// Slice 10: the enemy's turn: the drain of enemy turns up to the next player stack, an enemy stack's order (its
// commander's free cast first, then the shot, strike, advance, defend, wait or withdrawal) and the end of its action.

#include "aurelion_rules/port/battle_rules.hpp"

#include "aurelion_rules/port/ai_route.hpp"
#include "aurelion_rules/port/battle_ai_rules.hpp"
#include "aurelion_rules/port/spell_rules.hpp"

#include <initializer_list>
#include <string>
#include <vector>

namespace aurelion::rules::port::battle_rules {

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

// session.battle (SessionData types it Dictionary), read where the GDScript reads it: a battle end leaves a new
// empty Dictionary there.
DictRef session_battle(State &state, const Value &session) {
	return gd::as_dict(gd::member(state, session, key::battle));
}

// d.get(key, {}): a new Dictionary when the key is missing.
Value get_or_new_dict(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return dict_value(state.new_dict());
}

// d.get(key, {}) if d.get(key, {}) is Dictionary else {}: the stored Dictionary, else a new empty one.
DictRef stored_dict_or_new(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found) && gd::is_dict(found)) {
		return found.ref;
	}
	return state.new_dict();
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

// var x = d.get(key, {}), only read by `x is Dictionary and not x.is_empty()`: true with the stored value in found.
bool nonempty_dict_field(const State &state, DictRef dict, Atom field, Value &found) {
	return state.lookup(dict, str(field), found) && gd::is_dict(found) && !gd::is_empty(state, found.ref);
}

// {"ok": ok, "message": message, "state": result_state}
DictRef action_result(State &state, bool ok, Atom message, Atom result_state) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(ok));
	state.set(result, str(key::message), str(message));
	state.set(result, str(key::state), str(result_state));
	return result;
}

// {"action_id": action_id, "actor_battle_id": actor_battle_id}
DictRef actor_context(State &state, Atom action_id, Atom actor_battle_id) {
	const DictRef context = state.new_dict();
	state.set(context, str(key::action_id), str(action_id));
	state.set(context, str(key::actor_battle_id), str(actor_battle_id));
	return context;
}

// {"action_id": action_id, "actor_battle_id": actor_battle_id, "target_battle_id": target_battle_id}
DictRef actor_target_context(State &state, Atom action_id, Atom actor_battle_id, Atom target_battle_id) {
	const DictRef context = actor_context(state, action_id, actor_battle_id);
	state.set(context, str(key::target_battle_id), str(target_battle_id));
	return context;
}

// {"target_battle_id": target_battle_id}
DictRef target_context(State &state, Atom target_battle_id) {
	const DictRef context = state.new_dict();
	state.set(context, str(key::target_battle_id), str(target_battle_id));
	return context;
}

// {"action": action, "side": side, "battle_id": battle_id}, the field objectives' action context.
DictRef objective_context(State &state, Atom action, Atom side, Atom battle_id) {
	const DictRef context = state.new_dict();
	state.set(context, str(key::action), str(action));
	state.set(context, str(key::side), str(side));
	state.set(context, str(key::battle_id), str(battle_id));
	return context;
}

// [text]: an Array literal of one String.
ArrayRef one_text(State &state, Atom text) {
	const ArrayRef array = state.new_array();
	state.append(array, str(text));
	return array;
}

// _join_messages([first, second]).
Atom join_two(State &state, Atom first, Atom second) {
	const ArrayRef parts = state.new_array();
	state.append(parts, str(first));
	state.append(parts, str(second));
	return _join_messages(state, parts);
}

// text + suffix of Strings (text += suffix).
Atom concat(State &state, Atom text, Atom suffix) {
	return state.intern(state.text(text) + state.text(suffix));
}

// " ".join(values): String.join takes a PackedStringArray, so each item is String(item).
Atom join_values(State &state, const std::vector<Value> &values) {
	std::string joined;
	for (size_t index = 0; index < values.size(); ++index) {
		const Atom part = gd::stringify(state, values[index]);
		if (index > 0) {
			joined += state.text(key::space);
		}
		joined += state.text(part);
	}
	return state.intern(joined);
}

// " ".join(array) of an Array.
Atom join_array(State &state, ArrayRef array) {
	std::vector<Value> values;
	const int64_t size = state.array_size(array);
	for (int64_t index = 0; index < size; ++index) {
		values.push_back(state.at(array, index));
	}
	return join_values(state, values);
}

// " ".join(parts) of Strings.
Atom join_atoms(State &state, const std::vector<Atom> &parts) {
	std::string joined;
	for (size_t index = 0; index < parts.size(); ++index) {
		if (index > 0) {
			joined += state.text(key::space);
		}
		joined += state.text(parts[index]);
	}
	return state.intern(joined);
}

