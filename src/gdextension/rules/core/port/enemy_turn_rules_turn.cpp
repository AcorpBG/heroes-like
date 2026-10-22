// The computer players' day as one native call (EnemyTurnRules.run_enemy_turn),
// and the town, dwelling, boat and playback helpers the faction turns reach.

#include "aurelion_rules/port/creature_dwelling_rules_turn.hpp"
#include "aurelion_rules/port/enemy_town_services_turn.hpp"
#include "aurelion_rules/port/enemy_turn_rules_turn.hpp"
#include "aurelion_rules/port/faction_town_services_turn.hpp"
#include "aurelion_rules/port/overworld_turn_playback_turn.hpp"
#include "aurelion_rules/port/player_identity_rules_turn.hpp"
#include "aurelion_rules/port/resource_node_payload_rules_turn.hpp"
#include "aurelion_rules/port/scenario_select_rules_turn.hpp"
#include "aurelion_rules/port/town_development_rules_turn.hpp"
#include "aurelion_rules/port/town_rules_turn.hpp"
#include "aurelion_rules/port/water_travel_rules_turn.hpp"

#include "aurelion_rules/port/ai_hero_rules_turn.hpp"
#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/artifact_rules.hpp"
#include "aurelion_rules/port/artifact_rules_turn.hpp"
#include "aurelion_rules/port/content_service_ai.hpp"
#include "aurelion_rules/port/difficulty_rules.hpp"
#include "aurelion_rules/port/enemy_adventure_rules_turn.hpp"
#include "aurelion_rules/port/hero_progression_rules_turn.hpp"
#include "aurelion_rules/port/overworld_level_rules_turn.hpp"
#include "aurelion_rules/port/overworld_rules_turn.hpp"
#include "aurelion_rules/port/scenario_factory_ai.hpp"
#include "aurelion_rules/port/spell_rules.hpp"
#include "aurelion_rules/port/spell_rules_turn.hpp"
#include "aurelion_rules/port/turn_port.hpp"

#include <initializer_list>
#include <string>
#include <vector>

