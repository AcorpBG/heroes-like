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

#include <algorithm>
#include <string>
#include <unordered_map>
#include <vector>

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
	ArrayRef stacks = state.new_array();
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
	// The hero and the garrison share the battle's seven slots: stacks of one kind
	// merge when they would not fit (the garrison's into the hero's first stack of
	// that kind, its other kinds one stack each). When even that does not fit,
	// fits is false and the attacker fights the hero first.
	bool fits = true;
	ArrayRef merged_garrison = state.new_array();
	if (state.array_size(stacks) > kArmySlotCount && !gd::is_empty(state, hero)) {
		const Value hero_army = state.get(hero, str(key::army), dict_value(state.new_dict()));
		const Value hero_rows = gd::is_dict(hero_army) ? state.get(hero_army.ref, str(key::stacks), array_value(state.new_array())) : array_value(state.new_array());
		const DictRef plan = entry_defense_plan(state, hero_rows, state.get(town, str(key::garrison), array_value(state.new_array())));
		fits = gd::bool_field(state, plan, key::fits, false);
		if (fits) {
			const ArrayRef rebuilt = state.new_array();
			std::unordered_map<Atom, int64_t> first_at;
			for (const bool hero_side : {true, false}) {
				for (const Value &descriptor : gd::items(state, array_value(stacks))) {
					const DictRef source = gd::as_dict(state.get(descriptor.ref, str(key::source), dict_value(state.new_dict())));
					if ((ai::string_or_empty(state, source, key::source_type) == key::hero_army) != hero_side) {
						continue;
					}
					const Atom unit = ai::string_or_empty(state, descriptor.ref, key::unit_id);
					const auto found = first_at.find(unit);
					if (hero_side || found == first_at.end()) {
						if (found == first_at.end()) {
							first_at[unit] = state.array_size(rebuilt);
						}
						state.append(rebuilt, dict_value(gd::deep_duplicate_dict(state, descriptor.ref)));
						continue;
					}
					const DictRef target = gd::as_dict(state.at(rebuilt, found->second));
					state.set(target, str(key::count), int_value(gd::add(gd::int_field(state, target, key::count, 0), gd::int_field(state, descriptor.ref, key::count, 0))));
				}
			}
			stacks = rebuilt;
			merged_garrison = gd::as_array(gd::index(state, plan, str(key::merged)));
		}
	}
	const DictRef force = state.new_dict();
	state.set(force, str(key::hero), dict_value(hero));
	state.set(force, str(key::stacks), array_value(stacks));
	state.set(force, str(key::fits), bool_value(fits));
	state.set(force, str(key::merged_garrison), array_value(merged_garrison));
	state.set(force, str(key::troops), int_value(gd::add(garrison_troops, hero_troops)));
	state.set(force, str(key::stack_count), int_value(state.array_size(stacks)));
	state.set(force, str(key::garrison_troops), int_value(garrison_troops));
	state.set(force, str(key::garrison_stacks), int_value(garrison_stacks));
	state.set(force, str(key::hero_troops), int_value(hero_troops));
	state.set(force, str(key::hero_stacks), int_value(hero_stacks));
	return force;
}

// --- A hero on a town's entry fighting together with the garrison ---

namespace {

// The rows of an army list with a unit and a positive count.
std::vector<DictRef> live_rows(State &state, const Value &stacks) {
	std::vector<DictRef> rows;
	if (!gd::is_array(stacks)) {
		return rows;
	}
	for (const Value &row : gd::items(state, stacks)) {
		if (gd::is_dict(row) && gd::int_field(state, row.ref, key::count, 0) > 0 && ai::string_or_empty(state, row.ref, key::unit_id) != key::empty) {
			rows.push_back(row.ref);
		}
	}
	return rows;
}

std::unordered_map<Atom, int64_t> unit_totals(State &state, const std::vector<DictRef> &rows) {
	std::unordered_map<Atom, int64_t> totals;
	for (const DictRef row : rows) {
		totals[ai::string_or_empty(state, row, key::unit_id)] += gd::int_field(state, row, key::count, 0);
	}
	return totals;
}

DictRef row_with_count(State &state, DictRef row, int64_t count, bool keep_slot) {
	const DictRef copy = gd::deep_duplicate_dict(state, row);
	state.set(copy, str(key::count), int_value(count));
	if (!keep_slot) {
		state.erase(copy, str(key::slot_index));
	}
	return copy;
}

} // namespace

