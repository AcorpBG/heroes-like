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

} // namespace aurelion::rules::port::overworld_level_rules
