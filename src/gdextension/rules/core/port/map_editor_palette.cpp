// MapEditorShell's rules (Phase 7, slice 7.13): the map cursor's semantic texts, the property panel's
// payloads, the terrain and object pickers' items and the
// object taxonomy and palette guidance.

#include "aurelion_rules/port/map_editor.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/overworld_rules_panels.hpp"
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
using overworld_rules::Vector2i;
using state::ContentTable;
using state::Kind;
using state::State;
using state::Value;
namespace key = state::key;

// MapEditorShell.EDITOR_MAP_CURSOR_SEMANTIC_MAX_CHARS.
constexpr int64_t kCursorSemanticMaxChars = 320;

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

// d.get(field, {}) and d.get(field, []): the value, or a new container when the key is missing.
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

// sep.join(parts) of Strings.
Atom join_texts(State &state, Atom separator, const std::vector<Atom> &parts) {
	std::string joined;
	for (size_t index = 0; index < parts.size(); ++index) {
		if (index > 0) {
			joined += state.text(separator);
		}
		joined += state.text(parts[index]);
	}
	return state.intern(joined);
}

// sep.join(array) of an Array, which converts to a PackedStringArray.
Atom join_array(State &state, Atom separator, ArrayRef parts) {
	std::vector<Atom> texts;
	const int64_t size = state.array_size(parts);
	for (int64_t index = 0; index < size; ++index) {
		texts.push_back(string_of(state, state.at(parts, index)));
	}
	return join_texts(state, separator, texts);
}

// s.split(delimiter, allow_empty) (String::split without maxsplit) of a non-empty delimiter.
std::vector<std::string> split_text(const std::string &text, const std::string &delimiter, bool allow_empty) {
	std::vector<std::string> pieces;
	if (text.empty()) {
		if (allow_empty) {
			pieces.emplace_back();
		}
		return pieces;
	}
	size_t from = 0;
	while (true) {
		size_t end = text.find(delimiter, from);
		if (end == std::string::npos) {
			end = text.size();
		}
		if (allow_empty || end > from) {
			pieces.push_back(text.substr(from, end - from));
		}
		if (end == text.size()) {
			break;
		}
		from = end + delimiter.size();
	}
	return pieces;
}

// s.replace(what, with) (left to right, matches do not overlap) of a non-empty what.
std::string replace_text(const std::string &text, const std::string &what, const std::string &with) {
	std::string out;
	size_t from = 0;
	while (true) {
		const size_t at = text.find(what, from);
		if (at == std::string::npos) {
			out.append(text, from, std::string::npos);
			return out;
		}
		out.append(text, from, at - from);
		out += with;
		from = at + what.size();
	}
}

// s.strip_edges(): the characters up to code 32 at both ends (all ASCII, so bytes of UTF-8).
std::string strip_text(const std::string &text) {
	size_t begin = 0;
	size_t end = text.size();
	while (begin < end && static_cast<unsigned char>(text[begin]) <= 32) {
		++begin;
	}
	while (end > begin && static_cast<unsigned char>(text[end - 1]) <= 32) {
		--end;
	}
	return text.substr(begin, end - begin);
}

// s.left(length): the first length characters (code points), or all but the last -length.
std::string left_chars(const std::string &text, int32_t length) {
	std::vector<size_t> starts;
	for (size_t at = 0; at < text.size(); ++at) {
		if ((static_cast<unsigned char>(text[at]) & 0xC0) != 0x80) {
			starts.push_back(at);
		}
	}
	const int64_t count = static_cast<int64_t>(starts.size());
	int64_t wanted = length;
	if (wanted < 0) {
		wanted = count + wanted;
	}
	if (wanted <= 0) {
		return std::string();
	}
	if (wanted >= count) {
		return text;
	}
	return text.substr(0, starts[static_cast<size_t>(wanted)]);
}

// A String member of the screen.
Atom member_string(State &state, const Value &editor, Atom name) {
	return gd::to_string(gd::member(state, editor, name));
}

// A Vector2i member of the screen.
Vector2i member_tile(State &state, const Value &editor, Atom name) {
	const Value value = gd::member(state, editor, name);
	if (value.kind != Kind::Vector2i) {
		throw state::ScriptError(std::string("MapEditorShell: the member ") + state.text(name) + " is no Vector2i");
	}
	return Vector2i::of(value.vx(), value.vy());
}

// kind in [OBJECT_FAMILY_TOWN, OBJECT_FAMILY_RESOURCE, OBJECT_FAMILY_ARTIFACT, OBJECT_FAMILY_ENCOUNTER].
bool is_object_family(Atom kind) {
	return kind == key::town || kind == key::resource || kind == key::artifact || kind == key::encounter;
}

// {"ok": false, "changed": false, "message": message}.
DictRef refused(State &state, Atom message) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(false));
	state.set(result, str(key::changed), bool_value(false));
	state.set(result, str(key::message), str(message));
	return result;
}

// {"x": tile.x, "y": tile.y}.
DictRef tile_dict(State &state, Vector2i tile) {
	const DictRef payload = state.new_dict();
	state.set(payload, str(key::x), int_value(tile.x));
	state.set(payload, str(key::y), int_value(tile.y));
	return payload;
}

// for raw_line in text.split("\n"): the stripped lines that are not empty, at most limit (at least one).
ArrayRef summary_lines(State &state, Atom text, int64_t limit) {
	const ArrayRef lines = state.new_array();
	for (const std::string &raw_line : split_text(state.text(text), "\n", true)) {
		const std::string line = strip_text(raw_line);
		if (line.empty()) {
			continue;
		}
		state.append(lines, str(state.intern(line)));
		if (state.array_size(lines) >= limit) {
			break;
		}
	}
	return lines;
}

} // namespace

