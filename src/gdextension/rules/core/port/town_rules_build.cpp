// TownRules for the human seat's building (Phase 7, slice 7.6): the build
// actions and catalog and their texts.

#include "aurelion_rules/port/town_rules_actions.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/overworld_rules_ai.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/town_development_rules_ai.hpp"
#include "aurelion_rules/port/town_development_rules_turn.hpp"

#include <string>
#include <string_view>

namespace aurelion::rules::port {

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
using state::State;
using state::Value;
namespace key = state::key;

// String(d.get(field, fallback)).
Atom text_field(State &state, DictRef dict, Atom field, const Value &fallback) {
	return gd::stringify(state, state.get(dict, str(field), fallback));
}

// d.get(field, {}) of a value that may be stored: the field, or a new Dictionary.
Value field_or_new_dict(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return dict_value(state.new_dict());
}

// sep.join(parts) of an Array of Strings.
Atom join_array(State &state, Atom separator, ArrayRef parts) {
	std::string joined;
	bool first = true;
	for (const Value &part : gd::items(state, array_value(parts))) {
		if (!first) {
			joined += state.text(separator);
		}
		joined += gd::text(state, part);
		first = false;
	}
	return state.intern(joined);
}

// a.sort() of an Array that holds only Strings (code point order).
void sort_strings(State &state, ArrayRef array) {
	gd::sort_custom(state, array, [&state](const Value &a, const Value &b) { return gd::text(state, a) < gd::text(state, b); });
}

// s.trim_suffix(suffix).
Atom trim_suffix(State &state, Atom text, Atom suffix) {
	if (!gd::ends_with(state, text, suffix)) {
		return text;
	}
	const std::string source = state.text(text);
	return state.intern(std::string_view(source).substr(0, source.size() - state.text(suffix).size()));
}

// s.to_lower() of ASCII text (the pressure labels).
Atom to_lower_ascii(State &state, Atom text) {
	std::string lowered = state.text(text);
	for (char &c : lowered) {
		if (c >= 'A' && c <= 'Z') {
			c = static_cast<char>(c - 'A' + 'a');
		}
	}
	return state.intern(lowered);
}

// x in BUILDING_CATEGORY_IDS.
bool is_building_category(Atom category_id) {
	return category_id == key::civic || category_id == key::dwelling || category_id == key::economy || category_id == key::support || category_id == key::magic;
}

} // namespace

