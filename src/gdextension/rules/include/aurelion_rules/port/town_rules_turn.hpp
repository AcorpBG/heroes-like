#pragma once

// scripts/core/TownRules.gd: the functions the computer players' day runs
// (docs/native-rules-engine-transition.md, Phase 4), ported function by
// function under the GDScript names. A session is its view (session_view.hpp).

#include "aurelion_rules/port/gd.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/town_rules_ai.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"

#include <cstdint>

namespace aurelion::rules::port::town_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using gd::PackedRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// Ported in enemy_turn_rules_turn.cpp.
ArrayRef _school_spell_ids_for_town(State &state, DictRef town_template, int64_t tier);
ArrayRef _town_spell_school_access(State &state, DictRef town_template);
ArrayRef accessible_spell_ids(State &state, DictRef town);
int64_t current_spell_tier(State &state, DictRef town);
ArrayRef spell_ids_through_tier(State &state, DictRef town, int64_t tier);

// Not run by the six seeds: each throws state::NotPorted (turn_not_ported.cpp).
DictRef teach_visiting_heroes(State &state, DictRef session, DictRef town);

} // namespace aurelion::rules::port::town_rules