namespace aurelion::rules::port {

// Defined in enemy_states.cpp (Phase 5) and declared only there.
namespace enemy_turn_rules {
ArrayRef _enemy_faction_configs_for_session(State &state, DictRef session);
DictRef _find_state(State &state, const Value &states, Atom faction_id);
ArrayRef _normalize_string_array(State &state, const Value &value);
} // namespace enemy_turn_rules

namespace enemy_adventure_rules {
void normalize_all_commander_rosters(State &state, DictRef session);
} // namespace enemy_adventure_rules

namespace {

using gd::array_value;
using gd::ArrayRef;
using gd::Atom;
using gd::bool_value;
using gd::dict_value;
using gd::DictRef;
using gd::float_value;
using gd::int_value;
using gd::str;
using overworld_rules::Vector2i;
using state::ContentTable;
using state::Kind;
using state::State;
using state::Value;
namespace key = state::key;
namespace level_rules = overworld_level_rules;
namespace player_rules = player_identity_rules;

// maxi, clampi, and max() / clamp() of ints.
int64_t imax(int64_t a, int64_t b) {
	return compat::engine_max<int64_t>(a, b);
}
int64_t iclamp(int64_t x, int64_t lo, int64_t hi) {
	return compat::engine_clamp<int64_t>(x, lo, hi);
}

// String(d.get(field, fallback)).
Atom text_field(State &state, DictRef dict, Atom field, Atom fallback) {
	return gd::stringify(state, state.get(dict, str(field), str(fallback)));
}

// d.get(field, {}) and d.get(field, []) where the value is kept or written: a
// new container when the key is missing.
Value get_or_new_dict(State &state, DictRef dict, Atom field) {
	Value found;
	return state.lookup(dict, str(field), found) ? found : dict_value(state.new_dict());
}
Value get_or_new_array(State &state, DictRef dict, Atom field) {
	Value found;
	return state.lookup(dict, str(field), found) ? found : array_value(state.new_array());
}

// x.get(field, {}) of an untyped value, kept.
Value vget_or_new_dict(State &state, const Value &object, Atom field) {
	if (!gd::is_dict(object)) {
		return ai::vget(state, object, field);
	}
	return get_or_new_dict(state, object.ref, field);
}

// `d.get(field, {}) if d.get(field, {}) is Dictionary else {}`.
DictRef dict_field_or_new(State &state, DictRef dict, Atom field) {
	Value found;
	return state.lookup(dict, str(field), found) && gd::is_dict(found) ? found.ref : state.new_dict();
}

// var x: Dictionary = d.get(field, {}).
DictRef typed_dict_field(State &state, DictRef dict, Atom field) {
	Value found;
	return state.lookup(dict, str(field), found) ? gd::as_dict(found) : state.new_dict();
}

// int(d.get(outer, {}).get(inner, fallback)).
int64_t nested_int(State &state, DictRef dict, Atom outer, const Value &inner, int64_t fallback) {
	Value found;
	if (!state.lookup(dict, str(outer), found)) {
		return fallback;
	}
	return gd::to_int(state, ai::vget(state, found, inner, int_value(fallback)));
}

// a + b of Strings.
Atom join_text(State &state, Atom a, Atom b) {
	return state.intern(state.text(a) + state.text(b));
}

// separator.join(values) of an Array (each item as String(item)).
Atom join_array(State &state, const char *separator, ArrayRef values) {
	std::string joined;
	const int64_t size = state.array_size(values);
	for (int64_t index = 0; index < size; ++index) {
		if (index > 0) {
			joined += separator;
		}
		joined += state.text(gd::stringify(state, state.at(values, index)));
	}
	return state.intern(joined);
}

// s.to_lower() of ASCII text (the Unicode case tables are not ported).
Atom ascii_lower(State &state, Atom text, const char *where) {
	std::string lowered = state.text(text);
	for (char &c : lowered) {
		if (static_cast<unsigned char>(c) >= 0x80) {
			throw state::NotPorted(std::string(where) + ": to_lower() of non-ASCII text");
		}
		if (c >= 'A' && c <= 'Z') {
			c = static_cast<char>(c - 'A' + 'a');
		}
	}
	return state.intern(lowered);
}

// session.overworld of an untyped session.
DictRef overworld_of(State &state, const Value &session) {
	return session_view::overworld(state, gd::as_dict(session));
}

// {"ok": ok, "hero": hero, "message": message}.
DictRef service_outcome(State &state, bool ok, DictRef hero, Atom message) {
	const DictRef outcome = state.new_dict();
	state.set(outcome, str(key::ok), bool_value(ok));
	state.set(outcome, str(key::hero), dict_value(hero));
	state.set(outcome, str(key::message), str(message));
	return outcome;
}

// {"ok": ok, "hero": hero}.
DictRef hero_outcome(State &state, bool ok, DictRef hero) {
	const DictRef outcome = state.new_dict();
	state.set(outcome, str(key::ok), bool_value(ok));
	state.set(outcome, str(key::hero), dict_value(hero));
	return outcome;
}

// x.ok of a result Dictionary, as `if x.ok:` tests it.
bool ok_of(State &state, DictRef result) {
	return gd::truthy(state, gd::index(state, result, str(key::ok)));
}

// Levels.query_level(session, requested) of an untyped session.
int64_t query_level_of(State &state, const Value &session, int64_t requested) {
	if (session.kind == Kind::Nil) {
		return requested < 0 ? 0 : requested;
	}
	return level_rules::query_level(state, gd::as_dict(session), requested);
}

} // namespace

// CreatureDwellingRules.

namespace creature_dwelling_rules {

void take(State &state, DictRef node, DictRef site, Atom unit_id, int64_t count, int64_t day) {
	const DictRef available = population(state, node, site, day);
	state.set(available, str(unit_id), int_value(imax(0, gd::sub(gd::int_field(state, available, unit_id, 0), imax(0, count)))));
	state.set(node, str(key::dwelling_population), dict_value(available));
	state.set(node, str(key::dwelling_week), int_value(week_index(state, day)));
}

Atom guard_key(State &state, Atom placement_id) {
	return gd::format(state, key::s_s_5, { str(key::dwelling_guard_3), str(placement_id) });
}

} // namespace creature_dwelling_rules

// EnemyTownServices.

namespace enemy_town_services {

void apply_ai_weights(State &state, DictRef weights) {
	const Atom script = key::enemy_town_services_script;
	ai::assign_int(state, script, key::GOLD_RESERVE, weights, key::gold_reserve);
	ai::assign_float(state, script, key::TOWN_SPEND_SHARE, weights, key::town_spend_share);
	ai::assign_float(state, script, key::MIN_PURCHASE_GAIN, weights, key::min_purchase_gain);
	const DictRef loadout_values = state.new_dict();
	const DictRef values = gd::as_dict(gd::index(state, weights, str(key::loadout_values)));
	for (const Value &value_key : gd::items(state, dict_value(values))) {
		state.set(loadout_values, str(gd::stringify(state, value_key)), float_value(gd::to_float(gd::index(state, values, value_key))));
	}
	gd::set_static_var(state, script, key::LOADOUT_VALUES, dict_value(loadout_values));
	ai::assign_float(state, script, key::LOADOUT_GOLD_INCOME_VALUE, weights, key::loadout_gold_income_value);
	ai::assign_float(state, script, key::LOADOUT_INCOME_VALUE, weights, key::loadout_income_value);
	ai::assign_float(state, script, key::LOADOUT_SCHOOL_RESISTANCE_VALUE, weights, key::loadout_school_resistance_value);
	ai::assign_float(state, script, key::LOADOUT_SPELL_EFFECT_VALUE, weights, key::loadout_spell_effect_value);
	ai::assign_float(state, script, key::LOADOUT_MANA_COST_VALUE, weights, key::loadout_mana_cost_value);
	faction_town_services::apply_ai_weights(state, weights);
	gd::set_static_var(state, script, key::_ai_weights_ready, bool_value(true));
}

bool can_visit(State &state, DictRef town, DictRef raid, Atom controller) {
	if (!gd::equal(state, gd::field_or(state, town, key::owner, str(key::neutral)), str(key::enemy)) || player_rules::town_controller_id(state, town) != controller) {
		return false;
	}
	if (player_rules::raid_controller_id(state, raid) != controller || gd::bool_field(state, raid, key::raid_retired_to_rebuild, false)) {
		return false;
	}
	// Enemy hosts already resupply at an entrance or its cardinal approach.
	const DictRef entrance = level_rules::town_entrance(state, town);
	if (!level_rules::same_level(state, dict_value(entrance), dict_value(raid))) {
		return false;
	}
	const int64_t dx = compat::absi(gd::sub(gd::to_int(state, gd::index(state, entrance, str(key::x))), gd::int_field(state, raid, key::x, -999)));
	const int64_t dy = compat::absi(gd::sub(gd::to_int(state, gd::index(state, entrance, str(key::y))), gd::int_field(state, raid, key::y, -999)));
	return gd::add(dx, dy) <= 1;
}

DictRef upgrade_stacks(State &state, DictRef town, ArrayRef stacks, DictRef treasury) {
	const Atom script = key::enemy_town_services_script;
	if (!ai::static_bool(state, script, key::_ai_weights_ready)) {
		apply_ai_weights(state, content_service::default_ai_hero_weights(state));
	}
	ArrayRef result = gd::deep_duplicate_array(state, stacks);
	const ArrayRef upgrades = state.new_array();
	const int64_t spendable = gd::sub(gd::int_field(state, treasury, key::gold, 0), ai::static_int(state, script, key::GOLD_RESERVE));
	int64_t budget = imax(0, compat::float_to_int(static_cast<double>(spendable) * ai::static_float(state, script, key::TOWN_SPEND_SHARE)));
	const ArrayRef candidates = state.new_array();
	for (const Value &stack : gd::items(state, array_value(stacks))) {
		const Atom base = gd::stringify(state, ai::vget(state, stack, key::unit_id, str(key::empty)));
		if (!gd::array_has(state, candidates, str(base))) {
			state.append(candidates, str(base));
		}
	}
	// Highest-tier existing troops get priority; stable ids break ties.
	gd::sort_custom(state, candidates, [&](const Value &a, const Value &b) {
		const int64_t ta = gd::int_field(state, gd::content_row(state, ContentTable::Unit, gd::to_string(a)), key::tier, 0);
		const int64_t tb = gd::int_field(state, gd::content_row(state, ContentTable::Unit, gd::to_string(b)), key::tier, 0);
		return ta != tb ? ta > tb : gd::text(state, a) < gd::text(state, b);
	});
	for (const Value &base_value : gd::items(state, array_value(candidates))) {
		const Atom base = gd::to_string(base_value);
		Atom target = key::empty;
		Value upgrade_table;
		if (state.lookup(town_development_rules::data(state), str(key::unit_upgrades), upgrade_table)) {
			target = gd::stringify(state, ai::vget(state, upgrade_table, base_value, str(key::empty)));
		}
		if (target == key::empty) {
			continue;
		}
		int64_t count = 0;
		for (const Value &stack : gd::items(state, array_value(result))) {
			if (gd::equal(state, ai::vget(state, stack, key::unit_id, str(key::empty)), base_value)) {
				count = gd::add(count, gd::to_int(state, ai::vget(state, stack, key::count, int_value(0))));
			}
		}
		const DictRef cost = town_development_rules::upgrade_cost(state, base, target, count);
		if (gd::int_field(state, cost, key::gold, 0) > budget) {
			continue;
		}
		const DictRef upgraded = town_development_rules::upgrade_army(state, town, result, base, treasury);
		if (!ok_of(state, upgraded)) {
			continue;
		}
		result = gd::as_array(gd::index(state, upgraded, str(key::stacks)));
		budget = gd::sub(budget, gd::int_field(state, cost, key::gold, 0));
		const DictRef record = state.new_dict();
		state.set(record, str(key::base), base_value);
		state.set(record, str(key::target), str(target));
		state.set(record, str(key::count), int_value(count));
		state.set(record, str(key::cost), dict_value(cost));
		state.append(upgrades, dict_value(record));
	}
	const DictRef answer = state.new_dict();
	state.set(answer, str(key::stacks), array_value(result));
	state.set(answer, str(key::upgrades), array_value(upgrades));
	return answer;
}

DictRef visit(State &state, DictRef town, DictRef raid, DictRef treasury, int64_t day, Atom controller) {
	const Atom script = key::enemy_town_services_script;
	if (!ai::static_bool(state, script, key::_ai_weights_ready)) {
		apply_ai_weights(state, content_service::default_ai_hero_weights(state));
	}
	const ArrayRef changes = state.new_array();
	const ArrayRef sold_ids = state.new_array();
	if (!can_visit(state, town, raid, controller)) {
		const DictRef answer = state.new_dict();
		state.set(answer, str(key::changes), array_value(changes));
		return answer;
	}
	DictRef hero = gd::as_dict(gd::duplicate_value(state, get_or_new_dict(state, raid, key::enemy_commander_state), true));
	if (gd::is_empty(state, hero)) {
		const DictRef answer = state.new_dict();
		state.set(answer, str(key::changes), array_value(changes));
		return answer;
	}
	for (const Value &id : gd::items(state, array_value(town_development_rules::active_buildings(state, town)))) {
		const Atom building_id = gd::stringify(state, id);
		const DictRef trained = town_development_rules::train_hero(state, hero, town, building_id);
		if (ok_of(state, trained)) {
			hero = gd::as_dict(gd::index(state, trained, str(key::hero)));
			const DictRef row = gd::content_row(state, ContentTable::Building, building_id);
			state.append(changes, str(join_text(state, key::trained_at, gd::stringify(state, state.get(row, str(key::name), id)))));
		}
		const DictRef building = gd::content_row(state, ContentTable::Building, building_id);
		if (state.has(building, str(key::faction_service)) && faction_town_services::useful_to_ai(state, hero, town, building, day, treasury)) {
			const DictRef service = faction_town_services::perform(state, hero, town, building, day, treasury);
			if (ok_of(state, service)) {
				hero = gd::as_dict(gd::index(state, service, str(key::hero)));
				const Value label = ai::vmember(state, gd::index(state, building, str(key::faction_service)), key::label);
				state.append(changes, str(ascii_lower(state, gd::stringify(state, label), "EnemyTownServices.visit")));
			}
		}
	}
	const DictRef army = gd::as_dict(gd::duplicate_value(state, get_or_new_dict(state, raid, key::enemy_army), true));
	const DictRef upgraded = upgrade_stacks(state, town, gd::as_array(get_or_new_array(state, army, key::stacks)), treasury);
	if (!ai::vempty(state, gd::index(state, upgraded, str(key::upgrades)))) {
		state.set(army, str(key::stacks), gd::index(state, upgraded, str(key::stacks)));
		state.set(raid, str(key::enemy_army), dict_value(army));
		state.append(changes, str(key::upgraded_existing_troops));
	}
	bool has_exchange = false;
	for (const Value &id : gd::items(state, array_value(town_development_rules::active_buildings(state, town)))) {
		const DictRef building = gd::content_row(state, ContentTable::Building, gd::stringify(state, id));
		if (gd::truthy(state, gd::field_or(state, building, key::artifact_exchange, bool_value(false)))) {
			has_exchange = true;
		}
	}
	if (has_exchange && gd::int_field(state, hero, key::last_town_trade_day, -1) != day) {
		// Equip useful items already owned before evaluating purchases or sales.
		const Value owned = gd::duplicate_value(state, gd::index(state, artifact_rules::normalize_hero_artifacts(state, get_or_new_dict(state, hero, key::artifacts)), str(key::inventory)), false);
		for (const Value &id : gd::items(state, owned)) {
			const DictRef equipment = best_equipment(state, hero, gd::stringify(state, id));
			if (gd::to_float(gd::index(state, equipment, str(key::gain))) > 0.0) {
				hero = gd::as_dict(gd::index(state, equipment, str(key::hero)));
				state.append(changes, str(join_text(state, key::equipped_2, artifact_rules::artifact_name(state, gd::stringify(state, id)))));
			}
		}
		DictRef best = state.new_dict();
		const int64_t spendable = gd::sub(gd::int_field(state, treasury, key::gold, 0), ai::static_int(state, script, key::GOLD_RESERVE));
		const int64_t budget = imax(0, compat::float_to_int(static_cast<double>(spendable) * ai::static_float(state, script, key::TOWN_SPEND_SHARE)));
		const Atom week_key = gd::stringify(state, int_value(imax(0, compat::int_div(gd::sub(day, 1), 7))));
		const Value purchases = get_or_new_dict(state, town, key::artifact_shop_purchases);
		const ArrayRef sold = gd::as_array(ai::vget(state, purchases, str(week_key), array_value(state.new_array())));
		for (const Value &id : gd::items(state, array_value(town_development_rules::offers(state, town, day, state.new_array())))) {
			const DictRef artifact = gd::content_row(state, ContentTable::Artifact, gd::stringify(state, id));
			const int64_t cost = town_development_rules::price(state, artifact);
			if (gd::array_has(state, sold, id) || cost > budget || artifact_rules::has_artifact(state, hero, gd::stringify(state, id))) {
				continue;
			}
			const DictRef claimed = artifact_rules::claim_artifact(state, hero, gd::stringify(state, id), key::purchase_preview, false);
			if (!ok_of(state, claimed)) {
				continue;
			}
			const DictRef equipment = best_equipment(state, gd::as_dict(gd::index(state, claimed, str(key::hero))), gd::stringify(state, id));
			const double value = gd::to_float(gd::index(state, equipment, str(key::gain))) / static_cast<double>(imax(1, cost));
			if (gd::to_float(gd::index(state, equipment, str(key::gain))) >= ai::static_float(state, script, key::MIN_PURCHASE_GAIN) && (gd::is_empty(state, best) || value > gd::to_float(gd::index(state, best, str(key::value))))) {
				best = state.new_dict();
				state.set(best, str(key::id), id);
				state.set(best, str(key::value), float_value(value));
			}
		}
		if (!gd::is_empty(state, best)) {
			const DictRef bought = town_development_rules::trade_artifact(state, hero, town, day, gd::stringify(state, gd::index(state, best, str(key::id))), true, treasury, state.new_array());
			if (ok_of(state, bought)) {
				const DictRef equipped = best_equipment(state, gd::as_dict(gd::index(state, bought, str(key::hero))), gd::stringify(state, gd::index(state, best, str(key::id))));
				hero = gd::as_dict(gd::index(state, equipped, str(key::hero)));
				state.append(changes, str(join_text(state, key::bought_2, artifact_rules::artifact_name(state, gd::stringify(state, gd::index(state, best, str(key::id)))))));
			}
		}
		const Value surplus = gd::duplicate_value(state, gd::index(state, artifact_rules::normalize_hero_artifacts(state, get_or_new_dict(state, hero, key::artifacts)), str(key::inventory)), false);
		for (const Value &id : gd::items(state, surplus)) {
			const Atom artifact_id = gd::stringify(state, id);
			const DictRef artifact = gd::content_row(state, ContentTable::Artifact, artifact_id);
			if (gd::bool_field(state, artifact, key::quest_item, false) || text_field(state, artifact, key::set_id, key::empty) != key::empty) {
				continue;
			}
			const Atom artifact_class = text_field(state, artifact, key::artifact_class, key::empty);
			if (artifact_class == key::set_piece || artifact_class == key::scenario || artifact_class == key::relic) {
				continue;
			}
			if (gd::to_float(gd::index(state, best_equipment(state, hero, artifact_id), str(key::gain))) > 0.0) {
				continue;
			}
			const DictRef sale = town_development_rules::trade_artifact(state, hero, town, day, artifact_id, false, treasury, state.new_array());
			if (ok_of(state, sale)) {
				hero = gd::as_dict(gd::index(state, sale, str(key::hero)));
				state.append(sold_ids, str(artifact_id));
				state.append(changes, str(join_text(state, key::sold_surplus, artifact_rules::artifact_name(state, artifact_id))));
			}
		}
		state.set(hero, str(key::last_town_trade_day), int_value(day));
	}
	state.set(raid, str(key::enemy_commander_state), dict_value(hero));
	const DictRef answer = state.new_dict();
	state.set(answer, str(key::changes), array_value(changes));
	state.set(answer, str(key::sold_ids), array_value(sold_ids));
	return answer;
}

} // namespace enemy_town_services

// EnemyTurnRules.

namespace enemy_turn_rules {

DictRef run_enemy_turn(State &state, DictRef session, bool settle_rosters) {
	const bool profile_enabled = _enemy_turn_profile_enabled(state);
	const DictRef profile = state.new_dict();
	if (profile_enabled) {
		state.set(profile, str(key::schema_id), str(key::strategic_ai_enemy_turn_profile_v1));
		state.set(profile, str(key::day), int_value(ai::session_int(state, session, key::day)));
		state.set(profile, str(key::phases_ms), dict_value(state.new_dict()));
		state.set(profile, str(key::factions), array_value(state.new_array()));
	}
	ai_hero_rules::clear_shared_surfaces(state);
	int64_t phase_started = _profile_timer(state, profile_enabled);
	difficulty_rules::normalize_session(state, session);
	_profile_add_ms(state, profile, key::difficulty_normalize_ms, phase_started);
	phase_started = _profile_timer(state, profile_enabled);
	normalize_enemy_states(state, session);
	_profile_add_ms(state, profile, key::enemy_state_normalize_ms, phase_started);
	phase_started = _profile_timer(state, profile_enabled);
	const ArrayRef configs = _enemy_faction_configs_for_session(state, session);
	_profile_add_ms(state, profile, key::config_lookup_ms, phase_started);
	if (state.array_size(configs) == 0) {
		return _enemy_turn_result(state, true, key::empty, state.new_array(), profile_enabled, profile);
	}

	Value states = get_or_new_array(state, session_view::overworld(state, session), key::enemy_states);
	const ArrayRef messages = state.new_array();
	const ArrayRef events = state.new_array();
	const bool should_apply_weekly_growth = overworld_rules::is_weekly_growth_day(state, ai::session_int(state, session, key::day));

	// By index, reading every field again after a faction turn: its battles are
	// host calls.
	for (int64_t config_index = 0; config_index < state.array_size(configs); ++config_index) {
		const Value config_value = state.at(configs, config_index);
		if (!gd::is_dict(config_value)) {
			continue;
		}
		const DictRef config = config_value.ref;
		const Atom faction_id = player_rules::controller_id(state, config, key::empty);
		int64_t state_index = _find_state_index(state, states, faction_id);
		if (state_index < 0) {
			continue;
		}
		const Value enemy_state = ai::vindex(state, states, int_value(state_index));
		overworld_turn_playback::player_turn(state, dict_value(session), config);
		// Computer players act through heroes and towns under the human's rules.
		const DictRef turn_result = ai_hero_rules::run_faction_turn(state, session, config, gd::as_dict(enemy_state), should_apply_weekly_growth, profile_enabled);
		const DictRef latest = _latest_enemy_state(state, session, faction_id, gd::as_dict(state.get(turn_result, str(key::state), enemy_state)));
		states = state.get(session_view::overworld(state, session), str(key::enemy_states), states);
		state_index = _find_state_index(state, states, faction_id);
		if (state_index < 0) {
			continue;
		}
		if (profile_enabled) {
			const Value faction_profile = get_or_new_dict(state, turn_result, key::profile);
			if (gd::is_dict(faction_profile)) {
				state.append(gd::as_array(gd::index(state, profile, str(key::factions))), faction_profile);
			}
		}
		Value turn_messages;
		if (state.lookup(turn_result, str(key::messages), turn_messages) && gd::is_array(turn_messages)) {
			for (const Value &message : gd::items(state, turn_messages)) {
				const Atom text = gd::stringify(state, message);
				if (text != key::empty) {
					state.append(messages, str(text));
				}
			}
		}
		_append_event_records(state, events, gd::field(state, turn_result, key::events));
		state.set_at(gd::as_array(states), state_index, dict_value(latest));
	}

	phase_started = _profile_timer(state, profile_enabled);
	state.set(session_view::overworld(state, session), str(key::enemy_states), states);
	_profile_add_ms(state, profile, key::state_writeback_ms, phase_started);
	if (settle_rosters) {
		phase_started = _profile_timer(state, profile_enabled);
		enemy_adventure_rules::normalize_all_commander_rosters(state, session);
		_profile_add_ms(state, profile, key::final_commander_roster_normalize_ms, phase_started);
	}
	ai_hero_rules::clear_shared_surfaces(state);
	return _enemy_turn_result(state, true, join_array(state, " ", messages), events, profile_enabled, profile);
}

bool _enemy_turn_profile_enabled(State &state) {
	(void)state;
	// strip_edges() drops the characters up to code 32; the four answers are
	// ASCII, so an ASCII to_lower() decides them as Godot's does.
	const std::string value = turn::environment("HEROES_STRATEGIC_AI_PROFILE");
	size_t begin = 0;
	size_t end = value.size();
	while (begin < end && static_cast<unsigned char>(value[begin]) <= 32) {
		++begin;
	}
	while (end > begin && static_cast<unsigned char>(value[end - 1]) <= 32) {
		--end;
	}
	std::string lowered = value.substr(begin, end - begin);
	for (char &c : lowered) {
		if (c >= 'A' && c <= 'Z') {
			c = static_cast<char>(c - 'A' + 'a');
		}
	}
	return lowered == "1" || lowered == "true" || lowered == "yes" || lowered == "on";
}

int64_t _profile_timer(State &state, bool enabled) {
	(void)state;
	return enabled ? gd::ticks_usec() : 0;
}

void _profile_add_ms(State &state, DictRef profile, Atom key_name, int64_t started_usec) {
	if (gd::is_empty(state, profile) || key_name == key::empty || started_usec <= 0) {
		return;
	}
	const DictRef phases = dict_field_or_new(state, profile, key::phases_ms);
	const int64_t elapsed_ms = compat::float_to_int(compat::godot_round(static_cast<double>(imax(0, gd::sub(gd::ticks_usec(), started_usec))) / 1000.0));
	state.set(phases, str(key_name), int_value(gd::add(gd::int_field(state, phases, key_name, 0), elapsed_ms)));
	state.set(profile, str(key::phases_ms), dict_value(phases));
}

DictRef _enemy_turn_result(State &state, bool ok, Atom message, ArrayRef events, bool profile_enabled, DictRef profile) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(ok));
	state.set(result, str(key::message), str(message));
	state.set(result, str(key::events), array_value(events));
	if (profile_enabled) {
		state.set(result, str(key::profile), dict_value(profile));
	}
	return result;
}

