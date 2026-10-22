#pragma once

// scripts/core/NativeTransitRules.gd: the functions the computer players' day runs
// (docs/native-rules-engine-transition.md, Phase 4), ported function by
// function under the GDScript names. A session is its view (session_view.hpp).

#include "aurelion_rules/port/gd.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/native_transit_rules.hpp"
#include "aurelion_rules/port/native_transit_rules_ai.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"

#include <cstdint>

namespace aurelion::rules::port::native_transit_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using gd::PackedRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// Ported in hero_rules_turn.cpp.
DictRef resolve(State &state, ArrayRef nodes, DictRef node, Atom target_id = state::key::empty);

// Ported in overworld_rules_turn.cpp.
ArrayRef exit_order(State &state, DictRef node, Atom key);

} // namespace aurelion::rules::port::native_transit_rules
