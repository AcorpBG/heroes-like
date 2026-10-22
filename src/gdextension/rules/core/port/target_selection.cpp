// Layer 3: target selection: legal targets, the selected target and its click, continuity and closing contexts.

#include "aurelion_rules/port/battle_rules.hpp"

#include "aurelion_rules/port/battle_footprint.hpp"

#include <vector>

namespace aurelion::rules::port::battle_rules {

using gd::array_value;
using gd::bool_value;
using gd::dict_value;
using gd::str;
using state::Kind;
namespace key = state::key;

namespace {

// String(d.get(field, "")).
Atom string_or_empty(const State &state, DictRef dict, Atom field) {
	return gd::string_field(state, dict, field, key::empty);
}

// String(lhs.get("side", "")) == String(rhs.get("side", "")): the left
// operand is converted first, as GDScript evaluates it.
bool same_side(const State &state, DictRef lhs, DictRef rhs) {
	const Atom lhs_side = string_or_empty(state, lhs, key::side);
	const Atom rhs_side = string_or_empty(state, rhs, key::side);
	return lhs_side == rhs_side;
}

// var value: Variant = battle.get(SELECTED_TARGET_CLOSING_KEY, {})
// String(value.get("battle_id", "")) if value is Dictionary else "":
// the default {} has no battle_id, so a missing key gives "".
Atom closing_target_id(const State &state, DictRef battle) {
	Value value;
	if (!state.lookup(battle, str(key::selected_target_closing_context), value)) {
		return key::empty;
	}
	if (!gd::is_dict(value)) {
		return key::empty;
	}
	return string_or_empty(state, value.ref, key::battle_id);
}

// session.battle: SessionData.battle is a typed Dictionary.
DictRef session_battle(State &state, const Value &session) {
	return gd::as_dict(gd::member(state, session, key::battle));
}

// select_target's refusal literal.
DictRef invalid_selection(State &state, Atom battle_id, Atom message) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(false));
	state.set(result, str(key::target_battle_id), str(battle_id));
	state.set(result, str(key::message), str(message));
	state.set(result, str(key::state), str(key::invalid));
	return result;
}

bool array_is_empty(const State &state, ArrayRef array) {
	return state.array_size(array) == 0;
}

} // namespace

DictRef get_selected_target(State &state, DictRef battle) {
	return _get_stack_by_id(state, battle, string_or_empty(state, battle, key::selected_target_id));
}

DictRef select_target(State &state, const Value &session, Atom battle_id) {
	if (session.kind == Kind::Nil || gd::is_empty(state, session_battle(state, session))) {
		return invalid_selection(state, battle_id, state.intern("No battle is active."));
	}
	const DictRef active_stack = get_active_stack(state, session_battle(state, session));
	if (gd::is_empty(state, active_stack) || string_or_empty(state, active_stack, key::side) != key::player) {
		return invalid_selection(state, battle_id, state.intern("It is not the player's turn."));
	}
	const DictRef target = _get_stack_by_id(state, session_battle(state, session), battle_id);
	if (gd::is_empty(state, target) || _alive_count(state, target) <= 0 || same_side(state, target, active_stack)) {
		return invalid_selection(state, battle_id, state.intern("Only living enemy stacks can be selected."));
	}
	_set_selected_target(state, session_battle(state, session), battle_id, true);
	const DictRef click_intent = board_click_attack_intent_for_target(state, session_battle(state, session), battle_id);
	const DictRef continuity_context = selected_target_continuity_context(state, session_battle(state, session));
	const DictRef closing_context = selected_target_closing_context(state, session_battle(state, session), true);
	// The literal's values, in its order.
	const Atom target_name = _stack_label(state, target);
	const DictRef click_intent_copy = gd::deep_duplicate_dict(state, click_intent);
	const DictRef continuity_copy = gd::deep_duplicate_dict(state, continuity_context);
	const bool preserved_setup = !gd::is_empty(state, continuity_context);
	const DictRef closing_copy = gd::deep_duplicate_dict(state, closing_context);
	const bool closing_on_target = !gd::is_empty(state, closing_context);
	const Atom message = string_or_empty(state, click_intent, key::message);
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(true));
	state.set(result, str(key::target_battle_id), str(battle_id));
	state.set(result, str(key::target_name), str(target_name));
	state.set(result, str(key::selected_target_board_click_intent), dict_value(click_intent_copy));
	state.set(result, str(key::selected_target_continuity_context), dict_value(continuity_copy));
	state.set(result, str(key::selected_target_preserved_setup), bool_value(preserved_setup));
	state.set(result, str(key::selected_target_closing_context), dict_value(closing_copy));
	state.set(result, str(key::selected_target_closing_on_target), bool_value(closing_on_target));
	state.set(result, str(key::state), str(key::continue_));
	state.set(result, str(key::message), str(message));
	return result;
}

