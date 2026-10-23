#pragma once

// The human seat's move and its arrival (docs/native-rules-engine-transition.md,
// Phase 7, slice 7.2), ported function by function under the GDScript names:
// the step and the route, transit, boats, what the destination does, resource
// sites, dwellings, visit buildings, artifacts, the encounter's texts, the
// post-action recap and the action's scenario check narrowed to its event
// facts. A session is its view (session_view.hpp).

#include "aurelion_rules/port/gd.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"
#include "aurelion_rules/port/overworld_rules_human.hpp"

#include <cstdint>
#include <functional>

namespace aurelion::rules::port::overworld_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using state::State;
using state::Value;

// overworld_rules_move.cpp.
void _rules_profile_begin(State &state);
DictRef _rules_profile_finish(State &state);
void _rules_profile_count(State &state, Atom key, int64_t amount = 1);
void normalize_overworld_state_for_runtime(State &state, DictRef session);
void _store_level_fog(State &state, DictRef session, DictRef payload, int64_t level = -1);
DictRef try_move(State &state, DictRef session, int64_t dx, int64_t dy);
DictRef travel_native_passage(State &state, DictRef session, DictRef node, int64_t movement_cost = 1);
Atom native_portal_display_name(State &state, DictRef node);
// destination: a Vector3i (gd::vector3i).
Atom _native_travel_message(State &state, DictRef node, const Value &destination);
DictRef active_linked_transit_step(State &state, DictRef session, Vector2i from_tile, Vector2i to_tile);
DictRef try_move_along_route(State &state, DictRef session, const Value &route_tiles, int64_t movement_budget = -1, bool resolve_destination_interaction = true);
ArrayRef _apply_water_route_arrival(State &state, DictRef session, ArrayRef path, int64_t reachable_steps);
bool _descriptor_matches_hero_level(State &state, DictRef session, DictRef descriptor);
DictRef execute_prevalidated_route(State &state, DictRef session, const Value &route_tiles, DictRef route_preview, int64_t movement_budget, DictRef destination_descriptor);
bool _tile_blocks_route_step(State &state, DictRef session, Vector2i tile, bool is_destination);
void _set_active_hero_position(State &state, DictRef session, Vector2i tile, int64_t level = -1);
void _reveal_route_fog(State &state, DictRef session, ArrayRef traversed_tiles);
bool _visibility_grid_has_shape(State &state, const Value &grid, Vector2i map_size);

// water_travel_rules_human.cpp.
ArrayRef _whirlpool_throw(State &state, DictRef session, DictRef node);

// overworld_rules_arrival.cpp.
DictRef _resolve_post_move_interaction(State &state, DictRef session);
DictRef _resolve_destination_descriptor_interaction(State &state, DictRef session, DictRef descriptor);
DictRef get_active_encounter(State &state, DictRef session);
DictRef _engaging_encounter_at_tile(State &state, DictRef session, Vector2i pos, int64_t level);
DictRef _field_rendezvous_hero_at_tile(State &state, DictRef session, Vector2i tile);
DictRef _field_rendezvous_result(State &state, DictRef session, DictRef reserve);
void clear_active_town_visit(State &state, DictRef session);
DictRef capture_active_town(State &state, DictRef session);
DictRef _begin_town_assault(State &state, DictRef session, DictRef town);
bool _town_requires_assault(State &state, DictRef town);
Atom relieve_town_recovery_pressure(State &state, DictRef session, Atom town_placement_id, int64_t amount, Atom source = state::key::empty);
void _refresh_blocked_tile_index_for_interaction(State &state, DictRef session, DictRef topology_facts);
void _profile_blocked_index_not_applicable(State &state, DictRef session, Atom reason);
DictRef _resource_topology_facts(State &state, DictRef before_node, DictRef after_node, DictRef map_object);
ArrayRef _tile_key_array(State &state, ArrayRef tiles);
DictRef _resource_interaction_event_facts(State &state, DictRef node, DictRef site, Atom previous_controller, DictRef rewards, DictRef visit_cost, DictRef topology_facts);
DictRef _artifact_interaction_event_facts(State &state, DictRef node);
DictRef _encounter_handoff_event_facts(State &state, DictRef encounter);
DictRef _town_visit_event_facts(State &state, DictRef town);
DictRef _town_capture_event_facts(State &state, DictRef town, Atom previous_owner, Atom new_owner);
DictRef _interactable_result_payload(State &state, Atom family, DictRef placement, DictRef mutation_facts, DictRef topology_facts);
DictRef _profile_scenario_event_evaluation(State &state, DictRef session, DictRef event_facts);
DictRef _evaluate_scenario_state_for_event(State &state, DictRef session, DictRef event_facts);
Atom _scenario_objective_player_label(State &state, DictRef session, DictRef objective);

