#pragma once

// The overworld, town and hero panels (docs/native-rules-engine-transition.md,
// Phase 7, slice 7.8), ported function by function under the GDScript names:
// the screens' texts, boards, forecasts, feeds and the queries they read. A
// session is its view (session_view.hpp).

#include "aurelion_rules/port/gd.hpp"
#include "aurelion_rules/port/scenario_outcome.hpp"

#include <cstdint>

namespace aurelion::rules::port::overworld_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using state::State;
using state::Value;

// overworld_rules_panel_status.cpp.
bool is_runtime_session_normalized(State &state, DictRef session);
void begin_normalized_read_scope(State &state, DictRef session);
void end_normalized_read_scope(State &state, DictRef session);
DictRef validation_last_normalized_read_scope_cache_profile(State &state);
DictRef validation_pathing_profile_snapshot(State &state);
void validation_set_pathing_profile_capture_enabled(State &state, bool enabled);
Atom describe_visibility(State &state, DictRef session);
DictRef set_active_town_visit(State &state, DictRef session, Atom placement_id);
DictRef _resource_node_at_tile(State &state, DictRef session, int64_t x, int64_t y);
DictRef _encounter_at_tile(State &state, DictRef session, int64_t x, int64_t y);
DictRef overworld_object_placement_pathing_surface(State &state, DictRef session, Atom placement_id);
ArrayRef town_footprint_tiles(State &state, DictRef town);
bool hero_cast_spell_today(State &state, DictRef session, Atom hero_id);
ArrayRef mine_footprint_tiles(State &state, DictRef node);
Atom describe_status(State &state, DictRef session);
int64_t _weekday_of_day(State &state, int64_t day);
Atom _overworld_hero_line(State &state, DictRef hero);
Atom describe_heroes(State &state, DictRef session);
int64_t days_until_next_weekly_growth(State &state, int64_t day);
int64_t next_weekly_growth_day(State &state, int64_t day);
Atom town_control_label(State &state, Atom owner);
Atom describe_town_context(State &state, DictRef town, const Value &session);
Atom describe_context(State &state, DictRef session);
Atom describe_spellbook(State &state, DictRef session, Atom context_filter = state::key::empty);
Atom describe_spellbook_rail(State &state, DictRef session, Atom context_filter = state::key::empty);
Atom describe_specialties(State &state, DictRef session);
Atom describe_artifacts(State &state, DictRef session);
Atom town_strategic_summary(State &state, DictRef town);
Atom describe_town_identity_surface(State &state, DictRef town, const Value &session);
DictRef town_public_threat_state(State &state, DictRef session, DictRef town);
DictRef town_occupation_state(State &state, DictRef session, DictRef town);
Atom describe_town_market(State &state, DictRef session, DictRef town);
Atom describe_town_response_panel(State &state, DictRef session, DictRef town);
DictRef player_daily_income(State &state, DictRef session);
DictRef _player_daily_income_projection(State &state, DictRef session, int64_t next_day);
Atom _town_strategic_summary(State &state, DictRef town);
Atom _town_identity_surface(State &state, DictRef town, const Value &session);
Atom _town_economy_identity_line(State &state, DictRef town, DictRef town_template, DictRef faction, const Value &session);
Atom _town_magic_identity_line(State &state, DictRef town, DictRef town_template);
Atom _town_role_label(State &state, Atom role);
ArrayRef _town_response_panel_lines(State &state, DictRef session, DictRef town);
ArrayRef _town_market_panel_lines(State &state, DictRef session, DictRef town);
Atom _market_usage_summary(State &state, DictRef market_state, DictRef usage);
int64_t _town_garrison_company_count(State &state, DictRef town);

