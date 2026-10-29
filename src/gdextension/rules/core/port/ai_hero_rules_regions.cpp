// AiHeroRules: each level's ground in patches and the stretches a hero joins
// across the armies it beats, the reach past a gate, and the hostile heroes
// that endanger a hero.

#include "aurelion_rules/port/ai_hero_rules_ai.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/native_transit_rules_ai.hpp"
#include "aurelion_rules/port/overworld_level_rules.hpp"
#include "aurelion_rules/port/overworld_rules_ai.hpp"
#include "aurelion_rules/port/player_identity_rules_ai.hpp"
#include "aurelion_rules/port/session_view.hpp"

#include <cmath>
#include <string>
#include <vector>

namespace aurelion::rules::port {

namespace {

using gd::array_value;
using gd::ArrayRef;
using gd::Atom;
using gd::bool_value;
using gd::dict_value;
using gd::DictRef;
using gd::float_value;
using gd::int_value;
using gd::str;
using state::Kind;
using state::State;
using state::Value;
namespace key = state::key;

// NEIGHBOR_DX, NEIGHBOR_DY.
constexpr int64_t kNeighborDx[8] = {1, -1, 0, 0, 1, 1, -1, -1};
constexpr int64_t kNeighborDy[8] = {0, 0, 1, -1, 1, -1, 1, -1};

// A value assigned to a Vector2i or Vector3i variable.
overworld_rules::Vector2i vector2i_of(const Value &value) {
	if (!gd::is_vector2i(value)) {
		throw state::ScriptError(std::string("Trying to assign value of type '") + gd::type_name(value) + "' to a variable of type 'Vector2i'.");
	}
	return overworld_rules::Vector2i::of(value.vx(), value.vy());
}

Value vector3i_of(const Value &value) {
	if (!gd::is_vector3i(value)) {
		throw state::ScriptError(std::string("Trying to assign value of type '") + gd::type_name(value) + "' to a variable of type 'Vector3i'.");
	}
	return value;
}

// x.get(name, []) of an untyped value: the fallback a new Array.
Value get_or_new_array(State &state, const Value &object, Atom name) {
	if (!gd::is_dict(object)) {
		return ai::vget(state, object, name);
	}
	Value found;
	if (state.lookup(object.ref, str(name), found)) {
		return found;
	}
	return array_value(state.new_array());
}

// a + b of two untyped values holding Arrays.
ArrayRef concat_values(State &state, const Value &a, const Value &b) {
	if (!gd::is_array(a) || !gd::is_array(b)) {
		throw state::ScriptError(std::string("Invalid operands '") + gd::type_name(a) + "' and '" + gd::type_name(b) + "' in operator '+'.");
	}
	return gd::concat(state, a.ref, b.ref);
}

// patches[exit] of a portal exit: _level_surface keeps only exits on the map.
size_t exit_tile(const Value &exit, int64_t count) {
	if (exit.kind != Kind::Int || exit.i < 0 || exit.i >= count) {
		throw state::NotPorted("AiHeroRules._level_regions: a portal exit off the map");
	}
	return static_cast<size_t>(exit.i);
}

} // namespace

namespace ai_hero_rules {

DictRef _level_regions(State &state, DictRef session, DictRef context, int64_t level) {
	Value found;
	const DictRef cache = state.lookup(context, str(key::level_regions), found) ? gd::as_dict(found) : state.new_dict();
	if (state.lookup(cache, int_value(level), found)) {
		return gd::as_dict(found);
	}
	const DictRef surface = _level_surface(state, session, context, level);
	const Vector2i size = vector2i_of(gd::index(state, context, str(key::map_size)));
	const int64_t count = gd::mul(size.x, size.y);
	const PackedRef blocked = gd::as_bytes(gd::index(state, surface, str(key::blocked)));
	const DictRef static_stops = gd::as_dict(gd::index(state, surface, str(key::stops)));
	Value portals_value;
	const bool has_portals = state.lookup(surface, str(key::portals), portals_value);
	const DictRef portals = has_portals ? gd::as_dict(portals_value) : DictRef(0);
	const bool native_corners = native_transit_rules::uses_native_adjacency(state, dict_value(session));
	const DictRef resolved = _resolved_lookup(state, session);
	// Tiles no patch takes: rock and bodies that do not end a route, and water.
	Value water_value;
	const bool has_water = state.lookup(surface, str(key::water), water_value);
	const PackedRef water = has_water ? gd::as_bytes(water_value) : PackedRef(0);
	if (size.x < 0 || size.y < 0) {
		throw state::NotPorted("AiHeroRules._level_regions: a negative map size");
	}
	const size_t tile_count = static_cast<size_t>(count);
	const int64_t blocked_size = gd::packed_size(state, blocked);
	if (blocked_size < count) {
		throw state::ScriptError("Out of bounds get index '" + std::to_string(blocked_size) + "' (on base: 'PackedByteArray')");
	}
	// static_stops.has(tile) for each tile.
	std::vector<uint8_t> stop_tile(tile_count, 0);
	for (const Value &stop : state.dict(static_stops).keys) {
		if (stop.kind == Kind::Int && stop.i >= 0 && stop.i < count) {
			stop_tile[static_cast<size_t>(stop.i)] = 1;
		}
	}
	std::vector<uint8_t> closed(tile_count, 0);
	{
		const uint8_t *blocked_at = gd::packed_bytes(state, blocked);
		const int64_t water_size = has_water ? gd::packed_size(state, water) : 0;
		const uint8_t *water_at = has_water ? gd::packed_bytes(state, water) : nullptr;
		for (int64_t tile = 0; tile < count; ++tile) {
			const size_t at = static_cast<size_t>(tile);
			if ((blocked_at[at] != 0 && stop_tile[at] == 0) || (tile < water_size && water_at[at] != 0)) {
				closed[at] = 1;
			}
		}
	}
	std::vector<int32_t> patches(tile_count, -1);
	std::vector<int32_t> starts;
	const ArrayRef guards = state.new_array();
	std::vector<DictRef> armies;
	const DictRef overworld = session_view::overworld(state, session);
	const ArrayRef encounters = state.lookup(overworld, str(key::encounters), found) ? gd::as_array(found) : state.new_array();
	const state::ValueList neutrals = gd::items(state, gd::index(state, surface, str(key::neutrals))).list();
	for (const Value &record : neutrals) {
		if (state.has(resolved, str(gd::stringify(state, ai::vmember(state, record, key::id))))) {
			continue;
		}
		const Atom army_id = gd::stringify(state, ai::vmember(state, record, key::id));
		const double power = _guard_power(state, gd::as_dict(state.at(encounters, gd::to_int(state, ai::vmember(state, record, key::index)))));
		const Value zone = ai::vmember(state, record, key::zone);
		const Value body = ai::vmember(state, record, key::body);
		const ArrayRef tiles = concat_values(state, zone, body);
		const DictRef army = state.new_dict();
		state.set(army, str(key::id), str(army_id));
		state.set(army, str(key::power), float_value(power));
		state.set(army, str(key::tiles), array_value(tiles));
		armies.push_back(army);
	}
	// Rival heroes stand still through this player's turn and end a route
	// where they stand, as the search has it.
	const DictRef sight = _sight_context(state, gd::stringify(state, gd::index(state, context, str(key::controller))));
	const state::ValueList hero_guards = state.array(_hero_guards(state, session, context, level)).items;
	for (const Value &hero_guard : hero_guards) {
		if (!gd::to_bool(ai::vmember(state, hero_guard, key::hostile))) {
			continue;
		}
		const ArrayRef tiles = state.new_array();
		{
			const Value tile = ai::vmember(state, hero_guard, key::tile);
			const int64_t tile_y = gd::to_int(state, ai::vmember(state, tile, key::y));
			const int64_t tile_x = gd::to_int(state, ai::vmember(state, tile, key::x));
			state.append(tiles, int_value(gd::add(gd::mul(tile_y, size.x), tile_x)));
		}
		const state::ValueList zone_tiles = state.array(_hero_zone_tiles(state, session, context, vector2i_of(ai::vmember(state, hero_guard, key::tile)), level)).items;
		for (const Value &zone_tile : zone_tiles) {
			const int64_t zone_y = gd::to_int(state, ai::vmember(state, zone_tile, key::y));
			const int64_t zone_x = gd::to_int(state, ai::vmember(state, zone_tile, key::x));
			state.append(tiles, int_value(gd::add(gd::mul(zone_y, size.x), zone_x)));
		}
		const DictRef army = state.new_dict();
		state.set(army, str(key::id), str(gd::stringify(state, ai::vmember(state, hero_guard, key::id))));
		state.set(army, str(key::tiles), array_value(tiles));
		if (gd::stringify(state, ai::vmember(state, hero_guard, key::ref_kind)) == key::ai_hero) {
			const DictRef other = gd::as_dict(state.at(encounters, gd::to_int(state, ai::vmember(state, hero_guard, key::index))));
			const double power = hero_power(state, other);
			const Value commander = state.lookup(other, str(key::enemy_commander_state), found) ? found : dict_value(state.new_dict());
			const DictRef position = overworld_level_rules::position(state, other);
			const bool seen = _position_seen(state, session, sight, position);
			state.set(army, str(key::power), float_value(power));
			state.set(army, str(key::commander), commander);
			state.set(army, str(key::seen), bool_value(seen));
		} else {
			const Value heroes = gd::index(state, session_view::overworld(state, session), str(key::player_heroes));
			const DictRef hero = gd::as_dict(ai::vindex(state, heroes, int_value(gd::to_int(state, ai::vmember(state, hero_guard, key::index)))));
			Value hero_army;
			const Value stacks = state.lookup(hero, str(key::army), hero_army) ? get_or_new_array(state, hero_army, key::stacks) : array_value(state.new_array());
			const double power = army_power(state, stacks, dict_value(hero));
			const bool seen = _player_hero_seen(state, session, sight, hero);
			state.set(army, str(key::power), float_value(power));
			state.set(army, str(key::commander), dict_value(hero));
			state.set(army, str(key::seen), bool_value(seen));
		}
		armies.push_back(army);
	}
	// guards[i].links and guards[i].tiles.
	std::vector<DictRef> guard_links;
	std::vector<ArrayRef> guard_tiles;
	for (const DictRef army : armies) {
		const int64_t patch = static_cast<int64_t>(starts.size());
		const ArrayRef tiles = state.new_array();
		int64_t lowest = 0;
		const state::ValueList army_tiles = gd::items(state, gd::index(state, army, str(key::tiles))).list();
		for (const Value &tile : army_tiles) {
			const int64_t guard_tile = gd::to_int(state, tile);
			if (guard_tile < 0 || guard_tile >= count || patches[static_cast<size_t>(guard_tile)] >= 0 || closed[static_cast<size_t>(guard_tile)] != 0) {
				continue;
			}
			patches[static_cast<size_t>(guard_tile)] = static_cast<int32_t>(patch);
			if (state.array_size(tiles) == 0 || guard_tile < lowest) {
				lowest = guard_tile;
			}
			state.append(tiles, int_value(guard_tile));
		}
		if (state.array_size(tiles) == 0) {
			continue;
		}
		starts.push_back(static_cast<int32_t>(lowest));
		const DictRef guard_record = gd::duplicate_dict(state, army);
		const DictRef links = state.new_dict();
		state.set(guard_record, str(key::tiles), array_value(tiles));
		state.set(guard_record, str(key::links), dict_value(links));
		state.append(guards, dict_value(guard_record));
		guard_links.push_back(links);
		guard_tiles.push_back(tiles);
	}
	const int64_t guard_count = static_cast<int64_t>(guard_links.size());
	const int64_t width = size.x;
	const int64_t height = size.y;
	int64_t step_offset[8];
	{
		const PackedRef offsets = _step_offsets(state, width);
		for (int64_t direction = 0; direction < 8; ++direction) {
			step_offset[direction] = gd::packed_int(state, offsets, direction);
		}
	}
	// portals.has(tile) and portals[tile] for each tile.
	std::vector<int32_t> portal_slot(tile_count, -1);
	std::vector<Value> portal_values;
	if (has_portals) {
		const state::DictNode &node = state.dict(portals);
		for (size_t slot = 0; slot < node.keys.size(); ++slot) {
			const Value &tile = node.keys[slot];
			if (tile.kind == Kind::Int && tile.i >= 0 && tile.i < count && portal_slot[static_cast<size_t>(tile.i)] < 0) {
				portal_slot[static_cast<size_t>(tile.i)] = static_cast<int32_t>(portal_values.size());
				portal_values.push_back(node.values[slot]);
			}
		}
	}
	const uint8_t *blocked_at = gd::packed_bytes(state, blocked);
	std::vector<int32_t> queue(tile_count, 0);
	for (int64_t start = 0; start < count; ++start) {
		if (patches[static_cast<size_t>(start)] >= 0 || closed[static_cast<size_t>(start)] != 0) {
			continue;
		}
		const int64_t patch = static_cast<int64_t>(starts.size());
		starts.push_back(static_cast<int32_t>(start));
		patches[static_cast<size_t>(start)] = static_cast<int32_t>(patch);
		size_t head = 0;
		size_t tail = 0;
		queue[tail] = static_cast<int32_t>(start);
		tail += 1;
		while (head < tail) {
			const int64_t current = queue[head];
			head += 1;
			const int32_t slot = portal_slot[static_cast<size_t>(current)];
			if (slot >= 0) {
				const state::ValueList exits = gd::items(state, ai::vmember(state, portal_values[static_cast<size_t>(slot)], key::exits)).list();
				for (const Value &exit_value : exits) {
					const size_t exit = exit_tile(exit_value, count);
					if (patches[exit] < 0) {
						patches[exit] = static_cast<int32_t>(patch);
						queue[tail] = static_cast<int32_t>(exit);
						tail += 1;
					} else if (patches[exit] < guard_count) {
						state.set(guard_links[static_cast<size_t>(patches[exit])], int_value(patch), bool_value(true));
					}
				}
			}
			const int64_t cx = current % width;
			const int64_t cy = current / width;
			const bool on_edge = cx == 0 || cy == 0 || cx == width - 1 || cy == height - 1;
			for (int64_t direction = 0; direction < 8; ++direction) {
				const int64_t dx = kNeighborDx[direction];
				const int64_t dy = kNeighborDy[direction];
				if (on_edge && (cx + dx < 0 || cy + dy < 0 || cx + dx >= width || cy + dy >= height)) {
					continue;
				}
				const int64_t next = current + step_offset[direction];
				if (next < 0 || next >= count) {
					throw state::NotPorted("AiHeroRules._level_regions: a step off the map");
				}
				if (patches[static_cast<size_t>(next)] >= 0 || closed[static_cast<size_t>(next)] != 0) {
					continue;
				}
				if (dx != 0 && dy != 0 && !native_corners && blocked_at[static_cast<size_t>(current + dx)] != 0 && blocked_at[static_cast<size_t>(current + dy * width)] != 0) {
					continue;
				}
				patches[static_cast<size_t>(next)] = static_cast<int32_t>(patch);
				queue[tail] = static_cast<int32_t>(next);
				tail += 1;
			}
		}
	}
	// What each army's zone touches: open ground, other zones, portal exits.
	for (int64_t guard_patch = 0; guard_patch < guard_count; ++guard_patch) {
		const DictRef links = guard_links[static_cast<size_t>(guard_patch)];
		const state::ValueList tiles = state.array(guard_tiles[static_cast<size_t>(guard_patch)]).items;
		for (const Value &tile_value : tiles) {
			const int64_t tile = gd::to_int(state, tile_value);
			const int64_t cx = tile % width;
			const int64_t cy = tile / width;
			for (int64_t direction = 0; direction < 8; ++direction) {
				const int64_t nx = cx + kNeighborDx[direction];
				const int64_t ny = cy + kNeighborDy[direction];
				if (nx < 0 || ny < 0 || nx >= width || ny >= height) {
					continue;
				}
				const size_t next = static_cast<size_t>(ny * width + nx);
				if (patches[next] < 0 || patches[next] == guard_patch) {
					continue;
				}
				if (nx != cx && ny != cy && !native_corners && blocked_at[static_cast<size_t>(cy * width + nx)] != 0 && blocked_at[static_cast<size_t>(ny * width + cx)] != 0) {
					continue;
				}
				state.set(links, int_value(patches[next]), bool_value(true));
			}
			const int32_t slot = portal_slot[static_cast<size_t>(tile)];
			if (slot >= 0) {
				const state::ValueList exits = gd::items(state, ai::vmember(state, portal_values[static_cast<size_t>(slot)], key::exits)).list();
				for (const Value &exit_value : exits) {
					const size_t exit = exit_tile(exit_value, count);
					if (patches[exit] >= 0 && patches[exit] != guard_patch) {
						state.set(links, int_value(patches[exit]), bool_value(true));
					}
				}
			}
		}
	}
	const PackedRef patches_packed = gd::new_ints(state);
	state.packed_write(patches_packed).ints = std::move(patches);
	const PackedRef starts_packed = gd::new_ints(state);
	state.packed_write(starts_packed).ints = std::move(starts);
	const DictRef regions = state.new_dict();
	state.set(regions, str(key::patches), gd::ints_value(patches_packed));
	state.set(regions, str(key::starts), gd::ints_value(starts_packed));
	state.set(regions, str(key::guards), array_value(guards));
	state.set(cache, int_value(level), dict_value(regions));
	state.set(context, str(key::level_regions), dict_value(cache));
	return regions;
}

PackedRef _level_stretches(State &state, DictRef session, DictRef context, int64_t level, double power, double loss_limit, DictRef entry) {
	const DictRef avoided = _avoided_today(state, session, entry);
	const ArrayRef avoided_ids = gd::keys(state, avoided);
	gd::sort_custom(state, avoided_ids, [&state](const Value &a, const Value &b) { return gd::text(state, a) < gd::text(state, b); });
	std::string joined;
	bool first = true;
	for (const Value &id : gd::items(state, array_value(avoided_ids))) {
		if (!first) {
			joined += ',';
		}
		first = false;
		joined += gd::text(state, id);
	}
	const Atom stretch_key = gd::format(state, key::d_d_d_s_s, {int_value(level), int_value(compat::float_to_int(power)), int_value(compat::float_to_int(loss_limit)), str(ai::string_or_empty(state, entry, key::placement_id)), str(state.intern(joined))});
	Value found;
	const DictRef cache = state.lookup(context, str(key::level_stretches), found) ? gd::as_dict(found) : state.new_dict();
	if (state.lookup(cache, str(stretch_key), found)) {
		return gd::as_ints(found);
	}
	const DictRef regions = _level_regions(state, session, context, level);
	const PackedRef starts = gd::as_ints(gd::index(state, regions, str(key::starts)));
	const ArrayRef guards = gd::as_array(gd::index(state, regions, str(key::guards)));
	const DictRef resolved = _resolved_lookup(state, session);
	const PackedRef beaten = gd::new_bytes(state);
	gd::packed_resize(state, beaten, state.array_size(guards));
	for (int64_t guard_patch = 0; guard_patch < state.array_size(guards); ++guard_patch) {
		const DictRef guard = gd::as_dict(state.at(guards, guard_patch));
		if (state.has(resolved, str(gd::stringify(state, gd::index(state, guard, str(key::id)))))) {
			gd::packed_set(state, beaten, guard_patch, 1);
		} else if (state.has(avoided, str(gd::stringify(state, gd::index(state, guard, str(key::id))))) || _expected_loss_value(state, power, gd::to_float(gd::index(state, guard, str(key::power)))) > loss_limit) {
			continue;
		} else if (!state.has(guard, str(key::commander))) {
			if (gd::to_float(gd::index(state, guard, str(key::power))) * ai::static_float(state, key::ai_hero_rules_script, key::GUARD_WIN_RATIO) <= power) {
				gd::packed_set(state, beaten, guard_patch, 1);
			}
		} else if (gd::to_bool(gd::index(state, guard, str(key::seen)))) {
			// A rival hero as `_candidate` attacks one: seen, and beaten after the
			// damage its spells do.
			const double after_burst = power * (1.0 - _burst_share(state, entry, gd::index(state, guard, str(key::commander))));
			if (after_burst >= gd::to_float(gd::index(state, guard, str(key::power))) * ai::static_float(state, key::ai_hero_rules_script, key::HERO_ATTACK_RATIO)) {
				gd::packed_set(state, beaten, guard_patch, 1);
			}
		}
	}
	const ArrayRef parent = state.new_array();
	for (int64_t patch = 0; patch < gd::packed_size(state, starts); ++patch) {
		state.append(parent, int_value(patch));
	}
	for (int64_t guard_patch = 0; guard_patch < state.array_size(guards); ++guard_patch) {
		if (gd::packed_int(state, beaten, guard_patch) == 0) {
			continue;
		}
		const Value links = ai::vmember(state, state.at(guards, guard_patch), key::links);
		if (!gd::is_dict(links)) {
			throw state::ScriptError(std::string("Invalid call. Nonexistent function 'keys' in base '") + gd::type_name(links) + "'.");
		}
		const state::ValueList link_list = state.dict(links.ref).keys.list();
		for (const Value &link : link_list) {
			if (gd::to_int(state, link) < state.array_size(guards) && gd::packed_int(state, beaten, gd::to_int(state, link)) == 0) {
				continue;
			}
			const int64_t a = _patch_root(state, parent, guard_patch);
			const int64_t b = _patch_root(state, parent, gd::to_int(state, link));
			if (a != b) {
				state.set_at(parent, compat::engine_max(a, b), int_value(compat::engine_min(a, b)));
			}
		}
	}
	const PackedRef names = gd::new_ints(state);
	gd::packed_resize(state, names, gd::packed_size(state, starts));
	gd::packed_fill(state, names, -1);
	for (int64_t patch = 0; patch < gd::packed_size(state, starts); ++patch) {
		const int64_t root = _patch_root(state, parent, patch);
		if (gd::packed_int(state, names, root) < 0 || gd::packed_int(state, starts, patch) < gd::packed_int(state, names, root)) {
			gd::packed_set(state, names, root, gd::packed_int(state, starts, patch));
		}
	}
	const PackedRef stretches = gd::new_ints(state);
	gd::packed_resize(state, stretches, gd::packed_size(state, starts));
	for (int64_t patch = 0; patch < gd::packed_size(state, starts); ++patch) {
		gd::packed_set(state, stretches, patch, gd::packed_int(state, names, _patch_root(state, parent, patch)));
	}
	state.set(cache, str(stretch_key), gd::ints_value(stretches));
	state.set(context, str(key::level_stretches), dict_value(cache));
	return stretches;
}

int64_t _patch_root(State &state, ArrayRef parent, int64_t patch) {
	while (gd::to_int(state, state.at(parent, patch)) != patch) {
		state.set_at(parent, patch, state.at(parent, gd::to_int(state, state.at(parent, patch))));
		patch = gd::to_int(state, state.at(parent, patch));
	}
	return patch;
}

Atom _stretch_key(State &state, DictRef session, DictRef context, int64_t level, int64_t tile, double power, double loss_limit, DictRef entry) {
	const PackedRef patches = gd::as_ints(gd::index(state, _level_regions(state, session, context, level), str(key::patches)));
	if (tile < 0 || tile >= gd::packed_size(state, patches) || gd::packed_int(state, patches, tile) < 0) {
		return key::empty;
	}
	const PackedRef stretches = _level_stretches(state, session, context, level, power, loss_limit, entry);
	return gd::format(state, key::d_d, {int_value(level), int_value(gd::packed_int(state, stretches, gd::packed_int(state, patches, tile)))});
}

DictRef _avoided_today(State &state, DictRef session, DictRef entry) {
	const DictRef result = state.new_dict();
	Value block;
	if (!state.lookup(entry, str(key::ai_hero), block)) {
		return result;
	}
	const Value avoid = ai::vget(state, block, key::avoid);
	if (!gd::is_dict(avoid)) {
		return result;
	}
	const state::ValueList ids = state.dict(avoid.ref).keys.list();
	for (const Value &id : ids) {
		if (gd::to_int(state, gd::index(state, avoid.ref, id)) >= ai::session_int(state, session, key::day)) {
			state.set(result, str(gd::stringify(state, id)), bool_value(true));
		}
	}
	return result;
}

DictRef _beyond_gate(State &state, DictRef session, DictRef context, DictRef entry, DictRef gate, int64_t movement_max, int64_t radius) {
	const Value exit = vector3i_of(gd::index(state, gate, str(key::exit)));
	Value found;
	const DictRef cache = state.lookup(context, str(key::gate_beyond), found) ? gd::as_dict(found) : state.new_dict();
	const Atom beyond = _beyond_key(state, entry, gate, radius);
	if (state.lookup(cache, str(beyond), found)) {
		return gd::as_dict(found);
	}
	const DictRef traveller = gd::duplicate_dict(state, entry);
	state.set(traveller, str(key::ai_traveller), bool_value(true));
	state.set(traveller, str(key::x), int_value(exit.vx()));
	state.set(traveller, str(key::y), int_value(exit.vy()));
	state.set(traveller, str(key::level), int_value(exit.vz()));
	// The other level's candidates are not this decision's alternatives.
	const Value logged = state.get(context, str(key::decision_alternatives), Value());
	state.erase(context, str(key::decision_alternatives));
	const DictRef far_search = _search(state, session, context, traveller, radius, false);
	const DictRef far_dists = state.lookup(context, str(key::gate_far), found) ? gd::as_dict(found) : state.new_dict();
	const Value far_dist = state.lookup(far_search, str(key::dist), found) ? found : gd::ints_value(gd::new_ints(state));
	state.set(far_dists, str(beyond), far_dist);
	state.set(context, str(key::gate_far), dict_value(far_dists));
	const int64_t min_radius = ai::static_int(state, key::ai_hero_rules_script, key::MIN_SEARCH_RADIUS);
	const int64_t near_radius = compat::engine_max(min_radius, gd::mul(movement_max, ai::static_int(state, key::ai_hero_rules_script, key::SEARCH_DAYS)));
	// Farther than that only what is worth the walk (`_best_candidate`).
	DictRef far = _best_candidate(state, session, context, traveller, far_search, movement_max, near_radius, true);
	if (gd::is_empty(state, far)) {
		const int64_t far_radius = compat::engine_max(near_radius, gd::mul(movement_max, ai::static_int(state, key::ai_hero_rules_script, key::FAR_SEARCH_DAYS)));
		far = _best_candidate(state, session, context, traveller, far_search, movement_max, far_radius, true);
	}
	if (logged.kind != Kind::Nil) {
		state.set(context, str(key::decision_alternatives), logged);
	}
	const DictRef guard = overworld_rules::_find_guard_engagement_at_tile(state, session, exit.vx(), exit.vy(), exit.vz(), false);
	const int64_t guard_index = gd::int_field(state, guard, key::index, -1);
	const Atom guard_id = guard_index >= 0 ? gd::stringify(state, ai::vget(state, gd::index(state, guard, str(key::encounter)), key::placement_id, str(key::empty))) : key::empty;
	const double value = gd::float_field(state, far, key::value, 0.0);
	double guard_value = 0.0;
	if (guard_index >= 0 && ai::string_or_empty(state, far, key::id) != guard_id) {
		const double power = hero_power(state, entry);
		const DictRef needs = _resource_needs(state, session, context);
		guard_value = _guard_fight_value(state, session, context, traveller, guard_index, power, needs, far_search);
	}
	const DictRef result = state.new_dict();
	if (!std::isnan(guard_value) && (!gd::is_empty(state, far) || guard_index >= 0) && value + guard_value > 0.0) {
		const Atom kind = gd::stringify(state, state.get(far, str(key::kind), str(key::encounter)));
		const Atom id = gd::stringify(state, state.get(far, str(key::id), str(guard_id)));
		const double total = value + guard_value;
		const int64_t distance = gd::int_field(state, far, key::distance, 0);
		const double far_fight_power = guard_index >= 0 ? _guard_power(state, gd::as_dict(gd::index(state, guard, str(key::encounter)))) : 0.0;
		state.set(result, str(key::kind), str(kind));
		state.set(result, str(key::id), str(id));
		state.set(result, str(key::value), float_value(total));
		state.set(result, str(key::distance), int_value(distance));
		state.set(result, str(key::far_guard), int_value(guard_index));
		state.set(result, str(key::far_fight_power), float_value(far_fight_power));
	}
	state.set(cache, str(beyond), dict_value(result));
	state.set(context, str(key::gate_beyond), dict_value(cache));
	return result;
}

Atom _beyond_key(State &state, DictRef entry, DictRef gate, int64_t radius) {
	const Value exit = vector3i_of(gd::index(state, gate, str(key::exit)));
	const Atom placement_id = ai::string_or_empty(state, entry, key::placement_id);
	Value army;
	const Value stacks = state.lookup(entry, str(key::enemy_army), army) ? get_or_new_array(state, army, key::stacks) : array_value(state.new_array());
	return gd::format(state, key::s_d_d_d_d_d, {str(placement_id), int_value(exit.vx()), int_value(exit.vy()), int_value(exit.vz()), int_value(radius), int_value(gd::hash(state, stacks))});
}

PackedRef _gate_far_dist(State &state, DictRef context, DictRef entry, DictRef gate, int64_t radius) {
	Value far_dists;
	const bool has_far = state.lookup(context, str(key::gate_far), far_dists);
	const Atom beyond = _beyond_key(state, entry, gate, radius);
	if (has_far) {
		if (!gd::is_dict(far_dists)) {
			throw state::ScriptError(std::string("Invalid call. Nonexistent function 'get' in base '") + gd::type_name(far_dists) + "'.");
		}
		Value found;
		if (state.lookup(far_dists.ref, str(beyond), found)) {
			return gd::as_ints(found);
		}
	}
	return gd::new_ints(state);
}

ArrayRef _dangers(State &state, DictRef session, DictRef context, DictRef entry) {
	Value found;
	const DictRef cache = state.lookup(context, str(key::decision), found) ? gd::as_dict(found) : state.new_dict();
	const Atom dangers_key = gd::format(state, key::dangers_s, {str(ai::string_or_empty(state, entry, key::placement_id))});
	if (state.lookup(cache, str(dangers_key), found)) {
		return gd::as_array(found);
	}
	if (!state.has(cache, str(key::hostile))) {
		const Atom controller = gd::stringify(state, gd::index(state, context, str(key::controller)));
		state.set(cache, str(key::hostile), array_value(_hostile_heroes(state, session, controller)));
	}
	const double power = hero_power(state, entry);
	const ArrayRef result = state.new_array();
	const state::ValueList hostile = gd::items(state, gd::index(state, cache, str(key::hostile))).list();
	for (const Value &threat : hostile) {
		if (gd::to_float(ai::vmember(state, threat, key::power)) >= power * ai::static_float(state, key::ai_hero_rules_script, key::DANGER_RATIO)) {
			state.append(result, threat);
		}
	}
	state.set(cache, str(dangers_key), array_value(result));
	state.set(context, str(key::decision), dict_value(cache));
	return result;
}

bool _deters(State &state, DictRef session, DictRef entry, DictRef town, ArrayRef dangers) {
	(void)session;
	double strongest = 0.0;
	const state::ValueList threats = state.array(dangers).items;
	for (const Value &threat : threats) {
		strongest = compat::engine_max(strongest, gd::to_float(ai::vmember(state, threat, key::power)));
	}
	const double own_power = hero_power(state, entry);
	Value garrison;
	if (!state.lookup(town, str(key::garrison), garrison)) {
		garrison = array_value(state.new_array());
	}
	const double garrison_power = army_power(state, garrison, dict_value(state.new_dict()));
	return strongest < (own_power + garrison_power) * ai::static_float(state, key::ai_hero_rules_script, key::TOWN_ATTACK_RATIO);
}

bool _in_danger(State &state, ArrayRef dangers, int64_t x, int64_t y, int64_t level) {
	const state::ValueList threats = state.array(dangers).items;
	for (const Value &threat : threats) {
		if (gd::to_int(state, ai::vget(state, threat, key::level, int_value(0))) != level) {
			continue;
		}
		const int64_t across = compat::absi(gd::sub(gd::to_int(state, ai::vmember(state, threat, key::x)), x));
		const int64_t down = compat::absi(gd::sub(gd::to_int(state, ai::vmember(state, threat, key::y)), y));
		if (compat::engine_max(across, down) <= gd::add(gd::to_int(state, ai::vget(state, threat, key::reach, int_value(10))), 1)) {
			return true;
		}
	}
	return false;
}

DictRef _own_town_doors(State &state, DictRef session, Atom controller, int64_t level, Vector2i size) {
	const DictRef doors = state.new_dict();
	const state::ValueList towns = gd::field_items(state, session_view::overworld(state, session), str(key::towns)).list();
	for (const Value &town : towns) {
		if (!gd::is_dict(town) || ai::string_or_empty(state, town.ref, key::owner) != key::enemy || player_identity_rules::town_controller_id(state, town.ref) != controller) {
			continue;
		}
		const DictRef entrance = overworld_level_rules::town_entrance(state, town.ref);
		if (overworld_level_rules::level_of(state, dict_value(entrance)) != level) {
			continue;
		}
		const int64_t x = gd::int_field(state, entrance, key::x, -1);
		const int64_t y = gd::int_field(state, entrance, key::y, -1);
		if (x >= 0 && y >= 0 && x < size.x && y < size.y) {
			state.set(doors, int_value(y * size.x + x), str(ai::string_or_empty(state, town.ref, key::placement_id)));
		}
	}
	return doors;
}

} // namespace ai_hero_rules

} // namespace aurelion::rules::port
