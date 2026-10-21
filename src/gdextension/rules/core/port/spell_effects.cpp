// Layer 2: the effect reads of a stack, the town assault effects and the damage rules' multipliers.

#include "aurelion_rules/port/battle_damage_rules.hpp"
#include "aurelion_rules/port/battle_rules.hpp"
#include "aurelion_rules/port/spell_rules.hpp"
#include "aurelion_rules/port/town_battle_rules.hpp"

#include <string>

namespace aurelion::rules::port {

namespace key = state::key;

namespace {

using gd::Atom;
using gd::DictRef;
using state::Kind;
using state::State;
using state::Value;

// x.get(field, fallback) of an untyped value: Dictionary.get. No other type
// GDScript can hold here has a get(key, default) (Nil, a number or a String
// has no get, an Array's or an Object's takes one argument): a runtime error.
// found is false where the Dictionary has no such key (the fallback's case).
bool variant_lookup(const State &state, const Value &base, Atom field, Value &found) {
	if (base.kind != Kind::Dict) {
		throw state::ScriptError(std::string("Invalid call. Nonexistent function 'get' in base '") + gd::type_name(base) + "'.");
	}
	return state.lookup(base.ref, gd::str(field), found);
}

Value variant_get(const State &state, const Value &base, Atom field, const Value &fallback) {
	Value found;
	return variant_lookup(state, base, field, found) ? found : fallback;
}

// x.is_empty() of an untyped value: Dictionary, Array, String and StringName
// have it; any other type is a runtime error.
bool variant_is_empty(const State &state, const Value &value) {
	switch (value.kind) {
		case Kind::Dict:
			return state.dict_size(value.ref) == 0;
		case Kind::Array:
			return state.array_size(value.ref) == 0;
		case Kind::String:
		case Kind::StringName:
			return state.text(value.ref).empty();
		case Kind::Opaque:
			// A packed array would have is_empty(), an Object would not.
			throw state::ScriptError("is_empty() of an opaque value is not ported");
		default:
			throw state::ScriptError(std::string("Invalid call. Nonexistent function 'is_empty' in base '") + gd::type_name(value) + "'.");
	}
}

// var value: Dictionary = x: only a Dictionary assigns (Nil does not convert
// to Dictionary), anything else stops the script.
DictRef assign_dictionary(const Value &value) {
	if (value.kind != Kind::Dict) {
		throw state::ScriptError(std::string("Trying to assign value of type '") + gd::type_name(value) + "' to a variable of type 'Dictionary'.");
	}
	return value.ref;
}

} // namespace

} // namespace aurelion::rules::port