void _append_event_records(State &state, ArrayRef output, const Value &events_value) {
	if (!gd::is_array(events_value)) {
		return;
	}
	for (int64_t index = 0; index < state.array_size(events_value.ref); ++index) {
		const Value event_value = state.at(events_value.ref, index);
		if (gd::is_dict(event_value) && !gd::is_empty(state, event_value.ref)) {
			state.append(output, event_value);
		}
	}
}

DictRef ai_town_build_event(State &state, DictRef session, DictRef config, DictRef town, DictRef selected_build) {
	if (gd::is_empty(state, selected_build)) {
		return state.new_dict();
	}
	const Atom building_id = text_field(state, selected_build, key::building_id, key::empty);
	if (building_id == key::empty) {
		return state.new_dict();
	}
	const DictRef actor = _town_actor(state, town);
	const DictRef target = state.new_dict();
	state.set(target, str(key::target_kind), str(key::town_building));
	state.set(target, str(key::target_placement_id), str(building_id));
	state.set(target, str(key::target_label), str(text_field(state, selected_build, key::building_label, building_id)));
	state.set(target, str(key::target_x), int_value(gd::int_field(state, town, key::x, 0)));
	state.set(target, str(key::target_y), int_value(gd::int_field(state, town, key::y, 0)));
	state.set(target, str(key::target_reason_codes), get_or_new_array(state, selected_build, key::reason_codes));
	state.set(target, str(key::target_public_reason), str(text_field(state, selected_build, key::public_reason, key::empty)));
	state.set(target, str(key::target_public_importance), str(key::medium));
	state.set(target, str(key::target_debug_reason), str(text_field(state, selected_build, key::debug_reason, key::empty)));
	const DictRef options = state.new_dict();
	state.set(options, str(key::actor_label), str(_town_name(state, town)));
	const Atom summary = gd::format(state, key::s_builds_s_s, {
			str(_town_name(state, town)),
			str(text_field(state, selected_build, key::building_label, building_id)),
			str(text_field(state, selected_build, key::public_reason, key::town_pressure)),
	});
	state.set(options, str(key::summary), str(summary));
	state.set(options, str(key::state_policy), str(key::derived));
	return enemy_adventure_rules::build_ai_event_record(state, session, config, key::ai_town_built, actor, target, options);
}

