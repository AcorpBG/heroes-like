// OverworldRules for the computer players' day: fog and terrain reads, native
// passage checks, the blocked-tile cache, town weekly growth and capital projects,
// and resource site disruption. The debug rules profile, the spatial lookup cache,
// town control changes and town recovery are in overworld_rules_shared.cpp.

#include "aurelion_rules/port/overworld_rules_turn.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/creature_dwelling_rules_ai.hpp"
#include "aurelion_rules/port/hero_command_rules_ai.hpp"
#include "aurelion_rules/port/hero_progression_rules_turn.hpp"
#include "aurelion_rules/port/native_transit_rules_turn.hpp"
#include "aurelion_rules/port/overworld_level_rules.hpp"
#include "aurelion_rules/port/overworld_level_rules_ai.hpp"
#include "aurelion_rules/port/player_identity_rules.hpp"
#include "aurelion_rules/port/player_identity_rules_ai.hpp"
#include "aurelion_rules/port/scenario_evaluation.hpp"
#include "aurelion_rules/port/session_view.hpp"

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
using state::Kind;
using state::State;
using state::Value;
namespace key = state::key;
namespace level_rules = overworld_level_rules;
namespace transit = native_transit_rules;

// d.get(field, {}) / d.get(field, []) passed on or stored: the value, or a new container.
Value dict_or_new(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return dict_value(state.new_dict());
}

Value array_or_new(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return array_value(state.new_array());
}

// max(a, b) of two ints (untyped): a, unless it is less than b.
int64_t vmax(int64_t a, int64_t b) {
	return a < b ? b : a;
}

// {"ok": false, "message": message}.
DictRef failure(State &state, Atom message) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(false));
	state.set(result, str(key::message), str(message));
	return result;
}

} // namespace

