// Slice 08: BattleAiRules' own copies of the damage modifiers (abilities,
// faction, terrain tags), the field objectives' bonuses and influence, and the
// side reads they use. The copies walk a side's living stacks through the AI's
// _alive_stacks_for_side and its scoring memo, as the GDScript does, so they do
// not call the BattleRules port of the same name.

#include "aurelion_rules/port/battle_ai_rules.hpp"
#include "aurelion_rules/port/battle_rules.hpp"
#include "aurelion_rules/port/spell_rules.hpp"

#include "aurelion_rules/compat/godot_math.hpp"

#include <initializer_list>
#include <string>

namespace aurelion::rules::port::battle_ai_rules {

using compat::engine_clamp;
using compat::engine_max;
using compat::engine_min;
using compat::float_to_int;
using gd::array_value;
using gd::dict_value;
using gd::str;
using state::Kind;
namespace key = state::key;

namespace {

bool empty(const State &state, DictRef dict) {
	return gd::is_empty(state, dict);
}

// d.get(key, []): the field, or a new empty Array.
Value field_or_array(State &state, DictRef dict, Atom field) {
	Value out;
	if (state.lookup(dict, str(field), out)) {
		return out;
	}
	return array_value(state.new_array());
}

// value.get(key, {}) on an untyped value: a Dictionary's field, or a new
// empty one. GDScript stops on any other base.
Value get_or_empty_dict(State &state, const Value &base, Atom field) {
	if (!gd::is_dict(base)) {
		throw state::ScriptError(std::string("Invalid call. Nonexistent function 'get' in base '") + gd::type_name(base) + "'.");
	}
	Value out;
	if (state.lookup(base.ref, str(field), out)) {
		return out;
	}
	return dict_value(state.new_dict());
}

// value.get(key, fallback) on an untyped value.
Value get_or_empty_dict_value(State &state, const Value &base, Atom field, const Value &fallback) {
	if (!gd::is_dict(base)) {
		throw state::ScriptError(std::string("Invalid call. Nonexistent function 'get' in base '") + gd::type_name(base) + "'.");
	}
	return state.get(base.ref, str(field), fallback);
}

// var x: Dictionary = value.
DictRef typed_dict(const Value &value) {
	if (!gd::is_dict(value)) {
		throw state::ScriptError(std::string("Trying to assign value of type '") + gd::type_name(value) + "' to a variable of type 'Dictionary'.");
	}
	return value.ref;
}

ArrayRef string_array(State &state, std::initializer_list<Atom> atoms) {
	const ArrayRef array = state.new_array();
	for (const Atom atom : atoms) {
		state.append(array, str(atom));
	}
	return array;
}

// _battle_has_any_tags(battle, [...]) of a literal list.
bool any_tag(State &state, DictRef battle, std::initializer_list<Atom> tags) {
	for (const Atom tag : tags) {
		if (_battle_has_tag(state, battle, tag)) {
			return true;
		}
	}
	return false;
}

Atom side_of(const State &state, DictRef stack) {
	return gd::string_field(state, stack, key::side, key::empty);
}

bool ranged(const State &state, DictRef stack) {
	return gd::bool_field(state, stack, key::ranged, false);
}

int64_t battle_round(const State &state, DictRef battle) {
	return gd::int_field(state, battle, key::round, 1);
}

int64_t battle_distance(const State &state, DictRef battle) {
	return gd::int_field(state, battle, key::distance, 1);
}

// float(flare.get("ability", {}).get("ambush_bonus_retention", 1.0)) when a
// counter-ambush flare covers the defender, else 1.0.
double ambush_retention(State &state, DictRef flare) {
	if (empty(state, flare)) {
		return 1.0;
	}
	const Value ability = get_or_empty_dict(state, dict_value(flare), key::ability);
	return gd::to_float(get_or_empty_dict_value(state, ability, key::ambush_bonus_retention, gd::float_value(1.0)));
}

} // namespace

double _ability_damage_modifier(State &state, DictRef attacker, DictRef defender, DictRef battle, bool is_ranged, bool is_retaliation, int64_t attack_distance) {
	double modifier = 1.0;
	const DictRef reach = _ability_by_id(state, attacker, key::reach);
	if (!is_ranged && attack_distance == 1 && !empty(state, reach) && _reach_available(state, attacker, battle)) {
		modifier *= gd::float_field(state, reach, key::distance_one_multiplier, 1.0);
	}
	const DictRef hookline = _ability_by_id(state, attacker, key::hookline);
	if (!is_ranged && attack_distance == 1 && !empty(state, hookline) && _hookline_available(state, attacker, battle)) {
		modifier *= gd::float_field(state, hookline, key::distance_one_multiplier, 0.5);
	}

	const DictRef brace = _ability_by_id(state, attacker, key::brace);
	if (is_retaliation && gd::bool_field(state, attacker, key::defending, false) && !empty(state, brace) && _brace_available(state, attacker, battle)) {
		modifier *= gd::float_field(state, brace, key::retaliation_multiplier, 1.0);
		if (_brace_has_held_objective(state, attacker, battle, brace)) {
			modifier *= gd::float_field(state, brace, key::held_objective_retaliation_multiplier, 1.0);
		}
	}
	if (is_retaliation) {
		const DictRef charter_aura = _charter_retaliation_aura_context(state, attacker, battle);
		const DictRef aura_ability = typed_dict(get_or_empty_dict(state, dict_value(charter_aura), key::ability));
		if (!empty(state, charter_aura) && (!gd::bool_field(state, aura_ability, key::ally_retaliation_requires_defending, true) || gd::bool_field(state, attacker, key::defending, false))) {
			const Value ability = get_or_empty_dict(state, dict_value(charter_aura), key::ability);
			modifier *= gd::to_float(get_or_empty_dict_value(state, ability, key::ally_retaliation_multiplier, gd::float_value(1.0)));
		}
	}
	const DictRef bramble_ground = _bramble_ground_ability(state, attacker);
	if (is_retaliation && gd::bool_field(state, attacker, key::defending, false) && !empty(state, bramble_ground) && _bramble_ground_available(state, attacker, battle, bramble_ground)) {
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
	if (!empty(state, backstab) && backstab_attack_eligible && spell_rules::has_any_effect_ids(state, defender, battle, field_or_array(state, backstab, key::status_ids))) {
		modifier *= 1.0 + ((gd::float_field(state, backstab, key::damage_multiplier, 1.0) - 1.0) * backstab_retention);
	}
	if (!empty(state, backstab) && backstab_attack_eligible && _health_ratio(state, defender) <= gd::float_field(state, backstab, key::health_threshold_ratio, 0.0)) {
		modifier *= 1.0 + ((gd::float_field(state, backstab, key::threshold_damage_multiplier, 1.0) - 1.0) * backstab_retention);
	}
	if (!empty(state, bramble_ground) && !is_ranged && !is_retaliation
			&& spell_rules::has_effect_id(state, defender, battle, gd::string_field(state, bramble_ground, key::status_id, key::status_rooted))) {
		modifier *= gd::float_field(state, bramble_ground, key::rooted_damage_multiplier, 1.0);
	}
	const DictRef fogwake = _ability_by_id(state, attacker, key::fogwake);
	if (!is_ranged && !is_retaliation && !empty(state, fogwake) && _stack_is_hex_isolated(state, battle, defender)) {
		const DictRef fogwake_flare = _counter_ambush_flare_context(state, battle, defender, key::fogwake);
		const double fogwake_retention = ambush_retention(state, fogwake_flare);
		modifier *= 1.0 + ((gd::float_field(state, fogwake, key::isolated_damage_multiplier, 1.0) - 1.0) * fogwake_retention);
	}

	const DictRef volley = _ability_by_id(state, attacker, key::volley);
	const bool volley_lane_ready = _volley_has_protected_lane(state, attacker, battle, volley);
	if (is_ranged && !empty(state, volley) && volley_lane_ready && attack_distance >= gd::int_field(state, volley, key::min_distance, 1)) {
		modifier *= gd::float_field(state, volley, key::damage_multiplier, 1.0);
	}
	if (is_ranged && !empty(state, volley) && volley_lane_ready && spell_rules::has_any_effect_ids(state, defender, battle, field_or_array(state, volley, key::status_ids))) {
		modifier *= gd::float_field(state, volley, key::status_damage_multiplier, 1.0);
	}
	if (is_ranged && !empty(state, volley) && volley_lane_ready && _side_defending_count(state, battle, side_of(state, attacker)) > 0) {
		modifier *= gd::float_field(state, volley, key::ally_defending_multiplier, 1.0);
	}

	const DictRef formation_guard = _ability_by_id(state, attacker, key::formation_guard);
	if (!empty(state, formation_guard) && spell_rules::has_effect_id(state, defender, battle, key::status_staggered)) {
		modifier *= gd::float_field(state, formation_guard, key::staggered_damage_multiplier, 1.0);
	}

	const DictRef harry = _ability_by_id(state, attacker, key::harry);
	if (is_ranged && !empty(state, harry) && _health_ratio(state, defender) <= gd::float_field(state, harry, key::wounded_threshold_ratio, 0.0)) {
		modifier *= gd::float_field(state, harry, key::wounded_damage_multiplier, 1.0);
	}
	const DictRef rot_cant = _ability_by_id(state, attacker, key::rot_cant);
	if (is_ranged && !empty(state, rot_cant) && battle_round(state, battle) >= gd::int_field(state, rot_cant, key::available_from_round, 1)
			&& _health_ratio(state, defender) <= gd::float_field(state, rot_cant, key::wounded_threshold_ratio, 0.0)) {
		modifier *= gd::float_field(state, rot_cant, key::wounded_damage_multiplier, 1.0);
	}

	const DictRef bloodrush = _ability_by_id(state, attacker, key::bloodrush);
	if (!empty(state, bloodrush) && gd::bool_field(state, bloodrush, key::primary_melee_only, false)) {
		const bool bloodrush_attack_eligible = !is_ranged && !is_retaliation;
		const bool bloodrush_isolated = bloodrush_attack_eligible
				&& gd::float_field(state, bloodrush, key::isolated_damage_multiplier, 1.0) > 1.0
				&& _stack_is_hex_isolated(state, battle, defender);
		const bool bloodrush_prepared = _health_ratio(state, defender) <= gd::float_field(state, bloodrush, key::wounded_threshold_ratio, 0.0)
				|| spell_rules::has_any_effect_ids(state, defender, battle, field_or_array(state, bloodrush, key::status_ids))
				|| bloodrush_isolated;
		if (bloodrush_attack_eligible && !bloodrush_prepared) {
			modifier *= gd::float_field(state, bloodrush, key::clean_target_damage_multiplier, 1.0);
		}
		if (bloodrush_attack_eligible && _health_ratio(state, defender) <= gd::float_field(state, bloodrush, key::wounded_threshold_ratio, 0.0)) {
			modifier *= gd::float_field(state, bloodrush, key::wounded_damage_multiplier, 1.0);
		}
		if (bloodrush_attack_eligible && spell_rules::has_any_effect_ids(state, defender, battle, field_or_array(state, bloodrush, key::status_ids))) {
			modifier *= gd::float_field(state, bloodrush, key::status_damage_multiplier, 1.0);
		}
		if (bloodrush_isolated) {
			modifier *= gd::float_field(state, bloodrush, key::isolated_damage_multiplier, 1.0);
		}
	} else {
		const bool bloodrush_prepared = !empty(state, bloodrush)
				&& (_health_ratio(state, defender) <= gd::float_field(state, bloodrush, key::wounded_threshold_ratio, 0.0)
						|| spell_rules::has_any_effect_ids(state, defender, battle, field_or_array(state, bloodrush, key::status_ids)));
		if (!empty(state, bloodrush) && !is_retaliation && !bloodrush_prepared) {
			modifier *= gd::float_field(state, bloodrush, key::clean_target_damage_multiplier, 1.0);
		}
		if (!empty(state, bloodrush) && _health_ratio(state, defender) <= gd::float_field(state, bloodrush, key::wounded_threshold_ratio, 0.0)) {
			modifier *= gd::float_field(state, bloodrush, key::wounded_damage_multiplier, 1.0);
		}
		if (!empty(state, bloodrush) && spell_rules::has_any_effect_ids(state, defender, battle, field_or_array(state, bloodrush, key::status_ids))) {
			modifier *= gd::float_field(state, bloodrush, key::status_damage_multiplier, 1.0);
		}
	}

	const DictRef overheat = _ability_by_id(state, attacker, key::overheat);
	if (!empty(state, overheat)) {
		if (spell_rules::has_effect_id(state, attacker, battle, key::status_overheated)) {
			modifier *= gd::float_field(state, overheat, key::overheated_damage_multiplier, 1.0);
		} else if (!is_retaliation) {
			modifier *= gd::float_field(state, overheat, key::burst_damage_multiplier, 1.0);
		}
	}

	const DictRef shielding = _ability_by_id(state, defender, key::shielding);
	if (is_ranged && !empty(state, shielding)) {
		modifier *= gd::float_field(state, shielding, key::ranged_damage_multiplier, 1.0);
	}
	const DictRef fog_screen = _fog_screen_ability(state, defender);
	if (!empty(state, fog_screen) && _fog_screen_available(state, defender, battle, fog_screen)) {
		modifier *= gd::float_field(state, fog_screen, key::incoming_damage_multiplier, 1.0);
	}
	if (is_ranged) {
		modifier *= _linked_ranged_attack_screen_multiplier(state, defender, battle);
	}
	if (!is_ranged && attack_distance <= 0 && (ranged(state, defender) || !empty(state, shielding))) {
		int64_t screen_reduction_pct = float_to_int(_side_max_ability_float(state, battle, side_of(state, defender), key::shielding, key::ally_ranged_melee_damage_reduction_pct, 0.0));
		if (_brace_available(state, attacker, battle) || _reach_available(state, attacker, battle)) {
			screen_reduction_pct = gd::add(screen_reduction_pct, float_to_int(_side_max_ability_float(state, battle, side_of(state, defender), key::shielding, key::linebreaker_screen_bonus_pct, 0.0)));
		}
		if (ranged(state, defender) && _has_ability(state, attacker, key::bloodrush)) {
			screen_reduction_pct = gd::add(screen_reduction_pct, float_to_int(_side_max_authored_ability_float(state, battle, side_of(state, defender), key::shielding, key::committed_assault_screen_reduction_pct, 0.0)));
		}
		screen_reduction_pct = engine_clamp<int64_t>(screen_reduction_pct, 0, 75);
		modifier *= 1.0 - (static_cast<double>(screen_reduction_pct) / 100.0);
	}
	const DictRef attacking_shielding = _ability_by_id(state, attacker, key::shielding);
	if (!is_ranged && !empty(state, attacking_shielding) && attack_distance <= 0) {
		modifier *= gd::float_field(state, attacking_shielding, key::engaged_damage_multiplier, 1.0);
	}
	if (!is_ranged && !empty(state, attacking_shielding)) {
		Value payoff_status_ids;
		if (!state.lookup(attacking_shielding, str(key::payoff_status_ids), payoff_status_ids)) {
			payoff_status_ids = array_value(string_array(state, { key::status_harried }));
		}
		if (spell_rules::has_any_effect_ids(state, defender, battle, payoff_status_ids)) {
			modifier *= gd::float_field(state, attacking_shielding, key::harried_damage_multiplier, 1.0);
		}
	}
	if (!is_ranged) {
		modifier *= _solar_array_lane_melee_multiplier(state, defender, battle);
	}

	return modifier;
}

double _solar_array_lane_melee_multiplier(State &state, DictRef defender, DictRef battle) {
	if (gd::string_field(state, defender, key::faction_id, key::empty) != key::faction_sunvault || !ranged(state, defender)) {
		return 1.0;
	}
	const Atom side = side_of(state, defender);
	for (const Value &source : gd::items(state, array_value(_alive_stacks_for_side(state, battle, side)))) {
		const DictRef ability = _ability_by_id(state, gd::as_dict(source), key::solar_array_lane);
		if (empty(state, ability) || !_side_has_linked_unit(state, battle, side, field_or_array(state, ability, key::linked_unit_ids))) {
			continue;
		}
		return gd::float_field(state, ability, key::incoming_melee_damage_multiplier, 1.0);
	}
	return 1.0;
}

bool _side_has_linked_unit(State &state, DictRef battle, Atom side, const Value &unit_ids) {
	if (!gd::is_array(unit_ids)) {
		return false;
	}
	for (const Value &stack : gd::items(state, array_value(_alive_stacks_for_side(state, battle, side)))) {
		if (gd::array_has(state, unit_ids.ref, str(gd::string_field(state, gd::as_dict(stack), key::unit_id, key::empty)))) {
			return true;
		}
	}
	return false;
}

double _faction_damage_modifier(State &state, DictRef attacker, DictRef defender, DictRef battle, bool is_ranged, int64_t attack_distance) {
	double modifier = 1.0;
	Atom faction_id = gd::string_field(state, attacker, key::faction_id, key::empty);
	const Atom side = side_of(state, attacker);
	if (faction_id == key::empty) {
		faction_id = _side_faction_id(state, battle, side);
	}
	const int64_t side_defending_count = _side_defending_count(state, battle, side);
	if (faction_id == key::faction_embercourt) {
		if (is_ranged && side_defending_count > 0) {
			modifier *= 1.08;
			if (_side_has_ability(state, battle, side, key::formation_guard)) {
				modifier *= _side_max_ability_float(state, battle, side, key::formation_guard, key::ally_ranged_damage_multiplier, 1.0);
			}
		}
		if (spell_rules::has_effect_id(state, defender, battle, key::status_staggered)) {
			modifier *= 1.08;
		}
		if (battle_round(state, battle) >= 3 && _side_has_role_mix(state, battle, side)) {
			modifier *= _side_has_ability(state, battle, side, key::formation_guard) ? 1.06 : 1.04;
		}
	} else if (faction_id == key::faction_mireclaw) {
		const int64_t wounded_count = _enemy_wounded_count(state, battle, side);
		if (wounded_count > 0) {
			modifier *= 1.0 + (static_cast<double>(engine_min<int64_t>(wounded_count, 3)) * 0.04);
		}
		if (spell_rules::has_any_effect_ids(state, defender, battle, array_value(string_array(state, { key::status_harried, state.intern("status_mire_harried") })))) {
			modifier *= 1.08;
		}
		if (!is_ranged && battle_round(state, battle) >= 3 && attack_distance <= 0) {
			modifier *= 1.0 + (static_cast<double>(engine_min<int64_t>(wounded_count, 2)) * 0.03);
		}
	} else if (faction_id == key::faction_sunvault) {
		const int64_t positive_effect_count = _side_positive_effect_count(state, battle, side);
		if (_stack_has_positive_effect(state, attacker, battle)) {
			modifier *= 1.08;
			if (any_tag(state, battle, { key::elevated_fire, key::fortified_line })) {
				modifier *= 1.04;
			}
		}
		const int64_t relay_minimum = float_to_int(_side_max_ability_float(state, battle, side, key::resonance_relay, key::minimum_calibrated_stacks, 2.0));
		if (_side_has_ability(state, battle, side, key::resonance_relay) && positive_effect_count >= relay_minimum) {
			const int64_t calibrated_count = engine_min<int64_t>(positive_effect_count, float_to_int(_side_max_ability_float(state, battle, side, key::resonance_relay, key::maximum_calibrated_stacks, 3.0)));
			modifier *= 1.0 + (static_cast<double>(calibrated_count) * _side_max_ability_float(state, battle, side, key::resonance_relay, key::line_damage_per_calibrated_stack, 0.0));
		}
		if (spell_rules::has_effect_id(state, defender, battle, key::status_staggered)) {
			modifier *= 1.05;
		}
		if (is_ranged && any_tag(state, battle, { key::elevated_fire, key::open_lane }) && positive_effect_count > 0) {
			modifier *= 1.04;
		}
	} else if (faction_id == key::faction_thornwake) {
		if (spell_rules::has_effect_id(state, defender, battle, key::status_rooted)) {
			modifier *= 1.10;
		}
		if (spell_rules::has_any_effect_ids(state, defender, battle, array_value(string_array(state, { key::status_harried, key::status_staggered })))) {
			modifier *= 1.07;
		}
		if (any_tag(state, battle, { key::chokepoint, key::ambush_cover, key::fortified_line }) && !is_ranged) {
			modifier *= 1.05;
		}
		if (battle_round(state, battle) >= 4 && _side_defending_count(state, battle, side) > 0) {
			modifier *= 1.04;
		}
	} else if (faction_id == key::faction_brasshollow) {
		if (any_tag(state, battle, { key::fortress_lane, key::wall_pressure, key::battery_nest })) {
			modifier *= 1.05;
		}
		if (is_ranged && attack_distance >= 2) {
			modifier *= 1.04;
		}
		const double pressure_multiplier = _side_max_ability_float(state, battle, side, key::shielding, key::brasshollow_pressure_damage_multiplier, 1.0);
		if (pressure_multiplier > 1.0 && battle_round(state, battle) >= 3) {
			modifier *= pressure_multiplier;
		}
	} else if (faction_id == key::faction_veilmourn) {
		if (_stack_is_isolated(state, battle, defender)) {
			modifier *= 1.08;
		}
		if (spell_rules::has_any_effect_ids(state, defender, battle, array_value(string_array(state, { key::status_harried, key::status_staggered })))) {
			modifier *= 1.06;
		}
		if (any_tag(state, battle, { key::fog_bank, key::ambush_cover }) && !is_ranged) {
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
	if (any_tag(state, battle, { key::chokepoint, key::fortified_line })) {
		if (!is_ranged && attack_distance <= 1 && (_reach_available(state, attacker, battle) || _brace_available(state, attacker, battle) || _has_ability(state, attacker, key::formation_guard))) {
			modifier *= 1.08;
		} else if (is_ranged && attack_distance > 0) {
			modifier *= 0.92;
		}
	}
	if (_battle_has_tag(state, battle, key::ambush_cover)) {
		if (!is_ranged && battle_round(state, battle) <= 2) {
			modifier *= 1.08;
		} else if (is_ranged && attack_distance > 0) {
			modifier *= 0.94;
		}
	}
	if (_battle_has_tag(state, battle, key::bog_channels) && (
			_has_ability(state, attacker, key::harry)
			|| _has_ability(state, attacker, key::backstab)
			|| _has_ability(state, attacker, key::bloodrush)
			|| spell_rules::has_effect_id(state, defender, battle, key::status_harried))) {
		modifier *= 1.08;
	}
	if (_battle_has_tag(state, battle, key::fog_bank) && is_ranged && attack_distance > 0 && !faction_brings_tag(state, attacker, key::fog_bank)) {
		modifier *= 0.88;
	}
	return modifier;
}

double _linked_ranged_attack_screen_multiplier(State &state, DictRef defender, DictRef battle) {
	if (!ranged(state, defender)) {
		return 1.0;
	}
	const Atom defender_unit_id = gd::string_field(state, defender, key::unit_id, key::empty);
	int64_t best_reduction_pct = 0;
	for (const Value &source_value : gd::items(state, array_value(_alive_stacks_for_side(state, battle, side_of(state, defender))))) {
		const DictRef source = gd::as_dict(source_value);
		if (empty(state, _ability_by_id(state, source, key::shielding))) {
			continue;
		}
		const DictRef shielding = _authored_ability_by_id(state, source, key::shielding);
		const Value linked_unit_ids = field_or_array(state, shielding, key::linked_ranged_unit_ids);
		if (gd::is_array(linked_unit_ids) && gd::array_has(state, linked_unit_ids.ref, str(defender_unit_id))) {
			best_reduction_pct = engine_max<int64_t>(best_reduction_pct, gd::int_field(state, shielding, key::linked_ranged_damage_reduction_pct, 0));
		}
	}
	return 1.0 - (static_cast<double>(engine_clamp<int64_t>(best_reduction_pct, 0, 50)) / 100.0);
}

DictRef _charter_retaliation_aura_context(State &state, DictRef stack, DictRef battle) {
	if (empty(state, stack) || ranged(state, stack)) {
		return state.new_dict();
	}
	for (const Value &source_value : gd::items(state, array_value(_alive_stacks_for_side(state, battle, side_of(state, stack))))) {
		const DictRef source = gd::as_dict(source_value);
		if (gd::string_field(state, source, key::battle_id, key::empty) == gd::string_field(state, stack, key::battle_id, key::empty)) {
			continue;
		}
		const DictRef brace = _ability_by_id(state, source, key::brace);
		if (gd::float_field(state, brace, key::ally_retaliation_multiplier, 1.0) <= 1.0) {
			continue;
		}
		if (gd::int_field(state, stack, key::tier, 1) < gd::int_field(state, brace, key::ally_retaliation_min_tier, 1)) {
			continue;
		}
		const Atom role = gd::string_field(state, brace, key::ally_retaliation_role, key::empty);
		if (role != key::empty && ranged(state, stack) != (role == key::ranged)) {
			continue;
		}
		const DictRef context = state.new_dict();
		state.set(context, str(key::source), source_value);
		state.set(context, str(key::ability), dict_value(brace));
		return context;
	}
	return state.new_dict();
}

double _side_max_ability_float(State &state, DictRef battle, Atom side, Atom ability_id, Atom field, double default_value) {
	double best = default_value;
	for (const Value &stack : gd::items(state, array_value(_alive_stacks_for_side(state, battle, side)))) {
		const DictRef ability = _ability_by_id(state, gd::as_dict(stack), ability_id);
		if (empty(state, ability)) {
			continue;
		}
		best = engine_max<double>(best, gd::float_field(state, ability, field, default_value));
	}
	return best;
}

double _side_max_authored_ability_float(State &state, DictRef battle, Atom side, Atom ability_id, Atom field, double default_value) {
	double best = default_value;
	for (const Value &stack : gd::items(state, array_value(_alive_stacks_for_side(state, battle, side)))) {
		if (empty(state, _ability_by_id(state, gd::as_dict(stack), ability_id))) {
			continue;
		}
		const DictRef ability = _authored_ability_by_id(state, gd::as_dict(stack), ability_id);
		best = engine_max<double>(best, gd::float_field(state, ability, field, default_value));
	}
	return best;
}

bool _side_ability_bool(State &state, DictRef battle, Atom side, Atom ability_id, Atom field, bool default_value) {
	for (const Value &stack : gd::items(state, array_value(_alive_stacks_for_side(state, battle, side)))) {
		const DictRef ability = _ability_by_id(state, gd::as_dict(stack), ability_id);
		if (!empty(state, ability)) {
			return gd::bool_field(state, ability, field, default_value);
		}
	}
	return default_value;
}

bool _side_has_ability(State &state, DictRef battle, Atom side, Atom ability_id) {
	for (const Value &stack : gd::items(state, array_value(_alive_stacks_for_side(state, battle, side)))) {
		if (_has_ability(state, gd::as_dict(stack), ability_id)) {
			return true;
		}
	}
	return false;
}

int64_t _side_defending_count(State &state, DictRef battle, Atom side) {
	int64_t total = 0;
	for (const Value &stack : gd::items(state, array_value(_alive_stacks_for_side(state, battle, side)))) {
		if (gd::bool_field(state, gd::as_dict(stack), key::defending, false)) {
			total += 1;
		}
	}
	return total;
}

bool _brace_has_held_objective(State &state, DictRef stack, DictRef battle, DictRef brace) {
	if (empty(state, stack) || empty(state, brace) || gd::float_field(state, brace, key::held_objective_retaliation_multiplier, 1.0) <= 1.0) {
		return false;
	}
	const Atom side = side_of(state, stack);
	for (const Value &objective_type : gd::field_items(state, brace, str(key::held_objective_types))) {
		if (_side_controls_field_objective_type(state, battle, side, gd::to_string(objective_type))) {
			return true;
		}
	}
	return false;
}

bool _volley_has_protected_lane(State &state, DictRef stack, DictRef battle, DictRef volley) {
	if (empty(state, stack) || empty(state, volley)) {
		return false;
	}
	if (!gd::bool_field(state, volley, key::requires_protected_lane, false)) {
		return true;
	}
	const Atom side = side_of(state, stack);
	const Atom battle_id = gd::string_field(state, stack, key::battle_id, key::empty);
	for (const Value &ally_value : gd::items(state, array_value(_alive_stacks_for_side(state, battle, side)))) {
		const DictRef ally = gd::as_dict(ally_value);
		if (gd::string_field(state, ally, key::battle_id, key::empty) != battle_id
				&& gd::bool_field(state, ally, key::defending, false)
				&& _stack_hex_distance(state, stack, ally) <= 1) {
			return true;
		}
	}
	for (const Value &objective_type : gd::field_items(state, volley, str(key::protected_lane_objective_types))) {
		if (_side_controls_field_objective_type(state, battle, side, gd::to_string(objective_type))) {
			return true;
		}
	}
	return false;
}

bool _battle_has_any_tags(State &state, DictRef battle, ArrayRef tags) {
	for (const Value &tag_value : gd::items(state, array_value(tags))) {
		if (_battle_has_tag(state, battle, gd::to_string(tag_value))) {
			return true;
		}
	}
	return false;
}

Atom _capital_front_anchor_side(State &state, DictRef battle) {
	const Value context = get_or_empty_dict(state, dict_value(battle), key::context);
	if (gd::to_string(get_or_empty_dict_value(state, context, key::type, str(key::empty))) == key::town_defense) {
		return key::player;
	}
	if (any_tag(state, battle, { key::fortress_lane, key::reserve_wave, key::battery_nest, key::wall_pressure })) {
		return key::enemy;
	}
	return key::empty;
}

Atom _capital_front_assault_side(State &state, DictRef battle) {
	const Atom anchor_side = _capital_front_anchor_side(state, battle);
	if (anchor_side == key::player) {
		return key::enemy;
	}
	if (anchor_side == key::enemy) {
		return key::player;
	}
	return key::empty;
}

bool _stack_is_anchor_side(State &state, DictRef stack, DictRef battle) {
	return side_of(state, stack) == _capital_front_anchor_side(state, battle);
}

bool _stack_is_assault_side(State &state, DictRef stack, DictRef battle) {
	return side_of(state, stack) == _capital_front_assault_side(state, battle);
}

int64_t _allied_ranged_count(State &state, DictRef battle, Atom side) {
	int64_t total = 0;
	for (const Value &stack : gd::items(state, array_value(_alive_stacks_for_side(state, battle, side)))) {
		if (ranged(state, gd::as_dict(stack))) {
			total += 1;
		}
	}
	return total;
}

int64_t _allied_melee_count(State &state, DictRef battle, Atom side) {
	const ArrayRef entry = _scoring_living_entry(state, battle, side);
	if (state.array_size(entry) > 0) {
		return gd::to_int(state, state.at(entry, 2));
	}
	int64_t total = 0;
	for (const Value &stack : gd::items(state, array_value(_alive_stacks_for_side(state, battle, side)))) {
		if (!ranged(state, gd::as_dict(stack))) {
			total += 1;
		}
	}
	return total;
}

bool _stack_is_isolated(State &state, DictRef battle, DictRef stack) {
	if (empty(state, stack)) {
		return false;
	}
	const Atom side = side_of(state, stack);
	const ArrayRef entry = _scoring_living_entry(state, battle, side);
	if (state.array_size(entry) > 0) {
		if (state.array_size(gd::as_array(state.at(entry, 1))) <= 1) {
			return true;
		}
		if (ranged(state, stack)) {
			return gd::to_int(state, state.at(entry, 2)) <= 0;
		}
		return false;
	}
	const ArrayRef living_allies = _alive_stacks_for_side(state, battle, side);
	if (state.array_size(living_allies) <= 1) {
		return true;
	}
	if (ranged(state, stack)) {
		return _allied_melee_count(state, battle, side) <= 0;
	}
	return false;
}

bool _stack_is_hex_isolated(State &state, DictRef battle, DictRef stack) {
	if (empty(state, stack)) {
		return false;
	}
	const DictRef stack_hex = _stack_hex(state, stack);
	if (empty(state, stack_hex)) {
		return _stack_is_isolated(state, battle, stack);
	}
	const Atom battle_id = gd::string_field(state, stack, key::battle_id, key::empty);
	for (const Value &ally_value : gd::items(state, array_value(_alive_stacks_for_side(state, battle, side_of(state, stack))))) {
		const DictRef ally = gd::as_dict(ally_value);
		if (gd::string_field(state, ally, key::battle_id, key::empty) == battle_id) {
			continue;
		}
		const DictRef ally_hex = _stack_hex(state, ally);
		if (!empty(state, ally_hex) && _stack_hex_distance(state, stack, ally) <= 1) {
			return false;
		}
	}
	return true;
}

bool _side_has_role_mix(State &state, DictRef battle, Atom side) {
	bool ranged_alive = false;
	bool melee_alive = false;
	for (const Value &stack : gd::items(state, array_value(_alive_stacks_for_side(state, battle, side)))) {
		if (ranged(state, gd::as_dict(stack))) {
			ranged_alive = true;
		} else {
			melee_alive = true;
		}
		if (ranged_alive && melee_alive) {
			return true;
		}
	}
	return false;
}

int64_t _enemy_wounded_count(State &state, DictRef battle, Atom side) {
	// Not _opposing_side: any side but "enemy" faces the enemy.
	const Atom opposing_side = side == key::enemy ? key::player : key::enemy;
	int64_t total = 0;
	for (const Value &stack : gd::items(state, array_value(_alive_stacks_for_side(state, battle, opposing_side)))) {
		if (_health_ratio(state, gd::as_dict(stack)) <= 0.75) {
			total += 1;
		}
	}
	return total;
}

Atom _side_faction_id(State &state, DictRef battle, Atom side) {
	for (const Value &stack : gd::items(state, array_value(_alive_stacks_for_side(state, battle, side)))) {
		const Atom faction_id = gd::string_field(state, gd::as_dict(stack), key::faction_id, key::empty);
		if (faction_id != key::empty) {
			return faction_id;
		}
	}
	return key::empty;
}

bool _stack_has_positive_effect(State &state, DictRef stack, DictRef battle) {
	const int64_t current_round = battle_round(state, battle);
	for (const Value &effect : gd::items(state, array_value(spell_rules::active_effects_for_round(state, stack, current_round)))) {
		const DictRef modifiers = typed_dict(get_or_empty_dict(state, effect, key::modifiers));
		for (const Atom modifier_key : { key::attack, key::defense, key::initiative, key::cohesion, key::momentum }) {
			if (gd::int_field(state, modifiers, modifier_key, 0) > 0) {
				return true;
			}
		}
	}
	return false;
}

int64_t _side_positive_effect_count(State &state, DictRef battle, Atom side) {
	int64_t total = 0;
	for (const Value &stack : gd::items(state, array_value(_alive_stacks_for_side(state, battle, side)))) {
		if (gd::is_dict(stack) && _stack_has_positive_effect(state, stack.ref, battle)) {
			total += 1;
		}
	}
	return total;
}

int64_t _field_objective_attack_bonus(State &state, DictRef stack, DictRef battle) {
	const Atom side = side_of(state, stack);
	int64_t bonus = 0;
	for (const Value &objective : gd::items(state, array_value(_field_objectives(state, battle)))) {
		if (!gd::is_dict(objective) || gd::string_field(state, objective.ref, key::control_side, key::empty) != side) {
			continue;
		}
		const Atom type = gd::string_field(state, objective.ref, key::type, key::empty);
		if (type == key::lane_battery) {
			if (ranged(state, stack) && battle_distance(state, battle) > 0) {
				bonus += 1;
			}
		} else if (type == key::cover_line) {
			if (ranged(state, stack) && battle_distance(state, battle) > 0 && !_stack_is_isolated(state, battle, stack)) {
				bonus += 1;
			}
		} else if (type == key::obstruction_line) {
			if (!ranged(state, stack) && (
					battle_distance(state, battle) <= 1
					|| battle_round(state, battle) >= gd::int_field(state, objective.ref, key::urgency_round, 2))) {
				bonus += 1;
			}
		} else if (type == key::breach_point) {
			if (!ranged(state, stack) && battle_round(state, battle) >= gd::int_field(state, objective.ref, key::urgency_round, 3)) {
				bonus += 1;
			}
		}
	}
	return engine_min<int64_t>(bonus, 2);
}

int64_t _field_objective_defense_bonus(State &state, DictRef stack, DictRef battle) {
	const Atom side = side_of(state, stack);
	int64_t bonus = 0;
	for (const Value &objective : gd::items(state, array_value(_field_objectives(state, battle)))) {
		if (!gd::is_dict(objective) || gd::string_field(state, objective.ref, key::control_side, key::empty) != side) {
			continue;
		}
		const Atom type = gd::string_field(state, objective.ref, key::type, key::empty);
		if (type == key::cover_line) {
			if (ranged(state, stack) || gd::bool_field(state, stack, key::defending, false)) {
				bonus += 1;
			}
		} else if (type == key::obstruction_line) {
			if (!ranged(state, stack)) {
				bonus += 1;
			}
		} else if (type == key::supply_post) {
			if (!_stack_is_isolated(state, battle, stack)) {
				bonus += 1;
			}
		} else if (type == key::signal_beacon) {
			bonus += 1;
		} else if (type == key::breach_point) {
			if (_stack_is_anchor_side(state, stack, battle)) {
				bonus += 1;
			}
		}
	}
	return engine_min<int64_t>(bonus, 2);
}

int64_t _field_objective_cohesion_bonus(State &state, DictRef stack, DictRef battle) {
	const Atom side = side_of(state, stack);
	int64_t bonus = 0;
	for (const Value &objective : gd::items(state, array_value(_field_objectives(state, battle)))) {
		if (!gd::is_dict(objective)) {
			continue;
		}
		const Atom controller = gd::string_field(state, objective.ref, key::control_side, key::neutral);
		const Atom type = gd::string_field(state, objective.ref, key::type, key::empty);
		if (type == key::cover_line) {
			if (controller == side && (ranged(state, stack) || !_stack_is_isolated(state, battle, stack))) {
				bonus += 1;
			} else if (controller == _opposing_side(side) && ranged(state, stack) && battle_distance(state, battle) > 0) {
				bonus -= 1;
			}
		} else if (type == key::obstruction_line) {
			if (controller == side && !ranged(state, stack)) {
				bonus += 1;
			} else if (controller == _opposing_side(side) && !ranged(state, stack) && battle_distance(state, battle) > 0) {
				bonus -= 1;
			}
		} else if (type == key::supply_post) {
			if (controller == side && !_stack_is_isolated(state, battle, stack)) {
				bonus += 1;
			}
		} else if (type == key::breach_point) {
			if (controller == side && _stack_is_anchor_side(state, stack, battle)) {
				bonus += 1;
			}
		} else if (type == key::hazard_zone || type == key::ritual_pylon) {
			if (controller == _opposing_side(side) && battle_round(state, battle) >= gd::int_field(state, objective.ref, key::urgency_round, 2)) {
				bonus -= 1;
			}
		}
	}
	return engine_clamp<int64_t>(bonus, -2, 2);
}

int64_t _field_objective_momentum_bonus(State &state, DictRef stack, DictRef battle) {
	const Atom side = side_of(state, stack);
	int64_t bonus = 0;
	for (const Value &objective : gd::items(state, array_value(_field_objectives(state, battle)))) {
		if (!gd::is_dict(objective) || gd::string_field(state, objective.ref, key::control_side, key::empty) != side) {
			continue;
		}
		const Atom type = gd::string_field(state, objective.ref, key::type, key::empty);
		if (type == key::cover_line) {
			if (ranged(state, stack) && battle_round(state, battle) <= 2 && battle_distance(state, battle) > 0) {
				bonus += 1;
			}
		} else if (type == key::obstruction_line) {
			if (!ranged(state, stack) && battle_distance(state, battle) > 0 && battle_round(state, battle) >= gd::int_field(state, objective.ref, key::urgency_round, 2)) {
				bonus += 1;
			}
		} else if (type == key::breach_point) {
			if (!ranged(state, stack) && battle_round(state, battle) >= gd::int_field(state, objective.ref, key::urgency_round, 3)) {
				bonus += 1;
			}
		} else if (type == key::lane_battery) {
			if (ranged(state, stack) && battle_round(state, battle) <= 2 && battle_distance(state, battle) > 0) {
				bonus += 1;
			}
		}
	}
	return engine_min<int64_t>(bonus, 2);
}

double _field_objective_commander_modifier(State &state, DictRef attacker, DictRef defender, DictRef battle) {
	double modifier = 1.0;
	const Atom attacker_side = side_of(state, attacker);
	const Atom defender_side = side_of(state, defender);
	if (_side_controls_field_objective_type(state, battle, attacker_side, key::cover_line) && battle_distance(state, battle) > 0) {
		modifier *= 1.06;
	}
	if (_side_controls_field_objective_type(state, battle, defender_side, key::cover_line) && battle_distance(state, battle) > 0) {
		modifier *= 0.94;
	}
	if (_side_controls_field_objective_type(state, battle, attacker_side, key::signal_beacon)) {
		modifier *= 1.05;
	}
	if (_side_controls_field_objective_type(state, battle, defender_side, key::signal_beacon)) {
		modifier *= 0.95;
	}
	if (!ranged(state, attacker)
			&& _side_controls_field_objective_type(state, battle, defender_side, key::obstruction_line)
			&& battle_distance(state, battle) > 0) {
		modifier *= 0.94;
	}
	if (!ranged(state, attacker)
			&& _side_controls_field_objective_type(state, battle, attacker_side, key::obstruction_line)
			&& battle_round(state, battle) >= 2) {
		modifier *= 1.04;
	}
	if (_side_controls_field_objective_type(state, battle, attacker_side, key::ritual_pylon)) {
		modifier *= 1.03;
	}
	return modifier;
}

bool _stack_is_cover_screened(State &state, DictRef stack, DictRef battle) {
	if (empty(state, stack)) {
		return false;
	}
	if (ranged(state, stack)) {
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
	const Atom attacker_side = side_of(state, attacker);
	const Atom defender_side = side_of(state, defender);
	if (_side_controls_field_objective_type(state, battle, defender_side, key::cover_line)) {
		modifier *= _stack_is_cover_screened(state, defender, battle) ? 0.85 : 0.93;
	}
	if (_side_controls_field_objective_type(state, battle, attacker_side, key::cover_line) && _stack_is_cover_screened(state, attacker, battle)) {
		modifier *= 1.08;
	}
	return modifier;
}

int64_t _field_objective_action_influence(State &state, DictRef objective, DictRef battle, Atom acting_side, Atom action, DictRef acting_stack, DictRef target_stack) {
	const Atom controller = gd::string_field(state, objective, key::control_side, key::neutral);
	const bool contested = controller != acting_side;
	const bool is_ranged = ranged(state, acting_stack);
	const Atom type = gd::string_field(state, objective, key::type, key::empty);
	if (type == key::lane_battery) {
		if (action == key::advance) {
			return contested && !is_ranged ? 2 : (contested ? 1 : 0);
		} else if (action == key::strike) {
			return contested && !is_ranged ? 2 : 1;
		} else if (action == key::shoot) {
			if (is_ranged) {
				if (acting_side == controller) {
					return 2;
				}
				return ranged(state, target_stack) ? 2 : 1;
			}
		} else if (action == key::defend) {
			return acting_side == controller && (is_ranged || _brace_available(state, acting_stack, battle) || _has_ability(state, acting_stack, key::formation_guard)) ? 1 : 0;
		}
	} else if (type == key::cover_line) {
		if (action == key::advance) {
			return contested && !is_ranged ? 2 : (contested ? 1 : 0);
		} else if (action == key::strike) {
			return contested && !is_ranged ? 2 : 1;
		} else if (action == key::shoot) {
			return is_ranged && acting_side == controller ? 1 : 0;
		} else if (action == key::defend) {
			return acting_side == controller && (
					is_ranged
					|| _brace_available(state, acting_stack, battle)
					|| _has_ability(state, acting_stack, key::formation_guard)
				) ? 2 : (contested && !is_ranged ? 1 : 0);
		} else if (action == key::cast_spell) {
			return 1;
		}
	} else if (type == key::obstruction_line) {
		if (action == key::advance) {
			return contested && !is_ranged ? 2 : (contested ? 1 : 0);
		} else if (action == key::strike) {
			return !is_ranged ? 2 : 0;
		} else if (action == key::defend) {
			return acting_side == controller && (
					!is_ranged
					|| _brace_available(state, acting_stack, battle)
					|| _has_ability(state, acting_stack, key::formation_guard)
					|| _reach_available(state, acting_stack, battle)
				) ? 2 : (contested && !is_ranged ? 1 : 0);
		}
	} else if (type == key::ritual_pylon) {
		if (action == key::advance || action == key::strike) {
			return contested && !is_ranged ? 2 : 1;
		} else if (action == key::cast_spell) {
			return 1;
		} else if (action == key::defend) {
			return acting_side == controller ? 1 : 0;
		}
	} else if (type == key::supply_post) {
		if (action == key::defend) {
			return 2;
		} else if (action == key::strike) {
			return !is_ranged ? 1 : 0;
		} else if (action == key::advance) {
			return contested && !is_ranged ? 1 : 0;
		}
	} else if (type == key::signal_beacon) {
		if (action == key::advance) {
			return contested ? 1 : 0;
		} else if (action == key::defend) {
			return acting_side == controller ? 2 : 1;
		} else if (action == key::shoot) {
			return is_ranged ? 1 : 0;
		} else if (action == key::cast_spell) {
			return 1;
		}
	} else if (type == key::breach_point) {
		if (action == key::advance) {
			return !is_ranged ? 2 : 0;
		} else if (action == key::strike) {
			return !is_ranged ? 2 : 1;
		} else if (action == key::defend) {
			// _stack_is_anchor_side({"side": acting_side}, battle).
			return acting_side == controller && acting_side == _capital_front_anchor_side(state, battle) ? 2 : 0;
		}
	} else if (type == key::hazard_zone) {
		if (action == key::advance || action == key::strike) {
			return contested && !is_ranged ? 2 : 1;
		} else if (action == key::cast_spell) {
			return 1;
		} else if (action == key::defend) {
			return acting_side == controller ? 1 : 0;
		}
	}
	return 0;
}

int64_t _reserve_wave_ready_round(State &state, DictRef battle, Atom side) {
	int64_t ready_round = 3;
	if (side == key::empty) {
		return ready_round;
	}
	if (_side_controls_field_objective_type(state, battle, side, key::supply_post)) {
		ready_round -= 1;
	} else if (_side_controls_field_objective_type(state, battle, _opposing_side(side), key::supply_post)) {
		ready_round += 1;
	}
	return engine_clamp<int64_t>(ready_round, 2, 4);
}

bool _reserve_wave_is_active_for_side(State &state, DictRef battle, Atom side) {
	return side != key::empty && _battle_has_tag(state, battle, key::reserve_wave) && battle_round(state, battle) >= _reserve_wave_ready_round(state, battle, side);
}

bool _commander_spell_cast_this_round(State &state, DictRef battle, Atom side) {
	if (empty(state, battle) || side == key::empty) {
		return false;
	}
	if (side == key::enemy && gd::bool_field(state, battle, key::_enemy_commander_spell_cast_in_drain, false)) {
		return true;
	}
	Value cast_rounds;
	if (!state.lookup(battle, str(key::commander_spell_cast_rounds), cast_rounds)) {
		return 0 >= battle_round(state, battle); // the default {} holds no round
	}
	if (!gd::is_dict(cast_rounds)) {
		return false;
	}
	return gd::int_field(state, cast_rounds.ref, side, 0) >= battle_round(state, battle);
}

} // namespace aurelion::rules::port::battle_ai_rules
