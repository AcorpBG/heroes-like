// Layer 8: the tier-4 and tier-5 battle mechanics of one stack (docs/magic-system-spells.md). Sanctuary keeps every
// hurt off its stack, and the stack makes no attack; Crucible Ward takes the next hurt and then lends +4 attack for
// the stack's next turn; Ironbark halves shots and spells. Molten Brand melts a point of defense at each hurt, to its
// cap. Grave Edge's blows ignore the target's defense. Poison hurts at the end of each of the stack's turns and halves
// healing on it. Censure turns its abilities off and keeps its own hero's spells from it. A Stunned stack loses its
// next turn. Death's Door takes a share of the stack's creatures at the end of its last counted turn.

#include "aurelion_rules/port/spell_rules.hpp"

#include "aurelion_rules/compat/godot_math.hpp"
#include "aurelion_rules/port/battle_payload.hpp"
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

Atom battle_id_of(const State &state, DictRef stack) {
	return gd::string_field(state, stack, key::battle_id, key::empty);
}

bool living(State &state, DictRef stack) {
	return !gd::is_empty(state, stack) && battle_rules::_alive_count(state, stack) > 0;
}

// A counted effect's last turn: it ends with the turn now ending.
bool last_counted_turn(State &state, DictRef effect) {
	return !gd::is_empty(state, effect) && !gd::bool_field(state, effect, key::skip_current_turn, false)
			&& gd::int_field(state, effect, key::turns_left, 1) <= 1;
}

} // namespace

// --- Wards -------------------------------------------------------------------------

bool in_sanctuary(State &state, DictRef battle, DictRef stack) {
	return !gd::is_empty(state, stack) && !gd::is_empty(state, stack_mechanic_effect(state, stack, battle, key::invulnerable));
}

bool halves_shots_and_spells(State &state, DictRef battle, DictRef stack) {
	return !gd::is_empty(state, stack) && !gd::is_empty(state, stack_mechanic_effect(state, stack, battle, key::half_ranged));
}

int64_t hit_after_wards(State &state, DictRef battle, DictRef stack, int64_t damage) {
	if (damage <= 0 || !living(state, stack)) {
		return damage;
	}
	const Atom label = battle_rules::_stack_label(state, stack);
	if (in_sanctuary(state, battle, stack)) {
		battle_rules::_record_event(state, battle, gd::format(state, key::sanctuary_keeps_text, { str(label) }));
		return 0;
	}
	const DictRef ward = stack_mechanic_effect(state, stack, battle, key::absorb_one);
	if (gd::is_empty(state, ward)) {
		return damage;
	}
	// Crucible Ward: the hurt comes to nothing, then the stack strikes harder on its next turn.
	const int64_t attack = gd::int_field(state, effect_mechanic(state, ward), key::absorb_attack, 0);
	const Atom source_id = gd::string_field(state, ward, key::source_id, key::empty);
	const Atom ward_label = gd::string_field(state, ward, key::label, key::spell_word);
	remove_stack_effect(state, stack, ward);
	if (attack > 0) {
		const DictRef modifiers = state.new_dict();
		state.set(modifiers, str(key::attack), int_value(attack));
		const Atom surge_id = gd::format(state, key::spell_effect_id_format, { str(source_id), str(key::absorb_attack) });
		const DictRef surge = build_battle_effect(state, surge_id, ward_label, dict_value(modifiers), 1, battle, key::spell, source_id, array_value(state.new_array()));
		battle_rules::_apply_stack_effect(state, battle, battle_id_of(state, stack), dict_value(_counted_in_turns(state, surge, 1)));
	}
	battle_rules::_record_event(state, battle, gd::format(state, key::ward_takes_hit_text, { str(ward_label), str(label), int_value(attack) }));
	return 0;
}

// --- Molten Brand and Grave Edge -----------------------------------------------------

void brand_melts(State &state, DictRef battle, DictRef stack) {
	const DictRef brand = stack_status_effect(state, stack, battle, key::status_branded);
	if (gd::is_empty(state, brand)) {
		return;
	}
	const DictRef mechanic = effect_mechanic(state, brand);
	const int64_t cap = gd::int_field(state, mechanic, key::defense_melt, 0);
	const int64_t melted = gd::int_field(state, mechanic, key::melted, 0);
	if (melted >= cap) {
		return;
	}
	state.set(mechanic, str(key::melted), int_value(gd::add(melted, 1)));
	Value modifiers;
	if (!state.lookup(brand, str(key::modifiers), modifiers) || !gd::is_dict(modifiers)) {
		modifiers = dict_value(state.new_dict());
		state.set(brand, str(key::modifiers), modifiers);
	}
	state.set(modifiers.ref, str(key::defense), int_value(-gd::add(melted, 1)));
	battle_rules::_record_event(state, battle, gd::format(state, key::brand_melts_text, { str(battle_rules::_stack_label(state, stack)), int_value(gd::add(melted, 1)) }));
}

