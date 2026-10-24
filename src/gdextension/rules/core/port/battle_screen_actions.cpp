// BattleRules for the battle screen (Phase 7, slice 7.9): the attack, advance,
// defend and wait summaries and the active ability window.

#include "aurelion_rules/port/battle_screen.hpp"

#include "aurelion_rules/compat/godot_math.hpp"
#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/battle_ai_rules.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/spell_rules.hpp"

#include <algorithm>
#include <initializer_list>
#include <vector>

namespace aurelion::rules::port {

namespace {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using gd::int_value;
using gd::str;
using state::State;
using state::Value;
namespace key = state::key;

// bool(surface.get(action_id, {}).get("disabled", true)).
bool surface_action_disabled(const State &state, DictRef surface, Atom action_id) {
	Value entry;
	if (!state.lookup(surface, str(action_id), entry)) {
		return true;
	}
	return gd::to_bool(ai::vget(state, entry, key::disabled, gd::bool_value(true)));
}

// String(d.get("name", fallback)).
Atom name_or(State &state, DictRef dict, Atom fallback) {
	return gd::stringify(state, gd::field_or(state, dict, key::name, str(fallback)));
}

// An Array literal of Strings.
ArrayRef string_array(State &state, std::initializer_list<Atom> texts) {
	const ArrayRef array = state.new_array();
	for (const Atom text : texts) {
		state.append(array, str(text));
	}
	return array;
}

// d.get(field, [texts...]): the field, or a new Array of the texts.
Value field_or_strings(State &state, DictRef dict, Atom field, std::initializer_list<Atom> fallback) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return gd::array_value(string_array(state, fallback));
}

// d.get(field, {}) passed to a Dictionary parameter: the field (a Dictionary,
// else a ScriptError), or a new empty one when it is missing.
DictRef dict_field_or_new(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return gd::as_dict(found);
	}
	return state.new_dict();
}

// var uses = stack.get("ability_uses", {}); `uses is Dictionary` (a missing
// field is the {} fallback), with int(uses.get(ability_id, 0)) into count.
bool ability_use_count(const State &state, DictRef stack, Atom ability_id, int64_t &count) {
	Value uses;
	if (!state.lookup(stack, str(key::ability_uses), uses)) {
		count = 0;
		return true;
	}
	if (!gd::is_dict(uses)) {
		return false;
	}
	count = gd::int_field(state, uses.ref, ability_id, 0);
	return true;
}

// String(aura_context.get("source", {}).get("battle_id", "")).
Atom aura_source_battle_id(State &state, DictRef aura_context) {
	Value source;
	if (!state.lookup(aura_context, str(key::source), source)) {
		return key::empty;
	}
	return gd::stringify(state, ai::vget(state, source, key::battle_id, str(key::empty)));
}

// {"action": action, "side": side, "battle_id": battle_id}, and
// "target_battle_id" when one is given: a field objective preview's context.
DictRef action_context(State &state, Atom action, Atom side, Atom battle_id) {
	const DictRef context = state.new_dict();
	state.set(context, str(key::action), str(action));
	state.set(context, str(key::side), str(side));
	state.set(context, str(key::battle_id), str(battle_id));
	return context;
}

// "%s." % " | ".join(clauses).
Atom clauses_sentence(State &state, const std::vector<Atom> &clauses) {
	const gd::PackedRef strings = gd::new_strings(state);
	for (const Atom clause : clauses) {
		gd::packed_append_string(state, strings, clause);
	}
	return gd::format(state, key::s_4, { str(gd::join_strings(state, key::space_bar_space, strings)) });
}

} // namespace

