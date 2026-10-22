#pragma once

// The day processing's HeroCommandRules.commit_active_hero (hero_commit.cpp,
// Phase 5 slice 03). A session is its view (session_view.hpp).

#include "aurelion_rules/port/gd.hpp"

namespace aurelion::rules::port::hero_command_rules {

// The active hero's overworld mirrors (hero, army, movement, hero_position)
// written back into the player's roster as a normalized hero, then the mirrors
// rebuilt from the roster.
void commit_active_hero(state::State &state, gd::DictRef session);


// Its parts that HeroCommandRules.normalize_session also runs (hero_commit.cpp).
int64_t _hero_index_by_id(state::State &state, gd::ArrayRef player_heroes, gd::Atom hero_id);
gd::DictRef _normalize_army(state::State &state, const state::Value &value, gd::Atom hero_id);
gd::DictRef _normalize_player_hero(state::State &state, gd::DictRef hero_state, gd::DictRef session, gd::DictRef fallback_position, gd::DictRef fallback_army, const state::Value &fallback_movement);
void _sync_active_hero_mirror(state::State &state, gd::DictRef session);


// The active hero's roster entry (hero_commit.cpp).
gd::DictRef active_hero(state::State &state, gd::DictRef session);

} // namespace aurelion::rules::port::hero_command_rules
