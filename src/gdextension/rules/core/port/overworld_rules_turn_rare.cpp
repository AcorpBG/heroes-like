// OverworldRules: the paths of the computer players' day the six seeds do not run (Phase 4, slice 4.2):
// the delegating wrappers, encounter names, town metrics, resource site responses and the command risk items.

#include "aurelion_rules/port/overworld_rules_turn.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/enemy_adventure_rules_turn.hpp"
#include "aurelion_rules/port/enemy_turn_rules_turn.hpp"
#include "aurelion_rules/port/player_identity_rules.hpp"
#include "aurelion_rules/port/scenario_factory_turn.hpp"
#include "aurelion_rules/port/session_view.hpp"

#include "aurelion_rules/compat/godot_math.hpp"

#include <string>
#include <vector>

namespace aurelion::rules::port {

// Defined in scenario_evaluation.cpp (ScenarioRules._objective_met) and enemy_states.cpp
// (EnemyAdventureRules.commander_memory_brief, commander_army_brief); no header declares them.
namespace scenario_rules {
bool _objective_met(state::State &state, gd::DictRef session, gd::DictRef objective);
} // namespace scenario_rules

namespace enemy_adventure_rules {
gd::Atom commander_memory_brief(state::State &state, const state::Value &source);
gd::Atom commander_army_brief(state::State &state, const state::Value &source);
} // namespace enemy_adventure_rules

namespace {

using gd::array_value;
using gd::ArrayRef;
using gd::Atom;
using gd::bool_value;
using gd::dict_value;
using gd::DictRef;
using gd::int_value;
using gd::str;
using overworld_rules::Vector2i;
using state::ContentTable;
using state::Kind;
using state::State;
using state::Value;
namespace key = state::key;

// d.get(field, {}) / d.get(field, []) passed on or stored: the value, or a new container.
Value dict_or_new(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return dict_value(state.new_dict());
}

Value array_or_new(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return array_value(state.new_array());
}

// String(d.get(field, fallback)).
Atom text(State &state, DictRef dict, Atom field, Atom fallback) {
	return gd::stringify(state, state.get(dict, str(field), str(fallback)));
}

// String(d.get(field, fallback)) with an untyped fallback.
Atom text_or(State &state, DictRef dict, Atom field, const Value &fallback) {
	return gd::stringify(state, state.get(dict, str(field), fallback));
}

// max(0, value) of ints.
int64_t max0(int64_t value) {
	return compat::engine_max<int64_t>(0, value);
}

// max(a, b) of two ints (untyped: a, unless it is less than b).
int64_t vmax(int64_t a, int64_t b) {
	return a < b ? b : a;
}

// separator.join(parts) of Strings.
Atom join_atoms(State &state, Atom separator, const std::vector<Atom> &parts) {
	std::string joined;
	for (size_t index = 0; index < parts.size(); ++index) {
		if (index > 0) {
			joined += state.text(separator);
		}
		joined += state.text(parts[index]);
	}
	return state.intern(joined);
}

// {"index": -1, "town": {}}.
DictRef no_town(State &state) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::index), int_value(-1));
	state.set(result, str(key::town), dict_value(state.new_dict()));
	return result;
}

// var value: Dictionary = metric_context.get(field, {}).
DictRef context_dict(State &state, DictRef metric_context, Atom field) {
	Value found;
	if (state.lookup(metric_context, str(field), found)) {
		return gd::as_dict(found);
	}
	return state.new_dict();
}

// _town_logistics_state(session, town) with a session that may be null: without
// one the read scope key is "" and _compute_town_logistics_state answers
// _empty_town_logistics_state().
DictRef logistics_state_for(State &state, const Value &session, DictRef town) {
	if (session.kind == Kind::Nil) {
		return overworld_rules::_empty_town_logistics_state(state);
	}
	return overworld_rules::_town_logistics_state(state, gd::as_dict(session), town);
}

// {"key": item_key, "severity": severity, "gate": true, "summary": summary}.
DictRef risk_item(State &state, Atom item_key, int64_t severity, Atom summary) {
	const DictRef item = state.new_dict();
	state.set(item, str(key::key), str(item_key));
	state.set(item, str(key::severity), int_value(severity));
	state.set(item, str(key::gate), bool_value(true));
	state.set(item, str(key::summary), str(summary));
	return item;
}

} // namespace

