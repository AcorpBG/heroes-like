// Slice 10: BattleAutoResolveRules, the autoplay order of a player stack and the
// loop that resolves a whole battle order by order, with its result payload.

#include "aurelion_rules/port/battle_auto_resolve_rules.hpp"

#include "aurelion_rules/port/battle_ai_rules.hpp"
#include "aurelion_rules/port/battle_rules.hpp"
#include "aurelion_rules/port/spell_rules.hpp"

namespace aurelion::rules::port::battle_auto_resolve_rules {

using gd::Atom;
using gd::DictRef;
using state::State;
using state::Value;
using gd::bool_value;
using gd::dict_value;
using gd::int_value;
using gd::str;
using state::Kind;
namespace key = state::key;
namespace rules = battle_rules;

namespace {

// session.battle: SessionData.battle is a typed Dictionary. Read afresh each
// time the GDScript reads it: a finalize ends the battle with a new one.
DictRef session_battle(State &state, const Value &session) {
	return gd::as_dict(gd::member(state, session, key::battle));
}

// String(d.get(field, "")).
Atom string_or_empty(const State &state, DictRef dict, Atom field) {
	return gd::string_field(state, dict, field, key::empty);
}

// x in PLAYER_EXIT_ACTIONS: ["retreat", "surrender"].
bool is_player_exit_action(Atom action) {
	return action == key::retreat || action == key::surrender;
}

// {"action": "defend", "reason": reason, "scoring_policy": "battle_ai_nonspell_tactical_order_v1"}
DictRef defend_order(State &state, Atom reason) {
	const DictRef order = state.new_dict();
	state.set(order, str(key::action), str(key::defend));
	state.set(order, str(key::reason), str(reason));
	state.set(order, str(key::scoring_policy), str(key::battle_ai_nonspell_tactical_order_v1));
	return order;
}

// d.get(field, {}) if d.get(field, {}) is Dictionary else {}
DictRef dict_or_new(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found) && gd::is_dict(found)) {
		return found.ref;
	}
	return state.new_dict();
}

// action_counts[action] = int(action_counts.get(action, 0)) + 1
void count_action(State &state, DictRef action_counts, Atom action) {
	state.set(action_counts, str(action), int_value(gd::add(gd::int_field(state, action_counts, action, 0), 1)));
}

} // namespace

