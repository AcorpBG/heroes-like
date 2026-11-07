// Layer 8: the mechanics the basic spells brought in (docs/magic-system.md, docs/magic-system-spells.md): which effects
// on a stack help or harm it and the newest of them a dispel or a cleanse takes, the counts and reaches that grow with
// spell power, and the hexes a stack a spell moves can reach.

#include "aurelion_rules/port/spell_rules.hpp"

#include "aurelion_rules/compat/godot_math.hpp"
#include "aurelion_rules/port/battle_rules.hpp"

namespace aurelion::rules::port::spell_rules {

using compat::engine_max;
using gd::str;
using state::ContentTable;
namespace key = state::key;

namespace {

// The statuses that harm the stack they are on, whoever put them there.
bool is_harmful_status(Atom effect_id) {
	return effect_id == key::status_harried || effect_id == key::status_staggered || effect_id == key::status_rooted
			|| effect_id == key::status_slowed || effect_id == key::status_dazed;
}

// The spell an effect came from, or {} for an effect no spell put there.
DictRef source_spell(State &state, DictRef effect) {
	if (gd::string_field(state, effect, key::source_type, key::empty) != key::spell) {
		return state.new_dict();
	}
	return gd::content_row(state, ContentTable::Spell, gd::string_field(state, effect, key::source_id, key::empty));
}

// Some of the effect's modifiers lower a stat and none raises one.
bool only_lowers(State &state, DictRef effect) {
	Value modifiers;
	if (!state.lookup(effect, str(key::modifiers), modifiers) || !gd::is_dict(modifiers)) {
		return false;
	}
	bool lowers = false;
	for (const Value &amount : state.dict(modifiers.ref).values) {
		const int64_t value = gd::to_int(state, amount);
		if (value > 0) {
			return false;
		}
		lowers = lowers || value < 0;
	}
	return lowers;
}

} // namespace

bool spell_supports_allies(State &state, DictRef spell) {
	const Atom target_mode = gd::string_field(state, spell, key::target_mode, key::empty);
	return target_mode == key::ally_active || target_mode == key::ally_selected || target_mode == key::self;
}

bool effect_helps_stack(State &state, DictRef effect) {
	const DictRef spell = source_spell(state, effect);
	return !gd::is_empty(state, spell) && spell_supports_allies(state, spell);
}

bool effect_harms_stack(State &state, DictRef effect) {
	if (is_harmful_status(gd::string_field(state, effect, key::effect_id, key::empty))) {
		return true;
	}
	const DictRef spell = source_spell(state, effect);
	if (!gd::is_empty(state, spell)) {
		return !spell_supports_allies(state, spell);
	}
	return only_lowers(state, effect);
}

ArrayRef newest_effect_ids(State &state, DictRef stack, DictRef battle, bool helpful, int64_t limit) {
	const ArrayRef ids = state.new_array();
	if (limit <= 0 || gd::is_empty(state, stack)) {
		return ids;
	}
	// Effects are kept in the order they landed: the newest is the last.
	const ArrayRef active = active_effects_for_round(state, stack, gd::int_field(state, battle, key::round, 1));
	for (int64_t index = state.array_size(active) - 1; index >= 0 && state.array_size(ids) < limit; --index) {
		const DictRef effect = gd::as_dict(state.at(active, index));
		const Atom effect_id = gd::string_field(state, effect, key::effect_id, key::empty);
		if (effect_id == key::empty || gd::array_has(state, ids, str(effect_id))) {
			continue;
		}
		if (helpful ? effect_helps_stack(state, effect) : effect_harms_stack(state, effect)) {
			state.append(ids, str(effect_id));
		}
	}
	return ids;
}

int64_t power_count(State &state, DictRef effect, Atom base_field, Atom divisor_field, int64_t power) {
	const int64_t base = engine_max<int64_t>(0, gd::int_field(state, effect, base_field, 0));
	const int64_t divisor = gd::int_field(state, effect, divisor_field, 0);
	if (divisor <= 0) {
		return base;
	}
	return gd::add(base, compat::int_div(engine_max<int64_t>(0, power), divisor));
}

int64_t spell_effect_count(State &state, DictRef spell, int64_t power) {
	const Value effect = gd::field(state, spell, key::effect);
	return gd::is_dict(effect) ? power_count(state, effect.ref, key::count, key::count_power_divisor, power) : 0;
}

int64_t spell_move_reach(State &state, DictRef spell, int64_t power) {
	const Value effect = gd::field(state, spell, key::effect);
	return gd::is_dict(effect) ? power_count(state, effect.ref, key::range, key::range_power_divisor, power) : 0;
}

bool cleanse_takes_any_harm(State &state, DictRef effect) {
	Value listed;
	const bool has_list = state.lookup(effect, str(key::cleanse_effect_ids), listed) && gd::is_array(listed) && state.array_size(listed.ref) > 0;
	return !has_list && gd::int_field(state, effect, key::count, 0) > 0;
}

ArrayRef move_destinations(State &state, DictRef battle, DictRef stack, int64_t reach) {
	if (gd::is_empty(state, stack) || _alive_count(state, stack) <= 0 || battle_rules::_stack_is_rooted(state, stack, battle)) {
		return state.new_array();
	}
	return battle_rules::_reachable_empty_hexes(state, battle, stack, reach);
}

DictRef move_destination_in_reach(State &state, ArrayRef destinations, const Value &destination) {
	const DictRef wanted = battle_rules::_normalize_hex_cell(state, destination);
	if (gd::is_empty(state, wanted)) {
		return state.new_dict();
	}
	const Atom wanted_key = battle_rules::_hex_key(state, wanted);
	for (const Value &cell : gd::items(state, gd::array_value(destinations))) {
		if (gd::is_dict(cell) && battle_rules::_hex_key(state, cell.ref) == wanted_key) {
			return battle_rules::_normalize_hex_cell(state, cell);
		}
	}
	return state.new_dict();
}

} // namespace aurelion::rules::port::spell_rules
