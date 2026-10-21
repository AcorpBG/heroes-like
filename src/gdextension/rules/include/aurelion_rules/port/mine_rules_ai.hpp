#pragma once

// scripts/core/MineRules.gd
// (docs/native-rules-engine-transition.md, Phase 3: the AI targets), ported
// function by function under the GDScript names. A session is its view
// (session_view.hpp). Phase 5's ports of the script are in mine_rules.hpp.

#include "aurelion_rules/port/gd.hpp"
#include "aurelion_rules/port/mine_rules.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"

#include <cstdint>

namespace aurelion::rules::port::mine_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using gd::PackedRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// Ported in mine_rules_ai.cpp.
Vector2i entry_tile(State &state, DictRef node);

} // namespace aurelion::rules::port::mine_rules
