#pragma once

// scripts/core/BattleRules.gd, ported function by function under the GDScript
// names (docs/native-rules-engine-transition.md, Phase 1). Layer 1: hex
// geometry and board reads. Layer 2: the damage chain, the stat totals and
// what they read. Layers 3 and 4: movement and targeting, turn order and
// effects. Layer 5: the attack and ability effects, damage pressure and the
// attack events. Layers 6 and 7: the pressure of an advance and a defend, the
// melee approach and the town assault check. Layer 8: a spell's battle events.
// Layer 9: the AI's orders carried out. Layer 10: the fight: the player's
// orders and moves, the enemy's turn, the attacks and casts, the end of an
// action and the outcome. Layer 11 (Phase 5): the battle ends.
//
// _hero_payload_cache and _presentation_queue_written are GDScript's static
// vars, read and written through the host (gd::static_var) as the GDScript
// reads and writes them, so they keep its lifetime. A ported function that
// reaches one is a writing function. The board reads keep their answers in a
// native memo instead (board_read_key); GDScript's board-read memo
// (_board_read_scope_*, _board_read_cache_hits,
// _validation_board_read_cache_disabled) is GDScript's own, and the validating
// check refuses a native read of it. _hex_id_by_key is left out: it maps the
// board's 99 "q,r" keys to fixed hex ids, built once, and the native code reads
// the same ids off the State's fixed atoms.
//
// Not ported, with the reason:
// - begin_board_read_scope and end_board_read_scope: they open GDScript's
//   board-read memo, which the native board reads do not use.

#include "aurelion_rules/port/gd.hpp"

#include <cstdint>
#include <string>

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

// The board reads' native memo (slice 04c, State::memo_find), in place of
// GDScript's board-read memo (begin_board_read_scope, _board_read_scope_cache),
// which stays GDScript's own: the native port neither reads nor fills it. A
// board read is kept by the battle and the stacks it was asked about, as nodes,
// while nothing it read changes, so it needs no scope, no hash of the stacks
// and no copies; GDScript's memo returns the same answers inside its scope.
enum class BoardRead : uint64_t {
	destinations = 1,
	approach,
	legality,
	attack_target_ids,
	walk_steps,
	walk_open_mask,
};
inline State::MemoKey board_read_key(BoardRead kind, DictRef battle, uint64_t first, uint64_t second = 0, int64_t number = 0) {
	return { static_cast<uint64_t>(kind) << 32 | battle, first << 32 | second, static_cast<uint64_t>(number) };
}


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
bool _is_town_assault_context(State &state, const Value &context);
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

// Layer 5.

// Attack effects: the attack and retaliation ability effects, the hookline
// pull, the counter-ambush flare, strike-backs and the retaliations and shots
// an attack spends (attack_effects.cpp).
ArrayRef _apply_attack_ability_effects(State &state, DictRef battle, DictRef attacker, DictRef defender, bool is_ranged, int64_t attack_distance, DictRef defender_before);
ArrayRef _apply_retaliation_ability_effects(State &state, DictRef battle, DictRef retaliator, DictRef attacker);
DictRef _status_effect_from_ability(State &state, DictRef ability, DictRef battle);
bool _apply_hookline_pull(State &state, DictRef battle, DictRef attacker, DictRef defender);
Atom _append_counter_ambush_flare_event(State &state, DictRef battle, DictRef flare_context, DictRef ambusher, Atom blocked_ability_id, Atom blocked_ability_name);
DictRef stack_strike_backs(State &state, DictRef battle, DictRef stack);
bool _can_make_retaliation(State &state, DictRef stack, int64_t attack_distance, DictRef battle);
void _consume_retaliation(State &state, DictRef battle, Atom battle_id);
void _consume_shot(State &state, DictRef battle, Atom battle_id);

