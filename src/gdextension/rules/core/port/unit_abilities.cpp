// Layer 5: unit abilities: pressure artillery, the readiness writ, sporeglass mending fire, harry support and the
// lowest-health pick.

#include "aurelion_rules/port/battle_rules.hpp"
#include "aurelion_rules/port/spell_rules.hpp"

#include "aurelion_rules/compat/godot_string.hpp"

#include <string>

namespace aurelion::rules::port::battle_rules {

using compat::engine_max;
using compat::engine_min;
using compat::Number;
using compat::variant_max;
using compat::variant_min;
using gd::array_value;
using gd::bool_value;
using gd::dict_value;
using gd::int_value;
using gd::str;
using state::Kind;
namespace key = state::key;

namespace {

// d.get(field, []): the stored value, or a new empty Array when the key is missing.
Value field_or_new_array(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return array_value(state.new_array());
}

// x.size() of an untyped value: an Array or a Dictionary has one; Nil, a
// number, a String or a bool has no size() method.
int64_t untyped_size(const State &state, const Value &value) {
	if (value.kind == Kind::Array) {
		return state.array_size(value.ref);
	}
	if (value.kind == Kind::Dict) {
		return state.dict_size(value.ref);
	}
	if (value.kind == Kind::Opaque) {
		throw state::ScriptError("size() of an opaque value is not ported");
	}
	throw state::ScriptError(std::string("Invalid call. Nonexistent function 'size' in base '") + gd::type_name(value) + "'.");
}

// x[index] of an untyped value with an int index: an Array's item (out of
// range is an error), a Dictionary's value of the int key (missing is an error).
Value untyped_at(const State &state, const Value &value, int64_t index) {
	if (value.kind == Kind::Array) {
		return state.at(value.ref, index);
	}
	if (value.kind == Kind::Dict) {
		return gd::index(state, value.ref, int_value(index));
	}
	throw state::ScriptError(std::string("Invalid access of index '") + compat::itos(index) + "' on a base object of type '" + gd::type_name(value) + "'.");
}

// x[index] = item of an untyped value with an int index.
void untyped_set_at(State &state, const Value &value, int64_t index, const Value &item) {
	if (value.kind == Kind::Array) {
		state.set_at(value.ref, index, item);
		return;
	}
	if (value.kind == Kind::Dict) {
		state.set(value.ref, int_value(index), item);
		return;
	}
	throw state::ScriptError(std::string("Invalid assignment of index '") + compat::itos(index) + "' on a base object of type '" + gd::type_name(value) + "'.");
}

// x.duplicate(true) of an untyped value: an Array or a Dictionary copied deep.
// Nil and the scalar types have no duplicate(); an object or a packed array
// (whose duplicate() takes no argument) is not ported.
Value duplicate_deep_untyped(State &state, const Value &value) {
	if (value.kind == Kind::Array || value.kind == Kind::Dict) {
		return gd::duplicate_value(state, value, true);
	}
	if (value.kind == Kind::Nil) {
		throw state::ScriptError("Cannot call method 'duplicate' on a null value.");
	}
	if (value.kind == Kind::Opaque || value.is_packed()) {
		throw state::ScriptError("duplicate(true) of an opaque value or a packed array is not ported");
	}
	throw state::ScriptError(std::string("Invalid call. Nonexistent function 'duplicate' in base '") + gd::type_name(value) + "'.");
}

// a < b of two Strings (String::operator<): code point by code point, a prefix
// before the longer text. The unsigned byte order of UTF-8 is its code point order.
bool string_less(const State &state, Atom a, Atom b) {
	return state.text(a) < state.text(b);
}

// String(lhs.get("battle_id", "")) < String(rhs.get("battle_id", "")), the left operand first.
bool battle_id_less(const State &state, DictRef lhs, DictRef rhs) {
	const Atom left = gd::string_field(state, lhs, key::battle_id, key::empty);
	const Atom right = gd::string_field(state, rhs, key::battle_id, key::empty);
	return string_less(state, left, right);
}

// var x := ability if not ability.is_empty() else _readiness_writ_ability(source)
DictRef readiness_writ_or_authored(State &state, DictRef source, DictRef ability) {
	return !gd::is_empty(state, ability) ? ability : _readiness_writ_ability(state, source);
}

} // namespace

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
		if (candidate_health < best_health || (candidate_health == best_health && battle_id_less(state, candidate, best))) {
			best = candidate;
		}
	}
	return best;
}

