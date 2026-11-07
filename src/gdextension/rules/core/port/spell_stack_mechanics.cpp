// Layer 8: the lasting mechanics the tier-2 spells put on stacks (docs/magic-system-spells.md, Mechanics): an
// effect's mechanic values, resolved from spell power at the cast, and the hooks the battle calls with them: the
// plate that takes damage first, the sleeper a hit wakes, the curse that jumps when its stack falls, the sealed
// wound no healing reaches, a stack's turn start (regrowth, sleep) and end (backlash, curse, tightening roots), a
// blow's extras (stand fast, marked, blinded, thorns, lifesteal, momentum), confused blows, refused shots, Heat,
// Call to Arms in the turn order and fear of the enemy's stacks.

#include "aurelion_rules/port/spell_rules.hpp"

#include "aurelion_rules/compat/godot_math.hpp"
#include "aurelion_rules/compat/godot_string.hpp"
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

// Heat: a burst at 3 (docs/magic-system-spells.md, Damage).
constexpr int64_t HEAT_TO_BURST = 3;
// Marked stacks take this much more from the other side's blows unless the
// mark names its own share; Blinded blows keep this share.
constexpr int64_t MARKED_DAMAGE_PCT = 20;
constexpr double BLINDED_BLOW_SHARE = 0.7;
// Guards the sleepers' skipped turns within one advance.
constexpr int64_t MAX_SKIPPED_TURNS = 64;

bool ends_with(const std::string &text, const std::string &suffix) {
	return text.size() > suffix.size() && text.compare(text.size() - suffix.size(), suffix.size(), suffix) == 0;
}

Atom side_of(const State &state, DictRef stack) {
	return gd::string_field(state, stack, key::side, key::empty);
}

Atom battle_id_of(const State &state, DictRef stack) {
	return gd::string_field(state, stack, key::battle_id, key::empty);
}

// The stack's own effects Array in the battle, or an empty one.
ArrayRef raw_effects(State &state, DictRef stack) {
	Value effects;
	if (!gd::is_empty(state, stack) && state.lookup(stack, str(key::effects), effects) && gd::is_array(effects)) {
		return effects.ref;
	}
	return state.new_array();
}

bool effect_active(State &state, DictRef effect, DictRef battle) {
	return gd::int_field(state, effect, key::expires_after_round, 0) >= gd::int_field(state, battle, key::round, 1);
}

// A stable pick in [0, count) for a draw named by parts: the battle's random
// streams are left as they are.
int64_t stable_pick(State &state, DictRef battle, std::initializer_list<Value> parts, int64_t count) {
	if (count <= 1) {
		return 0;
	}
	const ArrayRef text_parts = state.new_array();
	state.append(text_parts, str(gd::stringify(state, gd::field_or(state, battle, key::combat_seed, int_value(0)))));
	state.append(text_parts, int_value(gd::int_field(state, battle, key::round, 1)));
	state.append(text_parts, int_value(gd::int_field(state, battle, key::turn_index, 0)));
	for (const Value &part : parts) {
		state.append(text_parts, str(gd::stringify(state, part)));
	}
	return compat::posmod(gd::hash(state, array_value(text_parts)), count);
}

ArrayRef alive_stacks(State &state, DictRef battle) {
	const ArrayRef alive = state.new_array();
	for (const Value &stack : gd::field_items(state, battle, str(key::stacks))) {
		if (gd::is_dict(stack) && _alive_count(state, stack.ref) > 0) {
			state.append(alive, stack);
		}
	}
	return alive;
}

} // namespace

int64_t stable_draw(State &state, DictRef battle, std::initializer_list<Value> parts, int64_t count) {
	return stable_pick(state, battle, parts, count);
}

DictRef effect_mechanic(State &state, DictRef effect) {
	Value mechanic;
	if (!gd::is_empty(state, effect) && state.lookup(effect, str(key::mechanic), mechanic) && gd::is_dict(mechanic)) {
		return mechanic.ref;
	}
	return state.new_dict();
}