// s.to_lower() of ASCII text. Other text is not ported: the Unicode case tables are the engine's.
Atom to_lower(State &state, Atom text, const char *where) {
	std::string lowered = state.text(text);
	for (char &c : lowered) {
		if (static_cast<unsigned char>(c) >= 0x80) {
			throw state::NotPorted(std::string(where) + ": to_lower() of non-ASCII text");
		}
		if (c >= 'A' && c <= 'Z') {
			c = static_cast<char>(c - 'A' + 'a');
		}
	}
	return state.intern(lowered);
}

// An enemy stack's advance: the "advance" order's own and the fallback's, word for word the same in the GDScript.
DictRef enemy_advance(State &state, const Value &session, DictRef active_stack) {
	const bool stalled = _advance_stalled_by_obstruction(state, active_stack, session_battle(state, session));
	_apply_auto_advance_movement(state, session_battle(state, session), active_stack);
	const Atom event_text = gd::format(state, key::stack_advances_text, { str(_stack_label(state, active_stack)) });
	const DictRef event_context = actor_context(state, key::advance, string_or_empty(state, active_stack, key::battle_id));
	_append_presentation_event(state, session_battle(state, session), key::move_, event_text, event_context);
	Atom advance_message = gd::format(state, key::stack_advances_text, { str(_stack_label(state, active_stack)) });
	const Atom advance_pressure = _apply_advance_pressure(state, session_battle(state, session), string_or_empty(state, active_stack, key::battle_id));
	if (advance_pressure != key::empty) {
		advance_message = concat(state, advance_message, gd::format(state, key::space_s_text, { str(advance_pressure) }));
		_append_text_presentation_event(state, session_battle(state, session), key::momentum, one_text(state, advance_pressure), active_stack, state.new_dict(), key::advance);
	}
	if (stalled) {
		advance_message = join_two(state, advance_message, key::obstruction_holds_push_text);
	}
	const DictRef action_context = objective_context(state, key::advance, key::enemy, string_or_empty(state, active_stack, key::battle_id));
	const ArrayRef advance_objective_messages = _apply_field_objective_action_pressure(state, session_battle(state, session), action_context);
	if (state.array_size(advance_objective_messages) != 0) {
		advance_message = join_two(state, advance_message, join_array(state, advance_objective_messages));
	}
	_mark_stack_animation_event(state, session_battle(state, session), string_or_empty(state, active_stack, key::battle_id), key::battle_unit_move, state.new_dict());
	return _complete_enemy_action(state, session, advance_message);
}

} // namespace

DictRef _run_enemy_turn(State &state, const Value &session, DictRef active_stack) {
	if (gd::is_empty(state, active_stack)) {
		return action_result(state, false, key::empty, key::invalid);
	}

	const ArrayRef targets = _alive_stacks_for_side(state, session_battle(state, session), key::player);
	if (state.array_size(targets) == 0) {
		const DictRef defeat_result = _finalize_player_battle_loss(state, session);
		const Atom message = join_two(state, key::army_is_broken_text, string_or_empty(state, defeat_result, key::message));
		return action_result(state, true, message, gd::string_field(state, defeat_result, key::state, key::defeat));
	}

	const DictRef enemy_hero = gd::as_dict(get_or_new_dict(state, session_battle(state, session), key::enemy_hero));
	const DictRef action = ai_route::by_stack(state, dict_value(active_stack), [&] { return battle_ai_rules::choose_enemy_action(state, session_battle(state, session), active_stack, enemy_hero, true); });
	if (string_or_empty(state, action, key::action) != key::cast_spell) {
		return _run_enemy_stack_order(state, session, active_stack, action);
	}
	// The hero casts first, as a free action; then the stack gives its own order.
	const DictRef cast_result = _cast_enemy_spell(state, session, active_stack, action);
	const Atom cast_state = gd::string_field(state, cast_result, key::state, key::continue_);
	if (gd::bool_field(state, cast_result, key::ok, false) && cast_state != key::continue_) {
		return cast_result;
	}
	const Atom cast_message = gd::bool_field(state, cast_result, key::ok, false) ? string_or_empty(state, cast_result, key::message) : static_cast<Atom>(key::empty);
	active_stack = _get_stack_by_id(state, session_battle(state, session), string_or_empty(state, active_stack, key::battle_id));
	const DictRef order_hero = gd::as_dict(get_or_new_dict(state, session_battle(state, session), key::enemy_hero));
	const DictRef order = ai_route::by_stack(state, dict_value(active_stack), [&] { return battle_ai_rules::choose_enemy_action(state, session_battle(state, session), active_stack, order_hero, false); });
	const DictRef order_result = _run_enemy_stack_order(state, session, active_stack, order);
	if (cast_message != key::empty) {
		state.set(order_result, str(key::message), str(join_two(state, cast_message, string_or_empty(state, order_result, key::message))));
	}
	return order_result;
}

