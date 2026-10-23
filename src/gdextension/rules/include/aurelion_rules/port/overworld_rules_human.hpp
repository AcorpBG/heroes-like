#pragma once

// scripts/core/OverworldRules.gd: the functions the human seat's screens call
// (docs/native-rules-engine-transition.md, Phase 7), ported function by function
// under the GDScript names. A session is its view (session_view.hpp).

#include "aurelion_rules/port/gd.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"
#include "aurelion_rules/port/overworld_rules_ai.hpp"
#include "aurelion_rules/port/overworld_rules_turn.hpp"

#include <cstdint>

namespace aurelion::rules::port::overworld_rules {

// 7.1, the routes (overworld_rules_routes.cpp).
bool tile_is_blocked(State &state, DictRef session, int64_t x, int64_t y, int64_t level = -1);
bool tile_has_route_interaction(State &state, DictRef session, int64_t x, int64_t y, int64_t level = -1, bool exact_target_only = false);
bool tile_is_actionable_route_destination(State &state, DictRef session, int64_t x, int64_t y, int64_t level = -1);
bool hero_route_tile_blocked(State &state, DictRef session, int64_t x, int64_t y, int64_t level = -1);
bool hero_route_destination(State &state, DictRef session, int64_t x, int64_t y, int64_t level = -1);
ArrayRef hero_route_path(State &state, DictRef session, Vector2i start, Vector2i goal, int64_t level = -1, bool plain = false);
DictRef hero_route_path_lengths(State &state, DictRef session, Vector2i start, const Value &goals);
DictRef resource_node_interaction_at_tile(State &state, DictRef session, int64_t x, int64_t y, int64_t level = -1);
bool tile_step_cuts_blocked_corner(State &state, DictRef session, Vector2i from_tile, Vector2i to_tile, int64_t level = -1);
ArrayRef active_linked_transit_edges(State &state, DictRef session, int64_t level = -1);
ArrayRef linked_transit_neighbors_from_edges(State &state, const Value &edges, Vector2i tile);
Atom active_linked_transit_signature(State &state, DictRef session);
// session: a view, or Nil.
DictRef route_movement_preview(State &state, const Value &session, const Value &route_tiles, int64_t movement_budget = -1);
DictRef guard_engagement_encounter_at_tile(State &state, DictRef session, int64_t x, int64_t y, int64_t level = -1);
ArrayRef guard_engagement_approach_route(State &state, DictRef session, DictRef encounter);
DictRef blocking_object_feedback_surface_at_tile(State &state, DictRef session, int64_t x, int64_t y);
Tiles _normalize_route_tiles(State &state, const Value &route_tiles);
Vector2i _route_tile_from_variant(State &state, const Value &value);
DictRef _route_tile_payload(State &state, Vector2i tile);
ArrayRef _route_tile_payloads(State &state, const Tiles &tiles);
DictRef _tile_payload(State &state, Vector2i tile);
bool _position_matches(State &state, DictRef entry, Vector2i pos);
// Array[String]: each item as text, stripped, without empty ones or repeats.
ArrayRef _string_array(State &state, const Value &value);

} // namespace aurelion::rules::port::overworld_rules

namespace aurelion::rules::port::water_travel_rules {

// session: a view, or Nil.
bool is_sailing(state::State &state, const state::Value &session);

} // namespace aurelion::rules::port::water_travel_rules
