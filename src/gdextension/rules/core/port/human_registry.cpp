#include "aurelion_rules/port/registry.hpp"

#include "aurelion_rules/port/overworld_rules_human.hpp"

namespace aurelion::rules::port {

namespace {

using state::State;
using state::Value;
namespace overworld = overworld_rules;
namespace water = water_travel_rules;
using overworld::Vector2i;

// The parameters as GDScript's types left them. A session is its view, a
// Dictionary (DayEngine.gd), or Nil.
gd::DictRef D(const Value *args, int index) {
	return gd::as_dict(args[index]);
}
int64_t I(const Value *args, int index) {
	return args[index].i;
}
bool B(const Value *args, int index) {
	return gd::to_bool(args[index]);
}
Vector2i V(const Value *args, int index) {
	return {args[index].vx(), args[index].vy()};
}
bool nil(const Value *args, int index) {
	return args[index].kind == state::Kind::Nil;
}

// GDScript stops with a runtime error on a null session here; no screen passes one.
void no_null_session(const Value *args) {
	if (nil(args, 0)) {
		throw state::NotPorted("a null session");
	}
}

#define PORT(script, fn, arity, mutates, body) \
	{ #script "." #fn, arity, mutates, [](State &s, const Value *a) -> Value { (void)s; (void)a; body; } }

// The human seat's functions ported so far (Phase 7). The ones that write
// fill the caches in the session's metadata (the blocked-tile and spatial
// lookup indexes) and the scripts' static vars (terrain passability, the
// normalized read scope's cache, the pathing debug profile).
const Function kFunctions[] = {
	// 7.1, the routes.
	PORT(OverworldRules, tile_is_blocked, 4, true,
			no_null_session(a);
			return gd::bool_value(overworld::tile_is_blocked(s, D(a, 0), I(a, 1), I(a, 2), I(a, 3)))),
	PORT(OverworldRules, tile_has_route_interaction, 5, true,
			if (nil(a, 0)) return gd::bool_value(false);
			return gd::bool_value(overworld::tile_has_route_interaction(s, D(a, 0), I(a, 1), I(a, 2), I(a, 3), B(a, 4)))),
	PORT(OverworldRules, tile_is_actionable_route_destination, 4, true,
			if (nil(a, 0)) return gd::bool_value(false);
			return gd::bool_value(overworld::tile_is_actionable_route_destination(s, D(a, 0), I(a, 1), I(a, 2), I(a, 3)))),
	PORT(OverworldRules, hero_route_tile_blocked, 4, true,
			no_null_session(a);
			return gd::bool_value(overworld::hero_route_tile_blocked(s, D(a, 0), I(a, 1), I(a, 2), I(a, 3)))),
	PORT(OverworldRules, hero_route_destination, 4, true,
			no_null_session(a);
			return gd::bool_value(overworld::hero_route_destination(s, D(a, 0), I(a, 1), I(a, 2), I(a, 3)))),
	// The route search, one call per route the screens show.
	PORT(OverworldRules, hero_route_path, 5, true,
			if (nil(a, 0)) return gd::array_value(s.new_array());
			return gd::array_value(overworld::hero_route_path(s, D(a, 0), V(a, 1), V(a, 2), I(a, 3), B(a, 4)))),
	PORT(OverworldRules, hero_route_path_lengths, 3, true,
			if (nil(a, 0)) return gd::dict_value(s.new_dict());
			return gd::dict_value(overworld::hero_route_path_lengths(s, D(a, 0), V(a, 1), a[2]))),
	PORT(OverworldRules, resource_node_interaction_at_tile, 4, true,
			if (nil(a, 0)) return gd::dict_value(s.new_dict());
			return gd::dict_value(overworld::resource_node_interaction_at_tile(s, D(a, 0), I(a, 1), I(a, 2), I(a, 3)))),
	PORT(OverworldRules, tile_step_cuts_blocked_corner, 4, true,
			no_null_session(a);
			return gd::bool_value(overworld::tile_step_cuts_blocked_corner(s, D(a, 0), V(a, 1), V(a, 2), I(a, 3)))),
	PORT(OverworldRules, active_linked_transit_edges, 2, true,
			if (nil(a, 0)) return gd::array_value(s.new_array());
			return gd::array_value(overworld::active_linked_transit_edges(s, D(a, 0), I(a, 1)))),
	PORT(OverworldRules, linked_transit_neighbors_from_edges, 2, false,
			return gd::array_value(overworld::linked_transit_neighbors_from_edges(s, a[0], V(a, 1)))),
	PORT(OverworldRules, active_linked_transit_signature, 1, true,
			if (nil(a, 0)) return s.string("linked_transit:");
			return gd::str(overworld::active_linked_transit_signature(s, D(a, 0)))),
	PORT(OverworldRules, route_movement_preview, 3, false,
			return gd::dict_value(overworld::route_movement_preview(s, a[0], a[1], I(a, 2)))),
	PORT(OverworldRules, guard_engagement_encounter_at_tile, 4, true,
			no_null_session(a);
			return gd::dict_value(overworld::guard_engagement_encounter_at_tile(s, D(a, 0), I(a, 1), I(a, 2), I(a, 3)))),
	PORT(OverworldRules, guard_engagement_approach_route, 2, true,
			if (nil(a, 0)) return gd::array_value(s.new_array());
			return gd::array_value(overworld::guard_engagement_approach_route(s, D(a, 0), D(a, 1)))),
	PORT(OverworldRules, blocking_object_feedback_surface_at_tile, 3, false,
			if (nil(a, 0)) return gd::dict_value(s.new_dict());
			return gd::dict_value(overworld::blocking_object_feedback_surface_at_tile(s, D(a, 0), I(a, 1), I(a, 2)))),
	PORT(WaterTravelRules, is_sailing, 1, false,
			return gd::bool_value(water::is_sailing(s, a[0]))),
};

#undef PORT

} // namespace

// The human seat's table, listed in registry_tables.cpp. A path its port
// leaves out is a native failure: there is no GDScript to fall back to after
// the slice merges (owner decision D-d).
Table human_table() {
	return {"HEROES_NATIVE_HUMAN_LOG", kFunctions, sizeof(kFunctions) / sizeof(kFunctions[0])};
}

} // namespace aurelion::rules::port
