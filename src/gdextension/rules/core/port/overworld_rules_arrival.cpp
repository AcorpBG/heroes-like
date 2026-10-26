// OverworldRules for the human seat's arrival (Phase 7, slice 7.2): what the
// destination does (encounters, rendezvous, towns), the blocked-tile index
// after an interaction, and the action's event facts for the scenario check.
// HeroCommandRules.field_rendezvous_heroes is here too.

#include "aurelion_rules/port/overworld_rules_move.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/battle_payload.hpp"
#include "aurelion_rules/port/hero_command_rules.hpp"
#include "aurelion_rules/port/hero_command_rules_ai.hpp"
#include "aurelion_rules/port/hero_commit.hpp"
#include "aurelion_rules/port/native_transit_rules.hpp"
#include "aurelion_rules/port/overworld_level_rules.hpp"
#include "aurelion_rules/port/player_identity_rules_ai.hpp"
#include "aurelion_rules/port/session_view.hpp"

#include <initializer_list>

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
using overworld_rules::Tiles;
using overworld_rules::Vector2i;
using state::State;
using state::Value;
namespace key = state::key;

constexpr Atom kScript = key::overworld_rules_script;

// String(d.get(field, fallback)).
Atom text_or(State &state, DictRef dict, Atom field, Atom fallback) {
	return gd::stringify(state, state.get(dict, str(field), str(fallback)));
}

// d.get(field, {}) passed on or stored: the value, or a new Dictionary.
Value field_or_new_dict(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return dict_value(state.new_dict());
}

// d.get(field, []) passed on: the value, or a new Array.
Value field_or_new_array(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return array_value(state.new_array());
}

// d.get(field, {}) if d.get(field, {}) is Dictionary else {}.
DictRef sub_dict(State &state, DictRef dict, Atom field) {
	const Value value = state.get(dict, str(field), Value());
	return gd::is_dict(value) ? value.ref : state.new_dict();
}

// {"ok": ok, "message": message, "route": route}.
DictRef route_result(State &state, bool ok, Atom message, Atom route) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(ok));
	state.set(result, str(key::message), str(message));
	state.set(result, str(key::route), str(route));
	return result;
}

// {"ok": false, "message": message}.
DictRef failure(State &state, Atom message) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(false));
	state.set(result, str(key::message), str(message));
	return result;
}

// [id] if id != "" else [].
ArrayRef single_or_empty(State &state, Atom id) {
	const ArrayRef ids = state.new_array();
	if (id != key::empty) {
		state.append(ids, str(id));
	}
	return ids;
}

// {"blocks_changed": false, "body_tiles_changed": false}.
DictRef unchanged_topology(State &state) {
	const DictRef topology = state.new_dict();
	state.set(topology, str(key::blocks_changed), bool_value(false));
	state.set(topology, str(key::body_tiles_changed), bool_value(false));
	return topology;
}

// "%s opens its gates." % _town_name(town).
Atom opens_its_gates(State &state, DictRef town) {
	return gd::format(state, key::s_opens_its_gates, {str(overworld_rules::_town_name(state, town))});
}

// An Array of the tiles as Vector2i values.
ArrayRef tile_array(State &state, const Tiles &tiles) {
	const ArrayRef array = state.new_array();
	for (const Vector2i tile : tiles) {
		state.append(array, Value::of_vector2i(tile.x, tile.y));
	}
	return array;
}

// session.battle = payload.
void set_battle(State &state, DictRef session, DictRef payload) {
	state.set(session, str(key::battle), dict_value(payload));
}

} // namespace

