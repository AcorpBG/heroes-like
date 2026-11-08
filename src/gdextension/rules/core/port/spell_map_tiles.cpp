// The map spells aimed at a tile the player picks (docs/magic-system-spells.md, Map; map_spells.hpp): Flare scouts
// the ground around a tile far off, Firebreak closes a tile next to the hero to every army, and Rootway, Relay, Ferry
// Call and Mist Jump move the army to a tile at a distance: beside trees, to a town of its side, across water, and to
// any free tile even past guards. The tiles each one reaches, the prompt to pick one, and what a cast there does.
#include "aurelion_rules/port/map_spells.hpp"

#include "aurelion_rules/compat/godot_math.hpp"
#include "aurelion_rules/port/hero_command_rules_ai.hpp"
#include "aurelion_rules/port/overworld_level_rules.hpp"
#include "aurelion_rules/port/overworld_rules_human.hpp"
#include "aurelion_rules/port/player_identity_rules.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/water_travel_rules_ai.hpp"

#include <algorithm>
#include <iterator>
#include <unordered_set>

namespace aurelion::rules::port::map_spells {

using compat::engine_max;
using compat::engine_min;
using gd::bool_value;
using gd::dict_value;
using gd::int_value;
using gd::str;
namespace key = state::key;
namespace levels = overworld_level_rules;

namespace {

// The woods of a generated map: obstacles of these object types (Oak Trees, Pine Trees, Trees).
constexpr int64_t kTreeTypes[] = {135, 137, 155};

constexpr int32_t kDirections[8][2] = {{-1, -1}, {0, -1}, {1, -1}, {-1, 0}, {1, 0}, {-1, 1}, {0, 1}, {1, 1}};

uint64_t tile_key(Vector2i tile) {
	return (static_cast<uint64_t>(static_cast<uint32_t>(tile.x)) << 32) | static_cast<uint32_t>(tile.y);
}

Vector2i tile_of(State &state, DictRef record) {
	return Vector2i::of(gd::int_field(state, record, key::x, 0), gd::int_field(state, record, key::y, 0));
}

int64_t term(State &state, DictRef hero, DictRef spell, Atom name) {
	return engine_max<int64_t>(0, gd::int_field(state, terms(state, hero, spell), name, 0));
}

bool within(State &state, Vector2i from, Vector2i to, int64_t range) {
	return hero_command_rules::within_scout_radius(state, static_cast<int64_t>(to.x) - from.x, static_cast<int64_t>(to.y) - from.y, range);
}

bool by_rows(Vector2i a, Vector2i b) {
	return a.y != b.y ? a.y < b.y : a.x < b.x;
}

// Whether the town is the caster's: the human seat's own, or a computer player's by its controller.
bool own_town(State &state, DictRef town, Atom controller) {
	const Atom owner = gd::string_field(state, town, key::owner, key::neutral);
	if (controller == key::player) {
		return owner == key::player;
	}
	return owner == key::enemy && player_identity_rules::town_controller_id(state, town) == controller;
}

// What stands on the caster's level: every hero and army, which no army lands on, and the trees when they count.
class Ground {
public:
	Ground(State &state, DictRef session, const Caster &caster, bool trees) : state_(state), session_(session), caster_(caster) {
		size_ = overworld_rules::derive_map_size(state, session);
		const DictRef overworld = session_view::overworld(state, session);
		const Value active = gd::field(state, overworld, key::hero);
		if (gd::is_dict(active)) {
			add_hero(active);
		}
		for (const Value &hero : gd::field_items(state, overworld, str(key::player_heroes))) {
			if (gd::is_dict(hero)) {
				add_hero(hero);
			}
		}
		for (const Value &encounter : gd::field_items(state, overworld, str(key::encounters))) {
			if (gd::is_dict(encounter) && levels::level_of(state, encounter) == caster.level && !overworld_rules::is_encounter_resolved(state, session, encounter.ref)) {
				occupied_.insert(tile_key(tile_of(state, encounter.ref)));
			}
		}
		if (!trees) {
			return;
		}
		for (const Value &object : gd::field_items(state, overworld, str(key::map_objects))) {
			if (!gd::is_dict(object) || !levels::on_level(state, object, caster.level)) {
				continue;
			}
			const int64_t type = gd::int_field(state, object.ref, key::h3m_type_id, -1);
			if (std::find(std::begin(kTreeTypes), std::end(kTreeTypes), type) == std::end(kTreeTypes)) {
				continue;
			}
			for (const Vector2i tile : overworld_rules::_generated_body_tiles_for_placement(state, object.ref, true)) {
				trees_.insert(tile_key(tile));
			}
		}
	}

