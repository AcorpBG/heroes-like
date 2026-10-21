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

} // namespace aurelion::rules::port::hero_command_rules
