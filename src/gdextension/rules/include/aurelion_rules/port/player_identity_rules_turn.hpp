#pragma once

// scripts/core/PlayerIdentityRules.gd: the functions the computer players' day runs
// (docs/native-rules-engine-transition.md, Phase 4), ported function by
// function under the GDScript names. A session is its view (session_view.hpp).

#include "aurelion_rules/port/gd.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/battle_ends.hpp"
#include "aurelion_rules/port/player_identity_rules.hpp"
#include "aurelion_rules/port/player_identity_rules_ai.hpp"
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

// Ported in enemy_turn_rules_turn.cpp.
void set_resource_controller(State &state, DictRef node, const Value &session, Atom controller);

// Ported in turn_rare_paths.cpp (slice 4.2: paths the six seeds do not run).
DictRef config_for_controller(State &state, const Value &session, Atom controller);

} // namespace aurelion::rules::port::player_identity_rules