namespace overworld_rules {

// A computer hero on the entry of its town fights with the garrison in one
// assault when every stack fits the battle's seven slots; {} otherwise.
DictRef _begin_entry_defense_assault(State &state, DictRef session, DictRef encounter) {
	if (!state.has(encounter, str(key::ai_hero))) {
		return state.new_dict();
	}
	// The town is the one whose entry the hero holds, wherever the attacker stands.
	DictRef town = 0;
	const Value at = dict_value(overworld_level_rules::position(state, encounter));
	for (const Value &candidate : gd::field_items(state, session_view::overworld(state, session), str(key::towns))) {
		if (gd::is_dict(candidate) && gd::equal(state, dict_value(overworld_level_rules::town_entrance(state, candidate.ref)), at)
				&& player_identity_rules::town_controller_id(state, candidate.ref) == player_identity_rules::raid_controller_id(state, encounter)) {
			town = candidate.ref;
			break;
		}
	}
	if (town == 0 || !_town_requires_assault(state, town)) {
		return state.new_dict();
	}
	const DictRef payload = battle_rules::create_entry_defense_assault_payload(state, dict_value(session), ai::string_or_empty(state, town, key::placement_id), encounter);
	if (gd::is_empty(state, payload)) {
		return payload;
	}
	set_battle(state, session, payload);
	const DictRef result = route_result(state, true, gd::format(state, key::the_assault_on_s_begins, {str(_town_name(state, town))}), key::battle);
	state.set(result, str(key::scenario_status), gd::field(state, session, key::scenario_status));
	return result;
}

DictRef _resolve_post_move_interaction(State &state, DictRef session) {
	{
		const DictRef profile = ai::static_dict(state, kScript, key::_pathing_debug_profile);
		if (gd::bool_field(state, profile, key::capture_enabled, false)) {
			state.set(profile, str(key::post_move_global_discovery_count),
					int_value(gd::add(gd::int_field(state, profile, key::post_move_global_discovery_count, 0), 1)));
		}
	}
	const DictRef encounter = get_active_encounter(state, session);
	if (!gd::is_empty(state, encounter)) {
		const DictRef assault = _begin_entry_defense_assault(state, session, encounter);
		if (!gd::is_empty(state, assault)) {
			return assault;
		}
		const DictRef battle_payload = battle_rules::create_battle_payload(state, dict_value(session), encounter);
		if (gd::is_empty(state, battle_payload)) {
			return route_result(state, false, key::the_enemy_blocks_the_lane_but, key::empty);
		}
		set_battle(state, session, battle_payload);
		return route_result(state, true, describe_encounter_battle_cue(state, session, encounter), key::battle);
	}

	const DictRef resource_result = _find_context_resource_node(state, session);
	if (gd::int_field(state, resource_result, key::index, -1) >= 0) {
		if (native_transit_rules::is_native(state, gd::as_dict(field_or_new_dict(state, resource_result, key::node)))) {
			return _collect_resource_node_result(state, session, resource_result, true, 0);
		}
		const DictRef result = collect_active_resource(state, session);
		if (state.has(result, str(key::reward_choice))) {
			return result;
		}
		const Atom message = ai::string_or_empty(state, result, key::message);
		return route_result(state, true, message, ai::string_or_empty(state, result, key::route));
	}

	const DictRef artifact_result = _find_active_artifact_node(state, session);
	if (gd::int_field(state, artifact_result, key::index, -1) >= 0) {
		const DictRef result = collect_active_artifact(state, session);
		return route_result(state, true, ai::string_or_empty(state, result, key::message), key::empty);
	}

	const DictRef town_result = _find_active_town(state, session);
	// var town: Dictionary = town_result.get("town", {})
	const DictRef town = gd::as_dict(field_or_new_dict(state, town_result, key::town));
	if (!gd::is_empty(state, town)) {
		if (text_or(state, town, key::owner, key::neutral) == key::player) {
			_teach_visiting_town_spells(state, session, town);
			return route_result(state, true, opens_its_gates(state, town), key::town);
		}
		return capture_active_town(state, session);
	}

	const DictRef rendezvous = _field_rendezvous_hero_at_tile(state, session, hero_position(state, session));
	if (!gd::is_empty(state, rendezvous)) {
		return _field_rendezvous_result(state, session, rendezvous);
	}
	return route_result(state, true, key::empty, key::empty);
}

DictRef _resolve_destination_descriptor_interaction(State &state, DictRef session, DictRef descriptor) {
	if (!_descriptor_matches_hero_level(state, session, descriptor)) {
		return route_result(state, false, key::the_selected_object_is_on_another, key::empty);
	}
	// A site/artifact and its defender can share an entrance. Cached commands
	// must preserve the same encounter-first authority as ordinary movement;
	// trying to claim the guarded reward first strands the hero without combat.
	if (ai::string_or_empty(state, descriptor, key::kind) != key::encounter) {
		const DictRef defender = get_active_encounter(state, session);
		if (!gd::is_empty(state, defender)) {
			// Older authored encounters may have no placement ID. The ordinary
			// resolver already supports their coordinate/content identity.
			return _resolve_post_move_interaction(state, session);
		}
	}
	const Atom kind = ai::string_or_empty(state, descriptor, key::kind);
	if (kind == key::resource) {
		const DictRef resource_result = _find_resource_node_by_placement(state, session, ai::string_or_empty(state, descriptor, key::placement_id));
		if (gd::int_field(state, resource_result, key::index, -1) < 0) {
			return route_result(state, false, key::no_resource_site_here, key::empty);
		}
		return _collect_resource_node_result(state, session, resource_result, false, 0);
	}
	if (kind == key::artifact) {
		const DictRef artifact_result = _find_artifact_node_by_descriptor(state, session, descriptor);
		if (gd::int_field(state, artifact_result, key::index, -1) < 0) {
			return route_result(state, false, key::no_artifact_cache_is_here, key::empty);
		}
		return _collect_artifact_node_result(state, session, artifact_result, false);
	}
	if (kind == key::encounter) {
		const DictRef encounter_result = _find_encounter_by_placement(state, session, ai::string_or_empty(state, descriptor, key::placement_id));
		const DictRef encounter = sub_dict(state, encounter_result, key::encounter);
		if (gd::int_field(state, encounter_result, key::index, -1) < 0 || gd::is_empty(state, encounter) || is_encounter_resolved(state, session, encounter)) {
			return route_result(state, true, key::empty, key::empty);
		}
		const DictRef assault = _begin_entry_defense_assault(state, session, encounter);
		if (!gd::is_empty(state, assault)) {
			return assault;
		}
		const DictRef battle_payload = battle_rules::create_battle_payload(state, dict_value(session), encounter);
		if (gd::is_empty(state, battle_payload)) {
			return route_result(state, false, key::the_enemy_blocks_the_lane_but, key::empty);
		}
		set_battle(state, session, battle_payload);
		_profile_blocked_index_not_applicable(state, session, key::encounter_handoff_does_not_refresh_blocked_index);
		const DictRef encounter_facts = _encounter_handoff_event_facts(state, encounter);
		_profile_scenario_event_evaluation(state, session, encounter_facts);
		const DictRef result = route_result(state, true, describe_encounter_battle_cue(state, session, encounter), key::battle);
		state.set(result, str(key::scenario_status), gd::field(state, session, key::scenario_status));
		state.set(result, str(key::interaction_result),
				dict_value(_interactable_result_payload(state, key::encounter, encounter, encounter_facts, unchanged_topology(state))));
		return result;
	}
	if (kind == key::town) {
		const int64_t town_lookup_started_usec = _rules_profile_timer(state);
		const DictRef town_result = _find_town_by_placement(state, session, ai::string_or_empty(state, descriptor, key::placement_id));
		_rules_profile_add_ms(state, key::descriptor_lookup_ms, town_lookup_started_usec);
		_rules_profile_set(state, key::descriptor, key::lookup_collection_size,
				int_value(_collection_size(state, field_or_new_array(state, session_view::overworld(state, session), key::towns))));
		_rules_profile_set(state, key::descriptor, key::lookup_mode, str(key::placement_index_or_active_visit));
		const DictRef town = sub_dict(state, town_result, key::town);
		if (gd::int_field(state, town_result, key::index, -1) < 0 || gd::is_empty(state, town)) {
			return route_result(state, true, key::empty, key::empty);
		}
		if (text_or(state, town, key::owner, key::neutral) == key::player) {
			_teach_visiting_town_spells(state, session, town);
			_profile_blocked_index_not_applicable(state, session, key::town_visit_does_not_refresh_blocked_index);
			const DictRef town_facts = _town_visit_event_facts(state, town);
			_profile_scenario_event_evaluation(state, session, town_facts);
			const DictRef result = route_result(state, true, opens_its_gates(state, town), key::town);
			state.set(result, str(key::scenario_status), gd::field(state, session, key::scenario_status));
			state.set(result, str(key::interaction_result),
					dict_value(_interactable_result_payload(state, key::town, town, town_facts, unchanged_topology(state))));
			return result;
		}
		return capture_active_town(state, session);
	}
	if (kind == key::hero) {
		const Atom target_hero_id = ai::string_or_empty(state, descriptor, key::hero_id);
		const DictRef target = hero_command_rules::hero_by_id(state, session, target_hero_id);
		if (gd::is_empty(state, target) || target_hero_id == ai::string_or_empty(state, session_view::overworld(state, session), key::active_hero_id)) {
			return route_result(state, true, key::empty, key::empty);
		}
		const Vector2i active_position = hero_position(state, session);
		const DictRef target_position = sub_dict(state, target, key::position);
		if (gd::int_field(state, target_position, key::x, -999) != active_position.x || gd::int_field(state, target_position, key::y, -999) != active_position.y) {
			return route_result(state, false, key::the_reserve_commander_is_no_longer, key::empty);
		}
		return _field_rendezvous_result(state, session, target);
	}
	return route_result(state, true, key::empty, key::empty);
}

DictRef get_active_encounter(State &state, DictRef session) {
	const Vector2i pos = hero_position(state, session);
	if (!is_tile_visible(state, session, pos.x, pos.y, -1)) {
		return state.new_dict();
	}
	return _engaging_encounter_at_tile(state, session, pos, hero_level(state, session));
}

DictRef _engaging_encounter_at_tile(State &state, DictRef session, Vector2i pos, int64_t level) {
	const Value encounters = field_or_new_array(state, session_view::overworld(state, session), key::encounters);
	const DictRef lookup_index = _spatial_lookup_index(state, session, level);
	const ArrayRef entries = _spatial_lookup_entries(state, lookup_index, key::encounter_by_tile, pos);
	for (const Value &encounter_index : gd::items(state, array_value(entries))) {
		// encounters[int(encounter_index)] if encounters is Array and in range else {}
		Value encounter;
		if (gd::is_array(encounters) && gd::to_int(state, encounter_index) >= 0 && gd::to_int(state, encounter_index) < state.array_size(encounters.ref)) {
			encounter = state.at(encounters.ref, gd::to_int(state, encounter_index));
		} else {
			encounter = dict_value(state.new_dict());
		}
		if (gd::is_dict(encounter) && !is_encounter_resolved(state, session, encounter.ref)) {
			return encounter.ref;
		}
	}
	const DictRef guard_result = _find_guard_engagement_at_tile(state, session, pos.x, pos.y, level, true);
	if (gd::int_field(state, guard_result, key::index, -1) >= 0) {
		return gd::as_dict(field_or_new_dict(state, guard_result, key::encounter));
	}
	return state.new_dict();
}

DictRef _field_rendezvous_hero_at_tile(State &state, DictRef session, Vector2i tile) {
	// session == null cannot happen: a session is its view.
	const ArrayRef rendezvous = hero_command_rules::field_rendezvous_heroes(state, session);
	for (const Value &hero_value : gd::items(state, array_value(rendezvous))) {
		if (!gd::is_dict(hero_value)) {
			continue;
		}
		const DictRef hero = hero_value.ref;
		const DictRef position = sub_dict(state, hero, key::position);
		if (gd::int_field(state, position, key::x, -999) == tile.x && gd::int_field(state, position, key::y, -999) == tile.y) {
			return hero;
		}
	}
	return state.new_dict();
}

DictRef _field_rendezvous_result(State &state, DictRef session, DictRef reserve) {
	const Atom reserve_name = text_or(state, reserve, key::name, key::the_reserve_commander);
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(true));
	state.set(result, str(key::message), str(gd::format(state, key::rendezvous_with_s_the_commanders_meet, {str(reserve_name)})));
	state.set(result, str(key::route), str(key::rendezvous));
	state.set(result, str(key::rendezvous_hero_id), str(ai::string_or_empty(state, reserve, key::id)));
	state.set(result, str(key::rendezvous_hero_name), str(reserve_name));
	// session.scenario_status if session != null else "": a session is its view.
	state.set(result, str(key::scenario_status), gd::field(state, session, key::scenario_status));
	return result;
}

