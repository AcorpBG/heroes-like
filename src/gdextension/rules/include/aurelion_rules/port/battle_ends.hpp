#pragma once

// The overworld rules the battle ends call (docs/native-rules-engine-transition.md,
// Phase 5 slice 09), ported function by function under the GDScript names. A
// session is its view (session_view.hpp): the battle ends pass
// gd::object_view(state, session).

#include "aurelion_rules/port/gd.hpp"
#include "aurelion_rules/port/session_view.hpp"

#include <cstdint>

namespace aurelion::rules::port {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using state::State;
using state::Value;

namespace creature_dwelling_rules {
// Ported in battle_end_sites.cpp.
Atom placement_from_guard_key(State &state, Atom key);
} // namespace creature_dwelling_rules

namespace difficulty_rules {
// Ported in battle_end_sites.cpp.
DictRef scale_reward_resources(State &state, DictRef session, const Value &payload);
} // namespace difficulty_rules

namespace player_elimination_rules {
// Ported in battle_end_heroes.cpp.
bool human_has_nothing_left(State &state, DictRef session);
// Ported in player_elimination.cpp, which declares it in no header.
bool applies(State &state, DictRef session);
} // namespace player_elimination_rules

namespace hero_command_rules {
// Ported in battle_end_heroes.cpp.
bool active_hero_is_primary(State &state, DictRef session);
void hand_over_primary(State &state, DictRef session, Atom fallen_id);
bool keep_hero_troop_from_garrison(State &state, DictRef session, DictRef town, Atom hero_id);
DictRef remove_active_hero_after_defeat(State &state, DictRef session);
// A Phase 4 stub there (Phase 4's signature).
void _set_holder_stacks(State &state, DictRef session, DictRef town, Atom holder_id, ArrayRef stacks);
} // namespace hero_command_rules

namespace enemy_adventure_rules {
// Ported in battle_end_heroes.cpp.
Atom apply_resolved_commander_aftermath(State &state, DictRef session, Atom faction_id, const Value &commander_state, Atom outcome_id);
int64_t commander_renown(State &state, const Value &source);
DictRef record_rivalry(State &state, DictRef commander_state, Atom rival_kind, Atom rival_id, Atom rival_label);
DictRef record_target_assignment(State &state, DictRef commander_state, Atom target_kind, Atom target_id, Atom target_label, int64_t target_x = 0, int64_t target_y = 0);
// Ported in enemy_states.cpp, where _active_commander_map needs it; a Phase 4
// stub there (Phase 4's signature).
DictRef _active_town_defender_entry(State &state, DictRef session, DictRef town, Atom faction_filter = state::key::empty);
// Ported in enemy_states.cpp, which declares them in no header.
DictRef sync_commander_army_continuity(State &state, DictRef commander_state, const Value &army_source, Atom encounter_id);
int64_t _army_strength(State &state, const Value &stacks);
// Phase 4 stubs there (Phase 4's signatures).
ArrayRef _ai_hero_task_prune_live_tasks(State &state, ArrayRef tasks, int64_t day);
int64_t _ai_hero_task_retention_priority(State &state, DictRef task);
} // namespace enemy_adventure_rules

namespace town_rules {
// Ported in battle_end_towns.cpp; a Phase 4 stub there (Phase 4's signature).
DictRef teach_visiting_heroes(State &state, DictRef session, DictRef town);
} // namespace town_rules

namespace artifact_rules {
// Ported in battle_end_heroes.cpp; a Phase 4 stub there (Phase 4's signature).
DictRef _select_rarity_source_reward(State &state, Atom source_tag, Atom rarity, Atom source_key, ArrayRef excluded_artifact_ids);
} // namespace artifact_rules

namespace overworld_rules {
// Ported in battle_end_sites.cpp: sites, their guards and defenders, rewards
// and reserve deliveries.
DictRef _apply_artifact_claim(State &state, DictRef session, Atom artifact_id, Atom source_verb, bool auto_equip);
int64_t _army_strength_value(State &state, const Value &stacks);
DictRef _clear_resource_ai_defender_metadata(State &state, DictRef node);
bool _deliver_reinforcements_to_hero(State &state, DictRef session, Atom hero_id, DictRef manifest);
bool _deliver_reinforcements_to_town(State &state, DictRef session, Atom town_placement_id, DictRef manifest);
Atom _describe_reward_delta(State &state, const Value &delta);
DictRef _find_resource_node_by_placement(State &state, DictRef session, Atom placement_id);
// _movement_max_from_hero(hero, session = null): a null session is Nil.
int64_t _movement_max_from_hero(State &state, DictRef hero, const Value &session);
void _record_successful_reserve_delivery(State &state, DictRef node, DictRef delivery_state, int64_t delivery_day);
Atom _resolve_player_reserve_delivery(State &state, DictRef session, DictRef site, DictRef delivery_state, DictRef node);
Atom _return_reinforcements_to_source(State &state, DictRef session, Atom source_town_id, DictRef manifest);
void _spend_resources(State &state, DictRef session, const Value &cost);
DictRef _split_recruit_payload(State &state, DictRef manifest, double return_ratio);
DictRef _stacks_to_recruits(State &state, ArrayRef stacks);
void _sync_movement_to_hero(State &state, DictRef session, int64_t previous_max);
DictRef apply_delivery_interception_outcome(State &state, DictRef session, Atom node_placement_id, Atom outcome);
DictRef apply_reward_bonus(State &state, const Value &rewards, int64_t pct);
Atom capture_dwelling_after_guard_victory(State &state, DictRef session, Atom placement_id);
DictRef capture_resource_after_defender_victory(State &state, DictRef session, Atom placement_id);
Atom update_dwelling_guard_after_battle(State &state, DictRef session, Atom placement_id, ArrayRef survivor_stacks, bool won);
Atom update_resource_defender_after_battle(State &state, DictRef session, Atom placement_id, Atom faction_id, DictRef commander_state, ArrayRef survivor_stacks, bool resolved);

// Ported in battle_end_towns.cpp: a town taken after a battle and its front.
// town_front_state(session, town, precomputed_development_metrics = {}).
DictRef town_front_state(State &state, DictRef session, DictRef town, DictRef precomputed_development_metrics);
Atom _claim_town(State &state, DictRef session, DictRef town_result);
Atom capture_town_by_placement(State &state, DictRef session, Atom placement_id);
DictRef stabilize_town_front(State &state, DictRef session, Atom placement_id, Atom faction_id, Atom source = state::key::empty, int64_t bonus_days = 0);
// Phase 4 stubs there (Phase 4's signatures).
DictRef _enemy_state_for_faction(State &state, DictRef session, Atom faction_id);
Atom _normalized_enemy_front_faction_id(State &state, DictRef session, DictRef front, DictRef town);
int64_t _readiness_bonus_from_profile(State &state, const Value &profile);
DictRef _retake_front_from_legacy_state(State &state, DictRef session, DictRef town, DictRef front);
bool _scenario_town_started_enemy(State &state, DictRef session, Atom placement_id);
void _teach_visiting_town_spells(State &state, DictRef session, DictRef town);
int64_t _town_battle_readiness(State &state, DictRef town, const Value &session, DictRef metric_context, int64_t reinforcement_quality = -1);
int64_t _town_front_priority_seed(State &state, Atom role, bool objective_anchor);
DictRef _town_front_state(State &state, DictRef session, DictRef town, DictRef precomputed_development_metrics);
int64_t _town_garrison_headcount(State &state, DictRef town);
int64_t _town_garrison_strength(State &state, DictRef town);
int64_t _town_occupation_seed_pressure(State &state, DictRef session, DictRef town);
int64_t _town_reinforcement_quality(State &state, DictRef town, const Value &session, DictRef metric_context);
int64_t _town_role_quality_bonus(State &state, Atom role);
int64_t _town_role_readiness_bonus(State &state, Atom role);
int64_t _town_spell_tier(State &state, DictRef town);
} // namespace overworld_rules

// Phase 4's ports (branch native-phase4-faction-turn), under its signatures;
// defined there. GDScript defaults missing here are passed by the callers.
namespace artifact_rules {
ArrayRef owned_artifact_ids(State &state, DictRef hero_state);
DictRef select_live_source_reward(State &state, Atom source_tag, DictRef source_record, Atom source_key, Atom faction_id, ArrayRef excluded_artifact_ids);
DictRef _draw_from_rarities(State &state, Atom source_tag, ArrayRef tiers, Atom table_id, Atom source_key, ArrayRef excluded_artifact_ids);
// claim_artifact(hero_state, artifact_id, source_verb = "Recovered", auto_equip = true).
DictRef claim_artifact(State &state, DictRef hero_state, Atom artifact_id, Atom source_verb, bool auto_equip);
} // namespace artifact_rules

namespace town_rules {
ArrayRef accessible_spell_ids(State &state, DictRef town);
} // namespace town_rules

namespace spell_rules {
DictRef learn_spell(State &state, DictRef hero_state, Atom spell_id);
} // namespace spell_rules

namespace creature_dwelling_rules {
void record_guard_result(State &state, DictRef node, Atom side, ArrayRef survivor_stacks, bool won, int64_t day);
} // namespace creature_dwelling_rules

namespace enemy_adventure_rules {
void _ai_hero_task_finish_live_assignment(State &state, DictRef session, Atom faction_id, DictRef raid, Atom task_status, Atom validation);
DictRef advance_commander_record(State &state, DictRef commander_state, Atom outcome_id);
Atom commander_display_name(State &state, const Value &source, bool include_veterancy = true);
DictRef commander_live_role_state(State &state, const Value &source);
DictRef commander_target_memory(State &state, const Value &source);
void sync_commander_state_to_roster(State &state, DictRef session, Atom faction_id, const Value &commander_state, Atom status_override = state::key::empty, Atom active_placement_id = state::key::empty, int64_t recovery_day = -1, Atom last_outcome = state::key::empty);
} // namespace enemy_adventure_rules

namespace hero_progression_rules {
DictRef add_experience(State &state, DictRef hero_state, int64_t amount);
int64_t experience_with_bonus(State &state, DictRef hero_state, int64_t amount);
} // namespace hero_progression_rules

namespace overworld_rules {
Atom apply_town_recovery_pressure(State &state, DictRef session, Atom town_placement_id, int64_t amount, Atom source = state::key::empty);
void invalidate_spatial_lookup(State &state, DictRef session);
DictRef transition_town_control(State &state, DictRef session, Atom placement_id, Atom new_owner, Atom controlling_faction_id = state::key::empty, Atom source = state::key::empty);
// _town_front_stabilizing_state(session, town, faction_id, source,
// previous_owner = "", bonus_days = 0).
DictRef _town_front_stabilizing_state(State &state, DictRef session, DictRef town, Atom faction_id, Atom source, Atom previous_owner, int64_t bonus_days);
DictRef _town_weekly_growth(State &state, DictRef town, const Value &session, DictRef metric_context);
bool _town_is_objective_anchor(State &state, DictRef session, Atom placement_id);
int64_t _rules_profile_timer(State &state);
void _rules_profile_add_ms(State &state, Atom bucket, int64_t started_usec);
void _rules_profile_set(State &state, Atom section, Atom key, const Value &value);
} // namespace overworld_rules

// Phase 4's stubs (NotPorted there), under its signatures: a human game's rival
// count reaches them. Ported in scenario_evaluation.cpp.
namespace player_identity_rules {
Atom defender_controller_id(State &state, DictRef record);
ArrayRef from_slots(State &state, ArrayRef slots);
} // namespace player_identity_rules

namespace enemy_adventure_rules {
bool is_active_pressure_host(State &state, const Value &encounter, Atom faction_id, const Value &resolved_encounters);
DictRef _active_resource_defender_entry(State &state, DictRef session, DictRef node, Atom faction_filter = state::key::empty);
} // namespace enemy_adventure_rules

} // namespace aurelion::rules::port
