// MapEditorShell's rules (Phase 7, slice 7.13): the placement preview, acceptance and action cues, the
// terrain paint and road checks and the object authoring
// recap.

#include "aurelion_rules/port/map_editor.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/session_view.hpp"

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
using state::Kind;
using state::State;
using state::Value;
namespace key = state::key;

// var tile: Vector2i = value
Vector2i as_tile(const Value &value) {
	if (value.kind != Kind::Vector2i) {
		throw state::ScriptError(std::string("Invalid type: expected Vector2i, got ") + gd::type_name(value));
	}
	return Vector2i::of(value.vx(), value.vy());
}

// self.<member> of a Vector2i member.
Vector2i member_tile(State &state, const Value &editor, Atom member) {
	return as_tile(gd::member(state, editor, member));
}

// String(d.get(field, fallback)).
Atom text_field(State &state, DictRef dict, Atom field, const Value &fallback) {
	return gd::stringify(state, state.get(dict, str(field), fallback));
}

// String(d.get(field, "")).strip_edges()
Atom stripped_field(State &state, DictRef dict, Atom field) {
	return gd::strip_edges(state, text_field(state, dict, field, str(key::empty)));
}

// bool(d.get(field, false))
bool flag_field(State &state, DictRef dict, Atom field) {
	return gd::to_bool(state.get(dict, str(field), bool_value(false)));
}

// var x: Dictionary = d.get(field, {}) and var x: Array = d.get(field, []).
DictRef dict_field_or_new(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return gd::as_dict(found);
	}
	return state.new_dict();
}

ArrayRef array_field_or_new(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return gd::as_array(found);
	}
	return state.new_array();
}

// "%d,%d" % [x, y]
Atom tile_label(State &state, int64_t x, int64_t y) {
	return state.intern(gd::format_pair(x, y));
}

// {"x": tile.x, "y": tile.y}
DictRef tile_payload(State &state, Vector2i tile) {
	const DictRef payload = state.new_dict();
	state.set(payload, str(key::x), int_value(tile.x));
	state.set(payload, str(key::y), int_value(tile.y));
	return payload;
}

// "" if count == 1 else "s"
Atom plural_s(int64_t count) {
	return count == 1 ? key::empty : key::s;
}

// a + b of Strings.
Atom concat_text(State &state, Atom a, Atom b) {
	std::string joined = state.text(a);
	joined += state.text(b);
	return state.intern(joined);
}

// separator.join(texts) of Strings.
Atom join_texts(State &state, Atom separator, const std::vector<Atom> &texts) {
	const std::string between = state.text(separator);
	std::string joined;
	for (size_t i = 0; i < texts.size(); ++i) {
		if (i > 0) {
			joined += between;
		}
		joined += state.text(texts[i]);
	}
	return state.intern(joined);
}

// separator.join(array) of an Array of Strings (the Array as a
// PackedStringArray: each item as String(item)).
Atom join_array(State &state, Atom separator, ArrayRef array) {
	std::vector<Atom> texts;
	for (int64_t i = 0; i < state.array_size(array); ++i) {
		texts.push_back(gd::stringify(state, state.at(array, i)));
	}
	return join_texts(state, separator, texts);
}

// var taxonomy: Dictionary = taxonomy_value if taxonomy_value is Dictionary else {}
// of taxonomy_value = detail.get(field, {}).
DictRef dict_field_if_dict(State &state, DictRef detail, Atom field) {
	Value found;
	if (state.lookup(detail, str(field), found) && gd::is_dict(found)) {
		return found.ref;
	}
	return state.new_dict();
}

} // namespace

