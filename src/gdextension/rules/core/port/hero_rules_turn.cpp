// The computer players' day (Phase 4): a hire's hero and starting army, the tavern's offer, experience and
// level-ups, spellbooks, transit passages and visit buildings, ported under their GDScript names.

#include "aurelion_rules/port/hero_command_rules_turn.hpp"
#include "aurelion_rules/port/hero_progression_rules_turn.hpp"
#include "aurelion_rules/port/native_transit_rules_turn.hpp"
#include "aurelion_rules/port/spell_rules_turn.hpp"
#include "aurelion_rules/port/visit_building_rules_turn.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/artifact_rules.hpp"
#include "aurelion_rules/port/turn_port.hpp"
#include "aurelion_rules/compat/godot_string.hpp"

#include <cstdio>
#include <random>
#include <string>
#include <vector>

namespace aurelion::rules::port {

namespace {

using gd::array_value;
using gd::ArrayRef;
using gd::Atom;
using gd::bool_value;
using gd::dict_value;
using gd::DictRef;
using gd::float_value;
using gd::int_value;
using gd::str;
using state::State;
using state::Value;
namespace key = state::key;

// HeroCommandRules.ARMY_SLOT_COUNT.
constexpr int64_t kArmySlotCount = 7;

// ceili(x).
int64_t ceili(double x) {
	return compat::float_to_int(compat::godot_ceil(x));
}

// {"current": movement_max, "max": movement_max}.
DictRef movement_of(State &state, int64_t movement_max) {
	const DictRef movement = state.new_dict();
	state.set(movement, str(key::current), int_value(movement_max));
	state.set(movement, str(key::max), int_value(movement_max));
	return movement;
}

// `d.get(key, {})` stored in a typed Dictionary: a new one when the key is missing.
DictRef dict_field_or_new(State &state, DictRef dict, Atom field) {
	Value found;
	return state.lookup(dict, str(field), found) ? gd::as_dict(found) : state.new_dict();
}

// `d.get(key, {})` (or `[]`) when it is not a Dictionary replaced by a new one, as the scripts' writers do.
Value dict_or_new(State &state, DictRef dict, Atom field) {
	Value found;
	if (!state.lookup(dict, str(field), found) || !gd::is_dict(found)) {
		return dict_value(state.new_dict());
	}
	return found;
}

// HeroCommandRules.new_growth_seed without a session: GDScript draws "%08x%08x" from a randomized
// RandomNumberGenerator, a value no run repeats, so a draw from the system's random source is as good.
Atom random_growth_seed(State &state) {
	std::random_device device;
	const unsigned int high = device();
	const unsigned int low = device();
	char text[17];
	std::snprintf(text, sizeof(text), "%08x%08x", high, low);
	return state.intern(text);
}

// STARTING_*_COMPANY_GROWTH_SHARE: a const Array that _starting_company_size only reads.
ArrayRef growth_share(State &state, double low, double high) {
	const ArrayRef share = state.new_array();
	state.append(share, float_value(low));
	state.append(share, float_value(high));
	return share;
}

// {"unit_id": unit_id, "count": count}.
DictRef stack_of(State &state, Atom unit_id, int64_t count) {
	const DictRef stack = state.new_dict();
	state.set(stack, str(key::unit_id), str(unit_id));
	state.set(stack, str(key::count), int_value(count));
	return stack;
}

// a.sort() of an Array of Strings: Godot compares Strings by code points, the byte order of their UTF-8. Anything
// else to compare is not ported.
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

// sep.join(parts) of Strings.
Atom join_texts(State &state, const std::vector<std::string> &parts, const char *separator) {
	std::string joined;
	for (size_t index = 0; index < parts.size(); ++index) {
		if (index > 0) {
			joined += separator;
		}
		joined += parts[index];
	}
	return state.intern(joined);
}

// {"ok": false, "error": error, "message": message}.
DictRef failure(State &state, Atom error, Atom message) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(false));
	state.set(result, str(key::error), str(error));
	state.set(result, str(key::message), str(message));
	return result;
}

// x.duplicate(true) of an untyped value: only Dictionary and Array take the argument.
Value deep_duplicate(State &state, const Value &value) {
	if (gd::is_dict(value) || gd::is_array(value)) {
		return gd::duplicate_value(state, value, true);
	}
	throw state::ScriptError(std::string("Invalid call. Nonexistent function 'duplicate' in base '") + gd::type_name(value) + "'.");
}

} // namespace

