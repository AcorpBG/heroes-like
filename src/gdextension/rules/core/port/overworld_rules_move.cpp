// OverworldRules for the human seat's move (Phase 7, slice 7.2): the step and
// the route, native transit, levels, the arrival on water, the hero's position
// and its fog, and the rules profile. NativeTransitRules.network_colour and
// OverworldLevelRules.moved_position are here too.

#include "aurelion_rules/port/overworld_rules_move.hpp"

#include "aurelion_rules/compat/godot_math.hpp"
#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/battle_payload.hpp"
#include "aurelion_rules/port/hero_command_rules.hpp"
#include "aurelion_rules/port/hero_command_rules_ai.hpp"
#include "aurelion_rules/port/hero_commit.hpp"
#include "aurelion_rules/port/native_transit_rules.hpp"
#include "aurelion_rules/port/native_transit_rules_ai.hpp"
#include "aurelion_rules/port/overworld_level_rules.hpp"
#include "aurelion_rules/port/overworld_rules_turn.hpp"
#include "aurelion_rules/port/session_view.hpp"
#include "aurelion_rules/port/water_travel_rules_ai.hpp"
#include "aurelion_rules/port/water_travel_rules_turn.hpp"

#include <string>

namespace aurelion::rules::port {

namespace {

using gd::array_value;
using gd::ArrayRef;
using gd::Atom;
using gd::bool_value;
using gd::dict_value;
using gd::DictRef;
using gd::int_value;
using gd::str;
using overworld_rules::Tiles;
using overworld_rules::Vector2i;
using state::ContentTable;
using state::Kind;
using state::State;
using state::Value;
namespace key = state::key;
namespace level_rules = overworld_level_rules;
namespace transit = native_transit_rules;
namespace water = water_travel_rules;

constexpr Atom kScript = key::overworld_rules_script;

Value tile_value(Vector2i tile) {
	return Value::of_vector2i(tile.x, tile.y);
}

// var x: Vector2i = value (or a Vector2i parameter): a Vector2i, or a ScriptError.
Vector2i as_vector2i(const Value &value) {
	if (!gd::is_vector2i(value)) {
		throw state::ScriptError(std::string("Trying to assign value of type '") + gd::type_name(value) + "' to a variable of type 'Vector2i'.");
	}
	return {value.vx(), value.vy()};
}

// d.get(field, {}) / d.get(field, []) passed on or stored: the value, or a new container.
Value field_or_new_dict(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return dict_value(state.new_dict());
}

Value field_or_new_array(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return array_value(state.new_array());
}

// d.get(field, {}) if d.get(field, {}) is Dictionary else {}.
DictRef sub_dict(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found) && gd::is_dict(found)) {
		return found.ref;
	}
	return state.new_dict();
}

// {"ok": false, "message": message}.
DictRef failure(State &state, Atom message) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(false));
	state.set(result, str(key::message), str(message));
	return result;
}

// {"ok": false, "message": message, "route_steps": []}.
DictRef route_failure(State &state, Atom message) {
	const DictRef result = failure(state, message);
	state.set(result, str(key::route_steps), array_value(state.new_array()));
	return result;
}

// The same, with "route_validation_mode": "cached_prevalidated".
DictRef cached_route_failure(State &state, Atom message) {
	const DictRef result = route_failure(state, message);
	state.set(result, str(key::route_validation_mode), str(key::cached_prevalidated));
	return result;
}

// {"ok": true, "message": "", "route": ""}.
DictRef open_interaction(State &state) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(true));
	state.set(result, str(key::message), str(key::empty));
	state.set(result, str(key::route), str(key::empty));
	return result;
}

// The route as GDScript's Array of Vector2i.
ArrayRef tiles_array(State &state, const Tiles &tiles) {
	const ArrayRef path = state.new_array();
	for (const Vector2i tile : tiles) {
		state.append(path, tile_value(tile));
	}
	return path;
}

// path.slice(1, end) of a route whose end is in range.
Tiles route_steps(const Tiles &tiles, int64_t end) {
	return Tiles(tiles.begin() + 1, tiles.begin() + end);
}

// " ".join(messages) of an Array of Strings.
Atom join_messages(State &state, ArrayRef messages) {
	std::string joined;
	bool first = true;
	for (const Value &message : gd::items(state, array_value(messages))) {
		if (!first) {
			joined += " ";
		}
		first = false;
		joined += gd::text(state, message);
	}
	return state.intern(joined);
}

// "Moved to %d,%d." and, short of the destination, "Route pauses with %d step%s remaining."
ArrayRef move_messages(State &state, Vector2i final_tile, ArrayRef water_messages, bool reached_destination, int64_t remaining) {
	const ArrayRef messages = state.new_array();
	state.append(messages, str(gd::format(state, key::moved_to_d_d, {int_value(final_tile.x), int_value(final_tile.y)})));
	ai::append_array(state, messages, water_messages);
	if (!reached_destination) {
		state.append(messages, str(gd::format(state, key::route_pauses_with_d_step_s, {int_value(remaining), str(remaining == 1 ? key::empty : key::s)})));
	}
	return messages;
}

// The "move" recap's context.
DictRef move_recap_context(State &state, Vector2i pos, Vector2i final_tile, Atom route, DictRef target_context, const Tiles &steps, Vector2i destination_tile, bool reached_destination) {
	const DictRef context = state.new_dict();
	state.set(context, str(key::from_x), int_value(pos.x));
	state.set(context, str(key::from_y), int_value(pos.y));
	state.set(context, str(key::to_x), int_value(final_tile.x));
	state.set(context, str(key::to_y), int_value(final_tile.y));
	state.set(context, str(key::route), str(route));
	state.set(context, str(key::target_context), dict_value(target_context));
	state.set(context, str(key::route_steps), array_value(overworld_rules::_route_tile_payloads(state, steps)));
	state.set(context, str(key::planned_destination), dict_value(overworld_rules::_route_tile_payload(state, destination_tile)));
	state.set(context, str(key::reached_destination), bool_value(reached_destination));
	return context;
}