namespace aurelion::rules::port::spell_rules {

using compat::engine_max;
using gd::array_value;
using gd::dict_value;
using gd::int_value;
using gd::str;

int64_t battle_spell_recoverable_health(State &state, DictRef stack) {
	const int64_t current_health = engine_max<int64_t>(0, gd::int_field(state, stack, key::total_health, 0));
	if (current_health <= 0) {
		return 0;
	}
	const int64_t unit_hp = engine_max<int64_t>(1, gd::int_field(state, stack, key::unit_hp, 1));
	const int64_t living_creatures = compat::float_to_int(compat::godot_ceil(static_cast<double>(current_health) / static_cast<double>(unit_hp)));
	return engine_max<int64_t>(0, gd::sub(gd::mul(living_creatures, unit_hp), current_health));
}

int64_t effect_bonus_for_kind(State &state, DictRef stack, DictRef battle, Atom kind) {
	int64_t total = 0;
	const int64_t current_round = gd::int_field(state, battle, key::round, 1);
	const ArrayRef active = active_effects_for_round(state, stack, current_round);
	for (const Value &effect : gd::items(state, array_value(active))) {
		Value modifiers;
		if (!state.lookup(gd::as_dict(effect), str(key::modifiers), modifiers)) {
			continue; // the default {} adds int(0)
		}
		if (gd::is_dict(modifiers)) {
			total = gd::add(total, gd::int_field(state, modifiers.ref, kind, 0));
		}
	}
	return total;
}

bool has_effect_id(State &state, DictRef stack, DictRef battle, Atom effect_id) {
	if (effect_id == key::empty) {
		return false;
	}
	const int64_t current_round = gd::int_field(state, battle, key::round, 1);
	Value effects;
	if (!state.lookup(stack, str(key::effects), effects)) {
		return false; // the default [] has nothing to walk
	}
	if (!gd::is_array(effects)) {
		return false;
	}
	for (const Value &effect : gd::items(state, effects)) {
		if (!gd::is_dict(effect)) {
			continue;
		}
		if (gd::int_field(state, effect.ref, key::expires_after_round, 0) < current_round) {
			continue;
		}
		// The fallbacks are evaluated first, innermost first.
		const Value kind_value = gd::field_or(state, effect.ref, key::kind, str(key::empty));
		const Value spell_value = gd::field_or(state, effect.ref, key::spell_id, kind_value);
		const Atom fallback_id = gd::to_string(spell_value);
		if (gd::string_field(state, effect.ref, key::effect_id, fallback_id) == effect_id) {
			return true;
		}
	}
	return false;
}

bool has_any_effect_ids(State &state, DictRef stack, DictRef battle, const Value &effect_ids) {
	if (!gd::is_array(effect_ids)) {
		return false;
	}
	for (const Value &effect_id_value : gd::items(state, effect_ids)) {
		if (has_effect_id(state, stack, battle, gd::to_string(effect_id_value))) {
			return true;
		}
	}
	return false;
}

ArrayRef active_effects_for_round(State &state, DictRef stack, int64_t round_number) {
	Value effects;
	if (!state.lookup(stack, str(key::effects), effects)) {
		return state.new_array(); // the default [] is an empty Array
	}
	if (gd::is_array(effects) && state.array_size(effects.ref) == 0) {
		return state.new_array();
	}
	const ArrayRef results = state.new_array();
	const ArrayRef normalized = _normalize_effects(state, effects);
	for (const Value &effect : gd::items(state, array_value(normalized))) {
		if (gd::int_field(state, gd::as_dict(effect), key::expires_after_round, 0) >= round_number) {
			state.append(results, effect);
		}
	}
	return results;
}

ArrayRef _normalize_effects(State &state, const Value &value) {
	const ArrayRef effects = state.new_array();
	if (!gd::is_array(value)) {
		return effects;
	}
	for (const Value &effect_value : gd::items(state, value)) {
		if (!gd::is_dict(effect_value)) {
			continue;
		}
		const DictRef effect = effect_value.ref;
		Value modifiers;
		if (!state.lookup(effect, str(key::modifiers), modifiers)) {
			modifiers = dict_value(state.new_dict()); // the default {}
		}
		if (!gd::is_dict(modifiers)) {
			const DictRef legacy = state.new_dict();
			modifiers = dict_value(legacy);
			const Atom legacy_kind = gd::string_field(state, effect, key::kind, key::empty);
			if (legacy_kind != key::empty) {
				state.set(legacy, str(legacy_kind), int_value(gd::int_field(state, effect, key::amount, 0)));
			}
		}
		// The literal's values in its order; each fallback is evaluated before its get.
		const DictRef normalized = state.new_dict();
		{
			const Value kind_value = gd::field_or(state, effect, key::kind, str(key::empty));
			const Value spell_value = gd::field_or(state, effect, key::spell_id, kind_value);
			const Atom fallback_id = gd::to_string(spell_value);
			state.set(normalized, str(key::effect_id), str(gd::string_field(state, effect, key::effect_id, fallback_id)));
		}
		{
			const Atom spell_text = gd::string_field(state, effect, key::spell_id, key::empty);
			const Atom fallback_type = spell_text != key::empty ? static_cast<Atom>(key::spell) : static_cast<Atom>(key::status);
			state.set(normalized, str(key::source_type), str(gd::string_field(state, effect, key::source_type, fallback_type)));
		}
		{
			const Value spell_value = gd::field_or(state, effect, key::spell_id, str(key::empty));
			state.set(normalized, str(key::source_id), str(gd::to_string(gd::field_or(state, effect, key::source_id, spell_value))));
		}
		state.set(normalized, str(key::spell_id), str(gd::string_field(state, effect, key::spell_id, key::empty)));
		{
			const Value kind_value = gd::field_or(state, effect, key::kind, str(key::Effect));
			state.set(normalized, str(key::label), str(gd::to_string(gd::field_or(state, effect, key::label, kind_value))));
		}
		state.set(normalized, str(key::kind), str(gd::string_field(state, effect, key::kind, key::empty)));
		state.set(normalized, str(key::amount), int_value(gd::int_field(state, effect, key::amount, 0)));
		state.set(normalized, str(key::modifiers), dict_value(_normalize_effect_modifiers(state, modifiers)));
		// A missing key's default [] normalizes as Nil does, to a new empty Array.
		state.set(normalized, str(key::status_immunity_ids), array_value(normalize_status_immunity_ids(state, gd::field(state, effect, key::status_immunity_ids))));
		state.set(normalized, str(key::expires_after_round), int_value(gd::int_field(state, effect, key::expires_after_round, 0)));
		const ArrayRef blocked_status_ids = normalize_blocked_status_ids(state, gd::field(state, effect, key::blocked_status_ids));
		if (state.array_size(blocked_status_ids) != 0) {
			state.set(normalized, str(key::blocked_status_ids), array_value(blocked_status_ids));
			state.set(normalized, str(key::protected_side), str(gd::string_field(state, effect, key::protected_side, key::empty)));
			state.set(normalized, str(key::target_role), str(gd::string_field(state, effect, key::target_role, key::empty)));
			state.set(normalized, str(key::target_min_tier), int_value(engine_max<int64_t>(1, gd::int_field(state, effect, key::target_min_tier, 1))));
		}
		if (state.has(effect, str(key::turns_left))) {
			state.set(normalized, str(key::turns_left), int_value(engine_max<int64_t>(1, gd::int_field(state, effect, key::turns_left, 1))));
			if (gd::bool_field(state, effect, key::skip_current_turn, false)) {
				state.set(normalized, str(key::skip_current_turn), gd::bool_value(true));
			}
		}
		state.append(effects, dict_value(normalized));
	}
	return effects;
}

DictRef _normalize_effect_modifiers(State &state, const Value &value) {
	const DictRef modifiers = state.new_dict();
	if (!gd::is_dict(value)) {
		return modifiers;
	}
	// value.keys(): a copy of the keys.
	const state::ValueList keys = state.dict(value.ref).keys.list();
	for (const Value &modifier : keys) {
		const Atom modifier_key = gd::to_string(modifier);
		if (modifier_key == key::empty) {
			continue;
		}
		state.set(modifiers, str(modifier_key), int_value(gd::to_int(state, gd::index(state, value.ref, modifier))));
	}
	return modifiers;
}

ArrayRef normalize_blocked_status_ids(State &state, const Value &value) {
	const ArrayRef ids = state.new_array();
	if (!gd::is_array(value)) {
		return ids;
	}
	for (const Value &status_id_value : gd::items(state, value)) {
		const Atom status_id = gd::strip_edges(state, gd::to_string(status_id_value));
		if (status_id != key::empty && !gd::array_has(state, ids, str(status_id))) {
			state.append(ids, str(status_id));
			if (state.array_size(ids) >= 16) {
				break;
			}
		}
	}
	return ids;
}

ArrayRef normalize_status_immunity_ids(State &state, const Value &value) {
	const ArrayRef ids = state.new_array();
	if (!gd::is_array(value)) {
		return ids;
	}
	for (const Value &status_id_value : gd::items(state, value)) {
		const Atom status_id = gd::to_string(status_id_value);
		// status_id in STATUS_EFFECT_IDS.
		const bool known = status_id == key::status_harried || status_id == key::status_staggered || status_id == key::status_rooted || status_id == key::status_overheated;
		if (known && !gd::array_has(state, ids, str(status_id))) {
			state.append(ids, str(status_id));
		}
	}
	return ids;
}

} // namespace aurelion::rules::port::spell_rules

