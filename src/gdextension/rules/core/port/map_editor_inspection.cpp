// MapEditorShell's rules (Phase 7, slice 7.13): the active tool cue, the play preparation, the tile
// inspection, object details, ids and the small
// tile and road helpers.

#include "aurelion_rules/port/map_editor.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/overworld_rules_ai.hpp"
#include "aurelion_rules/port/overworld_rules_panels.hpp"
#include "aurelion_rules/port/session_view.hpp"

#include <algorithm>
#include <set>
#include <string>
#include <utility>
#include <vector>

namespace aurelion::rules::port::map_editor {

namespace key = state::key;
using gd::array_value;
using gd::bool_value;
using gd::dict_value;
using gd::int_value;
using gd::str;
using state::ContentTable;
using state::Kind;

namespace {

// The bytes of the UTF-8 character that starts with lead.
size_t utf8_sequence_length(unsigned char lead) {
	if (lead < 0x80) {
		return 1;
	}
	if ((lead >> 5) == 0x6) {
		return 2;
	}
	if ((lead >> 4) == 0xE) {
		return 3;
	}
	if ((lead >> 3) == 0x1E) {
		return 4;
	}
	return 1;
}

// String(x) of any value: the engine's text for a float, a vector or a container.
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

// String(d.get(field, fallback)).
Atom text_or(State &state, DictRef dict, Atom field, Atom fallback) {
	return string_of(state, state.get(dict, str(field), str(fallback)));
}

// A String member of the screen.
Atom member_text(State &state, const Value &editor, Atom member) {
	return gd::to_string(gd::member(state, editor, member));
}

// A Vector2i member of the screen.
Vector2i member_tile(State &state, const Value &editor, Atom member) {
	const Value tile = gd::member(state, editor, member);
	if (tile.kind != Kind::Vector2i) {
		throw state::ScriptError(std::string("MapEditorShell: the member ") + state.text(member) + " is no Vector2i");
	}
	return Vector2i::of(tile.vx(), tile.vy());
}

// {"x": x, "y": y}.
DictRef tile_dict(State &state, int64_t x, int64_t y) {
	const DictRef payload = state.new_dict();
	state.set(payload, str(key::x), int_value(x));
	state.set(payload, str(key::y), int_value(y));
	return payload;
}

// A session value where an earlier port takes a view or Nil.
Value view_or_nil(State &state, const Value &session_value) {
	return session_value.kind == Kind::Nil ? Value() : dict_value(session_view(state, session_value));
}

// _session.overworld.
DictRef working_overworld(State &state, const Value &editor) {
	return port::session_view::overworld(state, session_view(state, session(state, editor)));
}

// What `for x in value` visits, copied: the bodies call on.
std::vector<Value> item_values(State &state, const Value &container) {
	const gd::Items items = gd::items(state, container);
	return std::vector<Value>(items.begin(), items.end());
}

// var x: Array = dict.get(field, []), for a list only read: false when the
// field is missing (the empty fallback).
bool array_field(State &state, DictRef dict, Atom field, ArrayRef &out, const char *where) {
	Value found;
	if (!state.lookup(dict, str(field), found)) {
		return false;
	}
	out = ai::typed_array(found, where);
	return true;
}

// x.get(field, <fallback>) of an untyped value whose fallback is only read:
// false when x is a Dictionary without the field. Anything but a Dictionary
// has no get() (ai::vget's ScriptError).
bool untyped_lookup(State &state, const Value &object, Atom field, Value &found) {
	if (!gd::is_dict(object)) {
		found = ai::vget(state, object, field, Value());
		return true;
	}
	return state.lookup(object.ref, str(field), found);
}

// text.to_lower() of ASCII text (the family labels).
Atom to_lower_ascii(State &state, Atom text, const char *where) {
	std::string lowered = state.text(text);
	for (char &c : lowered) {
		const unsigned char byte = static_cast<unsigned char>(c);
		if (byte >= 0x80) {
			throw state::NotPorted(std::string(where) + ": to_lower() of non-ASCII text");
		}
		if (byte >= 'A' && byte <= 'Z') {
			c = static_cast<char>(byte - 'A' + 'a');
		}
	}
	return state.intern(lowered);
}

// text.substr(0, 1).to_upper() + text.substr(1) of a text that starts with
// an ASCII character (the tool cue's actions).
Atom upper_first(State &state, Atom text, const char *where) {
	std::string result = state.text(text);
	if (result.empty()) {
		return text;
	}
	const unsigned char byte = static_cast<unsigned char>(result[0]);
	if (byte >= 0x80) {
		throw state::NotPorted(std::string(where) + ": to_upper() of a non-ASCII character");
	}
	if (byte >= 'a' && byte <= 'z') {
		result[0] = static_cast<char>(byte - 'a' + 'A');
	}
	return state.intern(result);
}

// text.left(count): the first count characters.
Atom left_chars(State &state, Atom text, size_t count) {
	const std::string source = state.text(text);
	size_t at = 0;
	size_t taken = 0;
	while (at < source.size() && taken < count) {
		at += std::min(utf8_sequence_length(static_cast<unsigned char>(source[at])), source.size() - at);
		++taken;
	}
	if (at >= source.size()) {
		return text;
	}
	return state.intern(source.substr(0, at));
}

// character.to_lower() of one character: ASCII letters, and the two
// characters outside ASCII the engine lowers to ASCII (U+0130 to "i", U+212A
// to "k"); every other character stays outside ASCII.
std::string lower_character(const std::string &character) {
	if (character.size() == 1) {
		const unsigned char byte = static_cast<unsigned char>(character[0]);
		if (byte >= 'A' && byte <= 'Z') {
			return std::string(1, static_cast<char>(byte - 'A' + 'a'));
		}
		return character;
	}
	if (character == "\xC4\xB0") {
		return "i";
	}
	if (character == "\xE2\x84\xAA") {
		return "k";
	}
	return character;
}

// separator.join(parts) of an Array of Strings.
Atom join_values(State &state, Atom separator, ArrayRef parts) {
	std::string joined;
	const int64_t size = state.array_size(parts);
	for (int64_t index = 0; index < size; ++index) {
		if (index > 0) {
			joined += state.text(separator);
		}
		joined += state.text(string_of(state, state.at(parts, index)));
	}
	return state.intern(joined);
}

// separator.join(parts) of Strings.
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

// for raw_line in text.split("\n"): var line := String(raw_line).strip_edges();
// if line != "": lines.append("  %s" % line).
void append_stripped_lines(State &state, ArrayRef lines, Atom text) {
	const std::string source = state.text(text);
	size_t start = 0;
	for (;;) {
		const size_t end = source.find('\n', start);
		const std::string piece = source.substr(start, end == std::string::npos ? std::string::npos : end - start);
		const Atom line = gd::strip_edges(state, state.intern(piece));
		if (line != key::empty) {
			state.append(lines, str(gd::format(state, key::s_10, { str(line) })));
		}
		if (end == std::string::npos) {
			break;
		}
		start = end + 1;
	}
}

// for value in _session.overworld.get(array_key, []): if value is Dictionary
// and _placement_at_tile(value, tile): details.append(...) (_object_details_at).
void append_family_details(State &state, const Value &editor, ArrayRef details, DictRef overworld, Atom array_key, Atom family, Vector2i tile) {
	Value placements;
	if (!state.lookup(overworld, str(array_key), placements)) {
		return;
	}
	for (const Value &value : item_values(state, placements)) {
		if (gd::is_dict(value) && _placement_at_tile(state, editor, value.ref, tile)) {
			const DictRef detail = _object_detail_for_placement(state, editor, family, value.ref);
			state.append(details, dict_value(_object_detail_with_guidance(state, editor, detail, tile)));
		}
	}
}

// _generate_editor_placement_id and _generate_duplicate_placement_id: the
// first of base_id, base_id_2, ... that no placement has.
Atom unused_placement_id(State &state, const Value &editor, Atom base_id) {
	Atom candidate = base_id;
	int64_t suffix = 2;
	while (_placement_id_exists(state, editor, candidate)) {
		candidate = gd::format(state, key::s_d_4, { str(base_id), int_value(suffix) });
		suffix = gd::add(suffix, 1);
	}
	return candidate;
}

constexpr Atom kObjectFamilies[] = { key::town, key::resource, key::artifact, key::encounter };

} // namespace

DictRef _editor_active_tool_cue_payload(State &state, const Value &editor, Atom tool) {
	constexpr const char *where = "MapEditorShell._editor_active_tool_cue_payload";
	const Atom tool_id = tool == key::empty ? member_text(state, editor, key::_tool) : tool;
	const Vector2i selected_tile = member_tile(state, editor, key::_selected_tile);
	const Atom selected_text = state.intern(gd::format_pair(selected_tile.x, selected_tile.y));
	Atom hovered_text = key::none;
	{
		const Vector2i hovered_tile = member_tile(state, editor, key::_hovered_tile);
		if (_tile_in_bounds(state, editor, hovered_tile)) {
			hovered_text = state.intern(gd::format_pair(hovered_tile.x, hovered_tile.y));
		}
	}
	Atom action = key::empty;
	Atom next_step = key::empty;
	Atom detail = key::empty;
	if (tool_id == key::terrain) {
		action = gd::format(state, key::paint_s_terrain, { str(_terrain_label_for_id(state, editor, member_text(state, editor, key::_selected_terrain_id))) });
		next_step = key::click_a_map_tile_to_apply;
		detail = gd::format(state, key::brush_s, { str(_terrain_label_for_id(state, editor, member_text(state, editor, key::_selected_terrain_id))) });
	} else if (tool_id == key::terrain_line) {
		action = gd::format(state, key::paint_a_s_terrain_line, { str(_terrain_label_for_id(state, editor, member_text(state, editor, key::_selected_terrain_id))) });
		if (_has_pending_terrain_line_start(state, editor)) {
			const Vector2i start = member_tile(state, editor, key::_pending_terrain_line_start);
			next_step = gd::format(state, key::click_the_line_end_start_is, { int_value(start.x), int_value(start.y) });
		} else {
			next_step = key::click_the_first_line_tile;
		}
		detail = key::manhattan_l_line_horizontal_first_then;
	} else if (tool_id == key::terrain_rectangle) {
		action = gd::format(state, key::paint_a_s_terrain_rectangle, { str(_terrain_label_for_id(state, editor, member_text(state, editor, key::_selected_terrain_id))) });
		if (_has_pending_terrain_rectangle_corner(state, editor)) {
			const Vector2i corner = member_tile(state, editor, key::_pending_terrain_rectangle_corner);
			next_step = gd::format(state, key::click_the_opposite_corner_first_corner, { int_value(corner.x), int_value(corner.y) });
		} else {
			next_step = key::click_the_first_rectangle_corner;
		}
		detail = key::inclusive_axis_aligned_rectangle_between_corner;
	} else if (tool_id == key::road) {
		action = key::toggle_the_editor_road_overlay;
		next_step = key::click_a_map_tile_to_add;
		detail = gd::format(state, key::road_layer_s, { str(key::editor_working_road) });
	} else if (tool_id == key::road_path) {
		action = key::paint_a_road_path;
		if (_has_pending_road_path_start(state, editor)) {
			const Vector2i start = member_tile(state, editor, key::_pending_road_path_start);
			next_step = gd::format(state, key::click_the_path_end_start_is, { int_value(start.x), int_value(start.y) });
		} else {
			next_step = key::click_the_first_path_tile;
		}
		detail = key::manhattan_l_path_horizontal_first_then;
	} else if (tool_id == key::hero_start) {
		action = key::move_the_playable_hero_start;
		next_step = key::click_the_new_starting_tile;
		const Value working_copy = session(state, editor);
		const Vector2i hero_position = working_copy.kind != Kind::Nil
				? overworld_rules::hero_position(state, session_view(state, working_copy))
				: member_tile(state, editor, key::_selected_tile);
		detail = gd::format(state, key::current_hero_start_d_d, { int_value(hero_position.x), int_value(hero_position.y) });
	} else if (tool_id == key::place_object) {
		const Atom family_label = to_lower_ascii(state, _object_family_label(state, editor, member_text(state, editor, key::_selected_object_family)), where);
		const Atom content_label = _selected_object_content_label(state, editor);
		action = gd::format(state, key::place_s_s, { str(family_label), str(content_label) });
		next_step = key::click_a_valid_map_tile_or;
		detail = gd::format(state, key::palette_s_s, { str(_object_family_label(state, editor, member_text(state, editor, key::_selected_object_family))), str(member_text(state, editor, key::_selected_object_content_id)) });
	} else if (tool_id == key::remove_object) {
		action = key::remove_an_object_from_the_selected;
		next_step = gd::format(state, key::click_a_tile_containing_a_s, { str(to_lower_ascii(state, _object_family_label(state, editor, member_text(state, editor, key::_selected_object_family)), where)) });
		detail = gd::format(state, key::family_s, { str(_object_family_label(state, editor, member_text(state, editor, key::_selected_object_family))) });
	} else if (tool_id == key::move_object) {
		action = key::move_an_existing_object;
		if (member_text(state, editor, key::_pending_move_object_key) != key::empty) {
			const DictRef move_detail = _object_detail_by_key(state, editor, member_text(state, editor, key::_pending_move_object_key));
			next_step = gd::format(state, key::click_the_destination_for_s, { str(text_or(state, move_detail, key::placement_id, member_text(state, editor, key::_pending_move_object_key))) });
		} else {
			next_step = key::click_an_object_to_pick_it;
		}
		detail = gd::format(state, key::family_s, { str(_object_family_label(state, editor, member_text(state, editor, key::_selected_object_family))) });
	} else if (tool_id == key::duplicate_object) {
		action = key::duplicate_an_existing_object;
		if (member_text(state, editor, key::_pending_duplicate_object_key) != key::empty) {
			const DictRef duplicate_detail = _object_detail_by_key(state, editor, member_text(state, editor, key::_pending_duplicate_object_key));
			next_step = gd::format(state, key::click_the_destination_for_a_copy, { str(text_or(state, duplicate_detail, key::placement_id, member_text(state, editor, key::_pending_duplicate_object_key))) });
		} else {
			next_step = key::click_an_object_to_copy_it;
		}
		detail = gd::format(state, key::family_s, { str(_object_family_label(state, editor, member_text(state, editor, key::_selected_object_family))) });
	} else if (tool_id == key::retheme_object) {
		action = gd::format(state, key::replace_an_object_s_content_with, { str(_selected_object_content_label(state, editor)) });
		next_step = key::click_a_matching_object_to_retheme;
		detail = gd::format(state, key::palette_s_s, { str(_object_family_label(state, editor, member_text(state, editor, key::_selected_object_family))), str(member_text(state, editor, key::_selected_object_content_id)) });
	} else {
		action = key::inspect_map_content;
		next_step = key::click_a_tile_to_show_terrain;
		detail = key::read_only_selection;
	}
	const Atom action_sentence = upper_first(state, action, where);
	const Atom text = gd::format(state, key::tool_cue_selected_s_s_next, { str(selected_text), str(action_sentence), str(next_step), str(detail) });
	const DictRef payload = state.new_dict();
	state.set(payload, str(key::tool), str(tool_id));
	state.set(payload, str(key::label), str(_tool_label(state, editor, tool_id)));
	state.set(payload, str(key::text), str(text));
	const Atom tooltip_label = _tool_label(state, editor, tool_id);
	state.set(payload, str(key::tooltip), str(gd::format(state, key::active_tool_s_s_selected_s, { str(tooltip_label), str(text), str(selected_text), str(hovered_text), str(detail) })));
	state.set(payload, str(key::action), str(action));
	state.set(payload, str(key::next_step_2), str(next_step));
	const Vector2i payload_selected = member_tile(state, editor, key::_selected_tile);
	state.set(payload, str(key::selected_tile), dict_value(tile_dict(state, payload_selected.x, payload_selected.y)));
	const Vector2i payload_hovered = member_tile(state, editor, key::_hovered_tile);
	const DictRef hovered = _tile_in_bounds(state, editor, payload_hovered) ? tile_dict(state, payload_hovered.x, payload_hovered.y) : state.new_dict();
	state.set(payload, str(key::hovered_tile), dict_value(hovered));
	state.set(payload, str(key::detail), str(detail));
	return payload;
}

Atom _selected_object_content_label(State &state, const Value &editor) {
	if (member_text(state, editor, key::_selected_object_content_id) == key::empty) {
		return key::selected_content;
	}
	const DictRef entry = _object_content_lookup(state, editor, member_text(state, editor, key::_selected_object_family), member_text(state, editor, key::_selected_object_content_id));
	if (gd::is_empty(state, entry)) {
		return member_text(state, editor, key::_selected_object_content_id);
	}
	return text_or(state, entry, key::name, member_text(state, editor, key::_selected_object_content_id));
}

void _prepare_working_copy_snapshot_for_return(State &state, const Value &editor) {
	const DictRef view = session_view(state, session(state, editor));
	const DictRef flags = gd::as_dict(gd::index(state, view, str(key::flags)));
	state.set(flags, str(key::editor_working_copy), bool_value(true));
	state.set(flags, str(key::editor_source_scenario_id), gd::index(state, view, str(key::scenario_id)));
	state.set(flags, str(key::editor_return_model), str(key::launch_snapshot));
	state.set(flags, str(key::editor_dirty), gd::member(state, editor, key::_dirty));
	const Vector2i selected_tile = member_tile(state, editor, key::_selected_tile);
	state.set(flags, str(key::editor_selected_tile), dict_value(tile_dict(state, selected_tile.x, selected_tile.y)));
	state.set(flags, str(key::editor_selected_terrain_id), gd::member(state, editor, key::_selected_terrain_id));
	state.set(flags, str(key::editor_selected_object_family), gd::member(state, editor, key::_selected_object_family));
	state.set(flags, str(key::editor_selected_object_content_id), gd::member(state, editor, key::_selected_object_content_id));
	state.set(flags, str(key::editor_selected_property_object_key), gd::member(state, editor, key::_selected_property_object_key));
	state.set(flags, str(key::editor_pending_move_object_key), gd::member(state, editor, key::_pending_move_object_key));
	state.set(flags, str(key::editor_pending_duplicate_object_key), gd::member(state, editor, key::_pending_duplicate_object_key));
	state.set(flags, str(key::editor_pending_terrain_line_start), dict_value(_pending_terrain_line_start_payload(state, editor)));
	state.set(flags, str(key::editor_pending_terrain_rectangle_corner), dict_value(_pending_terrain_rectangle_corner_payload(state, editor)));
	state.set(flags, str(key::editor_pending_road_path_start), dict_value(_pending_road_path_start_payload(state, editor)));
	state.set(view, str(key::game_state), str(key::overworld));
	state.set(view, str(key::scenario_status), str(key::in_progress));
	state.set(view, str(key::battle), dict_value(state.new_dict()));
}

void _prepare_working_copy_for_play(State &state, const Value &editor, const Value &session_value) {
	(void)editor;
	const DictRef view = session_view(state, session_value);
	const DictRef flags = gd::as_dict(gd::index(state, view, str(key::flags)));
	state.set(flags, str(key::editor_working_copy), bool_value(true));
	state.set(flags, str(key::editor_source_scenario_id), gd::index(state, view, str(key::scenario_id)));
	state.set(flags, str(key::editor_return_model), str(key::launch_snapshot));
	// Time.get_datetime_string_from_system(true).
	const Value started_at = gd::call_method(state, gd::engine_singleton(state, key::Time), key::get_datetime_string_from_system, { bool_value(true) });
	state.set(flags, str(key::editor_started_at), started_at);
	state.set(view, str(key::game_state), str(key::overworld));
	state.set(view, str(key::scenario_status), str(key::in_progress));
	state.set(view, str(key::battle), dict_value(state.new_dict()));
	overworld_rules::refresh_fog_of_war(state, view);
}

DictRef consume_safe_close_guard_confirmation(State &state, const Value &editor, Atom source) {
	const Atom normalized_source = left_chars(state, gd::strip_edges(state, source), 64);
	const bool authorized = gd::to_bool(gd::member(state, editor, key::_safe_close_guard_authorized))
			&& normalized_source == member_text(state, editor, key::_safe_close_guard_authorized_source);
	gd::set_member(state, editor, key::_safe_close_guard_authorized, bool_value(false));
	gd::set_member(state, editor, key::_safe_close_guard_authorized_source, str(key::empty));
	const DictRef result = state.new_dict();
	if (!authorized) {
		state.set(result, str(key::ok), bool_value(false));
		state.set(result, str(key::authorized), bool_value(false));
		state.set(result, str(key::reason), str(key::not_confirmed));
		state.set(result, str(key::message), str(key::close_confirmation_is_no_longer_active));
		return result;
	}
	state.set(result, str(key::ok), bool_value(true));
	state.set(result, str(key::authorized), bool_value(true));
	state.set(result, str(key::reason), str(key::confirmed));
	state.set(result, str(key::message), str(key::unsaved_editor_close_confirmed));
	return result;
}

Atom _tile_inspection_text(State &state, const Value &editor, Vector2i tile) {
	if (session(state, editor).kind == Kind::Nil) {
		return key::no_working_copy_is_loaded;
	}
	if (!_tile_in_bounds(state, editor, tile)) {
		return key::select_a_tile_inside_the_map;
	}
	const Atom terrain_id = _terrain_at(state, editor, tile);
	const DictRef biome = gd::content_row(state, ContentTable::BiomeForTerrain, terrain_id);
	const ArrayRef lines = state.new_array();
	state.append(lines, str(gd::format(state, key::tile_d_d, { int_value(tile.x), int_value(tile.y) })));
	const Atom biome_name = text_or(state, biome, key::name, key::unknown_biome);
	const Atom passable = overworld_rules::terrain_id_is_passable(state, terrain_id) ? key::yes : key::no;
	state.append(lines, str(gd::format(state, key::terrain_s_s_passable_s_2, { str(terrain_id), str(biome_name), str(passable) })));
	if (_has_road_at(state, editor, tile)) {
		state.append(lines, str(gd::format(state, key::road_s_2, { str(join_values(state, key::comma_space, _road_layer_ids_at(state, editor, tile))) })));
	} else {
		state.append(lines, str(key::road_none));
	}
	const ArrayRef object_lines = _object_lines_at(state, editor, tile);
	if (state.array_size(object_lines) == 0) {
		state.append(lines, str(key::objects_none));
	} else {
		state.append(lines, str(key::objects_2));
		ai::append_array(state, lines, object_lines);
	}
	return join_values(state, key::newline, lines);
}

ArrayRef _object_lines_at(State &state, const Value &editor, Vector2i tile) {
	const ArrayRef lines = state.new_array();
	const ArrayRef details = _object_details_at(state, editor, tile, true);
	for (const Value &detail_value : item_values(state, array_value(details))) {
		if (!gd::is_dict(detail_value)) {
			continue;
		}
		const DictRef detail = detail_value.ref;
		const Atom kind = text_or(state, detail, key::kind, key::empty);
		if (kind == key::hero_start) {
			state.append(lines, str(gd::format(state, key::hero_start_s_id_s, {
				str(text_or(state, detail, key::name, key::empty)),
				str(text_or(state, detail, key::content_id, key::empty)),
			})));
		} else if (kind == key::town) {
			state.append(lines, str(gd::format(state, key::town_s_placement_s_content_s, {
				str(text_or(state, detail, key::name, key::empty)),
				str(text_or(state, detail, key::placement_id, key::empty)),
				str(text_or(state, detail, key::content_id, key::empty)),
				str(text_or(state, detail, key::owner, key::neutral)),
			})));
			_append_taxonomy_object_lines(state, editor, lines, detail);
			_append_authoring_dependency_lines(state, editor, lines, detail);
		} else if (kind == key::resource) {
			state.append(lines, str(gd::format(state, key::site_s_placement_s_content_s, {
				str(text_or(state, detail, key::name, key::empty)),
				str(text_or(state, detail, key::placement_id, key::empty)),
				str(text_or(state, detail, key::content_id, key::empty)),
				str(text_or(state, detail, key::family, key::empty)),
				str(gd::bool_field(state, detail, key::collected, false) ? key::yes : key::no),
			})));
			_append_resource_control_lines(state, editor, lines, detail);
			_append_taxonomy_object_lines(state, editor, lines, detail);
			_append_authoring_dependency_lines(state, editor, lines, detail);
		} else if (kind == key::artifact) {
			state.append(lines, str(gd::format(state, key::artifact_s_placement_s_content_s, {
				str(text_or(state, detail, key::name, key::empty)),
				str(text_or(state, detail, key::placement_id, key::empty)),
				str(text_or(state, detail, key::content_id, key::empty)),
				str(gd::bool_field(state, detail, key::collected, false) ? key::yes : key::no),
			})));
			_append_taxonomy_object_lines(state, editor, lines, detail);
			_append_authoring_dependency_lines(state, editor, lines, detail);
		} else if (kind == key::encounter) {
			state.append(lines, str(gd::format(state, key::encounter_s_placement_s_content_s, {
				str(text_or(state, detail, key::name, key::empty)),
				str(text_or(state, detail, key::placement_id, key::empty)),
				str(text_or(state, detail, key::content_id, key::empty)),
				str(text_or(state, detail, key::difficulty, key::medium)),
			})));
			_append_taxonomy_object_lines(state, editor, lines, detail);
			_append_authoring_dependency_lines(state, editor, lines, detail);
		}
	}
	return lines;
}

void _append_taxonomy_object_lines(State &state, const Value &editor, ArrayRef lines, DictRef detail) {
	// detail.get("taxonomy", {}): a missing one is the empty Dictionary.
	Value taxonomy_value;
	if (!state.lookup(detail, str(key::taxonomy), taxonomy_value)) {
		return;
	}
	if (!gd::is_dict(taxonomy_value) || gd::is_empty(state, taxonomy_value.ref)) {
		return;
	}
	const DictRef taxonomy = taxonomy_value.ref;
	const Atom summary = _taxonomy_inline_text(state, editor, taxonomy);
	if (summary != key::empty) {
		state.append(lines, str(gd::format(state, key::taxonomy_s, { str(summary) })));
	}
	const Atom link_line = _taxonomy_link_line(state, editor, taxonomy);
	if (link_line != key::empty) {
		state.append(lines, str(gd::format(state, key::link_s, { str(link_line) })));
	}
	const Atom role_line = _taxonomy_role_line(state, editor, taxonomy);
	if (role_line != key::empty) {
		state.append(lines, str(gd::format(state, key::role_s_4, { str(role_line) })));
	}
	const Atom guard_link_surface = gd::strip_edges(state, text_or(state, taxonomy, key::guard_link_surface, key::empty));
	if (guard_link_surface != key::empty) {
		state.append(lines, str(gd::format(state, key::guard_link_s_2, { str(guard_link_surface) })));
	}
	const Atom consequence_summary = gd::strip_edges(state, text_or(state, taxonomy, key::consequence_summary, key::empty));
	if (consequence_summary != key::empty) {
		state.append(lines, str(gd::format(state, key::s_10, { str(consequence_summary) })));
	}
	const ArrayRef identity_lines = _identity_summary_lines_for_editor(state, editor, taxonomy, 3);
	for (const Value &identity_line : item_values(state, array_value(identity_lines))) {
		state.append(lines, str(gd::format(state, key::s_10, { identity_line })));
	}
	const Vector2i tile = Vector2i::of(gd::int_field(state, detail, key::x, 0), gd::int_field(state, detail, key::y, 0));
	const DictRef guidance = _placement_guidance_payload(state, editor, taxonomy, tile);
	if (!gd::is_empty(state, guidance)) {
		state.append(lines, str(gd::format(state, key::place_s_density_s_2, {
			str(text_or(state, guidance, key::placement_role, key::empty)),
			str(text_or(state, guidance, key::density_target, key::empty)),
		})));
		state.append(lines, str(gd::format(state, key::flags_s_local_d_in_16x16_2, {
			str(text_or(state, guidance, key::role_flags_text, key::empty)),
			int_value(gd::int_field(state, guidance, key::local_density_count, 0)),
		})));
	}
}

void _append_authoring_dependency_lines(State &state, const Value &editor, ArrayRef lines, DictRef detail) {
	(void)editor;
	constexpr const char *where = "MapEditorShell._append_authoring_dependency_lines";
	// detail.get("authoring_dependencies", {}): a missing one is the empty Dictionary.
	Value dependencies_value;
	if (!state.lookup(detail, str(key::authoring_dependencies), dependencies_value)) {
		return;
	}
	if (!gd::is_dict(dependencies_value) || gd::is_empty(state, dependencies_value.ref)) {
		return;
	}
	const DictRef dependencies = dependencies_value.ref;
	ArrayRef objective_links = 0;
	if (array_field(state, dependencies, key::objective_links, objective_links, where)) {
		const int64_t count = std::min<int64_t>(2, state.array_size(objective_links));
		for (int64_t index = 0; index < count; ++index) {
			const Value link = state.at(objective_links, index);
			if (!gd::is_dict(link)) {
				continue;
			}
			const Atom bucket = gd::capitalize(state, text_or(state, link.ref, key::bucket, key::empty));
			const Atom label = string_of(state, state.get(link.ref, str(key::label), state.get(link.ref, str(key::id), str(key::empty))));
			state.append(lines, str(gd::format(state, key::objective_s_s, { str(bucket), str(label) })));
		}
	}
	ArrayRef guard_links = 0;
	if (array_field(state, dependencies, key::guard_links, guard_links, where)) {
		const int64_t count = std::min<int64_t>(2, state.array_size(guard_links));
		for (int64_t index = 0; index < count; ++index) {
			const Value guard = state.at(guard_links, index);
			if (!gd::is_dict(guard)) {
				continue;
			}
			if (text_or(state, guard.ref, key::role, key::empty) == key::guards) {
				const Atom target_label = text_or(state, guard.ref, key::target_label, key::target);
				const Atom clear_text = gd::bool_field(state, guard.ref, key::clear_required_2, false) ? key::clear_required_3 : key::empty;
				state.append(lines, str(gd::format(state, key::guards_s_s, { str(target_label), str(clear_text) })));
			} else {
				state.append(lines, str(gd::format(state, key::guarded_by_s_2, { str(text_or(state, guard.ref, key::source_label, key::encounter)) })));
			}
		}
	}
	ArrayRef route_links = 0;
	if (array_field(state, dependencies, key::route_links, route_links, where) && state.array_size(route_links) != 0) {
		const Value route = state.at(route_links, 0);
		if (gd::is_dict(route)) {
			const Atom route_text = string_of(state, state.get(route.ref, str(key::route_id), state.get(route.ref, str(key::role), str(key::empty))));
			state.append(lines, str(gd::format(state, key::route_s_3, { str(route_text) })));
		}
	}
	ArrayRef reward_links = 0;
	if (array_field(state, dependencies, key::reward_links, reward_links, where) && state.array_size(reward_links) != 0) {
		std::vector<Atom> reward_labels;
		const int64_t count = std::min<int64_t>(2, state.array_size(reward_links));
		for (int64_t index = 0; index < count; ++index) {
			const Value reward = state.at(reward_links, index);
			if (gd::is_dict(reward)) {
				reward_labels.push_back(string_of(state, state.get(reward.ref, str(key::label), state.get(reward.ref, str(key::effect_type), str(key::empty)))));
			}
		}
		if (!reward_labels.empty()) {
			state.append(lines, str(gd::format(state, key::follow_up_s, { str(join_atoms(state, key::semicolon_space, reward_labels)) })));
		}
	}
	ArrayRef enemy_focus_links = 0;
	if (array_field(state, dependencies, key::enemy_focus_links, enemy_focus_links, where) && state.array_size(enemy_focus_links) != 0) {
		const Value focus = state.at(enemy_focus_links, 0);
		if (gd::is_dict(focus)) {
			state.append(lines, str(gd::format(state, key::enemy_focus_s_s, {
				str(text_or(state, focus.ref, key::label, key::empty)),
				str(text_or(state, focus.ref, key::role, key::empty)),
			})));
		}
	}
	ArrayRef warnings = 0;
	if (array_field(state, dependencies, key::warnings, warnings, where)) {
		const int64_t count = std::min<int64_t>(2, state.array_size(warnings));
		for (int64_t index = 0; index < count; ++index) {
			state.append(lines, str(gd::format(state, key::warning_s_3, { str(string_of(state, state.at(warnings, index))) })));
		}
	}
}

void _append_resource_control_lines(State &state, const Value &editor, ArrayRef lines, DictRef detail) {
	(void)editor;
	Atom control_inspection = gd::strip_edges(state, text_or(state, detail, key::control_inspection, key::empty));
	if (control_inspection == key::empty) {
		// detail.get("taxonomy", {}): the empty Dictionary gives "".
		Value taxonomy;
		if (state.lookup(detail, str(key::taxonomy), taxonomy) && gd::is_dict(taxonomy)) {
			control_inspection = gd::strip_edges(state, text_or(state, taxonomy.ref, key::control_inspection, key::empty));
		}
	}
	if (control_inspection == key::empty) {
		return;
	}
	append_stripped_lines(state, lines, control_inspection);
	Atom recruit_inspection = gd::strip_edges(state, text_or(state, detail, key::recruit_source_inspection, key::empty));
	if (recruit_inspection == key::empty) {
		Value recruit_taxonomy;
		if (state.lookup(detail, str(key::taxonomy), recruit_taxonomy) && gd::is_dict(recruit_taxonomy)) {
			recruit_inspection = gd::strip_edges(state, text_or(state, recruit_taxonomy.ref, key::recruit_source_inspection, key::empty));
		}
	}
	if (recruit_inspection == key::empty || state.text(control_inspection).find(state.text(recruit_inspection)) != std::string::npos) {
		return;
	}
	append_stripped_lines(state, lines, recruit_inspection);
}

DictRef _object_detail_for_placement(State &state, const Value &editor, Atom family, DictRef placement) {
	if (family == key::town) {
		const DictRef town = gd::content_row(state, ContentTable::Town, text_or(state, placement, key::town_id, key::empty));
		const DictRef town_taxonomy = _town_taxonomy_payload(state, editor, town);
		const DictRef detail = state.new_dict();
		state.set(detail, str(key::kind), str(key::town));
		state.set(detail, str(key::placement_id), str(text_or(state, placement, key::placement_id, key::empty)));
		state.set(detail, str(key::content_id), str(text_or(state, placement, key::town_id, key::empty)));
		state.set(detail, str(key::name), str(string_of(state, state.get(town, str(key::name), state.get(placement, str(key::town_id), str(key::empty))))));
		state.set(detail, str(key::owner), str(text_or(state, placement, key::owner, key::neutral)));
		state.set(detail, str(key::taxonomy), dict_value(town_taxonomy));
		state.set(detail, str(key::taxonomy_summary), str(_taxonomy_inline_text(state, editor, town_taxonomy)));
		state.set(detail, str(key::property_key), str(_object_property_key(state, editor, key::town, text_or(state, placement, key::placement_id, key::empty))));
		state.set(detail, str(key::editable_properties), array_value(_editable_properties_for_object(state, editor, key::town)));
		state.set(detail, str(key::x), int_value(gd::int_field(state, placement, key::x, 0)));
		state.set(detail, str(key::y), int_value(gd::int_field(state, placement, key::y, 0)));
		return detail;
	}
	if (family == key::resource) {
		const DictRef site = gd::content_row(state, ContentTable::ResourceSite, text_or(state, placement, key::site_id, key::empty));
		const DictRef resource_taxonomy = _resource_taxonomy_payload(state, editor, placement, site);
		const Atom control_inspection = overworld_rules::describe_resource_site_control_inspection(state, view_or_nil(state, session(state, editor)), placement, site);
		const DictRef detail = state.new_dict();
		state.set(detail, str(key::kind), str(key::resource));
		state.set(detail, str(key::placement_id), str(text_or(state, placement, key::placement_id, key::empty)));
		state.set(detail, str(key::content_id), str(text_or(state, placement, key::site_id, key::empty)));
		state.set(detail, str(key::name), str(string_of(state, state.get(site, str(key::name), state.get(placement, str(key::site_id), str(key::empty))))));
		state.set(detail, str(key::family), str(text_or(state, site, key::family, key::one_shot_pickup)));
		state.set(detail, str(key::collected), bool_value(gd::bool_field(state, placement, key::collected, false)));
		state.set(detail, str(key::collected_by_faction_id), str(text_or(state, placement, key::collected_by_faction_id, key::empty)));
		state.set(detail, str(key::collected_day), int_value(std::max<int64_t>(0, gd::int_field(state, placement, key::collected_day, 0))));
		state.set(detail, str(key::taxonomy), dict_value(resource_taxonomy));
		state.set(detail, str(key::taxonomy_summary), str(_taxonomy_inline_text(state, editor, resource_taxonomy)));
		const Value working_copy = session(state, editor);
		if (working_copy.kind == Kind::Nil) {
			// Every caller reads the placement from _session.overworld.
			throw state::NotPorted("MapEditorShell._object_detail_for_placement: describe_resource_site_control_summary of a null working copy (its port takes a session)");
		}
		state.set(detail, str(key::control_summary), str(overworld_rules::describe_resource_site_control_summary(state, session_view(state, working_copy), placement, site)));
		state.set(detail, str(key::control_inspection), str(control_inspection));
		state.set(detail, str(key::recruit_source_inspection), str(text_or(state, resource_taxonomy, key::recruit_source_inspection, key::empty)));
		state.set(detail, str(key::property_key), str(_object_property_key(state, editor, key::resource, text_or(state, placement, key::placement_id, key::empty))));
		state.set(detail, str(key::editable_properties), array_value(_editable_properties_for_object(state, editor, key::resource)));
		state.set(detail, str(key::x), int_value(gd::int_field(state, placement, key::x, 0)));
		state.set(detail, str(key::y), int_value(gd::int_field(state, placement, key::y, 0)));
		return detail;
	}
	if (family == key::artifact) {
		const DictRef artifact = gd::content_row(state, ContentTable::Artifact, text_or(state, placement, key::artifact_id, key::empty));
		const DictRef artifact_taxonomy = _artifact_taxonomy_payload(state, editor, artifact);
		const DictRef detail = state.new_dict();
		state.set(detail, str(key::kind), str(key::artifact));
		state.set(detail, str(key::placement_id), str(text_or(state, placement, key::placement_id, key::empty)));
		state.set(detail, str(key::content_id), str(text_or(state, placement, key::artifact_id, key::empty)));
		state.set(detail, str(key::name), str(string_of(state, state.get(artifact, str(key::name), state.get(placement, str(key::artifact_id), str(key::empty))))));
		state.set(detail, str(key::collected), bool_value(gd::bool_field(state, placement, key::collected, false)));
		state.set(detail, str(key::collected_by_faction_id), str(text_or(state, placement, key::collected_by_faction_id, key::empty)));
		state.set(detail, str(key::collected_day), int_value(std::max<int64_t>(0, gd::int_field(state, placement, key::collected_day, 0))));
		state.set(detail, str(key::taxonomy), dict_value(artifact_taxonomy));
		state.set(detail, str(key::taxonomy_summary), str(_taxonomy_inline_text(state, editor, artifact_taxonomy)));
		state.set(detail, str(key::property_key), str(_object_property_key(state, editor, key::artifact, text_or(state, placement, key::placement_id, key::empty))));
		state.set(detail, str(key::editable_properties), array_value(_editable_properties_for_object(state, editor, key::artifact)));
		state.set(detail, str(key::x), int_value(gd::int_field(state, placement, key::x, 0)));
		state.set(detail, str(key::y), int_value(gd::int_field(state, placement, key::y, 0)));
		return detail;
	}
	if (family == key::encounter) {
		const DictRef encounter = gd::content_row(state, ContentTable::Encounter, text_or(state, placement, key::encounter_id, key::empty));
		const DictRef encounter_taxonomy = _encounter_taxonomy_payload(state, editor, placement, encounter);
		const DictRef detail = state.new_dict();
		state.set(detail, str(key::kind), str(key::encounter));
		state.set(detail, str(key::placement_id), str(text_or(state, placement, key::placement_id, key::empty)));
		state.set(detail, str(key::content_id), str(text_or(state, placement, key::encounter_id, key::empty)));
		state.set(detail, str(key::name), str(string_of(state, state.get(encounter, str(key::name), state.get(placement, str(key::encounter_id), str(key::empty))))));
		state.set(detail, str(key::difficulty), str(text_or(state, placement, key::difficulty, key::medium)));
		state.set(detail, str(key::combat_seed), int_value(gd::int_field(state, placement, key::combat_seed, 0)));
		state.set(detail, str(key::taxonomy), dict_value(encounter_taxonomy));
		state.set(detail, str(key::taxonomy_summary), str(_taxonomy_inline_text(state, editor, encounter_taxonomy)));
		state.set(detail, str(key::property_key), str(_object_property_key(state, editor, key::encounter, text_or(state, placement, key::placement_id, key::empty))));
		state.set(detail, str(key::editable_properties), array_value(_editable_properties_for_object(state, editor, key::encounter)));
		state.set(detail, str(key::x), int_value(gd::int_field(state, placement, key::x, 0)));
		state.set(detail, str(key::y), int_value(gd::int_field(state, placement, key::y, 0)));
		return detail;
	}
	return state.new_dict();
}

ArrayRef _object_details_at(State &state, const Value &editor, Vector2i tile, bool include_hero) {
	const ArrayRef details = state.new_array();
	const DictRef view = session_view(state, session(state, editor));
	if (overworld_rules::hero_position(state, view) == tile) {
		// _session.overworld.get("hero", {}): a missing hero answers the fallbacks.
		Value hero;
		const bool has_hero = state.lookup(port::session_view::overworld(state, view), str(key::hero), hero);
		if (include_hero) {
			const Value id_fallback = gd::index(state, view, str(key::hero_id));
			const Atom content_id = string_of(state, has_hero ? ai::vget(state, hero, key::id, id_fallback) : id_fallback);
			const Value name_fallback = gd::index(state, view, str(key::hero_id));
			const Atom name = string_of(state, has_hero ? ai::vget(state, hero, key::name, name_fallback) : name_fallback);
			const DictRef entry = state.new_dict();
			state.set(entry, str(key::kind), str(key::hero_start));
			state.set(entry, str(key::content_id), str(content_id));
			state.set(entry, str(key::name), str(name));
			state.set(entry, str(key::x), int_value(tile.x));
			state.set(entry, str(key::y), int_value(tile.y));
			state.append(details, dict_value(entry));
		}
	}
	append_family_details(state, editor, details, working_overworld(state, editor), key::towns, key::town, tile);
	append_family_details(state, editor, details, working_overworld(state, editor), key::resource_nodes, key::resource, tile);
	append_family_details(state, editor, details, working_overworld(state, editor), key::artifact_nodes, key::artifact, tile);
	append_family_details(state, editor, details, working_overworld(state, editor), key::encounters, key::encounter, tile);
	return details;
}

DictRef _object_detail_with_guidance(State &state, const Value &editor, DictRef detail, Vector2i tile) {
	if (gd::is_empty(state, detail)) {
		return detail;
	}
	// detail.get("taxonomy", {}): a missing one is a new empty Dictionary, handed on.
	Value taxonomy;
	if (!state.lookup(detail, str(key::taxonomy), taxonomy)) {
		taxonomy = dict_value(state.new_dict());
	}
	if (gd::is_dict(taxonomy)) {
		const DictRef guidance = _placement_guidance_payload(state, editor, taxonomy.ref, tile);
		state.set(detail, str(key::placement_guidance), dict_value(guidance));
	}
	const DictRef dependencies = _authoring_dependencies_for_detail(state, editor, detail);
	state.set(detail, str(key::authoring_dependencies), dict_value(dependencies));
	return detail;
}

bool _placement_at_tile(State &state, const Value &editor, DictRef placement, Vector2i tile) {
	(void)editor;
	return gd::int_field(state, placement, key::x, -999) == tile.x && gd::int_field(state, placement, key::y, -999) == tile.y;
}

Atom _placement_array_key(State &state, const Value &editor, Atom family) {
	(void)state;
	(void)editor;
	if (family == key::town) {
		return key::towns;
	}
	if (family == key::resource) {
		return key::resource_nodes;
	}
	if (family == key::artifact) {
		return key::artifact_nodes;
	}
	if (family == key::encounter) {
		return key::encounters;
	}
	return key::empty;
}

Atom _placement_content_key(State &state, const Value &editor, Atom family) {
	(void)state;
	(void)editor;
	if (family == key::town) {
		return key::town_id;
	}
	if (family == key::resource) {
		return key::site_id;
	}
	if (family == key::artifact) {
		return key::artifact_id;
	}
	if (family == key::encounter) {
		return key::encounter_id;
	}
	return key::empty;
}

Atom _object_property_key(State &state, const Value &editor, Atom kind, Atom placement_id) {
	(void)editor;
	if (kind == key::empty || placement_id == key::empty) {
		return key::empty;
	}
	return gd::format(state, key::s_s_6, { str(kind), str(placement_id) });
}

ArrayRef _editable_properties_for_object(State &state, const Value &editor, Atom kind) {
	(void)editor;
	const ArrayRef properties = state.new_array();
	if (kind == key::town) {
		state.append(properties, str(key::owner));
	} else if (kind == key::resource || kind == key::artifact) {
		state.append(properties, str(key::collected));
	} else if (kind == key::encounter) {
		state.append(properties, str(key::difficulty));
	}
	return properties;
}

Atom _primary_editable_property_for_kind(State &state, const Value &editor, Atom kind) {
	const ArrayRef properties = _editable_properties_for_object(state, editor, kind);
	return state.array_size(properties) != 0 ? string_of(state, state.at(properties, 0)) : static_cast<Atom>(key::empty);
}

Atom _object_family_label(State &state, const Value &editor, Atom family) {
	(void)state;
	(void)editor;
	if (family == key::town) {
		return key::Town;
	}
	if (family == key::resource) {
		return key::Resource;
	}
	if (family == key::artifact) {
		return key::Artifact;
	}
	if (family == key::encounter) {
		return key::Encounter;
	}
	return key::Object;
}

DictRef _object_content_lookup(State &state, const Value &editor, Atom family, Atom content_id) {
	(void)editor;
	if (family == key::town) {
		return gd::content_row(state, ContentTable::Town, content_id);
	}
	if (family == key::resource) {
		return gd::content_row(state, ContentTable::ResourceSite, content_id);
	}
	if (family == key::artifact) {
		return gd::content_row(state, ContentTable::Artifact, content_id);
	}
	if (family == key::encounter) {
		return gd::content_row(state, ContentTable::Encounter, content_id);
	}
	return state.new_dict();
}

Atom _generate_editor_placement_id(State &state, const Value &editor, Atom family, Atom content_id, Vector2i tile) {
	const Atom family_segment = _safe_id_segment(state, editor, family);
	const Atom content_segment = _safe_id_segment(state, editor, content_id);
	const Atom base_id = gd::format(state, key::editor_s_s_d_d, { str(family_segment), str(content_segment), int_value(tile.x), int_value(tile.y) });
	return unused_placement_id(state, editor, base_id);
}

Atom _generate_duplicate_placement_id(State &state, const Value &editor, Atom family, Atom source_placement_id, Vector2i tile) {
	const Atom family_segment = _safe_id_segment(state, editor, family);
	const Atom source_segment = _safe_id_segment(state, editor, source_placement_id);
	const Atom base_id = gd::format(state, key::editor_duplicate_s_s_d_d, { str(family_segment), str(source_segment), int_value(tile.x), int_value(tile.y) });
	return unused_placement_id(state, editor, base_id);
}

Atom _safe_id_segment(State &state, const Value &editor, Atom value) {
	(void)editor;
	const std::string source = state.text(value);
	const std::string allowed = state.text(key::abcdefghijklmnopqrstuvwxyz0123456789_);
	std::string normalized;
	for (size_t at = 0; at < source.size();) {
		const size_t length = std::min(utf8_sequence_length(static_cast<unsigned char>(source[at])), source.size() - at);
		std::string character = lower_character(source.substr(at, length));
		at += length;
		if (character == "-") {
			character = "_";
		}
		if (allowed.find(character) != std::string::npos) {
			normalized += character;
		} else {
			normalized += "_";
		}
	}
	Atom result = state.intern(normalized);
	while (state.text(result).find("__") != std::string::npos) {
		result = gd::replace(state, result, key::double_underscore, key::_);
	}
	if (result == key::empty || result == key::_) {
		return key::object;
	}
	return result;
}

bool _placement_id_exists(State &state, const Value &editor, Atom placement_id) {
	if (session(state, editor).kind == Kind::Nil || placement_id == key::empty) {
		return false;
	}
	for (const Atom family : kObjectFamilies) {
		const Atom array_key = _placement_array_key(state, editor, family);
		// _session.overworld.get(array_key, []): a missing list has no placements.
		Value placements;
		if (!state.lookup(working_overworld(state, editor), str(array_key), placements) || !gd::is_array(placements)) {
			continue;
		}
		for (int64_t index = 0; index < state.array_size(placements.ref); ++index) {
			const Value placement = state.at(placements.ref, index);
			if (gd::is_dict(placement) && text_or(state, placement.ref, key::placement_id, key::empty) == placement_id) {
				return true;
			}
		}
	}
	return false;
}

bool _artifact_content_id_exists(State &state, const Value &editor, Atom artifact_id) {
	if (session(state, editor).kind == Kind::Nil || artifact_id == key::empty) {
		return false;
	}
	// _session.overworld.get("artifact_nodes", []): a missing list has no nodes.
	Value artifact_nodes;
	if (!state.lookup(working_overworld(state, editor), str(key::artifact_nodes), artifact_nodes)) {
		return false;
	}
	if (!gd::is_array(artifact_nodes)) {
		return false;
	}
	for (int64_t index = 0; index < state.array_size(artifact_nodes.ref); ++index) {
		const Value node = state.at(artifact_nodes.ref, index);
		if (gd::is_dict(node) && text_or(state, node.ref, key::artifact_id, key::empty) == artifact_id) {
			return true;
		}
	}
	return false;
}

DictRef _terrain_layers(State &state, const Value &editor) {
	const DictRef view = session_view(state, session(state, editor));
	Value layers;
	if (!state.lookup(port::session_view::overworld(state, view), str(key::terrain_layers), layers)) {
		// {}.duplicate(true).
		return state.new_dict();
	}
	if (gd::is_dict(layers)) {
		return gd::deep_duplicate_dict(state, layers.ref);
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::id), gd::index(state, view, str(key::scenario_id)));
	state.set(result, str(key::terrain_layer_status), str(key::editor_working_copy));
	state.set(result, str(key::roads), array_value(state.new_array()));
	return result;
}

