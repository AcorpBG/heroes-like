// BattleRules for the battle screen (Phase 7, slice 7.9): the board reads it
// draws, click intents, targets, the entry context, the consequence and the
// post-action recap payloads.

#include "aurelion_rules/port/battle_screen.hpp"

#include "aurelion_rules/compat/godot_math.hpp"
#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/battle_ends.hpp"
#include "aurelion_rules/port/battle_payload.hpp"
#include "aurelion_rules/port/battle_rules_ai.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"
#include "aurelion_rules/port/overworld_rules_heroes.hpp"
#include "aurelion_rules/port/session_view.hpp"

#include <string>

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

// String(d.get(field, "")).
Atom text_field(State &state, DictRef dict, Atom field) {
	return string_of(state, state.get(dict, str(field), str(key::empty)));
}

// session.battle: SessionData types it Dictionary.
DictRef session_battle(const State &state, DictRef session) {
	return gd::as_dict(gd::index(state, session, str(key::battle)));
}

// _stack_label(stack) if not stack.is_empty() else "".
Atom label_or_empty(const State &state, DictRef stack) {
	return !gd::is_empty(state, stack) ? battle_rules::_stack_label(state, stack) : static_cast<Atom>(key::empty);
}

// separator.join(items) of an Array (String.join converts it to a
// PackedStringArray: String() of every item).
Atom join_items(State &state, Atom separator, ArrayRef items) {
	std::string joined;
	const int64_t size = state.array_size(items);
	for (int64_t index = 0; index < size; ++index) {
		if (index > 0) {
			joined += state.text(separator);
		}
		joined += state.text(string_of(state, state.at(items, index)));
	}
	return state.intern(joined);
}

// a + b of Strings.
Atom concat(State &state, Atom a, Atom b) {
	std::string joined = state.text(a);
	joined += state.text(b);
	return state.intern(joined);
}

// text.left(text.find(".")) when it has a period: the characters before the
// first ".", which ends no multi-byte sequence, so the bytes before it.
Atom before_first_period(State &state, Atom text) {
	const std::string &whole = state.text(text);
	const size_t at = whole.find('.');
	if (at == std::string::npos) {
		return text;
	}
	return state.intern(whole.substr(0, at));
}

} // namespace

