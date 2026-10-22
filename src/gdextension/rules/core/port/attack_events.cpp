// Layer 5: attack events: the damage and text presentation events, the damage target animation, message
// joining and the post-attack target context of a player action.

#include "aurelion_rules/port/battle_rules.hpp"

#include "aurelion_rules/compat/godot_math.hpp"

#include <string>
#include <vector>

namespace aurelion::rules::port::battle_rules {

using compat::engine_max;
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

// session.battle: SessionData.battle is a typed Dictionary.
DictRef session_battle(State &state, const Value &session) {
	return gd::as_dict(gd::member(state, session, key::battle));
}

// " ".join(parts) of a local Array of Strings.
Atom join_with_space(State &state, const std::vector<Atom> &parts) {
	std::string joined;
	for (size_t index = 0; index < parts.size(); ++index) {
		if (index > 0) {
			joined += state.text(key::space);
		}
		joined += state.text(parts[index]);
	}
	return state.intern(joined);
}

// _stack_label(stack) if not stack.is_empty() else "".
Atom label_or_empty(const State &state, DictRef stack) {
	return !gd::is_empty(state, stack) ? _stack_label(state, stack) : static_cast<Atom>(key::empty);
}

} // namespace

DictRef _attach_post_attack_target_context(State &state, DictRef result, const Value &session, Atom action_id, DictRef target_before, DictRef target_after_before_outcome) {
	bool no_battle = session.kind == Kind::Nil;
	DictRef battle = 0;
	if (!no_battle) {
		battle = session_battle(state, session);
		no_battle = gd::is_empty(state, battle);
	}
	if (no_battle) {
		_clear_post_move_transition_result_fields(state, result);
		const Atom attack_target_id = string_or_empty(state, target_before, key::battle_id);
		const bool attack_target_alive_after = attack_target_id != key::empty
				&& string_or_empty(state, target_after_before_outcome, key::battle_id) == attack_target_id
				&& _alive_count(state, target_after_before_outcome) > 0;
		const DictRef empty_legality = _attack_legality_for_target(state, state.new_dict(), state.new_dict(), state.new_dict());
		const DictRef empty_click_intent = board_click_attack_intent_for_target(state, state.new_dict(), key::empty);
		state.set(result, str(key::attack_action), str(action_id));
		state.set(result, str(key::attack_target_battle_id), str(attack_target_id));
		state.set(result, str(key::attack_target_name), str(label_or_empty(state, target_before)));
		state.set(result, str(key::attack_target_alive_after_attack), bool_value(attack_target_alive_after));
		state.set(result, str(key::attack_target_still_selected_after_attack), bool_value(false));
		state.set(result, str(key::attack_target_invalidated_after_attack), bool_value(attack_target_id != key::empty));
		state.set(result, str(key::active_stack_after_attack_battle_id), str(key::empty));
		state.set(result, str(key::active_stack_after_attack_side), str(key::empty));
		state.set(result, str(key::selected_target_after_attack_battle_id), str(key::empty));
		state.set(result, str(key::selected_target_after_attack_name), str(key::empty));
		state.set(result, str(key::selected_target_valid_after_attack), bool_value(false));
		state.set(result, str(key::selected_target_after_attack_legality), dict_value(gd::deep_duplicate_dict(state, empty_legality)));
		state.set(result, str(key::selected_target_after_attack_board_click_intent), dict_value(gd::deep_duplicate_dict(state, empty_click_intent)));
		state.set(result, str(key::selected_target_after_attack_board_click_action), str(key::empty));
		state.set(result, str(key::selected_target_after_attack_board_click_label), str(key::empty));
		state.set(result, str(key::selected_target_handoff_after_attack), bool_value(false));
		state.set(result, str(key::selected_target_handoff_direct_actionable_after_attack), bool_value(false));
		state.set(result, str(key::selected_target_handoff_blocked_after_attack), bool_value(false));
		state.set(result, str(key::selected_target_direct_actionable_after_attack), bool_value(false));
		state.set(result, str(key::selected_target_continuity_context), dict_value(state.new_dict()));
		state.set(result, str(key::selected_target_preserved_setup), bool_value(false));
		state.set(result, str(key::selected_target_closing_context), dict_value(state.new_dict()));
		state.set(result, str(key::selected_target_closing_on_target), bool_value(false));
		return result;
	}
	_clear_post_move_transition_result_fields(state, result);
	_clear_selected_target_continuity(state, battle);
	_clear_selected_target_closing(state, battle);
	const DictRef active_stack = get_active_stack(state, battle);
	const DictRef selected_target = get_selected_target(state, battle);
	const Atom attack_target_id = string_or_empty(state, target_before, key::battle_id);
	const Atom selected_target_id = string_or_empty(state, selected_target, key::battle_id);
	const DictRef attack_target_after = _get_stack_by_id(state, battle, attack_target_id);
	const bool attack_target_alive_after = !gd::is_empty(state, attack_target_after) && _alive_count(state, attack_target_after) > 0;
	const bool selected_target_valid_after_attack = _selected_target_can_remain_for_active_stack(state, battle, active_stack, selected_target_id);
	const bool attack_target_still_selected_after_attack = attack_target_id != key::empty
			&& selected_target_id == attack_target_id
			&& attack_target_alive_after
			&& selected_target_valid_after_attack;
	const DictRef selected_legality = selected_target_legality(state, battle);
	const DictRef selected_click_intent = selected_target_board_click_intent(state, battle);
	const DictRef selected_continuity_context = selected_target_continuity_context(state, battle);
	const DictRef selected_closing_context = selected_target_closing_context(state, battle, true);
	const Atom selected_action_label = string_or_empty(state, selected_click_intent, key::label);
	const bool selected_target_handoff_after_attack = attack_target_id != key::empty
			&& selected_target_id != key::empty
			&& selected_target_id != attack_target_id
			&& !attack_target_still_selected_after_attack;
	const bool selected_target_direct_actionable_after_attack = gd::is_empty(state, selected_continuity_context)
			&& gd::is_empty(state, selected_closing_context)
			&& gd::bool_field(state, selected_legality, key::attackable, false)
			&& selected_action_label != key::empty;
	state.set(result, str(key::attack_action), str(action_id));
	state.set(result, str(key::attack_target_battle_id), str(attack_target_id));
	state.set(result, str(key::attack_target_name), str(label_or_empty(state, target_before)));
	state.set(result, str(key::attack_target_alive_after_attack), bool_value(attack_target_alive_after));
	state.set(result, str(key::attack_target_still_selected_after_attack), bool_value(attack_target_still_selected_after_attack));
	state.set(result, str(key::attack_target_invalidated_after_attack), bool_value(attack_target_id != key::empty && !attack_target_still_selected_after_attack));
	state.set(result, str(key::active_stack_after_attack_battle_id), str(string_or_empty(state, active_stack, key::battle_id)));
	state.set(result, str(key::active_stack_after_attack_side), str(string_or_empty(state, active_stack, key::side)));
	state.set(result, str(key::selected_target_after_attack_battle_id), str(selected_target_id));
	state.set(result, str(key::selected_target_after_attack_name), str(label_or_empty(state, selected_target)));
	state.set(result, str(key::selected_target_valid_after_attack), bool_value(selected_target_valid_after_attack));
	state.set(result, str(key::selected_target_after_attack_legality), dict_value(gd::deep_duplicate_dict(state, selected_legality)));
	state.set(result, str(key::selected_target_after_attack_board_click_intent), dict_value(gd::deep_duplicate_dict(state, selected_click_intent)));
	state.set(result, str(key::selected_target_after_attack_board_click_action), str(string_or_empty(state, selected_click_intent, key::action)));
	state.set(result, str(key::selected_target_after_attack_board_click_label), str(selected_action_label));
	state.set(result, str(key::selected_target_handoff_after_attack), bool_value(selected_target_handoff_after_attack));
	state.set(result, str(key::selected_target_handoff_direct_actionable_after_attack), bool_value(selected_target_handoff_after_attack && selected_target_direct_actionable_after_attack));
	state.set(result, str(key::selected_target_handoff_blocked_after_attack), bool_value(selected_target_handoff_after_attack && gd::bool_field(state, selected_legality, key::blocked, false)));
	state.set(result, str(key::selected_target_direct_actionable_after_attack), bool_value(selected_target_direct_actionable_after_attack));
	state.set(result, str(key::selected_target_continuity_context), dict_value(gd::deep_duplicate_dict(state, selected_continuity_context)));
	state.set(result, str(key::selected_target_preserved_setup), bool_value(!gd::is_empty(state, selected_continuity_context)));
	state.set(result, str(key::selected_target_closing_context), dict_value(gd::deep_duplicate_dict(state, selected_closing_context)));
	state.set(result, str(key::selected_target_closing_on_target), bool_value(!gd::is_empty(state, selected_closing_context)));
	return result;
}

