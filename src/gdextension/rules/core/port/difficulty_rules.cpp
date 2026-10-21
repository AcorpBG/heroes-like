// DifficultyRules: a difficulty id. Verbatim copies of Phase 1's port.

#include "aurelion_rules/port/difficulty_rules.hpp"

namespace aurelion::rules::port::difficulty_rules {

namespace {

namespace key = state::key;

} // namespace

Atom _default_difficulty_id(State &) {
	// ScenarioSelectRules.default_difficulty_id().
	return key::normal;
}

Atom normalize_difficulty(State &state, const Value &value) {
	// ScenarioSelectRules.normalize_difficulty(value): the ids of DIFFICULTY_OPTIONS.
	const Atom difficulty_id = gd::stringify_or_fallback(state, value);
	for (const Atom option_id : { key::story, key::normal, key::hard }) {
		if (option_id == difficulty_id) {
			return difficulty_id;
		}
	}
	return _default_difficulty_id(state);
}

} // namespace aurelion::rules::port::difficulty_rules
