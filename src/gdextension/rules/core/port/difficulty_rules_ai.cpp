// DifficultyRules: the functions the AI targets reach (Phase 3), ported under
// their GDScript names.

#include "aurelion_rules/port/difficulty_rules_ai.hpp"

namespace aurelion::rules::port {

namespace {

using gd::Atom;
using gd::DictRef;
using gd::float_value;
using gd::int_value;
using gd::str;
using state::Kind;
using state::State;
namespace key = state::key;
// DifficultyRules.DIFFICULTY_PROFILES, row by row in the literal's order.
struct DifficultyProfile {
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
const DifficultyProfile kDifficultyProfiles[3] = {
	{ 2, 1.25, 1.25, -1, 1, 0.75, 1.1, 0.9, 1, 0 },
	{ 0, 1.0, 1.0, 0, 0, 1.0, 1.0, 1.0, 0, 0 },
	{ -1, 0.85, 0.85, 1, -1, 1.25, 0.95, 1.05, 0, 1 },
};
// The DIFFICULTY_PROFILES row of an id, -1 when it has none.
int difficulty_row(Atom id) {
	if (id == key::story) {
		return 0;
	}
	if (id == key::normal) {
		return 1;
	}
	if (id == key::hard) {
		return 2;
	}
	return -1;
}
// DIFFICULTY_PROFILES[id].duplicate(true): a new Dictionary of the row's numbers.
DictRef new_difficulty_profile(State &state, int row) {
	const DifficultyProfile &profile = kDifficultyProfiles[row];
	const DictRef result = state.new_dict();
	state.set(result, str(key::movement_bonus), int_value(profile.movement_bonus));
	state.set(result, str(key::income_multiplier), float_value(profile.income_multiplier));
	state.set(result, str(key::reward_multiplier), float_value(profile.reward_multiplier));
	state.set(result, str(key::enemy_pressure_bonus), int_value(profile.enemy_pressure_bonus));
	state.set(result, str(key::raid_threshold_offset), int_value(profile.raid_threshold_offset));
	state.set(result, str(key::raid_pillage_multiplier), float_value(profile.raid_pillage_multiplier));
	state.set(result, str(key::player_damage_multiplier), float_value(profile.player_damage_multiplier));
	state.set(result, str(key::enemy_damage_multiplier), float_value(profile.enemy_damage_multiplier));
	state.set(result, str(key::player_initiative_bonus), int_value(profile.player_initiative_bonus));
	state.set(result, str(key::enemy_initiative_bonus), int_value(profile.enemy_initiative_bonus));
	return result;
}

} // namespace

namespace difficulty_rules {

DictRef profile_for_difficulty(State &state, const Value &difficulty_id) {
	const Atom normalized_id = normalize_difficulty(state, difficulty_id);
	const Atom default_id = _default_difficulty_id(state);
	const int fallback = difficulty_row(default_id);
	if (fallback < 0) {
		throw state::ScriptError("Invalid access to property or key '" + gd::text(state, str(default_id)) + "' on a base object of type 'Dictionary'.");
	}
	const int row = difficulty_row(normalized_id);
	return new_difficulty_profile(state, row >= 0 ? row : fallback);
}

DictRef profile_for_session(State &state, const Value &session) {
	if (session.kind == Kind::Nil) {
		return profile_for_difficulty(state, str(_default_difficulty_id(state)));
	}
	// session.difficulty: the AI targets pass the session's view, the battle port
	// the SessionData object.
	if (session.kind == Kind::Opaque) {
		return profile_for_difficulty(state, gd::member(state, session, key::difficulty));
	}
	return profile_for_difficulty(state, gd::index(state, gd::as_dict(session), str(key::difficulty)));
}

int64_t movement_bonus(State &state, const Value &session) {
	return gd::int_field(state, profile_for_session(state, session), key::movement_bonus, 0);
}

} // namespace difficulty_rules

} // namespace aurelion::rules::port