// Defined in hero_commit.cpp and enemy_states.cpp (Phase 5) without a header.

namespace hero_command_rules {
Atom new_growth_seed(State &state, Atom hero_id, DictRef session);
ArrayRef _normalize_authored_specialties(State &state, const Value &value);
} // namespace hero_command_rules

namespace hero_progression_rules {
int64_t raw_pending_choices_remaining(State &state, DictRef hero_state);
int64_t max_rank_for_specialty(State &state, Atom specialty_id);
int64_t specialty_rank(State &state, DictRef hero_state, Atom specialty_id);
Atom growth_seed(State &state, DictRef hero_state);
Atom command_path(State &state, DictRef hero_state);
DictRef _build_choice_group(State &state, DictRef hero_state, int64_t level_number);
DictRef current_pending_choice(State &state, DictRef hero_state);
DictRef specialty_definition(State &state, Atom specialty_id);
DictRef choose_specialty(State &state, DictRef hero_state, Atom specialty_id);
} // namespace hero_progression_rules

// HeroCommandRules.

namespace hero_command_rules {

DictRef build_hero_from_template(State &state, DictRef hero_template, DictRef position, DictRef army_state, const Value &movement_source) {
	if (gd::is_empty(state, hero_template)) {
		return state.new_dict();
	}
	// var command = hero_template.get("command", {}): read only, a missing one reads as {}.
	Value command;
	const bool has_command = state.lookup(hero_template, str(key::command), command);
	const DictRef seed = state.new_dict();
	state.set(seed, str(key::id), str(gd::stringify(state, gd::field_or(state, hero_template, key::id, str(key::empty)))));
	state.set(seed, str(key::name), str(gd::stringify(state, gd::field_or(state, hero_template, key::name, str(key::wandering_captain)))));
	state.set(seed, str(key::level), int_value(1));
	state.set(seed, str(key::experience), int_value(0));
	state.set(seed, str(key::next_level_experience), int_value(250));
	state.set(seed, str(key::base_movement), int_value(compat::engine_max<int64_t>(1, gd::int_field(state, hero_template, key::base_movement, 10))));
	state.set(seed, str(key::command_path), str(gd::stringify(state, gd::field_or(state, hero_template, key::command_path, str(key::empty)))));
	const DictRef command_stats = state.new_dict();
	for (const Atom stat : { key::attack, key::defense, key::power, key::knowledge }) {
		const Value value = has_command ? ai::vget(state, command, stat, int_value(0)) : int_value(0);
		state.set(command_stats, str(stat), int_value(gd::to_int(state, value)));
	}
	state.set(seed, str(key::command), dict_value(command_stats));
	state.set(seed, str(key::spellbook), dict_value(spell_rules::build_spellbook(state, hero_template)));
	state.set(seed, str(key::artifacts), dict_value(artifact_rules::normalize_hero_artifacts(state, dict_value(state.new_dict()))));
	state.set(seed, str(key::specialties), array_value(_normalize_authored_specialties(state, gd::field(state, hero_template, key::starting_specialties))));
	state.set(seed, str(key::pending_specialty_choices), array_value(state.new_array()));
	state.set(seed, str(key::specialty_focus_ids), array_value(_normalize_authored_specialties(state, gd::field(state, hero_template, key::specialty_focus_ids))));
	const DictRef hero = hero_progression_rules::ensure_hero_progression(state, seed);
	// new_growth_seed(hero id, movement_source): a session arrives as its view, a Dictionary.
	const Atom seed_hero_id = ai::string_or_empty(state, hero, key::id);
	state.set(hero, str(key::growth_seed), str(gd::is_dict(movement_source) ? new_growth_seed(state, seed_hero_id, movement_source.ref) : random_growth_seed(state)));
	state.set(hero, str(key::position), dict_value(_normalize_position(state, dict_value(position))));
	state.set(hero, str(key::army), dict_value(_normalize_army(state, dict_value(army_state), ai::string_or_empty(state, hero, key::id))));
	const int64_t movement_max = movement_max_for_hero(state, hero, movement_source);
	state.set(hero, str(key::movement), dict_value(movement_of(state, movement_max)));
	state.set(hero, str(key::is_primary), bool_value(false));
	if (gd::is_dict(movement_source)) {
		const DictRef overworld = session_view::overworld(state, movement_source.ref);
		if (ai::string_or_empty(state, overworld, key::active_player_id) != key::empty) {
			state.set(hero, str(key::player_id), str(gd::stringify(state, gd::index(state, overworld, str(key::active_player_id)))));
		}
	}
	return hero;
}

DictRef build_recruited_hero(State &state, DictRef hero_template, DictRef position, const Value &movement_source, int64_t level, const Value &army_state, Atom seed_key, Atom growth_seed) {
	if (gd::is_empty(state, hero_template)) {
		return state.new_dict();
	}
	const Atom hero_id = ai::string_or_empty(state, hero_template, key::id);
	DictRef army = _normalize_army(state, army_state, hero_id);
	if (_valid_stack_count(state, gd::field(state, army, key::stacks)) == 0) {
		army = starting_army_for_hero(state, hero_template, seed_key != key::empty ? seed_key : hero_id);
	}
	DictRef hero = build_hero_from_template(state, hero_template, position, army, movement_source);
	if (gd::is_empty(state, hero)) {
		return hero;
	}
	// A caller without a session (the computer player's hires) passes its own
	// seed, so the levels a hire arrives with roll the same way every time.
	if (growth_seed != key::empty) {
		state.set(hero, str(key::growth_seed), str(growth_seed));
	}
	if (level > 1) {
		hero = hero_progression_rules::advance_to_level(state, hero, level);
	}
	// Specialty mana counts toward the new commander's full reserve.
	hero = spell_rules::ensure_hero_spellbook(state, hero, hero_template);
	const DictRef spellbook = dict_field_or_new(state, hero, key::spellbook);
	const DictRef mana = dict_field_or_new(state, spellbook, key::mana);
	if (!gd::is_empty(state, mana)) {
		state.set(mana, str(key::current), int_value(gd::int_field(state, mana, key::max, 0)));
		state.set(spellbook, str(key::mana), dict_value(mana));
		state.set(hero, str(key::spellbook), dict_value(spellbook));
	}
	const int64_t movement_max = movement_max_for_hero(state, hero, movement_source);
	state.set(hero, str(key::movement), dict_value(movement_of(state, movement_max)));
	return hero;
}

DictRef starting_army_for_hero(State &state, DictRef hero_template, Atom seed_key) {
	const Atom hero_id = ai::string_or_empty(state, hero_template, key::id);
	const Value rng = _seeded_rng(state, gd::format(state, key::s_starting_army, { str(seed_key) }));
	const ArrayRef stacks = state.new_array();
	Value authored;
	if (state.lookup(hero_template, str(key::starting_army), authored) && gd::is_array(authored)) {
		for (const Value &row : gd::items(state, authored)) {
			const Atom unit_id = gd::is_dict(row) ? ai::string_or_empty(state, row.ref, key::unit_id) : key::empty;
			if (unit_id == key::empty || gd::is_empty(state, gd::content_row(state, state::ContentTable::Unit, unit_id))) {
				continue;
			}
			const Value count = state.get(row.ref, str(key::count), int_value(1));
			const int64_t low = compat::engine_max<int64_t>(1, gd::to_int(state, state.get(row.ref, str(key::min_), count)));
			const int64_t high = compat::engine_max<int64_t>(low, gd::int_field(state, row.ref, key::max, low));
			state.append(stacks, dict_value(stack_of(state, unit_id, gd::rng_randi_range(state, rng, low, high))));
		}
	}
	if (state.array_size(stacks) == 0) {
		const Atom faction_id = ai::string_or_empty(state, hero_template, key::faction_id);
		const ArrayRef tier_one = _faction_creatures(state, faction_id, 1);
		const ArrayRef tier_two = _faction_creatures(state, faction_id, 2);
		if (state.array_size(tier_one) > 0) {
			const Atom first = gd::stringify(state, state.at(tier_one, gd::rng_randi_range(state, rng, 0, state.array_size(tier_one) - 1)));
			state.append(stacks, dict_value(stack_of(state, first, _starting_company_size(state, rng, first, growth_share(state, 0.55, 1.1)))));
			const ArrayRef other_tier_one = state.new_array();
			for (const Value &unit_id : gd::items(state, array_value(tier_one))) {
				if (gd::stringify(state, unit_id) != first) {
					state.append(other_tier_one, unit_id);
				}
			}
			// STARTING_SECOND_COMPANY_PERCENT, then STARTING_SECOND_COMPANY_TIER_TWO_PERCENT.
			if (gd::rng_randi_range(state, rng, 0, 99) < 75 && !(state.array_size(tier_two) == 0 && state.array_size(other_tier_one) == 0)) {
				const int64_t tier_two_roll = gd::rng_randi_range(state, rng, 0, 99);
				const ArrayRef pool = state.array_size(tier_two) > 0 && (state.array_size(other_tier_one) == 0 || tier_two_roll < 70) ? tier_two : other_tier_one;
				const Atom second = gd::stringify(state, state.at(pool, gd::rng_randi_range(state, rng, 0, state.array_size(pool) - 1)));
				state.append(stacks, dict_value(stack_of(state, second, _starting_company_size(state, rng, second, growth_share(state, 0.33, 0.65)))));
			}
		}
	}
	for (int64_t index = 0; index < state.array_size(stacks); ++index) {
		state.set(gd::as_dict(state.at(stacks, index)), str(key::slot_index), int_value(index));
	}
	const DictRef army = state.new_dict();
	state.set(army, str(key::id), str(gd::format(state, key::s_army, { str(hero_id) })));
	state.set(army, str(key::name), str(key::field_army));
	state.set(army, str(key::stacks), array_value(stacks));
	return army;
}

int64_t scout_row_half_width(State &state, int64_t dy, int64_t radius) {
	(void)state;
	return scout_row_half_width(dy, radius);
}

DictRef army_addition_split(State &state, const Value &stacks_value, DictRef additions) {
	ArrayRef stacks = gd::is_array(stacks_value) ? gd::deep_duplicate_array(state, stacks_value.ref) : state.new_array();
	if (_valid_stack_count(state, array_value(stacks)) <= kArmySlotCount) {
		stacks = _slotted_stacks(state, array_value(stacks));
	}
	const DictRef added = state.new_dict();
	const DictRef overflow = state.new_dict();
	const ArrayRef unit_ids = gd::keys(state, additions);
	sort_strings(state, unit_ids, "HeroCommandRules.army_addition_split");
	for (const Value &unit_id_value : gd::items(state, array_value(unit_ids))) {
		const Atom unit_id = gd::stringify(state, unit_id_value);
		const int64_t amount = compat::engine_max<int64_t>(0, gd::to_int(state, state.get(additions, unit_id_value, int_value(0))));
		if (unit_id == key::empty || amount == 0) {
			continue;
		}
		const DictRef addition = state.new_dict();
		state.set(addition, str(unit_id), int_value(amount));
		const DictRef plan = army_addition_plan(state, array_value(stacks), addition);
		if (gd::bool_field(state, plan, key::ok, false)) {
			stacks = gd::as_array(state.get(plan, str(key::stacks), array_value(stacks)));
			state.set(added, str(unit_id), int_value(amount));
		} else {
			state.set(overflow, str(unit_id), int_value(amount));
		}
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::stacks), array_value(stacks));
	state.set(result, str(key::added), dict_value(added));
	state.set(result, str(key::overflow), dict_value(overflow));
	return result;
}

