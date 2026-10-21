// Layer 2: the damage multiplier chain.

#include "aurelion_rules/port/battle_ai_rules.hpp"
#include "aurelion_rules/port/battle_damage_rules.hpp"
#include "aurelion_rules/port/battle_rules.hpp"
#include "aurelion_rules/port/spell_rules.hpp"
#include "aurelion_rules/port/town_battle_rules.hpp"

#include <initializer_list>
#include <string>

namespace aurelion::rules::port::battle_rules {

using compat::engine_clamp;
using compat::engine_max;
using compat::engine_min;
using gd::array_value;
using gd::str;
namespace key = state::key;

namespace {

// d.get(field, []): the stored value itself, or a new empty Array.
Value get_or_new_array(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return array_value(state.new_array());
}

// An Array literal of String constants: a new Array on every evaluation.
ArrayRef string_array(State &state, std::initializer_list<Atom> atoms) {
	const ArrayRef array = state.new_array();
	for (const Atom atom : atoms) {
		state.append(array, str(atom));
	}
	return array;
}

// d.get(outer, {}).get(inner, fallback): the inner get is a Variant call, so a
// stored value that is not a Dictionary stops the script.
Value nested_get(State &state, DictRef dict, Atom outer, Atom inner, const Value &fallback) {
	Value found;
	if (!state.lookup(dict, str(outer), found)) {
		return fallback; // {}.get(inner, fallback)
	}
	if (!gd::is_dict(found)) {
		throw state::ScriptError(std::string("Invalid call. Nonexistent function 'get' in base '") + gd::type_name(found) + "'.");
	}
	return state.get(found.ref, str(inner), fallback);
}

// var x: Dictionary = d.get(field, {}): the stored Dictionary itself, a new one
// when missing; any other stored value is a failed typed assignment.
DictRef typed_dict_field(State &state, DictRef dict, Atom field) {
	Value found;
	if (!state.lookup(dict, str(field), found)) {
		return state.new_dict();
	}
	if (!gd::is_dict(found)) {
		throw state::ScriptError(std::string("Trying to assign value of type '") + gd::type_name(found) + "' to a variable of type 'Dictionary'.");
	}
	return found.ref;
}

// _health_ratio(stack) <= float(ability.get(field, fallback)), the left
// operand first, as GDScript evaluates it.
bool health_ratio_at_most(State &state, DictRef stack, DictRef ability, Atom field, double fallback) {
	const double ratio = _health_ratio(state, stack);
	return ratio <= gd::float_field(state, ability, field, fallback);
}

// float(flare.get("ability", {}).get("ambush_bonus_retention", 1.0)) if not
// flare.is_empty() else 1.0.
double ambush_retention(State &state, DictRef flare) {
	if (gd::is_empty(state, flare)) {
		return 1.0;
	}
	return gd::to_float(nested_get(state, flare, key::ability, key::ambush_bonus_retention, gd::float_value(1.0)));
}

} // namespace

int64_t _damage_for_roll(State &state, DictRef attacker, DictRef defender, DictRef battle, int64_t base_roll, bool is_ranged, bool is_retaliation, int64_t attack_distance) {
	const int64_t base_damage = gd::mul(engine_max<int64_t>(1, _alive_count(state, attacker)), base_roll);
	const double modifier = _damage_modifier(state, attacker, defender, battle, is_ranged, is_retaliation, attack_distance);
	return engine_max<int64_t>(1, compat::float_to_int(compat::godot_round(static_cast<double>(base_damage) * modifier)));
}

double _damage_modifier(State &state, DictRef attacker, DictRef defender, DictRef battle, bool is_ranged, bool is_retaliation, int64_t attack_distance) {
	const int64_t attack_bonus = gd::int_field(state, _hero_payload_for_side(state, battle, gd::string_field(state, attacker, key::side, key::empty)), key::attack, 0);
	const int64_t defense_bonus = gd::int_field(state, _hero_payload_for_side(state, battle, gd::string_field(state, defender, key::side, key::empty)), key::defense, 0);
	const int64_t attack_stat = gd::add(_stack_attack_total(state, attacker, battle), attack_bonus);
	int64_t defense_stat = gd::add(_stack_defense_total(state, defender, battle), defense_bonus);
	const DictRef attacker_hero = _hero_payload_for_side(state, battle, gd::string_field(state, attacker, key::side, key::empty));
	const DictRef defender_hero = _hero_payload_for_side(state, battle, gd::string_field(state, defender, key::side, key::empty));
	if (gd::bool_field(state, defender, key::defending, false)) {
		defense_stat = gd::add(defense_stat, gd::add(2, gd::int_field(state, defender_hero, key::defend_defense_bonus, 0)));
	}

	double modifier = battle_damage_rules::attack_defense_multiplier(attack_stat, defense_stat);
	const int64_t resolved_distance = attack_distance < 0 ? gd::int_field(state, battle, key::distance, 1) : attack_distance;
	if (is_ranged && gd::string_field(state, battle, key::terrain, key::empty) == key::forest) {
		modifier *= 0.8;
	}
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
	modifier *= town_battle_rules::damage_multiplier(state, battle, attacker, defender, is_ranged);
	const Atom assault_side = battle_damage_rules::town_assault_side(state, battle);
	const bool is_town_assault = assault_side == gd::string_field(state, attacker, key::side, key::empty);
	modifier *= battle_damage_rules::hero_damage_multiplier(state, attacker_hero, defender_hero, is_ranged, is_retaliation, is_town_assault);
	modifier *= gd::float_field(state, attacker_hero, key::damage_multiplier, 1.0);
	return modifier;
}

double _ranged_damage_return_ratio(State &state, DictRef stack) {
	const DictRef shielding = _ability_by_id(state, stack, key::shielding);
	if (gd::is_empty(state, shielding)) {
		return 0.0;
	}
	return engine_clamp(gd::float_field(state, shielding, key::ranged_damage_return_ratio, 0.0), 0.0, 0.25);
}

double _ability_damage_modifier(State &state, DictRef attacker, DictRef defender, DictRef battle, bool is_ranged, bool is_retaliation, int64_t attack_distance) {
	double modifier = 1.0;
	const DictRef reach = _ability_by_id(state, attacker, key::reach);
	if (!is_ranged && attack_distance == 1 && !gd::is_empty(state, reach) && _reach_available(state, attacker, battle)) {
		modifier *= gd::float_field(state, reach, key::distance_one_multiplier, 1.0);
	}
	const DictRef hookline = _ability_by_id(state, attacker, key::hookline);
	if (!is_ranged && attack_distance == 1 && !gd::is_empty(state, hookline) && _hookline_available(state, attacker, battle)) {
		modifier *= gd::float_field(state, hookline, key::distance_one_multiplier, 0.5);
	}

	const DictRef brace = _ability_by_id(state, attacker, key::brace);
	if (is_retaliation && gd::bool_field(state, attacker, key::defending, false) && !gd::is_empty(state, brace) && _brace_available(state, attacker, battle)) {
		modifier *= gd::float_field(state, brace, key::retaliation_multiplier, 1.0);
		if (_brace_has_held_objective(state, attacker, battle, brace)) {
			modifier *= gd::float_field(state, brace, key::held_objective_retaliation_multiplier, 1.0);
		}
	}
	if (is_retaliation) {
		const DictRef charter_aura = _charter_retaliation_aura_context(state, attacker, battle);
		const DictRef aura_ability = typed_dict_field(state, charter_aura, key::ability);
		if (!gd::is_empty(state, charter_aura) && (!gd::bool_field(state, aura_ability, key::ally_retaliation_requires_defending, true) || gd::bool_field(state, attacker, key::defending, false))) {
			modifier *= gd::to_float(nested_get(state, charter_aura, key::ability, key::ally_retaliation_multiplier, gd::float_value(1.0)));
		}
	}
	const DictRef bramble_ground = _bramble_ground_ability(state, attacker);
	if (is_retaliation && gd::bool_field(state, attacker, key::defending, false) && !gd::is_empty(state, bramble_ground) && _bramble_ground_available(state, attacker, battle, bramble_ground)) {
		modifier *= gd::float_field(state, bramble_ground, key::retaliation_multiplier, 1.0);
	}
	if (is_retaliation) {
		const int64_t retaliation_pressure = spell_rules::effect_bonus_for_kind(state, attacker, battle, key::retaliation);
		if (retaliation_pressure < 0) {
			modifier *= engine_clamp(1.0 + (static_cast<double>(retaliation_pressure) / 100.0), 0.25, 1.0);
		}
	}

	const DictRef backstab = _ability_by_id(state, attacker, key::backstab);
	const DictRef backstab_flare = _counter_ambush_flare_context(state, battle, defender, key::backstab);
	const double backstab_retention = ambush_retention(state, backstab_flare);
	const bool backstab_attack_eligible = !gd::bool_field(state, backstab, key::primary_melee_only, false) || (!is_ranged && !is_retaliation);
	if (!gd::is_empty(state, backstab) && backstab_attack_eligible && spell_rules::has_any_effect_ids(state, defender, battle, get_or_new_array(state, backstab, key::status_ids))) {
		modifier *= 1.0 + ((gd::float_field(state, backstab, key::damage_multiplier, 1.0) - 1.0) * backstab_retention);
	}
	if (!gd::is_empty(state, backstab) && backstab_attack_eligible && health_ratio_at_most(state, defender, backstab, key::health_threshold_ratio, 0.0)) {
		modifier *= 1.0 + ((gd::float_field(state, backstab, key::threshold_damage_multiplier, 1.0) - 1.0) * backstab_retention);
	}
	if (
			!gd::is_empty(state, bramble_ground) && !is_ranged && !is_retaliation && spell_rules::has_effect_id(state, defender, battle, gd::string_field(state, bramble_ground, key::status_id, key::status_rooted))) {
		modifier *= gd::float_field(state, bramble_ground, key::rooted_damage_multiplier, 1.0);
	}
	const DictRef fogwake = _ability_by_id(state, attacker, key::fogwake);
	if (!is_ranged && !is_retaliation && !gd::is_empty(state, fogwake) && _stack_is_hex_isolated(state, battle, defender)) {
		const DictRef fogwake_flare = _counter_ambush_flare_context(state, battle, defender, key::fogwake);
		const double fogwake_retention = ambush_retention(state, fogwake_flare);
		modifier *= 1.0 + ((gd::float_field(state, fogwake, key::isolated_damage_multiplier, 1.0) - 1.0) * fogwake_retention);
	}

	const DictRef volley = _ability_by_id(state, attacker, key::volley);
	const bool volley_lane_ready = _volley_has_protected_lane(state, attacker, battle, volley);
	if (is_ranged && !gd::is_empty(state, volley) && volley_lane_ready && attack_distance >= gd::int_field(state, volley, key::min_distance, 1)) {
		modifier *= gd::float_field(state, volley, key::damage_multiplier, 1.0);
	}
	if (is_ranged && !gd::is_empty(state, volley) && volley_lane_ready && spell_rules::has_any_effect_ids(state, defender, battle, get_or_new_array(state, volley, key::status_ids))) {
		modifier *= gd::float_field(state, volley, key::status_damage_multiplier, 1.0);
	}
	if (is_ranged && !gd::is_empty(state, volley) && volley_lane_ready && _side_defending_count(state, battle, gd::string_field(state, attacker, key::side, key::empty)) > 0) {
		modifier *= gd::float_field(state, volley, key::ally_defending_multiplier, 1.0);
	}

	const DictRef formation_guard = _ability_by_id(state, attacker, key::formation_guard);
	if (!gd::is_empty(state, formation_guard) && spell_rules::has_effect_id(state, defender, battle, key::status_staggered)) {
		modifier *= gd::float_field(state, formation_guard, key::staggered_damage_multiplier, 1.0);
	}

	const DictRef harry = _ability_by_id(state, attacker, key::harry);
	if (is_ranged && !gd::is_empty(state, harry) && health_ratio_at_most(state, defender, harry, key::wounded_threshold_ratio, 0.0)) {
		modifier *= gd::float_field(state, harry, key::wounded_damage_multiplier, 1.0);
	}
	const DictRef authored_harry = _authored_ability_by_id(state, attacker, key::harry);
	const DictRef defender_shielding = _authored_ability_by_id(state, defender, key::shielding);
	if (is_ranged && !gd::is_empty(state, harry) && gd::bool_field(state, defender_shielding, key::snare_vulnerable, false)) {
		modifier *= gd::float_field(state, authored_harry, key::shielding_damage_multiplier, 1.0);
	}
	const DictRef rot_cant = _ability_by_id(state, attacker, key::rot_cant);
	// int(battle.get("round", 1)) >= int(rot_cant.get("available_from_round", 1)), left first.
	const auto rot_cant_round_reached = [&]() {
		const int64_t current_round = gd::int_field(state, battle, key::round, 1);
		return current_round >= gd::int_field(state, rot_cant, key::available_from_round, 1);
	};
	if (is_ranged && !gd::is_empty(state, rot_cant) && rot_cant_round_reached() && health_ratio_at_most(state, defender, rot_cant, key::wounded_threshold_ratio, 0.0)) {
		modifier *= gd::float_field(state, rot_cant, key::wounded_damage_multiplier, 1.0);
	}

	const DictRef bloodrush = _ability_by_id(state, attacker, key::bloodrush);
	if (!gd::is_empty(state, bloodrush) && gd::bool_field(state, bloodrush, key::primary_melee_only, false)) {
		const bool bloodrush_attack_eligible = !is_ranged && !is_retaliation;
		const bool bloodrush_isolated = bloodrush_attack_eligible && gd::float_field(state, bloodrush, key::isolated_damage_multiplier, 1.0) > 1.0 && _stack_is_hex_isolated(state, battle, defender);
		const bool bloodrush_prepared = (health_ratio_at_most(state, defender, bloodrush, key::wounded_threshold_ratio, 0.0) || spell_rules::has_any_effect_ids(state, defender, battle, get_or_new_array(state, bloodrush, key::status_ids)) || bloodrush_isolated);
		if (bloodrush_attack_eligible && !bloodrush_prepared) {
			modifier *= gd::float_field(state, bloodrush, key::clean_target_damage_multiplier, 1.0);
		}
		if (bloodrush_attack_eligible && health_ratio_at_most(state, defender, bloodrush, key::wounded_threshold_ratio, 0.0)) {
			modifier *= gd::float_field(state, bloodrush, key::wounded_damage_multiplier, 1.0);
		}
		if (bloodrush_attack_eligible && spell_rules::has_any_effect_ids(state, defender, battle, get_or_new_array(state, bloodrush, key::status_ids))) {
			modifier *= gd::float_field(state, bloodrush, key::status_damage_multiplier, 1.0);
		}
		if (bloodrush_isolated) {
			modifier *= gd::float_field(state, bloodrush, key::isolated_damage_multiplier, 1.0);
		}
	} else {
		const bool bloodrush_prepared = !gd::is_empty(state, bloodrush) && (health_ratio_at_most(state, defender, bloodrush, key::wounded_threshold_ratio, 0.0) || spell_rules::has_any_effect_ids(state, defender, battle, get_or_new_array(state, bloodrush, key::status_ids)));
		if (!gd::is_empty(state, bloodrush) && !is_retaliation && !bloodrush_prepared) {
			modifier *= gd::float_field(state, bloodrush, key::clean_target_damage_multiplier, 1.0);
		}
		if (!gd::is_empty(state, bloodrush) && health_ratio_at_most(state, defender, bloodrush, key::wounded_threshold_ratio, 0.0)) {
			modifier *= gd::float_field(state, bloodrush, key::wounded_damage_multiplier, 1.0);
		}
		if (!gd::is_empty(state, bloodrush) && spell_rules::has_any_effect_ids(state, defender, battle, get_or_new_array(state, bloodrush, key::status_ids))) {
			modifier *= gd::float_field(state, bloodrush, key::status_damage_multiplier, 1.0);
		}
	}

	const DictRef overheat = _ability_by_id(state, attacker, key::overheat);
	if (!gd::is_empty(state, overheat)) {
		if (spell_rules::has_effect_id(state, attacker, battle, key::status_overheated)) {
			modifier *= gd::float_field(state, overheat, key::overheated_damage_multiplier, 1.0);
		} else if (!is_retaliation) {
			modifier *= gd::float_field(state, overheat, key::burst_damage_multiplier, 1.0);
		}
	}

	const DictRef shielding = _ability_by_id(state, defender, key::shielding);
	if (is_ranged && !gd::is_empty(state, shielding)) {
		modifier *= gd::float_field(state, shielding, key::ranged_damage_multiplier, 1.0);
	}
	const DictRef fog_screen = _fog_screen_ability(state, defender);
	if (!gd::is_empty(state, fog_screen) && _fog_screen_available(state, defender, battle, fog_screen)) {
		modifier *= gd::float_field(state, fog_screen, key::incoming_damage_multiplier, 1.0);
	}
	if (is_ranged) {
		modifier *= _linked_ranged_attack_screen_multiplier(state, defender, battle);
	}
	if (!is_ranged && attack_distance <= 0 && (gd::bool_field(state, defender, key::ranged, false) || !gd::is_empty(state, shielding))) {
		int64_t screen_reduction_pct = _side_max_ability_int(
				state,
				battle,
				gd::string_field(state, defender, key::side, key::empty),
				key::shielding,
				key::ally_ranged_melee_damage_reduction_pct);
		if (_brace_available(state, attacker, battle) || _reach_available(state, attacker, battle)) {
			const int64_t linebreaker_bonus = _side_max_ability_int(
					state,
					battle,
					gd::string_field(state, defender, key::side, key::empty),
					key::shielding,
					key::linebreaker_screen_bonus_pct);
			screen_reduction_pct = gd::add(screen_reduction_pct, linebreaker_bonus);
		}
		if (gd::bool_field(state, defender, key::ranged, false) && _has_ability(state, attacker, key::bloodrush)) {
			const int64_t committed_reduction = _side_max_authored_ability_int(
					state,
					battle,
					gd::string_field(state, defender, key::side, key::empty),
					key::shielding,
					key::committed_assault_screen_reduction_pct);
			screen_reduction_pct = gd::add(screen_reduction_pct, committed_reduction);
		}
		screen_reduction_pct = engine_clamp<int64_t>(screen_reduction_pct, 0, 75);
		modifier *= 1.0 - (static_cast<double>(screen_reduction_pct) / 100.0);
	}
	const DictRef attacking_shielding = _ability_by_id(state, attacker, key::shielding);
	if (!is_ranged && !gd::is_empty(state, attacking_shielding) && attack_distance <= 0) {
		modifier *= gd::float_field(state, attacking_shielding, key::engaged_damage_multiplier, 1.0);
	}
	// attacking_shielding.get("payoff_status_ids", [STATUS_HARRIED]).
	const auto payoff_status_ids = [&]() {
		Value found;
		if (state.lookup(attacking_shielding, str(key::payoff_status_ids), found)) {
			return found;
		}
		return array_value(string_array(state, { key::status_harried }));
	};
	if (!is_ranged && !gd::is_empty(state, attacking_shielding) && spell_rules::has_any_effect_ids(state, defender, battle, payoff_status_ids())) {
		modifier *= gd::float_field(state, attacking_shielding, key::harried_damage_multiplier, 1.0);
	}
	if (!is_ranged) {
		modifier *= _solar_array_lane_melee_multiplier(state, defender, battle);
	}

	return modifier;
}

double _solar_array_lane_melee_multiplier(State &state, DictRef defender, DictRef battle) {
	if (gd::string_field(state, defender, key::faction_id, key::empty) != key::faction_sunvault || !gd::bool_field(state, defender, key::ranged, false)) {
		return 1.0;
	}
	const Atom side = gd::string_field(state, defender, key::side, key::empty);
	const ArrayRef sources = _alive_stacks_for_side(state, battle, side);
	for (const Value &source : gd::items(state, array_value(sources))) {
		const DictRef ability = _ability_by_id(state, gd::as_dict(source), key::solar_array_lane);
		if (gd::is_empty(state, ability) || !_side_has_linked_unit(state, battle, side, get_or_new_array(state, ability, key::linked_unit_ids))) {
			continue;
		}
		return gd::float_field(state, ability, key::incoming_melee_damage_multiplier, 1.0);
	}
	return 1.0;
}

double _faction_damage_modifier(State &state, DictRef attacker, DictRef defender, DictRef battle, bool is_ranged, int64_t attack_distance) {
	double modifier = 1.0;
	const Atom faction_id = gd::string_field(state, attacker, key::faction_id, key::empty);
	const Atom side = gd::string_field(state, attacker, key::side, key::empty);
	const int64_t side_defending_count = _side_defending_count(state, battle, side);
	if (faction_id == key::faction_embercourt) {
		if (is_ranged && side_defending_count > 0) {
			modifier *= 1.08;
			if (_side_has_ability(state, battle, side, key::formation_guard)) {
				modifier *= _side_max_ability_float(
						state,
						battle,
						side,
						key::formation_guard,
						key::ally_ranged_damage_multiplier,
						1.0);
			}
		}
		if (spell_rules::has_effect_id(state, defender, battle, key::status_staggered)) {
			modifier *= 1.08;
		}
		if (gd::int_field(state, battle, key::round, 1) >= 3 && _side_has_role_mix(state, battle, side)) {
			modifier *= _side_has_ability(state, battle, side, key::formation_guard) ? 1.06 : 1.04;
		}
	} else if (faction_id == key::faction_mireclaw) {
		const int64_t wounded_count = _enemy_wounded_count(state, battle, side);
		if (wounded_count > 0) {
			modifier *= 1.0 + (static_cast<double>(engine_min<int64_t>(wounded_count, 3)) * 0.04);
		}
		if (spell_rules::has_effect_id(state, defender, battle, key::status_harried)) {
			modifier *= 1.08;
		}
		if (!is_ranged && gd::int_field(state, battle, key::round, 1) >= 3 && attack_distance <= 0) {
			modifier *= 1.0 + (static_cast<double>(engine_min<int64_t>(wounded_count, 2)) * 0.03);
		}
	} else if (faction_id == key::faction_sunvault) {
		const int64_t positive_effect_count = _side_positive_effect_count(state, battle, side);
		if (_stack_has_positive_effect(state, attacker, battle)) {
			modifier *= 1.08;
			if (_battle_has_any_tags(state, battle, string_array(state, { key::elevated_fire, key::fortified_line }))) {
				modifier *= 1.04;
			}
		}
		const DictRef resonance_relay = _side_resonance_relay(state, battle, side);
		const int64_t relay_minimum = gd::int_field(state, resonance_relay, key::minimum_calibrated_stacks, 2);
		if (!gd::is_empty(state, resonance_relay) && positive_effect_count >= relay_minimum) {
			const int64_t calibrated_count = engine_min<int64_t>(positive_effect_count, gd::int_field(state, resonance_relay, key::maximum_calibrated_stacks, 3));
			modifier *= 1.0 + (static_cast<double>(calibrated_count) * gd::float_field(state, resonance_relay, key::line_damage_per_calibrated_stack, 0.0));
		}
		if (spell_rules::has_effect_id(state, defender, battle, key::status_staggered)) {
			modifier *= 1.05;
		}
		if (is_ranged && _battle_has_any_tags(state, battle, string_array(state, { key::elevated_fire, key::open_lane })) && positive_effect_count > 0) {
			modifier *= 1.04;
		}
	} else if (faction_id == key::faction_thornwake) {
		if (spell_rules::has_effect_id(state, defender, battle, key::status_rooted)) {
			modifier *= 1.10;
		}
		if (spell_rules::has_any_effect_ids(state, defender, battle, array_value(string_array(state, { key::status_harried, key::status_staggered })))) {
			modifier *= 1.07;
		}
		if (_battle_has_any_tags(state, battle, string_array(state, { key::chokepoint, key::ambush_cover, key::fortified_line })) && !is_ranged) {
			modifier *= 1.05;
		}
		if (gd::int_field(state, battle, key::round, 1) >= 4 && _side_defending_count(state, battle, side) > 0) {
			modifier *= 1.04;
		}
	} else if (faction_id == key::faction_brasshollow) {
		if (_battle_has_any_tags(state, battle, string_array(state, { key::fortress_lane, key::wall_pressure, key::battery_nest }))) {
			modifier *= 1.05;
		}
		if (is_ranged && attack_distance >= 2) {
			modifier *= 1.04;
		}
		const double pressure_multiplier = _side_max_ability_float(
				state,
				battle,
				side,
				key::shielding,
				key::brasshollow_pressure_damage_multiplier,
				1.0);
		if (pressure_multiplier > 1.0 && gd::int_field(state, battle, key::round, 1) >= 3) {
			modifier *= pressure_multiplier;
		}
	} else if (faction_id == key::faction_veilmourn) {
		if (_stack_is_isolated(state, battle, defender)) {
			modifier *= 1.08;
		}
		if (spell_rules::has_any_effect_ids(state, defender, battle, array_value(string_array(state, { key::status_harried, key::status_staggered })))) {
			modifier *= 1.06;
		}
		if (_battle_has_any_tags(state, battle, string_array(state, { key::fog_bank, key::ambush_cover })) && !is_ranged) {
			modifier *= 1.05;
		}
	}
	return modifier;
}

double _terrain_tag_damage_modifier(State &state, DictRef attacker, DictRef defender, DictRef battle, bool is_ranged, int64_t attack_distance) {
	double modifier = 1.0;
	if (_battle_has_tag(state, battle, key::elevated_fire) && is_ranged && attack_distance > 0) {
		modifier *= 1.1;
	}
	if (_battle_has_tag(state, battle, key::open_lane) && is_ranged && attack_distance > 0) {
		modifier *= 1.06;
	}
	if (_battle_has_any_tags(state, battle, string_array(state, { key::chokepoint, key::fortified_line }))) {
		if (!is_ranged && attack_distance <= 1 && (_reach_available(state, attacker, battle) || _brace_available(state, attacker, battle) || _has_ability(state, attacker, key::formation_guard))) {
			modifier *= 1.08;
		} else if (is_ranged && attack_distance > 0) {
			modifier *= 0.92;
		}
	}
	if (_battle_has_tag(state, battle, key::ambush_cover)) {
		if (!is_ranged && gd::int_field(state, battle, key::round, 1) <= 2) {
			modifier *= 1.08;
		} else if (is_ranged && attack_distance > 0) {
			modifier *= 0.94;
		}
	}
	if (_battle_has_tag(state, battle, key::bog_channels) && (_has_ability(state, attacker, key::harry) || _has_ability(state, attacker, key::backstab) || _has_ability(state, attacker, key::bloodrush) || spell_rules::has_effect_id(state, defender, battle, key::status_harried))) {
		modifier *= 1.08;
	}
	if (_battle_has_tag(state, battle, key::fog_bank) && is_ranged && attack_distance > 0 && !battle_ai_rules::faction_brings_tag(state, attacker, key::fog_bank)) {
		modifier *= 0.88;
	}
	return modifier;
}

double _commander_damage_modifier(State &state, DictRef attacker, DictRef defender, DictRef battle, bool is_ranged, int64_t attack_distance) {
	double modifier = 1.0;
	const Atom side = gd::string_field(state, attacker, key::side, key::empty);
	if (_hero_has_trait(state, battle, side, key::artillerist) && is_ranged && _battle_has_any_tags(state, battle, string_array(state, { key::elevated_fire, key::open_lane }))) {
		modifier *= 1.06;
	}
	if (_hero_has_trait(state, battle, side, key::linekeeper) && is_ranged && _side_defending_count(state, battle, side) > 0) {
		modifier *= 1.05;
	}
	if (_hero_has_trait(state, battle, side, key::packhunter) && (_health_ratio(state, defender) <= 0.75 || spell_rules::has_effect_id(state, defender, battle, key::status_harried) || spell_rules::has_effect_id(state, defender, battle, key::status_staggered))) {
		modifier *= 1.06;
	}
	if (_hero_has_trait(state, battle, side, key::bogwise) && (_battle_has_tag(state, battle, key::bog_channels) || gd::string_field(state, battle, key::terrain, key::empty) == key::mire) && (_has_ability(state, attacker, key::harry) || _has_ability(state, attacker, key::backstab) || _has_ability(state, attacker, key::bloodrush))) {
		modifier *= 1.06;
	}
	if (_hero_has_trait(state, battle, side, key::vanguard) && !is_ranged && (gd::int_field(state, battle, key::round, 1) <= 2 || _battle_has_tag(state, battle, key::open_lane)) && attack_distance <= 1) {
		modifier *= 1.06;
	}
	if (_hero_has_trait(state, battle, side, key::ambusher) && !is_ranged && (gd::string_field(state, battle, key::terrain, key::empty) == key::forest || _battle_has_tag(state, battle, key::ambush_cover)) && gd::int_field(state, battle, key::round, 1) <= 2) {
		modifier *= 1.06;
	}
	modifier *= _field_objective_commander_modifier(state, attacker, defender, battle);
	return modifier;
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

double _linked_ranged_attack_screen_multiplier(State &state, DictRef defender, DictRef battle) {
	if (!gd::bool_field(state, defender, key::ranged, false)) {
		return 1.0;
	}
	const Atom defender_unit_id = gd::string_field(state, defender, key::unit_id, key::empty);
	int64_t best_reduction_pct = 0;
	const ArrayRef sources = _alive_stacks_for_side(state, battle, gd::string_field(state, defender, key::side, key::empty));
	for (const Value &source : gd::items(state, array_value(sources))) {
		if (gd::is_empty(state, _ability_by_id(state, gd::as_dict(source), key::shielding))) {
			continue;
		}
		const DictRef shielding = _authored_ability_by_id(state, gd::as_dict(source), key::shielding);
		const Value linked_unit_ids = get_or_new_array(state, shielding, key::linked_ranged_unit_ids);
		if (gd::is_array(linked_unit_ids) && gd::array_has(state, linked_unit_ids.ref, str(defender_unit_id))) {
			best_reduction_pct = engine_max<int64_t>(best_reduction_pct, gd::int_field(state, shielding, key::linked_ranged_damage_reduction_pct, 0));
		}
	}
	return 1.0 - (static_cast<double>(engine_clamp<int64_t>(best_reduction_pct, 0, 50)) / 100.0);
}

double _field_objective_commander_modifier(State &state, DictRef attacker, DictRef defender, DictRef battle) {
	double modifier = 1.0;
	const Atom attacker_side = gd::string_field(state, attacker, key::side, key::empty);
	const Atom defender_side = gd::string_field(state, defender, key::side, key::empty);
	if (_side_controls_field_objective_type(state, battle, attacker_side, key::cover_line) && gd::int_field(state, battle, key::distance, 1) > 0) {
		modifier *= 1.06;
	}
	if (_side_controls_field_objective_type(state, battle, defender_side, key::cover_line) && gd::int_field(state, battle, key::distance, 1) > 0) {
		modifier *= 0.94;
	}
	if (_side_controls_field_objective_type(state, battle, attacker_side, key::signal_beacon)) {
		modifier *= 1.05;
	}
	if (_side_controls_field_objective_type(state, battle, defender_side, key::signal_beacon)) {
		modifier *= 0.95;
	}
	if (
			!gd::bool_field(state, attacker, key::ranged, false) && _side_controls_field_objective_type(state, battle, defender_side, key::obstruction_line) && gd::int_field(state, battle, key::distance, 1) > 0) {
		modifier *= 0.94;
	}
	if (
			!gd::bool_field(state, attacker, key::ranged, false) && _side_controls_field_objective_type(state, battle, attacker_side, key::obstruction_line) && gd::int_field(state, battle, key::round, 1) >= 2) {
		modifier *= 1.04;
	}
	if (_side_controls_field_objective_type(state, battle, attacker_side, key::ritual_pylon)) {
		modifier *= 1.03;
	}
	return modifier;
}

bool _stack_is_cover_screened(State &state, DictRef stack, DictRef battle) {
	if (gd::is_empty(state, stack)) {
		return false;
	}
	if (gd::bool_field(state, stack, key::ranged, false)) {
		return true;
	}
	if (_has_ability(state, stack, key::formation_guard) || _brace_available(state, stack, battle)) {
		return true;
	}
	return gd::bool_field(state, stack, key::defending, false) && !_stack_is_isolated(state, battle, stack);
}

double _field_objective_cover_damage_modifier(State &state, DictRef attacker, DictRef defender, DictRef battle, bool is_ranged, int64_t attack_distance) {
	if (!is_ranged || attack_distance <= 0) {
		return 1.0;
	}
	double modifier = 1.0;
	const Atom attacker_side = gd::string_field(state, attacker, key::side, key::empty);
	const Atom defender_side = gd::string_field(state, defender, key::side, key::empty);
	if (_side_controls_field_objective_type(state, battle, defender_side, key::cover_line)) {
		modifier *= _stack_is_cover_screened(state, defender, battle) ? 0.85 : 0.93;
	}
	if (_side_controls_field_objective_type(state, battle, attacker_side, key::cover_line) && _stack_is_cover_screened(state, attacker, battle)) {
		modifier *= 1.08;
	}
	return modifier;
}

} // namespace aurelion::rules::port::battle_rules
