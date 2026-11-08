// Layer 8: the stacks a cast reaches beyond its target (docs/magic-system-spells.md): a mastery's shape (the
// stacks of the target's side next to it, or all of them), Morning Light's every stack, Cinder Spray's splash,
// Dawn Lance's beam, Spark Swarm's sparks and Leech's drain. Each reached stack gets a sub-resolution of the
// cast's own kind in the result's extra_resolutions, which battle_rules::_apply_spell_resolution applies after
// the target's own.

#include "aurelion_rules/port/spell_rules.hpp"

#include "aurelion_rules/compat/godot_math.hpp"
#include "aurelion_rules/port/battle_rules.hpp"
#include "aurelion_rules/port/hero_progression_rules.hpp"

#include <string>
#include <vector>

namespace aurelion::rules::port::hero_progression_rules {
// Defined in enemy_states.cpp, declared where it is used.
int64_t specialty_rank(State &state, DictRef hero_state, Atom specialty_id);
} // namespace aurelion::rules::port::hero_progression_rules

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

DictRef effect_of(State &state, DictRef spell) {
	Value effect;
	return state.lookup(spell, str(key::effect), effect) && gd::is_dict(effect) ? effect.ref : state.new_dict();
}

// The living stacks of a side (every side's with an empty one), in the battle's order.
std::vector<DictRef> living_stacks(State &state, DictRef battle, Atom side) {
	std::vector<DictRef> stacks;
	for (const Value &stack : gd::field_items(state, battle, str(key::stacks))) {
		if (gd::is_dict(stack) && battle_rules::_alive_count(state, stack.ref) > 0 && (side == key::empty || side_of(state, stack.ref) == side)) {
			stacks.push_back(stack.ref);
		}
	}
	return stacks;
}

// The spell's damage on a stack at a power the caller names, after that stack's resistance (the numbers of
// battle_spell_damage_projection).
int64_t damage_at(State &state, DictRef hero, DictRef battle, DictRef stack, DictRef spell, int64_t power) {
	const int64_t raw = _battle_spell_damage_at(state, hero, spell, stack, power);
	const int64_t resistance = spell_damage_resistance_pct(state, battle, stack, spell);
	const double scaled = static_cast<double>(raw) * static_cast<double>(gd::sub(100, resistance)) / 100.0;
	return spare_last_creature(state, spell, stack, engine_max<int64_t>(1, compat::float_to_int(compat::godot_round(scaled))));
}

DictRef sub_resolution(State &state, Atom type, DictRef stack, Atom message) {
	const DictRef sub = state.new_dict();
	state.set(sub, str(key::resolution_type), str(type));
	state.set(sub, str(key::target_battle_id), str(battle_id_of(state, stack)));
	state.set(sub, str(key::message), str(message));
	return sub;
}

DictRef damage_hit(State &state, DictRef stack, int64_t damage) {
	const DictRef sub = sub_resolution(state, key::damage, stack, gd::format(state, key::reach_takes_damage_text, { str(battle_rules::_stack_label(state, stack)), int_value(damage) }));
	state.set(sub, str(key::damage), int_value(damage));
	return sub;
}

// The stacks a shape reaches beyond the target: those of its side next to it, or all of its side.
std::vector<DictRef> shape_stacks(State &state, DictRef battle, DictRef target, Atom shape) {
	std::vector<DictRef> reached;
	if (shape == key::empty) {
		return reached;
	}
	for (const DictRef stack : living_stacks(state, battle, side_of(state, target))) {
		if (battle_id_of(state, stack) == battle_id_of(state, target)) {
			continue;
		}
		if (shape == key::all || battle_rules::_stack_hex_distance(state, stack, target) == 1) {
			reached.push_back(stack);
		}
	}
	return reached;
}

// The wider of two shapes: every stack over the stacks next to the target.
Atom wider_shape(Atom a, Atom b) {
	if (a == key::all || b == key::all) {
		return key::all;
	}
	return a != key::empty ? a : b;
}

// The widest shape the hero's mastery of the spell's school opens, from the spell's mastery_reach entries
// ({rank, reach}: its Mastery column).
Atom mastery_shape(State &state, DictRef hero, DictRef spell) {
	const int64_t rank = spell_mastery_rank(state, hero, spell);
	Atom shape = key::empty;
	for (const Value &entry : gd::field_items(state, spell, str(key::mastery_reach))) {
		if (!gd::is_dict(entry)) {
			continue;
		}
		const int64_t needed = gd::int_field(state, entry.ref, key::rank, 0);
		if (needed > 0 && rank >= needed) {
			shape = wider_shape(shape, gd::string_field(state, entry.ref, key::reach, key::empty));
		}
	}
	return shape;
}

