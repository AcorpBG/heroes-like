// MapEditorShell's rules (Phase 7, slice 7.13): the hero start, placing, removing, moving, duplicating
// and retheming objects, their properties and restoring
// a tile from the baseline.

#include "aurelion_rules/port/map_editor.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/artifact_rules.hpp"
#include "aurelion_rules/port/scenario_factory_turn.hpp"
#include "aurelion_rules/port/session_view.hpp"

#include <cstdint>

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

// String(x): stringify(), the engine's str() for a float, a container or an
// object.
Atom value_text(State &state, const Value &value) {
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
Atom field_text(State &state, DictRef dict, Atom field, Atom fallback) {
	return value_text(state, gd::field_or(state, dict, field, str(fallback)));
}

// A String member of the screen (self._x).
Atom member_text(State &state, const Value &editor, Atom member) {
	return gd::to_string(gd::member(state, editor, member));
}

// self._last_message = text.
void set_message(State &state, const Value &editor, Atom text) {
	gd::set_member(state, editor, key::_last_message, str(text));
}

// self._session.overworld.
DictRef editor_overworld(State &state, const Value &editor) {
	return session_view::overworld(state, map_editor::session_view(state, map_editor::session(state, editor)));
}

// {"x": tile.x, "y": tile.y}.
DictRef tile_payload(State &state, Vector2i tile) {
	const DictRef payload = state.new_dict();
	state.set(payload, str(key::x), int_value(tile.x));
	state.set(payload, str(key::y), int_value(tile.y));
	return payload;
}

// {"ok": false, "changed": false, "message": message}.
DictRef failure(State &state, Atom message) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(false));
	state.set(result, str(key::changed), bool_value(false));
	state.set(result, str(key::message), str(message));
	return result;
}

} // namespace

