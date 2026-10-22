// Slice 10: the player's move order: the movement intent of a hex (its skeleton, step labels and message), the move
// carried out, and the selected target's continuity and closing context after it.

#include "aurelion_rules/port/battle_rules.hpp"

#include "aurelion_rules/compat/godot_math.hpp"

#include <string>

namespace aurelion::rules::port::battle_rules {

using compat::engine_max;
using gd::array_value;
using gd::bool_value;
using gd::dict_value;
using gd::int_value;
using gd::str;
using state::Kind;
namespace key = state::key;

namespace {

// String(d.get(field, "")).
Atom string_or_empty(const State &state, DictRef dict, Atom field) {
	return gd::string_field(state, dict, field, key::empty);
}

// session.battle: SessionData.battle is a typed Dictionary, read again at every
// use as GDScript reads it.
DictRef session_battle(State &state, const Value &session) {
	return gd::as_dict(gd::member(state, session, key::battle));
}

// _stack_label(stack) if not stack.is_empty() else "".
Atom label_or_empty(const State &state, DictRef stack) {
	return !gd::is_empty(state, stack) ? _stack_label(state, stack) : static_cast<Atom>(key::empty);
}

// {"ok": false, "message": message, "state": "invalid"}
DictRef invalid_result(State &state, Atom message) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(false));
	state.set(result, str(key::message), str(message));
	state.set(result, str(key::state), str(key::invalid));
	return result;
}

// [first, second] of two Strings: a new Array.
ArrayRef string_pair(State &state, Atom first, Atom second) {
	const ArrayRef array = state.new_array();
	state.append(array, str(first));
	state.append(array, str(second));
	return array;
}

// " ".join(strings) of an Array of Strings (String.join takes it as a
// PackedStringArray): every item, empty ones included.
Atom join_array_with_space(State &state, ArrayRef strings) {
	std::string joined;
	const int64_t size = state.array_size(strings);
	for (int64_t index = 0; index < size; ++index) {
		if (index > 0) {
			joined += state.text(key::space);
		}
		joined += state.text(gd::to_string(state.at(strings, index)));
	}
	return state.intern(joined);
}

} // namespace

DictRef movement_intent_for_destination(State &state, DictRef battle, int64_t q, int64_t r, const Value &preloaded_legal_destinations) {
	const DictRef active_stack = get_active_stack(state, battle);
	DictRef destination = _hex_in_bounds(q, r) ? _hex_cell(state, q, r) : state.new_dict();
	Atom refusal = key::empty;
	bool refusal_blocks = true;
	// var legal_destination := {}: always assigned before it is read.
	DictRef legal_destination = 0;
	if (gd::is_empty(state, battle)) {
		refusal = key::move_click_no_battle_text;
		refusal_blocks = false;
	} else if (gd::is_empty(state, active_stack)) {
		refusal = key::move_click_no_stack_ready_text;
		refusal_blocks = false;
	} else if (string_or_empty(state, active_stack, key::side) != key::player) {
		refusal = key::not_the_players_turn_text;
		refusal_blocks = false;
	} else if (gd::is_empty(state, destination)) {
		refusal = key::move_click_outside_battlefield_text;
	} else {
		legal_destination = gd::is_array(preloaded_legal_destinations)
				? _legal_destination_from_preloaded(state, preloaded_legal_destinations.ref, q, r)
				: _legal_destination_for_stack(state, battle, active_stack, destination);
		if (gd::is_empty(state, legal_destination)) {
			const Atom hex_label = _hex_label(state, destination);
			const Atom stack_label = _stack_label(state, active_stack);
			refusal = gd::format(state, key::move_click_not_legal_destination_text, { str(hex_label), str(stack_label) });
		}
	}
	// Only a refusal describes the requested hex. A legal move is described from
	// its legal destination, so the skeleton is built once per intent.
	if (refusal != key::empty) {
		const DictRef refused = _movement_intent_skeleton(state, battle, active_stack, destination);
		if (refusal_blocks) {
			state.set(refused, str(key::blocked), bool_value(true));
		}
		state.set(refused, str(key::message), str(refusal));
		return refused;
	}

	destination = legal_destination;
	const DictRef intent = _movement_intent_skeleton(state, battle, active_stack, destination);
	state.set(intent, str(key::action), str(key::move_));
	state.set(intent, str(key::label), str(key::Move));
	state.set(intent, str(key::movable), bool_value(true));
	state.set(intent, str(key::destination_count), int_value(1));
	state.set(intent, str(key::message), str(_movement_intent_message(state, battle, active_stack, destination, 1)));
	return intent;
}

