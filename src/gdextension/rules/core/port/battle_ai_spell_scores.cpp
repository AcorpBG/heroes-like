// BattleAiRules' spell scores: what the field objectives add to an action, and
// the recovery, cleanse, buff and metadata terms of a spell on a target.

#include "aurelion_rules/port/battle_ai_rules.hpp"
#include "aurelion_rules/battle_hex.hpp"
#include "aurelion_rules/port/battle_footprint.hpp"
#include "aurelion_rules/port/battle_rules.hpp"
#include "aurelion_rules/port/spell_rules.hpp"

#include "aurelion_rules/compat/godot_math.hpp"

#include <initializer_list>
#include <string>
#include <vector>

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
	// Hot Iron seals the wound after it; Radiant Mend lifts harmful statuses too.
	const DictRef recovery_effect = get_base(effect_of(state, spell));
	if (gd::int_field(state, recovery_effect, key::heal_block_turns, 0) > 0) {
		score -= 0.75;
	}
	const int64_t statuses = gd::int_field(state, recovery_effect, key::cleanse_statuses, 0);
	if (statuses > 0) {
		score += 2.0 * static_cast<double>(state.array_size(spell_rules::newest_status_ids(state, target_stack, battle, statuses)));
	}
	score += _stack_spell_target_value(state, target_stack, battle);
	score += cast_objective_score(state, battle, active_stack, target_stack);
	score -= mana_cost_term(state, spell);
	return score;
}

double _reach_value(State &state, DictRef enemy_hero, DictRef battle, DictRef active_stack, DictRef target, DictRef spell, int64_t main_damage) {
	const DictRef effect = get_base(effect_of(state, spell));
	Value mastery_reach;
	const bool reaches = (state.lookup(spell, str(key::mastery_reach), mastery_reach) && gd::is_array(mastery_reach) && state.array_size(mastery_reach.ref) > 0)
			|| state.has(effect, str(key::splash)) || state.has(effect, str(key::line)) || state.has(effect, str(key::random_hits))
			|| state.has(effect, str(key::drain_pct)) || state.has(effect, str(key::reach));
	if (!reaches || empty(state, target)) {
		return 0.0;
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), gd::bool_value(true));
	state.set(result, str(key::damage), gd::int_value(main_damage));
	spell_rules::add_reach_resolutions(state, enemy_hero, battle, target, spell, result, Value());
	double value = 0.0;
	for (const Value &sub : gd::field_items(state, result, str(key::extra_resolutions))) {
		if (!gd::is_dict(sub)) {
			continue;
		}
		const DictRef stack = battle_rules::_get_stack_by_id(state, battle, gd::string_field(state, sub.ref, key::target_battle_id, key::empty));
		if (empty(state, stack)) {
			continue;
		}
		const Atom type = gd::string_field(state, sub.ref, key::resolution_type, key::empty);
		if (type == key::damage) {
			// A hit on the other side counts; a splash on the caster's own stacks counts against it.
			const double share = engine_min<double>(1.0, static_cast<double>(gd::int_field(state, sub.ref, key::damage, 0))
					/ static_cast<double>(engine_max<int64_t>(1, gd::int_field(state, stack, key::total_health, 0))));
			value += (side_of(state, stack) == side_of(state, active_stack) ? -1.5 : 1.0) * share * _w(state, key::spell_damage_share);
		} else if (type == key::recover_effect) {
			const int64_t useful = engine_min<int64_t>(gd::int_field(state, sub.ref, key::recovery_amount, 0), _stack_missing_health(state, stack));
			value += static_cast<double>(useful) / static_cast<double>(engine_max<int64_t>(1, gd::int_field(state, stack, key::unit_hp, 1))) * 0.8;
		} else if (type == key::effect) {
			Value payload;
			if (state.lookup(sub.ref, str(key::effect), payload) && gd::is_dict(payload) && !empty(state, payload.ref)) {
				value += 1.5;
			}
		}
	}
	return value;
}