bool _has_road_at(State &state, const Value &editor, Vector2i tile) {
	return state.array_size(_road_layer_ids_at(state, editor, tile)) != 0;
}

ArrayRef _road_layer_ids_at(State &state, const Value &editor, Vector2i tile) {
	if (session(state, editor).kind == Kind::Nil) {
		return state.new_array();
	}
	const ArrayRef ids = state.new_array();
	// _session.overworld.get("terrain_layers", {}).get("roads", []): missing
	// layers or roads have no roads.
	Value layers;
	if (!state.lookup(working_overworld(state, editor), str(key::terrain_layers), layers)) {
		return ids;
	}
	Value roads;
	if (!untyped_lookup(state, layers, key::roads, roads) || !gd::is_array(roads)) {
		return ids;
	}
	for (int64_t road_index = 0; road_index < state.array_size(roads.ref); ++road_index) {
		const Value road = state.at(roads.ref, road_index);
		if (!gd::is_dict(road)) {
			continue;
		}
		Value tiles;
		if (!state.lookup(road.ref, str(key::tiles), tiles) || !gd::is_array(tiles)) {
			continue;
		}
		for (int64_t tile_index = 0; tile_index < state.array_size(tiles.ref); ++tile_index) {
			const Value tile_value = state.at(tiles.ref, tile_index);
			if (gd::is_dict(tile_value) && gd::int_field(state, tile_value.ref, key::x, -1) == tile.x && gd::int_field(state, tile_value.ref, key::y, -1) == tile.y) {
				state.append(ids, str(text_or(state, road.ref, key::id, key::editor_working_road)));
				break;
			}
		}
	}
	return ids;
}

