#pragma once

// The GDScript function the AI turn port leaves in GDScript (the start of a
// battle against a human), as the turn's ports call it: a host call of
// TurnEngine.host_call, which hands the target the session itself
// (core/port/turn_hosts.cpp; turn_registry.cpp lists it as a host).
// Everything the native call changed is written back first and read again
// afterwards (gd::call_static): an items() range or a const DictNode & held
// across one is no longer valid. A shadow check stops at the first one.
// The battle preview (_simulate_battle) is Phase 2a's native port
// (ai_battle_preview.hpp), included here for the turn's ports.

#include "aurelion_rules/port/ai_battle_preview.hpp"
#include "aurelion_rules/port/gd.hpp"

#include <cstdint>

namespace aurelion::rules::port::ai_hero_rules {

using gd::Atom;
using gd::DictRef;
using state::State;

// AiHeroRules._start_player_battle: an AI hero's attack on a player's hero or
// town, which opens the battle the player fights.
DictRef _start_player_battle(State &state, DictRef session, DictRef context, int64_t index, DictRef battle_context, Atom summary, DictRef target);

} // namespace aurelion::rules::port::ai_hero_rules
