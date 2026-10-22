#pragma once

// scripts/core/TownRules.gd, ported function by function under the GDScript
// names (docs/native-rules-engine-transition.md): the ports shared by the computer
// players' day (Phase 4) and the ends of a battle (Phase 5).

#include "aurelion_rules/port/gd.hpp"

#include <cstdint>

namespace aurelion::rules::port::town_rules {

using gd::ArrayRef;
using gd::DictRef;
using state::State;

// Phase 4's ports shared with Phase 5's battle ends (town_rules_shared.cpp): the
// spells a town's mage guild teaches.
int64_t current_spell_tier(State &state, DictRef town);
ArrayRef accessible_spell_ids(State &state, DictRef town);
ArrayRef spell_ids_through_tier(State &state, DictRef town, int64_t tier);
ArrayRef _school_spell_ids_for_town(State &state, DictRef town_template, int64_t tier);
ArrayRef _town_spell_school_access(State &state, DictRef town_template);

} // namespace aurelion::rules::port::town_rules
