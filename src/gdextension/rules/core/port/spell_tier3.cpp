// Layer 8: the lasting mechanics the tier-3 spells bring (docs/magic-system-spells.md, Mechanics). Burning, left by
// Cinderfall and Molten Edge's burning blows, hurts at the end of each of the stack's turns. Tolling Doom lands at
// the end of its last turn and Last Breath heals then. A hit passes Tempering's cap, Last Breath's last creature,
// Seed of Return's regrowth and Budding's creatures (they fall first and wither when the battle ends). Blight turns
// healing into harm, Rekindle raises fallen creatures, Glass Aegis refuses enemy spells and Steadfast Halo holds
// cohesion. Flashpoint spends a stack's Heat, Earthsplit knocks a stack back toward its own edge, Volley Signal fires
// a side's shooters at a stack and Watchful Light heals its side's most wounded stack at the start of each round.

#include "aurelion_rules/port/spell_rules.hpp"

#include "aurelion_rules/compat/godot_math.hpp"
#include "aurelion_rules/port/battle_footprint.hpp"
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

namespace {

// Burning blows leave Burning for this many of the target's turns unless the mechanic names its own.
constexpr int64_t BURNING_BLOW_TURNS = 2;

Atom side_of(const State &state, DictRef stack) {
	return gd::string_field(state, stack, key::side, key::empty);
}

Atom battle_id_of(const State &state, DictRef stack) {
	return gd::string_field(state, stack, key::battle_id, key::empty);
}

bool living(State &state, DictRef stack) {
	return !gd::is_empty(state, stack) && _alive_count(state, stack) > 0;
}

// A counted effect's last turn: it ends with the turn now ending.
bool last_counted_turn(State &state, DictRef effect) {
	return !gd::is_empty(state, effect) && !gd::bool_field(state, effect, key::skip_current_turn, false)
			&& gd::int_field(state, effect, key::turns_left, 1) <= 1;
}

DictRef cell_at(State &state, int64_t q, int64_t r) {
	const DictRef cell = state.new_dict();
	state.set(cell, str(key::q), int_value(q));
	state.set(cell, str(key::r), int_value(r));
	return cell;
}

} // namespace

// --- Statuses ------------------------------------------------------------------

DictRef burning_payload(State &state, DictRef battle, Atom source_id, int64_t damage, int64_t turns) {
	const DictRef built = build_battle_effect(state, key::status_burning, key::burning_label_text, dict_value(state.new_dict()), turns, battle, key::spell, source_id, array_value(state.new_array()));
	const DictRef mechanic = state.new_dict();
	state.set(mechanic, str(key::burning_damage), int_value(engine_max<int64_t>(1, damage)));
	state.set(built, str(key::mechanic), dict_value(mechanic));
	return _counted_in_turns(state, built, turns);
}

Atom burning_blow(State &state, DictRef battle, DictRef striker, Atom defender_id) {
	const DictRef blows = stack_mechanic_effect(state, striker, battle, key::on_hit_burning);
	const DictRef defender = battle_rules::_get_stack_by_id(state, battle, defender_id);
	if (gd::is_empty(state, blows) || !living(state, defender) || defender_id == battle_id_of(state, striker)
			|| target_is_immune_to_status(state, defender, battle, key::status_burning)) {
		return key::empty;
	}
	const DictRef mechanic = effect_mechanic(state, blows);
	const int64_t damage = gd::int_field(state, mechanic, key::on_hit_burning, 0);
	const int64_t turns = engine_max<int64_t>(1, gd::int_field(state, mechanic, key::burning_turns, BURNING_BLOW_TURNS));
	const Atom source_id = gd::string_field(state, blows, key::source_id, key::empty);
	battle_rules::_apply_stack_effect(state, battle, defender_id, dict_value(burning_payload(state, battle, source_id, damage, turns)));
	// Full Steam: only the first blow that lands sets its target Burning.
	if (gd::int_field(state, mechanic, key::on_hit_once, 0) > 0) {
		state.erase(mechanic, str(key::on_hit_burning));
	}
	return gd::format(state, key::set_burning_text, { str(battle_rules::_stack_label(state, defender)) });
}

