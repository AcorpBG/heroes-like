// HeroCommandRules: a hero's sight and movement points.

#include "aurelion_rules/port/hero_command_rules.hpp"

#include "aurelion_rules/port/artifact_rules.hpp"
#include "aurelion_rules/port/difficulty_rules.hpp"
#include "aurelion_rules/port/hero_progression_rules.hpp"
#include "aurelion_rules/port/overworld_level_rules.hpp"

#include <cmath>

namespace aurelion::rules::port::hero_command_rules {

namespace {

namespace key = state::key;

// HeroCommandRules.BASE_SCOUT_RADIUS.
constexpr int64_t kBaseScoutRadius = 6;

} // namespace

int64_t scouting_radius_for_hero(State &state, DictRef hero_state) {
	const DictRef artifact_bonuses = artifact_rules::aggregate_bonuses(state, hero_state);
	const DictRef specialty_bonuses = hero_progression_rules::aggregate_bonuses(state, hero_state);
	const int64_t radius = gd::add(gd::add(kBaseScoutRadius, gd::int_field(state, artifact_bonuses, key::scouting_radius, 0)), gd::int_field(state, specialty_bonuses, key::scouting_radius, 0));
	return compat::engine_max<int64_t>(1, radius);
}

// Sight covers a round area: a tile is in range when its centre lies within
// radius + 1/2 tiles of the source, which keeps the rim free of one-tile nubs.
int64_t scout_row_half_width(int64_t dy, int64_t radius) {
	const int64_t remaining = gd::sub(gd::mul(radius, gd::add(radius, 1)), gd::mul(dy, dy));
	if (remaining < 0) {
		return -1;
	}
	int64_t half_width = compat::float_to_int(std::sqrt(static_cast<double>(remaining)));
	while (gd::mul(gd::add(half_width, 1), gd::add(half_width, 1)) <= remaining) {
		half_width = gd::add(half_width, 1);
	}
	while (gd::mul(half_width, half_width) > remaining) {
		half_width = gd::sub(half_width, 1);
	}
	return half_width;
}

int64_t movement_max_for_hero(State &state, DictRef hero_state, const Value &movement_source) {
	const DictRef artifact_bonuses = artifact_rules::aggregate_bonuses(state, hero_state);
	const DictRef specialty_bonuses = hero_progression_rules::aggregate_bonuses(state, hero_state);
	int64_t difficulty_bonus = 0;
	if (gd::is_dict(movement_source)) {
		difficulty_bonus = difficulty_rules::movement_bonus(state, movement_source);
	} else {
		if (movement_source.kind == state::Kind::Opaque) {
			throw state::NotPorted("left to GDScript: an object as the movement source");
		}
		const Atom difficulty_id = difficulty_rules::normalize_difficulty(state, gd::str(gd::stringify_or_fallback(state, movement_source)));
		difficulty_bonus = gd::int_field(state, difficulty_rules::profile_for_difficulty(state, gd::str(difficulty_id)), key::movement_bonus, 0);
	}
	int64_t movement = gd::int_field(state, hero_state, key::base_movement, 10);
	movement = gd::add(movement, compat::engine_max<int64_t>(0, gd::sub(gd::int_field(state, hero_state, key::level, 1), 1)));
	movement = gd::add(movement, gd::int_field(state, artifact_bonuses, key::overworld_movement, 0));
	movement = gd::add(movement, gd::int_field(state, specialty_bonuses, key::overworld_movement, 0));
	movement = gd::add(movement, difficulty_bonus);
	movement = gd::add(movement, _week_bonus(state, hero_state, key::movement));
	movement = gd::add(movement, compat::engine_max<int64_t>(0, gd::int_field(state, hero_state, key::movement_carry, 0)));
	return compat::engine_max<int64_t>(1, movement);
}

// Visit buildings can raise movement or mana until the week ends.
int64_t _week_bonus(State &state, DictRef hero_state, Atom field) {
	const Value bonuses = state.get(hero_state, gd::str(key::week_bonuses), gd::dict_value(state.new_dict()));
	return gd::is_dict(bonuses) ? gd::int_field(state, bonuses.ref, field, 0) : 0;
}

DictRef _normalize_position(State &state, const Value &value) {
	if (gd::is_dict(value)) {
		return overworld_level_rules::position(state, value.ref);
	}
	const DictRef result = state.new_dict();
	if (gd::is_vector3i(value) || gd::is_vector2i(value)) {
		state.set(result, gd::str(key::x), gd::int_value(value.vx()));
		state.set(result, gd::str(key::y), gd::int_value(value.vy()));
		if (gd::is_vector3i(value) && value.vz() != 0) {
			state.set(result, gd::str(key::level), gd::int_value(value.vz()));
		}
		return result;
	}
	state.set(result, gd::str(key::x), gd::int_value(0));
	state.set(result, gd::str(key::y), gd::int_value(0));
	return result;
}

} // namespace aurelion::rules::port::hero_command_rules