namespace battle_rules {

Atom _preferred_player_action_id(State &state, DictRef surface, DictRef active_stack) {
	if (!surface_action_disabled(state, surface, key::shoot) && gd::bool_field(state, active_stack, key::ranged, false)) {
		return key::shoot;
	}
	if (!surface_action_disabled(state, surface, key::strike)) {
		return key::strike;
	}
	if (!surface_action_disabled(state, surface, key::advance)) {
		return key::advance;
	}
	if (!surface_action_disabled(state, surface, key::defend)) {
		return key::defend;
	}
	if (!surface_action_disabled(state, surface, key::retreat)) {
		return key::retreat;
	}
	if (!surface_action_disabled(state, surface, key::surrender)) {
		return key::surrender;
	}
	return key::empty;
}

Atom _enemy_reply_line(State &state, DictRef session, DictRef battle) {
	(void)session;
	const DictRef reply_stack = _next_enemy_reply_stack(state, battle);
	if (gd::is_empty(state, reply_stack)) {
		return key::no_hostile_stack_remains_to_answer;
	}
	const DictRef enemy_hero = dict_field_or_new(state, battle, key::enemy_hero);
	const DictRef action = battle_ai_rules::choose_enemy_action(state, battle, reply_stack, enemy_hero, true);
	return _enemy_action_preview_summary(state, battle, reply_stack, action);
}

DictRef _next_enemy_reply_stack(State &state, DictRef battle) {
	Value turn_order;
	const bool has_turn_order = state.lookup(battle, str(key::turn_order), turn_order);
	// battle.get("turn_order", []) is an Array when the field is missing.
	if (!has_turn_order || gd::is_array(turn_order)) {
		const int64_t start = gd::add(gd::int_field(state, battle, key::turn_index, 0), 1);
		const int64_t size = has_turn_order ? state.array_size(turn_order.ref) : 0;
		for (int64_t index = start; index < size; ++index) {
			const DictRef stack = _get_stack_by_id(state, battle, gd::stringify(state, state.at(turn_order.ref, index)));
			if (!gd::is_empty(state, stack) && _alive_count(state, stack) > 0 && ai::string_or_empty(state, stack, key::side) == key::enemy) {
				return stack;
			}
		}
	}
	const ArrayRef enemies = _alive_stacks_for_side(state, battle, key::enemy);
	for (const Value &stack : gd::items(state, gd::array_value(enemies))) {
		if (gd::is_dict(stack)) {
			return stack.ref;
		}
	}
	return state.new_dict();
}

Atom _enemy_action_preview_summary(State &state, DictRef battle, DictRef enemy_stack, DictRef action) {
	if (gd::is_empty(state, enemy_stack)) {
		return key::hostile_reply_is_unclear;
	}
	const Atom action_id = ai::string_or_empty(state, action, key::action);
	const DictRef target = _get_stack_by_id(state, battle, ai::string_or_empty(state, action, key::target_battle_id));
	if (action_id == key::cast_spell) {
		const DictRef spell = gd::content_row(state, state::ContentTable::Spell, ai::string_or_empty(state, action, key::spell_id));
		const Atom enemy_label = _stack_label(state, enemy_stack);
		const Atom spell_name = name_or(state, spell, key::a_spell);
		const Atom on_target = !gd::is_empty(state, target) ? gd::format(state, key::on_s, { str(_stack_label(state, target)) }) : static_cast<Atom>(key::empty);
		return gd::format(state, key::s_is_best_placed_to_cast, { str(enemy_label), str(spell_name), str(on_target) });
	}
	if (action_id == key::shoot) {
		const Atom enemy_label = _stack_label(state, enemy_stack);
		const Atom target_label = !gd::is_empty(state, target) ? _stack_label(state, target) : static_cast<Atom>(key::the_exposed_line);
		return gd::format(state, key::s_is_best_placed_to_fire, { str(enemy_label), str(target_label) });
	}
	if (action_id == key::strike) {
		const Atom enemy_label = _stack_label(state, enemy_stack);
		const Atom target_label = !gd::is_empty(state, target) ? _stack_label(state, target) : static_cast<Atom>(key::the_front_rank);
		return gd::format(state, key::s_is_set_to_strike_s, { str(enemy_label), str(target_label) });
	}
	if (action_id == key::advance) {
		return gd::format(state, key::s_is_set_to_close_the, { str(_stack_label(state, enemy_stack)) });
	}
	if (action_id == key::defend) {
		return gd::format(state, key::s_is_set_to_hold_and, { str(_stack_label(state, enemy_stack)) });
	}
	if (action_id == key::wait) {
		return gd::format(state, key::s_is_set_to_wait_and, { str(_stack_label(state, enemy_stack)) });
	}
	return gd::format(state, key::s_is_best_placed_to_keep, { str(_stack_label(state, enemy_stack)) });
}

Atom _attack_action_summary(State &state, DictRef attacker, DictRef target, DictRef battle, bool is_ranged) {
	if (gd::is_empty(state, attacker) || gd::is_empty(state, target)) {
		return key::no_clean_target_is_lined_up;
	}
	if (ai::string_or_empty(state, attacker, key::battle_id) == ai::string_or_empty(state, battle, key::active_stack_id)) {
		const DictRef exchange = attack_consequence_preview(state, battle, is_ranged ? key::shoot : key::strike, ai::string_or_empty(state, target, key::battle_id), state.new_dict());
		if (gd::bool_field(state, exchange, key::ok, false)) {
			return gd::replace(state, gd::stringify(state, gd::index(state, exchange, str(key::message))), key::newline, key::space_bar_space);
		}
	}
	if (!is_ranged) {
		const DictRef approach = melee_approach_destination(state, battle, attacker, target);
		if (!gd::is_empty(state, approach)) {
			const Atom hex_label = _hex_label(state, approach);
			return gd::format(state, key::move_to_s_and_strike_s, { str(hex_label), str(_stack_label(state, target)) });
		}
	}
	const int64_t attack_distance = _attack_distance_for_action(state, attacker, target, battle, is_ranged);
	const DictRef attack_preview = _damage_range_preview(state, attacker, target, battle, is_ranged, false, attack_distance);
	if (gd::is_empty(state, attack_preview)) {
		return key::no_clean_target_is_lined_up;
	}
	std::vector<Atom> clauses;
	{
		const Atom target_label = _stack_label(state, target);
		const Atom preview_text = _damage_preview_text(state, attack_preview);
		clauses.push_back(gd::format(state, key::s_s_for_s, { str(is_ranged ? key::fire_on : key::Hit), str(target_label), str(preview_text) }));
	}
	if (is_ranged) {
		const int64_t shots_after = std::max<int64_t>(0, gd::sub(gd::int_field(state, attacker, key::shots_remaining, 0), 1));
		clauses.push_back(gd::format(state, key::shots_after_volley_d, { int_value(shots_after) }));
		const double ranged_return = _ranged_damage_return_ratio(state, target);
		if (ranged_return > 0.0) {
			const DictRef shielding = _ability_by_id(state, target, key::shielding);
			const Atom shielding_name = name_or(state, shielding, key::shielding_label);
			const int64_t percent = compat::float_to_int(compat::godot_round(ranged_return * 100.0));
			clauses.push_back(gd::format(state, key::s_returns_d_of_damage_received, { str(shielding_name), int_value(percent) }));
		}
		if (_side_controls_field_objective_type(state, battle, ai::string_or_empty(state, target, key::side), key::cover_line) && attack_distance > 0) {
			clauses.push_back(key::enemy_cover_will_blunt_part_of);
		} else if (_side_controls_field_objective_type(state, battle, ai::string_or_empty(state, attacker, key::side), key::cover_line) && attack_distance > 0) {
			clauses.push_back(key::friendly_cover_keeps_the_firing_angle);
		}
	} else {
		if (gd::int_field(state, target, key::retaliations_left, 0) > 0 && _can_make_retaliation(state, target, attack_distance, battle)) {
			const DictRef retaliation_preview = _retaliation_range_preview(state, attacker, target, battle, attack_distance, attack_preview);
			if (!gd::is_empty(state, retaliation_preview)) {
				clauses.push_back(gd::format(state, key::expect_s_retaliation, { str(_damage_preview_text(state, retaliation_preview)) }));
			}
		} else {
			clauses.push_back(key::retaliation_is_spent_or_blocked);
		}
	}
	const Atom side = ai::string_or_empty(state, attacker, key::side);
	const Atom battle_id = ai::string_or_empty(state, attacker, key::battle_id);
	const Atom target_battle_id = ai::string_or_empty(state, target, key::battle_id);
	const DictRef context = action_context(state, is_ranged ? key::shoot : key::strike, side, battle_id);
	state.set(context, str(key::target_battle_id), str(target_battle_id));
	const Atom objective_preview = _field_objective_action_preview(state, battle, context);
	if (objective_preview != key::empty) {
		clauses.push_back(objective_preview);
	}
	return clauses_sentence(state, clauses);
}

Atom _attack_unavailable_summary(State &state, DictRef attacker, DictRef target, DictRef battle, bool is_ranged) {
	if (gd::is_empty(state, attacker)) {
		return key::no_stack_is_ready_to_act;
	}
	if (gd::is_empty(state, target)) {
		return key::no_target_selected_text;
	}
	const Atom target_label = _stack_label(state, target);
	const DictRef legality = _attack_legality_for_target(state, attacker, target, battle);
	if (is_ranged) {
		if (!gd::bool_field(state, attacker, key::ranged, false)) {
			if (gd::bool_field(state, legality, key::melee, false)) {
				return gd::format(state, key::s_has_no_ranged_attack_strike, { str(_stack_label(state, attacker)), str(target_label) });
			}
			return gd::format(state, key::s_has_no_ranged_attack_s, { str(_stack_label(state, attacker)), str(target_label) });
		}
		if (gd::int_field(state, attacker, key::shots_remaining, 0) <= 0) {
			if (gd::bool_field(state, legality, key::melee, false)) {
				return gd::format(state, key::no_shots_remain_strike_is_legal, { str(target_label) });
			}
			return gd::format(state, key::no_shots_remain_and_s_is, { str(target_label) });
		}
		return gd::format(state, key::s_is_not_a_legal_ranged, { str(target_label) });
	}
	if (gd::bool_field(state, legality, key::ranged, false)) {
		return gd::format(state, key::s_is_outside_melee_reach_shoot, { str(target_label) });
	}
	if (gd::bool_field(state, legality, key::blocked, false)) {
		if (state.array_size(_legal_attack_target_ids_for_active_stack(state, battle)) != 0) {
			return gd::format(state, key::s_is_blocked_for_strike_from, { str(target_label) });
		}
		return gd::format(state, key::s_is_blocked_for_strike_from_2, { str(target_label) });
	}
	return key::close_the_distance_or_secure_a;
}

Atom _target_focus_action_line(State &state, DictRef active_stack, DictRef target, DictRef battle) {
	if (gd::is_empty(state, target)) {
		return key::no_target_selected_2;
	}
	const Atom target_label = _stack_label(state, target);
	if (gd::is_empty(state, active_stack) || ai::string_or_empty(state, active_stack, key::side) != key::player) {
		return target_label;
	}
	const DictRef legality = _attack_legality_for_target(state, active_stack, target, battle);
	const DictRef closing_context = selected_target_closing_context(state, battle, true);
	if (!gd::is_empty(state, closing_context)) {
		if (gd::bool_field(state, legality, key::attackable, false)) {
			const Atom closing_action_label = gd::stringify(state, gd::field_or(state, closing_context, key::board_click_label, str(key::attack)));
			return gd::format(state, key::s_closing_click_s, { str(target_label), str(closing_action_label) });
		}
		if (gd::bool_field(state, legality, key::blocked, false)) {
			return gd::format(state, key::s_closing_blocked, { str(target_label) });
		}
	}
	if (gd::bool_field(state, legality, key::attackable, false)) {
		const DictRef click_intent = board_click_attack_intent_for_target(state, battle, ai::string_or_empty(state, target, key::battle_id));
		const Atom action_label = ai::string_or_empty(state, click_intent, key::label);
		if (action_label != key::empty) {
			return gd::format(state, key::s_board_click_s, { str(target_label), str(action_label) });
		}
		return gd::format(state, key::s_board_click_attacks, { str(target_label) });
	}
	if (gd::bool_field(state, legality, key::blocked, false)) {
		return gd::format(state, key::s_blocked_from_current_hex, { str(target_label) });
	}
	return target_label;
}

Atom _target_legality_line(State &state, DictRef active_stack, DictRef target, DictRef battle) {
	if (gd::is_empty(state, active_stack) || gd::is_empty(state, target) || ai::string_or_empty(state, active_stack, key::side) != key::player) {
		return key::empty;
	}
	const DictRef continuity_context = selected_target_continuity_context(state, battle);
	if (!gd::is_empty(state, continuity_context)) {
		const Value message = gd::field_or(state, continuity_context, key::message, str(key::empty));
		return gd::stringify(state, gd::field_or(state, continuity_context, key::target_line, message));
	}
	const DictRef closing_context = selected_target_closing_context(state, battle, true);
	if (!gd::is_empty(state, closing_context)) {
		const Value message = gd::field_or(state, closing_context, key::message, str(key::empty));
		return gd::stringify(state, gd::field_or(state, closing_context, key::target_line, message));
	}
	const DictRef legality = _attack_legality_for_target(state, active_stack, target, battle);
	if (gd::bool_field(state, legality, key::attackable, false)) {
		const DictRef click_intent = board_click_attack_intent_for_target(state, battle, ai::string_or_empty(state, target, key::battle_id));
		const Atom action_label = gd::stringify(state, gd::field_or(state, click_intent, key::label, str(key::attack)));
		return gd::format(state, key::target_legality_board_click_will_s, { str(action_label), str(_stack_label(state, target)) });
	}
	if (gd::bool_field(state, legality, key::blocked, false)) {
		if (state.array_size(_legal_attack_target_ids_for_active_stack(state, battle)) != 0) {
			return gd::format(state, key::selected_target_blocked_this_hex_cannot, { str(_stack_label(state, target)) });
		}
		return gd::format(state, key::selected_target_blocked_this_hex_cannot_2, { str(_stack_label(state, target)) });
	}
	return key::empty;
}

Atom _advance_action_summary(State &state, DictRef battle, DictRef stack) {
	std::vector<Atom> clauses;
	const bool stalled = _advance_stalled_by_obstruction(state, stack, battle);
	DictRef destination = state.new_dict();
	if (stalled) {
		clauses.push_back(key::press_into_the_obstruction_line_without);
	} else {
		const DictRef nearest = battle_ai_rules::advance_target(state, battle, stack);
		const int64_t desired_gap = _advance_desired_gap(state, stack, battle);
		destination = battle_ai_rules::best_advance_destination(state, battle, stack, nearest, desired_gap);
		if (gd::is_empty(state, destination)) {
			clauses.push_back(key::no_open_hex_to_move_into);
		} else {
			const int64_t steps = gd::int_field(state, destination, key::steps, 1);
			const Atom plural = steps == 1 ? static_cast<Atom>(key::empty) : static_cast<Atom>(key::es);
			clauses.push_back(gd::format(state, key::move_d_hex_s_toward_s, { int_value(steps), str(plural), str(_stack_label(state, nearest)) }));
			clauses.push_back(key::move_hex_clicks_choose_exact_movement);
		}
	}
	const int64_t momentum_gain = _preview_advance_momentum_gain(state, stack, battle);
	if (momentum_gain > 0) {
		clauses.push_back(gd::format(state, key::momentum_d, { int_value(momentum_gain) }));
	}
	if (_side_controls_field_objective_type(state, battle, _opposing_side(ai::string_or_empty(state, stack, key::side)), key::obstruction_line)) {
		if (!stalled) {
			clauses.push_back(key::enemy_obstruction_will_still_tax_the);
		} else {
			clauses.push_back(key::enemy_obstruction_can_still_hold_the);
		}
	} else if (_side_controls_field_objective_type(state, battle, _opposing_side(ai::string_or_empty(state, stack, key::side)), key::cover_line)) {
		clauses.push_back(key::closing_also_strips_hostile_cover);
	}
	if (!gd::bool_field(state, stack, key::ranged, false) && !gd::is_empty(state, destination) && _projected_min_opposing_hex_distance(state, battle, stack, destination) <= 1) {
		clauses.push_back(key::melee_contact_opens_immediately);
	}
	const Atom side = ai::string_or_empty(state, stack, key::side);
	const DictRef context = action_context(state, key::advance, side, ai::string_or_empty(state, stack, key::battle_id));
	const Atom objective_preview = _field_objective_action_preview(state, battle, context);
	if (objective_preview != key::empty) {
		clauses.push_back(objective_preview);
	}
	return clauses_sentence(state, clauses);
}

Atom _defend_action_summary(State &state, DictRef battle, DictRef stack) {
	std::vector<Atom> clauses;
	clauses.push_back(key::brace_this_stack_for_the_next);
	const int64_t cohesion_gain = _preview_defend_cohesion_gain(state, stack, battle);
	if (cohesion_gain > 0) {
		clauses.push_back(gd::format(state, key::cohesion_d, { int_value(cohesion_gain) }));
	}
	if (gd::int_field(state, stack, key::momentum, 0) > 0) {
		clauses.push_back(key::shed_1_momentum);
	}
	if (gd::bool_field(state, stack, key::ranged, false)) {
		clauses.push_back(key::protect_the_firing_lane);
	} else if (gd::int_field(state, stack, key::retaliations_left, 0) > 0) {
		clauses.push_back(key::retaliation_stays_live);
	}
	if (_side_controls_field_objective_type(state, battle, ai::string_or_empty(state, stack, key::side), key::cover_line)) {
		clauses.push_back(key::hold_the_screened_cover_line);
	}
	if (_side_controls_field_objective_type(state, battle, ai::string_or_empty(state, stack, key::side), key::obstruction_line)) {
		clauses.push_back(key::keep_the_obstruction_sealed);
	}
	if (_brace_available(state, stack, battle)) {
		clauses.push_back(key::brace_can_stagger_the_next_attacker);
	} else if (_has_ability(state, stack, key::formation_guard)) {
		clauses.push_back(key::formation_guard_steadies_nearby_lanes);
	}
	const Atom side = ai::string_or_empty(state, stack, key::side);
	const DictRef context = action_context(state, key::defend, side, ai::string_or_empty(state, stack, key::battle_id));
	const Atom objective_preview = _field_objective_action_preview(state, battle, context);
	if (objective_preview != key::empty) {
		clauses.push_back(objective_preview);
	}
	return clauses_sentence(state, clauses);
}

int64_t _preview_advance_momentum_gain(State &state, DictRef stack, DictRef battle) {
	if (gd::is_empty(state, stack)) {
		return 0;
	}
	const auto ranged = [&]() { return gd::bool_field(state, stack, key::ranged, false); };
	const auto side = [&]() { return ai::string_or_empty(state, stack, key::side); };
	int64_t momentum_gain = !ranged() ? 1 : 0;
	if (_hero_has_trait(state, battle, side(), key::vanguard) && !ranged()) {
		momentum_gain = gd::add(momentum_gain, 1);
	}
	if (_hero_has_trait(state, battle, side(), key::ambusher) && _battle_has_any_tags(state, battle, string_array(state, { key::ambush_cover })) && !ranged()) {
		momentum_gain = gd::add(momentum_gain, 1);
	}
	if (_battle_has_tag(state, battle, key::open_lane) && (!ranged() || _hero_has_trait(state, battle, side(), key::artillerist))) {
		momentum_gain = gd::add(momentum_gain, 1);
	}
	if (_side_controls_field_objective_type(state, battle, side(), key::obstruction_line) && !ranged()) {
		momentum_gain = gd::add(momentum_gain, 1);
	}
	if (_side_controls_field_objective_type(state, battle, _opposing_side(side()), key::obstruction_line)) {
		if (_stack_can_breach_obstruction(state, stack, battle)) {
			momentum_gain = gd::sub(momentum_gain, 1);
		} else {
			momentum_gain = 0;
		}
	}
	return std::max<int64_t>(0, momentum_gain);
}

int64_t _preview_defend_cohesion_gain(State &state, DictRef stack, DictRef battle) {
	if (gd::is_empty(state, stack)) {
		return 0;
	}
	int64_t cohesion_gain = 1;
	const DictRef brace = _ability_by_id(state, stack, key::brace);
	if (!gd::is_empty(state, brace) && _brace_available(state, stack, battle)) {
		cohesion_gain = gd::add(cohesion_gain, std::max<int64_t>(0, gd::int_field(state, brace, key::defending_cohesion_bonus, 0)));
	}
	const DictRef bramble_ground = _bramble_ground_ability(state, stack);
	if (!gd::is_empty(state, bramble_ground) && _bramble_ground_available(state, stack, battle, bramble_ground)) {
		cohesion_gain = gd::add(cohesion_gain, std::max<int64_t>(0, gd::int_field(state, bramble_ground, key::defending_cohesion_bonus, 0)));
	}
	const DictRef formation_guard = _ability_by_id(state, stack, key::formation_guard);
	if (!gd::is_empty(state, formation_guard)) {
		cohesion_gain = gd::add(cohesion_gain, std::max<int64_t>(0, gd::int_field(state, formation_guard, key::defending_cohesion_bonus, 0)));
	}
	if (_hero_has_trait(state, battle, ai::string_or_empty(state, stack, key::side), key::linekeeper)) {
		cohesion_gain = gd::add(cohesion_gain, 1);
	}
	if (_battle_has_any_tags(state, battle, string_array(state, { key::chokepoint, key::fortified_line })) && !gd::bool_field(state, stack, key::ranged, false)) {
		cohesion_gain = gd::add(cohesion_gain, 1);
	}
	if (_side_controls_field_objective_type(state, battle, ai::string_or_empty(state, stack, key::side), key::cover_line)) {
		cohesion_gain = gd::add(cohesion_gain, 1);
	}
	if (_side_controls_field_objective_type(state, battle, ai::string_or_empty(state, stack, key::side), key::obstruction_line) && !gd::bool_field(state, stack, key::ranged, false)) {
		cohesion_gain = gd::add(cohesion_gain, 1);
	}
	return std::max<int64_t>(0, cohesion_gain);
}

Atom _active_ability_window_summary(State &state, DictRef stack, DictRef battle, DictRef target) {
	if (gd::is_empty(state, stack)) {
		return key::empty;
	}
	const auto ranged = [&]() { return gd::bool_field(state, stack, key::ranged, false); };
	const DictRef charter_brace = _ability_by_id(state, stack, key::brace);
	if (gd::float_field(state, charter_brace, key::ally_retaliation_multiplier, 1.0) > 1.0) {
		const ArrayRef allies = _alive_stacks_for_side(state, battle, ai::string_or_empty(state, stack, key::side));
		const int64_t ally_count = state.array_size(allies);
		for (int64_t index = 0; index < ally_count; ++index) {
			const DictRef ally = gd::as_dict(state.at(allies, index));
			if (ai::string_or_empty(state, ally, key::battle_id) == ai::string_or_empty(state, stack, key::battle_id)) {
				continue;
			}
			const DictRef aura_context = _charter_retaliation_aura_context(state, ally, battle);
			if (aura_source_battle_id(state, aura_context) != ai::string_or_empty(state, stack, key::battle_id)) {
				continue;
			}
			if (gd::bool_field(state, ally, key::defending, false)) {
				const Atom brace_name = name_or(state, charter_brace, key::charter_lock);
				return gd::format(state, key::s_is_raising_s_s_retaliation, { str(brace_name), str(_stack_label(state, ally)) });
			}
		}
		return gd::format(state, key::s_is_waiting_for_another_veteran, { str(name_or(state, charter_brace, key::charter_lock)) });
	}
	const DictRef fog_screen = _fog_screen_ability(state, stack);
	if (!gd::is_empty(state, fog_screen)) {
		if (_fog_screen_available(state, stack, battle, fog_screen)) {
			return gd::format(state, key::s_is_live_in_this_fog, { str(name_or(state, fog_screen, key::fog_screen_2)) });
		}
		return gd::format(state, key::s_is_waiting_for_a_natural, { str(name_or(state, fog_screen, key::fog_screen_2)) });
	}
	const DictRef readiness_writ = _readiness_writ_ability(state, stack);
	if (!gd::is_empty(state, readiness_writ)) {
		int64_t used = 0;
		if (ability_use_count(state, stack, key::readiness_writ, used) && used >= gd::int_field(state, readiness_writ, key::uses_per_battle, 1)) {
			return gd::format(state, key::s_has_already_steadied_one_allied, { str(name_or(state, readiness_writ, key::readiness_writ_name)) });
		}
		const DictRef readiness_target = _readiness_writ_target(state, battle, stack, readiness_writ);
		if (!gd::is_empty(state, readiness_target)) {
			const Atom writ_name = name_or(state, readiness_writ, key::readiness_writ_name);
			return gd::format(state, key::s_will_clear_the_disruption_from, { str(writ_name), str(_stack_label(state, readiness_target)) });
		}
	}
	const int64_t distance = gd::int_field(state, battle, key::distance, 1);
	if (_reach_available(state, stack, battle) && !ranged() && distance == 1) {
		return key::reach_makes_melee_contact_live_from;
	}
	if (_has_ability(state, stack, key::hookline) && gd::int_field(state, battle, key::round, 1) < gd::int_field(state, _ability_by_id(state, stack, key::hookline), key::available_from_round, 1)) {
		return gd::format(state, key::s_is_waiting_for_the_midline, { str(name_or(state, _ability_by_id(state, stack, key::hookline), key::Hookline)) });
	}
	if (_hookline_available(state, stack, battle) && !ranged() && distance == 1) {
		return gd::format(state, key::s_can_pin_the_selected_line, { str(name_or(state, _ability_by_id(state, stack, key::hookline), key::Hookline)) });
	}
	if (_has_ability(state, stack, key::hookline) && !_hookline_available(state, stack, battle)) {
		return gd::format(state, key::s_has_already_been_spent_this, { str(name_or(state, _ability_by_id(state, stack, key::hookline), key::Hookline)) });
	}
	if (_has_ability(state, stack, key::volley) && ranged() && distance >= gd::int_field(state, _ability_by_id(state, stack, key::volley), key::min_distance, 1)) {
		const DictRef active_volley = _ability_by_id(state, stack, key::volley);
		if (gd::bool_field(state, active_volley, key::requires_protected_lane, false)) {
			if (_volley_has_protected_lane(state, stack, battle, active_volley)) {
				return gd::format(state, key::s_has_full_pressure_behind_the, { str(name_or(state, active_volley, key::Volley)) });
			}
			return gd::format(state, key::s_needs_a_defending_allied_screen, { str(name_or(state, active_volley, key::Volley)) });
		}
		return key::volley_rewards_the_long_lane_while;
	}
	if (_has_ability(state, stack, key::obituary) && ranged()) {
		const DictRef obituary = _ability_by_id(state, stack, key::obituary);
		int64_t used = 0;
		if (ability_use_count(state, stack, key::obituary, used) && used >= gd::int_field(state, obituary, key::uses_per_battle, 1)) {
			return key::final_notice_has_already_been_issued;
		}
		if (!gd::is_empty(state, target) && _brace_available(state, target, battle) && gd::int_field(state, target, key::tier, 1) >= gd::int_field(state, obituary, key::braced_target_min_tier, 2)) {
			return key::final_notice_prioritizes_this_veteran_braced;
		}
		return key::final_notice_will_drain_the_target;
	}
	if (_has_ability(state, stack, key::rot_cant) && ranged()) {
		const DictRef rot_cant = _ability_by_id(state, stack, key::rot_cant);
		if (gd::int_field(state, battle, key::round, 1) < gd::int_field(state, rot_cant, key::available_from_round, 1)) {
			return gd::format(state, key::s_is_waiting_for_the_midline, { str(name_or(state, rot_cant, key::rot_cant_2)) });
		}
		int64_t used = 0;
		if (ability_use_count(state, stack, key::rot_cant, used) && used >= gd::int_field(state, rot_cant, key::uses_per_battle, 1)) {
			return gd::format(state, key::s_has_already_been_placed_this, { str(name_or(state, rot_cant, key::rot_cant_2)) });
		}
		const int64_t rot_min_tier = gd::int_field(state, rot_cant, key::target_min_tier, 1);
		if (gd::is_empty(state, target) || gd::int_field(state, target, key::tier, 1) < rot_min_tier) {
			return gd::format(state, key::s_is_waiting_for_a_tier, { str(name_or(state, rot_cant, key::rot_cant_2)), int_value(rot_min_tier) });
		}
		return gd::format(state, key::s_will_rot_call_this_veteran, { str(name_or(state, rot_cant, key::rot_cant_2)) });
	}
	if (_has_ability(state, stack, key::harry) && ranged()) {
		const DictRef harry = _ability_by_id(state, stack, key::harry);
		const int64_t uses_per_battle = gd::int_field(state, harry, key::uses_per_battle, 0);
		int64_t used = 0;
		if (uses_per_battle > 0 && ability_use_count(state, stack, key::harry, used) && used >= uses_per_battle) {
			return gd::format(state, key::s_has_already_been_placed_this, { str(name_or(state, harry, key::Harry)) });
		}
		const Atom modifier_text = _ability_modifier_text(state, harry);
		const Atom pressure_summary = modifier_text != key::empty ? gd::format(state, key::s_3, { str(modifier_text) }) : static_cast<Atom>(key::empty);
		const int64_t target_min_tier = gd::int_field(state, harry, key::target_min_tier, 1);
		if (target_min_tier > 1 && (gd::is_empty(state, target) || gd::int_field(state, target, key::tier, 1) < target_min_tier)) {
			return gd::format(state, key::s_is_waiting_for_a_tier, { str(name_or(state, harry, key::Harry)), int_value(target_min_tier) });
		}
		const DictRef authored_harry = _authored_ability_by_id(state, stack, key::harry);
		const DictRef target_shielding = _authored_ability_by_id(state, target, key::shielding);
		if (!gd::is_empty(state, target_shielding) && gd::bool_field(state, target_shielding, key::snare_vulnerable, false) && gd::float_field(state, authored_harry, key::shielding_damage_multiplier, 1.0) > 1.0) {
			return gd::format(state, key::s_will_foul_this_shield_screen, { str(name_or(state, harry, key::Harry)), str(pressure_summary) });
		}
		return gd::format(state, key::s_will_mark_the_target_s, { str(name_or(state, harry, key::Harry)), str(pressure_summary) });
	}
	if (_has_ability(state, stack, key::harry) && !ranged() && gd::int_field(state, _ability_by_id(state, stack, key::harry), key::min_adjacent_allies_to_target, 0) > 0) {
		const DictRef supported_harry = _ability_by_id(state, stack, key::harry);
		int64_t used = 0;
		if (ability_use_count(state, stack, key::harry, used) && used >= gd::int_field(state, supported_harry, key::uses_per_battle, 0) && gd::int_field(state, supported_harry, key::uses_per_battle, 0) > 0) {
			return gd::format(state, key::s_has_already_been_placed_this, { str(name_or(state, supported_harry, key::Harry)) });
		}
		const int64_t target_min_tier = gd::int_field(state, supported_harry, key::target_min_tier, 1);
		if (gd::is_empty(state, target) || gd::int_field(state, target, key::tier, 1) < target_min_tier) {
			return gd::format(state, key::s_is_waiting_for_a_tier, { str(name_or(state, supported_harry, key::Harry)), int_value(target_min_tier) });
		}
		const Atom target_role = ai::string_or_empty(state, supported_harry, key::target_role);
		if (target_role != key::empty && gd::bool_field(state, target, key::ranged, false) != (target_role == key::ranged)) {
			return gd::format(state, key::s_is_waiting_for_a_s, { str(name_or(state, supported_harry, key::Harry)), str(target_role) });
		}
		const int64_t required_support = gd::int_field(state, supported_harry, key::min_adjacent_allies_to_target, 0);
		if (!_harry_support_ready(state, stack, target, battle, supported_harry)) {
			const Atom authored_blocked_summary = ai::string_or_empty(state, supported_harry, key::support_blocked_summary);
			if (authored_blocked_summary != key::empty) {
				return authored_blocked_summary;
			}
			const Atom plural = required_support == 1 ? static_cast<Atom>(key::empty) : static_cast<Atom>(key::s);
			return gd::format(state, key::s_needs_d_allied_stack_s, { str(name_or(state, supported_harry, key::Harry)), int_value(required_support), str(plural) });
		}
		const Atom authored_ready_summary = ai::string_or_empty(state, supported_harry, key::support_ready_summary);
		if (authored_ready_summary != key::empty) {
			return authored_ready_summary;
		}
		return gd::format(state, key::s_will_close_the_supported_snare, { str(name_or(state, supported_harry, key::Harry)) });
	}
	if (_brace_available(state, stack, battle) && gd::int_field(state, stack, key::retaliations_left, 0) > 0) {
		return key::brace_can_stagger_the_next_attacker_2;
	}
	if (_has_ability(state, stack, key::formation_guard)) {
		return key::formation_guard_is_live_if_this;
	}
	if (_has_ability(state, stack, key::solar_array_lane)) {
		const DictRef array_lane = _ability_by_id(state, stack, key::solar_array_lane);
		const Atom side = ai::string_or_empty(state, stack, key::side);
		if (_side_has_linked_unit(state, battle, side, field_or_strings(state, array_lane, key::linked_unit_ids, {}))) {
			return key::solar_array_lanes_are_screening_allied;
		}
		return key::solar_array_lanes_are_waiting_for;
	}
	if (_has_ability(state, stack, key::sporeglass_mend) && ranged()) {
		return key::mending_fire_will_repair_an_injured;
	}
	if (_has_ability(state, stack, key::pressure_artillery) && ranged()) {
		const DictRef pressure_artillery = _ability_by_id(state, stack, key::pressure_artillery);
		const DictRef clustered_target = _pressure_artillery_secondary_target(state, battle, stack, target);
		const Atom cluster_text = !gd::is_empty(state, clustered_target) ? gd::format(state, key::and_throw_fragments_into_s, { str(_stack_label(state, clustered_target)) }) : static_cast<Atom>(key::empty);
		return gd::format(state, key::s_will_fire_s_then_run, { str(name_or(state, pressure_artillery, key::pressure_artillery_name)), str(cluster_text) });
	}
	if (_has_ability(state, stack, key::counter_ambush_flare)) {
		return key::counter_ambush_flare_is_exposing_backstab;
	}
	if (_has_ability(state, stack, key::foundry_aura)) {
		return key::saint_s_temper_is_hardening_overheated;
	}
	if (_has_ability(state, stack, key::overheat)) {
		if (spell_rules::has_effect_id(state, stack, battle, key::status_overheated)) {
			return key::the_debt_furnace_is_overheated_damage;
		}
		return key::the_debt_furnace_is_pressure_ready;
	}
	// The backstab payoff: the target carries one of its statuses or is wounded
	// below its threshold.
	const auto backstab_payoff = [&]() {
		if (spell_rules::has_any_effect_ids(state, target, battle, field_or_strings(state, _ability_by_id(state, stack, key::backstab), key::status_ids, {}))) {
			return true;
		}
		return _health_ratio(state, target) <= gd::float_field(state, _ability_by_id(state, stack, key::backstab), key::health_threshold_ratio, 0.0);
	};
	if (!gd::is_empty(state, target) && _has_ability(state, stack, key::backstab) && !gd::is_empty(state, _counter_ambush_flare_context(state, battle, target, key::backstab)) && backstab_payoff()) {
		return key::counter_ambush_flare_exposes_this_backstab;
	}
	if (!gd::is_empty(state, target) && _has_ability(state, stack, key::fogwake) && _stack_is_hex_isolated(state, battle, target) && !gd::is_empty(state, _counter_ambush_flare_context(state, battle, target, key::fogwake))) {
		return key::counter_ambush_flare_exposes_this_fogwake;
	}
	if (!gd::is_empty(state, target) && _has_ability(state, stack, key::backstab) && backstab_payoff()) {
		return key::backstab_is_live_on_the_marked;
	}
	if (!gd::is_empty(state, target) && _has_ability(state, stack, key::bloodrush)) {
		const DictRef bloodrush = _ability_by_id(state, stack, key::bloodrush);
		if (_health_ratio(state, target) <= gd::float_field(state, bloodrush, key::wounded_threshold_ratio, 0.0)
				|| spell_rules::has_any_effect_ids(state, target, battle, field_or_strings(state, bloodrush, key::status_ids, {}))
				|| (gd::float_field(state, bloodrush, key::isolated_damage_multiplier, 1.0) > 1.0 && _stack_is_hex_isolated(state, battle, target))) {
			return key::bloodrush_is_live_through_the_prepared;
		}
		if (gd::float_field(state, bloodrush, key::clean_target_damage_multiplier, 1.0) < 1.0) {
			if (gd::float_field(state, bloodrush, key::isolated_damage_multiplier, 1.0) > 1.0) {
				return key::bloodrush_needs_wounded_disrupted_or_isolated;
			}
			return key::bloodrush_needs_a_wounded_or_disrupted;
		}
	}
	if (!gd::is_empty(state, target) && _has_ability(state, stack, key::shielding)
			&& spell_rules::has_any_effect_ids(state, target, battle, field_or_strings(state, _ability_by_id(state, stack, key::shielding), key::payoff_status_ids, { key::status_harried }))) {
		return key::shielding_bites_harder_into_a_marked;
	}
	if (!gd::is_empty(state, target) && _has_ability(state, stack, key::fogwake) && _stack_is_hex_isolated(state, battle, target)) {
		return key::leviathan_fogwake_is_live_because_the;
	}
	const Atom ability_summary = _stack_ability_summary(state, stack);
	return ability_summary != key::empty ? gd::format(state, key::abilities_in_hand_s, { str(ability_summary) }) : static_cast<Atom>(key::empty);
}

} // namespace battle_rules

} // namespace aurelion::rules::port
