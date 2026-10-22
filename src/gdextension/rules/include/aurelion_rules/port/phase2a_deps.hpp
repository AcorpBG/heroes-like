#pragma once

// TEMPORARY (Phase 2a, until Phase 4's shared functions and Phase 5's slice 09
// are on main): the declarations 2a calls from those branches, under their
// signatures, so 2a's files compile alone. Delete when rebasing on them.

#include "aurelion_rules/port/gd.hpp"

#include <cstdint>

namespace aurelion::rules::port {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using state::State;
using state::Value;

namespace battle_rules {
// Phase 5 slice 09 (battle_rules.hpp, Layer 11).
ArrayRef _battle_survivor_stacks(State &state, const Value &session, Atom side, DictRef filters);
Atom _battle_context_controller_id(State &state, const Value &session, DictRef context, const Value &raw_context);
Atom _battle_context_resource_placement_id(State &state, DictRef context, const Value &raw_context);
Atom _battle_context_town_placement_id(State &state, const Value &session, DictRef context, const Value &raw_context);
Atom _battle_context_trigger_faction_id(State &state, const Value &session, DictRef context, const Value &raw_context, DictRef town);
bool _is_resource_assault_context(State &state, const Value &context);
bool _enemy_state_exists(State &state, const Value &session, Atom faction_id);
DictRef _find_town_by_placement(State &state, const Value &session, Atom placement_id);
DictRef _find_town_at_position(State &state, const Value &session, int64_t x, int64_t y, int64_t level);
Atom _titleize_token(State &state, Atom value);
Atom _town_name(State &state, DictRef town);
Atom _town_name_from_placement_id(State &state, const Value &session, Atom placement_id);
} // namespace battle_rules

namespace overworld_rules {
// Phase 5 slice 09 (battle_ends.hpp).
DictRef _find_resource_node_by_placement(State &state, DictRef session, Atom placement_id);
} // namespace overworld_rules

namespace enemy_adventure_rules {
// Phase 4 (enemy_adventure_rules_turn.hpp).
Atom commander_display_name(State &state, const Value &source, bool include_veterancy = true);
Atom raid_commander_name(State &state, DictRef encounter);
Atom raid_commander_display_name(State &state, DictRef encounter);
} // namespace enemy_adventure_rules

} // namespace aurelion::rules::port
