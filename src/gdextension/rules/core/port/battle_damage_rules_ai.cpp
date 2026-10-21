// BattleDamageRules: the functions the AI targets reach (Phase 3), ported under
// their GDScript names.

#include "aurelion_rules/port/battle_damage_rules_ai.hpp"

namespace aurelion::rules::port {

namespace {

using state::State;

} // namespace

namespace battle_damage_rules {

double attack_defense_multiplier(State &state, int64_t attack_stat, int64_t defense_stat) {
	(void)state;
	const int64_t difference = gd::sub(attack_stat, defense_stat);
	if (difference >= 0) {
		return 1.0 + compat::engine_min(static_cast<double>(difference) * 0.05, 3.0);
	}
	return 1.0 - compat::engine_min(static_cast<double>(gd::neg(difference)) * 0.025, 0.7);
}

} // namespace battle_damage_rules

} // namespace aurelion::rules::port
