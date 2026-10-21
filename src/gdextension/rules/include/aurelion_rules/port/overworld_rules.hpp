#pragma once

// scripts/core/OverworldRules.gd, ported function by function under the GDScript
// names (docs/native-rules-engine-transition.md, Phase 5). A session is its view
// (session_view.hpp). The debug rules profile (_rules_profile_*) is not recorded.

#include "aurelion_rules/port/gd.hpp"

#include <cstdint>
#include <vector>

namespace aurelion::rules::port::overworld_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using state::State;
using state::Value;

// A Vector2i: its components are 32-bit, read as int, and wrap like Godot's.
struct Vector2i {
	int32_t x = 0;
	int32_t y = 0;

	// Vector2i(int(a), int(b)): each int cut to 32 bits.
	static Vector2i of(int64_t x, int64_t y) { return {static_cast<int32_t>(x), static_cast<int32_t>(y)}; }
	Vector2i operator+(Vector2i other) const {
		return {static_cast<int32_t>(static_cast<uint32_t>(x) + static_cast<uint32_t>(other.x)), static_cast<int32_t>(static_cast<uint32_t>(y) + static_cast<uint32_t>(other.y))};
	}
	Vector2i operator-(Vector2i other) const {
		return {static_cast<int32_t>(static_cast<uint32_t>(x) - static_cast<uint32_t>(other.x)), static_cast<int32_t>(static_cast<uint32_t>(y) - static_cast<uint32_t>(other.y))};
	}
	bool operator==(Vector2i other) const { return x == other.x && y == other.y; }
};

// An Array of Vector2i that stays inside the native call.
using Tiles = std::vector<Vector2i>;

// The map size (overworld_rules.cpp).
Vector2i derive_map_size(State &state, DictRef session);

// The blocked-tile index: the tiles each map level's towns, encounters, scenery
// and resource nodes stand on (overworld_rules.cpp).
DictRef _build_blocked_tile_index(State &state, DictRef session, int64_t level, Atom ignore_actor_id, DictRef combat_defenders);
DictRef _blocked_scenery_layer(State &state, DictRef session, int64_t level);
DictRef _build_blocked_scenery_layer(State &state, const Value &objects, int64_t level);
void _append_generated_body_tiles_to_blocked_index(State &state, DictRef index, DictRef placement, bool blocks_body);
Tiles _generated_body_tiles_for_placement(State &state, DictRef placement, bool blocks_body);
Tiles _world_tiles_from_payload_array(State &state, const Value &payload);
Atom _tile_key(State &state, Vector2i tile);
DictRef _map_object_for_resource_node(State &state, DictRef node);
bool _map_object_blocks_body_tiles(State &state, DictRef map_object);
bool _resource_node_blocks_body_tiles(State &state, DictRef node, DictRef map_object);
Tiles _map_object_world_body_tiles(State &state, DictRef map_object, DictRef placement);
bool _resource_node_has_runtime_object_contract(State &state, DictRef node);
Vector2i _map_object_footprint_origin(State &state, DictRef map_object, DictRef placement);
// resource_node_is_present(node, site = {}): an empty site is looked up.
bool resource_node_is_present(State &state, DictRef node, DictRef site);
bool _resource_site_is_repeatable(State &state, DictRef site);
bool _resource_site_is_persistent(State &state, DictRef site);
bool is_encounter_resolved(State &state, DictRef session, DictRef encounter);
ArrayRef _resolved_lookup_entry(State &state, DictRef session);
Atom encounter_key(State &state, DictRef encounter);

// A recruit payload: unit id -> a positive count (overworld_rules.cpp).
DictRef _normalize_recruit_payload(State &state, const Value &value);

// Fog of war (fog.cpp).
void refresh_fog_of_war(State &state, DictRef session);
void _normalize_fog_of_war(State &state, DictRef session);
DictRef fog_for_level(State &state, DictRef session, int64_t level);
ArrayRef _normalize_visibility_grid(State &state, const Value &value, Vector2i map_size);
ArrayRef _blank_visibility_grid(State &state, Vector2i map_size, bool fill_value);
ArrayRef _merge_visibility_grids(State &state, ArrayRef base, ArrayRef overlay, Vector2i map_size);
ArrayRef _duplicate_visibility_grid(State &state, ArrayRef grid);
DictRef _build_fog_payload(State &state, ArrayRef visible_tiles, ArrayRef explored_tiles, Vector2i map_size);
int64_t _count_grid(State &state, const Value &grid);
void _reveal_all_current_fog_sources(State &state, DictRef session, ArrayRef explored_tiles, Vector2i map_size, int64_t level);
void _apply_hero_reveal(State &state, ArrayRef explored_tiles, DictRef hero, Vector2i map_size);
void _apply_site_reveal(State &state, ArrayRef explored_tiles, DictRef site_state, int64_t radius, Vector2i map_size);
void _set_grid_cell(State &state, ArrayRef grid, int64_t x, int64_t y, bool value);
int64_t held_site_vision_radius(State &state, DictRef site);
int64_t hero_level(State &state, DictRef session);

// The resource nodes, rebuilt with their known fields (overworld_normalize.cpp).
ArrayRef _normalize_resource_nodes(State &state, ArrayRef nodes);
void _copy_resource_runtime_metadata(State &state, DictRef target, DictRef source);
DictRef _normalize_delivery_completion_counts(State &state, const Value &value);

} // namespace aurelion::rules::port::overworld_rules
