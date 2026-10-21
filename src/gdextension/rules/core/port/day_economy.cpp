// The day's economy (Phase 5 slice 02, group "economy"): the opening half of
// OverworldRules.end_turn, _end_turn_open_day (the normalize and hero commit
// before the day moves on, then town occupation and recovery, town, hero and
// field-site income, weekly musters, the treasury, the heroes' new day and the
// player's reserve deliveries), with what it runs, and DifficultyRules' income
// scaling.
//
// The paths whose callees no port has yet throw state::NotPorted where they
// start, so the GDScript body runs instead; AI matches reach none of them (no
// town, hero or site belongs to "player" there):
// - a player town's weekly growth (OverworldRules._growth_tick_town);
// - a player convoy that reaches its arrival day
//   (OverworldRules._resource_site_delivery_interception, _delivery_army_admission,
//   _resolve_player_reserve_delivery, _queue_followup_reserve_delivery);
// - the debug rules profile recording (OverworldRules._movement_rules_profile_active);
// - towns or resource nodes held in something other than an Array, and
//   x.duplicate(true) or String(x) of a value that is not a container or a text.
//
// Not in the group's list, ported here under their GDScript names because no
// port has them in a named namespace: OverworldRules._add_recruit_growth
// (overworld_forecast.cpp has an anonymous copy), _clear_resource_site_delivery,
// _find_encounter_by_placement (overworld_rules_ai_sites.cpp has an anonymous
// copy), SpellRules.refresh_daily_mana and HeroProgressionRules.daily_income_bonus.
// OverworldRules._movement_max_from_hero is inlined: it is
// HeroCommandRules.movement_max_for_hero(hero, session).

#include "aurelion_rules/port/overworld_rules.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/artifact_rules.hpp"
#include "aurelion_rules/port/creature_dwelling_rules_ai.hpp"
#include "aurelion_rules/port/difficulty_rules.hpp"
#include "aurelion_rules/port/difficulty_rules_ai.hpp"
#include "aurelion_rules/port/enemy_states.hpp"
#include "aurelion_rules/port/hero_command_rules_ai.hpp"
#include "aurelion_rules/port/hero_commit.hpp"
#include "aurelion_rules/port/hero_progression_rules.hpp"
#include "aurelion_rules/port/overworld_level_rules.hpp"
#include "aurelion_rules/port/overworld_rules_ai.hpp"
#include "aurelion_rules/port/player_identity_rules_ai.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/spell_rules.hpp"
#include "aurelion_rules/port/visit_building_rules_ai.hpp"

#include "aurelion_rules/compat/godot_math.hpp"

#include <algorithm>
#include <cstdint>
#include <iterator>
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

[[noreturn]] void not_ported(const std::string &what) {
	throw state::NotPorted("left to GDScript: " + what);
}

// OverworldRules.WEEKLY_GROWTH_INTERVAL.
constexpr int64_t kWeeklyGrowthInterval = 7;

// OverworldRules.LIVE_STOCKPILE_RESOURCE_KEYS, in order.
constexpr Atom kLiveStockpileKeys[] = {
	key::gold,
	key::wood,
	key::ore,
	key::aetherglass,
	key::embergrain,
	key::peatwax,
	key::verdant_grafts,
	key::brass_scrip,
	key::memory_salt,
};

// String(d.get(key, fallback)).
Atom text(State &state, DictRef dict, Atom field, Atom fallback) {
	return gd::stringify_or_fallback(state, state.get(dict, str(field), str(fallback)));
}

// d.get(key, {}): the field as it is, or a new Dictionary when it is missing.
Value field_or_new_dict(State &state, DictRef dict, Atom field) {
	Value found;
	return state.lookup(dict, str(field), found) ? found : dict_value(state.new_dict());
}

// d.get(key, []): the field as it is, or a new Array when it is missing.
Value field_or_new_array(State &state, DictRef dict, Atom field) {
	Value found;
	return state.lookup(dict, str(field), found) ? found : array_value(state.new_array());
}

// var items = d.get(key, []) where the code then indexes it
// (range(items.size()), items[index] = ...): an Array, a new one when the key
// is missing. Anything else is left to GDScript.
ArrayRef indexed_array_field(State &state, DictRef dict, Atom field, const char *what) {
	Value found;
	if (!state.lookup(dict, str(field), found)) {
		return state.new_array();
	}
	if (!gd::is_array(found)) {
		not_ported(std::string(what) + " that are not an Array");
	}
	return found.ref;
}

// d.get(key, {}).duplicate(true): a deep copy of the field's container.
Value deep_duplicate_field(State &state, DictRef dict, Atom field) {
	const Value value = field_or_new_dict(state, dict, field);
	if (gd::is_dict(value)) {
		return dict_value(gd::deep_duplicate_dict(state, value.ref));
	}
	if (gd::is_array(value)) {
		return array_value(gd::deep_duplicate_array(state, value.ref));
	}
	not_ported("x.duplicate(true) of a value that is not an Array or a Dictionary");
}