int64_t _pressure_artillery_secondary_damage(State &state, DictRef attacker) {
	const DictRef ability = _ability_by_id(state, attacker, key::pressure_artillery);
	if (gd::is_empty(state, ability) || _alive_count(state, attacker) <= 0) {
		return 0;
	}
	// mini(maxi(1, int(...)), _alive_count(attacker) * maxi(1, int(...))), in that order.
	const int64_t damage_cap = engine_max<int64_t>(1, gd::int_field(state, ability, key::max_secondary_damage, 1));
	const int64_t alive = _alive_count(state, attacker);
	const int64_t per_unit = engine_max<int64_t>(1, gd::int_field(state, ability, key::secondary_damage_per_unit, 1));
	return engine_min<int64_t>(damage_cap, gd::mul(alive, per_unit));
}

ArrayRef _apply_pressure_artillery(State &state, DictRef battle, DictRef attacker, DictRef primary_target) {
	const ArrayRef messages = state.new_array();
	const DictRef ability = _ability_by_id(state, attacker, key::pressure_artillery);
	if (gd::is_empty(state, ability) || _alive_count(state, attacker) <= 0) {
		return messages;
	}
	const DictRef secondary_target = _pressure_artillery_secondary_target(state, battle, attacker, primary_target);
	const int64_t secondary_damage = _pressure_artillery_secondary_damage(state, attacker);
	if (!gd::is_empty(state, secondary_target) && secondary_damage > 0) {
		const DictRef secondary_before = gd::deep_duplicate_dict(state, secondary_target);
		_apply_damage_to_stack(state, battle, gd::string_field(state, secondary_target, key::battle_id, key::empty), secondary_damage);
		const DictRef secondary_after = _get_stack_by_id(state, battle, gd::string_field(state, secondary_target, key::battle_id, key::empty));
		// max(0, int - int): ints.
		const int64_t health_before = gd::int_field(state, secondary_before, key::total_health, 0);
		const int64_t health_after = gd::int_field(state, secondary_after, key::total_health, 0);
		const int64_t secondary_applied = variant_max({ Number::of_int(0), Number::of_int(gd::sub(health_before, health_after)) }).i;
		const Atom ability_name = gd::string_field(state, ability, key::name, key::pressure_artillery_name);
		const Atom secondary_label = _stack_label(state, secondary_before);
		state.append(messages, str(gd::format(state, state.intern("%s throws %d fragment damage into %s."), { str(ability_name), int_value(secondary_applied), str(secondary_label) })));
		{
			const Atom target_id = gd::string_field(state, secondary_target, key::battle_id, key::empty);
			const Atom source_id = gd::string_field(state, attacker, key::battle_id, key::empty);
			const DictRef extra_context = state.new_dict();
			state.set(extra_context, str(key::ability_id), str(key::pressure_artillery));
			_mark_damage_target_animation(state, battle, target_id, true, source_id, extra_context, secondary_before);
		}
		{
			const DictRef extra_context = state.new_dict();
			state.set(extra_context, str(key::ability_id), str(key::pressure_artillery));
			state.set(extra_context, str(key::ability_name), str(ability_name));
			_append_damage_presentation_event(state, battle, key::ability, attacker, secondary_before, secondary_after, secondary_applied, key::pressure_artillery, extra_context);
		}
		const ArrayRef pressure_messages = _apply_damage_pressure(state, battle, attacker, secondary_before, secondary_after, true, key::ability);
		// messages.append_array(pressure_messages): messages is a new untyped Array.
		for (const Value &message : gd::items(state, array_value(pressure_messages))) {
			state.append(messages, message);
		}
		_append_text_presentation_event(state, battle, key::morale, pressure_messages, attacker, secondary_after, key::pressure_artillery);
	}
	const DictRef current_attacker = _get_stack_by_id(state, battle, gd::string_field(state, attacker, key::battle_id, key::empty));
	if (!gd::is_empty(state, current_attacker) && !spell_rules::has_effect_id(state, current_attacker, battle, key::status_overheated)) {
		const Atom attacker_id = gd::string_field(state, attacker, key::battle_id, key::empty);
		const DictRef heat_effect = _status_effect_from_ability(state, ability, battle);
		_apply_stack_effect(state, battle, attacker_id, dict_value(heat_effect));
		const Atom heat_pattern = state.intern("%s runs overheated until its pressure cycle recovers.");
		state.append(messages, str(gd::format(state, heat_pattern, { str(_stack_label(state, attacker)) })));
		const Atom visible_text = gd::format(state, heat_pattern, { str(_stack_label(state, attacker)) });
		const DictRef context = state.new_dict();
		state.set(context, str(key::action_id), str(key::pressure_artillery_heat));
		state.set(context, str(key::actor_battle_id), str(gd::string_field(state, attacker, key::battle_id, key::empty)));
		state.set(context, str(key::target_battle_id), str(gd::string_field(state, attacker, key::battle_id, key::empty)));
		state.set(context, str(key::ability_id), str(key::pressure_artillery));
		state.set(context, str(key::effect_id), str(key::status_overheated));
		_append_presentation_event(state, battle, key::debuff, visible_text, context);
	}
	return messages;
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
	const ArrayRef candidates = _alive_stacks_for_side(state, battle, gd::string_field(state, source, key::side, key::empty));
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
		if (gd::is_empty(state, best) || effect_count > best_effect_count
				|| (effect_count == best_effect_count && cohesion < best_cohesion)
				|| (effect_count == best_effect_count && cohesion == best_cohesion && tier > best_tier)
				|| (effect_count == best_effect_count && cohesion == best_cohesion && tier == best_tier && string_less(state, candidate_id, best_id))) {
			best = candidate;
			best_effect_count = effect_count;
			best_cohesion = cohesion;
			best_tier = tier;
		}
	}
	return best;
}

