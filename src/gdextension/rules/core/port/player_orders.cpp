// Slice 10: the player's orders: an advance, a strike or shot, a defend, a wait, a retreat or surrender and the hero's
// cast; the attack they resolve, the completion of an action and the battle's outcome.

#include "aurelion_rules/port/battle_rules.hpp"

#include "aurelion_rules/port/artifact_rules.hpp"

#include <initializer_list>
#include <string>

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

// session.battle: SessionData.battle is a typed Dictionary, read again at every
// use as GDScript reads it (a host call ends the battle with a new one).
DictRef session_battle(State &state, const Value &session) {
	return gd::as_dict(gd::member(state, session, key::battle));
}

// session == null or session.battle.is_empty()
bool no_battle(State &state, const Value &session) {
	return session.kind == Kind::Nil || gd::is_empty(state, session_battle(state, session));
}

// d.get(key, {}) and d.get(key, []) of an untyped value: a new container when
// the key is missing.
Value get_or_new_dict(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return dict_value(state.new_dict());
}

Value get_or_new_array(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return array_value(state.new_array());
}

// effect is Dictionary and not effect.is_empty() of d.get(field, {}): a missing
// key's new {} is empty.
bool nonempty_dict_field(State &state, DictRef dict, Atom field, Value &out) {
	return state.lookup(dict, str(field), out) && gd::is_dict(out) && !gd::is_empty(state, out.ref);
}

// {"ok": false, "message": message, "state": "invalid"}
DictRef refusal(State &state, Atom message) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(false));
	state.set(result, str(key::message), str(message));
	state.set(result, str(key::state), str(key::invalid));
	return result;
}

// {"ok": true, "message": message, "state": result_state}
DictRef accepted(State &state, Atom message, Atom result_state) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(true));
	state.set(result, str(key::message), str(message));
	state.set(result, str(key::state), str(result_state));
	return result;
}

// {"state": result_state, "message": message}
DictRef state_and_message(State &state, Atom result_state, Atom message) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::state), str(result_state));
	state.set(result, str(key::message), str(message));
	return result;
}

// [a, b, ...] of Strings: a new Array.
ArrayRef string_array(State &state, std::initializer_list<Atom> atoms) {
	const ArrayRef array = state.new_array();
	for (const Atom atom : atoms) {
		state.append(array, str(atom));
	}
	return array;
}

// a + b of Strings.
Atom concat(State &state, Atom a, Atom b) {
	std::string joined = state.text(a);
	joined += state.text(b);
	return state.intern(joined);
}

// " ".join(parts) of an Array: String.join takes it as a PackedStringArray,
// String(item) of every item, empty ones included.
Atom join_with_space(State &state, ArrayRef parts) {
	std::string joined;
	const int64_t size = state.array_size(parts);
	for (int64_t index = 0; index < size; ++index) {
		if (index > 0) {
			joined += ' ';
		}
		const Atom part = gd::stringify(state, state.at(parts, index));
		joined += state.text(part);
	}
	return state.intern(joined);
}

// a.append_array(b) of an untyped Array: b's items as they were.
void append_all(State &state, ArrayRef array, ArrayRef other) {
	const int64_t size = state.array_size(other);
	for (int64_t index = 0; index < size; ++index) {
		state.append(array, state.at(other, index));
	}
}

// {"action_id": action_id, "actor_battle_id": actor_battle_id}
DictRef action_context(State &state, Atom action_id, Atom actor_battle_id) {
	const DictRef context = state.new_dict();
	state.set(context, str(key::action_id), str(action_id));
	state.set(context, str(key::actor_battle_id), str(actor_battle_id));
	return context;
}

// {"action": action, "side": side, "battle_id": battle_id}
DictRef objective_action(State &state, Atom action, Atom side, Atom battle_id) {
	const DictRef context = state.new_dict();
	state.set(context, str(key::action), str(action));
	state.set(context, str(key::side), str(side));
	state.set(context, str(key::battle_id), str(battle_id));
	return context;
}

// s.to_lower() of ASCII text (the Unicode case tables are not ported).
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

// BattleRules.<function>(session) of the functions that stay GDScript in
// Phase 1 (they change the overworld): a host call.
DictRef host_dict(State &state, Atom function, const Value &session) {
	return gd::as_dict(gd::call_static(state, key::battle_rules_script, function, { session }));
}

