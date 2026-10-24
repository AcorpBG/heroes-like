// MapEditorShell's rules (Phase 7, slice 7.13): the map tools: terrain paint, line, rectangle and fill,
// roads and road paths, and the property edit and
// restore commands.

#include "aurelion_rules/port/map_editor.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/session_view.hpp"

#include <cstdint>
#include <string>
#include <unordered_set>
#include <vector>

namespace aurelion::rules::port {

namespace {

namespace key = state::key;
using gd::array_value;
using gd::ArrayRef;
using gd::Atom;
using gd::bool_value;
using gd::dict_value;
using gd::DictRef;
using gd::int_value;
using gd::str;
using overworld_rules::Vector2i;
using state::Kind;
using state::State;
using state::Value;

Value tile_value(Vector2i tile) {
	return Value::of_vector2i(tile.x, tile.y);
}

// A Vector2i item or member as the struct (a typed Array[Vector2i] holds only these).
Vector2i tile_of(const Value &value) {
	if (value.kind != Kind::Vector2i) {
		throw state::ScriptError(std::string("Trying to assign a value of type '") + gd::type_name(value) + "' to a variable of type 'Vector2i'.");
	}
	return {value.vx(), value.vy()};
}

Vector2i member_tile(State &state, const Value &editor, Atom member) {
	return tile_of(gd::member(state, editor, member));
}

Atom member_string(State &state, const Value &editor, Atom member) {
	return gd::to_string(gd::member(state, editor, member));
}

void set_message(State &state, const Value &editor, Atom message) {
	gd::set_member(state, editor, key::_last_message, str(message));
}

// String(d.get(key, fallback)).
Atom string_of(State &state, DictRef dict, Atom field, Atom fallback) {
	return gd::stringify(state, gd::field_or(state, dict, field, str(fallback)));
}

// _dirty = _dirty or bool(result.get("changed", false)).
void dirty_or_changed(State &state, const Value &editor, DictRef result) {
	bool dirty = gd::to_bool(gd::member(state, editor, key::_dirty));
	if (!dirty) {
		dirty = gd::bool_field(state, result, key::changed, false);
	}
	map_editor::set_dirty(state, editor, dirty);
}

// {"ok": false, "changed": false, "message": message}.
DictRef failure(State &state, Atom message) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(false));
	state.set(result, str(key::changed), bool_value(false));
	state.set(result, str(key::message), str(message));
	return result;
}

// {"x": tile.x, "y": tile.y}.
DictRef xy_payload(State &state, Vector2i tile) {
	const DictRef payload = state.new_dict();
	state.set(payload, str(key::x), int_value(tile.x));
	state.set(payload, str(key::y), int_value(tile.y));
	return payload;
}

// d.get(key, []) where the answer is stored: the field, or a new Array.
Value field_or_new_array(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return array_value(state.new_array());
}

Atom plural_s(int64_t count) {
	return count == 1 ? Atom(key::empty) : Atom(key::s);
}

DictRef session_overworld(State &state, const Value &session) {
	return session_view::overworld(state, map_editor::session_view(state, session));
}

// `var map_data = _session.overworld.get("map", [])` then `not (map_data is Array)`.
bool session_map_is_array(State &state, const Value &session) {
	Value map_data;
	return !state.lookup(session_overworld(state, session), str(key::map), map_data) || gd::is_array(map_data);
}

// `var roads = terrain_layers.get("roads", [])` then `if not (roads is Array): roads = []`.
ArrayRef roads_of(State &state, DictRef terrain_layers) {
	Value roads;
	if (state.lookup(terrain_layers, str(key::roads), roads) && gd::is_array(roads)) {
		return roads.ref;
	}
	return state.new_array();
}

// The editor road layer of roads, appended when missing, and its tiles
// (`editor_layer.get("tiles", [])`, a new Array when that is no Array).
struct EditorRoadLayer {
	int64_t index = -1;
	DictRef layer = 0;
	ArrayRef tiles = 0;
};

EditorRoadLayer editor_road_layer(State &state, const Value &editor, ArrayRef roads) {
	int64_t index = map_editor::_editor_road_layer_index(state, editor, roads);
	if (index < 0) {
		const DictRef layer = state.new_dict();
		state.set(layer, str(key::id), str(key::editor_working_road));
		state.set(layer, str(key::overlay_id), str(key::road_dirt));
		state.set(layer, str(key::role), str(key::editor_working_copy));
		state.set(layer, str(key::tiles), array_value(state.new_array()));
		state.append(roads, dict_value(layer));
		index = state.array_size(roads) - 1;
	}
	EditorRoadLayer result;
	result.index = index;
	result.layer = gd::as_dict(state.at(roads, index));
	Value tiles;
	if (!state.lookup(result.layer, str(key::tiles), tiles) || !gd::is_array(tiles)) {
		tiles = array_value(state.new_array());
	}
	result.tiles = tiles.ref;
	return result;
}

ArrayRef new_tile_array(State &state) {
	return gd::new_typed_array(state, state::variant_type::VECTOR2I);
}

uint64_t tile_bits(Vector2i tile) {
	return static_cast<uint64_t>(static_cast<uint32_t>(tile.x)) | (static_cast<uint64_t>(static_cast<uint32_t>(tile.y)) << 32);
}

} // namespace