void clear_active_town_visit(State &state, DictRef session) {
	// session == null cannot happen: a session is its view.
	const DictRef indexes = ai::static_dict(state, kScript, key::_active_town_visit_indexes);
	state.erase(indexes, str(gd::stringify(state, gd::field(state, session, key::session_id))));
	state.erase(gd::as_dict(gd::index(state, session, str(key::flags))), str(key::active_town_placement_id));
}

DictRef capture_active_town(State &state, DictRef session) {
	normalize_overworld_state_for_runtime(state, session);
	const DictRef town_result = _find_active_town(state, session);
	if (gd::int_field(state, town_result, key::index, -1) < 0) {
		return failure(state, key::no_town_stands_here);
	}

	// var town = town_result.get("town", {})
	const DictRef town = gd::as_dict(field_or_new_dict(state, town_result, key::town));
	if (text_or(state, town, key::owner, key::neutral) == key::player) {
		return failure(state, key::this_town_already_flies_your_banner);
	}
	if (text_or(state, town, key::owner, key::neutral) == key::enemy && _town_requires_assault(state, town)) {
		return _begin_town_assault(state, session, town);
	}

	const Atom previous_owner = text_or(state, town, key::owner, key::neutral);
	const Atom placement_id = ai::string_or_empty(state, town, key::placement_id);
	const Atom capture_message = capture_town_by_placement(state, session, placement_id);
	const DictRef captured_town_result = _find_town_by_placement(state, session, placement_id);
	// captured_town_result.get("town", town) if that is a Dictionary else town.
	const Value captured_value = state.get(captured_town_result, str(key::town), dict_value(town));
	const DictRef captured_town = gd::is_dict(captured_value) ? captured_value.ref : town;
	const DictRef town_facts = _town_capture_event_facts(state, captured_town, previous_owner, text_or(state, captured_town, key::owner, key::neutral));
	_profile_blocked_index_not_applicable(state, session, key::town_capture_does_not_refresh_blocked_index);
	const DictRef result = _finalize_action_result(state, session, true, capture_message, true, false, town_facts);
	state.set(result, str(key::interaction_result),
			dict_value(_interactable_result_payload(state, key::town_capture, captured_town, town_facts, unchanged_topology(state))));
	const DictRef context = state.new_dict();
	state.set(context, str(key::placement_id), str(ai::string_or_empty(state, town, key::placement_id)));
	state.set(context, str(key::x), int_value(gd::int_field(state, town, key::x, 0)));
	state.set(context, str(key::y), int_value(gd::int_field(state, town, key::y, 0)));
	return _attach_post_action_recap(state, result, session, key::town_capture, context);
}

