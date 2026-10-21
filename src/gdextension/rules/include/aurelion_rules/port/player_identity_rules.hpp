#pragma once

// scripts/core/PlayerIdentityRules.gd, ported function by function under the
// GDScript names (docs/native-rules-engine-transition.md, Phase 5). A session
// is its view (session_view.hpp).

#include "aurelion_rules/port/gd.hpp"

namespace aurelion::rules::port::player_identity_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using state::State;
using state::Value;

// The controller of a record, a raid and a town (player_identity_rules.cpp).
// controller_id(record, fallback = "").
Atom controller_id(State &state, DictRef record, Atom fallback);
Atom raid_controller_id(State &state, DictRef raid);
Atom town_controller_id(State &state, DictRef town);

// A player's record and identity (player_identity_rules.cpp). player() answers
// the session's own record, or a new empty one.
DictRef player(State &state, DictRef session, Atom player_id);
Atom faction_id(State &state, DictRef session, Atom controller);
DictRef identity_fields(State &state, DictRef session, Atom controller);

// The computer players' enemy configs (player_identity_rules.cpp).
ArrayRef enemy_configs(State &state, ArrayRef players);

} // namespace aurelion::rules::port::player_identity_rules
