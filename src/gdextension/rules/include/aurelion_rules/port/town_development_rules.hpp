#pragma once

// scripts/core/TownDevelopmentRules.gd, ported function by function under the GDScript
// names (docs/native-rules-engine-transition.md, Phase 5). Phase 3's
// ports are in town_development_rules_ai.hpp.

#include "aurelion_rules/port/gd.hpp"

#include <cstdint>

namespace aurelion::rules::port::town_development_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using state::State;
using state::Value;

// A town's buildings and reserves brought to the current development version
// (overworld_towns_normalize.cpp).
void migrate_town(State &state, DictRef town);
void convert_reserves(State &state, DictRef town);

} // namespace aurelion::rules::port::town_development_rules
