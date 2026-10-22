#include "aurelion_rules/port/registry.hpp"

// BEGIN INCLUDES
#include "aurelion_rules/port/ai_hero_rules_turn.hpp"
#include "aurelion_rules/port/enemy_adventure_rules_turn.hpp"
#include "aurelion_rules/port/enemy_town_services_turn.hpp"
#include "aurelion_rules/port/enemy_turn_rules_turn.hpp"
// END INCLUDES

namespace aurelion::rules::port {

namespace {

using state::State;
using state::Value;

// The parameters as GDScript's types left them. A session is its view, a
// Dictionary (TurnEngine.gd).
gd::DictRef D(const Value *args, int index) {
	return gd::as_dict(args[index]);
}
gd::ArrayRef A(const Value *args, int index) {
	return gd::as_array(args[index]);
}
gd::Atom S(const Value *args, int index) {
	return gd::to_string(args[index]);
}
int64_t I(const Value *args, int index) {
	return args[index].i;
}
double F(const Value *args, int index) {
	return args[index].f;
}
bool B(const Value *args, int index) {
	return args[index].b;
}
gd::PackedRef P(const Value *args, int index) {
	return args[index].ref;
}
overworld_rules::Vector2i V(const Value *args, int index) {
	return {args[index].vx(), args[index].vy()};
}
const Value &X(const Value *args, int index) {
	return args[index];
}

Value nil() {
	return Value();
}

#define PORT(script, fn, arity, mutates, body) \
	{ #script "." #fn, arity, mutates, [](State &s, const Value *a) -> Value { (void)s; (void)a; body; } }
// A function of the AI turn's scripts that GDScript outside the turn still
// calls (the UI, day processing, battles, tests): its GDScript is a thin
// wrapper over this port (TurnEngine.native_writing). The other functions the
// turn reaches have no GDScript of their own, or keep a GDScript copy for
// their callers outside the turn (slice 4.4).
#define CHECK PORT

// run_enemy_turn runs native, every faction turn in it. A static var a port
// sets counts as a write.
const Function kFunctions[] = {
	// BEGIN CHECKS
	// AiHeroRules
	CHECK(AiHeroRules, _new_context, 3, true, return gd::dict_value(ai_hero_rules::_new_context(s, D(a, 0), D(a, 1), D(a, 2)))),
	CHECK(AiHeroRules, _start_heroes_day, 2, true, ai_hero_rules::_start_heroes_day(s, D(a, 0), S(a, 1)); return nil()),
	CHECK(AiHeroRules, _use_weights, 1, true, ai_hero_rules::_use_weights(s, D(a, 0)); return nil()),
	CHECK(AiHeroRules, clear_shared_surfaces, 0, true, ai_hero_rules::clear_shared_surfaces(s); return nil()),
	CHECK(AiHeroRules, faction_daily_income, 2, true, return gd::dict_value(ai_hero_rules::faction_daily_income(s, D(a, 0), S(a, 1)))),
	CHECK(AiHeroRules, run_faction_turn, 5, true, return gd::dict_value(ai_hero_rules::run_faction_turn(s, D(a, 0), D(a, 1), D(a, 2), B(a, 3), B(a, 4)))),
	CHECK(AiHeroRules, _choose_plan, 3, true, return gd::dict_value(ai_hero_rules::_choose_plan(s, D(a, 0), D(a, 1), D(a, 2)))),
	CHECK(AiHeroRules, _follow_plan, 4, true, return gd::dict_value(ai_hero_rules::_follow_plan(s, D(a, 0), D(a, 1), I(a, 2), D(a, 3)))),
	CHECK(AiHeroRules, _find_town, 2, true, return gd::dict_value(ai_hero_rules::_find_town(s, D(a, 0), S(a, 1)))),
	CHECK(AiHeroRules, _gate_fight_looks_good, 4, true, return gd::bool_value(ai_hero_rules::_gate_fight_looks_good(s, D(a, 0), D(a, 1), D(a, 2), D(a, 3)))),
	CHECK(AiHeroRules, _mark_resolved, 2, true, ai_hero_rules::_mark_resolved(s, D(a, 0), S(a, 1)); return nil()),
	CHECK(AiHeroRules, _record_hero_defeat, 3, true, ai_hero_rules::_record_hero_defeat(s, D(a, 0), S(a, 1), D(a, 2)); return nil()),
	CHECK(AiHeroRules, _take_artifact, 4, true, return gd::dict_value(ai_hero_rules::_take_artifact(s, D(a, 0), D(a, 1), I(a, 2), D(a, 3)))),
	CHECK(AiHeroRules, hero_name, 1, true, return gd::str(ai_hero_rules::hero_name(s, D(a, 0)))),
	CHECK(AiHeroRules, _cuts_a_way, 3, true, return gd::bool_value(ai_hero_rules::_cuts_a_way(s, D(a, 0), I(a, 1), V(a, 2)))),
	CHECK(AiHeroRules, _hostile_hero_beside, 4, true, return gd::dict_value(ai_hero_rules::_hostile_hero_beside(s, D(a, 0), D(a, 1), V(a, 2), I(a, 3)))),
	CHECK(AiHeroRules, _reveal, 4, true, ai_hero_rules::_reveal(s, D(a, 0), D(a, 1), D(a, 2), I(a, 3)); return nil()),
	CHECK(AiHeroRules, _wait_by_home, 5, true, return gd::dict_value(ai_hero_rules::_wait_by_home(s, D(a, 0), D(a, 1), D(a, 2), D(a, 3), D(a, 4)))),
	CHECK(AiHeroRules, _desired_hero_count, 2, true, return gd::int_value(ai_hero_rules::_desired_hero_count(s, D(a, 0), S(a, 1)))),
	CHECK(AiHeroRules, _ensure_starting_hero, 2, true, return gd::dict_value(ai_hero_rules::_ensure_starting_hero(s, D(a, 0), D(a, 1)))),
	CHECK(AiHeroRules, _govern_towns, 2, true, return gd::dict_value(ai_hero_rules::_govern_towns(s, D(a, 0), D(a, 1)))),
	CHECK(AiHeroRules, _roster_progression_seed, 2, true, return gd::dict_value(ai_hero_rules::_roster_progression_seed(s, D(a, 0), S(a, 1)))),
	CHECK(AiHeroRules, _tavern_pool, 3, true, return gd::array_value(ai_hero_rules::_tavern_pool(s, D(a, 0), D(a, 1), S(a, 2)))),
	CHECK(AiHeroRules, ai_tavern_offer_ids, 3, true, return gd::array_value(ai_hero_rules::ai_tavern_offer_ids(s, D(a, 0), D(a, 1), S(a, 2)))),
	CHECK(AiHeroRules, _convert_legacy_host, 3, true, return gd::dict_value(ai_hero_rules::_convert_legacy_host(s, D(a, 0), D(a, 1), S(a, 2)))),
	CHECK(AiHeroRules, _nearest_hero_index, 5, true, return gd::int_value(ai_hero_rules::_nearest_hero_index(s, A(a, 0), D(a, 1), S(a, 2), D(a, 3), I(a, 4)))),
	CHECK(AiHeroRules, _return_troops_to_nearest_town, 3, true, ai_hero_rules::_return_troops_to_nearest_town(s, D(a, 0), D(a, 1), S(a, 2)); return nil()),
	// EnemyAdventureRules
	CHECK(EnemyAdventureRules, _ai_hero_task_finish_live_assignment, 5, true, enemy_adventure_rules::_ai_hero_task_finish_live_assignment(s, D(a, 0), S(a, 1), D(a, 2), S(a, 3), S(a, 4)); return nil()),
	CHECK(EnemyAdventureRules, _apply_resource_site_artifact_reward_to_raid, 5, true, return gd::dict_value(enemy_adventure_rules::_apply_resource_site_artifact_reward_to_raid(s, D(a, 0), S(a, 1), D(a, 2), D(a, 3), D(a, 4)))),
	CHECK(EnemyAdventureRules, _apply_resource_site_claim_recruits_to_raid, 4, true, return gd::dict_value(enemy_adventure_rules::_apply_resource_site_claim_recruits_to_raid(s, D(a, 0), S(a, 1), D(a, 2), D(a, 3)))),
	CHECK(EnemyAdventureRules, _apply_resource_site_spell_reward_to_commander, 4, true, return gd::dict_value(enemy_adventure_rules::_apply_resource_site_spell_reward_to_commander(s, D(a, 0), S(a, 1), D(a, 2), D(a, 3)))),
	CHECK(EnemyAdventureRules, _break_dwelling_guard_by_raid, 5, true, return gd::bool_value(enemy_adventure_rules::_break_dwelling_guard_by_raid(s, D(a, 0), D(a, 1), S(a, 2), I(a, 3), D(a, 4)))),
	CHECK(EnemyAdventureRules, _hire_dwelling_creatures_into_raid, 6, true, return gd::dict_value(enemy_adventure_rules::_hire_dwelling_creatures_into_raid(s, D(a, 0), S(a, 1), D(a, 2), I(a, 3), D(a, 4), D(a, 5)))),
	CHECK(EnemyAdventureRules, _secure_resource_target, 5, true, return gd::dict_value(enemy_adventure_rules::_secure_resource_target(s, D(a, 0), D(a, 1), D(a, 2), S(a, 3), D(a, 4)))),
	CHECK(EnemyAdventureRules, _target_level, 5, true, return gd::int_value(enemy_adventure_rules::_target_level(s, D(a, 0), S(a, 1), S(a, 2), S(a, 3), I(a, 4)))),
	CHECK(EnemyAdventureRules, advance_commander_record, 2, true, return gd::dict_value(enemy_adventure_rules::advance_commander_record(s, D(a, 0), S(a, 1)))),
	CHECK(EnemyAdventureRules, commander_display_name, 2, true, return gd::str(enemy_adventure_rules::commander_display_name(s, X(a, 0), B(a, 1)))),
	CHECK(EnemyAdventureRules, commander_live_role_state, 1, true, return gd::dict_value(enemy_adventure_rules::commander_live_role_state(s, X(a, 0)))),
	CHECK(EnemyAdventureRules, commander_target_memory, 1, true, return gd::dict_value(enemy_adventure_rules::commander_target_memory(s, X(a, 0)))),
	CHECK(EnemyAdventureRules, raid_commander_display_name, 1, true, return gd::str(enemy_adventure_rules::raid_commander_display_name(s, D(a, 0)))),
	CHECK(EnemyAdventureRules, sync_commander_state_to_roster, 7, true, enemy_adventure_rules::sync_commander_state_to_roster(s, D(a, 0), S(a, 1), X(a, 2), S(a, 3), S(a, 4), I(a, 5), S(a, 6)); return nil()),
	CHECK(EnemyAdventureRules, _enemy_hero_sighting_sources, 3, true, return gd::array_value(enemy_adventure_rules::_enemy_hero_sighting_sources(s, D(a, 0), D(a, 1), S(a, 2)))),
	CHECK(EnemyAdventureRules, _find_encounter_by_placement, 2, true, return gd::dict_value(enemy_adventure_rules::_find_encounter_by_placement(s, D(a, 0), S(a, 1)))),
	CHECK(EnemyAdventureRules, _find_player_hero, 2, true, return gd::dict_value(enemy_adventure_rules::_find_player_hero(s, D(a, 0), S(a, 1)))),
	CHECK(EnemyAdventureRules, _find_town_by_placement, 2, true, return gd::dict_value(enemy_adventure_rules::_find_town_by_placement(s, D(a, 0), S(a, 1)))),
	CHECK(EnemyAdventureRules, _player_hero_snapshots_for_intercept, 2, true, return gd::array_value(enemy_adventure_rules::_player_hero_snapshots_for_intercept(s, D(a, 0), B(a, 1)))),
	CHECK(EnemyAdventureRules, _preferred_commander_index_for_encounter, 1, true, return gd::int_value(enemy_adventure_rules::_preferred_commander_index_for_encounter(s, D(a, 0)))),
	CHECK(EnemyAdventureRules, _town_controller_faction_id, 1, true, return gd::str(enemy_adventure_rules::_town_controller_faction_id(s, D(a, 0)))),
	CHECK(EnemyAdventureRules, commander_can_deploy, 1, true, return gd::bool_value(enemy_adventure_rules::commander_can_deploy(s, X(a, 0)))),
	CHECK(EnemyAdventureRules, commander_recent_outcome_brief, 1, true, return gd::str(enemy_adventure_rules::commander_recent_outcome_brief(s, X(a, 0)))),
	CHECK(EnemyAdventureRules, raid_display_name, 1, true, return gd::str(enemy_adventure_rules::raid_display_name(s, D(a, 0)))),
	CHECK(EnemyAdventureRules, raid_strength, 1, true, return gd::int_value(enemy_adventure_rules::raid_strength(s, D(a, 0)))),
	CHECK(EnemyAdventureRules, select_raid_commander_roster_hero_id, 5, true, return gd::str(enemy_adventure_rules::select_raid_commander_roster_hero_id(s, D(a, 0), S(a, 1), I(a, 2), D(a, 3), X(a, 4)))),
	CHECK(EnemyAdventureRules, target_is_objective_anchor, 3, true, return gd::bool_value(enemy_adventure_rules::target_is_objective_anchor(s, D(a, 0), S(a, 1), S(a, 2)))),
	CHECK(EnemyAdventureRules, _town_is_objective_anchor, 2, true, return gd::bool_value(enemy_adventure_rules::_town_is_objective_anchor(s, D(a, 0), S(a, 1)))),
	// EnemyTownServices
	CHECK(EnemyTownServices, visit, 5, true, return gd::dict_value(enemy_town_services::visit(s, D(a, 0), D(a, 1), D(a, 2), I(a, 3), S(a, 4)))),
	// EnemyTurnRules
	CHECK(EnemyTurnRules, _enemy_recruit_cost, 2, true, return gd::dict_value(enemy_turn_rules::_enemy_recruit_cost(s, D(a, 0), S(a, 1)))),
	CHECK(EnemyTurnRules, _latest_enemy_state, 3, true, return gd::dict_value(enemy_turn_rules::_latest_enemy_state(s, D(a, 0), S(a, 1), D(a, 2)))),
	CHECK(EnemyTurnRules, _owned_town_count, 2, true, return gd::int_value(enemy_turn_rules::_owned_town_count(s, D(a, 0), S(a, 1)))),
	CHECK(EnemyTurnRules, _town_name, 1, true, return gd::str(enemy_turn_rules::_town_name(s, D(a, 0)))),
	PORT(EnemyTurnRules, run_enemy_turn, 2, true, return gd::dict_value(enemy_turn_rules::run_enemy_turn(s, D(a, 0), B(a, 1)))),
	CHECK(EnemyTurnRules, _config_was_runtime_defaulted, 2, true, return gd::bool_value(enemy_turn_rules::_config_was_runtime_defaulted(s, D(a, 0), D(a, 1)))),
	CHECK(EnemyTurnRules, _faction_capital_state, 2, true, return gd::dict_value(enemy_turn_rules::_faction_capital_state(s, D(a, 0), S(a, 1)))),
	CHECK(EnemyTurnRules, _faction_front_state, 2, true, return gd::dict_value(enemy_turn_rules::_faction_front_state(s, D(a, 0), S(a, 1)))),
	CHECK(EnemyTurnRules, _max_active_raids_for_strategy, 4, true, return gd::int_value(enemy_turn_rules::_max_active_raids_for_strategy(s, D(a, 0), D(a, 1), S(a, 2), D(a, 3)))),
	CHECK(EnemyTurnRules, _raid_threshold_for_strategy, 4, true, return gd::int_value(enemy_turn_rules::_raid_threshold_for_strategy(s, D(a, 0), D(a, 1), S(a, 2), D(a, 3)))),
	CHECK(EnemyTurnRules, _valid_enemy_faction_configs, 1, true, return gd::array_value(enemy_turn_rules::_valid_enemy_faction_configs(s, A(a, 0)))),
	CHECK(EnemyTurnRules, active_raid_count, 2, true, return gd::int_value(enemy_turn_rules::active_raid_count(s, D(a, 0), S(a, 1)))),
	CHECK(EnemyTurnRules, get_pressure, 2, true, return gd::int_value(enemy_turn_rules::get_pressure(s, D(a, 0), S(a, 1)))),
	CHECK(EnemyTurnRules, normalize_optional_hero_task_state, 1, true, return gd::dict_value(enemy_turn_rules::normalize_optional_hero_task_state(s, X(a, 0)))),
	// END CHECKS
};

#undef CHECK
#undef PORT

} // namespace

// The AI turn port's table, listed in registry_tables.cpp. The turn calls no
// GDScript, and a path the port leaves out is a native failure: there is no
// GDScript turn to fall back to (slice 4.4).
Table turn_table() {
	Table table{"HEROES_NATIVE_TURN_LOG", kFunctions, sizeof(kFunctions) / sizeof(kFunctions[0])};
	return table;
}

} // namespace aurelion::rules::port