namespace overworld_rules {

ArrayRef _build_scenario_town_states(State &state, const Value &placements) {
	return scenario_factory::_build_town_states(state, placements);
}

ArrayRef _build_scenario_resource_states(State &state, const Value &placements) {
	return scenario_factory::_build_resource_states(state, placements);
}

bool _scenario_objective_met(State &state, DictRef session, DictRef objective) {
	return scenario_rules::_objective_met(state, session, objective);
}

int64_t _enemy_pressure(State &state, DictRef session, Atom faction_id) {
	return enemy_turn_rules::get_pressure(state, session, faction_id);
}

bool _raid_target_is_objective_anchor(State &state, DictRef session, Atom target_kind, Atom placement_id) {
	return enemy_adventure_rules::target_is_objective_anchor(state, session, target_kind, placement_id);
}

Atom encounter_commander_name(State &state, DictRef encounter) {
	if (gd::is_empty(state, encounter) || ai::string_or_empty(state, encounter, key::spawned_by_faction_id) == key::empty) {
		return key::empty;
	}
	return enemy_adventure_rules::raid_commander_display_name(state, encounter);
}

Atom encounter_commander_threat_label(State &state, DictRef encounter) {
	const Atom commander_name = encounter_commander_name(state, encounter);
	if (commander_name == key::empty) {
		return key::empty;
	}
	const Atom memory_brief = enemy_adventure_rules::commander_memory_brief(state, dict_or_new(state, encounter, key::enemy_commander_state));
	const Atom army_brief = enemy_adventure_rules::commander_army_brief(state, dict_or_new(state, encounter, key::enemy_commander_state));
	const Atom outcome_brief = enemy_adventure_rules::commander_recent_outcome_brief(state, dict_or_new(state, encounter, key::enemy_commander_state));
	std::vector<Atom> parts;
	if (outcome_brief != key::empty) {
		parts.push_back(outcome_brief);
	}
	if (memory_brief != key::empty) {
		parts.push_back(memory_brief);
	}
	if (army_brief != key::empty) {
		parts.push_back(army_brief);
	}
	if (parts.empty()) {
		return commander_name;
	}
	return gd::format(state, key::phrase_with_steps_text, {str(commander_name), str(join_atoms(state, key::semicolon_space, parts))});
}

Atom encounter_display_name(State &state, DictRef encounter) {
	if (gd::is_empty(state, encounter)) {
		return key::hostile_contact;
	}
	if (ai::string_or_empty(state, encounter, key::spawned_by_faction_id) != key::empty) {
		const Atom raid_name = enemy_adventure_rules::raid_display_name(state, encounter);
		if (raid_name != key::empty) {
			return raid_name;
		}
	}
	const Value id_fallback = state.get(encounter, str(key::id), str(key::empty));
	const DictRef encounter_def = gd::content_row(state, ContentTable::Encounter, text_or(state, encounter, key::encounter_id, id_fallback));
	const Value name_fallback = state.get(encounter, str(key::placement_id), str(key::hostile_contact));
	return text_or(state, encounter_def, key::name, name_fallback);
}

Atom _terrain_name_at(State &state, DictRef session, int64_t x, int64_t y) {
	const Atom terrain = _terrain_id_at(state, session, x, y);
	const DictRef biome = gd::content_row(state, ContentTable::BiomeForTerrain, terrain);
	if (!gd::is_empty(state, biome)) {
		// biome.get("name", terrain.capitalize()): the fallback is computed first.
		const Atom capitalized = gd::capitalize(state, terrain);
		return text(state, biome, key::name, capitalized);
	}
	return terrain != key::empty ? gd::capitalize(state, terrain) : key::unknown_terrain;
}

DictRef town_development_metrics(State &state, DictRef town, const Value &session) {
	// A null session: the read scope key is "" (no cache), the empty logistics state.
	const Atom cache_key = session.kind == Kind::Nil ? key::empty : _town_read_scope_cache_key(state, gd::as_dict(session), key::development_metrics, town);
	if (_town_read_scope_cache_has(state, cache_key)) {
		return gd::as_dict(_town_read_scope_cache_get(state, cache_key));
	}
	const DictRef logistics = logistics_state_for(state, session, town);
	const DictRef recovery = _town_recovery_state(state, session, town, logistics);
	const DictRef capital_project = _town_capital_project_state(state, town, session, logistics, recovery);
	const DictRef occupation = _town_occupation_state(state, session, town);
	const DictRef context = state.new_dict();
	state.set(context, str(key::logistics), dict_value(logistics));
	state.set(context, str(key::recovery), dict_value(recovery));
	state.set(context, str(key::capital_project), dict_value(capital_project));
	state.set(context, str(key::occupation), dict_value(occupation));
	const int64_t quality = _town_reinforcement_quality(state, town, session, context);
	const int64_t battle_readiness = _town_battle_readiness(state, town, session, context, quality);
	const int64_t pressure_output = _town_pressure_output(state, town, session, context, quality);
	const DictRef result = state.new_dict();
	state.set(result, str(key::reinforcement_quality), int_value(quality));
	state.set(result, str(key::battle_readiness), int_value(battle_readiness));
	state.set(result, str(key::pressure_output), int_value(pressure_output));
	state.set(result, str(key::logistics), dict_value(logistics));
	state.set(result, str(key::recovery), dict_value(recovery));
	state.set(result, str(key::capital_project), dict_value(capital_project));
	state.set(result, str(key::occupation), dict_value(occupation));
	_town_read_scope_cache_store(state, cache_key, dict_value(result));
	return result;
}

DictRef _find_active_town(State &state, DictRef session) {
	const DictRef visit_result = _find_active_town_by_visit_context(state, session);
	if (gd::int_field(state, visit_result, key::index, -1) >= 0) {
		return visit_result;
	}
	const Vector2i pos = hero_position(state, session);
	const Value towns = array_or_new(state, session_view::overworld(state, session), key::towns);
	const DictRef lookup_index = _spatial_lookup_index(state, session, -1);
	// town_by_tile: the index's Dictionary, or {} (read only).
	Value town_by_tile;
	const bool has_town_by_tile = state.lookup(lookup_index, str(key::town_by_tile), town_by_tile) && gd::is_dict(town_by_tile);
	const Atom tile_key = _tile_key(state, pos);
	const int64_t index = has_town_by_tile ? gd::to_int(state, state.get(town_by_tile.ref, str(tile_key), int_value(-1))) : -1;
	if (gd::is_array(towns) && index >= 0 && index < state.array_size(towns.ref) && gd::is_dict(state.at(towns.ref, index))) {
		const DictRef result = state.new_dict();
		state.set(result, str(key::index), int_value(index));
		state.set(result, str(key::town), state.at(towns.ref, index));
		return result;
	}
	return no_town(state);
}

DictRef _find_active_town_by_visit_context(State &state, DictRef session) {
	// session == null cannot happen: a session is its view.
	const DictRef flags = gd::as_dict(gd::index(state, session, str(key::flags)));
	const Atom placement_id = ai::string_or_empty(state, flags, key::active_town_placement_id);
	if (placement_id == key::empty) {
		return no_town(state);
	}
	const DictRef town_result = _find_town_by_placement(state, session, placement_id);
	// var town: Dictionary = town_result.get("town", {}) (read only: a missing one reads as {}).
	Value town_value;
	const bool has_town = state.lookup(town_result, str(key::town), town_value);
	const DictRef town = has_town ? gd::as_dict(town_value) : 0;
	if (gd::int_field(state, town_result, key::index, -1) >= 0 && (has_town ? text(state, town, key::owner, key::neutral) : key::neutral) == key::player) {
		return town_result;
	}
	state.erase(gd::as_dict(gd::index(state, session, str(key::flags))), str(key::active_town_placement_id));
	return no_town(state);
}

DictRef _resource_site_response_profile(State &state, DictRef site) {
	static constexpr Atom kBonuses[] = {
		key::watch_days,
		key::quality_bonus,
		key::readiness_bonus,
		key::pressure_bonus,
		key::recovery_relief,
		key::pressure_guard_bonus,
		key::growth_bonus_percent,
		key::break_pressure,
	};
	const DictRef profile = state.new_dict();
	state.set(profile, str(key::action_label), str(key::empty));
	state.set(profile, str(key::summary), str(key::empty));
	state.set(profile, str(key::movement_cost), int_value(0));
	const DictRef resource_cost = state.new_dict();
	state.set(resource_cost, str(key::gold), int_value(0));
	state.set(resource_cost, str(key::wood), int_value(0));
	state.set(resource_cost, str(key::ore), int_value(0));
	state.set(profile, str(key::resource_cost), dict_value(resource_cost));
	for (const Atom bonus : kBonuses) {
		state.set(profile, str(bonus), int_value(0));
	}
	// A missing response_profile is {}: a Dictionary too.
	const Value authored_profile = dict_or_new(state, site, key::response_profile);
	if (gd::is_dict(authored_profile)) {
		const DictRef authored = authored_profile.ref;
		state.set(profile, str(key::action_label), str(ai::string_or_empty(state, authored, key::action_label)));
		state.set(profile, str(key::summary), str(ai::string_or_empty(state, authored, key::summary)));
		state.set(profile, str(key::movement_cost), int_value(max0(gd::int_field(state, authored, key::movement_cost, 0))));
		state.set(profile, str(key::resource_cost), dict_value(_normalize_resource_dict(state, dict_or_new(state, authored, key::resource_cost))));
		for (const Atom bonus : kBonuses) {
			state.set(profile, str(bonus), int_value(max0(gd::int_field(state, authored, bonus, 0))));
		}
	}
	if (ai::string_or_empty(state, profile, key::action_label) == key::empty) {
		const Atom family = ai::string_or_empty(state, site, key::family);
		Atom label = key::secure_route;
		if (family == key::mine) {
			label = key::secure_work_road;
		} else if (family == key::neutral_dwelling) {
			label = key::dispatch_relief;
		} else if (family == key::faction_outpost) {
			label = key::repair_outpost;
		} else if (family == key::frontier_shrine) {
			label = key::relight_shrine;
		} else if (family == key::scouting_structure) {
			label = key::staff_watch;
		} else if (family == key::transit_object) {
			label = key::repair_route;
		}
		state.set(profile, str(key::action_label), str(label));
	}
	// Per family: mine, neutral_dwelling, faction_outpost, frontier_shrine, scouting_structure,
	// transit_object; any other family keeps the value (the matches have no default branch).
	const auto family_default = [&](Atom field, int64_t mine, int64_t dwelling, int64_t outpost, int64_t shrine, int64_t scouting, int64_t transit) {
		if (gd::int_field(state, profile, field, 0) > 0) {
			return;
		}
		const Atom family = ai::string_or_empty(state, site, key::family);
		int64_t value = 0;
		if (family == key::mine) {
			value = mine;
		} else if (family == key::neutral_dwelling) {
			value = dwelling;
		} else if (family == key::faction_outpost) {
			value = outpost;
		} else if (family == key::frontier_shrine) {
			value = shrine;
		} else if (family == key::scouting_structure) {
			value = scouting;
		} else if (family == key::transit_object) {
			value = transit;
		} else {
			return;
		}
		state.set(profile, str(field), int_value(value));
	};
	family_default(key::pressure_guard_bonus, 1, 1, 2, 1, 2, 1);
	family_default(key::growth_bonus_percent, 3, 14, 4, 6, 3, 3);
	family_default(key::break_pressure, 1, 1, 2, 1, 2, 1);
	return profile;
}

int64_t _route_security_rating_for_hero(State &state, DictRef hero) {
	if (gd::is_empty(state, hero)) {
		return 1;
	}
	// command: hero.get("command", {}); a missing one reads as {}.
	int64_t command_total = 0;
	Value command;
	if (state.lookup(hero, str(key::command), command)) {
		const int64_t attack = gd::to_int(state, ai::vget(state, command, key::attack, int_value(0)));
		const int64_t defense = gd::to_int(state, ai::vget(state, command, key::defense, int_value(0)));
		const int64_t power = gd::to_int(state, ai::vget(state, command, key::power, int_value(0)));
		const int64_t knowledge = gd::to_int(state, ai::vget(state, command, key::knowledge, int_value(0)));
		command_total = gd::add(gd::add(gd::add(attack, defense), power), knowledge);
	}
	const int64_t level_bonus = max0(gd::sub(gd::int_field(state, hero, key::level, 1), 1));
	const int64_t rating = gd::add(1, compat::float_to_int(compat::godot_floor(static_cast<double>(gd::add(command_total, level_bonus)) / 4.0)));
	return compat::engine_clamp<int64_t>(rating, 1, 5);
}

bool _delivery_encounter_matches_node(State &state, DictRef session, DictRef encounter, DictRef node, DictRef delivery_state) {
	// session == null cannot happen: a session is its view.
	if (gd::is_empty(state, encounter) || gd::is_empty(state, node) || gd::is_empty(state, delivery_state)) {
		return false;
	}
	const Atom explicit_node_id = ai::string_or_empty(state, encounter, key::delivery_intercept_node_placement_id);
	if (explicit_node_id != key::empty && explicit_node_id == ai::string_or_empty(state, node, key::placement_id)) {
		return true;
	}
	const Atom target_kind = ai::string_or_empty(state, encounter, key::target_kind);
	if (target_kind == key::resource) {
		const Atom target_placement_id = ai::string_or_empty(state, encounter, key::target_placement_id);
		return target_placement_id == ai::string_or_empty(state, node, key::placement_id);
	}
	if (target_kind == key::town) {
		if (ai::string_or_empty(state, delivery_state, key::target_kind) != key::town) {
			return false;
		}
		const Atom target_placement_id = ai::string_or_empty(state, encounter, key::target_placement_id);
		return target_placement_id == ai::string_or_empty(state, delivery_state, key::target_id);
	}
	if (target_kind == key::hero) {
		if (ai::string_or_empty(state, delivery_state, key::target_kind) != key::hero) {
			return false;
		}
		Atom hero_target_id = ai::string_or_empty(state, encounter, key::target_placement_id);
		if (hero_target_id == key::empty) {
			hero_target_id = ai::string_or_empty(state, session_view::overworld(state, session), key::active_hero_id);
		}
		return hero_target_id != key::empty && hero_target_id == ai::string_or_empty(state, delivery_state, key::target_id);
	}
	return false;
}

DictRef _resource_site_delivery_interception(State &state, DictRef session, DictRef node, DictRef site) {
	const DictRef empty_state = state.new_dict();
	state.set(empty_state, str(key::active), bool_value(false));
	state.set(empty_state, str(key::arrived), bool_value(false));
	state.set(empty_state, str(key::blocks_delivery), bool_value(false));
	state.set(empty_state, str(key::goal_distance), int_value(9999));
	state.set(empty_state, str(key::strength), int_value(0));
	state.set(empty_state, str(key::encounter_key), str(key::empty));
	state.set(empty_state, str(key::encounter_name), str(key::empty));
	state.set(empty_state, str(key::summary), str(key::empty));
	if (gd::is_empty(state, node)) {
		return empty_state;
	}
	const DictRef delivery_state = _resource_site_delivery_state(state, session, node, site);
	if (!gd::bool_field(state, delivery_state, key::active, false) || ai::string_or_empty(state, delivery_state, key::controller_id) != key::player) {
		return empty_state;
	}
	const DictRef overworld = session_view::overworld(state, session);
	const Value resolved_encounters = array_or_new(state, overworld, key::resolved_encounters);
	DictRef best = gd::deep_duplicate_dict(state, empty_state);
	for (const Value &encounter : gd::field_items(state, overworld, str(key::encounters))) {
		if (!gd::is_dict(encounter)) {
			continue;
		}
		if (ai::string_or_empty(state, encounter.ref, key::spawned_by_faction_id) == key::empty) {
			continue;
		}
		if (gd::is_array(resolved_encounters) && gd::array_has(state, resolved_encounters.ref, str(encounter_key(state, encounter.ref)))) {
			continue;
		}
		if (!_delivery_encounter_matches_node(state, session, encounter.ref, node, delivery_state)) {
			continue;
		}
		const int64_t goal_distance = max0(gd::int_field(state, encounter.ref, key::goal_distance, 9999));
		const bool arrived = gd::bool_field(state, encounter.ref, key::arrived, false) || goal_distance <= 0;
		const int64_t strength = enemy_adventure_rules::raid_strength(state, encounter.ref);
		if (gd::bool_field(state, best, key::active, false)) {
			const bool best_arrived = gd::bool_field(state, best, key::arrived, false);
			const int64_t best_distance = gd::int_field(state, best, key::goal_distance, 9999);
			const int64_t best_strength = gd::int_field(state, best, key::strength, 0);
			if (arrived == best_arrived) {
				if (goal_distance == best_distance && strength <= best_strength) {
					continue;
				}
				if (goal_distance > best_distance) {
					continue;
				}
			} else if (!arrived) {
				continue;
			}
		}
		const Atom found_key = encounter_key(state, encounter.ref);
		const Atom found_name = encounter_display_name(state, encounter.ref);
		best = state.new_dict();
		state.set(best, str(key::active), bool_value(true));
		state.set(best, str(key::arrived), bool_value(arrived));
		state.set(best, str(key::blocks_delivery), bool_value(arrived));
		state.set(best, str(key::goal_distance), int_value(goal_distance));
		state.set(best, str(key::strength), int_value(strength));
		state.set(best, str(key::encounter_key), str(found_key));
		state.set(best, str(key::encounter_name), str(found_name));
		state.set(best, str(key::summary), str(key::empty));
	}
	const Atom encounter_name = text(state, best, key::encounter_name, key::enemy_army_3);
	const Atom target_label = text(state, delivery_state, key::target_label, key::the_front);
	if (gd::bool_field(state, best, key::active, false)) {
		if (gd::bool_field(state, best, key::blocks_delivery, false)) {
			state.set(best, str(key::summary), str(gd::format(state, key::s_is_contesting_s, {str(encounter_name), str(target_label)})));
		} else {
			const int64_t distance = gd::int_field(state, best, key::goal_distance, 0);
			const Atom plural = gd::int_field(state, best, key::goal_distance, 0) == 1 ? key::empty : key::s;
			state.set(best, str(key::summary), str(gd::format(state, key::s_closes_on_s_in_d, {str(encounter_name), str(target_label), int_value(distance), str(plural)})));
		}
	}
	return best;
}

int64_t _town_pressure_output(State &state, DictRef town, const Value &session, DictRef metric_context, int64_t reinforcement_quality) {
	const DictRef town_template = gd::content_row(state, ContentTable::Town, ai::string_or_empty(state, town, key::town_id));
	const DictRef faction = gd::content_row(state, ContentTable::Faction, ai::string_or_empty(state, town_template, key::faction_id));
	int64_t pressure = _pressure_bonus_from_profile(state, dict_or_new(state, faction, key::economy));
	pressure = gd::add(pressure, _pressure_bonus_from_profile(state, dict_or_new(state, town_template, key::economy)));
	pressure = gd::add(pressure, _town_building_bonus_total(state, town, key::pressure_bonus));
	const int64_t quality = reinforcement_quality >= 0 ? reinforcement_quality : _town_reinforcement_quality(state, town, session, metric_context);
	pressure = gd::add(pressure, compat::float_to_int(compat::godot_floor(static_cast<double>(quality) / 18.0)));
	pressure = gd::add(pressure, vmax(0, gd::sub(_town_spell_tier(state, town), 1)));
	pressure = gd::add(pressure, _town_role_pressure_bonus(state, _town_strategic_role(state, town)));
	DictRef logistics = context_dict(state, metric_context, key::logistics);
	if (gd::is_empty(state, logistics)) {
		logistics = logistics_state_for(state, session, town);
	}
	pressure = gd::add(pressure, gd::int_field(state, logistics, key::pressure_bonus, 0));
	pressure = gd::add(pressure, gd::int_field(state, logistics, key::response_pressure_bonus, 0));
	pressure = gd::sub(pressure, gd::int_field(state, logistics, key::gap_pressure_penalty, 0));
	DictRef recovery = context_dict(state, metric_context, key::recovery);
	if (gd::is_empty(state, recovery)) {
		recovery = _town_recovery_state(state, session, town, logistics);
	}
	pressure = gd::sub(pressure, gd::int_field(state, recovery, key::pressure_penalty, 0));
	DictRef capital_project = context_dict(state, metric_context, key::capital_project);
	if (gd::is_empty(state, capital_project)) {
		capital_project = _town_capital_project_state(state, town, session, logistics, recovery);
	}
	pressure = gd::add(pressure, gd::int_field(state, capital_project, key::pressure_bonus, 0));
	pressure = gd::sub(pressure, gd::int_field(state, capital_project, key::pressure_penalty, 0));
	DictRef occupation = context_dict(state, metric_context, key::occupation);
	if (gd::is_empty(state, occupation)) {
		occupation = _town_occupation_state(state, session, town);
	}
	pressure = gd::sub(pressure, gd::int_field(state, occupation, key::pressure_penalty, 0));
	return vmax(0, pressure);
}

int64_t _town_role_pressure_bonus(State &state, Atom role) {
	(void)state;
	if (role == key::capital || role == key::stronghold) {
		return 1;
	}
	return 0;
}

int64_t _pressure_bonus_from_profile(State &state, const Value &profile) {
	if (!gd::is_dict(profile)) {
		return 0;
	}
	return vmax(0, gd::int_field(state, profile.ref, key::pressure_bonus, 0));
}

Atom _town_defense_summary(State &state, DictRef town) {
	int64_t garrison_strength = 0;
	for (const Value &stack : gd::field_items(state, town, str(key::garrison))) {
		if (!gd::is_dict(stack)) {
			continue;
		}
		const DictRef unit = gd::content_row(state, ContentTable::Unit, ai::string_or_empty(state, stack.ref, key::unit_id));
		const int64_t count = vmax(0, gd::int_field(state, stack.ref, key::count, 0));
		int64_t strength = gd::int_field(state, unit, key::hp, 1);
		strength = gd::add(strength, gd::int_field(state, unit, key::min_damage, 1));
		strength = gd::add(strength, gd::int_field(state, unit, key::max_damage, 1));
		strength = gd::add(strength, gd::bool_field(state, unit, key::ranged, false) ? 3 : 0);
		garrison_strength = gd::add(garrison_strength, gd::mul(count, vmax(6, strength)));
	}
	if (garrison_strength <= 0) {
		return key::empty;
	}
	if (garrison_strength >= 260) {
		return key::fortified_walls;
	}
	if (garrison_strength >= 140) {
		return key::steady_watch;
	}
	return key::thin_watch;
}

DictRef _command_risk_pressure_objective_item(State &state, DictRef session, DictRef scenario, DictRef objective, bool include_details) {
	if (_scenario_objective_met(state, session, objective)) {
		return state.new_dict();
	}
	const Atom faction_id = ai::string_or_empty(state, objective, key::faction_id);
	const DictRef config = _enemy_config_for_faction(state, scenario, faction_id);
	if (gd::is_empty(state, config)) {
		return state.new_dict();
	}
	const int64_t current_pressure = _enemy_pressure(state, session, faction_id);
	const int64_t threshold = gd::int_field(state, objective, key::threshold, 0);
	const Atom posture = text(state, _enemy_state_for_faction(state, session, faction_id), key::posture, key::probing);
	if (current_pressure < threshold && !(posture == key::massing && gd::sub(threshold, current_pressure) <= 2)) {
		return state.new_dict();
	}
	const Value id_fallback = state.get(objective, str(key::id), str(key::pressure_objective));
	const Atom label = text_or(state, objective, key::label, id_fallback);
	const Atom item_key = gd::format(state, key::objective_pressure_s_s, {str(faction_id), str(label)});
	const Atom summary = gd::format(state, key::s_near_trigger, {str(label)});
	const DictRef item = risk_item(state, item_key, 4, summary);
	if (include_details) {
		const DictRef faction = gd::content_row(state, ContentTable::Faction, faction_id);
		const Value name_fallback = state.get(faction, str(key::name), str(faction_id));
		const Atom faction_label = text_or(state, config, key::label, name_fallback);
		const Atom detail = gd::format(state, key::s_sits_at_d_d_pressure_2, {str(faction_label), int_value(current_pressure), int_value(threshold), str(_posture_label(state, posture)), str(label)});
		state.set(item, str(key::detail), str(detail));
	}
	return item;
}

DictRef _command_risk_encounter_objective_item(State &state, DictRef session, DictRef objective, bool include_details) {
	if (_scenario_objective_met(state, session, objective)) {
		return state.new_dict();
	}
	const Atom placement_id = ai::string_or_empty(state, objective, key::placement_id);
	if (placement_id == key::empty) {
		return state.new_dict();
	}
	const DictRef overworld = session_view::overworld(state, session);
	for (const Value &encounter : gd::field_items(state, overworld, str(key::encounters))) {
		if (!gd::is_dict(encounter) || ai::string_or_empty(state, encounter.ref, key::placement_id) != placement_id) {
			continue;
		}
		const Value id_fallback = state.get(encounter.ref, str(key::id), str(key::empty));
		const DictRef encounter_def = gd::content_row(state, ContentTable::Encounter, text_or(state, encounter.ref, key::encounter_id, id_fallback));
		if (ai::string_or_empty(state, encounter.ref, key::contested_by_faction_id) != key::empty) {
			const Atom item_key = gd::format(state, key::objective_encounter_s, {str(placement_id)});
			const Atom summary = gd::format(state, key::s_objective_contested, {str(text(state, encounter_def, key::name, placement_id))});
			const DictRef item = risk_item(state, item_key, 4, summary);
			if (include_details) {
				const Atom encounter_name = text(state, encounter_def, key::name, placement_id);
				const Value label_fallback = state.get(objective, str(key::id), str(key::objective));
				const Atom label = text_or(state, objective, key::label, label_fallback);
				state.set(item, str(key::detail), str(gd::format(state, key::s_is_already_under_hostile_contest, {str(encounter_name), str(label)})));
			}
			return item;
		}
		for (const Value &raid : gd::field_items(state, overworld, str(key::encounters))) {
			if (!gd::is_dict(raid) || ai::string_or_empty(state, raid.ref, key::spawned_by_faction_id) == key::empty) {
				continue;
			}
			if (ai::string_or_empty(state, raid.ref, key::target_kind) != key::encounter || ai::string_or_empty(state, raid.ref, key::target_placement_id) != placement_id) {
				continue;
			}
			const Atom item_key = gd::format(state, key::objective_encounter_s, {str(placement_id)});
			const Atom summary = gd::format(state, key::s_objective_pressured, {str(text(state, encounter_def, key::name, placement_id))});
			const DictRef item = risk_item(state, item_key, 3, summary);
			if (include_details) {
				const Atom encounter_name = text(state, encounter_def, key::name, placement_id);
				const Value label_fallback = state.get(objective, str(key::id), str(key::objective));
				const Atom label = text_or(state, objective, key::label, label_fallback);
				state.set(item, str(key::detail), str(gd::format(state, key::s_is_drawing_hostile_pressure_and, {str(encounter_name), str(label)})));
			}
			return item;
		}
	}
	return state.new_dict();
}

Atom _town_command_risk_consequence(State &state, DictRef town, int64_t readiness, DictRef logistics, DictRef recovery, DictRef capital_project, bool objective_anchor) {
	if (gd::bool_field(state, capital_project, key::vulnerable, false) && ai::string_or_empty(state, capital_project, key::vulnerability_summary) != key::empty) {
		return ai::string_or_empty(state, capital_project, key::vulnerability_summary);
	}
	std::vector<Atom> consequence_parts;
	if (gd::int_field(state, logistics, key::gap_readiness_penalty, 0) > 0) {
		consequence_parts.push_back(gd::format(state, key::readiness_stays_d, {int_value(gd::int_field(state, logistics, key::gap_readiness_penalty, 0))}));
	}
	if (gd::int_field(state, logistics, key::gap_growth_penalty_percent, 0) > 0) {
		consequence_parts.push_back(gd::format(state, key::recruits_stay_d, {int_value(gd::int_field(state, logistics, key::gap_growth_penalty_percent, 0))}));
	}
	if (gd::bool_field(state, recovery, key::active, false)) {
		consequence_parts.push_back(gd::format(state, key::d_recovery_pressure_remains, {int_value(gd::int_field(state, recovery, key::pressure, 0))}));
	}
	if (!consequence_parts.empty()) {
		return gd::format(state, key::if_you_hold_this_posture_s, {str(join_atoms(state, key::comma_space, consequence_parts))});
	}
	if (readiness <= 18 || _town_defense_summary(state, town) == key::thin_watch) {
		return key::ending_the_day_here_leaves_a;
	}
	if (objective_anchor) {
		return key::this_lane_also_sits_on_an;
	}
	return key::another_quiet_day_leaves_the_front;
}

DictRef _enemy_config_for_faction(State &state, DictRef scenario, Atom faction_id) {
	for (const Value &config : gd::field_items(state, scenario, str(key::enemy_factions))) {
		if (gd::is_dict(config) && player_identity_rules::controller_id(state, config.ref, key::empty) == faction_id) {
			return config.ref;
		}
	}
	return state.new_dict();
}

Atom _posture_label(State &state, Atom posture) {
	(void)state;
	if (posture == key::fortifying || posture == key::raiding || posture == key::massing || posture == key::collapsed) {
		return posture;
	}
	return key::probing;
}

} // namespace overworld_rules

} // namespace aurelion::rules::port