// Unit abilities: pressure artillery, the readiness writ, mending fire, the
// harry support and the lowest-health pick (unit_abilities.cpp).
ArrayRef _apply_pressure_artillery(State &state, DictRef battle, DictRef attacker, DictRef primary_target);
DictRef _pressure_artillery_secondary_target(State &state, DictRef battle, DictRef attacker, DictRef primary_target);
int64_t _pressure_artillery_secondary_damage(State &state, DictRef attacker);
DictRef _apply_readiness_writ(State &state, DictRef battle, DictRef attacker);
bool _readiness_writ_available(State &state, DictRef source, DictRef battle, DictRef ability);
int64_t _readiness_writ_effect_count(State &state, DictRef stack, DictRef battle, DictRef ability);
DictRef _readiness_writ_target(State &state, DictRef battle, DictRef source, DictRef ability);
DictRef _readiness_writ_preparation_target(State &state, DictRef battle, DictRef source, DictRef ability);
DictRef _apply_sporeglass_mending_fire(State &state, DictRef battle, DictRef attacker);
DictRef _sporeglass_mend_target(State &state, DictRef battle, Atom side);
bool _harry_support_ready(State &state, DictRef attacker, DictRef target, DictRef battle, DictRef ability);
DictRef _lowest_health_stack(State &state, ArrayRef stacks);

// Damage pressure: the cohesion and momentum shifts of a hit, the shock of a
// destroyed stack, the field objectives' action pressure and control push and
// the ranged damage return (damage_pressure.cpp).
ArrayRef _apply_damage_pressure(State &state, DictRef battle, DictRef attacker, DictRef target_before, DictRef target_after, bool is_ranged, Atom source_type);
void _apply_destroyed_stack_shock(State &state, DictRef battle, DictRef destroyed_stack, Atom attacking_side);
int64_t _attack_momentum_gain(State &state, DictRef attacker, DictRef target_before, DictRef target_after, DictRef battle, bool is_ranged, Atom source_type);
int64_t _casualty_cohesion_shift(State &state, DictRef target_before, DictRef target_after);
int64_t _supportive_cohesion_gain(State &state, DictRef attacker, DictRef battle, bool is_ranged);
int64_t _field_objective_action_influence(State &state, DictRef objective, DictRef battle, Atom acting_side, DictRef action_context, DictRef acting_stack, DictRef target_stack);
ArrayRef _apply_field_objective_action_pressure(State &state, DictRef battle, DictRef action_context);
Atom _apply_field_objective_control_push(State &state, DictRef objective, DictRef battle, Atom acting_side, int64_t amount);
Atom _field_objective_flip_message(State &state, DictRef objective, Atom previous_controller, Atom new_controller);
ArrayRef _apply_ranged_damage_return(State &state, DictRef battle, Atom attacker_battle_id, DictRef defender_before, bool is_ranged, Atom source_type);

// Attack events: the post-attack target context, the damage and text
// presentation events, the damage target animation and the message joins
// (attack_events.cpp).
DictRef _attach_post_attack_target_context(State &state, DictRef result, const Value &session, Atom action_id, DictRef target_before, DictRef target_after_before_outcome);
void _append_damage_presentation_event(State &state, DictRef battle, Atom event_type, DictRef attacker, DictRef target_before, DictRef target_after, int64_t damage, Atom action_id, DictRef extra_context);
void _append_text_presentation_event(State &state, DictRef battle, Atom event_type, ArrayRef texts, DictRef actor, DictRef target, Atom action_id);
void _append_nonempty_message(State &state, ArrayRef messages, Atom message);
Atom _join_messages(State &state, ArrayRef parts);
void _mark_damage_target_animation(State &state, DictRef battle, Atom battle_id, bool had_status_effect, Atom source_battle_id, DictRef extra_context, DictRef target_before);

// Layers 6 and 7.

// Action pressure: the cohesion and momentum of an advance and a defend, and
// the melee approach (action_pressure.cpp).
Atom _apply_advance_pressure(State &state, DictRef battle, Atom battle_id);
Atom _apply_defend_pressure(State &state, DictRef battle, Atom battle_id);
void _apply_melee_approach(State &state, DictRef battle, DictRef stack, DictRef destination);

