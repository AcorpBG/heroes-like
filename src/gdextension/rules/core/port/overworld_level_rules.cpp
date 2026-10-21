// Layer 2: the map level of a record, a session's levels and a town's entrance.

#include "aurelion_rules/port/overworld_level_rules.hpp"

#include "aurelion_rules/port/day_view.hpp"

#include <string>

namespace aurelion::rules::port::overworld_level_rules {

namespace {

using gd::ArrayRef;
using gd::Atom;
using gd::int_value;
using gd::str;
namespace key = state::key;

} // namespace

int64_t level_of(State &state, const Value &value) {
	if (gd::is_dict(value)) {
		// Hero.level is experience rank; its spatial level lives in position.
		const Value position_value = gd::field(state, value.ref, key::position);
		if (gd::is_dict(position_value)) {
			return level_of(state, position_value);
		}
		Value level;
		if (state.lookup(value.ref, str(key::level), level)) {
			return gd::to_int(state, level);
		}
		for (const Atom tile_key : {key::visit_tile, key::primary_tile}) {
			const Value tile = gd::field(state, value.ref, tile_key);
			if (gd::is_dict(tile) && state.lookup(tile.ref, str(key::level), level)) {
				return gd::to_int(state, level);
			}
		}
	}
	if (value.kind == state::Kind::Opaque) {
		// A Vector3i's z is its level; the State does not model Vector3i.
		throw state::ScriptError("OverworldLevelRules.level_of of an Object or a Vector3i is not ported");
	}
	return 0;
}

bool on_level(State &state, const Value &value, int64_t level) {
	return level_of(state, value) == level;
}

int64_t hero_level(State &state, DictRef session) {
	// level_of(session.overworld.get("hero_position", {})): {} is level 0.
	Value hero_position;
	if (!state.lookup(day_view::overworld(state, session), str(key::hero_position), hero_position)) {
		return 0;
	}
	return level_of(state, hero_position);
}

int64_t level_count(State &state, DictRef session) {
	// maxi(1, int(session.overworld.get("map_size", {}).get("level_count", 1))).
	Value map_size;
	if (!state.lookup(day_view::overworld(state, session), str(key::map_size), map_size)) {
		return 1;
	}
	if (!gd::is_dict(map_size)) {
		throw state::ScriptError(std::string("Invalid call. Nonexistent function 'get' with two arguments in base '") + gd::type_name(map_size) + "'.");
	}
	return compat::engine_max<int64_t>(1, gd::int_field(state, map_size.ref, key::level_count, 1));
}

int64_t query_level(State &state, DictRef session, int64_t requested) {
	return requested < 0 ? hero_level(state, session) : requested;
}

DictRef position(State &state, DictRef value) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::x), int_value(gd::int_field(state, value, key::x, 0)));
	state.set(result, str(key::y), int_value(gd::int_field(state, value, key::y, 0)));
	if (gd::int_field(state, value, key::level, 0) != 0) {
		state.set(result, str(key::level), int_value(gd::to_int(state, gd::index(state, value, str(key::level)))));
	}
	return result;
}

DictRef town_entrance(State &state, DictRef town) {
	const Value visit_tile = gd::field(state, town, key::visit_tile);
	DictRef tile = gd::is_dict(visit_tile) ? visit_tile.ref : state.new_dict();
	if (gd::is_empty(state, tile)) {
		// var visits: Array = town.get("package_visit_tiles", [])
		Value visits_value;
		const ArrayRef visits = state.lookup(town, str(key::package_visit_tiles), visits_value) ? gd::as_array(visits_value) : state.new_array();
		const Value first = state.array_size(visits) > 0 ? state.at(visits, 0) : Value();
		tile = gd::is_dict(first) ? first.ref : town;
	}
	const DictRef result = position(state, tile);
	if (!state.has(tile, str(key::level)) && level_of(state, gd::dict_value(town)) != 0) {
		state.set(result, str(key::level), int_value(level_of(state, gd::dict_value(town))));
	}
	return result;
}

} // namespace aurelion::rules::port::overworld_level_rules
