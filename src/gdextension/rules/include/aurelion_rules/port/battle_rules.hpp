#pragma once

// scripts/core/BattleRules.gd, ported function by function under the GDScript
// names (docs/native-rules-engine-transition.md, Phase 1). Layer 1: hex
// geometry and board reads. Layer 2: the damage chain, the stat totals and
// what they read. Layers 3 and 4: movement and targeting, turn order and
// effects.
//
// Not ported, with the reason:
// - begin_board_read_scope, end_board_read_scope, _board_read_cache_get,
//   _board_read_cache_key: the board-read memo. It is transparent, so the
//   native reads go without it; the shadow checks prove it.
// - BattleActionPlayback.capture, the playback frames of a presented action:
//   slice 10. It does nothing on a battle without the capture key; on one with
//   it, the native callers (_set_stack_hex, _mark_stack_animation_event) stop
//   with an error.
// - _presentation_queue_written: the memo of _append_presentation_event.
//   Normalizing a normalized queue gives the same queue, so the native call
//   normalizes all of it.
// - _hero_payload_cache: the payload memo of _hero_payload_for_side. It is
//   transparent (the payload depends only on the side's payload and commander
//   state, which it compares), so the native call computes the payload.

#include "aurelion_rules/port/gd.hpp"

#include <cstdint>

namespace aurelion::rules::port::battle_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using state::State;
using state::Value;

constexpr int64_t BATTLE_HEX_COLUMNS = 11;
constexpr int64_t BATTLE_HEX_ROWS = 9;

DictRef get_active_stack(State &state, DictRef battle);
int64_t _alive_count(const State &state, DictRef stack);
int64_t _alive_stack_count_for_side(State &state, DictRef battle, Atom side);
ArrayRef _alive_stacks_for_side(State &state, DictRef battle, Atom side);
DictRef _build_blocking_map(State &state, DictRef battle);
DictRef _build_occupancy_map(State &state, DictRef battle);
int64_t _distance_band_from_hex_distance(int64_t hex_distance);
DictRef _get_stack_by_id(State &state, DictRef battle, Atom battle_id);
double _health_ratio(const State &state, DictRef stack);
DictRef _hex_cell(State &state, int64_t q, int64_t r);
int64_t _hex_distance(State &state, DictRef lhs, DictRef rhs);
bool _hex_in_bounds(int64_t q, int64_t r);
Atom _hex_key(State &state, DictRef cell);
Atom _hex_key_from_coords(State &state, int64_t q, int64_t r);
Atom _hex_label(State &state, DictRef cell);
ArrayRef _hex_neighbors(State &state, DictRef cell);
// The PackedByteArray of BATTLE_HEX_COLUMNS * BATTLE_HEX_ROWS bytes, into open.
void _hex_open_mask(State &state, DictRef stack, DictRef occupied, uint8_t *open);
int64_t _hex_tail_step(const State &state, DictRef stack);
DictRef _normalize_hex_cell(State &state, const Value &value);
DictRef _obstacle_cell_map(State &state, DictRef battle);
DictRef _offset_to_cube(State &state, int64_t q, int64_t r);
Atom _opposing_side(Atom side);
int64_t _projected_min_opposing_hex_distance(State &state, DictRef battle, DictRef stack, DictRef destination);
ArrayRef _reachable_empty_hexes(State &state, DictRef battle, DictRef stack, int64_t max_steps);
Atom _side_label(Atom side);
DictRef _stack_hex(State &state, DictRef stack);
int64_t _stack_hex_distance(State &state, DictRef lhs, DictRef rhs);
bool _stack_is_engaged(State &state, DictRef stack, DictRef battle);
Atom _stack_label(const State &state, DictRef stack);
void _sync_distance_from_hexes(State &state, DictRef battle);
void _sync_occupied_hexes(State &state, DictRef battle);
DictRef _walk_steps_to_target(State &state, DictRef battle, DictRef stack, DictRef target, int64_t gap);
void _walk_open_mask(State &state, DictRef battle, DictRef stack, uint8_t *open);


// Layer 2.

