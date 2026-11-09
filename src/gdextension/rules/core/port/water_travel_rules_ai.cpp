// WaterTravelRules: the functions the AI targets reach (Phase 3), ported under
// their GDScript names.

#include "aurelion_rules/port/water_travel_rules_ai.hpp"

#include "aurelion_rules/compat/godot_string.hpp"
#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/content_service_ai.hpp"
#include "aurelion_rules/port/overworld_level_rules_ai.hpp"
#include "aurelion_rules/port/overworld_rules_ai.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/water_travel_rules.hpp"

#include <string>
#include <unordered_map>
#include <utility>
#include <vector>

namespace aurelion::rules::port {

namespace {

using gd::ArrayRef;
using gd::Atom;
using gd::bool_value;
using gd::dict_value;
using gd::DictRef;
using gd::int_value;
using gd::str;
using overworld_rules::Vector2i;
using state::Kind;
using state::State;
using state::Value;
namespace key = state::key;
namespace level_rules = overworld_level_rules;
// WaterTravelRules.NEIGHBORS.
const Vector2i kNeighbors[] = {{0, 1}, {-1, 0}, {1, 0}, {0, -1}, {-1, 1}, {1, 1}, {-1, -1}, {1, -1}};

// Town harbours (docs/water-travel.md, "Town shipyard"). A town has one when
// open sea lies within this many steps of its gate (owner decision, 2026-11-09).
constexpr int64_t kHarborReach = 6;
// Open sea: free water joined eight ways into a body of at least this many tiles.
constexpr int64_t kSeaTiles = 20;

// One level as the harbour search reads it.
struct HarborGrid {
	int64_t width = 0;
	int64_t height = 0;
	bool has_water = false;
	std::vector<uint8_t> water; // free water: water nothing stands or acts on
	std::vector<uint8_t> land; // ground a hero walks: passable, no body on it
	std::vector<uint8_t> sea; // a free-water tile: 0 not asked, 1 open sea, 2 a pond
};

bool split_pair(const std::string &text, int64_t &x, int64_t &y) {
	const size_t first = text.find(',');
	if (first == std::string::npos) {
		return false;
	}
	const size_t second = text.find(',', first + 1);
	x = compat::to_int(text.substr(0, first));
	y = compat::to_int(second == std::string::npos ? text.substr(first + 1) : text.substr(first + 1, second - first - 1));
	return true;
}

void take_water(HarborGrid &grid, int64_t x, int64_t y) {
	if (x >= 0 && y >= 0 && x < grid.width && y < grid.height) {
		grid.water[y * grid.width + x] = 0;
	}
}

void take_water(State &state, HarborGrid &grid, const Value &tiles) {
	for (const Vector2i tile : overworld_rules::_world_tiles_from_payload_array(state, tiles)) {
		take_water(grid, tile.x, tile.y);
	}
}

HarborGrid harbor_grid(State &state, DictRef session, int64_t level, int64_t width, int64_t height) {
	HarborGrid grid;
	if (width <= 0 || height <= 0 || level < 0 || level >= level_rules::level_count(state, session)) {
		return grid;
	}
	grid.width = width;
	grid.height = height;
	grid.water.assign(width * height, 0);
	grid.land.assign(width * height, 0);
	const level_rules::TerrainGrid terrain = level_rules::terrain_grid(state, dict_value(session), level);
	// Per terrain id: 1 water, 2 ground a hero walks, 0 neither.
	std::unordered_map<Atom, uint8_t> kinds;
	for (int64_t y = 0; y < height; ++y) {
		for (int64_t x = 0; x < width; ++x) {
			const Atom id = level_rules::terrain_grid_at(state, terrain, x, y);
			auto kind = kinds.find(id);
			if (kind == kinds.end()) {
				uint8_t value = 0;
				if (content_service::normalize_terrain_id(state, id) == key::water) {
					value = 1;
				} else if (overworld_rules::terrain_id_is_passable(state, id)) {
					value = 2;
				}
				kind = kinds.emplace(id, value).first;
			}
			if (kind->second == 1) {
				grid.water[y * width + x] = 1;
				grid.has_water = true;
			} else if (kind->second == 2) {
				grid.land[y * width + x] = 1;
			}
		}
	}
	if (!grid.has_water) {
		return grid;
	}
	grid.sea.assign(width * height, 0);
	// The bodies a walking hero goes around; guards move or fall, so none counts.
	const DictRef overworld = session_view::overworld(state, session);
	const DictRef every_encounter = state.new_dict();
	for (const Value &encounter : gd::field_items(state, overworld, str(key::encounters))) {
		if (gd::is_dict(encounter)) {
			state.set(every_encounter, str(overworld_rules::encounter_key(state, encounter.ref)), bool_value(true));
		}
	}
	const DictRef bodies = overworld_rules::_build_blocked_tile_index(state, session, level, key::empty, every_encounter);
	for (const Value &body_key : gd::items(state, dict_value(bodies))) {
		int64_t x = 0;
		int64_t y = 0;
		if (split_pair(state.text(gd::stringify(state, body_key)), x, y) && x >= 0 && y >= 0 && x < width && y < height) {
			grid.land[y * width + x] = 0;
			grid.water[y * width + x] = 0;
		}
	}
	// Water an object stands or acts on is no place for a boat.
	for (const Atom list : {key::resource_nodes, key::map_objects, key::artifact_nodes, key::towns}) {
		for (const Value &node : gd::field_items(state, overworld, str(list))) {
			if (!gd::is_dict(node) || level_rules::level_of(state, node) != level) {
				continue;
			}
			const Value body = gd::field(state, node.ref, key::body_tiles);
			take_water(state, grid, body);
			take_water(state, grid, gd::field(state, node.ref, key::package_visit_tiles));
			const Value visit = gd::field(state, node.ref, key::visit_tile);
			if (gd::is_dict(visit) && !gd::is_empty(state, visit.ref)) {
				take_water(grid, gd::int_field(state, visit.ref, key::x, -1), gd::int_field(state, visit.ref, key::y, -1));
			}
			if (!gd::is_array(body) || state.array_size(body.ref) == 0) {
				take_water(grid, gd::int_field(state, node.ref, key::x, -1), gd::int_field(state, node.ref, key::y, -1));
			}
		}
	}
	return grid;
}

// Whether a free-water tile lies in open sea. Every tile the fill visits shares
// the answer: it stops inside a body once that body is large enough.
bool open_sea(HarborGrid &grid, int64_t index) {
	if (grid.sea[index] != 0) {
		return grid.sea[index] == 1;
	}
	std::vector<int64_t> body{index};
	grid.sea[index] = 3;
	bool open = false;
	for (size_t at = 0; at < body.size() && !open; ++at) {
		const int64_t x = body[at] % grid.width;
		const int64_t y = body[at] / grid.width;
		for (const Vector2i delta : kNeighbors) {
			const int64_t next_x = x + delta.x;
			const int64_t next_y = y + delta.y;
			if (next_x < 0 || next_y < 0 || next_x >= grid.width || next_y >= grid.height) {
				continue;
			}
			const int64_t next = next_y * grid.width + next_x;
			if (!grid.water[next]) {
				continue;
			}
			if (grid.sea[next] == 1) {
				open = true;
				break;
			}
			if (grid.sea[next] == 0) {
				grid.sea[next] = 3;
				body.push_back(next);
			}
		}
		open = open || static_cast<int64_t>(body.size()) >= kSeaTiles;
	}
	for (const int64_t tile : body) {
		grid.sea[tile] = open ? 1 : 2;
	}
	return open;
}

// The first open-sea tile beside the ground a hero reaches from the gate within
// kHarborReach steps, eight ways: its index and the steps, or -1.
std::pair<int64_t, int64_t> find_harbor(HarborGrid &grid, Vector2i gate) {
	if (gate.x < 0 || gate.y < 0 || gate.x >= grid.width || gate.y >= grid.height) {
		return {-1, 0};
	}
	std::vector<int8_t> steps(grid.width * grid.height, -1);
	std::vector<int64_t> reached{gate.y * grid.width + gate.x};
	steps[reached[0]] = 0;
	for (size_t at = 0; at < reached.size(); ++at) {
		const int64_t x = reached[at] % grid.width;
		const int64_t y = reached[at] / grid.width;
		const int64_t walked = steps[reached[at]];
		for (int pass = 0; pass < 2; ++pass) {
			if (pass == 1 && walked >= kHarborReach) {
				break;
			}
			for (const Vector2i delta : kNeighbors) {
				const int64_t next_x = x + delta.x;
				const int64_t next_y = y + delta.y;
				if (next_x < 0 || next_y < 0 || next_x >= grid.width || next_y >= grid.height) {
					continue;
				}
				const int64_t next = next_y * grid.width + next_x;
				if (pass == 0) {
					if (grid.water[next] && open_sea(grid, next)) {
						return {next, walked};
					}
				} else if (steps[next] < 0 && grid.land[next]) {
					steps[next] = static_cast<int8_t>(walked + 1);
					reached.push_back(next);
				}
			}
		}
	}
	return {-1, 0};
}

} // namespace

namespace water_travel_rules {

void ensure_harbors(State &state, DictRef session) {
	const Value towns = gd::field(state, session_view::overworld(state, session), key::towns);
	if (!gd::is_array(towns)) {
		return;
	}
	std::vector<DictRef> unchecked;
	for (const Value &town : gd::items(state, towns)) {
		if (gd::is_dict(town) && !state.has(town.ref, str(key::harbor))) {
			unchecked.push_back(town.ref);
		}
	}
	if (unchecked.empty()) {
		return;
	}
	// A town on a level without water keeps no entry, so a land map's towns stay
	// as they were; the number left over says the search already ran.
	const DictRef meta = session_view::meta(state, session);
	Value left_before;
	if (state.lookup(meta, gd::name_value(key::harbors_checked), left_before) && gd::to_int(state, left_before) == static_cast<int64_t>(unchecked.size())) {
		return;
	}
	const Vector2i size = overworld_rules::derive_map_size(state, session);
	std::unordered_map<int64_t, HarborGrid> grids;
	int64_t left = 0;
	for (const DictRef town : unchecked) {
		const int64_t level = level_rules::level_of(state, dict_value(town));
		auto grid = grids.find(level);
		if (grid == grids.end()) {
			grid = grids.emplace(level, harbor_grid(state, session, level, size.x, size.y)).first;
		}
		if (!grid->second.has_water) {
			++left;
			continue;
		}
		const DictRef gate = level_rules::town_entrance(state, town);
		const std::pair<int64_t, int64_t> found = find_harbor(grid->second, Vector2i::of(gd::int_field(state, gate, key::x, -1), gd::int_field(state, gate, key::y, -1)));
		const DictRef harbor = state.new_dict();
		if (found.first >= 0) {
			state.set(harbor, str(key::x), int_value(found.first % grid->second.width));
			state.set(harbor, str(key::y), int_value(found.first / grid->second.width));
			state.set(harbor, str(key::level), int_value(level));
			state.set(harbor, str(key::steps), int_value(found.second));
		}
		state.set(town, str(key::harbor), dict_value(harbor));
	}
	state.set(meta, gd::name_value(key::harbors_checked), int_value(left));
}

bool town_has_harbor(State &state, DictRef town) {
	Value harbor;
	return state.lookup(town, str(key::harbor), harbor) && gd::is_dict(harbor) && !gd::is_empty(state, harbor.ref);
}

bool needs_missing_harbor(State &state, DictRef town, DictRef building) {
	return gd::bool_field(state, building, key::shipyard, false) && !town_has_harbor(state, town);
}

Atom town_shipyard_id(State &state, DictRef town) {
	if (!town_has_harbor(state, town)) {
		return key::empty;
	}
	for (const Value &built : gd::field_items(state, town, str(key::built_buildings))) {
		const Atom building_id = gd::stringify(state, built);
		if (gd::bool_field(state, gd::content_row(state, state::ContentTable::Building, building_id), key::shipyard, false)) {
			return building_id;
		}
	}
	return key::empty;
}

Atom harbor_line(State &state, DictRef town, Atom walk, Atom beside) {
	Value harbor;
	const int64_t steps = state.lookup(town, str(key::harbor), harbor) && gd::is_dict(harbor) ? gd::int_field(state, harbor.ref, key::steps, 0) : 0;
	if (steps <= 0) {
		return beside;
	}
	return gd::format(state, walk, {str(gd::format(state, steps == 1 ? key::d_step : key::d_steps, {int_value(steps)}))});
}

ArrayRef boats(State &state, const Value &session) {
	if (session.kind == Kind::Nil) {
		return state.new_array();
	}
	Value value;
	if (state.lookup(session_view::overworld(state, session.ref), str(key::boats), value) && gd::is_array(value)) {
		return value.ref;
	}
	return state.new_array();
}

Atom hero_boat_id(State &state, const Value &hero) {
	return gd::is_dict(hero) ? ai::string_or_empty(state, hero.ref, key::boat_id) : key::empty;
}

bool is_water(State &state, const Value &session, int64_t x, int64_t y, int64_t level) {
	const ArrayRef rows = level_rules::terrain_rows(state, session, level);
	if (y < 0 || y >= state.array_size(rows) || !gd::is_array(state.at(rows, y))) {
		return false;
	}
	const ArrayRef row = gd::as_array(state.at(rows, y));
	if (x < 0 || x >= state.array_size(row)) {
		return false;
	}
	return content_service::normalize_terrain_id(state, gd::stringify(state, state.at(row, x))) == key::water;
}

DictRef dock_tile(State &state, const Value &session, DictRef node) {
	// A town launches at its harbour (ensure_harbors), a walk from its walls.
	Value harbor;
	if (state.lookup(node, str(key::harbor), harbor)) {
		const DictRef dock = state.new_dict();
		if (gd::is_dict(harbor) && !gd::is_empty(state, harbor.ref)) {
			state.set(dock, str(key::x), int_value(gd::int_field(state, harbor.ref, key::x, -1)));
			state.set(dock, str(key::y), int_value(gd::int_field(state, harbor.ref, key::y, -1)));
			state.set(dock, str(key::level), int_value(gd::int_field(state, harbor.ref, key::level, 0)));
		}
		return dock;
	}
	const int64_t level = level_rules::level_of(state, dict_value(node));
	// visit: an empty Dictionary when missing or not one.
	Value visit;
	const bool has_visit = state.lookup(node, str(key::visit_tile), visit) && gd::is_dict(visit);
	const Value node_x = gd::field_or(state, node, key::x, int_value(0));
	const int64_t origin_x = gd::to_int(state, has_visit ? state.get(visit.ref, str(key::x), node_x) : node_x);
	const Value node_y = gd::field_or(state, node, key::y, int_value(0));
	const int64_t origin_y = gd::to_int(state, has_visit ? state.get(visit.ref, str(key::y), node_y) : node_y);
	const Vector2i origin = Vector2i::of(origin_x, origin_y);
	overworld_rules::Tiles sources{origin};
	for (const Value &tile : gd::field_items(state, node, str(key::body_tiles))) {
		if (gd::is_dict(tile)) {
			sources.push_back(Vector2i::of(gd::int_field(state, tile.ref, key::x, 0), gd::int_field(state, tile.ref, key::y, 0)));
		}
	}
	Vector2i best = Vector2i::of(-1, -1);
	int64_t best_distance = int64_t{1} << 30;
	for (const Vector2i source : sources) {
		for (const Vector2i delta : kNeighbors) {
			const Vector2i tile = source + delta;
			if (!is_water(state, session, tile.x, tile.y, level)) {
				continue;
			}
			// Vector2i.length_squared(): x * int64(x) + y * int64(y).
			const Vector2i offset = tile - origin;
			const int64_t distance = gd::add(gd::mul(offset.x, offset.x), gd::mul(offset.y, offset.y));
			if (distance < best_distance) {
				best_distance = distance;
				best = tile;
			}
		}
	}
	if (best.x < 0) {
		return state.new_dict();
	}
	const DictRef dock = state.new_dict();
	state.set(dock, str(key::x), int_value(best.x));
	state.set(dock, str(key::y), int_value(best.y));
	state.set(dock, str(key::level), int_value(level));
	return dock;
}

} // namespace water_travel_rules

} // namespace aurelion::rules::port