namespace map_editor {

bool _set_hero_start(State &state, const Value &editor, Vector2i tile) {
	if (!_set_hero_position(state, editor, tile)) {
		return false;
	}
	set_dirty(state, editor, true);
	set_message(state, editor, gd::format(state, key::moved_the_working_copy_hero_start, { int_value(tile.x), int_value(tile.y) }));
	return true;
}

bool _set_hero_position(State &state, const Value &editor, Vector2i tile) {
	if (!_tile_in_bounds(state, editor, tile)) {
		return false;
	}
	const DictRef position_payload = tile_payload(state, tile);
	const DictRef overworld = editor_overworld(state, editor);
	state.set(overworld, str(key::hero_position), gd::engine_duplicate(state, dict_value(position_payload), true));
	Value hero;
	if (!state.lookup(overworld, str(key::hero), hero)) {
		hero = dict_value(state.new_dict());
	}
	if (gd::is_dict(hero)) {
		state.set(hero.ref, str(key::position), gd::engine_duplicate(state, dict_value(position_payload), true));
		state.set(overworld, str(key::hero), hero);
	}
	Value heroes;
	if (!state.lookup(overworld, str(key::player_heroes), heroes)) {
		heroes = array_value(state.new_array());
	}
	if (gd::is_array(heroes)) {
		const int64_t count = state.array_size(heroes.ref);
		for (int64_t index = 0; index < count; ++index) {
			const Value hero_state = state.at(heroes.ref, index);
			if (!gd::is_dict(hero_state)) {
				continue;
			}
			const Value hero_id = gd::member(state, session(state, editor), key::hero_id);
			const Atom active_hero_id = value_text(state, state.get(overworld, str(key::active_hero_id), hero_id));
			if (field_text(state, hero_state.ref, key::id, key::empty) == active_hero_id) {
				state.set(hero_state.ref, str(key::position), gd::engine_duplicate(state, dict_value(position_payload), true));
				state.set_at(heroes.ref, index, hero_state);
				break;
			}
		}
		state.set(overworld, str(key::player_heroes), heroes);
	}
	return true;
}

bool _place_object(State &state, const Value &editor, Vector2i tile) {
	const auto family = [&]() { return member_text(state, editor, key::_selected_object_family); };
	const auto content_id = [&]() { return member_text(state, editor, key::_selected_object_content_id); };
	if (!_tile_in_bounds(state, editor, tile)) {
		return false;
	}
	if (family() == key::empty || content_id() == key::empty) {
		set_message(state, editor, key::choose_an_object_family_and_authored);
		return false;
	}
	if (gd::is_empty(state, _object_content_lookup(state, editor, family(), content_id()))) {
		set_message(state, editor, gd::format(state, key::unknown_s_content_id_s, { str(_object_family_label(state, editor, family())), str(content_id()) }));
		return false;
	}
	if (family() == key::artifact && _artifact_content_id_exists(state, editor, content_id())) {
		set_message(state, editor, gd::format(state, key::artifact_s_is_already_placed_in, { str(content_id()) }));
		return false;
	}
	const ArrayRef existing_objects = _object_details_at(state, editor, tile, false);
	if (state.array_size(existing_objects) != 0) {
		const Value fallback = ai::vget(state, state.at(existing_objects, 0), key::kind, str(key::object));
		const Value label = ai::vget(state, state.at(existing_objects, 0), key::placement_id, fallback);
		set_message(state, editor, gd::format(state, key::tile_d_d_already_has_s, { int_value(tile.x), int_value(tile.y), str(value_text(state, label)) }));
		return false;
	}

	const DictRef preview = _selected_object_placement_preview_payload(state, editor, tile);
	const Atom placement_id = _generate_editor_placement_id(state, editor, family(), content_id(), tile);
	const DictRef built_placement = _build_runtime_placement(state, editor, family(), content_id(), placement_id, tile);
	if (gd::is_empty(state, built_placement)) {
		set_message(state, editor, gd::format(state, key::could_not_build_s_placement_for, { str(_object_family_label(state, editor, family())), str(content_id()) }));
		return false;
	}
	state.set(built_placement, str(key::editor_authored_placement), bool_value(true));

	const Atom array_key = _placement_array_key(state, editor, family());
	const DictRef overworld = editor_overworld(state, editor);
	Value placements;
	if (!state.lookup(overworld, str(array_key), placements) || !gd::is_array(placements)) {
		placements = array_value(state.new_array());
	}
	state.append(placements.ref, dict_value(built_placement));
	state.set(overworld, str(array_key), placements);
	set_dirty(state, editor, true);
	const DictRef after_detail = _object_detail_by_key(state, editor, _object_property_key(state, editor, family(), placement_id));
	_set_object_authoring_recap(state, editor, key::place, true, state.new_dict(), after_detail, tile, tile, preview, key::empty, Value(), Value());
	return true;
}

bool _remove_object(State &state, const Value &editor, Vector2i tile) {
	const auto family = [&]() { return member_text(state, editor, key::_selected_object_family); };
	if (!_tile_in_bounds(state, editor, tile)) {
		return false;
	}
	const Atom array_key = _placement_array_key(state, editor, family());
	if (array_key == key::empty) {
		return false;
	}
	// _session.overworld.get(array_key, []): a missing array reads as empty.
	Value placements;
	const bool has_placements = state.lookup(editor_overworld(state, editor), str(array_key), placements);
	if (has_placements && !gd::is_array(placements)) {
		set_message(state, editor, gd::format(state, key::no_s_placements_exist_in_this, { str(_object_family_label(state, editor, family())) }));
		return false;
	}
	const ArrayRef updated = state.new_array();
	const ArrayRef removed_ids = state.new_array();
	const ArrayRef removed_details = state.new_array();
	if (has_placements) {
		for (int64_t index = 0; index < state.array_size(placements.ref); ++index) {
			const Value placement = state.at(placements.ref, index);
			if (gd::is_dict(placement) && _placement_at_tile(state, editor, placement.ref, tile)) {
				state.append(removed_ids, str(field_text(state, placement.ref, key::placement_id, key::empty)));
				const DictRef detail = _object_detail_for_placement(state, editor, family(), placement.ref);
				state.append(removed_details, dict_value(_object_detail_with_guidance(state, editor, detail, tile)));
				continue;
			}
			state.append(updated, placement);
		}
	}
	if (state.array_size(removed_ids) == 0) {
		set_message(state, editor, gd::format(state, key::no_s_placement_at_d_d, { str(_object_family_label(state, editor, family())), int_value(tile.x), int_value(tile.y) }));
		return false;
	}
	state.set(editor_overworld(state, editor), str(array_key), array_value(updated));
	if (family() == key::encounter) {
		_remove_resolved_encounter_ids(state, editor, removed_ids);
	}
	set_dirty(state, editor, true);
	const DictRef before_detail = state.array_size(removed_details) != 0 ? gd::as_dict(state.at(removed_details, 0)) : state.new_dict();
	_set_object_authoring_recap(state, editor, key::remove, true, before_detail, state.new_dict(), tile, tile, state.new_dict(), key::empty, Value(), Value());
	return true;
}

bool _move_object_tool_click(State &state, const Value &editor, Vector2i tile) {
	if (member_text(state, editor, key::_pending_move_object_key) == key::empty) {
		const DictRef detail = _preferred_move_detail_at(state, editor, tile);
		if (gd::is_empty(state, detail)) {
			set_message(state, editor, key::choose_a_supported_town_site_artifact);
			return false;
		}
		gd::set_member(state, editor, key::_pending_move_object_key, str(field_text(state, detail, key::property_key, key::empty)));
		gd::set_member(state, editor, key::_selected_property_object_key, str(member_text(state, editor, key::_pending_move_object_key)));
		set_message(state, editor, gd::format(state, key::move_source_selected_s_at_d, { str(field_text(state, detail, key::placement_id, key::empty)), int_value(tile.x), int_value(tile.y) }));
		return true;
	}
	const DictRef before_detail = _object_detail_by_key(state, editor, member_text(state, editor, key::_pending_move_object_key));
	const Vector2i source_tile = Vector2i::of(gd::int_field(state, before_detail, key::x, tile.x), gd::int_field(state, before_detail, key::y, tile.y));
	const DictRef result = _move_object_by_key(state, editor, member_text(state, editor, key::_pending_move_object_key), tile);
	if (gd::bool_field(state, result, key::ok, false)) {
		gd::set_member(state, editor, key::_pending_move_object_key, str(key::empty));
		set_dirty(state, editor, gd::to_bool(gd::member(state, editor, key::_dirty)) || gd::bool_field(state, result, key::changed, false));
		const DictRef after_detail = _object_detail_by_key(state, editor, field_text(state, before_detail, key::property_key, key::empty));
		_set_object_authoring_recap(state, editor, key::move_, gd::bool_field(state, result, key::changed, false), before_detail, after_detail, source_tile, tile, state.new_dict(), key::empty, Value(), Value());
	} else {
		set_message(state, editor, field_text(state, result, key::message, key::could_not_move_object_placement));
	}
	return gd::bool_field(state, result, key::ok, false);
}

DictRef _preferred_move_detail_at(State &state, const Value &editor, Vector2i tile) {
	const ArrayRef options = _property_object_options_at(state, editor, tile);
	if (state.array_size(options) == 0) {
		return state.new_dict();
	}
	for (int64_t index = 0; index < state.array_size(options); ++index) {
		const Value detail = state.at(options, index);
		if (gd::is_dict(detail) && field_text(state, detail.ref, key::property_key, key::empty) == member_text(state, editor, key::_selected_property_object_key)) {
			return detail.ref;
		}
	}
	for (int64_t index = 0; index < state.array_size(options); ++index) {
		const Value detail = state.at(options, index);
		if (gd::is_dict(detail)) {
			return detail.ref;
		}
	}
	return state.new_dict();
}

DictRef _move_object_by_key(State &state, const Value &editor, Atom property_key, Vector2i destination_tile) {
	if (!_tile_in_bounds(state, editor, destination_tile)) {
		return failure(state, key::destination_tile_is_outside_the_map);
	}
	const DictRef detail = _object_detail_by_key(state, editor, property_key);
	if (gd::is_empty(state, detail)) {
		return failure(state, gd::format(state, key::no_movable_object_s_exists_in, { str(property_key) }));
	}
	const Atom kind = field_text(state, detail, key::kind, key::empty);
	const Atom placement_id = field_text(state, detail, key::placement_id, key::empty);
	const DictRef blocker = _first_blocking_object_detail_at(state, editor, destination_tile, property_key);
	if (!gd::is_empty(state, blocker)) {
		const Value fallback = gd::field_or(state, blocker, key::kind, str(key::object));
		const Value label = gd::field_or(state, blocker, key::placement_id, fallback);
		return failure(state, gd::format(state, key::destination_d_d_already_has_s, { int_value(destination_tile.x), int_value(destination_tile.y), str(value_text(state, label)) }));
	}
	const Vector2i source_tile = Vector2i::of(gd::int_field(state, detail, key::x, 0), gd::int_field(state, detail, key::y, 0));
	if (source_tile == destination_tile) {
		gd::set_member(state, editor, key::_selected_property_object_key, str(property_key));
		const DictRef result = state.new_dict();
		state.set(result, str(key::ok), bool_value(true));
		state.set(result, str(key::changed), bool_value(false));
		state.set(result, str(key::message), str(gd::format(state, key::s_s_is_already_at_d, { str(_object_family_label(state, editor, kind)), str(placement_id), int_value(destination_tile.x), int_value(destination_tile.y) })));
		state.set(result, str(key::object), dict_value(detail));
		state.set(result, str(key::from), dict_value(tile_payload(state, source_tile)));
		state.set(result, str(key::to), dict_value(tile_payload(state, destination_tile)));
		return result;
	}
	const Atom array_key = _placement_array_key(state, editor, kind);
	// _session.overworld.get(array_key, []): a missing array reads as empty.
	Value placements;
	const bool has_placements = state.lookup(editor_overworld(state, editor), str(array_key), placements);
	if (array_key == key::empty || (has_placements && !gd::is_array(placements))) {
		return failure(state, gd::format(state, key::working_copy_has_no_s_array, { str(_object_family_label(state, editor, kind)) }));
	}
	const int64_t count = has_placements ? state.array_size(placements.ref) : 0;
	for (int64_t index = 0; index < count; ++index) {
		const Value placement = state.at(placements.ref, index);
		if (!gd::is_dict(placement)) {
			continue;
		}
		if (field_text(state, placement.ref, key::placement_id, key::empty) != placement_id) {
			continue;
		}
		const DictRef before = gd::as_dict(gd::engine_duplicate(state, placement, true));
		state.set(placement.ref, str(key::x), int_value(destination_tile.x));
		state.set(placement.ref, str(key::y), int_value(destination_tile.y));
		state.set_at(placements.ref, index, placement);
		state.set(editor_overworld(state, editor), str(array_key), placements);
		gd::set_member(state, editor, key::_selected_property_object_key, str(property_key));
		const DictRef result = state.new_dict();
		state.set(result, str(key::ok), bool_value(true));
		state.set(result, str(key::changed), bool_value(!gd::equal(state, dict_value(before), placement)));
		state.set(result, str(key::message), str(gd::format(state, key::moved_s_s_from_d_d, { str(_object_family_label(state, editor, kind)), str(placement_id), int_value(source_tile.x), int_value(source_tile.y), int_value(destination_tile.x), int_value(destination_tile.y) })));
		state.set(result, str(key::object), placement);
		state.set(result, str(key::from), dict_value(tile_payload(state, source_tile)));
		state.set(result, str(key::to), dict_value(tile_payload(state, destination_tile)));
		return result;
	}
	return failure(state, gd::format(state, key::no_s_placement_s_in_the, { str(_object_family_label(state, editor, kind)), str(placement_id) }));
}

bool _duplicate_object_tool_click(State &state, const Value &editor, Vector2i tile) {
	if (member_text(state, editor, key::_pending_duplicate_object_key) == key::empty) {
		const DictRef detail = _preferred_move_detail_at(state, editor, tile);
		if (gd::is_empty(state, detail)) {
			set_message(state, editor, key::choose_a_supported_town_site_artifact_2);
			return false;
		}
		gd::set_member(state, editor, key::_pending_duplicate_object_key, str(field_text(state, detail, key::property_key, key::empty)));
		gd::set_member(state, editor, key::_selected_property_object_key, str(member_text(state, editor, key::_pending_duplicate_object_key)));
		set_message(state, editor, gd::format(state, key::duplicate_source_selected_s_at_d, { str(field_text(state, detail, key::placement_id, key::empty)), int_value(tile.x), int_value(tile.y) }));
		return true;
	}
	const DictRef before_detail = _object_detail_by_key(state, editor, member_text(state, editor, key::_pending_duplicate_object_key));
	const Vector2i source_tile = Vector2i::of(gd::int_field(state, before_detail, key::x, tile.x), gd::int_field(state, before_detail, key::y, tile.y));
	const DictRef result = _duplicate_object_by_key(state, editor, member_text(state, editor, key::_pending_duplicate_object_key), tile);
	if (gd::bool_field(state, result, key::ok, false)) {
		gd::set_member(state, editor, key::_pending_duplicate_object_key, str(key::empty));
		set_dirty(state, editor, gd::to_bool(gd::member(state, editor, key::_dirty)) || gd::bool_field(state, result, key::changed, false));
		// String(result.get("object", {}).get("placement_id", "")).
		Value object;
		Atom duplicate_placement_id = key::empty;
		if (state.lookup(result, str(key::object), object)) {
			duplicate_placement_id = value_text(state, ai::vget(state, object, key::placement_id, str(key::empty)));
		}
		const Atom duplicate_key = _object_property_key(state, editor, field_text(state, before_detail, key::kind, key::empty), duplicate_placement_id);
		const DictRef after_detail = _object_detail_by_key(state, editor, duplicate_key);
		_set_object_authoring_recap(state, editor, key::duplicate, gd::bool_field(state, result, key::changed, false), before_detail, after_detail, source_tile, tile, state.new_dict(), key::empty, Value(), Value());
	} else {
		set_message(state, editor, field_text(state, result, key::message, key::could_not_duplicate_object_placement));
	}
	return gd::bool_field(state, result, key::ok, false);
}

DictRef _duplicate_object_by_key(State &state, const Value &editor, Atom property_key, Vector2i destination_tile) {
	if (!_tile_in_bounds(state, editor, destination_tile)) {
		return failure(state, key::destination_tile_is_outside_the_map);
	}
	const DictRef detail = _object_detail_by_key(state, editor, property_key);
	if (gd::is_empty(state, detail)) {
		return failure(state, gd::format(state, key::no_duplicable_object_s_exists_in, { str(property_key) }));
	}
	const DictRef blocker = _first_blocking_object_detail_at(state, editor, destination_tile, key::empty);
	if (!gd::is_empty(state, blocker)) {
		const Value fallback = gd::field_or(state, blocker, key::kind, str(key::object));
		const Value label = gd::field_or(state, blocker, key::placement_id, fallback);
		return failure(state, gd::format(state, key::destination_d_d_already_has_s, { int_value(destination_tile.x), int_value(destination_tile.y), str(value_text(state, label)) }));
	}
	const Atom kind = field_text(state, detail, key::kind, key::empty);
	const Atom placement_id = field_text(state, detail, key::placement_id, key::empty);
	const Atom array_key = _placement_array_key(state, editor, kind);
	// _session.overworld.get(array_key, []): a missing array reads as empty.
	Value placements;
	const bool has_placements = state.lookup(editor_overworld(state, editor), str(array_key), placements);
	if (array_key == key::empty || (has_placements && !gd::is_array(placements))) {
		return failure(state, gd::format(state, key::working_copy_has_no_s_array, { str(_object_family_label(state, editor, kind)) }));
	}
	// for placement in placements: the append below ends the loop (it returns).
	for (int64_t index = 0; has_placements && index < state.array_size(placements.ref); ++index) {
		const Value placement = state.at(placements.ref, index);
		if (!gd::is_dict(placement)) {
			continue;
		}
		if (field_text(state, placement.ref, key::placement_id, key::empty) != placement_id) {
			continue;
		}
		const Vector2i source_tile = Vector2i::of(gd::int_field(state, placement.ref, key::x, 0), gd::int_field(state, placement.ref, key::y, 0));
		const DictRef duplicated_placement = gd::as_dict(gd::engine_duplicate(state, placement, true));
		const Atom duplicated_placement_id = _generate_duplicate_placement_id(state, editor, kind, placement_id, destination_tile);
		state.set(duplicated_placement, str(key::placement_id), str(duplicated_placement_id));
		state.set(duplicated_placement, str(key::x), int_value(destination_tile.x));
		state.set(duplicated_placement, str(key::y), int_value(destination_tile.y));
		state.set(duplicated_placement, str(key::editor_authored_placement), bool_value(true));
		state.append(placements.ref, dict_value(duplicated_placement));
		state.set(editor_overworld(state, editor), str(array_key), placements);
		gd::set_member(state, editor, key::_selected_property_object_key, str(_object_property_key(state, editor, kind, duplicated_placement_id)));
		const DictRef result = state.new_dict();
		state.set(result, str(key::ok), bool_value(true));
		state.set(result, str(key::changed), bool_value(true));
		state.set(result, str(key::message), str(gd::format(state, key::duplicated_s_s_from_d_d, { str(_object_family_label(state, editor, kind)), str(placement_id), int_value(source_tile.x), int_value(source_tile.y), int_value(destination_tile.x), int_value(destination_tile.y), str(duplicated_placement_id) })));
		state.set(result, str(key::object), dict_value(duplicated_placement));
		state.set(result, str(key::source_object), placement);
		state.set(result, str(key::from), dict_value(tile_payload(state, source_tile)));
		state.set(result, str(key::to), dict_value(tile_payload(state, destination_tile)));
		return result;
	}
	return failure(state, gd::format(state, key::no_s_placement_s_in_the, { str(_object_family_label(state, editor, kind)), str(placement_id) }));
}

bool _retheme_object(State &state, const Value &editor, Vector2i tile) {
	const auto family = [&]() { return member_text(state, editor, key::_selected_object_family); };
	const auto content_id = [&]() { return member_text(state, editor, key::_selected_object_content_id); };
	if (!_tile_in_bounds(state, editor, tile)) {
		return false;
	}
	if (family() == key::empty || content_id() == key::empty) {
		set_message(state, editor, key::choose_an_object_family_and_replacement);
		return false;
	}
	if (gd::is_empty(state, _object_content_lookup(state, editor, family(), content_id()))) {
		set_message(state, editor, gd::format(state, key::unknown_s_content_id_s, { str(_object_family_label(state, editor, family())), str(content_id()) }));
		return false;
	}
	const DictRef source_detail = _object_detail_for_family_at(state, editor, tile, family());
	if (gd::is_empty(state, source_detail)) {
		set_message(state, editor, gd::format(state, key::no_s_placement_at_d_d_2, { str(_object_family_label(state, editor, family())), int_value(tile.x), int_value(tile.y) }));
		return false;
	}
	const DictRef result = _retheme_object_by_key(state, editor, field_text(state, source_detail, key::property_key, key::empty), content_id());
	if (gd::bool_field(state, result, key::ok, false)) {
		set_dirty(state, editor, gd::to_bool(gd::member(state, editor, key::_dirty)) || gd::bool_field(state, result, key::changed, false));
		const DictRef after_detail = _object_detail_by_key(state, editor, field_text(state, source_detail, key::property_key, key::empty));
		_set_object_authoring_recap(state, editor, key::retheme, gd::bool_field(state, result, key::changed, false), source_detail, after_detail, tile, tile, state.new_dict(), key::empty, Value(), Value());
	} else {
		set_message(state, editor, field_text(state, result, key::message, key::could_not_retheme_object_placement));
	}
	return gd::bool_field(state, result, key::ok, false);
}

DictRef _object_detail_for_family_at(State &state, const Value &editor, Vector2i tile, Atom family) {
	const ArrayRef options = _property_object_options_at(state, editor, tile);
	for (int64_t index = 0; index < state.array_size(options); ++index) {
		const Value detail = state.at(options, index);
		if (gd::is_dict(detail) && field_text(state, detail.ref, key::kind, key::empty) == family) {
			return detail.ref;
		}
	}
	return state.new_dict();
}

DictRef _retheme_object_by_key(State &state, const Value &editor, Atom property_key, Atom replacement_content_id) {
	const DictRef detail = _object_detail_by_key(state, editor, property_key);
	if (gd::is_empty(state, detail)) {
		return failure(state, gd::format(state, key::no_rethemeable_object_s_exists_in, { str(property_key) }));
	}
	const Atom kind = field_text(state, detail, key::kind, key::empty);
	const Atom placement_id = field_text(state, detail, key::placement_id, key::empty);
	if (gd::is_empty(state, _object_content_lookup(state, editor, kind, replacement_content_id))) {
		return failure(state, gd::format(state, key::unknown_s_content_id_s, { str(_object_family_label(state, editor, kind)), str(replacement_content_id) }));
	}
	const Atom content_key = _placement_content_key(state, editor, kind);
	const Atom array_key = _placement_array_key(state, editor, kind);
	// _session.overworld.get(array_key, []): a missing array reads as empty.
	Value placements;
	const bool has_placements = state.lookup(editor_overworld(state, editor), str(array_key), placements);
	if (content_key == key::empty || array_key == key::empty || (has_placements && !gd::is_array(placements))) {
		return failure(state, gd::format(state, key::working_copy_has_no_s_array, { str(_object_family_label(state, editor, kind)) }));
	}
	const int64_t count = has_placements ? state.array_size(placements.ref) : 0;
	for (int64_t index = 0; index < count; ++index) {
		const Value placement = state.at(placements.ref, index);
		if (!gd::is_dict(placement)) {
			continue;
		}
		if (field_text(state, placement.ref, key::placement_id, key::empty) != placement_id) {
			continue;
		}
		const Atom previous_content_id = field_text(state, placement.ref, content_key, key::empty);
		gd::set_member(state, editor, key::_selected_property_object_key, str(property_key));
		if (previous_content_id == replacement_content_id) {
			const DictRef result = state.new_dict();
			state.set(result, str(key::ok), bool_value(true));
			state.set(result, str(key::changed), bool_value(false));
			state.set(result, str(key::message), str(gd::format(state, key::s_s_already_uses_s, { str(_object_family_label(state, editor, kind)), str(placement_id), str(replacement_content_id) })));
			state.set(result, str(key::object), dict_value(_object_detail_for_placement(state, editor, kind, placement.ref)));
			state.set(result, str(key::previous_content_id), str(previous_content_id));
			state.set(result, str(key::content_id), str(replacement_content_id));
			return result;
		}
		const DictRef before = gd::as_dict(gd::engine_duplicate(state, placement, true));
		state.set(placement.ref, str(content_key), str(replacement_content_id));
		state.set_at(placements.ref, index, placement);
		state.set(editor_overworld(state, editor), str(array_key), placements);
		const DictRef result = state.new_dict();
		state.set(result, str(key::ok), bool_value(true));
		state.set(result, str(key::changed), bool_value(!gd::equal(state, dict_value(before), placement)));
		state.set(result, str(key::message), str(gd::format(state, key::rethemed_s_s_from_s_to, { str(_object_family_label(state, editor, kind)), str(placement_id), str(previous_content_id), str(replacement_content_id) })));
		state.set(result, str(key::object), dict_value(_object_detail_for_placement(state, editor, kind, placement.ref)));
		state.set(result, str(key::object_before), dict_value(_object_detail_for_placement(state, editor, kind, before)));
		state.set(result, str(key::previous_content_id), str(previous_content_id));
		state.set(result, str(key::content_id), str(replacement_content_id));
		return result;
	}
	return failure(state, gd::format(state, key::no_s_placement_s_in_the, { str(_object_family_label(state, editor, kind)), str(placement_id) }));
}

DictRef _first_blocking_object_detail_at(State &state, const Value &editor, Vector2i tile, Atom ignored_property_key) {
	const ArrayRef details = _object_details_at(state, editor, tile, false);
	for (int64_t index = 0; index < state.array_size(details); ++index) {
		const Value detail = state.at(details, index);
		if (!gd::is_dict(detail)) {
			continue;
		}
		if (ignored_property_key != key::empty && field_text(state, detail.ref, key::property_key, key::empty) == ignored_property_key) {
			continue;
		}
		return detail.ref;
	}
	return state.new_dict();
}

DictRef _apply_object_properties(State &state, const Value &editor, DictRef detail, Atom owner, Atom difficulty, bool collected) {
	const Atom kind = field_text(state, detail, key::kind, key::empty);
	const Atom placement_id = field_text(state, detail, key::placement_id, key::empty);
	if (placement_id == key::empty) {
		return failure(state, key::selected_object_has_no_placement_id);
	}
	if (kind == key::town) {
		return _set_town_owner_property(state, editor, placement_id, owner);
	}
	if (kind == key::resource) {
		return _set_collected_property(state, editor, key::resource, placement_id, collected);
	}
	if (kind == key::artifact) {
		return _set_collected_property(state, editor, key::artifact, placement_id, collected);
	}
	if (kind == key::encounter) {
		return _set_encounter_difficulty_property(state, editor, placement_id, difficulty);
	}
	return failure(state, gd::format(state, key::no_mutable_properties_for_s, { str(kind) }));
}

DictRef _set_town_owner_property(State &state, const Value &editor, Atom placement_id, Atom owner) {
	if (owner == key::empty) {
		owner = key::neutral;
	}
	// TOWN_OWNER_OPTIONS.
	if (owner != key::neutral && owner != key::player && owner != key::enemy) {
		return failure(state, gd::format(state, key::unsupported_town_owner_s, { str(owner) }));
	}
	const Value working_copy = session(state, editor);
	// OverworldRules.transition_town_control(null, ...) answers ok false.
	if (working_copy.kind == Kind::Nil) {
		return failure(state, gd::format(state, key::could_not_update_town_owner_for, { str(placement_id) }));
	}
	const DictRef result = overworld_rules::transition_town_control(state, session_view(state, working_copy), placement_id, owner, key::empty, key::map_editor_working_copy);
	if (!gd::bool_field(state, result, key::ok, false)) {
		return failure(state, gd::format(state, key::could_not_update_town_owner_for, { str(placement_id) }));
	}
	Value town;
	if (!state.lookup(result, str(key::town), town)) {
		town = dict_value(state.new_dict());
	}
	const DictRef updated = state.new_dict();
	state.set(updated, str(key::ok), bool_value(true));
	state.set(updated, str(key::changed), bool_value(gd::bool_field(state, result, key::changed, false)));
	state.set(updated, str(key::message), str(gd::format(state, key::set_town_s_owner_to_s, { str(placement_id), str(owner) })));
	state.set(updated, str(key::object), town);
	return updated;
}

DictRef _set_encounter_difficulty_property(State &state, const Value &editor, Atom placement_id, Atom difficulty) {
	if (difficulty == key::empty) {
		difficulty = key::medium;
	}
	// ENCOUNTER_DIFFICULTY_OPTIONS.
	if (difficulty != key::low && difficulty != key::medium && difficulty != key::high && difficulty != key::pressure && difficulty != key::scripted) {
		return failure(state, gd::format(state, key::unsupported_encounter_difficulty_s, { str(difficulty) }));
	}
	// _session.overworld.get("encounters", []): a missing array reads as empty.
	Value encounters;
	const bool has_encounters = state.lookup(editor_overworld(state, editor), str(key::encounters), encounters);
	if (has_encounters && !gd::is_array(encounters)) {
		return failure(state, key::working_copy_has_no_encounter_array);
	}
	const int64_t count = has_encounters ? state.array_size(encounters.ref) : 0;
	for (int64_t index = 0; index < count; ++index) {
		const Value encounter = state.at(encounters.ref, index);
		if (!gd::is_dict(encounter)) {
			continue;
		}
		if (field_text(state, encounter.ref, key::placement_id, key::empty) != placement_id) {
			continue;
		}
		const Atom previous = field_text(state, encounter.ref, key::difficulty, key::medium);
		state.set(encounter.ref, str(key::difficulty), str(difficulty));
		state.set_at(encounters.ref, index, encounter);
		state.set(editor_overworld(state, editor), str(key::encounters), encounters);
		const DictRef result = state.new_dict();
		state.set(result, str(key::ok), bool_value(true));
		state.set(result, str(key::changed), bool_value(previous != difficulty));
		state.set(result, str(key::message), str(gd::format(state, key::set_encounter_s_difficulty_to_s, { str(placement_id), str(difficulty) })));
		state.set(result, str(key::object), encounter);
		return result;
	}
	return failure(state, gd::format(state, key::no_encounter_placement_s_in_the, { str(placement_id) }));
}

DictRef _set_collected_property(State &state, const Value &editor, Atom family, Atom placement_id, bool collected) {
	const Atom array_key = _placement_array_key(state, editor, family);
	// _session.overworld.get(array_key, []): a missing array reads as empty.
	Value placements;
	const bool has_placements = state.lookup(editor_overworld(state, editor), str(array_key), placements);
	if (array_key == key::empty || (has_placements && !gd::is_array(placements))) {
		return failure(state, gd::format(state, key::working_copy_has_no_s_array, { str(_object_family_label(state, editor, family)) }));
	}
	const int64_t count = has_placements ? state.array_size(placements.ref) : 0;
	for (int64_t index = 0; index < count; ++index) {
		const Value placement = state.at(placements.ref, index);
		if (!gd::is_dict(placement)) {
			continue;
		}
		if (field_text(state, placement.ref, key::placement_id, key::empty) != placement_id) {
			continue;
		}
		const DictRef before = gd::as_dict(gd::engine_duplicate(state, placement, true));
		state.set(placement.ref, str(key::collected), bool_value(collected));
		if (collected) {
			if (field_text(state, placement.ref, key::collected_by_faction_id, key::empty) == key::empty) {
				state.set(placement.ref, str(key::collected_by_faction_id), str(key::player));
			}
			if (gd::int_field(state, placement.ref, key::collected_day, 0) <= 0) {
				state.set(placement.ref, str(key::collected_day), gd::member(state, session(state, editor), key::day));
			}
		} else {
			state.set(placement.ref, str(key::collected_by_faction_id), str(key::empty));
			state.set(placement.ref, str(key::collected_day), int_value(0));
		}
		state.set_at(placements.ref, index, placement);
		state.set(editor_overworld(state, editor), str(array_key), placements);
		const DictRef result = state.new_dict();
		state.set(result, str(key::ok), bool_value(true));
		state.set(result, str(key::changed), bool_value(!gd::equal(state, dict_value(before), placement)));
		state.set(result, str(key::message), str(gd::format(state, key::set_s_s_collected_to_s, { str(_object_family_label(state, editor, family)), str(placement_id), str(collected ? key::true_ : key::false_) })));
		state.set(result, str(key::object), placement);
		return result;
	}
	return failure(state, gd::format(state, key::no_s_placement_s_in_the, { str(_object_family_label(state, editor, family)), str(placement_id) }));
}

DictRef _build_runtime_placement(State &state, const Value &editor, Atom family, Atom content_id, Atom placement_id, Vector2i tile) {
	if (family == key::town) {
		const DictRef placement = state.new_dict();
		state.set(placement, str(key::placement_id), str(placement_id));
		state.set(placement, str(key::town_id), str(content_id));
		state.set(placement, str(key::x), int_value(tile.x));
		state.set(placement, str(key::y), int_value(tile.y));
		state.set(placement, str(key::owner), str(key::neutral));
		const ArrayRef placements = state.new_array();
		state.append(placements, dict_value(placement));
		const ArrayRef town_placements = scenario_factory::_build_town_states(state, array_value(placements));
		return state.array_size(town_placements) != 0 ? gd::as_dict(state.at(town_placements, 0)) : state.new_dict();
	}
	if (family == key::resource) {
		const DictRef placement = state.new_dict();
		state.set(placement, str(key::placement_id), str(placement_id));
		state.set(placement, str(key::site_id), str(content_id));
		state.set(placement, str(key::x), int_value(tile.x));
		state.set(placement, str(key::y), int_value(tile.y));
		const ArrayRef placements = state.new_array();
		state.append(placements, dict_value(placement));
		const ArrayRef resource_placements = scenario_factory::_build_resource_states(state, array_value(placements));
		return state.array_size(resource_placements) != 0 ? gd::as_dict(state.at(resource_placements, 0)) : state.new_dict();
	}
	if (family == key::artifact) {
		const DictRef placement = state.new_dict();
		state.set(placement, str(key::placement_id), str(placement_id));
		state.set(placement, str(key::artifact_id), str(content_id));
		state.set(placement, str(key::x), int_value(tile.x));
		state.set(placement, str(key::y), int_value(tile.y));
		const ArrayRef placements = state.new_array();
		state.append(placements, dict_value(placement));
		const ArrayRef artifact_placements = artifact_rules::build_artifact_nodes(state, array_value(placements), key::empty);
		return state.array_size(artifact_placements) != 0 ? gd::as_dict(state.at(artifact_placements, 0)) : state.new_dict();
	}
	if (family == key::encounter) {
		const DictRef placement = state.new_dict();
		state.set(placement, str(key::placement_id), str(placement_id));
		state.set(placement, str(key::encounter_id), str(content_id));
		state.set(placement, str(key::x), int_value(tile.x));
		state.set(placement, str(key::y), int_value(tile.y));
		state.set(placement, str(key::difficulty), str(key::medium));
		const Value scenario_id = gd::member(state, session(state, editor), key::scenario_id);
		const Atom seed_text = gd::format(state, key::s_s_d_d, { scenario_id, str(placement_id), int_value(tile.x), int_value(tile.y) });
		state.set(placement, str(key::combat_seed), int_value(gd::hash(state, str(seed_text))));
		return placement;
	}
	return state.new_dict();
}

void _remove_resolved_encounter_ids(State &state, const Value &editor, ArrayRef placement_ids) {
	// _session.overworld.get("resolved_encounters", []): a missing array reads
	// as empty, and an empty one is stored.
	Value resolved;
	const bool has_resolved = state.lookup(editor_overworld(state, editor), str(key::resolved_encounters), resolved);
	if (has_resolved && !gd::is_array(resolved)) {
		return;
	}
	const ArrayRef updated = state.new_array();
	for (int64_t index = 0; has_resolved && index < state.array_size(resolved.ref); ++index) {
		const Value value = state.at(resolved.ref, index);
		if (gd::array_has(state, placement_ids, str(value_text(state, value)))) {
			continue;
		}
		state.append(updated, value);
	}
	state.set(editor_overworld(state, editor), str(key::resolved_encounters), array_value(updated));
}

DictRef _restore_selected_tile_from_authored(State &state, const Value &editor) {
	if (session(state, editor).kind == Kind::Nil) {
		return failure(state, key::no_editor_working_copy_is_loaded_2);
	}
	const Value selected_tile = gd::member(state, editor, key::_selected_tile);
	const Vector2i tile = Vector2i::of(selected_tile.vx(), selected_tile.vy());
	if (!_tile_in_bounds(state, editor, tile)) {
		return failure(state, key::selected_tile_is_outside_the_map);
	}
	const Value baseline = _authored_baseline_session(state, editor);
	if (baseline.kind == Kind::Nil || gd::equal(state, gd::member(state, baseline, key::scenario_id), str(key::empty))) {
		return failure(state, gd::format(state, key::could_not_read_loaded_map_baseline, { gd::member(state, session(state, editor), key::scenario_id) }));
	}

	const Value before_overworld = gd::engine_duplicate(state, dict_value(editor_overworld(state, editor)), true);
	const DictRef before_inspection = _tile_inspection_payload(state, editor, tile);
	const DictRef terrain_result = _restore_tile_terrain_from_baseline(state, editor, tile, baseline);
	if (!gd::bool_field(state, terrain_result, key::ok, false)) {
		return terrain_result;
	}
	const DictRef road_result = _restore_tile_roads_from_baseline(state, editor, tile, baseline);
	const DictRef hero_result = _restore_tile_hero_start_from_baseline(state, editor, tile, baseline);
	const DictRef object_result = _restore_tile_objects_from_baseline(state, editor, tile, baseline);
	_remove_stale_editor_object_keys(state, editor);

	// before_overworld != _session.overworld: a save-sized tree, compared by the
	// engine when both are loaded.
	const bool changed = !gd::equal_loaded(state, before_overworld, dict_value(editor_overworld(state, editor)));
	Atom message = gd::format(state, key::restored_tile_d_d_from_loaded, { int_value(tile.x), int_value(tile.y) });
	if (!changed) {
		message = gd::format(state, key::tile_d_d_already_matches_the, { int_value(tile.x), int_value(tile.y) });
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(true));
	state.set(result, str(key::changed), bool_value(changed));
	state.set(result, str(key::message), str(message));
	state.set(result, str(key::tile), dict_value(tile_payload(state, tile)));
	state.set(result, str(key::before_tile_inspection), dict_value(before_inspection));
	state.set(result, str(key::terrain_restore), dict_value(terrain_result));
	state.set(result, str(key::road_restore), dict_value(road_result));
	state.set(result, str(key::hero_restore), dict_value(hero_result));
	state.set(result, str(key::object_restore), dict_value(object_result));
	return result;
}

Value _authored_baseline_session(State &state, const Value &editor) {
	const Value working_copy = session(state, editor);
	if (working_copy.kind == Kind::Nil || gd::equal(state, gd::member(state, working_copy, key::scenario_id), str(key::empty))) {
		return Value();
	}
	const Value cache = gd::member(state, editor, key::_authored_baseline_cache);
	if (cache.kind != Kind::Nil && gd::equal(state, gd::member(state, editor, key::_authored_baseline_cache_id), gd::member(state, working_copy, key::scenario_id))) {
		return session_object(state, cache);
	}
	return Value();
}

DictRef _restore_tile_terrain_from_baseline(State &state, const Value &editor, Vector2i tile, const Value &baseline) {
	const Atom authored_terrain = _terrain_at_in_overworld(state, editor, gd::as_dict(gd::member(state, baseline, key::overworld)), tile);
	if (authored_terrain == key::empty) {
		return failure(state, gd::format(state, key::authored_baseline_has_no_terrain_at, { int_value(tile.x), int_value(tile.y) }));
	}
	const Atom previous_terrain = _terrain_at(state, editor, tile);
	if (previous_terrain != authored_terrain) {
		_set_tile_terrain(state, editor, tile, authored_terrain);
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(true));
	state.set(result, str(key::changed), bool_value(previous_terrain != authored_terrain));
	state.set(result, str(key::previous_terrain_id), str(previous_terrain));
	state.set(result, str(key::authored_terrain_id), str(authored_terrain));
	return result;
}

DictRef _restore_tile_roads_from_baseline(State &state, const Value &editor, Vector2i tile, const Value &baseline) {
	const ArrayRef authored_road_layers = _road_layers_at_in_overworld(state, editor, gd::as_dict(gd::member(state, baseline, key::overworld)), tile);
	const DictRef authored_by_id = state.new_dict();
	for (int64_t index = 0; index < state.array_size(authored_road_layers); ++index) {
		const Value road = state.at(authored_road_layers, index);
		if (!gd::is_dict(road)) {
			continue;
		}
		state.set(authored_by_id, str(field_text(state, road.ref, key::id, key::empty)), road);
	}

	const DictRef terrain_layers = _terrain_layers(state, editor);
	Value roads_value;
	if (!state.lookup(terrain_layers, str(key::roads), roads_value) || !gd::is_array(roads_value)) {
		roads_value = array_value(state.new_array());
	}
	const ArrayRef roads = roads_value.ref;

	const ArrayRef restored_layer_ids = state.new_array();
	const ArrayRef removed_layer_ids = state.new_array();
	const DictRef found_authored_ids = state.new_dict();
	const int64_t road_count = state.array_size(roads);
	for (int64_t index = 0; index < road_count; ++index) {
		const Value road = state.at(roads, index);
		if (!gd::is_dict(road)) {
			continue;
		}
		const Atom road_id = field_text(state, road.ref, key::id, key::empty);
		const bool should_keep_tile = state.has(authored_by_id, str(road_id));
		// road.get("tiles", []), and [] for anything but an Array: read only.
		Value tiles;
		const bool has_tiles = state.lookup(road.ref, str(key::tiles), tiles) && gd::is_array(tiles);
		const ArrayRef updated_tiles = state.new_array();
		bool kept_tile = false;
		for (int64_t tile_index = 0; has_tiles && tile_index < state.array_size(tiles.ref); ++tile_index) {
			const Value tile_value = state.at(tiles.ref, tile_index);
			if (_tile_payload_matches(state, editor, tile_value, tile)) {
				if (should_keep_tile && !kept_tile) {
					state.append(updated_tiles, dict_value(_authored_road_tile_payload(state, editor, gd::as_dict(gd::index(state, authored_by_id, str(road_id))), tile)));
					kept_tile = true;
				} else {
					state.append(removed_layer_ids, str(road_id));
				}
				continue;
			}
			state.append(updated_tiles, tile_value);
		}
		if (should_keep_tile) {
			state.set(found_authored_ids, str(road_id), bool_value(true));
			if (!kept_tile) {
				state.append(updated_tiles, dict_value(_authored_road_tile_payload(state, editor, gd::as_dict(gd::index(state, authored_by_id, str(road_id))), tile)));
				state.append(restored_layer_ids, str(road_id));
			}
		}
		state.set(road.ref, str(key::tiles), array_value(updated_tiles));
		state.set_at(roads, index, road);
	}

	for (int64_t index = 0; index < state.array_size(authored_road_layers); ++index) {
		const Value road = state.at(authored_road_layers, index);
		if (!gd::is_dict(road)) {
			continue;
		}
		const Atom road_id = field_text(state, road.ref, key::id, key::empty);
		if (state.has(found_authored_ids, str(road_id))) {
			continue;
		}
		const DictRef restored_road = gd::as_dict(gd::engine_duplicate(state, road, true));
		const ArrayRef restored_tiles = state.new_array();
		state.append(restored_tiles, dict_value(_authored_road_tile_payload(state, editor, road.ref, tile)));
		state.set(restored_road, str(key::tiles), array_value(restored_tiles));
		state.append(roads, dict_value(restored_road));
		state.append(restored_layer_ids, str(road_id));
	}

	state.set(terrain_layers, str(key::roads), array_value(roads));
	state.set(editor_overworld(state, editor), str(key::terrain_layers), dict_value(terrain_layers));
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(true));
	state.set(result, str(key::changed), bool_value(state.array_size(restored_layer_ids) != 0 || state.array_size(removed_layer_ids) != 0));
	state.set(result, str(key::authored_road_layers), array_value(gd::keys(state, authored_by_id)));
	state.set(result, str(key::restored_road_layers), array_value(restored_layer_ids));
	state.set(result, str(key::removed_road_layers), array_value(removed_layer_ids));
	return result;
}

