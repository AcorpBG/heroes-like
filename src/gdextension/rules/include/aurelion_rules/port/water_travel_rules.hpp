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

// Town harbours (water_travel_rules_ai.cpp; docs/water-travel.md): each town on a
// level with water gets `harbor` once, the open-sea tile its boats launch on and
// the steps from its gate, or {} when no open sea lies within reach.
void ensure_harbors(State &state, DictRef session);
bool town_has_harbor(State &state, DictRef town);
// A building only a harbour town may have (the Shipyard), in a town without one.
bool needs_missing_harbor(State &state, DictRef town, DictRef building);
// The Shipyard a harbour town has built (its building id), or "".
Atom town_shipyard_id(State &state, DictRef town);
// A harbour town's walk to its boats, filled into one of two lines: "3 steps"
// into `walk`, or `beside` when the water touches the gate.
Atom harbor_line(State &state, DictRef town, Atom walk, Atom beside);

} // namespace aurelion::rules::port::water_travel_rules
