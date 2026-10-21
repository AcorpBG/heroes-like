#pragma once

// scripts/core/CommonMineRules.gd, ported function by function under the
// GDScript names (docs/native-rules-engine-transition.md, Phase 5): a mine's
// resource and its three-by-two body.

#include "aurelion_rules/port/gd.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"

namespace aurelion::rules::port::common_mine_rules {

using gd::Atom;
using gd::DictRef;
using overworld_rules::Tiles;
using overworld_rules::Vector2i;
using state::State;

Atom resource(State &state, DictRef node);
Vector2i entry_tile(State &state, DictRef node);
Vector2i origin(State &state, DictRef node);
Tiles body_tiles(State &state, DictRef node);
Tiles block_tiles(State &state, DictRef node);

} // namespace aurelion::rules::port::common_mine_rules
