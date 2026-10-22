#pragma once

// scripts/core/ScenarioRules.gd: the functions the computer players' day runs
// (docs/native-rules-engine-transition.md, Phase 4), ported function by
// function under the GDScript names. A session is its view (session_view.hpp).

#include "aurelion_rules/port/gd.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"

#include <cstdint>

namespace aurelion::rules::port::scenario_rules {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using gd::PackedRef;
using overworld_rules::Vector2i;
using state::State;
using state::Value;

// Ported in scenario_turn_rare.cpp (slice 4.2: paths the six seeds do not run).
int64_t _army_unit_count(State &state, DictRef army, Atom unit_id);
DictRef _artifact_set_equipment_progress(State &state, DictRef session, DictRef objective);
DictRef _controlled_hero_army(State &state, DictRef session, Atom hero_id);
DictRef _controlled_hero_state(State &state, DictRef session, Atom hero_id);
DictRef _find_town(State &state, DictRef session, DictRef objective);
DictRef _hero_army_requirement_progress(State &state, DictRef session, DictRef objective);
DictRef _hero_progression_requirement_progress(State &state, DictRef session, DictRef objective);
DictRef _hero_stationing_progress(State &state, DictRef session, DictRef objective);
DictRef _map_exploration_progress(State &state, DictRef session, DictRef objective);
Value _overworld_rules(State &state);
bool _player_knows_spell(State &state, DictRef session, Atom spell_id);
bool _player_owns_artifact(State &state, DictRef session, Atom artifact_id);
DictRef _reserve_delivery_progress(State &state, DictRef session, DictRef objective);
DictRef _resource_site_control_progress(State &state, DictRef session, DictRef objective);
DictRef _resource_stockpile_progress(State &state, DictRef session, DictRef objective);
Atom _titleize_token(State &state, Atom value);
DictRef _town_garrison_requirement_progress(State &state, DictRef session, DictRef objective);
bool _town_has_objective_building(State &state, DictRef town, Atom building_id);

} // namespace aurelion::rules::port::scenario_rules
