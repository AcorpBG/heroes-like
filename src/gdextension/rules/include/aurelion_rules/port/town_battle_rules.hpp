#pragma once

// scripts/core/TownBattleRules.gd, ported function by function under the
// GDScript names (docs/native-rules-engine-transition.md, Phase 1). Layer 2:
// the town assault effects of a battle.

#include "aurelion_rules/port/gd.hpp"

#include <cstdint>

namespace aurelion::rules::port::town_battle_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using state::State;
using state::Value;

// The effect reads of a stack, the town assault effects and the damage rules'
// multipliers (spell_effects.cpp).
double damage_multiplier(State &state, DictRef battle, DictRef attacker, DictRef defender, bool ranged);
int64_t absorb(State &state, DictRef stack, int64_t damage);
bool defends(State &state, DictRef battle, DictRef stack);
DictRef effect(State &state, DictRef battle, Atom id);

} // namespace aurelion::rules::port::town_battle_rules
