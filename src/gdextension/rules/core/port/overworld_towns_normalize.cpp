// OverworldRules.normalize_overworld_state's town and session parts (Phase 5
// slice 06b, group "towns"): the towns rebuilt with their known fields and the
// runtime metadata they keep, their development migration and reserve
// conversion (TownDevelopmentRules), the active town visit, and the session's
// difficulty, launch mode, player identity compatibility and player heroes
// (DifficultyRules, SessionStateStore, PlayerIdentityRules, HeroCommandRules).
//
// Left to GDScript (state::NotPorted): a human player's primary hero rebuilt
// from its template (HeroCommandRules.build_hero_from_template), the once per
// save garrison hero migration of a town holding two of the player's heroes
// (merge_stacks_into_army, _holder_stacks, _set_holder_stacks), and the
// GDScript runtime errors of odd values (built_buildings or available_recruits
// of the wrong type in TownDevelopmentRules).

#include "aurelion_rules/port/overworld_rules.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/difficulty_rules.hpp"
#include "aurelion_rules/port/difficulty_rules_ai.hpp"
#include "aurelion_rules/port/hero_command_rules.hpp"
#include "aurelion_rules/port/hero_command_rules_ai.hpp"
#include "aurelion_rules/port/hero_commit.hpp"
#include "aurelion_rules/port/overworld_rules_ai.hpp"
#include "aurelion_rules/port/player_identity_rules.hpp"
#include "aurelion_rules/port/session_state_store.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/town_development_rules.hpp"
#include "aurelion_rules/port/town_development_rules_ai.hpp"

#include "aurelion_rules/compat/godot_math.hpp"

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
using gd::int_value;
using gd::str;
using state::ContentTable;
using state::State;
using state::Value;
namespace key = state::key;

[[noreturn]] void not_ported(const char *path) {
	throw state::NotPorted(std::string("left to GDScript: ") + path);
}

// String(d.get(key, fallback)).
Atom text(State &state, DictRef dict, Atom field, Atom fallback) {
	return gd::stringify_or_fallback(state, state.get(dict, str(field), str(fallback)));
}

// max(0, int(d.get(key, 0))): an int, as max() of two ints is.
int64_t count_field(State &state, DictRef dict, Atom field) {
	return compat::engine_max<int64_t>(0, gd::int_field(state, dict, field, 0));
}

// d.get(key, {}) and d.get(key, []) where the result is passed on: the value,
// or a new container when the key is missing.
Value get_or_new_dict(State &state, DictRef dict, Atom field) {
	Value found;
	return state.lookup(dict, str(field), found) ? found : dict_value(state.new_dict());
}
Value get_or_new_array(State &state, DictRef dict, Atom field) {
	Value found;
	return state.lookup(dict, str(field), found) ? found : array_value(state.new_array());
}

// session.flags: SessionData types it Dictionary.
DictRef session_flags(const State &state, DictRef session) {
	return gd::as_dict(gd::field(state, session, key::flags));
}

// OverworldRules.ACTIVE_TOWN_PLACEMENT_KEY is key::active_town_placement_id;
// HeroCommandRules.TOWN_GARRISON_HERO_KEY is key::garrison_hero_id,
// TOWN_GARRISON_HEROES_VERSION_KEY key::town_garrison_heroes_version and
// PRIMARY_FALLEN_FLAG key::primary_hero_fallen.
constexpr int64_t kTownGarrisonHeroesVersion = 1;

