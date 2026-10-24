// TownBuildingPanel for the human seat (Phase 7, slice 7.6): a building's panel
// model, its cards and texts.

#include "aurelion_rules/port/town_rules_actions.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/hero_command_rules_ai.hpp"
#include "aurelion_rules/port/hero_command_rules_turn.hpp"
#include "aurelion_rules/port/hero_progression_rules_turn.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/spell_rules_ai.hpp"
#include "aurelion_rules/port/town_rules.hpp"

#include <algorithm>
#include <initializer_list>
#include <string>
#include <vector>

namespace aurelion::rules::port {

// Defined in enemy_states.cpp (Phase 5) without a header.
namespace hero_progression_rules {
int64_t specialty_rank(State &state, DictRef hero_state, Atom specialty_id);
DictRef specialty_definition(State &state, Atom specialty_id);
} // namespace hero_progression_rules

namespace {

using gd::array_value;
using gd::ArrayRef;
using gd::Atom;
using gd::bool_value;
using gd::dict_value;
using gd::DictRef;
using gd::int_value;
using gd::str;
using state::ContentTable;
using state::Kind;
using state::State;
using state::Value;
namespace key = state::key;

// HeroCommandRules.HERO_LIMIT and TAVERN_OFFER_SIZE.
constexpr int64_t kHeroLimit = 4;
constexpr int64_t kTavernOfferSize = 2;

// TownConstructionBoard.RESOURCE_ORDER, read only.
constexpr Atom kResourceOrder[] = {key::gold, key::wood, key::ore, key::aetherglass, key::embergrain, key::peatwax,
		key::verdant_grafts, key::brass_scrip, key::memory_salt};

bool in_resource_order(Atom resource_id) {
	return std::find(std::begin(kResourceOrder), std::end(kResourceOrder), resource_id) != std::end(kResourceOrder);
}

// String(x): stringify(), and the engine's for a float, a container or an object.
Atom string_of(State &state, const Value &value) {
	switch (value.kind) {
		case Kind::Nil:
		case Kind::Bool:
		case Kind::Int:
		case Kind::String:
		case Kind::StringName:
			return gd::stringify(state, value);
		default:
			return gd::engine_str(state, value);
	}
}

// String(d.get(name, fallback)).
Atom text_of(State &state, DictRef dict, Atom name, Atom fallback = key::empty) {
	return string_of(state, state.get(dict, str(name), str(fallback)));
}

// String(d.get(name, fallback)) with any fallback value.
Atom text_or(State &state, DictRef dict, Atom name, const Value &fallback) {
	return string_of(state, state.get(dict, str(name), fallback));
}

// `d.get(name, {}) if d.get(name, {}) is Dictionary else {}`: the Dictionary
// itself, or a new one.
DictRef dict_field_or_new(State &state, DictRef dict, Atom name) {
	Value found;
	if (state.lookup(dict, str(name), found) && gd::is_dict(found)) {
		return found.ref;
	}
	return state.new_dict();
}

// x.duplicate(deep) of an untyped value.
Value duplicate_of(State &state, const Value &value, bool deep) {
	if (value.kind == Kind::Dict || value.kind == Kind::Array) {
		return deep ? gd::engine_duplicate(state, value, true) : gd::duplicate_value(state, value, false);
	}
	if (value.is_packed() && !deep) {
		return gd::duplicate_value(state, value, false);
	}
	throw state::ScriptError(std::string("Invalid call. Nonexistent function 'duplicate' in base '") + gd::type_name(value) + "'.");
}

// d.get(name, {}).duplicate(deep) and d.get(name, []).duplicate(deep).
Value duplicate_field(State &state, DictRef dict, Atom name, bool deep, bool array_fallback) {
	Value found;
	if (state.lookup(dict, str(name), found)) {
		return duplicate_of(state, found, deep);
	}
	return array_fallback ? array_value(state.new_array()) : dict_value(state.new_dict());
}

// text.split(delimiter) (allow_empty): every piece, the empty ones included.
std::vector<std::string> split_text(const std::string &text, char delimiter) {
	std::vector<std::string> parts;
	size_t from = 0;
	while (true) {
		const size_t end = text.find(delimiter, from);
		if (end == std::string::npos) {
			parts.push_back(text.substr(from));
			break;
		}
		parts.push_back(text.substr(from, end - from));
		from = end + 1;
	}
	return parts;
}

// ", ".join(parts) of Strings.
Atom join_comma(State &state, const std::vector<Atom> &parts) {
	std::string joined;
	for (size_t index = 0; index < parts.size(); ++index) {
		if (index > 0) {
			joined += ", ";
		}
		joined += state.text(parts[index]);
	}
	return state.intern(joined);
}

// "<pattern>" % [int(value)] for a pattern with a flag (%+d): the engine's.
Atom signed_line(State &state, Atom pattern, int64_t value) {
	return gd::engine_format(state, pattern, {int_value(value)});
}

void append_text(State &state, ArrayRef lines, Atom text) {
	state.append(lines, str(text));
}

} // namespace

namespace town_building_panel {

DictRef build(State &state, const Value &session, Atom building_id, DictRef options) {
	if (session.kind == Kind::Nil) {
		return state.new_dict();
	}
	const DictRef view = gd::as_dict(session);
	const DictRef town = town_rules::get_active_town(state, view);
	const DictRef building = gd::content_row(state, ContentTable::Building, building_id);
	if (gd::is_empty(state, town) || gd::is_empty(state, building)) {
		return state.new_dict();
	}
	const DictRef town_template = gd::content_row(state, ContentTable::Town, text_of(state, town, key::town_id));
	const Atom faction_id = text_of(state, town_template, key::faction_id);
	const DictRef board = town_construction_board::build_for_active_town(state, session);
	const DictRef slot = town_construction_board::slot_for_building(state, board, building_id);
	const Atom kind = building_kind(state, building);
	const DictRef resources = dict_field_or_new(state, session_view::overworld(state, view), key::resources);
	const DictRef model = state.new_dict();
	state.set(model, str(key::schema), str(key::town_building_panel_v1));
	state.set(model, str(key::building_id), str(building_id));
	state.set(model, str(key::kind), str(kind));
	state.set(model, str(key::name), str(text_or(state, building, key::name, str(building_id))));
	state.set(model, str(key::description), str(text_of(state, building, key::description)));
	state.set(model, str(key::subtitle), str(_subtitle(state, kind, building, slot, faction_id)));
	state.set(model, str(key::art_path), str(town_rules::building_icon_path(state, building_id, faction_id)));
	state.set(model, str(key::faction_id), str(faction_id));
	state.set(model, str(key::resources), gd::engine_duplicate(state, dict_value(resources), true));
	state.set(model, str(key::effects), array_value(effect_lines(state, building, town, session)));
	state.set(model, str(key::upgrade), dict_value(_upgrade(state, slot)));
	state.set(model, str(key::services), array_value(_building_services(state, session, building_id, kind)));
	if (kind == key::dwelling) {
		state.set(model, str(key::recruit), dict_value(_recruitment(state, session, town, slot, building)));
	} else if (kind == key::guild) {
		state.set(model, str(key::guild), dict_value(_guild(state, session, town, slot)));
	} else if (kind == key::tavern) {
		state.set(model, str(key::tavern), dict_value(_tavern(state, session, resources)));
	} else if (kind == key::market) {
		const DictRef need = dict_field_or_new(state, options, key::market_need);
		state.set(model, str(key::market), dict_value(town_rules::market_desk(state, view, need)));
	}
	return model;
}

Atom building_kind(State &state, DictRef building) {
	if (gd::int_field(state, building, key::dwelling_tier, 0) > 0 || text_of(state, building, key::unlock_unit_id) != key::empty) {
		return key::dwelling;
	}
	if (gd::int_field(state, building, key::spell_tier, 0) > 0) {
		return key::guild;
	}
	if (text_of(state, building, key::id) == key::building_wayfarers_hall) {
		return key::tavern;
	}
	Value market_profile;
	if (state.lookup(building, str(key::market_profile), market_profile) && gd::is_dict(market_profile) && !gd::is_empty(state, market_profile.ref)) {
		return key::market;
	}
	if (gd::bool_field(state, building, key::artifact_exchange, false)) {
		return key::artifact_exchange;
	}
	if (state.has(building, str(key::hero_visit_reward)) || state.has(building, str(key::faction_service))) {
		return key::training;
	}
	return key::building;
}

ArrayRef effect_lines(State &state, DictRef building, DictRef town, const Value &session) {
	(void)session;
	const ArrayRef lines = state.new_array();
	const DictRef income = dict_field_or_new(state, building, key::income);
	for (const Atom resource_id : kResourceOrder) {
		if (state.has(income, str(resource_id))) {
			const Atom amount = town_construction_board::format_amount(state, gd::to_int(state, gd::index(state, income, str(resource_id))));
			append_text(state, lines, gd::format(state, key::s_s_per_day, {str(amount), str(town_construction_board::resource_name(state, resource_id))}));
		}
	}
	const int64_t faction_income = gd::int_field(state, building, key::faction_resource_income, 0);
	if (faction_income > 0) {
		const DictRef town_template = gd::content_row(state, ContentTable::Town, text_of(state, town, key::town_id));
		const DictRef faction = gd::content_row(state, ContentTable::Faction, text_of(state, town_template, key::faction_id));
		// String(faction.get("town_resources", {}).get("main", "")).
		Atom main_resource = key::empty;
		Value town_resources;
		if (state.lookup(faction, str(key::town_resources), town_resources)) {
			main_resource = string_of(state, ai::vget(state, town_resources, key::main, str(key::empty)));
		}
		const Atom resource_label = main_resource != key::empty ? town_construction_board::resource_name(state, main_resource) : key::faction_resource;
		append_text(state, lines, gd::format(state, key::d_s_per_day, {int_value(faction_income), str(resource_label)}));
	}
	if (gd::int_field(state, building, key::defender_defense_bonus, 0) > 0) {
		append_text(state, lines, gd::format(state, key::defenders_d_defense, {int_value(gd::int_field(state, building, key::defender_defense_bonus, 0))}));
	}
	if (gd::int_field(state, building, key::readiness_bonus, 0) != 0) {
		append_text(state, lines, signed_line(state, key::readiness_d_3, gd::int_field(state, building, key::readiness_bonus, 0)));
	}
	if (gd::int_field(state, building, key::spell_tier, 0) > 0) {
		append_text(state, lines, gd::format(state, key::spells_up_to_level_d, {int_value(gd::int_field(state, building, key::spell_tier, 0))}));
	}
	if (gd::int_field(state, building, key::growth_amount, 0) > 0) {
		const int64_t tier = gd::int_field(state, building, key::growth_tier, 0);
		const Atom target = _built_dwelling_unit_name(state, town, tier);
		const int64_t amount = gd::int_field(state, building, key::growth_amount, 0);
		const Atom label = target != key::empty ? target : gd::format(state, key::tier_s_recruits, {str(town_construction_board::roman(state, tier))});
		append_text(state, lines, gd::format(state, key::d_s_per_week, {int_value(amount), str(label)}));
	}
	if (gd::int_field(state, building, key::growth_percent, 0) > 0) {
		append_text(state, lines, gd::format(state, key::creature_growth_d, {int_value(gd::int_field(state, building, key::growth_percent, 0))}));
	}
	const DictRef visit_reward = dict_field_or_new(state, building, key::hero_visit_reward);
	if (!gd::is_empty(state, visit_reward)) {
		append_text(state, lines, gd::format(state, key::visiting_hero_s_once, {str(_reward_text(state, visit_reward))}));
	}
	const DictRef service = dict_field_or_new(state, building, key::faction_service);
	if (!gd::is_empty(state, service)) {
		const Atom label = text_of(state, service, key::label, key::town_service);
		Value cost;
		if (!state.lookup(service, str(key::cost), cost)) {
			cost = dict_value(state.new_dict());
		}
		append_text(state, lines, gd::format(state, key::s_s_11, {str(label), str(_resource_text(state, cost))}));
	}
	const DictRef defense_effect = dict_field_or_new(state, building, key::town_defense_effect);
	if (!gd::is_empty(state, defense_effect)) {
		const Atom name = gd::capitalize(state, gd::replace(state, text_of(state, defense_effect, key::id, key::defense_ward), key::_, key::space));
		append_text(state, lines, gd::format(state, key::s_in_town_battles, {str(name)}));
	}
	const DictRef market_profile = dict_field_or_new(state, building, key::market_profile);
	if (!gd::is_empty(state, market_profile)) {
		append_text(state, lines, key::trades_every_resource);
		if (gd::int_field(state, market_profile, key::tier, 1) >= 2) {
			append_text(state, lines, key::better_rates_larger_weekly_limits);
		}
	}
	if (gd::bool_field(state, building, key::artifact_exchange, false)) {
		append_text(state, lines, key::artifact_trade_offers_refresh_weekly);
	}
	if (text_of(state, building, key::id) == key::building_wayfarers_hall) {
		append_text(state, lines, gd::format(state, key::hire_heroes_up_to_d_in, {int_value(kHeroLimit)}));
	}
	const DictRef growth_bonus = dict_field_or_new(state, building, key::growth_bonus);
	for (const Value &unit_id : gd::items(state, dict_value(growth_bonus))) {
		const int64_t amount = gd::to_int(state, gd::index(state, growth_bonus, unit_id));
		const DictRef unit = gd::content_row(state, ContentTable::Unit, string_of(state, unit_id));
		append_text(state, lines, gd::format(state, key::d_s_per_week, {int_value(amount), str(text_or(state, unit, key::name, unit_id))}));
	}
	const DictRef discounts = dict_field_or_new(state, building, key::recruitment_discount_percent);
	for (const Value &unit_id : gd::items(state, dict_value(discounts))) {
		const int64_t percent = gd::to_int(state, gd::index(state, discounts, unit_id));
		const DictRef unit = gd::content_row(state, ContentTable::Unit, string_of(state, unit_id));
		append_text(state, lines, gd::format(state, key::d_off_s, {int_value(percent), str(text_or(state, unit, key::name, unit_id))}));
	}
	if (gd::int_field(state, building, key::pressure_bonus, 0) != 0) {
		append_text(state, lines, signed_line(state, key::frontier_pressure_d, gd::int_field(state, building, key::pressure_bonus, 0)));
	}
	const DictRef capital_project = dict_field_or_new(state, building, key::capital_project);
	if (!gd::is_empty(state, capital_project)) {
		append_text(state, lines, key::capital_project_2);
	}
	return lines;
}

// --- upgrade line ---

DictRef _upgrade(State &state, DictRef slot) {
	if (gd::is_empty(state, slot)) {
		const DictRef result = state.new_dict();
		state.set(result, str(key::has_line), bool_value(false));
		return result;
	}
	const ArrayRef stages = gd::as_array(duplicate_field(state, slot, key::stages, true, true));
	const Atom next_id = text_of(state, slot, key::next_id);
	const Atom current_id = text_of(state, slot, key::current_id);
	const DictRef next_building = next_id != key::empty ? gd::content_row(state, ContentTable::Building, next_id) : state.new_dict();
	const DictRef result = state.new_dict();
	state.set(result, str(key::has_line), bool_value(state.array_size(stages) > 1));
	state.set(result, str(key::slot_id), str(text_of(state, slot, key::id)));
	state.set(result, str(key::stages), array_value(stages));
	state.set(result, str(key::current_id), str(current_id));
	state.set(result, str(key::next_id), str(next_id));
	state.set(result, str(key::next_name), str(text_or(state, next_building, key::name, str(next_id))));
	state.set(result, str(key::next_description), str(text_of(state, next_building, key::description)));
	state.set(result, str(key::complete), bool_value(next_id == key::empty));
	state.set(result, str(key::status), str(text_of(state, slot, key::status)));
	state.set(result, str(key::status_text), str(text_of(state, slot, key::status_text)));
	state.set(result, str(key::status_detail), str(text_of(state, slot, key::status_detail)));
	state.set(result, str(key::verb), str(text_of(state, slot, key::verb)));
	state.set(result, str(key::cost), duplicate_field(state, slot, key::cost, true, false));
	state.set(result, str(key::shortfall), duplicate_field(state, slot, key::shortfall, true, false));
	state.set(result, str(key::missing_requirements), duplicate_field(state, slot, key::missing_requirements, false, true));
	state.set(result, str(key::forgone_unit_names), duplicate_field(state, slot, key::forgone_unit_names, false, true));
	const Atom current_unit_id = current_id != key::empty ? text_of(state, gd::content_row(state, ContentTable::Building, current_id), key::unlock_unit_id) : key::empty;
	state.set(result, str(key::current_unit_id), str(current_unit_id));
	state.set(result, str(key::next_unit_id), str(text_of(state, next_building, key::unlock_unit_id)));
	return result;
}

// --- dwelling ---

DictRef _recruitment(State &state, const Value &session, DictRef town, DictRef slot, DictRef building) {
	const DictRef view = gd::as_dict(session);
	const ArrayRef line_unit_ids = state.new_array();
	for (const Value &stage : gd::field_items(state, slot, str(key::stages))) {
		const Atom unit_id = string_of(state, ai::vget(state, stage, key::unit_id, str(key::empty)));
		if (unit_id != key::empty && !gd::array_has(state, line_unit_ids, str(unit_id))) {
			state.append(line_unit_ids, str(unit_id));
		}
	}
	if (state.array_size(line_unit_ids) == 0) {
		state.append(line_unit_ids, str(text_of(state, building, key::unlock_unit_id)));
	}
	const ArrayRef units = state.new_array();
	for (const Value &row_value : gd::items(state, array_value(town_rules::get_muster_catalog(state, view)))) {
		if (!gd::is_dict(row_value) || !gd::array_has(state, line_unit_ids, str(text_of(state, row_value.ref, key::unit_id)))) {
			continue;
		}
		state.append(units, dict_value(recruit_card(state, row_value.ref)));
	}
	const ArrayRef base_unit_ids = state.new_array();
	for (const Value &unit_id : gd::items(state, array_value(line_unit_ids))) {
		const Atom base_id = text_of(state, gd::content_row(state, ContentTable::Unit, string_of(state, unit_id)), key::upgrade_from);
		if (base_id != key::empty) {
			state.append(base_unit_ids, str(base_id));
		}
	}
	const ArrayRef troop_upgrades = state.new_array();
	for (const Value &action : gd::items(state, array_value(town_rules::get_response_actions(state, view)))) {
		const Atom action_id = string_of(state, ai::vget(state, action, key::id, str(key::empty)));
		const std::vector<std::string> parts = split_text(state.text(action_id), ':');
		if (parts.size() == 3 && parts[0] == state.text(key::town_upgrade) && gd::array_has(state, base_unit_ids, str(state.intern(parts[2])))) {
			state.append(troop_upgrades, dict_value(_action_entry(state, gd::as_dict(action))));
		}
	}
	const DictRef destination = hero_command_rules::town_recruitment_destination(state, view, town);
	const DictRef result = state.new_dict();
	state.set(result, str(key::line_unit_ids), array_value(line_unit_ids));
	state.set(result, str(key::units), array_value(units));
	state.set(result, str(key::destination), str(text_of(state, destination, key::summary)));
	state.set(result, str(key::troop_upgrades), array_value(troop_upgrades));
	return result;
}

DictRef recruit_card(State &state, DictRef row) {
	const Atom unit_id = text_of(state, row, key::unit_id);
	const int64_t direct = gd::int_field(state, row, key::direct_affordable_count, 0);
	const DictRef card = unit_card(state, unit_id);
	const DictRef extra = state.new_dict();
	state.set(extra, str(key::available), int_value(gd::int_field(state, row, key::available_count, 0)));
	state.set(extra, str(key::weekly_growth), int_value(gd::int_field(state, row, key::weekly_growth, 0)));
	Value unit_cost;
	if (state.lookup(row, str(key::unit_cost), unit_cost) && gd::is_dict(unit_cost)) {
		unit_cost = gd::engine_duplicate(state, unit_cost, true);
	} else {
		unit_cost = dict_value(state.new_dict());
	}
	state.set(extra, str(key::unit_cost), unit_cost);
	state.set(extra, str(key::max_now), int_value(direct));
	state.set(extra, str(key::market_max), int_value(gd::int_field(state, row, key::market_affordable_count, 0)));
	state.set(extra, str(key::status), str(text_of(state, row, key::catalog_status)));
	state.set(extra, str(key::status_detail), str(text_of(state, row, key::catalog_status_detail)));
	state.set(extra, str(key::disabled), bool_value(gd::bool_field(state, row, key::disabled, true) || direct <= 0));
	// unit_card(unit_id).merged({...}, true)
	const DictRef merged = gd::duplicate_dict(state, card);
	gd::merge(state, merged, extra, true);
	return merged;
}

DictRef unit_card(State &state, Atom unit_id) {
	const DictRef unit = gd::content_row(state, ContentTable::Unit, unit_id);
	const ArrayRef abilities = state.new_array();
	for (const Value &ability : gd::field_items(state, unit, str(key::abilities))) {
		if (!gd::is_dict(ability)) {
			continue;
		}
		const DictRef entry = state.new_dict();
		const Value name = state.get(ability.ref, str(key::name), state.get(ability.ref, str(key::id), str(key::empty)));
		state.set(entry, str(key::name), str(string_of(state, name)));
		state.set(entry, str(key::description), str(text_of(state, ability.ref, key::description)));
		state.append(abilities, dict_value(entry));
	}
	const bool ranged = gd::bool_field(state, unit, key::ranged, false) || text_of(state, unit, key::role) == key::ranged;
	const DictRef result = state.new_dict();
	state.set(result, str(key::unit_id), str(unit_id));
	state.set(result, str(key::name), str(text_or(state, unit, key::name, str(unit_id))));
	state.set(result, str(key::tier), int_value(gd::int_field(state, unit, key::tier, 0)));
	state.set(result, str(key::role), str(ranged ? key::ranged : key::melee));
	state.set(result, str(key::attack), int_value(gd::int_field(state, unit, key::attack, 0)));
	state.set(result, str(key::defense), int_value(gd::int_field(state, unit, key::defense, 0)));
	state.set(result, str(key::min_damage), int_value(gd::int_field(state, unit, key::min_damage, 0)));
	state.set(result, str(key::max_damage), int_value(gd::int_field(state, unit, key::max_damage, 0)));
	state.set(result, str(key::hp), int_value(gd::int_field(state, unit, key::hp, 0)));
	state.set(result, str(key::speed), int_value(gd::int_field(state, unit, key::speed, 0)));
	state.set(result, str(key::initiative), int_value(gd::int_field(state, unit, key::initiative, 0)));
	state.set(result, str(key::shots), int_value(ranged ? gd::int_field(state, unit, key::shots, 0) : 0));
	state.set(result, str(key::abilities), array_value(abilities));
	state.set(result, str(key::portrait_path), str(text_of(state, gd::content_row(state, ContentTable::UnitArt, unit_id), key::portrait)));
	return result;
}

// --- magic guild ---

DictRef _guild(State &state, const Value &session, DictRef town, DictRef slot) {
	Value stages_value;
	const ArrayRef stages = state.lookup(slot, str(key::stages), stages_value) ? gd::as_array(stages_value) : state.new_array();
	const int64_t current_level = town_rules::current_spell_tier(state, town);
	const DictRef visitor = hero_command_rules::town_defending_hero(state, gd::as_dict(session), town);
	const ArrayRef levels = state.new_array();
	const ArrayRef seen = state.new_array();
	for (int64_t index = 0; index < state.array_size(stages); ++index) {
		const DictRef stage = gd::as_dict(state.at(stages, index));
		const DictRef stage_building = gd::content_row(state, ContentTable::Building, text_of(state, stage, key::building_id));
		const int64_t level = gd::int_field(state, stage_building, key::spell_tier, index + 1);
		const ArrayRef spells = state.new_array();
		for (const Value &spell_id_value : gd::items(state, array_value(town_rules::spell_ids_through_tier(state, town, level)))) {
			const Atom spell_id = string_of(state, spell_id_value);
			if (gd::array_has(state, seen, str(spell_id))) {
				continue;
			}
			state.append(seen, str(spell_id));
			state.append(spells, dict_value(spell_entry(state, spell_id, visitor)));
		}
		const DictRef entry = state.new_dict();
		state.set(entry, str(key::level), int_value(level));
		state.set(entry, str(key::building_id), str(text_of(state, stage, key::building_id)));
		state.set(entry, str(key::building_name), str(text_of(state, stage, key::name)));
		state.set(entry, str(key::built), bool_value(level <= current_level));
		state.set(entry, str(key::spells), array_value(spells));
		state.append(levels, dict_value(entry));
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::current_level), int_value(current_level));
	state.set(result, str(key::max_level), int_value(state.array_size(levels)));
	state.set(result, str(key::visitor_name), str(text_of(state, visitor, key::name)));
	state.set(result, str(key::levels), array_value(levels));
	return result;
}

DictRef spell_entry(State &state, Atom spell_id, DictRef visitor) {
	const DictRef spell = gd::content_row(state, ContentTable::Spell, spell_id);
	const Atom school_id = text_of(state, spell, key::school_id);
	const DictRef result = state.new_dict();
	state.set(result, str(key::id), str(spell_id));
	state.set(result, str(key::name), str(text_or(state, spell, key::name, str(spell_id))));
	state.set(result, str(key::tier), int_value(gd::int_field(state, spell, key::tier, 0)));
	state.set(result, str(key::school_id), str(school_id));
	state.set(result, str(key::school_name), str(gd::capitalize(state, gd::replace(state, school_id, key::_, key::space))));
	state.set(result, str(key::context), str(text_of(state, spell, key::context) == key::overworld ? key::Adventure : key::Battle));
	state.set(result, str(key::mana), int_value(gd::int_field(state, spell, key::mana_cost, 0)));
	state.set(result, str(key::category), str(spell_rules::spell_category_label(state, spell)));
	state.set(result, str(key::summary), str(spell_rules::_spell_effect_summary(state, spell, visitor)));
	state.set(result, str(key::description), str(text_of(state, spell, key::description)));
	state.set(result, str(key::icon_path), str(spell_rules::spell_icon_path(state, spell_id)));
	state.set(result, str(key::known), bool_value(!gd::is_empty(state, visitor) && spell_rules::knows_spell(state, visitor, spell_id)));
	return result;
}

// --- tavern ---

DictRef _tavern(State &state, const Value &session, DictRef resources) {
	const DictRef view = gd::as_dict(session);
	const int64_t count = hero_command_rules::player_hero_count(state, view);
	const int64_t limit = kHeroLimit;
	const DictRef actions = state.new_dict();
	for (const Value &action : gd::items(state, array_value(town_rules::get_tavern_actions(state, view)))) {
		state.set(actions, str(string_of(state, ai::vget(state, action, key::id, str(key::empty)))), action);
	}
	const ArrayRef heroes = state.new_array();
	for (const Value &hero_id_value : gd::items(state, array_value(hero_command_rules::tavern_offer_ids(state, view)))) {
		const Atom hero_id = string_of(state, hero_id_value);
		const DictRef card = hero_card(state, hero_id);
		if (gd::is_empty(state, card)) {
			continue;
		}
		_apply_tavern_offer(state, card, hero_command_rules::tavern_offer_preview(state, view, hero_id));
		const Atom action_id = gd::format(state, key::hire_hero_s, {str(hero_id)});
		const DictRef shortfall = town_construction_board::_shortfall(state, gd::as_dict(gd::index(state, card, str(key::cost))), resources);
		Atom reason = key::empty;
		if (count >= limit) {
			reason = gd::format(state, key::command_is_full_d_of_d, {int_value(count), int_value(limit)});
		} else if (!gd::is_empty(state, shortfall)) {
			reason = gd::format(state, key::short_s, {str(_resource_text(state, dict_value(shortfall)))});
		} else if (!state.has(actions, str(action_id))) {
			reason = key::not_available_for_hire_here;
		}
		state.set(card, str(key::action_id), str(action_id));
		state.set(card, str(key::shortfall), dict_value(shortfall));
		bool disabled = reason != key::empty;
		if (!disabled) {
			// bool(actions.get(action_id, {}).get("disabled", true))
			Value action;
			disabled = state.lookup(actions, str(action_id), action) ? gd::to_bool(ai::vget(state, action, key::disabled, bool_value(true))) : true;
		}
		state.set(card, str(key::disabled), bool_value(disabled));
		state.set(card, str(key::disabled_reason), str(reason));
		state.append(heroes, dict_value(card));
	}
	const int64_t days = hero_command_rules::days_until_tavern_rotation(state, view);
	const DictRef result = state.new_dict();
	state.set(result, str(key::hero_count), int_value(count));
	state.set(result, str(key::hero_limit), int_value(limit));
	state.set(result, str(key::heroes), array_value(heroes));
	state.set(result, str(key::offer_size), int_value(kTavernOfferSize));
	state.set(result, str(key::days_until_rotation), int_value(days));
	state.set(result, str(key::next_rotation_day), int_value(gd::add(ai::session_int(state, view, key::day), days)));
	return result;
}

DictRef hero_card(State &state, Atom hero_id) {
	const DictRef hero = gd::content_row(state, ContentTable::Hero, hero_id);
	if (gd::is_empty(state, hero)) {
		return state.new_dict();
	}
	const DictRef command = dict_field_or_new(state, hero, key::command);
	const ArrayRef specialties = state.new_array();
	for (const Value &specialty_id : gd::field_items(state, hero, str(key::starting_specialties))) {
		const Atom specialty_text = string_of(state, specialty_id);
		const DictRef specialty = hero_progression_rules::specialty_definition(state, specialty_text);
		Value name;
		const Atom label = state.lookup(specialty, str(key::name), name) ? string_of(state, name) : gd::capitalize(state, specialty_text);
		state.append(specialties, str(label));
	}
	const ArrayRef traits = state.new_array();
	for (const Value &trait_id : gd::field_items(state, hero, str(key::battle_traits))) {
		state.append(traits, str(gd::capitalize(state, gd::replace(state, string_of(state, trait_id), key::_, key::space))));
	}
	const ArrayRef spells = state.new_array();
	for (const Value &spell_id : gd::field_items(state, hero, str(key::starting_spell_ids))) {
		const Atom spell_text = string_of(state, spell_id);
		const DictRef spell = gd::content_row(state, ContentTable::Spell, spell_text);
		const DictRef entry = state.new_dict();
		state.set(entry, str(key::id), str(spell_text));
		state.set(entry, str(key::name), str(text_or(state, spell, key::name, spell_id)));
		state.set(entry, str(key::icon_path), str(spell_rules::spell_icon_path(state, spell_text)));
		state.append(spells, dict_value(entry));
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::hero_id), str(hero_id));
	state.set(result, str(key::name), str(text_or(state, hero, key::name, str(hero_id))));
	state.set(result, str(key::class_name), str(hero_command_rules::hero_archetype_label(state, hero)));
	state.set(result, str(key::summary), str(text_of(state, hero, key::roster_summary)));
	state.set(result, str(key::identity), str(text_of(state, hero, key::identity_summary)));
	state.set(result, str(key::portrait_path), str(text_of(state, gd::content_row(state, ContentTable::HeroArt, hero_id), key::portrait)));
	state.set(result, str(key::attack), int_value(gd::int_field(state, command, key::attack, 0)));
	state.set(result, str(key::defense), int_value(gd::int_field(state, command, key::defense, 0)));
	state.set(result, str(key::power), int_value(gd::int_field(state, command, key::power, 0)));
	state.set(result, str(key::knowledge), int_value(gd::int_field(state, command, key::knowledge, 0)));
	state.set(result, str(key::movement), int_value(gd::int_field(state, hero, key::base_movement, 0)));
	state.set(result, str(key::specialties), array_value(specialties));
	state.set(result, str(key::traits), array_value(traits));
	state.set(result, str(key::spells), array_value(spells));
	state.set(result, str(key::cost), dict_value(hero_command_rules::hero_recruit_cost(state, hero)));
	return result;
}

