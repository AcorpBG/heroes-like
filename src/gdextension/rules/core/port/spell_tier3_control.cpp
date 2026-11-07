// Layer 8: tier 3's control spells and Fogwalk (docs/magic-system-spells.md). Goad names a stack of the caster's that
// the goaded stack must attack while it can reach it; Uproot drags an enemy stack, a rooted one too, to a hex it could
// walk to within the cast's reach and staggers it; Night Terror's Fleeing stack runs at the start of its next turn as
// far from the other side's stacks as it can walk (a stack that cannot move cowers) and strikes nothing back while it
// is Fleeing; Fogwalk's stack walks through stacks and obstacles (spell_ground.cpp's pass mask) and its next blow is
// not struck back.

#include "aurelion_rules/port/spell_rules.hpp"

#include "aurelion_rules/compat/godot_math.hpp"
#include "aurelion_rules/port/battle_footprint.hpp"
#include "aurelion_rules/port/battle_rules.hpp"

namespace aurelion::rules::port::spell_rules {

using compat::engine_min;
using gd::array_value;
using gd::dict_value;
using gd::int_value;
using gd::str;
namespace key = state::key;

namespace {

Atom side_of(const State &state, DictRef stack) {
	return gd::string_field(state, stack, key::side, key::empty);
}

bool alive(State &state, DictRef stack) {
	return !gd::is_empty(state, stack) && _alive_count(state, stack) > 0;
}

// The fewest hexes from the stack, standing on the cell (where it stands for a Nil cell), to the other side's stacks.
int64_t nearest_foe(State &state, DictRef stack, ArrayRef foes, const Value &cell) {
	int64_t best = 999;
	for (const Value &foe : gd::items(state, array_value(foes))) {
		if (gd::is_dict(foe)) {
			best = engine_min<int64_t>(best, battle_footprint::distance(state, stack, foe.ref, cell));
		}
	}
	return best;
}

} // namespace

// --- Goad --------------------------------------------------------------------

DictRef goad_target(State &state, DictRef battle, DictRef stack) {
	if (gd::is_empty(state, battle) || gd::is_empty(state, stack)) {
		return state.new_dict();
	}
	const DictRef goad = stack_mechanic_effect(state, stack, battle, key::taunt_target);
	if (gd::is_empty(state, goad)) {
		return state.new_dict();
	}
	const Atom named = gd::string_field(state, effect_mechanic(state, goad), key::taunt_target, key::empty);
	const DictRef target = named == key::empty ? state.new_dict() : battle_rules::_get_stack_by_id(state, battle, named);
	if (!alive(state, target) || side_of(state, target) == side_of(state, stack)) {
		return state.new_dict();
	}
	return target;
}

DictRef goad_forced_target(State &state, DictRef battle, DictRef stack) {
	const DictRef target = goad_target(state, battle, stack);
	if (gd::is_empty(state, target)) {
		return target;
	}
	if (battle_rules::_can_make_ranged_attack(state, stack, battle, target) || battle_rules::_can_make_melee_attack(state, stack, battle, target)
			|| !gd::is_empty(state, battle_rules::melee_approach_destination(state, battle, stack, target))) {
		return target;
	}
	return state.new_dict();
}

// --- Strike-backs --------------------------------------------------------------

Atom strike_back_refused_reason(State &state, DictRef battle, DictRef defender) {
	if (gd::is_empty(state, battle) || gd::is_empty(state, defender)) {
		return key::empty;
	}
	// Night Terror: a fleeing stack has no heart to strike back.
	if (has_effect_id(state, defender, battle, key::status_fleeing)) {
		return key::it_is_fleeing_text;
	}
	// Fogwalk: the active stack's next blow, or the one it has just struck, comes out of the fog.
	const Atom active_id = gd::string_field(state, battle, key::active_stack_id, key::empty);
	if (active_id == key::empty) {
		return key::empty;
	}
	const DictRef active = battle_rules::_get_stack_by_id(state, battle, active_id);
	if (gd::is_empty(state, active) || side_of(state, active) == side_of(state, defender) || side_of(state, active) == key::empty) {
		return key::empty;
	}
	if (gd::string_field(state, battle, key::unanswered_blow_by, key::empty) == active_id || stack_mechanic_int(state, active, battle, key::no_strike_back) > 0) {
		return key::blow_from_the_fog_text;
	}
	return key::empty;
}

bool strike_back_refused(State &state, DictRef battle, DictRef defender) {
	return strike_back_refused_reason(state, battle, defender) != key::empty;
}

void note_blow_for_strike_back(State &state, DictRef battle, Atom attacker_id, bool is_ranged) {
	if (is_ranged || gd::is_empty(state, battle) || gd::string_field(state, battle, key::active_stack_id, key::empty) != attacker_id) {
		return;
	}
	const DictRef attacker = battle_rules::_get_stack_by_id(state, battle, attacker_id);
	const DictRef fog = gd::is_empty(state, attacker) ? state.new_dict() : stack_mechanic_effect(state, attacker, battle, key::no_strike_back);
	if (!gd::is_empty(state, fog) && gd::int_field(state, effect_mechanic(state, fog), key::no_strike_back, 0) > 0) {
		state.set(effect_mechanic(state, fog), str(key::no_strike_back), int_value(0));
		state.set(battle, str(key::unanswered_blow_by), str(attacker_id));
	} else if (state.has(battle, str(key::unanswered_blow_by))) {
		state.erase(battle, str(key::unanswered_blow_by));
	}
}

// --- Night Terror --------------------------------------------------------------

bool flee_turn(State &state, DictRef battle, Atom battle_id) {
	const DictRef stack = battle_rules::_get_stack_by_id(state, battle, battle_id);
	if (!alive(state, stack)) {
		return false;
	}
	const DictRef fear = stack_mechanic_effect(state, stack, battle, key::flee);
	if (gd::is_empty(state, fear) || gd::int_field(state, effect_mechanic(state, fear), key::flee, 0) <= 0) {
		return false;
	}
	state.set(effect_mechanic(state, fear), str(key::flee), int_value(0));
	const Atom label = battle_rules::_stack_label(state, stack);
	const ArrayRef foes = battle_rules::_alive_stacks_for_side(state, battle, battle_rules::_opposing_side(side_of(state, stack)));
	// The hex it can walk to farthest from the other side's stacks, the first of the farthest; it stays put when no
	// hex is farther than where it stands.
	int64_t farthest = nearest_foe(state, stack, foes, Value());
	Value best;
	for (const Value &cell : gd::items(state, array_value(battle_rules::legal_destinations_for_stack(state, battle, battle_id)))) {
		if (!gd::is_dict(cell)) {
			continue;
		}
		const int64_t away = nearest_foe(state, stack, foes, cell);
		if (away > farthest) {
			farthest = away;
			best = cell;
		}
	}
	if (!gd::is_dict(best)) {
		battle_rules::_record_event(state, battle, gd::format(state, key::cowers_in_terror_text, { str(label) }));
		return true;
	}
	const DictRef start = gd::deep_duplicate_dict(state, battle_rules::_stack_hex(state, stack));
	battle_rules::_set_stack_hex(state, battle, battle_id, battle_rules::_normalize_hex_cell(state, best));
	battle_rules::_sync_distance_from_hexes(state, battle);
	// Ground it runs over or into is paid at the end of the turn, as after any walk.
	after_ground_walk(state, battle, battle_id, start);
	battle_rules::_record_event(state, battle, gd::format(state, key::flees_in_terror_text, { str(label) }));
	return true;
}

// --- Uproot ------------------------------------------------------------------

int64_t spell_pull_reach(State &state, DictRef hero, DictRef battle, DictRef spell, DictRef target) {
	return spell_move_reach(state, spell, spell_power_against(state, hero, battle, target));
}

ArrayRef pull_destinations(State &state, DictRef battle, DictRef stack, int64_t reach) {
	if (!alive(state, stack) || reach <= 0) {
		return state.new_array();
	}
	// Roots drag a rooted stack as well: the hexes it could walk to, its rooting aside.
	return battle_rules::_reachable_empty_hexes(state, battle, stack, reach);
}

} // namespace aurelion::rules::port::spell_rules
