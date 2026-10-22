#pragma once

// The overworld rules the battle ends call (docs/native-rules-engine-transition.md,
// Phase 5 slice 09), ported function by function under the GDScript names. A
// session is its view (session_view.hpp): the battle ends pass
// gd::object_view(state, session).

#include "aurelion_rules/port/artifact_rules.hpp"
#include "aurelion_rules/port/creature_dwelling_rules.hpp"
#include "aurelion_rules/port/enemy_adventure_rules.hpp"
#include "aurelion_rules/port/gd.hpp"
#include "aurelion_rules/port/hero_progression_rules.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/spell_rules.hpp"
#include "aurelion_rules/port/town_rules.hpp"

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
// A Phase 4 stub there (Phase 4's signature). _ai_hero_task_prune_live_tasks,
// also ported there, is declared in enemy_adventure_rules.hpp.
int64_t _ai_hero_task_retention_priority(State &state, DictRef task);
} // namespace enemy_adventure_rules

namespace town_rules {
// Ported in battle_end_towns.cpp; a Phase 4 stub there (Phase 4's signature).
DictRef teach_visiting_heroes(State &state, DictRef session, DictRef town);
} // namespace town_rules

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
// Phase 4 stubs there (Phase 4's signatures). _normalized_enemy_front_faction_id,
// _teach_visiting_town_spells and _town_occupation_seed_pressure, also ported
// there, are declared in overworld_rules.hpp.
DictRef _enemy_state_for_faction(State &state, DictRef session, Atom faction_id);
int64_t _readiness_bonus_from_profile(State &state, const Value &profile);
DictRef _retake_front_from_legacy_state(State &state, DictRef session, DictRef town, DictRef front);
bool _scenario_town_started_enemy(State &state, DictRef session, Atom placement_id);
int64_t _town_battle_readiness(State &state, DictRef town, const Value &session, DictRef metric_context, int64_t reinforcement_quality = -1);
int64_t _town_front_priority_seed(State &state, Atom role, bool objective_anchor);
DictRef _town_front_state(State &state, DictRef session, DictRef town, DictRef precomputed_development_metrics);
int64_t _town_garrison_headcount(State &state, DictRef town);
int64_t _town_garrison_strength(State &state, DictRef town);
int64_t _town_reinforcement_quality(State &state, DictRef town, const Value &session, DictRef metric_context);
int64_t _town_role_quality_bonus(State &state, Atom role);
int64_t _town_role_readiness_bonus(State &state, Atom role);
int64_t _town_spell_tier(State &state, DictRef town);
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