DictRef _run_enemy_stack_order(State &state, const Value &session, DictRef active_stack, DictRef action) {
	const ArrayRef targets = _alive_stacks_for_side(state, session_battle(state, session), key::player);
	const Atom order = string_or_empty(state, action, key::action);
	if (order == key::retreat) {
		if (!_battle_retreat_allowed(state, session_battle(state, session)) || !gd::bool_field(state, session_battle(state, session), key::enemy_withdrawal_allowed, false)) {
			return action_result(state, false, key::enemy_retreat_locked_text, key::invalid);
		}
		_mark_side_animation_event(state, session_battle(state, session), key::enemy, key::battle_unit_retreat);
		return _finalize_enemy_withdrawal(state, session, key::enemy_retreat);
	}
	if (order == key::surrender) {
		if (!_battle_surrender_allowed(state, session_battle(state, session)) || !gd::bool_field(state, session_battle(state, session), key::enemy_withdrawal_allowed, false)) {
			return action_result(state, false, key::enemy_surrender_locked_text, key::invalid);
		}
		_mark_side_animation_event(state, session_battle(state, session), key::enemy, key::battle_unit_surrender);
		return _finalize_enemy_withdrawal(state, session, key::enemy_surrender);
	}
	// Sanctuary: the stack makes no attack while it lasts, so it holds its ground.
	if (spell_rules::in_sanctuary(state, session_battle(state, session), active_stack) && order != key::wait && order != key::defend) {
		return _resolve_enemy_defend(state, session, active_stack);
	}
	if (order == key::shoot) {
		const DictRef target = _get_stack_by_id(state, session_battle(state, session), string_or_empty(state, action, key::target_battle_id));
		return _resolve_ai_attack(state, session, active_stack, target, true);
	}
	if (order == key::strike) {
		// It may step to a better side first, such as one next to a shooter (ai_melee_approach).
		const DictRef strike_target = _get_stack_by_id(state, session_battle(state, session), string_or_empty(state, action, key::target_battle_id));
		const DictRef strike_from = ai_melee_approach(state, session_battle(state, session), active_stack, strike_target);
		// Stand fast (Heartwood Stance) counts only a strike made without moving first.
		const bool marks_move = gd::int_field(state, strike_from, key::steps, 0) > 0
				&& spell_rules::stack_mechanic_int(state, active_stack, session_battle(state, session), key::stationary_attack) > 0;
		if (gd::int_field(state, strike_from, key::steps, 0) > 0) {
			_apply_melee_approach(state, session_battle(state, session), active_stack, strike_from);
			active_stack = _get_stack_by_id(state, session_battle(state, session), string_or_empty(state, active_stack, key::battle_id));
		}
		if (marks_move) {
			state.set(session_battle(state, session), str(key::strike_moved_battle_id), str(string_or_empty(state, active_stack, key::battle_id)));
		}
		const DictRef strike_result = _resolve_ai_attack(state, session, active_stack, strike_target, false);
		if (marks_move) {
			state.erase(session_battle(state, session), str(key::strike_moved_battle_id));
		}
		return strike_result;
	}
	if (order == key::advance) {
		const DictRef plan = ai_advance_plan(state, session_battle(state, session), active_stack);
		const Atom plan_action = gd::string_field(state, plan, key::action, key::advance);
		if (plan_action == key::defend) {
			return _resolve_enemy_defend(state, session, active_stack);
		}
		if (plan_action == key::wait) {
			return _resolve_enemy_wait(state, session, active_stack);
		}
		if (plan_action == key::strike) {
			const DictRef plan_target = _get_stack_by_id(state, session_battle(state, session), string_or_empty(state, plan, key::target_battle_id));
			const DictRef plan_approach = typed_dict_field(state, plan, key::approach);
			const bool marks_move = gd::int_field(state, plan_approach, key::steps, 0) > 0
					&& spell_rules::stack_mechanic_int(state, active_stack, session_battle(state, session), key::stationary_attack) > 0;
			if (gd::int_field(state, plan_approach, key::steps, 0) > 0) {
				_apply_melee_approach(state, session_battle(state, session), active_stack, plan_approach);
			}
			const DictRef attacker = _get_stack_by_id(state, session_battle(state, session), string_or_empty(state, active_stack, key::battle_id));
			if (marks_move) {
				state.set(session_battle(state, session), str(key::strike_moved_battle_id), str(string_or_empty(state, attacker, key::battle_id)));
			}
			const DictRef plan_result = _resolve_ai_attack(state, session, attacker, plan_target, false);
			if (marks_move) {
				state.erase(session_battle(state, session), str(key::strike_moved_battle_id));
			}
			return plan_result;
		}
		return enemy_advance(state, session, active_stack);
	}
	if (order == key::defend) {
		return _resolve_enemy_defend(state, session, active_stack);
	}
	if (order == key::wait) {
		return _resolve_enemy_wait(state, session, active_stack);
	}
	const DictRef fallback = _lowest_health_stack(state, targets);
	if (gd::bool_field(state, active_stack, key::ranged, false) && gd::int_field(state, active_stack, key::shots_remaining, 0) > 0) {
		return _resolve_ai_attack(state, session, active_stack, fallback, true);
	}
	if (gd::int_field(state, session_battle(state, session), key::distance, 1) > 0 && !_stack_is_rooted(state, active_stack, session_battle(state, session))) {
		return enemy_advance(state, session, active_stack);
	}
	return _resolve_ai_attack(state, session, active_stack, fallback, false);
}