double _ally_effect_mechanic_score(State &state, DictRef enemy_hero, DictRef battle, DictRef active_stack, DictRef ally, ArrayRef hostiles, DictRef spell) {
	(void)active_stack;
	const DictRef effect = get_base(effect_of(state, spell));
	Value raw;
	if (!state.lookup(effect, str(key::mechanic), raw) || !gd::is_dict(raw)) {
		return 0.0;
	}
	const int64_t power = spell_rules::spell_power(state, enemy_hero);
	const DictRef mechanic = spell_rules::resolve_mechanic(state, raw, power);
	const auto amount = [&](Atom field) { return gd::int_field(state, mechanic, field, 0); };
	const double unit_hp = static_cast<double>(engine_max<int64_t>(1, gd::int_field(state, ally, key::unit_hp, 1)));
	const bool engaged = _stack_contact_band(state, ally, battle) == 0;
	const int64_t turns = spell_rules::spell_effect_turns(state, enemy_hero, effect, spell, key::buff, power);
	int64_t melee_hostiles = 0;
	int64_t hostile_shooters = 0;
	for (const Value &hostile : gd::items(state, array_value(hostiles))) {
		if (!gd::is_dict(hostile)) {
			continue;
		}
		if (ranged(state, hostile.ref) && has_shots(state, hostile.ref)) {
			hostile_shooters += 1;
		} else if (_fights_in_melee(state, hostile.ref)) {
			melee_hostiles += 1;
		}
	}
	double score = 0.0;
	if (amount(key::plate) > 0) {
		score += 1.5 + engine_min<double>(4.0, static_cast<double>(amount(key::plate)) / unit_hp * 0.8) + (engaged ? 2.0 : 0.5);
	}
	if (amount(key::regrowth) > 0) {
		const int64_t useful = engine_min<int64_t>(gd::add(_stack_missing_health(state, ally), amount(key::regrowth)), gd::mul(amount(key::regrowth), turns));
		score += 1.0 + static_cast<double>(useful) / unit_hp * 0.8 + (1.0 - _health_ratio(state, ally)) * 3.0;
	}
	if (amount(key::thorns) > 0) {
		score += melee_hostiles > 0
				? engine_min<double>(3.0, static_cast<double>(melee_hostiles) * 0.75) + (engaged ? 1.5 : 0.0) + engine_min<double>(2.0, static_cast<double>(amount(key::thorns)) / 25.0)
				: -1.0;
	}
	if (amount(key::lifesteal_pct) > 0) {
		score += _buff_spell_offense_payoff(state, ally) * 1.2 + (1.0 - _health_ratio(state, ally)) * 2.0;
	}
	if (amount(key::momentum_per_blow) > 0) {
		score += _buff_spell_offense_payoff(state, ally) + (_can_make_melee_attack(state, ally, battle, state.new_dict()) ? 1.0 : 0.0);
	}
	if (amount(key::stationary_attack) > 0) {
		// Stand fast pays off for a stack that can strike from where it stands.
		const bool strikes_in_place = engaged || (ranged(state, ally) && has_shots(state, ally));
		score += strikes_in_place ? static_cast<double>(amount(key::stationary_attack)) * 1.2 + _buff_spell_offense_payoff(state, ally) : 0.5;
	}
	if (amount(key::shot_shield) > 0) {
		score += hostile_shooters > 0 ? 1.0 + static_cast<double>(hostile_shooters) * 1.5 : -2.0;
	}
	if (amount(key::reflect_spell) > 0) {
		// Only a commander on the other side who knows a battle spell casts one
		// to turn aside; guards and most garrisons know none.
		const Atom other_side = battle_rules::_opposing_side(side_of(state, ally));
		const Value commander = gd::field(state, battle, other_side == key::enemy ? key::enemy_hero : key::player_commander_state);
		const bool other_casts = gd::is_dict(commander) && !empty(state, commander.ref)
				&& state.array_size(spell_rules::known_spells(state, gd::deep_duplicate_dict(state, commander.ref), key::battle)) > 0;
		score += other_casts ? 1.5 : -3.0;
	}
	if (amount(key::act_next) > 0) {
		score += 1.0 + _buff_spell_offense_payoff(state, ally);
	}
	if (amount(key::backlash_pct) > 0) {
		score -= static_cast<double>(amount(key::backlash_pct)) / 100.0 * static_cast<double>(turns) * 4.0;
	}
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

double _any_harm_cleanse_score(State &state, DictRef enemy_hero, DictRef battle, DictRef active_stack, DictRef target_stack, DictRef spell) {
	// The newest harmful effects, as many as the cast lifts at the hero's power.
	const int64_t count = spell_rules::spell_effect_count(state, spell, spell_rules::spell_power(state, enemy_hero));
	const int64_t lifted = state.array_size(spell_rules::newest_effect_ids(state, target_stack, battle, false, count));
	if (lifted <= 0) {
		return -9999.0;
	}
	double score = 1.25 + static_cast<double>(lifted) * 4.0;
	if (spell_rules::has_any_effect_ids(state, target_stack, battle, pressure_status_ids(state))) {
		score += 1.5;
	}
	score += cohesion_gap(state, target_stack, battle) * 2.0;
	score += _stack_spell_target_value(state, target_stack, battle);
	score += cast_objective_score(state, battle, active_stack, target_stack);
	score -= mana_cost_term(state, spell);
	return score;
}

double _dispel_spell_score(State &state, DictRef enemy_hero, DictRef battle, DictRef active_stack, DictRef target_stack, DictRef spell) {
	// The target's newest helpful spell effects, as many as the cast takes at
	// the hero's power less the target hero's Knowledge.
	const int64_t count = spell_rules::spell_effect_count(state, spell, spell_rules::spell_power_against(state, enemy_hero, battle, target_stack));
	const int64_t removed = state.array_size(spell_rules::newest_effect_ids(state, target_stack, battle, true, count));
	if (removed <= 0) {
		return -9999.0;
	}
	double score = 1.0 + static_cast<double>(removed) * 3.0;
	score += _target_immediate_threat_score(state, active_stack, target_stack, battle) * 0.5;
	score += _stack_spell_target_value(state, target_stack, battle);
	score += cast_objective_score(state, battle, active_stack, target_stack);
	score -= mana_cost_term(state, spell);
	return score;
}

DictRef _move_spell_plan(State &state, DictRef enemy_hero, DictRef battle, DictRef active_stack, DictRef ally, DictRef spell) {
	const int64_t reach = spell_rules::spell_move_reach(state, spell, spell_rules::spell_power(state, enemy_hero));
	const ArrayRef cells = spell_rules::move_destinations(state, battle, ally, reach);
	if (state.array_size(cells) == 0) {
		return state.new_dict();
	}
	const bool acting = _is_same_stack(state, ally, active_stack);
	DictRef best_cell = state.new_dict();
	double value = 0.0;
	if (ranged(state, ally) && has_shots(state, ally) && _stack_is_engaged(state, ally, battle)) {
		// A shooter caught in melee: the hex farthest from every enemy, so it
		// shoots again (at once when it is the acting stack).
		int64_t best_distance = 1;
		for (const Value &cell : gd::items(state, array_value(cells))) {
			const int64_t distance = battle_rules::_projected_min_opposing_hex_distance(state, battle, ally, cell.ref);
			if (distance > best_distance) {
				best_distance = distance;
				best_cell = cell.ref;
			}
		}
		if (!empty(state, best_cell)) {
			value = (acting ? 5.0 : 3.0) + _buff_spell_offense_payoff(state, ally) + static_cast<double>(engine_min<int64_t>(3, best_distance - 1)) * 0.25;
		}
	} else if (acting && _fights_in_melee(state, ally) && !_can_make_melee_attack(state, ally, battle, state.new_dict())
			&& battle_rules::extra_speed_reaches_strike(state, battle, ally, reach)) {
		// The acting melee stack that reaches no enemy this turn but would with
		// the cast's steps: the hex nearest an enemy, from where its own move
		// ends next to one (it keeps its turn).
		int64_t best_distance = 999;
		for (const Value &cell : gd::items(state, array_value(cells))) {
			const int64_t distance = battle_rules::_projected_min_opposing_hex_distance(state, battle, ally, cell.ref);
			if (distance < best_distance) {
				best_distance = distance;
				best_cell = cell.ref;
			}
		}
		if (!empty(state, best_cell)) {
			value = 4.0 + _buff_spell_offense_payoff(state, ally);
		}
	}
	if (empty(state, best_cell)) {
		return state.new_dict();
	}
	const DictRef destination = state.new_dict();
	state.set(destination, str(key::q), gd::int_value(gd::int_field(state, best_cell, key::q, -1)));
	state.set(destination, str(key::r), gd::int_value(gd::int_field(state, best_cell, key::r, -1)));
	value += _stack_spell_target_value(state, ally, battle);
	value += cast_objective_score(state, battle, active_stack, ally);
	value -= mana_cost_term(state, spell);
	const DictRef plan = state.new_dict();
	state.set(plan, str(key::destination), dict_value(destination));
	state.set(plan, str(key::score), gd::float_value(value));
	return plan;
}

namespace {

bool in_contact(State &state, DictRef stack, DictRef battle) {
	return _stack_contact_band(state, stack, battle) == 0;
}

double stack_tier(const State &state, DictRef stack) {
	return static_cast<double>(engine_max<int64_t>(1, gd::int_field(state, stack, key::tier, 1)));
}

double stack_health(const State &state, DictRef stack) {
	return static_cast<double>(engine_max<int64_t>(0, gd::int_field(state, stack, key::total_health, 0)));
}

// The living stacks of side within one hex of stack, stack and skip left out.
int64_t neighbours_of_side(State &state, DictRef battle, DictRef stack, Atom side, DictRef skip) {
	int64_t count = 0;
	for (const Value &other : gd::items(state, array_value(_alive_stacks_for_side(state, battle, side)))) {
		if (!gd::is_dict(other) || _is_same_stack(state, other.ref, stack) || _is_same_stack(state, other.ref, skip)) {
			continue;
		}
		if (battle_rules::_stack_hex_distance(state, stack, other.ref) == 1) {
			count += 1;
		}
	}
	return count;
}

// Graft: worth it when the first stack is under attack and the second can bear
// half of it; a stack already grafted is left alone.
double graft_value(State &state, DictRef battle, DictRef first, DictRef second, ArrayRef hostiles) {
	if (!empty(state, spell_rules::stack_mechanic_effect(state, first, battle, key::graft_partner))
			|| !empty(state, spell_rules::stack_mechanic_effect(state, second, battle, key::graft_partner))) {
		return -9999.0;
	}
	int64_t hostile_shooters = 0;
	for (const Value &hostile : gd::items(state, array_value(hostiles))) {
		if (gd::is_dict(hostile) && ranged(state, hostile.ref) && has_shots(state, hostile.ref)) {
			hostile_shooters += 1;
		}
	}
	const double threat = in_contact(state, first, battle) ? 1.0 : (hostile_shooters > 0 ? 0.6 : 0.25);
	const double share = engine_min<double>(1.0, stack_health(state, second) / engine_max<double>(1.0, stack_health(state, first)));
	double value = 1.0 + 2.5 * threat * share + 0.3 * (stack_tier(state, first) - stack_tier(state, second)) + (1.0 - _health_ratio(state, first)) * 1.5;
	if (in_contact(state, second, battle)) {
		value -= 1.0;
	}
	return value;
}

// Blood Tithe: health is worth more in a higher tier; the trade must gain.
double transfer_value(State &state, DictRef enemy_hero, DictRef battle, DictRef spell, DictRef receiver, DictRef donor) {
	const int64_t amount = spell_rules::transfer_amount(state, enemy_hero, spell, receiver, donor);
	if (amount <= 0) {
		return -9999.0;
	}
	const auto per_health = [&](DictRef stack) { return 1.0 + 0.25 * (stack_tier(state, stack) - 1.0); };
	const double gain = static_cast<double>(amount) * (per_health(receiver) - per_health(donor));
	if (gain <= 0.0) {
		return -9999.0;
	}
	return 1.0 + gain / 40.0 + (in_contact(state, receiver, battle) ? 0.5 : 0.0);
}

// Signal Swap, one way round: an engaged shooter trades with a free melee
// stack (it shoots again, the melee stack is in the fight), or a badly wounded
// stack in the fight with a fresh one out of it.
double swap_allies_one_way(State &state, DictRef battle, DictRef a, DictRef b) {
	const bool b_shooter = ranged(state, b) && has_shots(state, b);
	if (ranged(state, a) && has_shots(state, a) && in_contact(state, a, battle) && !in_contact(state, b, battle) && !b_shooter && _fights_in_melee(state, b)) {
		return 3.0 + _buff_spell_offense_payoff(state, a) + 0.5 * _buff_spell_offense_payoff(state, b);
	}
	if (in_contact(state, a, battle) && !in_contact(state, b, battle) && !b_shooter && _health_ratio(state, a) < 0.4 && _health_ratio(state, b) > 0.7
			&& stack_health(state, b) > stack_health(state, a)) {
		return 1.5 + (1.0 - _health_ratio(state, a)) * 2.0;
	}
	return -9999.0;
}

// Changeling Swap: a free enemy shooter lands among the caster's stacks and
// one of its melee stacks among the enemy's.
double swap_enemy_value(State &state, DictRef battle, DictRef enemy, DictRef own) {
	if (!ranged(state, enemy) || !has_shots(state, enemy) || in_contact(state, enemy, battle) || !_fights_in_melee(state, own)) {
		return -9999.0;
	}
	const int64_t own_near = neighbours_of_side(state, battle, own, side_of(state, own), own);
	if (own_near == 0) {
		return -9999.0;
	}
	const int64_t enemy_near = neighbours_of_side(state, battle, enemy, side_of(state, enemy), enemy);
	return 1.5 + static_cast<double>(engine_min<int64_t>(2, own_near)) + 0.75 * static_cast<double>(engine_min<int64_t>(2, enemy_near))
			+ 0.5 * _buff_spell_offense_payoff(state, enemy);
}

} // namespace

DictRef _pair_spell_plan(State &state, DictRef enemy_hero, DictRef battle, DictRef active_stack, DictRef first, DictRef spell) {
	const Atom type = gd::string_field(state, get_base(effect_of(state, spell)), key::type, key::empty);
	const Atom side = side_of(state, active_stack);
	const ArrayRef hostiles = _alive_stacks_for_side(state, battle, battle_rules::_opposing_side(side));
	DictRef best_second = state.new_dict();
	double best = -9999.0;
	for (const Value &id : gd::items(state, array_value(spell_rules::second_stack_ids(state, enemy_hero, battle, first, spell, side)))) {
		const DictRef second = _stack_by_battle_id(state, battle, gd::to_string(id));
		if (empty(state, second)) {
			continue;
		}
		double value = -9999.0;
		if (type == key::graft_allies) {
			value = graft_value(state, battle, first, second, hostiles);
		} else if (type == key::transfer_ally) {
			value = transfer_value(state, enemy_hero, battle, spell, first, second);
		} else if (type == key::swap_allies) {
			value = engine_max<double>(swap_allies_one_way(state, battle, first, second), swap_allies_one_way(state, battle, second, first));
		} else if (type == key::swap_enemy) {
			value = swap_enemy_value(state, battle, first, second);
		}
		if (value > best) {
			best = value;
			best_second = second;
		}
	}
	if (empty(state, best_second) || best <= -9000.0) {
		return state.new_dict();
	}
	best += cast_objective_score(state, battle, active_stack, first);
	best -= mana_cost_term(state, spell);
	const DictRef destination = state.new_dict();
	state.set(destination, str(key::battle_id), str(gd::string_field(state, best_second, key::battle_id, key::empty)));
	const DictRef plan = state.new_dict();
	state.set(plan, str(key::destination), dict_value(destination));
	state.set(plan, str(key::score), gd::float_value(best));
	return plan;
}

namespace {

namespace hex = battle_hex;

hex::PlacedBody placed_of(const State &state, DictRef stack) {
	hex::PlacedBody placed;
	battle_footprint::placed_columns(state, stack, placed.q, placed.r, placed.tail_q);
	return placed;
}

// Hexes from a one-hex spot to a placed body.
int64_t spot_distance(int64_t id, hex::PlacedBody body) {
	return hex::body_distance(id, hex::Body{ 1, -1 }, body);
}

int64_t cell_id_of(State &state, const Value &cell) {
	if (!gd::is_dict(cell)) {
		return -1;
	}
	const int64_t q = gd::int_field(state, cell.ref, key::q, -1);
	const int64_t r = gd::int_field(state, cell.ref, key::r, -1);
	return battle_rules::_hex_in_bounds(q, r) ? q * hex::kRows + r : -1;
}

// A melee stack not yet in a fight, walking toward the nearest stack of the
// other side: the stack ground on its way or beside that stack can catch.
struct Walker {
	DictRef stack = 0;
	bool found = false; // a target was found (handle 0 is a real node)
	bool hostile = false; // an enemy of the caster
	hex::PlacedBody body;
	hex::PlacedBody target;
	DictRef target_stack = 0;
	int64_t distance = 999;
	int64_t steps = 0;
	int64_t free_beside_target = 0;
	double share = 0.0; // the ground's damage as a share of its health
};

// What one pick does to a walker: the share of the free hexes beside its target
// it covers (when the walker reaches the target this turn), and whether a
// covered hex lies on its shortest way there within this turn's steps.
struct Meeting {
	double beside_share = 0.0;
	bool on_way = false;
};

Meeting meeting_of(const Walker &walker, const std::vector<int64_t> &cells) {
	Meeting meeting;
	const bool reaches = walker.distance - 1 <= walker.steps;
	int64_t beside = 0;
	for (const int64_t id : cells) {
		const int64_t from_walker = spot_distance(id, walker.body);
		if (from_walker > walker.steps) {
			continue;
		}
		const int64_t to_target = spot_distance(id, walker.target);
		if (to_target == 1 && reaches) {
			beside += 1;
		} else if (from_walker >= 1 && to_target >= 1 && from_walker + to_target <= walker.distance) {
			meeting.on_way = true;
		}
	}
	if (beside > 0) {
		meeting.beside_share = engine_min<double>(1.0, static_cast<double>(beside) / static_cast<double>(engine_max<int64_t>(1, walker.free_beside_target)));
	}
	return meeting;
}

bool body_on(State &state, DictRef stack, const std::vector<int64_t> &cells) {
	const hex::PlacedBody body = placed_of(state, stack);
	for (const int64_t id : cells) {
		if (spot_distance(id, body) == 0) {
			return true;
		}
	}
	return false;
}

} // namespace

DictRef _ground_spell_plan(State &state, DictRef enemy_hero, DictRef battle, DictRef active_stack, DictRef spell) {
	const ArrayRef picks = spell_rules::ground_pick_shapes(state, battle, spell);
	if (state.array_size(picks) == 0) {
		return state.new_dict();
	}
	const Atom side = side_of(state, active_stack);
	const Atom ground = gd::string_field(state, get_base(effect_of(state, spell)), key::ground, key::empty);
	// The numbers the cast lays down do not depend on the hexes.
	const DictRef sample = spell_rules::ground_entry_for_cast(state, enemy_hero, battle, spell, side, state.new_array());
	const double damage_weight = _w(state, key::spell_damage_share);
	const DictRef blocking = battle_rules::_build_blocking_map(state, battle);
	uint8_t blocked[hex::kCellCount];
	for (int64_t q = 0; q < hex::kColumns; ++q) {
		for (int64_t r = 0; r < hex::kRows; ++r) {
			blocked[q * hex::kRows + r] = state.has(blocking, str(state.pair_atom(q, r))) ? 1 : 0;
		}
	}
	const ArrayRef allies = _alive_stacks_for_side(state, battle, side);
	const ArrayRef hostiles = _alive_stacks_for_side(state, battle, battle_rules::_opposing_side(side));
	const auto shooter = [&](DictRef stack) { return ranged(state, stack) && has_shots(state, stack); };
	int64_t hostile_shooters = 0;
	int64_t own_shooters = 0;
	for (const Value &stack : gd::items(state, array_value(hostiles))) {
		hostile_shooters += gd::is_dict(stack) && shooter(stack.ref) ? 1 : 0;
	}
	for (const Value &stack : gd::items(state, array_value(allies))) {
		own_shooters += gd::is_dict(stack) && shooter(stack.ref) ? 1 : 0;
	}
	// The walkers of both sides.
	std::vector<Walker> walkers;
	for (const bool hostile : { true, false }) {
		const ArrayRef movers = hostile ? hostiles : allies;
		const ArrayRef others = hostile ? allies : hostiles;
		for (const Value &mover : gd::items(state, array_value(movers))) {
			if (!gd::is_dict(mover) || !_fights_in_melee(state, mover.ref) || _stack_is_engaged(state, mover.ref, battle)) {
				continue;
			}
			Walker walker;
			walker.stack = mover.ref;
			walker.hostile = hostile;
			walker.steps = battle_rules::_stack_movement_points(state, mover.ref, battle);
			if (walker.steps <= 0) {
				continue;
			}
			for (const Value &other : gd::items(state, array_value(others))) {
				if (!gd::is_dict(other)) {
					continue;
				}
				const int64_t distance = battle_rules::_stack_hex_distance(state, mover.ref, other.ref);
				if (distance < walker.distance) {
					walker.distance = distance;
					walker.target_stack = other.ref;
					walker.found = true;
				}
			}
			if (!walker.found) {
				continue;
			}
			walker.body = placed_of(state, mover.ref);
			walker.target = placed_of(state, walker.target_stack);
			for (int64_t id = 0; id < hex::kCellCount; ++id) {
				walker.free_beside_target += blocked[id] == 0 && spot_distance(id, walker.target) == 1 ? 1 : 0;
			}
			const int64_t damage = spell_rules::ground_damage_against(state, battle, sample, mover.ref);
			walker.share = engine_min<double>(1.0, static_cast<double>(damage) / engine_max<double>(1.0, stack_health(state, mover.ref)));
			walkers.push_back(walker);
		}
	}
	const int64_t defense = gd::int_field(state, sample, key::defense, 0);
	DictRef best_pick = state.new_dict();
	double best = 0.0;
	std::vector<int64_t> cells;
	for (const Value &pick : gd::items(state, array_value(picks))) {
		if (!gd::is_dict(pick)) {
			continue;
		}
		cells.clear();
		for (const Value &cell : gd::field_items(state, pick.ref, str(key::cells))) {
			const int64_t id = cell_id_of(state, cell);
			if (id >= 0) {
				cells.push_back(id);
			}
		}
		if (cells.empty()) {
			continue;
		}
		double value = 0.0;
		if (ground == key::fire_ground || ground == key::bramble_ground) {
			// A walker burns once on its way or where it ends beside its
			// target, and keeps burning while it fights there; brambles stop
			// a walk that would have struck this turn. The caster's own
			// walkers count against, and as sure to walk through: the
			// computer's moves do not weigh ground yet.
			for (const Walker &walker : walkers) {
				const Meeting meeting = meeting_of(walker, cells);
				const double on_way = meeting.on_way ? (walker.hostile ? 0.35 : 1.0) : 0.0;
				const double hit = engine_max<double>(meeting.beside_share * (ground == key::fire_ground ? 1.5 : 1.0), on_way);
				double meets = hit * walker.share * damage_weight * 0.8;
				if (ground == key::bramble_ground && meeting.on_way) {
					meets += walker.distance - 1 <= walker.steps ? 1.0 : 0.4;
				}
				value += walker.hostile ? meets : -1.5 * meets;
			}
		} else if (ground == key::murk) {
			// Shooters in the fog do not shoot, and nothing in it is shot.
			for (const bool hostile : { true, false }) {
				for (const Value &stack : gd::items(state, array_value(hostile ? hostiles : allies))) {
					if (!gd::is_dict(stack) || spell_rules::in_murk(state, battle, stack.ref) || !body_on(state, stack.ref, cells)) {
						continue;
					}
					if (shooter(stack.ref)) {
						value += hostile ? 3.0 : -3.0;
					} else if (!hostile && hostile_shooters > 0) {
						value += 0.75;
					} else if (hostile && own_shooters > 0) {
						value -= 0.75;
					}
				}
			}
		} else if (ground == key::pillar) {
			// Defense for the caster's stacks beside it, most for those in a
			// fight; it also takes a hex to strike from.
			const int64_t id = cells.front();
			for (const Value &ally : gd::items(state, array_value(allies))) {
				if (!gd::is_dict(ally) || spot_distance(id, placed_of(state, ally.ref)) != 1 || spell_rules::pillar_defense(state, battle, ally.ref) >= defense) {
					continue;
				}
				double threat = 0.2;
				if (_stack_is_engaged(state, ally.ref, battle)) {
					threat = 1.0;
				} else {
					for (const Walker &walker : walkers) {
						if (walker.hostile && walker.target_stack == ally.ref && walker.distance - 1 <= walker.steps) {
							threat = 0.6;
						}
					}
				}
				value += threat * static_cast<double>(defense) / 2.0;
			}
			for (const Walker &walker : walkers) {
				if (walker.hostile && meeting_of(walker, cells).beside_share > 0.0) {
					value += 0.3;
				}
			}
		} else if (ground == key::trap) {
			// The first enemy walker that ends beside the seed sets it off:
			// the seed beside a stack it walks to, and the more of the hexes
			// it can strike from lie beside the seed, the likelier.
			const int64_t id = cells.front();
			for (const Walker &walker : walkers) {
				if (!walker.hostile || spot_distance(id, walker.target) != 1 || walker.distance - 1 > 2 * walker.steps) {
					continue;
				}
				int64_t near_seed = 0;
				for (int64_t other = 0; other < hex::kCellCount; ++other) {
					if (blocked[other] == 0 && spot_distance(other, walker.target) == 1
							&& spot_distance(other, hex::PlacedBody{ id / hex::kRows, id % hex::kRows, id / hex::kRows }) <= 1) {
						near_seed += 1;
					}
				}
				const double chance = engine_min<double>(1.0, static_cast<double>(near_seed) / static_cast<double>(engine_max<int64_t>(1, walker.free_beside_target)))
						* (walker.distance - 1 <= walker.steps ? 1.0 : 0.6);
				value = engine_max<double>(value, chance * (walker.share * damage_weight * 0.6 + 3.0));
			}
		}
		if (value > best) {
			best = value;
			best_pick = pick.ref;
		}
	}
	if (empty(state, best_pick)) {
		return state.new_dict();
	}
	best -= mana_cost_term(state, spell);
	const DictRef destination = state.new_dict();
	state.set(destination, str(key::q), gd::int_value(gd::int_field(state, best_pick, key::q, -1)));
	state.set(destination, str(key::r), gd::int_value(gd::int_field(state, best_pick, key::r, -1)));
	const DictRef plan = state.new_dict();
	state.set(plan, str(key::destination), dict_value(destination));
	state.set(plan, str(key::score), gd::float_value(best));
	return plan;
}

} // namespace aurelion::rules::port::battle_ai_rules
