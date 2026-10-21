#pragma once

// scripts/core/DifficultyRules.gd
// (docs/native-rules-engine-transition.md, Phase 3: the AI targets), ported
// function by function under the GDScript names. A session is its view
// (session_view.hpp).

#include "aurelion_rules/port/gd.hpp"
#include "aurelion_rules/port/difficulty_rules.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"

#include <cstdint>

namespace aurelion::rules::port::difficulty_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using gd::PackedRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// Ported in difficulty_rules_ai.cpp.
DictRef profile_for_difficulty(State &state, const Value &difficulty_id);
// A null session is GDScript's null SessionData. The battle port passes the
// SessionData object itself, not its view.
DictRef profile_for_session(State &state, const Value &session);
int64_t movement_bonus(State &state, const Value &session);

} // namespace aurelion::rules::port::difficulty_rules