void end_of_turn_tier3(State &state, DictRef battle, Atom battle_id) {
	DictRef stack = battle_rules::_get_stack_by_id(state, battle, battle_id);
	if (!living(state, stack)) {
		return;
	}
	const Atom label = battle_rules::_stack_label(state, stack);
	// Burning hurts at the end of each of its turns.
	const int64_t burn = gd::int_field(state, effect_mechanic(state, stack_status_effect(state, stack, battle, key::status_burning)), key::burning_damage, 0);
	if (burn > 0) {
		battle_rules::_apply_damage_to_stack(state, battle, battle_id, burn);
		battle_rules::_record_event(state, battle, gd::format(state, key::burns_for_text, { str(label), int_value(burn) }));
		stack = battle_rules::_get_stack_by_id(state, battle, battle_id);
		if (!living(state, stack)) {
			return;
		}
	}
	// Tolling Doom lands as its last turn ends.
	const DictRef doom = stack_status_effect(state, stack, battle, key::status_doomed);
	if (last_counted_turn(state, doom)) {
		const int64_t damage = gd::int_field(state, effect_mechanic(state, doom), key::doom_damage, 0);
		remove_stack_effect(state, stack, doom);
		if (damage > 0) {
			battle_rules::_apply_damage_to_stack(state, battle, battle_id, damage);
			battle_rules::_record_event(state, battle, gd::format(state, key::doom_falls_text, { str(label), int_value(damage) }));
		}
		stack = battle_rules::_get_stack_by_id(state, battle, battle_id);
		if (!living(state, stack)) {
			return;
		}
	}
	// Last Breath heals as it ends.
	const DictRef breath = stack_mechanic_effect(state, stack, battle, key::deathless);
	if (last_counted_turn(state, breath)) {
		const int64_t heal = gd::int_field(state, effect_mechanic(state, breath), key::deathless_heal, 0);
		remove_stack_effect(state, stack, breath);
		const int64_t restored = heal > 0 ? battle_rules::_restore_stack_health(state, battle, battle_id, heal) : 0;
		if (restored > 0) {
			battle_rules::_record_event(state, battle, gd::format(state, key::catches_breath_text, { str(label), int_value(restored) }));
		}
	}
}

// --- Hits and healing -----------------------------------------------------------

int64_t health_after_hit(State &state, DictRef battle, DictRef stack, int64_t health, int64_t taken) {
	taken = engine_max<int64_t>(0, taken);
	if (taken <= 0 || health <= 0) {
		return engine_max<int64_t>(0, gd::sub(health, taken));
	}
	// Tempering: no single hit takes more than its share of the health the stack has.
	const int64_t cap_pct = stack_mechanic_int(state, stack, battle, key::damage_cap_pct);
	if (cap_pct > 0) {
		taken = engine_min<int64_t>(taken, engine_max<int64_t>(1, compat::int_div(gd::mul(health, cap_pct), 100)));
	}
	int64_t after = engine_max<int64_t>(0, gd::sub(health, taken));
	const bool would_fall = after <= 0;
	if (would_fall) {
		const Atom label = battle_rules::_stack_label(state, stack);
		const DictRef seed = stack_mechanic_effect(state, stack, battle, key::death_save_pct);
		if (stack_mechanic_int(state, stack, battle, key::deathless) > 0) {
			// Last Breath: its last creature holds on.
			after = 1;
			battle_rules::_record_event(state, battle, gd::format(state, key::clings_to_life_text, { str(label) }));
		} else if (!gd::is_empty(state, seed)) {
			// Seed of Return: it grows back once with a share of the creatures it started with.
			const int64_t pct = gd::int_field(state, effect_mechanic(state, seed), key::death_save_pct, 0);
			const int64_t count = engine_max<int64_t>(1, compat::int_div(gd::mul(engine_max<int64_t>(1, gd::int_field(state, stack, key::base_count, 1)), pct), 100));
			after = gd::mul(count, engine_max<int64_t>(1, gd::int_field(state, stack, key::unit_hp, 1)));
			remove_stack_effect(state, stack, seed);
			battle_rules::_record_event(state, battle, gd::format(state, key::regrows_from_seed_text, { str(label), int_value(count) }));
		}
	}
	// Budding: the budded creatures fall first, and all of them with a stack that falls.
	const int64_t budded = gd::int_field(state, stack, key::budded_health, 0);
	if (budded > 0) {
		const int64_t kept = would_fall ? 0 : engine_max<int64_t>(0, gd::sub(budded, gd::sub(health, after)));
		state.set(stack, str(key::budded_health), int_value(kept));
	}
	return after;
}

