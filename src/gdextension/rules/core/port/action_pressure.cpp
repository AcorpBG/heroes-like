// Layer 6: the cohesion and momentum pressure of an advance and a defend, and the melee approach, the move next to
// the target before a strike.

#include "aurelion_rules/port/battle_rules.hpp"

#include "aurelion_rules/compat/godot_math.hpp"

#include <string>
#include <vector>

namespace aurelion::rules::port::battle_rules {

using compat::engine_max;
using gd::str;
namespace key = state::key;

namespace {

// An Array literal of String constants: a new Array on every evaluation.
ArrayRef string_array(State &state, std::initializer_list<Atom> atoms) {
	const ArrayRef array = state.new_array();
	for (const Atom atom : atoms) {
		state.append(array, str(atom));
	}
	return array;
}

// bool(stack.get("ranged", false)), read again at every use as GDScript reads it.
bool is_ranged(const State &state, DictRef stack) {
	return gd::bool_field(state, stack, key::ranged, false);
}

// String(stack.get("side", "")), read again at every use as GDScript reads it.
Atom side_of(const State &state, DictRef stack) {
	return gd::string_field(state, stack, key::side, key::empty);
}

// max(0, int(ability.get("defending_cohesion_bonus", 0))).
int64_t defending_cohesion_bonus(const State &state, DictRef ability) {
	return engine_max<int64_t>(0, gd::int_field(state, ability, key::defending_cohesion_bonus, 0));
}

// " ".join(parts) of Strings.
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

} // namespace

Atom _apply_advance_pressure(State &state, DictRef battle, Atom battle_id) {
	const DictRef stack = _get_stack_by_id(state, battle, battle_id);
	if (gd::is_empty(state, stack) || _alive_count(state, stack) <= 0) {
		return key::empty;
	}
	const Atom side = side_of(state, stack);
	int64_t momentum_gain = !is_ranged(state, stack) ? 1 : 0;
	bool hit_obstruction = false;
	bool stalled_at_obstruction = false;
	if (_hero_has_trait(state, battle, side_of(state, stack), key::vanguard) && !is_ranged(state, stack)) {
		momentum_gain = gd::add(momentum_gain, 1);
	}
	if (_hero_has_trait(state, battle, side_of(state, stack), key::ambusher) && _battle_has_any_tags(state, battle, string_array(state, { key::ambush_cover })) && !is_ranged(state, stack)) {
		momentum_gain = gd::add(momentum_gain, 1);
	}
	if (_battle_has_tag(state, battle, key::open_lane) && (!is_ranged(state, stack) || _hero_has_trait(state, battle, side_of(state, stack), key::artillerist))) {
		momentum_gain = gd::add(momentum_gain, 1);
	}
	if (_side_controls_field_objective_type(state, battle, side, key::obstruction_line) && !is_ranged(state, stack)) {
		momentum_gain = gd::add(momentum_gain, 1);
	}
	if (_side_controls_field_objective_type(state, battle, _opposing_side(side), key::obstruction_line)) {
		hit_obstruction = true;
		if (_stack_can_breach_obstruction(state, stack, battle)) {
			momentum_gain = engine_max<int64_t>(0, gd::sub(momentum_gain, 1));
		} else {
			stalled_at_obstruction = true;
			momentum_gain = 0;
		}
		if (!is_ranged(state, stack) && !(_reach_available(state, stack, battle) || _brace_available(state, stack, battle) || _has_ability(state, stack, key::formation_guard))) {
			_adjust_stack_cohesion(state, battle, battle_id, -1);
		}
	}
	_adjust_stack_momentum(state, battle, battle_id, momentum_gain);
	const DictRef updated = _get_stack_by_id(state, battle, battle_id);
	std::vector<Atom> notes;
	if (hit_obstruction) {
		const Atom pattern = stalled_at_obstruction ? key::cannot_crack_obstruction_format : key::hits_obstruction_format;
		notes.push_back(gd::format(state, pattern, { str(_stack_label(state, updated)) }));
	}
	if (_stack_momentum_total(state, updated, battle) >= 3) {
		notes.push_back(gd::format(state, key::surges_into_fight_format, { str(_stack_label(state, updated)) }));
	}
	return join_with_space(state, notes);
}

Atom _apply_defend_pressure(State &state, DictRef battle, Atom battle_id) {
	const DictRef stack = _get_stack_by_id(state, battle, battle_id);
	if (gd::is_empty(state, stack) || _alive_count(state, stack) <= 0) {
		return key::empty;
	}
	int64_t cohesion_gain = 1;
	const DictRef brace = _ability_by_id(state, stack, key::brace);
	if (!gd::is_empty(state, brace) && _brace_available(state, stack, battle)) {
		cohesion_gain = gd::add(cohesion_gain, defending_cohesion_bonus(state, brace));
	}
	const DictRef bramble_ground = _bramble_ground_ability(state, stack);
	if (!gd::is_empty(state, bramble_ground) && _bramble_ground_available(state, stack, battle, bramble_ground)) {
		cohesion_gain = gd::add(cohesion_gain, defending_cohesion_bonus(state, bramble_ground));
	}
	const DictRef formation_guard = _ability_by_id(state, stack, key::formation_guard);
	if (!gd::is_empty(state, formation_guard)) {
		cohesion_gain = gd::add(cohesion_gain, defending_cohesion_bonus(state, formation_guard));
	}
	if (_hero_has_trait(state, battle, side_of(state, stack), key::linekeeper)) {
		cohesion_gain = gd::add(cohesion_gain, 1);
	}
	if (_battle_has_any_tags(state, battle, string_array(state, { key::chokepoint, key::fortified_line })) && !is_ranged(state, stack)) {
		cohesion_gain = gd::add(cohesion_gain, 1);
	}
	if (_side_controls_field_objective_type(state, battle, side_of(state, stack), key::cover_line)) {
		cohesion_gain = gd::add(cohesion_gain, 1);
	}
	if (_side_controls_field_objective_type(state, battle, side_of(state, stack), key::obstruction_line) && !is_ranged(state, stack)) {
		cohesion_gain = gd::add(cohesion_gain, 1);
	}
	_adjust_stack_cohesion(state, battle, battle_id, cohesion_gain);
	_adjust_stack_momentum(state, battle, battle_id, -1);
	const DictRef updated = _get_stack_by_id(state, battle, battle_id);
	if (_stack_cohesion_total(state, updated, battle) >= 8) {
		return gd::format(state, key::steadies_line_format, { str(_stack_label(state, updated)) });
	}
	return key::empty;
}

void _apply_melee_approach(State &state, DictRef battle, DictRef stack, DictRef destination) {
	const DictRef start = _stack_hex(state, stack);
	const Atom id = gd::string_field(state, stack, key::battle_id, key::empty);
	_set_stack_hex(state, battle, id, destination);
	_sync_distance_from_hexes(state, battle);
	// The literal's values in order: start.q and start.r are read after the move, as GDScript reads them.
	const DictRef move_context = state.new_dict();
	state.set(move_context, str(key::from_q), gd::index(state, start, str(key::q)));
	state.set(move_context, str(key::from_r), gd::index(state, start, str(key::r)));
	state.set(move_context, str(key::to_q), gd::index(state, destination, str(key::q)));
	state.set(move_context, str(key::to_r), gd::index(state, destination, str(key::r)));
	_mark_stack_animation_event(state, battle, id, key::battle_unit_move, move_context);
	const Atom stack_label = _stack_label(state, stack);
	const Atom hex_label = _hex_label(state, destination);
	const Atom message = gd::format(state, key::moves_to_strike_format, { str(stack_label), str(hex_label) });
	const DictRef event_context = state.new_dict();
	state.set(event_context, str(key::actor_battle_id), str(id));
	state.set(event_context, str(key::action_id), str(key::move_strike));
	_append_presentation_event(state, battle, key::move_, message, event_context);
	_record_event(state, battle, message);
	const Atom pressure = _apply_advance_pressure(state, battle, id);
	if (pressure != key::empty) {
		const ArrayRef texts = state.new_array();
		state.append(texts, str(pressure));
		_append_text_presentation_event(state, battle, key::momentum, texts, stack, state.new_dict(), key::move_);
	}
	const DictRef action_context = state.new_dict();
	state.set(action_context, str(key::action), str(key::advance));
	state.set(action_context, str(key::side), str(side_of(state, stack)));
	state.set(action_context, str(key::battle_id), str(id));
	const ArrayRef objectives = _apply_field_objective_action_pressure(state, battle, action_context);
	if (state.array_size(objectives) > 0) {
		_append_text_presentation_event(state, battle, key::ability, objectives, stack, state.new_dict(), key::move_);
	}
}

} // namespace aurelion::rules::port::battle_rules