// int(movement.get("current", 0)) of the untyped movement value.
int64_t movement_current(State &state, const Value &movement) {
	return gd::to_int(state, ai::vget(state, movement, key::current, int_value(0)));
}

// movement_left if movement_budget < 0 else mini(movement_left, max(0, movement_budget)).
int64_t effective_budget_of(int64_t movement_left, int64_t movement_budget) {
	return movement_budget < 0 ? movement_left : compat::engine_min<int64_t>(movement_left, compat::engine_max<int64_t>(0, movement_budget));
}

// movement["current"] = value on the untyped movement value.
void set_movement_current(State &state, const Value &movement, int64_t value) {
	state.set(gd::as_dict(movement), str(key::current), int_value(value));
}

} // namespace

namespace overworld_rules {

void _rules_profile_begin(State &state) {
	const DictRef debug_profile = ai::static_dict(state, kScript, key::_pathing_debug_profile);
	const bool active = gd::to_bool(state.get(debug_profile, str(key::capture_enabled), bool_value(false)));
	gd::set_static_var(state, kScript, key::_movement_rules_profile_active, bool_value(active));
	if (!active) {
		gd::set_static_var(state, kScript, key::_movement_rules_profile, dict_value(state.new_dict()));
		return;
	}
	const DictRef profile = state.new_dict();
	for (const Atom section : {key::sub_buckets_ms, key::rule_counts, key::descriptor, key::scenario_eval, key::post_action_recap, key::fog, key::blocked_index, key::interactable}) {
		state.set(profile, str(section), dict_value(state.new_dict()));
	}
	gd::set_static_var(state, kScript, key::_movement_rules_profile, dict_value(profile));
}

DictRef _rules_profile_finish(State &state) {
	// The profile is the Dictionary _rules_profile_begin made earlier in the same
	// native call (execute_prevalidated_route runs both): a native copy.
	const DictRef profile = ai::static_bool(state, kScript, key::_movement_rules_profile_active)
			? gd::deep_duplicate_dict(state, ai::static_dict(state, kScript, key::_movement_rules_profile))
			: state.new_dict();
	gd::set_static_var(state, kScript, key::_movement_rules_profile_active, bool_value(false));
	gd::set_static_var(state, kScript, key::_movement_rules_profile, dict_value(state.new_dict()));
	return profile;
}

void _rules_profile_count(State &state, Atom name, int64_t amount) {
	if (!ai::static_bool(state, kScript, key::_movement_rules_profile_active) || name == key::empty) {
		return;
	}
	const DictRef profile = ai::static_dict(state, kScript, key::_movement_rules_profile);
	const DictRef counts = gd::as_dict(field_or_new_dict(state, profile, key::rule_counts));
	state.set(counts, str(name), int_value(gd::add(gd::to_int(state, state.get(counts, str(name), int_value(0))), amount)));
	state.set(profile, str(key::rule_counts), dict_value(counts));
}

void normalize_overworld_state_for_runtime(State &state, DictRef session) {
	// session == null: the registry answers it; a view is never null.
	if (ai::static_int(state, kScript, key::_normalized_read_scope_depth) > 0
			&& gd::stringify(state, gd::index(state, session, str(key::session_id))) == gd::to_string(gd::static_var(state, kScript, key::_normalized_read_scope_session_id))) {
		return;
	}
	const Atom session_id = gd::stringify(state, gd::index(state, session, str(key::session_id)));
	const DictRef signatures = ai::static_dict(state, kScript, key::_runtime_normalized_signatures);
	const Atom stored = gd::stringify(state, state.get(signatures, str(session_id), str(key::empty)));
	if (stored == _runtime_normalization_signature(state, session)) {
		return;
	}
	normalize_overworld_state(state, session);
}

void _store_level_fog(State &state, DictRef session, DictRef payload, int64_t level) {
	const DictRef overworld = session_view::overworld(state, session);
	if (level_rules::level_count(state, session) == 1) {
		state.set(overworld, str(key::fog), dict_value(payload));
		return;
	}
	level = level_rules::query_level(state, session, level);
	// var levels: Dictionary = session.overworld.get(FOG_KEY, {}).get("levels", {})
	const Value fog = field_or_new_dict(state, overworld, key::fog);
	const DictRef levels = gd::as_dict(ai::vget(state, fog, key::levels, dict_value(state.new_dict())));
	state.set(levels, str(gd::stringify(state, int_value(level))), dict_value(payload));
	// var active: Dictionary = levels.get(str(hero_level(session)), {}).duplicate(false)
	const Value active_source = field_or_new_dict(state, levels, gd::stringify(state, int_value(hero_level(state, session))));
	const DictRef active = gd::as_dict(gd::duplicate_value(state, active_source, false));
	state.set(active, str(key::levels), dict_value(levels));
	state.set(active, str(key::active_level), int_value(hero_level(state, session)));
	state.set(overworld, str(key::fog), dict_value(active));
}

DictRef try_move(State &state, DictRef session, int64_t dx, int64_t dy) {
	normalize_overworld_state_for_runtime(state, session);

	// var movement = session.overworld.get("movement", {}): read only here.
	Value movement;
	const int64_t movement_left = state.lookup(session_view::overworld(state, session), str(key::movement), movement) ? movement_current(state, movement) : 0;
	if (movement_left <= 0) {
		return failure(state, key::no_movement_left_today);
	}

	const Vector2i pos = hero_position(state, session);
	const Vector2i map_size = derive_map_size(state, session);
	// clamp(pos.x + dx, 0, max(map_size.x - 1, 0)) of ints.
	const int64_t nx = compat::engine_clamp<int64_t>(gd::add(pos.x, dx), 0, compat::engine_max<int64_t>(static_cast<int64_t>(map_size.x) - 1, 0));
	const int64_t ny = compat::engine_clamp<int64_t>(gd::add(pos.y, dy), 0, compat::engine_max<int64_t>(static_cast<int64_t>(map_size.y) - 1, 0));
	if (nx == pos.x && ny == pos.y) {
		return failure(state, key::the_map_edge_blocks_further_travel);
	}
	const ArrayRef route = state.new_array();
	state.append(route, tile_value(pos));
	state.append(route, tile_value(Vector2i::of(nx, ny)));
	return try_move_along_route(state, session, array_value(route), movement_left, true);
}

DictRef travel_native_passage(State &state, DictRef session, DictRef node, int64_t movement_cost) {
	movement_cost = compat::engine_clamp<int64_t>(movement_cost, 0, 1);
	const DictRef overworld = session_view::overworld(state, session);
	const Atom actor_id = ai::string_or_empty(state, overworld, key::active_hero_id);
	const Value actor_position = transit::point(state, gd::field(state, overworld, key::hero_position));
	DictRef check = native_passage_travel_check(state, session, node, actor_position, actor_id);
	if (gd::bool_field(state, check, key::native_transit_random_exit, false)) {
		check = native_random_exit_check(state, session, node, actor_position, actor_id);
	}
	if (!gd::bool_field(state, check, key::ok, false)) {
		if (movement_cost == 0 && gd::equal(state, actor_position, transit::point(state, gd::field(state, transit::link_of(state, node), key::entry)))) {
			// An arrival-only/stranded endpoint or a temporarily occupied exit
			// does not undo a legal, already-paid walk to this entrance.
			const ArrayRef nodes = ai::typed_array(field_or_new_array(state, session_view::overworld(state, session), key::resource_nodes), "OverworldRules.travel_native_passage");
			const Atom contract_error = transit::contract_error(state, node, transit::nodes_by_id(state, nodes));
			if (contract_error == key::empty && gd::bool_field(state, _native_passage_endpoint_safety(state, session, node, actor_id), key::ok, false)) {
				const Atom error = gd::stringify(state, state.get(check, str(key::error), str(key::empty)));
				if (error == key::empty || error == key::native_passage_has_no_exit) {
					state.set(check, str(key::ok), bool_value(true));
					state.set(check, str(key::native_transit_unavailable), bool_value(true));
				}
			}
		}
		return check;
	}
	// Arrival has already spent the approach step. A deliberate return from the
	// entrance spends one step.
	const DictRef movement = gd::as_dict(field_or_new_dict(state, session_view::overworld(state, session), key::movement));
	if (gd::int_field(state, movement, key::current, 0) < movement_cost) {
		return failure(state, key::no_movement_left_to_use_the);
	}
	// var destination: Vector3i = check.exit
	const Value destination = gd::index(state, check, str(key::exit));
	if (!gd::is_vector3i(destination)) {
		throw state::ScriptError(std::string("Trying to assign value of type '") + gd::type_name(destination) + "' to a variable of type 'Vector3i'.");
	}
	const DictRef defender = _engaging_encounter_at_tile(state, session, Vector2i::of(destination.vx(), destination.vy()), destination.vz());
	DictRef arrival_battle = state.new_dict();
	if (!gd::is_empty(state, defender)) {
		// Prepare before charging or moving; an invalid encounter cannot strand
		// the hero beyond the passage.
		arrival_battle = battle_rules::create_battle_payload(state, dict_value(session), defender);
		if (gd::is_empty(state, arrival_battle)) {
			return failure(state, key::the_passage_is_defended_but_battle);
		}
	}
	state.set(movement, str(key::current), int_value(gd::sub(gd::int_field(state, movement, key::current, 0), movement_cost)));
	state.set(session_view::overworld(state, session), str(key::movement), dict_value(movement));
	note_native_trip(state, session, actor_id);
	_set_active_hero_position(state, session, Vector2i::of(destination.vx(), destination.vy()), destination.vz());
	state.set(session_view::overworld(state, session), str(key::view_level), int_value(destination.vz()));
	clear_active_town_visit(state, session);
	hero_command_rules::commit_active_hero(state, session);
	_reveal_current_fog_sources(state, session);
	_mark_runtime_normalized(state, session);
	if (!gd::is_empty(state, arrival_battle)) {
		// Battle aftermath restores this commander snapshot; position and move
		// budget reflect the committed arrival.
		const DictRef commander = gd::as_dict(gd::index(state, arrival_battle, str(key::player_commander_state)));
		state.set(commander, str(key::position), gd::duplicate_value(state, gd::index(state, session_view::overworld(state, session), str(key::hero_position)), true));
		state.set(commander, str(key::movement), gd::duplicate_value(state, gd::index(state, session_view::overworld(state, session), str(key::movement)), true));
		state.set(session, str(key::battle), dict_value(arrival_battle));
		const DictRef result = state.new_dict();
		state.set(result, str(key::ok), bool_value(true));
		state.set(result, str(key::message), str(describe_encounter_battle_cue(state, session, defender)));
		state.set(result, str(key::route), str(key::battle));
		state.set(result, str(key::native_transit), gd::duplicate_value(state, gd::index(state, check, str(key::link)), true));
		state.set(result, str(key::movement_cost), int_value(movement_cost));
		return result;
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(true));
	state.set(result, str(key::message), str(_native_travel_message(state, node, destination)));
	state.set(result, str(key::native_transit), gd::duplicate_value(state, gd::index(state, check, str(key::link)), true));
	state.set(result, str(key::movement_cost), int_value(movement_cost));
	return result;
}

Atom native_portal_display_name(State &state, DictRef node) {
	const DictRef site = gd::content_row(state, ContentTable::ResourceSite, ai::string_or_empty(state, node, key::site_id));
	const Atom colour = gd::stringify(state, state.get(transit::network_colour(state, node), str(key::name), str(key::empty)));
	const Atom name = gd::stringify(state, state.get(site, str(key::name), str(key::portal)));
	return gd::format(state, key::s_s, {str(colour), str(name)});
}

Atom _native_travel_message(State &state, DictRef node, const Value &destination) {
	if (transit::portal_kind(state, node) == key::empty) {
		return gd::format(state, key::travelled_through_the_passage_to_s, {str(destination.vz() > 0 ? key::the_underground : key::the_surface), int_value(destination.vx()), int_value(destination.vy())});
	}
	return gd::format(state, key::travelled_through_the_s_and_came, {str(native_portal_display_name(state, node)), int_value(destination.vx()), int_value(destination.vy())});
}

DictRef active_linked_transit_step(State &state, DictRef session, Vector2i from_tile, Vector2i to_tile) {
	for (const Value &edge_value : gd::items(state, array_value(active_linked_transit_edges(state, session, -1)))) {
		if (!gd::is_dict(edge_value)) {
			continue;
		}
		const DictRef edge = edge_value.ref;
		const Vector2i edge_from = as_vector2i(state.get(edge, str(key::from_tile), Value::of_vector2i(-1, -1)));
		const Vector2i edge_to = as_vector2i(state.get(edge, str(key::to_tile), Value::of_vector2i(-1, -1)));
		if ((from_tile == edge_from && to_tile == edge_to) || (gd::bool_field(state, edge, key::two_way, false) && from_tile == edge_to && to_tile == edge_from)) {
			return gd::deep_duplicate_dict(state, edge);
		}
	}
	return state.new_dict();
}

DictRef try_move_along_route(State &state, DictRef session, const Value &route_tiles, int64_t movement_budget, bool resolve_destination_interaction) {
	normalize_overworld_state_for_runtime(state, session);
	const Tiles tiles = _normalize_route_tiles(state, route_tiles);
	const int64_t path_size = static_cast<int64_t>(tiles.size());
	if (path_size <= 1) {
		return route_failure(state, key::no_route_selected);
	}
	const ArrayRef path = tiles_array(state, tiles);
	// Walking away from a claimed site leaves its waiting troops behind.
	state.erase(session_view::overworld(state, session), str(key::pending_site_recruits));
	const Vector2i pos = hero_position(state, session);
	if (!(tiles[0] == pos)) {
		return route_failure(state, key::the_selected_route_no_longer_starts);
	}
	// A portal can arrive under both an occupying army and a site's guard.
	// Discover the remaining encounter instead of replaying the portal itself.
	if (!gd::is_empty(state, get_active_encounter(state, session))) {
		const DictRef origin_site = _find_context_resource_node(state, session);
		if (transit::is_native(state, gd::as_dict(field_or_new_dict(state, origin_site, key::node)))) {
			return _resolve_post_move_interaction(state, session);
		}
	}

	const Vector2i map_size = derive_map_size(state, session);
	for (int64_t index = 1; index < path_size; ++index) {
		const Vector2i tile = tiles[static_cast<size_t>(index)];
		if (tile.x < 0 || tile.y < 0 || tile.x >= map_size.x || tile.y >= map_size.y) {
			return route_failure(state, key::the_map_edge_blocks_that_route);
		}
		const Vector2i previous = tiles[static_cast<size_t>(index - 1)];
		const bool adjacent_step = compat::engine_max<int64_t>(compat::absi(static_cast<int64_t>(tile.x) - previous.x), compat::absi(static_cast<int64_t>(tile.y) - previous.y)) == 1;
		const DictRef linked_transit_step = !adjacent_step ? active_linked_transit_step(state, session, previous, tile) : state.new_dict();
		if (!adjacent_step && gd::is_empty(state, linked_transit_step)) {
			return route_failure(state, key::the_selected_route_is_not_contiguous);
		}
		if (adjacent_step && tile_step_cuts_blocked_corner(state, session, previous, tile, -1)) {
			return route_failure(state, key::the_terrain_blocks_that_route);
		}
		if (adjacent_step && _tile_blocks_route_step(state, session, tile, index == path_size - 1)) {
			return route_failure(state, key::the_terrain_blocks_that_route);
		}
		if (adjacent_step && index < path_size - 1 && tile_has_route_interaction(state, session, tile.x, tile.y, -1, false)) {
			return route_failure(state, key::an_interaction_blocks_that_route);
		}
	}

	const Value movement = field_or_new_dict(state, session_view::overworld(state, session), key::movement);
	const int64_t movement_left = movement_current(state, movement);
	const int64_t effective_budget = effective_budget_of(movement_left, movement_budget);
	if (effective_budget <= 0) {
		return route_failure(state, key::no_movement_left_today);
	}
	const DictRef preview = route_movement_preview(state, dict_value(session), array_value(path), effective_budget);
	const int64_t reachable_steps = gd::int_field(state, preview, key::reachable_steps, 0);
	if (reachable_steps <= 0) {
		return route_failure(state, key::no_movement_left_today);
	}

	const Vector2i final_tile = as_vector2i(state.at(path, reachable_steps));
	const Vector2i destination_tile = as_vector2i(state.at(path, path_size - 1));
	_set_active_hero_position(state, session, final_tile, -1);
	set_movement_current(state, movement, compat::engine_max<int64_t>(0, movement_left - reachable_steps));
	state.set(session_view::overworld(state, session), str(key::movement), movement);
	hero_command_rules::commit_active_hero(state, session);
	const ArrayRef water_messages = _apply_water_route_arrival(state, session, path, reachable_steps);
	_reveal_route_fog(state, session, gd::slice(state, path, 1, reachable_steps + 1));
	_mark_runtime_normalized(state, session);

	const bool reached_destination = final_tile == destination_tile;
	const ArrayRef messages = move_messages(state, final_tile, water_messages, reached_destination, path_size - 1 - reachable_steps);
	const DictRef target_context = _post_action_tile_context(state, session, final_tile);
	DictRef interaction_result = open_interaction(state);
	if (reached_destination && resolve_destination_interaction) {
		interaction_result = _resolve_post_move_interaction(state, session);
		const Atom interaction_message = gd::stringify(state, state.get(interaction_result, str(key::message), str(key::empty)));
		if (interaction_message != key::empty) {
			state.append(messages, str(interaction_message));
		}
	}
	DictRef result = _finalize_action_result(state, session, gd::to_bool(state.get(interaction_result, str(key::ok), bool_value(true))), join_messages(state, messages), false, true, state.new_dict());
	const Atom route = gd::stringify(state, state.get(interaction_result, str(key::route), str(key::empty)));
	if (route != key::empty) {
		state.set(result, str(key::route), str(route));
	}
	if (state.has(interaction_result, str(key::reward_choice))) {
		state.set(result, str(key::reward_choice), gd::duplicate_value(state, gd::index(state, interaction_result, str(key::reward_choice)), true));
	}
	if (state.has(interaction_result, str(key::native_transit))) {
		state.set(result, str(key::native_transit), gd::duplicate_value(state, gd::index(state, interaction_result, str(key::native_transit)), true));
	}
	state.set(result, str(key::route_steps), array_value(_route_tile_payloads(state, route_steps(tiles, reachable_steps + 1))));
	const DictRef route_execution = gd::deep_duplicate_dict(state, preview);
	state.set(route_execution, str(key::reached_destination), bool_value(reached_destination));
	state.set(route_execution, str(key::route_validation_mode), str(key::full_revalidation));
	state.set(result, str(key::route_execution), dict_value(route_execution));
	state.set(result, str(key::route_validation_mode), str(key::full_revalidation));
	result = _attach_post_action_recap(state, result, session, key::move_,
			move_recap_context(state, pos, final_tile, route, target_context, route_steps(tiles, reachable_steps + 1), destination_tile, reached_destination));
	return result;
}

ArrayRef _apply_water_route_arrival(State &state, DictRef session, ArrayRef path, int64_t reachable_steps) {
	if (reachable_steps <= 0 || reachable_steps >= state.array_size(path)) {
		return state.new_array();
	}
	const int64_t level = hero_level(state, session);
	const Vector2i final_tile = as_vector2i(state.at(path, reachable_steps));
	const DictRef overworld = session_view::overworld(state, session);
	// String(session.overworld.get("hero", {}).get("name", "The hero"))
	Value hero;
	const Atom hero_name = state.lookup(overworld, str(key::hero), hero)
			? gd::stringify(state, ai::vget(state, hero, key::name, str(key::the_hero_text)))
			: key::the_hero_text;
	const ArrayRef messages = state.new_array();
	if (water::is_sailing(state, dict_value(session))) {
		if (water::is_water(state, dict_value(session), final_tile.x, final_tile.y, level)) {
			water::follow_active_hero(state, dict_value(session), final_tile, level);
			return state.new_array();
		}
		water::disembark(state, dict_value(session), as_vector2i(state.at(path, reachable_steps - 1)), level);
		state.append(messages, str(gd::format(state, key::s_goes_ashore_the_boat_stays, {str(hero_name)})));
	} else {
		const DictRef boat = water::free_boat_at(state, dict_value(session), final_tile, level);
		if (gd::is_empty(state, boat)) {
			return state.new_array();
		}
		water::embark(state, dict_value(session), boat);
		state.append(messages, str(gd::format(state, key::s_boards_the_boat, {str(hero_name)})));
	}
	const DictRef movement = sub_dict(state, session_view::overworld(state, session), key::movement);
	state.set(movement, str(key::current), int_value(0));
	state.set(session_view::overworld(state, session), str(key::movement), dict_value(movement));
	hero_command_rules::commit_active_hero(state, session);
	return messages;
}

bool _descriptor_matches_hero_level(State &state, DictRef session, DictRef descriptor) {
	const int64_t level = hero_level(state, session);
	if (state.has(descriptor, str(key::level)) && gd::to_int(state, gd::index(state, descriptor, str(key::level))) != level) {
		return false;
	}
	const Atom placement_id = ai::string_or_empty(state, descriptor, key::placement_id);
	if (placement_id != key::empty && placement_level(state, session, placement_id, level) != level) {
		return false;
	}
	if (ai::string_or_empty(state, descriptor, key::kind) == key::hero) {
		const DictRef target = hero_command_rules::hero_by_id(state, session, ai::string_or_empty(state, descriptor, key::hero_id));
		if (!gd::is_empty(state, target) && !level_rules::on_level(state, dict_value(target), level)) {
			return false;
		}
	}
	return true;
}

DictRef execute_prevalidated_route(State &state, DictRef session, const Value &route_tiles, DictRef route_preview, int64_t movement_budget, DictRef destination_descriptor) {
	_rules_profile_begin(state);
	const int64_t execute_started_usec = _rules_profile_timer(state);
	int64_t route_shape_started_usec = _rules_profile_timer(state);
	const Tiles tiles = _normalize_route_tiles(state, route_tiles);
	const int64_t path_size = static_cast<int64_t>(tiles.size());
	_rules_profile_add_ms(state, key::execute_prevalidated_route_shape_ms, route_shape_started_usec);
	if (path_size <= 1) {
		_rules_profile_finish(state);
		return cached_route_failure(state, key::no_route_selected);
	}
	const ArrayRef path = tiles_array(state, tiles);
	state.erase(session_view::overworld(state, session), str(key::pending_site_recruits));
	if (!_descriptor_matches_hero_level(state, session, destination_descriptor)) {
		_rules_profile_finish(state);
		return cached_route_failure(state, key::the_selected_route_belongs_to_another);
	}
	const Vector2i pos = hero_position(state, session);
	if (!(tiles[0] == pos)) {
		_rules_profile_finish(state);
		return cached_route_failure(state, key::the_selected_route_no_longer_starts);
	}

	const Value movement = field_or_new_dict(state, session_view::overworld(state, session), key::movement);
	const int64_t movement_left = movement_current(state, movement);
	const int64_t effective_budget = effective_budget_of(movement_left, movement_budget);
	if (effective_budget <= 0) {
		_rules_profile_finish(state);
		return cached_route_failure(state, key::no_movement_left_today);
	}

	route_shape_started_usec = _rules_profile_timer(state);
	DictRef preview = gd::deep_duplicate_dict(state, route_preview);
	if (gd::is_empty(state, preview)
			|| gd::to_int(state, state.get(preview, str(key::movement_budget), int_value(effective_budget))) != effective_budget
			|| gd::to_int(state, state.get(preview, str(key::total_steps), int_value(path_size - 1))) != path_size - 1) {
		preview = route_movement_preview(state, dict_value(session), array_value(path), effective_budget);
	}
	_rules_profile_add_ms(state, key::execute_prevalidated_route_shape_ms, route_shape_started_usec);
	int64_t reachable_steps = compat::engine_min<int64_t>(compat::engine_max<int64_t>(0, gd::int_field(state, preview, key::reachable_steps, 0)), path_size - 1);
	reachable_steps = compat::engine_min<int64_t>(reachable_steps, effective_budget);
	if (reachable_steps <= 0) {
		_rules_profile_finish(state);
		return cached_route_failure(state, key::no_movement_left_today);
	}

	const int64_t apply_started_usec = _rules_profile_timer(state);
	const Vector2i final_tile = as_vector2i(state.at(path, reachable_steps));
	const Vector2i destination_tile = as_vector2i(state.at(path, path_size - 1));
	_set_active_hero_position(state, session, final_tile, -1);
	const int64_t movement_after = gd::to_int(state, state.get(preview, str(key::movement_after_reachable), int_value(movement_left - reachable_steps)));
	set_movement_current(state, movement, compat::engine_max<int64_t>(0, movement_after));
	state.set(session_view::overworld(state, session), str(key::movement), movement);
	hero_command_rules::commit_active_hero(state, session);
	const ArrayRef water_messages = _apply_water_route_arrival(state, session, path, reachable_steps);
	_rules_profile_add_ms(state, key::execute_prevalidated_apply_movement_ms, apply_started_usec);
	const int64_t route_fog_started_usec = _rules_profile_timer(state);
	_reveal_route_fog(state, session, gd::slice(state, path, 1, reachable_steps + 1));
	_rules_profile_add_ms(state, key::execute_prevalidated_route_fog_ms, route_fog_started_usec);
	_mark_runtime_normalized(state, session);

	const bool reached_destination = final_tile == destination_tile;
	const ArrayRef messages = move_messages(state, final_tile, water_messages, reached_destination, path_size - 1 - reachable_steps);
	DictRef interaction_result = open_interaction(state);
	Atom execution_mode = key::open_fast_path;
	Atom interaction_dispatch_mode = key::none;
	bool post_action_recap_skipped = true;
	bool scenario_eval_skipped = true;
	if (reached_destination) {
		const Atom descriptor_kind = ai::string_or_empty(state, destination_descriptor, key::kind);
		if (gd::is_empty(state, destination_descriptor) || descriptor_kind == key::empty || descriptor_kind == key::open || descriptor_kind == key::current) {
			interaction_result = open_interaction(state);
		} else {
			execution_mode = key::destination_interaction_fast_path;
			interaction_dispatch_mode = key::destination_descriptor;
			post_action_recap_skipped = false;
			scenario_eval_skipped = false;
			_rules_profile_set(state, key::descriptor, key::kind, str(descriptor_kind));
			_rules_profile_count(state, key::descriptor_dispatch_count, 1);
			const int64_t dispatch_started_usec = _rules_profile_timer(state);
			interaction_result = _resolve_destination_descriptor_interaction(state, session, destination_descriptor);
			_rules_profile_add_ms(state, key::descriptor_dispatch_total_ms, dispatch_started_usec);
		}
		const Atom interaction_message = gd::stringify(state, state.get(interaction_result, str(key::message), str(key::empty)));
		if (interaction_message != key::empty) {
			state.append(messages, str(interaction_message));
		}
	}
	DictRef result = 0;
	if (execution_mode == key::destination_interaction_fast_path) {
		result = gd::deep_duplicate_dict(state, interaction_result);
		state.set(result, str(key::ok), bool_value(gd::to_bool(state.get(interaction_result, str(key::ok), bool_value(true)))));
		state.set(result, str(key::message), str(join_messages(state, messages)));
		if (!state.has(result, str(key::scenario_status))) {
			state.set(result, str(key::scenario_status), gd::index(state, session, str(key::scenario_status)));
		}
	} else {
		result = state.new_dict();
		state.set(result, str(key::ok), bool_value(gd::to_bool(state.get(interaction_result, str(key::ok), bool_value(true)))));
		state.set(result, str(key::message), str(join_messages(state, messages)));
	}
	const Atom route = gd::stringify(state, state.get(interaction_result, str(key::route), str(key::empty)));
	if (route != key::empty) {
		state.set(result, str(key::route), str(route));
	}
	if (state.has(interaction_result, str(key::reward_choice))) {
		state.set(result, str(key::reward_choice), gd::duplicate_value(state, gd::index(state, interaction_result, str(key::reward_choice)), true));
	}
	state.set(result, str(key::route_steps), array_value(_route_tile_payloads(state, route_steps(tiles, reachable_steps + 1))));
	const DictRef route_execution = gd::deep_duplicate_dict(state, preview);
	state.set(route_execution, str(key::reached_destination), bool_value(reached_destination));
	state.set(route_execution, str(key::route_validation_mode), str(key::cached_prevalidated));
	state.set(route_execution, str(key::cached_execution_mode), str(execution_mode));
	state.set(route_execution, str(key::post_action_recap_skipped), bool_value(post_action_recap_skipped));
	state.set(route_execution, str(key::scenario_eval_skipped), bool_value(scenario_eval_skipped));
	state.set(route_execution, str(key::interaction_dispatch_mode), str(interaction_dispatch_mode));
	state.set(route_execution, str(key::descriptor_route_fog_reused), bool_value(gd::to_bool(state.get(interaction_result, str(key::descriptor_route_fog_reused), bool_value(false)))));
	if (gd::to_bool(state.get(result, str(key::ok), bool_value(false))) && !state.has(result, str(key::post_action_recap))) {
		result = _attach_post_action_recap(state, result, session, key::move_,
				move_recap_context(state, pos, final_tile, route, state.new_dict(), route_steps(tiles, reachable_steps + 1), destination_tile, reached_destination));
		post_action_recap_skipped = false;
		state.set(route_execution, str(key::post_action_recap_skipped), bool_value(false));
	}
	_rules_profile_add_ms(state, key::execute_prevalidated_total_ms, execute_started_usec);
	const DictRef rules_profile = _rules_profile_finish(state);
	if (!gd::is_empty(state, rules_profile)) {
		const DictRef scenario_profile = sub_dict(state, rules_profile, key::scenario_eval);
		if (ai::string_or_empty(state, scenario_profile, key::dependency_mode) == key::event_gated_skip) {
			state.set(route_execution, str(key::scenario_eval_skipped), bool_value(true));
		}
		for (const Atom section : {key::sub_buckets_ms, key::rule_counts, key::descriptor, key::scenario_eval, key::post_action_recap, key::fog, key::blocked_index, key::interactable}) {
			state.set(route_execution, str(section), field_or_new_dict(state, rules_profile, section));
		}
	}
	state.set(result, str(key::route_execution), dict_value(route_execution));
	state.set(result, str(key::route_validation_mode), str(key::cached_prevalidated));
	return result;
}

bool _tile_blocks_route_step(State &state, DictRef session, Vector2i tile, bool is_destination) {
	if (!hero_route_tile_blocked(state, session, tile.x, tile.y, -1)) {
		return false;
	}
	if (is_destination && hero_route_destination(state, session, tile.x, tile.y, -1)) {
		return false;
	}
	return true;
}

void _set_active_hero_position(State &state, DictRef session, Vector2i tile, int64_t level) {
	const DictRef overworld = session_view::overworld(state, session);
	const DictRef position = level_rules::moved_position(state, field_or_new_dict(state, overworld, key::hero_position), tile, level);
	state.set(overworld, str(key::hero_position), dict_value(gd::deep_duplicate_dict(state, position)));
	const DictRef active_hero = sub_dict(state, overworld, key::hero);
	state.set(active_hero, str(key::position), dict_value(gd::deep_duplicate_dict(state, position)));
	state.set(overworld, str(key::hero), dict_value(active_hero));
	// String(session.overworld.get("active_hero_id", active_hero.get("id", "")))
	Value active_hero_id_value;
	const Atom active_hero_id = state.lookup(overworld, str(key::active_hero_id), active_hero_id_value)
			? gd::stringify(state, active_hero_id_value)
			: ai::string_or_empty(state, active_hero, key::id);
	const Value heroes = field_or_new_array(state, overworld, key::player_heroes);
	if (gd::is_array(heroes)) {
		const int64_t count = state.array_size(heroes.ref);
		for (int64_t index = 0; index < count; ++index) {
			const Value hero = state.at(heroes.ref, index);
			if (gd::is_dict(hero) && ai::string_or_empty(state, hero.ref, key::id) == active_hero_id) {
				state.set(hero.ref, str(key::position), dict_value(gd::deep_duplicate_dict(state, position)));
				state.set_at(heroes.ref, index, hero);
				break;
			}
		}
		state.set(overworld, str(key::player_heroes), heroes);
	}
}

void _reveal_route_fog(State &state, DictRef session, ArrayRef traversed_tiles) {
	// session == null: a view is never null.
	if (!_fog_state_ready(state, session)) {
		_normalize_fog_of_war(state, session);
	}
	const Vector2i map_size = derive_map_size(state, session);
	_rules_profile_set(state, key::fog, key::grid_cells, int_value(gd::mul(compat::engine_max<int64_t>(map_size.x, 0), compat::engine_max<int64_t>(map_size.y, 0))));
	const DictRef fog = fog_for_level(state, session, -1);
	const int64_t before_explored_count = gd::int_field(state, fog, key::explored_count, -1);
	const int64_t normalize_started_usec = _rules_profile_timer(state);
	// Reveal into the stored explored grid when it already has the map's shape;
	// only a malformed legacy grid is rebuilt.
	ArrayRef explored_tiles = ai::typed_array(field_or_new_array(state, fog, key::explored_tiles), "OverworldRules._reveal_route_fog");
	if (!_visibility_grid_has_shape(state, array_value(explored_tiles), map_size)) {
		explored_tiles = _normalize_visibility_grid(state, array_value(explored_tiles), map_size);
	}
	_rules_profile_add_ms(state, key::fog_normalize_grid_ms, normalize_started_usec);
	const DictRef hero = sub_dict(state, session_view::overworld(state, session), key::hero);
	const int64_t route_reveal_started_usec = _rules_profile_timer(state);
	// The scouting radius depends on the hero, not on the tile: resolved once.
	const int64_t scouting_radius = hero_command_rules::scouting_radius_for_hero(state, hero);
	for (const Value &tile_value_entry : gd::items(state, array_value(traversed_tiles))) {
		const Vector2i tile = _route_tile_from_variant(state, tile_value_entry);
		if (tile.x < 0 || tile.y < 0) {
			continue;
		}
		const DictRef site_state = state.new_dict();
		state.set(site_state, str(key::x), int_value(tile.x));
		state.set(site_state, str(key::y), int_value(tile.y));
		_apply_site_reveal(state, explored_tiles, site_state, scouting_radius, map_size);
	}
	_rules_profile_add_ms(state, key::fog_apply_route_reveal_ms, route_reveal_started_usec);
	const int64_t sources_started_usec = _rules_profile_timer(state);
	_reveal_all_current_fog_sources(state, session, explored_tiles, map_size, -1);
	_rules_profile_add_ms(state, key::fog_reveal_current_sources_ms, sources_started_usec);
	// Visible tiles alias explored tiles in this fog model; share one grid.
	const DictRef payload = _build_fog_payload(state, explored_tiles, explored_tiles, map_size);
	if (before_explored_count >= 0) {
		const int64_t explored_count = gd::to_int(state, state.get(payload, str(key::explored_count), int_value(before_explored_count)));
		_rules_profile_set(state, key::fog, key::changed_cells, int_value(compat::engine_max<int64_t>(0, gd::sub(explored_count, before_explored_count))));
	}
	_store_level_fog(state, session, payload, -1);
}

bool _visibility_grid_has_shape(State &state, const Value &grid, Vector2i map_size) {
	if (!gd::is_array(grid) || state.array_size(grid.ref) != map_size.y) {
		return false;
	}
	for (const Value &row : gd::items(state, grid)) {
		if (!gd::is_array(row) || state.array_size(row.ref) != map_size.x) {
			return false;
		}
	}
	return true;
}

} // namespace overworld_rules