DictRef _legal_destination_from_preloaded(State &state, ArrayRef destinations, int64_t q, int64_t r) {
	for (const Value &destination_value : gd::items(state, array_value(destinations))) {
		if (!gd::is_dict(destination_value)) {
			continue;
		}
		const DictRef destination = destination_value.ref;
		if (gd::int_field(state, destination, key::q, -1) == q && gd::int_field(state, destination, key::r, -1) == r) {
			return destination;
		}
	}
	return state.new_dict();
}

DictRef _movement_intent_skeleton(State &state, DictRef battle, DictRef active_stack, DictRef destination) {
	const DictRef selected_target = get_selected_target(state, battle);
	const DictRef selected_legality = _attack_legality_for_target(state, active_stack, selected_target, battle);
	const DictRef selected_closing_context = selected_target_closing_context(state, battle, true);
	const int64_t q = !gd::is_empty(state, destination) ? gd::int_field(state, destination, key::q, -1) : -1;
	const int64_t r = !gd::is_empty(state, destination) ? gd::int_field(state, destination, key::r, -1) : -1;
	const int64_t steps = !gd::is_empty(state, destination) ? gd::int_field(state, destination, key::steps, 0) : 0;
	const DictRef target_setup = _movement_target_setup_for_destination(state, battle, active_stack, destination, selected_legality);
	// The literal's entries in its order.
	const DictRef intent = state.new_dict();
	state.set(intent, str(key::action), str(key::empty));
	state.set(intent, str(key::label), str(key::empty));
	state.set(intent, str(key::movable), bool_value(false));
	state.set(intent, str(key::blocked), bool_value(false));
	state.set(intent, str(key::q), int_value(q));
	state.set(intent, str(key::r), int_value(r));
	state.set(intent, str(key::steps), int_value(steps));
	state.set(intent, str(key::step_count), int_value(steps));
	{
		const Atom step_label = steps > 0 ? _step_count_label(state, steps) : static_cast<Atom>(key::empty);
		state.set(intent, str(key::step_label), str(step_label));
	}
	{
		const Atom destination_label = !gd::is_empty(state, destination) ? _hex_label(state, destination) : static_cast<Atom>(key::empty);
		state.set(intent, str(key::destination_label), str(destination_label));
	}
	{
		const Atom destination_detail = !gd::is_empty(state, destination) ? _movement_destination_phrase(state, destination) : static_cast<Atom>(key::empty);
		state.set(intent, str(key::destination_detail), str(destination_detail));
	}
	state.set(intent, str(key::active_battle_id), str(string_or_empty(state, active_stack, key::battle_id)));
	state.set(intent, str(key::active_stack_name), str(label_or_empty(state, active_stack)));
	state.set(intent, str(key::selected_target_battle_id), str(string_or_empty(state, selected_target, key::battle_id)));
	state.set(intent, str(key::selected_target_name), str(label_or_empty(state, selected_target)));
	state.set(intent, str(key::selected_target_blocked), bool_value(gd::bool_field(state, selected_legality, key::blocked, false)));
	state.set(intent, str(key::selected_target_attackable), bool_value(gd::bool_field(state, selected_legality, key::attackable, false)));
	{
		bool closing_before_move = false;
		if (!gd::is_empty(state, selected_closing_context)) {
			const Atom closing_id = string_or_empty(state, selected_closing_context, key::battle_id);
			closing_before_move = closing_id == string_or_empty(state, selected_target, key::battle_id);
		}
		state.set(intent, str(key::selected_target_closing_before_move), bool_value(closing_before_move));
	}
	state.set(intent, str(key::selected_target_after_move_hex_distance), int_value(gd::int_field(state, target_setup, key::after_move_hex_distance, -1)));
	state.set(intent, str(key::selected_target_after_move_attackable), bool_value(gd::bool_field(state, target_setup, key::after_move_attackable, false)));
	state.set(intent, str(key::sets_up_selected_target_attack), bool_value(gd::bool_field(state, target_setup, key::sets_up_attack, false)));
	state.set(intent, str(key::selected_target_setup_action), str(string_or_empty(state, target_setup, key::action)));
	state.set(intent, str(key::selected_target_setup_label), str(string_or_empty(state, target_setup, key::label)));
	state.set(intent, str(key::closes_on_selected_target), bool_value(gd::bool_field(state, target_setup, key::closes_on_target, false)));
	state.set(intent, str(key::destination_count), int_value(0));
	state.set(intent, str(key::message), str(key::empty));
	return intent;
}

