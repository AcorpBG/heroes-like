#include "aurelion_rules/port/registry.hpp"

#include "aurelion_rules/port/battle_ai_rules.hpp"
#include "aurelion_rules/port/battle_footprint.hpp"
#include "aurelion_rules/port/battle_rules.hpp"

#include <string>

namespace aurelion::rules::port {

namespace {

using gd::array_value;
using gd::bool_value;
using gd::dict_value;
using gd::float_value;
using gd::int_value;
using gd::str;
using state::Kind;
using state::State;
using state::Value;
namespace br = battle_rules;
namespace ai = battle_ai_rules;
namespace fp = battle_footprint;

// The parameters as GDScript's types left them.
gd::DictRef D(const Value *args, int index) {
	return gd::as_dict(args[index]);
}

int64_t I(const Value *args, int index) {
	if (args[index].kind != Kind::Int) {
		throw state::ScriptError(std::string("Invalid type: expected int, got ") + gd::type_name(args[index]));
	}
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

const Function kFunctions[] = {
	PORT(BattleAiRules, _alive_count, 1, false, return int_value(ai::_alive_count(s, D(a, 0)))),
	PORT(BattleAiRules, _alive_stacks_for_side, 2, false, return array_value(ai::_alive_stacks_for_side(s, D(a, 0), S(a, 1)))),
	PORT(BattleAiRules, _distance_band_from_hex_distance, 1, false, return int_value(ai::_distance_band_from_hex_distance(I(a, 0)))),
	PORT(BattleAiRules, _health_ratio, 1, false, return float_value(ai::_health_ratio(s, D(a, 0)))),
	PORT(BattleAiRules, _hex_cell, 2, false, return dict_value(ai::_hex_cell(s, I(a, 0), I(a, 1)))),
	PORT(BattleAiRules, _hex_in_bounds, 2, false, return bool_value(ai::_hex_in_bounds(I(a, 0), I(a, 1)))),
	PORT(BattleAiRules, _is_same_stack, 2, false, return bool_value(ai::_is_same_stack(s, D(a, 0), D(a, 1)))),
	PORT(BattleAiRules, _living_stacks_of_side, 2, false, return array_value(ai::_living_stacks_of_side(s, a[0], S(a, 1)))),
	PORT(BattleAiRules, _normalize_hex_cell, 1, false, return dict_value(ai::_normalize_hex_cell(s, a[0]))),
	PORT(BattleAiRules, _opposing_side, 1, false, return str(ai::_opposing_side(S(a, 0)))),
	PORT(BattleAiRules, _projected_on_cell, 3, false, return array_value(ai::_projected_on_cell(s, D(a, 0), D(a, 1), D(a, 2)))),
	PORT(BattleAiRules, _stack_by_battle_id, 2, false, return dict_value(ai::_stack_by_battle_id(s, D(a, 0), S(a, 1)))),
	PORT(BattleAiRules, _stack_contact_band, 2, false, return int_value(ai::_stack_contact_band(s, D(a, 0), D(a, 1)))),
	PORT(BattleAiRules, _stack_contact_band_on, 2, false, return int_value(ai::_stack_contact_band_on(s, D(a, 0), D(a, 1)))),
	PORT(BattleAiRules, _stack_engaged_on, 2, false, return bool_value(ai::_stack_engaged_on(s, D(a, 0), D(a, 1)))),
	PORT(BattleAiRules, _stack_hex, 1, false, return dict_value(ai::_stack_hex(s, D(a, 0)))),
	PORT(BattleAiRules, _stack_hex_distance, 2, false, return int_value(ai::_stack_hex_distance(s, D(a, 0), D(a, 1)))),
	PORT(BattleAiRules, _stack_is_engaged, 2, false, return bool_value(ai::_stack_is_engaged(s, D(a, 0), D(a, 1)))),
	PORT(BattleFootprint, cells, 2, false, return array_value(fp::cells(s, D(a, 0), dict_value(D(a, 1))))),
	PORT(BattleFootprint, distance, 3, false, return int_value(fp::distance(s, D(a, 0), D(a, 1), dict_value(D(a, 2))))),
	PORT(BattleFootprint, fits, 5, false, return bool_value(fp::fits(s, D(a, 0), dict_value(D(a, 1)), D(a, 2), I(a, 3), I(a, 4)))),
	PORT(BattleFootprint, placed_columns, 1, false, return array_value(fp::placed_columns(s, D(a, 0)))),
	PORT(BattleFootprint, width, 1, false, return int_value(fp::width(s, D(a, 0)))),
	PORT(BattleRules, _alive_count, 1, false, return int_value(br::_alive_count(s, D(a, 0)))),
	PORT(BattleRules, _alive_stack_count_for_side, 2, false, return int_value(br::_alive_stack_count_for_side(s, D(a, 0), S(a, 1)))),
	PORT(BattleRules, _alive_stacks_for_side, 2, false, return array_value(br::_alive_stacks_for_side(s, D(a, 0), S(a, 1)))),
	PORT(BattleRules, _build_blocking_map, 1, false, return dict_value(br::_build_blocking_map(s, D(a, 0)))),
	PORT(BattleRules, _build_occupancy_map, 1, false, return dict_value(br::_build_occupancy_map(s, D(a, 0)))),
	PORT(BattleRules, _distance_band_from_hex_distance, 1, false, return int_value(br::_distance_band_from_hex_distance(I(a, 0)))),
	PORT(BattleRules, _get_stack_by_id, 2, false, return dict_value(br::_get_stack_by_id(s, D(a, 0), S(a, 1)))),
	PORT(BattleRules, _health_ratio, 1, false, return float_value(br::_health_ratio(s, D(a, 0)))),
	PORT(BattleRules, _hex_cell, 2, false, return dict_value(br::_hex_cell(s, I(a, 0), I(a, 1)))),
	PORT(BattleRules, _hex_distance, 2, false, return int_value(br::_hex_distance(s, D(a, 0), D(a, 1)))),
	PORT(BattleRules, _hex_in_bounds, 2, false, return bool_value(br::_hex_in_bounds(I(a, 0), I(a, 1)))),
	PORT(BattleRules, _hex_key, 1, false, return str(br::_hex_key(s, D(a, 0)))),
	PORT(BattleRules, _hex_key_from_coords, 2, false, return str(br::_hex_key_from_coords(s, I(a, 0), I(a, 1)))),
	PORT(BattleRules, _hex_label, 1, false, return str(br::_hex_label(s, D(a, 0)))),
	PORT(BattleRules, _hex_neighbors, 1, false, return array_value(br::_hex_neighbors(s, D(a, 0)))),
	PORT(BattleRules, _hex_tail_step, 1, false, return int_value(br::_hex_tail_step(s, D(a, 0)))),
	PORT(BattleRules, _normalize_hex_cell, 1, false, return dict_value(br::_normalize_hex_cell(s, a[0]))),
	PORT(BattleRules, _obstacle_cell_map, 1, false, return dict_value(br::_obstacle_cell_map(s, D(a, 0)))),
	PORT(BattleRules, _offset_to_cube, 2, false, return dict_value(br::_offset_to_cube(s, I(a, 0), I(a, 1)))),
	PORT(BattleRules, _opposing_side, 1, false, return str(br::_opposing_side(S(a, 0)))),
	PORT(BattleRules, _projected_min_opposing_hex_distance, 3, false, return int_value(br::_projected_min_opposing_hex_distance(s, D(a, 0), D(a, 1), D(a, 2)))),
	PORT(BattleRules, _reachable_empty_hexes, 3, false, return array_value(br::_reachable_empty_hexes(s, D(a, 0), D(a, 1), I(a, 2)))),
	PORT(BattleRules, _side_label, 1, false, return str(br::_side_label(S(a, 0)))),
	PORT(BattleRules, _stack_hex, 1, false, return dict_value(br::_stack_hex(s, D(a, 0)))),
	PORT(BattleRules, _stack_hex_distance, 2, false, return int_value(br::_stack_hex_distance(s, D(a, 0), D(a, 1)))),
	PORT(BattleRules, _stack_is_engaged, 2, false, return bool_value(br::_stack_is_engaged(s, D(a, 0), D(a, 1)))),
	PORT(BattleRules, _stack_label, 1, false, return str(br::_stack_label(s, D(a, 0)))),
	PORT(BattleRules, _sync_distance_from_hexes, 1, true, br::_sync_distance_from_hexes(s, D(a, 0)); return nil()),
	PORT(BattleRules, _sync_occupied_hexes, 1, true, br::_sync_occupied_hexes(s, D(a, 0)); return nil()),
	PORT(BattleRules, _walk_steps_to_target, 4, false, return dict_value(br::_walk_steps_to_target(s, D(a, 0), D(a, 1), D(a, 2), I(a, 3)))),
	PORT(BattleRules, get_active_stack, 1, false, return dict_value(br::get_active_stack(s, D(a, 0)))),
};

#undef PORT

} // namespace

const Function *functions(size_t &count) {
	count = sizeof(kFunctions) / sizeof(kFunctions[0]);
	return kFunctions;
}

const Function *find_function(std::string_view name) {
	for (const Function &function : kFunctions) {
		if (name == function.name) {
			return &function;
		}
	}
	return nullptr;
}

} // namespace aurelion::rules::port
