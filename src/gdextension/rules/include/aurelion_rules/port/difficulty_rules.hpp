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
using gd::DictRef;
using state::State;
using state::Value;

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
