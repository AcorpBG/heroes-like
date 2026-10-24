// BattleRules for the battle screen (Phase 7, slice 7.9): the action surface's
// description, the readiness confirmation and the intent forecast.

#include "aurelion_rules/port/battle_screen.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/battle_ai_rules.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/spell_rules.hpp"

#include <string>
#include <vector>

namespace aurelion::rules::port {

namespace {

using gd::array_value;
using gd::ArrayRef;
using gd::Atom;
using gd::dict_value;
using gd::DictRef;
using gd::float_value;
using gd::str;
using state::ContentTable;
using state::Kind;
using state::State;
using state::Value;
namespace key = state::key;

// String(x) of any value: the engine's text for a float, a vector or a container.
Atom string_of(State &state, const Value &value) {
	switch (value.kind) {
		case Kind::Nil:
		case Kind::Bool:
		case Kind::Int:
		case Kind::String:
		case Kind::StringName:
			return gd::stringify(state, value);
		default:
			return gd::engine_str(state, value);
	}
}

// String(dict.get(field, fallback)).
Atom text_of(State &state, DictRef dict, Atom field, const Value &fallback) {
	return string_of(state, state.get(dict, str(field), fallback));
}

// String(action.get("label", action_id.capitalize())).
Atom label_or_capitalized(State &state, DictRef action, Atom action_id) {
	Value label;
	if (state.lookup(action, str(key::label), label)) {
		return string_of(state, label);
	}
	return gd::capitalize(state, action_id);
}

// session.battle: SessionData types it Dictionary.
DictRef battle_of(State &state, DictRef session) {
	return gd::as_dict(gd::field(state, session, key::battle));
}

// d.get(k, {}) if d.get(k, {}) is Dictionary else {}: the entry itself, or a new {}.
DictRef dict_entry(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found) && gd::is_dict(found)) {
		return found.ref;
	}
	return state.new_dict();
}

std::string join_text(State &state, Atom separator, const std::vector<Atom> &parts) {
	std::string joined;
	for (size_t index = 0; index < parts.size(); ++index) {
		if (index > 0) {
			joined += state.text(separator);
		}
		joined += state.text(parts[index]);
	}
	return joined;
}

// separator.join(parts) of Strings.
Atom join(State &state, Atom separator, const std::vector<Atom> &parts) {
	return state.intern(join_text(state, separator, parts));
}

Atom concat(State &state, Atom a, Atom b) {
	return state.intern(state.text(a) + state.text(b));
}

// text.trim_suffix(suffix).
Atom trim_suffix(State &state, Atom text, Atom suffix) {
	if (!gd::ends_with(state, text, suffix)) {
		return text;
	}
	const std::string &source = state.text(text);
	const std::string trimmed = source.substr(0, source.size() - state.text(suffix).size());
	return state.intern(trimmed);
}

// text.split(delimiter, false): the pieces between the delimiters, the empty
// ones left out (String::split with allow_empty false).
std::vector<Atom> split_non_empty(State &state, Atom text, Atom delimiter) {
	const std::string source = state.text(text);
	const std::string splitter = state.text(delimiter);
	std::vector<Atom> pieces;
	if (source.empty()) {
		return pieces;
	}
	size_t from = 0;
	while (true) {
		size_t end = source.find(splitter, from);
		if (end == std::string::npos) {
			end = source.size();
		}
		if (end > from) {
			pieces.push_back(state.intern(source.substr(from, end - from)));
		}
		if (end == source.size()) {
			break;
		}
		from = end + splitter.size();
	}
	return pieces;
}

// s.length(): Godot's Strings count code points.
int64_t code_point_count(const std::string &text) {
	int64_t count = 0;
	for (const char c : text) {
		if ((static_cast<unsigned char>(c) & 0xC0) != 0x80) {
			++count;
		}
	}
	return count;
}

// s.left(count) for count > 0: the first count code points, all of them when
// there are fewer.
std::string left_code_points(const std::string &text, int64_t count) {
	int64_t seen = 0;
	for (size_t index = 0; index < text.size(); ++index) {
		if ((static_cast<unsigned char>(text[index]) & 0xC0) != 0x80) {
			if (seen == count) {
				return text.substr(0, index);
			}
			++seen;
		}
	}
	return text;
}

// text.to_lower() of ASCII text; other text needs the engine's Unicode case
// tables.
Atom ascii_lower(State &state, Atom text, const char *where) {
	std::string lowered = state.text(text);
	for (char &c : lowered) {
		const unsigned char byte = static_cast<unsigned char>(c);
		if (byte >= 0x80) {
			throw state::NotPorted(std::string(where) + ": to_lower() of non-ASCII text");
		}
		if (byte >= 'A' && byte <= 'Z') {
			c = static_cast<char>(byte - 'A' + 'a');
		}
	}
	return state.intern(lowered);
}