// session.day.
int64_t session_day(State &state, DictRef session) {
	return gd::to_int(state, gd::index(state, session, str(key::day)));
}

// separator.join(parts) of Strings a function keeps to itself.
Atom join_atoms(State &state, Atom separator, const std::vector<Atom> &parts) {
	std::string joined;
	for (size_t index = 0; index < parts.size(); ++index) {
		if (index > 0) {
			joined += state.text(separator);
		}
		joined += state.text(parts[index]);
	}
	return state.intern(joined);
}

// separator.join(values) of an Array: the Array becomes a PackedStringArray,
// each item as String() converts it.
Atom join_array(State &state, Atom separator, ArrayRef values) {
	std::string joined;
	const int64_t size = state.array_size(values);
	for (int64_t index = 0; index < size; ++index) {
		if (index > 0) {
			joined += state.text(separator);
		}
		joined += state.text(gd::stringify_or_fallback(state, state.at(values, index)));
	}
	return state.intern(joined);
}

// {"index": index, "encounter": encounter}.
DictRef encounter_result(State &state, int64_t index, const Value &encounter) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::index), int_value(index));
	state.set(result, str(key::encounter), encounter);
	return result;
}

// The keys _resource_keys_for_payload(value) lists, in its order: the live
// stockpile's, then value's other keys (not "experience" or ""), each once.
void resource_keys(State &state, const Value &value, std::vector<Atom> &keys) {
	keys.assign(std::begin(kLiveStockpileKeys), std::end(kLiveStockpileKeys));
	if (!gd::is_dict(value)) {
		return;
	}
	for (const Value &key_value : gd::items(state, value)) {
		const Atom resource_key = gd::stringify_or_fallback(state, key_value);
		if (resource_key == key::experience || resource_key == key::empty) {
			continue;
		}
		// `resource_key not in keys`: every item is a String, so the same text is the same atom.
		if (std::find(keys.begin(), keys.end(), resource_key) == keys.end()) {
			keys.push_back(resource_key);
		}
	}
}

} // namespace

// OverworldRules.

