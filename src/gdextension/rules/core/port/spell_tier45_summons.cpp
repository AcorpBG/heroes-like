// Layer 8: the tier-4 and tier-5 battle spells that put stacks on the field (docs/magic-system-spells.md). Foundry
// Golem builds a two-hex summon beside the caster's stacks, as tier 3's summons stand; Wraith Host's flying host
// takes any empty hex and the one beside it, in two stacks; Clockwork Twin copies one of the caster's stacks beside
// it; Waking Forest raises an elder treant beside the caster's stacks and grows trees beside it for the rest of the
// battle; Drowned Host raises every stack destroyed so far, either side's, as Risen; Hollow Crown raises each enemy
// stack destroyed from its cast on, as the next round starts.
#include "aurelion_rules/port/spell_rules.hpp"

#include "aurelion_rules/battle_hex.hpp"
#include "aurelion_rules/compat/godot_math.hpp"
#include "aurelion_rules/port/battle_footprint.hpp"
#include "aurelion_rules/port/battle_payload.hpp"
#include "aurelion_rules/port/battle_rules.hpp"

#include <algorithm>
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

Atom side_of(const State &state, DictRef stack) {
	return gd::string_field(state, stack, key::side, key::empty);
}

Atom battle_id_of(const State &state, DictRef stack) {
	return gd::string_field(state, stack, key::battle_id, key::empty);
}

bool living(State &state, DictRef stack) {
	return !gd::is_empty(state, stack) && _alive_count(state, stack) > 0;
}

DictRef effect_of(State &state, DictRef spell) {
	const Value effect = gd::is_empty(state, spell) ? Value() : gd::field(state, spell, key::effect);
	return gd::is_dict(effect) ? effect.ref : state.new_dict();
}

Atom kind_of(State &state, DictRef spell) {
	return gd::string_field(state, effect_of(state, spell), key::conjure, key::empty);
}

// A stack of the unit for the side, as it would stand: not yet on the field and without a battle id of its own.
DictRef body_for(State &state, Atom unit_id, Atom side, int64_t count) {
	if (unit_id == key::empty) {
		return state.new_dict();
	}
	const DictRef stack = battle_rules::_build_battle_stack(state, unit_id, engine_max<int64_t>(1, count), side, 0, state.new_dict(), -1);
	if (!gd::is_empty(state, stack)) {
		state.set(stack, str(key::battle_id), str(key::empty));
	}
	return stack;
}

DictRef cell_at(State &state, int64_t id) {
	return battle_rules::_hex_cell(state, id / hex::kRows, id % hex::kRows);
}

int64_t cell_id(State &state, DictRef cell) {
	if (gd::is_empty(state, cell)) {
		return -1;
	}
	const int64_t q = gd::int_field(state, cell, key::q, -1);
	const int64_t r = gd::int_field(state, cell, key::r, -1);
	return battle_rules::_hex_in_bounds(q, r) ? q * hex::kRows + r : -1;
}

bool fits_at(State &state, DictRef body, int64_t id, DictRef occupied) {
	return battle_footprint::fits(state, body, dict_value(cell_at(state, id)), occupied, hex::kColumns, hex::kRows);
}

// The body's cells at the hex marked taken, so that no later stack of the same cast stands on them.
void take_cells(State &state, DictRef occupied, DictRef body, DictRef cell) {
	for (const Value &taken : gd::items(state, array_value(battle_footprint::cells(state, body, dict_value(cell))))) {
		if (gd::is_dict(taken)) {
			state.set(occupied, str(battle_rules::_hex_key(state, taken.ref)), str(key::conjured));
		}
	}
}

// The body's distance at the hex to the nearest living stack of the other side (far when there is none).
int64_t foe_distance(State &state, DictRef battle, DictRef body, DictRef cell, Atom side) {
	int64_t nearest = hex::kFarDistance;
	for (const Value &foe : gd::items(state, array_value(battle_rules::_alive_stacks_for_side(state, battle, battle_rules::_opposing_side(side))))) {
		if (gd::is_dict(foe)) {
			nearest = engine_min<int64_t>(nearest, battle_footprint::distance(state, body, foe.ref, dict_value(cell)));
		}
	}
	return nearest;
}

