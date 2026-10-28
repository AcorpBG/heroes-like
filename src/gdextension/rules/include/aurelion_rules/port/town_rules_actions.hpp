#pragma once

// The human seat's town actions (docs/native-rules-engine-transition.md,
// Phase 7, slice 7.6), ported function by function under the GDScript names:
// building, recruiting, the market, responses, spell learning, the town's
// services and tavern, the building panel and the construction board, and the
// action lists. A session is its view (session_view.hpp).

#include "aurelion_rules/port/gd.hpp"
#include "aurelion_rules/port/overworld_rules_heroes.hpp"

#include <cstdint>

namespace aurelion::rules::port::overworld_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using state::State;
using state::Value;

// overworld_rules_town_wrappers.cpp: the OverworldRules wrappers and texts the
// town's build, recruit and market actions call.
// A session that may be null (the town's base quality, readiness and pressure).
int64_t town_reinforcement_quality(State &state, DictRef town, const Value &session);
int64_t town_battle_readiness(State &state, DictRef town, const Value &session);
int64_t town_pressure_output(State &state, DictRef town, const Value &session);
DictRef town_logistics_state(State &state, DictRef session, DictRef town);
ArrayRef get_town_market_actions(State &state, DictRef session, DictRef town);
DictRef perform_town_market_action(State &state, DictRef session, DictRef town, Atom action_id);
bool can_afford_cost_with_town_market(State &state, DictRef town, DictRef pool, const Value &cost, int64_t current_day = -1);
Atom describe_town_build_projection(State &state, DictRef session, DictRef town, Atom building_id);
Atom describe_unit_recruit_brief(State &state, Atom unit_id, int64_t count = 0);
Atom unit_tier_label(State &state, DictRef unit);
Atom unit_role_label(State &state, DictRef unit);
int64_t unit_stack_strength_value(State &state, Atom unit_id, int64_t count);
int64_t unit_strength_value(State &state, Atom unit_id);
ArrayRef get_town_recruit_options(State &state, DictRef town);
ArrayRef _town_market_actions(State &state, DictRef session, DictRef town);
DictRef _market_action_entry(State &state, DictRef session, DictRef town, DictRef market_state, DictRef quote);
DictRef _execute_town_market_action(State &state, DictRef session, DictRef town, Atom action_id);
ArrayRef get_town_response_actions(State &state, DictRef session, DictRef town);
DictRef perform_town_response_action(State &state, DictRef session, DictRef town, Atom action_id);
ArrayRef _town_response_actions(State &state, DictRef session, DictRef town);
DictRef _execute_town_response_action(State &state, DictRef session, DictRef town, Atom action_id);
DictRef _town_recovery_stabilize_profile(State &state, DictRef town);
DictRef _stabilize_town_recovery(State &state, DictRef session, DictRef town);
Atom _summarize_market_actions(State &state, const Value &actions, int64_t max_steps = 2);

} // namespace aurelion::rules::port::overworld_rules

namespace aurelion::rules::port::scenario_rules {

using gd::ArrayRef;
using gd::DictRef;
using state::State;

// overworld_rules_town_wrappers.cpp: the artifacts a scenario's objectives name.
ArrayRef objective_artifact_ids(State &state, DictRef session);

} // namespace aurelion::rules::port::scenario_rules

namespace aurelion::rules::port::town_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// town_rules_build.cpp.
Atom building_id_for_action(State &state, Atom action_id);
Atom building_category_icon_path(State &state, Atom building_id);
Atom building_icon_path(State &state, Atom building_id, Atom faction_id = state::key::empty);
ArrayRef get_build_actions(State &state, DictRef session);
ArrayRef get_build_catalog(State &state, DictRef session);
DictRef build_active_town(State &state, DictRef session, Atom building_id);
Atom _build_choice_impact_line(State &state, DictRef session, DictRef town, Atom building_id, DictRef building);
Atom _action_recommendation_line(State &state, Atom lane, Atom label, bool ready, bool market_coverable, Atom shortfall_summary, Atom impact_line);
Atom _build_action_badge(State &state, bool ready, bool market_coverable);
Atom _signed_int(State &state, int64_t value);
ArrayRef _available_building_ids(State &state, DictRef town, int64_t current_day = -1);
Atom _building_line(State &state, Atom building_id, Atom building_state, DictRef build_status);
Atom _building_effect_summary(State &state, DictRef building);
Atom _town_name(State &state, DictRef town);
Atom _town_pressure_label(State &state, DictRef town);
Atom _pressure_noun_for_building(State &state, DictRef building);
Atom _describe_support_requirements(State &state, DictRef requirements);
Atom _describe_vulnerability_penalties(State &state, DictRef penalties);

