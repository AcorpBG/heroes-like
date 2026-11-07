// Layer 8: tier 3's conjured stacks, Hour Ledger's rewind and Puppet Strings' charm (docs/magic-system-spells.md).
// A summon (Brass Sentinel, Wake the Grove) stands on an empty hex next to one of the caster's stacks, Raise the
// Fallen's Risen on the hex of a stack destroyed in this battle, and Decoy's copy on the empty hex beside its stack
// nearest the closest enemy stack. A conjured stack acts from the next round (a decoy never acts), lasts its rounds,
// counts for neither side's outcome and leaves no losses, survivors or corpse behind. A decoy vanishes when anything
// hurts it or the other side aims a harmful spell at it. Hour Ledger puts a stack back as it stood at the start of
// an earlier round, from the snapshots each round's start takes while a commander in the battle knows the spell.
// Puppet Strings makes an enemy stack strike or shoot a stack of its own side, with no strike-back and without
// spending its own turn.

#include "aurelion_rules/port/spell_rules.hpp"

#include "aurelion_rules/battle_hex.hpp"
#include "aurelion_rules/compat/godot_math.hpp"
#include "aurelion_rules/port/battle_footprint.hpp"
#include "aurelion_rules/port/battle_payload.hpp"
#include "aurelion_rules/port/battle_rules.hpp"

#include <string>

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

// Snapshots a stack keeps in Hour Ledger's ledger: more than any reach a hero has.
constexpr int64_t kLedgerRounds = 12;

Atom side_of(const State &state, DictRef stack) {
	return gd::string_field(state, stack, key::side, key::empty);
}

Atom battle_id_of(const State &state, DictRef stack) {
	return gd::string_field(state, stack, key::battle_id, key::empty);
}

bool alive(State &state, DictRef stack) {
	return !gd::is_empty(state, stack) && _alive_count(state, stack) > 0;
}

DictRef effect_of(State &state, DictRef spell) {
	const Value effect = gd::is_empty(state, spell) ? Value() : gd::field(state, spell, key::effect);
	return gd::is_dict(effect) ? effect.ref : state.new_dict();
}

Atom conjure_kind(State &state, DictRef spell) {
	return gd::string_field(state, effect_of(state, spell), key::conjure, key::empty);
}

bool same_cell(State &state, DictRef a, DictRef b) {
	return !gd::is_empty(state, a) && !gd::is_empty(state, b) && gd::int_field(state, a, key::q, -1) == gd::int_field(state, b, key::q, -2)
			&& gd::int_field(state, a, key::r, -1) == gd::int_field(state, b, key::r, -2);
}

// A stack of the unit for the side, as it would stand: not yet on the field and without a battle id of its own.
DictRef conjured_body(State &state, Atom unit_id, Atom side, int64_t count) {
	if (unit_id == key::empty) {
		return state.new_dict();
	}
	const DictRef stack = battle_rules::_build_battle_stack(state, unit_id, engine_max<int64_t>(1, count), side, 0, state.new_dict(), -1);
	if (!gd::is_empty(state, stack)) {
		state.set(stack, str(key::battle_id), str(key::empty));
	}
	return stack;
}

bool body_fits(State &state, DictRef body, DictRef cell, DictRef occupied) {
	return !gd::is_empty(state, body) && battle_footprint::fits(state, body, dict_value(cell), occupied, hex::kColumns, hex::kRows);
}

// The fallen stack Raise the Fallen raises on the hex: destroyed in this battle, never conjured, not raised before,
// with the Risen's body fitting there for the side; {} when none.
DictRef fallen_on(State &state, DictRef battle, DictRef cell, Atom side, DictRef occupied) {
	for (const Value &stack : gd::field_items(state, battle, str(key::stacks))) {
		if (!gd::is_dict(stack) || _alive_count(state, stack.ref) > 0 || is_conjured(state, stack.ref) || gd::bool_field(state, stack.ref, key::raised, false)
				|| gd::int_field(state, stack.ref, key::base_count, 0) <= 0) {
			continue;
		}
		const DictRef hex = battle_rules::_stack_hex(state, stack.ref);
		if (!same_cell(state, hex, cell)) {
			continue;
		}
		if (body_fits(state, conjured_body(state, gd::string_field(state, stack.ref, key::unit_id, key::empty), side, 1), cell, occupied)) {
			return stack.ref;
		}
	}
	return state.new_dict();
}

