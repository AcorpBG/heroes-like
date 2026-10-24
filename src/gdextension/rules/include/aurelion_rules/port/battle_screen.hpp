#pragma once

// The battle screen (docs/native-rules-engine-transition.md, Phase 7, slice
// 7.9), ported function by function under the GDScript names: the battle's
// texts, the action surface, forecasts and recaps, the presentation reads
// and the board reads the screen draws. A session is its view
// (session_view.hpp).

#include "aurelion_rules/port/gd.hpp"
#include "aurelion_rules/port/battle_action_playback.hpp"
#include "aurelion_rules/port/battle_rules.hpp"
#include "aurelion_rules/port/overworld_rules_panels.hpp"
#include "aurelion_rules/port/town_battle_rules.hpp"

#include <cstdint>

namespace aurelion::rules::port::battle_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// battle_screen_entry.cpp.
Atom _withdrawal_pressure_label(State &state, DictRef battle, bool allowed);
bool _has_delivery_context(State &state, const Value &context);
DictRef battle_occupancy_map(State &state, DictRef battle);
ArrayRef legal_attack_target_ids_for_active_stack(State &state, DictRef battle);
DictRef active_movement_board_click_intent(State &state, DictRef battle, const Value &preloaded_legal_destinations);
ArrayRef legal_movement_intents_for_active_stack(State &state, DictRef battle, const Value &preloaded_legal_destinations);
DictRef battle_hex_state_summary(State &state, DictRef battle);
ArrayRef target_cycle_ids(State &state, DictRef battle);
void cycle_target(State &state, DictRef session, int64_t direction);
ArrayRef spell_target_ids(State &state, DictRef session, Atom spell_id);
ArrayRef get_spell_actions(State &state, DictRef session);
Atom describe_entry_context(State &state, DictRef session);
Atom _battle_entry_risk_label(State &state, DictRef session, DictRef battle);
Atom _battle_entry_stakes_line(State &state, DictRef session, DictRef battle, DictRef encounter, DictRef scenario);
Atom _battle_entry_reward_line(State &state, DictRef session, DictRef encounter, DictRef battle);
Atom _battle_difficulty_label(State &state, DictRef battle);
Atom _compact_army_total(State &state, DictRef totals);
Atom _player_force_name_from_battle(State &state, DictRef battle);
Atom _enemy_force_name_from_battle(State &state, DictRef battle, DictRef session);
Atom describe_risk_readiness_board(State &state, DictRef session);
Atom describe_tactical_briefing(State &state, DictRef session);
Atom consume_tactical_briefing(State &state, DictRef session);
DictRef active_consequence_payload(State &state, DictRef session);
DictRef post_action_recap_context(State &state, DictRef session, Atom action_id = state::key::empty);
DictRef post_action_recap_payload(State &state, DictRef session, DictRef result, Atom action_id, DictRef context);
Atom describe_target_context(State &state, DictRef session);

// battle_screen_forecast.cpp.
Atom describe_action_surface(State &state, DictRef session);
DictRef action_readiness_confirmation_payload(State &state, DictRef session);
Atom describe_action_readiness_confirmation(State &state, DictRef session);
DictRef intent_forecast_payload(State &state, DictRef session);
Atom _intent_forecast_action_id(State &state, DictRef battle, DictRef surface, ArrayRef spell_actions, DictRef tactical_order, DictRef active_stack);
bool _intent_forecast_tactical_spell_target_is_public(State &state, DictRef battle, DictRef active_stack, DictRef tactical_order);
DictRef _intent_forecast_action(State &state, DictRef surface, ArrayRef spell_actions, Atom action_id);
bool _intent_forecast_action_matches_tactical_order(State &state, Atom action_id, DictRef tactical_order);
Atom _intent_forecast_target_label(State &state, Atom action_id, DictRef active_stack, DictRef target);
Atom _intent_forecast_expected_result(State &state, Atom action_id, DictRef session, DictRef battle, DictRef active_stack, DictRef target, DictRef action);
Atom _intent_forecast_advance_result(State &state, DictRef battle, DictRef active_stack);
Atom _intent_forecast_sentence(State &state, Atom text);
Atom _intent_forecast_compact_result(State &state, Atom text, int64_t max_chars);
Atom _intent_forecast_confidence_line(State &state, DictRef tactical_order, Atom action_id);
Atom _manual_battle_action_cue(State &state, DictRef actions, DictRef click_intent, DictRef movement_intent);
Atom _action_button_label(State &state, DictRef actions, Atom action_id);
Atom _first_ready_action_label(State &state, DictRef actions, ArrayRef action_ids);
DictRef _preferred_spell_timing_action(State &state, DictRef session, DictRef battle, DictRef active_stack, DictRef target);
double _spell_timing_action_score(State &state, DictRef battle, DictRef active_stack, DictRef target, DictRef spell, DictRef availability);

