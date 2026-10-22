// The functions of the computer players' day that the six seeds do not run
// (docs/native-rules-engine-transition.md, Phase 4, slice 4.2 ports them): each
// throws state::NotPorted, so the day runs in GDScript where no host call came first.

#include "aurelion_rules/port/ai_hero_rules_turn.hpp"
#include "aurelion_rules/port/artifact_rules_turn.hpp"
#include "aurelion_rules/port/difficulty_rules_turn.hpp"
#include "aurelion_rules/port/enemy_adventure_rules_turn.hpp"
#include "aurelion_rules/port/enemy_town_services_turn.hpp"
#include "aurelion_rules/port/enemy_turn_rules_turn.hpp"
#include "aurelion_rules/port/hero_command_rules_turn.hpp"
#include "aurelion_rules/port/native_transit_rules_turn.hpp"
#include "aurelion_rules/port/overworld_level_rules_turn.hpp"
#include "aurelion_rules/port/overworld_rules_turn.hpp"
#include "aurelion_rules/port/overworld_turn_playback_turn.hpp"
#include "aurelion_rules/port/player_identity_rules_turn.hpp"
#include "aurelion_rules/port/scenario_factory_turn.hpp"
#include "aurelion_rules/port/scenario_rules_turn.hpp"
#include "aurelion_rules/port/scenario_script_rules_turn.hpp"
#include "aurelion_rules/port/spell_rules_turn.hpp"
#include "aurelion_rules/port/town_development_rules_turn.hpp"
#include "aurelion_rules/port/town_rules_turn.hpp"
#include "aurelion_rules/port/visit_building_rules_turn.hpp"