int64_t _road_tile_count(State &state, const Value &editor) {
	if (session(state, editor).kind == Kind::Nil) {
		return 0;
	}
	// unique_tiles["%d,%d" % [x, y]]: one key per (x, y).
	std::set<std::pair<int64_t, int64_t>> unique_tiles;
	Value layers;
	if (!state.lookup(working_overworld(state, editor), str(key::terrain_layers), layers)) {
		return 0;
	}
	Value roads;
	if (!untyped_lookup(state, layers, key::roads, roads)) {
		// [] is an Array without roads.
		return 0;
	}
	if (!gd::is_array(roads)) {
		return 0;
	}
	for (int64_t road_index = 0; road_index < state.array_size(roads.ref); ++road_index) {
		const Value road = state.at(roads.ref, road_index);
		if (!gd::is_dict(road)) {
			continue;
		}
		Value tiles;
		if (!state.lookup(road.ref, str(key::tiles), tiles) || !gd::is_array(tiles)) {
			continue;
		}
		for (int64_t tile_index = 0; tile_index < state.array_size(tiles.ref); ++tile_index) {
			const Value tile_value = state.at(tiles.ref, tile_index);
			if (gd::is_dict(tile_value)) {
				unique_tiles.emplace(gd::int_field(state, tile_value.ref, key::x, -1), gd::int_field(state, tile_value.ref, key::y, -1));
			}
		}
	}
	return static_cast<int64_t>(unique_tiles.size());
}