Atom vanish(State &state, DictRef battle, DictRef stack) {
	if (!alive(state, stack)) {
		return key::empty;
	}
	const Atom label = battle_rules::_stack_label(state, stack);
	state.set(stack, str(key::total_health), int_value(0));
	state.set(stack, str(key::budded_health), int_value(0));
	battle_rules::_sync_occupied_hexes(state, battle);
	battle_rules::_sync_distance_from_hexes(state, battle);
	return gd::format(state, is_decoy(state, stack) ? key::decoy_vanishes_text : key::conjured_fades_text, { str(label) });
}

} // namespace

// --- Conjured stacks ---------------------------------------------------------------

bool is_conjured(const State &state, DictRef stack) {
	return gd::bool_field(state, stack, key::conjured, false);
}

bool is_decoy(const State &state, DictRef stack) {
	return is_conjured(state, stack) && gd::string_field(state, stack, key::decoy_of, key::empty) != key::empty;
}

bool holds_field(State &state, DictRef battle, Atom side) {
	for (const Value &stack : gd::field_items(state, battle, str(key::stacks))) {
		if (gd::is_dict(stack) && side_of(state, stack.ref) == side && !is_conjured(state, stack.ref) && _alive_count(state, stack.ref) > 0) {
			return true;
		}
	}
	return false;
}

bool conjures_on_hex(State &state, DictRef spell) {
	if (gd::string_field(state, effect_of(state, spell), key::type, key::empty) != key::conjure) {
		return false;
	}
	const Atom kind = conjure_kind(state, spell);
	return kind == key::summon || kind == key::risen;
}

ArrayRef conjure_pick_cells(State &state, DictRef battle, DictRef spell, Atom side) {
	const ArrayRef cells = state.new_array();
	if (gd::is_empty(state, battle) || !conjures_on_hex(state, spell)) {
		return cells;
	}
	const DictRef occupied = battle_rules::_build_blocking_map(state, battle);
	if (conjure_kind(state, spell) == key::risen) {
		// The hexes of the fallen, each once.
		for (const Value &stack : gd::field_items(state, battle, str(key::stacks))) {
			if (!gd::is_dict(stack) || _alive_count(state, stack.ref) > 0) {
				continue;
			}
			const DictRef hex = battle_rules::_stack_hex(state, stack.ref);
			if (gd::is_empty(state, hex) || !battle_rules::_hex_in_bounds(gd::int_field(state, hex, key::q, -1), gd::int_field(state, hex, key::r, -1))) {
				continue;
			}
			bool listed = false;
			for (const Value &cell : gd::items(state, array_value(cells))) {
				listed = listed || same_cell(state, cell.ref, hex);
			}
			if (!listed && !gd::is_empty(state, fallen_on(state, battle, hex, side, occupied))) {
				state.append(cells, dict_value(battle_rules::_hex_cell(state, gd::int_field(state, hex, key::q, -1), gd::int_field(state, hex, key::r, -1))));
			}
		}
		return cells;
	}
	// A summon: the empty hexes its body fits on next to a living stack of the side (a decoy aside).
	const DictRef body = conjured_body(state, gd::string_field(state, effect_of(state, spell), key::unit_id, key::empty), side, 1);
	if (gd::is_empty(state, body)) {
		return cells;
	}
	for (int64_t q = 0; q < hex::kColumns; ++q) {
		for (int64_t r = 0; r < hex::kRows; ++r) {
			const DictRef cell = battle_rules::_hex_cell(state, q, r);
			if (!body_fits(state, body, cell, occupied)) {
				continue;
			}
			for (const Value &stack : gd::field_items(state, battle, str(key::stacks))) {
				if (gd::is_dict(stack) && side_of(state, stack.ref) == side && alive(state, stack.ref) && !is_decoy(state, stack.ref)
						&& battle_footprint::distance(state, body, stack.ref, dict_value(cell)) == 1) {
					state.append(cells, dict_value(cell));
					break;
				}
			}
		}
	}
	return cells;
}

