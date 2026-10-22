// Layer 4: stack effects: applying, spending, expiring and cleansing effects, defending and the readiness writ.

#include "aurelion_rules/port/battle_rules.hpp"
#include "aurelion_rules/port/spell_rules.hpp"

#include "aurelion_rules/compat/godot_string.hpp"

#include <initializer_list>
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

// `d.get(field, []) if d.get(field, []) is Array else []`: the stored Array, or
// a new empty one when the key is missing or holds something else.
ArrayRef array_field_or_new(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, gd::str(field), found) && found.kind == Kind::Array) {
		return found.ref;
	}
	return state.new_array();
}

// var x: Array = value: an Array assigns as it is. Nil and the other modelled
// types do not convert to Array (Variant::can_convert_strict); a packed array
// would convert, which is not ported.
ArrayRef assign_array(const Value &value) {
	if (value.kind == Kind::Array) {
		return value.ref;
	}
	if (value.kind == Kind::Opaque) {
		throw state::ScriptError("Assigning an opaque value (a packed array) to an Array variable is not ported");
	}
	throw state::ScriptError(std::string("Trying to assign value of type '") + gd::type_name(value) + "' to a variable of type 'Array'.");
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
// container (a property check) or a packed array is not ported; anything else
// is the engine's invalid-operands error (gd::in).
bool string_in(State &state, Atom value, const Value &container) {
	if (container.is_string_like()) {
		return string_contains(state.text(container.ref), state.text(value));
	}
	if (container.kind == Kind::Opaque) {
		throw state::ScriptError("String in an opaque Variant (an Object, a packed array) is not ported");
	}
	return gd::in(state, gd::str(value), container);
}

} // namespace

} // namespace aurelion::rules::port

namespace aurelion::rules::port::battle_rules {

using gd::array_value;
using gd::bool_value;
using gd::dict_value;
using gd::int_value;
using gd::str;

namespace {

// [STATUS_STAGGERED, STATUS_HARRIED]: a new untyped Array on every evaluation.
ArrayRef staggered_or_harried(State &state) {
	const ArrayRef array = state.new_array();
	state.append(array, str(key::status_staggered));
	state.append(array, str(key::status_harried));
	return array;
}

// incoming_effect_id.trim_prefix("status_").replace("_", " ")
Atom status_words(State &state, Atom incoming_effect_id) {
	const Atom trimmed = gd::trim_prefix(state, incoming_effect_id, state.intern("status_"));
	return gd::replace(state, trimmed, state.intern("_"), state.intern(" "));
}

// The readiness writ block's context literal: {"action_id": "readiness_writ_block",
// "actor_battle_id": String(source.get("battle_id", "")), "target_battle_id":
// battle_id, <status_key>: incoming_effect_id}.
DictRef readiness_block_context(State &state, DictRef source, Atom battle_id, Atom status_key, Atom incoming_effect_id) {
	const DictRef context = state.new_dict();
	state.set(context, str(key::action_id), str(key::readiness_writ_block));
	state.set(context, str(key::actor_battle_id), str(gd::string_field(state, source, key::battle_id, key::empty)));
	state.set(context, str(key::target_battle_id), str(battle_id));
	state.set(context, str(status_key), str(incoming_effect_id));
	return context;
}

// {"blocked": true, "message": visible_text}
DictRef readiness_block_result(State &state, Atom visible_text) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::blocked), bool_value(true));
	state.set(result, str(key::message), str(visible_text));
	return result;
}

// String(lhs.get(lhs_key, lhs_fallback)) != String(rhs.get(rhs_key, rhs_fallback)), the left operand first.
bool string_fields_differ(const State &state, DictRef lhs, Atom lhs_key, Atom lhs_fallback, DictRef rhs, Atom rhs_key, Atom rhs_fallback) {
	const Atom left = gd::string_field(state, lhs, lhs_key, lhs_fallback);
	const Atom right = gd::string_field(state, rhs, rhs_key, rhs_fallback);
	return left != right;
}

// int(lhs.get(lhs_key, 1)) < int(rhs.get(rhs_key, 1)), the left operand first.
bool int_field_less(const State &state, DictRef lhs, Atom lhs_key, DictRef rhs, Atom rhs_key) {
	const int64_t left = gd::int_field(state, lhs, lhs_key, 1);
	const int64_t right = gd::int_field(state, rhs, rhs_key, 1);
	return left < right;
}

} // namespace

