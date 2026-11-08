// Layer 8: the tier-4 and tier-5 battle spells that bend turns and losses (docs/magic-system-spells.md). Redline's
// stack strikes twice in melee on its next turn and is then Staggered; Clarion Call's stack takes another full turn
// right after its next one; Shadow Ranks gives back a share of the creatures its stack loses, as the round ends;
// Green Return brings every fallen stack of its side back once, as the next round starts; Echo casts the side's last
// spell of the battle again, at once and stronger.

#include "aurelion_rules/port/spell_rules.hpp"

#include "aurelion_rules/battle_hex.hpp"
#include "aurelion_rules/compat/godot_math.hpp"
#include "aurelion_rules/port/battle_footprint.hpp"
#include "aurelion_rules/port/battle_rules.hpp"

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

Atom battle_id_of(const State &state, DictRef stack) {
	return gd::string_field(state, stack, key::battle_id, key::empty);
}

Atom side_of(const State &state, DictRef stack) {
	return gd::string_field(state, stack, key::side, key::empty);
}

bool living(State &state, DictRef stack) {
	return !gd::is_empty(state, stack) && battle_rules::_alive_count(state, stack) > 0;
}

// A counted effect's last turn: it ends with the turn now ending.
bool last_counted_turn(State &state, DictRef effect) {
	return !gd::is_empty(state, effect) && !gd::bool_field(state, effect, key::skip_current_turn, false)
			&& gd::int_field(state, effect, key::turns_left, 1) <= 1;
}

DictRef effect_of(State &state, DictRef spell) {
	Value effect;
	return !gd::is_empty(state, spell) && state.lookup(spell, str(key::effect), effect) && gd::is_dict(effect) ? effect.ref : state.new_dict();
}

int64_t unit_hp_of(const State &state, DictRef stack) {
	return engine_max<int64_t>(1, gd::int_field(state, stack, key::unit_hp, 1));
}

void erase_field(State &state, DictRef dict, Atom field) {
	if (state.has(dict, str(field))) {
		state.erase(dict, str(field));
	}
}

// The hex a returning stack stands on: its own when its body fits there, else the nearest one that fits (the board's
// order on a tie); empty when none does.
DictRef return_cell(State &state, DictRef battle, DictRef stack) {
	const DictRef occupied = battle_rules::_build_blocking_map(state, battle);
	const DictRef home = battle_rules::_stack_hex(state, stack);
	if (!gd::is_empty(state, home) && battle_footprint::fits(state, stack, dict_value(home), occupied, hex::kColumns, hex::kRows)) {
		return home;
	}
	DictRef best = state.new_dict();
	int64_t best_distance = 0;
	for (int64_t q = 0; q < hex::kColumns; ++q) {
		for (int64_t r = 0; r < hex::kRows; ++r) {
			const DictRef cell = battle_rules::_hex_cell(state, q, r);
			if (!battle_footprint::fits(state, stack, dict_value(cell), occupied, hex::kColumns, hex::kRows)) {
				continue;
			}
			const int64_t distance = gd::is_empty(state, home) ? 0 : battle_rules::_hex_distance(state, home, cell);
			if (gd::is_empty(state, best) || distance < best_distance) {
				best = cell;
				best_distance = distance;
			}
		}
	}
	return best;
}

} // namespace

// --- Redline -----------------------------------------------------------------------

int64_t melee_blows(State &state, DictRef battle, DictRef attacker) {
	return living(state, attacker) && stack_mechanic_int(state, attacker, battle, key::double_strike) > 0 ? 2 : 1;
}

void spend_double_strike(State &state, DictRef battle, Atom attacker_id) {
	const DictRef attacker = battle_rules::_get_stack_by_id(state, battle, attacker_id);
	const DictRef boost = gd::is_empty(state, attacker) ? state.new_dict() : stack_mechanic_effect(state, attacker, battle, key::double_strike);
	if (gd::is_empty(state, boost)) {
		return;
	}
	const DictRef mechanic = effect_mechanic(state, boost);
	state.set(mechanic, str(key::double_strike), int_value(0));
	state.set(mechanic, str(key::struck_twice), int_value(1));
}

