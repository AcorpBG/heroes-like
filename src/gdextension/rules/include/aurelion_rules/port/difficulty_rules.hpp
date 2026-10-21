#pragma once

// scripts/core/DifficultyRules.gd, ported function by function under the
// GDScript names (docs/native-rules-engine-transition.md). The functions here
// are copies of Phase 1's port (native-phase1-battle, commander_payload.cpp),
// which drops its copies when it takes main; a session is its view
// (session_view.hpp) or, for the battle port, SessionData. ScenarioSelectRules'
// default_difficulty_id and normalize_difficulty are inlined:
// _scenario_select_rules returns the script, so it is not ported.

#include "aurelion_rules/port/gd.hpp"

namespace aurelion::rules::port::difficulty_rules {

using gd::Atom;
using gd::DictRef;
using state::State;
using state::Value;

// A difficulty id (difficulty_rules.cpp).
Atom _default_difficulty_id(State &state);
Atom normalize_difficulty(State &state, const Value &value);

// A difficulty's profile, a new Dictionary; a session's (null: the default
// difficulty's), and its movement bonus.
DictRef profile_for_difficulty(State &state, const Value &difficulty_id);
DictRef profile_for_session(State &state, const Value &session);
int64_t movement_bonus(State &state, const Value &session);

} // namespace aurelion::rules::port::difficulty_rules
