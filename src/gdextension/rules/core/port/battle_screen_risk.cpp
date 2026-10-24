// BattleRules for the battle screen (Phase 7, slice 7.9): the risk and
// readiness board.

#include "aurelion_rules/port/battle_screen.hpp"

#include "aurelion_rules/compat/godot_math.hpp"
#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/spell_rules.hpp"

#include <initializer_list>
#include <string>

namespace aurelion::rules::port {

namespace {

using compat::engine_max;
using gd::array_value;
using gd::ArrayRef;
using gd::Atom;
using gd::dict_value;
using gd::DictRef;
using gd::float_value;
using gd::int_value;
using gd::str;
using state::State;
using state::Value;
namespace key = state::key;

// String(d.get(field, fallback)).
Atom text_field(State &state, DictRef dict, Atom field, Atom fallback) {
	return gd::stringify(state, state.get(dict, str(field), str(fallback)));
}

// String(x.get(field, fallback)) of an untyped value.
Atom value_text(State &state, const Value &object, Atom field, Atom fallback) {
	return gd::stringify(state, ai::vget(state, object, field, str(fallback)));
}

// An Array literal of Strings, new each time it is evaluated.
ArrayRef string_array(State &state, std::initializer_list<Atom> texts) {
	const ArrayRef array = state.new_array();
	for (const Atom text : texts) {
		state.append(array, str(text));
	}
	return array;
}

// "" if count == 1 else "s"
Atom plural_s(int64_t count) {
	return count == 1 ? key::empty : key::s;
}

// s.to_lower() of ASCII text (the Unicode case tables are not ported;
// _distance_label answers only ASCII texts).
Atom lower_ascii(State &state, Atom text, const char *where) {
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

// int(round(float(value) / divisor)) and int(round(float(value) * factor)).
int64_t rounded_quotient(int64_t value, double divisor) {
	return compat::float_to_int(compat::godot_round(static_cast<double>(value) / divisor));
}

int64_t rounded_product(int64_t value, double factor) {
	return compat::float_to_int(compat::godot_round(static_cast<double>(value) * factor));
}

} // namespace

namespace battle_rules {

Atom _risk_readiness_grade(State &state, DictRef session, DictRef battle) {
	int64_t severity = 0;
	int64_t stability = 0;
	const DictRef player_totals = _army_totals(state, battle, key::player);
	const DictRef enemy_totals = _army_totals(state, battle, key::enemy);
	const int64_t player_health = gd::int_field(state, player_totals, key::health, 0);
	const int64_t enemy_health = gd::int_field(state, enemy_totals, key::health, 0);
	const int64_t player_wavering = _wavering_stack_count(state, battle, key::player);
	const int64_t enemy_wavering = _wavering_stack_count(state, battle, key::enemy);
	const int64_t player_steady = _steady_stack_count(state, battle, key::player);
	const ArrayRef next_window = _next_activation_window(state, battle, 3);
	int64_t player_next = 0;
	int64_t enemy_next = 0;
	for (const Value &stack : gd::items(state, array_value(next_window))) {
		if (value_text(state, stack, key::side, key::empty) == key::player) {
			player_next += 1;
		} else {
			enemy_next += 1;
		}
	}
	if (enemy_next >= 2 && enemy_next > player_next) {
		severity += 2;
	} else if (player_next >= 2 && player_next > enemy_next) {
		stability += 2;
	}
	if (player_wavering >= 2) {
		severity += 2;
	} else if (player_wavering == 1) {
		severity += 1;
	}
	if (enemy_wavering >= 2) {
		stability += 2;
	} else if (enemy_wavering == 1) {
		stability += 1;
	}
	if (player_steady <= 1) {
		severity += 1;
	} else if (player_steady >= 3) {
		stability += 1;
	}
	if (player_health > 0 && enemy_health > rounded_product(player_health, 1.25)) {
		severity += 2;
	} else if (enemy_health > 0 && player_health > rounded_product(enemy_health, 1.25)) {
		stability += 2;
	}
	if (_average_side_cohesion(state, battle, key::player) >= 7.0) {
		stability += 1;
	}
	if (_average_side_cohesion(state, battle, key::player) <= 5.0) {
		severity += 1;
	}
	if (gd::int_field(state, battle, key::distance, 1) > 0) {
		const int64_t player_shots = _side_shots_remaining(state, battle, key::player);
		const int64_t enemy_shots = _side_shots_remaining(state, battle, key::enemy);
		if (enemy_shots > player_shots) {
			severity += 1;
		} else if (player_shots > enemy_shots) {
			stability += 1;
		}
	}
	if (!_battle_retreat_allowed(state, battle)) {
		severity += 1;
	}
	const int64_t max_rounds = gd::int_field(state, battle, key::max_rounds, 12);
	const int64_t round_number = gd::int_field(state, battle, key::round, 1);
	if (engine_max<int64_t>(0, gd::add(gd::sub(max_rounds, round_number), 1)) <= 2) {
		severity += 1;
	}
	Atom category = key::balanced_posture;
	if (stability >= 5 && severity <= 1) {
		category = key::strong_stabilization_posture;
	} else if (stability >= 3 && severity <= 2) {
		category = key::ready_pressure_posture;
	} else if (severity >= 6) {
		category = key::collapse_risk_rising;
	} else if (severity >= 4) {
		category = key::fragile_exchange;
	} else if (severity >= 2) {
		category = key::contested_posture;
	}
	return gd::format(state, key::s_s, { str(category), str(_pressure_brief(state, session)) });
}

Atom _risk_board_initiative_line(State &state, DictRef battle) {
	const ArrayRef next_window = _next_activation_window(state, battle, 3);
	if (state.array_size(next_window) == 0) {
		return key::the_turn_order_is_rebuilding_after;
	}
	int64_t player_count = 0;
	int64_t enemy_count = 0;
	for (const Value &stack : gd::items(state, array_value(next_window))) {
		if (value_text(state, stack, key::side, key::empty) == key::player) {
			player_count += 1;
		} else {
			enemy_count += 1;
		}
	}
	const Value first_stack = state.at(next_window, 0);
	const int64_t window_size = state.array_size(next_window);
	if (player_count > enemy_count) {
		const Atom label = _stack_label(state, gd::as_dict(first_stack));
		const int64_t initiative = _stack_initiative_total(state, gd::as_dict(first_stack), battle);
		return gd::format(state, key::friendly_line_controls_d_of_the, { int_value(player_count), int_value(window_size), str(label), int_value(initiative) });
	}
	if (enemy_count > player_count) {
		const Atom label = _stack_label(state, gd::as_dict(first_stack));
		const int64_t initiative = _stack_initiative_total(state, gd::as_dict(first_stack), battle);
		return gd::format(state, key::enemy_line_controls_d_of_the, { int_value(enemy_count), int_value(window_size), str(label), int_value(initiative) });
	}
	const Atom label = _stack_label(state, gd::as_dict(first_stack));
	const int64_t initiative = _stack_initiative_total(state, gd::as_dict(first_stack), battle);
	return gd::format(state, key::the_next_d_activations_are_split, { int_value(window_size), str(label), int_value(initiative) });
}

Atom _risk_board_commander_line(State &state, DictRef battle) {
	const DictRef commander_state = _commander_state_for_side(state, battle, key::player);
	const DictRef commander_payload = _hero_payload_for_side(state, battle, key::player);
	const DictRef enemy_payload = _hero_payload_for_side(state, battle, key::enemy);
	const Atom commander_label = text_field(state, commander_state, key::name, key::field_command);
	const int64_t steady_count = _steady_stack_count(state, battle, key::player);
	const int64_t wavering_count = _wavering_stack_count(state, battle, key::player);
	const int64_t commander_initiative = gd::int_field(state, commander_payload, key::initiative, 0);
	const int64_t enemy_initiative = gd::int_field(state, enemy_payload, key::initiative, 0);
	const int64_t initiative_edge = gd::sub(commander_initiative, enemy_initiative);
	Atom aura_summary = key::aura_even_with_enemy_command;
	if (initiative_edge > 0) {
		aura_summary = gd::format(state, key::aura_leads_enemy_command_by_d, { int_value(initiative_edge) });
	} else if (initiative_edge < 0) {
		aura_summary = gd::format(state, key::aura_trails_enemy_command_by_d, { int_value(compat::absi(initiative_edge)) });
	}
	Atom cover_summary = key::line_covered;
	int64_t command_screen = 0;
	if (_side_controls_field_objective_type(state, battle, key::player, key::cover_line)) {
		command_screen += 2;
	}
	if (_side_controls_field_objective_type(state, battle, key::player, key::signal_beacon)) {
		command_screen += 1;
	}
	if (_side_controls_field_objective_type(state, battle, key::enemy, key::cover_line)) {
		command_screen -= 1;
	}
	if (_side_controls_field_objective_type(state, battle, key::enemy, key::signal_beacon)) {
		command_screen -= 1;
	}
	if (_side_controls_field_objective_type(state, battle, key::enemy, key::obstruction_line) && gd::int_field(state, battle, key::distance, 1) > 0) {
		command_screen -= 1;
	}
	if (command_screen >= 2) {
		cover_summary = key::command_screened;
	} else if (steady_count <= 1 && wavering_count >= 2) {
		cover_summary = key::command_exposed;
	} else if (wavering_count > 0) {
		cover_summary = key::cover_contested;
	}
	const int64_t mana_current = gd::int_field(state, commander_payload, key::mana_current, 0);
	const int64_t mana_max = gd::int_field(state, commander_payload, key::mana_max, 0);
	return gd::format(state, key::s_mana_d_d_d_steady, {
		str(commander_label),
		int_value(mana_current),
		int_value(mana_max),
		int_value(steady_count),
		int_value(wavering_count),
		str(cover_summary),
		str(aura_summary),
	});
}

Atom _risk_board_line_integrity_line(State &state, DictRef battle) {
	const int64_t player_wavering = _wavering_stack_count(state, battle, key::player);
	const int64_t enemy_wavering = _wavering_stack_count(state, battle, key::enemy);
	const double player_average = _average_side_cohesion(state, battle, key::player);
	const double enemy_average = _average_side_cohesion(state, battle, key::enemy);
	if (player_wavering > 0 && (player_wavering >= enemy_wavering || player_average < enemy_average)) {
		const DictRef weakest_player = _weakest_stack_by_cohesion(state, battle, key::player);
		return gd::format(state, key::d_friendly_stack_s_are_wavering, {
			int_value(player_wavering),
			str(plural_s(player_wavering)),
			str(_stack_label(state, weakest_player)),
		});
	}
	if (enemy_wavering > 0) {
		const DictRef weakest_enemy = _weakest_stack_by_cohesion(state, battle, key::enemy);
		return gd::format(state, key::d_enemy_stack_s_are_wavering, {
			int_value(enemy_wavering),
			str(plural_s(enemy_wavering)),
			str(_stack_label(state, weakest_enemy)),
		});
	}
	if (player_average >= 7.0 && _side_defending_count(state, battle, key::player) > 0) {
		const int64_t defending = _side_defending_count(state, battle, key::player);
		return gd::engine_format(state, key::friendly_anchors_are_stabilized_at_1f, { float_value(player_average), int_value(defending) });
	}
	return gd::engine_format(state, key::average_cohesion_is_1f_friendly_to, { float_value(player_average), float_value(enemy_average) });
}

Atom _risk_board_ranged_pressure_line(State &state, DictRef battle) {
	const DictRef player_totals = _army_totals(state, battle, key::player);
	const DictRef enemy_totals = _army_totals(state, battle, key::enemy);
	const int64_t player_ranged = gd::int_field(state, player_totals, key::ranged_stacks, 0);
	const int64_t enemy_ranged = gd::int_field(state, enemy_totals, key::ranged_stacks, 0);
	const int64_t player_shots = _side_shots_remaining(state, battle, key::player);
	const int64_t enemy_shots = _side_shots_remaining(state, battle, key::enemy);
	const Atom lane_label = _risk_board_lane_label(state, battle);
	if (engine_max<int64_t>(player_ranged, enemy_ranged) <= 0) {
		return key::no_ranged_pressure_remains_melee_tempo;
	}
	if (gd::int_field(state, battle, key::distance, 1) <= 0) {
		if (enemy_ranged > player_ranged) {
			return gd::format(state, key::d_enemy_ranged_stack_s_still, { int_value(enemy_ranged), str(plural_s(enemy_ranged)) });
		}
		if (player_ranged > enemy_ranged) {
			return gd::format(state, key::your_d_ranged_stack_s_still, { int_value(player_ranged), str(plural_s(player_ranged)) });
		}
		return key::the_lines_are_engaged_so_surviving;
	}
	if (enemy_shots > player_shots) {
		const Atom enemy_lane = _side_controls_field_objective_type(state, battle, key::enemy, key::cover_line)
				? gd::format(state, key::covered_s, { str(lane_label) })
				: lane_label;
		return gd::format(state, key::enemy_batteries_own_the_s_with, {
			str(enemy_lane),
			int_value(enemy_ranged),
			str(plural_s(enemy_ranged)),
			int_value(enemy_shots),
		});
	}
	if (player_shots > enemy_shots) {
		const Atom player_lane = _side_controls_field_objective_type(state, battle, key::player, key::cover_line)
				? gd::format(state, key::covered_s, { str(lane_label) })
				: lane_label;
		return gd::format(state, key::friendly_batteries_own_the_s_with, {
			str(player_lane),
			int_value(player_ranged),
			str(plural_s(player_ranged)),
			int_value(player_shots),
		});
	}
	if (_side_controls_field_objective_type(state, battle, key::enemy, key::obstruction_line)) {
		return gd::format(state, key::enemy_obstructions_are_keeping_the_s, { str(lane_label) });
	}
	if (_side_controls_field_objective_type(state, battle, key::player, key::obstruction_line)) {
		return gd::format(state, key::friendly_hands_own_the_s_choke, { str(lane_label) });
	}
	if (enemy_ranged > player_ranged) {
		return key::enemy_line_holds_the_deeper_firing;
	}
	if (player_ranged > enemy_ranged) {
		return key::friendly_line_holds_the_deeper_firing;
	}
	return gd::format(state, key::ranged_pressure_is_even_across_the, { str(lane_label) });
}

Atom _risk_board_priority_line(State &state, DictRef battle) {
	const DictRef decisive_target = _priority_enemy_stack_for_briefing(state, battle);
	if (gd::is_empty(state, decisive_target)) {
		return key::no_decisive_target_is_exposed_yet;
	}
	const DictRef active_stack = get_active_stack(state, battle);
	if (!gd::is_empty(state, active_stack) && text_field(state, active_stack, key::side, key::empty) != key::player) {
		return gd::format(state, key::s_remains_the_next_break_point, { str(_stack_label(state, decisive_target)) });
	}
	const DictRef selected_target = get_selected_target(state, battle);
	if (!gd::is_empty(state, selected_target)
			&& text_field(state, selected_target, key::battle_id, key::empty) == text_field(state, decisive_target, key::battle_id, key::empty)) {
		const Atom label = _stack_label(state, decisive_target);
		const Atom reason = _priority_target_reason(state, decisive_target, battle);
		return gd::format(state, key::s_is_already_marked_s, { str(label), str(reason) });
	}
	const Atom label = _stack_label(state, decisive_target);
	const Atom reason = _priority_target_reason(state, decisive_target, battle);
	return gd::format(state, key::shift_focus_to_s_s, { str(label), str(reason) });
}

Atom _risk_board_objective_line(State &state, DictRef session, DictRef battle) {
	const Atom urgency = _field_objective_urgency_summary(state, session, battle);
	return urgency != key::empty ? urgency : key::break_the_opposing_line_before_the;
}

Atom _risk_board_dispatch_line(State &state, DictRef battle) {
	for (const Value &event_text : gd::field_items(state, battle, str(key::recent_events))) {
		const Atom line = gd::strip_edges(state, gd::stringify(state, event_text));
		if (line != key::empty) {
			return line;
		}
	}
	return key::empty;
}

ArrayRef _next_activation_window(State &state, DictRef battle, int64_t count) {
	const ArrayRef window = state.new_array();
	// battle.get("turn_order", []): a missing key is an empty Array.
	Value turn_order;
	const bool has_turn_order = state.lookup(battle, str(key::turn_order), turn_order);
	if (has_turn_order && !gd::is_array(turn_order)) {
		return window;
	}
	const int64_t start = engine_max<int64_t>(0, gd::int_field(state, battle, key::turn_index, 0));
	if (!has_turn_order) {
		return window;
	}
	const int64_t end = state.array_size(turn_order.ref);
	for (int64_t index = start; index < end; ++index) {
		const DictRef stack = _get_stack_by_id(state, battle, gd::stringify(state, state.at(turn_order.ref, index)));
		if (gd::is_empty(state, stack) || _alive_count(state, stack) <= 0) {
			continue;
		}
		state.append(window, dict_value(stack));
		if (state.array_size(window) >= count) {
			break;
		}
	}
	return window;
}

int64_t _steady_stack_count(State &state, DictRef battle, Atom side) {
	int64_t total = 0;
	const ArrayRef alive = _alive_stacks_for_side(state, battle, side);
	for (const Value &stack_value : gd::items(state, array_value(alive))) {
		const DictRef stack = gd::as_dict(stack_value);
		if (_stack_cohesion_total(state, stack, battle) >= 6 && !_stack_is_isolated(state, battle, stack)) {
			total = gd::add(total, 1);
		}
	}
	return total;
}

int64_t _wavering_stack_count(State &state, DictRef battle, Atom side) {
	int64_t total = 0;
	const ArrayRef alive = _alive_stacks_for_side(state, battle, side);
	for (const Value &stack_value : gd::items(state, array_value(alive))) {
		const DictRef stack = gd::as_dict(stack_value);
		if (_stack_cohesion_total(state, stack, battle) <= 4
				|| _stack_is_isolated(state, battle, stack)
				|| spell_rules::has_any_effect_ids(state, stack, battle, array_value(string_array(state, { key::status_staggered, key::status_harried })))) {
			total = gd::add(total, 1);
		}
	}
	return total;
}

double _average_side_cohesion(State &state, DictRef battle, Atom side) {
	const ArrayRef stacks = _alive_stacks_for_side(state, battle, side);
	if (state.array_size(stacks) == 0) {
		return 0.0;
	}
	double total = 0.0;
	for (const Value &stack : gd::items(state, array_value(stacks))) {
		total += static_cast<double>(_stack_cohesion_total(state, gd::as_dict(stack), battle));
	}
	return total / static_cast<double>(state.array_size(stacks));
}

int64_t _side_shots_remaining(State &state, DictRef battle, Atom side) {
	int64_t total = 0;
	const ArrayRef alive = _alive_stacks_for_side(state, battle, side);
	for (const Value &stack_value : gd::items(state, array_value(alive))) {
		const DictRef stack = gd::as_dict(stack_value);
		if (gd::bool_field(state, stack, key::ranged, false)) {
			total = gd::add(total, engine_max<int64_t>(0, gd::int_field(state, stack, key::shots_remaining, 0)));
		}
	}
	return total;
}

Atom _risk_board_lane_label(State &state, DictRef battle) {
	if (_battle_has_tag(state, battle, key::battery_nest)) {
		return key::battery_lane;
	}
	if (_battle_has_any_tags(state, battle, string_array(state, { key::elevated_fire, key::open_lane }))) {
		return key::fire_lane;
	}
	return lower_ascii(state, _distance_label(state, gd::int_field(state, battle, key::distance, 1)), "BattleRules._risk_board_lane_label");
}

ArrayRef _battlefield_tag_labels(State &state, DictRef battle) {
	const ArrayRef labels = state.new_array();
	for (const Value &tag_value : gd::field_items(state, battle, str(key::battlefield_tags))) {
		const Atom label = _titleize_token(state, gd::stringify(state, tag_value));
		if (label != key::empty && !gd::array_has(state, labels, str(label))) {
			state.append(labels, str(label));
		}
		if (state.array_size(labels) >= 4) {
			break;
		}
	}
	return labels;
}

ArrayRef _battle_trait_labels(State &state, ArrayRef traits) {
	const ArrayRef labels = state.new_array();
	for (const Value &trait_value : gd::items(state, array_value(traits))) {
		const Atom label = _titleize_token(state, gd::stringify(state, trait_value));
		if (label != key::empty && !gd::array_has(state, labels, str(label))) {
			state.append(labels, str(label));
		}
		if (state.array_size(labels) >= 3) {
			break;
		}
	}
	return labels;
}

DictRef _encounter_objective_for_battle(State &state, DictRef session, DictRef battle, DictRef scenario) {
	if (gd::is_empty(state, scenario)) {
		return state.new_dict();
	}
	const DictRef encounter_placement = _current_battle_encounter_placement(state, dict_value(session));
	const Value resolved_key = state.get(battle, str(key::resolved_key), str(key::empty));
	const Atom placement_id = gd::stringify(state, state.get(encounter_placement, str(key::placement_id), resolved_key));
	if (placement_id == key::empty) {
		return state.new_dict();
	}
	// scenario.get("objectives", {}): a missing key is an empty Dictionary, with
	// no objectives in it.
	Value objectives;
	if (!state.lookup(scenario, str(key::objectives), objectives) || !gd::is_dict(objectives)) {
		return state.new_dict();
	}
	for (const Atom bucket_name : { key::victory, key::defeat }) {
		for (const Value &objective : gd::field_items(state, objectives.ref, str(bucket_name))) {
			if (gd::is_dict(objective)
					&& text_field(state, objective.ref, key::type, key::empty) == key::encounter_resolved
					&& text_field(state, objective.ref, key::placement_id, key::empty) == placement_id) {
				return objective.ref;
			}
		}
	}
	return state.new_dict();
}

DictRef _priority_enemy_stack_for_briefing(State &state, DictRef battle) {
	DictRef best = state.new_dict();
	int64_t best_score = -99999;
	const ArrayRef alive = _alive_stacks_for_side(state, battle, key::enemy);
	for (const Value &stack_value : gd::items(state, array_value(alive))) {
		const DictRef stack = gd::as_dict(stack_value);
		int64_t score = 0;
		if (gd::bool_field(state, stack, key::ranged, false)) {
			score += _battle_has_any_tags(state, battle, string_array(state, { key::battery_nest, key::elevated_fire, key::open_lane })) ? 5 : 3;
			if (_side_controls_field_objective_type(state, battle, key::enemy, key::cover_line)) {
				score += 2;
			}
		} else {
			score += _battle_has_any_tags(state, battle, string_array(state, { key::fortress_lane, key::wall_pressure, key::chokepoint })) ? 4 : 2;
			if (_side_controls_field_objective_type(state, battle, key::enemy, key::obstruction_line)
					&& (_has_ability(state, stack, key::formation_guard)
							|| _brace_available(state, stack, battle)
							|| _reach_available(state, stack, battle)
							|| gd::bool_field(state, stack, key::defending, false))) {
				score += 2;
			}
		}
		if (_side_controls_field_objective_type(state, battle, key::enemy, key::cover_line) && _stack_is_cover_screened(state, stack, battle)) {
			score += 1;
		}
		if (_has_ability(state, stack, key::formation_guard) || _brace_available(state, stack, battle) || _reach_available(state, stack, battle)) {
			score += 2;
		}
		if (_has_ability(state, stack, key::bloodrush) || _has_ability(state, stack, key::backstab) || _has_ability(state, stack, key::harry)) {
			score += 2;
		}
		score = gd::add(score, rounded_quotient(gd::int_field(state, stack, key::total_health, 0), 18.0));
		score = gd::add(score, rounded_quotient(_stack_initiative_total(state, stack, battle), 3.0));
		if (gd::is_empty(state, best) || score > best_score) {
			best = stack;
			best_score = score;
		}
	}
	return best;
}

Atom _priority_target_reason(State &state, DictRef stack, DictRef battle) {
	// String(stack.get("side", "")), read where GDScript reads it.
	const auto side = [&]() { return text_field(state, stack, key::side, key::empty); };
	const auto anchors = [&]() {
		return _has_ability(state, stack, key::formation_guard) || _brace_available(state, stack, battle) || _reach_available(state, stack, battle);
	};
	if (gd::bool_field(state, stack, key::ranged, false)
			&& _battle_has_any_tags(state, battle, string_array(state, { key::battery_nest, key::elevated_fire, key::open_lane }))) {
		return key::its_ranged_line_controls_the_opening;
	}
	if (gd::bool_field(state, stack, key::ranged, false) && _side_controls_field_objective_type(state, battle, side(), key::cover_line)) {
		return key::it_is_firing_from_a_screened;
	}
	if (_side_controls_field_objective_type(state, battle, side(), key::cover_line) && _stack_is_cover_screened(state, stack, battle)) {
		return key::it_is_part_of_the_screen;
	}
	if (gd::bool_field(state, stack, key::ranged, false)) {
		return key::it_is_the_sharpest_ranged_threat;
	}
	if (_side_controls_field_objective_type(state, battle, side(), key::obstruction_line) && anchors()) {
		return key::it_is_locking_the_obstruction_line;
	}
	if (_battle_has_any_tags(state, battle, string_array(state, { key::fortress_lane, key::wall_pressure, key::chokepoint })) && anchors()) {
		return key::it_anchors_the_tightest_lane_in;
	}
	if (_has_ability(state, stack, key::bloodrush) || _has_ability(state, stack, key::backstab) || _has_ability(state, stack, key::harry)) {
		return key::it_can_snowball_fast_once_the;
	}
	if (_stack_initiative_total(state, stack, battle) >= 10) {
		return key::it_will_act_early_and_pressure;
	}
	return key::breaking_it_will_soften_the_enemy;
}

} // namespace battle_rules

} // namespace aurelion::rules::port
