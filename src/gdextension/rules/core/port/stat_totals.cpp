// Layer 2: the stat totals and their contextual, cohesion, momentum, faction and field-objective bonuses.

#include "aurelion_rules/port/battle_rules.hpp"

#include "aurelion_rules/port/spell_rules.hpp"

#include <initializer_list>
#include <string>

namespace aurelion::rules::port::battle_rules {

using compat::engine_clamp;
using compat::engine_max;
using compat::engine_min;
using gd::array_value;
using gd::int_value;
using gd::str;
using state::Kind;
namespace key = state::key;

namespace {

constexpr int64_t COHESION_MIN = 0;
constexpr int64_t COHESION_MAX = 10;
constexpr int64_t MOMENTUM_MAX = 4;

// An Array literal of String constants (["elevated_fire", "open_lane"]): a new
// untyped Array on every evaluation.
ArrayRef string_array(State &state, std::initializer_list<Atom> texts) {
	const ArrayRef array = state.new_array();
	for (const Atom text : texts) {
		state.append(array, str(text));
	}
	return array;
}

// bool(stack.get("ranged", false))
bool is_ranged(const State &state, DictRef stack) {
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

// _has_ability(stack, "harry") or _has_ability(stack, "backstab") or _has_ability(stack, "bloodrush")
bool has_skirmish_ability(State &state, DictRef stack) {
	return _has_ability(state, stack, key::harry) || _has_ability(state, stack, key::backstab) || _has_ability(state, stack, key::bloodrush);
}

// _reach_available(stack, battle) or _brace_available(stack, battle) or _has_ability(stack, "formation_guard")
bool holds_line(State &state, DictRef stack, DictRef battle) {
	return _reach_available(state, stack, battle) || _brace_available(state, stack, battle) || _has_ability(state, stack, key::formation_guard);
}

// String(battle.get("terrain", "")) == terrain
bool battle_terrain_is(const State &state, DictRef battle, Atom terrain) {
	return gd::string_field(state, battle, key::terrain, key::empty) == terrain;
}

// int(battle.get("round", 1)) >= int(objective.get("urgency_round", fallback)), the left operand first.
bool urgency_round_reached(const State &state, DictRef battle, DictRef objective, int64_t fallback) {
	const int64_t round_number = battle_round(state, battle);
	return round_number >= gd::int_field(state, objective, key::urgency_round, fallback);
}

// String.find(needle) != -1 (OperatorEvaluatorInStringFind): String::find
// answers -1 for an empty needle or haystack. A byte search of UTF-8 finds a
// code point sequence exactly where the engine's search of UTF-32 does.
bool string_contains(const std::string &haystack, const std::string &needle) {
	if (needle.empty() || haystack.empty()) {
		return false;
	}
	return haystack.find(needle) != std::string::npos;
}

// value in container (Variant OP_IN) for a String value: Array.has, a
// Dictionary key, or a substring of a String or StringName. An Object
// container (a property check) is not ported; anything else is the engine's
// invalid-operands error (gd::in).
bool string_in(State &state, Atom value, const Value &container) {
	if (container.is_string_like()) {
		return string_contains(state.text(container.ref), state.text(value));
	}
	if (container.kind == Kind::Opaque) {
		throw state::ScriptError("String in an opaque Variant (an Object, a packed array) is not ported");
	}
	return gd::in(state, str(value), container);
}

} // namespace

int64_t _stack_attack_total(State &state, DictRef stack, DictRef battle) {
	int64_t total = gd::int_field(state, stack, key::attack, 0);
	total = gd::add(total, spell_rules::effect_bonus_for_kind(state, stack, battle, key::attack));
	total = gd::add(total, _contextual_attack_bonus(state, stack, battle));
	total = gd::add(total, _cohesion_attack_bonus(_stack_cohesion_total(state, stack, battle)));
	total = gd::add(total, _momentum_attack_bonus(_stack_momentum_total(state, stack, battle)));
	return total;
}

int64_t _stack_defense_total(State &state, DictRef stack, DictRef battle) {
	int64_t foundry_bonus = 0;
	if (gd::string_field(state, stack, key::faction_id, key::empty) == key::faction_brasshollow) {
		const Atom side = gd::string_field(state, stack, key::side, key::empty);
		const bool requires_overheat = _side_ability_bool(state, battle, side, key::foundry_aura, key::hardening_requires_overheated, true);
		if (!requires_overheat || spell_rules::has_effect_id(state, stack, battle, key::status_overheated)) {
			foundry_bonus = _side_max_ability_int(state, battle, side, key::foundry_aura, key::ally_defense_bonus);
		}
	}
	int64_t total = gd::int_field(state, stack, key::defense, 0);
	total = gd::add(total, spell_rules::effect_bonus_for_kind(state, stack, battle, key::defense));
	total = gd::add(total, _contextual_defense_bonus(state, stack, battle));
	total = gd::add(total, _cohesion_defense_bonus(_stack_cohesion_total(state, stack, battle)));
	total = gd::add(total, foundry_bonus);
	return total;
}

int64_t _stack_initiative_total(State &state, DictRef stack, DictRef battle) {
	const DictRef hero_bonus = _hero_payload_for_side(state, battle, gd::string_field(state, stack, key::side, key::empty));
	int64_t total = gd::int_field(state, stack, key::initiative, 0);
	total = gd::add(total, spell_rules::effect_bonus_for_kind(state, stack, battle, key::initiative));
	total = gd::add(total, _contextual_initiative_bonus(state, stack, battle));
	total = gd::add(total, _cohesion_initiative_bonus(_stack_cohesion_total(state, stack, battle)));
	total = gd::add(total, _momentum_initiative_bonus(_stack_momentum_total(state, stack, battle)));
	total = gd::add(total, _field_objective_initiative_bonus(state, stack, battle));
	int64_t result = gd::add(total, gd::int_field(state, hero_bonus, key::initiative, 0));
	result = gd::add(result, _faction_initiative_bonus(state, stack, battle));
	return result;
}

int64_t _stack_cohesion_total(State &state, DictRef stack, DictRef battle) {
	const Value fallback = state.get(stack, str(key::cohesion_base), int_value(5));
	int64_t total = gd::to_int(state, state.get(stack, str(key::cohesion), fallback));
	total = gd::add(total, spell_rules::effect_bonus_for_kind(state, stack, battle, key::cohesion));
	total = gd::add(total, _contextual_cohesion_bonus(state, stack, battle));
	return engine_clamp<int64_t>(total, COHESION_MIN, COHESION_MAX);
}

int64_t _stack_momentum_total(State &state, DictRef stack, DictRef battle) {
	int64_t total = gd::int_field(state, stack, key::momentum, 0);
	total = gd::add(total, spell_rules::effect_bonus_for_kind(state, stack, battle, key::momentum));
	total = gd::add(total, _contextual_momentum_bonus(state, stack, battle));
	return engine_clamp<int64_t>(total, 0, MOMENTUM_MAX);
}

int64_t _cohesion_attack_bonus(int64_t cohesion) {
	if (cohesion >= 9) {
		return 2;
	}
	if (cohesion >= 7) {
		return 1;
	}
	if (cohesion <= 2) {
		return -2;
	}
	if (cohesion <= 4) {
		return -1;
	}
	return 0;
}

int64_t _cohesion_defense_bonus(int64_t cohesion) {
	if (cohesion >= 8) {
		return 1;
	}
	if (cohesion <= 3) {
		return -2;
	}
	if (cohesion <= 5) {
		return -1;
	}
	return 0;
}

int64_t _cohesion_initiative_bonus(int64_t cohesion) {
	if (cohesion >= 8) {
		return 1;
	}
	if (cohesion <= 3) {
		return -2;
	}
	if (cohesion <= 5) {
		return -1;
	}
	return 0;
}

int64_t _momentum_attack_bonus(int64_t momentum) {
	if (momentum >= 3) {
		return 2;
	}
	if (momentum >= 1) {
		return 1;
	}
	return 0;
}

int64_t _momentum_initiative_bonus(int64_t momentum) {
	if (momentum >= 3) {
		return 2;
	}
	if (momentum >= 1) {
		return 1;
	}
	return 0;
}

int64_t _contextual_attack_bonus(State &state, DictRef stack, DictRef battle) {
	int64_t bonus = 0;
	const Atom side = gd::string_field(state, stack, key::side, key::empty);
	const int64_t round_number = battle_round(state, battle);
	if (_battle_has_tag(state, battle, key::elevated_fire) && is_ranged(state, stack)) {
		bonus += 1;
	}
	if (_battle_has_tag(state, battle, key::bog_channels) && has_skirmish_ability(state, stack)) {
		bonus += 1;
	}
	if (_battle_has_tag(state, battle, key::fortress_lane)) {
		if (_stack_is_anchor_side(state, stack, battle) && !is_ranged(state, stack) && holds_line(state, stack, battle)) {
			bonus += 1;
		} else if (_stack_is_assault_side(state, stack, battle) && is_ranged(state, stack) && battle_distance(state, battle) > 0) {
			bonus -= 1;
		}
	}
	if (_reserve_wave_is_active_for_side(state, battle, side) && _stack_is_anchor_side(state, stack, battle) && !_stack_is_isolated(state, battle, stack)) {
		bonus += 1;
	}
	if (_battle_has_tag(state, battle, key::battery_nest) && _stack_is_anchor_side(state, stack, battle) && is_ranged(state, stack)) {
		bonus += 1;
		if (_stack_has_positive_effect(state, stack, battle)) {
			bonus += 1;
		}
	}
	if (_battle_has_tag(state, battle, key::wall_pressure) && _stack_is_assault_side(state, stack, battle) && !is_ranged(state, stack) && round_number >= 3) {
		bonus += 1;
	}
	if (_hero_has_trait(state, battle, side, key::artillerist) && is_ranged(state, stack) && _battle_has_any_tags(state, battle, string_array(state, { key::elevated_fire, key::open_lane }))) {
		bonus += 1;
	}
	if (_hero_has_trait(state, battle, side, key::packhunter) && _enemy_wounded_count(state, battle, side) > 0) {
		bonus += 1;
	}
	if (_hero_has_trait(state, battle, side, key::vanguard) && !is_ranged(state, stack) && battle_round(state, battle) <= 2) {
		bonus += 1;
	}
	if (_hero_has_trait(state, battle, side, key::ambusher) && !is_ranged(state, stack) && _battle_has_any_tags(state, battle, string_array(state, { key::ambush_cover })) && battle_round(state, battle) <= 2) {
		bonus += 1;
	}
	if (_hero_has_trait(state, battle, side, key::bogwise) && (_battle_has_tag(state, battle, key::bog_channels) || battle_terrain_is(state, battle, key::mire)) && has_skirmish_ability(state, stack)) {
		bonus += 1;
	}
	if (gd::string_field(state, stack, key::faction_id, key::empty) == key::faction_sunvault && _stack_has_positive_effect(state, stack, battle)) {
		bonus += 1;
		if (is_ranged(state, stack) && _battle_has_any_tags(state, battle, string_array(state, { key::elevated_fire, key::open_lane }))) {
			bonus += 1;
		}
	}
	bonus = gd::add(bonus, _field_objective_attack_bonus(state, stack, battle));
	return bonus;
}

int64_t _contextual_defense_bonus(State &state, DictRef stack, DictRef battle) {
	int64_t bonus = 0;
	const Atom side = gd::string_field(state, stack, key::side, key::empty);
	// round_number is read (and converted) but not used, as in GDScript.
	const int64_t round_number = battle_round(state, battle);
	static_cast<void>(round_number);
	if (_battle_has_any_tags(state, battle, string_array(state, { key::chokepoint, key::fortified_line })) && !is_ranged(state, stack) && holds_line(state, stack, battle)) {
		bonus += 1;
	}
	if (_battle_has_tag(state, battle, key::fortress_lane) && _stack_is_anchor_side(state, stack, battle) && !is_ranged(state, stack) && holds_line(state, stack, battle)) {
		bonus += 1;
	}
	if (_reserve_wave_is_active_for_side(state, battle, side) && _stack_is_anchor_side(state, stack, battle) && !_stack_is_isolated(state, battle, stack)) {
		bonus += 1;
	}
	if (_battle_has_tag(state, battle, key::battery_nest) && _stack_is_anchor_side(state, stack, battle) && is_ranged(state, stack) && _stack_has_positive_effect(state, stack, battle)) {
		bonus += 1;
	}
	if (_hero_has_trait(state, battle, side, key::linekeeper) && (gd::bool_field(state, stack, key::defending, false) || _brace_available(state, stack, battle) || _has_ability(state, stack, key::formation_guard))) {
		bonus += 1;
	}
	if (_hero_has_trait(state, battle, side, key::bogwise) && battle_terrain_is(state, battle, key::mire) && !is_ranged(state, stack)) {
		bonus += 1;
	}
	bonus = gd::add(bonus, _field_objective_defense_bonus(state, stack, battle));
	return bonus;
}

int64_t _contextual_cohesion_bonus(State &state, DictRef stack, DictRef battle) {
	int64_t bonus = 0;
	const Atom side = gd::string_field(state, stack, key::side, key::empty);
	const int64_t round_number = battle_round(state, battle);
	if (_stack_is_isolated(state, battle, stack)) {
		bonus -= 1;
	}
	if (_battle_has_any_tags(state, battle, string_array(state, { key::chokepoint, key::fortified_line })) && !is_ranged(state, stack) && holds_line(state, stack, battle)) {
		bonus += 1;
	}
	if (_battle_has_tag(state, battle, key::fortress_lane) && _stack_is_anchor_side(state, stack, battle) && !is_ranged(state, stack) && holds_line(state, stack, battle)) {
		bonus += 1;
	}
	if (_battle_has_any_tags(state, battle, string_array(state, { key::elevated_fire, key::open_lane })) && is_ranged(state, stack)) {
		bonus += 1;
	}
	if (_reserve_wave_is_active_for_side(state, battle, side) && _stack_is_anchor_side(state, stack, battle) && !_stack_is_isolated(state, battle, stack)) {
		bonus += 1;
	}
	if (_battle_has_tag(state, battle, key::battery_nest) && _stack_is_anchor_side(state, stack, battle) && is_ranged(state, stack)) {
		bonus += 1;
		if (_stack_has_positive_effect(state, stack, battle)) {
			bonus += 1;
		}
	}
	if (_battle_has_tag(state, battle, key::wall_pressure) && _stack_is_assault_side(state, stack, battle) && !is_ranged(state, stack) && round_number >= 3) {
		bonus += 1;
	}
	if (spell_rules::has_any_effect_ids(state, stack, battle, array_value(string_array(state, { key::status_harried, key::status_staggered })))) {
		bonus -= 1;
	}
	const DictRef shielding = _ability_by_id(state, stack, key::shielding);
	if (!gd::is_empty(state, shielding)) {
		bonus = gd::add(bonus, engine_max<int64_t>(0, gd::int_field(state, shielding, key::cohesion_hold_bonus, 0)));
	}
	const Value traits = _hero_battle_traits(state, battle, side);
	if (_has_battle_trait(state, traits, key::linekeeper) && (gd::bool_field(state, stack, key::defending, false) || _brace_available(state, stack, battle) || _has_ability(state, stack, key::formation_guard))) {
		bonus = gd::add(bonus, 1);
	}
	if (_has_battle_trait(state, traits, key::artillerist) && is_ranged(state, stack) && _battle_has_any_tags(state, battle, string_array(state, { key::elevated_fire, key::open_lane }))) {
		bonus = gd::add(bonus, 1);
	}
	if (_has_battle_trait(state, traits, key::bogwise) && (_battle_has_tag(state, battle, key::bog_channels) || battle_terrain_is(state, battle, key::mire)) && !_stack_is_isolated(state, battle, stack)) {
		bonus = gd::add(bonus, 1);
	}
	if (_has_battle_trait(state, traits, key::ambusher) && !is_ranged(state, stack) && battle_round(state, battle) <= 2 && _battle_has_any_tags(state, battle, string_array(state, { key::ambush_cover }))) {
		bonus = gd::add(bonus, 1);
	}
	if (gd::string_field(state, stack, key::faction_id, key::empty) == key::faction_embercourt && _side_has_role_mix(state, battle, side) && !_stack_is_isolated(state, battle, stack)) {
		bonus = gd::add(bonus, 1);
	}
	if (gd::string_field(state, stack, key::faction_id, key::empty) == key::faction_mireclaw && _enemy_wounded_count(state, battle, side) > 0 && !is_ranged(state, stack)) {
		bonus = gd::add(bonus, 1);
	}
	if (gd::string_field(state, stack, key::faction_id, key::empty) == key::faction_sunvault && _stack_has_positive_effect(state, stack, battle) && !_stack_is_isolated(state, battle, stack)) {
		bonus = gd::add(bonus, 1);
		if (_battle_has_any_tags(state, battle, string_array(state, { key::fortified_line, key::elevated_fire }))) {
			bonus = gd::add(bonus, 1);
		}
	}
	bonus = gd::add(bonus, _field_objective_cohesion_bonus(state, stack, battle));
	return bonus;
}

int64_t _contextual_initiative_bonus(State &state, DictRef stack, DictRef battle) {
	int64_t bonus = 0;
	const Atom side = gd::string_field(state, stack, key::side, key::empty);
	const int64_t round_number = battle_round(state, battle);
	if (_battle_has_tag(state, battle, key::elevated_fire) && is_ranged(state, stack)) {
		bonus += 1;
	}
	if (_battle_has_tag(state, battle, key::open_lane) && is_ranged(state, stack) && battle_round(state, battle) <= 2) {
		bonus += 1;
	}
	if (_battle_has_any_tags(state, battle, string_array(state, { key::chokepoint, key::fortified_line })) && !is_ranged(state, stack) && holds_line(state, stack, battle)) {
		bonus += 1;
	}
	if (_battle_has_tag(state, battle, key::fortress_lane) && _stack_is_anchor_side(state, stack, battle) && !is_ranged(state, stack) && holds_line(state, stack, battle)) {
		bonus += 1;
	}
	if (_reserve_wave_is_active_for_side(state, battle, side) && _stack_is_anchor_side(state, stack, battle) && !_stack_is_isolated(state, battle, stack)) {
		bonus += 1;
	}
	if (_battle_has_tag(state, battle, key::battery_nest) && _stack_is_anchor_side(state, stack, battle) && is_ranged(state, stack)) {
		bonus += 1;
	}
	if (_battle_has_tag(state, battle, key::wall_pressure) && _stack_is_assault_side(state, stack, battle) && !is_ranged(state, stack) && round_number >= 3) {
		bonus += 1;
	}
	if (_battle_has_tag(state, battle, key::ambush_cover) && !is_ranged(state, stack) && battle_round(state, battle) <= 2) {
		bonus += 1;
	}
	if (_battle_has_tag(state, battle, key::bog_channels) && has_skirmish_ability(state, stack)) {
		bonus += 1;
	}
	const Value traits = _hero_battle_traits(state, battle, side);
	if (_has_battle_trait(state, traits, key::linekeeper) && (gd::bool_field(state, stack, key::defending, false) || _battle_has_any_tags(state, battle, string_array(state, { key::chokepoint, key::fortified_line })))) {
		bonus += 1;
	}
	if (_has_battle_trait(state, traits, key::artillerist) && is_ranged(state, stack) && _battle_has_any_tags(state, battle, string_array(state, { key::elevated_fire, key::open_lane }))) {
		bonus += 1;
	}
	if (_has_battle_trait(state, traits, key::ambusher) && !is_ranged(state, stack) && (battle_terrain_is(state, battle, key::forest) || _battle_has_tag(state, battle, key::ambush_cover)) && battle_round(state, battle) <= 2) {
		bonus += 1;
	}
	if (_has_battle_trait(state, traits, key::bogwise) && (_battle_has_tag(state, battle, key::bog_channels) || battle_terrain_is(state, battle, key::mire)) && has_skirmish_ability(state, stack)) {
		bonus += 1;
	}
	if (_has_battle_trait(state, traits, key::packhunter) && _enemy_wounded_count(state, battle, side) > 0 && !is_ranged(state, stack)) {
		bonus += 1;
	}
	if (_has_battle_trait(state, traits, key::vanguard) && !is_ranged(state, stack) && battle_round(state, battle) <= 2) {
		bonus += 1;
	}
	return bonus;
}

int64_t _contextual_momentum_bonus(State &state, DictRef stack, DictRef battle) {
	int64_t bonus = 0;
	const Atom side = gd::string_field(state, stack, key::side, key::empty);
	const int64_t round_number = battle_round(state, battle);
	if (_battle_has_any_tags(state, battle, string_array(state, { key::ambush_cover })) && !is_ranged(state, stack) && battle_round(state, battle) <= 2) {
		bonus += 1;
	}
	if (_battle_has_any_tags(state, battle, string_array(state, { key::elevated_fire, key::open_lane })) && is_ranged(state, stack) && battle_round(state, battle) <= 2) {
		bonus += 1;
	}
	if (_battle_has_tag(state, battle, key::bog_channels) && has_skirmish_ability(state, stack)) {
		bonus += 1;
	}
	if (_reserve_wave_is_active_for_side(state, battle, side) && _stack_is_anchor_side(state, stack, battle) && !_stack_is_isolated(state, battle, stack)) {
		bonus += 1;
	}
	if (_battle_has_tag(state, battle, key::battery_nest) && _stack_is_anchor_side(state, stack, battle) && is_ranged(state, stack) && (_stack_has_positive_effect(state, stack, battle) || round_number <= 2)) {
		bonus += 1;
	}
	if (_battle_has_tag(state, battle, key::wall_pressure) && _stack_is_assault_side(state, stack, battle) && !is_ranged(state, stack) && round_number >= 3) {
		bonus += 1;
	}
	const Value traits = _hero_battle_traits(state, battle, side);
	if (_has_battle_trait(state, traits, key::packhunter) && _enemy_wounded_count(state, battle, side) > 0 && !is_ranged(state, stack)) {
		bonus += 1;
	}
	if (_has_battle_trait(state, traits, key::vanguard) && !is_ranged(state, stack) && (battle_round(state, battle) <= 2 || _battle_has_tag(state, battle, key::open_lane))) {
		bonus += 1;
	}
	if (_has_battle_trait(state, traits, key::ambusher) && !is_ranged(state, stack) && battle_round(state, battle) <= 2 && (battle_terrain_is(state, battle, key::forest) || _battle_has_tag(state, battle, key::ambush_cover))) {
		bonus += 1;
	}
	if (_has_battle_trait(state, traits, key::artillerist) && is_ranged(state, stack) && _battle_has_any_tags(state, battle, string_array(state, { key::elevated_fire, key::open_lane }))) {
		bonus += 1;
	}
	if (_has_battle_trait(state, traits, key::bogwise) && (_battle_has_tag(state, battle, key::bog_channels) || battle_terrain_is(state, battle, key::mire)) && has_skirmish_ability(state, stack)) {
		bonus += 1;
	}
	if (gd::string_field(state, stack, key::faction_id, key::empty) == key::faction_sunvault && _stack_has_positive_effect(state, stack, battle)) {
		bonus += 1;
		const DictRef resonance_relay = _side_resonance_relay(state, battle, side);
		bool relay_holds = false;
		if (!gd::is_empty(state, resonance_relay)) {
			const int64_t positive_effect_count = _side_positive_effect_count(state, battle, side);
			relay_holds = positive_effect_count >= gd::int_field(state, resonance_relay, key::minimum_calibrated_stacks, 2) && _battle_has_any_tags(state, battle, string_array(state, { key::elevated_fire, key::fortified_line }));
		}
		if (relay_holds) {
			bonus = gd::add(bonus, gd::int_field(state, resonance_relay, key::terrain_momentum_bonus, 0));
		}
	}
	bonus = gd::add(bonus, _field_objective_momentum_bonus(state, stack, battle));
	return bonus;
}

int64_t _faction_initiative_bonus(State &state, DictRef stack, DictRef battle) {
	const Atom faction_id = gd::string_field(state, stack, key::faction_id, key::empty);
	const Atom side = gd::string_field(state, stack, key::side, key::empty);
	if (faction_id == key::faction_embercourt) {
		int64_t bonus = 0;
		if (is_ranged(state, stack) && _side_defending_count(state, battle, side) > 0) {
			bonus += 1;
			if (_side_has_ability(state, battle, side, key::formation_guard)) {
				bonus = gd::add(bonus, _side_max_ability_int(state, battle, side, key::formation_guard, key::ally_ranged_initiative_bonus));
			}
		}
		if (battle_round(state, battle) >= 3 && _side_has_role_mix(state, battle, side)) {
			bonus = gd::add(bonus, 1);
		}
		const DictRef formation_guard = _ability_by_id(state, stack, key::formation_guard);
		if (!gd::is_empty(state, formation_guard) && gd::bool_field(state, stack, key::defending, false)) {
			bonus = gd::add(bonus, gd::int_field(state, formation_guard, key::defending_initiative_bonus, 0));
		}
		return bonus;
	}
	if (faction_id == key::faction_mireclaw) {
		int64_t bonus = 0;
		const int64_t wounded_count = _enemy_wounded_count(state, battle, side);
		if (wounded_count > 0) {
			bonus += 1;
		}
		const DictRef bloodrush = _ability_by_id(state, stack, key::bloodrush);
		if (!gd::is_empty(state, bloodrush) && wounded_count > 0) {
			const int64_t max_bonus = gd::int_field(state, bloodrush, key::max_initiative_bonus, 0);
			const int64_t per_wounded = engine_max<int64_t>(1, gd::int_field(state, bloodrush, key::wounded_initiative_bonus, 0));
			bonus = gd::add(bonus, engine_min<int64_t>(max_bonus, gd::mul(wounded_count, per_wounded)));
		}
		if (!is_ranged(state, stack) && battle_round(state, battle) >= 3) {
			bonus = gd::add(bonus, 1);
		}
		if (!gd::is_empty(state, bloodrush) && battle_round(state, battle) >= 3) {
			bonus = gd::add(bonus, gd::int_field(state, bloodrush, key::late_round_initiative_bonus, 0));
		}
		return bonus;
	}
	if (faction_id == key::faction_sunvault) {
		int64_t bonus = 0;
		const int64_t positive_effect_count = _side_positive_effect_count(state, battle, side);
		const DictRef resonance_relay = _side_resonance_relay(state, battle, side);
		const int64_t relay_minimum = gd::int_field(state, resonance_relay, key::minimum_calibrated_stacks, 2);
		const Atom unit_id = gd::string_field(state, stack, key::unit_id, key::empty);
		const Value linked_unit_ids = gd::field_or(state, resonance_relay, key::linked_unit_ids, array_value(state.new_array()));
		if (string_in(state, unit_id, linked_unit_ids)) {
			bonus = gd::add(bonus, gd::int_field(state, resonance_relay, key::linked_initiative_bonus, 0));
		}
		if (_stack_has_positive_effect(state, stack, battle)) {
			bonus = gd::add(bonus, 1);
			if (is_ranged(state, stack) && _battle_has_any_tags(state, battle, string_array(state, { key::elevated_fire, key::open_lane }))) {
				bonus = gd::add(bonus, 1);
			}
		}
		if (!gd::is_empty(state, resonance_relay) && positive_effect_count >= relay_minimum && !_stack_is_isolated(state, battle, stack)) {
			bonus = gd::add(bonus, gd::int_field(state, resonance_relay, key::line_initiative_bonus, 0));
		}
		if (!gd::is_empty(state, resonance_relay) && battle_round(state, battle) >= 3 && positive_effect_count >= relay_minimum) {
			bonus = gd::add(bonus, gd::int_field(state, resonance_relay, key::late_round_initiative_bonus, 0));
		}
		return bonus;
	}
	if (faction_id == key::faction_thornwake) {
		int64_t bonus = 0;
		if (gd::bool_field(state, stack, key::defending, false) && battle_round(state, battle) >= 3) {
			bonus += 1;
		}
		if (_battle_has_any_tags(state, battle, string_array(state, { key::chokepoint, key::ambush_cover })) && !spell_rules::has_any_effect_ids(state, stack, battle, array_value(string_array(state, { key::status_harried, key::status_staggered })))) {
			bonus += 1;
		}
		return bonus;
	}
	if (faction_id == key::faction_brasshollow) {
		int64_t bonus = 0;
		if (_side_has_ability(state, battle, side, key::formation_guard) && battle_round(state, battle) >= 3) {
			bonus += 1;
		}
		if (is_ranged(state, stack) && _battle_has_any_tags(state, battle, string_array(state, { key::fortress_lane, key::battery_nest }))) {
			bonus += 1;
		}
		return bonus;
	}
	if (faction_id == key::faction_veilmourn) {
		int64_t bonus = 0;
		if (_battle_has_any_tags(state, battle, string_array(state, { key::fog_bank, key::ambush_cover }))) {
			bonus += 1;
		}
		if (_stack_is_isolated(state, battle, stack)) {
			bonus += 1;
		}
		return bonus;
	}
	return 0;
}

DictRef _highest_momentum_stack_for_side(State &state, DictRef battle, Atom side) {
	DictRef best = state.new_dict();
	int64_t best_score = -99999;
	const ArrayRef alive = _alive_stacks_for_side(state, battle, side);
	for (const Value &stack_value : gd::items(state, array_value(alive))) {
		const DictRef stack = gd::as_dict(stack_value);
		int64_t score = gd::mul(_stack_momentum_total(state, stack, battle), 3);
		score = gd::add(score, _stack_attack_total(state, stack, battle));
		if (is_ranged(state, stack)) {
			score = gd::sub(score, 2);
		}
		if (gd::is_empty(state, best) || score > best_score) {
			best = stack;
			best_score = score;
		}
	}
	return best;
}

ArrayRef _field_objectives(State &state, DictRef battle) {
	Value objectives;
	if (state.lookup(battle, str(key::field_objectives), objectives) && gd::is_array(objectives)) {
		return objectives.ref;
	}
	// The default [] when the key is missing, or a new [] when it is not an Array.
	return state.new_array();
}

Atom _field_objective_label(State &state, DictRef objective) {
	const Value fallback = state.get(objective, str(key::id), str(key::Objective));
	return gd::to_string(state.get(objective, str(key::label), fallback));
}

bool _side_controls_field_objective_type(State &state, DictRef battle, Atom side, Atom objective_type) {
	const ArrayRef objectives = _field_objectives(state, battle);
	for (const Value &objective : gd::items(state, array_value(objectives))) {
		if (gd::is_dict(objective) && gd::string_field(state, objective.ref, key::type, key::empty) == objective_type && gd::string_field(state, objective.ref, key::control_side, key::empty) == side) {
			return true;
		}
	}
	return false;
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
	if (side == key::empty || !_battle_has_tag(state, battle, key::reserve_wave)) {
		return false;
	}
	const int64_t round_number = battle_round(state, battle);
	return round_number >= _reserve_wave_ready_round(state, battle, side);
}

int64_t _field_objective_initiative_bonus(State &state, DictRef stack, DictRef battle) {
	const Atom side = gd::string_field(state, stack, key::side, key::empty);
	int64_t bonus = 0;
	const ArrayRef objectives = _field_objectives(state, battle);
	for (const Value &objective : gd::items(state, array_value(objectives))) {
		if (!gd::is_dict(objective) || gd::string_field(state, objective.ref, key::control_side, key::empty) != side) {
			continue;
		}
		const Atom objective_type = gd::string_field(state, objective.ref, key::type, key::empty);
		if (objective_type == key::signal_beacon) {
			bonus += 1;
		} else if (objective_type == key::lane_battery) {
			if (is_ranged(state, stack) && battle_distance(state, battle) > 0) {
				bonus += 1;
			}
		} else if (objective_type == key::cover_line) {
			if (is_ranged(state, stack) && battle_distance(state, battle) > 0) {
				bonus += 1;
			}
		} else if (objective_type == key::obstruction_line) {
			if (!is_ranged(state, stack) && battle_distance(state, battle) > 0 && holds_line(state, stack, battle)) {
				bonus += 1;
			}
		} else if (objective_type == key::ritual_pylon) {
			if (urgency_round_reached(state, battle, objective.ref, 2)) {
				bonus += 1;
			}
		} else if (objective_type == key::supply_post) {
			if (_reserve_wave_is_active_for_side(state, battle, side)) {
				bonus += 1;
			}
		}
	}
	return engine_min<int64_t>(bonus, 2);
}

int64_t _field_objective_attack_bonus(State &state, DictRef stack, DictRef battle) {
	const Atom side = gd::string_field(state, stack, key::side, key::empty);
	int64_t bonus = 0;
	const ArrayRef objectives = _field_objectives(state, battle);
	for (const Value &objective : gd::items(state, array_value(objectives))) {
		if (!gd::is_dict(objective) || gd::string_field(state, objective.ref, key::control_side, key::empty) != side) {
			continue;
		}
		const Atom objective_type = gd::string_field(state, objective.ref, key::type, key::empty);
		if (objective_type == key::lane_battery) {
			if (is_ranged(state, stack) && battle_distance(state, battle) > 0) {
				bonus += 1;
			}
		} else if (objective_type == key::cover_line) {
			if (is_ranged(state, stack) && battle_distance(state, battle) > 0 && !_stack_is_isolated(state, battle, stack)) {
				bonus += 1;
			}
		} else if (objective_type == key::obstruction_line) {
			if (!is_ranged(state, stack) && (battle_distance(state, battle) <= 1 || urgency_round_reached(state, battle, objective.ref, 2))) {
				bonus += 1;
			}
		} else if (objective_type == key::breach_point) {
			if (!is_ranged(state, stack) && urgency_round_reached(state, battle, objective.ref, 3)) {
				bonus += 1;
			}
		}
	}
	return engine_min<int64_t>(bonus, 2);
}

int64_t _field_objective_defense_bonus(State &state, DictRef stack, DictRef battle) {
	const Atom side = gd::string_field(state, stack, key::side, key::empty);
	int64_t bonus = 0;
	const ArrayRef objectives = _field_objectives(state, battle);
	for (const Value &objective : gd::items(state, array_value(objectives))) {
		if (!gd::is_dict(objective) || gd::string_field(state, objective.ref, key::control_side, key::empty) != side) {
			continue;
		}
		const Atom objective_type = gd::string_field(state, objective.ref, key::type, key::empty);
		if (objective_type == key::cover_line) {
			if (is_ranged(state, stack) || gd::bool_field(state, stack, key::defending, false)) {
				bonus += 1;
			}
		} else if (objective_type == key::obstruction_line) {
			if (!is_ranged(state, stack)) {
				bonus += 1;
			}
		} else if (objective_type == key::supply_post) {
			if (!_stack_is_isolated(state, battle, stack)) {
				bonus += 1;
			}
		} else if (objective_type == key::signal_beacon) {
			bonus += 1;
		} else if (objective_type == key::breach_point) {
			if (_stack_is_anchor_side(state, stack, battle)) {
				bonus += 1;
			}
		}
	}
	return engine_min<int64_t>(bonus, 2);
}

int64_t _field_objective_cohesion_bonus(State &state, DictRef stack, DictRef battle) {
	const Atom side = gd::string_field(state, stack, key::side, key::empty);
	int64_t bonus = 0;
	const ArrayRef objectives = _field_objectives(state, battle);
	for (const Value &objective : gd::items(state, array_value(objectives))) {
		if (!gd::is_dict(objective)) {
			continue;
		}
		const Atom controller = gd::string_field(state, objective.ref, key::control_side, key::neutral);
		const Atom objective_type = gd::string_field(state, objective.ref, key::type, key::empty);
		if (objective_type == key::cover_line) {
			if (controller == side && (is_ranged(state, stack) || !_stack_is_isolated(state, battle, stack))) {
				bonus += 1;
			} else if (controller == _opposing_side(side) && is_ranged(state, stack) && battle_distance(state, battle) > 0) {
				bonus -= 1;
			}
		} else if (objective_type == key::obstruction_line) {
			if (controller == side && !is_ranged(state, stack)) {
				bonus += 1;
			} else if (controller == _opposing_side(side) && !is_ranged(state, stack) && battle_distance(state, battle) > 0) {
				bonus -= 1;
			}
		} else if (objective_type == key::supply_post) {
			if (controller == side && !_stack_is_isolated(state, battle, stack)) {
				bonus += 1;
			}
		} else if (objective_type == key::breach_point) {
			if (controller == side && _stack_is_anchor_side(state, stack, battle)) {
				bonus += 1;
			}
		} else if (objective_type == key::hazard_zone || objective_type == key::ritual_pylon) {
			if (controller == _opposing_side(side) && urgency_round_reached(state, battle, objective.ref, 2)) {
				bonus -= 1;
			}
		}
	}
	return engine_clamp<int64_t>(bonus, -2, 2);
}

int64_t _field_objective_momentum_bonus(State &state, DictRef stack, DictRef battle) {
	const Atom side = gd::string_field(state, stack, key::side, key::empty);
	int64_t bonus = 0;
	const ArrayRef objectives = _field_objectives(state, battle);
	for (const Value &objective : gd::items(state, array_value(objectives))) {
		if (!gd::is_dict(objective) || gd::string_field(state, objective.ref, key::control_side, key::empty) != side) {
			continue;
		}
		const Atom objective_type = gd::string_field(state, objective.ref, key::type, key::empty);
		if (objective_type == key::cover_line) {
			if (is_ranged(state, stack) && battle_round(state, battle) <= 2 && battle_distance(state, battle) > 0) {
				bonus += 1;
			}
		} else if (objective_type == key::obstruction_line) {
			if (!is_ranged(state, stack) && battle_distance(state, battle) > 0 && urgency_round_reached(state, battle, objective.ref, 2)) {
				bonus += 1;
			}
		} else if (objective_type == key::breach_point) {
			if (!is_ranged(state, stack) && urgency_round_reached(state, battle, objective.ref, 3)) {
				bonus += 1;
			}
		} else if (objective_type == key::lane_battery) {
			if (is_ranged(state, stack) && battle_round(state, battle) <= 2 && battle_distance(state, battle) > 0) {
				bonus += 1;
			}
		}
	}
	return engine_min<int64_t>(bonus, 2);
}

} // namespace aurelion::rules::port::battle_rules
