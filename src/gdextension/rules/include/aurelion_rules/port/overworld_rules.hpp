#pragma once

// scripts/core/OverworldRules.gd, ported function by function under the GDScript
// names (docs/native-rules-engine-transition.md, Phase 5). A session is its view
// (session_view.hpp). The debug rules profile (_rules_profile_*) is recorded as
// GDScript records it, except at the end of the turn (refuse_recording_profile).

#include "aurelion_rules/port/gd.hpp"

#include <cstdint>
#include <vector>

namespace aurelion::rules::port::overworld_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using state::State;
using state::Value;

// A Vector2i: its components are 32-bit, read as int, and wrap like Godot's.
struct Vector2i {
	int32_t x = 0;
	int32_t y = 0;

	// Vector2i(int(a), int(b)): each int cut to 32 bits.
	static Vector2i of(int64_t x, int64_t y) { return {static_cast<int32_t>(x), static_cast<int32_t>(y)}; }
	Vector2i operator+(Vector2i other) const {
		return {static_cast<int32_t>(static_cast<uint32_t>(x) + static_cast<uint32_t>(other.x)), static_cast<int32_t>(static_cast<uint32_t>(y) + static_cast<uint32_t>(other.y))};
	}
	Vector2i operator-(Vector2i other) const {
		return {static_cast<int32_t>(static_cast<uint32_t>(x) - static_cast<uint32_t>(other.x)), static_cast<int32_t>(static_cast<uint32_t>(y) - static_cast<uint32_t>(other.y))};
	}
	bool operator==(Vector2i other) const { return x == other.x && y == other.y; }
};

// An Array of Vector2i that stays inside the native call.
using Tiles = std::vector<Vector2i>;

// The map size (overworld_rules.cpp).
Vector2i derive_map_size(State &state, DictRef session);

// The blocked-tile index: the tiles each map level's towns, encounters, scenery
// and resource nodes stand on (overworld_rules.cpp).
DictRef _build_blocked_tile_index(State &state, DictRef session, int64_t level, Atom ignore_actor_id, DictRef combat_defenders);
DictRef _blocked_scenery_layer(State &state, DictRef session, int64_t level);
DictRef _build_blocked_scenery_layer(State &state, const Value &objects, int64_t level);
void _append_generated_body_tiles_to_blocked_index(State &state, DictRef index, DictRef placement, bool blocks_body);
Tiles _generated_body_tiles_for_placement(State &state, DictRef placement, bool blocks_body);
Tiles _world_tiles_from_payload_array(State &state, const Value &payload);
Atom _tile_key(State &state, Vector2i tile);
DictRef _map_object_for_resource_node(State &state, DictRef node);
bool _map_object_blocks_body_tiles(State &state, DictRef map_object);
bool _resource_node_blocks_body_tiles(State &state, DictRef node, DictRef map_object);
Tiles _map_object_world_body_tiles(State &state, DictRef map_object, DictRef placement);
bool _resource_node_has_runtime_object_contract(State &state, DictRef node);
Vector2i _map_object_footprint_origin(State &state, DictRef map_object, DictRef placement);
// resource_node_is_present(node, site = {}): an empty site is looked up.
bool resource_node_is_present(State &state, DictRef node, DictRef site);
bool _resource_site_is_repeatable(State &state, DictRef site);
bool _resource_site_is_persistent(State &state, DictRef site);
bool is_encounter_resolved(State &state, DictRef session, DictRef encounter);
ArrayRef _resolved_lookup_entry(State &state, DictRef session);
// The resolved placements as a lookup, the session's cached one.
DictRef resolved_encounter_lookup(State &state, DictRef session);
Atom encounter_key(State &state, DictRef encounter);

// A recruit payload: unit id -> a positive count (overworld_rules.cpp).
DictRef _normalize_recruit_payload(State &state, const Value &value);

