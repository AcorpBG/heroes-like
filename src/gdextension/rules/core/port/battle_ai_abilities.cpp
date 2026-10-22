// Layer 5: BattleAiRules' own copies of the ability checks (brace,
// bramble ground, fog screen, hookline, reach, retaliation, readiness writ,
// pressure artillery, harry, counter-ambush flare) and the helpers they use.
// A copy whose body and callees are BattleRules' word for word calls the
// BattleRules port; the ones that walk a side's living stacks go through the
// AI's _alive_stacks_for_side and its scoring memo.

#include "aurelion_rules/port/battle_ai_rules.hpp"
#include "aurelion_rules/port/battle_rules.hpp"
#include "aurelion_rules/port/spell_rules.hpp"

#include "aurelion_rules/compat/godot_math.hpp"

#include <string>

namespace aurelion::rules::port::battle_ai_rules {

using compat::engine_max;
using compat::engine_min;
using gd::array_value;
using gd::dict_value;
using gd::str;
using state::Kind;
namespace key = state::key;
namespace rules = battle_rules;

namespace {

// a < b of two Strings (String::operator<, code point by code point): the
// UTF-8 bytes compared unsigned order the same way.
bool string_less(const State &state, Atom a, Atom b) {
	return state.text(a) < state.text(b);
}

// container.has(item) on an untyped value: Array.has (StringLikeVariantComparator),
// Dictionary.has or PackedStringArray.has. Nil and the other modelled types have
// no has() for a String: GDScript stops there too.
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

} // namespace

DictRef _ability_by_id(State &state, DictRef stack, Atom ability_id) {
	return rules::_ability_by_id(state, stack, ability_id);
}

DictRef _authored_ability_by_id(State &state, DictRef stack, Atom ability_id) {
	return rules::_authored_ability_by_id(state, stack, ability_id);
}

bool _has_ability(State &state, DictRef stack, Atom ability_id) {
	return rules::_has_ability(state, stack, ability_id);
}

bool _battle_has_tag(State &state, DictRef battle, Atom tag) {
	return rules::_battle_has_tag(state, battle, tag);
}

ArrayRef _field_objectives(State &state, DictRef battle) {
	return rules::_field_objectives(state, battle);
}

bool _side_controls_field_objective_type(State &state, DictRef battle, Atom side, Atom objective_type) {
	return rules::_side_controls_field_objective_type(state, battle, side, objective_type);
}

bool _brace_available(State &state, DictRef stack, DictRef battle) {
	return rules::_brace_available(state, stack, battle);
}

DictRef _bramble_ground_ability(State &state, DictRef stack) {
	return rules::_bramble_ground_ability(state, stack);
}

bool _bramble_ground_available(State &state, DictRef stack, DictRef battle, DictRef ability) {
	return rules::_bramble_ground_available(state, stack, battle, ability);
}

DictRef _fog_screen_ability(State &state, DictRef stack) {
	return rules::_fog_screen_ability(state, stack);
}

bool _fog_screen_available(State &state, DictRef stack, DictRef battle, DictRef ability) {
	return rules::_fog_screen_available(state, stack, battle, ability);
}

bool _hookline_available(State &state, DictRef stack, DictRef battle) {
	return rules::_hookline_available(state, stack, battle);
}

bool _reach_available(State &state, DictRef stack, DictRef battle) {
	return rules::_reach_available(state, stack, battle);
}

bool _can_make_retaliation(State &state, DictRef stack, int64_t attack_distance, DictRef battle) {
	if (spell_rules::has_effect_id(state, stack, battle, key::status_staggered)) {
		return false;
	}
	if (attack_distance <= 0) {
		return true;
	}
	return attack_distance == 1 && _reach_available(state, stack, battle);
}

DictRef _readiness_writ_ability(State &state, DictRef stack) {
	return rules::_readiness_writ_ability(state, stack);
}

int64_t _readiness_writ_effect_count(State &state, DictRef stack, DictRef battle, DictRef ability) {
	int64_t count = 0;
	for (const Value &status_id : gd::field_items(state, ability, str(key::cleansed_status_ids))) {
		if (spell_rules::has_effect_id(state, stack, battle, gd::to_string(status_id))) {
			count = gd::add(count, 1);
		}
	}
	return count;
}

DictRef _pressure_artillery_secondary_target(State &state, DictRef battle, DictRef attacker, DictRef primary_target) {
	const DictRef ability = _ability_by_id(state, attacker, key::pressure_artillery);
	if (gd::is_empty(state, ability) || gd::is_empty(state, primary_target)) {
		return state.new_dict();
	}
	const int64_t cluster_range = engine_max<int64_t>(1, gd::int_field(state, ability, key::cluster_range, 1));
	const Atom primary_id = gd::string_field(state, primary_target, key::battle_id, key::empty);
	const Atom target_side = gd::string_field(state, primary_target, key::side, key::empty);
	DictRef best = state.new_dict();
	const ArrayRef candidates = _alive_stacks_for_side(state, battle, target_side);
	for (const Value &candidate_value : gd::items(state, array_value(candidates))) {
		const DictRef candidate = gd::as_dict(candidate_value);
		if (gd::string_field(state, candidate, key::battle_id, key::empty) == primary_id) {
			continue;
		}
		if (_stack_hex_distance(state, primary_target, candidate) > cluster_range) {
			continue;
		}
		if (gd::is_empty(state, best)) {
			best = candidate;
			continue;
		}
		const int64_t candidate_health = gd::int_field(state, candidate, key::total_health, 0);
		const int64_t best_health = gd::int_field(state, best, key::total_health, 0);
		if (candidate_health < best_health) {
			best = candidate;
			continue;
		}
		if (candidate_health == best_health) {
			const Atom candidate_id = gd::string_field(state, candidate, key::battle_id, key::empty);
			const Atom best_id = gd::string_field(state, best, key::battle_id, key::empty);
			if (string_less(state, candidate_id, best_id)) {
				best = candidate;
			}
		}
	}
	return best;
}

int64_t _pressure_artillery_secondary_damage(State &state, DictRef attacker) {
	const DictRef ability = _ability_by_id(state, attacker, key::pressure_artillery);
	if (gd::is_empty(state, ability) || _alive_count(state, attacker) <= 0) {
		return 0;
	}
	// mini()'s arguments in order, and the product's operands left to right.
	const int64_t max_damage = engine_max<int64_t>(1, gd::int_field(state, ability, key::max_secondary_damage, 1));
	const int64_t alive = _alive_count(state, attacker);
	const int64_t per_unit = engine_max<int64_t>(1, gd::int_field(state, ability, key::secondary_damage_per_unit, 1));
	return engine_min<int64_t>(max_damage, gd::mul(alive, per_unit));
}

bool _harry_support_ready(State &state, DictRef attacker, DictRef target, DictRef battle, DictRef ability) {
	const int64_t required_support = gd::int_field(state, ability, key::min_adjacent_allies_to_target, 0);
	if (required_support <= 0) {
		return true;
	}
	if (gd::is_empty(state, attacker) || gd::is_empty(state, target)) {
		return false;
	}
	const DictRef target_hex = _stack_hex(state, target);
	if (gd::is_empty(state, target_hex)) {
		return false;
	}
	const Atom attacker_id = gd::string_field(state, attacker, key::battle_id, key::empty);
	int64_t supporting_allies = 0;
	const ArrayRef allies = _alive_stacks_for_side(state, battle, gd::string_field(state, attacker, key::side, key::empty));
	for (const Value &ally_value : gd::items(state, array_value(allies))) {
		const DictRef ally = gd::as_dict(ally_value);
		if (gd::string_field(state, ally, key::battle_id, key::empty) == attacker_id) {
			continue;
		}
		const DictRef ally_hex = _stack_hex(state, ally);
		if (gd::is_empty(state, ally_hex) || _stack_hex_distance(state, target, ally) > 1) {
			continue;
		}
		supporting_allies = gd::add(supporting_allies, 1);
		if (supporting_allies >= required_support) {
			return true;
		}
	}
	return false;
}

DictRef _counter_ambush_flare_context(State &state, DictRef battle, DictRef protected_stack, Atom ambush_ability_id) {
	if (gd::is_empty(state, protected_stack) || ambush_ability_id == key::empty) {
		return state.new_dict();
	}
	const ArrayRef sources = _alive_stacks_for_side(state, battle, gd::string_field(state, protected_stack, key::side, key::empty));
	for (const Value &source : gd::items(state, array_value(sources))) {
		const DictRef ability = _ability_by_id(state, gd::as_dict(source), key::counter_ambush_flare);
		if (gd::is_empty(state, ability)) {
			continue;
		}
		Value countered;
		if (!state.lookup(ability, str(key::countered_ability_ids), countered)) {
			continue; // the default [] has nothing
		}
		if (variant_has(state, countered, str(ambush_ability_id))) {
			const DictRef context = state.new_dict();
			state.set(context, str(key::source), source);
			state.set(context, str(key::ability), dict_value(ability));
			return context;
		}
	}
	return state.new_dict();
}

} // namespace aurelion::rules::port::battle_ai_rules