// Layer 8.

// Spell events: the commander's cast of the round, the casting hero, the
// commit of a resistance roll, and the cast's animation states and
// presentation events (spell_events.cpp).
DictRef _player_commander_state(State &state, const Value &session);
DictRef _player_spell_resolution(State &state, const Value &session, Atom spell_id, Atom target_id);
DictRef _normalize_commander_spell_cast_rounds(State &state, const Value &value);
bool _commander_spell_cast_this_round(State &state, DictRef battle, Atom side);
void _mark_commander_spell_cast(State &state, DictRef battle, Atom side);
Atom hero_actor_id(State &state, Atom side);
Atom commander_name(State &state, DictRef battle, Atom side);
DictRef _hero_caster(State &state, DictRef battle, Atom side);
void _commit_spell_resistance_roll(State &state, DictRef battle, DictRef resolution);
void _mark_spell_animation_states(State &state, DictRef battle, DictRef caster_stack, DictRef resolution);
void _append_spell_presentation_events(State &state, DictRef battle, DictRef caster_stack, DictRef resolution, DictRef target_before, DictRef target_after, int64_t recovered_amount, int64_t cleansed_count, Atom action_id);
void _append_spell_status_resolution_event(State &state, DictRef battle, DictRef resolution, DictRef base_context, Atom target_name, Atom prefix);
void _append_spell_effect_event(State &state, DictRef battle, Atom event_type, const Value &effect_payload, DictRef base_context, Atom target_name);
Atom _spell_effect_label(State &state, const Value &effect_payload);

// Layer 9: the AI's orders carried out (enemy_orders.cpp).
DictRef ai_melee_approach(State &state, DictRef battle, DictRef stack, DictRef target);
DictRef ai_advance_plan(State &state, DictRef battle, DictRef stack);
bool _apply_auto_advance_movement(State &state, DictRef battle, DictRef active_stack);

// Layer 10: the player's orders, the attack they resolve, the end of an
// action and the outcome (player_orders.cpp).
DictRef resolve_if_battle_ready(State &state, const Value &session);
DictRef cast_player_spell(State &state, const Value &session, Atom spell_id, Atom target_id);
DictRef perform_player_action(State &state, const Value &session, Atom action, DictRef approach);
DictRef _resolve_attack_action(State &state, const Value &session, DictRef attacker, DictRef target, bool is_ranged);
DictRef _complete_action(State &state, const Value &session, Atom initial_message, bool turn_spent);
DictRef _evaluate_outcome(State &state, const Value &session);
void _clear_stack_animation_states(State &state, DictRef battle);

// Layer 10: the player's move order (move_orders.cpp).
DictRef movement_intent_for_destination(State &state, DictRef battle, int64_t q, int64_t r, const Value &preloaded_legal_destinations);
DictRef _legal_destination_from_preloaded(State &state, ArrayRef destinations, int64_t q, int64_t r);
DictRef _movement_intent_skeleton(State &state, DictRef battle, DictRef active_stack, DictRef destination);
Atom _step_count_label(State &state, int64_t steps);
Atom _movement_destination_phrase(State &state, DictRef destination);
DictRef _movement_target_setup_for_destination(State &state, DictRef battle, DictRef active_stack, DictRef destination, DictRef current_legality);
Atom _movement_intent_message(State &state, DictRef battle, DictRef active_stack, DictRef destination, int64_t destination_count);
DictRef move_active_stack_to_hex(State &state, const Value &session, int64_t q, int64_t r);
DictRef _legal_destination_for_stack(State &state, DictRef battle, DictRef stack, DictRef destination);
DictRef _resolve_move_action(State &state, const Value &session, DictRef active_stack, DictRef destination, Atom verb, DictRef movement_intent);
DictRef _attach_movement_intent_to_result(State &state, DictRef result, DictRef movement_intent);
DictRef _attach_post_move_target_context(State &state, DictRef result, DictRef battle);
bool _apply_setup_move_target_continuity(State &state, DictRef battle, DictRef movement_intent, DictRef result);
bool _apply_ordinary_closing_target_context(State &state, DictRef battle, DictRef movement_intent, DictRef result);

