// EnemyAdventureRules: whether a placement is resolved.

#include "aurelion_rules/port/enemy_adventure_rules.hpp"

namespace aurelion::rules::port::enemy_adventure_rules {

bool _placement_resolved(State &state, Atom placement_id, const Value &resolved_encounters) {
	if (gd::is_dict(resolved_encounters)) {
		return state.has(resolved_encounters.ref, gd::str(placement_id));
	}
	return gd::is_array(resolved_encounters) && gd::array_has(state, resolved_encounters.ref, gd::str(placement_id));
}

} // namespace aurelion::rules::port::enemy_adventure_rules
