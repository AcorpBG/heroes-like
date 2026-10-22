#pragma once

// scripts/core/HeroProgressionRules.gd, ported function by function under the
// GDScript names (docs/native-rules-engine-transition.md, Phase 1). Layer 2:
// aggregate_bonuses, a hero's specialty bonuses.

#include "aurelion_rules/port/gd.hpp"

#include <cstdint>

namespace aurelion::rules::port::hero_progression_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using state::State;
using state::Value;

// The commander payload: a side's hero payload, its specialty bonuses and
// difficulty terms (commander_payload.cpp).
//
// _specialty_catalog keeps GDScript's memo in HeroProgressionRules' static
// vars (_catalog_source, _catalog_index): the call that builds the index
// assigns them, so a ported function that reaches it is a writing one, and its
// shadow runs the native call first (a validating subsystem).
DictRef aggregate_bonuses(State &state, DictRef hero_state);
void _merge_bonuses(State &state, DictRef target, DictRef source, DictRef hero_state);
ArrayRef _normalize_specialties_in(State &state, DictRef catalog, const Value &value);
DictRef _rank_bonuses(State &state, DictRef row, int64_t rank);
int64_t _rank_in_array(State &state, ArrayRef specialty_ids, Atom specialty_id);
DictRef _specialty_catalog(State &state);
Atom _resolve_bonus_key(State &state, Atom key, DictRef hero_state);
Value _sum_bonus(State &state, const Value &current, const Value &added);

// A spell's mana cost after the hero's specialty discounts, shared with the
// battle port (hero_progression_rules.cpp).
int64_t adjusted_mana_cost(State &state, DictRef hero_state, int64_t base_cost, Atom school_id);

// A hero's extra maximum mana from its specialties, shared with the battle
// port (hero_progression_rules.cpp).
int64_t mana_max_bonus(State &state, DictRef hero_state);

// A hero's daily income from artifacts and specialties (day_economy.cpp).
DictRef daily_income_bonus(State &state, DictRef hero_state);

// Phase 4's ports shared with Phase 5's battle ends (hero_progression_rules_shared.cpp).
DictRef _add_experience(State &state, DictRef hero_state, int64_t amount);
DictRef _apply_command_gain(State &state, const Value &command_state, Atom stat);
DictRef _enqueue_choice_group(State &state, DictRef hero_state, int64_t level_number);
DictRef add_experience(State &state, DictRef hero_state, int64_t amount);
Atom command_gain_stat(State &state, DictRef hero_state, int64_t level_number);
int64_t experience_with_bonus(State &state, DictRef hero_state, int64_t amount);
Atom pending_choice_summary(State &state, DictRef pending_choice);

} // namespace aurelion::rules::port::hero_progression_rules