ArrayRef conjure_shape_cells(State &state, DictRef battle, DictRef spell, DictRef center, Atom side) {
	for (const Value &cell : gd::items(state, array_value(conjure_pick_cells(state, battle, spell, side)))) {
		if (!same_cell(state, cell.ref, center)) {
			continue;
		}
		Atom unit_id = gd::string_field(state, effect_of(state, spell), key::unit_id, key::empty);
		if (conjure_kind(state, spell) == key::risen) {
			unit_id = gd::string_field(state, fallen_on(state, battle, center, side, battle_rules::_build_blocking_map(state, battle)), key::unit_id, key::empty);
		}
		return battle_footprint::cells(state, conjured_body(state, unit_id, side, 1), dict_value(cell.ref));
	}
	return state.new_array();
}

DictRef decoy_cell(State &state, DictRef battle, DictRef target) {
	if (!alive(state, target)) {
		return state.new_dict();
	}
	const DictRef body = conjured_body(state, gd::string_field(state, target, key::unit_id, key::empty), side_of(state, target), 1);
	const DictRef occupied = battle_rules::_build_blocking_map(state, battle);
	const ArrayRef foes = battle_rules::_alive_stacks_for_side(state, battle, battle_rules::_opposing_side(side_of(state, target)));
	DictRef best = state.new_dict();
	int64_t best_distance = 0;
	for (int64_t q = 0; q < hex::kColumns; ++q) {
		for (int64_t r = 0; r < hex::kRows; ++r) {
			const DictRef cell = battle_rules::_hex_cell(state, q, r);
			if (!body_fits(state, body, cell, occupied) || battle_footprint::distance(state, body, target, dict_value(cell)) != 1) {
				continue;
			}
			int64_t nearest = hex::kFarDistance;
			for (const Value &foe : gd::items(state, array_value(foes))) {
				if (gd::is_dict(foe)) {
					nearest = engine_min<int64_t>(nearest, battle_footprint::distance(state, body, foe.ref, dict_value(cell)));
				}
			}
			if (gd::is_empty(state, best) || nearest < best_distance) {
				best = cell;
				best_distance = nearest;
			}
		}
	}
	return best;
}

DictRef conjured_stack_for_cast(State &state, DictRef hero, DictRef battle, DictRef spell, Atom side, DictRef cell, DictRef target) {
	const DictRef effect = effect_of(state, spell);
	const Atom kind = conjure_kind(state, spell);
	const int64_t power = spell_power(state, hero);
	const int64_t round = gd::int_field(state, battle, key::round, 1);
	const int64_t rounds = spell_effect_turns(state, hero, effect, spell, key::buff, power);
	DictRef stack = state.new_dict();
	int64_t health = 0;
	if (kind == key::decoy) {
		// A copy of the stack: its creatures and health. It stands from now through its last round.
		if (!alive(state, target) || gd::is_empty(state, cell)) {
			return stack;
		}
		health = gd::int_field(state, target, key::total_health, 0);
		stack = conjured_body(state, gd::string_field(state, target, key::unit_id, key::empty), side, _alive_count(state, target));
		if (gd::is_empty(state, stack)) {
			return stack;
		}
		state.set(stack, str(key::name), str(gd::string_field(state, target, key::name, key::empty)));
		state.set(stack, str(key::decoy_of), str(battle_id_of(state, target)));
		state.set(stack, str(key::conjured_until_round), int_value(gd::sub(gd::add(round, rounds), 1)));
	} else {
		if (!conjures_on_hex(state, spell)) {
			return stack;
		}
		bool listed = false;
		for (const Value &pick : gd::items(state, array_value(conjure_pick_cells(state, battle, spell, side)))) {
			listed = listed || same_cell(state, pick.ref, cell);
		}
		if (!listed) {
			return stack;
		}
		health = engine_max<int64_t>(1, gd::add(gd::int_field(state, effect, key::base_health, 0), gd::mul(gd::int_field(state, effect, key::power_scale, 0), power)));
		Atom unit_id = gd::string_field(state, effect, key::unit_id, key::empty);
		DictRef fallen = state.new_dict();
		if (kind == key::risen) {
			// The Risen rise with no more creatures than the stack started the battle with.
			fallen = fallen_on(state, battle, cell, side, battle_rules::_build_blocking_map(state, battle));
			unit_id = gd::string_field(state, fallen, key::unit_id, key::empty);
			health = engine_min<int64_t>(health, gd::mul(gd::int_field(state, fallen, key::base_count, 0), engine_max<int64_t>(1, gd::int_field(state, fallen, key::unit_hp, 1))));
		}
		const DictRef unit = gd::content_row(state, state::ContentTable::Unit, unit_id);
		const int64_t unit_hp = engine_max<int64_t>(1, gd::int_field(state, unit, key::hp, 1));
		stack = conjured_body(state, unit_id, side, compat::int_div(gd::add(health, gd::sub(unit_hp, 1)), unit_hp));
		if (gd::is_empty(state, stack) || health <= 0) {
			return state.new_dict();
		}
		if (kind == key::risen) {
			state.set(stack, str(key::name), str(gd::format(state, key::risen_name_text, { str(gd::string_field(state, fallen, key::name, unit_id)) })));
			state.set(stack, str(key::risen_from), str(battle_id_of(state, fallen)));
		} else {
			const Atom name = gd::string_field(state, effect, key::name, key::empty);
			if (name != key::empty) {
				state.set(stack, str(key::name), str(name));
			}
			if (gd::bool_field(state, effect, key::immobile, false)) {
				state.set(stack, str(key::immobile), bool_value(true));
			}
			const int64_t speed = gd::int_field(state, effect, key::speed, 0);
			if (speed > 0) {
				state.set(stack, str(key::speed), int_value(speed));
			}
		}
		// It acts from the next round, for its rounds.
		state.set(stack, str(key::conjured_until_round), int_value(gd::add(round, rounds)));
	}
	state.set(stack, str(key::total_health), int_value(health));
	state.set(stack, str(key::conjured), bool_value(true));
	state.set(stack, str(key::conjured_by_spell), str(gd::string_field(state, spell, key::id, key::empty)));
	state.set(stack, str(key::army_slot_index), int_value(-1));
	state.set(stack, str(key::hex), dict_value(battle_rules::_hex_cell(state, gd::int_field(state, cell, key::q, -1), gd::int_field(state, cell, key::r, -1))));
	return stack;
}

