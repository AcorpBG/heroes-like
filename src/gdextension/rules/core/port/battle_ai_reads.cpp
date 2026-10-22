// Slice 08: BattleAiRules' reads that need no weights: melee and ranged reach,
// the attack distance, side health, the advance target and destination, the
// commander's payload and template, and the spell estimates. The decisions
// that weigh them (_w) are slice 09's.

#include "aurelion_rules/port/battle_ai_rules.hpp"
#include "aurelion_rules/port/battle_footprint.hpp"
#include "aurelion_rules/port/battle_rules.hpp"
#include "aurelion_rules/port/spell_rules.hpp"

#include "aurelion_rules/compat/godot_math.hpp"

#include <initializer_list>
#include <string>

namespace aurelion::rules::port::battle_ai_rules {

using compat::engine_clamp;
using compat::engine_max;
using compat::engine_min;
using gd::array_value;
using gd::dict_value;
using gd::str;
using state::Kind;
namespace key = state::key;
namespace rules = battle_rules;

namespace {

constexpr int64_t kBattleHexColumns = 11;
constexpr int64_t kClockPressureRounds = 3;
constexpr double kDecisiveAttackTargetSideHealthRatioMax = 0.4;
constexpr double kDecisiveAttackActingSideHealthRatioMin = 0.5;
constexpr double kDecisiveAttackMaxDefendScoreGap = 2.0;

bool empty(const State &state, DictRef dict) {
	return gd::is_empty(state, dict);
}

Atom side_of(const State &state, DictRef stack) {
	return gd::string_field(state, stack, key::side, key::empty);
}

bool ranged(const State &state, DictRef stack) {
	return gd::bool_field(state, stack, key::ranged, false);
}

// d.get(key, []): the field, or a new empty Array.
Value field_or_array(State &state, DictRef dict, Atom field) {
	Value out;
	if (state.lookup(dict, str(field), out)) {
		return out;
	}
	return array_value(state.new_array());
}

// battle.get(key, {}) if battle.get(key, {}) is Dictionary else {}
DictRef dict_or_new(State &state, DictRef dict, Atom field) {
	Value out;
	if (state.lookup(dict, str(field), out) && gd::is_dict(out)) {
		return out.ref;
	}
	return state.new_dict();
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

// container.has(item) on an untyped value: Array.has, Dictionary.has or
// PackedStringArray.has. Nil and the other modelled types have no has() for
// a String: GDScript stops there too.
bool variant_has(const State &state, const Value &container, const Value &item) {
	if (container.kind == Kind::Array) {
		return gd::array_has(state, container.ref, item);
	}
	if (container.kind == Kind::Dict) {
		return state.has(container.ref, item);
	}
	if (container.kind == Kind::PackedString) {
		return gd::packed_find(state, container, item) >= 0;
	}
	if (container.kind == Kind::Opaque) {
		throw state::ScriptError("has() on an opaque value is not ported");
	}
	if (container.kind == Kind::Nil) {
		throw state::ScriptError("Cannot call method 'has' on a null value.");
	}
	throw state::ScriptError(std::string("Invalid call. Nonexistent function 'has' in base '") + gd::type_name(container) + "'.");
}

bool one_of(Atom value, std::initializer_list<Atom> atoms) {
	for (const Atom atom : atoms) {
		if (value == atom) {
			return true;
		}
	}
	return false;
}

// (float(int(stack.get("min_damage", 1))) + float(int(stack.get("max_damage", 1)))) / 2.0
double damage_mean(const State &state, DictRef stack) {
	return (static_cast<double>(gd::int_field(state, stack, key::min_damage, 1)) + static_cast<double>(gd::int_field(state, stack, key::max_damage, 1))) / 2.0;
}

bool scoring_scope_open(State &state) {
	return gd::to_int(state, gd::static_var(state, key::battle_ai_rules_script, key::_scoring_scope_depth)) > 0;
}

} // namespace

bool _can_make_melee_attack(State &state, DictRef stack, DictRef battle, DictRef target) {
	if (empty(state, stack) || _alive_count(state, stack) <= 0) {
		return false;
	}
	if (empty(state, target)) {
		const ArrayRef memo = _stack_term_memo(state, key::melee_any, stack, battle);
		if (state.array_size(memo) == 3) {
			return gd::to_bool(state.at(memo, 2));
		}
		bool can_attack = false;
		for (const Value &candidate : gd::items(state, array_value(_alive_stacks_for_side(state, battle, _opposing_side(side_of(state, stack)))))) {
			if (_can_make_melee_attack(state, stack, battle, gd::as_dict(candidate))) {
				can_attack = true;
				break;
			}
		}
		_keep_stack_term(state, memo, gd::bool_value(can_attack));
		return can_attack;
	}
	if (_alive_count(state, target) <= 0 || side_of(state, stack) == side_of(state, target)) {
		return false;
	}
	const int64_t hex_distance = _stack_hex_distance(state, stack, target);
	if (hex_distance <= 1) {
		return true;
	}
	return hex_distance == 2 && (_reach_available(state, stack, battle) || _hookline_available(state, stack, battle));
}

bool _can_make_ranged_attack(State &state, DictRef stack, DictRef battle, DictRef target) {
	(void)battle;
	return !empty(state, stack)
			&& !empty(state, target)
			&& _alive_count(state, stack) > 0
			&& _alive_count(state, target) > 0
			&& side_of(state, stack) != side_of(state, target)
			&& ranged(state, stack)
			&& gd::int_field(state, stack, key::shots_remaining, 0) > 0
			&& !empty(state, _stack_hex(state, stack))
			&& !empty(state, _stack_hex(state, target));
}

bool _can_make_any_ranged_attack(State &state, DictRef stack, DictRef battle, ArrayRef targets) {
	for (const Value &target : gd::items(state, array_value(targets))) {
		if (gd::is_dict(target) && _can_make_ranged_attack(state, stack, battle, target.ref)) {
			return true;
		}
	}
	return false;
}

int64_t _attack_distance_for_action(State &state, DictRef attacker, DictRef target, DictRef battle, bool is_ranged) {
	const int64_t hex_distance = _stack_hex_distance(state, attacker, target);
	if (hex_distance >= 999) {
		return gd::int_field(state, battle, key::distance, 1);
	}
	if (is_ranged) {
		return _distance_band_from_hex_distance(hex_distance);
	}
	if (hex_distance <= 1) {
		return 0;
	}
	if (hex_distance == 2 && (_reach_available(state, attacker, battle) || _hookline_available(state, attacker, battle))) {
		return 1;
	}
	return gd::int_field(state, battle, key::distance, 1);
}

bool _fights_in_melee(State &state, DictRef stack) {
	return !ranged(state, stack) || gd::int_field(state, stack, key::shots_remaining, 0) <= 0;
}

bool should_wait_for_contact(State &state, DictRef battle, DictRef active_stack, bool can_wait, int64_t opposing_stacks_still_to_act) {
	if (!can_wait || opposing_stacks_still_to_act <= 0) {
		return false;
	}
	if (empty(state, active_stack) || _alive_count(state, active_stack) <= 0) {
		return false;
	}
	if (!_fights_in_melee(state, active_stack)) {
		return false;
	}
	return !_can_make_melee_attack(state, active_stack, battle, state.new_dict());
}

bool _should_close_distance(State &state, DictRef active_stack) {
	if (!ranged(state, active_stack)) {
		return true;
	}
	return gd::int_field(state, active_stack, key::shots_remaining, 0) <= 0;
}

int64_t _clock_pressure(State &state, DictRef battle) {
	const int64_t rounds_left = gd::add(gd::sub(gd::int_field(state, battle, key::max_rounds, 12), gd::int_field(state, battle, key::round, 1)), 1);
	return engine_clamp<int64_t>(gd::sub(kClockPressureRounds + 1, rounds_left), 0, kClockPressureRounds);
}

double _side_ranged_power(State &state, DictRef battle, Atom side) {
	double power = 0.0;
	for (const Value &stack_value : gd::items(state, array_value(_alive_stacks_for_side(state, battle, side)))) {
		const DictRef stack = gd::as_dict(stack_value);
		if (ranged(state, stack) && gd::int_field(state, stack, key::shots_remaining, 0) > 0) {
			power += static_cast<double>(_alive_count(state, stack)) * _creature_average_damage(state, stack);
		}
	}
	return power;
}

DictRef advance_target(State &state, DictRef battle, DictRef stack) {
	const int64_t gap = rules::_advance_desired_gap(state, stack, battle);
	const Atom start_key = rules::_hex_key(state, _stack_hex(state, stack));
	DictRef best = state.new_dict();
	int64_t best_steps = 0;
	int64_t best_distance = 0;
	for (const Value &target_value : gd::items(state, array_value(_alive_stacks_for_side(state, battle, _opposing_side(side_of(state, stack)))))) {
		const DictRef target = gd::as_dict(target_value);
		const DictRef walk_steps = rules::_walk_steps_to_target(state, battle, stack, target, gap);
		const int64_t steps = gd::int_field(state, walk_steps, start_key, 9999);
		const int64_t distance = _stack_hex_distance(state, stack, target);
		if (empty(state, best) || steps < best_steps || (steps == best_steps && distance < best_distance)) {
			best = target;
			best_steps = steps;
			best_distance = distance;
		}
	}
	return best;
}

DictRef best_advance_destination(State &state, DictRef battle, DictRef stack, DictRef preferred_target, int64_t desired_gap) {
	const ArrayRef destinations = rules::legal_destinations_for_stack(state, battle, gd::string_field(state, stack, key::battle_id, key::empty));
	if (state.array_size(destinations) == 0) {
		return state.new_dict();
	}
	DictRef target = preferred_target;
	if (empty(state, target) || _alive_count(state, target) <= 0 || side_of(state, target) == side_of(state, stack)) {
		target = advance_target(state, battle, stack);
	}
	const DictRef walk_steps = !empty(state, target) ? rules::_walk_steps_to_target(state, battle, stack, target, desired_gap) : state.new_dict();
	DictRef best = state.new_dict();
	int64_t best_score = 0;
	for (const Value &destination_value : gd::items(state, array_value(destinations))) {
		if (!gd::is_dict(destination_value)) {
			continue;
		}
		const DictRef destination = destination_value.ref;
		int64_t score = 0;
		if (!empty(state, target)) {
			const int64_t closest_gap = rules::_projected_min_opposing_hex_distance(state, battle, stack, destination);
			if (closest_gap < desired_gap) {
				score = gd::add(score, gd::mul(gd::sub(desired_gap, closest_gap), 1000));
			}
			int64_t remaining = gd::int_field(state, walk_steps, rules::_hex_key(state, destination), -1);
			if (remaining < 0) {
				remaining = engine_max<int64_t>(0, gd::sub(battle_footprint::distance(state, stack, target, dict_value(destination)), desired_gap));
				if (!empty(state, walk_steps)) {
					// Walks reach the target, only none from this hex.
					remaining = gd::add(remaining, kBattleHexColumns);
				}
			}
			score = gd::add(score, gd::mul(remaining, 100));
		}
		score = gd::add(score, gd::int_field(state, destination, key::steps, 1));
		score = gd::add(score, rules::_advance_lateral_penalty(state, stack, destination));
		if (empty(state, best) || score < best_score) {
			best = destination;
			best_score = score;
		}
	}
	return best;
}

double _average_unit_damage(State &state, DictRef stack) {
	const int64_t min_damage = gd::int_field(state, stack, key::min_damage, 1);
	return static_cast<double>(gd::add(min_damage, engine_max<int64_t>(min_damage, gd::int_field(state, stack, key::max_damage, 1)))) * 0.5;
}

double _creature_average_damage(State &state, DictRef stack) {
	return engine_max<double>(0.5, damage_mean(state, stack));
}

double _creature_threat_weight(State &state, DictRef battle, DictRef target) {
	int64_t creatures = 0;
	double damage = 0.0;
	for (const Value &stack_value : gd::items(state, array_value(_alive_stacks_for_side(state, battle, side_of(state, target))))) {
		const DictRef stack = gd::as_dict(stack_value);
		const int64_t count = _alive_count(state, stack);
		creatures = gd::add(creatures, count);
		damage += static_cast<double>(count) * _creature_average_damage(state, stack);
	}
	if (creatures <= 0 || damage <= 0.0) {
		return 1.0;
	}
	return _creature_average_damage(state, target) / (damage / static_cast<double>(creatures));
}

int64_t _stack_missing_health(State &state, DictRef stack) {
	return spell_rules::battle_spell_recoverable_health(state, stack);
}

int64_t _battle_recovery_amount(State &state, DictRef hero_state, DictRef spell) {
	return spell_rules::_battle_spell_recovery_amount(state, hero_state, spell);
}

int64_t _side_current_health(State &state, DictRef battle, Atom side) {
	int64_t total = 0;
	for (const Value &stack : gd::items(state, array_value(_alive_stacks_for_side(state, battle, side)))) {
		total = gd::add(total, engine_max<int64_t>(0, gd::int_field(state, gd::as_dict(stack), key::total_health, 0)));
	}
	return total;
}

int64_t _side_base_health(State &state, DictRef battle, Atom side) {
	int64_t total = 0;
	for (const Value &stack : gd::field_items(state, battle, str(key::stacks))) {
		if (gd::is_dict(stack) && side_of(state, stack.ref) == side) {
			const int64_t base_count = engine_max<int64_t>(0, gd::int_field(state, stack.ref, key::base_count, 0));
			total = gd::add(total, gd::mul(base_count, engine_max<int64_t>(1, gd::int_field(state, stack.ref, key::unit_hp, 1))));
		}
	}
	return total;
}

double _side_health_ratio(State &state, DictRef battle, Atom side) {
	const int64_t base_health = engine_max<int64_t>(1, _side_base_health(state, battle, side));
	return engine_clamp(static_cast<double>(_side_current_health(state, battle, side)) / static_cast<double>(base_health), 0.0, 1.0);
}

bool _has_hostile_ranged_pressure(State &state, ArrayRef targets) {
	for (const Value &target : gd::items(state, array_value(targets))) {
		if (gd::is_dict(target) && ranged(state, target.ref) && _alive_count(state, target.ref) > 0) {
			return true;
		}
	}
	return false;
}

bool _must_force_engaged_attack(State &state, DictRef active_stack, DictRef battle, ArrayRef targets, DictRef best_attack) {
	if (empty(state, best_attack) || _stack_contact_band(state, active_stack, battle) > 0) {
		return false;
	}
	if (!_fights_in_melee(state, active_stack)) {
		return false;
	}
	if (_has_hostile_ranged_pressure(state, targets)) {
		return false;
	}
	return true;
}

bool _should_press_decisive_attack(State &state, DictRef battle, DictRef active_stack, DictRef best_attack, double defend_score) {
	// A strike candidate is one the stack can make this turn, walking first or not.
	if (gd::string_field(state, best_attack, key::action, key::empty) != key::strike) {
		return false;
	}
	const Atom acting_side = side_of(state, active_stack);
	if (acting_side == key::empty || _side_health_ratio(state, battle, acting_side) < kDecisiveAttackActingSideHealthRatioMin) {
		return false;
	}
	const DictRef target = _stack_by_battle_id(state, battle, gd::string_field(state, best_attack, key::target_battle_id, key::empty));
	const Atom target_side = side_of(state, target);
	if (target_side == key::empty || _side_health_ratio(state, battle, target_side) > kDecisiveAttackTargetSideHealthRatioMax) {
		return false;
	}
	return gd::float_field(state, best_attack, key::score, -9999.0) >= defend_score - kDecisiveAttackMaxDefendScoreGap;
}

bool _candidate_beats(State &state, DictRef candidate, DictRef current_best) {
	if (empty(state, current_best)) {
		return true;
	}
	if (gd::is_equal_approx(gd::float_field(state, candidate, key::score, 0.0), gd::float_field(state, current_best, key::score, 0.0))) {
		// String < String: code point by code point, as the UTF-8 bytes
		// compared unsigned.
		return state.text(gd::string_field(state, candidate, key::action, key::empty)) < state.text(gd::string_field(state, current_best, key::action, key::empty));
	}
	return gd::float_field(state, candidate, key::score, 0.0) > gd::float_field(state, current_best, key::score, 0.0);
}

DictRef _enemy_hero_state_for_ai(State &state, DictRef battle, DictRef enemy_hero) {
	const DictRef battle_enemy_payload = dict_or_new(state, battle, key::enemy_hero_payload);
	if (!empty(state, enemy_hero)) {
		return _merged_commander_ai_payload(state, enemy_hero, battle_enemy_payload);
	}
	const DictRef battle_enemy_hero = dict_or_new(state, battle, key::enemy_hero);
	if (!empty(state, battle_enemy_hero)) {
		return _merged_commander_ai_payload(state, battle_enemy_hero, battle_enemy_payload);
	}
	if (!empty(state, battle_enemy_payload)) {
		return gd::deep_duplicate_dict(state, battle_enemy_payload);
	}
	return state.new_dict();
}

DictRef _commander_template_for_ai_payload(State &state, DictRef commander_payload) {
	for (const Atom field : { key::roster_hero_id, key::hero_id, key::id }) {
		const Atom hero_id = gd::strip_edges(state, gd::string_field(state, commander_payload, field, key::empty));
		if (hero_id == key::empty) {
			continue;
		}
		const DictRef hero_template = gd::content_row(state, state::ContentTable::Hero, hero_id);
		if (!empty(state, hero_template)) {
			return hero_template;
		}
	}
	return state.new_dict();
}

DictRef _commander_template_for_spell_role(State &state, DictRef enemy_hero) {
	return _commander_template_for_ai_payload(state, enemy_hero);
}

DictRef _side_commander_state_for_ai(State &state, DictRef battle, Atom side, DictRef commander_payload) {
	const bool player = side == key::player;
	const DictRef existing_payload = dict_or_new(state, battle, player ? key::player_hero : key::enemy_hero_payload);
	const DictRef existing_state = dict_or_new(state, battle, player ? key::player_commander_state : key::enemy_hero);
	DictRef resolved = !empty(state, commander_payload) ? gd::deep_duplicate_dict(state, commander_payload) : state.new_dict();
	if (empty(state, resolved) && !empty(state, existing_payload)) {
		resolved = gd::deep_duplicate_dict(state, existing_payload);
	} else if (!empty(state, existing_payload)) {
		resolved = _merged_commander_ai_payload(state, resolved, existing_payload);
	}
	if (empty(state, resolved) && !empty(state, existing_state)) {
		resolved = gd::deep_duplicate_dict(state, existing_state);
	} else if (!empty(state, existing_state)) {
		resolved = _merged_commander_ai_payload(state, resolved, existing_state);
	}
	return resolved;
}

Atom _side_commander_payload_source(State &state, DictRef battle, Atom side, DictRef commander_payload) {
	const bool player = side == key::player;
	if (!empty(state, dict_or_new(state, battle, player ? key::player_hero : key::enemy_hero_payload))) {
		return key::battle;
	}
	if (!empty(state, dict_or_new(state, battle, player ? key::player_commander_state : key::enemy_hero))) {
		return key::battle;
	}
	if (!empty(state, commander_payload)) {
		return key::argument;
	}
	return key::none;
}

double _commander_spell_role_modifier(State &state, DictRef enemy_hero, DictRef behavior) {
	if (empty(state, enemy_hero) || empty(state, behavior)) {
		return 0.0;
	}
	const DictRef hero_template = _commander_template_for_spell_role(state, enemy_hero);
	Atom command_path = gd::strip_edges(state, gd::string_field(state, enemy_hero, key::command_path, key::empty));
	if (command_path == key::empty) {
		command_path = gd::strip_edges(state, gd::string_field(state, hero_template, key::command_path, key::empty));
	}
	Atom archetype = gd::strip_edges(state, gd::string_field(state, enemy_hero, key::archetype, key::empty));
	if (archetype == key::empty) {
		archetype = gd::strip_edges(state, gd::string_field(state, hero_template, key::archetype, key::empty));
	}
	const Atom effect_type = gd::string_field(state, behavior, key::effect_type, key::empty);
	const Atom primary_role = gd::string_field(state, behavior, key::primary_role, key::empty);
	const ArrayRef role_categories = _normalize_string_array(state, field_or_array(state, behavior, key::role_categories));
	const auto has_category = [&](Atom category) {
		return gd::array_has(state, role_categories, str(category));
	};
	double modifier = 0.0;
	if (command_path == key::magic) {
		modifier += 0.65;
	} else if (command_path == key::might && one_of(effect_type, { key::damage_enemy, key::attack_buff })) {
		modifier += 0.25;
	}
	if (one_of(archetype, { key::hexcaller, key::starseer, key::rootoracle, key::denaugur, key::drumoracle, key::fogprophet, key::funeralhexer })) {
		// Damage spells hit 2.5x harder per point of power since 2026-10-08;
		// the control lean grew with them so these casters still favour control.
		if (effect_type == key::control_enemy || has_category(key::control) || primary_role == key::control_enemy) {
			modifier += 3.2;
		} else if (effect_type == key::damage_enemy && has_category(key::debuff)) {
			modifier += 0.7;
		}
	}
	if (one_of(archetype, { key::warden, key::castellan, key::solarphysician, key::recoverywarden, key::granary, key::sporedoctor, key::graftprophet })) {
		if (one_of(effect_type, { key::recover_ally, key::cleanse_ally, key::defense_buff }) || has_category(key::recovery) || has_category(key::countermagic)) {
			modifier += 1.6;
		}
	}
	if (one_of(archetype, { key::raider, key::marshal, key::packlord, key::batterycaptain, key::siegelock, key::briarmarshal, key::contractmarshal, key::pitmarshal, key::huntleader })) {
		if (effect_type == key::damage_enemy || effect_type == key::attack_buff || has_category(key::damage)) {
			modifier += 1.25;
		}
	}
	if (one_of(archetype, { key::artillerist, key::sharpshooter, key::beaconscribe, key::pressuremath, key::slagalchemist, key::heatrice })) {
		if (effect_type == key::damage_enemy || effect_type == key::initiative_buff) {
			modifier += 1.0;
		}
	}
	return modifier;
}

bool _candidate_is_lethal_damage_spell(State &state, DictRef candidate, DictRef battle, DictRef enemy_hero) {
	if (empty(state, candidate) || gd::string_field(state, candidate, key::action, key::empty) != key::cast_spell) {
		return false;
	}
	const DictRef spell = gd::content_row(state, state::ContentTable::Spell, gd::string_field(state, candidate, key::spell_id, key::empty));
	const DictRef behavior = spell_rules::battle_spell_behavior(state, spell);
	if (gd::string_field(state, behavior, key::effect_type, key::empty) != key::damage_enemy) {
		return false;
	}
	const DictRef target = _stack_by_battle_id(state, battle, gd::string_field(state, candidate, key::target_battle_id, key::empty));
	if (empty(state, target) || _alive_count(state, target) <= 0) {
		return false;
	}
	const DictRef projection = spell_rules::battle_spell_damage_projection(state, enemy_hero, battle, target, spell);
	return gd::int_field(state, projection, key::final_damage, 0) >= gd::int_field(state, target, key::total_health, 0);
}

bool _damage_candidate_is_lethal(State &state, DictRef candidate, DictRef battle, DictRef enemy_hero, DictRef target, DictRef projection) {
	const DictRef by_id = _stack_by_battle_id(state, battle, gd::string_field(state, candidate, key::target_battle_id, key::empty));
	if (!gd::is_same(state, dict_value(by_id), dict_value(target))) {
		return _candidate_is_lethal_damage_spell(state, candidate, battle, enemy_hero);
	}
	if (_alive_count(state, target) <= 0) {
		return false;
	}
	return gd::int_field(state, projection, key::final_damage, 0) >= gd::int_field(state, target, key::total_health, 0);
}

bool _allied_spell_candidate_suppressed_by_active_buff(State &state, Atom effect_type, DictRef ally, DictRef battle, DictRef spell) {
	if (!_spell_buff_already_active(state, ally, battle, spell)) {
		return false;
	}
	if (effect_type == key::cleanse_ally) {
		const DictRef effect = dict_or_new(state, spell, key::effect);
		const ArrayRef cleanse_ids = _normalize_string_array(state, field_or_array(state, effect, key::cleanse_effect_ids));
		return !spell_rules::has_any_effect_ids(state, ally, battle, array_value(cleanse_ids));
	}
	if (effect_type == key::recover_ally) {
		return _stack_missing_health(state, ally) <= 0;
	}
	return true;
}

bool _spell_buff_already_active(State &state, DictRef active_stack, DictRef battle, DictRef spell) {
	const DictRef modifiers = spell_rules::battle_spell_modifiers(state, spell);
	if (empty(state, modifiers)) {
		return false;
	}
	const ArrayRef modifier_keys = gd::keys(state, modifiers);
	for (const Value &modifier_key : gd::items(state, array_value(modifier_keys))) {
		const Atom name = gd::to_string(modifier_key);
		if (spell_rules::effect_bonus_for_kind(state, active_stack, battle, name) < gd::to_int(state, gd::index(state, modifiers, str(name)))) {
			return false;
		}
	}
	return true;
}

bool _stack_has_control_effect(State &state, DictRef stack, DictRef battle) {
	const ArrayRef ids = state.new_array();
	for (const Atom id : { key::status_harried, key::status_staggered, key::status_rooted }) {
		state.append(ids, str(id));
	}
	return spell_rules::has_any_effect_ids(state, stack, battle, array_value(ids));
}

bool _stack_is_rooted(State &state, DictRef stack, DictRef battle) {
	return spell_rules::has_effect_id(state, stack, battle, key::status_rooted);
}

DictRef _status_effect_from_spell(State &state, DictRef spell) {
	const Value effect = get_or_empty_dict(state, dict_value(spell), key::effect);
	const Value status_effect = get_or_empty_dict(state, effect, key::status_effect);
	if (gd::is_dict(status_effect)) {
		return status_effect.ref;
	}
	return state.new_dict();
}

double _status_tactical_value(State &state, Atom status_id, DictRef target) {
	const bool melee = !ranged(state, target);
	if (status_id == key::status_rooted) {
		return melee ? 2.0 : 0.5;
	}
	if (status_id == key::status_staggered) {
		return melee && gd::int_field(state, target, key::retaliations_left, 0) > 0 ? 1.5 : 0.5;
	}
	return 0.0;
}

double _buff_spell_offense_payoff(State &state, DictRef stack) {
	const double average_damage = damage_mean(state, stack);
	const double output = static_cast<double>(_alive_count(state, stack)) * average_damage;
	double score = engine_min<double>(3.0, output / 80.0);
	if (ranged(state, stack) && gd::int_field(state, stack, key::shots_remaining, 0) > 0) {
		score += 0.45;
	}
	return score;
}

double _stack_spell_target_value(State &state, DictRef stack, DictRef battle) {
	const double tier_value = static_cast<double>(engine_max<int64_t>(1, gd::int_field(state, stack, key::tier, 1))) * 0.15;
	const double average_damage = damage_mean(state, stack);
	const double offense_value = engine_min<double>(1.5, (static_cast<double>(_alive_count(state, stack)) * average_damage) / 160.0);
	double role_value = 0.0;
	if (ranged(state, stack) && gd::int_field(state, stack, key::shots_remaining, 0) > 0) {
		role_value += 0.3;
	}
	if (_has_ability(state, stack, key::formation_guard) || _brace_available(state, stack, battle)) {
		role_value += 0.2;
	}
	return tier_value + offense_value + role_value;
}

double _allied_status_synergy_score(State &state, DictRef battle, Atom side, Atom status_id) {
	if (status_id == key::empty) {
		return 0.0;
	}
	if (!scoring_scope_open(state)) {
		return _allied_status_synergy_on(state, battle, side, status_id);
	}
	const Atom memo_key = state.intern("synergy|" + state.text(side) + "|" + state.text(status_id));
	const DictRef terms = gd::as_dict(gd::static_var(state, key::battle_ai_rules_script, key::_scoring_stack_terms));
	const ArrayRef entry = _scoring_memo_entry(state, terms, memo_key, battle, battle);
	if (state.array_size(entry) > 0) {
		return gd::to_float(state.at(entry, 2));
	}
	const double score = _allied_status_synergy_on(state, battle, side, status_id);
	const ArrayRef made = state.new_array();
	state.append(made, dict_value(battle));
	state.append(made, dict_value(battle));
	state.append(made, gd::float_value(score));
	_add_scoring_memo_entry(state, terms, memo_key, made);
	return score;
}

double _allied_status_synergy_on(State &state, DictRef battle, Atom side, Atom status_id) {
	double score = 0.0;
	const Value status = str(status_id);
	for (const Value &stack_value : gd::items(state, array_value(_alive_stacks_for_side(state, battle, side)))) {
		const DictRef stack = gd::as_dict(stack_value);
		if (_has_ability(state, stack, key::backstab) && variant_has(state, field_or_array(state, _ability_by_id(state, stack, key::backstab), key::status_ids), status)) {
			score += 1.2;
		}
		if (_has_ability(state, stack, key::bloodrush) && variant_has(state, field_or_array(state, _ability_by_id(state, stack, key::bloodrush), key::status_ids), status)) {
			score += 1.0;
		}
		if (ranged(state, stack) && _has_ability(state, stack, key::volley) && variant_has(state, field_or_array(state, _ability_by_id(state, stack, key::volley), key::status_ids), status)) {
			score += 0.9;
		}
		if (_has_ability(state, stack, key::formation_guard) && status_id == key::status_staggered) {
			score += 0.8;
		}
		if (_has_ability(state, stack, key::shielding) && status_id == key::status_harried) {
			score += 0.6;
		}
		if (gd::string_field(state, stack, key::faction_id, key::empty) == key::faction_thornwake && status_id == key::status_rooted) {
			score += 0.8;
		}
	}
	return engine_min<double>(score, 3.0);
}

} // namespace aurelion::rules::port::battle_ai_rules