namespace aurelion::rules::port::battle_rules {

using gd::array_value;
using gd::str;

bool _stack_has_positive_effect(State &state, DictRef stack, DictRef battle) {
	static constexpr Atom kModifierKeys[] = { key::attack, key::defense, key::initiative, key::cohesion, key::momentum };
	const int64_t current_round = gd::int_field(state, battle, key::round, 1);
	const ArrayRef active = spell_rules::active_effects_for_round(state, stack, current_round);
	for (const Value &effect : gd::items(state, array_value(active))) {
		Value modifiers;
		if (!state.lookup(gd::as_dict(effect), str(key::modifiers), modifiers)) {
			continue; // the default {} has no modifier above 0
		}
		if (!gd::is_dict(modifiers)) {
			continue;
		}
		for (const Atom modifier_key : kModifierKeys) {
			if (gd::int_field(state, modifiers.ref, modifier_key, 0) > 0) {
				return true;
			}
		}
	}
	return false;
}

int64_t _side_positive_effect_count(State &state, DictRef battle, Atom side) {
	int64_t total = 0;
	const ArrayRef alive = _alive_stacks_for_side(state, battle, side);
	for (const Value &stack : gd::items(state, array_value(alive))) {
		if (gd::is_dict(stack) && _stack_has_positive_effect(state, stack.ref, battle)) {
			total = gd::add(total, 1);
		}
	}
	return total;
}

} // namespace aurelion::rules::port::battle_rules