	bool in_bounds(Vector2i tile) const {
		return tile.x >= 0 && tile.y >= 0 && tile.x < size_.x && tile.y < size_.y;
	}

	bool occupied(Vector2i tile) const {
		return occupied_.count(tile_key(tile)) != 0;
	}

	bool water(Vector2i tile) const {
		return water_travel_rules::is_water(state_, dict_value(session_), tile.x, tile.y, caster_.level);
	}

	// Land an army can stand on with nothing on it and no guard watching it, not where the caster stands.
	bool free(Vector2i tile) const {
		if (!in_bounds(tile) || tile == caster_.tile || occupied(tile) || water(tile)) {
			return false;
		}
		if (overworld_rules::tile_is_blocked(state_, session_, tile.x, tile.y, caster_.level)) {
			return false;
		}
		return !overworld_rules::tile_has_route_interaction(state_, session_, tile.x, tile.y, caster_.level, false);
	}

	bool beside_trees(Vector2i tile) const {
		for (const auto &step : kDirections) {
			if (trees_.count(tile_key(Vector2i::of(tile.x + step[0], tile.y + step[1]))) != 0) {
				return true;
			}
		}
		return false;
	}

	Vector2i size() const { return size_; }

private:
	void add_hero(const Value &hero) {
		const Value position = gd::field(state_, hero.ref, key::position);
		if (gd::is_dict(position) && !gd::is_empty(state_, position.ref) && levels::level_of(state_, position) == caster_.level) {
			occupied_.insert(tile_key(tile_of(state_, position.ref)));
		}
	}