DictRef _resolve_enemy_defend(State &state, const Value &session, DictRef active_stack) {
	_set_stack_defending(state, session_battle(state, session), string_or_empty(state, active_stack, key::battle_id));
	_mark_stack_animation_event(state, session_battle(state, session), string_or_empty(state, active_stack, key::battle_id), key::battle_unit_defend, state.new_dict());
	const Atom brace_format = spell_rules::in_mire(state, session_battle(state, session), active_stack) ? static_cast<Atom>(key::stuck_in_mire_text) : static_cast<Atom>(key::braces_for_impact_text);
	const Atom event_text = gd::format(state, brace_format, { str(_stack_label(state, active_stack)) });
	const DictRef event_context = actor_context(state, key::defend, string_or_empty(state, active_stack, key::battle_id));
	_append_presentation_event(state, session_battle(state, session), key::buff, event_text, event_context);
	Atom defend_message = gd::format(state, brace_format, { str(_stack_label(state, active_stack)) });
	const Atom defend_pressure = _apply_defend_pressure(state, session_battle(state, session), string_or_empty(state, active_stack, key::battle_id));
	if (defend_pressure != key::empty) {
		defend_message = concat(state, defend_message, gd::format(state, key::space_s_text, { str(defend_pressure) }));
		_append_text_presentation_event(state, session_battle(state, session), key::morale, one_text(state, defend_pressure), active_stack, state.new_dict(), key::defend);
	}
	const DictRef action_context = objective_context(state, key::defend, key::enemy, string_or_empty(state, active_stack, key::battle_id));
	const ArrayRef defend_objective_messages = _apply_field_objective_action_pressure(state, session_battle(state, session), action_context);
	if (state.array_size(defend_objective_messages) != 0) {
		defend_message = join_two(state, defend_message, join_array(state, defend_objective_messages));
	}
	return _complete_enemy_action(state, session, defend_message);
}