namespace overworld_rules {

DictRef _end_turn_open_day(State &state, DictRef session) {
	// _rules_profile_*: recorded only while the debug capture is on.
	if (gd::truthy(state, gd::static_var(state, key::overworld_rules_script, key::_movement_rules_profile_active))) {
		not_ported("the rules profile is recording");
	}
	if (!(gd::to_bool(ai::meta_get(state, session, key::_overworld_session_untouched_between_days, bool_value(false))) &&
				gd::to_int(state, ai::meta_get(state, session, key::_overworld_end_turn_closing_normalize_day, int_value(-1))) == session_day(state, session))) {
		normalize_overworld_state(state, session);
	}
	hero_command_rules::commit_active_hero(state, session);
	state.set(session, str(key::day), int_value(gd::add(session_day(state, session), 1)));

	const ArrayRef occupation_messages = _advance_all_town_occupations(state, session);
	const ArrayRef recovery_messages = _advance_all_town_recovery(state, session);
	DictRef town_income = _empty_live_resource_stockpile(state);
	const ArrayRef weekly_growth_messages = state.new_array();
	const bool should_apply_weekly_growth = is_weekly_growth_day(state, session_day(state, session));
	const ArrayRef towns = indexed_array_field(state, session_view::overworld(state, session), key::towns, "towns");
	const int64_t town_count = state.array_size(towns);
	for (int64_t index = 0; index < town_count; ++index) {
		const Value town = state.at(towns, index);
		if (!gd::is_dict(town) || text(state, town.ref, key::owner, key::neutral) != key::player) {
			continue;
		}
		const DictRef town_base_income = _calculate_town_income(state, town.ref, dict_value(session));
		const DictRef income = difficulty_rules::scale_income_resources(state, session, dict_value(town_base_income));
		town_income = _add_resource_sets(state, dict_value(town_income), dict_value(income));
		if (should_apply_weekly_growth) {
			not_ported("OverworldRules._growth_tick_town (a player town's weekly growth)");
		}
		state.set_at(towns, index, town);
	}
	state.set(session_view::overworld(state, session), str(key::towns), array_value(towns));

	const DictRef hero_income = _player_heroes_daily_income(state, session);
	const DictRef artifact_income = gd::as_dict(field_or_new_dict(state, hero_income, key::artifact));
	const DictRef specialty_income = gd::as_dict(field_or_new_dict(state, hero_income, key::specialty));
	const DictRef site_base_income = controlled_resource_site_income(state, session, key::player, -1);
	const DictRef site_income = difficulty_rules::scale_income_resources(state, session, dict_value(site_base_income));
	const DictRef town_and_artifact_income = _add_resource_sets(state, dict_value(town_income), dict_value(artifact_income));
	const DictRef hero_total_income = _add_resource_sets(state, dict_value(town_and_artifact_income), dict_value(specialty_income));
	const DictRef total_income = _add_resource_sets(state, dict_value(hero_total_income), dict_value(site_income));
	ArrayRef site_muster_messages = state.new_array();
	if (should_apply_weekly_growth) {
		site_muster_messages = apply_controlled_resource_site_musters(state, session, key::player);
	}
	_add_resources(state, session, dict_value(total_income));
	_refresh_all_player_heroes_for_new_day(state, session);
	// var hero_state = session.overworld.get("hero", {}): read and never used.
	const Value movement_after = field_or_new_dict(state, session_view::overworld(state, session), key::movement);

	const ArrayRef messages = state.new_array();
	state.append(messages, str(gd::format(state, key::day_d_begins_, {int_value(session_day(state, session))})));
	const Atom town_income_summary = _describe_resource_delta(state, dict_value(town_income));
	if (town_income_summary != key::empty) {
		state.append(messages, str(gd::format(state, key::town_income_s_, {str(town_income_summary)})));
	}
	if (state.array_size(occupation_messages) > 0) {
		state.append(messages, str(gd::format(state, key::occupation_lines_s_, {str(join_array(state, key::semicolon_space, occupation_messages))})));
	}
	if (state.array_size(recovery_messages) > 0) {
		state.append(messages, str(gd::format(state, key::recovery_lines_s_, {str(join_array(state, key::semicolon_space, recovery_messages))})));
	}
	if (state.array_size(weekly_growth_messages) > 0) {
		state.append(messages, str(gd::format(state, key::weekly_musters_s_, {str(join_array(state, key::semicolon_space, weekly_growth_messages))})));
	}
	const Atom artifact_income_summary = _describe_resource_delta(state, dict_value(artifact_income));
	if (artifact_income_summary != key::empty) {
		state.append(messages, str(gd::format(state, key::artifact_income_s_, {str(artifact_income_summary)})));
	}
	const Atom specialty_income_summary = _describe_resource_delta(state, dict_value(specialty_income));
	if (specialty_income_summary != key::empty) {
		state.append(messages, str(gd::format(state, key::specialty_income_s_, {str(specialty_income_summary)})));
	}
	const Atom site_income_summary = _describe_resource_delta(state, dict_value(site_income));
	if (site_income_summary != key::empty) {
		state.append(messages, str(gd::format(state, key::field_sites_yield_s_, {str(site_income_summary)})));
	}
	if (state.array_size(site_muster_messages) > 0) {
		state.append(messages, str(gd::format(state, key::outlying_musters_s_, {str(join_array(state, key::semicolon_space, site_muster_messages))})));
	}
	const ArrayRef delivery_messages = _advance_player_reserve_deliveries(state, session);
	if (state.array_size(delivery_messages) > 0) {
		state.append(messages, str(gd::format(state, key::reserve_deliveries_s_, {str(join_array(state, key::semicolon_space, delivery_messages))})));
	}

	// The very containers end_turn's second half reads, not copies.
	const DictRef opened = state.new_dict();
	state.set(opened, str(key::messages), array_value(messages));
	state.set(opened, str(key::occupation_messages), array_value(occupation_messages));
	state.set(opened, str(key::recovery_messages), array_value(recovery_messages));
	state.set(opened, str(key::weekly_growth_messages), array_value(weekly_growth_messages));
	state.set(opened, str(key::site_muster_messages), array_value(site_muster_messages));
	state.set(opened, str(key::delivery_messages), array_value(delivery_messages));
	state.set(opened, str(key::total_income), dict_value(total_income));
	state.set(opened, str(key::movement_after), movement_after);
	return opened;
}

ArrayRef _advance_all_town_occupations(State &state, DictRef session) {
	const ArrayRef messages = state.new_array();
	const ArrayRef towns = indexed_array_field(state, session_view::overworld(state, session), key::towns, "towns");
	const int64_t count = state.array_size(towns);
	for (int64_t index = 0; index < count; ++index) {
		Value town = state.at(towns, index);
		if (!gd::is_dict(town)) {
			continue;
		}
		const DictRef result = _advance_town_occupation(state, session, town.ref);
		town = state.get(result, str(key::town), town);
		state.set_at(towns, index, town);
		const Atom message = text(state, result, key::message, key::empty);
		if (message != key::empty) {
			state.append(messages, str(message));
		}
	}
	state.set(session_view::overworld(state, session), str(key::towns), array_value(towns));
	return messages;
}

ArrayRef _advance_all_town_recovery(State &state, DictRef session) {
	const ArrayRef messages = state.new_array();
	const ArrayRef towns = indexed_array_field(state, session_view::overworld(state, session), key::towns, "towns");
	const int64_t count = state.array_size(towns);
	for (int64_t index = 0; index < count; ++index) {
		Value town = state.at(towns, index);
		if (!gd::is_dict(town)) {
			continue;
		}
		const DictRef result = _advance_town_recovery(state, session, town.ref);
		town = state.get(result, str(key::town), town);
		state.set_at(towns, index, town);
		const Atom message = text(state, result, key::message, key::empty);
		if (message != key::empty) {
			state.append(messages, str(message));
		}
	}
	state.set(session_view::overworld(state, session), str(key::towns), array_value(towns));
	return messages;
}

bool is_weekly_growth_day(State &state, int64_t day) {
	(void)state;
	return day > 1 && compat::int_mod(gd::sub(day, 1), kWeeklyGrowthInterval) == 0;
}

DictRef _player_heroes_daily_income(State &state, DictRef session) {
	// Every commander's artifacts and specialties earn income, whichever is selected.
	DictRef artifact_income = state.new_dict();
	DictRef specialty_income = state.new_dict();
	const ArrayRef heroes = _player_hero_states(state, session);
	for (const Value &hero_value : gd::items(state, array_value(heroes))) {
		const DictRef hero = gd::as_dict(hero_value);
		const DictRef artifact_bonuses = artifact_rules::aggregate_bonuses(state, hero);
		artifact_income = _add_resource_sets(state, dict_value(artifact_income), field_or_new_dict(state, artifact_bonuses, key::daily_income));
		const DictRef specialty_bonus = hero_progression_rules::daily_income_bonus(state, hero);
		specialty_income = _add_resource_sets(state, dict_value(specialty_income), dict_value(specialty_bonus));
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::artifact), dict_value(difficulty_rules::scale_income_resources(state, session, dict_value(artifact_income))));
	state.set(result, str(key::specialty), dict_value(specialty_income));
	return result;
}

