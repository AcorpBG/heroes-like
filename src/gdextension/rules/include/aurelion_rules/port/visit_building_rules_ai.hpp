#pragma once

// scripts/core/VisitBuildingRules.gd
// (docs/native-rules-engine-transition.md, Phase 3: the AI targets), ported
// function by function under the GDScript names. A session is its view
// (session_view.hpp).

#include "aurelion_rules/port/gd.hpp"
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

// Ported in visit_building_rules_ai.cpp.
bool is_visit_building(State &state, DictRef site);
DictRef spec(State &state, DictRef site);
Atom cadence(State &state, DictRef site);
DictRef cost(State &state, DictRef site, Atom choice_id = state::key::empty);
int64_t required_level(State &state, DictRef site);
ArrayRef choices(State &state, DictRef site);
DictRef effects(State &state, DictRef site, Atom choice_id = state::key::empty);
DictRef readiness(State &state, DictRef node, DictRef site, Atom visitor_key, int64_t day, Atom side = state::key::empty);
int64_t week_index(State &state, int64_t day);
// effect_value: what the effects only the AI's caller can weigh are worth (the
// unseen ground a chart of a level shows).
int64_t ai_value(State &state, DictRef site, double effect_value = 0.0);
// A chart of the whole level the site stands on (a Chartmaker's).
bool reveals_level(State &state, DictRef site);

void apply_ai_weights(State &state, DictRef weights);

} // namespace aurelion::rules::port::visit_building_rules
