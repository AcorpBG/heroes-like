#pragma once

// scripts/core/ArtifactRules.gd, ported function by function under the GDScript
// names (docs/native-rules-engine-transition.md, Phase 5): a hero's artifacts,
// normalized, and the bonuses they and their sets give.

#include "aurelion_rules/port/gd.hpp"

#include <cstdint>

namespace aurelion::rules::port::artifact_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using state::State;
using state::Value;

DictRef aggregate_bonuses(State &state, DictRef hero_state);
DictRef ensure_hero_artifacts(State &state, DictRef hero_state);
DictRef normalize_hero_artifacts(State &state, const Value &value);
DictRef _blank_equipped_slots(State &state);
void _register_equipped_candidate(State &state, Atom artifact_id, DictRef equipped, ArrayRef inventory, Atom preferred_slot);
Atom _first_empty_slot_from_candidates(State &state, DictRef equipped, ArrayRef candidates);
void _append_inventory_artifact(State &state, Atom artifact_id, DictRef equipped, ArrayRef inventory);
bool _artifact_exists(State &state, Atom artifact_id);
bool _artifact_is_owned(State &state, DictRef equipped, ArrayRef inventory, Atom artifact_id);
Atom artifact_slot(State &state, Atom artifact_id);
ArrayRef _compatible_equipment_slots(State &state, Atom slot_type);
DictRef _blank_bonus_totals(State &state);
void _apply_bonus_payload(State &state, DictRef totals, const Value &bonuses_value, DictRef modifier_source, Atom modifier_source_id);
DictRef _merge_school_resistance(State &state, const Value &base, const Value &delta);
DictRef _merge_resources(State &state, const Value &base, const Value &delta);
ArrayRef _artifact_spell_modifier_records(State &state, DictRef artifact, Atom artifact_id);
ArrayRef _set_states_for_equipped(State &state, const Value &equipped);
DictRef artifact_set_insignia_state(State &state, Atom set_id);
DictRef artifact_set_record(State &state, Atom set_id);
ArrayRef _string_array(State &state, const Value &value);


// The map's artifact nodes (overworld_state_normalize.cpp).
ArrayRef build_artifact_nodes(State &state, const Value &placements, Atom scenario_id = state::key::empty);
ArrayRef normalize_artifact_nodes(State &state, const Value &nodes, Atom scenario_id = state::key::empty);

} // namespace aurelion::rules::port::artifact_rules