ArrayRef _player_hero_states(State &state, DictRef session) {
	// session == null cannot happen: a session is its view.
	const ArrayRef heroes = state.new_array();
	const DictRef overworld = session_view::overworld(state, session);
	Atom active_id = key::empty;
	// var active = session.overworld.get("hero", {}): a missing hero is an empty Dictionary.
	Value active;
	if (state.lookup(overworld, str(key::hero), active) && gd::is_dict(active) && !gd::is_empty(state, active.ref)) {
		active_id = text(state, active.ref, key::id, key::empty);
		state.append(heroes, active);
	}
	for (const Value &hero : gd::field_items(state, overworld, str(key::player_heroes))) {
		if (gd::is_dict(hero) && (active_id == key::empty || text(state, hero.ref, key::id, key::empty) != active_id)) {
			state.append(heroes, hero);
		}
	}
	return heroes;
}

DictRef controlled_resource_site_income(State &state, DictRef session, Atom controller_id, int64_t income_day) {
	DictRef income = _empty_live_resource_stockpile(state);
	const int64_t resolved_income_day = income_day < 0 ? session_day(state, session) : income_day;
	for (const Value &node : gd::field_items(state, session_view::overworld(state, session), str(key::resource_nodes))) {
		// The resource bar asks every refresh: skip unowned sites before the content lookup.
		if (!gd::is_dict(node) || !_resource_node_matches_controller(state, node.ref, controller_id)) {
			continue;
		}
		const DictRef site = gd::content_row(state, ContentTable::ResourceSite, text(state, node.ref, key::site_id, key::empty));
		if (!_resource_site_is_persistent(state, site)) {
			continue;
		}
		const DictRef site_income = _resource_site_control_income_for_day(state, site, resolved_income_day);
		income = _add_resource_sets(state, dict_value(income), dict_value(site_income));
	}
	return income;
}

DictRef _resource_site_control_income_for_day(State &state, DictRef site, int64_t day) {
	// site.get("control_income", {}) if it is a Dictionary, else {}: the row's own Dictionary.
	Value income;
	const bool income_is_dict = state.lookup(site, str(key::control_income), income) && gd::is_dict(income);
	// String(site.get("control_income_cadence", "daily")) == "weekly": a missing cadence is daily.
	Value cadence;
	if (state.lookup(site, str(key::control_income_cadence), cadence) && gd::stringify_or_fallback(state, cadence) == key::weekly &&
			!is_weekly_growth_day(state, day)) {
		return state.new_dict();
	}
	return income_is_dict ? income.ref : state.new_dict();
}

bool _resource_node_matches_controller(State &state, DictRef node, Atom controller_id) {
	return player_identity_rules::resource_controller_id(state, node) == controller_id;
}