void redline_turn_end(State &state, DictRef battle, Atom battle_id) {
	const DictRef stack = battle_rules::_get_stack_by_id(state, battle, battle_id);
	if (!living(state, stack)) {
		return;
	}
	const DictRef boost = stack_mechanic_effect(state, stack, battle, key::staggered_after);
	if (gd::is_empty(state, boost)) {
		return;
	}
	const DictRef mechanic = effect_mechanic(state, boost);
	// The price comes once the double blow is struck, or once its turn is over unstruck.
	if (gd::int_field(state, mechanic, key::struck_twice, 0) <= 0 && !last_counted_turn(state, boost)) {
		return;
	}
	const int64_t turns = engine_max<int64_t>(1, gd::int_field(state, mechanic, key::staggered_after, 2));
	const Atom source_id = gd::string_field(state, boost, key::source_id, key::empty);
	remove_stack_effect(state, stack, boost);
	const Atom label = battle_rules::_stack_label(state, stack);
	if (target_is_immune_to_status(state, stack, battle, key::status_staggered)) {
		battle_rules::_record_event(state, battle, gd::format(state, key::redline_spent_text, { str(label) }));
		return;
	}
	const DictRef stagger = build_battle_effect(state, key::status_staggered, key::staggered_label, dict_value(state.new_dict()), turns, battle, key::spell, source_id, array_value(state.new_array()));
	battle_rules::_apply_stack_effect(state, battle, battle_id, dict_value(_counted_in_turns(state, stagger, turns)));
	battle_rules::_record_event(state, battle, gd::format(state, key::spent_and_staggered_text, { str(label), str(_turns_label(state, turns)) }));
}

// --- Clarion Call ------------------------------------------------------------------

void grant_extra_turn(State &state, DictRef battle, Atom battle_id) {
	const DictRef stack = battle_rules::_get_stack_by_id(state, battle, battle_id);
	if (!living(state, stack)) {
		return;
	}
	state.set(stack, str(key::extra_turn_pending), bool_value(true));
	// The boost holds through the turn that the extra one follows, and through the extra turn.
	const DictRef boost = stack_mechanic_effect(state, stack, battle, key::extra_turn);
	if (!gd::is_empty(state, boost) && state.has(boost, str(key::turns_left))) {
		state.set(boost, str(key::skip_current_turn), bool_value(true));
	}
}

bool take_extra_turn(State &state, DictRef battle, Atom ending_id) {
	erase_field(state, battle, key::extra_turn_stack_id);
	const DictRef stack = battle_rules::_get_stack_by_id(state, battle, ending_id);
	if (gd::is_empty(state, stack) || !gd::bool_field(state, stack, key::extra_turn_pending, false)) {
		return false;
	}
	state.erase(stack, str(key::extra_turn_pending));
	if (!living(state, stack)) {
		return false;
	}
	state.set(battle, str(key::extra_turn_stack_id), str(ending_id));
	battle_rules::_record_event(state, battle, gd::format(state, key::takes_another_turn_text, { str(battle_rules::_stack_label(state, stack)) }));
	return true;
}

bool in_extra_turn(State &state, DictRef battle, Atom battle_id) {
	return battle_id != key::empty && gd::string_field(state, battle, key::extra_turn_stack_id, key::empty) == battle_id;
}

// --- Shadow Ranks ------------------------------------------------------------------

