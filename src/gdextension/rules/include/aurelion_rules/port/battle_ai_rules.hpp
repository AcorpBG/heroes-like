#pragma once

// scripts/core/BattleAiRules.gd, ported function by function under the
// GDScript names. Layer 1: the AI's own copies of the hex geometry and board
// reads. Where a copy's body is BattleRules' word for word, it calls the
// BattleRules port.
//
// The scoring memos of one AI decision (_open_scoring_scope) are GDScript's
// static vars (_scoring_scope_depth, _scoring_living, _scoring_stack_terms and
// the rest), read and written through the host as the GDScript does:
// _alive_stacks_for_side, _stack_contact_band, _stack_is_engaged,
// _can_make_melee_attack and _allied_status_synergy_score keep their entries
// inside a scoring scope.
//
// Slice 08: the AI's estimates, the side's scoring payload with them (it
// reaches SpellRules.ensure_hero_spellbook). Slice 09: the decisions, with
// the weights (_w). Not ported: _battle_rules, a Script (the ports call the
// BattleRules ports), and GDScript's board-read scope, which the native board
// reads do not need.

#include "aurelion_rules/port/gd.hpp"

#include <cstdint>

namespace aurelion::rules::port::battle_ai_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using state::State;
using state::Value;

int64_t _alive_count(const State &state, DictRef stack);
ArrayRef _alive_stacks_for_side(State &state, DictRef battle, Atom side);
int64_t _distance_band_from_hex_distance(int64_t hex_distance);
double _health_ratio(const State &state, DictRef stack);
DictRef _hex_cell(State &state, int64_t q, int64_t r);
bool _hex_in_bounds(int64_t q, int64_t r);
bool _is_same_stack(const State &state, DictRef lhs, DictRef rhs);
ArrayRef _living_stacks_of_side(State &state, const Value &stacks, Atom side);
DictRef _normalize_hex_cell(State &state, const Value &value);
Atom _opposing_side(Atom side);
ArrayRef _projected_on_cell(State &state, DictRef battle, DictRef stack, DictRef cell);
DictRef _stack_by_battle_id(State &state, DictRef battle, Atom battle_id);
int64_t _stack_contact_band(State &state, DictRef stack, DictRef battle);
int64_t _stack_contact_band_on(State &state, DictRef stack, DictRef battle);
bool _stack_engaged_on(State &state, DictRef stack, DictRef battle);
DictRef _stack_hex(State &state, DictRef stack);
int64_t _stack_hex_distance(State &state, DictRef lhs, DictRef rhs);
bool _stack_is_engaged(State &state, DictRef stack, DictRef battle);

// Slice 08: the scoring scope of one AI decision and its memos.
void _open_scoring_scope(State &state);
void _close_scoring_scope(State &state);
void _clear_scoring_memos(State &state);
ArrayRef _scoring_memo_entry(State &state, DictRef entries_by_key, Atom key, DictRef first, DictRef second);
void _add_scoring_memo_entry(State &state, DictRef entries_by_key, Atom key, ArrayRef entry);
ArrayRef _stack_term_memo(State &state, Atom term, DictRef stack, DictRef battle);
void _keep_stack_term(State &state, ArrayRef entry, const Value &value);
ArrayRef _scoring_living_entry(State &state, DictRef battle, Atom side);


// Layer 2: the faction tags and the commander payload merge.

// The commander payload: a side's hero payload, its specialty bonuses and
// difficulty terms (commander_payload.cpp).
DictRef _merged_commander_ai_payload(State &state, DictRef primary_payload, DictRef secondary_payload);
bool _commander_payloads_can_merge(State &state, DictRef primary_payload, DictRef secondary_payload);
DictRef _merge_commander_spellbooks_for_ai(State &state, DictRef merged, DictRef secondary_payload);
ArrayRef _normalize_string_array(State &state, const Value &value);
ArrayRef _commander_identity_tokens(State &state, DictRef payload);
bool _commander_identity_tokens_match(State &state, Atom left_token, Atom right_token);

// Abilities, battle tags, traits and the side counts the bonuses read
// (ability_helpers.cpp).
bool faction_brings_tag(State &state, DictRef stack, Atom tag);
ArrayRef faction_brought_tags(State &state, DictRef stack);