// overworld_rules_collect.cpp.
DictRef collect_active_resource(State &state, DictRef session);
DictRef _route_lock_prompt(State &state, DictRef session, DictRef node, DictRef site);
DictRef _resource_reward_choice_context(State &state, DictRef session, DictRef node);
ArrayRef _resource_site_reward_choices(State &state, DictRef site);
Atom _resource_site_artifact_summary(State &state, DictRef site);
Atom _spell_list_text(State &state, ArrayRef names);
Atom _resource_site_reward_summary(State &state, DictRef site);
DictRef _collect_resource_node_result(State &state, DictRef session, DictRef node_result, bool refresh_fog_after_action = true, int64_t native_transit_cost = 1, Atom reward_choice_id = state::key::empty);
bool _resource_site_grants_command_lesson(State &state, DictRef site);
bool _open_resource_site_route_body(State &state, DictRef node, DictRef site);
DictRef _clear_resource_site_response(State &state, DictRef node);
int64_t _reveal_resource_site_claim_fog(State &state, DictRef session, DictRef node, int64_t radius);

// overworld_rules_site_queries.cpp.
DictRef _find_resource_node_at(State &state, DictRef session);
DictRef _find_context_resource_node(State &state, DictRef session);
DictRef _find_resource_node_interaction_at(State &state, DictRef session);
DictRef _resource_site_visit_cost(State &state, DictRef site);
bool _resource_site_repeat_ready(State &state, DictRef session, DictRef node, DictRef site);
int64_t _resource_site_next_visit_day(State &state, DictRef node, DictRef site);
Atom _resource_site_repeatable_block_message(State &state, DictRef session, DictRef node, DictRef site);
// session: a view, or Nil.
bool _resource_node_claimable_by_player(State &state, DictRef node, DictRef site, const Value &session);
DictRef _resource_defender_battle_payload(State &state, DictRef session, DictRef node, DictRef site);
bool _resource_node_has_live_ai_defender(State &state, DictRef session, DictRef node, DictRef site);
DictRef _resource_site_claim_rewards(State &state, DictRef site);
DictRef _resource_site_claim_recruits(State &state, DictRef site);
DictRef _resource_site_claim_flags(State &state, DictRef site);
bool hero_is_visiting_resource_site(State &state, DictRef session, DictRef node);
bool resource_site_is_recruit_source(State &state, DictRef site);
Atom _resource_site_claim_message(State &state, DictRef site, Atom previous_controller);
Atom _resource_site_yield_line(State &state, DictRef session, DictRef node, DictRef site);
Atom _resource_site_income_cadence_label(State &state, DictRef site);
// positions: as GDScript gets it (null when the caller passes none).
DictRef _resource_site_guard_encounter(State &state, DictRef session, DictRef node, DictRef site, const Value &positions);
bool _resource_site_guard_blocks_node(State &state, DictRef encounter, DictRef node);
bool _resource_site_guard_targets_node(State &state, DictRef guard, DictRef node, DictRef site);
DictRef _find_resource_node_by_guard(State &state, DictRef guard, DictRef session);
DictRef collect_active_artifact(State &state, DictRef session);
DictRef _collect_artifact_node_result(State &state, DictRef session, DictRef node_result, bool refresh_fog_after_action = true);
DictRef _find_active_artifact_node(State &state, DictRef session);
DictRef _find_artifact_node_by_descriptor(State &state, DictRef session, DictRef descriptor);

// overworld_rules_site_effects.cpp.
DictRef _dwelling_guard_battle_result(State &state, DictRef session, DictRef node, DictRef site);
DictRef dwelling_recruit_offer(State &state, DictRef session, DictRef node, DictRef site);
bool _dwelling_has_creatures_for_hire(State &state, DictRef offer);
DictRef _dwelling_recruit_result(State &state, DictRef session, DictRef node, DictRef site, Atom prefix);
DictRef _attach_dwelling_recruit_offer(State &state, DictRef session, DictRef result, DictRef node, DictRef site);
DictRef _apply_resource_site_strategic_effects(State &state, DictRef session, DictRef node, DictRef site);
DictRef _apply_shrine_command_bonus(State &state, DictRef session, DictRef site);
DictRef _visit_building_result(State &state, DictRef session, DictRef node_result, DictRef site, bool refresh_fog_after_action, Atom choice_id);
Atom _visit_effect_blocker(State &state, DictRef session, DictRef node, DictRef effect);
ArrayRef _apply_visit_effects(State &state, DictRef session, DictRef node, DictRef site, DictRef effect);