// The runtime metadata _copy_town_runtime_metadata keeps, in its order.
constexpr Atom kTownRuntimeMetadataKeys[] = {
	key::development_version,
	key::garrison_hero_id,
	key::legacy_built_buildings,
	key::artifact_shop_purchases,
	key::town_service_claims,
	key::controlling_player_id,
	key::owner_slot,
	key::level,
	key::hero_start_tile,
	key::runtime_start_tile,
	key::player_slot,
	key::player_type,
	key::team_id,
	key::faction_id,
	key::is_start_town,
	key::start_anchor,
	key::body_tiles,
	key::blocking_body,
	key::approach_tiles,
	key::visit_tile,
	key::package_visit_tiles,
	key::package_body_tiles,
	key::package_block_tiles,
	key::passability_class,
	key::zone_id,
	key::zone_role,
	key::ai_defended_by_faction_id,
	key::ai_defended_by_player_id,
	key::ai_defended_day,
	key::ai_defense_until_day,
	key::ai_defense_rating,
	key::ai_defense_reinforced_strength,
	key::ai_defender_commander_state,
	key::ai_defender_roster_hero_id,
	key::artifact_reward_id,
	key::artifact_reward_table_id,
	key::artifact_reward_source_key,
	key::artifact_reward_claimed_by_owner,
	key::artifact_reward_claimed_by_faction_id,
	key::artifact_reward_claimed_by_player_id,
	key::artifact_reward_claimed_day,
	key::artifact_reward_service_building_id,
};

// _pathing_debug_profile[counter] = int(_pathing_debug_profile.get(counter, 0)) + 1.
void count_pathing(State &state, Atom counter) {
	const DictRef profile = gd::as_dict(gd::static_var(state, key::overworld_rules_script, key::_pathing_debug_profile));
	state.set(profile, str(counter), int_value(gd::add(gd::int_field(state, profile, counter, 0), 1)));
}

// OverworldRules._active_town_visit_indexes.
DictRef active_town_visit_indexes(State &state) {
	return gd::as_dict(gd::static_var(state, key::overworld_rules_script, key::_active_town_visit_indexes));
}

// {"index": index, "town": town}.
DictRef town_result(State &state, int64_t index, const Value &town) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::index), int_value(index));
	state.set(result, str(key::town), town);
	return result;
}

// {"index": -1, "town": {}}.
DictRef no_town(State &state) {
	return town_result(state, -1, dict_value(state.new_dict()));
}

} // namespace

// OverworldRules.