// town_rules_recruit.cpp.
ArrayRef get_recruit_actions(State &state, DictRef session);
ArrayRef get_muster_catalog(State &state, DictRef session);
bool _muster_catalog_row_less(State &state, DictRef left, DictRef right);
DictRef recruit_active_town(State &state, DictRef session, Atom unit_id, int64_t requested_count = -1, bool runtime_normalized = false);
Atom _recruit_choice_impact_line(State &state, Atom unit_id, int64_t ready_count, int64_t available_count);
Atom _recruit_action_badge(State &state, int64_t ready_count, int64_t market_count);
Atom _unit_tier_label(State &state, int64_t unit_tier);
Atom _cost_shortfall_line(State &state, DictRef readiness);
Atom _cost_readiness_line(State &state, DictRef resources, const Value &cost, DictRef readiness);
Atom _stock_against_cost_line(State &state, DictRef resources, const Value &cost);
Atom _stores_after_cost_line(State &state, DictRef resources, const Value &cost);
Atom _recruit_affordability_label(State &state, int64_t direct_count, int64_t market_count, Atom shortfall_summary);
Atom _disabled_reason_line(State &state, bool ready, bool market_coverable, Atom market_summary, Atom shortfall_summary);
DictRef _multiply_resource_cost(State &state, const Value &cost, int64_t multiplier);
int64_t _max_affordable_count(State &state, DictRef session, const Value &unit_cost);
ArrayRef _town_unit_ids(State &state, DictRef town);
bool _unit_is_unlocked_in_town(State &state, DictRef town, Atom unit_id);
Atom _unlock_building_for_unit(State &state, DictRef town, Atom unit_id);

// town_rules_market.cpp.
ArrayRef get_market_actions(State &state, DictRef session);
DictRef perform_market_action(State &state, DictRef session, Atom action_id);
DictRef market_desk(State &state, DictRef session, DictRef need);
ArrayRef _market_slider_counts(State &state, DictRef market, Atom give_id, Atom receive_id, int64_t max_amount);
DictRef _market_suggestion(State &state, DictRef pairs, DictRef stock, DictRef need);
DictRef _perform_market_conversion(State &state, DictRef session, DictRef town, Atom give_id, Atom receive_id, int64_t amount);
Atom market_action_label(State &state, Atom action_id);
Atom _market_coverage_line(State &state, DictRef readiness);
int64_t _max_market_affordable_count(State &state, DictRef session, DictRef town, DictRef resources, const Value &unit_cost, int64_t available_count);
Atom _market_building_summary(State &state, DictRef building);

// town_rules_services.cpp.
void begin_read_scope(State &state, DictRef session);
void end_read_scope(State &state, DictRef session);
bool can_visit_active_town(State &state, DictRef session);
ArrayRef get_response_actions(State &state, DictRef session);
ArrayRef get_spell_learning_actions(State &state, DictRef session);
ArrayRef get_specialty_actions(State &state, DictRef session);
DictRef perform_response_action(State &state, DictRef session, Atom action_id);
DictRef learn_spell_at_active_town(State &state, DictRef session, Atom spell_id);
bool active_hero_can_study(State &state, DictRef session, DictRef town);
DictRef choose_specialty_at_active_town(State &state, DictRef session, Atom specialty_id);

} // namespace aurelion::rules::port::town_rules

namespace aurelion::rules::port::town_building_panel {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// town_building_panel.cpp.
DictRef build(State &state, const Value &session, Atom building_id, DictRef options);
Atom building_kind(State &state, DictRef building);
ArrayRef effect_lines(State &state, DictRef building, DictRef town, const Value &session);
DictRef _upgrade(State &state, DictRef slot);
DictRef _recruitment(State &state, const Value &session, DictRef town, DictRef slot, DictRef building);
DictRef recruit_card(State &state, DictRef row);
DictRef unit_card(State &state, Atom unit_id);
DictRef _guild(State &state, const Value &session, DictRef town, DictRef slot);
DictRef spell_entry(State &state, Atom spell_id, DictRef visitor);
DictRef _tavern(State &state, const Value &session, DictRef resources);
DictRef hero_card(State &state, Atom hero_id);
void _apply_tavern_offer(State &state, DictRef card, DictRef recruit);
ArrayRef _building_services(State &state, const Value &session, Atom building_id, Atom kind);
DictRef _action_entry(State &state, DictRef action);
Atom _subtitle(State &state, Atom kind, DictRef building, DictRef slot, Atom faction_id);
Atom _built_dwelling_unit_name(State &state, DictRef town, int64_t tier);
Atom _resource_text(State &state, const Value &resources);
Atom _reward_text(State &state, DictRef reward);

} // namespace aurelion::rules::port::town_building_panel

