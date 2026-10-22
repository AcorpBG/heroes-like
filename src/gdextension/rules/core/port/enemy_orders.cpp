// Slice 09: the orders of a computer-driven stack: the hex it strikes from and
// its advance plan, both BattleAiRules' decisions, and the walk of an advance.

#include "aurelion_rules/port/battle_rules.hpp"

#include "aurelion_rules/port/battle_ai_rules.hpp"

namespace aurelion::rules::port::battle_rules {

namespace key = state::key;

DictRef ai_melee_approach(State &state, DictRef battle, DictRef stack, DictRef target) {
	const ArrayRef cells = melee_approach_cells(state, battle, stack, target);
	return battle_ai_rules::choose_melee_approach(state, battle, stack, target, cells);
}

DictRef ai_advance_plan(State &state, DictRef battle, DictRef stack) {
	return battle_ai_rules::advance_plan(state, battle, stack);
}

bool _apply_auto_advance_movement(State &state, DictRef battle, DictRef active_stack) {
	if (_advance_stalled_by_obstruction(state, active_stack, battle)) {
		return false;
	}
	const Atom battle_id = gd::string_field(state, active_stack, key::battle_id, key::empty);
	const Atom start_key = _hex_key(state, _stack_hex(state, active_stack));
	// GDScript's board-read scope: the native board reads keep their own memo.
	// The arguments in the GDScript order: the target, then the gap.
	const DictRef preferred_target = battle_ai_rules::advance_target(state, battle, active_stack);
	const int64_t desired_gap = _advance_desired_gap(state, active_stack, battle);
	const DictRef destination = battle_ai_rules::best_advance_destination(state, battle, active_stack, preferred_target, desired_gap);
	// End of GDScript's board-read scope.
	if (!gd::is_empty(state, destination)) {
		_set_stack_hex(state, battle, battle_id, destination);
	}
	// Without a destination nobody moved, so the band must not shrink.
	_sync_distance_from_hexes(state, battle);
	return _hex_key(state, _stack_hex(state, _get_stack_by_id(state, battle, battle_id))) != start_key;
}

} // namespace aurelion::rules::port::battle_rules
