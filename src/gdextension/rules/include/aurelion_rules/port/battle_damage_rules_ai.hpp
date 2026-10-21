#pragma once

// scripts/core/BattleDamageRules.gd
// (docs/native-rules-engine-transition.md, Phase 3: the AI targets), ported
// function by function under the GDScript names. A session is its view
// (session_view.hpp).

#include "aurelion_rules/port/gd.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"

#include <cstdint>

namespace aurelion::rules::port::battle_damage_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using gd::PackedRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// Ported in battle_damage_rules_ai.cpp.
double attack_defense_multiplier(State &state, int64_t attack_stat, int64_t defense_stat);

} // namespace aurelion::rules::port::battle_damage_rules