DictRef _cast_enemy_spell(State &state, const Value &session, DictRef active_stack, DictRef action) {
	const char *where = "BattleRules._cast_enemy_spell";
	const DictRef target = _get_stack_by_id(state, session_battle(state, session), string_or_empty(state, action, key::target_battle_id));
	const DictRef caster = _hero_caster(state, session_battle(state, session), key::enemy);
	const DictRef raw_enemy_hero = stored_dict_or_new(state, session_battle(state, session), key::enemy_hero);
	const DictRef enemy_hero_state = ai_route::by_side(state, key::enemy, [&] { return battle_ai_rules::_enemy_hero_state_for_ai(state, session_battle(state, session), raw_enemy_hero); });
	DictRef resolved_enemy_hero = ai_route::by_side(state, key::empty, [&] { return battle_ai_rules::_commander_payload_for_tactical_scoring(state, enemy_hero_state); });
	if (gd::is_empty(state, resolved_enemy_hero)) {
		resolved_enemy_hero = raw_enemy_hero;
	}
	_ensure_damage_rng_state(state, session, session_battle(state, session));
	// A move spell's hex comes with the plan that chose it.
	Value destination;
	state.lookup(action, str(key::destination), destination);
	const DictRef resolution = spell_rules::resolve_battle_spell(state, resolved_enemy_hero, session_battle(state, session), active_stack, target, string_or_empty(state, action, key::spell_id), key::enemy, destination);
	if (!gd::bool_field(state, resolution, key::ok, false) || gd::bool_field(state, resolution, key::needs_destination, false)
			|| gd::bool_field(state, resolution, key::needs_second_target, false)) {
		return action_result(state, false, string_or_empty(state, resolution, key::message), key::invalid);
	}
	_commit_spell_resistance_roll(state, session_battle(state, session), resolution);
	_mark_commander_spell_cast(state, session_battle(state, session), key::enemy);
	state.set(session_battle(state, session), str(key::_enemy_commander_spell_cast_in_drain), bool_value(true));

	const Value hero = state.get(resolution, str(key::hero), get_or_new_dict(state, session_battle(state, session), key::enemy_hero));
	state.set(session_battle(state, session), str(key::enemy_hero), hero);
	// The arguments in the GDScript order: the hero state, then the existing payload.
	const DictRef hero_state = gd::as_dict(get_or_new_dict(state, session_battle(state, session), key::enemy_hero));
	const Value existing_payload = get_or_new_dict(state, session_battle(state, session), key::enemy_hero_payload);
	const DictRef enemy_hero_payload = _enemy_hero_payload_from_state(state, hero_state, existing_payload, session);
	state.set(session_battle(state, session), str(key::enemy_hero_payload), dict_value(enemy_hero_payload));
	Atom message = string_or_empty(state, resolution, key::message);
	const DictRef animation_resolution = gd::deep_duplicate_dict(state, resolution);
	state.set(animation_resolution, str(key::spell_id), str(string_or_empty(state, action, key::spell_id)));
	const DictRef target_before = _get_stack_by_id(state, session_battle(state, session), string_or_empty(state, resolution, key::target_battle_id));
	int64_t recovered_amount = 0;
	int64_t cleansed_count = 0;
	if (!_apply_spell_resolution(state, session_battle(state, session), resolution, animation_resolution, message, recovered_amount, cleansed_count)) {
		return action_result(state, false, key::unsupported_spell_resolution_text, key::invalid);
	}
	// Echo: the side's last spell of the battle (spell_tier45_turns.cpp).
	spell_rules::record_last_cast(state, session_battle(state, session), key::enemy, string_or_empty(state, action, key::spell_id), resolution, destination);
	// Prism Array: the side's crystals answer a damage spell (an echo's spell too).
	const Atom fired_id = string_or_empty(state, resolution, key::echo_of) != key::empty ? string_or_empty(state, resolution, key::echo_of) : string_or_empty(state, action, key::spell_id);
	message = concat(state, message, spell_rules::fire_prisms(state, session_battle(state, session), key::enemy, gd::content_row(state, state::ContentTable::Spell, fired_id)));
	Value post_damage_effect;
	if (nonempty_dict_field(state, resolution, key::post_damage_effect, post_damage_effect)) {
		const DictRef effect_target = _get_stack_by_id(state, session_battle(state, session), string_or_empty(state, resolution, key::target_battle_id));
		if (!gd::is_empty(state, effect_target) && _alive_count(state, effect_target) > 0) {
			_apply_stack_effect(state, session_battle(state, session), string_or_empty(state, resolution, key::target_battle_id), post_damage_effect);
			// The Array literal's items, in order.
			const Atom label = _stack_label(state, effect_target);
			const Atom effect_label = to_lower(state, gd::string_field(state, post_damage_effect.ref, key::label, key::affected), where);
			message = concat(state, message, gd::format(state, key::stack_is_suffix_text, { str(label), str(effect_label) }));
		}
	}
	if (string_or_empty(state, resolution, key::resolution_type) == key::damage) {
		const DictRef spell_target_after = _get_stack_by_id(state, session_battle(state, session), string_or_empty(state, resolution, key::target_battle_id));
		const ArrayRef pressure_messages = _apply_damage_pressure(state, session_battle(state, session), caster, target_before, spell_target_after, true, key::spell);
		if (state.array_size(pressure_messages) != 0) {
			message = join_two(state, message, join_array(state, pressure_messages));
		}
	}
	_mark_spell_animation_states(state, session_battle(state, session), caster, animation_resolution);
	const DictRef target_after = _get_stack_by_id(state, session_battle(state, session), string_or_empty(state, resolution, key::target_battle_id));
	_append_spell_presentation_events(state, session_battle(state, session), caster, resolution, target_before, target_after, recovered_amount, cleansed_count, key::cast_spell);
	const DictRef action_context = objective_context(state, key::cast_spell, key::enemy, string_or_empty(state, caster, key::battle_id));
	state.set(action_context, str(key::target_battle_id), str(string_or_empty(state, action, key::target_battle_id)));
	const ArrayRef objective_messages = _apply_field_objective_action_pressure(state, session_battle(state, session), action_context);
	if (state.array_size(objective_messages) != 0) {
		message = join_two(state, message, join_array(state, objective_messages));
	}

	// The cast is the hero's free action: the active stack still gives its order.
	const DictRef outcome = _evaluate_outcome(state, session);
	if (string_or_empty(state, outcome, key::state) != key::empty) {
		const Atom outcome_message = join_two(state, message, string_or_empty(state, outcome, key::message));
		return action_result(state, true, outcome_message, string_or_empty(state, outcome, key::state));
	}
	const DictRef result = action_result(state, true, message, key::continue_);
	state.set(result, str(key::hero_cast), bool_value(true));
	return result;
}