// The stack of the caster's side that drinks a drain: the one picked, or the most wounded.
DictRef drinking_stack(State &state, DictRef battle, Atom caster_side, const Value &pick) {
	if (gd::is_dict(pick)) {
		const DictRef picked = battle_rules::_get_stack_by_id(state, battle, gd::string_field(state, pick.ref, key::battle_id, key::empty));
		if (!gd::is_empty(state, picked) && side_of(state, picked) == caster_side && battle_rules::_alive_count(state, picked) > 0) {
			return picked;
		}
	}
	DictRef best = state.new_dict();
	int64_t best_missing = 0;
	for (const DictRef stack : living_stacks(state, battle, caster_side)) {
		const int64_t missing = gd::sub(gd::mul(battle_rules::_alive_count(state, stack), gd::int_field(state, stack, key::unit_hp, 1)), gd::int_field(state, stack, key::total_health, 0));
		if (missing > best_missing) {
			best = stack;
			best_missing = missing;
		}
	}
	return best;
}

void add_damage_reach(State &state, DictRef hero, DictRef battle, DictRef target, DictRef spell, DictRef effect, DictRef result, const Value &second_pick, ArrayRef extras) {
	const Atom spell_id = gd::string_field(state, spell, key::id, key::empty);
	const int64_t power_against = spell_power_against(state, hero, battle, target, spell);
	int64_t main_damage = gd::int_field(state, result, key::damage, 0);
	// Spark Swarm: the first spark strikes the target, the others random stacks of its side.
	int64_t sparks = gd::int_field(state, effect, key::random_hits, 0);
	const int64_t spark_divisor = gd::int_field(state, effect, key::random_hits_power_divisor, 0);
	if (sparks > 0 && spark_divisor > 0) {
		sparks = gd::add(sparks, compat::int_div(spell_power(state, hero, spell), spark_divisor));
	}
	if (sparks > 1) {
		const std::vector<DictRef> struck = living_stacks(state, battle, side_of(state, target));
		std::vector<int64_t> counts(struck.size(), 0);
		int64_t on_target = 1;
		for (int64_t spark = 1; spark < sparks && !struck.empty(); ++spark) {
			const int64_t pick = stable_draw(state, battle, { str(spell_id), str(key::random_hits), int_value(spark) }, static_cast<int64_t>(struck.size()));
			if (battle_id_of(state, struck[static_cast<size_t>(pick)]) == battle_id_of(state, target)) {
				on_target += 1;
			} else {
				counts[static_cast<size_t>(pick)] += 1;
			}
		}
		main_damage = gd::mul(main_damage, on_target);
		state.set(result, str(key::damage), int_value(main_damage));
		state.set(result, str(key::final_damage), int_value(main_damage));
		state.set(result, str(key::message), str(gd::format(state, key::casts_on_for_damage_format, {
			str(gd::string_field(state, hero, key::name, key::the_hero_text)),
			str(gd::string_field(state, spell, key::name, spell_id)),
			str(gd::string_field(state, target, key::name, key::the_enemy_text)),
			int_value(main_damage),
		})));
		for (size_t index = 0; index < struck.size(); ++index) {
			if (counts[index] > 0) {
				const int64_t per_spark = damage_at(state, hero, battle, struck[index], spell, spell_power_against(state, hero, battle, struck[index], spell));
				state.append(extras, dict_value(damage_hit(state, struck[index], gd::mul(per_spark, counts[index]))));
			}
		}
	}
	// Cinder Spray: every stack next to the target takes as much, the caster's own included.
	if (gd::string_field(state, effect, key::splash, key::empty) == key::adjacent) {
		for (const DictRef stack : living_stacks(state, battle, key::empty)) {
			if (battle_id_of(state, stack) != battle_id_of(state, target) && battle_rules::_stack_hex_distance(state, stack, target) == 1) {
				state.append(extras, dict_value(damage_hit(state, stack, damage_at(state, hero, battle, stack, spell, power_against))));
			}
		}
	}
	// Kiln Burst: every other stack of the target's side within the blast's radius takes the blast's own numbers.
	const int64_t blast_radius = gd::int_field(state, effect, key::blast_radius, 0);
	if (blast_radius > 0) {
		const DictRef blast = gd::deep_duplicate_dict(state, spell);
		const DictRef blast_effect = effect_of(state, blast);
		state.set(blast_effect, str(key::base_damage), int_value(gd::int_field(state, effect, key::blast_base_damage, 0)));
		state.set(blast_effect, str(key::power_scale), int_value(gd::int_field(state, effect, key::blast_power_scale, 0)));
		for (const DictRef stack : living_stacks(state, battle, side_of(state, target))) {
			if (battle_id_of(state, stack) != battle_id_of(state, target) && battle_rules::_stack_hex_distance(state, stack, target) <= blast_radius) {
				state.append(extras, dict_value(damage_hit(state, stack, damage_at(state, hero, battle, stack, blast, spell_power_against(state, hero, battle, stack, spell)))));
			}
		}
	}
	// Molten Deluge, Fever Wind and Black Tide: every other stack of the target's side takes it too, at its own
	// numbers; Molten Deluge's Heat lands on each.
	if (gd::string_field(state, effect, key::reach, key::empty) == key::all) {
		const int64_t heat = gd::int_field(state, effect, key::heat, 0);
		for (const DictRef stack : living_stacks(state, battle, side_of(state, target))) {
			if (battle_id_of(state, stack) == battle_id_of(state, target)) {
				continue;
			}
			const int64_t stack_power = spell_power_against(state, hero, battle, stack, spell);
			const int64_t damage = damage_at(state, hero, battle, stack, spell, stack_power);
			if (damage <= 0) {
				continue;
			}
			const DictRef hit = damage_hit(state, stack, damage);
			if (heat > 0) {
				state.set(hit, str(key::heat), int_value(heat));
				state.set(hit, str(key::heat_burst_damage), int_value(heat_burst_damage(stack_power)));
				if (gd::bool_field(state, effect, key::heat_short_of_burst, false)) {
					state.set(hit, str(key::heat_short_of_burst), bool_value(true));
				}
			}
			state.append(extras, dict_value(hit));
		}
	}
	// Dawn Lance: the beam runs along the target's row from the caster's edge, through every stack of its side.
	if (gd::bool_field(state, effect, key::line, false)) {
		const int64_t row = gd::int_field(state, battle_rules::_stack_hex(state, target), key::r, -1);
		for (const DictRef stack : living_stacks(state, battle, side_of(state, target))) {
			if (battle_id_of(state, stack) != battle_id_of(state, target) && gd::int_field(state, battle_rules::_stack_hex(state, stack), key::r, -2) == row) {
				state.append(extras, dict_value(damage_hit(state, stack, damage_at(state, hero, battle, stack, spell, spell_power_against(state, hero, battle, stack, spell)))));
			}
		}
	}
	// Cinderfall: the target's neighbours on its side get its status too, each on its own draw.
	const Atom status_splash = gd::string_field(state, effect, key::status_splash, key::empty);
	if (status_splash != key::empty) {
		for (const DictRef stack : shape_stacks(state, battle, target, status_splash)) {
			const int64_t stack_power = spell_power_against(state, hero, battle, stack, spell);
			const DictRef payload = _status_effect_from_spell_effect_at(state, spell, battle, hero, stack_power);
			const Atom status_id = gd::string_field(state, payload, key::effect_id, key::empty);
			const int64_t resistance = control_resistance_pct(state, battle, stack, spell);
			const bool resists = target_is_immune_to_status(state, stack, battle, status_id)
					|| (resistance > 0 && stable_draw(state, battle, { str(spell_id), str(battle_id_of(state, stack)), str(key::status_splash) }, 100) < resistance);
			const DictRef sub = sub_resolution(state, key::effect, stack, gd::format(state, resists ? key::reach_resists_text : key::reach_also_text, { str(battle_rules::_stack_label(state, stack)) }));
			state.set(sub, str(key::effect), dict_value(resists ? state.new_dict() : payload));
			state.append(extras, dict_value(sub));
		}
	}
	// Prism Bolt: it jumps on to the nearest enemy stack not yet struck, weaker each jump; Glass Aegis turns it.
	std::vector<int64_t> jumps;
	for (const Value &pct : gd::field_items(state, effect, str(key::chain))) {
		jumps.push_back(gd::to_int(state, pct));
	}
	if (!jumps.empty()) {
		const int64_t rank = spell_mastery_rank(state, hero, spell);
		for (const Value &entry : gd::field_items(state, effect, str(key::mastery_chain))) {
			if (gd::is_dict(entry) && rank >= gd::int_field(state, entry.ref, key::rank, 99)) {
				jumps.push_back(gd::int_field(state, entry.ref, key::pct, 0));
			}
		}
		std::vector<Atom> struck = { battle_id_of(state, target) };
		DictRef from = target;
		for (const int64_t pct : jumps) {
			DictRef next = state.new_dict();
			int64_t next_distance = 0;
			for (const DictRef stack : living_stacks(state, battle, side_of(state, target))) {
				const Atom id = battle_id_of(state, stack);
				bool seen = false;
				for (const Atom done : struck) {
					seen = seen || done == id;
				}
				if (seen || spell_shielded(state, battle, stack)) {
					continue;
				}
				const int64_t distance = battle_rules::_stack_hex_distance(state, from, stack);
				if (gd::is_empty(state, next) || distance < next_distance) {
					next = stack;
					next_distance = distance;
				}
			}
			if (gd::is_empty(state, next)) {
				break;
			}
			const int64_t full = damage_at(state, hero, battle, next, spell, spell_power_against(state, hero, battle, next, spell));
			state.append(extras, dict_value(damage_hit(state, next, engine_max<int64_t>(1, compat::int_div(gd::mul(full, pct), 100)))));
			struck.push_back(battle_id_of(state, next));
			from = next;
		}
	}
	// Flashpoint, from its mastery rank: every other stack of the target's side with Heat bursts it too.
	if (gd::bool_field(state, effect, key::heat_burst, false) && mastery_shape(state, hero, spell) == key::all) {
		for (const DictRef stack : living_stacks(state, battle, side_of(state, target))) {
			if (battle_id_of(state, stack) == battle_id_of(state, target) || gd::int_field(state, stack, key::spell_heat, 0) <= 0) {
				continue;
			}
			const DictRef hit = damage_hit(state, stack, damage_at(state, hero, battle, stack, spell, spell_power_against(state, hero, battle, stack, spell)));
			state.set(hit, str(key::heat_burst), bool_value(true));
			state.append(extras, dict_value(hit));
		}
	}
	// Leech: a stack of the caster's side heals a share of what the target loses.
	const int64_t drain_pct = gd::int_field(state, effect, key::drain_pct, 0);
	if (drain_pct > 0) {
		const Atom caster_side = battle_rules::_opposing_side(side_of(state, target));
		const DictRef drinker = drinking_stack(state, battle, caster_side, second_pick);
		const int64_t taken = engine_min<int64_t>(main_damage, gd::int_field(state, target, key::total_health, 0));
		const int64_t amount = compat::int_div(gd::mul(taken, drain_pct), 100);
		if (!gd::is_empty(state, drinker) && amount > 0) {
			const DictRef sub = sub_resolution(state, key::recover_effect, drinker, key::empty);
			state.set(sub, str(key::recovery_amount), int_value(amount));
			state.append(extras, dict_value(sub));
		}
	}
}

