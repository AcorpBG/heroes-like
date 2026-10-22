#pragma once

// scripts/core/ArtifactRules.gd: the functions the computer players' day runs
// (docs/native-rules-engine-transition.md, Phase 4), ported function by
// function under the GDScript names. A session is its view (session_view.hpp).

#include "aurelion_rules/port/gd.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/artifact_rules.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"

#include <cstdint>

namespace aurelion::rules::port::artifact_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using gd::PackedRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// Ported in artifact_rules_turn.cpp.
Atom _already_owned_message(State &state, Atom artifact_id, DictRef location, Atom source_verb);
Atom _artifact_effect_line(State &state, Atom artifact_id);
Atom _artifact_effect_summary(State &state, DictRef artifact);
Atom _artifact_equipped_note(State &state, Atom artifact_id, Atom slot);
Atom _artifact_set_id(State &state, DictRef artifact);
DictRef _artifact_source_contract(State &state, DictRef source_record);
DictRef _artifact_source_runtime_policy(State &state, DictRef table);
ArrayRef _artifact_spell_modifier_parts(State &state, const Value &value);
DictRef _artifact_taxonomy_payload(State &state, DictRef artifact);
Atom _artifact_ui_summary(State &state, DictRef artifact);
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
DictRef artifact_taxonomy(State &state, Atom artifact_id);
Atom artifact_taxonomy_summary(State &state, Atom artifact_id);
DictRef claim_artifact(State &state, DictRef hero_state, Atom artifact_id, Atom source_verb = state::key::Recovered, bool auto_equip = true);
Atom describe_artifact(State &state, Atom artifact_id);
DictRef equip_artifact(State &state, DictRef hero_state, Atom artifact_id);
Atom live_source_reward_tag(State &state, DictRef source_record);
DictRef locate_artifact(State &state, DictRef hero_state, Atom artifact_id);
ArrayRef owned_artifact_ids(State &state, DictRef hero_state);
DictRef select_live_source_reward(State &state, Atom source_tag, DictRef source_record, Atom source_key, Atom faction_id, ArrayRef excluded_artifact_ids);
ArrayRef select_live_source_rewards(State &state, Atom source_tag, DictRef source_record, Atom source_key, Atom faction_id, ArrayRef excluded_artifact_ids);
Atom _artifact_collection_note(State &state, DictRef hero_state, Atom artifact_id);
Atom artifact_slot_label(State &state, Atom artifact_id);

// Not run by the six seeds: each throws state::NotPorted (turn_not_ported.cpp).
DictRef _select_rarity_source_reward(State &state, Atom source_tag, Atom rarity, Atom source_key, ArrayRef excluded_artifact_ids);
ArrayRef artifact_set_runtime_state(State &state, DictRef hero_state);
bool has_artifact(State &state, DictRef hero_state, Atom artifact_id);
DictRef remove_owned_artifact(State &state, DictRef hero_state, Atom artifact_id);

} // namespace aurelion::rules::port::artifact_rules