namespace map_editor {

DictRef _editor_object_preview_check_payload(State &state, const Value &editor) {
	if (session(state, editor).kind == Kind::Nil) {
		return state.new_dict();
	}
	const DictRef preview = _selected_object_placement_preview_payload(state, editor, _placement_preview_tile(state, editor));
	if (gd::is_empty(state, preview)) {
		return state.new_dict();
	}
	const DictRef target_tile = dict_field_or_new(state, preview, key::target_tile);
	const Vector2i selected_tile = member_tile(state, editor, key::_selected_tile);
	const int64_t tile_x = gd::to_int(state, state.get(target_tile, str(key::x), int_value(selected_tile.x)));
	const int64_t tile_y = gd::to_int(state, state.get(target_tile, str(key::y), int_value(selected_tile.y)));
	const Vector2i tile = Vector2i::of(tile_x, tile_y);
	const Atom target_label = tile_label(state, tile.x, tile.y);
	const Atom family = text_field(state, preview, key::family, gd::member(state, editor, key::_selected_object_family));
	const Atom family_label = _object_family_label(state, editor, family);
	const Atom content_id = text_field(state, preview, key::content_id, gd::member(state, editor, key::_selected_object_content_id));
	Atom content_label = _selected_object_content_label(state, editor);
	if (content_label == key::empty) {
		content_label = content_id;
	}
	const bool can_place = flag_field(state, preview, key::can_place);
	const Atom readiness = can_place ? key::ready : key::blocked;
	const Atom occupied_label = _first_placement_label_at_tile(state, editor, tile);
	const Atom occupancy = occupied_label == key::empty ? key::empty_target : gd::format(state, key::occupied_by_s, {str(occupied_label)});
	const Atom blocked_reason = stripped_field(state, preview, key::blocked_reason);
	const Atom density_warning = stripped_field(state, preview, key::density_warning);
	const Atom dependency_warning = stripped_field(state, preview, key::dependency_warning);
	const Atom consequence = stripped_field(state, preview, key::authoring_consequence);
	Atom watch = blocked_reason;
	if (watch == key::empty) {
		watch = dependency_warning;
	}
	if (watch == key::empty) {
		watch = density_warning;
	}
	if (watch == key::empty) {
		watch = key::no_blocker_on_the_current_preview;
	}
	Atom next_step = gd::format(state, key::click_s_to_place_then_use, {str(target_label)});
	if (!can_place) {
		next_step = key::choose_another_tile_or_remove_the;
	}
	Value guidance;
	if (!state.lookup(preview, str(key::guidance), guidance)) {
		guidance = dict_value(state.new_dict());
	}
	if (!gd::is_dict(guidance)) {
		guidance = dict_value(state.new_dict());
	}
	const int64_t local_density_count = gd::to_int(state, state.get(guidance.ref, str(key::local_density_count), int_value(0)));
	const Atom density_target = text_field(state, guidance.ref, key::density_target, str(key::empty));
	const Atom density_line = gd::format(state, key::local_d_in_16x16_target_s, {int_value(local_density_count), str(density_target)});
	const Atom visible_text = gd::format(state, key::object_preview_check_s_s_at, {
		str(family_label),
		str(content_label),
		str(target_label),
		str(readiness),
		str(occupancy),
		str(next_step),
	});
	const Atom placement_role = text_field(state, preview, key::placement_role, str(key::empty));
	const Atom tooltip = gd::format(state, key::object_preview_check_target_s_s, {
		str(family_label),
		str(content_label),
		str(target_label),
		str(readiness),
		str(occupancy),
		str(placement_role),
		str(density_line),
		str(watch),
		str(consequence != key::empty ? consequence : key::adds_the_selected_object_to_this),
		str(next_step),
	});
	const DictRef result = state.new_dict();
	state.set(result, str(key::text), str(visible_text));
	state.set(result, str(key::tooltip), str(tooltip));
	state.set(result, str(key::target_tile), dict_value(tile_payload(state, tile)));
	state.set(result, str(key::family), str(family));
	state.set(result, str(key::content_id), str(content_id));
	state.set(result, str(key::content_label), str(content_label));
	state.set(result, str(key::can_place), bool_value(can_place));
	state.set(result, str(key::readiness), str(readiness));
	state.set(result, str(key::occupancy), str(occupancy));
	state.set(result, str(key::watch), str(watch));
	state.set(result, str(key::consequence), str(consequence));
	state.set(result, str(key::next_step_2), str(next_step));
	state.set(result, str(key::placement_role), str(text_field(state, preview, key::placement_role, str(key::empty))));
	state.set(result, str(key::density), str(density_line));
	state.set(result, str(key::scope), str(key::working_copy_only));
	return result;
}

DictRef _editor_acceptance_cue_payload(State &state, const Value &editor) {
	if (session(state, editor).kind == Kind::Nil) {
		return state.new_dict();
	}
	const Value recap_value = gd::member(state, editor, key::_last_object_authoring_recap);
	const DictRef recap = gd::is_dict(recap_value) ? recap_value.ref : state.new_dict();
	const Atom recap_next_check = stripped_field(state, recap, key::next_check);
	if (!gd::is_empty(state, recap) && recap_next_check != key::empty) {
		const DictRef result = state.new_dict();
		state.set(result, str(key::source), str(key::action_recap));
		state.set(result, str(key::action), str(text_field(state, recap, key::action, str(key::empty))));
		state.set(result, str(key::placement_id), str(text_field(state, recap, key::placement_id, str(key::empty))));
		state.set(result, str(key::next_check), str(recap_next_check));
		state.set(result, str(key::text), str(gd::format(state, key::cue_s_2, {str(recap_next_check)})));
		return result;
	}
	const DictRef preview = _selected_object_placement_preview_payload(state, editor, _placement_preview_tile(state, editor));
	if (gd::to_string(gd::member(state, editor, key::_tool)) == key::place_object && !gd::is_empty(state, preview)) {
		const DictRef target_tile = dict_field_or_new(state, preview, key::target_tile);
		const Vector2i selected_tile = member_tile(state, editor, key::_selected_tile);
		const int64_t label_x = gd::to_int(state, state.get(target_tile, str(key::x), int_value(selected_tile.x)));
		const int64_t label_y = gd::to_int(state, state.get(target_tile, str(key::y), int_value(selected_tile.y)));
		const Atom target_label = tile_label(state, label_x, label_y);
		const Atom content_id = text_field(state, preview, key::content_id, gd::member(state, editor, key::_selected_object_content_id));
		const Atom blocked_reason = stripped_field(state, preview, key::blocked_reason);
		const Atom dependency_warning = stripped_field(state, preview, key::dependency_warning);
		const Atom consequence = stripped_field(state, preview, key::authoring_consequence);
		if (!flag_field(state, preview, key::can_place)) {
			const Atom blocked_next = blocked_reason != key::empty ? blocked_reason : key::choose_an_empty_destination_before_placing;
			const DictRef result = state.new_dict();
			state.set(result, str(key::source), str(key::placement_preview));
			state.set(result, str(key::target_tile), dict_value(target_tile));
			state.set(result, str(key::family), str(text_field(state, preview, key::family, gd::member(state, editor, key::_selected_object_family))));
			state.set(result, str(key::content_id), str(content_id));
			state.set(result, str(key::can_place), bool_value(false));
			state.set(result, str(key::next_check), str(blocked_next));
			state.set(result, str(key::text), str(gd::format(state, key::cue_pick_another_tile_or_remove, {str(target_label), str(blocked_next)})));
			return result;
		}
		Atom preview_next = dependency_warning != key::empty ? dependency_warning : consequence;
		if (preview_next == key::empty) {
			preview_next = key::inspect_density_dependency_and_route_context;
		}
		const DictRef result = state.new_dict();
		state.set(result, str(key::source), str(key::placement_preview));
		state.set(result, str(key::target_tile), dict_value(target_tile));
		state.set(result, str(key::family), str(text_field(state, preview, key::family, gd::member(state, editor, key::_selected_object_family))));
		state.set(result, str(key::content_id), str(content_id));
		state.set(result, str(key::can_place), bool_value(true));
		state.set(result, str(key::next_check), str(preview_next));
		state.set(result, str(key::text), str(gd::format(state, key::cue_click_s_to_place_s, {str(target_label), str(content_id), str(preview_next)})));
		return result;
	}
	const DictRef validation = _scenario_authoring_validation_payload(state, editor);
	const ArrayRef warnings = array_field_or_new(state, validation, key::warnings);
	if (gd::to_int(state, state.get(validation, str(key::warning_count), int_value(0))) > 0 && state.array_size(warnings) != 0) {
		const Atom warning = gd::strip_edges(state, gd::stringify(state, state.at(warnings, 0)));
		if (warning != key::empty) {
			const DictRef result = state.new_dict();
			state.set(result, str(key::source), str(key::scenario_validation));
			state.set(result, str(key::next_check), str(warning));
			state.set(result, str(key::text), str(gd::format(state, key::cue_check_authoring_warning_s, {str(warning)})));
			return result;
		}
	}
	const Atom summary = stripped_field(state, validation, key::summary);
	if (summary != key::empty) {
		const DictRef result = state.new_dict();
		state.set(result, str(key::source), str(key::scenario_validation));
		state.set(result, str(key::next_check), str(summary));
		state.set(result, str(key::text), str(gd::format(state, key::cue_select_a_tile_or_tool, {str(summary)})));
		return result;
	}
	return state.new_dict();
}

DictRef _editor_placement_action_cue_payload(State &state, const Value &editor) {
	if (session(state, editor).kind == Kind::Nil) {
		return state.new_dict();
	}
	const DictRef preview = _selected_object_placement_preview_payload(state, editor, _placement_preview_tile(state, editor));
	if (gd::is_empty(state, preview)) {
		return state.new_dict();
	}
	const DictRef target_tile = dict_field_or_new(state, preview, key::target_tile);
	const Vector2i selected_tile = member_tile(state, editor, key::_selected_tile);
	const int64_t label_x = gd::to_int(state, state.get(target_tile, str(key::x), int_value(selected_tile.x)));
	const int64_t label_y = gd::to_int(state, state.get(target_tile, str(key::y), int_value(selected_tile.y)));
	const Atom target_label = tile_label(state, label_x, label_y);
	const Atom family = text_field(state, preview, key::family, gd::member(state, editor, key::_selected_object_family));
	const Atom family_label = _object_family_label(state, editor, family);
	const Atom content_id = text_field(state, preview, key::content_id, gd::member(state, editor, key::_selected_object_content_id));
	Atom content_label = _selected_object_content_label(state, editor);
	if (content_label == key::empty) {
		content_label = content_id;
	}
	const bool can_place = flag_field(state, preview, key::can_place);
	const Atom blocked_reason = stripped_field(state, preview, key::blocked_reason);
	const Atom consequence = stripped_field(state, preview, key::authoring_consequence);
	const Atom dependency_warning = stripped_field(state, preview, key::dependency_warning);
	const Atom status = can_place ? key::ready : key::blocked;
	Atom why = consequence != key::empty ? consequence : key::adds_or_updates_the_selected_object;
	Atom next_step = gd::format(state, key::click_s_to_place_it_then, {str(target_label)});
	if (!can_place) {
		why = blocked_reason != key::empty ? blocked_reason : key::the_selected_tile_cannot_accept_this;
		next_step = key::choose_another_tile_or_remove_the;
	} else if (dependency_warning != key::empty) {
		next_step = gd::format(state, key::click_s_to_place_it_then_2, {str(target_label), str(dependency_warning)});
	}
	const Atom visible_text = gd::format(state, key::placement_action_s_s_at_s, {
		str(family_label),
		str(content_label),
		str(target_label),
		str(status),
		str(next_step),
	});
	Atom tooltip = gd::format(state, key::placement_action_target_s_s_at, {
		str(family_label),
		str(content_label),
		str(target_label),
		str(status),
		str(why),
		str(next_step),
	});
	if (dependency_warning != key::empty && can_place) {
		const Atom watch_line = gd::format(state, key::watch_s_4, {str(dependency_warning)});
		tooltip = concat_text(state, tooltip, watch_line);
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::text), str(visible_text));
	state.set(result, str(key::tooltip_text), str(tooltip));
	state.set(result, str(key::target_tile), dict_value(target_tile));
	state.set(result, str(key::family), str(family));
	state.set(result, str(key::content_id), str(content_id));
	state.set(result, str(key::can_place), bool_value(can_place));
	state.set(result, str(key::status), str(status));
	state.set(result, str(key::why_it_matters), str(why));
	state.set(result, str(key::next_step_2), str(next_step));
	state.set(result, str(key::blocked_reason), str(blocked_reason));
	state.set(result, str(key::dependency_warning), str(dependency_warning));
	state.set(result, str(key::scope), str(key::working_copy_only));
	return result;
}

