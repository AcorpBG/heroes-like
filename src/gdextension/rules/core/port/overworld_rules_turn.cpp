// OverworldRules for the computer players' day: the debug rules profile, fog and
// terrain reads, native passage checks, the blocked-tile and spatial lookup caches,
// town control changes with their front and occupation, and town weekly growth.

#include "aurelion_rules/port/overworld_rules_turn.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/creature_dwelling_rules_ai.hpp"
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

constexpr Atom kScript = key::overworld_rules_script;

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

// {"ok": false, "changed": false, "town": {}}.
DictRef no_control_change(State &state) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(false));
	state.set(result, str(key::changed), bool_value(false));
	state.set(result, str(key::town), dict_value(state.new_dict()));
	return result;
}

// var entry: Dictionary = context.get(field, {}); false when it is empty (the caller computes it).
bool context_entry(State &state, DictRef context, Atom field, DictRef &out) {
	Value found;
	if (!state.lookup(context, str(field), found)) {
		return false;
	}
	out = gd::as_dict(found);
	return !gd::is_empty(state, out);
}

bool rules_profile_active(State &state) {
	return ai::static_bool(state, kScript, key::_movement_rules_profile_active);
}

} // namespace

namespace overworld_rules {

int64_t _rules_profile_timer(State &state) {
	return rules_profile_active(state) ? gd::ticks_usec() : 0;
}

void _rules_profile_add_ms(State &state, Atom bucket, int64_t started_usec) {
	if (!rules_profile_active(state) || started_usec <= 0 || bucket == key::empty) {
		return;
	}
	const DictRef profile = ai::static_dict(state, kScript, key::_movement_rules_profile);
	const DictRef buckets = gd::as_dict(dict_or_new(state, profile, key::sub_buckets_ms));
	const double before = gd::to_float(state.get(buckets, str(bucket), gd::float_value(0.0)));
	const double elapsed = static_cast<double>(compat::engine_max<int64_t>(0, gd::sub(gd::ticks_usec(), started_usec)));
	state.set(buckets, str(bucket), gd::float_value(compat::snappedf(before + elapsed / 1000.0, 0.001)));
	state.set(profile, str(key::sub_buckets_ms), dict_value(buckets));
}

void _rules_profile_set(State &state, Atom section, Atom name, const Value &value) {
	if (!rules_profile_active(state) || section == key::empty || name == key::empty) {
		return;
	}
	const DictRef profile = ai::static_dict(state, kScript, key::_movement_rules_profile);
	Value found;
	const DictRef target = state.lookup(profile, str(section), found) && gd::is_dict(found) ? found.ref : state.new_dict();
	state.set(target, str(name), value);
	state.set(profile, str(section), dict_value(target));
}

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

DictRef _add_dwelling_town_growth(State &state, DictRef session, DictRef town, DictRef growth) {
	const Atom controller = _town_controller_id(state, town);
	if (controller == key::empty || gd::is_empty(state, growth)) {
		return growth;
	}
	const DictRef held = state.new_dict();
	for (const Value &node : gd::field_items(state, session_view::overworld(state, session), str(key::resource_nodes))) {
		if (!gd::is_dict(node) || player_identity_rules::resource_controller_id(state, node.ref) != controller) {
			continue;
		}
		const DictRef site = gd::content_row(state, ContentTable::ResourceSite, ai::string_or_empty(state, node.ref, key::site_id));
		if (!creature_dwelling_rules::is_dwelling(state, site) || creature_dwelling_rules::is_refugee_camp(state, site)) {
			continue;
		}
		const ArrayRef units = creature_dwelling_rules::creatures(state, node.ref, site, ai::session_int(state, session, key::day));
		for (const Value &unit_id : gd::items(state, array_value(units))) {
			const Atom base = creature_dwelling_rules::base_unit_id(state, gd::stringify(state, unit_id));
			state.set(held, str(base), int_value(gd::add(gd::int_field(state, held, base, 0), 1)));
		}
	}
	if (gd::is_empty(state, held)) {
		return growth;
	}
	const DictRef result = gd::deep_duplicate_dict(state, growth);
	const ArrayRef unit_ids = gd::keys(state, result);
	for (const Value &unit_id : gd::items(state, array_value(unit_ids))) {
		const Atom base = creature_dwelling_rules::base_unit_id(state, gd::stringify(state, unit_id));
		if (state.has(held, str(base))) {
			const int64_t count = gd::to_int(state, gd::index(state, result, unit_id));
			const int64_t bonus = gd::to_int(state, gd::index(state, held, str(base)));
			state.set(result, unit_id, int_value(gd::add(count, bonus)));
		}
	}
	return result;
}

DictRef transition_town_control(State &state, DictRef session, Atom placement_id, Atom new_owner, Atom controlling_faction_id, Atom source) {
	if (placement_id == key::empty) {
		return no_control_change(state);
	}
	const DictRef town_result = _find_town_by_placement(state, session, placement_id);
	if (gd::int_field(state, town_result, key::index, -1) < 0) {
		return no_control_change(state);
	}
	const Value towns = array_or_new(state, session_view::overworld(state, session), key::towns);
	DictRef town = gd::as_dict(dict_or_new(state, town_result, key::town));
	const Atom previous_owner = gd::stringify(state, state.get(town, str(key::owner), str(key::neutral)));
	const Atom previous_controller = player_identity_rules::town_controller_id(state, town);
	if (controlling_faction_id == key::empty && previous_owner == key::enemy) {
		controlling_faction_id = previous_controller;
	}
	if (previous_owner != new_owner && previous_owner == key::player) {
		town = _release_town_occupation_reserves(state, town);
	}
	state.set(town, str(key::owner), str(new_owner));
	if (new_owner == key::enemy) {
		state.set(town, str(key::controlling_faction_id), str(player_identity_rules::faction_id(state, session, controlling_faction_id)));
		const DictRef controlling_player = player_identity_rules::player(state, session, controlling_faction_id);
		state.set(town, str(key::controlling_player_id), str(ai::string_or_empty(state, controlling_player, key::player_id)));
	} else {
		state.set(town, str(key::controlling_faction_id), str(key::empty));
		if (new_owner == key::player && ai::string_or_empty(state, session_view::overworld(state, session), key::active_player_id) != key::empty) {
			const Value active_player_id = gd::index(state, session_view::overworld(state, session), str(key::active_player_id));
			state.set(town, str(key::controlling_player_id), str(gd::stringify(state, active_player_id)));
		} else {
			state.erase(town, str(key::controlling_player_id));
		}
	}
	const DictRef owning_player = player_identity_rules::player(state, session, ai::string_or_empty(state, town, key::controlling_player_id));
	if (!gd::is_empty(state, owning_player)) {
		state.set(town, str(key::team_id), str(ai::string_or_empty(state, owning_player, key::team_id)));
	} else {
		state.erase(town, str(key::team_id));
	}
	const DictRef front = _town_front_after_control_change(state, session, town, previous_owner, new_owner, controlling_faction_id, source);
	state.set(town, str(key::front), dict_value(front));
	// town.get("available_recruits", {}): a missing entry reads as an empty Dictionary.
	Value available_recruits;
	const bool has_recruits = state.lookup(town, str(key::available_recruits), available_recruits);
	const bool recruits_dict = !has_recruits || gd::is_dict(available_recruits);
	if (new_owner == key::player &&
			(!recruits_dict || (previous_owner != key::enemy && recruits_dict && (!has_recruits || gd::is_empty(state, available_recruits.ref))))) {
		state.set(town, str(key::available_recruits), dict_value(_seed_recruits_for_town(state, town)));
	}
	const DictRef occupation = _town_occupation_after_control_change(state, session, town, previous_owner, new_owner, controlling_faction_id, source);
	state.set(town, str(key::occupation), dict_value(occupation));
	state.set_at(gd::as_array(towns), gd::int_field(state, town_result, key::index, -1), dict_value(town));
	state.set(session_view::overworld(state, session), str(key::towns), towns);
	if (new_owner == key::player) {
		_teach_visiting_town_spells(state, session, town);
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(true));
	state.set(result, str(key::changed), bool_value(previous_owner != new_owner || previous_controller != player_identity_rules::town_controller_id(state, town)));
	state.set(result, str(key::previous_owner), str(previous_owner));
	state.set(result, str(key::town), dict_value(town));
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

void invalidate_spatial_lookup(State &state, DictRef session) {
	ai::meta_remove(state, session, key::_overworld_spatial_lookup_indexes);
	ai::meta_remove(state, session, key::_overworld_spatial_lookup_signature);
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
	if (has_session && gd::stringify(state, state.get(town, str(key::owner), str(key::neutral))) == key::player) {
		throw state::NotPorted("OverworldRules.town_weekly_growth: _effective_player_town_weekly_growth (a player town) is not ported");
	}
	const DictRef result = _town_weekly_growth(state, town, session, state.new_dict());
	_town_read_scope_cache_store(state, cache_key, dict_value(result));
	return result;
}

DictRef _town_weekly_growth(State &state, DictRef town, const Value &session, DictRef metric_context) {
	const DictRef growth = _seed_recruits_for_town(state, town);
	if (session.kind == Kind::Nil) {
		return growth;
	}
	const DictRef view = gd::as_dict(session);
	int64_t growth_percent = 0;
	DictRef logistics = 0;
	if (!context_entry(state, metric_context, key::logistics, logistics)) {
		logistics = _town_logistics_state(state, view, town);
	}
	growth_percent = gd::add(growth_percent, gd::int_field(state, logistics, key::growth_bonus_percent, 0));
	growth_percent = gd::add(growth_percent, gd::int_field(state, logistics, key::response_growth_bonus_percent, 0));
	growth_percent = gd::sub(growth_percent, gd::int_field(state, logistics, key::gap_growth_penalty_percent, 0));
	DictRef recovery = 0;
	if (!context_entry(state, metric_context, key::recovery, recovery)) {
		recovery = _town_recovery_state(state, view, town, logistics);
	}
	growth_percent = gd::sub(growth_percent, gd::int_field(state, recovery, key::growth_penalty_percent, 0));
	DictRef capital_project = 0;
	if (!context_entry(state, metric_context, key::capital_project, capital_project)) {
		capital_project = _town_capital_project_state(state, town, session, logistics, recovery);
	}
	growth_percent = gd::sub(growth_percent, gd::int_field(state, capital_project, key::growth_penalty_percent, 0));
	DictRef occupation = 0;
	if (!context_entry(state, metric_context, key::occupation, occupation)) {
		occupation = _town_occupation_state(state, view, town);
	}
	growth_percent = gd::sub(growth_percent, gd::int_field(state, occupation, key::growth_penalty_percent, 0));
	return _add_dwelling_town_growth(state, view, town, _apply_recruit_percent(state, dict_value(growth), growth_percent));
}

DictRef _town_front_after_control_change(State &state, DictRef session, DictRef town, Atom previous_owner, Atom new_owner, Atom controlling_faction_id, Atom source) {
	const DictRef front = _normalize_town_front_state(state, dict_or_new(state, town, key::front));
	Atom faction_id = controlling_faction_id;
	if (faction_id == key::empty && previous_owner == key::enemy) {
		faction_id = _normalized_enemy_front_faction_id(state, session, front, town);
	}
	if (faction_id == key::empty && new_owner == key::enemy) {
		faction_id = _normalized_enemy_front_faction_id(state, session, front, town);
	}
	if (previous_owner == new_owner) {
		if (new_owner == key::enemy && faction_id != key::empty) {
			return _town_front_stabilizing_state(state, session, town, faction_id, source);
		}
		return front;
	}
	if (new_owner == key::player) {
		if (faction_id == key::empty) {
			return _normalize_town_front_state(state, dict_value(state.new_dict()));
		}
		state.set(front, str(key::state), str(key::retake));
		gd::merge(state, front, player_identity_rules::identity_fields(state, session, faction_id), true);
		state.set(front, str(key::last_change_day), int_value(ai::session_int(state, session, key::day)));
		state.set(front, str(key::stabilize_until_day), int_value(0));
		state.set(front, str(key::last_owner), str(previous_owner));
		state.set(front, str(key::capture_count), int_value(vmax(1, gd::add(gd::int_field(state, front, key::capture_count, 0), 1))));
		state.set(front, str(key::source), str(source));
		return front;
	}
	if (new_owner == key::enemy) {
		if (faction_id == key::empty) {
			return _normalize_town_front_state(state, dict_value(state.new_dict()));
		}
		return _town_front_stabilizing_state(state, session, town, faction_id, source, previous_owner);
	}
	return _normalize_town_front_state(state, dict_value(state.new_dict()));
}

DictRef _town_front_stabilizing_state(State &state, DictRef session, DictRef town, Atom faction_id, Atom source, Atom previous_owner, int64_t bonus_days) {
	const DictRef front = _normalize_town_front_state(state, dict_or_new(state, town, key::front));
	state.set(front, str(key::state), str(key::stabilizing));
	gd::merge(state, front, player_identity_rules::identity_fields(state, session, faction_id), true);
	state.set(front, str(key::last_change_day), int_value(ai::session_int(state, session, key::day)));
	const int64_t day = ai::session_int(state, session, key::day);
	const int64_t days = compat::engine_clamp<int64_t>(gd::add(_town_front_stabilize_days(state, session, town), vmax(0, bonus_days)), 2, 8);
	state.set(front, str(key::stabilize_until_day), int_value(gd::add(day, days)));
	if (previous_owner != key::empty) {
		state.set(front, str(key::last_owner), str(previous_owner));
	}
	state.set(front, str(key::capture_count), int_value(vmax(1, gd::int_field(state, front, key::capture_count, 0))));
	state.set(front, str(key::source), str(source));
	return front;
}

int64_t _town_front_stabilize_days(State &state, DictRef session, DictRef town) {
	int64_t days = 2;
	const Atom role = _town_strategic_role(state, town);
	if (role == key::capital) {
		days += 2;
	} else if (role == key::stronghold) {
		days += 1;
	}
	if (_town_is_objective_anchor(state, session, ai::string_or_empty(state, town, key::placement_id))) {
		days += 1;
	}
	if (gd::bool_field(state, _town_recovery_state(state, session, town, state.new_dict()), key::active, false)) {
		days += 1;
	}
	return compat::engine_clamp<int64_t>(days, 2, 6);
}

DictRef _town_occupation_after_control_change(State &state, DictRef session, DictRef town, Atom previous_owner, Atom new_owner, Atom controlling_faction_id, Atom source) {
	const DictRef occupation = _normalize_town_occupation_state(state, dict_or_new(state, town, key::occupation));
	if (previous_owner == new_owner) {
		if (new_owner != key::player) {
			return _normalize_town_occupation_state(state, dict_value(state.new_dict()));
		}
		return occupation;
	}
	if (new_owner != key::player) {
		return _normalize_town_occupation_state(state, dict_value(state.new_dict()));
	}
	if (previous_owner != key::enemy) {
		return _normalize_town_occupation_state(state, dict_value(state.new_dict()));
	}
	Atom faction_id = controlling_faction_id;
	if (faction_id == key::empty) {
		faction_id = _town_faction_id(state, town);
	}
	if (faction_id == key::empty) {
		return _normalize_town_occupation_state(state, dict_value(state.new_dict()));
	}
	const int64_t pressure = _town_occupation_seed_pressure(state, session, town);
	state.set(occupation, str(key::state), str(key::pacifying));
	gd::merge(state, occupation, player_identity_rules::identity_fields(state, session, faction_id), true);
	state.set(occupation, str(key::pressure), int_value(pressure));
	state.set(occupation, str(key::initial_pressure), int_value(pressure));
	state.set(occupation, str(key::start_day), gd::index(state, session, str(key::day)));
	state.set(occupation, str(key::last_event_day), gd::index(state, session, str(key::day)));
	state.set(occupation, str(key::last_owner), str(previous_owner));
	state.set(occupation, str(key::source), str(source));
	state.set(occupation, str(key::locked_recruits), dict_value(state.new_dict()));
	_lock_town_occupation_reserves(state, town, occupation);
	return occupation;
}

DictRef _apply_recruit_percent(State &state, const Value &recruits, int64_t percent_modifier) {
	const DictRef adjusted = state.new_dict();
	if (!gd::is_dict(recruits)) {
		return adjusted;
	}
	const ArrayRef unit_ids = gd::keys(state, recruits.ref);
	for (const Value &unit_id_value : gd::items(state, array_value(unit_ids))) {
		const Atom unit_id = gd::stringify(state, unit_id_value);
		const int64_t base_count = vmax(0, gd::to_int(state, state.get(recruits.ref, str(unit_id), int_value(0))));
		if (unit_id == key::empty) {
			continue;
		}
		if (base_count <= 0) {
			state.set(adjusted, str(unit_id), int_value(0));
			continue;
		}
		// max(0.0, float(100 + percent_modifier)) of the untyped max.
		const double percent = static_cast<double>(gd::add(100, percent_modifier));
		const double scale = 0.0 < percent ? percent : 0.0;
		const double scaled = static_cast<double>(base_count) * scale / 100.0;
		state.set(adjusted, str(unit_id), int_value(vmax(0, compat::float_to_int(compat::godot_round(scaled)))));
	}
	return adjusted;
}

bool _town_is_objective_anchor(State &state, DictRef session, Atom placement_id) {
	if (placement_id == key::empty) {
		return false;
	}
	// GDScript also reads the scenario record here, and never uses it.
	const Value objectives = scenario_rules::objectives_for_session(state, session);
	if (!gd::is_dict(objectives)) {
		return false;
	}
	const Atom buckets[2] = {key::victory, key::defeat};
	for (const Atom bucket : buckets) {
		for (const Value &objective : gd::field_items(state, objectives.ref, str(bucket))) {
			if (gd::is_dict(objective) && ai::string_or_empty(state, objective.ref, key::placement_id) == placement_id) {
				return true;
			}
		}
	}
	return false;
}

void _lock_town_occupation_reserves(State &state, DictRef town, DictRef occupation) {
	if (gd::is_empty(state, town)) {
		return;
	}
	const DictRef available = _normalize_recruit_payload(state, dict_or_new(state, town, key::available_recruits));
	if (gd::is_empty(state, available)) {
		state.set(occupation, str(key::locked_recruits), dict_value(state.new_dict()));
		return;
	}
	const int64_t access_percent = compat::engine_clamp<int64_t>(gd::sub(80, gd::mul(gd::int_field(state, occupation, key::initial_pressure, 0), 8)), 20, 55);
	const DictRef accessible = state.new_dict();
	const DictRef locked = state.new_dict();
	const ArrayRef unit_ids = gd::keys(state, available);
	for (const Value &unit_id_value : gd::items(state, array_value(unit_ids))) {
		const Atom unit_id = gd::stringify(state, unit_id_value);
		const int64_t count = vmax(0, gd::to_int(state, state.get(available, str(unit_id), int_value(0))));
		if (unit_id == key::empty || count <= 0) {
			continue;
		}
		int64_t released = compat::float_to_int(compat::godot_floor(static_cast<double>(count) * static_cast<double>(access_percent) / 100.0));
		if (released <= 0) {
			released = 1;
		}
		released = compat::engine_clamp<int64_t>(released, 0, count);
		if (released > 0) {
			state.set(accessible, str(unit_id), int_value(released));
		}
		if (count > released) {
			state.set(locked, str(unit_id), int_value(gd::sub(count, released)));
		}
	}
	state.set(town, str(key::available_recruits), dict_value(accessible));
	state.set(occupation, str(key::locked_recruits), dict_value(locked));
}

DictRef _release_town_occupation_reserves(State &state, DictRef town) {
	const DictRef occupation = _normalize_town_occupation_state(state, dict_or_new(state, town, key::occupation));
	const DictRef locked = _normalize_recruit_payload(state, dict_or_new(state, occupation, key::locked_recruits));
	if (!gd::is_empty(state, locked)) {
		state.set(town, str(key::available_recruits), dict_value(_add_recruit_growth(state, dict_or_new(state, town, key::available_recruits), dict_value(locked))));
	}
	state.set(town, str(key::occupation), dict_value(_normalize_town_occupation_state(state, dict_value(state.new_dict()))));
	return town;
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

DictRef town_recovery_state(State &state, DictRef session, DictRef town) {
	const Atom cache_key = _town_read_scope_cache_key(state, session, key::recovery, town);
	if (_town_read_scope_cache_has(state, cache_key)) {
		return gd::as_dict(_town_read_scope_cache_get(state, cache_key));
	}
	const DictRef result = _town_recovery_state(state, session, town, state.new_dict());
	_town_read_scope_cache_store(state, cache_key, dict_value(result));
	return result;
}

Atom apply_town_recovery_pressure(State &state, DictRef session, Atom town_placement_id, int64_t amount, Atom source) {
	if (town_placement_id == key::empty || amount <= 0) {
		return key::empty;
	}
	const DictRef town_result = _find_town_by_placement(state, session, town_placement_id);
	if (gd::int_field(state, town_result, key::index, -1) < 0) {
		return key::empty;
	}
	const Value towns = array_or_new(state, session_view::overworld(state, session), key::towns);
	const DictRef town = gd::as_dict(dict_or_new(state, town_result, key::town));
	const DictRef recovery = _normalize_town_recovery_state(state, dict_or_new(state, town, key::recovery));
	state.set(recovery, str(key::pressure), int_value(gd::add(vmax(0, gd::int_field(state, recovery, key::pressure, 0)), amount)));
	state.set(recovery, str(key::last_event_day), int_value(ai::session_int(state, session, key::day)));
	state.set(recovery, str(key::source), str(source));
	state.set(town, str(key::recovery), dict_value(recovery));
	state.set_at(gd::as_array(towns), gd::int_field(state, town_result, key::index, -1), dict_value(town));
	state.set(session_view::overworld(state, session), str(key::towns), towns);
	const DictRef recovery_state = town_recovery_state(state, session, town);
	const Atom source_clause = source != key::empty ? gd::format(state, key::from_s, {str(source)}) : key::empty;
	const int64_t days_to_clear = gd::int_field(state, recovery_state, key::days_to_clear, 0);
	return gd::format(state, key::s_recovery_d_s_d_day, {str(_town_name(state, town)), int_value(amount), str(source_clause), int_value(days_to_clear), str(days_to_clear == 1 ? key::empty : key::s)});
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