// overworld_rules_site_rewards.cpp.
Atom _grant_site_claim_recruits(State &state, DictRef session, const Value &recruits, DictRef node, DictRef site);
DictRef _add_to_active_army(State &state, DictRef session, DictRef recruits);
Atom _describe_recruit_count(State &state, DictRef recruits);
Atom _learn_site_spell(State &state, DictRef session, Atom spell_id);
ArrayRef _learn_site_spells(State &state, DictRef session, const Value &spell_ids);
ArrayRef _resource_site_spell_names(State &state, DictRef site);
ArrayRef _award_experience(State &state, DictRef session, int64_t amount);
bool _can_afford(State &state, DictRef session, const Value &cost);
void _sync_spellbook_to_hero(State &state, DictRef session, int64_t previous_max);
DictRef _grant_resource_site_artifact_reward(State &state, DictRef session, DictRef node, DictRef site);
DictRef _army_totals(State &state, DictRef army);

// overworld_rules_encounter_text.cpp.
Atom describe_encounter_compact_readability(State &state, DictRef session, DictRef encounter);
Atom describe_encounter_battle_cue(State &state, DictRef session, DictRef encounter);
Atom describe_encounter_consequence_surface(State &state, DictRef session, DictRef encounter, bool compact = false);
DictRef _encounter_guard_link(State &state, DictRef encounter);
// session: a view, or Nil.
Atom _encounter_guard_summary(State &state, DictRef encounter, const Value &session);
Atom _encounter_readiness_surface(State &state, DictRef session, DictRef encounter, bool compact = false);
Atom _encounter_guard_consequence_line(State &state, DictRef session, DictRef encounter, bool compact = false);
Atom _encounter_objective_consequence_line(State &state, DictRef session, DictRef encounter);
Atom _encounter_hook_consequence_line(State &state, DictRef session, DictRef encounter);
ArrayRef _encounter_clear_objectives(State &state, DictRef session, DictRef encounter);
ArrayRef _encounter_clear_objective_ids(State &state, DictRef session, DictRef encounter);
bool _hook_follows_encounter_clear(State &state, DictRef hook, DictRef encounter, ArrayRef objective_ids);
Atom _script_hook_effect_consequence_summary(State &state, const Value &effects);
Atom _encounter_risk_label(State &state, DictRef encounter);
Atom _encounter_difficulty_label(State &state, DictRef encounter);
Atom _encounter_army_surface(State &state, DictRef encounter, bool include_units);
DictRef _encounter_army_payload(State &state, DictRef encounter);
Atom _encounter_army_unit_summary(State &state, DictRef army);
Atom _encounter_reward_surface(State &state, DictRef encounter);
Atom _encounter_guard_target_label(State &state, DictRef session, DictRef guard);
ArrayRef _non_empty_strings(State &state, ArrayRef value);
Atom _humanize_id(State &state, Atom value);

// overworld_rules_recap.cpp.
DictRef _attach_post_action_recap(State &state, DictRef result, DictRef session, Atom action_kind, DictRef context);
DictRef _build_post_action_recap(State &state, DictRef session, Atom action_kind, DictRef context, Atom message);
DictRef _movement_post_action_recap(State &state, DictRef session, DictRef context, Atom message);
DictRef _resource_site_post_action_recap(State &state, DictRef session, DictRef context, Atom message);
DictRef _artifact_post_action_recap(State &state, DictRef session, DictRef context, Atom message);
DictRef _site_response_post_action_recap(State &state, DictRef session, DictRef context, Atom message);
DictRef _spell_post_action_recap(State &state, DictRef session, DictRef context, Atom message);
DictRef _town_capture_post_action_recap(State &state, DictRef session, DictRef context, Atom message);
DictRef _town_visit_post_action_recap(State &state, DictRef session, DictRef context, Atom message);
DictRef _battle_post_action_recap(State &state, DictRef session, DictRef context, Atom message);
DictRef _generic_post_action_recap(State &state, DictRef session, Atom action_kind, DictRef context, Atom message);
DictRef _post_action_recap_payload(State &state, Atom kind, Atom happened, Atom affected, Atom why_it_matters, Atom next_step, Atom cue_text);
DictRef _normalize_post_action_recap(State &state, const Value &value);
DictRef _post_action_tile_context(State &state, DictRef session, Vector2i tile);
DictRef _post_action_resource_node(State &state, DictRef session, DictRef context);
Atom _post_action_tile_label(State &state, DictRef context, DictRef fallback);
Atom _post_action_next_step(State &state, DictRef session);
Atom _resource_site_post_action_why(State &state, DictRef site);
Atom _first_sentence_or_default(State &state, Atom text, Atom fallback);
Atom _sentence_with_keyword_or_default(State &state, Atom text, Atom keyword, Atom fallback);

} // namespace aurelion::rules::port::overworld_rules