DictRef entry_defense_plan(State &state, const Value &hero_stacks, const Value &garrison) {
	const std::vector<DictRef> hero_rows = live_rows(state, hero_stacks);
	const std::vector<DictRef> garrison_rows = live_rows(state, garrison);
	const ArrayRef stacks = state.new_array();
	const ArrayRef merged = state.new_array();
	bool fits = static_cast<int64_t>(hero_rows.size() + garrison_rows.size()) <= kArmySlotCount;
	if (fits) {
		// Every stack keeps its own slot in the battle.
		for (const DictRef row : hero_rows) {
			state.append(stacks, dict_value(row_with_count(state, row, gd::int_field(state, row, key::count, 0), true)));
		}
		for (const DictRef row : garrison_rows) {
			state.append(stacks, dict_value(row_with_count(state, row, gd::int_field(state, row, key::count, 0), true)));
		}
	} else {
		// Stacks of one kind merge: the garrison's join the hero's first stack of
		// that kind, its other kinds take one stack each.
		std::unordered_map<Atom, int64_t> first_at;
		std::unordered_map<Atom, int64_t> from_garrison;
		std::vector<Atom> merged_order;
		for (const DictRef row : hero_rows) {
			const Atom unit = ai::string_or_empty(state, row, key::unit_id);
			if (first_at.find(unit) == first_at.end()) {
				first_at[unit] = state.array_size(stacks);
			}
			state.append(stacks, dict_value(row_with_count(state, row, gd::int_field(state, row, key::count, 0), true)));
		}
		const int64_t hero_slots = state.array_size(stacks);
		for (const DictRef row : garrison_rows) {
			const Atom unit = ai::string_or_empty(state, row, key::unit_id);
			const int64_t count = gd::int_field(state, row, key::count, 0);
			const auto found = first_at.find(unit);
			if (found == first_at.end()) {
				first_at[unit] = state.array_size(stacks);
				state.append(stacks, dict_value(row_with_count(state, row, count, false)));
				continue;
			}
			const DictRef stack = gd::as_dict(state.at(stacks, found->second));
			state.set(stack, str(key::count), int_value(gd::add(gd::int_field(state, stack, key::count, 0), count)));
			if (found->second < hero_slots) {
				if (from_garrison.find(unit) == from_garrison.end()) {
					merged_order.push_back(unit);
				}
				from_garrison[unit] += count;
			}
		}
		fits = state.array_size(stacks) <= kArmySlotCount;
		const std::unordered_map<Atom, int64_t> hero_totals = unit_totals(state, hero_rows);
		for (const Atom unit : merged_order) {
			const DictRef entry = state.new_dict();
			state.set(entry, str(key::unit_id), str(unit));
			state.set(entry, str(key::hero_count), int_value(hero_totals.at(unit)));
			state.set(entry, str(key::garrison_count), int_value(from_garrison[unit]));
			state.append(merged, dict_value(entry));
		}
	}
	const DictRef plan = state.new_dict();
	state.set(plan, str(key::fits), bool_value(fits));
	state.set(plan, str(key::stacks), array_value(fits ? stacks : state.new_array()));
	state.set(plan, str(key::merged), array_value(fits ? merged : state.new_array()));
	return plan;
}