bool pierces_defense(State &state, DictRef battle, DictRef attacker) {
	return !gd::is_empty(state, attacker) && stack_mechanic_int(state, attacker, battle, key::pierce_blows) > 0;
}

void spend_pierce(State &state, DictRef battle, Atom attacker_id) {
	const DictRef attacker = battle_rules::_get_stack_by_id(state, battle, attacker_id);
	const DictRef edge = gd::is_empty(state, attacker) ? state.new_dict() : stack_mechanic_effect(state, attacker, battle, key::pierce_blows);
	if (gd::is_empty(state, edge)) {
		return;
	}
	const DictRef mechanic = effect_mechanic(state, edge);
	const int64_t left = gd::sub(gd::int_field(state, mechanic, key::pierce_blows, 0), 1);
	if (left <= 0) {
		remove_stack_effect(state, attacker, edge);
	} else {
		state.set(mechanic, str(key::pierce_blows), int_value(left));
	}
}

// --- Poison, Censure and Stun ------------------------------------------------------

int64_t poisoned_healing(State &state, DictRef battle, DictRef stack, int64_t amount) {
	if (amount <= 0 || gd::is_empty(state, stack) || gd::is_empty(state, stack_status_effect(state, stack, battle, key::status_poisoned))) {
		return amount;
	}
	return compat::int_div(amount, 2);
}

bool censured(State &state, DictRef stack) {
	Value effects;
	if (gd::is_empty(state, stack) || !state.lookup(stack, str(key::effects), effects) || !gd::is_array(effects)) {
		return false;
	}
	for (const Value &effect : gd::items(state, effects)) {
		if (gd::is_dict(effect) && gd::string_field(state, effect.ref, key::effect_id, key::empty) == key::status_censured) {
			return true;
		}
	}
	return false;
}

bool stunned_turn(State &state, DictRef battle, Atom battle_id) {
	const DictRef stack = battle_rules::_get_stack_by_id(state, battle, battle_id);
	if (!living(state, stack) || gd::is_empty(state, stack_status_effect(state, stack, battle, key::status_stunned))) {
		return false;
	}
	battle_rules::_record_event(state, battle, gd::format(state, key::stunned_loses_turn_text, { str(battle_rules::_stack_label(state, stack)) }));
	return true;
}

// --- Turn ends ---------------------------------------------------------------------

void end_of_turn_tier45(State &state, DictRef battle, Atom battle_id) {
	DictRef stack = battle_rules::_get_stack_by_id(state, battle, battle_id);
	if (!living(state, stack)) {
		return;
	}
	const Atom label = battle_rules::_stack_label(state, stack);
	// Poison hurts at the end of each of its turns.
	const int64_t poison = gd::int_field(state, effect_mechanic(state, stack_status_effect(state, stack, battle, key::status_poisoned)), key::poison_damage, 0);
	if (poison > 0) {
		battle_rules::_apply_damage_to_stack(state, battle, battle_id, poison);
		battle_rules::_record_event(state, battle, gd::format(state, key::poison_hurts_text, { str(label), int_value(poison) }));
		stack = battle_rules::_get_stack_by_id(state, battle, battle_id);
		if (!living(state, stack)) {
			return;
		}
	}
	// Death's Door takes its share of the creatures as its last turn ends.
	const DictRef door = stack_status_effect(state, stack, battle, key::status_deaths_door);
	if (last_counted_turn(state, door)) {
		const int64_t pct = gd::int_field(state, effect_mechanic(state, door), key::doom_pct, 0);
		remove_stack_effect(state, stack, door);
		const int64_t alive = battle_rules::_alive_count(state, stack);
		if (pct > 0 && alive > 0) {
			const int64_t lost = engine_max<int64_t>(1, compat::int_div(gd::add(gd::mul(alive, pct), 50), 100));
			const int64_t unit_hp = engine_max<int64_t>(1, gd::int_field(state, stack, key::unit_hp, 1));
			battle_rules::_record_event(state, battle, gd::format(state, key::deaths_door_falls_text, { str(label), int_value(engine_min<int64_t>(lost, alive)) }));
			battle_rules::_apply_damage_to_stack(state, battle, battle_id, gd::mul(engine_min<int64_t>(lost, alive), unit_hp));
		}
	}
}

// --- Death's Door's cast -------------------------------------------------------------

int64_t deaths_door_pct(State &state, DictRef hero, DictRef battle, DictRef spell, DictRef target) {
	const DictRef effect = gd::as_dict(state.get(spell, str(key::effect), dict_value(state.new_dict())));
	const int64_t power = spell_power_against(state, hero, battle, target);
	const int64_t pct = gd::add(gd::int_field(state, effect, key::doom_pct, 0), gd::mul(gd::int_field(state, effect, key::doom_pct_power_scale, 0), power));
	const int64_t resistance = spell_damage_resistance_pct(state, battle, target, spell);
	return engine_max<int64_t>(1, engine_min<int64_t>(100, compat::int_div(gd::mul(pct, gd::sub(100, resistance)), 100)));
}

} // namespace aurelion::rules::port::spell_rules