namespace overworld_rules {

ArrayRef _normalize_towns(State &state, ArrayRef towns, int64_t current_day) {
	const ArrayRef normalized = state.new_array();
	for (const Value &town_value : gd::items(state, array_value(towns))) {
		if (!gd::is_dict(town_value)) {
			continue;
		}
		const DictRef town = town_value.ref;
		// var built_buildings = town.get("built_buildings", []), [] unless an Array.
		Value built_buildings;
		if (!state.lookup(town, str(key::built_buildings), built_buildings) || !gd::is_array(built_buildings)) {
			built_buildings = array_value(state.new_array());
		}
		const DictRef normalized_town = state.new_dict();
		state.set(normalized_town, str(key::placement_id), str(text(state, town, key::placement_id, key::empty)));
		state.set(normalized_town, str(key::town_id), str(text(state, town, key::town_id, key::empty)));
		state.set(normalized_town, str(key::x), int_value(gd::int_field(state, town, key::x, 0)));
		state.set(normalized_town, str(key::y), int_value(gd::int_field(state, town, key::y, 0)));
		state.set(normalized_town, str(key::owner), str(text(state, town, key::owner, key::neutral)));
		state.set(normalized_town, str(key::controlling_faction_id), str(text(state, town, key::controlling_faction_id, key::empty)));
		state.set(normalized_town, str(key::built_buildings), array_value(gd::deep_duplicate_array(state, built_buildings.ref)));
		state.set(normalized_town, str(key::available_recruits), dict_value(_normalize_resource_dict(state, get_or_new_dict(state, town, key::available_recruits))));
		// town.get("garrison", []).duplicate(true) if it is an Array, else [].
		Value garrison;
		const bool has_garrison_array = state.lookup(town, str(key::garrison), garrison) && gd::is_array(garrison);
		state.set(normalized_town, str(key::garrison), array_value(has_garrison_array ? gd::deep_duplicate_array(state, garrison.ref) : state.new_array()));
		state.set(normalized_town, str(key::recovery), dict_value(_normalize_town_recovery_state(state, get_or_new_dict(state, town, key::recovery))));
		state.set(normalized_town, str(key::front), dict_value(_normalize_town_front_state(state, get_or_new_dict(state, town, key::front))));
		state.set(normalized_town, str(key::occupation), dict_value(_normalize_town_occupation_state(state, get_or_new_dict(state, town, key::occupation))));
		state.set(normalized_town, str(key::last_build_day), int_value(count_field(state, town, key::last_build_day)));
		state.set(normalized_town, str(key::market_usage), dict_value(_normalize_town_market_usage_state(state, get_or_new_dict(state, town, key::market_usage), current_day)));
		_copy_town_runtime_metadata(state, normalized_town, town);
		town_development_rules::migrate_town(state, normalized_town);
		state.set(normalized_town, str(key::built_buildings), array_value(_normalize_built_buildings_for_town_state(state, normalized_town)));
		Value recruits;
		if (!state.lookup(town, str(key::available_recruits), recruits) || !gd::is_dict(recruits)) {
			state.set(normalized_town, str(key::available_recruits), dict_value(_seed_recruits_for_town(state, normalized_town)));
		}
		state.append(normalized, dict_value(normalized_town));
	}
	return normalized;
}

void _copy_town_runtime_metadata(State &state, DictRef target, DictRef source) {
	for (const Atom field : kTownRuntimeMetadataKeys) {
		Value value;
		if (state.lookup(source, str(field), value)) {
			state.set(target, str(field), value.is_container() ? gd::duplicate_value(state, value, true) : value);
		}
	}
}

DictRef _normalize_town_recovery_state(State &state, const Value &value) {
	const bool is_dict = gd::is_dict(value);
	const DictRef normalized = state.new_dict();
	state.set(normalized, str(key::pressure), int_value(is_dict ? count_field(state, value.ref, key::pressure) : 0));
	state.set(normalized, str(key::last_event_day), int_value(is_dict ? count_field(state, value.ref, key::last_event_day) : 0));
	state.set(normalized, str(key::source), str(is_dict ? text(state, value.ref, key::source, key::empty) : key::empty));
	return normalized;
}

DictRef _normalize_town_front_state(State &state, const Value &value) {
	const bool is_dict = gd::is_dict(value);
	const auto day_field = [&](Atom field) {
		return int_value(is_dict ? count_field(state, value.ref, field) : 0);
	};
	const auto text_field = [&](Atom field) {
		return str(is_dict ? text(state, value.ref, field, key::empty) : key::empty);
	};
	const DictRef normalized = state.new_dict();
	state.set(normalized, str(key::state), text_field(key::state));
	state.set(normalized, str(key::faction_id), text_field(key::faction_id));
	state.set(normalized, str(key::last_change_day), day_field(key::last_change_day));
	state.set(normalized, str(key::stabilize_until_day), day_field(key::stabilize_until_day));
	state.set(normalized, str(key::defense_until_day), day_field(key::defense_until_day));
	state.set(normalized, str(key::last_defended_day), day_field(key::last_defended_day));
	state.set(normalized, str(key::last_owner), text_field(key::last_owner));
	state.set(normalized, str(key::capture_count), day_field(key::capture_count));
	state.set(normalized, str(key::source), text_field(key::source));

	if (is_dict && text(state, value.ref, key::player_id, key::empty) != key::empty) {
		// String(value.player_id).
		state.set(normalized, str(key::player_id), str(gd::stringify_or_fallback(state, gd::index(state, value.ref, str(key::player_id)))));
	}
	return normalized;
}

void _normalize_active_town_visit_context(State &state, DictRef session) {
	const DictRef flags = session_flags(state, session);
	const Atom placement_id = text(state, flags, key::active_town_placement_id, key::empty);
	if (placement_id == key::empty) {
		return;
	}
	const DictRef found = _find_town_by_placement(state, session, placement_id);
	// var town: Dictionary = town_result.get("town", {})
	const DictRef town = gd::as_dict(get_or_new_dict(state, found, key::town));
	if (gd::int_field(state, found, key::index, -1) < 0 || text(state, town, key::owner, key::neutral) != key::player) {
		state.erase(flags, str(key::active_town_placement_id));
	}
}

// Not in the group's list: Phase 3 ported it in an anonymous namespace
// (overworld_rules_ai_sites.cpp, find_town_by_placement), so it is defined here
// under its GDScript name. A session is never null here.
DictRef _find_town_by_placement(State &state, DictRef session, Atom placement_id) {
	if (placement_id == key::empty) {
		return no_town(state);
	}
	const Value towns = get_or_new_array(state, session_view::overworld(state, session), key::towns);
	const Atom session_id = gd::stringify_or_fallback(state, gd::field(state, session, key::session_id));
	const DictRef flags = session_flags(state, session);
	if (text(state, flags, key::active_town_placement_id, key::empty) == placement_id && state.has(active_town_visit_indexes(state), str(session_id))) {
		const int64_t direct_index = gd::to_int(state, state.get(active_town_visit_indexes(state), str(session_id), int_value(-1)));
		if (gd::is_array(towns) && direct_index >= 0 && direct_index < state.array_size(towns.ref)) {
			const Value direct_town = state.at(towns.ref, direct_index);
			if (gd::is_dict(direct_town) && text(state, direct_town.ref, key::placement_id, key::empty) == placement_id) {
				count_pathing(state, key::town_placement_lookup_direct_index_count);
				return town_result(state, direct_index, direct_town);
			}
		}
	}
	const DictRef lookup_index = _spatial_lookup_index(state, session, -1);
	// var town_by_placement: Dictionary = lookup_index.get("town_by_placement", {}), {} unless a Dictionary.
	Value town_by_placement;
	if (state.lookup(lookup_index, str(key::town_by_placement), town_by_placement) && gd::is_dict(town_by_placement) &&
			state.has(town_by_placement.ref, str(placement_id))) {
		const int64_t placement_index = gd::to_int(state, state.get(town_by_placement.ref, str(placement_id), int_value(-1)));
		if (gd::is_array(towns) && placement_index >= 0 && placement_index < state.array_size(towns.ref)) {
			const Value indexed_town = state.at(towns.ref, placement_index);
			if (gd::is_dict(indexed_town) && text(state, indexed_town.ref, key::placement_id, key::empty) == placement_id) {
				count_pathing(state, key::town_placement_lookup_spatial_index_count);
				return town_result(state, placement_index, indexed_town);
			}
		}
	}
	count_pathing(state, key::town_placement_lookup_full_scan_count);
	// for index in range(towns.size()): towns[index]
	const int64_t count = ai::vsize(state, towns);
	for (int64_t index = 0; index < count; ++index) {
		const Value town = ai::vindex(state, towns, int_value(index));
		if (gd::is_dict(town) && text(state, town.ref, key::placement_id, key::empty) == placement_id) {
			if (text(state, flags, key::active_town_placement_id, key::empty) == placement_id) {
				state.set(active_town_visit_indexes(state), str(session_id), int_value(index));
			}
			return town_result(state, index, town);
		}
	}
	return no_town(state);
}

} // namespace overworld_rules

