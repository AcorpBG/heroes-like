#pragma once

// scripts/core/AiHeroRules.gd: the functions the computer players' day runs
// (docs/native-rules-engine-transition.md, Phase 4), ported function by
// function under the GDScript names. A session is its view (session_view.hpp).

#include "aurelion_rules/port/gd.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/ai_hero_rules.hpp"
#include "aurelion_rules/port/ai_hero_rules_ai.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"

#include <cstdint>

namespace aurelion::rules::port::ai_hero_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using gd::PackedRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// Ported in ai_hero_rules_turn.cpp.
void _apply_weights(State &state, DictRef weights);
int64_t _elapsed_ms(State &state, int64_t started);
DictRef _new_context(State &state, DictRef session, DictRef config, DictRef state_);
void _note_sightings(State &state, DictRef session, DictRef context);
Atom _posture(State &state, DictRef session, Atom controller);
DictRef _resolved_weight_set(State &state, Atom set_name);
void _reveal_from_holdings(State &state, DictRef session, DictRef context);
DictRef _shared_level_surfaces(State &state, DictRef session);
void _start_heroes_day(State &state, DictRef session, Atom controller);
void _store_explored(State &state, DictRef context);
DictRef _turn_result(State &state, DictRef state_, ArrayRef messages, ArrayRef events, bool profile_enabled, DictRef phases, int64_t started);
void _use_weights(State &state, DictRef state_);
void clear_shared_surfaces(State &state);
DictRef faction_daily_income(State &state, DictRef session, Atom controller);
DictRef run_faction_turn(State &state, DictRef session, DictRef config, DictRef state_, bool should_apply_weekly_growth, bool profile_enabled = false);

// Ported in ai_hero_rules_turn_day.cpp.
DictRef _choose_plan(State &state, DictRef session, DictRef context, DictRef entry);
void _close_decision_memos(State &state, DictRef context);
DictRef _decide_plan(State &state, DictRef session, DictRef context, DictRef entry);
DictRef _follow_plan(State &state, DictRef session, DictRef context, int64_t index, DictRef plan);
void _forget_beyond(State &state, DictRef context, Atom target_id);
DictRef _interact(State &state, DictRef session, DictRef context, int64_t index, DictRef plan);
void _log_decision(State &state, DictRef session, DictRef context, DictRef entry, DictRef plan);
void _note_route_visit(State &state, DictRef session, DictRef context, DictRef entry);
void _open_decision_memos(State &state, DictRef context);
DictRef _run_hero_day(State &state, DictRef session, DictRef context, Atom placement_id);
DictRef _strategic_candidate(State &state, DictRef session, DictRef context, DictRef entry, int64_t movement_max, int64_t local_radius, DictRef wide);
DictRef _vetted_candidate(State &state, DictRef session, DictRef context, DictRef entry, DictRef search, int64_t movement_max);
bool placement_is_main(State &state, DictRef session, DictRef context, DictRef entry);

