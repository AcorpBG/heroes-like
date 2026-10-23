// OverworldRules for the human seat's routes (Phase 7, slice 7.1): tile
// blocking and route interactions, the active hero's route search and its
// lengths, linked transit edges, the movement preview, the guard approach and
// the blocking-object feedback. WaterTravelRules.is_sailing is here too.

#include "aurelion_rules/port/overworld_rules_human.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/native_transit_rules.hpp"
#include "aurelion_rules/port/native_transit_rules_ai.hpp"
#include "aurelion_rules/port/overworld_level_rules.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/water_travel_rules_ai.hpp"
#include "aurelion_rules/port/water_travel_rules_turn.hpp"

#include <algorithm>
#include <string>
#include <unordered_map>
#include <unordered_set>
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
using overworld_rules::Tiles;
using overworld_rules::Vector2i;
using state::ContentTable;
using state::Kind;
using state::State;
using state::Value;
namespace key = state::key;
namespace level_rules = overworld_level_rules;
namespace transit = native_transit_rules;
namespace water = water_travel_rules;

// OverworldRules.ROUTE_DIRECTIONS and PLAIN_ROUTE_DIRECTIONS.
constexpr Vector2i kRouteDirections[] = {{0, -1}, {0, 1}, {-1, 0}, {1, 0}, {-1, -1}, {1, -1}, {-1, 1}, {1, 1}};
constexpr Vector2i kPlainRouteDirections[] = {{-1, 0}, {1, 0}, {0, -1}, {0, 1}, {-1, -1}, {1, -1}, {-1, 1}, {1, 1}};

Value tile_value(Vector2i tile) {
	return Value::of_vector2i(tile.x, tile.y);
}

uint64_t tile_id(Vector2i tile) {
	return (static_cast<uint64_t>(static_cast<uint32_t>(tile.x)) << 32) | static_cast<uint32_t>(tile.y);
}

bool tiles_have(const Tiles &tiles, Vector2i tile) {
	return std::find(tiles.begin(), tiles.end(), tile) != tiles.end();
}

// var x: Vector2i = value: a Vector2i, or a ScriptError.
Vector2i as_vector2i(const Value &value) {
	if (!gd::is_vector2i(value)) {
		throw state::ScriptError(std::string("Trying to assign value of type '") + gd::type_name(value) + "' to a variable of type 'Vector2i'.");
	}
	return {value.vx(), value.vy()};
}

// d.get(field, {}) if d.get(field, {}) is Dictionary else {}.
DictRef sub_dict(State &state, DictRef dict, Atom field) {
	const Value value = state.get(dict, str(field), Value());
	return gd::is_dict(value) ? value.ref : state.new_dict();
}

// d.get(field, fallback) of an untyped field passed on: the value, or the fallback.
Value field_or_new_array(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return array_value(state.new_array());
}

Value field_or_new_dict(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return dict_value(state.new_dict());
}

// String(d.get(a, d.get(b, ""))).
Atom string_or_other(State &state, DictRef dict, Atom first, Atom second) {
	Value found;
	if (state.lookup(dict, str(first), found)) {
		return gd::stringify(state, found);
	}
	return ai::string_or_empty(state, dict, second);
}

// _pathing_debug_profile[counter] = int(_pathing_debug_profile.get(counter, 0)) + 1.
void count_pathing(State &state, Atom counter) {
	const DictRef profile = ai::static_dict(state, key::overworld_rules_script, key::_pathing_debug_profile);
	state.set(profile, str(counter), int_value(gd::add(gd::int_field(state, profile, counter, 0), 1)));
}

// _blocked_tile_index(session, level).has(_tile_key(tile)).
bool blocked_index_has(State &state, DictRef session, Vector2i tile, int64_t level) {
	return state.has(overworld_rules::_blocked_tile_index(state, session, level), str(overworld_rules::_tile_key(state, tile)));
}

// The breadth-first search's predecessors and path sizes, by tile.
template <typename T>
using TileMap = std::unordered_map<uint64_t, T>;

} // namespace

namespace water_travel_rules {

bool is_sailing(State &state, const Value &session) {
	if (session.kind == Kind::Nil) {
		return false;
	}
	const DictRef overworld = session_view::overworld(state, gd::as_dict(session));
	return hero_boat_id(state, field_or_new_dict(state, overworld, key::hero)) != key::empty;
}

} // namespace water_travel_rules

