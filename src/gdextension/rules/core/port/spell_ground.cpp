// Layer 8: the tier-2 spells that take a hex (docs/magic-system-spells.md). Flame Furrow burns up to 3 empty hexes
// in a row, Bramble Patch grows brambles on up to 3, Crystal Pillar raises a pillar on one, Murk lays fog on up to 3
// hexes and Thorn Seed plants a seed on one. A cast lays an entry on battle.spell_ground with its numbers fixed: the
// hexes, the caster's side, the last round it holds, and its damage, defense or status. The board reads the entries
// that still hold: a pillar blocks like an obstacle and lends defense to its side's stacks next to it, a walk stops in
// brambles and pays for them, a walk over burning ground burns once and a stack standing in it burns at the end of
// its turn, murk refuses shots into and out of it, and a seed goes off under the first stack of the other side that
// ends a walk next to it.
//
// A "line" is the picked hex and the hexes above and below it (q, r - 1) and (q, r + 1): three hexes across the
// field, each next to the one before.

#include "aurelion_rules/port/spell_rules.hpp"

#include "aurelion_rules/battle_hex.hpp"
#include "aurelion_rules/compat/godot_math.hpp"
#include "aurelion_rules/port/battle_footprint.hpp"
#include "aurelion_rules/port/battle_rules.hpp"

#include <cstdint>
#include <string>
#include <vector>