namespace map_editor {

void _edit_selected_object_properties(State &state, const Value &editor, Atom owner, Atom difficulty, bool collected) {
	const DictRef detail = _selected_property_object_detail(state, editor);
	if (gd::is_empty(state, detail)) {
		set_message(state, editor, key::select_a_supported_overworld_object_before);
		return;
	}
	const Atom property_name = _primary_editable_property_for_kind(state, editor, string_of(state, detail, key::kind, key::empty));
	Value previous_value;
	if (property_name != key::empty) {
		previous_value = gd::field(state, detail, property_name);
	}
	const DictRef result = _apply_object_properties(state, editor, detail, owner, difficulty, collected);
	if (gd::bool_field(state, result, key::ok, false)) {
		dirty_or_changed(state, editor, result);
		const DictRef after_detail = _object_detail_by_key(state, editor, string_of(state, detail, key::property_key, key::empty));
		const Vector2i selected = member_tile(state, editor, key::_selected_tile);
		const Vector2i tile = Vector2i::of(gd::int_field(state, detail, key::x, selected.x), gd::int_field(state, detail, key::y, selected.y));
		Value new_value;
		if (property_name != key::empty) {
			new_value = gd::field(state, after_detail, property_name);
		}
		_set_object_authoring_recap(state, editor, key::edit_property, gd::bool_field(state, result, key::changed, false), detail, after_detail, tile, tile, state.new_dict(), property_name, previous_value, new_value);
	} else {
		set_message(state, editor, string_of(state, result, key::message, key::could_not_update_selected_object_properties));
	}
}

void _fill_terrain_tool(State &state, const Value &editor) {
	const DictRef result = _fill_terrain_from_selected_tile(state, editor);
	if (gd::bool_field(state, result, key::ok, false)) {
		dirty_or_changed(state, editor, result);
	}
	set_message(state, editor, string_of(state, result, key::message, key::could_not_fill_selected_terrain_region));
}

void _restore_tile_tool(State &state, const Value &editor) {
	const DictRef result = _restore_selected_tile_from_authored(state, editor);
	if (gd::bool_field(state, result, key::ok, false)) {
		dirty_or_changed(state, editor, result);
	}
	set_message(state, editor, string_of(state, result, key::message, key::could_not_restore_selected_tile));
}

bool _apply_map_tool(State &state, const Value &editor, Vector2i tile) {
	gd::set_member(state, editor, key::_selected_tile, tile_value(tile));
	bool action_succeeded = true;
	const Atom tool = member_string(state, editor, key::_tool);
	if (tool == key::terrain) {
		action_succeeded = _paint_terrain(state, editor, tile, member_string(state, editor, key::_selected_terrain_id));
	} else if (tool == key::terrain_line) {
		action_succeeded = _terrain_line_tool_click(state, editor, tile);
	} else if (tool == key::terrain_rectangle) {
		action_succeeded = _terrain_rectangle_tool_click(state, editor, tile);
	} else if (tool == key::road) {
		action_succeeded = _toggle_road(state, editor, tile);
	} else if (tool == key::road_path) {
		action_succeeded = _road_path_tool_click(state, editor, tile);
	} else if (tool == key::hero_start) {
		action_succeeded = _set_hero_start(state, editor, tile);
	} else if (tool == key::place_object) {
		action_succeeded = _place_object(state, editor, tile);
	} else if (tool == key::remove_object) {
		action_succeeded = _remove_object(state, editor, tile);
	} else if (tool == key::move_object) {
		action_succeeded = _move_object_tool_click(state, editor, tile);
	} else if (tool == key::duplicate_object) {
		action_succeeded = _duplicate_object_tool_click(state, editor, tile);
	} else if (tool == key::retheme_object) {
		action_succeeded = _retheme_object(state, editor, tile);
	} else {
		set_message(state, editor, gd::format(state, key::inspected_tile_d_d, {int_value(tile.x), int_value(tile.y)}));
	}
	return action_succeeded;
}

bool _paint_terrain(State &state, const Value &editor, Vector2i tile, Atom terrain_id) {
	if (!_tile_in_bounds(state, editor, tile) || terrain_id == key::empty) {
		return false;
	}
	const Atom previous = _terrain_at(state, editor, tile);
	const ArrayRef paint_tiles = state.new_array();
	state.append(paint_tiles, tile_value(tile));
	const DictRef result = _apply_terrain_placement(state, editor, paint_tiles, terrain_id);
	if (!gd::bool_field(state, result, key::ok, false)) {
		set_message(state, editor, string_of(state, result, key::message, key::could_not_paint_terrain));
		return false;
	}
	if (!gd::bool_field(state, result, key::changed, false)) {
		set_message(state, editor, gd::format(state, key::tile_d_d_already_uses_s, {int_value(tile.x), int_value(tile.y), str(_terrain_label_for_id(state, editor, terrain_id))}));
		return true;
	}
	const Atom previous_label = _terrain_label_for_id(state, editor, previous);
	const Atom terrain_label = _terrain_label_for_id(state, editor, terrain_id);
	set_message(state, editor, gd::format(state, key::painted_d_d_from_s_to, {int_value(tile.x), int_value(tile.y), str(previous_label), str(terrain_label), int_value(gd::int_field(state, result, key::owner_changed_count, 0))}));
	return true;
}

DictRef _apply_terrain_placement(State &state, const Value &editor, ArrayRef paint_tiles, Atom terrain_id) {
	const Value s = session(state, editor);
	if (s.kind == Kind::Nil) {
		const DictRef result = failure(state, key::no_editor_working_copy_is_loaded_2);
		gd::set_member(state, editor, key::_last_terrain_placement_result, dict_value(result));
		return result;
	}
	const DictRef view = session_view(state, s);
	const DictRef overworld = session_view::overworld(state, view);
	Value map_data;
	if (!state.lookup(overworld, str(key::map), map_data)) {
		map_data = array_value(state.new_array());
	}
	if (!gd::is_array(map_data)) {
		const DictRef result = failure(state, key::working_copy_has_no_terrain_map);
		gd::set_member(state, editor, key::_last_terrain_placement_result, dict_value(result));
		return result;
	}
	const Vector2i map_size = overworld_rules::derive_map_size(state, view);
	const DictRef terrain_grammar = gd::content_file(state, key::terrain_grammar_path);
	const DictRef result = terrain_placement_rules::apply_paint(state, map_data.ref, map_size, terrain_id, paint_tiles, terrain_grammar, false);
	gd::set_member(state, editor, key::_last_terrain_placement_result, dict_value(result));
	if (gd::bool_field(state, result, key::ok, false)) {
		state.set(overworld, str(key::map), map_data);
		if (gd::bool_field(state, result, key::changed, false)) {
			const int64_t paint_order = gd::to_int(state, gd::member(state, editor, key::_terrain_paint_order));
			gd::set_member(state, editor, key::_terrain_paint_order, int_value(gd::add(paint_order, 1)));
			set_dirty(state, editor, true);
		}
	}
	return result;
}

DictRef _materialize_last_terrain_final_normalization(State &state, const Value &editor) {
	const Value s = session(state, editor);
	if (s.kind == Kind::Nil || gd::is_empty(state, gd::as_dict(gd::member(state, editor, key::_last_terrain_placement_result)))) {
		return gd::as_dict(gd::member(state, editor, key::_last_terrain_placement_result));
	}
	const DictRef last_result = gd::as_dict(gd::member(state, editor, key::_last_terrain_placement_result));
	if (gd::bool_field(state, last_result, key::final_normalization_deferred, false)) {
		Value map_data;
		if (!state.lookup(session_overworld(state, s), str(key::map), map_data)) {
			map_data = array_value(state.new_array());
		}
		if (gd::is_array(map_data)) {
			const Vector2i map_size = overworld_rules::derive_map_size(state, session_view(state, s));
			const DictRef terrain_grammar = gd::content_file(state, key::terrain_grammar_path);
			const DictRef payload = terrain_placement_rules::final_normalization_payload(state, map_data.ref, map_size, terrain_grammar);
			state.set(last_result, str(key::final_normalization), dict_value(payload));
			state.set(last_result, str(key::final_normalization_deferred), bool_value(false));
		}
	}
	return gd::as_dict(gd::member(state, editor, key::_last_terrain_placement_result));
}

DictRef _fill_terrain_from_selected_tile(State &state, const Value &editor) {
	return _fill_terrain_region(state, editor, member_tile(state, editor, key::_selected_tile), member_string(state, editor, key::_selected_terrain_id));
}

bool _terrain_line_tool_click(State &state, const Value &editor, Vector2i tile) {
	if (!_tile_in_bounds(state, editor, tile)) {
		return false;
	}
	if (!_has_pending_terrain_line_start(state, editor)) {
		gd::set_member(state, editor, key::_pending_terrain_line_start, tile_value(tile));
		const Atom terrain_label = _terrain_label_for_id(state, editor, member_string(state, editor, key::_selected_terrain_id));
		set_message(state, editor, gd::format(state, key::terrain_line_start_set_at_d, {int_value(tile.x), int_value(tile.y), str(key::manhattan_l_line_horizontal_first_then), str(terrain_label)}));
		return true;
	}
	const DictRef result = _apply_terrain_line(state, editor, member_tile(state, editor, key::_pending_terrain_line_start), tile, member_string(state, editor, key::_selected_terrain_id));
	if (gd::bool_field(state, result, key::ok, false)) {
		gd::set_member(state, editor, key::_pending_terrain_line_start, Value::of_vector2i(-1, -1));
		dirty_or_changed(state, editor, result);
		set_message(state, editor, string_of(state, result, key::message, key::applied_terrain_line));
	} else {
		set_message(state, editor, string_of(state, result, key::message, key::could_not_apply_terrain_line));
	}
	return gd::bool_field(state, result, key::ok, false);
}

DictRef _apply_terrain_line(State &state, const Value &editor, Vector2i start_tile, Vector2i end_tile, Atom terrain_id) {
	const Value s = session(state, editor);
	if (s.kind == Kind::Nil) {
		return failure(state, key::no_editor_working_copy_is_loaded_2);
	}
	if (!_tile_in_bounds(state, editor, start_tile) || !_tile_in_bounds(state, editor, end_tile)) {
		return failure(state, key::terrain_line_start_or_end_is);
	}
	if (terrain_id == key::empty) {
		return failure(state, key::choose_an_active_terrain_id_before);
	}
	if (!_terrain_id_in_grammar(state, editor, terrain_id)) {
		const DictRef result = failure(state, gd::format(state, key::terrain_id_s_is_not_in, {str(terrain_id)}));
		state.set(result, str(key::path_rule), str(key::manhattan_l_horizontal_then_vertical));
		state.set(result, str(key::path_rule_label), str(key::manhattan_l_line_horizontal_first_then));
		return result;
	}
	if (!session_map_is_array(state, s)) {
		return failure(state, key::working_copy_has_no_terrain_map);
	}
	const ArrayRef path_tiles = _terrain_line_tiles(state, editor, start_tile, end_tile);
	const DictRef previous_terrain_by_tile = state.new_dict();
	const int64_t path_size = state.array_size(path_tiles);
	for (int64_t index = 0; index < path_size; ++index) {
		const Vector2i tile = tile_of(state.at(path_tiles, index));
		if (!_tile_in_bounds(state, editor, tile)) {
			continue;
		}
		const Atom tile_key = _tile_key(state, editor, tile);
		state.set(previous_terrain_by_tile, str(tile_key), str(_terrain_at(state, editor, tile)));
	}
	const DictRef placement_result = _apply_terrain_placement(state, editor, path_tiles, terrain_id);
	if (!gd::bool_field(state, placement_result, key::ok, false)) {
		return placement_result;
	}
	const bool changed = gd::bool_field(state, placement_result, key::changed, false);
	const Atom active_label = _terrain_label_for_id(state, editor, terrain_id);
	const int64_t affected_count = gd::int_field(state, placement_result, key::changed_count, 0);
	const int64_t owner_write_count = gd::int_field(state, placement_result, key::owner_changed_count, 0);
	Atom message = gd::format(state, key::painted_d_terrain_line_tile_s, {
		int_value(affected_count),
		str(plural_s(affected_count)),
		str(active_label),
		str(key::manhattan_l_line_horizontal_first_then),
		int_value(start_tile.x),
		int_value(start_tile.y),
		int_value(end_tile.x),
		int_value(end_tile.y),
		int_value(owner_write_count),
	});
	if (!changed) {
		message = gd::format(state, key::terrain_line_made_no_working_copy, {
			str(active_label),
			str(key::manhattan_l_line_horizontal_first_then),
			int_value(start_tile.x),
			int_value(start_tile.y),
			int_value(end_tile.x),
			int_value(end_tile.y),
		});
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(true));
	state.set(result, str(key::changed), bool_value(changed));
	state.set(result, str(key::message), str(message));
	state.set(result, str(key::active_terrain_id), str(terrain_id));
	state.set(result, str(key::path_rule), str(key::manhattan_l_horizontal_then_vertical));
	state.set(result, str(key::path_rule_label), str(key::manhattan_l_line_horizontal_first_then));
	state.set(result, str(key::start_tile), dict_value(xy_payload(state, start_tile)));
	state.set(result, str(key::end_tile), dict_value(xy_payload(state, end_tile)));
	state.set(result, str(key::path_tiles), array_value(_tile_array_payload(state, editor, path_tiles)));
	state.set(result, str(key::changed_tiles), field_or_new_array(state, placement_result, key::changed_tiles));
	state.set(result, str(key::owner_changed_tiles), field_or_new_array(state, placement_result, key::owner_changed_tiles));
	state.set(result, str(key::previous_terrain_by_tile), dict_value(previous_terrain_by_tile));
	state.set(result, str(key::path_count), int_value(state.array_size(path_tiles)));
	state.set(result, str(key::affected_count), int_value(affected_count));
	state.set(result, str(key::owner_changed_count), int_value(owner_write_count));
	state.set(result, str(key::terrain_placement), dict_value(placement_result));
	return result;
}

ArrayRef _terrain_line_tiles(State &state, const Value &editor, Vector2i start_tile, Vector2i end_tile) {
	return _manhattan_l_path_tiles(state, editor, start_tile, end_tile);
}

bool _terrain_rectangle_tool_click(State &state, const Value &editor, Vector2i tile) {
	if (!_tile_in_bounds(state, editor, tile)) {
		return false;
	}
	if (!_has_pending_terrain_rectangle_corner(state, editor)) {
		gd::set_member(state, editor, key::_pending_terrain_rectangle_corner, tile_value(tile));
		const Atom terrain_label = _terrain_label_for_id(state, editor, member_string(state, editor, key::_selected_terrain_id));
		set_message(state, editor, gd::format(state, key::terrain_rectangle_corner_set_at_d, {int_value(tile.x), int_value(tile.y), str(key::inclusive_axis_aligned_rectangle_between_corner), str(terrain_label)}));
		return true;
	}
	const DictRef result = _apply_terrain_rectangle(state, editor, member_tile(state, editor, key::_pending_terrain_rectangle_corner), tile, member_string(state, editor, key::_selected_terrain_id));
	if (gd::bool_field(state, result, key::ok, false)) {
		gd::set_member(state, editor, key::_pending_terrain_rectangle_corner, Value::of_vector2i(-1, -1));
		dirty_or_changed(state, editor, result);
		set_message(state, editor, string_of(state, result, key::message, key::applied_terrain_rectangle));
	} else {
		set_message(state, editor, string_of(state, result, key::message, key::could_not_apply_terrain_rectangle));
	}
	return gd::bool_field(state, result, key::ok, false);
}

DictRef _apply_terrain_rectangle(State &state, const Value &editor, Vector2i corner_tile, Vector2i opposite_tile, Atom terrain_id) {
	const Value s = session(state, editor);
	if (s.kind == Kind::Nil) {
		return failure(state, key::no_editor_working_copy_is_loaded_2);
	}
	if (!_tile_in_bounds(state, editor, corner_tile) || !_tile_in_bounds(state, editor, opposite_tile)) {
		return failure(state, key::terrain_rectangle_corner_or_opposite_corner);
	}
	if (terrain_id == key::empty) {
		return failure(state, key::choose_an_active_terrain_id_before_2);
	}
	if (!_terrain_id_in_grammar(state, editor, terrain_id)) {
		const DictRef result = failure(state, gd::format(state, key::terrain_id_s_is_not_in, {str(terrain_id)}));
		state.set(result, str(key::rectangle_rule), str(key::inclusive_axis_aligned_corners));
		state.set(result, str(key::rectangle_rule_label), str(key::inclusive_axis_aligned_rectangle_between_corner));
		state.set(result, str(key::tile_order), str(key::row_major_top_left_to_bottom_right));
		return result;
	}
	if (!session_map_is_array(state, s)) {
		return failure(state, key::working_copy_has_no_terrain_map);
	}
	const ArrayRef rectangle_tiles = _terrain_rectangle_tiles(state, editor, corner_tile, opposite_tile);
	const DictRef previous_terrain_by_tile = state.new_dict();
	const int64_t rectangle_size = state.array_size(rectangle_tiles);
	for (int64_t index = 0; index < rectangle_size; ++index) {
		const Vector2i tile = tile_of(state.at(rectangle_tiles, index));
		if (!_tile_in_bounds(state, editor, tile)) {
			continue;
		}
		const Atom tile_key = _tile_key(state, editor, tile);
		state.set(previous_terrain_by_tile, str(tile_key), str(_terrain_at(state, editor, tile)));
	}
	const DictRef placement_result = _apply_terrain_placement(state, editor, rectangle_tiles, terrain_id);
	if (!gd::bool_field(state, placement_result, key::ok, false)) {
		return placement_result;
	}
	const bool changed = gd::bool_field(state, placement_result, key::changed, false);
	const Atom active_label = _terrain_label_for_id(state, editor, terrain_id);
	const int64_t affected_count = gd::int_field(state, placement_result, key::changed_count, 0);
	const int64_t owner_write_count = gd::int_field(state, placement_result, key::owner_changed_count, 0);
	Atom message = gd::format(state, key::painted_d_terrain_rectangle_tile_s, {
		int_value(affected_count),
		str(plural_s(affected_count)),
		str(active_label),
		str(key::inclusive_axis_aligned_rectangle_between_corner),
		int_value(corner_tile.x),
		int_value(corner_tile.y),
		int_value(opposite_tile.x),
		int_value(opposite_tile.y),
		int_value(owner_write_count),
	});
	if (!changed) {
		message = gd::format(state, key::terrain_rectangle_made_no_working_copy, {
			str(active_label),
			str(key::inclusive_axis_aligned_rectangle_between_corner),
			int_value(corner_tile.x),
			int_value(corner_tile.y),
			int_value(opposite_tile.x),
			int_value(opposite_tile.y),
		});
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(true));
	state.set(result, str(key::changed), bool_value(changed));
	state.set(result, str(key::message), str(message));
	state.set(result, str(key::active_terrain_id), str(terrain_id));
	state.set(result, str(key::rectangle_rule), str(key::inclusive_axis_aligned_corners));
	state.set(result, str(key::rectangle_rule_label), str(key::inclusive_axis_aligned_rectangle_between_corner));
	state.set(result, str(key::tile_order), str(key::row_major_top_left_to_bottom_right));
	state.set(result, str(key::corner_tile), dict_value(xy_payload(state, corner_tile)));
	state.set(result, str(key::opposite_tile), dict_value(xy_payload(state, opposite_tile)));
	state.set(result, str(key::bounds), dict_value(_terrain_rectangle_bounds(state, editor, corner_tile, opposite_tile)));
	state.set(result, str(key::rectangle_tiles), array_value(_tile_array_payload(state, editor, rectangle_tiles)));
	state.set(result, str(key::changed_tiles), field_or_new_array(state, placement_result, key::changed_tiles));
	state.set(result, str(key::owner_changed_tiles), field_or_new_array(state, placement_result, key::owner_changed_tiles));
	state.set(result, str(key::previous_terrain_by_tile), dict_value(previous_terrain_by_tile));
	state.set(result, str(key::rectangle_count), int_value(state.array_size(rectangle_tiles)));
	state.set(result, str(key::affected_count), int_value(affected_count));
	state.set(result, str(key::owner_changed_count), int_value(owner_write_count));
	state.set(result, str(key::terrain_placement), dict_value(placement_result));
	return result;
}

ArrayRef _terrain_rectangle_tiles(State &state, const Value &editor, Vector2i corner_tile, Vector2i opposite_tile) {
	const DictRef bounds = _terrain_rectangle_bounds(state, editor, corner_tile, opposite_tile);
	const ArrayRef tiles = new_tile_array(state);
	const int64_t max_y = gd::add(gd::int_field(state, bounds, key::max_y, 0), 1);
	for (int64_t y = gd::int_field(state, bounds, key::min_y, 0); y < max_y; ++y) {
		const int64_t max_x = gd::add(gd::int_field(state, bounds, key::max_x, 0), 1);
		for (int64_t x = gd::int_field(state, bounds, key::min_x, 0); x < max_x; ++x) {
			state.append(tiles, tile_value(Vector2i::of(x, y)));
		}
	}
	return tiles;
}

DictRef _terrain_rectangle_bounds(State &state, const Value &editor, Vector2i corner_tile, Vector2i opposite_tile) {
	(void)editor;
	const DictRef bounds = state.new_dict();
	state.set(bounds, str(key::min_x), int_value(corner_tile.x < opposite_tile.x ? corner_tile.x : opposite_tile.x));
	state.set(bounds, str(key::min_y), int_value(corner_tile.y < opposite_tile.y ? corner_tile.y : opposite_tile.y));
	state.set(bounds, str(key::max_x), int_value(corner_tile.x > opposite_tile.x ? corner_tile.x : opposite_tile.x));
	state.set(bounds, str(key::max_y), int_value(corner_tile.y > opposite_tile.y ? corner_tile.y : opposite_tile.y));
	return bounds;
}

DictRef _fill_terrain_region(State &state, const Value &editor, Vector2i start_tile, Atom terrain_id) {
	const Value s = session(state, editor);
	if (s.kind == Kind::Nil) {
		return failure(state, key::no_editor_working_copy_is_loaded_2);
	}
	if (!_tile_in_bounds(state, editor, start_tile)) {
		return failure(state, key::selected_tile_is_outside_the_map);
	}
	if (terrain_id == key::empty) {
		return failure(state, key::choose_an_active_terrain_id_before_3);
	}
	if (!_terrain_id_in_grammar(state, editor, terrain_id)) {
		return failure(state, gd::format(state, key::terrain_id_s_is_not_in, {str(terrain_id)}));
	}
	const Atom source_terrain = _terrain_at(state, editor, start_tile);
	if (source_terrain == key::empty) {
		return failure(state, key::selected_tile_has_no_terrain_to);
	}
	if (source_terrain == terrain_id) {
		const Atom terrain_label = _terrain_label_for_id(state, editor, terrain_id);
		const DictRef result = state.new_dict();
		state.set(result, str(key::ok), bool_value(true));
		state.set(result, str(key::changed), bool_value(false));
		state.set(result, str(key::message), str(gd::format(state, key::tile_d_d_already_uses_s_2, {int_value(start_tile.x), int_value(start_tile.y), str(terrain_label)})));
		state.set(result, str(key::start_tile), dict_value(xy_payload(state, start_tile)));
		state.set(result, str(key::source_terrain_id), str(source_terrain));
		state.set(result, str(key::active_terrain_id), str(terrain_id));
		state.set(result, str(key::filled_count), int_value(0));
		state.set(result, str(key::contiguity), str(key::cardinal));
		return result;
	}

	if (!session_map_is_array(state, s)) {
		return failure(state, key::working_copy_has_no_terrain_map);
	}
	// visited and frontier stay inside the call: a set of tiles (for the
	// "%d,%d" keys) and a stack of them.
	std::unordered_set<uint64_t> visited;
	std::vector<Vector2i> frontier{start_tile};
	const ArrayRef filled_tiles = new_tile_array(state);
	static constexpr Vector2i directions[4] = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}};
	while (!frontier.empty()) {
		const Vector2i tile = frontier.back();
		frontier.pop_back();
		if (!_tile_in_bounds(state, editor, tile)) {
			continue;
		}
		if (!visited.insert(tile_bits(tile)).second) {
			continue;
		}
		if (_terrain_at(state, editor, tile) != source_terrain) {
			continue;
		}
		state.append(filled_tiles, tile_value(tile));
		for (const Vector2i direction : directions) {
			const Vector2i neighbor = tile + direction;
			if (!_tile_in_bounds(state, editor, neighbor)) {
				continue;
			}
			if (visited.count(tile_bits(neighbor)) != 0) {
				continue;
			}
			if (_terrain_at(state, editor, neighbor) == source_terrain) {
				frontier.push_back(neighbor);
			}
		}
	}

	const DictRef placement_result = _apply_terrain_placement(state, editor, filled_tiles, terrain_id);
	if (!gd::bool_field(state, placement_result, key::ok, false)) {
		return placement_result;
	}
	const int64_t affected_count = gd::int_field(state, placement_result, key::changed_count, 0);
	const int64_t owner_write_count = gd::int_field(state, placement_result, key::owner_changed_count, 0);
	const int64_t filled_count = state.array_size(filled_tiles);
	const bool changed = gd::bool_field(state, placement_result, key::changed, false);
	const Atom source_label = _terrain_label_for_id(state, editor, source_terrain);
	const Atom terrain_label = _terrain_label_for_id(state, editor, terrain_id);
	const Atom message = gd::format(state, key::filled_d_contiguous_s_tile_s, {
		int_value(filled_count),
		str(source_label),
		str(plural_s(filled_count)),
		int_value(start_tile.x),
		int_value(start_tile.y),
		str(terrain_label),
		int_value(owner_write_count),
		int_value(affected_count),
		str(plural_s(affected_count)),
	});
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(true));
	state.set(result, str(key::changed), bool_value(changed));
	state.set(result, str(key::message), str(message));
	state.set(result, str(key::start_tile), dict_value(xy_payload(state, start_tile)));
	state.set(result, str(key::source_terrain_id), str(source_terrain));
	state.set(result, str(key::active_terrain_id), str(terrain_id));
	state.set(result, str(key::filled_count), int_value(state.array_size(filled_tiles)));
	state.set(result, str(key::changed_tiles), field_or_new_array(state, placement_result, key::changed_tiles));
	state.set(result, str(key::owner_changed_tiles), field_or_new_array(state, placement_result, key::owner_changed_tiles));
	state.set(result, str(key::affected_count), int_value(affected_count));
	state.set(result, str(key::owner_changed_count), int_value(owner_write_count));
	state.set(result, str(key::contiguity), str(key::cardinal));
	state.set(result, str(key::terrain_placement), dict_value(placement_result));
	return result;
}

