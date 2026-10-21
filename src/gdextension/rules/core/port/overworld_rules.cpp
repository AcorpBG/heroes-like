// OverworldRules functions other ports share: the map size, the blocked-tile
// index with the scenery layers and resolved-encounter set the session's
// metadata caches, resource-node presence and the recruit payload.

#include "aurelion_rules/port/overworld_rules.hpp"

#include "aurelion_rules/port/mine_rules.hpp"
#include "aurelion_rules/port/native_transit_rules.hpp"
#include "aurelion_rules/port/overworld_level_rules.hpp"
#include "aurelion_rules/port/session_view.hpp"

#include "aurelion_rules/compat/godot_string.hpp"

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
using overworld_rules::Tiles;
using overworld_rules::Vector2i;
using state::ContentTable;
using state::State;
using state::Value;
namespace key = state::key;
namespace level_rules = overworld_level_rules;

// String(d.get(key, "")).
Atom string_or_empty(State &state, DictRef dict, Atom field) {
	return gd::to_string(state.get(dict, str(field), str(key::empty)));
}

// is_same(a, b) (Variant::identity_compare): a container is the same node;
// anything else compares as hash_compare does, its type first.
bool is_same(const State &state, const Value &a, const Value &b) {
	if (a.is_container() || b.is_container()) {
		return a.kind == b.kind && a.ref == b.ref;
	}
	return gd::hash_compare(state, a, b);
}

// session.get_meta(name, []) into a typed Array variable.
ArrayRef meta_array(State &state, DictRef session, Atom name) {
	Value found;
	if (state.lookup(session_view::meta(state, session), gd::name_value(name), found)) {
		return gd::as_array(found);
	}
	return state.new_array();
}

// value.get(field, fallback) of an untyped value: only a Dictionary has get()
// among the values these functions meet.
Value variant_get(State &state, const Value &value, Atom field, const Value &fallback) {
	if (!gd::is_dict(value)) {
		throw state::ScriptError(std::string("Invalid call. Nonexistent function 'get' in base '") + gd::type_name(value) + "'.");
	}
	return state.get(value.ref, str(field), fallback);
}

} // namespace