Atom add_conjured_stack(State &state, DictRef battle, DictRef stack) {
	const Value stacks = gd::field(state, battle, key::stacks);
	if (!gd::is_array(stacks) || gd::is_empty(state, stack)) {
		return key::empty;
	}
	const int64_t serial = gd::add(gd::int_field(state, battle, key::conjured_serial, 0), 1);
	state.set(battle, str(key::conjured_serial), int_value(serial));
	const Atom id = gd::format(state, key::conjured_id_format, { str(side_of(state, stack)), int_value(serial) });
	state.set(stack, str(key::battle_id), str(id));
	state.append(stacks.ref, dict_value(stack));
	// The fallen stack the Risen came from rises only once.
	const Atom risen_from = gd::string_field(state, stack, key::risen_from, key::empty);
	if (risen_from != key::empty) {
		const DictRef fallen = battle_rules::_get_stack_by_id(state, battle, risen_from);
		if (!gd::is_empty(state, fallen)) {
			state.set(fallen, str(key::raised), bool_value(true));
		}
	}
	battle_rules::_sync_occupied_hexes(state, battle);
	battle_rules::_sync_distance_from_hexes(state, battle);
	return id;
}

Atom vanish_conjured(State &state, DictRef battle, Atom battle_id) {
	const DictRef stack = battle_rules::_get_stack_by_id(state, battle, battle_id);
	return is_conjured(state, stack) ? vanish(state, battle, stack) : static_cast<Atom>(key::empty);
}

bool decoy_takes_hit(State &state, DictRef battle, Atom battle_id) {
	const DictRef stack = battle_rules::_get_stack_by_id(state, battle, battle_id);
	if (!is_decoy(state, stack) || !alive(state, stack)) {
		return false;
	}
	battle_rules::_record_event(state, battle, vanish(state, battle, stack));
	return true;
}

void expire_conjured(State &state, DictRef battle, int64_t round) {
	for (const Value &stack : gd::field_items(state, battle, str(key::stacks))) {
		if (gd::is_dict(stack) && is_conjured(state, stack.ref) && alive(state, stack.ref) && gd::int_field(state, stack.ref, key::conjured_until_round, 0) < round) {
			battle_rules::_record_event(state, battle, vanish(state, battle, stack.ref));
		}
	}
}