void _apply_tavern_offer(State &state, DictRef card, DictRef recruit) {
	if (gd::is_empty(state, recruit)) {
		return;
	}
	const DictRef command = dict_field_or_new(state, recruit, key::command);
	for (const Atom stat : {key::attack, key::defense, key::power, key::knowledge}) {
		const Value fallback = state.get(card, str(stat), int_value(0));
		state.set(card, str(stat), int_value(gd::to_int(state, state.get(command, str(stat), fallback))));
	}
	state.set(card, str(key::level), int_value(gd::int_field(state, recruit, key::level, 1)));
	{
		// int(recruit.get("movement", {}).get("max", card.get("movement", 0)))
		const Value fallback = state.get(card, str(key::movement), int_value(0));
		Value movement;
		const Value max_value = state.lookup(recruit, str(key::movement), movement) ? ai::vget(state, movement, key::max, fallback) : fallback;
		state.set(card, str(key::movement), int_value(gd::to_int(state, max_value)));
	}
	const ArrayRef specialties = state.new_array();
	std::vector<Atom> seen;
	for (const Value &specialty_id_value : gd::field_items(state, recruit, str(key::specialties))) {
		const Atom specialty_id = string_of(state, specialty_id_value);
		if (std::find(seen.begin(), seen.end(), specialty_id) != seen.end()) {
			continue;
		}
		seen.push_back(specialty_id);
		const int64_t rank = hero_progression_rules::specialty_rank(state, recruit, specialty_id);
		const DictRef definition = hero_progression_rules::specialty_definition(state, specialty_id);
		Value name;
		const Atom specialty_name = state.lookup(definition, str(key::name), name) ? string_of(state, name) : gd::capitalize(state, specialty_id);
		const Atom label = rank <= 1 ? specialty_name : gd::format(state, key::s_s, {str(specialty_name), str(hero_progression_rules::rank_label(state, rank))});
		state.append(specialties, str(label));
	}
	state.set(card, str(key::specialties), array_value(specialties));
	const ArrayRef army = state.new_array();
	Value stacks = array_value(state.new_array());
	Value army_value;
	if (state.lookup(recruit, str(key::army), army_value)) {
		stacks = ai::vget(state, army_value, key::stacks, stacks);
	}
	for (const Value &stack : gd::items(state, stacks)) {
		const Atom unit_id = string_of(state, ai::vget(state, stack, key::unit_id, str(key::empty)));
		const DictRef art = gd::content_row(state, ContentTable::UnitArt, unit_id);
		const DictRef entry = state.new_dict();
		state.set(entry, str(key::unit_id), str(unit_id));
		state.set(entry, str(key::name), str(text_or(state, gd::content_row(state, ContentTable::Unit, unit_id), key::name, str(unit_id))));
		state.set(entry, str(key::count), int_value(gd::to_int(state, ai::vget(state, stack, key::count, int_value(0)))));
		const Value icon = state.get(art, str(key::battle_icon), state.get(art, str(key::portrait), str(key::empty)));
		state.set(entry, str(key::icon_path), str(string_of(state, icon)));
		state.append(army, dict_value(entry));
	}
	state.set(card, str(key::army), array_value(army));
}

