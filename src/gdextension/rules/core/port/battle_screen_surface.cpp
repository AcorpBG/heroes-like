// BattleRules for the battle screen (Phase 7, slice 7.9): the action surface,
// the post-action lines and the presented action.

#include "aurelion_rules/port/battle_screen.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/spell_rules.hpp"

#include <algorithm>
#include <string>
#include <vector>

namespace aurelion::rules::port {

namespace {

using gd::array_value;
using gd::ArrayRef;
using gd::Atom;
using gd::bool_value;
using gd::dict_value;
using gd::DictRef;
using gd::int_value;
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

// String(d.get(field, fallback)).
Atom text_or(State &state, DictRef dict, Atom field, Atom fallback) {
	return string_of(state, state.get(dict, str(field), str(fallback)));
}

// session.battle: SessionData types it Dictionary.
DictRef session_battle(State &state, DictRef session) {
	return gd::as_dict(gd::index(state, session, str(key::battle)));
}

// d.get(field, {}) if d.get(field, {}) is Dictionary else {}.
DictRef dict_or_empty(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found) && gd::is_dict(found)) {
		return found.ref;
	}
	return state.new_dict();
}

// a + b of Strings.
Atom concat(State &state, Atom a, Atom b) {
	return state.intern(state.text(a) + state.text(b));
}

// text.trim_suffix(suffix).
Atom trim_suffix(State &state, Atom text, Atom suffix) {
	if (!gd::ends_with(state, text, suffix)) {
		return text;
	}
	const std::string source = state.text(text);
	return state.intern(source.substr(0, source.size() - state.text(suffix).size()));
}

// sep.join(parts) of an Array of Strings.
Atom join_array(State &state, Atom separator, ArrayRef parts) {
	std::string joined;
	const int64_t size = state.array_size(parts);
	for (int64_t index = 0; index < size; ++index) {
		if (index > 0) {
			joined += state.text(separator);
		}
		joined += state.text(gd::stringify(state, state.at(parts, index)));
	}
	return state.intern(joined);
}

// s.to_lower() of ASCII text (_distance_label's texts; other text: the Unicode
// case tables are not ported).
Atom lower_ascii(State &state, Atom text, const char *where) {
	std::string lowered = state.text(text);
	bool changed = false;
	for (char &c : lowered) {
		if (static_cast<unsigned char>(c) >= 0x80) {
			throw state::NotPorted(std::string(where) + ": to_lower() of non-ASCII text");
		}
		if (c >= 'A' && c <= 'Z') {
			c = static_cast<char>(c - 'A' + 'a');
			changed = true;
		}
	}
	return changed ? state.intern(lowered) : text;
}

// String(message.split(". ", false)[0]) (String::split without empty pieces):
// the first non-empty piece.
Atom first_split_piece(State &state, Atom message) {
	const std::string text = state.text(message);
	size_t from = 0;
	while (true) {
		size_t end = text.find(". ", from);
		if (end == std::string::npos) {
			end = text.size();
		}
		if (end > from) {
			return state.intern(text.substr(from, end - from));
		}
		if (end == text.size()) {
			break;
		}
		from = end + 2;
	}
	throw state::ScriptError("Out of bounds get index '0' (on base: 'PackedStringArray')");
}

// surface[action_id] = {"label": label, "disabled": disabled, "summary": summary}
DictRef surface_entry(State &state, DictRef surface, Atom action_id, Atom label, bool disabled, Atom summary) {
	const DictRef entry = state.new_dict();
	state.set(entry, str(key::label), str(label));
	state.set(entry, str(key::disabled), bool_value(disabled));
	state.set(entry, str(key::summary), str(summary));
	state.set(surface, str(action_id), dict_value(entry));
	return entry;
}

// {"ok": false, "state": "invalid", "message": "No battle is active."}
DictRef no_battle_result(State &state) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(false));
	state.set(result, str(key::state), str(key::invalid));
	state.set(result, str(key::message), str(key::no_battle_is_active_text));
	return result;
}

} // namespace

