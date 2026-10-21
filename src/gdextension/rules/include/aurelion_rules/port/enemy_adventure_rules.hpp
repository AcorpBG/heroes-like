#pragma once

// scripts/core/EnemyAdventureRules.gd, ported function by function under the
// GDScript names (docs/native-rules-engine-transition.md, Phase 5).

#include "aurelion_rules/port/gd.hpp"

namespace aurelion::rules::port::enemy_adventure_rules {

using gd::Atom;
using state::State;
using state::Value;

// Whether a placement is resolved: resolved_encounters is the session's list,
// or a lookup Dictionary of it (enemy_adventure_rules.cpp).
bool _placement_resolved(State &state, Atom placement_id, const Value &resolved_encounters);

} // namespace aurelion::rules::port::enemy_adventure_rules