Atom _step_count_label(State &state, int64_t steps) {
	const Atom plural = steps == 1 ? static_cast<Atom>(key::empty) : static_cast<Atom>(key::s);
	return gd::format(state, key::step_count_label_text, { int_value(engine_max<int64_t>(0, steps)), str(plural) });
}

Atom _movement_destination_phrase(State &state, DictRef destination) {
	if (gd::is_empty(state, destination)) {
		return key::a_highlighted_hex_text;
	}
	Atom phrase = _hex_label(state, destination);
	const int64_t steps = gd::int_field(state, destination, key::steps, 0);
	if (steps > 0) {
		phrase = gd::format(state, key::phrase_with_steps_text, { str(phrase), str(_step_count_label(state, steps)) });
	}
	return phrase;
}

DictRef _movement_target_setup_for_destination(State &state, DictRef battle, DictRef active_stack, DictRef destination, DictRef current_legality) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::after_move_hex_distance), int_value(-1));
	state.set(result, str(key::after_move_attackable), bool_value(false));
	state.set(result, str(key::sets_up_attack), bool_value(false));
	state.set(result, str(key::action), str(key::empty));
	state.set(result, str(key::label), str(key::empty));
	state.set(result, str(key::closes_on_target), bool_value(false));
	const DictRef selected_target = get_selected_target(state, battle);
	if (gd::is_empty(state, active_stack) || gd::is_empty(state, selected_target) || gd::is_empty(state, destination) || gd::int_field(state, destination, key::steps, 0) <= 0) {
		return result;
	}
	// The left operand is converted first, as GDScript evaluates it.
	const Atom target_side = string_or_empty(state, selected_target, key::side);
	if (target_side == string_or_empty(state, active_stack, key::side)) {
		return result;
	}

	if (gd::is_empty(state, current_legality)) {
		current_legality = _attack_legality_for_target(state, active_stack, selected_target, battle);
	}
	const int64_t current_distance = gd::int_field(state, current_legality, key::hex_distance, -1);
	const DictRef projected_stack = gd::deep_duplicate_dict(state, active_stack);
	state.set(projected_stack, str(key::hex), dict_value(_normalize_hex_cell(state, dict_value(destination))));
	const DictRef projected_legality = _attack_legality_for_target(state, projected_stack, selected_target, battle);
	const int64_t after_distance = gd::int_field(state, projected_legality, key::hex_distance, -1);
	state.set(result, str(key::after_move_hex_distance), int_value(after_distance));
	state.set(result, str(key::after_move_attackable), bool_value(gd::bool_field(state, projected_legality, key::attackable, false)));
	state.set(result, str(key::closes_on_target), bool_value(current_distance >= 0 && after_distance >= 0 && after_distance < current_distance));
	if (gd::bool_field(state, projected_legality, key::melee, false)) {
		state.set(result, str(key::action), str(key::strike));
		state.set(result, str(key::label), str(key::Strike));
	} else if (gd::bool_field(state, projected_legality, key::ranged, false)) {
		state.set(result, str(key::action), str(key::shoot));
		state.set(result, str(key::label), str(key::Shoot));
	}
	const bool sets_up_attack = gd::bool_field(state, current_legality, key::blocked, false) && gd::bool_field(state, projected_legality, key::attackable, false);
	state.set(result, str(key::sets_up_attack), bool_value(sets_up_attack));
	return result;
}