// Layer 5: the AI's own copies of the ability checks and the helpers they use
// (battle_ai_abilities.cpp).
DictRef _ability_by_id(State &state, DictRef stack, Atom ability_id);
DictRef _authored_ability_by_id(State &state, DictRef stack, Atom ability_id);
bool _has_ability(State &state, DictRef stack, Atom ability_id);
bool _battle_has_tag(State &state, DictRef battle, Atom tag);
ArrayRef _field_objectives(State &state, DictRef battle);
bool _side_controls_field_objective_type(State &state, DictRef battle, Atom side, Atom objective_type);
bool _brace_available(State &state, DictRef stack, DictRef battle);
DictRef _bramble_ground_ability(State &state, DictRef stack);
bool _bramble_ground_available(State &state, DictRef stack, DictRef battle, DictRef ability);
DictRef _fog_screen_ability(State &state, DictRef stack);
bool _fog_screen_available(State &state, DictRef stack, DictRef battle, DictRef ability);
bool _hookline_available(State &state, DictRef stack, DictRef battle);
bool _reach_available(State &state, DictRef stack, DictRef battle);
bool _can_make_retaliation(State &state, DictRef stack, int64_t attack_distance, DictRef battle);
DictRef _readiness_writ_ability(State &state, DictRef stack);
int64_t _readiness_writ_effect_count(State &state, DictRef stack, DictRef battle, DictRef ability);
DictRef _pressure_artillery_secondary_target(State &state, DictRef battle, DictRef attacker, DictRef primary_target);
int64_t _pressure_artillery_secondary_damage(State &state, DictRef attacker);
bool _harry_support_ready(State &state, DictRef attacker, DictRef target, DictRef battle, DictRef ability);
DictRef _counter_ambush_flare_context(State &state, DictRef battle, DictRef protected_stack, Atom ambush_ability_id);

// Slice 08: the AI's copies of the damage modifiers, the field objectives'
// bonuses and the side reads they use (battle_ai_modifiers.cpp).
double _ability_damage_modifier(State &state, DictRef attacker, DictRef defender, DictRef battle, bool is_ranged, bool is_retaliation, int64_t attack_distance);
double _faction_damage_modifier(State &state, DictRef attacker, DictRef defender, DictRef battle, bool is_ranged, int64_t attack_distance);
double _terrain_tag_damage_modifier(State &state, DictRef attacker, DictRef defender, DictRef battle, bool is_ranged, int64_t attack_distance);
double _solar_array_lane_melee_multiplier(State &state, DictRef defender, DictRef battle);
bool _side_has_linked_unit(State &state, DictRef battle, Atom side, const Value &unit_ids);
double _linked_ranged_attack_screen_multiplier(State &state, DictRef defender, DictRef battle);
DictRef _charter_retaliation_aura_context(State &state, DictRef stack, DictRef battle);
double _side_max_ability_float(State &state, DictRef battle, Atom side, Atom ability_id, Atom key, double default_value);
double _side_max_authored_ability_float(State &state, DictRef battle, Atom side, Atom ability_id, Atom key, double default_value);
bool _side_ability_bool(State &state, DictRef battle, Atom side, Atom ability_id, Atom key, bool default_value);
bool _side_has_ability(State &state, DictRef battle, Atom side, Atom ability_id);
int64_t _side_defending_count(State &state, DictRef battle, Atom side);
bool _brace_has_held_objective(State &state, DictRef stack, DictRef battle, DictRef brace);
bool _volley_has_protected_lane(State &state, DictRef stack, DictRef battle, DictRef volley);
bool _battle_has_any_tags(State &state, DictRef battle, ArrayRef tags);
Atom _capital_front_anchor_side(State &state, DictRef battle);
Atom _capital_front_assault_side(State &state, DictRef battle);
bool _stack_is_anchor_side(State &state, DictRef stack, DictRef battle);
bool _stack_is_assault_side(State &state, DictRef stack, DictRef battle);
int64_t _allied_ranged_count(State &state, DictRef battle, Atom side);
int64_t _allied_melee_count(State &state, DictRef battle, Atom side);
bool _stack_is_isolated(State &state, DictRef battle, DictRef stack);
bool _stack_is_hex_isolated(State &state, DictRef battle, DictRef stack);
bool _side_has_role_mix(State &state, DictRef battle, Atom side);
int64_t _enemy_wounded_count(State &state, DictRef battle, Atom side);
Atom _side_faction_id(State &state, DictRef battle, Atom side);
bool _stack_has_positive_effect(State &state, DictRef stack, DictRef battle);
int64_t _side_positive_effect_count(State &state, DictRef battle, Atom side);
int64_t _field_objective_attack_bonus(State &state, DictRef stack, DictRef battle);
int64_t _field_objective_defense_bonus(State &state, DictRef stack, DictRef battle);
int64_t _field_objective_cohesion_bonus(State &state, DictRef stack, DictRef battle);
int64_t _field_objective_momentum_bonus(State &state, DictRef stack, DictRef battle);
double _field_objective_commander_modifier(State &state, DictRef attacker, DictRef defender, DictRef battle);
bool _stack_is_cover_screened(State &state, DictRef stack, DictRef battle);
double _field_objective_cover_damage_modifier(State &state, DictRef attacker, DictRef defender, DictRef battle, bool is_ranged, int64_t attack_distance);
int64_t _field_objective_action_influence(State &state, DictRef objective, DictRef battle, Atom acting_side, Atom action, DictRef acting_stack, DictRef target_stack);
int64_t _reserve_wave_ready_round(State &state, DictRef battle, Atom side);
bool _reserve_wave_is_active_for_side(State &state, DictRef battle, Atom side);
bool _commander_spell_cast_this_round(State &state, DictRef battle, Atom side);