DictRef _editor_terrain_paint_check_payload(State &state, const Value &editor, Atom tool) {
	const Atom tool_id = tool == key::empty ? gd::to_string(gd::member(state, editor, key::_tool)) : tool;
	if (!(tool_id == key::terrain || tool_id == key::terrain_line || tool_id == key::terrain_rectangle)) {
		return state.new_dict();
	}
	if (session(state, editor).kind == Kind::Nil) {
		const Atom empty_text = key::paint_check_load_a_scenario_working;
		const DictRef result = state.new_dict();
		state.set(result, str(key::text), str(empty_text));
		state.set(result, str(key::tooltip), str(empty_text));
		state.set(result, str(key::state), str(key::empty_2));
		state.set(result, str(key::scope), str(key::working_copy_only));
		return result;
	}
	const Atom terrain_id = gd::to_string(gd::member(state, editor, key::_selected_terrain_id));
	const Atom terrain_label = _terrain_label_for_id(state, editor, terrain_id);
	const Vector2i target_tile = _terrain_paint_preview_tile(state, editor, tool_id);
	const Atom target_label = tile_label(state, target_tile.x, target_tile.y);
	const Atom current_id = _tile_in_bounds(state, editor, target_tile) ? _terrain_at(state, editor, target_tile) : key::empty;
	const Atom current_label = current_id != key::empty ? _terrain_label_for_id(state, editor, current_id) : key::none;
	Atom scope = key::empty;
	Atom readiness = key::empty;
	Atom next_step = key::empty;
	int64_t affected_count = 1;
	int64_t changed_count = 0;
	if (tool_id == key::terrain) {
		changed_count = current_id != terrain_id ? 1 : 0;
		scope = gd::format(state, key::single_tile_s, {str(target_label)});
		readiness = changed_count > 0 ? key::ready_to_repaint : key::no_terrain_change;
		next_step = changed_count > 0 ? gd::format(state, key::click_s_to_paint_s, {str(target_label), str(terrain_label)}) : key::choose_another_tile_or_brush_before;
	} else if (tool_id == key::terrain_line) {
		if (_has_pending_terrain_line_start(state, editor)) {
			const ArrayRef line_tiles = _terrain_line_tiles(state, editor, member_tile(state, editor, key::_pending_terrain_line_start), target_tile);
			affected_count = state.array_size(line_tiles);
			changed_count = _terrain_changed_tile_count(state, editor, line_tiles, terrain_id);
			const Vector2i line_start = member_tile(state, editor, key::_pending_terrain_line_start);
			scope = gd::format(state, key::line_d_d_to_s_d, {
				int_value(line_start.x),
				int_value(line_start.y),
				str(target_label),
				int_value(affected_count),
				str(plural_s(affected_count)),
			});
			readiness = changed_count > 0 ? gd::format(state, key::ready_x_d_d, {int_value(changed_count), int_value(affected_count)}) : key::no_terrain_change;
			next_step = changed_count > 0 ? gd::format(state, key::click_s_to_paint_the_terrain, {str(target_label)}) : key::choose_another_endpoint_or_brush_before;
		} else {
			affected_count = 0;
			scope = gd::format(state, key::line_start_at_s, {str(target_label)});
			readiness = key::pick_line_start;
			next_step = key::click_the_first_line_tile;
		}
	} else if (tool_id == key::terrain_rectangle) {
		if (_has_pending_terrain_rectangle_corner(state, editor)) {
			const ArrayRef rectangle_tiles = _terrain_rectangle_tiles(state, editor, member_tile(state, editor, key::_pending_terrain_rectangle_corner), target_tile);
			affected_count = state.array_size(rectangle_tiles);
			changed_count = _terrain_changed_tile_count(state, editor, rectangle_tiles, terrain_id);
			const Vector2i corner = member_tile(state, editor, key::_pending_terrain_rectangle_corner);
			scope = gd::format(state, key::rectangle_d_d_to_s_d, {
				int_value(corner.x),
				int_value(corner.y),
				str(target_label),
				int_value(affected_count),
				str(plural_s(affected_count)),
			});
			readiness = changed_count > 0 ? gd::format(state, key::ready_x_d_d, {int_value(changed_count), int_value(affected_count)}) : key::no_terrain_change;
			next_step = changed_count > 0 ? gd::format(state, key::click_s_to_paint_the_terrain_2, {str(target_label)}) : key::choose_another_corner_or_brush_before;
		} else {
			affected_count = 0;
			scope = gd::format(state, key::rectangle_corner_at_s, {str(target_label)});
			readiness = key::pick_rectangle_corner;
			next_step = key::click_the_first_rectangle_corner;
		}
	}
	const Atom text = gd::format(state, key::paint_check_s_brush_s_s, {
		str(gd::capitalize(state, readiness)),
		str(terrain_label),
		str(scope),
		str(next_step),
	});
	const Atom tooltip = gd::format(state, key::terrain_paint_check_brush_s_target, {
		str(terrain_label),
		str(scope),
		str(current_label),
		str(readiness),
		int_value(changed_count),
		int_value(affected_count),
		str(plural_s(affected_count)),
		str(next_step),
	});
	const DictRef result = state.new_dict();
	state.set(result, str(key::text), str(text));
	state.set(result, str(key::tooltip), str(tooltip));
	state.set(result, str(key::tool), str(tool_id));
	state.set(result, str(key::terrain_id), str(terrain_id));
	state.set(result, str(key::terrain_label), str(terrain_label));
	state.set(result, str(key::target_tile), dict_value(tile_payload(state, target_tile)));
	state.set(result, str(key::current_terrain_id), str(current_id));
	state.set(result, str(key::current_terrain_label), str(current_label));
	state.set(result, str(key::scope_text), str(scope));
	state.set(result, str(key::readiness), str(readiness));
	state.set(result, str(key::next_step_2), str(next_step));
	state.set(result, str(key::affected_count), int_value(affected_count));
	state.set(result, str(key::changed_count), int_value(changed_count));
	state.set(result, str(key::scope), str(key::working_copy_only));
	return result;
}

