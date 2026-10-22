// Slice 09: BattleAiRules' decisions: the enemy's order and any stack's tactical
// order, the stack's own order weighed from its attack, defend and advance
// scores, the best strike in reach and how an advance is carried out. Each
// public entry point scores inside one scoring scope, as the GDScript does.

#include "aurelion_rules/port/battle_ai_rules.hpp"
#include "aurelion_rules/port/battle_rules.hpp"

#include <string>

namespace aurelion::rules::port::battle_ai_rules {

using gd::bool_value;
using gd::dict_value;
using gd::float_value;
using gd::int_value;
using gd::str;
namespace key = state::key;
namespace rules = battle_rules;

namespace {

bool empty(const State &state, DictRef dict) {
	return gd::is_empty(state, dict);
}

Atom side_of(const State &state, DictRef stack) {
	return gd::string_field(state, stack, key::side, key::empty);
}

// String(order.get("action", ""))
Atom action_of(const State &state, DictRef order) {
	return gd::string_field(state, order, key::action, key::empty);
}

// String(...) in ["retreat", "surrender"]: the enemy's withdrawal orders.
bool is_withdrawal(Atom action) {
	return action == key::retreat || action == key::surrender;
}

// var x: Dictionary = d.get(key, {}).
DictRef typed_dict_field(State &state, DictRef dict, Atom field) {
	Value found;
	if (!state.lookup(dict, str(field), found)) {
		return state.new_dict();
	}
	if (!gd::is_dict(found)) {
		throw state::ScriptError(std::string("Trying to assign value of type '") + gd::type_name(found) + "' to a variable of type 'Dictionary'.");
	}
	return found.ref;
}

// {"action": action}
DictRef plain_order(State &state, Atom action) {
	const DictRef order = state.new_dict();
	state.set(order, str(key::action), str(action));
	return order;
}

// {"action": action, "score": score}
DictRef scored_order(State &state, Atom action, double score) {
	const DictRef order = state.new_dict();
	state.set(order, str(key::action), str(action));
	state.set(order, str(key::score), float_value(score));
	return order;
}

// {"defend": defend_score, "advance": advance_score}
DictRef base_candidate_scores(State &state, double defend_score, double advance_score) {
	const DictRef scores = state.new_dict();
	state.set(scores, str(key::defend), float_value(defend_score));
	state.set(scores, str(key::advance), float_value(advance_score));
	return scores;
}

// candidate_scores[String(candidate.get("action", fallback))] = float(candidate.get("score", 0.0))
void add_candidate_score(State &state, DictRef scores, DictRef candidate, Atom fallback_action) {
	const Atom action = gd::string_field(state, candidate, key::action, fallback_action);
	state.set(scores, str(action), float_value(gd::float_field(state, candidate, key::score, 0.0)));
}

} // namespace

DictRef choose_enemy_action(State &state, DictRef battle, DictRef active_stack, DictRef enemy_hero, bool allow_hero_cast) {
	_open_scoring_scope(state);
	const DictRef action = _enemy_action_choice(state, battle, active_stack, enemy_hero, allow_hero_cast);
	_close_scoring_scope(state);
	return action;
}

DictRef _enemy_action_choice(State &state, DictRef battle, DictRef active_stack, DictRef enemy_hero, bool allow_hero_cast) {
	if (empty(state, active_stack) || side_of(state, active_stack) != key::enemy) {
		return state.new_dict();
	}

	const DictRef resolved_enemy_hero = _commander_payload_for_tactical_scoring(state, _enemy_hero_state_for_ai(state, battle, enemy_hero));
	const DictRef scoring_battle = _battle_with_enemy_hero_payload(state, battle, resolved_enemy_hero);
	const ArrayRef targets = _alive_stacks_for_side(state, scoring_battle, key::player);
	if (state.array_size(targets) == 0) {
		return state.new_dict();
	}

	const DictRef best_spell = allow_hero_cast ? _best_spell_action(state, scoring_battle, active_stack, resolved_enemy_hero, targets) : state.new_dict();
	const DictRef choice = _stack_order_choice(state, scoring_battle, active_stack, targets);
	DictRef best = typed_dict_field(state, choice, key::best);
	const DictRef best_attack = typed_dict_field(state, choice, key::best_attack);
	const bool lethal_attack_available = gd::bool_field(state, choice, key::lethal_attack_available, false);
	const bool lethal_spell_available = _candidate_is_lethal_damage_spell(state, best_spell, scoring_battle, resolved_enemy_hero);
	const double defend_score = gd::float_field(state, choice, key::defend_score, 0.0);
	const double advance_score = gd::float_field(state, choice, key::advance_score, 0.0);
	const DictRef withdrawal_candidate = _enemy_withdrawal_action(state, scoring_battle, active_stack, targets, best);
	if (!empty(state, withdrawal_candidate) && _candidate_beats(state, withdrawal_candidate, best)) {
		best = withdrawal_candidate;
	}
	const bool preservation_exit_selected = is_withdrawal(action_of(state, best));
	const DictRef candidate_scores = base_candidate_scores(state, defend_score, advance_score);
	if (!empty(state, best_attack)) {
		add_candidate_score(state, candidate_scores, best_attack, key::attack);
	}
	if (!empty(state, best_spell)) {
		state.set(candidate_scores, str(key::cast_spell), float_value(gd::float_field(state, best_spell, key::score, 0.0)));
	}
	if (!empty(state, withdrawal_candidate)) {
		add_candidate_score(state, candidate_scores, withdrawal_candidate, key::withdraw);
	}
	if ((!preservation_exit_selected || lethal_spell_available)
			&& _hero_cast_worthwhile(state, best_spell, best_attack, scoring_battle, active_stack, targets, resolved_enemy_hero, lethal_spell_available, lethal_attack_available, false)) {
		best = best_spell;
	}
	const DictRef report = gd::deep_duplicate_dict(state, best);
	state.set(report, str(key::candidate_scores), dict_value(candidate_scores));
	if (is_withdrawal(action_of(state, report))) {
		state.set(report, str(key::scoring_policy), str(key::battle_ai_enemy_withdrawal_decision_v1));
	}
	return report;
}

DictRef _stack_order_choice(State &state, DictRef scoring_battle, DictRef active_stack, ArrayRef targets) {
	// GDScript's board-read scope: the native board reads keep their own memo.
	const DictRef best_attack = _best_attack_action(state, scoring_battle, active_stack, targets);
	const bool lethal_attack_available = _candidate_is_lethal_attack(state, best_attack, scoring_battle, active_stack);
	const double defend_score = _defend_score(state, scoring_battle, active_stack, targets);
	const double advance_score = _advance_score(state, scoring_battle, active_stack, targets);
	const int64_t contact = _stack_contact_band(state, active_stack, scoring_battle);
	const bool force_attack = _must_force_engaged_attack(state, active_stack, scoring_battle, targets, best_attack)
			|| _should_press_decisive_attack(state, scoring_battle, active_stack, best_attack, defend_score);
	DictRef best = (force_attack && !empty(state, best_attack)) ? best_attack : scored_order(state, key::defend, defend_score);
	if (!force_attack && !empty(state, best_attack) && _candidate_beats(state, best_attack, best)) {
		best = best_attack;
	}
	if ((contact > 0 || empty(state, best_attack)) && !lethal_attack_available && !_stack_is_rooted(state, active_stack, scoring_battle)) {
		const DictRef advance_candidate = scored_order(state, key::advance, advance_score);
		if (_candidate_beats(state, advance_candidate, best)) {
			best = advance_candidate;
		}
	}
	if (action_of(state, best) == key::advance && !empty(state, best_attack)) {
		if (action_of(state, best_attack) == key::strike && _fights_in_melee(state, active_stack)) {
			best = best_attack;
		} else if (!_should_close_distance(state, active_stack)) {
			const double best_attack_score = gd::float_field(state, best_attack, key::score, -9999.0);
			if (best_attack_score >= gd::float_field(state, best, key::score, -9999.0) - 0.25) {
				best = best_attack;
			}
		}
	}
	// End of GDScript's board-read scope.
	const DictRef choice = state.new_dict();
	state.set(choice, str(key::best), dict_value(best));
	state.set(choice, str(key::best_attack), dict_value(best_attack));
	state.set(choice, str(key::lethal_attack_available), bool_value(lethal_attack_available));
	state.set(choice, str(key::defend_score), float_value(defend_score));
	state.set(choice, str(key::advance_score), float_value(advance_score));
	return choice;
}

DictRef best_reachable_strike(State &state, DictRef battle, DictRef active_stack) {
	_open_scoring_scope(state);
	const DictRef strike = _best_reachable_strike(state, battle, active_stack);
	_close_scoring_scope(state);
	return strike;
}

DictRef _best_reachable_strike(State &state, DictRef battle, DictRef active_stack) {
	if (empty(state, active_stack) || _alive_count(state, active_stack) <= 0 || !_fights_in_melee(state, active_stack)) {
		return state.new_dict();
	}
	const Atom side = side_of(state, active_stack);
	const DictRef scoring_battle = _battle_with_side_hero_payload(state, battle, side, _side_commander_state_for_ai(state, battle, side, state.new_dict()));
	DictRef best = state.new_dict();
	// GDScript's board-read scope: the native board reads keep their own memo.
	const ArrayRef enemies = _alive_stacks_for_side(state, scoring_battle, _opposing_side(side));
	for (const Value &target : gd::items(state, gd::array_value(enemies))) {
		const DictRef candidate = _strike_candidate(state, scoring_battle, active_stack, gd::as_dict(target));
		if (!empty(state, candidate) && _candidate_beats(state, candidate, best)) {
			best = candidate;
		}
	}
	// End of GDScript's board-read scope.
	return best;
}

DictRef advance_plan(State &state, DictRef battle, DictRef stack) {
	_open_scoring_scope(state);
	const DictRef plan = _advance_plan(state, battle, stack);
	_close_scoring_scope(state);
	return plan;
}

DictRef _advance_plan(State &state, DictRef battle, DictRef stack) {
	if (empty(state, stack) || _alive_count(state, stack) <= 0 || rules::_stack_is_rooted(state, stack, battle)) {
		return plain_order(state, key::defend);
	}
	const DictRef strike = best_reachable_strike(state, battle, stack);
	if (!empty(state, strike)) {
		const DictRef target = rules::_get_stack_by_id(state, battle, gd::string_field(state, strike, key::target_battle_id, key::empty));
		const ArrayRef cells = rules::melee_approach_cells(state, battle, stack, target);
		state.set(strike, str(key::approach), dict_value(choose_melee_approach(state, battle, stack, target, cells)));
		return strike;
	}
	// The arguments in the GDScript order.
	const bool wait_allowed = rules::can_wait(state, battle);
	const int64_t still_to_act = rules::_opposing_stacks_still_to_act(state, battle, stack);
	if (should_wait_for_contact(state, battle, stack, wait_allowed, still_to_act)) {
		return plain_order(state, key::wait);
	}
	if (_should_hold_line(state, battle, stack)) {
		return plain_order(state, key::defend);
	}
	return plain_order(state, key::advance);
}

DictRef choose_stack_tactical_order(State &state, DictRef battle, DictRef active_stack, Atom target_side, DictRef commander_payload, bool allow_hero_cast) {
	_open_scoring_scope(state);
	const DictRef order = _stack_tactical_order(state, battle, active_stack, target_side, commander_payload, allow_hero_cast);
	_close_scoring_scope(state);
	return order;
}

DictRef _stack_tactical_order(State &state, DictRef battle, DictRef active_stack, Atom target_side, DictRef commander_payload, bool allow_hero_cast) {
	if (empty(state, battle) || empty(state, active_stack) || _alive_count(state, active_stack) <= 0) {
		return state.new_dict();
	}
	const Atom acting_side = side_of(state, active_stack);
	const Atom resolved_target_side = target_side != key::empty ? target_side : _opposing_side(acting_side);
	if (acting_side == key::empty || resolved_target_side == key::empty || acting_side == resolved_target_side) {
		return state.new_dict();
	}
	const DictRef resolved_commander_payload = _side_commander_state_for_ai(state, battle, acting_side, commander_payload);
	const DictRef scoring_battle = _battle_with_side_hero_payload(state, battle, acting_side, resolved_commander_payload);
	const ArrayRef targets = _alive_stacks_for_side(state, scoring_battle, resolved_target_side);
	if (state.array_size(targets) == 0) {
		return state.new_dict();
	}

	const DictRef best_spell = allow_hero_cast ? _best_spell_action(state, scoring_battle, active_stack, resolved_commander_payload, targets) : state.new_dict();
	const DictRef choice = _stack_order_choice(state, scoring_battle, active_stack, targets);
	DictRef best = typed_dict_field(state, choice, key::best);
	const DictRef best_attack = typed_dict_field(state, choice, key::best_attack);
	const bool lethal_attack_available = gd::bool_field(state, choice, key::lethal_attack_available, false);
	const bool lethal_spell_available = _candidate_is_lethal_damage_spell(state, best_spell, scoring_battle, resolved_commander_payload);
	const double defend_score = gd::float_field(state, choice, key::defend_score, 0.0);
	const double advance_score = gd::float_field(state, choice, key::advance_score, 0.0);
	if (_hero_cast_worthwhile(state, best_spell, best_attack, scoring_battle, active_stack, targets, resolved_commander_payload, lethal_spell_available, lethal_attack_available, true)) {
		best = best_spell;
	}

	const DictRef candidate_scores = base_candidate_scores(state, defend_score, advance_score);
	if (!empty(state, best_attack)) {
		add_candidate_score(state, candidate_scores, best_attack, key::attack);
	}
	if (!empty(state, best_spell)) {
		state.set(candidate_scores, str(key::cast_spell), float_value(gd::float_field(state, best_spell, key::score, 0.0)));
	}
	const DictRef report = gd::deep_duplicate_dict(state, best);
	state.set(report, str(key::acting_side), str(acting_side));
	state.set(report, str(key::target_side), str(resolved_target_side));
	state.set(report, str(key::target_count), int_value(state.array_size(targets)));
	const Atom scoring_policy = action_of(state, best) == key::cast_spell ? key::battle_ai_spell_tactical_order_v1 : key::battle_ai_nonspell_tactical_order_v1;
	state.set(report, str(key::scoring_policy), str(scoring_policy));
	state.set(report, str(key::commander_payload_source), str(_side_commander_payload_source(state, battle, acting_side, commander_payload)));
	state.set(report, str(key::candidate_scores), dict_value(candidate_scores));
	return report;
}

} // namespace aurelion::rules::port::battle_ai_rules