DictRef player_autoplay_decision(State &state, const Value &session, bool apply_selection, bool allow_hero_cast) {
	if (session.kind == Kind::Nil || gd::is_empty(state, session_battle(state, session))) {
		return defend_order(state, key::no_active_battle);
	}
	const DictRef active_stack = rules::get_active_stack(state, session_battle(state, session));
	if (gd::is_empty(state, active_stack) || string_or_empty(state, active_stack, key::side) != key::player) {
		return defend_order(state, key::no_active_player_stack);
	}
	DictRef commander_payload = dict_or_new(state, session_battle(state, session), key::player_hero);
	if (gd::is_empty(state, commander_payload)) {
		Value commander_state;
		if (!state.lookup(session_battle(state, session), str(key::player_commander_state), commander_state)) {
			commander_payload = state.new_dict();
		} else if (gd::is_dict(commander_state)) {
			commander_payload = commander_state.ref;
		}
	}
	const DictRef decision = battle_ai_rules::choose_stack_tactical_order(state, session_battle(state, session), active_stack, key::enemy, commander_payload, allow_hero_cast);
	if (gd::is_empty(state, decision)) {
		return _fallback_player_autoplay_decision(state, session, key::no_scored_tactical_order, apply_selection, state.new_dict());
	}
	if (string_or_empty(state, decision, key::action) == key::advance) {
		const DictRef plan = rules::ai_advance_plan(state, session_battle(state, session), active_stack);
		if (gd::string_field(state, plan, key::action, key::advance) != key::advance) {
			state.set(decision, str(key::advance_plan), dict_value(gd::deep_duplicate_dict(state, plan)));
			state.set(decision, str(key::action), str(gd::string_field(state, plan, key::action, key::advance)));
			state.set(decision, str(key::target_battle_id), str(string_or_empty(state, plan, key::target_battle_id)));
		}
	}
	const Atom target_id = string_or_empty(state, decision, key::target_battle_id);
	const Atom action = gd::string_field(state, decision, key::action, key::defend);
	if (is_player_exit_action(action)) {
		return _fallback_player_autoplay_decision(state, session, key::player_exit_order_forbidden, apply_selection, decision);
	}
	if (target_id != key::empty) {
		if (apply_selection && (action == key::shoot || action == key::strike)) {
			const DictRef selection_result = rules::select_target(state, session, target_id);
			state.set(decision, str(key::target_selection_ok), bool_value(gd::bool_field(state, selection_result, key::ok, false)));
			state.set(decision, str(key::target_selection_message), str(string_or_empty(state, selection_result, key::message)));
		} else if (apply_selection && action == key::cast_spell) {
			rules::_set_selected_target(state, session_battle(state, session), target_id, true);
			const DictRef selected_spell_target = rules::_get_stack_by_id(state, session_battle(state, session), target_id);
			state.set(decision, str(key::target_selection_ok), bool_value(!gd::is_empty(state, selected_spell_target)));
			const Atom message = !gd::is_empty(state, selected_spell_target) ? static_cast<Atom>(key::spell_target_selected_for_autoplay_text) : static_cast<Atom>(key::spell_target_missing_for_autoplay_text);
			state.set(decision, str(key::target_selection_message), str(message));
		} else {
			state.set(decision, str(key::target_selection_ok), bool_value(true));
		}
	}
	if (action == key::cast_spell) {
		const Atom spell_id = string_or_empty(state, decision, key::spell_id);
		const DictRef spell_target_stack = rules::_get_stack_by_id(state, session_battle(state, session), target_id);
		// The spell is checked against the commander state the cast spends mana
		// from (BattleRules._player_spell_resolution), not battle.player_hero.
		const DictRef hero_state = rules::_player_commander_state(state, session);
		const DictRef validation = spell_rules::validate_battle_spell(state, hero_state, session_battle(state, session), active_stack, spell_target_stack, str(spell_id), key::player);
		if (gd::bool_field(state, validation, key::ok, false)) {
			state.set(decision, str(key::reason), str(key::scored_tactical_spell_order));
			return decision;
		}
		// The hero cannot cast it: the stack still gives its own order.
		const DictRef stack_order = player_autoplay_decision(state, session, apply_selection, false);
		state.set(stack_order, str(key::refused_hero_cast), dict_value(gd::deep_duplicate_dict(state, decision)));
		state.set(stack_order, str(key::spell_validation_message), str(gd::string_field(state, validation, key::message, key::spell_order_unavailable_text)));
		return stack_order;
	}
	const DictRef availability = rules::action_availability(state, session_battle(state, session));
	if (gd::bool_field(state, availability, action, false)) {
		state.set(decision, str(key::reason), str(key::scored_tactical_order));
		return decision;
	}
	return _fallback_player_autoplay_decision(state, session, key::scored_order_unavailable, apply_selection, decision);
}

