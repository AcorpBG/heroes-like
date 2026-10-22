#pragma once

// scripts/core/WaterTravelRules.gd, ported function by function under the GDScript
// names (docs/native-rules-engine-transition.md, Phase 5). A session is
// its view (session_view.hpp). Phase 3's ports are in water_travel_rules_ai.hpp.

#include "aurelion_rules/port/gd.hpp"

#include <cstdint>

namespace aurelion::rules::port::water_travel_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using state::State;
using state::Value;

// The boats and the heroes aboard them kept consistent
// (overworld_transit_normalize.cpp).
void normalize(State &state, DictRef session);

} // namespace aurelion::rules::port::water_travel_rules
