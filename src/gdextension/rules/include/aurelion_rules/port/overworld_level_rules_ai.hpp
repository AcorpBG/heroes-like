#pragma once

// scripts/core/OverworldLevelRules.gd
// (docs/native-rules-engine-transition.md, Phase 3: the AI targets), ported
// function by function under the GDScript names. A session is its view
// (session_view.hpp). Phase 5's ports of the script are in overworld_level_rules.hpp.

#include "aurelion_rules/port/gd.hpp"
#include "aurelion_rules/port/overworld_level_rules.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"

#include <cstdint>

namespace aurelion::rules::port::overworld_level_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using gd::PackedRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// Ported in overworld_level_rules_ai.cpp.
bool same_level(State &state, const Value &a, const Value &b);
ArrayRef terrain_rows(State &state, const Value &session, int64_t requested = -1);

// One level's terrain as terrain_rows reads it, tile by tile: the surface's
// rows, or a deeper level's codes and the ids they index. Unlike terrain_rows it
// builds no rows and fills no OverworldLevelRules._terrain_rows, so a call that
// must not write (the route preview) can ask for it.
struct TerrainGrid {
	ArrayRef rows = 0; // the surface's rows, or an empty array; set by terrain_grid
	Value codes;
	Value ids;
	int64_t width = 0;
	int64_t height = 0;
	bool coded = false; // a deeper level: codes and ids, width by height
};
TerrainGrid terrain_grid(State &state, const Value &session, int64_t requested = -1);
// The terrain id of a tile, rock off the grid, as terrain_rows would give it.
Atom terrain_grid_at(State &state, const TerrainGrid &grid, int64_t x, int64_t y);

} // namespace aurelion::rules::port::overworld_level_rules
