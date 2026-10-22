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
	PORT(AiHeroRules, _market_cover, 6, true, return gd::bool_value(ai_hero_rules::_market_cover(s, D(a, 0), D(a, 1), D(a, 2), D(a, 3), B(a, 4), X(a, 5)))),
	PORT(AiHeroRules, _garrison_pickup, 2, true, return gd::dict_value(ai_hero_rules::_garrison_pickup(s, A(a, 0), A(a, 1)))),
	PORT(AiHeroRules, _town_threatened, 3, true, return gd::bool_value(ai_hero_rules::_town_threatened(s, D(a, 0), D(a, 1), D(a, 2)))),
	PORT(AiHeroRules, _decision_main_id, 2, true, return gd::str(ai_hero_rules::_decision_main_id(s, D(a, 0), D(a, 1)))),
	PORT(AiHeroRules, _gate_candidate, 6, true, return gd::dict_value(ai_hero_rules::_gate_candidate(s, D(a, 0), D(a, 1), D(a, 2), D(a, 3), I(a, 4), I(a, 5)))),
	PORT(AiHeroRules, _candidate, 8, true, return gd::dict_value(ai_hero_rules::_candidate(s, D(a, 0), D(a, 1), D(a, 2), D(a, 3), F(a, 4), D(a, 5), D(a, 6), I(a, 7)))),
	PORT(AiHeroRules, _guard_power, 1, true, return gd::float_value(ai_hero_rules::_guard_power(s, D(a, 0)))),
	PORT(AiHeroRules, _guarded_object_value, 6, true, return gd::float_value(ai_hero_rules::_guarded_object_value(s, D(a, 0), D(a, 1), D(a, 2), D(a, 3), I(a, 4), S(a, 5)))),
	PORT(AiHeroRules, _rival_towns_unknown, 2, true, return gd::bool_value(ai_hero_rules::_rival_towns_unknown(s, D(a, 0), D(a, 1)))),
	PORT(AiHeroRules, _level_surface, 3, true, return gd::dict_value(ai_hero_rules::_level_surface(s, D(a, 0), D(a, 1), I(a, 2)))),
	PORT(AiHeroRules, _search, 5, true, return gd::dict_value(ai_hero_rules::_search(s, D(a, 0), D(a, 1), D(a, 2), I(a, 3), B(a, 4)))),
	PORT(AiHeroRules, _path_to, 2, true, return gd::array_value(ai_hero_rules::_path_to(s, D(a, 0), I(a, 1)))),
	PORT(AiHeroRules, _neutral_army, 1, true, return gd::dict_value(ai_hero_rules::_neutral_army(s, D(a, 0)))),
	PORT(AiHeroRules, army_power, 2, true, return gd::float_value(ai_hero_rules::army_power(s, X(a, 0), X(a, 1)))),
	PORT(AiHeroRules, _spell_damage_per_round, 1, true, return gd::float_value(ai_hero_rules::_spell_damage_per_round(s, D(a, 0)))),
	PORT(AiHeroRules, hero_power, 1, true, return gd::float_value(ai_hero_rules::hero_power(s, D(a, 0)))),
	PORT(AiHeroRules, _resource_needs, 2, true, return gd::dict_value(ai_hero_rules::_resource_needs(s, D(a, 0), D(a, 1)))),
	PORT(AiHeroRules, _merge_stacks_into, 2, true, return gd::dict_value(ai_hero_rules::_merge_stacks_into(s, X(a, 0), X(a, 1)))),
};

#undef PORT

} // namespace

// The AI targets port's table, listed in registry_tables.cpp.
Table ai_table() {
	return {"HEROES_NATIVE_AI_LOG", kFunctions, sizeof(kFunctions) / sizeof(kFunctions[0])};
}

} // namespace aurelion::rules::port