DictRef _begin_town_assault(State &state, DictRef session, DictRef town) {
	const Atom town_name = _town_name(state, town);
	const DictRef payload = battle_rules::create_town_assault_payload(state, dict_value(session), ai::string_or_empty(state, town, key::placement_id));
	if (gd::is_empty(state, payload)) {
		return failure(state, gd::format(state, key::the_assault_on_s_cannot_be, {str(town_name)}));
	}
	set_battle(state, session, payload);
	const DictRef result = route_result(state, true, gd::format(state, key::the_assault_on_s_begins, {str(town_name)}), key::battle);
	state.set(result, str(key::scenario_status), gd::field(state, session, key::scenario_status));
	return result;
}

bool _town_requires_assault(State &state, DictRef town) {
	return text_or(state, town, key::owner, key::neutral) == key::enemy && _town_garrison_headcount(state, town) > 0;
}

Atom relieve_town_recovery_pressure(State &state, DictRef session, Atom town_placement_id, int64_t amount, Atom source) {
	// session == null cannot happen: a session is its view.
	if (town_placement_id == key::empty || amount <= 0) {
		return key::empty;
	}
	const DictRef town_result = _find_town_by_placement(state, session, town_placement_id);
	if (gd::int_field(state, town_result, key::index, -1) < 0) {
		return key::empty;
	}
	const Value towns = field_or_new_array(state, session_view::overworld(state, session), key::towns);
	const Value town_value = field_or_new_dict(state, town_result, key::town);
	const DictRef town = gd::as_dict(town_value);
	const DictRef recovery = _normalize_town_recovery_state(state, field_or_new_dict(state, town, key::recovery));
	// max(0, int(...)) and min(current_pressure, amount) of ints.
	const int64_t current_pressure = compat::engine_max<int64_t>(0, gd::int_field(state, recovery, key::pressure, 0));
	if (current_pressure <= 0) {
		return key::empty;
	}
	const int64_t relieved = compat::engine_min<int64_t>(current_pressure, amount);
	state.set(recovery, str(key::pressure), int_value(compat::engine_max<int64_t>(0, gd::sub(current_pressure, relieved))));
	state.set(recovery, str(key::last_event_day), gd::field(state, session, key::day));
	if (gd::int_field(state, recovery, key::pressure, 0) <= 0) {
		state.set(recovery, str(key::source), str(key::empty));
	} else if (source != key::empty) {
		state.set(recovery, str(key::source), str(source));
	}
	state.set(town, str(key::recovery), dict_value(recovery));
	state.set_at(gd::as_array(towns), gd::int_field(state, town_result, key::index, -1), town_value);
	state.set(session_view::overworld(state, session), str(key::towns), towns);
	const DictRef recovery_state = town_recovery_state(state, session, town);
	const Atom source_clause = source != key::empty ? gd::format(state, key::via_s, {str(source)}) : key::empty;
	if (gd::int_field(state, recovery, key::pressure, 0) <= 0) {
		return gd::format(state, key::s_recovery_stabilized_s, {str(_town_name(state, town)), str(source_clause)});
	}
	const int64_t days_to_clear = gd::int_field(state, recovery_state, key::days_to_clear, 0);
	return gd::format(state, key::s_recovery_d_s_d_day_2,
			{str(_town_name(state, town)), int_value(relieved), str(source_clause), int_value(days_to_clear),
					str(gd::int_field(state, recovery_state, key::days_to_clear, 0) == 1 ? key::empty : key::s)});
}