// --- Hour Ledger ---------------------------------------------------------------------

void record_round_ledger(State &state, DictRef battle, int64_t round) {
	bool kept = false;
	for (const Atom field : { key::player_commander_state, key::enemy_hero }) {
		const Value hero = gd::field(state, battle, field);
		if (!gd::is_dict(hero) || gd::is_empty(state, hero.ref)) {
			continue;
		}
		for (const Value &spell : gd::items(state, array_value(known_spells(state, hero.ref, key::battle)))) {
			kept = kept || (gd::is_dict(spell) && gd::string_field(state, effect_of(state, spell.ref), key::type, key::empty) == key::rewind);
		}
	}
	if (!kept) {
		return;
	}
	Value ledger = gd::field(state, battle, key::round_ledger);
	if (!gd::is_dict(ledger)) {
		ledger = dict_value(state.new_dict());
		state.set(battle, str(key::round_ledger), ledger);
	}
	for (const Value &stack : gd::field_items(state, battle, str(key::stacks))) {
		if (!gd::is_dict(stack) || is_conjured(state, stack.ref) || !alive(state, stack.ref)) {
			continue;
		}
		const DictRef hex = battle_rules::_stack_hex(state, stack.ref);
		if (gd::is_empty(state, hex)) {
			continue;
		}
		// The round's snapshot replaces one taken at the same round's start (a resumed battle).
		const ArrayRef entries = state.new_array();
		const Value old = gd::field(state, ledger.ref, battle_id_of(state, stack.ref));
		if (gd::is_array(old)) {
			for (const Value &entry : gd::items(state, old)) {
				const int64_t entry_round = gd::is_dict(entry) ? gd::int_field(state, entry.ref, key::round, 0) : 0;
				if (entry_round > gd::sub(round, kLedgerRounds) && entry_round != round) {
					state.append(entries, entry);
				}
			}
		}
		const DictRef entry = state.new_dict();
		state.set(entry, str(key::round), int_value(round));
		state.set(entry, str(key::total_health), int_value(gd::int_field(state, stack.ref, key::total_health, 0)));
		state.set(entry, str(key::budded_health), int_value(gd::int_field(state, stack.ref, key::budded_health, 0)));
		state.set(entry, str(key::q), int_value(gd::int_field(state, hex, key::q, -1)));
		state.set(entry, str(key::r), int_value(gd::int_field(state, hex, key::r, -1)));
		state.append(entries, dict_value(entry));
		state.set(ledger.ref, str(battle_id_of(state, stack.ref)), array_value(entries));
	}
}

int64_t rewind_reach(State &state, DictRef hero, DictRef spell) {
	return power_count(state, effect_of(state, spell), key::rounds_back, key::rounds_back_power_divisor, spell_power(state, hero));
}

ArrayRef rewind_destinations(State &state, DictRef battle, DictRef stack, int64_t reach) {
	const ArrayRef cells = state.new_array();
	const Value ledger = gd::field(state, battle, key::round_ledger);
	if (!alive(state, stack) || is_conjured(state, stack) || !gd::is_dict(ledger)) {
		return cells;
	}
	const Value entries = gd::field(state, ledger.ref, battle_id_of(state, stack));
	if (!gd::is_array(entries)) {
		return cells;
	}
	// Each round within reach (this round's start is none back) on a hex the stack fits now; of the rounds on one
	// hex, the one with the most health, the newer on a tie.
	const int64_t round = gd::int_field(state, battle, key::round, 1);
	const DictRef occupied = battle_rules::_build_blocking_map(state, battle);
	for (const Value &entry : gd::items(state, entries)) {
		if (!gd::is_dict(entry) || gd::int_field(state, entry.ref, key::round, 0) < gd::sub(round, reach) || gd::int_field(state, entry.ref, key::round, 0) > round) {
			continue;
		}
		const DictRef cell = battle_rules::_hex_cell(state, gd::int_field(state, entry.ref, key::q, -1), gd::int_field(state, entry.ref, key::r, -1));
		if (!battle_footprint::fits(state, stack, dict_value(cell), occupied, hex::kColumns, hex::kRows)) {
			continue;
		}
		const int64_t health = gd::int_field(state, entry.ref, key::total_health, 0);
		bool placed = false;
		for (const Value &listed : gd::items(state, array_value(cells))) {
			if (same_cell(state, listed.ref, cell)) {
				placed = true;
				if (health >= gd::int_field(state, listed.ref, key::total_health, 0)) {
					state.set(listed.ref, str(key::round), int_value(gd::int_field(state, entry.ref, key::round, 0)));
					state.set(listed.ref, str(key::total_health), int_value(health));
					state.set(listed.ref, str(key::budded_health), int_value(gd::int_field(state, entry.ref, key::budded_health, 0)));
				}
			}
		}
		if (!placed) {
			state.set(cell, str(key::round), int_value(gd::int_field(state, entry.ref, key::round, 0)));
			state.set(cell, str(key::total_health), int_value(health));
			state.set(cell, str(key::budded_health), int_value(gd::int_field(state, entry.ref, key::budded_health, 0)));
			state.append(cells, dict_value(cell));
		}
	}
	return cells;
}