namespace overworld_rules {

bool _resource_site_is_persistent(State &state, DictRef site) {
	return gd::to_bool(gd::field_or(state, site, key::persistent_control, bool_value(false)));
}

Vector2i derive_map_size(State &state, DictRef session) {
	const DictRef overworld = session_view::overworld(state, session);
	Value stored_size;
	if (state.lookup(overworld, str(key::map_size), stored_size) && gd::is_dict(stored_size)) {
		const int64_t width = gd::int_field(state, stored_size.ref, key::width, 0);
		const int64_t height = gd::int_field(state, stored_size.ref, key::height, 0);
		if (width > 0 && height > 0) {
			return {static_cast<int32_t>(width), static_cast<int32_t>(height)};
		}
	}

	Value map_data;
	const bool has_map = state.lookup(overworld, str(key::map), map_data) && gd::is_array(map_data);
	const int64_t height_from_map = has_map ? state.array_size(map_data.ref) : 0;
	int64_t width_from_map = 0;
	if (height_from_map > 0) {
		const Value first_row = state.at(map_data.ref, 0);
		if (gd::is_array(first_row)) {
			width_from_map = state.array_size(first_row.ref);
		}
	}
	return {static_cast<int32_t>(compat::engine_max<int64_t>(width_from_map, 1)), static_cast<int32_t>(compat::engine_max<int64_t>(height_from_map, 1))};
}

DictRef _build_blocked_tile_index(State &state, DictRef session, int64_t level, Atom ignore_actor_id, DictRef combat_defenders) {
	const DictRef index = state.new_dict();
	level = level_rules::query_level(state, session, level);
	const DictRef overworld = session_view::overworld(state, session);
	for (const Value &town_value : gd::field_items(state, overworld, str(key::towns))) {
		if (!gd::is_dict(town_value)) {
			continue;
		}
		if (!level_rules::on_level(state, town_value, level)) {
			continue;
		}
		// Nonempty strings retain exclusive town-wall ownership for doorway
		// corner checks. Membership remains the authoritative blocking bit.
		// Any overlapping town or non-town body replaces this token with true.
		const Atom town_id = string_or_empty(state, town_value.ref, key::placement_id);
		for (const Vector2i tile : _generated_body_tiles_for_placement(state, town_value.ref, true)) {
			const Value tile_key = str(_tile_key(state, tile));
			state.set(index, tile_key, town_id != key::empty && !state.has(index, tile_key) ? str(town_id) : bool_value(true));
		}
	}
	for (const Value &encounter_value : gd::field_items(state, overworld, str(key::encounters))) {
		if (!gd::is_dict(encounter_value)) {
			continue;
		}
		const DictRef encounter = encounter_value.ref;
		if (ignore_actor_id != key::empty && string_or_empty(state, encounter, key::placement_id) == ignore_actor_id) {
			continue;
		}
		if (state.has(combat_defenders, str(encounter_key(state, encounter)))) {
			continue;
		}
		if (!level_rules::on_level(state, encounter_value, level) || is_encounter_resolved(state, session, encounter)) {
			continue;
		}
		_append_generated_body_tiles_to_blocked_index(state, index, encounter, gd::bool_field(state, encounter, key::blocking_body, true));
	}
	// The same keys set to true, in the same order, as walking the objects here.
	gd::merge(state, index, _blocked_scenery_layer(state, session, level), true);
	for (const Value &node_value : gd::field_items(state, overworld, str(key::resource_nodes))) {
		if (!gd::is_dict(node_value)) {
			continue;
		}
		const DictRef node = node_value.ref;
		if (!level_rules::on_level(state, node_value, level)) {
			continue;
		}
		Tiles body_tiles;
		const Value package_mask = state.get(node, str(key::package_block_tiles), Value());
		if (mine_rules::resource(state, node) != key::empty) {
			if (!resource_node_is_present(state, node, state.new_dict())) {
				continue;
			}
			body_tiles = mine_rules::block_tiles(state, node);
		} else if (gd::is_array(package_mask)) {
			// Package masks already override authored geometry, including an
			// explicitly empty mask. Preserve presence and decode only once;
			// resolving a content definition cannot affect this branch.
			if (!resource_node_is_present(state, node, state.new_dict())) {
				continue;
			}
			body_tiles = _world_tiles_from_payload_array(state, package_mask);
		} else {
			const DictRef map_object = _map_object_for_resource_node(state, node);
			if (!_resource_node_blocks_body_tiles(state, node, map_object)) {
				continue;
			}
			body_tiles = _map_object_world_body_tiles(state, map_object, node);
		}
		for (const Vector2i body_tile : body_tiles) {
			const Value tile_key = str(_tile_key(state, body_tile));
			const Atom id = string_or_empty(state, node, key::placement_id);
			const bool own = native_transit_rules::is_native(state, node) && id != key::empty && !state.has(index, tile_key);
			state.set(index, tile_key, own ? str(id) : bool_value(true));
		}
	}
	return index;
}

DictRef _blocked_scenery_layer(State &state, DictRef session, int64_t level) {
	const DictRef overworld = session_view::overworld(state, session);
	const Value objects = state.get(overworld, str(key::map_objects), array_value(state.new_array()));
	if (!gd::is_array(objects)) {
		return _build_blocked_scenery_layer(state, objects, level);
	}
	// [list, a shallow copy of it, level -> layer]. Comparing the copy is cheap:
	// an entry that is still the same dictionary compares equal at once.
	ArrayRef cached = meta_array(state, session, key::overworld_blocked_scenery_layers);
	if (state.array_size(cached) != 3 || !is_same(state, state.at(cached, 0), objects) || !gd::equal(state, state.at(cached, 1), objects)) {
		cached = state.new_array();
		state.append(cached, objects);
		state.append(cached, array_value(gd::duplicate_array(state, objects.ref)));
		state.append(cached, dict_value(state.new_dict()));
		state.set(session_view::meta(state, session), gd::name_value(key::overworld_blocked_scenery_layers), array_value(cached));
	}
	const DictRef layers = gd::as_dict(state.at(cached, 2));
	const Value level_key = int_value(level);
	if (!state.has(layers, level_key)) {
		state.set(layers, level_key, dict_value(_build_blocked_scenery_layer(state, objects, level)));
	}
	return gd::as_dict(gd::index(state, layers, level_key));
}

DictRef _build_blocked_scenery_layer(State &state, const Value &objects, int64_t level) {
	const DictRef layer = state.new_dict();
	for (const Value &object_value : gd::items(state, objects)) {
		if (!gd::is_dict(object_value)) {
			continue;
		}
		const DictRef object = object_value.ref;
		if (!level_rules::on_level(state, object_value, level)) {
			continue;
		}
		const Atom kind = string_or_empty(state, object, key::kind);
		const Value family_fallback = state.get(object, str(key::family_id), str(key::empty));
		const Atom family = gd::to_string(state.get(object, str(key::object_family_id), family_fallback));
		const bool blocks_body = gd::to_bool(state.get(object, str(key::blocking_body), bool_value(kind == key::decorative_obstacle || family == key::decorative_obstacle)));
		_append_generated_body_tiles_to_blocked_index(state, layer, object, blocks_body);
	}
	return layer;
}

void _append_generated_body_tiles_to_blocked_index(State &state, DictRef index, DictRef placement, bool blocks_body) {
	for (const Vector2i body_tile : _generated_body_tiles_for_placement(state, placement, blocks_body)) {
		state.set(index, str(_tile_key(state, body_tile)), bool_value(true));
	}
}

Tiles _generated_body_tiles_for_placement(State &state, DictRef placement, bool blocks_body) {
	if (!blocks_body) {
		return {};
	}
	const Value block_payload = state.get(placement, str(key::package_block_tiles), Value());
	Tiles body_tiles = gd::is_array(block_payload) ? _world_tiles_from_payload_array(state, block_payload) : Tiles();
	if (body_tiles.empty() && gd::is_array(block_payload)) {
		return {};
	}
	if (body_tiles.empty()) {
		body_tiles = _world_tiles_from_payload_array(state, state.get(placement, str(key::body_tiles), array_value(state.new_array())));
	}
	if (body_tiles.empty()) {
		const int64_t x = gd::int_field(state, placement, key::x, -1);
		body_tiles.push_back(Vector2i::of(x, gd::int_field(state, placement, key::y, -1)));
	}
	Tiles valid_tiles;
	for (const Vector2i body_tile : body_tiles) {
		if (body_tile.x >= 0 && body_tile.y >= 0) {
			valid_tiles.push_back(body_tile);
		}
	}
	return valid_tiles;
}

Tiles _world_tiles_from_payload_array(State &state, const Value &payload) {
	Tiles tiles;
	if (!gd::is_array(payload)) {
		return tiles;
	}
	for (const Value &value : gd::items(state, payload)) {
		if (!gd::is_dict(value)) {
			continue;
		}
		const int64_t x = gd::int_field(state, value.ref, key::x, 0);
		tiles.push_back(Vector2i::of(x, gd::int_field(state, value.ref, key::y, 0)));
	}
	return tiles;
}

Atom _tile_key(State &state, Vector2i tile) {
	return state.pair_atom(tile.x, tile.y);
}

DictRef _map_object_for_resource_node(State &state, DictRef node) {
	const Atom object_id = gd::strip_edges(state, string_or_empty(state, node, key::object_id));
	if (object_id != key::empty) {
		const DictRef direct = gd::content_row(state, ContentTable::MapObject, object_id);
		if (!gd::is_empty(state, direct)) {
			return direct;
		}
	}
	return gd::content_row(state, ContentTable::MapObjectForResourceSite, string_or_empty(state, node, key::site_id));
}

namespace {

// passability_class in [...] of the two passable classes and the blocking ones.
bool passable_class(Atom passability_class) {
	return passability_class == key::passable_visit_on_enter || passability_class == key::passable_scenic;
}

bool blocking_class(Atom passability_class) {
	return passability_class == key::blocking_visitable || passability_class == key::blocking_non_visitable ||
			passability_class == key::edge_blocker || passability_class == key::conditional_pass ||
			passability_class == key::town_blocking || passability_class == key::neutral_stack_blocking;
}

} // namespace

bool _map_object_blocks_body_tiles(State &state, DictRef map_object) {
	const Value body_tiles = state.get(map_object, str(key::body_tiles), array_value(state.new_array()));
	if (!gd::is_array(body_tiles) || state.array_size(body_tiles.ref) == 0) {
		return false;
	}
	const Atom passability_class = string_or_empty(state, map_object, key::passability_class);
	if (passable_class(passability_class)) {
		return false;
	}
	if (blocking_class(passability_class)) {
		return true;
	}
	return !gd::bool_field(state, map_object, key::passable, true);
}

bool _resource_node_blocks_body_tiles(State &state, DictRef node, DictRef map_object) {
	// Source masks describe the original placement, not its consumed lifetime.
	// Keep them immutable while removing occupancy with the vanished pickup.
	if (!resource_node_is_present(state, node, state.new_dict())) {
		return false;
	}
	if (mine_rules::resource(state, node) != key::empty) {
		return true;
	}
	if (gd::is_array(state.get(node, str(key::package_block_tiles), Value()))) {
		return !_world_tiles_from_payload_array(state, state.get(node, str(key::package_block_tiles), array_value(state.new_array()))).empty();
	}
	if (gd::is_empty(state, map_object)) {
		return gd::bool_field(state, node, key::blocking_body, false);
	}
	const Atom passability_class = string_or_empty(state, map_object, key::passability_class);
	if (passable_class(passability_class)) {
		return false;
	}
	if (_resource_node_has_runtime_object_contract(state, node)) {
		return gd::to_bool(state.get(node, str(key::blocking_body), bool_value(_map_object_blocks_body_tiles(state, map_object))));
	}
	return _map_object_blocks_body_tiles(state, map_object);
}

Tiles _map_object_world_body_tiles(State &state, DictRef map_object, DictRef placement) {
	if (mine_rules::resource(state, placement) != key::empty) {
		return mine_rules::block_tiles(state, placement);
	}
	if (gd::is_array(state.get(placement, str(key::package_block_tiles), Value()))) {
		Tiles package_tiles = _world_tiles_from_payload_array(state, state.get(placement, str(key::package_block_tiles), array_value(state.new_array())));
		if (!package_tiles.empty()) {
			return package_tiles;
		}
	}
	if (_resource_node_has_runtime_object_contract(state, placement)) {
		Tiles runtime_tiles = _world_tiles_from_payload_array(state, state.get(placement, str(key::package_block_tiles), array_value(state.new_array())));
		if (!runtime_tiles.empty()) {
			return runtime_tiles;
		}
		runtime_tiles = _world_tiles_from_payload_array(state, state.get(placement, str(key::body_tiles), array_value(state.new_array())));
		if (!runtime_tiles.empty()) {
			return runtime_tiles;
		}
	}
	Tiles tiles;
	const Vector2i origin = _map_object_footprint_origin(state, map_object, placement);
	const Value body_tiles = state.get(map_object, str(key::body_tiles), array_value(state.new_array()));
	if (!gd::is_array(body_tiles)) {
		return tiles;
	}
	for (const Value &body_value : gd::items(state, body_tiles)) {
		if (!gd::is_dict(body_value)) {
			continue;
		}
		const int64_t x = gd::int_field(state, body_value.ref, key::x, 0);
		tiles.push_back(origin + Vector2i::of(x, gd::int_field(state, body_value.ref, key::y, 0)));
	}
	return tiles;
}

bool _resource_node_has_runtime_object_contract(State &state, DictRef node) {
	const Value ref = state.get(node, str(key::object_footprint_catalog_ref), dict_value(state.new_dict()));
	if (!gd::is_dict(ref)) {
		return false;
	}
	// The second get() is the one is_empty() reads: the same value.
	return !gd::is_empty(state, ref.ref);
}

Vector2i _map_object_footprint_origin(State &state, DictRef map_object, DictRef placement) {
	if (mine_rules::resource(state, placement) != key::empty) {
		return mine_rules::origin(state, placement);
	}
	const Value footprint_value = state.get(map_object, str(key::footprint), dict_value(state.new_dict()));
	const DictRef footprint = gd::is_dict(footprint_value) ? footprint_value.ref : state.new_dict();
	const int64_t width = compat::engine_max<int64_t>(1, gd::int_field(state, footprint, key::width, 1));
	const int64_t height = compat::engine_max<int64_t>(1, gd::int_field(state, footprint, key::height, 1));
	const Atom anchor = gd::to_string(state.get(footprint, str(key::anchor), str(key::bottom_center)));
	const int64_t x = gd::int_field(state, placement, key::x, 0);
	const Vector2i anchor_tile = Vector2i::of(x, gd::int_field(state, placement, key::y, 0));
	if (anchor == key::top_left) {
		return anchor_tile;
	}
	if (anchor == key::center) {
		return anchor_tile - Vector2i::of(width / 2, height / 2);
	}
	if (anchor == key::bottom_left) {
		return anchor_tile - Vector2i::of(0, gd::sub(height, 1));
	}
	if (anchor == key::bottom_right) {
		return anchor_tile - Vector2i::of(gd::sub(width, 1), gd::sub(height, 1));
	}
	return anchor_tile - Vector2i::of(width / 2, gd::sub(height, 1));
}

bool resource_node_is_present(State &state, DictRef node, DictRef site) {
	// Shared by collision, route/context queries and the map renderer. Ownership
	// and cooldowns do not consume a permanent service or a native passage.
	if (!gd::bool_field(state, node, key::collected, false) || native_transit_rules::is_native(state, node)) {
		return true;
	}
	if (gd::is_empty(state, site)) {
		site = gd::content_row(state, ContentTable::ResourceSite, string_or_empty(state, node, key::site_id));
	}
	if (_resource_site_is_persistent(state, site) || _resource_site_is_repeatable(state, site)) {
		return true;
	}
	// A one-time site whose object stays after its visit (a looted guarded bank,
	// an opened route camp) remains in its claimed state; pickups are taken.
	const Value interaction = state.get(_map_object_for_resource_node(state, node), str(key::interaction), dict_value(state.new_dict()));
	return gd::to_bool(variant_get(state, interaction, key::remains_after_visit, bool_value(false)));
}

bool _resource_site_is_repeatable(State &state, DictRef site) {
	return gd::bool_field(state, site, key::repeatable, false) || string_or_empty(state, site, key::family) == key::repeatable_service;
}

bool is_encounter_resolved(State &state, DictRef session, DictRef encounter) {
	const DictRef overworld = session_view::overworld(state, session);
	const Value resolved = state.get(overworld, str(key::resolved_encounters), array_value(state.new_array()));
	if (!gd::is_array(resolved)) {
		return false;
	}
	const ArrayRef cached = _resolved_lookup_entry(state, session);
	if (!gd::to_bool(state.at(cached, 3))) {
		return gd::in(state, str(encounter_key(state, encounter)), resolved);
	}
	return state.has(gd::as_dict(state.at(cached, 2)), str(encounter_key(state, encounter)));
}

ArrayRef _resolved_lookup_entry(State &state, DictRef session) {
	const DictRef overworld = session_view::overworld(state, session);
	const Value resolved = state.get(overworld, str(key::resolved_encounters), array_value(state.new_array()));
	const int64_t size = gd::is_array(resolved) ? state.array_size(resolved.ref) : -1;
	ArrayRef cached = meta_array(state, session, key::overworld_resolved_encounter_lookup);
	if (state.array_size(cached) == 4 && is_same(state, state.at(cached, 0), resolved) && gd::to_int(state, state.at(cached, 1)) == size) {
		return cached;
	}
	const DictRef lookup = state.new_dict();
	bool strings_only = true;
	if (gd::is_array(resolved)) {
		for (const Value &value : gd::items(state, resolved)) {
			state.set(lookup, str(gd::to_string(value)), bool_value(true));
			if (!value.is_string_like()) {
				strings_only = false;
			}
		}
	}
	cached = state.new_array();
	state.append(cached, resolved);
	state.append(cached, int_value(size));
	state.append(cached, dict_value(lookup));
	state.append(cached, bool_value(strings_only));
	state.set(session_view::meta(state, session), gd::name_value(key::overworld_resolved_encounter_lookup), array_value(cached));
	return cached;
}

Atom encounter_key(State &state, DictRef encounter) {
	const Atom placement_id = string_or_empty(state, encounter, key::placement_id);
	if (placement_id != key::empty) {
		return placement_id;
	}
	const int64_t x = gd::int_field(state, encounter, key::x, -1);
	const int64_t y = gd::int_field(state, encounter, key::y, -1);
	const Value id_fallback = state.get(encounter, str(key::id), str(key::empty));
	const Atom encounter_id = gd::to_string(state.get(encounter, str(key::encounter_id), id_fallback));
	return state.intern(compat::itos(x) + "," + compat::itos(y) + "," + state.text(encounter_id));
}

DictRef _normalize_recruit_payload(State &state, const Value &value) {
	const DictRef normalized = state.new_dict();
	if (gd::is_dict(value)) {
		for (const Value &unit_id_value : gd::items(state, array_value(gd::keys(state, value.ref)))) {
			const Atom unit_id = gd::to_string(unit_id_value);
			const int64_t count = compat::engine_max<int64_t>(0, gd::to_int(state, state.get(value.ref, unit_id_value, int_value(0))));
			if (unit_id == key::empty || count <= 0) {
				continue;
			}
			state.set(normalized, str(unit_id), int_value(count));
		}
	}
	return normalized;
}

} // namespace overworld_rules

} // namespace aurelion::rules::port
