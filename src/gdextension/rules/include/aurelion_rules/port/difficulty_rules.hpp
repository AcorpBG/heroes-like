#pragma once

// scripts/core/DifficultyRules.gd, ported function by function under the
// GDScript names (docs/native-rules-engine-transition.md). Phase 1, layer 2:
// the battle initiative and damage of a session's difficulty. The difficulty
// id (difficulty_rules.cpp) and the difficulty profiles (difficulty_rules_ai.hpp)
// are shared helpers on main.
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

// A difficulty id (difficulty_rules.cpp).
Atom _default_difficulty_id(State &state);
Atom normalize_difficulty(State &state, const Value &value);

// The session's difficulty normalized; its profile (overworld_towns_normalize.cpp).
DictRef normalize_session(State &state, DictRef session);


// Income scaled by the session's difficulty (day_economy.cpp).
DictRef scale_income_resources(State &state, DictRef session, const Value &payload);
DictRef scale_resource_payload(State &state, const Value &payload, double multiplier);
int64_t _scale_amount(State &state, int64_t amount, double multiplier);

} // namespace aurelion::rules::port::difficulty_rules
