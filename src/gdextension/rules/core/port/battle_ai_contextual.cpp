// BattleAiRules' own copies of the contextual attack, defense, cohesion and
// momentum bonuses, the cohesion and momentum totals with their scoring memos,
// the obstruction breach, the advance delta and the readiness writ's target.

#include "aurelion_rules/port/battle_ai_rules.hpp"
#include "aurelion_rules/port/spell_rules.hpp"

#include "aurelion_rules/compat/godot_math.hpp"

#include <initializer_list>

namespace aurelion::rules::port::battle_ai_rules {

using compat::engine_clamp;
using compat::engine_max;
using gd::array_value;
using gd::dict_value;
using gd::int_value;
using gd::str;
namespace key = state::key;

namespace {

constexpr int64_t kCohesionMin = 0;
constexpr int64_t kCohesionMax = 10;
constexpr int64_t kMomentumMax = 4;

// String(stack.get("side", ""))
Atom side_of(const State &state, DictRef stack) {
	return gd::string_field(state, stack, key::side, key::empty);
}

// bool(stack.get("ranged", false))
bool ranged(const State &state, DictRef stack) {
	return gd::bool_field(state, stack, key::ranged, false);
}

// int(battle.get("round", 1))
int64_t battle_round(const State &state, DictRef battle) {
	return gd::int_field(state, battle, key::round, 1);
}

// int(battle.get("distance", 1))
int64_t battle_distance(const State &state, DictRef battle) {
	return gd::int_field(state, battle, key::distance, 1);
}

// String(battle.get("terrain", "")) == terrain
bool battle_terrain_is(const State &state, DictRef battle, Atom terrain) {
	return gd::string_field(state, battle, key::terrain, key::empty) == terrain;
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

// An Array literal of String constants: a new untyped Array.
ArrayRef string_array(State &state, std::initializer_list<Atom> atoms) {
	const ArrayRef array = state.new_array();
	for (const Atom atom : atoms) {
		state.append(array, str(atom));
	}
	return array;
}

// _has_ability(stack, "harry") or _has_ability(stack, "backstab") or _has_ability(stack, "bloodrush")
bool skirmisher(State &state, DictRef stack) {
	return _has_ability(state, stack, key::harry) || _has_ability(state, stack, key::backstab) || _has_ability(state, stack, key::bloodrush);
}

// _reach_available(stack, battle) or _brace_available(stack, battle) or _has_ability(stack, "formation_guard")
bool holds_line(State &state, DictRef stack, DictRef battle) {
	return _reach_available(state, stack, battle) || _brace_available(state, stack, battle) || _has_ability(state, stack, key::formation_guard);
}

// _scoring_scope_depth > 0
bool scoring_scope_open(State &state) {
	return gd::to_int(state, gd::static_var(state, key::battle_ai_rules_script, key::_scoring_scope_depth)) > 0;
}

DictRef scoring_memo(State &state, Atom name) {
	return gd::as_dict(gd::static_var(state, key::battle_ai_rules_script, name));
}

// [stack, battle, total]
ArrayRef total_entry(State &state, DictRef stack, DictRef battle, int64_t total) {
	const ArrayRef entry = state.new_array();
	state.append(entry, dict_value(stack));
	state.append(entry, dict_value(battle));
	state.append(entry, int_value(total));
	return entry;
}

// var x := ability if not ability.is_empty() else _readiness_writ_ability(source)
DictRef readiness_writ_or_authored(State &state, DictRef source, DictRef ability) {
	return !gd::is_empty(state, ability) ? ability : _readiness_writ_ability(state, source);
}

} // namespace

bool _stack_can_breach_obstruction(State &state, DictRef stack, DictRef battle) {
	if (gd::is_empty(state, stack) || ranged(state, stack)) {
		return false;
	}
	if (holds_line(state, stack, battle)) {
		return true;
	}
	if (_stack_momentum_total(state, stack, battle) >= 2) {
		return true;
	}
	return gd::int_field(state, stack, key::speed, 0) >= 5;
}

int64_t _advance_distance_delta(State &state, DictRef stack, DictRef battle) {
	if (gd::is_empty(state, stack) || _stack_contact_band(state, stack, battle) <= 0) {
		return 0;
	}
	const Atom opposing_side = _opposing_side(side_of(state, stack));
	if (battle_distance(state, battle) > 0
			&& _side_controls_field_objective_type(state, battle, opposing_side, key::obstruction_line)
			&& !_stack_can_breach_obstruction(state, stack, battle)) {
		return 0;
	}
	return 1;
}

int64_t _contextual_attack_bonus(State &state, DictRef stack, DictRef battle) {
	const ArrayRef memo = _stack_term_memo(state, key::attack_bonus, stack, battle);
	if (state.array_size(memo) == 3) {
		return gd::to_int(state, state.at(memo, 2));
	}
	const int64_t value = _contextual_attack_bonus_on(state, stack, battle);
	_keep_stack_term(state, memo, int_value(value));
	return value;
}

int64_t _contextual_attack_bonus_on(State &state, DictRef stack, DictRef battle) {
	int64_t bonus = 0;
	const Atom side = side_of(state, stack);
	const int64_t round_number = battle_round(state, battle);
	if (_battle_has_tag(state, battle, key::elevated_fire) && ranged(state, stack)) {
		bonus += 1;
	}
	if (_battle_has_tag(state, battle, key::bog_channels) && skirmisher(state, stack)) {
		bonus += 1;
	}
	if (_battle_has_tag(state, battle, key::fortress_lane)) {
		if (_stack_is_anchor_side(state, stack, battle) && !ranged(state, stack) && holds_line(state, stack, battle)) {
			bonus += 1;
		} else if (_stack_is_assault_side(state, stack, battle) && ranged(state, stack) && battle_distance(state, battle) > 0) {
			bonus -= 1;
		}
	}
	if (_reserve_wave_is_active_for_side(state, battle, side) && _stack_is_anchor_side(state, stack, battle) && !_stack_is_isolated(state, battle, stack)) {
		bonus += 1;
	}
	if (_battle_has_tag(state, battle, key::battery_nest) && _stack_is_anchor_side(state, stack, battle) && ranged(state, stack)) {
		bonus += 1;
		if (_stack_has_positive_effect(state, stack, battle)) {
			bonus += 1;
		}
	}
	if (_battle_has_tag(state, battle, key::wall_pressure) && _stack_is_assault_side(state, stack, battle) && !ranged(state, stack) && round_number >= 3) {
		bonus += 1;
	}
	if (_hero_has_trait(state, battle, side, key::artillerist) && ranged(state, stack) && any_tag(state, battle, { key::elevated_fire, key::open_lane })) {
		bonus += 1;
	}
	if (_hero_has_trait(state, battle, side, key::packhunter) && _enemy_wounded_count(state, battle, side) > 0) {
		bonus += 1;
	}
	if (_hero_has_trait(state, battle, side, key::vanguard) && !ranged(state, stack) && battle_round(state, battle) <= 2) {
		bonus += 1;
	}
	if (_hero_has_trait(state, battle, side, key::ambusher) && !ranged(state, stack) && _battle_has_tag(state, battle, key::ambush_cover) && battle_round(state, battle) <= 2) {
		bonus += 1;
	}
	if (_hero_has_trait(state, battle, side, key::bogwise) && (_battle_has_tag(state, battle, key::bog_channels) || battle_terrain_is(state, battle, key::mire)) && skirmisher(state, stack)) {
		bonus += 1;
	}
	if (gd::string_field(state, stack, key::faction_id, key::empty) == key::faction_sunvault && _stack_has_positive_effect(state, stack, battle)) {
		bonus += 1;
		if (ranged(state, stack) && any_tag(state, battle, { key::elevated_fire, key::open_lane })) {
			bonus += 1;
		}
	}
	bonus = gd::add(bonus, _field_objective_attack_bonus(state, stack, battle));
	return bonus;
}

int64_t _contextual_defense_bonus(State &state, DictRef stack, DictRef battle) {
	const ArrayRef memo = _stack_term_memo(state, key::defense_bonus, stack, battle);
	if (state.array_size(memo) == 3) {
		return gd::to_int(state, state.at(memo, 2));
	}
	const int64_t value = _contextual_defense_bonus_on(state, stack, battle);
	_keep_stack_term(state, memo, int_value(value));
	return value;
}

int64_t _contextual_defense_bonus_on(State &state, DictRef stack, DictRef battle) {
	int64_t bonus = 0;
	const Atom side = side_of(state, stack);
	// round_number is read (and converted) but not used, as in GDScript.
	const int64_t round_number = battle_round(state, battle);
	static_cast<void>(round_number);
	if (any_tag(state, battle, { key::chokepoint, key::fortified_line }) && !ranged(state, stack) && holds_line(state, stack, battle)) {
		bonus += 1;
	}
	if (_battle_has_tag(state, battle, key::fortress_lane) && _stack_is_anchor_side(state, stack, battle) && !ranged(state, stack) && holds_line(state, stack, battle)) {
		bonus += 1;
	}
	if (_reserve_wave_is_active_for_side(state, battle, side) && _stack_is_anchor_side(state, stack, battle) && !_stack_is_isolated(state, battle, stack)) {
		bonus += 1;
	}
	if (_battle_has_tag(state, battle, key::battery_nest) && _stack_is_anchor_side(state, stack, battle) && ranged(state, stack) && _stack_has_positive_effect(state, stack, battle)) {
		bonus += 1;
	}
	if (_hero_has_trait(state, battle, side, key::linekeeper)
			&& (gd::bool_field(state, stack, key::defending, false) || _brace_available(state, stack, battle) || _has_ability(state, stack, key::formation_guard))) {
		bonus += 1;
	}
	if (_hero_has_trait(state, battle, side, key::bogwise) && battle_terrain_is(state, battle, key::mire) && !ranged(state, stack)) {
		bonus += 1;
	}
	bonus = gd::add(bonus, _field_objective_defense_bonus(state, stack, battle));
	return bonus;
}

int64_t _stack_cohesion_total(State &state, DictRef stack, DictRef battle) {
	if (!scoring_scope_open(state)) {
		return _stack_cohesion_sum(state, stack, battle);
	}
	const Atom memo_key = gd::string_field(state, stack, key::battle_id, key::empty);
	const ArrayRef entry = _scoring_memo_entry(state, scoring_memo(state, key::_scoring_cohesion), memo_key, stack, battle);
	if (state.array_size(entry) > 0) {
		return gd::to_int(state, state.at(entry, 2));
	}
	const int64_t total = _stack_cohesion_sum(state, stack, battle);
	_add_scoring_memo_entry(state, scoring_memo(state, key::_scoring_cohesion), memo_key, total_entry(state, stack, battle, total));
	return total;
}

int64_t _stack_momentum_total(State &state, DictRef stack, DictRef battle) {
	if (!scoring_scope_open(state)) {
		return _stack_momentum_sum(state, stack, battle);
	}
	const Atom memo_key = gd::string_field(state, stack, key::battle_id, key::empty);
	const ArrayRef entry = _scoring_memo_entry(state, scoring_memo(state, key::_scoring_momentum), memo_key, stack, battle);
	if (state.array_size(entry) > 0) {
		return gd::to_int(state, state.at(entry, 2));
	}
	const int64_t total = _stack_momentum_sum(state, stack, battle);
	_add_scoring_memo_entry(state, scoring_memo(state, key::_scoring_momentum), memo_key, total_entry(state, stack, battle, total));
	return total;
}

int64_t _stack_cohesion_sum(State &state, DictRef stack, DictRef battle) {
	// int(stack.get("cohesion", stack.get("cohesion_base", 5))): the fallback is read first.
	const Value fallback = state.get(stack, str(key::cohesion_base), int_value(5));
	int64_t total = gd::to_int(state, state.get(stack, str(key::cohesion), fallback));
	total = gd::add(total, spell_rules::effect_bonus_for_kind(state, stack, battle, key::cohesion));
	total = gd::add(total, _contextual_cohesion_bonus(state, stack, battle));
	return engine_clamp<int64_t>(total, kCohesionMin, kCohesionMax);
}

int64_t _stack_momentum_sum(State &state, DictRef stack, DictRef battle) {
	int64_t total = gd::int_field(state, stack, key::momentum, 0);
	total = gd::add(total, spell_rules::effect_bonus_for_kind(state, stack, battle, key::momentum));
	total = gd::add(total, _contextual_momentum_bonus(state, stack, battle));
	return engine_clamp<int64_t>(total, 0, kMomentumMax);
}

int64_t _contextual_cohesion_bonus(State &state, DictRef stack, DictRef battle) {
	int64_t bonus = 0;
	const Atom side = side_of(state, stack);
	const int64_t round_number = battle_round(state, battle);
	if (_stack_is_isolated(state, battle, stack)) {
		bonus -= 1;
	}
	if (any_tag(state, battle, { key::chokepoint, key::fortified_line }) && !ranged(state, stack) && holds_line(state, stack, battle)) {
		bonus += 1;
	}
	if (_battle_has_tag(state, battle, key::fortress_lane) && _stack_is_anchor_side(state, stack, battle) && !ranged(state, stack) && holds_line(state, stack, battle)) {
		bonus += 1;
	}
	if (any_tag(state, battle, { key::elevated_fire, key::open_lane }) && ranged(state, stack)) {
		bonus += 1;
	}
	if (_reserve_wave_is_active_for_side(state, battle, side) && _stack_is_anchor_side(state, stack, battle) && !_stack_is_isolated(state, battle, stack)) {
		bonus += 1;
	}
	if (_battle_has_tag(state, battle, key::battery_nest) && _stack_is_anchor_side(state, stack, battle) && ranged(state, stack)) {
		bonus += 1;
		if (_stack_has_positive_effect(state, stack, battle)) {
			bonus += 1;
		}
	}
	if (_battle_has_tag(state, battle, key::wall_pressure) && _stack_is_assault_side(state, stack, battle) && !ranged(state, stack) && round_number >= 3) {
		bonus += 1;
	}
	if (spell_rules::has_any_effect_ids(state, stack, battle, array_value(string_array(state, { key::status_harried, key::status_staggered })))) {
		bonus -= 1;
	}
	const DictRef shielding = _ability_by_id(state, stack, key::shielding);
	if (!gd::is_empty(state, shielding)) {
		bonus = gd::add(bonus, engine_max<int64_t>(0, gd::int_field(state, shielding, key::cohesion_hold_bonus, 0)));
	}
	if (_hero_has_trait(state, battle, side, key::linekeeper)
			&& (gd::bool_field(state, stack, key::defending, false) || _brace_available(state, stack, battle) || _has_ability(state, stack, key::formation_guard))) {
		bonus = gd::add(bonus, 1);
	}
	if (_hero_has_trait(state, battle, side, key::artillerist) && ranged(state, stack) && any_tag(state, battle, { key::elevated_fire, key::open_lane })) {
		bonus = gd::add(bonus, 1);
	}
	if (_hero_has_trait(state, battle, side, key::bogwise)
			&& (_battle_has_tag(state, battle, key::bog_channels) || battle_terrain_is(state, battle, key::mire))
			&& !_stack_is_isolated(state, battle, stack)) {
		bonus = gd::add(bonus, 1);
	}
	if (_hero_has_trait(state, battle, side, key::ambusher) && !ranged(state, stack) && battle_round(state, battle) <= 2 && _battle_has_tag(state, battle, key::ambush_cover)) {
		bonus = gd::add(bonus, 1);
	}
	if (gd::string_field(state, stack, key::faction_id, key::empty) == key::faction_embercourt && _side_has_role_mix(state, battle, side) && !_stack_is_isolated(state, battle, stack)) {
		bonus = gd::add(bonus, 1);
	}
	if (gd::string_field(state, stack, key::faction_id, key::empty) == key::faction_mireclaw && _enemy_wounded_count(state, battle, side) > 0 && !ranged(state, stack)) {
		bonus = gd::add(bonus, 1);
	}
	if (gd::string_field(state, stack, key::faction_id, key::empty) == key::faction_sunvault && _stack_has_positive_effect(state, stack, battle) && !_stack_is_isolated(state, battle, stack)) {
		bonus = gd::add(bonus, 1);
		if (any_tag(state, battle, { key::fortified_line, key::elevated_fire })) {
			bonus = gd::add(bonus, 1);
		}
	}
	bonus = gd::add(bonus, _field_objective_cohesion_bonus(state, stack, battle));
	return bonus;
}

int64_t _contextual_momentum_bonus(State &state, DictRef stack, DictRef battle) {
	int64_t bonus = 0;
	const Atom side = side_of(state, stack);
	const int64_t round_number = battle_round(state, battle);
	if (_battle_has_tag(state, battle, key::ambush_cover) && !ranged(state, stack) && battle_round(state, battle) <= 2) {
		bonus += 1;
	}
	if (any_tag(state, battle, { key::elevated_fire, key::open_lane }) && ranged(state, stack) && battle_round(state, battle) <= 2) {
		bonus += 1;
	}
	if (_battle_has_tag(state, battle, key::bog_channels) && skirmisher(state, stack)) {
		bonus += 1;
	}
	if (_reserve_wave_is_active_for_side(state, battle, side) && _stack_is_anchor_side(state, stack, battle) && !_stack_is_isolated(state, battle, stack)) {
		bonus += 1;
	}
	if (_battle_has_tag(state, battle, key::battery_nest) && _stack_is_anchor_side(state, stack, battle) && ranged(state, stack)
			&& (_stack_has_positive_effect(state, stack, battle) || round_number <= 2)) {
		bonus += 1;
	}
	if (_battle_has_tag(state, battle, key::wall_pressure) && _stack_is_assault_side(state, stack, battle) && !ranged(state, stack) && round_number >= 3) {
		bonus += 1;
	}
	if (_hero_has_trait(state, battle, side, key::packhunter) && _enemy_wounded_count(state, battle, side) > 0 && !ranged(state, stack)) {
		bonus += 1;
	}
	if (_hero_has_trait(state, battle, side, key::vanguard) && !ranged(state, stack)
			&& (battle_round(state, battle) <= 2 || _battle_has_tag(state, battle, key::open_lane))) {
		bonus += 1;
	}
	if (_hero_has_trait(state, battle, side, key::ambusher) && !ranged(state, stack) && battle_round(state, battle) <= 2
			&& (battle_terrain_is(state, battle, key::forest) || _battle_has_tag(state, battle, key::ambush_cover))) {
		bonus += 1;
	}
	if (_hero_has_trait(state, battle, side, key::artillerist) && ranged(state, stack) && any_tag(state, battle, { key::elevated_fire, key::open_lane })) {
		bonus += 1;
	}
	if (_hero_has_trait(state, battle, side, key::bogwise)
			&& (_battle_has_tag(state, battle, key::bog_channels) || battle_terrain_is(state, battle, key::mire))
			&& skirmisher(state, stack)) {
		bonus += 1;
	}
	if (gd::string_field(state, stack, key::faction_id, key::empty) == key::faction_sunvault && _stack_has_positive_effect(state, stack, battle)) {
		bonus += 1;
		if (_side_positive_effect_count(state, battle, side) >= 2 && any_tag(state, battle, { key::elevated_fire, key::fortified_line })) {
			bonus += 1;
		}
	}
	bonus = gd::add(bonus, _field_objective_momentum_bonus(state, stack, battle));
	return bonus;
}

DictRef _readiness_writ_target(State &state, DictRef battle, DictRef source, DictRef ability) {
	const DictRef readiness_writ = readiness_writ_or_authored(state, source, ability);
	if (gd::is_empty(state, source) || gd::is_empty(state, readiness_writ)) {
		return state.new_dict();
	}
	const Atom source_id = gd::string_field(state, source, key::battle_id, key::empty);
	DictRef best = state.new_dict();
	int64_t best_effect_count = 0;
	int64_t best_cohesion = 999;
	int64_t best_tier = 0;
	const ArrayRef candidates = _alive_stacks_for_side(state, battle, side_of(state, source));
	for (const Value &candidate_value : gd::items(state, array_value(candidates))) {
		const DictRef candidate = gd::as_dict(candidate_value);
		if (gd::string_field(state, candidate, key::battle_id, key::empty) == source_id) {
			continue;
		}
		const int64_t effect_count = _readiness_writ_effect_count(state, candidate, battle, readiness_writ);
		if (effect_count <= 0) {
			continue;
		}
		const int64_t cohesion = _stack_cohesion_total(state, candidate, battle);
		const int64_t tier = gd::int_field(state, candidate, key::tier, 1);
		const Atom candidate_id = gd::string_field(state, candidate, key::battle_id, key::empty);
		const Atom best_id = gd::string_field(state, best, key::battle_id, key::empty);
		// String < String: code point by code point, as the UTF-8 bytes compared unsigned.
		if (gd::is_empty(state, best) || effect_count > best_effect_count
				|| (effect_count == best_effect_count && cohesion < best_cohesion)
				|| (effect_count == best_effect_count && cohesion == best_cohesion && tier > best_tier)
				|| (effect_count == best_effect_count && cohesion == best_cohesion && tier == best_tier && state.text(candidate_id) < state.text(best_id))) {
			best = candidate;
			best_effect_count = effect_count;
			best_cohesion = cohesion;
			best_tier = tier;
		}
	}
	return best;
}

bool _readiness_writ_available(State &state, DictRef source, DictRef battle, DictRef ability) {
	const DictRef readiness_writ = readiness_writ_or_authored(state, source, ability);
	if (gd::is_empty(state, source) || gd::is_empty(state, readiness_writ) || _alive_count(state, source) <= 0 || !ranged(state, source)) {
		return false;
	}
	// var ability_uses = source.get("ability_uses", {}): the default {} holds no uses.
	int64_t used = 0;
	Value ability_uses;
	if (state.lookup(source, str(key::ability_uses), ability_uses)) {
		if (!gd::is_dict(ability_uses)) {
			return false;
		}
		used = gd::int_field(state, ability_uses.ref, key::readiness_writ, 0);
	}
	if (used >= gd::int_field(state, readiness_writ, key::uses_per_battle, 1)) {
		return false;
	}
	return !gd::is_empty(state, _readiness_writ_target(state, battle, source, readiness_writ));
}

} // namespace aurelion::rules::port::battle_ai_rules