Atom _movement_intent_message(State &state, DictRef battle, DictRef active_stack, DictRef destination, int64_t destination_count) {
	const Atom active_label = !gd::is_empty(state, active_stack) ? _stack_label(state, active_stack) : static_cast<Atom>(key::the_active_stack_text);
	const DictRef selected_target = get_selected_target(state, battle);
	const DictRef selected_legality = _attack_legality_for_target(state, active_stack, selected_target, battle);
	bool selected_blocked = false;
	if (!gd::is_empty(state, selected_target)) {
		const Atom target_side = string_or_empty(state, selected_target, key::side);
		selected_blocked = target_side != string_or_empty(state, active_stack, key::side)
				&& gd::bool_field(state, selected_legality, key::blocked, false);
	}
	const int64_t legal_attack_count = state.array_size(_legal_attack_target_ids_for_active_stack(state, battle));
	if (destination_count <= 0) {
		if (selected_blocked) {
			return gd::format(state, key::move_click_no_legal_move_target_blocked_text, { str(_stack_label(state, selected_target)) });
		}
		return gd::format(state, key::move_click_no_legal_movement_hex_text, { str(active_label) });
	}

	Atom destination_phrase = key::a_highlighted_hex_text;
	if (!gd::is_empty(state, destination)) {
		destination_phrase = _movement_destination_phrase(state, destination);
	}

	if (selected_blocked) {
		// The default current_legality: a new {}.
		const DictRef target_setup = _movement_target_setup_for_destination(state, battle, active_stack, destination, state.new_dict());
		if (!gd::is_empty(state, destination) && gd::bool_field(state, target_setup, key::sets_up_attack, false)) {
			const Atom setup_label = gd::string_field(state, target_setup, key::label, key::attack);
			const Atom target_label = _stack_label(state, selected_target);
			return gd::format(state, key::move_click_sets_up_later_text, { str(active_label), str(destination_phrase), str(setup_label), str(target_label) });
		}
		if (!gd::is_empty(state, destination) && gd::bool_field(state, target_setup, key::closes_on_target, false)) {
			return gd::format(state, key::move_click_closes_toward_blocked_text, { str(active_label), str(destination_phrase), str(_stack_label(state, selected_target)) });
		}
		if (!gd::is_empty(state, destination)) {
			return gd::format(state, key::move_click_remains_blocked_text, { str(active_label), str(destination_phrase), str(_stack_label(state, selected_target)) });
		}
		if (legal_attack_count > 0) {
			return gd::format(state, key::select_move_hex_preview_text, { str(active_label), str(destination_phrase) });
		}
		return gd::format(state, key::move_click_move_toward_text, { str(active_label), str(destination_phrase), str(_stack_label(state, selected_target)) });
	}
	return gd::format(state, key::move_click_move_to_text, { str(active_label), str(destination_phrase) });
}

DictRef move_active_stack_to_hex(State &state, const Value &session, int64_t q, int64_t r) {
	if (session.kind == Kind::Nil || gd::is_empty(state, session_battle(state, session))) {
		return invalid_result(state, key::no_battle_is_active_text);
	}
	const DictRef movement_intent = movement_intent_for_destination(state, session_battle(state, session), q, r, Value());
	const DictRef active_stack = get_active_stack(state, session_battle(state, session));
	if (gd::is_empty(state, active_stack) || string_or_empty(state, active_stack, key::side) != key::player) {
		const Atom message = gd::string_field(state, movement_intent, key::message, key::not_the_players_turn_text);
		return _attach_movement_intent_to_result(state, invalid_result(state, message), movement_intent);
	}
	if (!_hex_in_bounds(q, r)) {
		const Atom message = gd::string_field(state, movement_intent, key::message, key::hex_outside_battlefield_text);
		return _attach_movement_intent_to_result(state, invalid_result(state, message), movement_intent);
	}
	const DictRef destination = _hex_cell(state, q, r);
	const DictRef legal_destination = _legal_destination_for_stack(state, session_battle(state, session), active_stack, destination);
	if (gd::is_empty(state, legal_destination)) {
		const Atom message = gd::string_field(state, movement_intent, key::message, key::hex_not_legal_destination_text);
		return _attach_movement_intent_to_result(state, invalid_result(state, message), movement_intent);
	}
	_clear_stack_animation_states(state, session_battle(state, session));
	return _resolve_move_action(state, session, active_stack, legal_destination, key::moves, movement_intent);
}