// overworld_rules_panel_objectives.cpp.
Atom _scenario_opening_objective_summary(State &state, DictRef session, DictRef scenario);
ArrayRef _scenario_enemy_operational_lines(State &state, DictRef session, DictRef scenario);
Atom _scenario_first_contact_summary(State &state, DictRef scenario);
ArrayRef _scenario_objective_labels_from_bucket(State &state, DictRef session, const Value &bucket, int64_t limit);
bool _scenario_is_objective_met(State &state, DictRef session, Atom objective_id, Atom bucket);
Atom _scenario_describe_objectives(State &state, DictRef session);
Atom _describe_recent_events(State &state, DictRef session, int64_t limit);
Atom _describe_enemy_threats(State &state, DictRef session);
DictRef describe_objective_header_surfaces(State &state, DictRef session);
Atom _describe_objective_brief_from_surface(State &state, DictRef surface);
Atom describe_objective_stakes_board(State &state, DictRef session);
Atom _describe_objective_stakes_board_from_surface(State &state, DictRef session, DictRef surface, DictRef preloaded_progress);
Atom describe_objective_board(State &state, DictRef session);
Atom describe_objectives(State &state, DictRef session);
DictRef _objective_stakes_surface(State &state, DictRef session);
DictRef _campaign_context_for_session(State &state, DictRef session, DictRef scenario);
DictRef _campaign_scenario_entry(State &state, DictRef campaign, Atom scenario_id);
Atom _join_limited_labels(State &state, ArrayRef labels, int64_t limit, Atom fallback);
Atom describe_frontier_threats(State &state, DictRef session);
Atom describe_defense_readiness_warnings(State &state, DictRef session, int64_t limit = 2);
Atom describe_town_defense_readiness_warning(State &state, DictRef session, DictRef town);
ArrayRef _defense_readiness_warning_items(State &state, DictRef session);
DictRef _defense_readiness_warning_item(State &state, DictRef session, DictRef town, bool include_steady);
ArrayRef _defense_readiness_pressure_parts(State &state, DictRef threat_state, DictRef front, DictRef occupation);
Atom _defense_readiness_warning_why(State &state, bool objective_anchor, bool has_pressure, bool logistics_alert, bool recovery_alert, bool capital_alert, bool low_readiness);
Atom _defense_readiness_next_step(State &state, bool has_pressure, bool logistics_alert, bool recovery_alert, bool capital_alert, bool low_readiness, bool front_active, int64_t readiness);
Atom _local_visible_threat_summary(State &state, DictRef session, Atom fallback = state::key::empty);
Atom _occupied_town_watch_summary(State &state, DictRef session);

// overworld_rules_panel_forecast.cpp.
Atom describe_command_briefing(State &state, DictRef session);
Atom consume_command_briefing(State &state, DictRef session);
Atom describe_command_risk(State &state, DictRef session);
Atom describe_command_risk_summary_from_normalized_session(State &state, DictRef session);
DictRef _refresh_watch_observation_context(State &state, DictRef session);
DictRef _refresh_watch_observation_context_from_normalized_session(State &state, DictRef session);
Atom describe_commitment_board(State &state, DictRef session, DictRef refresh_watch_context);
Atom describe_command_risk_forecast(State &state, DictRef session);
Atom describe_end_turn_forecast(State &state, DictRef session);
Atom describe_end_turn_forecast_compact(State &state, DictRef session);
DictRef describe_end_turn_forecast_surfaces(State &state, DictRef session, DictRef refresh_watch_context);
DictRef describe_command_risk_surfaces(State &state, DictRef session);
DictRef _command_risk_surfaces_from_forecast(State &state, DictRef forecast);
Atom consume_command_risk_forecast(State &state, DictRef session);
Atom _end_turn_income_forecast_line(State &state, DictRef session, int64_t next_day);
Atom _end_turn_muster_forecast_line(State &state, DictRef session, int64_t next_day);
Atom _end_turn_movement_forecast_line(State &state, DictRef session);
Atom _end_turn_risk_forecast_line(State &state, DictRef session);
Atom _end_turn_risk_forecast_line_from_watch_context(State &state, DictRef refresh_watch_context);
Atom describe_management_watch(State &state, DictRef session);
Atom _describe_management_watch_from_normalized_session(State &state, DictRef session);
bool _should_surface_command_briefing(State &state, DictRef session);
bool _should_surface_command_risk_forecast(State &state, DictRef session);
ArrayRef _command_briefing_lines(State &state, DictRef session);
Atom _command_briefing_posture_line(State &state, DictRef session);
Atom _command_briefing_logistics_line(State &state, DictRef session);
Atom _command_briefing_pressure_line(State &state, DictRef session, DictRef scenario);
Atom _command_briefing_orders_line(State &state, DictRef session, DictRef scenario);
Atom _command_commitment_action_line(State &state, DictRef session);
Atom _command_commitment_action_summary(State &state, DictRef session, DictRef action);
Atom _command_commitment_route_line(State &state, DictRef session);
Atom _command_commitment_coverage_line(State &state, DictRef session);
Atom _command_commitment_hold_line(State &state, DictRef session);
Atom _command_commitment_hold_line_from_watch_context(State &state, DictRef session, DictRef refresh_watch_context);
Atom _command_commitment_hold_line_from_forecast(State &state, DictRef session, DictRef forecast);
DictRef _nearest_reserve_hero_support(State &state, DictRef session);
DictRef _nearest_logistics_plan(State &state, DictRef session);
DictRef _nearest_visible_encounter_plan(State &state, DictRef session);
Atom _direction_from_to(State &state, Vector2i origin, Vector2i target);

