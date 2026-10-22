#pragma once

// A battle's payload (docs/native-rules-engine-transition.md, Phase 2, slice
// 2a): BattleRules.create_battle_payload and what it reaches that no port had,
// ported function by function under the GDScript names. BattleRules takes the
// session as the battle does (const Value &session: the SessionData object or
// a session view); the overworld rules take its view (gd::object_view).
// Arguments GDScript defaults are passed by the callers.

#include "aurelion_rules/port/gd.hpp"

#include <cstdint>

namespace aurelion::rules::port {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using state::State;
using state::Value;

namespace battle_rules {

// The encounter payload: its setup, stacks, boosts, obstacles and seed
// (battle_payload.cpp).
DictRef create_battle_payload(State &state, const Value &session, DictRef encounter_placement);
void _apply_hero_battle_boosts(State &state, const Value &session, ArrayRef stacks, const Value &commander_state);
void _apply_specialty_battle_starts(State &state, DictRef battle);
DictRef _resolved_encounter_placement(State &state, const Value &session, DictRef encounter_placement);
bool _enemy_withdrawal_allowed(State &state, const Value &session, DictRef battle_context, DictRef encounter_placement);
Atom _battle_name(State &state, const Value &session, DictRef encounter, DictRef battle_context, DictRef encounter_placement);
DictRef _enemy_stack_source(State &state, DictRef encounter_placement, DictRef battle_context);
DictRef _enemy_army_for_battle(State &state, const Value &session, DictRef encounter_placement, DictRef encounter, DictRef battle_context);
Atom _army_affiliation(State &state, DictRef army);
DictRef _player_setup_for_battle(State &state, const Value &session, DictRef encounter_placement, DictRef battle_context);
ArrayRef _army_stack_descriptors(State &state, const Value &army, DictRef source);
Atom _battle_difficulty_value(State &state, DictRef encounter_placement, DictRef encounter);
Atom _battle_enemy_army_name(State &state, DictRef enemy_army, DictRef battle_context, const Value &session);
void _generate_battle_obstacles(State &state, DictRef battle);
bool _obstacle_cells_clear(State &state, ArrayRef cells, DictRef blocked);
bool _obstacle_field_stays_open(State &state, DictRef blocked);
ArrayRef _with_army_battlefield_tags(State &state, ArrayRef tags, ArrayRef stacks);
ArrayRef _normalized_battlefield_tags(State &state, DictRef encounter, const Value &context);
int64_t _new_battle_combat_seed(State &state, const Value &session, DictRef encounter_placement, Atom encounter_id);

// The battle context of an encounter (battle_context.cpp).
DictRef _normalized_battle_context(State &state, const Value &session, const Value &raw_context);
DictRef _normalized_battle_context_fields(State &state, const Value &session, const Value &raw_context);
Atom _battle_context_target_hero_id(State &state, const Value &session, DictRef context, const Value &raw_context);
ArrayRef _normalize_string_array(State &state, const Value &value);

// The enemy commander and a town's watch captain (battle_commanders.cpp).
DictRef _enemy_commander_state_for_battle(State &state, const Value &session, DictRef encounter_placement, DictRef encounter, DictRef battle_context);
DictRef _encounter_enemy_commander_seed(State &state, DictRef encounter_placement);
Atom _encounter_enemy_commander_name(State &state, DictRef encounter_placement, DictRef encounter);
DictRef _enemy_commander_state(State &state, DictRef encounter);
DictRef _normalize_enemy_hero_state(State &state, const Value &existing_state, DictRef encounter, DictRef encounter_placement);
ArrayRef _normalized_specialty_ranks(State &state, const Value &primary, const Value &secondary);
ArrayRef _normalized_specialty_focus_ids(State &state, const Value &value);
DictRef _normalize_command(State &state, const Value &value);
DictRef _town_captain_state(State &state, DictRef town);
DictRef _normalize_town_captain(State &state, DictRef hero_state);
DictRef _town_building_category_counts(State &state, DictRef town);
ArrayRef _normalized_town_buildings(State &state, DictRef town);
void _append_building_with_requirements(State &state, ArrayRef target, Atom building_id, ArrayRef trail);

// A battle stack from its unit, and the field objectives (battle_stacks.cpp).
DictRef _build_battle_stack(State &state, Atom unit_id, int64_t count, Atom side, int64_t index, DictRef source, int64_t army_slot_index);
int64_t _cohesion_base_for_unit(State &state, DictRef unit);
ArrayRef _normalize_unit_abilities(State &state, const Value &value);
Atom _normalize_side_token(Atom side, bool allow_neutral);
ArrayRef _normalize_field_objectives(State &state, const Value &existing_value, DictRef encounter, DictRef encounter_placement, DictRef scenario, const Value &context);
ArrayRef _authored_field_objectives(State &state, DictRef encounter, DictRef encounter_placement, DictRef scenario, const Value &context);
DictRef _normalize_field_objective(State &state, DictRef entry, const Value &existing_state, const Value &context);
Atom _default_field_objective_summary(State &state, Atom objective_type);
ArrayRef _default_field_objective_pressure_tags(State &state, Atom objective_type);

} // namespace battle_rules

namespace town_battle_rules {
// A town battle's buildings on the field (battle_stacks.cpp).
void prepare(State &state, DictRef battle, ArrayRef building_ids, Atom side);
} // namespace town_battle_rules

namespace town_development_rules {
// A town's defence bonus for its defenders (battle_payload.cpp).
void apply_defender_bonus(State &state, ArrayRef stacks, DictRef town, Atom context_type);
} // namespace town_development_rules

namespace overworld_rules {
// A town's battlefront and a delivery's interception (battle_context.cpp).
DictRef town_battlefront_profile(State &state, DictRef town);
DictRef _town_battlefront_profile(State &state, DictRef town);
DictRef delivery_interception_context_for_encounter(State &state, DictRef session, DictRef encounter);
// Phase 4's ports (overworld_rules_turn_rare.cpp, declared in overworld_rules_turn.hpp too).
bool _delivery_encounter_matches_node(State &state, DictRef session, DictRef encounter, DictRef node, DictRef delivery_state);
DictRef _resource_site_delivery_interception(State &state, DictRef session, DictRef node, DictRef site);
Atom encounter_display_name(State &state, DictRef encounter);
} // namespace overworld_rules

namespace enemy_adventure_rules {
// A raid's name and strength: Phase 4's ports (enemy_adventure_rules_turn_rare.cpp,
// declared in enemy_adventure_rules_turn.hpp too).
Atom raid_display_name(State &state, DictRef encounter);
int64_t raid_strength(State &state, DictRef encounter);
} // namespace enemy_adventure_rules

} // namespace aurelion::rules::port
