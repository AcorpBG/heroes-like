// OverworldRules.normalize_overworld_state (Phase 5 slice 06b, the "top"
// group): the session brought to the current save version and normalized field
// by field (difficulty, players, heroes, resources, towns, resource and
// artifact nodes, the scenario's map copies, transit, the blocked-tile index,
// fog, the command briefing and risk forecast, the scenario state), then its
// runtime signature recorded in OverworldRules._runtime_normalized_signatures.
//
// The paths AI matches never run are left to GDScript (state::NotPorted): a
// session without towns or resource nodes (built from the scenario by
// ScenarioFactory._build_town_states / _build_resource_states) and an artifact
// placement still to be drawn from a reward table
// (ArtifactRules.select_live_source_reward).

#include "aurelion_rules/port/overworld_rules.hpp"

#include "aurelion_rules/port/artifact_rules.hpp"
#include "aurelion_rules/port/difficulty_rules.hpp"
#include "aurelion_rules/port/hero_command_rules.hpp"
#include "aurelion_rules/port/native_transit_rules.hpp"
#include "aurelion_rules/port/overworld_level_rules.hpp"
#include "aurelion_rules/port/overworld_rules_ai.hpp"
#include "aurelion_rules/port/player_identity_rules.hpp"
#include "aurelion_rules/port/scenario_evaluation.hpp"
#include "aurelion_rules/port/scenario_factory.hpp"
#include "aurelion_rules/port/session_state_store.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/water_travel_rules.hpp"

#include "aurelion_rules/compat/godot_math.hpp"
#include "aurelion_rules/compat/godot_string.hpp"

#include <string>

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
using overworld_rules::Vector2i;
using state::ContentTable;
using state::State;
using state::Value;
namespace key = state::key;

[[noreturn]] void not_ported(const char *path) {
	throw state::NotPorted(std::string("left to GDScript: ") + path);
}

// String(d.get(key, fallback)).
Atom text(State &state, DictRef dict, Atom field, Atom fallback) {
	return gd::stringify_or_fallback(state, state.get(dict, str(field), str(fallback)));
}

// d.get(key, []): the field as it is, or a new Array when it is missing.
Value field_or_new_array(State &state, DictRef dict, Atom field) {
	Value found;
	return state.lookup(dict, str(field), found) ? found : array_value(state.new_array());
}

// d.get(key, {}): the field as it is, or a new Dictionary when it is missing.
Value field_or_new_dict(State &state, DictRef dict, Atom field) {
	Value found;
	return state.lookup(dict, str(field), found) ? found : dict_value(state.new_dict());
}

// d.get(key, {"x": 0, "y": 0}): the field as it is, or a new origin.
Value field_or_origin(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	const DictRef origin = state.new_dict();
	state.set(origin, str(key::x), int_value(0));
	state.set(origin, str(key::y), int_value(0));
	return dict_value(origin);
}

// not d.has(key) or not (d.get(key) is Array).
bool lacks_array(State &state, DictRef dict, Atom field) {
	Value found;
	return !state.lookup(dict, str(field), found) || !gd::is_array(found);
}

// not d.has(key) or not (d.get(key) is Dictionary).
bool lacks_dict(State &state, DictRef dict, Atom field) {
	Value found;
	return !state.lookup(dict, str(field), found) || !gd::is_dict(found);
}

// SessionStateStore.SAVE_VERSION (and SessionData.SAVE_VERSION).
constexpr int64_t kSaveVersion = 9;

// OverworldRules.LIVE_STOCKPILE_RESOURCE_KEYS and ScenarioFactory's, in order.
constexpr Atom kLiveStockpileKeys[] = {
	key::gold,
	key::wood,
	key::ore,
	key::aetherglass,
	key::embergrain,
	key::peatwax,
	key::verdant_grafts,
	key::brass_scrip,
	key::memory_salt,
};

