// Layer 3: movement: legal destinations, melee approaches, the advance terms and attack legality.
//
// The board-read memo (_board_read_cache_key, _board_read_cache_get and the
// scope cache writes) is left out: each function computes its answer as
// GDScript does outside a board-read scope. The memo keys' arguments (hash()
// of the stacks, the battle id as a String) cannot fail, so nothing of them is
// evaluated here.

#include "aurelion_rules/port/battle_rules.hpp"

#include "aurelion_rules/port/battle_footprint.hpp"

#include <initializer_list>

namespace aurelion::rules::port::battle_rules {

using gd::array_value;
using gd::bool_value;
using gd::dict_value;
using gd::int_value;
using gd::str;
namespace key = state::key;

namespace {

// int(battle.get("distance", 1))
int64_t battle_distance(const State &state, DictRef battle) {
	return gd::int_field(state, battle, key::distance, 1);
}

// String(stack.get("side", ""))
Atom stack_side(const State &state, DictRef stack) {
	return gd::string_field(state, stack, key::side, key::empty);
}

// String(stack.get("battle_id", ""))
Atom stack_battle_id(const State &state, DictRef stack) {
	return gd::string_field(state, stack, key::battle_id, key::empty);
}

} // namespace

ArrayRef legal_destinations_for_active_stack(State &state, DictRef battle) {
	return legal_destinations_for_stack(state, battle, gd::string_field(state, battle, key::active_stack_id, key::empty));
}

ArrayRef legal_destinations_for_stack(State &state, DictRef battle, Atom battle_id) {
	const DictRef stack = _get_stack_by_id(state, battle, battle_id);
	if (gd::is_empty(state, stack) || _alive_count(state, stack) <= 0) {
		return state.new_array();
	}
	if (_advance_stalled_by_obstruction(state, stack, battle)) {
		return state.new_array();
	}
	return _reachable_empty_hexes(state, battle, stack, _stack_movement_points(state, stack, battle));
}

DictRef melee_approach_destination(State &state, DictRef battle, DictRef stack, DictRef target) {
	if (gd::is_empty(state, stack) || gd::is_empty(state, target) || _alive_count(state, stack) <= 0 || _alive_count(state, target) <= 0) {
		return state.new_dict();
	}
	if (stack_side(state, stack) == stack_side(state, target) || _can_make_melee_attack(state, stack, battle, target)) {
		return state.new_dict();
	}
	// var best := {}: Nil stands for the empty literal until a cell is taken.
	Value best;
	const ArrayRef destinations = legal_destinations_for_stack(state, battle, stack_battle_id(state, stack));
	for (const Value &cell : gd::items(state, array_value(destinations))) {
		if (battle_footprint::distance(state, stack, target, cell) != 1) {
			continue;
		}
		if (best.kind == state::Kind::Nil || gd::is_empty(state, gd::as_dict(best))) {
			best = cell;
			continue;
		}
		const int64_t cell_steps = gd::int_field(state, gd::as_dict(cell), key::steps, 0);
		if (cell_steps < gd::int_field(state, gd::as_dict(best), key::steps, 0)) {
			best = cell;
		}
	}
	if (best.kind == state::Kind::Nil) {
		return state.new_dict();
	}
	return gd::deep_duplicate_dict(state, gd::as_dict(best));
}

ArrayRef melee_approach_cells(State &state, DictRef battle, DictRef stack, DictRef target) {
	if (gd::is_empty(state, stack) || gd::is_empty(state, target) || _alive_count(state, stack) <= 0 || _alive_count(state, target) <= 0) {
		return state.new_array();
	}
	if (stack_side(state, stack) == stack_side(state, target)) {
		return state.new_array();
	}
	const ArrayRef cells = state.new_array();
	const DictRef start = _stack_hex(state, stack);
	if (!gd::is_empty(state, start) && _can_make_melee_attack(state, stack, battle, target)) {
		state.append(cells, dict_value(_melee_approach_entry(state, stack, target, start, 0)));
	}
	if (_stack_is_rooted(state, stack, battle)) {
		return cells;
	}
	const ArrayRef destinations = legal_destinations_for_stack(state, battle, stack_battle_id(state, stack));
	for (const Value &cell : gd::items(state, array_value(destinations))) {
		if (battle_footprint::distance(state, stack, target, cell) == 1) {
			const DictRef cell_dict = gd::as_dict(cell);
			const int64_t steps = gd::int_field(state, cell_dict, key::steps, 0);
			state.append(cells, dict_value(_melee_approach_entry(state, stack, target, cell_dict, steps)));
		}
	}
	return cells;
}

DictRef _melee_approach_entry(State &state, DictRef stack, DictRef target, DictRef cell, int64_t steps) {
	const ArrayRef body = battle_footprint::cells(state, stack, dict_value(cell));
	const int64_t body_size = state.array_size(body);
	DictRef strike_cell = body_size != 0 ? gd::as_dict(state.at(body, 0)) : cell;
	Atom strike_part = key::head;
	int64_t nearest = 999;
	for (int64_t index = 0; index < body_size; ++index) {
		const DictRef probe = state.new_dict();
		state.set(probe, str(key::hex), state.at(body, index));
		const int64_t distance = battle_footprint::distance(state, probe, target, Value());
		if (distance < nearest) {
			nearest = distance;
			strike_cell = gd::as_dict(state.at(body, index));
			strike_part = index == 0 ? key::head : key::tail;
		}
	}
	const int64_t q = gd::int_field(state, cell, key::q, -1);
	const int64_t r = gd::int_field(state, cell, key::r, -1);
	const int64_t strike_q = gd::int_field(state, strike_cell, key::q, -1);
	const int64_t strike_r = gd::int_field(state, strike_cell, key::r, -1);
	const DictRef entry = state.new_dict();
	state.set(entry, str(key::q), int_value(q));
	state.set(entry, str(key::r), int_value(r));
	state.set(entry, str(key::steps), int_value(steps));
	state.set(entry, str(key::stands), bool_value(steps == 0));
	state.set(entry, str(key::strike_q), int_value(strike_q));
	state.set(entry, str(key::strike_r), int_value(strike_r));
	state.set(entry, str(key::strike_part), str(strike_part));
	state.set(entry, str(key::hex_distance), int_value(nearest));
	return entry;
}

DictRef _matching_melee_approach(State &state, DictRef battle, DictRef stack, DictRef target, DictRef approach) {
	const ArrayRef cells = melee_approach_cells(state, battle, stack, target);
	for (const Value &cell : gd::items(state, array_value(cells))) {
		const DictRef cell_dict = gd::as_dict(cell);
		const int64_t cell_q = gd::int_field(state, cell_dict, key::q, -1);
		if (cell_q != gd::int_field(state, approach, key::q, -2)) {
			continue;
		}
		const int64_t cell_r = gd::int_field(state, cell_dict, key::r, -1);
		if (cell_r == gd::int_field(state, approach, key::r, -2)) {
			return cell_dict;
		}
	}
	return state.new_dict();
}

bool extra_speed_reaches_strike(State &state, DictRef battle, DictRef stack, int64_t extra) {
	if (extra <= 0 || gd::is_empty(state, stack) || _stack_is_rooted(state, stack, battle) || _advance_stalled_by_obstruction(state, stack, battle)) {
		return false;
	}
	const ArrayRef enemies = _alive_stacks_for_side(state, battle, _opposing_side(stack_side(state, stack)));
	const int64_t movement = _stack_movement_points(state, stack, battle);
	const ArrayRef reachable = _reachable_empty_hexes(state, battle, stack, movement);
	for (const Value &cell : gd::items(state, array_value(reachable))) {
		for (const Value &enemy : gd::items(state, array_value(enemies))) {
			if (battle_footprint::distance(state, stack, gd::as_dict(enemy), cell) <= 1) {
				return false;
			}
		}
	}
	const ArrayRef extended = _reachable_empty_hexes(state, battle, stack, gd::add(movement, extra));
	for (const Value &cell : gd::items(state, array_value(extended))) {
		for (const Value &enemy : gd::items(state, array_value(enemies))) {
			if (battle_footprint::distance(state, stack, gd::as_dict(enemy), cell) <= 1) {
				return true;
			}
		}
	}
	return false;
}

int64_t _advance_desired_gap(State &state, DictRef stack, DictRef battle) {
	if (gd::bool_field(state, stack, key::ranged, false) && gd::int_field(state, stack, key::shots_remaining, 0) > 0) {
		return 2;
	}
	if (_reach_available(state, stack, battle)) {
		return 2;
	}
	return 1;
}

bool _advance_stalled_by_obstruction(State &state, DictRef stack, DictRef battle) {
	return battle_distance(state, battle) > 0 && _advance_distance_delta(state, stack, battle) <= 0;
}

int64_t _advance_lateral_penalty(State &state, DictRef stack, DictRef destination) {
	const DictRef current = _stack_hex(state, stack);
	if (gd::is_empty(state, current)) {
		return 0;
	}
	const int64_t destination_q = gd::int_field(state, destination, key::q, 0);
	int64_t forward_delta = gd::sub(destination_q, gd::int_field(state, current, key::q, 0));
	if (stack_side(state, stack) == key::enemy) {
		forward_delta = gd::neg(forward_delta);
	}
	const int64_t destination_r = gd::int_field(state, destination, key::r, 0);
	const int64_t lateral = compat::absi(gd::sub(destination_r, gd::int_field(state, current, key::r, 0)));
	const compat::Number backward = compat::variant_max({ compat::Number::of_int(0), compat::Number::of_int(gd::neg(forward_delta)) });
	return gd::add(lateral, gd::mul(backward.i, 2));
}

bool _stack_can_breach_obstruction(State &state, DictRef stack, DictRef battle) {
	if (gd::is_empty(state, stack) || gd::bool_field(state, stack, key::ranged, false)) {
		return false;
	}
	if (_reach_available(state, stack, battle) || _brace_available(state, stack, battle) || _has_ability(state, stack, key::formation_guard)) {
		return true;
	}
	if (_stack_momentum_total(state, stack, battle) >= 2) {
		return true;
	}
	return gd::int_field(state, stack, key::speed, 0) >= 5;
}

int64_t _advance_distance_delta(State &state, DictRef stack, DictRef battle) {
	if (gd::is_empty(state, stack) || battle_distance(state, battle) <= 0) {
		return 0;
	}
	const Atom opposing_side = _opposing_side(stack_side(state, stack));
	if (_side_controls_field_objective_type(state, battle, opposing_side, key::obstruction_line) && !_stack_can_breach_obstruction(state, stack, battle)) {
		return 0;
	}
	return 1;
}

void _clear_post_move_transition_result_fields(State &state, DictRef result) {
	static const Atom kFields[] = {
		key::movement_intent,
		key::sets_up_selected_target_attack,
		key::selected_target_setup_label,
		key::selected_target_after_move_attackable,
		key::selected_target_after_move_hex_distance,
		key::selected_target_after_move_battle_id,
		key::selected_target_after_move_name,
		key::selected_target_after_move_legality,
		key::selected_target_after_move_board_click_intent,
		key::selected_target_after_move_board_click_action,
		key::selected_target_after_move_board_click_label,
		key::selected_target_actionable_after_move,
		key::selected_target_continuity_preserved,
		key::selected_target_closing_before_move,
		key::closes_on_selected_target,
		key::post_move_target_guidance,
	};
	for (const Atom field : kFields) {
		state.erase(result, str(field));
	}
}

bool _can_melee_this_action(State &state, DictRef stack, DictRef battle, DictRef target) {
	return _can_make_melee_attack(state, stack, battle, target) || !gd::is_empty(state, melee_approach_destination(state, battle, stack, target));
}

DictRef _attack_legality_for_target(State &state, DictRef active_stack, DictRef target, DictRef battle) {
	if (gd::is_empty(state, active_stack) || gd::is_empty(state, target)) {
		const DictRef none = state.new_dict();
		state.set(none, str(key::battle_id), str(key::empty));
		state.set(none, str(key::melee), bool_value(false));
		state.set(none, str(key::ranged), bool_value(false));
		state.set(none, str(key::attackable), bool_value(false));
		state.set(none, str(key::blocked), bool_value(false));
		state.set(none, str(key::hex_distance), int_value(-1));
		return none;
	}
	const int64_t hex_distance = _stack_hex_distance(state, active_stack, target);
	const bool melee_legal = _can_melee_this_action(state, active_stack, battle, target);
	const bool ranged_legal = _can_make_ranged_attack(state, active_stack, battle, target);
	const Atom target_id = stack_battle_id(state, target);
	const DictRef legality = state.new_dict();
	state.set(legality, str(key::battle_id), str(target_id));
	state.set(legality, str(key::melee), bool_value(melee_legal));
	state.set(legality, str(key::ranged), bool_value(ranged_legal));
	state.set(legality, str(key::attackable), bool_value(melee_legal || ranged_legal));
	state.set(legality, str(key::blocked), bool_value(!melee_legal && !ranged_legal));
	state.set(legality, str(key::hex_distance), int_value(hex_distance));
	return legality;
}

bool _can_make_ranged_attack(State &state, DictRef stack, DictRef battle, DictRef target) {
	(void)battle;
	return !gd::is_empty(state, stack)
			&& !gd::is_empty(state, target)
			&& _alive_count(state, stack) > 0
			&& _alive_count(state, target) > 0
			&& stack_side(state, stack) != stack_side(state, target)
			&& gd::bool_field(state, stack, key::ranged, false)
			&& gd::int_field(state, stack, key::shots_remaining, 0) > 0
			&& !gd::is_empty(state, _stack_hex(state, stack))
			&& !gd::is_empty(state, _stack_hex(state, target));
}

int64_t _attack_distance_for_action(State &state, DictRef attacker, DictRef target, DictRef battle, bool is_ranged) {
	const int64_t hex_distance = _stack_hex_distance(state, attacker, target);
	if (hex_distance >= 999) {
		return battle_distance(state, battle);
	}
	if (is_ranged) {
		return _distance_band_from_hex_distance(hex_distance);
	}
	if (hex_distance <= 1) {
		return 0;
	}
	if (hex_distance == 2 && (_reach_available(state, attacker, battle) || _hookline_available(state, attacker, battle))) {
		return 1;
	}
	return battle_distance(state, battle);
}

bool _can_make_melee_attack(State &state, DictRef stack, DictRef battle, DictRef target) {
	if (gd::is_empty(state, stack) || _alive_count(state, stack) <= 0) {
		return false;
	}
	if (gd::is_empty(state, target)) {
		const ArrayRef candidates = _alive_stacks_for_side(state, battle, _opposing_side(stack_side(state, stack)));
		for (const Value &candidate : gd::items(state, array_value(candidates))) {
			if (_can_make_melee_attack(state, stack, battle, gd::as_dict(candidate))) {
				return true;
			}
		}
		return false;
	}
	if (_alive_count(state, target) <= 0 || stack_side(state, stack) == stack_side(state, target)) {
		return false;
	}
	const int64_t hex_distance = _stack_hex_distance(state, stack, target);
	if (hex_distance <= 1) {
		return true;
	}
	return hex_distance == 2 && (_reach_available(state, stack, battle) || _hookline_available(state, stack, battle));
}

} // namespace aurelion::rules::port::battle_rules
