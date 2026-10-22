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

} // namespace aurelion::rules::port::session_state_store
