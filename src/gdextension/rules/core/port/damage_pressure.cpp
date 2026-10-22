// Layer 5: damage pressure: the cohesion and momentum shifts of a hit and the shock of a destroyed
// stack, the field objectives' action pressure and control push, and the ranged damage return.

#include "aurelion_rules/port/battle_rules.hpp"
#include "aurelion_rules/port/spell_rules.hpp"

#include "aurelion_rules/compat/godot_math.hpp"

namespace aurelion::rules::port::battle_rules {

using compat::engine_clamp;
using compat::engine_max;
using compat::engine_min;
using gd::array_value;
using gd::int_value;
using gd::str;
namespace key = state::key;

namespace {

// [a, b]: a new Array of two Strings.
ArrayRef string_pair(State &state, Atom a, Atom b) {
	const ArrayRef pair = state.new_array();
	state.append(pair, str(a));
	state.append(pair, str(b));
	return pair;
}

// [STATUS_HARRIED, STATUS_STAGGERED]: a new untyped Array on every evaluation.
Value harried_or_staggered(State &state) {
	return array_value(string_pair(state, key::status_harried, key::status_staggered));
}

// d.get(field, []): the stored value, or a new empty Array when the key is missing.
Value field_or_new_array(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return array_value(state.new_array());
}

// clampf(float(max(0, before_health - after_health)) / float(before_health), 0.0, 1.0),
// with before_health at least 1.
double lost_health_ratio(int64_t before_health, int64_t after_health) {
	const int64_t lost = engine_max<int64_t>(0, gd::sub(before_health, after_health));
	return engine_clamp<double>(static_cast<double>(lost) / static_cast<double>(before_health), 0.0, 1.0);
}

// max(0, int(d.get(field, 0))): an int.
int64_t non_negative_int_field(const State &state, DictRef dict, Atom field) {
	return engine_max<int64_t>(0, gd::int_field(state, dict, field, 0));
}

// a.append_array(b) of an untyped Array a that is not b.
void append_array(State &state, ArrayRef array, ArrayRef other) {
	for (const Value &item : gd::items(state, array_value(other))) {
		state.append(array, item);
	}
}

} // namespace

ArrayRef _apply_damage_pressure(State &state, DictRef battle, DictRef attacker, DictRef target_before, DictRef target_after, bool is_ranged, Atom source_type) {
	const ArrayRef messages = state.new_array();
	if (gd::is_empty(state, attacker) || gd::is_empty(state, target_before)) {
		return messages;
	}
	const Atom target_battle_id = gd::string_field(state, target_before, key::battle_id, key::empty);
	const Atom attacker_battle_id = gd::string_field(state, attacker, key::battle_id, key::empty);
	int64_t cohesion_shift = _casualty_cohesion_shift(state, target_before, target_after);
	if (!gd::is_empty(state, target_after) && _alive_count(state, target_after) > 0 && _stack_is_isolated(state, battle, target_after)) {
		cohesion_shift = gd::sub(cohesion_shift, 1);
	}
	if (!gd::is_empty(state, target_after) && spell_rules::has_any_effect_ids(state, target_after, battle, harried_or_staggered(state))) {
		cohesion_shift = gd::sub(cohesion_shift, 1);
	}
	_adjust_stack_cohesion(state, battle, target_battle_id, cohesion_shift);
	const int64_t momentum_gain = _attack_momentum_gain(state, attacker, target_before, target_after, battle, is_ranged, source_type);
	_adjust_stack_momentum(state, battle, attacker_battle_id, momentum_gain);
	const int64_t support_gain = _supportive_cohesion_gain(state, attacker, battle, is_ranged);
	_adjust_stack_cohesion(state, battle, attacker_battle_id, support_gain);
	if (gd::is_empty(state, target_after) || _alive_count(state, target_after) <= 0) {
		_apply_destroyed_stack_shock(state, battle, target_before, gd::string_field(state, attacker, key::side, key::empty));
	}
	const DictRef updated_target = _get_stack_by_id(state, battle, target_battle_id);
	const DictRef updated_attacker = _get_stack_by_id(state, battle, attacker_battle_id);
	if (!gd::is_empty(state, updated_target) && _alive_count(state, updated_target) > 0 && _stack_cohesion_total(state, updated_target, battle) <= 3) {
		state.append(messages, str(gd::format(state, key::stack_wavering_format, { str(_stack_label(state, updated_target)) })));
	}
	if (!gd::is_empty(state, updated_attacker) && _stack_momentum_total(state, updated_attacker, battle) >= 3) {
		state.append(messages, str(gd::format(state, key::stack_seizes_tempo_format, { str(_stack_label(state, updated_attacker)) })));
	}
	return messages;
}

int64_t _casualty_cohesion_shift(State &state, DictRef target_before, DictRef target_after) {
	// max(1, int) and max(0, int): ints.
	const int64_t before_health = engine_max<int64_t>(1, gd::int_field(state, target_before, key::total_health, 0));
	const int64_t after_health = !gd::is_empty(state, target_after) ? non_negative_int_field(state, target_after, key::total_health) : 0;
	const int64_t after_count = !gd::is_empty(state, target_after) ? _alive_count(state, target_after) : 0;
	const double lost_ratio = lost_health_ratio(before_health, after_health);
	if (after_count <= 0) {
		return -3;
	}
	if (lost_ratio >= 0.45) {
		return -2;
	}
	if (lost_ratio >= 0.18) {
		return -1;
	}
	return 0;
}

int64_t _attack_momentum_gain(State &state, DictRef attacker, DictRef target_before, DictRef target_after, DictRef battle, bool is_ranged, Atom source_type) {
	int64_t gain = 0;
	const Atom side = gd::string_field(state, attacker, key::side, key::empty);
	const bool destroyed = gd::is_empty(state, target_after) || _alive_count(state, target_after) <= 0;
	if (destroyed) {
		gain = gd::add(gain, 2);
	} else {
		const int64_t before_health = engine_max<int64_t>(1, gd::int_field(state, target_before, key::total_health, 0));
		const int64_t after_health = non_negative_int_field(state, target_after, key::total_health);
		const double lost_ratio = lost_health_ratio(before_health, after_health);
		if (lost_ratio >= 0.25 || _health_ratio(state, target_after) <= 0.75) {
			gain = gd::add(gain, 1);
		}
	}
	// target_after if not target_after.is_empty() else target_before
	const auto effect_target = [&state, target_before, target_after]() {
		return !gd::is_empty(state, target_after) ? target_after : target_before;
	};
	if (spell_rules::has_any_effect_ids(state, effect_target(), battle, harried_or_staggered(state))) {
		gain = gd::add(gain, 1);
	}
	if (_stack_cohesion_total(state, target_before, battle) <= 4) {
		gain = gd::add(gain, 1);
	}
	if (_hero_has_trait(state, battle, side, key::packhunter)
			&& (_enemy_wounded_count(state, battle, side) > 0 || spell_rules::has_any_effect_ids(state, effect_target(), battle, harried_or_staggered(state)))) {
		gain = gd::add(gain, 1);
	}
	if (_hero_has_trait(state, battle, side, key::vanguard)
			&& !is_ranged
			&& (gd::int_field(state, battle, key::round, 1) <= 2 || _battle_has_tag(state, battle, key::open_lane))) {
		gain = gd::add(gain, 1);
	}
	if (_hero_has_trait(state, battle, side, key::artillerist)
			&& is_ranged
			&& _battle_has_any_tags(state, battle, string_pair(state, key::elevated_fire, key::open_lane))) {
		gain = gd::add(gain, 1);
	}
	if (_hero_has_trait(state, battle, side, key::ambusher)
			&& !is_ranged
			&& gd::int_field(state, battle, key::round, 1) <= 2
			&& (gd::string_field(state, battle, key::terrain, key::empty) == key::forest || _battle_has_tag(state, battle, key::ambush_cover))) {
		gain = gd::add(gain, 1);
	}
	if (_hero_has_trait(state, battle, side, key::bogwise)
			&& (_battle_has_tag(state, battle, key::bog_channels) || gd::string_field(state, battle, key::terrain, key::empty) == key::mire)
			&& (_has_ability(state, attacker, key::harry) || _has_ability(state, attacker, key::backstab) || _has_ability(state, attacker, key::bloodrush))) {
		gain = gd::add(gain, 1);
	}
	const DictRef backstab = _ability_by_id(state, attacker, key::backstab);
	if (!gd::is_empty(state, backstab) && spell_rules::has_any_effect_ids(state, effect_target(), battle, field_or_new_array(state, backstab, key::status_ids))) {
		gain = gd::add(gain, non_negative_int_field(state, backstab, key::momentum_gain));
	}
	const DictRef harry = _ability_by_id(state, attacker, key::harry);
	if (!gd::is_empty(state, harry) && is_ranged) {
		gain = gd::add(gain, non_negative_int_field(state, harry, key::momentum_gain));
	}
	const DictRef bloodrush = _ability_by_id(state, attacker, key::bloodrush);
	if (!gd::is_empty(state, bloodrush)) {
		// _health_ratio(...) <= float(...): the left operand first.
		const double health_ratio = _health_ratio(state, effect_target());
		if (health_ratio <= gd::float_field(state, bloodrush, key::wounded_threshold_ratio, 0.0) || destroyed) {
			gain = gd::add(gain, non_negative_int_field(state, bloodrush, key::momentum_gain));
			if (destroyed) {
				gain = gd::add(gain, non_negative_int_field(state, bloodrush, key::kill_momentum_gain));
			}
		}
	}
	if (source_type == key::spell) {
		gain = engine_max<int64_t>(1, gain);
	}
	return gain;
}

int64_t _supportive_cohesion_gain(State &state, DictRef attacker, DictRef battle, bool is_ranged) {
	int64_t gain = 0;
	const Atom side = gd::string_field(state, attacker, key::side, key::empty);
	if (gd::string_field(state, attacker, key::faction_id, key::empty) == key::faction_embercourt
			&& is_ranged
			&& _side_defending_count(state, battle, side) > 0) {
		gain = gd::add(gain, 1);
	}
	if (gd::string_field(state, attacker, key::faction_id, key::empty) == key::faction_sunvault && _stack_has_positive_effect(state, attacker, battle)) {
		gain = gd::add(gain, 1);
		if (_side_positive_effect_count(state, battle, side) >= 2 && _battle_has_any_tags(state, battle, string_pair(state, key::fortified_line, key::elevated_fire))) {
			gain = gd::add(gain, 1);
		}
	}
	if (is_ranged && _side_has_ability(state, battle, side, key::formation_guard)) {
		gain = gd::add(gain, _side_max_ability_int(state, battle, side, key::formation_guard, key::ally_cohesion_bonus));
	}
	const DictRef formation_guard = _ability_by_id(state, attacker, key::formation_guard);
	if (!gd::is_empty(state, formation_guard) && gd::bool_field(state, attacker, key::defending, false)) {
		gain = gd::add(gain, non_negative_int_field(state, formation_guard, key::defending_cohesion_bonus));
	}
	return gain;
}

void _apply_destroyed_stack_shock(State &state, DictRef battle, DictRef destroyed_stack, Atom attacking_side) {
	const Atom defending_side = gd::string_field(state, destroyed_stack, key::side, key::empty);
	// New Arrays of the sides' stacks: the bodies write into the battle's stacks, not into them.
	const ArrayRef defenders = _alive_stacks_for_side(state, battle, defending_side);
	for (const Value &ally_value : gd::items(state, array_value(defenders))) {
		const DictRef ally = gd::as_dict(ally_value);
		const Atom ally_id = gd::string_field(state, ally, key::battle_id, key::empty);
		if (ally_id == gd::string_field(state, destroyed_stack, key::battle_id, key::empty)) {
			continue;
		}
		int64_t shock = -1;
		if (_hero_has_trait(state, battle, defending_side, key::linekeeper) && _battle_has_any_tags(state, battle, string_pair(state, key::chokepoint, key::fortified_line))) {
			shock = 0;
		}
		_adjust_stack_cohesion(state, battle, ally_id, shock);
	}
	const ArrayRef attackers = _alive_stacks_for_side(state, battle, attacking_side);
	for (const Value &ally_value : gd::items(state, array_value(attackers))) {
		const DictRef ally = gd::as_dict(ally_value);
		if (!gd::bool_field(state, ally, key::ranged, false) || _hero_has_trait(state, battle, attacking_side, key::packhunter)) {
			_adjust_stack_momentum(state, battle, gd::string_field(state, ally, key::battle_id, key::empty), 1);
		}
	}
}

ArrayRef _apply_field_objective_action_pressure(State &state, DictRef battle, DictRef action_context) {
	const Atom acting_side = gd::string_field(state, action_context, key::side, key::empty);
	// acting_side not in ["player", "enemy"]: a String matches by its text.
	if (!(acting_side == key::player || acting_side == key::enemy)) {
		return state.new_array();
	}
	const DictRef acting_stack = _get_stack_by_id(state, battle, gd::string_field(state, action_context, key::battle_id, key::empty));
	const DictRef target_stack = _get_stack_by_id(state, battle, gd::string_field(state, action_context, key::target_battle_id, key::empty));
	const ArrayRef messages = state.new_array();
	// The battle's own Array when it holds one, else a new one.
	const ArrayRef objectives = _field_objectives(state, battle);
	// range(objectives.size()): the size read once.
	const int64_t count = state.array_size(objectives);
	for (int64_t index = 0; index < count; ++index) {
		const Value objective = state.at(objectives, index);
		if (!gd::is_dict(objective)) {
			continue;
		}
		const int64_t influence = _field_objective_action_influence(state, objective.ref, battle, acting_side, action_context, acting_stack, target_stack);
		if (influence <= 0) {
			continue;
		}
		const Atom event_text = _apply_field_objective_control_push(state, objective.ref, battle, acting_side, influence);
		state.set_at(objectives, index, objective);
		if (event_text != key::empty) {
			state.append(messages, str(event_text));
		}
	}
	state.set(battle, str(key::field_objectives), array_value(objectives));
	return messages;
}

int64_t _field_objective_action_influence(State &state, DictRef objective, DictRef battle, Atom acting_side, DictRef action_context, DictRef acting_stack, DictRef target_stack) {
	const Atom action = gd::string_field(state, action_context, key::action, key::empty);
	const Atom controller = gd::string_field(state, objective, key::control_side, key::neutral);
	const bool contested = controller != acting_side;
	const bool is_ranged = gd::bool_field(state, acting_stack, key::ranged, false);
	const bool holds = acting_side == controller;
	// 2 if contested and not is_ranged else (1 if contested else 0)
	const int64_t contested_advance = contested && !is_ranged ? 2 : (contested ? 1 : 0);
	// _brace_available(acting_stack, battle) or _has_ability(acting_stack, "formation_guard")
	const auto braced = [&state, acting_stack, battle]() {
		return _brace_available(state, acting_stack, battle) || _has_ability(state, acting_stack, key::formation_guard);
	};
	const Atom objective_type = gd::string_field(state, objective, key::type, key::empty);
	if (objective_type == key::lane_battery) {
		if (action == key::advance) {
			return contested_advance;
		}
		if (action == key::strike) {
			return contested && !is_ranged ? 2 : 1;
		}
		if (action == key::shoot) {
			if (is_ranged) {
				if (holds) {
					return 2;
				}
				return gd::bool_field(state, target_stack, key::ranged, false) ? 2 : 1;
			}
		} else if (action == key::defend) {
			return holds && (is_ranged || braced()) ? 1 : 0;
		}
	} else if (objective_type == key::cover_line) {
		if (action == key::advance) {
			return contested_advance;
		}
		if (action == key::strike) {
			return contested && !is_ranged ? 2 : 1;
		}
		if (action == key::shoot) {
			return is_ranged && holds ? 1 : 0;
		}
		if (action == key::defend) {
			return holds && (is_ranged || braced()) ? 2 : (contested && !is_ranged ? 1 : 0);
		}
	} else if (objective_type == key::obstruction_line) {
		if (action == key::advance) {
			return contested_advance;
		}
		if (action == key::strike) {
			return !is_ranged ? 2 : 0;
		}
		if (action == key::defend) {
			return holds && (!is_ranged || braced() || _reach_available(state, acting_stack, battle)) ? 2 : (contested && !is_ranged ? 1 : 0);
		}
	} else if (objective_type == key::ritual_pylon || objective_type == key::hazard_zone) {
		// The two objectives' match bodies are the same.
		if (action == key::advance || action == key::strike) {
			return contested && !is_ranged ? 2 : 1;
		}
		if (action == key::cast_spell) {
			return 1;
		}
		if (action == key::defend) {
			return holds ? 1 : 0;
		}
	} else if (objective_type == key::supply_post) {
		if (action == key::defend) {
			return 2;
		}
		if (action == key::strike) {
			return !is_ranged ? 1 : 0;
		}
		if (action == key::advance) {
			return contested && !is_ranged ? 1 : 0;
		}
	} else if (objective_type == key::signal_beacon) {
		if (action == key::advance) {
			return contested ? 1 : 0;
		}
		if (action == key::defend) {
			return holds ? 2 : 1;
		}
		if (action == key::shoot) {
			return is_ranged ? 1 : 0;
		}
		if (action == key::cast_spell) {
			return 1;
		}
	} else if (objective_type == key::breach_point) {
		if (action == key::advance) {
			return !is_ranged ? 2 : 0;
		}
		if (action == key::strike) {
			return !is_ranged ? 2 : 1;
		}
		if (action == key::defend) {
			if (!holds) {
				return 0;
			}
			// _stack_is_anchor_side({"side": acting_side}, battle)
			const DictRef side_stack = state.new_dict();
			state.set(side_stack, str(key::side), str(acting_side));
			return _stack_is_anchor_side(state, side_stack, battle) ? 2 : 0;
		}
	}
	return 0;
}

Atom _apply_field_objective_control_push(State &state, DictRef objective, DictRef battle, Atom acting_side, int64_t amount) {
	if (amount <= 0) {
		return key::empty;
	}
	Atom controller = gd::string_field(state, objective, key::control_side, key::neutral);
	Atom progress_side = gd::string_field(state, objective, key::progress_side, key::empty);
	// max(0, int) and max(1, int): ints.
	int64_t progress_value = non_negative_int_field(state, objective, key::progress_value);
	const int64_t threshold = engine_max<int64_t>(1, gd::int_field(state, objective, key::capture_threshold, 2));
	if (controller == acting_side) {
		if (progress_side != key::empty && progress_side != acting_side) {
			progress_value = engine_max<int64_t>(0, gd::sub(progress_value, amount));
			if (progress_value <= 0) {
				progress_side = key::empty;
			}
		} else {
			progress_side = key::empty;
			progress_value = 0;
		}
	} else {
		if (progress_side != key::empty && progress_side != acting_side) {
			progress_value = engine_max<int64_t>(0, gd::sub(progress_value, amount));
			if (progress_value <= 0) {
				progress_side = acting_side;
				progress_value = amount;
			}
		} else {
			progress_side = acting_side;
			progress_value = gd::add(progress_value, amount);
		}
		if (progress_value >= threshold) {
			const Atom previous_controller = controller;
			controller = acting_side;
			progress_side = key::empty;
			progress_value = 0;
			state.set(objective, str(key::control_side), str(controller));
			state.set(objective, str(key::progress_side), str(progress_side));
			state.set(objective, str(key::progress_value), int_value(progress_value));
			// The round is read after the three writes above.
			state.set(objective, str(key::last_flip_round), int_value(gd::int_field(state, battle, key::round, 1)));
			return _field_objective_flip_message(state, objective, previous_controller, controller);
		}
	}
	state.set(objective, str(key::control_side), str(controller));
	state.set(objective, str(key::progress_side), str(progress_side));
	state.set(objective, str(key::progress_value), int_value(progress_side != key::empty ? progress_value : 0));
	return key::empty;
}

Atom _field_objective_flip_message(State &state, DictRef objective, Atom previous_controller, Atom new_controller) {
	const Atom label = _field_objective_label(state, objective);
	// previous_controller in ["player", "enemy"]: a String matches by its text.
	if (previous_controller == key::player || previous_controller == key::enemy) {
		return gd::format(state, key::objective_swings_format, { str(label), str(_side_label(new_controller)) });
	}
	return gd::format(state, key::objective_seized_format, { str(label), str(_side_label(new_controller)) });
}

ArrayRef _apply_ranged_damage_return(State &state, DictRef battle, Atom attacker_battle_id, DictRef defender_before, bool is_ranged, Atom source_type) {
	const ArrayRef messages = state.new_array();
	if (!is_ranged || source_type != key::attack || attacker_battle_id == key::empty || gd::is_empty(state, defender_before)) {
		return messages;
	}
	// The battle's own stack, shared with the calls below.
	const DictRef defender_after = _get_stack_by_id(state, battle, gd::string_field(state, defender_before, key::battle_id, key::empty));
	if (gd::is_empty(state, defender_after) || _alive_count(state, defender_after) <= 0) {
		return messages;
	}
	const double return_ratio = _ranged_damage_return_ratio(state, defender_after);
	if (return_ratio <= 0.0) {
		return messages;
	}
	// max(0, int - int): an int, the left int() first.
	const int64_t health_before = gd::int_field(state, defender_before, key::total_health, 0);
	const int64_t health_after = gd::int_field(state, defender_after, key::total_health, 0);
	const int64_t damage_received = engine_max<int64_t>(0, gd::sub(health_before, health_after));
	if (damage_received <= 0) {
		return messages;
	}
	const DictRef attacker_stack = _get_stack_by_id(state, battle, attacker_battle_id);
	if (gd::is_empty(state, attacker_stack) || _alive_count(state, attacker_stack) <= 0) {
		return messages;
	}
	const DictRef attacker_before = gd::deep_duplicate_dict(state, attacker_stack);
	// round() of a float stays a float; int() truncates it; max(1, int) and min(int, int) are ints.
	int64_t reflected_damage = engine_max<int64_t>(1, compat::float_to_int(compat::godot_round(static_cast<double>(damage_received) * return_ratio)));
	reflected_damage = engine_min<int64_t>(reflected_damage, gd::int_field(state, attacker_before, key::total_health, 0));
	_apply_damage_to_stack(state, battle, attacker_battle_id, reflected_damage);
	const DictRef attacker_after = _get_stack_by_id(state, battle, attacker_battle_id);
	const DictRef shielding = _ability_by_id(state, defender_after, key::shielding);
	const Atom ability_name = gd::string_field(state, shielding, key::name, key::shielding_label);
	const Atom attacker_label = _stack_label(state, attacker_before);
	state.append(messages, str(gd::format(state, key::shielding_returns_damage_format, { str(ability_name), int_value(reflected_damage), str(attacker_label) })));
	// The arguments in order: the source id, then the context literal.
	const Atom source_battle_id = gd::string_field(state, defender_after, key::battle_id, key::empty);
	const DictRef mark_context = state.new_dict();
	state.set(mark_context, str(key::ability_id), str(key::shielding));
	_mark_damage_target_animation(state, battle, attacker_battle_id, false, source_battle_id, mark_context, attacker_before);
	const DictRef damage_context = state.new_dict();
	state.set(damage_context, str(key::ability_id), str(key::shielding));
	state.set(damage_context, str(key::ability_name), str(ability_name));
	_append_damage_presentation_event(state, battle, key::ability, defender_after, attacker_before, attacker_after, reflected_damage, key::shielding, damage_context);
	const ArrayRef pressure_messages = _apply_damage_pressure(state, battle, defender_after, attacker_before, attacker_after, false, key::ability);
	append_array(state, messages, pressure_messages);
	_append_text_presentation_event(state, battle, key::morale, pressure_messages, defender_after, attacker_after, key::shielding);
	return messages;
}

} // namespace aurelion::rules::port::battle_rules
