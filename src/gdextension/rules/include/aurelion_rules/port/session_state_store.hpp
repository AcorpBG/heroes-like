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

} // namespace aurelion::rules::port::session_state_store