DictRef ai_town_recruit_event(State &state, DictRef session, DictRef config, DictRef town, DictRef selected_recruitment) {
	if (gd::is_empty(state, selected_recruitment)) {
		return state.new_dict();
	}
	const Atom unit_id = text_field(state, selected_recruitment, key::unit_id, key::empty);
	if (unit_id == key::empty) {
		return state.new_dict();
	}
	const DictRef destination = typed_dict_field(state, selected_recruitment, key::destination);
	const ArrayRef reason_codes = _normalize_string_array(state, gd::field(state, destination, key::reason_codes));
	if (!gd::array_has(state, reason_codes, str(key::town_recruitment))) {
		gd::push_front(state, reason_codes, str(key::town_recruitment));
	}
	const DictRef actor = _town_actor(state, town);
	const DictRef target = state.new_dict();
	state.set(target, str(key::target_kind), str(key::unit));
	state.set(target, str(key::target_placement_id), str(unit_id));
	const Atom target_label = gd::format(state, key::_d_s, {
			int_value(gd::int_field(state, selected_recruitment, key::recruit_count, 0)),
			str(text_field(state, selected_recruitment, key::unit_label, unit_id)),
	});
	state.set(target, str(key::target_label), str(target_label));
	state.set(target, str(key::target_x), int_value(gd::int_field(state, town, key::x, 0)));
	state.set(target, str(key::target_y), int_value(gd::int_field(state, town, key::y, 0)));
	state.set(target, str(key::target_reason_codes), array_value(reason_codes));
	state.set(target, str(key::target_public_reason), str(text_field(state, destination, key::public_reason, key::empty)));
	state.set(target, str(key::target_public_importance), str(key::medium));
	state.set(target, str(key::target_debug_reason), str(text_field(state, destination, key::debug_reason, key::empty)));
	const DictRef options = state.new_dict();
	state.set(options, str(key::actor_label), str(_town_name(state, town)));
	const Atom summary = gd::format(state, key::s_recruits_d_s_for_s, {
			str(_town_name(state, town)),
			int_value(gd::int_field(state, selected_recruitment, key::recruit_count, 0)),
			str(text_field(state, selected_recruitment, key::unit_label, unit_id)),
			str(text_field(state, destination, key::public_reason, key::front_pressure)),
	});
	state.set(options, str(key::summary), str(summary));
	state.set(options, str(key::state_policy), str(key::derived));
	return enemy_adventure_rules::build_ai_event_record(state, session, config, key::ai_town_recruited, actor, target, options);
}

DictRef _town_actor(State &state, DictRef town) {
	const DictRef actor = state.new_dict();
	state.set(actor, str(key::placement_id), str(text_field(state, town, key::placement_id, key::empty)));
	state.set(actor, str(key::name), str(_town_name(state, town)));
	state.set(actor, str(key::x), int_value(gd::int_field(state, town, key::x, 0)));
	state.set(actor, str(key::y), int_value(gd::int_field(state, town, key::y, 0)));
	state.set(actor, str(key::level), int_value(level_rules::level_of(state, dict_value(town))));
	return actor;
}

DictRef _latest_enemy_state(State &state, DictRef session, Atom faction_id, DictRef fallback) {
	if (faction_id == key::empty) {
		return fallback;
	}
	const DictRef latest = _find_state(state, gd::field(state, session_view::overworld(state, session), key::enemy_states), faction_id);
	if (gd::is_empty(state, latest) || gd::is_empty(state, fallback)) {
		return !gd::is_empty(state, latest) ? latest : fallback;
	}
	const DictRef merged = gd::deep_duplicate_dict(state, fallback);
	// Commander and memory helpers persist these fields directly while the
	// faction turn returns treasury and posture in its local state
	// (EnemyAdventureRules.SESSION_OWNED_ENEMY_STATE_KEYS).
	for (const Atom runtime_key : { key::commander_roster, key::known_world_memory, key::hero_task_state, key::rebuild_pressure_request }) {
		Value kept;
		if (state.lookup(latest, str(runtime_key), kept)) {
			state.set(merged, str(runtime_key), kept);
		} else {
			state.erase(merged, str(runtime_key));
		}
	}
	return merged;
}

Atom _apply_weekly_musters(State &state, DictRef session, ArrayRef town_entries, ArrayRef towns, Atom faction_id, DictRef config) {
	const ArrayRef musters = state.new_array();
	for (int64_t entry_index = 0; entry_index < state.array_size(town_entries); ++entry_index) {
		const Value entry = state.at(town_entries, entry_index);
		const Value town_value = vget_or_new_dict(state, entry, key::town);
		const DictRef town = gd::as_dict(town_value);
		const DictRef growth = overworld_rules::town_weekly_growth(state, town, dict_value(session));
		state.set(town, str(key::available_recruits), dict_value(_merge_recruits(state, gd::field(state, town, key::available_recruits), dict_value(growth))));
		state.set_at(towns, gd::to_int(state, ai::vget(state, entry, key::index, int_value(-1))), town_value);
		if (!gd::is_empty(state, growth)) {
			state.append(musters, str(gd::format(state, key::phrase_with_steps_text, { str(_town_name(state, town)), str(_describe_recruit_delta(state, dict_value(growth))) })));
		}
	}
	ai::append_array(state, musters, overworld_rules::apply_controlled_resource_site_musters(state, session, faction_id));
	if (state.array_size(musters) == 0) {
		return key::empty;
	}
	return gd::format(state, key::s_musters_fresh_levies_at_s, {
			str(text_field(state, config, key::label, faction_id)),
			str(join_array(state, "; ", musters)),
	});
}