ArrayRef legal_attack_targets_for_active_stack(State &state, DictRef battle, bool ranged) {
	const DictRef active_stack = get_active_stack(state, battle);
	if (gd::is_empty(state, active_stack) || _alive_count(state, active_stack) <= 0) {
		return state.new_array();
	}
	const ArrayRef targets = state.new_array();
	const ArrayRef approach_cells = ranged ? state.new_array() : legal_destinations_for_active_stack(state, battle);
	const ArrayRef opposing = _alive_stacks_for_side(state, battle, _opposing_side(string_or_empty(state, active_stack, key::side)));
	for (const Value &target_value : gd::items(state, array_value(opposing))) {
		if (ranged) {
			if (_can_make_ranged_attack(state, active_stack, battle, gd::as_dict(target_value))) {
				state.append(targets, str(string_or_empty(state, gd::as_dict(target_value), key::battle_id)));
			}
		} else {
			bool reachable = _can_make_melee_attack(state, active_stack, battle, gd::as_dict(target_value));
			if (!reachable) {
				for (const Value &cell : gd::items(state, array_value(approach_cells))) {
					if (battle_footprint::distance(state, active_stack, gd::as_dict(target_value), dict_value(gd::as_dict(cell))) == 1) {
						reachable = true;
						break;
					}
				}
			}
			if (reachable) {
				state.append(targets, str(string_or_empty(state, gd::as_dict(target_value), key::battle_id)));
			}
		}
	}
	return targets;
}

DictRef selected_target_legality(State &state, DictRef battle) {
	const DictRef active_stack = get_active_stack(state, battle);
	const DictRef target = get_selected_target(state, battle);
	return _attack_legality_for_target(state, active_stack, target, battle);
}

DictRef selected_target_board_click_intent(State &state, DictRef battle) {
	return board_click_attack_intent_for_target(state, battle, string_or_empty(state, battle, key::selected_target_id));
}

