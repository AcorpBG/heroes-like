#pragma once

// scripts/core/BattleAutoResolveRules.gd, ported function by function under
// the GDScript names (slice 10): the autoplay order of a player stack and the
// loop that resolves a whole battle order by order.

#include "aurelion_rules/port/gd.hpp"

#include <cstdint>

namespace aurelion::rules::port::battle_auto_resolve_rules {

using gd::Atom;
using gd::DictRef;
using state::State;
using state::Value;

// BattleAutoResolveRules.DEFAULT_STEP_LIMIT.
constexpr int64_t DEFAULT_STEP_LIMIT = 240;

DictRef player_autoplay_decision(State &state, const Value &session, bool apply_selection, bool allow_hero_cast);
DictRef resolve_active_battle(State &state, const Value &session, int64_t step_limit, int64_t stop_below_player_creatures);
bool is_terminal_state(Atom state);
int64_t _player_creatures_standing(State &state, DictRef battle);
DictRef _perform_player_order(State &state, const Value &session, DictRef decision, Atom action);
DictRef _fallback_player_autoplay_decision(State &state, const Value &session, Atom reason, bool apply_selection, DictRef scored_decision);
void _select_focus_enemy(State &state, const Value &session);
DictRef _resolve_result(State &state, const Value &session, bool completed, Atom stop_reason, Atom result_state, int64_t steps, int64_t player_orders, int64_t enemy_ready_ticks, int64_t invalid_orders, int64_t forbidden_exit_orders, DictRef action_counts, DictRef terminal_result, DictRef last_result);

} // namespace aurelion::rules::port::battle_auto_resolve_rules
