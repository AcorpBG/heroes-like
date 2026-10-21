#pragma once

// The day processing's HeroCommandRules.commit_active_hero (hero_commit.cpp,
// Phase 5 slice 03). A session is its view (session_view.hpp).

#include "aurelion_rules/port/gd.hpp"

namespace aurelion::rules::port::hero_command_rules {

// The active hero's overworld mirrors (hero, army, movement, hero_position)
// written back into the player's roster as a normalized hero, then the mirrors
// rebuilt from the roster.
void commit_active_hero(state::State &state, gd::DictRef session);

} // namespace aurelion::rules::port::hero_command_rules
