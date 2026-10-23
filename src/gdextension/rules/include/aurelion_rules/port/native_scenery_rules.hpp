#pragma once

// scripts/persistence/NativeSceneryRules.gd, ported function by function
// under the GDScript names (docs/native-rules-engine-transition.md, Phase 7,
// 7.11; native_scenery_rules.cpp): which random map objects are scenery and
// whether the art covers them. policy and asset_candidates keep their
// GDScript copies too, for the overworld map's drawing: a behaviour change to
// one goes into both copies in the same commit.

#include "aurelion_rules/port/gd.hpp"

namespace aurelion::rules::port::native_scenery_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using state::State;

ArrayRef asset_candidates(State &state, DictRef object, Atom biome_id, Atom terrain_id = state::key::empty);
DictRef policy(State &state, DictRef object);
bool is_scenery(State &state, DictRef object);
DictRef validate(State &state, ArrayRef objects);

} // namespace aurelion::rules::port::native_scenery_rules