DictRef rewind_snapshot_at(State &state, DictRef battle, DictRef stack, int64_t reach, const Value &destination) {
	const DictRef wanted = battle_rules::_normalize_hex_cell(state, destination);
	for (const Value &cell : gd::items(state, array_value(rewind_destinations(state, battle, stack, reach)))) {
		if (same_cell(state, cell.ref, wanted)) {
			return cell.ref;
		}
	}
	return state.new_dict();
}

void rewind_stack(State &state, DictRef battle, Atom battle_id, DictRef snapshot) {
	const DictRef stack = battle_rules::_get_stack_by_id(state, battle, battle_id);
	if (!alive(state, stack) || gd::is_empty(state, snapshot)) {
		return;
	}
	const int64_t health = engine_max<int64_t>(1, gd::int_field(state, snapshot, key::total_health, 1));
	state.set(stack, str(key::total_health), int_value(health));
	state.set(stack, str(key::budded_health), int_value(engine_min<int64_t>(health, engine_max<int64_t>(0, gd::int_field(state, snapshot, key::budded_health, 0)))));
	battle_rules::_set_stack_hex(state, battle, battle_id, battle_rules::_hex_cell(state, gd::int_field(state, snapshot, key::q, -1), gd::int_field(state, snapshot, key::r, -1)));
	battle_rules::_sync_occupied_hexes(state, battle);
	battle_rules::_sync_distance_from_hexes(state, battle);
}

// --- Puppet Strings --------------------------------------------------------------------

int64_t charm_damage_pct(State &state, DictRef hero, DictRef battle, DictRef spell, DictRef puppet) {
	const DictRef effect = effect_of(state, spell);
	return engine_max<int64_t>(1, gd::add(gd::int_field(state, effect, key::damage_pct, 0),
			gd::mul(gd::int_field(state, effect, key::damage_pct_power_scale, 0), spell_power_against(state, hero, battle, puppet))));
}

bool charm_shoots(State &state, DictRef battle, DictRef puppet, DictRef victim) {
	if (!gd::bool_field(state, puppet, key::ranged, false) || gd::int_field(state, puppet, key::shots_remaining, 0) <= 0) {
		return false;
	}
	// A stack of the caster's side next to it keeps it from shooting, as it would any shooter.
	for (const Value &foe : gd::items(state, array_value(battle_rules::_alive_stacks_for_side(state, battle, battle_rules::_opposing_side(side_of(state, puppet)))))) {
		if (gd::is_dict(foe) && battle_footprint::distance(state, puppet, foe.ref, Value()) == 1) {
			return false;
		}
	}
	return !shot_refused_by_spells(state, battle, puppet, victim);
}

bool charm_reach(State &state, DictRef battle, DictRef puppet, DictRef victim, DictRef &approach) {
	approach = state.new_dict();
	if (!alive(state, puppet) || !alive(state, victim) || battle_id_of(state, puppet) == battle_id_of(state, victim)) {
		return false;
	}
	if (charm_shoots(state, battle, puppet, victim) || battle_footprint::distance(state, puppet, victim, Value()) == 1) {
		return true;
	}
	// A melee stack walks first, on its own walk, to the hex beside the victim with the fewest steps.
	int64_t fewest = 0;
	for (const Value &cell : gd::items(state, array_value(battle_rules::legal_destinations_for_stack(state, battle, battle_id_of(state, puppet))))) {
		if (!gd::is_dict(cell) || battle_footprint::distance(state, puppet, victim, cell) != 1) {
			continue;
		}
		const int64_t steps = gd::int_field(state, cell.ref, key::steps, 0);
		if (gd::is_empty(state, approach) || steps < fewest) {
			approach = battle_rules::_normalize_hex_cell(state, cell);
			fewest = steps;
		}
	}
	return !gd::is_empty(state, approach);
}