DictRef _editor_road_check_payload(State &state, const Value &editor, Atom tool) {
	const Atom tool_id = tool == key::empty ? gd::to_string(gd::member(state, editor, key::_tool)) : tool;
	if (!(tool_id == key::road || tool_id == key::road_path)) {
		return state.new_dict();
	}
	if (session(state, editor).kind == Kind::Nil) {
		const Atom empty_text = key::road_check_load_a_scenario_working;
		const DictRef result = state.new_dict();
		state.set(result, str(key::text), str(empty_text));
		state.set(result, str(key::tooltip), str(empty_text));
		state.set(result, str(key::state), str(key::empty_2));
		state.set(result, str(key::scope), str(key::working_copy_only));
		return result;
	}
	const Vector2i target_tile = _road_check_preview_tile(state, editor);
	const Atom target_label = tile_label(state, target_tile.x, target_tile.y);
	const bool current_has_road = _tile_in_bounds(state, editor, target_tile) ? _has_road_at(state, editor, target_tile) : false;
	const ArrayRef road_layers = current_has_road ? _road_layer_ids_at(state, editor, target_tile) : state.new_array();
	Atom scope = key::empty;
	Atom readiness = key::empty;
	Atom next_step = key::empty;
	Atom resolved_action = key::toggle;
	int64_t affected_count = 1;
	int64_t changed_count = 1;
	int64_t existing_count = current_has_road ? 1 : 0;
	if (tool_id == key::road) {
		resolved_action = current_has_road ? key::remove : key::add;
		scope = gd::format(state, key::single_tile_s, {str(target_label)});
		readiness = gd::format(state, key::s_ready, {str(resolved_action)});
		next_step = gd::format(state, key::click_s_to_s_road, {str(target_label), str(resolved_action)});
	} else if (tool_id == key::road_path) {
		if (_has_pending_road_path_start(state, editor)) {
			const ArrayRef path_tiles = _road_path_tiles(state, editor, member_tile(state, editor, key::_pending_road_path_start), target_tile);
			affected_count = state.array_size(path_tiles);
			existing_count = _road_check_existing_count(state, editor, path_tiles);
			resolved_action = affected_count > 0 && existing_count == affected_count ? key::remove : key::add;
			changed_count = resolved_action == key::remove ? existing_count : affected_count - existing_count;
			const Vector2i path_start = member_tile(state, editor, key::_pending_road_path_start);
			scope = gd::format(state, key::path_d_d_to_s_d, {
				int_value(path_start.x),
				int_value(path_start.y),
				str(target_label),
				int_value(affected_count),
				str(plural_s(affected_count)),
			});
			readiness = changed_count > 0 ? gd::format(state, key::s_ready_x_d_d, {str(resolved_action), int_value(changed_count), int_value(affected_count)}) : key::no_road_change;
			next_step = changed_count > 0 ? gd::format(state, key::click_s_to_s_the_road, {str(target_label), str(resolved_action)}) : key::choose_another_endpoint_before_applying_the;
		} else {
			affected_count = 0;
			changed_count = 0;
			existing_count = 0;
			scope = gd::format(state, key::path_start_at_s, {str(target_label)});
			readiness = key::pick_path_start;
			next_step = key::click_the_first_road_path_tile;
		}
	}
	const Atom layer_text = state.array_size(road_layers) != 0 ? join_array(state, key::comma_space, road_layers) : key::none;
	const Atom text = gd::format(state, key::road_check_s_s_next_s, {
		str(gd::capitalize(state, readiness)),
		str(scope),
		str(next_step),
	});
	const Atom tooltip = gd::format(state, key::road_check_target_s_current_road, {
		str(scope),
		str(layer_text),
		str(tool_id == key::road_path ? key::manhattan_l_path_horizontal_first_then : key::single_tile_toggle),
		str(readiness),
		str(resolved_action),
		int_value(changed_count),
		int_value(affected_count),
		str(plural_s(affected_count)),
		str(next_step),
	});
	const DictRef result = state.new_dict();
	state.set(result, str(key::text), str(text));
	state.set(result, str(key::tooltip), str(tooltip));
	state.set(result, str(key::tool), str(tool_id));
	state.set(result, str(key::target_tile), dict_value(tile_payload(state, target_tile)));
	state.set(result, str(key::has_road), bool_value(current_has_road));
	state.set(result, str(key::road_layers), array_value(road_layers));
	state.set(result, str(key::scope_text), str(scope));
	state.set(result, str(key::readiness), str(readiness));
	state.set(result, str(key::action), str(resolved_action));
	state.set(result, str(key::next_step_2), str(next_step));
	state.set(result, str(key::affected_count), int_value(affected_count));
	state.set(result, str(key::changed_count), int_value(changed_count));
	state.set(result, str(key::existing_count), int_value(existing_count));
	state.set(result, str(key::path_rule), str(tool_id == key::road_path ? key::manhattan_l_horizontal_then_vertical : key::single_tile_toggle_2));
	state.set(result, str(key::path_rule_label), str(tool_id == key::road_path ? key::manhattan_l_path_horizontal_first_then : key::single_tile_road_toggle));
	state.set(result, str(key::scope), str(key::working_copy_only));
	return result;
}

