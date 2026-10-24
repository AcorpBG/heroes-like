// MapEditorShell's rules (Phase 7, slice 7.13): the load, scenario, validation focus, play, return,
// restore and menu handoff payloads.

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
using state::ContentTable;
using state::Kind;
using state::State;
using state::Value;
namespace key = state::key;

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
Atom text_or(State &state, DictRef dict, Atom field, const Value &fallback) {
	return string_of(state, state.get(dict, str(field), fallback));
}

// d.get(field, []) where the value is compared: a new Array when missing.
Value field_or_new_array(State &state, DictRef dict, Atom field) {
	Value found;
	if (state.lookup(dict, str(field), found)) {
		return found;
	}
	return array_value(state.new_array());
}

// d.get(field, []).size(): 0 when missing.
int64_t field_size(State &state, DictRef dict, Atom field) {
	Value found;
	if (!state.lookup(dict, str(field), found)) {
		return 0;
	}
	return ai::vsize(state, found);
}

// separator.join(parts) of Texts.
Atom join_atoms(State &state, Atom separator, const std::vector<Atom> &parts) {
	const std::string separator_text = state.text(separator);
	std::string joined;
	for (size_t index = 0; index < parts.size(); ++index) {
		if (index > 0) {
			joined += separator_text;
		}
		joined += state.text(parts[index]);
	}
	return state.intern(joined);
}

// separator.join(array): each item as String(item), as the PackedStringArray
// conversion makes it.
Atom join_array(State &state, Atom separator, ArrayRef array) {
	std::vector<Atom> parts;
	for (int64_t index = 0; index < state.array_size(array); ++index) {
		parts.push_back(string_of(state, state.at(array, index)));
	}
	return join_atoms(state, separator, parts);
}

// a.sort() of an Array of Strings (code point order is UTF-8 byte order).
void sort_texts(State &state, ArrayRef array) {
	gd::sort_custom(state, array, [&state](const Value &a, const Value &b) {
		return gd::text(state, a) < gd::text(state, b);
	});
}

void put(State &state, DictRef dict, Atom field, const Value &value) {
	state.set(dict, str(field), value);
}

// {"x": tile.x, "y": tile.y}.
DictRef tile_payload(State &state, Vector2i tile) {
	const DictRef payload = state.new_dict();
	put(state, payload, key::x, int_value(tile.x));
	put(state, payload, key::y, int_value(tile.y));
	return payload;
}

// The screen's members these payloads read.
Vector2i selected_tile(State &state, const Value &editor) {
	const Value tile = gd::member(state, editor, key::_selected_tile);
	return Vector2i::of(tile.vx(), tile.vy());
}

bool is_dirty(State &state, const Value &editor) {
	return gd::to_bool(gd::member(state, editor, key::_dirty));
}

bool restored_from_play_copy(State &state, const Value &editor) {
	return gd::to_bool(gd::member(state, editor, key::_restored_from_play_copy));
}

} // namespace

