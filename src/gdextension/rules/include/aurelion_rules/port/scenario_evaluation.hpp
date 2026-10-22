#pragma once

// Phase 5 slice 05's entries (docs/native-rules-engine-transition.md, Phase 5):
// ScenarioRules.evaluate_session, the scenario's state and objectives checked
// once a day and after actions, and PlayerEliminationRules.apply_daily, the
// townless days counted after every player has moved.

#include "aurelion_rules/port/gd.hpp"

namespace aurelion::rules::port {

namespace scenario_rules {
// The session is its view (session_view.hpp).
gd::DictRef evaluate_session(state::State &state, gd::DictRef session);
// The scenario's state normalized, its record and objectives
// (scenario_evaluation.cpp; objectives_for_session in overworld_forecast.cpp).
void normalize_scenario_state(state::State &state, gd::DictRef session, bool normalize_enemies);
gd::DictRef scenario_record_for_session(state::State &state, gd::DictRef session);
state::Value objective_definitions(state::State &state, gd::DictRef scenario);
state::Value objectives_for_session(state::State &state, gd::DictRef session);

} // namespace scenario_rules

namespace player_elimination_rules {
gd::ArrayRef apply_daily(state::State &state, gd::DictRef session);
} // namespace player_elimination_rules

} // namespace aurelion::rules::port
