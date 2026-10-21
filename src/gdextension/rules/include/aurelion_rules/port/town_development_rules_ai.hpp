#pragma once

// scripts/core/TownDevelopmentRules.gd
// (docs/native-rules-engine-transition.md, Phase 3: the AI targets), ported
// function by function under the GDScript names. A session is its view
// (session_view.hpp).

#include "aurelion_rules/port/gd.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"

#include <cstdint>

namespace aurelion::rules::port::town_development_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using gd::PackedRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// Ported in town_development_rules_ai.cpp.
DictRef data(State &state);
Atom faction_id(State &state, DictRef town);
bool is_current(State &state, DictRef town);
void _sync_memo_sources(State &state);
DictRef satisfied_ids(State &state, ArrayRef built);
DictRef _satisfied_ids(State &state, ArrayRef built);
ArrayRef active_buildings(State &state, DictRef town);
ArrayRef _compute_active_buildings(State &state, DictRef town);
bool choice_blocked_among(State &state, ArrayRef active, DictRef building);
bool has_dwelling_tier_among(State &state, ArrayRef active, int64_t tier);
DictRef growth(State &state, DictRef town);
DictRef income(State &state, DictRef town);

bool choice_blocked(State &state, DictRef town, DictRef building);
bool has_dwelling_tier(State &state, DictRef town, int64_t tier);

} // namespace aurelion::rules::port::town_development_rules