// --- services ---

ArrayRef _building_services(State &state, const Value &session, Atom building_id, Atom kind) {
	const ArrayRef services = state.new_array();
	for (const Value &action : gd::items(state, array_value(town_rules::get_response_actions(state, gd::as_dict(session))))) {
		const Atom action_id = string_of(state, ai::vget(state, action, key::id, str(key::empty)));
		const std::vector<std::string> parts = split_text(state.text(action_id), ':');
		if (parts.size() < 2) {
			continue;
		}
		const bool own = (parts[0] == state.text(key::town_train) || parts[0] == state.text(key::town_faction)) && parts[1] == state.text(building_id);
		const bool exchange = kind == key::artifact_exchange && (parts[0] == state.text(key::town_buy) || parts[0] == state.text(key::town_sell));
		if (own || exchange) {
			state.append(services, dict_value(_action_entry(state, gd::as_dict(action))));
		}
	}
	return services;
}

DictRef _action_entry(State &state, DictRef action) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::id), str(text_of(state, action, key::id)));
	const Value label = state.get(action, str(key::label), state.get(action, str(key::id), str(key::empty)));
	state.set(result, str(key::label), str(string_of(state, label)));
	state.set(result, str(key::summary), str(text_of(state, action, key::summary)));
	state.set(result, str(key::disabled), bool_value(gd::bool_field(state, action, key::disabled, false)));
	return result;
}

