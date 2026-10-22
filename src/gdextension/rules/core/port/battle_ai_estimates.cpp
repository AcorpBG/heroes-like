// Slice 08: BattleAiRules' estimates: the damage one stack would deal another,
// its cohesion and commander modifiers, the threat a hostile stack poses, and
// the lethal-attack and support-pressure reads built on them. Inside a scoring
// scope the damage and the threat keep their entries in _scoring_damage and
// _scoring_threats, as the GDScript does.

#include "aurelion_rules/port/battle_ai_rules.hpp"
#include "aurelion_rules/port/battle_damage_rules.hpp"
#include "aurelion_rules/port/battle_damage_rules_ai.hpp"
#include "aurelion_rules/port/spell_rules.hpp"

#include "aurelion_rules/compat/godot_math.hpp"

#include <initializer_list>
#include <string>

namespace aurelion::rules::port::battle_ai_rules {

using compat::engine_max;
using compat::engine_min;
using compat::float_to_int;
using compat::godot_round;
using gd::array_value;
using gd::bool_value;
using gd::dict_value;
using gd::float_value;
using gd::int_value;
using gd::str;
namespace key = state::key;

namespace {

bool empty(const State &state, DictRef dict) {
	return gd::is_empty(state, dict);
}

Atom side_of(const State &state, DictRef stack) {
	return gd::string_field(state, stack, key::side, key::empty);
}

bool scoring_scope_open(State &state) {
	return gd::to_int(state, gd::static_var(state, key::battle_ai_rules_script, key::_scoring_scope_depth)) > 0;
}

DictRef scoring_memo(State &state, Atom name) {
	return gd::as_dict(gd::static_var(state, key::battle_ai_rules_script, name));
}

// String(first.get("battle_id", "")) + ">" + String(second.get("battle_id", "")):
// the memo key of a pair of stacks.
Atom pair_key(State &state, DictRef first, DictRef second) {
	const Atom first_id = gd::string_field(state, first, key::battle_id, key::empty);
	const Atom second_id = gd::string_field(state, second, key::battle_id, key::empty);
	return state.intern(state.text(first_id) + ">" + state.text(second_id));
}

// An Array literal of String constants: a new Array on every evaluation.
ArrayRef string_array(State &state, std::initializer_list<Atom> atoms) {
	const ArrayRef array = state.new_array();
	for (const Atom atom : atoms) {
		state.append(array, str(atom));
	}
	return array;
}

} // namespace

bool _candidate_is_lethal_attack(State &state, DictRef candidate, DictRef battle, DictRef active_stack) {
	if (empty(state, candidate)) {
		return false;
	}
	const Atom action = gd::string_field(state, candidate, key::action, key::empty);
	if (action != key::shoot && action != key::strike) {
		return false;
	}
	const DictRef target = _stack_by_battle_id(state, battle, gd::string_field(state, candidate, key::target_battle_id, key::empty));
	if (empty(state, target) || _alive_count(state, target) <= 0) {
		return false;
	}
	const bool is_ranged = action == key::shoot;
	DictRef attacker = active_stack;
	DictRef attack_battle = battle;
	Value approach;
	if (state.lookup(candidate, str(key::approach), approach) && gd::is_dict(approach) && !empty(state, approach.ref)) {
		const ArrayRef projection = _projected_on_cell(state, battle, active_stack, approach.ref);
		attacker = gd::as_dict(state.at(projection, 0));
		attack_battle = gd::as_dict(state.at(projection, 1));
	}
	const int64_t attack_distance = _attack_distance_for_action(state, attacker, target, attack_battle, is_ranged);
	const int64_t projected_damage = _estimate_damage(state, attacker, target, attack_battle, is_ranged, false, attack_distance);
	return projected_damage >= gd::int_field(state, target, key::total_health, 0);
}

bool _support_spell_has_active_pressure(State &state, DictRef battle, DictRef active_stack, DictRef target_stack, ArrayRef hostile_targets) {
	const DictRef support_target = !empty(state, target_stack) ? target_stack : active_stack;
	if (empty(state, support_target)) {
		return false;
	}
	if (_health_ratio(state, support_target) <= 0.75) {
		return true;
	}
	for (const Value &hostile : gd::items(state, array_value(hostile_targets))) {
		if (gd::is_dict(hostile) && _target_immediate_threat_score(state, support_target, hostile.ref, battle) >= 3.0) {
			return true;
		}
	}
	return false;
}

double _target_immediate_threat_score(State &state, DictRef defended_stack, DictRef target, DictRef battle) {
	if (!scoring_scope_open(state)) {
		return _target_threat_on(state, defended_stack, target, battle);
	}
	const Atom memo_key = pair_key(state, defended_stack, target);
	for (const Value &held : gd::field_items(state, scoring_memo(state, key::_scoring_threats), str(memo_key))) {
		const ArrayRef entry = gd::as_array(held);
		if (gd::is_same(state, state.at(entry, 0), dict_value(defended_stack))
				&& gd::is_same(state, state.at(entry, 1), dict_value(target))
				&& gd::is_same(state, state.at(entry, 2), dict_value(battle))) {
			return gd::to_float(state.at(entry, 3));
		}
	}
	const double threat = _target_threat_on(state, defended_stack, target, battle);
	const ArrayRef made = state.new_array();
	state.append(made, dict_value(defended_stack));
	state.append(made, dict_value(target));
	state.append(made, dict_value(battle));
	state.append(made, float_value(threat));
	_add_scoring_memo_entry(state, scoring_memo(state, key::_scoring_threats), memo_key, made);
	return threat;
}

double _target_threat_on(State &state, DictRef defended_stack, DictRef target, DictRef battle) {
	if (empty(state, defended_stack) || empty(state, target)) {
		return 0.0;
	}
	if (side_of(state, defended_stack) == key::empty || side_of(state, defended_stack) == side_of(state, target)) {
		return 0.0;
	}
	if (_alive_count(state, defended_stack) <= 0 || _alive_count(state, target) <= 0) {
		return 0.0;
	}
	const bool can_shoot = _can_make_ranged_attack(state, target, battle, defended_stack);
	const bool can_strike = _can_make_melee_attack(state, target, battle, defended_stack);
	if (!can_shoot && !can_strike) {
		return 0.0;
	}
	const bool is_ranged = can_shoot;
	const int64_t attack_distance = _attack_distance_for_action(state, target, defended_stack, battle, is_ranged);
	const int64_t projected_damage = _estimate_damage(state, target, defended_stack, battle, is_ranged, false, attack_distance);
	const int64_t defended_health = engine_max<int64_t>(1, gd::int_field(state, defended_stack, key::total_health, 0));
	const int64_t defended_unit_hp = engine_max<int64_t>(1, gd::int_field(state, defended_stack, key::unit_hp, 1));
	double pressure = engine_min<double>(4.0, static_cast<double>(projected_damage) / static_cast<double>(defended_unit_hp) * 0.45);
	pressure += engine_min<double>(4.0, static_cast<double>(projected_damage) / static_cast<double>(defended_health) * 4.0);
	if (projected_damage >= defended_health) {
		pressure += 4.0;
	} else if (projected_damage >= float_to_int(godot_round(static_cast<double>(defended_health) * 0.5))) {
		pressure += 1.5;
	}
	if (can_shoot) {
		pressure += 0.75;
	}
	if (_stack_has_control_effect(state, target, battle)) {
		pressure *= 0.45;
	}
	return engine_min<double>(8.0, pressure);
}

int64_t _estimate_damage(State &state, DictRef attacker, DictRef defender, DictRef battle, bool is_ranged, bool is_retaliation, int64_t attack_distance) {
	if (!scoring_scope_open(state)) {
		return _estimate_damage_on(state, attacker, defender, battle, is_ranged, is_retaliation, attack_distance);
	}
	const Atom memo_key = pair_key(state, attacker, defender);
	for (const Value &held : gd::field_items(state, scoring_memo(state, key::_scoring_damage), str(memo_key))) {
		const ArrayRef entry = gd::as_array(held);
		if (gd::is_same(state, state.at(entry, 0), dict_value(attacker))
				&& gd::is_same(state, state.at(entry, 1), dict_value(defender))
				&& gd::is_same(state, state.at(entry, 2), dict_value(battle))
				&& gd::to_bool(state.at(entry, 3)) == is_ranged
				&& gd::to_bool(state.at(entry, 4)) == is_retaliation
				&& gd::to_int(state, state.at(entry, 5)) == attack_distance) {
			return gd::to_int(state, state.at(entry, 6));
		}
	}
	const int64_t damage = _estimate_damage_on(state, attacker, defender, battle, is_ranged, is_retaliation, attack_distance);
	const ArrayRef made = state.new_array();
	state.append(made, dict_value(attacker));
	state.append(made, dict_value(defender));
	state.append(made, dict_value(battle));
	state.append(made, bool_value(is_ranged));
	state.append(made, bool_value(is_retaliation));
	state.append(made, int_value(attack_distance));
	state.append(made, int_value(damage));
	_add_scoring_memo_entry(state, scoring_memo(state, key::_scoring_damage), memo_key, made);
	return damage;
}

int64_t _estimate_damage_on(State &state, DictRef attacker, DictRef defender, DictRef battle, bool is_ranged, bool is_retaliation, int64_t attack_distance) {
	const int64_t attacker_count = engine_max<int64_t>(1, _alive_count(state, attacker));
	const int64_t min_damage = gd::int_field(state, attacker, key::min_damage, 1);
	const int64_t max_damage = engine_max<int64_t>(min_damage, gd::int_field(state, attacker, key::max_damage, 1));
	const int64_t base_damage = gd::mul(attacker_count, float_to_int(godot_round(static_cast<double>(gd::add(min_damage, max_damage)) / 2.0)));

	// Each term in the GDScript order: the effect and contextual reads keep memos.
	int64_t attack_stat = gd::int_field(state, attacker, key::attack, 0);
	attack_stat = gd::add(attack_stat, spell_rules::effect_bonus_for_kind(state, attacker, battle, key::attack));
	attack_stat = gd::add(attack_stat, _contextual_attack_bonus(state, attacker, battle));
	int64_t defense_stat = gd::int_field(state, defender, key::defense, 0);
	defense_stat = gd::add(defense_stat, spell_rules::effect_bonus_for_kind(state, defender, battle, key::defense));
	defense_stat = gd::add(defense_stat, _contextual_defense_bonus(state, defender, battle));
	if (gd::string_field(state, defender, key::faction_id, key::empty) == key::faction_brasshollow) {
		const Atom defender_side = side_of(state, defender);
		const bool requires_overheat = _side_ability_bool(state, battle, defender_side, key::foundry_aura, key::hardening_requires_overheated, true);
		if (!requires_overheat || spell_rules::has_effect_id(state, defender, battle, key::status_overheated)) {
			defense_stat = gd::add(defense_stat, float_to_int(_side_max_ability_float(state, battle, defender_side, key::foundry_aura, key::ally_defense_bonus, 0.0)));
		}
	}
	attack_stat = gd::add(attack_stat, _hero_bonus_for_side(state, battle, side_of(state, attacker), key::attack));
	defense_stat = gd::add(defense_stat, _hero_bonus_for_side(state, battle, side_of(state, defender), key::defense));
	if (gd::bool_field(state, defender, key::defending, false)) {
		defense_stat = gd::add(defense_stat, gd::add(2, _hero_bonus_for_side(state, battle, side_of(state, defender), key::defend_defense_bonus)));
	}

	double modifier = battle_damage_rules::attack_defense_multiplier(state, attack_stat, defense_stat);
	if (is_ranged && gd::string_field(state, battle, key::terrain, key::empty) == key::forest) {
		modifier *= 0.8;
	}
	const int64_t resolved_distance = attack_distance < 0 ? gd::int_field(state, battle, key::distance, 1) : attack_distance;
	if (is_ranged && _stack_is_engaged(state, attacker, battle)) {
		modifier *= 0.6;
	}
	if (!is_ranged && gd::string_field(state, battle, key::terrain, key::empty) == key::mire) {
		modifier *= 0.9;
	}
	if (is_retaliation) {
		modifier *= 0.9;
	}
	modifier *= _cohesion_damage_modifier(state, attacker, defender, battle, is_ranged, is_retaliation);
	modifier *= _ability_damage_modifier(state, attacker, defender, battle, is_ranged, is_retaliation, resolved_distance);
	modifier *= _terrain_tag_damage_modifier(state, attacker, defender, battle, is_ranged, resolved_distance);
	modifier *= _field_objective_cover_damage_modifier(state, attacker, defender, battle, is_ranged, resolved_distance);
	modifier *= _faction_damage_modifier(state, attacker, defender, battle, is_ranged, resolved_distance);
	modifier *= _commander_damage_modifier(state, attacker, defender, battle, is_ranged, resolved_distance);
	// The arguments in the GDScript order: the payload reads keep _scoring_payloads.
	const DictRef attacker_hero = _hero_payload_for_side(state, battle, side_of(state, attacker));
	const DictRef defender_hero = _hero_payload_for_side(state, battle, side_of(state, defender));
	const Atom assault_side = battle_damage_rules::town_assault_side(state, battle);
	const bool is_town_assault = assault_side == side_of(state, attacker);
	modifier *= battle_damage_rules::hero_damage_multiplier(state, attacker_hero, defender_hero, is_ranged, is_retaliation, is_town_assault);
	modifier *= _damage_multiplier_for_side(state, battle, side_of(state, attacker));

	return engine_max<int64_t>(1, float_to_int(godot_round(static_cast<double>(base_damage) * modifier)));
}

double _cohesion_damage_modifier(State &state, DictRef attacker, DictRef defender, DictRef battle, bool is_ranged, bool is_retaliation) {
	double modifier = 1.0;
	const int64_t attacker_cohesion = _stack_cohesion_total(state, attacker, battle);
	const int64_t defender_cohesion = _stack_cohesion_total(state, defender, battle);
	const int64_t attacker_momentum = _stack_momentum_total(state, attacker, battle);
	if (attacker_cohesion >= 8) {
		modifier *= 1.05;
	} else if (attacker_cohesion <= 3) {
		modifier *= 0.9;
	}
	if (defender_cohesion <= 3) {
		modifier *= 1.08;
	} else if (defender_cohesion <= 5) {
		modifier *= 1.03;
	}
	modifier *= 1.0 + (static_cast<double>(attacker_momentum) * 0.04);
	if (is_retaliation && attacker_cohesion <= 4) {
		modifier *= 0.92;
	}
	if (is_ranged && _stack_is_isolated(state, battle, attacker)) {
		modifier *= 0.94;
	}
	return modifier;
}

double _commander_damage_modifier(State &state, DictRef attacker, DictRef defender, DictRef battle, bool is_ranged, int64_t attack_distance) {
	double modifier = 1.0;
	const Atom side = side_of(state, attacker);
	if (_hero_has_trait(state, battle, side, key::artillerist) && is_ranged && _battle_has_any_tags(state, battle, string_array(state, { key::elevated_fire, key::open_lane }))) {
		modifier *= 1.06;
	}
	if (_hero_has_trait(state, battle, side, key::linekeeper) && is_ranged && _side_defending_count(state, battle, side) > 0) {
		modifier *= 1.05;
	}
	if (_hero_has_trait(state, battle, side, key::packhunter)
			&& (_health_ratio(state, defender) <= 0.75
					|| spell_rules::has_effect_id(state, defender, battle, key::status_harried)
					|| spell_rules::has_effect_id(state, defender, battle, key::status_staggered))) {
		modifier *= 1.06;
	}
	if (_hero_has_trait(state, battle, side, key::bogwise)
			&& (_battle_has_tag(state, battle, key::bog_channels) || gd::string_field(state, battle, key::terrain, key::empty) == key::mire)
			&& (_has_ability(state, attacker, key::harry) || _has_ability(state, attacker, key::backstab) || _has_ability(state, attacker, key::bloodrush))) {
		modifier *= 1.06;
	}
	if (_hero_has_trait(state, battle, side, key::vanguard) && !is_ranged
			&& (gd::int_field(state, battle, key::round, 1) <= 2 || _battle_has_tag(state, battle, key::open_lane)) && attack_distance <= 1) {
		modifier *= 1.06;
	}
	if (_hero_has_trait(state, battle, side, key::ambusher) && !is_ranged
			&& (gd::string_field(state, battle, key::terrain, key::empty) == key::forest || _battle_has_tag(state, battle, key::ambush_cover))
			&& gd::int_field(state, battle, key::round, 1) <= 2) {
		modifier *= 1.06;
	}
	modifier *= _field_objective_commander_modifier(state, attacker, defender, battle);
	return modifier;
}

} // namespace aurelion::rules::port::battle_ai_rules