// The loop _normalize_live_resource_stockpile and
// ScenarioFactory._normalize_resources share:
//   for key in value.keys():
//       var resource_key := String(key)
//       if resource_key == "experience" or resource_key == "": continue
//       resources[resource_key] = max(0, int(value.get(key, 0)))
// The loop writes into a new Dictionary, never into value.
void copy_resource_amounts(State &state, DictRef resources, const Value &value) {
	if (!gd::is_dict(value)) {
		return;
	}
	for (const Value &resource_key_value : gd::items(state, value)) {
		const Atom resource_key = gd::stringify_or_fallback(state, resource_key_value);
		if (resource_key == key::experience || resource_key == key::empty) {
			continue;
		}
		const int64_t amount = gd::to_int(state, state.get(value.ref, resource_key_value, int_value(0)));
		state.set(resources, str(resource_key), int_value(compat::engine_max<int64_t>(0, amount)));
	}
}

} // namespace

// OverworldRules.

namespace overworld_rules {

void normalize_overworld_state(State &state, DictRef session) {
	// if _normalized_read_scope_depth > 0 and String(session.session_id) == _normalized_read_scope_session_id: return
	if (gd::to_int(state, gd::static_var(state, key::overworld_rules_script, key::_normalized_read_scope_depth)) > 0 &&
			text(state, session, key::session_id, key::empty) == gd::to_string(gd::static_var(state, key::overworld_rules_script, key::_normalized_read_scope_session_id))) {
		return;
	}
	state.set(session, str(key::save_version), int_value(kSaveVersion));
	difficulty_rules::normalize_session(state, session);
	player_identity_rules::normalize_compatibility(state, session);

	// ContentService.get_scenario_readonly(session.scenario_id).
	const DictRef scenario = gd::content_row(state, ContentTable::Scenario, text(state, session, key::scenario_id, key::empty));
	Atom hero_id = text(state, session, key::hero_id, key::empty);
	if (hero_id == key::empty) {
		hero_id = text(state, scenario, key::hero_id, key::empty);
		state.set(session, str(key::hero_id), str(hero_id));
	}
	const Value overworld_army_id = state.get(session_view::overworld(state, session), str(key::player_army_id), str(key::empty));
	const Atom player_army_id = gd::stringify_or_fallback(state, state.get(scenario, str(key::player_army_id), overworld_army_id));
	const Value start = field_or_origin(state, scenario, key::start);
	// ContentService.get_army_group(player_army_id).
	const DictRef default_army = _build_scenario_army_state(state, gd::content_row(state, ContentTable::ArmyGroup, player_army_id));
	hero_command_rules::normalize_session(state, session, hero_id, gd::as_dict(start), default_army);

	Value resources;
	if (!state.lookup(session_view::overworld(state, session), str(key::resources), resources) || !gd::is_dict(resources) || gd::is_empty(state, resources.ref)) {
		// scenario.get("starting_resources", {}): a missing field normalizes as {} does.
		resources = dict_value(_normalize_scenario_resources(state, state.get(scenario, str(key::starting_resources), Value())));
	}
	const DictRef stockpile = _normalize_live_resource_stockpile(state, dict_value(_normalize_scenario_resources(state, resources)));
	state.set(session_view::overworld(state, session), str(key::resources), dict_value(stockpile));

	if (lacks_array(state, session_view::overworld(state, session), key::towns)) {
		// ScenarioFactory._build_town_states(scenario.get("towns", [])).
		not_ported("OverworldRules._build_scenario_town_states (a session without towns)");
	} else {
		const DictRef overworld = session_view::overworld(state, session);
		const ArrayRef towns = _normalize_towns(state, gd::as_array(gd::field(state, overworld, key::towns)), gd::to_int(state, gd::field(state, session, key::day)));
		state.set(session_view::overworld(state, session), str(key::towns), array_value(towns));
	}
	_normalize_active_town_visit_context(state, session);

	if (lacks_array(state, session_view::overworld(state, session), key::resource_nodes)) {
		// ScenarioFactory._build_resource_states(scenario.get("resource_nodes", [])).
		not_ported("OverworldRules._build_scenario_resource_states (a session without resource nodes)");
	} else {
		const DictRef overworld = session_view::overworld(state, session);
		const ArrayRef nodes = _normalize_resource_nodes(state, gd::as_array(gd::field(state, overworld, key::resource_nodes)));
		state.set(overworld, str(key::resource_nodes), array_value(nodes));
	}

	if (lacks_array(state, session_view::overworld(state, session), key::artifact_nodes)) {
		const Value placements = field_or_new_array(state, scenario, key::artifact_nodes);
		const ArrayRef nodes = artifact_rules::build_artifact_nodes(state, placements, text(state, session, key::scenario_id, key::empty));
		state.set(session_view::overworld(state, session), str(key::artifact_nodes), array_value(nodes));
	} else {
		const DictRef overworld = session_view::overworld(state, session);
		const ArrayRef nodes = _normalize_artifact_nodes(state, gd::as_array(gd::field(state, overworld, key::artifact_nodes)), text(state, session, key::scenario_id, key::empty));
		state.set(overworld, str(key::artifact_nodes), array_value(nodes));
	}

	{
		// The scenario's own containers, shared as GDScript assigns them.
		const DictRef overworld = session_view::overworld(state, session);
		if (lacks_array(state, overworld, key::encounters)) {
			state.set(overworld, str(key::encounters), field_or_new_array(state, scenario, key::encounters));
		}
		if (lacks_array(state, overworld, key::resolved_encounters)) {
			state.set(overworld, str(key::resolved_encounters), array_value(state.new_array()));
		}
		if (lacks_array(state, overworld, key::map)) {
			state.set(overworld, str(key::map), field_or_new_array(state, scenario, key::map));
		}
		if (lacks_dict(state, overworld, key::map_size)) {
			state.set(overworld, str(key::map_size), field_or_new_dict(state, scenario, key::map_size));
		}
		Value layers;
		if (!state.lookup(overworld, str(key::terrain_layers), layers) || !gd::is_dict(layers) || gd::is_empty(state, layers.ref)) {
			// ContentService.get_terrain_layers_for_scenario(session.scenario_id): a new deep copy.
			const DictRef scenario_layers = gd::content_row(state, ContentTable::TerrainLayersForScenario, text(state, session, key::scenario_id, key::empty));
			state.set(overworld, str(key::terrain_layers), dict_value(scenario_layers));
		}
	}
	_normalize_generated_runtime_materialization(state, session, scenario);
	_migrate_generated_transit_meanings(state, session);
	water_travel_rules::normalize(state, session);
	native_transit_rules::normalize_legacy_session(state, session);
	native_transit_rules::assign_network_colours(state, gd::as_array(field_or_new_array(state, session_view::overworld(state, session), key::resource_nodes)));
	if (lacks_dict(state, session_view::overworld(state, session), key::hero_position)) {
		const Value scenario_start = field_or_origin(state, scenario, key::start);
		state.set(session_view::overworld(state, session), str(key::hero_position), scenario_start);
	}
	_refresh_blocked_tile_index(state, session);
	_normalize_fog_of_war(state, session);
	_normalize_command_briefing(state, session);
	// The forecast normalizes the enemy states first; the scenario rules reuse them.
	_normalize_command_risk_forecast(state, session);

	_normalize_scenario_state_rules(state, session, false);
	_mark_runtime_normalized(state, session);
}

void _mark_runtime_normalized(State &state, DictRef session) {
	// _runtime_normalized_signatures[String(session.session_id)] = _runtime_normalization_signature(session)
	const DictRef signatures = gd::as_dict(gd::static_var(state, key::overworld_rules_script, key::_runtime_normalized_signatures));
	const Atom session_id = text(state, session, key::session_id, key::empty);
	const Atom signature = _runtime_normalization_signature(state, session);
	state.set(signatures, str(session_id), str(signature));
}

Atom _runtime_normalization_signature(State &state, DictRef session) {
	const Vector2i map_size = derive_map_size(state, session);
	const DictRef overworld = session_view::overworld(state, session);
	const Value movement_value = gd::field(state, overworld, key::movement);
	const DictRef movement = gd::is_dict(movement_value) ? movement_value.ref : state.new_dict();
	const Vector2i hero_pos = hero_position(state, session);
	const Value fog_value = gd::field(state, overworld, key::fog);
	const DictRef fog = gd::is_dict(fog_value) ? fog_value.ref : state.new_dict();

	std::string signature;
	bool first = true;
	// "|".join([...]): each part in turn.
	const auto part = [&](const std::string &value) {
		if (!first) {
			signature += '|';
		}
		first = false;
		signature += value;
	};
	const auto part_atom = [&](Atom atom) { part(state.text(atom)); };
	// str(x) / String(x) of a session field.
	const auto field_text = [&](Atom field) { part_atom(gd::stringify_or_fallback(state, gd::field(state, session, field))); };

	part(compat::itos(kSaveVersion));
	field_text(key::save_version);
	field_text(key::session_id);
	field_text(key::scenario_id);
	field_text(key::hero_id);
	field_text(key::difficulty);
	part_atom(session_state_store::normalize_launch_mode(state, gd::field(state, session, key::launch_mode)));
	field_text(key::game_state);
	field_text(key::scenario_status);
	field_text(key::day);
	part(gd::format_pair(map_size.x, map_size.y));
	part(gd::format_pair(hero_pos.x, hero_pos.y));
	part(compat::itos(hero_level(state, session)));
	// "%d/%d" % [int(movement.get("current", 0)), int(movement.get("max", 0))]
	const int64_t movement_current = gd::int_field(state, movement, key::current, 0);
	const int64_t movement_max = gd::int_field(state, movement, key::max, 0);
	part(compat::itos(movement_current) + "/" + compat::itos(movement_max));
	// str(_collection_size(session.overworld.get(field, [] or {}))): a missing
	// field counts 0, as its empty fallback does.
	for (const Atom field : { key::map, key::terrain_layers, key::towns, key::resource_nodes, key::artifact_nodes, key::encounters, key::resolved_encounters, key::player_heroes }) {
		part(compat::itos(_collection_size(state, gd::field(state, session_view::overworld(state, session), field))));
	}
	part_atom(gd::stringify_or_fallback(state, state.get(fog, str(key::visible_count), int_value(-1))));
	part_atom(gd::stringify_or_fallback(state, state.get(fog, str(key::explored_count), int_value(-1))));
	const DictRef flags = gd::as_dict(gd::field(state, session, key::flags));
	part_atom(text(state, flags, key::active_town_placement_id, key::empty));
	return state.intern(signature);
}

DictRef _build_scenario_army_state(State &state, DictRef army_template) {
	return scenario_factory::_build_army_state(state, army_template);
}

DictRef _normalize_scenario_resources(State &state, const Value &value) {
	return scenario_factory::_normalize_resources(state, value);
}

DictRef _normalize_live_resource_stockpile(State &state, const Value &value) {
	const DictRef normalized = _empty_live_resource_stockpile(state);
	copy_resource_amounts(state, normalized, value);
	return normalized;
}

ArrayRef _normalize_artifact_nodes(State &state, ArrayRef nodes, Atom scenario_id) {
	return artifact_rules::normalize_artifact_nodes(state, array_value(nodes), scenario_id);
}

void _normalize_scenario_state_rules(State &state, DictRef session, bool normalize_enemies) {
	scenario_rules::normalize_scenario_state(state, session, normalize_enemies);
}

void _refresh_blocked_tile_index(State &state, DictRef session) {
	// bool(_pathing_debug_profile.get("capture_enabled", false)): the debug
	// capture, off in games and matches.
	const DictRef profile = gd::as_dict(gd::static_var(state, key::overworld_rules_script, key::_pathing_debug_profile));
	const bool capture_enabled = gd::bool_field(state, profile, key::capture_enabled, false);
	const int64_t started_usec = capture_enabled ? gd::ticks_usec() : 0;
	const DictRef level_indexes = state.new_dict();
	const int64_t level_count = overworld_level_rules::level_count(state, session);
	for (int64_t level = 0; level < level_count; ++level) {
		const DictRef index = _build_blocked_tile_index(state, session, level, key::empty, state.new_dict());
		state.set(level_indexes, int_value(level), dict_value(index));
	}
	// session.set_meta(BLOCKED_TILE_INDEX_META, level_indexes).
	state.set(session_view::meta(state, session), gd::name_value(key::_overworld_blocked_tile_indexes), dict_value(level_indexes));
	// The rules profile's blocked_index section (_rules_profile_set) is not recorded.
	if (!capture_enabled) {
		return;
	}
	// var index: Dictionary = level_indexes.get(hero_level(session), {})
	const Value index_value = state.get(level_indexes, int_value(hero_level(state, session)), Value());
	const int64_t tile_count = gd::is_dict(index_value) ? state.dict_size(index_value.ref) : 0;
	const int64_t elapsed_usec = compat::engine_max<int64_t>(0, gd::sub(gd::ticks_usec(), started_usec));
	state.set(profile, str(key::blocked_index_rebuild_count), int_value(gd::add(gd::int_field(state, profile, key::blocked_index_rebuild_count, 0), 1)));
	state.set(profile, str(key::last_blocked_index_rebuild_usec), int_value(elapsed_usec));
	state.set(profile, str(key::last_blocked_index_tile_count), int_value(tile_count));
	state.set(profile, str(key::last_blocked_index_session_id), str(gd::stringify_or_fallback(state, gd::field(state, session, key::session_id))));
}

void _normalize_command_briefing(State &state, DictRef session) {
	const Atom scenario_id = text(state, session, key::scenario_id, key::empty);
	if (scenario_id == key::empty) {
		return;
	}
	Value briefing_value;
	DictRef briefing_state;
	if (state.lookup(session_view::overworld(state, session), str(key::command_briefing), briefing_value) && gd::is_dict(briefing_value)) {
		briefing_state = briefing_value.ref;
	} else {
		briefing_state = state.new_dict();
	}
	// "%s|%s" % [session.scenario_id, SessionStateStore.normalize_launch_mode(session.launch_mode)]
	const Atom launch_mode = session_state_store::normalize_launch_mode(state, gd::field(state, session, key::launch_mode));
	const Atom signature = state.intern(state.text(scenario_id) + "|" + state.text(launch_mode));
	if (text(state, briefing_state, key::signature, key::empty) != signature) {
		briefing_state = state.new_dict();
		state.set(briefing_state, str(key::signature), str(signature));
		state.set(briefing_state, str(key::shown), bool_value(false));
		state.set(briefing_state, str(key::shown_day), int_value(0));
	} else {
		state.set(briefing_state, str(key::signature), str(signature));
		state.set(briefing_state, str(key::shown), bool_value(gd::bool_field(state, briefing_state, key::shown, false)));
		state.set(briefing_state, str(key::shown_day), int_value(compat::engine_max<int64_t>(0, gd::int_field(state, briefing_state, key::shown_day, 0))));
	}
	if (!gd::bool_field(state, briefing_state, key::shown, false)) {
		const int64_t day = gd::to_int(state, gd::field(state, session, key::day));
		if (day > 1 || text(state, gd::as_dict(gd::field(state, session, key::flags)), key::last_action, key::empty) != key::empty) {
			state.set(briefing_state, str(key::shown), bool_value(true));
			state.set(briefing_state, str(key::shown_day), int_value(compat::engine_max<int64_t>(1, day)));
		}
	}
	state.set(session_view::overworld(state, session), str(key::command_briefing), dict_value(briefing_state));
}

} // namespace overworld_rules