DictRef selected_target_continuity_context(State &state, DictRef battle) {
	if (gd::is_empty(state, battle)) {
		return state.new_dict();
	}
	const Atom target_id = string_or_empty(state, battle, key::selected_target_continuity_id);
	if (target_id == key::empty || string_or_empty(state, battle, key::selected_target_id) != target_id) {
		return state.new_dict();
	}
	const DictRef active_stack = get_active_stack(state, battle);
	const DictRef target = _get_stack_by_id(state, battle, target_id);
	if (
			gd::is_empty(state, active_stack)
			|| gd::is_empty(state, target)
			|| _alive_count(state, target) <= 0
			|| string_or_empty(state, active_stack, key::side) != key::player
			|| same_side(state, target, active_stack)) {
		return state.new_dict();
	}

	const Atom target_label = _stack_label(state, target);
	const DictRef legality = _attack_legality_for_target(state, active_stack, target, battle);
	const DictRef click_intent = board_click_attack_intent_for_target(state, battle, target_id);
	const Atom action_id = string_or_empty(state, click_intent, key::action);
	const Atom action_label = string_or_empty(state, click_intent, key::label);
	// The literal's values, in its order.
	const Atom active_battle_id = string_or_empty(state, active_stack, key::battle_id);
	const Atom active_stack_name = _stack_label(state, active_stack);
	const bool attackable = gd::bool_field(state, legality, key::attackable, false);
	const bool blocked = gd::bool_field(state, legality, key::blocked, false);
	const DictRef click_intent_copy = gd::deep_duplicate_dict(state, click_intent);
	const DictRef legality_copy = gd::deep_duplicate_dict(state, legality);
	const DictRef context = state.new_dict();
	state.set(context, str(key::preserved_setup_target), bool_value(true));
	state.set(context, str(key::battle_id), str(target_id));
	state.set(context, str(key::target_name), str(target_label));
	state.set(context, str(key::active_battle_id), str(active_battle_id));
	state.set(context, str(key::active_stack_name), str(active_stack_name));
	state.set(context, str(key::attackable), bool_value(attackable));
	state.set(context, str(key::blocked), bool_value(blocked));
	state.set(context, str(key::board_click_action), str(action_id));
	state.set(context, str(key::board_click_label), str(action_label));
	state.set(context, str(key::board_click_intent), dict_value(click_intent_copy));
	state.set(context, str(key::legality), dict_value(legality_copy));
	state.set(context, str(key::emphasis), str(key::empty));
	state.set(context, str(key::footer_label), str(key::empty));
	state.set(context, str(key::message), str(key::empty));
	state.set(context, str(key::target_line), str(key::empty));
	if (gd::bool_field(state, legality, key::attackable, false) && action_label != key::empty) {
		const Atom ready_message = gd::format(state, state.intern("Preserved setup target: select to preview %s %s; confirm to commit."), { str(action_label), str(target_label) });
		state.set(context, str(key::emphasis), str(key::attackable));
		const Atom footer_label = gd::format(state, state.intern("Setup: %s"), { str(action_label) });
		state.set(context, str(key::footer_label), str(footer_label));
		state.set(context, str(key::message), str(ready_message));
		state.set(context, str(key::target_line), str(ready_message));
		return context;
	}
	if (gd::bool_field(state, legality, key::blocked, false)) {
		Atom blocked_message = key::empty;
		if (!array_is_empty(state, _legal_attack_target_ids_for_active_stack(state, battle))) {
			blocked_message = gd::format(state, state.intern("Preserved setup target: %s is still blocked from this hex; highlighted enemies can attack now, or move again to keep setting it up."), { str(target_label) });
		} else {
			blocked_message = gd::format(state, state.intern("Preserved setup target: %s is still blocked from this hex; movement is still needed."), { str(target_label) });
		}
		state.set(context, str(key::emphasis), str(key::blocked));
		state.set(context, str(key::footer_label), str(state.intern("Setup: blocked")));
		state.set(context, str(key::message), str(blocked_message));
		state.set(context, str(key::target_line), str(blocked_message));
		return context;
	}

	const Atom fallback_message = gd::format(state, state.intern("Preserved setup target: %s remains selected."), { str(target_label) });
	state.set(context, str(key::emphasis), str(key::selected));
	state.set(context, str(key::footer_label), str(state.intern("Setup: selected")));
	state.set(context, str(key::message), str(fallback_message));
	state.set(context, str(key::target_line), str(fallback_message));
	return context;
}