ArrayRef charm_victim_ids(State &state, DictRef battle, DictRef puppet) {
	const ArrayRef ids = state.new_array();
	for (const Value &other : gd::field_items(state, battle, str(key::stacks))) {
		if (!gd::is_dict(other) || side_of(state, other.ref) != side_of(state, puppet)) {
			continue;
		}
		DictRef approach;
		if (charm_reach(state, battle, puppet, other.ref, approach)) {
			state.append(ids, str(battle_id_of(state, other.ref)));
		}
	}
	return ids;
}

int64_t charm_blow_damage(State &state, DictRef battle, DictRef puppet, DictRef victim, int64_t pct) {
	// The middle of the stack's damage roll, at the spell's share, with no draw.
	const bool ranged = charm_shoots(state, battle, puppet, victim);
	const int64_t low = gd::int_field(state, puppet, key::min_damage, 1);
	const int64_t high = engine_max<int64_t>(low, gd::int_field(state, puppet, key::max_damage, 1));
	const int64_t distance = battle_rules::_attack_distance_for_action(state, puppet, victim, battle, ranged);
	const int64_t full = battle_rules::_damage_for_roll(state, puppet, victim, battle, compat::int_div(gd::add(low, high), 2), ranged, false, distance);
	return engine_max<int64_t>(1, compat::int_div(gd::mul(full, engine_max<int64_t>(0, pct)), 100));
}

Atom charm_attack(State &state, DictRef battle, Atom puppet_id, Atom victim_id, int64_t pct) {
	const DictRef puppet = battle_rules::_get_stack_by_id(state, battle, puppet_id);
	const DictRef victim = battle_rules::_get_stack_by_id(state, battle, victim_id);
	DictRef approach;
	if (!charm_reach(state, battle, puppet, victim, approach)) {
		return state.intern(" " + state.text(gd::format(state, key::puppet_cannot_reach_text, { str(battle_rules::_stack_label(state, puppet)) })));
	}
	// A suffix to the cast's line: each sentence after a space.
	std::string text;
	const bool ranged = charm_shoots(state, battle, puppet, victim);
	if (!ranged && !gd::is_empty(state, approach)) {
		// The approach is not a walk of its own turn: no ground or seed goes off.
		battle_rules::_set_stack_hex(state, battle, puppet_id, approach);
		battle_rules::_sync_occupied_hexes(state, battle);
		battle_rules::_sync_distance_from_hexes(state, battle);
		text += " " + state.text(gd::format(state, key::puppet_walks_text, { str(battle_rules::_stack_label(state, puppet)), str(battle_rules::_hex_label(state, approach)) }));
	}
	const int64_t damage = charm_blow_damage(state, battle, puppet, victim, pct);
	const Atom puppet_label = battle_rules::_stack_label(state, puppet);
	const Atom victim_label = battle_rules::_stack_label(state, victim);
	battle_rules::_apply_damage_to_stack(state, battle, victim_id, damage);
	if (ranged) {
		battle_rules::_consume_shot(state, battle, puppet_id);
	}
	text += " " + state.text(gd::format(state, ranged ? key::shoots_for_damage_text : key::strikes_for_damage_text, { str(puppet_label), str(victim_label), int_value(damage) }));
	for (const Value &extra : gd::items(state, array_value(after_blow_mechanics(state, battle, puppet_id, victim_id, ranged, damage)))) {
		text += " " + state.text(gd::to_string(extra));
	}
	const DictRef after = battle_rules::_get_stack_by_id(state, battle, victim_id);
	if (!gd::is_empty(state, after) && _alive_count(state, after) <= 0 && !is_decoy(state, after)) {
		text += state.text(gd::format(state, key::stack_destroyed_suffix_text, { str(victim_label) }));
	}
	return state.intern(text);
}

} // namespace aurelion::rules::port::spell_rules
