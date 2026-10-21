// HeroCommandRules: the functions the AI targets reach (Phase 3), ported under
// their GDScript names.

#include "aurelion_rules/port/hero_command_rules_ai.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/artifact_rules.hpp"
#include "aurelion_rules/port/difficulty_rules_ai.hpp"
#include "aurelion_rules/port/hero_progression_rules.hpp"
#include "aurelion_rules/port/overworld_level_rules.hpp"
#include "aurelion_rules/port/overworld_level_rules_ai.hpp"
#include "aurelion_rules/port/session_view.hpp"

#include <string>

namespace aurelion::rules::port {

namespace {

using gd::array_value;
using gd::ArrayRef;
using gd::Atom;
using gd::bool_value;
using gd::dict_value;
using gd::DictRef;
using gd::int_value;
using gd::str;
using state::Kind;
using state::State;
using state::Value;
namespace key = state::key;
// HeroCommandRules.ARMY_SLOT_COUNT.
constexpr int64_t kArmySlotCount = 7;
// a.sort() of an Array of Strings: Godot compares Strings by code points, the
// byte order of their UTF-8. Anything else to compare is not ported.
void sort_strings(State &state, ArrayRef array, const char *where) {
	if (state.array_size(array) >= 2) {
		for (const Value &item : gd::items(state, array_value(array))) {
			if (!gd::is_string(item)) {
				throw state::NotPorted(std::string(where) + ": sort() of an Array that is not all Strings");
			}
		}
	}
	gd::sort_custom(state, array, [&state](const Value &a, const Value &b) { return gd::text(state, a) < gd::text(state, b); });
}

} // namespace

namespace hero_command_rules {

int64_t movement_max_for_hero(State &state, DictRef hero_state, const Value &movement_source) {
	const DictRef artifact_bonuses = artifact_rules::aggregate_bonuses(state, hero_state);
	const DictRef specialty_bonuses = hero_progression_rules::aggregate_bonuses(state, hero_state);
	int64_t difficulty_bonus = 0;
	// A session arrives as its view, a Dictionary.
	if (gd::is_dict(movement_source)) {
		difficulty_bonus = difficulty_rules::movement_bonus(state, movement_source);
	} else {
		if (movement_source.kind == Kind::Opaque) {
			throw state::NotPorted("HeroCommandRules.movement_max_for_hero: an object as the movement source");
		}
		const Atom difficulty_id = difficulty_rules::normalize_difficulty(state, str(gd::stringify(state, movement_source)));
		difficulty_bonus = gd::int_field(state, difficulty_rules::profile_for_difficulty(state, str(difficulty_id)), key::movement_bonus, 0);
	}
	int64_t total = gd::int_field(state, hero_state, key::base_movement, 10);
	total = gd::add(total, compat::engine_max<int64_t>(0, gd::sub(gd::int_field(state, hero_state, key::level, 1), 1)));
	total = gd::add(total, gd::int_field(state, artifact_bonuses, key::overworld_movement, 0));
	total = gd::add(total, gd::int_field(state, specialty_bonuses, key::overworld_movement, 0));
	total = gd::add(total, difficulty_bonus);
	total = gd::add(total, _week_bonus(state, hero_state, key::movement));
	total = gd::add(total, compat::engine_max<int64_t>(0, gd::int_field(state, hero_state, key::movement_carry, 0)));
	return compat::engine_max<int64_t>(1, total);
}

int64_t _week_bonus(State &state, DictRef hero_state, Atom bonus_key) {
	// hero_state.get("week_bonuses", {}): a missing entry reads as {}, so 0.
	Value bonuses;
	if (!state.lookup(hero_state, str(key::week_bonuses), bonuses)) {
		return 0;
	}
	return gd::is_dict(bonuses) ? gd::int_field(state, bonuses.ref, bonus_key, 0) : 0;
}

bool within_scout_radius(State &state, int64_t dx, int64_t dy, int64_t radius) {
	(void)state;
	return gd::add(gd::mul(dx, dx), gd::mul(dy, dy)) <= gd::mul(radius, gd::add(radius, 1));
}

DictRef army_addition_plan(State &state, const Value &stacks_value, DictRef additions) {
	ArrayRef stacks = gd::is_array(stacks_value) ? gd::deep_duplicate_array(state, stacks_value.ref) : state.new_array();
	int64_t occupied = _valid_stack_count(state, array_value(stacks));
	if (occupied <= kArmySlotCount) {
		stacks = _slotted_stacks(state, array_value(stacks));
	}
	const ArrayRef unit_ids = gd::keys(state, additions);
	sort_strings(state, unit_ids, "HeroCommandRules.army_addition_plan");
	for (const Value &unit_id_value : gd::items(state, array_value(unit_ids))) {
		const Atom unit_id = gd::stringify(state, unit_id_value);
		const int64_t amount = compat::engine_max<int64_t>(0, gd::to_int(state, state.get(additions, unit_id_value, int_value(0))));
		if (unit_id == key::empty || amount == 0) {
			continue;
		}
		int64_t matching = -1;
		const int64_t stack_count = state.array_size(stacks);
		for (int64_t index = 0; index < stack_count; ++index) {
			const Value stack = state.at(stacks, index);
			if (gd::is_dict(stack) && ai::string_or_empty(state, stack.ref, key::unit_id) == unit_id && gd::int_field(state, stack.ref, key::count, 0) > 0) {
				matching = index;
				break;
			}
		}
		if (matching >= 0) {
			const DictRef stack = gd::as_dict(state.at(stacks, matching));
			state.set(stack, str(key::count), int_value(gd::add(gd::int_field(state, stack, key::count, 0), amount)));
			continue;
		}
		if (occupied >= kArmySlotCount) {
			const DictRef refused = state.new_dict();
			state.set(refused, str(key::ok), bool_value(false));
			state.set(refused, str(key::reason), str(key::army_capacity));
			state.set(refused, str(key::message), str(key::all_seven_army_slots_are_occupied));
			return refused;
		}
		const DictRef claimed = state.new_dict();
		for (const Value &stack : gd::items(state, array_value(stacks))) {
			state.set(claimed, int_value(gd::to_int(state, ai::vget(state, stack, key::slot_index, int_value(-1)))), bool_value(true));
		}
		const DictRef added = state.new_dict();
		state.set(added, str(key::unit_id), str(unit_id));
		state.set(added, str(key::count), int_value(amount));
		state.set(added, str(key::slot_index), int_value(_first_open_army_slot(state, claimed)));
		state.append(stacks, dict_value(added));
		occupied += 1;
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(true));
	state.set(result, str(key::stacks), array_value(stacks));
	return result;
}

DictRef _normalize_position(State &state, const Value &value) {
	// OverworldLevelRules.position(value).
	if (gd::is_dict(value)) {
		return overworld_level_rules::position(state, value.ref);
	}
	const DictRef result = state.new_dict();
	if (gd::is_vector3i(value)) {
		// position({"x": value.x, "y": value.y, "level": value.z})
		state.set(result, str(key::x), int_value(value.vx()));
		state.set(result, str(key::y), int_value(value.vy()));
		if (value.vz() != 0) {
			state.set(result, str(key::level), int_value(value.vz()));
		}
		return result;
	}
	if (gd::is_vector2i(value)) {
		state.set(result, str(key::x), int_value(value.vx()));
		state.set(result, str(key::y), int_value(value.vy()));
		return result;
	}
	state.set(result, str(key::x), int_value(0));
	state.set(result, str(key::y), int_value(0));
	return result;
}

ArrayRef _slotted_stacks(State &state, const Value &value) {
	const ArrayRef stacks = state.new_array();
	const DictRef claimed = state.new_dict();
	if (gd::is_array(value)) {
		for (const Value &stack_value : gd::items(state, value)) {
			if (!gd::is_dict(stack_value)) {
				continue;
			}
			const DictRef stack = gd::deep_duplicate_dict(state, stack_value.ref);
			const Atom unit_id = ai::string_or_empty(state, stack, key::unit_id);
			const int64_t count = gd::int_field(state, stack, key::count, 0);
			if (unit_id == key::empty || count <= 0) {
				continue;
			}
			int64_t preferred_slot = gd::int_field(state, stack, key::slot_index, -1);
			if (preferred_slot < 0 || preferred_slot >= kArmySlotCount || state.has(claimed, int_value(preferred_slot))) {
				preferred_slot = _first_open_army_slot(state, claimed);
			}
			if (preferred_slot < 0) {
				continue;
			}
			state.set(stack, str(key::slot_index), int_value(preferred_slot));
			state.set(claimed, int_value(preferred_slot), bool_value(true));
			state.append(stacks, dict_value(stack));
		}
	}
	// _stack_slot_less.
	gd::sort_custom(state, stacks, [&state](const Value &left, const Value &right) {
		return gd::int_field(state, gd::as_dict(left), key::slot_index, kArmySlotCount) < gd::int_field(state, gd::as_dict(right), key::slot_index, kArmySlotCount);
	});
	return stacks;
}

int64_t _valid_stack_count(State &state, const Value &value) {
	int64_t count = 0;
	if (gd::is_array(value)) {
		for (const Value &stack_value : gd::items(state, value)) {
			if (gd::is_dict(stack_value) && ai::string_or_empty(state, stack_value.ref, key::unit_id) != key::empty && gd::int_field(state, stack_value.ref, key::count, 0) > 0) {
				count += 1;
			}
		}
	}
	return count;
}

int64_t _first_open_army_slot(State &state, DictRef claimed) {
	for (int64_t slot_index = 0; slot_index < kArmySlotCount; ++slot_index) {
		if (!state.has(claimed, int_value(slot_index))) {
			return slot_index;
		}
	}
	return -1;
}

DictRef hero_by_id(State &state, DictRef session, Atom hero_id) {
	if (hero_id == key::empty) {
		return state.new_dict();
	}
	const DictRef overworld = session_view::overworld(state, session);
	for (const Value &hero : gd::field_items(state, overworld, str(key::player_heroes))) {
		if (gd::is_dict(hero) && ai::string_or_empty(state, hero.ref, key::id) == hero_id) {
			return hero.ref;
		}
	}
	return state.new_dict();
}

ArrayRef stationed_heroes(State &state, DictRef session, DictRef town) {
	const ArrayRef stationed = state.new_array();
	if (gd::is_empty(state, town)) {
		return stationed;
	}
	const DictRef overworld = session_view::overworld(state, session);
	for (const Value &hero : gd::field_items(state, overworld, str(key::player_heroes))) {
		if (gd::is_dict(hero) && _hero_is_stationed_at_town(state, hero.ref, town)) {
			state.append(stationed, hero);
		}
	}
	return stationed;
}

DictRef town_defending_hero(State &state, DictRef session, DictRef town, Atom preferred_hero_id) {
	const ArrayRef candidates = stationed_heroes(state, session, town);
	if (preferred_hero_id != key::empty) {
		for (const Value &hero : gd::items(state, array_value(candidates))) {
			if (ai::string_or_empty(state, hero.ref, key::id) == preferred_hero_id) {
				return hero.ref;
			}
		}
	}
	// The garrison hero's army is the garrison, so it holds the walls.
	const DictRef garrison_hero = town_garrison_hero(state, session, town);
	if (!gd::is_empty(state, garrison_hero)) {
		return garrison_hero;
	}
	const Atom identity = ai::string_or_empty(state, session_view::overworld(state, session), key::active_hero_id);
	if (identity != key::empty) {
		for (const Value &hero : gd::items(state, array_value(candidates))) {
			if (ai::string_or_empty(state, hero.ref, key::id) == identity) {
				return hero.ref;
			}
		}
	}
	for (const Value &hero : gd::items(state, array_value(candidates))) {
		if (gd::bool_field(state, hero.ref, key::is_primary, false)) {
			return hero.ref;
		}
	}
	return state.array_size(candidates) != 0 ? gd::as_dict(state.at(candidates, 0)) : state.new_dict();
}

DictRef town_garrison_hero(State &state, DictRef session, DictRef town) {
	if (gd::is_empty(state, town)) {
		return state.new_dict();
	}
	const Atom hero_id = ai::string_or_empty(state, town, key::garrison_hero_id);
	if (hero_id == key::empty) {
		return state.new_dict();
	}
	const DictRef hero = hero_by_id(state, session, hero_id);
	if (gd::is_empty(state, hero) || !_hero_is_stationed_at_town(state, hero, town)) {
		return state.new_dict();
	}
	return hero;
}

DictRef town_defense_force(State &state, DictRef session, DictRef town, Atom preferred_hero_id) {
	const DictRef hero = town_defending_hero(state, session, town, preferred_hero_id);
	const ArrayRef stacks = state.new_array();
	int64_t garrison_troops = 0;
	int64_t garrison_stacks = 0;
	int64_t hero_troops = 0;
	int64_t hero_stacks = 0;
	for (const Atom source_type : {key::hero_army, key::town_garrison}) {
		const bool from_hero = source_type == key::hero_army;
		// hero.get("army", {}).get("stacks", []) or town.get("garrison", []).
		Value rows;
		bool listed = false;
		if (from_hero) {
			Value army;
			if (state.lookup(hero, str(key::army), army)) {
				if (!gd::is_dict(army)) {
					(void)ai::vget(state, army, key::stacks);
				}
				listed = state.lookup(army.ref, str(key::stacks), rows);
			}
		} else {
			listed = state.lookup(town, str(key::garrison), rows);
		}
		if (!listed) {
			continue;
		}
		const ArrayRef row_list = ai::typed_array(rows, "HeroCommandRules.town_defense_force");
		for (const Value &row : gd::items(state, array_value(row_list))) {
			if (!gd::is_dict(row)) {
				continue;
			}
			const int64_t count = compat::engine_max<int64_t>(0, gd::int_field(state, row.ref, key::count, 0));
			const Atom unit_id = ai::string_or_empty(state, row.ref, key::unit_id);
			if (count == 0 || unit_id == key::empty) {
				continue;
			}
			const DictRef source = state.new_dict();
			state.set(source, str(key::source_type), str(source_type));
			state.set(source, str(key::town_placement_id), str(ai::string_or_empty(state, town, key::placement_id)));
			if (from_hero) {
				state.set(source, str(key::hero_id), str(ai::string_or_empty(state, hero, key::id)));
			}
			const DictRef descriptor = state.new_dict();
			state.set(descriptor, str(key::unit_id), str(unit_id));
			state.set(descriptor, str(key::count), int_value(count));
			state.set(descriptor, str(key::source), dict_value(source));
			const int64_t slot = gd::int_field(state, row.ref, key::slot_index, -1);
			if (slot >= 0 && slot < kArmySlotCount) {
				state.set(descriptor, str(key::slot_index), int_value(slot));
			}
			state.append(stacks, dict_value(descriptor));
			if (from_hero) {
				hero_troops = gd::add(hero_troops, count);
				hero_stacks += 1;
			} else {
				garrison_troops = gd::add(garrison_troops, count);
				garrison_stacks += 1;
			}
		}
	}
	const DictRef force = state.new_dict();
	state.set(force, str(key::hero), dict_value(hero));
	state.set(force, str(key::stacks), array_value(stacks));
	state.set(force, str(key::troops), int_value(gd::add(garrison_troops, hero_troops)));
	state.set(force, str(key::stack_count), int_value(state.array_size(stacks)));
	state.set(force, str(key::garrison_troops), int_value(garrison_troops));
	state.set(force, str(key::garrison_stacks), int_value(garrison_stacks));
	state.set(force, str(key::hero_troops), int_value(hero_troops));
	state.set(force, str(key::hero_stacks), int_value(hero_stacks));
	return force;
}

bool _hero_is_stationed_at_town(State &state, DictRef hero, DictRef town) {
	Value position;
	if (!state.lookup(hero, str(key::position), position)) {
		position = dict_value(state.new_dict());
	}
	const DictRef normalized = _normalize_position(state, position);
	const DictRef entrance = overworld_level_rules::town_entrance(state, town);
	return gd::equal(state, dict_value(normalized), dict_value(entrance));
}

} // namespace hero_command_rules

} // namespace aurelion::rules::port