// The body's own hex when it fits there, else the nearest hex it fits on (board order among the nearest); {} when none.
DictRef nearest_fit_cell(State &state, DictRef body, DictRef from, DictRef occupied) {
	const int64_t start = cell_id(state, from);
	if (start >= 0 && fits_at(state, body, start, occupied)) {
		return cell_at(state, start);
	}
	DictRef best = state.new_dict();
	int64_t best_distance = 0;
	for (int64_t id = 0; id < hex::kCellCount; ++id) {
		if (!fits_at(state, body, id, occupied)) {
			continue;
		}
		const DictRef cell = cell_at(state, id);
		const int64_t distance = start >= 0 ? battle_rules::_hex_distance(state, from, cell) : 0;
		if (gd::is_empty(state, best) || distance < best_distance) {
			best = cell;
			best_distance = distance;
		}
	}
	return best;
}

// A stack destroyed in this battle that can rise: never conjured, not raised before, with a starting count.
bool can_rise(State &state, DictRef stack) {
	return !gd::is_empty(state, stack) && _alive_count(state, stack) <= 0 && !is_conjured(state, stack) && !gd::bool_field(state, stack, key::raised, false)
			&& gd::int_field(state, stack, key::base_count, 0) > 0;
}

// A Risen of the fallen stack for the side: its unit with the share of its starting creatures, whole, on the fallen's
// hex or the nearest one its body fits; {} when none fits. Its cells are marked taken.
DictRef risen_of(State &state, DictRef fallen, Atom side, int64_t pct, int64_t until_round, Atom spell_id, DictRef occupied) {
	const Atom unit_id = gd::string_field(state, fallen, key::unit_id, key::empty);
	const int64_t count = engine_max<int64_t>(1, compat::int_div(gd::mul(gd::int_field(state, fallen, key::base_count, 0), pct), 100));
	const DictRef stack = body_for(state, unit_id, side, count);
	if (gd::is_empty(state, stack)) {
		return stack;
	}
	const DictRef cell = nearest_fit_cell(state, stack, battle_rules::_stack_hex(state, fallen), occupied);
	if (gd::is_empty(state, cell)) {
		return state.new_dict();
	}
	state.set(stack, str(key::name), str(gd::format(state, key::risen_name_text, { str(gd::string_field(state, fallen, key::name, unit_id)) })));
	state.set(stack, str(key::risen_from), str(battle_id_of(state, fallen)));
	state.set(stack, str(key::conjured), bool_value(true));
	state.set(stack, str(key::conjured_by_spell), str(spell_id));
	state.set(stack, str(key::conjured_until_round), int_value(until_round));
	state.set(stack, str(key::army_slot_index), int_value(-1));
	state.set(stack, str(key::hex), dict_value(cell));
	take_cells(state, occupied, stack, cell);
	return stack;
}

// A spell's share at the hero's power for it, 1 to 100.
int64_t share_at(State &state, DictRef spell, DictRef hero) {
	const DictRef effect = effect_of(state, spell);
	const int64_t pct = gd::add(gd::int_field(state, effect, key::pct, 0), gd::mul(gd::int_field(state, effect, key::pct_power_scale, 0), spell_power(state, hero, spell)));
	return engine_max<int64_t>(1, engine_min<int64_t>(100, pct));
}

} // namespace

bool conjures_over_battle(State &state, DictRef spell) {
	if (gd::string_field(state, effect_of(state, spell), key::type, key::empty) != key::conjure) {
		return false;
	}
	const Atom kind = kind_of(state, spell);
	return kind == key::elder || kind == key::risen_all;
}

int64_t conjure_share_pct(State &state, DictRef hero, DictRef spell) {
	return share_at(state, spell, hero);
}