// battle_screen_actions.cpp.
Atom _preferred_player_action_id(State &state, DictRef surface, DictRef active_stack);
Atom _enemy_reply_line(State &state, DictRef session, DictRef battle);
DictRef _next_enemy_reply_stack(State &state, DictRef battle);
Atom _enemy_action_preview_summary(State &state, DictRef battle, DictRef enemy_stack, DictRef action);
Atom _attack_action_summary(State &state, DictRef attacker, DictRef target, DictRef battle, bool is_ranged);
Atom _attack_unavailable_summary(State &state, DictRef attacker, DictRef target, DictRef battle, bool is_ranged);
Atom _target_focus_action_line(State &state, DictRef active_stack, DictRef target, DictRef battle);
Atom _target_legality_line(State &state, DictRef active_stack, DictRef target, DictRef battle);
Atom _advance_action_summary(State &state, DictRef battle, DictRef stack);
Atom _defend_action_summary(State &state, DictRef battle, DictRef stack);
int64_t _preview_advance_momentum_gain(State &state, DictRef stack, DictRef battle);
int64_t _preview_defend_cohesion_gain(State &state, DictRef stack, DictRef battle);
Atom _active_ability_window_summary(State &state, DictRef stack, DictRef battle, DictRef target);

// battle_screen_abilities.cpp.
Atom _active_ability_role_line(State &state, DictRef stack, DictRef battle, DictRef target);
Atom _ability_role_sentence(State &state, DictRef stack, DictRef ability, DictRef battle, DictRef target);
Atom _ability_modifier_text(State &state, DictRef ability);
Atom _status_modifier_label(State &state, Atom key);
Atom _stack_status_pressure_line(State &state, DictRef stack, DictRef battle);
Atom _stack_status_pressure_short(State &state, DictRef stack, DictRef battle);
Atom _effect_modifier_text(State &state, DictRef effect);
Atom _target_range_readiness_line(State &state, DictRef active_stack, DictRef target, DictRef battle);
Atom _field_objective_action_preview(State &state, DictRef battle, DictRef action_context);
DictRef _project_field_objective_state(State &state, DictRef objective, Atom acting_side, int64_t amount);
bool _should_surface_tactical_briefing(State &state, DictRef session);
ArrayRef _tactical_briefing_lines(State &state, DictRef session);
Atom _tactical_battlefield_line(State &state, DictRef session, DictRef battle);
Atom _tactical_objective_line(State &state, DictRef session, DictRef battle, DictRef scenario);
Atom _tactical_field_objective_line(State &state, DictRef battle);
Atom _tactical_enemy_doctrine_line(State &state, DictRef battle);
Atom _tactical_opening_pressure_line(State &state, DictRef session, DictRef battle);
Atom _tactical_decisive_target_line(State &state, DictRef battle);
Atom _tactical_caution_line(State &state, DictRef session, DictRef battle);

