// Layer 8: the tier-2 spells that take two stacks (docs/magic-system-spells.md): Graft joins two of the caster's
// stacks so that damage either one takes is split between them, Blood Tithe moves health from one of them into
// another (fallen creatures can come back), Signal Swap trades two of the caster's stacks' places and Changeling
// Swap one of the caster's stacks' place with an enemy stack's. The cast names its second stack ({battle_id}); the
// battle screen offers the stacks second_stack_ids lists, and Leech's drinker the same way.

#include "aurelion_rules/port/spell_rules.hpp"

#include "aurelion_rules/compat/godot_math.hpp"
#include "aurelion_rules/port/battle_footprint.hpp"
#include "aurelion_rules/port/battle_rules.hpp"

namespace aurelion::rules::port::spell_rules {

using compat::engine_max;
using compat::engine_min;
using gd::array_value;
using gd::bool_value;
using gd::dict_value;
using gd::int_value;
using gd::str;
namespace key = state::key;

namespace {

Atom side_of(const State &state, DictRef stack) {
	return gd::string_field(state, stack, key::side, key::empty);
}

Atom battle_id_of(const State &state, DictRef stack) {
	return gd::string_field(state, stack, key::battle_id, key::empty);
}

bool alive(State &state, DictRef stack) {
	return !gd::is_empty(state, stack) && _alive_count(state, stack) > 0;
}

Atom effect_type_of(State &state, DictRef spell) {
	const Value effect = gd::field(state, spell, key::effect);
	return gd::is_dict(effect) ? gd::string_field(state, effect.ref, key::type, key::empty) : key::empty;
}

int64_t total_health(State &state, DictRef stack) {
	return engine_max<int64_t>(0, gd::int_field(state, stack, key::total_health, 0));
}

ArrayRef stack_effects(State &state, DictRef stack) {
	Value effects;
	if (!gd::is_empty(state, stack) && state.lookup(stack, str(key::effects), effects) && gd::is_array(effects)) {
		return effects.ref;
	}
	return state.new_array();
}

Atom graft_partner_named(State &state, DictRef effect) {
	return gd::string_field(state, effect_mechanic(state, effect), key::graft_partner, key::empty);
}

// Removes the stack's graft effects that name partner_id (any partner when empty).
void remove_grafts(State &state, DictRef stack, Atom partner_id) {
	const ArrayRef effects = stack_effects(state, stack);
	for (int64_t index = state.array_size(effects) - 1; index >= 0; --index) {
		const Value effect = state.at(effects, index);
		if (!gd::is_dict(effect)) {
			continue;
		}
		const Atom named = graft_partner_named(state, effect.ref);
		if (named != key::empty && (partner_id == key::empty || named == partner_id)) {
			gd::remove_at(state, effects, index);
		}
	}
}

int64_t swap_range(State &state, DictRef hero, DictRef battle, DictRef spell, DictRef enemy_stack) {
	// Signal Swap reaches {4+P} hexes; Changeling Swap {4+E}, E against the enemy stack's side.
	const int64_t power = gd::is_empty(state, enemy_stack) ? spell_power(state, hero) : spell_power_against(state, hero, battle, enemy_stack);
	return spell_move_reach(state, spell, power);
}

} // namespace

bool takes_second_stack(State &state, DictRef spell) {
	const Atom type = effect_type_of(state, spell);
	return type == key::graft_allies || type == key::transfer_ally || type == key::swap_allies || type == key::swap_enemy || type == key::sacrifice
			|| type == key::taunt_enemy || type == key::charm_enemy;
}

bool offers_second_stack(State &state, DictRef spell) {
	if (takes_second_stack(state, spell)) {
		return true;
	}
	const Value effect = gd::field(state, spell, key::effect);
	return gd::is_dict(effect) && gd::int_field(state, effect.ref, key::drain_pct, 0) > 0;
}

int64_t stack_full_health(State &state, DictRef stack) {
	const int64_t unit_hp = engine_max<int64_t>(1, gd::int_field(state, stack, key::unit_hp, 1));
	const int64_t count = engine_max<int64_t>(gd::int_field(state, stack, key::base_count, 0), _alive_count(state, stack));
	return gd::mul(unit_hp, count);
}

int64_t spell_swap_range(State &state, DictRef hero, DictRef battle, DictRef spell, DictRef first) {
	return swap_range(state, hero, battle, spell, effect_type_of(state, spell) == key::swap_enemy ? first : state.new_dict());
}

bool swap_fits(State &state, DictRef battle, DictRef a, DictRef b) {
	const DictRef a_hex = battle_rules::_stack_hex(state, a);
	const DictRef b_hex = battle_rules::_stack_hex(state, b);
	if (gd::is_empty(state, a_hex) || gd::is_empty(state, b_hex)) {
		return false;
	}
	// The field without the two stacks, then each body in the other's place.
	const DictRef occupied = battle_rules::_build_blocking_map(state, battle);
	for (const DictRef stack : { a, b }) {
		for (const Value &cell : gd::items(state, array_value(battle_footprint::cells(state, stack, Value())))) {
			state.erase(occupied, str(battle_rules::_hex_key(state, gd::as_dict(cell))));
		}
	}
	if (!battle_footprint::fits(state, a, dict_value(b_hex), occupied, battle_rules::BATTLE_HEX_COLUMNS, battle_rules::BATTLE_HEX_ROWS)
			|| !battle_footprint::fits(state, b, dict_value(a_hex), occupied, battle_rules::BATTLE_HEX_COLUMNS, battle_rules::BATTLE_HEX_ROWS)) {
		return false;
	}
	const DictRef a_cells = state.new_dict();
	for (const Value &cell : gd::items(state, array_value(battle_footprint::cells(state, a, dict_value(b_hex))))) {
		state.set(a_cells, str(battle_rules::_hex_key(state, gd::as_dict(cell))), bool_value(true));
	}
	for (const Value &cell : gd::items(state, array_value(battle_footprint::cells(state, b, dict_value(a_hex))))) {
		if (state.has(a_cells, str(battle_rules::_hex_key(state, gd::as_dict(cell))))) {
			return false;
		}
	}
	return true;
}

ArrayRef second_stack_ids(State &state, DictRef hero, DictRef battle, DictRef first, DictRef spell, Atom acting_side) {
	const ArrayRef ids = state.new_array();
	if (!alive(state, first) || !offers_second_stack(state, spell)) {
		return ids;
	}
	const Atom type = effect_type_of(state, spell);
	// Puppet Strings: a stack of the puppet's own side it can attack now.
	if (type == key::charm_enemy) {
		return charm_victim_ids(state, battle, first);
	}
	const bool swaps = type == key::swap_allies || type == key::swap_enemy;
	const int64_t range = swaps ? spell_swap_range(state, hero, battle, spell, first) : 0;
	for (const Value &other : gd::field_items(state, battle, str(key::stacks))) {
		if (!gd::is_dict(other) || !alive(state, other.ref) || side_of(state, other.ref) != acting_side) {
			continue;
		}
		const DictRef stack = other.ref;
		// A decoy is no second stack, and a Censured stack takes no helpful pair spell of its own hero's.
		if (battle_id_of(state, stack) == battle_id_of(state, first) || is_decoy(state, stack)
				|| ((type == key::graft_allies || type == key::transfer_ally || type == key::swap_allies) && censured(state, stack))) {
			continue;
		}
		// Blood Tithe's donor and Smelter's Bargain's payer keep at least 1 health.
		if ((type == key::transfer_ally || type == key::sacrifice) && total_health(state, stack) <= 1) {
			continue;
		}
		if (swaps && (battle_rules::_stack_is_rooted(state, stack, battle)
							 || battle_rules::_stack_hex_distance(state, first, stack) > range
							 || !swap_fits(state, battle, first, stack))) {
			continue;
		}
		state.append(ids, str(battle_id_of(state, stack)));
	}
	return ids;
}

DictRef second_stack_pick(State &state, DictRef battle, const Value &pick) {
	if (!gd::is_dict(pick)) {
		return state.new_dict();
	}
	const Atom id = gd::string_field(state, pick.ref, key::battle_id, key::empty);
	return id == key::empty ? state.new_dict() : battle_rules::_get_stack_by_id(state, battle, id);
}

int64_t transfer_amount(State &state, DictRef hero, DictRef spell, DictRef receiver, DictRef donor) {
	const int64_t most = _battle_spell_recovery_amount(state, hero, spell);
	const int64_t missing = gd::sub(stack_full_health(state, receiver), total_health(state, receiver));
	const int64_t spare = gd::sub(total_health(state, donor), 1);
	return engine_max<int64_t>(0, engine_min<int64_t>(most, engine_min<int64_t>(missing, spare)));
}

int64_t move_stack_health(State &state, DictRef battle, Atom donor_id, Atom receiver_id, int64_t amount) {
	const DictRef donor = battle_rules::_get_stack_by_id(state, battle, donor_id);
	const DictRef receiver = battle_rules::_get_stack_by_id(state, battle, receiver_id);
	if (!alive(state, donor) || !alive(state, receiver) || amount <= 0 || heal_blocked(state, receiver, battle)
			|| !gd::is_empty(state, stack_status_effect(state, receiver, battle, key::status_blighted))) {
		return 0;
	}
	const int64_t receiver_health = total_health(state, receiver);
	const int64_t moved = engine_min<int64_t>(amount, engine_min<int64_t>(gd::sub(stack_full_health(state, receiver), receiver_health), gd::sub(total_health(state, donor), 1)));
	if (moved <= 0) {
		return 0;
	}
	state.set(donor, str(key::total_health), int_value(gd::sub(total_health(state, donor), moved)));
	state.set(receiver, str(key::total_health), int_value(gd::add(receiver_health, moved)));
	battle_rules::_sync_occupied_hexes(state, battle);
	return moved;
}

void swap_stack_places(State &state, DictRef battle, Atom a_id, Atom b_id) {
	const DictRef a = battle_rules::_get_stack_by_id(state, battle, a_id);
	const DictRef b = battle_rules::_get_stack_by_id(state, battle, b_id);
	if (gd::is_empty(state, a) || gd::is_empty(state, b)) {
		return;
	}
	const DictRef a_hex = gd::deep_duplicate_dict(state, battle_rules::_stack_hex(state, a));
	const DictRef b_hex = gd::deep_duplicate_dict(state, battle_rules::_stack_hex(state, b));
	state.set(a, str(key::hex), dict_value(b_hex));
	state.set(b, str(key::hex), dict_value(a_hex));
	battle_rules::_sync_occupied_hexes(state, battle);
	battle_rules::_sync_distance_from_hexes(state, battle);
}

Atom graft_partner(State &state, DictRef battle, Atom battle_id) {
	const DictRef stack = battle_rules::_get_stack_by_id(state, battle, battle_id);
	if (!alive(state, stack)) {
		return key::empty;
	}
	const DictRef effect = stack_mechanic_effect(state, stack, battle, key::graft_partner);
	if (gd::is_empty(state, effect)) {
		return key::empty;
	}
	const Atom partner_id = graft_partner_named(state, effect);
	const DictRef partner = battle_rules::_get_stack_by_id(state, battle, partner_id);
	if (partner_id == battle_id || !alive(state, partner) || side_of(state, partner) != side_of(state, stack)) {
		return key::empty;
	}
	// Both ends hold the graft.
	const DictRef back = stack_mechanic_effect(state, partner, battle, key::graft_partner);
	return !gd::is_empty(state, back) && graft_partner_named(state, back) == battle_id ? partner_id : static_cast<Atom>(key::empty);
}

void clear_graft(State &state, DictRef battle, Atom battle_id) {
	const DictRef stack = battle_rules::_get_stack_by_id(state, battle, battle_id);
	if (gd::is_empty(state, stack)) {
		return;
	}
	const ArrayRef effects = stack_effects(state, stack);
	for (int64_t index = state.array_size(effects) - 1; index >= 0; --index) {
		const Value effect = state.at(effects, index);
		if (!gd::is_dict(effect)) {
			continue;
		}
		const Atom partner_id = graft_partner_named(state, effect.ref);
		if (partner_id == key::empty) {
			continue;
		}
		remove_grafts(state, battle_rules::_get_stack_by_id(state, battle, partner_id), battle_id);
		gd::remove_at(state, effects, index);
	}
}

} // namespace aurelion::rules::port::spell_rules
