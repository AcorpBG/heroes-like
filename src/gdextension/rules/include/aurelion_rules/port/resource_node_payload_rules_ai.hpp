#pragma once

// scripts/core/ResourceNodePayloadRules.gd
// (docs/native-rules-engine-transition.md, Phase 3: the AI targets), ported
// function by function under the GDScript names. A session is its view
// (session_view.hpp).

#include "aurelion_rules/port/gd.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"

#include <cstdint>

namespace aurelion::rules::port::resource_node_payload_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using gd::PackedRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// Ported in resource_node_payload_rules_ai.cpp.
DictRef site_for_node(State &state, DictRef node, DictRef site);
void _erase_claim_recruits(State &state, DictRef effective);
bool claim_payload_spent(State &state, DictRef node, DictRef site);
bool _has_node_payload(State &state, DictRef node, DictRef site);

} // namespace aurelion::rules::port::resource_node_payload_rules