namespace overworld_rules {

bool tile_is_blocked(State &state, DictRef session, int64_t x, int64_t y, int64_t level) {
	const ArrayRef map_data = map_for_level(state, session, level);
	if (y < 0 || y >= state.array_size(map_data)) {
		return true;
	}
	const Value row = state.at(map_data, y);
	if (!gd::is_array(row) || x < 0 || x >= state.array_size(row.ref)) {
		return true;
	}
	const Atom terrain_id = gd::stringify(state, state.at(row.ref, x));
	if (!terrain_id_is_passable(state, terrain_id)) {
		return true;
	}
	return blocked_index_has(state, session, Vector2i::of(x, y), level);
}

bool tile_has_route_interaction(State &state, DictRef session, int64_t x, int64_t y, int64_t level, bool exact_target_only) {
	const DictRef profile = gd::as_dict(gd::static_var(state, key::overworld_rules_script, key::_pathing_debug_profile));
	if (gd::bool_field(state, profile, key::capture_enabled, false)) {
		count_pathing(state, key::route_interaction_lookup_count);
		count_pathing(state, key::route_interaction_spatial_lookup_count);
	}
	const Vector2i tile = Vector2i::of(x, y);
	level = level_rules::query_level(state, session, level);
	const DictRef lookup_index = _spatial_lookup_index(state, session, level);
	// Selection ownership excludes surrounding guard zones and town art anchors.
	// Existing movement callers retain their full interaction/approach semantics.
	if (!exact_target_only && gd::int_field(state, _find_guard_engagement_at_tile(state, session, x, y, level), key::index, -1) >= 0) {
		return true;
	}
	const DictRef overworld = session_view::overworld(state, session);
	const Value towns = field_or_new_array(state, overworld, key::towns);
	const DictRef town_by_tile = sub_dict(state, lookup_index, key::town_by_tile);
	const int64_t town_index = gd::int_field(state, town_by_tile, _tile_key(state, tile), -1);
	if (gd::is_array(towns) && town_index >= 0 && town_index < state.array_size(towns.ref) && gd::is_dict(state.at(towns.ref, town_index))) {
		if (!exact_target_only) {
			return true;
		}
		const DictRef here = state.new_dict();
		state.set(here, str(key::x), int_value(x));
		state.set(here, str(key::y), int_value(y));
		state.set(here, str(key::level), int_value(level));
		if (gd::equal(state, dict_value(level_rules::town_entrance(state, state.at(towns.ref, town_index).ref)), dict_value(level_rules::position(state, here)))) {
			return true;
		}
	}
	const Value resource_nodes = field_or_new_array(state, overworld, key::resource_nodes);
	for (const Value &node_index : gd::items(state, array_value(_spatial_lookup_entries(state, lookup_index, key::resource_by_interaction_tile, tile)))) {
		const int64_t index = gd::to_int(state, node_index);
		const Value node = gd::is_array(resource_nodes) && index >= 0 && index < state.array_size(resource_nodes.ref) ? state.at(resource_nodes.ref, index) : dict_value(state.new_dict());
		if (!gd::is_dict(node)) {
			continue;
		}
		const DictRef site = gd::content_row(state, ContentTable::ResourceSite, ai::string_or_empty(state, node.ref, key::site_id));
		if (!resource_node_is_present(state, node.ref, site)) {
			continue;
		}
		return true;
	}
	const Value artifact_nodes = field_or_new_array(state, overworld, key::artifact_nodes);
	for (const Value &node_index : gd::items(state, array_value(_spatial_lookup_entries(state, lookup_index, key::artifact_by_tile, tile)))) {
		const int64_t index = gd::to_int(state, node_index);
		const Value node = gd::is_array(artifact_nodes) && index >= 0 && index < state.array_size(artifact_nodes.ref) ? state.at(artifact_nodes.ref, index) : dict_value(state.new_dict());
		if (gd::is_dict(node) && !gd::bool_field(state, node.ref, key::collected, false)) {
			return true;
		}
	}
	for (const Value &encounter_index : gd::items(state, array_value(_spatial_lookup_entries(state, lookup_index, key::encounter_by_tile, tile)))) {
		const DictRef encounter = gd::as_dict(ai::vindex(state, field_or_new_array(state, overworld, key::encounters), int_value(gd::to_int(state, encounter_index))));
		if (is_encounter_resolved(state, session, encounter)) {
			continue;
		}
		if (gd::int_field(state, encounter, key::x, -1) == x && gd::int_field(state, encounter, key::y, -1) == y) {
			return true;
		}
	}
	const Atom active_hero_id = ai::string_or_empty(state, overworld, key::active_hero_id);
	for (const Value &hero : gd::field_items(state, overworld, str(key::player_heroes))) {
		if (!gd::is_dict(hero)) {
			continue;
		}
		if (ai::string_or_empty(state, hero.ref, key::id) == active_hero_id) {
			continue;
		}
		const DictRef position = sub_dict(state, hero.ref, key::position);
		if (level_rules::on_level(state, dict_value(position), level) && gd::int_field(state, position, key::x, -999) == x && gd::int_field(state, position, key::y, -999) == y) {
			return true;
		}
	}
	return false;
}

bool tile_is_actionable_route_destination(State &state, DictRef session, int64_t x, int64_t y, int64_t level) {
	return tile_has_route_interaction(state, session, x, y, level);
}

bool hero_route_tile_blocked(State &state, DictRef session, int64_t x, int64_t y, int64_t level) {
	if (!water::is_sailing(state, dict_value(session))) {
		return tile_is_blocked(state, session, x, y, level);
	}
	level = level_rules::query_level(state, session, level);
	if (!water::is_water(state, dict_value(session), x, y, level)) {
		return true;
	}
	if (!gd::is_empty(state, water::free_boat_at(state, dict_value(session), Vector2i::of(x, y), level))) {
		return true;
	}
	return blocked_index_has(state, session, Vector2i::of(x, y), level);
}

bool hero_route_destination(State &state, DictRef session, int64_t x, int64_t y, int64_t level) {
	level = level_rules::query_level(state, session, level);
	if (water::is_sailing(state, dict_value(session))) {
		if (water::is_water(state, dict_value(session), x, y, level)) {
			return tile_has_route_interaction(state, session, x, y, level);
		}
		return !tile_is_blocked(state, session, x, y, level) || tile_is_actionable_route_destination(state, session, x, y, level);
	}
	if (!gd::is_empty(state, water::free_boat_at(state, dict_value(session), Vector2i::of(x, y), level))) {
		return true;
	}
	if (water::is_water(state, dict_value(session), x, y, level)) {
		return false;
	}
	return tile_is_actionable_route_destination(state, session, x, y, level);
}

ArrayRef hero_route_path(State &state, DictRef session, Vector2i start, Vector2i goal, int64_t level, bool plain) {
	const ArrayRef path = state.new_array();
	const Vector2i size = derive_map_size(state, session);
	if (goal.x < 0 || goal.y < 0 || goal.x >= size.x || goal.y >= size.y) {
		return path;
	}
	if (start == goal) {
		state.append(path, tile_value(start));
		return path;
	}
	if (hero_route_tile_blocked(state, session, goal.x, goal.y, level) && (plain || !hero_route_destination(state, session, goal.x, goal.y, level))) {
		return path;
	}
	const Vector2i *directions = plain ? kPlainRouteDirections : kRouteDirections;
	const ArrayRef transit_edges = plain ? state.new_array() : active_linked_transit_edges(state, session, level);
	const bool has_transit = state.array_size(transit_edges) != 0;
	std::vector<Vector2i> queue{start};
	size_t queue_index = 0;
	TileMap<Vector2i> came_from{{tile_id(start), start}};
	while (queue_index < queue.size()) {
		const Vector2i current = queue[queue_index];
		queue_index += 1;
		if (current == goal) {
			std::vector<Vector2i> walked{goal};
			Vector2i walker = goal;
			while (!(walker == start)) {
				walker = came_from.at(tile_id(walker));
				walked.push_back(walker);
			}
			for (auto tile = walked.rbegin(); tile != walked.rend(); ++tile) {
				state.append(path, tile_value(*tile));
			}
			return path;
		}
		for (size_t index = 0; index < 8; ++index) {
			const Vector2i next = current + directions[index];
			if (next.x < 0 || next.y < 0 || next.x >= size.x || next.y >= size.y || came_from.count(tile_id(next)) != 0) {
				continue;
			}
			if (tile_step_cuts_blocked_corner(state, session, current, next, level)) {
				continue;
			}
			if (hero_route_tile_blocked(state, session, next.x, next.y, level) && (plain || !(next == goal) || !hero_route_destination(state, session, next.x, next.y, level))) {
				continue;
			}
			if (!(next == goal) && tile_has_route_interaction(state, session, next.x, next.y, level)) {
				continue;
			}
			came_from.emplace(tile_id(next), current);
			queue.push_back(next);
		}
		if (!has_transit) {
			continue;
		}
		for (const Value &linked_next : gd::items(state, array_value(linked_transit_neighbors_from_edges(state, array_value(transit_edges), current)))) {
			if (!gd::is_vector2i(linked_next)) {
				continue;
			}
			const Vector2i linked = {linked_next.vx(), linked_next.vy()};
			if (came_from.count(tile_id(linked)) != 0) {
				continue;
			}
			came_from.emplace(tile_id(linked), current);
			queue.push_back(linked);
		}
	}
	return path;
}

DictRef hero_route_path_lengths(State &state, DictRef session, Vector2i start, const Value &goals) {
	const DictRef lengths = state.new_dict();
	const Vector2i size = derive_map_size(state, session);
	std::unordered_set<uint64_t> pending;
	for (const Value &goal_value : gd::items(state, goals)) {
		const Vector2i goal = as_vector2i(goal_value);
		if (goal.x < 0 || goal.y < 0 || goal.x >= size.x || goal.y >= size.y) {
			continue;
		}
		if (goal == start) {
			state.set(lengths, tile_value(goal), int_value(1));
		} else if (!hero_route_tile_blocked(state, session, goal.x, goal.y) || hero_route_destination(state, session, goal.x, goal.y)) {
			pending.insert(tile_id(goal));
		}
	}
	if (pending.empty()) {
		return lengths;
	}
	std::vector<Vector2i> queue{start};
	size_t queue_index = 0;
	TileMap<int64_t> path_sizes{{tile_id(start), 1}};
	const ArrayRef transit_edges = active_linked_transit_edges(state, session);
	const bool has_transit = state.array_size(transit_edges) != 0;
	while (queue_index < queue.size() && !pending.empty()) {
		const Vector2i current = queue[queue_index];
		queue_index += 1;
		const int64_t next_size = path_sizes.at(tile_id(current)) + 1;
		for (const Vector2i direction : kRouteDirections) {
			const Vector2i next = current + direction;
			if (next.x < 0 || next.y < 0 || next.x >= size.x || next.y >= size.y) {
				continue;
			}
			const uint64_t id = tile_id(next);
			const bool is_pending_goal = pending.count(id) != 0;
			if (path_sizes.count(id) != 0 && !is_pending_goal) {
				continue;
			}
			if (tile_step_cuts_blocked_corner(state, session, current, next)) {
				continue;
			}
			const bool blocked = hero_route_tile_blocked(state, session, next.x, next.y);
			if (is_pending_goal && (!blocked || hero_route_destination(state, session, next.x, next.y))) {
				state.set(lengths, tile_value(next), int_value(next_size));
				pending.erase(id);
			}
			if (path_sizes.count(id) != 0 || blocked || tile_has_route_interaction(state, session, next.x, next.y)) {
				continue;
			}
			path_sizes.emplace(id, next_size);
			queue.push_back(next);
		}
		if (!has_transit) {
			continue;
		}
		for (const Value &linked_next : gd::items(state, array_value(linked_transit_neighbors_from_edges(state, array_value(transit_edges), current)))) {
			if (!gd::is_vector2i(linked_next)) {
				continue;
			}
			const Vector2i linked = {linked_next.vx(), linked_next.vy()};
			const uint64_t id = tile_id(linked);
			if (pending.count(id) != 0) {
				state.set(lengths, linked_next, int_value(next_size));
				pending.erase(id);
			}
			if (path_sizes.count(id) != 0) {
				continue;
			}
			path_sizes.emplace(id, next_size);
			queue.push_back(linked);
		}
	}
	return lengths;
}

DictRef resource_node_interaction_at_tile(State &state, DictRef session, int64_t x, int64_t y, int64_t level) {
	const Value nodes = field_or_new_array(state, session_view::overworld(state, session), key::resource_nodes);
	const DictRef lookup_index = _spatial_lookup_index(state, session, level);
	for (const Value &node_index : gd::items(state, array_value(_spatial_lookup_entries(state, lookup_index, key::resource_by_interaction_tile, Vector2i::of(x, y))))) {
		const int64_t index = gd::to_int(state, node_index);
		const Value node = gd::is_array(nodes) && index >= 0 && index < state.array_size(nodes.ref) ? state.at(nodes.ref, index) : dict_value(state.new_dict());
		if (gd::is_dict(node) && resource_node_is_present(state, node.ref, gd::content_row(state, ContentTable::ResourceSite, ai::string_or_empty(state, node.ref, key::site_id)))) {
			return node.ref;
		}
	}
	return state.new_dict();
}

bool tile_step_cuts_blocked_corner(State &state, DictRef session, Vector2i from_tile, Vector2i to_tile, int64_t level) {
	const int64_t dx = static_cast<int64_t>(to_tile.x) - from_tile.x;
	const int64_t dy = static_cast<int64_t>(to_tile.y) - from_tile.y;
	if ((dx != 1 && dx != -1) || (dy != 1 && dy != -1)) {
		return false;
	}
	if (transit::uses_native_adjacency(state, dict_value(session))) {
		// Native RMG connectivity includes diagonal rock corridors. The move
		// owner still validates the destination's terrain, body and interaction.
		return false;
	}
	const Vector2i side_a = Vector2i::of(from_tile.x + dx, from_tile.y);
	const Vector2i side_b = Vector2i::of(from_tile.x, from_tile.y + dy);
	if (!hero_route_tile_blocked(state, session, side_a.x, side_a.y, level) || !hero_route_tile_blocked(state, session, side_b.x, side_b.y, level)) {
		return false;
	}
	// A doorway is an interaction endpoint within the town's exact source body.
	// Its own wall can border a legal diagonal ingress/egress; unrelated bodies
	// and impassable terrain still close the corner.
	const DictRef blocked = _blocked_tile_index(state, session, level);
	const DictRef lookup = _spatial_lookup_index(state, session, level);
	const ArrayRef towns = gd::as_array(field_or_new_array(state, session_view::overworld(state, session), key::towns));
	for (const Vector2i endpoint : {from_tile, to_tile}) {
		const Value town_by_tile = field_or_new_dict(state, lookup, key::town_by_tile);
		const int64_t town_index = gd::to_int(state, ai::vget(state, town_by_tile, _tile_key(state, endpoint), int_value(-1)));
		if (town_index < 0 || town_index >= state.array_size(towns)) {
			continue;
		}
		const DictRef town = gd::as_dict(state.at(towns, town_index));
		const DictRef entrance = sub_dict(state, town, key::visit_tile);
		if (gd::is_empty(state, entrance) || !_position_matches(state, entrance, endpoint)) {
			continue;
		}
		const Atom placement_id = ai::string_or_empty(state, town, key::placement_id);
		for (const Vector2i side : {side_a, side_b}) {
			const Value owner = state.get(blocked, str(_tile_key(state, side)), bool_value(true));
			if (owner.kind == Kind::String && owner.ref == placement_id && terrain_id_is_passable(state, _terrain_id_at(state, session, side.x, side.y, level))) {
				return false;
			}
		}
	}
	return true;
}

ArrayRef active_linked_transit_edges(State &state, DictRef session, int64_t level) {
	const ArrayRef edges = state.new_array();
	level = level_rules::query_level(state, session, level);
	const Vector2i map_size = derive_map_size(state, session);
	const Value resource_nodes = field_or_new_array(state, session_view::overworld(state, session), key::resource_nodes);
	if (!gd::is_array(resource_nodes)) {
		return edges;
	}
	for (const Value &node_value : gd::items(state, resource_nodes)) {
		if (!gd::is_dict(node_value) || !level_rules::on_level(state, node_value, level)) {
			continue;
		}
		const DictRef node = node_value.ref;
		if (transit::is_native(state, node)) {
			continue;
		}
		const DictRef site = gd::content_row(state, ContentTable::ResourceSite, ai::string_or_empty(state, node, key::site_id));
		if (gd::string_field(state, site, key::family, key::empty) != key::transit_object) {
			continue;
		}
		const DictRef transit_profile = sub_dict(state, site, key::transit_profile);
		const DictRef site_runtime = sub_dict(state, site, key::runtime_boundary);
		const DictRef site_route_boundary = sub_dict(state, site, key::route_effect_boundary);
		const DictRef site_contract = sub_dict(state, site, key::linked_endpoint_contract);
		if (!gd::bool_field(state, transit_profile, key::runtime_route_effect_adopted, false)
				|| !gd::bool_field(state, site_runtime, key::pathing_runtime_adopted, false)
				|| !gd::bool_field(state, site_runtime, key::route_effect_runtime_adopted, false)
				|| !gd::bool_field(state, site_route_boundary, key::runtime_behavior_adopted, false)
				|| !gd::bool_field(state, site_contract, key::runtime_route_effect_adopted, false)) {
			continue;
		}
		if (gd::bool_field(state, transit_profile, key::requires_repair, false) && !gd::bool_field(state, _resource_site_response_state(state, session, node, site), key::active, false)) {
			continue;
		}
		const DictRef map_object = _map_object_for_resource_node(state, node);
		const DictRef object_runtime = sub_dict(state, map_object, key::runtime_boundary);
		const DictRef object_route_boundary = sub_dict(state, map_object, key::route_effect_boundary);
		const DictRef object_contract = sub_dict(state, map_object, key::linked_endpoint_contract);
		const DictRef route_effect = sub_dict(state, map_object, key::route_effect);
		const DictRef approach = sub_dict(state, map_object, key::approach);
		if (gd::string_field(state, route_effect, key::effect_type, key::empty) != key::linked_endpoint
				|| gd::string_field(state, approach, key::mode, key::empty) != key::linked_endpoint
				|| !gd::bool_field(state, object_runtime, key::pathing_runtime_adopted, false)
				|| !gd::bool_field(state, object_runtime, key::route_effect_runtime_adopted, false)
				|| !gd::bool_field(state, object_route_boundary, key::runtime_behavior_adopted, false)
				|| !gd::bool_field(state, object_contract, key::runtime_route_effect_adopted, false)) {
			continue;
		}
		const Atom endpoint_group_id = gd::string_field(state, site_contract, key::endpoint_group_id, key::empty);
		const Atom directionality = gd::string_field(state, site_contract, key::directionality, key::empty);
		if (endpoint_group_id == key::empty
				|| endpoint_group_id != gd::string_field(state, object_contract, key::endpoint_group_id, key::empty)
				|| endpoint_group_id != gd::string_field(state, route_effect, key::linked_endpoint_group_id, key::empty)
				|| (directionality != key::two_way && directionality != key::one_way)
				|| directionality != gd::string_field(state, object_contract, key::directionality, key::empty)
				|| gd::bool_field(state, transit_profile, key::one_way, false) != (directionality == key::one_way)
				|| gd::bool_field(state, transit_profile, key::paired_link_required, false) != (directionality == key::two_way)
				|| !gd::bool_field(state, site_contract, key::requires_exit_safety, false)
				|| !gd::bool_field(state, object_contract, key::requires_exit_safety, false)) {
			continue;
		}
		if (gd::bool_field(state, route_effect, key::requires_visit, false) && !gd::bool_field(state, node, key::collected, false)) {
			continue;
		}
		if (gd::bool_field(state, route_effect, key::requires_owner, false) && ai::string_or_empty(state, node, key::collected_by_faction_id) != key::player) {
			continue;
		}
		if (!gd::is_empty(state, _normalize_resource_dict(state, field_or_new_dict(state, route_effect, key::toll_resources)))) {
			continue;
		}
		const ArrayRef blocked_state_ids = _string_array(state, field_or_new_array(state, route_effect, key::blocked_state_ids));
		const Atom route_state_id = string_or_other(state, node, key::route_state_id, key::state_id);
		if (route_state_id != key::empty && gd::array_has(state, blocked_state_ids, str(route_state_id))) {
			continue;
		}
		const Value entry_offsets = field_or_new_array(state, site_contract, key::entry_offsets);
		const Value exit_offsets = field_or_new_array(state, site_contract, key::exit_offsets);
		const Value object_entry_offsets = field_or_new_array(state, object_contract, key::entry_offsets);
		const Value object_exit_offsets = field_or_new_array(state, object_contract, key::exit_offsets);
		if (!gd::is_array(entry_offsets)
				|| state.array_size(entry_offsets.ref) != 2
				|| !gd::equal(state, entry_offsets, object_entry_offsets)
				|| !gd::is_array(exit_offsets)
				|| state.array_size(exit_offsets.ref) != 2
				|| !gd::equal(state, exit_offsets, object_exit_offsets)
				|| !gd::equal(state, exit_offsets, field_or_new_array(state, approach, key::linked_exit_offsets))) {
			continue;
		}
		if (directionality == key::two_way && !(gd::array_has(state, exit_offsets.ref, state.at(entry_offsets.ref, 0)) && gd::array_has(state, exit_offsets.ref, state.at(entry_offsets.ref, 1)))) {
			continue;
		}
		const Vector2i placement = Vector2i::of(gd::int_field(state, node, key::x, -1), gd::int_field(state, node, key::y, -1));
		Tiles endpoint_tiles;
		const Value directed_offsets[2] = {
			state.at(entry_offsets.ref, 0),
			directionality == key::two_way ? state.at(entry_offsets.ref, 1) : state.at(exit_offsets.ref, 0),
		};
		for (const Value &offset_value : directed_offsets) {
			if (!gd::is_dict(offset_value)) {
				endpoint_tiles.clear();
				break;
			}
			endpoint_tiles.push_back(placement + Vector2i::of(gd::int_field(state, offset_value.ref, key::x, 0), gd::int_field(state, offset_value.ref, key::y, 0)));
		}
		if (endpoint_tiles.size() != 2 || endpoint_tiles[0] == endpoint_tiles[1]) {
			continue;
		}
		const Vector2i from_tile = endpoint_tiles[0];
		const Vector2i to_tile = endpoint_tiles[1];
		const int64_t endpoint_distance = std::abs(static_cast<int64_t>(to_tile.x) - from_tile.x) + std::abs(static_cast<int64_t>(to_tile.y) - from_tile.y);
		const int64_t movement_cost = gd::add(endpoint_distance, gd::int_field(state, route_effect, key::movement_cost_delta, 0));
		if (movement_cost != 1) {
			continue;
		}
		bool endpoints_safe = true;
		const Tiles own_body_tiles = _map_object_world_body_tiles(state, map_object, node);
		const ArrayRef own_interaction_tiles = _resource_node_world_interaction_tiles(state, map_object, node);
		for (const Vector2i endpoint : endpoint_tiles) {
			if (endpoint.x < 0
					|| endpoint.y < 0
					|| endpoint.x >= map_size.x
					|| endpoint.y >= map_size.y
					|| (tile_is_blocked(state, session, endpoint.x, endpoint.y, level) && !tiles_have(own_body_tiles, endpoint))
					|| (tile_has_route_interaction(state, session, endpoint.x, endpoint.y, level) && !gd::array_has(state, own_interaction_tiles, tile_value(endpoint)))) {
				endpoints_safe = false;
				break;
			}
		}
		if (!endpoints_safe) {
			continue;
		}
		const DictRef edge = state.new_dict();
		state.set(edge, str(key::placement_id), str(ai::string_or_empty(state, node, key::placement_id)));
		state.set(edge, str(key::site_id), str(ai::string_or_empty(state, node, key::site_id)));
		state.set(edge, str(key::object_id), str(ai::string_or_empty(state, map_object, key::id)));
		state.set(edge, str(key::effect_id), str(ai::string_or_empty(state, route_effect, key::effect_id)));
		state.set(edge, str(key::endpoint_group_id), str(endpoint_group_id));
		state.set(edge, str(key::from_tile), tile_value(from_tile));
		state.set(edge, str(key::to_tile), tile_value(to_tile));
		state.set(edge, str(key::movement_cost), int_value(movement_cost));
		state.set(edge, str(key::directionality), str(directionality));
		state.set(edge, str(key::two_way), bool_value(directionality == key::two_way));
		state.append(edges, dict_value(edge));
	}
	return edges;
}

ArrayRef linked_transit_neighbors_from_edges(State &state, const Value &edges, Vector2i tile) {
	const ArrayRef neighbors = state.new_array();
	for (const Value &edge_value : gd::items(state, edges)) {
		if (!gd::is_dict(edge_value)) {
			continue;
		}
		const DictRef edge = edge_value.ref;
		if (gd::int_field(state, edge, key::movement_cost, 0) != 1) {
			continue;
		}
		const Vector2i from_tile = as_vector2i(state.get(edge, str(key::from_tile), Value::of_vector2i(-1, -1)));
		const Vector2i to_tile = as_vector2i(state.get(edge, str(key::to_tile), Value::of_vector2i(-1, -1)));
		if (tile == from_tile && !gd::array_has(state, neighbors, tile_value(to_tile))) {
			state.append(neighbors, tile_value(to_tile));
		} else if (gd::bool_field(state, edge, key::two_way, false) && tile == to_tile && !gd::array_has(state, neighbors, tile_value(from_tile))) {
			state.append(neighbors, tile_value(from_tile));
		}
	}
	return neighbors;
}

Atom active_linked_transit_signature(State &state, DictRef session) {
	// The shell's selected-route signature asks for this several times per
	// refresh, and each call rescans every resource node. A normalized read
	// scope guarantees the session is not changing, so compute it once there.
	Atom scope_key = key::empty;
	if (ai::static_int(state, key::overworld_rules_script, key::_normalized_read_scope_depth) > 0
			&& gd::stringify(state, gd::index(state, session, str(key::session_id))) == gd::stringify(state, gd::static_var(state, key::overworld_rules_script, key::_normalized_read_scope_session_id))) {
		scope_key = gd::format(state, key::d_active_linked_transit_signature, {int_value(session_view::instance_id(state, session))});
		const DictRef cache = ai::static_dict(state, key::overworld_rules_script, key::_normalized_read_scope_cache);
		Value cached;
		if (state.lookup(cache, str(scope_key), cached)) {
			return gd::stringify(state, cached);
		}
	}
	std::string rows;
	bool first = true;
	for (const Value &edge_value : gd::items(state, array_value(active_linked_transit_edges(state, session)))) {
		if (!gd::is_dict(edge_value)) {
			continue;
		}
		const DictRef edge = edge_value.ref;
		const Vector2i from_tile = as_vector2i(state.get(edge, str(key::from_tile), Value::of_vector2i(-1, -1)));
		const Vector2i to_tile = as_vector2i(state.get(edge, str(key::to_tile), Value::of_vector2i(-1, -1)));
		const Atom row = gd::format(state, key::s_s_d_d_d_d_d, {
				str(ai::string_or_empty(state, edge, key::placement_id)),
				str(ai::string_or_empty(state, edge, key::directionality)),
				int_value(from_tile.x),
				int_value(from_tile.y),
				int_value(to_tile.x),
				int_value(to_tile.y),
				int_value(gd::int_field(state, edge, key::movement_cost, 0)),
		});
		if (!first) {
			rows += state.text(key::semicolon);
		}
		first = false;
		rows += state.text(row);
	}
	const Atom signature = gd::format(state, key::linked_transit_s, {state.string(rows)});
	if (scope_key != key::empty) {
		state.set(ai::static_dict(state, key::overworld_rules_script, key::_normalized_read_scope_cache), str(scope_key), str(signature));
	}
	return signature;
}

DictRef route_movement_preview(State &state, const Value &session, const Value &route_tiles, int64_t movement_budget) {
	const Tiles path = _normalize_route_tiles(state, route_tiles);
	int64_t movement_current = 0;
	if (session.kind != Kind::Nil) {
		const Value movement = field_or_new_dict(state, session_view::overworld(state, gd::as_dict(session)), key::movement);
		if (gd::is_dict(movement)) {
			movement_current = gd::int_field(state, movement.ref, key::current, 0);
		}
	}
	int64_t budget = movement_budget < 0 ? movement_current : movement_budget;
	budget = std::max<int64_t>(0, budget);
	const int64_t total_steps = std::max<int64_t>(0, static_cast<int64_t>(path.size()) - 1);
	const int64_t reachable_steps = std::min(total_steps, budget);
	const ArrayRef reachable_tiles = state.new_array();
	for (int64_t index = 0; index < reachable_steps + 1; ++index) {
		if (index >= 0 && index < static_cast<int64_t>(path.size())) {
			state.append(reachable_tiles, dict_value(_route_tile_payload(state, path[static_cast<size_t>(index)])));
		}
	}
	const ArrayRef unreachable_tiles = state.new_array();
	for (int64_t index = reachable_steps + 1; index < static_cast<int64_t>(path.size()); ++index) {
		state.append(unreachable_tiles, dict_value(_route_tile_payload(state, path[static_cast<size_t>(index)])));
	}
	const Vector2i final_tile = reachable_steps >= 0 && reachable_steps < static_cast<int64_t>(path.size()) ? path[static_cast<size_t>(reachable_steps)] : Vector2i::of(-1, -1);
	const Vector2i destination_tile = !path.empty() ? path.back() : Vector2i::of(-1, -1);
	const DictRef preview = state.new_dict();
	state.set(preview, str(key::ok), bool_value(!path.empty()));
	state.set(preview, str(key::route_tiles), array_value(_route_tile_payloads(state, path)));
	state.set(preview, str(key::total_steps), int_value(total_steps));
	state.set(preview, str(key::total_cost), int_value(total_steps));
	state.set(preview, str(key::movement_budget), int_value(budget));
	state.set(preview, str(key::reachable_steps), int_value(reachable_steps));
	state.set(preview, str(key::reachable_cost), int_value(reachable_steps));
	state.set(preview, str(key::unreachable_steps), int_value(std::max<int64_t>(0, total_steps - reachable_steps)));
	state.set(preview, str(key::movement_after_reachable), int_value(std::max<int64_t>(0, budget - reachable_steps)));
	state.set(preview, str(key::destination_reachable), bool_value(total_steps > 0 && reachable_steps >= total_steps));
	state.set(preview, str(key::reachable_tiles), array_value(reachable_tiles));
	state.set(preview, str(key::unreachable_tiles), array_value(unreachable_tiles));
	state.set(preview, str(key::final_tile), dict_value(_route_tile_payload(state, final_tile)));
	state.set(preview, str(key::destination_tile), dict_value(_route_tile_payload(state, destination_tile)));
	return preview;
}

DictRef guard_engagement_encounter_at_tile(State &state, DictRef session, int64_t x, int64_t y, int64_t level) {
	return gd::as_dict(field_or_new_dict(state, _find_guard_engagement_at_tile(state, session, x, y, level), key::encounter));
}

ArrayRef guard_engagement_approach_route(State &state, DictRef session, DictRef encounter) {
	// The painted stack sits inside its terminal engagement ring. A player
	// selects the stack, but must walk only to the first legal combat entry.
	// One multi-target BFS avoids repeating a map-sized search for each entry.
	if (gd::is_empty(state, encounter) || is_encounter_resolved(state, session, encounter)) {
		return state.new_array();
	}
	const int64_t level = hero_level(state, session);
	if (!level_rules::on_level(state, dict_value(encounter), level)) {
		return state.new_array();
	}
	const Vector2i start = hero_position(state, session);
	const Vector2i anchor = Vector2i::of(gd::int_field(state, encounter, key::x, -1), gd::int_field(state, encounter, key::y, -1));
	std::unordered_set<uint64_t> targets;
	const Atom identity = encounter_key(state, encounter);
	ArrayRef engagement = _guard_engagement_world_tiles(state, encounter);
	if (state.array_size(engagement) == 0 && _ai_hero_guards_against_player(state, session, encounter)) {
		engagement = hero_guard_zone_tiles(state, session, anchor, level);
	}
	for (const Value &tile_entry : gd::items(state, array_value(engagement))) {
		const Vector2i tile = as_vector2i(tile_entry);
		if (tile_is_blocked(state, session, tile.x, tile.y, level) && !(tile == anchor)) {
			continue;
		}
		const DictRef owner = guard_engagement_encounter_at_tile(state, session, tile.x, tile.y, level);
		if (!gd::is_empty(state, owner) && encounter_key(state, owner) == identity) {
			targets.insert(tile_id(tile));
		}
	}
	if (targets.empty()) {
		return state.new_array();
	}
	const Vector2i size = derive_map_size(state, session);
	std::vector<Vector2i> queue{start};
	TileMap<Vector2i> parents{{tile_id(start), start}};
	size_t cursor = 0;
	Vector2i destination = Vector2i::of(-1, -1);
	const ArrayRef links = active_linked_transit_edges(state, session);
	const bool has_links = state.array_size(links) != 0;
	std::vector<Vector2i> neighbors;
	while (cursor < queue.size()) {
		const Vector2i current = queue[cursor];
		cursor += 1;
		if (targets.count(tile_id(current)) != 0) {
			destination = current;
			break;
		}
		neighbors.clear();
		for (const Vector2i offset : kRouteDirections) {
			const Vector2i next = current + offset;
			if (next.x < 0 || next.y < 0 || next.x >= size.x || next.y >= size.y || parents.count(tile_id(next)) != 0) {
				continue;
			}
			if (tile_step_cuts_blocked_corner(state, session, current, next, level)) {
				continue;
			}
			if (tile_is_blocked(state, session, next.x, next.y, level) && targets.count(tile_id(next)) == 0) {
				continue;
			}
			if (tile_has_route_interaction(state, session, next.x, next.y, level) && targets.count(tile_id(next)) == 0) {
				continue;
			}
			neighbors.push_back(next);
		}
		if (has_links) {
			for (const Value &linked : gd::items(state, array_value(linked_transit_neighbors_from_edges(state, array_value(links), current)))) {
				neighbors.push_back(as_vector2i(linked));
			}
		}
		for (const Vector2i next : neighbors) {
			if (parents.count(tile_id(next)) != 0) {
				continue;
			}
			parents.emplace(tile_id(next), current);
			queue.push_back(next);
		}
	}
	const ArrayRef path = state.new_array();
	if (destination == Vector2i::of(-1, -1)) {
		return path;
	}
	std::vector<Vector2i> walked{destination};
	while (!(walked.back() == start)) {
		walked.push_back(parents.at(tile_id(walked.back())));
	}
	for (auto tile = walked.rbegin(); tile != walked.rend(); ++tile) {
		state.append(path, tile_value(*tile));
	}
	return path;
}

DictRef blocking_object_feedback_surface_at_tile(State &state, DictRef session, int64_t x, int64_t y) {
	const Vector2i map_size = derive_map_size(state, session);
	const Vector2i tile = Vector2i::of(x, y);
	if (tile.x < 0 || tile.y < 0 || tile.x >= map_size.x || tile.y >= map_size.y) {
		return state.new_dict();
	}
	const DictRef overworld = session_view::overworld(state, session);
	for (const Value &object_value : gd::field_items(state, overworld, str(key::map_objects))) {
		if (!gd::is_dict(object_value)) {
			continue;
		}
		const DictRef object = object_value.ref;
		const Atom kind = ai::string_or_empty(state, object, key::kind);
		const Atom family = string_or_other(state, object, key::object_family_id, key::family_id);
		const bool blocks_body = gd::to_bool(state.get(object, str(key::blocking_body), bool_value(kind == key::decorative_obstacle || family == key::decorative_obstacle)));
		if (!tiles_have(_generated_body_tiles_for_placement(state, object, blocks_body), tile)) {
			continue;
		}
		const Atom object_id = gd::strip_edges(state, string_or_other(state, object, key::object_id, key::id));
		const DictRef map_object = object_id != key::empty ? gd::content_row(state, ContentTable::MapObject, object_id) : state.new_dict();
		Value name;
		if (!state.lookup(map_object, str(key::name), name)) {
			name = state.get(object, str(key::name), str(key::empty));
		}
		const Atom object_name = gd::strip_edges(state, gd::stringify(state, name));
		if (object_name == key::empty) {
			continue;
		}
		const DictRef surface = state.new_dict();
		state.set(surface, str(key::source), str(key::map_objects));
		state.set(surface, str(key::kind), str(key::map_object));
		state.set(surface, str(key::placement_id), str(ai::string_or_empty(state, object, key::placement_id)));
		state.set(surface, str(key::object_id), str(object_id));
		state.set(surface, str(key::site_id), str(key::empty));
		state.set(surface, str(key::name), str(object_name));
		state.set(surface, str(key::tile), dict_value(_tile_payload(state, tile)));
		return surface;
	}
	for (const Value &node_value : gd::field_items(state, overworld, str(key::resource_nodes))) {
		if (!gd::is_dict(node_value)) {
			continue;
		}
		const DictRef node = node_value.ref;
		const DictRef map_object = _map_object_for_resource_node(state, node);
		if (!_resource_node_blocks_body_tiles(state, node, map_object)) {
			continue;
		}
		if (!tiles_have(_map_object_world_body_tiles(state, map_object, node), tile)) {
			continue;
		}
		const Atom site_id = gd::strip_edges(state, ai::string_or_empty(state, node, key::site_id));
		const DictRef site = site_id != key::empty ? gd::content_row(state, ContentTable::ResourceSite, site_id) : state.new_dict();
		Value name;
		if (!state.lookup(map_object, str(key::name), name) && !state.lookup(site, str(key::name), name)) {
			name = state.get(node, str(key::name), str(key::empty));
		}
		const Atom object_name = gd::strip_edges(state, gd::stringify(state, name));
		if (object_name == key::empty) {
			continue;
		}
		const DictRef surface = state.new_dict();
		state.set(surface, str(key::source), str(key::resource_nodes));
		state.set(surface, str(key::kind), str(key::resource_body));
		state.set(surface, str(key::placement_id), str(ai::string_or_empty(state, node, key::placement_id)));
		// String(map_object.get("id", node.get("object_id", ""))).
		Value object_id;
		if (!state.lookup(map_object, str(key::id), object_id)) {
			object_id = state.get(node, str(key::object_id), str(key::empty));
		}
		state.set(surface, str(key::object_id), str(gd::stringify(state, object_id)));
		state.set(surface, str(key::site_id), str(site_id));
		state.set(surface, str(key::name), str(object_name));
		state.set(surface, str(key::tile), dict_value(_tile_payload(state, tile)));
		return surface;
	}
	return state.new_dict();
}

Tiles _normalize_route_tiles(State &state, const Value &route_tiles) {
	Tiles tiles;
	if (!gd::is_array(route_tiles)) {
		return tiles;
	}
	for (const Value &tile_value_entry : gd::items(state, route_tiles)) {
		const Vector2i tile = _route_tile_from_variant(state, tile_value_entry);
		if (tile.x < 0 || tile.y < 0) {
			continue;
		}
		tiles.push_back(tile);
	}
	return tiles;
}

Vector2i _route_tile_from_variant(State &state, const Value &value) {
	if (gd::is_vector2i(value)) {
		return {value.vx(), value.vy()};
	}
	if (value.kind == Kind::Opaque) {
		// A Vector2 (or another value the State does not model): no caller passes one.
		throw state::NotPorted("OverworldRules._route_tile_from_variant of a value the port does not model (a Vector2)");
	}
	if (gd::is_dict(value)) {
		return Vector2i::of(gd::int_field(state, value.ref, key::x, -1), gd::int_field(state, value.ref, key::y, -1));
	}
	return Vector2i::of(-1, -1);
}

DictRef _route_tile_payload(State &state, Vector2i tile) {
	return _tile_payload(state, tile);
}

ArrayRef _route_tile_payloads(State &state, const Tiles &tiles) {
	const ArrayRef payloads = state.new_array();
	for (const Vector2i tile : tiles) {
		if (tile.x < 0 || tile.y < 0) {
			continue;
		}
		state.append(payloads, dict_value(_route_tile_payload(state, tile)));
	}
	return payloads;
}

DictRef _tile_payload(State &state, Vector2i tile) {
	const DictRef payload = state.new_dict();
	state.set(payload, str(key::x), int_value(tile.x));
	state.set(payload, str(key::y), int_value(tile.y));
	return payload;
}

bool _position_matches(State &state, DictRef entry, Vector2i pos) {
	return gd::int_field(state, entry, key::x, -1) == pos.x && gd::int_field(state, entry, key::y, -1) == pos.y;
}

ArrayRef _string_array(State &state, const Value &value) {
	const ArrayRef strings = state.new_array();
	if (gd::is_array(value)) {
		for (const Value &item : gd::items(state, value)) {
			const Atom text = gd::strip_edges(state, gd::stringify(state, item));
			if (text != key::empty && !gd::array_has(state, strings, str(text))) {
				state.append(strings, str(text));
			}
		}
	}
	return strings;
}

} // namespace overworld_rules

} // namespace aurelion::rules::port