namespace map_editor {

DictRef _editor_map_load_handoff_payload(State &state, const Value &editor) {
	const Atom selected_label = _selected_map_package_label(state, editor);
	const DictRef index_status = gd::as_dict(gd::member(state, editor, key::_map_package_index_status));
	// warnings: the status's Array, or [] (only its size is read).
	int64_t warning_count = 0;
	Value warnings_value;
	if (state.lookup(index_status, str(key::warnings), warnings_value) && gd::is_array(warnings_value)) {
		warning_count = state.array_size(warnings_value.ref);
	}
	const int64_t unpaired_count = gd::add(gd::int_field(state, index_status, key::unpaired_map_count, 0), gd::int_field(state, index_status, key::unpaired_scenario_count, 0));
	const Atom selected_id = gd::to_string(gd::member(state, editor, key::_selected_map_package_id));
	const ArrayRef entries = gd::as_array(gd::member(state, editor, key::_map_package_entries));
	const Value current_session = session(state, editor);
	if (current_session.kind == Kind::Nil) {
		Atom state_label = selected_id != key::empty ? key::ready : key::empty_2;
		Atom text = key::load_map_choose_a_generated_map;
		Atom next_step = selected_id != key::empty ? key::press_load_map : key::generate_a_map_package_so_maps;
		if (!gd::bool_field(state, index_status, key::ok, true)) {
			state_label = key::unavailable;
			text = key::load_map_map_packages_are_unavailable;
			next_step = key::enable_native_mappackageservice_before_loading_map;
		} else if (state.array_size(entries) == 0) {
			text = key::load_map_no_map_packages_found;
		}
		if (warning_count != 0 || unpaired_count > 0) {
			text = gd::format(state, key::s_invalid_package_pairs_were_skipped, {str(text)});
		}
		const DictRef payload = state.new_dict();
		put(state, payload, key::text, str(text));
		put(state, payload, key::tooltip, str(gd::format(state, key::load_map_source_generated_map_packages, {
				str(selected_label != key::empty ? selected_label : key::none),
				str(next_step),
		})));
		put(state, payload, key::state, str(state_label));
		put(state, payload, key::dirty, bool_value(false));
		put(state, payload, key::selected_map_package_id, str(selected_id));
		put(state, payload, key::map_package_count, int_value(state.array_size(entries)));
		put(state, payload, key::invalid_pair_count, int_value(gd::add(warning_count, unpaired_count)));
		put(state, payload, key::authored_json_scenarios_used, bool_value(false));
		put(state, payload, key::scope, str(key::map_package_load_working_copy_replace));
		return payload;
	}
	const Atom map_name = _current_scenario_display_name(state, editor);
	const bool dirty = is_dirty(state, editor);
	const Atom state_label = dirty ? key::dirty : key::clean;
	const Atom consequence = key::loading_another_map_package_replaces_this;
	Atom next_step = key::choose_another_map_package_then_load;
	if (dirty) {
		next_step = key::use_play_copy_for_a_smoke;
	}
	const Atom write_context = key::no_authored_file_old_json_scenario;
	const Atom text = gd::format(state, key::load_map_s_s_working_copy, {str(map_name), str(state_label), str(consequence)});
	const Atom tooltip = gd::format(state, key::load_map_current_map_package_s, {
			str(map_name),
			str(state_label),
			str(consequence),
			str(next_step),
			str(write_context),
	});
	const DictRef payload = state.new_dict();
	put(state, payload, key::text, str(text));
	put(state, payload, key::tooltip, str(tooltip));
	put(state, payload, key::state, str(state_label));
	put(state, payload, key::dirty, bool_value(dirty));
	put(state, payload, key::scenario_id, gd::member(state, current_session, key::scenario_id));
	put(state, payload, key::map_name, str(map_name));
	put(state, payload, key::selected_map_package_id, str(selected_id));
	put(state, payload, key::consequence, str(consequence));
	put(state, payload, key::next_step_2, str(next_step));
	put(state, payload, key::write_context, str(write_context));
	put(state, payload, key::map_package_count, int_value(state.array_size(entries)));
	put(state, payload, key::authored_json_scenarios_used, bool_value(false));
	put(state, payload, key::scope, str(key::map_package_load_working_copy_replace));
	return payload;
}

DictRef _editor_scenario_switch_handoff_payload(State &state, const Value &editor) {
	return _editor_map_load_handoff_payload(state, editor);
}

DictRef _editor_selected_validation_focus_payload(State &state, const Value &editor) {
	const Vector2i tile = selected_tile(state, editor);
	if (session(state, editor).kind == Kind::Nil || !_tile_in_bounds(state, editor, tile)) {
		const DictRef payload = state.new_dict();
		put(state, payload, key::text, str(key::empty));
		put(state, payload, key::tooltip, str(key::empty));
		put(state, payload, key::state, str(key::no_selection));
		put(state, payload, key::scope, str(key::selected_tile_validation_focus));
		return payload;
	}
	const ArrayRef details = state.new_array();
	const ArrayRef tile_details = _object_details_at(state, editor, tile, false);
	for (const Value &detail : gd::items(state, array_value(tile_details))) {
		if (gd::is_dict(detail)) {
			state.append(details, detail);
		}
	}
	if (state.array_size(details) == 0) {
		const DictRef payload = state.new_dict();
		put(state, payload, key::text, str(key::empty));
		put(state, payload, key::tooltip, str(key::empty));
		put(state, payload, key::state, str(key::empty_tile));
		put(state, payload, key::scope, str(key::selected_tile_validation_focus));
		put(state, payload, key::tile, dict_value(tile_payload(state, tile)));
		return payload;
	}
	const DictRef counts = _selected_validation_focus_counts(state, editor, details);
	int64_t total_links = gd::int_field(state, counts, key::objective, 0);
	total_links = gd::add(total_links, gd::int_field(state, counts, key::guard, 0));
	total_links = gd::add(total_links, gd::int_field(state, counts, key::route, 0));
	total_links = gd::add(total_links, gd::int_field(state, counts, key::reward, 0));
	total_links = gd::add(total_links, gd::int_field(state, counts, key::enemy_focus, 0));
	if (total_links <= 0 && gd::int_field(state, counts, key::warning, 0) <= 0) {
		const DictRef payload = state.new_dict();
		put(state, payload, key::text, str(key::empty));
		put(state, payload, key::tooltip, str(key::empty));
		put(state, payload, key::state, str(key::unlinked_selection));
		put(state, payload, key::scope, str(key::selected_tile_validation_focus));
		put(state, payload, key::tile, dict_value(tile_payload(state, tile)));
		put(state, payload, key::object_count, int_value(state.array_size(details)));
		return payload;
	}
	const ArrayRef object_labels = state.new_array();
	const ArrayRef warnings = state.new_array();
	for (int64_t index = 0; index < state.array_size(details); ++index) {
		const Value detail = state.at(details, index);
		if (!gd::is_dict(detail)) {
			continue;
		}
		const Atom label = _object_recap_label(state, editor, detail.ref);
		if (label != key::empty && !gd::array_has(state, object_labels, str(label))) {
			state.append(object_labels, str(label));
		}
		Value dependencies;
		if (!state.lookup(detail.ref, str(key::authoring_dependencies), dependencies) || !gd::is_dict(dependencies)) {
			// A missing field is the {} fallback, which has no warnings.
			continue;
		}
		// for warning in dependencies.get("warnings", []): copied first, since
		// String(warning) may ask the engine.
		std::vector<Value> dependency_warnings;
		for (const Value &warning : gd::field_items(state, dependencies.ref, str(key::warnings))) {
			dependency_warnings.push_back(warning);
		}
		for (const Value &warning : dependency_warnings) {
			const Atom warning_text = gd::strip_edges(state, string_of(state, warning));
			if (warning_text != key::empty && !gd::array_has(state, warnings, str(warning_text))) {
				state.append(warnings, str(warning_text));
			}
		}
	}
	const Atom summary = _selected_validation_focus_summary(state, editor, counts);
	const Atom selected_label = _compact_join_limited(state, editor, object_labels, 2);
	const Atom first_warning = state.array_size(warnings) != 0 ? gd::strip_edges(state, string_of(state, state.at(warnings, 0))) : key::empty;
	Atom next_step = key::recheck_linked_objectives_guards_rewards_routes_2;
	if (first_warning != key::empty) {
		next_step = key::resolve_or_accept_the_selected_warning;
	}
	const Atom text = gd::format(state, key::validation_focus_d_d_s_s, {
			int_value(tile.x),
			int_value(tile.y),
			str(selected_label),
			str(summary),
			str(next_step),
	});
	Atom tooltip = gd::format(state, key::selected_validation_focus_tile_d_d, {
			int_value(tile.x),
			int_value(tile.y),
			str(selected_label),
			str(summary),
			str(next_step),
	});
	if (first_warning != key::empty) {
		tooltip = gd::format(state, key::s_first_warning_s, {str(tooltip), str(first_warning)});
	}
	const DictRef payload = state.new_dict();
	put(state, payload, key::text, str(text));
	put(state, payload, key::tooltip, str(tooltip));
	put(state, payload, key::state, str(key::review));
	put(state, payload, key::ready, bool_value(first_warning == key::empty));
	put(state, payload, key::scope, str(key::selected_tile_validation_focus));
	put(state, payload, key::tile, dict_value(tile_payload(state, tile)));
	put(state, payload, key::object_labels, array_value(object_labels));
	put(state, payload, key::summary, str(summary));
	put(state, payload, key::objective_link_count, int_value(gd::int_field(state, counts, key::objective, 0)));
	put(state, payload, key::guard_link_count, int_value(gd::int_field(state, counts, key::guard, 0)));
	put(state, payload, key::route_link_count, int_value(gd::int_field(state, counts, key::route, 0)));
	put(state, payload, key::reward_link_count, int_value(gd::int_field(state, counts, key::reward, 0)));
	put(state, payload, key::enemy_focus_link_count, int_value(gd::int_field(state, counts, key::enemy_focus, 0)));
	put(state, payload, key::warning_count, int_value(gd::int_field(state, counts, key::warning, 0)));
	put(state, payload, key::first_warning, str(first_warning));
	put(state, payload, key::next_step_2, str(next_step));
	return payload;
}

DictRef _selected_validation_focus_counts(State &state, const Value &editor, ArrayRef details) {
	(void)editor;
	// The counts' keys and the dependency lists they add up, in GDScript's order.
	static constexpr Atom kCountKeys[] = {key::objective, key::guard, key::route, key::reward, key::enemy_focus, key::warning};
	static constexpr Atom kListKeys[] = {key::objective_links, key::guard_links, key::route_links, key::reward_links, key::enemy_focus_links, key::warnings};
	const DictRef counts = state.new_dict();
	for (const Atom count_key : kCountKeys) {
		put(state, counts, count_key, int_value(0));
	}
	for (const Value &detail : gd::items(state, array_value(details))) {
		if (!gd::is_dict(detail)) {
			continue;
		}
		Value dependencies;
		const bool has_dependencies = state.lookup(detail.ref, str(key::authoring_dependencies), dependencies);
		if (has_dependencies && !gd::is_dict(dependencies)) {
			continue;
		}
		// A missing field is the {} fallback: every list is [] there.
		for (size_t index = 0; index < 6; ++index) {
			const int64_t size = has_dependencies ? field_size(state, dependencies.ref, kListKeys[index]) : 0;
			put(state, counts, kCountKeys[index], int_value(gd::add(gd::int_field(state, counts, kCountKeys[index], 0), size)));
		}
	}
	return counts;
}

Atom _selected_validation_focus_summary(State &state, const Value &editor, DictRef counts) {
	(void)editor;
	// The local labels Dictionary: each key has its label.
	static constexpr Atom kKeys[] = {key::objective, key::guard, key::route, key::reward, key::enemy_focus, key::warning};
	static constexpr Atom kLabels[] = {key::objectives, key::guards, key::routes, key::rewards, key::enemy_focus_2, key::warnings};
	std::vector<Atom> parts;
	for (size_t index = 0; index < 6; ++index) {
		const int64_t count = gd::int_field(state, counts, kKeys[index], 0);
		if (count <= 0) {
			continue;
		}
		parts.push_back(gd::format(state, key::s_d_6, {str(kLabels[index]), int_value(count)}));
	}
	return !parts.empty() ? join_atoms(state, key::space_bar_space, parts) : key::no_selected_authoring_links;
}

DictRef _editor_play_handoff_payload(State &state, const Value &editor) {
	const Value current_session = session(state, editor);
	if (current_session.kind == Kind::Nil) {
		const DictRef payload = state.new_dict();
		put(state, payload, key::button_label, str(key::play_copy));
		put(state, payload, key::text, str(key::empty));
		put(state, payload, key::tooltip, str(key::load_a_map_package_working_copy));
		put(state, payload, key::state_context, str(key::no_working_copy));
		return payload;
	}
	const Value scenario_id = gd::member(state, current_session, key::scenario_id);
	const DictRef scenario = gd::content_row(state, ContentTable::Scenario, gd::to_string(scenario_id));
	const Atom scenario_name = text_or(state, scenario, key::name, scenario_id);
	const DictRef view = session_view(state, current_session);
	const Vector2i map_size = overworld_rules::derive_map_size(state, view);
	const Vector2i hero_position = overworld_rules::hero_position(state, view);
	const bool dirty = is_dirty(state, editor);
	const Atom state_context = dirty ? key::edited_in_memory_working_copy : key::authored_working_copy;
	const Atom return_context = key::return_restores_the_editor_launch_snapshot;
	const Atom write_context = key::no_authored_file_or_campaign_progress;
	const Atom text = gd::format(state, key::play_handoff_s_launches_s_s, {
			str(scenario_name),
			str(state_context),
			str(return_context),
			str(write_context),
	});
	const DictRef payload = state.new_dict();
	put(state, payload, key::button_label, str(key::play_copy));
	put(state, payload, key::text, str(text));
	put(state, payload, key::tooltip, str(gd::format(state, key::s_map_dx_d_objects_d, {
			str(text),
			int_value(map_size.x),
			int_value(map_size.y),
			int_value(_placement_count(state, editor)),
			int_value(hero_position.x),
			int_value(hero_position.y),
	})));
	put(state, payload, key::scenario_id, scenario_id);
	put(state, payload, key::scenario_name, str(scenario_name));
	put(state, payload, key::state_context, str(state_context));
	put(state, payload, key::return_context, str(return_context));
	put(state, payload, key::write_context, str(write_context));
	put(state, payload, key::return_model, str(key::launch_snapshot));
	put(state, payload, key::dirty, bool_value(dirty));
	put(state, payload, key::map_size, dict_value(tile_payload(state, map_size)));
	put(state, payload, key::object_count, int_value(_placement_count(state, editor)));
	put(state, payload, key::hero_position, dict_value(tile_payload(state, hero_position)));
	return payload;
}

DictRef _editor_play_return_context_payload(State &state, const Value &editor) {
	const Value current_session = session(state, editor);
	if (current_session.kind == Kind::Nil || !restored_from_play_copy(state, editor)) {
		const DictRef payload = state.new_dict();
		put(state, payload, key::text, str(key::empty));
		put(state, payload, key::tooltip, str(key::empty));
		put(state, payload, key::restored, bool_value(false));
		return payload;
	}
	const Value scenario_id = gd::member(state, current_session, key::scenario_id);
	const DictRef scenario = gd::content_row(state, ContentTable::Scenario, gd::to_string(scenario_id));
	const Atom scenario_name = text_or(state, scenario, key::name, scenario_id);
	const DictRef view = session_view(state, current_session);
	const Vector2i map_size = overworld_rules::derive_map_size(state, view);
	const Vector2i hero_position = overworld_rules::hero_position(state, view);
	const DictRef flags = gd::as_dict(gd::member(state, current_session, key::flags));
	const Atom return_model = text_or(state, flags, key::editor_return_model, str(key::launch_snapshot));
	const bool dirty = is_dirty(state, editor);
	const Atom dirty_text = dirty ? key::unsaved_edits_still_in_memory : key::authored_working_copy_unchanged;
	const Vector2i tile = selected_tile(state, editor);
	const Atom text = gd::format(state, key::play_return_launch_snapshot_restored_live, {
			int_value(hero_position.x),
			int_value(hero_position.y),
			int_value(tile.x),
			int_value(tile.y),
			int_value(_placement_count(state, editor)),
	});
	const DictRef payload = state.new_dict();
	put(state, payload, key::text, str(text));
	put(state, payload, key::tooltip, str(gd::format(state, key::s_s_map_dx_d_return, {
			str(text),
			str(scenario_name),
			int_value(map_size.x),
			int_value(map_size.y),
			str(return_model),
			str(dirty_text),
	})));
	put(state, payload, key::restored, bool_value(true));
	put(state, payload, key::scenario_id, scenario_id);
	put(state, payload, key::scenario_name, str(scenario_name));
	put(state, payload, key::return_model, str(return_model));
	put(state, payload, key::hero_position, dict_value(tile_payload(state, hero_position)));
	put(state, payload, key::selected_tile, dict_value(tile_payload(state, tile)));
	put(state, payload, key::object_count, int_value(_placement_count(state, editor)));
	put(state, payload, key::dirty, bool_value(dirty));
	return payload;
}

DictRef _editor_restore_tile_cue_payload(State &state, const Value &editor) {
	const Value current_session = session(state, editor);
	if (current_session.kind == Kind::Nil) {
		const DictRef payload = state.new_dict();
		put(state, payload, key::button_label, str(key::restore_tile));
		put(state, payload, key::text, str(key::empty));
		put(state, payload, key::tooltip, str(key::load_a_map_package_working_copy_2));
		put(state, payload, key::state, str(key::no_working_copy));
		put(state, payload, key::changed, bool_value(false));
		return payload;
	}
	const Vector2i tile = selected_tile(state, editor);
	if (!_tile_in_bounds(state, editor, tile)) {
		const Atom outside_text = key::tile_reset_selected_tile_is_outside;
		const DictRef payload = state.new_dict();
		put(state, payload, key::button_label, str(key::restore_tile));
		put(state, payload, key::text, str(outside_text));
		put(state, payload, key::tooltip, str(outside_text));
		put(state, payload, key::state, str(key::blocked));
		put(state, payload, key::changed, bool_value(false));
		put(state, payload, key::scope, str(key::selected_tile_working_copy_only));
		return payload;
	}
	const Value baseline = _authored_baseline_session(state, editor);
	if (baseline.kind == Kind::Nil || gd::equal(state, gd::member(state, baseline, key::scenario_id), str(key::empty))) {
		const Atom missing_text = gd::format(state, key::tile_reset_loaded_map_baseline_is, {gd::member(state, current_session, key::scenario_id)});
		const DictRef payload = state.new_dict();
		put(state, payload, key::button_label, str(key::restore_tile));
		put(state, payload, key::text, str(missing_text));
		put(state, payload, key::tooltip, str(missing_text));
		put(state, payload, key::state, str(key::blocked));
		put(state, payload, key::changed, bool_value(false));
		put(state, payload, key::scope, str(key::selected_tile_working_copy_only));
		return payload;
	}
	const DictRef current_signature = _tile_authoring_signature_for_session(state, editor, current_session, tile);
	const DictRef authored_signature = _tile_authoring_signature_for_session(state, editor, baseline, tile);
	const ArrayRef delta_labels = _tile_authoring_delta_labels(state, editor, current_signature, authored_signature);
	const bool changed = state.array_size(delta_labels) != 0;
	const Atom tile_label = state.intern(gd::format_pair(tile.x, tile.y));
	Atom text = key::empty;
	Atom button_label = key::restore_clean;
	Atom next_step = key::select_another_tile_or_keep_editing;
	if (changed) {
		button_label = key::restore_changed;
		next_step = key::press_restore_tile_to_reset_this;
		text = gd::format(state, key::tile_reset_s_differs_in_s, {
				str(tile_label),
				str(join_array(state, key::comma_space, delta_labels)),
		});
	} else {
		text = gd::format(state, key::tile_reset_s_already_matches_loaded, {str(tile_label)});
	}
	const Atom tooltip = gd::format(state, key::restore_tile_selected_s_current_s, {
			str(tile_label),
			str(_tile_authoring_signature_summary(state, editor, current_signature)),
			str(_tile_authoring_signature_summary(state, editor, authored_signature)),
			str(next_step),
	});
	const DictRef payload = state.new_dict();
	put(state, payload, key::button_label, str(button_label));
	put(state, payload, key::text, str(text));
	put(state, payload, key::tooltip, str(tooltip));
	put(state, payload, key::state, str(changed ? key::changed : key::clean));
	put(state, payload, key::changed, bool_value(changed));
	put(state, payload, key::delta_labels, array_value(delta_labels));
	put(state, payload, key::next_step_2, str(next_step));
	put(state, payload, key::scope, str(key::selected_tile_working_copy_only));
	put(state, payload, key::tile, dict_value(tile_payload(state, tile)));
	put(state, payload, key::current, dict_value(current_signature));
	put(state, payload, key::authored, dict_value(authored_signature));
	return payload;
}

DictRef _tile_authoring_signature_for_session(State &state, const Value &editor, const Value &session, Vector2i tile) {
	if (session.kind == Kind::Nil) {
		return state.new_dict();
	}
	const ArrayRef road_layer_ids = state.new_array();
	const ArrayRef roads = _road_layers_at_in_overworld(state, editor, gd::as_dict(gd::member(state, session, key::overworld)), tile);
	for (int64_t index = 0; index < state.array_size(roads); ++index) {
		const Value road = state.at(roads, index);
		if (gd::is_dict(road)) {
			state.append(road_layer_ids, str(text_or(state, road.ref, key::id, str(key::editor_working_road))));
		}
	}
	sort_texts(state, road_layer_ids);
	const ArrayRef object_signatures = state.new_array();
	static constexpr Atom kFamilies[] = {key::town, key::resource, key::artifact, key::encounter};
	for (const Atom family : kFamilies) {
		const Atom content_key = _placement_content_key(state, editor, family);
		const ArrayRef placements = _placements_for_family_at_in_session(state, editor, session, family, tile);
		for (int64_t index = 0; index < state.array_size(placements); ++index) {
			const Value placement = state.at(placements, index);
			if (!gd::is_dict(placement)) {
				continue;
			}
			std::vector<Atom> parts;
			parts.push_back(family);
			parts.push_back(text_or(state, placement.ref, key::placement_id, str(key::empty)));
			parts.push_back(text_or(state, placement.ref, content_key, str(key::empty)));
			if (family == key::town) {
				parts.push_back(text_or(state, placement.ref, key::owner, str(key::neutral)));
			} else if (family == key::resource || family == key::artifact) {
				const bool collected = gd::bool_field(state, placement.ref, key::collected, false);
				parts.push_back(gd::format(state, key::collected_s_2, {str(collected ? key::yes : key::no)}));
			} else if (family == key::encounter) {
				parts.push_back(text_or(state, placement.ref, key::difficulty, str(key::medium)));
			}
			state.append(object_signatures, str(join_atoms(state, key::colon, parts)));
		}
	}
	sort_texts(state, object_signatures);
	const DictRef signature = state.new_dict();
	put(state, signature, key::terrain_id, str(_terrain_at_in_overworld(state, editor, gd::as_dict(gd::member(state, session, key::overworld)), tile)));
	put(state, signature, key::road_layer_ids, array_value(road_layer_ids));
	put(state, signature, key::road_count, int_value(state.array_size(road_layer_ids)));
	put(state, signature, key::hero_start, bool_value(overworld_rules::hero_position(state, session_view(state, session)) == tile));
	put(state, signature, key::object_signatures, array_value(object_signatures));
	put(state, signature, key::object_count, int_value(state.array_size(object_signatures)));
	return signature;
}

ArrayRef _tile_authoring_delta_labels(State &state, const Value &editor, DictRef current_signature, DictRef authored_signature) {
	(void)editor;
	const ArrayRef labels = state.new_array();
	if (text_or(state, current_signature, key::terrain_id, str(key::empty)) != text_or(state, authored_signature, key::terrain_id, str(key::empty))) {
		state.append(labels, str(key::terrain));
	}
	if (!gd::equal(state, field_or_new_array(state, current_signature, key::road_layer_ids), field_or_new_array(state, authored_signature, key::road_layer_ids))) {
		state.append(labels, str(key::roads));
	}
	if (gd::bool_field(state, current_signature, key::hero_start, false) != gd::bool_field(state, authored_signature, key::hero_start, false)) {
		state.append(labels, str(key::hero_start_2));
	}
	if (!gd::equal(state, field_or_new_array(state, current_signature, key::object_signatures), field_or_new_array(state, authored_signature, key::object_signatures))) {
		state.append(labels, str(key::objects));
	}
	return labels;
}

Atom _tile_authoring_signature_summary(State &state, const Value &editor, DictRef signature) {
	if (gd::is_empty(state, signature)) {
		return key::unavailable;
	}
	return gd::format(state, key::terrain_s_roads_d_hero_s, {
			str(_terrain_label_for_id(state, editor, text_or(state, signature, key::terrain_id, str(key::empty)))),
			int_value(gd::int_field(state, signature, key::road_count, 0)),
			str(gd::bool_field(state, signature, key::hero_start, false) ? key::yes : key::no),
			int_value(gd::int_field(state, signature, key::object_count, 0)),
	});
}

DictRef _editor_menu_return_payload(State &state, const Value &editor) {
	const Value current_session = session(state, editor);
	if (current_session.kind == Kind::Nil) {
		const Atom empty_text = key::menu_return_main_menu_no_editor;
		const DictRef payload = state.new_dict();
		put(state, payload, key::button_label, str(key::Menu));
		put(state, payload, key::text, str(empty_text));
		put(state, payload, key::tooltip, str(empty_text));
		put(state, payload, key::state, str(key::empty_2));
		put(state, payload, key::dirty, bool_value(false));
		put(state, payload, key::restored_from_play_copy, bool_value(false));
		put(state, payload, key::write_context, str(key::no_editor_working_copy_is_loaded));
		return payload;
	}
	const Value scenario_id = gd::member(state, current_session, key::scenario_id);
	const DictRef scenario = gd::content_row(state, ContentTable::Scenario, gd::to_string(scenario_id));
	const Atom scenario_name = text_or(state, scenario, key::name, scenario_id);
	const bool dirty = is_dirty(state, editor);
	const bool restored = restored_from_play_copy(state, editor);
	const Atom dirty_context = dirty ? key::unsaved_editor_edits_are_discarded_when : key::no_editor_edits_need_preserving;
	const Atom restored_context = restored ? key::play_copy_launch_snapshot_restored : key::active_editor_working_copy;
	const Atom write_context = key::no_authored_file_or_campaign_progress;
	const Atom play_hint = key::use_play_copy_before_leaving_when;
	const Atom text = gd::format(state, key::menu_return_main_menu_s_s, {str(dirty_context), str(write_context)});
	const DictRef payload = state.new_dict();
	put(state, payload, key::button_label, str(dirty ? key::menu_unsaved : key::Menu));
	put(state, payload, key::text, str(text));
	put(state, payload, key::tooltip, str(gd::format(state, key::s_s_s_scenario_s_s, {
			str(text),
			str(restored_context),
			str(play_hint),
			str(scenario_name),
			str(write_context),
	})));
	put(state, payload, key::state, str(dirty ? key::dirty : key::clean));
	put(state, payload, key::dirty, bool_value(dirty));
	put(state, payload, key::restored_from_play_copy, bool_value(restored));
	put(state, payload, key::scenario_id, scenario_id);
	put(state, payload, key::scenario_name, str(scenario_name));
	put(state, payload, key::write_context, str(write_context));
	put(state, payload, key::dirty_context, str(dirty_context));
	put(state, payload, key::play_hint, str(play_hint));
	return payload;
}

} // namespace map_editor

} // namespace aurelion::rules::port