DictRef selected_target_closing_context(State &state, DictRef battle, bool clear_stale) {
	if (gd::is_empty(state, battle)) {
		return state.new_dict();
	}
	if (!gd::is_empty(state, selected_target_continuity_context(state, battle))) {
		if (clear_stale) {
			_clear_selected_target_closing(state, battle);
		}
		return state.new_dict();
	}
	if (_selected_target_closing_is_stale(state, battle, true)) {
		if (clear_stale) {
			_clear_selected_target_closing(state, battle);
		}
		return state.new_dict();
	}
	Value context_value;
	if (!state.lookup(battle, str(key::selected_target_closing_context), context_value)) {
		// The default {} has no battle_id: target_id is "".
		return state.new_dict();
	}
	if (!gd::is_dict(context_value)) {
		return state.new_dict();
	}
	const DictRef stored_context = context_value.ref;
	const Atom target_id = string_or_empty(state, stored_context, key::battle_id);
	if (target_id == key::empty || string_or_empty(state, battle, key::selected_target_id) != target_id) {
		return state.new_dict();
	}
	const DictRef active_stack = get_active_stack(state, battle);
	const Atom expected_active_id = string_or_empty(state, stored_context, key::active_battle_id);
	if (
			gd::is_empty(state, active_stack)
			|| string_or_empty(state, active_stack, key::side) != key::player
			|| (expected_active_id != key::empty && string_or_empty(state, active_stack, key::battle_id) != expected_active_id)) {
		return state.new_dict();
	}
	const DictRef target = _get_stack_by_id(state, battle, target_id);
	if (gd::is_empty(state, target) || _alive_count(state, target) <= 0 || same_side(state, target, active_stack)) {
		return state.new_dict();
	}

	const Atom mover_label = gd::string_field(state, stored_context, key::mover_name, state.intern("A stack"));
	const Atom target_label = _stack_label(state, target);
	const DictRef legality = _attack_legality_for_target(state, active_stack, target, battle);
	const DictRef click_intent = board_click_attack_intent_for_target(state, battle, target_id);
	const Atom action_id = string_or_empty(state, click_intent, key::action);
	const Atom action_label = string_or_empty(state, click_intent, key::label);
	const DictRef context = gd::deep_duplicate_dict(state, stored_context);
	state.set(context, str(key::ordinary_closing_target), bool_value(true));
	state.set(context, str(key::preserved_setup_target), bool_value(false));
	state.set(context, str(key::battle_id), str(target_id));
	state.set(context, str(key::target_name), str(target_label));
	const Atom active_battle_id = string_or_empty(state, active_stack, key::battle_id);
	state.set(context, str(key::active_battle_id), str(active_battle_id));
	const Atom active_stack_name = _stack_label(state, active_stack);
	state.set(context, str(key::active_stack_name), str(active_stack_name));
	const bool attackable = gd::bool_field(state, legality, key::attackable, false);
	state.set(context, str(key::attackable), bool_value(attackable));
	const bool blocked = gd::bool_field(state, legality, key::blocked, false);
	state.set(context, str(key::blocked), bool_value(blocked));
	state.set(context, str(key::board_click_action), str(action_id));
	state.set(context, str(key::board_click_label), str(action_label));
	const DictRef click_intent_copy = gd::deep_duplicate_dict(state, click_intent);
	state.set(context, str(key::board_click_intent), dict_value(click_intent_copy));
	const DictRef legality_copy = gd::deep_duplicate_dict(state, legality);
	state.set(context, str(key::legality), dict_value(legality_copy));
	state.set(context, str(key::emphasis), str(key::empty));
	state.set(context, str(key::footer_label), str(key::empty));
	state.set(context, str(key::message), str(key::empty));
	state.set(context, str(key::target_line), str(key::empty));
	if (gd::bool_field(state, legality, key::blocked, false)) {
		Atom blocked_message = key::empty;
		if (!array_is_empty(state, _legal_attack_target_ids_for_active_stack(state, battle))) {
			blocked_message = gd::format(state, state.intern("Closing on target: %s moved closer to %s; target is still blocked here, but highlighted enemies can attack now."), { str(mover_label), str(target_label) });
		} else {
			blocked_message = gd::format(state, state.intern("Closing on target: %s moved closer to %s; target is still blocked here, so another move continues the approach."), { str(mover_label), str(target_label) });
		}
		state.set(context, str(key::emphasis), str(key::blocked));
		state.set(context, str(key::footer_label), str(state.intern("Closing: blocked")));
		state.set(context, str(key::message), str(blocked_message));
		state.set(context, str(key::target_line), str(blocked_message));
		return context;
	}

	const Atom fallback_message = gd::format(state, state.intern("Closing on target: %s moved closer to %s."), { str(mover_label), str(target_label) });
	state.set(context, str(key::emphasis), str(key::selected));
	state.set(context, str(key::footer_label), str(state.intern("Closing: selected")));
	state.set(context, str(key::message), str(fallback_message));
	state.set(context, str(key::target_line), str(fallback_message));
	return context;
}