DictRef _resolve_ai_attack(State &state, const Value &session, DictRef attacker, DictRef target, bool is_ranged) {
	if (gd::is_empty(state, target)) {
		return action_result(state, false, key::empty, key::invalid);
	}
	if (is_ranged) {
		if (!_can_make_ranged_attack(state, attacker, session_battle(state, session), target)) {
			return action_result(state, false, key::empty, key::invalid);
		}
	} else if (!_can_make_melee_attack(state, attacker, session_battle(state, session), target)) {
		return action_result(state, false, key::empty, key::invalid);
	}
	// String(x.get("battle_id", "")), read again at every use as GDScript reads it.
	const auto attacker_id = [&]() { return string_or_empty(state, attacker, key::battle_id); };
	const auto target_id = [&]() { return string_or_empty(state, target, key::battle_id); };
	const Atom action_id = is_ranged ? static_cast<Atom>(key::shoot) : static_cast<Atom>(key::strike);
	const Value rng = _damage_rng_for_battle(state, session);
	std::vector<Value> messages;
	// A Confused attacker's blow lands on a stack next to it (Fog Mind).
	const DictRef blow_target = spell_rules::confused_blow_target(state, session_battle(state, session), attacker, target, is_ranged);
	if (string_or_empty(state, blow_target, key::battle_id) != target_id()) {
		messages.push_back(str(gd::format(state, key::confused_hits_text, { str(_stack_label(state, attacker)), str(_stack_label(state, blow_target)) })));
		target = blow_target;
	}
	const int64_t attack_distance = _attack_distance_for_action(state, attacker, target, session_battle(state, session), is_ranged);
	const DictRef target_before = gd::deep_duplicate_dict(state, target);
	// Redline: a melee attack strikes twice while it holds (spell_tier45_turns.cpp).
	const int64_t blows = is_ranged ? 1 : spell_rules::melee_blows(state, session_battle(state, session), attacker);
	for (int64_t blow = 0; blow < blows; ++blow) {
		if (blow > 0) {
			// The second blow: both stacks still stand and the target is still in reach.
			const DictRef attacker_now = _get_stack_by_id(state, session_battle(state, session), attacker_id());
			const DictRef target_now = _get_stack_by_id(state, session_battle(state, session), target_id());
			if (gd::is_empty(state, target_now) || _alive_count(state, target_now) <= 0 || !_can_make_melee_attack(state, attacker_now, session_battle(state, session), target_now)) {
				break;
			}
			attacker = attacker_now;
			target = target_now;
			messages.push_back(str(gd::format(state, key::strikes_again_text, { str(_stack_label(state, attacker)) })));
		}
		const DictRef blow_before = blow == 0 ? target_before : gd::deep_duplicate_dict(state, target);
		const int64_t damage = _calculate_damage(state, attacker, target, session_battle(state, session), rng, is_ranged, false, attack_distance);
		const Atom attack_event = is_ranged ? static_cast<Atom>(key::battle_unit_ranged_attack) : static_cast<Atom>(key::battle_unit_melee_attack);
		_mark_stack_animation_event(state, session_battle(state, session), attacker_id(), attack_event, target_context(state, target_id()));
		// The Array literal's items, in order.
		const Atom attacker_label = _stack_label(state, attacker);
		const Atom verb = is_ranged ? static_cast<Atom>(key::fires_on_text) : static_cast<Atom>(key::batters);
		const Atom attack_text = gd::format(state, key::attack_announce_text, { str(attacker_label), str(verb), str(_stack_label(state, target)) });
		const DictRef attack_context = actor_target_context(state, action_id, attacker_id(), target_id());
		_append_presentation_event(state, session_battle(state, session), action_id, attack_text, attack_context);
		_apply_damage_to_stack(state, session_battle(state, session), target_id(), damage);
		if (is_ranged) {
			_consume_shot(state, session_battle(state, session), attacker_id());
			const Atom shooter_label = _stack_label(state, attacker);
			messages.push_back(str(gd::format(state, key::fires_on_for_damage_text, { str(shooter_label), str(_stack_label(state, target)), int_value(damage) })));
		} else {
			const Atom striker_label = _stack_label(state, attacker);
			messages.push_back(str(gd::format(state, key::batters_for_damage_text, { str(striker_label), str(_stack_label(state, target)), int_value(damage) })));
		}

		DictRef defender_after = _get_stack_by_id(state, session_battle(state, session), target_id());
		const ArrayRef ability_messages = _apply_attack_ability_effects(state, session_battle(state, session), attacker, defender_after, is_ranged, attack_distance, blow_before);
		// The blow's spell extras: thorns, lifesteal, momentum.
		const bool attacker_stood = _alive_count(state, _get_stack_by_id(state, session_battle(state, session), attacker_id())) > 0;
		const int64_t blow_dealt = gd::sub(gd::int_field(state, blow_before, key::total_health, 0), gd::int_field(state, defender_after, key::total_health, 0));
		for (const Value &blow_message : gd::items(state, array_value(spell_rules::after_blow_mechanics(state, session_battle(state, session), attacker_id(), target_id(), is_ranged, blow_dealt)))) {
			state.append(ability_messages, blow_message);
		}
		const bool attacker_fell_to_spells = attacker_stood && _alive_count(state, _get_stack_by_id(state, session_battle(state, session), attacker_id())) <= 0;
		for (int64_t index = 0; index < state.array_size(ability_messages); ++index) {
			messages.push_back(state.at(ability_messages, index));
		}
		defender_after = _get_stack_by_id(state, session_battle(state, session), target_id());
		_append_damage_presentation_event(state, session_battle(state, session), key::damage, attacker, blow_before, defender_after, damage, action_id, state.new_dict());
		_append_text_presentation_event(state, session_battle(state, session), key::ability, ability_messages, attacker, defender_after, action_id);
		const ArrayRef damage_pressure_messages = _apply_damage_pressure(state, session_battle(state, session), attacker, blow_before, defender_after, is_ranged, key::attack);
		for (int64_t index = 0; index < state.array_size(damage_pressure_messages); ++index) {
			messages.push_back(state.at(damage_pressure_messages, index));
		}
		_append_text_presentation_event(state, session_battle(state, session), key::morale, damage_pressure_messages, attacker, defender_after, action_id);
		_mark_damage_target_animation(state, session_battle(state, session), target_id(), state.array_size(ability_messages) != 0, attacker_id(), state.new_dict(), blow_before);
		const ArrayRef ranged_return_messages = _apply_ranged_damage_return(state, session_battle(state, session), attacker_id(), blow_before, is_ranged, key::attack);
		for (int64_t index = 0; index < state.array_size(ranged_return_messages); ++index) {
			messages.push_back(state.at(ranged_return_messages, index));
		}
		if (!is_ranged
				&& !gd::is_empty(state, defender_after)
				&& _alive_count(state, defender_after) > 0
				&& gd::int_field(state, defender_after, key::retaliations_left, 0) > 0
				&& !attacker_fell_to_spells
				&& string_or_empty(state, defender_after, key::side) != string_or_empty(state, attacker, key::side)
				&& _can_make_retaliation(state, defender_after, attack_distance, session_battle(state, session))) {
			const auto defender_id = [&]() { return string_or_empty(state, defender_after, key::battle_id); };
			const DictRef attacker_after = _get_stack_by_id(state, session_battle(state, session), attacker_id());
			const DictRef attacker_before_retaliation = gd::deep_duplicate_dict(state, attacker_after);
			const int64_t retaliation_damage = _calculate_damage(state, defender_after, attacker_after, session_battle(state, session), rng, false, true, attack_distance);
			_consume_retaliation(state, session_battle(state, session), defender_id());
			// Match the player path: the retaliation snapshot precedes its damage.
			_mark_stack_animation_event(state, session_battle(state, session), defender_id(), key::battle_retaliation, target_context(state, attacker_id()));
			_apply_damage_to_stack(state, session_battle(state, session), attacker_id(), retaliation_damage);
			const Atom retaliator_label = _stack_label(state, defender_after);
			const Atom retaliation_text = gd::format(state, key::retaliates_against_text, { str(retaliator_label), str(_stack_label(state, attacker_after)) });
			const DictRef retaliation_context = actor_target_context(state, key::retaliation, defender_id(), string_or_empty(state, attacker_after, key::battle_id));
			_append_presentation_event(state, session_battle(state, session), key::retaliation, retaliation_text, retaliation_context);
			messages.push_back(str(gd::format(state, key::retaliates_for_damage_text, { str(_stack_label(state, defender_after)), int_value(retaliation_damage) })));
			DictRef attacker_after_retaliation = _get_stack_by_id(state, session_battle(state, session), attacker_id());
			const ArrayRef retaliation_ability_messages = _apply_retaliation_ability_effects(state, session_battle(state, session), defender_after, attacker_after_retaliation);
			const int64_t retaliation_dealt = gd::sub(gd::int_field(state, attacker_before_retaliation, key::total_health, 0), gd::int_field(state, attacker_after_retaliation, key::total_health, 0));
			for (const Value &blow_message : gd::items(state, array_value(spell_rules::after_blow_mechanics(state, session_battle(state, session), defender_id(), attacker_id(), false, retaliation_dealt)))) {
				state.append(retaliation_ability_messages, blow_message);
			}
			for (int64_t index = 0; index < state.array_size(retaliation_ability_messages); ++index) {
				messages.push_back(state.at(retaliation_ability_messages, index));
			}
			attacker_after_retaliation = _get_stack_by_id(state, session_battle(state, session), attacker_id());
			_append_damage_presentation_event(state, session_battle(state, session), key::damage, defender_after, attacker_before_retaliation, attacker_after_retaliation, retaliation_damage, key::retaliation, state.new_dict());
			_append_text_presentation_event(state, session_battle(state, session), key::ability, retaliation_ability_messages, defender_after, attacker_after_retaliation, key::retaliation);
			const ArrayRef retaliation_pressure_messages = _apply_damage_pressure(state, session_battle(state, session), defender_after, attacker_before_retaliation, attacker_after_retaliation, false, key::retaliation);
			for (int64_t index = 0; index < state.array_size(retaliation_pressure_messages); ++index) {
				messages.push_back(state.at(retaliation_pressure_messages, index));
			}
			_append_text_presentation_event(state, session_battle(state, session), key::morale, retaliation_pressure_messages, defender_after, attacker_after_retaliation, key::retaliation);
			_mark_damage_target_animation(state, session_battle(state, session), attacker_id(), state.array_size(retaliation_ability_messages) != 0, defender_id(), state.new_dict(), attacker_before_retaliation);
		}
		if (blows > 1 && blow == 0) {
			spell_rules::spend_double_strike(state, session_battle(state, session), attacker_id());
		}
	}
	const DictRef action_context = objective_context(state, action_id, string_or_empty(state, attacker, key::side), attacker_id());
	state.set(action_context, str(key::target_battle_id), str(target_id()));
	const ArrayRef objective_messages = _apply_field_objective_action_pressure(state, session_battle(state, session), action_context);
	if (state.array_size(objective_messages) != 0) {
		messages.push_back(str(join_array(state, objective_messages)));
	}

	return _complete_enemy_action(state, session, join_values(state, messages));
}