ArrayRef _enemy_town_accessible_spell_ids(State &state, DictRef town) {
	return town_rules::accessible_spell_ids(state, town);
}

int64_t _owned_town_count(State &state, DictRef session, Atom faction_id) {
	return state.array_size(_owned_town_entries(state, session, faction_id));
}

DictRef _enemy_recruit_cost(State &state, DictRef town, Atom unit_id) {
	const DictRef unit = gd::content_row(state, ContentTable::Unit, unit_id);
	const Value cost = gd::field(state, unit, key::cost);
	const int64_t discount = _recruitment_discount_percent(state, town, unit_id);
	return _apply_discount(state, cost, discount);
}

int64_t _recruitment_discount_percent(State &state, DictRef town, Atom unit_id) {
	const DictRef town_template = gd::content_row(state, ContentTable::Town, text_field(state, town, key::town_id, key::empty));
	int64_t total_discount = _discount_from_profile(state, gd::field(state, town_template, key::recruitment), unit_id);
	const DictRef faction = gd::content_row(state, ContentTable::Faction, text_field(state, town_template, key::faction_id, key::empty));
	total_discount = gd::add(total_discount, _discount_from_profile(state, gd::field(state, faction, key::recruitment), unit_id));
	for (const Value &building_id : gd::items(state, array_value(_normalized_built_buildings(state, town)))) {
		const DictRef building = gd::content_row(state, ContentTable::Building, gd::stringify(state, building_id));
		const Value recruit_discount = gd::field(state, building, key::recruitment_discount_percent);
		if (gd::is_dict(recruit_discount)) {
			total_discount = gd::add(total_discount, gd::int_field(state, recruit_discount.ref, unit_id, 0));
		}
	}
	return iclamp(total_discount, 0, 75);
}

int64_t _discount_from_profile(State &state, const Value &profile, Atom unit_id) {
	if (!gd::is_dict(profile)) {
		return 0;
	}
	Value discounts;
	if (!state.lookup(profile.ref, str(key::cost_discount_percent), discounts)) {
		return 0;
	}
	if (!gd::is_dict(discounts)) {
		return 0;
	}
	return imax(0, gd::int_field(state, discounts.ref, unit_id, 0));
}

DictRef _building_growth_payload(State &state, Atom building_id) {
	const DictRef payload = state.new_dict();
	const DictRef building = gd::content_row(state, ContentTable::Building, building_id);
	if (gd::int_field(state, building, key::development_version, 0) == 1) {
		return town_development_rules::construction_growth(state, building);
	}
	const Atom unlock_unit_id = text_field(state, building, key::unlock_unit_id, key::empty);
	if (unlock_unit_id != key::empty) {
		state.set(payload, str(unlock_unit_id), int_value(scenario_factory::_unit_growth(state, unlock_unit_id)));
	}
	const Value growth_bonus = gd::field(state, building, key::growth_bonus);
	if (gd::is_dict(growth_bonus)) {
		for (const Value &unit_id : gd::items(state, growth_bonus)) {
			const Value id = str(gd::stringify(state, unit_id));
			state.set(payload, id, int_value(gd::add(gd::to_int(state, state.get(payload, id, int_value(0))), gd::to_int(state, gd::index(state, growth_bonus.ref, unit_id)))));
		}
	}
	return payload;
}

DictRef _merge_recruits(State &state, const Value &base, const Value &delta) {
	const DictRef merged = state.new_dict();
	if (gd::is_dict(base)) {
		for (const Value &unit_id : gd::items(state, base)) {
			state.set(merged, str(gd::stringify(state, unit_id)), int_value(imax(0, gd::to_int(state, gd::index(state, base.ref, unit_id)))));
		}
	}
	if (gd::is_dict(delta)) {
		for (const Value &unit_id : gd::items(state, delta)) {
			const Value id = str(gd::stringify(state, unit_id));
			state.set(merged, id, int_value(gd::add(gd::to_int(state, state.get(merged, id, int_value(0))), imax(0, gd::to_int(state, gd::index(state, delta.ref, unit_id))))));
		}
	}
	return merged;
}

DictRef _consume_recruits(State &state, const Value &base, Atom unit_id, int64_t amount) {
	const DictRef remaining = state.new_dict();
	if (gd::is_dict(base)) {
		for (const Value &existing_unit_id : gd::items(state, base)) {
			state.set(remaining, str(gd::stringify(state, existing_unit_id)), int_value(imax(0, gd::to_int(state, gd::index(state, base.ref, existing_unit_id)))));
		}
	}
	state.set(remaining, str(unit_id), int_value(imax(0, gd::sub(gd::int_field(state, remaining, unit_id, 0), imax(0, amount)))));
	return remaining;
}

void _spend_from_pool(State &state, DictRef pool, const Value &cost) {
	if (!gd::is_dict(cost)) {
		return;
	}
	// cost.keys() is a copy: the pool may be the cost itself.
	const ArrayRef cost_keys = gd::keys(state, cost.ref);
	for (int64_t index = 0; index < state.array_size(cost_keys); ++index) {
		const Value resource = state.at(cost_keys, index);
		const Value resource_key = str(gd::stringify(state, resource));
		const int64_t held = gd::to_int(state, state.get(pool, resource_key, int_value(0)));
		const int64_t spent = imax(0, gd::to_int(state, gd::index(state, cost.ref, resource)));
		state.set(pool, resource_key, int_value(imax(0, gd::sub(held, spent))));
	}
}

DictRef _scale_resource_pool(State &state, const Value &cost, int64_t multiplier) {
	const DictRef scaled = state.new_dict();
	if (!gd::is_dict(cost)) {
		return scaled;
	}
	for (const Value &resource : gd::items(state, cost)) {
		state.set(scaled, str(gd::stringify(state, resource)), int_value(gd::mul(imax(0, gd::to_int(state, gd::index(state, cost.ref, resource))), imax(0, multiplier))));
	}
	return scaled;
}

DictRef _apply_discount(State &state, const Value &cost, int64_t discount_percent) {
	const DictRef discounted = state.new_dict();
	const int64_t clamped_discount = iclamp(discount_percent, 0, 75);
	if (gd::is_dict(cost)) {
		for (const Value &resource : gd::items(state, cost)) {
			const Atom resource_key = gd::stringify(state, resource);
			const int64_t base_amount = imax(0, gd::to_int(state, gd::index(state, cost.ref, resource)));
			const double scaled = static_cast<double>(gd::mul(base_amount, gd::sub(100, clamped_discount))) / 100.0;
			state.set(discounted, str(resource_key), int_value(compat::float_to_int(compat::godot_ceil(scaled))));
		}
	}
	return discounted;
}

ArrayRef _normalized_built_buildings(State &state, DictRef town) {
	if (town_development_rules::is_current(state, town)) {
		return town_development_rules::active_buildings(state, town);
	}
	const ArrayRef normalized = state.new_array();
	const DictRef town_template = gd::content_row(state, ContentTable::Town, text_field(state, town, key::town_id, key::empty));
	for (const Value &building_id_value : gd::field_items(state, town_template, str(key::starting_building_ids))) {
		_append_building_with_requirements(state, normalized, gd::stringify(state, building_id_value), state.new_array());
	}
	for (const Value &building_id_value : gd::field_items(state, town, str(key::built_buildings))) {
		_append_building_with_requirements(state, normalized, gd::stringify(state, building_id_value), state.new_array());
	}
	return normalized;
}

Atom _describe_recruit_delta(State &state, const Value &delta) {
	if (!gd::is_dict(delta) || gd::is_empty(state, delta.ref)) {
		return key::empty;
	}
	const ArrayRef parts = state.new_array();
	const ArrayRef unit_ids = state.new_array();
	for (const Value &unit_id_value : gd::items(state, delta)) {
		state.append(unit_ids, str(gd::stringify(state, unit_id_value)));
	}
	gd::sort_custom(state, unit_ids, [&](const Value &a, const Value &b) { return gd::text(state, a) < gd::text(state, b); });
	for (const Value &unit_id : gd::items(state, array_value(unit_ids))) {
		const int64_t amount = gd::to_int(state, state.get(delta.ref, unit_id, int_value(0)));
		if (amount <= 0) {
			continue;
		}
		const DictRef unit = gd::content_row(state, ContentTable::Unit, gd::to_string(unit_id));
		state.append(parts, str(gd::format(state, key::d_s_2, { int_value(amount), str(gd::stringify(state, state.get(unit, str(key::name), unit_id))) })));
	}
	return join_array(state, ", ", parts);
}

int64_t _find_state_index(State &state, const Value &states, Atom faction_id) {
	if (gd::is_array(states)) {
		for (int64_t index = 0; index < state.array_size(states.ref); ++index) {
			const Value found = state.at(states.ref, index);
			if (gd::is_dict(found) && player_rules::controller_id(state, found.ref, key::empty) == faction_id) {
				return index;
			}
		}
	}
	return -1;
}

