// OverworldRules for the overworld panels (Phase 7, slice 7.8): the read scope,
// the status, hero, context and town texts, the map's footprints and pathing
// surface.

#include "aurelion_rules/port/overworld_rules_panels.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/battle_ends.hpp"
#include "aurelion_rules/port/battle_payload.hpp"
#include "aurelion_rules/port/difficulty_rules.hpp"
#include "aurelion_rules/port/hero_command_rules_ai.hpp"
#include "aurelion_rules/port/mine_rules.hpp"
#include "aurelion_rules/port/overworld_level_rules.hpp"
#include "aurelion_rules/port/overworld_rules_ai.hpp"
#include "aurelion_rules/port/overworld_rules_turn.hpp"
#include "aurelion_rules/port/resource_node_payload_rules_ai.hpp"
#include "aurelion_rules/port/session_view.hpp"

#include <algorithm>
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
using gd::int_value;
using gd::str;
using overworld_rules::Tiles;
using overworld_rules::Vector2i;
using state::ContentTable;
using state::Kind;
using state::State;
using state::Value;
namespace key = state::key;

constexpr Atom kScript = key::overworld_rules_script;

// String(d.get(field, fallback)).
Atom field_text(State &state, DictRef dict, Atom field, Atom fallback) {
	return gd::stringify(state, state.get(dict, str(field), str(fallback)));
}

// String(x.get(field, fallback)) of an untyped value.
Atom value_field_text(State &state, const Value &object, Atom field, Atom fallback) {
	return gd::stringify(state, ai::vget(state, object, field, str(fallback)));
}

// String(session.field).
Atom session_text(State &state, DictRef session, Atom field) {
	return gd::stringify(state, gd::index(state, session, str(field)));
}

// d.get(field, {}) where the answer is kept or passed on: a new Dictionary when
// it is missing.
Value field_or_new_dict(State &state, DictRef dict, Atom field) {
	Value found;
	return state.lookup(dict, str(field), found) ? found : dict_value(state.new_dict());
}

// var x: Dictionary = d.get(field, {}) if d.get(field, {}) is Dictionary else {},
// only read.
DictRef dict_or_empty(State &state, DictRef dict, Atom field) {
	Value found;
	return state.lookup(dict, str(field), found) && gd::is_dict(found) ? found.ref : state.new_dict();
}

// d.get(field, []) is Array and not d.get(field, []).is_empty(): the Array, or
// Nil.
Value nonempty_array_field(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found) && gd::is_array(found) && state.array_size(found.ref) > 0) {
		return found;
	}
	return Value();
}

// separator.join(parts) of Strings built here.
Atom join_atoms(State &state, Atom separator, const std::vector<Atom> &parts) {
	std::string joined;
	for (size_t index = 0; index < parts.size(); ++index) {
		if (index > 0) {
			joined += state.text(separator);
		}
		joined += state.text(parts[index]);
	}
	return state.intern(joined);
}

// separator.join(array): the Array as a PackedStringArray, each item String(item).
Atom join_array(State &state, Atom separator, ArrayRef array) {
	std::vector<Atom> parts;
	for (const Value &item : gd::items(state, array_value(array))) {
		parts.push_back(gd::stringify(state, item));
	}
	return join_atoms(state, separator, parts);
}

// text.split(delimiter) (allow_empty: every piece, the empty ones too).
std::vector<Atom> split_text(State &state, Atom text, Atom delimiter) {
	const std::string whole = state.text(text);
	const std::string separator = state.text(delimiter);
	std::vector<Atom> pieces;
	size_t from = 0;
	for (;;) {
		const size_t at = whole.find(separator, from);
		if (at == std::string::npos) {
			pieces.push_back(state.intern(whole.substr(from)));
			break;
		}
		pieces.push_back(state.intern(whole.substr(from, at - from)));
		from = at + separator.size();
	}
	return pieces;
}

// text.to_lower() of ASCII text (the pressure labels are constants).
Atom to_lower_ascii(State &state, Atom text) {
	std::string lowered = state.text(text);
	for (char &c : lowered) {
		if (c >= 'A' && c <= 'Z') {
			c = static_cast<char>(c - 'A' + 'a');
		}
	}
	return state.intern(lowered);
}

// Tiles as the Array of Vector2i GDScript holds.
ArrayRef tiles_array(State &state, const Tiles &tiles) {
	const ArrayRef array = state.new_array();
	for (const Vector2i tile : tiles) {
		state.append(array, Value::of_vector2i(tile.x, tile.y));
	}
	return array;
}

// A value passed where GDScript's static type is Vector2i.
Vector2i tile_of(const Value &value) {
	if (!gd::is_vector2i(value)) {
		throw state::ScriptError(std::string("Invalid type in function '_tile_payload': expected Vector2i, got ") + gd::type_name(value));
	}
	return Vector2i{ value.vx(), value.vy() };
}

// The first entry of a spatial lookup table at a tile: its record when it is a
// Dictionary, {} when the entry's index is out of range, and {} when there is none.
DictRef record_at_tile(State &state, DictRef session, Atom collection, Atom table, int64_t x, int64_t y) {
	// var records = session.overworld.get(collection, []): a missing one is an
	// empty Array.
	Value records;
	const bool has_records = state.lookup(session_view::overworld(state, session), str(collection), records);
	const DictRef lookup_index = overworld_rules::_spatial_lookup_index(state, session, -1);
	const ArrayRef entries = overworld_rules::_spatial_lookup_entries(state, lookup_index, table, Vector2i::of(x, y));
	for (const Value &record_index : gd::items(state, array_value(entries))) {
		Value record;
		if ((!has_records || gd::is_array(records)) && gd::to_int(state, record_index) >= 0
				&& gd::to_int(state, record_index) < (has_records ? state.array_size(records.ref) : 0)) {
			record = state.at(records.ref, gd::to_int(state, record_index));
		} else {
			record = dict_value(state.new_dict());
		}
		if (gd::is_dict(record)) {
			return record.ref;
		}
	}
	return state.new_dict();
}

// {"ok": ok, "message": message, "town": town}.
DictRef visit_result(State &state, bool ok, Atom message, const Value &town) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(ok));
	state.set(result, str(key::message), str(message));
	state.set(result, str(key::town), town);
	return result;
}

// town_occupation_state(session, town) of a session that may be null: its
// cache key is "" then, so the cache is neither read nor written.
DictRef occupation_state_of(State &state, const Value &session, DictRef town) {
	if (session.kind == Kind::Nil) {
		return overworld_rules::_town_occupation_state(state, Value(), town);
	}
	return overworld_rules::town_occupation_state(state, gd::as_dict(session), town);
}

} // namespace