DictRef _drain_enemy_turns(State &state, const Value &session) {
	if (session.kind == Kind::Nil || gd::is_empty(state, session_battle(state, session))) {
		const DictRef result = state.new_dict();
		state.set(result, str(key::state), str(key::invalid));
		state.set(result, str(key::message), str(key::empty));
		return result;
	}

	std::vector<Atom> messages;
	state.set(session_battle(state, session), str(key::_enemy_commander_spell_cast_in_drain), bool_value(false));
	while (true) {
		const DictRef active_stack = get_active_stack(state, session_battle(state, session));
		if (gd::is_empty(state, active_stack)) {
			const DictRef outcome = _evaluate_outcome(state, session);
			if (string_or_empty(state, outcome, key::state) != key::empty) {
				state.erase(session_battle(state, session), str(key::_enemy_commander_spell_cast_in_drain));
				return outcome;
			}
			break;
		}
		if (string_or_empty(state, active_stack, key::side) != key::enemy) {
			break;
		}
		DictRef enemy_result = _run_enemy_turn(state, session, active_stack);
		if (gd::string_field(state, enemy_result, key::state, key::continue_) == key::invalid) {
			// An enemy stack that cannot act would keep the turn and lock player
			// input. Brace it instead so initiative moves on.
			const DictRef stuck_stack = get_active_stack(state, session_battle(state, session));
			if (string_or_empty(state, stuck_stack, key::battle_id) == string_or_empty(state, active_stack, key::battle_id)
					&& string_or_empty(state, stuck_stack, key::side) == key::enemy) {
				const Atom invalid_message = string_or_empty(state, enemy_result, key::message);
				enemy_result = _resolve_enemy_defend(state, session, stuck_stack);
				state.set(enemy_result, str(key::message), str(join_two(state, invalid_message, string_or_empty(state, enemy_result, key::message))));
			} else {
				state.set(enemy_result, str(key::state), str(key::continue_));
			}
		}
		const Atom enemy_message = string_or_empty(state, enemy_result, key::message);
		if (enemy_message != key::empty) {
			_record_event(state, session_battle(state, session), enemy_message);
			messages.push_back(enemy_message);
		}
		const Atom enemy_state = gd::string_field(state, enemy_result, key::state, key::continue_);
		if (enemy_state != key::empty && enemy_state != key::continue_ && enemy_state != key::invalid) {
			state.erase(session_battle(state, session), str(key::_enemy_commander_spell_cast_in_drain));
			const DictRef terminal_result = gd::deep_duplicate_dict(state, enemy_result);
			state.set(terminal_result, str(key::state), str(enemy_state));
			state.set(terminal_result, str(key::message), str(join_atoms(state, messages)));
			return terminal_result;
		}
	}

	state.erase(session_battle(state, session), str(key::_enemy_commander_spell_cast_in_drain));
	const DictRef result = state.new_dict();
	state.set(result, str(key::state), str(key::continue_));
	state.set(result, str(key::message), str(join_atoms(state, messages)));
	return result;
}

