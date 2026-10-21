#pragma once

// scripts/core/NativeTransitRules.gd
// (docs/native-rules-engine-transition.md, Phase 3: the AI targets), ported
// function by function under the GDScript names. A session is its view
// (session_view.hpp). Phase 5's ports of the script are in native_transit_rules.hpp.

#include "aurelion_rules/port/gd.hpp"
#include "aurelion_rules/port/native_transit_rules.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"

#include <cstdint>

namespace aurelion::rules::port::native_transit_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using gd::PackedRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// Ported in native_transit_rules_ai.cpp.
bool uses_native_adjacency(State &state, const Value &session);
DictRef link_of(State &state, DictRef node);
ArrayRef destinations(State &state, DictRef node);
Atom portal_kind(State &state, DictRef node);
Value point(State &state, const Value &value);

} // namespace aurelion::rules::port::native_transit_rules
