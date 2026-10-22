#pragma once

// scripts/core/OverworldRules.gd: the functions the computer players' day runs
// (docs/native-rules-engine-transition.md, Phase 4), ported function by
// function under the GDScript names. A session is its view (session_view.hpp).

#include "aurelion_rules/port/gd.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/battle_ends.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"
#include "aurelion_rules/port/overworld_rules_ai.hpp"

#include <cstdint>

namespace aurelion::rules::port::overworld_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using gd::PackedRef;
using state::State;
using state::Value;

// Ported in overworld_rules_turn.cpp.
DictRef _blocked_tile_index(State &state, DictRef session, int64_t level = -1);
DictRef _native_passage_endpoint_safety(State &state, DictRef session, DictRef node, Atom actor_id, const Value &actor_blocked_indexes = Value(), bool combat_arrival = false);
Atom _terrain_id_at(State &state, DictRef session, int64_t x, int64_t y, int64_t level = -1);
bool is_tile_explored(State &state, DictRef session, int64_t x, int64_t y, int64_t level = -1);
ArrayRef map_for_level(State &state, DictRef session, int64_t level = -1);
DictRef native_passage_travel_check(State &state, DictRef session, DictRef node, const Value &actor_position, Atom actor_id, Atom target_id = state::key::empty, bool fight_on_arrival = false);
int64_t placement_level(State &state, DictRef session, Atom placement_id, int64_t fallback = 0);
DictRef town_weekly_growth(State &state, DictRef town, const Value &session = Value());
Atom native_exit_roll_key(State &state, DictRef session, DictRef node, Atom actor_id);
DictRef native_random_exit_check(State &state, DictRef session, DictRef node, const Value &actor_position, Atom actor_id);
void note_native_trip(State &state, DictRef session, Atom actor_id);
DictRef town_capital_project_state(State &state, DictRef town, const Value &session = Value());
int64_t town_logistics_support_radius(State &state, DictRef session, DictRef town);
Atom apply_resource_site_disruption(State &state, DictRef session, DictRef node, DictRef site, Atom previous_controller, Atom attacker_controller);
DictRef _town_scaling_hero(State &state, DictRef session, DictRef town);
DictRef _effective_player_town_weekly_growth(State &state, DictRef session, DictRef town);

// Ported in overworld_rules_turn_rare.cpp (slice 4.2: paths the six seeds do not run).
ArrayRef _build_scenario_resource_states(State &state, const Value &placements);
ArrayRef _build_scenario_town_states(State &state, const Value &placements);
DictRef _command_risk_encounter_objective_item(State &state, DictRef session, DictRef objective, bool include_details = true);
DictRef _command_risk_pressure_objective_item(State &state, DictRef session, DictRef scenario, DictRef objective, bool include_details = true);
bool _delivery_encounter_matches_node(State &state, DictRef session, DictRef encounter, DictRef node, DictRef delivery_state);
int64_t _enemy_active_raids(State &state, DictRef session, Atom faction_id);
DictRef _enemy_config_for_faction(State &state, DictRef scenario, Atom faction_id);
int64_t _enemy_max_active_raids_for_strategy(State &state, DictRef session, DictRef config, Atom faction_id);
int64_t _enemy_pressure(State &state, DictRef session, Atom faction_id);
int64_t _enemy_raid_threshold_for_strategy(State &state, DictRef session, DictRef config, Atom faction_id);
DictRef _find_active_town(State &state, DictRef session);
DictRef _find_active_town_by_visit_context(State &state, DictRef session);
Atom _posture_label(State &state, Atom posture);
int64_t _pressure_bonus_from_profile(State &state, const Value &profile);
int64_t _public_enemy_pressure_gain(State &state, DictRef session, DictRef config);
bool _raid_target_is_objective_anchor(State &state, DictRef session, Atom target_kind, Atom placement_id);
DictRef _resource_site_delivery_interception(State &state, DictRef session, DictRef node, DictRef site);
DictRef _resource_site_response_profile(State &state, DictRef site);
int64_t _route_security_rating_for_hero(State &state, DictRef hero);
bool _scenario_objective_met(State &state, DictRef session, DictRef objective);
Atom _terrain_name_at(State &state, DictRef session, int64_t x, int64_t y);
Atom _town_command_risk_consequence(State &state, DictRef town, int64_t readiness, DictRef logistics, DictRef recovery, DictRef capital_project, bool objective_anchor);
Atom _town_defense_summary(State &state, DictRef town);
int64_t _town_pressure_output(State &state, DictRef town, const Value &session, DictRef metric_context, int64_t reinforcement_quality = -1);
int64_t _town_role_pressure_bonus(State &state, Atom role);
Atom encounter_commander_name(State &state, DictRef encounter);
Atom encounter_commander_threat_label(State &state, DictRef encounter);
Atom encounter_display_name(State &state, DictRef encounter);
DictRef town_development_metrics(State &state, DictRef town, const Value &session = Value());

} // namespace aurelion::rules::port::overworld_rules
