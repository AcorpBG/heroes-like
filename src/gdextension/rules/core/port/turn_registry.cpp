#include "aurelion_rules/port/registry.hpp"

// BEGIN INCLUDES
#include "aurelion_rules/port/ai_hero_rules_turn.hpp"
#include "aurelion_rules/port/artifact_rules_turn.hpp"
#include "aurelion_rules/port/creature_dwelling_rules_turn.hpp"
#include "aurelion_rules/port/difficulty_rules_turn.hpp"
#include "aurelion_rules/port/enemy_adventure_rules_turn.hpp"
#include "aurelion_rules/port/enemy_town_services_turn.hpp"
#include "aurelion_rules/port/enemy_turn_rules_turn.hpp"
#include "aurelion_rules/port/faction_town_services_turn.hpp"
#include "aurelion_rules/port/hero_command_rules_turn.hpp"
#include "aurelion_rules/port/hero_progression_rules_turn.hpp"
#include "aurelion_rules/port/native_transit_rules_turn.hpp"
#include "aurelion_rules/port/overworld_level_rules_turn.hpp"
#include "aurelion_rules/port/overworld_rules_turn.hpp"
#include "aurelion_rules/port/overworld_turn_playback_turn.hpp"
#include "aurelion_rules/port/player_identity_rules_turn.hpp"
#include "aurelion_rules/port/resource_node_payload_rules_turn.hpp"
#include "aurelion_rules/port/scenario_factory_turn.hpp"
#include "aurelion_rules/port/scenario_rules_turn.hpp"
#include "aurelion_rules/port/scenario_script_rules_turn.hpp"
#include "aurelion_rules/port/scenario_select_rules_turn.hpp"
#include "aurelion_rules/port/spell_rules_turn.hpp"
#include "aurelion_rules/port/town_development_rules_turn.hpp"
#include "aurelion_rules/port/town_rules_turn.hpp"
#include "aurelion_rules/port/visit_building_rules_turn.hpp"
#include "aurelion_rules/port/water_travel_rules_turn.hpp"
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
// A function ported only inside run_enemy_turn: its switch runs the GDScript
// body outside shadow mode, and a shadow run checks each of its calls.
#define CHECK PORT