Atom host_string(State &state, Atom function, const Value &session) {
	return gd::to_string(gd::call_static(state, key::battle_rules_script, function, { session }));
}

} // namespace

DictRef resolve_if_battle_ready(State &state, const Value &session) {
	if (no_battle(state, session)) {
		return state_and_message(state, key::invalid, key::empty);
	}
	const DictRef outcome = _evaluate_outcome(state, session);
	if (string_or_empty(state, outcome, key::state) != key::empty) {
		return outcome;
	}
	return _drain_enemy_turns(state, session);
}

DictRef cast_player_spell(State &state, const Value &session, Atom spell_id, Atom target_id) {
	if (no_battle(state, session)) {
		return refusal(state, key::no_battle_is_active_text);
	}

	const DictRef active_stack = get_active_stack(state, session_battle(state, session));
	if (gd::is_empty(state, active_stack) || string_or_empty(state, active_stack, key::side) != key::player) {
		return refusal(state, key::not_the_players_turn_text);
	}
	if (_commander_spell_cast_this_round(state, session_battle(state, session), key::player)) {
		return refusal(state, key::commander_already_cast_text);
	}
	const DictRef caster = _hero_caster(state, session_battle(state, session), key::player);
	_ensure_damage_rng_state(state, session, session_battle(state, session));
	const DictRef resolution = _player_spell_resolution(state, session, spell_id, target_id);
	if (!gd::bool_field(state, resolution, key::ok, false)) {
		return refusal(state, gd::string_field(state, resolution, key::message, key::spell_casting_failed_text));
	}
	_commit_spell_resistance_roll(state, session_battle(state, session), resolution);
	_clear_stack_animation_states(state, session_battle(state, session));
	_clear_selected_target_continuity(state, session_battle(state, session));
	_clear_selected_target_closing(state, session_battle(state, session));
	_mark_commander_spell_cast(state, session_battle(state, session), key::player);

	// The assignments read session.battle, then the value.
	const DictRef commander_battle = session_battle(state, session);
	const Value commander_state = state.get(resolution, str(key::hero), dict_value(_player_commander_state(state, session)));
	state.set(commander_battle, str(key::player_commander_state), commander_state);
	const DictRef payload_battle = session_battle(state, session);
	const DictRef hero_state = _player_commander_state(state, session);
	const DictRef bonuses = artifact_rules::aggregate_bonuses(state, _player_commander_state(state, session));
	const DictRef hero_payload = _hero_payload_from_state(state, hero_state, bonuses, session, key::player);
	state.set(payload_battle, str(key::player_hero), dict_value(hero_payload));
	Atom message = string_or_empty(state, resolution, key::message);
	const DictRef animation_resolution = gd::deep_duplicate_dict(state, resolution);
	state.set(animation_resolution, str(key::spell_id), str(spell_id));
	// The stack itself, not a copy: it takes the cast below.
	const DictRef target_before = _get_stack_by_id(state, session_battle(state, session), string_or_empty(state, resolution, key::target_battle_id));
	int64_t recovered_amount = 0;
	int64_t cleansed_count = 0;
	const Atom resolution_type = string_or_empty(state, resolution, key::resolution_type);
	if (resolution_type == key::damage) {
		const Atom target_battle_id = string_or_empty(state, resolution, key::target_battle_id);
		const DictRef before_copy = gd::duplicate_dict(state, _get_stack_by_id(state, session_battle(state, session), target_battle_id));
		state.set(animation_resolution, str(key::playback_target_before), dict_value(before_copy));
		_apply_damage_to_stack(state, session_battle(state, session), target_battle_id, gd::int_field(state, resolution, key::damage, 0));
		const DictRef target_after = _get_stack_by_id(state, session_battle(state, session), target_battle_id);
		if (!gd::is_empty(state, target_after) && _alive_count(state, target_after) <= 0) {
			message = concat(state, message, gd::format(state, key::stack_destroyed_suffix_text, { str(_stack_label(state, target_after)) }));
		}
	} else if (resolution_type == key::effect) {
		Value effect_payload;
		if (nonempty_dict_field(state, resolution, key::effect, effect_payload)) {
			_apply_stack_effect(state, session_battle(state, session), string_or_empty(state, resolution, key::target_battle_id), effect_payload);
		}
	} else if (resolution_type == key::recover_effect) {
		const int64_t recovered = _restore_stack_health(state, session_battle(state, session), string_or_empty(state, resolution, key::target_battle_id), gd::int_field(state, resolution, key::recovery_amount, 0));
		recovered_amount = recovered;
		if (recovered > 0) {
			const Atom label = _stack_label(state, _get_stack_by_id(state, session_battle(state, session), string_or_empty(state, resolution, key::target_battle_id)));
			message = concat(state, message, gd::format(state, key::recovers_health_suffix_text, { str(label), int_value(recovered) }));
		}
		Value recovery_effect;
		if (nonempty_dict_field(state, resolution, key::effect, recovery_effect)) {
			_apply_stack_effect(state, session_battle(state, session), string_or_empty(state, resolution, key::target_battle_id), recovery_effect);
		}
	} else if (resolution_type == key::cleanse_effect) {
		const DictRef cleanse_battle = session_battle(state, session);
		const Atom cleanse_target_id = string_or_empty(state, resolution, key::target_battle_id);
		const int64_t cleansed = _cleanse_stack_effects(state, cleanse_battle, cleanse_target_id, get_or_new_array(state, resolution, key::cleanse_effect_ids));
		cleansed_count = cleansed;
		state.set(animation_resolution, str(key::cleansed_effect_count), int_value(cleansed));
		if (cleansed > 0) {
			const Atom label = _stack_label(state, _get_stack_by_id(state, session_battle(state, session), string_or_empty(state, resolution, key::target_battle_id)));
			const Atom plural = cleansed == 1 ? static_cast<Atom>(key::empty) : static_cast<Atom>(key::s);
			message = concat(state, message, gd::format(state, key::sheds_pressure_suffix_text, { str(label), int_value(cleansed), str(plural) }));
		}
		Value cleanse_effect;
		if (nonempty_dict_field(state, resolution, key::effect, cleanse_effect)) {
			_apply_stack_effect(state, session_battle(state, session), string_or_empty(state, resolution, key::target_battle_id), cleanse_effect);
		}
	} else {
		return refusal(state, key::unsupported_spell_resolution_text);
	}
	Value post_damage_effect;
	if (nonempty_dict_field(state, resolution, key::post_damage_effect, post_damage_effect)) {
		const DictRef effect_target = _get_stack_by_id(state, session_battle(state, session), string_or_empty(state, resolution, key::target_battle_id));
		if (!gd::is_empty(state, effect_target) && _alive_count(state, effect_target) > 0) {
			_apply_stack_effect(state, session_battle(state, session), string_or_empty(state, resolution, key::target_battle_id), post_damage_effect);
			const Atom label = _stack_label(state, effect_target);
			const Atom effect_label = to_lower(state, gd::string_field(state, post_damage_effect.ref, key::label, key::affected), "BattleRules.cast_player_spell");
			message = concat(state, message, gd::format(state, key::stack_is_suffix_text, { str(label), str(effect_label) }));
		}
	}
	if (string_or_empty(state, resolution, key::resolution_type) == key::damage) {
		const DictRef spell_target_after = _get_stack_by_id(state, session_battle(state, session), string_or_empty(state, resolution, key::target_battle_id));
		const ArrayRef pressure_messages = _apply_damage_pressure(state, session_battle(state, session), caster, target_before, spell_target_after, true, key::spell);
		if (state.array_size(pressure_messages) != 0) {
			message = _join_messages(state, string_array(state, { message, join_with_space(state, pressure_messages) }));
		}
	}
	_mark_spell_animation_states(state, session_battle(state, session), caster, animation_resolution);
	const DictRef events_battle = session_battle(state, session);
	const DictRef target_after_cast = _get_stack_by_id(state, session_battle(state, session), string_or_empty(state, resolution, key::target_battle_id));
	_append_spell_presentation_events(state, events_battle, caster, resolution, target_before, target_after_cast, recovered_amount, cleansed_count, key::cast_spell);
	const DictRef objective_battle = session_battle(state, session);
	const DictRef objective_context = objective_action(state, key::cast_spell, key::player, string_or_empty(state, caster, key::battle_id));
	state.set(objective_context, str(key::target_battle_id), str(string_or_empty(state, resolution, key::target_battle_id)));
	const ArrayRef objective_messages = _apply_field_objective_action_pressure(state, objective_battle, objective_context);
	if (state.array_size(objective_messages) != 0) {
		message = _join_messages(state, string_array(state, { message, join_with_space(state, objective_messages) }));
	}

	// The cast is the hero's free action: the active stack keeps its turn.
	const DictRef result = _complete_action(state, session, message, false);
	state.set(result, str(key::hero_cast), bool_value(true));
	return result;
}