int64_t kept_alive_count(State &state, DictRef stack) {
	// A conjured stack leaves with the battle.
	if (is_conjured(state, stack)) {
		return 0;
	}
	const int64_t unit_hp = engine_max<int64_t>(1, gd::int_field(state, stack, key::unit_hp, 1));
	const int64_t health = engine_max<int64_t>(0, gd::sub(gd::int_field(state, stack, key::total_health, 0), engine_max<int64_t>(0, gd::int_field(state, stack, key::budded_health, 0))));
	return compat::int_div(gd::add(health, gd::sub(unit_hp, 1)), unit_hp);
}

int64_t bud_stack(State &state, DictRef battle, Atom battle_id, int64_t amount) {
	const DictRef stack = battle_rules::_get_stack_by_id(state, battle, battle_id);
	if (!living(state, stack) || amount <= 0) {
		return 0;
	}
	state.set(stack, str(key::total_health), int_value(gd::add(gd::int_field(state, stack, key::total_health, 0), amount)));
	state.set(stack, str(key::budded_health), int_value(gd::add(gd::int_field(state, stack, key::budded_health, 0), amount)));
	battle_rules::_sync_occupied_hexes(state, battle);
	return amount;
}

bool blight_turns_heal(State &state, DictRef battle, DictRef stack, int64_t amount) {
	const DictRef blight = stack_status_effect(state, stack, battle, key::status_blighted);
	if (gd::is_empty(state, blight)) {
		return false;
	}
	const int64_t pct = gd::int_field(state, effect_mechanic(state, blight), key::heal_inversion_pct, 100);
	const int64_t harm = compat::int_div(gd::mul(engine_max<int64_t>(0, amount), engine_max<int64_t>(0, pct)), 100);
	if (harm > 0 && living(state, stack)) {
		const Atom label = battle_rules::_stack_label(state, stack);
		battle_rules::_apply_damage_to_stack(state, battle, battle_id_of(state, stack), harm);
		battle_rules::_record_event(state, battle, gd::format(state, key::blight_turns_healing_text, { str(label), int_value(harm) }));
	}
	return true;
}

int64_t raise_stack_health(State &state, DictRef battle, Atom battle_id, int64_t amount) {
	const DictRef stack = battle_rules::_get_stack_by_id(state, battle, battle_id);
	if (!living(state, stack) || amount <= 0 || heal_blocked(state, stack, battle)) {
		return 0;
	}
	if (blight_turns_heal(state, battle, stack, amount)) {
		return 0;
	}
	amount = poisoned_healing(state, battle, stack, amount);
	const int64_t health = gd::int_field(state, stack, key::total_health, 0);
	const int64_t full = gd::mul(engine_max<int64_t>(1, gd::int_field(state, stack, key::unit_hp, 1)), engine_max<int64_t>(0, gd::int_field(state, stack, key::base_count, 0)));
	const int64_t raised = engine_max<int64_t>(0, engine_min<int64_t>(amount, gd::sub(full, health)));
	if (raised > 0) {
		state.set(stack, str(key::total_health), int_value(gd::add(health, raised)));
		battle_rules::_sync_occupied_hexes(state, battle);
	}
	return raised;
}

bool spell_shielded(State &state, DictRef battle, DictRef stack) {
	return !gd::is_empty(state, stack) && !gd::is_empty(state, stack_mechanic_effect(state, stack, battle, key::spell_shield));
}

bool cohesion_locked(State &state, DictRef battle, DictRef stack) {
	return !gd::is_empty(state, stack) && !gd::is_empty(state, stack_mechanic_effect(state, stack, battle, key::cohesion_lock));
}

// --- Heat, knockback and volleys --------------------------------------------------

