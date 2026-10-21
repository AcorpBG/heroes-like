#pragma once

// scripts/core/HeroCommandRules.gd, ported function by function under the
// GDScript names (docs/native-rules-engine-transition.md, Phase 5).

#include "aurelion_rules/port/gd.hpp"

#include <cstdint>

namespace aurelion::rules::port::hero_command_rules {

using gd::DictRef;
using state::State;

// A hero's sight (hero_command_rules.cpp).
int64_t scouting_radius_for_hero(State &state, DictRef hero_state);
int64_t scout_row_half_width(int64_t dy, int64_t radius);


// The player's heroes normalized (overworld_towns_normalize.cpp).
void normalize_session(State &state, DictRef session, gd::Atom primary_hero_id, DictRef default_position, DictRef default_army);
void _normalize_town_garrison_heroes(State &state, DictRef session);
void _replace_hero_in_array(State &state, gd::ArrayRef player_heroes, DictRef replacement);

} // namespace aurelion::rules::port::hero_command_rules
