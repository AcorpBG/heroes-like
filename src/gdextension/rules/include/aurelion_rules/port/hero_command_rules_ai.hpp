#pragma once

// scripts/core/HeroCommandRules.gd
// (docs/native-rules-engine-transition.md, Phase 3: the AI targets), ported
// function by function under the GDScript names. A session is its view
// (session_view.hpp). Phase 5's ports of the script are in hero_command_rules.hpp.

#include "aurelion_rules/port/gd.hpp"
#include "aurelion_rules/port/hero_command_rules.hpp"
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

// Ported in hero_command_rules_ai.cpp.
int64_t movement_max_for_hero(State &state, DictRef hero_state, const Value &movement_source = Value());
int64_t _week_bonus(State &state, DictRef hero_state, Atom key);
bool within_scout_radius(State &state, int64_t dx, int64_t dy, int64_t radius);
DictRef army_addition_plan(State &state, const Value &stacks_value, DictRef additions);
DictRef _normalize_position(State &state, const Value &value);
ArrayRef _slotted_stacks(State &state, const Value &value);
int64_t _valid_stack_count(State &state, const Value &value);
int64_t _first_open_army_slot(State &state, DictRef claimed);

DictRef hero_by_id(State &state, DictRef session, Atom hero_id);
ArrayRef stationed_heroes(State &state, DictRef session, DictRef town);
DictRef town_defending_hero(State &state, DictRef session, DictRef town, Atom preferred_hero_id = state::key::empty);
DictRef town_garrison_hero(State &state, DictRef session, DictRef town);
DictRef town_defense_force(State &state, DictRef session, DictRef town, Atom preferred_hero_id = state::key::empty);
// A hero on a town's entry and the garrison in one battle: {fits, stacks, merged}.
// fits when every stack has one of the battle's seven slots, after stacks of one
// kind merge if needed; merged lists the kinds the garrison added to the hero's
// stacks ({unit_id, hero_count, garrison_count}).
DictRef entry_defense_plan(State &state, const Value &hero_stacks, const Value &garrison);
// The survivors of such a battle back to {hero, garrison}, each kind split by
// what each side brought.
DictRef split_entry_defense(State &state, const Value &hero_stacks, const Value &garrison, const Value &survivors);
int64_t entry_hero_share(int64_t survivors, int64_t hero_count, int64_t garrison_count);
bool _hero_is_stationed_at_town(State &state, DictRef hero, DictRef town);

} // namespace aurelion::rules::port::hero_command_rules