// TownDevelopmentRules.

namespace town_development_rules {

void migrate_town(State &state, DictRef town) {
	if (!is_current(state, town)) {
		return;
	}
	if (gd::int_field(state, town, key::development_version, 0) != 1) {
		// town.get("built_buildings", []).duplicate(true)
		Value built;
		Value legacy;
		if (!state.lookup(town, str(key::built_buildings), built)) {
			legacy = array_value(state.new_array());
		} else if (built.is_container()) {
			legacy = gd::duplicate_value(state, built, true);
		} else {
			not_ported("TownDevelopmentRules.migrate_town of built_buildings that is no Array or Dictionary (duplicate)");
		}
		state.set(town, str(key::legacy_built_buildings), legacy);
		state.set(town, str(key::development_version), int_value(1));
	}
	state.set(town, str(key::built_buildings), array_value(active_buildings(state, town)));
	convert_reserves(state, town);
}

void convert_reserves(State &state, DictRef town) {
	// var pool: Dictionary = town.get("available_recruits", {}).duplicate(true)
	Value recruits;
	DictRef pool = 0;
	if (!state.lookup(town, str(key::available_recruits), recruits)) {
		pool = state.new_dict();
	} else if (gd::is_dict(recruits)) {
		pool = gd::deep_duplicate_dict(state, recruits.ref);
	} else {
		not_ported("TownDevelopmentRules.convert_reserves of available_recruits that is no Dictionary");
	}
	for (const Value &id : gd::field_items(state, town, str(key::built_buildings))) {
		const DictRef building = gd::content_row(state, ContentTable::Building, gd::stringify_or_fallback(state, id));
		const Atom unit_id = text(state, building, key::unlock_unit_id, key::empty);
		const DictRef unit = gd::content_row(state, ContentTable::Unit, unit_id);
		const Atom base = text(state, unit, key::upgrade_from, key::empty);
		if (base != key::empty && state.has(pool, str(base))) {
			// int(pool.get(unit_id, 0)) + int(pool[base]), left operand first (C++
			// leaves the order of a call's arguments unspecified).
			const int64_t upgraded = gd::int_field(state, pool, unit_id, 0);
			const int64_t reserve = gd::to_int(state, gd::index(state, pool, str(base)));
			state.set(pool, str(unit_id), int_value(gd::add(upgraded, reserve)));
			state.erase(pool, str(base));
		}
	}
	state.set(town, str(key::available_recruits), dict_value(pool));
}

} // namespace town_development_rules