DictRef _restore_tile_hero_start_from_baseline(State &state, const Value &editor, Vector2i tile, const Value &baseline) {
	const Vector2i authored_start = overworld_rules::hero_position(state, session_view(state, baseline));
	const Vector2i current_start = overworld_rules::hero_position(state, session_view(state, session(state, editor)));
	const bool applies = tile == authored_start || tile == current_start;
	const DictRef result = state.new_dict();
	if (!applies) {
		state.set(result, str(key::applied), bool_value(false));
		state.set(result, str(key::changed), bool_value(false));
		state.set(result, str(key::authored_start), dict_value(tile_payload(state, authored_start)));
		state.set(result, str(key::previous_start), dict_value(tile_payload(state, current_start)));
		return result;
	}
	if (!(current_start == authored_start)) {
		_set_hero_position(state, editor, authored_start);
	}
	state.set(result, str(key::applied), bool_value(true));
	state.set(result, str(key::changed), bool_value(!(current_start == authored_start)));
	state.set(result, str(key::authored_start), dict_value(tile_payload(state, authored_start)));
	state.set(result, str(key::previous_start), dict_value(tile_payload(state, current_start)));
	return result;
}

DictRef _restore_tile_objects_from_baseline(State &state, const Value &editor, Vector2i tile, const Value &baseline) {
	const ArrayRef restored_ids = state.new_array();
	const ArrayRef removed_ids = state.new_array();
	for (const Atom family : { Atom(key::town), Atom(key::resource), Atom(key::artifact), Atom(key::encounter) }) {
		const ArrayRef baseline_placements = _placements_for_family_at_in_session(state, editor, baseline, family, tile);
		const DictRef baseline_by_id = state.new_dict();
		for (int64_t index = 0; index < state.array_size(baseline_placements); ++index) {
			const Value baseline_placement = state.at(baseline_placements, index);
			if (gd::is_dict(baseline_placement)) {
				state.set(baseline_by_id, str(field_text(state, baseline_placement.ref, key::placement_id, key::empty)), baseline_placement);
			}
		}
		const Atom array_key = _placement_array_key(state, editor, family);
		// _session.overworld.get(array_key, []), and [] for anything but an
		// Array: read only.
		Value placements;
		const bool has_placements = state.lookup(editor_overworld(state, editor), str(array_key), placements) && gd::is_array(placements);
		const ArrayRef updated = state.new_array();
		const ArrayRef restored_for_family = state.new_array();
		const ArrayRef removed_for_family = state.new_array();
		for (int64_t index = 0; has_placements && index < state.array_size(placements.ref); ++index) {
			const Value placement = state.at(placements.ref, index);
			if (!gd::is_dict(placement)) {
				state.append(updated, placement);
				continue;
			}
			const Atom placement_id = field_text(state, placement.ref, key::placement_id, key::empty);
			if (state.has(baseline_by_id, str(placement_id))) {
				if (!gd::array_has(state, restored_for_family, str(placement_id))) {
					const DictRef restored_placement = gd::as_dict(gd::engine_duplicate(state, gd::index(state, baseline_by_id, str(placement_id)), true));
					state.append(updated, dict_value(restored_placement));
					state.append(restored_for_family, str(placement_id));
				} else {
					state.append(removed_for_family, str(placement_id));
				}
				continue;
			}
			if (_placement_at_tile(state, editor, placement.ref, tile)) {
				state.append(removed_for_family, str(placement_id));
				continue;
			}
			state.append(updated, placement);
		}
		for (int64_t index = 0; index < state.array_size(baseline_placements); ++index) {
			const Value baseline_placement = state.at(baseline_placements, index);
			if (!gd::is_dict(baseline_placement)) {
				continue;
			}
			const Atom placement_id = field_text(state, baseline_placement.ref, key::placement_id, key::empty);
			if (gd::array_has(state, restored_for_family, str(placement_id))) {
				continue;
			}
			state.append(updated, gd::engine_duplicate(state, baseline_placement, true));
			state.append(restored_for_family, str(placement_id));
		}
		state.set(editor_overworld(state, editor), str(array_key), array_value(updated));
		ai::append_array(state, restored_ids, restored_for_family);
		ai::append_array(state, removed_ids, removed_for_family);
		if (family == key::encounter) {
			const ArrayRef encounter_ids_to_unresolve = state.new_array();
			ai::append_array(state, encounter_ids_to_unresolve, restored_for_family);
			ai::append_array(state, encounter_ids_to_unresolve, removed_for_family);
			_remove_resolved_encounter_ids(state, editor, encounter_ids_to_unresolve);
		}
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(true));
	state.set(result, str(key::restored_ids), array_value(restored_ids));
	state.set(result, str(key::removed_ids), array_value(removed_ids));
	return result;
}

