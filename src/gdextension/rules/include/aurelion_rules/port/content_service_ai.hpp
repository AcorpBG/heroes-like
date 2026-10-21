#pragma once

// scripts/autoload/ContentService.gd
// (docs/native-rules-engine-transition.md, Phase 3: the AI targets), ported
// function by function under the GDScript names. A session is its view
// (session_view.hpp).

#include "aurelion_rules/port/gd.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"

#include <cstdint>

namespace aurelion::rules::port::content_service {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using gd::PackedRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// Ported in content_service_ai.cpp.
Atom normalize_terrain_id(State &state, Atom terrain_id);

DictRef default_ai_hero_weights(State &state);

} // namespace aurelion::rules::port::content_service
