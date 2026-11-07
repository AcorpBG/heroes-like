#pragma once

// scripts/core/TownRules.gd, ported function by function under the GDScript
// names (docs/native-rules-engine-transition.md): the ports shared by the computer
// players' day (Phase 4) and the ends of a battle (Phase 5).

#include "aurelion_rules/port/gd.hpp"

#include <cstdint>

namespace aurelion::rules::port::town_rules {

using gd::ArrayRef;
using gd::DictRef;
using state::State;

// Phase 4's ports shared with Phase 5's battle ends (town_rules_shared.cpp): the
// spells a town's mage guild teaches, from the guild the town drew.
int64_t current_spell_tier(State &state, DictRef town);
ArrayRef accessible_spell_ids(State &state, DictRef town);
ArrayRef spell_ids_through_tier(State &state, DictRef town, int64_t tier);
// A town's guild (docs/magic-system.md, "Guilds and learning"): at each level a
// third of that tier's spells, each of the faction's preferred school twice as
// likely, seeded by the game and the town's placement.
ArrayRef draw_guild_spell_ids(State &state, DictRef session, DictRef town);
// Draws the guild of every town of the session that has none yet: a new game's
// towns and those of a save from before the draws.
void ensure_guild_draws(State &state, DictRef session);

} // namespace aurelion::rules::port::town_rules