DictRef board_click_attack_intent_for_target(State &state, DictRef battle, Atom battle_id) {
	const DictRef active_stack = get_active_stack(state, battle);
	const DictRef target = _get_stack_by_id(state, battle, battle_id);
	const Atom target_label = !gd::is_empty(state, target) ? _stack_label(state, target) : state.intern("that target");
	const DictRef intent = state.new_dict();
	state.set(intent, str(key::target_battle_id), str(battle_id));
	state.set(intent, str(key::target_name), str(target_label));
	state.set(intent, str(key::action), str(key::empty));
	state.set(intent, str(key::label), str(key::empty));
	state.set(intent, str(key::attackable), bool_value(false));
	state.set(intent, str(key::blocked), bool_value(false));
	state.set(intent, str(key::message), str(key::empty));
	if (gd::is_empty(state, battle) || battle_id == key::empty) {
		state.set(intent, str(key::message), str(state.intern("Board click: no battle target is selected.")));
		return intent;
	}
	if (gd::is_empty(state, active_stack)) {
		state.set(intent, str(key::message), str(state.intern("Board click: no stack is ready to act.")));
		return intent;
	}
	if (string_or_empty(state, active_stack, key::side) != key::player) {
		state.set(intent, str(key::message), str(_player_input_locked_summary(state)));
		return intent;
	}
	if (gd::is_empty(state, target) || string_or_empty(state, target, key::side) != key::enemy) {
		state.set(intent, str(key::message), str(state.intern("Board click: only enemy stacks can be attacked.")));
		return intent;
	}

	const ArrayRef legal_ranged_targets = legal_attack_targets_for_active_stack(state, battle, true);
	const ArrayRef legal_melee_targets = legal_attack_targets_for_active_stack(state, battle, false);
	Atom action_id = key::empty;
	if (gd::bool_field(state, active_stack, key::ranged, false) && gd::array_has(state, legal_ranged_targets, str(battle_id))) {
		action_id = key::shoot;
	} else if (gd::array_has(state, legal_melee_targets, str(battle_id))) {
		action_id = key::strike;
	} else if (gd::array_has(state, legal_ranged_targets, str(battle_id))) {
		action_id = key::shoot;
	}

	if (action_id != key::empty) {
		Atom action_label = gd::capitalize(state, action_id);
		const DictRef approach = action_id == key::strike ? melee_approach_destination(state, battle, active_stack, target) : state.new_dict();
		if (!gd::is_empty(state, approach)) {
			action_label = state.intern("Move & strike");
			state.set(intent, str(key::approach_hex), dict_value(approach));
		}
		state.set(intent, str(key::action), str(action_id));
		state.set(intent, str(key::label), str(action_label));
		state.set(intent, str(key::attackable), bool_value(true));
		const Atom preview_message = gd::format(state, state.intern("Select to preview %s %s. Confirm order or activate the same target again to commit; Esc cancels."), { str(action_label), str(target_label) });
		state.set(intent, str(key::message), str(preview_message));
		if (!gd::is_empty(state, approach)) {
			const Atom approach_message = gd::format(state, state.intern("Move to %s and strike %s in one action."), { str(_hex_label(state, approach)), str(target_label) });
			state.set(intent, str(key::message), str(approach_message));
		}
		return intent;
	}

	state.set(intent, str(key::blocked), bool_value(true));
	if (!array_is_empty(state, _legal_attack_target_ids_for_active_stack(state, battle))) {
		const Atom blocked_message = gd::format(state, state.intern("Target blocked: %s cannot be attacked from this hex; select a highlighted enemy to preview, or move first."), { str(target_label) });
		state.set(intent, str(key::message), str(blocked_message));
	} else {
		const Atom blocked_message = gd::format(state, state.intern("Board click blocked: %s cannot be attacked from this hex; move to a highlighted hex before attacking."), { str(target_label) });
		state.set(intent, str(key::message), str(blocked_message));
	}
	return intent;
}

Atom _player_input_locked_summary(State &state) {
	return state.intern("Input locked: it is not the player's turn.");
}