Atom _town_name(State &state, DictRef town_state) {
	const DictRef town = gd::content_row(state, ContentTable::Town, text_field(state, town_state, key::town_id, key::empty));
	return gd::stringify(state, state.get(town, str(key::name), state.get(town_state, str(key::town_id), str(key::Town))));
}

} // namespace enemy_turn_rules

// FactionTownServices.

namespace faction_town_services {

void apply_ai_weights(State &state, DictRef weights) {
	const Atom script = key::faction_town_services_script;
	ai::assign_int(state, script, key::AI_GOLD_RESERVE, weights, key::service_gold_reserve);
	ai::assign_float(state, script, key::AI_RESTORE_MANA_SHARE, weights, key::restore_mana_share);
	ai::assign_int(state, script, key::AI_EXPERIENCE_MIN_GOLD, weights, key::experience_service_min_gold);
	ai::assign_int(state, script, key::AI_EXCHANGE_MIN_KEPT, weights, key::exchange_min_kept);
	ai::assign_int(state, script, key::AI_EXCHANGE_GOLD_CAP, weights, key::exchange_gold_cap);
	ai::assign_int(state, script, key::AI_EXCHANGE_LOW_STOCK, weights, key::exchange_low_stock);
	gd::set_static_var(state, script, key::_ai_weights_ready, bool_value(true));
}

int64_t week(State &state, int64_t day) {
	(void)state;
	return imax(0, compat::int_div(gd::sub(day, 1), 7));
}

DictRef recruit_reward(State &state, DictRef town, DictRef service) {
	const DictRef reward = state.new_dict();
	for (const Value &id : gd::field_items(state, town, str(key::built_buildings))) {
		const Atom uid = text_field(state, gd::content_row(state, ContentTable::Building, gd::stringify(state, id)), key::unlock_unit_id, key::empty);
		if (uid == key::empty) {
			continue;
		}
		const DictRef unit = gd::content_row(state, ContentTable::Unit, uid);
		// JSON numbers arrive as floats; Array membership is type-sensitive.
		bool eligible = false;
		for (const Value &tier : gd::field_items(state, service, str(key::tiers))) {
			if (gd::int_field(state, unit, key::tier, 0) == gd::to_int(state, tier)) {
				eligible = true;
			}
		}
		if (!eligible) {
			continue;
		}
		const double growth = gd::to_float(gd::field_or(state, unit, key::growth, int_value(1)));
		const double growth_pct = gd::to_float(gd::field_or(state, service, key::growth_pct, int_value(100)));
		const double weekly = growth * growth_pct / 100.0;
		state.set(reward, str(uid), int_value(imax(1, compat::float_to_int(compat::godot_ceil(weekly)))));
	}
	return reward;
}

Atom unavailable_reason(State &state, DictRef hero, DictRef town, DictRef building, int64_t day, DictRef resources) {
	const DictRef service = typed_dict_field(state, building, key::faction_service);
	if (gd::is_empty(state, service)) {
		return key::this_faction_building_is_not_constructed;
	}
	Value built;
	if (!state.lookup(town, str(key::built_buildings), built) || !gd::in(state, str(text_field(state, building, key::id, key::empty)), built)) {
		return key::this_faction_building_is_not_constructed;
	}
	const DictRef holder = gd::equal(state, gd::field_or(state, service, key::scope, str(key::town)), str(key::hero)) ? hero : town;
	const Value building_key = str(gd::stringify(state, gd::index(state, building, str(key::id))));
	if (nested_int(state, holder, key::town_service_claims, building_key, -1) >= week(state, day)) {
		return key::already_used_this_week_available_again;
	}
	for (const Value &resource : gd::field_items(state, service, str(key::cost))) {
		const Value needed = ai::vindex(state, gd::index(state, service, str(key::cost)), resource);
		if (gd::to_int(state, state.get(resources, resource, int_value(0))) < gd::to_int(state, needed)) {
			const Atom name = gd::replace(state, gd::stringify(state, resource), key::_, key::space);
			return state.intern(state.text(key::not_enough) + state.text(name) + ".");
		}
	}
	if (gd::equal(state, gd::field_or(state, service, key::kind, str(key::empty)), str(key::restore_mana))) {
		const DictRef mana = spell_rules::mana_state(state, hero);
		if (gd::to_int(state, gd::index(state, mana, str(key::current))) >= gd::to_int(state, gd::index(state, mana, str(key::max)))) {
			return key::this_hero_s_mana_is_already;
		}
	}
	if (gd::equal(state, gd::field_or(state, service, key::kind, str(key::empty)), str(key::recruits)) && gd::is_empty(state, recruit_reward(state, town, service))) {
		return key::build_a_matching_creature_dwelling_first;
	}
	return key::empty;
}

DictRef perform(State &state, DictRef hero, DictRef town, DictRef building, int64_t day, DictRef resources) {
	const Atom reason = unavailable_reason(state, hero, town, building, day, resources);
	if (reason != key::empty) {
		return service_outcome(state, false, hero, reason);
	}
	const DictRef service = gd::as_dict(gd::index(state, building, str(key::faction_service)));
	DictRef result = gd::deep_duplicate_dict(state, hero);
	const Atom kind = text_field(state, service, key::kind, key::empty);
	if (kind == key::resource_exchange) {
		for (const Value &resource : gd::field_items(state, service, str(key::reward))) {
			const int64_t gained = gd::to_int(state, ai::vindex(state, gd::index(state, service, str(key::reward)), resource));
			state.set(resources, resource, int_value(gd::add(gd::to_int(state, state.get(resources, resource, int_value(0))), gained)));
		}
	} else if (kind == key::restore_mana) {
		result = spell_rules::refresh_daily_mana(state, result);
	} else if (kind == key::experience) {
		const DictRef progressed = hero_progression_rules::add_experience(state, result, gd::int_field(state, service, key::experience, 0));
		result = gd::as_dict(gd::index(state, progressed, str(key::hero)));
	} else if (kind == key::recruits) {
		const DictRef pool = gd::as_dict(gd::duplicate_value(state, get_or_new_dict(state, town, key::available_recruits), true));
		const DictRef recruits = recruit_reward(state, town, service);
		for (const Value &id : gd::items(state, dict_value(recruits))) {
			state.set(pool, id, int_value(gd::add(gd::to_int(state, state.get(pool, id, int_value(0))), gd::to_int(state, gd::index(state, recruits, id)))));
		}
		state.set(town, str(key::available_recruits), dict_value(pool));
	} else {
		return service_outcome(state, false, hero, key::unknown_faction_service);
	}
	for (const Value &resource : gd::field_items(state, service, str(key::cost))) {
		const int64_t spent = gd::to_int(state, ai::vindex(state, gd::index(state, service, str(key::cost)), resource));
		state.set(resources, resource, int_value(gd::sub(gd::to_int(state, state.get(resources, resource, int_value(0))), spent)));
	}
	const DictRef holder = gd::equal(state, gd::field_or(state, service, key::scope, str(key::town)), str(key::hero)) ? result : town;
	const DictRef claims = gd::as_dict(gd::duplicate_value(state, get_or_new_dict(state, holder, key::town_service_claims), true));
	state.set(claims, str(gd::stringify(state, gd::index(state, building, str(key::id)))), int_value(week(state, day)));
	state.set(holder, str(key::town_service_claims), dict_value(claims));
	const Value fallback = state.get(service, str(key::label), str(key::faction_service_completed));
	return service_outcome(state, true, result, gd::stringify(state, state.get(service, str(key::description), fallback)));
}

bool useful_to_ai(State &state, DictRef hero, DictRef town, DictRef building, int64_t day, DictRef resources) {
	const Atom script = key::faction_town_services_script;
	if (!ai::static_bool(state, script, key::_ai_weights_ready)) {
		apply_ai_weights(state, content_service::default_ai_hero_weights(state));
	}
	if (unavailable_reason(state, hero, town, building, day, resources) != key::empty) {
		return false;
	}
	const DictRef service = gd::as_dict(gd::index(state, building, str(key::faction_service)));
	const bool earns_gold = nested_int(state, service, key::reward, str(key::gold), 0) > nested_int(state, service, key::cost, str(key::gold), 0);
	if (!earns_gold && gd::sub(gd::int_field(state, resources, key::gold, 0), nested_int(state, service, key::cost, str(key::gold), 0)) < ai::static_int(state, script, key::AI_GOLD_RESERVE)) {
		return false;
	}
	const Atom kind = text_field(state, service, key::kind, key::empty);
	if (kind == key::restore_mana) {
		const DictRef mana = spell_rules::mana_state(state, hero);
		const double current = static_cast<double>(gd::to_int(state, gd::index(state, mana, str(key::current))));
		const double most = static_cast<double>(gd::to_int(state, gd::index(state, mana, str(key::max))));
		return current <= most * ai::static_float(state, script, key::AI_RESTORE_MANA_SHARE);
	}
	if (kind == key::experience) {
		return gd::int_field(state, resources, key::gold, 0) >= ai::static_int(state, script, key::AI_EXPERIENCE_MIN_GOLD);
	}
	if (kind == key::recruits) {
		for (const Value &id : gd::items(state, dict_value(recruit_reward(state, town, service)))) {
			const int64_t growth = gd::int_field(state, gd::content_row(state, ContentTable::Unit, gd::stringify(state, id)), key::growth, 1);
			if (nested_int(state, town, key::available_recruits, id, 0) <= growth) {
				return true;
			}
		}
		return false;
	}
	if (kind == key::resource_exchange) {
		for (const Atom resource : { key::wood, key::ore }) {
			if (gd::sub(gd::int_field(state, resources, resource, 0), nested_int(state, service, key::cost, str(resource), 0)) < ai::static_int(state, script, key::AI_EXCHANGE_MIN_KEPT)) {
				return false;
			}
		}
		const DictRef reward = typed_dict_field(state, service, key::reward);
		if (state.has(reward, str(key::gold))) {
			return gd::int_field(state, resources, key::gold, 0) < ai::static_int(state, script, key::AI_EXCHANGE_GOLD_CAP);
		}
		for (const Value &resource : gd::items(state, dict_value(reward))) {
			if (gd::to_int(state, state.get(resources, resource, int_value(0))) <= ai::static_int(state, script, key::AI_EXCHANGE_LOW_STOCK)) {
				return true;
			}
		}
	}
	return false;
}

} // namespace faction_town_services