namespace battle_rules {

Atom _withdrawal_pressure_label(State &state, DictRef battle, bool allowed) {
	if (!allowed) {
		return key::Locked;
	}
	const DictRef active_stack = get_active_stack(state, battle);
	if (gd::is_empty(state, active_stack) || text_field(state, active_stack, key::side) != key::player) {
		return key::window_closed;
	}
	return key::Open;
}

bool _has_delivery_context(State &state, const Value &context) {
	return gd::is_dict(context) && text_field(state, context.ref, key::delivery_node_placement_id) != key::empty;
}

DictRef battle_occupancy_map(State &state, DictRef battle) {
	if (gd::is_empty(state, battle)) {
		return state.new_dict();
	}
	return _build_occupancy_map(state, battle);
}

ArrayRef legal_attack_target_ids_for_active_stack(State &state, DictRef battle) {
	return _legal_attack_target_ids_for_active_stack(state, battle);
}

DictRef active_movement_board_click_intent(State &state, DictRef battle, const Value &preloaded_legal_destinations) {
	const DictRef active_stack = get_active_stack(state, battle);
	const ArrayRef destinations = gd::is_array(preloaded_legal_destinations)
			? preloaded_legal_destinations.ref
			: legal_destinations_for_active_stack(state, battle);
	const DictRef intent = _movement_intent_skeleton(state, battle, active_stack, state.new_dict());
	state.set(intent, str(key::destination_count), int_value(state.array_size(destinations)));
	if (gd::is_empty(state, battle)) {
		state.set(intent, str(key::message), str(key::move_click_no_battle_text));
		return intent;
	}
	if (gd::is_empty(state, active_stack)) {
		state.set(intent, str(key::message), str(key::move_click_no_stack_ready_text));
		return intent;
	}
	if (text_field(state, active_stack, key::side) != key::player) {
		state.set(intent, str(key::message), str(key::not_the_players_turn_text));
		return intent;
	}
	if (state.array_size(destinations) == 0) {
		state.set(intent, str(key::blocked), bool_value(true));
		state.set(intent, str(key::message), str(_movement_intent_message(state, battle, active_stack, state.new_dict(), 0)));
		return intent;
	}

	state.set(intent, str(key::action), str(key::move_));
	state.set(intent, str(key::label), str(key::Move));
	state.set(intent, str(key::movable), bool_value(true));
	state.set(intent, str(key::message), str(_movement_intent_message(state, battle, active_stack, state.new_dict(), state.array_size(destinations))));
	return intent;
}

ArrayRef legal_movement_intents_for_active_stack(State &state, DictRef battle, const Value &preloaded_legal_destinations) {
	const ArrayRef intents = state.new_array();
	// GDScript's begin_board_read_scope / end_board_read_scope around the loop
	// are not ported: the native board reads keep their own memo.
	const ArrayRef destinations = gd::is_array(preloaded_legal_destinations)
			? preloaded_legal_destinations.ref
			: legal_destinations_for_active_stack(state, battle);
	for (const Value &destination : gd::items(state, array_value(destinations))) {
		if (!gd::is_dict(destination)) {
			continue;
		}
		const int64_t q = gd::int_field(state, destination.ref, key::q, -1);
		const int64_t r = gd::int_field(state, destination.ref, key::r, -1);
		state.append(intents, dict_value(movement_intent_for_destination(state, battle, q, r, array_value(destinations))));
	}
	return intents;
}

DictRef battle_hex_state_summary(State &state, DictRef battle) {
	const DictRef active_stack = get_active_stack(state, battle);
	const DictRef active_hex = _stack_hex(state, active_stack);
	const ArrayRef legal_destinations = legal_destinations_for_active_stack(state, battle);
	const DictRef selected_legality = selected_target_legality(state, battle);
	const DictRef selected_click_intent = selected_target_board_click_intent(state, battle);
	const DictRef selected_continuity_context = selected_target_continuity_context(state, battle);
	const DictRef selected_closing_context = selected_target_closing_context(state, battle, true);
	const DictRef movement_click_intent = active_movement_board_click_intent(state, battle, array_value(legal_destinations));
	const Atom selected_action_label = text_field(state, selected_click_intent, key::label);
	const DictRef summary = state.new_dict();
	state.set(summary, str(key::columns), int_value(BATTLE_HEX_COLUMNS));
	state.set(summary, str(key::rows), int_value(BATTLE_HEX_ROWS));
	state.set(summary, str(key::occupied_hexes), dict_value(_build_occupancy_map(state, battle)));
	state.set(summary, str(key::legal_destinations), array_value(legal_destinations));
	state.set(summary, str(key::legal_movement_intents), array_value(legal_movement_intents_for_active_stack(state, battle, array_value(legal_destinations))));
	state.set(summary, str(key::legal_melee_targets), array_value(legal_attack_targets_for_active_stack(state, battle, false)));
	state.set(summary, str(key::legal_ranged_targets), array_value(legal_attack_targets_for_active_stack(state, battle, true)));
	state.set(summary, str(key::active_hex), dict_value(active_hex));
	state.set(summary, str(key::active_movement_board_click_intent), dict_value(movement_click_intent));
	state.set(summary, str(key::selected_target_legality), dict_value(selected_legality));
	state.set(summary, str(key::selected_target_board_click_intent), dict_value(selected_click_intent));
	const bool direct_actionable = gd::is_empty(state, selected_continuity_context)
			&& gd::is_empty(state, selected_closing_context)
			&& gd::bool_field(state, selected_legality, key::attackable, false)
			&& selected_action_label != key::empty;
	state.set(summary, str(key::selected_target_direct_actionable), bool_value(direct_actionable));
	state.set(summary, str(key::selected_target_continuity_context), dict_value(selected_continuity_context));
	state.set(summary, str(key::selected_target_closing_context), dict_value(selected_closing_context));
	return summary;
}

ArrayRef target_cycle_ids(State &state, DictRef battle) {
	const ArrayRef enemies = _alive_stacks_for_side(state, battle, key::enemy);
	const ArrayRef legal_ids = _legal_attack_target_ids_for_active_stack(state, battle);
	const ArrayRef ids = state.new_array();
	for (const Value &enemy : gd::items(state, array_value(enemies))) {
		const Atom id = string_of(state, ai::vget(state, enemy, key::battle_id, str(key::empty)));
		if (state.array_size(legal_ids) == 0 || gd::array_has(state, legal_ids, str(id))) {
			state.append(ids, str(id));
		}
	}
	return ids;
}

void cycle_target(State &state, DictRef session, int64_t direction) {
	// A view is never null; nothing below assigns session.battle.
	const DictRef battle = session_battle(state, session);
	if (gd::is_empty(state, battle)) {
		return;
	}
	const DictRef active_stack = get_active_stack(state, battle);
	if (gd::is_empty(state, active_stack) || text_field(state, active_stack, key::side) != key::player) {
		return;
	}

	const ArrayRef candidates = target_cycle_ids(state, battle);
	if (state.array_size(candidates) == 0) {
		_set_selected_target(state, battle, key::empty, true);
		return;
	}

	const Atom current_id = text_field(state, battle, key::selected_target_id);
	const int64_t step = direction < 0 ? -1 : 1;
	int64_t index = step > 0 ? -1 : 0;
	const int64_t size = state.array_size(candidates);
	for (int64_t candidate_index = 0; candidate_index < size; ++candidate_index) {
		if (string_of(state, state.at(candidates, candidate_index)) == current_id) {
			index = candidate_index;
			break;
		}
	}
	index = compat::posmod(index + step, size);
	_set_selected_target(state, battle, string_of(state, state.at(candidates, index)), true);
}

ArrayRef spell_target_ids(State &state, DictRef session, Atom spell_id) {
	const ArrayRef ids = state.new_array();
	if (gd::is_empty(state, session_battle(state, session))) {
		return ids;
	}
	for (const Value &stack : gd::field_items(state, session_battle(state, session), str(key::stacks))) {
		const Atom id = string_of(state, ai::vget(state, stack, key::battle_id, str(key::empty)));
		if (id != key::empty && gd::bool_field(state, spell_consequence_preview(state, dict_value(session), spell_id, id), key::ok, false)) {
			state.append(ids, str(id));
		}
	}
	return ids;
}

ArrayRef get_spell_actions(State &state, DictRef session) {
	if (gd::is_empty(state, session_battle(state, session))) {
		return state.new_array();
	}
	const DictRef active_stack = get_active_stack(state, session_battle(state, session));
	if (gd::is_empty(state, active_stack) || text_field(state, active_stack, key::side) != key::player) {
		return state.new_array();
	}
	if (_commander_spell_cast_this_round(state, session_battle(state, session), key::player)) {
		return state.new_array();
	}
	const DictRef hero_state = _player_commander_state(state, dict_value(session));
	const DictRef battle = session_battle(state, session);
	const DictRef target = get_selected_target(state, session_battle(state, session));
	return spell_rules::get_battle_actions(state, hero_state, battle, active_stack, target);
}

Atom describe_entry_context(State &state, DictRef session) {
	if (gd::is_empty(state, session_battle(state, session))) {
		return key::battle_context_unavailable;
	}
	const DictRef battle = session_battle(state, session);
	const DictRef encounter = gd::content_row(state, ContentTable::Encounter, text_field(state, battle, key::encounter_id));
	const DictRef scenario = gd::content_row(state, ContentTable::Scenario, gd::to_string(gd::index(state, session, str(key::scenario_id))));
	const ArrayRef lines = state.new_array();
	{
		const Atom player_force = _player_force_name_from_battle(state, battle);
		const Atom enemy_force = _enemy_force_name_from_battle(state, battle, session);
		state.append(lines, str(gd::format(state, key::matchup_s_vs_s, { str(player_force), str(enemy_force) })));
	}
	{
		const DictRef player_commander = _commander_state_for_side(state, battle, key::player);
		const Atom player_faction_id = text_field(state, scenario, key::player_faction_id);
		const Atom player_identity = hero_command_rules::hero_identity_context_line(state, player_commander, player_faction_id);
		const DictRef enemy_commander = _commander_state_for_side(state, battle, key::enemy);
		const Atom enemy_faction_id = _battle_enemy_faction_id(state, dict_value(session));
		const Atom enemy_identity = hero_command_rules::hero_identity_context_line(state, enemy_commander, enemy_faction_id);
		state.append(lines, str(gd::format(state, key::commanders_s_vs_s, { str(player_identity), str(enemy_identity) })));
	}
	{
		const Atom risk_label = _battle_entry_risk_label(state, session, battle);
		const Atom friendly_total = _compact_army_total(state, _army_totals(state, battle, key::player));
		const Atom enemy_total = _compact_army_total(state, _army_totals(state, battle, key::enemy));
		state.append(lines, str(gd::format(state, key::forces_s_friendly_s_enemy_s, { str(risk_label), str(friendly_total), str(enemy_total) })));
	}
	const Atom stakes_line = _battle_entry_stakes_line(state, session, battle, encounter, scenario);
	if (stakes_line != key::empty) {
		state.append(lines, str(gd::format(state, key::stakes_s, { str(stakes_line) })));
	}
	return join_items(state, key::newline, lines);
}

Atom _battle_entry_risk_label(State &state, DictRef session, DictRef battle) {
	const ArrayRef parts = state.new_array();
	const Atom difficulty_label = _battle_difficulty_label(state, battle);
	if (difficulty_label != key::empty) {
		state.append(parts, str(difficulty_label));
	}
	Atom outlook = gd::strip_edges(state, _risk_readiness_grade(state, session, battle));
	outlook = before_first_period(state, outlook);
	if (outlook != key::empty) {
		state.append(parts, str(gd::format(state, key::outlook_s, { str(outlook) })));
	}
	return state.array_size(parts) != 0 ? join_items(state, key::space_bar_space, parts) : static_cast<Atom>(key::outlook_unscouted);
}

Atom _battle_entry_stakes_line(State &state, DictRef session, DictRef battle, DictRef encounter, DictRef scenario) {
	const ArrayRef parts = state.new_array();
	Atom objective_line = gd::strip_edges(state, _tactical_objective_line(state, session, battle, scenario));
	if (gd::begins_with(state, objective_line, key::battle_aim)) {
		objective_line = gd::strip_edges(state, gd::trim_prefix(state, objective_line, key::battle_aim));
	}
	if (objective_line != key::empty) {
		state.append(parts, str(objective_line));
	}
	const Atom reward_line = _battle_entry_reward_line(state, session, encounter, battle);
	if (reward_line != key::empty) {
		state.append(parts, str(gd::format(state, key::reward_s, { str(reward_line) })));
	}
	const Atom field_line = _field_objective_status_brief(state, battle);
	if (field_line != key::empty) {
		state.append(parts, str(gd::format(state, key::field_s, { str(field_line) })));
	}
	return join_items(state, key::space_bar_space, parts);
}

Atom _battle_entry_reward_line(State &state, DictRef session, DictRef encounter, DictRef battle) {
	if (gd::is_empty(state, encounter)) {
		return key::empty;
	}
	const ArrayRef beaten_stacks = _starting_enemy_stacks(state, battle);
	Value commander;
	if (!state.lookup(battle, str(key::enemy_hero), commander)) {
		commander = dict_value(state.new_dict());
	}
	const DictRef strength_rewards = battle_rewards_for_strength(state, encounter, array_value(beaten_stacks), commander);
	const DictRef rewards = difficulty_rules::scale_reward_resources(state, session, dict_value(strength_rewards));
	return overworld_rules::_describe_resource_delta(state, dict_value(rewards));
}

Atom _battle_difficulty_label(State &state, DictRef battle) {
	const Value fallback = state.get(battle, str(key::difficulty), str(key::empty));
	const Atom difficulty = gd::strip_edges(state, string_of(state, state.get(battle, str(key::encounter_difficulty), fallback)));
	return difficulty != key::empty ? gd::format(state, key::difficulty_s, { str(_titleize_token(state, difficulty)) }) : static_cast<Atom>(key::empty);
}

Atom _compact_army_total(State &state, DictRef totals) {
	const int64_t ranged_count = gd::int_field(state, totals, key::ranged_stacks, 0);
	const int64_t stacks = gd::int_field(state, totals, key::stacks, 0);
	const int64_t units = gd::int_field(state, totals, key::units, 0);
	const int64_t health = gd::int_field(state, totals, key::health, 0);
	Atom text = gd::format(state, key::d_stacks_d_units_d_hp, { int_value(stacks), int_value(units), int_value(health) });
	if (ranged_count > 0) {
		text = concat(state, text, gd::format(state, key::d_ranged, { int_value(ranged_count) }));
	}
	return text;
}

Atom _player_force_name_from_battle(State &state, DictRef battle) {
	const DictRef commander_state = _commander_state_for_side(state, battle, key::player);
	const Atom commander_name = gd::strip_edges(state, text_field(state, commander_state, key::name));
	if (commander_name != key::empty) {
		return gd::format(state, key::s_s_command, { str(commander_name) });
	}
	return key::friendly_command;
}

Atom _enemy_force_name_from_battle(State &state, DictRef battle, DictRef session) {
	Atom army_name = gd::strip_edges(state, text_field(state, battle, key::enemy_army_name));
	if (army_name == key::empty) {
		army_name = _enemy_force_name_from_battle_army_id(state, battle, dict_value(session));
	}
	const DictRef commander_state = _commander_state_for_side(state, battle, key::enemy);
	const Atom commander_name = gd::strip_edges(state, text_field(state, commander_state, key::name));
	if (commander_name != key::empty && army_name != key::empty && commander_name != army_name) {
		return gd::format(state, key::s_s_s, { str(commander_name), str(army_name) });
	}
	if (army_name != key::empty) {
		return army_name;
	}
	return key::enemy_force;
}

Atom describe_risk_readiness_board(State &state, DictRef session) {
	if (gd::is_empty(state, session_battle(state, session))) {
		return key::outlook_tactical_risk_board_unavailable;
	}
	const DictRef battle = session_battle(state, session);
	const ArrayRef lines = state.new_array();
	state.append(lines, str(gd::format(state, key::outlook_s_2, { str(_risk_readiness_grade(state, session, battle)) })));
	state.append(lines, str(gd::format(state, key::initiative_swing_s, { str(_risk_board_initiative_line(state, battle)) })));
	state.append(lines, str(gd::format(state, key::command_posture_s, { str(_risk_board_commander_line(state, battle)) })));
	state.append(lines, str(gd::format(state, key::line_integrity_s, { str(_risk_board_line_integrity_line(state, battle)) })));
	state.append(lines, str(gd::format(state, key::fire_lane_s, { str(_risk_board_ranged_pressure_line(state, battle)) })));
	state.append(lines, str(gd::format(state, key::priority_break_s, { str(_risk_board_priority_line(state, battle)) })));
	state.append(lines, str(gd::format(state, key::objective_urgency_s, { str(_risk_board_objective_line(state, session, battle)) })));
	const Atom dispatch_line = _risk_board_dispatch_line(state, battle);
	if (dispatch_line != key::empty) {
		state.append(lines, str(gd::format(state, key::latest_shift_s, { str(dispatch_line) })));
	}
	return join_items(state, key::newline, lines);
}

Atom describe_tactical_briefing(State &state, DictRef session) {
	if (gd::is_empty(state, session_battle(state, session))) {
		return key::empty;
	}
	normalize_battle_state(state, dict_value(session));
	if (!_should_surface_tactical_briefing(state, session)) {
		return key::empty;
	}
	return join_items(state, key::newline, _tactical_briefing_lines(state, session));
}

Atom consume_tactical_briefing(State &state, DictRef session) {
	const Atom briefing_text = describe_tactical_briefing(state, session);
	if (briefing_text == key::empty) {
		return key::empty;
	}
	// describe_tactical_briefing may have given the session a new battle: read it again.
	const DictRef battle = session_battle(state, session);
	Value briefing_state;
	if (!state.lookup(battle, str(key::tactical_briefing), briefing_state) || !gd::is_dict(briefing_state)) {
		briefing_state = dict_value(state.new_dict());
	}
	state.set(briefing_state.ref, str(key::shown), bool_value(true));
	state.set(briefing_state.ref, str(key::shown_round), int_value(gd::int_field(state, session_battle(state, session), key::round, 1)));
	state.set(session_battle(state, session), str(key::tactical_briefing), briefing_state);
	return briefing_text;
}

DictRef active_consequence_payload(State &state, DictRef session) {
	if (gd::is_empty(state, session_battle(state, session))) {
		const DictRef empty_payload = state.new_dict();
		state.set(empty_payload, str(key::active_ability_role), str(key::no_battle_is_active_text));
		state.set(empty_payload, str(key::status_pressure_2), str(key::no_status_pressure));
		state.set(empty_payload, str(key::target_range_2), str(key::no_target_selected));
		state.set(empty_payload, str(key::confirmation), str(key::ready_check_unavailable));
		state.set(empty_payload, str(key::preferred_action_id), str(key::empty));
		state.set(empty_payload, str(key::action_previews), array_value(state.new_array()));
		return empty_payload;
	}
	const DictRef battle = session_battle(state, session);
	const DictRef active_stack = get_active_stack(state, battle);
	const DictRef target = get_selected_target(state, battle);
	const DictRef surface = get_action_surface(state, session);
	const Atom preferred_action_id = text_field(state, active_stack, key::side) == key::player
			? _preferred_player_action_id(state, surface, active_stack)
			: static_cast<Atom>(key::empty);
	const DictRef payload = state.new_dict();
	state.set(payload, str(key::active_stack_name), str(label_or_empty(state, active_stack)));
	state.set(payload, str(key::active_side), str(text_field(state, active_stack, key::side)));
	state.set(payload, str(key::target_name), str(label_or_empty(state, target)));
	state.set(payload, str(key::active_ability_role), str(_active_ability_role_line(state, active_stack, battle, target)));
	state.set(payload, str(key::status_pressure_2), str(_stack_status_pressure_line(state, active_stack, battle)));
	state.set(payload, str(key::target_range_2), str(_target_range_readiness_line(state, active_stack, target, battle)));
	state.set(payload, str(key::confirmation), str(describe_action_readiness_confirmation(state, session)));
	state.set(payload, str(key::preferred_action_id), str(preferred_action_id));
	state.set(payload, str(key::action_previews), array_value(_action_consequence_preview_list(state, surface)));
	return payload;
}

DictRef post_action_recap_context(State &state, DictRef session, Atom action_id) {
	if (gd::is_empty(state, session_battle(state, session))) {
		return state.new_dict();
	}
	const DictRef battle = session_battle(state, session);
	const DictRef active_stack = get_active_stack(state, battle);
	const DictRef target = get_selected_target(state, battle);
	const bool has_active = !gd::is_empty(state, active_stack);
	const bool has_target = !gd::is_empty(state, target);
	const DictRef context = state.new_dict();
	state.set(context, str(key::action_id), str(action_id));
	state.set(context, str(key::active_battle_id), str(text_field(state, active_stack, key::battle_id)));
	state.set(context, str(key::active_name), str(has_active ? _stack_label(state, active_stack) : static_cast<Atom>(key::empty)));
	state.set(context, str(key::active_side), str(text_field(state, active_stack, key::side)));
	state.set(context, str(key::active_count_before), int_value(has_active ? _alive_count(state, active_stack) : 0));
	state.set(context, str(key::active_health_before), int_value(gd::int_field(state, active_stack, key::total_health, 0)));
	state.set(context, str(key::active_hex_before), str(has_active ? _hex_label(state, _stack_hex(state, active_stack)) : static_cast<Atom>(key::empty)));
	state.set(context, str(key::active_status_before), str(has_active ? _stack_status_pressure_short(state, active_stack, battle) : static_cast<Atom>(key::empty)));
	state.set(context, str(key::target_battle_id), str(text_field(state, target, key::battle_id)));
	state.set(context, str(key::target_name), str(has_target ? _stack_label(state, target) : static_cast<Atom>(key::empty)));
	state.set(context, str(key::target_side), str(text_field(state, target, key::side)));
	state.set(context, str(key::target_count_before), int_value(has_target ? _alive_count(state, target) : 0));
	state.set(context, str(key::target_health_before), int_value(gd::int_field(state, target, key::total_health, 0)));
	state.set(context, str(key::target_hex_before), str(has_target ? _hex_label(state, _stack_hex(state, target)) : static_cast<Atom>(key::empty)));
	state.set(context, str(key::target_status_before), str(has_target ? _stack_status_pressure_short(state, target, battle) : static_cast<Atom>(key::empty)));
	return context;
}

DictRef post_action_recap_payload(State &state, DictRef session, DictRef result, Atom action_id, DictRef context) {
	if (gd::is_empty(state, result) || !gd::bool_field(state, result, key::ok, false)) {
		return state.new_dict();
	}
	// A view is never null: session.battle if it is not empty, else a new {}.
	const DictRef battle = !gd::is_empty(state, session_battle(state, session)) ? session_battle(state, session) : state.new_dict();
	Atom normalized_action_id = action_id;
	if (normalized_action_id == key::empty) {
		const Value fallback = state.get(result, str(key::attack_action), str(key::empty));
		normalized_action_id = string_of(state, state.get(context, str(key::action_id), fallback));
	}
	const Atom happened = _post_action_happened_line(state, result, normalized_action_id);
	const Atom affected = _post_action_affected_line(state, battle, result, normalized_action_id, context);
	const Atom decision = _post_action_decision_line(state, session, result, context);
	const Atom next_actor = _post_action_next_actor_line(state, session);
	const ArrayRef lines = state.new_array();
	state.append(lines, str(gd::format(state, key::after_order_s, { str(happened) })));
	state.append(lines, str(gd::format(state, key::affected_s_2, { str(affected) })));
	state.append(lines, str(gd::format(state, key::why_it_matters_s_2, { str(decision) })));
	state.append(lines, str(gd::format(state, key::next_s, { str(next_actor) })));
	const Atom tooltip = gd::format(state, key::action_recap_happened_s_affected_s, { str(happened), str(affected), str(decision), str(next_actor) });
	const DictRef payload = state.new_dict();
	state.set(payload, str(key::action_id), str(normalized_action_id));
	state.set(payload, str(key::state), str(text_field(state, result, key::state)));
	state.set(payload, str(key::happened), str(happened));
	state.set(payload, str(key::affected), str(affected));
	state.set(payload, str(key::why_it_matters), str(decision));
	state.set(payload, str(key::next_step_2), str(next_actor));
	state.set(payload, str(key::decision), str(decision));
	state.set(payload, str(key::next_actor), str(next_actor));
	state.set(payload, str(key::text), str(join_items(state, key::newline, lines)));
	state.set(payload, str(key::tooltip), str(tooltip));
	state.set(payload, str(key::tooltip_text), str(tooltip));
	return payload;
}

Atom describe_target_context(State &state, DictRef session) {
	if (gd::is_empty(state, session_battle(state, session))) {
		return key::no_target_selected;
	}
	const DictRef battle = session_battle(state, session);
	const DictRef target = get_selected_target(state, battle);
	if (gd::is_empty(state, target)) {
		return key::no_target_selected;
	}
	const Atom summary = _stack_focus_summary(state, target, battle, false);
	const DictRef active_stack = get_active_stack(state, battle);
	if (gd::is_empty(state, active_stack)) {
		return summary;
	}
	const Atom legality_line = _target_legality_line(state, active_stack, target, battle);
	if (legality_line != key::empty) {
		const Atom engagement = _engagement_preview(state, active_stack, target, battle);
		return gd::format(state, key::s_s_engagement_s, { str(summary), str(legality_line), str(engagement) });
	}
	const Atom engagement = _engagement_preview(state, active_stack, target, battle);
	return gd::format(state, key::s_engagement_s, { str(summary), str(engagement) });
}

} // namespace battle_rules

} // namespace aurelion::rules::port
