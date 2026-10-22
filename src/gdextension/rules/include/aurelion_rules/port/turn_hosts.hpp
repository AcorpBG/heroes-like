#pragma once

// The GDScript functions the AI turn port leaves in GDScript until Phase 1's
// merge (the battles), as the turn's ports call them: each is a host call of
// TurnEngine.host_call, which hands the target the session itself
// (core/port/turn_hosts.cpp; turn_registry.cpp lists them as hosts).
// Everything the native call changed is written back first and read again
// afterwards (gd::call_static): an items() range or a const DictNode & held
// across one is no longer valid. A shadow check stops at the first one.
// _simulate_battle is pure (TurnEngine.pure_host_call): it reads the session's
// day and copies of its arguments, and returns new containers, so nothing is
// read again after it.

#include "aurelion_rules/port/gd.hpp"

#include <cstdint>

namespace aurelion::rules::port::ai_hero_rules {

using gd::Atom;
using gd::DictRef;
using state::State;

// AiHeroRules._simulate_battle: the battle an AI hero's plan previews or
// fights, resolved in GDScript (BattleRules).
DictRef _simulate_battle(State &state, DictRef session, DictRef context, DictRef entry, DictRef defender, int64_t battle_number, int64_t stop_below_creatures = 0);
// AiHeroRules._start_player_battle: an AI hero's attack on a player's hero or
// town, which opens the battle the player fights.
DictRef _start_player_battle(State &state, DictRef session, DictRef context, int64_t index, DictRef battle_context, Atom summary, DictRef target);

} // namespace aurelion::rules::port::ai_hero_rules