DictRef perform_player_action(State &state, const Value &session, Atom action, DictRef approach) {
	if (no_battle(state, session)) {
		return refusal(state, key::no_battle_is_active_text);
	}

	DictRef active_stack = get_active_stack(state, session_battle(state, session));
	if (gd::is_empty(state, active_stack) || string_or_empty(state, active_stack, key::side) != key::player) {
		return refusal(state, key::not_the_players_turn_text);
	}

	if (action == key::advance) {
		if (_stack_is_rooted(state, active_stack, session_battle(state, session))) {
			return refusal(state, gd::format(state, key::rooted_cannot_move_text, { str(_stack_label(state, active_stack)) }));
		}
		if (!_advance_stalled_by_obstruction(state, active_stack, session_battle(state, session)) && state.array_size(legal_destinations_for_active_stack(state, session_battle(state, session))) == 0) {
			return refusal(state, gd::format(state, key::no_open_hex_text, { str(_stack_label(state, active_stack)) }));
		}
		_clear_stack_animation_states(state, session_battle(state, session));
		_clear_selected_target_continuity(state, session_battle(state, session));
		_clear_selected_target_closing(state, session_battle(state, session));
		_mark_stack_animation_event(state, session_battle(state, session), string_or_empty(state, active_stack, key::battle_id), key::battle_unit_move, state.new_dict());
		const bool stalled = _advance_stalled_by_obstruction(state, active_stack, session_battle(state, session));
		_apply_auto_advance_movement(state, session_battle(state, session), active_stack);
		const DictRef move_battle = session_battle(state, session);
		const Atom move_text = gd::format(state, key::stack_advances_text, { str(_stack_label(state, active_stack)) });
		const DictRef move_context = action_context(state, key::advance, string_or_empty(state, active_stack, key::battle_id));
		_append_presentation_event(state, move_battle, key::move_, move_text, move_context);
		Atom advance_message = gd::format(state, key::stack_advances_text, { str(_stack_label(state, active_stack)) });
		const Atom advance_pressure = _apply_advance_pressure(state, session_battle(state, session), string_or_empty(state, active_stack, key::battle_id));
		if (advance_pressure != key::empty) {
			advance_message = concat(state, advance_message, gd::format(state, key::space_s_text, { str(advance_pressure) }));
			_append_text_presentation_event(state, session_battle(state, session), key::momentum, string_array(state, { advance_pressure }), active_stack, state.new_dict(), key::advance);
		}
		if (stalled) {
			advance_message = _join_messages(state, string_array(state, { advance_message, key::obstruction_holds_push_text }));
		}
		const DictRef advance_battle = session_battle(state, session);
		const DictRef advance_context = objective_action(state, key::advance, key::player, string_or_empty(state, active_stack, key::battle_id));
		const ArrayRef advance_objective_messages = _apply_field_objective_action_pressure(state, advance_battle, advance_context);
		if (state.array_size(advance_objective_messages) != 0) {
			advance_message = _join_messages(state, string_array(state, { advance_message, join_with_space(state, advance_objective_messages) }));
		}
		return _complete_action(state, session, advance_message, true);
	}
	if (action == key::strike) {
		const DictRef strike_target = get_selected_target(state, session_battle(state, session));
		// var strike_from := {}: assigned on both paths before it is read.
		DictRef strike_from = 0;
		if (!gd::is_empty(state, approach)) {
			if (gd::is_empty(state, strike_target)) {
				return refusal(state, key::no_target_selected_text);
			}
			strike_from = _matching_melee_approach(state, session_battle(state, session), active_stack, strike_target, approach);
			if (gd::is_empty(state, strike_from)) {
				const Atom message = gd::format(state, key::cannot_strike_from_text, { str(_stack_label(state, active_stack)), str(_stack_label(state, strike_target)), str(_hex_label(state, approach)) });
				return refusal(state, message);
			}
		} else {
			strike_from = melee_approach_destination(state, session_battle(state, session), active_stack, strike_target);
			if (!_can_make_melee_attack(state, active_stack, session_battle(state, session), strike_target) && gd::is_empty(state, strike_from)) {
				return refusal(state, key::cannot_reach_enemy_line_text);
			}
		}
		_clear_stack_animation_states(state, session_battle(state, session));
		_clear_selected_target_continuity(state, session_battle(state, session));
		_clear_selected_target_closing(state, session_battle(state, session));
		if (gd::int_field(state, strike_from, key::steps, 0) > 0) {
			_apply_melee_approach(state, session_battle(state, session), active_stack, strike_from);
			active_stack = _get_stack_by_id(state, session_battle(state, session), string_or_empty(state, active_stack, key::battle_id));
		}
		return _resolve_attack_action(state, session, active_stack, strike_target, false);
	}
	if (action == key::shoot) {
		const DictRef shoot_target = get_selected_target(state, session_battle(state, session));
		if (!_can_make_ranged_attack(state, active_stack, session_battle(state, session), shoot_target)) {
			return refusal(state, key::cannot_ranged_attack_target_text);
		}
		_clear_stack_animation_states(state, session_battle(state, session));
		_clear_selected_target_continuity(state, session_battle(state, session));
		_clear_selected_target_closing(state, session_battle(state, session));
		return _resolve_attack_action(state, session, active_stack, shoot_target, true);
	}
	if (action == key::defend) {
		_clear_stack_animation_states(state, session_battle(state, session));
		_clear_selected_target_continuity(state, session_battle(state, session));
		_clear_selected_target_closing(state, session_battle(state, session));
		_set_stack_defending(state, session_battle(state, session), string_or_empty(state, active_stack, key::battle_id));
		_mark_stack_animation_event(state, session_battle(state, session), string_or_empty(state, active_stack, key::battle_id), key::battle_unit_defend, state.new_dict());
		const DictRef buff_battle = session_battle(state, session);
		const Atom buff_text = gd::format(state, key::braces_for_impact_text, { str(_stack_label(state, active_stack)) });
		const DictRef buff_context = action_context(state, key::defend, string_or_empty(state, active_stack, key::battle_id));
		_append_presentation_event(state, buff_battle, key::buff, buff_text, buff_context);
		Atom defend_message = gd::format(state, key::braces_for_impact_text, { str(_stack_label(state, active_stack)) });
		const Atom defend_pressure = _apply_defend_pressure(state, session_battle(state, session), string_or_empty(state, active_stack, key::battle_id));
		if (defend_pressure != key::empty) {
			defend_message = concat(state, defend_message, gd::format(state, key::space_s_text, { str(defend_pressure) }));
			_append_text_presentation_event(state, session_battle(state, session), key::morale, string_array(state, { defend_pressure }), active_stack, state.new_dict(), key::defend);
		}
		const DictRef defend_battle = session_battle(state, session);
		const DictRef defend_context = objective_action(state, key::defend, key::player, string_or_empty(state, active_stack, key::battle_id));
		const ArrayRef defend_objective_messages = _apply_field_objective_action_pressure(state, defend_battle, defend_context);
		if (state.array_size(defend_objective_messages) != 0) {
			defend_message = _join_messages(state, string_array(state, { defend_message, join_with_space(state, defend_objective_messages) }));
		}
		return _complete_action(state, session, defend_message, true);
	}
	if (action == key::wait) {
		if (!can_wait(state, session_battle(state, session))) {
			return refusal(state, gd::format(state, key::already_waited_text, { str(_stack_label(state, active_stack)) }));
		}
		_clear_stack_animation_states(state, session_battle(state, session));
		_clear_selected_target_continuity(state, session_battle(state, session));
		_clear_selected_target_closing(state, session_battle(state, session));
		const Atom wait_message = _resolve_wait(state, session_battle(state, session), active_stack);
		return _complete_action(state, session, wait_message, false);
	}
	if (action == key::retreat) {
		if (_is_town_defense_context(state, get_or_new_dict(state, session_battle(state, session), key::context))) {
			return refusal(state, key::town_defenders_cannot_retreat_text);
		}
		if (!_battle_retreat_allowed(state, session_battle(state, session))) {
			return refusal(state, host_string(state, key::_retreat_action_summary, session));
		}
		_clear_stack_animation_states(state, session_battle(state, session));
		_mark_side_animation_event(state, session_battle(state, session), key::player, key::battle_unit_retreat);
		_clear_selected_target_continuity(state, session_battle(state, session));
		_clear_selected_target_closing(state, session_battle(state, session));
		return host_dict(state, key::_finalize_retreat, session);
	}
	if (action == key::surrender) {
		if (_is_town_defense_context(state, get_or_new_dict(state, session_battle(state, session), key::context))) {
			return refusal(state, key::town_defenders_cannot_surrender_text);
		}
		if (!_battle_surrender_allowed(state, session_battle(state, session))) {
			return refusal(state, host_string(state, key::_surrender_action_summary, session));
		}
		_clear_stack_animation_states(state, session_battle(state, session));
		_mark_side_animation_event(state, session_battle(state, session), key::player, key::battle_unit_surrender);
		_clear_selected_target_continuity(state, session_battle(state, session));
		_clear_selected_target_closing(state, session_battle(state, session));
		return host_dict(state, key::_finalize_surrender, session);
	}
	return refusal(state, key::unknown_action_text);
}