namespace battle_rules {

DictRef get_action_surface(State &state, DictRef session) {
	const DictRef surface = state.new_dict();
	if (gd::is_empty(state, session_battle(state, session))) {
		return surface;
	}
	const DictRef battle = session_battle(state, session);
	const DictRef active_stack = get_active_stack(state, battle);
	const DictRef target = get_selected_target(state, battle);
	const DictRef availability = action_availability(state, battle);
	const bool player_turn = !gd::is_empty(state, active_stack) && text_or(state, active_stack, key::side, key::empty) == key::player;
	const Atom locked_summary = _player_input_locked_summary(state);

	Atom advance_summary = locked_summary;
	if (player_turn) {
		advance_summary = gd::bool_field(state, availability, key::advance, false) ? _advance_action_summary(state, battle, active_stack) : static_cast<Atom>(key::the_lines_are_already_engaged);
	}
	const DictRef advance = surface_entry(state, surface, key::advance, key::Advance,
			!player_turn || !gd::bool_field(state, availability, key::advance, false), advance_summary);
	_enrich_action_surface_entry(state, advance, key::advance, session, battle, active_stack, target, availability);

	Atom strike_summary = locked_summary;
	if (player_turn) {
		strike_summary = gd::bool_field(state, availability, key::strike, false) ? _attack_action_summary(state, active_stack, target, battle, false) : _attack_unavailable_summary(state, active_stack, target, battle, false);
	}
	const DictRef strike = surface_entry(state, surface, key::strike, key::Strike,
			!player_turn || !gd::bool_field(state, availability, key::strike, false), strike_summary);
	_enrich_action_surface_entry(state, strike, key::strike, session, battle, active_stack, target, availability);

	Atom shoot_summary = locked_summary;
	if (player_turn) {
		shoot_summary = gd::bool_field(state, availability, key::shoot, false) ? _attack_action_summary(state, active_stack, target, battle, true) : _attack_unavailable_summary(state, active_stack, target, battle, true);
	}
	const DictRef shoot = surface_entry(state, surface, key::shoot, key::Shoot,
			!player_turn || !gd::bool_field(state, availability, key::shoot, false), shoot_summary);
	_enrich_action_surface_entry(state, shoot, key::shoot, session, battle, active_stack, target, availability);

	{
		const bool disabled = !player_turn || !gd::bool_field(state, availability, key::defend, false);
		const Atom summary = !player_turn ? locked_summary : _defend_action_summary(state, battle, active_stack);
		const DictRef defend = surface_entry(state, surface, key::defend, key::Defend, disabled, summary);
		_enrich_action_surface_entry(state, defend, key::defend, session, battle, active_stack, target, availability);
	}
	{
		const bool disabled = !player_turn || !gd::bool_field(state, availability, key::wait, false);
		const Atom summary = !player_turn ? locked_summary : _wait_action_summary(state, battle, active_stack);
		const DictRef wait = surface_entry(state, surface, key::wait, key::Wait, disabled, summary);
		_enrich_action_surface_entry(state, wait, key::wait, session, battle, active_stack, target, availability);
	}

	Atom retreat_summary = locked_summary;
	if (player_turn) {
		retreat_summary = _retreat_action_summary(state, dict_value(session));
	}
	const DictRef retreat = surface_entry(state, surface, key::retreat, key::Retreat,
			!player_turn || !gd::bool_field(state, availability, key::retreat, false), retreat_summary);
	_enrich_action_surface_entry(state, retreat, key::retreat, session, battle, active_stack, target, availability);

	Atom surrender_summary = locked_summary;
	if (player_turn) {
		surrender_summary = _surrender_action_summary(state, dict_value(session));
	}
	const DictRef surrender = surface_entry(state, surface, key::surrender, key::Surrender,
			!player_turn || !gd::bool_field(state, availability, key::surrender, false), surrender_summary);
	_enrich_action_surface_entry(state, surrender, key::surrender, session, battle, active_stack, target, availability);
	return surface;
}

void _enrich_action_surface_entry(State &state, DictRef action, Atom action_id, DictRef session, DictRef battle, DictRef active_stack, DictRef target, DictRef availability) {
	const bool ready = text_or(state, active_stack, key::side, key::empty) == key::player && gd::bool_field(state, availability, action_id, false);
	state.set(action, str(key::readiness), str(ready ? key::Ready : key::Blocked));
	const Atom target_label = _action_target_label(state, action_id, active_stack, target, battle);
	state.set(action, str(key::target), str(target_label));
	const Atom range = _action_range_line(state, action_id, active_stack, target, battle);
	state.set(action, str(key::range), str(range));
	const Atom why = _action_why_line(state, action_id, session, battle, active_stack, target, ready);
	state.set(action, str(key::why), str(why));
	const Atom consequence = _action_consequence_line(state, action_id, session, battle, active_stack, target, action);
	state.set(action, str(key::consequence), str(consequence));
	const Atom confirmation = _action_confirmation_line(state, action_id, active_stack, target, action);
	state.set(action, str(key::confirmation), str(confirmation));
	const Atom tooltip = _compact_action_tooltip(state, action);
	state.set(action, str(key::tooltip), str(tooltip));
}

Atom _compact_action_tooltip(State &state, DictRef action) {
	std::vector<Atom> lines;
	{
		const Atom label = text_or(state, action, key::label, key::Order);
		const Atom readiness = text_or(state, action, key::readiness, key::empty);
		lines.push_back(gd::format(state, key::s_s_text, { str(label), str(readiness) }));
	}
	lines.push_back(text_or(state, action, key::summary, key::empty));
	{
		const Atom target = text_or(state, action, key::target, key::empty);
		const Atom range = text_or(state, action, key::range, key::empty);
		lines.push_back(gd::format(state, key::target_range_s_s, { str(target), str(range) }));
	}
	lines.push_back(gd::format(state, key::why_s, { str(text_or(state, action, key::why, key::empty)) }));
	lines.push_back(gd::format(state, key::consequence_s, { str(text_or(state, action, key::consequence, key::empty)) }));
	lines.push_back(gd::format(state, key::confirm_s, { str(text_or(state, action, key::confirmation, key::empty)) }));
	const ArrayRef compact = state.new_array();
	for (const Atom line_value : lines) {
		const Atom line = gd::strip_edges(state, line_value);
		if (line != key::empty) {
			state.append(compact, str(line));
		}
	}
	return join_array(state, key::newline, compact);
}

Atom _action_confirmation_line(State &state, Atom action_id, DictRef active_stack, DictRef target, DictRef action) {
	if (gd::is_empty(state, active_stack) || text_or(state, active_stack, key::side, key::empty) != key::player) {
		return key::input_is_locked_until_command_returns;
	}
	const Atom label = text_or(state, action, key::label, gd::capitalize(state, action_id));
	if (gd::bool_field(state, action, key::disabled, false)) {
		return gd::format(state, key::s_is_not_ready_from_this, { str(label) });
	}
	if (action_id == key::strike || action_id == key::shoot) {
		const Atom target_label = !gd::is_empty(state, target) ? _stack_label(state, target) : static_cast<Atom>(key::the_selected_target);
		return gd::format(state, key::s_s_this_stack_spends_its, { str(label), str(target_label) });
	}
	if (action_id == key::advance) {
		return key::move_this_stack_on_the_tactical;
	}
	if (action_id == key::defend) {
		return key::brace_in_place_until_this_stack;
	}
	if (action_id == key::wait) {
		return key::step_out_of_the_order_this;
	}
	if (action_id == key::retreat) {
		return key::leave_the_field_and_route_back;
	}
	if (action_id == key::surrender) {
		return key::concede_the_field_under_surrender_terms;
	}
	return key::confirm_this_order_initiative_advances_after;
}

Atom _action_target_label(State &state, Atom action_id, DictRef active_stack, DictRef target, DictRef battle) {
	(void)battle;
	if (action_id == key::strike || action_id == key::shoot) {
		return !gd::is_empty(state, target) ? _stack_label(state, target) : static_cast<Atom>(key::select_an_enemy);
	}
	if (action_id == key::advance) {
		if (!gd::is_empty(state, target)) {
			return gd::format(state, key::close_toward_s, { str(_stack_label(state, target)) });
		}
		return key::nearest_lane;
	}
	if (action_id == key::defend || action_id == key::wait) {
		return !gd::is_empty(state, active_stack) ? _stack_label(state, active_stack) : static_cast<Atom>(key::active_stack_2);
	}
	if (action_id == key::retreat || action_id == key::surrender) {
		return key::whole_army;
	}
	return key::battle_line;
}

Atom _action_range_line(State &state, Atom action_id, DictRef active_stack, DictRef target, DictRef battle) {
	if (gd::is_empty(state, active_stack)) {
		return key::no_active_stack;
	}
	if (action_id == key::strike) {
		if (gd::is_empty(state, target)) {
			return key::needs_target;
		}
		const DictRef legality = _attack_legality_for_target(state, active_stack, target, battle);
		if (gd::bool_field(state, legality, key::melee, false)) {
			return gd::format(state, key::melee_ready_at_hex_range_d, { int_value(gd::int_field(state, legality, key::hex_distance, -1)) });
		}
		if (_reach_available(state, active_stack, battle) || _hookline_available(state, active_stack, battle)) {
			return key::chain_reach_needs_hex_range_2;
		}
		return key::needs_adjacent_contact;
	}
	if (action_id == key::shoot) {
		if (!gd::bool_field(state, active_stack, key::ranged, false)) {
			return key::no_ranged_attack;
		}
		if (gd::is_empty(state, target)) {
			return key::needs_target;
		}
		const DictRef ranged_legality = _attack_legality_for_target(state, active_stack, target, battle);
		if (gd::bool_field(state, ranged_legality, key::ranged, false)) {
			const Atom distance = _distance_label(state, _attack_distance_for_action(state, active_stack, target, battle, true));
			return gd::format(state, key::fire_lane_ready_at_s, { str(lower_ascii(state, distance, "BattleRules._action_range_line")) });
		}
		return key::fire_lane_blocked;
	}
	if (action_id == key::advance) {
		const ArrayRef destinations = legal_destinations_for_active_stack(state, battle);
		if (state.array_size(destinations) == 0 && gd::int_field(state, battle, key::distance, 1) <= 0) {
			return key::no_move_lane;
		}
		const Atom distance = _distance_label(state, gd::int_field(state, battle, key::distance, 1));
		const int64_t count = state.array_size(destinations);
		return gd::format(state, key::s_d_move_hex_s, { str(distance), int_value(count), str(count == 1 ? static_cast<Atom>(key::empty) : static_cast<Atom>(key::es)) });
	}
	if (action_id == key::defend || action_id == key::wait) {
		return key::current_hex;
	}
	if (action_id == key::retreat || action_id == key::surrender) {
		return key::exit_order;
	}
	return _distance_label(state, gd::int_field(state, battle, key::distance, 1));
}

Atom _action_why_line(State &state, Atom action_id, DictRef session, DictRef battle, DictRef active_stack, DictRef target, bool ready) {
	if (gd::is_empty(state, active_stack) || text_or(state, active_stack, key::side, key::empty) != key::player) {
		return _player_input_locked_summary(state);
	}
	if (action_id == key::strike) {
		if (gd::is_empty(state, target)) {
			return key::melee_pressure_needs_a_selected_enemy;
		}
		if (ready) {
			const Atom melee_ability = _active_ability_window_summary(state, active_stack, battle, target);
			return melee_ability != key::empty ? melee_ability : static_cast<Atom>(key::this_trades_damage_now_and_can);
		}
		return _attack_unavailable_summary(state, active_stack, target, battle, false);
	}
	if (action_id == key::shoot) {
		if (gd::is_empty(state, target)) {
			return key::ranged_pressure_needs_a_selected_enemy;
		}
		if (ready) {
			const Atom ranged_ability = _active_ability_window_summary(state, active_stack, battle, target);
			return ranged_ability != key::empty ? ranged_ability : static_cast<Atom>(key::this_spends_a_shot_to_soften);
		}
		return _attack_unavailable_summary(state, active_stack, target, battle, true);
	}
	if (action_id == key::advance) {
		if (ready) {
			if (!gd::is_empty(state, target) && gd::bool_field(state, _attack_legality_for_target(state, active_stack, target, battle), key::blocked, false)) {
				return key::movement_turns_the_selected_target_from;
			}
			return key::closing_changes_range_threatens_contact_and;
		}
		return key::the_line_is_already_engaged_or;
	}
	if (action_id == key::defend) {
		// The ternary calls the summary twice when it is not empty.
		if (_active_ability_window_summary(state, active_stack, battle, target) != key::empty) {
			return _active_ability_window_summary(state, active_stack, battle, target);
		}
		return key::bracing_buys_cohesion_and_keeps_retaliation;
	}
	if (action_id == key::wait) {
		return ready ? static_cast<Atom>(key::waiting_lets_the_enemy_move_first) : _wait_action_summary(state, battle, active_stack);
	}
	if (action_id == key::retreat) {
		return ready ? static_cast<Atom>(key::withdrawal_preserves_survivors_but_yields_this) : _retreat_action_summary(state, dict_value(session));
	}
	if (action_id == key::surrender) {
		return ready ? static_cast<Atom>(key::surrender_preserves_what_terms_allow_while) : _surrender_action_summary(state, dict_value(session));
	}
	return key::this_order_changes_the_next_exchange;
}

Atom _action_consequence_line(State &state, Atom action_id, DictRef session, DictRef battle, DictRef active_stack, DictRef target, DictRef action) {
	(void)session;
	const Atom summary = gd::strip_edges(state, text_or(state, action, key::summary, key::empty));
	Atom objective_preview = key::empty;
	if (!gd::is_empty(state, active_stack) && text_or(state, active_stack, key::side, key::empty) == key::player) {
		const DictRef action_context = state.new_dict();
		state.set(action_context, str(key::action), str(action_id));
		state.set(action_context, str(key::side), str(key::player));
		state.set(action_context, str(key::battle_id), str(text_or(state, active_stack, key::battle_id, key::empty)));
		state.set(action_context, str(key::target_battle_id), str(text_or(state, target, key::battle_id, key::empty)));
		objective_preview = _field_objective_action_preview(state, battle, action_context);
	}
	if (objective_preview != key::empty) {
		return objective_preview;
	}
	if ((action_id == key::strike || action_id == key::shoot) && !gd::is_empty(state, target) && !gd::bool_field(state, action, key::disabled, false)) {
		return _attack_action_summary(state, active_stack, target, battle, action_id == key::shoot);
	}
	if (action_id == key::defend && !gd::is_empty(state, active_stack)) {
		return gd::format(state, key::cohesion_can_rise_by_d_status, { int_value(_preview_defend_cohesion_gain(state, active_stack, battle)) });
	}
	if (action_id == key::advance) {
		return _advance_action_summary(state, battle, active_stack);
	}
	if (summary != key::empty) {
		return summary;
	}
	return key::no_immediate_consequence_preview;
}

ArrayRef _action_consequence_preview_list(State &state, DictRef surface) {
	const ArrayRef previews = state.new_array();
	constexpr Atom action_ids[] = { key::advance, key::strike, key::shoot, key::defend, key::retreat, key::surrender };
	for (const Atom action_id : action_ids) {
		Value action_value;
		if (!state.lookup(surface, str(action_id), action_value)) {
			action_value = dict_value(state.new_dict()); // the default {}
		}
		if (!gd::is_dict(action_value)) {
			continue;
		}
		const DictRef action = action_value.ref;
		const DictRef preview = state.new_dict();
		state.set(preview, str(key::id), str(action_id));
		state.set(preview, str(key::label), str(text_or(state, action, key::label, gd::capitalize(state, action_id))));
		state.set(preview, str(key::readiness), str(text_or(state, action, key::readiness, key::empty)));
		state.set(preview, str(key::target), str(text_or(state, action, key::target, key::empty)));
		state.set(preview, str(key::range), str(text_or(state, action, key::range, key::empty)));
		state.set(preview, str(key::why), str(text_or(state, action, key::why, key::empty)));
		state.set(preview, str(key::consequence), str(text_or(state, action, key::consequence, key::empty)));
		state.append(previews, dict_value(preview));
	}
	return previews;
}

Atom _post_action_happened_line(State &state, DictRef result, Atom action_id) {
	const Atom message = gd::strip_edges(state, text_or(state, result, key::message, key::empty));
	if (message == key::empty) {
		return gd::format(state, key::s_resolved, { str(_post_action_label(state, action_id)) });
	}
	Atom happened = gd::strip_edges(state, first_split_piece(state, message));
	if (happened != key::empty && !gd::ends_with(state, happened, key::period) && !gd::ends_with(state, happened, key::exclamation)
			&& !gd::ends_with(state, happened, key::question)) {
		happened = concat(state, happened, key::period);
	}
	return happened;
}

Atom _post_action_affected_line(State &state, DictRef battle, DictRef result, Atom action_id, DictRef context) {
	const Atom attack_target_id = text_or(state, result, key::attack_target_battle_id, key::empty);
	if (attack_target_id != key::empty) {
		const Value name_fallback = gd::field_or(state, context, key::target_name, str(key::Target));
		const Atom target_name = string_of(state, gd::field_or(state, result, key::attack_target_name, name_fallback));
		const int64_t count_before = gd::int_field(state, context, key::target_count_before, 0);
		const int64_t health_before = gd::int_field(state, context, key::target_health_before, 0);
		return _post_action_stack_delta_line(state, battle, attack_target_id, target_name, count_before, health_before);
	}

	Value movement_value;
	if (state.lookup(result, str(key::movement_intent), movement_value) && gd::is_dict(movement_value) && !gd::is_empty(state, movement_value.ref)) {
		const DictRef movement_intent = movement_value.ref;
		const Value mover_fallback = gd::field_or(state, context, key::active_battle_id, str(key::empty));
		const Atom mover_id = string_of(state, gd::field_or(state, movement_intent, key::active_battle_id, mover_fallback));
		const Value destination_fallback = gd::field_or(state, movement_intent, key::destination_label, str(key::empty));
		const Atom destination = string_of(state, gd::field_or(state, movement_intent, key::destination_detail, destination_fallback));
		const Value name_fallback = gd::field_or(state, context, key::active_name, str(key::acting_stack));
		const Atom mover_name = string_of(state, gd::field_or(state, movement_intent, key::active_stack_name, name_fallback));
		const int64_t count_before = gd::int_field(state, context, key::active_count_before, 0);
		const int64_t health_before = gd::int_field(state, context, key::active_health_before, 0);
		const Atom mover_line = _post_action_stack_delta_line(state, battle, mover_id, mover_name, count_before, health_before);
		if (destination != key::empty) {
			return gd::format(state, key::s_position_s, { str(trim_suffix(state, mover_line, key::period)), str(destination) });
		}
		return mover_line;
	}

	const Atom actor_id = text_or(state, context, key::active_battle_id, key::empty);
	const Atom actor_name = text_or(state, context, key::active_name, key::acting_stack);
	if (action_id == key::defend) {
		const Atom status = _post_action_status_after(state, battle, actor_id, text_or(state, context, key::active_status_before, key::empty));
		return gd::format(state, key::s_braced_s, { str(actor_name), str(status) });
	}
	if (action_id == key::advance) {
		const int64_t count_before = gd::int_field(state, context, key::active_count_before, 0);
		const int64_t health_before = gd::int_field(state, context, key::active_health_before, 0);
		return _post_action_stack_delta_line(state, battle, actor_id, actor_name, count_before, health_before);
	}
	const Atom target_id = text_or(state, context, key::target_battle_id, key::empty);
	if (target_id != key::empty) {
		const Atom target_name = text_or(state, context, key::target_name, key::Target);
		const int64_t count_before = gd::int_field(state, context, key::target_count_before, 0);
		const int64_t health_before = gd::int_field(state, context, key::target_health_before, 0);
		return _post_action_stack_delta_line(state, battle, target_id, target_name, count_before, health_before);
	}
	return gd::format(state, key::s_resolved_battlefield_status_updated, { str(_post_action_label(state, action_id)) });
}

Atom _post_action_stack_delta_line(State &state, DictRef battle, Atom battle_id, Atom fallback_name, int64_t count_before, int64_t health_before) {
	const DictRef stack = _get_stack_by_id(state, battle, battle_id);
	if (gd::is_empty(state, stack) || _alive_count(state, stack) <= 0) {
		if (count_before > 0 || health_before > 0) {
			return gd::format(state, key::s_removed_from_the_field, { str(fallback_name) });
		}
		return gd::format(state, key::s_changed_state, { str(fallback_name) });
	}
	const int64_t count_after = _alive_count(state, stack);
	const int64_t health_after = gd::int_field(state, stack, key::total_health, 0);
	const int64_t count_delta = gd::sub(count_after, count_before);
	const int64_t health_delta = gd::sub(health_after, health_before);
	const ArrayRef delta_parts = state.new_array();
	if (count_before > 0 && count_delta != 0) {
		const Atom sign = count_delta > 0 ? static_cast<Atom>(key::plus) : static_cast<Atom>(key::empty);
		state.append(delta_parts, str(gd::format(state, key::x_s_d, { str(sign), int_value(count_delta) })));
	}
	if (health_before > 0 && health_delta != 0) {
		const Atom sign = health_delta > 0 ? static_cast<Atom>(key::plus) : static_cast<Atom>(key::empty);
		state.append(delta_parts, str(gd::format(state, key::s_d_hp, { str(sign), int_value(health_delta) })));
	}
	const Atom delta_text = state.array_size(delta_parts) != 0
			? gd::format(state, key::space_bar_space_s, { str(join_array(state, key::comma_space, delta_parts)) })
			: static_cast<Atom>(key::empty);
	const Atom label = _stack_label(state, stack);
	const Atom hex = _hex_label(state, _stack_hex(state, stack));
	const Atom status = _stack_status_pressure_short(state, stack, battle);
	return gd::format(state, key::s_x_d_d_hp_at,
			{ str(label), int_value(count_after), int_value(health_after), str(hex), str(delta_text), str(status) });
}

Atom _post_action_status_after(State &state, DictRef battle, Atom battle_id, Atom fallback_status) {
	const DictRef stack = _get_stack_by_id(state, battle, battle_id);
	if (!gd::is_empty(state, stack) && _alive_count(state, stack) > 0) {
		return _stack_status_pressure_short(state, stack, battle);
	}
	return fallback_status != key::empty ? fallback_status : static_cast<Atom>(key::status_pressure_updated);
}

Atom _post_action_decision_line(State &state, DictRef session, DictRef result, DictRef context) {
	(void)context;
	const Atom result_state = text_or(state, result, key::state, key::continue_);
	if (result_state != key::empty && result_state != key::continue_) {
		return gd::format(state, key::battle_result_is_s_routing_follows, { str(gd::replace(state, result_state, key::_, key::space)) });
	}
	if (gd::is_empty(state, session_battle(state, session))) {
		return key::battlefield_state_changed_check_the_return;
	}
	const DictRef battle = session_battle(state, session);
	const DictRef active_stack = get_active_stack(state, battle);
	if (gd::is_empty(state, active_stack)) {
		return key::no_stack_is_ready_resolution_will;
	}
	if (text_or(state, active_stack, key::side, key::empty) != key::player) {
		return gd::format(state, key::s_has_initiative_expect_enemy_pressure, { str(_stack_label(state, active_stack)) });
	}
	const DictRef target = get_selected_target(state, battle);
	const DictRef click_intent = selected_target_board_click_intent(state, battle);
	const Atom action_label = text_or(state, click_intent, key::label, key::empty);
	if (action_label != key::empty && !gd::is_empty(state, target)) {
		return gd::format(state, key::s_can_s_s_now, { str(_stack_label(state, active_stack)), str(action_label), str(_stack_label(state, target)) });
	}
	const Atom target_range = gd::trim_prefix(state, _target_range_readiness_line(state, active_stack, target, battle), key::target_range);
	if (target_range != key::empty) {
		return gd::format(state, key::s_order_window_s, { str(_stack_label(state, active_stack)), str(target_range) });
	}
	return gd::format(state, key::s_has_command_choose_the_next, { str(_stack_label(state, active_stack)) });
}

Atom _post_action_next_actor_line(State &state, DictRef session) {
	if (gd::is_empty(state, session_battle(state, session))) {
		return key::battle_will_leave_the_tactical_field;
	}
	const DictRef active_stack = get_active_stack(state, session_battle(state, session));
	if (gd::is_empty(state, active_stack)) {
		return key::no_living_stack_is_queued;
	}
	const Atom label = _stack_label(state, active_stack);
	const Atom side = _side_label(text_or(state, active_stack, key::side, key::empty));
	const int64_t initiative = _stack_initiative_total(state, active_stack, session_battle(state, session));
	return gd::format(state, key::s_s_acts_now_at_init, { str(label), str(side), int_value(initiative) });
}

Atom _post_action_label(State &state, Atom action_id) {
	const Atom normalized = action_id;
	if (gd::begins_with(state, normalized, key::cast_spell_prefix_text)) {
		const DictRef spell = gd::content_row(state, ContentTable::Spell, gd::trim_prefix(state, normalized, key::cast_spell_prefix_text));
		return !gd::is_empty(state, spell) ? text_or(state, spell, key::name, key::spell_word) : static_cast<Atom>(key::spell_word);
	}
	if (normalized == key::shoot) {
		return key::Shot;
	}
	if (normalized == key::strike) {
		return key::Strike;
	}
	if (normalized == key::advance || normalized == key::move_) {
		return key::Move;
	}
	if (normalized == key::defend) {
		return key::Defend;
	}
	if (normalized == key::wait) {
		return key::Wait;
	}
	if (normalized == key::retreat) {
		return key::Retreat;
	}
	if (normalized == key::surrender) {
		return key::Surrender;
	}
	return key::Order;
}

ArrayRef animation_event_queue(State &state, DictRef battle) {
	Value queue;
	if (!state.lookup(battle, str(key::battle_animation_events), queue)) {
		queue = array_value(state.new_array()); // the default []
	}
	return _normalize_animation_event_queue(state, queue);
}

ArrayRef battle_presentation_event_stream(State &state, DictRef battle) {
	Value queue;
	if (!state.lookup(battle, str(key::battle_presentation_events), queue)) {
		queue = array_value(state.new_array()); // the default []
	}
	return _normalize_presentation_event_queue(state, queue);
}

Atom battle_presentation_speed(State &state, DictRef session) {
	if (gd::is_empty(state, session_battle(state, session))) {
		return key::normal;
	}
	return _normalize_presentation_speed(state, text_or(state, session_battle(state, session), key::battle_presentation_speed, key::normal));
}

DictRef set_battle_presentation_speed(State &state, DictRef session, Atom speed) {
	if (gd::is_empty(state, session_battle(state, session))) {
		const DictRef refused = state.new_dict();
		state.set(refused, str(key::ok), bool_value(false));
		state.set(refused, str(key::speed), str(key::normal));
		state.set(refused, str(key::message), str(key::no_battle_is_active_text));
		return refused;
	}
	const Atom normalized = _normalize_presentation_speed(state, speed);
	state.set(session_battle(state, session), str(key::battle_presentation_speed), str(normalized));
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(true));
	state.set(result, str(key::speed), str(normalized));
	state.set(result, str(key::message), str(gd::format(state, key::battle_playback_speed_set_to_s, { str(gd::capitalize(state, normalized)) })));
	return result;
}

