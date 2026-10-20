#include "aurelion_rules/port/battle_footprint.hpp"

namespace aurelion::rules::port::battle_footprint {

using compat::absi;
using compat::int_div;
using compat::int_mod;
using gd::int_value;
using gd::str;
using state::Kind;
namespace key = state::key;

namespace {

bool anchor_is_empty(const State &state, const Value &anchor) {
	return anchor.kind == Kind::Nil || state.dict_size(gd::as_dict(anchor)) == 0;
}

// `stack.get("hex", {}) if anchor.is_empty() else anchor`; Nil for the `{}`.
Value origin_of(const State &state, DictRef stack, const Value &anchor) {
	if (!anchor_is_empty(state, anchor)) {
		return anchor;
	}
	return state.get(stack, str(key::hex), Value());
}

// The q and r every function here reads from an origin: a Vector2i's x and y,
// or a non-empty Dictionary's int(get("q", get("x", -1))) and the same for r.
// -1 and -1 for anything else.
void origin_cell(const State &state, const Value &origin, int64_t &q, int64_t &r) {
	q = -1;
	r = -1;
	if (origin.kind == Kind::Vector2i) {
		q = origin.vx();
		r = origin.vy();
		return;
	}
	if (origin.kind == Kind::Dict && state.dict_size(origin.ref) != 0) {
		q = gd::to_int(state, state.get(origin.ref, str(key::q), state.get(origin.ref, str(key::x), int_value(-1))));
		r = gd::to_int(state, state.get(origin.ref, str(key::r), state.get(origin.ref, str(key::y), int_value(-1))));
	}
}

// `q + (1 if String(stack.get("side", "player")) == "enemy" else -1)`
int64_t tail_column(const State &state, DictRef stack, int64_t q) {
	return q + (gd::to_string(state.get(stack, str(key::side), str(key::player))) == key::enemy ? 1 : -1);
}

bool wide(const State &state, DictRef stack) {
	return gd::to_int(state, state.get(stack, str(key::battle_footprint), int_value(1))) == 2;
}

DictRef cell_dict(State &state, int64_t q, int64_t r) {
	const DictRef cell = state.new_dict();
	state.set(cell, str(key::q), int_value(q));
	state.set(cell, str(key::r), int_value(r));
	return cell;
}

// `occupied.has(key) and (identity.is_empty() or String(occupied[key]) != identity)`
bool taken(State &state, DictRef occupied, int64_t q, int64_t r, gd::Atom identity) {
	const Value cell_key = state.string(gd::format_pair(q, r));
	Value holder;
	if (!state.lookup(occupied, cell_key, holder)) {
		return false;
	}
	return identity == key::empty || gd::to_string(holder) != identity;
}

int64_t cube_distance(int64_t dx, int64_t dz) {
	return int_div(absi(dx) + absi(dz) + absi(dx + dz), 2);
}

} // namespace

int64_t width(const State &state, DictRef stack) {
	return wide(state, stack) ? 2 : 1;
}

ArrayRef cells(State &state, DictRef stack, const Value &anchor) {
	const Value origin = origin_of(state, stack, anchor);
	const ArrayRef result = state.new_array();
	if (!(origin.kind == Kind::Vector2i || (origin.kind == Kind::Dict && state.dict_size(origin.ref) != 0))) {
		return result;
	}
	int64_t q = -1;
	int64_t r = -1;
	origin_cell(state, origin, q, r);
	if (q < 0 || r < 0) {
		return result;
	}
	state.append(result, gd::dict_value(cell_dict(state, q, r)));
	if (width(state, stack) == 2) {
		state.append(result, gd::dict_value(cell_dict(state, tail_column(state, stack, q), r)));
	}
	return result;
}

bool fits(State &state, DictRef stack, const Value &anchor, DictRef occupied, int64_t columns, int64_t rows) {
	int64_t q = -1;
	int64_t r = -1;
	origin_cell(state, origin_of(state, stack, anchor), q, r);
	if (q < 0 || r < 0) {
		return false;
	}
	const bool is_wide = wide(state, stack);
	const gd::Atom identity = gd::to_string(state.get(stack, str(key::battle_id), str(key::empty)));
	if (q >= columns || r >= rows) {
		return false;
	}
	if (taken(state, occupied, q, r, identity)) {
		return false;
	}
	if (is_wide) {
		const int64_t tail_q = tail_column(state, stack, q);
		if (tail_q < 0 || tail_q >= columns) {
			return false;
		}
		if (taken(state, occupied, tail_q, r, identity)) {
			return false;
		}
	}
	return true;
}

void placed_columns(const State &state, DictRef stack, int64_t &q, int64_t &r, int64_t &tail) {
	origin_cell(state, state.get(stack, str(key::hex), Value()), q, r);
	tail = q;
	if (wide(state, stack)) {
		tail = tail_column(state, stack, q);
	}
}

ArrayRef placed_columns(State &state, DictRef stack) {
	int64_t q = -1;
	int64_t r = -1;
	int64_t tail = -1;
	placed_columns(state, stack, q, r, tail);
	const ArrayRef result = state.new_array();
	state.append(result, int_value(q));
	state.append(result, int_value(r));
	state.append(result, int_value(tail));
	return result;
}

int64_t distance(const State &state, DictRef lhs, DictRef rhs, const Value &lhs_anchor) {
	int64_t a_q = -1;
	int64_t a_r = -1;
	origin_cell(state, origin_of(state, lhs, lhs_anchor), a_q, a_r);
	if (a_q < 0 || a_r < 0) {
		return 999;
	}
	int64_t a_tail = a_q;
	if (wide(state, lhs)) {
		a_tail = tail_column(state, lhs, a_q);
	}
	int64_t b_q = -1;
	int64_t b_r = -1;
	origin_cell(state, state.get(rhs, str(key::hex), Value()), b_q, b_r);
	if (b_q < 0 || b_r < 0) {
		return 999;
	}
	int64_t b_tail = b_q;
	if (wide(state, rhs)) {
		b_tail = tail_column(state, rhs, b_q);
	}
	const int64_t a_shift = int_div(a_r - int_mod(a_r, 2), 2);
	const int64_t b_shift = int_div(b_r - int_mod(b_r, 2), 2);
	const int64_t dz = a_r - b_r;
	int64_t dx = (a_q - a_shift) - (b_q - b_shift);
	int64_t nearest = compat::engine_min<int64_t>(999, cube_distance(dx, dz));
	if (b_tail != b_q) {
		dx = (a_q - a_shift) - (b_tail - b_shift);
		nearest = compat::engine_min<int64_t>(nearest, cube_distance(dx, dz));
	}
	if (a_tail != a_q) {
		dx = (a_tail - a_shift) - (b_q - b_shift);
		nearest = compat::engine_min<int64_t>(nearest, cube_distance(dx, dz));
		if (b_tail != b_q) {
			dx = (a_tail - a_shift) - (b_tail - b_shift);
			nearest = compat::engine_min<int64_t>(nearest, cube_distance(dx, dz));
		}
	}
	return nearest;
}

} // namespace aurelion::rules::port::battle_footprint