DictRef resolve_active_battle(State &state, const Value &session, int64_t step_limit, int64_t stop_below_player_creatures) {
	if (session.kind == Kind::Nil) {
		return _resolve_result(state, Value(), false, key::invalid_session, key::invalid, 0, 0, 0, 0, 0, state.new_dict(), state.new_dict(), state.new_dict());
	}
	if (gd::is_empty(state, session_battle(state, session))) {
		return _resolve_result(state, session, false, key::no_active_battle, key::invalid, 0, 0, 0, 0, 0, state.new_dict(), state.new_dict(), state.new_dict());
	}
	if (step_limit <= 0) {
		return _resolve_result(state, session, false, key::invalid_step_limit, key::invalid, 0, 0, 0, 0, 0, state.new_dict(), state.new_dict(), state.new_dict());
	}
	if (stop_below_player_creatures > 0
			&& gd::int_field(state, rules::_hero_payload_for_side(state, session_battle(state, session), key::player), key::victory_recovery_pct, 0) > 0) {
		stop_below_player_creatures = 0;
	}

	int64_t steps = 0;
	int64_t player_orders = 0;
	int64_t enemy_ready_ticks = 0;
	int64_t invalid_orders = 0;
	int64_t forbidden_exit_orders = 0;
	const DictRef action_counts = state.new_dict();
	Atom final_state = key::continue_;
	Atom stop_reason = key::empty;
	DictRef last_result = state.new_dict();
	DictRef terminal_result = state.new_dict();
	while (steps < step_limit && !gd::is_empty(state, session_battle(state, session))) {
		if (stop_below_player_creatures > 0 && _player_creatures_standing(state, session_battle(state, session)) < stop_below_player_creatures) {
			stop_reason = key::player_losses;
			break;
		}
		steps += 1;
		const DictRef ready_result = rules::resolve_if_battle_ready(state, session);
		last_result = gd::deep_duplicate_dict(state, ready_result);
		final_state = gd::string_field(state, ready_result, key::state, key::continue_);
		if (is_terminal_state(final_state)) {
			terminal_result = gd::deep_duplicate_dict(state, ready_result);
			break;
		}
		if (gd::is_empty(state, session_battle(state, session))) {
			stop_reason = key::battle_cleared_without_terminal_state;
			break;
		}
		const DictRef active_stack = rules::get_active_stack(state, session_battle(state, session));
		if (string_or_empty(state, active_stack, key::side) != key::player) {
			enemy_ready_ticks += 1;
			continue;
		}
		DictRef decision = player_autoplay_decision(state, session, true, true);
		Atom action = gd::string_field(state, decision, key::action, key::defend);
		if (action == key::cast_spell) {
			// The hero's cast is a free action: the same stack still gives its
			// order in this step, so casting never uses up the step limit.
			const DictRef cast_result = _perform_player_order(state, session, decision, action);
			if (string_or_empty(state, cast_result, key::state) == key::invalid) {
				invalid_orders += 1;
			} else {
				count_action(state, action_counts, action);
				player_orders += 1;
				last_result = gd::deep_duplicate_dict(state, cast_result);
				final_state = gd::string_field(state, cast_result, key::state, final_state);
				if (is_terminal_state(final_state)) {
					terminal_result = gd::deep_duplicate_dict(state, cast_result);
					break;
				}
			}
			decision = player_autoplay_decision(state, session, true, false);
			action = gd::string_field(state, decision, key::action, key::defend);
		}
		if (is_player_exit_action(action)) {
			forbidden_exit_orders += 1;
			action = key::defend;
		}
		DictRef result = _perform_player_order(state, session, decision, action);
		if (string_or_empty(state, result, key::state) == key::invalid && action != key::defend) {
			invalid_orders += 1;
			action = key::defend;
			result = rules::perform_player_action(state, session, action, state.new_dict());
		}
		if (string_or_empty(state, result, key::state) == key::invalid) {
			invalid_orders += 1;
			last_result = gd::deep_duplicate_dict(state, result);
			final_state = key::invalid;
			stop_reason = key::fallback_defend_invalid;
			break;
		}
		count_action(state, action_counts, action);
		player_orders += 1;
		last_result = gd::deep_duplicate_dict(state, result);
		final_state = gd::string_field(state, result, key::state, final_state);
		if (is_terminal_state(final_state)) {
			terminal_result = gd::deep_duplicate_dict(state, result);
			break;
		}
	}

	const bool completed = is_terminal_state(final_state);
	if (!completed && stop_reason == key::empty && steps >= step_limit) {
		final_state = key::stalled_step_limit;
		stop_reason = key::step_limit_reached;
	}
	if (!completed && stop_reason == key::empty && gd::is_empty(state, session_battle(state, session))) {
		stop_reason = key::battle_cleared_without_terminal_state;
	}
	return _resolve_result(state, session, completed, stop_reason, final_state, steps, player_orders, enemy_ready_ticks, invalid_orders, forbidden_exit_orders, action_counts, terminal_result, last_result);
}

bool is_terminal_state(Atom state) {
	return state == key::victory
			|| state == key::defeat
			|| state == key::hero_defeat
			|| state == key::town_lost
			|| state == key::retreat
			|| state == key::surrender
			|| state == key::stalemate;
}

int64_t _player_creatures_standing(State &state, DictRef battle) {
	int64_t total = 0;
	for (const Value &stack : gd::field_items(state, battle, str(key::stacks))) {
		if (gd::is_dict(stack) && string_or_empty(state, stack.ref, key::side) == key::player) {
			total = gd::add(total, rules::_alive_count(state, stack.ref));
		}
	}
	return total;
}

DictRef _perform_player_order(State &state, const Value &session, DictRef decision, Atom action) {
	if (action == key::cast_spell) {
		return rules::cast_player_spell(state, session, string_or_empty(state, decision, key::spell_id), key::empty);
	}
	if (action == key::strike) {
		// The same approach choice as the enemy's (BattleRules.ai_melee_approach),
		// its arguments in the GDScript order.
		const DictRef battle = session_battle(state, session);
		const DictRef active_stack = rules::get_active_stack(state, session_battle(state, session));
		const DictRef selected_target = rules::get_selected_target(state, session_battle(state, session));
		const DictRef approach = rules::ai_melee_approach(state, battle, active_stack, selected_target);
		return rules::perform_player_action(state, session, action, approach);
	}
	return rules::perform_player_action(state, session, action, state.new_dict());
}

