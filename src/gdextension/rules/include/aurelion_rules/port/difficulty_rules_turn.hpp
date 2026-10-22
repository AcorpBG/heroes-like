#pragma once

// scripts/core/DifficultyRules.gd: the functions the computer players' day runs
// (docs/native-rules-engine-transition.md, Phase 4), ported function by
// function under the GDScript names. A session is its view (session_view.hpp).

#include "aurelion_rules/port/gd.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/difficulty_rules.hpp"
#include "aurelion_rules/port/difficulty_rules_ai.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"

#include <cstdint>

namespace aurelion::rules::port::difficulty_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using gd::PackedRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// Not run by the six seeds: each throws state::NotPorted (turn_not_ported.cpp).
int64_t adjust_enemy_pressure_gain(State &state, DictRef session, int64_t base_gain);
int64_t adjust_raid_threshold(State &state, DictRef session, int64_t base_threshold);

} // namespace aurelion::rules::port::difficulty_rules
