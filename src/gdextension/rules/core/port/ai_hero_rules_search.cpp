// AiHeroRules: the computer heroes' map search (the search kernel's inputs and
// tables, the walk, the route-ending stops reached) and the route helpers.

#include "aurelion_rules/port/ai_hero_rules_ai.hpp"

#include "aurelion_rules/ai_search.hpp"
#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/native_transit_rules_ai.hpp"
#include "aurelion_rules/port/overworld_level_rules.hpp"
#include "aurelion_rules/port/player_identity_rules_ai.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/water_travel_rules_ai.hpp"

#include <cstdint>
#include <exception>
#include <string>
#include <vector>

namespace aurelion::rules::port {

namespace {

using gd::array_value;
using gd::ArrayRef;
using gd::Atom;
using gd::bool_value;
using gd::bytes_value;
using gd::dict_value;
using gd::DictRef;
using gd::int_value;
using gd::ints_value;
using gd::PackedRef;
using gd::str;
using overworld_rules::Vector2i;
using state::State;
using state::Value;
namespace key = state::key;
namespace level_rules = overworld_level_rules;

// AiHeroRules.STOP_HERO and STOP_AI_HERO, and the step kind of a route that
// buys its boat.
constexpr int64_t kStopHero = 5;
constexpr int64_t kStopAiHero = 6;
constexpr int64_t kBoughtBoat = 4;

// var x: Vector2i = value.
Vector2i to_vector2i(const Value &value) {
	if (!gd::is_vector2i(value)) {
		throw state::ScriptError(std::string("Trying to assign value of type '") + gd::type_name(value) + "' to a variable of type 'Vector2i'.");
	}
	return Vector2i{value.vx(), value.vy()};
}

// tile.y * width + tile.x of an untyped tile.
int64_t tile_index_value(State &state, const Value &tile, int64_t width) {
	const Value product = gd::op_mul(ai::vmember(state, tile, key::y), int_value(width));
	return gd::to_int(state, gd::op_add(product, ai::vmember(state, tile, key::x)));
}

// var x: Array = d.get(field, []) that is only read: false when missing.
bool optional_array(const State &state, DictRef dict, Atom field, ArrayRef &out) {
	Value found;
	if (!state.lookup(dict, str(field), found)) {
		return false;
	}
	out = gd::as_array(found);
	return true;
}

// var x: Array = d.get(field, []) that is passed on.
ArrayRef array_or_new(State &state, DictRef dict, Atom field) {
	ArrayRef found = 0;
	return optional_array(state, dict, field, found) ? found : state.new_array();
}

DictRef stop_ref(State &state, int64_t kind, int64_t index) {
	const DictRef ref = state.new_dict();
	state.set(ref, str(key::kind), int_value(kind));
	state.set(ref, str(key::index), int_value(index));
	return ref;
}

// if not stops.has(tile_index): stops[tile_index] = []; stops[tile_index].append(ref)
void append_stop(State &state, DictRef stops, int64_t tile_index, DictRef ref) {
	const Value tile_key = int_value(tile_index);
	if (!state.has(stops, tile_key)) {
		state.set(stops, tile_key, array_value(state.new_array()));
	}
	state.append(gd::as_array(gd::index(state, stops, tile_key)), dict_value(ref));
}

// The native search kernel as AurelionRules.ai_search_masks and ai_search_walk
// (gdextension/aurelion_rules_api.cpp) call it: where the adapter pushes an
// error and answers an empty Array, GDScript would stop on that Array.
[[noreturn]] void kernel_refused(const char *method, const std::string &what) {
	throw state::NotPorted(std::string("AiHeroRules._search: AurelionRules.") + method + ": " + what);
}

void check_map(int64_t width, int64_t height, const char *method) {
	if (width > 0 && height > 0 && width <= 1 << 20 && height <= 1 << 20 && width * height <= INT32_MAX) {
		return;
	}
	kernel_refused(method, "bad map size " + std::to_string(width) + "x" + std::to_string(height));
}

void check_tile_mask(const State &state, PackedRef mask, int64_t count, bool may_be_empty, const char *method, const char *what) {
	const int64_t size = gd::packed_size(state, mask);
	if (size == count || (may_be_empty && size == 0)) {
		return;
	}
	kernel_refused(method, std::string(what) + " has " + std::to_string(size) + " bytes, expected " + std::to_string(count));
}

ai_search::Span span_of(const State &state, PackedRef items) {
	const int64_t size = gd::packed_size(state, items);
	return ai_search::Span{gd::packed_ints(state, items), size};
}

ai_search::Bytes bytes_of(const State &state, PackedRef items) {
	const int64_t size = gd::packed_size(state, items);
	return ai_search::Bytes{gd::packed_bytes(state, items), size};
}

ai_search::Lists lists_of(const State &state, PackedRef offsets, PackedRef items, const char *method, const char *what) {
	const int64_t offset_count = gd::packed_size(state, offsets);
	const int64_t item_count = gd::packed_size(state, items);
	if (offset_count == 0) {
		if (item_count != 0) {
			kernel_refused(method, std::string(what) + " has items and no offsets");
		}
		return ai_search::Lists{};
	}
	return ai_search::Lists{gd::packed_ints(state, offsets), offset_count - 1, gd::packed_ints(state, items), item_count};
}

PackedRef new_tile_bytes(State &state, int64_t count) {
	const PackedRef bytes = gd::new_bytes(state);
	gd::packed_resize(state, bytes, count);
	return bytes;
}

PackedRef new_tile_ints(State &state, int64_t count) {
	const PackedRef ints = gd::new_ints(state);
	gd::packed_resize(state, ints, count);
	return ints;
}

PackedRef ints_of(State &state, const std::vector<int32_t> &items) {
	const PackedRef packed = gd::new_ints(state);
	gd::packed_resize(state, packed, static_cast<int64_t>(items.size()));
	std::vector<int32_t> &out = state.packed_write(packed).ints;
	for (size_t at = 0; at < items.size(); ++at) {
		out[at] = items[at];
	}
	return packed;
}

// NativeRules.api().ai_search_masks(...): [blocked, stop_mask, guard_mask,
// hero_zone, pass_mask, sea_open, zone_stops, pending sites].
ArrayRef search_masks(State &state, int64_t width, int64_t height, PackedRef surface_blocked, PackedRef surface_stops, PackedRef water, PackedRef sea, PackedRef body_offsets, PackedRef body_tiles, PackedRef zone_offsets, PackedRef zone_tiles, PackedRef neutral_open, PackedRef unit_blocked, PackedRef unit_stops, PackedRef hero_tiles, PackedRef guard_offsets, PackedRef guard_tiles, PackedRef site_tiles, PackedRef site_open) {
	const char *method = "ai_search_masks";
	check_map(width, height, method);
	const int64_t count = width * height;
	check_tile_mask(state, surface_blocked, count, false, method, "surface_blocked");
	check_tile_mask(state, surface_stops, count, false, method, "surface_stops");
	check_tile_mask(state, sea, count, true, method, "sea");
	ai_search::PrepareInput in;
	in.width = width;
	in.height = height;
	in.bodies = lists_of(state, body_offsets, body_tiles, method, "bodies");
	in.zones = lists_of(state, zone_offsets, zone_tiles, method, "zones");
	in.guard_zones = lists_of(state, guard_offsets, guard_tiles, method, "guard zones");
	if (gd::packed_size(state, neutral_open) != in.bodies.count) {
		kernel_refused(method, "neutral_open has " + std::to_string(gd::packed_size(state, neutral_open)) + " entries for " + std::to_string(in.bodies.count) + " armies");
	}
	const bool has_sea = !gd::packed_is_empty(state, sea);
	in.surface_blocked = gd::packed_bytes(state, surface_blocked);
	in.surface_stops = gd::packed_bytes(state, surface_stops);
	in.water = bytes_of(state, water);
	in.sea = has_sea ? gd::packed_bytes(state, sea) : nullptr;
	in.neutral_open = gd::packed_bytes(state, neutral_open);
	in.unit_blocked = span_of(state, unit_blocked);
	in.unit_stops = span_of(state, unit_stops);
	in.hero_tiles = span_of(state, hero_tiles);
	in.site_tiles = span_of(state, site_tiles);
	in.site_open = bytes_of(state, site_open);
	const PackedRef blocked = new_tile_bytes(state, count);
	const PackedRef stop_mask = new_tile_bytes(state, count);
	const PackedRef guard_mask = new_tile_bytes(state, count);
	const PackedRef hero_zone = new_tile_bytes(state, count);
	const PackedRef pass_mask = new_tile_bytes(state, count);
	const PackedRef sea_open = gd::new_bytes(state);
	if (has_sea) {
		gd::packed_resize(state, sea_open, count);
	}
	ai_search::PrepareOutput out;
	out.blocked = state.packed_write(blocked).bytes.data();
	out.stop_mask = state.packed_write(stop_mask).bytes.data();
	out.guard_mask = state.packed_write(guard_mask).bytes.data();
	out.hero_zone = state.packed_write(hero_zone).bytes.data();
	out.pass_mask = state.packed_write(pass_mask).bytes.data();
	out.sea_open = has_sea ? state.packed_write(sea_open).bytes.data() : nullptr;
	try {
		ai_search::prepare(in, out);
	} catch (const std::exception &error) {
		kernel_refused(method, std::string("native exception: ") + error.what());
	}
	const ArrayRef result = state.new_array();
	state.append(result, bytes_value(blocked));
	state.append(result, bytes_value(stop_mask));
	state.append(result, bytes_value(guard_mask));
	state.append(result, bytes_value(hero_zone));
	state.append(result, bytes_value(pass_mask));
	state.append(result, bytes_value(sea_open));
	state.append(result, ints_value(ints_of(state, out.zone_stops)));
	state.append(result, ints_value(ints_of(state, out.pending_sites)));
	return result;
}

// NativeRules.api().ai_search_walk(...): [dist, parent, order, order_count,
// capped, phase, reached].
ArrayRef search_walk(State &state, int64_t width, int64_t height, int64_t start, int64_t start_phase, int64_t radius, bool native_corners, PackedRef blocked, PackedRef stop_mask, PackedRef pass_mask, PackedRef hero_zone, PackedRef portals, PackedRef seen, PackedRef water, PackedRef sea_open, PackedRef boats, PackedRef docks, int64_t shore_cost, int64_t dock_cost) {
	const char *method = "ai_search_walk";
	check_map(width, height, method);
	const int64_t count = width * height;
	const bool has_water = !gd::packed_is_empty(state, water);
	check_tile_mask(state, blocked, count, false, method, "blocked");
	check_tile_mask(state, stop_mask, count, false, method, "stop_mask");
	check_tile_mask(state, pass_mask, count, false, method, "pass_mask");
	check_tile_mask(state, hero_zone, count, false, method, "hero_zone");
	check_tile_mask(state, water, count, true, method, "water");
	if (has_water) {
		check_tile_mask(state, sea_open, count, false, method, "sea_open");
		check_tile_mask(state, boats, count, false, method, "boats");
	}
	ai_search::Board board;
	board.width = width;
	board.height = height;
	board.blocked = gd::packed_bytes(state, blocked);
	board.stop_mask = gd::packed_bytes(state, stop_mask);
	board.pass_mask = gd::packed_bytes(state, pass_mask);
	board.hero_zone = gd::packed_bytes(state, hero_zone);
	board.native_corners = native_corners;
	board.portals = span_of(state, portals);
	board.seen = bytes_of(state, seen);
	if (has_water) {
		board.water = gd::packed_bytes(state, water);
		board.sea_open = gd::packed_bytes(state, sea_open);
		board.boats = gd::packed_bytes(state, boats);
		board.docks = span_of(state, docks);
	}
	board.shore_cost = shore_cost;
	board.dock_cost = dock_cost;
	const PackedRef dist = new_tile_ints(state, count);
	const PackedRef parent = new_tile_ints(state, count);
	const PackedRef order = new_tile_ints(state, count);
	const PackedRef phase = gd::new_bytes(state);
	if (has_water) {
		gd::packed_resize(state, phase, count);
	}
	ai_search::Output out;
	out.dist = state.packed_write(dist).ints.data();
	out.parent = state.packed_write(parent).ints.data();
	out.order = state.packed_write(order).ints.data();
	out.phase = has_water ? state.packed_write(phase).bytes.data() : nullptr;
	try {
		ai_search::search(board, start, start_phase, radius, out);
	} catch (const std::exception &error) {
		kernel_refused(method, std::string("native exception: ") + error.what());
	}
	const ArrayRef result = state.new_array();
	state.append(result, ints_value(dist));
	state.append(result, ints_value(parent));
	state.append(result, ints_value(order));
	state.append(result, int_value(out.order_count));
	state.append(result, bool_value(out.capped));
	state.append(result, bytes_value(phase));
	state.append(result, ints_value(ints_of(state, out.reached)));
	return result;
}

} // namespace

namespace ai_hero_rules {

void _add_stop(State &state, DictRef stops, Vector2i tile, Vector2i size, DictRef ref) {
	if (tile.x < 0 || tile.y < 0 || tile.x >= size.x || tile.y >= size.y) {
		return;
	}
	append_stop(state, stops, static_cast<int64_t>(tile.y) * size.x + tile.x, ref);
}

DictRef _search_tables(State &state, DictRef surface, DictRef resolved) {
	const ArrayRef neutrals = gd::as_array(gd::index(state, surface, str(key::neutrals)));
	Value found;
	DictRef tables = 0;
	bool tables_empty = true;
	if (state.lookup(surface, str(key::search_tables), found)) {
		tables = gd::as_dict(found);
		tables_empty = gd::is_empty(state, tables);
	}
	if (tables_empty) {
		const PackedRef body_offsets = gd::new_ints(state);
		gd::packed_append(state, body_offsets, 0);
		const PackedRef body_tiles = gd::new_ints(state);
		for (const Value &record : gd::items(state, array_value(neutrals))) {
			for (const Value &body_index : gd::items(state, ai::vmember(state, record, key::body))) {
				gd::packed_append(state, body_tiles, gd::to_int(state, body_index));
			}
			gd::packed_append(state, body_offsets, gd::packed_size(state, body_tiles));
		}
		const PackedRef site_tiles = gd::new_ints(state);
		for (const Value &site : gd::field_items(state, surface, str(key::site_stops))) {
			gd::packed_append(state, site_tiles, gd::to_int(state, ai::vmember(state, site, key::tile)));
		}
		// [entrance, exit count, exits...] per portal.
		const PackedRef portal_list = gd::new_ints(state);
		if (state.lookup(surface, str(key::portals), found)) {
			const DictRef portals = gd::as_dict(found);
			for (const Value &tile_index : gd::items(state, dict_value(portals))) {
				const PackedRef exits = gd::as_ints(ai::vmember(state, gd::index(state, portals, tile_index), key::exits));
				gd::packed_append(state, portal_list, gd::to_int(state, tile_index));
				gd::packed_append(state, portal_list, gd::packed_size(state, exits));
				gd::packed_append_array(state, portal_list, exits);
			}
		}
		tables = state.new_dict();
		state.set(tables, str(key::body_offsets), ints_value(body_offsets));
		state.set(tables, str(key::body_tiles), ints_value(body_tiles));
		state.set(tables, str(key::site_tiles), ints_value(site_tiles));
		state.set(tables, str(key::portals), ints_value(portal_list));
		state.set(surface, str(key::search_tables), dict_value(tables));
	}
	const ArrayRef open_zones = _open_guard_zones(state, surface);
	if (!gd::is_same(state, state.get(tables, str(key::open_zones), Value()), array_value(open_zones))) {
		const PackedRef zone_offsets = gd::new_ints(state);
		gd::packed_append(state, zone_offsets, 0);
		const PackedRef zone_tiles = gd::new_ints(state);
		// Per zone tile, the armies (places in surface.neutrals) whose zone holds it, in order.
		const DictRef zone_records = state.new_dict();
		const int64_t zone_count = state.array_size(open_zones);
		for (int64_t record_position = 0; record_position < zone_count; ++record_position) {
			for (const Value &zone_index : gd::items(state, state.at(open_zones, record_position))) {
				const int64_t tile = gd::to_int(state, zone_index);
				gd::packed_append(state, zone_tiles, tile);
				Value records;
				if (state.lookup(zone_records, int_value(tile), records)) {
					state.append(gd::as_array(records), int_value(record_position));
				} else {
					const ArrayRef made = state.new_array();
					state.append(made, int_value(record_position));
					state.set(zone_records, int_value(tile), array_value(made));
				}
			}
			gd::packed_append(state, zone_offsets, gd::packed_size(state, zone_tiles));
		}
		state.set(tables, str(key::open_zones), array_value(open_zones));
		state.set(tables, str(key::zone_offsets), ints_value(zone_offsets));
		state.set(tables, str(key::zone_tiles), ints_value(zone_tiles));
		state.set(tables, str(key::zone_records), dict_value(zone_records));
		state.erase(tables, str(key::resolved));
	}
	if (!gd::is_same(state, state.get(tables, str(key::resolved), Value()), dict_value(resolved))) {
		const int64_t neutral_count = state.array_size(neutrals);
		const PackedRef neutral_open = gd::new_bytes(state);
		gd::packed_resize(state, neutral_open, neutral_count);
		const DictRef guard_zones = state.new_dict();
		for (int64_t record_position = 0; record_position < neutral_count; ++record_position) {
			const DictRef record = gd::as_dict(state.at(neutrals, record_position));
			if (state.has(resolved, str(gd::stringify(state, gd::index(state, record, str(key::id)))))) {
				continue;
			}
			gd::packed_set(state, neutral_open, record_position, 1);
			const int64_t encounter_index = gd::to_int(state, gd::index(state, record, str(key::index)));
			state.set(guard_zones, int_value(encounter_index), state.at(open_zones, record_position));
		}
		state.set(tables, str(key::resolved), dict_value(resolved));
		state.set(tables, str(key::neutral_open), bytes_value(neutral_open));
		state.set(tables, str(key::guard_zones), dict_value(guard_zones));
	}
	return tables;
}

DictRef _search(State &state, DictRef session, DictRef context, DictRef entry, int64_t radius, bool past_own_heroes) {
	state.set(context, str(key::search_count), int_value(gd::add(gd::int_field(state, context, key::search_count, 0), 1)));
	const int64_t level = level_rules::level_of(state, dict_value(entry));
	const DictRef surface = _level_surface(state, session, context, level);
	const Vector2i size = to_vector2i(gd::index(state, context, str(key::map_size)));
	const int64_t width = size.x;
	const int64_t count = static_cast<int64_t>(size.x) * size.y;
	const DictRef static_stops = gd::as_dict(gd::index(state, surface, str(key::stops)));
	const Atom actor_id = ai::string_or_empty(state, entry, key::placement_id);
	const Atom controller = gd::stringify(state, gd::index(state, context, str(key::controller)));
	const DictRef own_doors = _own_town_doors(state, session, controller, level, size);
	const DictRef resolved = _resolved_lookup(state, session);
	const DictRef overworld = session_view::overworld(state, session);
	ArrayRef encounters = 0;
	const int64_t encounter_count = optional_array(state, overworld, key::encounters, encounters) ? state.array_size(encounters) : 0;
	Value found;
	const PackedRef water = state.lookup(surface, str(key::water), found) ? gd::as_bytes(found) : gd::new_bytes(state);
	const DictRef tables = _search_tables(state, surface, resolved);
	// Every army and hero where it stands now: tiles no one walks through, and
	// tiles that end a route. Route-ending refs by tile, for the armies and
	// heroes (the neutral armies' zones are in `tables`).
	const PackedRef unit_blocked = gd::new_ints(state);
	const PackedRef unit_stops = gd::new_ints(state);
	const DictRef dynamic_stops = state.new_dict();
	for (int64_t index = 0; index < encounter_count; ++index) {
		const Value other = state.at(encounters, index);
		if (!gd::is_dict(other)) {
			continue;
		}
		const Atom other_controller = player_identity_rules::raid_controller_id(state, other.ref);
		if (other_controller == key::empty || level_rules::level_of(state, other) != level) {
			continue;
		}
		const Atom other_id = ai::string_or_empty(state, other.ref, key::placement_id);
		if (other_id == actor_id || state.has(resolved, str(other_id))) {
			continue;
		}
		const int64_t tile_index = _tile_index_of(state, other.ref, size);
		if (tile_index < 0) {
			continue;
		}
		// Rival heroes can be attacked and this player's own heroes met; both
		// end a route, neither can be walked through.
		const bool meetable = other_controller == controller;
		if (meetable && is_ai_hero(state, other) && (past_own_heroes || state.has(own_doors, int_value(tile_index)))) {
			continue;
		}
		if (!is_ai_hero(state, other) || (!meetable && player_identity_rules::allied(state, dict_value(session), controller, other_controller))) {
			gd::packed_append(state, unit_blocked, tile_index);
		} else {
			gd::packed_append(state, unit_stops, tile_index);
			_add_stop_index(state, dynamic_stops, tile_index, stop_ref(state, kStopAiHero, index));
		}
	}
	ArrayRef heroes = 0;
	const int64_t hero_count = optional_array(state, overworld, key::player_heroes, heroes) ? state.array_size(heroes) : 0;
	const bool human_allied = player_identity_rules::allied(state, dict_value(session), controller, key::player);
	for (int64_t index = 0; index < hero_count; ++index) {
		const Value hero = state.at(heroes, index);
		Value position;
		if (!gd::is_dict(hero) || !state.lookup(hero.ref, str(key::position), position) || !gd::is_dict(position)) {
			continue;
		}
		if (gd::is_empty(state, position.ref) || level_rules::level_of(state, position) != level) {
			continue;
		}
		const int64_t hero_index = _tile_index_of(state, position.ref, size);
		if (hero_index < 0) {
			continue;
		}
		if (human_allied) {
			gd::packed_append(state, unit_blocked, hero_index);
		} else {
			gd::packed_append(state, unit_stops, hero_index);
			_add_stop_index(state, dynamic_stops, hero_index, stop_ref(state, kStopHero, index));
		}
	}
	// Heroes guard the tiles around them (OverworldRules.hero_guard_zone_tiles):
	// stepping next to a hostile hero means fighting it, so its zone ends a
	// route like a neutral army's and is never walked through.
	const ArrayRef guards = _hero_guards(state, session, context, level);
	const PackedRef hero_tiles = gd::new_ints(state);
	for (const Value &guard : gd::items(state, array_value(guards))) {
		gd::packed_append(state, hero_tiles, tile_index_value(state, ai::vmember(state, guard, key::tile), width));
	}
	const PackedRef guard_offsets = gd::new_ints(state);
	gd::packed_append(state, guard_offsets, 0);
	const PackedRef guard_tiles = gd::new_ints(state);
	const ArrayRef guard_refs = state.new_array();
	for (const Value &guard : gd::items(state, array_value(guards))) {
		if (!gd::to_bool(ai::vmember(state, guard, key::hostile))) {
			continue;
		}
		const int64_t kind = gd::stringify(state, ai::vmember(state, guard, key::ref_kind)) == key::hero ? kStopHero : kStopAiHero;
		const int64_t guard_index = gd::to_int(state, ai::vmember(state, guard, key::index));
		const DictRef ref = stop_ref(state, kind, guard_index);
		state.set(ref, str(key::zone), bool_value(true));
		state.append(guard_refs, dict_value(ref));
		const Vector2i guard_tile = to_vector2i(ai::vmember(state, guard, key::tile));
		for (const Value &tile : gd::items(state, array_value(_hero_zone_tiles(state, session, context, guard_tile, level)))) {
			gd::packed_append(state, guard_tiles, tile_index_value(state, tile, width));
		}
		gd::packed_append(state, guard_offsets, gd::packed_size(state, guard_tiles));
	}
	_sync_site_pass_memo(state);
	const ArrayRef resource_nodes = array_or_new(state, overworld, key::resource_nodes);
	const ArrayRef artifact_nodes = array_or_new(state, overworld, key::artifact_nodes);
	const DictRef site_allies = state.new_dict();
	const ArrayRef sites = array_or_new(state, surface, key::site_stops);
	// Per site: 0 not yet known this decision, 1 open, 2 closed.
	const PackedRef site_open = _decision_site_pass(state, context, level, sites);
	const bool shared = !gd::packed_is_empty(state, site_open);
	const bool has_water = gd::int_field(state, surface, key::water_count, 0) > 0;
	const PackedRef surface_blocked = gd::as_bytes(gd::index(state, surface, str(key::blocked)));
	const PackedRef surface_stops = gd::as_bytes(gd::index(state, surface, str(key::stop_mask)));
	const PackedRef sea = has_water ? gd::as_bytes(gd::index(state, surface, str(key::sea))) : gd::new_bytes(state);
	const PackedRef body_offsets = gd::as_ints(gd::index(state, tables, str(key::body_offsets)));
	const PackedRef body_tiles = gd::as_ints(gd::index(state, tables, str(key::body_tiles)));
	const PackedRef zone_offsets = gd::as_ints(gd::index(state, tables, str(key::zone_offsets)));
	const PackedRef zone_tiles = gd::as_ints(gd::index(state, tables, str(key::zone_tiles)));
	const PackedRef table_neutral_open = gd::as_bytes(gd::index(state, tables, str(key::neutral_open)));
	const PackedRef site_tiles = gd::as_ints(gd::index(state, tables, str(key::site_tiles)));
	const ArrayRef masks = search_masks(state, width, size.y, surface_blocked, surface_stops, water, sea, body_offsets, body_tiles, zone_offsets, zone_tiles, table_neutral_open,
			unit_blocked, unit_stops, hero_tiles, guard_offsets, guard_tiles, site_tiles, site_open);
	const PackedRef blocked = gd::as_bytes(state.at(masks, 0));
	const PackedRef stop_mask = gd::as_bytes(state.at(masks, 1));
	const PackedRef guard_mask = gd::as_bytes(state.at(masks, 2));
	const PackedRef hero_zone = gd::as_bytes(state.at(masks, 3));
	const PackedRef pass_mask = gd::as_bytes(state.at(masks, 4));
	const PackedRef zone_stops = gd::as_ints(state.at(masks, 6));
	const int64_t zone_stop_count = gd::packed_size(state, zone_stops);
	for (int64_t at = 0; at < zone_stop_count; at += 2) {
		const int64_t tile_index = gd::packed_int(state, zone_stops, at + 1);
		const DictRef ref = gd::as_dict(state.at(guard_refs, gd::packed_int(state, zone_stops, at)));
		_add_stop_index(state, dynamic_stops, tile_index, ref);
	}
	// The sites the decision has not checked yet: crossed where nothing more
	// waits there for the hero.
	const PackedRef pending_sites = gd::as_ints(state.at(masks, 7));
	const int64_t pending_count = gd::packed_size(state, pending_sites);
	for (int64_t at = 0; at < pending_count; ++at) {
		const int64_t site_position = gd::packed_int(state, pending_sites, at);
		const DictRef site = gd::as_dict(state.at(sites, site_position));
		bool open = true;
		for (const Value &ref : gd::items(state, gd::index(state, site, str(key::refs)))) {
			if (!_site_stop_passable(state, session, controller, gd::as_dict(ref), resource_nodes, artifact_nodes, site_allies)) {
				open = false;
				break;
			}
		}
		if (shared) {
			gd::packed_set(state, site_open, site_position, open ? 1 : 2);
		}
		if (open) {
			gd::packed_set(state, pass_mask, gd::to_int(state, gd::index(state, site, str(key::tile))), 1);
		}
	}
	const int64_t start_index = _tile_index_of(state, entry, size);
	if (start_index < 0) {
		const PackedRef dist = new_tile_ints(state, count);
		gd::packed_fill(state, dist, -1);
		const PackedRef parent = new_tile_ints(state, count);
		gd::packed_fill(state, parent, -1);
		const DictRef result = state.new_dict();
		state.set(result, str(key::dist), ints_value(dist));
		state.set(result, str(key::parent), ints_value(parent));
		state.set(result, str(key::stops), dict_value(state.new_dict()));
		state.set(result, str(key::size), Value::of_vector2i(size.x, size.y));
		state.set(result, str(key::start), int_value(-1));
		return result;
	}
	// Water, as for the human (WaterTravelRules). Phase per tile: 0 walking,
	// 1 sailing, 2 ashore again, plus kBoughtBoat when the route buys its boat.
	int64_t start_phase = 0;
	const PackedRef sea_open = gd::as_bytes(state.at(masks, 5));
	const PackedRef boat_tiles = gd::new_bytes(state);
	// [shipyard visit tile, dock] per shipyard whose boat the player can buy.
	const PackedRef docks = gd::new_ints(state);
	int64_t shore_cost = 0;
	int64_t dock_cost = 0;
	if (has_water) {
		gd::packed_resize(state, boat_tiles, count);
		for (const Value &boat : gd::items(state, array_value(water_travel_rules::boats(state, dict_value(session))))) {
			if (!gd::is_dict(boat) || gd::int_field(state, boat.ref, key::level, 0) != level) {
				continue;
			}
			const int64_t boat_index = _tile_index_of(state, boat.ref, size);
			if (boat_index < 0) {
				continue;
			}
			gd::packed_set(state, sea_open, boat_index, 0);
			if (ai::string_or_empty(state, boat.ref, key::hero_id) == key::empty) {
				gd::packed_set(state, boat_tiles, boat_index, 1);
			}
		}
		if (water_travel_rules::hero_boat_id(state, dict_value(entry)) != key::empty && gd::packed_int(state, water, start_index) != 0) {
			start_phase = 1;
		} else {
			Value shipyards;
			if (state.lookup(surface, str(key::shipyards), shipyards) && !ai::vempty(state, shipyards)) {
				Value cost;
				const DictRef boat_cost = state.lookup(surface, str(key::boat_cost), cost) ? gd::as_dict(cost) : state.new_dict();
				if (!gd::is_empty(state, _boat_market(state, session, context, boat_cost))) {
					if (!gd::is_dict(shipyards)) {
						throw state::ScriptError(std::string("Invalid call. Nonexistent function 'keys' in base '") + gd::type_name(shipyards) + "'.");
					}
					for (const Value &visit_index : gd::items(state, shipyards)) {
						const Value yard = ai::vindex(state, gd::index(state, surface, str(key::shipyards)), visit_index);
						const int64_t dock = gd::to_int(state, ai::vmember(state, yard, key::dock));
						if (gd::packed_int(state, sea_open, dock) != 0 && gd::packed_int(state, guard_mask, dock) == 0 && !state.has(dynamic_stops, int_value(dock))) {
							gd::packed_append(state, docks, gd::to_int(state, visit_index));
							gd::packed_append(state, docks, dock);
						}
					}
				}
			}
		}
		const int64_t movement_max = _movement_max(state, entry);
		const double share = ai::static_float(state, key::ai_hero_rules_script, key::SHORE_STEP_SHARE);
		shore_cost = compat::engine_max<int64_t>(1, compat::float_to_int(compat::godot_round(static_cast<double>(movement_max) * share)));
		dock_cost = gd::add(shore_cost, movement_max);
	}
	const bool native_corners = native_transit_rules::uses_native_adjacency(state, dict_value(session));
	bool has_portals = false;
	if (state.lookup(surface, str(key::portals), found)) {
		has_portals = !gd::is_empty(state, gd::as_dict(found));
	}
	const PackedRef seen_map = has_portals ? _explored(state, session, context, level) : gd::new_bytes(state);
	const PackedRef portal_list = gd::as_ints(gd::index(state, tables, str(key::portals)));
	const PackedRef walk_water = has_water ? water : gd::new_bytes(state);
	const ArrayRef walk = search_walk(state, width, size.y, start_index, start_phase, radius, native_corners, blocked, stop_mask, pass_mask, hero_zone,
			portal_list, seen_map, walk_water, sea_open, boat_tiles, docks, shore_cost, dock_cost);
	// Every route-ending tile reached, the hero's own included, with what ends
	// the route there: the level's objects, the neutral armies whose zone holds
	// it, then the armies and heroes.
	const DictRef reached_stops = state.new_dict();
	const ArrayRef neutrals = gd::as_array(gd::index(state, surface, str(key::neutrals)));
	const PackedRef neutral_open = gd::as_bytes(gd::index(state, tables, str(key::neutral_open)));
	const DictRef zone_records = gd::as_dict(gd::index(state, tables, str(key::zone_records)));
	const PackedRef reached = gd::as_ints(state.at(walk, 6));
	const int64_t reached_count = gd::packed_size(state, reached);
	for (int64_t at = 0; at < reached_count; ++at) {
		const Value tile_key = int_value(gd::packed_int(state, reached, at));
		// var refs: Array = [], made when something goes in.
		ArrayRef refs = 0;
		bool made = false;
		if (state.lookup(static_stops, tile_key, found)) {
			refs = state.new_array();
			made = true;
			ai::append_array(state, refs, gd::as_array(found));
		}
		if (gd::packed_int(state, guard_mask, tile_key.i) != 0) {
			for (const Value &record_position : gd::items(state, gd::index(state, zone_records, tile_key))) {
				if (gd::packed_int(state, neutral_open, gd::to_int(state, record_position)) != 0) {
					const Value ref = ai::vmember(state, ai::vindex(state, array_value(neutrals), record_position), key::ref);
					if (!made) {
						refs = state.new_array();
						made = true;
					}
					state.append(refs, ref);
				}
			}
		}
		if (state.lookup(dynamic_stops, tile_key, found)) {
			const ArrayRef dynamic_refs = gd::as_array(found);
			if (!made) {
				refs = state.new_array();
				made = true;
			}
			ai::append_array(state, refs, dynamic_refs);
		}
		if (made && state.array_size(refs) != 0) {
			state.set(reached_stops, tile_key, array_value(refs));
		}
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::dist), state.at(walk, 0));
	state.set(result, str(key::parent), state.at(walk, 1));
	state.set(result, str(key::stops), dict_value(reached_stops));
	state.set(result, str(key::size), Value::of_vector2i(size.x, size.y));
	state.set(result, str(key::start), int_value(start_index));
	state.set(result, str(key::order), state.at(walk, 2));
	state.set(result, str(key::order_count), state.at(walk, 3));
	state.set(result, str(key::capped), state.at(walk, 4));
	state.set(result, str(key::radius), int_value(radius));
	state.set(result, str(key::blocked), bytes_value(blocked));
	state.set(result, str(key::stop_mask), bytes_value(stop_mask));
	state.set(result, str(key::pass_mask), bytes_value(pass_mask));
	state.set(result, str(key::native_corners), bool_value(native_corners));
	state.set(result, str(key::guard_mask), bytes_value(guard_mask));
	state.set(result, str(key::guard_zones), gd::index(state, tables, str(key::guard_zones)));
	state.set(result, str(key::hero_zone), bytes_value(hero_zone));
	state.set(result, str(key::static_stops), dict_value(static_stops));
	state.set(result, str(key::phase), state.at(walk, 5));
	return result;
}

double _boat_price(State &state, DictRef session, DictRef context, DictRef search, int64_t tile_index) {
	Value found;
	PackedRef phase = 0;
	int64_t phase_size = 0;
	if (state.lookup(search, str(key::phase), found)) {
		phase = gd::as_bytes(found);
		phase_size = gd::packed_size(state, phase);
	}
	if (tile_index < 0 || tile_index >= phase_size || (gd::packed_int(state, phase, tile_index) & kBoughtBoat) == 0) {
		return 0.0;
	}
	const DictRef surface = _level_surface(state, session, context, 0);
	const Value payload = state.lookup(surface, str(key::boat_cost), found) ? found : dict_value(state.new_dict());
	return _payload_value(state, payload, state.new_dict());
}

int64_t _tile_index_of(State &state, DictRef point, Vector2i size) {
	const int64_t x = gd::int_field(state, point, key::x, -1);
	const int64_t y = gd::int_field(state, point, key::y, -1);
	if (x < 0 || y < 0 || x >= size.x || y >= size.y) {
		return -1;
	}
	return y * size.x + x;
}

PackedRef _step_offsets(State &state, int64_t width) {
	// NEIGHBOR_DX, NEIGHBOR_DY.
	static constexpr int64_t kDx[8] = {1, -1, 0, 0, 1, 1, -1, -1};
	static constexpr int64_t kDy[8] = {0, 0, 1, -1, 1, -1, 1, -1};
	const PackedRef offsets = gd::new_ints(state);
	for (int direction = 0; direction < 8; ++direction) {
		gd::packed_append(state, offsets, gd::add(gd::mul(kDy[direction], width), kDx[direction]));
	}
	return offsets;
}

void _add_stop_index(State &state, DictRef stops, int64_t tile_index, DictRef ref) {
	append_stop(state, stops, tile_index, ref);
}

ArrayRef _path_to(State &state, DictRef search, int64_t tile_index) {
	const Vector2i size = to_vector2i(gd::index(state, search, str(key::size)));
	const ArrayRef path = state.new_array();
	int64_t cursor = tile_index;
	const PackedRef parent = gd::as_ints(gd::index(state, search, str(key::parent)));
	// int(search.start), read once the loop first gets that far.
	bool start_read = false;
	int64_t start = 0;
	// path.push_front(...) for each step: kept in walk order, then added back to front.
	std::vector<Value> steps;
	while (cursor >= 0) {
		if (!start_read) {
			start = gd::to_int(state, gd::index(state, search, str(key::start)));
			start_read = true;
		}
		if (cursor == start) {
			break;
		}
		if (size.x == 0) {
			throw state::ScriptError("Division by zero error in operator '%'.");
		}
		steps.push_back(Value::of_vector2i(static_cast<int32_t>(compat::int_mod(cursor, size.x)), static_cast<int32_t>(compat::int_div(cursor, size.x))));
		cursor = gd::packed_int(state, parent, cursor);
	}
	for (size_t at = steps.size(); at > 0; --at) {
		state.append(path, steps[at - 1]);
	}
	return path;
}

} // namespace ai_hero_rules

} // namespace aurelion::rules::port
