#pragma once

// scripts/core/HeroProgressionRules.gd: the functions the computer players' day runs
// (docs/native-rules-engine-transition.md, Phase 4), ported function by
// function under the GDScript names. A session is its view (session_view.hpp).

#include "aurelion_rules/port/gd.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/enemy_states.hpp"
#include "aurelion_rules/port/hero_progression_rules.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"

#include <cstdint>

namespace aurelion::rules::port::hero_progression_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using gd::PackedRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// Ported in hero_rules_turn.cpp.
DictRef advance_to_level(State &state, DictRef hero_state, int64_t target_level);
int64_t experience_for_level(State &state, int64_t level);
int64_t pending_choices_remaining(State &state, DictRef hero_state);
Atom rank_label(State &state, int64_t rank);

} // namespace aurelion::rules::port::hero_progression_rules