// HeroCommandRules.

namespace hero_command_rules {

void normalize_session(State &state, DictRef session, Atom primary_hero_id, DictRef default_position, DictRef default_army) {
	const DictRef overworld = session_view::overworld(state, session);
	if (!player_identity_rules::has_human_seat(state, session)) {
		// The computer plays every seat: its heroes are map encounters.
		state.set(session, str(key::hero_id), str(key::empty));
		state.set(overworld, str(key::player_heroes), array_value(state.new_array()));
		state.set(overworld, str(key::active_hero_id), str(key::empty));
		_sync_active_hero_mirror(state, session);
		return;
	}

	// ContentService.get_scenario_readonly(session.scenario_id).
	const DictRef scenario = gd::content_row(state, ContentTable::Scenario, gd::stringify_or_fallback(state, gd::field(state, session, key::scenario_id)));
	Atom resolved_primary_id = gd::stringify_or_fallback(state, gd::field(state, session, key::hero_id));
	const DictRef flags = session_flags(state, session);
	// var fallen: Array = session.flags.get(PRIMARY_FALLEN_FLAG, []), [] unless an Array.
	Value fallen_value;
	const ArrayRef fallen = state.lookup(flags, str(key::primary_hero_fallen), fallen_value) && gd::is_array(fallen_value) ? fallen_value.ref : state.new_array();
	if (resolved_primary_id == key::empty && state.array_size(fallen) == 0) {
		resolved_primary_id = primary_hero_id != key::empty ? primary_hero_id : text(state, scenario, key::hero_id, key::empty);
	}
	state.set(session, str(key::hero_id), str(resolved_primary_id));

	const Value legacy_hero = get_or_new_dict(state, overworld, key::hero);
	const Atom legacy_hero_id = gd::is_dict(legacy_hero) ? text(state, legacy_hero.ref, key::id, resolved_primary_id) : resolved_primary_id;
	DictRef legacy_position = 0;
	if (!gd::is_empty(state, default_position)) {
		legacy_position = _normalize_position(state, dict_value(default_position));
	} else {
		// session.overworld.get("hero_position", scenario.get("start", {"x": 0, "y": 0}))
		const DictRef start_fallback = state.new_dict();
		state.set(start_fallback, str(key::x), int_value(0));
		state.set(start_fallback, str(key::y), int_value(0));
		const Value start = state.get(scenario, str(key::start), dict_value(start_fallback));
		legacy_position = _normalize_position(state, state.get(overworld, str(key::hero_position), start));
	}
	const DictRef legacy_army = !gd::is_empty(state, default_army) ? default_army : _normalize_army(state, get_or_new_dict(state, overworld, key::army), legacy_hero_id);
	const Value legacy_movement = get_or_new_dict(state, overworld, key::movement);

	const ArrayRef normalized_heroes = state.new_array();
	// seen: the hero ids already in normalized_heroes.
	std::vector<Atom> seen;
	const auto has_seen = [&](Atom hero_id) {
		for (const Atom id : seen) {
			if (id == hero_id) {
				return true;
			}
		}
		return false;
	};
	const Value raw_player_heroes = get_or_new_array(state, overworld, key::player_heroes);
	if (gd::is_array(raw_player_heroes)) {
		for (const Value &hero_entry : gd::items(state, raw_player_heroes)) {
			if (!gd::is_dict(hero_entry)) {
				continue;
			}
			const Atom hero_id = text(state, hero_entry.ref, key::id, key::empty);
			if (hero_id == key::empty || has_seen(hero_id)) {
				continue;
			}
			const bool is_legacy = hero_id == legacy_hero_id;
			const DictRef fallback_position = is_legacy ? legacy_position : state.new_dict();
			const DictRef fallback_army = is_legacy ? legacy_army : state.new_dict();
			const Value fallback_movement = is_legacy ? legacy_movement : dict_value(state.new_dict());
			const DictRef hero = _normalize_player_hero(state, hero_entry.ref, session, fallback_position, fallback_army, fallback_movement);
			if (gd::is_empty(state, hero)) {
				continue;
			}
			state.append(normalized_heroes, dict_value(hero));
			seen.push_back(hero_id);
		}
	}

	if (gd::is_dict(legacy_hero) && !gd::is_empty(state, legacy_hero.ref)) {
		const DictRef normalized_legacy = _normalize_player_hero(state, legacy_hero.ref, session, legacy_position, legacy_army, legacy_movement);
		if (!gd::is_empty(state, normalized_legacy)) {
			if (has_seen(legacy_hero_id)) {
				_replace_hero_in_array(state, normalized_heroes, normalized_legacy);
			} else {
				state.append(normalized_heroes, dict_value(normalized_legacy));
				seen.push_back(legacy_hero_id);
			}
		}
	}

	if (resolved_primary_id != key::empty && !has_seen(resolved_primary_id)) {
		// ContentService.get_hero(resolved_primary_id) and build_hero_from_template(...).
		not_ported("HeroCommandRules.build_hero_from_template (a human primary hero missing from the roster)");
	}

	if (resolved_primary_id == key::empty && state.array_size(normalized_heroes) > 0) {
		// A fallen leader still in the list (it is being removed) does not lead.
		for (const Value &candidate : gd::items(state, array_value(normalized_heroes))) {
			const Atom candidate_id = text(state, candidate.ref, key::id, key::empty);
			if (!gd::array_has(state, fallen, str(candidate_id))) {
				resolved_primary_id = candidate_id;
				break;
			}
		}
		state.set(session, str(key::hero_id), str(resolved_primary_id));
	}

	const int64_t hero_count = state.array_size(normalized_heroes);
	for (int64_t index = 0; index < hero_count; ++index) {
		const Value hero = state.at(normalized_heroes, index);
		const DictRef hero_dict = gd::as_dict(hero);
		state.set(hero_dict, str(key::is_primary), bool_value(text(state, hero_dict, key::id, key::empty) == resolved_primary_id));
		if (text(state, overworld, key::active_player_id, key::empty) != key::empty) {
			// String(session.overworld.active_player_id).
			state.set(hero_dict, str(key::player_id), str(gd::stringify_or_fallback(state, gd::index(state, overworld, str(key::active_player_id)))));
		}
		state.set_at(normalized_heroes, index, hero);
	}

	state.set(overworld, str(key::player_heroes), array_value(normalized_heroes));
	Atom active_hero_id = text(state, overworld, key::active_hero_id, legacy_hero_id);
	if (active_hero_id == key::empty || _hero_index_by_id(state, normalized_heroes, active_hero_id) < 0) {
		active_hero_id = resolved_primary_id;
	}
	if (active_hero_id == key::empty && state.array_size(normalized_heroes) > 0) {
		active_hero_id = text(state, gd::as_dict(state.at(normalized_heroes, 0)), key::id, key::empty);
	}
	state.set(overworld, str(key::active_hero_id), str(active_hero_id));
	_sync_active_hero_mirror(state, session);
	_normalize_town_garrison_heroes(state, session);
}

// Clears garrison heroes that left, lost their town or no longer exist, and
// once per save gives towns holding two of the player's heroes a garrison hero.
void _normalize_town_garrison_heroes(State &state, DictRef session) {
	const DictRef overworld = session_view::overworld(state, session);
	const bool migrate = gd::int_field(state, overworld, key::town_garrison_heroes_version, 0) < kTownGarrisonHeroesVersion;
	for (const Value &town_value : gd::field_items(state, overworld, str(key::towns))) {
		if (!gd::is_dict(town_value)) {
			continue;
		}
		const DictRef town = town_value.ref;
		const Atom hero_id = text(state, town, key::garrison_hero_id, key::empty);
		if (hero_id != key::empty) {
			if (text(state, town, key::owner, key::neutral) != key::player || gd::is_empty(state, town_garrison_hero(state, session, town))) {
				state.erase(town, str(key::garrison_hero_id));
			}
			continue;
		}
		if (!migrate || text(state, town, key::owner, key::neutral) != key::player) {
			continue;
		}
		const ArrayRef stationed = stationed_heroes(state, session, town);
		if (state.array_size(stationed) < 2) {
			continue;
		}
		// The candidate loop merges the garrison into a hero's army.
		not_ported("HeroCommandRules._normalize_town_garrison_heroes migration (merge_stacks_into_army, _holder_stacks, _set_holder_stacks)");
	}
	state.set(overworld, str(key::town_garrison_heroes_version), int_value(kTownGarrisonHeroesVersion));
}

void _replace_hero_in_array(State &state, ArrayRef player_heroes, DictRef replacement) {
	const Atom replacement_id = text(state, replacement, key::id, key::empty);
	const int64_t count = state.array_size(player_heroes);
	for (int64_t index = 0; index < count; ++index) {
		const Value hero = state.at(player_heroes, index);
		if (gd::is_dict(hero) && text(state, hero.ref, key::id, key::empty) == replacement_id) {
			state.set_at(player_heroes, index, dict_value(replacement));
			return;
		}
	}
}

} // namespace hero_command_rules

