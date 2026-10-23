// ScenarioSelectRules.gd's maps folder: its index of generated .amap/.ascenario
// pairs, their entries, and a session loaded or started from one.

#include "aurelion_rules/port/scenario_select_rules_setup.hpp"

#include "aurelion_rules/port/native_random_map_package_session_bridge.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"
#include "aurelion_rules/port/session_state_store.hpp"
#include "aurelion_rules/port/session_view.hpp"

#include <algorithm>
#include <string>
#include <utility>
#include <vector>

namespace aurelion::rules::port {

namespace {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using state::Kind;
using state::State;
using state::Value;
namespace key = state::key;

void put(State &state, DictRef dict, Atom name, const Value &value) {
	state.set(dict, gd::str(name), value);
}

// String(d.get(name, fallback)).
Atom string_of(State &state, DictRef dict, Atom name, const Value &fallback) {
	return gd::stringify(state, state.get(dict, gd::str(name), fallback));
}

// String(d.get(name, "")).
Atom text_of(State &state, DictRef dict, Atom name) {
	return string_of(state, dict, name, gd::str(key::empty));
}

// var x: Dictionary = d.get(name, {}) if d.get(name, {}) is Dictionary else {}
DictRef dict_or_new(State &state, DictRef dict, Atom name) {
	Value found;
	if (state.lookup(dict, gd::str(name), found) && found.kind == Kind::Dict) {
		return found.ref;
	}
	return state.new_dict();
}

// var x: Dictionary = d.get(name, {})
DictRef typed_dict_field(State &state, DictRef dict, Atom name) {
	Value found;
	if (!state.lookup(dict, gd::str(name), found)) {
		return state.new_dict();
	}
	return gd::as_dict(found);
}

// d.get(name, {}) as a value.
Value field_or_new_dict(State &state, DictRef dict, Atom name) {
	Value found;
	if (state.lookup(dict, gd::str(name), found)) {
		return found;
	}
	return gd::dict_value(state.new_dict());
}

// separator.join(parts) of Strings.
Atom join(State &state, Atom separator, const std::vector<Atom> &parts) {
	std::string joined;
	for (size_t index = 0; index < parts.size(); ++index) {
		if (index != 0) {
			joined += state.text(separator);
		}
		joined += state.text(parts[index]);
	}
	return state.intern(joined);
}

// The last '/' or '\\' (String::get_file and get_basename), or npos.
size_t last_separator(const std::string &text) {
	const size_t slash = text.rfind('/');
	const size_t backslash = text.rfind('\\');
	if (slash == std::string::npos) {
		return backslash;
	}
	if (backslash == std::string::npos) {
		return slash;
	}
	return std::max(slash, backslash);
}

// s.get_file().
Atom get_file(State &state, Atom path) {
	const std::string text = state.text(path);
	const size_t separator = last_separator(text);
	if (separator == std::string::npos) {
		return path;
	}
	return state.intern(text.substr(separator + 1));
}

// s.get_basename().
Atom get_basename(State &state, Atom path) {
	const std::string text = state.text(path);
	const size_t dot = text.rfind('.');
	const size_t separator = last_separator(text);
	if (dot == std::string::npos || (separator != std::string::npos && dot < separator)) {
		return path;
	}
	return state.intern(text.substr(0, dot));
}

// SessionStateStoreScript.new_session_data().
Value empty_session(State &state) {
	return port::session_state_store::new_session_data(state, key::empty, key::empty, key::empty, 1, state.new_dict(), key::normal,
			key::campaign);
}

ArrayRef string_array(State &state, std::initializer_list<Atom> texts) {
	const ArrayRef array = state.new_array();
	for (const Atom text : texts) {
		state.append(array, gd::str(text));
	}
	return array;
}

// {"ok": false, "package_stem": ..., "map_path": ..., "scenario_path": ..., "error_code": ...}
DictRef record_failure(State &state, Atom package_stem, Atom map_path, Atom scenario_path, Atom error_code) {
	const DictRef failure = state.new_dict();
	put(state, failure, key::ok, gd::bool_value(false));
	put(state, failure, key::package_stem, gd::str(package_stem));
	put(state, failure, key::map_path, gd::str(map_path));
	put(state, failure, key::scenario_path, gd::str(scenario_path));
	put(state, failure, key::error_code, gd::str(error_code));
	return failure;
}

DictRef launch_failure(State &state, Atom code, Atom path, Atom message) {
	const DictRef failure = state.new_dict();
	put(state, failure, key::code, gd::str(code));
	put(state, failure, key::path, gd::str(path));
	put(state, failure, key::message, gd::str(message));
	return failure;
}

} // namespace

namespace scenario_select_rules {

bool maps_folder_package_id_is_valid(State &state, Atom package_id) {
	return gd::begins_with(state, package_id, key::maps_package);
}

Atom maps_folder_package_id_for_stem(State &state, Atom package_stem) {
	return gd::format(state, key::s_s_5, { gd::str(key::maps_package), gd::str(_safe_package_stem(state, package_stem)) });
}

Atom maps_folder_package_stem_from_id(State &state, Atom package_id) {
	if (!maps_folder_package_id_is_valid(state, package_id)) {
		return key::empty;
	}
	// The prefix is ASCII: its length in characters is its length in bytes.
	return state.intern(state.text(package_id).substr(state.text(key::maps_package).size()));
}

Atom safe_maps_folder_package_stem(State &state, Atom value) {
	return _safe_package_stem(state, value);
}

ArrayRef build_maps_folder_package_browser_entries(State &state, DictRef options) {
	const DictRef index = maps_folder_package_index(state, options);
	Value entries;
	if (!state.lookup(index, gd::str(key::entries), entries)) {
		return state.new_array();
	}
	return gd::as_array(entries);
}

DictRef maps_folder_package_index(State &state, DictRef options) {
	const Value service = _native_map_package_service(state);
	const Atom package_dir = string_of(state, options, key::package_dir, gd::str(_generated_map_package_dir(state)));
	const bool include_non_launchable = gd::bool_field(state, options, key::include_non_launchable_generated_packages, false);
	const DictRef result = state.new_dict();
	put(state, result, key::ok, gd::bool_value(true));
	put(state, result, key::schema_id, gd::str(key::aurelion_maps_folder_package_index_v1));
	put(state, result, key::package_dir, gd::str(package_dir));
	put(state, result, key::directory_policy, gd::dict_value(generated_map_package_directory_policy(state)));
	put(state, result, key::include_non_launchable_generated_packages, gd::bool_value(include_non_launchable));
	const ArrayRef entries = state.new_array();
	put(state, result, key::entries, gd::array_value(entries));
	const ArrayRef warnings = state.new_array();
	put(state, result, key::warnings, gd::array_value(warnings));
	put(state, result, key::message, gd::str(key::empty));
	put(state, result, key::authored_json_scenarios_used, gd::bool_value(false));
	if (service.kind == Kind::Nil) {
		put(state, result, key::ok, gd::bool_value(false));
		put(state, result, key::message, gd::str(key::native_mappackageservice_is_required_to_read));
		return result;
	}
	std::vector<std::pair<Atom, bool>> dir_listing;
	if (!gd::dir_entries(state, package_dir, dir_listing)) {
		put(state, result, key::message, gd::str(key::no_generated_maps_folder_exists_yet));
		return result;
	}
	const DictRef stems_by_kind = _maps_folder_package_stems(state, dir_listing);
	const DictRef map_stems = typed_dict_field(state, stems_by_kind, key::map_stems);
	const DictRef scenario_stems = typed_dict_field(state, stems_by_kind, key::scenario_stems);
	const ArrayRef stems = state.new_array();
	for (const Value &stem : gd::items(state, gd::dict_value(map_stems))) {
		if (state.has(scenario_stems, stem)) {
			state.append(stems, gd::str(gd::stringify(state, stem)));
		}
	}
	// stems.sort() of Strings: code point order, which is UTF-8 byte order.
	gd::sort_custom(state, stems, [&state](const Value &a, const Value &b) {
		return gd::text(state, a) < gd::text(state, b);
	});
	for (const Value &stem : gd::items(state, gd::array_value(stems))) {
		const DictRef entry = _maps_folder_package_record(state, service, package_dir, gd::to_string(stem), options);
		if (gd::bool_field(state, entry, key::ok, false)) {
			state.append(entries, gd::dict_value(entry));
		} else {
			state.append(warnings, gd::dict_value(entry));
		}
	}
	const int64_t stem_count = state.array_size(stems);
	put(state, result, key::unpaired_map_count, gd::int_value(std::max<int64_t>(0, state.dict_size(map_stems) - stem_count)));
	put(state, result, key::unpaired_scenario_count, gd::int_value(std::max<int64_t>(0, state.dict_size(scenario_stems) - stem_count)));
	if (state.array_size(entries) == 0) {
		put(state, result, key::message, gd::str(key::no_generated_amap_ascenario_package_pairs));
	}
	return result;
}

DictRef maps_folder_package_entry(State &state, Atom package_id, DictRef options) {
	const DictRef index = maps_folder_package_index(state, options);
	for (const Value &entry : gd::field_items(state, index, gd::str(key::entries))) {
		if (gd::is_dict(entry) && text_of(state, entry.ref, key::package_id) == package_id) {
			return entry.ref;
		}
	}
	return state.new_dict();
}

DictRef build_maps_folder_package_skirmish_setup(State &state, Atom package_id, Atom difficulty_id, DictRef options) {
	const DictRef entry = maps_folder_package_entry(state, package_id, options);
	return build_maps_folder_package_skirmish_setup_from_entry(state, entry, difficulty_id);
}

DictRef build_maps_folder_package_skirmish_setup_from_entry(State &state, DictRef entry, Atom difficulty_id) {
	if (!_maps_folder_package_entry_is_current(state, entry)) {
		return state.new_dict();
	}
	const Atom package_id = text_of(state, entry, key::package_id);
	const Atom normalized_difficulty = normalize_difficulty(state, gd::str(difficulty_id));
	const Atom difficulty_label_text = difficulty_label(state, normalized_difficulty);
	const Atom briefing_check = _maps_folder_package_briefing_check(state, entry, normalized_difficulty);
	std::vector<Atom> setup_lines;
	setup_lines.push_back(key::launch_handoff_generated_package_for_selected);
	setup_lines.push_back(briefing_check);
	setup_lines.push_back(text_of(state, entry, key::summary));
	const Atom map_path_text = text_of(state, entry, key::map_path);
	const Atom scenario_path_text = text_of(state, entry, key::scenario_path);
	setup_lines.push_back(gd::format(state, key::packages_s_s, { gd::str(map_path_text), gd::str(scenario_path_text) }));
	const Atom mode_label = launch_mode_label(state, key::skirmish);
	setup_lines.push_back(gd::format(state, key::mode_s_difficulty_s, { gd::str(mode_label), gd::str(difficulty_label_text) }));
	setup_lines.push_back(key::boundary_native_packages_loaded_from_disk);

	const DictRef setup = state.new_dict();
	put(state, setup, key::ok, gd::bool_value(true));
	put(state, setup, key::setup_kind, gd::str(key::maps_folder_generated_package_skirmish));
	put(state, setup, key::startup_source, gd::str(key::maps_folder_package));
	put(state, setup, key::launch_mode, gd::str(key::skirmish));
	put(state, setup, key::difficulty, gd::str(normalized_difficulty));
	put(state, setup, key::difficulty_label, gd::str(difficulty_label_text));
	put(state, setup, key::difficulty_summary, gd::str(difficulty_summary(state, normalized_difficulty)));
	put(state, setup, key::recommended_difficulty, gd::str(default_difficulty_id(state)));
	put(state, setup, key::recommended_difficulty_label, gd::str(difficulty_label(state, default_difficulty_id(state))));
	put(state, setup, key::scenario_id, gd::str(package_id));
	put(state, setup, key::scenario_name, gd::str(string_of(state, entry, key::display_name, gd::str(package_id))));
	put(state, setup, key::summary, gd::str(text_of(state, entry, key::summary)));
	put(state, setup, key::setup_summary, gd::str(join(state, key::newline, setup_lines)));
	const Atom preview_name = string_of(state, entry, key::display_name, gd::str(package_id));
	put(state, setup, key::launch_preview, gd::str(gd::format(state, key::launch_generated_map_package_s, { gd::str(preview_name) })));
	put(state, setup, key::launch_handoff, gd::str(setup_lines[0]));
	put(state, setup, key::briefing_check, gd::str(briefing_check));
	put(state, setup, key::front_context, gd::str(text_of(state, entry, key::front_context)));
	put(state, setup, key::objective_stakes, gd::str(key::package_objective_defeat_generated_rivals_from));
	put(state, setup, key::readiness_summary, gd::str(text_of(state, entry, key::readiness_summary)));
	put(state, setup, key::difficulty_check,
			gd::str(describe_skirmish_difficulty_check(state, normalized_difficulty, default_difficulty_id(state))));
	put(state, setup, key::difficulty_consequence,
			gd::str(_skirmish_difficulty_consequence(state, normalized_difficulty, default_difficulty_id(state))));
	put(state, setup, key::action_consequence, gd::str(key::starts_a_fresh_package_backed_skirmish));
	put(state, setup, key::action_tooltip, gd::str(join(state, key::newline, setup_lines)));
	const Atom commander_name = string_of(state, entry, key::display_name, gd::str(package_id));
	put(state, setup, key::commander_preview, gd::str(gd::format(state, key::commander_preview_s_opens_with_lyra, { gd::str(commander_name) })));
	put(state, setup, key::operational_board, gd::str(text_of(state, entry, key::operational_board)));
	put(state, setup, key::package_entry, gd::dict_value(entry));
	put(state, setup, key::map_ref, field_or_new_dict(state, entry, key::map_ref));
	put(state, setup, key::scenario_ref, field_or_new_dict(state, entry, key::scenario_ref));
	put(state, setup, key::campaign_adoption, gd::bool_value(false));
	put(state, setup, key::alpha_parity_claim, gd::bool_value(false));
	return setup;
}

Value load_maps_folder_package_session(State &state, Atom package_id, Atom difficulty_id, DictRef options) {
	const DictRef entry = maps_folder_package_entry(state, package_id, options);
	if (gd::is_empty(state, entry)) {
		return empty_session(state);
	}
	return _load_maps_folder_package_session_from_entry(state, entry, normalize_difficulty(state, gd::str(difficulty_id)), options);
}

Value load_maps_folder_package_session_from_entry(State &state, DictRef entry, Atom difficulty_id, DictRef options) {
	return _load_maps_folder_package_session_from_entry(state, entry, normalize_difficulty(state, gd::str(difficulty_id)), options);
}

Value start_maps_folder_package_skirmish_session(State &state, Atom package_id, Atom difficulty_id) {
	const DictRef entry = maps_folder_package_entry(state, package_id, state.new_dict());
	return start_maps_folder_package_skirmish_session_from_entry(state, entry, difficulty_id);
}

Value start_maps_folder_package_skirmish_session_from_entry(State &state, DictRef entry, Atom difficulty_id) {
	if (!_maps_folder_package_entry_is_current(state, entry)) {
		return empty_session(state);
	}
	const DictRef load_options = state.new_dict();
	put(state, load_options, key::startup_source, gd::str(key::skirmish_browser_maps_folder));
	const Value session = load_maps_folder_package_session_from_entry(state, entry, difficulty_id, load_options);
	const DictRef view = gd::object_view(state, session);
	const Atom scenario_id = gd::to_string(gd::index(state, view, gd::str(key::scenario_id)));
	if (scenario_id == key::empty) {
		return session;
	}
	const DictRef flags = gd::as_dict(gd::field(state, view, key::flags));
	const DictRef boundary = dict_or_new(state, flags, key::generated_random_map_boundary);
	put(state, boundary, key::adoption_path, gd::str(key::maps_folder_package_browser_loaded_from_disk));
	put(state, boundary, key::content_service_generated_draft,
			gd::call_method(state, gd::autoload(state, key::ContentService), key::has_generated_scenario_draft, { gd::str(scenario_id) }));
	put(state, boundary, key::legacy_json_scenario_record, gd::bool_value(false));
	put(state, boundary, key::authored_json_scenarios_used, gd::bool_value(false));
	put(state, flags, key::generated_random_map_boundary, gd::dict_value(boundary));
	put(state, flags, key::maps_folder_package_browser, gd::bool_value(true));
	overworld_rules::normalize_overworld_state(state, view);
	gd::set_property(state, gd::autoload(state, key::SessionState), key::active_session, session);
	return session;
}

DictRef _maps_folder_package_stems(State &state, const std::vector<std::pair<Atom, bool>> &entries) {
	const DictRef map_stems = state.new_dict();
	const DictRef scenario_stems = state.new_dict();
	for (const std::pair<Atom, bool> &entry : entries) {
		const Atom filename = entry.first;
		if (!entry.second) {
			if (gd::ends_with(state, filename, key::amap)) {
				put(state, map_stems, get_basename(state, filename), gd::bool_value(true));
			} else if (gd::ends_with(state, filename, key::ascenario)) {
				put(state, scenario_stems, get_basename(state, filename), gd::bool_value(true));
			}
		}
	}
	const DictRef stems = state.new_dict();
	put(state, stems, key::map_stems, gd::dict_value(map_stems));
	put(state, stems, key::scenario_stems, gd::dict_value(scenario_stems));
	return stems;
}

DictRef _maps_folder_package_record(State &state, const Value &service, Atom package_dir, Atom package_stem, DictRef options) {
	const Atom map_path = gd::format(state, key::s_s_amap, { gd::str(package_dir), gd::str(package_stem) });
	const Atom scenario_path = gd::format(state, key::s_s_ascenario, { gd::str(package_dir), gd::str(package_stem) });
	const DictRef map_inspect = gd::as_dict(gd::call_method(state, service, key::inspect_package, { gd::str(map_path) }));
	const DictRef scenario_inspect = gd::as_dict(gd::call_method(state, service, key::inspect_package, { gd::str(scenario_path) }));
	if (!gd::bool_field(state, map_inspect, key::ok, false) || !gd::bool_field(state, scenario_inspect, key::ok, false)) {
		const DictRef failure = record_failure(state, package_stem, map_path, scenario_path, key::package_inspect_failed);
		put(state, failure, key::map_inspect, gd::dict_value(_public_package_load_result(state, map_inspect)));
		put(state, failure, key::scenario_inspect, gd::dict_value(_public_package_load_result(state, scenario_inspect)));
		return failure;
	}
	if (gd::bool_field(state, map_inspect, key::legacy_json_scenario_record, true)
			|| gd::bool_field(state, scenario_inspect, key::legacy_json_scenario_record, true)) {
		return record_failure(state, package_stem, map_path, scenario_path, key::legacy_json_package_rejected);
	}
	const DictRef map_manifest = dict_or_new(state, map_inspect, key::browser_manifest);
	const DictRef scenario_manifest = dict_or_new(state, scenario_inspect, key::browser_manifest);
	if (text_of(state, map_manifest, key::document_kind) != key::map || text_of(state, scenario_manifest, key::document_kind) != key::scenario) {
		const DictRef map_load = gd::as_dict(gd::call_method(state, service, key::load_map_package, { gd::str(map_path) }));
		const DictRef scenario_load = gd::as_dict(gd::call_method(state, service, key::load_scenario_package, { gd::str(scenario_path) }));
		const DictRef failure = record_failure(state, package_stem, map_path, scenario_path, key::package_load_failed);
		put(state, failure, key::map_load, gd::dict_value(_public_package_load_result(state, map_load)));
		put(state, failure, key::scenario_load, gd::dict_value(_public_package_load_result(state, scenario_load)));
		return failure;
	}
	const DictRef metadata = dict_or_new(state, map_manifest, key::metadata);
	const DictRef map_ref = dict_or_new(state, map_manifest, key::map_ref);
	const DictRef scenario_ref = dict_or_new(state, scenario_manifest, key::scenario_ref);
	const int64_t player_count = gd::int_field(state, scenario_manifest, key::player_count, 1);
	const Atom source_kind = string_of(state, map_ref, key::source_kind,
			state.get(metadata, gd::str(key::source_kind), gd::str(key::generated)));
	const bool generated = source_kind == key::generated || gd::begins_with(state, source_kind, key::generated_);
	const bool editor_authored_copy = source_kind == key::authored_legacy_scenario_conversion;
	if (!generated) {
		if (editor_authored_copy && gd::bool_field(state, options, key::include_non_launchable_generated_packages, false)
				&& text_of(state, options, key::consumer) == key::map_editor) {
			const DictRef validation = state.new_dict();
			put(state, validation, key::ok, gd::bool_value(false));
			put(state, validation, key::error_code, gd::str(key::editor_authored_copy_not_skirmish_validated));
			put(state, validation, key::message, gd::str(key::editor_authored_package_copies_require_separate));
			return _maps_folder_package_entry_payload(state, package_stem, map_path, scenario_path, map_manifest, scenario_manifest, metadata,
					map_ref, scenario_ref, player_count, validation, false);
		}
		return record_failure(state, package_stem, map_path, scenario_path, key::non_generated_package_rejected);
	}
	const DictRef launch_validation = _maps_folder_package_launch_validation(state, metadata, map_ref, player_count);
	if (!gd::bool_field(state, launch_validation, key::ok, false)) {
		if (gd::bool_field(state, options, key::include_non_launchable_generated_packages, false)) {
			return _maps_folder_package_entry_payload(state, package_stem, map_path, scenario_path, map_manifest, scenario_manifest, metadata,
					map_ref, scenario_ref, player_count, launch_validation, false);
		}
		const DictRef failure = record_failure(state, package_stem, map_path, scenario_path,
				string_of(state, launch_validation, key::error_code, gd::str(key::generated_package_launch_validation_failed)));
		put(state, failure, key::validation, gd::dict_value(launch_validation));
		return failure;
	}
	return _maps_folder_package_entry_payload(state, package_stem, map_path, scenario_path, map_manifest, scenario_manifest, metadata, map_ref,
			scenario_ref, player_count, launch_validation, true);
}

DictRef _maps_folder_package_entry_payload(State &state, Atom package_stem, Atom map_path, Atom scenario_path, DictRef map_manifest,
		DictRef scenario_manifest, DictRef metadata, DictRef map_ref, DictRef scenario_ref, int64_t player_count, DictRef launch_validation,
		bool launchable) {
	const int64_t width = gd::int_field(state, map_manifest, key::width, 0);
	const int64_t height = gd::int_field(state, map_manifest, key::height, 0);
	const int64_t level_count = gd::int_field(state, map_manifest, key::level_count, 1);
	const Atom package_id = maps_folder_package_id_for_stem(state, package_stem);
	const DictRef selection = dict_or_new(state, scenario_manifest, key::selection);
	const Atom display_name = _maps_folder_display_name(state, package_stem, metadata, selection);
	const Atom source_kind = string_of(state, map_ref, key::source_kind,
			state.get(metadata, gd::str(key::source_kind), gd::str(key::generated)));
	const bool editor_authored_copy = source_kind == key::authored_legacy_scenario_conversion;
	const Atom map_size_label = gd::format(state, key::dx_d_l_d,
			{ gd::int_value(width), gd::int_value(height), gd::int_value(std::max<int64_t>(1, level_count)) });
	const Atom package_label = editor_authored_copy ? key::editor_copy : key::generated_package;
	const Atom metadata_summary = _maps_folder_metadata_summary(state, metadata);
	const Atom summary = gd::format(state, key::s_s_players_d_s,
			{ gd::str(package_label), gd::str(map_size_label), gd::int_value(std::max<int64_t>(1, player_count)), gd::str(metadata_summary) });
	const Atom launch_status = launchable ? key::launchable : key::editor_inspection_only;
	const DictRef payload = state.new_dict();
	put(state, payload, key::ok, gd::bool_value(true));
	put(state, payload, key::package_id, gd::str(package_id));
	put(state, payload, key::scenario_id, gd::str(package_id));
	put(state, payload, key::package_stem, gd::str(package_stem));
	const Atom default_label = difficulty_label(state, default_difficulty_id(state));
	put(state, payload, key::label,
			gd::str(gd::format(state, key::s_s_s_6, { gd::str(display_name), gd::str(map_size_label), gd::str(default_label) })));
	put(state, payload, key::display_name, gd::str(display_name));
	put(state, payload, key::summary, gd::str(summary));
	put(state, payload, key::front_context,
			gd::str(editor_authored_copy ? key::front_editor_authored_package_copy_from : key::front_generated_package_pair_from_maps));
	put(state, payload, key::readiness_summary, gd::str(key::readiness_paired_amap_ascenario_files_load));
	put(state, payload, key::operational_board,
			gd::str(gd::format(state, key::s_s_s_7, { gd::str(summary), gd::str(map_path), gd::str(scenario_path) })));
	put(state, payload, key::map_path, gd::str(map_path));
	put(state, payload, key::scenario_path, gd::str(scenario_path));
	put(state, payload, key::map_ref, gd::dict_value(map_ref));
	put(state, payload, key::scenario_ref, gd::dict_value(scenario_ref));
	put(state, payload, key::map_file_identity, gd::dict_value(_maps_folder_package_file_identity(state, map_path)));
	put(state, payload, key::scenario_file_identity, gd::dict_value(_maps_folder_package_file_identity(state, scenario_path)));
	const DictRef map_size = state.new_dict();
	put(state, map_size, key::width, gd::int_value(width));
	put(state, map_size, key::height, gd::int_value(height));
	put(state, map_size, key::x, gd::int_value(width));
	put(state, map_size, key::y, gd::int_value(height));
	put(state, map_size, key::level_count, gd::int_value(std::max<int64_t>(1, level_count)));
	put(state, payload, key::map_size, gd::dict_value(map_size));
	put(state, payload, key::player_count, gd::int_value(std::max<int64_t>(1, player_count)));
	put(state, payload, key::metadata, gd::dict_value(metadata));
	put(state, payload, key::maps_folder_launch_validation, gd::dict_value(launch_validation));
	put(state, payload, key::launchable, gd::bool_value(launchable));
	put(state, payload, key::editor_inspection_only, gd::bool_value(!launchable));
	put(state, payload, key::editor_index_policy, gd::str(launch_status));
	put(state, payload, key::source_kind, gd::str(source_kind));
	put(state, payload, key::editor_authored_copy, gd::bool_value(editor_authored_copy));
	put(state, payload, key::startup_source, gd::str(key::maps_folder_package));
	put(state, payload, key::legacy_json_scenario_record, gd::bool_value(false));
	put(state, payload, key::authored_json_scenarios_used, gd::bool_value(false));
	return payload;
}

DictRef _maps_folder_package_launch_validation(State &state, DictRef metadata, DictRef map_ref, int64_t player_count) {
	DictRef normalized = dict_or_new(state, metadata, key::normalized_config);
	if (gd::is_empty(state, normalized)) {
		const DictRef identity = dict_or_new(state, metadata, key::deterministic_identity);
		normalized = dict_or_new(state, identity, key::normalized_config);
	}
	const Atom template_id = gd::strip_edges(state,
			string_of(state, normalized, key::template_id,
					state.get(metadata, gd::str(key::template_id), state.get(map_ref, gd::str(key::template_id), gd::str(key::empty)))));
	const Atom profile_id = gd::strip_edges(state,
			string_of(state, normalized, key::profile_id,
					state.get(metadata, gd::str(key::profile_id), state.get(map_ref, gd::str(key::profile_id), gd::str(key::empty)))));
	const Atom source_template_id = gd::strip_edges(state,
			string_of(state, metadata, key::source_template_id, state.get(map_ref, gd::str(key::source_template_id), gd::str(key::empty))));
	const bool h3maped_source_authoritative = gd::begins_with(state, source_template_id, key::h3maped_template_)
			&& gd::strip_edges(state, text_of(state, metadata, key::source_template_authority)) == key::h3maped_exe_rng;
	const Atom full_generation_status = gd::strip_edges(state,
			string_of(state, metadata, key::full_generation_status, state.get(normalized, gd::str(key::full_generation_status), gd::str(key::empty))));
	const Atom validation_status = gd::strip_edges(state, string_of(state, metadata, key::validation_status, gd::str(key::pass)));
	const DictRef component_counts = dict_or_new(state, metadata, key::component_counts);
	const ArrayRef failures = state.new_array();
	if (!gd::bool_field(state, metadata, key::native_runtime_authoritative, false)) {
		state.append(failures, gd::dict_value(launch_failure(state, key::maps_folder_package_not_runtime_authoritative,
										 key::map_metadata_native_runtime_authoritative, key::generated_maps_folder_packages_must_come)));
	}
	if (!h3maped_source_authoritative && (template_id == key::empty || !gd::begins_with(state, template_id, key::translated_rmg_template_))) {
		const DictRef failure = launch_failure(state, key::maps_folder_package_template_not_recovered_rmg,
				key::map_metadata_normalized_config_template_id, key::generated_maps_folder_packages_must_use);
		put(state, failure, key::template_id, gd::str(template_id));
		put(state, failure, key::source_template_id, gd::str(source_template_id));
		state.append(failures, gd::dict_value(failure));
	}
	if (profile_id == key::border_gate_compact_profile_v1 || template_id == key::border_gate_compact_v1) {
		const DictRef failure = launch_failure(state, key::maps_folder_package_legacy_compact_rejected,
				key::map_metadata_normalized_config_template_id_2, key::the_legacy_compact_generator_output_is);
		put(state, failure, key::template_id, gd::str(template_id));
		put(state, failure, key::profile_id, gd::str(profile_id));
		state.append(failures, gd::dict_value(failure));
	}
	if (full_generation_status == key::empty || full_generation_status == key::not_implemented
			|| full_generation_status == key::implemented_for_supported_profile) {
		const DictRef failure = launch_failure(state, key::maps_folder_package_generation_status_not_launchable,
				key::map_metadata_full_generation_status, key::generated_maps_folder_packages_must_carry);
		put(state, failure, key::full_generation_status, gd::str(full_generation_status));
		state.append(failures, gd::dict_value(failure));
	}
	if (validation_status != key::empty && validation_status != key::pass) {
		const DictRef failure = launch_failure(state, key::maps_folder_package_validation_not_pass, key::map_metadata_validation_status,
				key::generated_maps_folder_packages_must_have);
		put(state, failure, key::validation_status, gd::str(validation_status));
		state.append(failures, gd::dict_value(failure));
	}
	if (gd::int_field(state, component_counts, key::zone_count, 0) <= 0) {
		state.append(failures, gd::dict_value(launch_failure(state, key::maps_folder_package_missing_zones,
										 key::map_metadata_component_counts_zone_count, key::generated_maps_folder_packages_must_preserve)));
	}
	const Atom h3maped_road_public_adoption_status = gd::strip_edges(state, text_of(state, metadata, key::h3maped_road_public_adoption_status));
	const bool h3maped_private_roads_pending = h3maped_road_public_adoption_status
			== key::h3maped_final_road_overlay_private_until_complete_0x14b0_vector_and_public_adoption;
	if (gd::int_field(state, component_counts, key::road_cell_count, 0) <= 0 && !h3maped_private_roads_pending) {
		state.append(failures, gd::dict_value(launch_failure(state, key::maps_folder_package_missing_roads,
										 key::map_metadata_component_counts_road_cell, key::generated_maps_folder_packages_must_preserve_2)));
	}
	if (gd::int_field(state, component_counts, key::town_count, 0) < std::max<int64_t>(1, player_count)) {
		state.append(failures, gd::dict_value(launch_failure(state, key::maps_folder_package_town_count_below_players,
										 key::map_metadata_component_counts_town_count, key::generated_maps_folder_packages_must_provide)));
	}
	const bool passed = state.array_size(failures) == 0;
	const DictRef validation = state.new_dict();
	put(state, validation, key::ok, gd::bool_value(passed));
	put(state, validation, key::schema_id, gd::str(key::aurelion_maps_folder_package_launch_validation_v1));
	put(state, validation, key::status, gd::str(passed ? key::pass : key::fail));
	put(state, validation, key::error_code, gd::str(!passed ? key::generated_package_launch_validation_failed : key::empty));
	put(state, validation, key::template_id, gd::str(template_id));
	put(state, validation, key::profile_id, gd::str(profile_id));
	put(state, validation, key::source_template_id, gd::str(source_template_id));
	put(state, validation, key::h3maped_source_authoritative, gd::bool_value(h3maped_source_authoritative));
	put(state, validation, key::full_generation_status, gd::str(full_generation_status));
	put(state, validation, key::native_runtime_authoritative, gd::bool_value(gd::bool_field(state, metadata, key::native_runtime_authoritative, false)));
	put(state, validation, key::validation_status, gd::str(validation_status));
	put(state, validation, key::component_counts, gd::dict_value(gd::deep_duplicate_dict(state, component_counts)));
	put(state, validation, key::failure_count, gd::int_value(state.array_size(failures)));
	put(state, validation, key::failures, gd::array_value(failures));
	return validation;
}

Value _load_maps_folder_package_session_from_entry(State &state, DictRef entry, Atom difficulty_id, DictRef options) {
	const Value service = _native_map_package_service(state);
	if (service.kind == Kind::Nil) {
		return empty_session(state);
	}
	const Atom map_path = text_of(state, entry, key::map_path);
	const Atom scenario_path = text_of(state, entry, key::scenario_path);
	const DictRef map_load = gd::as_dict(gd::call_method(state, service, key::load_map_package, { gd::str(map_path) }));
	const DictRef scenario_load = gd::as_dict(gd::call_method(state, service, key::load_scenario_package, { gd::str(scenario_path) }));
	if (!gd::bool_field(state, map_load, key::ok, false) || !gd::bool_field(state, scenario_load, key::ok, false)) {
		return empty_session(state);
	}
	const DictRef map_ref = dict_or_new(state, entry, key::map_ref);
	const DictRef scenario_ref = dict_or_new(state, entry, key::scenario_ref);
	const DictRef loaded_map_ref = dict_or_new(state, map_load, key::map_ref);
	const DictRef loaded_scenario_ref = dict_or_new(state, scenario_load, key::scenario_ref);
	if (!_maps_folder_package_ref_matches(state, map_ref, loaded_map_ref,
				string_array(state, { key::package_hash, key::map_id, key::map_hash, key::source_kind }))) {
		return empty_session(state);
	}
	if (!_maps_folder_package_ref_matches(state, scenario_ref, loaded_scenario_ref,
				string_array(state, { key::package_hash, key::scenario_id, key::scenario_hash }))) {
		return empty_session(state);
	}
	const DictRef boundary = state.new_dict();
	put(state, boundary, key::scenario_id, gd::str(text_of(state, scenario_ref, key::scenario_id)));
	const Atom session_id_prefix = string_of(state, options, key::session_id_prefix, gd::str(key::maps_folder_package_session));
	put(state, boundary, key::session_id,
			gd::str(gd::format(state, key::s_d_5, { gd::str(session_id_prefix), gd::int_value(gd::engine_ticks_msec(state)) })));
	put(state, boundary, key::hero_id, gd::str(key::hero_lyra));
	put(state, boundary, key::feature_gate, gd::str(key::native_rmg_generated_map_package_startup));
	put(state, boundary, key::map_package_ref, gd::dict_value(map_ref));
	put(state, boundary, key::scenario_package_ref, gd::dict_value(scenario_ref));
	put(state, boundary, key::launch_mode, gd::str(key::skirmish));
	put(state, boundary, key::runtime_call_site_adoption, gd::bool_value(true));
	put(state, boundary, key::generated_record_policy, gd::str(key::maps_folder_package_loaded_documents_only));
	put(state, boundary, key::content_service_generated_draft, gd::bool_value(false));
	put(state, boundary, key::legacy_json_scenario_record, gd::bool_value(false));
	put(state, boundary, key::authored_json_scenarios_used, gd::bool_value(false));
	put(state, boundary, key::map_package_path, gd::str(map_path));
	put(state, boundary, key::scenario_package_path, gd::str(scenario_path));
	put(state, boundary, key::package_id, gd::str(text_of(state, entry, key::package_id)));
	put(state, boundary, key::package_stem, gd::str(text_of(state, entry, key::package_stem)));
	put(state, boundary, key::startup_source, gd::str(string_of(state, options, key::startup_source, gd::str(key::maps_folder_package))));
	const DictRef bridge_options = state.new_dict();
	put(state, bridge_options, key::hero_id, gd::str(key::hero_lyra));
	const Value session = native_random_map_package_session_bridge::build_session_from_loaded_packages(state, map_load, scenario_load, boundary,
			difficulty_id, bridge_options);
	const DictRef view = gd::object_view(state, session);
	const Atom scenario_id = gd::to_string(gd::index(state, view, gd::str(key::scenario_id)));
	if (scenario_id == key::empty) {
		return session;
	}
	const DictRef flags = gd::as_dict(gd::field(state, view, key::flags));
	put(state, flags, key::maps_folder_package_browser, gd::bool_value(true));
	put(state, flags, key::maps_folder_package_entry, gd::dict_value(gd::deep_duplicate_dict(state, entry)));
	put(state, flags, key::generated_random_map_source, gd::str(key::maps_folder_package));
	const DictRef package_paths = state.new_dict();
	put(state, package_paths, key::map_path, gd::str(map_path));
	put(state, package_paths, key::scenario_path, gd::str(scenario_path));
	put(state, flags, key::generated_random_map_package_paths, gd::dict_value(package_paths));
	put(state, gd::as_dict(gd::index(state, flags, gd::str(key::generated_random_map_boundary))), key::adoption_path,
			gd::str(key::maps_folder_package_loaded_from_disk));
	const Value draft = gd::call_method(state, gd::autoload(state, key::ContentService), key::has_generated_scenario_draft, { gd::str(scenario_id) });
	put(state, gd::as_dict(gd::index(state, flags, gd::str(key::generated_random_map_boundary))), key::content_service_generated_draft, draft);
	put(state, gd::as_dict(gd::index(state, flags, gd::str(key::generated_random_map_boundary))), key::legacy_json_scenario_record,
			gd::bool_value(false));
	put(state, gd::as_dict(gd::index(state, flags, gd::str(key::generated_random_map_boundary))), key::authored_json_scenarios_used,
			gd::bool_value(false));
	put(state, session_view::overworld(state, view), key::maps_folder_package_entry, gd::dict_value(gd::deep_duplicate_dict(state, entry)));
	overworld_rules::normalize_overworld_state(state, view);
	return session;
}

bool _maps_folder_package_entry_is_current(State &state, DictRef entry) {
	if (gd::is_empty(state, entry) || !gd::bool_field(state, entry, key::ok, false) || !gd::bool_field(state, entry, key::launchable, false)) {
		return false;
	}
	if (gd::bool_field(state, entry, key::editor_inspection_only, true) || gd::bool_field(state, entry, key::legacy_json_scenario_record, true)
			|| gd::bool_field(state, entry, key::authored_json_scenarios_used, true)) {
		return false;
	}
	const Atom package_id = text_of(state, entry, key::package_id);
	const Atom package_stem = text_of(state, entry, key::package_stem);
	if (!maps_folder_package_id_is_valid(state, package_id) || maps_folder_package_stem_from_id(state, package_id) != package_stem) {
		return false;
	}
	const Atom map_path = text_of(state, entry, key::map_path);
	const Atom scenario_path = text_of(state, entry, key::scenario_path);
	if (get_file(state, map_path) != gd::format(state, key::s_amap, { gd::str(package_stem) })
			|| get_file(state, scenario_path) != gd::format(state, key::s_ascenario, { gd::str(package_stem) })) {
		return false;
	}
	const DictRef launch_validation = dict_or_new(state, entry, key::maps_folder_launch_validation);
	if (!gd::bool_field(state, launch_validation, key::ok, false)) {
		return false;
	}
	return gd::equal(state, field_or_new_dict(state, entry, key::map_file_identity),
				   gd::dict_value(_maps_folder_package_file_identity(state, map_path)))
			&& gd::equal(state, field_or_new_dict(state, entry, key::scenario_file_identity),
					gd::dict_value(_maps_folder_package_file_identity(state, scenario_path)));
}

DictRef _maps_folder_package_file_identity(State &state, Atom path) {
	if (path == key::empty || !gd::file_exists(state, path)) {
		return state.new_dict();
	}
	// FileAccess.open answers null: -1 (a length is never negative).
	const int64_t size = gd::file_length(state, path);
	if (size == -1) {
		return state.new_dict();
	}
	const DictRef identity = state.new_dict();
	put(state, identity, key::path, gd::str(path));
	put(state, identity, key::size, gd::int_value(size));
	put(state, identity, key::modified_time, gd::int_value(gd::file_modified_time(state, path)));
	return identity;
}

bool _maps_folder_package_ref_matches(State &state, DictRef expected, DictRef actual, ArrayRef key_list) {
	if (gd::is_empty(state, expected) || gd::is_empty(state, actual)) {
		return false;
	}
	for (const Value &key_value : gd::items(state, gd::array_value(key_list))) {
		const Value name = gd::str(gd::stringify(state, key_value));
		if (gd::stringify(state, state.get(expected, name, gd::str(key::empty))) == key::empty
				|| !gd::equal(state, state.get(expected, name, Value()), state.get(actual, name, Value()))) {
			return false;
		}
	}
	return true;
}

Atom _maps_folder_display_name(State &state, Atom package_stem, DictRef metadata, DictRef selection) {
	Atom candidate = gd::strip_edges(state,
			string_of(state, metadata, key::display_name, state.get(metadata, gd::str(key::name), gd::str(key::empty))));
	if (candidate != key::empty) {
		return candidate;
	}
	candidate = gd::strip_edges(state, string_of(state, selection, key::name, state.get(selection, gd::str(key::label), gd::str(key::empty))));
	if (candidate != key::empty) {
		return candidate;
	}
	return _title_from_package_stem(state, package_stem);
}

Atom _maps_folder_metadata_summary(State &state, DictRef metadata) {
	const DictRef normalized = dict_or_new(state, metadata, key::normalized_config);
	std::vector<Atom> parts;
	const Atom seed = gd::strip_edges(state,
			string_of(state, normalized, key::normalized_seed, state.get(normalized, gd::str(key::seed), gd::str(key::empty))));
	const Atom template_id = gd::strip_edges(state, text_of(state, normalized, key::template_id));
	const Atom profile_id = gd::strip_edges(state, text_of(state, normalized, key::profile_id));
	if (seed != key::empty) {
		parts.push_back(gd::format(state, key::seed_s, { gd::str(seed) }));
	}
	if (template_id != key::empty) {
		parts.push_back(gd::format(state, key::template_s, { gd::str(template_id) }));
	}
	if (profile_id != key::empty) {
		parts.push_back(gd::format(state, key::profile_s, { gd::str(profile_id) }));
	}
	return !parts.empty() ? join(state, key::space_bar_space, parts) : key::native_generated_map;
}

Atom _maps_folder_package_briefing_check(State &state, DictRef entry, Atom difficulty_id) {
	const Atom front_context = _first_substantive_line(state, text_of(state, entry, key::front_context));
	const Atom readiness = _first_substantive_line(state, text_of(state, entry, key::readiness_summary));
	Atom first_decision = readiness;
	if (first_decision == key::empty) {
		first_decision = front_context;
	}
	if (first_decision == key::empty) {
		first_decision = key::scout_the_generated_start_ring_identify;
	}
	const Atom label = difficulty_label(state, difficulty_id);
	return gd::format(state, key::opening_briefing_package_backed_skirmish_on,
			{ gd::str(label), gd::str(_compact_sentence(state, first_decision, 96)) });
}

} // namespace scenario_select_rules

} // namespace aurelion::rules::port