DictRef _readiness_writ_preparation_target(State &state, DictRef battle, DictRef source, DictRef ability) {
	const DictRef readiness_writ = readiness_writ_or_authored(state, source, ability);
	if (gd::is_empty(state, source) || gd::is_empty(state, readiness_writ)) {
		return state.new_dict();
	}
	const Atom source_id = gd::string_field(state, source, key::battle_id, key::empty);
	const Atom preparation_status_id = gd::string_field(state, readiness_writ, key::preparation_status_id, key::status_readiness_prepared);
	const Atom target_role = gd::string_field(state, readiness_writ, key::preparation_target_role, key::empty);
	const int64_t target_min_tier = gd::int_field(state, readiness_writ, key::preparation_target_min_tier, 1);
	DictRef best = state.new_dict();
	int64_t best_cohesion = 999;
	int64_t best_tier = 0;
	const ArrayRef candidates = _alive_stacks_for_side(state, battle, gd::string_field(state, source, key::side, key::empty));
	for (const Value &candidate_value : gd::items(state, array_value(candidates))) {
		const DictRef candidate = gd::as_dict(candidate_value);
		if (gd::string_field(state, candidate, key::battle_id, key::empty) == source_id) {
			continue;
		}
		if (target_role != key::empty && gd::string_field(state, candidate, key::role, key::melee) != target_role) {
			continue;
		}
		if (gd::int_field(state, candidate, key::tier, 1) < target_min_tier) {
			continue;
		}
		if (preparation_status_id != key::empty && spell_rules::has_effect_id(state, candidate, battle, preparation_status_id)) {
			continue;
		}
		const int64_t cohesion = _stack_cohesion_total(state, candidate, battle);
		const int64_t tier = gd::int_field(state, candidate, key::tier, 1);
		const Atom candidate_id = gd::string_field(state, candidate, key::battle_id, key::empty);
		const Atom best_id = gd::string_field(state, best, key::battle_id, key::empty);
		if (gd::is_empty(state, best) || cohesion < best_cohesion
				|| (cohesion == best_cohesion && tier > best_tier)
				|| (cohesion == best_cohesion && tier == best_tier && string_less(state, candidate_id, best_id))) {
			best = candidate;
			best_cohesion = cohesion;
			best_tier = tier;
		}
	}
	return best;
}