int64_t battle_presentation_playback_msec(State &state, DictRef battle) {
	const Atom speed = _normalize_presentation_speed(state, text_or(state, battle, key::battle_presentation_speed, key::normal));
	if (speed == key::fast) {
		return 320;
	}
	if (speed == key::instant) {
		return 1;
	}
	return 760;
}

DictRef latest_animation_event_presentation_payload(State &state, DictRef session) {
	if (gd::is_empty(state, session_battle(state, session))) {
		return state.new_dict();
	}
	const DictRef event = _latest_animation_event(state, session_battle(state, session));
	if (gd::is_empty(state, event)) {
		return state.new_dict();
	}
	const DictRef battle = session_battle(state, session);
	const Atom battle_id = text_or(state, event, key::battle_id, key::empty);
	const DictRef actor = _get_stack_by_id(state, battle, battle_id);
	const DictRef source = _get_stack_by_id(state, battle, text_or(state, event, key::source_battle_id, key::empty));
	const DictRef target = _get_stack_by_id(state, battle, text_or(state, event, key::target_battle_id, key::empty));
	Atom actor_label = battle_id;
	if (is_hero_actor_id(state, battle_id)) {
		actor_label = battle_actor_label(state, battle, battle_id);
	} else if (!gd::is_empty(state, actor)) {
		actor_label = _stack_label(state, actor);
	}
	const Atom target_label = !gd::is_empty(state, target) ? _stack_label(state, target) : static_cast<Atom>(key::empty);
	const Atom source_id = text_or(state, event, key::source_battle_id, key::empty);
	Atom source_label = key::empty;
	if (is_hero_actor_id(state, source_id)) {
		source_label = battle_actor_label(state, battle, source_id);
	} else if (!gd::is_empty(state, source)) {
		source_label = _stack_label(state, source);
	}
	const Atom event_id = text_or(state, event, key::event_id, key::empty);
	Atom action_text = _animation_event_action_text(state, event_id, actor_label, source_label, target_label, event);
	if (action_text == key::empty) {
		action_text = gd::format(state, key::s_changes_posture, { str(actor_label) });
	}
	const Atom visible = gd::format(state, key::action_cue_s, { str(action_text) });
	const ArrayRef tooltip_lines = state.new_array();
	state.append(tooltip_lines, str(key::battle_presentation_event));
	state.append(tooltip_lines, str(gd::format(state, key::cue_s, { str(action_text) })));
	state.append(tooltip_lines, str(gd::format(state, key::actor_s, { str(actor_label) })));
	state.append(tooltip_lines, str(gd::format(state, key::event_s_2, { str(event_id) })));
	state.append(tooltip_lines, str(gd::format(state, key::state_s, { str(text_or(state, event, key::state, key::empty)) })));
	state.append(tooltip_lines, str(key::playback_board_motion_vfx_and_audio));
	if (source_label != key::empty) {
		state.append(tooltip_lines, str(gd::format(state, key::source_s, { str(source_label) })));
	}
	if (target_label != key::empty) {
		state.append(tooltip_lines, str(gd::format(state, key::target_s_2, { str(target_label) })));
	}
	const DictRef payload = state.new_dict();
	state.set(payload, str(key::ok), bool_value(true));
	state.set(payload, str(key::source), str(key::battle_animation_events));
	state.set(payload, str(key::visible_text), str(visible));
	state.set(payload, str(key::tooltip_text), str(join_array(state, key::newline, tooltip_lines)));
	state.set(payload, str(key::action_text), str(action_text));
	state.set(payload, str(key::event), gd::engine_duplicate(state, dict_value(event), true));
	state.set(payload, str(key::event_id), str(event_id));
	state.set(payload, str(key::state), str(text_or(state, event, key::state, key::empty)));
	state.set(payload, str(key::battle_id), str(battle_id));
	state.set(payload, str(key::actor_name), str(actor_label));
	state.set(payload, str(key::source_name), str(source_label));
	state.set(payload, str(key::target_name), str(target_label));
	state.set(payload, str(key::serial), int_value(gd::int_field(state, event, key::serial, 0)));
	state.set(payload, str(key::round), int_value(gd::int_field(state, event, key::round, 1)));
	state.set(payload, str(key::turn_index), int_value(gd::int_field(state, event, key::turn_index, 0)));
	return payload;
}