ArrayRef _placements_for_family_at_in_session(State &state, const Value &editor, const Value &session, Atom family, Vector2i tile) {
	const ArrayRef placements_at_tile = state.new_array();
	if (session.kind == Kind::Nil) {
		return placements_at_tile;
	}
	const Atom array_key = _placement_array_key(state, editor, family);
	// session.overworld.get(array_key, []): a missing array reads as empty.
	Value placements;
	if (!state.lookup(gd::as_dict(gd::member(state, session, key::overworld)), str(array_key), placements) || !gd::is_array(placements)) {
		return placements_at_tile;
	}
	for (int64_t index = 0; index < state.array_size(placements.ref); ++index) {
		const Value placement = state.at(placements.ref, index);
		if (gd::is_dict(placement) && _placement_at_tile(state, editor, placement.ref, tile)) {
			state.append(placements_at_tile, gd::engine_duplicate(state, placement, true));
		}
	}
	return placements_at_tile;
}

ArrayRef _road_layers_at_in_overworld(State &state, const Value &editor, DictRef overworld, Vector2i tile) {
	const ArrayRef matching_roads = state.new_array();
	// overworld.get("terrain_layers", {}) and .get("roads", []): a missing one
	// reads as empty.
	Value terrain_layers;
	if (!state.lookup(overworld, str(key::terrain_layers), terrain_layers) || !gd::is_dict(terrain_layers)) {
		return matching_roads;
	}
	Value roads;
	if (!state.lookup(terrain_layers.ref, str(key::roads), roads) || !gd::is_array(roads)) {
		return matching_roads;
	}
	for (int64_t index = 0; index < state.array_size(roads.ref); ++index) {
		const Value road = state.at(roads.ref, index);
		if (!gd::is_dict(road)) {
			continue;
		}
		Value tiles;
		if (!state.lookup(road.ref, str(key::tiles), tiles) || !gd::is_array(tiles)) {
			continue;
		}
		for (int64_t tile_index = 0; tile_index < state.array_size(tiles.ref); ++tile_index) {
			if (_tile_payload_matches(state, editor, state.at(tiles.ref, tile_index), tile)) {
				state.append(matching_roads, gd::engine_duplicate(state, road, true));
				break;
			}
		}
	}
	return matching_roads;
}