void _clear_selected_target_continuity(State &state, DictRef battle) {
	if (gd::is_empty(state, battle)) {
		return;
	}
	state.erase(battle, str(key::selected_target_continuity_id));
}

void _clear_selected_target_closing(State &state, DictRef battle) {
	if (gd::is_empty(state, battle)) {
		return;
	}
	state.erase(battle, str(key::selected_target_closing_context));
}

bool _clear_stale_selected_target_closing(State &state, DictRef battle, bool clear_attackable) {
	if (!_selected_target_closing_is_stale(state, battle, clear_attackable)) {
		return false;
	}
	_clear_selected_target_closing(state, battle);
	return true;
}

bool _selected_target_closing_is_stale(State &state, DictRef battle, bool clear_attackable) {
	if (gd::is_empty(state, battle) || !state.has(battle, str(key::selected_target_closing_context))) {
		return false;
	}
	// The key is present, so get() answers its value, not the default {}.
	const Value context_value = gd::field(state, battle, key::selected_target_closing_context);
	if (!gd::is_dict(context_value)) {
		return true;
	}
	const DictRef stored_context = context_value.ref;
	const Atom target_id = string_or_empty(state, stored_context, key::battle_id);
	if (target_id == key::empty || string_or_empty(state, battle, key::selected_target_id) != target_id) {
		return true;
	}
	const DictRef active_stack = get_active_stack(state, battle);
	const Atom expected_active_id = string_or_empty(state, stored_context, key::active_battle_id);
	if (
			gd::is_empty(state, active_stack)
			|| string_or_empty(state, active_stack, key::side) != key::player
			|| (expected_active_id != key::empty && string_or_empty(state, active_stack, key::battle_id) != expected_active_id)) {
		return true;
	}
	const DictRef target = _get_stack_by_id(state, battle, target_id);
	if (gd::is_empty(state, target) || _alive_count(state, target) <= 0 || same_side(state, target, active_stack)) {
		return true;
	}
	const DictRef legality = _attack_legality_for_target(state, active_stack, target, battle);
	return (clear_attackable && gd::bool_field(state, legality, key::attackable, false)) || !gd::bool_field(state, legality, key::blocked, false);
}

void _set_selected_target(State &state, DictRef battle, Atom target_id, bool explicit_retarget) {
	if (gd::is_empty(state, battle)) {
		return;
	}
	const Atom normalized_target_id = target_id;
	if (explicit_retarget) {
		const Atom continuity_target_id = string_or_empty(state, battle, key::selected_target_continuity_id);
		if (continuity_target_id != key::empty && normalized_target_id != continuity_target_id) {
			_clear_selected_target_continuity(state, battle);
		}
		const Atom explicit_closing_target_id = closing_target_id(state, battle);
		if (explicit_closing_target_id != key::empty && normalized_target_id != explicit_closing_target_id) {
			_clear_selected_target_closing(state, battle);
		}
	} else {
		const Atom current_closing_target_id = closing_target_id(state, battle);
		if (current_closing_target_id != key::empty && normalized_target_id != current_closing_target_id) {
			_clear_selected_target_closing(state, battle);
		}
	}
	state.set(battle, str(key::selected_target_id), str(normalized_target_id));
}

bool _selected_target_can_remain_for_active_stack(State &state, DictRef battle, DictRef active_stack, Atom target_id) {
	if (gd::is_empty(state, battle) || gd::is_empty(state, active_stack) || target_id == key::empty) {
		return false;
	}
	const DictRef target = _get_stack_by_id(state, battle, target_id);
	return (
			!gd::is_empty(state, target)
			&& _alive_count(state, target) > 0
			&& !same_side(state, target, active_stack));
}