namespace aurelion::rules::port {

namespace ai_hero_rules {

DictRef _attack_player_hero(State &state, DictRef session, DictRef context, int64_t index, DictRef plan) {
	(void)session; (void)context; (void)index; (void)plan; (void)state;
	throw state::NotPorted("AiHeroRules._attack_player_hero");
}

DictRef _convert_legacy_host(State &state, DictRef session, DictRef entry, Atom controller) {
	(void)session; (void)entry; (void)controller; (void)state;
	throw state::NotPorted("AiHeroRules._convert_legacy_host");
}

int64_t _nearest_hero_index(State &state, ArrayRef encounters, DictRef resolved, Atom controller, DictRef column, int64_t radius) {
	(void)encounters; (void)resolved; (void)controller; (void)column; (void)radius; (void)state;
	throw state::NotPorted("AiHeroRules._nearest_hero_index");
}

void _return_troops_to_nearest_town(State &state, DictRef session, DictRef entry, Atom controller) {
	(void)session; (void)entry; (void)controller; (void)state;
	throw state::NotPorted("AiHeroRules._return_troops_to_nearest_town");
}

double _upgrade_value(State &state, DictRef town, DictRef building) {
	(void)town; (void)building; (void)state;
	throw state::NotPorted("AiHeroRules._upgrade_value");
}

} // namespace ai_hero_rules

namespace artifact_rules {

DictRef _select_rarity_source_reward(State &state, Atom source_tag, Atom rarity, Atom source_key, ArrayRef excluded_artifact_ids) {
	(void)source_tag; (void)rarity; (void)source_key; (void)excluded_artifact_ids; (void)state;
	throw state::NotPorted("ArtifactRules._select_rarity_source_reward");
}

ArrayRef artifact_set_runtime_state(State &state, DictRef hero_state) {
	(void)hero_state; (void)state;
	throw state::NotPorted("ArtifactRules.artifact_set_runtime_state");
}

bool has_artifact(State &state, DictRef hero_state, Atom artifact_id) {
	(void)hero_state; (void)artifact_id; (void)state;
	throw state::NotPorted("ArtifactRules.has_artifact");
}

DictRef remove_owned_artifact(State &state, DictRef hero_state, Atom artifact_id) {
	(void)hero_state; (void)artifact_id; (void)state;
	throw state::NotPorted("ArtifactRules.remove_owned_artifact");
}

} // namespace artifact_rules

namespace difficulty_rules {

int64_t adjust_enemy_pressure_gain(State &state, DictRef session, int64_t base_gain) {
	(void)session; (void)base_gain; (void)state;
	throw state::NotPorted("DifficultyRules.adjust_enemy_pressure_gain");
}

int64_t adjust_raid_threshold(State &state, DictRef session, int64_t base_threshold) {
	(void)session; (void)base_threshold; (void)state;
	throw state::NotPorted("DifficultyRules.adjust_raid_threshold");
}

} // namespace difficulty_rules

namespace enemy_adventure_rules {

DictRef _active_resource_defender_entry(State &state, DictRef session, DictRef node, Atom faction_filter) {
	(void)session; (void)node; (void)faction_filter; (void)state;
	throw state::NotPorted("EnemyAdventureRules._active_resource_defender_entry");
}

DictRef _active_town_defender_entry(State &state, DictRef session, DictRef town, Atom faction_filter) {
	(void)session; (void)town; (void)faction_filter; (void)state;
	throw state::NotPorted("EnemyAdventureRules._active_town_defender_entry");
}

ArrayRef _ai_hero_task_prune_live_tasks(State &state, ArrayRef tasks, int64_t day) {
	(void)tasks; (void)day; (void)state;
	throw state::NotPorted("EnemyAdventureRules._ai_hero_task_prune_live_tasks");
}

int64_t _ai_hero_task_retention_priority(State &state, DictRef task) {
	(void)task; (void)state;
	throw state::NotPorted("EnemyAdventureRules._ai_hero_task_retention_priority");
}

DictRef _clear_regroup_target(State &state, DictRef raid) {
	(void)raid; (void)state;
	throw state::NotPorted("EnemyAdventureRules._clear_regroup_target");
}

void _clear_resource_defender_metadata(State &state, DictRef node) {
	(void)node; (void)state;
	throw state::NotPorted("EnemyAdventureRules._clear_resource_defender_metadata");
}

void _clear_town_defender_metadata(State &state, DictRef town) {
	(void)town; (void)state;
	throw state::NotPorted("EnemyAdventureRules._clear_town_defender_metadata");
}

ArrayRef _current_enemy_player_hero_sighting_records(State &state, DictRef session, DictRef config, Atom faction_id, const Value &preloaded_sources, const Value &projection_profile) {
	(void)session; (void)config; (void)faction_id; (void)preloaded_sources; (void)projection_profile; (void)state;
	throw state::NotPorted("EnemyAdventureRules._current_enemy_player_hero_sighting_records");
}

DictRef _default_enemy_strategy(State &state) {
	(void)state;
	throw state::NotPorted("EnemyAdventureRules._default_enemy_strategy");
}

ArrayRef _default_reason_codes_for_target(State &state, Atom target_kind, Atom target_id, DictRef target) {
	(void)target_kind; (void)target_id; (void)target; (void)state;
	throw state::NotPorted("EnemyAdventureRules._default_reason_codes_for_target");
}

int64_t _dwelling_guard_strength(State &state, DictRef session, DictRef node, DictRef site, Atom faction_id) {
	(void)session; (void)node; (void)site; (void)faction_id; (void)state;
	throw state::NotPorted("EnemyAdventureRules._dwelling_guard_strength");
}

bool _encounter_is_objective_anchor(State &state, DictRef session, DictRef encounter) {
	(void)session; (void)encounter; (void)state;
	throw state::NotPorted("EnemyAdventureRules._encounter_is_objective_anchor");
}

ArrayRef _enemy_hero_sighting_sources(State &state, DictRef session, DictRef config, Atom faction_id) {
	(void)session; (void)config; (void)faction_id; (void)state;
	throw state::NotPorted("EnemyAdventureRules._enemy_hero_sighting_sources");
}

DictRef _enemy_player_hero_sighting_record(State &state, DictRef session, Atom faction_id, Atom hero_id) {
	(void)session; (void)faction_id; (void)hero_id; (void)state;
	throw state::NotPorted("EnemyAdventureRules._enemy_player_hero_sighting_record");
}

int64_t _exploration_target_level(State &state, Atom target_id) {
	(void)target_id; (void)state;
	throw state::NotPorted("EnemyAdventureRules._exploration_target_level");
}

DictRef _find_encounter_by_placement(State &state, DictRef session, Atom placement_id) {
	(void)session; (void)placement_id; (void)state;
	throw state::NotPorted("EnemyAdventureRules._find_encounter_by_placement");
}

DictRef _find_player_hero(State &state, DictRef session, Atom hero_id) {
	(void)session; (void)hero_id; (void)state;
	throw state::NotPorted("EnemyAdventureRules._find_player_hero");
}

DictRef _find_town_by_placement(State &state, DictRef session, Atom placement_id) {
	(void)session; (void)placement_id; (void)state;
	throw state::NotPorted("EnemyAdventureRules._find_town_by_placement");
}

DictRef _known_player_hero_snapshot_for_ai(State &state, DictRef session, Atom faction_id, DictRef hero) {
	(void)session; (void)faction_id; (void)hero; (void)state;
	throw state::NotPorted("EnemyAdventureRules._known_player_hero_snapshot_for_ai");
}

int64_t _known_player_hero_strength(State &state, DictRef hero) {
	(void)hero; (void)state;
	throw state::NotPorted("EnemyAdventureRules._known_player_hero_strength");
}

DictRef _merge_strategy_dict(State &state, DictRef base, DictRef override) {
	(void)base; (void)override; (void)state;
	throw state::NotPorted("EnemyAdventureRules._merge_strategy_dict");
}

Vector2i _player_hero_goal_tile(State &state, DictRef hero) {
	(void)hero; (void)state;
	throw state::NotPorted("EnemyAdventureRules._player_hero_goal_tile");
}

ArrayRef _player_hero_snapshots_for_intercept(State &state, DictRef session, bool read_only) {
	(void)session; (void)read_only; (void)state;
	throw state::NotPorted("EnemyAdventureRules._player_hero_snapshots_for_intercept");
}

int64_t _preferred_commander_index_for_encounter(State &state, DictRef encounter) {
	(void)encounter; (void)state;
	throw state::NotPorted("EnemyAdventureRules._preferred_commander_index_for_encounter");
}

DictRef _secure_native_passage_target(State &state, DictRef session, DictRef raid, DictRef state_, Atom faction_id, DictRef node, bool preserve_target) {
	(void)session; (void)raid; (void)state_; (void)faction_id; (void)node; (void)preserve_target; (void)state;
	throw state::NotPorted("EnemyAdventureRules._secure_native_passage_target");
}

Atom _town_controller_faction_id(State &state, DictRef town_state) {
	(void)town_state; (void)state;
	throw state::NotPorted("EnemyAdventureRules._town_controller_faction_id");
}

bool _town_is_objective_anchor(State &state, DictRef session, Atom placement_id) {
	(void)session; (void)placement_id; (void)state;
	throw state::NotPorted("EnemyAdventureRules._town_is_objective_anchor");
}

bool commander_can_deploy(State &state, const Value &source) {
	(void)source; (void)state;
	throw state::NotPorted("EnemyAdventureRules.commander_can_deploy");
}

Atom commander_recent_outcome_brief(State &state, const Value &source) {
	(void)source; (void)state;
	throw state::NotPorted("EnemyAdventureRules.commander_recent_outcome_brief");
}

DictRef enemy_strategy(State &state, DictRef config, Atom faction_id) {
	(void)config; (void)faction_id; (void)state;
	throw state::NotPorted("EnemyAdventureRules.enemy_strategy");
}

bool is_active_pressure_host(State &state, const Value &encounter, Atom faction_id, const Value &resolved_encounters) {
	(void)encounter; (void)faction_id; (void)resolved_encounters; (void)state;
	throw state::NotPorted("EnemyAdventureRules.is_active_pressure_host");
}

DictRef occupied_raid_commander_ids(State &state, DictRef session, Atom faction_id, Atom exclude_placement_id) {
	(void)session; (void)faction_id; (void)exclude_placement_id; (void)state;
	throw state::NotPorted("EnemyAdventureRules.occupied_raid_commander_ids");
}

Atom raid_display_name(State &state, DictRef encounter) {
	(void)encounter; (void)state;
	throw state::NotPorted("EnemyAdventureRules.raid_display_name");
}

int64_t raid_strength(State &state, DictRef encounter) {
	(void)encounter; (void)state;
	throw state::NotPorted("EnemyAdventureRules.raid_strength");
}

Atom select_raid_commander_roster_hero_id(State &state, DictRef session, Atom faction_id, int64_t preferred_index, DictRef occupied_commander_ids, const Value &commander_roster) {
	(void)session; (void)faction_id; (void)preferred_index; (void)occupied_commander_ids; (void)commander_roster; (void)state;
	throw state::NotPorted("EnemyAdventureRules.select_raid_commander_roster_hero_id");
}

int64_t strategy_int(State &state, DictRef strategy, Atom section, Atom key, int64_t default_value) {
	(void)strategy; (void)section; (void)key; (void)default_value; (void)state;
	throw state::NotPorted("EnemyAdventureRules.strategy_int");
}

double strategy_scalar(State &state, DictRef strategy, Atom section, Atom key, double default_value) {
	(void)strategy; (void)section; (void)key; (void)default_value; (void)state;
	throw state::NotPorted("EnemyAdventureRules.strategy_scalar");
}

bool target_is_objective_anchor(State &state, DictRef session, Atom target_kind, Atom placement_id) {
	(void)session; (void)target_kind; (void)placement_id; (void)state;
	throw state::NotPorted("EnemyAdventureRules.target_is_objective_anchor");
}

} // namespace enemy_adventure_rules

namespace enemy_town_services {

DictRef best_equipment(State &state, DictRef hero, Atom artifact_id) {
	(void)hero; (void)artifact_id; (void)state;
	throw state::NotPorted("EnemyTownServices.best_equipment");
}

double loadout_value(State &state, DictRef hero) {
	(void)hero; (void)state;
	throw state::NotPorted("EnemyTownServices.loadout_value");
}

} // namespace enemy_town_services

namespace enemy_turn_rules {

void _append_building_with_requirements(State &state, ArrayRef target, Atom building_id, ArrayRef trail) {
	(void)target; (void)building_id; (void)trail; (void)state;
	throw state::NotPorted("EnemyTurnRules._append_building_with_requirements");
}

bool _config_was_runtime_defaulted(State &state, DictRef source, DictRef normalized) {
	(void)source; (void)normalized; (void)state;
	throw state::NotPorted("EnemyTurnRules._config_was_runtime_defaulted");
}

DictRef _faction_capital_state(State &state, DictRef session, Atom faction_id) {
	(void)session; (void)faction_id; (void)state;
	throw state::NotPorted("EnemyTurnRules._faction_capital_state");
}

DictRef _faction_capital_state_from_towns(State &state, DictRef session, ArrayRef towns, Atom faction_id) {
	(void)session; (void)towns; (void)faction_id; (void)state;
	throw state::NotPorted("EnemyTurnRules._faction_capital_state_from_towns");
}

DictRef _faction_front_state(State &state, DictRef session, Atom faction_id) {
	(void)session; (void)faction_id; (void)state;
	throw state::NotPorted("EnemyTurnRules._faction_front_state");
}

int64_t _hero_task_record_sanitized_field_count(State &state, DictRef task) {
	(void)task; (void)state;
	throw state::NotPorted("EnemyTurnRules._hero_task_record_sanitized_field_count");
}

int64_t _hero_task_state_board_sanitized_field_count(State &state, DictRef board) {
	(void)board; (void)state;
	throw state::NotPorted("EnemyTurnRules._hero_task_state_board_sanitized_field_count");
}

DictRef _launch_policy_capital_state(State &state, DictRef session, Atom faction_id, DictRef launch_policy_context) {
	(void)session; (void)faction_id; (void)launch_policy_context; (void)state;
	throw state::NotPorted("EnemyTurnRules._launch_policy_capital_state");
}

DictRef _launch_policy_front_state(State &state, DictRef session, Atom faction_id, DictRef launch_policy_context) {
	(void)session; (void)faction_id; (void)launch_policy_context; (void)state;
	throw state::NotPorted("EnemyTurnRules._launch_policy_front_state");
}

int64_t _max_active_raids_for_strategy(State &state, DictRef session, DictRef config, Atom faction_id, DictRef launch_policy_context) {
	(void)session; (void)config; (void)faction_id; (void)launch_policy_context; (void)state;
	throw state::NotPorted("EnemyTurnRules._max_active_raids_for_strategy");
}

Atom _normalize_hero_task_actor_kind(State &state, const Value &value) {
	(void)value; (void)state;
	throw state::NotPorted("EnemyTurnRules._normalize_hero_task_actor_kind");
}

Atom _normalize_hero_task_class(State &state, const Value &value) {
	(void)value; (void)state;
	throw state::NotPorted("EnemyTurnRules._normalize_hero_task_class");
}

Atom _normalize_hero_task_continuity_policy(State &state, const Value &value) {
	(void)value; (void)state;
	throw state::NotPorted("EnemyTurnRules._normalize_hero_task_continuity_policy");
}

Atom _normalize_hero_task_origin_kind(State &state, const Value &value) {
	(void)value; (void)state;
	throw state::NotPorted("EnemyTurnRules._normalize_hero_task_origin_kind");
}

DictRef _normalize_hero_task_record(State &state, const Value &value) {
	(void)value; (void)state;
	throw state::NotPorted("EnemyTurnRules._normalize_hero_task_record");
}

DictRef _normalize_hero_task_reservation(State &state, const Value &value) {
	(void)value; (void)state;
	throw state::NotPorted("EnemyTurnRules._normalize_hero_task_reservation");
}

Atom _normalize_hero_task_route_policy(State &state, const Value &value) {
	(void)value; (void)state;
	throw state::NotPorted("EnemyTurnRules._normalize_hero_task_route_policy");
}

Atom _normalize_hero_task_source_kind(State &state, const Value &value) {
	(void)value; (void)state;
	throw state::NotPorted("EnemyTurnRules._normalize_hero_task_source_kind");
}

Atom _normalize_hero_task_status(State &state, const Value &value) {
	(void)value; (void)state;
	throw state::NotPorted("EnemyTurnRules._normalize_hero_task_status");
}

Atom _normalize_hero_task_target_kind(State &state, const Value &value) {
	(void)value; (void)state;
	throw state::NotPorted("EnemyTurnRules._normalize_hero_task_target_kind");
}

Atom _normalize_hero_task_validation_code(State &state, const Value &value) {
	(void)value; (void)state;
	throw state::NotPorted("EnemyTurnRules._normalize_hero_task_validation_code");
}

int64_t _raid_threshold_for_strategy(State &state, DictRef session, DictRef config, Atom faction_id, DictRef launch_policy_context) {
	(void)session; (void)config; (void)faction_id; (void)launch_policy_context; (void)state;
	throw state::NotPorted("EnemyTurnRules._raid_threshold_for_strategy");
}

ArrayRef _valid_enemy_faction_configs(State &state, ArrayRef configs) {
	(void)configs; (void)state;
	throw state::NotPorted("EnemyTurnRules._valid_enemy_faction_configs");
}

int64_t active_raid_count(State &state, DictRef session, Atom faction_id) {
	(void)session; (void)faction_id; (void)state;
	throw state::NotPorted("EnemyTurnRules.active_raid_count");
}

int64_t get_pressure(State &state, DictRef session, Atom faction_id) {
	(void)session; (void)faction_id; (void)state;
	throw state::NotPorted("EnemyTurnRules.get_pressure");
}

DictRef normalize_optional_hero_task_state(State &state, const Value &value) {
	(void)value; (void)state;
	throw state::NotPorted("EnemyTurnRules.normalize_optional_hero_task_state");
}

} // namespace enemy_turn_rules

namespace hero_command_rules {

ArrayRef _holder_stacks(State &state, DictRef session, DictRef town, Atom holder_id) {
	(void)session; (void)town; (void)holder_id; (void)state;
	throw state::NotPorted("HeroCommandRules._holder_stacks");
}

void _set_holder_stacks(State &state, DictRef session, DictRef town, Atom holder_id, ArrayRef stacks) {
	(void)session; (void)town; (void)holder_id; (void)stacks; (void)state;
	throw state::NotPorted("HeroCommandRules._set_holder_stacks");
}

ArrayRef merge_stacks_into_army(State &state, ArrayRef army, ArrayRef incoming) {
	(void)army; (void)incoming; (void)state;
	throw state::NotPorted("HeroCommandRules.merge_stacks_into_army");
}

DictRef set_active_hero(State &state, DictRef session, Atom hero_id) {
	(void)session; (void)hero_id; (void)state;
	throw state::NotPorted("HeroCommandRules.set_active_hero");
}

} // namespace hero_command_rules

namespace native_transit_rules {

} // namespace native_transit_rules

namespace overworld_level_rules {

int64_t view_level(State &state, const Value &session) {
	(void)session; (void)state;
	throw state::NotPorted("OverworldLevelRules.view_level");
}

} // namespace overworld_level_rules

namespace overworld_rules {

ArrayRef _build_scenario_resource_states(State &state, const Value &placements) {
	(void)placements; (void)state;
	throw state::NotPorted("OverworldRules._build_scenario_resource_states");
}

ArrayRef _build_scenario_town_states(State &state, const Value &placements) {
	(void)placements; (void)state;
	throw state::NotPorted("OverworldRules._build_scenario_town_states");
}

DictRef _command_risk_encounter_objective_item(State &state, DictRef session, DictRef objective, bool include_details) {
	(void)session; (void)objective; (void)include_details; (void)state;
	throw state::NotPorted("OverworldRules._command_risk_encounter_objective_item");
}

DictRef _command_risk_pressure_objective_item(State &state, DictRef session, DictRef scenario, DictRef objective, bool include_details) {
	(void)session; (void)scenario; (void)objective; (void)include_details; (void)state;
	throw state::NotPorted("OverworldRules._command_risk_pressure_objective_item");
}

bool _delivery_encounter_matches_node(State &state, DictRef session, DictRef encounter, DictRef node, DictRef delivery_state) {
	(void)session; (void)encounter; (void)node; (void)delivery_state; (void)state;
	throw state::NotPorted("OverworldRules._delivery_encounter_matches_node");
}

int64_t _enemy_active_raids(State &state, DictRef session, Atom faction_id) {
	(void)session; (void)faction_id; (void)state;
	throw state::NotPorted("OverworldRules._enemy_active_raids");
}

DictRef _enemy_config_for_faction(State &state, DictRef scenario, Atom faction_id) {
	(void)scenario; (void)faction_id; (void)state;
	throw state::NotPorted("OverworldRules._enemy_config_for_faction");
}

int64_t _enemy_max_active_raids_for_strategy(State &state, DictRef session, DictRef config, Atom faction_id) {
	(void)session; (void)config; (void)faction_id; (void)state;
	throw state::NotPorted("OverworldRules._enemy_max_active_raids_for_strategy");
}

int64_t _enemy_pressure(State &state, DictRef session, Atom faction_id) {
	(void)session; (void)faction_id; (void)state;
	throw state::NotPorted("OverworldRules._enemy_pressure");
}

int64_t _enemy_raid_threshold_for_strategy(State &state, DictRef session, DictRef config, Atom faction_id) {
	(void)session; (void)config; (void)faction_id; (void)state;
	throw state::NotPorted("OverworldRules._enemy_raid_threshold_for_strategy");
}

DictRef _enemy_state_for_faction(State &state, DictRef session, Atom faction_id) {
	(void)session; (void)faction_id; (void)state;
	throw state::NotPorted("OverworldRules._enemy_state_for_faction");
}

DictRef _find_active_town(State &state, DictRef session) {
	(void)session; (void)state;
	throw state::NotPorted("OverworldRules._find_active_town");
}

DictRef _find_active_town_by_visit_context(State &state, DictRef session) {
	(void)session; (void)state;
	throw state::NotPorted("OverworldRules._find_active_town_by_visit_context");
}

Atom _normalized_enemy_front_faction_id(State &state, DictRef session, DictRef front, DictRef town) {
	(void)session; (void)front; (void)town; (void)state;
	throw state::NotPorted("OverworldRules._normalized_enemy_front_faction_id");
}

Atom _posture_label(State &state, Atom posture) {
	(void)posture; (void)state;
	throw state::NotPorted("OverworldRules._posture_label");
}

int64_t _pressure_bonus_from_profile(State &state, const Value &profile) {
	(void)profile; (void)state;
	throw state::NotPorted("OverworldRules._pressure_bonus_from_profile");
}

int64_t _public_enemy_pressure_gain(State &state, DictRef session, DictRef config) {
	(void)session; (void)config; (void)state;
	throw state::NotPorted("OverworldRules._public_enemy_pressure_gain");
}

bool _raid_target_is_objective_anchor(State &state, DictRef session, Atom target_kind, Atom placement_id) {
	(void)session; (void)target_kind; (void)placement_id; (void)state;
	throw state::NotPorted("OverworldRules._raid_target_is_objective_anchor");
}

int64_t _readiness_bonus_from_profile(State &state, const Value &profile) {
	(void)profile; (void)state;
	throw state::NotPorted("OverworldRules._readiness_bonus_from_profile");
}

DictRef _resource_site_delivery_interception(State &state, DictRef session, DictRef node, DictRef site) {
	(void)session; (void)node; (void)site; (void)state;
	throw state::NotPorted("OverworldRules._resource_site_delivery_interception");
}

DictRef _resource_site_response_profile(State &state, DictRef site) {
	(void)site; (void)state;
	throw state::NotPorted("OverworldRules._resource_site_response_profile");
}

DictRef _retake_front_from_legacy_state(State &state, DictRef session, DictRef town, DictRef front) {
	(void)session; (void)town; (void)front; (void)state;
	throw state::NotPorted("OverworldRules._retake_front_from_legacy_state");
}

int64_t _route_security_rating_for_hero(State &state, DictRef hero) {
	(void)hero; (void)state;
	throw state::NotPorted("OverworldRules._route_security_rating_for_hero");
}

bool _scenario_objective_met(State &state, DictRef session, DictRef objective) {
	(void)session; (void)objective; (void)state;
	throw state::NotPorted("OverworldRules._scenario_objective_met");
}

bool _scenario_town_started_enemy(State &state, DictRef session, Atom placement_id) {
	(void)session; (void)placement_id; (void)state;
	throw state::NotPorted("OverworldRules._scenario_town_started_enemy");
}

void _teach_visiting_town_spells(State &state, DictRef session, DictRef town) {
	(void)session; (void)town; (void)state;
	throw state::NotPorted("OverworldRules._teach_visiting_town_spells");
}

Atom _terrain_name_at(State &state, DictRef session, int64_t x, int64_t y) {
	(void)session; (void)x; (void)y; (void)state;
	throw state::NotPorted("OverworldRules._terrain_name_at");
}

int64_t _town_battle_readiness(State &state, DictRef town, const Value &session, DictRef metric_context, int64_t reinforcement_quality) {
	(void)town; (void)session; (void)metric_context; (void)reinforcement_quality; (void)state;
	throw state::NotPorted("OverworldRules._town_battle_readiness");
}

Atom _town_command_risk_consequence(State &state, DictRef town, int64_t readiness, DictRef logistics, DictRef recovery, DictRef capital_project, bool objective_anchor) {
	(void)town; (void)readiness; (void)logistics; (void)recovery; (void)capital_project; (void)objective_anchor; (void)state;
	throw state::NotPorted("OverworldRules._town_command_risk_consequence");
}

Atom _town_defense_summary(State &state, DictRef town) {
	(void)town; (void)state;
	throw state::NotPorted("OverworldRules._town_defense_summary");
}

int64_t _town_front_priority_seed(State &state, Atom role, bool objective_anchor) {
	(void)role; (void)objective_anchor; (void)state;
	throw state::NotPorted("OverworldRules._town_front_priority_seed");
}

DictRef _town_front_state(State &state, DictRef session, DictRef town, DictRef precomputed_development_metrics) {
	(void)session; (void)town; (void)precomputed_development_metrics; (void)state;
	throw state::NotPorted("OverworldRules._town_front_state");
}

int64_t _town_garrison_headcount(State &state, DictRef town) {
	(void)town; (void)state;
	throw state::NotPorted("OverworldRules._town_garrison_headcount");
}

int64_t _town_garrison_strength(State &state, DictRef town) {
	(void)town; (void)state;
	throw state::NotPorted("OverworldRules._town_garrison_strength");
}

int64_t _town_occupation_seed_pressure(State &state, DictRef session, DictRef town) {
	(void)session; (void)town; (void)state;
	throw state::NotPorted("OverworldRules._town_occupation_seed_pressure");
}

int64_t _town_pressure_output(State &state, DictRef town, const Value &session, DictRef metric_context, int64_t reinforcement_quality) {
	(void)town; (void)session; (void)metric_context; (void)reinforcement_quality; (void)state;
	throw state::NotPorted("OverworldRules._town_pressure_output");
}

int64_t _town_reinforcement_quality(State &state, DictRef town, const Value &session, DictRef metric_context) {
	(void)town; (void)session; (void)metric_context; (void)state;
	throw state::NotPorted("OverworldRules._town_reinforcement_quality");
}

int64_t _town_role_pressure_bonus(State &state, Atom role) {
	(void)role; (void)state;
	throw state::NotPorted("OverworldRules._town_role_pressure_bonus");
}

int64_t _town_role_quality_bonus(State &state, Atom role) {
	(void)role; (void)state;
	throw state::NotPorted("OverworldRules._town_role_quality_bonus");
}

int64_t _town_role_readiness_bonus(State &state, Atom role) {
	(void)role; (void)state;
	throw state::NotPorted("OverworldRules._town_role_readiness_bonus");
}

int64_t _town_spell_tier(State &state, DictRef town) {
	(void)town; (void)state;
	throw state::NotPorted("OverworldRules._town_spell_tier");
}

Atom encounter_commander_name(State &state, DictRef encounter) {
	(void)encounter; (void)state;
	throw state::NotPorted("OverworldRules.encounter_commander_name");
}

Atom encounter_commander_threat_label(State &state, DictRef encounter) {
	(void)encounter; (void)state;
	throw state::NotPorted("OverworldRules.encounter_commander_threat_label");
}

Atom encounter_display_name(State &state, DictRef encounter) {
	(void)encounter; (void)state;
	throw state::NotPorted("OverworldRules.encounter_display_name");
}

DictRef town_development_metrics(State &state, DictRef town, const Value &session) {
	(void)town; (void)session; (void)state;
	throw state::NotPorted("OverworldRules.town_development_metrics");
}

} // namespace overworld_rules

namespace overworld_turn_playback {

Atom _actor_name(State &state, DictRef actor) {
	(void)actor; (void)state;
	throw state::NotPorted("OverworldTurnPlayback._actor_name");
}

DictRef _visual_actor(State &state, DictRef actor, DictRef point) {
	(void)actor; (void)point; (void)state;
	throw state::NotPorted("OverworldTurnPlayback._visual_actor");
}

bool visible(State &state, const Value &session, DictRef point) {
	(void)session; (void)point; (void)state;
	throw state::NotPorted("OverworldTurnPlayback.visible");
}

} // namespace overworld_turn_playback

namespace player_identity_rules {

DictRef config_for_controller(State &state, const Value &session, Atom controller) {
	(void)session; (void)controller; (void)state;
	throw state::NotPorted("PlayerIdentityRules.config_for_controller");
}

Atom defender_controller_id(State &state, DictRef record) {
	(void)record; (void)state;
	throw state::NotPorted("PlayerIdentityRules.defender_controller_id");
}

ArrayRef from_slots(State &state, ArrayRef slots) {
	(void)slots; (void)state;
	throw state::NotPorted("PlayerIdentityRules.from_slots");
}

} // namespace player_identity_rules

namespace scenario_factory {

ArrayRef _build_resource_states(State &state, const Value &placements) {
	(void)placements; (void)state;
	throw state::NotPorted("ScenarioFactory._build_resource_states");
}

ArrayRef _build_town_states(State &state, const Value &placements) {
	(void)placements; (void)state;
	throw state::NotPorted("ScenarioFactory._build_town_states");
}

void _copy_resource_runtime_metadata(State &state, DictRef target, DictRef source) {
	(void)target; (void)source; (void)state;
	throw state::NotPorted("ScenarioFactory._copy_resource_runtime_metadata");
}

DictRef _duplicate_dict(State &state, const Value &value) {
	(void)value; (void)state;
	throw state::NotPorted("ScenarioFactory._duplicate_dict");
}

} // namespace scenario_factory

namespace scenario_rules {

int64_t _army_unit_count(State &state, DictRef army, Atom unit_id) {
	(void)army; (void)unit_id; (void)state;
	throw state::NotPorted("ScenarioRules._army_unit_count");
}

DictRef _artifact_set_equipment_progress(State &state, DictRef session, DictRef objective) {
	(void)session; (void)objective; (void)state;
	throw state::NotPorted("ScenarioRules._artifact_set_equipment_progress");
}

DictRef _controlled_hero_army(State &state, DictRef session, Atom hero_id) {
	(void)session; (void)hero_id; (void)state;
	throw state::NotPorted("ScenarioRules._controlled_hero_army");
}

DictRef _controlled_hero_state(State &state, DictRef session, Atom hero_id) {
	(void)session; (void)hero_id; (void)state;
	throw state::NotPorted("ScenarioRules._controlled_hero_state");
}

DictRef _find_town(State &state, DictRef session, DictRef objective) {
	(void)session; (void)objective; (void)state;
	throw state::NotPorted("ScenarioRules._find_town");
}

DictRef _hero_army_requirement_progress(State &state, DictRef session, DictRef objective) {
	(void)session; (void)objective; (void)state;
	throw state::NotPorted("ScenarioRules._hero_army_requirement_progress");
}

DictRef _hero_progression_requirement_progress(State &state, DictRef session, DictRef objective) {
	(void)session; (void)objective; (void)state;
	throw state::NotPorted("ScenarioRules._hero_progression_requirement_progress");
}

DictRef _hero_stationing_progress(State &state, DictRef session, DictRef objective) {
	(void)session; (void)objective; (void)state;
	throw state::NotPorted("ScenarioRules._hero_stationing_progress");
}

DictRef _map_exploration_progress(State &state, DictRef session, DictRef objective) {
	(void)session; (void)objective; (void)state;
	throw state::NotPorted("ScenarioRules._map_exploration_progress");
}

Value _overworld_rules(State &state) {
	(void)state;
	throw state::NotPorted("ScenarioRules._overworld_rules");
}

bool _player_knows_spell(State &state, DictRef session, Atom spell_id) {
	(void)session; (void)spell_id; (void)state;
	throw state::NotPorted("ScenarioRules._player_knows_spell");
}

bool _player_owns_artifact(State &state, DictRef session, Atom artifact_id) {
	(void)session; (void)artifact_id; (void)state;
	throw state::NotPorted("ScenarioRules._player_owns_artifact");
}

DictRef _reserve_delivery_progress(State &state, DictRef session, DictRef objective) {
	(void)session; (void)objective; (void)state;
	throw state::NotPorted("ScenarioRules._reserve_delivery_progress");
}

DictRef _resource_site_control_progress(State &state, DictRef session, DictRef objective) {
	(void)session; (void)objective; (void)state;
	throw state::NotPorted("ScenarioRules._resource_site_control_progress");
}

DictRef _resource_stockpile_progress(State &state, DictRef session, DictRef objective) {
	(void)session; (void)objective; (void)state;
	throw state::NotPorted("ScenarioRules._resource_stockpile_progress");
}

Atom _titleize_token(State &state, Atom value) {
	(void)value; (void)state;
	throw state::NotPorted("ScenarioRules._titleize_token");
}

DictRef _town_garrison_requirement_progress(State &state, DictRef session, DictRef objective) {
	(void)session; (void)objective; (void)state;
	throw state::NotPorted("ScenarioRules._town_garrison_requirement_progress");
}

bool _town_has_objective_building(State &state, DictRef town, Atom building_id) {
	(void)town; (void)building_id; (void)state;
	throw state::NotPorted("ScenarioRules._town_has_objective_building");
}

} // namespace scenario_rules

namespace scenario_script_rules {

bool _encounter_resolved(State &state, DictRef session, Atom placement_id) {
	(void)session; (void)placement_id; (void)state;
	throw state::NotPorted("ScenarioScriptRules._encounter_resolved");
}

bool _hook_fired(State &state, DictRef session, Atom hook_id) {
	(void)session; (void)hook_id; (void)state;
	throw state::NotPorted("ScenarioScriptRules._hook_fired");
}

DictRef build_script_state(State &state) {
	(void)state;
	throw state::NotPorted("ScenarioScriptRules.build_script_state");
}

} // namespace scenario_script_rules

namespace spell_rules {

DictRef mana_state(State &state, DictRef hero_state) {
	(void)hero_state; (void)state;
	throw state::NotPorted("SpellRules.mana_state");
}

} // namespace spell_rules

namespace town_development_rules {

ArrayRef offers(State &state, DictRef town, int64_t day, ArrayRef excluded_ids) {
	(void)town; (void)day; (void)excluded_ids; (void)state;
	throw state::NotPorted("TownDevelopmentRules.offers");
}

int64_t price(State &state, DictRef artifact) {
	(void)artifact; (void)state;
	throw state::NotPorted("TownDevelopmentRules.price");
}

bool satisfies(State &state, ArrayRef built, Atom required) {
	(void)built; (void)required; (void)state;
	throw state::NotPorted("TownDevelopmentRules.satisfies");
}

DictRef trade_artifact(State &state, DictRef hero, DictRef town, int64_t day, Atom artifact_id, bool buying, DictRef resources, ArrayRef excluded_ids) {
	(void)hero; (void)town; (void)day; (void)artifact_id; (void)buying; (void)resources; (void)excluded_ids; (void)state;
	throw state::NotPorted("TownDevelopmentRules.trade_artifact");
}

} // namespace town_development_rules

namespace town_rules {

DictRef teach_visiting_heroes(State &state, DictRef session, DictRef town) {
	(void)session; (void)town; (void)state;
	throw state::NotPorted("TownRules.teach_visiting_heroes");
}

} // namespace town_rules

namespace visit_building_rules {

Atom _resource_text(State &state, DictRef resources) {
	(void)resources; (void)state;
	throw state::NotPorted("VisitBuildingRules._resource_text");
}

} // namespace visit_building_rules

} // namespace aurelion::rules::port
