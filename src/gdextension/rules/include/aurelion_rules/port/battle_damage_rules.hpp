#pragma once

// scripts/core/BattleDamageRules.gd, ported function by function under the
// GDScript names (docs/native-rules-engine-transition.md, Phase 1). Layer 2:
// the hero damage multiplier and the town assault side. The attack and defense
// multiplier is a shared helper on main (battle_damage_rules_ai.hpp).

#include "aurelion_rules/port/gd.hpp"

#include <cstdint>

namespace aurelion::rules::port::battle_damage_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using state::State;
using state::Value;

// The effect reads of a stack, the town assault effects and the damage rules'
// multipliers (spell_effects.cpp).
double hero_damage_multiplier(State &state, DictRef attacker_hero, DictRef defender_hero, bool is_ranged, bool is_retaliation, bool is_town_assault);
Atom town_assault_side(State &state, DictRef battle);

} // namespace aurelion::rules::port::battle_damage_rules
