#pragma once

// The human seat's hero commands (docs/native-rules-engine-transition.md,
// Phase 7, slice 7.5), ported function by function under the GDScript names:
// switching heroes, rendezvous and field exchange, army slots, town transfers,
// the garrison, the tavern hire, artifact management and the town's artifact
// services. A session is its view (session_view.hpp).

#include "aurelion_rules/port/gd.hpp"
#include "aurelion_rules/port/overworld_rules_spells.hpp"

#include <cstdint>

namespace aurelion::rules::port::overworld_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using state::State;
using state::Value;

// overworld_rules_heroes.cpp.
DictRef perform_artifact_action(State &state, DictRef session, Atom action_id);
DictRef perform_rendezvous_transfer_action(State &state, DictRef session, Atom action_id);
DictRef perform_rendezvous_action(State &state, DictRef session, Atom action_id);
DictRef _finalize_rendezvous_exchange(State &state, DictRef session, DictRef result, Atom fallback_message, ArrayRef result_keys);
ArrayRef get_artifact_actions(State &state, DictRef session);
ArrayRef get_hero_actions(State &state, DictRef session);
DictRef switch_active_hero(State &state, DictRef session, Atom hero_id);

} // namespace aurelion::rules::port::overworld_rules

namespace aurelion::rules::port::hero_command_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// hero_command_rules_army.cpp.
DictRef hero_inspection_snapshot(State &state, DictRef session, Atom hero_id);
DictRef hero_template(State &state, DictRef payload);
Atom hero_archetype_label(State &state, DictRef payload);
Atom hero_faction_label(State &state, DictRef payload, Atom fallback_faction_id = state::key::empty);
Atom hero_role_label(State &state, DictRef payload);
Atom hero_identity_context_line(State &state, DictRef payload, Atom fallback_faction_id = state::key::empty);
Atom hero_progress_context_line(State &state, DictRef hero_state);
Atom hero_readiness_context_line(State &state, DictRef hero_state, bool include_position = false);
ArrayRef get_overworld_switch_actions(State &state, DictRef session);
DictRef manage_army_slots(State &state, DictRef session, DictRef town, Atom source_holder_id, int64_t source_slot_index, Atom target_holder_id, int64_t target_slot_index, Atom amount_token = state::key::all);
Atom _hero_roster_line(State &state, DictRef hero, Atom active_hero_id);
DictRef _army_count_summary(State &state, const Value &army);
DictRef _preserve_movement_deficit_after_artifact_change(State &state, DictRef hero, int64_t previous_max, DictRef session);
bool _transfer_empties_hero_army(State &state, Atom holder_id, const Value &stacks, int64_t transfer_count, int64_t available, bool stack_leaves = true);
Atom _last_stack_message(State &state, DictRef session, DictRef town, Atom holder_id);
int64_t _stack_index_by_unit(State &state, ArrayRef stacks, Atom unit_id);
int64_t _stack_index_by_slot(State &state, ArrayRef stacks, int64_t slot_index);
int64_t _resolve_transfer_amount(State &state, Atom amount_token, int64_t available);

// hero_command_rules_field.cpp.
DictRef transfer_field_stack(State &state, DictRef session, Atom source_hero_id, Atom target_hero_id, Atom unit_id, Atom amount_token);
DictRef transfer_field_artifact(State &state, DictRef session, Atom source_hero_id, Atom target_hero_id, Atom artifact_id);
DictRef teach_field_spell(State &state, DictRef session, Atom source_hero_id, Atom target_hero_id, Atom spell_id);
Atom field_slot_action_id(State &state, Atom source_hero_id, int64_t source_slot_index, Atom target_hero_id, int64_t target_slot_index, Atom amount_token = state::key::all);
Atom field_troops_all_action_id(State &state, Atom source_hero_id, Atom target_hero_id);
Atom field_artifact_place_action_id(State &state, Atom source_hero_id, Atom target_hero_id, Atom artifact_id, Atom target_slot = state::key::empty);
Atom field_artifacts_all_action_id(State &state, Atom source_hero_id, Atom target_hero_id);
Atom field_spell_share_action_id(State &state, Atom source_hero_id, Atom target_hero_id, Atom spell_id);
DictRef field_exchange_state(State &state, DictRef session, Atom partner_hero_id = state::key::empty);
DictRef field_exchange_snapshot(State &state, DictRef session, Atom hero_id);
DictRef move_all_field_troops(State &state, DictRef session, Atom source_hero_id, Atom target_hero_id);
DictRef place_field_artifact(State &state, DictRef session, Atom source_hero_id, Atom target_hero_id, Atom artifact_id, Atom target_slot = state::key::empty);
DictRef move_all_field_artifacts(State &state, DictRef session, Atom source_hero_id, Atom target_hero_id);
DictRef _rearrange_field_artifact(State &state, DictRef session, Atom hero_id, Atom artifact_id, Atom target_slot);
void _store_field_heroes(State &state, DictRef session, ArrayRef updated_heroes);
DictRef _plan_move_all_troops(State &state, ArrayRef source_stacks, ArrayRef target_stacks, int64_t keeper_index);
int64_t _move_all_keeper_index(State &state, ArrayRef source_stacks);
Atom _field_exchange_pair_error(State &state, DictRef session, Atom source_hero_id, Atom target_hero_id);