bool _toggle_road(State &state, const Value &editor, Vector2i tile) {
	if (!_tile_in_bounds(state, editor, tile)) {
		return false;
	}
	const DictRef terrain_layers = _terrain_layers(state, editor);
	const ArrayRef roads = roads_of(state, terrain_layers);
	const bool had_road = _has_road_at(state, editor, tile);
	if (had_road) {
		const int64_t road_count = state.array_size(roads);
		for (int64_t index = 0; index < road_count; ++index) {
			const Value road = state.at(roads, index);
			if (!gd::is_dict(road)) {
				continue;
			}
			Value tiles;
			const bool has_tiles = state.lookup(road.ref, str(key::tiles), tiles);
			if (has_tiles && !gd::is_array(tiles)) {
				continue;
			}
			const ArrayRef updated_tiles = state.new_array();
			const int64_t tile_count = has_tiles ? state.array_size(tiles.ref) : 0;
			for (int64_t tile_index = 0; tile_index < tile_count; ++tile_index) {
				const Value tile_entry = state.at(tiles.ref, tile_index);
				if (gd::is_dict(tile_entry) && gd::int_field(state, tile_entry.ref, key::x, -1) == tile.x && gd::int_field(state, tile_entry.ref, key::y, -1) == tile.y) {
					continue;
				}
				state.append(updated_tiles, tile_entry);
			}
			state.set(road.ref, str(key::tiles), array_value(updated_tiles));
			state.set_at(roads, index, road);
		}
	} else {
		const EditorRoadLayer editor_layer = editor_road_layer(state, editor, roads);
		state.append(editor_layer.tiles, dict_value(xy_payload(state, tile)));
		state.set(editor_layer.layer, str(key::tiles), array_value(editor_layer.tiles));
		state.set_at(roads, editor_layer.index, dict_value(editor_layer.layer));
	}
	state.set(terrain_layers, str(key::roads), array_value(roads));
	state.set(session_overworld(state, session(state, editor)), str(key::terrain_layers), dict_value(terrain_layers));
	set_dirty(state, editor, true);
	set_message(state, editor, gd::format(state, key::s_road_at_d_d, {str(had_road ? Atom(key::Removed) : Atom(key::Added)), int_value(tile.x), int_value(tile.y)}));
	return true;
}

