// MapEditorShell's rules (Phase 7, slice 7.13): opening and resuming a working copy, the labels'
// texts, the tool, and writing a package copy.

#include "aurelion_rules/port/map_editor.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/overworld_level_rules.hpp"
#include "aurelion_rules/port/scenario_select_rules_setup.hpp"
#include "aurelion_rules/port/session_state_store.hpp"
#include "aurelion_rules/port/session_view.hpp"

#include <string>
#include <string_view>
#include <vector>

namespace aurelion::rules::port::map_editor {

namespace {

using state::Kind;
namespace key = state::key;

void put(State &state, DictRef dict, Atom name, const Value &value) {
	state.set(dict, gd::str(name), value);
}

// String(x): the engine's for a float or a container.
Atom string_of(State &state, const Value &value) {
	switch (value.kind) {
		case Kind::Nil:
		case Kind::Bool:
		case Kind::Int:
		case Kind::String:
		case Kind::StringName:
			return gd::stringify(state, value);
		default:
			return gd::engine_str(state, value);
	}
}

// String(d.get(name, fallback)).
Atom string_get(State &state, DictRef dict, Atom name, const Value &fallback) {
	return string_of(state, state.get(dict, gd::str(name), fallback));
}

// String(payload.get("text", "")).strip_edges().
Atom payload_text(State &state, DictRef payload) {
	return gd::strip_edges(state, string_get(state, payload, key::text, gd::str(key::empty)));
}

// session.scenario_id (a String var of SessionData); null.scenario_id is a ScriptError.
Atom scenario_id_of(State &state, const Value &session) {
	return gd::to_string(gd::member(state, session, key::scenario_id));
}

// session.flags (a Dictionary var of SessionData).
DictRef flags_of(State &state, const Value &session) {
	return gd::as_dict(gd::member(state, session, key::flags));
}

// self._x of a Vector2i var.
Vector2i tile_member(State &state, const Value &editor, Atom name) {
	const Value value = gd::member(state, editor, name);
	if (!gd::is_vector2i(value)) {
		throw state::ScriptError("MapEditorShell." + state.text(name) + " is no Vector2i");
	}
	return Vector2i::of(value.vx(), value.vy());
}

void set_tile_member(State &state, const Value &editor, Atom name, Vector2i tile) {
	gd::set_member(state, editor, name, Value::of_vector2i(tile.x, tile.y));
}

void set_string_member(State &state, const Value &editor, Atom name, Atom text) {
	gd::set_member(state, editor, name, gd::str(text));
}

Atom string_member(State &state, const Value &editor, Atom name) {
	return gd::to_string(gd::member(state, editor, name));
}

// SessionState.editor_package_identity(session), a static func called on the autoload.
DictRef editor_package_identity(State &state, const Value &session) {
	return gd::as_dict(gd::call_method(state, gd::autoload(state, key::SessionState), key::editor_package_identity,
			{ session_object(state, session) }));
}

// ProjectSettings.globalize_path(path).
Value globalize_path(State &state, Atom path) {
	return gd::call_method(state, gd::engine_singleton(state, key::ProjectSettings), key::globalize_path, { gd::str(path) });
}

// text.trim_suffix(suffix).
Atom trim_suffix(State &state, Atom text, Atom suffix) {
	if (!gd::ends_with(state, text, suffix)) {
		return text;
	}
	const std::string &whole = state.text(text);
	return state.intern(std::string_view(whole).substr(0, whole.size() - state.text(suffix).size()));
}

// "\n".join(lines) of Strings.
Atom join_lines(State &state, const std::vector<Atom> &lines) {
	std::string joined;
	for (size_t index = 0; index < lines.size(); ++index) {
		if (index > 0) {
			joined += "\n";
		}
		joined += state.text(lines[index]);
	}
	return state.intern(joined);
}

// A Dictionary value's field, or a new empty Dictionary when it is no Dictionary
// (`d.get(k, {}) if d.get(k, {}) is Dictionary else {}`).
DictRef dict_field_or_new(State &state, DictRef dict, Atom name) {
	Value found;
	if (state.lookup(dict, gd::str(name), found) && gd::is_dict(found)) {
		return found.ref;
	}
	return state.new_dict();
}

} // namespace

bool _open_maps_folder_package_entry(State &state, const Value &editor, DictRef entry) {
	const Atom package_id = string_get(state, entry, key::package_id, gd::str(key::empty));
	const DictRef options = state.new_dict();
	put(state, options, key::startup_source, gd::str(key::map_editor_maps_folder));
	put(state, options, key::session_id_prefix, gd::str(key::editor_maps_folder_package));
	put(state, options, key::consumer, gd::str(key::map_editor));
	const Value loaded = scenario_select_rules::load_maps_folder_package_session_from_entry(state, entry, key::normal, options);
	if (loaded.kind == Kind::Nil || scenario_id_of(state, loaded) == key::empty) {
		set_string_member(state, editor, key::_last_message, gd::format(state, key::unable_to_load_package_s_into, { gd::str(package_id) }));
		return false;
	}
	const Atom level_block = _editor_level_support_block_message(state, editor, loaded,
			string_get(state, entry, key::display_name, gd::str(package_id)));
	if (level_block != key::empty) {
		set_string_member(state, editor, key::_last_message, level_block);
		return false;
	}
	gd::call_method(state, gd::autoload(state, key::SessionState), key::set_editor_working_copy_session, { Value() });
	set_session(state, editor, loaded);
	const Value working = session(state, editor);
	const DictRef flags = flags_of(state, working);
	const Value stored_entry = state.get(flags, gd::str(key::maps_folder_package_entry), gd::dict_value(entry));
	if (gd::is_dict(stored_entry)) {
		entry = stored_entry.ref;
	}
	put(state, flags, key::editor_source_kind, gd::str(key::maps_folder_package));
	put(state, flags, key::editor_source_package_id, gd::str(package_id));
	put(state, flags, key::editor_source_display_name, gd::str(string_get(state, entry, key::display_name, gd::str(package_id))));
	put(state, flags, key::editor_source_map_path, gd::str(string_get(state, entry, key::map_path, gd::str(key::empty))));
	put(state, flags, key::editor_source_scenario_path, gd::str(string_get(state, entry, key::scenario_path, gd::str(key::empty))));
	gd::set_member(state, editor, key::_authored_baseline_cache, _duplicate_session(state, editor, session(state, editor)));
	set_string_member(state, editor, key::_authored_baseline_cache_id, scenario_id_of(state, session(state, editor)));
	overworld_rules::normalize_overworld_state(state, session_view(state, session(state, editor)));
	_make_all_tiles_visible(state, editor, session(state, editor));
	set_string_member(state, editor, key::_selected_map_package_id, package_id);
	set_tile_member(state, editor, key::_selected_tile, overworld_rules::hero_position(state, session_view(state, session(state, editor))));
	set_string_member(state, editor, key::_selected_property_object_key, key::empty);
	set_string_member(state, editor, key::_pending_move_object_key, key::empty);
	set_string_member(state, editor, key::_pending_duplicate_object_key, key::empty);
	set_tile_member(state, editor, key::_pending_terrain_line_start, Vector2i::of(-1, -1));
	set_tile_member(state, editor, key::_pending_terrain_rectangle_corner, Vector2i::of(-1, -1));
	set_tile_member(state, editor, key::_pending_road_path_start, Vector2i::of(-1, -1));
	gd::set_member(state, editor, key::_terrain_paint_order, gd::int_value(0));
	set_dirty(state, editor, false);
	gd::set_member(state, editor, key::_restored_from_play_copy, gd::bool_value(false));
	set_string_member(state, editor, key::_last_message, key::loaded_editor_package_into_a_mutable);
	return true;
}

Atom _editor_level_support_block_message(State &state, const Value &editor, const Value &session, Atom label) {
	(void)editor;
	// OverworldLevelRules.level_count(null) is 1.
	const int64_t level_count = session.kind == Kind::Nil ? 1 : overworld_level_rules::level_count(state, session_view(state, session));
	if (level_count <= 1) {
		return key::empty;
	}
	return gd::format(state, key::s_has_d_map_levels_the, { gd::str(label), gd::int_value(level_count) });
}

Value _duplicate_session(State &state, const Value &editor, const Value &session) {
	(void)editor;
	if (session.kind == Kind::Nil || scenario_id_of(state, session) == key::empty) {
		return Value();
	}
	const Value copy = session_state_store::new_session_data(state, key::empty, key::empty, key::empty, 1, state.new_dict(), key::normal,
			key::campaign);
	const Value payload = gd::call_method(state, session_object(state, session), key::to_dict, {});
	gd::call_method(state, copy, key::from_dict, { gd::dict_value(gd::as_dict(payload)) });
	return copy;
}

bool _resume_working_copy_session(State &state, const Value &editor, const Value &session, const Value &baseline_session, DictRef package_identity) {
	if (session.kind == Kind::Nil || scenario_id_of(state, session) == key::empty) {
		return false;
	}
	const DictRef session_package_identity = editor_package_identity(state, session);
	const bool package_companion_present = !gd::is_empty(state, package_identity) || baseline_session.kind != Kind::Nil;
	const bool has_identity = !gd::is_empty(state, session_package_identity);
	if ((has_identity
				&& (gd::is_empty(state, package_identity) || baseline_session.kind == Kind::Nil
						|| scenario_id_of(state, baseline_session) != scenario_id_of(state, session)
						|| !gd::equal(state, gd::dict_value(session_package_identity), gd::dict_value(package_identity))
						|| !gd::equal(state, gd::dict_value(editor_package_identity(state, baseline_session)), gd::dict_value(package_identity))))
			|| (!has_identity && package_companion_present)) {
		return false;
	}
	const Value resumed_session = has_identity ? _duplicate_session(state, editor, session) : session;
	const Value resumed_baseline = has_identity ? _duplicate_session(state, editor, baseline_session) : Value();
	if (resumed_session.kind == Kind::Nil || (has_identity && resumed_baseline.kind == Kind::Nil)) {
		return false;
	}
	set_session(state, editor, resumed_session);
	gd::set_member(state, editor, key::_authored_baseline_cache, Value());
	set_string_member(state, editor, key::_authored_baseline_cache_id, key::empty);
	if (has_identity) {
		gd::set_member(state, editor, key::_authored_baseline_cache, session_object(state, resumed_baseline));
		set_string_member(state, editor, key::_authored_baseline_cache_id, scenario_id_of(state, map_editor::session(state, editor)));
	} else {
		overworld_rules::normalize_overworld_state(state, session_view(state, map_editor::session(state, editor)));
		_make_all_tiles_visible(state, editor, map_editor::session(state, editor));
	}
	set_string_member(state, editor, key::_selected_map_package_id,
			string_get(state, flags_of(state, map_editor::session(state, editor)), key::editor_source_package_id, gd::str(key::empty)));
	return true;
}

void _make_all_tiles_visible(State &state, const Value &editor, const Value &session) {
	(void)editor;
	const DictRef view = session_view(state, session);
	const Vector2i map_size = overworld_rules::derive_map_size(state, view);
	const ArrayRef visible_tiles = state.new_array();
	const ArrayRef explored_tiles = state.new_array();
	for (int64_t y = 0; y < map_size.y; ++y) {
		const ArrayRef visible_row = state.new_array();
		const ArrayRef explored_row = state.new_array();
		for (int64_t x = 0; x < map_size.x; ++x) {
			state.append(visible_row, gd::bool_value(true));
			state.append(explored_row, gd::bool_value(true));
		}
		state.append(visible_tiles, gd::array_value(visible_row));
		state.append(explored_tiles, gd::array_value(explored_row));
	}
	const int64_t tile_count = gd::mul(map_size.x, map_size.y);
	const DictRef fog = state.new_dict();
	put(state, fog, key::visible_tiles, gd::array_value(visible_tiles));
	put(state, fog, key::explored_tiles, gd::array_value(explored_tiles));
	put(state, fog, key::visible_count, gd::int_value(tile_count));
	put(state, fog, key::explored_count, gd::int_value(tile_count));
	put(state, fog, key::total_tiles, gd::int_value(tile_count));
	put(state, session_view::overworld(state, view), key::fog, gd::dict_value(fog));
}

DictRef _editor_label_texts(State &state, const Value &editor) {
	if (session(state, editor).kind == Kind::Nil) {
		std::vector<Atom> empty_lines;
		const Atom load_handoff = payload_text(state, _editor_map_load_handoff_payload(state, editor));
		if (load_handoff != key::empty) {
			empty_lines.push_back(load_handoff);
		}
		const DictRef index_status = gd::as_dict(gd::member(state, editor, key::_map_package_index_status));
		const Atom index_message = gd::strip_edges(state, string_get(state, index_status, key::message, gd::str(key::empty)));
		if (index_message != key::empty) {
			empty_lines.push_back(index_message);
		}
		// warnings: the Array there, or [] (missing or no Array).
		Value warnings;
		const bool has_warnings = state.lookup(index_status, gd::str(key::warnings), warnings) && gd::is_array(warnings)
				&& state.array_size(warnings.ref) > 0;
		const int64_t unpaired_count = gd::add(gd::int_field(state, index_status, key::unpaired_map_count, 0),
				gd::int_field(state, index_status, key::unpaired_scenario_count, 0));
		if (has_warnings || unpaired_count > 0) {
			empty_lines.push_back(key::invalid_map_package_pairs_were_skipped);
		}
		const Atom last_message = string_member(state, editor, key::_last_message);
		if (last_message != key::empty) {
			empty_lines.push_back(last_message);
		}
		const DictRef result = state.new_dict();
		put(state, result, key::header, gd::str(key::map_editor_2));
		put(state, result, key::tile_info, gd::str(key::no_map_package_loaded));
		put(state, result, key::tile_info_lines, gd::int_value(4));
		put(state, result, key::status, gd::str(join_lines(state, empty_lines)));
		put(state, result, key::status_lines, gd::int_value(3));
		return result;
	}
	const Vector2i map_size = overworld_rules::derive_map_size(state, session_view(state, session(state, editor)));
	const Atom tool_label = _tool_label(state, editor, string_member(state, editor, key::_tool));
	const Atom terrain_label = _terrain_label_for_id(state, editor, string_member(state, editor, key::_selected_terrain_id));
	const int64_t road_tile_count = _road_tile_count(state, editor);
	Atom state_line = gd::format(state, key::working_copy_dx_d_tool_s,
			{ gd::int_value(map_size.x), gd::int_value(map_size.y), gd::str(tool_label), gd::str(terrain_label), gd::int_value(road_tile_count) });
	const int64_t placement_count = _placement_count(state, editor);
	const Atom family_label = _object_family_label(state, editor, string_member(state, editor, key::_selected_object_family));
	state_line = gd::format(state, key::s_objects_d_palette_s_s,
			{ gd::str(state_line), gd::int_value(placement_count), gd::str(family_label), gd::member(state, editor, key::_selected_object_content_id) });
	if (gd::truthy(state, gd::member(state, editor, key::_dirty))) {
		state_line = gd::format(state, key::s_unsaved_in_memory, { gd::str(state_line) });
	}
	if (gd::truthy(state, gd::member(state, editor, key::_placement_debug_overlay_enabled))) {
		state_line = gd::format(state, key::s_f4_blockers, { gd::str(state_line) });
	}
	const DictRef authoring_validation = _scenario_authoring_validation_payload(state, editor);
	const int64_t authoring_warning_count = gd::int_field(state, authoring_validation, key::warning_count, 0);
	if (authoring_warning_count > 0) {
		state_line = gd::format(state, key::s_authoring_warnings_d, { gd::str(state_line), gd::int_value(authoring_warning_count) });
	}
	if (string_member(state, editor, key::_pending_move_object_key) != key::empty) {
		const DictRef pending_detail = _object_detail_by_key(state, editor, string_member(state, editor, key::_pending_move_object_key));
		state_line = gd::format(state, key::s_move_s,
				{ gd::str(state_line), gd::str(string_get(state, pending_detail, key::placement_id, gd::member(state, editor, key::_pending_move_object_key))) });
	}
	if (string_member(state, editor, key::_pending_duplicate_object_key) != key::empty) {
		const DictRef pending_duplicate_detail = _object_detail_by_key(state, editor, string_member(state, editor, key::_pending_duplicate_object_key));
		state_line = gd::format(state, key::s_duplicate_s,
				{ gd::str(state_line),
						gd::str(string_get(state, pending_duplicate_detail, key::placement_id, gd::member(state, editor, key::_pending_duplicate_object_key))) });
	}
	if (_has_pending_terrain_line_start(state, editor)) {
		const Vector2i start = tile_member(state, editor, key::_pending_terrain_line_start);
		state_line = gd::format(state, key::s_terrain_line_start_d_d, { gd::str(state_line), gd::int_value(start.x), gd::int_value(start.y) });
	}
	if (_has_pending_terrain_rectangle_corner(state, editor)) {
		const Vector2i corner = tile_member(state, editor, key::_pending_terrain_rectangle_corner);
		state_line = gd::format(state, key::s_terrain_rectangle_corner_d_d, { gd::str(state_line), gd::int_value(corner.x), gd::int_value(corner.y) });
	}
	if (_has_pending_road_path_start(state, editor)) {
		const Vector2i start = tile_member(state, editor, key::_pending_road_path_start);
		state_line = gd::format(state, key::s_road_path_start_d_d, { gd::str(state_line), gd::int_value(start.x), gd::int_value(start.y) });
	}
	std::vector<Atom> status_lines{ state_line };
	const auto append_text = [&](DictRef payload) {
		const Atom text = payload_text(state, payload);
		if (text != key::empty) {
			status_lines.push_back(text);
		}
	};
	append_text(_editor_map_load_handoff_payload(state, editor));
	append_text(_editor_scenario_validation_check_payload(state, editor));
	append_text(_editor_selected_validation_focus_payload(state, editor));
	append_text(_editor_active_tool_cue_payload(state, editor, key::empty));
	Atom tool = string_member(state, editor, key::_tool);
	if (tool == key::terrain || tool == key::terrain_line || tool == key::terrain_rectangle) {
		append_text(_editor_terrain_paint_check_payload(state, editor, key::empty));
	}
	tool = string_member(state, editor, key::_tool);
	if (tool == key::road || tool == key::road_path) {
		append_text(_editor_road_check_payload(state, editor, key::empty));
	}
	append_text(_editor_restore_tile_cue_payload(state, editor));
	if (string_member(state, editor, key::_tool) == key::place_object) {
		append_text(_editor_object_preview_check_payload(state, editor));
		append_text(_editor_placement_action_cue_payload(state, editor));
	}
	append_text(_editor_play_return_context_payload(state, editor));
	append_text(_editor_play_readiness_gate_payload(state, editor));
	append_text(_editor_play_handoff_payload(state, editor));
	append_text(_editor_acceptance_cue_payload(state, editor));
	const Atom last_message = string_member(state, editor, key::_last_message);
	if (last_message != key::empty) {
		status_lines.push_back(last_message);
	}
	const Atom header = gd::format(state, key::map_editor_s, { gd::str(_current_scenario_display_name(state, editor)) });
	const Atom tile_info = _tile_inspection_text(state, editor, tile_member(state, editor, key::_selected_tile));
	const DictRef result = state.new_dict();
	put(state, result, key::header, gd::str(header));
	put(state, result, key::tile_info, gd::str(tile_info));
	put(state, result, key::tile_info_lines, gd::int_value(12));
	put(state, result, key::status, gd::str(join_lines(state, status_lines)));
	put(state, result, key::status_lines, gd::int_value(4));
	return result;
}

Atom _current_scenario_display_name(State &state, const Value &editor) {
	const Value working = session(state, editor);
	if (working.kind == Kind::Nil) {
		return key::empty;
	}
	const Atom package_display = gd::strip_edges(state, string_get(state, flags_of(state, working), key::editor_source_display_name, gd::str(key::empty)));
	if (package_display != key::empty) {
		return package_display;
	}
	const DictRef scenario = gd::content_row(state, state::ContentTable::Scenario, scenario_id_of(state, working));
	return string_get(state, scenario, key::name, gd::member(state, working, key::scenario_id));
}

Atom _selected_map_package_label(State &state, const Value &editor) {
	return _map_package_label_for_id(state, editor, string_member(state, editor, key::_selected_map_package_id));
}

Atom _map_package_label_for_id(State &state, const Value &editor, Atom package_id) {
	if (package_id == key::empty) {
		return key::empty;
	}
	const ArrayRef entries = gd::as_array(gd::member(state, editor, key::_map_package_entries));
	for (int64_t index = 0; index < state.array_size(entries); ++index) {
		const Value entry = state.at(entries, index);
		if (!gd::is_dict(entry)) {
			continue;
		}
		if (string_get(state, entry.ref, key::package_id, gd::str(key::empty)) == package_id) {
			const Value stem = state.get(entry.ref, gd::str(key::package_stem), gd::str(package_id));
			return string_get(state, entry.ref, key::display_name, stem);
		}
	}
	return package_id;
}

Atom _tool_label(State &state, const Value &editor, Atom tool) {
	(void)state;
	(void)editor;
	if (tool == key::terrain) {
		return key::Terrain;
	}
	if (tool == key::terrain_line) {
		return key::terrain_line_2;
	}
	if (tool == key::terrain_rectangle) {
		return key::terrain_rect;
	}
	if (tool == key::road) {
		return key::Road;
	}
	if (tool == key::road_path) {
		return key::road_path_2;
	}
	if (tool == key::hero_start) {
		return key::hero_start_3;
	}
	if (tool == key::place_object) {
		return key::place_object_2;
	}
	if (tool == key::remove_object) {
		return key::remove_object_2;
	}
	if (tool == key::move_object) {
		return key::move_object_2;
	}
	if (tool == key::duplicate_object) {
		return key::duplicate_object_2;
	}
	if (tool == key::retheme_object) {
		return key::retheme_object_2;
	}
	return key::Inspect;
}

void _set_tool(State &state, const Value &editor, Atom tool) {
	const bool valid = tool == key::inspect || tool == key::terrain || tool == key::terrain_line || tool == key::terrain_rectangle
			|| tool == key::road || tool == key::road_path || tool == key::hero_start || tool == key::place_object
			|| tool == key::remove_object || tool == key::move_object || tool == key::duplicate_object || tool == key::retheme_object;
	set_string_member(state, editor, key::_tool, valid ? tool : key::inspect);
	const Atom current = string_member(state, editor, key::_tool);
	if (current != key::move_object) {
		set_string_member(state, editor, key::_pending_move_object_key, key::empty);
	}
	if (current != key::duplicate_object) {
		set_string_member(state, editor, key::_pending_duplicate_object_key, key::empty);
	}
	if (current != key::terrain_line) {
		set_tile_member(state, editor, key::_pending_terrain_line_start, Vector2i::of(-1, -1));
	}
	if (current != key::terrain_rectangle) {
		set_tile_member(state, editor, key::_pending_terrain_rectangle_corner, Vector2i::of(-1, -1));
	}
	if (current != key::road_path) {
		set_tile_member(state, editor, key::_pending_road_path_start, Vector2i::of(-1, -1));
	}
}

DictRef _write_package_copy(State &state, const Value &editor, Atom target_dir_override, Atom target_stem_override) {
	if (session(state, editor).kind == Kind::Nil
			|| string_get(state, flags_of(state, session(state, editor)), key::editor_source_kind, gd::str(key::empty)) != key::maps_folder_package) {
		return _save_copy_failure(state, editor, key::package_working_copy_required, key::load_a_map_package_working_copy_4, state.new_array(),
				state.new_dict());
	}
	const DictRef contract = _save_copy_draft_payload(state, editor);
	if (!gd::bool_field(state, contract, key::ready, false)) {
		const DictRef details = state.new_dict();
		put(state, details, key::blockers, state.get(contract, gd::str(key::blockers), gd::array_value(state.new_array())));
		return _save_copy_failure(state, editor, key::draft_validation_failed, key::resolve_editor_validation_blockers_before_saving,
				state.new_array(), details);
	}
	// ClassDB.class_exists("MapPackageService") and ClassDB.instantiate(...): null when the class is missing.
	const Value service = scenario_select_rules::_native_map_package_service(state);
	if (service.kind == Kind::Nil) {
		return _save_copy_failure(state, editor, key::native_service_unavailable, key::native_map_package_persistence_is_unavailable,
				state.new_array(), state.new_dict());
	}
	if (!gd::in(state, gd::str(key::legacy_scenario_record_conversion), gd::call_method(state, service, key::get_capabilities, {}))) {
		return _save_copy_failure(state, editor, key::native_conversion_unavailable, key::native_scenario_conversion_is_unavailable,
				state.new_array(), state.new_dict());
	}
	Atom target_dir = gd::strip_edges(state, target_dir_override);
	if (target_dir == key::empty) {
		target_dir = string_get(state, scenario_select_rules::generated_map_package_directory_policy(state), key::active_dir, gd::str(key::user_maps));
	}
	const int64_t mkdir_error = gd::to_int(state,
			gd::class_call_static(state, key::DirAccess, key::make_dir_recursive_absolute, { globalize_path(state, target_dir) }));
	if (mkdir_error != 0) {
		const DictRef details = state.new_dict();
		put(state, details, key::error, gd::int_value(mkdir_error));
		put(state, details, key::target_dir, gd::str(target_dir));
		return _save_copy_failure(state, editor, key::target_directory_failed, key::could_not_create_the_map_package, state.new_array(), details);
	}
	const DictRef source_entry = dict_field_or_new(state, flags_of(state, session(state, editor)), key::maps_folder_package_entry);
	const Atom source_stem = string_get(state, source_entry, key::package_stem, gd::member(state, session(state, editor), key::scenario_id));
	Atom requested_stem = gd::strip_edges(state, target_stem_override);
	if (requested_stem == key::empty) {
		requested_stem = gd::format(state, key::s_copy, { gd::str(source_stem) });
	}
	const Atom base_stem = scenario_select_rules::safe_maps_folder_package_stem(state, requested_stem);
	const Atom target_stem = _unique_package_copy_stem(state, editor, target_dir, base_stem);
	const Atom map_path = gd::format(state, key::s_s_amap, { gd::str(trim_suffix(state, target_dir, key::slash)), gd::str(target_stem) });
	const Atom scenario_path = gd::format(state, key::s_s_ascenario, { gd::str(trim_suffix(state, target_dir, key::slash)), gd::str(target_stem) });
	const ArrayRef output_paths = state.new_array();
	state.append(output_paths, gd::str(map_path));
	state.append(output_paths, gd::str(scenario_path));
	const DictRef draft = dict_field_or_new(state, contract, key::draft);
	const DictRef scenario_record = gd::as_dict(
			gd::engine_duplicate(state, state.get(draft, gd::str(key::scenario_record), gd::dict_value(state.new_dict())), true));
	const DictRef terrain_layers_record = gd::as_dict(
			gd::engine_duplicate(state, state.get(draft, gd::str(key::terrain_layers_record), gd::dict_value(state.new_dict())), true));
	const Value display_fallback = state.get(source_entry, gd::str(key::display_name), gd::member(state, session(state, editor), key::scenario_id));
	Atom display_name = gd::strip_edges(state, string_get(state, scenario_record, key::name, display_fallback));
	if (!gd::ends_with(state, display_name, key::copy)) {
		display_name = gd::format(state, key::s_copy_2, { gd::str(display_name) });
	}
	put(state, scenario_record, key::name, gd::str(display_name));
	const DictRef conversion_options = state.new_dict();
	put(state, conversion_options, key::map_id, gd::str(gd::format(state, key::s_map, { gd::str(target_stem) })));
	put(state, conversion_options, key::scenario_id, gd::str(target_stem));
	const DictRef conversion = gd::as_dict(gd::call_method(state, service, key::convert_legacy_scenario_record,
			{ gd::dict_value(scenario_record), gd::dict_value(terrain_layers_record), gd::dict_value(conversion_options) }));
	if (!gd::bool_field(state, conversion, key::ok, false)) {
		const DictRef details = state.new_dict();
		put(state, details, key::conversion, gd::dict_value(conversion));
		return _save_copy_failure(state, editor, key::conversion_failed, key::the_editor_working_copy_could_not, output_paths, details);
	}
	const Value map_document = state.get(conversion, gd::str(key::map_document), Value());
	const Value scenario_document = state.get(conversion, gd::str(key::scenario_document), Value());
	if (map_document.kind == Kind::Nil || scenario_document.kind == Kind::Nil) {
		return _save_copy_failure(state, editor, key::conversion_missing_documents, key::native_conversion_did_not_return_package, output_paths,
				state.new_dict());
	}
	const DictRef save_options = state.new_dict();
	put(state, save_options, key::path_policy, gd::str(key::editor_non_overwriting_package_copy));
	put(state, save_options, key::return_package, gd::bool_value(false));
	const DictRef map_save = gd::as_dict(
			gd::call_method(state, service, key::save_map_package, { map_document, gd::str(map_path), gd::dict_value(save_options) }));
	if (!gd::bool_field(state, map_save, key::ok, false)) {
		const DictRef details = state.new_dict();
		put(state, details, key::map_save, gd::dict_value(map_save));
		return _save_copy_failure(state, editor, key::map_save_failed, key::the_map_package_copy_could_not, output_paths, details);
	}
	const DictRef map_load = gd::as_dict(gd::call_method(state, service, key::load_map_package, { gd::str(map_path) }));
	if (!gd::bool_field(state, map_load, key::ok, false)) {
		const DictRef details = state.new_dict();
		put(state, details, key::map_load, gd::dict_value(map_load));
		return _save_copy_failure(state, editor, key::map_reload_failed, key::the_written_map_package_could_not, output_paths, details);
	}
	const DictRef configuration = state.new_dict();
	put(state, configuration, key::scenario_id, gd::call_method(state, scenario_document, key::get_scenario_id, {}));
	put(state, configuration, key::scenario_hash, gd::call_method(state, scenario_document, key::get_scenario_hash, {}));
	put(state, configuration, key::map_ref, state.get(map_load, gd::str(key::map_ref), gd::dict_value(state.new_dict())));
	put(state, configuration, key::selection, gd::call_method(state, scenario_document, key::get_selection, {}));
	put(state, configuration, key::player_slots, gd::call_method(state, scenario_document, key::get_player_slots, {}));
	put(state, configuration, key::objectives, gd::call_method(state, scenario_document, key::get_objectives, {}));
	put(state, configuration, key::script_hooks, gd::call_method(state, scenario_document, key::get_script_hooks, {}));
	put(state, configuration, key::enemy_factions, gd::call_method(state, scenario_document, key::get_enemy_factions, {}));
	put(state, configuration, key::start_contract, gd::call_method(state, scenario_document, key::get_start_contract, {}));
	gd::call_method(state, scenario_document, key::configure, { gd::dict_value(configuration) });
	const DictRef scenario_save = gd::as_dict(
			gd::call_method(state, service, key::save_scenario_package, { scenario_document, gd::str(scenario_path), gd::dict_value(save_options) }));
	if (!gd::bool_field(state, scenario_save, key::ok, false)) {
		const DictRef details = state.new_dict();
		put(state, details, key::scenario_save, gd::dict_value(scenario_save));
		return _save_copy_failure(state, editor, key::scenario_save_failed, key::the_scenario_package_copy_could_not, output_paths, details);
	}
	const DictRef scenario_load = gd::as_dict(gd::call_method(state, service, key::load_scenario_package, { gd::str(scenario_path) }));
	if (!gd::bool_field(state, scenario_load, key::ok, false)) {
		const DictRef details = state.new_dict();
		put(state, details, key::scenario_load, gd::dict_value(scenario_load));
		return _save_copy_failure(state, editor, key::scenario_reload_failed, key::the_written_scenario_package_could_not, output_paths, details);
	}
	const Value loaded_map = state.get(map_load, gd::str(key::map_document), Value());
	const Value loaded_scenario = state.get(scenario_load, gd::str(key::scenario_document), Value());
	const DictRef map_validation = gd::as_dict(gd::call_method(state, service, key::validate_map_document, { loaded_map }));
	const DictRef scenario_validation = gd::as_dict(gd::call_method(state, service, key::validate_scenario_document, { loaded_scenario, loaded_map }));
	if (!gd::bool_field(state, map_validation, key::ok, false) || !gd::bool_field(state, scenario_validation, key::ok, false)) {
		const DictRef details = state.new_dict();
		put(state, details, key::map_validation, gd::dict_value(map_validation));
		put(state, details, key::scenario_validation, gd::dict_value(scenario_validation));
		return _save_copy_failure(state, editor, key::saved_pair_validation_failed, key::the_written_package_pair_failed_structural, output_paths,
				details);
	}
	const DictRef index_options = state.new_dict();
	put(state, index_options, key::package_dir, gd::str(target_dir));
	put(state, index_options, key::include_non_launchable_generated_packages, gd::bool_value(true));
	put(state, index_options, key::consumer, gd::str(key::map_editor));
	const DictRef index = scenario_select_rules::maps_folder_package_index(state, index_options);
	DictRef saved_entry = state.new_dict();
	for (const Value &entry_value : gd::field_items(state, index, gd::str(key::entries))) {
		if (gd::is_dict(entry_value) && string_get(state, entry_value.ref, key::package_stem, gd::str(key::empty)) == target_stem) {
			saved_entry = entry_value.ref;
			break;
		}
	}
	if (gd::is_empty(state, saved_entry)) {
		const DictRef details = state.new_dict();
		put(state, details, key::index, gd::dict_value(index));
		return _save_copy_failure(state, editor, key::saved_pair_adoption_failed, key::the_saved_package_pair_could_not, output_paths, details);
	}
	const DictRef result = state.new_dict();
	put(state, result, key::ok, gd::bool_value(true));
	put(state, result, key::saved_entry, gd::dict_value(saved_entry));
	put(state, result, key::index, gd::dict_value(index));
	put(state, result, key::output_paths, gd::array_value(output_paths));
	put(state, result, key::target_dir, gd::str(target_dir));
	put(state, result, key::target_stem, gd::str(target_stem));
	put(state, result, key::map_path, gd::str(map_path));
	put(state, result, key::scenario_path, gd::str(scenario_path));
	put(state, result, key::loaded_map, loaded_map);
	put(state, result, key::loaded_scenario, loaded_scenario);
	return result;
}

DictRef _finish_package_copy(State &state, const Value &editor, DictRef written) {
	const DictRef saved_entry = gd::as_dict(gd::index(state, written, gd::str(key::saved_entry)));
	const Value loaded_map = gd::index(state, written, gd::str(key::loaded_map));
	const Value loaded_scenario = gd::index(state, written, gd::str(key::loaded_scenario));
	set_dirty(state, editor, false);
	gd::set_member(state, editor, key::_authored_baseline_cache, _duplicate_session(state, editor, session(state, editor)));
	set_string_member(state, editor, key::_authored_baseline_cache_id, scenario_id_of(state, session(state, editor)));
	const DictRef result = state.new_dict();
	put(state, result, key::ok, gd::bool_value(true));
	put(state, result, key::status, gd::str(key::saved_copy));
	put(state, result, key::package_id, gd::str(string_get(state, saved_entry, key::package_id, gd::str(key::empty))));
	put(state, result, key::package_stem, gd::str(string_of(state, gd::index(state, written, gd::str(key::target_stem)))));
	put(state, result, key::target_dir, gd::str(string_of(state, gd::index(state, written, gd::str(key::target_dir)))));
	put(state, result, key::map_path, gd::str(string_of(state, gd::index(state, written, gd::str(key::map_path)))));
	put(state, result, key::scenario_path, gd::str(string_of(state, gd::index(state, written, gd::str(key::scenario_path)))));
	put(state, result, key::map_hash, gd::call_method(state, loaded_map, key::get_map_hash, {}));
	put(state, result, key::scenario_hash, gd::call_method(state, loaded_scenario, key::get_scenario_hash, {}));
	put(state, result, key::object_count, gd::call_method(state, loaded_map, key::get_object_count, {}));
	put(state, result, key::player_slot_count, gd::int_value(ai::vsize(state, gd::call_method(state, loaded_scenario, key::get_player_slots, {}))));
	put(state, result, key::source_unchanged_by_policy, gd::bool_value(true));
	put(state, result, key::authored_json_writeback, gd::bool_value(false));
	put(state, result, key::editor_inspection_only, gd::bool_value(gd::bool_field(state, saved_entry, key::editor_inspection_only, false)));
	gd::set_member(state, editor, key::_last_save_copy_result, gd::engine_duplicate(state, gd::dict_value(result), true));
	set_string_member(state, editor, key::_last_message,
			gd::format(state, key::saved_s_as_a_new_map, { gd::str(string_of(state, gd::index(state, written, gd::str(key::target_stem)))) }));
	return result;
}

Atom _unique_package_copy_stem(State &state, const Value &editor, Atom target_dir, Atom base_stem) {
	(void)editor;
	int64_t suffix = 1;
	Atom candidate = base_stem;
	while (gd::file_exists(state, gd::format(state, key::s_s_amap, { gd::str(trim_suffix(state, target_dir, key::slash)), gd::str(candidate) }))
			|| gd::file_exists(state, gd::format(state, key::s_s_ascenario, { gd::str(trim_suffix(state, target_dir, key::slash)), gd::str(candidate) }))) {
		suffix = gd::add(suffix, 1);
		candidate = gd::format(state, key::s_d_5, { gd::str(base_stem), gd::int_value(suffix) });
	}
	return candidate;
}

DictRef _save_copy_failure(State &state, const Value &editor, Atom code, Atom message, ArrayRef cleanup_paths, DictRef details) {
	for (int64_t index = 0; index < state.array_size(cleanup_paths); ++index) {
		const Atom path = string_of(state, state.at(cleanup_paths, index));
		if (gd::file_exists(state, path)) {
			gd::class_call_static(state, key::DirAccess, key::remove_absolute, { globalize_path(state, path) });
		}
	}
	const DictRef result = state.new_dict();
	put(state, result, key::ok, gd::bool_value(false));
	put(state, result, key::status, gd::str(key::failed));
	put(state, result, key::error_code, gd::str(code));
	put(state, result, key::message, gd::str(message));
	put(state, result, key::partial_outputs_removed, gd::bool_value(true));
	gd::merge(state, result, details, true);
	gd::set_member(state, editor, key::_last_save_copy_result, gd::engine_duplicate(state, gd::dict_value(result), true));
	set_string_member(state, editor, key::_last_message, message);
	return result;
}

} // namespace aurelion::rules::port::map_editor
