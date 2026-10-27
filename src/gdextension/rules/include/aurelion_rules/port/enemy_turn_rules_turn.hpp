#pragma once

// scripts/core/EnemyTurnRules.gd: the functions the computer players' day runs
// (docs/native-rules-engine-transition.md, Phase 4), ported function by
// function under the GDScript names. A session is its view (session_view.hpp).

#include "aurelion_rules/port/gd.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/enemy_states.hpp"
#include "aurelion_rules/port/enemy_turn_rules.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"

#include <cstdint>

namespace aurelion::rules::port::enemy_turn_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using gd::PackedRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// Ported in enemy_turn_rules_turn.cpp.
void _append_event_records(State &state, ArrayRef output, const Value &events_value);
DictRef _apply_discount(State &state, const Value &cost, int64_t discount_percent);
Atom _apply_weekly_musters(State &state, DictRef session, ArrayRef town_entries, ArrayRef towns, Atom faction_id, DictRef config);
DictRef _building_growth_payload(State &state, Atom building_id);
DictRef _consume_recruits(State &state, const Value &base, Atom unit_id, int64_t amount);
Atom _describe_recruit_delta(State &state, const Value &delta);
int64_t _discount_from_profile(State &state, const Value &profile, Atom unit_id);
DictRef _enemy_recruit_cost(State &state, DictRef town, Atom unit_id);
ArrayRef _enemy_town_accessible_spell_ids(State &state, DictRef town);
bool _enemy_turn_profile_enabled(State &state);
DictRef _enemy_turn_result(State &state, bool ok, Atom message, ArrayRef events, bool profile_enabled, DictRef profile);
int64_t _find_state_index(State &state, const Value &states, Atom faction_id);
DictRef _latest_enemy_state(State &state, DictRef session, Atom faction_id, DictRef fallback);
DictRef _merge_recruits(State &state, const Value &base, const Value &delta);
ArrayRef _normalized_built_buildings(State &state, DictRef town);
int64_t _owned_town_count(State &state, DictRef session, Atom faction_id);
void _profile_add_ms(State &state, DictRef profile, Atom key, int64_t started_usec);
int64_t _profile_timer(State &state, bool enabled);
int64_t _recruitment_discount_percent(State &state, DictRef town, Atom unit_id);
DictRef _scale_resource_pool(State &state, const Value &cost, int64_t multiplier);
void _spend_from_pool(State &state, DictRef pool, const Value &cost);
DictRef _town_actor(State &state, DictRef town);
Atom _town_name(State &state, DictRef town_state);
DictRef ai_town_build_event(State &state, DictRef session, DictRef config, DictRef town, DictRef selected_build);
DictRef ai_town_recruit_event(State &state, DictRef session, DictRef config, DictRef town, DictRef selected_recruitment);
DictRef run_enemy_turn(State &state, DictRef session, bool settle_rosters = true);

// Ported in enemy_turn_rules_turn_rare.cpp (slice 4.2: paths the six seeds do not run).
void _append_building_with_requirements(State &state, ArrayRef target, Atom building_id, ArrayRef trail);
bool _config_was_runtime_defaulted(State &state, DictRef source, DictRef normalized);
DictRef _faction_capital_state(State &state, DictRef session, Atom faction_id);
DictRef _faction_capital_state_from_towns(State &state, DictRef session, ArrayRef towns, Atom faction_id);
DictRef _faction_front_state(State &state, DictRef session, Atom faction_id);
int64_t _hero_task_record_sanitized_field_count(State &state, DictRef task);
int64_t _hero_task_state_board_sanitized_field_count(State &state, DictRef board);
DictRef _launch_policy_capital_state(State &state, DictRef session, Atom faction_id, DictRef launch_policy_context);
int64_t _max_active_raids_for_strategy(State &state, DictRef session, DictRef config, Atom faction_id, DictRef launch_policy_context);
Atom _normalize_hero_task_actor_kind(State &state, const Value &value);
Atom _normalize_hero_task_class(State &state, const Value &value);
Atom _normalize_hero_task_continuity_policy(State &state, const Value &value);
Atom _normalize_hero_task_origin_kind(State &state, const Value &value);
DictRef _normalize_hero_task_record(State &state, const Value &value);
DictRef _normalize_hero_task_reservation(State &state, const Value &value);
Atom _normalize_hero_task_route_policy(State &state, const Value &value);
Atom _normalize_hero_task_source_kind(State &state, const Value &value);
Atom _normalize_hero_task_status(State &state, const Value &value);
Atom _normalize_hero_task_target_kind(State &state, const Value &value);
Atom _normalize_hero_task_validation_code(State &state, const Value &value);
ArrayRef _valid_enemy_faction_configs(State &state, ArrayRef configs);
int64_t active_raid_count(State &state, DictRef session, Atom faction_id);
int64_t get_pressure(State &state, DictRef session, Atom faction_id);
DictRef normalize_optional_hero_task_state(State &state, const Value &value);

} // namespace aurelion::rules::port::enemy_turn_rules