// The commander payload: a side's hero payload, its specialty bonuses and
// difficulty terms (commander_payload.cpp).
bool _hero_has_trait(State &state, DictRef battle, Atom side, Atom trait_id);
Value _hero_battle_traits(State &state, DictRef battle, Atom side);
DictRef _hero_payload_for_side(State &state, DictRef battle, Atom side);
DictRef _side_payload_with_commander_fallback(State &state, const Value &existing_payload_value, const Value &commander_state_value, Atom side);
bool _has_battle_trait(State &state, const Value &traits, Atom trait_id);
DictRef _enemy_hero_payload_from_state(State &state, DictRef hero_state, const Value &existing_payload, const Value &session);
DictRef _hero_payload_from_state(State &state, DictRef hero_state, DictRef bonuses, const Value &session, Atom side);
DictRef _merge_spell_school_resistance(State &state, const Value &left, const Value &right);
ArrayRef _normalized_battle_traits(State &state, const Value &value);

// The effect reads of a stack, the town assault effects and the damage rules'
// multipliers (spell_effects.cpp).
int64_t _side_positive_effect_count(State &state, DictRef battle, Atom side);
bool _stack_has_positive_effect(State &state, DictRef stack, DictRef battle);

// Abilities, battle tags, traits and the side counts the bonuses read
// (ability_helpers.cpp).
bool _stack_is_isolated(State &state, DictRef battle, DictRef stack);
bool _stack_is_hex_isolated(State &state, DictRef battle, DictRef stack);
bool _side_has_role_mix(State &state, DictRef battle, Atom side);
int64_t _enemy_wounded_count(State &state, DictRef battle, Atom side);
DictRef _side_resonance_relay(State &state, DictRef battle, Atom side);
DictRef _charter_retaliation_aura_context(State &state, DictRef stack, DictRef battle);
double _side_max_ability_float(State &state, DictRef battle, Atom side, Atom ability_id, Atom key, double default_value);
bool _side_ability_bool(State &state, DictRef battle, Atom side, Atom ability_id, Atom key, bool default_value);
DictRef _normalize_ability_modifiers(State &state, const Value &value);
bool _battle_has_any_tags(State &state, DictRef battle, ArrayRef tags);
DictRef _ability_by_id(State &state, DictRef stack, Atom ability_id);
int64_t _side_max_ability_int(State &state, DictRef battle, Atom side, Atom ability_id, Atom key);
int64_t _allied_melee_count(State &state, DictRef battle, Atom side);
bool _battle_has_tag(State &state, DictRef battle, Atom tag);
ArrayRef _side_ability_payloads(State &state, DictRef battle, Atom side, Atom ability_id);
DictRef _authored_ability_by_id(State &state, DictRef stack, Atom ability_id);
bool _brace_available(State &state, DictRef stack, DictRef battle);
bool _brace_has_held_objective(State &state, DictRef stack, DictRef battle, DictRef brace);
DictRef _bramble_ground_ability(State &state, DictRef stack);
bool _bramble_ground_available(State &state, DictRef stack, DictRef battle, DictRef ability);
DictRef _counter_ambush_flare_context(State &state, DictRef battle, DictRef protected_stack, Atom ambush_ability_id);
DictRef _fog_screen_ability(State &state, DictRef stack);
bool _fog_screen_available(State &state, DictRef stack, DictRef battle, DictRef ability);
bool _has_ability(State &state, DictRef stack, Atom ability_id);
bool _hookline_available(State &state, DictRef stack, DictRef battle);
bool _reach_available(State &state, DictRef stack, DictRef battle);
int64_t _side_defending_count(State &state, DictRef battle, Atom side);
int64_t _side_max_authored_ability_int(State &state, DictRef battle, Atom side, Atom ability_id, Atom key);
bool _volley_has_protected_lane(State &state, DictRef stack, DictRef battle, DictRef volley);
bool _side_has_ability(State &state, DictRef battle, Atom side, Atom ability_id);
bool _stack_is_anchor_side(State &state, DictRef stack, DictRef battle);
bool _stack_is_assault_side(State &state, DictRef stack, DictRef battle);
bool _side_has_linked_unit(State &state, DictRef battle, Atom side, const Value &unit_ids);
Atom _capital_front_anchor_side(State &state, DictRef battle);
Atom _capital_front_assault_side(State &state, DictRef battle);
bool _is_town_defense_context(State &state, const Value &context);

