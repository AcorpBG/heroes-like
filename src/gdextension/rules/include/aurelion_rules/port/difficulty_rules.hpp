#pragma once

// scripts/core/DifficultyRules.gd, ported function by function under the
// GDScript names (docs/native-rules-engine-transition.md). The two functions
// here are copies of Phase 1's port (native-phase1-battle, commander_payload.cpp),
// which drops its copies when it takes main. ScenarioSelectRules'
// default_difficulty_id and normalize_difficulty are inlined: _scenario_select_rules
// returns the script, so it is not ported.

#include "aurelion_rules/port/gd.hpp"

namespace aurelion::rules::port::difficulty_rules {

using gd::Atom;
using state::State;
using state::Value;

// A difficulty id (difficulty_rules.cpp).
Atom _default_difficulty_id(State &state);
Atom normalize_difficulty(State &state, const Value &value);

} // namespace aurelion::rules::port::difficulty_rules