// overworld_rules_panel_feed.cpp.
Atom describe_encounter_pressure(State &state, DictRef session, DictRef encounter, bool for_battle_prompt = false);
Atom describe_encounter_readability_surface(State &state, DictRef session, DictRef encounter);
Atom describe_encounter_guard_link_surface(State &state, DictRef session, DictRef encounter);
Atom describe_dispatch(State &state, DictRef session, Atom last_message = state::key::empty);
Atom _describe_dispatch_from_observation_context(State &state, DictRef session, Atom last_message, DictRef observation_context);
DictRef describe_event_dispatch_surfaces(State &state, DictRef session, Atom last_message, Atom turn_resolution_summary, Atom enemy_activity_summary, const Value &enemy_activity_events_value, const Value &action_recap_value, DictRef refresh_watch_context);
DictRef _event_dispatch_observation_context(State &state, DictRef session, DictRef refresh_watch_context);
DictRef describe_event_feed_surface(State &state, DictRef session, Atom last_message, Atom turn_resolution_summary, Atom enemy_activity_summary, const Value &enemy_activity_events_value, const Value &action_recap_value);
DictRef _describe_event_feed_surface_from_observation_context(State &state, DictRef session, Atom last_message, Atom turn_resolution_summary, Atom enemy_activity_summary, const Value &enemy_activity_events_value, const Value &action_recap_value, DictRef observation_context);
Atom _event_feed_visible_line(State &state, Atom happened, Atom turn_resolution_summary, Atom enemy_activity_summary);
Atom _event_feed_happened_line(State &state, Atom last_message, Atom turn_resolution_summary, Atom enemy_activity_summary, Atom recent_events);
Atom _event_feed_affected_line(State &state, DictRef session, Atom enemy_activity_summary, const Value &enemy_activity_events_value);
Atom _event_feed_why_line(State &state, Atom last_message, Atom turn_resolution_summary, Atom enemy_activity_summary, Atom recent_events);
Atom _event_feed_next_step_line(State &state, DictRef session);
Atom _event_feed_watch_line_from_observation_context(State &state, DictRef observation_context);
DictRef describe_route_interception_surface(State &state, DictRef session, int64_t destination_x = -1, int64_t destination_y = -1, int64_t route_steps = 0, bool include_global_fallback = true);
DictRef _route_interception_empty_surface(State &state);
DictRef _route_interception_payload(State &state, Atom kind, Atom affected, Atom why_it_matters, Atom next_step, Atom cue_text, Atom importance = state::key::normal);
DictRef _selected_route_interception_surface(State &state, DictRef session, Vector2i tile, int64_t route_steps);
DictRef _best_convoy_interception_surface(State &state, DictRef session);
DictRef _convoy_interception_surface(State &state, DictRef session, DictRef node, DictRef site, bool selected);
Atom _convoy_interception_why(State &state, Atom target_kind, Atom target_label);
DictRef _best_raid_interception_surface(State &state, DictRef session);
DictRef _raid_interception_surface(State &state, DictRef session, DictRef encounter, int64_t route_steps, bool selected);
Atom _raid_interception_why(State &state, Atom target_kind, Atom target_label, bool objective_anchor);
Atom _event_feed_convoy_line(State &state, DictRef session);
Atom _dispatch_context_brief(State &state, DictRef session);
// session: Nil in the map editor's palette before a map is loaded.
Atom describe_recruit_source_compact(State &state, const Value &session, DictRef node, DictRef site);
Atom describe_resource_site_control_summary(State &state, DictRef session, DictRef node, DictRef site);
Atom describe_encounter_object_surface(State &state, DictRef encounter);
Atom _encounter_object_tag_summary(State &state, DictRef encounter, DictRef map_object);
Atom _encounter_object_interaction_label(State &state, DictRef encounter, DictRef map_object);
Atom _encounter_role_label(State &state, DictRef encounter);
Atom _encounter_field_objective_surface(State &state, DictRef encounter);
ArrayRef _encounter_tags(State &state, DictRef encounter, DictRef map_object);

} // namespace aurelion::rules::port::overworld_rules