ArrayRef apply_controlled_resource_site_musters(State &state, DictRef session, Atom controller_id) {
	const ArrayRef messages = state.new_array();
	const ArrayRef towns = indexed_array_field(state, session_view::overworld(state, session), key::towns, "towns");
	for (const Value &node : gd::field_items(state, session_view::overworld(state, session), str(key::resource_nodes))) {
		if (!gd::is_dict(node)) {
			continue;
		}
		const DictRef site = gd::content_row(state, ContentTable::ResourceSite, text(state, node.ref, key::site_id, key::empty));
		const DictRef weekly_recruits = _resource_site_weekly_recruits(state, site);
		if (!_resource_site_is_persistent(state, site) || !_resource_node_matches_controller(state, node.ref, controller_id)) {
			continue;
		}
		// Dwellings are hired at the dwelling; they never feed a town.
		if (creature_dwelling_rules::is_dwelling(state, site)) {
			continue;
		}
		if (gd::is_empty(state, weekly_recruits)) {
			continue;
		}
		const DictRef town_result = _nearest_town_for_controller(state, session, controller_id,
				gd::int_field(state, node.ref, key::x, 0), gd::int_field(state, node.ref, key::y, 0),
				overworld_level_rules::level_of(state, node));
		if (gd::int_field(state, town_result, key::index, -1) < 0) {
			continue;
		}
		const DictRef town = gd::as_dict(field_or_new_dict(state, town_result, key::town));
		const DictRef grown = _add_recruit_growth(state, field_or_new_dict(state, town, key::available_recruits), dict_value(weekly_recruits));
		state.set(town, str(key::available_recruits), dict_value(grown));
		state.set_at(towns, gd::int_field(state, town_result, key::index, -1), dict_value(town));
		const Atom site_name = text(state, site, key::name, key::frontier_site);
		const Atom town_name = _town_name(state, town);
		const Atom recruit_summary = _describe_recruit_delta(state, dict_value(weekly_recruits));
		state.append(messages, str(gd::format(state, key::_s_feeds_s_s_, {str(site_name), str(town_name), str(recruit_summary)})));
	}
	state.set(session_view::overworld(state, session), str(key::towns), array_value(towns));
	return messages;
}

DictRef _resource_site_weekly_recruits(State &state, DictRef site) {
	Value recruits;
	if (state.lookup(site, str(key::weekly_recruits), recruits) && gd::is_dict(recruits) && !gd::is_empty(state, recruits.ref)) {
		return recruits.ref;
	}
	Value roster;
	if (state.lookup(site, str(key::neutral_roster), roster) && gd::is_dict(roster)) {
		// roster.get("weekly_recruits", {}): a missing entry is a new empty Dictionary.
		Value roster_recruits;
		if (!state.lookup(roster.ref, str(key::weekly_recruits), roster_recruits)) {
			return state.new_dict();
		}
		if (gd::is_dict(roster_recruits)) {
			return roster_recruits.ref;
		}
	}
	return state.new_dict();
}

void _add_resources(State &state, DictRef session, const Value &delta) {
	const DictRef resources = _normalize_live_resource_stockpile(state, field_or_new_dict(state, session_view::overworld(state, session), key::resources));
	if (gd::is_dict(delta)) {
		for (const Value &key_value : gd::items(state, delta)) {
			const Atom resource_key = gd::stringify_or_fallback(state, key_value);
			if (resource_key == key::experience) {
				continue;
			}
			const int64_t held = gd::int_field(state, resources, resource_key, 0);
			const int64_t added = gd::to_int(state, gd::index(state, delta.ref, key_value));
			state.set(resources, str(resource_key), int_value(compat::engine_max<int64_t>(0, gd::add(held, added))));
		}
	}
	state.set(session_view::overworld(state, session), str(key::resources), dict_value(resources));
}

void _refresh_all_player_heroes_for_new_day(State &state, DictRef session) {
	const Value heroes_value = field_or_new_array(state, session_view::overworld(state, session), key::player_heroes);
	if (!gd::is_array(heroes_value)) {
		return;
	}
	const ArrayRef heroes = heroes_value.ref;
	const Atom active_hero_id = text(state, session_view::overworld(state, session), key::active_hero_id, key::empty);
	bool synced_active = false;
	const int64_t day = session_day(state, session);
	const bool new_week = visit_building_rules::week_index(state, day) != visit_building_rules::week_index(state, gd::sub(day, 1));
	const int64_t count = state.array_size(heroes);
	for (int64_t index = 0; index < count; ++index) {
		const Value hero_value = state.at(heroes, index);
		if (!gd::is_dict(hero_value)) {
			continue;
		}
		if (new_week) {
			// VisitBuildings.WEEK_BONUSES, erased from the roster entry itself.
			state.erase(hero_value.ref, str(key::week_bonuses));
		}
		const DictRef hero = spell_rules::refresh_daily_mana(state, hero_value.ref);
		const int64_t carry_limit = gd::int_field(state, hero_progression_rules::aggregate_bonuses(state, hero), key::movement_carry, 0);
		// int(hero.get("movement", {}).get("current", 0)) if hero.get("movement", {}) is Dictionary else 0
		int64_t leftover = 0;
		Value movement;
		if (state.lookup(hero, str(key::movement), movement)) {
			if (gd::is_dict(movement)) {
				leftover = gd::int_field(state, movement.ref, key::current, 0);
			}
		}
		state.set(hero, str(key::movement_carry), int_value(compat::engine_clamp<int64_t>(leftover, 0, carry_limit)));
		// _movement_max_from_hero(hero, session).
		const int64_t movement_max = hero_command_rules::movement_max_for_hero(state, hero, dict_value(session));
		const DictRef refreshed_movement = state.new_dict();
		state.set(refreshed_movement, str(key::current), int_value(movement_max));
		state.set(refreshed_movement, str(key::max), int_value(movement_max));
		state.set(hero, str(key::movement), dict_value(refreshed_movement));
		state.set_at(heroes, index, dict_value(hero));
		if (text(state, hero, key::id, key::empty) != active_hero_id) {
			continue;
		}
		synced_active = true;
		const DictRef overworld = session_view::overworld(state, session);
		state.set(overworld, str(key::hero), dict_value(gd::deep_duplicate_dict(state, hero)));
		state.set(overworld, str(key::army), deep_duplicate_field(state, hero, key::army));
		state.set(overworld, str(key::movement), deep_duplicate_field(state, hero, key::movement));
		state.set(overworld, str(key::hero_position), deep_duplicate_field(state, hero, key::position));
	}
	state.set(session_view::overworld(state, session), str(key::player_heroes), array_value(heroes));
	if (synced_active) {
		return;
	}
	const DictRef active_hero = hero_command_rules::active_hero(state, session);
	if (gd::is_empty(state, active_hero)) {
		return;
	}
	const DictRef overworld = session_view::overworld(state, session);
	state.set(overworld, str(key::hero), dict_value(gd::deep_duplicate_dict(state, active_hero)));
	state.set(overworld, str(key::army), deep_duplicate_field(state, active_hero, key::army));
	state.set(overworld, str(key::movement), deep_duplicate_field(state, active_hero, key::movement));
	state.set(overworld, str(key::hero_position), deep_duplicate_field(state, active_hero, key::position));
}