Atom spend_or_kindle_heat(State &state, DictRef battle, Atom battle_id) {
	const DictRef stack = battle_rules::_get_stack_by_id(state, battle, battle_id);
	if (!living(state, stack)) {
		return key::empty;
	}
	if (gd::int_field(state, stack, key::spell_heat, 0) > 0) {
		state.set(stack, str(key::spell_heat), int_value(0));
		return gd::format(state, key::heat_spent_suffix_text, { str(battle_rules::_stack_label(state, stack)) });
	}
	return add_heat(state, battle, battle_id, 1, 0);
}

DictRef push_cell(State &state, DictRef battle, DictRef stack, int64_t steps) {
	if (!living(state, stack) || steps <= 0 || battle_rules::_stack_is_rooted(state, stack, battle)) {
		return state.new_dict();
	}
	const DictRef hex = battle_rules::_stack_hex(state, stack);
	if (gd::is_empty(state, hex)) {
		return state.new_dict();
	}
	// Back is toward the stack's own edge: the player's side stands at the west edge.
	const int64_t step = side_of(state, stack) == key::player ? -1 : 1;
	const int64_t q = gd::int_field(state, hex, key::q, -1);
	const int64_t r = gd::int_field(state, hex, key::r, -1);
	const DictRef blocked = battle_rules::_build_blocking_map(state, battle);
	DictRef reached = state.new_dict();
	for (int64_t moved = 1; moved <= steps; ++moved) {
		const DictRef cell = cell_at(state, gd::add(q, gd::mul(step, moved)), r);
		if (gd::int_field(state, cell, key::q, -1) < 0
				|| !battle_footprint::fits(state, stack, dict_value(cell), blocked, battle_rules::BATTLE_HEX_COLUMNS, battle_rules::BATTLE_HEX_ROWS)) {
			break;
		}
		reached = cell;
	}
	return reached;
}

ArrayRef volley_shooters(State &state, DictRef battle, Atom side, DictRef target) {
	const ArrayRef ids = state.new_array();
	for (const Value &stack : gd::field_items(state, battle, str(key::stacks))) {
		if (gd::is_dict(stack) && side_of(state, stack.ref) == side && battle_rules::_can_make_ranged_attack(state, stack.ref, battle, target)) {
			state.append(ids, str(battle_id_of(state, stack.ref)));
		}
	}
	return ids;
}

int64_t volley_shot_damage(State &state, DictRef battle, DictRef shooter, DictRef target, int64_t pct) {
	// A volley shot hits for the middle of the shooter's damage, at the volley's share.
	const int64_t low = gd::int_field(state, shooter, key::min_damage, 1);
	const int64_t high = engine_max<int64_t>(low, gd::int_field(state, shooter, key::max_damage, 1));
	const int64_t distance = battle_rules::_attack_distance_for_action(state, shooter, target, battle, true);
	const int64_t full = battle_rules::_damage_for_roll(state, shooter, target, battle, compat::int_div(gd::add(low, high), 2), true, false, distance);
	return engine_max<int64_t>(1, compat::int_div(gd::mul(full, engine_max<int64_t>(0, pct)), 100));
}

Atom fire_volley(State &state, DictRef battle, Atom side, Atom target_id, int64_t pct) {
	std::string text;
	const ArrayRef shooters = volley_shooters(state, battle, side, battle_rules::_get_stack_by_id(state, battle, target_id));
	for (const Value &shooter_value : gd::items(state, array_value(shooters))) {
		const Atom shooter_id = gd::to_string(shooter_value);
		const DictRef shooter = battle_rules::_get_stack_by_id(state, battle, shooter_id);
		const DictRef target = battle_rules::_get_stack_by_id(state, battle, target_id);
		if (!living(state, target)) {
			break;
		}
		if (!battle_rules::_can_make_ranged_attack(state, shooter, battle, target)) {
			continue;
		}
		const int64_t damage = volley_shot_damage(state, battle, shooter, target, pct);
		const Atom shooter_label = battle_rules::_stack_label(state, shooter);
		const Atom target_label = battle_rules::_stack_label(state, target);
		battle_rules::_apply_damage_to_stack(state, battle, target_id, damage);
		battle_rules::_consume_shot(state, battle, shooter_id);
		text += state.text(gd::format(state, key::volley_shot_text, { str(shooter_label), str(target_label), int_value(damage) }));
		for (const Value &extra : gd::items(state, array_value(after_blow_mechanics(state, battle, shooter_id, target_id, true, damage)))) {
			text += " " + state.text(gd::to_string(extra));
		}
	}
	return state.intern(text);
}

