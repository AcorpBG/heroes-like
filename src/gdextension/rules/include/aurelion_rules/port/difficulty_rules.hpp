#pragma once

// scripts/core/DifficultyRules.gd, ported function by function under the
// GDScript names (docs/native-rules-engine-transition.md). Phase 1, layer 2:
// the battle initiative and damage of a session's difficulty. The difficulty
// id is a shared helper on main (difficulty_rules.cpp).
// ScenarioSelectRules' default_difficulty_id and normalize_difficulty are
// inlined: _scenario_select_rules returns the script, so it is not ported.

#include "aurelion_rules/port/gd.hpp"

#include <cstdint>

namespace aurelion::rules::port::difficulty_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using state::State;
using state::Value;

// The commander payload: a side's hero payload, its specialty bonuses and
// difficulty terms (commander_payload.cpp).
double damage_multiplier_for_side(State &state, const Value &session, Atom side);
int64_t initiative_bonus_for_side(State &state, const Value &session, Atom side);
DictRef profile_for_session(State &state, const Value &session);
DictRef profile_for_difficulty(State &state, const Value &difficulty_id);

// A difficulty id (difficulty_rules.cpp).
Atom _default_difficulty_id(State &state);
Atom normalize_difficulty(State &state, const Value &value);

} // namespace aurelion::rules::port::difficulty_rules