bool town_has_hall(State &state, DictRef town) {
	// HALL_BUILDING_ID in town.get("built_buildings", []): a missing list holds nothing.
	Value built;
	if (!state.lookup(town, str(key::built_buildings), built)) {
		return false;
	}
	return gd::in(state, str(key::building_wayfarers_hall), built);
}

DictRef hero_recruit_cost(State &state, DictRef hero_template) {
	Value cost;
	if (!state.lookup(hero_template, str(key::recruit_cost), cost)) {
		// DEFAULT_RECRUIT_COST, which _normalize_resources only reads.
		const DictRef fallback = state.new_dict();
		state.set(fallback, str(key::gold), int_value(1200));
		cost = dict_value(fallback);
	}
	return _normalize_resources(state, cost);
}

int64_t tavern_week(State &state, DictRef session) {
	return compat::engine_max<int64_t>(0, compat::int_div(gd::sub(ai::session_int(state, session, key::day), 1), 7));
}

DictRef tavern_offer(State &state, DictRef session, Atom hero_id, int64_t week) {
	const DictRef hero_template = gd::content_row(state, state::ContentTable::Hero, hero_id);
	if (gd::is_empty(state, hero_template)) {
		return state.new_dict();
	}
	const int64_t offer_week = week >= 0 ? week : tavern_week(state, session);
	const Atom session_id = gd::stringify(state, gd::index(state, session, str(key::session_id)));
	const Atom scenario_id = gd::stringify(state, gd::index(state, session, str(key::scenario_id)));
	const Atom seed_key = gd::format(state, key::s_s_tavern_offer_d_s, { str(session_id), str(scenario_id), int_value(offer_week), str(hero_id) });
	const int64_t roll = gd::rng_randi_range(state, _seeded_rng(state, gd::format(state, key::s_level, { str(seed_key) })), 0, 99);
	// TAVERN_LEVEL_THREE_PERCENT, then TAVERN_LEVEL_TWO_PERCENT more.
	int64_t level = 1;
	if (roll < 3) {
		level = 3;
	} else if (roll < 3 + 10) {
		level = 2;
	}
	const DictRef offer = state.new_dict();
	state.set(offer, str(key::hero_id), str(hero_id));
	state.set(offer, str(key::week), int_value(offer_week));
	state.set(offer, str(key::level), int_value(level));
	state.set(offer, str(key::army), dict_value(starting_army_for_hero(state, hero_template, seed_key)));
	return offer;
}

