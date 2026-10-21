#pragma once

// scripts/core/PlayerIdentityRules.gd
// (docs/native-rules-engine-transition.md, Phase 3: the AI targets), ported
// function by function under the GDScript names. A session is its view
// (session_view.hpp).

#include "aurelion_rules/port/gd.hpp"
#include "aurelion_rules/port/player_identity_rules.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"

#include <cstdint>

namespace aurelion::rules::port::player_identity_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using gd::PackedRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// Ported in player_identity_rules_ai.cpp.
Atom resource_controller_id(State &state, DictRef node);
bool allied(State &state, const Value &session, Atom first, Atom second);

} // namespace aurelion::rules::port::player_identity_rules