namespace aurelion::rules::port::town_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// town_rules_panels.cpp.
Atom faction_crest_icon_path(State &state, Atom faction_id);
Atom describe_status(State &state, DictRef session);
Atom describe_header(State &state, DictRef session);
Atom town_control_label(State &state, Atom owner);
Atom describe_summary(State &state, DictRef session);
Atom describe_production_overview(State &state, DictRef session);
Atom describe_outlook_board(State &state, DictRef session);
Atom describe_command_ledger(State &state, DictRef session);
Atom describe_defense(State &state, DictRef session);
Atom describe_defense_headline(State &state, DictRef session);
Atom _defense_headline_for_town(State &state, DictRef town);
Atom describe_threats(State &state, DictRef session);
Atom describe_buildings(State &state, DictRef session);
Atom describe_recruitment(State &state, DictRef session);
Atom describe_market(State &state, DictRef session);
Atom describe_spell_access(State &state, DictRef session);
Atom describe_artifacts(State &state, DictRef session);
Atom describe_heroes(State &state, DictRef session);
Atom describe_specialties(State &state, DictRef session);
Atom describe_tavern(State &state, DictRef session);
Atom describe_transfer(State &state, DictRef session);
Atom describe_responses(State &state, DictRef session);
DictRef _army_unit_counts(State &state, const Value &army);
DictRef _duplicate_dictionary(State &state, const Value &value);
ArrayRef _normalize_string_array(State &state, const Value &value);
int64_t _week_of_day(State &state, int64_t day);
int64_t _weekday_of_day(State &state, int64_t day);
int64_t _locked_building_count(State &state, DictRef town);
Atom _describe_building_category_counts(State &state, const Value &building_ids);
Atom _describe_garrison(State &state, DictRef town);
int64_t _garrison_company_count(State &state, DictRef town);
int64_t _garrison_headcount(State &state, DictRef town);
int64_t _garrison_strength(State &state, DictRef town);
Atom _defense_grade(State &state, DictRef town);
Atom _hero_command_line(State &state, DictRef hero);
Atom _growth_source_summary(State &state, DictRef town, Atom unit_id);
Atom _reinforcement_grade(State &state, int64_t quality);
Atom _project_support_summary(State &state, DictRef capital_project);
Atom _project_watch_summary(State &state, DictRef capital_project);
Atom _logistics_watch_summary(State &state, DictRef logistics);
Atom _convoy_watch_summary(State &state, DictRef logistics);
Atom _town_outlook_grade(State &state, int64_t readiness, DictRef threat_state, DictRef front_state, DictRef occupation_state, DictRef logistics, DictRef recovery, DictRef capital_project, int64_t reserve_count, int64_t ready_response_count);
Atom _town_frontier_outlook_line(State &state, DictRef town, DictRef threat_state, DictRef front_state, DictRef occupation_state, DictRef battlefront);
Atom _town_dispatch_readiness_line(State &state, int64_t response_count, int64_t ready_response_count, DictRef movement_state, int64_t reserve_count);
Atom _town_support_watch_line(State &state, DictRef town, DictRef logistics, DictRef recovery, DictRef capital_project);
DictRef _active_hero_movement_state(State &state, DictRef session);
int64_t _count_ready_actions(State &state, ArrayRef actions);
int64_t _stationed_reserve_count(State &state, DictRef session, ArrayRef stationed);
int64_t _enemy_hero_distance_to_town(State &state, DictRef encounter, DictRef town);
ArrayRef _town_threat_lines(State &state, DictRef session, DictRef town);
Atom _pressure_brief(State &state, DictRef session, DictRef town);
DictRef _enemy_state_for_faction(State &state, DictRef session, Atom faction_id);