// Fog of war (fog.cpp).
void refresh_fog_of_war(State &state, DictRef session);
void _normalize_fog_of_war(State &state, DictRef session);
DictRef fog_for_level(State &state, DictRef session, int64_t level);
ArrayRef _normalize_visibility_grid(State &state, const Value &value, Vector2i map_size);
ArrayRef _blank_visibility_grid(State &state, Vector2i map_size, bool fill_value);
ArrayRef _merge_visibility_grids(State &state, ArrayRef base, ArrayRef overlay, Vector2i map_size);
ArrayRef _duplicate_visibility_grid(State &state, ArrayRef grid);
DictRef _build_fog_payload(State &state, ArrayRef visible_tiles, ArrayRef explored_tiles, Vector2i map_size);
int64_t _count_grid(State &state, const Value &grid);
void _reveal_all_current_fog_sources(State &state, DictRef session, ArrayRef explored_tiles, Vector2i map_size, int64_t level);
void _apply_hero_reveal(State &state, ArrayRef explored_tiles, DictRef hero, Vector2i map_size);
void _apply_site_reveal(State &state, ArrayRef explored_tiles, DictRef site_state, int64_t radius, Vector2i map_size);
void _set_grid_cell(State &state, ArrayRef grid, int64_t x, int64_t y, bool value);
int64_t held_site_vision_radius(State &state, DictRef site);
int64_t hero_level(State &state, DictRef session);

// The resource nodes, rebuilt with their known fields (overworld_normalize.cpp).
ArrayRef _normalize_resource_nodes(State &state, ArrayRef nodes);
void _copy_resource_runtime_metadata(State &state, DictRef target, DictRef source);
DictRef _normalize_delivery_completion_counts(State &state, const Value &value);

// normalize_overworld_state and its parts (overworld_state_normalize.cpp).
void normalize_overworld_state(State &state, DictRef session);
void _mark_runtime_normalized(State &state, DictRef session);
Atom _runtime_normalization_signature(State &state, DictRef session);
DictRef _build_scenario_army_state(State &state, DictRef army_template);
DictRef _normalize_scenario_resources(State &state, const Value &value);
DictRef _normalize_live_resource_stockpile(State &state, const Value &value);
ArrayRef _normalize_artifact_nodes(State &state, ArrayRef nodes, Atom scenario_id = state::key::empty);
void _normalize_scenario_state_rules(State &state, DictRef session, bool normalize_enemies = true);
void _refresh_blocked_tile_index(State &state, DictRef session);
void _normalize_command_briefing(State &state, DictRef session);

// The towns, the active town visit (overworld_towns_normalize.cpp).
ArrayRef _normalize_towns(State &state, ArrayRef towns, int64_t current_day = -1);
void _copy_town_runtime_metadata(State &state, DictRef target, DictRef source);
DictRef _normalize_town_recovery_state(State &state, const Value &value);
DictRef _normalize_town_front_state(State &state, const Value &value);
void _normalize_active_town_visit_context(State &state, DictRef session);
// {"index": i, "town": town}, index -1 when missing.
DictRef _find_town_by_placement(State &state, DictRef session, Atom placement_id);

// Transit: the generated map's materialization record and the one-time
// translation of its transit objects (overworld_transit_normalize.cpp).
void _migrate_generated_transit_meanings(State &state, DictRef session);
void _normalize_generated_runtime_materialization(State &state, DictRef session, DictRef scenario);

