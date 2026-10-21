// AiHeroRules: whether an encounter is an AI hero.

#include "aurelion_rules/port/ai_hero_rules.hpp"

namespace aurelion::rules::port::ai_hero_rules {

bool is_ai_hero(State &state, const Value &entry) {
	// entry is Dictionary and entry.get(AI_HERO_KEY, null) is Dictionary.
	return gd::is_dict(entry) && gd::is_dict(state.get(entry.ref, gd::str(state::key::ai_hero), Value()));
}

} // namespace aurelion::rules::port::ai_hero_rules
