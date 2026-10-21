// WaterTravelRules: the functions the AI targets reach (Phase 3), ported under
// their GDScript names.

#include "aurelion_rules/port/water_travel_rules_ai.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/content_service_ai.hpp"
#include "aurelion_rules/port/overworld_level_rules_ai.hpp"
#include "aurelion_rules/port/session_view.hpp"

namespace aurelion::rules::port {

namespace {

using gd::ArrayRef;
using gd::Atom;
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

} // namespace

namespace water_travel_rules {

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