DictRef _resolve_attack_action(State &state, const Value &session, DictRef attacker, DictRef target, bool is_ranged) {
	if (gd::is_empty(state, target)) {
		return refusal(state, key::no_target_selected_text);
	}
	if (is_ranged) {
		if (!_can_make_ranged_attack(state, attacker, session_battle(state, session), target)) {
			return refusal(state, key::cannot_ranged_attack_target_text);
		}
	} else if (!_can_make_melee_attack(state, attacker, session_battle(state, session), target)) {
		return refusal(state, key::cannot_reach_target_text);
	}

	const Value rng = _damage_rng_for_battle(state, session);

	// var action_id := "shoot" if is_ranged else "strike", which every use before
	// it spells out.
	const Atom action_id = is_ranged ? static_cast<Atom>(key::shoot) : static_cast<Atom>(key::strike);
	const ArrayRef messages = state.new_array();
	const int64_t attack_distance = _attack_distance_for_action(state, attacker, target, session_battle(state, session), is_ranged);
	const DictRef target_before = gd::deep_duplicate_dict(state, target);
	const int64_t damage = _calculate_damage(state, attacker, target, session_battle(state, session), rng, is_ranged, false, attack_distance);
	{
		const DictRef battle = session_battle(state, session);
		const Atom attacker_id = string_or_empty(state, attacker, key::battle_id);
		const Atom event_id = is_ranged ? static_cast<Atom>(key::battle_unit_ranged_attack) : static_cast<Atom>(key::battle_unit_melee_attack);
		const DictRef context = state.new_dict();
		state.set(context, str(key::target_battle_id), str(string_or_empty(state, target, key::battle_id)));
		_mark_stack_animation_event(state, battle, attacker_id, event_id, context);
	}
	{
		const DictRef battle = session_battle(state, session);
		const Atom verb = is_ranged ? static_cast<Atom>(key::shoots) : static_cast<Atom>(key::strikes);
		const Atom text = gd::format(state, key::attack_announce_text, { str(_stack_label(state, attacker)), str(verb), str(_stack_label(state, target)) });
		const DictRef context = action_context(state, action_id, string_or_empty(state, attacker, key::battle_id));
		state.set(context, str(key::target_battle_id), str(string_or_empty(state, target, key::battle_id)));
		_append_presentation_event(state, battle, action_id, text, context);
	}
	_apply_damage_to_stack(state, session_battle(state, session), string_or_empty(state, target, key::battle_id), damage);
	if (is_ranged) {
		_consume_shot(state, session_battle(state, session), string_or_empty(state, attacker, key::battle_id));
		state.append(messages, str(gd::format(state, key::shoots_for_damage_text, { str(_stack_label(state, attacker)), str(_stack_label(state, target)), int_value(damage) })));
	} else {
		state.append(messages, str(gd::format(state, key::strikes_for_damage_text, { str(_stack_label(state, attacker)), str(_stack_label(state, target)), int_value(damage) })));
	}

	bool retaliated = false;
	DictRef defender_after = _get_stack_by_id(state, session_battle(state, session), string_or_empty(state, target, key::battle_id));
	const ArrayRef ability_messages = _apply_attack_ability_effects(state, session_battle(state, session), attacker, defender_after, is_ranged, attack_distance, target_before);
	append_all(state, messages, ability_messages);
	defender_after = _get_stack_by_id(state, session_battle(state, session), string_or_empty(state, target, key::battle_id));
	_append_damage_presentation_event(state, session_battle(state, session), key::damage, attacker, target_before, defender_after, damage, action_id, state.new_dict());
	_append_text_presentation_event(state, session_battle(state, session), key::ability, ability_messages, attacker, defender_after, action_id);
	const ArrayRef damage_pressure_messages = _apply_damage_pressure(state, session_battle(state, session), attacker, target_before, defender_after, is_ranged, key::attack);
	append_all(state, messages, damage_pressure_messages);
	_append_text_presentation_event(state, session_battle(state, session), key::morale, damage_pressure_messages, attacker, defender_after, action_id);
	_mark_damage_target_animation(state, session_battle(state, session), string_or_empty(state, target, key::battle_id), state.array_size(ability_messages) != 0, string_or_empty(state, attacker, key::battle_id), state.new_dict(), target_before);
	const ArrayRef ranged_return_messages = _apply_ranged_damage_return(state, session_battle(state, session), string_or_empty(state, attacker, key::battle_id), target_before, is_ranged, key::attack);
	append_all(state, messages, ranged_return_messages);
	if (!is_ranged
			&& !gd::is_empty(state, defender_after)
			&& _alive_count(state, defender_after) > 0
			&& gd::int_field(state, defender_after, key::retaliations_left, 0) > 0
			&& _can_make_retaliation(state, defender_after, attack_distance, session_battle(state, session))) {
		const DictRef attacker_after = _get_stack_by_id(state, session_battle(state, session), string_or_empty(state, attacker, key::battle_id));
		const DictRef attacker_before_retaliation = gd::deep_duplicate_dict(state, attacker_after);
		const int64_t retaliation_damage = _calculate_damage(state, defender_after, attacker_after, session_battle(state, session), rng, false, true, attack_distance);
		_consume_retaliation(state, session_battle(state, session), string_or_empty(state, defender_after, key::battle_id));
		// Capture the windup with its target still alive. Applying damage first
		// exposes a corpse before the following hit/death playback snapshot.
		{
			const DictRef battle = session_battle(state, session);
			const Atom retaliator_id = string_or_empty(state, defender_after, key::battle_id);
			const DictRef context = state.new_dict();
			state.set(context, str(key::target_battle_id), str(string_or_empty(state, attacker, key::battle_id)));
			_mark_stack_animation_event(state, battle, retaliator_id, key::battle_retaliation, context);
		}
		_apply_damage_to_stack(state, session_battle(state, session), string_or_empty(state, attacker, key::battle_id), retaliation_damage);
		{
			const DictRef battle = session_battle(state, session);
			const Atom text = gd::format(state, key::retaliates_against_text, { str(_stack_label(state, defender_after)), str(_stack_label(state, attacker_after)) });
			const DictRef context = action_context(state, key::retaliation, string_or_empty(state, defender_after, key::battle_id));
			state.set(context, str(key::target_battle_id), str(string_or_empty(state, attacker_after, key::battle_id)));
			_append_presentation_event(state, battle, key::retaliation, text, context);
		}
		state.append(messages, str(gd::format(state, key::retaliates_for_damage_text, { str(_stack_label(state, defender_after)), int_value(retaliation_damage) })));
		DictRef attacker_after_retaliation = _get_stack_by_id(state, session_battle(state, session), string_or_empty(state, attacker, key::battle_id));
		const ArrayRef retaliation_ability_messages = _apply_retaliation_ability_effects(state, session_battle(state, session), defender_after, attacker_after_retaliation);
		append_all(state, messages, retaliation_ability_messages);
		attacker_after_retaliation = _get_stack_by_id(state, session_battle(state, session), string_or_empty(state, attacker, key::battle_id));
		_append_damage_presentation_event(state, session_battle(state, session), key::damage, defender_after, attacker_before_retaliation, attacker_after_retaliation, retaliation_damage, key::retaliation, state.new_dict());
		_append_text_presentation_event(state, session_battle(state, session), key::ability, retaliation_ability_messages, defender_after, attacker_after_retaliation, key::retaliation);
		const ArrayRef retaliation_pressure_messages = _apply_damage_pressure(state, session_battle(state, session), defender_after, attacker_before_retaliation, attacker_after_retaliation, false, key::retaliation);
		append_all(state, messages, retaliation_pressure_messages);
		_append_text_presentation_event(state, session_battle(state, session), key::morale, retaliation_pressure_messages, defender_after, attacker_after_retaliation, key::retaliation);
		_mark_damage_target_animation(state, session_battle(state, session), string_or_empty(state, attacker, key::battle_id), state.array_size(retaliation_ability_messages) != 0, string_or_empty(state, defender_after, key::battle_id), state.new_dict(), attacker_before_retaliation);
		retaliated = true;
	}

	// The stack itself in the battle as it stands now: _evaluate_outcome may end
	// the battle, and this keeps the old one's stack.
	const DictRef target_after_before_outcome = _get_stack_by_id(state, session_battle(state, session), string_or_empty(state, target, key::battle_id));
	const DictRef outcome = _evaluate_outcome(state, session);
	if (string_or_empty(state, outcome, key::state) != key::empty) {
		_append_nonempty_message(state, messages, string_or_empty(state, outcome, key::message));
		const Atom outcome_message = join_with_space(state, messages);
		const DictRef result = accepted(state, outcome_message, string_or_empty(state, outcome, key::state));
		return _attach_post_attack_target_context(state, result, session, action_id, target_before, target_after_before_outcome);
	}

	if (!retaliated && _alive_count(state, _get_stack_by_id(state, session_battle(state, session), string_or_empty(state, target, key::battle_id))) <= 0) {
		state.append(messages, str(gd::format(state, key::stack_destroyed_format, { str(_stack_label(state, target)) })));
	}
	const DictRef objective_battle = session_battle(state, session);
	const DictRef objective_context = objective_action(state, action_id, string_or_empty(state, attacker, key::side), string_or_empty(state, attacker, key::battle_id));
	state.set(objective_context, str(key::target_battle_id), str(string_or_empty(state, target, key::battle_id)));
	const ArrayRef objective_messages = _apply_field_objective_action_pressure(state, objective_battle, objective_context);
	if (state.array_size(objective_messages) != 0) {
		state.append(messages, str(join_with_space(state, objective_messages)));
	}

	const DictRef completed = _complete_action(state, session, join_with_space(state, messages), true);
	return _attach_post_attack_target_context(state, completed, session, action_id, target_before, target_after_before_outcome);
}