DictRef resolve_mechanic(State &state, const Value &raw, int64_t power) {
	const DictRef resolved = state.new_dict();
	if (!gd::is_dict(raw)) {
		return resolved;
	}
	const state::ValueList names = state.dict(raw.ref).keys.list();
	for (const Value &name : names) {
		const std::string text = state.text(gd::to_string(name));
		if (ends_with(text, "_power_scale") || ends_with(text, "_power_divisor")) {
			continue;
		}
		const Value value = gd::index(state, raw.ref, name);
		if (!gd::is_int(value) && !gd::is_float(value)) {
			state.set(resolved, name, value);
			continue;
		}
		int64_t amount = gd::to_int(state, value);
		amount = gd::add(amount, gd::mul(gd::int_field(state, raw.ref, state.intern(text + "_power_scale"), 0), engine_max<int64_t>(0, power)));
		const int64_t divisor = gd::int_field(state, raw.ref, state.intern(text + "_power_divisor"), 0);
		if (divisor > 0) {
			amount = gd::add(amount, compat::int_div(engine_max<int64_t>(0, power), divisor));
		}
		state.set(resolved, name, int_value(amount));
	}
	return resolved;
}

DictRef stack_mechanic_effect(State &state, DictRef stack, DictRef battle, Atom field) {
	const ArrayRef effects = raw_effects(state, stack);
	for (int64_t index = state.array_size(effects) - 1; index >= 0; --index) {
		const Value effect = state.at(effects, index);
		if (!gd::is_dict(effect) || !effect_active(state, effect.ref, battle)) {
			continue;
		}
		if (state.has(effect_mechanic(state, effect.ref), str(field))) {
			return effect.ref;
		}
	}
	return state.new_dict();
}

int64_t stack_mechanic_int(State &state, DictRef stack, DictRef battle, Atom field) {
	const DictRef effect = stack_mechanic_effect(state, stack, battle, field);
	return gd::is_empty(state, effect) ? 0 : gd::int_field(state, effect_mechanic(state, effect), field, 0);
}

DictRef stack_status_effect(State &state, DictRef stack, DictRef battle, Atom effect_id) {
	const ArrayRef effects = raw_effects(state, stack);
	for (int64_t index = state.array_size(effects) - 1; index >= 0; --index) {
		const Value effect = state.at(effects, index);
		if (gd::is_dict(effect) && effect_active(state, effect.ref, battle) && gd::string_field(state, effect.ref, key::effect_id, key::empty) == effect_id) {
			return effect.ref;
		}
	}
	return state.new_dict();
}

void remove_stack_effect(State &state, DictRef stack, DictRef effect) {
	const ArrayRef effects = raw_effects(state, stack);
	for (int64_t index = state.array_size(effects) - 1; index >= 0; --index) {
		const Value candidate = state.at(effects, index);
		if (gd::is_dict(candidate) && candidate.ref == effect) {
			gd::remove_at(state, effects, index);
			return;
		}
	}
}

ArrayRef newest_status_ids(State &state, DictRef stack, DictRef battle, int64_t limit) {
	const ArrayRef ids = state.new_array();
	const ArrayRef effects = raw_effects(state, stack);
	for (int64_t index = state.array_size(effects) - 1; index >= 0 && state.array_size(ids) < limit; --index) {
		const Value effect = state.at(effects, index);
		if (!gd::is_dict(effect) || !effect_active(state, effect.ref, battle)) {
			continue;
		}
		const Atom effect_id = gd::string_field(state, effect.ref, key::effect_id, key::empty);
		if (is_harmful_status(effect_id) && !gd::array_has(state, ids, str(effect_id))) {
			state.append(ids, str(effect_id));
		}
	}
	return ids;
}

int64_t opposing_side_knowledge(State &state, DictRef battle, Atom side) {
	const Atom other = side == key::player ? static_cast<Atom>(key::enemy) : static_cast<Atom>(key::player);
	const DictRef hero = battle_rules::_hero_payload_for_side(state, battle, other);
	return engine_max<int64_t>(0, gd::int_field(state, hero, key::knowledge, 0));
}

// --- Damage and healing ----------------------------------------------------