void count_shadow_losses(State &state, DictRef battle, Atom battle_id, int64_t taken, bool killed) {
	const DictRef stack = battle_rules::_get_stack_by_id(state, battle, battle_id);
	if (gd::is_empty(state, stack)) {
		return;
	}
	// A destroyed stack's shadows fall with it.
	if (killed) {
		erase_field(state, stack, key::shadow_lost);
		erase_field(state, stack, key::shadow_pct);
		return;
	}
	if (taken <= 0 || !living(state, stack)) {
		return;
	}
	const DictRef ward = stack_mechanic_effect(state, stack, battle, key::loss_return_pct);
	if (gd::is_empty(state, ward)) {
		return;
	}
	const int64_t unit_hp = unit_hp_of(state, stack);
	const int64_t health = engine_max<int64_t>(0, gd::int_field(state, stack, key::total_health, 0));
	const int64_t before = compat::int_div(gd::add(gd::add(health, taken), unit_hp - 1), unit_hp);
	const int64_t lost = gd::sub(before, battle_rules::_alive_count(state, stack));
	if (lost <= 0) {
		return;
	}
	state.set(stack, str(key::shadow_lost), int_value(gd::add(gd::int_field(state, stack, key::shadow_lost, 0), lost)));
	state.set(stack, str(key::shadow_pct), int_value(gd::int_field(state, effect_mechanic(state, ward), key::loss_return_pct, 0)));
}

void shadows_return(State &state, DictRef battle) {
	bool returned = false;
	for (const Value &stack : gd::field_items(state, battle, str(key::stacks))) {
		if (!gd::is_dict(stack) || !state.has(stack.ref, str(key::shadow_lost))) {
			continue;
		}
		const int64_t lost = gd::int_field(state, stack.ref, key::shadow_lost, 0);
		const int64_t pct = gd::int_field(state, stack.ref, key::shadow_pct, 0);
		erase_field(state, stack.ref, key::shadow_lost);
		erase_field(state, stack.ref, key::shadow_pct);
		if (!living(state, stack.ref) || lost <= 0 || pct <= 0) {
			continue;
		}
		const int64_t back = compat::int_div(gd::add(gd::mul(lost, pct), 50), 100);
		const int64_t unit_hp = unit_hp_of(state, stack.ref);
		const int64_t health = gd::int_field(state, stack.ref, key::total_health, 0);
		const int64_t full = gd::mul(unit_hp, engine_max<int64_t>(0, gd::int_field(state, stack.ref, key::base_count, 0)));
		const int64_t raised = engine_max<int64_t>(0, engine_min<int64_t>(gd::mul(back, unit_hp), gd::sub(full, health)));
		if (raised <= 0) {
			continue;
		}
		const int64_t alive_before = battle_rules::_alive_count(state, stack.ref);
		state.set(stack.ref, str(key::total_health), int_value(gd::add(health, raised)));
		returned = true;
		battle_rules::_record_event(state, battle, gd::format(state, key::shadows_return_text, {
			int_value(gd::sub(battle_rules::_alive_count(state, stack.ref), alive_before)), str(battle_rules::_stack_label(state, stack.ref)) }));
	}
	if (returned) {
		battle_rules::_sync_occupied_hexes(state, battle);
	}
}

// --- Green Return ------------------------------------------------------------------

bool green_return_used(State &state, DictRef battle, Atom side) {
	Value sides;
	return !gd::is_empty(state, battle) && state.lookup(battle, str(key::green_return_sides), sides) && gd::is_array(sides) && gd::array_has(state, sides.ref, str(side));
}

void mark_green_return(State &state, DictRef battle, Atom side) {
	Value sides;
	if (!state.lookup(battle, str(key::green_return_sides), sides) || !gd::is_array(sides)) {
		sides = array_value(state.new_array());
		state.set(battle, str(key::green_return_sides), sides);
	}
	if (!gd::array_has(state, sides.ref, str(side))) {
		state.append(sides.ref, str(side));
	}
}

