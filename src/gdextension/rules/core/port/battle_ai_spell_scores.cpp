// BattleAiRules' spell scores: what the field objectives add to an action, and
// the recovery, cleanse, buff and metadata terms of a spell on a target.

#include "aurelion_rules/port/battle_ai_rules.hpp"
#include "aurelion_rules/port/battle_rules.hpp"
#include "aurelion_rules/port/spell_rules.hpp"

#include "aurelion_rules/compat/godot_math.hpp"

#include <initializer_list>
#include <string>

namespace aurelion::rules::port::battle_ai_rules {

using compat::engine_max;
using compat::engine_min;
using compat::float_to_int;
using gd::array_value;
using gd::dict_value;
using gd::str;
namespace key = state::key;

namespace {

// BattleAiRules.COHESION_MAX.
constexpr int64_t kCohesionMax = 10;

bool empty(const State &state, DictRef dict) {
	return gd::is_empty(state, dict);
}

Atom side_of(const State &state, DictRef stack) {
	return gd::string_field(state, stack, key::side, key::empty);
}

Atom faction_of(const State &state, DictRef stack) {
	return gd::string_field(state, stack, key::faction_id, key::empty);
}

bool ranged(const State &state, DictRef stack) {
	return gd::bool_field(state, stack, key::ranged, false);
}

bool has_shots(const State &state, DictRef stack) {
	return gd::int_field(state, stack, key::shots_remaining, 0) > 0;
}

int64_t battle_round(const State &state, DictRef battle) {
	return gd::int_field(state, battle, key::round, 1);
}

int64_t battle_distance(const State &state, DictRef battle) {
	return gd::int_field(state, battle, key::distance, 1);
}

bool one_of(Atom value, std::initializer_list<Atom> atoms) {
	for (const Atom atom : atoms) {
		if (value == atom) {
			return true;
		}
	}
	return false;
}

ArrayRef string_array(State &state, std::initializer_list<Atom> atoms) {
	const ArrayRef array = state.new_array();
	for (const Atom atom : atoms) {
		state.append(array, str(atom));
	}
	return array;
}

// [STATUS_HARRIED, STATUS_STAGGERED].
Value pressure_status_ids(State &state) {
	return array_value(string_array(state, { key::status_harried, key::status_staggered }));
}

// spell.get("effect", {}): the field, or a new empty Dictionary.
Value effect_of(State &state, DictRef spell) {
	Value found;
	if (state.lookup(spell, str(key::effect), found)) {
		return found;
	}
	return dict_value(state.new_dict());
}

// value.get(key, fallback) on an untyped value: only a Dictionary has a
// two-argument get, so GDScript stops on any other base.
DictRef get_base(const Value &base) {
	if (!gd::is_dict(base)) {
		throw state::ScriptError(std::string("Invalid call. Nonexistent function 'get' in base '") + gd::type_name(base) + "'.");
	}
	return base.ref;
}

// var role_categories: Array = behavior.get("role_categories", []). A packed
// array would be converted to a new Array by the typed assignment.
ArrayRef role_categories_of(State &state, DictRef behavior) {
	Value found;
	if (!state.lookup(behavior, str(key::role_categories), found)) {
		return state.new_array();
	}
	if (gd::is_array(found)) {
		return found.ref;
	}
	if (gd::is_packed(found)) {
		throw state::NotPorted("BattleAiRules._spell_metadata_value_modifier: role_categories is a packed array, which the typed assignment converts to an Array");
	}
	throw state::ScriptError(std::string("Trying to assign value of type '") + gd::type_name(found) + "' to a variable of type 'Array'.");
}

// _objective_action_score(battle, String(active_stack.get("side", "")), "cast_spell", active_stack, target_stack).
double cast_objective_score(State &state, DictRef battle, DictRef active_stack, DictRef target_stack) {
	return _objective_action_score(state, battle, side_of(state, active_stack), key::cast_spell, active_stack, target_stack);
}

// float(int(spell.get("mana_cost", 0))) * 0.2
double mana_cost_term(const State &state, DictRef spell) {
	return static_cast<double>(gd::int_field(state, spell, key::mana_cost, 0)) * 0.2;
}

// (1.0 - (float(_stack_cohesion_total(stack, battle)) / float(COHESION_MAX)))
double cohesion_gap(State &state, DictRef stack, DictRef battle) {
	return 1.0 - (static_cast<double>(_stack_cohesion_total(state, stack, battle)) / static_cast<double>(kCohesionMax));
}

} // namespace

double _objective_action_score(State &state, DictRef battle, Atom acting_side, Atom action, DictRef acting_stack, DictRef target_stack) {
	double score = 0.0;
	for (const Value &objective : gd::items(state, array_value(_field_objectives(state, battle)))) {
		if (!gd::is_dict(objective)) {
			continue;
		}
		const int64_t influence = _field_objective_action_influence(state, objective.ref, battle, acting_side, action, acting_stack, target_stack);
		if (influence <= 0) {
			continue;
		}
		score += static_cast<double>(influence) * _field_objective_value(state, objective.ref, battle, acting_side, action, acting_stack, target_stack);
	}
	return score;
}

double _field_objective_value(State &state, DictRef objective, DictRef battle, Atom acting_side, Atom action, DictRef acting_stack, DictRef target_stack) {
	const Atom objective_type = gd::string_field(state, objective, key::type, key::empty);
	const Atom controller = gd::string_field(state, objective, key::control_side, key::neutral);
	const int64_t urgency_round = gd::int_field(state, objective, key::urgency_round, 2);
	double value = 1.15;
	if (objective_type == key::lane_battery) {
		value = battle_distance(state, battle) > 0 ? 1.8 : 1.1;
		if (ranged(state, target_stack)) {
			value += 0.35;
		}
	} else if (objective_type == key::cover_line) {
		value = battle_distance(state, battle) > 0 ? 1.55 : 1.15;
		if (ranged(state, target_stack)) {
			value += 0.35;
		}
		if (_has_ability(state, target_stack, key::formation_guard) || _brace_available(state, target_stack, battle)) {
			value += 0.2;
		}
		if (gd::int_field(state, _hero_payload_for_side(state, battle, acting_side), key::mana_current, 0) > 0) {
			value += 0.2;
		}
	} else if (objective_type == key::obstruction_line) {
		value = battle_distance(state, battle) > 0 ? 1.6 : 1.2;
		if (_has_ability(state, target_stack, key::formation_guard) || _brace_available(state, target_stack, battle) || _reach_available(state, target_stack, battle)) {
			value += 0.35;
		}
		if (ranged(state, target_stack)) {
			value -= 0.15;
		}
	} else if (objective_type == key::ritual_pylon) {
		value = 1.45;
		if (battle_round(state, battle) >= urgency_round) {
			value += 0.45;
		}
	} else if (objective_type == key::supply_post) {
		value = 1.35;
		if (_battle_has_tag(state, battle, key::reserve_wave)) {
			value += 0.5;
		}
	} else if (objective_type == key::signal_beacon) {
		value = 1.3;
		if (gd::int_field(state, _hero_payload_for_side(state, battle, acting_side), key::mana_current, 0) > 0) {
			value += 0.25;
		}
	} else if (objective_type == key::breach_point) {
		value = 1.55;
		if (battle_round(state, battle) >= urgency_round) {
			value += 0.5;
		}
	} else if (objective_type == key::hazard_zone) {
		value = 1.4;
		if (battle_round(state, battle) >= urgency_round) {
			value += 0.55;
		}
	}
	if (controller == _opposing_side(acting_side)) {
		value += 0.35;
	} else if (controller == acting_side) {
		value -= 0.1;
	}
	if (action == key::cast_spell && !one_of(objective_type, { key::ritual_pylon, key::hazard_zone, key::signal_beacon })) {
		value *= 0.9;
	}
	if (action == key::defend && one_of(objective_type, { key::lane_battery, key::cover_line, key::signal_beacon, key::supply_post }) && ranged(state, acting_stack)) {
		value += 0.2;
	}
	return value;
}

double _recovery_spell_score_for_target(State &state, DictRef enemy_hero, DictRef battle, DictRef active_stack, DictRef target_stack, DictRef spell) {
	const int64_t missing_health = _stack_missing_health(state, target_stack);
	if (missing_health <= 0) {
		return -9999.0;
	}
	const int64_t unit_hp = engine_max<int64_t>(1, gd::int_field(state, target_stack, key::unit_hp, 1));
	const int64_t restore_amount = _battle_recovery_amount(state, enemy_hero, spell);
	const int64_t useful_restore = engine_min<int64_t>(missing_health, restore_amount);
	double score = 1.5 + (static_cast<double>(useful_restore) / static_cast<double>(unit_hp)) * 1.15;
	score += (1.0 - _health_ratio(state, target_stack)) * 5.0;
	if (_stack_contact_band(state, target_stack, battle) <= 0) {
		score += 1.0;
	}
	if (_stack_is_anchor_side(state, target_stack, battle) || _stack_is_assault_side(state, target_stack, battle)) {
		score += 0.75;
	}
	score += _stack_spell_target_value(state, target_stack, battle);
	score += cast_objective_score(state, battle, active_stack, target_stack);
	score -= mana_cost_term(state, spell);
	return score;
}

double _cleanse_spell_score_for_target(State &state, DictRef battle, DictRef active_stack, DictRef target_stack, DictRef spell) {
	const Value effect = effect_of(state, spell);
	Value listed;
	if (!state.lookup(get_base(effect), str(key::cleanse_effect_ids), listed)) {
		listed = array_value(state.new_array());
	}
	const ArrayRef cleanse_effect_ids = _normalize_string_array(state, listed);
	int64_t matching_effects = 0;
	for (const Value &effect_id : gd::items(state, array_value(cleanse_effect_ids))) {
		if (spell_rules::has_effect_id(state, target_stack, battle, gd::to_string(effect_id))) {
			matching_effects += 1;
		}
	}
	double score = 1.25 + static_cast<double>(matching_effects) * 4.0;
	if (spell_rules::has_any_effect_ids(state, target_stack, battle, pressure_status_ids(state))) {
		score += 1.5;
	}
	score += cohesion_gap(state, target_stack, battle) * 2.0;
	score += _stack_spell_target_value(state, target_stack, battle);
	score += cast_objective_score(state, battle, active_stack, target_stack);
	score -= mana_cost_term(state, spell);
	return score;
}

double _spell_metadata_value_modifier(State &state, DictRef battle, DictRef active_stack, DictRef target, DictRef spell, DictRef behavior) {
	(void)spell;
	double modifier = 0.0;
	DictRef allied_target = active_stack;
	if (!empty(state, target) && side_of(state, target) == side_of(state, active_stack)) {
		allied_target = target;
	}
	const ArrayRef role_categories = role_categories_of(state, behavior);
	const Atom primary_role = gd::string_field(state, behavior, key::primary_role, key::empty);
	const auto has_category = [&](Atom category) {
		return gd::array_has(state, role_categories, str(category));
	};
	if (has_category(key::damage) && _health_ratio(state, target) <= 0.5) {
		modifier += 0.8;
	}
	if (has_category(key::control) && !empty(state, target) && _health_ratio(state, target) > 0.5) {
		modifier += 0.7;
	}
	if (has_category(key::recovery) && _health_ratio(state, allied_target) <= 0.65) {
		modifier += 0.7;
	}
	if (has_category(key::countermagic) && spell_rules::has_any_effect_ids(state, allied_target, battle, pressure_status_ids(state))) {
		modifier += 0.9;
	}
	if (primary_role == key::priority_damage && _health_ratio(state, target) <= 0.5) {
		modifier += 0.7;
	} else if (primary_role == key::control_enemy && !empty(state, target) && _stack_cohesion_total(state, target, battle) >= 5) {
		modifier += 0.6;
	} else if (primary_role == key::ally_recovery && _stack_missing_health(state, allied_target) > 0) {
		modifier += 0.6;
	} else if (primary_role == key::countermagic_ward && spell_rules::has_any_effect_ids(state, allied_target, battle, pressure_status_ids(state))) {
		modifier += 0.6;
	}
	return modifier;
}

double _buff_spell_score(State &state, DictRef battle, DictRef active_stack, DictRef target_stack, ArrayRef targets, DictRef spell) {
	const DictRef modifiers = spell_rules::battle_spell_modifiers(state, spell);
	double score = 1.5;
	const int64_t round_number = battle_round(state, battle);
	const int64_t defense_bonus = gd::int_field(state, modifiers, key::defense, 0);
	if (defense_bonus > 0) {
		score += static_cast<double>(defense_bonus) * 1.2;
		score += (1.0 - _health_ratio(state, target_stack)) * 4.0;
		if (_stack_contact_band(state, target_stack, battle) == 0) {
			score += 2.5;
		} else if (_fights_in_melee(state, target_stack)) {
			score += 1.5;
		}
		if (_has_hostile_ranged_pressure(state, targets)) {
			score += 1.0;
		}
		if (_battle_has_any_tags(state, battle, string_array(state, { key::chokepoint, key::fortified_line }))) {
			score += 1.5;
		}
		if (_battle_has_tag(state, battle, key::fortress_lane) && _stack_is_anchor_side(state, target_stack, battle)) {
			score += 1.5;
		}
		if (_reserve_wave_is_active_for_side(state, battle, side_of(state, target_stack)) && _stack_is_anchor_side(state, target_stack, battle)) {
			score += 1.0;
		}
		if (_hero_has_trait(state, battle, side_of(state, active_stack), key::linekeeper)) {
			score += 1.0;
		}
		if (faction_of(state, target_stack) == key::faction_sunvault && _battle_has_any_tags(state, battle, string_array(state, { key::fortified_line, key::elevated_fire }))) {
			score += 1.0;
		}
	}
	const int64_t initiative_bonus = gd::int_field(state, modifiers, key::initiative, 0);
	if (initiative_bonus > 0) {
		score += static_cast<double>(initiative_bonus) * 1.1;
		if (battle_round(state, battle) <= 2) {
			score += 1.5;
		}
		if (_stack_contact_band(state, target_stack, battle) > 0 && _fights_in_melee(state, target_stack)) {
			score += 2.0;
		}
		if (_battle_has_any_tags(state, battle, string_array(state, { key::ambush_cover, key::open_lane })) && battle_round(state, battle) <= 2) {
			score += 1.0;
		}
		if (_reserve_wave_is_active_for_side(state, battle, side_of(state, target_stack)) && _stack_is_anchor_side(state, target_stack, battle)) {
			score += 1.5;
		}
		if (faction_of(state, target_stack) == key::faction_sunvault && _battle_has_any_tags(state, battle, string_array(state, { key::elevated_fire, key::open_lane }))) {
			score += 1.0;
		}
	}
	// Haste's speed matters to a melee stack that still has to close in, most
	// of all to the acting stack when it then reaches an enemy this turn.
	const int64_t speed_bonus = gd::int_field(state, modifiers, key::speed, 0);
	if (speed_bonus > 0 && _fights_in_melee(state, target_stack) && !_can_make_melee_attack(state, target_stack, battle, state.new_dict())) {
		score += 1.5 + static_cast<double>(speed_bonus) * 1.0;
		if (_is_same_stack(state, target_stack, active_stack) && battle_rules::extra_speed_reaches_strike(state, battle, target_stack, speed_bonus)) {
			score += 2.5;
		}
	}
	const int64_t attack_bonus = gd::int_field(state, modifiers, key::attack, 0);
	if (attack_bonus > 0) {
		score += static_cast<double>(attack_bonus) * 1.35;
		score += _buff_spell_offense_payoff(state, target_stack);
		if (ranged(state, target_stack) && has_shots(state, target_stack)) {
			score += 1.0;
		}
		if (_can_make_melee_attack(state, target_stack, battle, state.new_dict())) {
			score += 1.5;
		}
		if (faction_of(state, target_stack) == key::faction_mireclaw && _enemy_wounded_count(state, battle, side_of(state, target_stack)) > 0) {
			score += 1.0;
			if (_side_has_ability(state, battle, side_of(state, target_stack), key::bloodrush)) {
				score += 1.5;
			}
		}
		if (faction_of(state, target_stack) == key::faction_embercourt && _side_defending_count(state, battle, side_of(state, target_stack)) > 0) {
			score += 1.0;
			if (_side_has_ability(state, battle, side_of(state, target_stack), key::formation_guard)) {
				score += 1.5;
			}
		}
		if (gd::string_field(state, get_base(effect_of(state, spell)), key::type, key::empty) == key::attack_buff
				&& !ranged(state, target_stack)
				&& battle_round(state, battle) >= 3) {
			score += 0.75;
		}
		if (_battle_has_tag(state, battle, key::elevated_fire) && ranged(state, target_stack)) {
			score += 1.25;
		}
		if (_battle_has_tag(state, battle, key::battery_nest) && _stack_is_anchor_side(state, target_stack, battle) && ranged(state, target_stack)) {
			score += 1.75;
		}
		if (_battle_has_tag(state, battle, key::wall_pressure) && _stack_is_assault_side(state, target_stack, battle) && !ranged(state, target_stack) && round_number >= 3) {
			score += 1.25;
		}
		if (_battle_has_tag(state, battle, key::bog_channels)
				&& (_has_ability(state, target_stack, key::harry) || _has_ability(state, target_stack, key::backstab) || _has_ability(state, target_stack, key::bloodrush))) {
			score += 1.25;
		}
		if (faction_of(state, target_stack) == key::faction_sunvault && _side_positive_effect_count(state, battle, side_of(state, target_stack)) > 0) {
			score += 1.25;
		}
	}
	const int64_t cohesion_bonus = gd::int_field(state, modifiers, key::cohesion, 0);
	if (cohesion_bonus > 0) {
		score += static_cast<double>(cohesion_bonus) * 1.25;
		score += cohesion_gap(state, target_stack, battle) * 4.5;
		if (_stack_is_isolated(state, battle, target_stack)) {
			score += 1.5;
		}
		if (_battle_has_tag(state, battle, key::fortress_lane) && _stack_is_anchor_side(state, target_stack, battle)) {
			score += 1.0;
		}
		if (_reserve_wave_is_active_for_side(state, battle, side_of(state, target_stack)) && _stack_is_anchor_side(state, target_stack, battle)) {
			score += 1.5;
		}
		if (_hero_has_trait(state, battle, side_of(state, active_stack), key::linekeeper)) {
			score += 1.0;
		}
		if (faction_of(state, target_stack) == key::faction_sunvault && _battle_has_any_tags(state, battle, string_array(state, { key::fortified_line, key::elevated_fire }))) {
			score += 1.0;
		}
	}
	const int64_t momentum_bonus = gd::int_field(state, modifiers, key::momentum, 0);
	if (momentum_bonus > 0) {
		score += static_cast<double>(momentum_bonus) * 1.4;
		score += _buff_spell_offense_payoff(state, target_stack) * 0.8;
		if (_can_make_melee_attack(state, target_stack, battle, state.new_dict()) || (ranged(state, target_stack) && has_shots(state, target_stack))) {
			score += 1.5;
		}
		if (_hero_has_trait(state, battle, side_of(state, active_stack), key::vanguard) || _hero_has_trait(state, battle, side_of(state, active_stack), key::packhunter)) {
			score += 1.0;
		}
		if (_reserve_wave_is_active_for_side(state, battle, side_of(state, target_stack)) && _stack_is_anchor_side(state, target_stack, battle)) {
			score += 1.25;
		}
		if (_battle_has_tag(state, battle, key::wall_pressure) && _stack_is_assault_side(state, target_stack, battle) && !ranged(state, target_stack) && round_number >= 3) {
			score += 1.5;
		}
		if (faction_of(state, target_stack) == key::faction_sunvault) {
			const Atom target_side = side_of(state, target_stack);
			const int64_t relay_minimum = float_to_int(_side_max_ability_float(state, battle, target_side, key::resonance_relay, key::minimum_calibrated_stacks, 2.0));
			if (_side_has_ability(state, battle, target_side, key::resonance_relay) && _side_positive_effect_count(state, battle, target_side) >= relay_minimum) {
				score += 1.0;
			}
		}
	}
	if (faction_of(state, target_stack) == key::faction_sunvault && !_stack_has_positive_effect(state, target_stack, battle)) {
		score += 1.5;
	}
	// The hero casts as the acting stack's turn starts, and an effect on the
	// acting stack does not spend that turn: it serves one turn more.
	if (_is_same_stack(state, target_stack, active_stack)) {
		score += 1.0;
	}
	score += _stack_spell_target_value(state, target_stack, battle);
	score += cast_objective_score(state, battle, active_stack, target_stack);
	score -= mana_cost_term(state, spell);
	return score;
}

} // namespace aurelion::rules::port::battle_ai_rules