void _append_damage_presentation_event(State &state, DictRef battle, Atom event_type, DictRef attacker, DictRef target_before, DictRef target_after, int64_t damage, Atom action_id, DictRef extra_context) {
	if (gd::is_empty(state, target_before)) {
		return;
	}
	const Atom target_id = string_or_empty(state, target_before, key::battle_id);
	const int64_t health_before = gd::int_field(state, target_before, key::total_health, 0);
	const int64_t health_lost = engine_max<int64_t>(0, gd::sub(health_before, gd::int_field(state, target_after, key::total_health, 0)));
	const int64_t alive_before = _alive_count(state, target_before);
	const int64_t units_lost = engine_max<int64_t>(0, gd::sub(alive_before, _alive_count(state, target_after)));
	const Atom target_name = _stack_label(state, target_before);
	std::string text = state.text(gd::format(state, key::damage_event_takes_format, { str(target_name), int_value(engine_max<int64_t>(0, damage)) }));
	if (units_lost > 0) {
		const Atom plural = units_lost == 1 ? static_cast<Atom>(key::empty) : static_cast<Atom>(key::s);
		text += state.text(gd::format(state, key::damage_event_units_lost_format, { int_value(units_lost), str(plural) }));
	}
	if (!gd::is_empty(state, target_after) && _alive_count(state, target_after) <= 0) {
		text += state.text(gd::format(state, key::damage_event_falls_format, { str(target_name) }));
	}
	text += state.text(key::period);
	const DictRef context = gd::deep_duplicate_dict(state, extra_context);
	state.set(context, str(key::action_id), str(action_id));
	state.set(context, str(key::actor_battle_id), str(string_or_empty(state, attacker, key::battle_id)));
	state.set(context, str(key::target_battle_id), str(target_id));
	state.set(context, str(key::target_name), str(target_name));
	state.set(context, str(key::damage), int_value(engine_max<int64_t>(0, damage)));
	state.set(context, str(key::units_lost), int_value(units_lost));
	state.set(context, str(key::detail_text), str(gd::format(state, key::damage_event_health_lost_format, { int_value(health_lost) })));
	_append_presentation_event(state, battle, event_type, state.intern(text), context);
	if (!gd::is_empty(state, target_after) && _alive_count(state, target_after) <= 0) {
		_append_presentation_event(state, battle, key::death, gd::format(state, key::stack_destroyed_format, { str(target_name) }), context);
	}
}