// OverworldTurnPlayback.

namespace overworld_turn_playback {

void player_turn(State &state, const Value &session, DictRef config) {
	if (!state.has(overworld_of(state, session), str(key::_live_turn_playback))) {
		return;
	}
	const Atom controller = player_rules::controller_id(state, config, key::empty);
	const DictRef identity = player_rules::player(state, gd::as_dict(session), controller);
	const Atom faction = player_rules::faction_id(state, gd::as_dict(session), controller);
	const Atom name = text_field(state, gd::content_row(state, ContentTable::Faction, faction), key::name, faction);
	// Player id remains explicit even when multiple opponents share a faction.
	const Value shown = state.get(identity, str(key::name), state.get(identity, str(key::player_id), str(controller)));
	Atom label = gd::capitalize(state, gd::replace(state, gd::stringify(state, shown), key::_, key::space));
	if (gd::is_empty(state, identity)) {
		label = name;
	}
	const char *where = "OverworldTurnPlayback.player_turn";
	const Atom caption = ascii_lower(state, label, where) == ascii_lower(state, name, where) ? join_text(state, name, key::ai_turn) : gd::format(state, key::s_s_ai_turn, { str(label), str(name) });
	const DictRef record = state.new_dict();
	state.set(record, str(key::kind), str(key::turn));
	state.set(record, str(key::player_id), str(controller));
	state.set(record, str(key::faction_id), str(faction));
	state.set(record, str(key::caption), str(caption));
	state.append(gd::as_array(gd::index(state, overworld_of(state, session), str(key::_live_turn_playback))), dict_value(record));
}

void move(State &state, const Value &session, DictRef actor, DictRef before) {
	if (!state.has(overworld_of(state, session), str(key::_live_turn_playback))) {
		return;
	}
	const DictRef after = level_rules::position(state, actor);
	const bool from_visible = visible(state, session, before);
	const bool to_visible = visible(state, session, after);
	if (!from_visible && !to_visible) {
		return;
	}
	const bool same_level = level_rules::level_of(state, dict_value(before)) == level_rules::level_of(state, dict_value(after));
	const Atom kind = from_visible && to_visible && same_level ? key::move_ : (to_visible ? key::appear : key::disappear);
	const DictRef safe_from = from_visible ? before : after;
	const DictRef safe_to = to_visible ? after : before;
	const DictRef visual = _visual_actor(state, actor, safe_to);
	const Atom name = _actor_name(state, actor);
	const Atom suffix = kind == key::move_ ? key::is_moving : (kind == key::appear ? key::comes_into_view : key::leaves_explored_ground);
	const DictRef record = state.new_dict();
	state.set(record, str(key::kind), str(kind));
	state.set(record, str(key::actor), dict_value(visual));
	state.set(record, str(key::placement_id), str(text_field(state, actor, key::placement_id, key::empty)));
	state.set(record, str(key::from), dict_value(gd::duplicate_dict(state, safe_from)));
	state.set(record, str(key::to), dict_value(gd::duplicate_dict(state, safe_to)));
	state.set(record, str(key::caption), str(join_text(state, name, suffix)));
	state.append(gd::as_array(gd::index(state, overworld_of(state, session), str(key::_live_turn_playback))), dict_value(record));
}

void action(State &state, const Value &session, DictRef actor, Atom verb) {
	if (!state.has(overworld_of(state, session), str(key::_live_turn_playback)) || !visible(state, session, level_rules::position(state, actor))) {
		return;
	}
	const DictRef point = level_rules::position(state, actor);
	Atom cue = key::empty;
	if (verb == key::claims_a_nearby_site || verb == key::seizes_a_resource_site) {
		cue = key::vfx_placeholder_capture_flag;
	} else if (verb == key::engages_a_defending_army) {
		cue = key::vfx_placeholder_guard_warning;
	}
	const DictRef record = state.new_dict();
	state.set(record, str(key::kind), str(key::action));
	state.set(record, str(key::actor), dict_value(_visual_actor(state, actor, point)));
	state.set(record, str(key::placement_id), str(text_field(state, actor, key::placement_id, key::empty)));
	state.set(record, str(key::from), dict_value(point));
	state.set(record, str(key::to), dict_value(gd::duplicate_dict(state, point)));
	state.set(record, str(key::caption), str(state.intern(state.text(_actor_name(state, actor)) + " " + state.text(verb))));
	state.set(record, str(key::vfx_cue_id), str(cue));
	state.append(gd::as_array(gd::index(state, overworld_of(state, session), str(key::_live_turn_playback))), dict_value(record));
}

} // namespace overworld_turn_playback

// PlayerIdentityRules.

namespace player_identity_rules {

void set_resource_controller(State &state, DictRef node, const Value &session, Atom controller) {
	// player(null, id) is {}, so faction_id(null, id) is the id itself.
	const bool has_session = session.kind != Kind::Nil;
	state.set(node, str(key::collected_by_faction_id), str(has_session ? faction_id(state, gd::as_dict(session), controller) : controller));
	if (!has_session || gd::is_empty(state, player(state, gd::as_dict(session), controller))) {
		state.erase(node, str(key::collected_by_player_id));
	} else {
		state.set(node, str(key::collected_by_player_id), str(controller));
	}
}

} // namespace player_identity_rules

// ResourceNodePayloadRules.

namespace resource_node_payload_rules {

void mark_claimed(State &state, DictRef node, DictRef site) {
	if (gd::bool_field(state, site, key::persistent_control, false)) {
		state.set(node, str(key::claim_payload_spent), bool_value(true));
	}
}

} // namespace resource_node_payload_rules

// ScenarioSelectRules.

namespace scenario_select_rules {

Atom default_difficulty_id(State &state) {
	(void)state;
	return key::normal;
}

Atom normalize_difficulty(State &state, const Value &value) {
	// The ids of DIFFICULTY_OPTIONS.
	const Atom difficulty_id = gd::stringify(state, value);
	for (const Atom option_id : { key::story, key::normal, key::hard }) {
		if (option_id == difficulty_id) {
			return difficulty_id;
		}
	}
	return default_difficulty_id(state);
}

} // namespace scenario_select_rules

// TownDevelopmentRules.