DictRef _apply_stack_effect(State &state, DictRef battle, Atom battle_id, const Value &effect_payload) {
	if (!gd::is_dict(effect_payload)) {
		return state.new_dict();
	}
	const DictRef payload = effect_payload.ref;
	const Atom effect_id = gd::string_field(state, payload, key::effect_id, key::empty);
	const Value stacks = field_or_new_array(state, battle, key::stacks);
	const int64_t count = untyped_size(state, stacks);
	for (int64_t index = 0; index < count; ++index) {
		const Value stack_value = untyped_at(state, stacks, index);
		if (!gd::is_dict(stack_value) || gd::string_field(state, stack_value.ref, key::battle_id, key::empty) != battle_id) {
			continue;
		}
		// Ability statuses obey the same innate and active-effect immunities as
		// spells. An immune target must not spend a one-use readiness ward.
		if (spell_rules::target_is_immune_to_status(state, stack_value.ref, battle, effect_id)) {
			const Atom stack_label = _stack_label(state, stack_value.ref);
			const Atom effect_label = gd::string_field(state, payload, key::label, effect_id);
			const Atom message = gd::format(state, state.intern("%s is immune to %s."), { str(stack_label), str(effect_label) });
			const DictRef result = state.new_dict();
			state.set(result, str(key::applied), bool_value(false));
			state.set(result, str(key::immune), bool_value(true));
			state.set(result, str(key::blocked), bool_value(true));
			state.set(result, str(key::blocked_status_id), str(effect_id));
			state.set(result, str(key::message), str(message));
			return result;
		}
		const DictRef readiness_block = _consume_readiness_writ_preparation(state, battle, battle_id, effect_id);
		if (!gd::is_empty(state, readiness_block)) {
			return readiness_block;
		}
		const DictRef stack = spell_rules::normalize_stack_effects(state, stack_value.ref);
		// normalize_stack_effects stored an Array under "effects".
		const ArrayRef effects = gd::as_array(field_or_new_array(state, stack, key::effects));
		const Atom kind = gd::string_field(state, payload, key::kind, key::empty);
		for (int64_t effect_index = state.array_size(effects) - 1; effect_index > -1; --effect_index) {
			const Value existing = state.at(effects, effect_index);
			if (!gd::is_dict(existing)) {
				continue;
			}
			const bool same_effect_id = effect_id != key::empty && gd::string_field(state, existing.ref, key::effect_id, key::empty) == effect_id;
			const bool same_legacy_kind = effect_id == key::empty && kind != key::empty && gd::string_field(state, existing.ref, key::kind, key::empty) == kind;
			if (same_effect_id || same_legacy_kind) {
				gd::remove_at(state, effects, effect_index);
			}
		}
		const DictRef added = gd::deep_duplicate_dict(state, payload);
		if (state.has(added, str(key::turns_left)) && battle_id == gd::string_field(state, battle, key::active_stack_id, key::empty)) {
			state.set(added, str(key::skip_current_turn), bool_value(true));
		}
		state.append(effects, dict_value(added));
		state.set(stack, str(key::effects), array_value(effects));
		untyped_set_at(state, stacks, index, dict_value(stack));
		state.set(battle, str(key::stacks), stacks);
		_resort_remaining_turn_order(state, battle);
		const DictRef result = state.new_dict();
		state.set(result, str(key::applied), bool_value(true));
		return result;
	}
	state.set(battle, str(key::stacks), stacks);
	return state.new_dict();
}

void spend_effect_turns(State &state, DictRef battle, Atom battle_id) {
	if (battle_id == key::empty) {
		return;
	}
	const ArrayRef stacks = assign_array(field_or_new_array(state, battle, key::stacks));
	const int64_t count = state.array_size(stacks);
	for (int64_t index = 0; index < count; ++index) {
		const Value stack = state.at(stacks, index);
		if (!gd::is_dict(stack) || gd::string_field(state, stack.ref, key::battle_id, key::empty) != battle_id) {
			continue;
		}
		const ArrayRef kept = state.new_array();
		bool changed = false;
		// The loop writes only kept and the new copies, never the walked container.
		for (const Value &effect : gd::field_items(state, stack.ref, str(key::effects))) {
			if (!gd::is_dict(effect) || !state.has(effect.ref, str(key::turns_left))) {
				state.append(kept, effect);
				continue;
			}
			changed = true;
			const DictRef updated = gd::deep_duplicate_dict(state, effect.ref);
			if (gd::bool_field(state, updated, key::skip_current_turn, false)) {
				state.erase(updated, str(key::skip_current_turn));
			} else {
				state.set(updated, str(key::turns_left), int_value(gd::sub(gd::int_field(state, updated, key::turns_left, 1), 1)));
			}
			if (gd::int_field(state, updated, key::turns_left, 0) > 0) {
				state.append(kept, dict_value(updated));
			}
		}
		if (changed) {
			state.set(stack.ref, str(key::effects), array_value(kept));
			state.set_at(stacks, index, stack);
			state.set(battle, str(key::stacks), array_value(stacks));
		}
		return;
	}
}