DictRef perform_presented_action(State &state, DictRef session, Atom action, DictRef destination) {
	if (gd::is_empty(state, session_battle(state, session))) {
		return no_battle_result(state);
	}
	const DictRef original_battle = session_battle(state, session);
	battle_action_playback::begin(state, original_battle);
	const Value session_value = dict_value(session);
	DictRef result;
	if (action == key::ready) {
		result = resolve_if_battle_ready(state, session_value);
		state.set(result, str(key::ok), bool_value(text_or(state, result, key::state, key::invalid) != key::invalid));
	} else if (action == key::move_) {
		const int64_t q = gd::int_field(state, destination, key::q, -1);
		const int64_t r = gd::int_field(state, destination, key::r, -1);
		result = move_active_stack_to_hex(state, session_value, q, r);
	} else if (gd::begins_with(state, action, key::cast_spell_prefix_text)) {
		const Atom spell_id = gd::trim_prefix(state, action, key::cast_spell_prefix_text);
		const Atom target_id = text_or(state, destination, key::target_id, key::empty);
		result = cast_player_spell(state, session_value, spell_id, target_id);
	} else {
		// A strike can name the hex to strike from as its destination.
		result = perform_player_action(state, session_value, action, action == key::strike ? destination : state.new_dict());
	}
	if (action != key::ready) {
		record_player_order(state, session_battle(state, session), result);
	}
	return battle_action_playback::finish(state, original_battle, result);
}