DictRef _complete_enemy_action(State &state, const Value &session, Atom message) {
	DictRef outcome = _evaluate_outcome(state, session);
	if (string_or_empty(state, outcome, key::state) != key::empty) {
		const Atom outcome_message = join_two(state, message, string_or_empty(state, outcome, key::message));
		return action_result(state, true, outcome_message, string_or_empty(state, outcome, key::state));
	}
	advance_turn(state, session_battle(state, session));
	outcome = _evaluate_outcome(state, session);
	if (string_or_empty(state, outcome, key::state) != key::empty) {
		const Atom outcome_message = join_two(state, message, string_or_empty(state, outcome, key::message));
		return action_result(state, true, outcome_message, string_or_empty(state, outcome, key::state));
	}
	return action_result(state, true, message, key::continue_);
}

DictRef _resolve_enemy_wait(State &state, const Value &session, DictRef active_stack) {
	if (!can_wait(state, session_battle(state, session))) {
		return _resolve_enemy_defend(state, session, active_stack);
	}
	const Atom message = _resolve_wait(state, session_battle(state, session), active_stack);
	return action_result(state, true, message, key::continue_);
}

void _mark_side_animation_event(State &state, DictRef battle, Atom side, Atom event_id) {
	// The stacks as the loop starts: the body only marks animation states, so the list stays as it is.
	const state::ValueList stacks = gd::field_items(state, battle, str(key::stacks)).list();
	for (const Value &stack : stacks) {
		if (!gd::is_dict(stack)) {
			continue;
		}
		if (string_or_empty(state, stack.ref, key::side) != side || _alive_count(state, stack.ref) <= 0) {
			continue;
		}
		_mark_stack_animation_event(state, battle, string_or_empty(state, stack.ref, key::battle_id), event_id, state.new_dict());
	}
}

} // namespace aurelion::rules::port::battle_rules