void green_return_rises(State &state, DictRef battle, DictRef aura) {
	const Atom side = gd::string_field(state, aura, key::side, key::empty);
	const int64_t pct = engine_max<int64_t>(1, engine_min<int64_t>(100, gd::int_field(state, aura, key::pct, 0)));
	const Atom label = gd::string_field(state, aura, key::label, key::empty);
	// The side's fallen in the battle's order: never a conjured stack, each once.
	std::vector<Atom> fallen;
	for (const Value &stack : gd::field_items(state, battle, str(key::stacks))) {
		if (gd::is_dict(stack) && side_of(state, stack.ref) == side && !living(state, stack.ref) && !is_conjured(state, stack.ref)
				&& !gd::bool_field(state, stack.ref, key::green_returned, false) && gd::int_field(state, stack.ref, key::base_count, 0) > 0) {
			fallen.push_back(battle_id_of(state, stack.ref));
		}
	}
	for (const Atom id : fallen) {
		const DictRef stack = battle_rules::_get_stack_by_id(state, battle, id);
		const DictRef cell = return_cell(state, battle, stack);
		if (gd::is_empty(state, cell)) {
			continue;
		}
		const int64_t count = engine_max<int64_t>(1, compat::int_div(gd::mul(gd::int_field(state, stack, key::base_count, 0), pct), 100));
		battle_rules::_set_stack_hex(state, battle, id, cell);
		const DictRef risen = battle_rules::_get_stack_by_id(state, battle, id);
		state.set(risen, str(key::total_health), int_value(gd::mul(count, unit_hp_of(state, risen))));
		state.set(risen, str(key::budded_health), int_value(0));
		state.set(risen, str(key::effects), array_value(state.new_array()));
		state.set(risen, str(key::defending), bool_value(false));
		state.set(risen, str(key::retaliations_left), int_value(gd::int_field(state, risen, key::retaliations, 1)));
		state.set(risen, str(key::spell_heat), int_value(0));
		state.set(risen, str(key::green_returned), bool_value(true));
		erase_field(state, risen, key::extra_turn_pending);
		battle_rules::_sync_occupied_hexes(state, battle);
		battle_rules::_record_event(state, battle, gd::format(state, key::green_return_text, { str(label), str(battle_rules::_stack_label(state, risen)), int_value(count) }));
	}
	if (!fallen.empty()) {
		battle_rules::_sync_distance_from_hexes(state, battle);
	}
}

// --- Echo ----------------------------------------------------------------------------

DictRef last_cast_of(State &state, DictRef battle, Atom side) {
	Value casts;
	Value entry;
	if (!gd::is_empty(state, battle) && state.lookup(battle, str(key::last_casts), casts) && gd::is_dict(casts)
			&& state.lookup(casts.ref, str(side), entry) && gd::is_dict(entry)) {
		return entry.ref;
	}
	return state.new_dict();
}

void record_last_cast(State &state, DictRef battle, Atom side, Atom spell_id, DictRef resolution, const Value &destination) {
	const DictRef spell = gd::content_row(state, state::ContentTable::Spell, spell_id);
	if (gd::is_empty(state, battle) || gd::is_empty(state, spell) || gd::string_field(state, effect_of(state, spell), key::type, key::empty) == key::recast) {
		return;
	}
	const Atom reflected_from = gd::string_field(state, resolution, key::reflected_from_battle_id, key::empty);
	const DictRef entry = state.new_dict();
	state.set(entry, str(key::spell_id), str(spell_id));
	state.set(entry, str(key::target_battle_id), str(reflected_from != key::empty ? reflected_from : gd::string_field(state, resolution, key::target_battle_id, key::empty)));
	if (gd::is_dict(destination) && !gd::is_empty(state, destination.ref)) {
		state.set(entry, str(key::destination), dict_value(gd::deep_duplicate_dict(state, destination.ref)));
	}
	Value casts;
	if (!state.lookup(battle, str(key::last_casts), casts) || !gd::is_dict(casts)) {
		casts = dict_value(state.new_dict());
		state.set(battle, str(key::last_casts), casts);
	}
	state.set(casts.ref, str(side), dict_value(entry));
}