// ScenarioFactory.

namespace scenario_factory {

DictRef _build_army_state(State &state, DictRef army_template) {
	const ArrayRef stacks = state.new_array();
	for (const Value &stack : gd::field_items(state, army_template, str(key::stacks))) {
		if (!gd::is_dict(stack)) {
			continue;
		}
		const DictRef entry = state.new_dict();
		state.set(entry, str(key::unit_id), str(text(state, stack.ref, key::unit_id, key::empty)));
		state.set(entry, str(key::count), int_value(compat::engine_max<int64_t>(0, gd::int_field(state, stack.ref, key::count, 0))));
		state.append(stacks, dict_value(entry));
	}

	const DictRef army = state.new_dict();
	state.set(army, str(key::id), str(text(state, army_template, key::id, key::empty)));
	state.set(army, str(key::name), str(text(state, army_template, key::name, key::field_army)));
	state.set(army, str(key::stacks), array_value(stacks));
	return army;
}

DictRef _normalize_resources(State &state, const Value &value) {
	const DictRef resources = state.new_dict();
	for (const Atom resource_key : kLiveStockpileKeys) {
		state.set(resources, str(resource_key), int_value(0));
	}
	copy_resource_amounts(state, resources, value);
	return resources;
}

} // namespace scenario_factory

