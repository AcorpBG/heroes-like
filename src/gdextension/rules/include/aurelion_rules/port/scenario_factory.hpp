#pragma once

// scripts/core/ScenarioFactory.gd, ported function by function under the GDScript
// names (docs/native-rules-engine-transition.md, Phase 5). Phase 3's
// ports are in scenario_factory_ai.hpp.

#include "aurelion_rules/port/gd.hpp"

#include <cstdint>

namespace aurelion::rules::port::scenario_factory {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using state::State;
using state::Value;

// An army group's state and a resources Dictionary (overworld_state_normalize.cpp).
DictRef _build_army_state(State &state, DictRef army_template);
DictRef _normalize_resources(State &state, const Value &value);

} // namespace aurelion::rules::port::scenario_factory
