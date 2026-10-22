#pragma once

// scripts/core/TownBattleRules.gd, ported function by function under the
// GDScript names (docs/native-rules-engine-transition.md, Phase 1). Layer 2:
// the town assault effects of a battle. Layers 3 and 4: the movement penalty
// and the round's healing. Layer 7: the spell resistance of a defending stack.

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

// Layers 3 and 4.

// The board setup: deployment hexes, the hex state of a battle, moving a stack
// and its walk path (board_setup.cpp).
int64_t movement_penalty(State &state, DictRef battle, DictRef stack);

// Round effects: foundry repair, town healing, pressure shifts, cohesion and
// momentum (round_effects.cpp).
ArrayRef heal_round(State &state, DictRef battle);

// Layer 7.

// The prism ward's spell resistance (spell_effects.cpp).
int64_t spell_resistance(State &state, DictRef battle, DictRef stack);

} // namespace aurelion::rules::port::town_battle_rules
