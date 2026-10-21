// DifficultyRules: a difficulty id and its profile. Copies of Phase 1's port,
// with a session as its view.

#include "aurelion_rules/port/difficulty_rules.hpp"

namespace aurelion::rules::port::difficulty_rules {

namespace {

using gd::int_value;
using gd::str;
namespace key = state::key;

// The profile of DIFFICULTY_PROFILES[id].duplicate(true): a new Dictionary in
// the const's key order and types.
DictRef difficulty_profile(State &state, Atom id) {
	struct Profile {
		int64_t movement_bonus;
		double income_multiplier;
		double reward_multiplier;
		int64_t enemy_pressure_bonus;
		int64_t raid_threshold_offset;
		double raid_pillage_multiplier;
		double player_damage_multiplier;
		double enemy_damage_multiplier;
		int64_t player_initiative_bonus;
		int64_t enemy_initiative_bonus;
	};
	static constexpr Profile kStory{ 2, 1.25, 1.25, -1, 1, 0.75, 1.1, 0.9, 1, 0 };
	static constexpr Profile kNormal{ 0, 1.0, 1.0, 0, 0, 1.0, 1.0, 1.0, 0, 0 };
	static constexpr Profile kHard{ -1, 0.85, 0.85, 1, -1, 1.25, 0.95, 1.05, 0, 1 };
	const Profile &profile = id == key::story ? kStory : (id == key::hard ? kHard : kNormal);
	const DictRef result = state.new_dict();
	state.set(result, str(key::movement_bonus), int_value(profile.movement_bonus));
	state.set(result, str(key::income_multiplier), gd::float_value(profile.income_multiplier));
	state.set(result, str(key::reward_multiplier), gd::float_value(profile.reward_multiplier));
	state.set(result, str(key::enemy_pressure_bonus), int_value(profile.enemy_pressure_bonus));
	state.set(result, str(key::raid_threshold_offset), int_value(profile.raid_threshold_offset));
	state.set(result, str(key::raid_pillage_multiplier), gd::float_value(profile.raid_pillage_multiplier));
	state.set(result, str(key::player_damage_multiplier), gd::float_value(profile.player_damage_multiplier));
	state.set(result, str(key::enemy_damage_multiplier), gd::float_value(profile.enemy_damage_multiplier));
	state.set(result, str(key::player_initiative_bonus), int_value(profile.player_initiative_bonus));
	state.set(result, str(key::enemy_initiative_bonus), int_value(profile.enemy_initiative_bonus));
	return result;
}

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

DictRef profile_for_difficulty(State &state, const Value &difficulty_id) {
	const Atom normalized_id = normalize_difficulty(state, difficulty_id);
	// DIFFICULTY_PROFILES.get(normalized_id, DIFFICULTY_PROFILES[_default_difficulty_id()]).duplicate(true):
	// normalize_difficulty only answers the profiles' own ids.
	const Atom fallback_id = _default_difficulty_id(state);
	const bool known = normalized_id == key::story || normalized_id == key::normal || normalized_id == key::hard;
	return difficulty_profile(state, known ? normalized_id : fallback_id);
}

DictRef profile_for_session(State &state, const Value &session) {
	if (session.kind == state::Kind::Nil) {
		return profile_for_difficulty(state, str(_default_difficulty_id(state)));
	}
	// A day or AI port's session is its view; the battle port's, SessionData.
	const Value difficulty = gd::is_dict(session) ? gd::field(state, session.ref, key::difficulty) : gd::member(state, session, key::difficulty);
	return profile_for_difficulty(state, difficulty);
}

int64_t movement_bonus(State &state, const Value &session) {
	return gd::int_field(state, profile_for_session(state, session), key::movement_bonus, 0);
}

} // namespace aurelion::rules::port::difficulty_rules