int64_t plate_absorb(State &state, DictRef battle, DictRef stack, int64_t damage) {
	if (damage <= 0) {
		return damage;
	}
	const DictRef effect = stack_mechanic_effect(state, stack, battle, key::plate);
	if (gd::is_empty(state, effect)) {
		return damage;
	}
	const DictRef mechanic = effect_mechanic(state, effect);
	const int64_t plate = engine_max<int64_t>(0, gd::int_field(state, mechanic, key::plate, 0));
	const int64_t absorbed = engine_min<int64_t>(plate, damage);
	const Atom label = battle_rules::_stack_label(state, stack);
	if (absorbed >= plate) {
		remove_stack_effect(state, stack, effect);
		battle_rules::_record_event(state, battle, gd::format(state, key::plate_breaks_text, { int_value(absorbed), str(label) }));
	} else {
		state.set(mechanic, str(key::plate), int_value(gd::sub(plate, absorbed)));
		battle_rules::_record_event(state, battle, gd::format(state, key::plate_absorbs_text, { int_value(absorbed), str(label) }));
	}
	return gd::sub(damage, absorbed);
}

void after_stack_damaged(State &state, DictRef battle, Atom battle_id, int64_t taken, bool killed) {
	const DictRef stack = battle_rules::_get_stack_by_id(state, battle, battle_id);
	if (gd::is_empty(state, stack)) {
		return;
	}
	if (taken > 0 && !killed) {
		const DictRef sleep = stack_status_effect(state, stack, battle, key::status_asleep);
		if (!gd::is_empty(state, sleep)) {
			remove_stack_effect(state, stack, sleep);
			battle_rules::_record_event(state, battle, gd::format(state, key::wakes_up_text, { str(battle_rules::_stack_label(state, stack)) }));
		}
	}
	if (!killed) {
		return;
	}
	const DictRef curse = stack_status_effect(state, stack, battle, key::status_cursed);
	if (gd::is_empty(state, curse)) {
		return;
	}
	// The curse jumps to the nearest stack of the fallen one's side.
	DictRef nearest = state.new_dict();
	int64_t nearest_distance = 0;
	for (const Value &other : gd::items(state, array_value(alive_stacks(state, battle)))) {
		if (side_of(state, other.ref) != side_of(state, stack) || battle_id_of(state, other.ref) == battle_id) {
			continue;
		}
		const int64_t distance = battle_rules::_stack_hex_distance(state, stack, other.ref);
		if (gd::is_empty(state, nearest) || distance < nearest_distance) {
			nearest = other.ref;
			nearest_distance = distance;
		}
	}
	remove_stack_effect(state, stack, curse);
	if (gd::is_empty(state, nearest)) {
		return;
	}
	const DictRef jumped = gd::deep_duplicate_dict(state, curse);
	state.erase(jumped, str(key::skip_current_turn));
	battle_rules::_apply_stack_effect(state, battle, battle_id_of(state, nearest), dict_value(jumped));
	battle_rules::_record_event(state, battle, gd::format(state, key::curse_jumps_text, { str(battle_rules::_stack_label(state, nearest)) }));
}

bool heal_blocked(State &state, DictRef stack, DictRef battle) {
	return !gd::is_empty(state, stack_mechanic_effect(state, stack, battle, key::heal_block));
}

// --- Spells cast on a stack -------------------------------------------------

DictRef reflected_spell_target(State &state, DictRef battle, DictRef target, Atom spell_id) {
	if (gd::is_empty(state, target) || gd::is_empty(state, stack_mechanic_effect(state, target, battle, key::reflect_spell))) {
		return state.new_dict();
	}
	const ArrayRef candidates = state.new_array();
	for (const Value &other : gd::items(state, array_value(alive_stacks(state, battle)))) {
		if (side_of(state, other.ref) != side_of(state, target)) {
			state.append(candidates, other);
		}
	}
	const int64_t count = state.array_size(candidates);
	if (count == 0) {
		return state.new_dict();
	}
	return state.at(candidates, stable_pick(state, battle, { str(battle_id_of(state, target)), str(spell_id), str(key::reflect_spell) }, count)).ref;
}

void spend_reflect_ward(State &state, DictRef battle, Atom battle_id) {
	const DictRef stack = battle_rules::_get_stack_by_id(state, battle, battle_id);
	const DictRef ward = stack_mechanic_effect(state, stack, battle, key::reflect_spell);
	if (!gd::is_empty(state, ward)) {
		remove_stack_effect(state, stack, ward);
	}
}

// --- Turns -------------------------------------------------------------------

