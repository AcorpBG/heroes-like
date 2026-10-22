// EnemyAdventureRules: the paths of the computer players' day the six seeds do not run (Phase 4, slice 4.2):
// hero sightings, commander picks, strategies, objective anchors and native passages, under their GDScript names.

#include "aurelion_rules/port/enemy_adventure_rules_turn.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/creature_dwelling_rules_ai.hpp"
#include "aurelion_rules/port/hero_command_rules.hpp"
#include "aurelion_rules/port/hero_command_rules_ai.hpp"
#include "aurelion_rules/port/native_transit_rules_ai.hpp"
#include "aurelion_rules/port/overworld_level_rules.hpp"
#include "aurelion_rules/port/overworld_level_rules_ai.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"
#include "aurelion_rules/port/overworld_rules_turn.hpp"
#include "aurelion_rules/port/overworld_turn_playback_turn.hpp"
#include "aurelion_rules/port/player_identity_rules.hpp"
#include "aurelion_rules/port/player_identity_rules_ai.hpp"
#include "aurelion_rules/port/session_view.hpp"

#include "aurelion_rules/compat/godot_math.hpp"
#include "aurelion_rules/compat/godot_string.hpp"

#include <initializer_list>
#include <string>

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
using overworld_rules::Vector2i;
using state::ContentTable;
using state::State;
using state::Value;
namespace key = state::key;

// d.get(key, {}) and d.get(key, []): a new container when the key is missing.
Value get_or_new_dict(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return dict_value(state.new_dict());
}

Value get_or_new_array(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return array_value(state.new_array());
}

// String(d.get(key, fallback)).
Atom text(State &state, DictRef dict, Atom field, Atom fallback) {
	return gd::stringify(state, state.get(dict, str(field), str(fallback)));
}

// String(d.get(key, fallback)) with an untyped fallback.
Atom text_or(State &state, DictRef dict, Atom field, const Value &fallback) {
	return gd::stringify(state, state.get(dict, str(field), fallback));
}

// String(record.get("encounter_id", record.get("id", ""))).
Atom encounter_id_of(State &state, DictRef record) {
	const Value id = state.get(record, str(key::id), str(key::empty));
	return text_or(state, record, key::encounter_id, id);
}

// max(a, b) of ints.
int64_t imax(int64_t a, int64_t b) {
	return compat::engine_max<int64_t>(a, b);
}

// var x: Vector3i = value.
Value as_vector3i(const Value &value) {
	if (!gd::is_vector3i(value)) {
		throw state::ScriptError(std::string("Trying to assign value of type '") + gd::type_name(value) + "' to a variable of type 'Vector3i'.");
	}
	return value;
}

// An Array literal of Strings.
ArrayRef strings(State &state, std::initializer_list<Atom> texts) {
	const ArrayRef array = state.new_array();
	for (const Atom text_atom : texts) {
		state.append(array, str(text_atom));
	}
	return array;
}

// A Dictionary literal mapping each field to 1.0, in order.
DictRef unit_weights(State &state, std::initializer_list<Atom> fields) {
	const DictRef weights = state.new_dict();
	for (const Atom field : fields) {
		state.set(weights, str(field), float_value(1.0));
	}
	return weights;
}

// The _find_*_by_placement lookups: for index in range(session.overworld.get(list, []).size()), the first
// Dictionary item whose placement_id matches as {"index": index, item_field: item}, else
// {"index": -1, item_field: {}}.
DictRef find_by_placement(State &state, DictRef session, Atom list_field, Atom item_field, Atom placement_id) {
	Value items;
	if (state.lookup(session_view::overworld(state, session), str(list_field), items)) {
		const int64_t count = ai::vsize(state, items);
		for (int64_t index = 0; index < count; ++index) {
			const Value item = ai::vindex(state, items, int_value(index));
			if (gd::is_dict(item) && text(state, item.ref, key::placement_id, key::empty) == placement_id) {
				const DictRef found = state.new_dict();
				state.set(found, str(key::index), int_value(index));
				state.set(found, str(item_field), item);
				return found;
			}
		}
	}
	const DictRef missing = state.new_dict();
	state.set(missing, str(key::index), int_value(-1));
	state.set(missing, str(item_field), dict_value(state.new_dict()));
	return missing;
}

} // namespace

