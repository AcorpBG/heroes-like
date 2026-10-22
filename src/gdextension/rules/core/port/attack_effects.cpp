// Layer 5: attack effects: the attack and retaliation ability effects, the hookline pull, the counter-ambush flare,
// strike-backs, retaliation and shot use, and SpellRules.build_battle_effect.

#include "aurelion_rules/port/battle_footprint.hpp"
#include "aurelion_rules/port/battle_rules.hpp"
#include "aurelion_rules/port/spell_rules.hpp"

#include "aurelion_rules/compat/godot_string.hpp"

#include <string>

namespace aurelion::rules::port {

namespace key = state::key;

namespace {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using state::Kind;
using state::State;
using state::Value;

// d.get(field, []): the stored value, or a new empty Array when the key is missing.
Value field_or_new_array(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, gd::str(field), found)) {
		return found;
	}
	return gd::array_value(state.new_array());
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
		return gd::index(state, value.ref, gd::int_value(index));
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
		state.set(value.ref, gd::int_value(index), item);
		return;
	}
	throw state::ScriptError(std::string("Invalid assignment of index '") + compat::itos(index) + "' on a base object of type '" + gd::type_name(value) + "'.");
}

// var x: Dictionary = d.get(field, {}): the stored Dictionary, a new {} when
// the key is missing; anything else (Nil included) stops the script.
DictRef dict_field_or_new(State &state, DictRef dict, Atom field) {
	Value found;
	if (!state.lookup(dict, gd::str(field), found)) {
		return state.new_dict();
	}
	if (found.kind != Kind::Dict) {
		throw state::ScriptError(std::string("Trying to assign value of type '") + gd::type_name(found) + "' to a variable of type 'Dictionary'.");
	}
	return found.ref;
}

// x.get(field, fallback) of an untyped value: Dictionary.get. No other type
// GDScript can hold here has a get(key, default): a runtime error.
Value variant_get(const State &state, const Value &base, Atom field, const Value &fallback) {
	if (base.kind != Kind::Dict) {
		throw state::ScriptError(std::string("Invalid call. Nonexistent function 'get' in base '") + gd::type_name(base) + "'.");
	}
	return state.get(base.ref, gd::str(field), fallback);
}

// container.has(item) on an untyped value: Array.has (StringLikeVariantComparator),
// Dictionary.has or PackedStringArray.has. Nil and the other modelled types have
// no has() for a String.
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

// s.to_lower() of ASCII text (other text throws: the Unicode case tables are
// not ported).
Atom lower_text(State &state, Atom text) {
	std::string lowered = state.text(text);
	bool changed = false;
	for (char &c : lowered) {
		if (static_cast<unsigned char>(c) >= 0x80) {
			throw state::ScriptError("to_lower() of non-ASCII text is not ported");
		}
		if (c >= 'A' && c <= 'Z') {
			c = static_cast<char>(c - 'A' + 'a');
			changed = true;
		}
	}
	return changed ? state.intern(lowered) : text;
}

// a.append_array(b) of an untyped a.
void append_array(State &state, ArrayRef array, ArrayRef other) {
	const state::ValueList items = state.array(other).items;
	for (const Value &item : items) {
		state.append(array, item);
	}
}

// {first: first_value, second: second_value}, a literal of two int entries.
DictRef int_pair_dict(State &state, Atom first, int64_t first_value, Atom second, int64_t second_value) {
	const DictRef dict = state.new_dict();
	state.set(dict, gd::str(first), gd::int_value(first_value));
	state.set(dict, gd::str(second), gd::int_value(second_value));
	return dict;
}

} // namespace

} // namespace aurelion::rules::port

