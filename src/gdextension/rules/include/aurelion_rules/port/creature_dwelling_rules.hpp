#pragma once

// scripts/core/CreatureDwellingRules.gd, ported function by function under the GDScript
// names (docs/native-rules-engine-transition.md): the ports shared by the computer
// players' day (Phase 4) and the ends of a battle (Phase 5).

#include "aurelion_rules/port/gd.hpp"

#include <cstdint>

namespace aurelion::rules::port::creature_dwelling_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using state::State;

// Phase 4's ports shared with Phase 5's battle ends (creature_dwelling_rules_shared.cpp).
void record_guard_result(State &state, DictRef node, Atom side, ArrayRef survivor_stacks, bool won, int64_t day);

} // namespace aurelion::rules::port::creature_dwelling_rules