// battle_screen_risk.cpp.
Atom _risk_readiness_grade(State &state, DictRef session, DictRef battle);
Atom _risk_board_initiative_line(State &state, DictRef battle);
Atom _risk_board_commander_line(State &state, DictRef battle);
Atom _risk_board_line_integrity_line(State &state, DictRef battle);
Atom _risk_board_ranged_pressure_line(State &state, DictRef battle);
Atom _risk_board_priority_line(State &state, DictRef battle);
Atom _risk_board_objective_line(State &state, DictRef session, DictRef battle);
Atom _risk_board_dispatch_line(State &state, DictRef battle);
ArrayRef _next_activation_window(State &state, DictRef battle, int64_t count);
int64_t _steady_stack_count(State &state, DictRef battle, Atom side);
int64_t _wavering_stack_count(State &state, DictRef battle, Atom side);
double _average_side_cohesion(State &state, DictRef battle, Atom side);
int64_t _side_shots_remaining(State &state, DictRef battle, Atom side);
Atom _risk_board_lane_label(State &state, DictRef battle);
ArrayRef _battlefield_tag_labels(State &state, DictRef battle);
ArrayRef _battle_trait_labels(State &state, ArrayRef traits);
DictRef _encounter_objective_for_battle(State &state, DictRef session, DictRef battle, DictRef scenario);
DictRef _priority_enemy_stack_for_briefing(State &state, DictRef battle);
Atom _priority_target_reason(State &state, DictRef stack, DictRef battle);

// battle_screen_surface.cpp.
DictRef get_action_surface(State &state, DictRef session);
void _enrich_action_surface_entry(State &state, DictRef action, Atom action_id, DictRef session, DictRef battle, DictRef active_stack, DictRef target, DictRef availability);
Atom _compact_action_tooltip(State &state, DictRef action);
Atom _action_confirmation_line(State &state, Atom action_id, DictRef active_stack, DictRef target, DictRef action);
Atom _action_target_label(State &state, Atom action_id, DictRef active_stack, DictRef target, DictRef battle);
Atom _action_range_line(State &state, Atom action_id, DictRef active_stack, DictRef target, DictRef battle);
Atom _action_why_line(State &state, Atom action_id, DictRef session, DictRef battle, DictRef active_stack, DictRef target, bool ready);
Atom _action_consequence_line(State &state, Atom action_id, DictRef session, DictRef battle, DictRef active_stack, DictRef target, DictRef action);
ArrayRef _action_consequence_preview_list(State &state, DictRef surface);
Atom _post_action_happened_line(State &state, DictRef result, Atom action_id);
Atom _post_action_affected_line(State &state, DictRef battle, DictRef result, Atom action_id, DictRef context);
Atom _post_action_stack_delta_line(State &state, DictRef battle, Atom battle_id, Atom fallback_name, int64_t count_before, int64_t health_before);
Atom _post_action_status_after(State &state, DictRef battle, Atom battle_id, Atom fallback_status);
Atom _post_action_decision_line(State &state, DictRef session, DictRef result, DictRef context);
Atom _post_action_next_actor_line(State &state, DictRef session);
Atom _post_action_label(State &state, Atom action_id);
ArrayRef animation_event_queue(State &state, DictRef battle);
ArrayRef battle_presentation_event_stream(State &state, DictRef battle);
Atom battle_presentation_speed(State &state, DictRef session);
DictRef set_battle_presentation_speed(State &state, DictRef session, Atom speed);
int64_t battle_presentation_playback_msec(State &state, DictRef battle);
DictRef latest_animation_event_presentation_payload(State &state, DictRef session);
DictRef perform_presented_action(State &state, DictRef session, Atom action, DictRef destination);
void record_player_order(State &state, DictRef battle, DictRef result);
bool player_has_given_orders(State &state, DictRef battle);
DictRef hero_presentation(State &state, DictRef battle, Atom side);