namespace town_development_rules {

DictRef construction_growth(State &state, DictRef building) {
	// Dwelling upgrades convert existing reserve and never grant a second week.
	if (text_field(state, building, key::upgrade_from, key::empty) != key::empty) {
		return state.new_dict();
	}
	const Atom uid = text_field(state, building, key::unlock_unit_id, key::empty);
	const DictRef growth = state.new_dict();
	if (uid != key::empty) {
		state.set(growth, str(uid), int_value(gd::int_field(state, gd::content_row(state, ContentTable::Unit, uid), key::growth, 1)));
	}
	return growth;
}

bool can_pay(State &state, DictRef resources, DictRef cost) {
	for (const Value &resource : gd::items(state, dict_value(cost))) {
		if (gd::to_int(state, state.get(resources, resource, int_value(0))) < gd::to_int(state, gd::index(state, cost, resource))) {
			return false;
		}
	}
	return true;
}

DictRef upgrade_cost(State &state, Atom base, Atom target, int64_t count) {
	const DictRef before = typed_dict_field(state, gd::content_row(state, ContentTable::Unit, base), key::cost);
	const DictRef after = typed_dict_field(state, gd::content_row(state, ContentTable::Unit, target), key::cost);
	const DictRef cost = state.new_dict();
	for (const Value &resource : gd::items(state, dict_value(after))) {
		const int64_t raise = gd::sub(gd::to_int(state, gd::index(state, after, resource)), gd::to_int(state, state.get(before, resource, int_value(0))));
		const int64_t delta = gd::mul(imax(0, raise), count);
		if (delta > 0) {
			state.set(cost, resource, int_value(delta));
		}
	}
	return cost;
}

DictRef train_hero(State &state, DictRef hero, DictRef town, Atom building_id) {
	const DictRef building = gd::content_row(state, ContentTable::Building, building_id);
	const DictRef reward = typed_dict_field(state, building, key::hero_visit_reward);
	const ArrayRef claims = gd::as_array(gd::duplicate_value(state, get_or_new_array(state, hero, key::town_training_claims), false));
	if (!gd::array_has(state, active_buildings(state, town), str(building_id)) || gd::is_empty(state, reward) || gd::array_has(state, claims, str(building_id))) {
		return hero_outcome(state, false, hero);
	}
	DictRef trained = gd::deep_duplicate_dict(state, hero);
	if (state.has(reward, str(key::experience))) {
		const DictRef progressed = hero_progression_rules::add_experience(state, trained, gd::to_int(state, gd::index(state, reward, str(key::experience))));
		trained = gd::as_dict(gd::index(state, progressed, str(key::hero)));
	}
	const DictRef command = gd::as_dict(gd::duplicate_value(state, get_or_new_dict(state, trained, key::command), true));
	for (const Atom stat : { key::attack, key::defense, key::power, key::knowledge }) {
		state.set(command, str(stat), int_value(gd::add(gd::int_field(state, command, stat, 0), gd::int_field(state, reward, stat, 0))));
	}
	state.set(trained, str(key::command), dict_value(command));
	state.append(claims, str(building_id));
	state.set(trained, str(key::town_training_claims), array_value(claims));
	return hero_outcome(state, true, trained);
}

DictRef upgrade_army(State &state, DictRef town, ArrayRef stacks, Atom base, DictRef resources) {
	Atom target = key::empty;
	Value upgrade_table;
	if (state.lookup(data(state), str(key::unit_upgrades), upgrade_table)) {
		target = gd::stringify(state, ai::vget(state, upgrade_table, str(base), str(key::empty)));
	}
	bool available = false;
	for (const Value &id : gd::items(state, array_value(active_buildings(state, town)))) {
		if (target != key::empty && gd::equal(state, gd::field_or(state, gd::content_row(state, ContentTable::Building, gd::stringify(state, id)), key::unlock_unit_id, str(key::empty)), str(target))) {
			available = true;
		}
	}
	int64_t count = 0;
	for (const Value &stack : gd::items(state, array_value(stacks))) {
		if (gd::equal(state, ai::vget(state, stack, key::unit_id, str(key::empty)), str(base))) {
			count = gd::add(count, imax(0, gd::to_int(state, ai::vget(state, stack, key::count, int_value(0)))));
		}
	}
	const DictRef cost = upgrade_cost(state, base, target, count);
	if (!available || count <= 0 || !can_pay(state, resources, cost)) {
		const DictRef refused = state.new_dict();
		state.set(refused, str(key::ok), bool_value(false));
		state.set(refused, str(key::stacks), array_value(stacks));
		return refused;
	}
	const ArrayRef upgraded = gd::deep_duplicate_array(state, stacks);
	for (const Value &stack : gd::items(state, array_value(upgraded))) {
		if (gd::equal(state, ai::vget(state, stack, key::unit_id, str(key::empty)), str(base))) {
			state.set(gd::as_dict(stack), str(key::unit_id), str(target));
		}
	}
	for (const Value &resource : gd::items(state, dict_value(cost))) {
		state.set(resources, resource, int_value(gd::sub(gd::to_int(state, state.get(resources, resource, int_value(0))), gd::to_int(state, gd::index(state, cost, resource)))));
	}
	const DictRef answer = state.new_dict();
	state.set(answer, str(key::ok), bool_value(true));
	state.set(answer, str(key::stacks), array_value(upgraded));
	state.set(answer, str(key::count), int_value(count));
	state.set(answer, str(key::cost), dict_value(cost));
	return answer;
}

} // namespace town_development_rules

// WaterTravelRules.

namespace water_travel_rules {

DictRef boat_by_id(State &state, const Value &session, Atom boat_id) {
	for (const Value &boat : gd::items(state, array_value(boats(state, session)))) {
		if (gd::is_dict(boat) && text_field(state, boat.ref, key::id, key::empty) == boat_id) {
			return boat.ref;
		}
	}
	return state.new_dict();
}

DictRef free_boat_at(State &state, const Value &session, Vector2i tile, int64_t level) {
	level = query_level_of(state, session, level);
	for (const Value &boat : gd::items(state, array_value(boats(state, session)))) {
		if (gd::is_dict(boat) && text_field(state, boat.ref, key::hero_id, key::empty) == key::empty && gd::int_field(state, boat.ref, key::x, -1) == tile.x && gd::int_field(state, boat.ref, key::y, -1) == tile.y && gd::int_field(state, boat.ref, key::level, 0) == level) {
			return boat.ref;
		}
	}
	return state.new_dict();
}

bool any_boat_at(State &state, const Value &session, Vector2i tile, int64_t level) {
	for (const Value &boat : gd::items(state, array_value(boats(state, session)))) {
		if (gd::is_dict(boat) && gd::int_field(state, boat.ref, key::x, -1) == tile.x && gd::int_field(state, boat.ref, key::y, -1) == tile.y && gd::int_field(state, boat.ref, key::level, 0) == level) {
			return true;
		}
	}
	return false;
}

DictRef add_boat(State &state, const Value &session, Vector2i tile, int64_t level, Atom id_hint) {
	const ArrayRef list = gd::deep_duplicate_array(state, boats(state, session));
	Atom boat_id = id_hint;
	int64_t serial = 1;
	while (!gd::is_empty(state, boat_by_id(state, session, boat_id))) {
		serial = gd::add(serial, 1);
		boat_id = gd::format(state, key::s_d_4, { str(id_hint), int_value(serial) });
	}
	const DictRef boat = state.new_dict();
	state.set(boat, str(key::id), str(boat_id));
	state.set(boat, str(key::x), int_value(tile.x));
	state.set(boat, str(key::y), int_value(tile.y));
	state.set(boat, str(key::level), int_value(level));
	state.set(boat, str(key::hero_id), str(key::empty));
	state.append(list, dict_value(boat));
	state.set(overworld_of(state, session), str(key::boats), array_value(list));
	return boat;
}

void place_boat(State &state, const Value &session, Atom boat_id, Atom hero_id, Vector2i tile, int64_t level) {
	const ArrayRef list = gd::deep_duplicate_array(state, boats(state, session));
	const int64_t size = state.array_size(list);
	for (int64_t index = 0; index < size; ++index) {
		const Value boat = state.at(list, index);
		if (gd::stringify(state, ai::vget(state, boat, key::id, str(key::empty))) == boat_id) {
			const DictRef placed = gd::as_dict(boat);
			state.set(placed, str(key::hero_id), str(hero_id));
			state.set(placed, str(key::x), int_value(tile.x));
			state.set(placed, str(key::y), int_value(tile.y));
			state.set(placed, str(key::level), int_value(level));
		}
	}
	state.set(overworld_of(state, session), str(key::boats), array_value(list));
}

bool hero_at(State &state, const Value &session, Vector2i tile, int64_t level) {
	for (const Value &hero : gd::field_items(state, overworld_of(state, session), str(key::player_heroes))) {
		if (!gd::is_dict(hero)) {
			continue;
		}
		const DictRef position = dict_field_or_new(state, hero.ref, key::position);
		if (gd::int_field(state, position, key::x, -999) == tile.x && gd::int_field(state, position, key::y, -999) == tile.y && level_rules::level_of(state, dict_value(position)) == level) {
			return true;
		}
	}
	return false;
}

Atom dock_blocker(State &state, const Value &session, DictRef node) {
	const DictRef dock = dock_tile(state, session, node);
	if (gd::is_empty(state, dock)) {
		return key::this_shipyard_has_no_water_at;
	}
	const Vector2i tile = Vector2i::of(gd::to_int(state, gd::index(state, dock, str(key::x))), gd::to_int(state, gd::index(state, dock, str(key::y))));
	if (any_boat_at(state, session, tile, gd::to_int(state, gd::index(state, dock, str(key::level)))) || hero_at(state, session, tile, gd::to_int(state, gd::index(state, dock, str(key::level))))) {
		return key::a_boat_already_waits_at_the;
	}
	return key::empty;
}

Atom build_boat(State &state, const Value &session, DictRef node) {
	const Atom blocker = dock_blocker(state, session, node);
	if (blocker != key::empty) {
		return blocker;
	}
	const DictRef dock = dock_tile(state, session, node);
	const Vector2i tile = Vector2i::of(gd::to_int(state, gd::index(state, dock, str(key::x))), gd::to_int(state, gd::index(state, dock, str(key::y))));
	const int64_t level = gd::to_int(state, gd::index(state, dock, str(key::level)));
	add_boat(state, session, tile, level, gd::format(state, key::boat_s, { str(text_field(state, node, key::placement_id, key::shipyard)) }));
	return key::empty;
}

} // namespace water_travel_rules

} // namespace aurelion::rules::port
