#pragma once

// scripts/core/OverworldLevelRules.gd, ported function by function under the
// GDScript names (docs/native-rules-engine-transition.md, Phase 5). A session is
// its view (session_view.hpp).

#include "aurelion_rules/port/gd.hpp"

#include <cstdint>

namespace aurelion::rules::port::overworld_level_rules {

using gd::DictRef;
using state::State;
using state::Value;

int64_t level_of(State &state, const Value &value);
bool on_level(State &state, const Value &value, int64_t level);
int64_t hero_level(State &state, DictRef session);
int64_t level_count(State &state, DictRef session);
int64_t query_level(State &state, DictRef session, int64_t requested);
// position() of a Dictionary.
DictRef position(State &state, DictRef value);
DictRef town_entrance(State &state, DictRef town);

} // namespace aurelion::rules::port::overworld_level_rules
