#pragma once

// scripts/core/CreatureDwellingRules.gd
// (docs/native-rules-engine-transition.md, Phase 3: the AI targets), ported
// function by function under the GDScript names. A session is its view
// (session_view.hpp).

#include "aurelion_rules/port/gd.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"

#include <cstdint>

namespace aurelion::rules::port::creature_dwelling_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using gd::PackedRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// Ported in creature_dwelling_rules_ai.cpp.
bool is_dwelling(State &state, DictRef site);
bool is_refugee_camp(State &state, DictRef site);
int64_t week_index(State &state, int64_t day);
int64_t unit_tier(State &state, Atom unit_id);
ArrayRef creatures(State &state, DictRef node, DictRef site, int64_t day);
DictRef weekly_growth(State &state, DictRef node, DictRef site, int64_t day);
DictRef population(State &state, DictRef node, DictRef site, int64_t day);
DictRef unit_cost(State &state, Atom unit_id);
Atom refugee_unit(State &state, DictRef node, int64_t day);
ArrayRef _refugee_candidates(State &state);
Atom base_unit_id(State &state, Atom unit_id);
Atom guard_unit(State &state, DictRef node, DictRef site, int64_t day);
bool is_guarded(State &state, DictRef node, DictRef site, int64_t day);
bool guard_beaten(State &state, DictRef node, Atom side);
bool guard_blocks(State &state, DictRef node, DictRef site, Atom side, int64_t day);
ArrayRef full_guard(State &state, DictRef node, DictRef site, int64_t day);
ArrayRef guard_stacks(State &state, DictRef node, DictRef site, Atom side, int64_t day);
int64_t week_value(State &state, DictRef node, DictRef site, int64_t day, bool available_only = false);
int64_t _stable_roll(State &state, Atom key, int64_t size);

void apply_ai_weights(State &state, DictRef weights);

} // namespace aurelion::rules::port::creature_dwelling_rules