bool _stack_slot_less(State &state, DictRef left, DictRef right) {
	return gd::int_field(state, left, key::slot_index, kArmySlotCount) < gd::int_field(state, right, key::slot_index, kArmySlotCount);
}

Value _seeded_rng(State &state, Atom seed_key) {
	return turn::seeded_rng(state, gd::hash(state, str(seed_key)));
}

ArrayRef _faction_creatures(State &state, Atom faction_id, int64_t tier) {
	const ArrayRef creatures = state.new_array();
	// ContentService.load_json(TOWN_DEVELOPMENT_PATH).get("rosters", {}) and rosters.get(faction_id, []), read only.
	Value rosters;
	Value roster;
	const bool has_roster = state.lookup(gd::content_file(state, key::town_development_path), str(key::rosters), rosters) &&
			gd::is_dict(rosters) && state.lookup(rosters.ref, str(faction_id), roster);
	if (has_roster && gd::is_array(roster)) {
		for (const Value &row : gd::items(state, roster)) {
			if (gd::is_dict(row) && gd::int_field(state, row.ref, key::tier, 0) == tier) {
				const Atom unit_id = ai::string_or_empty(state, row.ref, key::unit_id);
				if (unit_id != key::empty && !gd::array_has(state, creatures, str(unit_id)) && !gd::is_empty(state, gd::content_row(state, state::ContentTable::Unit, unit_id))) {
					state.append(creatures, str(unit_id));
				}
			}
		}
	}
	if (state.array_size(creatures) == 0) {
		const DictRef faction = gd::content_row(state, state::ContentTable::Faction, faction_id);
		for (const Value &unit_id_value : gd::field_items(state, faction, str(key::unit_ladder_ids))) {
			const DictRef unit = gd::content_row(state, state::ContentTable::Unit, gd::stringify(state, unit_id_value));
			if (gd::int_field(state, unit, key::tier, 0) == tier) {
				state.append(creatures, str(gd::stringify(state, unit_id_value)));
			}
		}
	}
	return creatures;
}

