#pragma once

// The human seat's context and site actions (docs/native-rules-engine-transition.md,
// Phase 7, slice 7.3), ported function by function under the GDScript names: the
// context and its actions, a site's response order and its reserve delivery, a
// resource site's surfaces, building and recruiting in the visited town, the reward
// choice, dwelling hire, site recruits, level-up, specialties, army slots and the
// artifact texts they show. A session is its view (session_view.hpp).

#include "aurelion_rules/port/gd.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"
#include "aurelion_rules/port/overworld_rules_human.hpp"
#include "aurelion_rules/port/overworld_rules_move.hpp"

#include <cstdint>

namespace aurelion::rules::port::overworld_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using state::State;
using state::Value;

// overworld_rules_context.cpp.
Atom describe_native_portal(State &state, DictRef session, DictRef node);
DictRef perform_context_action(State &state, DictRef session, Atom action_id);
DictRef get_active_context(State &state, DictRef session);
ArrayRef get_context_actions(State &state, DictRef session);
Atom _resource_site_context_summary(State &state, DictRef session, DictRef node, DictRef site);
Atom resource_site_primary_stockpile_resource_id(State &state, DictRef site);
Atom _context_action_briefing(State &state, DictRef session, const Value &action, DictRef context);
Atom _context_action_summary(State &state, DictRef session, Atom action_id, DictRef context);
Atom _encounter_delivery_pressure_summary(State &state, DictRef session, DictRef encounter, bool for_battle_prompt = false);
Atom _encounter_pressure_summary(State &state, DictRef session, DictRef encounter, bool for_battle_prompt = false);
Atom _resource_site_opening_value(State &state, DictRef site);

// overworld_rules_site_response.cpp.
Atom _resource_site_response_effect_summary(State &state, DictRef response_state);
int64_t _estimate_reserve_delivery_eta(State &state, Vector2i origin, Vector2i target, int64_t security_rating, int64_t max_days);
DictRef _player_reserve_delivery_plan(State &state, DictRef session, DictRef source_town, DictRef response_state);
ArrayRef _player_reserve_delivery_candidates(State &state, DictRef session, DictRef source_town, DictRef response_state);
int64_t _player_hero_delivery_priority(State &state, DictRef session, DictRef hero);
DictRef _reserve_delivery_manifest_for_candidate(State &state, DictRef session, DictRef source_town, DictRef candidate, DictRef response_state);
int64_t _reserve_delivery_unit_priority(State &state, Atom unit_id, Atom target_kind);
int64_t _reserve_delivery_unit_value(State &state, Atom unit_id);
bool _town_should_hold_back_reserves(State &state, DictRef session, DictRef town);
DictRef _consume_recruit_payload(State &state, const Value &recruits, const Value &manifest);
DictRef _resource_site_response_action(State &state, DictRef session, DictRef node, DictRef site);
DictRef _issue_active_site_response(State &state, DictRef session);
DictRef _issue_resource_site_response(State &state, DictRef session, Atom placement_id, Atom origin);
int64_t _army_unit_count(State &state, const Value &stacks, Atom unit_id);

// overworld_rules_site_text.cpp.
// session: a view, or Nil.
Atom describe_recruit_source_inspection(State &state, const Value &session, DictRef node, DictRef site);
Atom _resource_site_neutral_dwelling_label(State &state, DictRef site);
Atom _resource_site_family_label(State &state, DictRef site);
Atom describe_resource_site_surface(State &state, DictRef session, DictRef node, DictRef site);
// session: a view, or Nil.
Atom describe_resource_site_control_inspection(State &state, const Value &session, DictRef node, DictRef site);
Atom describe_resource_site_interaction_surface(State &state, DictRef node, DictRef site);
Atom _recruit_source_roster_line(State &state, Atom label, const Value &recruits, int64_t limit, bool dwelling_prices = false);
Atom _unit_role_tier_label(State &state, DictRef unit);
// session: a view, or Nil.
Atom _recruit_source_support_readiness_line(State &state, const Value &session, DictRef node, DictRef site);
Atom _recruit_source_why_line(State &state, DictRef site);
Atom _resource_site_action_label(State &state, DictRef node, DictRef site);
Atom _resource_site_role_label(State &state, DictRef node, DictRef site);
Atom _resource_site_control_label(State &state, DictRef node, DictRef site);
Atom _resource_site_control_brief(State &state, DictRef node, DictRef site);
Atom _resource_site_control_detail(State &state, DictRef node, DictRef site);
// session: a view, or Nil.
Atom _resource_site_route_line(State &state, const Value &session, DictRef node, DictRef site);
// session: a view, or Nil.
Atom _resource_site_guard_or_contest_line(State &state, const Value &session, DictRef node, DictRef site);
// session: a view, or Nil.
DictRef _resource_site_contest_encounter(State &state, const Value &session, DictRef node, Atom controller_id);
Atom _resource_site_object_class_label(State &state, DictRef site, DictRef map_object);
Atom _resource_site_interaction_cadence(State &state, DictRef site, DictRef map_object);
Atom _interaction_cadence_label(State &state, Atom cadence);
Atom _resource_site_role_tag_summary(State &state, DictRef site, DictRef map_object);
ArrayRef _fallback_resource_site_roles(State &state, DictRef site);
Atom _controller_display_name(State &state, Atom controller_id, Atom faction_id = state::key::empty);