DictRef elder_cell(State &state, DictRef battle, DictRef spell, Atom side) {
	const DictRef body = body_for(state, gd::string_field(state, effect_of(state, spell), key::unit_id, key::empty), side, 1);
	if (gd::is_empty(state, body) || gd::is_empty(state, battle)) {
		return state.new_dict();
	}
	const DictRef occupied = battle_rules::_build_blocking_map(state, battle);
	DictRef best = state.new_dict();
	int64_t best_distance = 0;
	for (int64_t id = 0; id < hex::kCellCount; ++id) {
		if (!fits_at(state, body, id, occupied)) {
			continue;
		}
		const DictRef cell = cell_at(state, id);
		bool beside = false;
		for (const Value &stack : gd::field_items(state, battle, str(key::stacks))) {
			if (gd::is_dict(stack) && side_of(state, stack.ref) == side && living(state, stack.ref) && !is_decoy(state, stack.ref)
					&& battle_footprint::distance(state, body, stack.ref, dict_value(cell)) == 1) {
				beside = true;
				break;
			}
		}
		if (!beside) {
			continue;
		}
		const int64_t distance = foe_distance(state, battle, body, cell, side);
		if (gd::is_empty(state, best) || distance < best_distance) {
			best = cell;
			best_distance = distance;
		}
	}
	return best;
}

ArrayRef forest_tree_cells(State &state, DictRef battle, DictRef treant, int64_t count) {
	const ArrayRef cells = state.new_array();
	if (count <= 0 || gd::is_empty(state, treant) || gd::is_empty(state, battle)) {
		return cells;
	}
	const DictRef occupied = battle_rules::_build_blocking_map(state, battle);
	take_cells(state, occupied, treant, battle_rules::_stack_hex(state, treant));
	// The empty hexes next to the treant, those nearest the closest enemy stack first (board order among equals).
	std::vector<int64_t> beside;
	for (const Value &own : gd::items(state, array_value(battle_footprint::cells(state, treant, Value())))) {
		if (!gd::is_dict(own)) {
			continue;
		}
		for (const Value &next : gd::items(state, array_value(battle_rules::_hex_neighbors(state, own.ref)))) {
			const int64_t id = gd::is_dict(next) ? cell_id(state, next.ref) : -1;
			if (id >= 0 && !state.has(occupied, str(battle_rules::_hex_key(state, next.ref))) && std::find(beside.begin(), beside.end(), id) == beside.end()) {
				beside.push_back(id);
			}
		}
	}
	const ArrayRef foes = battle_rules::_alive_stacks_for_side(state, battle, battle_rules::_opposing_side(side_of(state, treant)));
	std::vector<std::pair<int64_t, int64_t>> ranked;
	for (const int64_t id : beside) {
		int64_t nearest = hex::kFarDistance;
		const DictRef cell = cell_at(state, id);
		for (const Value &foe : gd::items(state, array_value(foes))) {
			if (gd::is_dict(foe)) {
				nearest = engine_min<int64_t>(nearest, battle_rules::_hex_distance(state, cell, battle_rules::_stack_hex(state, foe.ref)));
			}
		}
		ranked.emplace_back(nearest, id);
	}
	std::sort(ranked.begin(), ranked.end());
	// Each tree stands only where the field stays open around the obstacles already there.
	const DictRef standing = battle_rules::_obstacle_cell_map(state, battle);
	for (const auto &[distance, id] : ranked) {
		if (state.array_size(cells) >= count) {
			break;
		}
		const DictRef cell = cell_at(state, id);
		const DictRef trial = gd::duplicate_dict(state, standing);
		state.set(trial, str(battle_rules::_hex_key(state, cell)), str(key::obstacle_prefix));
		if (!battle_rules::_obstacle_field_stays_open(state, trial)) {
			continue;
		}
		state.set(standing, str(battle_rules::_hex_key(state, cell)), str(key::obstacle_prefix));
		state.append(cells, dict_value(cell));
	}
	return cells;
}