DictRef _authored_road_tile_payload(State &state, const Value &editor, DictRef road, Vector2i tile) {
	// road.get("tiles", []): a missing array reads as empty.
	Value tiles;
	if (state.lookup(road, str(key::tiles), tiles) && gd::is_array(tiles)) {
		for (int64_t index = 0; index < state.array_size(tiles.ref); ++index) {
			const Value tile_value = state.at(tiles.ref, index);
			if (_tile_payload_matches(state, editor, tile_value, tile)) {
				return _tile_payload_for_restore(state, editor, tile_value, tile);
			}
		}
	}
	return tile_payload(state, tile);
}

DictRef _tile_payload_for_restore(State &state, const Value &editor, const Value &value, Vector2i tile) {
	(void)editor;
	if (gd::is_dict(value)) {
		return gd::as_dict(gd::engine_duplicate(state, value, true));
	}
	return tile_payload(state, tile);
}

bool _tile_payload_matches(State &state, const Value &editor, const Value &value, Vector2i tile) {
	(void)editor;
	return gd::is_dict(value) && gd::int_field(state, value.ref, key::x, -999) == tile.x && gd::int_field(state, value.ref, key::y, -999) == tile.y;
}

Atom _terrain_at_in_overworld(State &state, const Value &editor, DictRef overworld, Vector2i tile) {
	(void)editor;
	// overworld.get("map", []): a missing map reads as empty.
	Value map_data;
	if (!state.lookup(overworld, str(key::map), map_data) || !gd::is_array(map_data) || tile.y < 0 || tile.y >= state.array_size(map_data.ref)) {
		return key::empty;
	}
	const Value row = state.at(map_data.ref, tile.y);
	if (!gd::is_array(row) || tile.x < 0 || tile.x >= state.array_size(row.ref)) {
		return key::empty;
	}
	return value_text(state, state.at(row.ref, tile.x));
}