Vector2i _terrain_paint_preview_tile(State &state, const Value &editor, Atom tool) {
	(void)tool;
	if (_tile_in_bounds(state, editor, member_tile(state, editor, key::_hovered_tile))) {
		return member_tile(state, editor, key::_hovered_tile);
	}
	return member_tile(state, editor, key::_selected_tile);
}

Vector2i _road_check_preview_tile(State &state, const Value &editor) {
	if (_tile_in_bounds(state, editor, member_tile(state, editor, key::_hovered_tile))) {
		return member_tile(state, editor, key::_hovered_tile);
	}
	return member_tile(state, editor, key::_selected_tile);
}

int64_t _road_check_existing_count(State &state, const Value &editor, ArrayRef path_tiles) {
	int64_t existing_count = 0;
	for (int64_t i = 0; i < state.array_size(path_tiles); ++i) {
		const Vector2i tile = as_tile(state.at(path_tiles, i));
		if (_tile_in_bounds(state, editor, tile) && _has_road_at(state, editor, tile)) {
			existing_count += 1;
		}
	}
	return existing_count;
}

int64_t _terrain_changed_tile_count(State &state, const Value &editor, ArrayRef tiles, Atom terrain_id) {
	int64_t changed_count = 0;
	for (int64_t i = 0; i < state.array_size(tiles); ++i) {
		const Vector2i tile = as_tile(state.at(tiles, i));
		if (_tile_in_bounds(state, editor, tile) && _terrain_at(state, editor, tile) != terrain_id) {
			changed_count += 1;
		}
	}
	return changed_count;
}