void _append_text_presentation_event(State &state, DictRef battle, Atom event_type, ArrayRef texts, DictRef actor, DictRef target, Atom action_id) {
	std::vector<Atom> lines;
	for (const Value &text_value : gd::items(state, gd::array_value(texts))) {
		const Atom line = gd::strip_edges(state, gd::to_string(text_value));
		if (line != key::empty) {
			lines.push_back(line);
		}
	}
	if (lines.empty()) {
		return;
	}
	const Atom visible_text = join_with_space(state, lines);
	const Atom actor_battle_id = string_or_empty(state, actor, key::battle_id);
	const Atom target_battle_id = string_or_empty(state, target, key::battle_id);
	const DictRef context = state.new_dict();
	state.set(context, str(key::action_id), str(action_id));
	state.set(context, str(key::actor_battle_id), str(actor_battle_id));
	state.set(context, str(key::target_battle_id), str(target_battle_id));
	_append_presentation_event(state, battle, event_type, visible_text, context);
}

void _append_nonempty_message(State &state, ArrayRef messages, Atom message) {
	if (message != key::empty) {
		state.append(messages, str(message));
	}
}

Atom _join_messages(State &state, ArrayRef parts) {
	std::vector<Atom> messages;
	for (const Value &value : gd::items(state, gd::array_value(parts))) {
		const Atom message = gd::to_string(value);
		if (message != key::empty) {
			messages.push_back(message);
		}
	}
	return join_with_space(state, messages);
}

void _mark_damage_target_animation(State &state, DictRef battle, Atom battle_id, bool had_status_effect, Atom source_battle_id, DictRef extra_context, DictRef target_before) {
	if (battle_id == key::empty) {
		return;
	}
	const DictRef target = _get_stack_by_id(state, battle, battle_id);
	if (gd::is_empty(state, target)) {
		return;
	}
	const DictRef context = gd::deep_duplicate_dict(state, extra_context);
	if (source_battle_id != key::empty) {
		state.set(context, str(key::source_battle_id), str(source_battle_id));
	}
	if (!gd::is_empty(state, target_before)) {
		const int64_t unit_hp = engine_max<int64_t>(1, gd::int_field(state, target, key::unit_hp, 1));
		const int64_t health_before = gd::int_field(state, target_before, key::total_health, 0);
		const int64_t health_after = gd::int_field(state, target, key::total_health, 0);
		state.set(context, str(key::_playback_applied_damage), int_value(engine_max<int64_t>(0, gd::sub(health_before, health_after))));
		// int(ceil(float(health) / unit_hp)): a float division, ceil of a float stays a float.
		const int64_t units_before = compat::float_to_int(compat::godot_ceil(static_cast<double>(health_before) / static_cast<double>(unit_hp)));
		const int64_t units_after = compat::float_to_int(compat::godot_ceil(static_cast<double>(health_after) / static_cast<double>(unit_hp)));
		state.set(context, str(key::_playback_applied_casualties), int_value(engine_max<int64_t>(0, gd::sub(units_before, units_after))));
	}
	if (_alive_count(state, target) <= 0) {
		_mark_stack_animation_event(state, battle, battle_id, key::battle_unit_death, context);
	} else if (had_status_effect) {
		_mark_stack_animation_event(state, battle, battle_id, key::battle_status_applied, context);
	} else {
		_mark_stack_animation_event(state, battle, battle_id, key::battle_unit_hit, context);
	}
}

} // namespace aurelion::rules::port::battle_rules
