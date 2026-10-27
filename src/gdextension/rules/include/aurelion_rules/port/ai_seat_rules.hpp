#pragma once

// scripts/core/AiSeatRules.gd, ported under the GDScript names: the seats the
// computer plays in place of the human, in an AI-against-AI match or a
// spectated game. One copy: the game's wrappers (human_registry.cpp) and
// match_sim_cli call it. A session is its view (session_view.hpp).

#include "aurelion_rules/port/gd.hpp"

namespace aurelion::rules::port::ai_seat_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using state::State;

// Hands the human's seat to the computer: the seat keeps its identity, towns
// and treasury, its towns become computer towns and its heroes leave the map.
// The seat's player id, or "" when the session has no human seat.
Atom hand_human_seat_to_ai(State &state, DictRef session);
// The players that still hold a town or a hero, in seat order.
ArrayRef standing_players(State &state, DictRef session);
// A match with no human seat is over once every standing player is on one team.
bool match_over(State &state, DictRef session);

} // namespace aurelion::rules::port::ai_seat_rules
