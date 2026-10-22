#pragma once

// The day processing's entry into the computer players' states
// (enemy_states.cpp, Phase 5 slice 04): EnemyTurnRules.normalize_enemy_states.
// The functions it reaches stay in that file until they have a second caller;
// those below have one in hero_commit.cpp (slice 03).

#include "aurelion_rules/port/gd.hpp"

namespace aurelion::rules::port::enemy_turn_rules {

// The computer players' states rebuilt from their configs, then their raid
// hosts and commander rosters; writes the session's difficulty and the fallen
// heroes' days in its metadata.
void normalize_enemy_states(state::State &state, gd::DictRef session);

} // namespace aurelion::rules::port::enemy_turn_rules

namespace aurelion::rules::port::hero_progression_rules {

// A hero's levels, specialties and pending specialty choices normalized in
// place; returns the hero.
gd::DictRef ensure_hero_progression(state::State &state, gd::DictRef hero_state);
// The catalog row of a specialty, empty when there is none.
gd::DictRef _specialty_row(state::State &state, gd::Atom specialty_id);

} // namespace aurelion::rules::port::hero_progression_rules