DictRef _set_object_authoring_recap(State &state, const Value &editor, Atom action, bool changed, DictRef before_detail, DictRef after_detail, Vector2i from_tile, Vector2i to_tile, DictRef preview, Atom property_name, const Value &previous_value, const Value &new_value) {
	const DictRef recap = _object_authoring_recap_payload(state, editor, action, changed, before_detail, after_detail, from_tile, to_tile, preview, property_name, previous_value, new_value);
	gd::set_member(state, editor, key::_last_object_authoring_recap, dict_value(recap));
	const Atom text = stripped_field(state, recap, key::text);
	if (text != key::empty) {
		gd::set_member(state, editor, key::_last_message, str(text));
	}
	return recap;
}

DictRef _object_authoring_recap_payload(State &state, const Value &editor, Atom action, bool changed, DictRef before_detail, DictRef after_detail, Vector2i from_tile, Vector2i to_tile, DictRef preview, Atom property_name, const Value &previous_value, const Value &new_value) {
	const DictRef detail = !gd::is_empty(state, after_detail) ? after_detail : before_detail;
	if (gd::is_empty(state, detail)) {
		return state.new_dict();
	}
	const Atom kind = text_field(state, detail, key::kind, str(key::empty));
	const Atom content_id = text_field(state, detail, key::content_id, str(key::empty));
	const Atom placement_id = text_field(state, detail, key::placement_id, str(key::empty));
	Vector2i target_tile = to_tile;
	if (!_tile_in_bounds(state, editor, target_tile)) {
		const int64_t detail_x = gd::to_int(state, state.get(detail, str(key::x), int_value(from_tile.x)));
		const int64_t detail_y = gd::to_int(state, state.get(detail, str(key::y), int_value(from_tile.y)));
		target_tile = Vector2i::of(detail_x, detail_y);
	}
	Value taxonomy;
	if (!state.lookup(detail, str(key::taxonomy), taxonomy)) {
		taxonomy = dict_value(state.new_dict());
	}
	if (!gd::is_dict(taxonomy)) {
		taxonomy = dict_value(_object_content_taxonomy_payload(state, editor, kind, content_id));
	}
	DictRef enriched_detail = gd::deep_duplicate_dict(state, detail);
	if (gd::is_dict(taxonomy) && !gd::is_empty(state, taxonomy.ref)) {
		state.set(enriched_detail, str(key::taxonomy), taxonomy);
	}
	if (!_tile_in_bounds(state, editor, target_tile)) {
		target_tile = from_tile;
	}
	enriched_detail = _object_detail_with_guidance(state, editor, enriched_detail, target_tile);
	const DictRef dependencies = dict_field_or_new(state, enriched_detail, key::authoring_dependencies);
	ArrayRef context_lines = state.new_array();
	if (gd::is_dict(taxonomy) && !gd::is_empty(state, taxonomy.ref) && _tile_in_bounds(state, editor, target_tile)) {
		context_lines = _placement_context_lines(state, editor, kind, content_id, taxonomy.ref, target_tile);
	}
	const Atom dependency_line = _dependency_recap_line(state, editor, enriched_detail);
	const Atom why_line = _object_action_why_line(state, editor, action, enriched_detail, preview, property_name);
	const Atom next_check = _object_action_next_check(state, editor, action, enriched_detail, preview, property_name);
	const Atom headline = _object_action_headline(state, editor, action, changed, before_detail, after_detail, from_tile, target_tile, property_name, previous_value, new_value);
	std::vector<Atom> text_lines = {headline};
	if (state.array_size(context_lines) != 0) {
		const Atom context_text = _compact_join_limited(state, editor, context_lines, 2);
		text_lines.push_back(gd::format(state, key::context_s, {str(context_text)}));
	}
	if (dependency_line != key::empty) {
		text_lines.push_back(gd::format(state, key::dependency_s, {str(dependency_line)}));
	}
	if (why_line != key::empty) {
		text_lines.push_back(gd::format(state, key::matters_s, {str(why_line)}));
	}
	if (next_check != key::empty) {
		text_lines.push_back(gd::format(state, key::next_s, {str(next_check)}));
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::action), str(action));
	state.set(result, str(key::changed), bool_value(changed));
	state.set(result, str(key::family), str(kind));
	state.set(result, str(key::placement_id), str(placement_id));
	state.set(result, str(key::content_id), str(content_id));
	state.set(result, str(key::name), str(text_field(state, detail, key::name, str(content_id))));
	const DictRef from_payload = _tile_in_bounds(state, editor, from_tile) ? tile_payload(state, from_tile) : state.new_dict();
	state.set(result, str(key::from), dict_value(from_payload));
	const DictRef to_payload = _tile_in_bounds(state, editor, target_tile) ? tile_payload(state, target_tile) : state.new_dict();
	state.set(result, str(key::to), dict_value(to_payload));
	state.set(result, str(key::property), str(property_name));
	const Atom previous_text = property_name != key::empty ? _editor_variant_text(state, editor, previous_value) : key::empty;
	state.set(result, str(key::previous_value), str(previous_text));
	const Atom new_text = property_name != key::empty ? _editor_variant_text(state, editor, new_value) : key::empty;
	state.set(result, str(key::new_value), str(new_text));
	state.set(result, str(key::context), array_value(context_lines));
	state.set(result, str(key::dependency_summary), str(dependency_line));
	Value dependency_warnings;
	const int64_t dependency_warning_count = state.lookup(dependencies, str(key::warnings), dependency_warnings) ? ai::vsize(state, dependency_warnings) : 0;
	state.set(result, str(key::dependency_warning_count), int_value(dependency_warning_count));
	state.set(result, str(key::why), str(why_line));
	state.set(result, str(key::next_check), str(next_check));
	state.set(result, str(key::text), str(join_texts(state, key::newline, text_lines)));
	return result;
}

