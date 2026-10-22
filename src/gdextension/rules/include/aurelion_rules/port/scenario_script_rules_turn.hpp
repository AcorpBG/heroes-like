#pragma once

// scripts/core/ScenarioScriptRules.gd: the functions the computer players' day runs
// (docs/native-rules-engine-transition.md, Phase 4), ported function by
// function under the GDScript names. A session is its view (session_view.hpp).

#include "aurelion_rules/port/gd.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"

#include <cstdint>

namespace aurelion::rules::port::scenario_script_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using gd::PackedRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// Ported in scenario_turn_rare.cpp (slice 4.2: paths the six seeds do not run).
bool _encounter_resolved(State &state, DictRef session, Atom placement_id);
bool _hook_fired(State &state, DictRef session, Atom hook_id);
DictRef build_script_state(State &state);

} // namespace aurelion::rules::port::scenario_script_rules
