#pragma once

// scripts/core/ScenarioFactory.gd: the functions the computer players' day runs
// (docs/native-rules-engine-transition.md, Phase 4), ported function by
// function under the GDScript names. A session is its view (session_view.hpp).

#include "aurelion_rules/port/gd.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/scenario_factory.hpp"
#include "aurelion_rules/port/scenario_factory_ai.hpp"
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

// Not run by the six seeds: each throws state::NotPorted (turn_not_ported.cpp).
ArrayRef _build_resource_states(State &state, const Value &placements);
ArrayRef _build_town_states(State &state, const Value &placements);
void _copy_resource_runtime_metadata(State &state, DictRef target, DictRef source);
DictRef _duplicate_dict(State &state, const Value &value);

} // namespace aurelion::rules::port::scenario_factory
