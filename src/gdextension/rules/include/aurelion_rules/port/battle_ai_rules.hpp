#pragma once

// scripts/core/BattleAiRules.gd, ported function by function under the
// GDScript names. Layer 1: the AI's own copies of the hex geometry and board
// reads. Where a copy's body is BattleRules' word for word, it calls the
// BattleRules port.
//
// The scoring memos of one AI decision (_scoring_living_entry, _stack_term_memo
// and _keep_stack_term) are GDScript's static vars (_scoring_scope_depth,
// _scoring_living, _scoring_stack_terms), read and written through the host as
// the GDScript does: _alive_stacks_for_side, _stack_contact_band and
// _stack_is_engaged keep their entries inside a scoring scope.
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


// Layer 2: the faction tags and the commander payload merge.

// The commander payload: a side's hero payload, its specialty bonuses and
// difficulty terms (commander_payload.cpp).
DictRef _merged_commander_ai_payload(State &state, DictRef primary_payload, DictRef secondary_payload);
bool _commander_payloads_can_merge(State &state, DictRef primary_payload, DictRef secondary_payload);
DictRef _merge_commander_spellbooks_for_ai(State &state, DictRef merged, DictRef secondary_payload);
ArrayRef _normalize_string_array(State &state, const Value &value);
ArrayRef _commander_identity_tokens(State &state, DictRef payload);
bool _commander_identity_tokens_match(State &state, Atom left_token, Atom right_token);

// Abilities, battle tags, traits and the side counts the bonuses read
// (ability_helpers.cpp).
bool faction_brings_tag(State &state, DictRef stack, Atom tag);
ArrayRef faction_brought_tags(State &state, DictRef stack);

} // namespace aurelion::rules::port::battle_ai_rules
