#include "aurelion_rules/port/registry.hpp"

#include "aurelion_rules/port/enemy_states.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"

namespace aurelion::rules::port {

namespace {

using state::State;
using state::Value;
namespace overworld = overworld_rules;

// The parameters as GDScript's types left them. A session is its view, a
// Dictionary (DayEngine.gd).
gd::DictRef D(const Value *args, int index) {
	return gd::as_dict(args[index]);
}
gd::ArrayRef A(const Value *args, int index) {
	return gd::as_array(args[index]);
}
int64_t I(const Value *args, int index) {
	return args[index].i;
}
gd::Atom S(const Value *args, int index) {
	return gd::to_string(args[index]);
}

Value nil() {
	return Value();
}

#define PORT(script, fn, arity, mutates, body) \
	{ #script "." #fn, arity, mutates, [](State &s, const Value *a) -> Value { (void)s; (void)a; body; } }

// The entry points of the day processing ported so far; the functions they
// reach run native inside them.
const Function kFunctions[] = {
	PORT(OverworldRules, _normalize_fog_of_war, 1, true, overworld::_normalize_fog_of_war(s, D(a, 0)); return nil()),
	// Writes the session's cached scenery layers and resolved-encounter set.
	PORT(OverworldRules, _build_blocked_tile_index, 4, true,
			if (a[0].kind == state::Kind::Nil) return gd::dict_value(s.new_dict());
			return gd::dict_value(overworld::_build_blocked_tile_index(s, D(a, 0), I(a, 1), S(a, 2), D(a, 3)))),
	PORT(OverworldRules, _normalize_resource_nodes, 1, false, return gd::array_value(overworld::_normalize_resource_nodes(s, A(a, 0)))),
	// The computer players' states, their raid hosts and commander rosters;
	// writes the session's difficulty and the fallen heroes' days in its metadata.
	PORT(EnemyTurnRules, normalize_enemy_states, 1, true,
			if (a[0].kind == state::Kind::Nil) return nil();
			enemy_turn_rules::normalize_enemy_states(s, D(a, 0)); return nil()),
};

#undef PORT

} // namespace

// The day port's table, listed in registry_tables.cpp.
Table day_table() {
	return {"HEROES_NATIVE_DAY_LOG", kFunctions, sizeof(kFunctions) / sizeof(kFunctions[0])};
}

} // namespace aurelion::rules::port
