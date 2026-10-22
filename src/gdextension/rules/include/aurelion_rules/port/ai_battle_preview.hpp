#pragma once

// The AI's battle preview (docs/native-rules-engine-transition.md, Phase 2,
// slice 2a): AiHeroRules._simulate_battle, one auto-resolved battle on a
// scratch session, as one native call (ai_battle_preview.cpp). The scratch
// session is a session view the preview builds (gd::member and gd::object_view
// take it as the SessionData GDScript makes); the live session gives only its
// day. Pure: nothing of the session or the arguments is written.

#include "aurelion_rules/port/gd.hpp"

#include <cstdint>

namespace aurelion::rules::port::ai_hero_rules {

using gd::DictRef;
using state::State;

// The preview of the battle `entry` (an AI hero's encounter) fights against
// `defender`, on the session's day. stop_below_creatures > 0 ends the battle
// unresolved (not won) once the hero has fewer creatures standing. The entry
// Phase 4's turn port calls, with the session as its view.
DictRef _simulate_battle(State &state, DictRef session, DictRef context, DictRef entry, DictRef defender, int64_t battle_number, int64_t stop_below_creatures = 0);
// The same on a day given, for the battle table's entry: it reads the
// session's day alone and never builds the session's view.
DictRef _simulate_battle_on_day(State &state, int64_t day, DictRef entry, DictRef defender, int64_t battle_number, int64_t stop_below_creatures);
// The hero as the human's battle code expects one: a hero record with army,
// movement and position.
DictRef _battle_hero(State &state, DictRef entry);

} // namespace aurelion::rules::port::ai_hero_rules