// Layer 10: the enemy's turn: the drain, an enemy stack's order and its end
// (enemy_turn.cpp).
DictRef _run_enemy_turn(State &state, const Value &session, DictRef active_stack);
DictRef _run_enemy_stack_order(State &state, const Value &session, DictRef active_stack, DictRef action);
DictRef _resolve_enemy_defend(State &state, const Value &session, DictRef active_stack);
DictRef _cast_enemy_spell(State &state, const Value &session, DictRef active_stack, DictRef action);
DictRef _resolve_ai_attack(State &state, const Value &session, DictRef attacker, DictRef target, bool is_ranged);
DictRef _drain_enemy_turns(State &state, const Value &session);
DictRef _complete_enemy_action(State &state, const Value &session, Atom message);
DictRef _resolve_enemy_wait(State &state, const Value &session, DictRef active_stack);
void _mark_side_animation_event(State &state, DictRef battle, Atom side, Atom event_id);

// Layer 10b: the battle screen's consequence previews: an attack's, an
// advance's and a spell's, and the damage and loss ranges they print
// (consequence_previews.cpp).
DictRef attack_consequence_preview(State &state, DictRef battle, Atom action, Atom target_id, DictRef approach);
Atom _no_retaliation_reason(State &state, DictRef defender, DictRef battle, bool ranged, int64_t distance, bool always_destroyed);
ArrayRef _attack_forecast_lines(State &state, DictRef preview, DictRef target);
Atom forecast_text(State &state, ArrayRef lines);
Atom _range_text(State &state, int64_t low, int64_t high);
Atom consequence_range_text(State &state, DictRef value);
DictRef advance_consequence_preview(State &state, DictRef battle);
DictRef spell_consequence_preview(State &state, const Value &session, Atom spell_id, Atom target_id);
DictRef _damage_range_preview(State &state, DictRef attacker, DictRef defender, DictRef battle, bool is_ranged, bool is_retaliation, int64_t attack_distance);
DictRef _unit_loss_range(State &state, DictRef defender, int64_t min_damage, int64_t max_damage);

// Layer 10b: the turn order forecast (turn_forecast.cpp).
ArrayRef upcoming_actor_ids(State &state, DictRef battle, int64_t limit);
DictRef turn_order_forecast(State &state, DictRef battle);
ArrayRef _projected_next_round_order(State &state, DictRef battle, ArrayRef still_to_act);

// Layer 11 (Phase 5 slice 09): the battle ends. They take the session as the
// battle does and hand the overworld rules its view (gd::object_view), so both
// read and write the same fields. Arguments GDScript defaults are passed.

// The ends: victory, defeat, retreat, surrender, an enemy's withdrawal and a
// stalemate, and the encounter they resolve (battle_finalize.cpp).
DictRef _finalize_victory(State &state, const Value &session);
DictRef _finalize_player_battle_loss(State &state, const Value &session);
DictRef _finalize_primary_defeat(State &state, const Value &session, Atom base_summary, Atom outcome_id);
DictRef _finalize_secondary_hero_defeat(State &state, const Value &session);
DictRef _finalize_town_defense_loss(State &state, const Value &session);
DictRef _finalize_retreat(State &state, const Value &session);
DictRef _finalize_surrender(State &state, const Value &session);
DictRef _finalize_enemy_withdrawal(State &state, const Value &session, Atom outcome_id);
DictRef _finalize_stalemate(State &state, const Value &session);
Atom _retreat_action_summary(State &state, const Value &session);
Atom _surrender_action_summary(State &state, const Value &session);
DictRef _battle_victory_rewards(State &state, const Value &session, DictRef encounter);
ArrayRef _beaten_enemy_stacks(State &state, DictRef battle);
DictRef _battle_resolution_static_encounter_snapshot(State &state, const Value &session);
void _apply_encounter_victory_flags(State &state, const Value &session, DictRef encounter);
void _mark_resolved_encounter(State &state, const Value &session, Atom resolved_key);
DictRef _find_encounter_by_key(State &state, const Value &session, Atom encounter_key);
DictRef _current_battle_encounter_placement(State &state, const Value &session);
DictRef _synthetic_battle_encounter_placement(State &state, const Value &session, const Value &context);
DictRef _battle_exit_animation_snapshot(State &state, DictRef battle, Atom outcome);
DictRef _normalize_stack_animation_states(State &state, const Value &value);
Atom _normalize_presentation_speed(State &state, Atom speed);

