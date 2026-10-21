#pragma once

// scripts/core/ScenarioFactory.gd
// (docs/native-rules-engine-transition.md, Phase 3: the AI targets), ported
// function by function under the GDScript names. A session is its view
// (session_view.hpp).

#include "aurelion_rules/port/gd.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"

#include <cstdint>

namespace aurelion::rules::port::scenario_factory {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using gd::PackedRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// Ported in scenario_factory_ai.cpp.
DictRef _seed_recruits(State &state, ArrayRef built_buildings);
DictRef _seed_recruits_for_town_state(State &state, DictRef town);
DictRef _apply_growth_profile(State &state, DictRef recruits, const Value &profile);
int64_t _unit_growth(State &state, Atom unit_id);
ArrayRef _duplicate_array(State &state, const Value &value);

} // namespace aurelion::rules::port::scenario_factory