bool _road_path_tool_click(State &state, const Value &editor, Vector2i tile) {
	if (!_tile_in_bounds(state, editor, tile)) {
		return false;
	}
	if (!_has_pending_road_path_start(state, editor)) {
		gd::set_member(state, editor, key::_pending_road_path_start, tile_value(tile));
		set_message(state, editor, gd::format(state, key::road_path_start_set_at_d, {int_value(tile.x), int_value(tile.y), str(key::manhattan_l_path_horizontal_first_then)}));
		return true;
	}
	const DictRef result = _apply_road_path(state, editor, member_tile(state, editor, key::_pending_road_path_start), tile, key::toggle);
	if (gd::bool_field(state, result, key::ok, false)) {
		gd::set_member(state, editor, key::_pending_road_path_start, Value::of_vector2i(-1, -1));
		dirty_or_changed(state, editor, result);
		set_message(state, editor, string_of(state, result, key::message, key::applied_road_path));
	} else {
		set_message(state, editor, string_of(state, result, key::message, key::could_not_apply_road_path));
	}
	return gd::bool_field(state, result, key::ok, false);
}

DictRef _apply_road_path(State &state, const Value &editor, Vector2i start_tile, Vector2i end_tile, Atom requested_action) {
	if (session(state, editor).kind == Kind::Nil) {
		return failure(state, key::no_editor_working_copy_is_loaded_2);
	}
	if (!_tile_in_bounds(state, editor, start_tile) || !_tile_in_bounds(state, editor, end_tile)) {
		return failure(state, key::road_path_start_or_end_is);
	}
	const Atom action = requested_action != key::empty ? requested_action : Atom(key::toggle);
	if (action != key::toggle && action != key::add && action != key::remove) {
		const DictRef result = failure(state, key::road_path_action_must_be_toggle);
		state.set(result, str(key::requested_action), str(requested_action));
		state.set(result, str(key::path_rule), str(key::manhattan_l_horizontal_then_vertical));
		state.set(result, str(key::path_rule_label), str(key::manhattan_l_path_horizontal_first_then));
		return result;
	}
	const ArrayRef path_tiles = _road_path_tiles(state, editor, start_tile, end_tile);
	Atom resolved_action = action;
	if (action == key::toggle) {
		resolved_action = _all_road_path_tiles_have_roads(state, editor, path_tiles) ? Atom(key::remove) : Atom(key::add);
	}
	ArrayRef changed_tiles = 0;
	if (resolved_action == key::remove) {
		changed_tiles = _remove_road_tiles(state, editor, path_tiles);
	} else {
		changed_tiles = _add_road_tiles(state, editor, path_tiles);
	}
	const int64_t changed_count = state.array_size(changed_tiles);
	const bool changed = changed_count != 0;
	Atom verb = key::Added;
	if (resolved_action == key::remove) {
		verb = key::Removed;
	}
	Atom message = gd::format(state, key::s_d_road_tile_s_on, {
		str(verb),
		int_value(changed_count),
		str(plural_s(changed_count)),
		str(key::manhattan_l_path_horizontal_first_then),
		int_value(start_tile.x),
		int_value(start_tile.y),
		int_value(end_tile.x),
		int_value(end_tile.y),
	});
	if (!changed) {
		message = gd::format(state, key::road_path_made_no_working_copy, {
			str(key::manhattan_l_path_horizontal_first_then),
			int_value(start_tile.x),
			int_value(start_tile.y),
			int_value(end_tile.x),
			int_value(end_tile.y),
		});
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(true));
	state.set(result, str(key::changed), bool_value(changed));
	state.set(result, str(key::message), str(message));
	state.set(result, str(key::requested_action), str(action));
	state.set(result, str(key::road_path_action), str(resolved_action));
	state.set(result, str(key::path_rule), str(key::manhattan_l_horizontal_then_vertical));
	state.set(result, str(key::path_rule_label), str(key::manhattan_l_path_horizontal_first_then));
	state.set(result, str(key::start_tile), dict_value(xy_payload(state, start_tile)));
	state.set(result, str(key::end_tile), dict_value(xy_payload(state, end_tile)));
	state.set(result, str(key::path_tiles), array_value(_tile_array_payload(state, editor, path_tiles)));
	state.set(result, str(key::changed_tiles), array_value(_tile_array_payload(state, editor, changed_tiles)));
	state.set(result, str(key::path_count), int_value(state.array_size(path_tiles)));
	state.set(result, str(key::affected_count), int_value(changed_count));
	return result;
}