namespace aurelion::rules::port::town_construction_board {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// town_construction_board.cpp.
DictRef layout(State &state);
DictRef build_for_active_town(State &state, const Value &session);
DictRef build(State &state, DictRef town, int64_t day, DictRef resources, DictRef catalog_by_building);
ArrayRef town_building_ids(State &state, DictRef town_template);
DictRef slot_for_building(State &state, DictRef board, Atom building_id);
Atom format_amount(State &state, int64_t value);
Atom resource_name(State &state, Atom resource_id);
Atom roman(State &state, int64_t tier);
DictRef _build_slot(State &state, DictRef spec, Atom row_id, ArrayRef town_ids, DictRef context);
ArrayRef _line_chain(State &state, Atom line_id, ArrayRef town_ids);
ArrayRef _dwelling_branches(State &state, int64_t tier, ArrayRef town_ids);
DictRef _dwelling_slot(State &state, DictRef slot, int64_t tier, ArrayRef town_ids, DictRef context);
DictRef _finish_chain_slot(State &state, DictRef slot, ArrayRef chain, DictRef context);
bool _stage_done(State &state, Atom building_id, DictRef context);
void _apply_status(State &state, DictRef slot, Atom building_id, DictRef context, Atom verb);
ArrayRef _missing_requirement_names(State &state, DictRef building, DictRef context);
DictRef _shortfall(State &state, DictRef cost, DictRef resources);
Atom _first_sentence(State &state, Atom text);

} // namespace aurelion::rules::port::town_construction_board

namespace aurelion::rules::port::town_development_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// town_development_rules_services.cpp.
bool visiting_active_hero(State &state, const Value &session, DictRef town);
ArrayRef objective_artifact_ids(State &state, const Value &session);
ArrayRef service_actions(State &state, const Value &session, DictRef town);
Atom cost_text(State &state, DictRef cost);
DictRef perform_service(State &state, const Value &session, DictRef town, Atom action_id);

} // namespace aurelion::rules::port::town_development_rules

namespace aurelion::rules::port::hero_command_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// hero_command_rules_tavern.cpp.
int64_t player_hero_count(State &state, DictRef session);
// Heroes some player leads or will lead again: no tavern offers them.
DictRef heroes_in_play(State &state, DictRef session);
// The week's draw of the tavern `site_id`: the first free heroes of the whole
// roster drawn by weight, `faction_id`'s heroes weighing more and every other
// faction's `other_weight` (0 draws only that faction).
ArrayRef tavern_draw(State &state, DictRef session, Atom site_id, Atom faction_id, int64_t other_weight);
// The week's offer of the tavern at `site_id` (a town or a Wayfarer Lodge),
// `faction_id`'s heroes most likely; what a hire there left this week.
ArrayRef site_tavern_offer_ids(State &state, DictRef session, Atom site_id, Atom faction_id);
// A town's offer: its own pool, the town's faction most likely.
ArrayRef tavern_offer_ids(State &state, DictRef session, DictRef town);
// A hire at `site_id`: the hired hero's place stays empty until the next week.
void take_tavern_offer(State &state, DictRef session, Atom site_id, ArrayRef offer, Atom hero_id);
int64_t days_until_tavern_rotation(State &state, DictRef session);
DictRef tavern_offer_preview(State &state, DictRef session, Atom hero_id);
// Every free hero a tavern could offer, of every faction.
ArrayRef recruitable_hero_ids(State &state, DictRef session);
ArrayRef _tavern_roster(State &state, DictRef session);
ArrayRef _tavern_candidate_ids(State &state, DictRef session);
bool _hero_recruitable_for_scenario(State &state, Atom hero_id, DictRef scenario);
int64_t hero_count_from_overworld(State &state, const Value &overworld_state);

} // namespace aurelion::rules::port::hero_command_rules

namespace aurelion::rules::port::spell_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// spell_rules_town.cpp.
Atom spell_school_icon_path(State &state, Atom spell_id);
Atom spell_icon_path(State &state, Atom spell_id);
Atom describe_spell_inspection_line(State &state, DictRef hero_state, DictRef spell, DictRef context_state);
Atom _mana_readiness_label(State &state, DictRef hero_state, int64_t mana_cost);
Atom _spell_effect_summary(State &state, DictRef spell, DictRef hero_state);

} // namespace aurelion::rules::port::spell_rules