Atom _object_action_headline(State &state, const Value &editor, Atom action, bool changed, DictRef before_detail, DictRef after_detail, Vector2i from_tile, Vector2i to_tile, Atom property_name, const Value &previous_value, const Value &new_value) {
	const DictRef detail = !gd::is_empty(state, after_detail) ? after_detail : before_detail;
	const Atom object_label = _object_recap_label(state, editor, detail);
	const Atom changed_prefix = _object_action_label(state, editor, action, changed);
	if (action == key::place) {
		return gd::format(state, key::s_s_at_d_d, {str(changed_prefix), str(object_label), int_value(to_tile.x), int_value(to_tile.y)});
	}
	if (action == key::remove) {
		return gd::format(state, key::s_s_from_d_d, {str(changed_prefix), str(object_label), int_value(from_tile.x), int_value(from_tile.y)});
	}
	if (action == key::move_ || action == key::duplicate) {
		return gd::format(state, key::s_s_from_d_d_to, {
			str(changed_prefix),
			str(object_label),
			int_value(from_tile.x),
			int_value(from_tile.y),
			int_value(to_tile.x),
			int_value(to_tile.y),
		});
	}
	if (action == key::retheme) {
		const Atom before_label = _object_recap_label(state, editor, before_detail);
		const Atom before_content_id = text_field(state, before_detail, key::content_id, str(key::empty));
		const Atom after_content_id = text_field(state, after_detail, key::content_id, str(key::empty));
		return gd::format(state, key::s_s_from_s_to_s, {
			str(changed_prefix),
			str(before_label),
			str(before_content_id),
			str(after_content_id),
			int_value(to_tile.x),
			int_value(to_tile.y),
		});
	}
	if (action == key::edit_property) {
		const Atom property_label = _humanize_editor_id(state, editor, property_name);
		const Atom previous_text = _editor_variant_text(state, editor, previous_value);
		const Atom new_text = _editor_variant_text(state, editor, new_value);
		return gd::format(state, key::s_s_s_from_s_to, {
			str(changed_prefix),
			str(object_label),
			str(property_label),
			str(previous_text),
			str(new_text),
			int_value(to_tile.x),
			int_value(to_tile.y),
		});
	}
	return gd::format(state, key::s_s_2, {str(changed_prefix), str(object_label)});
}

Atom _object_action_label(State &state, const Value &editor, Atom action, bool changed) {
	(void)state;
	(void)editor;
	if (!changed) {
		return key::no_change_for;
	}
	if (action == key::place) {
		return key::Placed;
	}
	if (action == key::remove) {
		return key::Removed;
	}
	if (action == key::move_) {
		return key::Moved;
	}
	if (action == key::duplicate) {
		return key::Duplicated;
	}
	if (action == key::retheme) {
		return key::Rethemed;
	}
	if (action == key::edit_property) {
		return key::Edited;
	}
	return key::Updated;
}

Atom _object_recap_label(State &state, const Value &editor, DictRef detail) {
	if (gd::is_empty(state, detail)) {
		return key::object;
	}
	const Atom family_label = _object_family_label(state, editor, text_field(state, detail, key::kind, str(key::empty)));
	const Value name_fallback = state.get(detail, str(key::content_id), str(key::empty));
	const Atom name = gd::strip_edges(state, text_field(state, detail, key::name, name_fallback));
	const Atom placement_id = stripped_field(state, detail, key::placement_id);
	if (placement_id == key::empty) {
		return gd::format(state, key::s_s, {str(family_label), str(name)});
	}
	return gd::format(state, key::s_s_s_15, {str(family_label), str(name), str(placement_id)});
}