bool _readiness_writ_available(State &state, DictRef source, DictRef battle, DictRef ability) {
	const DictRef readiness_writ = readiness_writ_or_authored(state, source, ability);
	if (gd::is_empty(state, source) || gd::is_empty(state, readiness_writ) || _alive_count(state, source) <= 0
			|| !gd::bool_field(state, source, key::ranged, false)) {
		return false;
	}
	// var ability_uses = source.get("ability_uses", {}): the default {} holds no uses.
	Value ability_uses;
	if (!state.lookup(source, str(key::ability_uses), ability_uses)) {
		ability_uses = dict_value(state.new_dict());
	}
	if (!gd::is_dict(ability_uses)) {
		return false;
	}
	{
		const int64_t used = gd::int_field(state, ability_uses.ref, key::readiness_writ, 0);
		if (used >= gd::int_field(state, readiness_writ, key::uses_per_battle, 1)) {
			return false;
		}
	}
	return !gd::is_empty(state, _readiness_writ_target(state, battle, source, readiness_writ))
			|| !gd::is_empty(state, _readiness_writ_preparation_target(state, battle, source, readiness_writ));
}

DictRef _apply_readiness_writ(State &state, DictRef battle, DictRef attacker) {
	const DictRef source = _get_stack_by_id(state, battle, gd::string_field(state, attacker, key::battle_id, key::empty));
	const DictRef readiness_writ = _readiness_writ_ability(state, source);
	if (!_readiness_writ_available(state, source, battle, readiness_writ)) {
		return state.new_dict();
	}
	DictRef target = _readiness_writ_target(state, battle, source, readiness_writ);
	const bool preparing = gd::is_empty(state, target);
	if (preparing) {
		const DictRef eligible_target = _readiness_writ_preparation_target(state, battle, source, readiness_writ);
		if (!gd::is_empty(state, eligible_target)) {
			target = source;
		}
	}
	if (gd::is_empty(state, target)) {
		return state.new_dict();
	}
	const Atom target_id = gd::string_field(state, target, key::battle_id, key::empty);
	int64_t cleansed = 0;
	if (preparing) {
		const Atom status_id = gd::string_field(state, readiness_writ, key::preparation_status_id, key::status_readiness_prepared);
		const Atom status_label = gd::string_field(state, readiness_writ, key::preparation_status_label, key::mustered_label);
		const DictRef modifiers = state.new_dict();
		const int64_t duration_rounds = gd::int_field(state, readiness_writ, key::preparation_duration_rounds, 99);
		// status_immunity_ids: its default [].
		const DictRef preparation_effect = spell_rules::build_battle_effect(state, status_id, status_label, dict_value(modifiers), duration_rounds, battle, key::ability, key::readiness_writ, array_value(state.new_array()));
		state.set(preparation_effect, str(key::blocked_status_ids), duplicate_deep_untyped(state, field_or_new_array(state, readiness_writ, key::cleansed_status_ids)));
		state.set(preparation_effect, str(key::protected_side), str(gd::string_field(state, source, key::side, key::empty)));
		state.set(preparation_effect, str(key::target_role), str(gd::string_field(state, readiness_writ, key::preparation_target_role, key::empty)));
		state.set(preparation_effect, str(key::target_min_tier), int_value(gd::int_field(state, readiness_writ, key::preparation_target_min_tier, 1)));
		_apply_stack_effect(state, battle, target_id, dict_value(preparation_effect));
	} else {
		cleansed = _cleanse_stack_effects(state, battle, target_id, field_or_new_array(state, readiness_writ, key::cleansed_status_ids));
		if (cleansed <= 0) {
			return state.new_dict();
		}
	}
	const Value stacks = field_or_new_array(state, battle, key::stacks);
	const int64_t count = untyped_size(state, stacks);
	for (int64_t index = 0; index < count; ++index) {
		const Value stack = untyped_at(state, stacks, index);
		if (!gd::is_dict(stack)) {
			continue;
		}
		{
			const Atom stack_id = gd::string_field(state, stack.ref, key::battle_id, key::empty);
			const Atom source_id = gd::string_field(state, source, key::battle_id, key::empty);
			if (stack_id != source_id) {
				continue;
			}
		}
		// var ability_uses = stack.get("ability_uses", {}); a missing or
		// non-Dictionary value becomes a new {}.
		Value ability_uses;
		if (!state.lookup(stack.ref, str(key::ability_uses), ability_uses) || !gd::is_dict(ability_uses)) {
			ability_uses = dict_value(state.new_dict());
		}
		state.set(ability_uses.ref, str(key::readiness_writ), int_value(gd::add(gd::int_field(state, ability_uses.ref, key::readiness_writ, 0), 1)));
		state.set(stack.ref, str(key::ability_uses), ability_uses);
		untyped_set_at(state, stacks, index, stack);
		break;
	}
	state.set(battle, str(key::stacks), stacks);
	Atom visible_text = key::empty;
	{
		const Atom source_label = _stack_label(state, source);
		const Atom writ_name = gd::string_field(state, readiness_writ, key::name, key::readiness_writ_name);
		if (preparing) {
			visible_text = gd::format(state, state.intern("%s sounds %s and holds one writ for the next disrupted veteran line."), { str(source_label), str(writ_name) });
		} else {
			const Atom target_label = _stack_label(state, target);
			visible_text = gd::format(state, state.intern("%s sounds %s and clears the disruption from %s."), { str(source_label), str(writ_name), str(target_label) });
		}
	}
	{
		const DictRef context = state.new_dict();
		state.set(context, str(key::action_id), str(key::readiness_writ));
		state.set(context, str(key::actor_battle_id), str(gd::string_field(state, source, key::battle_id, key::empty)));
		state.set(context, str(key::target_battle_id), str(target_id));
		_mark_stack_animation_event(state, battle, target_id, preparing ? key::battle_status_applied : key::battle_status_expired, context);
	}
	{
		const DictRef context = state.new_dict();
		state.set(context, str(key::action_id), str(key::readiness_writ));
		state.set(context, str(key::actor_battle_id), str(gd::string_field(state, source, key::battle_id, key::empty)));
		state.set(context, str(key::target_battle_id), str(target_id));
		state.set(context, str(key::cleansed_effect_count), int_value(cleansed));
		const Atom effect_id = preparing ? gd::string_field(state, readiness_writ, key::preparation_status_id, key::status_readiness_prepared) : key::empty;
		state.set(context, str(key::effect_id), str(effect_id));
		_append_presentation_event(state, battle, preparing ? key::effect : key::cleanse, visible_text, context);
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::message), str(visible_text));
	state.set(result, str(key::cleansed_effect_count), int_value(cleansed));
	state.set(result, str(key::target_battle_id), str(target_id));
	state.set(result, str(key::prepared), bool_value(preparing));
	return result;
}

