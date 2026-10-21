#include "aurelion_rules/port/registry.hpp"

#include "aurelion_rules/port/battle_ai_rules.hpp"
#include "aurelion_rules/port/battle_damage_rules.hpp"
#include "aurelion_rules/port/battle_damage_rules_ai.hpp"
#include "aurelion_rules/port/battle_footprint.hpp"
#include "aurelion_rules/port/battle_rules.hpp"
#include "aurelion_rules/port/difficulty_rules.hpp"
#include "aurelion_rules/port/difficulty_rules_ai.hpp"
#include "aurelion_rules/port/hero_progression_rules.hpp"
#include "aurelion_rules/port/spell_rules.hpp"
#include "aurelion_rules/port/town_battle_rules.hpp"

#include <string>

namespace aurelion::rules::port {

namespace {

using gd::array_value;
using gd::bool_value;
using gd::dict_value;
using gd::float_value;
using gd::int_value;
using gd::str;
using state::Kind;
using state::State;
using state::Value;
namespace br = battle_rules;
namespace ai = battle_ai_rules;
namespace dmg = battle_damage_rules;
namespace diff = difficulty_rules;
namespace fp = battle_footprint;
namespace hero = hero_progression_rules;
namespace spell = spell_rules;
namespace town = town_battle_rules;

// The parameters as GDScript's types left them.
gd::DictRef D(const Value *args, int index) {
	return gd::as_dict(args[index]);
}

gd::ArrayRef A(const Value *args, int index) {
	return gd::as_array(args[index]);
}

int64_t I(const Value *args, int index) {
	if (args[index].kind != Kind::Int) {
		throw state::ScriptError(std::string("Invalid type: expected int, got ") + gd::type_name(args[index]));
	}
	return args[index].i;
}

double F(const Value *args, int index) {
	if (args[index].kind != Kind::Float) {
		throw state::ScriptError(std::string("Invalid type: expected float, got ") + gd::type_name(args[index]));
	}
	return args[index].f;
}

bool B(const Value *args, int index) {
	if (args[index].kind != Kind::Bool) {
		throw state::ScriptError(std::string("Invalid type: expected bool, got ") + gd::type_name(args[index]));
	}
	return args[index].b;
}

gd::Atom S(const Value *args, int index) {
	return gd::to_string(args[index]);
}

Value nil() {
	return Value();
}

// mutates: the function writes into its arguments, or reaches a memo, which
// writes GDScript's static vars (battle_rules.hpp).
#define PORT(script, fn, arity, mutates, body) \
	{ #script "." #fn, arity, mutates, [](State &s, const Value *a) -> Value { (void)s; (void)a; body; } }

const Function kFunctions[] = {
	PORT(BattleAiRules, _ability_by_id, 2, false, return dict_value(ai::_ability_by_id(s, D(a, 0), S(a, 1)))),
	PORT(BattleAiRules, _alive_count, 1, false, return int_value(ai::_alive_count(s, D(a, 0)))),
	PORT(BattleAiRules, _alive_stacks_for_side, 2, true, return array_value(ai::_alive_stacks_for_side(s, D(a, 0), S(a, 1)))),
	PORT(BattleAiRules, _authored_ability_by_id, 2, false, return dict_value(ai::_authored_ability_by_id(s, D(a, 0), S(a, 1)))),
	PORT(BattleAiRules, _battle_has_tag, 2, false, return bool_value(ai::_battle_has_tag(s, D(a, 0), S(a, 1)))),
	PORT(BattleAiRules, _brace_available, 2, false, return bool_value(ai::_brace_available(s, D(a, 0), D(a, 1)))),
	PORT(BattleAiRules, _bramble_ground_ability, 1, false, return dict_value(ai::_bramble_ground_ability(s, D(a, 0)))),
	PORT(BattleAiRules, _bramble_ground_available, 3, false, return bool_value(ai::_bramble_ground_available(s, D(a, 0), D(a, 1), D(a, 2)))),
	PORT(BattleAiRules, _can_make_retaliation, 3, false, return bool_value(ai::_can_make_retaliation(s, D(a, 0), I(a, 1), D(a, 2)))),
	PORT(BattleAiRules, _commander_identity_tokens, 1, false, return array_value(ai::_commander_identity_tokens(s, D(a, 0)))),
	PORT(BattleAiRules, _commander_identity_tokens_match, 2, false, return bool_value(ai::_commander_identity_tokens_match(s, S(a, 0), S(a, 1)))),
	PORT(BattleAiRules, _commander_payloads_can_merge, 2, false, return bool_value(ai::_commander_payloads_can_merge(s, D(a, 0), D(a, 1)))),
	PORT(BattleAiRules, _counter_ambush_flare_context, 3, true, return dict_value(ai::_counter_ambush_flare_context(s, D(a, 0), D(a, 1), S(a, 2)))),
	PORT(BattleAiRules, _distance_band_from_hex_distance, 1, false, return int_value(ai::_distance_band_from_hex_distance(I(a, 0)))),
	PORT(BattleAiRules, _field_objectives, 1, false, return array_value(ai::_field_objectives(s, D(a, 0)))),
	PORT(BattleAiRules, _fog_screen_ability, 1, false, return dict_value(ai::_fog_screen_ability(s, D(a, 0)))),
	PORT(BattleAiRules, _fog_screen_available, 3, false, return bool_value(ai::_fog_screen_available(s, D(a, 0), D(a, 1), D(a, 2)))),
	PORT(BattleAiRules, _harry_support_ready, 4, true, return bool_value(ai::_harry_support_ready(s, D(a, 0), D(a, 1), D(a, 2), D(a, 3)))),
	PORT(BattleAiRules, _has_ability, 2, false, return bool_value(ai::_has_ability(s, D(a, 0), S(a, 1)))),
	PORT(BattleAiRules, _health_ratio, 1, false, return float_value(ai::_health_ratio(s, D(a, 0)))),
	PORT(BattleAiRules, _hex_cell, 2, false, return dict_value(ai::_hex_cell(s, I(a, 0), I(a, 1)))),
	PORT(BattleAiRules, _hex_in_bounds, 2, false, return bool_value(ai::_hex_in_bounds(I(a, 0), I(a, 1)))),
	PORT(BattleAiRules, _hookline_available, 2, false, return bool_value(ai::_hookline_available(s, D(a, 0), D(a, 1)))),
	PORT(BattleAiRules, _is_same_stack, 2, false, return bool_value(ai::_is_same_stack(s, D(a, 0), D(a, 1)))),
	PORT(BattleAiRules, _living_stacks_of_side, 2, false, return array_value(ai::_living_stacks_of_side(s, a[0], S(a, 1)))),
	PORT(BattleAiRules, _merge_commander_spellbooks_for_ai, 2, true, return dict_value(ai::_merge_commander_spellbooks_for_ai(s, D(a, 0), D(a, 1)))),
	PORT(BattleAiRules, _merged_commander_ai_payload, 2, false, return dict_value(ai::_merged_commander_ai_payload(s, D(a, 0), D(a, 1)))),
	PORT(BattleAiRules, _normalize_hex_cell, 1, false, return dict_value(ai::_normalize_hex_cell(s, a[0]))),
	PORT(BattleAiRules, _normalize_string_array, 1, false, return array_value(ai::_normalize_string_array(s, a[0]))),
	PORT(BattleAiRules, _opposing_side, 1, false, return str(ai::_opposing_side(S(a, 0)))),
	PORT(BattleAiRules, _pressure_artillery_secondary_damage, 1, false, return int_value(ai::_pressure_artillery_secondary_damage(s, D(a, 0)))),
	PORT(BattleAiRules, _pressure_artillery_secondary_target, 3, true, return dict_value(ai::_pressure_artillery_secondary_target(s, D(a, 0), D(a, 1), D(a, 2)))),
	PORT(BattleAiRules, _projected_on_cell, 3, false, return array_value(ai::_projected_on_cell(s, D(a, 0), D(a, 1), D(a, 2)))),
	PORT(BattleAiRules, _reach_available, 2, false, return bool_value(ai::_reach_available(s, D(a, 0), D(a, 1)))),
	PORT(BattleAiRules, _readiness_writ_ability, 1, false, return dict_value(ai::_readiness_writ_ability(s, D(a, 0)))),
	PORT(BattleAiRules, _readiness_writ_effect_count, 3, false, return int_value(ai::_readiness_writ_effect_count(s, D(a, 0), D(a, 1), D(a, 2)))),
	PORT(BattleAiRules, _side_controls_field_objective_type, 3, false, return bool_value(ai::_side_controls_field_objective_type(s, D(a, 0), S(a, 1), S(a, 2)))),
	PORT(BattleAiRules, _stack_by_battle_id, 2, false, return dict_value(ai::_stack_by_battle_id(s, D(a, 0), S(a, 1)))),
	PORT(BattleAiRules, _stack_contact_band, 2, true, return int_value(ai::_stack_contact_band(s, D(a, 0), D(a, 1)))),
	PORT(BattleAiRules, _stack_contact_band_on, 2, true, return int_value(ai::_stack_contact_band_on(s, D(a, 0), D(a, 1)))),
	PORT(BattleAiRules, _stack_engaged_on, 2, true, return bool_value(ai::_stack_engaged_on(s, D(a, 0), D(a, 1)))),
	PORT(BattleAiRules, _stack_hex, 1, false, return dict_value(ai::_stack_hex(s, D(a, 0)))),
	PORT(BattleAiRules, _stack_hex_distance, 2, false, return int_value(ai::_stack_hex_distance(s, D(a, 0), D(a, 1)))),
	PORT(BattleAiRules, _stack_is_engaged, 2, true, return bool_value(ai::_stack_is_engaged(s, D(a, 0), D(a, 1)))),
	PORT(BattleAiRules, faction_brings_tag, 2, false, return bool_value(ai::faction_brings_tag(s, D(a, 0), S(a, 1)))),
	PORT(BattleAiRules, faction_brought_tags, 1, false, return array_value(ai::faction_brought_tags(s, D(a, 0)))),
	PORT(BattleDamageRules, attack_defense_multiplier, 2, false, return float_value(dmg::attack_defense_multiplier(s, I(a, 0), I(a, 1)))),
	PORT(BattleDamageRules, hero_damage_multiplier, 5, false, return float_value(dmg::hero_damage_multiplier(s, D(a, 0), D(a, 1), B(a, 2), B(a, 3), B(a, 4)))),
	PORT(BattleDamageRules, town_assault_side, 1, false, return str(dmg::town_assault_side(s, D(a, 0)))),
	PORT(BattleFootprint, cells, 2, false, return array_value(fp::cells(s, D(a, 0), dict_value(D(a, 1))))),
	PORT(BattleFootprint, distance, 3, false, return int_value(fp::distance(s, D(a, 0), D(a, 1), dict_value(D(a, 2))))),
	PORT(BattleFootprint, fits, 5, false, return bool_value(fp::fits(s, D(a, 0), dict_value(D(a, 1)), D(a, 2), I(a, 3), I(a, 4)))),
	PORT(BattleFootprint, placed_columns, 1, false, return array_value(fp::placed_columns(s, D(a, 0)))),
	PORT(BattleFootprint, width, 1, false, return int_value(fp::width(s, D(a, 0)))),
	PORT(BattleRules, _ability_by_id, 2, false, return dict_value(br::_ability_by_id(s, D(a, 0), S(a, 1)))),
	PORT(BattleRules, _ability_damage_modifier, 6, false, return float_value(br::_ability_damage_modifier(s, D(a, 0), D(a, 1), D(a, 2), B(a, 3), B(a, 4), I(a, 5)))),
	PORT(BattleRules, _adjust_stack_cohesion, 3, true, br::_adjust_stack_cohesion(s, D(a, 0), S(a, 1), I(a, 2)); return nil()),
	PORT(BattleRules, _adjust_stack_momentum, 3, true, br::_adjust_stack_momentum(s, D(a, 0), S(a, 1), I(a, 2)); return nil()),
	PORT(BattleRules, _advance_desired_gap, 2, false, return int_value(br::_advance_desired_gap(s, D(a, 0), D(a, 1)))),
	PORT(BattleRules, _advance_distance_delta, 2, true, return int_value(br::_advance_distance_delta(s, D(a, 0), D(a, 1)))),
	PORT(BattleRules, _advance_lateral_penalty, 2, false, return int_value(br::_advance_lateral_penalty(s, D(a, 0), D(a, 1)))),
	PORT(BattleRules, _advance_stalled_by_obstruction, 2, true, return bool_value(br::_advance_stalled_by_obstruction(s, D(a, 0), D(a, 1)))),
	PORT(BattleRules, _advance_to_next_alive, 2, true, return str(br::_advance_to_next_alive(s, D(a, 0), I(a, 1)))),
	PORT(BattleRules, _alive_count, 1, false, return int_value(br::_alive_count(s, D(a, 0)))),
	PORT(BattleRules, _alive_stack_count_for_side, 2, false, return int_value(br::_alive_stack_count_for_side(s, D(a, 0), S(a, 1)))),
	PORT(BattleRules, _alive_stacks_for_side, 2, false, return array_value(br::_alive_stacks_for_side(s, D(a, 0), S(a, 1)))),
	PORT(BattleRules, _allied_melee_count, 2, false, return int_value(br::_allied_melee_count(s, D(a, 0), S(a, 1)))),
	PORT(BattleRules, _append_animation_event_record, 2, true, br::_append_animation_event_record(s, D(a, 0), D(a, 1)); return nil()),
	PORT(BattleRules, _append_counter_ambush_flare_event, 5, true, return str(br::_append_counter_ambush_flare_event(s, D(a, 0), D(a, 1), D(a, 2), S(a, 3), S(a, 4)))),
	PORT(BattleRules, _append_damage_presentation_event, 8, true, br::_append_damage_presentation_event(s, D(a, 0), S(a, 1), D(a, 2), D(a, 3), D(a, 4), I(a, 5), S(a, 6), D(a, 7)); return nil()),
	PORT(BattleRules, _append_nonempty_message, 2, true, br::_append_nonempty_message(s, A(a, 0), S(a, 1)); return nil()),
	PORT(BattleRules, _append_presentation_event, 4, true, br::_append_presentation_event(s, D(a, 0), S(a, 1), S(a, 2), D(a, 3)); return nil()),
	PORT(BattleRules, _append_text_presentation_event, 6, true, br::_append_text_presentation_event(s, D(a, 0), S(a, 1), A(a, 2), D(a, 3), D(a, 4), S(a, 5)); return nil()),
	PORT(BattleRules, _apply_attack_ability_effects, 6, true, return array_value(br::_apply_attack_ability_effects(s, D(a, 0), D(a, 1), D(a, 2), B(a, 3), I(a, 4), D(a, 5)))),
	PORT(BattleRules, _apply_damage_pressure, 6, true, return array_value(br::_apply_damage_pressure(s, D(a, 0), D(a, 1), D(a, 2), D(a, 3), B(a, 4), S(a, 5)))),
	PORT(BattleRules, _apply_damage_to_stack, 3, true, br::_apply_damage_to_stack(s, D(a, 0), S(a, 1), I(a, 2)); return nil()),
	PORT(BattleRules, _apply_destroyed_stack_shock, 3, true, br::_apply_destroyed_stack_shock(s, D(a, 0), D(a, 1), S(a, 2)); return nil()),
	PORT(BattleRules, _apply_field_objective_action_pressure, 2, true, return array_value(br::_apply_field_objective_action_pressure(s, D(a, 0), D(a, 1)))),
	PORT(BattleRules, _apply_field_objective_control_push, 4, true, return str(br::_apply_field_objective_control_push(s, D(a, 0), D(a, 1), S(a, 2), I(a, 3)))),
	PORT(BattleRules, _apply_field_objective_round_effects, 1, true, br::_apply_field_objective_round_effects(s, D(a, 0)); return nil()),
	PORT(BattleRules, _apply_foundry_aura_round_repair, 1, true, return int_value(br::_apply_foundry_aura_round_repair(s, D(a, 0)))),
	PORT(BattleRules, _apply_hookline_pull, 3, true, return bool_value(br::_apply_hookline_pull(s, D(a, 0), D(a, 1), D(a, 2)))),
	PORT(BattleRules, _apply_pressure_artillery, 3, true, return array_value(br::_apply_pressure_artillery(s, D(a, 0), D(a, 1), D(a, 2)))),
	PORT(BattleRules, _apply_ranged_damage_return, 5, true, return array_value(br::_apply_ranged_damage_return(s, D(a, 0), S(a, 1), D(a, 2), B(a, 3), S(a, 4)))),
	PORT(BattleRules, _apply_readiness_writ, 2, true, return dict_value(br::_apply_readiness_writ(s, D(a, 0), D(a, 1)))),
	PORT(BattleRules, _apply_retaliation_ability_effects, 3, true, return array_value(br::_apply_retaliation_ability_effects(s, D(a, 0), D(a, 1), D(a, 2)))),
	PORT(BattleRules, _apply_round_pressure_shifts, 1, true, br::_apply_round_pressure_shifts(s, D(a, 0)); return nil()),
	PORT(BattleRules, _apply_sporeglass_mending_fire, 2, true, return dict_value(br::_apply_sporeglass_mending_fire(s, D(a, 0), D(a, 1)))),
	PORT(BattleRules, _apply_stack_effect, 3, true, return dict_value(br::_apply_stack_effect(s, D(a, 0), S(a, 1), a[2]))),
	PORT(BattleRules, _apply_wait, 1, true, br::_apply_wait(s, D(a, 0)); return nil()),
	PORT(BattleRules, _assign_default_target, 1, true, br::_assign_default_target(s, D(a, 0)); return nil()),
	PORT(BattleRules, _attach_post_attack_target_context, 5, true, return dict_value(br::_attach_post_attack_target_context(s, D(a, 0), a[1], S(a, 2), D(a, 3), D(a, 4)))),
	PORT(BattleRules, _attack_distance_for_action, 4, false, return int_value(br::_attack_distance_for_action(s, D(a, 0), D(a, 1), D(a, 2), B(a, 3)))),
	PORT(BattleRules, _attack_legality_for_target, 3, true, return dict_value(br::_attack_legality_for_target(s, D(a, 0), D(a, 1), D(a, 2)))),
	PORT(BattleRules, _attack_momentum_gain, 6, true, return int_value(br::_attack_momentum_gain(s, D(a, 0), D(a, 1), D(a, 2), D(a, 3), B(a, 4), S(a, 5)))),
	PORT(BattleRules, _authored_ability_by_id, 2, false, return dict_value(br::_authored_ability_by_id(s, D(a, 0), S(a, 1)))),
	PORT(BattleRules, _battle_has_any_tags, 2, false, return bool_value(br::_battle_has_any_tags(s, D(a, 0), A(a, 1)))),
	PORT(BattleRules, _battle_has_tag, 2, false, return bool_value(br::_battle_has_tag(s, D(a, 0), S(a, 1)))),
	PORT(BattleRules, _battle_retreat_allowed, 1, false, return bool_value(br::_battle_retreat_allowed(s, D(a, 0)))),
	PORT(BattleRules, _battle_surrender_allowed, 1, false, return bool_value(br::_battle_surrender_allowed(s, D(a, 0)))),
	PORT(BattleRules, _brace_available, 2, false, return bool_value(br::_brace_available(s, D(a, 0), D(a, 1)))),
	PORT(BattleRules, _brace_has_held_objective, 3, false, return bool_value(br::_brace_has_held_objective(s, D(a, 0), D(a, 1), D(a, 2)))),
	PORT(BattleRules, _bramble_ground_ability, 1, false, return dict_value(br::_bramble_ground_ability(s, D(a, 0)))),
	PORT(BattleRules, _bramble_ground_available, 3, false, return bool_value(br::_bramble_ground_available(s, D(a, 0), D(a, 1), D(a, 2)))),
	PORT(BattleRules, _build_blocking_map, 1, false, return dict_value(br::_build_blocking_map(s, D(a, 0)))),
	PORT(BattleRules, _build_occupancy_map, 1, false, return dict_value(br::_build_occupancy_map(s, D(a, 0)))),
	PORT(BattleRules, _calculate_damage, 7, true, return int_value(br::_calculate_damage(s, D(a, 0), D(a, 1), D(a, 2), a[3], B(a, 4), B(a, 5), I(a, 6)))),
	PORT(BattleRules, _can_make_melee_attack, 3, false, return bool_value(br::_can_make_melee_attack(s, D(a, 0), D(a, 1), D(a, 2)))),
	PORT(BattleRules, _can_make_ranged_attack, 3, false, return bool_value(br::_can_make_ranged_attack(s, D(a, 0), D(a, 1), D(a, 2)))),
	PORT(BattleRules, _can_make_retaliation, 3, false, return bool_value(br::_can_make_retaliation(s, D(a, 0), I(a, 1), D(a, 2)))),
	PORT(BattleRules, _can_melee_this_action, 3, true, return bool_value(br::_can_melee_this_action(s, D(a, 0), D(a, 1), D(a, 2)))),
	PORT(BattleRules, _capital_front_anchor_side, 1, false, return str(br::_capital_front_anchor_side(s, D(a, 0)))),
	PORT(BattleRules, _capital_front_assault_side, 1, false, return str(br::_capital_front_assault_side(s, D(a, 0)))),
	PORT(BattleRules, _casualty_cohesion_shift, 2, false, return int_value(br::_casualty_cohesion_shift(s, D(a, 0), D(a, 1)))),
	PORT(BattleRules, _charter_retaliation_aura_context, 2, false, return dict_value(br::_charter_retaliation_aura_context(s, D(a, 0), D(a, 1)))),
	PORT(BattleRules, _cleanse_stack_effects, 3, true, return int_value(br::_cleanse_stack_effects(s, D(a, 0), S(a, 1), a[2]))),
	PORT(BattleRules, _clear_post_move_transition_result_fields, 1, true, br::_clear_post_move_transition_result_fields(s, D(a, 0)); return nil()),
	PORT(BattleRules, _clear_selected_target_closing, 1, true, br::_clear_selected_target_closing(s, D(a, 0)); return nil()),
	PORT(BattleRules, _clear_selected_target_continuity, 1, true, br::_clear_selected_target_continuity(s, D(a, 0)); return nil()),
	PORT(BattleRules, _clear_stale_selected_target_closing, 2, true, return bool_value(br::_clear_stale_selected_target_closing(s, D(a, 0), B(a, 1)))),
	PORT(BattleRules, _cohesion_attack_bonus, 1, false, return int_value(br::_cohesion_attack_bonus(I(a, 0)))),
	PORT(BattleRules, _cohesion_damage_modifier, 5, true, return float_value(br::_cohesion_damage_modifier(s, D(a, 0), D(a, 1), D(a, 2), B(a, 3), B(a, 4)))),
	PORT(BattleRules, _cohesion_defense_bonus, 1, false, return int_value(br::_cohesion_defense_bonus(I(a, 0)))),
	PORT(BattleRules, _cohesion_initiative_bonus, 1, false, return int_value(br::_cohesion_initiative_bonus(I(a, 0)))),
	PORT(BattleRules, _commander_damage_modifier, 5, true, return float_value(br::_commander_damage_modifier(s, D(a, 0), D(a, 1), D(a, 2), B(a, 3), I(a, 4)))),
	PORT(BattleRules, _commit_damage_rng_roll, 2, true, br::_commit_damage_rng_roll(s, D(a, 0), a[1]); return nil()),
	PORT(BattleRules, _compare_stack_order_keys, 2, false, return bool_value(br::_compare_stack_order_keys(s, D(a, 0), D(a, 1)))),
	PORT(BattleRules, _compare_waiting_order_keys, 2, false, return bool_value(br::_compare_waiting_order_keys(s, D(a, 0), D(a, 1)))),
	PORT(BattleRules, _consume_readiness_writ_preparation, 3, true, return dict_value(br::_consume_readiness_writ_preparation(s, D(a, 0), S(a, 1), S(a, 2)))),
	PORT(BattleRules, _consume_retaliation, 2, true, br::_consume_retaliation(s, D(a, 0), S(a, 1)); return nil()),
	PORT(BattleRules, _consume_shot, 2, true, br::_consume_shot(s, D(a, 0), S(a, 1)); return nil()),
	PORT(BattleRules, _contextual_attack_bonus, 2, true, return int_value(br::_contextual_attack_bonus(s, D(a, 0), D(a, 1)))),
	PORT(BattleRules, _contextual_cohesion_bonus, 2, true, return int_value(br::_contextual_cohesion_bonus(s, D(a, 0), D(a, 1)))),
	PORT(BattleRules, _contextual_defense_bonus, 2, true, return int_value(br::_contextual_defense_bonus(s, D(a, 0), D(a, 1)))),
	PORT(BattleRules, _contextual_initiative_bonus, 2, true, return int_value(br::_contextual_initiative_bonus(s, D(a, 0), D(a, 1)))),
	PORT(BattleRules, _contextual_momentum_bonus, 2, true, return int_value(br::_contextual_momentum_bonus(s, D(a, 0), D(a, 1)))),
	PORT(BattleRules, _counter_ambush_flare_context, 3, false, return dict_value(br::_counter_ambush_flare_context(s, D(a, 0), D(a, 1), S(a, 2)))),
	PORT(BattleRules, _damage_for_roll, 7, true, return int_value(br::_damage_for_roll(s, D(a, 0), D(a, 1), D(a, 2), I(a, 3), B(a, 4), B(a, 5), I(a, 6)))),
	PORT(BattleRules, _damage_modifier, 6, true, return float_value(br::_damage_modifier(s, D(a, 0), D(a, 1), D(a, 2), B(a, 3), B(a, 4), I(a, 5)))),
	PORT(BattleRules, _damage_rng_for_battle, 1, true, return br::_damage_rng_for_battle(s, a[0])),
	PORT(BattleRules, _damage_rng_integrity, 3, false, return str(br::_damage_rng_integrity(s, I(a, 0), S(a, 1), I(a, 2)))),
	PORT(BattleRules, _default_stack_hex, 4, false, return dict_value(br::_default_stack_hex(s, S(a, 0), I(a, 1), I(a, 2), D(a, 3)))),
	PORT(BattleRules, _deployment_column, 2, false, return int_value(br::_deployment_column(s, S(a, 0), D(a, 1)))),
	PORT(BattleRules, _distance_band_from_hex_distance, 1, false, return int_value(br::_distance_band_from_hex_distance(I(a, 0)))),
	PORT(BattleRules, _enemy_hero_payload_from_state, 3, true, return dict_value(br::_enemy_hero_payload_from_state(s, D(a, 0), a[1], a[2]))),
	PORT(BattleRules, _enemy_wounded_count, 2, false, return int_value(br::_enemy_wounded_count(s, D(a, 0), S(a, 1)))),
	PORT(BattleRules, _ensure_battle_hex_state, 1, true, br::_ensure_battle_hex_state(s, D(a, 0)); return nil()),
	PORT(BattleRules, _ensure_damage_rng_state, 2, true, br::_ensure_damage_rng_state(s, a[0], D(a, 1)); return nil()),
	PORT(BattleRules, _expired_stack_effect_count, 2, true, return int_value(br::_expired_stack_effect_count(s, D(a, 0), I(a, 1)))),
	PORT(BattleRules, _faction_damage_modifier, 5, false, return float_value(br::_faction_damage_modifier(s, D(a, 0), D(a, 1), D(a, 2), B(a, 3), I(a, 4)))),
	PORT(BattleRules, _faction_initiative_bonus, 2, false, return int_value(br::_faction_initiative_bonus(s, D(a, 0), D(a, 1)))),
	PORT(BattleRules, _field_objective_action_influence, 6, false, return int_value(br::_field_objective_action_influence(s, D(a, 0), D(a, 1), S(a, 2), D(a, 3), D(a, 4), D(a, 5)))),
	PORT(BattleRules, _field_objective_attack_bonus, 2, false, return int_value(br::_field_objective_attack_bonus(s, D(a, 0), D(a, 1)))),
	PORT(BattleRules, _field_objective_cohesion_bonus, 2, false, return int_value(br::_field_objective_cohesion_bonus(s, D(a, 0), D(a, 1)))),
	PORT(BattleRules, _field_objective_commander_modifier, 3, false, return float_value(br::_field_objective_commander_modifier(s, D(a, 0), D(a, 1), D(a, 2)))),
	PORT(BattleRules, _field_objective_cover_damage_modifier, 5, false, return float_value(br::_field_objective_cover_damage_modifier(s, D(a, 0), D(a, 1), D(a, 2), B(a, 3), I(a, 4)))),
	PORT(BattleRules, _field_objective_defense_bonus, 2, false, return int_value(br::_field_objective_defense_bonus(s, D(a, 0), D(a, 1)))),
	PORT(BattleRules, _field_objective_flip_message, 3, false, return str(br::_field_objective_flip_message(s, D(a, 0), S(a, 1), S(a, 2)))),
	PORT(BattleRules, _field_objective_initiative_bonus, 2, false, return int_value(br::_field_objective_initiative_bonus(s, D(a, 0), D(a, 1)))),
	PORT(BattleRules, _field_objective_label, 1, false, return str(br::_field_objective_label(s, D(a, 0)))),
	PORT(BattleRules, _field_objective_momentum_bonus, 2, false, return int_value(br::_field_objective_momentum_bonus(s, D(a, 0), D(a, 1)))),
	PORT(BattleRules, _field_objectives, 1, false, return array_value(br::_field_objectives(s, D(a, 0)))),
	PORT(BattleRules, _first_open_body_near, 3, false, return dict_value(br::_first_open_body_near(s, D(a, 0), D(a, 1), D(a, 2)))),
	PORT(BattleRules, _fog_screen_ability, 1, false, return dict_value(br::_fog_screen_ability(s, D(a, 0)))),
	PORT(BattleRules, _fog_screen_available, 3, false, return bool_value(br::_fog_screen_available(s, D(a, 0), D(a, 1), D(a, 2)))),
	PORT(BattleRules, _formation_rows, 1, false, return array_value(br::_formation_rows(s, I(a, 0)))),
	PORT(BattleRules, _get_stack_by_id, 2, false, return dict_value(br::_get_stack_by_id(s, D(a, 0), S(a, 1)))),
	PORT(BattleRules, _harry_support_ready, 4, false, return bool_value(br::_harry_support_ready(s, D(a, 0), D(a, 1), D(a, 2), D(a, 3)))),
	PORT(BattleRules, _has_ability, 2, false, return bool_value(br::_has_ability(s, D(a, 0), S(a, 1)))),
	PORT(BattleRules, _has_battle_trait, 2, false, return bool_value(br::_has_battle_trait(s, a[0], S(a, 1)))),
	PORT(BattleRules, _health_ratio, 1, false, return float_value(br::_health_ratio(s, D(a, 0)))),
	PORT(BattleRules, _hero_battle_traits, 2, true, return br::_hero_battle_traits(s, D(a, 0), S(a, 1))),
	PORT(BattleRules, _hero_has_trait, 3, true, return bool_value(br::_hero_has_trait(s, D(a, 0), S(a, 1), S(a, 2)))),
	PORT(BattleRules, _hero_payload_for_side, 2, true, return dict_value(br::_hero_payload_for_side(s, D(a, 0), S(a, 1)))),
	PORT(BattleRules, _hero_payload_from_state, 4, true, return dict_value(br::_hero_payload_from_state(s, D(a, 0), D(a, 1), a[2], S(a, 3)))),
	PORT(BattleRules, _hex_board_descriptor, 0, false, return dict_value(br::_hex_board_descriptor(s))),
	PORT(BattleRules, _hex_cell, 2, false, return dict_value(br::_hex_cell(s, I(a, 0), I(a, 1)))),
	PORT(BattleRules, _hex_distance, 2, false, return int_value(br::_hex_distance(s, D(a, 0), D(a, 1)))),
	PORT(BattleRules, _hex_in_bounds, 2, false, return bool_value(br::_hex_in_bounds(I(a, 0), I(a, 1)))),
	PORT(BattleRules, _hex_key, 1, false, return str(br::_hex_key(s, D(a, 0)))),
	PORT(BattleRules, _hex_key_from_coords, 2, false, return str(br::_hex_key_from_coords(s, I(a, 0), I(a, 1)))),
	PORT(BattleRules, _hex_label, 1, false, return str(br::_hex_label(s, D(a, 0)))),
	PORT(BattleRules, _hex_neighbors, 1, false, return array_value(br::_hex_neighbors(s, D(a, 0)))),
	PORT(BattleRules, _hex_tail_step, 1, false, return int_value(br::_hex_tail_step(s, D(a, 0)))),
	PORT(BattleRules, _highest_momentum_stack_for_side, 2, true, return dict_value(br::_highest_momentum_stack_for_side(s, D(a, 0), S(a, 1)))),
	PORT(BattleRules, _hookline_available, 2, false, return bool_value(br::_hookline_available(s, D(a, 0), D(a, 1)))),
	PORT(BattleRules, _initialize_damage_rng_state, 2, true, br::_initialize_damage_rng_state(s, a[0], D(a, 1)); return nil()),
	PORT(BattleRules, _is_town_defense_context, 1, false, return bool_value(br::_is_town_defense_context(s, a[0]))),
	PORT(BattleRules, _join_messages, 1, false, return str(br::_join_messages(s, A(a, 0)))),
	PORT(BattleRules, _legal_attack_target_ids_for_active_stack, 1, true, return array_value(br::_legal_attack_target_ids_for_active_stack(s, D(a, 0)))),
	PORT(BattleRules, _legal_attack_target_ids_for_active_stack_uncached, 1, true, return array_value(br::_legal_attack_target_ids_for_active_stack_uncached(s, D(a, 0)))),
	PORT(BattleRules, _linked_ranged_attack_screen_multiplier, 2, false, return float_value(br::_linked_ranged_attack_screen_multiplier(s, D(a, 0), D(a, 1)))),
	PORT(BattleRules, _lowest_health_stack, 1, false, return dict_value(br::_lowest_health_stack(s, A(a, 0)))),
	PORT(BattleRules, _mark_damage_target_animation, 6, true, br::_mark_damage_target_animation(s, D(a, 0), S(a, 1), B(a, 2), S(a, 3), D(a, 4), D(a, 5)); return nil()),
	PORT(BattleRules, _mark_stack_animation_event, 4, true, br::_mark_stack_animation_event(s, D(a, 0), S(a, 1), S(a, 2), D(a, 3)); return nil()),
	PORT(BattleRules, _matching_melee_approach, 4, true, return dict_value(br::_matching_melee_approach(s, D(a, 0), D(a, 1), D(a, 2), D(a, 3)))),
	PORT(BattleRules, _melee_approach_entry, 4, false, return dict_value(br::_melee_approach_entry(s, D(a, 0), D(a, 1), D(a, 2), I(a, 3)))),
	PORT(BattleRules, _merge_spell_school_resistance, 2, false, return dict_value(br::_merge_spell_school_resistance(s, a[0], a[1]))),
	PORT(BattleRules, _momentum_attack_bonus, 1, false, return int_value(br::_momentum_attack_bonus(I(a, 0)))),
	PORT(BattleRules, _momentum_initiative_bonus, 1, false, return int_value(br::_momentum_initiative_bonus(I(a, 0)))),
	PORT(BattleRules, _normalize_ability_modifiers, 1, false, return dict_value(br::_normalize_ability_modifiers(s, a[0]))),
	PORT(BattleRules, _normalize_animation_event_queue, 1, false, return array_value(br::_normalize_animation_event_queue(s, a[0]))),
	PORT(BattleRules, _normalize_hex_cell, 1, false, return dict_value(br::_normalize_hex_cell(s, a[0]))),
	PORT(BattleRules, _normalize_presentation_event_queue, 1, false, return array_value(br::_normalize_presentation_event_queue(s, a[0]))),
	PORT(BattleRules, _normalize_recent_events, 1, false, return array_value(br::_normalize_recent_events(s, a[0]))),
	PORT(BattleRules, _normalized_battle_traits, 1, false, return array_value(br::_normalized_battle_traits(s, a[0]))),
	PORT(BattleRules, _obstacle_cell_map, 1, false, return dict_value(br::_obstacle_cell_map(s, D(a, 0)))),
	PORT(BattleRules, _offset_to_cube, 2, false, return dict_value(br::_offset_to_cube(s, I(a, 0), I(a, 1)))),
	PORT(BattleRules, _opposing_side, 1, false, return str(br::_opposing_side(S(a, 0)))),
	PORT(BattleRules, _opposing_stacks_still_to_act, 2, false, return int_value(br::_opposing_stacks_still_to_act(s, D(a, 0), D(a, 1)))),
	PORT(BattleRules, _ordered_remaining_actors, 3, true, return array_value(br::_ordered_remaining_actors(s, D(a, 0), A(a, 1), a[2]))),
	PORT(BattleRules, _player_input_locked_summary, 0, false, return str(br::_player_input_locked_summary(s))),
	PORT(BattleRules, _preferred_default_target_for_active_stack, 3, true, return dict_value(br::_preferred_default_target_for_active_stack(s, D(a, 0), D(a, 1), A(a, 2)))),
	PORT(BattleRules, _prepare_round, 2, true, br::_prepare_round(s, D(a, 0), I(a, 1)); return nil()),
	PORT(BattleRules, _presentation_walk_path, 3, false, return array_value(br::_presentation_walk_path(s, D(a, 0), D(a, 1), D(a, 2)))),
	PORT(BattleRules, _pressure_artillery_secondary_damage, 1, false, return int_value(br::_pressure_artillery_secondary_damage(s, D(a, 0)))),
	PORT(BattleRules, _pressure_artillery_secondary_target, 3, false, return dict_value(br::_pressure_artillery_secondary_target(s, D(a, 0), D(a, 1), D(a, 2)))),
	PORT(BattleRules, _projected_min_opposing_hex_distance, 3, false, return int_value(br::_projected_min_opposing_hex_distance(s, D(a, 0), D(a, 1), D(a, 2)))),
	PORT(BattleRules, _ranged_damage_return_ratio, 1, false, return float_value(br::_ranged_damage_return_ratio(s, D(a, 0)))),
	PORT(BattleRules, _reach_available, 2, false, return bool_value(br::_reach_available(s, D(a, 0), D(a, 1)))),
	PORT(BattleRules, _reachable_empty_hexes, 3, false, return array_value(br::_reachable_empty_hexes(s, D(a, 0), D(a, 1), I(a, 2)))),
	PORT(BattleRules, _readiness_writ_ability, 1, false, return dict_value(br::_readiness_writ_ability(s, D(a, 0)))),
	PORT(BattleRules, _readiness_writ_available, 3, true, return bool_value(br::_readiness_writ_available(s, D(a, 0), D(a, 1), D(a, 2)))),
	PORT(BattleRules, _readiness_writ_effect_count, 3, false, return int_value(br::_readiness_writ_effect_count(s, D(a, 0), D(a, 1), D(a, 2)))),
	PORT(BattleRules, _readiness_writ_preparation_target, 3, true, return dict_value(br::_readiness_writ_preparation_target(s, D(a, 0), D(a, 1), D(a, 2)))),
	PORT(BattleRules, _readiness_writ_target, 3, true, return dict_value(br::_readiness_writ_target(s, D(a, 0), D(a, 1), D(a, 2)))),
	PORT(BattleRules, _record_event, 2, true, br::_record_event(s, D(a, 0), S(a, 1)); return nil()),
	PORT(BattleRules, _reserve_wave_is_active_for_side, 2, false, return bool_value(br::_reserve_wave_is_active_for_side(s, D(a, 0), S(a, 1)))),
	PORT(BattleRules, _reserve_wave_ready_round, 2, false, return int_value(br::_reserve_wave_ready_round(s, D(a, 0), S(a, 1)))),
	PORT(BattleRules, _resolve_wait, 2, true, return str(br::_resolve_wait(s, D(a, 0), D(a, 1)))),
	PORT(BattleRules, _resolved_damage_seed, 2, false, return int_value(br::_resolved_damage_seed(s, a[0], D(a, 1)))),
	PORT(BattleRules, _resort_remaining_turn_order, 1, true, br::_resort_remaining_turn_order(s, D(a, 0)); return nil()),
	PORT(BattleRules, _restore_stack_health, 3, true, return int_value(br::_restore_stack_health(s, D(a, 0), S(a, 1), I(a, 2)))),
	PORT(BattleRules, _selected_target_can_remain_for_active_stack, 3, false, return bool_value(br::_selected_target_can_remain_for_active_stack(s, D(a, 0), D(a, 1), S(a, 2)))),
	PORT(BattleRules, _selected_target_closing_is_stale, 2, true, return bool_value(br::_selected_target_closing_is_stale(s, D(a, 0), B(a, 1)))),
	PORT(BattleRules, _set_selected_target, 3, true, br::_set_selected_target(s, D(a, 0), S(a, 1), B(a, 2)); return nil()),
	PORT(BattleRules, _set_stack_defending, 2, true, br::_set_stack_defending(s, D(a, 0), S(a, 1)); return nil()),
	PORT(BattleRules, _set_stack_hex, 3, true, br::_set_stack_hex(s, D(a, 0), S(a, 1), D(a, 2)); return nil()),
	PORT(BattleRules, _side_ability_bool, 5, false, return bool_value(br::_side_ability_bool(s, D(a, 0), S(a, 1), S(a, 2), S(a, 3), B(a, 4)))),
	PORT(BattleRules, _side_ability_payloads, 3, false, return array_value(br::_side_ability_payloads(s, D(a, 0), S(a, 1), S(a, 2)))),
	PORT(BattleRules, _side_controls_field_objective_type, 3, false, return bool_value(br::_side_controls_field_objective_type(s, D(a, 0), S(a, 1), S(a, 2)))),
	PORT(BattleRules, _side_defending_count, 2, false, return int_value(br::_side_defending_count(s, D(a, 0), S(a, 1)))),
	PORT(BattleRules, _side_has_ability, 3, false, return bool_value(br::_side_has_ability(s, D(a, 0), S(a, 1), S(a, 2)))),
	PORT(BattleRules, _side_has_linked_unit, 3, false, return bool_value(br::_side_has_linked_unit(s, D(a, 0), S(a, 1), a[2]))),
	PORT(BattleRules, _side_has_role_mix, 2, false, return bool_value(br::_side_has_role_mix(s, D(a, 0), S(a, 1)))),
	PORT(BattleRules, _side_label, 1, false, return str(br::_side_label(S(a, 0)))),
	PORT(BattleRules, _side_max_ability_float, 5, false, return float_value(br::_side_max_ability_float(s, D(a, 0), S(a, 1), S(a, 2), S(a, 3), F(a, 4)))),
	PORT(BattleRules, _side_max_ability_int, 4, false, return int_value(br::_side_max_ability_int(s, D(a, 0), S(a, 1), S(a, 2), S(a, 3)))),
	PORT(BattleRules, _side_max_authored_ability_int, 4, false, return int_value(br::_side_max_authored_ability_int(s, D(a, 0), S(a, 1), S(a, 2), S(a, 3)))),
	PORT(BattleRules, _side_payload_with_commander_fallback, 3, true, return dict_value(br::_side_payload_with_commander_fallback(s, a[0], a[1], S(a, 2)))),
	PORT(BattleRules, _side_positive_effect_count, 2, false, return int_value(br::_side_positive_effect_count(s, D(a, 0), S(a, 1)))),
	PORT(BattleRules, _side_resonance_relay, 2, false, return dict_value(br::_side_resonance_relay(s, D(a, 0), S(a, 1)))),
	PORT(BattleRules, _solar_array_lane_melee_multiplier, 2, false, return float_value(br::_solar_array_lane_melee_multiplier(s, D(a, 0), D(a, 1)))),
	PORT(BattleRules, _sorted_turn_order, 1, true, return array_value(br::_sorted_turn_order(s, D(a, 0)))),
	PORT(BattleRules, _sporeglass_mend_target, 2, false, return dict_value(br::_sporeglass_mend_target(s, D(a, 0), S(a, 1)))),
	PORT(BattleRules, _stack_attack_total, 2, true, return int_value(br::_stack_attack_total(s, D(a, 0), D(a, 1)))),
	PORT(BattleRules, _stack_can_breach_obstruction, 2, true, return bool_value(br::_stack_can_breach_obstruction(s, D(a, 0), D(a, 1)))),
	PORT(BattleRules, _stack_cohesion_total, 2, true, return int_value(br::_stack_cohesion_total(s, D(a, 0), D(a, 1)))),
	PORT(BattleRules, _stack_defense_total, 2, true, return int_value(br::_stack_defense_total(s, D(a, 0), D(a, 1)))),
	PORT(BattleRules, _stack_has_positive_effect, 2, false, return bool_value(br::_stack_has_positive_effect(s, D(a, 0), D(a, 1)))),
	PORT(BattleRules, _stack_hex, 1, false, return dict_value(br::_stack_hex(s, D(a, 0)))),
	PORT(BattleRules, _stack_hex_distance, 2, false, return int_value(br::_stack_hex_distance(s, D(a, 0), D(a, 1)))),
	PORT(BattleRules, _stack_initiative_total, 2, true, return int_value(br::_stack_initiative_total(s, D(a, 0), D(a, 1)))),
	PORT(BattleRules, _stack_is_anchor_side, 2, false, return bool_value(br::_stack_is_anchor_side(s, D(a, 0), D(a, 1)))),
	PORT(BattleRules, _stack_is_assault_side, 2, false, return bool_value(br::_stack_is_assault_side(s, D(a, 0), D(a, 1)))),
	PORT(BattleRules, _stack_is_cover_screened, 2, false, return bool_value(br::_stack_is_cover_screened(s, D(a, 0), D(a, 1)))),
	PORT(BattleRules, _stack_is_engaged, 2, false, return bool_value(br::_stack_is_engaged(s, D(a, 0), D(a, 1)))),
	PORT(BattleRules, _stack_is_hex_isolated, 2, false, return bool_value(br::_stack_is_hex_isolated(s, D(a, 0), D(a, 1)))),
	PORT(BattleRules, _stack_is_isolated, 2, false, return bool_value(br::_stack_is_isolated(s, D(a, 0), D(a, 1)))),
	PORT(BattleRules, _stack_is_rooted, 2, false, return bool_value(br::_stack_is_rooted(s, D(a, 0), D(a, 1)))),
	PORT(BattleRules, _stack_label, 1, false, return str(br::_stack_label(s, D(a, 0)))),
	PORT(BattleRules, _stack_momentum_total, 2, true, return int_value(br::_stack_momentum_total(s, D(a, 0), D(a, 1)))),
	PORT(BattleRules, _stack_movement_points, 2, false, return int_value(br::_stack_movement_points(s, D(a, 0), D(a, 1)))),
	PORT(BattleRules, _stacks_ahead_after_wait, 2, true, return int_value(br::_stacks_ahead_after_wait(s, D(a, 0), S(a, 1)))),
	PORT(BattleRules, _status_effect_from_ability, 2, false, return dict_value(br::_status_effect_from_ability(s, D(a, 0), D(a, 1)))),
	PORT(BattleRules, _supportive_cohesion_gain, 3, false, return int_value(br::_supportive_cohesion_gain(s, D(a, 0), D(a, 1), B(a, 2)))),
	PORT(BattleRules, _sync_distance_from_hexes, 1, true, br::_sync_distance_from_hexes(s, D(a, 0)); return nil()),
	PORT(BattleRules, _sync_occupied_hexes, 1, true, br::_sync_occupied_hexes(s, D(a, 0)); return nil()),
	PORT(BattleRules, _terrain_tag_damage_modifier, 5, false, return float_value(br::_terrain_tag_damage_modifier(s, D(a, 0), D(a, 1), D(a, 2), B(a, 3), I(a, 4)))),
	PORT(BattleRules, _volley_has_protected_lane, 3, false, return bool_value(br::_volley_has_protected_lane(s, D(a, 0), D(a, 1), D(a, 2)))),
	PORT(BattleRules, _walk_steps_to_target, 4, true, return dict_value(br::_walk_steps_to_target(s, D(a, 0), D(a, 1), D(a, 2), I(a, 3)))),
	PORT(BattleRules, _weakest_stack_by_cohesion, 2, true, return dict_value(br::_weakest_stack_by_cohesion(s, D(a, 0), S(a, 1)))),
	PORT(BattleRules, _weakest_stack_by_role, 3, true, return dict_value(br::_weakest_stack_by_role(s, D(a, 0), S(a, 1), B(a, 2)))),
	PORT(BattleRules, action_availability, 1, true, return dict_value(br::action_availability(s, D(a, 0)))),
	PORT(BattleRules, advance_turn, 1, true, br::advance_turn(s, D(a, 0)); return nil()),
	PORT(BattleRules, board_click_attack_intent_for_target, 2, true, return dict_value(br::board_click_attack_intent_for_target(s, D(a, 0), S(a, 1)))),
	PORT(BattleRules, can_wait, 1, false, return bool_value(br::can_wait(s, D(a, 0)))),
	PORT(BattleRules, extra_speed_reaches_strike, 3, true, return bool_value(br::extra_speed_reaches_strike(s, D(a, 0), D(a, 1), I(a, 2)))),
	PORT(BattleRules, get_active_stack, 1, false, return dict_value(br::get_active_stack(s, D(a, 0)))),
	PORT(BattleRules, get_selected_target, 1, false, return dict_value(br::get_selected_target(s, D(a, 0)))),
	PORT(BattleRules, legal_attack_targets_for_active_stack, 2, true, return array_value(br::legal_attack_targets_for_active_stack(s, D(a, 0), B(a, 1)))),
	PORT(BattleRules, legal_destinations_for_active_stack, 1, true, return array_value(br::legal_destinations_for_active_stack(s, D(a, 0)))),
	PORT(BattleRules, legal_destinations_for_stack, 2, true, return array_value(br::legal_destinations_for_stack(s, D(a, 0), S(a, 1)))),
	PORT(BattleRules, melee_approach_cells, 3, true, return array_value(br::melee_approach_cells(s, D(a, 0), D(a, 1), D(a, 2)))),
	PORT(BattleRules, melee_approach_destination, 3, true, return dict_value(br::melee_approach_destination(s, D(a, 0), D(a, 1), D(a, 2)))),
	PORT(BattleRules, select_target, 2, true, return dict_value(br::select_target(s, a[0], S(a, 1)))),
	PORT(BattleRules, selected_target_board_click_intent, 1, true, return dict_value(br::selected_target_board_click_intent(s, D(a, 0)))),
	PORT(BattleRules, selected_target_closing_context, 2, true, return dict_value(br::selected_target_closing_context(s, D(a, 0), B(a, 1)))),
	PORT(BattleRules, selected_target_continuity_context, 1, true, return dict_value(br::selected_target_continuity_context(s, D(a, 0)))),
	PORT(BattleRules, selected_target_legality, 1, true, return dict_value(br::selected_target_legality(s, D(a, 0)))),
	PORT(BattleRules, spend_effect_turns, 2, true, br::spend_effect_turns(s, D(a, 0), S(a, 1)); return nil()),
	PORT(BattleRules, stack_has_waited, 2, false, return bool_value(br::stack_has_waited(s, D(a, 0), S(a, 1)))),
	PORT(BattleRules, stack_strike_backs, 2, false, return dict_value(br::stack_strike_backs(s, D(a, 0), D(a, 1)))),
	PORT(BattleRules, waited_stack_ids, 1, false, return array_value(br::waited_stack_ids(s, D(a, 0)))),
	PORT(DifficultyRules, _default_difficulty_id, 0, false, return str(diff::_default_difficulty_id(s))),
	PORT(DifficultyRules, damage_multiplier_for_side, 2, false, return float_value(diff::damage_multiplier_for_side(s, a[0], S(a, 1)))),
	PORT(DifficultyRules, initiative_bonus_for_side, 2, false, return int_value(diff::initiative_bonus_for_side(s, a[0], S(a, 1)))),
	PORT(DifficultyRules, normalize_difficulty, 1, false, return str(diff::normalize_difficulty(s, a[0]))),
	PORT(DifficultyRules, profile_for_difficulty, 1, false, return dict_value(diff::profile_for_difficulty(s, a[0]))),
	PORT(DifficultyRules, profile_for_session, 1, false, return dict_value(diff::profile_for_session(s, a[0]))),
	PORT(HeroProgressionRules, _merge_bonuses, 3, true, hero::_merge_bonuses(s, D(a, 0), D(a, 1), D(a, 2)); return nil()),
	PORT(HeroProgressionRules, _normalize_specialties_in, 2, false, return array_value(hero::_normalize_specialties_in(s, D(a, 0), a[1]))),
	PORT(HeroProgressionRules, _rank_bonuses, 2, false, return dict_value(hero::_rank_bonuses(s, D(a, 0), I(a, 1)))),
	PORT(HeroProgressionRules, _rank_in_array, 2, false, return int_value(hero::_rank_in_array(s, A(a, 0), S(a, 1)))),
	PORT(HeroProgressionRules, _resolve_bonus_key, 2, false, return str(hero::_resolve_bonus_key(s, S(a, 0), D(a, 1)))),
	PORT(HeroProgressionRules, _specialty_catalog, 0, true, return dict_value(hero::_specialty_catalog(s))),
	PORT(HeroProgressionRules, _sum_bonus, 2, false, return hero::_sum_bonus(s, a[0], a[1])),
	PORT(HeroProgressionRules, aggregate_bonuses, 1, true, return dict_value(hero::aggregate_bonuses(s, D(a, 0)))),
	PORT(SpellRules, _normalize_effect_modifiers, 1, false, return dict_value(spell::_normalize_effect_modifiers(s, a[0]))),
	PORT(SpellRules, _normalize_effects, 1, false, return array_value(spell::_normalize_effects(s, a[0]))),
	PORT(SpellRules, active_effects_for_round, 2, false, return array_value(spell::active_effects_for_round(s, D(a, 0), I(a, 1)))),
	PORT(SpellRules, battle_spell_recoverable_health, 1, false, return int_value(spell::battle_spell_recoverable_health(s, D(a, 0)))),
	PORT(SpellRules, build_battle_effect, 8, false, return dict_value(spell::build_battle_effect(s, S(a, 0), S(a, 1), a[2], I(a, 3), D(a, 4), S(a, 5), S(a, 6), a[7]))),
	PORT(SpellRules, effect_bonus_for_kind, 3, false, return int_value(spell::effect_bonus_for_kind(s, D(a, 0), D(a, 1), S(a, 2)))),
	PORT(SpellRules, has_any_effect_ids, 3, false, return bool_value(spell::has_any_effect_ids(s, D(a, 0), D(a, 1), a[2]))),
	PORT(SpellRules, has_effect_id, 3, false, return bool_value(spell::has_effect_id(s, D(a, 0), D(a, 1), S(a, 2)))),
	PORT(SpellRules, normalize_blocked_status_ids, 1, false, return array_value(spell::normalize_blocked_status_ids(s, a[0]))),
	PORT(SpellRules, normalize_school_resistance, 1, false, return dict_value(spell::normalize_school_resistance(s, a[0]))),
	PORT(SpellRules, normalize_stack_effects, 1, true, return dict_value(spell::normalize_stack_effects(s, D(a, 0)))),
	PORT(SpellRules, normalize_status_immunity_ids, 1, false, return array_value(spell::normalize_status_immunity_ids(s, a[0]))),
	PORT(SpellRules, purge_expired_stack_effects, 2, true, return dict_value(spell::purge_expired_stack_effects(s, D(a, 0), I(a, 1)))),
	PORT(SpellRules, stack_status_immunity_ids, 2, false, return array_value(spell::stack_status_immunity_ids(s, D(a, 0), D(a, 1)))),
	PORT(SpellRules, target_is_immune_to_status, 3, false, return bool_value(spell::target_is_immune_to_status(s, D(a, 0), D(a, 1), S(a, 2)))),
	PORT(TownBattleRules, absorb, 2, true, return int_value(town::absorb(s, D(a, 0), I(a, 1)))),
	PORT(TownBattleRules, damage_multiplier, 4, false, return float_value(town::damage_multiplier(s, D(a, 0), D(a, 1), D(a, 2), B(a, 3)))),
	PORT(TownBattleRules, defends, 2, false, return bool_value(town::defends(s, D(a, 0), D(a, 1)))),
	PORT(TownBattleRules, effect, 2, false, return dict_value(town::effect(s, D(a, 0), S(a, 1)))),
	PORT(TownBattleRules, heal_round, 1, true, return array_value(town::heal_round(s, D(a, 0)))),
	PORT(TownBattleRules, movement_penalty, 2, false, return int_value(town::movement_penalty(s, D(a, 0), D(a, 1)))),
};

#undef PORT

} // namespace

namespace key = state::key;

// GDScript's own memos: BattleRules' board-read memo. The native board reads
// keep their answers in the State instead (State::memo_find, board_read_key).
constexpr ScriptStatic kGdscriptOnly[] = {
	{ key::battle_rules_script, key::_board_read_scope_depth },
	{ key::battle_rules_script, key::_board_read_scope_battle },
	{ key::battle_rules_script, key::_board_read_scope_cache },
	{ key::battle_rules_script, key::_board_read_cache_hits },
	{ key::battle_rules_script, key::_validation_board_read_cache_disabled },
};

// The memos the port shares with GDScript.
constexpr ScriptStatic kSharedMemos[] = {
	{ key::battle_rules_script, key::_presentation_queue_written },
	{ key::battle_rules_script, key::_hero_payload_cache },
	{ key::battle_ai_rules_script, key::_scoring_scope_depth },
	{ key::battle_ai_rules_script, key::_scoring_living },
	{ key::battle_ai_rules_script, key::_scoring_stack_terms },
	{ key::hero_progression_rules_script, key::_catalog_source },
	{ key::hero_progression_rules_script, key::_catalog_index },
};

// The battle port's table, listed in registry_tables.cpp.
Table battle_table() {
	return {"HEROES_NATIVE_BATTLE_LOG", kFunctions, sizeof(kFunctions) / sizeof(kFunctions[0]), kGdscriptOnly, sizeof(kGdscriptOnly) / sizeof(kGdscriptOnly[0]), kSharedMemos,
		sizeof(kSharedMemos) / sizeof(kSharedMemos[0])};
}

} // namespace aurelion::rules::port