void _refresh_blocked_tile_index_for_interaction(State &state, DictRef session, DictRef topology_facts) {
	// session == null cannot happen: a session is its view.
	const bool blocks_changed = gd::bool_field(state, topology_facts, key::blocks_changed, true);
	const bool body_tiles_changed = gd::bool_field(state, topology_facts, key::body_tiles_changed, true);
	const bool contract_known = gd::bool_field(state, topology_facts, key::contract_known, false);
	// session.has_meta(BLOCKED_TILE_INDEX_META)
	if (contract_known && !blocks_changed && !body_tiles_changed && ai::meta_has(state, session, key::_overworld_blocked_tile_indexes)) {
		const DictRef index = _blocked_tile_index(state, session, -1);
		_rules_profile_set(state, key::blocked_index, key::rebuilt, bool_value(false));
		_rules_profile_set(state, key::blocked_index, key::mode, str(key::skipped));
		_rules_profile_set(state, key::blocked_index, key::reason, str(key::topology_unchanged));
		_rules_profile_set(state, key::blocked_index, key::blocks_changed, bool_value(false));
		_rules_profile_set(state, key::blocked_index, key::body_tiles_changed, bool_value(false));
		_rules_profile_set(state, key::blocked_index, key::tile_count, int_value(state.dict_size(index)));
		return;
	}
	_rules_profile_set(state, key::blocked_index, key::mode, str(key::full));
	_rules_profile_set(state, key::blocked_index, key::reason, str(text_or(state, topology_facts, key::fallback_reason, key::topology_changed_or_unknown)));
	_rules_profile_set(state, key::blocked_index, key::blocks_changed, bool_value(blocks_changed));
	_rules_profile_set(state, key::blocked_index, key::body_tiles_changed, bool_value(body_tiles_changed));
	_refresh_blocked_tile_index(state, session);
}

