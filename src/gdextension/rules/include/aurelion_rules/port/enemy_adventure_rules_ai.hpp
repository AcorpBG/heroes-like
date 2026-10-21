#pragma once

// scripts/core/EnemyAdventureRules.gd
// (docs/native-rules-engine-transition.md, Phase 3: the AI targets), ported
// function by function under the GDScript names. A session is its view
// (session_view.hpp).

#include "aurelion_rules/port/gd.hpp"
#include "aurelion_rules/port/enemy_adventure_rules.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"

#include <cstdint>

namespace aurelion::rules::port::enemy_adventure_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using gd::PackedRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// Ported in enemy_adventure_rules_ai.cpp.
Atom _visit_key(State &state, Atom faction_id);
DictRef _find_resource_by_placement(State &state, DictRef session, Atom placement_id);
DictRef _guard_link_for_encounter(State &state, DictRef encounter);
DictRef _artifact_guard_encounter_for_node(State &state, DictRef session, DictRef node, const Value &positions = Value());
bool _resource_site_is_persistent(State &state, DictRef site);
bool _resource_node_contestable_by_faction(State &state, DictRef node, DictRef site, Atom faction_id, const Value &session = Value());
DictRef _resource_site_claim_rewards(State &state, DictRef site);

bool _is_active_raid(State &state, const Value &encounter, Atom faction_id, const Value &resolved_encounters);
bool _encounter_is_pressure_host_candidate(State &state, const Value &encounter, Atom faction_id, const Value &resolved_encounters);
bool _artifact_guard_link_targets_node(State &state, DictRef guard, DictRef node);
bool _generated_object_guard_targets(State &state, DictRef encounter, Atom target_kind, Atom target_placement_id);
DictRef _find_artifact_by_placement(State &state, DictRef session, Atom placement_id);

void apply_ai_weights(State &state, DictRef weights);

} // namespace aurelion::rules::port::enemy_adventure_rules