int64_t _placement_count(State &state, const Value &editor) {
	if (session(state, editor).kind == Kind::Nil) {
		return 0;
	}
	int64_t total = 0;
	for (const Atom family : kObjectFamilies) {
		Value placements;
		if (state.lookup(working_overworld(state, editor), str(_placement_array_key(state, editor, family)), placements) && gd::is_array(placements)) {
			total = gd::add(total, state.array_size(placements.ref));
		}
	}
	return total;
}

Atom _terrain_at(State &state, const Value &editor, Vector2i tile) {
	if (session(state, editor).kind == Kind::Nil) {
		return key::empty;
	}
	// _session.overworld.get("map", []): an empty map has no row.
	Value map_data;
	if (!state.lookup(working_overworld(state, editor), str(key::map), map_data)) {
		return key::empty;
	}
	if (!gd::is_array(map_data) || tile.y < 0 || tile.y >= state.array_size(map_data.ref)) {
		return key::empty;
	}
	const Value row = state.at(map_data.ref, tile.y);
	if (!gd::is_array(row) || tile.x < 0 || tile.x >= state.array_size(row.ref)) {
		return key::empty;
	}
	return string_of(state, state.at(row.ref, tile.x));
}

bool _terrain_id_in_grammar(State &state, const Value &editor, Atom terrain_id) {
	if (terrain_id == key::empty) {
		return false;
	}
	const ArrayRef authored_terrain_ids = _authored_terrain_ids(state, editor);
	for (int64_t index = 0; index < state.array_size(authored_terrain_ids); ++index) {
		if (string_of(state, state.at(authored_terrain_ids, index)) == terrain_id) {
			return true;
		}
	}
	return false;
}