namespace overworld_rules {

bool is_tile_explored(State &state, DictRef session, int64_t x, int64_t y, int64_t level) {
	return _grid_cell(state, state.at(_fog_grids(state, session, level), 0), x, y);
}

DictRef native_passage_travel_check(State &state, DictRef session, DictRef node, const Value &actor_position, Atom actor_id, Atom target_id, bool fight_on_arrival) {
	const Value nodes = array_or_new(state, session_view::overworld(state, session), key::resource_nodes);
	const DictRef resolved = transit::resolve(state, ai::typed_array(nodes, "OverworldRules.native_passage_travel_check"), node, target_id);
	if (!gd::bool_field(state, resolved, key::ok, false)) {
		if (gd::bool_field(state, resolved, key::native_transit_random_exit, false)) {
			if (!gd::equal(state, actor_position, transit::point(state, gd::field(state, transit::link_of(state, node), key::entry)))) {
				return failure(state, key::move_to_the_passage_entrance_first);
			}
			const DictRef source_safety = _native_passage_endpoint_safety(state, session, node, actor_id);
			if (!gd::bool_field(state, source_safety, key::ok, false)) {
				return source_safety;
			}
		}
		return resolved;
	}
	if (!gd::equal(state, actor_position, gd::index(state, resolved, str(key::entry)))) {
		return failure(state, key::move_to_the_passage_entrance_first);
	}
	const Value endpoints[2] = {dict_value(node), gd::index(state, resolved, str(key::peer))};
	for (const Value &endpoint : endpoints) {
		// Player arrivals can engage a hostile destination through BattleRules;
		// AI movement has its own combat owner.
		const bool combat_arrival = gd::equal(state, endpoint, gd::index(state, resolved, str(key::peer))) && actor_id != key::empty &&
				(fight_on_arrival || actor_id == ai::string_or_empty(state, session_view::overworld(state, session), key::active_hero_id));
		const DictRef safety = _native_passage_endpoint_safety(state, session, gd::as_dict(endpoint), actor_id, Value(), combat_arrival);
		if (!gd::bool_field(state, safety, key::ok, false)) {
			return safety;
		}
	}
	return resolved;
}

DictRef native_random_exit_check(State &state, DictRef session, DictRef node, const Value &actor_position, Atom actor_id) {
	DictRef first_failure = state.new_dict();
	const ArrayRef order = transit::exit_order(state, node, native_exit_roll_key(state, session, node, actor_id));
	for (const Value &destination : gd::items(state, array_value(order))) {
		const Atom target_id = gd::stringify(state, ai::vget(state, destination, key::target_placement_id, str(key::empty)));
		const DictRef check = native_passage_travel_check(state, session, node, actor_position, actor_id, target_id);
		if (gd::bool_field(state, check, key::ok, false)) {
			return check;
		}
		if (gd::is_empty(state, first_failure)) {
			first_failure = check;
		}
	}
	if (!gd::is_empty(state, first_failure)) {
		return first_failure;
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(false));
	state.set(result, str(key::error), str(key::native_passage_has_no_exit));
	state.set(result, str(key::message), str(key::this_portal_has_no_exit_on));
	return result;
}

Atom native_exit_roll_key(State &state, DictRef session, DictRef node, Atom actor_id) {
	// trips: the overworld's Dictionary, or {} (read only).
	Value trips;
	const bool has_trips = state.lookup(session_view::overworld(state, session), str(key::native_transit_trips), trips) && gd::is_dict(trips);
	const Atom placement_id = ai::string_or_empty(state, node, key::placement_id);
	const int64_t day = ai::session_int(state, session, key::day);
	const int64_t trip_count = has_trips ? gd::int_field(state, trips.ref, actor_id, 0) : 0;
	return gd::format(state, key::s_d_s_d, {str(placement_id), int_value(day), str(actor_id), int_value(trip_count)});
}

void note_native_trip(State &state, DictRef session, Atom actor_id) {
	Value found;
	const DictRef trips = state.lookup(session_view::overworld(state, session), str(key::native_transit_trips), found) && gd::is_dict(found) ? found.ref : state.new_dict();
	state.set(trips, str(actor_id), int_value(gd::add(gd::int_field(state, trips, actor_id, 0), 1)));
	state.set(session_view::overworld(state, session), str(key::native_transit_trips), dict_value(trips));
}

DictRef _native_passage_endpoint_safety(State &state, DictRef session, DictRef node, Atom actor_id, const Value &actor_blocked_indexes, bool combat_arrival) {
	const Value tile = transit::point(state, gd::field(state, transit::link_of(state, node), key::entry));
	const Vector2i local = Vector2i::of(tile.vx(), tile.vy());
	const Value local_value = Value::of_vector2i(local.x, local.y);
	const Atom id = ai::string_or_empty(state, node, key::placement_id);
	const int64_t level = tile.vz();
	if (level < 0 || level >= level_rules::level_count(state, session) || !terrain_id_is_passable(state, _terrain_id_at(state, session, tile.vx(), tile.vy(), level))) {
		return failure(state, key::the_passage_destination_is_impassable);
	}
	const Atom tile_key = _tile_key(state, local);
	Value blocked = state.get(_blocked_tile_index(state, session, level), str(tile_key), bool_value(false));
	if (combat_arrival) {
		// Exclude only armies that this exact arrival can fight.
		const DictRef defenders = state.new_dict();
		for (const Value &encounter : gd::field_items(state, session_view::overworld(state, session), str(key::encounters))) {
			if (gd::is_dict(encounter) && level_rules::on_level(state, encounter, level) && !is_encounter_resolved(state, session, encounter.ref)) {
				if (gd::equal(state, transit::point(state, encounter), tile) || gd::array_has(state, _guard_engagement_world_tiles(state, encounter.ref), local_value)) {
					state.set(defenders, str(encounter_key(state, encounter.ref)), bool_value(true));
				}
			}
		}
		if (!gd::is_empty(state, defenders)) {
			blocked = state.get(_build_blocked_tile_index(state, session, level, actor_id, defenders), str(tile_key), bool_value(false));
		}
	} else if (blocked.kind == Kind::Bool && blocked.b && actor_id != key::empty) {
		// A moving AI army may itself cover the doorway: re-evaluate without that actor.
		if (gd::is_dict(actor_blocked_indexes)) {
			const Value level_key = int_value(level);
			if (!state.has(actor_blocked_indexes.ref, level_key)) {
				state.set(actor_blocked_indexes.ref, level_key, dict_value(_build_blocked_tile_index(state, session, level, actor_id, state.new_dict())));
			}
			blocked = ai::vget(state, gd::index(state, actor_blocked_indexes.ref, level_key), str(tile_key), bool_value(false));
		} else {
			blocked = state.get(_build_blocked_tile_index(state, session, level, actor_id, state.new_dict()), str(tile_key), bool_value(false));
		}
	}
	const bool open = blocked.kind == Kind::Bool && !blocked.b;
	const bool blocked_by_self = gd::is_string(blocked) && blocked.ref == id;
	if (!open && !blocked_by_self) {
		return failure(state, key::another_object_blocks_the_passage_entrance);
	}
	// A hero's zone does not close a passage.
	const DictRef guard = _find_guard_engagement_at_tile(state, session, tile.vx(), tile.vy(), level, false);
	if (!combat_arrival && gd::int_field(state, guard, key::index, -1) >= 0) {
		Atom guard_id = key::empty;
		Value guard_encounter;
		if (state.lookup(guard, str(key::encounter), guard_encounter)) {
			guard_id = gd::stringify(state, ai::vget(state, guard_encounter, key::placement_id, str(key::empty)));
		}
		if (guard_id != actor_id) {
			return failure(state, key::clear_the_guard_before_using_this);
		}
	}
	for (const Value &encounter : gd::field_items(state, session_view::overworld(state, session), str(key::encounters))) {
		if (!gd::is_dict(encounter) || ai::string_or_empty(state, encounter.ref, key::placement_id) == actor_id || is_encounter_resolved(state, session, encounter.ref)) {
			continue;
		}
		if (!combat_arrival && gd::equal(state, transit::point(state, encounter), tile)) {
			return failure(state, key::an_army_occupies_the_passage_entrance);
		}
	}
	for (const Value &hero : gd::field_items(state, session_view::overworld(state, session), str(key::player_heroes))) {
		if (gd::is_dict(hero) && ai::string_or_empty(state, hero.ref, key::id) != actor_id && gd::equal(state, transit::point(state, gd::field(state, hero.ref, key::position)), tile)) {
			return failure(state, key::a_hero_occupies_the_passage_entrance);
		}
	}
	const DictRef lookup = _spatial_lookup_index(state, session, level);
	Value town_by_tile;
	if (state.lookup(lookup, str(key::town_by_tile), town_by_tile) && ai::vhas(state, town_by_tile, str(tile_key))) {
		return failure(state, key::a_town_occupies_the_passage_entrance);
	}
	const ArrayRef site_entries = _spatial_lookup_entries(state, lookup, key::resource_by_interaction_tile, local);
	for (const Value &index : gd::items(state, array_value(site_entries))) {
		const Value nodes = gd::index(state, session_view::overworld(state, session), str(key::resource_nodes));
		const DictRef other = gd::as_dict(ai::vindex(state, nodes, int_value(gd::to_int(state, index))));
		if (ai::string_or_empty(state, other, key::placement_id) != id) {
			return failure(state, key::another_site_occupies_the_passage_entrance);
		}
	}
	const ArrayRef artifact_entries = _spatial_lookup_entries(state, lookup, key::artifact_by_tile, local);
	for (const Value &index : gd::items(state, array_value(artifact_entries))) {
		const Value nodes = gd::index(state, session_view::overworld(state, session), str(key::artifact_nodes));
		const Value artifact = ai::vindex(state, nodes, int_value(gd::to_int(state, index)));
		if (!gd::to_bool(ai::vget(state, artifact, key::collected, bool_value(false)))) {
			return failure(state, key::recover_the_artifact_at_the_passage);
		}
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(true));
	return result;
}

ArrayRef map_for_level(State &state, DictRef session, int64_t level) {
	return level_rules::terrain_rows(state, dict_value(session), level);
}

DictRef _blocked_tile_index(State &state, DictRef session, int64_t level) {
	if (!ai::meta_has(state, session, key::_overworld_blocked_tile_indexes)) {
		_refresh_blocked_tile_index(state, session);
	}
	Value stored;
	const bool has_indexes = state.lookup(session_view::meta(state, session), gd::name_value(key::_overworld_blocked_tile_indexes), stored);
	const DictRef level_indexes = has_indexes ? gd::as_dict(stored) : 0;
	const int64_t resolved_level = level_rules::query_level(state, session, level);
	Value found;
	if (has_indexes && state.lookup(level_indexes, int_value(resolved_level), found)) {
		return gd::as_dict(found);
	}
	return state.new_dict();
}

int64_t placement_level(State &state, DictRef session, Atom placement_id, int64_t fallback) {
	if (placement_id == key::empty) {
		return fallback;
	}
	// Placement identity is global even though tile indexes are per level.
	const DictRef index = _spatial_lookup_index(state, session, 0);
	const Atom pairs[4][2] = {
		{key::town_by_placement, key::towns},
		{key::encounter_by_placement, key::encounters},
		{key::resource_by_placement, key::resource_nodes},
		{key::artifact_by_placement, key::artifact_nodes},
	};
	for (const auto &pair : pairs) {
		// var rows: Array = session.overworld.get(pair[1], []): a missing entry reads as [].
		Value rows_value;
		const bool has_rows = state.lookup(session_view::overworld(state, session), str(pair[1]), rows_value);
		const ArrayRef rows = has_rows ? ai::typed_array(rows_value, "OverworldRules.placement_level") : 0;
		const int64_t rows_size = has_rows ? state.array_size(rows) : 0;
		int64_t ordinal = -1;
		Value table;
		if (state.lookup(index, str(pair[0]), table)) {
			ordinal = gd::to_int(state, ai::vget(state, table, str(placement_id), int_value(-1)));
		}
		if (ordinal >= 0 && ordinal < rows_size) {
			return level_rules::level_of(state, state.at(rows, ordinal));
		}
	}
	return fallback;
}

Atom _terrain_id_at(State &state, DictRef session, int64_t x, int64_t y, int64_t level) {
	const ArrayRef map_data = map_for_level(state, session, level);
	if (y < 0 || y >= state.array_size(map_data)) {
		return key::empty;
	}
	const Value row = state.at(map_data, y);
	if (!gd::is_array(row) || x < 0 || x >= state.array_size(row.ref)) {
		return key::empty;
	}
	return gd::stringify(state, state.at(row.ref, x));
}

DictRef town_weekly_growth(State &state, DictRef town, const Value &session) {
	// Without a session the growth is the town's seeded growth alone.
	const bool has_session = session.kind != Kind::Nil;
	const Atom cache_key = has_session ? _town_read_scope_cache_key(state, gd::as_dict(session), key::weekly_growth, town) : _town_content_read_scope_key(state, key::seeded_weekly_growth, town);
	if (_town_read_scope_cache_has(state, cache_key)) {
		return gd::as_dict(_town_read_scope_cache_get(state, cache_key));
	}
	const DictRef result = has_session && gd::stringify(state, state.get(town, str(key::owner), str(key::neutral))) == key::player ? _effective_player_town_weekly_growth(state, gd::as_dict(session), town) : _town_weekly_growth(state, town, session, state.new_dict());
	_town_read_scope_cache_store(state, cache_key, dict_value(result));
	return result;
}

DictRef town_capital_project_state(State &state, DictRef town, const Value &session) {
	// Without a session the cache key is "": no cache read or write.
	const Atom cache_key = session.kind != Kind::Nil ? _town_read_scope_cache_key(state, gd::as_dict(session), key::capital_project, town) : key::empty;
	if (_town_read_scope_cache_has(state, cache_key)) {
		return gd::as_dict(_town_read_scope_cache_get(state, cache_key));
	}
	const DictRef result = _town_capital_project_state(state, town, session, state.new_dict(), state.new_dict());
	_town_read_scope_cache_store(state, cache_key, dict_value(result));
	return result;
}

int64_t town_logistics_support_radius(State &state, DictRef session, DictRef town) {
	// session == null cannot happen: a session is its view.
	(void)session;
	if (gd::is_empty(state, town) || _town_controller_id(state, town) == key::empty) {
		return 0;
	}
	return gd::int_field(state, _town_logistics_plan(state, town), key::support_radius, 0);
}

Atom apply_resource_site_disruption(State &state, DictRef session, DictRef node, DictRef site, Atom previous_controller, Atom attacker_controller) {
	if (previous_controller == key::empty || previous_controller == attacker_controller) {
		return key::empty;
	}
	const int64_t x = gd::int_field(state, node, key::x, 0);
	const int64_t y = gd::int_field(state, node, key::y, 0);
	const DictRef town_result = _nearest_town_for_controller(state, session, previous_controller, x, y, level_rules::level_of(state, dict_value(node)));
	if (gd::int_field(state, town_result, key::index, -1) < 0) {
		return key::empty;
	}
	const DictRef town = gd::as_dict(dict_or_new(state, town_result, key::town));
	const int64_t distance = gd::add(compat::absi(gd::sub(x, gd::int_field(state, town, key::x, 0))), compat::absi(gd::sub(y, gd::int_field(state, town, key::y, 0))));
	if (distance > gd::int_field(state, _town_logistics_plan(state, town), key::support_radius, 0)) {
		return key::empty;
	}
	int64_t disruption_pressure = gd::int_field(state, _resource_site_town_support(state, site), key::disruption_pressure, 0);
	const DictRef response_state = _resource_site_response_state(state, session, node, site);
	Atom disruption_source = gd::stringify(state, state.get(site, str(key::name), str(key::frontier_route_2)));
	if (gd::bool_field(state, response_state, key::active, false)) {
		disruption_pressure = gd::add(disruption_pressure, vmax(1, gd::int_field(state, response_state, key::recovery_relief, 0)));
		disruption_pressure = gd::add(disruption_pressure, vmax(1, gd::int_field(state, response_state, key::break_pressure, 0)));
		disruption_source = gd::format(state, key::s_escort_line, {str(disruption_source)});
	}
	if (disruption_pressure <= 0) {
		return key::empty;
	}
	return apply_town_recovery_pressure(state, session, gd::stringify(state, state.get(town, str(key::placement_id), str(key::empty))), disruption_pressure, disruption_source);
}

DictRef _town_scaling_hero(State &state, DictRef session, DictRef town) {
	// Recruit prices and growth follow the commander stationed in this town, not
	// whichever hero happens to be selected. No local hero means no hero bonus.
	// session == null cannot happen: a session is its view.
	if (gd::is_empty(state, town)) {
		return state.new_dict();
	}
	const DictRef hero = hero_command_rules::town_defending_hero(state, session, town);
	const Atom hero_id = gd::stringify(state, state.get(hero, str(key::id), str(key::empty)));
	if (hero_id == key::empty) {
		return state.new_dict();
	}
	// The active mirror can be ahead of its roster entry until commit_active_hero.
	const DictRef overworld = session_view::overworld(state, session);
	const Value active = state.get(overworld, str(key::hero), dict_value(state.new_dict()));
	if (gd::is_dict(active) && hero_id == gd::stringify(state, state.get(overworld, str(key::active_hero_id), str(key::empty))) && gd::stringify(state, state.get(active.ref, str(key::id), str(key::empty))) == hero_id) {
		return active.ref;
	}
	return hero;
}

DictRef _effective_player_town_weekly_growth(State &state, DictRef session, DictRef town) {
	const DictRef hero = _town_scaling_hero(state, session, town);
	const DictRef growth = _town_weekly_growth(state, town, dict_value(session), state.new_dict());
	return hero_progression_rules::scale_recruit_growth(state, hero, dict_value(growth));
}

} // namespace overworld_rules

namespace native_transit_rules {

ArrayRef exit_order(State &state, DictRef node, Atom key_text) {
	const ArrayRef options = gd::deep_duplicate_array(state, destinations(state, node));
	if (state.array_size(options) < 2) {
		return options;
	}
	gd::sort_custom(state, options, [&](const Value &a, const Value &b) {
		const Atom a_id = gd::stringify(state, ai::vget(state, a, key::target_placement_id, str(key::empty)));
		const Atom b_id = gd::stringify(state, ai::vget(state, b, key::target_placement_id, str(key::empty)));
		return state.text(a_id) < state.text(b_id);
	});
	const int64_t start = compat::posmod(gd::hash(state, str(key_text)), state.array_size(options));
	return gd::concat(state, gd::slice(state, options, start), gd::slice(state, options, 0, start));
}

} // namespace native_transit_rules

} // namespace aurelion::rules::port