DictRef _legal_destination_for_stack(State &state, DictRef battle, DictRef stack, DictRef destination) {
	const DictRef normalized = _normalize_hex_cell(state, dict_value(destination));
	if (gd::is_empty(state, normalized)) {
		return state.new_dict();
	}
	const ArrayRef candidates = legal_destinations_for_stack(state, battle, string_or_empty(state, stack, key::battle_id));
	for (const Value &candidate : gd::items(state, array_value(candidates))) {
		if (gd::is_dict(candidate) && _hex_key(state, candidate.ref) == _hex_key(state, normalized)) {
			const DictRef found = candidate.ref;
			return gd::deep_duplicate_dict(state, found);
		}
	}
	return state.new_dict();
}

DictRef _resolve_move_action(State &state, const Value &session, DictRef active_stack, DictRef destination, Atom verb, DictRef movement_intent) {
	const DictRef start_hex = _stack_hex(state, active_stack);
	{
		const DictRef battle = session_battle(state, session);
		_set_stack_hex(state, battle, string_or_empty(state, active_stack, key::battle_id), destination);
	}
	{
		// The arguments in the GDScript order: the battle, the id, then the literal.
		const DictRef battle = session_battle(state, session);
		const Atom battle_id = string_or_empty(state, active_stack, key::battle_id);
		const DictRef move_context = state.new_dict();
		state.set(move_context, str(key::from_q), int_value(gd::int_field(state, start_hex, key::q, -1)));
		state.set(move_context, str(key::from_r), int_value(gd::int_field(state, start_hex, key::r, -1)));
		state.set(move_context, str(key::to_q), int_value(gd::int_field(state, destination, key::q, -1)));
		state.set(move_context, str(key::to_r), int_value(gd::int_field(state, destination, key::r, -1)));
		_mark_stack_animation_event(state, battle, battle_id, key::battle_unit_move, move_context);
	}
	_sync_distance_from_hexes(state, session_battle(state, session));
	Atom pressure_message = key::empty;
	{
		const DictRef battle = session_battle(state, session);
		pressure_message = _apply_advance_pressure(state, battle, string_or_empty(state, active_stack, key::battle_id));
	}
	DictRef updated_stack = 0;
	{
		const DictRef battle = session_battle(state, session);
		updated_stack = _get_stack_by_id(state, battle, string_or_empty(state, active_stack, key::battle_id));
	}
	Atom message = gd::strip_edges(state, string_or_empty(state, movement_intent, key::message));
	if (message == key::empty) {
		const Atom stack_label = _stack_label(state, updated_stack);
		const Atom start_label = _hex_label(state, start_hex);
		const Atom destination_label = _hex_label(state, destination);
		message = gd::format(state, key::stack_verb_from_to_text, { str(stack_label), str(verb), str(start_label), str(destination_label) });
	}
	{
		const DictRef battle = session_battle(state, session);
		const Atom actor_battle_id = string_or_empty(state, updated_stack, key::battle_id);
		const Atom start_label = _hex_label(state, start_hex);
		const Atom destination_label = _hex_label(state, destination);
		const Atom detail_text = gd::format(state, key::hex_to_hex_text, { str(start_label), str(destination_label) });
		const DictRef event_context = state.new_dict();
		state.set(event_context, str(key::action_id), str(key::move_));
		state.set(event_context, str(key::actor_battle_id), str(actor_battle_id));
		state.set(event_context, str(key::detail_text), str(detail_text));
		_append_presentation_event(state, battle, key::move_, message, event_context);
	}
	if (pressure_message != key::empty) {
		message = _join_messages(state, string_pair(state, message, pressure_message));
		const DictRef battle = session_battle(state, session);
		const ArrayRef texts = state.new_array();
		state.append(texts, str(pressure_message));
		_append_text_presentation_event(state, battle, key::momentum, texts, updated_stack, state.new_dict(), key::move_);
	}
	ArrayRef objective_messages = 0;
	{
		const DictRef battle = session_battle(state, session);
		const DictRef action_context = state.new_dict();
		state.set(action_context, str(key::action), str(key::advance));
		state.set(action_context, str(key::side), str(string_or_empty(state, updated_stack, key::side)));
		state.set(action_context, str(key::battle_id), str(string_or_empty(state, updated_stack, key::battle_id)));
		objective_messages = _apply_field_objective_action_pressure(state, battle, action_context);
	}
	if (state.array_size(objective_messages) > 0) {
		message = _join_messages(state, string_pair(state, message, join_array_with_space(state, objective_messages)));
	}
	// _complete_action can end the battle (a host call): session.battle is read
	// again below, the new empty Dictionary then.
	DictRef result = _complete_action(state, session, message, true);
	const bool continuity_preserved = _apply_setup_move_target_continuity(state, session_battle(state, session), movement_intent, result);
	bool ordinary_closing_recorded = false;
	if (continuity_preserved) {
		_clear_selected_target_closing(state, session_battle(state, session));
	} else {
		ordinary_closing_recorded = _apply_ordinary_closing_target_context(state, session_battle(state, session), movement_intent, result);
	}
	result = _attach_movement_intent_to_result(state, result, movement_intent);
	state.set(result, str(key::selected_target_continuity_preserved), bool_value(continuity_preserved));
	state.set(result, str(key::selected_target_closing_on_target), bool_value(ordinary_closing_recorded));
	return _attach_post_move_target_context(state, result, session_battle(state, session));
}