void add_control_reach(State &state, DictRef hero, DictRef battle, DictRef target, DictRef spell, DictRef effect, ArrayRef extras) {
	const Atom spell_id = gd::string_field(state, spell, key::id, key::empty);
	// The spell's own reach (Spore Cloud's neighbours), widened by mastery.
	const Atom shape = wider_shape(gd::string_field(state, effect, key::reach, key::empty), mastery_shape(state, hero, spell));
	for (const DictRef stack : shape_stacks(state, battle, target, shape)) {
		const int64_t power_against = spell_power_against(state, hero, battle, stack, spell);
		// Grasp of the Deep stuns a stack that is already Rooted.
		const DictRef payload = grasp_status(state, spell, battle, hero, stack, _status_effect_from_spell_effect_at(state, spell, battle, hero, power_against), power_against);
		const Atom status_id = gd::string_field(state, payload, key::effect_id, key::empty);
		const Atom label = battle_rules::_stack_label(state, stack);
		const int64_t resistance = control_resistance_pct(state, battle, stack, spell);
		// A reached stack resists on its own stable draw; the battle's stream serves the target alone.
		const bool resists = target_is_immune_to_status(state, stack, battle, status_id)
				|| (resistance > 0 && stable_draw(state, battle, { str(spell_id), str(battle_id_of(state, stack)), str(key::resisted) }, 100) < resistance);
		const DictRef sub = sub_resolution(state, key::effect, stack, gd::format(state, resists ? key::reach_resists_text : key::reach_also_text, { str(label) }));
		state.set(sub, str(key::effect), dict_value(resists ? state.new_dict() : payload));
		Value follow;
		if (!resists && state.lookup(effect, str(key::follow_status_effect), follow) && gd::is_dict(follow)) {
			state.set(sub, str(key::follow_effect), dict_value(_status_payload(state, spell, follow, battle, hero, power_against, gd::int_field(state, payload, key::turns_left, 1))));
		}
		state.append(extras, dict_value(sub));
	}
}

