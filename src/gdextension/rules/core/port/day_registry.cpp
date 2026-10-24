#include "aurelion_rules/port/registry.hpp"

#include "aurelion_rules/port/enemy_states.hpp"
#include "aurelion_rules/port/hero_commit.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"
#include "aurelion_rules/port/scenario_evaluation.hpp"

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

#define NATIVE(script, fn, arity, mutates, body) \
	{ #script "." #fn, arity, mutates, [](State &s, const Value *a) -> Value { (void)s; (void)a; body; } }

// The entry points of the day processing; the functions they reach run native
// inside them. Their GDScript functions are thin wrappers over DayEngine's
// native call (Phase 7, merge 3, owner decision D-d): a path the port leaves
// out is a native failure.
const Function kFunctions[] = {
	NATIVE(OverworldRules, _normalize_fog_of_war, 1, true, overworld::_normalize_fog_of_war(s, D(a, 0)); return nil()),
	// Writes the session's cached scenery layers and resolved-encounter set.
	NATIVE(OverworldRules, _build_blocked_tile_index, 4, true,
			if (a[0].kind == state::Kind::Nil) return gd::dict_value(s.new_dict());
			return gd::dict_value(overworld::_build_blocked_tile_index(s, D(a, 0), I(a, 1), S(a, 2), D(a, 3)))),
	NATIVE(OverworldRules, _normalize_resource_nodes, 1, false, return gd::array_value(overworld::_normalize_resource_nodes(s, A(a, 0)))),
	// The computer players' states, their raid hosts and commander rosters;
	// writes the session's difficulty and the fallen heroes' days in its metadata.
	NATIVE(EnemyTurnRules, normalize_enemy_states, 1, true,
			if (a[0].kind == state::Kind::Nil) return nil();
			enemy_turn_rules::normalize_enemy_states(s, D(a, 0)); return nil()),
	// The scenario's state and objectives: writes its status, its script state
	// and the computer players' states.
	NATIVE(ScenarioRules, evaluate_session, 1, true,
			if (a[0].kind == state::Kind::Nil) {
				const gd::DictRef invalid = s.new_dict();
				s.set(invalid, gd::str(state::key::status), gd::str(state::key::invalid));
				s.set(invalid, gd::str(state::key::message), gd::str(state::key::empty));
				return gd::dict_value(invalid);
			}
			return gd::dict_value(scenario_rules::evaluate_session(s, D(a, 0)))),
	// The townless days: writes the session's townless_since.
	NATIVE(PlayerEliminationRules, apply_daily, 1, true,
			if (a[0].kind == state::Kind::Nil) return gd::array_value(s.new_array());
			return gd::array_value(player_elimination_rules::apply_daily(s, D(a, 0)))),
	// The active hero's mirrors written back into the player's roster.
	NATIVE(HeroCommandRules, commit_active_hero, 1, true,
			if (a[0].kind == state::Kind::Nil) return nil();
			hero_command_rules::commit_active_hero(s, D(a, 0)); return nil()),
	// The whole session normalized: its fields, heroes, towns, nodes, transit,
	// blocked tiles, fog, briefing, risk forecast and scenario state; writes the
	// runtime signature into OverworldRules._runtime_normalized_signatures.
	NATIVE(OverworldRules, normalize_overworld_state, 1, true,
			if (a[0].kind == state::Kind::Nil) return nil();
			overworld::normalize_overworld_state(s, D(a, 0)); return nil()),
	// end_turn up to the AI turn: the closing normalize, the hero commit and the
	// new day's economy; writes the session's day, towns, treasury, heroes and
	// resource nodes, and returns the day's messages and income.
	NATIVE(OverworldRules, _end_turn_open_day, 1, true,
			if (a[0].kind == state::Kind::Nil) throw state::NotPorted("left to GDScript: a null session");
			return gd::dict_value(overworld::_end_turn_open_day(s, D(a, 0)))),
	// end_turn after the AI turn: elimination, the action result, the closing
	// normalize and the day's summaries; appends to the opened messages.
	NATIVE(OverworldRules, _end_turn_close_day, 3, true,
			if (a[0].kind == state::Kind::Nil) throw state::NotPorted("left to GDScript: a null session");
			return gd::dict_value(overworld::_end_turn_close_day(s, D(a, 0), D(a, 1), D(a, 2)))),
	// The whole day in one call (Phase 6 P6-3): _end_turn_open_day, the
	// computer players' turn and _end_turn_close_day, so the session loads
	// once a day.
	NATIVE(OverworldRules, end_turn, 1, true,
			if (a[0].kind == state::Kind::Nil) throw state::NotPorted("left to GDScript: a null session");
			return gd::dict_value(overworld::end_turn(s, D(a, 0)))),
	// An action's close: the hero committed, the fog refreshed, the scenario
	// evaluated, the runtime signature recorded.
	NATIVE(OverworldRules, _finalize_action_result, 6, true,
			if (a[0].kind == state::Kind::Nil) throw state::NotPorted("left to GDScript: a null session");
			return gd::dict_value(overworld::_finalize_action_result(s, D(a, 0), gd::to_bool(a[1]), S(a, 2), gd::to_bool(a[3]), gd::to_bool(a[4]), D(a, 5)))),
};

#undef NATIVE

} // namespace

// The day port's table, listed in registry_tables.cpp.
Table day_table() {
	Table table{"HEROES_NATIVE_DAY_LOG", kFunctions, sizeof(kFunctions) / sizeof(kFunctions[0])};
	return table;
}

} // namespace aurelion::rules::port