DictRef _attach_movement_intent_to_result(State &state, DictRef result, DictRef movement_intent) {
	if (gd::is_empty(state, movement_intent)) {
		return result;
	}
	state.set(result, str(key::movement_intent), dict_value(gd::deep_duplicate_dict(state, movement_intent)));
	state.set(result, str(key::preview_message), str(string_or_empty(state, movement_intent, key::message)));
	state.set(result, str(key::destination_detail), str(string_or_empty(state, movement_intent, key::destination_detail)));
	state.set(result, str(key::steps), int_value(gd::int_field(state, movement_intent, key::steps, 0)));
	{
		const Value steps_fallback = state.get(result, str(key::steps), int_value(0));
		state.set(result, str(key::step_count), int_value(gd::to_int(state, state.get(movement_intent, str(key::step_count), steps_fallback))));
	}
	state.set(result, str(key::sets_up_selected_target_attack), bool_value(gd::bool_field(state, movement_intent, key::sets_up_selected_target_attack, false)));
	state.set(result, str(key::selected_target_setup_label), str(string_or_empty(state, movement_intent, key::selected_target_setup_label)));
	state.set(result, str(key::selected_target_after_move_attackable), bool_value(gd::bool_field(state, movement_intent, key::selected_target_after_move_attackable, false)));
	state.set(result, str(key::selected_target_after_move_hex_distance), int_value(gd::int_field(state, movement_intent, key::selected_target_after_move_hex_distance, -1)));
	state.set(result, str(key::selected_target_closing_before_move), bool_value(gd::bool_field(state, movement_intent, key::selected_target_closing_before_move, false)));
	state.set(result, str(key::closes_on_selected_target), bool_value(gd::bool_field(state, movement_intent, key::closes_on_selected_target, false)));
	return result;
}