void end_of_turn_mechanics(State &state, DictRef battle, Atom battle_id) {
	DictRef stack = battle_rules::_get_stack_by_id(state, battle, battle_id);
	if (gd::is_empty(state, stack) || _alive_count(state, stack) <= 0) {
		return;
	}
	// Backlash: the boosted stack pays a share of its health, never its last point.
	const int64_t backlash_pct = stack_mechanic_int(state, stack, battle, key::backlash_pct);
	if (backlash_pct > 0) {
		const int64_t health = gd::int_field(state, stack, key::total_health, 0);
		const int64_t loss = engine_min<int64_t>(gd::sub(health, 1), engine_max<int64_t>(1, compat::int_div(gd::mul(health, backlash_pct), 100)));
		if (loss > 0) {
			state.set(stack, str(key::total_health), int_value(gd::sub(health, loss)));
			battle_rules::_record_event(state, battle, gd::format(state, key::pays_health_backlash_text, { str(battle_rules::_stack_label(state, stack)), int_value(loss) }));
		}
	}
	// Tightening roots: one more defense lost for each turn it stays rooted.
	const DictRef rooted = stack_status_effect(state, stack, battle, key::status_rooted);
	const int64_t tightening = gd::int_field(state, effect_mechanic(state, rooted), key::tightening, 0);
	if (tightening > 0) {
		Value modifiers;
		if (state.lookup(rooted, str(key::modifiers), modifiers) && gd::is_dict(modifiers)) {
			state.set(modifiers.ref, str(key::defense), int_value(gd::sub(gd::int_field(state, modifiers.ref, key::defense, 0), tightening)));
		}
	}
	// A curse hurts at the end of each of its turns.
	const DictRef curse = stack_status_effect(state, stack, battle, key::status_cursed);
	const int64_t curse_damage = gd::int_field(state, effect_mechanic(state, curse), key::curse_damage, 0);
	if (curse_damage > 0) {
		const Atom label = battle_rules::_stack_label(state, stack);
		battle_rules::_apply_damage_to_stack(state, battle, battle_id, curse_damage);
		battle_rules::_record_event(state, battle, gd::format(state, key::curse_deals_text, { str(label), int_value(curse_damage) }));
	}
}

bool start_of_turn_mechanics(State &state, DictRef battle, Atom battle_id) {
	const DictRef stack = battle_rules::_get_stack_by_id(state, battle, battle_id);
	if (gd::is_empty(state, stack) || _alive_count(state, stack) <= 0) {
		return false;
	}
	const int64_t regrowth = stack_mechanic_int(state, stack, battle, key::regrowth);
	if (regrowth > 0) {
		const int64_t restored = battle_rules::_restore_stack_health(state, battle, battle_id, regrowth);
		if (restored > 0) {
			battle_rules::_record_event(state, battle, gd::format(state, key::regrows_health_text, { str(battle_rules::_stack_label(state, stack)), int_value(restored) }));
		}
	}
	return !gd::is_empty(state, stack_status_effect(state, stack, battle, key::status_asleep));
}

void begin_active_turn(State &state, DictRef battle) {
	for (int64_t skipped = 0; skipped < MAX_SKIPPED_TURNS; ++skipped) {
		const Atom active_id = gd::string_field(state, battle, key::active_stack_id, key::empty);
		if (active_id == key::empty || !start_of_turn_mechanics(state, battle, active_id)) {
			return;
		}
		const DictRef sleeper = battle_rules::_get_stack_by_id(state, battle, active_id);
		battle_rules::_record_event(state, battle, gd::format(state, key::sleeps_through_turn_text, { str(battle_rules::_stack_label(state, sleeper)) }));
		battle_rules::_advance_turn_without_start(state, battle);
	}
}

// --- Blows -------------------------------------------------------------------

int64_t stationary_attack_bonus(State &state, DictRef battle, DictRef attacker, bool is_retaliation) {
	if (is_retaliation) {
		return 0;
	}
	const int64_t bonus = stack_mechanic_int(state, attacker, battle, key::stationary_attack);
	if (bonus <= 0 || gd::string_field(state, battle, key::strike_moved_battle_id, key::empty) == battle_id_of(state, attacker)) {
		return 0;
	}
	return bonus;
}