// battle_screen_details.cpp.
DictRef stack_details(State &state, DictRef battle, Atom battle_id);
bool stack_is_waiting(State &state, DictRef battle, Atom battle_id);
ArrayRef stack_effect_rows(State &state, DictRef stack, DictRef battle);
Atom _effect_modifier_phrase(State &state, DictRef effect);
Atom effect_polarity(State &state, DictRef effect);
DictRef hero_details(State &state, DictRef battle, Atom side);
ArrayRef roster_lines(State &state, DictRef battle, Atom side);
ArrayRef _starting_enemy_stacks(State &state, DictRef battle);
DictRef pending_battle_report(State &state, DictRef session);
bool is_hero_actor_id(State &state, Atom actor_id);
Atom hero_actor_side(State &state, Atom actor_id);
Atom battle_actor_label(State &state, DictRef battle, Atom actor_id);
Atom battle_actor_side(State &state, DictRef battle, Atom actor_id);
DictRef default_deployment_hex(State &state, Atom side, int64_t index, int64_t stack_count, DictRef stack);
ArrayRef battle_obstacles(State &state, DictRef battle);
DictRef battle_obstacle_cells(State &state, DictRef battle);
Atom _damage_preview_text(State &state, DictRef preview);
DictRef _retaliation_range_preview(State &state, DictRef attacker, DictRef defender, DictRef battle, int64_t attack_distance, DictRef attack_preview);
Atom _wait_action_summary(State &state, DictRef battle, DictRef stack);

// battle_screen_context.cpp.
Atom _stack_ability_summary(State &state, DictRef stack);
Atom _battle_context_label(State &state, DictRef session, const Value &context);
Atom _battlefield_identity_summary(State &state, DictRef battle);
Atom _distance_label(State &state, int64_t distance);
DictRef _commander_state_for_side(State &state, DictRef battle, Atom side);
Atom _commander_role_label(State &state, DictRef battle, Atom side);
Atom _pressure_brief(State &state, DictRef session);
Atom _engagement_preview(State &state, DictRef active_stack, DictRef target, DictRef battle);
Atom _stack_focus_summary(State &state, DictRef stack, DictRef battle, bool is_active);
Atom _side_doctrine_summary(State &state, DictRef battle, Atom side);
Atom _field_objective_progress_text(State &state, DictRef objective);
Atom _field_objective_short_status(State &state, DictRef objective);
Atom _field_objective_status_brief(State &state, DictRef battle);
Atom _field_objective_pressure_summary(State &state, DictRef battle);
Atom _field_objective_pressure_brief(State &state, DictRef battle);
Atom _field_objective_urgency_summary(State &state, DictRef session, DictRef battle);
Atom _field_objective_focus_line(State &state, DictRef battle, Atom side, DictRef stack);
Atom _terrain_effect_brief(State &state, DictRef battle);
DictRef _latest_animation_event(State &state, DictRef battle);
Atom _animation_event_action_text(State &state, Atom event_id, Atom actor_label, Atom source_label, Atom target_label, DictRef event);
Atom _stack_summary_line(State &state, DictRef stack, DictRef battle, Atom active_id, Atom selected_id);

} // namespace aurelion::rules::port::battle_rules

namespace aurelion::rules::port::spell_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// battle_screen_details.cpp.
ArrayRef get_battle_actions(State &state, DictRef hero_state, DictRef battle, DictRef active_stack, DictRef target_stack);
Atom _battle_spell_action_summary(State &state, DictRef hero_state, DictRef battle, DictRef active_stack, DictRef target_stack, DictRef spell);

} // namespace aurelion::rules::port::spell_rules

namespace aurelion::rules::port::town_battle_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// battle_screen_details.cpp.
Atom summary(State &state, DictRef battle, DictRef stack);

} // namespace aurelion::rules::port::town_battle_rules

namespace aurelion::rules::port::battle_action_playback {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// battle_screen_details.cpp.
void begin(State &state, DictRef battle);
DictRef finish(State &state, DictRef battle, DictRef result);

} // namespace aurelion::rules::port::battle_action_playback
