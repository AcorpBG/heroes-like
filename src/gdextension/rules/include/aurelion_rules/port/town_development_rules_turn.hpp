#pragma once

// scripts/core/TownDevelopmentRules.gd: the functions the computer players' day runs
// (docs/native-rules-engine-transition.md, Phase 4), ported function by
// function under the GDScript names. A session is its view (session_view.hpp).

#include "aurelion_rules/port/gd.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/town_development_rules.hpp"
#include "aurelion_rules/port/town_development_rules_ai.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"

#include <cstdint>

namespace aurelion::rules::port::town_development_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using gd::PackedRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// Ported in enemy_turn_rules_turn.cpp.
bool can_pay(State &state, DictRef resources, DictRef cost);
DictRef construction_growth(State &state, DictRef building);
DictRef train_hero(State &state, DictRef hero, DictRef town, Atom building_id);
DictRef upgrade_army(State &state, DictRef town, ArrayRef stacks, Atom base, DictRef resources);
DictRef upgrade_cost(State &state, Atom base, Atom target, int64_t count);

// Ported in turn_rare_paths.cpp (slice 4.2: paths the six seeds do not run).
ArrayRef offers(State &state, DictRef town, int64_t day, ArrayRef excluded_ids);
int64_t price(State &state, DictRef artifact);
bool satisfies(State &state, ArrayRef built, Atom required);
DictRef trade_artifact(State &state, DictRef hero, DictRef town, int64_t day, Atom artifact_id, bool buying, DictRef resources, ArrayRef excluded_ids);

} // namespace aurelion::rules::port::town_development_rules
