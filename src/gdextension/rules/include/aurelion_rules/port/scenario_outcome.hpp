#pragma once

// The scenario's outcome screen (docs/native-rules-engine-transition.md, Phase 7,
// slice 7.7), ported function by function under the GDScript names: the outcome
// model, its actions and their texts, and the session's progress recap. A session
// is its view (session_view.hpp).

#include "aurelion_rules/port/gd.hpp"
#include "aurelion_rules/port/town_rules_actions.hpp"

#include <cstdint>

namespace aurelion::rules::port::overworld_rules {

using gd::Atom;
using gd::DictRef;
using state::State;
using state::Value;

// scenario_outcome_texts.cpp: the hero, army and resource texts the outcome
// screen shows.
Atom describe_resources(State &state, DictRef session);
Atom describe_resource_stockpile(State &state, const Value &resources, bool include_zero_rare = false);
Atom describe_hero(State &state, DictRef session);
Atom describe_army(State &state, DictRef session);
Atom describe_stack_inspection_line(State &state, DictRef stack, DictRef options);
int64_t _stack_display_count(State &state, DictRef stack, DictRef unit);
int64_t _stack_display_health(State &state, DictRef stack, DictRef unit, int64_t count);
int64_t _stack_display_max_health(State &state, DictRef stack, DictRef unit, int64_t count);
Atom _stack_readiness_label(State &state, DictRef stack, int64_t health, int64_t max_health);
Atom _resource_display_name(State &state, Atom resource_key);

} // namespace aurelion::rules::port::overworld_rules

namespace aurelion::rules::port::scenario_script_rules {

using gd::Atom;
using gd::DictRef;
using state::State;

// scenario_evaluation.cpp.
void normalize_script_state(State &state, DictRef session);
// scenario_outcome_texts.cpp.
Atom describe_recent_events(State &state, DictRef session, int64_t limit = 2);

} // namespace aurelion::rules::port::scenario_script_rules

namespace aurelion::rules::port::scenario_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// scenario_outcome.cpp.
Atom describe_session_progress_recap(State &state, DictRef session, bool include_header = true);
Atom describe_session_progress_recap_from_normalized_session(State &state, DictRef session, bool include_header, DictRef preloaded_objective_surface);
DictRef build_outcome_model(State &state, DictRef session);
DictRef perform_outcome_action(State &state, DictRef session, Atom action_id);
ArrayRef _build_skirmish_outcome_actions(State &state, DictRef session);
ArrayRef _decorate_outcome_actions(State &state, DictRef session, DictRef scenario, ArrayRef actions);
Atom _outcome_action_cue_text(State &state, DictRef session, DictRef scenario, DictRef action);
Atom _outcome_action_cue_line(State &state, DictRef session, DictRef scenario, ArrayRef actions);
Atom _outcome_post_result_handoff_line(State &state, DictRef session, DictRef scenario, ArrayRef actions);
Atom _first_enabled_outcome_action_label(State &state, ArrayRef actions, Atom excluded_id = state::key::empty);
Atom _skirmish_outcome_continuity_choice_line(State &state, DictRef session);
Atom _build_skirmish_aftermath_summary(State &state, DictRef session, DictRef scenario);
Atom _progress_recap_context_line(State &state, DictRef session, DictRef scenario);
Atom _progress_recap_status_line(State &state, DictRef session, DictRef preloaded_objective_surface);
Atom _progress_recap_recent_line(State &state, DictRef session, DictRef scenario, DictRef preloaded_objective_surface);
Atom _progress_recap_next_step_line(State &state, DictRef session, DictRef scenario, DictRef preloaded_objective_surface);
bool _objective_progress_surface_is_complete(State &state, DictRef surface);
DictRef _objective_progress_counts_from_surface(State &state, DictRef surface);
DictRef _objective_progress_counts(State &state, DictRef session);
Atom _next_unmet_victory_objective_label(State &state, DictRef session);
ArrayRef _completed_objective_labels(State &state, DictRef session, int64_t limit);
Atom _last_battle_aftermath_compact_text(State &state, DictRef session);
Atom _resolved_next_step_text(State &state, DictRef session, DictRef scenario);
Atom _outcome_next_play_action_line(State &state, DictRef session, DictRef scenario);
Atom _campaign_id_for_scenario(State &state, Atom scenario_id);
Atom _campaign_chapter_label(State &state, DictRef campaign, Atom scenario_id, Atom fallback);
Atom _next_campaign_chapter_label(State &state, DictRef session, DictRef scenario);
Atom _last_battle_aftermath_text(State &state, DictRef session);

} // namespace aurelion::rules::port::scenario_rules