void grow_trees(State &state, DictRef battle, ArrayRef cells) {
	if (gd::is_empty(state, battle) || state.array_size(cells) == 0) {
		return;
	}
	Value obstacles = gd::field(state, battle, key::obstacles);
	if (!gd::is_array(obstacles)) {
		obstacles = array_value(state.new_array());
		state.set(battle, str(key::obstacles), obstacles);
	}
	for (const Value &cell : gd::items(state, array_value(cells))) {
		if (!gd::is_dict(cell)) {
			continue;
		}
		const int64_t serial = gd::add(gd::int_field(state, battle, key::tree_serial, 0), 1);
		state.set(battle, str(key::tree_serial), int_value(serial));
		const DictRef tree = state.new_dict();
		state.set(tree, str(key::id), str(gd::format(state, key::tree_id_format, { int_value(serial) })));
		state.set(tree, str(key::kind), str(key::deadwood));
		state.set(tree, str(key::size), int_value(1));
		state.set(tree, str(key::variant), int_value(0));
		const ArrayRef tree_cells = state.new_array();
		state.append(tree_cells, dict_value(battle_rules::_hex_cell(state, gd::int_field(state, cell.ref, key::q, -1), gd::int_field(state, cell.ref, key::r, -1))));
		state.set(tree, str(key::cells), array_value(tree_cells));
		state.append(obstacles.ref, dict_value(tree));
	}
	battle_rules::_sync_occupied_hexes(state, battle);
	battle_rules::_sync_distance_from_hexes(state, battle);
}

ArrayRef conjured_host(State &state, DictRef battle, DictRef first, DictRef spell, Atom side) {
	const ArrayRef host = state.new_array();
	if (gd::is_empty(state, first)) {
		return host;
	}
	state.append(host, dict_value(first));
	const int64_t health = gd::int_field(state, first, key::total_health, 0);
	const int64_t unit_hp = engine_max<int64_t>(1, gd::int_field(state, first, key::unit_hp, 1));
	if (gd::int_field(state, effect_of(state, spell), key::stacks, 1) < 2 || health < gd::mul(2, unit_hp)) {
		return host;
	}
	// The second stack: on the empty hex nearest the first that its body fits, nearest the closest enemy among those.
	const DictRef occupied = battle_rules::_build_blocking_map(state, battle);
	const DictRef from = battle_rules::_stack_hex(state, first);
	take_cells(state, occupied, first, from);
	DictRef best = state.new_dict();
	int64_t best_step = 0;
	int64_t best_foe = 0;
	for (int64_t id = 0; id < hex::kCellCount; ++id) {
		if (!fits_at(state, first, id, occupied)) {
			continue;
		}
		const DictRef cell = cell_at(state, id);
		const int64_t step = battle_rules::_hex_distance(state, from, cell);
		const int64_t foe = foe_distance(state, battle, first, cell, side);
		if (gd::is_empty(state, best) || step < best_step || (step == best_step && foe < best_foe)) {
			best = cell;
			best_step = step;
			best_foe = foe;
		}
	}
	if (gd::is_empty(state, best)) {
		return host;
	}
	// The health shared out, the first stack the larger half.
	const DictRef second = gd::deep_duplicate_dict(state, first);
	const int64_t second_health = compat::int_div(health, 2);
	const int64_t first_health = gd::sub(health, second_health);
	state.set(first, str(key::total_health), int_value(first_health));
	state.set(first, str(key::base_count), int_value(compat::int_div(gd::add(first_health, gd::sub(unit_hp, 1)), unit_hp)));
	state.set(second, str(key::total_health), int_value(second_health));
	state.set(second, str(key::base_count), int_value(compat::int_div(gd::add(second_health, gd::sub(unit_hp, 1)), unit_hp)));
	state.set(second, str(key::hex), dict_value(best));
	state.append(host, dict_value(second));
	return host;
}

ArrayRef risen_host_for_cast(State &state, DictRef hero, DictRef battle, DictRef spell, Atom side) {
	const ArrayRef host = state.new_array();
	if (gd::is_empty(state, battle)) {
		return host;
	}
	const DictRef effect = effect_of(state, spell);
	const int64_t round = gd::int_field(state, battle, key::round, 1);
	const int64_t rounds = spell_effect_turns(state, hero, effect, spell, key::buff, spell_power(state, hero, spell));
	const int64_t pct = share_at(state, spell, hero);
	const Atom spell_id = gd::string_field(state, spell, key::id, key::empty);
	std::vector<DictRef> fallen;
	for (const Value &stack : gd::field_items(state, battle, str(key::stacks))) {
		if (gd::is_dict(stack) && can_rise(state, stack.ref)) {
			fallen.push_back(stack.ref);
		}
	}
	// They act from the next round, for their rounds.
	const DictRef occupied = battle_rules::_build_blocking_map(state, battle);
	for (const DictRef stack : fallen) {
		const DictRef risen = risen_of(state, stack, side, pct, gd::add(round, rounds), spell_id, occupied);
		if (!gd::is_empty(state, risen)) {
			state.append(host, dict_value(risen));
		}
	}
	return host;
}

