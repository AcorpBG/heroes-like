// AiHeroRules: whether an encounter is an AI hero, the active AI heroes.

#include "aurelion_rules/port/ai_hero_rules.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"
#include "aurelion_rules/port/player_identity_rules.hpp"
#include "aurelion_rules/port/session_view.hpp"

namespace aurelion::rules::port::ai_hero_rules {

bool is_ai_hero(State &state, const Value &entry) {
	// entry is Dictionary and entry.get(AI_HERO_KEY, null) is Dictionary.
	return gd::is_dict(entry) && gd::is_dict(state.get(entry.ref, gd::str(state::key::ai_hero), Value()));
}

gd::ArrayRef active_hero_entries(State &state, gd::DictRef session, gd::Atom controller) {
	const gd::ArrayRef result = state.new_array();
	const gd::DictRef resolved = _resolved_lookup(state, session);
	for (const Value &entry : gd::field_items(state, session_view::overworld(state, session), gd::str(state::key::encounters))) {
		// is_ai_hero, inline, then the resolved placements.
		if (!is_ai_hero(state, entry) ||
				state.has(resolved, gd::str(gd::stringify_or_fallback(state, state.get(entry.ref, gd::str(state::key::placement_id), gd::str(state::key::empty)))))) {
			continue;
		}
		if (controller != state::key::empty && player_identity_rules::raid_controller_id(state, entry.ref) != controller) {
			continue;
		}
		state.append(result, entry);
	}
	return result;
}

int64_t active_hero_count(State &state, gd::DictRef session, gd::Atom controller) {
	return state.array_size(active_hero_entries(state, session, controller));
}

gd::DictRef _resolved_lookup(State &state, gd::DictRef session) {
	return overworld_rules::resolved_encounter_lookup(state, session);
}

} // namespace aurelion::rules::port::ai_hero_rules
