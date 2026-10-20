#pragma once

// scripts/core/BattleRules.gd, ported function by function under the GDScript
// names (docs/native-rules-engine-transition.md, Phase 1). Layer 1: hex
// geometry and board reads.
//
// Not ported, with the reason:
// - begin_board_read_scope, end_board_read_scope, _board_read_cache_get,
//   _board_read_cache_key: the board-read memo. It is transparent, so the
//   native reads go without it; the shadow checks prove it.
// - _ensure_battle_hex_state: calls _default_stack_hex, _first_open_body_near
//   and _hex_board_descriptor, which are not ported yet.
// - _set_stack_hex: calls _presentation_walk_path and ActionPlayback.capture.
// - _stack_is_isolated, _stack_is_hex_isolated: call _allied_melee_count
//   (layer 2).

#include "aurelion_rules/port/gd.hpp"

#include <cstdint>

namespace aurelion::rules::port::battle_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using state::State;
using state::Value;

constexpr int64_t BATTLE_HEX_COLUMNS = 11;
constexpr int64_t BATTLE_HEX_ROWS = 9;

DictRef get_active_stack(State &state, DictRef battle);
int64_t _alive_count(const State &state, DictRef stack);
int64_t _alive_stack_count_for_side(State &state, DictRef battle, Atom side);
ArrayRef _alive_stacks_for_side(State &state, DictRef battle, Atom side);
DictRef _build_blocking_map(State &state, DictRef battle);
DictRef _build_occupancy_map(State &state, DictRef battle);
int64_t _distance_band_from_hex_distance(int64_t hex_distance);
DictRef _get_stack_by_id(State &state, DictRef battle, Atom battle_id);
double _health_ratio(const State &state, DictRef stack);
DictRef _hex_cell(State &state, int64_t q, int64_t r);
int64_t _hex_distance(State &state, DictRef lhs, DictRef rhs);
bool _hex_in_bounds(int64_t q, int64_t r);
Atom _hex_key(State &state, DictRef cell);
Atom _hex_key_from_coords(State &state, int64_t q, int64_t r);
Atom _hex_label(State &state, DictRef cell);
ArrayRef _hex_neighbors(State &state, DictRef cell);
// The PackedByteArray of BATTLE_HEX_COLUMNS * BATTLE_HEX_ROWS bytes, into open.
void _hex_open_mask(State &state, DictRef stack, DictRef occupied, uint8_t *open);
int64_t _hex_tail_step(const State &state, DictRef stack);
DictRef _normalize_hex_cell(State &state, const Value &value);
DictRef _obstacle_cell_map(State &state, DictRef battle);
DictRef _offset_to_cube(State &state, int64_t q, int64_t r);
Atom _opposing_side(Atom side);
int64_t _projected_min_opposing_hex_distance(State &state, DictRef battle, DictRef stack, DictRef destination);
ArrayRef _reachable_empty_hexes(State &state, DictRef battle, DictRef stack, int64_t max_steps);
Atom _side_label(Atom side);
DictRef _stack_hex(State &state, DictRef stack);
int64_t _stack_hex_distance(State &state, DictRef lhs, DictRef rhs);
bool _stack_is_engaged(State &state, DictRef stack, DictRef battle);
Atom _stack_label(const State &state, DictRef stack);
void _sync_distance_from_hexes(State &state, DictRef battle);
void _sync_occupied_hexes(State &state, DictRef battle);
DictRef _walk_steps_to_target(State &state, DictRef battle, DictRef stack, DictRef target, int64_t gap);
void _walk_open_mask(State &state, DictRef battle, DictRef stack, uint8_t *open);

} // namespace aurelion::rules::port::battle_rules