// The command risk forecast and the reads it needs (overworld_forecast.cpp).
void _normalize_enemy_states(State &state, DictRef session);
void _normalize_command_risk_forecast(State &state, DictRef session);
DictRef _command_risk_forecast(State &state, DictRef session);
DictRef _command_risk_forecast_from_normalized_session(State &state, DictRef session);
DictRef _reduce_command_risk_items(State &state, ArrayRef items);
ArrayRef _command_risk_items(State &state, DictRef session, bool include_details = true);
ArrayRef _command_risk_player_town_daybreak_contexts(State &state, DictRef session);
ArrayRef _command_risk_town_items(State &state, DictRef session, ArrayRef daybreak_contexts, bool include_details = true);
ArrayRef _command_risk_logistics_items(State &state, DictRef session, DictRef pressured_town_ids, ArrayRef daybreak_contexts, bool include_details = true);
ArrayRef _command_risk_objective_items(State &state, DictRef session, DictRef pressured_town_ids, bool include_details = true);
ArrayRef _command_risk_posture_items(State &state, DictRef session, bool include_details = true);
DictRef _command_risk_field_item(State &state, DictRef session, bool include_details = true);
Atom _command_risk_grade_label(State &state, int64_t severity);
DictRef _town_command_risk_state(State &state, DictRef session, DictRef town, bool include_front = true);
// {"session": a projected view, "town": the town}: not a registry entry, since
// GDScript's holds a SessionData.
DictRef _project_player_town_at_daybreak(State &state, DictRef session, DictRef town, int64_t town_index, int64_t next_day);
DictRef _advance_town_occupation(State &state, DictRef session, DictRef town);
DictRef _advance_town_recovery(State &state, DictRef session, DictRef town);
// session: a view, or Nil for GDScript's null.
DictRef _town_capital_project_state(State &state, DictRef town, const Value &session, DictRef logistics_state, DictRef recovery_state);
ArrayRef _town_capital_project_ids(State &state, DictRef town);
int64_t _town_capital_project_recovery_relief(State &state, DictRef town);
ArrayRef _project_dependency_ids(State &state, Atom project_id);
DictRef _blank_project_vulnerability_penalties(State &state);
int64_t _town_recovery_relief_rating(State &state, DictRef session, DictRef town, DictRef logistics_state);
int64_t _town_building_bonus_total(State &state, DictRef town, Atom bonus_key);
DictRef _nearest_town_for_controller(State &state, DictRef session, Atom controller_id, int64_t x, int64_t y, int64_t level = -1);
bool _town_matches_controller(State &state, DictRef town, Atom controller_id);
bool _raid_is_public(State &state, DictRef session, DictRef encounter);
Vector2i hero_position(State &state, DictRef session);
Atom town_strategic_role(State &state, DictRef town);
bool _fog_state_ready(State &state, DictRef session);
ArrayRef _fog_grids(State &state, DictRef session, int64_t level);
ArrayRef _fog_grids_uncached(State &state, DictRef session, int64_t level);
bool _grid_cell(State &state, const Value &grid, int64_t x, int64_t y);
bool is_tile_visible(State &state, DictRef session, int64_t x, int64_t y, int64_t level = -1);


// The day's economy: end_turn's opening half and what it runs (day_economy.cpp).
DictRef _end_turn_open_day(State &state, DictRef session);
ArrayRef _advance_all_town_occupations(State &state, DictRef session);
ArrayRef _advance_all_town_recovery(State &state, DictRef session);
bool is_weekly_growth_day(State &state, int64_t day);
DictRef _player_heroes_daily_income(State &state, DictRef session);
ArrayRef _player_hero_states(State &state, DictRef session);
DictRef controlled_resource_site_income(State &state, DictRef session, Atom controller_id, int64_t income_day = -1);
DictRef _resource_site_control_income_for_day(State &state, DictRef site, int64_t day);
bool _resource_node_matches_controller(State &state, DictRef node, Atom controller_id);
ArrayRef apply_controlled_resource_site_musters(State &state, DictRef session, Atom controller_id);
DictRef _resource_site_weekly_recruits(State &state, DictRef site);
void _add_resources(State &state, DictRef session, const Value &delta);
void _refresh_all_player_heroes_for_new_day(State &state, DictRef session);
ArrayRef _advance_player_reserve_deliveries(State &state, DictRef session);
Atom _resource_site_delivery_target_label(State &state, DictRef session, Atom target_kind, Atom target_id, Atom fallback_label = state::key::empty);
Atom _describe_recruit_delta(State &state, const Value &delta);
int64_t _weighted_recruit_value(State &state, const Value &recruits);
Atom _describe_resource_delta(State &state, const Value &delta);
ArrayRef _resource_keys_for_payload(State &state, const Value &value);
DictRef _add_recruit_growth(State &state, const Value &base_recruits, const Value &delta_recruits);
DictRef _clear_resource_site_delivery(State &state, DictRef node);
// {"index": i, "encounter": encounter}, index -1 when missing.
DictRef _find_encounter_by_placement(State &state, DictRef session, Atom placement_id);

