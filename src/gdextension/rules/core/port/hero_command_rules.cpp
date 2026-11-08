// HeroCommandRules: a hero's sight.

#include "aurelion_rules/port/hero_command_rules.hpp"

#include "aurelion_rules/port/artifact_rules.hpp"
#include "aurelion_rules/port/hero_progression_rules.hpp"

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
	// Far Sight's tiles until the hero's next day starts (map_spells.hpp).
	const int64_t far_sight = compat::engine_max<int64_t>(0, gd::int_field(state, hero_state, key::map_sight_tiles, 0));
	return gd::add(compat::engine_max<int64_t>(1, radius), far_sight);
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

} // namespace aurelion::rules::port::hero_command_rules