Atom _dependency_recap_line(State &state, const Value &editor, DictRef detail) {
	(void)editor;
	Value dependencies;
	if (!state.lookup(detail, str(key::authoring_dependencies), dependencies)) {
		return key::no_authored_objective_guard_reward_route;
	}
	if (!gd::is_dict(dependencies) || gd::is_empty(state, dependencies.ref)) {
		return key::no_authored_objective_guard_reward_route;
	}
	std::vector<Atom> parts;
	const Atom summary = stripped_field(state, dependencies.ref, key::summary);
	if (summary != key::empty) {
		parts.push_back(summary);
	}
	const ArrayRef warnings = array_field_or_new(state, dependencies.ref, key::warnings);
	if (state.array_size(warnings) != 0) {
		const Atom first_warning = gd::stringify(state, state.at(warnings, 0));
		parts.push_back(gd::format(state, key::warning_s, {str(first_warning)}));
	}
	if (parts.empty()) {
		return key::no_authored_objective_guard_reward_route;
	}
	return join_texts(state, key::space_bar_space, parts);
}

Atom _object_action_why_line(State &state, const Value &editor, Atom action, DictRef detail, DictRef preview, Atom property_name) {
	const DictRef taxonomy = dict_field_if_dict(state, detail, key::taxonomy);
	const DictRef flags = !gd::is_empty(state, taxonomy) ? _placement_role_flags(state, editor, taxonomy) : state.new_dict();
	const Atom preview_consequence = stripped_field(state, preview, key::authoring_consequence);
	if (action == key::place) {
		const DictRef guidance = dict_field_if_dict(state, detail, key::placement_guidance);
		if (preview_consequence != key::empty) {
			return preview_consequence;
		}
		const Atom kind = text_field(state, detail, key::kind, str(key::empty));
		const Atom content_id = text_field(state, detail, key::content_id, str(key::empty));
		return _placement_authoring_consequence(state, editor, kind, content_id, taxonomy, guidance);
	}
	if (action == key::remove) {
		if (flag_field(state, flags, key::economy)) {
			return key::removes_an_economy_control_source_from;
		}
		if (flag_field(state, flags, key::neutral)) {
			return key::removes_a_battle_gate_or_recruit;
		}
		return key::removes_a_reward_town_or_route;
	}
	if (action == key::move_) {
		return key::keeps_the_placement_id_stable_while;
	}
	if (action == key::duplicate) {
		return key::creates_a_fresh_editor_id_with;
	}
	if (action == key::retheme) {
		return key::keeps_the_placement_id_and_links;
	}
	if (action == key::edit_property) {
		if (property_name == key::owner) {
			return key::changes_control_state_used_by_objectives;
		}
		if (property_name == key::collected) {
			return key::changes_whether_this_reward_site_appears;
		}
		if (property_name == key::difficulty) {
			return key::changes_battle_pressure_without_moving_the;
		}
		return key::changes_the_working_copy_runtime_state;
	}
	return key::empty;
}

Atom _object_action_next_check(State &state, const Value &editor, Atom action, DictRef detail, DictRef preview, Atom property_name) {
	Value dependencies;
	if (!state.lookup(detail, str(key::authoring_dependencies), dependencies)) {
		dependencies = dict_value(state.new_dict());
	}
	const ArrayRef warnings = gd::is_dict(dependencies) ? array_field_or_new(state, dependencies.ref, key::warnings) : state.new_array();
	if (state.array_size(warnings) != 0) {
		return gd::stringify(state, state.at(warnings, 0));
	}
	if ((action == key::remove || action == key::move_ || action == key::retheme) && gd::is_dict(dependencies) && stripped_field(state, dependencies.ref, key::summary) != key::empty) {
		return key::recheck_linked_objectives_guards_rewards_routes;
	}
	if (action == key::place || action == key::duplicate) {
		const Atom dependency_warning = stripped_field(state, preview, key::dependency_warning);
		if (dependency_warning != key::empty) {
			return key::stabilize_the_placement_id_before_adding;
		}
	}
	const DictRef taxonomy = dict_field_if_dict(state, detail, key::taxonomy);
	const DictRef flags = !gd::is_empty(state, taxonomy) ? _placement_role_flags(state, editor, taxonomy) : state.new_dict();
	if (property_name == key::owner) {
		return key::check_victory_defeat_anchors_and_nearest;
	}
	if (property_name == key::collected) {
		return key::check_live_preview_visibility_and_nearby;
	}
	if (property_name == key::difficulty) {
		return key::check_guard_pressure_against_the_reward;
	}
	if (flag_field(state, flags, key::economy) || flag_field(state, flags, key::transit)) {
		return key::check_road_contact_local_density_nearest;
	}
	if (flag_field(state, flags, key::neutral)) {
		return key::check_guarded_target_reward_link_and;
	}
	return key::inspect_the_tile_density_band_and;
}

Atom _compact_join_limited(State &state, const Value &editor, ArrayRef lines, int64_t limit) {
	(void)editor;
	std::vector<Atom> compact;
	for (int64_t i = 0; i < state.array_size(lines); ++i) {
		const Atom line = gd::strip_edges(state, gd::stringify(state, state.at(lines, i)));
		if (line == key::empty) {
			continue;
		}
		compact.push_back(line);
		if (static_cast<int64_t>(compact.size()) >= limit) {
			break;
		}
	}
	return join_texts(state, key::space_bar_space, compact);
}

Atom _editor_variant_text(State &state, const Value &editor, const Value &value) {
	(void)editor;
	if (value.kind == Kind::Nil) {
		return key::empty;
	}
	if (value.kind == Kind::Bool) {
		return value.b ? key::true_ : key::false_;
	}
	if (value.kind == Kind::Int || value.is_string_like()) {
		return gd::stringify(state, value);
	}
	// String(value) of a float, a Vector2i, a container or an object: the
	// engine's text.
	return gd::engine_str(state, value);
}

} // namespace map_editor

} // namespace aurelion::rules::port