// --- text helpers ---

Atom _subtitle(State &state, Atom kind, DictRef building, DictRef slot, Atom faction_id) {
	// String(ContentService.get_faction(faction_id).get("name", "")).split(" ")[0]
	const std::string faction_name = state.text(text_of(state, gd::content_row(state, ContentTable::Faction, faction_id), key::name));
	const Atom faction_word = state.intern(faction_name.substr(0, faction_name.find(' ')));
	const int64_t stage_count = gd::int_field(state, slot, key::stage_count, 1);
	const Atom stage_text = stage_count > 1 ? gd::format(state, key::stage_d_of_d, {int_value(gd::int_field(state, slot, key::done_count, 1)), int_value(stage_count)}) : key::empty;
	if (kind == key::dwelling) {
		const Atom tier = town_construction_board::roman(state, gd::int_field(state, building, key::dwelling_tier, 0));
		return gd::format(state, key::tier_s_dwelling_s, {str(tier), str(stage_text)});
	}
	if (kind == key::guild) {
		return gd::format(state, key::magic_guild_level_d_of_d, {int_value(gd::int_field(state, building, key::spell_tier, 0)), int_value(stage_count)});
	}
	if (kind == key::tavern) {
		return key::tavern_hire_heroes;
	}
	if (text_of(state, building, key::faction_id) != key::empty && faction_word != key::empty) {
		return gd::format(state, key::s_signature_s, {str(faction_word), str(stage_text)});
	}
	const Atom category = gd::capitalize(state, text_of(state, building, key::category, key::support));
	return gd::format(state, key::s_building_s, {str(category), str(stage_text)});
}

