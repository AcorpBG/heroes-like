// AiHeroRules: how a computer player pays for a boat, the heroes that guard a
// level, the static surface of a level its searches walk, and its site stops.

#include "aurelion_rules/port/ai_hero_rules_ai.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/content_service_ai.hpp"
#include "aurelion_rules/port/enemy_turn_rules.hpp"
#include "aurelion_rules/port/native_transit_rules_ai.hpp"
#include "aurelion_rules/port/overworld_level_rules_ai.hpp"
#include "aurelion_rules/port/overworld_rules_ai.hpp"
#include "aurelion_rules/port/player_identity_rules_ai.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/visit_building_rules_ai.hpp"
#include "aurelion_rules/port/water_travel_rules_ai.hpp"

#include "aurelion_rules/compat/godot_string.hpp"

#include <string>
#include <unordered_map>
#include <unordered_set>
#include <utility>

namespace aurelion::rules::port {

namespace {

using gd::array_value;
using gd::ArrayRef;
using gd::Atom;
using gd::bool_value;
using gd::dict_value;
using gd::DictRef;
using gd::int_value;
using gd::PackedRef;
using gd::str;
using overworld_rules::Vector2i;
using state::ContentTable;
using state::Kind;
using state::State;
using state::Value;
namespace key = state::key;
namespace level_rules = overworld_level_rules;

// STOP_RESOURCE, STOP_ARTIFACT, STOP_TOWN and STOP_ENCOUNTER.
constexpr int64_t kStopResource = 1;
constexpr int64_t kStopArtifact = 2;
constexpr int64_t kStopTown = 3;
constexpr int64_t kStopEncounter = 4;

// var a: Array = d.get(field, []) where the code only reads a: its size, 0
// (and no Array) when the key is missing.
int64_t array_field(const State &state, DictRef dict, Atom field, ArrayRef &array) {
	Value found;
	if (!state.lookup(dict, str(field), found)) {
		array = 0;
		return 0;
	}
	array = gd::as_array(found);
	return state.array_size(array);
}

// x.get(field, {}) of a value: a new empty Dictionary when the key is missing.
Value get_or_new_dict(State &state, const Value &object, Atom field) {
	if (!gd::is_dict(object)) {
		return ai::vget(state, object, field);
	}
	Value found;
	return state.lookup(object.ref, str(field), found) ? found : dict_value(state.new_dict());
}

// Vector2i(int(a), int(b)) as a Value.
Value vector2i_value(int64_t x, int64_t y) {
	const Vector2i tile = Vector2i::of(x, y);
	return Value::of_vector2i(tile.x, tile.y);
}

// {"kind": kind, "index": index}.
DictRef stop_ref(State &state, int64_t kind, int64_t index) {
	const DictRef ref = state.new_dict();
	state.set(ref, str(key::kind), int_value(kind));
	state.set(ref, str(key::index), int_value(index));
	return ref;
}

// tile is Vector2i and tile.x >= 0 and tile.y >= 0 and tile.x < size.x and tile.y < size.y.
bool tile_inside(const Value &tile, Vector2i size) {
	return gd::is_vector2i(tile) && tile.vx() >= 0 && tile.vy() >= 0 && tile.vx() < size.x && tile.vy() < size.y;
}

// tile.y * size.x + tile.x of a Vector2i Value.
int64_t tile_index_of(const Value &tile, Vector2i size) {
	return static_cast<int64_t>(tile.vy()) * size.x + tile.vx();
}

// String(key).split(",") of a blocked-index key (allow_empty): false when it has
// fewer than two parts, else int(parts[0]) and int(parts[1]).
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

} // namespace

namespace ai_hero_rules {

DictRef _boat_market(State &state, DictRef session, DictRef context, DictRef cost) {
	Value found;
	// context.get("state", {}): a missing state is an empty Dictionary, whose treasury is {}.
	const Value enemy_state = state.lookup(context, str(key::state), found) ? found : Value();
	DictRef treasury;
	if (gd::is_dict(enemy_state) && state.lookup(enemy_state.ref, str(key::treasury), found)) {
		treasury = gd::as_dict(found);
	} else {
		treasury = state.new_dict();
	}
	if (gd::is_empty(state, cost)) {
		return state.new_dict();
	}
	if (_can_afford(state, treasury, cost)) {
		const DictRef result = state.new_dict();
		state.set(result, str(key::treasury), bool_value(true));
		return result;
	}
	const DictRef cache = state.lookup(context, str(key::boat_market), found) ? gd::as_dict(found) : state.new_dict();
	const Value cache_key = int_value(gd::hash(state, dict_value(treasury)));
	if (state.has(cache, cache_key)) {
		return gd::as_dict(gd::index(state, cache, cache_key));
	}
	DictRef result = state.new_dict();
	const ArrayRef entries = enemy_turn_rules::_owned_town_entries(state, session, ai::string_or_empty(state, context, key::controller));
	for (const Value &entry : gd::items(state, array_value(entries))) {
		const DictRef town = gd::as_dict(get_or_new_dict(state, entry, key::town));
		if (_market_cover(state, session, town, treasury, cost, false)) {
			result = state.new_dict();
			state.set(result, str(key::town_index), int_value(gd::to_int(state, ai::vget(state, entry, key::index, int_value(-1)))));
			break;
		}
	}
	state.set(cache, cache_key, dict_value(result));
	state.set(context, str(key::boat_market), dict_value(cache));
	return result;
}

ArrayRef _hero_guards(State &state, DictRef session, DictRef context, int64_t level) {
	const Atom controller = gd::stringify(state, gd::index(state, context, str(key::controller)));
	const ArrayRef guards = state.new_array();
	const bool human_hostile = !player_identity_rules::allied(state, dict_value(session), controller, key::player);
	ArrayRef heroes;
	const int64_t hero_count = array_field(state, session_view::overworld(state, session), key::player_heroes, heroes);
	for (int64_t index = 0; index < hero_count; ++index) {
		const Value hero = state.at(heroes, index);
		Value position;
		if (!gd::is_dict(hero) || !state.lookup(hero.ref, str(key::position), position) || !gd::is_dict(position)) {
			continue;
		}
		if (gd::is_empty(state, position.ref) || level_rules::level_of(state, position) != level) {
			continue;
		}
		const DictRef guard = state.new_dict();
		state.set(guard, str(key::tile), vector2i_value(gd::int_field(state, position.ref, key::x, -1), gd::int_field(state, position.ref, key::y, -1)));
		state.set(guard, str(key::ref_kind), str(key::hero));
		state.set(guard, str(key::index), int_value(index));
		state.set(guard, str(key::id), str(ai::string_or_empty(state, hero.ref, key::id)));
		state.set(guard, str(key::hostile), bool_value(human_hostile));
		state.append(guards, dict_value(guard));
	}
	ArrayRef encounters;
	const int64_t encounter_count = array_field(state, session_view::overworld(state, session), key::encounters, encounters);
	const DictRef resolved = _resolved_lookup(state, session);
	for (int64_t index = 0; index < encounter_count; ++index) {
		const Value other = state.at(encounters, index);
		if (!gd::is_dict(other) || !gd::is_dict(gd::field(state, other.ref, key::ai_hero)) || level_rules::level_of(state, other) != level ||
				state.has(resolved, str(ai::string_or_empty(state, other.ref, key::placement_id)))) {
			continue;
		}
		const Atom other_controller = player_identity_rules::raid_controller_id(state, other.ref);
		const bool hostile = other_controller != controller && !player_identity_rules::allied(state, dict_value(session), controller, other_controller);
		const DictRef guard = state.new_dict();
		state.set(guard, str(key::tile), vector2i_value(gd::int_field(state, other.ref, key::x, -1), gd::int_field(state, other.ref, key::y, -1)));
		state.set(guard, str(key::ref_kind), str(key::ai_hero));
		state.set(guard, str(key::index), int_value(index));
		state.set(guard, str(key::id), str(ai::string_or_empty(state, other.ref, key::placement_id)));
		state.set(guard, str(key::hostile), bool_value(hostile));
		state.append(guards, dict_value(guard));
	}
	return guards;
}

ArrayRef _hero_zone_tiles(State &state, DictRef session, DictRef context, Vector2i tile, int64_t level) {
	Value found;
	const DictRef cache = state.lookup(context, str(key::hero_zone_tiles), found) ? gd::as_dict(found) : state.new_dict();
	// "%d:%d,%d" % [level, tile.x, tile.y]
	const Value cache_key = str(state.intern(compat::itos(level) + ":" + compat::itos(tile.x) + "," + compat::itos(tile.y)));
	if (!state.has(cache, cache_key)) {
		state.set(cache, cache_key, array_value(overworld_rules::hero_guard_zone_tiles(state, session, tile, level)));
		state.set(context, str(key::hero_zone_tiles), dict_value(cache));
	}
	return gd::as_array(gd::index(state, cache, cache_key));
}

DictRef _level_surface(State &state, DictRef session, DictRef context, int64_t level) {
	const DictRef levels = gd::as_dict(gd::index(state, context, str(key::levels)));
	if (state.has(levels, int_value(level))) {
		return gd::as_dict(gd::index(state, levels, int_value(level)));
	}
	const int64_t surface_started = gd::ticks_usec();
	const Value size_value = gd::index(state, context, str(key::map_size));
	if (!gd::is_vector2i(size_value)) {
		throw state::ScriptError(std::string("Trying to assign value of type '") + gd::type_name(size_value) + "' to a variable of type 'Vector2i'.");
	}
	const Vector2i size{size_value.vx(), size_value.vy()};
	const int64_t width = size.x;
	const int64_t height = size.y;
	const PackedRef blocked = gd::new_bytes(state);
	gd::packed_resize(state, blocked, width * height);
	const PackedRef water = gd::new_bytes(state);
	gd::packed_resize(state, water, width * height);
	int64_t water_count = 0;
	// Per terrain id: [passable, water].
	std::unordered_map<Atom, std::pair<bool, bool>> terrain_kinds;
	const ArrayRef rows = level_rules::terrain_rows(state, dict_value(session), level);
	for (int64_t y = 0; y < height; ++y) {
		ArrayRef row = 0;
		int64_t row_size = 0;
		if (y < state.array_size(rows)) {
			const Value row_value = state.at(rows, y);
			if (gd::is_array(row_value)) {
				row = row_value.ref;
				row_size = state.array_size(row);
			}
		}
		for (int64_t x = 0; x < width; ++x) {
			if (x >= row_size) {
				gd::packed_set(state, blocked, y * width + x, 1);
				continue;
			}
			const Atom terrain = gd::stringify(state, state.at(row, x));
			auto kind = terrain_kinds.find(terrain);
			if (kind == terrain_kinds.end()) {
				const bool passable = overworld_rules::terrain_id_is_passable(state, terrain);
				const bool is_water = content_service::normalize_terrain_id(state, terrain) == key::water;
				kind = terrain_kinds.emplace(terrain, std::make_pair(passable, is_water)).first;
			}
			if (!kind->second.first) {
				gd::packed_set(state, blocked, y * width + x, 1);
			}
			if (kind->second.second) {
				gd::packed_set(state, water, y * width + x, 1);
				water_count += 1;
			}
		}
	}
	// Open water a boat sails over: water without an object's body on it.
	const PackedRef sea = gd::packed_duplicate(state, water);
	// Armies move and are added for each search: every army body on the level is
	// left out of the static bodies, so the index skips all encounters.
	std::unordered_set<Atom> army_tiles;
	const DictRef every_encounter = state.new_dict();
	const DictRef overworld = session_view::overworld(state, session);
	for (const Value &encounter : gd::field_items(state, overworld, str(key::encounters))) {
		if (!gd::is_dict(encounter)) {
			continue;
		}
		state.set(every_encounter, str(overworld_rules::encounter_key(state, encounter.ref)), bool_value(true));
		if (level_rules::level_of(state, encounter) == level) {
			for (const Vector2i tile : overworld_rules::_generated_body_tiles_for_placement(state, encounter.ref, gd::bool_field(state, encounter.ref, key::blocking_body, true))) {
				army_tiles.insert(overworld_rules::_tile_key(state, tile));
			}
		}
	}
	const DictRef bodies = overworld_rules::_build_blocked_tile_index(state, session, level, key::empty, every_encounter);
	for (const Value &body_key : gd::items(state, dict_value(bodies))) {
		if (body_key.is_string_like() && army_tiles.count(body_key.ref) != 0) {
			continue;
		}
		const std::string text = state.text(gd::stringify(state, body_key));
		int64_t x = 0;
		int64_t y = 0;
		if (!split_pair(text, x, y)) {
			continue;
		}
		if (x >= 0 && y >= 0 && x < width && y < height) {
			gd::packed_set(state, blocked, y * width + x, 1);
			gd::packed_set(state, sea, y * width + x, 0);
		}
	}
	const DictRef stops = state.new_dict();
	ArrayRef resources;
	const int64_t resource_count = array_field(state, session_view::overworld(state, session), key::resource_nodes, resources);
	for (int64_t index = 0; index < resource_count; ++index) {
		const Value node = state.at(resources, index);
		if (!gd::is_dict(node) || level_rules::level_of(state, node) != level) {
			continue;
		}
		const DictRef map_object = overworld_rules::_map_object_for_resource_node(state, node.ref);
		for (const Value &tile : gd::items(state, array_value(overworld_rules::_resource_node_world_interaction_tiles(state, map_object, node.ref)))) {
			if (gd::is_vector2i(tile)) {
				_add_stop(state, stops, Vector2i{tile.vx(), tile.vy()}, size, stop_ref(state, kStopResource, index));
			}
		}
	}
	ArrayRef artifacts;
	const int64_t artifact_count = array_field(state, session_view::overworld(state, session), key::artifact_nodes, artifacts);
	for (int64_t index = 0; index < artifact_count; ++index) {
		const Value artifact = state.at(artifacts, index);
		if (gd::is_dict(artifact) && level_rules::level_of(state, artifact) == level) {
			const Vector2i tile = Vector2i::of(gd::int_field(state, artifact.ref, key::x, -1), gd::int_field(state, artifact.ref, key::y, -1));
			_add_stop(state, stops, tile, size, stop_ref(state, kStopArtifact, index));
		}
	}
	ArrayRef towns;
	const int64_t town_count = array_field(state, session_view::overworld(state, session), key::towns, towns);
	for (int64_t index = 0; index < town_count; ++index) {
		const Value town = state.at(towns, index);
		if (gd::is_dict(town) && level_rules::level_of(state, town) == level) {
			const DictRef entrance = level_rules::town_entrance(state, town.ref);
			const Vector2i tile = Vector2i::of(gd::int_field(state, entrance, key::x, -1), gd::int_field(state, entrance, key::y, -1));
			_add_stop(state, stops, tile, size, stop_ref(state, kStopTown, index));
		}
	}
	const PackedRef stop_mask = gd::new_bytes(state);
	gd::packed_resize(state, stop_mask, width * height);
	// Map sites a hero may also walk across once they hold nothing more for it
	// (a picked-up cache, its own mine). Towns always end a route.
	const ArrayRef site_stops = state.new_array();
	for (const Value &tile_index : gd::items(state, dict_value(stops))) {
		gd::packed_set(state, stop_mask, gd::to_int(state, tile_index), 1);
		bool sites_only = true;
		for (const Value &ref : gd::items(state, gd::index(state, stops, tile_index))) {
			const int64_t kind = gd::to_int(state, ai::vmember(state, ref, key::kind));
			if (kind != kStopResource && kind != kStopArtifact) {
				sites_only = false;
			}
		}
		if (sites_only) {
			const ArrayRef refs = state.new_array();
			for (const Value &ref : gd::items(state, gd::index(state, stops, tile_index))) {
				const int64_t kind = gd::to_int(state, ai::vmember(state, ref, key::kind));
				const int64_t ref_index = gd::to_int(state, ai::vmember(state, ref, key::index));
				state.append(refs, dict_value(stop_ref(state, kind, ref_index)));
			}
			const DictRef site = state.new_dict();
			state.set(site, str(key::tile), int_value(gd::to_int(state, tile_index)));
			state.set(site, str(key::refs), array_value(refs));
			state.append(site_stops, dict_value(site));
		}
	}
	// Neutral armies stand still: decode their bodies and engagement zones once.
	const ArrayRef neutrals = state.new_array();
	ArrayRef encounters;
	const int64_t encounter_count = array_field(state, session_view::overworld(state, session), key::encounters, encounters);
	for (int64_t index = 0; index < encounter_count; ++index) {
		const Value encounter = state.at(encounters, index);
		if (!gd::is_dict(encounter) || level_rules::level_of(state, encounter) != level || player_identity_rules::raid_controller_id(state, encounter.ref) != key::empty) {
			continue;
		}
		const ArrayRef body = state.new_array();
		for (const Vector2i tile : overworld_rules::_generated_body_tiles_for_placement(state, encounter.ref, gd::bool_field(state, encounter.ref, key::blocking_body, true))) {
			if (tile.x >= 0 && tile.y >= 0 && tile.x < size.x && tile.y < size.y) {
				state.append(body, int_value(static_cast<int64_t>(tile.y) * size.x + tile.x));
			}
		}
		const ArrayRef zone = state.new_array();
		const ArrayRef engagement = overworld_rules::_guard_engagement_world_tiles(state, encounter.ref);
		if (state.array_size(engagement) == 0) {
			const Value tile = vector2i_value(gd::int_field(state, encounter.ref, key::x, -1), gd::int_field(state, encounter.ref, key::y, -1));
			if (tile_inside(tile, size)) {
				state.append(zone, int_value(tile_index_of(tile, size)));
			}
		} else {
			for (const Value &tile : gd::items(state, array_value(engagement))) {
				if (tile_inside(tile, size)) {
					state.append(zone, int_value(tile_index_of(tile, size)));
				}
			}
		}
		const DictRef record = state.new_dict();
		state.set(record, str(key::id), str(ai::string_or_empty(state, encounter.ref, key::placement_id)));
		state.set(record, str(key::index), int_value(index));
		state.set(record, str(key::body), array_value(body));
		state.set(record, str(key::zone), array_value(zone));
		state.set(record, str(key::ref), dict_value(stop_ref(state, kStopEncounter, index)));
		state.append(neutrals, dict_value(record));
	}
	// Portals on this level, by entrance tile: their exits on this level and the
	// portal node. One that sends travellers to one of several exits at random
	// keeps their number (`random`) and its exits on another level (`far_exits`):
	// a hero stepping in may come out there.
	const DictRef portals = state.new_dict();
	for (int64_t index = 0; index < resource_count; ++index) {
		const Value node = state.at(resources, index);
		if (!gd::is_dict(node) || level_rules::level_of(state, node) != level || !native_transit_rules::is_native(state, node.ref)) {
			continue;
		}
		const Atom kind = native_transit_rules::portal_kind(state, node.ref);
		if (kind != key::two_way_portal && kind != key::one_way_entrance) {
			continue;
		}
		const ArrayRef options = native_transit_rules::destinations(state, node.ref);
		const int64_t option_count = state.array_size(options);
		const PackedRef exits = gd::new_ints(state);
		const ArrayRef far_exits = state.new_array();
		for (const Value &option : gd::items(state, array_value(options))) {
			const Value exit = native_transit_rules::point(state, get_or_new_dict(state, option, key::exit));
			if (exit.vz() < 0 || exit.vx() < 0 || exit.vy() < 0 || exit.vx() >= size.x || exit.vy() >= size.y) {
				continue;
			}
			if (exit.vz() == level) {
				gd::packed_append(state, exits, static_cast<int64_t>(exit.vy()) * size.x + exit.vx());
			} else {
				state.append(far_exits, exit);
			}
		}
		// A portal whose one exit is on the other level is a gate (below).
		if (gd::packed_size(state, exits) == 0 && (option_count < 2 || state.array_size(far_exits) == 0)) {
			continue;
		}
		const DictRef map_object = overworld_rules::_map_object_for_resource_node(state, node.ref);
		for (const Value &tile : gd::items(state, array_value(overworld_rules::_resource_node_world_interaction_tiles(state, map_object, node.ref)))) {
			if (tile_inside(tile, size)) {
				const DictRef portal = state.new_dict();
				state.set(portal, str(key::exits), gd::ints_value(exits));
				state.set(portal, str(key::node), int_value(index));
				if (option_count > 1) {
					state.set(portal, str(key::random), int_value(option_count));
				}
				if (state.array_size(far_exits) != 0) {
					state.set(portal, str(key::far_exits), array_value(far_exits));
				}
				state.set(portals, int_value(tile_index_of(tile, size)), dict_value(portal));
			}
		}
	}
	// Subterranean gates on this level, by entrance tile, with the tile on the
	// other level a hero comes out on. A portal whose one exit is on the other
	// level is such a gate too, and so is one that sends travellers at random to
	// one of several exits, some on another level: it keeps their number
	// (`random`) and those exits (`far_exits`), the first of them as its exit.
	const DictRef gates = state.new_dict();
	for (int64_t index = 0; index < resource_count; ++index) {
		const Value node = state.at(resources, index);
		if (!gd::is_dict(node) || level_rules::level_of(state, node) != level || !native_transit_rules::is_native(state, node.ref)) {
			continue;
		}
		const DictRef link = native_transit_rules::link_of(state, node.ref);
		const ArrayRef options = native_transit_rules::destinations(state, node.ref);
		const int64_t option_count = state.array_size(options);
		bool random = false;
		if (ai::string_or_empty(state, link, key::kind) != key::paired_cave) {
			const Atom kind = native_transit_rules::portal_kind(state, node.ref);
			if (!((kind == key::two_way_portal || kind == key::one_way_entrance) && option_count >= 1)) {
				continue;
			}
			random = option_count > 1;
		}
		const Value entrance = native_transit_rules::point(state, get_or_new_dict(state, dict_value(link), key::entry));
		const ArrayRef far_exits = state.new_array();
		if (random) {
			for (const Value &option : gd::items(state, array_value(options))) {
				const Value exit = native_transit_rules::point(state, get_or_new_dict(state, option, key::exit));
				if (exit.vz() != level && exit.vz() >= 0 && exit.vx() >= 0 && exit.vy() >= 0 && exit.vx() < size.x && exit.vy() < size.y) {
					state.append(far_exits, exit);
				}
			}
		} else {
			const Value exit = native_transit_rules::point(state, option_count != 0 ? get_or_new_dict(state, state.at(options, 0), key::exit) : get_or_new_dict(state, dict_value(link), key::exit));
			if (exit.vz() != level && exit.vz() >= 0 && exit.vx() >= 0 && exit.vy() >= 0 && exit.vx() < size.x && exit.vy() < size.y) {
				state.append(far_exits, exit);
			}
		}
		if (entrance.vz() != level || state.array_size(far_exits) == 0) {
			continue;
		}
		if (entrance.vx() >= 0 && entrance.vy() >= 0 && entrance.vx() < size.x && entrance.vy() < size.y) {
			const DictRef gate = state.new_dict();
			state.set(gate, str(key::node), int_value(index));
			state.set(gate, str(key::exit), state.at(far_exits, 0));
			if (random) {
				state.set(gate, str(key::random), int_value(option_count));
				state.set(gate, str(key::far_exits), array_value(far_exits));
			}
			state.set(gates, int_value(static_cast<int64_t>(entrance.vy()) * size.x + entrance.vx()), dict_value(gate));
		}
	}
	// Shipyards on this level, by visit tile, with the dock where the boat they
	// build is launched.
	const DictRef shipyards = state.new_dict();
	if (water_count > 0) {
		for (int64_t index = 0; index < resource_count; ++index) {
			const Value node = state.at(resources, index);
			if (!gd::is_dict(node) || level_rules::level_of(state, node) != level || ai::string_or_empty(state, node.ref, key::site_id) != key::site_shipyard) {
				continue;
			}
			const DictRef dock = water_travel_rules::dock_tile(state, dict_value(session), node.ref);
			if (gd::is_empty(state, dock)) {
				continue;
			}
			const DictRef map_object = overworld_rules::_map_object_for_resource_node(state, node.ref);
			for (const Value &tile : gd::items(state, array_value(overworld_rules::_resource_node_world_interaction_tiles(state, map_object, node.ref)))) {
				if (tile_inside(tile, size)) {
					const DictRef yard = state.new_dict();
					state.set(yard, str(key::node), int_value(index));
					const int64_t dock_y = gd::to_int(state, gd::index(state, dock, str(key::y)));
					const int64_t dock_x = gd::to_int(state, gd::index(state, dock, str(key::x)));
					state.set(yard, str(key::dock), int_value(gd::add(gd::mul(dock_y, width), dock_x)));
					state.set(shipyards, int_value(tile_index_of(tile, size)), dict_value(yard));
				}
			}
		}
	}
	const DictRef surface = state.new_dict();
	state.set(surface, str(key::blocked), gd::bytes_value(blocked));
	state.set(surface, str(key::stops), dict_value(stops));
	state.set(surface, str(key::stop_mask), gd::bytes_value(stop_mask));
	state.set(surface, str(key::site_stops), array_value(site_stops));
	state.set(surface, str(key::neutrals), array_value(neutrals));
	state.set(surface, str(key::portals), dict_value(portals));
	state.set(surface, str(key::gates), dict_value(gates));
	state.set(surface, str(key::water), gd::bytes_value(water));
	state.set(surface, str(key::water_count), int_value(water_count));
	state.set(surface, str(key::sea), gd::bytes_value(sea));
	state.set(surface, str(key::shipyards), dict_value(shipyards));
	const DictRef shipyard_site = gd::content_row(state, ContentTable::ResourceSite, key::site_shipyard);
	state.set(surface, str(key::boat_cost), dict_value(visit_building_rules::cost(state, shipyard_site, key::build_boat)));
	state.set(levels, int_value(level), dict_value(surface));
	_profile_add(state, context, key::surface_ms, surface_started);
	return surface;
}

ArrayRef _open_guard_zones(State &state, DictRef surface) {
	Value found;
	if (state.lookup(surface, str(key::open_zones), found)) {
		return gd::as_array(found);
	}
	const PackedRef blocked = gd::as_bytes(gd::index(state, surface, str(key::blocked)));
	const PackedRef water = state.lookup(surface, str(key::water), found) ? gd::as_bytes(found) : gd::new_bytes(state);
	const DictRef static_stops = gd::as_dict(gd::index(state, surface, str(key::stops)));
	const ArrayRef zones = state.new_array();
	for (const Value &record : gd::items(state, gd::index(state, surface, str(key::neutrals)))) {
		const ArrayRef zone = state.new_array();
		for (const Value &zone_index : gd::items(state, ai::vmember(state, record, key::zone))) {
			// Rock or an object's body inside the zone is no place to stand; only
			// a doorway or visit tile there can be entered.
			const int64_t tile = gd::to_int(state, zone_index);
			if (gd::packed_int(state, blocked, tile) != 0 && !state.has(static_stops, int_value(tile)) &&
					!(tile < gd::packed_size(state, water) && gd::packed_int(state, water, tile) != 0)) {
				continue;
			}
			state.append(zone, int_value(tile));
		}
		state.append(zones, array_value(zone));
	}
	state.set(surface, str(key::open_zones), array_value(zones));
	return zones;
}

PackedRef _portal_exits(State &state, DictRef portal, PackedRef seen_map) {
	const PackedRef exits = gd::as_ints(gd::index(state, portal, str(key::exits)));
	if (gd::packed_size(state, exits) == 1) {
		return exits;
	}
	const PackedRef known = gd::new_ints(state);
	const int64_t count = gd::packed_size(state, exits);
	for (int64_t at = 0; at < count; ++at) {
		const int64_t exit = gd::packed_int(state, exits, at);
		if (exit < gd::packed_size(state, seen_map) && gd::packed_int(state, seen_map, exit) != 0) {
			gd::packed_append(state, known, exit);
		}
	}
	return known;
}

bool _portal_leads_unseen(State &state, DictRef session, DictRef context, DictRef portal, PackedRef seen_map) {
	for (const Value &exit : gd::items(state, gd::index(state, portal, str(key::exits)))) {
		if (exit.kind != Kind::Int) {
			throw state::NotPorted("AiHeroRules._portal_leads_unseen: an exit that is not an int");
		}
		if (exit.i >= gd::packed_size(state, seen_map) || gd::packed_int(state, seen_map, exit.i) == 0) {
			return true;
		}
	}
	// An exit on another level, where a random portal may send the hero.
	Value far_exits;
	if (state.lookup(portal, str(key::far_exits), far_exits)) {
		const int64_t width = gd::index(state, context, str(key::map_size)).vx();
		for (const Value &exit : gd::items(state, far_exits)) {
			const PackedRef far_seen = _explored(state, session, context, exit.vz());
			const int64_t tile = static_cast<int64_t>(exit.vy()) * width + exit.vx();
			if (tile >= gd::packed_size(state, far_seen) || gd::packed_int(state, far_seen, tile) == 0) {
				return true;
			}
		}
	}
	return false;
}

bool _site_stop_passable(State &state, DictRef session, Atom controller, DictRef ref, ArrayRef nodes, ArrayRef artifacts, DictRef allies) {
	const int64_t kind = gd::to_int(state, gd::index(state, ref, str(key::kind)));
	if (kind == kStopArtifact) {
		const int64_t index = gd::to_int(state, gd::index(state, ref, str(key::index)));
		// Past the end it is {}, which holds no "collected".
		if (index >= state.array_size(artifacts)) {
			return false;
		}
		const Value artifact = state.at(artifacts, index);
		return gd::is_dict(artifact) && gd::bool_field(state, artifact.ref, key::collected, false);
	}
	if (kind == kStopResource) {
		const int64_t index = gd::to_int(state, gd::index(state, ref, str(key::index)));
		const Value node = index < state.array_size(nodes) ? state.at(nodes, index) : dict_value(state.new_dict());
		if (!gd::is_dict(node) || native_transit_rules::is_native(state, node.ref)) {
			return false;
		}
		const ArrayRef site_class = _site_pass_class(state, ai::string_or_empty(state, node.ref, key::site_id));
		if (!gd::to_bool(state.at(site_class, 0))) {
			return false;
		}
		// A building a hero visits and leaves standing can be crossed on the way
		// elsewhere.
		if (gd::to_bool(state.at(site_class, 1))) {
			return true;
		}
		// A collected pickup is gone; a looted one-time site that stays standing
		// holds nothing for anyone.
		if (gd::bool_field(state, node.ref, key::collected, false) && !gd::to_bool(state.at(site_class, 2))) {
			return true;
		}
		const Atom owner = player_identity_rules::resource_controller_id(state, node.ref);
		if (owner == key::empty) {
			return false;
		}
		if (!state.has(allies, str(owner))) {
			state.set(allies, str(owner), bool_value(player_identity_rules::allied(state, dict_value(session), controller, owner)));
		}
		return gd::to_bool(gd::index(state, allies, str(owner)));
	}
	return false;
}

PackedRef _decision_site_pass(State &state, DictRef context, int64_t level, ArrayRef sites) {
	const Value by_level = state.get(context, str(key::decision_site_pass), Value());
	if (!gd::is_dict(by_level)) {
		return gd::new_bytes(state);
	}
	Value found;
	DictRef record = 0;
	bool renew = true;
	if (state.lookup(by_level.ref, int_value(level), found)) {
		record = gd::as_dict(found);
		renew = gd::is_empty(state, record) || !gd::is_same(state, gd::index(state, record, str(key::sites)), array_value(sites));
	}
	if (renew) {
		const PackedRef open = gd::new_bytes(state);
		gd::packed_resize(state, open, state.array_size(sites));
		record = state.new_dict();
		state.set(record, str(key::sites), array_value(sites));
		state.set(record, str(key::open), gd::bytes_value(open));
		state.set(by_level.ref, int_value(level), dict_value(record));
	}
	return gd::as_bytes(gd::index(state, record, str(key::open)));
}

} // namespace ai_hero_rules

} // namespace aurelion::rules::port