// Ported in ai_hero_rules_turn_fights.cpp.
void _add_pool(State &state, DictRef pool, const Value &delta);
DictRef _attack_town(State &state, DictRef session, DictRef context, int64_t index, DictRef plan);
DictRef _auto_resolve(State &state, DictRef session, DictRef context, int64_t index, DictRef defender);
void _avoid_target(State &state, DictRef session, Atom placement_id, Atom target_id, int64_t until_day);
Atom _battle_key(State &state, DictRef entry, DictRef defender, int64_t battle_number);
DictRef _claim_resource(State &state, DictRef session, DictRef context, int64_t index, DictRef plan);
void _clear_static_body(State &state, DictRef session, DictRef context, DictRef node);
DictRef _commander_brief(State &state, const Value &commander);
DictRef _cornered_fight(State &state, DictRef session, DictRef entry, DictRef search, DictRef context);
int64_t _creature_total(State &state, const Value &stacks);
Atom _defender_label(State &state, DictRef defender);
DictRef _defender_target(State &state, DictRef defender, Atom label);
void _economy_add(State &state, DictRef session, Atom controller, Atom key, double amount);
DictRef _event(State &state, DictRef session, DictRef context, Atom event_type, DictRef actor, DictRef target, Atom summary, ArrayRef reason_codes);
DictRef _fight_ai_hero(State &state, DictRef session, DictRef context, int64_t index, DictRef plan);
void _step_back_from_guard(State &state, DictRef session, int64_t index, DictRef plan);
bool _fight_looks_good(State &state, DictRef session, DictRef context, DictRef entry, DictRef plan, bool idle = false);
DictRef _fight_neutral(State &state, DictRef session, DictRef context, int64_t index, DictRef plan);
DictRef _find_town(State &state, DictRef session, Atom placement_id);
void _forget_sighting(State &state, DictRef context, Atom id);
DictRef _free_fight(State &state, DictRef session, DictRef context, DictRef entry, DictRef search);
bool _gate_fight_looks_good(State &state, DictRef session, DictRef context, DictRef entry, DictRef plan);
bool _home_reachable(State &state, DictRef session, DictRef context, DictRef entry, DictRef search);
DictRef _idle_fight(State &state, DictRef session, DictRef context, DictRef entry, DictRef search);
bool _is_resolved(State &state, DictRef session, Atom placement_id);
void _log_battle(State &state, DictRef session, DictRef context, DictRef entry, DictRef defender, DictRef outcome, bool previewed);
DictRef _make_room(State &state, ArrayRef garrison, Atom unit_id, int64_t count);
void _mark_resolved(State &state, DictRef session, Atom placement_id);
int64_t _max_affordable_with_market(State &state, DictRef session, DictRef town, DictRef pool, DictRef unit_cost, int64_t available);
DictRef _meet_hero(State &state, DictRef session, DictRef context, int64_t index, DictRef plan);
void _record_hero_defeat(State &state, DictRef session, Atom controller, DictRef entry);
ArrayRef _recruit_town(State &state, DictRef session, DictRef context, int64_t index, DictRef reserve);
// Slice 4.3: an AI hero's attack on a player's hero or town, which opens the
// battle the player fights (BattleRules.create_battle_payload, Phase 2a's port).
DictRef _start_player_battle(State &state, DictRef session, DictRef context, int64_t index, DictRef battle_context, Atom summary, DictRef target);
void _store_entry(State &state, DictRef session, int64_t index, DictRef entry);
DictRef _take_artifact(State &state, DictRef session, DictRef context, int64_t index, DictRef plan);
DictRef _take_garrison(State &state, DictRef session, DictRef entry, DictRef town, DictRef context, bool fresh_hire = false);
Atom hero_name(State &state, DictRef entry);

// Ported in ai_hero_rules_turn_moves.cpp.
bool _clear_way(State &state, DictRef session, DictRef context, DictRef entry, int64_t radius, int64_t movement_max);
DictRef _cross_gate(State &state, DictRef session, DictRef context, int64_t index, DictRef plan);
bool _cross_shore(State &state, DictRef session, DictRef context, DictRef entry, Vector2i tile, int64_t level);
bool _cuts_a_way(State &state, DictRef search, int64_t tile_index, Vector2i size);
int64_t _danger_gap(State &state, ArrayRef dangers, int64_t x, int64_t y, int64_t level);
DictRef _evade(State &state, DictRef session, DictRef context, DictRef entry, DictRef search);
DictRef _gate_home(State &state, DictRef session, DictRef context, DictRef entry, DictRef search, DictRef town);
DictRef _gate_walk(State &state, DictRef session, DictRef context, DictRef entry, DictRef plan, DictRef search);
bool _holds_gate(State &state, DictRef session, DictRef context, DictRef entry, DictRef town, bool is_main);
DictRef _hostile_hero_beside(State &state, DictRef session, DictRef context, Vector2i tile, int64_t level);
DictRef _launch_boat(State &state, DictRef session, DictRef context, DictRef entry, Vector2i tile, int64_t level);
bool _leave_guard(State &state, DictRef session, DictRef context, DictRef entry, DictRef town, double needed);
bool _make_way(State &state, DictRef session, DictRef context, Atom placement_id, DictRef keep_clear);
DictRef _nearest_owned_town(State &state, DictRef session, Atom controller, Vector2i tile, int64_t level);
bool _next_to_any(State &state, Vector2i tile, ArrayRef others);
void _note_boat_need(State &state, DictRef session, DictRef context, DictRef entry);
DictRef _own_town_at(State &state, DictRef session, Atom controller, DictRef entry);
void _park(State &state, DictRef session, Atom placement_id, Atom town_id);
Atom _parked_hero_id(State &state, DictRef session, Atom controller, Atom town_id);
DictRef _pending_make_way(State &state, DictRef session, DictRef context, DictRef entry, DictRef search);
DictRef _portal_step(State &state, DictRef session, DictRef context, DictRef entry, Vector2i tile, int64_t level);
void _reveal(State &state, DictRef session, DictRef context, DictRef point, int64_t radius);
int64_t _sight_radius(State &state, DictRef entry);
bool _tile_blocked_for_standing(State &state, DictRef session, DictRef context, Vector2i tile, int64_t level, Atom actor_id);
DictRef _visit_own_town_if_inside(State &state, DictRef session, DictRef context, int64_t index);
DictRef _wait_by_home(State &state, DictRef session, DictRef context, DictRef entry, DictRef search, DictRef keep_clear);