namespace aurelion::rules::port::spell_rules {

using compat::engine_max;
using compat::engine_min;
using gd::array_value;
using gd::bool_value;
using gd::dict_value;
using gd::int_value;
using gd::str;
namespace key = state::key;
namespace hex = battle_hex;

namespace {

// A seed waits until it goes off.
constexpr int64_t GROUND_FOREVER = 1000000;
constexpr int64_t CELL_COUNT = hex::kCellCount;
constexpr int32_t FAR = 1 << 20;
// No entry: handle 0 is a real node, so none is the largest handle.
constexpr uint32_t NONE = UINT32_MAX;

// a + b of Strings.
Atom concat(State &state, Atom a, Atom b) {
	return state.intern(state.text(a) + state.text(b));
}

// A content label in lower case (ASCII letters; anything else as it is).
Atom ascii_lower(State &state, Atom text) {
	std::string lowered = state.text(text);
	for (char &c : lowered) {
		if (c >= 'A' && c <= 'Z') {
			c = static_cast<char>(c - 'A' + 'a');
		}
	}
	return state.intern(lowered);
}

Atom side_of(const State &state, DictRef stack) {
	return gd::string_field(state, stack, key::side, key::empty);
}

DictRef effect_of(State &state, DictRef spell) {
	const Value effect = gd::field(state, spell, key::effect);
	return gd::is_dict(effect) ? effect.ref : state.new_dict();
}

int64_t cell_id(int64_t q, int64_t r) {
	return q * hex::kRows + r;
}

int64_t cell_id_of(State &state, const Value &cell) {
	if (!gd::is_dict(cell)) {
		return -1;
	}
	const int64_t q = gd::int_field(state, cell.ref, key::q, -1);
	const int64_t r = gd::int_field(state, cell.ref, key::r, -1);
	return battle_rules::_hex_in_bounds(q, r) ? cell_id(q, r) : -1;
}

// The entries on the board, those that still hold this round first checked by the caller.
ArrayRef raw_entries(State &state, DictRef battle) {
	Value entries;
	if (!gd::is_empty(state, battle) && state.lookup(battle, str(key::spell_ground), entries) && gd::is_array(entries)) {
		return entries.ref;
	}
	return NONE;
}

bool entry_holds(State &state, DictRef battle, const Value &entry) {
	return gd::is_dict(entry) && gd::int_field(state, entry.ref, key::until_round, 0) >= gd::int_field(state, battle, key::round, 1);
}

// The entries of one kind (any kind when ground is empty) that still hold.
std::vector<DictRef> holding(State &state, DictRef battle, Atom ground) {
	std::vector<DictRef> found;
	const ArrayRef entries = raw_entries(state, battle);
	if (entries == NONE) {
		return found;
	}
	for (const Value &entry : gd::items(state, array_value(entries))) {
		if (entry_holds(state, battle, entry) && (ground == key::empty || gd::string_field(state, entry.ref, key::ground, key::empty) == ground)) {
			found.push_back(entry.ref);
		}
	}
	return found;
}

// One byte per hex id: 1 on the entries' hexes.
void mark_cells(State &state, const std::vector<DictRef> &entries, uint8_t *marked) {
	for (int64_t id = 0; id < CELL_COUNT; ++id) {
		marked[id] = 0;
	}
	for (const DictRef entry : entries) {
		for (const Value &cell : gd::field_items(state, entry, str(key::cells))) {
			const int64_t id = cell_id_of(state, cell);
			if (id >= 0) {
				marked[id] = 1;
			}
		}
	}
}

// 1 where the body anchored at the hex covers a marked hex.
void body_mask(const uint8_t *marked, hex::Body body, uint8_t *out) {
	for (int64_t q = 0; q < hex::kColumns; ++q) {
		for (int64_t r = 0; r < hex::kRows; ++r) {
			bool covered = marked[cell_id(q, r)] != 0;
			if (!covered && body.width == 2) {
				const int64_t tail_q = q + body.tail_step;
				covered = tail_q >= 0 && tail_q < hex::kColumns && marked[cell_id(tail_q, r)] != 0;
			}
			out[cell_id(q, r)] = covered ? 1 : 0;
		}
	}
}

hex::Body body_of(State &state, DictRef stack) {
	return hex::Body{ battle_footprint::width(state, stack), battle_rules::_hex_tail_step(state, stack) };
}

bool cell_in_entry(State &state, DictRef entry, int64_t id) {
	for (const Value &cell : gd::field_items(state, entry, str(key::cells))) {
		if (cell_id_of(state, cell) == id) {
			return true;
		}
	}
	return false;
}

// The stack's hexes where it stands now.
std::vector<int64_t> body_ids(State &state, DictRef stack) {
	std::vector<int64_t> ids;
	for (const Value &cell : gd::items(state, array_value(battle_footprint::cells(state, stack, Value())))) {
		const int64_t id = cell_id_of(state, cell);
		if (id >= 0) {
			ids.push_back(id);
		}
	}
	return ids;
}

// The first entry among these whose hexes the stack stands on.
DictRef entry_under(State &state, const std::vector<DictRef> &entries, DictRef stack) {
	const std::vector<int64_t> ids = body_ids(state, stack);
	for (const DictRef entry : entries) {
		for (const int64_t id : ids) {
			if (cell_in_entry(state, entry, id)) {
				return entry;
			}
		}
	}
	return NONE;
}

// The fewest hexes between the stack's body and a hex.
int64_t body_distance_to(State &state, DictRef stack, const Value &cell) {
	const DictRef target = battle_rules::_normalize_hex_cell(state, cell);
	if (gd::is_empty(state, target)) {
		return 999;
	}
	int64_t best = 999;
	for (const Value &body_cell : gd::items(state, array_value(battle_footprint::cells(state, stack, Value())))) {
		if (gd::is_dict(body_cell)) {
			best = engine_min<int64_t>(best, battle_rules::_hex_distance(state, body_cell.ref, target));
		}
	}
	return best;
}

// A ground entry's damage to a stack, after the stack's resistance to the spell.
int64_t ground_damage_to(State &state, DictRef battle, DictRef entry, DictRef stack) {
	const int64_t raw = gd::int_field(state, entry, key::damage, 0);
	if (raw <= 0) {
		return 0;
	}
	const DictRef spell = gd::content_row(state, state::ContentTable::Spell, gd::string_field(state, entry, key::spell_id, key::empty));
	const int64_t resistance_pct = spell_damage_resistance_pct(state, battle, stack, spell);
	const double scaled = static_cast<double>(raw) * static_cast<double>(gd::sub(100, resistance_pct)) / 100.0;
	return engine_max<int64_t>(1, compat::float_to_int(compat::godot_round(scaled)));
}

// The damage done and its line, or an empty Atom when the stack is gone.
Atom hurt(State &state, DictRef battle, Atom battle_id, DictRef entry, Atom format) {
	const DictRef stack = battle_rules::_get_stack_by_id(state, battle, battle_id);
	if (gd::is_empty(state, stack) || _alive_count(state, stack) <= 0) {
		return key::empty;
	}
	const int64_t damage = ground_damage_to(state, battle, entry, stack);
	if (damage <= 0) {
		return key::empty;
	}
	const Atom label = battle_rules::_stack_label(state, stack);
	battle_rules::_apply_damage_to_stack(state, battle, battle_id, damage);
	const Atom line = gd::format(state, format, { str(label), int_value(damage) });
	battle_rules::_record_event(state, battle, line);
	return line;
}

void store_entries(State &state, DictRef battle, ArrayRef entries) {
	// A new Array each time, so that answers read from the old one are dropped.
	state.set(battle, str(key::spell_ground), array_value(entries));
}

void remove_entry(State &state, DictRef battle, DictRef gone) {
	const ArrayRef kept = state.new_array();
	const ArrayRef entries = raw_entries(state, battle);
	if (entries == NONE) {
		return;
	}
	for (const Value &entry : gd::items(state, array_value(entries))) {
		if (gd::is_dict(entry) && entry.ref != gone) {
			state.append(kept, entry);
		}
	}
	store_entries(state, battle, kept);
}

// The hexes a pick covers, with the board's blockers already known.
ArrayRef shape_cells(State &state, DictRef blocked, DictRef spell, int64_t q, int64_t r) {
	const ArrayRef cells = state.new_array();
	if (!battle_rules::_hex_in_bounds(q, r)) {
		return cells;
	}
	const DictRef effect = effect_of(state, spell);
	const bool empty_only = gd::bool_field(state, effect, key::empty_only, false);
	const auto open = [&](int64_t cq, int64_t cr) {
		return battle_rules::_hex_in_bounds(cq, cr) && (!empty_only || !state.has(blocked, str(state.pair_atom(cq, cr))));
	};
	if (!open(q, r)) {
		return cells;
	}
	const bool line = gd::string_field(state, effect, key::shape, key::single) == key::line;
	for (int64_t dr = line ? -1 : 0; dr <= (line ? 1 : 0); ++dr) {
		if (open(q, r + dr)) {
			state.append(cells, dict_value(battle_rules::_hex_cell(state, q, r + dr)));
		}
	}
	return cells;
}

} // namespace

bool takes_hex(State &state, DictRef spell) {
	return !gd::is_empty(state, spell) && gd::string_field(state, effect_of(state, spell), key::type, key::empty) == key::ground_effect;
}

ArrayRef ground_pick_cells(State &state, DictRef battle, DictRef spell) {
	const ArrayRef picks = state.new_array();
	if (!takes_hex(state, spell) || gd::is_empty(state, battle)) {
		return picks;
	}
	const DictRef blocked = battle_rules::_build_blocking_map(state, battle);
	for (int64_t q = 0; q < hex::kColumns; ++q) {
		for (int64_t r = 0; r < hex::kRows; ++r) {
			if (state.array_size(shape_cells(state, blocked, spell, q, r)) > 0) {
				state.append(picks, dict_value(battle_rules::_hex_cell(state, q, r)));
			}
		}
	}
	return picks;
}

ArrayRef ground_pick_shapes(State &state, DictRef battle, DictRef spell) {
	const ArrayRef picks = state.new_array();
	if (!takes_hex(state, spell) || gd::is_empty(state, battle)) {
		return picks;
	}
	const DictRef blocked = battle_rules::_build_blocking_map(state, battle);
	for (int64_t q = 0; q < hex::kColumns; ++q) {
		for (int64_t r = 0; r < hex::kRows; ++r) {
			const ArrayRef cells = shape_cells(state, blocked, spell, q, r);
			if (state.array_size(cells) > 0) {
				const DictRef pick = battle_rules::_hex_cell(state, q, r);
				state.set(pick, str(key::cells), array_value(cells));
				state.append(picks, dict_value(pick));
			}
		}
	}
	return picks;
}

ArrayRef ground_shape_cells(State &state, DictRef battle, DictRef spell, DictRef center) {
	if (!takes_hex(state, spell) || gd::is_empty(state, battle) || gd::is_empty(state, center)) {
		return state.new_array();
	}
	const DictRef blocked = battle_rules::_build_blocking_map(state, battle);
	return shape_cells(state, blocked, spell, gd::int_field(state, center, key::q, -1), gd::int_field(state, center, key::r, -1));
}

DictRef ground_entry_for_cast(State &state, DictRef hero, DictRef battle, DictRef spell, Atom side, ArrayRef cells) {
	const DictRef effect = effect_of(state, spell);
	const Atom ground = gd::string_field(state, effect, key::ground, key::empty);
	const int64_t power = spell_power(state, hero);
	// Damage and the seed's roots grow with power less the other side's Knowledge.
	const int64_t against = engine_max<int64_t>(0, gd::sub(power, opposing_side_knowledge(state, battle, side)));
	const DictRef entry = state.new_dict();
	state.set(entry, str(key::spell_id), str(gd::string_field(state, spell, key::id, key::empty)));
	state.set(entry, str(key::ground), str(ground));
	state.set(entry, str(key::side), str(side));
	state.set(entry, str(key::cells), array_value(gd::duplicate_array(state, cells)));
	const int64_t round = gd::int_field(state, battle, key::round, 1);
	if (ground == key::trap) {
		state.set(entry, str(key::until_round), int_value(GROUND_FOREVER));
	} else {
		const int64_t rounds = spell_effect_turns(state, hero, effect, spell, ground == key::pillar ? key::buff : key::debuff, power);
		state.set(entry, str(key::rounds), int_value(rounds));
		state.set(entry, str(key::until_round), int_value(gd::sub(gd::add(round, rounds), 1)));
	}
	if (gd::int_field(state, effect, key::base_damage, 0) > 0) {
		state.set(entry, str(key::damage), int_value(_battle_spell_damage_at(state, hero, spell, state.new_dict(), against)));
	}
	if (ground == key::pillar) {
		state.set(entry, str(key::defense), int_value(engine_max<int64_t>(0, gd::int_field(state, effect, key::defense, 0))));
	}
	if (ground == key::trap) {
		const DictRef status = _status_effect_from_spell_effect_at(state, spell, battle, hero, against);
		if (!gd::is_empty(state, status)) {
			state.set(entry, str(key::status), dict_value(status));
		}
	}
	return entry;
}

void add_ground(State &state, DictRef battle, DictRef entry) {
	const Atom ground = gd::string_field(state, entry, key::ground, key::empty);
	uint8_t taken[CELL_COUNT];
	mark_cells(state, { entry }, taken);
	// The new entry takes its hexes from older ones of its kind; what no longer holds goes.
	const ArrayRef kept = state.new_array();
	const ArrayRef entries = raw_entries(state, battle);
	if (entries != NONE) {
		for (const Value &old : gd::items(state, array_value(entries))) {
			if (!entry_holds(state, battle, old)) {
				continue;
			}
			if (gd::string_field(state, old.ref, key::ground, key::empty) == ground) {
				const ArrayRef left = state.new_array();
				for (const Value &cell : gd::field_items(state, old.ref, str(key::cells))) {
					const int64_t id = cell_id_of(state, cell);
					if (id >= 0 && taken[id] == 0) {
						state.append(left, cell);
					}
				}
				if (state.array_size(left) == 0) {
					continue;
				}
				state.set(old.ref, str(key::cells), array_value(left));
			}
			state.append(kept, old);
		}
	}
	const int64_t serial = gd::add(gd::int_field(state, battle, key::spell_ground_serial, 0), 1);
	state.set(battle, str(key::spell_ground_serial), int_value(serial));
	state.set(entry, str(key::id), str(gd::format(state, key::ground_id_format, { int_value(serial) })));
	state.append(kept, dict_value(entry));
	store_entries(state, battle, kept);
}

int64_t ground_damage_against(State &state, DictRef battle, DictRef entry, DictRef stack) {
	return gd::is_empty(state, entry) || gd::is_empty(state, stack) ? 0 : ground_damage_to(state, battle, entry, stack);
}

bool has_ground(State &state, DictRef battle, Atom ground) {
	return !holding(state, battle, ground).empty();
}

void add_pillar_blockers(State &state, DictRef battle, DictRef blocked) {
	for (const DictRef entry : holding(state, battle, key::pillar)) {
		const Atom blocker = state.joined_atom(key::obstacle_prefix, gd::string_field(state, entry, key::id, key::empty));
		for (const Value &cell : gd::field_items(state, entry, str(key::cells))) {
			const DictRef normalized = battle_rules::_normalize_hex_cell(state, cell);
			if (!gd::is_empty(state, normalized)) {
				state.set(blocked, str(battle_rules::_hex_key(state, normalized)), str(blocker));
			}
		}
	}
}

bool bramble_stop_mask(State &state, DictRef battle, DictRef stack, uint8_t *stop) {
	const std::vector<DictRef> brambles = holding(state, battle, key::bramble_ground);
	if (brambles.empty()) {
		return false;
	}
	uint8_t marked[CELL_COUNT];
	mark_cells(state, brambles, marked);
	body_mask(marked, body_of(state, stack), stop);
	return true;
}

int64_t pillar_defense(State &state, DictRef battle, DictRef stack) {
	if (gd::is_empty(state, battle) || gd::is_empty(state, stack)) {
		return 0;
	}
	int64_t best = 0;
	for (const DictRef entry : holding(state, battle, key::pillar)) {
		if (gd::string_field(state, entry, key::side, key::empty) != side_of(state, stack)) {
			continue;
		}
		for (const Value &cell : gd::field_items(state, entry, str(key::cells))) {
			if (body_distance_to(state, stack, cell) == 1) {
				best = engine_max<int64_t>(best, gd::int_field(state, entry, key::defense, 0));
			}
		}
	}
	return best;
}

bool in_murk(State &state, DictRef battle, DictRef stack) {
	if (gd::is_empty(state, battle) || gd::is_empty(state, stack)) {
		return false;
	}
	const std::vector<DictRef> murk = holding(state, battle, key::murk);
	return !murk.empty() && entry_under(state, murk, stack) != NONE;
}

ArrayRef ground_walk_path(State &state, DictRef battle, DictRef stack, DictRef start, DictRef destination, int64_t max_steps) {
	const ArrayRef path = state.new_array();
	const int64_t from = cell_id_of(state, dict_value(start));
	const int64_t to = cell_id_of(state, dict_value(destination));
	if (from < 0 || to < 0 || max_steps <= 0) {
		return path;
	}
	if (from == to) {
		state.append(path, dict_value(battle_rules::_hex_cell(state, from / hex::kRows, from % hex::kRows)));
		return path;
	}
	const DictRef occupied = battle_rules::_build_blocking_map(state, battle);
	uint8_t open[CELL_COUNT];
	battle_rules::_hex_open_mask(state, stack, occupied, open);
	open[from] = 1;
	const hex::Body body = body_of(state, stack);
	uint8_t fit[CELL_COUNT];
	hex::fit_mask(open, body, fit);
	uint8_t burning_cells[CELL_COUNT];
	mark_cells(state, holding(state, battle, key::fire_ground), burning_cells);
	uint8_t burn[CELL_COUNT];
	body_mask(burning_cells, body, burn);
	uint8_t stop[CELL_COUNT];
	const bool stops = bramble_stop_mask(state, battle, stack, stop);
	// Layer by steps: the fewest burning hexes met on the way to each hex.
	const int64_t layers = engine_min<int64_t>(max_steps, CELL_COUNT) + 1;
	std::vector<int32_t> best(static_cast<size_t>(layers * CELL_COUNT), FAR);
	std::vector<int16_t> parent(static_cast<size_t>(layers * CELL_COUNT), -1);
	best[static_cast<size_t>(from)] = 0;
	const hex::NeighborList *neighbors = hex::neighbor_table();
	for (int64_t step = 0; step + 1 < layers; ++step) {
		for (int64_t id = 0; id < CELL_COUNT; ++id) {
			const int32_t cost = best[static_cast<size_t>(step * CELL_COUNT + id)];
			if (cost >= FAR || (step > 0 && stops && stop[id] != 0)) {
				continue;
			}
			const hex::NeighborList &around = neighbors[id];
			for (int32_t i = 0; i < around.count; ++i) {
				const int32_t next = around.ids[i];
				if (fit[next] == 0) {
					continue;
				}
				const size_t slot = static_cast<size_t>((step + 1) * CELL_COUNT + next);
				const int32_t next_cost = cost + burn[next];
				if (next_cost < best[slot]) {
					best[slot] = next_cost;
					parent[slot] = static_cast<int16_t>(id);
				}
			}
		}
	}
	int64_t best_step = -1;
	for (int64_t step = 1; step < layers; ++step) {
		const int32_t cost = best[static_cast<size_t>(step * CELL_COUNT + to)];
		if (cost < FAR && (best_step < 0 || cost < best[static_cast<size_t>(best_step * CELL_COUNT + to)])) {
			best_step = step;
		}
	}
	if (best_step < 0) {
		return path;
	}
	std::vector<int64_t> ids;
	int64_t id = to;
	for (int64_t step = best_step; step >= 0; --step) {
		ids.push_back(id);
		if (step > 0) {
			id = parent[static_cast<size_t>(step * CELL_COUNT + id)];
		}
	}
	for (auto it = ids.rbegin(); it != ids.rend(); ++it) {
		state.append(path, dict_value(battle_rules::_hex_cell(state, *it / hex::kRows, *it % hex::kRows)));
	}
	return path;
}

void after_ground_walk(State &state, DictRef battle, Atom battle_id, DictRef start) {
	if (raw_entries(state, battle) == NONE) {
		return;
	}
	const DictRef stack = battle_rules::_get_stack_by_id(state, battle, battle_id);
	if (gd::is_empty(state, stack) || _alive_count(state, stack) <= 0) {
		return;
	}
	const DictRef destination = battle_rules::_stack_hex(state, stack);
	// What the walk met, paid at the end of the stack's turn (after its strike).
	const DictRef met = state.new_dict();
	state.set(met, str(key::battle_id), str(battle_id));
	// Burning ground the walk crossed, the hex it ended on included.
	const std::vector<DictRef> fire = holding(state, battle, key::fire_ground);
	if (!fire.empty() && !gd::is_empty(state, start) && !gd::equal(state, dict_value(start), dict_value(destination))) {
		ArrayRef walk = ground_walk_path(state, battle, stack, start, destination, battle_rules::_stack_movement_points(state, stack, battle));
		if (state.array_size(walk) == 0) {
			walk = ground_walk_path(state, battle, stack, start, destination, CELL_COUNT);
		}
		const hex::Body body = body_of(state, stack);
		for (int64_t index = 1; index < state.array_size(walk) && !state.has(met, str(key::fire_ground)); ++index) {
			const int64_t id = cell_id_of(state, state.at(walk, index));
			if (id < 0) {
				continue;
			}
			for (const DictRef entry : fire) {
				bool covers = cell_in_entry(state, entry, id);
				if (!covers && body.width == 2) {
					const int64_t tail_q = id / hex::kRows + body.tail_step;
					covers = tail_q >= 0 && tail_q < hex::kColumns && cell_in_entry(state, entry, cell_id(tail_q, id % hex::kRows));
				}
				if (covers) {
					state.set(met, str(key::fire_ground), str(gd::string_field(state, entry, key::id, key::empty)));
					break;
				}
			}
		}
	}
	// Brambles where the walk ended.
	const DictRef bramble = entry_under(state, holding(state, battle, key::bramble_ground), stack);
	if (bramble != NONE) {
		state.set(met, str(key::bramble_ground), str(gd::string_field(state, bramble, key::id, key::empty)));
	}
	// Seeds of the other side next to where the walk ended.
	const ArrayRef seeds = state.new_array();
	for (const DictRef entry : holding(state, battle, key::trap)) {
		if (gd::string_field(state, entry, key::side, key::empty) == side_of(state, stack)) {
			continue;
		}
		for (const Value &cell : gd::field_items(state, entry, str(key::cells))) {
			if (body_distance_to(state, stack, cell) <= 1) {
				state.append(seeds, str(gd::string_field(state, entry, key::id, key::empty)));
				break;
			}
		}
	}
	if (state.array_size(seeds) > 0) {
		state.set(met, str(key::trap), array_value(seeds));
	}
	state.set(battle, str(key::_ground_walk), dict_value(met));
}

void end_of_turn_ground(State &state, DictRef battle, Atom battle_id) {
	Value met_value;
	const bool walked = state.lookup(battle, str(key::_ground_walk), met_value) && gd::is_dict(met_value)
			&& gd::string_field(state, met_value.ref, key::battle_id, key::empty) == battle_id;
	const DictRef met = walked ? gd::duplicate_dict(state, met_value.ref) : state.new_dict();
	if (state.has(battle, str(key::_ground_walk))) {
		state.erase(battle, str(key::_ground_walk));
	}
	if (raw_entries(state, battle) == NONE) {
		return;
	}
	const DictRef stack = battle_rules::_get_stack_by_id(state, battle, battle_id);
	if (gd::is_empty(state, stack) || _alive_count(state, stack) <= 0) {
		return;
	}
	const auto by_id = [&](Atom ground, Atom id) -> DictRef {
		for (const DictRef entry : holding(state, battle, ground)) {
			if (gd::string_field(state, entry, key::id, key::empty) == id) {
				return entry;
			}
		}
		return NONE;
	};
	// Burning ground: the one the walk crossed, else the one it stands in.
	const std::vector<DictRef> fire = holding(state, battle, key::fire_ground);
	DictRef burning = walked ? by_id(key::fire_ground, gd::string_field(state, met, key::fire_ground, key::empty)) : NONE;
	if (burning == NONE && !fire.empty()) {
		burning = entry_under(state, fire, stack);
	}
	if (burning != NONE) {
		hurt(state, battle, battle_id, burning, key::burning_ground_text);
	}
	if (!walked) {
		return;
	}
	const DictRef bramble = by_id(key::bramble_ground, gd::string_field(state, met, key::bramble_ground, key::empty));
	if (bramble != NONE) {
		hurt(state, battle, battle_id, bramble, key::brambles_hold_text);
	}
	for (const Value &seed_id : gd::field_items(state, met, str(key::trap))) {
		const DictRef seed = by_id(key::trap, gd::to_string(seed_id));
		const DictRef victim = battle_rules::_get_stack_by_id(state, battle, battle_id);
		if (seed == NONE || _alive_count(state, victim) <= 0) {
			continue;
		}
		remove_entry(state, battle, seed);
		const Atom label = battle_rules::_stack_label(state, victim);
		const int64_t damage = ground_damage_to(state, battle, seed, victim);
		if (damage > 0) {
			battle_rules::_apply_damage_to_stack(state, battle, battle_id, damage);
		}
		Atom line = gd::format(state, key::seed_springs_text, { str(label), int_value(damage) });
		Value status;
		if (_alive_count(state, battle_rules::_get_stack_by_id(state, battle, battle_id)) > 0 && state.lookup(seed, str(key::status), status)
				&& gd::is_dict(status) && !gd::is_empty(state, status.ref)) {
			const Atom status_id = gd::string_field(state, status.ref, key::effect_id, key::empty);
			const Atom status_label = ascii_lower(state, gd::string_field(state, status.ref, key::label, key::affected));
			if (target_is_immune_to_status(state, battle_rules::_get_stack_by_id(state, battle, battle_id), battle, status_id)) {
				line = concat(state, concat(state, line, key::space), gd::format(state, key::is_immune_to_format, { str(label), str(status_label) }));
			} else {
				battle_rules::_apply_stack_effect(state, battle, battle_id, dict_value(gd::deep_duplicate_dict(state, status.ref)));
				line = concat(state, line, gd::format(state, key::stack_is_suffix_text, { str(label), str(status_label) }));
			}
		}
		battle_rules::_record_event(state, battle, line);
	}
}

} // namespace aurelion::rules::port::spell_rules