	State &state_;
	DictRef session_;
	const Caster &caster_;
	Vector2i size_;
	std::unordered_set<uint64_t> occupied_;
	std::unordered_set<uint64_t> trees_;
};

} // namespace

bool needs_tile(State &state, DictRef spell) {
	const Atom kind = mechanic(state, spell);
	return kind == key::map_flare || kind == key::map_block || kind == key::map_jump_forest || kind == key::map_town ||
			kind == key::map_ferry || kind == key::map_jump;
}

std::vector<Vector2i> target_tiles(State &state, DictRef session, const Caster &caster, DictRef spell) {
	std::vector<Vector2i> tiles;
	if (!needs_tile(state, spell)) {
		return tiles;
	}
	const Atom kind = mechanic(state, spell);
	const Ground ground(state, session, caster, kind == key::map_jump_forest);
	if (kind == key::map_block) {
		for (int32_t dy = -1; dy <= 1; ++dy) {
			for (int32_t dx = -1; dx <= 1; ++dx) {
				const Vector2i tile = Vector2i::of(caster.tile.x + dx, caster.tile.y + dy);
				if ((dx != 0 || dy != 0) && ground.free(tile)) {
					tiles.push_back(tile);
				}
			}
		}
		return tiles;
	}
	const int64_t range = term(state, caster.hero, spell, key::range);
	if (kind == key::map_ferry) {
		for (const auto &step : kDirections) {
			int64_t water = 0;
			for (int64_t distance = 1;; ++distance) {
				const Vector2i tile = Vector2i::of(caster.tile.x + static_cast<int32_t>(step[0] * distance), caster.tile.y + static_cast<int32_t>(step[1] * distance));
				if (!ground.in_bounds(tile)) {
					break;
				}
				if (ground.water(tile)) {
					water += 1;
					if (water > range) {
						break;
					}
					continue;
				}
				if (water > 0 && ground.free(tile)) {
					tiles.push_back(tile);
				}
				break;
			}
		}
		std::sort(tiles.begin(), tiles.end(), by_rows);
		return tiles;
	}
	if (kind == key::map_town) {
		for (const Value &town : gd::field_items(state, session_view::overworld(state, session), str(key::towns))) {
			if (!gd::is_dict(town) || !levels::on_level(state, town, caster.level) || !own_town(state, town.ref, caster.controller)) {
				continue;
			}
			const Vector2i gate = tile_of(state, levels::town_entrance(state, town.ref));
			if (!ground.in_bounds(gate) || gate == caster.tile || ground.occupied(gate) || !within(state, caster.tile, gate, range)) {
				continue;
			}
			if (std::find(tiles.begin(), tiles.end(), gate) == tiles.end()) {
				tiles.push_back(gate);
			}
		}
		std::sort(tiles.begin(), tiles.end(), by_rows);
		return tiles;
	}
	const Vector2i size = ground.size();
	const int64_t top = engine_max<int64_t>(0, static_cast<int64_t>(caster.tile.y) - range);
	const int64_t bottom = engine_min<int64_t>(static_cast<int64_t>(size.y) - 1, static_cast<int64_t>(caster.tile.y) + range);
	const int64_t left = engine_max<int64_t>(0, static_cast<int64_t>(caster.tile.x) - range);
	const int64_t right = engine_min<int64_t>(static_cast<int64_t>(size.x) - 1, static_cast<int64_t>(caster.tile.x) + range);
	for (int64_t y = top; y <= bottom; ++y) {
		for (int64_t x = left; x <= right; ++x) {
			const Vector2i tile = Vector2i::of(static_cast<int32_t>(x), static_cast<int32_t>(y));
			if (!within(state, caster.tile, tile, range)) {
				continue;
			}
			if (kind == key::map_flare) {
				tiles.push_back(tile);
				continue;
			}
			if (!ground.free(tile) || (kind == key::map_jump_forest && !ground.beside_trees(tile))) {
				continue;
			}
			tiles.push_back(tile);
		}
	}
	return tiles;
}

Atom aim_text(State &state, DictRef hero, DictRef spell) {
	const Atom kind = mechanic(state, spell);
	const int64_t range = term(state, hero, spell, key::range);
	if (kind == key::map_flare) {
		return gd::format(state, key::map_aim_flare_text, {int_value(range)});
	}
	if (kind == key::map_block) {
		return key::map_aim_block_text;
	}
	if (kind == key::map_jump_forest) {
		return gd::format(state, key::map_aim_forest_text, {int_value(range)});
	}
	if (kind == key::map_town) {
		return gd::format(state, key::map_aim_town_text, {int_value(range)});
	}
	if (kind == key::map_ferry) {
		return gd::format(state, key::map_aim_ferry_text, {int_value(range)});
	}
	if (kind == key::map_jump) {
		return gd::format(state, key::map_aim_jump_text, {int_value(range)});
	}
	return key::empty;
}

DictRef apply_at(State &state, DictRef session, const Caster &caster, DictRef spell, Vector2i tile, int64_t day) {
	const DictRef result = state.new_dict();
	const Atom kind = mechanic(state, spell);
	if (kind == key::map_flare) {
		state.set(result, str(key::reveal_radius), int_value(term(state, caster.hero, spell, key::radius)));
		return result;
	}
	if (kind == key::map_block) {
		Caster at = caster;
		at.tile = tile;
		apply_to_map(state, session, at, spell, day);
		overworld_rules::_refresh_blocked_tile_index(state, session);
		return result;
	}
	state.set(result, str(key::move_to), Value::of_vector2i(tile.x, tile.y));
	state.set(result, str(key::ends_movement), bool_value(kind == key::map_town || kind == key::map_ferry));
	return result;
}

} // namespace aurelion::rules::port::map_spells