double blow_damage_multiplier(State &state, DictRef battle, DictRef attacker, DictRef defender, bool is_ranged) {
	double multiplier = 1.0;
	const DictRef mark = stack_status_effect(state, defender, battle, key::status_marked);
	if (!gd::is_empty(state, mark) && side_of(state, attacker) != side_of(state, defender)) {
		const int64_t pct = gd::int_field(state, effect_mechanic(state, mark), key::damage_taken_pct, MARKED_DAMAGE_PCT);
		multiplier *= 1.0 + static_cast<double>(pct) / 100.0;
	}
	if (!is_ranged && !gd::is_empty(state, stack_status_effect(state, attacker, battle, key::status_blinded))) {
		multiplier *= BLINDED_BLOW_SHARE;
	}
	return multiplier;
}

ArrayRef after_blow_mechanics(State &state, DictRef battle, Atom attacker_id, Atom defender_id, bool is_ranged, int64_t dealt) {
	const ArrayRef messages = state.new_array();
	const DictRef attacker = battle_rules::_get_stack_by_id(state, battle, attacker_id);
	const DictRef defender = battle_rules::_get_stack_by_id(state, battle, defender_id);
	if (gd::is_empty(state, attacker) || gd::is_empty(state, defender)) {
		return messages;
	}
	if (!is_ranged && _alive_count(state, attacker) > 0) {
		const int64_t thorns = stack_mechanic_int(state, defender, battle, key::thorns);
		if (thorns > 0) {
			const Atom label = battle_rules::_stack_label(state, attacker);
			battle_rules::_apply_damage_to_stack(state, battle, attacker_id, thorns);
			state.append(messages, str(gd::format(state, key::takes_thorns_damage_text, { str(label), int_value(thorns), str(battle_rules::_stack_label(state, defender)) })));
		}
	}
	const DictRef striker = battle_rules::_get_stack_by_id(state, battle, attacker_id);
	if (dealt <= 0 || _alive_count(state, striker) <= 0) {
		return messages;
	}
	const int64_t lifesteal_pct = stack_mechanic_int(state, striker, battle, key::lifesteal_pct);
	if (lifesteal_pct > 0) {
		const int64_t healed = battle_rules::_restore_stack_health(state, battle, attacker_id, compat::int_div(gd::mul(dealt, lifesteal_pct), 100));
		if (healed > 0) {
			state.append(messages, str(gd::format(state, key::drinks_health_text, { str(battle_rules::_stack_label(state, striker)), int_value(healed) })));
		}
	}
	const DictRef ramp = stack_mechanic_effect(state, striker, battle, key::momentum_per_blow);
	if (!gd::is_empty(state, ramp)) {
		const DictRef mechanic = effect_mechanic(state, ramp);
		const int64_t gained = gd::int_field(state, mechanic, key::momentum_gained, 0);
		const int64_t cap = gd::int_field(state, mechanic, key::momentum_cap, 0);
		const int64_t step = engine_min<int64_t>(gd::int_field(state, mechanic, key::momentum_per_blow, 1), gd::sub(cap, gained));
		if (step > 0) {
			state.set(mechanic, str(key::momentum_gained), int_value(gd::add(gained, step)));
			battle_rules::_adjust_stack_momentum(state, battle, attacker_id, step);
		}
	}
	return messages;
}

DictRef confused_blow_target(State &state, DictRef battle, DictRef attacker, DictRef target, bool is_ranged) {
	if (gd::is_empty(state, attacker) || gd::is_empty(state, target) || gd::is_empty(state, stack_status_effect(state, attacker, battle, key::status_confused))) {
		return target;
	}
	// A blow lands on a stack next to the confused one; a shot on the target or
	// a stack next to it. Either side's stacks can be hit, never the attacker.
	const DictRef centre = is_ranged ? target : attacker;
	const ArrayRef candidates = state.new_array();
	if (is_ranged) {
		state.append(candidates, dict_value(target));
	}
	for (const Value &other : gd::items(state, array_value(alive_stacks(state, battle)))) {
		const Atom other_id = battle_id_of(state, other.ref);
		if (other_id == battle_id_of(state, attacker) || other_id == battle_id_of(state, centre)) {
			continue;
		}
		if (battle_rules::_stack_hex_distance(state, centre, other.ref) == 1) {
			state.append(candidates, other);
		}
	}
	if (!is_ranged && battle_rules::_stack_hex_distance(state, attacker, target) == 1) {
		state.append(candidates, dict_value(target));
	}
	if (state.array_size(candidates) == 0) {
		return target;
	}
	const int64_t pick = stable_pick(state, battle, { str(key::status_confused), str(battle_id_of(state, attacker)), str(battle_id_of(state, target)) }, state.array_size(candidates));
	return gd::as_dict(state.at(candidates, pick));
}

