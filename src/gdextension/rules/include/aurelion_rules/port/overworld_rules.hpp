#pragma once

// scripts/core/OverworldRules.gd, ported function by function under the GDScript
// names (docs/native-rules-engine-transition.md, Phase 5). A session is its view
// (day_view.hpp). The debug rules profile (_rules_profile_*) is not recorded.

#include "aurelion_rules/port/gd.hpp"

#include <cstdint>

namespace aurelion::rules::port::overworld_rules {

using gd::ArrayRef;
using gd::DictRef;
using state::State;
using state::Value;

// A Vector2i: its components are 32-bit, read as int.
struct Vector2i {
	int32_t x = 0;
	int32_t y = 0;
};

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
bool _resource_site_is_persistent(State &state, DictRef site);

// The map (fog.cpp).
Vector2i derive_map_size(State &state, DictRef session);
int64_t hero_level(State &state, DictRef session);

} // namespace aurelion::rules::port::overworld_rules
