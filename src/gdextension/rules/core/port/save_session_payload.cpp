// The save format's payload: SessionStateStore.normalize_payload and its
// helpers, SessionData.payload_for_storage and share_runtime_scenario_record
// (SessionData.from_dict reads normalize_payload), and
// HeroCommandRules.restore_empty_hero_armies, which a restored save runs.

#include "aurelion_rules/port/session_state_store.hpp"
#include "aurelion_rules/port/hero_command_rules.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/hero_command_rules_ai.hpp"
#include "aurelion_rules/port/hero_command_rules_turn.hpp"
#include "aurelion_rules/port/hero_commit.hpp"
#include "aurelion_rules/port/session_view.hpp"

#include <algorithm>

namespace aurelion::rules::port {

namespace {

using gd::array_value;
using gd::ArrayRef;
using gd::Atom;
using gd::dict_value;
using gd::DictRef;
using gd::int_value;
using gd::str;
using state::Kind;
using state::State;
using state::Value;
namespace key = state::key;

// String(x) of a Variant: str(x), the engine's text for a float or a container.
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

// String(d.get(k, fallback)).
Atom string_get(State &state, DictRef dict, Atom k, const Value &fallback) {
	return string_of(state, state.get(dict, str(k), fallback));
}

// _dict_or_empty_value(d.get(k, {})): a missing field is a new empty one.
DictRef dict_or_empty_field(State &state, DictRef dict, Atom k) {
	Value found;
	if (!state.lookup(dict, str(k), found)) {
		return state.new_dict();
	}
	return session_state_store::_dict_or_empty_value(state, found);
}

// d.get(k, {}).get("stacks", []) if d.get(k, {}) is Dictionary else []: the
// holder's stacks, a new empty Array when there are none.
Value stacks_of(State &state, DictRef dict, Atom k) {
	Value holder;
	Value stacks;
	if (state.lookup(dict, str(k), holder) && gd::is_dict(holder) && state.lookup(holder.ref, str(key::stacks), stacks)) {
		return stacks;
	}
	return array_value(state.new_array());
}

// army.get("stacks", []).is_empty().
bool army_stacks_empty(State &state, DictRef army) {
	Value stacks;
	if (!state.lookup(army, str(key::stacks), stacks)) {
		return true;
	}
	return ai::vempty(state, stacks);
}

// "%s|%s|restored_army|%s" % [String(session.session_id), String(session.scenario_id), last].
Atom restored_army_seed(State &state, DictRef view, Atom last) {
	const Atom session_id = string_of(state, gd::field(state, view, key::session_id));
	const Atom scenario_id = string_of(state, gd::field(state, view, key::scenario_id));
	return gd::format(state, key::s_s_restored_army_s, { str(session_id), str(scenario_id), str(last) });
}

} // namespace

// SessionStateStore.

namespace session_state_store {

DictRef normalize_payload(State &state, const Value &value) {
	const DictRef payload = gd::is_dict(value) ? value.ref : state.new_dict();
	const DictRef normalized = state.new_dict();
	state.set(normalized, str(key::save_version), int_value(std::max<int64_t>(0, gd::int_field(state, payload, key::save_version, kSaveVersion))));
	Value session_id;
	if (!state.lookup(payload, str(key::session_id), session_id)) {
		session_id = str(gd::stringify(state, int_value(gd::engine_ticks_msec(state))));
	}
	state.set(normalized, str(key::session_id), str(string_of(state, session_id)));
	state.set(normalized, str(key::scenario_id), str(string_get(state, payload, key::scenario_id, str(key::empty))));
	state.set(normalized, str(key::hero_id), str(string_get(state, payload, key::hero_id, str(key::empty))));
	state.set(normalized, str(key::day), int_value(std::max<int64_t>(1, gd::int_field(state, payload, key::day, 1))));
	state.set(normalized, str(key::difficulty), str(string_get(state, payload, key::difficulty, str(key::normal))));
	state.set(normalized, str(key::launch_mode), str(normalize_launch_mode(state, state.get(payload, str(key::launch_mode), str(key::campaign)))));
	state.set(normalized, str(key::game_state), str(_normalize_game_state(state, state.get(payload, str(key::game_state), str(key::overworld)))));
	state.set(normalized, str(key::scenario_status), str(_normalize_scenario_status(state, state.get(payload, str(key::scenario_status), str(key::in_progress)))));
	state.set(normalized, str(key::scenario_summary), str(string_get(state, payload, key::scenario_summary, str(key::empty))));
	const DictRef overworld = dict_or_empty_field(state, payload, key::overworld);
	state.set(normalized, str(key::overworld), dict_value(overworld));
	state.set(normalized, str(key::battle), dict_value(dict_or_empty_field(state, payload, key::battle)));
	const DictRef flags = dict_or_empty_field(state, payload, key::flags);
	state.set(normalized, str(key::flags), dict_value(flags));
	share_runtime_scenario_record(state, overworld, flags);
	return normalized;
}

Atom _normalize_game_state(State &state, const Value &value) {
	const Atom game_state = string_of(state, value);
	// SUPPORTED_GAME_STATES: overworld, town, battle, outcome.
	if (game_state == key::overworld || game_state == key::town || game_state == key::battle || game_state == key::outcome) {
		return game_state;
	}
	return key::overworld;
}

Atom _normalize_scenario_status(State &state, const Value &value) {
	const Atom scenario_status = string_of(state, value);
	// SUPPORTED_SCENARIO_STATUSES: in_progress, victory, defeat.
	if (scenario_status == key::in_progress || scenario_status == key::victory || scenario_status == key::defeat) {
		return scenario_status;
	}
	return key::in_progress;
}

DictRef _dict_or_empty_value(State &state, const Value &value) {
	if (gd::is_dict(value)) {
		return gd::as_dict(gd::engine_duplicate(state, value, true));
	}
	return state.new_dict();
}

// SessionData's statics.

DictRef payload_for_storage(State &state, DictRef payload) {
	// A missing flags or overworld is a new {}: no package flag, no record.
	Value flags_value;
	if (!state.lookup(payload, str(key::flags), flags_value)) {
		return payload;
	}
	Value overworld_value;
	const bool has_overworld = state.lookup(payload, str(key::overworld), overworld_value);
	if (!gd::is_dict(flags_value) || (has_overworld && !gd::is_dict(overworld_value))) {
		return payload;
	}
	const DictRef payload_flags = flags_value.ref;
	if (!gd::bool_field(state, payload_flags, key::native_random_map_package_session_adoption, false)) {
		return payload;
	}
	const Value flags_record = gd::field(state, payload_flags, key::native_random_map_runtime_scenario_record);
	if (!has_overworld) {
		return payload;
	}
	const Value overworld_record = gd::field(state, overworld_value.ref, key::native_random_map_runtime_scenario_record);
	if (!gd::is_dict(flags_record) || !gd::is_dict(overworld_record)) {
		return payload;
	}
	if (!gd::is_same(state, flags_record, overworld_record) && !gd::equal_loaded(state, flags_record, overworld_record)) {
		return payload;
	}
	const DictRef stored_flags = gd::duplicate_dict(state, payload_flags);
	state.erase(stored_flags, str(key::native_random_map_runtime_scenario_record));
	const DictRef stored = gd::duplicate_dict(state, payload);
	state.set(stored, str(key::flags), dict_value(stored_flags));
	return stored;
}

void share_runtime_scenario_record(State &state, DictRef overworld_state, DictRef session_flags) {
	if (!gd::bool_field(state, session_flags, key::native_random_map_package_session_adoption, false)
			|| state.has(session_flags, str(key::native_random_map_runtime_scenario_record))) {
		return;
	}
	const Value record = gd::field(state, overworld_state, key::native_random_map_runtime_scenario_record);
	if (gd::is_dict(record)) {
		state.set(session_flags, str(key::native_random_map_runtime_scenario_record), record);
	}
}

} // namespace session_state_store

// HeroCommandRules.

namespace hero_command_rules {

int64_t restore_empty_hero_armies(State &state, const Value &session) {
	if (session.kind == Kind::Nil) {
		return 0;
	}
	const DictRef view = gd::object_view(state, session);
	if (!gd::is_empty(state, gd::as_dict(gd::field(state, view, key::battle)))) {
		return 0;
	}
	const Atom scenario_status = string_of(state, gd::field(state, view, key::scenario_status));
	if (scenario_status != key::empty && scenario_status != key::in_progress) {
		return 0;
	}
	int64_t restored = 0;
	Value heroes;
	if (state.lookup(session_view::overworld(state, view), str(key::player_heroes), heroes) && gd::is_array(heroes)) {
		const int64_t count = state.array_size(heroes.ref);
		for (int64_t index = 0; index < count; ++index) {
			const Value hero = state.at(heroes.ref, index);
			if (!gd::is_dict(hero) || _valid_stack_count(state, stacks_of(state, hero.ref, key::army)) > 0) {
				continue;
			}
			const Atom hero_id = string_get(state, hero.ref, key::id, str(key::empty));
			const DictRef hero_template = gd::content_row(state, state::ContentTable::Hero, hero_id);
			const DictRef army = starting_army_for_hero(state, hero_template, restored_army_seed(state, view, hero_id));
			if (army_stacks_empty(state, army)) {
				continue;
			}
			// previous: hero.get("army", {}) if it is a Dictionary, else {}.
			Value previous;
			const bool has_previous = state.lookup(hero.ref, str(key::army), previous) && gd::is_dict(previous);
			const Value id_fallback = state.get(army, str(key::id), str(key::empty));
			state.set(army, str(key::id), str(string_of(state, has_previous ? state.get(previous.ref, str(key::id), id_fallback) : id_fallback)));
			const Value name_fallback = state.get(army, str(key::name), str(key::field_army));
			state.set(army, str(key::name), str(string_of(state, has_previous ? state.get(previous.ref, str(key::name), name_fallback) : name_fallback)));
			state.set(hero.ref, str(key::army), dict_value(army));
			state.set_at(heroes.ref, index, hero);
			restored += 1;
		}
		if (restored > 0) {
			state.set(session_view::overworld(state, view), str(key::player_heroes), heroes);
			_sync_active_hero_mirror(state, view);
		}
	}
	Value encounters;
	int64_t raids_restored = 0;
	if (state.lookup(session_view::overworld(state, view), str(key::encounters), encounters) && gd::is_array(encounters)) {
		const int64_t count = state.array_size(encounters.ref);
		for (int64_t index = 0; index < count; ++index) {
			const Value encounter = state.at(encounters.ref, index);
			if (!gd::is_dict(encounter) || gd::bool_field(state, encounter.ref, key::commanderless_support_column, false)) {
				continue;
			}
			if (string_get(state, encounter.ref, key::spawned_by_player_id, str(key::empty)) == key::empty
					&& string_get(state, encounter.ref, key::spawned_by_faction_id, str(key::empty)) == key::empty) {
				continue;
			}
			// A missing commander or host is a new {}: no roster hero, no stacks.
			Value commander;
			const Atom roster_hero_id = state.lookup(encounter.ref, str(key::enemy_commander_state), commander) && gd::is_dict(commander)
					? string_get(state, commander.ref, key::roster_hero_id, str(key::empty))
					: key::empty;
			Value host;
			const bool host_is_dict = state.lookup(encounter.ref, str(key::enemy_army), host) && gd::is_dict(host);
			if (roster_hero_id == key::empty || _valid_stack_count(state, stacks_of(state, encounter.ref, key::enemy_army)) > 0) {
				continue;
			}
			const DictRef hero_template = gd::content_row(state, state::ContentTable::Hero, roster_hero_id);
			const Atom placement_id = string_get(state, encounter.ref, key::placement_id, str(roster_hero_id));
			const DictRef army = starting_army_for_hero(state, hero_template, restored_army_seed(state, view, placement_id));
			if (army_stacks_empty(state, army)) {
				continue;
			}
			const Value id_fallback = state.get(encounter.ref, str(key::encounter_id), str(key::empty));
			state.set(army, str(key::id), str(string_of(state, host_is_dict ? state.get(host.ref, str(key::id), id_fallback) : id_fallback)));
			state.set(army, str(key::name), str(string_of(state, host_is_dict ? state.get(host.ref, str(key::name), str(key::raid_host)) : str(key::raid_host))));
			state.set(encounter.ref, str(key::enemy_army), dict_value(army));
			state.set_at(encounters.ref, index, encounter);
			raids_restored += 1;
		}
		if (raids_restored > 0) {
			state.set(session_view::overworld(state, view), str(key::encounters), encounters);
		}
	}
	return restored + raids_restored;
}

} // namespace hero_command_rules

} // namespace aurelion::rules::port