ArrayRef enemies_beside(State &state, DictRef battle, DictRef stack) {
	const ArrayRef beside = state.new_array();
	if (!living(state, stack)) {
		return beside;
	}
	for (const Value &other : gd::field_items(state, battle, str(key::stacks))) {
		if (gd::is_dict(other) && living(state, other.ref) && side_of(state, other.ref) != side_of(state, stack)
				&& battle_rules::_stack_hex_distance(state, stack, other.ref) == 1) {
			state.append(beside, other);
		}
	}
	return beside;
}

// --- Auras ------------------------------------------------------------------------

void add_battle_aura(State &state, DictRef battle, DictRef entry) {
	// A newer aura of a kind takes the place of its side's older one.
	const ArrayRef kept = state.new_array();
	for (const Value &aura : gd::field_items(state, battle, str(key::spell_auras))) {
		if (gd::is_dict(aura) && !(gd::string_field(state, aura.ref, key::aura, key::empty) == gd::string_field(state, entry, key::aura, key::empty)
									 && gd::string_field(state, aura.ref, key::side, key::empty) == gd::string_field(state, entry, key::side, key::empty))) {
			state.append(kept, aura);
		}
	}
	state.append(kept, dict_value(entry));
	state.set(battle, str(key::spell_auras), array_value(kept));
}

DictRef most_wounded_stack(State &state, DictRef battle, Atom side) {
	DictRef best = state.new_dict();
	int64_t best_missing = 0;
	double best_ratio = 2.0;
	for (const Value &stack : gd::field_items(state, battle, str(key::stacks))) {
		if (!gd::is_dict(stack) || side_of(state, stack.ref) != side || !living(state, stack.ref)
				|| heal_blocked(state, stack.ref, battle) || !gd::is_empty(state, stack_status_effect(state, stack.ref, battle, key::status_blighted))
				|| censured(state, stack.ref)) {
			continue;
		}
		const int64_t missing = battle_spell_recoverable_health(state, stack.ref);
		const double ratio = _health_ratio(state, stack.ref);
		if (missing > best_missing || (missing > 0 && missing == best_missing && ratio < best_ratio)) {
			best = stack.ref;
			best_missing = missing;
			best_ratio = ratio;
		}
	}
	return best;
}

void round_start_auras(State &state, DictRef battle, int64_t round) {
	Value auras;
	if (!state.lookup(battle, str(key::spell_auras), auras) || !gd::is_array(auras)) {
		return;
	}
	const ArrayRef kept = state.new_array();
	for (const Value &aura : gd::items(state, auras)) {
		if (!gd::is_dict(aura) || gd::int_field(state, aura.ref, key::until_round, 0) < round) {
			continue;
		}
		state.append(kept, aura);
		if (gd::int_field(state, aura.ref, key::healed_round, 0) >= round) {
			continue;
		}
		state.set(aura.ref, str(key::healed_round), int_value(round));
		// Second Sun: every stack of the other side burns as the round before ends.
		if (gd::string_field(state, aura.ref, key::aura, key::empty) == key::sun) {
			second_sun_burns(state, battle, aura.ref);
			continue;
		}
		// Watchful Light: its side's most wounded stack heals.
		if (gd::string_field(state, aura.ref, key::aura, key::empty) == key::triage) {
			const DictRef stack = most_wounded_stack(state, battle, gd::string_field(state, aura.ref, key::side, key::empty));
			if (gd::is_empty(state, stack)) {
				continue;
			}
			const Atom label = battle_rules::_stack_label(state, stack);
			const int64_t restored = battle_rules::_restore_stack_health(state, battle, battle_id_of(state, stack), gd::int_field(state, aura.ref, key::heal, 0));
			if (restored > 0) {
				battle_rules::_record_event(state, battle, gd::format(state, key::watchful_light_heals_text, {
					str(gd::string_field(state, aura.ref, key::label, key::empty)), str(label), int_value(restored) }));
			}
		}
	}
	state.set(battle, str(key::spell_auras), array_value(kept));
}

} // namespace aurelion::rules::port::spell_rules