// text.to_lower().contains(word) of an ASCII word. A character outside ASCII
// lowers to one outside ASCII, so it is never part of the word, except U+0130
// (to "i") and U+212A (to "k"), which are left out.
bool lower_contains(State &state, Atom text, Atom word, const char *where) {
	const std::string &source = state.text(text);
	std::string lowered;
	lowered.reserve(source.size());
	for (size_t index = 0; index < source.size(); ++index) {
		const unsigned char byte = static_cast<unsigned char>(source[index]);
		if (byte == 0xC4 && index + 1 < source.size() && static_cast<unsigned char>(source[index + 1]) == 0xB0) {
			throw state::NotPorted(std::string(where) + ": to_lower() of U+0130");
		}
		if (byte == 0xE2 && index + 2 < source.size() && static_cast<unsigned char>(source[index + 1]) == 0x84
				&& static_cast<unsigned char>(source[index + 2]) == 0xAA) {
			throw state::NotPorted(std::string(where) + ": to_lower() of U+212A");
		}
		lowered += static_cast<char>(byte >= 'A' && byte <= 'Z' ? byte - 'A' + 'a' : byte);
	}
	return lowered.find(state.text(word)) != std::string::npos;
}

// A new Array of Strings.
ArrayRef string_array(State &state, std::initializer_list<Atom> texts) {
	const ArrayRef array = state.new_array();
	for (const Atom text : texts) {
		state.append(array, str(text));
	}
	return array;
}

bool is_attack_action(Atom action_id) {
	return action_id == key::strike || action_id == key::shoot;
}

} // namespace