namespace aurelion::rules::port::town_battle_rules {

using compat::engine_max;
using compat::engine_min;
using gd::int_value;
using gd::str;

DictRef effect(State &state, DictRef battle, Atom id) {
	Value defenses;
	if (!state.lookup(battle, str(key::town_defenses), defenses)) {
		return state.new_dict(); // {}.get("effects", {}).get(id, {}) is empty: a new {}
	}
	Value effects;
	if (!variant_lookup(state, defenses, key::effects, effects)) {
		return state.new_dict(); // {}.get(id, {}) is empty: a new {}
	}
	Value found;
	if (!variant_lookup(state, effects, id, found)) {
		return state.new_dict(); // the default {} is empty: a new {}
	}
	const DictRef value = assign_dictionary(found);
	if (gd::is_empty(state, value) || gd::int_field(state, battle, key::round, 1) > gd::int_field(state, value, key::rounds, 999)) {
		return state.new_dict();
	}
	return value;
}

bool defends(State &state, DictRef battle, DictRef stack) {
	Value defenses;
	if (!state.lookup(battle, str(key::town_defenses), defenses)) {
		return false; // the default {} is empty
	}
	if (variant_is_empty(state, defenses)) {
		return false;
	}
	const Value side = gd::field_or(state, stack, key::side, str(key::empty));
	// battle.town_defenses: the key, read again.
	const Value named = gd::index(state, battle, str(key::town_defenses));
	return gd::equal(state, side, variant_get(state, named, key::side, str(key::empty)));
}

double damage_multiplier(State &state, DictRef battle, DictRef attacker, DictRef defender, bool ranged) {
	if (!ranged) {
		return 1.0;
	}
	double multiplier = 1.0;
	if (defends(state, battle, attacker)) {
		multiplier *= 1.0 + gd::to_float(gd::field_or(state, effect(state, battle, key::beacon_volley), key::damage_pct, int_value(0))) / 100.0;
	}
	if (defends(state, battle, defender)) {
		multiplier *= 1.0 - gd::to_float(gd::field_or(state, effect(state, battle, key::bellwake_fog), key::ranged_reduction_pct, int_value(0))) / 100.0;
	}
	return multiplier;
}

int64_t absorb(State &state, DictRef stack, int64_t damage) {
	const int64_t absorbed = engine_min<int64_t>(engine_max<int64_t>(0, gd::int_field(state, stack, key::town_shield_hp, 0)), engine_max<int64_t>(0, damage));
	if (absorbed > 0) {
		const int64_t shield = gd::to_int(state, gd::index(state, stack, str(key::town_shield_hp)));
		state.set(stack, str(key::town_shield_hp), int_value(gd::sub(shield, absorbed)));
	}
	return absorbed;
}

} // namespace aurelion::rules::port::town_battle_rules

namespace aurelion::rules::port::battle_damage_rules {

using compat::engine_max;
using gd::str;

double hero_damage_multiplier(State &state, DictRef attacker_hero, DictRef defender_hero, bool is_ranged, bool is_retaliation, bool is_town_assault) {
	int64_t pct = gd::int_field(state, attacker_hero, is_ranged ? static_cast<Atom>(key::ranged_damage_pct) : static_cast<Atom>(key::melee_damage_pct), 0);
	if (is_retaliation) {
		pct = gd::add(pct, gd::int_field(state, attacker_hero, key::retaliation_damage_pct, 0));
	}
	if (is_town_assault) {
		pct = gd::add(pct, gd::int_field(state, attacker_hero, key::siege_damage_pct, 0));
	}
	const double taken = engine_max<double>(0.1, 1.0 + static_cast<double>(gd::int_field(state, defender_hero, key::damage_taken_pct, 0)) / 100.0);
	return (1.0 + static_cast<double>(pct) / 100.0) * taken;
}

Atom town_assault_side(State &state, DictRef battle) {
	Value context;
	if (!state.lookup(battle, str(key::context), context)) {
		return key::empty; // the default {} has no type: ""
	}
	const Atom context_type = gd::is_dict(context) ? gd::string_field(state, context.ref, key::type, key::empty) : static_cast<Atom>(key::empty);
	if (context_type == key::town_assault) {
		return key::player;
	}
	if (context_type == key::town_defense) {
		return key::enemy;
	}
	return key::empty;
}

} // namespace aurelion::rules::port::battle_damage_rules
