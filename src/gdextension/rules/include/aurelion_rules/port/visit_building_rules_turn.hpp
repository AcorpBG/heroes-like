#pragma once

// scripts/core/VisitBuildingRules.gd: the functions the computer players' day runs
// (docs/native-rules-engine-transition.md, Phase 4), ported function by
// function under the GDScript names. A session is its view (session_view.hpp).

#include "aurelion_rules/port/gd.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/visit_building_rules_ai.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"

#include <cstdint>

namespace aurelion::rules::port::visit_building_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using gd::PackedRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// Ported in hero_rules_turn.cpp.
Atom _thousands(State &state, int64_t value);
Atom effect_summary(State &state, DictRef effect);
void record_visit(State &state, DictRef node, DictRef site, Atom visitor_key, int64_t day, Atom side = state::key::empty);

// Ported in turn_rare_paths.cpp (slice 4.2: paths the six seeds do not run).
Atom _resource_text(State &state, DictRef resources);

} // namespace aurelion::rules::port::visit_building_rules