namespace town_rules {

Atom building_id_for_action(State &state, Atom action_id) {
	if (!gd::begins_with(state, action_id, key::build)) {
		return key::empty;
	}
	const Atom building_id = gd::trim_prefix(state, action_id, key::build);
	return !gd::is_empty(state, gd::content_row(state, ContentTable::Building, building_id)) ? building_id : key::empty;
}

Atom building_category_icon_path(State &state, Atom building_id) {
	const DictRef building = gd::content_row(state, ContentTable::Building, building_id);
	const Atom category_id = gd::strip_edges(state, ai::string_or_empty(state, building, key::category));
	if (!is_building_category(category_id)) {
		return key::empty;
	}
	const DictRef icon = gd::content_row(state, ContentTable::BuildingCategoryIcon, category_id);
	const Atom icon_path = gd::strip_edges(state, ai::string_or_empty(state, icon, key::icon_path));
	if (ai::string_or_empty(state, icon, key::id) != category_id) {
		return key::empty;
	}
	if (ai::string_or_empty(state, icon, key::icon_id) != gd::format(state, key::building_category_sigil_s, {str(category_id)})) {
		return key::empty;
	}
	if (!gd::begins_with(state, icon_path, key::res_art_towns_runtime_building_categories) || !gd::resource_exists(state, icon_path)) {
		return key::empty;
	}
	return icon_path;
}

Atom building_icon_path(State &state, Atom building_id, Atom faction_id) {
	if (faction_id != key::empty) {
		const DictRef layers = gd::content_file(state, key::town_building_scene_art_manifest_path);
		const Value factions = field_or_new_dict(state, layers, key::factions);
		const DictRef faction_layers = gd::as_dict(ai::vget(state, factions, faction_id, dict_value(state.new_dict())));
		const DictRef layer = gd::as_dict(field_or_new_dict(state, faction_layers, building_id));
		const Atom faction_icon = ai::string_or_empty(state, layer, key::icon_path);
		if (gd::begins_with(state, faction_icon, key::res_art_towns_runtime_buildings) && gd::resource_exists(state, faction_icon)) {
			return faction_icon;
		}
	}
	const DictRef art = gd::content_row(state, ContentTable::BuildingArt, building_id);
	const Atom icon_path = gd::strip_edges(state, ai::string_or_empty(state, art, key::icon_path));
	if (ai::string_or_empty(state, art, key::id) == building_id
			&& ai::string_or_empty(state, art, key::building_id) == building_id
			&& ai::string_or_empty(state, art, key::source_kind) == key::curated_original_building
			&& gd::begins_with(state, icon_path, key::res_art_towns_runtime_buildings)
			&& gd::resource_exists(state, icon_path)) {
		return icon_path;
	}
	return building_category_icon_path(state, building_id);
}

ArrayRef get_build_actions(State &state, DictRef session) {
	if (_read_cache_has(state, session, key::build_actions)) {
		return gd::as_array(_read_cache_get(state, session, key::build_actions));
	}
	const DictRef town = get_active_town(state, session);
	if (gd::is_empty(state, town)) {
		const ArrayRef empty = state.new_array();
		_read_cache_store(state, session, key::build_actions, array_value(empty));
		return empty;
	}

	const ArrayRef actions = state.new_array();
	const Value resources = field_or_new_dict(state, session_view::overworld(state, session), key::resources);
	const ArrayRef building_ids = _available_building_ids(state, town, ai::session_int(state, session, key::day));
	for (const Value &building_id_value : gd::items(state, array_value(building_ids))) {
		const Atom building_id = gd::to_string(building_id_value);
		const DictRef building = gd::content_row(state, ContentTable::Building, building_id);
		const Atom unlock_unit_id = ai::string_or_empty(state, building, key::unlock_unit_id);
		const DictRef unlocked_unit = unlock_unit_id != key::empty ? gd::content_row(state, ContentTable::Unit, unlock_unit_id) : state.new_dict();
		const int64_t unit_tier = !gd::is_empty(state, unlocked_unit) ? gd::int_field(state, unlocked_unit, key::tier, 0) : 0;
		const Atom tier_label = _unit_tier_label(state, unit_tier);
		const DictRef build_status = overworld_rules::get_town_build_status(state, town, building_id, ai::session_int(state, session, key::day));
		const Value cost = field_or_new_dict(state, building, key::cost);
		const Atom projection = overworld_rules::describe_town_build_projection(state, session, town, building_id);
		const DictRef readiness = overworld_rules::town_cost_readiness(state, town, gd::as_dict(resources), cost, ai::session_int(state, session, key::day));
		const bool direct_affordable = gd::bool_field(state, readiness, key::direct_affordable, false);
		const bool market_coverable = gd::bool_field(state, readiness, key::market_affordable, false) && !direct_affordable;
		const Atom market_summary = _market_coverage_line(state, readiness);
		const Atom shortfall_summary = _cost_shortfall_line(state, readiness);
		const Atom affordability_line = _cost_readiness_line(state, gd::as_dict(resources), cost, readiness);
		const Atom after_spend_line = _stores_after_cost_line(state, gd::as_dict(resources), cost);
		const Atom impact_line = _build_choice_impact_line(state, session, town, building_id, building);
		const ArrayRef summary_lines = state.new_array();
		const Atom available_line = _building_line(state, building_id, key::available, build_status);
		state.append(summary_lines, str(gd::format(state, key::s_cost_s, {str(available_line), str(_describe_resources(state, cost))})));
		state.append(summary_lines, str(projection));
		state.append(summary_lines, str(impact_line));
		state.append(summary_lines, str(affordability_line));
		if (unit_tier > 0) {
			gd::insert(state, summary_lines, 1, str(gd::format(state, key::unlocks_s_s, {str(tier_label), str(text_field(state, unlocked_unit, key::name, str(unlock_unit_id)))})));
		}
		if (direct_affordable) {
			if (after_spend_line != key::empty) {
				state.append(summary_lines, str(gd::format(state, key::after_build_stores_s, {str(after_spend_line)})));
			}
		} else if (market_coverable && market_summary != key::empty) {
			state.append(summary_lines, str(gd::format(state, key::exchange_path_s, {str(market_summary)})));
		} else if (shortfall_summary != key::empty) {
			state.append(summary_lines, str(gd::format(state, key::blocker_s, {str(shortfall_summary)})));
		}
		const DictRef action = state.new_dict();
		state.set(action, str(key::id), str(gd::format(state, key::build_s, {building_id_value})));
		state.set(action, str(key::label), str(gd::format(state, key::build_s_2, {str(text_field(state, building, key::name, building_id_value))})));
		state.set(action, str(key::summary), str(join_array(state, key::newline, summary_lines)));
		const Atom button_name = text_field(state, building, key::name, building_id_value);
		state.set(action, str(key::button_label), str(gd::format(state, key::build_s_s, {str(button_name), str(_build_action_badge(state, direct_affordable, market_coverable))})));
		const Atom ledger_building_line = _building_line(state, building_id, key::available, build_status);
		const Atom ledger_cost = _describe_resources(state, cost);
		state.set(action, str(key::ledger_line), str(gd::format(state, key::s_cost_s_s, {str(ledger_building_line), str(ledger_cost), str(trim_suffix(state, affordability_line, key::period))})));
		state.set(action, str(key::impact_line), str(impact_line));
		state.set(action, str(key::recommendation_line), str(_action_recommendation_line(state, key::Build, text_field(state, building, key::name, building_id_value), direct_affordable, market_coverable, shortfall_summary, impact_line)));
		state.set(action, str(key::cost), cost);
		state.set(action, str(key::unlocked_unit_id), str(unlock_unit_id));
		state.set(action, str(key::unit_tier), int_value(unit_tier));
		state.set(action, str(key::tier_label), str(tier_label));
		state.set(action, str(key::affordability_label), str(trim_suffix(state, affordability_line, key::period)));
		state.set(action, str(key::direct_affordable), bool_value(direct_affordable));
		state.set(action, str(key::market_coverable), bool_value(market_coverable));
		state.set(action, str(key::market_summary), str(market_summary));
		state.set(action, str(key::shortfall_summary), str(shortfall_summary));
		state.set(action, str(key::disabled_reason), str(_disabled_reason_line(state, direct_affordable, market_coverable, market_summary, shortfall_summary)));
		state.set(action, str(key::disabled), bool_value(!direct_affordable));
		state.append(actions, dict_value(action));
	}
	_read_cache_store(state, session, key::build_actions, array_value(actions));
	return actions;
}

ArrayRef get_build_catalog(State &state, DictRef session) {
	const DictRef town = get_active_town(state, session);
	if (gd::is_empty(state, town)) {
		return state.new_array();
	}
	const DictRef town_template = gd::content_row(state, ContentTable::Town, ai::string_or_empty(state, town, key::town_id));
	const ArrayRef built_buildings = state.new_array();
	for (const Value &built_value : gd::field_items(state, town, str(key::built_buildings))) {
		const Atom built_id = gd::stringify(state, built_value);
		if (built_id != key::empty && !gd::array_has(state, built_buildings, str(built_id))) {
			state.append(built_buildings, str(built_id));
		}
	}
	const ArrayRef building_ids = state.new_array();
	// for source in [town_template.get("starting_building_ids", []), town_template.get("buildable_building_ids", [])]
	const Atom source_fields[] = {key::starting_building_ids, key::buildable_building_ids};
	for (const Atom source_field : source_fields) {
		Value source;
		if (!state.lookup(town_template, str(source_field), source) || !gd::is_array(source)) {
			continue;
		}
		for (const Value &building_value : gd::items(state, source)) {
			const Atom building_id = gd::stringify(state, building_value);
			if (building_id != key::empty && !gd::array_has(state, building_ids, str(building_id))) {
				state.append(building_ids, str(building_id));
			}
		}
	}
	const DictRef actions_by_building = state.new_dict();
	for (const Value &action_value : gd::items(state, array_value(get_build_actions(state, session)))) {
		if (!gd::is_dict(action_value)) {
			continue;
		}
		const DictRef action = action_value.ref;
		state.set(actions_by_building, str(building_id_for_action(state, ai::string_or_empty(state, action, key::id))), dict_value(action));
	}
	const ArrayRef catalog = state.new_array();
	for (const Value &building_id_value : gd::items(state, array_value(building_ids))) {
		const Atom building_id = gd::stringify(state, building_id_value);
		const DictRef building = gd::content_row(state, ContentTable::Building, building_id);
		if (gd::is_empty(state, building)) {
			continue;
		}
		if (town_development_rules::choice_blocked(state, town, building)) {
			continue;
		}
		const bool built = gd::array_has(state, built_buildings, str(building_id));
		const DictRef status = overworld_rules::get_town_build_status(state, town, building_id, ai::session_int(state, session, key::day));
		Value found_action;
		const DictRef action = state.lookup(actions_by_building, str(building_id), found_action) ? gd::as_dict(found_action) : state.new_dict();
		const bool has_action = !gd::is_empty(state, action);
		const DictRef row = has_action ? gd::as_dict(gd::engine_duplicate(state, dict_value(action), true)) : state.new_dict();
		Atom catalog_status = key::Locked;
		Atom status_detail = text_field(state, status, key::blocked_message, str(key::prerequisites_are_not_met));
		if (built) {
			catalog_status = key::Built;
			status_detail = key::standing_in_this_town;
		} else if (town_development_rules::satisfies(state, built_buildings, building_id)) {
			catalog_status = key::Upgraded;
			status_detail = key::replaced_by_its_higher_stage;
		} else if (has_action && gd::bool_field(state, action, key::direct_affordable, false)) {
			catalog_status = key::Ready;
			status_detail = key::ready_for_today_s_construction_order;
		} else if (has_action && gd::bool_field(state, action, key::market_coverable, false)) {
			catalog_status = key::Trade;
			status_detail = text_field(state, action, key::market_summary, str(key::trade_can_cover_the_missing_resources));
		} else if (has_action) {
			catalog_status = key::Resources;
			status_detail = text_field(state, action, key::disabled_reason, str(key::current_stores_cannot_fund_this_building));
		}
		const DictRef merged = state.new_dict();
		state.set(merged, str(key::id), str(gd::format(state, key::build_s, {str(building_id)})));
		state.set(merged, str(key::building_id), str(building_id));
		state.set(merged, str(key::name), str(text_field(state, building, key::name, str(building_id))));
		state.set(merged, str(key::label), str(gd::format(state, key::build_s_2, {str(text_field(state, building, key::name, str(building_id)))})));
		state.set(merged, str(key::category), str(text_field(state, building, key::category, str(key::support))));
		state.set(merged, str(key::description), str(text_field(state, building, key::description, str(key::empty))));
		const Value cost = field_or_new_dict(state, building, key::cost);
		state.set(merged, str(key::cost), gd::is_dict(cost) ? gd::engine_duplicate(state, cost, true) : dict_value(state.new_dict()));
		state.set(merged, str(key::effect_summary), str(_building_effect_summary(state, building)));
		state.set(merged, str(key::catalog_status), str(catalog_status));
		state.set(merged, str(key::catalog_status_detail), str(status_detail));
		state.set(merged, str(key::built), bool_value(built));
		state.set(merged, str(key::locked), bool_value(!built && !has_action));
		state.set(merged, str(key::action_available), bool_value(has_action));
		state.set(merged, str(key::disabled), bool_value(built || !has_action || gd::bool_field(state, action, key::disabled, false)));
		state.set(merged, str(key::disabled_reason), str(!has_action || built ? status_detail : ai::string_or_empty(state, action, key::disabled_reason)));
		gd::merge(state, row, merged, true);
		state.append(catalog, dict_value(row));
	}
	return catalog;
}

DictRef build_active_town(State &state, DictRef session, Atom building_id) {
	return overworld_rules::build_in_active_town(state, session, building_id);
}

Atom _build_choice_impact_line(State &state, DictRef session, DictRef town, Atom building_id, DictRef building) {
	const DictRef projected_town = gd::as_dict(gd::engine_duplicate(state, dict_value(town), true));
	Value built_value;
	const bool has_built = state.lookup(projected_town, str(key::built_buildings), built_value);
	const ArrayRef built_buildings = has_built && gd::is_array(built_value) ? gd::duplicate_array(state, built_value.ref) : state.new_array();
	if (!gd::array_has(state, built_buildings, str(building_id))) {
		state.append(built_buildings, str(building_id));
	}
	state.set(projected_town, str(key::built_buildings), array_value(built_buildings));
	const ArrayRef parts = state.new_array();
	const int64_t projected_readiness = overworld_rules::town_battle_readiness(state, projected_town, dict_value(session));
	const int64_t readiness_delta = gd::sub(projected_readiness, overworld_rules::town_battle_readiness(state, town, dict_value(session)));
	if (readiness_delta != 0) {
		state.append(parts, str(gd::format(state, key::readiness_s, {str(_signed_int(state, readiness_delta))})));
	}
	const int64_t projected_quality = overworld_rules::town_reinforcement_quality(state, projected_town, dict_value(session));
	const int64_t quality_delta = gd::sub(projected_quality, overworld_rules::town_reinforcement_quality(state, town, dict_value(session)));
	if (quality_delta != 0) {
		state.append(parts, str(gd::format(state, key::muster_quality_s, {str(_signed_int(state, quality_delta))})));
	}
	const int64_t projected_pressure = overworld_rules::town_pressure_output(state, projected_town, dict_value(session));
	const int64_t pressure_delta = gd::sub(projected_pressure, overworld_rules::town_pressure_output(state, town, dict_value(session)));
	if (pressure_delta != 0) {
		const Atom pressure_label = to_lower_ascii(state, _town_pressure_label(state, town));
		state.append(parts, str(gd::format(state, key::s_s, {str(pressure_label), str(_signed_int(state, pressure_delta))})));
	}
	const Atom unlock_unit_id = ai::string_or_empty(state, building, key::unlock_unit_id);
	if (unlock_unit_id != key::empty) {
		const DictRef unit = gd::content_row(state, ContentTable::Unit, unlock_unit_id);
		state.append(parts, str(gd::format(state, key::opens_s_recruits, {str(text_field(state, unit, key::name, str(unlock_unit_id)))})));
	}
	if (state.array_size(parts) == 0) {
		const Atom category = ai::string_or_empty(state, building, key::category);
		if (category == key::economy) {
			state.append(parts, str(key::raises_income_for_later_build_and));
		} else if (category == key::magic) {
			state.append(parts, str(key::opens_spell_access_without_changing_wall));
		} else {
			state.append(parts, str(key::steadies_the_town_without_an_immediate));
		}
	}
	return gd::format(state, key::defense_frontier_s, {str(join_array(state, key::space_bar_space, parts))});
}

Atom _action_recommendation_line(State &state, Atom lane, Atom label, bool ready, bool market_coverable, Atom shortfall_summary, Atom impact_line) {
	const Atom status = ready ? key::ready_now : (market_coverable ? key::needs_exchange_first : key::blocked);
	const ArrayRef parts = state.new_array();
	state.append(parts, str(gd::format(state, key::s_s_is_s, {str(lane), str(label), str(status)})));
	if (!ready && !market_coverable && shortfall_summary != key::empty) {
		state.append(parts, str(gd::format(state, key::blocker_s, {str(shortfall_summary)})));
	}
	if (impact_line != key::empty) {
		state.append(parts, str(impact_line));
	}
	return join_array(state, key::period_space_text, parts);
}

Atom _build_action_badge(State &state, bool ready, bool market_coverable) {
	(void)state;
	if (ready) {
		return key::Ready;
	}
	if (market_coverable) {
		return key::Trade;
	}
	return key::Blocked;
}

Atom _signed_int(State &state, int64_t value) {
	// "%+d" % value: Godot's sign flag puts "+" before a value that is not negative.
	return gd::format(state, value < 0 ? key::d_text : key::plus_d_text, {int_value(value)});
}

ArrayRef _available_building_ids(State &state, DictRef town, int64_t current_day) {
	return overworld_rules::get_town_build_options(state, town, current_day);
}

Atom _building_line(State &state, Atom building_id, Atom building_state, DictRef build_status) {
	const DictRef building = gd::content_row(state, ContentTable::Building, building_id);
	const ArrayRef parts = state.new_array();
	state.append(parts, str(text_field(state, building, key::name, str(building_id))));
	const Atom effect_summary = _building_effect_summary(state, building);
	if (effect_summary != key::empty) {
		state.append(parts, str(effect_summary));
	}
	if (building_state == key::locked) {
		const Atom blocked_message = ai::string_or_empty(state, build_status, key::blocked_message);
		if (blocked_message != key::empty) {
			state.append(parts, str(blocked_message));
		}
	}
	return join_array(state, key::space_bar_space, parts);
}

Atom _building_effect_summary(State &state, DictRef building) {
	if (gd::int_field(state, building, key::development_version, 0) == 1) {
		return ai::string_or_empty(state, building, key::description);
	}
	const ArrayRef parts = state.new_array();
	const Atom category = ai::string_or_empty(state, building, key::category);
	if (category != key::empty) {
		state.append(parts, str(gd::capitalize(state, category)));
	}
	const Atom upgrade_from = ai::string_or_empty(state, building, key::upgrade_from);
	if (upgrade_from != key::empty) {
		const DictRef upgrade_building = gd::content_row(state, ContentTable::Building, upgrade_from);
		state.append(parts, str(gd::format(state, key::upgrades_s, {str(text_field(state, upgrade_building, key::name, str(upgrade_from)))})));
	}
	const Atom income = _describe_resources(state, field_or_new_dict(state, building, key::income), key::empty);
	if (income != key::empty) {
		state.append(parts, str(gd::format(state, key::income_s, {str(income)})));
	}
	const Atom market_summary = _market_building_summary(state, building);
	if (market_summary != key::empty) {
		state.append(parts, str(market_summary));
	}
	const Atom unlock_unit_id = ai::string_or_empty(state, building, key::unlock_unit_id);
	if (unlock_unit_id != key::empty) {
		const DictRef unit = gd::content_row(state, ContentTable::Unit, unlock_unit_id);
		state.append(parts, str(gd::format(state, key::trains_s, {str(text_field(state, unit, key::name, str(unlock_unit_id)))})));
	}
	if (gd::int_field(state, building, key::spell_tier, 0) > 0) {
		state.append(parts, str(gd::format(state, key::spell_tier_d, {int_value(gd::int_field(state, building, key::spell_tier, 0))})));
	}
	const Value growth_bonus = gd::field_or(state, building, key::growth_bonus, Value());
	if (gd::is_dict(growth_bonus) && !gd::is_empty(state, growth_bonus.ref)) {
		const ArrayRef growth_parts = state.new_array();
		for (const Value &unit_id : gd::items(state, array_value(gd::keys(state, growth_bonus.ref)))) {
			const DictRef unit = gd::content_row(state, ContentTable::Unit, gd::stringify(state, unit_id));
			const int64_t bonus = gd::to_int(state, gd::index(state, growth_bonus.ref, unit_id));
			state.append(growth_parts, str(gd::format(state, key::d_s_2, {int_value(bonus), str(gd::stringify(state, state.get(unit, str(key::name), unit_id)))})));
		}
		sort_strings(state, growth_parts);
		state.append(parts, str(gd::format(state, key::growth_s, {str(join_array(state, key::comma_space, growth_parts))})));
	}
	const Value recruit_discount = gd::field_or(state, building, key::recruitment_discount_percent, Value());
	if (gd::is_dict(recruit_discount) && !gd::is_empty(state, recruit_discount.ref)) {
		const ArrayRef discount_parts = state.new_array();
		for (const Value &unit_id : gd::items(state, array_value(gd::keys(state, recruit_discount.ref)))) {
			const DictRef unit = gd::content_row(state, ContentTable::Unit, gd::stringify(state, unit_id));
			const int64_t discount = gd::to_int(state, gd::index(state, recruit_discount.ref, unit_id));
			state.append(discount_parts, str(gd::format(state, key::d_s_3, {int_value(discount), str(gd::stringify(state, state.get(unit, str(key::name), unit_id)))})));
		}
		sort_strings(state, discount_parts);
		state.append(parts, str(gd::format(state, key::discount_s, {str(join_array(state, key::comma_space, discount_parts))})));
	}
	if (gd::int_field(state, building, key::readiness_bonus, 0) > 0) {
		state.append(parts, str(gd::format(state, key::readiness_d_2, {int_value(gd::int_field(state, building, key::readiness_bonus, 0))})));
	}
	if (gd::int_field(state, building, key::pressure_bonus, 0) > 0) {
		const Atom noun = _pressure_noun_for_building(state, building);
		state.append(parts, str(gd::format(state, key::s_d_2, {str(noun), int_value(gd::int_field(state, building, key::pressure_bonus, 0))})));
	}
	if (gd::int_field(state, building, key::recovery_relief, 0) > 0) {
		state.append(parts, str(gd::format(state, key::recovery_d_day_2, {int_value(gd::int_field(state, building, key::recovery_relief, 0))})));
	}
	const Value capital_project = gd::field_or(state, building, key::capital_project, Value());
	if (gd::is_dict(capital_project) && !gd::is_empty(state, capital_project.ref)) {
		const DictRef project = capital_project.ref;
		state.append(parts, str(key::capital_project_2));
		if (gd::int_field(state, project, key::defense_bonus, 0) > 0) {
			state.append(parts, str(gd::format(state, key::defense_d, {int_value(gd::int_field(state, project, key::defense_bonus, 0))})));
		}
		if (gd::int_field(state, project, key::max_active_raids_bonus, 0) > 0) {
			state.append(parts, str(gd::format(state, key::raid_slots_d, {int_value(gd::int_field(state, project, key::max_active_raids_bonus, 0))})));
		}
		if (gd::int_field(state, project, key::recovery_guard, 0) > 0) {
			state.append(parts, str(gd::format(state, key::recovery_d_day_2, {int_value(gd::int_field(state, project, key::recovery_guard, 0))})));
		}
		const Value support_requirements = gd::field_or(state, project, key::support_requirements, Value());
		if (gd::is_dict(support_requirements) && !gd::is_empty(state, support_requirements.ref)) {
			state.append(parts, str(gd::format(state, key::needs_s_2, {str(_describe_support_requirements(state, support_requirements.ref))})));
		}
		const Value vulnerability_penalties = gd::field_or(state, project, key::vulnerability_penalties, Value());
		if (gd::is_dict(vulnerability_penalties) && !gd::is_empty(state, vulnerability_penalties.ref)) {
			state.append(parts, str(gd::format(state, key::cut_chain_s, {str(_describe_vulnerability_penalties(state, vulnerability_penalties.ref))})));
		}
	}
	return join_array(state, key::space_bar_space, parts);
}

Atom _town_name(State &state, DictRef town) {
	const DictRef town_template = gd::content_row(state, ContentTable::Town, ai::string_or_empty(state, town, key::town_id));
	return text_field(state, town_template, key::name, gd::field_or(state, town, key::town_id, str(key::Town)));
}

Atom _town_pressure_label(State &state, DictRef town) {
	const DictRef town_template = gd::content_row(state, ContentTable::Town, ai::string_or_empty(state, town, key::town_id));
	const Atom faction_id = ai::string_or_empty(state, town_template, key::faction_id);
	if (faction_id == key::faction_embercourt) {
		return key::frontier_leverage;
	}
	if (faction_id == key::faction_mireclaw) {
		return key::enemy_heroes;
	}
	if (faction_id == key::faction_sunvault) {
		return key::relay_reach;
	}
	if (faction_id == key::faction_thornwake) {
		return key::root_pressure;
	}
	if (faction_id == key::faction_brasshollow) {
		return key::siege_pressure;
	}
	if (faction_id == key::faction_veilmourn) {
		return key::fog_pressure;
	}
	return key::Pressure;
}

Atom _pressure_noun_for_building(State &state, DictRef building) {
	const Atom building_id = ai::string_or_empty(state, building, key::id);
	if (gd::begins_with(state, building_id, key::building_war_drum) || gd::begins_with(state, building_id, key::building_smugglers) || gd::begins_with(state, building_id, key::building_floodtide)) {
		return key::Pressure;
	}
	if (gd::begins_with(state, building_id, key::building_resonant) || gd::begins_with(state, building_id, key::building_harmonic) || gd::begins_with(state, building_id, key::building_aurora)) {
		return key::Reach;
	}
	if (gd::begins_with(state, building_id, key::building_thornwake)) {
		return key::Rooting;
	}
	if (gd::begins_with(state, building_id, key::building_brasshollow)) {
		return key::Pressure;
	}
	if (gd::begins_with(state, building_id, key::building_veilmourn)) {
		return key::Fog;
	}
	return key::Leverage;
}

Atom _describe_support_requirements(State &state, DictRef requirements) {
	const ArrayRef parts = state.new_array();
	for (const Value &family_id : gd::items(state, array_value(gd::keys(state, requirements)))) {
		const int64_t count = compat::engine_max<int64_t>(0, gd::to_int(state, state.get(requirements, family_id, int_value(0))));
		if (count <= 0) {
			continue;
		}
		const Atom family = gd::stringify(state, family_id);
		Atom label = family;
		if (family == key::neutral_dwelling) {
			label = key::dwelling;
		} else if (family == key::faction_outpost) {
			label = key::outpost;
		} else if (family == key::frontier_shrine) {
			label = key::shrine;
		}
		state.append(parts, str(gd::format(state, key::_d_s, {int_value(count), str(label)})));
	}
	sort_strings(state, parts);
	return join_array(state, key::comma_space, parts);
}

Atom _describe_vulnerability_penalties(State &state, DictRef penalties) {
	const ArrayRef parts = state.new_array();
	if (gd::int_field(state, penalties, key::quality_penalty, 0) > 0) {
		state.append(parts, str(gd::format(state, key::quality_d_2, {int_value(gd::int_field(state, penalties, key::quality_penalty, 0))})));
	}
	if (gd::int_field(state, penalties, key::readiness_penalty, 0) > 0) {
		state.append(parts, str(gd::format(state, key::readiness_minus_d, {int_value(gd::int_field(state, penalties, key::readiness_penalty, 0))})));
	}
	if (gd::int_field(state, penalties, key::pressure_penalty, 0) > 0) {
		state.append(parts, str(gd::format(state, key::pressure_d_2, {int_value(gd::int_field(state, penalties, key::pressure_penalty, 0))})));
	}
	if (gd::int_field(state, penalties, key::growth_penalty_percent, 0) > 0) {
		state.append(parts, str(gd::format(state, key::growth_d_2, {int_value(gd::int_field(state, penalties, key::growth_penalty_percent, 0))})));
	}
	return join_array(state, key::comma_space, parts);
}

} // namespace town_rules

} // namespace aurelion::rules::port