int64_t _starting_company_size(State &state, const Value &rng, Atom unit_id, ArrayRef growth_share) {
	const int64_t growth = compat::engine_max<int64_t>(1, gd::int_field(state, gd::content_row(state, state::ContentTable::Unit, unit_id), key::growth, 6));
	const int64_t low = compat::engine_max<int64_t>(1, ceili(static_cast<double>(growth) * gd::to_float(state.at(growth_share, 0))));
	const int64_t high = compat::engine_max<int64_t>(low, ceili(static_cast<double>(growth) * gd::to_float(state.at(growth_share, 1))));
	return gd::rng_randi_range(state, rng, low, high);
}

DictRef _normalize_resources(State &state, const Value &value) {
	const DictRef resources = state.new_dict();
	if (gd::is_dict(value)) {
		for (const Value &resource : gd::items(state, value)) {
			const Atom resource_key = gd::stringify(state, resource);
			const int64_t amount = compat::engine_max<int64_t>(0, gd::to_int(state, gd::index(state, value.ref, resource)));
			if (amount > 0) {
				state.set(resources, str(resource_key), int_value(amount));
			}
		}
	}
	return resources;
}

} // namespace hero_command_rules

// HeroProgressionRules.

namespace hero_progression_rules {

int64_t experience_for_level(State &state, int64_t level) {
	(void)state;
	int64_t threshold = 0;
	int64_t next_threshold = 250;
	const int64_t end = gd::add(level, 1);
	for (int64_t reached = 2; reached < end; ++reached) {
		threshold = next_threshold;
		next_threshold = gd::add(next_threshold, gd::add(250, gd::mul(reached, 100)));
	}
	return threshold;
}

DictRef advance_to_level(State &state, DictRef hero_state, int64_t target_level) {
	DictRef hero = ensure_hero_progression(state, gd::deep_duplicate_dict(state, hero_state));
	const int64_t missing = gd::sub(experience_for_level(state, target_level), gd::int_field(state, hero, key::experience, 0));
	if (missing > 0) {
		hero = gd::as_dict(state.get(_add_experience(state, hero, missing), str(key::hero), dict_value(hero)));
	}
	while (pending_choices_remaining(state, hero) > 0) {
		// var options: Array = current_pending_choice(hero).get("options", [])
		Value options;
		if (!state.lookup(current_pending_choice(state, hero), str(key::options), options)) {
			options = array_value(state.new_array());
		}
		if (state.array_size(gd::as_array(options)) == 0) {
			break;
		}
		const Atom specialty_id = gd::stringify(state, state.at(options.ref, 0));
		// choose_specialty answers the hero alone. Its refusals: no choice waiting
		// or an id not offered cannot happen (the option comes from the same
		// ensured hero), and a mastered specialty is checked here as it checks it
		// (the hero's specialties are already normalized).
		if (specialty_rank(state, hero, specialty_id) >= max_rank_for_specialty(state, specialty_id)) {
			break;
		}
		hero = choose_specialty(state, hero, specialty_id);
	}
	state.set(hero, str(key::level_up_presented), int_value(gd::int_field(state, hero, key::level, 1)));
	return hero;
}

int64_t pending_choices_remaining(State &state, DictRef hero_state) {
	const DictRef hero = ensure_hero_progression(state, gd::deep_duplicate_dict(state, hero_state));
	return raw_pending_choices_remaining(state, hero);
}

Atom rank_label(State &state, int64_t rank) {
	(void)state;
	if (rank <= 0) {
		return key::k_0;
	}
	// RANK_LABELS[min(rank - 1, RANK_LABELS.size() - 1)]
	switch (compat::engine_min<int64_t>(rank - 1, 3)) {
		case 0:
			return key::I;
		case 1:
			return key::II;
		case 2:
			return key::III;
		default:
			return key::IV;
	}
}

} // namespace hero_progression_rules