bool shot_refused_by_spells(State &state, DictRef battle, DictRef shooter, DictRef target) {
	if (!gd::is_empty(state, stack_status_effect(state, shooter, battle, key::status_blinded))) {
		return true;
	}
	return !gd::is_empty(state, stack_mechanic_effect(state, target, battle, key::shot_shield));
}

bool move_refused_by_fear(State &state, DictRef battle, DictRef stack, DictRef cell) {
	if (gd::is_empty(state, stack_status_effect(state, stack, battle, key::status_afraid))) {
		return false;
	}
	// It will not move toward the other side's stacks: no hex nearer to the
	// nearest of them than it stands now.
	int64_t now = -1;
	int64_t after = -1;
	for (const Value &other : gd::items(state, array_value(alive_stacks(state, battle)))) {
		if (side_of(state, other.ref) == side_of(state, stack)) {
			continue;
		}
		const int64_t from_here = battle_rules::_stack_hex_distance(state, stack, other.ref);
		const int64_t from_there = battle_footprint::distance(state, stack, other.ref, dict_value(cell));
		now = now < 0 ? from_here : engine_min<int64_t>(now, from_here);
		after = after < 0 ? from_there : engine_min<int64_t>(after, from_there);
	}
	return now >= 0 && after < now;
}

// --- Heat and turn order -----------------------------------------------------

Atom add_heat(State &state, DictRef battle, Atom battle_id, int64_t heat, int64_t burst_damage) {
	const DictRef stack = battle_rules::_get_stack_by_id(state, battle, battle_id);
	if (heat <= 0 || gd::is_empty(state, stack) || _alive_count(state, stack) <= 0) {
		return key::empty;
	}
	const Atom label = battle_rules::_stack_label(state, stack);
	const int64_t total = gd::add(gd::int_field(state, stack, key::spell_heat, 0), heat);
	if (total < HEAT_TO_BURST) {
		state.set(stack, str(key::spell_heat), int_value(total));
		return gd::format(state, key::has_heat_suffix_text, { str(label), int_value(total) });
	}
	// The third Heat bursts: damage, and the Heat clears.
	state.set(stack, str(key::spell_heat), int_value(0));
	battle_rules::_apply_damage_to_stack(state, battle, battle_id, burst_damage);
	return gd::format(state, key::heat_bursts_suffix_text, { str(label), int_value(burst_damage) });
}

void act_next(State &state, DictRef battle, Atom battle_id) {
	const DictRef stack = battle_rules::_get_stack_by_id(state, battle, battle_id);
	if (gd::is_empty(state, stack)) {
		return;
	}
	Value order;
	const int64_t position = state.lookup(battle, str(key::turn_order), order) && gd::is_array(order) ? gd::array_find(state, order.ref, str(battle_id)) : -1;
	const int64_t round = gd::int_field(state, battle, key::round, 1);
	// Still to act this round: it acts next. Acting now or done: first next round.
	const bool this_round = position > gd::int_field(state, battle, key::turn_index, 0);
	state.set(stack, str(key::acts_next_round), int_value(this_round ? round : gd::add(round, 1)));
	battle_rules::_resort_remaining_turn_order(state, battle);
}

ArrayRef acts_next_first(State &state, DictRef battle, ArrayRef battle_ids) {
	const int64_t round = gd::int_field(state, battle, key::round, 1);
	const ArrayRef first = state.new_array();
	const ArrayRef rest = state.new_array();
	for (const Value &battle_id : gd::items(state, array_value(battle_ids))) {
		const DictRef stack = battle_rules::_get_stack_by_id(state, battle, gd::to_string(battle_id));
		const bool called = !gd::is_empty(state, stack) && gd::int_field(state, stack, key::acts_next_round, 0) == round;
		state.append(called ? first : rest, battle_id);
	}
	if (state.array_size(first) == 0) {
		return battle_ids;
	}
	return gd::concat(state, first, rest);
}

} // namespace aurelion::rules::port::spell_rules