void record_player_order(State &state, DictRef battle, DictRef result) {
	if (gd::is_empty(state, battle) || text_or(state, result, key::state, key::invalid) == key::invalid) {
		return;
	}
	const int64_t given = std::max<int64_t>(0, gd::int_field(state, battle, key::player_orders_given, 0));
	state.set(battle, str(key::player_orders_given), int_value(gd::add(given, 1)));
}

bool player_has_given_orders(State &state, DictRef battle) {
	return gd::int_field(state, battle, key::player_orders_given, 0) > 0;
}

DictRef hero_presentation(State &state, DictRef battle, Atom side) {
	if (gd::is_empty(state, battle) || (side != key::player && side != key::enemy)) {
		return state.new_dict();
	}
	const DictRef commander_state = _commander_state_for_side(state, battle, side);
	if (gd::is_empty(state, commander_state)) {
		return state.new_dict();
	}
	Atom hero_id = key::empty;
	if (side == key::player) {
		const DictRef source = dict_or_empty(state, battle, key::player_commander_source);
		const Atom source_type = text_or(state, source, key::type, key::empty);
		if (source_type == key::active_hero || source_type == key::town_hero) {
			hero_id = gd::strip_edges(state, text_or(state, source, key::hero_id, key::empty));
			if (hero_id == key::empty) {
				hero_id = gd::strip_edges(state, text_or(state, commander_state, key::id, key::empty));
			}
		}
	} else {
		constexpr Atom candidate_keys[] = { key::roster_hero_id, key::hero_id, key::id };
		for (const Atom candidate_key : candidate_keys) {
			const Atom candidate = gd::strip_edges(state, text_or(state, commander_state, candidate_key, key::empty));
			if (candidate != key::empty && !gd::is_empty(state, gd::content_row(state, ContentTable::Hero, candidate))) {
				hero_id = candidate;
				break;
			}
		}
	}
	const DictRef hero_template = hero_id != key::empty ? gd::content_row(state, ContentTable::Hero, hero_id) : state.new_dict();
	if (gd::is_empty(state, hero_template)) {
		hero_id = key::empty;
	}
	const DictRef spellbook = dict_or_empty(state, commander_state, key::spellbook);
	const DictRef mana = dict_or_empty(state, spellbook, key::mana);
	const int64_t battle_spell_count = state.array_size(spell_rules::known_spells(state, commander_state, key::battle));
	const Atom name = commander_name(state, battle, side);

	const DictRef presentation = state.new_dict();
	state.set(presentation, str(key::side), str(side));
	state.set(presentation, str(key::actor_id), str(hero_actor_id(state, side)));
	const Atom fallback_name = side == key::player ? static_cast<Atom>(key::your_commander) : static_cast<Atom>(key::enemy_commander_2);
	state.set(presentation, str(key::name), str(name != key::empty ? name : fallback_name));
	state.set(presentation, str(key::hero_id), str(hero_id));
	{
		const Value faction_fallback = gd::field_or(state, hero_template, key::faction_id, str(key::empty));
		const Atom faction_id = gd::strip_edges(state, string_of(state, gd::field_or(state, commander_state, key::faction_id, faction_fallback)));
		state.set(presentation, str(key::faction_id), str(faction_id));
	}
	state.set(presentation, str(key::has_figure), bool_value(hero_id != key::empty));
	state.set(presentation, str(key::role), str(_commander_role_label(state, battle, side)));
	state.set(presentation, str(key::level), int_value(std::max<int64_t>(1, gd::int_field(state, commander_state, key::level, 1))));
	state.set(presentation, str(key::mana_current), int_value(std::max<int64_t>(0, gd::int_field(state, mana, key::current, 0))));
	state.set(presentation, str(key::mana_max), int_value(std::max<int64_t>(0, gd::int_field(state, mana, key::max, 0))));
	state.set(presentation, str(key::battle_spell_count), int_value(battle_spell_count));
	state.set(presentation, str(key::cast_this_round), bool_value(_commander_spell_cast_this_round(state, battle, side)));
	return presentation;
}

} // namespace battle_rules

} // namespace aurelion::rules::port