ArrayRef _advance_player_reserve_deliveries(State &state, DictRef session) {
	// session == null cannot happen: a session is its view.
	const ArrayRef messages = state.new_array();
	const ArrayRef nodes = indexed_array_field(state, session_view::overworld(state, session), key::resource_nodes, "resource nodes");
	bool changed = false;
	// _resource_site_delivery_state(session, node): its _site parameter, {} by
	// default, is never read, so one empty Dictionary serves every call.
	const DictRef no_site = state.new_dict();
	const int64_t count = state.array_size(nodes);
	for (int64_t index = 0; index < count; ++index) {
		const Value node = state.at(nodes, index);
		if (!gd::is_dict(node)) {
			continue;
		}
		const DictRef delivery_state = _resource_site_delivery_state(state, session, node.ref, no_site);
		if (text(state, delivery_state, key::controller_id, key::empty) != key::player) {
			continue;
		}
		if (gd::is_empty(state, _normalize_recruit_payload(state, field_or_new_dict(state, delivery_state, key::manifest)))) {
			state.set_at(nodes, index, dict_value(_clear_resource_site_delivery(state, node.ref)));
			changed = true;
			continue;
		}
		if (text(state, node.ref, key::collected_by_faction_id, key::empty) != key::player) {
			state.set_at(nodes, index, dict_value(_clear_resource_site_delivery(state, node.ref)));
			changed = true;
			continue;
		}
		if (session_day(state, session) < gd::int_field(state, delivery_state, key::arrival_day, 0)) {
			continue;
		}
		not_ported("OverworldRules._resource_site_delivery_interception, _delivery_army_admission, "
				   "_resolve_player_reserve_delivery and _queue_followup_reserve_delivery (a player convoy arrives)");
	}
	if (changed) {
		state.set(session_view::overworld(state, session), str(key::resource_nodes), array_value(nodes));
	}
	return messages;
}

Atom _resource_site_delivery_target_label(State &state, DictRef session, Atom target_kind, Atom target_id, Atom fallback_label) {
	// session != null: a session is its view.
	if (target_kind == key::hero) {
		const DictRef hero = hero_command_rules::hero_by_id(state, session, target_id);
		if (!gd::is_empty(state, hero)) {
			return text(state, hero, key::name, target_id);
		}
	} else if (target_kind == key::town) {
		const DictRef town_result = _find_town_by_placement(state, session, target_id);
		if (gd::int_field(state, town_result, key::index, -1) >= 0) {
			return _town_name(state, gd::as_dict(field_or_new_dict(state, town_result, key::town)));
		}
	} else if (target_kind == key::raid) {
		const DictRef found = _find_encounter_by_placement(state, session, target_id);
		if (gd::int_field(state, found, key::index, -1) >= 0) {
			const DictRef encounter = gd::as_dict(field_or_new_dict(state, found, key::encounter));
			const Value placement_fallback = state.get(encounter, str(key::placement_id), str(target_id));
			return gd::stringify_or_fallback(state, state.get(encounter, str(key::target_label), placement_fallback));
		}
	}
	if (fallback_label != key::empty) {
		return fallback_label;
	}
	if (target_kind == key::hero) {
		return key::frontline_hero;
	}
	if (target_kind == key::town) {
		return key::frontline_town;
	}
	if (target_kind == key::raid) {
		return key::enemy_army_2;
	}
	return key::frontline;
}