bool _tile_in_bounds(State &state, const Value &editor, Vector2i tile) {
	const Value working_copy = session(state, editor);
	if (working_copy.kind == Kind::Nil) {
		return false;
	}
	const Vector2i map_size = overworld_rules::derive_map_size(state, session_view(state, working_copy));
	return tile.x >= 0 && tile.y >= 0 && tile.x < map_size.x && tile.y < map_size.y;
}

Atom _tile_key(State &state, const Value &editor, Vector2i tile) {
	(void)editor;
	return state.intern(gd::format_pair(tile.x, tile.y));
}

DictRef _public_map_package_index_status(State &state, const Value &editor) {
	const DictRef index_status = gd::as_dict(gd::member(state, editor, key::_map_package_index_status));
	// var warnings: Array = status.get("warnings", []) if ... is Array else []: only its size is read.
	int64_t warning_count = 0;
	Value warnings;
	if (state.lookup(index_status, str(key::warnings), warnings) && gd::is_array(warnings)) {
		warning_count = state.array_size(warnings.ref);
	}
	int64_t inspection_only_count = 0;
	const ArrayRef entries = gd::as_array(gd::member(state, editor, key::_map_package_entries));
	for (int64_t index = 0; index < state.array_size(entries); ++index) {
		const Value entry = state.at(entries, index);
		if (gd::is_dict(entry) && gd::bool_field(state, entry.ref, key::editor_inspection_only, false)) {
			inspection_only_count = gd::add(inspection_only_count, 1);
		}
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(gd::bool_field(state, index_status, key::ok, true)));
	state.set(result, str(key::schema_id), str(text_or(state, index_status, key::schema_id, key::empty)));
	state.set(result, str(key::package_dir), str(text_or(state, index_status, key::package_dir, key::empty)));
	state.set(result, str(key::include_non_launchable_generated_packages), bool_value(gd::bool_field(state, index_status, key::include_non_launchable_generated_packages, false)));
	state.set(result, str(key::entry_count), int_value(state.array_size(gd::as_array(gd::member(state, editor, key::_map_package_entries)))));
	state.set(result, str(key::editor_inspection_only_count), int_value(inspection_only_count));
	state.set(result, str(key::message), str(text_or(state, index_status, key::message, key::empty)));
	state.set(result, str(key::warning_count), int_value(warning_count));
	state.set(result, str(key::unpaired_map_count), int_value(gd::int_field(state, index_status, key::unpaired_map_count, 0)));
	state.set(result, str(key::unpaired_scenario_count), int_value(gd::int_field(state, index_status, key::unpaired_scenario_count, 0)));
	state.set(result, str(key::authored_json_scenarios_used), bool_value(false));
	return result;
}