// Slice 08: the AI's reads: reach and attack distance, health, the advance,
// the commander and the spell estimates (battle_ai_reads.cpp).
bool _can_make_melee_attack(State &state, DictRef stack, DictRef battle, DictRef target);
bool _can_make_ranged_attack(State &state, DictRef stack, DictRef battle, DictRef target);
bool _can_make_any_ranged_attack(State &state, DictRef stack, DictRef battle, ArrayRef targets);
int64_t _attack_distance_for_action(State &state, DictRef attacker, DictRef target, DictRef battle, bool is_ranged);
bool _fights_in_melee(State &state, DictRef stack);
bool should_wait_for_contact(State &state, DictRef battle, DictRef active_stack, bool can_wait, int64_t opposing_stacks_still_to_act);
bool _should_close_distance(State &state, DictRef active_stack);
int64_t _clock_pressure(State &state, DictRef battle);
double _side_ranged_power(State &state, DictRef battle, Atom side);
DictRef advance_target(State &state, DictRef battle, DictRef stack);
DictRef best_advance_destination(State &state, DictRef battle, DictRef stack, DictRef preferred_target, int64_t desired_gap);
double _average_unit_damage(State &state, DictRef stack);
double _creature_average_damage(State &state, DictRef stack);
double _creature_threat_weight(State &state, DictRef battle, DictRef target);
int64_t _stack_missing_health(State &state, DictRef stack);
int64_t _battle_recovery_amount(State &state, DictRef hero_state, DictRef spell);
int64_t _side_current_health(State &state, DictRef battle, Atom side);
int64_t _side_base_health(State &state, DictRef battle, Atom side);
double _side_health_ratio(State &state, DictRef battle, Atom side);
bool _has_hostile_ranged_pressure(State &state, ArrayRef targets);
bool _must_force_engaged_attack(State &state, DictRef active_stack, DictRef battle, ArrayRef targets, DictRef best_attack);
bool _should_press_decisive_attack(State &state, DictRef battle, DictRef active_stack, DictRef best_attack, double defend_score);
bool _candidate_beats(State &state, DictRef candidate, DictRef current_best);
DictRef _enemy_hero_state_for_ai(State &state, DictRef battle, DictRef enemy_hero);
DictRef _commander_template_for_ai_payload(State &state, DictRef commander_payload);
DictRef _commander_template_for_spell_role(State &state, DictRef enemy_hero);
DictRef _side_commander_state_for_ai(State &state, DictRef battle, Atom side, DictRef commander_payload);
Atom _side_commander_payload_source(State &state, DictRef battle, Atom side, DictRef commander_payload);
double _commander_spell_role_modifier(State &state, DictRef enemy_hero, DictRef behavior);
bool _candidate_is_lethal_damage_spell(State &state, DictRef candidate, DictRef battle, DictRef enemy_hero);
bool _damage_candidate_is_lethal(State &state, DictRef candidate, DictRef battle, DictRef enemy_hero, DictRef target, DictRef projection);
bool _allied_spell_candidate_suppressed_by_active_buff(State &state, Atom effect_type, DictRef ally, DictRef battle, DictRef spell);
bool _spell_buff_already_active(State &state, DictRef active_stack, DictRef battle, DictRef spell);
bool _stack_has_control_effect(State &state, DictRef stack, DictRef battle);
bool _stack_is_rooted(State &state, DictRef stack, DictRef battle);
DictRef _status_effect_from_spell(State &state, DictRef spell);
double _status_tactical_value(State &state, Atom status_id, DictRef target);
double _buff_spell_offense_payoff(State &state, DictRef stack);
double _stack_spell_target_value(State &state, DictRef stack, DictRef battle);
double _allied_status_synergy_score(State &state, DictRef battle, Atom side, Atom status_id);
double _allied_status_synergy_on(State &state, DictRef battle, Atom side, Atom status_id);

