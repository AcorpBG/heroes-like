#pragma once

// scripts/core/WaterTravelRules.gd: the functions the computer players' day runs
// (docs/native-rules-engine-transition.md, Phase 4), ported function by
// function under the GDScript names. A session is its view (session_view.hpp).

#include "aurelion_rules/port/gd.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/water_travel_rules.hpp"
#include "aurelion_rules/port/water_travel_rules_ai.hpp"
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

// Ported in enemy_turn_rules_turn.cpp.
DictRef add_boat(State &state, const Value &session, Vector2i tile, int64_t level, Atom id_hint);
bool any_boat_at(State &state, const Value &session, Vector2i tile, int64_t level);
DictRef boat_by_id(State &state, const Value &session, Atom boat_id);
Atom build_boat(State &state, const Value &session, DictRef node);
Atom dock_blocker(State &state, const Value &session, DictRef node);
DictRef free_boat_at(State &state, const Value &session, Vector2i tile, int64_t level = -1);
bool hero_at(State &state, const Value &session, Vector2i tile, int64_t level);
void place_boat(State &state, const Value &session, Atom boat_id, Atom hero_id, Vector2i tile, int64_t level);

} // namespace aurelion::rules::port::water_travel_rules
