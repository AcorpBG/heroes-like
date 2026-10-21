#pragma once

// scripts/core/WaterTravelRules.gd
// (docs/native-rules-engine-transition.md, Phase 3: the AI targets), ported
// function by function under the GDScript names. A session is its view
// (session_view.hpp).

#include "aurelion_rules/port/gd.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"

#include <cstdint>

namespace aurelion::rules::port::water_travel_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using gd::PackedRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// Ported in water_travel_rules_ai.cpp.
ArrayRef boats(State &state, const Value &session);
Atom hero_boat_id(State &state, const Value &hero);
bool is_water(State &state, const Value &session, int64_t x, int64_t y, int64_t level = -1);
DictRef dock_tile(State &state, const Value &session, DictRef node);

} // namespace aurelion::rules::port::water_travel_rules