void _profile_blocked_index_not_applicable(State &state, DictRef session, Atom reason) {
	// session != null always: a session is its view.
	const DictRef index = _blocked_tile_index(state, session, -1);
	const int64_t session_index_size = state.dict_size(index);
	_rules_profile_set(state, key::blocked_index, key::rebuilt, bool_value(false));
	_rules_profile_set(state, key::blocked_index, key::mode, str(key::not_applicable));
	_rules_profile_set(state, key::blocked_index, key::reason, str(reason));
	_rules_profile_set(state, key::blocked_index, key::blocks_changed, bool_value(false));
	_rules_profile_set(state, key::blocked_index, key::body_tiles_changed, bool_value(false));
	_rules_profile_set(state, key::blocked_index, key::tile_count, int_value(session_index_size));
}

DictRef _resource_topology_facts(State &state, DictRef before_node, DictRef after_node, DictRef map_object) {
	if (gd::is_empty(state, map_object) && !_resource_node_has_runtime_object_contract(state, after_node)) {
		const DictRef facts = state.new_dict();
		state.set(facts, str(key::contract_known), bool_value(false));
		state.set(facts, str(key::blocks_changed), bool_value(true));
		state.set(facts, str(key::body_tiles_changed), bool_value(true));
		state.set(facts, str(key::fallback_reason), str(key::unknown_resource_object_contract));
		return facts;
	}
	const bool before_blocks = _resource_node_blocks_body_tiles(state, before_node, map_object);
	const bool after_blocks = _resource_node_blocks_body_tiles(state, after_node, map_object);
	const ArrayRef before_tiles = _tile_key_array(state, tile_array(state, _map_object_world_body_tiles(state, map_object, before_node)));
	const ArrayRef after_tiles = _tile_key_array(state, tile_array(state, _map_object_world_body_tiles(state, map_object, after_node)));
	const DictRef facts = state.new_dict();
	state.set(facts, str(key::contract_known), bool_value(true));
	state.set(facts, str(key::blocks_changed), bool_value(before_blocks != after_blocks));
	state.set(facts, str(key::body_tiles_changed), bool_value(!gd::equal(state, array_value(before_tiles), array_value(after_tiles))));
	state.set(facts, str(key::fallback_reason), str(key::topology_changed));
	state.set(facts, str(key::before_body_tile_count), int_value(state.array_size(before_tiles)));
	state.set(facts, str(key::after_body_tile_count), int_value(state.array_size(after_tiles)));
	return facts;
}

ArrayRef _tile_key_array(State &state, ArrayRef tiles) {
	const ArrayRef keys = state.new_array();
	for (const Value &tile : gd::items(state, array_value(tiles))) {
		if (gd::is_vector2i(tile)) {
			state.append(keys, str(_tile_key(state, Vector2i::of(tile.vx(), tile.vy()))));
		}
	}
	// keys.sort() of Strings: code point order, which is UTF-8 byte order.
	gd::sort_custom(state, keys, [&state](const Value &a, const Value &b) { return gd::text(state, a) < gd::text(state, b); });
	return keys;
}

DictRef _resource_interaction_event_facts(State &state, DictRef node, DictRef site, Atom previous_controller, DictRef rewards, DictRef visit_cost, DictRef topology_facts) {
	const ArrayRef changed_resources = state.new_array();
	for (const Value &resource_id : gd::items(state, array_value(gd::keys(state, rewards)))) {
		if (gd::to_int(state, state.get(rewards, resource_id, int_value(0))) != 0) {
			state.append(changed_resources, str(gd::stringify(state, resource_id)));
		}
	}
	for (const Value &resource_id : gd::items(state, array_value(gd::keys(state, visit_cost)))) {
		if (gd::to_int(state, state.get(visit_cost, resource_id, int_value(0))) != 0
				&& !gd::array_has(state, changed_resources, str(gd::stringify(state, resource_id)))) {
			state.append(changed_resources, str(gd::stringify(state, resource_id)));
		}
	}
	const Atom placement_id = ai::string_or_empty(state, node, key::placement_id);
	const bool control_changed = previous_controller != player_identity_rules::resource_controller_id(state, node);
	const DictRef facts = state.new_dict();
	state.set(facts, str(key::event_type), str(key::interactable_resolved));
	state.set(facts, str(key::family), str(key::resource_site));
	state.set(facts, str(key::placement_id), str(placement_id));
	state.set(facts, str(key::resource_site_placement_ids), array_value(single_or_empty(state, placement_id)));
	state.set(facts, str(key::resources), array_value(changed_resources));
	state.set(facts, str(key::changed_resources), array_value(changed_resources));
	state.set(facts, str(key::control_changed), bool_value(control_changed));
	state.set(facts, str(key::previous_controller), str(previous_controller));
	state.set(facts, str(key::new_controller), str(player_identity_rules::resource_controller_id(state, node)));
	state.set(facts, str(key::blocks_changed), bool_value(gd::bool_field(state, topology_facts, key::blocks_changed, true)));
	state.set(facts, str(key::body_tiles_changed), bool_value(gd::bool_field(state, topology_facts, key::body_tiles_changed, true)));
	state.set(facts, str(key::contract_known), bool_value(gd::bool_field(state, topology_facts, key::contract_known, false)));
	if (ai::string_or_empty(state, site, key::family) == key::scenario_objective || gd::bool_field(state, site, key::requires_full_scenario_eval, false)) {
		state.set(facts, str(key::requires_full_scenario_eval), bool_value(true));
		state.set(facts, str(key::fallback_reason), str(key::resource_site_explicit_objective));
	}
	const ArrayRef learned_spell_ids = _resource_site_spell_ids(state, site);
	if (state.array_size(learned_spell_ids) > 0) {
		state.set(facts, str(key::spell_ids), array_value(learned_spell_ids));
	}
	return facts;
}