namespace aurelion::rules::port::spell_rules {

using compat::engine_max;
using gd::array_value;
using gd::dict_value;
using gd::int_value;
using gd::str;

DictRef build_battle_effect(State &state, Atom effect_id, Atom label, const Value &modifiers, int64_t duration_rounds, DictRef battle, Atom source_type, Atom source_id, const Value &status_immunity_ids) {
	const DictRef normalized_modifiers = _normalize_effect_modifiers(state, modifiers);
	// The loop breaks on its first key.
	Atom fallback_kind = key::empty;
	int64_t fallback_amount = 0;
	{
		const state::DictNode &node = state.dict(normalized_modifiers);
		if (!node.keys.empty()) {
			const Value first_key = node.keys[0];
			const Value first_value = node.values[0];
			fallback_kind = gd::to_string(first_key);
			fallback_amount = gd::to_int(state, first_value);
		}
	}
	// The literal's values in its order.
	const Atom spell_id = source_type == key::spell ? source_id : static_cast<Atom>(key::empty);
	const Atom shown_label = label != key::empty ? label : gd::capitalize(state, fallback_kind);
	const ArrayRef immunity_ids = normalize_status_immunity_ids(state, status_immunity_ids);
	const int64_t first_round = engine_max<int64_t>(1, gd::int_field(state, battle, key::round, 1));
	const int64_t expires_after_round = gd::sub(gd::add(first_round, engine_max<int64_t>(1, duration_rounds)), 1);
	const DictRef effect = state.new_dict();
	state.set(effect, str(key::effect_id), str(effect_id));
	state.set(effect, str(key::source_type), str(source_type));
	state.set(effect, str(key::source_id), str(source_id));
	state.set(effect, str(key::spell_id), str(spell_id));
	state.set(effect, str(key::label), str(shown_label));
	state.set(effect, str(key::kind), str(fallback_kind));
	state.set(effect, str(key::amount), int_value(fallback_amount));
	state.set(effect, str(key::modifiers), dict_value(normalized_modifiers));
	state.set(effect, str(key::status_immunity_ids), array_value(immunity_ids));
	state.set(effect, str(key::expires_after_round), int_value(expires_after_round));
	return effect;
}

} // namespace aurelion::rules::port::spell_rules