// town_rules_handoff.cpp.
Atom describe_event_feed(State &state, DictRef session, Atom last_message, DictRef action_recap);
DictRef town_handoff_recap(State &state, DictRef session);
DictRef town_departure_confirmation(State &state, DictRef session);
DictRef town_order_target_handoff(State &state, DictRef session);
DictRef town_action_consequence_signature(State &state, DictRef session);
DictRef build_town_action_recap(State &state, DictRef session, Atom lane, Atom action_id, DictRef action, DictRef result, DictRef before, DictRef after_signature);
Atom _build_order_ledger_line(State &state, DictRef session, DictRef town);
Atom _recruit_order_ledger_line(State &state, DictRef session, DictRef town);
Atom _response_order_ledger_line(State &state, DictRef session, DictRef town);
Atom _coverage_order_ledger_line(State &state, DictRef session, DictRef town);
Atom _town_recommendation_line(State &state, DictRef session, DictRef town);
DictRef _town_recommendation_action(State &state, DictRef session, DictRef town);
DictRef _town_order_target_action(State &state, DictRef session, DictRef town);
Atom _town_order_ui_surface_for_lane(State &state, Atom lane);
Atom _town_order_lane_label(State &state, Atom lane);
Atom _town_order_readiness_line(State &state, DictRef action, Atom lane);
Atom _town_order_impact_line(State &state, DictRef action, Atom lane);
Atom _town_order_next_step(State &state, DictRef action, Atom lane, Atom label, Atom where, Atom readiness);
int64_t _town_build_recommendation_score(State &state, DictRef town, DictRef action);
int64_t _town_recruit_recommendation_score(State &state, DictRef action);
Atom _next_town_action_line(State &state, DictRef session, DictRef town);
DictRef _first_ready_action(State &state, ArrayRef actions);
Atom _town_handoff_affected_line(State &state, Atom town_name, DictRef front, DictRef occupation, DictRef logistics, DictRef ready_response);
Atom _town_handoff_why_line(State &state, DictRef town, DictRef front, DictRef occupation, DictRef logistics, DictRef recovery, DictRef ready_response);
Atom _town_handoff_next_line(State &state, DictRef session, DictRef town, DictRef ready_response, DictRef movement);
Atom _short_town_handoff_text(State &state, Atom text, int64_t max_chars);
Atom _short_action_label(State &state, DictRef action, Atom fallback);
Atom _action_projection_line(State &state, DictRef action);
Atom _town_action_happened_line(State &state, Atom lane, Atom action_id, DictRef action, Atom message);
Atom _town_action_affected_line(State &state, Atom lane, Atom action_id, DictRef action, DictRef before, DictRef after);
Atom _town_action_matters_line(State &state, DictRef session, Atom lane, DictRef before, DictRef after);
Atom _town_action_next_line(State &state, DictRef session);
Atom _first_sentence(State &state, Atom text);
Atom _market_action_target_line(State &state, Atom action_id, DictRef action);
Atom _built_delta_summary(State &state, const Value &before_value, const Value &after_value);
Atom _signed_resource_delta_summary(State &state, const Value &before_value, const Value &after_value, Atom label);
Atom _artifact_delta_summary(State &state, const Value &before_value, const Value &after_value);
Atom _signed_recruit_delta_summary(State &state, const Value &before_value, const Value &after_value, Atom label);
Atom _describe_recruit_delta(State &state, const Value &delta);
int64_t _recruit_pool_total(State &state, const Value &recruits);

} // namespace aurelion::rules::port::town_rules

namespace aurelion::rules::port::scenario_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// scenario_rules_panels.cpp.
bool is_objective_met(State &state, DictRef session, Atom objective_id, Atom bucket = state::key::empty);
DictRef get_objective(State &state, DictRef session, Atom objective_id, Atom bucket = state::key::empty);
Atom describe_objectives(State &state, DictRef session);
ArrayRef _enemy_operational_lines(State &state, DictRef session, DictRef scenario);
Atom _opening_objective_summary(State &state, DictRef session, DictRef scenario);
Atom _first_contact_summary(State &state, DictRef scenario);
ArrayRef _objective_labels_from_bucket(State &state, DictRef session, const Value &bucket, int64_t limit);
ArrayRef _nearest_encounter_placements(State &state, DictRef scenario, int64_t limit);
ArrayRef _priority_target_labels(State &state, DictRef scenario, DictRef config);
Atom _placement_label_for_scenario(State &state, DictRef scenario, Atom placement_id);
Atom _terrain_label(State &state, Atom terrain_id);
Atom _objective_marker(State &state, bool is_victory, bool met);

} // namespace aurelion::rules::port::scenario_rules

namespace aurelion::rules::port::enemy_turn_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// enemy_rules_panels.cpp.
Atom describe_threats(State &state, DictRef session);
ArrayRef _visible_raids_for_faction(State &state, DictRef session, Atom faction_id);
Atom _public_posture_label(State &state, DictRef enemy_state, int64_t raid_threshold, Atom faction_id);
Atom _capital_watch_summary(State &state, DictRef capital_state);

} // namespace aurelion::rules::port::enemy_turn_rules