// The aftermath report, the casualties, and the withdrawal and collapse
// previews (battle_aftermath.cpp).
void _record_battle_aftermath(State &state, const Value &session, Atom outcome, Atom summary, DictRef details);
Atom _battle_aftermath_display_outcome(State &state, Atom outcome, DictRef details);
Atom _battle_aftermath_result_summary(State &state, Atom summary);
Atom _battle_aftermath_reward_summary(State &state, DictRef details);
Atom _battle_aftermath_artifact_summary(State &state, DictRef details);
Atom _battle_aftermath_force_summary(State &state, const Value &session);
Atom _battle_aftermath_side_force_clause(State &state, DictRef battle, Atom side, Atom label);
Atom _battle_aftermath_world_summary(State &state, const Value &session, Atom outcome, DictRef details);
Atom _battle_aftermath_return_summary(State &state, DictRef report);
DictRef _battle_report_casualty_ledger(State &state, DictRef battle);
DictRef _battle_report_side_casualties(State &state, DictRef battle, Atom side);
Atom _titleize_token(State &state, Atom value);
DictRef _army_totals(State &state, DictRef battle, Atom side);
DictRef _build_withdrawal_aftermath_preview(State &state, const Value &session, Atom outcome);
DictRef _build_collapse_aftermath_preview(State &state, const Value &session, Atom outcome);
Atom _withdrawal_preview_summary(State &state, DictRef preview, Atom outcome);
Atom _withdrawal_resource_summary(State &state, Atom outcome, DictRef resource_loss, Atom enemy_label);
Atom _collapse_resource_summary(State &state, Atom outcome, DictRef resource_loss, Atom enemy_label);
DictRef _clamped_resource_loss(State &state, const Value &session, DictRef desired_loss);
int64_t _casualty_units_from_ratio(int64_t total_units, double ratio);
int64_t _remove_units_from_stacks(State &state, ArrayRef stacks, int64_t unit_losses);
int64_t _stack_count_total(State &state, const Value &stacks);
int64_t _army_strength_from_stacks(State &state, const Value &stacks);

// The forces and commanders after a battle: survivors, recovery, mana,
// salvage, experience, losses and the enemy commander's record
// (battle_forces.cpp).
void _sync_player_force_from_battle(State &state, const Value &session);
void _sync_enemy_force_from_battle(State &state, const Value &session, bool encounter_resolved);
ArrayRef _battle_survivor_stacks(State &state, const Value &session, Atom side, DictRef filters);
int64_t _apply_victory_recovery(State &state, DictRef battle, Atom side);
int64_t _apply_victory_mana(State &state, DictRef commander_state, DictRef battle, Atom side);
DictRef _apply_player_battle_salvage_reward(State &state, const Value &session);
ArrayRef _award_commander_experience(State &state, const Value &session, int64_t amount);
Atom _apply_active_hero_aftermath_losses(State &state, const Value &session, int64_t unit_losses, Atom outcome);
void _set_player_hero_state(State &state, const Value &session, DictRef hero_state, Atom hero_id);
DictRef _remove_hero_by_id_after_defeat(State &state, const Value &session, Atom hero_id);
DictRef _enemy_commander_state_for_force_sync(State &state, const Value &session);
DictRef _enemy_commander_state_with_payload(State &state, const Value &session, DictRef commander_state);
DictRef _apply_enemy_commander_battle_memory(State &state, const Value &session, DictRef commander_state);
Atom _resolve_enemy_commander_aftermath(State &state, const Value &session, Atom outcome_id);
void _record_enemy_commander_battle_continuity(State &state, const Value &session, Atom outcome_id);
DictRef _enemy_commander_rivalry_context(State &state, const Value &session, DictRef encounter);
Atom _enemy_commander_exit_reaction(State &state, const Value &session, Atom outcome_id);
void _finish_enemy_battle_task_assignment(State &state, const Value &session, Atom task_status, Atom validation);