Atom battle_conjure_refusal(State &state, DictRef battle, DictRef spell, Atom side) {
	const Atom kind = kind_of(state, spell);
	if (kind == key::elder && gd::is_empty(state, elder_cell(state, battle, spell, side))) {
		return gd::format(state, key::no_hex_for_spell_text, { str(gd::string_field(state, spell, key::name, key::spell_word)) });
	}
	if (kind == key::risen_all) {
		for (const Value &stack : gd::field_items(state, battle, str(key::stacks))) {
			if (gd::is_dict(stack) && can_rise(state, stack.ref)) {
				return key::empty;
			}
		}
		return key::nothing_fallen_text;
	}
	return key::empty;
}

bool hollow_crown_held(State &state, DictRef battle, Atom side) {
	const int64_t round = gd::int_field(state, battle, key::round, 1);
	for (const Value &aura : gd::field_items(state, battle, str(key::spell_auras))) {
		if (gd::is_dict(aura) && gd::string_field(state, aura.ref, key::aura, key::empty) == key::hollow_crown && side_of(state, aura.ref) == side
				&& gd::int_field(state, aura.ref, key::until_round, 0) >= round) {
			return true;
		}
	}
	return false;
}

void crown_marks(State &state, DictRef battle, Atom side) {
	// The other side's stacks fallen before the cast do not rise.
	for (const Value &stack : gd::field_items(state, battle, str(key::stacks))) {
		if (gd::is_dict(stack) && side_of(state, stack.ref) != side && _alive_count(state, stack.ref) <= 0) {
			state.set(stack.ref, str(key::crown_passed), bool_value(true));
		}
	}
}

void crown_rises(State &state, DictRef battle, DictRef aura) {
	const Atom side = side_of(state, aura);
	std::vector<DictRef> fallen;
	for (const Value &stack : gd::field_items(state, battle, str(key::stacks))) {
		if (gd::is_dict(stack) && side_of(state, stack.ref) != side && side_of(state, stack.ref) != key::empty && can_rise(state, stack.ref)
				&& !gd::bool_field(state, stack.ref, key::crown_passed, false)) {
			fallen.push_back(stack.ref);
		}
	}
	if (fallen.empty()) {
		return;
	}
	// They rise as the round starts and act in it, for their rounds.
	const int64_t round = gd::int_field(state, battle, key::round, 1);
	const int64_t until = gd::sub(gd::add(round, engine_max<int64_t>(1, gd::int_field(state, aura, key::rounds, 1))), 1);
	const int64_t pct = engine_max<int64_t>(1, engine_min<int64_t>(100, gd::int_field(state, aura, key::pct, 1)));
	const Atom label = gd::string_field(state, aura, key::label, key::empty);
	const DictRef occupied = battle_rules::_build_blocking_map(state, battle);
	for (const DictRef stack : fallen) {
		const DictRef risen = risen_of(state, stack, side, pct, until, gd::string_field(state, aura, key::spell_id, key::empty), occupied);
		if (gd::is_empty(state, risen)) {
			continue;
		}
		const Atom id = add_conjured_stack(state, battle, risen);
		const DictRef added = battle_rules::_get_stack_by_id(state, battle, id);
		if (!gd::is_empty(state, added)) {
			battle_rules::_record_event(state, battle, gd::format(state, key::crown_rises_text, { str(label), str(battle_rules::_stack_label(state, added)), int_value(_alive_count(state, added)) }));
		}
	}
}

} // namespace aurelion::rules::port::spell_rules