// The stat totals and their contextual, cohesion, momentum, faction and
// field-objective bonuses (stat_totals.cpp).
int64_t _stack_attack_total(State &state, DictRef stack, DictRef battle);
int64_t _stack_defense_total(State &state, DictRef stack, DictRef battle);
int64_t _stack_initiative_total(State &state, DictRef stack, DictRef battle);
int64_t _stack_cohesion_total(State &state, DictRef stack, DictRef battle);
int64_t _stack_momentum_total(State &state, DictRef stack, DictRef battle);
DictRef _highest_momentum_stack_for_side(State &state, DictRef battle, Atom side);
int64_t _reserve_wave_ready_round(State &state, DictRef battle, Atom side);
bool _reserve_wave_is_active_for_side(State &state, DictRef battle, Atom side);
Atom _field_objective_label(State &state, DictRef objective);
int64_t _cohesion_attack_bonus(int64_t cohesion);
int64_t _contextual_attack_bonus(State &state, DictRef stack, DictRef battle);
int64_t _momentum_attack_bonus(int64_t momentum);
int64_t _cohesion_defense_bonus(int64_t cohesion);
int64_t _contextual_defense_bonus(State &state, DictRef stack, DictRef battle);
int64_t _cohesion_initiative_bonus(int64_t cohesion);
int64_t _contextual_initiative_bonus(State &state, DictRef stack, DictRef battle);
int64_t _faction_initiative_bonus(State &state, DictRef stack, DictRef battle);
int64_t _field_objective_initiative_bonus(State &state, DictRef stack, DictRef battle);
int64_t _momentum_initiative_bonus(int64_t momentum);
int64_t _contextual_cohesion_bonus(State &state, DictRef stack, DictRef battle);
int64_t _contextual_momentum_bonus(State &state, DictRef stack, DictRef battle);
bool _side_controls_field_objective_type(State &state, DictRef battle, Atom side, Atom objective_type);
int64_t _field_objective_attack_bonus(State &state, DictRef stack, DictRef battle);
int64_t _field_objective_defense_bonus(State &state, DictRef stack, DictRef battle);
ArrayRef _field_objectives(State &state, DictRef battle);
int64_t _field_objective_cohesion_bonus(State &state, DictRef stack, DictRef battle);
int64_t _field_objective_momentum_bonus(State &state, DictRef stack, DictRef battle);

// The damage multiplier chain (damage_modifiers.cpp).
int64_t _damage_for_roll(State &state, DictRef attacker, DictRef defender, DictRef battle, int64_t base_roll, bool is_ranged, bool is_retaliation, int64_t attack_distance);
double _damage_modifier(State &state, DictRef attacker, DictRef defender, DictRef battle, bool is_ranged, bool is_retaliation, int64_t attack_distance);
double _ranged_damage_return_ratio(State &state, DictRef stack);
double _ability_damage_modifier(State &state, DictRef attacker, DictRef defender, DictRef battle, bool is_ranged, bool is_retaliation, int64_t attack_distance);
double _cohesion_damage_modifier(State &state, DictRef attacker, DictRef defender, DictRef battle, bool is_ranged, bool is_retaliation);
double _commander_damage_modifier(State &state, DictRef attacker, DictRef defender, DictRef battle, bool is_ranged, int64_t attack_distance);
double _faction_damage_modifier(State &state, DictRef attacker, DictRef defender, DictRef battle, bool is_ranged, int64_t attack_distance);
double _field_objective_cover_damage_modifier(State &state, DictRef attacker, DictRef defender, DictRef battle, bool is_ranged, int64_t attack_distance);
double _terrain_tag_damage_modifier(State &state, DictRef attacker, DictRef defender, DictRef battle, bool is_ranged, int64_t attack_distance);
double _linked_ranged_attack_screen_multiplier(State &state, DictRef defender, DictRef battle);
double _solar_array_lane_melee_multiplier(State &state, DictRef defender, DictRef battle);
double _field_objective_commander_modifier(State &state, DictRef attacker, DictRef defender, DictRef battle);
bool _stack_is_cover_screened(State &state, DictRef stack, DictRef battle);

