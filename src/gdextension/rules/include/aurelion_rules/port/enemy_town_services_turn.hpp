#pragma once

// scripts/core/EnemyTownServices.gd: the functions the computer players' day runs
// (docs/native-rules-engine-transition.md, Phase 4), ported function by
// function under the GDScript names. A session is its view (session_view.hpp).

#include "aurelion_rules/port/gd.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"

#include <cstdint>

namespace aurelion::rules::port::enemy_town_services {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using gd::PackedRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// Ported in enemy_turn_rules_turn.cpp.
void apply_ai_weights(State &state, DictRef weights);
bool can_visit(State &state, DictRef town, DictRef raid, Atom controller);
DictRef upgrade_stacks(State &state, DictRef town, ArrayRef stacks, DictRef treasury);
DictRef visit(State &state, DictRef town, DictRef raid, DictRef treasury, int64_t day, Atom controller);

// Ported in turn_rare_paths.cpp (slice 4.2: paths the six seeds do not run).
DictRef best_equipment(State &state, DictRef hero, Atom artifact_id);
double loadout_value(State &state, DictRef hero);

} // namespace aurelion::rules::port::enemy_town_services