// overworld_rules_town_actions.cpp.
int64_t _scenario_unit_growth(State &state, Atom unit_id);
DictRef build_in_active_town(State &state, DictRef session, Atom building_id);
DictRef recruit_in_active_town(State &state, DictRef session, Atom unit_id, int64_t requested_count = -1, bool runtime_normalized = false);
bool town_built_today(State &state, DictRef town, int64_t day);
DictRef town_cost_readiness(State &state, DictRef town, DictRef pool, const Value &cost, int64_t current_day = -1);
DictRef town_recruit_cost(State &state, DictRef session, DictRef town, Atom unit_id);
ArrayRef _market_buy_resources(State &state, DictRef market_state);
DictRef _town_market_cost_coverage(State &state, DictRef town, DictRef pool, const Value &cost, int64_t current_day = -1);
ArrayRef _apply_market_cost_coverage(State &state, DictRef town, DictRef pool, const Value &cost, int64_t current_day = -1);
DictRef _building_growth_payload(State &state, Atom building_id);
int64_t _max_affordable_count(State &state, DictRef session, const Value &unit_cost);
bool _resource_pool_meets_cost(State &state, DictRef pool, DictRef cost);
DictRef _resource_pool_shortfall(State &state, DictRef pool, DictRef cost);
DictRef _apply_percent_discount(State &state, const Value &cost, int64_t discount_percent);
int64_t _recruitment_discount_percent(State &state, DictRef town, Atom unit_id);
int64_t _cost_discount_from_profile(State &state, const Value &profile, Atom unit_id);
void _apply_resource_transaction_to_pool(State &state, DictRef pool, const Value &cost, const Value &gain);
Atom resource_icon_path(State &state, Atom resource_id);
Atom _describe_resource_change(State &state, const Value &before, const Value &after);
Atom _describe_cost_shortfall(State &state, DictRef readiness);
Atom _describe_recruit_projection(State &state, const Value &current, const Value &projected);
Atom _describe_signed_int(State &state, int64_t value);

// overworld_rules_hero_choices.cpp.
DictRef choose_resource_reward(State &state, DictRef session, Atom choice_id, DictRef expected_context);
DictRef hire_from_dwelling(State &state, DictRef session, DictRef hires, DictRef expected_context);
DictRef get_level_up_prompt(State &state, DictRef session);
DictRef resolve_level_up(State &state, DictRef session, DictRef context, Atom specialty_id = state::key::empty);
ArrayRef get_specialty_actions(State &state, DictRef session);
DictRef choose_specialty(State &state, DictRef session, Atom specialty_id, Atom hero_id = state::key::empty);
DictRef _pending_site_recruits(State &state, DictRef session);
DictRef site_recruit_overflow_prompt(State &state, DictRef session);
bool _pending_matches(State &state, DictRef pending, DictRef expected_context);
DictRef take_site_recruits_by_dismissing(State &state, DictRef session, int64_t slot_index, DictRef expected_context);
DictRef leave_site_recruits(State &state, DictRef session, DictRef expected_context);

} // namespace aurelion::rules::port::overworld_rules

namespace aurelion::rules::port::hero_command_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// overworld_rules_site_response.cpp.
DictRef spend_active_hero_movement(State &state, DictRef session, int64_t amount, Atom reason = state::key::empty);

// overworld_rules_town_actions.cpp.
DictRef town_recruitment_destination(State &state, DictRef session, DictRef town);

// overworld_rules_hero_choices.cpp.
DictRef army_slot_snapshot(State &state, DictRef session, DictRef town, Atom holder_id);
ArrayRef _stationed_holder_ids(State &state, DictRef session, DictRef town);
bool _army_slot_holder_is_available(State &state, DictRef session, DictRef town, Atom holder_id);
bool _is_field_exchange_partner(State &state, DictRef session, Atom hero_id);
Atom _holder_label(State &state, DictRef session, DictRef town, Atom holder_id);

} // namespace aurelion::rules::port::hero_command_rules

namespace aurelion::rules::port::hero_progression_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// overworld_rules_town_actions.cpp.
DictRef scale_recruit_cost(State &state, DictRef hero_state, const Value &cost_payload);

// overworld_rules_hero_choices.cpp.
DictRef level_up_summary(State &state, DictRef hero_state);
ArrayRef get_choice_actions(State &state, DictRef hero_state);
Atom rank_text(State &state, Atom specialty_id, int64_t rank);

} // namespace aurelion::rules::port::hero_progression_rules

namespace aurelion::rules::port::creature_dwelling_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// overworld_rules_hero_choices.cpp.
DictRef hire_cost(State &state, DictRef hires);

} // namespace aurelion::rules::port::creature_dwelling_rules

namespace aurelion::rules::port::artifact_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// artifact_rules_text.cpp.
Atom describe_single_artifact_impact(State &state, Atom artifact_id);
Atom describe_artifact_short(State &state, Atom artifact_id);
Atom artifact_collection_state(State &state, DictRef hero_state, Atom artifact_id, bool collected = false, Atom collected_by_faction_id = state::key::empty);
Atom _owned_location_label(State &state, Atom artifact_id, DictRef location);
DictRef _artifact_bonus_totals(State &state, DictRef artifact);
ArrayRef _bonus_impact_sections(State &state, DictRef totals, bool include_empty_sections);
ArrayRef _resource_impact_parts(State &state, const Value &value);

} // namespace aurelion::rules::port::artifact_rules
