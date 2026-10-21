#include "aurelion_rules/port/registry.hpp"

#include "aurelion_rules/port/ai_hero_rules_ai.hpp"

namespace aurelion::rules::port {

namespace {

using state::State;
using state::Value;

// The parameters as GDScript's types left them. A session is its view, a
// Dictionary (AiEngine.gd).
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

// Every function the AI targets port runs, each switched, so a shadow run
// checks each call on its own. A static var a port sets counts as a write.
const Function kFunctions[] = {
	PORT(AiHeroRules, active_hero_entries, 2, true, return gd::array_value(ai_hero_rules::active_hero_entries(s, D(a, 0), S(a, 1)))),
	PORT(AiHeroRules, _resolved_lookup, 1, true, return gd::dict_value(ai_hero_rules::_resolved_lookup(s, D(a, 0)))),
	PORT(AiHeroRules, _entry_index, 2, true, return gd::int_value(ai_hero_rules::_entry_index(s, D(a, 0), S(a, 1)))),
	PORT(AiHeroRules, _movement_max, 1, true, return gd::int_value(ai_hero_rules::_movement_max(s, D(a, 0)))),
	PORT(AiHeroRules, _trial_growth, 1, true, return gd::dict_value(ai_hero_rules::_trial_growth(s, D(a, 0)))),
	PORT(AiHeroRules, _recruit_set_value, 1, true, return gd::float_value(ai_hero_rules::_recruit_set_value(s, D(a, 0)))),
	PORT(AiHeroRules, _build_value, 1, true, return gd::float_value(ai_hero_rules::_build_value(s, D(a, 0)))),
	PORT(AiHeroRules, _market_cover, 6, true, return gd::bool_value(ai_hero_rules::_market_cover(s, D(a, 0), D(a, 1), D(a, 2), D(a, 3), B(a, 4), X(a, 5)))),
	PORT(AiHeroRules, _town_hero_defender_index, 3, true, return gd::int_value(ai_hero_rules::_town_hero_defender_index(s, D(a, 0), D(a, 1), S(a, 2)))),
	PORT(AiHeroRules, _town_entrance_free, 3, true, return gd::bool_value(ai_hero_rules::_town_entrance_free(s, D(a, 0), D(a, 1), S(a, 2)))),
	PORT(AiHeroRules, _garrison_pickup, 2, true, return gd::dict_value(ai_hero_rules::_garrison_pickup(s, A(a, 0), A(a, 1)))),
	PORT(AiHeroRules, _ferries_from, 4, true, return gd::bool_value(ai_hero_rules::_ferries_from(s, D(a, 0), D(a, 1), D(a, 2), S(a, 3)))),
	PORT(AiHeroRules, _field_hero_ids, 2, true, return gd::array_value(ai_hero_rules::_field_hero_ids(s, D(a, 0), S(a, 1)))),
	PORT(AiHeroRules, _decision_field_ids, 2, true, return gd::array_value(ai_hero_rules::_decision_field_ids(s, D(a, 0), D(a, 1)))),
	PORT(AiHeroRules, _burst_share, 2, true, return gd::float_value(ai_hero_rules::_burst_share(s, D(a, 0), X(a, 1)))),
	PORT(AiHeroRules, _main_hero_id, 2, true, return gd::str(ai_hero_rules::_main_hero_id(s, D(a, 0), S(a, 1)))),
	PORT(AiHeroRules, _weakest_stack_index, 1, true, return gd::int_value(ai_hero_rules::_weakest_stack_index(s, A(a, 0)))),
	PORT(AiHeroRules, _town_threatened, 3, true, return gd::bool_value(ai_hero_rules::_town_threatened(s, D(a, 0), D(a, 1), D(a, 2)))),
	PORT(AiHeroRules, _strongest_threat, 3, true, return gd::dict_value(ai_hero_rules::_strongest_threat(s, D(a, 0), D(a, 1), D(a, 2)))),
	PORT(AiHeroRules, _leave_defense, 6, true, return gd::dict_value(ai_hero_rules::_leave_defense(s, D(a, 0), D(a, 1), D(a, 2), A(a, 3), A(a, 4), B(a, 5)))),
	PORT(AiHeroRules, _decision_main_id, 2, true, return gd::str(ai_hero_rules::_decision_main_id(s, D(a, 0), D(a, 1)))),
	PORT(AiHeroRules, _plans_far, 3, true, return gd::bool_value(ai_hero_rules::_plans_far(s, D(a, 0), D(a, 1), D(a, 2)))),
	PORT(AiHeroRules, _gate_candidate, 6, true, return gd::dict_value(ai_hero_rules::_gate_candidate(s, D(a, 0), D(a, 1), D(a, 2), D(a, 3), I(a, 4), I(a, 5)))),
	PORT(AiHeroRules, _route_loss_limit, 1, true, return gd::float_value(ai_hero_rules::_route_loss_limit(s, F(a, 0)))),
	PORT(AiHeroRules, _stretch_key, 7, true, return gd::str(ai_hero_rules::_stretch_key(s, D(a, 0), D(a, 1), I(a, 2), I(a, 3), F(a, 4), F(a, 5), D(a, 6)))),
	PORT(AiHeroRules, _dangers, 3, true, return gd::array_value(ai_hero_rules::_dangers(s, D(a, 0), D(a, 1), D(a, 2)))),
	PORT(AiHeroRules, _in_danger, 4, true, return gd::bool_value(ai_hero_rules::_in_danger(s, A(a, 0), I(a, 1), I(a, 2), I(a, 3)))),
	PORT(AiHeroRules, _own_town_doors, 4, true, return gd::dict_value(ai_hero_rules::_own_town_doors(s, D(a, 0), S(a, 1), I(a, 2), V(a, 3)))),
	PORT(AiHeroRules, _profile_add, 3, true, ai_hero_rules::_profile_add(s, D(a, 0), S(a, 1), I(a, 2)); return nil()),
	PORT(AiHeroRules, _best_candidate, 7, true, return gd::dict_value(ai_hero_rules::_best_candidate(s, D(a, 0), D(a, 1), D(a, 2), D(a, 3), I(a, 4), I(a, 5), B(a, 6)))),
	PORT(AiHeroRules, _in_hero_zone, 2, true, return gd::bool_value(ai_hero_rules::_in_hero_zone(s, D(a, 0), I(a, 1)))),
	PORT(AiHeroRules, _exploration_candidate, 4, true, return gd::dict_value(ai_hero_rules::_exploration_candidate(s, D(a, 0), D(a, 1), D(a, 2), D(a, 3)))),
	PORT(AiHeroRules, _candidate, 8, true, return gd::dict_value(ai_hero_rules::_candidate(s, D(a, 0), D(a, 1), D(a, 2), D(a, 3), F(a, 4), D(a, 5), D(a, 6), I(a, 7)))),
	PORT(AiHeroRules, _split_for_handover, 1, true, return gd::dict_value(ai_hero_rules::_split_for_handover(s, X(a, 0)))),
	PORT(AiHeroRules, _guard_fight_value, 7, true, return gd::float_value(ai_hero_rules::_guard_fight_value(s, D(a, 0), D(a, 1), D(a, 2), I(a, 3), F(a, 4), D(a, 5), D(a, 6)))),
	PORT(AiHeroRules, _guard_power, 1, true, return gd::float_value(ai_hero_rules::_guard_power(s, D(a, 0)))),
	PORT(AiHeroRules, _expected_loss_value, 2, true, return gd::float_value(ai_hero_rules::_expected_loss_value(s, F(a, 0), F(a, 1)))),
	PORT(AiHeroRules, _guarded_object_value, 6, true, return gd::float_value(ai_hero_rules::_guarded_object_value(s, D(a, 0), D(a, 1), D(a, 2), D(a, 3), I(a, 4), S(a, 5)))),
	PORT(AiHeroRules, _site_door_value, 6, true, return gd::float_value(ai_hero_rules::_site_door_value(s, D(a, 0), D(a, 1), D(a, 2), D(a, 3), I(a, 4), D(a, 5)))),
	PORT(AiHeroRules, _site_door_key, 1, true, return gd::int_value(ai_hero_rules::_site_door_key(s, I(a, 0)))),
	PORT(AiHeroRules, _site_doors, 1, true, return gd::dict_value(ai_hero_rules::_site_doors(s, D(a, 0)))),
	PORT(AiHeroRules, _war_paths, 5, true, return gd::dict_value(ai_hero_rules::_war_paths(s, D(a, 0), D(a, 1), D(a, 2), D(a, 3), D(a, 4)))),
	PORT(AiHeroRules, _explore_value, 2, true, return gd::float_value(ai_hero_rules::_explore_value(s, D(a, 0), D(a, 1)))),
	PORT(AiHeroRules, _rival_towns_unknown, 2, true, return gd::bool_value(ai_hero_rules::_rival_towns_unknown(s, D(a, 0), D(a, 1)))),
	PORT(AiHeroRules, _hostile_heroes, 2, true, return gd::array_value(ai_hero_rules::_hostile_heroes(s, D(a, 0), S(a, 1)))),
	PORT(AiHeroRules, _explored, 3, true, return gd::bytes_value(ai_hero_rules::_explored(s, D(a, 0), D(a, 1), I(a, 2)))),
	PORT(AiHeroRules, _town_seen, 3, true, return gd::bool_value(ai_hero_rules::_town_seen(s, P(a, 0), D(a, 1), V(a, 2)))),
	PORT(AiHeroRules, _boat_market, 3, true, return gd::dict_value(ai_hero_rules::_boat_market(s, D(a, 0), D(a, 1), D(a, 2)))),
	PORT(AiHeroRules, _hero_guards, 3, true, return gd::array_value(ai_hero_rules::_hero_guards(s, D(a, 0), D(a, 1), I(a, 2)))),
	PORT(AiHeroRules, _hero_zone_tiles, 4, true, return gd::array_value(ai_hero_rules::_hero_zone_tiles(s, D(a, 0), D(a, 1), V(a, 2), I(a, 3)))),
	PORT(AiHeroRules, _level_surface, 3, true, return gd::dict_value(ai_hero_rules::_level_surface(s, D(a, 0), D(a, 1), I(a, 2)))),
	PORT(AiHeroRules, _search, 5, true, return gd::dict_value(ai_hero_rules::_search(s, D(a, 0), D(a, 1), D(a, 2), I(a, 3), B(a, 4)))),
	PORT(AiHeroRules, _boat_price, 4, true, return gd::float_value(ai_hero_rules::_boat_price(s, D(a, 0), D(a, 1), D(a, 2), I(a, 3)))),
	PORT(AiHeroRules, _tile_index_of, 2, true, return gd::int_value(ai_hero_rules::_tile_index_of(s, D(a, 0), V(a, 1)))),
	PORT(AiHeroRules, _path_to, 2, true, return gd::array_value(ai_hero_rules::_path_to(s, D(a, 0), I(a, 1)))),
	PORT(AiHeroRules, _note_alternative, 4, true, ai_hero_rules::_note_alternative(s, D(a, 0), D(a, 1), F(a, 2), I(a, 3)); return nil()),
	PORT(AiHeroRules, _neutral_army, 1, true, return gd::dict_value(ai_hero_rules::_neutral_army(s, D(a, 0)))),
	PORT(AiHeroRules, army_power, 2, true, return gd::float_value(ai_hero_rules::army_power(s, X(a, 0), X(a, 1)))),
	PORT(AiHeroRules, _spell_damage_per_round, 1, true, return gd::float_value(ai_hero_rules::_spell_damage_per_round(s, D(a, 0)))),
	PORT(AiHeroRules, _sync_power_memos, 0, true, ai_hero_rules::_sync_power_memos(s); return nil()),
	PORT(AiHeroRules, hero_power, 1, true, return gd::float_value(ai_hero_rules::hero_power(s, D(a, 0)))),
	PORT(AiHeroRules, _resource_needs, 2, true, return gd::dict_value(ai_hero_rules::_resource_needs(s, D(a, 0), D(a, 1)))),
	PORT(AiHeroRules, _merge_stacks_into, 2, true, return gd::dict_value(ai_hero_rules::_merge_stacks_into(s, X(a, 0), X(a, 1)))),
	PORT(AiHeroRules, _can_afford, 2, true, return gd::bool_value(ai_hero_rules::_can_afford(s, D(a, 0), D(a, 1)))),
};

#undef PORT

} // namespace

// The AI targets port's table, listed in registry_tables.cpp.
Table ai_table() {
	return {"HEROES_NATIVE_AI_LOG", kFunctions, sizeof(kFunctions) / sizeof(kFunctions[0])};
}

} // namespace aurelion::rules::port