DictRef _attach_post_move_target_context(State &state, DictRef result, DictRef battle) {
	if (gd::is_empty(state, battle)) {
		return result;
	}
	const DictRef active_stack = get_active_stack(state, battle);
	const DictRef selected_target = get_selected_target(state, battle);
	const DictRef selected_legality = selected_target_legality(state, battle);
	const DictRef selected_click_intent = selected_target_board_click_intent(state, battle);
	const DictRef selected_continuity_context = selected_target_continuity_context(state, battle);
	const DictRef selected_closing_context = selected_target_closing_context(state, battle, true);
	state.set(result, str(key::active_stack_after_move_battle_id), str(string_or_empty(state, active_stack, key::battle_id)));
	state.set(result, str(key::active_stack_after_move_side), str(string_or_empty(state, active_stack, key::side)));
	state.set(result, str(key::selected_target_after_move_battle_id), str(string_or_empty(state, selected_target, key::battle_id)));
	state.set(result, str(key::selected_target_after_move_name), str(label_or_empty(state, selected_target)));
	state.set(result, str(key::selected_target_after_move_legality), dict_value(gd::deep_duplicate_dict(state, selected_legality)));
	state.set(result, str(key::selected_target_after_move_board_click_intent), dict_value(gd::deep_duplicate_dict(state, selected_click_intent)));
	state.set(result, str(key::selected_target_after_move_board_click_action), str(string_or_empty(state, selected_click_intent, key::action)));
	state.set(result, str(key::selected_target_after_move_board_click_label), str(string_or_empty(state, selected_click_intent, key::label)));
	state.set(result, str(key::selected_target_continuity_context), dict_value(gd::deep_duplicate_dict(state, selected_continuity_context)));
	state.set(result, str(key::selected_target_preserved_setup), bool_value(!gd::is_empty(state, selected_continuity_context)));
	state.set(result, str(key::selected_target_closing_context), dict_value(gd::deep_duplicate_dict(state, selected_closing_context)));
	state.set(result, str(key::selected_target_closing_on_target), bool_value(!gd::is_empty(state, selected_closing_context)));
	const Atom selected_action_label = string_or_empty(state, selected_click_intent, key::label);
	const bool actionable = gd::is_empty(state, selected_continuity_context)
			&& gd::is_empty(state, selected_closing_context)
			&& gd::bool_field(state, selected_legality, key::attackable, false)
			&& selected_action_label != key::empty;
	state.set(result, str(key::selected_target_actionable_after_move), bool_value(actionable));
	if (!gd::is_empty(state, selected_continuity_context)) {
		// The get's fallback is evaluated before the get.
		const Value fallback = state.get(selected_click_intent, str(key::message), str(key::empty));
		state.set(result, str(key::post_move_target_guidance), str(gd::to_string(state.get(selected_continuity_context, str(key::message), fallback))));
	} else if (!gd::is_empty(state, selected_closing_context)) {
		const Value fallback = state.get(selected_click_intent, str(key::message), str(key::empty));
		state.set(result, str(key::post_move_target_guidance), str(gd::to_string(state.get(selected_closing_context, str(key::message), fallback))));
	} else if (gd::bool_field(state, result, key::selected_target_actionable_after_move, false)) {
		const Atom guidance = gd::format(state, key::target_legality_select_preview_text, { str(selected_action_label), str(_stack_label(state, selected_target)) });
		state.set(result, str(key::post_move_target_guidance), str(guidance));
	} else {
		state.set(result, str(key::post_move_target_guidance), str(string_or_empty(state, selected_click_intent, key::message)));
	}
	return result;
}

