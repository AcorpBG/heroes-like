// AiHeroRules: what opening the way past a guard or a site's doorway is worth,
// and which guard stands first on the way to each town out of reach.

#include "aurelion_rules/port/ai_hero_rules_ai.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/overworld_level_rules.hpp"
#include "aurelion_rules/port/session_view.hpp"

#include <cstdint>
#include <string>
#include <vector>

namespace aurelion::rules::port {

namespace {

using gd::array_value;
using gd::ArrayRef;
using gd::Atom;
using gd::dict_value;
using gd::DictRef;
using gd::float_value;
using gd::int_value;
using gd::PackedRef;
using gd::str;
using overworld_rules::Vector2i;
using state::State;
using state::Value;
namespace key = state::key;
namespace level_rules = overworld_level_rules;

constexpr int64_t kNeighborDx[8] = {1, -1, 0, 0, 1, 1, -1, -1};
constexpr int64_t kNeighborDy[8] = {0, 0, 1, -1, 1, -1, 1, -1};
constexpr int64_t kStopResource = 1;
constexpr int64_t kStopArtifact = 2;
constexpr int64_t kStopTown = 3;

[[noreturn]] void out_of_bounds(int64_t index, const char *base, bool set) {
	throw state::ScriptError(std::string("Out of bounds ") + (set ? "set" : "get") + " index '" + std::to_string(index) + "' (on base: '" + base + "')");
}

// The element a[index] names in a packed array of this size (negative from the end).
size_t cell(int64_t index, size_t size, const char *base, bool set) {
	const int64_t count = static_cast<int64_t>(size);
	const int64_t position = index < 0 ? index + count : index;
	if (position < 0 || position >= count) {
		out_of_bounds(index, base, set);
	}
	return static_cast<size_t>(position);
}

// A packed array of the search read in place: valid while it does not change.
template <typename T>
struct View {
	const T *data = nullptr;
	size_t size = 0;
	const char *base = "";
	int64_t operator[](int64_t index) const { return data[cell(index, size, base, false)]; }
};

View<uint8_t> bytes_view(const State &state, PackedRef packed) {
	return {gd::packed_bytes(state, packed), static_cast<size_t>(gd::packed_size(state, packed)), "PackedByteArray"};
}

View<int32_t> ints_view(const State &state, PackedRef packed) {
	return {gd::packed_ints(state, packed), static_cast<size_t>(gd::packed_size(state, packed)), "PackedInt32Array"};
}

// search.get(name, PackedByteArray()) read only: empty when missing.
View<uint8_t> optional_bytes(const State &state, DictRef search, Atom name) {
	Value found;
	if (!state.lookup(search, str(name), found)) {
		return {nullptr, 0, "PackedByteArray"};
	}
	return bytes_view(state, gd::as_bytes(found));
}

// A PackedByteArray or PackedInt32Array the function makes, resizes to count
// (zeros) and keeps to itself.
template <typename T>
struct Local {
	std::vector<T> items;
	const char *base;
	Local(int64_t count, const char *base_name) :
			base(base_name) {
		if (count > 0) {
			items.assign(static_cast<size_t>(count), T(0));
		}
	}
	int64_t get(int64_t index) const { return items[cell(index, items.size(), base, false)]; }
	void set(int64_t index, int64_t value) { items[cell(index, items.size(), base, true)] = static_cast<T>(value); }
};

// What a.resize(count) prints for a negative size.
void resize_check(const State &state, int64_t count) {
	if (count < 0) {
		state.print_error("Condition \"p_size < 0\" is true. Returning: ERR_INVALID_PARAMETER");
	}
}

Value as_vector2i(const Value &value) {
	if (!gd::is_vector2i(value)) {
		throw state::ScriptError(std::string("Trying to assign value of type '") + gd::type_name(value) + "' to a variable of type 'Vector2i'.");
	}
	return value;
}

int64_t int_mod(int64_t a, int64_t b) {
	if (b == 0) {
		throw state::ScriptError("Division by zero error in operator '%'.");
	}
	return compat::int_mod(a, b);
}

int64_t int_div(int64_t a, int64_t b) {
	if (b == 0) {
		throw state::ScriptError("Division by zero error in operator '/'.");
	}
	return compat::int_div(a, b);
}

// maxi(1, int(entry.get(AI_HERO_KEY, {}).get("movement", {}).get("max", 1))).
int64_t planned_movement_max(State &state, DictRef entry) {
	Value max_value = int_value(1);
	Value ai_hero;
	if (state.lookup(entry, str(key::ai_hero), ai_hero)) {
		if (!gd::is_dict(ai_hero)) {
			throw state::ScriptError(std::string("Invalid call. Nonexistent function 'get' in base '") + gd::type_name(ai_hero) + "'.");
		}
		Value movement;
		if (state.lookup(ai_hero.ref, str(key::movement), movement)) {
			max_value = ai::vget(state, movement, key::max, int_value(1));
		}
	}
	return compat::engine_max<int64_t>(1, gd::to_int(state, max_value));
}

} // namespace

namespace ai_hero_rules {

double _opened_value(State &state, DictRef session, DictRef context, DictRef entry, DictRef search, int64_t passage_key, ArrayRef origin, DictRef needs) {
	if (!state.has(search, str(key::blocked))) {
		return 0.0;
	}
	Value found;
	const DictRef cache = state.lookup(search, str(key::passage_cache), found) ? gd::as_dict(found) : state.new_dict();
	const Value cache_key = int_value(passage_key);
	if (state.lookup(cache, cache_key, found)) {
		return gd::to_float(found);
	}
	const DictRef opened = state.lookup(search, str(key::passage_unexplored), found) ? gd::as_dict(found) : state.new_dict();
	const Value size = as_vector2i(gd::index(state, search, str(key::size)));
	const PackedRef dist = gd::as_ints(gd::index(state, search, str(key::dist)));
	const PackedRef blocked = gd::as_bytes(gd::index(state, search, str(key::blocked)));
	const PackedRef guard_mask = gd::as_bytes(gd::index(state, search, str(key::guard_mask)));
	const PackedRef known = _explored(state, session, context, level_rules::level_of(state, dict_value(entry)));
	const View<uint8_t> stop_at = optional_bytes(state, search, key::stop_mask);
	const View<uint8_t> pass_at = optional_bytes(state, search, key::pass_mask);
	int64_t horizon = -1;
	if (gd::bool_field(state, search, key::capped, false)) {
		horizon = gd::int_field(state, search, key::radius, -1);
	}
	// Flood out from the guard's zone over open ground the search did not reach,
	// stopping at other guards' zones, one stretch of ground at a time; a
	// stretch that meets a tile where the search stopped for distance is not
	// behind the guard.
	const int64_t width = size.vx();
	const int64_t height = size.vy();
	resize_check(state, width * height);
	Local<uint8_t> seen(width * height, "PackedByteArray");
	for (const Value &zone_index : gd::items(state, array_value(origin))) {
		seen.set(gd::to_int(state, zone_index), 1);
	}
	const View<int32_t> dist_at = ints_view(state, dist);
	const View<uint8_t> blocked_at = bytes_view(state, blocked);
	const View<uint8_t> guard_at = bytes_view(state, guard_mask);
	const int64_t tile_cap = ai::static_int(state, key::ai_hero_rules_script, key::PASSAGE_TILE_CAP);
	std::vector<int64_t> region;
	int64_t flooded = 0;
	for (const Value &zone_index : gd::items(state, array_value(origin))) {
		const int64_t zone_tile = gd::to_int(state, zone_index);
		for (int64_t start_direction = 0; start_direction < 8; ++start_direction) {
			const int64_t sx = int_mod(zone_tile, width) + kNeighborDx[start_direction];
			const int64_t sy = int_div(zone_tile, width) + kNeighborDy[start_direction];
			if (sx < 0 || sy < 0 || sx >= width || sy >= height) {
				continue;
			}
			const int64_t start = sy * width + sx;
			if (flooded >= tile_cap || seen.get(start) != 0 || dist_at[start] >= 0 || blocked_at[start] != 0 || guard_at[start] != 0) {
				continue;
			}
			seen.set(start, 1);
			std::vector<int64_t> stretch{start};
			size_t head = 0;
			bool open_to_hero = false;
			while (head < stretch.size() && flooded < tile_cap && !open_to_hero) {
				const int64_t tile = stretch[head];
				head += 1;
				flooded += 1;
				const int64_t x = int_mod(tile, width);
				const int64_t y = int_div(tile, width);
				for (int64_t direction = 0; direction < 8; ++direction) {
					const int64_t nx = x + kNeighborDx[direction];
					const int64_t ny = y + kNeighborDy[direction];
					if (nx < 0 || ny < 0 || nx >= width || ny >= height) {
						continue;
					}
					const int64_t next = ny * width + nx;
					if (dist_at[next] >= 0) {
						if (horizon >= 0 && dist_at[next] >= horizon && (stop_at.size == 0 || stop_at[next] == 0 || pass_at[next] != 0)) {
							open_to_hero = true;
						}
						continue;
					}
					if (seen.get(next) != 0 || blocked_at[next] != 0 || guard_at[next] != 0) {
						continue;
					}
					seen.set(next, 1);
					stretch.push_back(next);
				}
			}
			if (!open_to_hero) {
				region.insert(region.end(), stretch.begin(), stretch.end());
			}
		}
	}
	double value = 0.0;
	if (!region.empty()) {
		const bool has_static_stops = state.lookup(search, str(key::static_stops), found);
		const DictRef static_stops = has_static_stops ? gd::as_dict(found) : 0;
		const double power = hero_power(state, entry);
		int64_t unexplored = 0;
		double sites = 0.0;
		double towns = 0.0;
		const auto weigh = [&](const Value &ref) {
			const int64_t kind = gd::to_int(state, ai::vmember(state, ref, key::kind));
			if (kind == kStopResource || kind == kStopArtifact) {
				const DictRef candidate = _candidate(state, session, context, entry, gd::as_dict(ref), power, needs, state.new_dict());
				sites += gd::float_field(state, candidate, key::value, 0.0);
			} else if (kind == kStopTown) {
				const DictRef candidate = _candidate(state, session, context, entry, gd::as_dict(ref), power, needs, state.new_dict());
				towns += gd::float_field(state, candidate, key::value, 0.0);
			}
		};
		for (const int64_t tile : region) {
			if (gd::packed_int(state, known, tile) == 0) {
				unexplored += 1;
				continue;
			}
			Value refs;
			if (!has_static_stops || !state.lookup(static_stops, int_value(tile), refs)) {
				continue;
			}
			// The candidates run between the items: read the Array live, as GDScript does.
			if (gd::is_array(refs)) {
				for (int64_t at = 0; at < state.array_size(refs.ref); ++at) {
					weigh(state.at(refs.ref, at));
				}
			} else {
				for (const Value &ref : gd::items(state, refs)) {
					weigh(ref);
				}
			}
		}
		const double value_cap = ai::static_float(state, key::ai_hero_rules_script, key::PASSAGE_VALUE_CAP);
		const double base_value = ai::static_float(state, key::ai_hero_rules_script, key::PASSAGE_BASE_VALUE);
		const double tile_value = ai::static_float(state, key::ai_hero_rules_script, key::PASSAGE_UNEXPLORED_TILE_VALUE);
		const double site_share = ai::static_float(state, key::ai_hero_rules_script, key::PASSAGE_KNOWN_SITE_SHARE);
		value = compat::engine_min(value_cap, base_value + static_cast<double>(unexplored) * tile_value + sites * site_share);
		// Towns are worth the fight on their own: they are not held to the cap.
		value += towns * site_share;
		// While a rival is still standing whose towns this player has not found,
		// unexplored ground is where they are.
		if (unexplored > 0 && _rival_towns_unknown(state, session, context)) {
			const double elimination = ai::static_float(state, key::ai_hero_rules_script, key::ELIMINATION_VALUE);
			const double hidden_share = ai::static_float(state, key::ai_hero_rules_script, key::HIDDEN_RIVAL_SHARE);
			const int64_t hidden_tiles = ai::static_int(state, key::ai_hero_rules_script, key::HIDDEN_RIVAL_TILES);
			value += elimination * hidden_share * compat::engine_min(1.0, static_cast<double>(unexplored) / static_cast<double>(hidden_tiles));
		}
		state.set(opened, cache_key, int_value(unexplored));
		state.set(search, str(key::passage_unexplored), dict_value(opened));
	}
	// The guard that stands first on the way to a town out of reach opens the
	// road to it, however many guards lie beyond.
	const double war = gd::to_float(state.get(_war_paths(state, session, context, entry, search, needs), cache_key, float_value(0.0)));
	value += war * ai::static_float(state, key::ai_hero_rules_script, key::PASSAGE_KNOWN_SITE_SHARE);
	state.set(cache, cache_key, float_value(value));
	state.set(search, str(key::passage_cache), dict_value(cache));
	return value;
}

DictRef _war_paths(State &state, DictRef session, DictRef context, DictRef entry, DictRef search, DictRef needs) {
	(void)needs;
	Value found;
	if (state.lookup(search, str(key::war_paths), found)) {
		return gd::as_dict(found);
	}
	const DictRef result = state.new_dict();
	state.set(search, str(key::war_paths), dict_value(result));
	if (!state.has(search, str(key::blocked)) || !state.has(search, str(key::guard_zones))) {
		return result;
	}
	const Value size = as_vector2i(gd::index(state, search, str(key::size)));
	const int64_t width = size.vx();
	const int64_t height = size.vy();
	const int64_t count = width * height;
	const PackedRef dist = gd::as_ints(gd::index(state, search, str(key::dist)));
	const PackedRef blocked = gd::as_bytes(gd::index(state, search, str(key::blocked)));
	const int64_t level = level_rules::level_of(state, dict_value(entry));
	const PackedRef known = _explored(state, session, context, level);
	const double power = hero_power(state, entry);
	// Doors of known towns out of reach, with what each is worth to this hero.
	const DictRef targets = state.new_dict();
	Value towns_value;
	if (state.lookup(session_view::overworld(state, session), str(key::towns), towns_value)) {
		const ArrayRef towns = gd::as_array(towns_value);
		const int64_t town_count = state.array_size(towns);
		const Vector2i town_size = Vector2i::of(width, height);
		for (int64_t index = 0; index < town_count; ++index) {
			const Value town = state.at(towns, index);
			if (!gd::is_dict(town) || level_rules::level_of(state, town) != level) {
				continue;
			}
			const DictRef entrance = level_rules::town_entrance(state, town.ref);
			const int64_t door_y = gd::int_field(state, entrance, key::y, 0);
			const int64_t door_x = gd::int_field(state, entrance, key::x, 0);
			const int64_t door = gd::add(gd::mul(door_y, width), door_x);
			// A doorway in a hostile hero's zone is reached through that fight.
			if (door < 0 || door >= count || (gd::packed_int(state, dist, door) >= 0 && !_in_hero_zone(state, search, door)) || !_town_seen(state, known, town.ref, town_size)) {
				continue;
			}
			const double value = gd::float_field(state, _town_candidate(state, session, context, entry, index, power), key::value, 0.0);
			if (value > 0.0) {
				const Value door_key = int_value(door);
				const double best = gd::to_float(state.get(targets, door_key, float_value(0.0)));
				state.set(targets, door_key, float_value(compat::engine_max(best, value)));
			}
		}
	}
	// A gate out of reach that starts a main or field army's way to a town or
	// to unseen ground on other stretches (`_gate_routes`).
	if (_plans_far(state, session, context, entry)) {
		const int64_t movement_max = planned_movement_max(state, entry);
		const DictRef routes = _gate_routes(state, session, context, entry, search, movement_max);
		for (const Value &gate_tile : gd::items(state, dict_value(routes))) {
			const int64_t gate = gd::to_int(state, gate_tile);
			if (gate < count && gd::packed_int(state, dist, gate) < 0) {
				const Value gate_key = int_value(gate);
				const double best = gd::to_float(state.get(targets, gate_key, float_value(0.0)));
				const double route = gd::to_float(ai::vmember(state, gd::index(state, routes, gate_tile), key::value));
				state.set(targets, gate_key, float_value(compat::engine_max(best, route)));
			}
		}
	}
	if (gd::is_empty(state, targets)) {
		return result;
	}
	// guard_at: GDScript's Dictionary of tile -> guard key, kept as the walk reads
	// it (`guarded`, `guard_key`): only its keys on the map are ever read.
	Local<uint8_t> guarded(count, "PackedByteArray");
	Local<int32_t> guard_key(count, "PackedInt32Array");
	const auto guard_at = [&](int64_t tile, int64_t guard) {
		if (tile >= 0 && tile < count) {
			guarded.set(tile, 1);
			guard_key.set(tile, guard);
		}
	};
	const DictRef zones = gd::as_dict(gd::index(state, search, str(key::guard_zones)));
	for (const Value &guard_index : gd::items(state, dict_value(zones))) {
		const Value zone = gd::index(state, zones, guard_index);
		for (const Value &tile : gd::items(state, zone)) {
			const int64_t zone_tile = gd::to_int(state, tile);
			guard_at(zone_tile, gd::to_int(state, guard_index));
		}
	}
	for (const Value &door : gd::items(state, dict_value(_site_doors(state, search)))) {
		const int64_t door_tile = gd::to_int(state, door);
		guard_at(door_tile, _site_door_key(state, door_tile));
	}
	// A hostile hero in the way is fought there like a guard, under
	// `_hero_war_key`.
	const ArrayRef hero_guards = _hero_guards(state, session, context, level);
	for (int64_t guard_position = 0; guard_position < state.array_size(hero_guards); ++guard_position) {
		const Value hero_guard = state.at(hero_guards, guard_position);
		if (!gd::to_bool(ai::vmember(state, hero_guard, key::hostile))) {
			continue;
		}
		const Atom ref_kind = gd::stringify(state, ai::vmember(state, hero_guard, key::ref_kind));
		const int64_t hero_key = _hero_war_key(state, ref_kind, gd::to_int(state, ai::vmember(state, hero_guard, key::index)));
		const Value guard_tile = ai::vmember(state, hero_guard, key::tile);
		const Value tile_arg = as_vector2i(guard_tile);
		const ArrayRef zone_tiles = _hero_zone_tiles(state, session, context, Vector2i{tile_arg.vx(), tile_arg.vy()}, level);
		const auto claim = [&](const Value &zone_tile) {
			const int64_t zone_y = gd::to_int(state, ai::vmember(state, zone_tile, key::y));
			const int64_t zone_x = gd::to_int(state, ai::vmember(state, zone_tile, key::x));
			const int64_t zone_index = gd::add(gd::mul(zone_y, width), zone_x);
			if (zone_index >= 0 && zone_index < count && guarded.get(zone_index) == 0) {
				guard_at(zone_index, hero_key);
			}
		};
		claim(guard_tile);
		for (const Value &zone_tile : gd::items(state, array_value(zone_tiles))) {
			claim(zone_tile);
		}
	}
	// Breadth-first from everything reachable today; zone tiles are walkable
	// and the first zone entered is carried along. A portal leads on to its
	// exits, as in the search (`_portal_exits`) and in `_level_regions`.
	Value portals_value;
	const bool has_portals = state.lookup(_level_surface(state, session, context, level), str(key::portals), portals_value);
	const DictRef portals = has_portals ? gd::as_dict(portals_value) : 0;
	const PackedRef seen_map = has_portals && !gd::is_empty(state, portals) ? _explored(state, session, context, level) : gd::new_bytes(state);
	resize_check(state, count);
	resize_check(state, count);
	resize_check(state, count);
	Local<uint8_t> is_target(count, "PackedByteArray");
	for (const Value &tile : gd::items(state, dict_value(targets))) {
		const int64_t target_tile = gd::to_int(state, tile);
		if (target_tile >= 0 && target_tile < count) {
			is_target.set(target_tile, 1);
		}
	}
	resize_check(state, count);
	Local<uint8_t> is_portal(count, "PackedByteArray");
	if (has_portals) {
		for (const Value &tile : gd::items(state, dict_value(portals))) {
			const int64_t portal_tile = gd::to_int(state, tile);
			if (portal_tile >= 0 && portal_tile < count) {
				is_portal.set(portal_tile, 1);
			}
		}
	}
	resize_check(state, count);
	Local<int32_t> first(count, "PackedInt32Array");
	for (int32_t &item : first.items) {
		item = -2;
	}
	resize_check(state, count);
	Local<int32_t> queue(count, "PackedInt32Array");
	int64_t head = 0;
	int64_t tail = 0;
	// Every tile the search reached, in tile order: those it queued and the
	// stops where it ended a route (each has a reference there).
	const PackedRef order = gd::as_ints(gd::index(state, search, str(key::order)));
	const PackedRef reached = gd::packed_slice(state, order, 0, gd::to_int(state, gd::index(state, search, str(key::order_count))));
	for (const Value &tile : gd::items(state, dict_value(gd::as_dict(gd::index(state, search, str(key::stops)))))) {
		gd::packed_append(state, reached, gd::to_int(state, tile));
	}
	gd::packed_sort(state, reached);
	int64_t previous = -1;
	const View<int32_t> reached_at = ints_view(state, reached);
	for (size_t at = 0; at < reached_at.size; ++at) {
		const int64_t tile = reached_at.data[at];
		if (tile == previous) {
			continue;
		}
		previous = tile;
		if (guarded.get(tile) == 0) {
			first.set(tile, -1);
			queue.set(tail, tile);
			tail += 1;
		}
	}
	int64_t found_targets = 0;
	const int64_t target_count = state.dict_size(targets);
	const PackedRef step_offset = _step_offsets(state, width);
	int64_t offsets[8];
	for (int64_t direction = 0; direction < 8; ++direction) {
		offsets[direction] = gd::packed_int(state, step_offset, direction);
	}
	const View<uint8_t> blocked_at = bytes_view(state, blocked);
	const auto step_to = [&](int64_t next, int64_t carried_here) {
		if (first.get(next) != -2) {
			return;
		}
		if (blocked_at[next] != 0 && guarded.get(next) == 0 && is_target.get(next) == 0 && is_portal.get(next) == 0) {
			return;
		}
		int64_t carried = carried_here;
		if (carried == -1 && guarded.get(next) != 0) {
			carried = guard_key.get(next);
		}
		first.set(next, carried);
		if (is_target.get(next) != 0) {
			found_targets += 1;
			if (carried != -1) {
				const Value carried_key = int_value(carried);
				const double best = gd::to_float(state.get(result, carried_key, float_value(0.0)));
				const double target = gd::to_float(gd::index(state, targets, int_value(next)));
				state.set(result, carried_key, float_value(compat::engine_max(best, target)));
			}
			return;
		}
		queue.set(tail, next);
		tail += 1;
	};
	while (head < tail && found_targets < target_count) {
		const int64_t current = queue.get(head);
		head += 1;
		const int64_t carried_here = first.get(current);
		const int64_t cx = int_mod(current, width);
		const int64_t cy = int_div(current, width);
		const bool on_edge = cx == 0 || cy == 0 || cx == width - 1 || cy == height - 1;
		// The neighbours, then where a portal here leads.
		for (int64_t direction = 0; direction < 8; ++direction) {
			if (on_edge) {
				const int64_t nx = cx + kNeighborDx[direction];
				const int64_t ny = cy + kNeighborDy[direction];
				if (nx < 0 || ny < 0 || nx >= width || ny >= height) {
					continue;
				}
			}
			step_to(current + offsets[direction], carried_here);
		}
		if (is_portal.get(current) != 0) {
			const PackedRef exits = _portal_exits(state, gd::as_dict(gd::index(state, portals, int_value(current))), seen_map);
			const int64_t exit_count = gd::packed_size(state, exits);
			for (int64_t at = 0; at < exit_count; ++at) {
				step_to(gd::packed_int(state, exits, at), carried_here);
			}
		}
	}
	return result;
}

} // namespace ai_hero_rules

} // namespace aurelion::rules::port
