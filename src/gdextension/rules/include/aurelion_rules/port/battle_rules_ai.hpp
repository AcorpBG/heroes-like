#pragma once

// scripts/core/BattleRules.gd
// (docs/native-rules-engine-transition.md, Phase 3: the AI targets), ported
// function by function under the GDScript names. A session is its view
// (session_view.hpp).

#include "aurelion_rules/port/gd.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"

#include <cstdint>

namespace aurelion::rules::port::battle_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using gd::PackedRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// Ported in battle_rules_ai.cpp.
DictRef _enemy_army_for_encounter(State &state, DictRef encounter_placement, DictRef encounter);
DictRef battle_rewards_for_strength(State &state, DictRef encounter, const Value &beaten_stacks, const Value &commander);

} // namespace aurelion::rules::port::battle_rules