ArrayRef _road_path_tiles(State &state, const Value &editor, Vector2i start_tile, Vector2i end_tile) {
	return _manhattan_l_path_tiles(state, editor, start_tile, end_tile);
}

ArrayRef _manhattan_l_path_tiles(State &state, const Value &editor, Vector2i start_tile, Vector2i end_tile) {
	(void)editor;
	const ArrayRef tiles = new_tile_array(state);
	Vector2i cursor = start_tile;
	state.append(tiles, tile_value(cursor));
	while (cursor.x != end_tile.x) {
		cursor.x = static_cast<int32_t>(end_tile.x > cursor.x ? cursor.x + 1 : cursor.x - 1);
		state.append(tiles, tile_value(cursor));
	}
	while (cursor.y != end_tile.y) {
		cursor.y = static_cast<int32_t>(end_tile.y > cursor.y ? cursor.y + 1 : cursor.y - 1);
		state.append(tiles, tile_value(cursor));
	}
	return tiles;
}

bool _all_road_path_tiles_have_roads(State &state, const Value &editor, ArrayRef path_tiles) {
	const int64_t path_size = state.array_size(path_tiles);
	if (path_size == 0) {
		return false;
	}
	for (int64_t index = 0; index < path_size; ++index) {
		if (!_has_road_at(state, editor, tile_of(state.at(path_tiles, index)))) {
			return false;
		}
	}
	return true;
}