namespace aurelion::rules::port::battle_rules {

using compat::engine_max;
using gd::array_value;
using gd::bool_value;
using gd::dict_value;
using gd::int_value;
using gd::str;

namespace {

// String(stack.get("battle_id", ""))
Atom stack_battle_id(const State &state, DictRef stack) {
	return gd::string_field(state, stack, key::battle_id, key::empty);
}

// var ability_uses = stack.get("ability_uses", {}); a missing or
// non-Dictionary value becomes a new {}.
DictRef ability_uses_of(State &state, DictRef stack) {
	Value found;
	if (state.lookup(stack, str(key::ability_uses), found) && gd::is_dict(found)) {
		return found.ref;
	}
	return state.new_dict();
}

// ability_uses[use_key] = int(ability_uses.get(use_key, 0)) + 1, then
// stack["ability_uses"] = ability_uses.
void count_ability_use(State &state, DictRef stack, DictRef ability_uses, Atom use_key) {
	state.set(ability_uses, str(use_key), int_value(gd::add(gd::int_field(state, ability_uses, use_key, 0), 1)));
	state.set(stack, str(key::ability_uses), dict_value(ability_uses));
}

// elif String(result.get("message", "")) != "": messages.append(String(result.get("message", "")))
void append_result_message(State &state, ArrayRef messages, DictRef result) {
	const Atom message = gd::string_field(state, result, key::message, key::empty);
	if (message != key::empty) {
		state.append(messages, str(message));
	}
}

// bool(flare.get("ability", {}).get("blocks_ambush_status", false))
bool flare_blocks_ambush_status(State &state, DictRef flare) {
	Value ability;
	if (!state.lookup(flare, str(key::ability), ability)) {
		return false; // the default {} has no such key
	}
	return gd::to_bool(variant_get(state, ability, key::blocks_ambush_status, bool_value(false)));
}

// The status of an ability applied to target: "%s is %s." % [_stack_label(target),
// String(ability.get("status_label", fallback_label)).to_lower()] when applied, else
// the result's message.
void append_status_outcome(State &state, ArrayRef messages, DictRef result, DictRef target, DictRef ability, Atom fallback_label) {
	if (gd::bool_field(state, result, key::applied, false)) {
		const Atom target_label = _stack_label(state, target);
		const Atom status_label = lower_text(state, gd::string_field(state, ability, key::status_label, fallback_label));
		state.append(messages, str(gd::format(state, key::stack_is_status_format, { str(target_label), str(status_label) })));
	} else {
		append_result_message(state, messages, result);
	}
}

// _consume_retaliation and _consume_shot: stack[field] = max(0, int(stack.get(field, 0)) - 1)
// for the first stack with the battle id.
void consume_stack_count(State &state, DictRef battle, Atom battle_id, Atom field) {
	const Value stacks = field_or_new_array(state, battle, key::stacks);
	const int64_t count = untyped_size(state, stacks);
	for (int64_t index = 0; index < count; ++index) {
		const Value stack = untyped_at(state, stacks, index);
		if (gd::is_dict(stack) && stack_battle_id(state, stack.ref) == battle_id) {
			state.set(stack.ref, str(field), int_value(engine_max<int64_t>(0, gd::sub(gd::int_field(state, stack.ref, field, 0), 1))));
			untyped_set_at(state, stacks, index, stack);
			break;
		}
	}
	state.set(battle, str(key::stacks), stacks);
}

} // namespace

DictRef stack_strike_backs(State &state, DictRef battle, DictRef stack) {
	const bool staggered = spell_rules::has_effect_id(state, stack, battle, key::status_staggered);
	const int64_t left = staggered ? 0 : engine_max<int64_t>(0, gd::int_field(state, stack, key::retaliations_left, 0));
	const int64_t most = engine_max<int64_t>(0, gd::int_field(state, stack, key::retaliations, 0));
	const DictRef result = state.new_dict();
	state.set(result, str(key::left), int_value(left));
	state.set(result, str(key::max), int_value(most));
	state.set(result, str(key::blocked), bool_value(staggered));
	return result;
}

void _consume_retaliation(State &state, DictRef battle, Atom battle_id) {
	consume_stack_count(state, battle, battle_id, key::retaliations_left);
}

void _consume_shot(State &state, DictRef battle, Atom battle_id) {
	consume_stack_count(state, battle, battle_id, key::shots_remaining);
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

ArrayRef _apply_attack_ability_effects(State &state, DictRef battle, DictRef attacker, DictRef defender, bool is_ranged, int64_t attack_distance, DictRef defender_before) {
	const ArrayRef messages = state.new_array();
	const DictRef overheat = _ability_by_id(state, attacker, key::overheat);
	if (!gd::is_empty(state, overheat) && !is_ranged && !spell_rules::has_effect_id(state, attacker, battle, key::status_overheated)) {
		const Atom attacker_id = stack_battle_id(state, attacker);
		_apply_stack_effect(state, battle, attacker_id, dict_value(_status_effect_from_ability(state, overheat, battle)));
		state.append(messages, str(gd::format(state, key::overheat_vents_format, { str(_stack_label(state, attacker)) })));
	}
	const DictRef ability_uses = ability_uses_of(state, attacker);
	const DictRef hookline = _ability_by_id(state, attacker, key::hookline);
	const bool hookline_triggered = !is_ranged && attack_distance == 1 && !gd::is_empty(state, hookline) && _hookline_available(state, attacker, battle);
	if (hookline_triggered) {
		count_ability_use(state, attacker, ability_uses, key::hookline);
	}
	if (is_ranged) {
		append_array(state, messages, _apply_pressure_artillery(state, battle, attacker, defender));
		const DictRef mending_fire = _apply_sporeglass_mending_fire(state, battle, attacker);
		if (!gd::is_empty(state, mending_fire)) {
			state.append(messages, str(gd::string_field(state, mending_fire, key::message, key::empty)));
		}
		const DictRef readiness_writ = _apply_readiness_writ(state, battle, attacker);
		if (!gd::is_empty(state, readiness_writ)) {
			state.append(messages, str(gd::string_field(state, readiness_writ, key::message, key::empty)));
		}
	}
	const DictRef ambush_target = !gd::is_empty(state, defender_before) ? defender_before : defender;
	const DictRef ambush_context_target = !gd::is_empty(state, defender) ? defender : ambush_target;
	const DictRef backstab = _ability_by_id(state, attacker, key::backstab);
	bool backstab_ready = false;
	if (!gd::is_empty(state, backstab)) {
		backstab_ready = spell_rules::has_any_effect_ids(state, ambush_target, battle, field_or_new_array(state, backstab, key::status_ids));
		if (!backstab_ready) {
			const double health_ratio = _health_ratio(state, ambush_target);
			backstab_ready = health_ratio <= gd::float_field(state, backstab, key::health_threshold_ratio, 0.0);
		}
	}
	const DictRef backstab_flare = _counter_ambush_flare_context(state, battle, ambush_context_target, key::backstab);
	if (backstab_ready && !gd::is_empty(state, backstab_flare)) {
		const Atom backstab_name = gd::string_field(state, backstab, key::name, key::backstab_name);
		state.append(messages, str(_append_counter_ambush_flare_event(state, battle, backstab_flare, attacker, key::backstab, backstab_name)));
	}
	const DictRef fogwake = _ability_by_id(state, attacker, key::fogwake);
	const bool fogwake_ready = !is_ranged && !gd::is_empty(state, fogwake) && _stack_is_hex_isolated(state, battle, ambush_target);
	const DictRef fogwake_flare = fogwake_ready ? _counter_ambush_flare_context(state, battle, ambush_context_target, key::fogwake) : state.new_dict();
	if (fogwake_ready && !gd::is_empty(state, fogwake_flare) && flare_blocks_ambush_status(state, fogwake_flare)) {
		const Atom fogwake_name = gd::string_field(state, fogwake, key::name, key::fogwake_name);
		state.append(messages, str(_append_counter_ambush_flare_event(state, battle, fogwake_flare, attacker, key::fogwake, fogwake_name)));
	}
	if (gd::is_empty(state, defender) || _alive_count(state, defender) <= 0) {
		return messages;
	}
	if (!is_ranged && attack_distance > 1) {
		return messages;
	}
	if (hookline_triggered) {
		const bool pulled_into_contact = _apply_hookline_pull(state, battle, attacker, defender);
		const Atom defender_id = stack_battle_id(state, defender);
		const DictRef hookline_result = _apply_stack_effect(state, battle, defender_id, dict_value(_status_effect_from_ability(state, hookline, battle)));
		if (gd::bool_field(state, hookline_result, key::applied, false)) {
			const Atom defender_label = _stack_label(state, defender);
			const Atom pulled_clause = pulled_into_contact ? key::hookline_pulled_clause : key::empty;
			const Atom status_label = lower_text(state, gd::string_field(state, hookline, key::status_label, key::pinned_label));
			state.append(messages, str(gd::format(state, key::stack_is_status_clause_format, { str(defender_label), str(pulled_clause), str(status_label) })));
		} else {
			append_result_message(state, messages, hookline_result);
		}
	}
	const DictRef rot_cant = _ability_by_id(state, attacker, key::rot_cant);
	bool rot_target_ready = false;
	{
		const int64_t tier = gd::int_field(state, defender, key::tier, 1);
		rot_target_ready = tier >= gd::int_field(state, rot_cant, key::target_min_tier, 1);
	}
	bool rot_available = false;
	{
		const int64_t round = gd::int_field(state, battle, key::round, 1);
		if (round >= gd::int_field(state, rot_cant, key::available_from_round, 1) && rot_target_ready) {
			const int64_t used = gd::int_field(state, ability_uses, key::rot_cant, 0);
			rot_available = used < gd::int_field(state, rot_cant, key::uses_per_battle, 1);
		}
	}
	if (is_ranged && !gd::is_empty(state, rot_cant) && rot_available) {
		const Atom defender_id = stack_battle_id(state, defender);
		const DictRef rot_result = _apply_stack_effect(state, battle, defender_id, dict_value(_status_effect_from_ability(state, rot_cant, battle)));
		append_status_outcome(state, messages, rot_result, defender, rot_cant, key::rot_called_label);
		count_ability_use(state, attacker, ability_uses, key::rot_cant);
	}
	const DictRef harry = _ability_by_id(state, attacker, key::harry);
	const int64_t harry_limit = gd::int_field(state, harry, key::uses_per_battle, 0);
	const Atom harry_target_role = gd::string_field(state, harry, key::target_role, key::empty);
	bool harry_target_ready = false;
	{
		const int64_t tier = gd::int_field(state, defender, key::tier, 1);
		harry_target_ready = tier >= gd::int_field(state, harry, key::target_min_tier, 1);
	}
	if (harry_target_ready && harry_target_role != key::empty) {
		harry_target_ready = gd::bool_field(state, defender, key::ranged, false) == (harry_target_role == key::ranged);
	}
	bool harry_available = harry_target_ready && _harry_support_ready(state, attacker, defender, battle, harry);
	if (harry_available && harry_limit > 0) {
		harry_available = gd::int_field(state, ability_uses, key::harry, 0) < harry_limit;
	}
	if (!gd::is_empty(state, harry) && harry_available) {
		const Atom defender_id = stack_battle_id(state, defender);
		const DictRef harry_result = _apply_stack_effect(state, battle, defender_id, dict_value(_status_effect_from_ability(state, harry, battle)));
		append_status_outcome(state, messages, harry_result, defender, harry, key::harried_label);
		if (harry_limit > 0) {
			count_ability_use(state, attacker, ability_uses, key::harry);
		}
	}
	const DictRef obituary = _ability_by_id(state, attacker, key::obituary);
	bool obituary_available = false;
	{
		const int64_t used = gd::int_field(state, ability_uses, key::obituary, 0);
		obituary_available = used < gd::int_field(state, obituary, key::uses_per_battle, 1);
	}
	if (is_ranged && !gd::is_empty(state, obituary) && obituary_available) {
		const DictRef obituary_effect = _status_effect_from_ability(state, obituary, battle);
		bool braced_line = _brace_available(state, defender, battle);
		if (braced_line) {
			const int64_t tier = gd::int_field(state, defender, key::tier, 1);
			braced_line = tier >= gd::int_field(state, obituary, key::braced_target_min_tier, 2);
		}
		if (braced_line) {
			Value braced_modifiers;
			if (!state.lookup(obituary, str(key::braced_modifiers), braced_modifiers)) {
				braced_modifiers = dict_value(int_pair_dict(state, key::cohesion, -2, key::retaliation, -20));
			}
			state.set(obituary_effect, str(key::modifiers), dict_value(_normalize_ability_modifiers(state, braced_modifiers)));
		}
		const Atom defender_id = stack_battle_id(state, defender);
		_apply_stack_effect(state, battle, defender_id, dict_value(obituary_effect));
		count_ability_use(state, attacker, ability_uses, key::obituary);
		const Atom retaliation_clause = braced_line ? key::obituary_braced_clause : key::obituary_clause;
		const Atom defender_label = _stack_label(state, defender);
		const Atom status_label = lower_text(state, gd::string_field(state, obituary, key::status_label, key::obituary_marked_label));
		state.append(messages, str(gd::format(state, key::obituary_marked_format, { str(defender_label), str(status_label), str(retaliation_clause) })));
	}
	if (fogwake_ready) {
		if (gd::is_empty(state, fogwake_flare) || !flare_blocks_ambush_status(state, fogwake_flare)) {
			const Atom defender_id = stack_battle_id(state, defender);
			_apply_stack_effect(state, battle, defender_id, dict_value(_status_effect_from_ability(state, fogwake, battle)));
			const Atom defender_label = _stack_label(state, defender);
			const Atom status_label = lower_text(state, gd::string_field(state, fogwake, key::status_label, key::fogbound_label));
			state.append(messages, str(gd::format(state, key::fogwake_isolated_format, { str(defender_label), str(status_label) })));
		}
	}
	return messages;
}

ArrayRef _apply_retaliation_ability_effects(State &state, DictRef battle, DictRef retaliator, DictRef attacker) {
	const ArrayRef messages = state.new_array();
	if (gd::is_empty(state, attacker) || _alive_count(state, attacker) <= 0) {
		return messages;
	}
	DictRef retaliation_ability = _ability_by_id(state, retaliator, key::brace);
	if (gd::is_empty(state, retaliation_ability) || !_brace_available(state, retaliator, battle)) {
		retaliation_ability = _bramble_ground_ability(state, retaliator);
		if (gd::is_empty(state, retaliation_ability) || !_bramble_ground_available(state, retaliator, battle, retaliation_ability)) {
			return messages;
		}
	}
	if (!gd::bool_field(state, retaliator, key::defending, false)) {
		return messages;
	}
	const Atom attacker_id = stack_battle_id(state, attacker);
	const DictRef retaliation_result = _apply_stack_effect(state, battle, attacker_id, dict_value(_status_effect_from_ability(state, retaliation_ability, battle)));
	append_status_outcome(state, messages, retaliation_result, attacker, retaliation_ability, key::staggered_label);
	return messages;
}

DictRef _status_effect_from_ability(State &state, DictRef ability, DictRef battle) {
	// The arguments in their order.
	const Atom status_id = gd::string_field(state, ability, key::status_id, key::empty);
	const Atom status_label = gd::string_field(state, ability, key::status_label, key::status_title);
	Value modifiers;
	if (!state.lookup(ability, str(key::modifiers), modifiers)) {
		modifiers = dict_value(state.new_dict()); // the default {}
	}
	const int64_t duration_rounds = gd::int_field(state, ability, key::duration_rounds, 1);
	const Atom ability_id = gd::string_field(state, ability, key::id, key::empty);
	return spell_rules::build_battle_effect(state, status_id, status_label, modifiers, duration_rounds, battle, key::ability, ability_id, array_value(state.new_array()));
}

bool _apply_hookline_pull(State &state, DictRef battle, DictRef attacker, DictRef defender) {
	const DictRef attacker_cell = _stack_hex(state, attacker);
	const DictRef defender_cell = _stack_hex(state, defender);
	if (gd::is_empty(state, attacker_cell) || gd::is_empty(state, defender_cell) || _stack_hex_distance(state, attacker, defender) != 2) {
		return false;
	}
	const DictRef occupied = _build_blocking_map(state, battle);
	DictRef destination = state.new_dict();
	const bool single_hex_bodies = battle_footprint::width(state, attacker) == 1 && battle_footprint::width(state, defender) == 1;
	const ArrayRef candidates = _hex_neighbors(state, single_hex_bodies ? attacker_cell : defender_cell);
	for (const Value &candidate_value : gd::items(state, array_value(candidates))) {
		// Footprint.fits' anchor is a Dictionary parameter.
		const DictRef candidate = gd::as_dict(candidate_value);
		if (!battle_footprint::fits(state, defender, dict_value(candidate), occupied, BATTLE_HEX_COLUMNS, BATTLE_HEX_ROWS)
				|| battle_footprint::distance(state, defender, attacker, dict_value(candidate)) != 1) {
			continue;
		}
		if (_hex_distance(state, candidate, defender_cell) != 1) {
			continue;
		}
		destination = candidate;
		break;
	}
	if (gd::is_empty(state, destination)) {
		return false;
	}
	_set_stack_hex(state, battle, stack_battle_id(state, defender), destination);
	_sync_distance_from_hexes(state, battle);
	return true;
}

Atom _append_counter_ambush_flare_event(State &state, DictRef battle, DictRef flare_context, DictRef ambusher, Atom blocked_ability_id, Atom blocked_ability_name) {
	const DictRef source = dict_field_or_new(state, flare_context, key::source);
	const DictRef ability = dict_field_or_new(state, flare_context, key::ability);
	const DictRef current_ambusher = _get_stack_by_id(state, battle, stack_battle_id(state, ambusher));
	bool reveals_ambusher = false;
	{
		Value revealed_ability_ids;
		if (state.lookup(ability, str(key::revealed_ability_ids), revealed_ability_ids)) {
			reveals_ambusher = variant_has(state, revealed_ability_ids, str(blocked_ability_id));
		}
	}
	if (reveals_ambusher && !gd::is_empty(state, current_ambusher) && _alive_count(state, current_ambusher) > 0) {
		// The arguments in their order: the battle id before the effect's own.
		const Atom ambusher_id = stack_battle_id(state, current_ambusher);
		const Atom status_id = gd::string_field(state, ability, key::revealed_status_id, key::status_flare_revealed);
		const Atom status_label = gd::string_field(state, ability, key::revealed_status_label, key::flare_revealed_label);
		Value revealed_modifiers;
		if (!state.lookup(ability, str(key::revealed_modifiers), revealed_modifiers)) {
			revealed_modifiers = dict_value(int_pair_dict(state, key::defense, -1, key::initiative, -1));
		}
		const DictRef modifiers = _normalize_ability_modifiers(state, revealed_modifiers);
		const int64_t duration_rounds = engine_max<int64_t>(1, gd::int_field(state, ability, key::revealed_duration_rounds, 1));
		const DictRef effect = spell_rules::build_battle_effect(state, status_id, status_label, dict_value(modifiers), duration_rounds, battle, key::unit_ability, key::counter_ambush_flare, array_value(state.new_array()));
		_apply_stack_effect(state, battle, ambusher_id, dict_value(effect));
	}
	const Atom flare_name = gd::string_field(state, ability, key::name, key::counter_ambush_flare_name);
	// " and the attacker is %s" % String(...).to_lower() if reveals_ambusher else ""
	Atom revealed_clause = key::empty;
	if (reveals_ambusher) {
		const Atom revealed_label = lower_text(state, gd::string_field(state, ability, key::revealed_status_label, key::flare_revealed_label));
		revealed_clause = gd::format(state, key::attacker_revealed_clause_format, { str(revealed_label) });
	}
	const Atom message = gd::format(state, key::counter_ambush_flare_format, { str(flare_name), str(blocked_ability_name), str(revealed_clause) });
	const Atom event_type = reveals_ambusher ? key::debuff : key::ability;
	const DictRef context = state.new_dict();
	state.set(context, str(key::action_id), str(key::counter_ambush_flare));
	state.set(context, str(key::actor_battle_id), str(stack_battle_id(state, source)));
	state.set(context, str(key::target_battle_id), str(stack_battle_id(state, ambusher)));
	state.set(context, str(key::ability_id), str(key::counter_ambush_flare));
	_append_presentation_event(state, battle, event_type, message, context);
	return message;
}

} // namespace aurelion::rules::port::battle_rules