namespace map_editor {

Vector2i _editor_map_direction_for_action(State &state, const Value &editor, Atom action) {
	(void)state;
	(void)editor;
	if (action == key::ui_left) {
		return Vector2i::of(-1, 0);
	}
	if (action == key::ui_right) {
		return Vector2i::of(1, 0);
	}
	if (action == key::ui_up) {
		return Vector2i::of(0, -1);
	}
	if (action == key::ui_down) {
		return Vector2i::of(0, 1);
	}
	return Vector2i::of(0, 0);
}

Atom _editor_map_cursor_semantic_context(State &state, const Value &editor) {
	const Vector2i selected_tile = member_tile(state, editor, key::_selected_tile);
	if (session(state, editor).kind == Kind::Nil || !_tile_in_bounds(state, editor, selected_tile)) {
		return key::empty;
	}
	const Atom terrain_id = _terrain_at(state, editor, selected_tile);
	Atom terrain_label = _terrain_label_for_id(state, editor, terrain_id);
	if (terrain_label == key::empty) {
		terrain_label = terrain_id != key::empty ? terrain_id : static_cast<Atom>(key::unknown);
	}
	terrain_label = _bounded_editor_map_semantic_text(state, editor, terrain_label, 32);
	const ArrayRef material_parts = state.new_array();
	if (_has_road_at(state, editor, selected_tile)) {
		const Atom road_ids = join_array(state, key::comma_space, _road_layer_ids_at(state, editor, selected_tile));
		state.append(material_parts, str(gd::format(state, key::road_s, { str(_bounded_editor_map_semantic_text(state, editor, road_ids, 48)) })));
	}
	const ArrayRef object_details = _object_details_at(state, editor, selected_tile, true);
	const ArrayRef object_labels = state.new_array();
	for (const Value &detail_value : gd::items(state, array_value(object_details))) {
		if (!gd::is_dict(detail_value)) {
			continue;
		}
		const DictRef detail = detail_value.ref;
		const Atom kind = _humanize_editor_id(state, editor, text_or(state, detail, key::kind, key::object));
		const Value name_fallback = state.get(detail, str(key::content_id), str(key::empty));
		const Atom name = gd::strip_edges(state, string_of(state, state.get(detail, str(key::name), name_fallback)));
		const Atom object_label = name != key::empty ? gd::format(state, key::s_s, { str(kind), str(name) }) : kind;
		state.append(object_labels, str(_bounded_editor_map_semantic_text(state, editor, object_label, 56)));
		if (state.array_size(object_labels) >= 2) {
			break;
		}
	}
	if (state.array_size(object_labels) != 0) {
		Atom object_summary = join_array(state, key::comma_space, object_labels);
		if (state.array_size(object_details) > state.array_size(object_labels)) {
			object_summary = gd::format(state, key::s_plus_d_more, { str(object_summary), int_value(state.array_size(object_details) - state.array_size(object_labels)) });
		}
		state.append(material_parts, str(object_summary));
	}
	if (state.array_size(material_parts) == 0) {
		state.append(material_parts, str(key::no_road_or_objects));
	}
	const Atom material_summary = _bounded_editor_map_semantic_text(state, editor, join_array(state, key::comma_space, material_parts), 80);
	const DictRef cue = _editor_active_tool_cue_payload(state, editor, key::empty);
	const Value action_fallback = state.get(cue, str(key::action), str(key::apply_the_active_tool));
	Atom next_step = gd::strip_edges(state, string_of(state, state.get(cue, str(key::next_step_2), action_fallback)));
	if (gd::begins_with(state, next_step, key::click_2)) {
		next_step = state.intern(state.text(key::select) + state.text(next_step).substr(6));
	}
	next_step = _bounded_editor_map_semantic_text(state, editor, next_step, 72);
	const Atom tool_label = _bounded_editor_map_semantic_text(state, editor, _tool_label(state, editor, member_string(state, editor, key::_tool)), 24);
	const Atom text = gd::format(state, key::tile_d_d_terrain_s_s, {
			int_value(selected_tile.x),
			int_value(selected_tile.y),
			str(terrain_label),
			str(material_summary),
			str(tool_label),
			str(next_step),
	});
	return _bounded_editor_map_semantic_text(state, editor, text, kCursorSemanticMaxChars);
}

Atom _editor_map_action_result_semantic_text(State &state, const Value &editor) {
	Atom result_text = _bounded_editor_map_semantic_text(state, editor, member_string(state, editor, key::_last_message), 240);
	if (result_text == key::empty) {
		result_text = gd::format(state, key::s_applied, { str(_tool_label(state, editor, member_string(state, editor, key::_tool))) });
	}
	const Vector2i selected_tile = member_tile(state, editor, key::_selected_tile);
	return _bounded_editor_map_semantic_text(state, editor,
			gd::format(state, key::map_action_result_at_d_d, { int_value(selected_tile.x), int_value(selected_tile.y), str(result_text) }),
			kCursorSemanticMaxChars);
}

Atom _bounded_editor_map_semantic_text(State &state, const Value &editor, Atom value, int64_t maximum_characters) {
	(void)editor;
	const std::vector<std::string> pieces = split_text(replace_text(state.text(value), "\r", "\n"), "\n", false);
	std::string joined;
	for (size_t index = 0; index < pieces.size(); ++index) {
		if (index > 0) {
			joined += ' ';
		}
		joined += pieces[index];
	}
	std::string normalized = strip_text(joined);
	while (normalized.find("  ") != std::string::npos) {
		normalized = replace_text(normalized, "  ", " ");
	}
	// String.left takes an int.
	return state.intern(left_chars(normalized, static_cast<int32_t>(maximum_characters)));
}

DictRef _editor_tile_payload(State &state, const Value &editor, Vector2i tile) {
	(void)editor;
	return tile_dict(state, tile);
}

Atom _property_summary_text(State &state, const Value &editor, DictRef detail) {
	if (gd::is_empty(state, detail)) {
		return key::select_a_tile_with_a_town;
	}
	const Value taxonomy = field_or_new_dict(state, detail, key::taxonomy);
	const Atom taxonomy_summary = gd::is_dict(taxonomy) ? _taxonomy_inline_text(state, editor, taxonomy.ref) : static_cast<Atom>(key::empty);
	const Atom kind = text_or(state, detail, key::kind, key::empty);
	if (kind == key::town) {
		return taxonomy_summary != key::empty ? gd::format(state, key::town_owner_edit_s, { str(taxonomy_summary) }) : static_cast<Atom>(key::town_owner_edits_mutate_the_working);
	}
	if (kind == key::resource) {
		return taxonomy_summary != key::empty ? gd::format(state, key::site_collected_edit_s, { str(taxonomy_summary) }) : static_cast<Atom>(key::site_collected_edits_mutate_the_working);
	}
	if (kind == key::artifact) {
		return taxonomy_summary != key::empty ? gd::format(state, key::artifact_collected_edit_s, { str(taxonomy_summary) }) : static_cast<Atom>(key::artifact_collected_edits_mutate_the_working);
	}
	if (kind == key::encounter) {
		return taxonomy_summary != key::empty ? gd::format(state, key::encounter_difficulty_edit_s, { str(taxonomy_summary) }) : static_cast<Atom>(key::encounter_difficulty_edits_mutate_the_working);
	}
	return key::no_mutable_object_property_is_available;
}

DictRef _selected_property_handoff_payload(State &state, const Value &editor, DictRef detail) {
	if (gd::is_empty(state, detail)) {
		const Atom empty_text = key::selection_handoff_choose_a_placed_town;
		const DictRef payload = state.new_dict();
		state.set(payload, str(key::visible_text), str(empty_text));
		state.set(payload, str(key::tooltip_text), str(gd::format(state, key::s_property_edits_stay_in_the, { str(empty_text) })));
		state.set(payload, str(key::apply_tooltip), str(key::select_a_mutable_placed_object_before));
		state.set(payload, str(key::scope), str(key::working_copy_only));
		state.set(payload, str(key::next_step_2), str(key::select_a_placed_editable_object));
		return payload;
	}
	const Atom kind = text_or(state, detail, key::kind, key::empty);
	const Atom kind_label = _object_family_label(state, editor, kind);
	const Value name_fallback = state.get(detail, str(key::content_id), str(key::empty));
	const Atom name = string_of(state, state.get(detail, str(key::name), name_fallback));
	const Atom placement_id = text_or(state, detail, key::placement_id, key::empty);
	const Atom tile_text = gd::format(state, key::d_d_3, { int_value(gd::int_field(state, detail, key::x, 0)), int_value(gd::int_field(state, detail, key::y, 0)) });
	Atom field_label = key::empty;
	Atom readiness = key::empty;
	Atom next_step = key::empty;
	Atom why = key::empty;
	if (kind == key::town) {
		field_label = key::Owner;
		readiness = gd::format(state, key::owner_s, { str(text_or(state, detail, key::owner, key::neutral)) });
		next_step = key::choose_owner_then_apply_properties;
		why = key::changes_control_state_for_this_working;
	} else if (kind == key::resource) {
		field_label = key::Collected;
		readiness = gd::format(state, key::collected_s_3, { str(gd::bool_field(state, detail, key::collected, false) ? key::yes : key::no) });
		next_step = key::toggle_collected_then_apply_properties;
		why = key::sets_whether_this_economy_node_is;
	} else if (kind == key::artifact) {
		field_label = key::Collected;
		readiness = gd::format(state, key::collected_s_3, { str(gd::bool_field(state, detail, key::collected, false) ? key::yes : key::no) });
		next_step = key::toggle_collected_then_apply_properties;
		why = key::sets_whether_this_reward_appears_on;
	} else if (kind == key::encounter) {
		field_label = key::Difficulty;
		readiness = gd::format(state, key::difficulty_s_2, { str(text_or(state, detail, key::difficulty, key::medium)) });
		next_step = key::choose_difficulty_then_apply_properties;
		why = key::changes_battle_pressure_for_this_working;
	} else {
		field_label = key::Properties;
		readiness = key::read_only;
		next_step = key::select_an_editable_object;
		why = key::no_mutable_property_is_available;
	}
	const Atom visible_text = gd::format(state, key::selection_handoff_s_s_at_s, {
			str(kind_label),
			str(name),
			str(tile_text),
			str(readiness),
			str(next_step),
	});
	const Atom tooltip = gd::format(state, key::selected_object_s_s_placement_s, {
			str(kind_label),
			str(name),
			str(placement_id),
			str(tile_text),
			str(field_label),
			str(readiness),
			str(why),
			str(next_step),
	});
	const DictRef payload = state.new_dict();
	state.set(payload, str(key::visible_text), str(visible_text));
	state.set(payload, str(key::tooltip_text), str(tooltip));
	state.set(payload, str(key::apply_tooltip), str(gd::format(state, key::s_apply_properties_updates_the_in, { str(tooltip) })));
	state.set(payload, str(key::kind), str(kind));
	state.set(payload, str(key::placement_id), str(placement_id));
	state.set(payload, str(key::content_id), str(text_or(state, detail, key::content_id, key::empty)));
	state.set(payload, str(key::name), str(name));
	state.set(payload, str(key::field), str(field_label));
	state.set(payload, str(key::readiness), str(readiness));
	state.set(payload, str(key::why_it_matters), str(why));
	state.set(payload, str(key::next_step_2), str(next_step));
	state.set(payload, str(key::scope), str(key::working_copy_only));
	state.set(payload, str(key::x), int_value(gd::int_field(state, detail, key::x, 0)));
	state.set(payload, str(key::y), int_value(gd::int_field(state, detail, key::y, 0)));
	return payload;
}

ArrayRef _property_object_options_at(State &state, const Value &editor, Vector2i tile) {
	const ArrayRef options = state.new_array();
	if (session(state, editor).kind == Kind::Nil || !_tile_in_bounds(state, editor, tile)) {
		return options;
	}
	const ArrayRef details = _object_details_at(state, editor, tile, false);
	for (const Value &detail : gd::items(state, array_value(details))) {
		if (!gd::is_dict(detail)) {
			continue;
		}
		const Atom kind = text_or(state, detail.ref, key::kind, key::empty);
		if (is_object_family(kind)) {
			state.append(options, detail);
		}
	}
	return options;
}

DictRef _selected_property_object_detail(State &state, const Value &editor) {
	const Atom selected_key = member_string(state, editor, key::_selected_property_object_key);
	if (selected_key == key::empty) {
		return state.new_dict();
	}
	const ArrayRef options = _property_object_options_at(state, editor, member_tile(state, editor, key::_selected_tile));
	for (const Value &detail : gd::items(state, array_value(options))) {
		if (gd::is_dict(detail) && text_or(state, detail.ref, key::property_key, key::empty) == selected_key) {
			return detail.ref;
		}
	}
	return state.new_dict();
}

DictRef _object_detail_by_key(State &state, const Value &editor, Atom property_key) {
	const Value current = session(state, editor);
	if (current.kind == Kind::Nil || property_key == key::empty) {
		return state.new_dict();
	}
	for (const Atom family : { key::town, key::resource, key::artifact, key::encounter }) {
		const Atom array_key = _placement_array_key(state, editor, family);
		const DictRef overworld = port::session_view::overworld(state, session_view(state, current));
		// _session.overworld.get(array_key, []): a missing one has no placements.
		Value placements;
		if (!state.lookup(overworld, str(array_key), placements) || !gd::is_array(placements)) {
			continue;
		}
		for (int64_t index = 0; index < state.array_size(placements.ref); ++index) {
			const Value placement = state.at(placements.ref, index);
			if (!gd::is_dict(placement)) {
				continue;
			}
			const Atom placement_id = text_or(state, placement.ref, key::placement_id, key::empty);
			if (_object_property_key(state, editor, family, placement_id) != property_key) {
				continue;
			}
			return _object_detail_for_placement(state, editor, family, placement.ref);
		}
	}
	return state.new_dict();
}

DictRef _selected_property_object_payload(State &state, const Value &editor) {
	const DictRef detail = _selected_property_object_detail(state, editor);
	return _property_object_payload_from_detail(state, editor, detail);
}

DictRef _property_object_payload_from_detail(State &state, const Value &editor, DictRef detail) {
	if (gd::is_empty(state, detail)) {
		return state.new_dict();
	}
	const Value taxonomy = field_or_new_dict(state, detail, key::taxonomy);
	Value guidance = field_or_new_dict(state, detail, key::placement_guidance);
	if (!gd::is_dict(guidance)) {
		guidance = dict_value(state.new_dict());
	}
	if (gd::is_empty(state, guidance.ref) && gd::is_dict(taxonomy)) {
		const Vector2i tile = Vector2i::of(gd::int_field(state, detail, key::x, 0), gd::int_field(state, detail, key::y, 0));
		guidance = dict_value(_placement_guidance_payload(state, editor, taxonomy.ref, tile));
	}
	const DictRef payload = state.new_dict();
	state.set(payload, str(key::property_key), str(text_or(state, detail, key::property_key, key::empty)));
	state.set(payload, str(key::kind), str(text_or(state, detail, key::kind, key::empty)));
	state.set(payload, str(key::placement_id), str(text_or(state, detail, key::placement_id, key::empty)));
	state.set(payload, str(key::content_id), str(text_or(state, detail, key::content_id, key::empty)));
	state.set(payload, str(key::name), str(text_or(state, detail, key::name, key::empty)));
	state.set(payload, str(key::editable_properties), array_value(_editable_properties_for_object(state, editor, text_or(state, detail, key::kind, key::empty))));
	state.set(payload, str(key::owner), str(text_or(state, detail, key::owner, key::empty)));
	state.set(payload, str(key::difficulty), str(text_or(state, detail, key::difficulty, key::empty)));
	state.set(payload, str(key::collected), bool_value(gd::bool_field(state, detail, key::collected, false)));
	state.set(payload, str(key::collected_by_faction_id), str(text_or(state, detail, key::collected_by_faction_id, key::empty)));
	state.set(payload, str(key::collected_day), int_value(std::max<int64_t>(0, gd::int_field(state, detail, key::collected_day, 0))));
	state.set(payload, str(key::taxonomy), field_or_new_dict(state, detail, key::taxonomy));
	state.set(payload, str(key::taxonomy_summary), str(text_or(state, detail, key::taxonomy_summary, key::empty)));
	state.set(payload, str(key::control_summary), str(text_or(state, detail, key::control_summary, key::empty)));
	state.set(payload, str(key::control_inspection), str(text_or(state, detail, key::control_inspection, key::empty)));
	state.set(payload, str(key::placement_guidance), guidance);
	state.set(payload, str(key::authoring_dependencies), field_or_new_dict(state, detail, key::authoring_dependencies));
	state.set(payload, str(key::x), int_value(gd::int_field(state, detail, key::x, 0)));
	state.set(payload, str(key::y), int_value(gd::int_field(state, detail, key::y, 0)));
	return payload;
}

DictRef _pending_move_object_payload(State &state, const Value &editor) {
	return _property_object_payload_from_detail(state, editor, _object_detail_by_key(state, editor, member_string(state, editor, key::_pending_move_object_key)));
}

DictRef _pending_duplicate_object_payload(State &state, const Value &editor) {
	return _property_object_payload_from_detail(state, editor, _object_detail_by_key(state, editor, member_string(state, editor, key::_pending_duplicate_object_key)));
}

bool _select_property_object_at_tile(State &state, const Value &editor, Atom family) {
	const ArrayRef options = _property_object_options_at(state, editor, member_tile(state, editor, key::_selected_tile));
	for (int64_t index = 0; index < state.array_size(options); ++index) {
		const Value detail = state.at(options, index);
		if (!gd::is_dict(detail)) {
			continue;
		}
		if (family != key::empty && text_or(state, detail.ref, key::kind, key::empty) != family) {
			continue;
		}
		const Atom property_key = text_or(state, detail.ref, key::property_key, key::empty);
		gd::set_member(state, editor, key::_selected_property_object_key, str(property_key));
		return property_key != key::empty;
	}
	gd::set_member(state, editor, key::_selected_property_object_key, str(key::empty));
	return false;
}

DictRef _apply_object_property_value(State &state, const Value &editor, Atom property_name, const Value &value) {
	const DictRef detail = _selected_property_object_detail(state, editor);
	if (gd::is_empty(state, detail)) {
		return refused(state, key::no_selected_object_property_target);
	}
	const Atom kind = text_or(state, detail, key::kind, key::empty);
	const Atom placement_id = text_or(state, detail, key::placement_id, key::empty);
	if (property_name == key::owner) {
		if (kind != key::town) {
			return refused(state, key::owner_is_only_editable_for_towns);
		}
		return _set_town_owner_property(state, editor, placement_id, string_of(state, value));
	}
	if (property_name == key::difficulty) {
		if (kind != key::encounter) {
			return refused(state, key::difficulty_is_only_editable_for_encounters);
		}
		return _set_encounter_difficulty_property(state, editor, placement_id, string_of(state, value));
	}
	if (property_name == key::collected) {
		if (kind != key::resource && kind != key::artifact) {
			return refused(state, key::collected_is_only_editable_for_sites);
		}
		return _set_collected_property(state, editor, kind, placement_id, gd::to_bool(value));
	}
	return refused(state, gd::format(state, key::unsupported_editable_property_s, { str(property_name) }));
}

Atom _property_object_label(State &state, const Value &editor, DictRef detail) {
	(void)editor;
	const Atom kind = text_or(state, detail, key::kind, key::empty);
	const Value name_fallback = state.get(detail, str(key::content_id), str(key::empty));
	const Atom name = string_of(state, state.get(detail, str(key::name), name_fallback));
	const Atom placement_id = text_or(state, detail, key::placement_id, key::empty);
	if (kind == key::town) {
		return gd::format(state, key::town_s_owner_s, { str(name), str(text_or(state, detail, key::owner, key::neutral)) });
	}
	if (kind == key::resource) {
		return gd::format(state, key::site_s_collected_s, { str(name), str(gd::bool_field(state, detail, key::collected, false) ? key::yes : key::no) });
	}
	if (kind == key::artifact) {
		return gd::format(state, key::artifact_s_collected_s, { str(name), str(gd::bool_field(state, detail, key::collected, false) ? key::yes : key::no) });
	}
	if (kind == key::encounter) {
		return gd::format(state, key::encounter_s_s, { str(name), str(text_or(state, detail, key::difficulty, key::medium)) });
	}
	return gd::format(state, key::s_s_text, { str(gd::capitalize(state, kind)), str(placement_id) });
}

ArrayRef _terrain_items(State &state, const Value &editor) {
	const DictRef grammar = gd::content_file(state, key::terrain_grammar_path);
	const DictRef class_index = _terrain_class_index(state, editor, grammar);
	const ArrayRef curated_items = state.new_array();
	// grammar.get(TERRAIN_OPTION_SOURCE, []): a missing one has no options.
	Value curated_options;
	if (state.lookup(grammar, str(key::editor_base_terrain_options), curated_options) && gd::is_array(curated_options)) {
		for (const Value &option : gd::items(state, curated_options)) {
			if (!gd::is_dict(option)) {
				continue;
			}
			const Atom option_id = text_or(state, option.ref, key::id, key::empty);
			if (option_id == key::empty || !state.has(class_index, str(option_id))) {
				continue;
			}
			const DictRef terrain_class = gd::as_dict(state.get(class_index, str(option_id), Value()));
			// option.get("label", terrain_class.get("label", option_id.capitalize())): the
			// fallbacks are only read when the keys are missing.
			Value label;
			if (!state.lookup(option.ref, str(key::label), label) && !state.lookup(terrain_class, str(key::label), label)) {
				label = str(gd::capitalize(state, option_id));
			}
			const DictRef item = state.new_dict();
			state.set(item, str(key::id), str(option_id));
			state.set(item, str(key::label), str(string_of(state, label)));
			state.set(item, str(key::homm3_family), str(text_or(state, option.ref, key::homm3_family, key::empty)));
			state.set(item, str(key::homm3_atlas), str(text_or(state, option.ref, key::homm3_atlas, key::empty)));
			state.append(curated_items, dict_value(item));
		}
	}
	if (state.array_size(curated_items) != 0) {
		return curated_items;
	}
	const ArrayRef items = state.new_array();
	// grammar.get("terrain_classes", []): a missing one has no classes.
	Value classes;
	if (!state.lookup(grammar, str(key::terrain_classes), classes) || !gd::is_array(classes)) {
		return items;
	}
	for (const Value &terrain_class : gd::items(state, classes)) {
		if (!gd::is_dict(terrain_class)) {
			continue;
		}
		const Atom terrain_id = text_or(state, terrain_class.ref, key::id, key::empty);
		if (terrain_id == key::empty) {
			continue;
		}
		Value label;
		if (!state.lookup(terrain_class.ref, str(key::label), label)) {
			label = str(gd::capitalize(state, terrain_id));
		}
		const DictRef item = state.new_dict();
		state.set(item, str(key::id), str(terrain_id));
		state.set(item, str(key::label), str(string_of(state, label)));
		state.append(items, dict_value(item));
	}
	return items;
}

DictRef _terrain_class_index(State &state, const Value &editor, DictRef grammar) {
	(void)editor;
	const DictRef index = state.new_dict();
	// grammar.get("terrain_classes", []): a missing one has no classes.
	Value classes;
	if (!state.lookup(grammar, str(key::terrain_classes), classes) || !gd::is_array(classes)) {
		return index;
	}
	for (const Value &terrain_class : gd::items(state, classes)) {
		if (!gd::is_dict(terrain_class)) {
			continue;
		}
		const Atom terrain_id = text_or(state, terrain_class.ref, key::id, key::empty);
		if (terrain_id != key::empty) {
			state.set(index, str(terrain_id), terrain_class);
		}
	}
	return index;
}

Atom _terrain_label_for_id(State &state, const Value &editor, Atom terrain_id) {
	const Value entries = gd::member(state, editor, key::_terrain_entries);
	for (const Value &entry : gd::items(state, entries)) {
		if (!gd::is_dict(entry)) {
			continue;
		}
		if (text_or(state, entry.ref, key::id, key::empty) == terrain_id) {
			// entry.get("label", terrain_id.capitalize()): the fallback only when the key is missing.
			Value label;
			if (state.lookup(entry.ref, str(key::label), label)) {
				return string_of(state, label);
			}
			return gd::capitalize(state, terrain_id);
		}
	}
	return gd::capitalize(state, terrain_id);
}

ArrayRef _terrain_option_payload(State &state, const Value &editor) {
	const ArrayRef options = state.new_array();
	const Value entries = gd::member(state, editor, key::_terrain_entries);
	for (const Value &entry : gd::items(state, entries)) {
		if (!gd::is_dict(entry)) {
			continue;
		}
		const DictRef option = state.new_dict();
		state.set(option, str(key::id), str(text_or(state, entry.ref, key::id, key::empty)));
		state.set(option, str(key::label), str(text_or(state, entry.ref, key::label, key::empty)));
		state.set(option, str(key::homm3_family), str(text_or(state, entry.ref, key::homm3_family, key::empty)));
		state.set(option, str(key::homm3_atlas), str(text_or(state, entry.ref, key::homm3_atlas, key::empty)));
		state.append(options, dict_value(option));
	}
	return options;
}

ArrayRef _terrain_option_ids(State &state, const Value &editor) {
	const ArrayRef ids = state.new_array();
	const Value entries = gd::member(state, editor, key::_terrain_entries);
	for (const Value &entry : gd::items(state, entries)) {
		if (gd::is_dict(entry)) {
			state.append(ids, str(text_or(state, entry.ref, key::id, key::empty)));
		}
	}
	return ids;
}

ArrayRef _authored_terrain_ids(State &state, const Value &editor) {
	(void)editor;
	const DictRef grammar = gd::content_file(state, key::terrain_grammar_path);
	const ArrayRef ids = state.new_array();
	// grammar.get("terrain_classes", []): a missing one has no classes.
	Value classes;
	if (!state.lookup(grammar, str(key::terrain_classes), classes) || !gd::is_array(classes)) {
		return ids;
	}
	for (const Value &terrain_class : gd::items(state, classes)) {
		if (!gd::is_dict(terrain_class)) {
			continue;
		}
		const Atom terrain_id = text_or(state, terrain_class.ref, key::id, key::empty);
		if (terrain_id != key::empty) {
			state.append(ids, str(terrain_id));
		}
	}
	return ids;
}

ArrayRef _hidden_terrain_ids(State &state, const Value &editor) {
	const ArrayRef option_ids = _terrain_option_ids(state, editor);
	const ArrayRef hidden = state.new_array();
	const ArrayRef authored = _authored_terrain_ids(state, editor);
	for (const Value &terrain_id : gd::items(state, array_value(authored))) {
		if (!gd::array_has(state, option_ids, terrain_id)) {
			state.append(hidden, terrain_id);
		}
	}
	return hidden;
}

ArrayRef _object_content_items(State &state, const Value &editor, Atom family) {
	const Atom path = _object_content_path(state, editor, family);
	if (path == key::empty) {
		return state.new_array();
	}
	const DictRef raw = gd::content_file(state, path);
	const ArrayRef items = state.new_array();
	// raw.get("items", []): a missing one has no items.
	Value raw_items;
	if (!state.lookup(raw, str(key::items), raw_items) || !gd::is_array(raw_items)) {
		return items;
	}
	for (const Value &item : gd::items(state, raw_items)) {
		if (!gd::is_dict(item)) {
			continue;
		}
		const Atom content_id = text_or(state, item.ref, key::id, key::empty);
		if (content_id == key::empty) {
			continue;
		}
		const Value label_fallback = state.get(item.ref, str(key::label), str(content_id));
		const DictRef entry = state.new_dict();
		state.set(entry, str(key::id), str(content_id));
		state.set(entry, str(key::name), str(string_of(state, state.get(item.ref, str(key::name), label_fallback))));
		state.set(entry, str(key::family), str(text_or(state, item.ref, key::family, key::empty)));
		state.append(items, dict_value(entry));
	}
	return items;
}

Atom _object_content_path(State &state, const Value &editor, Atom family) {
	(void)state;
	(void)editor;
	if (family == key::town) {
		return key::towns_path;
	}
	if (family == key::resource) {
		return key::resource_sites_path;
	}
	if (family == key::artifact) {
		return key::artifacts_path;
	}
	if (family == key::encounter) {
		return key::encounters_path;
	}
	return key::empty;
}

Atom _object_content_label(State &state, const Value &editor, DictRef entry) {
	(void)editor;
	const Atom content_id = text_or(state, entry, key::id, key::empty);
	const Atom label = text_or(state, entry, key::name, content_id);
	const Atom family = text_or(state, entry, key::family, key::empty);
	if (family != key::empty) {
		return gd::format(state, key::s_s_text, { str(label), str(family) });
	}
	return label;
}

DictRef _object_content_taxonomy_payload(State &state, const Value &editor, Atom family, Atom content_id) {
	if (content_id == key::empty) {
		return state.new_dict();
	}
	if (family == key::town) {
		const DictRef town = gd::content_row(state, ContentTable::Town, content_id);
		if (gd::is_empty(state, town)) {
			return state.new_dict();
		}
		return _town_taxonomy_payload(state, editor, town);
	}
	if (family == key::resource) {
		const DictRef site = gd::content_row(state, ContentTable::ResourceSite, content_id);
		if (gd::is_empty(state, site)) {
			return state.new_dict();
		}
		const DictRef node = state.new_dict();
		state.set(node, str(key::site_id), str(content_id));
		return _resource_taxonomy_payload(state, editor, node, site);
	}
	if (family == key::artifact) {
		const DictRef artifact = gd::content_row(state, ContentTable::Artifact, content_id);
		if (gd::is_empty(state, artifact)) {
			return state.new_dict();
		}
		return _artifact_taxonomy_payload(state, editor, artifact);
	}
	if (family == key::encounter) {
		const DictRef encounter = gd::content_row(state, ContentTable::Encounter, content_id);
		if (gd::is_empty(state, encounter)) {
			return state.new_dict();
		}
		const DictRef placement = state.new_dict();
		state.set(placement, str(key::encounter_id), str(content_id));
		state.set(placement, str(key::difficulty), str(key::medium));
		return _encounter_taxonomy_payload(state, editor, placement, encounter);
	}
	return state.new_dict();
}

DictRef _town_taxonomy_payload(State &state, const Value &editor, DictRef town) {
	(void)editor;
	const Atom faction_id = text_or(state, town, key::faction_id, key::empty);
	const DictRef faction = gd::content_row(state, ContentTable::Faction, faction_id);
	const ArrayRef tags = state.new_array();
	state.append(tags, str(key::settlement));
	state.append(tags, str(key::production));
	state.append(tags, str(key::ownership));
	if (faction_id != key::empty) {
		state.append(tags, str(key::faction_presence));
	}
	const DictRef town_state = state.new_dict();
	state.set(town_state, str(key::town_id), str(text_or(state, town, key::id, key::empty)));
	state.set(town_state, str(key::built_buildings), field_or_new_array(state, town, key::starting_building_ids));
	const DictRef payload = state.new_dict();
	state.set(payload, str(key::primary_class), str(key::town));
	state.set(payload, str(key::secondary_tags), array_value(tags));
	state.set(payload, str(key::cadence), str(key::persistent_control));
	state.set(payload, str(key::passability_class), str(key::town_blocking));
	state.set(payload, str(key::content_link_label), str(key::Town));
	state.set(payload, str(key::content_link_id), str(text_or(state, town, key::id, key::empty)));
	state.set(payload, str(key::object_family), str(key::town));
	state.set(payload, str(key::summary), str(key::town_cadence_persistent_control_passability_town));
	const Atom detail = faction_id != key::empty
			? gd::format(state, key::faction_s, { str(text_or(state, faction, key::name, faction_id)) })
			: static_cast<Atom>(key::empty);
	state.set(payload, str(key::detail), str(detail));
	state.set(payload, str(key::town_role), str(text_or(state, town, key::strategic_role, key::frontier)));
	state.set(payload, str(key::identity_summary), str(overworld_rules::describe_town_identity_surface(state, town_state, Value())));
	return payload;
}

DictRef _artifact_taxonomy_payload(State &state, const Value &editor, DictRef artifact) {
	(void)editor;
	const ArrayRef tags = state.new_array();
	state.append(tags, str(key::reward));
	state.append(tags, str(key::hero_progression));
	const DictRef payload = state.new_dict();
	state.set(payload, str(key::primary_class), str(key::artifact_reward));
	state.set(payload, str(key::secondary_tags), array_value(tags));
	state.set(payload, str(key::cadence), str(key::one_time));
	state.set(payload, str(key::passability_class), str(key::passable_visit_on_enter));
	state.set(payload, str(key::content_link_label), str(key::Artifact));
	state.set(payload, str(key::content_link_id), str(text_or(state, artifact, key::id, key::empty)));
	state.set(payload, str(key::object_family), str(key::artifact));
	state.set(payload, str(key::summary), str(key::artifact_reward_cadence_one_time_passability));
	state.set(payload, str(key::detail), str(text_or(state, artifact, key::slot, key::empty)));
	return payload;
}

DictRef _resource_taxonomy_payload(State &state, const Value &editor, DictRef node, DictRef site) {
	const Value id_fallback = state.get(node, str(key::site_id), str(key::empty));
	const Atom site_id = string_of(state, state.get(site, str(key::id), id_fallback));
	const DictRef map_object = gd::content_row(state, ContentTable::MapObjectForResourceSite, site_id);
	Atom primary_class = gd::strip_edges(state, text_or(state, map_object, key::primary_class, key::empty));
	if (primary_class == key::empty) {
		primary_class = _fallback_resource_primary_class(state, editor, site);
	}
	ArrayRef secondary_tags = _string_array_for_editor(state, editor, field_or_new_array(state, map_object, key::secondary_tags));
	if (state.array_size(secondary_tags) == 0) {
		secondary_tags = _string_array_for_editor(state, editor, field_or_new_array(state, map_object, key::map_roles));
	}
	if (state.array_size(secondary_tags) == 0) {
		secondary_tags = _fallback_resource_tags(state, editor, site);
	}
	// map_object.get("interaction", {}): a missing one has no cadence.
	Atom cadence = key::empty;
	Value interaction;
	if (state.lookup(map_object, str(key::interaction), interaction) && gd::is_dict(interaction)) {
		cadence = gd::strip_edges(state, text_or(state, interaction.ref, key::cadence, key::empty));
	}
	if (cadence == key::empty) {
		cadence = _fallback_resource_cadence(state, editor, site);
	}
	Atom passability_class = gd::strip_edges(state, text_or(state, map_object, key::passability_class, key::empty));
	if (passability_class == key::empty) {
		passability_class = _fallback_passability_class(state, editor, map_object, text_or(state, site, key::family, key::empty));
	}
	const Atom footprint = _footprint_summary(state, editor, field_or_new_dict(state, map_object, key::footprint));
	const Atom surface = overworld_rules::describe_resource_site_interaction_surface(state, node, site);
	Atom recruit_source_summary = key::empty;
	Atom recruit_source_inspection = key::empty;
	Atom live_surface = key::empty;
	Atom control_summary = key::empty;
	Atom control_inspection = key::empty;
	const Value current = session(state, editor);
	if (overworld_rules::resource_site_is_recruit_source(state, site)) {
		// The session as the ports take it: its view, or Nil before a map is loaded.
		const Value session_value = current.kind == Kind::Nil ? Value() : dict_value(session_view(state, current));
		recruit_source_summary = overworld_rules::describe_recruit_source_compact(state, session_value, node, site);
		recruit_source_inspection = overworld_rules::describe_recruit_source_inspection(state, session_value, node, site);
	}
	if (current.kind != Kind::Nil) {
		const DictRef view = session_view(state, current);
		live_surface = overworld_rules::describe_resource_site_surface(state, view, node, site);
		control_summary = overworld_rules::describe_resource_site_control_summary(state, view, node, site);
		control_inspection = overworld_rules::describe_resource_site_control_inspection(state, dict_value(view), node, site);
	}
	const DictRef payload = state.new_dict();
	state.set(payload, str(key::primary_class), str(primary_class));
	state.set(payload, str(key::secondary_tags), array_value(secondary_tags));
	state.set(payload, str(key::cadence), str(cadence));
	state.set(payload, str(key::passability_class), str(passability_class));
	state.set(payload, str(key::content_link_label), str(key::resource_site_3));
	state.set(payload, str(key::content_link_id), str(site_id));
	state.set(payload, str(key::resource_site_id), str(site_id));
	state.set(payload, str(key::map_object_id), str(text_or(state, map_object, key::id, key::empty)));
	state.set(payload, str(key::map_object_name), str(text_or(state, map_object, key::name, key::empty)));
	const Value family_fallback = state.get(site, str(key::family), str(key::one_shot_pickup));
	state.set(payload, str(key::object_family), str(string_of(state, state.get(map_object, str(key::family), family_fallback))));
	state.set(payload, str(key::site_family), str(text_or(state, site, key::family, key::one_shot_pickup)));
	state.set(payload, str(key::footprint), str(footprint));
	state.set(payload, str(key::summary), str(surface));
	state.set(payload, str(key::detail), str(live_surface));
	state.set(payload, str(key::control_summary), str(control_summary));
	state.set(payload, str(key::control_inspection), str(control_inspection));
	state.set(payload, str(key::recruit_source_summary), str(recruit_source_summary));
	state.set(payload, str(key::recruit_source_inspection), str(recruit_source_inspection));
	return payload;
}

DictRef _encounter_taxonomy_payload(State &state, const Value &editor, DictRef placement, DictRef encounter) {
	const DictRef map_object = gd::content_row(state, ContentTable::MapObject, text_or(state, placement, key::object_id, key::empty));
	Value neutral_value = field_or_new_dict(state, placement, key::neutral_encounter);
	if (!gd::is_dict(neutral_value) || gd::is_empty(state, neutral_value.ref)) {
		neutral_value = field_or_new_dict(state, map_object, key::neutral_encounter);
	}
	if (!gd::is_dict(neutral_value)) {
		neutral_value = dict_value(state.new_dict());
	}
	const DictRef neutral_metadata = neutral_value.ref;
	const Value primary_fallback = state.get(placement, str(key::primary_class), str(key::empty));
	Atom primary_class = gd::strip_edges(state, string_of(state, state.get(map_object, str(key::primary_class), primary_fallback)));
	if (primary_class == key::empty) {
		primary_class = gd::strip_edges(state, text_or(state, neutral_metadata, key::primary_class, key::neutral_encounter));
	}
	ArrayRef secondary_tags = _string_array_for_editor(state, editor, field_or_new_array(state, map_object, key::secondary_tags));
	if (state.array_size(secondary_tags) == 0) {
		secondary_tags = _string_array_for_editor(state, editor, field_or_new_array(state, neutral_metadata, key::secondary_tags));
	}
	if (state.array_size(secondary_tags) == 0) {
		secondary_tags = state.new_array();
		state.append(secondary_tags, str(key::visible_army));
	}
	// map_object.get("interaction", {}): a missing one has no cadence.
	Atom cadence = key::empty;
	Value interaction;
	if (state.lookup(map_object, str(key::interaction), interaction) && gd::is_dict(interaction)) {
		cadence = gd::strip_edges(state, text_or(state, interaction.ref, key::cadence, key::empty));
	}
	if (cadence == key::empty) {
		cadence = key::one_time;
	}
	Atom passability_class = gd::strip_edges(state, text_or(state, map_object, key::passability_class, key::empty));
	// neutral_metadata.get("passability", {}): a missing one has no class.
	Value passability;
	if (passability_class == key::empty && state.lookup(neutral_metadata, str(key::passability), passability) && gd::is_dict(passability)) {
		passability_class = gd::strip_edges(state, text_or(state, passability.ref, key::passability_class, key::empty));
	}
	if (passability_class == key::empty) {
		passability_class = key::neutral_stack_blocking;
	}
	// neutral_metadata.get("representation", {}): a missing one has no mode.
	Atom role = key::empty;
	Value representation;
	if (state.lookup(neutral_metadata, str(key::representation), representation) && gd::is_dict(representation)) {
		role = gd::strip_edges(state, text_or(state, representation.ref, key::mode, key::empty));
	}
	if (role == key::empty) {
		role = _fallback_encounter_role(state, editor, secondary_tags);
	}
	// neutral_metadata.get("reward_guard_summary", {}): a missing one has no risk tier.
	Atom risk = key::empty;
	Value reward_guard;
	if (state.lookup(neutral_metadata, str(key::reward_guard_summary), reward_guard) && gd::is_dict(reward_guard)) {
		risk = gd::strip_edges(state, text_or(state, reward_guard.ref, key::risk_tier, key::empty));
	}
	if (risk == key::empty) {
		risk = _risk_from_difficulty(state, editor, text_or(state, placement, key::difficulty, key::medium));
	}
	Value guard_value = field_or_new_dict(state, placement, key::guard_link);
	if (!gd::is_dict(guard_value)) {
		guard_value = field_or_new_dict(state, neutral_metadata, key::guard_link);
	}
	if (!gd::is_dict(guard_value)) {
		guard_value = dict_value(state.new_dict());
	}
	const DictRef guard = guard_value.ref;
	Atom surface = overworld_rules::describe_encounter_object_surface(state, placement);
	if (surface == key::empty) {
		surface = gd::format(state, key::neutral_encounter_risk_s_cadence_one, { str(_humanize_editor_id(state, editor, risk)) });
	}
	Atom guard_surface = key::empty;
	Atom consequence_surface = key::empty;
	Atom readiness_surface = key::empty;
	const Value current = session(state, editor);
	if (current.kind != Kind::Nil) {
		const DictRef view = session_view(state, current);
		guard_surface = overworld_rules::describe_encounter_guard_link_surface(state, view, placement);
		consequence_surface = overworld_rules::describe_encounter_consequence_surface(state, view, placement, false);
		readiness_surface = overworld_rules::describe_encounter_compact_readability(state, view, placement);
	}
	const DictRef payload = state.new_dict();
	state.set(payload, str(key::primary_class), str(primary_class));
	state.set(payload, str(key::secondary_tags), array_value(secondary_tags));
	state.set(payload, str(key::cadence), str(cadence));
	state.set(payload, str(key::passability_class), str(passability_class));
	state.set(payload, str(key::content_link_label), str(key::Encounter));
	const Value encounter_id_fallback = state.get(placement, str(key::encounter_id), str(key::empty));
	state.set(payload, str(key::content_link_id), str(string_of(state, state.get(encounter, str(key::id), encounter_id_fallback))));
	state.set(payload, str(key::map_object_id), str(text_or(state, map_object, key::id, key::empty)));
	state.set(payload, str(key::object_placement_id), str(text_or(state, placement, key::object_placement_id, key::empty)));
	state.set(payload, str(key::object_family), str(text_or(state, map_object, key::family, key::neutral_encounter)));
	state.set(payload, str(key::encounter_role), str(role));
	state.set(payload, str(key::risk_tier), str(risk));
	state.set(payload, str(key::guard_role), str(text_or(state, guard, key::guard_role, key::empty)));
	state.set(payload, str(key::guard_target_id), str(text_or(state, guard, key::target_id, key::empty)));
	state.set(payload, str(key::guard_target_placement_id), str(text_or(state, guard, key::target_placement_id, key::empty)));
	state.set(payload, str(key::guard_link_surface), str(guard_surface));
	state.set(payload, str(key::consequence_summary), str(consequence_surface));
	state.set(payload, str(key::readiness_summary), str(readiness_surface));
	state.set(payload, str(key::summary), str(surface));
	state.set(payload, str(key::detail), str(_encounter_detail_summary(state, editor, encounter, placement, risk, role, guard)));
	return payload;
}

Atom _taxonomy_summary_text(State &state, const Value &editor, DictRef payload) {
	if (gd::is_empty(state, payload)) {
		return key::empty;
	}
	const ArrayRef lines = state.new_array();
	const Atom class_label = _humanize_editor_id(state, editor, text_or(state, payload, key::primary_class, key::empty));
	const Atom cadence_label = _humanize_editor_id(state, editor, text_or(state, payload, key::cadence, key::empty));
	const Atom passability_label = _humanize_editor_id(state, editor, text_or(state, payload, key::passability_class, key::empty));
	state.append(lines, str(gd::format(state, key::class_s_cadence_s_passability_s, { str(class_label), str(cadence_label), str(passability_label) })));
	const Atom tag_summary = _tag_summary_for_editor(state, editor, field_or_new_array(state, payload, key::secondary_tags), 3);
	if (tag_summary != key::empty) {
		state.append(lines, str(gd::format(state, key::tags_s_2, { str(tag_summary) })));
	}
	const Atom link_line = _taxonomy_link_line(state, editor, payload);
	if (link_line != key::empty) {
		state.append(lines, str(link_line));
	}
	const Atom role_line = _taxonomy_role_line(state, editor, payload);
	if (role_line != key::empty) {
		state.append(lines, str(role_line));
	}
	const Atom guard_link_surface = gd::strip_edges(state, text_or(state, payload, key::guard_link_surface, key::empty));
	if (guard_link_surface != key::empty) {
		state.append(lines, str(gd::format(state, key::guard_link_s, { str(guard_link_surface) })));
	}
	const Atom consequence_summary = gd::strip_edges(state, text_or(state, payload, key::consequence_summary, key::empty));
	if (consequence_summary != key::empty) {
		state.append(lines, str(consequence_summary));
	}
	ai::append_array(state, lines, _recruit_source_summary_lines_for_editor(state, editor, payload, 2));
	ai::append_array(state, lines, _identity_summary_lines_for_editor(state, editor, payload, 3));
	return join_array(state, key::newline, lines);
}

Atom _taxonomy_inline_text(State &state, const Value &editor, DictRef payload) {
	if (gd::is_empty(state, payload)) {
		return key::empty;
	}
	std::vector<Atom> parts;
	const Atom primary_class = text_or(state, payload, key::primary_class, key::empty);
	if (primary_class != key::empty) {
		parts.push_back(gd::format(state, key::class_s_2, { str(_humanize_editor_id(state, editor, primary_class)) }));
	}
	const Atom cadence = text_or(state, payload, key::cadence, key::empty);
	if (cadence != key::empty) {
		parts.push_back(gd::format(state, key::cadence_s_2, { str(_humanize_editor_id(state, editor, cadence)) }));
	}
	const Atom passability_class = text_or(state, payload, key::passability_class, key::empty);
	if (passability_class != key::empty) {
		parts.push_back(gd::format(state, key::pass_s, { str(_humanize_editor_id(state, editor, passability_class)) }));
	}
	const Atom tag_summary = _tag_summary_for_editor(state, editor, field_or_new_array(state, payload, key::secondary_tags), 2);
	if (tag_summary != key::empty) {
		parts.push_back(gd::format(state, key::tags_s_3, { str(tag_summary) }));
	}
	return join_texts(state, key::space_bar_space, parts);
}

Atom _taxonomy_link_line(State &state, const Value &editor, DictRef payload) {
	(void)editor;
	std::vector<Atom> links;
	const Atom map_object_id = gd::strip_edges(state, text_or(state, payload, key::map_object_id, key::empty));
	if (map_object_id != key::empty) {
		links.push_back(gd::format(state, key::object_s, { str(map_object_id) }));
	}
	const Atom resource_site_id = gd::strip_edges(state, text_or(state, payload, key::resource_site_id, key::empty));
	if (resource_site_id != key::empty) {
		links.push_back(gd::format(state, key::site_s, { str(resource_site_id) }));
	}
	const Atom content_link_id = gd::strip_edges(state, text_or(state, payload, key::content_link_id, key::empty));
	if (links.empty() && content_link_id != key::empty) {
		links.push_back(gd::format(state, key::s_s, { str(text_or(state, payload, key::content_link_label, key::Content)), str(content_link_id) }));
	}
	const Atom footprint = gd::strip_edges(state, text_or(state, payload, key::footprint, key::empty));
	if (footprint != key::empty) {
		links.push_back(gd::format(state, key::footprint_s, { str(footprint) }));
	}
	return join_texts(state, key::space_bar_space, links);
}

Atom _taxonomy_role_line(State &state, const Value &editor, DictRef payload) {
	const Atom role = gd::strip_edges(state, text_or(state, payload, key::encounter_role, key::empty));
	const Atom risk = gd::strip_edges(state, text_or(state, payload, key::risk_tier, key::empty));
	const Atom guard_role = gd::strip_edges(state, text_or(state, payload, key::guard_role, key::empty));
	const Value target_fallback = state.get(payload, str(key::guard_target_id), str(key::empty));
	const Atom guard_target = gd::strip_edges(state, string_of(state, state.get(payload, str(key::guard_target_placement_id), target_fallback)));
	std::vector<Atom> parts;
	if (role != key::empty) {
		parts.push_back(gd::format(state, key::role_s_3, { str(_humanize_editor_id(state, editor, role)) }));
	}
	if (risk != key::empty) {
		parts.push_back(gd::format(state, key::risk_s, { str(_humanize_editor_id(state, editor, risk)) }));
	}
	if (guard_role != key::empty) {
		Atom guard_text = gd::format(state, key::guard_s_2, { str(_humanize_editor_id(state, editor, guard_role)) });
		if (guard_target != key::empty) {
			guard_text = gd::format(state, key::s_s_17, { str(guard_text), str(guard_target) });
		}
		parts.push_back(guard_text);
	}
	const Atom site_family = gd::strip_edges(state, text_or(state, payload, key::site_family, key::empty));
	if (parts.empty() && site_family != key::empty) {
		parts.push_back(gd::format(state, key::site_family_s, { str(_humanize_editor_id(state, editor, site_family)) }));
	}
	return join_texts(state, key::space_bar_space, parts);
}

ArrayRef _identity_summary_lines_for_editor(State &state, const Value &editor, DictRef payload, int64_t limit) {
	(void)editor;
	const Atom identity_summary = gd::strip_edges(state, text_or(state, payload, key::identity_summary, key::empty));
	if (identity_summary == key::empty) {
		return state.new_array();
	}
	return summary_lines(state, identity_summary, limit);
}

ArrayRef _recruit_source_summary_lines_for_editor(State &state, const Value &editor, DictRef payload, int64_t limit) {
	(void)editor;
	const Atom inspection = gd::strip_edges(state, text_or(state, payload, key::recruit_source_inspection, key::empty));
	if (inspection == key::empty) {
		return state.new_array();
	}
	return summary_lines(state, inspection, limit);
}

Atom _object_palette_guidance_text(State &state, const Value &editor, DictRef payload, DictRef guidance) {
	if (gd::is_empty(state, payload)) {
		return key::empty;
	}
	const ArrayRef lines = state.new_array();
	const Atom class_label = _humanize_editor_id(state, editor, text_or(state, payload, key::primary_class, key::empty));
	const Atom cadence_label = _humanize_editor_id(state, editor, text_or(state, payload, key::cadence, key::empty));
	const Atom passability_label = _humanize_editor_id(state, editor, text_or(state, payload, key::passability_class, key::empty));
	state.append(lines, str(gd::format(state, key::class_s_cadence_s_passability_s, { str(class_label), str(cadence_label), str(passability_label) })));
	if (!gd::is_empty(state, guidance)) {
		state.append(lines, str(gd::format(state, key::place_s_density_s, {
				str(text_or(state, guidance, key::placement_role, key::empty)),
				str(text_or(state, guidance, key::density_target, key::empty)),
		})));
		state.append(lines, str(gd::format(state, key::flags_s_local_d_in_16x16, {
				str(text_or(state, guidance, key::role_flags_text, key::empty)),
				int_value(gd::int_field(state, guidance, key::local_density_count, 0)),
		})));
	} else {
		const Atom tag_summary = _tag_summary_for_editor(state, editor, field_or_new_array(state, payload, key::secondary_tags), 3);
		if (tag_summary != key::empty) {
			state.append(lines, str(gd::format(state, key::tags_s_2, { str(tag_summary) })));
		}
	}
	const DictRef preview = _selected_object_placement_preview_payload(state, editor, _placement_preview_tile(state, editor));
	const DictRef preview_check = _editor_object_preview_check_payload(state, editor);
	const Atom preview_check_text = gd::strip_edges(state, text_or(state, preview_check, key::text, key::empty));
	if (preview_check_text != key::empty) {
		state.append(lines, str(preview_check_text));
	}
	const Atom preview_text = gd::strip_edges(state, text_or(state, preview, key::text, key::empty));
	if (preview_text != key::empty) {
		for (const std::string &raw_line : split_text(state.text(preview_text), "\n", true)) {
			const std::string line = strip_text(raw_line);
			if (!line.empty()) {
				state.append(lines, str(state.intern(line)));
			}
		}
	}
	const Atom link_line = _taxonomy_link_line(state, editor, payload);
	if (link_line != key::empty) {
		state.append(lines, str(link_line));
	}
	const Atom tile_dependency = _selected_tile_authoring_dependency_text(state, editor);
	if (tile_dependency != key::empty) {
		state.append(lines, str(tile_dependency));
	}
	ai::append_array(state, lines, _recruit_source_summary_lines_for_editor(state, editor, payload, 2));
	ai::append_array(state, lines, _identity_summary_lines_for_editor(state, editor, payload, 2));
	return join_array(state, key::newline, lines);
}

Vector2i _placement_preview_tile(State &state, const Value &editor) {
	const Vector2i hovered_tile = member_tile(state, editor, key::_hovered_tile);
	if (member_string(state, editor, key::_tool) == key::place_object && _tile_in_bounds(state, editor, hovered_tile)) {
		return hovered_tile;
	}
	return member_tile(state, editor, key::_selected_tile);
}

DictRef _selected_object_placement_preview_payload(State &state, const Value &editor, Vector2i tile) {
	// Several status surfaces show the same hover preview; build it once per
	// edit revision, tile and palette choice. Callers must not mutate it.
	const Atom memo_key = gd::format(state, key::placement_preview_d_d_s_s, {
			int_value(tile.x),
			int_value(tile.y),
			str(member_string(state, editor, key::_selected_object_family)),
			str(member_string(state, editor, key::_selected_object_content_id)),
	});
	const Value memo = _editor_validation_memo_lookup(state, editor, memo_key);
	if (gd::is_dict(memo)) {
		return memo.ref;
	}
	const DictRef preview = _build_selected_object_placement_preview_payload(state, editor, tile);
	state.set(gd::as_dict(gd::member(state, editor, key::_editor_validation_memo)), str(memo_key), dict_value(preview));
	return preview;
}

DictRef _build_selected_object_placement_preview_payload(State &state, const Value &editor, Vector2i tile) {
	const Atom family = member_string(state, editor, key::_selected_object_family);
	const Atom content_id = member_string(state, editor, key::_selected_object_content_id);
	const DictRef payload = _object_content_taxonomy_payload(state, editor, family, content_id);
	if (gd::is_empty(state, payload) || family == key::empty || content_id == key::empty) {
		return state.new_dict();
	}
	const DictRef guidance = _placement_guidance_payload(state, editor, payload, tile);
	const DictRef availability = _placement_availability_for_selected_object(state, editor, tile);
	const ArrayRef context_lines = _placement_context_lines(state, editor, family, content_id, payload, tile);
	const Atom density_warning = _density_warning_for_guidance(state, editor, guidance, gd::bool_field(state, availability, key::can_place, false));
	const Atom dependency_warning = _placement_dependency_warning(state, editor, payload);
	const Atom consequence = _placement_authoring_consequence(state, editor, family, content_id, payload, guidance);
	const ArrayRef warning_lines = state.new_array();
	const Atom blocked_reason = gd::strip_edges(state, text_or(state, availability, key::blocked_reason, key::empty));
	if (blocked_reason != key::empty) {
		state.append(warning_lines, str(blocked_reason));
	}
	if (density_warning != key::empty) {
		state.append(warning_lines, str(density_warning));
	}
	if (dependency_warning != key::empty) {
		state.append(warning_lines, str(dependency_warning));
	}
	const ArrayRef text_lines = state.new_array();
	state.append(text_lines, str(gd::format(state, key::preview_d_d_s_s, {
			int_value(tile.x),
			int_value(tile.y),
			str(text_or(state, guidance, key::placement_role, key::empty)),
			str(gd::bool_field(state, availability, key::can_place, false) ? key::can_place_2 : key::blocked),
	})));
	ai::append_array(state, text_lines, context_lines);
	if (state.array_size(warning_lines) != 0) {
		state.append(text_lines, str(gd::format(state, key::warning_s_2, { str(join_array(state, key::space_bar_space, warning_lines)) })));
	}
	state.append(text_lines, str(gd::format(state, key::consequence_s, { str(consequence) })));
	const DictRef preview = state.new_dict();
	state.set(preview, str(key::target_tile), dict_value(tile_dict(state, tile)));
	state.set(preview, str(key::family), str(member_string(state, editor, key::_selected_object_family)));
	state.set(preview, str(key::content_id), str(member_string(state, editor, key::_selected_object_content_id)));
	state.set(preview, str(key::can_place), bool_value(gd::bool_field(state, availability, key::can_place, false)));
	state.set(preview, str(key::blocked_reason), str(blocked_reason));
	state.set(preview, str(key::placement_role), str(text_or(state, guidance, key::placement_role, key::empty)));
	state.set(preview, str(key::role_flags_text), str(text_or(state, guidance, key::role_flags_text, key::empty)));
	state.set(preview, str(key::terrain_context), str(_placement_terrain_context_line(state, editor, tile)));
	state.set(preview, str(key::affected_context), array_value(context_lines));
	state.set(preview, str(key::density_warning), str(density_warning));
	state.set(preview, str(key::dependency_warning), str(dependency_warning));
	state.set(preview, str(key::warnings), array_value(warning_lines));
	state.set(preview, str(key::authoring_consequence), str(consequence));
	state.set(preview, str(key::guidance), dict_value(guidance));
	state.set(preview, str(key::text), str(join_array(state, key::newline, text_lines)));
	return preview;
}

} // namespace map_editor

} // namespace aurelion::rules::port
