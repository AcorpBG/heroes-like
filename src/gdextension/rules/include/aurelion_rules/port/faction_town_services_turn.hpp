#pragma once

// scripts/core/FactionTownServices.gd: the functions the computer players' day runs
// (docs/native-rules-engine-transition.md, Phase 4), ported function by
// function under the GDScript names. A session is its view (session_view.hpp).

#include "aurelion_rules/port/gd.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"

#include <cstdint>

namespace aurelion::rules::port::faction_town_services {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using gd::PackedRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// Ported in enemy_turn_rules_turn.cpp.
void apply_ai_weights(State &state, DictRef weights);
DictRef perform(State &state, DictRef hero, DictRef town, DictRef building, int64_t day, DictRef resources);
DictRef recruit_reward(State &state, DictRef town, DictRef service);
Atom unavailable_reason(State &state, DictRef hero, DictRef town, DictRef building, int64_t day, DictRef resources);
bool useful_to_ai(State &state, DictRef hero, DictRef town, DictRef building, int64_t day, DictRef resources);
int64_t week(State &state, int64_t day);

} // namespace aurelion::rules::port::faction_town_services
