// Layer 4: turn order: rounds, the turn order and its sort, waiting and the action availability.

#include "aurelion_rules/port/battle_rules.hpp"

#include "aurelion_rules/compat/godot_string.hpp"
#include "aurelion_rules/port/spell_rules.hpp"
#include "aurelion_rules/port/town_battle_rules.hpp"

#include <string>

namespace aurelion::rules::port::battle_rules {

using compat::engine_max;
using gd::array_value;
using gd::bool_value;
using gd::dict_value;
using gd::int_value;
using gd::str;
using state::Kind;
namespace key = state::key;

namespace {

// d.get(key, []) of an untyped result: the stored value, or a new empty Array
// when the key is missing.
Value turn_field_or_new_array(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return array_value(state.new_array());
}

// d.get(key, {}) of an untyped result: the stored value, or a new empty
// Dictionary when the key is missing.
Value turn_field_or_new_dict(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return dict_value(state.new_dict());
}

// var x: Array = d.get(key, []) if d.get(key, []) is Array else []: the stored
// Array itself, else a new empty one (a missing key's default [] is one).
ArrayRef turn_array_field_or_empty(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found) && gd::is_array(found)) {
		return found.ref;
	}
	return state.new_array();
}

// x.size() of an untyped value: an Array or a Dictionary has one; Nil, a
// number, a String or a bool has no size() method.
int64_t turn_untyped_size(const State &state, const Value &value) {
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
Value turn_untyped_at(const State &state, const Value &value, int64_t index) {
	if (value.kind == Kind::Array) {
		return state.at(value.ref, index);
	}
	if (value.kind == Kind::Dict) {
		return gd::index(state, value.ref, int_value(index));
	}
	throw state::ScriptError(std::string("Invalid access of index '") + compat::itos(index) + "' on a base object of type '" + gd::type_name(value) + "'.");
}

// x[index] = item of an untyped value with an int index.
void turn_untyped_set_at(State &state, const Value &value, int64_t index, const Value &item) {
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

// keys[id] passed to a typed Dictionary parameter.
DictRef turn_order_keys_of(const State &state, DictRef keys, const Value &id) {
	return gd::as_dict(gd::index(state, keys, id));
}

} // namespace

void _prepare_round(State &state, DictRef battle, int64_t round_number) {
	_ensure_battle_hex_state(state, battle);
	state.set(battle, str(key::round), int_value(round_number));
	const Value stacks = turn_field_or_new_array(state, battle, key::stacks);
	const int64_t count = turn_untyped_size(state, stacks);
	for (int64_t index = 0; index < count; ++index) {
		Value stack = turn_untyped_at(state, stacks, index);
		if (!gd::is_dict(stack)) {
			continue;
		}
		const int64_t expired_effect_count = _expired_stack_effect_count(state, stack.ref, round_number);
		stack = dict_value(spell_rules::purge_expired_stack_effects(state, stack.ref, round_number));
		state.set(stack.ref, str(key::defending), bool_value(false));
		state.set(stack.ref, str(key::retaliations_left), int_value(gd::int_field(state, stack.ref, key::retaliations, 1)));
		// Momentum a stack brings into the battle (visit-building boosts,
		// Fortune's Favour) lasts through the first round; it fades from round 2.
		if (round_number > 1) {
			// max(0, int - 1): ints.
			state.set(stack.ref, str(key::momentum), int_value(engine_max<int64_t>(0, gd::sub(gd::int_field(state, stack.ref, key::momentum, 0), 1))));
		}
		turn_untyped_set_at(state, stacks, index, stack);
		// A fallen stack's effects end unannounced: the event would stand it
		// up on the field again for its effect's end.
		if (expired_effect_count > 0 && _alive_count(state, stack.ref) > 0) {
			_mark_stack_animation_event(state, battle, gd::string_field(state, stack.ref, key::battle_id, key::empty), key::battle_status_expired, state.new_dict());
		}
	}
	state.set(battle, str(key::stacks), stacks);
	_apply_foundry_aura_round_repair(state, battle);
	// heal_round answers a new Array that nothing below writes.
	const ArrayRef healed = town_battle_rules::heal_round(state, battle);
	for (const Value &healing : gd::items(state, array_value(healed))) {
		const DictRef healing_dict = gd::as_dict(healing);
		const int64_t amount = gd::to_int(state, gd::index(state, healing_dict, str(key::amount)));
		const Atom label = _stack_label(state, gd::as_dict(gd::index(state, healing_dict, str(key::stack))));
		const Atom message = gd::format(state, state.intern("Rootbound Ward restores %d health to %s."), { int_value(amount), str(label) });
		_record_event(state, battle, message);
		// The literal's values in order: the action id, the target's battle id, the healing.
		const Atom target_battle_id = gd::string_field(state, gd::as_dict(gd::index(state, healing_dict, str(key::stack))), key::battle_id, key::empty);
		const int64_t healing_amount = gd::to_int(state, gd::index(state, healing_dict, str(key::amount)));
		const DictRef context = state.new_dict();
		state.set(context, str(key::action_id), str(state.intern("town_root_ward")));
		state.set(context, str(key::target_battle_id), str(target_battle_id));
		state.set(context, str(key::healing), int_value(healing_amount));
		_append_presentation_event(state, battle, state.intern("heal"), message, context);
	}
	_sync_occupied_hexes(state, battle);
	_sync_distance_from_hexes(state, battle);
	_apply_round_pressure_shifts(state, battle);
	state.set(battle, str(key::waited_stack_ids), array_value(state.new_array()));
	const ArrayRef sorted = _sorted_turn_order(state, battle);
	state.set(battle, str(key::turn_order), array_value(sorted));
	state.set(battle, str(key::turn_index), int_value(0));
	const Atom active_id = _advance_to_next_alive(state, battle, 0);
	state.set(battle, str(key::active_stack_id), str(active_id));
	_assign_default_target(state, battle);
	const DictRef active_stack = get_active_stack(state, battle);
	if (!gd::is_empty(state, active_stack)) {
		// The Array literal's items, in order.
		const int64_t round = gd::int_field(state, battle, key::round, 1);
		const Atom label = _stack_label(state, active_stack);
		const Atom side_label = _side_label(gd::string_field(state, active_stack, key::side, key::empty));
		_record_event(state, battle, gd::format(state, state.intern("Round %d begins. %s [%s] has the initiative."), { int_value(round), str(label), str(side_label) }));
	}
}

ArrayRef _sorted_turn_order(State &state, DictRef battle) {
	const ArrayRef candidates = state.new_array();
	// candidates is a new node: walking the stacks while it grows is safe.
	for (const Value &stack : gd::field_items(state, battle, str(key::stacks))) {
		if (!gd::is_dict(stack) || _alive_count(state, stack.ref) <= 0) {
			continue;
		}
		state.append(candidates, str(gd::string_field(state, stack.ref, key::battle_id, key::empty)));
	}

	// Initiative is resolved once per stack; the selection order below is
	// unchanged, so ties still fall back to speed, then player first.
	const DictRef keys = state.new_dict();
	const int64_t candidate_count = state.array_size(candidates);
	for (int64_t index = 0; index < candidate_count; ++index) {
		const Value battle_id = state.at(candidates, index);
		const DictRef stack = _get_stack_by_id(state, battle, gd::to_string(battle_id));
		// The literal's values in order: score, speed, player.
		const int64_t score = _stack_initiative_total(state, stack, battle);
		const int64_t speed = gd::int_field(state, stack, key::speed, 0);
		const bool player = gd::string_field(state, stack, key::side, key::empty) == key::player;
		const DictRef entry = state.new_dict();
		state.set(entry, str(key::score), int_value(score));
		state.set(entry, str(key::speed), int_value(speed));
		state.set(entry, str(key::player), bool_value(player));
		state.set(keys, battle_id, dict_value(entry));
	}
	const ArrayRef sorted = state.new_array();
	while (state.array_size(candidates) != 0) {
		int64_t best_index = 0;
		const int64_t size = state.array_size(candidates);
		for (int64_t index = 1; index < size; ++index) {
			const DictRef lhs = turn_order_keys_of(state, keys, state.at(candidates, index));
			const DictRef rhs = turn_order_keys_of(state, keys, state.at(candidates, best_index));
			if (_compare_stack_order_keys(state, lhs, rhs)) {
				best_index = index;
			}
		}
		state.append(sorted, state.at(candidates, best_index));
		gd::remove_at(state, candidates, best_index);
	}
	return sorted;
}

bool _compare_stack_order_keys(State &state, DictRef lhs, DictRef rhs) {
	const int64_t lhs_score = gd::to_int(state, gd::index(state, lhs, str(key::score)));
	const int64_t rhs_score = gd::to_int(state, gd::index(state, rhs, str(key::score)));
	if (lhs_score == rhs_score) {
		const int64_t lhs_speed = gd::to_int(state, gd::index(state, lhs, str(key::speed)));
		const int64_t rhs_speed = gd::to_int(state, gd::index(state, rhs, str(key::speed)));
		if (lhs_speed == rhs_speed) {
			const bool lhs_player = gd::to_bool(gd::index(state, lhs, str(key::player)));
			const bool rhs_player = gd::to_bool(gd::index(state, rhs, str(key::player)));
			if (lhs_player == rhs_player) {
				// Keys built for a re-sort carry each stack's previous place,
				// so equal stacks keep their order (sort_custom is not stable).
				const int64_t lhs_order = gd::int_field(state, lhs, key::order, 0);
				const int64_t rhs_order = gd::int_field(state, rhs, key::order, 0);
				return lhs_order < rhs_order;
			}
			return gd::to_bool(gd::index(state, lhs, str(key::player)));
		}
		const int64_t lhs_speed_again = gd::to_int(state, gd::index(state, lhs, str(key::speed)));
		const int64_t rhs_speed_again = gd::to_int(state, gd::index(state, rhs, str(key::speed)));
		return lhs_speed_again > rhs_speed_again;
	}
	const int64_t lhs_score_again = gd::to_int(state, gd::index(state, lhs, str(key::score)));
	const int64_t rhs_score_again = gd::to_int(state, gd::index(state, rhs, str(key::score)));
	return lhs_score_again > rhs_score_again;
}

bool _compare_waiting_order_keys(State &state, DictRef lhs, DictRef rhs) {
	const int64_t lhs_score = gd::to_int(state, gd::index(state, lhs, str(key::score)));
	const int64_t rhs_score = gd::to_int(state, gd::index(state, rhs, str(key::score)));
	if (lhs_score == rhs_score) {
		const int64_t lhs_speed = gd::to_int(state, gd::index(state, lhs, str(key::speed)));
		const int64_t rhs_speed = gd::to_int(state, gd::index(state, rhs, str(key::speed)));
		if (lhs_speed == rhs_speed) {
			const int64_t lhs_waited = gd::to_int(state, gd::index(state, lhs, str(key::waited)));
			const int64_t rhs_waited = gd::to_int(state, gd::index(state, rhs, str(key::waited)));
			return lhs_waited < rhs_waited;
		}
		const int64_t lhs_speed_again = gd::to_int(state, gd::index(state, lhs, str(key::speed)));
		const int64_t rhs_speed_again = gd::to_int(state, gd::index(state, rhs, str(key::speed)));
		return lhs_speed_again < rhs_speed_again;
	}
	const int64_t lhs_score_again = gd::to_int(state, gd::index(state, lhs, str(key::score)));
	const int64_t rhs_score_again = gd::to_int(state, gd::index(state, rhs, str(key::score)));
	return lhs_score_again < rhs_score_again;
}

Atom _advance_to_next_alive(State &state, DictRef battle, int64_t start_index) {
	Value turn_order;
	if (!state.lookup(battle, str(key::turn_order), turn_order)) {
		// The default [] is an Array with nothing to visit.
		return key::empty;
	}
	if (!gd::is_array(turn_order)) {
		return key::empty;
	}
	// max(0, int): an int.
	int64_t index = engine_max<int64_t>(0, start_index);
	while (index < state.array_size(turn_order.ref)) {
		const Atom battle_id = gd::to_string(state.at(turn_order.ref, index));
		const DictRef stack = _get_stack_by_id(state, battle, battle_id);
		if (!gd::is_empty(state, stack) && _alive_count(state, stack) > 0) {
			state.set(battle, str(key::turn_index), int_value(index));
			return battle_id;
		}
		index = gd::add(index, 1);
	}
	return key::empty;
}

void advance_turn(State &state, DictRef battle) {
	spend_effect_turns(state, battle, gd::string_field(state, battle, key::active_stack_id, key::empty));
	Value turn_order;
	const bool has_turn_order = state.lookup(battle, str(key::turn_order), turn_order);
	// A missing key's default [] is an empty Array.
	if (!has_turn_order || !gd::is_array(turn_order) || state.array_size(turn_order.ref) == 0) {
		_prepare_round(state, battle, engine_max<int64_t>(1, gd::int_field(state, battle, key::round, 1)));
		return;
	}

	const int64_t next_index = gd::add(gd::int_field(state, battle, key::turn_index, 0), 1);
	const Atom next_id = _advance_to_next_alive(state, battle, next_index);
	if (next_id == key::empty) {
		_prepare_round(state, battle, gd::add(gd::int_field(state, battle, key::round, 1), 1));
	} else {
		state.set(battle, str(key::turn_index), int_value(next_index));
		state.set(battle, str(key::active_stack_id), str(next_id));
	}
	_assign_default_target(state, battle);
}

void _resort_remaining_turn_order(State &state, DictRef battle) {
	const ArrayRef turn_order = turn_array_field_or_empty(state, battle, key::turn_order);
	const int64_t active_index = gd::array_find(state, turn_order, str(gd::string_field(state, battle, key::active_stack_id, key::empty)));
	if (active_index < 0 || active_index >= state.array_size(turn_order) - 2) {
		return;
	}
	const ArrayRef head = gd::slice(state, turn_order, 0, active_index + 1);
	const ArrayRef tail = gd::slice(state, turn_order, active_index + 1);
	const ArrayRef rest = _ordered_remaining_actors(state, battle, tail, Value());
	state.set(battle, str(key::turn_order), array_value(gd::concat(state, head, rest)));
}

ArrayRef _ordered_remaining_actors(State &state, DictRef battle, ArrayRef battle_ids, const Value &waited_override) {
	const ArrayRef waited = gd::is_array(waited_override) ? waited_override.ref : waited_stack_ids(state, battle);
	const DictRef keys = state.new_dict();
	const ArrayRef acting = state.new_array();
	const ArrayRef waiting = state.new_array();
	const int64_t count = state.array_size(battle_ids);
	for (int64_t index = 0; index < count; ++index) {
		const Atom battle_id = gd::to_string(state.at(battle_ids, index));
		const DictRef stack = _get_stack_by_id(state, battle, battle_id);
		// The literal's values in order: score, speed, player, order, waited.
		const int64_t score = !gd::is_empty(state, stack) ? _stack_initiative_total(state, stack, battle) : -999;
		const int64_t speed = gd::int_field(state, stack, key::speed, 0);
		const bool player = gd::string_field(state, stack, key::side, key::empty) == key::player;
		const int64_t waited_at = gd::array_find(state, waited, str(battle_id));
		const DictRef entry = state.new_dict();
		state.set(entry, str(key::score), int_value(score));
		state.set(entry, str(key::speed), int_value(speed));
		state.set(entry, str(key::player), bool_value(player));
		state.set(entry, str(key::order), int_value(index));
		state.set(entry, str(key::waited), int_value(waited_at));
		state.set(keys, str(battle_id), dict_value(entry));
		if (gd::array_has(state, waited, str(battle_id))) {
			state.append(waiting, str(battle_id));
		} else {
			state.append(acting, str(battle_id));
		}
	}
	gd::sort_custom(state, acting, [&state, keys](const Value &left, const Value &right) {
		const DictRef lhs = turn_order_keys_of(state, keys, left);
		const DictRef rhs = turn_order_keys_of(state, keys, right);
		return _compare_stack_order_keys(state, lhs, rhs);
	});
	gd::sort_custom(state, waiting, [&state, keys](const Value &left, const Value &right) {
		const DictRef lhs = turn_order_keys_of(state, keys, left);
		const DictRef rhs = turn_order_keys_of(state, keys, right);
		return _compare_waiting_order_keys(state, lhs, rhs);
	});
	return gd::concat(state, acting, waiting);
}

ArrayRef waited_stack_ids(State &state, DictRef battle) {
	return turn_array_field_or_empty(state, battle, key::waited_stack_ids);
}

bool stack_has_waited(State &state, DictRef battle, Atom battle_id) {
	return battle_id != key::empty && gd::array_has(state, waited_stack_ids(state, battle), str(battle_id));
}

bool can_wait(State &state, DictRef battle) {
	const DictRef active_stack = get_active_stack(state, battle);
	if (gd::is_empty(state, active_stack) || _alive_count(state, active_stack) <= 0) {
		return false;
	}
	return !stack_has_waited(state, battle, gd::string_field(state, active_stack, key::battle_id, key::empty));
}

void _apply_wait(State &state, DictRef battle) {
	const Atom active_id = gd::string_field(state, battle, key::active_stack_id, key::empty);
	// The stored Array's copy, else a new empty Array (a missing key's default
	// [] is an Array, and its copy is a new empty one).
	ArrayRef turn_order = 0;
	{
		Value found;
		if (state.lookup(battle, str(key::turn_order), found) && gd::is_array(found)) {
			turn_order = gd::duplicate_array(state, found.ref);
		} else {
			turn_order = state.new_array();
		}
	}
	const int64_t active_index = gd::array_find(state, turn_order, str(active_id));
	if (active_id == key::empty || active_index < 0) {
		return;
	}
	const ArrayRef waited = gd::duplicate_array(state, waited_stack_ids(state, battle));
	state.append(waited, str(active_id));
	state.set(battle, str(key::waited_stack_ids), array_value(waited));
	gd::remove_at(state, turn_order, active_index);
	const ArrayRef remaining = gd::slice(state, turn_order, active_index);
	state.append(remaining, str(active_id));
	const ArrayRef head = gd::slice(state, turn_order, 0, active_index);
	const ArrayRef rest = _ordered_remaining_actors(state, battle, remaining, Value());
	state.set(battle, str(key::turn_order), array_value(gd::concat(state, head, rest)));
	// Never empty: the waiting stack itself is still to act.
	const Atom next_id = _advance_to_next_alive(state, battle, active_index);
	state.set(battle, str(key::active_stack_id), str(next_id));
	_assign_default_target(state, battle);
}

int64_t _opposing_stacks_still_to_act(State &state, DictRef battle, DictRef stack) {
	const ArrayRef turn_order = turn_array_field_or_empty(state, battle, key::turn_order);
	const Atom side = gd::string_field(state, stack, key::side, key::empty);
	int64_t count = 0;
	// range(begin, end): both bounds evaluated once.
	const int64_t begin = gd::add(gd::array_find(state, turn_order, str(gd::string_field(state, stack, key::battle_id, key::empty))), 1);
	const int64_t end = state.array_size(turn_order);
	for (int64_t index = begin; index < end; ++index) {
		const DictRef other = _get_stack_by_id(state, battle, gd::to_string(state.at(turn_order, index)));
		if (_alive_count(state, other) > 0 && gd::string_field(state, other, key::side, key::empty) != side) {
			count += 1;
		}
	}
	return count;
}

int64_t _stacks_ahead_after_wait(State &state, DictRef battle, Atom battle_id) {
	const ArrayRef turn_order = turn_array_field_or_empty(state, battle, key::turn_order);
	const int64_t index = gd::array_find(state, turn_order, str(battle_id));
	if (battle_id == key::empty || index < 0) {
		return 0;
	}
	const ArrayRef remaining = gd::slice(state, turn_order, index + 1);
	state.append(remaining, str(battle_id));
	const ArrayRef waited = gd::duplicate_array(state, waited_stack_ids(state, battle));
	state.append(waited, str(battle_id));
	int64_t ahead = 0;
	// A new Array that nothing below writes.
	const ArrayRef ordered = _ordered_remaining_actors(state, battle, remaining, array_value(waited));
	for (const Value &other_id : gd::items(state, array_value(ordered))) {
		if (gd::to_string(other_id) == battle_id) {
			break;
		}
		if (_alive_count(state, _get_stack_by_id(state, battle, gd::to_string(other_id))) > 0) {
			ahead += 1;
		}
	}
	return ahead;
}

Atom _resolve_wait(State &state, DictRef battle, DictRef active_stack) {
	const Atom battle_id = gd::string_field(state, active_stack, key::battle_id, key::empty);
	const int64_t ahead = _stacks_ahead_after_wait(state, battle, battle_id);
	Atom message = gd::format(state, state.intern("%s waits."), { str(_stack_label(state, active_stack)) });
	if (ahead > 0) {
		// The Array literal's items, in order.
		const Atom label = _stack_label(state, active_stack);
		const Atom plural = ahead == 1 ? key::empty : state.intern("s");
		const Atom verb_suffix = ahead == 1 ? state.intern("s") : key::empty;
		message = gd::format(state, state.intern("%s waits; %d stack%s act%s first."), { str(label), int_value(ahead), str(plural), str(verb_suffix) });
	}
	_mark_stack_animation_event(state, battle, battle_id, key::battle_unit_wait, state.new_dict());
	_apply_wait(state, battle);
	const DictRef context = state.new_dict();
	state.set(context, str(key::action_id), str(key::wait));
	state.set(context, str(key::actor_battle_id), str(battle_id));
	_append_presentation_event(state, battle, key::wait, message, context);
	return message;
}

bool _battle_retreat_allowed(State &state, DictRef battle) {
	if (gd::is_empty(state, battle) || _is_town_defense_context(state, turn_field_or_new_dict(state, battle, key::context))) {
		return false;
	}
	return gd::bool_field(state, battle, key::retreat_allowed, true);
}

bool _battle_surrender_allowed(State &state, DictRef battle) {
	if (gd::is_empty(state, battle) || _is_town_defense_context(state, turn_field_or_new_dict(state, battle, key::context))) {
		return false;
	}
	return gd::bool_field(state, battle, key::surrender_allowed, true);
}

DictRef action_availability(State &state, DictRef battle) {
	const DictRef active_stack = get_active_stack(state, battle);
	const DictRef selected_target = get_selected_target(state, battle);
	if (gd::is_empty(state, active_stack)) {
		const DictRef none = state.new_dict();
		state.set(none, str(key::advance), bool_value(false));
		state.set(none, str(key::strike), bool_value(false));
		state.set(none, str(key::shoot), bool_value(false));
		state.set(none, str(key::defend), bool_value(false));
		state.set(none, str(key::wait), bool_value(false));
		state.set(none, str(key::retreat), bool_value(false));
		state.set(none, str(key::surrender), bool_value(false));
		return none;
	}

	// The literal's values in order, each and/or short-circuiting.
	const bool advance = !_stack_is_rooted(state, active_stack, battle)
			&& (_advance_stalled_by_obstruction(state, active_stack, battle)
					|| !(state.array_size(legal_destinations_for_active_stack(state, battle)) == 0));
	const bool strike = !gd::is_empty(state, selected_target) && _can_melee_this_action(state, active_stack, battle, selected_target);
	const bool shoot = !gd::is_empty(state, selected_target) && _can_make_ranged_attack(state, active_stack, battle, selected_target);
	const bool wait = can_wait(state, battle);
	const bool retreat = _battle_retreat_allowed(state, battle);
	const bool surrender = _battle_surrender_allowed(state, battle);
	const DictRef availability = state.new_dict();
	state.set(availability, str(key::advance), bool_value(advance));
	state.set(availability, str(key::strike), bool_value(strike));
	state.set(availability, str(key::shoot), bool_value(shoot));
	state.set(availability, str(key::defend), bool_value(true));
	state.set(availability, str(key::wait), bool_value(wait));
	state.set(availability, str(key::retreat), bool_value(retreat));
	state.set(availability, str(key::surrender), bool_value(surrender));
	return availability;
}

} // namespace aurelion::rules::port::battle_rules