namespace native_transit_rules {

DictRef network_colour(State &state, DictRef node) {
	// NETWORK_COLOURS[...]: an item of the script's const Array, read-only as
	// GDScript hands it out (its colours are Color values the State keeps opaque).
	const ArrayRef colours = gd::as_array(gd::static_var(state, key::native_transit_rules_script, key::NETWORK_COLOURS));
	const Value fallback = int_value(network_index(state, node));
	const int64_t colour = gd::to_int(state, state.get(node, str(key::portal_colour), fallback));
	return gd::as_dict(state.at(colours, compat::posmod(colour, state.array_size(colours))));
}

} // namespace native_transit_rules

namespace overworld_level_rules {

DictRef moved_position(State &state, const Value &previous, Vector2i tile, int64_t level) {
	// position(previous): a Dictionary's, a Vector3i's as {"x", "y", "level"}, a
	// Vector2i's, or the origin.
	DictRef result = 0;
	if (gd::is_dict(previous)) {
		result = position(state, previous.ref);
	} else if (gd::is_vector3i(previous)) {
		const DictRef source = state.new_dict();
		state.set(source, str(key::x), int_value(previous.vx()));
		state.set(source, str(key::y), int_value(previous.vy()));
		state.set(source, str(key::level), int_value(previous.vz()));
		result = position(state, source);
	} else if (gd::is_vector2i(previous)) {
		result = state.new_dict();
		state.set(result, str(key::x), int_value(previous.vx()));
		state.set(result, str(key::y), int_value(previous.vy()));
	} else {
		result = state.new_dict();
		state.set(result, str(key::x), int_value(0));
		state.set(result, str(key::y), int_value(0));
	}
	state.set(result, str(key::x), int_value(tile.x));
	state.set(result, str(key::y), int_value(tile.y));
	if (level >= 0) {
		if (level == 0) {
			state.erase(result, str(key::level));
		} else {
			state.set(result, str(key::level), int_value(level));
		}
	}
	return result;
}

} // namespace overworld_level_rules

} // namespace aurelion::rules::port
