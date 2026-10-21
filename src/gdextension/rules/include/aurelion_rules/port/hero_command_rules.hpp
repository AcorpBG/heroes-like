#pragma once

// scripts/core/HeroCommandRules.gd, ported function by function under the
// GDScript names (docs/native-rules-engine-transition.md, Phase 5).

#include "aurelion_rules/port/gd.hpp"

#include <cstdint>

namespace aurelion::rules::port::hero_command_rules {

using gd::Atom;
using gd::DictRef;
using state::State;
using state::Value;

// A hero's sight (hero_command_rules.cpp).
int64_t scouting_radius_for_hero(State &state, DictRef hero_state);
int64_t scout_row_half_width(int64_t dy, int64_t radius);

// A hero's movement points a day: movement_source is a session (its view) or a
// difficulty id.
int64_t movement_max_for_hero(State &state, DictRef hero_state, const Value &movement_source);
int64_t _week_bonus(State &state, DictRef hero_state, Atom field);
// OverworldLevelRules.position of a Dictionary, Vector3i or Vector2i; {x: 0, y: 0}
// for anything else.
DictRef _normalize_position(State &state, const Value &value);

} // namespace aurelion::rules::port::hero_command_rules