namespace aurelion::rules::port::water_travel_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// water_travel_rules_human.cpp.
void embark(State &state, const Value &session, DictRef boat);
void disembark(State &state, const Value &session, Vector2i mooring, int64_t level);
void follow_active_hero(State &state, const Value &session, Vector2i tile, int64_t level);
void _set_active_hero_boat(State &state, const Value &session, Atom boat_id);
// blocked: the Callable, blocked.call(tile, level).
DictRef whirlpool_exit(State &state, const Value &session, DictRef node, const std::function<bool(Vector2i, int64_t)> &blocked);
DictRef whirlpool_losses(State &state, ArrayRef stacks);

} // namespace aurelion::rules::port::water_travel_rules

namespace aurelion::rules::port::hero_command_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// overworld_rules_arrival.cpp.
ArrayRef field_rendezvous_heroes(State &state, DictRef session);

} // namespace aurelion::rules::port::hero_command_rules

namespace aurelion::rules::port::native_transit_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// overworld_rules_move.cpp.
DictRef network_colour(State &state, DictRef node);

} // namespace aurelion::rules::port::native_transit_rules

namespace aurelion::rules::port::overworld_level_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// overworld_rules_move.cpp.
DictRef moved_position(State &state, const Value &previous, Vector2i tile, int64_t level = -1);

} // namespace aurelion::rules::port::overworld_level_rules

namespace aurelion::rules::port::creature_dwelling_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// overworld_rules_site_effects.cpp.
Atom describe_creatures(State &state, DictRef node, DictRef site, int64_t day);
Atom summary(State &state, DictRef node, DictRef site, int64_t day);

} // namespace aurelion::rules::port::creature_dwelling_rules

namespace aurelion::rules::port::visit_building_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// overworld_rules_site_effects.cpp.
Atom side_key(State &state, const Value &session);
Atom cadence_label(State &state, DictRef site);
Atom summary(State &state, DictRef site);
Atom status_line(State &state, DictRef node, DictRef site, Atom visitor_key, int64_t day, Atom side = state::key::empty);
void add_week_bonus(State &state, DictRef hero, Atom key, int64_t amount);
int64_t week_bonus(State &state, DictRef hero, Atom key);
DictRef add_battle_boosts(State &state, DictRef hero, DictRef boosts);

} // namespace aurelion::rules::port::visit_building_rules

namespace aurelion::rules::port::scenario_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// scenario_event_check.cpp.
DictRef evaluate_session_for_event(State &state, DictRef session, DictRef event_facts);
DictRef _scenario_event_dependency_profile(State &state, DictRef session, DictRef event_facts);
DictRef _scenario_dependency_metadata_for_session(State &state, DictRef session);
DictRef _scenario_dependency_metadata(State &state, DictRef scenario);
DictRef _scenario_objective_dependency(State &state, DictRef objective, DictRef objective_index, DictRef seen);
DictRef _scenario_hook_dependency(State &state, DictRef hook, ArrayRef objective_dependencies, const Value &objectives);
DictRef _scenario_condition_dependency(State &state, DictRef condition, DictRef objective_index);
DictRef _empty_dependency(State &state);
DictRef _scenario_event_dependency(State &state, DictRef event_facts);
bool _scenario_event_affects_dependency(State &state, DictRef event_dependency, DictRef dependency);
void _merge_dependency(State &state, DictRef target, DictRef source);
void _add_dependency_value(State &state, DictRef dependency, Atom key, Atom value);
ArrayRef _string_array(State &state, const Value &value);
bool _arrays_intersect(State &state, const Value &left, const Value &right);

// scenario_objective_label.cpp.
Atom _objective_label(State &state, DictRef session, DictRef objective);

} // namespace aurelion::rules::port::scenario_rules
