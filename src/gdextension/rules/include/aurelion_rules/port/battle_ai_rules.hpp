#pragma once

// scripts/core/BattleAiRules.gd, ported function by function under the
// GDScript names. Layer 1: the AI's own copies of the hex geometry and board
// reads. Where a copy's body is BattleRules' word for word, it calls the
// BattleRules port.
//
// The scoring memos (_scoring_living_entry, _stack_term_memo and
// _keep_stack_term) are not ported: they are transparent, so the native reads
// go without them and the shadow checks prove it. _stack_contact_band and
// _stack_is_engaged are therefore _stack_contact_band_on and _stack_engaged_on.
//
// Not ported: _stack_is_isolated (calls _allied_melee_count, layer 2, and
// reads the living memo's melee count) and _stack_is_hex_isolated (calls it).

#include "aurelion_rules/port/gd.hpp"

#include <cstdint>

namespace aurelion::rules::port::battle_ai_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using state::State;
using state::Value;

int64_t _alive_count(const State &state, DictRef stack);
ArrayRef _alive_stacks_for_side(State &state, DictRef battle, Atom side);
int64_t _distance_band_from_hex_distance(int64_t hex_distance);
double _health_ratio(const State &state, DictRef stack);
DictRef _hex_cell(State &state, int64_t q, int64_t r);
bool _hex_in_bounds(int64_t q, int64_t r);
bool _is_same_stack(const State &state, DictRef lhs, DictRef rhs);
ArrayRef _living_stacks_of_side(State &state, const Value &stacks, Atom side);
DictRef _normalize_hex_cell(State &state, const Value &value);
Atom _opposing_side(Atom side);
ArrayRef _projected_on_cell(State &state, DictRef battle, DictRef stack, DictRef cell);
DictRef _stack_by_battle_id(State &state, DictRef battle, Atom battle_id);
int64_t _stack_contact_band(State &state, DictRef stack, DictRef battle);
int64_t _stack_contact_band_on(State &state, DictRef stack, DictRef battle);
bool _stack_engaged_on(State &state, DictRef stack, DictRef battle);
DictRef _stack_hex(State &state, DictRef stack);
int64_t _stack_hex_distance(State &state, DictRef lhs, DictRef rhs);
bool _stack_is_engaged(State &state, DictRef stack, DictRef battle);

} // namespace aurelion::rules::port::battle_ai_rules