DictRef _artifact_interaction_event_facts(State &state, DictRef node) {
	const Atom placement_id = ai::string_or_empty(state, node, key::placement_id);
	const Atom artifact_id = ai::string_or_empty(state, node, key::artifact_id);
	const DictRef facts = state.new_dict();
	state.set(facts, str(key::event_type), str(key::interactable_resolved));
	state.set(facts, str(key::family), str(key::artifact));
	state.set(facts, str(key::placement_id), str(placement_id));
	state.set(facts, str(key::artifact_ids), array_value(single_or_empty(state, artifact_id)));
	state.set(facts, str(key::blocks_changed), bool_value(false));
	state.set(facts, str(key::body_tiles_changed), bool_value(false));
	state.set(facts, str(key::contract_known), bool_value(true));
	return facts;
}

DictRef _encounter_handoff_event_facts(State &state, DictRef encounter) {
	// String(encounter.get("placement_id", encounter.get("id", "")))
	const Value id_fallback = state.get(encounter, str(key::id), str(key::empty));
	const Atom placement_id = gd::stringify(state, state.get(encounter, str(key::placement_id), id_fallback));
	const DictRef facts = state.new_dict();
	state.set(facts, str(key::event_type), str(key::battle_handoff));
	state.set(facts, str(key::family), str(key::encounter));
	state.set(facts, str(key::placement_id), str(placement_id));
	state.set(facts, str(key::encounter_handoff_placement_ids), array_value(single_or_empty(state, placement_id)));
	state.set(facts, str(key::blocks_changed), bool_value(true));
	state.set(facts, str(key::body_tiles_changed), bool_value(true));
	state.set(facts, str(key::contract_known), bool_value(true));
	state.set(facts, str(key::requires_full_scenario_eval), bool_value(true));
	state.set(facts, str(key::fallback_reason), str(key::battle_handoff));
	return facts;
}

DictRef _town_visit_event_facts(State &state, DictRef town) {
	const Atom placement_id = ai::string_or_empty(state, town, key::placement_id);
	const DictRef facts = state.new_dict();
	state.set(facts, str(key::event_type), str(key::town_visit));
	state.set(facts, str(key::family), str(key::town));
	state.set(facts, str(key::placement_id), str(placement_id));
	state.set(facts, str(key::town_visit_placement_ids), array_value(single_or_empty(state, placement_id)));
	state.set(facts, str(key::blocks_changed), bool_value(false));
	state.set(facts, str(key::body_tiles_changed), bool_value(false));
	state.set(facts, str(key::contract_known), bool_value(true));
	return facts;
}

DictRef _town_capture_event_facts(State &state, DictRef town, Atom previous_owner, Atom new_owner) {
	const Atom placement_id = ai::string_or_empty(state, town, key::placement_id);
	const Atom town_id = ai::string_or_empty(state, town, key::town_id);
	const DictRef facts = state.new_dict();
	state.set(facts, str(key::event_type), str(key::town_control_changed));
	state.set(facts, str(key::family), str(key::town));
	state.set(facts, str(key::placement_id), str(placement_id));
	state.set(facts, str(key::town_placement_ids), array_value(single_or_empty(state, placement_id)));
	state.set(facts, str(key::town_ids), array_value(single_or_empty(state, town_id)));
	state.set(facts, str(key::previous_owner), str(previous_owner));
	state.set(facts, str(key::new_owner), str(new_owner));
	state.set(facts, str(key::blocks_changed), bool_value(false));
	state.set(facts, str(key::body_tiles_changed), bool_value(false));
	state.set(facts, str(key::contract_known), bool_value(true));
	state.set(facts, str(key::requires_full_scenario_eval), bool_value(true));
	state.set(facts, str(key::fallback_reason), str(key::town_control_changed));
	return facts;
}