// The damage stream, damage application and the event log (damage_stream.cpp).
int64_t _calculate_damage(State &state, DictRef attacker, DictRef defender, DictRef battle, const Value &rng, bool is_ranged, bool is_retaliation, int64_t attack_distance);
void _apply_damage_to_stack(State &state, DictRef battle, Atom battle_id, int64_t damage);
int64_t _restore_stack_health(State &state, DictRef battle, Atom battle_id, int64_t amount);
int64_t _resolved_damage_seed(State &state, const Value &session, DictRef battle);
void _ensure_damage_rng_state(State &state, const Value &session, DictRef battle);
Value _damage_rng_for_battle(State &state, const Value &session);
void _commit_damage_rng_roll(State &state, DictRef battle, const Value &rng);
Atom _damage_rng_integrity(State &state, int64_t seed, Atom state_text, int64_t roll_count);
void _record_event(State &state, DictRef battle, Atom message);
void _initialize_damage_rng_state(State &state, const Value &session, DictRef battle);
ArrayRef _normalize_recent_events(State &state, const Value &value);

// Layers 3 and 4.

// The board setup: deployment hexes, the hex state of a battle, moving a stack
// and its walk path (board_setup.cpp).
void _ensure_battle_hex_state(State &state, DictRef battle);
DictRef _default_stack_hex(State &state, Atom side, int64_t index, int64_t stack_count, DictRef stack);
int64_t _deployment_column(State &state, Atom side, DictRef stack);
ArrayRef _formation_rows(State &state, int64_t stack_count);
DictRef _first_open_body_near(State &state, DictRef stack, DictRef preferred, DictRef used);
DictRef _hex_board_descriptor(State &state);
void _set_stack_hex(State &state, DictRef battle, Atom battle_id, DictRef cell);
ArrayRef _presentation_walk_path(State &state, DictRef battle, DictRef start, DictRef destination);
int64_t _stack_movement_points(State &state, DictRef stack, DictRef battle);
bool _stack_is_rooted(State &state, DictRef stack, DictRef battle);

// Movement: legal destinations, melee approaches, the advance terms and attack
// legality (movement.cpp).
ArrayRef legal_destinations_for_active_stack(State &state, DictRef battle);
ArrayRef legal_destinations_for_stack(State &state, DictRef battle, Atom battle_id);
DictRef melee_approach_destination(State &state, DictRef battle, DictRef stack, DictRef target);
ArrayRef melee_approach_cells(State &state, DictRef battle, DictRef stack, DictRef target);
DictRef _melee_approach_entry(State &state, DictRef stack, DictRef target, DictRef cell, int64_t steps);
DictRef _matching_melee_approach(State &state, DictRef battle, DictRef stack, DictRef target, DictRef approach);
bool extra_speed_reaches_strike(State &state, DictRef battle, DictRef stack, int64_t extra);
int64_t _advance_desired_gap(State &state, DictRef stack, DictRef battle);
bool _advance_stalled_by_obstruction(State &state, DictRef stack, DictRef battle);
int64_t _advance_lateral_penalty(State &state, DictRef stack, DictRef destination);
bool _stack_can_breach_obstruction(State &state, DictRef stack, DictRef battle);
int64_t _advance_distance_delta(State &state, DictRef stack, DictRef battle);
void _clear_post_move_transition_result_fields(State &state, DictRef result);
bool _can_melee_this_action(State &state, DictRef stack, DictRef battle, DictRef target);
DictRef _attack_legality_for_target(State &state, DictRef active_stack, DictRef target, DictRef battle);
bool _can_make_ranged_attack(State &state, DictRef stack, DictRef battle, DictRef target);
int64_t _attack_distance_for_action(State &state, DictRef attacker, DictRef target, DictRef battle, bool is_ranged);
bool _can_make_melee_attack(State &state, DictRef stack, DictRef battle, DictRef target);

// Target selection: legal targets, the selected target and its click,
// continuity and closing contexts (target_selection.cpp).
ArrayRef legal_attack_targets_for_active_stack(State &state, DictRef battle, bool ranged);
DictRef selected_target_legality(State &state, DictRef battle);
DictRef selected_target_board_click_intent(State &state, DictRef battle);
DictRef selected_target_continuity_context(State &state, DictRef battle);
DictRef selected_target_closing_context(State &state, DictRef battle, bool clear_stale);
DictRef board_click_attack_intent_for_target(State &state, DictRef battle, Atom battle_id);
Atom _player_input_locked_summary(State &state);
void _clear_selected_target_continuity(State &state, DictRef battle);
void _clear_selected_target_closing(State &state, DictRef battle);
bool _clear_stale_selected_target_closing(State &state, DictRef battle, bool clear_attackable);
bool _selected_target_closing_is_stale(State &state, DictRef battle, bool clear_attackable);
void _set_selected_target(State &state, DictRef battle, Atom target_id, bool explicit_retarget);
bool _selected_target_can_remain_for_active_stack(State &state, DictRef battle, DictRef active_stack, Atom target_id);
void _assign_default_target(State &state, DictRef battle);
DictRef _preferred_default_target_for_active_stack(State &state, DictRef battle, DictRef active_stack, ArrayRef targets);
ArrayRef _legal_attack_target_ids_for_active_stack(State &state, DictRef battle);
ArrayRef _legal_attack_target_ids_for_active_stack_uncached(State &state, DictRef battle);
DictRef get_selected_target(State &state, DictRef battle);
DictRef select_target(State &state, const Value &session, Atom battle_id);

