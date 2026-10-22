#pragma once

// scripts/core/OverworldTurnPlayback.gd: the functions the computer players' day runs
// (docs/native-rules-engine-transition.md, Phase 4), ported function by
// function under the GDScript names. A session is its view (session_view.hpp).

#include "aurelion_rules/port/gd.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"

#include <cstdint>

namespace aurelion::rules::port::overworld_turn_playback {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using gd::PackedRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// Ported in enemy_turn_rules_turn.cpp.
void action(State &state, const Value &session, DictRef actor, Atom verb);
void move(State &state, const Value &session, DictRef actor, DictRef before);
void player_turn(State &state, const Value &session, DictRef config);

// Not run by the six seeds: each throws state::NotPorted (turn_not_ported.cpp).
Atom _actor_name(State &state, DictRef actor);
DictRef _visual_actor(State &state, DictRef actor, DictRef point);
bool visible(State &state, const Value &session, DictRef point);

} // namespace aurelion::rules::port::overworld_turn_playback