// hero_command_rules_town.cpp: the town's hero list, tavern, transfers, hiring
// and garrison that TownRules calls.
Atom hero_profile_summary(State &state, DictRef payload, bool include_focus = false);
ArrayRef get_town_switch_actions(State &state, DictRef session, DictRef town);
DictRef town_visiting_hero(State &state, DictRef session, DictRef town);
DictRef set_town_garrison_hero(State &state, DictRef session, DictRef town, Atom hero_id);
DictRef _live_town(State &state, DictRef session, DictRef town);
void _write_town_garrison_hero(State &state, DictRef session, DictRef town, Atom hero_id);
ArrayRef get_tavern_actions(State &state, DictRef session, DictRef town);
DictRef recruit_hero_at_town(State &state, DictRef session, DictRef town, Atom hero_id);
ArrayRef get_town_transfer_actions(State &state, DictRef session, DictRef town);
DictRef transfer_town_stack(State &state, DictRef session, DictRef town, Atom source_holder, Atom target_holder, Atom unit_id, Atom amount_token);
Atom _army_summary(State &state, const Value &army);
ArrayRef _transfer_amount_tokens(State &state, int64_t count);
Atom _transfer_amount_label(State &state, Atom amount_token, int64_t available);
bool _can_afford(State &state, DictRef session, const Value &cost);
void _spend_resources(State &state, DictRef session, const Value &cost);
Atom _describe_resources(State &state, const Value &resources);
Atom _stack_summary_from_array(State &state, const Value &stacks);

} // namespace aurelion::rules::port::hero_command_rules

namespace aurelion::rules::port::hero_progression_rules {

using gd::Atom;
using state::State;
using state::Value;

// hero_command_rules_town.cpp.
Atom summarize_specialty_ids(State &state, const Value &specialty_ids, bool use_short_names = true);

} // namespace aurelion::rules::port::hero_progression_rules

namespace aurelion::rules::port::artifact_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// artifact_rules_management.cpp.
DictRef perform_management_action(State &state, DictRef hero_state, Atom action_id);
bool equipment_slot_accepts(State &state, Atom slot, Atom artifact_id);
DictRef equip_artifact_in_slot(State &state, DictRef hero_state, Atom artifact_id, Atom slot);
DictRef unequip_artifact(State &state, DictRef hero_state, Atom slot);
ArrayRef get_management_actions(State &state, DictRef hero_state);
Atom artifact_id_for_management_action(State &state, DictRef hero_state, Atom action_id);
Atom artifact_set_context(State &state, Atom artifact_id);
Atom artifact_decision_summary(State &state, DictRef hero_state, Atom artifact_id);

} // namespace aurelion::rules::port::artifact_rules

namespace aurelion::rules::port::town_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// town_rules_heroes.cpp.
bool _read_cache_has(State &state, DictRef session, Atom key);
Value _read_cache_get(State &state, DictRef session, Atom key);
void _read_cache_store(State &state, DictRef session, Atom key, const Value &value);
DictRef get_active_town(State &state, DictRef session);
ArrayRef get_hero_actions(State &state, DictRef session);
ArrayRef get_tavern_actions(State &state, DictRef session);
ArrayRef get_transfer_actions(State &state, DictRef session);
ArrayRef get_artifact_actions(State &state, DictRef session);
DictRef switch_active_hero_at_town(State &state, DictRef session, Atom hero_id);
DictRef hire_hero_at_active_town(State &state, DictRef session, Atom hero_id);
DictRef transfer_in_active_town(State &state, DictRef session, Atom action_id);
DictRef manage_army_slots_in_active_town(State &state, DictRef session, Atom source_holder_id, int64_t source_slot_index, Atom target_holder_id, int64_t target_slot_index, Atom amount_token = state::key::all);
DictRef set_garrison_hero_in_active_town(State &state, DictRef session, Atom hero_id);
DictRef manage_artifact_at_active_town(State &state, DictRef session, Atom action_id);
ArrayRef _town_artifact_service_actions(State &state, DictRef session, DictRef town);
DictRef _commission_town_artifact(State &state, DictRef session, Atom building_id);
DictRef _find_active_town_result(State &state, DictRef session);
bool _can_afford(State &state, DictRef session, const Value &cost);
Atom _resource_shortfall(State &state, DictRef session, const Value &cost);
void _spend_resources(State &state, DictRef session, DictRef cost);
Atom _describe_resources(State &state, const Value &resources, Atom empty_label = state::key::none);
ArrayRef _resource_keys_for_payload(State &state, const Value &value);
DictRef _finalize_town_result(State &state, DictRef session, bool ok, Atom base_message);

} // namespace aurelion::rules::port::town_rules