namespace overworld_rules {

bool is_runtime_session_normalized(State &state, DictRef session) {
	// session == null: the registry answers it; a view is never null.
	const DictRef signatures = ai::static_dict(state, kScript, key::_runtime_normalized_signatures);
	const Atom stored = gd::stringify(state, state.get(signatures, str(session_text(state, session, key::session_id)), str(key::empty)));
	return stored == _runtime_normalization_signature(state, session);
}

void begin_normalized_read_scope(State &state, DictRef session) {
	// session == null: the registry answers it; a view is never null.
	if (ai::static_int(state, kScript, key::_normalized_read_scope_depth) <= 0) {
		normalize_overworld_state_for_runtime(state, session);
		gd::set_static_var(state, kScript, key::_normalized_read_scope_session_id, str(session_text(state, session, key::session_id)));
		gd::set_static_var(state, kScript, key::_normalized_read_scope_depth, int_value(1));
		gd::set_static_var(state, kScript, key::_normalized_read_scope_cache, dict_value(state.new_dict()));
		gd::set_static_var(state, kScript, key::_normalized_read_scope_town_digests, array_value(state.new_array()));
		const DictRef profile = state.new_dict();
		state.set(profile, str(key::hits), int_value(0));
		state.set(profile, str(key::misses), int_value(0));
		state.set(profile, str(key::entries), int_value(0));
		gd::set_static_var(state, kScript, key::_last_normalized_read_scope_cache_profile, dict_value(profile));
		return;
	}
	if (session_text(state, session, key::session_id) == gd::to_string(gd::static_var(state, kScript, key::_normalized_read_scope_session_id))) {
		gd::set_static_var(state, kScript, key::_normalized_read_scope_depth, int_value(gd::add(ai::static_int(state, kScript, key::_normalized_read_scope_depth), 1)));
		return;
	}
	normalize_overworld_state_for_runtime(state, session);
}

void end_normalized_read_scope(State &state, DictRef session) {
	// session == null: the registry answers it; a view is never null.
	if (ai::static_int(state, kScript, key::_normalized_read_scope_depth) <= 0
			|| session_text(state, session, key::session_id) != gd::to_string(gd::static_var(state, kScript, key::_normalized_read_scope_session_id))) {
		return;
	}
	gd::set_static_var(state, kScript, key::_normalized_read_scope_depth, int_value(gd::sub(ai::static_int(state, kScript, key::_normalized_read_scope_depth), 1)));
	if (ai::static_int(state, kScript, key::_normalized_read_scope_depth) <= 0) {
		const int64_t entries = state.dict_size(ai::static_dict(state, kScript, key::_normalized_read_scope_cache));
		state.set(ai::static_dict(state, kScript, key::_last_normalized_read_scope_cache_profile), str(key::entries), int_value(entries));
		gd::set_static_var(state, kScript, key::_normalized_read_scope_depth, int_value(0));
		gd::set_static_var(state, kScript, key::_normalized_read_scope_session_id, str(key::empty));
		gd::set_static_var(state, kScript, key::_normalized_read_scope_cache, dict_value(state.new_dict()));
		gd::set_static_var(state, kScript, key::_normalized_read_scope_town_digests, array_value(state.new_array()));
	}
}

DictRef validation_last_normalized_read_scope_cache_profile(State &state) {
	return gd::deep_duplicate_dict(state, ai::static_dict(state, kScript, key::_last_normalized_read_scope_cache_profile));
}

DictRef validation_pathing_profile_snapshot(State &state) {
	return gd::deep_duplicate_dict(state, ai::static_dict(state, kScript, key::_pathing_debug_profile));
}

void validation_set_pathing_profile_capture_enabled(State &state, bool enabled) {
	const DictRef profile = ai::static_dict(state, kScript, key::_pathing_debug_profile);
	state.set(profile, str(key::capture_enabled), bool_value(enabled));
	if (enabled) {
		state.set(profile, str(key::route_interaction_lookup_count), int_value(0));
		state.set(profile, str(key::route_interaction_spatial_lookup_count), int_value(0));
		state.set(profile, str(key::route_interaction_full_scan_count), int_value(0));
		state.set(profile, str(key::town_placement_lookup_direct_index_count), int_value(0));
		state.set(profile, str(key::town_placement_lookup_spatial_index_count), int_value(0));
		state.set(profile, str(key::town_placement_lookup_full_scan_count), int_value(0));
		state.set(profile, str(key::post_move_global_discovery_count), int_value(0));
		state.set(profile, str(key::post_action_tile_context_scan_count), int_value(0));
	}
}

Atom describe_visibility(State &state, DictRef session) {
	// session == null: the registry answers it; a view is never null.
	if (!_fog_state_ready(state, session)) {
		normalize_overworld_state(state, session);
	}
	Value fog;
	if (!state.lookup(session_view::overworld(state, session), str(key::fog), fog)) {
		// fog = {}: every count is its fallback 0.
		return gd::format(state, key::explored_d_d_visible_d, { int_value(0), int_value(0), int_value(0) });
	}
	const int64_t explored = gd::to_int(state, ai::vget(state, fog, key::explored_count, int_value(0)));
	const int64_t total = gd::to_int(state, ai::vget(state, fog, key::total_tiles, int_value(0)));
	const int64_t visible = gd::to_int(state, ai::vget(state, fog, key::visible_count, int_value(0)));
	return gd::format(state, key::explored_d_d_visible_d, { int_value(explored), int_value(total), int_value(visible) });
}

DictRef set_active_town_visit(State &state, DictRef session, Atom placement_id) {
	normalize_overworld_state_for_runtime(state, session);
	// session == null: the registry answers it; a view is never null.
	if (placement_id == key::empty) {
		return visit_result(state, false, key::no_town_was_selected, dict_value(state.new_dict()));
	}
	const DictRef town_result = _find_town_by_placement(state, session, placement_id);
	const DictRef town = gd::as_dict(field_or_new_dict(state, town_result, key::town));
	if (gd::int_field(state, town_result, key::index, -1) < 0 || gd::is_empty(state, town)) {
		clear_active_town_visit(state, session);
		return visit_result(state, false, key::the_selected_town_is_no_longer, dict_value(state.new_dict()));
	}
	if (field_text(state, town, key::owner, key::neutral) != key::player) {
		clear_active_town_visit(state, session);
		return visit_result(state, false, key::only_owned_towns_can_be_managed, dict_value(town));
	}
	state.set(gd::as_dict(gd::index(state, session, str(key::flags))), str(key::active_town_placement_id), str(placement_id));
	state.set(ai::static_dict(state, kScript, key::_active_town_visit_indexes), str(session_text(state, session, key::session_id)), int_value(gd::int_field(state, town_result, key::index, -1)));
	_teach_visiting_town_spells(state, session, town);
	return visit_result(state, true, gd::format(state, key::s_opens_its_gates, { str(_town_name(state, town)) }), dict_value(town));
}

DictRef _resource_node_at_tile(State &state, DictRef session, int64_t x, int64_t y) {
	return record_at_tile(state, session, key::resource_nodes, key::resource_by_tile, x, y);
}

DictRef _encounter_at_tile(State &state, DictRef session, int64_t x, int64_t y) {
	return record_at_tile(state, session, key::encounters, key::encounter_by_tile, x, y);
}

DictRef overworld_object_placement_pathing_surface(State &state, DictRef session, Atom placement_id) {
	// session == null: the registry answers it; a view is never null.
	if (placement_id == key::empty) {
		return state.new_dict();
	}
	const DictRef node_result = _find_resource_node_by_placement(state, session, placement_id);
	const DictRef node = gd::as_dict(field_or_new_dict(state, node_result, key::node));
	if (gd::int_field(state, node_result, key::index, -1) < 0 || gd::is_empty(state, node)) {
		return state.new_dict();
	}
	const DictRef map_object = _map_object_for_resource_node(state, node);
	if (gd::is_empty(state, map_object)) {
		return state.new_dict();
	}
	const Tiles body_tiles = _map_object_world_body_tiles(state, map_object, node);
	const ArrayRef interaction_tiles = _resource_node_world_interaction_tiles(state, map_object, node);
	const DictRef footprint = dict_or_empty(state, map_object, key::footprint);
	const int64_t width = compat::engine_max<int64_t>(1, gd::int_field(state, footprint, key::width, 1));
	const int64_t height = compat::engine_max<int64_t>(1, gd::int_field(state, footprint, key::height, 1));
	const Vector2i origin = _map_object_footprint_origin(state, map_object, node);
	const ArrayRef body_payload = state.new_array();
	for (const Vector2i tile : body_tiles) {
		state.append(body_payload, dict_value(_tile_payload(state, tile)));
	}
	const ArrayRef interaction_payload = state.new_array();
	for (const Value &tile : gd::items(state, array_value(interaction_tiles))) {
		state.append(interaction_payload, dict_value(_tile_payload(state, tile_of(tile))));
	}

	const DictRef surface = state.new_dict();
	state.set(surface, str(key::placement_id), str(placement_id));
	state.set(surface, str(key::site_id), str(field_text(state, node, key::site_id, key::empty)));
	state.set(surface, str(key::object_id), str(field_text(state, map_object, key::id, key::empty)));
	const DictRef footprint_payload = state.new_dict();
	state.set(footprint_payload, str(key::width), int_value(width));
	state.set(footprint_payload, str(key::height), int_value(height));
	state.set(footprint_payload, str(key::anchor), str(field_text(state, footprint, key::anchor, key::bottom_center)));
	state.set(footprint_payload, str(key::origin), dict_value(_tile_payload(state, origin)));
	state.set(footprint_payload, str(key::visual_tile_count), int_value(gd::mul(width, height)));
	state.set(surface, str(key::footprint), dict_value(footprint_payload));
	state.set(surface, str(key::body_tiles), array_value(body_payload));
	state.set(surface, str(key::interaction_tiles), array_value(interaction_payload));
	state.set(surface, str(key::body_tile_count), int_value(state.array_size(body_payload)));
	state.set(surface, str(key::interaction_tile_count), int_value(state.array_size(interaction_payload)));
	state.set(surface, str(key::uses_authored_body_tiles), bool_value(nonempty_array_field(state, map_object, key::body_tiles).kind != Kind::Nil));
	state.set(surface, str(key::uses_runtime_body_tiles), bool_value(_resource_node_has_runtime_object_contract(state, node)));
	state.set(surface, str(key::uses_runtime_visit_tile), bool_value(_resource_node_has_runtime_visit_tile(state, node)));
	Value approach;
	const bool uses_authored_approach = state.lookup(map_object, str(key::approach), approach) && gd::is_dict(approach) && !gd::is_empty(state, approach.ref);
	state.set(surface, str(key::uses_authored_approach), bool_value(uses_authored_approach));
	state.set(surface, str(key::blocks_body_tiles), bool_value(_resource_node_blocks_body_tiles(state, node, map_object)));
	state.set(surface, str(key::blocks_visual_footprint_rectangle), bool_value(false));
	return surface;
}

ArrayRef town_footprint_tiles(State &state, DictRef town) {
	const ArrayRef tiles = tiles_array(state, _generated_body_tiles_for_placement(state, town, true));
	const DictRef entrance = overworld_level_rules::town_entrance(state, town);
	const Vector2i entrance_tile = Vector2i::of(gd::int_field(state, entrance, key::x, -1), gd::int_field(state, entrance, key::y, -1));
	const Value entrance_value = Value::of_vector2i(entrance_tile.x, entrance_tile.y);
	if (entrance_tile.x >= 0 && entrance_tile.y >= 0 && !gd::array_has(state, tiles, entrance_value)) {
		state.append(tiles, entrance_value);
	}
	return tiles;
}

bool hero_cast_spell_today(State &state, DictRef session, Atom hero_id) {
	// session == null: the registry answers it; a view is never null.
	if (hero_id == key::empty) {
		return false;
	}
	const DictRef overworld = session_view::overworld(state, session);
	const DictRef hero = hero_id == field_text(state, overworld, key::active_hero_id, key::empty)
			? gd::as_dict(field_or_new_dict(state, overworld, key::hero))
			: hero_command_rules::hero_by_id(state, session, hero_id);
	return spell_rules::cast_overworld_spell_on_day(state, hero, ai::session_int(state, session, key::day));
}

ArrayRef mine_footprint_tiles(State &state, DictRef node) {
	if (field_text(state, node, key::kind, key::empty) == key::reward_reference) {
		return state.new_array();
	}
	if (mine_rules::resource(state, node) != key::empty) {
		return mine_rules::body_tiles(state, node);
	}
	const DictRef site = gd::content_row(state, ContentTable::ResourceSite, field_text(state, node, key::site_id, key::empty));
	if (field_text(state, site, key::family, key::empty) != key::mine && field_text(state, node, key::kind, key::empty) != key::mine) {
		return state.new_array();
	}
	const DictRef map_object = _map_object_for_resource_node(state, node);
	const ArrayRef tiles = tiles_array(state, _map_object_world_body_tiles(state, map_object, node));
	const ArrayRef interaction_tiles = _resource_node_world_interaction_tiles(state, map_object, node);
	for (const Value &tile : gd::items(state, array_value(interaction_tiles))) {
		if (!gd::array_has(state, tiles, tile)) {
			state.append(tiles, tile);
		}
	}
	return tiles;
}

Atom describe_status(State &state, DictRef session) {
	normalize_overworld_state(state, session);
	const Vector2i pos = hero_position(state, session);
	const Value movement = field_or_new_dict(state, session_view::overworld(state, session), key::movement);
	const int64_t days_until_growth = days_until_next_weekly_growth(state, ai::session_int(state, session, key::day));
	const int64_t week = _week_of_day(state, ai::session_int(state, session, key::day));
	const int64_t weekday = _weekday_of_day(state, ai::session_int(state, session, key::day));
	const int64_t current = gd::to_int(state, ai::vget(state, movement, key::current, int_value(0)));
	const int64_t max = gd::to_int(state, ai::vget(state, movement, key::max, int_value(0)));
	const Atom visibility = describe_visibility(state, session);
	const int64_t growth_day = next_weekly_growth_day(state, ai::session_int(state, session, key::day));
	return gd::format(state, key::week_d_day_d_pos_d, {
			int_value(week),
			int_value(weekday),
			int_value(pos.x),
			int_value(pos.y),
			int_value(current),
			int_value(max),
			str(visibility),
			int_value(growth_day),
			int_value(days_until_growth),
			str(days_until_growth == 1 ? key::empty : key::s),
	});
}

int64_t _weekday_of_day(State &state, int64_t day) {
	(void)state;
	return gd::add(compat::int_mod(gd::sub(compat::engine_max<int64_t>(day, 1), 1), 7), 1);
}

Atom _overworld_hero_line(State &state, DictRef hero) {
	const Atom identity = hero_command_rules::hero_identity_context_line(state, hero, key::empty);
	const Atom progress = hero_command_rules::hero_progress_context_line(state, hero);
	const Atom readiness = hero_command_rules::hero_readiness_context_line(state, hero, true);
	return gd::format(state, key::s_s_s_6, { str(identity), str(progress), str(readiness) });
}

Atom describe_heroes(State &state, DictRef session) {
	normalize_overworld_state(state, session);
	const DictRef overworld = session_view::overworld(state, session);
	const Atom active_hero_id = field_text(state, overworld, key::active_hero_id, key::empty);
	std::vector<Atom> lines{ key::command_wing };
	std::vector<Atom> reserves;
	for (const Value &hero : gd::field_items(state, overworld, str(key::player_heroes))) {
		if (!gd::is_dict(hero)) {
			continue;
		}
		const Atom line = _overworld_hero_line(state, hero.ref);
		if (field_text(state, hero.ref, key::id, key::empty) == active_hero_id) {
			lines.push_back(gd::format(state, key::active_command_s, { str(line) }));
		} else {
			reserves.push_back(gd::format(state, key::reserve_command_s, { str(line) }));
		}
	}
	if (reserves.empty()) {
		lines.push_back(key::no_reserve_commanders_are_currently_marching);
	} else {
		lines.push_back(gd::format(state, key::reserve_roster_d, { int_value(static_cast<int64_t>(reserves.size())) }));
		for (const Atom reserve : reserves) {
			lines.push_back(reserve);
		}
	}
	return join_atoms(state, key::newline, lines);
}

int64_t days_until_next_weekly_growth(State &state, int64_t day) {
	(void)state;
	return gd::sub(7, compat::int_mod(gd::sub(compat::engine_max<int64_t>(day, 1), 1), 7));
}

int64_t next_weekly_growth_day(State &state, int64_t day) {
	return gd::add(compat::engine_max<int64_t>(day, 1), days_until_next_weekly_growth(state, day));
}

Atom town_control_label(State &state, Atom owner) {
	// owner.strip_edges().to_lower(): a non-ASCII character lowers to ASCII only
	// as U+0130 to "i" and U+212A to "k", and no label below has either, so text
	// with one matches none.
	const Atom stripped = gd::strip_edges(state, owner);
	for (const char c : state.text(stripped)) {
		if (static_cast<unsigned char>(c) >= 0x80) {
			return key::unknown_control;
		}
	}
	const Atom lowered = to_lower_ascii(state, stripped);
	if (lowered == key::player) {
		return key::your_control;
	}
	if (lowered == key::enemy) {
		return key::enemy_control;
	}
	if (lowered == key::neutral) {
		return key::neutral_control;
	}
	return key::unknown_control;
}

Atom describe_town_context(State &state, DictRef town, const Value &session) {
	const Atom income = _describe_resource_delta(state, dict_value(_calculate_town_income(state, town, session)));
	const Atom weekly_growth = _describe_recruit_delta(state, dict_value(town_weekly_growth(state, town, session)));
	const Atom defense = _town_defense_summary(state, town);
	const int64_t readiness = town_battle_readiness(state, town, session);
	const int64_t pressure_output = town_pressure_output(state, town, session);
	const Atom strategic_role = town_strategic_role(state, town);
	const DictRef capital_project = town_capital_project_state(state, town, session);
	const DictRef battlefront = town_battlefront_profile(state, town);
	const DictRef occupation = occupation_state_of(state, session, town);
	std::vector<Atom> parts;
	parts.push_back(_town_name(state, town));
	const DictRef faction = gd::content_row(state, ContentTable::Faction, _town_faction_id(state, town));
	parts.push_back(gd::stringify(state, state.get(faction, str(key::name), str(_town_faction_id(state, town)))));
	parts.push_back(town_control_label(state, field_text(state, town, key::owner, key::neutral)));
	if (strategic_role == key::capital) {
		parts.push_back(key::capital_anchor);
	} else if (strategic_role == key::stronghold) {
		parts.push_back(key::frontier_stronghold);
	}
	for (const Atom line : split_text(state, _town_identity_surface(state, town, session), key::newline)) {
		if (gd::begins_with(state, line, key::economy_2) || gd::begins_with(state, line, key::magic_2) || gd::begins_with(state, line, key::strategic_cue)) {
			parts.push_back(line);
		}
	}
	if (income != key::empty) {
		parts.push_back(gd::format(state, key::daily_s, { str(income) }));
	}
	if (weekly_growth != key::empty) {
		parts.push_back(gd::format(state, key::weekly_s_2, { str(weekly_growth) }));
	}
	if (gd::bool_field(state, occupation, key::active, false)) {
		const int64_t days_to_clear = gd::int_field(state, occupation, key::days_to_clear, 0);
		parts.push_back(gd::format(state, key::pacifying_d_day_s, { int_value(days_to_clear), str(gd::int_field(state, occupation, key::days_to_clear, 0) == 1 ? key::empty : key::s) }));
	}
	if (defense != key::empty) {
		parts.push_back(gd::format(state, key::defense_s_2, { str(defense) }));
	}
	if (field_text(state, town, key::owner, key::neutral) == key::enemy && _town_garrison_headcount(state, town) > 0) {
		const int64_t headcount = _town_garrison_headcount(state, town);
		parts.push_back(gd::format(state, key::garrison_d_troops_d_companies, { int_value(headcount), int_value(_town_garrison_company_count(state, town)) }));
		if (_town_requires_assault(state, town)) {
			parts.push_back(key::assault_required);
		}
	}
	if (readiness > 0) {
		parts.push_back(gd::format(state, key::readiness_d_text, { int_value(readiness) }));
	}
	if (pressure_output > 0) {
		parts.push_back(gd::format(state, key::s_d_6, { str(_town_pressure_label(state, town)), int_value(pressure_output) }));
	}
	if (field_text(state, battlefront, key::label, key::empty) != key::empty) {
		parts.push_back(field_text(state, battlefront, key::label, key::empty));
	}
	if (gd::bool_field(state, capital_project, key::active, false)) {
		parts.push_back(key::project_online);
	} else if (gd::int_field(state, capital_project, key::total, 0) > 0) {
		parts.push_back(key::project_dormant);
	}
	if (session.kind != Kind::Nil) {
		const DictRef view = gd::as_dict(session);
		const DictRef logistics = town_logistics_state(state, view, town);
		if (field_text(state, logistics, key::summary, key::empty) != key::empty) {
			parts.push_back(gd::format(state, key::logistics_s_3, { str(field_text(state, logistics, key::summary, key::empty)) }));
		}
		const DictRef recovery = town_recovery_state(state, view, town);
		if (gd::bool_field(state, recovery, key::active, false)) {
			parts.push_back(gd::format(state, key::recovery_s, { str(field_text(state, recovery, key::summary, key::empty)) }));
		}
	}
	return join_atoms(state, key::space_bar_space, parts);
}

Atom describe_context(State &state, DictRef session) {
	const DictRef context = get_active_context(state, session);
	const Vector2i pos = hero_position(state, session);
	const Atom terrain = _terrain_name_at(state, session, pos.x, pos.y);
	const Atom type = field_text(state, context, key::type, key::empty_2);
	if (type == key::town) {
		const DictRef town = gd::as_dict(field_or_new_dict(state, context, key::town));
		const Atom name = _town_name(state, town);
		const Atom town_context = describe_town_context(state, town, dict_value(session));
		return gd::format(state, key::town_tile_terrain_s_s_s, { str(terrain), str(name), str(town_context) });
	}
	if (type == key::resource) {
		const DictRef node = gd::as_dict(field_or_new_dict(state, context, key::node));
		const DictRef site = resource_node_payload_rules::site_for_node(state, node, state.new_dict());
		const Atom role_label = _resource_site_role_label(state, node, site);
		const Atom site_name = field_text(state, site, key::name, key::resource_cache);
		const Atom summary = _resource_site_context_summary(state, session, node, site);
		return gd::format(state, key::s_terrain_s_s_s, { str(role_label), str(terrain), str(site_name), str(summary) });
	}
	if (type == key::artifact) {
		const Value artifact_node = field_or_new_dict(state, context, key::node);
		const DictRef hero = gd::as_dict(field_or_new_dict(state, session_view::overworld(state, session), key::hero));
		const Atom artifact_id = value_field_text(state, artifact_node, key::artifact_id, key::empty);
		const bool collected = gd::to_bool(ai::vget(state, artifact_node, key::collected, bool_value(false)));
		const Atom collected_by = value_field_text(state, artifact_node, key::collected_by_faction_id, key::empty);
		const Atom inspection = artifact_rules::describe_artifact_inspection(state, hero, artifact_id, collected, collected_by);
		return gd::format(state, key::artifact_cache_terrain_s_s, { str(terrain), str(inspection) });
	}
	if (type == key::encounter) {
		const DictRef placement = gd::as_dict(field_or_new_dict(state, context, key::encounter));
		const Atom object_surface = describe_encounter_object_surface(state, placement);
		const Atom display_name = encounter_display_name(state, placement);
		const Atom object_clause = object_surface == key::empty ? key::empty : gd::format(state, key::space_bar_space_s, { str(object_surface) });
		const Atom readability = describe_encounter_readability_surface(state, session, placement);
		const Atom pressure = _encounter_pressure_summary(state, session, placement, false);
		return gd::format(state, key::hostile_contact_terrain_s_s_s, { str(terrain), str(display_name), str(object_clause), str(readability), str(pressure) });
	}
	if (type == key::rendezvous) {
		const Atom rendezvous = hero_command_rules::describe_field_rendezvous(state, session);
		return gd::format(state, key::s_terrain_s_meet_to_exchange, { str(rendezvous), str(terrain) });
	}
	return gd::format(state, key::open_ground_terrain_s_no_immediate, { str(terrain) });
}

Atom describe_spellbook(State &state, DictRef session, Atom context_filter) {
	const DictRef overworld = session_view::overworld(state, session);
	if (context_filter == key::overworld) {
		const DictRef hero = gd::as_dict(field_or_new_dict(state, overworld, key::hero));
		return spell_rules::describe_overworld_spellbook(state, hero, gd::as_dict(field_or_new_dict(state, overworld, key::movement)));
	}
	return spell_rules::describe_spellbook(state, gd::as_dict(field_or_new_dict(state, overworld, key::hero)), context_filter);
}

Atom describe_spellbook_rail(State &state, DictRef session, Atom context_filter) {
	const DictRef overworld = session_view::overworld(state, session);
	if (context_filter == key::overworld) {
		const DictRef hero = gd::as_dict(field_or_new_dict(state, overworld, key::hero));
		return spell_rules::describe_overworld_spell_rail(state, hero, gd::as_dict(field_or_new_dict(state, overworld, key::movement)));
	}
	return spell_rules::describe_spellbook(state, gd::as_dict(field_or_new_dict(state, overworld, key::hero)), context_filter);
}

Atom describe_specialties(State &state, DictRef session) {
	normalize_overworld_state(state, session);
	return hero_progression_rules::describe_specialties(state, gd::as_dict(field_or_new_dict(state, session_view::overworld(state, session), key::hero)));
}

Atom describe_artifacts(State &state, DictRef session) {
	const Value hero = field_or_new_dict(state, session_view::overworld(state, session), key::hero);
	return artifact_rules::describe_management(state, gd::as_dict(hero));
}

Atom town_strategic_summary(State &state, DictRef town) {
	return _town_strategic_summary(state, town);
}

Atom describe_town_identity_surface(State &state, DictRef town, const Value &session) {
	return _town_identity_surface(state, town, session);
}

DictRef town_public_threat_state(State &state, DictRef session, DictRef town) {
	const Atom cache_key = _town_read_scope_cache_key(state, session, key::public_threat, town);
	if (_town_read_scope_cache_has(state, cache_key)) {
		return gd::as_dict(_town_read_scope_cache_get(state, cache_key));
	}
	const DictRef result = _town_command_risk_state(state, session, town, true);
	_town_read_scope_cache_store(state, cache_key, dict_value(result));
	return result;
}

DictRef town_occupation_state(State &state, DictRef session, DictRef town) {
	const Atom cache_key = _town_read_scope_cache_key(state, session, key::occupation, town);
	if (_town_read_scope_cache_has(state, cache_key)) {
		return gd::as_dict(_town_read_scope_cache_get(state, cache_key));
	}
	const DictRef result = _town_occupation_state(state, session, town);
	_town_read_scope_cache_store(state, cache_key, dict_value(result));
	return result;
}

Atom describe_town_market(State &state, DictRef session, DictRef town) {
	return join_array(state, key::newline, _town_market_panel_lines(state, session, town));
}

Atom describe_town_response_panel(State &state, DictRef session, DictRef town) {
	return join_array(state, key::newline, _town_response_panel_lines(state, session, town));
}

DictRef player_daily_income(State &state, DictRef session) {
	// session == null: the registry answers it; a view is never null.
	return _player_daily_income_projection(state, session, gd::add(ai::session_int(state, session, key::day), 1));
}

DictRef _player_daily_income_projection(State &state, DictRef session, int64_t next_day) {
	DictRef town_income = _empty_live_resource_stockpile(state);
	// var towns = session.overworld.get("towns", []): none when missing.
	Value towns;
	if (state.lookup(session_view::overworld(state, session), str(key::towns), towns)) {
		const int64_t town_count = ai::vsize(state, towns);
		for (int64_t index = 0; index < town_count; ++index) {
			const Value town = ai::vindex(state, towns, int_value(index));
			if (!gd::is_dict(town) || field_text(state, town.ref, key::owner, key::neutral) != key::player) {
				continue;
			}
			const DictRef projection = _project_player_town_at_daybreak(state, session, town.ref, index, next_day);
			const DictRef projected_session = gd::as_dict(state.get(projection, str(key::session), dict_value(session)));
			const DictRef projected_town = gd::as_dict(state.get(projection, str(key::town), town));
			const DictRef scaled = difficulty_rules::scale_income_resources(state, projected_session, dict_value(_calculate_town_income(state, projected_town, dict_value(projected_session))));
			town_income = _add_resource_sets(state, dict_value(town_income), dict_value(scaled));
		}
	}
	const DictRef hero_income = _player_heroes_daily_income(state, session);
	const DictRef artifact_income = gd::as_dict(field_or_new_dict(state, hero_income, key::artifact));
	const DictRef specialty_income = gd::as_dict(field_or_new_dict(state, hero_income, key::specialty));
	const DictRef site_income = difficulty_rules::scale_income_resources(state, session, dict_value(controlled_resource_site_income(state, session, key::player, next_day)));
	const DictRef with_artifacts = _add_resource_sets(state, dict_value(town_income), dict_value(artifact_income));
	const DictRef with_specialties = _add_resource_sets(state, dict_value(with_artifacts), dict_value(specialty_income));
	return _add_resource_sets(state, dict_value(with_specialties), dict_value(site_income));
}

Atom _town_strategic_summary(State &state, DictRef town) {
	const DictRef town_template = gd::content_row(state, ContentTable::Town, field_text(state, town, key::town_id, key::empty));
	const Atom summary = field_text(state, town_template, key::strategic_summary, key::empty);
	if (summary != key::empty) {
		return summary;
	}
	return field_text(state, town_template, key::identity_summary, key::empty);
}

Atom _town_identity_surface(State &state, DictRef town, const Value &session) {
	if (gd::is_empty(state, town)) {
		return key::empty;
	}
	const DictRef town_template = gd::content_row(state, ContentTable::Town, field_text(state, town, key::town_id, key::empty));
	const Atom faction_id = field_text(state, town_template, key::faction_id, key::empty);
	const DictRef faction = gd::content_row(state, ContentTable::Faction, faction_id);
	// var pillars = faction.get("design_pillars", {}): a missing one reads as {}.
	Value pillars;
	const bool has_pillars = state.lookup(faction, str(key::design_pillars), pillars);
	const Atom role = _town_strategic_role(state, town);
	std::vector<Atom> lines;
	{
		const Atom name = _town_name(state, town);
		const Atom faction_name = field_text(state, faction, key::name, faction_id != key::empty ? faction_id : key::Faction);
		const Atom role_label = _town_role_label(state, role);
		lines.push_back(gd::format(state, key::identity_s_s_s, { str(name), str(faction_name), str(role_label) }));
	}
	Atom identity = gd::strip_edges(state, field_text(state, town_template, key::identity_summary, key::empty));
	if (identity == key::empty) {
		identity = gd::strip_edges(state, field_text(state, faction, key::identity_summary, key::empty));
	}
	if (identity != key::empty) {
		lines.push_back(gd::format(state, key::town_s_2, { str(identity) }));
	}
	const Atom economy_line = _town_economy_identity_line(state, town, town_template, faction, session);
	if (economy_line != key::empty) {
		lines.push_back(economy_line);
	}
	const Atom magic_line = _town_magic_identity_line(state, town, town_template);
	if (magic_line != key::empty) {
		lines.push_back(magic_line);
	}
	const Atom strategic_summary = gd::strip_edges(state, _town_strategic_summary(state, town));
	if (strategic_summary != key::empty) {
		lines.push_back(gd::format(state, key::role_s, { str(strategic_summary) }));
	}
	if (has_pillars && gd::is_dict(pillars)) {
		const Atom map_pressure = gd::strip_edges(state, field_text(state, pillars.ref, key::map_pressure, key::empty));
		if (map_pressure != key::empty) {
			lines.push_back(gd::format(state, key::pressure_identity_s, { str(map_pressure) }));
		}
		const Atom battle_style = gd::strip_edges(state, field_text(state, pillars.ref, key::battle_style, key::empty));
		if (battle_style != key::empty) {
			lines.push_back(gd::format(state, key::strategic_cue_s, { str(battle_style) }));
		}
	}
	return join_atoms(state, key::newline, lines);
}

Atom _town_economy_identity_line(State &state, DictRef town, DictRef town_template, DictRef faction, const Value &session) {
	(void)town_template;
	std::vector<Atom> parts;
	const Atom income = _describe_resource_delta(state, dict_value(_calculate_town_income(state, town, session)));
	if (income != key::empty) {
		parts.push_back(gd::format(state, key::daily_s_2, { str(income) }));
	}
	// var pillars = faction.get("design_pillars", {}): a missing one reads as {}.
	Value pillars;
	if (state.lookup(faction, str(key::design_pillars), pillars) && gd::is_dict(pillars)) {
		const Atom economy_style = gd::strip_edges(state, field_text(state, pillars.ref, key::economy_style, key::empty));
		if (economy_style != key::empty) {
			parts.push_back(economy_style);
		}
	}
	const int64_t pressure_output = _town_pressure_output(state, town, session, state.new_dict(), -1);
	if (pressure_output > 0) {
		parts.push_back(gd::format(state, key::s_d_6, { str(to_lower_ascii(state, _town_pressure_label(state, town))), int_value(pressure_output) }));
	}
	if (parts.empty()) {
		return key::empty;
	}
	return gd::format(state, key::economy_s_2, { str(join_atoms(state, key::space_bar_space, parts)) });
}

Atom _town_magic_identity_line(State &state, DictRef town, DictRef town_template) {
	std::vector<Atom> spell_names;
	int64_t max_library_tier = 0;
	for (const Value &tier_value : gd::field_items(state, town_template, str(key::spell_library))) {
		if (!gd::is_dict(tier_value)) {
			continue;
		}
		max_library_tier = compat::engine_max<int64_t>(max_library_tier, gd::int_field(state, tier_value.ref, key::tier, 0));
		for (const Value &spell_id_value : gd::field_items(state, tier_value.ref, str(key::spell_ids))) {
			if (spell_names.size() >= 3) {
				break;
			}
			const Atom spell_id = gd::stringify(state, spell_id_value);
			const DictRef spell = gd::content_row(state, ContentTable::Spell, spell_id);
			const Atom spell_name = field_text(state, spell, key::name, spell_id);
			if (spell_name != key::empty && std::find(spell_names.begin(), spell_names.end(), spell_name) == spell_names.end()) {
				spell_names.push_back(spell_name);
			}
		}
	}
	if (max_library_tier <= 0 && spell_names.empty()) {
		return key::empty;
	}
	std::vector<Atom> parts;
	parts.push_back(gd::format(state, key::tier_d_library, { int_value(compat::engine_max<int64_t>(max_library_tier, _town_spell_tier(state, town))) }));
	if (!spell_names.empty()) {
		parts.push_back(gd::format(state, key::flavor_s, { str(join_atoms(state, key::comma_space, spell_names)) }));
	}
	return gd::format(state, key::magic_s_2, { str(join_atoms(state, key::space_bar_space, parts)) });
}

Atom _town_role_label(State &state, Atom role) {
	(void)state;
	if (role == key::capital) {
		return key::capital_anchor;
	}
	if (role == key::stronghold) {
		return key::frontier_stronghold;
	}
	return key::frontier_town;
}

ArrayRef _town_response_panel_lines(State &state, DictRef session, DictRef town) {
	const ArrayRef lines = state.new_array();
	state.append(lines, str(key::strategic_response_2));
	const DictRef logistics = _town_logistics_state(state, session, town);
	const DictRef recovery = _town_recovery_state(state, session, town, state.new_dict());
	const DictRef capital_project = _town_capital_project_state(state, town, dict_value(session), state.new_dict(), state.new_dict());
	if (gd::bool_field(state, recovery, key::active, false)) {
		state.append(lines, str(gd::format(state, key::recovery_s_2, { str(field_text(state, recovery, key::summary, key::empty)) })));
	} else {
		state.append(lines, str(gd::format(state, key::recovery_steady_d_day_relief, { int_value(gd::int_field(state, recovery, key::relief_per_day, 1)) })));
	}
	state.append(lines, str(gd::format(state, key::logistics_s_4, { str(field_text(state, logistics, key::summary, key::no_linked_routes)) })));
	const Value response_labels = nonempty_array_field(state, logistics, key::response_site_labels);
	if (response_labels.kind != Kind::Nil) {
		state.append(lines, str(gd::format(state, key::active_route_orders_s, { str(join_array(state, key::comma_space, response_labels.ref)) })));
	}
	const Value delivery_labels = nonempty_array_field(state, logistics, key::delivery_site_labels);
	if (delivery_labels.kind != Kind::Nil) {
		state.append(lines, str(gd::format(state, key::reserve_deliveries_s, { str(join_array(state, key::comma_space, delivery_labels.ref)) })));
	}
	const Value threatened_labels = nonempty_array_field(state, logistics, key::threatened_site_labels);
	if (threatened_labels.kind != Kind::Nil) {
		state.append(lines, str(gd::format(state, key::threat_lanes_s, { str(join_array(state, key::comma_space, threatened_labels.ref)) })));
	}
	const Value disrupted_labels = nonempty_array_field(state, logistics, key::disrupted_site_labels);
	if (disrupted_labels.kind != Kind::Nil) {
		state.append(lines, str(gd::format(state, key::denied_routes_s_2, { str(join_array(state, key::comma_space, disrupted_labels.ref)) })));
	}
	if (gd::bool_field(state, capital_project, key::vulnerable, false)) {
		state.append(lines, str(key::capital_project_is_vulnerable_while_chains));
	}
	const int64_t action_count = state.array_size(_town_response_actions(state, session, town));
	if (action_count > 0) {
		state.append(lines, str(gd::format(state, key::d_active_order_s_ready_response, { int_value(action_count), str(action_count == 1 ? key::empty : key::s) })));
	} else {
		state.append(lines, str(key::no_immediate_response_order_is_ready));
	}
	return lines;
}

ArrayRef _town_market_panel_lines(State &state, DictRef session, DictRef town) {
	const DictRef market = _town_market_state(state, town);
	const ArrayRef lines = state.new_array();
	state.append(lines, str(key::exchange_hall));
	if (!gd::bool_field(state, market, key::active, false)) {
		state.append(lines, str(key::no_market_square_stands_here_build));
		return lines;
	}
	const DictRef buy_rates = gd::as_dict(field_or_new_dict(state, market, key::buy_rates));
	const DictRef sell_rates = gd::as_dict(field_or_new_dict(state, market, key::sell_rates));
	state.append(lines, str(gd::format(state, key::s_buy_wood_d_gold_ore, {
			str(field_text(state, market, key::building_name, key::Market)),
			int_value(gd::int_field(state, buy_rates, key::wood, 0)),
			int_value(gd::int_field(state, buy_rates, key::ore, 0)),
			int_value(gd::int_field(state, sell_rates, key::wood, 0)),
			int_value(gd::int_field(state, sell_rates, key::ore, 0)),
	})));
	const Atom specialty_summary = field_text(state, market, key::specialty_summary, key::empty);
	if (specialty_summary != key::empty) {
		state.append(lines, str(gd::format(state, key::dash_space_s, { str(specialty_summary) })));
	}
	// session != null: a session is its view.
	const DictRef usage = _normalize_town_market_usage_state(state, field_or_new_dict(state, town, key::market_usage), ai::session_int(state, session, key::day));
	state.append(lines, str(gd::format(state, key::weekly_caps_s, { str(_market_usage_summary(state, market, usage)) })));
	const int64_t reset_day = gd::add(gd::mul(gd::int_field(state, usage, key::week, 1), 7), 1);
	Value rare_value;
	const ArrayRef rare_resources = state.lookup(market, str(key::rare_resources), rare_value) ? gd::as_array(rare_value) : state.new_array();
	if (state.array_size(rare_resources) > 0) {
		// rare_buy.min(), .max() and the same of rare_sell: Arrays of ints.
		int64_t buy_min = 0;
		int64_t buy_max = 0;
		int64_t sell_min = 0;
		int64_t sell_max = 0;
		bool first = true;
		for (const Value &resource : gd::items(state, array_value(rare_resources))) {
			const int64_t buy = gd::to_int(state, state.get(buy_rates, resource, int_value(0)));
			const int64_t sell = gd::to_int(state, state.get(sell_rates, resource, int_value(0)));
			if (first) {
				buy_min = buy_max = buy;
				sell_min = sell_max = sell;
				first = false;
				continue;
			}
			buy_min = buy < buy_min ? buy : buy_min;
			buy_max = buy > buy_max ? buy : buy_max;
			sell_min = sell < sell_min ? sell : sell_min;
			sell_max = sell > sell_max ? sell : sell_max;
		}
		const Value first_resource = state.at(rare_resources, 0);
		const int64_t buy_cap = gd::to_int(state, ai::vget(state, gd::index(state, market, str(key::buy_caps)), first_resource, int_value(0)));
		const int64_t sell_cap = gd::to_int(state, ai::vget(state, gd::index(state, market, str(key::sell_caps)), state.at(rare_resources, 0), int_value(0)));
		state.append(lines, str(gd::format(state, key::rare_resources_buy_d_d_gold, {
				int_value(buy_min),
				int_value(buy_max),
				int_value(sell_min),
				int_value(sell_max),
				int_value(buy_cap),
				int_value(sell_cap),
				int_value(reset_day),
		})));
	}
	Atom bulk_resource = field_text(state, market, key::bulk_resource, key::empty);
	const ArrayRef bulk_resources = _market_bulk_resources(state, market);
	const int64_t bulk_amount = gd::int_field(state, market, key::bulk_amount, 0);
	for (const Value &bulk_resource_value : gd::items(state, array_value(bulk_resources))) {
		bulk_resource = gd::stringify(state, bulk_resource_value);
		const DictRef bulk_buy = _market_quote_from_state(state, market, key::buy, bulk_resource, bulk_amount);
		const DictRef bulk_sell = _market_quote_from_state(state, market, key::sell, bulk_resource, bulk_amount);
		state.append(lines, str(gd::format(state, key::bulk_s_lot_buy_d_for, {
				str(bulk_resource),
				int_value(bulk_amount),
				int_value(gd::int_field(state, bulk_buy, key::gold_value, 0)),
				int_value(gd::int_field(state, bulk_sell, key::gold_value, 0)),
		})));
	}
	int64_t ready_count = 0;
	for (const Value &action : gd::items(state, array_value(_town_market_actions(state, session, town)))) {
		if (gd::is_dict(action) && !gd::bool_field(state, action.ref, key::disabled, false)) {
			ready_count = gd::add(ready_count, 1);
		}
	}
	state.append(lines, str(gd::format(state, key::d_exchange_order_s_ready, { int_value(ready_count), str(ready_count == 1 ? key::empty : key::s) })));
	return lines;
}

Atom _market_usage_summary(State &state, DictRef market_state, DictRef usage) {
	std::vector<Atom> parts;
	for (const Atom action_type : { key::buy, key::sell }) {
		const DictRef caps = dict_or_empty(state, market_state, gd::format(state, key::s_caps, { str(action_type) }));
		const DictRef bucket = dict_or_empty(state, usage, action_type);
		// OverworldRules.NORMAL_MARKET_RESOURCE_KEYS.
		std::vector<Atom> resource_parts;
		for (const Atom resource_key : { key::wood, key::ore }) {
			resource_parts.push_back(gd::format(state, key::s_d_d_3, {
					str(resource_key),
					int_value(gd::int_field(state, bucket, resource_key, 0)),
					int_value(gd::int_field(state, caps, resource_key, 0)),
			}));
		}
		parts.push_back(gd::format(state, key::s_s, { str(action_type), str(join_atoms(state, key::comma_space, resource_parts)) }));
	}
	return join_atoms(state, key::semicolon_space, parts);
}

int64_t _town_garrison_company_count(State &state, DictRef town) {
	int64_t companies = 0;
	for (const Value &stack : gd::field_items(state, town, str(key::garrison))) {
		if (gd::is_dict(stack) && gd::int_field(state, stack.ref, key::count, 0) > 0) {
			companies = gd::add(companies, 1);
		}
	}
	return companies;
}

} // namespace overworld_rules

} // namespace aurelion::rules::port
