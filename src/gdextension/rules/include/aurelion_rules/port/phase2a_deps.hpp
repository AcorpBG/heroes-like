#pragma once

// TEMPORARY (Phase 2a, until Phase 4's shared functions are on main): the two
// of them 2a calls, under Phase 4's signatures (enemy_adventure_rules_turn.hpp),
// and the headers of Phase 5's slice 09 functions 2a calls. Delete when
// rebasing on Phase 4.

#include "aurelion_rules/port/battle_ends.hpp"
#include "aurelion_rules/port/battle_rules.hpp"
#include "aurelion_rules/port/gd.hpp"

namespace aurelion::rules::port::enemy_adventure_rules {

gd::Atom raid_commander_name(state::State &state, gd::DictRef encounter);
gd::Atom raid_commander_display_name(state::State &state, gd::DictRef encounter);

} // namespace aurelion::rules::port::enemy_adventure_rules