void add_ally_reach(State &state, DictRef hero, DictRef battle, DictRef target, DictRef spell, DictRef effect, Atom effect_type, ArrayRef extras) {
	// The spell's own reach (Morning Light's every stack, Bloomburst's and Bark Ring's neighbours), widened by mastery.
	const Atom shape = wider_shape(gd::string_field(state, effect, key::reach, key::empty), mastery_shape(state, hero, spell));
	// Bloomburst's neighbours heal a share of it.
	const int64_t reach_pct = gd::int_field(state, effect, key::reach_pct, 100);
	for (const DictRef stack : shape_stacks(state, battle, target, shape)) {
		// Censure: no spell of its own hero's helps the stack.
		if (censured(state, stack)) {
			continue;
		}
		if (effect_type == key::recover_ally) {
			const DictRef sub = sub_resolution(state, key::recover_effect, stack, key::empty);
			state.set(sub, str(key::recovery_amount), int_value(compat::int_div(gd::mul(_battle_spell_recovery_amount(state, hero, spell), reach_pct), 100)));
			if (gd::bool_field(state, effect, key::raise, false)) {
				state.set(sub, str(key::raise), bool_value(true));
			}
			const bool lasting = !gd::is_empty(state, battle_spell_modifiers(state, spell)) || state.has(effect, str(key::mechanic));
			state.set(sub, str(key::effect), dict_value(lasting ? _effect_payload(state, spell, effect, battle, hero) : state.new_dict()));
			const int64_t block_turns = gd::int_field(state, effect, key::heal_block_turns, 0);
			if (block_turns > 0) {
				state.set(sub, str(key::heal_block_effect), dict_value(heal_block_payload(state, spell, battle, block_turns)));
			}
			const int64_t statuses = gd::int_field(state, effect, key::cleanse_statuses, 0);
			if (statuses > 0) {
				state.set(sub, str(key::cleanse_status_ids), array_value(newest_status_ids(state, stack, battle, statuses)));
			}
			state.append(extras, dict_value(sub));
			continue;
		}
		const DictRef sub = sub_resolution(state, key::effect, stack, gd::format(state, key::reach_also_text, { str(battle_rules::_stack_label(state, stack)) }));
		state.set(sub, str(key::effect), dict_value(_effect_payload_for(state, spell, effect, battle, hero, stack)));
		state.append(extras, dict_value(sub));
	}
}