Atom _describe_recruit_delta(State &state, const Value &delta) {
	if (!gd::is_dict(delta)) {
		return key::empty;
	}
	std::vector<Atom> unit_ids;
	for (const Value &unit_id_value : gd::items(state, delta)) {
		unit_ids.push_back(gd::stringify_or_fallback(state, unit_id_value));
	}
	// unit_ids.sort(): Strings by code point, which is the UTF-8 byte order; equal
	// Strings are the same atom, so the sort's instability shows nowhere.
	std::sort(unit_ids.begin(), unit_ids.end(), [&state](Atom a, Atom b) { return state.text(a) < state.text(b); });
	std::vector<Atom> parts;
	for (const Atom unit_id : unit_ids) {
		const int64_t amount = gd::to_int(state, state.get(delta.ref, str(unit_id), int_value(0)));
		if (amount <= 0) {
			continue;
		}
		const DictRef unit = gd::content_row(state, ContentTable::Unit, unit_id);
		const Atom unit_name = text(state, unit, key::name, unit_id);
		parts.push_back(gd::format(state, key::d_s_2, {int_value(amount), str(unit_name)}));
	}
	return join_atoms(state, key::comma_space, parts);
}

int64_t _weighted_recruit_value(State &state, const Value &recruits) {
	int64_t total = 0;
	if (!gd::is_dict(recruits)) {
		return total;
	}
	for (const Value &unit_id_value : gd::items(state, recruits)) {
		const Atom unit_id = gd::stringify_or_fallback(state, unit_id_value);
		// max(0, int(recruits[unit_id_value])) of ints.
		const int64_t raw_count = gd::to_int(state, gd::index(state, recruits.ref, unit_id_value));
		const int64_t count = 0 < raw_count ? raw_count : 0;
		if (unit_id == key::empty || count <= 0) {
			continue;
		}
		const DictRef unit = gd::content_row(state, ContentTable::Unit, unit_id);
		const int64_t raw_tier = gd::int_field(state, unit, key::tier, 1);
		const int64_t tier = 1 < raw_tier ? raw_tier : 1;
		total = gd::add(total, gd::mul(count, gd::add(4, gd::mul(tier, 3))));
		const int64_t stat_excess = gd::sub(gd::add(gd::int_field(state, unit, key::attack, 0), gd::int_field(state, unit, key::defense, 0)), 6);
		total = gd::add(total, gd::mul(count, 0 < stat_excess ? stat_excess : 0));
		if (gd::bool_field(state, unit, key::ranged, false)) {
			total = gd::add(total, count);
		}
	}
	return total;
}

Atom _describe_resource_delta(State &state, const Value &delta) {
	if (!gd::is_dict(delta)) {
		return key::empty;
	}
	std::vector<Atom> keys;
	resource_keys(state, delta, keys);
	std::vector<Atom> parts;
	for (const Atom resource_key : keys) {
		const int64_t amount = gd::to_int(state, state.get(delta.ref, str(resource_key), int_value(0)));
		if (amount > 0) {
			parts.push_back(gd::format(state, key::_d_s, {int_value(amount), str(resource_key)}));
		}
	}
	return join_atoms(state, key::comma_space, parts);
}

ArrayRef _resource_keys_for_payload(State &state, const Value &value) {
	std::vector<Atom> keys;
	resource_keys(state, value, keys);
	const ArrayRef result = state.new_array();
	for (const Atom resource_key : keys) {
		state.append(result, str(resource_key));
	}
	return result;
}

// Not in the group's list: overworld_forecast.cpp keeps an anonymous copy
// (add_recruit_growth).
DictRef _add_recruit_growth(State &state, const Value &base_recruits, const Value &delta_recruits) {
	const DictRef merged = state.new_dict();
	if (gd::is_dict(base_recruits)) {
		for (const Value &unit_id : gd::items(state, base_recruits)) {
			const Atom id = gd::stringify_or_fallback(state, unit_id);
			const int64_t count = gd::to_int(state, gd::index(state, base_recruits.ref, unit_id));
			state.set(merged, str(id), int_value(0 < count ? count : 0));
		}
	}
	if (gd::is_dict(delta_recruits)) {
		for (const Value &unit_id : gd::items(state, delta_recruits)) {
			const Atom id = gd::stringify_or_fallback(state, unit_id);
			const int64_t held = gd::to_int(state, state.get(merged, str(id), int_value(0)));
			const int64_t delta = gd::to_int(state, gd::index(state, delta_recruits.ref, unit_id));
			state.set(merged, str(id), int_value(gd::add(held, 0 < delta ? delta : 0)));
		}
	}
	return merged;
}

// Not in the group's list: the player's convoy clear-out
// (_advance_player_reserve_deliveries).
DictRef _clear_resource_site_delivery(State &state, DictRef node) {
	const DictRef cleared = gd::deep_duplicate_dict(state, node);
	state.set(cleared, str(key::delivery_controller_id), str(key::empty));
	state.set(cleared, str(key::delivery_origin_town_id), str(key::empty));
	state.set(cleared, str(key::delivery_target_kind), str(key::empty));
	state.set(cleared, str(key::delivery_target_id), str(key::empty));
	state.set(cleared, str(key::delivery_target_label), str(key::empty));
	state.set(cleared, str(key::delivery_arrival_day), int_value(0));
	state.set(cleared, str(key::delivery_manifest), dict_value(state.new_dict()));
	return cleared;
}

