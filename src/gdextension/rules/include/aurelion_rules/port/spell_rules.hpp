#pragma once

// scripts/core/SpellRules.gd, ported function by function under the GDScript
// names (docs/native-rules-engine-transition.md). Phase 1, layer 2: the effect
// reads of a battle stack, the normalizers they use and
// normalize_school_resistance. Layer 4: status immunity and normalizing and
// purging a stack's effects. Layer 8: the battle spells. _normalize_spell_ids
// and the spell helpers shared with the battle port are on main
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

// Shared with the battle port: a spell's school, tier and roles, its mana cost
// for a hero, and the hero's mana and known spells (spell_rules.cpp).
int64_t adjusted_spell_mana_cost(State &state, DictRef hero_state, const Value &spell);
Atom spell_school_id(State &state, DictRef spell);
int64_t spell_tier(State &state, DictRef spell);
Atom spell_primary_role(State &state, DictRef spell);
ArrayRef spell_role_categories(State &state, DictRef spell);
ArrayRef _normalize_string_array(State &state, const Value &value);
bool _has_mana(State &state, DictRef hero_state, int64_t cost);
bool _knows_spell(State &state, DictRef hero_state, Atom spell_id);

// Layer 5: a battle effect built from an ability (attack_effects.cpp).
DictRef build_battle_effect(State &state, Atom effect_id, Atom label, const Value &modifiers, int64_t duration_rounds, DictRef battle, Atom source_type, Atom source_id, const Value &status_immunity_ids);

// Layer 8: the battle spells. A spell's battle behavior, the cast and target
// checks, spell and control resistance, the damage, recovery and duration of
// a cast, the effect payloads and the status resistance roll
// (spell_battle.cpp). _battle_stream_rng answers a RandomNumberGenerator, or
// Nil for a battle without a seed.
DictRef battle_spell_behavior(State &state, DictRef spell);
DictRef _battle_spell_ally_target(State &state, DictRef active_stack, DictRef target_stack, Atom acting_side);
DictRef battle_spell_cast_check(State &state, DictRef hero, DictRef spell_dict, DictRef active_stack, Atom acting_side);
DictRef battle_spell_target_check(State &state, DictRef battle, DictRef active_stack, DictRef target_stack, DictRef spell_dict, Atom acting_side);
int64_t spell_damage_resistance_pct(State &state, DictRef battle, DictRef target_stack, DictRef spell);
int64_t control_resistance_pct(State &state, DictRef battle, DictRef target_stack, DictRef spell);
DictRef battle_spell_damage_projection(State &state, DictRef hero_state, DictRef battle, DictRef target_stack, DictRef spell);
DictRef battle_spell_status_resolution(State &state, DictRef battle, DictRef active_stack, DictRef target_stack, DictRef spell, DictRef effect_payload);
int64_t spell_duration_bonus(State &state, DictRef hero_state);
int64_t spell_duration_rounds(State &state, DictRef hero_state, const Value &base_rounds, DictRef spell, Atom kind);
int64_t spell_power(State &state, DictRef hero_state);
int64_t _school_bonus(State &state, DictRef bonuses, Atom field, DictRef spell);
DictRef _counted_in_turns(State &state, DictRef effect, int64_t turns);
DictRef battle_spell_modifiers(State &state, DictRef spell);
DictRef _effect_payload(State &state, DictRef spell, DictRef effect, DictRef battle, DictRef hero_state);
DictRef _hero_payload_for_target_side(State &state, DictRef battle, DictRef target_stack);
DictRef _status_resistance_roll(State &state, DictRef battle, DictRef active_stack, DictRef target_stack, DictRef spell, Atom status_id);
Value _battle_stream_rng(State &state, DictRef battle);
int64_t _stable_percent(State &state, ArrayRef parts);
Atom _append_status_resolution_message(State &state, Atom message, DictRef target_stack, DictRef effect_payload, DictRef status_resolution);
DictRef _spell_effect_modifiers(State &state, DictRef effect, Atom default_kind, int64_t default_amount);
DictRef _status_effect_from_spell_effect(State &state, DictRef spell, DictRef battle, DictRef hero_state);
int64_t _battle_spell_damage(State &state, DictRef hero_state, DictRef spell, DictRef target_stack);
bool _wounded_bonus_applies(State &state, DictRef effect, DictRef target_stack);
int64_t _battle_spell_recovery_amount(State &state, DictRef hero_state, DictRef spell);
int64_t _alive_count(State &state, DictRef stack);
double _health_ratio(State &state, DictRef stack);

// Shared with the battle port: a hero's spellbook (known spells, mana)
// normalized in place, the template's starting spells for one that knows none,
// returning the hero; its maximum mana (spell_rules.cpp).
DictRef ensure_hero_spellbook(State &state, DictRef hero_state, DictRef hero_template);
int64_t mana_max_from_hero(State &state, DictRef hero_state);
int64_t mana_max_from_command(State &state, const Value &command);

} // namespace aurelion::rules::port::spell_rules