bool echo_names_stack(State &state, DictRef inner_spell) {
	const DictRef effect = effect_of(state, inner_spell);
	const Atom type = gd::string_field(state, effect, key::type, key::empty);
	return !(type == key::ground_effect || type == key::battle_aura || (type == key::conjure && conjures_on_hex(state, inner_spell)));
}

DictRef echo_target(State &state, DictRef battle, DictRef active_stack, DictRef inner_spell, DictRef last) {
	if (gd::is_empty(state, inner_spell)) {
		return state.new_dict();
	}
	// A spell over the battle or on a hex is cast as it was, with the acting stack as its stack.
	if (!echo_names_stack(state, inner_spell)) {
		return active_stack;
	}
	const DictRef target = battle_rules::_get_stack_by_id(state, battle, gd::string_field(state, last, key::target_battle_id, key::empty));
	return living(state, target) ? target : state.new_dict();
}

DictRef echo_caster(State &state, DictRef hero, DictRef echo_spell, Atom inner_id) {
	const DictRef caster = ensure_hero_spellbook(state, gd::deep_duplicate_dict(state, hero), state.new_dict());
	const int64_t power = spell_power(state, hero);
	const int64_t bonus = power_count(state, effect_of(state, echo_spell), key::power_bonus, key::power_bonus_power_divisor, power);
	Value command;
	if (!state.lookup(caster, str(key::command), command) || !gd::is_dict(command)) {
		command = dict_value(state.new_dict());
		state.set(caster, str(key::command), command);
	}
	state.set(command.ref, str(key::power), int_value(gd::add(engine_max<int64_t>(0, gd::int_field(state, command.ref, key::power, 0)), bonus)));
	// It knows the spell and holds the mana for it: the echo costs nothing more.
	const Value spellbook = gd::field(state, caster, key::spellbook);
	if (gd::is_dict(spellbook)) {
		Value known;
		if (!state.lookup(spellbook.ref, str(key::known_spell_ids), known) || !gd::is_array(known)) {
			known = array_value(state.new_array());
			state.set(spellbook.ref, str(key::known_spell_ids), known);
		}
		if (!gd::array_has(state, known.ref, str(inner_id))) {
			state.append(known.ref, str(inner_id));
		}
		Value mana;
		if (!state.lookup(spellbook.ref, str(key::mana), mana) || !gd::is_dict(mana)) {
			mana = dict_value(state.new_dict());
			state.set(spellbook.ref, str(key::mana), mana);
		}
		const int64_t cost = adjusted_spell_mana_cost(state, caster, dict_value(gd::content_row(state, state::ContentTable::Spell, inner_id)));
		state.set(mana.ref, str(key::current), int_value(engine_max<int64_t>(gd::int_field(state, mana.ref, key::current, 0), cost)));
	}
	return caster;
}

int64_t echo_power_bonus(State &state, DictRef hero, DictRef echo_spell) {
	return power_count(state, effect_of(state, echo_spell), key::power_bonus, key::power_bonus_power_divisor, spell_power(state, hero));
}

bool echo_scores_inner(State &state, DictRef inner_spell) {
	const Atom type = gd::string_field(state, effect_of(state, inner_spell), key::type, key::empty);
	// The computer weighs again only a spell that needs no hex, destination or second stack.
	return !(type == key::empty || type == key::recast || type == key::ground_effect || type == key::move_ally || type == key::pull_enemy || type == key::rewind
			|| type == key::graft_allies || type == key::transfer_ally || type == key::swap_allies || type == key::swap_enemy || type == key::sacrifice
			|| type == key::taunt_enemy || type == key::charm_enemy || (type == key::conjure && conjures_on_hex(state, inner_spell)));
}

} // namespace aurelion::rules::port::spell_rules
