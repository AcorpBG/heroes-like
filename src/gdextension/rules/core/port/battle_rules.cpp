#include "aurelion_rules/port/battle_rules.hpp"

#include "aurelion_rules/battle_hex.hpp"
#include "aurelion_rules/compat/godot_string.hpp"
#include "aurelion_rules/port/battle_footprint.hpp"

#include <cstring>
#include <string>
#include <vector>

namespace aurelion::rules::port::battle_rules {

using compat::absi;
using compat::engine_clamp;
using compat::engine_max;
using compat::engine_min;
using compat::int_div;
using compat::int_mod;
using gd::array_value;
using gd::dict_value;
using gd::int_value;
using gd::str;
using state::Kind;
namespace key = state::key;
namespace hex = aurelion::rules::battle_hex;

namespace {

// int * int as the engine computes it: two's complement wrap-around.
int64_t mul(int64_t a, int64_t b) {
	return static_cast<int64_t>(static_cast<uint64_t>(a) * static_cast<uint64_t>(b));
}

int64_t int_field(const State &state, DictRef dict, Atom field, int64_t fallback) {
	return gd::to_int(state, state.get(dict, str(field), int_value(fallback)));
}

Atom string_field(const State &state, DictRef dict, Atom field, Atom fallback) {
	return gd::to_string(state.get(dict, str(field), str(fallback)));
}

// "%d,%d" % [q, r], interned.
Atom pair_key(State &state, int64_t q, int64_t r) {
	return state.intern(gd::format_pair(q, r));
}

// The "q,r" key of a hex id, the way _hex_id_by_key maps them: -1 for a key
// that is not one of the board's 99.
int64_t hex_id_of_key(const State &state, const Value &key) {
	if (!key.is_string_like()) {
		return -1;
	}
	const std::string &text = state.text(key.ref);
	const size_t comma = text.find(',');
	if (comma == std::string::npos || comma == 0 || comma + 1 >= text.size() || comma > 2 || text.size() - comma - 1 > 1) {
		return -1;
	}
	int64_t q = 0;
	for (size_t index = 0; index < comma; ++index) {
		if (text[index] < '0' || text[index] > '9') {
			return -1;
		}
		q = q * 10 + (text[index] - '0');
	}
	const char row = text[comma + 1];
	if (row < '0' || row > '9') {
		return -1;
	}
	const int64_t r = row - '0';
	if (q >= BATTLE_HEX_COLUMNS || r >= BATTLE_HEX_ROWS || gd::format_pair(q, r) != text) {
		return -1;
	}
	return q * BATTLE_HEX_ROWS + r;
}

DictRef empty_dict(State &state) {
	return state.new_dict();
}

} // namespace

DictRef get_active_stack(State &state, DictRef battle) {
	return _get_stack_by_id(state, battle, string_field(state, battle, key::active_stack_id, key::empty));
}

int64_t _alive_count(const State &state, DictRef stack) {
	const int64_t unit_hp = engine_max<int64_t>(1, int_field(state, stack, key::unit_hp, 1));
	const double health = static_cast<double>(engine_max<int64_t>(0, int_field(state, stack, key::total_health, 0)));
	return compat::float_to_int(compat::godot_ceil(health / static_cast<double>(unit_hp)));
}

int64_t _alive_stack_count_for_side(State &state, DictRef battle, Atom side) {
	int64_t total = 0;
	for (const Value &stack : gd::field_items(state, battle, str(key::stacks))) {
		if (gd::is_dict(stack) && string_field(state, stack.ref, key::side, key::empty) == side && _alive_count(state, stack.ref) > 0) {
			total += 1;
		}
	}
	return total;
}

ArrayRef _alive_stacks_for_side(State &state, DictRef battle, Atom side) {
	const ArrayRef alive = state.new_array();
	for (const Value &stack : gd::field_items(state, battle, str(key::stacks))) {
		if (gd::is_dict(stack) && string_field(state, stack.ref, key::side, key::empty) == side && int_field(state, stack.ref, key::total_health, 0) > 0) {
			state.append(alive, stack);
		}
	}
	return alive;
}

DictRef _build_blocking_map(State &state, DictRef battle) {
	const DictRef blocked = _obstacle_cell_map(state, battle);
	gd::merge(state, blocked, _build_occupancy_map(state, battle), true);
	return blocked;
}

DictRef _build_occupancy_map(State &state, DictRef battle) {
	const DictRef occupied = state.new_dict();
	for (const Value &stack : gd::field_items(state, battle, str(key::stacks))) {
		if (!gd::is_dict(stack) || _alive_count(state, stack.ref) <= 0) {
			continue;
		}
		const DictRef cell = _stack_hex(state, stack.ref);
		if (gd::is_empty(state, cell)) {
			continue;
		}
		const ArrayRef body = battle_footprint::cells(state, stack.ref, Value());
		for (const Value &body_cell : gd::items(state, array_value(body))) {
			const Atom cell_key = _hex_key(state, gd::as_dict(body_cell));
			state.set(occupied, str(cell_key), str(string_field(state, stack.ref, key::battle_id, key::empty)));
		}
	}
	return occupied;
}

int64_t _distance_band_from_hex_distance(int64_t hex_distance) {
	if (hex_distance <= 1) {
		return 0;
	}
	if (hex_distance <= 5) {
		return 1;
	}
	return 2;
}

DictRef _get_stack_by_id(State &state, DictRef battle, Atom battle_id) {
	if (battle_id == key::empty) {
		return empty_dict(state);
	}
	for (const Value &stack : gd::field_items(state, battle, str(key::stacks))) {
		if (gd::is_dict(stack) && string_field(state, stack.ref, key::battle_id, key::empty) == battle_id) {
			return stack.ref;
		}
	}
	return empty_dict(state);
}

double _health_ratio(const State &state, DictRef stack) {
	if (gd::is_empty(state, stack)) {
		return 0.0;
	}
	const int64_t base_count = int_field(state, stack, key::base_count, 0);
	const int64_t max_health = engine_max<int64_t>(1, mul(base_count, engine_max<int64_t>(1, int_field(state, stack, key::unit_hp, 1))));
	const double health = static_cast<double>(engine_max<int64_t>(0, int_field(state, stack, key::total_health, 0)));
	return engine_clamp(health / static_cast<double>(max_health), 0.0, 1.0);
}

DictRef _hex_cell(State &state, int64_t q, int64_t r) {
	const DictRef cell = state.new_dict();
	state.set(cell, str(key::q), int_value(engine_clamp<int64_t>(q, 0, BATTLE_HEX_COLUMNS - 1)));
	state.set(cell, str(key::r), int_value(engine_clamp<int64_t>(r, 0, BATTLE_HEX_ROWS - 1)));
	return cell;
}

int64_t _hex_distance(State &state, DictRef lhs, DictRef rhs) {
	if (gd::is_empty(state, lhs) || gd::is_empty(state, rhs)) {
		return 999;
	}
	const int64_t lhs_q = int_field(state, lhs, key::q, 0);
	const int64_t lhs_r = int_field(state, lhs, key::r, 0);
	const DictRef lhs_cube = _offset_to_cube(state, lhs_q, lhs_r);
	const int64_t rhs_q = int_field(state, rhs, key::q, 0);
	const int64_t rhs_r = int_field(state, rhs, key::r, 0);
	const DictRef rhs_cube = _offset_to_cube(state, rhs_q, rhs_r);
	const int64_t dx = absi(int_field(state, lhs_cube, key::x, 0) - int_field(state, rhs_cube, key::x, 0));
	const int64_t dy = absi(int_field(state, lhs_cube, key::y, 0) - int_field(state, rhs_cube, key::y, 0));
	const int64_t dz = absi(int_field(state, lhs_cube, key::z, 0) - int_field(state, rhs_cube, key::z, 0));
	return int_div(dx + dy + dz, 2);
}

bool _hex_in_bounds(int64_t q, int64_t r) {
	return q >= 0 && q < BATTLE_HEX_COLUMNS && r >= 0 && r < BATTLE_HEX_ROWS;
}

Atom _hex_key(State &state, DictRef cell) {
	const int64_t q = int_field(state, cell, key::q, -1);
	const int64_t r = int_field(state, cell, key::r, -1);
	return pair_key(state, q, r);
}

Atom _hex_key_from_coords(State &state, int64_t q, int64_t r) {
	return pair_key(state, q, r);
}

Atom _hex_label(State &state, DictRef cell) {
	if (gd::is_empty(state, cell)) {
		return key::unknown_hex;
	}
	const int64_t q = int_field(state, cell, key::q, 0);
	const int64_t r = int_field(state, cell, key::r, 0);
	return state.intern("hex " + gd::format_pair(q, r));
}

ArrayRef _hex_neighbors(State &state, DictRef cell) {
	static const int64_t kEven[6][2] = { { 1, 0 }, { 0, -1 }, { -1, -1 }, { -1, 0 }, { -1, 1 }, { 0, 1 } };
	static const int64_t kOdd[6][2] = { { 1, 0 }, { 1, -1 }, { 0, -1 }, { -1, 0 }, { 0, 1 }, { 1, 1 } };
	const int64_t q = int_field(state, cell, key::q, -1);
	const int64_t r = int_field(state, cell, key::r, -1);
	const int64_t(*offsets)[2] = int_mod(r, 2) == 0 ? kEven : kOdd;
	const ArrayRef neighbors = state.new_array();
	for (int index = 0; index < 6; ++index) {
		const int64_t next_q = q + offsets[index][0];
		const int64_t next_r = r + offsets[index][1];
		if (_hex_in_bounds(next_q, next_r)) {
			state.append(neighbors, dict_value(_hex_cell(state, next_q, next_r)));
		}
	}
	return neighbors;
}

void _hex_open_mask(State &state, DictRef stack, DictRef occupied, uint8_t *open) {
	std::memset(open, 1, static_cast<size_t>(BATTLE_HEX_COLUMNS * BATTLE_HEX_ROWS));
	const Atom identity = string_field(state, stack, key::battle_id, key::empty);
	const state::DictNode &blockers = state.dict(occupied);
	for (size_t index = 0; index < blockers.keys.size(); ++index) {
		const int64_t id = hex_id_of_key(state, blockers.keys[index]);
		if (id >= 0 && (identity == key::empty || gd::to_string(blockers.values[index]) != identity)) {
			open[id] = 0;
		}
	}
}

int64_t _hex_tail_step(const State &state, DictRef stack) {
	return string_field(state, stack, key::side, key::player) == key::enemy ? 1 : -1;
}

DictRef _normalize_hex_cell(State &state, const Value &value) {
	if (gd::is_vector2i(value)) {
		return _hex_cell(state, value.vx(), value.vy());
	}
	if (gd::is_dict(value)) {
		const int64_t q = gd::to_int(state, state.get(value.ref, str(key::q), state.get(value.ref, str(key::x), int_value(-1))));
		const int64_t r = gd::to_int(state, state.get(value.ref, str(key::r), state.get(value.ref, str(key::y), int_value(-1))));
		if (_hex_in_bounds(q, r)) {
			return _hex_cell(state, q, r);
		}
	}
	return empty_dict(state);
}

DictRef _obstacle_cell_map(State &state, DictRef battle) {
	const DictRef blocked = state.new_dict();
	Value obstacles;
	if (!state.lookup(battle, str(key::obstacles), obstacles)) {
		return blocked; // the default [] has nothing to walk
	}
	if (!gd::is_array(obstacles)) {
		return blocked;
	}
	for (const Value &obstacle : gd::items(state, obstacles)) {
		if (!gd::is_dict(obstacle)) {
			continue;
		}
		for (const Value &cell : gd::field_items(state, obstacle.ref, str(key::cells))) {
			const DictRef normalized = _normalize_hex_cell(state, cell);
			if (!gd::is_empty(state, normalized)) {
				const Atom cell_key = _hex_key(state, normalized);
				const Atom blocker = state.intern("obstacle:" + state.text(string_field(state, obstacle.ref, key::id, key::empty)));
				state.set(blocked, str(cell_key), str(blocker));
			}
		}
	}
	return blocked;
}

DictRef _offset_to_cube(State &state, int64_t q, int64_t r) {
	const int64_t x = q - int_div(r - int_mod(r, 2), 2);
	const int64_t z = r;
	const int64_t y = -x - z;
	const DictRef cube = state.new_dict();
	state.set(cube, str(key::x), int_value(x));
	state.set(cube, str(key::y), int_value(y));
	state.set(cube, str(key::z), int_value(z));
	return cube;
}

Atom _opposing_side(Atom side) {
	if (side == key::player) {
		return key::enemy;
	}
	if (side == key::enemy) {
		return key::player;
	}
	return key::empty;
}

int64_t _projected_min_opposing_hex_distance(State &state, DictRef battle, DictRef stack, DictRef destination) {
	int64_t best = 999;
	const ArrayRef targets = _alive_stacks_for_side(state, battle, _opposing_side(string_field(state, stack, key::side, key::empty)));
	for (const Value &target : gd::items(state, array_value(targets))) {
		best = engine_min<int64_t>(best, battle_footprint::distance(state, stack, gd::as_dict(target), dict_value(destination)));
	}
	return best;
}

ArrayRef _reachable_empty_hexes(State &state, DictRef battle, DictRef stack, int64_t max_steps) {
	const DictRef start = _stack_hex(state, stack);
	if (gd::is_empty(state, start) || max_steps <= 0) {
		return state.new_array();
	}
	const DictRef occupied = _build_blocking_map(state, battle);
	state.erase(occupied, str(_hex_key(state, start)));
	const int64_t start_id = gd::to_int(state, gd::index(state, start, str(key::q))) * BATTLE_HEX_ROWS + gd::to_int(state, gd::index(state, start, str(key::r)));
	uint8_t open[BATTLE_HEX_COLUMNS * BATTLE_HEX_ROWS];
	_hex_open_mask(state, stack, occupied, open);
	const hex::Body body{ battle_footprint::width(state, stack), _hex_tail_step(state, stack) };
	const std::vector<hex::CellSteps> pairs = hex::reachable(open, body, start_id, max_steps);
	const ArrayRef reachable = state.new_array();
	for (const hex::CellSteps &pair : pairs) {
		const DictRef cell = state.new_dict();
		state.set(cell, str(key::q), int_value(int_div(pair.id, BATTLE_HEX_ROWS)));
		state.set(cell, str(key::r), int_value(int_mod(pair.id, BATTLE_HEX_ROWS)));
		state.set(cell, str(key::steps), int_value(pair.steps));
		state.append(reachable, dict_value(cell));
	}
	return reachable;
}

Atom _side_label(Atom side) {
	return side == key::enemy ? key::Enemy : key::Player;
}

DictRef _stack_hex(State &state, DictRef stack) {
	return _normalize_hex_cell(state, state.get(stack, str(key::hex), Value()));
}

int64_t _stack_hex_distance(State &state, DictRef lhs, DictRef rhs) {
	return battle_footprint::distance(state, lhs, rhs, Value());
}

bool _stack_is_engaged(State &state, DictRef stack, DictRef battle) {
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

Atom _stack_label(const State &state, DictRef stack) {
	const Value fallback = state.get(stack, str(key::unit_id), str(key::Stack));
	return gd::to_string(state.get(stack, str(key::name), fallback));
}

void _sync_distance_from_hexes(State &state, DictRef battle) {
	int64_t best = 999;
	const ArrayRef players = _alive_stacks_for_side(state, battle, key::player);
	for (const Value &player_stack : gd::items(state, array_value(players))) {
		const ArrayRef enemies = _alive_stacks_for_side(state, battle, key::enemy);
		for (const Value &enemy_stack : gd::items(state, array_value(enemies))) {
			best = engine_min<int64_t>(best, _stack_hex_distance(state, gd::as_dict(player_stack), gd::as_dict(enemy_stack)));
		}
	}
	if (best < 999) {
		state.set(battle, str(key::distance), int_value(_distance_band_from_hex_distance(best)));
	}
}

void _sync_occupied_hexes(State &state, DictRef battle) {
	state.set(battle, str(key::occupied_hexes), dict_value(_build_occupancy_map(state, battle)));
}

DictRef _walk_steps_to_target(State &state, DictRef battle, DictRef stack, DictRef target, int64_t gap) {
	// The board-read memo's key reads both battle ids as Strings.
	gd::to_string(state.get(stack, str(key::battle_id), str(key::empty)));
	gd::to_string(state.get(target, str(key::battle_id), str(key::empty)));
	int64_t target_q = -1;
	int64_t target_r = -1;
	int64_t target_tail = -1;
	battle_footprint::placed_columns(state, target, target_q, target_r, target_tail);
	uint8_t open[BATTLE_HEX_COLUMNS * BATTLE_HEX_ROWS];
	_walk_open_mask(state, battle, stack, open);
	const hex::Body body{ battle_footprint::width(state, stack), _hex_tail_step(state, stack) };
	const std::vector<hex::CellSteps> pairs = hex::walk_steps(open, body, hex::PlacedBody{ target_q, target_r, target_tail }, gap);
	const DictRef steps = state.new_dict();
	for (const hex::CellSteps &pair : pairs) {
		const Atom cell_key = _hex_key_from_coords(state, int_div(pair.id, BATTLE_HEX_ROWS), int_mod(pair.id, BATTLE_HEX_ROWS));
		state.set(steps, str(cell_key), int_value(pair.steps));
	}
	return steps;
}

void _walk_open_mask(State &state, DictRef battle, DictRef stack, uint8_t *open) {
	gd::to_string(state.get(stack, str(key::battle_id), str(key::empty)));
	_hex_open_mask(state, stack, _build_blocking_map(state, battle), open);
}

} // namespace aurelion::rules::port::battle_rules