ArrayRef _add_road_tiles(State &state, const Value &editor, ArrayRef path_tiles) {
	const DictRef terrain_layers = _terrain_layers(state, editor);
	const ArrayRef roads = roads_of(state, terrain_layers);
	const DictRef existing_keys = _road_tile_keys_from_layers(state, editor, roads);
	const ArrayRef tiles_to_add = new_tile_array(state);
	const int64_t path_size = state.array_size(path_tiles);
	for (int64_t index = 0; index < path_size; ++index) {
		const Vector2i tile = tile_of(state.at(path_tiles, index));
		const Value tile_key = str(_tile_key(state, editor, tile));
		if (state.has(existing_keys, tile_key)) {
			continue;
		}
		state.set(existing_keys, tile_key, bool_value(true));
		state.append(tiles_to_add, tile_value(tile));
	}
	const int64_t add_count = state.array_size(tiles_to_add);
	if (add_count == 0) {
		return new_tile_array(state);
	}
	const EditorRoadLayer editor_layer = editor_road_layer(state, editor, roads);
	for (int64_t index = 0; index < add_count; ++index) {
		const Vector2i tile = tile_of(state.at(tiles_to_add, index));
		state.append(editor_layer.tiles, dict_value(xy_payload(state, tile)));
	}
	state.set(editor_layer.layer, str(key::tiles), array_value(editor_layer.tiles));
	state.set_at(roads, editor_layer.index, dict_value(editor_layer.layer));
	state.set(terrain_layers, str(key::roads), array_value(roads));
	state.set(session_overworld(state, session(state, editor)), str(key::terrain_layers), dict_value(terrain_layers));
	return tiles_to_add;
}