namespace enemy_adventure_rules {

// Defined in enemy_states.cpp (Phase 5) and declared in no header.
DictRef normalize_enemy_known_world_memory(State &state, const Value &value, int64_t current_day);
int64_t _army_strength(State &state, const Value &stacks);
DictRef _normalized_commander_record(State &state, const Value &entry_value, const Value &commander_state_value);
DictRef _normalized_commander_army_continuity(State &state, const Value &entry_value, const Value &commander_state_value, Atom encounter_id);
ArrayRef _faction_commander_ids(State &state, Atom faction_id);
ArrayRef normalize_commander_roster(State &state, DictRef session, Atom faction_id, const Value &roster_value);
Value commander_roster_for_faction(State &state, DictRef session, Atom faction_id);
Atom _normalize_commander_status(State &state, const Value &value);
DictRef _normalize_army_payload(State &state, const Value &army);
DictRef _base_enemy_army(State &state, Atom encounter_id);

ArrayRef _current_enemy_player_hero_sighting_records(State &state, DictRef session, DictRef config, Atom faction_id, const Value &preloaded_sources, const Value &projection_profile) {
	const ArrayRef records = state.new_array();
	const ArrayRef sources = gd::is_array(preloaded_sources) ? preloaded_sources.ref : _enemy_hero_sighting_sources(state, session, config, faction_id);
	const DictRef profile = gd::is_dict(projection_profile) ? projection_profile.ref : state.new_dict();
	const int64_t source_count = static_cast<int64_t>(state.array_size(sources));
	state.set(profile, str(key::hero_source_projection_count), int_value(gd::add(gd::int_field(state, profile, key::hero_source_projection_count, 0), source_count)));
	if (state.array_size(sources) == 0) {
		return overworld_level_rules::canonical_spatial_records(state, records);
	}
	const ArrayRef heroes = _player_hero_snapshots_for_intercept(state, session, false);
	for (const Value &hero_value : gd::items(state, array_value(heroes))) {
		if (!gd::is_dict(hero_value)) {
			continue;
		}
		const DictRef hero = hero_value.ref;
		const Atom hero_id = text(state, hero, key::id, key::empty);
		if (hero_id == key::empty) {
			continue;
		}
		const Vector2i hero_tile = _player_hero_goal_tile(state, hero);
		// best_source starts as {}: none chosen yet.
		DictRef best_source = 0;
		bool chosen = false;
		int64_t best_distance = 9999;
		for (const Value &source_value : gd::items(state, array_value(sources))) {
			if (!gd::is_dict(source_value) || !overworld_level_rules::same_level(state, source_value, hero_value)) {
				continue;
			}
			state.set(profile, str(key::hero_source_comparison_count), int_value(gd::add(gd::int_field(state, profile, key::hero_source_comparison_count, 0), 1)));
			const DictRef source = source_value.ref;
			const Vector2i offset = hero_tile - Vector2i::of(gd::int_field(state, source, key::x, 0), gd::int_field(state, source, key::y, 0));
			if (!hero_command_rules::within_scout_radius(state, offset.x, offset.y, gd::int_field(state, source, key::radius, 0))) {
				continue;
			}
			const int64_t distance = compat::absi(offset.x) + compat::absi(offset.y);
			if (!chosen || gd::is_empty(state, best_source) || distance < best_distance) {
				best_source = source;
				chosen = true;
				best_distance = distance;
			}
		}
		if (!chosen || gd::is_empty(state, best_source)) {
			continue;
		}
		const DictRef record = state.new_dict();
		state.set(record, str(key::hero_id), str(hero_id));
		state.set(record, str(key::hero_label), str(text_or(state, hero, key::name, str(hero_id))));
		state.set(record, str(key::x), int_value(hero_tile.x));
		state.set(record, str(key::y), int_value(hero_tile.y));
		state.set(record, str(key::level), int_value(overworld_level_rules::level_of(state, hero_value)));
		state.set(record, str(key::army_strength), int_value(_known_player_hero_strength(state, hero)));
		state.set(record, str(key::seen_day), int_value(ai::session_int(state, session, key::day)));
		state.set(record, str(key::expires_day), int_value(gd::add(ai::session_int(state, session, key::day), 3)));
		state.set(record, str(key::source_kind), str(text(state, best_source, key::kind, key::empty)));
		state.set(record, str(key::source_id), str(text(state, best_source, key::id, key::empty)));
		state.set(record, str(key::confidence), str(key::current));
		state.set(record, str(key::state_policy), str(key::ai_known_world_memory));
		state.append(records, dict_value(record));
	}
	return overworld_level_rules::canonical_spatial_records(state, records);
}

ArrayRef _enemy_hero_sighting_sources(State &state, DictRef session, DictRef config, Atom faction_id) {
	(void)config;
	const ArrayRef sources = state.new_array();
	if (faction_id == key::empty) {
		return overworld_level_rules::canonical_spatial_records(state, sources);
	}
	for (const Value &town_value : gd::field_items(state, session_view::overworld(state, session), str(key::towns))) {
		if (!gd::is_dict(town_value)) {
			continue;
		}
		const DictRef town = town_value.ref;
		if (text(state, town, key::owner, key::neutral) != key::enemy || _town_controller_faction_id(state, town) != faction_id) {
			continue;
		}
		// AI sight uses the player's rules: towns see from their entrance,
		// commanders as far as a hero with the same artifacts and specialties.
		const DictRef entrance = overworld_level_rules::town_entrance(state, town);
		const DictRef source = state.new_dict();
		state.set(source, str(key::kind), str(key::town));
		state.set(source, str(key::id), str(text(state, town, key::placement_id, key::empty)));
		state.set(source, str(key::x), int_value(gd::int_field(state, entrance, key::x, 0)));
		state.set(source, str(key::y), int_value(gd::int_field(state, entrance, key::y, 0)));
		state.set(source, str(key::level), int_value(overworld_level_rules::level_of(state, town_value)));
		// OverworldRules.town_vision_radius(): TOWN_VISION_RADIUS.
		state.set(source, str(key::radius), int_value(8));
		state.append(sources, dict_value(source));
	}
	const Value resolved_encounters = get_or_new_array(state, session_view::overworld(state, session), key::resolved_encounters);
	for (const Value &encounter_value : gd::field_items(state, session_view::overworld(state, session), str(key::encounters))) {
		if (!_is_active_raid(state, encounter_value, faction_id, resolved_encounters)) {
			continue;
		}
		const DictRef encounter = gd::as_dict(encounter_value);
		Value commander_value;
		const bool has_commander = state.lookup(encounter, str(key::enemy_commander_state), commander_value) && gd::is_dict(commander_value);
		const DictRef commander_state = has_commander ? commander_value.ref : state.new_dict();
		const DictRef source = state.new_dict();
		state.set(source, str(key::kind), str(key::commander));
		state.set(source, str(key::id), str(text(state, encounter, key::placement_id, key::empty)));
		state.set(source, str(key::x), int_value(gd::int_field(state, encounter, key::x, 0)));
		state.set(source, str(key::y), int_value(gd::int_field(state, encounter, key::y, 0)));
		state.set(source, str(key::level), int_value(overworld_level_rules::level_of(state, encounter_value)));
		state.set(source, str(key::radius), int_value(hero_command_rules::scouting_radius_for_hero(state, commander_state)));
		state.append(sources, dict_value(source));
	}
	for (const Value &node_value : gd::field_items(state, session_view::overworld(state, session), str(key::resource_nodes))) {
		if (!gd::is_dict(node_value)) {
			continue;
		}
		const DictRef node = node_value.ref;
		if (player_identity_rules::resource_controller_id(state, node) != faction_id) {
			continue;
		}
		const DictRef site = gd::content_row(state, ContentTable::ResourceSite, text(state, node, key::site_id, key::empty));
		const int64_t site_radius = overworld_rules::held_site_vision_radius(state, site);
		if (site_radius <= 0) {
			continue;
		}
		const DictRef source = state.new_dict();
		state.set(source, str(key::kind), str(key::resource_site));
		state.set(source, str(key::id), str(text(state, node, key::placement_id, key::empty)));
		state.set(source, str(key::x), int_value(gd::int_field(state, node, key::x, 0)));
		state.set(source, str(key::y), int_value(gd::int_field(state, node, key::y, 0)));
		state.set(source, str(key::level), int_value(overworld_level_rules::level_of(state, node_value)));
		state.set(source, str(key::radius), int_value(site_radius));
		state.append(sources, dict_value(source));
	}
	return overworld_level_rules::canonical_spatial_records(state, sources);
}

DictRef _known_player_hero_snapshot_for_ai(State &state, DictRef session, Atom faction_id, DictRef hero) {
	if (faction_id == key::empty || gd::is_empty(state, hero)) {
		return state.new_dict();
	}
	const Atom hero_id = text(state, hero, key::id, key::empty);
	if (hero_id == key::empty) {
		return state.new_dict();
	}
	const ArrayRef records = _current_enemy_player_hero_sighting_records(state, session, state.new_dict(), faction_id, Value(), Value());
	for (const Value &record : gd::items(state, array_value(records))) {
		if (gd::stringify(state, ai::vget(state, record, key::hero_id, str(key::empty))) != hero_id) {
			continue;
		}
		// record.get() answered, so record is a Dictionary.
		const DictRef current = gd::deep_duplicate_dict(state, hero);
		state.set(current, str(key::position), dict_value(overworld_level_rules::position(state, gd::as_dict(record))));
		state.set(current, str(key::known_army_strength), int_value(imax(0, gd::to_int(state, ai::vget(state, record, key::army_strength, int_value(0))))));
		state.set(current, str(key::ai_sighting_confidence), str(key::current));
		state.set(current, str(key::ai_sighting_seen_day), int_value(gd::to_int(state, ai::vget(state, record, key::seen_day, int_value(0)))));
		return current;
	}
	const DictRef remembered = _enemy_player_hero_sighting_record(state, session, faction_id, hero_id);
	if (gd::is_empty(state, remembered)) {
		return state.new_dict();
	}
	const DictRef recent = gd::deep_duplicate_dict(state, hero);
	state.set(recent, str(key::position), dict_value(overworld_level_rules::position(state, remembered)));
	state.set(recent, str(key::known_army_strength), int_value(imax(0, gd::int_field(state, remembered, key::army_strength, 0))));
	state.set(recent, str(key::name), str(text_or(state, remembered, key::hero_label, str(hero_id))));
	state.set(recent, str(key::ai_sighting_confidence), str(key::recent));
	state.set(recent, str(key::ai_sighting_seen_day), int_value(gd::int_field(state, remembered, key::seen_day, 0)));
	return recent;
}

DictRef _enemy_player_hero_sighting_record(State &state, DictRef session, Atom faction_id, Atom hero_id) {
	if (faction_id == key::empty || hero_id == key::empty) {
		return state.new_dict();
	}
	for (const Value &state_value : gd::field_items(state, session_view::overworld(state, session), str(key::enemy_states))) {
		if (!gd::is_dict(state_value) || player_identity_rules::controller_id(state, state_value.ref, key::empty) != faction_id) {
			continue;
		}
		const Value memory_value = get_or_new_dict(state, state_value.ref, key::known_world_memory);
		const DictRef memory = normalize_enemy_known_world_memory(state, memory_value, ai::session_int(state, session, key::day));
		for (const Value &record_value : gd::field_items(state, memory, str(key::player_hero_sightings))) {
			if (gd::is_dict(record_value) && text(state, record_value.ref, key::hero_id, key::empty) == hero_id) {
				return record_value.ref;
			}
		}
	}
	return state.new_dict();
}

int64_t _known_player_hero_strength(State &state, DictRef hero) {
	if (state.has(hero, str(key::known_army_strength))) {
		return imax(0, gd::int_field(state, hero, key::known_army_strength, 0));
	}
	const Value army = get_or_new_dict(state, hero, key::army);
	return _army_strength(state, ai::vget(state, army, key::stacks, array_value(state.new_array())));
}

ArrayRef _player_hero_snapshots_for_intercept(State &state, DictRef session, bool read_only) {
	// read_only callers only inspect the records (path fingerprints, blocked
	// tiles), so they get the live hero dictionaries instead of deep copies.
	const ArrayRef heroes = state.new_array();
	const DictRef seen = state.new_dict();
	for (const Value &hero_value : gd::field_items(state, session_view::overworld(state, session), str(key::player_heroes))) {
		if (!gd::is_dict(hero_value)) {
			continue;
		}
		const DictRef hero = read_only ? hero_value.ref : gd::deep_duplicate_dict(state, hero_value.ref);
		const Atom hero_id = text(state, hero, key::id, key::empty);
		if (hero_id == key::empty) {
			continue;
		}
		state.set(seen, str(hero_id), bool_value(true));
		state.append(heroes, dict_value(hero));
	}
	const Atom active_hero_id = text(state, session_view::overworld(state, session), key::active_hero_id, key::empty);
	if (active_hero_id != key::empty && !state.has(seen, str(active_hero_id))) {
		Value active_hero_value;
		const bool found = state.lookup(session_view::overworld(state, session), str(key::hero), active_hero_value);
		if (found && gd::is_dict(active_hero_value) && !gd::is_empty(state, active_hero_value.ref)) {
			const DictRef active_hero = read_only ? gd::duplicate_dict(state, active_hero_value.ref) : gd::deep_duplicate_dict(state, active_hero_value.ref);
			state.set(active_hero, str(key::id), str(active_hero_id));
			Value active_position;
			const bool has_position = state.lookup(active_hero, str(key::position), active_position);
			if (!has_position || !gd::is_dict(active_position) || gd::is_empty(state, active_position.ref)) {
				Value position_source;
				if (state.lookup(session_view::overworld(state, session), str(key::hero_position), position_source)) {
					if (gd::is_dict(position_source)) {
						state.set(active_hero, str(key::position), dict_value(gd::deep_duplicate_dict(state, position_source.ref)));
					}
				} else {
					// {"x": 0, "y": 0}.duplicate(true).
					const DictRef origin = state.new_dict();
					state.set(origin, str(key::x), int_value(0));
					state.set(origin, str(key::y), int_value(0));
					state.set(active_hero, str(key::position), dict_value(origin));
				}
			}
			state.set(active_hero, str(key::is_primary), bool_value(true));
			state.append(heroes, dict_value(active_hero));
		}
	}
	return heroes;
}

Atom commander_recent_outcome_brief(State &state, const Value &source) {
	const DictRef record = _normalized_commander_record(state, source, dict_value(state.new_dict()));
	const Atom last_outcome = text(state, record, key::last_outcome, key::empty);
	if (last_outcome == key::rout_victory) {
		return key::fresh_from_a_rout;
	}
	if (last_outcome == key::pursuit_victory) {
		return key::driving_a_hard_pursuit;
	}
	if (last_outcome == key::capitulation) {
		return key::flush_with_surrender_terms;
	}
	return key::empty;
}

bool commander_can_deploy(State &state, const Value &source) {
	const DictRef continuity = _normalized_commander_army_continuity(state, source, dict_value(state.new_dict()), key::empty);
	if (gd::is_empty(state, continuity) || gd::int_field(state, continuity, key::base_strength, 0) <= 0) {
		return true;
	}
	const int64_t current_strength = imax(0, gd::int_field(state, continuity, key::current_strength, 0));
	if (current_strength <= 0) {
		return false;
	}
	const int64_t base_strength = imax(1, gd::int_field(state, continuity, key::base_strength, 0));
	const int64_t deploy_floor = imax(45, compat::float_to_int(compat::godot_round(static_cast<double>(base_strength) * 0.55)));
	return current_strength >= deploy_floor;
}

DictRef occupied_raid_commander_ids(State &state, DictRef session, Atom faction_id, Atom exclude_placement_id) {
	const DictRef occupied = state.new_dict();
	// A missing list reads as a new [], which holds no placement.
	Value resolved_encounters;
	const bool resolved_list = state.lookup(session_view::overworld(state, session), str(key::resolved_encounters), resolved_encounters) && gd::is_array(resolved_encounters);
	for (const Value &encounter : gd::field_items(state, session_view::overworld(state, session), str(key::encounters))) {
		if (!gd::is_dict(encounter)) {
			continue;
		}
		if (resolved_list && gd::array_has(state, resolved_encounters.ref, str(text(state, encounter.ref, key::placement_id, key::empty)))) {
			continue;
		}
		if (faction_id != key::empty && player_identity_rules::raid_controller_id(state, encounter.ref) != faction_id) {
			continue;
		}
		if (exclude_placement_id != key::empty && text(state, encounter.ref, key::placement_id, key::empty) == exclude_placement_id) {
			continue;
		}
		const Value commander_state = get_or_new_dict(state, encounter.ref, key::enemy_commander_state);
		const Atom roster_hero_id = gd::stringify(state, ai::vget(state, commander_state, key::roster_hero_id, str(key::empty)));
		if (roster_hero_id != key::empty) {
			state.set(occupied, str(roster_hero_id), bool_value(true));
		}
	}
	return occupied;
}

Atom select_raid_commander_roster_hero_id(State &state, DictRef session, Atom faction_id, int64_t preferred_index, DictRef occupied_commander_ids, const Value &commander_roster) {
	if (faction_id == key::empty) {
		return key::empty;
	}
	const ArrayRef hero_ids = _faction_commander_ids(state, player_identity_rules::faction_id(state, session, faction_id));
	if (state.array_size(hero_ids) == 0) {
		return key::empty;
	}
	DictRef occupied = occupied_commander_ids;
	if (gd::is_empty(state, occupied)) {
		occupied = occupied_raid_commander_ids(state, session, faction_id, key::empty);
	}
	const Value roster = gd::is_array(commander_roster) ? commander_roster : commander_roster_for_faction(state, session, faction_id);
	const ArrayRef normalized_roster = normalize_commander_roster(state, session, faction_id, roster);
	const DictRef unavailable = state.new_dict();
	for (const Value &entry_value : gd::items(state, array_value(normalized_roster))) {
		if (!gd::is_dict(entry_value)) {
			continue;
		}
		const Atom roster_hero_id = text(state, entry_value.ref, key::roster_hero_id, key::empty);
		if (roster_hero_id == key::empty) {
			continue;
		}
		const Atom status = _normalize_commander_status(state, state.get(entry_value.ref, str(key::status), str(key::available)));
		if (status != key::available || !commander_can_deploy(state, entry_value)) {
			state.set(unavailable, str(roster_hero_id), bool_value(true));
		}
	}
	const int64_t count = static_cast<int64_t>(state.array_size(hero_ids));
	const int64_t start_index = compat::posmod(preferred_index, count);
	for (int64_t offset = 0; offset < count; ++offset) {
		const int64_t index = compat::int_mod(gd::add(start_index, offset), static_cast<int64_t>(state.array_size(hero_ids)));
		const Atom candidate_id = gd::stringify(state, state.at(hero_ids, index));
		if (candidate_id == key::empty || state.has(occupied, str(candidate_id)) || state.has(unavailable, str(candidate_id))) {
			continue;
		}
		return candidate_id;
	}
	return key::empty;
}

Atom raid_display_name(State &state, DictRef encounter) {
	if (gd::is_empty(state, encounter)) {
		return key::hostile_contact;
	}
	// An enemy hero is named like any hero; there is no "host" around it.
	if (gd::is_dict(gd::field(state, encounter, key::ai_hero))) {
		const Atom hero_name = raid_commander_name(state, encounter);
		if (hero_name != key::empty) {
			return hero_name;
		}
	}
	const DictRef encounter_template = gd::content_row(state, ContentTable::Encounter, encounter_id_of(state, encounter));
	const Value name_fallback = state.get(encounter, str(key::placement_id), str(key::enemy_army_3));
	const Atom encounter_name = text_or(state, encounter_template, key::name, name_fallback);
	const Atom commander_name = raid_commander_display_name(state, encounter);
	if (commander_name == key::empty || player_identity_rules::raid_controller_id(state, encounter) == key::empty) {
		return encounter_name;
	}
	return gd::format(state, key::s_s_s, { str(commander_name), str(encounter_name) });
}

int64_t _preferred_commander_index_for_encounter(State &state, DictRef encounter) {
	const Value fallback = state.get(encounter, str(key::encounter_id), str(key::empty));
	const Atom placement_id = text_or(state, encounter, key::placement_id, fallback);
	if (placement_id == key::empty) {
		return 0;
	}
	return compat::absi(gd::hash(state, str(placement_id)));
}

DictRef enemy_strategy(State &state, DictRef config, Atom faction_id) {
	DictRef strategy = _default_enemy_strategy(state);
	const DictRef faction = gd::content_row(state, ContentTable::Faction, text_or(state, config, key::faction_id, str(faction_id)));
	// A missing field reads as a new {}: a Dictionary, merged as one.
	Value faction_strategy;
	if (!state.lookup(faction, str(key::enemy_strategy), faction_strategy)) {
		strategy = _merge_strategy_dict(state, strategy, state.new_dict());
	} else if (gd::is_dict(faction_strategy)) {
		strategy = _merge_strategy_dict(state, strategy, faction_strategy.ref);
	}
	Value overrides;
	if (!state.lookup(config, str(key::strategy_overrides), overrides)) {
		strategy = _merge_strategy_dict(state, strategy, state.new_dict());
	} else if (gd::is_dict(overrides)) {
		strategy = _merge_strategy_dict(state, strategy, overrides.ref);
	}
	return strategy;
}

double strategy_scalar(State &state, DictRef strategy, Atom section, Atom field, double default_value) {
	// A missing section reads as {}: its get() answers the default.
	Value bucket;
	if (!state.lookup(strategy, str(section), bucket)) {
		return default_value;
	}
	if (!gd::is_dict(bucket)) {
		return default_value;
	}
	return gd::to_float(state.get(bucket.ref, str(field), float_value(default_value)));
}

int64_t strategy_int(State &state, DictRef strategy, Atom section, Atom field, int64_t default_value) {
	Value bucket;
	if (!state.lookup(strategy, str(section), bucket)) {
		return default_value;
	}
	if (!gd::is_dict(bucket)) {
		return default_value;
	}
	return gd::to_int(state, state.get(bucket.ref, str(field), int_value(default_value)));
}

bool target_is_objective_anchor(State &state, DictRef session, Atom target_kind, Atom placement_id) {
	if (target_kind == key::town) {
		return _town_is_objective_anchor(state, session, placement_id);
	}
	if (target_kind == key::encounter) {
		const DictRef encounter_result = _find_encounter_by_placement(state, session, placement_id);
		if (gd::int_field(state, encounter_result, key::index, -1) < 0) {
			return false;
		}
		return _encounter_is_objective_anchor(state, session, gd::as_dict(get_or_new_dict(state, encounter_result, key::encounter)));
	}
	return false;
}

int64_t raid_strength(State &state, DictRef encounter) {
	DictRef normalized_army = _normalize_army_payload(state, get_or_new_dict(state, encounter, key::enemy_army));
	if (gd::is_empty(state, normalized_army)) {
		normalized_army = _base_enemy_army(state, encounter_id_of(state, encounter));
	}
	return _army_strength(state, get_or_new_array(state, normalized_army, key::stacks));
}

DictRef _find_player_hero(State &state, DictRef session, Atom hero_id) {
	if (hero_id == key::empty) {
		return state.new_dict();
	}
	for (const Value &hero : gd::field_items(state, session_view::overworld(state, session), str(key::player_heroes))) {
		if (gd::is_dict(hero) && text(state, hero.ref, key::id, key::empty) == hero_id) {
			return hero.ref;
		}
	}
	return state.new_dict();
}

Vector2i _player_hero_goal_tile(State &state, DictRef hero) {
	Value position;
	if (!state.lookup(hero, str(key::position), position)) {
		return Vector2i::of(0, 0);
	}
	const DictRef hero_position = gd::as_dict(position);
	return Vector2i::of(gd::int_field(state, hero_position, key::x, 0), gd::int_field(state, hero_position, key::y, 0));
}

int64_t _exploration_target_level(State &state, Atom target_id) {
	// target_id.split(":"): four parts when it holds exactly three separators.
	const std::string &whole = state.text(target_id);
	const std::string &separator = state.text(key::colon);
	int64_t separators = 0;
	size_t last = std::string::npos;
	for (size_t at = whole.find(separator); at != std::string::npos; at = whole.find(separator, at + separator.size())) {
		++separators;
		last = at;
	}
	if (separators != 3) {
		return 0;
	}
	return compat::to_int(whole.substr(last + separator.size()));
}

bool _town_is_objective_anchor(State &state, DictRef session, Atom placement_id) {
	const Atom scenario_id = gd::to_string(gd::index(state, session, str(key::scenario_id)));
	const DictRef scenario = gd::content_row(state, ContentTable::Scenario, scenario_id);
	// A missing objectives field reads as {}: no bucket, no anchor.
	Value objectives;
	if (!state.lookup(scenario, str(key::objectives), objectives) || !gd::is_dict(objectives)) {
		return false;
	}
	for (const Atom bucket : { key::victory, key::defeat }) {
		for (const Value &objective : gd::field_items(state, objectives.ref, str(bucket))) {
			if (gd::is_dict(objective) && text(state, objective.ref, key::placement_id, key::empty) == placement_id) {
				return true;
			}
		}
	}
	return false;
}

ArrayRef _default_reason_codes_for_target(State &state, Atom target_kind, Atom target_id, DictRef target) {
	if (target_kind == key::town) {
		const ArrayRef codes = strings(state, { key::town_siege });
		if (gd::bool_field(state, target, key::objective_anchor_2, true) || target_id == key::riverwatch_hold) {
			state.append(codes, str(key::objective_front));
		}
		return codes;
	}
	if (target_kind == key::resource) {
		return strings(state, { key::route_pressure });
	}
	if (target_kind == key::encounter) {
		return strings(state, { key::site_contested, key::objective_front });
	}
	if (target_kind == key::explore) {
		return strings(state, { key::frontier_scouting, key::search_contact });
	}
	return state.new_array();
}

bool _encounter_is_objective_anchor(State &state, DictRef session, DictRef encounter) {
	const DictRef encounter_template = gd::content_row(state, ContentTable::Encounter, encounter_id_of(state, encounter));
	Value flags_value;
	if (!state.lookup(encounter_template, str(key::victory_flags), flags_value)) {
		return false;
	}
	const ArrayRef victory_flags = ai::typed_array(flags_value, "EnemyAdventureRules._encounter_is_objective_anchor: victory_flags");
	if (state.array_size(victory_flags) == 0) {
		return false;
	}
	const Atom scenario_id = gd::to_string(gd::index(state, session, str(key::scenario_id)));
	const DictRef scenario = gd::content_row(state, ContentTable::Scenario, scenario_id);
	// A missing objectives field reads as {}: no bucket, no anchor.
	Value objectives;
	if (!state.lookup(scenario, str(key::objectives), objectives) || !gd::is_dict(objectives)) {
		return false;
	}
	for (const Atom bucket : { key::victory, key::defeat }) {
		for (const Value &objective : gd::field_items(state, objectives.ref, str(bucket))) {
			if (!gd::is_dict(objective)) {
				continue;
			}
			if (text(state, objective.ref, key::type, key::empty) != key::flag_true) {
				continue;
			}
			if (gd::array_has(state, victory_flags, str(text(state, objective.ref, key::flag, key::empty)))) {
				return true;
			}
		}
	}
	return false;
}

DictRef _secure_native_passage_target(State &state, DictRef session, DictRef raid, DictRef state_, Atom faction_id, DictRef node, bool preserve_target) {
	const Atom actor_id = text(state, raid, key::placement_id, key::empty);
	DictRef check = overworld_rules::native_passage_travel_check(state, session, node, native_transit_rules::point(state, dict_value(raid)), actor_id);
	if (gd::bool_field(state, check, key::native_transit_random_exit, false)) {
		// Raids roll the same random exit as the player; every candidate still
		// goes through the shared occupancy/guard rules.
		check = overworld_rules::native_random_exit_check(state, session, node, native_transit_rules::point(state, dict_value(raid)), actor_id);
	}
	if (!gd::bool_field(state, check, key::ok, false)) {
		const DictRef refused = state.new_dict();
		state.set(refused, str(key::encounter), dict_value(raid));
		state.set(refused, str(key::state), dict_value(state_));
		state.set(refused, str(key::event_message), str(key::empty));
		state.set(refused, str(key::native_transit_error), str(text(state, check, key::message, key::empty)));
		return refused;
	}
	DictRef updated = gd::deep_duplicate_dict(state, raid);
	const Value destination = as_vector3i(gd::index(state, check, str(key::exit)));
	state.set(updated, str(key::x), int_value(destination.vx()));
	state.set(updated, str(key::y), int_value(destination.vy()));
	if (destination.vz() == 0) {
		state.erase(updated, str(key::level));
	} else {
		state.set(updated, str(key::level), int_value(destination.vz()));
	}
	const Value link = gd::index(state, check, str(key::link));
	state.set(updated, str(key::native_transit_last_exit_id), str(gd::stringify(state, ai::vmember(state, link, key::target_placement_id))));
	overworld_rules::note_native_trip(state, session, actor_id);
	overworld_turn_playback::move(state, dict_value(session), updated, overworld_level_rules::position(state, raid));
	state.erase(updated, str(key::native_transit_target_exit_id));
	if (!preserve_target) {
		_ai_hero_task_finish_live_assignment(state, session, faction_id, updated, key::completed, key::valid);
		updated = _clear_regroup_target(state, updated);
	}
	Value encounters_value;
	const ArrayRef encounters = state.lookup(session_view::overworld(state, session), str(key::encounters), encounters_value)
			? ai::typed_array(encounters_value, "EnemyAdventureRules._secure_native_passage_target: encounters")
			: state.new_array();
	const int64_t count = static_cast<int64_t>(state.array_size(encounters));
	for (int64_t index = 0; index < count; ++index) {
		const Atom placement_id = gd::stringify(state, ai::vget(state, state.at(encounters, index), key::placement_id, str(key::empty)));
		if (placement_id == text(state, updated, key::placement_id, key::empty)) {
			state.set_at(encounters, index, dict_value(updated));
			break;
		}
	}
	state.set(session_view::overworld(state, session), str(key::encounters), array_value(encounters));
	overworld_rules::invalidate_spatial_lookup(state, session);
	overworld_rules::_refresh_blocked_tile_index(state, session);
	const DictRef result = state.new_dict();
	state.set(result, str(key::encounter), dict_value(updated));
	state.set(result, str(key::state), dict_value(state_));
	const Atom where = destination.vz() > 0 ? key::the_underground : key::the_surface;
	const Atom message = gd::format(state, key::s_travelled_through_a_passage_to, { str(_raid_name(state, updated)), str(where) });
	state.set(result, str(key::event_message), str(message));
	state.set(result, str(key::native_transit), gd::duplicate_value(state, gd::index(state, check, str(key::link)), true));
	return result;
}

int64_t _dwelling_guard_strength(State &state, DictRef session, DictRef node, DictRef site, Atom faction_id) {
	if (!creature_dwelling_rules::is_dwelling(state, site)) {
		return 0;
	}
	const ArrayRef stacks = creature_dwelling_rules::guard_stacks(state, node, site, faction_id, ai::session_int(state, session, key::day));
	return _army_strength(state, array_value(stacks));
}

DictRef _clear_regroup_target(State &state, DictRef raid) {
	state.set(raid, str(key::target_kind), str(key::empty));
	state.set(raid, str(key::target_placement_id), str(key::empty));
	state.set(raid, str(key::target_label), str(key::empty));
	state.set(raid, str(key::target_x), int_value(gd::int_field(state, raid, key::x, 0)));
	state.set(raid, str(key::target_y), int_value(gd::int_field(state, raid, key::y, 0)));
	state.set(raid, str(key::goal_x), int_value(gd::int_field(state, raid, key::x, 0)));
	state.set(raid, str(key::goal_y), int_value(gd::int_field(state, raid, key::y, 0)));
	state.set(raid, str(key::goal_distance), int_value(9999));
	state.set(raid, str(key::arrived), bool_value(false));
	state.set(raid, str(key::target_public_reason), str(key::empty));
	state.set(raid, str(key::target_reason_codes), array_value(state.new_array()));
	state.set(raid, str(key::target_public_importance), str(key::empty));
	state.set(raid, str(key::target_debug_reason), str(key::empty));
	return raid;
}

DictRef _find_town_by_placement(State &state, DictRef session, Atom placement_id) {
	return find_by_placement(state, session, key::towns, key::town, placement_id);
}

DictRef _default_enemy_strategy(State &state) {
	const DictRef strategy = state.new_dict();
	state.set(strategy, str(key::build_category_weights), dict_value(unit_weights(state, { key::civic, key::dwelling, key::economy, key::support, key::magic })));
	state.set(strategy, str(key::build_value_weights), dict_value(unit_weights(state, { key::income, key::growth, key::quality, key::readiness, key::pressure })));
	state.set(strategy, str(key::raid_target_weights), dict_value(unit_weights(state, { key::town, key::resource, key::artifact, key::encounter, key::hero })));
	state.set(strategy, str(key::resource_value_weights), dict_value(unit_weights(state, { key::gold, key::wood, key::ore, key::aetherglass, key::embergrain, key::peatwax, key::verdant_grafts, key::brass_scrip, key::memory_salt, key::experience })));
	state.set(strategy, str(key::site_family_weights), dict_value(unit_weights(state, { key::neutral_dwelling, key::faction_outpost, key::frontier_shrine })));
	state.set(strategy, str(key::reinforcement), dict_value(unit_weights(state, { key::garrison_bias, key::raid_bias, key::ranged_weight, key::melee_weight, key::low_tier_weight, key::high_tier_weight })));
	const DictRef raid = state.new_dict();
	state.set(raid, str(key::threshold_scale), float_value(1.0));
	state.set(raid, str(key::max_active_bonus), int_value(0));
	state.set(raid, str(key::pressure_commitment_scale), float_value(1.0));
	state.set(raid, str(key::objective_weight), float_value(1.0));
	state.set(raid, str(key::town_siege_weight), float_value(1.0));
	state.set(raid, str(key::site_denial_weight), float_value(1.0));
	state.set(raid, str(key::hero_hunt_weight), float_value(1.0));
	state.set(strategy, str(key::raid), dict_value(raid));
	return strategy;
}

DictRef _merge_strategy_dict(State &state, DictRef base, DictRef override) {
	const DictRef merged = gd::deep_duplicate_dict(state, base);
	const ArrayRef override_keys = gd::keys(state, override);
	for (const Value &field : gd::items(state, array_value(override_keys))) {
		const Value value = gd::index(state, override, field);
		// merged.get(key, {}) is Dictionary: a missing key reads as a new {}.
		Value existing;
		const bool has_existing = state.lookup(merged, field, existing);
		if (gd::is_dict(value) && (!has_existing || gd::is_dict(existing))) {
			const DictRef existing_dict = has_existing ? existing.ref : state.new_dict();
			const DictRef nested = _merge_strategy_dict(state, existing_dict, value.ref);
			state.set(merged, str(gd::stringify(state, field)), dict_value(nested));
		} else {
			state.set(merged, str(gd::stringify(state, field)), value);
		}
	}
	return merged;
}

DictRef _find_encounter_by_placement(State &state, DictRef session, Atom placement_id) {
	return find_by_placement(state, session, key::encounters, key::encounter, placement_id);
}

// Controlling player (or legacy faction key) of the town, matching
// EnemyTurnRules._town_controller_faction_id. Not the town's content faction.
Atom _town_controller_faction_id(State &state, DictRef town_state) {
	return player_identity_rules::town_controller_id(state, town_state);
}

} // namespace enemy_adventure_rules

} // namespace aurelion::rules::port
