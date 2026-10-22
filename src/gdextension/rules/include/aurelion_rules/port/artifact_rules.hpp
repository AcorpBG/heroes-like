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

// The spell modifiers of a hero's artifacts and the mana they take off a
// spell, shared with the battle port (artifact_rules.cpp).
ArrayRef spell_affinity_records(State &state, DictRef hero_state, DictRef spell);
int64_t spell_mana_cost_delta(State &state, DictRef hero_state, DictRef spell);
bool _spell_modifier_matches(State &state, DictRef modifier, DictRef spell);

// The map's artifact nodes (overworld_state_normalize.cpp).
ArrayRef build_artifact_nodes(State &state, const Value &placements, Atom scenario_id = state::key::empty);
ArrayRef normalize_artifact_nodes(State &state, const Value &nodes, Atom scenario_id = state::key::empty);

// Phase 4's ports shared with Phase 5's battle ends (artifact_rules_shared.cpp).
Atom _already_owned_message(State &state, Atom artifact_id, DictRef location, Atom source_verb);
Atom _artifact_collection_note(State &state, DictRef hero_state, Atom artifact_id);
Atom _artifact_effect_line(State &state, Atom artifact_id);
Atom _artifact_effect_summary(State &state, DictRef artifact);
Atom _artifact_equipped_note(State &state, Atom artifact_id, Atom slot);
DictRef _artifact_source_contract(State &state, DictRef source_record);
DictRef _artifact_source_runtime_policy(State &state, DictRef table);
ArrayRef _artifact_spell_modifier_parts(State &state, const Value &value);
DictRef _draw_from_rarities(State &state, Atom source_tag, ArrayRef tiers, Atom table_id, Atom source_key, ArrayRef excluded_artifact_ids);
Atom _equipment_slot_label(State &state, Atom slot);
Atom _first_empty_compatible_slot(State &state, const Value &equipped, Atom artifact_id);
ArrayRef _matching_artifact_source_contexts(State &state, DictRef table, ArrayRef records, bool map_object_context);
bool _remove_artifact_from_inventory(State &state, ArrayRef inventory, Atom artifact_id);
Atom _resource_display_name(State &state, Atom resource_id);
DictRef _select_class_source_reward(State &state, Atom source_tag, Atom artifact_class, Atom source_key, ArrayRef excluded_artifact_ids);
Atom _signed_amount_label(State &state, int64_t amount);
Atom _source_record_guard_tier(State &state, DictRef record);
bool _source_record_has_required_categories(State &state, DictRef record, ArrayRef required_categories);
bool _source_record_has_required_tags(State &state, DictRef record, ArrayRef required_tags);
ArrayRef _source_record_reward_categories(State &state, DictRef record);
int64_t _stable_source_reward_index(State &state, Atom source_key, int64_t candidate_count);
Atom _title_label(State &state, Atom value);
Atom artifact_effect_summary(State &state, Atom artifact_id);
Atom artifact_name(State &state, Atom artifact_id);
Atom artifact_reward_role(State &state, Atom artifact_id);
Atom artifact_slot_label(State &state, Atom artifact_id);
DictRef claim_artifact(State &state, DictRef hero_state, Atom artifact_id, Atom source_verb = state::key::Recovered, bool auto_equip = true);
DictRef equip_artifact(State &state, DictRef hero_state, Atom artifact_id);
DictRef locate_artifact(State &state, DictRef hero_state, Atom artifact_id);
ArrayRef owned_artifact_ids(State &state, DictRef hero_state);
DictRef select_live_source_reward(State &state, Atom source_tag, DictRef source_record, Atom source_key, Atom faction_id, ArrayRef excluded_artifact_ids);

// Not ported yet: each throws state::NotPorted (phase4_shared_stubs.cpp) until Phase 5's
// slice 09 ports it.
DictRef _select_rarity_source_reward(State &state, Atom source_tag, Atom rarity, Atom source_key, ArrayRef excluded_artifact_ids);

} // namespace aurelion::rules::port::artifact_rules