ArrayRef _remove_road_tiles(State &state, const Value &editor, ArrayRef path_tiles) {
	const DictRef terrain_layers = _terrain_layers(state, editor);
	// Roads that are no Array answer []; a missing "roads" is the fallback's
	// empty Array, which removes nothing and answers [] too.
	Value roads_value;
	if (!state.lookup(terrain_layers, str(key::roads), roads_value) || !gd::is_array(roads_value)) {
		return new_tile_array(state);
	}
	const ArrayRef roads = roads_value.ref;
	// path_keys and removed_keys stay inside the call: sets of the "%d,%d" keys.
	std::unordered_set<Atom> path_keys;
	const int64_t path_size = state.array_size(path_tiles);
	for (int64_t index = 0; index < path_size; ++index) {
		path_keys.insert(_tile_key(state, editor, tile_of(state.at(path_tiles, index))));
	}
	std::unordered_set<Atom> removed_keys;
	const int64_t road_count = state.array_size(roads);
	for (int64_t index = 0; index < road_count; ++index) {
		const Value road = state.at(roads, index);
		if (!gd::is_dict(road)) {
			continue;
		}
		Value tiles;
		const bool has_tiles = state.lookup(road.ref, str(key::tiles), tiles);
		if (has_tiles && !gd::is_array(tiles)) {
			continue;
		}
		const ArrayRef updated_tiles = state.new_array();
		const int64_t tile_count = has_tiles ? state.array_size(tiles.ref) : 0;
		for (int64_t tile_index = 0; tile_index < tile_count; ++tile_index) {
			const Value tile_entry = state.at(tiles.ref, tile_index);
			if (!gd::is_dict(tile_entry)) {
				state.append(updated_tiles, tile_entry);
				continue;
			}
			const Vector2i tile = Vector2i::of(gd::int_field(state, tile_entry.ref, key::x, -1), gd::int_field(state, tile_entry.ref, key::y, -1));
			const Atom tile_key = _tile_key(state, editor, tile);
			if (path_keys.count(tile_key) != 0) {
				removed_keys.insert(tile_key);
				continue;
			}
			state.append(updated_tiles, tile_entry);
		}
		state.set(road.ref, str(key::tiles), array_value(updated_tiles));
		state.set_at(roads, index, road);
	}
	if (removed_keys.empty()) {
		return new_tile_array(state);
	}
	state.set(terrain_layers, str(key::roads), array_value(roads));
	state.set(session_overworld(state, session(state, editor)), str(key::terrain_layers), dict_value(terrain_layers));
	const ArrayRef removed_tiles = new_tile_array(state);
	for (int64_t index = 0; index < path_size; ++index) {
		const Vector2i tile = tile_of(state.at(path_tiles, index));
		if (removed_keys.count(_tile_key(state, editor, tile)) != 0) {
			state.append(removed_tiles, tile_value(tile));
		}
	}
	return removed_tiles;
}