// Slice 08b: the side's scoring payload, the commander's traits and bonuses,
// and the enemy's withdrawal (battle_ai_payloads.cpp).
DictRef _battle_with_enemy_hero_payload(State &state, DictRef battle, DictRef enemy_hero);
DictRef _battle_with_side_hero_payload(State &state, DictRef battle, Atom side, DictRef commander_payload);
DictRef _commander_payload_for_tactical_scoring(State &state, DictRef commander_payload);
DictRef _enemy_withdrawal_action(State &state, DictRef battle, DictRef active_stack, ArrayRef targets, DictRef current_best);
double _preservation_comparison_score(State &state, DictRef battle, DictRef active_stack, DictRef current_best, double best_score);
double _enemy_withdrawal_urgency_scale(State &state, DictRef battle);
int64_t _hero_bonus_for_side(State &state, DictRef battle, Atom side, Atom kind);
double _damage_multiplier_for_side(State &state, DictRef battle, Atom side);
DictRef _hero_payload_for_side(State &state, DictRef battle, Atom side);
ArrayRef _scoring_payload_entry(State &state, DictRef battle, Atom side);
DictRef _side_hero_payload(State &state, DictRef battle, Atom side);
DictRef _side_payload_with_commander_fallback(State &state, const Value &existing_payload_value, const Value &commander_state_value);
bool _hero_has_trait(State &state, DictRef battle, Atom side, Atom trait_id);

// Slice 08b: the contextual bonuses, the cohesion and momentum totals, the
// breach of an obstruction and the readiness writ (battle_ai_contextual.cpp).
bool _stack_can_breach_obstruction(State &state, DictRef stack, DictRef battle);
int64_t _advance_distance_delta(State &state, DictRef stack, DictRef battle);
int64_t _contextual_attack_bonus(State &state, DictRef stack, DictRef battle);
int64_t _contextual_attack_bonus_on(State &state, DictRef stack, DictRef battle);
int64_t _contextual_defense_bonus(State &state, DictRef stack, DictRef battle);
int64_t _contextual_defense_bonus_on(State &state, DictRef stack, DictRef battle);
int64_t _stack_cohesion_total(State &state, DictRef stack, DictRef battle);
int64_t _stack_momentum_total(State &state, DictRef stack, DictRef battle);
int64_t _stack_cohesion_sum(State &state, DictRef stack, DictRef battle);
int64_t _stack_momentum_sum(State &state, DictRef stack, DictRef battle);
int64_t _contextual_cohesion_bonus(State &state, DictRef stack, DictRef battle);
int64_t _contextual_momentum_bonus(State &state, DictRef stack, DictRef battle);
DictRef _readiness_writ_target(State &state, DictRef battle, DictRef source, DictRef ability);
bool _readiness_writ_available(State &state, DictRef source, DictRef battle, DictRef ability);

// Slice 08b: the damage estimate and its modifiers, the threat to a stack and
// the lethal attack (battle_ai_estimates.cpp).
int64_t _estimate_damage(State &state, DictRef attacker, DictRef defender, DictRef battle, bool is_ranged, bool is_retaliation, int64_t attack_distance);
int64_t _estimate_damage_on(State &state, DictRef attacker, DictRef defender, DictRef battle, bool is_ranged, bool is_retaliation, int64_t attack_distance);
double _cohesion_damage_modifier(State &state, DictRef attacker, DictRef defender, DictRef battle, bool is_ranged, bool is_retaliation);
double _commander_damage_modifier(State &state, DictRef attacker, DictRef defender, DictRef battle, bool is_ranged, int64_t attack_distance);
double _target_threat_on(State &state, DictRef defended_stack, DictRef target, DictRef battle);
double _target_immediate_threat_score(State &state, DictRef defended_stack, DictRef target, DictRef battle);
bool _candidate_is_lethal_attack(State &state, DictRef candidate, DictRef battle, DictRef active_stack);
bool _support_spell_has_active_pressure(State &state, DictRef battle, DictRef active_stack, DictRef target_stack, ArrayRef hostile_targets);