DictRef _tile_inspection_payload(State &state, const Value &editor, Vector2i tile) {
	if (session(state, editor).kind == Kind::Nil || !_tile_in_bounds(state, editor, tile)) {
		return state.new_dict();
	}
	const ArrayRef object_lines = _object_lines_at(state, editor, tile);
	const DictRef payload = state.new_dict();
	state.set(payload, str(key::x), int_value(tile.x));
	state.set(payload, str(key::y), int_value(tile.y));
	state.set(payload, str(key::terrain_id), str(_terrain_at(state, editor, tile)));
	state.set(payload, str(key::road), bool_value(_has_road_at(state, editor, tile)));
	state.set(payload, str(key::road_layers), array_value(_road_layer_ids_at(state, editor, tile)));
	state.set(payload, str(key::object_count), int_value(state.array_size(object_lines)));
	state.set(payload, str(key::objects), array_value(object_lines));
	state.set(payload, str(key::object_details), array_value(_object_details_at(state, editor, tile, true)));
	state.set(payload, str(key::selected_property_object), dict_value(_selected_property_object_payload(state, editor)));
	state.set(payload, str(key::pending_move_object), dict_value(_pending_move_object_payload(state, editor)));
	state.set(payload, str(key::pending_duplicate_object), dict_value(_pending_duplicate_object_payload(state, editor)));
	state.set(payload, str(key::text), str(_tile_inspection_text(state, editor, tile)));
	return payload;
}

} // namespace aurelion::rules::port::map_editor