namespace battle_rules {

Atom describe_action_surface(State &state, DictRef session) {
	const DictRef battle = battle_of(state, session);
	if (gd::is_empty(state, battle)) {
		return key::no_battle_orders_are_available;
	}
	const DictRef active_stack = get_active_stack(state, battle);
	if (gd::is_empty(state, active_stack)) {
		return key::no_stack_is_ready_to_act;
	}
	if (text_of(state, active_stack, key::side, str(key::empty)) != key::player) {
		return gd::format(state, key::s_is_acting_now_hold_the, {str(_stack_label(state, active_stack))});
	}
	const DictRef target = get_selected_target(state, battle);
	const DictRef actions = get_action_surface(state, session);
	const Atom target_line = _target_focus_action_line(state, active_stack, target, battle);
	const DictRef click_intent = selected_target_board_click_intent(state, battle);
	const DictRef movement_intent = active_movement_board_click_intent(state, battle, Value());
	const DictRef continuity_context = selected_target_continuity_context(state, battle);
	const DictRef closing_context = selected_target_closing_context(state, battle, true);
	Atom board_click_line = text_of(state, click_intent, key::message, str(key::empty));
	if (board_click_line == key::empty) {
		board_click_line = key::board_select_an_enemy_or_move;
	}
	if (!gd::is_empty(state, continuity_context)) {
		board_click_line = text_of(state, continuity_context, key::message, str(board_click_line));
	} else if (!gd::is_empty(state, closing_context)) {
		board_click_line = text_of(state, closing_context, key::message, str(board_click_line));
	}
	const Atom movement_click_line = text_of(state, movement_intent, key::message, str(key::empty));
	const Atom manual_cue = _manual_battle_action_cue(state, actions, click_intent, movement_intent);
	const Atom confirmation_line = describe_action_readiness_confirmation(state, session);
	std::vector<Atom> lines = {
		gd::format(state, key::target_focus_s, {str(target_line)}),
		confirmation_line,
		manual_cue,
		board_click_line,
	};
	if (movement_click_line != key::empty) {
		lines.push_back(movement_click_line);
	}
	const Atom action_ids[] = {key::advance, key::strike, key::shoot, key::defend, key::retreat, key::surrender};
	for (const Atom action_id : action_ids) {
		Value action;
		Atom label = key::empty;
		Atom summary = key::empty;
		if (state.lookup(actions, str(action_id), action)) {
			label = string_of(state, ai::vget(state, action, key::label, str(gd::capitalize(state, action_id))));
			summary = string_of(state, ai::vget(state, action, key::summary, str(key::empty)));
		} else {
			label = gd::capitalize(state, action_id);
		}
		lines.push_back(gd::format(state, key::s_colon_s_text, {str(label), str(summary)}));
	}
	return join(state, key::newline, lines);
}

DictRef action_readiness_confirmation_payload(State &state, DictRef session) {
	const DictRef battle = battle_of(state, session);
	if (gd::is_empty(state, battle)) {
		const DictRef payload = state.new_dict();
		state.set(payload, str(key::visible_text), str(key::ready_check_unavailable));
		state.set(payload, str(key::tooltip_text), str(key::action_confirmation_no_battle_is_active));
		return payload;
	}
	const DictRef active_stack = get_active_stack(state, battle);
	if (gd::is_empty(state, active_stack)) {
		const DictRef payload = state.new_dict();
		state.set(payload, str(key::visible_text), str(key::ready_check_no_stack_is_queued));
		state.set(payload, str(key::tooltip_text), str(key::action_confirmation_no_stack_is_queued));
		state.set(payload, str(key::next_step_2), str(key::wait_for_battle_resolution));
		return payload;
	}
	if (text_of(state, active_stack, key::side, str(key::empty)) != key::player) {
		const Atom enemy_text = gd::format(state, key::ready_check_s_has_initiative_wait, {str(_stack_label(state, active_stack))});
		const DictRef payload = state.new_dict();
		state.set(payload, str(key::visible_text), str(enemy_text));
		state.set(payload, str(key::tooltip_text), str(gd::format(state, key::action_confirmation_active_s_next_wait, {str(_stack_label(state, active_stack))})));
		state.set(payload, str(key::active_stack), str(_stack_label(state, active_stack)));
		state.set(payload, str(key::next_step_2), str(key::wait_for_command_to_return));
		return payload;
	}

	const DictRef target = get_selected_target(state, battle);
	const DictRef surface = get_action_surface(state, session);
	const Atom action_id = _preferred_player_action_id(state, surface, active_stack);
	const DictRef action = dict_entry(state, surface, action_id);
	const Atom action_label = gd::strip_edges(state, label_or_capitalized(state, action, action_id));
	Value target_value;
	Atom target_label = key::empty;
	if (state.lookup(action, str(key::target), target_value)) {
		target_label = string_of(state, target_value);
	} else {
		target_label = !gd::is_empty(state, target) ? _stack_label(state, target) : static_cast<Atom>(key::current_focus);
	}
	target_label = gd::strip_edges(state, target_label);
	const Atom consequence = gd::strip_edges(state, text_of(state, action, key::consequence, state.get(action, str(key::summary), str(key::empty))));
	const DictRef spell_action = _preferred_spell_timing_action(state, session, battle, active_stack, target);
	const Atom spell_label = gd::strip_edges(state, text_of(state, spell_action, key::label, str(key::empty)));
	const DictRef hold_action = dict_entry(state, surface, key::defend);
	const bool hold_ready = !gd::bool_field(state, hold_action, key::disabled, true);
	if (action_id == key::empty) {
		const DictRef payload = state.new_dict();
		state.set(payload, str(key::visible_text), str(key::ready_check_retarget_move_or_wait));
		state.set(payload, str(key::tooltip_text), str(key::action_confirmation_no_ready_order_is));
		state.set(payload, str(key::next_step_2), str(key::retarget_or_change_posture));
		return payload;
	}

	std::vector<Atom> option_parts;
	if (spell_label != key::empty) {
		option_parts.push_back(gd::format(state, key::cast_s_first_the_stack_keeps, {str(spell_label)}));
	}
	if (hold_ready && action_id != key::defend) {
		option_parts.push_back(key::defend_to_hold);
	}
	Atom option_text = key::empty;
	if (!option_parts.empty()) {
		option_text = gd::format(state, key::or_s, {str(join(state, key::comma_space, option_parts))});
	}
	const Atom target_text = target_label != key::empty && is_attack_action(action_id) ? gd::format(state, key::on_s, {str(target_label)}) : static_cast<Atom>(key::empty);
	const Atom visible = gd::format(state, key::ready_check_confirm_s_s_s, {str(action_label), str(target_text), str(option_text)});
	const Atom readiness = text_of(state, action, key::readiness, str(key::empty));
	const Atom why = text_of(state, action, key::why, str(key::empty));
	Atom tooltip = gd::format(state, key::action_confirmation_confirm_s_s_readiness, {str(action_label), str(target_text), str(readiness), str(why), str(consequence)});
	if (spell_label != key::empty) {
		tooltip = concat(state, tooltip, gd::format(state, key::cast_option_s, {str(text_of(state, spell_action, key::summary, str(spell_label)))}));
	}
	if (hold_ready && action_id != key::defend) {
		tooltip = concat(state, tooltip, gd::format(state, key::hold_option_s, {str(text_of(state, hold_action, key::summary, str(key::defend_to_hold_position)))}));
	}
	const DictRef payload = state.new_dict();
	state.set(payload, str(key::visible_text), str(visible));
	state.set(payload, str(key::tooltip_text), str(tooltip));
	state.set(payload, str(key::action_id), str(action_id));
	state.set(payload, str(key::button_label), str(action_label));
	state.set(payload, str(key::target), str(target_label));
	state.set(payload, str(key::readiness), str(text_of(state, action, key::readiness, str(key::empty))));
	state.set(payload, str(key::why), str(text_of(state, action, key::why, str(key::empty))));
	state.set(payload, str(key::consequence), str(consequence));
	state.set(payload, str(key::spell_option), str(spell_label));
	state.set(payload, str(key::hold_option), str(hold_ready ? static_cast<Atom>(key::Defend) : static_cast<Atom>(key::empty)));
	state.set(payload, str(key::next_step_2), str(key::order_ends_this_stack_s_action));
	return payload;
}

Atom describe_action_readiness_confirmation(State &state, DictRef session) {
	return text_of(state, action_readiness_confirmation_payload(state, session), key::visible_text, str(key::ready_check_unavailable));
}

DictRef intent_forecast_payload(State &state, DictRef session) {
	const DictRef battle = battle_of(state, session);
	if (gd::is_empty(state, battle)) {
		const DictRef payload = state.new_dict();
		state.set(payload, str(key::visible_text), str(key::suggested_order_unavailable));
		state.set(payload, str(key::tooltip_text), str(key::order_preview_no_battle_is_loaded));
		state.set(payload, str(key::readiness), str(key::unavailable));
		return payload;
	}
	const DictRef active_stack = get_active_stack(state, battle);
	if (gd::is_empty(state, active_stack)) {
		const DictRef payload = state.new_dict();
		state.set(payload, str(key::visible_text), str(key::suggested_order_wait_for_the_next));
		state.set(payload, str(key::tooltip_text), str(key::order_preview_no_stack_is_queued));
		state.set(payload, str(key::readiness), str(key::waiting));
		return payload;
	}
	if (text_of(state, active_stack, key::side, str(key::empty)) != key::player) {
		const DictRef enemy_hero = gd::as_dict(state.get(battle, str(key::enemy_hero), dict_value(state.new_dict())));
		const DictRef enemy_action = battle_ai_rules::choose_enemy_action(state, battle, active_stack, enemy_hero, true);
		const Atom enemy_reply = _enemy_action_preview_summary(state, battle, active_stack, enemy_action);
		const DictRef payload = state.new_dict();
		state.set(payload, str(key::visible_text), str(gd::format(state, key::incoming_order_s, {str(_intent_forecast_sentence(state, enemy_reply))})));
		state.set(payload, str(key::tooltip_text), str(gd::format(state, key::order_preview_active_s_incoming_s, {str(_stack_label(state, active_stack)), str(enemy_reply)})));
		state.set(payload, str(key::readiness), str(key::locked));
		state.set(payload, str(key::action_id), str(text_of(state, enemy_action, key::action, str(key::empty))));
		state.set(payload, str(key::target_battle_id), str(text_of(state, enemy_action, key::target_battle_id, str(key::empty))));
		state.set(payload, str(key::risk), str(enemy_reply));
		return payload;
	}

	const DictRef surface = get_action_surface(state, session);
	const ArrayRef spell_actions = get_spell_actions(state, session);
	DictRef tactical_commander_payload = dict_entry(state, battle, key::player_hero);
	if (gd::is_empty(state, tactical_commander_payload)) {
		Value commander_state;
		if (!state.lookup(battle, str(key::player_commander_state), commander_state)) {
			tactical_commander_payload = state.new_dict();
		} else if (gd::is_dict(commander_state)) {
			tactical_commander_payload = commander_state.ref;
		}
	}
	const DictRef tactical_order = battle_ai_rules::choose_stack_tactical_order(state, battle, active_stack, key::enemy, tactical_commander_payload, true);
	const Atom action_id = _intent_forecast_action_id(state, battle, surface, spell_actions, tactical_order, active_stack);
	if (action_id == key::empty) {
		const DictRef payload = state.new_dict();
		state.set(payload, str(key::visible_text), str(key::suggested_order_no_legal_action_is));
		state.set(payload, str(key::tooltip_text), str(gd::format(state, key::order_preview_active_s_no_ready, {str(_stack_label(state, active_stack))})));
		state.set(payload, str(key::readiness), str(key::blocked));
		return payload;
	}
	const DictRef action = _intent_forecast_action(state, surface, spell_actions, action_id);
	DictRef target = get_selected_target(state, battle);
	const Atom tactical_target_id = text_of(state, tactical_order, key::target_battle_id, str(key::empty));
	if (tactical_target_id != key::empty && _intent_forecast_action_matches_tactical_order(state, action_id, tactical_order)) {
		const DictRef tactical_target = _get_stack_by_id(state, battle, tactical_target_id);
		if (!gd::is_empty(state, tactical_target)) {
			target = tactical_target;
		}
	}
	const Atom action_label = gd::strip_edges(state, label_or_capitalized(state, action, action_id));
	const Atom target_label = _intent_forecast_target_label(state, action_id, active_stack, target);
	const Atom expected_result = _intent_forecast_expected_result(state, action_id, session, battle, active_stack, target, action);
	Atom reason = gd::strip_edges(state, text_of(state, action, key::why, state.get(action, str(key::best_use), str(key::empty))));
	if (reason == key::empty) {
		reason = _action_why_line(state, action_id, session, battle, active_stack, target, true);
	}
	const Atom risk = _enemy_reply_line(state, session, battle);
	const Atom confidence = _intent_forecast_confidence_line(state, tactical_order, action_id);
	Atom retarget_line = key::empty;
	if (tactical_target_id != key::empty
			&& tactical_target_id != text_of(state, get_selected_target(state, battle), key::battle_id, str(key::empty))
			&& is_attack_action(action_id)) {
		retarget_line = gd::format(state, key::retarget_first_s, {str(target_label)});
	}
	const Atom target_suffix = target_label != key::empty ? gd::format(state, key::s_9, {str(target_label)}) : static_cast<Atom>(key::empty);
	const Atom visible_order = gd::format(state, key::s_s_5, {str(action_label), str(target_suffix)});
	const Atom visible_prefix = gd::format(state, key::suggested_order_s, {str(visible_order)});
	const int64_t max_chars = compat::engine_max<int64_t>(24, gd::sub(95, code_point_count(state.text(visible_prefix))));
	const Atom visible_result = _intent_forecast_compact_result(state, expected_result, max_chars);
	const Atom visible = gd::format(state, key::s_s_16, {str(visible_prefix), str(visible_result)});
	std::vector<Atom> tooltip_lines = {
		key::order_preview,
		gd::format(state, key::active_s, {str(_stack_label(state, active_stack))}),
		gd::format(state, key::preferred_order_s_s, {str(action_label), str(target_suffix)}),
		gd::format(state, key::expected_result_s, {str(expected_result)}),
		gd::format(state, key::why_s_2, {str(reason)}),
		gd::format(state, key::risk_s_2, {str(risk)}),
		gd::format(state, key::confidence_s, {str(confidence)}),
		key::inspection_checking_this_forecast_does_not,
	};
	if (retarget_line != key::empty) {
		tooltip_lines.insert(tooltip_lines.begin() + 3, gd::format(state, key::dash_space_s, {str(retarget_line)}));
	}
	const DictRef payload = state.new_dict();
	state.set(payload, str(key::visible_text), str(visible));
	state.set(payload, str(key::tooltip_text), str(join(state, key::newline, tooltip_lines)));
	state.set(payload, str(key::readiness), str(text_of(state, action, key::readiness, str(key::Ready))));
	state.set(payload, str(key::action_id), str(action_id));
	state.set(payload, str(key::action_label), str(action_label));
	state.set(payload, str(key::target), str(target_label));
	state.set(payload, str(key::target_battle_id), str(text_of(state, target, key::battle_id, str(key::empty))));
	state.set(payload, str(key::expected_result), str(expected_result));
	state.set(payload, str(key::why), str(reason));
	state.set(payload, str(key::risk), str(risk));
	state.set(payload, str(key::confidence), str(confidence));
	state.set(payload, str(key::scoring_policy), str(text_of(state, tactical_order, key::scoring_policy, str(key::empty))));
	Value candidate_scores;
	if (state.lookup(tactical_order, str(key::candidate_scores), candidate_scores) && gd::is_dict(candidate_scores)) {
		state.set(payload, str(key::candidate_scores), dict_value(gd::deep_duplicate_dict(state, candidate_scores.ref)));
	} else {
		state.set(payload, str(key::candidate_scores), dict_value(state.new_dict()));
	}
	return payload;
}

Atom _intent_forecast_action_id(State &state, DictRef battle, DictRef surface, ArrayRef spell_actions, DictRef tactical_order, DictRef active_stack) {
	const Atom tactical_action = text_of(state, tactical_order, key::action, str(key::empty));
	if (tactical_action == key::cast_spell) {
		const Atom tactical_spell_action_id = gd::format(state, key::cast_spell_s, {str(text_of(state, tactical_order, key::spell_id, str(key::empty)))});
		if (_intent_forecast_tactical_spell_target_is_public(state, battle, active_stack, tactical_order)) {
			for (const Value &action_value : gd::items(state, array_value(spell_actions))) {
				if (!gd::is_dict(action_value)) {
					continue;
				}
				const DictRef spell_action = action_value.ref;
				if (text_of(state, spell_action, key::id, str(key::empty)) == tactical_spell_action_id && !gd::bool_field(state, spell_action, key::disabled, true)) {
					return tactical_spell_action_id;
				}
			}
		}
		return _preferred_player_action_id(state, surface, active_stack);
	}
	if (tactical_action != key::empty) {
		const DictRef tactical_surface = dict_entry(state, surface, tactical_action);
		if (!gd::bool_field(state, tactical_surface, key::disabled, true)) {
			return tactical_action;
		}
	}
	return _preferred_player_action_id(state, surface, active_stack);
}

bool _intent_forecast_tactical_spell_target_is_public(State &state, DictRef battle, DictRef active_stack, DictRef tactical_order) {
	const Atom spell_id = text_of(state, tactical_order, key::spell_id, str(key::empty));
	const Atom tactical_target_id = text_of(state, tactical_order, key::target_battle_id, str(key::empty));
	if (spell_id == key::empty || tactical_target_id == key::empty) {
		return false;
	}
	const DictRef spell = gd::content_row(state, ContentTable::Spell, spell_id);
	if (gd::is_empty(state, spell)) {
		return false;
	}
	Atom public_target_id = key::empty;
	const Atom target_mode = text_of(state, spell, key::target_mode, str(key::empty));
	if (target_mode == key::ally_active) {
		public_target_id = text_of(state, active_stack, key::battle_id, str(key::empty));
	} else if (target_mode == key::enemy_selected) {
		public_target_id = text_of(state, get_selected_target(state, battle), key::battle_id, str(key::empty));
	} else {
		return false;
	}
	return public_target_id != key::empty && tactical_target_id == public_target_id;
}

DictRef _intent_forecast_action(State &state, DictRef surface, ArrayRef spell_actions, Atom action_id) {
	if (gd::begins_with(state, action_id, key::cast_spell_prefix_text)) {
		for (const Value &action_value : gd::items(state, array_value(spell_actions))) {
			if (gd::is_dict(action_value) && text_of(state, action_value.ref, key::id, str(key::empty)) == action_id) {
				return gd::deep_duplicate_dict(state, action_value.ref);
			}
		}
	}
	Value surface_action;
	if (state.lookup(surface, str(action_id), surface_action) && gd::is_dict(surface_action)) {
		return gd::deep_duplicate_dict(state, surface_action.ref);
	}
	// A missing action is {}.duplicate(true); any other value is {}.
	return state.new_dict();
}

bool _intent_forecast_action_matches_tactical_order(State &state, Atom action_id, DictRef tactical_order) {
	const Atom tactical_action = text_of(state, tactical_order, key::action, str(key::empty));
	if (tactical_action == key::cast_spell) {
		return action_id == gd::format(state, key::cast_spell_s, {str(text_of(state, tactical_order, key::spell_id, str(key::empty)))});
	}
	return action_id == tactical_action;
}

Atom _intent_forecast_target_label(State &state, Atom action_id, DictRef active_stack, DictRef target) {
	if (gd::begins_with(state, action_id, key::cast_spell_prefix_text)) {
		return !gd::is_empty(state, target) ? _stack_label(state, target) : static_cast<Atom>(key::spell_target);
	}
	if (is_attack_action(action_id)) {
		return !gd::is_empty(state, target) ? _stack_label(state, target) : static_cast<Atom>(key::selected_target);
	}
	if (action_id == key::advance) {
		return !gd::is_empty(state, target) ? _stack_label(state, target) : static_cast<Atom>(key::nearest_lane_2);
	}
	if (action_id == key::defend || action_id == key::wait) {
		return !gd::is_empty(state, active_stack) ? _stack_label(state, active_stack) : static_cast<Atom>(key::active_stack_text);
	}
	if (action_id == key::retreat || action_id == key::surrender) {
		return key::whole_army_2;
	}
	return key::empty;
}

Atom _intent_forecast_expected_result(State &state, Atom action_id, DictRef session, DictRef battle, DictRef active_stack, DictRef target, DictRef action) {
	if (gd::begins_with(state, action_id, key::cast_spell_prefix_text)) {
		const Atom spell_effect = gd::strip_edges(state, text_of(state, action, key::effect, str(key::empty)));
		if (spell_effect != key::empty) {
			return trim_suffix(state, spell_effect, key::period);
		}
		return trim_suffix(state, gd::strip_edges(state, text_of(state, action, key::summary, str(key::casting_resolves_the_selected_spell_consequence))), key::period);
	}
	if (is_attack_action(action_id) && !gd::is_empty(state, active_stack) && !gd::is_empty(state, target)) {
		return trim_suffix(state, _attack_action_summary(state, active_stack, target, battle, action_id == key::shoot), key::period);
	}
	if (action_id == key::advance) {
		return _intent_forecast_advance_result(state, battle, active_stack);
	}
	if (action_id == key::defend) {
		return trim_suffix(state, _defend_action_summary(state, battle, active_stack), key::period);
	}
	if (action_id == key::retreat) {
		return trim_suffix(state, _retreat_action_summary(state, dict_value(session)), key::period);
	}
	if (action_id == key::surrender) {
		return trim_suffix(state, _surrender_action_summary(state, dict_value(session)), key::period);
	}
	const Atom consequence = gd::strip_edges(state, text_of(state, action, key::consequence, state.get(action, str(key::summary), str(key::empty))));
	return consequence != key::empty ? consequence : static_cast<Atom>(key::initiative_advances_after_the_order_resolves);
}

Atom _intent_forecast_advance_result(State &state, DictRef battle, DictRef active_stack) {
	const Atom summary = trim_suffix(state, _advance_action_summary(state, battle, active_stack), key::period);
	if (gd::int_field(state, battle, key::distance, 1) <= 0) {
		// summary.split(";", false)[0]: an empty split is GDScript's out of
		// bounds error.
		const gd::PackedRef pieces = gd::new_strings(state);
		for (const Atom piece : split_non_empty(state, summary, key::semicolon)) {
			gd::packed_append_string(state, pieces, piece);
		}
		return gd::strip_edges(state, gd::packed_string(state, pieces, 0));
	}
	std::vector<Atom> consequence_clauses;
	for (const Atom clause_value : split_non_empty(state, summary, key::space_bar_space)) {
		const Atom clause = gd::strip_edges(state, clause_value);
		if (lower_contains(state, clause, key::click, "BattleRules._intent_forecast_advance_result")) {
			continue;
		}
		if (clause != key::empty) {
			consequence_clauses.push_back(clause);
		}
	}
	return !consequence_clauses.empty() ? join(state, key::space_bar_space, consequence_clauses) : static_cast<Atom>(key::advance_changes_the_active_stack_s);
}

Atom _intent_forecast_sentence(State &state, Atom text) {
	const Atom cleaned = gd::strip_edges(state, text);
	if (cleaned == key::empty) {
		return key::empty;
	}
	const std::vector<Atom> split = split_non_empty(state, cleaned, key::period_space_text);
	if (split.empty()) {
		return trim_suffix(state, cleaned, key::period);
	}
	return trim_suffix(state, gd::strip_edges(state, split[0]), key::period);
}

Atom _intent_forecast_compact_result(State &state, Atom text, int64_t max_chars) {
	const Atom sentence = _intent_forecast_sentence(state, text);
	if (code_point_count(state.text(sentence)) <= max_chars) {
		return sentence;
	}
	std::vector<Atom> selected_clauses;
	for (const Atom clause_value : split_non_empty(state, sentence, key::space_bar_space)) {
		const Atom clause = gd::strip_edges(state, clause_value);
		if (clause == key::empty) {
			continue;
		}
		std::vector<Atom> candidate_parts = selected_clauses;
		candidate_parts.push_back(clause);
		if (code_point_count(join_text(state, key::space_bar_space, candidate_parts)) <= max_chars) {
			selected_clauses.push_back(clause);
			continue;
		}
		if (selected_clauses.empty()) {
			const std::string kept = left_code_points(state.text(clause), compat::engine_max<int64_t>(1, gd::sub(max_chars, 3)));
			return gd::format(state, key::s_5, {str(state.intern(kept))});
		}
		break;
	}
	return join(state, key::space_bar_space, selected_clauses);
}

Atom _intent_forecast_confidence_line(State &state, DictRef tactical_order, Atom action_id) {
	const DictRef scores = dict_entry(state, tactical_order, key::candidate_scores);
	if (gd::is_empty(state, scores)) {
		return key::manual_order_surface_no_score_spread;
	}
	double chosen_score = -99999.0;
	double next_score = -99999.0;
	const Atom score_action_id = gd::begins_with(state, action_id, key::cast_spell_prefix_text) ? static_cast<Atom>(key::cast_spell) : action_id;
	const ArrayRef score_keys = gd::keys(state, scores);
	for (const Value &key_value : gd::items(state, array_value(score_keys))) {
		const Atom key_text = string_of(state, key_value);
		const double score = gd::to_float(state.get(scores, key_value, float_value(0.0)));
		if (key_text == score_action_id) {
			chosen_score = score;
		} else if (score > next_score) {
			next_score = score;
		}
	}
	if (chosen_score <= -99998.0) {
		return key::fallback_from_scored_order_selected_action;
	}
	if (next_score <= -99998.0) {
		return gd::engine_format(state, key::single_scored_option_at_1f, {float_value(chosen_score)});
	}
	const double margin = chosen_score - next_score;
	Atom band = key::close;
	if (margin >= 3.0) {
		band = key::strong;
	} else if (margin >= 1.0) {
		band = key::clear;
	}
	return gd::engine_format(state, key::s_scored_pick_1f_vs_next, {str(band), float_value(chosen_score), float_value(next_score)});
}

Atom _manual_battle_action_cue(State &state, DictRef actions, DictRef click_intent, DictRef movement_intent) {
	const Atom click_action = text_of(state, click_intent, key::action, str(key::empty));
	const Atom click_label = gd::strip_edges(state, text_of(state, click_intent, key::label, str(key::empty)));
	if (click_action != key::empty && click_label != key::empty) {
		const Atom lowered = ascii_lower(state, click_label, "BattleRules._manual_battle_action_cue");
		return gd::format(state, key::try_click_the_highlighted_target_to, {str(lowered), str(_action_button_label(state, actions, click_action))});
	}

	if (text_of(state, movement_intent, key::action, str(key::empty)) == key::move_) {
		const Atom ready_after_move = _first_ready_action_label(state, actions, string_array(state, {key::strike, key::shoot, key::advance, key::defend}));
		if (ready_after_move != key::empty) {
			return gd::format(state, key::try_click_a_move_hex_to, {str(ready_after_move)});
		}
		return key::try_click_a_move_hex_to_2;
	}

	const Atom ready_action = _first_ready_action_label(state, actions, string_array(state, {key::strike, key::shoot, key::advance, key::defend, key::retreat, key::surrender}));
	if (ready_action != key::empty) {
		return gd::format(state, key::try_click_s_for_the_next, {str(ready_action)});
	}
	return key::try_cycle_target_focus_or_wait;
}

Atom _action_button_label(State &state, DictRef actions, Atom action_id) {
	// actions.get(action_id, {}): a missing action is an empty Dictionary.
	Value action_value;
	const bool found = state.lookup(actions, str(action_id), action_value);
	if (!found || gd::is_dict(action_value)) {
		const Atom label = gd::strip_edges(state, found ? label_or_capitalized(state, action_value.ref, action_id) : gd::capitalize(state, action_id));
		if (label != key::empty) {
			return label;
		}
	}
	return gd::capitalize(state, action_id);
}

Atom _first_ready_action_label(State &state, DictRef actions, ArrayRef action_ids) {
	for (const Value &action_id_value : gd::items(state, array_value(action_ids))) {
		const Atom action_id = string_of(state, action_id_value);
		// actions.get(action_id, {}): a missing action is an empty Dictionary,
		// so it is ready.
		Value action_value;
		if (state.lookup(actions, str(action_id), action_value)) {
			if (!gd::is_dict(action_value)) {
				continue;
			}
			if (gd::bool_field(state, action_value.ref, key::disabled, false)) {
				continue;
			}
		}
		return _action_button_label(state, actions, action_id);
	}
	return key::empty;
}

DictRef _preferred_spell_timing_action(State &state, DictRef session, DictRef battle, DictRef active_stack, DictRef target) {
	DictRef best = state.new_dict();
	double best_score = -99999.0;
	const DictRef availability = action_availability(state, battle);
	const ArrayRef spell_actions = get_spell_actions(state, session);
	const state::ValueList actions = state.array(spell_actions).items;
	for (const Value &action : actions) {
		if (!gd::is_dict(action) || gd::bool_field(state, action.ref, key::disabled, false)) {
			continue;
		}
		const Atom spell_id = gd::trim_prefix(state, text_of(state, action.ref, key::id, str(key::empty)), key::cast_spell_prefix_text);
		const DictRef spell = gd::content_row(state, ContentTable::Spell, spell_id);
		if (gd::is_empty(state, spell)) {
			continue;
		}
		const double score = _spell_timing_action_score(state, battle, active_stack, target, spell, availability);
		if (gd::is_empty(state, best) || score > best_score) {
			best = action.ref;
			best_score = score;
		}
	}
	return best;
}

double _spell_timing_action_score(State &state, DictRef battle, DictRef active_stack, DictRef target, DictRef spell, DictRef availability) {
	Value effect;
	if (!state.lookup(spell, str(key::effect), effect)) {
		effect = dict_value(state.new_dict());
	}
	const Atom effect_type = string_of(state, ai::vget(state, effect, key::type, str(key::empty)));
	double score = 0.0;
	if (effect_type == key::damage_enemy) {
		score = 4.0;
		if (!gd::is_empty(state, target)) {
			score += 2.0;
			if (gd::bool_field(state, target, key::ranged, false)) {
				score += 1.0;
			}
			if (_health_ratio(state, target) <= 0.75) {
				score += 1.0;
			}
		}
		const Value status_effect = ai::vget(state, effect, key::status_effect, dict_value(state.new_dict()));
		const Atom effect_id = string_of(state, ai::vget(state, status_effect, key::effect_id, ai::vget(state, status_effect, key::status_id, str(key::empty))));
		if (effect_id != key::empty && !gd::is_empty(state, target) && !spell_rules::has_effect_id(state, target, battle, effect_id)) {
			score += 1.5;
		}
	} else if (effect_type == key::control_enemy) {
		score = 3.5;
		if (!gd::is_empty(state, target)) {
			score += 1.5;
			if (_stack_cohesion_total(state, target, battle) <= 5) {
				score += 1.0;
			}
		}
		const Value control_effect = ai::vget(state, effect, key::status_effect, dict_value(state.new_dict()));
		const Atom control_effect_id = string_of(state, ai::vget(state, control_effect, key::effect_id, ai::vget(state, control_effect, key::status_id, str(key::empty))));
		if (control_effect_id != key::empty && !gd::is_empty(state, target) && !spell_rules::has_effect_id(state, target, battle, control_effect_id)) {
			score += 2.0;
		}
	} else if (effect_type == key::recover_ally) {
		score = 2.5;
		if (_health_ratio(state, active_stack) <= 0.65) {
			score += 3.0;
		}
		if (_stack_cohesion_total(state, active_stack, battle) <= 5) {
			score += 1.0;
		}
	} else if (effect_type == key::cleanse_ally) {
		score = 2.5;
		if (spell_rules::has_any_effect_ids(state, active_stack, battle, ai::vget(state, effect, key::cleanse_effect_ids, array_value(state.new_array())))) {
			score += 4.0;
		}
		if (_stack_cohesion_total(state, active_stack, battle) <= 5) {
			score += 1.0;
		}
	} else if (effect_type == key::defense_buff) {
		score = 2.0;
		if (_stack_cohesion_total(state, active_stack, battle) <= 5) {
			score += 2.5;
		}
		if (_stack_is_isolated(state, battle, active_stack)) {
			score += 1.5;
		}
		if (gd::int_field(state, battle, key::distance, 1) <= 0 || gd::bool_field(state, active_stack, key::defending, false)) {
			score += 1.0;
		}
	} else if (effect_type == key::initiative_buff) {
		score = 2.0;
		if (gd::int_field(state, battle, key::round, 1) <= 2) {
			score += 1.5;
		}
		if (gd::bool_field(state, active_stack, key::ranged, false) && gd::int_field(state, active_stack, key::shots_remaining, 0) > 0) {
			score += 1.5;
		}
		if (!gd::bool_field(state, active_stack, key::ranged, false) && gd::int_field(state, battle, key::distance, 1) > 0) {
			score += 1.5;
		}
	} else if (effect_type == key::attack_buff) {
		score = 2.0;
		if (gd::bool_field(state, active_stack, key::ranged, false) && gd::int_field(state, active_stack, key::shots_remaining, 0) > 0) {
			score += 2.0;
		}
		if (gd::bool_field(state, availability, key::shoot, false) || gd::bool_field(state, availability, key::strike, false)) {
			score += 1.5;
		}
		if (!gd::is_empty(state, target) && _health_ratio(state, target) <= 0.75) {
			score += 1.0;
		}
	}
	return score;
}

} // namespace battle_rules

} // namespace aurelion::rules::port
