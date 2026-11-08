// Layer 8: the tier-2 spells that take a hex (docs/magic-system-spells.md). Flame Furrow burns up to 3 empty hexes
// in a row, Bramble Patch grows brambles on up to 3, Crystal Pillar raises a pillar on one, Murk lays fog on up to 3
// hexes and Thorn Seed plants a seed on one. A cast lays an entry on battle.spell_ground with its numbers fixed: the
// hexes, the caster's side, the last round it holds, and its damage, defense or status. The board reads the entries
// that still hold: a pillar blocks like an obstacle and lends defense to its side's stacks next to it, a walk stops in
// brambles and pays for them, a walk over burning ground burns once and a stack standing in it burns at the end of
// its turn, murk refuses shots into and out of it, and a seed goes off under the first stack of the other side that
// ends a walk next to it.
//
// Tier 3 adds four kinds: Living Wall's trees block like a pillar and halve shots whose line crosses them, Boundary
// Line's light closes its hexes to the other side's walks, Prism Array's crystal blocks its hex and fires at the
// nearest enemy stack each time its side's hero casts a damage spell, and Bog Pool's mire, for the rest of the
// battle, halves the speed of a stack standing in it and keeps it from bracing.
//
// A "line" is the picked hex and the hexes above and below it (q, r - 1) and (q, r + 1): three hexes across the
// field, each next to the one before; a longer line (Boundary Line's 4) runs one more hex down. A "blob" is the picked
// hex and the nearest hexes around it, in the board's neighbour order, up to the cast's count.

#include "aurelion_rules/port/spell_rules.hpp"

#include "aurelion_rules/battle_hex.hpp"
#include "aurelion_rules/compat/godot_math.hpp"
#include "aurelion_rules/port/battle_footprint.hpp"
#include "aurelion_rules/port/battle_rules.hpp"

#include <algorithm>
#include <cmath>
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

// The hexes a pick covers, with the board's blockers (obstacles and stacks) and its obstacles alone already known;
// count is a blob's size.
ArrayRef shape_cells(State &state, DictRef blocked, DictRef obstacles, DictRef spell, int64_t q, int64_t r, int64_t count) {
	const ArrayRef cells = state.new_array();
	if (!battle_rules::_hex_in_bounds(q, r)) {
		return cells;
	}
	const DictRef effect = effect_of(state, spell);
	const bool empty_only = gd::bool_field(state, effect, key::empty_only, false);
	const Atom shape = gd::string_field(state, effect, key::shape, key::single);
	// A blob never covers an obstacle's hex: no stack could ever stand there.
	const auto open = [&](int64_t cq, int64_t cr) {
		if (!battle_rules::_hex_in_bounds(cq, cr) || (empty_only && state.has(blocked, str(state.pair_atom(cq, cr))))) {
			return false;
		}
		return shape != key::blob || !state.has(obstacles, str(state.pair_atom(cq, cr)));
	};
	if (!open(q, r)) {
		return cells;
	}
	if (shape == key::blob) {
		std::vector<int64_t> taken{ cell_id(q, r) };
		const hex::NeighborList *neighbors = hex::neighbor_table();
		for (size_t index = 0; index < taken.size() && static_cast<int64_t>(taken.size()) < count; ++index) {
			const hex::NeighborList &around = neighbors[taken[index]];
			for (int32_t i = 0; i < around.count && static_cast<int64_t>(taken.size()) < count; ++i) {
				const int64_t next = around.ids[i];
				bool seen = false;
				for (const int64_t id : taken) {
					seen = seen || id == next;
				}
				if (!seen && open(next / hex::kRows, next % hex::kRows)) {
					taken.push_back(next);
				}
			}
		}
		for (const int64_t id : taken) {
			state.append(cells, dict_value(battle_rules::_hex_cell(state, id / hex::kRows, id % hex::kRows)));
		}
		return cells;
	}
	// An area: the picked hex and the six around it.
	if (shape == key::area) {
		state.append(cells, dict_value(battle_rules::_hex_cell(state, q, r)));
		const hex::NeighborList &around = hex::neighbor_table()[cell_id(q, r)];
		for (int32_t i = 0; i < around.count; ++i) {
			const int64_t next = around.ids[i];
			if (open(next / hex::kRows, next % hex::kRows)) {
				state.append(cells, dict_value(battle_rules::_hex_cell(state, next / hex::kRows, next % hex::kRows)));
			}
		}
		return cells;
	}
	const int64_t length = shape == key::line ? engine_max<int64_t>(1, gd::int_field(state, effect, key::length, 3)) : 1;
	const int64_t first = -compat::int_div(gd::sub(length, 1), 2);
	for (int64_t dr = first; dr < first + length; ++dr) {
		if (open(q, r + dr)) {
			state.append(cells, dict_value(battle_rules::_hex_cell(state, q, r + dr)));
		}
	}
	return cells;
}