// Ported in ai_hero_rules_turn_towns.cpp.
void _append_all(State &state, ArrayRef target, const Value &values);
DictRef _build_choice(State &state, DictRef session, DictRef town, DictRef treasury, DictRef values);
DictRef _build_in_towns(State &state, DictRef session, DictRef context);
DictRef _build_tavern(State &state, DictRef session, DictRef context, ArrayRef town_entries);
DictRef _create_hero(State &state, DictRef session, DictRef context, DictRef town, Atom hero_id, ArrayRef start_stacks);
int64_t _desired_hero_count(State &state, DictRef session, Atom controller);
int64_t _unexplored_land(State &state, DictRef session, DictRef context);
int64_t _wanted_explorers(State &state, DictRef session, DictRef context);
double _hire_reserve(State &state, DictRef session, Atom controller, Atom days_name);
DictRef _hold_back(State &state, DictRef treasury, DictRef amounts);
void _ensure_opening_stockpile(State &state, DictRef session, DictRef context);
DictRef _ensure_starting_hero(State &state, DictRef session, DictRef context);
bool _faction_has_tavern(State &state, ArrayRef town_entries);
DictRef _govern_towns(State &state, DictRef session, DictRef context);
DictRef _hire_hero(State &state, DictRef session, DictRef context, double reserve);
double _market_value(State &state, DictRef building, DictRef short_);
int64_t _opens_count(State &state, DictRef town, Atom building_id, ArrayRef trial_built);
DictRef _pool_delta(State &state, DictRef after, DictRef before);
DictRef _recruit_in_towns(State &state, DictRef session, DictRef context, DictRef reserve);
DictRef _roster_progression_seed(State &state, DictRef state_, Atom hero_id);
ArrayRef _tavern_pool(State &state, DictRef session, DictRef state_, Atom controller);
DictRef _trial_income(State &state, DictRef town);
ArrayRef ai_tavern_offer_ids(State &state, DictRef session, DictRef state_, Atom controller);
DictRef build_in_town(State &state, DictRef session, DictRef context, int64_t town_index, Atom building_id, Atom reason = state::key::heroes);

// Ported in turn_rare_paths.cpp (slice 4.2: paths the six seeds do not run).
DictRef _attack_player_hero(State &state, DictRef session, DictRef context, int64_t index, DictRef plan);
DictRef _convert_legacy_host(State &state, DictRef session, DictRef entry, Atom controller);
int64_t _nearest_hero_index(State &state, ArrayRef encounters, DictRef resolved, Atom controller, DictRef column, int64_t radius);
void _return_troops_to_nearest_town(State &state, DictRef session, DictRef entry, Atom controller);
double _upgrade_value(State &state, DictRef town, DictRef building);

} // namespace aurelion::rules::port::ai_hero_rules