bool _apply_setup_move_target_continuity(State &state, DictRef battle, DictRef movement_intent, DictRef result) {
	if (gd::is_empty(state, battle)) {
		return false;
	}
	const Atom result_state = gd::string_field(state, result, key::state, key::continue_);
	if (result_state != key::empty && result_state != key::continue_) {
		_clear_selected_target_continuity(state, battle);
		return false;
	}
	if (!gd::bool_field(state, movement_intent, key::sets_up_selected_target_attack, false)) {
		return false;
	}
	if (gd::bool_field(state, movement_intent, key::selected_target_closing_before_move, false)) {
		_clear_selected_target_continuity(state, battle);
		return false;
	}
	const Atom target_id = string_or_empty(state, movement_intent, key::selected_target_battle_id);
	const DictRef active_stack = get_active_stack(state, battle);
	if (_selected_target_can_remain_for_active_stack(state, battle, active_stack, target_id)) {
		state.set(battle, str(key::selected_target_continuity_id), str(target_id));
		_set_selected_target(state, battle, target_id, false);
		return true;
	}
	if (string_or_empty(state, active_stack, key::side) == key::player) {
		_clear_selected_target_continuity(state, battle);
	}
	return false;
}

bool _apply_ordinary_closing_target_context(State &state, DictRef battle, DictRef movement_intent, DictRef result) {
	_clear_selected_target_closing(state, battle);
	if (gd::is_empty(state, battle)) {
		return false;
	}
	const Atom result_state = gd::string_field(state, result, key::state, key::continue_);
	if (result_state != key::empty && result_state != key::continue_) {
		return false;
	}
	if (
			gd::bool_field(state, movement_intent, key::sets_up_selected_target_attack, false)
			|| !gd::bool_field(state, movement_intent, key::closes_on_selected_target, false)
			|| !gd::bool_field(state, movement_intent, key::selected_target_blocked, false)
			|| gd::bool_field(state, movement_intent, key::selected_target_after_move_attackable, false)) {
		return false;
	}
	const Atom target_id = string_or_empty(state, movement_intent, key::selected_target_battle_id);
	if (target_id == key::empty || string_or_empty(state, battle, key::selected_target_id) != target_id) {
		return false;
	}
	const DictRef active_stack = get_active_stack(state, battle);
	const DictRef selected_target = get_selected_target(state, battle);
	const DictRef selected_legality = selected_target_legality(state, battle);
	const Atom mover_id = string_or_empty(state, movement_intent, key::active_battle_id);
	if (
			gd::is_empty(state, active_stack)
			|| string_or_empty(state, active_stack, key::side) != key::player
			|| mover_id == key::empty
			|| string_or_empty(state, active_stack, key::battle_id) != mover_id
			|| gd::is_empty(state, selected_target)
			|| string_or_empty(state, selected_target, key::battle_id) != target_id
			|| !gd::bool_field(state, selected_legality, key::blocked, false)) {
		return false;
	}
	// The literal's entries in its order; each get's fallback is evaluated
	// before the get.
	const DictRef context = state.new_dict();
	state.set(context, str(key::ordinary_closing_target), bool_value(true));
	state.set(context, str(key::preserved_setup_target), bool_value(false));
	state.set(context, str(key::battle_id), str(target_id));
	{
		const Atom target_label = _stack_label(state, selected_target);
		state.set(context, str(key::target_name), str(gd::string_field(state, movement_intent, key::selected_target_name, target_label)));
	}
	state.set(context, str(key::mover_battle_id), str(string_or_empty(state, movement_intent, key::active_battle_id)));
	state.set(context, str(key::mover_name), str(string_or_empty(state, movement_intent, key::active_stack_name)));
	state.set(context, str(key::active_battle_id), str(string_or_empty(state, active_stack, key::battle_id)));
	state.set(context, str(key::active_stack_name), str(_stack_label(state, active_stack)));
	state.set(context, str(key::destination_detail), str(string_or_empty(state, movement_intent, key::destination_detail)));
	{
		const Value steps_fallback = state.get(movement_intent, str(key::steps), int_value(0));
		state.set(context, str(key::step_count), int_value(gd::to_int(state, state.get(movement_intent, str(key::step_count), steps_fallback))));
	}
	state.set(context, str(key::after_move_hex_distance), int_value(gd::int_field(state, movement_intent, key::selected_target_after_move_hex_distance, -1)));
	state.set(battle, str(key::selected_target_closing_context), dict_value(context));
	return true;
}

} // namespace aurelion::rules::port::battle_rules