// Long Night: the smallest stack of the target's side (fewest creatures, then least health) also runs, on its own draw.
void add_flee_smallest(State &state, DictRef hero, DictRef battle, DictRef target, DictRef spell, DictRef effect, ArrayRef extras) {
	Value flee;
	if (!state.lookup(effect, str(key::flee_smallest_status), flee) || !gd::is_dict(flee)) {
		return;
	}
	DictRef smallest = state.new_dict();
	for (const DictRef stack : living_stacks(state, battle, side_of(state, target))) {
		if (is_decoy(state, stack)) {
			continue;
		}
		if (gd::is_empty(state, smallest)) {
			smallest = stack;
			continue;
		}
		const int64_t count = battle_rules::_alive_count(state, stack);
		const int64_t best = battle_rules::_alive_count(state, smallest);
		if (count < best || (count == best && gd::int_field(state, stack, key::total_health, 0) < gd::int_field(state, smallest, key::total_health, 0))) {
			smallest = stack;
		}
	}
	if (gd::is_empty(state, smallest)) {
		return;
	}
	const Atom spell_id = gd::string_field(state, spell, key::id, key::empty);
	const DictRef payload = _status_payload(state, spell, flee, battle, hero, spell_power_against(state, hero, battle, smallest, spell), 0);
	const Atom status_id = gd::string_field(state, payload, key::effect_id, key::empty);
	const int64_t resistance = control_resistance_pct(state, battle, smallest, spell);
	const bool resists = target_is_immune_to_status(state, smallest, battle, status_id)
			|| (resistance > 0 && stable_draw(state, battle, { str(spell_id), str(battle_id_of(state, smallest)), str(key::flee) }, 100) < resistance);
	const DictRef sub = sub_resolution(state, key::effect, smallest, gd::format(state, resists ? key::reach_resists_text : key::flees_smallest_text, { str(battle_rules::_stack_label(state, smallest)) }));
	state.set(sub, str(key::effect), dict_value(resists ? state.new_dict() : payload));
	state.append(extras, dict_value(sub));
}

} // namespace