// The battle's context afterwards: the town, site or route it was fought for,
// the fronts and the enemy's pressure, treasury and siege
// (battle_context_aftermath.cpp).
Atom _apply_battle_context_victory(State &state, const Value &session);
Atom _apply_battle_context_stalemate(State &state, const Value &session);
Atom _battle_context_controller_id(State &state, const Value &session, DictRef context, const Value &raw_context);
Atom _battle_context_resource_placement_id(State &state, DictRef context, const Value &raw_context);
Atom _battle_context_town_placement_id(State &state, const Value &session, DictRef context, const Value &raw_context);
Atom _battle_context_trigger_faction_id(State &state, const Value &session, DictRef context, const Value &raw_context, DictRef town);
bool _is_resource_assault_context(State &state, const Value &context);
Atom _battle_enemy_faction_id(State &state, const Value &session);
Atom _battle_enemy_label(State &state, const Value &session, Atom faction_id);
Atom _side_faction_id(State &state, DictRef battle, Atom side);
bool _enemy_state_exists(State &state, const Value &session, Atom faction_id);
int64_t _adjust_enemy_pressure(State &state, const Value &session, Atom faction_id, int64_t delta);
void _add_enemy_treasury_resources(State &state, const Value &session, Atom faction_id, DictRef delta);
void _set_enemy_siege_progress(State &state, const Value &session, Atom faction_id, int64_t progress);
Atom _apply_front_pressure_shift(State &state, const Value &session, Atom faction_id, int64_t delta, Atom outcome);
DictRef _apply_victory_front_aftermath(State &state, const Value &session);
DictRef _apply_collapse_aftermath(State &state, const Value &session, Atom outcome);
DictRef _apply_withdrawal_aftermath(State &state, const Value &session, Atom outcome);
Atom _apply_collapse_recovery_pressure(State &state, const Value &session, Atom town_placement_id, int64_t pressure, Atom outcome);
Atom _apply_withdrawal_recovery_pressure(State &state, const Value &session, Atom town_placement_id, int64_t pressure, Atom outcome);
Atom _apply_town_assault_recovery(State &state, const Value &session, Atom outcome);
Atom _apply_town_defense_recovery(State &state, const Value &session, Atom outcome);
int64_t _town_assault_recovery_pressure(State &state, const Value &session, Atom outcome);
int64_t _town_defense_recovery_pressure(State &state, const Value &session, Atom outcome);
Atom _apply_delivery_route_aftermath(State &state, const Value &session, Atom outcome);
void _apply_enemy_victory_specialties(State &state, const Value &session);
void _capture_town_after_assault(State &state, const Value &session, Atom town_placement_id, ArrayRef enemy_survivors);
Atom _keep_enemy_hero_after_town_capture(State &state, const Value &session, Atom town_placement_id, ArrayRef enemy_survivors);
Atom _station_enemy_commander_after_town_capture(State &state, const Value &session, Atom town_placement_id, ArrayRef enemy_survivors);
Atom _stabilize_hostile_town_front(State &state, const Value &session, Atom source, int64_t bonus_days);
DictRef _find_town_by_placement(State &state, const Value &session, Atom placement_id);
DictRef _find_town_at_position(State &state, const Value &session, int64_t x, int64_t y, int64_t level);
Atom _town_name(State &state, DictRef town);
Atom _town_name_from_placement_id(State &state, const Value &session, Atom placement_id);

} // namespace aurelion::rules::port::battle_rules
