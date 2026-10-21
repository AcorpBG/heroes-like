#pragma once

// scripts/core/SpellRules.gd, ported function by function under the GDScript
// names (docs/native-rules-engine-transition.md, Phase 1). Layer 2: the effect
// reads of a battle stack, the normalizers they use and
// normalize_school_resistance.

#include "aurelion_rules/port/gd.hpp"

#include <cstdint>

namespace aurelion::rules::port::spell_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using state::State;
using state::Value;

// The commander payload: a side's hero payload, its specialty bonuses and
// difficulty terms (commander_payload.cpp).
DictRef normalize_school_resistance(State &state, const Value &value);

// The effect reads of a stack, the town assault effects and the damage rules'
// multipliers (spell_effects.cpp).
int64_t battle_spell_recoverable_health(State &state, DictRef stack);
int64_t effect_bonus_for_kind(State &state, DictRef stack, DictRef battle, Atom kind);
bool has_effect_id(State &state, DictRef stack, DictRef battle, Atom effect_id);
bool has_any_effect_ids(State &state, DictRef stack, DictRef battle, const Value &effect_ids);
ArrayRef active_effects_for_round(State &state, DictRef stack, int64_t round_number);
ArrayRef _normalize_effects(State &state, const Value &value);
DictRef _normalize_effect_modifiers(State &state, const Value &value);
ArrayRef normalize_blocked_status_ids(State &state, const Value &value);
ArrayRef normalize_status_immunity_ids(State &state, const Value &value);

} // namespace aurelion::rules::port::spell_rules
