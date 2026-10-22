#pragma once

// scripts/core/EnemyAdventureRules.gd: the functions the computer players' day runs
// (docs/native-rules-engine-transition.md, Phase 4), ported function by
// function under the GDScript names. A session is its view (session_view.hpp).

#include "aurelion_rules/port/gd.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/battle_ends.hpp"
#include "aurelion_rules/port/enemy_adventure_rules.hpp"
#include "aurelion_rules/port/enemy_adventure_rules_ai.hpp"
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

// Ported in enemy_adventure_rules_turn.cpp.
DictRef _apply_resource_site_artifact_reward_to_raid(State &state, DictRef session, Atom faction_id, DictRef raid, DictRef node, DictRef site);
DictRef _apply_resource_site_claim_recruits_to_raid(State &state, DictRef session, Atom faction_id, DictRef raid, DictRef site);
DictRef _apply_resource_site_spell_reward_to_commander(State &state, DictRef session, Atom faction_id, DictRef raid, DictRef site);
bool _break_dwelling_guard_by_raid(State &state, DictRef session, DictRef raid, Atom faction_id, int64_t index, DictRef site);
int64_t _commander_map_level(State &state, const Value &source);
Atom _default_public_importance(State &state, Atom target_kind, ArrayRef reason_codes);
Atom _describe_recruit_set(State &state, const Value &recruits);
Atom _describe_resource_set(State &state, DictRef resources);
Atom _event_visibility(State &state, DictRef session, int64_t x, int64_t y, Atom public_importance, int64_t level = 0);
DictRef _hire_at_own_dwelling_by_raid(State &state, DictRef session, DictRef raid, DictRef state_, Atom faction_id, int64_t index, DictRef site, DictRef _config);
DictRef _hire_dwelling_creatures_into_raid(State &state, DictRef session, Atom faction_id, DictRef raid, int64_t index, DictRef site, DictRef state_);
int64_t _linked_player_town_bonus(State &state, DictRef session, DictRef node);
DictRef _merge_resources(State &state, const Value &base, const Value &delta);
DictRef _normalize_recruit_payload(State &state, const Value &recruits);
Atom _raid_name(State &state, DictRef raid);
DictRef _raid_reinforcement_army(State &state, DictRef raid);
DictRef _raid_site_recruit_admission(State &state, DictRef raid, DictRef site);
DictRef _record_adventure_objective_success(State &state, DictRef session, Atom faction_id, DictRef raid, Atom outcome_id, Atom active_placement_id = state::key::empty);
int64_t _recruit_payload_value(State &state, const Value &recruits);
int64_t _resource_route_pressure_value(State &state, DictRef site);
DictRef _resource_site_claim_recruits(State &state, DictRef site);
int64_t _resource_site_support_value(State &state, DictRef site);
ArrayRef _resource_target_reason_codes(State &state, DictRef site, bool player_controlled, bool persistent, int64_t income_value, int64_t recruit_payload_value, int64_t route_pressure_value, int64_t town_enablement_value, int64_t scarcity_value = 0);
DictRef _reward_resources_for_empire(State &state, const Value &rewards);
DictRef _secure_resource_target(State &state, DictRef session, DictRef raid, DictRef state_, Atom faction_id, DictRef config);
int64_t _target_level(State &state, DictRef session, Atom kind, Atom target_id, Atom faction_id = state::key::empty, int64_t fallback = 0);
int64_t _target_resource_value(State &state, const Value &rewards);
DictRef _visit_building_by_raid(State &state, DictRef session, DictRef raid, DictRef state_, Atom faction_id, DictRef node_result, DictRef site, DictRef _config);
DictRef build_ai_event_record(State &state, DictRef session, DictRef config, Atom event_type, DictRef actor, DictRef target, DictRef options);
Atom raid_commander_display_name(State &state, DictRef encounter);
Atom raid_commander_name(State &state, DictRef encounter);

// Ported in enemy_adventure_rules_turn_rare.cpp (slice 4.2: paths the six seeds do not run).
DictRef _clear_regroup_target(State &state, DictRef raid);
ArrayRef _current_enemy_player_hero_sighting_records(State &state, DictRef session, DictRef config, Atom faction_id, const Value &preloaded_sources = Value(), const Value &projection_profile = Value());
DictRef _default_enemy_strategy(State &state);
ArrayRef _default_reason_codes_for_target(State &state, Atom target_kind, Atom target_id, DictRef target);
int64_t _dwelling_guard_strength(State &state, DictRef session, DictRef node, DictRef site, Atom faction_id);
bool _encounter_is_objective_anchor(State &state, DictRef session, DictRef encounter);
ArrayRef _enemy_hero_sighting_sources(State &state, DictRef session, DictRef config, Atom faction_id);
DictRef _enemy_player_hero_sighting_record(State &state, DictRef session, Atom faction_id, Atom hero_id);
int64_t _exploration_target_level(State &state, Atom target_id);
DictRef _find_encounter_by_placement(State &state, DictRef session, Atom placement_id);
DictRef _find_player_hero(State &state, DictRef session, Atom hero_id);
DictRef _find_town_by_placement(State &state, DictRef session, Atom placement_id);
DictRef _known_player_hero_snapshot_for_ai(State &state, DictRef session, Atom faction_id, DictRef hero);
int64_t _known_player_hero_strength(State &state, DictRef hero);
DictRef _merge_strategy_dict(State &state, DictRef base, DictRef override);
Vector2i _player_hero_goal_tile(State &state, DictRef hero);
ArrayRef _player_hero_snapshots_for_intercept(State &state, DictRef session, bool read_only = false);
int64_t _preferred_commander_index_for_encounter(State &state, DictRef encounter);
DictRef _secure_native_passage_target(State &state, DictRef session, DictRef raid, DictRef state_, Atom faction_id, DictRef node, bool preserve_target = false);
Atom _town_controller_faction_id(State &state, DictRef town_state);
bool _town_is_objective_anchor(State &state, DictRef session, Atom placement_id);
bool commander_can_deploy(State &state, const Value &source);
Atom commander_recent_outcome_brief(State &state, const Value &source);
DictRef enemy_strategy(State &state, DictRef config, Atom faction_id);
DictRef occupied_raid_commander_ids(State &state, DictRef session, Atom faction_id = state::key::empty, Atom exclude_placement_id = state::key::empty);
Atom raid_display_name(State &state, DictRef encounter);
int64_t raid_strength(State &state, DictRef encounter);
Atom select_raid_commander_roster_hero_id(State &state, DictRef session, Atom faction_id, int64_t preferred_index, DictRef occupied_commander_ids, const Value &commander_roster);
int64_t strategy_int(State &state, DictRef strategy, Atom section, Atom key, int64_t default_value = 0);
double strategy_scalar(State &state, DictRef strategy, Atom section, Atom key, double default_value = 1.0);
bool target_is_objective_anchor(State &state, DictRef session, Atom target_kind, Atom placement_id);

// Not run by the six seeds: Phase 5's slice 09 ported them (enemy_states.cpp), and no other header declares them.
void _clear_resource_defender_metadata(State &state, DictRef node);
void _clear_town_defender_metadata(State &state, DictRef town);

} // namespace aurelion::rules::port::enemy_adventure_rules
