// MapEditorShell's rules (Phase 7, slice 7.13): staging the play copy, its readiness gate, Save Copy's
// readiness and draft and the saved records.

#include "aurelion_rules/port/map_editor.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/session_view.hpp"

namespace aurelion::rules::port {

namespace {

using gd::array_value;
using gd::Atom;
using gd::bool_value;
using gd::dict_value;
using gd::DictRef;
using gd::ArrayRef;
using gd::int_value;
using gd::str;
using overworld_rules::Vector2i;
using state::Kind;
using state::State;
using state::Value;
namespace key = state::key;

// String(value) and str(value): stringify's kinds, and a float or a container
// as the engine prints it.
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
Atom string_field_of(State &state, DictRef dict, Atom field, Atom fallback) {
	return string_of(state, state.get(dict, str(field), str(fallback)));
}

// d.get(field, []): the field, or a new Array.
Value field_or_new_array(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return array_value(state.new_array());
}

// _session.scenario_id, _session.flags and _session.overworld (SessionData's
// typed fields); a null session is GDScript's error.
Atom scenario_id_of(State &state, const Value &session) {
	return gd::to_string(gd::member(state, session, key::scenario_id));
}

DictRef flags_of(State &state, const Value &session) {
	return gd::as_dict(gd::member(state, session, key::flags));
}

DictRef overworld_of(State &state, const Value &session) {
	return gd::as_dict(gd::member(state, session, key::overworld));
}

// var runtime_record = _session.flags.get(K, {})
// if not (runtime_record is Dictionary) or runtime_record.is_empty():
// 	runtime_record = _session.overworld.get(K, {})
Value runtime_record_of(State &state, const Value &session) {
	const Value record_key = str(key::native_random_map_runtime_scenario_record);
	Value record;
	if (state.lookup(flags_of(state, session), record_key, record) && gd::is_dict(record) && !gd::is_empty(state, record.ref)) {
		return record;
	}
	if (state.lookup(overworld_of(state, session), record_key, record)) {
		return record;
	}
	return dict_value(state.new_dict());
}

// {"x": tile.x, "y": tile.y}
DictRef position_payload(State &state, Vector2i tile) {
	const DictRef payload = state.new_dict();
	state.set(payload, str(key::x), int_value(tile.x));
	state.set(payload, str(key::y), int_value(tile.y));
	return payload;
}

// int(d.get(field, []).size())
int64_t field_size(State &state, DictRef dict, Atom field) {
	Value found;
	if (!state.lookup(dict, str(field), found)) {
		return 0;
	}
	return ai::vsize(state, found);
}

// var warnings: Array = validation.get("warnings", [])
// String(warnings[0]).strip_edges() if not warnings.is_empty() else ""
Atom first_warning_of(State &state, DictRef validation) {
	Value found;
	if (!state.lookup(validation, str(key::warnings), found)) {
		return key::empty;
	}
	const ArrayRef warnings = gd::as_array(found);
	if (state.array_size(warnings) == 0) {
		return key::empty;
	}
	return gd::strip_edges(state, string_of(state, state.at(warnings, 0)));
}

// {"ready": false, "blockers": [blocker]}
DictRef not_ready(State &state, Atom blocker) {
	const DictRef payload = state.new_dict();
	state.set(payload, str(key::ready), bool_value(false));
	const ArrayRef blockers = state.new_array();
	state.append(blockers, str(blocker));
	state.set(payload, str(key::blockers), array_value(blockers));
	return payload;
}

} // namespace

namespace map_editor {

bool _stage_working_copy_for_play(State &state, const Value &editor) {
	_prepare_working_copy_snapshot_for_return(state, editor);
	const Value session_state = gd::autoload(state, key::SessionState);
	const Value working_copy = session_object(state, session(state, editor));
	const Value baseline = session_object(state, _authored_baseline_session(state, editor));
	const Value staged_session = gd::call_method(state, session_state, key::set_editor_working_copy_session, { working_copy, baseline });
	const Value play_session = gd::call_method(state, session_state, key::duplicate_editor_working_copy_session, {});
	if (staged_session.kind == Kind::Nil || play_session.kind == Kind::Nil) {
		gd::call_method(state, session_state, key::set_editor_working_copy_session, { Value() });
		gd::set_member(state, editor, key::_last_message, str(key::could_not_stage_the_editor_working));
		return false;
	}
	_prepare_working_copy_for_play(state, editor, play_session);
	gd::call_method(state, session_state, key::set_active_session, { session_object(state, play_session) });
	return true;
}

DictRef _editor_play_readiness_gate_payload(State &state, const Value &editor) {
	const Value current = session(state, editor);
	if (current.kind == Kind::Nil) {
		const DictRef payload = state.new_dict();
		state.set(payload, str(key::button_label), str(key::play_copy));
		state.set(payload, str(key::text), str(key::empty));
		state.set(payload, str(key::tooltip), str(key::load_a_map_package_working_copy));
		state.set(payload, str(key::state), str(key::no_working_copy));
		return payload;
	}
	const DictRef validation = _scenario_authoring_validation_payload(state, editor);
	const int64_t warning_count = gd::int_field(state, validation, key::warning_count, 0);
	const int64_t covered_count = gd::int_field(state, validation, key::covered_objective_anchor_count, 0);
	const int64_t objective_count = field_size(state, validation, key::objective_anchors);
	const int64_t missing_count = gd::int_field(state, validation, key::missing_objective_anchor_count, 0);
	const Vector2i hero_position = overworld_rules::hero_position(state, session_view(state, current));
	const bool ready = warning_count == 0 && missing_count == 0;
	const Atom gate_state = ready ? key::ready : key::review;
	const Atom action = ready ? key::play_copy_can_smoke_test_this : key::review_warnings_before_play_copy;
	const Atom text = gd::format(state, key::play_gate_s_objectives_d_d, {
		str(action),
		int_value(covered_count),
		int_value(objective_count),
		int_value(warning_count),
		int_value(hero_position.x),
		int_value(hero_position.y),
		int_value(_placement_count(state, editor)),
	});
	const Atom first_warning = first_warning_of(state, validation);
	const DictRef payload = state.new_dict();
	state.set(payload, str(key::button_label), str(ready ? key::play_copy_ready : key::play_copy_check));
	state.set(payload, str(key::text), str(text));
	state.set(payload, str(key::tooltip), str(first_warning != key::empty ? gd::format(state, key::s_s_12, { str(text), str(first_warning) }) : text));
	state.set(payload, str(key::state), str(gate_state));
	state.set(payload, str(key::ready), bool_value(ready));
	state.set(payload, str(key::action), str(action));
	state.set(payload, str(key::covered_objective_anchor_count), int_value(covered_count));
	state.set(payload, str(key::objective_anchor_count), int_value(objective_count));
	state.set(payload, str(key::missing_objective_anchor_count), int_value(missing_count));
	state.set(payload, str(key::warning_count), int_value(warning_count));
	state.set(payload, str(key::first_warning), str(first_warning));
	state.set(payload, str(key::hero_position), dict_value(position_payload(state, hero_position)));
	state.set(payload, str(key::object_count), int_value(_placement_count(state, editor)));
	return payload;
}

DictRef _editor_scenario_validation_check_payload(State &state, const Value &editor) {
	const Value current = session(state, editor);
	if (current.kind == Kind::Nil) {
		const DictRef payload = state.new_dict();
		state.set(payload, str(key::text), str(key::empty));
		state.set(payload, str(key::tooltip), str(key::load_a_map_package_working_copy_3));
		state.set(payload, str(key::state), str(key::no_working_copy));
		state.set(payload, str(key::ready), bool_value(false));
		return payload;
	}
	const DictRef scenario = gd::content_row(state, state::ContentTable::Scenario, scenario_id_of(state, current));
	const Atom scenario_name = string_of(state, state.get(scenario, str(key::name), str(scenario_id_of(state, current))));
	const DictRef validation = _scenario_authoring_validation_payload(state, editor);
	const int64_t warning_count = gd::int_field(state, validation, key::warning_count, 0);
	const int64_t covered_count = gd::int_field(state, validation, key::covered_objective_anchor_count, 0);
	const int64_t objective_count = field_size(state, validation, key::objective_anchors);
	const int64_t missing_count = gd::int_field(state, validation, key::missing_objective_anchor_count, 0);
	const Vector2i hero_position = overworld_rules::hero_position(state, session_view(state, current));
	const bool ready = warning_count == 0 && missing_count == 0;
	const Atom check_state = ready ? key::ready : key::review;
	const Atom next_step = ready ? key::play_copy_can_smoke_test_this : key::review_authoring_warnings_before_play_copy;
	const Atom text = gd::format(state, key::scenario_check_s_objectives_d_d, {
		str(next_step),
		int_value(covered_count),
		int_value(objective_count),
		int_value(warning_count),
		int_value(hero_position.x),
		int_value(hero_position.y),
		int_value(_placement_count(state, editor)),
	});
	const Atom first_warning = first_warning_of(state, validation);
	Atom tooltip = gd::format(state, key::scenario_validation_scenario_s_state_s, {
		str(scenario_name),
		str(gd::capitalize(state, check_state)),
		int_value(covered_count),
		int_value(objective_count),
		int_value(warning_count),
		int_value(hero_position.x),
		int_value(hero_position.y),
		int_value(_placement_count(state, editor)),
		str(next_step),
	});
	if (first_warning != key::empty) {
		tooltip = gd::format(state, key::s_first_warning_s, { str(tooltip), str(first_warning) });
	}
	const DictRef payload = state.new_dict();
	state.set(payload, str(key::text), str(text));
	state.set(payload, str(key::tooltip), str(tooltip));
	state.set(payload, str(key::state), str(check_state));
	state.set(payload, str(key::ready), bool_value(ready));
	state.set(payload, str(key::scenario_id), str(scenario_id_of(state, current)));
	state.set(payload, str(key::scenario_name), str(scenario_name));
	state.set(payload, str(key::covered_objective_anchor_count), int_value(covered_count));
	state.set(payload, str(key::objective_anchor_count), int_value(objective_count));
	state.set(payload, str(key::missing_objective_anchor_count), int_value(missing_count));
	state.set(payload, str(key::warning_count), int_value(warning_count));
	state.set(payload, str(key::first_warning), str(first_warning));
	state.set(payload, str(key::hero_position), dict_value(position_payload(state, hero_position)));
	state.set(payload, str(key::object_count), int_value(_placement_count(state, editor)));
	state.set(payload, str(key::scope), str(key::editor_working_copy_only));
	return payload;
}

DictRef _save_copy_readiness_payload(State &state, const Value &editor) {
	if (session(state, editor).kind == Kind::Nil) {
		return not_ready(state, key::no_editor_working_copy_is_loaded_2);
	}
	const Value memo = _editor_validation_memo_lookup(state, editor, key::save_copy_readiness);
	if (gd::is_dict(memo)) {
		return memo.ref;
	}
	if (gd::is_empty(state, _editor_scenario_template(state, editor))) {
		return not_ready(state, _missing_scenario_template_blocker(state, editor));
	}
	const ArrayRef blockers = _save_copy_validation_blockers(state, editor);
	const DictRef readiness = state.new_dict();
	state.set(readiness, str(key::ready), bool_value(state.array_size(blockers) == 0));
	state.set(readiness, str(key::blockers), array_value(blockers));
	const DictRef validation_memo = gd::as_dict(gd::member(state, editor, key::_editor_validation_memo));
	state.set(validation_memo, str(key::save_copy_readiness), dict_value(readiness));
	return gd::as_dict(gd::index(state, gd::as_dict(gd::member(state, editor, key::_editor_validation_memo)), str(key::save_copy_readiness)));
}

DictRef _save_copy_draft_payload(State &state, const Value &editor) {
	if (session(state, editor).kind == Kind::Nil) {
		return not_ready(state, key::no_editor_working_copy_is_loaded_2);
	}
	const int64_t revision = gd::to_int(state, gd::member(state, editor, key::_editor_edit_revision));
	gd::set_member(state, editor, key::_editor_edit_revision, int_value(gd::add(revision, 1)));
	const DictRef scenario = _editor_scenario_template(state, editor);
	if (gd::is_empty(state, scenario)) {
		return not_ready(state, _missing_scenario_template_blocker(state, editor));
	}
	const ArrayRef blockers = _save_copy_validation_blockers(state, editor);
	const DictRef scenario_record = _export_scenario_record_from_working_copy(state, editor, scenario);
	const DictRef terrain_layers_record = _export_terrain_layers_record_from_working_copy(state, editor);
	ai::append_array(state, blockers, _validate_export_scenario_record(state, editor, scenario_record));
	ai::append_array(state, blockers, _validate_export_terrain_layers_record(state, editor, terrain_layers_record));
	const DictRef payload = state.new_dict();
	state.set(payload, str(key::ready), bool_value(state.array_size(blockers) == 0));
	state.set(payload, str(key::blockers), array_value(blockers));
	const DictRef draft = state.new_dict();
	state.set(draft, str(key::scenario_record), dict_value(scenario_record));
	state.set(draft, str(key::terrain_layers_record), dict_value(terrain_layers_record));
	state.set(payload, str(key::draft), dict_value(draft));
	return payload;
}

Atom _missing_scenario_template_blocker(State &state, const Value &editor) {
	return gd::format(state, key::scenario_template_s_could_not_be, { str(scenario_id_of(state, session(state, editor))) });
}

ArrayRef _save_copy_validation_blockers(State &state, const Value &editor) {
	const ArrayRef blockers = state.new_array();
	const DictRef validation = _scenario_authoring_validation_payload(state, editor);
	for (const Value &warning : gd::field_items(state, validation, str(key::warnings))) {
		const Atom warning_text = gd::strip_edges(state, string_of(state, warning));
		if (warning_text != key::empty) {
			state.append(blockers, str(warning_text));
		}
	}
	return blockers;
}

DictRef _editor_scenario_objectives(State &state, const Value &editor) {
	// Maps-folder packages are not registered with ContentService, so the
	// objectives come from the runtime record the save draft is built from.
	// Returned read-only.
	const Value current = session(state, editor);
	if (current.kind == Kind::Nil || scenario_id_of(state, current) == key::empty) {
		return state.new_dict();
	}
	const Value runtime_record = runtime_record_of(state, current);
	if (gd::is_dict(runtime_record)) {
		Value objectives;
		if (state.lookup(runtime_record.ref, str(key::objectives), objectives)) {
			return gd::is_dict(objectives) ? objectives.ref : state.new_dict();
		}
	}
	return state.new_dict();
}

DictRef _editor_scenario_template(State &state, const Value &editor) {
	const Value current = session(state, editor);
	if (current.kind == Kind::Nil || scenario_id_of(state, current) == key::empty) {
		return state.new_dict();
	}
	const Value runtime_record = runtime_record_of(state, current);
	if (!gd::is_dict(runtime_record) || gd::is_empty(state, runtime_record.ref)) {
		return state.new_dict();
	}
	const DictRef scenario = gd::as_dict(gd::engine_duplicate(state, runtime_record, true));
	state.set(scenario, str(key::id), str(scenario_id_of(state, current)));
	Value map_size_value;
	if (!state.lookup(scenario, str(key::map_size), map_size_value) || !gd::is_dict(map_size_value) || gd::is_empty(state, map_size_value.ref)) {
		const Vector2i map_size = overworld_rules::derive_map_size(state, session_view(state, current));
		const DictRef size = state.new_dict();
		state.set(size, str(key::width), int_value(map_size.x));
		state.set(size, str(key::height), int_value(map_size.y));
		state.set(scenario, str(key::map_size), dict_value(size));
	}
	Value start_value;
	if (state.lookup(scenario, str(key::start), start_value) && !gd::is_dict(start_value)) {
		const Vector2i hero_position = overworld_rules::hero_position(state, session_view(state, current));
		state.set(scenario, str(key::start), dict_value(position_payload(state, hero_position)));
	}
	return scenario;
}

DictRef _export_scenario_record_from_working_copy(State &state, const Value &editor, DictRef baseline_scenario) {
	return _export_scenario_record_from_session(state, editor, baseline_scenario, session(state, editor));
}

DictRef _export_scenario_record_from_session(State &state, const Value &editor, DictRef baseline_scenario, const Value &session) {
	const DictRef record = gd::as_dict(gd::engine_duplicate(state, dict_value(baseline_scenario), true));
	if (session.kind == Kind::Nil) {
		return record;
	}
	state.set(record, str(key::map), array_value(_normalized_export_map(state, editor, field_or_new_array(state, overworld_of(state, session), key::map))));
	const Vector2i hero_position = overworld_rules::hero_position(state, session_view(state, session));
	state.set(record, str(key::start), dict_value(position_payload(state, hero_position)));
	state.set(record, str(key::towns), array_value(_normalized_export_placements(state, editor, key::town, field_or_new_array(state, overworld_of(state, session), key::towns))));
	state.set(record, str(key::resource_nodes), array_value(_normalized_export_placements(state, editor, key::resource, field_or_new_array(state, overworld_of(state, session), key::resource_nodes))));
	state.set(record, str(key::artifact_nodes), array_value(_normalized_export_placements(state, editor, key::artifact, field_or_new_array(state, overworld_of(state, session), key::artifact_nodes))));
	state.set(record, str(key::encounters), array_value(_normalized_export_placements(state, editor, key::encounter, field_or_new_array(state, overworld_of(state, session), key::encounters))));
	state.set(record, str(key::map_objects), array_value(_normalized_export_map_objects(state, editor, field_or_new_array(state, overworld_of(state, session), key::map_objects))));
	return record;
}

DictRef _export_terrain_layers_record_from_working_copy(State &state, const Value &editor) {
	const DictRef layers = _terrain_layers(state, editor);
	return _export_terrain_layers_record_from_layers(state, editor, layers);
}

DictRef _export_terrain_layers_record_from_layers(State &state, const Value &editor, DictRef layers) {
	const DictRef record = state.new_dict();
	state.set(record, str(key::id), str(scenario_id_of(state, session(state, editor))));
	state.set(record, str(key::terrain_layer_status), str(key::foundation_authored));
	state.set(record, str(key::roads), array_value(_normalized_export_roads(state, editor, field_or_new_array(state, layers, key::roads))));
	return record;
}

ArrayRef _normalized_export_map(State &state, const Value &editor, const Value &map_value) {
	(void)editor;
	const ArrayRef rows = state.new_array();
	if (!gd::is_array(map_value)) {
		return rows;
	}
	const int64_t row_count = state.array_size(map_value.ref);
	for (int64_t y = 0; y < row_count; ++y) {
		const Value row_value = state.at(map_value.ref, y);
		const ArrayRef row = state.new_array();
		if (gd::is_array(row_value)) {
			const int64_t width = state.array_size(row_value.ref);
			for (int64_t x = 0; x < width; ++x) {
				state.append(row, str(string_of(state, state.at(row_value.ref, x))));
			}
		}
		state.append(rows, array_value(row));
	}
	return rows;
}

ArrayRef _normalized_export_roads(State &state, const Value &editor, const Value &roads_value) {
	const ArrayRef roads = state.new_array();
	if (!gd::is_array(roads_value)) {
		return roads;
	}
	for (int64_t index = 0; index < state.array_size(roads_value.ref); ++index) {
		const Value road_value = state.at(roads_value.ref, index);
		if (!gd::is_dict(road_value)) {
			continue;
		}
		const DictRef road = road_value.ref;
		const DictRef record = state.new_dict();
		state.set(record, str(key::id), str(string_field_of(state, road, key::id, key::editor_working_road)));
		state.set(record, str(key::overlay_id), str(string_field_of(state, road, key::overlay_id, key::road_dirt)));
		state.set(record, str(key::role), str(string_field_of(state, road, key::role, key::editor_working_copy)));
		state.set(record, str(key::tiles), array_value(_normalized_export_positions(state, editor, field_or_new_array(state, road, key::tiles))));
		state.append(roads, dict_value(record));
	}
	return roads;
}

ArrayRef _normalized_export_positions(State &state, const Value &editor, const Value &values) {
	(void)editor;
	const ArrayRef positions = state.new_array();
	if (!gd::is_array(values)) {
		return positions;
	}
	for (int64_t index = 0; index < state.array_size(values.ref); ++index) {
		const Value value = state.at(values.ref, index);
		if (gd::is_dict(value)) {
			const DictRef position = state.new_dict();
			state.set(position, str(key::x), int_value(gd::int_field(state, value.ref, key::x, 0)));
			state.set(position, str(key::y), int_value(gd::int_field(state, value.ref, key::y, 0)));
			state.append(positions, dict_value(position));
		}
	}
	return positions;
}

ArrayRef _normalized_export_placements(State &state, const Value &editor, Atom family, const Value &placements_value) {
	const ArrayRef records = state.new_array();
	if (!gd::is_array(placements_value)) {
		return records;
	}
	for (int64_t index = 0; index < state.array_size(placements_value.ref); ++index) {
		const Value placement_value = state.at(placements_value.ref, index);
		if (!gd::is_dict(placement_value)) {
			continue;
		}
		const DictRef placement = placement_value.ref;
		if (!_placement_belongs_in_saved_package(state, editor, placement)) {
			continue;
		}
		const Atom placement_id = string_field_of(state, placement, key::placement_id, key::empty);
		const DictRef source_record = _package_source_object_record(state, editor, placement_id);
		const DictRef record = !gd::is_empty(state, source_record)
				? gd::as_dict(gd::engine_duplicate(state, dict_value(source_record), true))
				: state.new_dict();
		gd::merge(state, record, gd::as_dict(gd::engine_duplicate(state, dict_value(placement), true)), true);
		state.set(record, str(key::placement_id), str(placement_id));
		state.set(record, str(key::x), int_value(gd::int_field(state, placement, key::x, 0)));
		state.set(record, str(key::y), int_value(gd::int_field(state, placement, key::y, 0)));
		if (family == key::town) {
			state.set(record, str(key::town_id), str(string_field_of(state, placement, key::town_id, key::empty)));
			state.set(record, str(key::owner), str(string_field_of(state, placement, key::owner, key::neutral)));
			_copy_optional_dict(state, editor, record, placement, key::recovery);
			_copy_optional_dict(state, editor, record, placement, key::front);
			_copy_optional_dict(state, editor, record, placement, key::occupation);
		} else if (family == key::resource) {
			state.set(record, str(key::site_id), str(string_field_of(state, placement, key::site_id, key::empty)));
			_copy_optional_bool(state, editor, record, placement, key::collected);
			_copy_optional_string(state, editor, record, placement, key::collected_by_faction_id);
			_copy_optional_positive_int(state, editor, record, placement, key::collected_day);
			_copy_optional_string(state, editor, record, placement, key::response_origin);
			_copy_optional_string(state, editor, record, placement, key::response_source_town_id);
			_copy_optional_positive_int(state, editor, record, placement, key::response_last_day);
			_copy_optional_positive_int(state, editor, record, placement, key::response_until_day);
		} else if (family == key::artifact) {
			state.set(record, str(key::artifact_id), str(string_field_of(state, placement, key::artifact_id, key::empty)));
			_copy_optional_bool(state, editor, record, placement, key::collected);
			_copy_optional_string(state, editor, record, placement, key::collected_by_faction_id);
			_copy_optional_positive_int(state, editor, record, placement, key::collected_day);
		} else if (family == key::encounter) {
			state.set(record, str(key::encounter_id), str(string_field_of(state, placement, key::encounter_id, key::empty)));
			_copy_optional_string(state, editor, record, placement, key::difficulty);
			_copy_optional_positive_int(state, editor, record, placement, key::combat_seed);
			_copy_optional_string(state, editor, record, placement, key::object_id);
			_copy_optional_string(state, editor, record, placement, key::object_placement_id);
			_copy_optional_string(state, editor, record, placement, key::encounter_ref);
			_copy_optional_string(state, editor, record, placement, key::legacy_scenario_encounter_ref);
			_copy_optional_dict(state, editor, record, placement, key::guard_link);
			_copy_optional_dict(state, editor, record, placement, key::authored_bundle);
		}
		state.append(records, dict_value(record));
	}
	return records;
}

DictRef _package_source_object_record(State &state, const Value &editor, Atom placement_id) {
	const Value current = session(state, editor);
	if (current.kind == Kind::Nil || placement_id == key::empty) {
		return state.new_dict();
	}
	Value source_records;
	if (!state.lookup(overworld_of(state, current), str(key::package_source_objects_by_id), source_records)) {
		// The fallback {} has no records.
		return state.new_dict();
	}
	if (!gd::is_dict(source_records)) {
		return state.new_dict();
	}
	Value source_record;
	if (state.lookup(source_records.ref, str(placement_id), source_record) && gd::is_dict(source_record)) {
		return source_record.ref;
	}
	return state.new_dict();
}

bool _placement_belongs_in_saved_package(State &state, const Value &editor, DictRef placement) {
	const Value current = session(state, editor);
	if (current.kind == Kind::Nil || string_field_of(state, flags_of(state, current), key::editor_source_kind, key::empty) != key::maps_folder_package) {
		return true;
	}
	if (gd::to_bool(state.get(placement, str(key::editor_authored_placement), bool_value(false)))) {
		return true;
	}
	Value source_ids;
	if (!state.lookup(overworld_of(state, current), str(key::package_source_object_ids), source_ids)) {
		// The fallback [] is empty.
		return true;
	}
	if (!gd::is_array(source_ids) || state.array_size(source_ids.ref) == 0) {
		return true;
	}
	return gd::array_has(state, source_ids.ref, str(string_field_of(state, placement, key::placement_id, key::empty)));
}

ArrayRef _normalized_export_map_objects(State &state, const Value &editor, const Value &objects_value) {
	(void)editor;
	const ArrayRef records = state.new_array();
	if (!gd::is_array(objects_value)) {
		return records;
	}
	for (int64_t index = 0; index < state.array_size(objects_value.ref); ++index) {
		const Value object_value = state.at(objects_value.ref, index);
		if (!gd::is_dict(object_value)) {
			continue;
		}
		const DictRef record = gd::as_dict(gd::engine_duplicate(state, object_value, true));
		state.set(record, str(key::placement_id), str(string_field_of(state, record, key::placement_id, key::empty)));
		state.set(record, str(key::x), int_value(gd::int_field(state, record, key::x, 0)));
		state.set(record, str(key::y), int_value(gd::int_field(state, record, key::y, 0)));
		state.set(record, str(key::level), int_value(gd::int_field(state, record, key::level, 0)));
		state.append(records, dict_value(record));
	}
	return records;
}

void _copy_optional_dict(State &state, const Value &editor, DictRef target, DictRef source, Atom field) {
	(void)editor;
	Value value;
	if (state.lookup(source, str(field), value) && gd::is_dict(value) && !gd::is_empty(state, value.ref)) {
		state.set(target, str(field), gd::engine_duplicate(state, value, true));
	}
}

void _copy_optional_string(State &state, const Value &editor, DictRef target, DictRef source, Atom field) {
	(void)editor;
	const Value raw_value = state.get(source, str(field), str(key::empty));
	if (raw_value.kind == Kind::Nil) {
		return;
	}
	const Atom value = gd::strip_edges(state, string_of(state, raw_value));
	if (value != key::empty) {
		state.set(target, str(field), str(value));
	}
}

void _copy_optional_bool(State &state, const Value &editor, DictRef target, DictRef source, Atom field) {
	(void)editor;
	if (gd::to_bool(state.get(source, str(field), bool_value(false)))) {
		state.set(target, str(field), bool_value(true));
	}
}

void _copy_optional_positive_int(State &state, const Value &editor, DictRef target, DictRef source, Atom field) {
	(void)editor;
	const int64_t value = gd::int_field(state, source, field, 0);
	if (value > 0) {
		state.set(target, str(field), int_value(value));
	}
}

ArrayRef _validate_export_scenario_record(State &state, const Value &editor, DictRef record) {
	const ArrayRef blockers = state.new_array();
	if (gd::strip_edges(state, string_field_of(state, record, key::id, key::empty)) == key::empty) {
		state.append(blockers, str(key::scenario_export_draft_is_missing_an));
	}
	const Vector2i map_size = overworld_rules::derive_map_size(state, session_view(state, session(state, editor)));
	const Value map_data = field_or_new_array(state, record, key::map);
	if (!gd::is_array(map_data) || state.array_size(map_data.ref) != map_size.y) {
		state.append(blockers, str(gd::format(state, key::scenario_export_draft_map_height_does, { int_value(map_size.y) })));
	} else {
		const ArrayRef authored_ids = _authored_terrain_ids(state, editor);
		const int64_t row_count = state.array_size(map_data.ref);
		for (int64_t y = 0; y < row_count; ++y) {
			const Value row = state.at(map_data.ref, y);
			if (!gd::is_array(row) || state.array_size(row.ref) != map_size.x) {
				state.append(blockers, str(gd::format(state, key::scenario_export_draft_map_row_d, { int_value(y), int_value(map_size.x) })));
				continue;
			}
			const int64_t width = state.array_size(row.ref);
			for (int64_t x = 0; x < width; ++x) {
				const Atom terrain_id = string_of(state, state.at(row.ref, x));
				if (!gd::array_has(state, authored_ids, str(terrain_id))) {
					state.append(blockers, str(gd::format(state, key::scenario_export_draft_has_unknown_terrain, { str(terrain_id), int_value(x), int_value(y) })));
				}
			}
		}
	}
	const Value start = state.get(record, str(key::start), dict_value(state.new_dict()));
	if (!gd::is_dict(start) || !_tile_in_bounds(state, editor, Vector2i::of(gd::int_field(state, start.ref, key::x, -1), gd::int_field(state, start.ref, key::y, -1)))) {
		state.append(blockers, str(key::scenario_export_draft_hero_start_is));
	}
	const DictRef placement_ids = state.new_dict();
	const Atom families[] = { key::town, key::resource, key::artifact, key::encounter };
	for (const Atom family : families) {
		const Value placements = field_or_new_array(state, record, _placement_array_key(state, editor, family));
		if (!gd::is_array(placements)) {
			state.append(blockers, str(gd::format(state, key::scenario_export_draft_s_is_not, { str(_placement_array_key(state, editor, family)) })));
			continue;
		}
		for (int64_t index = 0; index < state.array_size(placements.ref); ++index) {
			const Value placement_value = state.at(placements.ref, index);
			if (!gd::is_dict(placement_value)) {
				state.append(blockers, str(gd::format(state, key::scenario_export_draft_s_contains_a, { str(_placement_array_key(state, editor, family)) })));
				continue;
			}
			const DictRef placement = placement_value.ref;
			const Atom placement_id = gd::strip_edges(state, string_field_of(state, placement, key::placement_id, key::empty));
			if (placement_id == key::empty) {
				state.append(blockers, str(gd::format(state, key::scenario_export_draft_s_placement_is, { str(_placement_array_key(state, editor, family)) })));
			} else if (state.has(placement_ids, str(placement_id))) {
				state.append(blockers, str(gd::format(state, key::scenario_export_draft_repeats_placement_id, { str(placement_id) })));
			} else {
				state.set(placement_ids, str(placement_id), bool_value(true));
			}
			const Vector2i tile = Vector2i::of(gd::int_field(state, placement, key::x, -1), gd::int_field(state, placement, key::y, -1));
			if (!_tile_in_bounds(state, editor, tile)) {
				state.append(blockers, str(gd::format(state, key::scenario_export_draft_placement_s_is, { str(placement_id) })));
			}
			const Atom content_id = gd::strip_edges(state, string_field_of(state, placement, _placement_content_key(state, editor, family), key::empty));
			if (content_id == key::empty || gd::is_empty(state, _object_content_lookup(state, editor, family, content_id))) {
				state.append(blockers, str(gd::format(state, key::scenario_export_draft_placement_s_references, {
					str(placement_id),
					str(_object_family_label(state, editor, family)),
					str(content_id),
				})));
			}
		}
	}
	const DictRef map_object_ids = state.new_dict();
	const Value map_objects = field_or_new_array(state, record, key::map_objects);
	if (!gd::is_array(map_objects)) {
		state.append(blockers, str(key::scenario_export_draft_map_objects_is));
	} else {
		for (int64_t index = 0; index < state.array_size(map_objects.ref); ++index) {
			const Value object_value = state.at(map_objects.ref, index);
			if (!gd::is_dict(object_value)) {
				state.append(blockers, str(key::scenario_export_draft_map_objects_contains));
				continue;
			}
			const DictRef object = object_value.ref;
			const Atom placement_id = gd::strip_edges(state, string_field_of(state, object, key::placement_id, key::empty));
			if (placement_id == key::empty) {
				state.append(blockers, str(key::scenario_export_draft_map_object_is));
			} else if (state.has(map_object_ids, str(placement_id))) {
				state.append(blockers, str(gd::format(state, key::scenario_export_draft_repeats_map_object, { str(placement_id) })));
			} else {
				state.set(map_object_ids, str(placement_id), bool_value(true));
			}
			const Vector2i tile = Vector2i::of(gd::int_field(state, object, key::x, -1), gd::int_field(state, object, key::y, -1));
			if (!_tile_in_bounds(state, editor, tile)) {
				state.append(blockers, str(gd::format(state, key::scenario_export_draft_map_object_s, { str(placement_id) })));
			}
			Atom kind = gd::strip_edges(state, string_field_of(state, object, key::kind, key::empty));
			if (kind == key::empty) {
				kind = gd::strip_edges(state, string_field_of(state, object, key::native_record_kind, key::empty));
			}
			if (kind == key::empty) {
				state.append(blockers, str(gd::format(state, key::scenario_export_draft_map_object_s_2, { str(placement_id) })));
			}
		}
	}
	return blockers;
}

ArrayRef _validate_export_terrain_layers_record(State &state, const Value &editor, DictRef record) {
	const ArrayRef blockers = state.new_array();
	const Value current = session(state, editor);
	if (gd::strip_edges(state, string_field_of(state, record, key::id, key::empty)) != scenario_id_of(state, current)) {
		state.append(blockers, str(gd::format(state, key::terrain_layer_export_draft_id_must, { str(scenario_id_of(state, current)) })));
	}
	const Value roads = field_or_new_array(state, record, key::roads);
	if (!gd::is_array(roads)) {
		const ArrayRef only = state.new_array();
		state.append(only, str(key::terrain_layer_export_draft_roads_must));
		return only;
	}
	const Vector2i map_size = overworld_rules::derive_map_size(state, session_view(state, current));
	const DictRef road_ids = state.new_dict();
	for (int64_t index = 0; index < state.array_size(roads.ref); ++index) {
		const Value road_value = state.at(roads.ref, index);
		if (!gd::is_dict(road_value)) {
			state.append(blockers, str(key::terrain_layer_export_draft_contains_a));
			continue;
		}
		const DictRef road = road_value.ref;
		const Atom road_id = gd::strip_edges(state, string_field_of(state, road, key::id, key::empty));
		if (road_id == key::empty) {
			state.append(blockers, str(key::terrain_layer_export_draft_road_is));
		} else if (state.has(road_ids, str(road_id))) {
			state.append(blockers, str(gd::format(state, key::terrain_layer_export_draft_repeats_road, { str(road_id) })));
		} else {
			state.set(road_ids, str(road_id), bool_value(true));
		}
		if (gd::strip_edges(state, string_field_of(state, road, key::overlay_id, key::empty)) == key::empty) {
			state.append(blockers, str(gd::format(state, key::terrain_layer_export_draft_road_s, { str(road_id) })));
		}
		const Value tiles = field_or_new_array(state, road, key::tiles);
		if (!gd::is_array(tiles)) {
			state.append(blockers, str(gd::format(state, key::terrain_layer_export_draft_road_s_2, { str(road_id) })));
			continue;
		}
		for (int64_t tile_index = 0; tile_index < state.array_size(tiles.ref); ++tile_index) {
			const Value tile_value = state.at(tiles.ref, tile_index);
			if (!gd::is_dict(tile_value)) {
				state.append(blockers, str(gd::format(state, key::terrain_layer_export_draft_road_s_3, { str(road_id) })));
				continue;
			}
			const Vector2i tile = Vector2i::of(gd::int_field(state, tile_value.ref, key::x, -1), gd::int_field(state, tile_value.ref, key::y, -1));
			if (tile.x < 0 || tile.y < 0 || tile.x >= map_size.x || tile.y >= map_size.y) {
				state.append(blockers, str(gd::format(state, key::terrain_layer_export_draft_road_s_4, { str(road_id), int_value(tile.x), int_value(tile.y) })));
			}
		}
	}
	return blockers;
}

} // namespace map_editor

} // namespace aurelion::rules::port