bool _set_tile_terrain(State &state, const Value &editor, Vector2i tile, Atom terrain_id) {
	if (!_tile_in_bounds(state, editor, tile) || terrain_id == key::empty) {
		return false;
	}
	_materialize_last_terrain_final_normalization(state, editor);
	const DictRef overworld = editor_overworld(state, editor);
	// _session.overworld.get("map", []): a missing map reads as empty.
	Value map_data;
	if (!state.lookup(overworld, str(key::map), map_data) || !gd::is_array(map_data) || tile.y >= state.array_size(map_data.ref)) {
		return false;
	}
	const Value row = state.at(map_data.ref, tile.y);
	if (!gd::is_array(row) || tile.x >= state.array_size(row.ref)) {
		return false;
	}
	state.set_at(row.ref, tile.x, str(terrain_id));
	state.set_at(map_data.ref, tile.y, row);
	state.set(overworld, str(key::map), map_data);
	return true;
}

void _remove_stale_editor_object_keys(State &state, const Value &editor) {
	if (member_text(state, editor, key::_selected_property_object_key) != key::empty && gd::is_empty(state, _object_detail_by_key(state, editor, member_text(state, editor, key::_selected_property_object_key)))) {
		gd::set_member(state, editor, key::_selected_property_object_key, str(key::empty));
	}
	if (member_text(state, editor, key::_pending_move_object_key) != key::empty && gd::is_empty(state, _object_detail_by_key(state, editor, member_text(state, editor, key::_pending_move_object_key)))) {
		gd::set_member(state, editor, key::_pending_move_object_key, str(key::empty));
	}
	if (member_text(state, editor, key::_pending_duplicate_object_key) != key::empty && gd::is_empty(state, _object_detail_by_key(state, editor, member_text(state, editor, key::_pending_duplicate_object_key)))) {
		gd::set_member(state, editor, key::_pending_duplicate_object_key, str(key::empty));
	}
}

} // namespace map_editor

} // namespace aurelion::rules::port