DictRef _sporeglass_mend_target(State &state, DictRef battle, Atom side) {
	DictRef best = state.new_dict();
	int64_t best_recoverable = 0;
	const ArrayRef candidates = _alive_stacks_for_side(state, battle, side);
	for (const Value &candidate_value : gd::items(state, array_value(candidates))) {
		const DictRef candidate = gd::as_dict(candidate_value);
		const int64_t recoverable = spell_rules::battle_spell_recoverable_health(state, candidate);
		if (recoverable <= 0) {
			continue;
		}
		const int64_t candidate_tier = gd::int_field(state, candidate, key::tier, 1);
		const int64_t best_tier = gd::int_field(state, best, key::tier, 1);
		const Atom candidate_id = gd::string_field(state, candidate, key::battle_id, key::empty);
		const Atom best_id = gd::string_field(state, best, key::battle_id, key::empty);
		if (gd::is_empty(state, best) || recoverable > best_recoverable
				|| (recoverable == best_recoverable && candidate_tier > best_tier)
				|| (recoverable == best_recoverable && candidate_tier == best_tier && string_less(state, candidate_id, best_id))) {
			best = candidate;
			best_recoverable = recoverable;
		}
	}
	return best;
}

DictRef _apply_sporeglass_mending_fire(State &state, DictRef battle, DictRef attacker) {
	const DictRef source = _get_stack_by_id(state, battle, gd::string_field(state, attacker, key::battle_id, key::empty));
	if (gd::is_empty(state, source) || _alive_count(state, source) <= 0) {
		return state.new_dict();
	}
	const DictRef ability = _ability_by_id(state, source, key::sporeglass_mend);
	if (gd::is_empty(state, ability) || !gd::bool_field(state, source, key::ranged, false)) {
		return state.new_dict();
	}
	// var requested: int = min(int(...), _alive_count(source) * int(...)): min() of two ints is an int.
	const int64_t max_per_attack = gd::int_field(state, ability, key::max_health_per_attack, 0);
	const int64_t alive = _alive_count(state, source);
	const int64_t per_mender = gd::int_field(state, ability, key::health_per_mender, 0);
	const int64_t requested = variant_min({ Number::of_int(max_per_attack), Number::of_int(gd::mul(alive, per_mender)) }).i;
	if (requested <= 0) {
		return state.new_dict();
	}
	const DictRef target = _sporeglass_mend_target(state, battle, gd::string_field(state, source, key::side, key::empty));
	if (gd::is_empty(state, target)) {
		return state.new_dict();
	}
	const int64_t restored = _restore_stack_health(state, battle, gd::string_field(state, target, key::battle_id, key::empty), requested);
	if (restored <= 0) {
		return state.new_dict();
	}
	const Atom source_label = _stack_label(state, source);
	const Atom target_label = _stack_label(state, target);
	const Atom visible_text = gd::format(state, state.intern("%s restores %d surviving health to %s with Mending Fire."), { str(source_label), int_value(restored), str(target_label) });
	{
		const DictRef context = state.new_dict();
		state.set(context, str(key::action_id), str(key::sporeglass_mend));
		state.set(context, str(key::actor_battle_id), str(gd::string_field(state, source, key::battle_id, key::empty)));
		state.set(context, str(key::target_battle_id), str(gd::string_field(state, target, key::battle_id, key::empty)));
		state.set(context, str(key::healing), int_value(restored));
		_append_presentation_event(state, battle, key::heal, visible_text, context);
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::message), str(visible_text));
	state.set(result, str(key::restored), int_value(restored));
	state.set(result, str(key::target_battle_id), str(gd::string_field(state, target, key::battle_id, key::empty)));
	return result;
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

DictRef _lowest_health_stack(State &state, ArrayRef stacks) {
	// var best = {}: untyped, always a Dictionary.
	DictRef best = state.new_dict();
	for (const Value &stack : gd::items(state, array_value(stacks))) {
		if (!gd::is_dict(stack)) {
			continue;
		}
		if (gd::is_empty(state, best)) {
			best = stack.ref;
			continue;
		}
		const int64_t stack_health = gd::int_field(state, stack.ref, key::total_health, 0);
		const int64_t best_health = gd::int_field(state, best, key::total_health, 0);
		if (stack_health < best_health) {
			best = stack.ref;
		}
	}
	return best;
}

} // namespace aurelion::rules::port::battle_rules