// Turn order: rounds, the turn order and its sort, waiting and the action
// availability (turn_order.cpp).
void _prepare_round(State &state, DictRef battle, int64_t round_number);
ArrayRef _sorted_turn_order(State &state, DictRef battle);
bool _compare_stack_order_keys(State &state, DictRef lhs, DictRef rhs);
bool _compare_waiting_order_keys(State &state, DictRef lhs, DictRef rhs);
Atom _advance_to_next_alive(State &state, DictRef battle, int64_t start_index);
void advance_turn(State &state, DictRef battle);
void _resort_remaining_turn_order(State &state, DictRef battle);
ArrayRef _ordered_remaining_actors(State &state, DictRef battle, ArrayRef battle_ids, const Value &waited_override);
ArrayRef waited_stack_ids(State &state, DictRef battle);
bool stack_has_waited(State &state, DictRef battle, Atom battle_id);
bool can_wait(State &state, DictRef battle);
void _apply_wait(State &state, DictRef battle);
int64_t _opposing_stacks_still_to_act(State &state, DictRef battle, DictRef stack);
int64_t _stacks_ahead_after_wait(State &state, DictRef battle, Atom battle_id);
Atom _resolve_wait(State &state, DictRef battle, DictRef active_stack);
bool _battle_retreat_allowed(State &state, DictRef battle);
bool _battle_surrender_allowed(State &state, DictRef battle);
DictRef action_availability(State &state, DictRef battle);

// Stack effects: applying, spending, expiring and cleansing effects, defending
// and the readiness writ (stack_effects.cpp).
DictRef _apply_stack_effect(State &state, DictRef battle, Atom battle_id, const Value &effect_payload);
void spend_effect_turns(State &state, DictRef battle, Atom battle_id);
int64_t _expired_stack_effect_count(State &state, DictRef stack, int64_t round_number);
int64_t _cleanse_stack_effects(State &state, DictRef battle, Atom battle_id, const Value &effect_ids);
void _set_stack_defending(State &state, DictRef battle, Atom battle_id);
DictRef _consume_readiness_writ_preparation(State &state, DictRef battle, Atom battle_id, Atom incoming_effect_id);
DictRef _readiness_writ_ability(State &state, DictRef stack);
DictRef _weakest_stack_by_cohesion(State &state, DictRef battle, Atom side);
DictRef _weakest_stack_by_role(State &state, DictRef battle, Atom side, bool prefer_ranged);

// Round effects: foundry repair, town healing, pressure shifts, cohesion and
// momentum (round_effects.cpp).
int64_t _apply_foundry_aura_round_repair(State &state, DictRef battle);
void _apply_round_pressure_shifts(State &state, DictRef battle);
void _adjust_stack_cohesion(State &state, DictRef battle, Atom battle_id, int64_t amount);
void _adjust_stack_momentum(State &state, DictRef battle, Atom battle_id, int64_t amount);
void _apply_field_objective_round_effects(State &state, DictRef battle);

// Presentation: the animation states and events and the presentation event
// queue (presentation.cpp).
void _mark_stack_animation_event(State &state, DictRef battle, Atom battle_id, Atom event_id, DictRef context);
void _append_animation_event_record(State &state, DictRef battle, DictRef record);
void _append_presentation_event(State &state, DictRef battle, Atom event_type, Atom visible_text, DictRef context);
ArrayRef _normalize_presentation_event_queue(State &state, const Value &value);
ArrayRef _normalize_animation_event_queue(State &state, const Value &value);

} // namespace aurelion::rules::port::battle_rules