Atom _built_dwelling_unit_name(State &state, DictRef town, int64_t tier) {
	if (tier <= 0) {
		return key::empty;
	}
	const DictRef town_template = gd::content_row(state, ContentTable::Town, text_of(state, town, key::town_id));
	int64_t best_stage = 0;
	Atom name = key::empty;
	for (const Value &building_id : gd::items(state, array_value(town_construction_board::town_building_ids(state, town_template)))) {
		const DictRef building = gd::content_row(state, ContentTable::Building, string_of(state, building_id));
		if (gd::int_field(state, building, key::dwelling_tier, 0) != tier) {
			continue;
		}
		// building_id not in town.get("built_buildings", [])
		Value built;
		if (!state.lookup(town, str(key::built_buildings), built) || !gd::in(state, building_id, built)) {
			continue;
		}
		if (gd::int_field(state, building, key::stage, 1) > best_stage) {
			best_stage = gd::int_field(state, building, key::stage, 1);
			name = text_of(state, gd::content_row(state, ContentTable::Unit, text_of(state, building, key::unlock_unit_id)), key::name);
		}
	}
	return name;
}

Atom _resource_text(State &state, const Value &resources) {
	if (!gd::is_dict(resources) || gd::is_empty(state, resources.ref)) {
		return key::nothing;
	}
	std::vector<Atom> parts;
	for (const Atom resource_id : kResourceOrder) {
		if (state.has(resources.ref, str(resource_id))) {
			const Atom amount = town_construction_board::format_amount(state, gd::to_int(state, gd::index(state, resources.ref, str(resource_id))));
			parts.push_back(gd::format(state, key::s_s, {str(amount), str(town_construction_board::resource_name(state, resource_id))}));
		}
	}
	for (const Value &resource_id : gd::items(state, resources)) {
		const Atom id_text = string_of(state, resource_id);
		if (!in_resource_order(id_text)) {
			const Atom amount = town_construction_board::format_amount(state, gd::to_int(state, gd::index(state, resources.ref, resource_id)));
			parts.push_back(gd::format(state, key::s_s, {str(amount), str(gd::replace(state, string_of(state, resource_id), key::_, key::space))}));
		}
	}
	return join_comma(state, parts);
}

Atom _reward_text(State &state, DictRef reward) {
	std::vector<Atom> parts;
	for (const Value &reward_key : gd::items(state, dict_value(reward))) {
		const int64_t amount = gd::to_int(state, gd::index(state, reward, reward_key));
		if (string_of(state, reward_key) == key::experience) {
			parts.push_back(gd::format(state, key::s_experience, {str(town_construction_board::format_amount(state, amount))}));
		} else {
			parts.push_back(gd::format(state, key::d_s_2, {int_value(amount), str(string_of(state, reward_key))}));
		}
	}
	return join_comma(state, parts);
}

} // namespace town_building_panel

} // namespace aurelion::rules::port
