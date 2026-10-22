// Layer 3: the board setup: deployment hexes, the hex state of a battle, moving a stack and its walk path.

#include "aurelion_rules/compat/godot_string.hpp"
#include "aurelion_rules/port/battle_action_playback.hpp"
#include "aurelion_rules/port/battle_footprint.hpp"
#include "aurelion_rules/port/battle_rules.hpp"
#include "aurelion_rules/port/spell_rules.hpp"
#include "aurelion_rules/port/town_battle_rules.hpp"

#include <deque>
#include <initializer_list>
#include <string>
#include <unordered_set>

namespace aurelion::rules::port::battle_rules {

using compat::engine_clamp;
using compat::engine_max;
using gd::array_value;
using gd::dict_value;
using gd::int_value;
using gd::str;
using state::Kind;
namespace key = state::key;

namespace {

// d.get(key, []): the stored value, or a new empty Array when the key is missing.
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

// An Array literal of ints: a new Array on every evaluation.
ArrayRef int_array(State &state, std::initializer_list<int64_t> items) {
	const ArrayRef array = state.new_array();
	for (const int64_t item : items) {
		state.append(array, int_value(item));
	}
	return array;
}

} // namespace

void _ensure_battle_hex_state(State &state, DictRef battle) {
	if (gd::is_empty(state, battle)) {
		return;
	}
	state.set(battle, str(key::hex_board), dict_value(_hex_board_descriptor(state)));
	const Value stacks = field_or_new_array(state, battle, key::stacks);
	if (!gd::is_array(stacks)) {
		state.set(battle, str(key::stacks), array_value(state.new_array()));
		state.set(battle, str(key::occupied_hexes), dict_value(state.new_dict()));
		return;
	}
	// Obstacle cells are taken before any stack is placed.
	const DictRef used = _obstacle_cell_map(state, battle);
	const DictRef side_indices = state.new_dict();
	state.set(side_indices, str(key::player), int_value(0));
	state.set(side_indices, str(key::enemy), int_value(0));
	const int64_t player_count = _alive_stack_count_for_side(state, battle, key::player);
	const int64_t enemy_count = _alive_stack_count_for_side(state, battle, key::enemy);
	const DictRef side_counts = state.new_dict();
	state.set(side_counts, str(key::player), int_value(player_count));
	state.set(side_counts, str(key::enemy), int_value(enemy_count));
	const int64_t count = state.array_size(stacks.ref);
	for (int64_t index = 0; index < count; ++index) {
		const Value stack = state.at(stacks.ref, index);
		if (!gd::is_dict(stack)) {
			continue;
		}
		const Atom side = gd::string_field(state, stack.ref, key::side, key::player);
		if (_alive_count(state, stack.ref) <= 0) {
			// stack.get("hex", {}): a missing key normalizes like the new {} (to {}).
			const DictRef kept = _normalize_hex_cell(state, state.get(stack.ref, str(key::hex), Value()));
			state.set(stack.ref, str(key::hex), dict_value(kept));
			state.set_at(stacks.ref, index, stack);
			continue;
		}
		// Living stacks only, matching side_counts.
		const int64_t side_index = gd::int_field(state, side_indices, side, 0);
		state.set(side_indices, str(side), int_value(gd::add(side_index, 1)));
		DictRef cell = _normalize_hex_cell(state, state.get(stack.ref, str(key::hex), Value()));
		if (gd::is_empty(state, cell) || !battle_footprint::fits(state, stack.ref, dict_value(cell), used, BATTLE_HEX_COLUMNS, BATTLE_HEX_ROWS)) {
			cell = _default_stack_hex(state, side, side_index, gd::int_field(state, side_counts, side, 1), stack.ref);
			cell = _first_open_body_near(state, stack.ref, cell, used);
		}
		state.set(stack.ref, str(key::hex), dict_value(cell));
		const ArrayRef body = battle_footprint::cells(state, stack.ref, Value());
		for (const Value &body_cell : gd::items(state, array_value(body))) {
			const Atom cell_key = _hex_key(state, gd::as_dict(body_cell));
			state.set(used, str(cell_key), str(gd::string_field(state, stack.ref, key::battle_id, key::empty)));
		}
		state.set_at(stacks.ref, index, stack);
	}
	state.set(battle, str(key::stacks), stacks);
	_sync_occupied_hexes(state, battle);
}

DictRef _default_stack_hex(State &state, Atom side, int64_t index, int64_t stack_count, DictRef stack) {
	const ArrayRef rows = _formation_rows(state, stack_count);
	// clamp(int, int, int) is an int.
	const int64_t row = index >= 0 && index < state.array_size(rows) ? gd::to_int(state, state.at(rows, index)) : engine_clamp<int64_t>(index, 0, BATTLE_HEX_ROWS - 1);
	return _hex_cell(state, _deployment_column(state, side, stack), row);
}

int64_t _deployment_column(State &state, Atom side, DictRef stack) {
	const int64_t inset = battle_footprint::width(state, stack) - 1;
	return side == key::player ? inset : BATTLE_HEX_COLUMNS - 1 - inset;
}

ArrayRef _formation_rows(State &state, int64_t stack_count) {
	// The match arms return Array literals: a new Array on every call.
	switch (stack_count) {
		case 0:
			return int_array(state, {});
		case 1:
			return int_array(state, { 4 });
		case 2:
			return int_array(state, { 2, 6 });
		case 3:
			return int_array(state, { 1, 4, 7 });
		case 4:
			return int_array(state, { 1, 3, 5, 7 });
		case 5:
			return int_array(state, { 0, 2, 4, 6, 8 });
		case 6:
			return int_array(state, { 0, 2, 3, 5, 6, 8 });
		case 7:
			return int_array(state, { 0, 1, 3, 4, 5, 7, 8 });
		case 8:
			return int_array(state, { 0, 1, 2, 3, 5, 6, 7, 8 });
		default:
			return int_array(state, { 0, 1, 2, 3, 4, 5, 6, 7, 8 });
	}
}

DictRef _first_open_body_near(State &state, DictRef stack, DictRef preferred, DictRef used) {
	// frontier and seen stay local: a queue of the cells (all Dictionaries) and
	// the set of their keys.
	std::deque<DictRef> frontier{ preferred };
	std::unordered_set<Atom> seen{ _hex_key(state, preferred) };
	while (!frontier.empty()) {
		const DictRef cell = frontier.front();
		frontier.pop_front();
		if (battle_footprint::fits(state, stack, dict_value(cell), used, BATTLE_HEX_COLUMNS, BATTLE_HEX_ROWS)) {
			return cell;
		}
		const ArrayRef neighbors = _hex_neighbors(state, cell);
		for (const Value &neighbor : gd::items(state, array_value(neighbors))) {
			const Atom cell_key = _hex_key(state, gd::as_dict(neighbor));
			if (seen.count(cell_key) != 0) {
				continue;
			}
			seen.insert(cell_key);
			frontier.push_back(neighbor.ref);
		}
	}
	const Atom battle_id = gd::string_field(state, stack, key::battle_id, key::empty);
	const Atom message = gd::format(state, state.intern("No legal deployment space for battle stack %s"), { str(battle_id) });
	state.print_error(state.text(message));
	return state.new_dict();
}

DictRef _hex_board_descriptor(State &state) {
	const DictRef descriptor = state.new_dict();
	state.set(descriptor, str(key::columns), int_value(BATTLE_HEX_COLUMNS));
	state.set(descriptor, str(key::rows), int_value(BATTLE_HEX_ROWS));
	return descriptor;
}

void _set_stack_hex(State &state, DictRef battle, Atom battle_id, DictRef cell) {
	const DictRef moving = _get_stack_by_id(state, battle, battle_id);
	const DictRef from_hex = _stack_hex(state, moving);
	const DictRef normalized = _normalize_hex_cell(state, dict_value(cell));
	if (gd::is_empty(state, normalized)) {
		return;
	}
	const DictRef blocking = _build_blocking_map(state, battle);
	if (!battle_footprint::fits(state, moving, dict_value(normalized), blocking, BATTLE_HEX_COLUMNS, BATTLE_HEX_ROWS)) {
		return;
	}
	// The playback path is computed only with the capture key, for the capture.
	const ArrayRef playback_path = state.has(battle, str(key::_live_action_playback_capture)) ? _presentation_walk_path(state, battle, from_hex, normalized) : state.new_array();
	const Value stacks = field_or_new_array(state, battle, key::stacks);
	const int64_t count = untyped_size(state, stacks);
	for (int64_t index = 0; index < count; ++index) {
		const Value stack = untyped_at(state, stacks, index);
		if (gd::is_dict(stack) && gd::string_field(state, stack.ref, key::battle_id, key::empty) == battle_id) {
			state.set(stack.ref, str(key::hex), dict_value(normalized));
			untyped_set_at(state, stacks, index, stack);
			break;
		}
	}
	state.set(battle, str(key::stacks), stacks);
	_sync_occupied_hexes(state, battle);
	if (!gd::equal(state, dict_value(from_hex), dict_value(normalized))) {
		// The event literal in its order.
		const DictRef event = state.new_dict();
		state.set(event, str(key::event_id), str(key::battle_unit_move));
		state.set(event, str(key::state), str(key::move_path_step));
		state.set(event, str(key::battle_id), str(battle_id));
		state.set(event, str(key::from_q), state.get(from_hex, str(key::q), int_value(-1)));
		state.set(event, str(key::from_r), state.get(from_hex, str(key::r), int_value(-1)));
		state.set(event, str(key::to_q), gd::index(state, normalized, str(key::q)));
		state.set(event, str(key::to_r), gd::index(state, normalized, str(key::r)));
		state.set(event, str(key::walk_path), array_value(playback_path));
		battle_action_playback::capture(state, battle, event);
	}
}

ArrayRef _presentation_walk_path(State &state, DictRef battle, DictRef start, DictRef destination) {
	if (gd::is_empty(state, start) || gd::is_empty(state, destination)) {
		return state.new_array();
	}
	const DictRef occupied = _build_blocking_map(state, battle);
	const Atom holder = gd::to_string(state.get(occupied, str(_hex_key(state, start)), str(key::empty)));
	const DictRef moving = _get_stack_by_id(state, battle, holder);
	state.erase(occupied, str(_hex_key(state, start)));
	// frontier and seen stay local: a queue of the paths (Arrays, one of which
	// is returned) and the set of the cells' keys.
	std::deque<ArrayRef> frontier;
	const ArrayRef first = state.new_array();
	state.append(first, dict_value(start));
	frontier.push_back(first);
	std::unordered_set<Atom> seen{ _hex_key(state, start) };
	while (!frontier.empty()) {
		const ArrayRef path = frontier.front();
		frontier.pop_front();
		const DictRef cell = gd::as_dict(state.at(path, -1));
		if (_hex_key(state, cell) == _hex_key(state, destination)) {
			return path;
		}
		const ArrayRef neighbors = _hex_neighbors(state, cell);
		for (const Value &next : gd::items(state, array_value(neighbors))) {
			const Atom cell_key = _hex_key(state, gd::as_dict(next));
			if (seen.count(cell_key) != 0 || !battle_footprint::fits(state, moving, next, occupied, BATTLE_HEX_COLUMNS, BATTLE_HEX_ROWS)) {
				continue;
			}
			seen.insert(cell_key);
			const ArrayRef extended = gd::duplicate_array(state, path);
			state.append(extended, next);
			frontier.push_back(extended);
		}
	}
	return state.new_array();
}

int64_t _stack_movement_points(State &state, DictRef stack, DictRef battle) {
	if (!gd::is_empty(state, battle) && _stack_is_rooted(state, stack, battle)) {
		return 0;
	}
	const int64_t haste = !gd::is_empty(state, battle) ? spell_rules::effect_bonus_for_kind(state, stack, battle, key::speed) : 0;
	const int64_t speed = engine_clamp<int64_t>(gd::int_field(state, stack, key::speed, 1), 1, 6);
	const int64_t hasted = gd::add(speed, haste);
	const int64_t penalty = town_battle_rules::movement_penalty(state, battle, stack);
	return engine_max<int64_t>(1, gd::sub(hasted, penalty));
}

bool _stack_is_rooted(State &state, DictRef stack, DictRef battle) {
	return spell_rules::has_effect_id(state, stack, battle, key::status_rooted);
}

} // namespace aurelion::rules::port::battle_rules

namespace aurelion::rules::port::town_battle_rules {

namespace key = state::key;

int64_t movement_penalty(State &state, DictRef battle, DictRef stack) {
	if (defends(state, battle, stack)) {
		return 0;
	}
	return gd::int_field(state, effect(state, battle, key::chainboom), key::movement_penalty, 0);
}

} // namespace aurelion::rules::port::town_battle_rules