ArrayRef snare_resolutions(State &state, DictRef hero, DictRef battle, DictRef spell, ArrayRef cells, Atom caster_side) {
	const ArrayRef extras = state.new_array();
	const Atom spell_id = gd::string_field(state, spell, key::id, key::empty);
	for (const Value &caught : gd::items(state, array_value(snared_stacks(state, battle, cells, caster_side)))) {
		if (!gd::is_dict(caught)) {
			continue;
		}
		const DictRef stack = caught.ref;
		const int64_t power_against = spell_power_against(state, hero, battle, stack, spell);
		const DictRef payload = _status_effect_from_spell_effect_at(state, spell, battle, hero, power_against);
		const Atom status_id = gd::string_field(state, payload, key::effect_id, key::empty);
		const int64_t resistance = control_resistance_pct(state, battle, stack, spell);
		const bool resists = target_is_immune_to_status(state, stack, battle, status_id)
				|| (resistance > 0 && stable_draw(state, battle, { str(spell_id), str(battle_id_of(state, stack)), str(key::resisted) }, 100) < resistance);
		const DictRef sub = sub_resolution(state, key::effect, stack, gd::format(state, resists ? key::reach_resists_text : key::snare_catches_text, { str(battle_rules::_stack_label(state, stack)) }));
		state.set(sub, str(key::effect), dict_value(resists ? state.new_dict() : payload));
		state.append(extras, dict_value(sub));
	}
	return extras;
}

int64_t spell_mastery_rank(State &state, DictRef hero_state, DictRef spell) {
	const Atom school = gd::string_field(state, spell, key::school_id, key::empty);
	if (school == key::empty || gd::is_empty(state, hero_state)) {
		return 0;
	}
	return hero_progression_rules::specialty_rank(state, hero_state, state.intern("mastery_" + state.text(school)));
}

void add_reach_resolutions(State &state, DictRef hero, DictRef battle, DictRef target, DictRef spell, DictRef result, const Value &second_pick) {
	if (!gd::bool_field(state, result, key::ok, false) || gd::is_empty(state, target)) {
		return;
	}
	const DictRef effect = effect_of(state, spell);
	const Atom effect_type = gd::string_field(state, effect, key::type, key::empty);
	const ArrayRef extras = state.new_array();
	if (effect_type == key::damage_enemy) {
		add_damage_reach(state, hero, battle, target, spell, effect, result, second_pick, extras);
	} else if (effect_type == key::control_enemy) {
		add_control_reach(state, hero, battle, target, spell, effect, extras);
		add_flee_smallest(state, hero, battle, target, spell, effect, extras);
	} else if (effect_type == key::recover_ally || effect_type == key::ally_effect || effect_type == key::attack_buff
			|| effect_type == key::defense_buff || effect_type == key::initiative_buff) {
		add_ally_reach(state, hero, battle, target, spell, effect, effect_type, extras);
	}
	// Glass Dome: no spell's damage reaches a stack under one.
	for (int64_t index = state.array_size(extras) - 1; index >= 0; --index) {
		const Value extra = state.at(extras, index);
		if (gd::is_dict(extra) && gd::string_field(state, extra.ref, key::resolution_type, key::empty) == key::damage
				&& in_dome(state, battle, battle_rules::_get_stack_by_id(state, battle, gd::string_field(state, extra.ref, key::target_battle_id, key::empty)))) {
			gd::remove_at(state, extras, index);
		}
	}
	if (state.array_size(extras) > 0) {
		state.set(result, str(key::extra_resolutions), array_value(extras));
	}
}

} // namespace aurelion::rules::port::spell_rules