DictRef _complete_action(State &state, const Value &session, Atom initial_message, bool turn_spent) {
	const ArrayRef messages = string_array(state, { initial_message });
	_record_event(state, session_battle(state, session), initial_message);
	DictRef outcome = _evaluate_outcome(state, session);
	if (string_or_empty(state, outcome, key::state) != key::empty) {
		_append_nonempty_message(state, messages, string_or_empty(state, outcome, key::message));
		const Atom message = join_with_space(state, messages);
		return accepted(state, message, string_or_empty(state, outcome, key::state));
	}

	if (turn_spent) {
		advance_turn(state, session_battle(state, session));
	}
	outcome = _evaluate_outcome(state, session);
	if (string_or_empty(state, outcome, key::state) != key::empty) {
		_append_nonempty_message(state, messages, string_or_empty(state, outcome, key::message));
		const Atom message = join_with_space(state, messages);
		return accepted(state, message, string_or_empty(state, outcome, key::state));
	}

	const DictRef enemy_result = _drain_enemy_turns(state, session);
	_append_nonempty_message(state, messages, string_or_empty(state, enemy_result, key::message));
	const Atom enemy_state = gd::string_field(state, enemy_result, key::state, key::continue_);
	if (enemy_state != key::empty && enemy_state != key::continue_) {
		const DictRef terminal_result = gd::deep_duplicate_dict(state, enemy_result);
		state.set(terminal_result, str(key::ok), bool_value(true));
		state.set(terminal_result, str(key::message), str(join_with_space(state, messages)));
		state.set(terminal_result, str(key::state), str(enemy_state));
		return terminal_result;
	}
	return accepted(state, join_with_space(state, messages), key::continue_);
}

DictRef _evaluate_outcome(State &state, const Value &session) {
	const bool player_alive = state.array_size(_alive_stacks_for_side(state, session_battle(state, session), key::player)) != 0;
	const bool enemy_alive = state.array_size(_alive_stacks_for_side(state, session_battle(state, session), key::enemy)) != 0;
	if (!enemy_alive && player_alive) {
		return host_dict(state, key::_finalize_victory, session);
	}
	if (!player_alive) {
		return host_dict(state, key::_finalize_player_battle_loss, session);
	}
	if (gd::int_field(state, session_battle(state, session), key::round, 1) > gd::int_field(state, session_battle(state, session), key::max_rounds, 12)) {
		return host_dict(state, key::_finalize_stalemate, session);
	}
	return state_and_message(state, key::empty, key::empty);
}

void _clear_stack_animation_states(State &state, DictRef battle) {
	if (gd::is_empty(state, battle)) {
		return;
	}
	state.set(battle, str(key::stack_animation_states), dict_value(state.new_dict()));
}

} // namespace aurelion::rules::port::battle_rules