// NativeTransitRules.

namespace native_transit_rules {

DictRef resolve(State &state, ArrayRef nodes, DictRef node, Atom target_id) {
	const DictRef indexed = nodes_by_id(state, nodes);
	const Atom error = contract_error(state, node, indexed);
	if (error != key::empty) {
		return failure(state, error, gd::format(state, key::this_passage_has_an_invalid_destination, { str(error) }));
	}
	const DictRef link = gd::deep_duplicate_dict(state, link_of(state, node));
	const ArrayRef options = destinations(state, node);
	const int64_t option_count = state.array_size(options);
	if (option_count == 0) {
		const bool arrival_only = gd::equal(state, gd::field(state, link, key::kind), str(key::one_way_exit));
		return failure(state, key::native_passage_has_no_exit, arrival_only ? key::this_is_an_arrival_only_portal : key::this_passage_has_no_connected_destination);
	}
	if (target_id == key::empty && option_count > 1) {
		const DictRef result = state.new_dict();
		state.set(result, str(key::ok), bool_value(false));
		state.set(result, str(key::native_transit_random_exit), bool_value(true));
		state.set(result, str(key::destinations), array_value(gd::deep_duplicate_array(state, options)));
		state.set(result, str(key::message), str(key::this_portal_sends_travellers_to_a));
		return result;
	}
	for (int64_t index = 0; index < option_count; ++index) {
		const Value destination = state.at(options, index);
		if (target_id == key::empty || gd::stringify(state, ai::vget(state, destination, key::target_placement_id, str(key::empty))) == target_id) {
			state.set(link, str(key::target_placement_id), ai::vmember(state, destination, key::target_placement_id));
			state.set(link, str(key::exit), deep_duplicate(state, ai::vmember(state, destination, key::exit)));
			const DictRef result = state.new_dict();
			state.set(result, str(key::ok), bool_value(true));
			state.set(result, str(key::link), dict_value(link));
			state.set(result, str(key::entry), point(state, gd::index(state, link, str(key::entry))));
			state.set(result, str(key::exit), point(state, gd::index(state, link, str(key::exit))));
			const Atom peer_id = gd::stringify(state, gd::index(state, link, str(key::target_placement_id)));
			state.set(result, str(key::peer), gd::index(state, indexed, str(peer_id)));
			return result;
		}
	}
	return failure(state, key::native_passage_destination_not_in_group, key::that_destination_is_not_connected_to);
}

} // namespace native_transit_rules