namespace aurelion::rules::port::enemy_adventure_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// enemy_rules_panels.cpp.
int64_t recovering_commander_count(State &state, DictRef session, Atom faction_id, const Value &roster_value);
int64_t rebuilding_commander_count(State &state, DictRef session, Atom faction_id, const Value &roster_value);
Atom public_commander_recovery_summary(State &state, DictRef session, Atom faction_id, const Value &roster_value);
Atom public_commander_rebuild_summary(State &state, DictRef session, Atom faction_id, const Value &roster_value);
ArrayRef raid_commander_summaries(State &state, ArrayRef encounters, int64_t limit = 2);
Atom public_strategy_summary(State &state, DictRef config, Atom faction_id);

} // namespace aurelion::rules::port::enemy_adventure_rules

namespace aurelion::rules::port::artifact_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// artifact_rules_panels.cpp.
Atom describe_management(State &state, DictRef hero_state);
Atom describe_bonus_summary(State &state, DictRef hero_state);
Atom describe_set_bonus_summary(State &state, DictRef hero_state);
Atom describe_impact_summary(State &state, DictRef hero_state);
Atom describe_collection_summary(State &state, DictRef hero_state);
Atom artifact_icon_path(State &state, Atom artifact_id);
Atom artifact_type_label(State &state, Atom artifact_id);
Atom describe_artifact_inspection(State &state, DictRef hero_state, Atom artifact_id, bool collected = false, Atom collected_by_faction_id = state::key::empty);

} // namespace aurelion::rules::port::artifact_rules

namespace aurelion::rules::port::spell_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// spell_rules_panels.cpp.
Atom spell_id_for_action(State &state, Atom action_id);
Atom describe_spellbook(State &state, DictRef hero_state, Atom context_filter = state::key::empty);
Atom describe_overworld_spellbook(State &state, DictRef hero_state, DictRef movement_state);
Atom describe_overworld_spell_rail(State &state, DictRef hero_state, DictRef movement_state);
Atom _overworld_spell_readability_line(State &state, DictRef hero_state, DictRef movement_state, DictRef spell, DictRef validation, int64_t mana_cost);

} // namespace aurelion::rules::port::spell_rules

namespace aurelion::rules::port::hero_command_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// hero_rules_panels.cpp.
Atom town_garrison_holder_id(State &state, DictRef session, DictRef town);
Atom describe_town_defense_force(State &state, DictRef session, DictRef town);
ArrayRef empty_owned_towns(State &state, DictRef session);
Atom describe_tavern(State &state, DictRef session, DictRef town);
Atom describe_town_transfer(State &state, DictRef session, DictRef town);
Atom describe_field_rendezvous(State &state, DictRef session);
ArrayRef hero_positions(State &state, DictRef session);

} // namespace aurelion::rules::port::hero_command_rules

namespace aurelion::rules::port::hero_progression_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// hero_rules_panels.cpp.
Atom describe_specialties(State &state, DictRef hero_state);
Atom specialty_id_for_action(State &state, Atom action_id);
Atom specialty_insignia_description(State &state, Atom specialty_id);

} // namespace aurelion::rules::port::hero_progression_rules

namespace aurelion::rules::port::mine_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// map_view_rules.cpp.
Atom asset_id(State &state, DictRef node);
ArrayRef body_tiles(State &state, DictRef node);

} // namespace aurelion::rules::port::mine_rules

namespace aurelion::rules::port::water_travel_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// map_view_rules.cpp.
ArrayRef free_boats(State &state, const Value &session, int64_t level);

} // namespace aurelion::rules::port::water_travel_rules

namespace aurelion::rules::port::town_biome_art_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// map_view_rules.cpp.
DictRef resolve(State &state, Atom base_asset_id, Atom terrain, DictRef skins);

} // namespace aurelion::rules::port::town_biome_art_rules

namespace aurelion::rules::port::overworld_gain_feed {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// map_view_rules.cpp.
DictRef snapshot(State &state, const Value &session);
ArrayRef gains(State &state, DictRef before, DictRef after, int64_t movement_walked = 0);
ArrayRef _resource_order(State &state, DictRef before, DictRef after);

} // namespace aurelion::rules::port::overworld_gain_feed

namespace aurelion::rules::port::town_building_panel {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// town_panel_boards.cpp.
Atom market_building_id(State &state, DictRef town);
Atom guild_building_id(State &state, DictRef town);

} // namespace aurelion::rules::port::town_building_panel

namespace aurelion::rules::port::town_construction_board {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// town_panel_boards.cpp.
DictRef slot_by_id(State &state, DictRef board, Atom slot_id);
ArrayRef ordered_slots(State &state, DictRef board);

} // namespace aurelion::rules::port::town_construction_board