// The day's close: end_turn's second half, an action's result and the turn's
// summaries (day_boundary.cpp).
DictRef _end_turn_close_day(State &state, DictRef session, DictRef opened, DictRef enemy_turn_result);
// The whole day in one call: _end_turn_open_day, the computer players' turn and
// _end_turn_close_day.
DictRef end_turn(State &state, DictRef session);
DictRef _finalize_action_result(State &state, DictRef session, bool ok, Atom base_message, bool refresh_fog, bool incremental_fog, DictRef scenario_event_facts);
DictRef _evaluate_scenario_state(State &state, DictRef session);
void _reveal_current_fog_sources(State &state, DictRef session);
Atom describe_enemy_activity(State &state, const Value &events_value, int64_t limit = 4);
ArrayRef _compact_enemy_activity_events(State &state, const Value &events_value, int64_t limit = 6);
Atom _enemy_activity_line(State &state, DictRef event);
Atom _enemy_activity_public_text(State &state, Atom text);
Atom _short_player_text(State &state, Atom text, int64_t max_chars);
Atom _end_turn_muster_summary(State &state, ArrayRef weekly_growth_messages, ArrayRef site_muster_messages);
Atom _end_turn_town_economy_summary(State &state, ArrayRef occupation_messages, ArrayRef recovery_messages, ArrayRef delivery_messages);
Atom _end_turn_resolution_summary(State &state, DictRef session, DictRef result);

// Phase 4's ports shared with Phase 5's battle ends (overworld_rules_shared.cpp).
DictRef _add_dwelling_town_growth(State &state, DictRef session, DictRef town, DictRef growth);
DictRef _apply_recruit_percent(State &state, const Value &recruits, int64_t percent_modifier);
void _lock_town_occupation_reserves(State &state, DictRef town, DictRef occupation);
DictRef _release_town_occupation_reserves(State &state, DictRef town);
void _rules_profile_add_ms(State &state, Atom bucket, int64_t started_usec);
void _rules_profile_set(State &state, Atom section, Atom key, const Value &value);
int64_t _rules_profile_timer(State &state);
DictRef _town_front_after_control_change(State &state, DictRef session, DictRef town, Atom previous_owner, Atom new_owner, Atom controlling_faction_id, Atom source);
int64_t _town_front_stabilize_days(State &state, DictRef session, DictRef town);
DictRef _town_front_stabilizing_state(State &state, DictRef session, DictRef town, Atom faction_id, Atom source, Atom previous_owner = state::key::empty, int64_t bonus_days = 0);
bool _town_is_objective_anchor(State &state, DictRef session, Atom placement_id);
DictRef _town_occupation_after_control_change(State &state, DictRef session, DictRef town, Atom previous_owner, Atom new_owner, Atom controlling_faction_id, Atom source);
DictRef _town_weekly_growth(State &state, DictRef town, const Value &session, DictRef metric_context);
Atom apply_town_recovery_pressure(State &state, DictRef session, Atom town_placement_id, int64_t amount, Atom source = state::key::empty);
void invalidate_spatial_lookup(State &state, DictRef session);
DictRef town_recovery_state(State &state, DictRef session, DictRef town);
DictRef transition_town_control(State &state, DictRef session, Atom placement_id, Atom new_owner, Atom controlling_faction_id = state::key::empty, Atom source = state::key::empty);

// Ported in Phase 5's slice 09 (battle_end_towns.cpp).
Atom _normalized_enemy_front_faction_id(State &state, DictRef session, DictRef front, DictRef town);
void _teach_visiting_town_spells(State &state, DictRef session, DictRef town);
int64_t _town_occupation_seed_pressure(State &state, DictRef session, DictRef town);

} // namespace aurelion::rules::port::overworld_rules