void _assign_default_target(State &state, DictRef battle) {
	const DictRef active_stack = get_active_stack(state, battle);
	_clear_stale_selected_target_closing(state, battle, true);
	if (gd::is_empty(state, active_stack)) {
		_set_selected_target(state, battle, key::empty, false);
		return;
	}
	const Atom target_side = string_or_empty(state, active_stack, key::side) == key::player ? static_cast<Atom>(key::enemy) : static_cast<Atom>(key::player);
	const ArrayRef targets = _alive_stacks_for_side(state, battle, target_side);
	if (array_is_empty(state, targets)) {
		_set_selected_target(state, battle, key::empty, false);
		return;
	}
	Atom continuity_target_id = string_or_empty(state, battle, key::selected_target_continuity_id);
	const Atom current_selected_id = string_or_empty(state, battle, key::selected_target_id);
	if (
			continuity_target_id != key::empty
			&& current_selected_id != key::empty
			&& current_selected_id != continuity_target_id
			&& string_or_empty(state, active_stack, key::side) == key::player) {
		_clear_selected_target_continuity(state, battle);
		continuity_target_id = key::empty;
	}
	if (continuity_target_id != key::empty) {
		if (_selected_target_can_remain_for_active_stack(state, battle, active_stack, continuity_target_id)) {
			_set_selected_target(state, battle, continuity_target_id, false);
			return;
		}
		if (string_or_empty(state, active_stack, key::side) == key::player) {
			_clear_selected_target_continuity(state, battle);
		}
	}
	const DictRef preferred_target = _preferred_default_target_for_active_stack(state, battle, active_stack, targets);
	_set_selected_target(state, battle, string_or_empty(state, preferred_target, key::battle_id), false);
}

DictRef _preferred_default_target_for_active_stack(State &state, DictRef battle, DictRef active_stack, ArrayRef targets) {
	if (gd::is_empty(state, battle) || gd::is_empty(state, active_stack) || array_is_empty(state, targets)) {
		return state.new_dict();
	}
	const ArrayRef legal_target_ids = _legal_attack_target_ids_for_active_stack(state, battle);
	for (const Value &legal_target_id_value : gd::items(state, array_value(legal_target_ids))) {
		const Atom legal_target_id = gd::to_string(legal_target_id_value);
		for (const Value &target : gd::items(state, array_value(targets))) {
			if (gd::is_dict(target) && string_or_empty(state, target.ref, key::battle_id) == legal_target_id) {
				return target.ref;
			}
		}
	}
	for (const Value &target : gd::items(state, array_value(targets))) {
		if (gd::is_dict(target)) {
			return target.ref;
		}
	}
	return state.new_dict();
}

ArrayRef _legal_attack_target_ids_for_active_stack(State &state, DictRef battle) {
	const Atom active_id = string_or_empty(state, battle, key::active_stack_id);
	const State::MemoKey memo = board_read_key(BoardRead::attack_target_ids, battle, active_id);
	Value kept;
	uint64_t since = 0;
	if (state.memo_find(memo, { dict_value(battle) }, kept, since)) {
		return gd::as_array(kept);
	}
	const ArrayRef ids = _legal_attack_target_ids_for_active_stack_uncached(state, battle);
	state.memo_keep(memo, array_value(ids), since);
	return ids;
}

ArrayRef _legal_attack_target_ids_for_active_stack_uncached(State &state, DictRef battle) {
	const ArrayRef ids = state.new_array();
	// var seen := {}: String keys, so one atom per key.
	std::vector<Atom> seen;
	const auto seen_has = [&seen](Atom battle_id) {
		for (const Atom known : seen) {
			if (known == battle_id) {
				return true;
			}
		}
		return false;
	};
	const ArrayRef melee_ids = legal_attack_targets_for_active_stack(state, battle, false);
	for (const Value &battle_id_value : gd::items(state, array_value(melee_ids))) {
		const Atom battle_id = gd::to_string(battle_id_value);
		if (battle_id != key::empty && !seen_has(battle_id)) {
			seen.push_back(battle_id);
			state.append(ids, str(battle_id));
		}
	}
	const ArrayRef ranged_ids = legal_attack_targets_for_active_stack(state, battle, true);
	for (const Value &battle_id_value : gd::items(state, array_value(ranged_ids))) {
		const Atom battle_id = gd::to_string(battle_id_value);
		if (battle_id != key::empty && !seen_has(battle_id)) {
			seen.push_back(battle_id);
			state.append(ids, str(battle_id));
		}
	}
	return ids;
}

} // namespace aurelion::rules::port::battle_rules
