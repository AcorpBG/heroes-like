// The functions of the computer players' day that Phase 5's slice 09 ports
// (docs/native-rules-engine-transition.md, Phase 4, 4.2): until it is merged each
// throws state::NotPorted, so the day runs in GDScript where no full host call came first.

#include "aurelion_rules/port/enemy_adventure_rules_turn.hpp"
#include "aurelion_rules/port/hero_command_rules_turn.hpp"
#include "aurelion_rules/port/overworld_rules_turn.hpp"
#include "aurelion_rules/port/player_identity_rules_turn.hpp"
#include "aurelion_rules/port/town_rules_turn.hpp"

namespace aurelion::rules::port {

namespace enemy_adventure_rules {

DictRef _active_resource_defender_entry(State &state, DictRef session, DictRef node, Atom faction_filter) {
	(void)session; (void)node; (void)faction_filter; (void)state;
	throw state::NotPorted("EnemyAdventureRules._active_resource_defender_entry");
}

DictRef _active_town_defender_entry(State &state, DictRef session, DictRef town, Atom faction_filter) {
	(void)session; (void)town; (void)faction_filter; (void)state;
	throw state::NotPorted("EnemyAdventureRules._active_town_defender_entry");
}

int64_t _ai_hero_task_retention_priority(State &state, DictRef task) {
	(void)task; (void)state;
	throw state::NotPorted("EnemyAdventureRules._ai_hero_task_retention_priority");
}

void _clear_resource_defender_metadata(State &state, DictRef node) {
	(void)node; (void)state;
	throw state::NotPorted("EnemyAdventureRules._clear_resource_defender_metadata");
}

void _clear_town_defender_metadata(State &state, DictRef town) {
	(void)town; (void)state;
	throw state::NotPorted("EnemyAdventureRules._clear_town_defender_metadata");
}

bool is_active_pressure_host(State &state, const Value &encounter, Atom faction_id, const Value &resolved_encounters) {
	(void)encounter; (void)faction_id; (void)resolved_encounters; (void)state;
	throw state::NotPorted("EnemyAdventureRules.is_active_pressure_host");
}

} // namespace enemy_adventure_rules

namespace hero_command_rules {

void _set_holder_stacks(State &state, DictRef session, DictRef town, Atom holder_id, ArrayRef stacks) {
	(void)session; (void)town; (void)holder_id; (void)stacks; (void)state;
	throw state::NotPorted("HeroCommandRules._set_holder_stacks");
}

} // namespace hero_command_rules

namespace overworld_rules {

DictRef _enemy_state_for_faction(State &state, DictRef session, Atom faction_id) {
	(void)session; (void)faction_id; (void)state;
	throw state::NotPorted("OverworldRules._enemy_state_for_faction");
}

int64_t _readiness_bonus_from_profile(State &state, const Value &profile) {
	(void)profile; (void)state;
	throw state::NotPorted("OverworldRules._readiness_bonus_from_profile");
}

DictRef _retake_front_from_legacy_state(State &state, DictRef session, DictRef town, DictRef front) {
	(void)session; (void)town; (void)front; (void)state;
	throw state::NotPorted("OverworldRules._retake_front_from_legacy_state");
}

bool _scenario_town_started_enemy(State &state, DictRef session, Atom placement_id) {
	(void)session; (void)placement_id; (void)state;
	throw state::NotPorted("OverworldRules._scenario_town_started_enemy");
}

int64_t _town_battle_readiness(State &state, DictRef town, const Value &session, DictRef metric_context, int64_t reinforcement_quality) {
	(void)town; (void)session; (void)metric_context; (void)reinforcement_quality; (void)state;
	throw state::NotPorted("OverworldRules._town_battle_readiness");
}

int64_t _town_front_priority_seed(State &state, Atom role, bool objective_anchor) {
	(void)role; (void)objective_anchor; (void)state;
	throw state::NotPorted("OverworldRules._town_front_priority_seed");
}

DictRef _town_front_state(State &state, DictRef session, DictRef town, DictRef precomputed_development_metrics) {
	(void)session; (void)town; (void)precomputed_development_metrics; (void)state;
	throw state::NotPorted("OverworldRules._town_front_state");
}

int64_t _town_garrison_headcount(State &state, DictRef town) {
	(void)town; (void)state;
	throw state::NotPorted("OverworldRules._town_garrison_headcount");
}

int64_t _town_garrison_strength(State &state, DictRef town) {
	(void)town; (void)state;
	throw state::NotPorted("OverworldRules._town_garrison_strength");
}

int64_t _town_reinforcement_quality(State &state, DictRef town, const Value &session, DictRef metric_context) {
	(void)town; (void)session; (void)metric_context; (void)state;
	throw state::NotPorted("OverworldRules._town_reinforcement_quality");
}

int64_t _town_role_quality_bonus(State &state, Atom role) {
	(void)role; (void)state;
	throw state::NotPorted("OverworldRules._town_role_quality_bonus");
}

int64_t _town_role_readiness_bonus(State &state, Atom role) {
	(void)role; (void)state;
	throw state::NotPorted("OverworldRules._town_role_readiness_bonus");
}

int64_t _town_spell_tier(State &state, DictRef town) {
	(void)town; (void)state;
	throw state::NotPorted("OverworldRules._town_spell_tier");
}

} // namespace overworld_rules

namespace player_identity_rules {

Atom defender_controller_id(State &state, DictRef record) {
	(void)record; (void)state;
	throw state::NotPorted("PlayerIdentityRules.defender_controller_id");
}

ArrayRef from_slots(State &state, ArrayRef slots) {
	(void)slots; (void)state;
	throw state::NotPorted("PlayerIdentityRules.from_slots");
}

} // namespace player_identity_rules

namespace town_rules {

DictRef teach_visiting_heroes(State &state, DictRef session, DictRef town) {
	(void)session; (void)town; (void)state;
	throw state::NotPorted("TownRules.teach_visiting_heroes");
}

} // namespace town_rules

} // namespace aurelion::rules::port