// A blob's size at the hero's power (Bog Pool's {2+P/4}); 1 for the other shapes.
int64_t pick_count(State &state, DictRef spell, DictRef hero) {
	const DictRef effect = effect_of(state, spell);
	if (gd::string_field(state, effect, key::shape, key::single) != key::blob) {
		return 1;
	}
	return engine_max<int64_t>(1, power_count(state, effect, key::count, key::count_power_divisor, gd::is_empty(state, hero) ? 0 : spell_power(state, hero, spell)));
}

// The kinds that stand on their hexes and block them like an obstacle.
bool blocks_hexes(Atom ground) {
	return ground == key::pillar || ground == key::wall || ground == key::prism;
}

} // namespace

bool snare_ground(State &state, DictRef spell) {
	return !gd::is_empty(state, spell) && gd::string_field(state, effect_of(state, spell), key::ground, key::empty) == key::snare;
}

ArrayRef snared_stacks(State &state, DictRef battle, ArrayRef cells, Atom caster_side) {
	const ArrayRef caught = state.new_array();
	std::vector<int64_t> ids;
	for (const Value &cell : gd::items(state, array_value(cells))) {
		ids.push_back(cell_id_of(state, cell));
	}
	for (const Value &stack : gd::field_items(state, battle, str(key::stacks))) {
		if (!gd::is_dict(stack) || side_of(state, stack.ref) == caster_side || side_of(state, stack.ref) == key::empty || battle_rules::_alive_count(state, stack.ref) <= 0) {
			continue;
		}
		bool inside = false;
		for (const int64_t id : body_ids(state, stack.ref)) {
			for (const int64_t cell : ids) {
				inside = inside || cell == id;
			}
		}
		if (inside) {
			state.append(caught, dict_value(stack.ref));
		}
	}
	return caught;
}

bool takes_hex(State &state, DictRef spell) {
	return !gd::is_empty(state, spell) && gd::string_field(state, effect_of(state, spell), key::type, key::empty) == key::ground_effect;
}

ArrayRef ground_pick_cells(State &state, DictRef battle, DictRef spell) {
	const ArrayRef picks = state.new_array();
	if (!takes_hex(state, spell) || gd::is_empty(state, battle)) {
		return picks;
	}
	const DictRef blocked = battle_rules::_build_blocking_map(state, battle);
	const DictRef obstacles = battle_rules::_obstacle_cell_map(state, battle);
	for (int64_t q = 0; q < hex::kColumns; ++q) {
		for (int64_t r = 0; r < hex::kRows; ++r) {
			if (state.array_size(shape_cells(state, blocked, obstacles, spell, q, r, 1)) > 0) {
				state.append(picks, dict_value(battle_rules::_hex_cell(state, q, r)));
			}
		}
	}
	return picks;
}

ArrayRef ground_pick_shapes(State &state, DictRef battle, DictRef spell, DictRef hero) {
	const ArrayRef picks = state.new_array();
	if (!takes_hex(state, spell) || gd::is_empty(state, battle)) {
		return picks;
	}
	const DictRef blocked = battle_rules::_build_blocking_map(state, battle);
	const DictRef obstacles = battle_rules::_obstacle_cell_map(state, battle);
	const int64_t count = pick_count(state, spell, hero);
	for (int64_t q = 0; q < hex::kColumns; ++q) {
		for (int64_t r = 0; r < hex::kRows; ++r) {
			const ArrayRef cells = shape_cells(state, blocked, obstacles, spell, q, r, count);
			if (state.array_size(cells) > 0) {
				const DictRef pick = battle_rules::_hex_cell(state, q, r);
				state.set(pick, str(key::cells), array_value(cells));
				state.append(picks, dict_value(pick));
			}
		}
	}
	return picks;
}