// PlayerIdentityRules.

namespace player_identity_rules {

// Whether a person plays this session. A session whose every seat was handed
// to the computer (AiSeatRules) has none, and so no human heroes.
bool has_human_seat(State &state, DictRef session) {
	Value players;
	// session.overworld.get("players", []): a missing list is empty.
	if (!state.lookup(session_view::overworld(state, session), str(key::players), players)) {
		return true;
	}
	if (!gd::is_array(players) || state.array_size(players.ref) == 0) {
		return true;
	}
	for (const Value &record : gd::items(state, players)) {
		if (gd::is_dict(record) && gd::bool_field(state, record.ref, key::human, false)) {
			return true;
		}
	}
	return false;
}

void normalize_compatibility(State &state, DictRef session) {
	const DictRef overworld = session_view::overworld(state, session);
	// not session.overworld.get("players", []).is_empty(): a missing list is empty.
	Value players;
	if (state.lookup(overworld, str(key::players), players) && !ai::vempty(state, players)) {
		return;
	}
	if (gd::bool_field(state, session_flags(state, session), key::generated_random_map, false)) {
		// Pre-player-identity saves already pooled same-faction controllers.
		state.set(overworld, str(key::player_identity_version), int_value(0));
		state.set(overworld, str(key::player_identity_mode), str(key::legacy_generated_faction_v0));
	}
}

} // namespace player_identity_rules

// DifficultyRules.

namespace difficulty_rules {

DictRef normalize_session(State &state, DictRef session) {
	state.set(session, str(key::difficulty), str(normalize_difficulty(state, gd::field(state, session, key::difficulty))));
	return profile_for_session(state, dict_value(session));
}

} // namespace difficulty_rules

// SessionStateStore.

namespace session_state_store {

Atom normalize_launch_mode(State &state, const Value &value) {
	const Atom launch_mode = gd::stringify_or_fallback(state, value);
	// SUPPORTED_LAUNCH_MODES: campaign, skirmish, generated_draft.
	if (launch_mode == key::campaign || launch_mode == key::skirmish || launch_mode == key::generated_draft) {
		return launch_mode;
	}
	return key::campaign;
}

} // namespace session_state_store

} // namespace aurelion::rules::port