DictRef _interactable_result_payload(State &state, Atom family, DictRef placement, DictRef mutation_facts, DictRef topology_facts) {
	const DictRef payload = state.new_dict();
	state.set(payload, str(key::family), str(family));
	state.set(payload, str(key::placement_id), str(ai::string_or_empty(state, placement, key::placement_id)));
	{
		// String(placement.get("site_id", placement.get("artifact_id", placement.get("encounter_id", placement.get("town_id", ""))))).
		const Value town_id = state.get(placement, str(key::town_id), str(key::empty));
		const Value encounter_id = state.get(placement, str(key::encounter_id), town_id);
		const Value artifact_id = state.get(placement, str(key::artifact_id), encounter_id);
		state.set(payload, str(key::content_id), str(gd::stringify(state, state.get(placement, str(key::site_id), artifact_id))));
	}
	{
		const DictRef tile = state.new_dict();
		state.set(tile, str(key::x), int_value(gd::int_field(state, placement, key::x, 0)));
		state.set(tile, str(key::y), int_value(gd::int_field(state, placement, key::y, 0)));
		state.set(payload, str(key::tile), dict_value(tile));
	}
	state.set(payload, str(key::mutation_facts), gd::engine_duplicate(state, dict_value(mutation_facts), true));
	state.set(payload, str(key::blocks_changed), bool_value(gd::bool_field(state, topology_facts, key::blocks_changed, false)));
	state.set(payload, str(key::body_tiles_changed), bool_value(gd::bool_field(state, topology_facts, key::body_tiles_changed, false)));
	_rules_profile_set(state, key::interactable, key::family, str(family));
	_rules_profile_set(state, key::interactable, key::placement_id, str(text_or(state, payload, key::placement_id, key::empty)));
	_rules_profile_set(state, key::interactable, key::blocks_changed, bool_value(gd::bool_field(state, payload, key::blocks_changed, false)));
	_rules_profile_set(state, key::interactable, key::body_tiles_changed, bool_value(gd::bool_field(state, payload, key::body_tiles_changed, false)));
	return payload;
}

DictRef _profile_scenario_event_evaluation(State &state, DictRef session, DictRef event_facts) {
	const int64_t scenario_started_usec = _rules_profile_timer(state);
	const DictRef scenario_result = _evaluate_scenario_state_for_event(state, session, event_facts);
	_rules_profile_add_ms(state, key::finalize_scenario_eval_ms, scenario_started_usec);
	// var scenario_profile: Dictionary = scenario_result.get("profile", {}), {} unless a Dictionary (read only).
	Value scenario_profile;
	if (state.lookup(scenario_result, str(key::profile), scenario_profile) && gd::is_dict(scenario_profile)) {
		const ArrayRef profile_keys = gd::keys(state, scenario_profile.ref);
		for (const Value &profile_key : gd::items(state, array_value(profile_keys))) {
			_rules_profile_set(state, key::scenario_eval, gd::stringify(state, profile_key), state.get(scenario_profile.ref, profile_key, Value()));
		}
	}
	return scenario_result;
}

DictRef _evaluate_scenario_state_for_event(State &state, DictRef session, DictRef event_facts) {
	return scenario_rules::evaluate_session_for_event(state, session, event_facts);
}

Atom _scenario_objective_player_label(State &state, DictRef session, DictRef objective) {
	const Atom label = gd::strip_edges(state, scenario_rules::_objective_label(state, session, objective));
	if (label != key::empty) {
		return label;
	}
	// String(objective.get("label", objective.get("id", "Objective")))
	const Value id_fallback = state.get(objective, str(key::id), str(key::Objective));
	return gd::stringify(state, state.get(objective, str(key::label), id_fallback));
}

} // namespace overworld_rules

namespace hero_command_rules {

ArrayRef field_rendezvous_heroes(State &state, DictRef session) {
	// normalize_session(session) with its defaults; session == null cannot
	// happen: a session is its view.
	normalize_session(state, session, key::empty, state.new_dict(), state.new_dict());
	const ArrayRef rendezvous = state.new_array();
	const DictRef active = active_hero(state, session);
	if (gd::is_empty(state, active)) {
		return rendezvous;
	}
	const Atom active_id = ai::string_or_empty(state, active, key::id);
	const DictRef active_position = _normalize_position(state, field_or_new_dict(state, active, key::position));
	for (const Value &hero_value : gd::field_items(state, session_view::overworld(state, session), str(key::player_heroes))) {
		if (!gd::is_dict(hero_value)) {
			continue;
		}
		const DictRef hero = hero_value.ref;
		if (ai::string_or_empty(state, hero, key::id) == active_id) {
			continue;
		}
		if (gd::equal(state, dict_value(_normalize_position(state, field_or_new_dict(state, hero, key::position))), dict_value(active_position))) {
			state.append(rendezvous, dict_value(hero));
		}
	}
	return rendezvous;
}

} // namespace hero_command_rules

} // namespace aurelion::rules::port
