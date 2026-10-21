#include "aurelion_rules/port/battle_ai_rules.hpp"

#include "aurelion_rules/port/battle_footprint.hpp"
#include "aurelion_rules/port/battle_rules.hpp"

#include <string>

namespace aurelion::rules::port::battle_ai_rules {

using compat::engine_clamp;
using compat::engine_max;
using compat::engine_min;
using compat::int_div;
using gd::array_value;
using gd::dict_value;
using gd::int_value;
using gd::str;
namespace key = state::key;
namespace rules = battle_rules;

namespace {

int64_t mul(int64_t a, int64_t b) {
	return static_cast<int64_t>(static_cast<uint64_t>(a) * static_cast<uint64_t>(b));
}

int64_t int_field(const State &state, DictRef dict, Atom field, int64_t fallback) {
	return gd::to_int(state, state.get(dict, str(field), int_value(fallback)));
}

Atom string_field(const State &state, DictRef dict, Atom field, Atom fallback) {
	return gd::to_string(state.get(dict, str(field), str(fallback)));
}

// The memos of one AI decision (_open_scoring_scope), GDScript's static vars.
bool scoring_scope_open(State &state) {
	return gd::to_int(state, gd::static_var(state, key::battle_ai_rules_script, key::_scoring_scope_depth)) > 0;
}

// _add_scoring_memo_entry(entries_by_key, key, entry)
void add_scoring_memo_entry(State &state, DictRef entries_by_key, Atom memo_key, ArrayRef entry) {
	Value entries;
	if (state.lookup(entries_by_key, str(memo_key), entries)) {
		state.append(gd::as_array(entries), array_value(entry));
		return;
	}
	const ArrayRef list = state.new_array();
	state.append(list, array_value(entry));
	state.set(entries_by_key, str(memo_key), array_value(list));
}

// _scoring_memo_entry(entries_by_key, key, first, second): the entry holding
// the same two dictionaries, or a new [].
ArrayRef scoring_memo_entry(State &state, DictRef entries_by_key, Atom memo_key, DictRef first, DictRef second) {
	for (const Value &entry : gd::field_items(state, entries_by_key, str(memo_key))) {
		const ArrayRef held = gd::as_array(entry);
		if (gd::is_same(state, state.at(held, 0), dict_value(first)) && gd::is_same(state, state.at(held, 1), dict_value(second))) {
			return held;
		}
	}
	return state.new_array();
}

// _stack_term_memo(term, stack, battle): [stack, battle, value] once worked
// out, else a new [stack, battle] that keep_stack_term completes; a new []
// outside a scope.
ArrayRef stack_term_memo(State &state, const char *term, DictRef stack, DictRef battle) {
	if (!scoring_scope_open(state)) {
		return state.new_array();
	}
	const Atom memo_key = state.intern(std::string(term) + "|" + state.text(string_field(state, stack, key::battle_id, key::empty)));
	const DictRef terms = gd::as_dict(gd::static_var(state, key::battle_ai_rules_script, key::_scoring_stack_terms));
	const ArrayRef entry = scoring_memo_entry(state, terms, memo_key, stack, battle);
	if (state.array_size(entry) > 0) {
		return entry;
	}
	const ArrayRef made = state.new_array();
	state.append(made, dict_value(stack));
	state.append(made, dict_value(battle));
	add_scoring_memo_entry(state, terms, memo_key, made);
	return made;
}

// _keep_stack_term(entry, value)
void keep_stack_term(State &state, ArrayRef entry, const Value &value) {
	if (state.array_size(entry) == 2) {
		state.append(entry, value);
	}
}

// _scoring_living_entry(battle, side): [stacks array, its living stacks of
// side, how many of them are not ranged]; a new [] outside a scope or without
// a stacks array.
ArrayRef scoring_living_entry(State &state, DictRef battle, Atom side) {
	if (!scoring_scope_open(state)) {
		return state.new_array();
	}
	Value stacks;
	if (!state.lookup(battle, str(key::stacks), stacks) || !gd::is_array(stacks)) {
		return state.new_array();
	}
	const DictRef living = gd::as_dict(gd::static_var(state, key::battle_ai_rules_script, key::_scoring_living));
	for (const Value &entry : gd::field_items(state, living, str(side))) {
		if (gd::is_same(state, state.at(gd::as_array(entry), 0), stacks)) {
			return gd::as_array(entry);
		}
	}
	const ArrayRef alive = _living_stacks_of_side(state, stacks, side);
	int64_t not_ranged = 0;
	for (const Value &stack : gd::items(state, array_value(alive))) {
		if (!gd::bool_field(state, gd::as_dict(stack), key::ranged, false)) {
			not_ranged += 1;
		}
	}
	const ArrayRef made = state.new_array();
	state.append(made, stacks);
	state.append(made, array_value(alive));
	state.append(made, int_value(not_ranged));
	add_scoring_memo_entry(state, living, side, made);
	return made;
}

} // namespace

int64_t _alive_count(const State &state, DictRef stack) {
	const int64_t unit_hp = engine_max<int64_t>(1, int_field(state, stack, key::unit_hp, 1));
	return int_div(engine_max<int64_t>(0, int_field(state, stack, key::total_health, 0)) + unit_hp - 1, unit_hp);
}

ArrayRef _alive_stacks_for_side(State &state, DictRef battle, Atom side) {
	const ArrayRef entry = scoring_living_entry(state, battle, side);
	if (state.array_size(entry) > 0) {
		return gd::as_array(state.at(entry, 1));
	}
	const ArrayRef none = state.new_array();
	return _living_stacks_of_side(state, state.get(battle, str(key::stacks), array_value(none)), side);
}

int64_t _distance_band_from_hex_distance(int64_t hex_distance) {
	return rules::_distance_band_from_hex_distance(hex_distance);
}

double _health_ratio(const State &state, DictRef stack) {
	const int64_t base_count = int_field(state, stack, key::base_count, 0);
	const int64_t max_health = engine_max<int64_t>(1, mul(base_count, engine_max<int64_t>(1, int_field(state, stack, key::unit_hp, 1))));
	const double health = static_cast<double>(engine_max<int64_t>(0, int_field(state, stack, key::total_health, 0)));
	return engine_clamp(health / static_cast<double>(max_health), 0.0, 1.0);
}

DictRef _hex_cell(State &state, int64_t q, int64_t r) {
	return rules::_hex_cell(state, q, r);
}

bool _hex_in_bounds(int64_t q, int64_t r) {
	return rules::_hex_in_bounds(q, r);
}

bool _is_same_stack(const State &state, DictRef lhs, DictRef rhs) {
	if (gd::is_empty(state, lhs) || string_field(state, lhs, key::battle_id, key::empty) == key::empty) {
		return false;
	}
	const Atom lhs_id = string_field(state, lhs, key::battle_id, key::empty);
	return lhs_id == string_field(state, rhs, key::battle_id, key::empty);
}

ArrayRef _living_stacks_of_side(State &state, const Value &stacks, Atom side) {
	const ArrayRef alive = state.new_array();
	for (const Value &stack : gd::items(state, stacks)) {
		if (gd::is_dict(stack) && string_field(state, stack.ref, key::side, key::empty) == side && _alive_count(state, stack.ref) > 0) {
			state.append(alive, stack);
		}
	}
	return alive;
}

DictRef _normalize_hex_cell(State &state, const Value &value) {
	return rules::_normalize_hex_cell(state, value);
}

Atom _opposing_side(Atom side) {
	return rules::_opposing_side(side);
}

ArrayRef _projected_on_cell(State &state, DictRef battle, DictRef stack, DictRef cell) {
	const DictRef projected = gd::duplicate_dict(state, stack);
	const int64_t q = int_field(state, cell, key::q, -1);
	const int64_t r = int_field(state, cell, key::r, -1);
	const DictRef projected_hex = state.new_dict();
	state.set(projected_hex, str(key::q), int_value(q));
	state.set(projected_hex, str(key::r), int_value(r));
	state.set(projected, str(key::hex), dict_value(projected_hex));
	const DictRef projected_battle = gd::duplicate_dict(state, battle);
	const ArrayRef stacks = state.new_array();
	for (const Value &other : gd::field_items(state, battle, str(key::stacks))) {
		const bool is_moving = gd::is_dict(other) && string_field(state, other.ref, key::battle_id, key::empty) == string_field(state, stack, key::battle_id, key::empty);
		state.append(stacks, is_moving ? dict_value(projected) : other);
	}
	state.set(projected_battle, str(key::stacks), array_value(stacks));
	const ArrayRef result = state.new_array();
	state.append(result, dict_value(projected));
	state.append(result, dict_value(projected_battle));
	return result;
}

DictRef _stack_by_battle_id(State &state, DictRef battle, Atom battle_id) {
	return rules::_get_stack_by_id(state, battle, battle_id);
}

int64_t _stack_contact_band(State &state, DictRef stack, DictRef battle) {
	const ArrayRef memo = stack_term_memo(state, "contact_band", stack, battle);
	if (state.array_size(memo) == 3) {
		return gd::to_int(state, state.at(memo, 2));
	}
	const int64_t value = _stack_contact_band_on(state, stack, battle);
	keep_stack_term(state, memo, int_value(value));
	return value;
}

int64_t _stack_contact_band_on(State &state, DictRef stack, DictRef battle) {
	int64_t nearest = 999;
	const ArrayRef enemies = _alive_stacks_for_side(state, battle, _opposing_side(string_field(state, stack, key::side, key::empty)));
	for (const Value &enemy : gd::items(state, array_value(enemies))) {
		nearest = engine_min<int64_t>(nearest, _stack_hex_distance(state, stack, gd::as_dict(enemy)));
	}
	if (nearest >= 999) {
		return int_field(state, battle, key::distance, 1);
	}
	return _distance_band_from_hex_distance(nearest);
}

bool _stack_engaged_on(State &state, DictRef stack, DictRef battle) {
	if (gd::is_empty(state, stack) || gd::is_empty(state, _stack_hex(state, stack))) {
		return false;
	}
	const ArrayRef enemies = _alive_stacks_for_side(state, battle, _opposing_side(string_field(state, stack, key::side, key::empty)));
	for (const Value &enemy : gd::items(state, array_value(enemies))) {
		if (_stack_hex_distance(state, stack, gd::as_dict(enemy)) <= 1) {
			return true;
		}
	}
	return false;
}

DictRef _stack_hex(State &state, DictRef stack) {
	return _normalize_hex_cell(state, state.get(stack, str(key::hex), Value()));
}

int64_t _stack_hex_distance(State &state, DictRef lhs, DictRef rhs) {
	return battle_footprint::distance(state, lhs, rhs, Value());
}

bool _stack_is_engaged(State &state, DictRef stack, DictRef battle) {
	const ArrayRef memo = stack_term_memo(state, "engaged", stack, battle);
	if (state.array_size(memo) == 3) {
		return gd::to_bool(state.at(memo, 2));
	}
	const bool value = _stack_engaged_on(state, stack, battle);
	keep_stack_term(state, memo, gd::bool_value(value));
	return value;
}

} // namespace aurelion::rules::port::battle_ai_rules