// ArtifactRules.

namespace artifact_rules {

ArrayRef build_artifact_nodes(State &state, const Value &placements, Atom scenario_id) {
	// scenario_id names the reward-table draw's source key only, which is left to GDScript.
	(void)scenario_id;
	const ArrayRef nodes = state.new_array();
	if (!gd::is_array(placements)) {
		return nodes;
	}

	for (const Value &placement_value : gd::items(state, placements)) {
		if (!gd::is_dict(placement_value)) {
			continue;
		}
		const DictRef placement = placement_value.ref;
		const Atom placement_id = text(state, placement, key::placement_id, key::empty);
		const Atom artifact_id = text(state, placement, key::artifact_id, key::empty);
		const Atom table_id = gd::strip_edges(state, text(state, placement, key::artifact_reward_table_id, key::empty));
		const Atom source_key = gd::strip_edges(state, text(state, placement, key::artifact_reward_source_key, key::empty));
		const bool materialized = gd::bool_field(state, placement, key::artifact_source_materialized, false);
		if (table_id != key::empty && !materialized) {
			// select_live_source_reward("pickup", source_record, source_key).
			not_ported("ArtifactRules.select_live_source_reward (an artifact placement still to be drawn from a reward table)");
		}

		const DictRef node = state.new_dict();
		state.set(node, str(key::placement_id), str(placement_id));
		state.set(node, str(key::artifact_id), str(artifact_id));
		state.set(node, str(key::x), int_value(gd::int_field(state, placement, key::x, 0)));
		state.set(node, str(key::y), int_value(gd::int_field(state, placement, key::y, 0)));
		state.set(node, str(key::collected), bool_value(gd::bool_field(state, placement, key::collected, false)));
		state.set(node, str(key::collected_by_faction_id), str(text(state, placement, key::collected_by_faction_id, key::empty)));
		state.set(node, str(key::collected_day), int_value(compat::engine_max<int64_t>(0, gd::int_field(state, placement, key::collected_day, 0))));
		Value level;
		if (state.lookup(placement, str(key::level), level)) {
			state.set(node, str(key::level), int_value(gd::to_int(state, level)));
		}
		if (text(state, placement, key::collected_by_player_id, key::empty) != key::empty) {
			// String(placement.collected_by_player_id).
			const Value player_id = gd::index(state, placement, str(key::collected_by_player_id));
			state.set(node, str(key::collected_by_player_id), str(gd::stringify_or_fallback(state, player_id)));
		}
		if (table_id != key::empty) {
			state.set(node, str(key::artifact_reward_table_id), str(table_id));
			state.set(node, str(key::artifact_reward_source_key), str(source_key));
			state.set(node, str(key::artifact_source_materialized), bool_value(materialized));
		}
		state.append(nodes, dict_value(node));
	}
	return nodes;
}

ArrayRef normalize_artifact_nodes(State &state, const Value &nodes, Atom scenario_id) {
	return build_artifact_nodes(state, nodes, scenario_id);
}

} // namespace artifact_rules

} // namespace aurelion::rules::port