ArrayRef ground_shape_cells(State &state, DictRef battle, DictRef spell, DictRef center, DictRef hero) {
	if (!takes_hex(state, spell) || gd::is_empty(state, battle) || gd::is_empty(state, center)) {
		return state.new_array();
	}
	const DictRef blocked = battle_rules::_build_blocking_map(state, battle);
	const DictRef obstacles = battle_rules::_obstacle_cell_map(state, battle);
	return shape_cells(state, blocked, obstacles, spell, gd::int_field(state, center, key::q, -1), gd::int_field(state, center, key::r, -1), pick_count(state, spell, hero));
}

DictRef ground_entry_for_cast(State &state, DictRef hero, DictRef battle, DictRef spell, Atom side, ArrayRef cells) {
	const DictRef effect = effect_of(state, spell);
	const Atom ground = gd::string_field(state, effect, key::ground, key::empty);
	const int64_t power = spell_power(state, hero, spell);
	// Damage and the seed's roots grow with power less the other side's Knowledge.
	const int64_t against = engine_max<int64_t>(0, gd::sub(power, opposing_side_knowledge(state, battle, side)));
	const DictRef entry = state.new_dict();
	state.set(entry, str(key::spell_id), str(gd::string_field(state, spell, key::id, key::empty)));
	state.set(entry, str(key::ground), str(ground));
	state.set(entry, str(key::side), str(side));
	state.set(entry, str(key::cells), array_value(gd::duplicate_array(state, cells)));
	const int64_t round = gd::int_field(state, battle, key::round, 1);
	// A seed waits until it goes off; mire lasts the battle.
	if (ground == key::trap || gd::bool_field(state, effect, key::battle_long, false)) {
		state.set(entry, str(key::until_round), int_value(GROUND_FOREVER));
	} else {
		// A ward of its caster's (Glass Dome) lasts as a boost does.
		const int64_t rounds = spell_effect_turns(state, hero, effect, spell, blocks_hexes(ground) || ground == key::dome ? key::buff : key::debuff, power);
		state.set(entry, str(key::rounds), int_value(rounds));
		state.set(entry, str(key::until_round), int_value(gd::sub(gd::add(round, rounds), 1)));
	}
	if (gd::int_field(state, effect, key::base_damage, 0) > 0) {
		state.set(entry, str(key::damage), int_value(_battle_spell_damage_at(state, hero, spell, state.new_dict(), against)));
	}
	if (ground == key::pillar) {
		state.set(entry, str(key::defense), int_value(engine_max<int64_t>(0, gd::int_field(state, effect, key::defense, 0))));
	}
	// Elder Grove: its heal at the caster's power, and its defense.
	if (ground == key::grove) {
		state.set(entry, str(key::heal), int_value(_battle_spell_recovery_amount(state, hero, spell)));
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
	for (const DictRef entry : holding(state, battle, key::empty)) {
		if (!blocks_hexes(gd::string_field(state, entry, key::ground, key::empty))) {
			continue;
		}
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

int64_t grove_defense(State &state, DictRef battle, DictRef stack) {
	if (gd::is_empty(state, battle) || gd::is_empty(state, stack) || raw_entries(state, battle) == NONE) {
		return 0;
	}
	int64_t best = 0;
	for (const DictRef entry : holding(state, battle, key::grove)) {
		if (gd::string_field(state, entry, key::side, key::empty) == side_of(state, stack) && entry_under(state, { entry }, stack) != NONE) {
			best = engine_max<int64_t>(best, gd::int_field(state, entry, key::defense, 0));
		}
	}
	return best;
}

void grove_heal(State &state, DictRef battle, Atom battle_id) {
	if (raw_entries(state, battle) == NONE) {
		return;
	}
	const DictRef stack = battle_rules::_get_stack_by_id(state, battle, battle_id);
	if (gd::is_empty(state, stack) || _alive_count(state, stack) <= 0) {
		return;
	}
	// The best grove of its side under it.
	DictRef grove = NONE;
	for (const DictRef entry : holding(state, battle, key::grove)) {
		if (gd::string_field(state, entry, key::side, key::empty) == side_of(state, stack) && entry_under(state, { entry }, stack) != NONE
				&& (grove == NONE || gd::int_field(state, entry, key::heal, 0) > gd::int_field(state, grove, key::heal, 0))) {
			grove = entry;
		}
	}
	if (grove == NONE || gd::int_field(state, grove, key::heal, 0) <= 0) {
		return;
	}
	const Atom label = battle_rules::_stack_label(state, stack);
	const int64_t restored = battle_rules::_restore_stack_health(state, battle, battle_id, gd::int_field(state, grove, key::heal, 0));
	if (restored > 0) {
		battle_rules::_record_event(state, battle, gd::format(state, key::grove_heals_text, { str(label), int_value(restored) }));
	}
}

bool in_dome(State &state, DictRef battle, DictRef stack) {
	if (gd::is_empty(state, battle) || gd::is_empty(state, stack) || raw_entries(state, battle) == NONE) {
		return false;
	}
	const std::vector<DictRef> domes = holding(state, battle, key::dome);
	return !domes.empty() && entry_under(state, domes, stack) != NONE;
}

bool dome_keeps_off(State &state, DictRef battle, DictRef shooter, DictRef target) {
	if (gd::is_empty(state, battle) || gd::is_empty(state, target) || raw_entries(state, battle) == NONE) {
		return false;
	}
	for (const DictRef entry : holding(state, battle, key::dome)) {
		if (entry_under(state, { entry }, target) != NONE && (gd::is_empty(state, shooter) || entry_under(state, { entry }, shooter) == NONE)) {
			return true;
		}
	}
	return false;
}

void close_barrier_cells(State &state, DictRef battle, DictRef stack, uint8_t *open) {
	if (gd::is_empty(state, battle) || raw_entries(state, battle) == NONE) {
		return;
	}
	const Atom side = side_of(state, stack);
	for (const DictRef entry : holding(state, battle, key::barrier)) {
		if (gd::string_field(state, entry, key::side, key::empty) == side) {
			continue;
		}
		for (const Value &cell : gd::field_items(state, entry, str(key::cells))) {
			const int64_t id = cell_id_of(state, cell);
			if (id >= 0) {
				open[id] = 0;
			}
		}
	}
}

bool phase_pass_mask(State &state, DictRef battle, DictRef stack, uint8_t *pass) {
	// Fogwalk, or a stack that flies (Wraith Host's wraiths).
	if (gd::is_empty(state, battle) || gd::is_empty(state, stack)
			|| (!gd::bool_field(state, stack, key::flies, false) && stack_mechanic_int(state, stack, battle, key::phase) <= 0)) {
		return false;
	}
	for (int64_t id = 0; id < CELL_COUNT; ++id) {
		pass[id] = 1;
	}
	close_barrier_cells(state, battle, stack, pass);
	return true;
}

bool in_mire(State &state, DictRef battle, DictRef stack) {
	if (gd::is_empty(state, battle) || gd::is_empty(state, stack) || raw_entries(state, battle) == NONE) {
		return false;
	}
	const std::vector<DictRef> mire = holding(state, battle, key::mire);
	return !mire.empty() && entry_under(state, mire, stack) != NONE;
}

bool shot_crosses_wall(State &state, DictRef battle, DictRef shooter, DictRef target) {
	if (gd::is_empty(state, battle) || raw_entries(state, battle) == NONE) {
		return false;
	}
	const std::vector<DictRef> walls = holding(state, battle, key::wall);
	if (walls.empty()) {
		return false;
	}
	const int64_t from = cell_id_of(state, dict_value(battle_rules::_stack_hex(state, shooter)));
	const int64_t to = cell_id_of(state, dict_value(battle_rules::_stack_hex(state, target)));
	if (from < 0 || to < 0) {
		return false;
	}
	uint8_t marked[CELL_COUNT];
	mark_cells(state, walls, marked);
	for (const int64_t id : shot_line_cells(from, to)) {
		if (marked[id] != 0) {
			return true;
		}
	}
	return false;
}

std::vector<int64_t> shot_line_cells(int64_t from_id, int64_t to_id) {
	std::vector<int64_t> cells;
	if (from_id < 0 || to_id < 0 || from_id >= CELL_COUNT || to_id >= CELL_COUNT) {
		return cells;
	}
	// Cube coordinates of the offset rows, the line nudged so that a line along a hex edge takes one side.
	const auto cube = [](int64_t id, double &x, double &y, double &z) {
		const int64_t q = id / hex::kRows;
		const int64_t r = id % hex::kRows;
		x = static_cast<double>(q - (r - (r & 1)) / 2);
		z = static_cast<double>(r);
		y = -x - z;
	};
	double ax = 0.0, ay = 0.0, az = 0.0, bx = 0.0, by = 0.0, bz = 0.0;
	cube(from_id, ax, ay, az);
	cube(to_id, bx, by, bz);
	const int64_t steps = static_cast<int64_t>(std::llround(engine_max<double>(std::fabs(ax - bx), engine_max<double>(std::fabs(ay - by), std::fabs(az - bz)))));
	for (int64_t step = 1; step < steps; ++step) {
		const double t = static_cast<double>(step) / static_cast<double>(steps);
		const double x = ax + 1e-6 + (bx - ax) * t;
		const double y = ay + 2e-6 + (by - ay) * t;
		const double z = az - 3e-6 + (bz - az) * t;
		double rx = std::round(x);
		double ry = std::round(y);
		double rz = std::round(z);
		const double dx = std::fabs(rx - x);
		const double dy = std::fabs(ry - y);
		const double dz = std::fabs(rz - z);
		if (dx > dy && dx > dz) {
			rx = -ry - rz;
		} else if (dy > dz) {
			ry = -rx - rz;
		} else {
			rz = -rx - ry;
		}
		const int64_t r = static_cast<int64_t>(rz);
		const int64_t q = static_cast<int64_t>(rx) + (r - (r & 1)) / 2;
		if (battle_rules::_hex_in_bounds(q, r)) {
			cells.push_back(cell_id(q, r));
		}
	}
	return cells;
}

Atom fire_prisms(State &state, DictRef battle, Atom side, DictRef spell) {
	if (gd::is_empty(state, battle) || gd::is_empty(state, spell) || raw_entries(state, battle) == NONE) {
		return key::empty;
	}
	// Only a damage spell sets them off, and a new crystal does not set off the old ones.
	const Value categories = gd::field(state, spell, key::role_categories);
	if (!gd::is_array(categories) || !gd::array_has(state, categories.ref, str(key::damage))
			|| gd::string_field(state, effect_of(state, spell), key::ground, key::empty) == key::prism) {
		return key::empty;
	}
	Atom message = key::empty;
	for (const DictRef entry : holding(state, battle, key::prism)) {
		if (gd::string_field(state, entry, key::side, key::empty) != side) {
			continue;
		}
		Value cells;
		if (!state.lookup(entry, str(key::cells), cells) || !gd::is_array(cells) || state.array_size(cells.ref) == 0) {
			continue;
		}
		const Value crystal = state.at(cells.ref, 0);
		// The nearest enemy stack, in the stacks' order on a tie; Glass Aegis keeps it off.
		DictRef nearest = NONE;
		int64_t best = 999;
		for (const Value &other : gd::field_items(state, battle, str(key::stacks))) {
			if (!gd::is_dict(other) || side_of(state, other.ref) == side || side_of(state, other.ref) == key::empty
					|| _alive_count(state, other.ref) <= 0 || spell_shielded(state, battle, other.ref) || in_dome(state, battle, other.ref)) {
				continue;
			}
			const int64_t distance = body_distance_to(state, other.ref, crystal);
			if (distance < best) {
				best = distance;
				nearest = other.ref;
			}
		}
		if (nearest == NONE) {
			continue;
		}
		const Atom target_id = gd::string_field(state, nearest, key::battle_id, key::empty);
		const Atom line = hurt(state, battle, target_id, entry, key::prism_fires_text);
		if (line == key::empty) {
			continue;
		}
		message = concat(state, concat(state, message, key::space), line);
		const DictRef after = battle_rules::_get_stack_by_id(state, battle, target_id);
		if (!gd::is_empty(state, after) && _alive_count(state, after) <= 0) {
			message = concat(state, message, gd::format(state, key::stack_destroyed_suffix_text, { str(battle_rules::_stack_label(state, after)) }));
		}
	}
	return message;
}

namespace {

// A stack's walks from one hex, layered by steps: the fewest burning hexes met on the way to each hex within each
// step count, and the hex before it there.
struct WalkLayers {
	int64_t layers = 0;
	std::vector<int32_t> best;
	std::vector<int16_t> parent;

	// The walk to a hex, its start first: the fewest burning hexes, then the fewest steps; empty when the steps
	// reach none.
	std::vector<int64_t> walk_to(int64_t to) const {
		std::vector<int64_t> ids;
		int64_t best_step = -1;
		for (int64_t step = 1; step < layers; ++step) {
			const int32_t cost = best[static_cast<size_t>(step * CELL_COUNT + to)];
			if (cost < FAR && (best_step < 0 || cost < best[static_cast<size_t>(best_step * CELL_COUNT + to)])) {
				best_step = step;
			}
		}
		if (best_step < 0) {
			return ids;
		}
		int64_t id = to;
		for (int64_t step = best_step; step >= 0; --step) {
			ids.push_back(id);
			if (step > 0) {
				id = parent[static_cast<size_t>(step * CELL_COUNT + id)];
			}
		}
		std::reverse(ids.begin(), ids.end());
		return ids;
	}
};

WalkLayers walk_layers(State &state, DictRef battle, DictRef stack, int64_t from, int64_t max_steps) {
	const DictRef occupied = battle_rules::_build_blocking_map(state, battle);
	uint8_t open[CELL_COUNT];
	battle_rules::_hex_open_mask(state, stack, occupied, open);
	close_barrier_cells(state, battle, stack, open);
	// Fogwalk: the walk passes through stacks and obstacles to its free hex.
	phase_pass_mask(state, battle, stack, open);
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
	WalkLayers walk;
	walk.layers = engine_min<int64_t>(engine_max<int64_t>(0, max_steps), CELL_COUNT) + 1;
	walk.best.assign(static_cast<size_t>(walk.layers * CELL_COUNT), FAR);
	walk.parent.assign(static_cast<size_t>(walk.layers * CELL_COUNT), -1);
	walk.best[static_cast<size_t>(from)] = 0;
	const hex::NeighborList *neighbors = hex::neighbor_table();
	for (int64_t step = 0; step + 1 < walk.layers; ++step) {
		for (int64_t id = 0; id < CELL_COUNT; ++id) {
			const int32_t cost = walk.best[static_cast<size_t>(step * CELL_COUNT + id)];
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
				if (next_cost < walk.best[slot]) {
					walk.best[slot] = next_cost;
					walk.parent[slot] = static_cast<int16_t>(id);
				}
			}
		}
	}
	return walk;
}

// Per hex: the first of the entries (in the board's order) whose hexes the stack's body standing there covers, or -1.
std::vector<int32_t> first_under(State &state, const std::vector<DictRef> &entries, hex::Body body) {
	std::vector<int32_t> under(static_cast<size_t>(CELL_COUNT), -1);
	uint8_t marked[CELL_COUNT];
	uint8_t covered[CELL_COUNT];
	// Last to first, so that the first entry over a hex is the one kept.
	for (size_t index = entries.size(); index-- > 0;) {
		mark_cells(state, { entries[index] }, marked);
		body_mask(marked, body, covered);
		for (int64_t id = 0; id < CELL_COUNT; ++id) {
			if (covered[id] != 0) {
				under[static_cast<size_t>(id)] = static_cast<int32_t>(index);
			}
		}
	}
	return under;
}

} // namespace

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
	for (const int64_t id : walk_layers(state, battle, stack, from, max_steps).walk_to(to)) {
		state.append(path, dict_value(battle_rules::_hex_cell(state, id / hex::kRows, id % hex::kRows)));
	}
	return path;
}

GroundTolls::GroundTolls(State &state, DictRef battle, DictRef stack) {
	if (gd::is_empty(state, battle) || gd::is_empty(state, stack) || raw_entries(state, battle) == NONE || _alive_count(state, stack) <= 0) {
		return;
	}
	const std::vector<DictRef> fire = holding(state, battle, key::fire_ground);
	const std::vector<DictRef> brambles = holding(state, battle, key::bramble_ground);
	std::vector<DictRef> seeds;
	for (const DictRef entry : holding(state, battle, key::trap)) {
		if (gd::string_field(state, entry, key::side, key::empty) != side_of(state, stack)) {
			seeds.push_back(entry);
		}
	}
	const int64_t from = cell_id_of(state, dict_value(battle_rules::_stack_hex(state, stack)));
	if ((fire.empty() && brambles.empty() && seeds.empty()) || from < 0) {
		return;
	}
	const hex::Body body = body_of(state, stack);
	const std::vector<int32_t> fire_under = first_under(state, fire, body);
	const std::vector<int32_t> bramble_under = first_under(state, brambles, body);
	std::vector<int64_t> fire_damage;
	for (const DictRef entry : fire) {
		fire_damage.push_back(ground_damage_to(state, battle, entry, stack));
	}
	std::vector<int64_t> bramble_damage;
	for (const DictRef entry : brambles) {
		bramble_damage.push_back(ground_damage_to(state, battle, entry, stack));
	}
	// Each seed: its hexes, its damage and the status it would set.
	struct Seed {
		std::vector<hex::PlacedBody> cells;
		int64_t damage = 0;
		Atom status = key::empty;
	};
	std::vector<Seed> seed_rows;
	for (const DictRef entry : seeds) {
		Seed seed;
		for (const Value &cell : gd::field_items(state, entry, str(key::cells))) {
			const int64_t id = cell_id_of(state, cell);
			if (id >= 0) {
				seed.cells.push_back(hex::PlacedBody{ id / hex::kRows, id % hex::kRows, id / hex::kRows });
			}
		}
		seed.damage = ground_damage_to(state, battle, entry, stack);
		Value status;
		if (state.lookup(entry, str(key::status), status) && gd::is_dict(status) && !gd::is_empty(state, status.ref)) {
			const Atom status_id = gd::string_field(state, status.ref, key::effect_id, key::empty);
			if (status_id != key::empty && !target_is_immune_to_status(state, stack, battle, status_id)) {
				seed.status = status_id;
			}
		}
		seed_rows.push_back(seed);
	}
	// Fire: the walk the stack would take there, as after_ground_walk reads it.
	const WalkLayers walk = fire.empty() ? WalkLayers{} : walk_layers(state, battle, stack, from, battle_rules::_stack_movement_points(state, stack, battle));
	tolls_.assign(static_cast<size_t>(CELL_COUNT), WalkToll{});
	for (int64_t to = 0; to < CELL_COUNT; ++to) {
		WalkToll &toll = tolls_[static_cast<size_t>(to)];
		// Staying is no walk: only the fire it stands in at its turn's end.
		if (to == from) {
			if (fire_under[static_cast<size_t>(from)] >= 0) {
				toll.damage += fire_damage[static_cast<size_t>(fire_under[static_cast<size_t>(from)])];
			}
			continue;
		}
		if (!fire.empty()) {
			const std::vector<int64_t> ids = walk.walk_to(to);
			// With no walk in its steps, the fire it would end in.
			int32_t burning = ids.empty() ? fire_under[static_cast<size_t>(to)] : -1;
			for (size_t index = 1; index < ids.size() && burning < 0; ++index) {
				burning = fire_under[static_cast<size_t>(ids[index])];
			}
			if (burning >= 0) {
				toll.damage += fire_damage[static_cast<size_t>(burning)];
			}
		}
		if (bramble_under[static_cast<size_t>(to)] >= 0) {
			toll.damage += bramble_damage[static_cast<size_t>(bramble_under[static_cast<size_t>(to)])];
		}
		for (const Seed &seed : seed_rows) {
			bool beside = false;
			for (const hex::PlacedBody &cell : seed.cells) {
				beside = beside || hex::body_distance(to, body, cell) <= 1;
			}
			if (beside) {
				toll.damage += seed.damage;
				if (seed.status != key::empty) {
					toll.statuses.push_back(seed.status);
				}
			}
		}
	}
}

const WalkToll &GroundTolls::at(State &state, const Value &cell) const {
	const int64_t id = tolls_.empty() ? -1 : cell_id_of(state, cell);
	return id >= 0 ? tolls_[static_cast<size_t>(id)] : none_;
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