DictRef _fallback_player_autoplay_decision(State &state, const Value &session, Atom reason, bool apply_selection, DictRef scored_decision) {
	_select_focus_enemy(state, session);
	const DictRef availability = rules::action_availability(state, session_battle(state, session));
	Atom fallback_action = key::defend;
	if (gd::bool_field(state, availability, key::shoot, false)) {
		fallback_action = key::shoot;
	} else if (gd::bool_field(state, availability, key::strike, false)) {
		fallback_action = key::strike;
	} else if (gd::bool_field(state, availability, key::advance, false)) {
		fallback_action = key::advance;
	}
	const Atom target_battle_id = string_or_empty(state, session_battle(state, session), key::selected_target_id);
	const DictRef decision = state.new_dict();
	state.set(decision, str(key::action), str(fallback_action));
	state.set(decision, str(key::target_battle_id), str(target_battle_id));
	state.set(decision, str(key::reason), str(reason));
	state.set(decision, str(key::scoring_policy), str(key::battle_ai_nonspell_tactical_order_v1));
	state.set(decision, str(key::fallback_policy), str(key::legacy_availability_order));
	state.set(decision, str(key::scored_decision), dict_value(scored_decision));
	state.set(decision, str(key::applied_selection), bool_value(apply_selection));
	return decision;
}

void _select_focus_enemy(State &state, const Value &session) {
	Atom best_id = key::empty;
	int64_t best_health = 0;
	int64_t best_alive = 0;
	for (const Value &stack : gd::field_items(state, session_battle(state, session), str(key::stacks))) {
		if (!gd::is_dict(stack)) {
			continue;
		}
		if (string_or_empty(state, stack.ref, key::side) != key::enemy) {
			continue;
		}
		const int64_t alive = rules::_alive_count(state, stack.ref);
		if (alive <= 0) {
			continue;
		}
		const int64_t health = gd::int_field(state, stack.ref, key::total_health, 0);
		if (best_id == key::empty || health < best_health || (health == best_health && alive < best_alive)) {
			best_id = string_or_empty(state, stack.ref, key::battle_id);
			best_health = health;
			best_alive = alive;
		}
	}
	if (best_id != key::empty) {
		rules::select_target(state, session, best_id);
	}
}

DictRef _resolve_result(State &state, const Value &session, bool completed, Atom stop_reason, Atom result_state, int64_t steps, int64_t player_orders, int64_t enemy_ready_ticks, int64_t invalid_orders, int64_t forbidden_exit_orders, DictRef action_counts, DictRef terminal_result, DictRef last_result) {
	// The literal's values in its order.
	const DictRef action_counts_copy = gd::deep_duplicate_dict(state, action_counts);
	const DictRef terminal_result_copy = gd::deep_duplicate_dict(state, terminal_result);
	const DictRef last_result_copy = gd::deep_duplicate_dict(state, last_result);
	const bool has_session = session.kind != Kind::Nil;
	const bool battle_active = has_session && !gd::is_empty(state, session_battle(state, session));
	const Atom scenario_status = has_session ? gd::to_string(gd::member(state, session, key::scenario_status)) : static_cast<Atom>(key::empty);
	const Atom game_state = has_session ? gd::to_string(gd::member(state, session, key::game_state)) : static_cast<Atom>(key::empty);
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(completed && stop_reason == key::empty));
	state.set(result, str(key::completed), bool_value(completed));
	state.set(result, str(key::state), str(result_state));
	state.set(result, str(key::stop_reason), str(stop_reason));
	state.set(result, str(key::steps), int_value(steps));
	state.set(result, str(key::player_orders), int_value(player_orders));
	state.set(result, str(key::enemy_ready_ticks), int_value(enemy_ready_ticks));
	state.set(result, str(key::invalid_orders), int_value(invalid_orders));
	state.set(result, str(key::forbidden_exit_orders), int_value(forbidden_exit_orders));
	state.set(result, str(key::action_counts), dict_value(action_counts_copy));
	state.set(result, str(key::terminal_result), dict_value(terminal_result_copy));
	state.set(result, str(key::last_result), dict_value(last_result_copy));
	state.set(result, str(key::battle_active), bool_value(battle_active));
	state.set(result, str(key::scenario_status), str(scenario_status));
	state.set(result, str(key::game_state), str(game_state));
	return result;
}

} // namespace aurelion::rules::port::battle_auto_resolve_rules