// Slice 08b: the field objectives' worth and the support spells' scores
// (battle_ai_spell_scores.cpp).
double _objective_action_score(State &state, DictRef battle, Atom acting_side, Atom action, DictRef acting_stack, DictRef target_stack);
double _field_objective_value(State &state, DictRef objective, DictRef battle, Atom acting_side, Atom action, DictRef acting_stack, DictRef target_stack);
double _recovery_spell_score_for_target(State &state, DictRef enemy_hero, DictRef battle, DictRef active_stack, DictRef target_stack, DictRef spell);
double _cleanse_spell_score_for_target(State &state, DictRef battle, DictRef active_stack, DictRef target_stack, DictRef spell);
double _spell_metadata_value_modifier(State &state, DictRef battle, DictRef active_stack, DictRef target, DictRef spell, DictRef behavior);
double _buff_spell_score(State &state, DictRef battle, DictRef active_stack, DictRef target_stack, ArrayRef targets, DictRef spell);

// Slice 09: the weights, the attack, defend and advance scores, and the melee
// approach (battle_ai_attack_scores.cpp).
double _w(State &state, Atom key);
double _attack_score(State &state, DictRef attacker, DictRef target, DictRef battle, bool is_ranged);
double _attack_score_on(State &state, DictRef attacker, DictRef target, DictRef battle, bool is_ranged);
DictRef _strike_candidate(State &state, DictRef battle, DictRef active_stack, DictRef target);
DictRef _best_attack_action(State &state, DictRef battle, DictRef active_stack, ArrayRef targets);
double _defend_score(State &state, DictRef battle, DictRef active_stack, ArrayRef targets);
double _advance_score(State &state, DictRef battle, DictRef active_stack, ArrayRef targets);
bool _should_hold_line(State &state, DictRef battle, DictRef stack);
double _melee_approach_score(State &state, DictRef battle, DictRef stack, DictRef target, DictRef cell);
DictRef _melee_approach_choice(State &state, DictRef battle, DictRef stack, DictRef target, ArrayRef cells);
DictRef choose_melee_approach(State &state, DictRef battle, DictRef stack, DictRef target, ArrayRef cells);

// Slice 09: the commander's spell choice and whether a cast is worth its
// mana (battle_ai_spell_choice.cpp).
double _damage_spell_score(State &state, DictRef enemy_hero, DictRef battle, DictRef active_stack, DictRef target, DictRef spell, DictRef damage_projection);
double _spell_candidate_score(State &state, DictRef enemy_hero, DictRef battle, DictRef active_stack, DictRef target, DictRef spell, DictRef behavior, ArrayRef hostiles, double role_modifier, DictRef damage_projection);
double _control_spell_score(State &state, DictRef battle, DictRef active_stack, DictRef target, DictRef spell);
ArrayRef _battle_spell_candidates(State &state, DictRef battle, DictRef active_stack, DictRef enemy_hero, ArrayRef targets, ArrayRef lethal_flags);
DictRef _best_spell_action(State &state, DictRef battle, DictRef active_stack, DictRef enemy_hero, ArrayRef targets);
bool _hero_cast_worthwhile(State &state, DictRef best_spell, DictRef best_attack, DictRef battle, DictRef active_stack, ArrayRef hostile_targets, DictRef commander_payload, bool lethal_spell_available, bool lethal_attack_available, bool support_needs_pressure);
double _shared_tactical_spell_conservation_delta(State &state, DictRef battle, DictRef active_stack, DictRef target_stack, ArrayRef hostile_targets, DictRef commander_payload, DictRef behavior, bool support_needs_pressure);

// Slice 09: the decisions, an enemy stack's action, a stack's tactical order,
// the advance plan and the reachable strike (battle_ai_decisions.cpp).
DictRef choose_enemy_action(State &state, DictRef battle, DictRef active_stack, DictRef enemy_hero, bool allow_hero_cast);
DictRef _enemy_action_choice(State &state, DictRef battle, DictRef active_stack, DictRef enemy_hero, bool allow_hero_cast);
DictRef _stack_order_choice(State &state, DictRef scoring_battle, DictRef active_stack, ArrayRef targets);
DictRef best_reachable_strike(State &state, DictRef battle, DictRef active_stack);
DictRef _best_reachable_strike(State &state, DictRef battle, DictRef active_stack);
DictRef advance_plan(State &state, DictRef battle, DictRef stack);
DictRef _advance_plan(State &state, DictRef battle, DictRef stack);
DictRef choose_stack_tactical_order(State &state, DictRef battle, DictRef active_stack, Atom target_side, DictRef commander_payload, bool allow_hero_cast);
DictRef _stack_tactical_order(State &state, DictRef battle, DictRef active_stack, Atom target_side, DictRef commander_payload, bool allow_hero_cast);

} // namespace aurelion::rules::port::battle_ai_rules