int64_t entry_hero_share(int64_t survivors, int64_t hero_count, int64_t garrison_count) {
	if (survivors <= 0 || hero_count <= 0) {
		return 0;
	}
	if (garrison_count <= 0) {
		return survivors;
	}
	const int64_t total = hero_count + garrison_count;
	// Survivors split by what each side brought, rounded half up.
	const int64_t share = (survivors * hero_count * 2 + total) / (total * 2);
	return std::min({share, hero_count, survivors});
}

DictRef split_entry_defense(State &state, const Value &hero_stacks, const Value &garrison, const Value &survivors) {
	const std::vector<DictRef> hero_rows = live_rows(state, hero_stacks);
	const std::vector<DictRef> garrison_rows = live_rows(state, garrison);
	const std::unordered_map<Atom, int64_t> hero_totals = unit_totals(state, hero_rows);
	const std::unordered_map<Atom, int64_t> garrison_totals = unit_totals(state, garrison_rows);
	const std::vector<DictRef> survivor_rows = live_rows(state, survivors);
	std::unordered_map<Atom, int64_t> survived = unit_totals(state, survivor_rows);
	std::unordered_map<Atom, int64_t> hero_left;
	std::unordered_map<Atom, int64_t> garrison_left;
	std::vector<Atom> survivor_order;
	for (const DictRef row : survivor_rows) {
		const Atom unit = ai::string_or_empty(state, row, key::unit_id);
		if (hero_left.find(unit) != hero_left.end()) {
			continue;
		}
		survivor_order.push_back(unit);
		const auto hero_total = hero_totals.find(unit);
		const auto garrison_total = garrison_totals.find(unit);
		const int64_t share = entry_hero_share(survived[unit], hero_total == hero_totals.end() ? 0 : hero_total->second, garrison_total == garrison_totals.end() ? 0 : garrison_total->second);
		hero_left[unit] = share;
		garrison_left[unit] = survived[unit] - share;
	}
	const ArrayRef hero_after = state.new_array();
	for (const DictRef row : hero_rows) {
		const Atom unit = ai::string_or_empty(state, row, key::unit_id);
		const int64_t take = std::min(gd::int_field(state, row, key::count, 0), hero_left[unit]);
		if (take > 0) {
			state.append(hero_after, dict_value(row_with_count(state, row, take, true)));
			hero_left[unit] -= take;
		}
	}
	const ArrayRef garrison_after = state.new_array();
	for (const DictRef row : garrison_rows) {
		const Atom unit = ai::string_or_empty(state, row, key::unit_id);
		const int64_t take = std::min(gd::int_field(state, row, key::count, 0), garrison_left[unit]);
		if (take > 0) {
			state.append(garrison_after, dict_value(row_with_count(state, row, take, true)));
			garrison_left[unit] -= take;
		}
	}
	// Survivors no row can take (more than went in) stay in the garrison.
	for (const Atom unit : survivor_order) {
		const int64_t rest = hero_left[unit] + garrison_left[unit];
		if (rest > 0) {
			const DictRef row = state.new_dict();
			state.set(row, str(key::unit_id), str(unit));
			state.set(row, str(key::count), int_value(rest));
			state.append(garrison_after, dict_value(row));
		}
	}
	// A hero that brought troops keeps one creature, as a human hero keeps one
	// from the garrison (keep_hero_troop_from_garrison).
	if (state.array_size(hero_after) == 0 && !hero_rows.empty() && state.array_size(garrison_after) > 0) {
		const DictRef first = gd::as_dict(state.at(garrison_after, 0));
		const int64_t count = gd::int_field(state, first, key::count, 0);
		state.append(hero_after, dict_value(row_with_count(state, first, 1, false)));
		if (count > 1) {
			state.set(first, str(key::count), int_value(count - 1));
		} else {
			gd::remove_at(state, garrison_after, 0);
		}
	}
	const DictRef split = state.new_dict();
	state.set(split, str(key::hero), array_value(hero_after));
	state.set(split, str(key::garrison), array_value(garrison_after));
	return split;
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