// run_enemy_turn runs native, every faction turn in it; each other function
// it reaches is checked on its own in a shadow run. A static var a port sets
// counts as a write.
const Function kFunctions[] = {
	// BEGIN CHECKS
	// AiHeroRules
	CHECK(AiHeroRules, _apply_weights, 1, true, ai_hero_rules::_apply_weights(s, D(a, 0)); return nil()),
	CHECK(AiHeroRules, _new_context, 3, true, return gd::dict_value(ai_hero_rules::_new_context(s, D(a, 0), D(a, 1), D(a, 2)))),
	CHECK(AiHeroRules, _note_sightings, 2, true, ai_hero_rules::_note_sightings(s, D(a, 0), D(a, 1)); return nil()),
	CHECK(AiHeroRules, _posture, 2, true, return gd::str(ai_hero_rules::_posture(s, D(a, 0), S(a, 1)))),
	CHECK(AiHeroRules, _resolved_weight_set, 1, true, return gd::dict_value(ai_hero_rules::_resolved_weight_set(s, S(a, 0)))),
	CHECK(AiHeroRules, _reveal_from_holdings, 2, true, ai_hero_rules::_reveal_from_holdings(s, D(a, 0), D(a, 1)); return nil()),
	CHECK(AiHeroRules, _shared_level_surfaces, 1, true, return gd::dict_value(ai_hero_rules::_shared_level_surfaces(s, D(a, 0)))),
	CHECK(AiHeroRules, _start_heroes_day, 2, true, ai_hero_rules::_start_heroes_day(s, D(a, 0), S(a, 1)); return nil()),
	CHECK(AiHeroRules, _store_explored, 1, true, ai_hero_rules::_store_explored(s, D(a, 0)); return nil()),
	CHECK(AiHeroRules, _turn_result, 6, true, return gd::dict_value(ai_hero_rules::_turn_result(s, D(a, 0), A(a, 1), A(a, 2), B(a, 3), D(a, 4), I(a, 5)))),
	CHECK(AiHeroRules, _use_weights, 1, true, ai_hero_rules::_use_weights(s, D(a, 0)); return nil()),
	CHECK(AiHeroRules, clear_shared_surfaces, 0, true, ai_hero_rules::clear_shared_surfaces(s); return nil()),
	CHECK(AiHeroRules, faction_daily_income, 2, true, return gd::dict_value(ai_hero_rules::faction_daily_income(s, D(a, 0), S(a, 1)))),
	CHECK(AiHeroRules, run_faction_turn, 5, true, return gd::dict_value(ai_hero_rules::run_faction_turn(s, D(a, 0), D(a, 1), D(a, 2), B(a, 3), B(a, 4)))),
	CHECK(AiHeroRules, _choose_plan, 3, true, return gd::dict_value(ai_hero_rules::_choose_plan(s, D(a, 0), D(a, 1), D(a, 2)))),
	CHECK(AiHeroRules, _close_decision_memos, 1, true, ai_hero_rules::_close_decision_memos(s, D(a, 0)); return nil()),
	CHECK(AiHeroRules, _decide_plan, 3, true, return gd::dict_value(ai_hero_rules::_decide_plan(s, D(a, 0), D(a, 1), D(a, 2)))),
	CHECK(AiHeroRules, _follow_plan, 4, true, return gd::dict_value(ai_hero_rules::_follow_plan(s, D(a, 0), D(a, 1), I(a, 2), D(a, 3)))),
	CHECK(AiHeroRules, _forget_beyond, 2, true, ai_hero_rules::_forget_beyond(s, D(a, 0), S(a, 1)); return nil()),
	CHECK(AiHeroRules, _interact, 4, true, return gd::dict_value(ai_hero_rules::_interact(s, D(a, 0), D(a, 1), I(a, 2), D(a, 3)))),
	CHECK(AiHeroRules, _log_decision, 4, true, ai_hero_rules::_log_decision(s, D(a, 0), D(a, 1), D(a, 2), D(a, 3)); return nil()),
	CHECK(AiHeroRules, _note_route_visit, 3, true, ai_hero_rules::_note_route_visit(s, D(a, 0), D(a, 1), D(a, 2)); return nil()),
	CHECK(AiHeroRules, _open_decision_memos, 1, true, ai_hero_rules::_open_decision_memos(s, D(a, 0)); return nil()),
	CHECK(AiHeroRules, _run_hero_day, 3, true, return gd::dict_value(ai_hero_rules::_run_hero_day(s, D(a, 0), D(a, 1), S(a, 2)))),
	CHECK(AiHeroRules, _strategic_candidate, 6, true, return gd::dict_value(ai_hero_rules::_strategic_candidate(s, D(a, 0), D(a, 1), D(a, 2), I(a, 3), I(a, 4), D(a, 5)))),
	CHECK(AiHeroRules, _vetted_candidate, 5, true, return gd::dict_value(ai_hero_rules::_vetted_candidate(s, D(a, 0), D(a, 1), D(a, 2), D(a, 3), I(a, 4)))),
	CHECK(AiHeroRules, placement_is_main, 3, true, return gd::bool_value(ai_hero_rules::placement_is_main(s, D(a, 0), D(a, 1), D(a, 2)))),
	CHECK(AiHeroRules, _add_pool, 2, true, ai_hero_rules::_add_pool(s, D(a, 0), X(a, 1)); return nil()),
	CHECK(AiHeroRules, _attack_town, 4, true, return gd::dict_value(ai_hero_rules::_attack_town(s, D(a, 0), D(a, 1), I(a, 2), D(a, 3)))),
	CHECK(AiHeroRules, _auto_resolve, 4, true, return gd::dict_value(ai_hero_rules::_auto_resolve(s, D(a, 0), D(a, 1), I(a, 2), D(a, 3)))),
	CHECK(AiHeroRules, _avoid_target, 4, true, ai_hero_rules::_avoid_target(s, D(a, 0), S(a, 1), S(a, 2), I(a, 3)); return nil()),
	CHECK(AiHeroRules, _battle_key, 3, true, return gd::str(ai_hero_rules::_battle_key(s, D(a, 0), D(a, 1), I(a, 2)))),
	CHECK(AiHeroRules, _claim_resource, 4, true, return gd::dict_value(ai_hero_rules::_claim_resource(s, D(a, 0), D(a, 1), I(a, 2), D(a, 3)))),
	CHECK(AiHeroRules, _clear_static_body, 3, true, ai_hero_rules::_clear_static_body(s, D(a, 0), D(a, 1), D(a, 2)); return nil()),
	CHECK(AiHeroRules, _commander_brief, 1, true, return gd::dict_value(ai_hero_rules::_commander_brief(s, X(a, 0)))),
	CHECK(AiHeroRules, _cornered_fight, 4, true, return gd::dict_value(ai_hero_rules::_cornered_fight(s, D(a, 0), D(a, 1), D(a, 2), D(a, 3)))),
	CHECK(AiHeroRules, _creature_total, 1, true, return gd::int_value(ai_hero_rules::_creature_total(s, X(a, 0)))),
	CHECK(AiHeroRules, _defender_label, 1, true, return gd::str(ai_hero_rules::_defender_label(s, D(a, 0)))),
	CHECK(AiHeroRules, _defender_target, 2, true, return gd::dict_value(ai_hero_rules::_defender_target(s, D(a, 0), S(a, 1)))),
	CHECK(AiHeroRules, _economy_add, 4, true, ai_hero_rules::_economy_add(s, D(a, 0), S(a, 1), S(a, 2), F(a, 3)); return nil()),
	CHECK(AiHeroRules, _event, 7, true, return gd::dict_value(ai_hero_rules::_event(s, D(a, 0), D(a, 1), S(a, 2), D(a, 3), D(a, 4), S(a, 5), A(a, 6)))),
	CHECK(AiHeroRules, _fight_ai_hero, 4, true, return gd::dict_value(ai_hero_rules::_fight_ai_hero(s, D(a, 0), D(a, 1), I(a, 2), D(a, 3)))),
	CHECK(AiHeroRules, _step_back_from_guard, 3, true, ai_hero_rules::_step_back_from_guard(s, D(a, 0), I(a, 1), D(a, 2)); return nil()),
	CHECK(AiHeroRules, _fight_looks_good, 5, true, return gd::bool_value(ai_hero_rules::_fight_looks_good(s, D(a, 0), D(a, 1), D(a, 2), D(a, 3), B(a, 4)))),
	CHECK(AiHeroRules, _fight_neutral, 4, true, return gd::dict_value(ai_hero_rules::_fight_neutral(s, D(a, 0), D(a, 1), I(a, 2), D(a, 3)))),
	CHECK(AiHeroRules, _find_town, 2, true, return gd::dict_value(ai_hero_rules::_find_town(s, D(a, 0), S(a, 1)))),
	CHECK(AiHeroRules, _forget_sighting, 2, true, ai_hero_rules::_forget_sighting(s, D(a, 0), S(a, 1)); return nil()),
	CHECK(AiHeroRules, _free_fight, 4, true, return gd::dict_value(ai_hero_rules::_free_fight(s, D(a, 0), D(a, 1), D(a, 2), D(a, 3)))),
	CHECK(AiHeroRules, _gate_fight_looks_good, 4, true, return gd::bool_value(ai_hero_rules::_gate_fight_looks_good(s, D(a, 0), D(a, 1), D(a, 2), D(a, 3)))),
	CHECK(AiHeroRules, _home_reachable, 4, true, return gd::bool_value(ai_hero_rules::_home_reachable(s, D(a, 0), D(a, 1), D(a, 2), D(a, 3)))),
	CHECK(AiHeroRules, _idle_fight, 4, true, return gd::dict_value(ai_hero_rules::_idle_fight(s, D(a, 0), D(a, 1), D(a, 2), D(a, 3)))),
	CHECK(AiHeroRules, _is_resolved, 2, true, return gd::bool_value(ai_hero_rules::_is_resolved(s, D(a, 0), S(a, 1)))),
	CHECK(AiHeroRules, _log_battle, 6, true, ai_hero_rules::_log_battle(s, D(a, 0), D(a, 1), D(a, 2), D(a, 3), D(a, 4), B(a, 5)); return nil()),
	CHECK(AiHeroRules, _make_room, 3, true, return gd::dict_value(ai_hero_rules::_make_room(s, A(a, 0), S(a, 1), I(a, 2)))),
	CHECK(AiHeroRules, _mark_resolved, 2, true, ai_hero_rules::_mark_resolved(s, D(a, 0), S(a, 1)); return nil()),
	CHECK(AiHeroRules, _max_affordable_with_market, 5, true, return gd::int_value(ai_hero_rules::_max_affordable_with_market(s, D(a, 0), D(a, 1), D(a, 2), D(a, 3), I(a, 4)))),
	CHECK(AiHeroRules, _meet_hero, 4, true, return gd::dict_value(ai_hero_rules::_meet_hero(s, D(a, 0), D(a, 1), I(a, 2), D(a, 3)))),
	CHECK(AiHeroRules, _record_hero_defeat, 3, true, ai_hero_rules::_record_hero_defeat(s, D(a, 0), S(a, 1), D(a, 2)); return nil()),
	CHECK(AiHeroRules, _recruit_town, 4, true, return gd::array_value(ai_hero_rules::_recruit_town(s, D(a, 0), D(a, 1), I(a, 2), D(a, 3)))),
	CHECK(AiHeroRules, _store_entry, 3, true, ai_hero_rules::_store_entry(s, D(a, 0), I(a, 1), D(a, 2)); return nil()),
	CHECK(AiHeroRules, _take_artifact, 4, true, return gd::dict_value(ai_hero_rules::_take_artifact(s, D(a, 0), D(a, 1), I(a, 2), D(a, 3)))),
	CHECK(AiHeroRules, _take_garrison, 5, true, return gd::dict_value(ai_hero_rules::_take_garrison(s, D(a, 0), D(a, 1), D(a, 2), D(a, 3), B(a, 4)))),
	CHECK(AiHeroRules, hero_name, 1, true, return gd::str(ai_hero_rules::hero_name(s, D(a, 0)))),
	CHECK(AiHeroRules, _clear_way, 5, true, return gd::bool_value(ai_hero_rules::_clear_way(s, D(a, 0), D(a, 1), D(a, 2), I(a, 3), I(a, 4)))),
	CHECK(AiHeroRules, _cross_gate, 4, true, return gd::dict_value(ai_hero_rules::_cross_gate(s, D(a, 0), D(a, 1), I(a, 2), D(a, 3)))),
	CHECK(AiHeroRules, _cross_shore, 5, true, return gd::bool_value(ai_hero_rules::_cross_shore(s, D(a, 0), D(a, 1), D(a, 2), V(a, 3), I(a, 4)))),
	CHECK(AiHeroRules, _cuts_a_way, 3, true, return gd::bool_value(ai_hero_rules::_cuts_a_way(s, D(a, 0), I(a, 1), V(a, 2)))),
	CHECK(AiHeroRules, _danger_gap, 4, true, return gd::int_value(ai_hero_rules::_danger_gap(s, A(a, 0), I(a, 1), I(a, 2), I(a, 3)))),
	CHECK(AiHeroRules, _evade, 4, true, return gd::dict_value(ai_hero_rules::_evade(s, D(a, 0), D(a, 1), D(a, 2), D(a, 3)))),
	CHECK(AiHeroRules, _gate_home, 5, true, return gd::dict_value(ai_hero_rules::_gate_home(s, D(a, 0), D(a, 1), D(a, 2), D(a, 3), D(a, 4)))),
	CHECK(AiHeroRules, _gate_walk, 5, true, return gd::dict_value(ai_hero_rules::_gate_walk(s, D(a, 0), D(a, 1), D(a, 2), D(a, 3), D(a, 4)))),
	CHECK(AiHeroRules, _holds_gate, 5, true, return gd::bool_value(ai_hero_rules::_holds_gate(s, D(a, 0), D(a, 1), D(a, 2), D(a, 3), B(a, 4)))),
	CHECK(AiHeroRules, _hostile_hero_beside, 4, true, return gd::dict_value(ai_hero_rules::_hostile_hero_beside(s, D(a, 0), D(a, 1), V(a, 2), I(a, 3)))),
	CHECK(AiHeroRules, _launch_boat, 5, true, return gd::dict_value(ai_hero_rules::_launch_boat(s, D(a, 0), D(a, 1), D(a, 2), V(a, 3), I(a, 4)))),
	CHECK(AiHeroRules, _leave_guard, 5, true, return gd::bool_value(ai_hero_rules::_leave_guard(s, D(a, 0), D(a, 1), D(a, 2), D(a, 3), F(a, 4)))),
	CHECK(AiHeroRules, _make_way, 4, true, return gd::bool_value(ai_hero_rules::_make_way(s, D(a, 0), D(a, 1), S(a, 2), D(a, 3)))),
	CHECK(AiHeroRules, _nearest_owned_town, 4, true, return gd::dict_value(ai_hero_rules::_nearest_owned_town(s, D(a, 0), S(a, 1), V(a, 2), I(a, 3)))),
	CHECK(AiHeroRules, _next_to_any, 2, true, return gd::bool_value(ai_hero_rules::_next_to_any(s, V(a, 0), A(a, 1)))),
	CHECK(AiHeroRules, _note_boat_need, 3, true, ai_hero_rules::_note_boat_need(s, D(a, 0), D(a, 1), D(a, 2)); return nil()),
	CHECK(AiHeroRules, _own_town_at, 3, true, return gd::dict_value(ai_hero_rules::_own_town_at(s, D(a, 0), S(a, 1), D(a, 2)))),
	CHECK(AiHeroRules, _park, 3, true, ai_hero_rules::_park(s, D(a, 0), S(a, 1), S(a, 2)); return nil()),
	CHECK(AiHeroRules, _parked_hero_id, 3, true, return gd::str(ai_hero_rules::_parked_hero_id(s, D(a, 0), S(a, 1), S(a, 2)))),
	CHECK(AiHeroRules, _pending_make_way, 4, true, return gd::dict_value(ai_hero_rules::_pending_make_way(s, D(a, 0), D(a, 1), D(a, 2), D(a, 3)))),
	CHECK(AiHeroRules, _portal_step, 5, true, return gd::dict_value(ai_hero_rules::_portal_step(s, D(a, 0), D(a, 1), D(a, 2), V(a, 3), I(a, 4)))),
	CHECK(AiHeroRules, _reveal, 4, true, ai_hero_rules::_reveal(s, D(a, 0), D(a, 1), D(a, 2), I(a, 3)); return nil()),
	CHECK(AiHeroRules, _sight_radius, 1, true, return gd::int_value(ai_hero_rules::_sight_radius(s, D(a, 0)))),
	CHECK(AiHeroRules, _tile_blocked_for_standing, 5, true, return gd::bool_value(ai_hero_rules::_tile_blocked_for_standing(s, D(a, 0), D(a, 1), V(a, 2), I(a, 3), S(a, 4)))),
	CHECK(AiHeroRules, _visit_own_town_if_inside, 3, true, return gd::dict_value(ai_hero_rules::_visit_own_town_if_inside(s, D(a, 0), D(a, 1), I(a, 2)))),
	CHECK(AiHeroRules, _wait_by_home, 5, true, return gd::dict_value(ai_hero_rules::_wait_by_home(s, D(a, 0), D(a, 1), D(a, 2), D(a, 3), D(a, 4)))),
	CHECK(AiHeroRules, _append_all, 2, true, ai_hero_rules::_append_all(s, A(a, 0), X(a, 1)); return nil()),
	CHECK(AiHeroRules, _build_choice, 4, true, return gd::dict_value(ai_hero_rules::_build_choice(s, D(a, 0), D(a, 1), D(a, 2), D(a, 3)))),
	CHECK(AiHeroRules, _build_in_towns, 2, true, return gd::dict_value(ai_hero_rules::_build_in_towns(s, D(a, 0), D(a, 1)))),
	CHECK(AiHeroRules, _build_tavern, 3, true, return gd::dict_value(ai_hero_rules::_build_tavern(s, D(a, 0), D(a, 1), A(a, 2)))),
	CHECK(AiHeroRules, _create_hero, 5, true, return gd::dict_value(ai_hero_rules::_create_hero(s, D(a, 0), D(a, 1), D(a, 2), S(a, 3), A(a, 4)))),
	CHECK(AiHeroRules, _desired_hero_count, 2, true, return gd::int_value(ai_hero_rules::_desired_hero_count(s, D(a, 0), S(a, 1)))),
	CHECK(AiHeroRules, _hold_back, 2, true, return gd::dict_value(ai_hero_rules::_hold_back(s, D(a, 0), D(a, 1)))),
	CHECK(AiHeroRules, _ensure_opening_stockpile, 2, true, ai_hero_rules::_ensure_opening_stockpile(s, D(a, 0), D(a, 1)); return nil()),
	CHECK(AiHeroRules, _ensure_starting_hero, 2, true, return gd::dict_value(ai_hero_rules::_ensure_starting_hero(s, D(a, 0), D(a, 1)))),
	CHECK(AiHeroRules, _faction_has_tavern, 1, true, return gd::bool_value(ai_hero_rules::_faction_has_tavern(s, A(a, 0)))),
	CHECK(AiHeroRules, _govern_towns, 2, true, return gd::dict_value(ai_hero_rules::_govern_towns(s, D(a, 0), D(a, 1)))),
	CHECK(AiHeroRules, _hire_hero, 2, true, return gd::dict_value(ai_hero_rules::_hire_hero(s, D(a, 0), D(a, 1)))),
	CHECK(AiHeroRules, _market_value, 2, true, return gd::float_value(ai_hero_rules::_market_value(s, D(a, 0), D(a, 1)))),
	CHECK(AiHeroRules, _opens_count, 3, true, return gd::int_value(ai_hero_rules::_opens_count(s, D(a, 0), S(a, 1), A(a, 2)))),
	CHECK(AiHeroRules, _pool_delta, 2, true, return gd::dict_value(ai_hero_rules::_pool_delta(s, D(a, 0), D(a, 1)))),
	CHECK(AiHeroRules, _recruit_in_towns, 3, true, return gd::dict_value(ai_hero_rules::_recruit_in_towns(s, D(a, 0), D(a, 1), D(a, 2)))),
	CHECK(AiHeroRules, _roster_progression_seed, 2, true, return gd::dict_value(ai_hero_rules::_roster_progression_seed(s, D(a, 0), S(a, 1)))),
	CHECK(AiHeroRules, _tavern_pool, 3, true, return gd::array_value(ai_hero_rules::_tavern_pool(s, D(a, 0), D(a, 1), S(a, 2)))),
	CHECK(AiHeroRules, _trial_income, 1, true, return gd::dict_value(ai_hero_rules::_trial_income(s, D(a, 0)))),
	CHECK(AiHeroRules, ai_tavern_offer_ids, 3, true, return gd::array_value(ai_hero_rules::ai_tavern_offer_ids(s, D(a, 0), D(a, 1), S(a, 2)))),
	CHECK(AiHeroRules, build_in_town, 5, true, return gd::dict_value(ai_hero_rules::build_in_town(s, D(a, 0), D(a, 1), I(a, 2), S(a, 3), S(a, 4)))),
	CHECK(AiHeroRules, _attack_player_hero, 4, true, return gd::dict_value(ai_hero_rules::_attack_player_hero(s, D(a, 0), D(a, 1), I(a, 2), D(a, 3)))),
	CHECK(AiHeroRules, _convert_legacy_host, 3, true, return gd::dict_value(ai_hero_rules::_convert_legacy_host(s, D(a, 0), D(a, 1), S(a, 2)))),
	CHECK(AiHeroRules, _nearest_hero_index, 5, true, return gd::int_value(ai_hero_rules::_nearest_hero_index(s, A(a, 0), D(a, 1), S(a, 2), D(a, 3), I(a, 4)))),
	CHECK(AiHeroRules, _return_troops_to_nearest_town, 3, true, ai_hero_rules::_return_troops_to_nearest_town(s, D(a, 0), D(a, 1), S(a, 2)); return nil()),
	CHECK(AiHeroRules, _upgrade_value, 2, true, return gd::float_value(ai_hero_rules::_upgrade_value(s, D(a, 0), D(a, 1)))),
	// ArtifactRules
	CHECK(ArtifactRules, _already_owned_message, 3, true, return gd::str(artifact_rules::_already_owned_message(s, S(a, 0), D(a, 1), S(a, 2)))),
	CHECK(ArtifactRules, _artifact_effect_line, 1, true, return gd::str(artifact_rules::_artifact_effect_line(s, S(a, 0)))),
	CHECK(ArtifactRules, _artifact_effect_summary, 1, true, return gd::str(artifact_rules::_artifact_effect_summary(s, D(a, 0)))),
	CHECK(ArtifactRules, _artifact_equipped_note, 2, true, return gd::str(artifact_rules::_artifact_equipped_note(s, S(a, 0), S(a, 1)))),
	CHECK(ArtifactRules, _artifact_set_id, 1, true, return gd::str(artifact_rules::_artifact_set_id(s, D(a, 0)))),
	CHECK(ArtifactRules, _artifact_source_contract, 1, true, return gd::dict_value(artifact_rules::_artifact_source_contract(s, D(a, 0)))),
	CHECK(ArtifactRules, _artifact_source_runtime_policy, 1, true, return gd::dict_value(artifact_rules::_artifact_source_runtime_policy(s, D(a, 0)))),
	CHECK(ArtifactRules, _artifact_spell_modifier_parts, 1, true, return gd::array_value(artifact_rules::_artifact_spell_modifier_parts(s, X(a, 0)))),
	CHECK(ArtifactRules, _artifact_taxonomy_payload, 1, true, return gd::dict_value(artifact_rules::_artifact_taxonomy_payload(s, D(a, 0)))),
	CHECK(ArtifactRules, _artifact_ui_summary, 1, true, return gd::str(artifact_rules::_artifact_ui_summary(s, D(a, 0)))),
	CHECK(ArtifactRules, _draw_from_rarities, 5, true, return gd::dict_value(artifact_rules::_draw_from_rarities(s, S(a, 0), A(a, 1), S(a, 2), S(a, 3), A(a, 4)))),
	CHECK(ArtifactRules, _equipment_slot_label, 1, true, return gd::str(artifact_rules::_equipment_slot_label(s, S(a, 0)))),
	CHECK(ArtifactRules, _first_empty_compatible_slot, 2, true, return gd::str(artifact_rules::_first_empty_compatible_slot(s, X(a, 0), S(a, 1)))),
	CHECK(ArtifactRules, _matching_artifact_source_contexts, 3, true, return gd::array_value(artifact_rules::_matching_artifact_source_contexts(s, D(a, 0), A(a, 1), B(a, 2)))),
	CHECK(ArtifactRules, _remove_artifact_from_inventory, 2, true, return gd::bool_value(artifact_rules::_remove_artifact_from_inventory(s, A(a, 0), S(a, 1)))),
	CHECK(ArtifactRules, _resource_display_name, 1, true, return gd::str(artifact_rules::_resource_display_name(s, S(a, 0)))),
	CHECK(ArtifactRules, _select_class_source_reward, 4, true, return gd::dict_value(artifact_rules::_select_class_source_reward(s, S(a, 0), S(a, 1), S(a, 2), A(a, 3)))),
	CHECK(ArtifactRules, _signed_amount_label, 1, true, return gd::str(artifact_rules::_signed_amount_label(s, I(a, 0)))),
	CHECK(ArtifactRules, _source_record_guard_tier, 1, true, return gd::str(artifact_rules::_source_record_guard_tier(s, D(a, 0)))),
	CHECK(ArtifactRules, _source_record_has_required_categories, 2, true, return gd::bool_value(artifact_rules::_source_record_has_required_categories(s, D(a, 0), A(a, 1)))),
	CHECK(ArtifactRules, _source_record_has_required_tags, 2, true, return gd::bool_value(artifact_rules::_source_record_has_required_tags(s, D(a, 0), A(a, 1)))),
	CHECK(ArtifactRules, _source_record_reward_categories, 1, true, return gd::array_value(artifact_rules::_source_record_reward_categories(s, D(a, 0)))),
	CHECK(ArtifactRules, _stable_source_reward_index, 2, true, return gd::int_value(artifact_rules::_stable_source_reward_index(s, S(a, 0), I(a, 1)))),
	CHECK(ArtifactRules, _title_label, 1, true, return gd::str(artifact_rules::_title_label(s, S(a, 0)))),
	CHECK(ArtifactRules, artifact_effect_summary, 1, true, return gd::str(artifact_rules::artifact_effect_summary(s, S(a, 0)))),
	CHECK(ArtifactRules, artifact_name, 1, true, return gd::str(artifact_rules::artifact_name(s, S(a, 0)))),
	CHECK(ArtifactRules, artifact_reward_role, 1, true, return gd::str(artifact_rules::artifact_reward_role(s, S(a, 0)))),
	CHECK(ArtifactRules, artifact_taxonomy, 1, true, return gd::dict_value(artifact_rules::artifact_taxonomy(s, S(a, 0)))),
	CHECK(ArtifactRules, artifact_taxonomy_summary, 1, true, return gd::str(artifact_rules::artifact_taxonomy_summary(s, S(a, 0)))),
	CHECK(ArtifactRules, claim_artifact, 4, true, return gd::dict_value(artifact_rules::claim_artifact(s, D(a, 0), S(a, 1), S(a, 2), B(a, 3)))),
	CHECK(ArtifactRules, describe_artifact, 1, true, return gd::str(artifact_rules::describe_artifact(s, S(a, 0)))),
	CHECK(ArtifactRules, equip_artifact, 2, true, return gd::dict_value(artifact_rules::equip_artifact(s, D(a, 0), S(a, 1)))),
	CHECK(ArtifactRules, live_source_reward_tag, 1, true, return gd::str(artifact_rules::live_source_reward_tag(s, D(a, 0)))),
	CHECK(ArtifactRules, locate_artifact, 2, true, return gd::dict_value(artifact_rules::locate_artifact(s, D(a, 0), S(a, 1)))),
	CHECK(ArtifactRules, owned_artifact_ids, 1, true, return gd::array_value(artifact_rules::owned_artifact_ids(s, D(a, 0)))),
	CHECK(ArtifactRules, select_live_source_reward, 5, true, return gd::dict_value(artifact_rules::select_live_source_reward(s, S(a, 0), D(a, 1), S(a, 2), S(a, 3), A(a, 4)))),
	CHECK(ArtifactRules, select_live_source_rewards, 5, true, return gd::array_value(artifact_rules::select_live_source_rewards(s, S(a, 0), D(a, 1), S(a, 2), S(a, 3), A(a, 4)))),
	CHECK(ArtifactRules, _artifact_collection_note, 2, true, return gd::str(artifact_rules::_artifact_collection_note(s, D(a, 0), S(a, 1)))),
	CHECK(ArtifactRules, artifact_slot_label, 1, true, return gd::str(artifact_rules::artifact_slot_label(s, S(a, 0)))),
	CHECK(ArtifactRules, artifact_set_runtime_state, 1, true, return gd::array_value(artifact_rules::artifact_set_runtime_state(s, D(a, 0)))),
	CHECK(ArtifactRules, has_artifact, 2, true, return gd::bool_value(artifact_rules::has_artifact(s, D(a, 0), S(a, 1)))),
	CHECK(ArtifactRules, remove_owned_artifact, 2, true, return gd::dict_value(artifact_rules::remove_owned_artifact(s, D(a, 0), S(a, 1)))),
	// CreatureDwellingRules
	CHECK(CreatureDwellingRules, guard_key, 1, true, return gd::str(creature_dwelling_rules::guard_key(s, S(a, 0)))),
	CHECK(CreatureDwellingRules, record_guard_result, 5, true, creature_dwelling_rules::record_guard_result(s, D(a, 0), S(a, 1), A(a, 2), B(a, 3), I(a, 4)); return nil()),
	CHECK(CreatureDwellingRules, take, 5, true, creature_dwelling_rules::take(s, D(a, 0), D(a, 1), S(a, 2), I(a, 3), I(a, 4)); return nil()),
	// DifficultyRules
	CHECK(DifficultyRules, adjust_enemy_pressure_gain, 2, true, return gd::int_value(difficulty_rules::adjust_enemy_pressure_gain(s, D(a, 0), I(a, 1)))),
	CHECK(DifficultyRules, adjust_raid_threshold, 2, true, return gd::int_value(difficulty_rules::adjust_raid_threshold(s, D(a, 0), I(a, 1)))),
	// EnemyAdventureRules
	CHECK(EnemyAdventureRules, _ai_hero_task_actor_id_from_raid, 1, true, return gd::str(enemy_adventure_rules::_ai_hero_task_actor_id_from_raid(s, D(a, 0)))),
	CHECK(EnemyAdventureRules, _ai_hero_task_finish_live_assignment, 5, true, enemy_adventure_rules::_ai_hero_task_finish_live_assignment(s, D(a, 0), S(a, 1), D(a, 2), S(a, 3), S(a, 4)); return nil()),
	CHECK(EnemyAdventureRules, _apply_resource_site_artifact_reward_to_raid, 5, true, return gd::dict_value(enemy_adventure_rules::_apply_resource_site_artifact_reward_to_raid(s, D(a, 0), S(a, 1), D(a, 2), D(a, 3), D(a, 4)))),
	CHECK(EnemyAdventureRules, _apply_resource_site_claim_recruits_to_raid, 4, true, return gd::dict_value(enemy_adventure_rules::_apply_resource_site_claim_recruits_to_raid(s, D(a, 0), S(a, 1), D(a, 2), D(a, 3)))),
	CHECK(EnemyAdventureRules, _apply_resource_site_spell_reward_to_commander, 4, true, return gd::dict_value(enemy_adventure_rules::_apply_resource_site_spell_reward_to_commander(s, D(a, 0), S(a, 1), D(a, 2), D(a, 3)))),
	CHECK(EnemyAdventureRules, _award_enemy_commander_experience, 2, true, return gd::dict_value(enemy_adventure_rules::_award_enemy_commander_experience(s, D(a, 0), I(a, 1)))),
	CHECK(EnemyAdventureRules, _break_dwelling_guard_by_raid, 5, true, return gd::bool_value(enemy_adventure_rules::_break_dwelling_guard_by_raid(s, D(a, 0), D(a, 1), S(a, 2), I(a, 3), D(a, 4)))),
	CHECK(EnemyAdventureRules, _commander_map_level, 1, true, return gd::int_value(enemy_adventure_rules::_commander_map_level(s, X(a, 0)))),
	CHECK(EnemyAdventureRules, _commander_memory_target_kind_for_outcome, 2, true, return gd::str(enemy_adventure_rules::_commander_memory_target_kind_for_outcome(s, S(a, 0), D(a, 1)))),
	CHECK(EnemyAdventureRules, _commander_name_from_source, 1, true, return gd::str(enemy_adventure_rules::_commander_name_from_source(s, X(a, 0)))),
	CHECK(EnemyAdventureRules, _default_public_importance, 2, true, return gd::str(enemy_adventure_rules::_default_public_importance(s, S(a, 0), A(a, 1)))),
	CHECK(EnemyAdventureRules, _describe_recruit_set, 1, true, return gd::str(enemy_adventure_rules::_describe_recruit_set(s, X(a, 0)))),
	CHECK(EnemyAdventureRules, _describe_resource_set, 1, true, return gd::str(enemy_adventure_rules::_describe_resource_set(s, D(a, 0)))),
	CHECK(EnemyAdventureRules, _event_visibility, 5, true, return gd::str(enemy_adventure_rules::_event_visibility(s, D(a, 0), I(a, 1), I(a, 2), S(a, 3), I(a, 4)))),
	CHECK(EnemyAdventureRules, _hire_at_own_dwelling_by_raid, 7, true, return gd::dict_value(enemy_adventure_rules::_hire_at_own_dwelling_by_raid(s, D(a, 0), D(a, 1), D(a, 2), S(a, 3), I(a, 4), D(a, 5), D(a, 6)))),
	CHECK(EnemyAdventureRules, _hire_dwelling_creatures_into_raid, 6, true, return gd::dict_value(enemy_adventure_rules::_hire_dwelling_creatures_into_raid(s, D(a, 0), S(a, 1), D(a, 2), I(a, 3), D(a, 4), D(a, 5)))),
	CHECK(EnemyAdventureRules, _linked_player_town_bonus, 2, true, return gd::int_value(enemy_adventure_rules::_linked_player_town_bonus(s, D(a, 0), D(a, 1)))),
	CHECK(EnemyAdventureRules, _merge_resources, 2, true, return gd::dict_value(enemy_adventure_rules::_merge_resources(s, X(a, 0), X(a, 1)))),
	CHECK(EnemyAdventureRules, _normalize_recruit_payload, 1, true, return gd::dict_value(enemy_adventure_rules::_normalize_recruit_payload(s, X(a, 0)))),
	CHECK(EnemyAdventureRules, _raid_name, 1, true, return gd::str(enemy_adventure_rules::_raid_name(s, D(a, 0)))),
	CHECK(EnemyAdventureRules, _raid_reinforcement_army, 1, true, return gd::dict_value(enemy_adventure_rules::_raid_reinforcement_army(s, D(a, 0)))),
	CHECK(EnemyAdventureRules, _raid_site_recruit_admission, 2, true, return gd::dict_value(enemy_adventure_rules::_raid_site_recruit_admission(s, D(a, 0), D(a, 1)))),
	CHECK(EnemyAdventureRules, _record_adventure_objective_success, 5, true, return gd::dict_value(enemy_adventure_rules::_record_adventure_objective_success(s, D(a, 0), S(a, 1), D(a, 2), S(a, 3), S(a, 4)))),
	CHECK(EnemyAdventureRules, _record_commander_adaptive_task_memory, 2, true, return gd::dict_value(enemy_adventure_rules::_record_commander_adaptive_task_memory(s, D(a, 0), S(a, 1)))),
	CHECK(EnemyAdventureRules, _recruit_payload_value, 1, true, return gd::int_value(enemy_adventure_rules::_recruit_payload_value(s, X(a, 0)))),
	CHECK(EnemyAdventureRules, _resource_route_pressure_value, 1, true, return gd::int_value(enemy_adventure_rules::_resource_route_pressure_value(s, D(a, 0)))),
	CHECK(EnemyAdventureRules, _resource_site_claim_recruits, 1, true, return gd::dict_value(enemy_adventure_rules::_resource_site_claim_recruits(s, D(a, 0)))),
	CHECK(EnemyAdventureRules, _resource_site_support_value, 1, true, return gd::int_value(enemy_adventure_rules::_resource_site_support_value(s, D(a, 0)))),
	CHECK(EnemyAdventureRules, _resource_target_reason_codes, 8, true, return gd::array_value(enemy_adventure_rules::_resource_target_reason_codes(s, D(a, 0), B(a, 1), B(a, 2), I(a, 3), I(a, 4), I(a, 5), I(a, 6), I(a, 7)))),
	CHECK(EnemyAdventureRules, _reward_resources_for_empire, 1, true, return gd::dict_value(enemy_adventure_rules::_reward_resources_for_empire(s, X(a, 0)))),
	CHECK(EnemyAdventureRules, _secure_resource_target, 5, true, return gd::dict_value(enemy_adventure_rules::_secure_resource_target(s, D(a, 0), D(a, 1), D(a, 2), S(a, 3), D(a, 4)))),
	CHECK(EnemyAdventureRules, _target_level, 5, true, return gd::int_value(enemy_adventure_rules::_target_level(s, D(a, 0), S(a, 1), S(a, 2), S(a, 3), I(a, 4)))),
	CHECK(EnemyAdventureRules, _target_resource_value, 1, true, return gd::int_value(enemy_adventure_rules::_target_resource_value(s, X(a, 0)))),
	CHECK(EnemyAdventureRules, _visit_building_by_raid, 7, true, return gd::dict_value(enemy_adventure_rules::_visit_building_by_raid(s, D(a, 0), D(a, 1), D(a, 2), S(a, 3), D(a, 4), D(a, 5), D(a, 6)))),
	CHECK(EnemyAdventureRules, _with_runtime_spellbook_state, 2, true, return gd::dict_value(enemy_adventure_rules::_with_runtime_spellbook_state(s, D(a, 0), X(a, 1)))),
	CHECK(EnemyAdventureRules, advance_commander_record, 2, true, return gd::dict_value(enemy_adventure_rules::advance_commander_record(s, D(a, 0), S(a, 1)))),
	CHECK(EnemyAdventureRules, build_ai_event_record, 6, true, return gd::dict_value(enemy_adventure_rules::build_ai_event_record(s, D(a, 0), D(a, 1), S(a, 2), D(a, 3), D(a, 4), D(a, 5)))),
	CHECK(EnemyAdventureRules, commander_display_name, 2, true, return gd::str(enemy_adventure_rules::commander_display_name(s, X(a, 0), B(a, 1)))),
	CHECK(EnemyAdventureRules, commander_live_role_state, 1, true, return gd::dict_value(enemy_adventure_rules::commander_live_role_state(s, X(a, 0)))),
	CHECK(EnemyAdventureRules, commander_target_memory, 1, true, return gd::dict_value(enemy_adventure_rules::commander_target_memory(s, X(a, 0)))),
	CHECK(EnemyAdventureRules, raid_commander_display_name, 1, true, return gd::str(enemy_adventure_rules::raid_commander_display_name(s, D(a, 0)))),
	CHECK(EnemyAdventureRules, raid_commander_name, 1, true, return gd::str(enemy_adventure_rules::raid_commander_name(s, D(a, 0)))),
	CHECK(EnemyAdventureRules, sync_commander_state_to_roster, 7, true, enemy_adventure_rules::sync_commander_state_to_roster(s, D(a, 0), S(a, 1), X(a, 2), S(a, 3), S(a, 4), I(a, 5), S(a, 6)); return nil()),
	CHECK(EnemyAdventureRules, _clear_regroup_target, 1, true, return gd::dict_value(enemy_adventure_rules::_clear_regroup_target(s, D(a, 0)))),
	CHECK(EnemyAdventureRules, _current_enemy_player_hero_sighting_records, 5, true, return gd::array_value(enemy_adventure_rules::_current_enemy_player_hero_sighting_records(s, D(a, 0), D(a, 1), S(a, 2), X(a, 3), X(a, 4)))),
	CHECK(EnemyAdventureRules, _default_enemy_strategy, 0, true, return gd::dict_value(enemy_adventure_rules::_default_enemy_strategy(s))),
	CHECK(EnemyAdventureRules, _default_reason_codes_for_target, 3, true, return gd::array_value(enemy_adventure_rules::_default_reason_codes_for_target(s, S(a, 0), S(a, 1), D(a, 2)))),
	CHECK(EnemyAdventureRules, _dwelling_guard_strength, 4, true, return gd::int_value(enemy_adventure_rules::_dwelling_guard_strength(s, D(a, 0), D(a, 1), D(a, 2), S(a, 3)))),
	CHECK(EnemyAdventureRules, _encounter_is_objective_anchor, 2, true, return gd::bool_value(enemy_adventure_rules::_encounter_is_objective_anchor(s, D(a, 0), D(a, 1)))),
	CHECK(EnemyAdventureRules, _enemy_hero_sighting_sources, 3, true, return gd::array_value(enemy_adventure_rules::_enemy_hero_sighting_sources(s, D(a, 0), D(a, 1), S(a, 2)))),
	CHECK(EnemyAdventureRules, _enemy_player_hero_sighting_record, 3, true, return gd::dict_value(enemy_adventure_rules::_enemy_player_hero_sighting_record(s, D(a, 0), S(a, 1), S(a, 2)))),
	CHECK(EnemyAdventureRules, _exploration_target_level, 1, true, return gd::int_value(enemy_adventure_rules::_exploration_target_level(s, S(a, 0)))),
	CHECK(EnemyAdventureRules, _find_encounter_by_placement, 2, true, return gd::dict_value(enemy_adventure_rules::_find_encounter_by_placement(s, D(a, 0), S(a, 1)))),
	CHECK(EnemyAdventureRules, _find_player_hero, 2, true, return gd::dict_value(enemy_adventure_rules::_find_player_hero(s, D(a, 0), S(a, 1)))),
	CHECK(EnemyAdventureRules, _find_town_by_placement, 2, true, return gd::dict_value(enemy_adventure_rules::_find_town_by_placement(s, D(a, 0), S(a, 1)))),
	CHECK(EnemyAdventureRules, _known_player_hero_snapshot_for_ai, 3, true, return gd::dict_value(enemy_adventure_rules::_known_player_hero_snapshot_for_ai(s, D(a, 0), S(a, 1), D(a, 2)))),
	CHECK(EnemyAdventureRules, _known_player_hero_strength, 1, true, return gd::int_value(enemy_adventure_rules::_known_player_hero_strength(s, D(a, 0)))),
	CHECK(EnemyAdventureRules, _merge_strategy_dict, 2, true, return gd::dict_value(enemy_adventure_rules::_merge_strategy_dict(s, D(a, 0), D(a, 1)))),
	CHECK(EnemyAdventureRules, _player_hero_goal_tile, 1, true, const overworld_rules::Vector2i v = enemy_adventure_rules::_player_hero_goal_tile(s, D(a, 0)); return Value::of_vector2i(v.x, v.y)),
	CHECK(EnemyAdventureRules, _player_hero_snapshots_for_intercept, 2, true, return gd::array_value(enemy_adventure_rules::_player_hero_snapshots_for_intercept(s, D(a, 0), B(a, 1)))),
	CHECK(EnemyAdventureRules, _preferred_commander_index_for_encounter, 1, true, return gd::int_value(enemy_adventure_rules::_preferred_commander_index_for_encounter(s, D(a, 0)))),
	CHECK(EnemyAdventureRules, _secure_native_passage_target, 6, true, return gd::dict_value(enemy_adventure_rules::_secure_native_passage_target(s, D(a, 0), D(a, 1), D(a, 2), S(a, 3), D(a, 4), B(a, 5)))),
	CHECK(EnemyAdventureRules, _town_controller_faction_id, 1, true, return gd::str(enemy_adventure_rules::_town_controller_faction_id(s, D(a, 0)))),
	CHECK(EnemyAdventureRules, commander_can_deploy, 1, true, return gd::bool_value(enemy_adventure_rules::commander_can_deploy(s, X(a, 0)))),
	CHECK(EnemyAdventureRules, commander_recent_outcome_brief, 1, true, return gd::str(enemy_adventure_rules::commander_recent_outcome_brief(s, X(a, 0)))),
	CHECK(EnemyAdventureRules, enemy_strategy, 2, true, return gd::dict_value(enemy_adventure_rules::enemy_strategy(s, D(a, 0), S(a, 1)))),
	CHECK(EnemyAdventureRules, occupied_raid_commander_ids, 3, true, return gd::dict_value(enemy_adventure_rules::occupied_raid_commander_ids(s, D(a, 0), S(a, 1), S(a, 2)))),
	CHECK(EnemyAdventureRules, raid_display_name, 1, true, return gd::str(enemy_adventure_rules::raid_display_name(s, D(a, 0)))),
	CHECK(EnemyAdventureRules, raid_strength, 1, true, return gd::int_value(enemy_adventure_rules::raid_strength(s, D(a, 0)))),
	CHECK(EnemyAdventureRules, select_raid_commander_roster_hero_id, 5, true, return gd::str(enemy_adventure_rules::select_raid_commander_roster_hero_id(s, D(a, 0), S(a, 1), I(a, 2), D(a, 3), X(a, 4)))),
	CHECK(EnemyAdventureRules, strategy_int, 4, true, return gd::int_value(enemy_adventure_rules::strategy_int(s, D(a, 0), S(a, 1), S(a, 2), I(a, 3)))),
	CHECK(EnemyAdventureRules, strategy_scalar, 4, true, return gd::float_value(enemy_adventure_rules::strategy_scalar(s, D(a, 0), S(a, 1), S(a, 2), F(a, 3)))),
	CHECK(EnemyAdventureRules, target_is_objective_anchor, 3, true, return gd::bool_value(enemy_adventure_rules::target_is_objective_anchor(s, D(a, 0), S(a, 1), S(a, 2)))),
	CHECK(EnemyAdventureRules, _town_is_objective_anchor, 2, true, return gd::bool_value(enemy_adventure_rules::_town_is_objective_anchor(s, D(a, 0), S(a, 1)))),
	// EnemyTownServices
	CHECK(EnemyTownServices, apply_ai_weights, 1, true, enemy_town_services::apply_ai_weights(s, D(a, 0)); return nil()),
	CHECK(EnemyTownServices, can_visit, 3, true, return gd::bool_value(enemy_town_services::can_visit(s, D(a, 0), D(a, 1), S(a, 2)))),
	CHECK(EnemyTownServices, upgrade_stacks, 3, true, return gd::dict_value(enemy_town_services::upgrade_stacks(s, D(a, 0), A(a, 1), D(a, 2)))),
	CHECK(EnemyTownServices, visit, 5, true, return gd::dict_value(enemy_town_services::visit(s, D(a, 0), D(a, 1), D(a, 2), I(a, 3), S(a, 4)))),
	CHECK(EnemyTownServices, best_equipment, 2, true, return gd::dict_value(enemy_town_services::best_equipment(s, D(a, 0), S(a, 1)))),
	CHECK(EnemyTownServices, loadout_value, 1, true, return gd::float_value(enemy_town_services::loadout_value(s, D(a, 0)))),
	// EnemyTurnRules
	CHECK(EnemyTurnRules, _append_event_records, 2, true, enemy_turn_rules::_append_event_records(s, A(a, 0), X(a, 1)); return nil()),
	CHECK(EnemyTurnRules, _apply_discount, 2, true, return gd::dict_value(enemy_turn_rules::_apply_discount(s, X(a, 0), I(a, 1)))),
	CHECK(EnemyTurnRules, _apply_weekly_musters, 5, true, return gd::str(enemy_turn_rules::_apply_weekly_musters(s, D(a, 0), A(a, 1), A(a, 2), S(a, 3), D(a, 4)))),
	CHECK(EnemyTurnRules, _building_growth_payload, 1, true, return gd::dict_value(enemy_turn_rules::_building_growth_payload(s, S(a, 0)))),
	CHECK(EnemyTurnRules, _consume_recruits, 3, true, return gd::dict_value(enemy_turn_rules::_consume_recruits(s, X(a, 0), S(a, 1), I(a, 2)))),
	CHECK(EnemyTurnRules, _describe_recruit_delta, 1, true, return gd::str(enemy_turn_rules::_describe_recruit_delta(s, X(a, 0)))),
	CHECK(EnemyTurnRules, _discount_from_profile, 2, true, return gd::int_value(enemy_turn_rules::_discount_from_profile(s, X(a, 0), S(a, 1)))),
	CHECK(EnemyTurnRules, _enemy_recruit_cost, 2, true, return gd::dict_value(enemy_turn_rules::_enemy_recruit_cost(s, D(a, 0), S(a, 1)))),
	CHECK(EnemyTurnRules, _enemy_town_accessible_spell_ids, 1, true, return gd::array_value(enemy_turn_rules::_enemy_town_accessible_spell_ids(s, D(a, 0)))),
	CHECK(EnemyTurnRules, _enemy_turn_profile_enabled, 0, true, return gd::bool_value(enemy_turn_rules::_enemy_turn_profile_enabled(s))),
	CHECK(EnemyTurnRules, _enemy_turn_result, 5, true, return gd::dict_value(enemy_turn_rules::_enemy_turn_result(s, B(a, 0), S(a, 1), A(a, 2), B(a, 3), D(a, 4)))),
	CHECK(EnemyTurnRules, _find_state_index, 2, true, return gd::int_value(enemy_turn_rules::_find_state_index(s, X(a, 0), S(a, 1)))),
	CHECK(EnemyTurnRules, _latest_enemy_state, 3, true, return gd::dict_value(enemy_turn_rules::_latest_enemy_state(s, D(a, 0), S(a, 1), D(a, 2)))),
	CHECK(EnemyTurnRules, _merge_recruits, 2, true, return gd::dict_value(enemy_turn_rules::_merge_recruits(s, X(a, 0), X(a, 1)))),
	CHECK(EnemyTurnRules, _normalized_built_buildings, 1, true, return gd::array_value(enemy_turn_rules::_normalized_built_buildings(s, D(a, 0)))),
	CHECK(EnemyTurnRules, _owned_town_count, 2, true, return gd::int_value(enemy_turn_rules::_owned_town_count(s, D(a, 0), S(a, 1)))),
	CHECK(EnemyTurnRules, _profile_add_ms, 3, true, enemy_turn_rules::_profile_add_ms(s, D(a, 0), S(a, 1), I(a, 2)); return nil()),
	CHECK(EnemyTurnRules, _recruitment_discount_percent, 2, true, return gd::int_value(enemy_turn_rules::_recruitment_discount_percent(s, D(a, 0), S(a, 1)))),
	CHECK(EnemyTurnRules, _scale_resource_pool, 2, true, return gd::dict_value(enemy_turn_rules::_scale_resource_pool(s, X(a, 0), I(a, 1)))),
	CHECK(EnemyTurnRules, _spend_from_pool, 2, true, enemy_turn_rules::_spend_from_pool(s, D(a, 0), X(a, 1)); return nil()),
	CHECK(EnemyTurnRules, _town_actor, 1, true, return gd::dict_value(enemy_turn_rules::_town_actor(s, D(a, 0)))),
	CHECK(EnemyTurnRules, _town_name, 1, true, return gd::str(enemy_turn_rules::_town_name(s, D(a, 0)))),
	CHECK(EnemyTurnRules, ai_town_build_event, 4, true, return gd::dict_value(enemy_turn_rules::ai_town_build_event(s, D(a, 0), D(a, 1), D(a, 2), D(a, 3)))),
	CHECK(EnemyTurnRules, ai_town_recruit_event, 4, true, return gd::dict_value(enemy_turn_rules::ai_town_recruit_event(s, D(a, 0), D(a, 1), D(a, 2), D(a, 3)))),
	PORT(EnemyTurnRules, run_enemy_turn, 2, true, return gd::dict_value(enemy_turn_rules::run_enemy_turn(s, D(a, 0), B(a, 1)))),
	CHECK(EnemyTurnRules, _append_building_with_requirements, 3, true, enemy_turn_rules::_append_building_with_requirements(s, A(a, 0), S(a, 1), A(a, 2)); return nil()),
	CHECK(EnemyTurnRules, _config_was_runtime_defaulted, 2, true, return gd::bool_value(enemy_turn_rules::_config_was_runtime_defaulted(s, D(a, 0), D(a, 1)))),
	CHECK(EnemyTurnRules, _faction_capital_state, 2, true, return gd::dict_value(enemy_turn_rules::_faction_capital_state(s, D(a, 0), S(a, 1)))),
	CHECK(EnemyTurnRules, _faction_capital_state_from_towns, 3, true, return gd::dict_value(enemy_turn_rules::_faction_capital_state_from_towns(s, D(a, 0), A(a, 1), S(a, 2)))),
	CHECK(EnemyTurnRules, _faction_front_state, 2, true, return gd::dict_value(enemy_turn_rules::_faction_front_state(s, D(a, 0), S(a, 1)))),
	CHECK(EnemyTurnRules, _hero_task_record_sanitized_field_count, 1, true, return gd::int_value(enemy_turn_rules::_hero_task_record_sanitized_field_count(s, D(a, 0)))),
	CHECK(EnemyTurnRules, _hero_task_state_board_sanitized_field_count, 1, true, return gd::int_value(enemy_turn_rules::_hero_task_state_board_sanitized_field_count(s, D(a, 0)))),
	CHECK(EnemyTurnRules, _launch_policy_capital_state, 3, true, return gd::dict_value(enemy_turn_rules::_launch_policy_capital_state(s, D(a, 0), S(a, 1), D(a, 2)))),
	CHECK(EnemyTurnRules, _launch_policy_front_state, 3, true, return gd::dict_value(enemy_turn_rules::_launch_policy_front_state(s, D(a, 0), S(a, 1), D(a, 2)))),
	CHECK(EnemyTurnRules, _max_active_raids_for_strategy, 4, true, return gd::int_value(enemy_turn_rules::_max_active_raids_for_strategy(s, D(a, 0), D(a, 1), S(a, 2), D(a, 3)))),
	CHECK(EnemyTurnRules, _normalize_hero_task_actor_kind, 1, true, return gd::str(enemy_turn_rules::_normalize_hero_task_actor_kind(s, X(a, 0)))),
	CHECK(EnemyTurnRules, _normalize_hero_task_class, 1, true, return gd::str(enemy_turn_rules::_normalize_hero_task_class(s, X(a, 0)))),
	CHECK(EnemyTurnRules, _normalize_hero_task_continuity_policy, 1, true, return gd::str(enemy_turn_rules::_normalize_hero_task_continuity_policy(s, X(a, 0)))),
	CHECK(EnemyTurnRules, _normalize_hero_task_origin_kind, 1, true, return gd::str(enemy_turn_rules::_normalize_hero_task_origin_kind(s, X(a, 0)))),
	CHECK(EnemyTurnRules, _normalize_hero_task_record, 1, true, return gd::dict_value(enemy_turn_rules::_normalize_hero_task_record(s, X(a, 0)))),
	CHECK(EnemyTurnRules, _normalize_hero_task_reservation, 1, true, return gd::dict_value(enemy_turn_rules::_normalize_hero_task_reservation(s, X(a, 0)))),
	CHECK(EnemyTurnRules, _normalize_hero_task_route_policy, 1, true, return gd::str(enemy_turn_rules::_normalize_hero_task_route_policy(s, X(a, 0)))),
	CHECK(EnemyTurnRules, _normalize_hero_task_source_kind, 1, true, return gd::str(enemy_turn_rules::_normalize_hero_task_source_kind(s, X(a, 0)))),
	CHECK(EnemyTurnRules, _normalize_hero_task_status, 1, true, return gd::str(enemy_turn_rules::_normalize_hero_task_status(s, X(a, 0)))),
	CHECK(EnemyTurnRules, _normalize_hero_task_target_kind, 1, true, return gd::str(enemy_turn_rules::_normalize_hero_task_target_kind(s, X(a, 0)))),
	CHECK(EnemyTurnRules, _normalize_hero_task_validation_code, 1, true, return gd::str(enemy_turn_rules::_normalize_hero_task_validation_code(s, X(a, 0)))),
	CHECK(EnemyTurnRules, _raid_threshold_for_strategy, 4, true, return gd::int_value(enemy_turn_rules::_raid_threshold_for_strategy(s, D(a, 0), D(a, 1), S(a, 2), D(a, 3)))),
	CHECK(EnemyTurnRules, _valid_enemy_faction_configs, 1, true, return gd::array_value(enemy_turn_rules::_valid_enemy_faction_configs(s, A(a, 0)))),
	CHECK(EnemyTurnRules, active_raid_count, 2, true, return gd::int_value(enemy_turn_rules::active_raid_count(s, D(a, 0), S(a, 1)))),
	CHECK(EnemyTurnRules, get_pressure, 2, true, return gd::int_value(enemy_turn_rules::get_pressure(s, D(a, 0), S(a, 1)))),
	CHECK(EnemyTurnRules, normalize_optional_hero_task_state, 1, true, return gd::dict_value(enemy_turn_rules::normalize_optional_hero_task_state(s, X(a, 0)))),
	// FactionTownServices
	CHECK(FactionTownServices, apply_ai_weights, 1, true, faction_town_services::apply_ai_weights(s, D(a, 0)); return nil()),
	CHECK(FactionTownServices, perform, 5, true, return gd::dict_value(faction_town_services::perform(s, D(a, 0), D(a, 1), D(a, 2), I(a, 3), D(a, 4)))),
	CHECK(FactionTownServices, recruit_reward, 2, true, return gd::dict_value(faction_town_services::recruit_reward(s, D(a, 0), D(a, 1)))),
	CHECK(FactionTownServices, unavailable_reason, 5, true, return gd::str(faction_town_services::unavailable_reason(s, D(a, 0), D(a, 1), D(a, 2), I(a, 3), D(a, 4)))),
	CHECK(FactionTownServices, useful_to_ai, 5, true, return gd::bool_value(faction_town_services::useful_to_ai(s, D(a, 0), D(a, 1), D(a, 2), I(a, 3), D(a, 4)))),
	CHECK(FactionTownServices, week, 1, true, return gd::int_value(faction_town_services::week(s, I(a, 0)))),
	// HeroCommandRules
	CHECK(HeroCommandRules, _faction_creatures, 2, true, return gd::array_value(hero_command_rules::_faction_creatures(s, S(a, 0), I(a, 1)))),
	CHECK(HeroCommandRules, _normalize_resources, 1, true, return gd::dict_value(hero_command_rules::_normalize_resources(s, X(a, 0)))),
	CHECK(HeroCommandRules, _seeded_rng, 1, true, return hero_command_rules::_seeded_rng(s, S(a, 0))),
	CHECK(HeroCommandRules, _stack_slot_less, 2, true, return gd::bool_value(hero_command_rules::_stack_slot_less(s, D(a, 0), D(a, 1)))),
	CHECK(HeroCommandRules, _starting_company_size, 3, true, return gd::int_value(hero_command_rules::_starting_company_size(s, X(a, 0), S(a, 1), A(a, 2)))),
	CHECK(HeroCommandRules, army_addition_split, 2, true, return gd::dict_value(hero_command_rules::army_addition_split(s, X(a, 0), D(a, 1)))),
	CHECK(HeroCommandRules, build_recruited_hero, 7, true, return gd::dict_value(hero_command_rules::build_recruited_hero(s, D(a, 0), D(a, 1), X(a, 2), I(a, 3), X(a, 4), S(a, 5), S(a, 6)))),
	CHECK(HeroCommandRules, hero_recruit_cost, 1, true, return gd::dict_value(hero_command_rules::hero_recruit_cost(s, D(a, 0)))),
	CHECK(HeroCommandRules, scout_row_half_width, 2, true, return gd::int_value(hero_command_rules::scout_row_half_width(s, I(a, 0), I(a, 1)))),
	CHECK(HeroCommandRules, starting_army_for_hero, 2, true, return gd::dict_value(hero_command_rules::starting_army_for_hero(s, D(a, 0), S(a, 1)))),
	CHECK(HeroCommandRules, tavern_offer, 3, true, return gd::dict_value(hero_command_rules::tavern_offer(s, D(a, 0), S(a, 1), I(a, 2)))),
	CHECK(HeroCommandRules, tavern_week, 1, true, return gd::int_value(hero_command_rules::tavern_week(s, D(a, 0)))),
	CHECK(HeroCommandRules, town_has_hall, 1, true, return gd::bool_value(hero_command_rules::town_has_hall(s, D(a, 0)))),
	CHECK(HeroCommandRules, _holder_stacks, 3, true, return gd::array_value(hero_command_rules::_holder_stacks(s, D(a, 0), D(a, 1), S(a, 2)))),
	CHECK(HeroCommandRules, merge_stacks_into_army, 2, true, return gd::array_value(hero_command_rules::merge_stacks_into_army(s, A(a, 0), A(a, 1)))),
	CHECK(HeroCommandRules, set_active_hero, 2, true, return gd::dict_value(hero_command_rules::set_active_hero(s, D(a, 0), S(a, 1)))),
	// HeroProgressionRules
	CHECK(HeroProgressionRules, _add_experience, 2, true, return gd::dict_value(hero_progression_rules::_add_experience(s, D(a, 0), I(a, 1)))),
	CHECK(HeroProgressionRules, _apply_command_gain, 2, true, return gd::dict_value(hero_progression_rules::_apply_command_gain(s, X(a, 0), S(a, 1)))),
	CHECK(HeroProgressionRules, _enqueue_choice_group, 2, true, return gd::dict_value(hero_progression_rules::_enqueue_choice_group(s, D(a, 0), I(a, 1)))),
	CHECK(HeroProgressionRules, add_experience, 2, true, return gd::dict_value(hero_progression_rules::add_experience(s, D(a, 0), I(a, 1)))),
	CHECK(HeroProgressionRules, advance_to_level, 2, true, return gd::dict_value(hero_progression_rules::advance_to_level(s, D(a, 0), I(a, 1)))),
	CHECK(HeroProgressionRules, command_gain_stat, 2, true, return gd::str(hero_progression_rules::command_gain_stat(s, D(a, 0), I(a, 1)))),
	CHECK(HeroProgressionRules, experience_for_level, 1, true, return gd::int_value(hero_progression_rules::experience_for_level(s, I(a, 0)))),
	CHECK(HeroProgressionRules, experience_with_bonus, 2, true, return gd::int_value(hero_progression_rules::experience_with_bonus(s, D(a, 0), I(a, 1)))),
	CHECK(HeroProgressionRules, pending_choice_summary, 1, true, return gd::str(hero_progression_rules::pending_choice_summary(s, D(a, 0)))),
	CHECK(HeroProgressionRules, pending_choices_remaining, 1, true, return gd::int_value(hero_progression_rules::pending_choices_remaining(s, D(a, 0)))),
	CHECK(HeroProgressionRules, rank_label, 1, true, return gd::str(hero_progression_rules::rank_label(s, I(a, 0)))),
	CHECK(HeroProgressionRules, scale_recruit_growth, 2, true, return gd::dict_value(hero_progression_rules::scale_recruit_growth(s, D(a, 0), X(a, 1)))),
	// NativeTransitRules
	CHECK(NativeTransitRules, resolve, 3, true, return gd::dict_value(native_transit_rules::resolve(s, A(a, 0), D(a, 1), S(a, 2)))),
	CHECK(NativeTransitRules, exit_order, 2, true, return gd::array_value(native_transit_rules::exit_order(s, D(a, 0), S(a, 1)))),
	// OverworldLevelRules
	CHECK(OverworldLevelRules, view_level, 1, true, return gd::int_value(overworld_level_rules::view_level(s, X(a, 0)))),
	// OverworldRules
	CHECK(OverworldRules, _add_dwelling_town_growth, 3, true, return gd::dict_value(overworld_rules::_add_dwelling_town_growth(s, D(a, 0), D(a, 1), D(a, 2)))),
	CHECK(OverworldRules, _apply_recruit_percent, 2, true, return gd::dict_value(overworld_rules::_apply_recruit_percent(s, X(a, 0), I(a, 1)))),
	CHECK(OverworldRules, _blocked_tile_index, 2, true, return gd::dict_value(overworld_rules::_blocked_tile_index(s, D(a, 0), I(a, 1)))),
	CHECK(OverworldRules, _native_passage_endpoint_safety, 5, true, return gd::dict_value(overworld_rules::_native_passage_endpoint_safety(s, D(a, 0), D(a, 1), S(a, 2), X(a, 3), B(a, 4)))),
	CHECK(OverworldRules, _rules_profile_add_ms, 2, true, overworld_rules::_rules_profile_add_ms(s, S(a, 0), I(a, 1)); return nil()),
	CHECK(OverworldRules, _rules_profile_set, 3, true, overworld_rules::_rules_profile_set(s, S(a, 0), S(a, 1), X(a, 2)); return nil()),
	CHECK(OverworldRules, _terrain_id_at, 4, true, return gd::str(overworld_rules::_terrain_id_at(s, D(a, 0), I(a, 1), I(a, 2), I(a, 3)))),
	CHECK(OverworldRules, _town_front_after_control_change, 6, true, return gd::dict_value(overworld_rules::_town_front_after_control_change(s, D(a, 0), D(a, 1), S(a, 2), S(a, 3), S(a, 4), S(a, 5)))),
	CHECK(OverworldRules, _town_front_stabilize_days, 2, true, return gd::int_value(overworld_rules::_town_front_stabilize_days(s, D(a, 0), D(a, 1)))),
	CHECK(OverworldRules, _town_front_stabilizing_state, 6, true, return gd::dict_value(overworld_rules::_town_front_stabilizing_state(s, D(a, 0), D(a, 1), S(a, 2), S(a, 3), S(a, 4), I(a, 5)))),
	CHECK(OverworldRules, _town_is_objective_anchor, 2, true, return gd::bool_value(overworld_rules::_town_is_objective_anchor(s, D(a, 0), S(a, 1)))),
	CHECK(OverworldRules, _town_occupation_after_control_change, 6, true, return gd::dict_value(overworld_rules::_town_occupation_after_control_change(s, D(a, 0), D(a, 1), S(a, 2), S(a, 3), S(a, 4), S(a, 5)))),
	CHECK(OverworldRules, _town_weekly_growth, 3, true, return gd::dict_value(overworld_rules::_town_weekly_growth(s, D(a, 0), X(a, 1), D(a, 2)))),
	CHECK(OverworldRules, invalidate_spatial_lookup, 1, true, overworld_rules::invalidate_spatial_lookup(s, D(a, 0)); return nil()),
	CHECK(OverworldRules, is_tile_explored, 4, true, return gd::bool_value(overworld_rules::is_tile_explored(s, D(a, 0), I(a, 1), I(a, 2), I(a, 3)))),
	CHECK(OverworldRules, map_for_level, 2, true, return gd::array_value(overworld_rules::map_for_level(s, D(a, 0), I(a, 1)))),
	CHECK(OverworldRules, native_passage_travel_check, 6, true, return gd::dict_value(overworld_rules::native_passage_travel_check(s, D(a, 0), D(a, 1), X(a, 2), S(a, 3), S(a, 4), B(a, 5)))),
	CHECK(OverworldRules, placement_level, 3, true, return gd::int_value(overworld_rules::placement_level(s, D(a, 0), S(a, 1), I(a, 2)))),
	CHECK(OverworldRules, town_weekly_growth, 2, true, return gd::dict_value(overworld_rules::town_weekly_growth(s, D(a, 0), X(a, 1)))),
	CHECK(OverworldRules, transition_town_control, 5, true, return gd::dict_value(overworld_rules::transition_town_control(s, D(a, 0), S(a, 1), S(a, 2), S(a, 3), S(a, 4)))),
	CHECK(OverworldRules, native_exit_roll_key, 3, true, return gd::str(overworld_rules::native_exit_roll_key(s, D(a, 0), D(a, 1), S(a, 2)))),
	CHECK(OverworldRules, native_random_exit_check, 4, true, return gd::dict_value(overworld_rules::native_random_exit_check(s, D(a, 0), D(a, 1), X(a, 2), S(a, 3)))),
	CHECK(OverworldRules, note_native_trip, 2, true, overworld_rules::note_native_trip(s, D(a, 0), S(a, 1)); return nil()),
	CHECK(OverworldRules, town_capital_project_state, 2, true, return gd::dict_value(overworld_rules::town_capital_project_state(s, D(a, 0), X(a, 1)))),
	CHECK(OverworldRules, town_logistics_support_radius, 2, true, return gd::int_value(overworld_rules::town_logistics_support_radius(s, D(a, 0), D(a, 1)))),
	CHECK(OverworldRules, town_recovery_state, 2, true, return gd::dict_value(overworld_rules::town_recovery_state(s, D(a, 0), D(a, 1)))),
	CHECK(OverworldRules, apply_town_recovery_pressure, 4, true, return gd::str(overworld_rules::apply_town_recovery_pressure(s, D(a, 0), S(a, 1), I(a, 2), S(a, 3)))),
	CHECK(OverworldRules, apply_resource_site_disruption, 5, true, return gd::str(overworld_rules::apply_resource_site_disruption(s, D(a, 0), D(a, 1), D(a, 2), S(a, 3), S(a, 4)))),
	CHECK(OverworldRules, _lock_town_occupation_reserves, 2, true, overworld_rules::_lock_town_occupation_reserves(s, D(a, 0), D(a, 1)); return nil()),
	CHECK(OverworldRules, _release_town_occupation_reserves, 1, true, return gd::dict_value(overworld_rules::_release_town_occupation_reserves(s, D(a, 0)))),
	CHECK(OverworldRules, _town_scaling_hero, 2, true, return gd::dict_value(overworld_rules::_town_scaling_hero(s, D(a, 0), D(a, 1)))),
	CHECK(OverworldRules, _effective_player_town_weekly_growth, 2, true, return gd::dict_value(overworld_rules::_effective_player_town_weekly_growth(s, D(a, 0), D(a, 1)))),
	CHECK(OverworldRules, _build_scenario_resource_states, 1, true, return gd::array_value(overworld_rules::_build_scenario_resource_states(s, X(a, 0)))),
	CHECK(OverworldRules, _build_scenario_town_states, 1, true, return gd::array_value(overworld_rules::_build_scenario_town_states(s, X(a, 0)))),
	CHECK(OverworldRules, _command_risk_encounter_objective_item, 3, true, return gd::dict_value(overworld_rules::_command_risk_encounter_objective_item(s, D(a, 0), D(a, 1), B(a, 2)))),
	CHECK(OverworldRules, _command_risk_pressure_objective_item, 4, true, return gd::dict_value(overworld_rules::_command_risk_pressure_objective_item(s, D(a, 0), D(a, 1), D(a, 2), B(a, 3)))),
	CHECK(OverworldRules, _delivery_encounter_matches_node, 4, true, return gd::bool_value(overworld_rules::_delivery_encounter_matches_node(s, D(a, 0), D(a, 1), D(a, 2), D(a, 3)))),
	CHECK(OverworldRules, _enemy_active_raids, 2, true, return gd::int_value(overworld_rules::_enemy_active_raids(s, D(a, 0), S(a, 1)))),
	CHECK(OverworldRules, _enemy_config_for_faction, 2, true, return gd::dict_value(overworld_rules::_enemy_config_for_faction(s, D(a, 0), S(a, 1)))),
	CHECK(OverworldRules, _enemy_max_active_raids_for_strategy, 3, true, return gd::int_value(overworld_rules::_enemy_max_active_raids_for_strategy(s, D(a, 0), D(a, 1), S(a, 2)))),
	CHECK(OverworldRules, _enemy_pressure, 2, true, return gd::int_value(overworld_rules::_enemy_pressure(s, D(a, 0), S(a, 1)))),
	CHECK(OverworldRules, _enemy_raid_threshold_for_strategy, 3, true, return gd::int_value(overworld_rules::_enemy_raid_threshold_for_strategy(s, D(a, 0), D(a, 1), S(a, 2)))),
	CHECK(OverworldRules, _find_active_town, 1, true, return gd::dict_value(overworld_rules::_find_active_town(s, D(a, 0)))),
	CHECK(OverworldRules, _find_active_town_by_visit_context, 1, true, return gd::dict_value(overworld_rules::_find_active_town_by_visit_context(s, D(a, 0)))),
	CHECK(OverworldRules, _posture_label, 1, true, return gd::str(overworld_rules::_posture_label(s, S(a, 0)))),
	CHECK(OverworldRules, _pressure_bonus_from_profile, 1, true, return gd::int_value(overworld_rules::_pressure_bonus_from_profile(s, X(a, 0)))),
	CHECK(OverworldRules, _public_enemy_pressure_gain, 2, true, return gd::int_value(overworld_rules::_public_enemy_pressure_gain(s, D(a, 0), D(a, 1)))),
	CHECK(OverworldRules, _raid_target_is_objective_anchor, 3, true, return gd::bool_value(overworld_rules::_raid_target_is_objective_anchor(s, D(a, 0), S(a, 1), S(a, 2)))),
	CHECK(OverworldRules, _resource_site_delivery_interception, 3, true, return gd::dict_value(overworld_rules::_resource_site_delivery_interception(s, D(a, 0), D(a, 1), D(a, 2)))),
	CHECK(OverworldRules, _resource_site_response_profile, 1, true, return gd::dict_value(overworld_rules::_resource_site_response_profile(s, D(a, 0)))),
	CHECK(OverworldRules, _route_security_rating_for_hero, 1, true, return gd::int_value(overworld_rules::_route_security_rating_for_hero(s, D(a, 0)))),
	CHECK(OverworldRules, _scenario_objective_met, 2, true, return gd::bool_value(overworld_rules::_scenario_objective_met(s, D(a, 0), D(a, 1)))),
	CHECK(OverworldRules, _terrain_name_at, 3, true, return gd::str(overworld_rules::_terrain_name_at(s, D(a, 0), I(a, 1), I(a, 2)))),
	CHECK(OverworldRules, _town_command_risk_consequence, 6, true, return gd::str(overworld_rules::_town_command_risk_consequence(s, D(a, 0), I(a, 1), D(a, 2), D(a, 3), D(a, 4), B(a, 5)))),
	CHECK(OverworldRules, _town_defense_summary, 1, true, return gd::str(overworld_rules::_town_defense_summary(s, D(a, 0)))),
	CHECK(OverworldRules, _town_pressure_output, 4, true, return gd::int_value(overworld_rules::_town_pressure_output(s, D(a, 0), X(a, 1), D(a, 2), I(a, 3)))),
	CHECK(OverworldRules, _town_role_pressure_bonus, 1, true, return gd::int_value(overworld_rules::_town_role_pressure_bonus(s, S(a, 0)))),
	CHECK(OverworldRules, encounter_commander_name, 1, true, return gd::str(overworld_rules::encounter_commander_name(s, D(a, 0)))),
	CHECK(OverworldRules, encounter_commander_threat_label, 1, true, return gd::str(overworld_rules::encounter_commander_threat_label(s, D(a, 0)))),
	CHECK(OverworldRules, encounter_display_name, 1, true, return gd::str(overworld_rules::encounter_display_name(s, D(a, 0)))),
	CHECK(OverworldRules, town_development_metrics, 2, true, return gd::dict_value(overworld_rules::town_development_metrics(s, D(a, 0), X(a, 1)))),
	// OverworldTurnPlayback
	CHECK(OverworldTurnPlayback, action, 3, true, overworld_turn_playback::action(s, X(a, 0), D(a, 1), S(a, 2)); return nil()),
	CHECK(OverworldTurnPlayback, move, 3, true, overworld_turn_playback::move(s, X(a, 0), D(a, 1), D(a, 2)); return nil()),
	CHECK(OverworldTurnPlayback, player_turn, 2, true, overworld_turn_playback::player_turn(s, X(a, 0), D(a, 1)); return nil()),
	CHECK(OverworldTurnPlayback, _actor_name, 1, true, return gd::str(overworld_turn_playback::_actor_name(s, D(a, 0)))),
	CHECK(OverworldTurnPlayback, _visual_actor, 2, true, return gd::dict_value(overworld_turn_playback::_visual_actor(s, D(a, 0), D(a, 1)))),
	CHECK(OverworldTurnPlayback, visible, 2, true, return gd::bool_value(overworld_turn_playback::visible(s, X(a, 0), D(a, 1)))),
	// PlayerIdentityRules
	CHECK(PlayerIdentityRules, set_resource_controller, 3, true, player_identity_rules::set_resource_controller(s, D(a, 0), X(a, 1), S(a, 2)); return nil()),
	CHECK(PlayerIdentityRules, config_for_controller, 2, true, return gd::dict_value(player_identity_rules::config_for_controller(s, X(a, 0), S(a, 1)))),
	// ResourceNodePayloadRules
	CHECK(ResourceNodePayloadRules, mark_claimed, 2, true, resource_node_payload_rules::mark_claimed(s, D(a, 0), D(a, 1)); return nil()),
	// ScenarioFactory
	CHECK(ScenarioFactory, _build_resource_states, 1, true, return gd::array_value(scenario_factory::_build_resource_states(s, X(a, 0)))),
	CHECK(ScenarioFactory, _build_town_states, 1, true, return gd::array_value(scenario_factory::_build_town_states(s, X(a, 0)))),
	CHECK(ScenarioFactory, _copy_resource_runtime_metadata, 2, true, scenario_factory::_copy_resource_runtime_metadata(s, D(a, 0), D(a, 1)); return nil()),
	CHECK(ScenarioFactory, _duplicate_dict, 1, true, return gd::dict_value(scenario_factory::_duplicate_dict(s, X(a, 0)))),
	// ScenarioRules
	CHECK(ScenarioRules, _army_unit_count, 2, true, return gd::int_value(scenario_rules::_army_unit_count(s, D(a, 0), S(a, 1)))),
	CHECK(ScenarioRules, _artifact_set_equipment_progress, 2, true, return gd::dict_value(scenario_rules::_artifact_set_equipment_progress(s, D(a, 0), D(a, 1)))),
	CHECK(ScenarioRules, _controlled_hero_army, 2, true, return gd::dict_value(scenario_rules::_controlled_hero_army(s, D(a, 0), S(a, 1)))),
	CHECK(ScenarioRules, _controlled_hero_state, 2, true, return gd::dict_value(scenario_rules::_controlled_hero_state(s, D(a, 0), S(a, 1)))),
	CHECK(ScenarioRules, _find_town, 2, true, return gd::dict_value(scenario_rules::_find_town(s, D(a, 0), D(a, 1)))),
	CHECK(ScenarioRules, _hero_army_requirement_progress, 2, true, return gd::dict_value(scenario_rules::_hero_army_requirement_progress(s, D(a, 0), D(a, 1)))),
	CHECK(ScenarioRules, _hero_progression_requirement_progress, 2, true, return gd::dict_value(scenario_rules::_hero_progression_requirement_progress(s, D(a, 0), D(a, 1)))),
	CHECK(ScenarioRules, _hero_stationing_progress, 2, true, return gd::dict_value(scenario_rules::_hero_stationing_progress(s, D(a, 0), D(a, 1)))),
	CHECK(ScenarioRules, _map_exploration_progress, 2, true, return gd::dict_value(scenario_rules::_map_exploration_progress(s, D(a, 0), D(a, 1)))),
	CHECK(ScenarioRules, _player_knows_spell, 2, true, return gd::bool_value(scenario_rules::_player_knows_spell(s, D(a, 0), S(a, 1)))),
	CHECK(ScenarioRules, _player_owns_artifact, 2, true, return gd::bool_value(scenario_rules::_player_owns_artifact(s, D(a, 0), S(a, 1)))),
	CHECK(ScenarioRules, _reserve_delivery_progress, 2, true, return gd::dict_value(scenario_rules::_reserve_delivery_progress(s, D(a, 0), D(a, 1)))),
	CHECK(ScenarioRules, _resource_site_control_progress, 2, true, return gd::dict_value(scenario_rules::_resource_site_control_progress(s, D(a, 0), D(a, 1)))),
	CHECK(ScenarioRules, _resource_stockpile_progress, 2, true, return gd::dict_value(scenario_rules::_resource_stockpile_progress(s, D(a, 0), D(a, 1)))),
	CHECK(ScenarioRules, _titleize_token, 1, true, return gd::str(scenario_rules::_titleize_token(s, S(a, 0)))),
	CHECK(ScenarioRules, _town_garrison_requirement_progress, 2, true, return gd::dict_value(scenario_rules::_town_garrison_requirement_progress(s, D(a, 0), D(a, 1)))),
	CHECK(ScenarioRules, _town_has_objective_building, 2, true, return gd::bool_value(scenario_rules::_town_has_objective_building(s, D(a, 0), S(a, 1)))),
	// ScenarioScriptRules
	CHECK(ScenarioScriptRules, _encounter_resolved, 2, true, return gd::bool_value(scenario_script_rules::_encounter_resolved(s, D(a, 0), S(a, 1)))),
	CHECK(ScenarioScriptRules, _hook_fired, 2, true, return gd::bool_value(scenario_script_rules::_hook_fired(s, D(a, 0), S(a, 1)))),
	CHECK(ScenarioScriptRules, build_script_state, 0, true, return gd::dict_value(scenario_script_rules::build_script_state(s))),
	// ScenarioSelectRules
	CHECK(ScenarioSelectRules, default_difficulty_id, 0, true, return gd::str(scenario_select_rules::default_difficulty_id(s))),
	CHECK(ScenarioSelectRules, normalize_difficulty, 1, true, return gd::str(scenario_select_rules::normalize_difficulty(s, X(a, 0)))),
	// SpellRules
	CHECK(SpellRules, build_spellbook, 1, true, return gd::dict_value(spell_rules::build_spellbook(s, D(a, 0)))),
	CHECK(SpellRules, learn_spell, 2, true, return gd::dict_value(spell_rules::learn_spell(s, D(a, 0), S(a, 1)))),
	CHECK(SpellRules, mana_state, 1, true, return gd::dict_value(spell_rules::mana_state(s, D(a, 0)))),
	// TownDevelopmentRules
	CHECK(TownDevelopmentRules, can_pay, 2, true, return gd::bool_value(town_development_rules::can_pay(s, D(a, 0), D(a, 1)))),
	CHECK(TownDevelopmentRules, construction_growth, 1, true, return gd::dict_value(town_development_rules::construction_growth(s, D(a, 0)))),
	CHECK(TownDevelopmentRules, train_hero, 3, true, return gd::dict_value(town_development_rules::train_hero(s, D(a, 0), D(a, 1), S(a, 2)))),
	CHECK(TownDevelopmentRules, upgrade_army, 4, true, return gd::dict_value(town_development_rules::upgrade_army(s, D(a, 0), A(a, 1), S(a, 2), D(a, 3)))),
	CHECK(TownDevelopmentRules, upgrade_cost, 3, true, return gd::dict_value(town_development_rules::upgrade_cost(s, S(a, 0), S(a, 1), I(a, 2)))),
	CHECK(TownDevelopmentRules, offers, 3, true, return gd::array_value(town_development_rules::offers(s, D(a, 0), I(a, 1), A(a, 2)))),
	CHECK(TownDevelopmentRules, price, 1, true, return gd::int_value(town_development_rules::price(s, D(a, 0)))),
	CHECK(TownDevelopmentRules, satisfies, 2, true, return gd::bool_value(town_development_rules::satisfies(s, A(a, 0), S(a, 1)))),
	CHECK(TownDevelopmentRules, trade_artifact, 7, true, return gd::dict_value(town_development_rules::trade_artifact(s, D(a, 0), D(a, 1), I(a, 2), S(a, 3), B(a, 4), D(a, 5), A(a, 6)))),
	// TownRules
	CHECK(TownRules, _school_spell_ids_for_town, 2, true, return gd::array_value(town_rules::_school_spell_ids_for_town(s, D(a, 0), I(a, 1)))),
	CHECK(TownRules, _town_spell_school_access, 1, true, return gd::array_value(town_rules::_town_spell_school_access(s, D(a, 0)))),
	CHECK(TownRules, accessible_spell_ids, 1, true, return gd::array_value(town_rules::accessible_spell_ids(s, D(a, 0)))),
	CHECK(TownRules, current_spell_tier, 1, true, return gd::int_value(town_rules::current_spell_tier(s, D(a, 0)))),
	CHECK(TownRules, spell_ids_through_tier, 2, true, return gd::array_value(town_rules::spell_ids_through_tier(s, D(a, 0), I(a, 1)))),
	// VisitBuildingRules
	CHECK(VisitBuildingRules, _thousands, 1, true, return gd::str(visit_building_rules::_thousands(s, I(a, 0)))),
	CHECK(VisitBuildingRules, effect_summary, 1, true, return gd::str(visit_building_rules::effect_summary(s, D(a, 0)))),
	CHECK(VisitBuildingRules, record_visit, 5, true, visit_building_rules::record_visit(s, D(a, 0), D(a, 1), S(a, 2), I(a, 3), S(a, 4)); return nil()),
	CHECK(VisitBuildingRules, _resource_text, 1, true, return gd::str(visit_building_rules::_resource_text(s, D(a, 0)))),
	// WaterTravelRules
	CHECK(WaterTravelRules, add_boat, 4, true, return gd::dict_value(water_travel_rules::add_boat(s, X(a, 0), V(a, 1), I(a, 2), S(a, 3)))),
	CHECK(WaterTravelRules, any_boat_at, 3, true, return gd::bool_value(water_travel_rules::any_boat_at(s, X(a, 0), V(a, 1), I(a, 2)))),
	CHECK(WaterTravelRules, boat_by_id, 2, true, return gd::dict_value(water_travel_rules::boat_by_id(s, X(a, 0), S(a, 1)))),
	CHECK(WaterTravelRules, build_boat, 2, true, return gd::str(water_travel_rules::build_boat(s, X(a, 0), D(a, 1)))),
	CHECK(WaterTravelRules, dock_blocker, 2, true, return gd::str(water_travel_rules::dock_blocker(s, X(a, 0), D(a, 1)))),
	CHECK(WaterTravelRules, free_boat_at, 3, true, return gd::dict_value(water_travel_rules::free_boat_at(s, X(a, 0), V(a, 1), I(a, 2)))),
	CHECK(WaterTravelRules, hero_at, 3, true, return gd::bool_value(water_travel_rules::hero_at(s, X(a, 0), V(a, 1), I(a, 2)))),
	CHECK(WaterTravelRules, place_boat, 5, true, water_travel_rules::place_boat(s, X(a, 0), S(a, 1), S(a, 2), V(a, 3), I(a, 4)); return nil()),
	// END CHECKS
};

#undef CHECK
#undef PORT

// The start of a battle against a human stays GDScript. The ports call it
// through TurnEngine.host_call (turn_hosts.cpp), which a shadow check meets at
// the target's wrapper (TurnEngine.host_point). The battle preview is native
// (ai_battle_preview.cpp, Phase 2a).
#define HOST(script, fn, arity) { #script "." #fn, arity }
const Host kHosts[] = {
	{"TurnEngine.host_call", 3},
	{"TurnEngine.pure_host_call", 3, true},
	HOST(AiHeroRules, _start_player_battle, 6),
};
#undef HOST

} // namespace

// The AI turn port's table, listed in registry_tables.cpp. Its switches run
// the GDScript body on a path the port leaves to GDScript.
Table turn_table() {
	Table table{"HEROES_NATIVE_TURN_LOG", kFunctions, sizeof(kFunctions) / sizeof(kFunctions[0])};
	table.hosts = kHosts;
	table.host_count = sizeof(kHosts) / sizeof(kHosts[0]);
	table.fallback = true;
	return table;
}

} // namespace aurelion::rules::port
