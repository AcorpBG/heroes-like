#pragma once

// scripts/core/SpellRules.gd, ported function by function under the GDScript
// names (docs/native-rules-engine-transition.md). Phase 1, layer 2: the effect
// reads of a battle stack, the normalizers they use and
// normalize_school_resistance. Layer 4: status immunity and normalizing and
// purging a stack's effects. _normalize_spell_ids is a shared helper on main
// (spell_rules.cpp).

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

// Layers 3 and 4.

// Stack effects: applying, spending, expiring and cleansing effects, defending
// and the readiness writ (stack_effects.cpp).
ArrayRef stack_status_immunity_ids(State &state, DictRef stack, DictRef battle);
bool target_is_immune_to_status(State &state, DictRef target_stack, DictRef battle, Atom status_id);
DictRef normalize_stack_effects(State &state, DictRef stack);
DictRef purge_expired_stack_effects(State &state, DictRef stack, int64_t round_number);

// A list of spell ids, the empty ones dropped (spell_rules.cpp).
ArrayRef _normalize_spell_ids(State &state, const Value &value);

} // namespace aurelion::rules::port::spell_rules
