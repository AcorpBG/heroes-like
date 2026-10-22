#pragma once

// scripts/core/NativeTransitRules.gd, ported function by function under the
// GDScript names (docs/native-rules-engine-transition.md, Phase 5).

#include "aurelion_rules/port/gd.hpp"

namespace aurelion::rules::port::native_transit_rules {

using gd::DictRef;
using state::State;

bool is_native(State &state, DictRef node);


// Old packages' transit links rebuilt and validated, the portal networks'
// colours (overworld_transit_normalize.cpp).
void normalize_legacy_session(State &state, DictRef session);
gd::Atom contract_error(State &state, DictRef node, DictRef indexed);
gd::Atom _portal_contract_error(State &state, DictRef node, DictRef indexed);
gd::ArrayRef validate(State &state, gd::ArrayRef nodes);
void assign_network_colours(State &state, gd::ArrayRef nodes);
int64_t network_index(State &state, DictRef node);
DictRef nodes_by_id(State &state, gd::ArrayRef nodes);
bool is_dead_end(State &state, DictRef object);
gd::Atom _network_colour_key(State &state, DictRef node);

} // namespace aurelion::rules::port::native_transit_rules