// Not in the group's list: overworld_rules_ai_sites.cpp keeps an anonymous copy
// (find_encounter_by_placement). The rules profile calls record nothing: every
// entry that reaches this throws NotPorted first while the profile records.
DictRef _find_encounter_by_placement(State &state, DictRef session, Atom placement_id) {
	// session == null cannot happen: a session is its view.
	if (placement_id == key::empty) {
		return encounter_result(state, -1, dict_value(state.new_dict()));
	}
	const Value encounters = field_or_new_array(state, session_view::overworld(state, session), key::encounters);
	const DictRef lookup_index = _spatial_lookup_index(state, session, -1);
	// var by_placement: Dictionary = lookup_index.get("encounter_by_placement", {}), {} unless a Dictionary.
	Value by_placement;
	if (state.lookup(lookup_index, str(key::encounter_by_placement), by_placement) && gd::is_dict(by_placement) &&
			state.has(by_placement.ref, str(placement_id))) {
		const int64_t indexed = gd::to_int(state, state.get(by_placement.ref, str(placement_id), int_value(-1)));
		if (gd::is_array(encounters) && indexed >= 0 && indexed < state.array_size(encounters.ref)) {
			const Value indexed_encounter = state.at(encounters.ref, indexed);
			if (gd::is_dict(indexed_encounter)) {
				const Value id_fallback = state.get(indexed_encounter.ref, str(key::id), str(key::empty));
				if (gd::stringify_or_fallback(state, state.get(indexed_encounter.ref, str(key::placement_id), id_fallback)) == placement_id) {
					return encounter_result(state, indexed, indexed_encounter);
				}
			}
		}
	}
	// for index in range(encounters.size()): encounters[index]
	const int64_t count = ai::vsize(state, encounters);
	for (int64_t index = 0; index < count; ++index) {
		const Value encounter = ai::vindex(state, encounters, int_value(index));
		if (gd::is_dict(encounter) && text(state, encounter.ref, key::placement_id, key::empty) == placement_id) {
			return encounter_result(state, index, encounter);
		}
	}
	return encounter_result(state, -1, dict_value(state.new_dict()));
}

} // namespace overworld_rules

// DifficultyRules.

namespace difficulty_rules {

DictRef scale_income_resources(State &state, DictRef session, const Value &payload) {
	const double multiplier = gd::float_field(state, profile_for_session(state, dict_value(session)), key::income_multiplier, 1.0);
	return scale_resource_payload(state, payload, multiplier);
}

DictRef scale_resource_payload(State &state, const Value &payload, double multiplier) {
	const DictRef scaled = state.new_dict();
	if (!gd::is_dict(payload)) {
		return scaled;
	}
	for (const Value &key_value : gd::items(state, payload)) {
		const Atom resource_key = gd::stringify_or_fallback(state, key_value);
		const int64_t amount = gd::to_int(state, gd::index(state, payload.ref, key_value));
		state.set(scaled, str(resource_key), int_value(_scale_amount(state, amount, multiplier)));
	}
	return scaled;
}

int64_t _scale_amount(State &state, int64_t amount, double multiplier) {
	(void)state;
	if (amount == 0 || gd::is_equal_approx(multiplier, 1.0)) {
		return amount;
	}
	const int64_t scaled = compat::float_to_int(compat::godot_round(static_cast<double>(amount) * multiplier));
	if (amount > 0 && scaled <= 0) {
		return 1;
	}
	if (amount < 0 && scaled >= 0) {
		return -1;
	}
	return scaled;
}

} // namespace difficulty_rules

// SpellRules. Not in the group's list: the heroes' new day
// (_refresh_all_player_heroes_for_new_day) needs it.

namespace spell_rules {

gd::DictRef refresh_daily_mana(State &state, gd::DictRef hero_state) {
	const DictRef hero = ensure_hero_spellbook(state, gd::deep_duplicate_dict(state, hero_state), state.new_dict());
	const Value spellbook = field_or_new_dict(state, hero, key::spellbook);
	const Value mana = field_or_new_dict(state, gd::as_dict(spellbook), key::mana);
	state.set(gd::as_dict(mana), str(key::current), int_value(gd::int_field(state, gd::as_dict(mana), key::max, 0)));
	state.set(gd::as_dict(spellbook), str(key::mana), mana);
	state.set(hero, str(key::spellbook), spellbook);
	return hero;
}

} // namespace spell_rules

// HeroProgressionRules. Not in the group's list: the heroes' daily income
// (_player_heroes_daily_income) needs it.

namespace hero_progression_rules {

DictRef daily_income_bonus(State &state, DictRef hero_state) {
	const Value daily_income = field_or_new_dict(state, aggregate_bonuses(state, hero_state), key::daily_income);
	if (!gd::is_dict(daily_income)) {
		not_ported("HeroProgressionRules.daily_income_bonus of a daily_income that is not a Dictionary");
	}
	return gd::deep_duplicate_dict(state, daily_income.ref);
}

} // namespace hero_progression_rules

} // namespace aurelion::rules::port