// SpellRules.

namespace spell_rules {

DictRef build_spellbook(State &state, DictRef hero_template) {
	// hero_template.get("command", {}): mana_max_from_command reads no command and {} alike.
	const int64_t mana_max = mana_max_from_command(state, gd::field(state, hero_template, key::command));
	const DictRef spellbook = state.new_dict();
	state.set(spellbook, str(key::known_spell_ids), array_value(_normalize_spell_ids(state, gd::field(state, hero_template, key::starting_spell_ids))));
	const DictRef mana = state.new_dict();
	state.set(mana, str(key::current), int_value(mana_max));
	state.set(mana, str(key::max), int_value(mana_max));
	state.set(spellbook, str(key::mana), dict_value(mana));
	return spellbook;
}

DictRef learn_spell(State &state, DictRef hero_state, Atom spell_id) {
	const DictRef hero = ensure_hero_spellbook(state, gd::deep_duplicate_dict(state, hero_state), state.new_dict());
	const DictRef spell = gd::content_row(state, state::ContentTable::Spell, spell_id);
	const DictRef result = state.new_dict();
	if (gd::is_empty(state, spell)) {
		state.set(result, str(key::ok), bool_value(false));
		state.set(result, str(key::hero), dict_value(hero));
		state.set(result, str(key::message), str(key::that_spell_is_not_known_to));
		return result;
	}
	if (_knows_spell(state, hero, spell_id)) {
		const Atom hero_name = gd::stringify(state, gd::field_or(state, hero, key::name, str(key::the_hero_text)));
		const Atom spell_name = gd::stringify(state, gd::field_or(state, spell, key::name, str(spell_id)));
		state.set(result, str(key::ok), bool_value(false));
		state.set(result, str(key::hero), dict_value(hero));
		state.set(result, str(key::message), str(gd::format(state, key::s_already_knows_s, { str(hero_name), str(spell_name) })));
		return result;
	}
	// var spellbook = hero.get("spellbook", {}); var known_spell_ids: Array = spellbook.get("known_spell_ids", [])
	Value spellbook;
	if (!state.lookup(hero, str(key::spellbook), spellbook)) {
		spellbook = dict_value(state.new_dict());
	}
	const ArrayRef known_spell_ids = gd::as_array(ai::vget(state, spellbook, key::known_spell_ids, array_value(state.new_array())));
	state.append(known_spell_ids, str(spell_id));
	state.set(spellbook.ref, str(key::known_spell_ids), array_value(_normalize_spell_ids(state, array_value(known_spell_ids))));
	state.set(hero, str(key::spellbook), spellbook);
	const Atom hero_name = gd::stringify(state, gd::field_or(state, hero, key::name, str(key::the_hero_text)));
	const Atom spell_name = gd::stringify(state, gd::field_or(state, spell, key::name, str(spell_id)));
	state.set(result, str(key::ok), bool_value(true));
	state.set(result, str(key::hero), dict_value(hero));
	state.set(result, str(key::message), str(gd::format(state, key::s_learns_s, { str(hero_name), str(spell_name) })));
	return result;
}

} // namespace spell_rules

// VisitBuildingRules.

