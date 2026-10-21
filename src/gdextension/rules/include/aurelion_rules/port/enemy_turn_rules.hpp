#pragma once

// scripts/core/EnemyTurnRules.gd, ported function by function under the
// GDScript names (docs/native-rules-engine-transition.md, Phase 5). A session
// is its view (session_view.hpp).

#include "aurelion_rules/port/gd.hpp"

namespace aurelion::rules::port::enemy_turn_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using state::State;

// A faction's towns: {"index", "town"} for each town the enemy owns under that
// controller (enemy_turn_rules.cpp).
ArrayRef _owned_town_entries(State &state, DictRef session, Atom faction_id);
Atom _town_controller_faction_id(State &state, DictRef town_state);

} // namespace aurelion::rules::port::enemy_turn_rules