DictRef _road_tile_keys_from_layers(State &state, const Value &editor, ArrayRef roads) {
	(void)editor;
	const DictRef keys = state.new_dict();
	const int64_t road_count = state.array_size(roads);
	for (int64_t index = 0; index < road_count; ++index) {
		const Value road = state.at(roads, index);
		if (!gd::is_dict(road)) {
			continue;
		}
		Value tiles;
		if (!state.lookup(road.ref, str(key::tiles), tiles) || !gd::is_array(tiles)) {
			continue;
		}
		const int64_t tile_count = state.array_size(tiles.ref);
		for (int64_t tile_index = 0; tile_index < tile_count; ++tile_index) {
			const Value tile_entry = state.at(tiles.ref, tile_index);
			if (gd::is_dict(tile_entry)) {
				const std::string tile_key = gd::format_pair(gd::int_field(state, tile_entry.ref, key::x, -1), gd::int_field(state, tile_entry.ref, key::y, -1));
				state.set(keys, state.string(tile_key), bool_value(true));
			}
		}
	}
	return keys;
}

bool _has_pending_terrain_line_start(State &state, const Value &editor) {
	const Vector2i start = member_tile(state, editor, key::_pending_terrain_line_start);
	return start.x >= 0 && start.y >= 0 && _tile_in_bounds(state, editor, start);
}

DictRef _pending_terrain_line_start_payload(State &state, const Value &editor) {
	if (!_has_pending_terrain_line_start(state, editor)) {
		return state.new_dict();
	}
	return xy_payload(state, member_tile(state, editor, key::_pending_terrain_line_start));
}

bool _has_pending_terrain_rectangle_corner(State &state, const Value &editor) {
	const Vector2i corner = member_tile(state, editor, key::_pending_terrain_rectangle_corner);
	return corner.x >= 0 && corner.y >= 0 && _tile_in_bounds(state, editor, corner);
}

DictRef _pending_terrain_rectangle_corner_payload(State &state, const Value &editor) {
	if (!_has_pending_terrain_rectangle_corner(state, editor)) {
		return state.new_dict();
	}
	return xy_payload(state, member_tile(state, editor, key::_pending_terrain_rectangle_corner));
}

bool _has_pending_road_path_start(State &state, const Value &editor) {
	const Vector2i start = member_tile(state, editor, key::_pending_road_path_start);
	return start.x >= 0 && start.y >= 0 && _tile_in_bounds(state, editor, start);
}

DictRef _pending_road_path_start_payload(State &state, const Value &editor) {
	if (!_has_pending_road_path_start(state, editor)) {
		return state.new_dict();
	}
	return xy_payload(state, member_tile(state, editor, key::_pending_road_path_start));
}

ArrayRef _tile_array_payload(State &state, const Value &editor, ArrayRef tiles) {
	(void)editor;
	const ArrayRef payload = state.new_array();
	const int64_t tile_count = state.array_size(tiles);
	for (int64_t index = 0; index < tile_count; ++index) {
		const Vector2i tile = tile_of(state.at(tiles, index));
		state.append(payload, dict_value(xy_payload(state, tile)));
	}
	return payload;
}

int64_t _editor_road_layer_index(State &state, const Value &editor, ArrayRef roads) {
	(void)editor;
	const int64_t road_count = state.array_size(roads);
	for (int64_t index = 0; index < road_count; ++index) {
		const Value road = state.at(roads, index);
		if (gd::is_dict(road) && gd::stringify(state, gd::field_or(state, road.ref, key::id, str(key::empty))) == key::editor_working_road) {
			return index;
		}
	}
	return -1;
}

} // namespace map_editor

} // namespace aurelion::rules::port