namespace visit_building_rules {

void record_visit(State &state, DictRef node, DictRef site, Atom visitor_key, int64_t day, Atom side) {
	const Value visits = dict_or_new(state, node, key::hero_visits);
	state.set(visits.ref, str(visitor_key), int_value(day));
	state.set(node, str(key::hero_visits), visits);
	if (cadence(state, site) == key::once_per_side) {
		const Value side_visits = dict_or_new(state, node, key::side_visits);
		state.set(side_visits.ref, str(side != key::empty ? side : visitor_key), int_value(day));
		state.set(node, str(key::side_visits), side_visits);
	}
	if (cadence(state, site) == key::weekly_site) {
		state.set(node, str(key::site_last_visit_day), int_value(day));
	}
}

Atom effect_summary(State &state, DictRef effect) {
	std::vector<std::string> parts;
	const auto add = [&state, &parts](Atom part) { parts.push_back(state.text(part)); };
	const Value gains = gd::field(state, effect, key::resources);
	if (gd::is_dict(gains) && !gd::is_empty(state, gains.ref)) {
		add(gd::format(state, key::s_2, { str(_resource_text(state, gains.ref)) }));
	}
	const Value stats = gd::field(state, effect, key::stats);
	if (gd::is_dict(stats)) {
		for (const Atom stat : { key::attack, key::defense, key::power, key::knowledge }) {
			if (gd::int_field(state, stats.ref, stat, 0) != 0) {
				add(gd::format(state, key::d_s_2, { int_value(gd::int_field(state, stats.ref, stat, 0)), str(stat) }));
			}
		}
	}
	if (gd::int_field(state, effect, key::experience, 0) > 0) {
		add(gd::format(state, key::s_xp, { str(_thousands(state, gd::int_field(state, effect, key::experience, 0))) }));
	}
	if (gd::int_field(state, effect, key::levels, 0) > 0) {
		add(gd::format(state, key::d_level, { int_value(gd::int_field(state, effect, key::levels, 0)) }));
	}
	if (gd::int_field(state, effect, key::spell_tier, 0) > 0) {
		add(gd::format(state, key::teaches_a_tier_d_spell, { int_value(gd::int_field(state, effect, key::spell_tier, 0)) }));
	}
	const Atom mana = ai::string_or_empty(state, effect, key::mana);
	if (mana == key::refill) {
		add(key::refills_mana);
	} else if (mana == key::week_double) {
		add(key::double_mana_until_the_week_ends);
	}
	if (gd::int_field(state, effect, key::movement, 0) > 0) {
		add(gd::format(state, key::d_movement_now, { int_value(gd::int_field(state, effect, key::movement, 0)) }));
	}
	if (gd::int_field(state, effect, key::week_movement, 0) > 0) {
		add(gd::format(state, key::d_movement_each_day_this_week, { int_value(gd::int_field(state, effect, key::week_movement, 0)) }));
	}
	const Value boosts = gd::field(state, effect, key::battle_boosts);
	if (gd::is_dict(boosts)) {
		for (const Atom boost : { key::cohesion, key::momentum }) {
			if (gd::int_field(state, boosts.ref, boost, 0) != 0) {
				add(gd::format(state, key::d_s_next_battle, { int_value(gd::int_field(state, boosts.ref, boost, 0)), str(boost) }));
			}
		}
	}
	const Value rest_day = gd::field(state, effect, key::day7_battle_boosts);
	if (gd::is_dict(rest_day)) {
		for (const Atom boost : { key::cohesion, key::momentum }) {
			if (gd::int_field(state, rest_day.ref, boost, 0) != 0) {
				add(gd::format(state, key::d_more_s_on_day_7, { int_value(gd::int_field(state, rest_day.ref, boost, 0)), str(boost) }));
			}
		}
	}
	if (gd::int_field(state, effect, key::reveal_radius, 0) > 0) {
		add(gd::format(state, key::reveals_the_land_within_d_tiles, { int_value(gd::int_field(state, effect, key::reveal_radius, 0)) }));
	}
	if (ai::string_or_empty(state, effect, key::reveal) == key::level) {
		add(key::reveals_this_map_level);
	}
	if (gd::bool_field(state, effect, key::market, false)) {
		add(key::trades_resources);
	}
	return join_texts(state, parts, ", ");
}

Atom _thousands(State &state, int64_t value) {
	std::string digits = compat::itos(value);
	std::string grouped;
	while (digits.size() > 3) {
		grouped = "," + digits.substr(digits.size() - 3) + grouped;
		digits = digits.substr(0, digits.size() - 3);
	}
	return state.intern(digits + grouped);
}

} // namespace visit_building_rules

} // namespace aurelion::rules::port