int64_t _expired_stack_effect_count(State &state, DictRef stack, int64_t round_number) {
	int64_t expired = 0;
	const DictRef normalized_stack = spell_rules::normalize_stack_effects(state, gd::deep_duplicate_dict(state, stack));
	const ArrayRef effects = array_field_or_new(state, normalized_stack, key::effects);
	for (const Value &effect : gd::items(state, array_value(effects))) {
		if (gd::is_dict(effect) && gd::int_field(state, effect.ref, key::expires_after_round, 0) < round_number) {
			expired = gd::add(expired, 1);
		}
	}
	return expired;
}

int64_t _cleanse_stack_effects(State &state, DictRef battle, Atom battle_id, const Value &effect_ids) {
	const ArrayRef cleanse_ids = state.new_array();
	if (gd::is_array(effect_ids)) {
		for (const Value &effect_id : gd::items(state, effect_ids)) {
			const Atom normalized_id = gd::to_string(effect_id);
			if (normalized_id != key::empty && !gd::array_has(state, cleanse_ids, str(normalized_id))) {
				state.append(cleanse_ids, str(normalized_id));
			}
		}
	}
	if (state.array_size(cleanse_ids) == 0) {
		return 0;
	}
	int64_t removed = 0;
	const Value stacks = field_or_new_array(state, battle, key::stacks);
	const int64_t count = untyped_size(state, stacks);
	for (int64_t index = 0; index < count; ++index) {
		const Value stack_value = untyped_at(state, stacks, index);
		if (!gd::is_dict(stack_value) || gd::string_field(state, stack_value.ref, key::battle_id, key::empty) != battle_id) {
			continue;
		}
		const DictRef stack = spell_rules::normalize_stack_effects(state, stack_value.ref);
		// normalize_stack_effects stored an Array under "effects".
		const ArrayRef effects = gd::as_array(field_or_new_array(state, stack, key::effects));
		for (int64_t effect_index = state.array_size(effects) - 1; effect_index > -1; --effect_index) {
			const Value effect = state.at(effects, effect_index);
			if (gd::is_dict(effect) && gd::array_has(state, cleanse_ids, str(gd::string_field(state, effect.ref, key::effect_id, key::empty)))) {
				gd::remove_at(state, effects, effect_index);
				removed = gd::add(removed, 1);
			}
		}
		state.set(stack, str(key::effects), array_value(effects));
		untyped_set_at(state, stacks, index, dict_value(stack));
		break;
	}
	state.set(battle, str(key::stacks), stacks);
	return removed;
}

void _set_stack_defending(State &state, DictRef battle, Atom battle_id) {
	const Value stacks = field_or_new_array(state, battle, key::stacks);
	const int64_t count = untyped_size(state, stacks);
	for (int64_t index = 0; index < count; ++index) {
		const Value stack = untyped_at(state, stacks, index);
		if (gd::is_dict(stack) && gd::string_field(state, stack.ref, key::battle_id, key::empty) == battle_id) {
			state.set(stack.ref, str(key::defending), bool_value(true));
			untyped_set_at(state, stacks, index, stack);
			break;
		}
	}
	state.set(battle, str(key::stacks), stacks);
}

