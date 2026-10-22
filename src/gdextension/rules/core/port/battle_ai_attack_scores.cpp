// Slice 09: BattleAiRules' weighed scores: the weights (_w), an attack's score
// and its candidates, the defend and advance scores, holding the line and the
// melee approach. Inside a scoring scope an attack's score keeps its entry in
// _scoring_attack_scores, as the GDScript does.

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
using compat::godot_round;
using gd::array_value;
using gd::bool_value;
using gd::dict_value;
using gd::float_value;
using gd::int_value;
using gd::str;
namespace key = state::key;

namespace {

// BattleAiRules.COHESION_MAX.
constexpr int64_t kCohesionMax = 10;

bool empty(const State &state, DictRef dict) {
	return gd::is_empty(state, dict);
}

// String(stack.get("side", ""))
Atom side_of(const State &state, DictRef stack) {
	return gd::string_field(state, stack, key::side, key::empty);
}

// bool(stack.get("ranged", false))
bool ranged(const State &state, DictRef stack) {
	return gd::bool_field(state, stack, key::ranged, false);
}

// int(stack.get("shots_remaining", 0)) > 0
bool has_shots(const State &state, DictRef stack) {
	return gd::int_field(state, stack, key::shots_remaining, 0) > 0;
}

// int(battle.get("round", 1))
int64_t battle_round(const State &state, DictRef battle) {
	return gd::int_field(state, battle, key::round, 1);
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

// [STATUS_HARRIED, STATUS_STAGGERED]
Value pressure_status_ids(State &state) {
	return array_value(string_array(state, { key::status_harried, key::status_staggered }));
}

// d.get(key, []): the field, or a new empty Array.
Value field_or_array(State &state, DictRef dict, Atom field) {
	Value out;
	if (state.lookup(dict, str(field), out)) {
		return out;
	}
	return array_value(state.new_array());
}

// value.get(key, fallback) on an untyped value: only a Dictionary has a
// two-argument get, so GDScript stops on any other base.
DictRef get_base(const Value &base) {
	if (!gd::is_dict(base)) {
		throw state::ScriptError(std::string("Invalid call. Nonexistent function 'get' in base '") + gd::type_name(base) + "'.");
	}
	return base.ref;
}

// The untyped min(a, b) of floats.
double variant_min_float(double a, double b) {
	return compat::variant_min({ compat::Number::of_float(a), compat::Number::of_float(b) }).f;
}

// (1.0 - (float(_stack_cohesion_total(stack, battle)) / float(COHESION_MAX)))
double cohesion_gap(State &state, DictRef stack, DictRef battle) {
	return 1.0 - (static_cast<double>(_stack_cohesion_total(state, stack, battle)) / static_cast<double>(kCohesionMax));
}

// _has_ability(stack, "harry") or _has_ability(stack, "backstab") or _has_ability(stack, "bloodrush")
bool skirmisher(State &state, DictRef stack) {
	return _has_ability(state, stack, key::harry) || _has_ability(state, stack, key::backstab) || _has_ability(state, stack, key::bloodrush);
}

// _reach_available(stack, battle) or _brace_available(stack, battle) or _has_ability(stack, "formation_guard")
bool holds_line(State &state, DictRef stack, DictRef battle) {
	return _reach_available(state, stack, battle) || _brace_available(state, stack, battle) || _has_ability(state, stack, key::formation_guard);
}

// var ability_uses = attacker.get("ability_uses", {}): `ability_uses is
// Dictionary`, and int(ability_uses.get(name, 0)) once it is one. A missing
// field is the new empty Dictionary, which holds no uses.
struct AbilityUses {
	bool present = false;
	Value value;

	bool is_dict() const {
		return !present || gd::is_dict(value);
	}

	int64_t count(const State &state, Atom name) const {
		return present ? gd::int_field(state, value.ref, name, 0) : 0;
	}
};

// {"action": action, "target_battle_id": target_id, "score": score}
DictRef attack_order(State &state, Atom action, Atom target_id, double score) {
	const DictRef order = state.new_dict();
	state.set(order, str(key::action), str(action));
	state.set(order, str(key::target_battle_id), str(target_id));
	state.set(order, str(key::score), float_value(score));
	return order;
}

} // namespace

double _w(State &state, Atom weight_key) {
	// The static is read every call: the arena tool rewrites its declaration.
	Value weights = gd::static_var(state, key::battle_ai_rules_script, key::_weights);
	if (empty(state, gd::as_dict(weights))) {
		const DictRef data = gd::content_file(state, key::battle_ai_weights_path);
		Value loaded;
		if (!state.lookup(data, str(key::weights), loaded) || !gd::is_dict(loaded)) {
			loaded = dict_value(state.new_dict());
		}
		gd::set_static_var(state, key::battle_ai_rules_script, key::_weights, loaded);
		weights = gd::static_var(state, key::battle_ai_rules_script, key::_weights);
	}
	return gd::to_float(gd::index(state, gd::as_dict(weights), str(weight_key)));
}

DictRef _best_attack_action(State &state, DictRef battle, DictRef active_stack, ArrayRef targets) {
	DictRef best = state.new_dict();
	if (ranged(state, active_stack) && has_shots(state, active_stack)) {
		for (const Value &target : gd::items(state, array_value(targets))) {
			if (!gd::is_dict(target)) {
				continue;
			}
			if (!_can_make_ranged_attack(state, active_stack, battle, target.ref)) {
				continue;
			}
			const Atom target_id = gd::string_field(state, target.ref, key::battle_id, key::empty);
			const double score = _attack_score(state, active_stack, target.ref, battle, true);
			const DictRef ranged_candidate = attack_order(state, key::shoot, target_id, score);
			if (_candidate_beats(state, ranged_candidate, best)) {
				best = ranged_candidate;
			}
		}
	}

	for (const Value &target : gd::items(state, array_value(targets))) {
		if (!gd::is_dict(target)) {
			continue;
		}
		const DictRef melee_candidate = _strike_candidate(state, battle, active_stack, target.ref);
		if (!empty(state, melee_candidate) && _candidate_beats(state, melee_candidate, best)) {
			best = melee_candidate;
		}
	}

	return best;
}

DictRef _strike_candidate(State &state, DictRef battle, DictRef active_stack, DictRef target) {
	const Atom target_id = gd::string_field(state, target, key::battle_id, key::empty);
	if (_can_make_melee_attack(state, active_stack, battle, target)) {
		const double score = _attack_score(state, active_stack, target, battle, false);
		return attack_order(state, key::strike, target_id, score);
	}
	if (!_fights_in_melee(state, active_stack) || _stack_is_rooted(state, active_stack, battle)) {
		return state.new_dict();
	}
	const DictRef approach = battle_rules::ai_melee_approach(state, battle, active_stack, target);
	if (empty(state, approach)) {
		return state.new_dict();
	}
	const ArrayRef projection = _projected_on_cell(state, battle, active_stack, approach);
	const double score = _attack_score(state, gd::as_dict(state.at(projection, 0)), target, gd::as_dict(state.at(projection, 1)), false);
	const DictRef cell = state.new_dict();
	state.set(cell, str(key::q), int_value(gd::int_field(state, approach, key::q, -1)));
	state.set(cell, str(key::r), int_value(gd::int_field(state, approach, key::r, -1)));
	state.set(cell, str(key::steps), int_value(gd::int_field(state, approach, key::steps, 0)));
	const DictRef order = attack_order(state, key::strike, target_id, score);
	state.set(order, str(key::approach), dict_value(cell));
	return order;
}

double _attack_score(State &state, DictRef attacker, DictRef target, DictRef battle, bool is_ranged) {
	if (!scoring_scope_open(state)) {
		return _attack_score_on(state, attacker, target, battle, is_ranged);
	}
	const Atom memo_key = pair_key(state, attacker, target);
	for (const Value &held : gd::field_items(state, scoring_memo(state, key::_scoring_attack_scores), str(memo_key))) {
		const ArrayRef entry = gd::as_array(held);
		if (gd::is_same(state, state.at(entry, 0), dict_value(attacker))
				&& gd::is_same(state, state.at(entry, 1), dict_value(target))
				&& gd::is_same(state, state.at(entry, 2), dict_value(battle))
				&& gd::to_bool(state.at(entry, 3)) == is_ranged) {
			return gd::to_float(state.at(entry, 4));
		}
	}
	const double score = _attack_score_on(state, attacker, target, battle, is_ranged);
	const ArrayRef made = state.new_array();
	state.append(made, dict_value(attacker));
	state.append(made, dict_value(target));
	state.append(made, dict_value(battle));
	state.append(made, bool_value(is_ranged));
	state.append(made, float_value(score));
	_add_scoring_memo_entry(state, scoring_memo(state, key::_scoring_attack_scores), memo_key, made);
	return score;
}

double _attack_score_on(State &state, DictRef attacker, DictRef target, DictRef battle, bool is_ranged) {
	const int64_t attack_distance = _attack_distance_for_action(state, attacker, target, battle, is_ranged);
	const int64_t damage = _estimate_damage(state, attacker, target, battle, is_ranged, false, attack_distance);
	const int64_t target_health = engine_max<int64_t>(1, gd::int_field(state, target, key::total_health, 0));
	const int64_t applied_damage = engine_min<int64_t>(damage, target_health);
	const Atom side = side_of(state, attacker);
	const int64_t round_number = battle_round(state, battle);
	// Creatures killed, each weighed by the damage it deals: killing two dragons
	// beats killing twenty peasants. Each weighed term in the GDScript order:
	// the reads keep memos and _w may load the weights.
	const double target_unit_hp = static_cast<double>(engine_max<int64_t>(1, gd::int_field(state, target, key::unit_hp, 1)));
	const double threat_weight = _creature_threat_weight(state, battle, target);
	double score = static_cast<double>(applied_damage) / target_unit_hp * threat_weight * _w(state, key::attack_kills);
	score += variant_min_float(1.0, static_cast<double>(applied_damage) / static_cast<double>(target_health)) * _w(state, key::attack_damage_share);
	if (damage >= target_health) {
		score += _w(state, key::attack_lethal);
	}
	if (ranged(state, target)) {
		score += _w(state, key::attack_target_ranged);
	}
	if (has_shots(state, target)) {
		score += _w(state, key::attack_target_has_shots);
	}
	const DictRef foundry_aura = _ability_by_id(state, target, key::foundry_aura);
	if (!empty(state, foundry_aura)) {
		score += gd::float_field(state, foundry_aura, key::ai_target_priority_bonus, 0.0);
	}
	const double threat = _target_immediate_threat_score(state, attacker, target, battle);
	score += threat * _w(state, key::attack_target_threat);
	const double wounded = 1.0 - _health_ratio(state, target);
	score += wounded * _w(state, key::attack_target_wounded);
	const double cohesion_lost = cohesion_gap(state, target, battle);
	score += cohesion_lost * _w(state, key::attack_target_cohesion_lost);
	const double momentum = static_cast<double>(_stack_momentum_total(state, attacker, battle));
	score += momentum * _w(state, key::attack_momentum);
	if (_stack_cohesion_total(state, target, battle) <= 3) {
		score += _w(state, key::attack_target_shaken);
	}
	if (_stack_is_isolated(state, battle, target)) {
		score += _w(state, key::attack_target_isolated);
	}
	if (_stack_cohesion_total(state, attacker, battle) <= 4) {
		score -= _w(state, key::attack_own_shaken);
	}
	// A shooter next to an enemy shoots at x0.6 (_stack_is_engaged).
	const bool point_blank = is_ranged && _stack_is_engaged(state, attacker, battle);
	if (is_ranged && !point_blank) {
		score += _w(state, key::attack_clear_shot);
	}
	if (point_blank) {
		score -= _w(state, key::attack_point_blank);
	}
	if (is_ranged && attack_distance > 0 && _side_controls_field_objective_type(state, battle, side_of(state, target), key::cover_line)) {
		score -= _stack_is_cover_screened(state, target, battle) ? 2.5 : 1.0;
	}
	if (_side_controls_field_objective_type(state, battle, side_of(state, target), key::cover_line) && _stack_is_cover_screened(state, target, battle)) {
		score += 1.25;
	}
	if (_battle_has_tag(state, battle, key::elevated_fire) && is_ranged) {
		score += 2.0;
	}
	if (_battle_has_tag(state, battle, key::fog_bank) && is_ranged && attack_distance > 0 && !faction_brings_tag(state, attacker, key::fog_bank)) {
		score -= 2.0;
	}
	if (_battle_has_any_tags(state, battle, string_array(state, { key::chokepoint, key::fortified_line })) && !is_ranged) {
		score += 1.5;
	}
	if (_battle_has_tag(state, battle, key::fortress_lane)) {
		if (_stack_is_anchor_side(state, attacker, battle) && !is_ranged && holds_line(state, attacker, battle)) {
			score += 1.5;
		} else if (_stack_is_assault_side(state, attacker, battle) && is_ranged && gd::int_field(state, battle, key::distance, 1) > 0) {
			score -= 1.5;
		}
	}
	if (_reserve_wave_is_active_for_side(state, battle, side) && _stack_is_anchor_side(state, attacker, battle) && !_stack_is_isolated(state, battle, attacker)) {
		score += 1.5;
	}
	if (_battle_has_tag(state, battle, key::battery_nest) && _stack_is_anchor_side(state, attacker, battle) && is_ranged) {
		score += 2.0;
		if (_stack_has_positive_effect(state, attacker, battle)) {
			score += 1.0;
		}
	}
	if (_battle_has_tag(state, battle, key::wall_pressure) && _stack_is_assault_side(state, attacker, battle) && !is_ranged && round_number >= 3) {
		score += 1.75;
	}
	if (_side_controls_field_objective_type(state, battle, side_of(state, target), key::obstruction_line)
			&& (_has_ability(state, target, key::formation_guard)
					|| _brace_available(state, target, battle)
					|| _reach_available(state, target, battle)
					|| gd::bool_field(state, target, key::defending, false))) {
		score += 2.0;
	}
	if (_battle_has_tag(state, battle, key::bog_channels) && skirmisher(state, attacker)) {
		score += 1.5;
	}
	AbilityUses ability_uses;
	ability_uses.present = state.lookup(attacker, str(key::ability_uses), ability_uses.value);
	const DictRef harry = _ability_by_id(state, attacker, key::harry);
	const int64_t harry_limit = gd::int_field(state, harry, key::uses_per_battle, 0);
	const Atom harry_target_role = gd::string_field(state, harry, key::target_role, key::empty);
	const bool harry_target_ready = gd::int_field(state, target, key::tier, 1) >= gd::int_field(state, harry, key::target_min_tier, 1)
			&& (harry_target_role == key::empty || ranged(state, target) == (harry_target_role == key::ranged));
	const bool harry_support_gated = gd::int_field(state, harry, key::min_adjacent_allies_to_target, 0) > 0;
	const bool harry_available = ability_uses.is_dict()
			&& (is_ranged || harry_support_gated)
			&& harry_target_ready
			&& _harry_support_ready(state, attacker, target, battle, harry)
			&& (harry_limit <= 0 || ability_uses.count(state, key::harry) < harry_limit);
	const Atom harry_status_id = gd::string_field(state, harry, key::status_id, key::status_harried);
	if (!empty(state, harry) && harry_available && !spell_rules::has_effect_id(state, target, battle, harry_status_id)) {
		const double priority_bonus = gd::float_field(state, harry, key::ai_target_priority_bonus, 2.0);
		score += priority_bonus + gd::float_field(state, harry, key::support_ai_target_priority_bonus, 0.0);
	}
	const DictRef authored_harry = _authored_ability_by_id(state, attacker, key::harry);
	const DictRef target_shielding = _authored_ability_by_id(state, target, key::shielding);
	if (!empty(state, harry) && is_ranged && gd::bool_field(state, target_shielding, key::snare_vulnerable, false)) {
		score += gd::float_field(state, authored_harry, key::shielding_ai_target_priority_bonus, 0.0);
	}
	const DictRef rot_cant = _ability_by_id(state, attacker, key::rot_cant);
	const bool rot_available = ability_uses.is_dict()
			&& battle_round(state, battle) >= gd::int_field(state, rot_cant, key::available_from_round, 1)
			&& gd::int_field(state, target, key::tier, 1) >= gd::int_field(state, rot_cant, key::target_min_tier, 1)
			&& ability_uses.count(state, key::rot_cant) < gd::int_field(state, rot_cant, key::uses_per_battle, 1);
	if (!empty(state, rot_cant) && rot_available && is_ranged && !spell_rules::has_effect_id(state, target, battle, key::status_harried)) {
		score += gd::float_field(state, rot_cant, key::ai_target_priority_bonus, 0.25);
	}
	const DictRef obituary = _ability_by_id(state, attacker, key::obituary);
	const bool obituary_available = ability_uses.is_dict() && ability_uses.count(state, key::obituary) < gd::int_field(state, obituary, key::uses_per_battle, 1);
	if (!empty(state, obituary) && obituary_available && is_ranged && !spell_rules::has_effect_id(state, target, battle, key::status_obituary_marked)) {
		score += 0.25;
		if (_brace_available(state, target, battle) && gd::int_field(state, target, key::tier, 1) >= gd::int_field(state, obituary, key::braced_target_min_tier, 2)) {
			score += gd::float_field(state, obituary, key::braced_ai_target_priority_bonus, 0.25);
		}
	}
	if (_has_ability(state, attacker, key::backstab)
			&& empty(state, _counter_ambush_flare_context(state, battle, target, key::backstab))
			&& spell_rules::has_any_effect_ids(state, target, battle, pressure_status_ids(state))) {
		score += 2.5;
	}
	const DictRef bramble_ground = _bramble_ground_ability(state, attacker);
	if (!is_ranged && !empty(state, bramble_ground) && spell_rules::has_effect_id(state, target, battle, gd::string_field(state, bramble_ground, key::status_id, key::status_rooted))) {
		score += gd::float_field(state, bramble_ground, key::ai_rooted_target_priority_bonus, 0.0);
	}
	const DictRef fogwake = _ability_by_id(state, attacker, key::fogwake);
	if (!is_ranged && !empty(state, fogwake) && _stack_is_hex_isolated(state, battle, target) && empty(state, _counter_ambush_flare_context(state, battle, target, key::fogwake))) {
		score += gd::float_field(state, fogwake, key::ai_target_priority_bonus, 0.0);
	}
	if (is_ranged && _side_defending_count(state, battle, side) > 0 && _side_has_ability(state, battle, side, key::formation_guard)) {
		score += 1.5;
	}
	if (_has_ability(state, attacker, key::formation_guard) && spell_rules::has_effect_id(state, target, battle, key::status_staggered)) {
		score += 1.5;
	}
	const DictRef bloodrush = _ability_by_id(state, attacker, key::bloodrush);
	if (!empty(state, bloodrush) && gd::bool_field(state, bloodrush, key::primary_melee_only, false)) {
		if (!is_ranged && _health_ratio(state, target) <= gd::float_field(state, bloodrush, key::wounded_threshold_ratio, 0.0)) {
			score += 2.0;
		}
		if (!is_ranged && spell_rules::has_any_effect_ids(state, target, battle, field_or_array(state, bloodrush, key::status_ids))) {
			score += 1.5;
		}
		if (!is_ranged && gd::float_field(state, bloodrush, key::isolated_damage_multiplier, 1.0) > 1.0 && _stack_is_hex_isolated(state, battle, target)) {
			score += gd::float_field(state, bloodrush, key::isolated_ai_target_priority_bonus, 0.0);
		}
		if (gd::int_field(state, bloodrush, key::late_round_initiative_bonus, 0) > 0 && battle_round(state, battle) >= 3) {
			score += 0.75;
		}
	} else {
		if (!empty(state, bloodrush) && _health_ratio(state, target) <= gd::float_field(state, bloodrush, key::wounded_threshold_ratio, 0.0)) {
			score += 2.0;
		}
		if (!empty(state, bloodrush) && spell_rules::has_any_effect_ids(state, target, battle, field_or_array(state, bloodrush, key::status_ids))) {
			score += 1.5;
		}
		if (!empty(state, bloodrush) && gd::int_field(state, bloodrush, key::late_round_initiative_bonus, 0) > 0 && battle_round(state, battle) >= 3) {
			score += 0.75;
		}
	}
	const DictRef overheat = _ability_by_id(state, attacker, key::overheat);
	if (!empty(state, overheat) && !spell_rules::has_effect_id(state, attacker, battle, key::status_overheated)) {
		score += 0.10;
	}
	const DictRef readiness_writ = _readiness_writ_ability(state, attacker);
	if (is_ranged && _readiness_writ_available(state, attacker, battle, readiness_writ)
			&& !empty(state, _readiness_writ_target(state, battle, attacker, readiness_writ))) {
		score += gd::float_field(state, readiness_writ, key::ai_attack_score_bonus, 0.0);
	}
	if (is_ranged) {
		const DictRef pressure_artillery = _ability_by_id(state, attacker, key::pressure_artillery);
		if (!empty(state, pressure_artillery)) {
			const DictRef secondary_target = _pressure_artillery_secondary_target(state, battle, attacker, target);
			if (!empty(state, secondary_target)) {
				const int64_t secondary_damage = _pressure_artillery_secondary_damage(state, attacker);
				const int64_t secondary_health = engine_max<int64_t>(1, gd::int_field(state, secondary_target, key::total_health, 0));
				const int64_t secondary_applied = engine_min<int64_t>(secondary_damage, secondary_health);
				score += static_cast<double>(secondary_applied) / static_cast<double>(engine_max<int64_t>(1, gd::int_field(state, secondary_target, key::unit_hp, 1)));
				score += variant_min_float(1.0, static_cast<double>(secondary_applied) / static_cast<double>(secondary_health)) * 5.0;
				if (secondary_damage >= secondary_health) {
					score += 2.0;
				}
			}
			if (!spell_rules::has_effect_id(state, attacker, battle, key::status_overheated)) {
				score -= gd::float_field(state, pressure_artillery, key::ai_heat_score_penalty, 0.5);
			}
		}
	}
	if (_hero_has_trait(state, battle, side, key::artillerist) && is_ranged && _battle_has_any_tags(state, battle, string_array(state, { key::elevated_fire, key::open_lane }))) {
		score += 1.5;
	}
	if (_hero_has_trait(state, battle, side, key::packhunter)
			&& (_health_ratio(state, target) <= 0.75 || spell_rules::has_any_effect_ids(state, target, battle, pressure_status_ids(state)))) {
		score += 1.25;
	}
	if (_hero_has_trait(state, battle, side, key::vanguard) && !is_ranged && battle_round(state, battle) <= 2) {
		score += 1.0;
	}
	if (_hero_has_trait(state, battle, side, key::ambusher) && !is_ranged
			&& (gd::string_field(state, battle, key::terrain, key::empty) == key::forest || _battle_has_tag(state, battle, key::ambush_cover))
			&& battle_round(state, battle) <= 2) {
		score += 1.0;
	}
	if (is_ranged && _side_controls_field_objective_type(state, battle, side, key::cover_line) && _stack_is_cover_screened(state, attacker, battle)) {
		score += 1.25;
	}
	score += _objective_action_score(state, battle, side, is_ranged ? key::shoot : key::strike, attacker, target);
	if (is_ranged && damage < target_health) {
		const DictRef shielding = _ability_by_id(state, target, key::shielding);
		const double return_ratio = engine_clamp<double>(gd::float_field(state, shielding, key::ranged_damage_return_ratio, 0.0), 0.0, 0.25);
		if (return_ratio > 0.0) {
			const int64_t reflected_damage = engine_max<int64_t>(1, float_to_int(godot_round(static_cast<double>(applied_damage) * return_ratio)));
			score -= (static_cast<double>(reflected_damage) / static_cast<double>(engine_max<int64_t>(1, gd::int_field(state, attacker, key::unit_hp, 1)))) * 0.45;
			if (reflected_damage >= gd::int_field(state, attacker, key::total_health, 0)) {
				score -= 6.0;
			}
		}
	}
	if (!is_ranged && gd::int_field(state, target, key::retaliations_left, 0) > 0 && _alive_count(state, target) > 0 && _can_make_retaliation(state, target, attack_distance, battle)) {
		const int64_t retaliation_damage = _estimate_damage(state, target, attacker, battle, false, true, attack_distance);
		const double strike_back = static_cast<double>(retaliation_damage) / static_cast<double>(engine_max<int64_t>(1, gd::int_field(state, attacker, key::unit_hp, 1)));
		score -= strike_back * _w(state, key::attack_strike_back);
	}
	return score;
}

double _defend_score(State &state, DictRef battle, DictRef active_stack, ArrayRef targets) {
	const double base = _w(state, key::defend_base);
	const double wounded = 1.0 - _health_ratio(state, active_stack);
	double score = base + (wounded * _w(state, key::defend_wounded));
	// var round_number: read, never used.
	(void)battle_round(state, battle);
	const int64_t contact = _stack_contact_band(state, active_stack, battle);
	const double cohesion_lost = cohesion_gap(state, active_stack, battle);
	score += cohesion_lost * _w(state, key::defend_cohesion_lost);
	if (ranged(state, active_stack) && has_shots(state, active_stack)) {
		score -= _w(state, key::defend_shooter);
	}
	if (contact > 0 && _fights_in_melee(state, active_stack)) {
		score -= _w(state, key::defend_melee_out_of_contact);
	}
	if ((_brace_available(state, active_stack, battle) || _bramble_ground_available(state, active_stack, battle, state.new_dict())) && contact <= 1) {
		score += _w(state, key::defend_brace);
	}
	const DictRef charter_aura = _charter_retaliation_aura_context(state, active_stack, battle);
	if (!empty(state, charter_aura) && _has_ability(state, active_stack, key::brace)) {
		// charter_aura.get("ability", {}).get(...): the new {} holds no bonus.
		Value ability;
		const double bonus = state.lookup(charter_aura, str(key::ability), ability)
				? gd::float_field(state, get_base(ability), key::ally_retaliation_ai_defend_bonus, 0.0)
				: 0.0;
		score += bonus;
	}
	if (_has_ability(state, active_stack, key::formation_guard) && _allied_ranged_count(state, battle, side_of(state, active_stack)) > 0) {
		score += 2.5;
	}
	if (_has_ability(state, active_stack, key::overheat) && spell_rules::has_effect_id(state, active_stack, battle, key::status_overheated)) {
		score += 0.25;
	}
	if (_battle_has_any_tags(state, battle, string_array(state, { key::chokepoint, key::fortified_line })) && !ranged(state, active_stack)) {
		score += 1.5;
	}
	if (_battle_has_tag(state, battle, key::fortress_lane) && _stack_is_anchor_side(state, active_stack, battle) && !ranged(state, active_stack)) {
		score += 2.0;
	}
	if (_reserve_wave_is_active_for_side(state, battle, side_of(state, active_stack)) && _stack_is_anchor_side(state, active_stack, battle)) {
		score += 1.5;
	}
	if (_battle_has_tag(state, battle, key::battery_nest) && _stack_is_anchor_side(state, active_stack, battle) && ranged(state, active_stack) && _stack_has_positive_effect(state, active_stack, battle)) {
		score += 1.0;
	}
	if (_side_controls_field_objective_type(state, battle, side_of(state, active_stack), key::cover_line) && ranged(state, active_stack) && contact > 0) {
		score += 2.0;
	}
	if (_side_controls_field_objective_type(state, battle, side_of(state, active_stack), key::obstruction_line)
			&& _stack_can_breach_obstruction(state, active_stack, battle)
			&& gd::int_field(state, battle, key::distance, 1) > 0) {
		score += 2.0;
	}
	if (contact == 0 && _has_hostile_ranged_pressure(state, targets)) {
		score += _w(state, key::defend_in_contact_under_fire);
	}
	if (_stack_is_isolated(state, battle, active_stack)) {
		score += _w(state, key::defend_isolated);
	}
	if (_hero_has_trait(state, battle, side_of(state, active_stack), key::linekeeper)) {
		score += 1.0;
	}
	score += _objective_action_score(state, battle, side_of(state, active_stack), key::defend, active_stack, active_stack);
	const double clock_weight = _w(state, key::defend_clock);
	score -= clock_weight * static_cast<double>(_clock_pressure(state, battle));
	return score;
}

double _advance_score(State &state, DictRef battle, DictRef active_stack, ArrayRef targets) {
	// A rooted stack cannot move (BattleRules.action_availability), so advancing
	// or repositioning is not an order it can be given.
	if (_stack_is_rooted(state, active_stack, battle)) {
		return -9999.0;
	}
	const int64_t current_distance = _stack_contact_band(state, active_stack, battle);
	const Atom side = side_of(state, active_stack);
	const int64_t round_number = battle_round(state, battle);
	// A shooter with no shots left closes in like a melee stack.
	const bool shooter = !_fights_in_melee(state, active_stack);
	if (current_distance <= 0) {
		if (_can_make_melee_attack(state, active_stack, battle, state.new_dict()) || (shooter && _can_make_any_ranged_attack(state, active_stack, battle, targets))) {
			return -9999.0;
		}
		double reposition_score = _w(state, key::reposition_base);
		if (!shooter) {
			reposition_score += _w(state, key::reposition_melee);
		}
		if (_has_hostile_ranged_pressure(state, targets)) {
			reposition_score += _w(state, key::reposition_under_fire);
		}
		if (_stack_is_isolated(state, battle, active_stack)) {
			reposition_score += 1.0;
		}
		reposition_score += _objective_action_score(state, battle, side, key::advance, active_stack, state.new_dict());
		return reposition_score;
	}
	const int64_t distance_delta = _advance_distance_delta(state, active_stack, battle);
	double score = _w(state, key::advance_base);
	if (_should_close_distance(state, active_stack)) {
		score += _w(state, key::advance_close_in);
	}
	if (!shooter) {
		score += _w(state, key::advance_melee);
		if (!_can_make_melee_attack(state, active_stack, battle, state.new_dict())) {
			score += _w(state, key::advance_melee_out_of_reach);
			if (_has_hostile_ranged_pressure(state, targets)) {
				score += _w(state, key::advance_melee_out_of_reach_under_fire);
			}
		}
		if (current_distance >= 2) {
			score += _w(state, key::advance_far);
		}
	} else {
		score -= _w(state, key::advance_shooter);
	}
	if (_has_hostile_ranged_pressure(state, targets) && !shooter) {
		score += _w(state, key::advance_melee_under_fire);
	}
	if (distance_delta <= 0) {
		score -= _w(state, key::advance_no_gain);
	} else {
		score += _w(state, key::advance_gain);
		if (_side_controls_field_objective_type(state, battle, _opposing_side(side), key::obstruction_line)) {
			if (_stack_can_breach_obstruction(state, active_stack, battle)) {
				score += 1.5;
			} else {
				score -= 1.5;
			}
		}
		if (_side_controls_field_objective_type(state, battle, side, key::obstruction_line)) {
			score -= 3.0;
		}
		if (_stack_cohesion_total(state, active_stack, battle) <= 4) {
			score -= _w(state, key::advance_own_shaken);
		}
	}
	if (_stack_is_isolated(state, battle, active_stack)) {
		score -= _w(state, key::advance_isolated);
	}
	if (_battle_has_tag(state, battle, key::wall_pressure) && _stack_is_assault_side(state, active_stack, battle) && !shooter && round_number >= 3) {
		score += 1.25;
	}
	if (_hero_has_trait(state, battle, side, key::vanguard) && !shooter && round_number <= 2) {
		score += 1.0;
	}
	if (_hero_has_trait(state, battle, side, key::packhunter) && _enemy_wounded_count(state, battle, side) > 0 && !shooter) {
		score += 0.75;
	}
	score += _objective_action_score(state, battle, side, key::advance, active_stack, state.new_dict());
	if (!shooter) {
		const double clock_weight = _w(state, key::advance_clock);
		score += clock_weight * static_cast<double>(_clock_pressure(state, battle));
	}
	return score;
}

bool _should_hold_line(State &state, DictRef battle, DictRef stack) {
	if (!_fights_in_melee(state, stack) || _clock_pressure(state, battle) > 0) {
		return false;
	}
	const Atom side = side_of(state, stack);
	const double own_power = _side_ranged_power(state, battle, side);
	const double other_power = _side_ranged_power(state, battle, _opposing_side(side));
	return own_power > other_power * _w(state, key::hold_ranged_ratio);
}

DictRef choose_melee_approach(State &state, DictRef battle, DictRef stack, DictRef target, ArrayRef cells) {
	_open_scoring_scope(state);
	const DictRef approach = _melee_approach_choice(state, battle, stack, target, cells);
	_close_scoring_scope(state);
	return approach;
}

DictRef _melee_approach_choice(State &state, DictRef battle, DictRef stack, DictRef target, ArrayRef cells) {
	DictRef best = state.new_dict();
	double best_score = 0.0;
	for (const Value &cell : gd::items(state, array_value(cells))) {
		if (!gd::is_dict(cell)) {
			continue;
		}
		const double score = _melee_approach_score(state, battle, stack, target, cell.ref);
		if (empty(state, best) || score > best_score + 0.001) {
			best = gd::deep_duplicate_dict(state, cell.ref);
			best_score = score;
		}
	}
	if (!empty(state, best)) {
		state.set(best, str(key::score), float_value(compat::snappedf(best_score, 0.01)));
	}
	return best;
}

double _melee_approach_score(State &state, DictRef battle, DictRef stack, DictRef target, DictRef cell) {
	const ArrayRef projection = _projected_on_cell(state, battle, stack, cell);
	const DictRef projected = gd::as_dict(state.at(projection, 0));
	const DictRef projected_battle = gd::as_dict(state.at(projection, 1));
	const int64_t attack_distance = _attack_distance_for_action(state, projected, target, projected_battle, false);
	const int64_t target_health = engine_max<int64_t>(1, gd::int_field(state, target, key::total_health, 0));
	const int64_t damage = engine_min<int64_t>(_estimate_damage(state, projected, target, projected_battle, false, false, attack_distance), target_health);
	const double target_unit_hp = static_cast<double>(engine_max<int64_t>(1, gd::int_field(state, target, key::unit_hp, 1)));
	double score = static_cast<double>(damage) / target_unit_hp * _average_unit_damage(state, target);
	if (damage < target_health && gd::int_field(state, target, key::retaliations_left, 1) > 0 && _can_make_retaliation(state, target, attack_distance, projected_battle)) {
		const DictRef survivor = gd::duplicate_dict(state, target);
		state.set(survivor, str(key::total_health), int_value(gd::sub(target_health, damage)));
		const int64_t retaliation = _estimate_damage(state, survivor, projected, projected_battle, false, true, attack_distance);
		const int64_t strike_back = engine_min<int64_t>(retaliation, gd::int_field(state, projected, key::total_health, 0));
		const double projected_unit_hp = static_cast<double>(engine_max<int64_t>(1, gd::int_field(state, projected, key::unit_hp, 1)));
		score -= static_cast<double>(strike_back) / projected_unit_hp * _average_unit_damage(state, projected);
	}
	for (const Value &enemy_value : gd::items(state, array_value(_alive_stacks_for_side(state, projected_battle, side_of(state, target))))) {
		const DictRef enemy = gd::as_dict(enemy_value);
		if (ranged(state, enemy) && has_shots(state, enemy) && _stack_hex_distance(state, projected, enemy) <= 1) {
			const double weight = _w(state, key::approach_next_to_shooter);
			score += weight * static_cast<double>(_alive_count(state, enemy)) * _average_unit_damage(state, enemy);
		}
	}
	return score;
}

} // namespace aurelion::rules::port::battle_ai_rules
