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
DictRef aggregate_bonuses(State &state, DictRef hero_state);
void _merge_bonuses(State &state, DictRef target, DictRef source, DictRef hero_state);
ArrayRef _normalize_specialties_in(State &state, DictRef catalog, const Value &value);
DictRef _rank_bonuses(State &state, DictRef row, int64_t rank);
int64_t _rank_in_array(State &state, ArrayRef specialty_ids, Atom specialty_id);
DictRef _specialty_catalog(State &state);
Atom _resolve_bonus_key(State &state, Atom key, DictRef hero_state);
Value _sum_bonus(State &state, const Value &current, const Value &added);

} // namespace aurelion::rules::port::hero_progression_rules
