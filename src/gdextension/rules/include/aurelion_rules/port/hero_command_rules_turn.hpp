#pragma once

// scripts/core/HeroCommandRules.gd: the functions the computer players' day runs
// (docs/native-rules-engine-transition.md, Phase 4), ported function by
// function under the GDScript names. A session is its view (session_view.hpp).

#include "aurelion_rules/port/gd.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/battle_ends.hpp"
#include "aurelion_rules/port/hero_command_rules.hpp"
#include "aurelion_rules/port/hero_command_rules_ai.hpp"
#include "aurelion_rules/port/hero_commit.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"

#include <cstdint>

namespace aurelion::rules::port::hero_command_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using gd::PackedRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// Ported in hero_rules_turn.cpp.
ArrayRef _faction_creatures(State &state, Atom faction_id, int64_t tier);
DictRef _normalize_resources(State &state, const Value &value);
Value _seeded_rng(State &state, Atom seed_key);
bool _stack_slot_less(State &state, DictRef left, DictRef right);
int64_t _starting_company_size(State &state, const Value &rng, Atom unit_id, ArrayRef growth_share);
DictRef army_addition_split(State &state, const Value &stacks_value, DictRef additions);
DictRef build_hero_from_template(State &state, DictRef hero_template, DictRef position, DictRef army_state, const Value &movement_source = Value());
DictRef build_recruited_hero(State &state, DictRef hero_template, DictRef position, const Value &movement_source, int64_t level, const Value &army_state, Atom seed_key = state::key::empty, Atom growth_seed = state::key::empty);
DictRef hero_recruit_cost(State &state, DictRef hero_template);
int64_t scout_row_half_width(State &state, int64_t dy, int64_t radius);
DictRef starting_army_for_hero(State &state, DictRef hero_template, Atom seed_key);
DictRef tavern_offer(State &state, DictRef session, Atom hero_id, int64_t week = -1);
int64_t tavern_week(State &state, DictRef session);
bool town_has_hall(State &state, DictRef town);

// Ported in turn_rare_paths.cpp (slice 4.2: paths the six seeds do not run).
ArrayRef _holder_stacks(State &state, DictRef session, DictRef town, Atom holder_id);
ArrayRef merge_stacks_into_army(State &state, ArrayRef army, ArrayRef incoming);
DictRef set_active_hero(State &state, DictRef session, Atom hero_id);

} // namespace aurelion::rules::port::hero_command_rules