DictRef _consume_readiness_writ_preparation(State &state, DictRef battle, Atom battle_id, Atom incoming_effect_id) {
	if (incoming_effect_id == key::empty) {
		return state.new_dict();
	}
	const Value stacks = field_or_new_array(state, battle, key::stacks);
	const DictRef target = _get_stack_by_id(state, battle, battle_id);
	if (gd::is_empty(state, target)) {
		return state.new_dict();
	}
	const int64_t count = untyped_size(state, stacks);
	for (int64_t index = 0; index < count; ++index) {
		const Value source_value = untyped_at(state, stacks, index);
		if (!gd::is_dict(source_value) || string_fields_differ(state, source_value.ref, key::side, key::empty, target, key::side, key::empty)) {
			continue;
		}
		const DictRef source = spell_rules::normalize_stack_effects(state, source_value.ref);
		const ArrayRef effects = array_field_or_new(state, source, key::effects);
		for (int64_t effect_index = state.array_size(effects) - 1; effect_index > -1; --effect_index) {
			const Value effect = state.at(effects, effect_index);
			if (!gd::is_dict(effect) || gd::string_field(state, effect.ref, key::effect_id, key::empty) != key::status_readiness_prepared) {
				continue;
			}
			const ArrayRef blocked_status_ids = array_field_or_new(state, effect.ref, key::blocked_status_ids);
			if (!gd::array_has(state, blocked_status_ids, str(incoming_effect_id))) {
				continue;
			}
			if (gd::string_field(state, effect.ref, key::protected_side, key::empty) != key::empty
					&& string_fields_differ(state, effect.ref, key::protected_side, key::empty, target, key::side, key::empty)) {
				continue;
			}
			if (gd::string_field(state, effect.ref, key::target_role, key::empty) != key::empty
					&& string_fields_differ(state, effect.ref, key::target_role, key::empty, target, key::role, key::melee)) {
				continue;
			}
			if (int_field_less(state, target, key::tier, effect.ref, key::target_min_tier)) {
				continue;
			}
			gd::remove_at(state, effects, effect_index);
			state.set(source, str(key::effects), array_value(effects));
			untyped_set_at(state, stacks, index, dict_value(source));
			state.set(battle, str(key::stacks), stacks);
			const Atom target_label = _stack_label(state, target);
			const Atom status_text = status_words(state, incoming_effect_id);
			const Atom visible_text = gd::format(state, state.intern("%s holds formation under Beacon Muster and resists %s."), { str(target_label), str(status_text) });
			_mark_stack_animation_event(state, battle, battle_id, key::battle_status_expired, readiness_block_context(state, source, battle_id, key::effect_id, incoming_effect_id));
			_append_presentation_event(state, battle, key::guard, visible_text, readiness_block_context(state, source, battle_id, key::prevented_status_id, incoming_effect_id));
			return readiness_block_result(state, visible_text);
		}
	}
	const int64_t second_count = untyped_size(state, stacks);
	for (int64_t index = 0; index < second_count; ++index) {
		const Value source_value = untyped_at(state, stacks, index);
		if (!gd::is_dict(source_value) || _alive_count(state, source_value.ref) <= 0
				|| string_fields_differ(state, source_value.ref, key::side, key::empty, target, key::side, key::empty)) {
			continue;
		}
		const DictRef source = source_value.ref;
		const DictRef readiness_writ = _readiness_writ_ability(state, source);
		if (gd::is_empty(state, readiness_writ)) {
			continue;
		}
		{
			// incoming_effect_id not in readiness_writ.get("cleansed_status_ids", []):
			// the default [] holds nothing.
			Value cleansed_status_ids;
			if (!state.lookup(readiness_writ, str(key::cleansed_status_ids), cleansed_status_ids)
					|| !string_in(state, incoming_effect_id, cleansed_status_ids)) {
				continue;
			}
		}
		if (gd::string_field(state, readiness_writ, key::preparation_target_role, key::empty) != key::empty
				&& string_fields_differ(state, readiness_writ, key::preparation_target_role, key::empty, target, key::role, key::melee)) {
			continue;
		}
		if (int_field_less(state, target, key::tier, readiness_writ, key::preparation_target_min_tier)) {
			continue;
		}
		// var ability_uses = source.get("ability_uses", {}); a missing or
		// non-Dictionary value becomes a new {}.
		Value ability_uses_value;
		if (!state.lookup(source, str(key::ability_uses), ability_uses_value) || !gd::is_dict(ability_uses_value)) {
			ability_uses_value = dict_value(state.new_dict());
		}
		const DictRef ability_uses = ability_uses_value.ref;
		{
			const int64_t used = gd::int_field(state, ability_uses, key::readiness_writ, 0);
			if (used >= gd::int_field(state, readiness_writ, key::uses_per_battle, 1)) {
				continue;
			}
		}
		state.set(ability_uses, str(key::readiness_writ), int_value(gd::add(gd::int_field(state, ability_uses, key::readiness_writ, 0), 1)));
		state.set(source, str(key::ability_uses), dict_value(ability_uses));
		untyped_set_at(state, stacks, index, dict_value(source));
		state.set(battle, str(key::stacks), stacks);
		const Atom source_label = _stack_label(state, source);
		const Atom target_label = _stack_label(state, target);
		const Atom status_text = status_words(state, incoming_effect_id);
		const Atom visible_text = gd::format(state, state.intern("%s calls Beacon Muster and %s resists %s."), { str(source_label), str(target_label), str(status_text) });
		_mark_stack_animation_event(state, battle, battle_id, key::battle_status_expired, readiness_block_context(state, source, battle_id, key::effect_id, incoming_effect_id));
		_append_presentation_event(state, battle, key::guard, visible_text, readiness_block_context(state, source, battle_id, key::prevented_status_id, incoming_effect_id));
		return readiness_block_result(state, visible_text);
	}
	return state.new_dict();
}

