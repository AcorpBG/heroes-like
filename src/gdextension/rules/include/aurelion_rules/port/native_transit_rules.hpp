#pragma once

// scripts/core/NativeTransitRules.gd, ported function by function under the
// GDScript names (docs/native-rules-engine-transition.md, Phase 5).

#include "aurelion_rules/port/gd.hpp"

namespace aurelion::rules::port::native_transit_rules {

using gd::DictRef;
using state::State;

bool is_native(State &state, DictRef node);

} // namespace aurelion::rules::port::native_transit_rules
