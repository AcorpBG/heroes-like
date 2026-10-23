#pragma once

// scripts/core/SessionStateStore.gd, ported function by function under the GDScript
// names (docs/native-rules-engine-transition.md, Phase 5).

#include "aurelion_rules/port/gd.hpp"

#include <cstdint>

namespace aurelion::rules::port::session_state_store {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using state::State;
using state::Value;

// String(value) when it is a known launch mode, else "campaign"
// (overworld_towns_normalize.cpp).
Atom normalize_launch_mode(State &state, const Value &value);

// SessionStateStore.new_session_data(...): a new SessionData object, which
// GDScript makes (a pure host call, listed in human_registry.cpp). The rules
// fill it through its view (gd::object_view), which the call writes back.
inline Value new_session_data(State &state, Atom session_id, Atom scenario_id, Atom hero_id, int64_t day, DictRef overworld_state, Atom difficulty, Atom launch_mode) {
	return gd::call_static(state, state::key::session_state_store_script, state::key::new_session_data,
			{gd::str(session_id), gd::str(scenario_id), gd::str(hero_id), gd::int_value(day), gd::dict_value(overworld_state),
					gd::str(difficulty), gd::str(launch_mode)});
}

// SessionStateStore.SAVE_VERSION. SUPPORTED_GAME_STATES are "overworld",
// "town", "battle" and "outcome"; SUPPORTED_SCENARIO_STATUSES "in_progress",
// "victory" and "defeat".
constexpr int64_t kSaveVersion = 9;

// The save format's payload (Phase 7, 7.12; save_session_payload.cpp):
// SessionStateStore.normalize_payload and its helpers, and SessionData's
// payload_for_storage and share_runtime_scenario_record, whose GDScript copies
// SessionData.from_dict and to_dict keep (two copies).
DictRef normalize_payload(State &state, const Value &value);
Atom _normalize_game_state(State &state, const Value &value);
Atom _normalize_scenario_status(State &state, const Value &value);
DictRef _dict_or_empty_value(State &state, const Value &value);
DictRef payload_for_storage(State &state, DictRef payload);
void share_runtime_scenario_record(State &state, DictRef overworld_state, DictRef session_flags);

} // namespace aurelion::rules::port::session_state_store