DictRef _readiness_writ_ability(State &state, DictRef stack) {
	return _authored_ability_by_id(state, stack, key::readiness_writ);
}

DictRef _weakest_stack_by_cohesion(State &state, DictRef battle, Atom side) {
	DictRef weakest = state.new_dict();
	int64_t weakest_score = 99999;
	const ArrayRef alive = _alive_stacks_for_side(state, battle, side);
	for (const Value &stack_value : gd::items(state, array_value(alive))) {
		const DictRef stack = gd::as_dict(stack_value);
		int64_t score = _stack_cohesion_total(state, stack, battle);
		if (_stack_is_isolated(state, battle, stack)) {
			score = gd::sub(score, 1);
		}
		if (spell_rules::has_any_effect_ids(state, stack, battle, array_value(staggered_or_harried(state)))) {
			score = gd::sub(score, 1);
		}
		if (gd::is_empty(state, weakest) || score < weakest_score) {
			weakest = stack;
			weakest_score = score;
		}
	}
	return weakest;
}

DictRef _weakest_stack_by_role(State &state, DictRef battle, Atom side, bool prefer_ranged) {
	DictRef weakest = state.new_dict();
	int64_t weakest_score = 99999;
	const ArrayRef alive = _alive_stacks_for_side(state, battle, side);
	for (const Value &stack_value : gd::items(state, array_value(alive))) {
		const DictRef stack = gd::as_dict(stack_value);
		if (gd::bool_field(state, stack, key::ranged, false) != prefer_ranged) {
			continue;
		}
		int64_t score = _stack_cohesion_total(state, stack, battle);
		if (_stack_is_isolated(state, battle, stack)) {
			score = gd::sub(score, 1);
		}
		if (spell_rules::has_any_effect_ids(state, stack, battle, array_value(staggered_or_harried(state)))) {
			score = gd::sub(score, 1);
		}
		if (gd::is_empty(state, weakest) || score < weakest_score) {
			weakest = stack;
			weakest_score = score;
		}
	}
	if (gd::is_empty(state, weakest)) {
		return _weakest_stack_by_cohesion(state, battle, side);
	}
	return weakest;
}

} // namespace aurelion::rules::port::battle_rules

namespace aurelion::rules::port::spell_rules {

using gd::array_value;
using gd::str;

ArrayRef stack_status_immunity_ids(State &state, DictRef stack, DictRef battle) {
	// A missing key's default [] normalizes as Nil does, to a new empty Array.
	const ArrayRef ids = normalize_status_immunity_ids(state, gd::field(state, stack, key::status_immunity_ids));
	const int64_t current_round = gd::int_field(state, battle, key::round, 1);
	const ArrayRef active = active_effects_for_round(state, stack, current_round);
	for (const Value &effect : gd::items(state, array_value(active))) {
		const ArrayRef effect_ids = normalize_status_immunity_ids(state, gd::field(state, gd::as_dict(effect), key::status_immunity_ids));
		for (const Value &status_id : gd::items(state, array_value(effect_ids))) {
			if (!gd::array_has(state, ids, status_id)) {
				state.append(ids, status_id);
			}
		}
	}
	return ids;
}

bool target_is_immune_to_status(State &state, DictRef target_stack, DictRef battle, Atom status_id) {
	return status_id != key::empty && gd::array_has(state, stack_status_immunity_ids(state, target_stack, battle), str(status_id));
}

DictRef normalize_stack_effects(State &state, DictRef stack) {
	// A missing key's default [] normalizes as Nil does, to a new empty Array.
	const ArrayRef effects = _normalize_effects(state, gd::field(state, stack, key::effects));
	state.set(stack, str(key::effects), array_value(effects));
	return stack;
}

DictRef purge_expired_stack_effects(State &state, DictRef stack, int64_t round_number) {
	const ArrayRef active = state.new_array();
	// A missing key's default [] normalizes as Nil does, to a new empty Array.
	const ArrayRef normalized = _normalize_effects(state, gd::field(state, stack, key::effects));
	for (const Value &effect : gd::items(state, array_value(normalized))) {
		if (gd::int_field(state, gd::as_dict(effect), key::expires_after_round, 0) >= round_number) {
			state.append(active, effect);
		}
	}
	state.set(stack, str(key::effects), array_value(active));
	return stack;
}

} // namespace aurelion::rules::port::spell_rules
