// SaveService's slots, the summary lists, the in-session save surface and its
// recap contexts (scripts/autoload/SaveService.gd).

#include "aurelion_rules/port/save_service.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"
#include "aurelion_rules/port/session_state_store.hpp"

#include <algorithm>
#include <string>
#include <vector>

namespace aurelion::rules::port {

namespace {

using gd::ArrayRef;
using gd::Atom;
using gd::bool_value;
using gd::dict_value;
using gd::DictRef;
using gd::float_value;
using gd::int_value;
using gd::PackedRef;
using gd::str;
using state::Kind;
using state::State;
using state::Value;
namespace key = state::key;

// SAVE_DIR ("user://saves"), SLOT_TYPE_MANUAL and SLOT_TYPE_AUTOSAVE are
// key::user_saves, key::manual and key::autosave.
constexpr int64_t kManualSlotIds[] = { 1, 2, 3 };

Value self_node(State &state) {
	return gd::autoload(state, key::SaveService);
}

int64_t selected_manual_slot_member(State &state) {
	return gd::to_int(state, gd::member(state, self_node(state), key::_selected_manual_slot));
}

// String(value): stringify()'s types, and the engine's text of anything else.
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

// String(dict.get(field, fallback)).
Atom string_get(State &state, DictRef dict, Atom field, Atom fallback) {
	return string_of(state, state.get(dict, str(field), str(fallback)));
}

// session != null and session.scenario_id != "".
bool has_scenario(State &state, const Value &session) {
	if (session.kind == Kind::Nil) {
		return false;
	}
	return gd::to_string(gd::member(state, session, key::scenario_id)) != key::empty;
}

// The session object a host call takes.
Value session_object(State &state, const Value &session) {
	return session.kind == Kind::Dict ? gd::view_object(state, session.ref) : session;
}

// base.path_join(file) (String::path_join).
Atom path_join(State &state, Atom base, Atom file) {
	const std::string base_text = state.text(base);
	const std::string file_text = state.text(file);
	if (base_text.empty()) {
		return file;
	}
	if (base_text.back() == '/' || (!file_text.empty() && file_text.front() == '/')) {
		return state.intern(base_text + file_text);
	}
	return state.intern(base_text + "/" + file_text);
}

// separator.join(parts) of the first count parts.
Atom join_atoms(State &state, Atom separator, const std::vector<Atom> &parts, size_t count) {
	std::string joined;
	for (size_t index = 0; index < count && index < parts.size(); ++index) {
		if (index != 0) {
			joined += state.text(separator);
		}
		joined += state.text(parts[index]);
	}
	return state.intern(joined);
}

// buckets[name] = ProfileLogScript.elapsed_ms(started).
void bucket(State &state, DictRef buckets, Atom name, int64_t started) {
	state.set(buckets, str(name), float_value(save_service::profile_elapsed_ms(state, started)));
}

// load("res://scripts/core/ScenarioRules.gd").describe_session_progress_recap_from_normalized_session(session, false).
Atom progress_recap_from_normalized_session(State &state, const Value &session) {
	return gd::to_string(gd::call_static(state, key::scenario_rules_script, key::describe_session_progress_recap_from_normalized_session,
			{ session_object(state, session), bool_value(false), dict_value(state.new_dict()) }));
}

} // namespace

namespace save_service {

ArrayRef get_manual_slot_ids(State &state) {
	// MANUAL_SLOT_IDS.duplicate(): a new untyped Array.
	const ArrayRef ids = state.new_array();
	for (const int64_t slot : kManualSlotIds) {
		state.append(ids, int_value(slot));
	}
	return ids;
}

int64_t get_selected_manual_slot(State &state) {
	return selected_manual_slot_member(state);
}

void set_selected_manual_slot(State &state, int64_t slot) {
	gd::set_member(state, self_node(state), key::_selected_manual_slot, int_value(_normalize_manual_slot(state, slot)));
}

DictRef inspect_manual_slot(State &state, int64_t slot) {
	_trace_summary_inspection(state, key::inspect_manual_slot);
	const int64_t normalized_slot = _normalize_manual_slot(state, slot);
	const Atom slot_id = gd::stringify(state, int_value(normalized_slot));
	const Atom path = _slot_path(state, normalized_slot);
	return _inspect_slot(state, key::manual, slot_id, path);
}

DictRef inspect_autosave(State &state) {
	_trace_summary_inspection(state, key::inspect_autosave);
	return _inspect_slot(state, key::autosave, key::autosave, _autosave_path(state));
}

ArrayRef list_session_summaries(State &state) {
	_trace_summary_inspection(state, key::list_session_summaries);
	const ArrayRef summaries = state.new_array();
	state.append(summaries, dict_value(inspect_autosave(state)));
	for (const int64_t slot : kManualSlotIds) {
		state.append(summaries, dict_value(inspect_manual_slot(state, slot)));
	}
	ai::append_array(state, summaries, list_save_files(state));
	return summaries;
}

DictRef latest_loadable_summary(State &state) {
	_trace_summary_inspection(state, key::latest_loadable_summary);
	// Every overworld refresh asks for this. Reuse the answer until this service
	// writes a save or any file in the save folder changes.
	const Atom fingerprint = _save_folder_fingerprint(state);
	if (fingerprint != key::empty
			&& fingerprint == gd::to_string(gd::member(state, self_node(state), key::_latest_loadable_summary_fingerprint))) {
		return gd::duplicate_dict(state, gd::as_dict(gd::member(state, self_node(state), key::_latest_loadable_summary_cache)));
	}
	DictRef latest = state.new_dict();
	const ArrayRef listed = list_session_summaries(state);
	for (int64_t index = 0; index < state.array_size(listed); ++index) {
		const Value summary = state.at(listed, index);
		if (!can_load_summary(state, gd::as_dict(summary))) {
			continue;
		}
		if (gd::is_empty(state, latest)
				|| summary_recency_timestamp(state, gd::as_dict(summary)) > summary_recency_timestamp(state, latest)) {
			latest = gd::as_dict(summary);
		}
	}
	// Inspection may have recovered an interrupted save, so fingerprint afterwards.
	gd::set_member(state, self_node(state), key::_latest_loadable_summary_cache, dict_value(gd::duplicate_dict(state, latest)));
	gd::set_member(state, self_node(state), key::_latest_loadable_summary_fingerprint, str(_save_folder_fingerprint(state)));
	return latest;
}

Atom _save_folder_fingerprint(State &state) {
	const Value directory = gd::class_call_static(state, key::DirAccess, key::open, { str(key::user_saves) });
	if (directory.kind == Kind::Nil) {
		return key::empty;
	}
	const PackedRef entries = gd::as_strings(gd::call_method(state, directory, key::get_files, {}));
	std::vector<std::string> parts;
	const int64_t count = gd::packed_size(state, entries);
	for (int64_t index = 0; index < count; ++index) {
		const Atom entry = gd::packed_string(state, entries, index);
		const Atom path = path_join(state, key::user_saves, entry);
		const int64_t modified_timestamp = gd::file_modified_time(state, path);
		if (_slot_file_modified_recently(state, modified_timestamp)) {
			return key::empty;
		}
		const Value size = gd::class_call_static(state, key::FileAccess, key::get_size, { str(path) });
		parts.push_back(state.text(gd::format(state, key::s_d_d, { str(entry), int_value(modified_timestamp), size })));
	}
	// parts.sort(): Godot's String < compares code points, which is UTF-8's byte
	// order, and equal strings cannot be told apart, so any correct sort is Godot's.
	std::sort(parts.begin(), parts.end());
	std::string joined;
	for (size_t index = 0; index < parts.size(); ++index) {
		if (index != 0) {
			joined += "\n";
		}
		joined += parts[index];
	}
	return state.intern(joined);
}

void _invalidate_latest_loadable_summary(State &state) {
	gd::set_member(state, self_node(state), key::_latest_loadable_summary_cache, dict_value(state.new_dict()));
	gd::set_member(state, self_node(state), key::_latest_loadable_summary_fingerprint, str(key::empty));
}

double summary_recency_timestamp(State &state, DictRef summary) {
	return _summary_sort_timestamp(state, summary);
}

DictRef in_session_save_bar_status(State &state, const Value &session, int64_t manual_slot) {
	const int64_t selected_slot = _normalize_manual_slot(state, manual_slot > 0 ? manual_slot : selected_manual_slot_member(state));
	const Atom current_target = _resume_target_for_session(state, session);
	const DictRef live_summary = state.new_dict();
	if (has_scenario(state, session)) {
		state.set(live_summary, str(key::slot_type), str(key::manual));
		state.set(live_summary, str(key::slot_id), str(gd::stringify(state, int_value(selected_slot))));
		state.set(live_summary, str(key::resume_target), str(current_target));
	}
	const Atom save_button_label = _in_session_save_label(state, current_target, selected_slot);
	const Atom menu_button_label = _return_to_menu_label(state, current_target, session);
	const Atom save_handoff_brief = _describe_session_save_handoff_brief_from_summary(state, session, live_summary);
	const DictRef latest = latest_loadable_summary(state);
	const Atom latest_context = _latest_context_line(state, latest, current_target);
	const DictRef result = state.new_dict();
	state.set(result, str(key::selected_slot), int_value(selected_slot));
	state.set(result, str(key::save_button_label), str(save_button_label));
	state.set(result, str(key::menu_button_label), str(menu_button_label));
	state.set(result, str(key::save_handoff_brief), str(save_handoff_brief));
	state.set(result, str(key::latest_context), str(latest_context));
	return result;
}

DictRef build_current_session_save_context(State &state, const Value &session) {
	// Action tooltips consume current-session copy, not a list of stored saves.
	return build_in_session_save_surface(state, session, -1, state.new_dict(), false, true);
}

DictRef build_in_session_save_surface(State &state, const Value &session, int64_t manual_slot, DictRef refresh_watch_context, bool include_stored_summaries, bool include_stored_recaps) {
	const int64_t profile_started = profile_begin_usec(state);
	const DictRef buckets = state.new_dict();
	const int64_t selected_slot = _normalize_manual_slot(state, manual_slot > 0 ? manual_slot : selected_manual_slot_member(state));
	const int64_t slot_started = profile_begin_usec(state);
	const DictRef slot_summary = include_stored_summaries ? inspect_manual_slot(state, selected_slot) : state.new_dict();
	bucket(state, buckets, key::inspect_selected_slot, slot_started);
	const int64_t latest_started = profile_begin_usec(state);
	const DictRef latest_summary = include_stored_summaries ? latest_loadable_summary(state) : state.new_dict();
	bucket(state, buckets, key::latest_loadable_summary, latest_started);
	const Atom current_target = _resume_target_for_session(state, session);
	const int64_t payload_started = profile_begin_usec(state);
	const DictRef live_payload = has_scenario(state, session)
			? gd::as_dict(gd::call_method(state, session, key::to_dict, {}))
			: state.new_dict();
	bucket(state, buckets, key::detached_live_payload, payload_started);
	const int64_t summary_started = profile_begin_usec(state);
	const DictRef selected_live_summary = _live_session_summary_from_payload(state, live_payload, selected_slot, current_target);
	const DictRef default_live_summary = _live_summary_for_manual_slot(state, selected_live_summary, selected_manual_slot_member(state), false);
	const Value detached_live_session = _session_from_owned_detached_payload(state, live_payload);
	bucket(state, buckets, key::normalized_live_summary, summary_started);
	const int64_t context_started = profile_begin_usec(state);
	const Atom current_context = !gd::is_empty(state, default_live_summary) ? describe_resume_brief(state, default_live_summary) : key::empty;
	bucket(state, buckets, key::current_context, context_started);
	const int64_t normalization_started = profile_begin_usec(state);
	const bool detached_was_runtime_normalized = gd::to_bool(
			gd::call_static(state, key::overworld_rules_script, key::is_runtime_session_normalized, { detached_live_session }));
	const bool detached_normalization_fallback = detached_live_session.kind != Kind::Nil && !detached_was_runtime_normalized;
	if (detached_normalization_fallback) {
		overworld_rules::normalize_overworld_state(state, gd::object_view(state, detached_live_session));
	}
	bucket(state, buckets, key::detached_normalization, normalization_started);
	const int64_t read_scope_started = profile_begin_usec(state);
	gd::call_static(state, key::overworld_rules_script, key::begin_normalized_read_scope, { detached_live_session });
	gd::call_static(state, key::town_rules_script, key::begin_read_scope, { detached_live_session });
	bucket(state, buckets, key::detached_read_scope_begin, read_scope_started);
	const int64_t recap_started = profile_begin_usec(state);
	const int64_t recap_context_started = profile_begin_usec(state);
	const DictRef recap_context = _session_save_recap_context(state, detached_live_session, default_live_summary, key::empty, true, refresh_watch_context);
	bucket(state, buckets, key::shared_recap_context, recap_context_started);
	state.set(buckets, str(key::shared_progress_context),
			float_value(gd::to_float(state.get(recap_context, str(key::profile_progress_ms), float_value(0.0)))));
	state.set(buckets, str(key::shared_watch_context),
			float_value(gd::to_float(state.get(recap_context, str(key::profile_watch_ms), float_value(0.0)))));
	const int64_t save_copy_started = profile_begin_usec(state);
	const Atom save_check = _describe_session_save_check_from_context(state, detached_live_session, default_live_summary, recap_context);
	const Atom save_handoff = _describe_session_save_handoff_from_summary(state, detached_live_session, selected_live_summary, selected_slot);
	const Atom save_handoff_brief = _describe_session_save_handoff_brief_from_summary(state, detached_live_session, selected_live_summary);
	bucket(state, buckets, key::save_copy, save_copy_started);
	const int64_t return_copy_started = profile_begin_usec(state);
	const Atom return_handoff = _describe_session_return_handoff_from_summary(state, detached_live_session, default_live_summary);
	bucket(state, buckets, key::return_copy, return_copy_started);
	const int64_t current_recap_started = profile_begin_usec(state);
	const Atom current_save_recap = _session_save_resume_recap_from_context(state, detached_live_session, default_live_summary, recap_context);
	bucket(state, buckets, key::current_save_recap, current_recap_started);
	const int64_t play_check_started = profile_begin_usec(state);
	const Atom play_check = _describe_session_play_check_from_context(state, detached_live_session, default_live_summary, recap_context);
	bucket(state, buckets, key::play_check, play_check_started);
	bucket(state, buckets, key::recap_surfaces, recap_started);
	gd::call_static(state, key::town_rules_script, key::end_read_scope, { detached_live_session });
	gd::call_static(state, key::overworld_rules_script, key::end_normalized_read_scope, { detached_live_session });
	if (!include_stored_summaries) {
		const DictRef current = state.new_dict();
		state.set(current, str(key::save_check), str(save_check));
		state.set(current, str(key::current_save_recap), str(current_save_recap));
		return current;
	}
	const int64_t stored_recap_started = profile_begin_usec(state);
	const DictRef stored_recap_profile = state.new_dict();
	// Active-play save bars consume current copy and verified slot identity, but
	// not stored resume recaps.
	const Atom slot_resume_recap = include_stored_recaps
			? _describe_summary_resume_recap_with_context(state, slot_summary, stored_recap_profile)
			: key::empty;
	const bool stored_recap_alias_reused = _summaries_share_storage_identity(state, slot_summary, latest_summary);
	const Atom latest_resume_recap = stored_recap_alias_reused || !include_stored_recaps
			? slot_resume_recap
			: _describe_summary_resume_recap_with_context(state, latest_summary, stored_recap_profile);
	bucket(state, buckets, key::stored_resume_recaps, stored_recap_started);
	const Atom save_button_label = _in_session_save_label(state, current_target, selected_slot);
	const Atom save_button_tooltip = _in_session_save_tooltip(state, current_target, slot_summary, current_context);
	const Atom latest_context = _latest_context_line(state, latest_summary, current_target);
	const Atom menu_button_label = _return_to_menu_label(state, current_target, detached_live_session);
	const Atom menu_button_tooltip = _return_to_menu_tooltip(state, current_target, latest_summary, current_context, return_handoff);
	const DictRef result = state.new_dict();
	state.set(result, str(key::selected_slot), int_value(selected_slot));
	state.set(result, str(key::slot_summary), dict_value(slot_summary));
	state.set(result, str(key::latest_summary), dict_value(latest_summary));
	state.set(result, str(key::save_button_label), str(save_button_label));
	state.set(result, str(key::save_button_tooltip), str(save_button_tooltip));
	state.set(result, str(key::latest_context), str(latest_context));
	state.set(result, str(key::current_context), str(current_context));
	state.set(result, str(key::play_check), str(play_check));
	state.set(result, str(key::save_check), str(save_check));
	state.set(result, str(key::save_handoff), str(save_handoff));
	state.set(result, str(key::save_handoff_brief), str(save_handoff_brief));
	state.set(result, str(key::return_handoff), str(return_handoff));
	state.set(result, str(key::current_save_recap), str(current_save_recap));
	state.set(result, str(key::slot_resume_recap), str(slot_resume_recap));
	state.set(result, str(key::latest_resume_recap), str(latest_resume_recap));
	state.set(result, str(key::menu_button_label), str(menu_button_label));
	state.set(result, str(key::menu_button_tooltip), str(menu_button_tooltip));
	const double total_ms = profile_elapsed_ms(state, profile_started);
	const bool play_check_materialized = gd::bool_field(state, recap_context, key::play_check_state_materialized, false);
	const DictRef metadata = state.new_dict();
	state.set(metadata, str(key::selected_slot), int_value(selected_slot));
	state.set(metadata, str(key::current_target), str(current_target));
	state.set(metadata, str(key::detached_normalization_fallback), bool_value(detached_normalization_fallback));
	state.set(metadata, str(key::detached_was_runtime_normalized), bool_value(detached_was_runtime_normalized));
	state.set(metadata, str(key::stored_recap_alias_reused), bool_value(stored_recap_alias_reused));
	state.set(metadata, str(key::stored_recaps_requested), bool_value(include_stored_recaps));
	state.set(metadata, str(key::stored_recap_context_build_count),
			int_value(gd::int_field(state, stored_recap_profile, key::context_build_count, 0)));
	state.set(metadata, str(key::stored_recap_context_reuse_count),
			int_value(gd::int_field(state, stored_recap_profile, key::context_reuse_count, 0)));
	state.set(metadata, str(key::stored_recap_text_cache_hits),
			int_value(gd::int_field(state, stored_recap_profile, key::text_cache_hits, 0)));
	state.set(metadata, str(key::play_check_context_build_count), int_value(play_check_materialized ? 1 : 0));
	state.set(metadata, str(key::play_check_context_reuse_count),
			int_value(gd::bool_field(state, recap_context, key::play_check_state_materialized, false) ? 1 : 0));
	state.set(metadata, str(key::play_check_context_direct_fallback_count),
			int_value(gd::int_field(state, recap_context, key::play_check_direct_fallback_count, 0)));
	state.set(metadata, str(key::overworld_refresh_watch_context_preloaded),
			bool_value(gd::bool_field(state, recap_context, key::refresh_watch_context_preloaded, false)));
	state.set(metadata, str(key::overworld_save_watch_context_reuse_count),
			int_value(gd::bool_field(state, recap_context, key::refresh_watch_context_preloaded, false) ? 1 : 0));
	state.set(metadata, str(key::overworld_save_watch_context_direct_fallback_count),
			int_value(gd::bool_field(state, recap_context, key::refresh_watch_context_preloaded, false) ? 0 : 1));
	gd::call_static(state, key::profile_log_script, key::emit_general,
			{ str(key::save), str(key::surface), str(key::build_in_session_save_surface), float_value(total_ms), dict_value(buckets),
					dict_value(metadata), session_object(state, session) });
	return result;
}

DictRef _live_session_summary_from_payload(State &state, DictRef payload, int64_t manual_slot, Atom resume_target) {
	if (gd::is_empty(state, payload) || string_get(state, payload, key::scenario_id, key::empty) == key::empty) {
		return state.new_dict();
	}
	const int64_t selected_slot = _normalize_manual_slot(state, manual_slot);
	const Atom slot_id = gd::stringify(state, int_value(selected_slot));
	const Atom path = _slot_path(state, selected_slot);
	DictRef summary = _empty_summary(state, key::manual, slot_id, path);
	summary = _populate_summary_from_payload(state, summary, payload);
	state.set(summary, str(key::payload), dict_value(payload));
	state.set(summary, str(key::valid), bool_value(true));
	state.set(summary, str(key::validity), str(key::ok));
	state.set(summary, str(key::loadable), bool_value(true));
	state.set(summary, str(key::resume_target), str(resume_target));
	state.set(summary, str(key::status_text), str(_status_text_for_summary(state, summary)));
	return summary;
}

Value _session_from_owned_detached_payload(State &state, DictRef payload) {
	if (gd::is_empty(state, payload)) {
		return Value();
	}
	const Value session = session_state_store::new_session_data(state, key::empty, key::empty, key::empty, 1, state.new_dict(), key::normal, key::campaign);
	const DictRef view = gd::object_view(state, session);
	const int64_t save_version = std::max<int64_t>(0,
			gd::to_int(state, state.get(payload, str(key::save_version), int_value(session_state_store::kSaveVersion))));
	state.set(view, str(key::save_version), int_value(save_version));
	const Atom ticks = gd::stringify(state, int_value(gd::engine_ticks_msec(state)));
	state.set(view, str(key::session_id), str(string_get(state, payload, key::session_id, ticks)));
	state.set(view, str(key::scenario_id), str(string_get(state, payload, key::scenario_id, key::empty)));
	state.set(view, str(key::hero_id), str(string_get(state, payload, key::hero_id, key::empty)));
	const int64_t day = std::max<int64_t>(1, gd::to_int(state, state.get(payload, str(key::day), int_value(1))));
	state.set(view, str(key::day), int_value(day));
	state.set(view, str(key::difficulty), str(string_get(state, payload, key::difficulty, key::normal)));
	state.set(view, str(key::launch_mode),
			str(session_state_store::normalize_launch_mode(state, state.get(payload, str(key::launch_mode), str(key::campaign)))));
	state.set(view, str(key::game_state),
			str(session_state_store::_normalize_game_state(state, state.get(payload, str(key::game_state), str(key::overworld)))));
	state.set(view, str(key::scenario_status),
			str(session_state_store::_normalize_scenario_status(state, state.get(payload, str(key::scenario_status), str(key::in_progress)))));
	state.set(view, str(key::scenario_summary), str(string_get(state, payload, key::scenario_summary, key::empty)));
	// payload.get(x, {}) if payload.get(x, {}) is Dictionary else {}: the payload's
	// own Dictionary, or a new empty one.
	DictRef parts[3] = {};
	const Atom fields[3] = { key::overworld, key::battle, key::flags };
	for (int index = 0; index < 3; ++index) {
		Value found;
		parts[index] = state.lookup(payload, str(fields[index]), found) && gd::is_dict(found) ? found.ref : state.new_dict();
		state.set(view, str(fields[index]), dict_value(parts[index]));
	}
	session_state_store::share_runtime_scenario_record(state, parts[0], parts[2]);
	return session;
}

bool _summaries_share_storage_identity(State &state, DictRef first, DictRef second) {
	if (gd::is_empty(state, first) || gd::is_empty(state, second)) {
		return false;
	}
	const Atom first_path = string_get(state, first, key::path, key::empty);
	if (first_path == key::empty || first_path != string_get(state, second, key::path, key::empty)) {
		return false;
	}
	const Atom fields[] = {
		key::slot_type,
		key::slot_id,
		key::validity,
		key::loadable,
		key::modified_timestamp,
		key::recorded_timestamp,
		key::recorded_timestamp_precise,
		key::payload_bytes,
	};
	for (const Atom field : fields) {
		if (!gd::equal(state, state.get(first, str(field), Value()), state.get(second, str(field), Value()))) {
			return false;
		}
	}
	return true;
}

DictRef _live_summary_for_manual_slot(State &state, DictRef source, int64_t manual_slot, bool valid_storage) {
	if (gd::is_empty(state, source)) {
		return state.new_dict();
	}
	const int64_t selected_slot = _normalize_manual_slot(state, manual_slot);
	const DictRef summary = gd::duplicate_dict(state, source);
	state.set(summary, str(key::slot_type), str(key::manual));
	state.set(summary, str(key::slot_id), str(gd::stringify(state, int_value(selected_slot))));
	state.set(summary, str(key::path), str(_slot_path(state, selected_slot)));
	state.set(summary, str(key::validity), str(valid_storage ? key::ok : key::missing));
	state.set(summary, str(key::status_text), str(_status_text_for_summary(state, summary)));
	return summary;
}

DictRef _session_save_recap_context(State &state, const Value &session, DictRef summary, Atom preloaded_progress_recap, bool include_play_check_state, DictRef refresh_watch_context) {
	if (!has_scenario(state, session) || gd::is_empty(state, summary)) {
		const DictRef empty = state.new_dict();
		state.set(empty, str(key::changed_line), str(key::empty));
		state.set(empty, str(key::watch_line), str(key::empty));
		state.set(empty, str(key::next_decision_line), str(key::empty));
		state.set(empty, str(key::progress_recap), str(key::empty));
		state.set(empty, str(key::profile_progress_ms), float_value(0.0));
		state.set(empty, str(key::profile_watch_ms), float_value(0.0));
		state.set(empty, str(key::play_check_state_line), str(key::empty));
		state.set(empty, str(key::play_check_state_materialized), bool_value(false));
		state.set(empty, str(key::play_check_direct_fallback_count), int_value(0));
		state.set(empty, str(key::refresh_watch_context_preloaded), bool_value(false));
		return empty;
	}
	const int64_t progress_started = profile_begin_usec(state);
	const Atom resume_target = string_get(state, summary, key::resume_target, key::overworld);
	const DictRef preferred_recap = _preferred_recent_action_recap(state, session, resume_target);
	const Atom recap_summary = _action_recap_change_summary(state, preferred_recap);
	const Atom recap_next = _action_recap_next_step(state, preferred_recap);
	const Atom battle_summary = resume_target == key::battle && recap_summary == key::empty
			? _battle_aftermath_summary(state, session)
			: key::empty;
	Atom progress_recap = preloaded_progress_recap;
	if ((recap_summary == key::empty && battle_summary == key::empty) || recap_next == key::empty) {
		if (progress_recap == key::empty) {
			progress_recap = progress_recap_from_normalized_session(state, session);
		}
	}
	Atom changed_line = recap_summary;
	if (changed_line == key::empty) {
		changed_line = battle_summary;
	}
	if (changed_line == key::empty) {
		const Atom progress_recent = _line_with_prefix(state, progress_recap, key::recently_resolved);
		if (progress_recent != key::empty) {
			changed_line = _safe_player_text(state,
					gd::strip_edges(state, gd::trim_prefix(state, progress_recent, key::recently_resolved)), 220);
		}
	}
	if (changed_line == key::empty) {
		const Atom scenario_summary = gd::strip_edges(state, string_get(state, summary, key::scenario_summary, key::empty));
		changed_line = scenario_summary != key::empty
				? _safe_player_text(state, scenario_summary, 220)
				: key::no_recent_action_recap_is_stored;
	}
	Atom next_decision_line = recap_next;
	if (next_decision_line == key::empty) {
		const Atom progress_next = _line_with_prefix(state, progress_recap, key::next_step);
		if (progress_next != key::empty) {
			next_decision_line = _safe_player_text(state, gd::strip_edges(state, gd::trim_prefix(state, progress_next, key::next_step)), 220);
		}
	}
	if (next_decision_line == key::empty) {
		const Atom action_line = _summary_resume_action_line(state, summary);
		next_decision_line = action_line != key::empty
				? _safe_player_text(state, gd::strip_edges(state, gd::trim_prefix(state, action_line, key::action_2)), 220)
				: key::load_the_save_inspect_the_resumed;
	}
	if (include_play_check_state && progress_recap == key::empty
			&& (resume_target == key::overworld || resume_target == key::outcome)) {
		progress_recap = progress_recap_from_normalized_session(state, session);
	}
	const double progress_ms = profile_elapsed_ms(state, progress_started);
	const int64_t watch_started = profile_begin_usec(state);
	const bool refresh_watch_context_preloaded = resume_target == key::overworld
			&& state.has(refresh_watch_context, str(key::command_risk_forecast))
			&& state.has(refresh_watch_context, str(key::management_watch));
	const DictRef effective_refresh_watch_context = refresh_watch_context_preloaded ? refresh_watch_context : state.new_dict();
	const Atom watch_line = _summary_watch_state_line(state, session, summary, true, progress_recap, effective_refresh_watch_context);
	const DictRef play_check_context = state.new_dict();
	state.set(play_check_context, str(key::progress_recap), str(progress_recap));
	state.set(play_check_context, str(key::watch_line), str(watch_line));
	Atom play_check_state_line = key::empty;
	int64_t play_check_direct_fallback_count = 0;
	if (include_play_check_state) {
		play_check_state_line = _summary_play_check_state_line_from_context(state, session, summary, play_check_context);
		play_check_direct_fallback_count = gd::int_field(state, play_check_context, key::direct_fallback_count, 0);
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::changed_line), str(changed_line));
	state.set(result, str(key::watch_line), str(watch_line));
	state.set(result, str(key::next_decision_line), str(next_decision_line));
	state.set(result, str(key::progress_recap), str(progress_recap));
	state.set(result, str(key::profile_progress_ms), float_value(progress_ms));
	state.set(result, str(key::profile_watch_ms), float_value(profile_elapsed_ms(state, watch_started)));
	state.set(result, str(key::play_check_state_line), str(play_check_state_line));
	state.set(result, str(key::play_check_state_materialized), bool_value(include_play_check_state));
	state.set(result, str(key::play_check_direct_fallback_count), int_value(play_check_direct_fallback_count));
	state.set(result, str(key::refresh_watch_context_preloaded), bool_value(refresh_watch_context_preloaded));
	return result;
}

Atom _describe_session_save_check_from_context(State &state, const Value &session, DictRef summary, DictRef recap_context) {
	if (!has_scenario(state, session)) {
		return key::save_check_no_active_expedition;
	}
	const Atom resume_context = _safe_player_text(state, _resume_context_label(state, summary), 44);
	const Atom changed = _safe_player_text(state, string_get(state, recap_context, key::changed_line, key::empty), 74);
	const Atom next_decision = _safe_player_text(state, string_get(state, recap_context, key::next_decision_line, key::empty), 74);
	std::vector<Atom> parts;
	if (resume_context != key::empty) {
		parts.push_back(gd::format(state, key::resume_s, { str(resume_context) }));
	}
	if (changed != key::empty) {
		parts.push_back(gd::format(state, key::what_changed_s, { str(changed) }));
	}
	if (next_decision != key::empty) {
		parts.push_back(gd::format(state, key::next_s, { str(next_decision) }));
	}
	return gd::format(state, key::save_check_s, { str(join_atoms(state, key::space_bar_space, parts, parts.size())) });
}

Atom _describe_session_save_handoff_from_summary(State &state, const Value &session, DictRef summary, int64_t manual_slot) {
	if (!has_scenario(state, session)) {
		return key::save_handoff_no_active_expedition_is;
	}
	if (gd::is_empty(state, summary)) {
		return key::save_handoff_no_active_expedition_is;
	}
	const Atom save_label = _in_session_save_label(state, string_get(state, summary, key::resume_target, key::blocked), manual_slot);
	const Atom slot_label = _slot_label(state, summary);
	const Atom target_label = _resume_target_label(state, summary);
	const Atom context_label = _resume_context_label(state, summary);
	const Atom preserved = _resume_preserved_context(state, summary);
	return gd::format(state, key::save_handoff_s_writes_s_as,
			{ str(save_label), str(slot_label), str(target_label), str(context_label), str(preserved) });
}

Atom _describe_session_save_handoff_brief_from_summary(State &state, const Value &session, DictRef summary) {
	if (!has_scenario(state, session)) {
		return key::save_handoff_no_active_expedition;
	}
	if (gd::is_empty(state, summary)) {
		return key::save_handoff_no_active_expedition;
	}
	const Atom slot_label = _slot_label(state, summary);
	const Atom target_label = _resume_target_label(state, summary);
	return gd::format(state, key::save_handoff_s_s, { str(slot_label), str(target_label) });
}

Atom _describe_session_play_check_from_summary(State &state, const Value &session, DictRef summary) {
	if (!has_scenario(state, session)) {
		return key::play_check_no_active_expedition;
	}
	const Atom resume_context = _safe_player_text(state, _resume_context_label(state, summary), 34);
	const Atom next_action = _safe_player_text(state,
			gd::strip_edges(state, gd::trim_prefix(state, describe_summary_next_play_action(state, summary), key::next_play_action)), 72);
	Atom state_line = key::empty;
	if (string_get(state, summary, key::resume_target, key::overworld) == key::town) {
		const Atom headline = gd::to_string(
				gd::call_static(state, key::town_rules_script, key::describe_defense_headline, { session_object(state, session) }));
		const ArrayRef ignored_lines = state.new_array();
		state.append(ignored_lines, str(key::Defense));
		const Atom defense_line = _first_meaningful_line(state, headline, ignored_lines);
		if (defense_line != key::empty) {
			const Atom defense = gd::strip_edges(state, gd::trim_prefix(state, defense_line, key::text_2));
			state_line = _safe_player_text(state, gd::format(state, key::defense_s, { str(defense) }), 72);
		}
	} else {
		state_line = _summary_play_check_state_line(state, session, summary);
	}
	std::vector<Atom> parts;
	if (resume_context != key::empty) {
		parts.push_back(gd::format(state, key::s_ready, { str(resume_context) }));
	}
	if (next_action != key::empty) {
		parts.push_back(next_action);
	}
	if (state_line != key::empty) {
		parts.push_back(state_line);
	}
	return gd::format(state, key::play_check_s, { str(join_atoms(state, key::space_bar_space, parts, std::min<size_t>(3, parts.size()))) });
}

Atom _describe_session_play_check_from_context(State &state, const Value &session, DictRef summary, DictRef recap_context) {
	if (!gd::bool_field(state, recap_context, key::play_check_state_materialized, false)) {
		return _describe_session_play_check_from_summary(state, session, summary);
	}
	if (!has_scenario(state, session)) {
		return key::play_check_no_active_expedition;
	}
	const Atom resume_context = _safe_player_text(state, _resume_context_label(state, summary), 34);
	const Atom next_action = _safe_player_text(state,
			gd::strip_edges(state, gd::trim_prefix(state, describe_summary_next_play_action(state, summary), key::next_play_action)), 72);
	const Atom state_line = string_get(state, recap_context, key::play_check_state_line, key::empty);
	std::vector<Atom> parts;
	if (resume_context != key::empty) {
		parts.push_back(gd::format(state, key::s_ready, { str(resume_context) }));
	}
	if (next_action != key::empty) {
		parts.push_back(next_action);
	}
	if (state_line != key::empty) {
		parts.push_back(state_line);
	}
	return gd::format(state, key::play_check_s, { str(join_atoms(state, key::space_bar_space, parts, std::min<size_t>(3, parts.size()))) });
}

Atom _describe_session_return_handoff_from_summary(State &state, const Value &session, DictRef summary) {
	if (!has_scenario(state, session)) {
		return key::return_handoff_no_active_expedition_is;
	}
	const Atom target = _resume_context_label(state, summary);
	const Atom preserved = _resume_preserved_context(state, summary);
	const DictRef flags = gd::as_dict(gd::member(state, session, key::flags));
	if (gd::bool_field(state, flags, key::editor_working_copy, false)) {
		return gd::format(state, key::return_handoff_editor_restores_the_play, { str(target), str(preserved) });
	}
	const Atom brief = describe_resume_brief(state, summary);
	return gd::format(state, key::return_handoff_menu_autosaves_s_continue, { str(brief), str(target), str(preserved) });
}

Atom _session_save_resume_recap_from_context(State &state, const Value &session, DictRef summary, DictRef recap_context) {
	if (!has_scenario(state, session)) {
		return key::saved_state_no_active_expedition_is;
	}
	std::vector<Atom> lines;
	lines.push_back(gd::format(state, key::saved_state_s, { str(describe_resume_brief(state, summary)) }));
	const Atom next_play_action = describe_summary_next_play_action(state, summary);
	if (next_play_action != key::empty) {
		lines.push_back(next_play_action);
	}
	const Atom resume_handoff = describe_summary_resume_handoff(state, summary);
	if (resume_handoff != key::empty) {
		lines.push_back(resume_handoff);
	}
	const Atom changed_line = string_get(state, recap_context, key::changed_line, key::empty);
	if (changed_line != key::empty) {
		lines.push_back(gd::format(state, key::what_changed_s, { str(changed_line) }));
	}
	const Atom context_label = _resume_context_label(state, summary);
	const Atom game_state = _humanize_label(state, string_get(state, summary, key::game_state, key::overworld));
	lines.push_back(gd::format(state, key::resume_state_s_s, { str(context_label), str(game_state) }));
	const Atom watch_line = string_get(state, recap_context, key::watch_line, key::empty);
	if (watch_line != key::empty) {
		lines.push_back(gd::format(state, key::watch_s, { str(gd::strip_edges(state, gd::trim_prefix(state, watch_line, key::risk_watch))) }));
	}
	const Atom next_line = string_get(state, recap_context, key::next_decision_line, key::empty);
	if (next_line != key::empty) {
		lines.push_back(gd::format(state, key::next_decision_s, { str(next_line) }));
	}
	return join_atoms(state, key::newline, lines, lines.size());
}

} // namespace save_service

} // namespace aurelion::rules::port
