// SaveService: making, finishing and caching slot summaries, the slot files'
// signatures, and the continuity, objective, watch and recap lines a summary
// shows.

#include "aurelion_rules/port/save_service.hpp"

#include "aurelion_rules/port/battle_screen.hpp"

#include "aurelion_rules/port/overworld_rules.hpp"
#include "aurelion_rules/port/overworld_rules_panels.hpp"
#include "aurelion_rules/port/scenario_evaluation.hpp"
#include "aurelion_rules/port/scenario_outcome.hpp"
#include "aurelion_rules/port/scenario_select_rules_setup.hpp"
#include "aurelion_rules/port/scenario_select_rules_turn.hpp"
#include "aurelion_rules/port/session_state_store.hpp"

#include <algorithm>
#include <initializer_list>
#include <string>
#include <vector>

namespace aurelion::rules::port::save_service {

namespace {

using state::Kind;
namespace key = state::key;

// SUMMARY_INLINE_PAYLOAD_MAX_BYTES and SUMMARY_CACHE_TIMESTAMP_SETTLE_SECONDS.
constexpr int64_t kSummaryInlinePayloadMaxBytes = 8 * 1024 * 1024;
constexpr int64_t kSummaryCacheTimestampSettleSeconds = 2;

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
Atom string_get(State &state, DictRef dict, Atom name, Atom fallback) {
	return string_of(state, state.get(dict, gd::str(name), gd::str(fallback)));
}

// profile[name] = int(profile.get(name, 0)) + amount.
void bump(State &state, DictRef profile, Atom name, int64_t amount) {
	put(state, profile, name, gd::int_value(gd::add(gd::int_field(state, profile, name, 0), amount)));
}

// The autoload's _slot_summary_cache and _selected_manual_slot.
DictRef summary_cache(State &state) {
	return gd::as_dict(gd::member(state, gd::autoload(state, key::SaveService), key::_slot_summary_cache));
}

int64_t selected_manual_slot(State &state) {
	return gd::to_int(state, gd::member(state, gd::autoload(state, key::SaveService), key::_selected_manual_slot));
}

// session.scenario_id of a SessionData (the object or its view).
Atom session_scenario_id(State &state, const Value &session) {
	return gd::to_string(gd::index(state, gd::object_view(state, session), gd::str(key::scenario_id)));
}

// session == null or session.scenario_id == "".
bool no_scenario(State &state, const Value &session) {
	return session.kind == Kind::Nil || session_scenario_id(state, session) == key::empty;
}

// BattleRules.describe_risk_readiness_board(session): a null session has no board.
Atom risk_board_of(State &state, const Value &session) {
	return session.kind == Kind::Dict ? battle_rules::describe_risk_readiness_board(state, session.ref) : key::outlook_tactical_risk_board_unavailable;
}

// ScenarioRules.describe_session_progress_recap(session, include_header).
Atom progress_recap_of(State &state, const Value &session, bool include_header) {
	if (session.kind == Kind::Nil) {
		return include_header ? key::progress_recap_no_active_scenario_progress : key::empty;
	}
	return scenario_rules::describe_session_progress_recap(state, gd::object_view(state, session), include_header);
}

// session.to_dict().
DictRef session_to_dict(State &state, const Value &session) {
	return gd::as_dict(gd::call_method(state, session, key::to_dict, {}));
}

// FileAccess.get_size(path) and FileAccess.get_sha256(path).
int64_t file_size(State &state, Atom path) {
	return gd::to_int(state, gd::class_call_static(state, key::FileAccess, key::get_size, { gd::str(path) }));
}

Atom file_sha256(State &state, Atom path) {
	return gd::to_string(gd::class_call_static(state, key::FileAccess, key::get_sha256, { gd::str(path) }));
}

// separator.join(parts) of Strings.
Atom join(State &state, Atom separator, const std::vector<Atom> &parts) {
	std::string out;
	for (size_t index = 0; index < parts.size(); ++index) {
		if (index > 0) {
			out += state.text(separator);
		}
		out += state.text(parts[index]);
	}
	return state.intern(out);
}

// text.contains(what) of a non-empty what.
bool contains(const State &state, Atom text, Atom what) {
	return state.text(text).find(state.text(what)) != std::string::npos;
}

// s.trim_prefix(prefix).strip_edges().
Atom trimmed(State &state, Atom text, Atom prefix) {
	return gd::strip_edges(state, gd::trim_prefix(state, text, prefix));
}

// A one-line Array literal: [text].
ArrayRef one_line(State &state, Atom text) {
	const ArrayRef lines = state.new_array();
	state.append(lines, gd::str(text));
	return lines;
}

// d.get(a, d.get(b, d.get(c, ""))).
Value field_chain(const State &state, DictRef dict, std::initializer_list<Atom> names) {
	Value found;
	for (const Atom name : names) {
		if (state.lookup(dict, gd::str(name), found)) {
			return found;
		}
	}
	return gd::str(key::empty);
}

// summary.get("payload", {}) if it is Dictionary: false for {} (it is only read).
bool payload_of(const State &state, DictRef summary, DictRef &payload) {
	Value found;
	if (state.lookup(summary, gd::str(key::payload), found) && found.kind == Kind::Dict) {
		payload = found.ref;
		return true;
	}
	return false;
}

} // namespace

DictRef _empty_summary(State &state, Atom slot_type, Atom slot_id, Atom file_path) {
	const DictRef summary = state.new_dict();
	put(state, summary, key::slot_type, gd::str(slot_type));
	put(state, summary, key::slot_id, gd::str(slot_id));
	put(state, summary, key::path, gd::str(file_path));
	put(state, summary, key::modified_timestamp, gd::int_value(0));
	put(state, summary, key::recorded_timestamp, gd::int_value(0));
	put(state, summary, key::recorded_timestamp_precise, gd::float_value(0.0));
	put(state, summary, key::source_save_version, gd::int_value(0));
	put(state, summary, key::save_version, gd::int_value(0));
	put(state, summary, key::scenario_id, gd::str(key::empty));
	put(state, summary, key::scenario_name, gd::str(key::empty));
	put(state, summary, key::scenario_summary, gd::str(key::empty));
	put(state, summary, key::campaign_id, gd::str(key::empty));
	put(state, summary, key::campaign_name, gd::str(key::empty));
	put(state, summary, key::chapter_label, gd::str(key::empty));
	put(state, summary, key::day, gd::int_value(0));
	put(state, summary, key::hero_id, gd::str(key::empty));
	put(state, summary, key::hero_name, gd::str(key::empty));
	put(state, summary, key::battle_name, gd::str(key::empty));
	put(state, summary, key::resume_location, gd::str(key::empty));
	put(state, summary, key::difficulty, gd::str(scenario_select_rules::default_difficulty_id(state)));
	put(state, summary, key::launch_mode, gd::str(key::campaign));
	put(state, summary, key::scenario_status, gd::str(key::in_progress));
	put(state, summary, key::game_state, gd::str(key::overworld));
	put(state, summary, key::saved_from_game_state, gd::str(key::overworld));
	put(state, summary, key::saved_from_scenario_status, gd::str(key::in_progress));
	put(state, summary, key::saved_from_launch_mode, gd::str(key::campaign));
	put(state, summary, key::manual_slot_name, gd::str(key::empty));
	put(state, summary, key::resume_target, gd::str(key::blocked));
	put(state, summary, key::validity, gd::str(key::missing));
	put(state, summary, key::valid, gd::bool_value(false));
	put(state, summary, key::loadable, gd::bool_value(false));
	put(state, summary, key::warnings, gd::array_value(state.new_array()));
	put(state, summary, key::status_text, gd::str(key::empty_slot));
	put(state, summary, key::summary, gd::str(key::empty));
	put(state, summary, key::detail, gd::str(key::empty));
	put(state, summary, key::payload, gd::dict_value(state.new_dict()));
	put(state, summary, key::payload_bytes, gd::int_value(0));
	put(state, summary, key::payload_deferred, gd::bool_value(false));
	return summary;
}

DictRef _finalize_summary(State &state, DictRef summary) {
	put(state, summary, key::summary, gd::str(describe_slot(state, summary)));
	put(state, summary, key::detail, gd::str(describe_slot_details(state, summary)));
	return summary;
}

DictRef _finalize_runtime_summary(State &state, DictRef summary, DictRef profile) {
	DictRef payload = 0;
	const bool has_payload = payload_of(state, summary, payload);
	if (gd::bool_field(state, summary, key::payload_deferred, false) || !has_payload || gd::is_empty(state, payload)) {
		if (!gd::is_empty(state, profile)) {
			bump(state, profile, key::summary_detail_direct_fallback_count, 1);
		}
		return _finalize_summary(state, summary);
	}
	return _finalize_summary_from_session(state, summary, _session_from_owned_detached_payload(state, payload), profile);
}

DictRef _finalize_stored_summary(State &state, DictRef summary) {
	DictRef payload = 0;
	const bool has_payload = payload_of(state, summary, payload);
	if (gd::bool_field(state, summary, key::payload_deferred, false) || !has_payload || gd::is_empty(state, payload)) {
		return _finalize_summary(state, summary);
	}
	const Value session = _session_from_payload(state, payload);
	if (session.kind != Kind::Nil && session_scenario_id(state, session) != key::empty) {
		const DictRef view = gd::object_view(state, session);
		overworld_rules::normalize_overworld_state(state, view);
		scenario_rules::normalize_scenario_state(state, view, true);
	}
	return _finalize_summary_from_session(state, summary, session, state.new_dict());
}

DictRef _finalize_summary_from_session(State &state, DictRef summary, const Value &trusted_session, DictRef profile) {
	if (no_scenario(state, trusted_session)) {
		if (!gd::is_empty(state, profile)) {
			bump(state, profile, key::summary_detail_direct_fallback_count, 1);
		}
		return _finalize_summary(state, summary);
	}
	if (!gd::is_empty(state, profile)) {
		bump(state, profile, key::summary_owned_session_materialization_count, 1);
	}
	const int64_t context_started = profile_begin_usec(state);
	const DictRef trusted_view = gd::object_view(state, trusted_session);
	overworld_rules::begin_normalized_read_scope(state, trusted_view);
	town_rules::begin_read_scope(state, trusted_view);
	const Atom progress_recap = scenario_rules::describe_session_progress_recap_from_normalized_session(state, trusted_view, true, state.new_dict());
	const Atom progress_without_header = gd::trim_prefix(state, progress_recap, key::progress_recap_2);
	const DictRef recap_context = _session_save_recap_context(state, trusted_session, summary, progress_without_header, false, state.new_dict());
	put(state, summary, key::summary, gd::str(describe_slot(state, summary)));
	put(state, summary, key::detail, gd::str(_describe_slot_details(state, summary, trusted_session, recap_context, progress_recap)));
	town_rules::end_read_scope(state, trusted_view);
	overworld_rules::end_normalized_read_scope(state, trusted_view);
	if (!gd::is_empty(state, profile)) {
		bump(state, profile, key::summary_detail_context_build_count, 1);
		bump(state, profile, key::summary_detail_context_reuse_count, 3);
		_runtime_save_profile_bucket(state, profile, key::summary_detail_context, profile_elapsed_ms(state, context_started));
	}
	return summary;
}

DictRef _finalize_and_cache_summary(State &state, DictRef summary) {
	const DictRef finalized = _finalize_summary(state, summary);
	_store_slot_summary_cache(state, finalized);
	return finalized;
}

DictRef _cached_slot_summary(State &state, Atom slot_type, Atom slot_id, Atom file_path) {
	const DictRef cached = _cached_slot_summary_entry(state, slot_type, slot_id, file_path);
	Value summary;
	if (state.lookup(cached, gd::str(key::summary), summary) && summary.kind == Kind::Dict) {
		// The caller's own top-level fields, the cached payload shared.
		return gd::duplicate_dict(state, summary.ref);
	}
	return state.new_dict();
}

DictRef _cached_slot_summary_entry(State &state, Atom slot_type, Atom slot_id, Atom file_path) {
	const Atom cache_key = _summary_cache_key(state, slot_type, slot_id, file_path);
	const DictRef cache = summary_cache(state);
	Value cached;
	if (!state.lookup(cache, gd::str(cache_key), cached) || cached.kind != Kind::Dict) {
		return state.new_dict();
	}
	const DictRef entry = cached.ref;
	const DictRef signature = _slot_file_signature(state, file_path, false);
	if (gd::bool_field(state, entry, key::exists, false) != gd::bool_field(state, signature, key::exists, false)) {
		return state.new_dict();
	}
	if (gd::int_field(state, entry, key::modified_timestamp, 0) != gd::int_field(state, signature, key::modified_timestamp, 0)) {
		return state.new_dict();
	}
	if (gd::int_field(state, entry, key::file_size, -1) != gd::int_field(state, signature, key::file_size, -1)) {
		return state.new_dict();
	}
	const Atom cached_sha256 = string_get(state, entry, key::named_file_sha256, key::empty);
	if (cached_sha256 != key::empty) {
		if (file_sha256(state, file_path) != cached_sha256) {
			return state.new_dict();
		}
		// Past the timestamp tick a later edit changes the modification time.
		if (!_slot_file_modified_recently(state, gd::int_field(state, signature, key::modified_timestamp, 0))) {
			put(state, entry, key::named_file_sha256, gd::str(key::empty));
		}
	}
	return entry;
}

void _store_slot_summary_cache(State &state, DictRef summary) {
	const Atom slot_type = string_get(state, summary, key::slot_type, key::empty);
	const Atom slot_id = string_get(state, summary, key::slot_id, key::empty);
	const Atom file_path = string_get(state, summary, key::path, key::empty);
	if (slot_type == key::empty || slot_id == key::empty || file_path == key::empty) {
		return;
	}
	const DictRef signature = _slot_file_signature(state, file_path, true);
	_invalidate_latest_loadable_summary(state);
	const DictRef cache = summary_cache(state);
	const Atom cache_key = _summary_cache_key(state, slot_type, slot_id, file_path);
	const DictRef entry = state.new_dict();
	put(state, entry, key::exists, gd::bool_value(gd::bool_field(state, signature, key::exists, false)));
	put(state, entry, key::file_path, gd::str(file_path));
	put(state, entry, key::modified_timestamp, gd::int_value(gd::int_field(state, signature, key::modified_timestamp, 0)));
	put(state, entry, key::file_size, gd::int_value(gd::int_field(state, signature, key::file_size, -1)));
	put(state, entry, key::named_file_sha256, gd::str(string_get(state, signature, key::named_file_sha256, key::empty)));
	put(state, entry, key::summary, gd::dict_value(gd::duplicate_dict(state, summary)));
	state.set(cache, gd::str(cache_key), gd::dict_value(entry));
}

void _store_runtime_summary_cache(State &state, DictRef payload, Atom slot_type, Atom slot_id, Atom file_path, Atom authoritative_resume_target, DictRef profile) {
	if (gd::is_empty(state, payload) || slot_type == key::empty || slot_id == key::empty || file_path == key::empty) {
		return;
	}
	DictRef summary = _empty_summary(state, slot_type, slot_id, file_path);
	put(state, summary, key::modified_timestamp, gd::int_value(gd::file_exists(state, file_path) ? gd::file_modified_time(state, file_path) : 0));
	put(state, summary, key::payload_bytes, gd::int_value(gd::file_exists(state, file_path) ? file_size(state, file_path) : 0));
	summary = _populate_summary_from_payload(state, summary, payload);
	if (slot_type != key::file && gd::int_field(state, summary, key::payload_bytes, 0) <= kSummaryInlinePayloadMaxBytes) {
		put(state, summary, key::payload, gd::engine_duplicate(state, gd::dict_value(payload), true));
		put(state, summary, key::payload_deferred, gd::bool_value(false));
	} else {
		put(state, summary, key::payload, gd::dict_value(state.new_dict()));
		put(state, summary, key::payload_deferred, gd::bool_value(true));
	}
	put(state, summary, key::valid, gd::bool_value(true));
	put(state, summary, key::validity, gd::str(key::ok));
	put(state, summary, key::warnings, gd::array_value(state.new_array()));
	if (authoritative_resume_target != key::empty) {
		put(state, summary, key::resume_target, gd::str(authoritative_resume_target));
	} else {
		const Value session = _session_from_payload(state, payload);
		put(state, summary, key::resume_target, gd::str(session.kind != Kind::Nil ? _resume_target_for_session(state, session) : key::blocked));
		if (!gd::is_empty(state, profile)) {
			bump(state, profile, key::summary_session_reconstruction_count, 1);
		}
	}
	const Value resume_target = gd::index(state, summary, gd::str(key::resume_target));
	put(state, summary, key::loadable, gd::bool_value(!gd::equal(state, resume_target, gd::str(key::blocked))));
	put(state, summary, key::status_text, gd::str(_status_text_for_summary(state, summary)));
	_store_slot_summary_cache(state, _finalize_runtime_summary(state, summary, profile));
}

void _invalidate_summary_cache_for_path(State &state, Atom file_path) {
	if (file_path == key::empty) {
		return;
	}
	_invalidate_latest_loadable_summary(state);
	const DictRef cache = summary_cache(state);
	// keys().duplicate(): the loop walks a copy while it erases.
	const ArrayRef cache_keys = gd::keys(state, cache);
	const int64_t count = state.array_size(cache_keys);
	for (int64_t index = 0; index < count; ++index) {
		const Value cache_key = state.at(cache_keys, index);
		Value cached;
		if (!state.lookup(cache, cache_key, cached)) {
			continue;
		}
		if (cached.kind == Kind::Dict && string_get(state, cached.ref, key::file_path, key::empty) == file_path) {
			state.erase(cache, cache_key);
		}
	}
}

Atom _summary_cache_key(State &state, Atom slot_type, Atom slot_id, Atom file_path) {
	return gd::format(state, key::s_s_s_9, { gd::str(slot_type), gd::str(slot_id), gd::str(file_path) });
}

DictRef _slot_file_signature(State &state, Atom file_path, bool include_named_file_sha256) {
	const bool exists = gd::file_exists(state, file_path);
	const int64_t modified_timestamp = exists ? gd::file_modified_time(state, file_path) : 0;
	const int64_t size = exists ? file_size(state, file_path) : -1;
	// A named file that fresh is hashed too: a same-size edit within one
	// timestamp tick must not return an old cached save.
	const Atom sha256 = include_named_file_sha256 && exists && gd::ends_with(state, file_path, key::save_json) &&
					_slot_file_modified_recently(state, modified_timestamp)
			? file_sha256(state, file_path)
			: key::empty;
	const DictRef signature = state.new_dict();
	put(state, signature, key::exists, gd::bool_value(exists));
	put(state, signature, key::modified_timestamp, gd::int_value(modified_timestamp));
	put(state, signature, key::file_size, gd::int_value(size));
	put(state, signature, key::named_file_sha256, gd::str(sha256));
	return signature;
}

bool _slot_file_modified_recently(State &state, int64_t modified_timestamp) {
	return modified_timestamp >= gd::sub(compat::float_to_int(gd::engine_unix_time(state)), kSummaryCacheTimestampSettleSeconds);
}

DictRef _summary_payload(State &state, DictRef summary) {
	// Shared with the summary cache: only read.
	DictRef payload = 0;
	if (payload_of(state, summary, payload)) {
		return payload;
	}
	return state.new_dict();
}

DictRef _load_summary_payload_for_restore(State &state, DictRef summary) {
	const DictRef payload = _summary_payload(state, summary);
	if (!gd::is_empty(state, payload)) {
		return payload;
	}
	const Atom path = string_get(state, summary, key::path, key::empty);
	if (path == key::empty || !gd::file_exists(state, path)) {
		return state.new_dict();
	}
	return _load_raw_dictionary(state, path, false);
}

Atom _resume_target_from_payload_summary(State &state, DictRef payload) {
	if (string_get(state, payload, key::scenario_id, key::empty) == key::empty) {
		return key::blocked;
	}
	const Atom scenario_status = session_state_store::_normalize_scenario_status(state,
			state.get(payload, gd::str(key::scenario_status), gd::str(key::in_progress)));
	if (scenario_status != key::in_progress) {
		return key::outcome;
	}
	Value battle;
	if (state.lookup(payload, gd::str(key::battle), battle) && battle.kind == Kind::Dict && !gd::is_empty(state, battle.ref) &&
			string_get(state, payload, key::game_state, key::overworld) == key::battle) {
		return key::battle;
	}
	if (string_get(state, payload, key::game_state, key::overworld) == key::town) {
		return key::town;
	}
	return key::overworld;
}

double _summary_sort_timestamp(State &state, DictRef summary) {
	const double precise_timestamp = gd::float_field(state, summary, key::recorded_timestamp_precise, 0.0);
	if (precise_timestamp > 0.0) {
		return precise_timestamp;
	}
	const int64_t recorded_timestamp = gd::int_field(state, summary, key::recorded_timestamp, 0);
	return static_cast<double>(recorded_timestamp > 0 ? recorded_timestamp : gd::int_field(state, summary, key::modified_timestamp, 0));
}

DictRef _manual_summary_for_session(State &state, const Value &session, int64_t manual_slot) {
	if (no_scenario(state, session)) {
		return state.new_dict();
	}
	const int64_t selected_slot = _normalize_manual_slot(state, manual_slot > 0 ? manual_slot : selected_manual_slot(state));
	DictRef summary = _empty_summary(state, key::manual, gd::stringify(state, gd::int_value(selected_slot)), _slot_path(state, selected_slot));
	summary = _populate_summary_from_payload(state, summary, session_to_dict(state, session));
	put(state, summary, key::payload, gd::dict_value(session_to_dict(state, session)));
	put(state, summary, key::valid, gd::bool_value(true));
	put(state, summary, key::validity, gd::str(key::ok));
	put(state, summary, key::loadable, gd::bool_value(true));
	put(state, summary, key::resume_target, gd::str(_resume_target_for_session(state, session)));
	put(state, summary, key::status_text, gd::str(_status_text_for_summary(state, summary)));
	return summary;
}

Value _session_from_payload(State &state, DictRef payload) {
	if (gd::is_empty(state, payload)) {
		return Value();
	}
	const Value session = session_state_store::new_session_data(state, key::empty, key::empty, key::empty, 1, state.new_dict(), key::normal, key::campaign);
	gd::call_method(state, session, key::from_dict, { gd::dict_value(payload) });
	return session;
}

Atom _summary_progress_recap(State &state, DictRef summary) {
	if (gd::is_empty(state, summary) || !gd::bool_field(state, summary, key::valid, false)) {
		return key::empty;
	}
	const Value session = _session_from_payload(state, _summary_payload(state, summary));
	if (no_scenario(state, session)) {
		return key::empty;
	}
	return progress_recap_of(state, session, true);
}

ArrayRef _summary_continuity_lines(State &state, DictRef summary) {
	if (gd::is_empty(state, summary) || !gd::bool_field(state, summary, key::valid, false)) {
		return state.new_array();
	}
	const Value session = _session_from_payload(state, _summary_payload(state, summary));
	if (no_scenario(state, session)) {
		return state.new_array();
	}

	const ArrayRef lines = state.new_array();
	const Atom action_line = _summary_resume_action_line(state, summary);
	if (action_line != key::empty) {
		state.append(lines, gd::str(action_line));
	}
	const Atom context_line = _summary_campaign_context_line(state, summary);
	if (context_line != key::empty) {
		state.append(lines, gd::str(context_line));
	}
	const Atom objective_line = _summary_objective_line(state, session);
	if (objective_line != key::empty) {
		state.append(lines, gd::str(objective_line));
	}
	const Atom watch_line = _summary_watch_state_line(state, session, summary, false, key::empty, state.new_dict());
	if (watch_line != key::empty) {
		state.append(lines, gd::str(watch_line));
	}
	return lines;
}

ArrayRef _summary_continuity_lines_from_context(State &state, DictRef summary, DictRef recap_context) {
	if (gd::is_empty(state, summary) || !gd::bool_field(state, summary, key::valid, false) || gd::is_empty(state, recap_context)) {
		return state.new_array();
	}
	const ArrayRef lines = state.new_array();
	const Atom action_line = _summary_resume_action_line(state, summary);
	if (action_line != key::empty) {
		state.append(lines, gd::str(action_line));
	}
	const Atom context_line = _summary_campaign_context_line(state, summary);
	if (context_line != key::empty) {
		state.append(lines, gd::str(context_line));
	}
	const Atom objective_line = _summary_objective_line_from_progress_recap(state, string_get(state, recap_context, key::progress_recap, key::empty));
	if (objective_line != key::empty) {
		state.append(lines, gd::str(objective_line));
	}
	const Atom watch_line = string_get(state, recap_context, key::watch_line, key::empty);
	if (watch_line != key::empty) {
		state.append(lines, gd::str(watch_line));
	}
	return lines;
}

Atom _summary_resume_action_line(State &state, DictRef summary) {
	if (!can_load_summary(state, summary)) {
		return key::empty;
	}
	const Atom action = load_action_label(state, summary);
	const Atom target = _resume_context_label(state, summary);
	const Atom resume_target = string_get(state, summary, key::resume_target, key::blocked);
	Atom pattern = key::empty;
	if (resume_target == key::battle) {
		pattern = key::action_s_will_restore_s_before;
	} else if (resume_target == key::town) {
		pattern = key::action_s_will_reopen_s_with;
	} else if (resume_target == key::outcome) {
		pattern = key::action_s_will_reopen_s_and;
	} else if (resume_target == key::overworld) {
		pattern = key::action_s_will_restore_s_with;
	} else {
		return key::empty;
	}
	return gd::format(state, pattern, { gd::str(action), gd::str(target) });
}

Atom _summary_campaign_context_line(State &state, DictRef summary) {
	const Atom mode_label = scenario_select_rules::launch_mode_label(state, string_get(state, summary, key::launch_mode, key::campaign));
	std::vector<Atom> parts{ mode_label };
	const Atom campaign_name = gd::strip_edges(state, string_get(state, summary, key::campaign_name, key::empty));
	const Atom chapter_label = gd::strip_edges(state, string_get(state, summary, key::chapter_label, key::empty));
	if (campaign_name != key::empty) {
		parts.push_back(campaign_name);
	}
	if (chapter_label != key::empty) {
		parts.push_back(chapter_label);
	}
	const int64_t day = gd::int_field(state, summary, key::day, 0);
	if (day > 0) {
		parts.push_back(gd::format(state, key::day_d, { gd::int_value(day) }));
	}
	if (parts.size() <= 1) {
		return key::empty;
	}
	return gd::format(state, key::continuity_s, { gd::str(join(state, key::space_bar_space, parts)) });
}

Atom _summary_objective_line(State &state, const Value &session) {
	const Atom recap = progress_recap_of(state, session, false);
	return _summary_objective_line_from_progress_recap(state, recap);
}

Atom _summary_objective_line_from_progress_recap(State &state, Atom recap) {
	const Atom progress_line = _line_with_prefix(state, recap, key::current_progress);
	const Atom next_step_line = _line_with_prefix(state, recap, key::next_step);
	if (progress_line == key::empty && next_step_line == key::empty) {
		return key::empty;
	}
	std::vector<Atom> parts;
	if (progress_line != key::empty) {
		parts.push_back(trimmed(state, progress_line, key::current_progress));
	}
	if (next_step_line != key::empty) {
		parts.push_back(trimmed(state, next_step_line, key::next_step));
	}
	return gd::format(state, key::current_objective_s, { gd::str(join(state, key::space_bar_space, parts)) });
}

Atom _summary_play_check_state_line(State &state, const Value &session, DictRef summary) {
	if (no_scenario(state, session)) {
		return key::empty;
	}
	const Atom resume_target = string_get(state, summary, key::resume_target, key::overworld);
	if (resume_target == key::battle) {
		const Atom battle_risk = risk_board_of(state, session);
		const Atom outlook = _line_with_prefix(state, battle_risk, key::outlook);
		if (outlook != key::empty) {
			return _safe_player_text(state, gd::format(state, key::battle_s, { gd::str(trimmed(state, outlook, key::outlook)) }), 72);
		}
	} else if (resume_target == key::town) {
		const Atom defense = town_rules::describe_defense(state, gd::object_view(state, session));
		const Atom defense_line = _first_meaningful_line(state, defense, one_line(state, key::Defense));
		if (defense_line != key::empty) {
			return _safe_player_text(state, gd::format(state, key::defense_s, { gd::str(trimmed(state, defense_line, key::text_2)) }), 72);
		}
	} else if (resume_target == key::outcome) {
		const Atom recent_line = _line_with_prefix(state, progress_recap_of(state, session, false), key::recently_resolved);
		if (recent_line != key::empty) {
			return _safe_player_text(state, recent_line, 72);
		}
	}
	const Atom objective_line = trimmed(state, _summary_objective_line(state, session), key::current_objective);
	if (objective_line != key::empty) {
		return _safe_player_text(state, gd::format(state, key::objective_s, { gd::str(objective_line) }), 72);
	}
	const Atom watch_line = trimmed(state, _summary_watch_state_line(state, session, summary, false, key::empty, state.new_dict()), key::risk_watch);
	if (watch_line != key::empty) {
		return _safe_player_text(state, gd::format(state, key::watch_s, { gd::str(watch_line) }), 72);
	}
	return key::empty;
}

Atom _summary_play_check_state_line_from_context(State &state, const Value &session, DictRef summary, DictRef recap_context) {
	if (no_scenario(state, session)) {
		return key::empty;
	}
	const Atom resume_target = string_get(state, summary, key::resume_target, key::overworld);
	const Atom progress_recap = string_get(state, recap_context, key::progress_recap, key::empty);
	const Atom watch_line = string_get(state, recap_context, key::watch_line, key::empty);
	if (resume_target == key::battle) {
		const Atom battle_watch = trimmed(state, watch_line, key::risk_watch);
		if (battle_watch != key::empty && !contains(state, watch_line, key::no_immediate_stored_warning)) {
			return _safe_player_text(state, gd::format(state, key::battle_s, { gd::str(battle_watch) }), 72);
		}
	} else if (resume_target == key::town) {
		const Atom defense = town_rules::describe_defense_headline(state, gd::object_view(state, session));
		const Atom defense_line = _first_meaningful_line(state, defense, one_line(state, key::Defense));
		if (defense_line != key::empty) {
			return _safe_player_text(state, gd::format(state, key::defense_s, { gd::str(trimmed(state, defense_line, key::text_2)) }), 72);
		}
	} else if (resume_target == key::outcome) {
		const Atom recent_line = _line_with_prefix(state, progress_recap, key::recently_resolved);
		if (recent_line != key::empty) {
			return _safe_player_text(state, recent_line, 72);
		}
	}
	const Atom objective_line = trimmed(state, _summary_objective_line_from_progress_recap(state, progress_recap), key::current_objective);
	if (objective_line != key::empty) {
		return _safe_player_text(state, gd::format(state, key::objective_s, { gd::str(objective_line) }), 72);
	}
	if (resume_target == key::battle || resume_target == key::outcome) {
		put(state, recap_context, key::direct_fallback_count, gd::int_value(1));
		return _summary_play_check_state_line(state, session, summary);
	}
	const Atom watch = trimmed(state, watch_line, key::risk_watch);
	if (watch != key::empty) {
		return _safe_player_text(state, gd::format(state, key::watch_s, { gd::str(watch) }), 72);
	}
	return key::empty;
}

Atom _summary_watch_state_line(State &state, const Value &session, DictRef summary, bool trusted_normalized_session, Atom preloaded_progress_recap, DictRef refresh_watch_context) {
	const Atom resume_target = string_get(state, summary, key::resume_target, key::overworld);
	if (resume_target == key::battle) {
		const Atom battle_risk = risk_board_of(state, session);
		const Atom outlook = _line_with_prefix(state, battle_risk, key::outlook);
		if (outlook != key::empty) {
			return gd::format(state, key::risk_watch_s, { gd::str(trimmed(state, outlook, key::outlook)) });
		}
	} else if (resume_target == key::outcome) {
		const Atom recap = preloaded_progress_recap != key::empty ? preloaded_progress_recap : progress_recap_of(state, session, false);
		const Atom recent_line = _line_with_prefix(state, recap, key::recently_resolved);
		if (recent_line != key::empty) {
			return gd::format(state, key::risk_watch_s, { gd::str(trimmed(state, recent_line, key::recently_resolved)) });
		}
	} else {
		Atom risk_line = key::empty;
		Value forecast;
		const bool has_forecast = state.lookup(refresh_watch_context, gd::str(key::command_risk_forecast), forecast) &&
				forecast.kind == Kind::Dict && !gd::is_empty(state, forecast.ref);
		if (has_forecast) {
			if (gd::bool_field(state, forecast.ref, key::has_risk, false)) {
				risk_line = string_get(state, forecast.ref, key::summary, key::empty);
			}
		} else if (trusted_normalized_session) {
			risk_line = overworld_rules::describe_command_risk_summary_from_normalized_session(state, gd::object_view(state, session));
		} else {
			const Atom command_risk = overworld_rules::describe_command_risk(state, gd::object_view(state, session));
			risk_line = _first_meaningful_line(state, command_risk, one_line(state, key::command_risk));
		}
		if (risk_line != key::empty && !gd::begins_with(state, risk_line, key::steady_watch_2)) {
			return gd::format(state, key::risk_watch_s, { gd::str(risk_line) });
		}
		const Atom frontier_watch = overworld_rules::describe_frontier_threats(state, gd::object_view(state, session));
		const Atom frontier_line = _first_meaningful_line(state, frontier_watch, one_line(state, key::frontier_watch));
		if (frontier_line != key::empty && !contains(state, frontier_line, key::no_hostile_factions_are_active)) {
			return gd::format(state, key::risk_watch_s, { gd::str(trimmed(state, frontier_line, key::text_2)) });
		}
		const Atom management_watch = state.has(refresh_watch_context, gd::str(key::management_watch))
				? string_get(state, refresh_watch_context, key::management_watch, key::empty)
				: overworld_rules::describe_management_watch(state, gd::object_view(state, session));
		if (management_watch != key::empty && management_watch != key::town_lines_are_stable) {
			return gd::format(state, key::risk_watch_s, { gd::str(management_watch) });
		}
	}
	return key::risk_watch_no_immediate_stored_warning;
}

Atom _session_next_decision_line(State &state, const Value &session, DictRef summary) {
	const DictRef recap = _preferred_recent_action_recap(state, session, string_get(state, summary, key::resume_target, key::overworld));
	const Atom recap_next = _action_recap_next_step(state, recap);
	if (recap_next != key::empty) {
		return recap_next;
	}
	const Atom progress_next = _line_with_prefix(state, progress_recap_of(state, session, false), key::next_step);
	if (progress_next != key::empty) {
		return _safe_player_text(state, trimmed(state, progress_next, key::next_step), 220);
	}
	const Atom action_line = _summary_resume_action_line(state, summary);
	if (action_line != key::empty) {
		return _safe_player_text(state, trimmed(state, action_line, key::action_2), 220);
	}
	return key::load_the_save_inspect_the_resumed;
}

Atom _fallback_resume_decision(State &state, Atom resume_target) {
	(void)state;
	if (resume_target == key::battle) {
		return key::finish_the_encounter;
	}
	if (resume_target == key::town) {
		return key::make_the_next_town_order;
	}
	if (resume_target == key::outcome) {
		return key::choose_the_follow_up_result_action;
	}
	if (resume_target == key::overworld) {
		return key::choose_the_next_field_route;
	}
	return key::select_a_loadable_save;
}

DictRef _preferred_recent_action_recap(State &state, const Value &session, Atom resume_target) {
	if (session.kind == Kind::Nil) {
		return state.new_dict();
	}
	std::vector<Atom> ordered_keys;
	if (resume_target == key::battle) {
		ordered_keys = { key::last_battle_action_recap, key::last_overworld_action_recap, key::last_town_action_recap };
	} else if (resume_target == key::town) {
		ordered_keys = { key::last_town_action_recap, key::last_overworld_action_recap };
	} else {
		ordered_keys = { key::last_overworld_action_recap, key::last_town_action_recap };
	}
	const DictRef flags = gd::as_dict(gd::index(state, gd::object_view(state, session), gd::str(key::flags)));
	for (const Atom name : ordered_keys) {
		Value value;
		// A missing flag is {}, which normalizes to {}.
		if (!state.lookup(flags, gd::str(name), value)) {
			continue;
		}
		const DictRef recap = _normalize_saved_action_recap(state, value);
		if (!gd::is_empty(state, recap)) {
			return recap;
		}
	}
	return state.new_dict();
}

DictRef _normalize_saved_action_recap(State &state, const Value &value) {
	if (value.kind != Kind::Dict) {
		return state.new_dict();
	}
	const DictRef source = value.ref;
	const Atom happened = _safe_player_text(state, string_get(state, source, key::happened, key::empty), 180);
	const Atom affected = _safe_player_text(state, string_get(state, source, key::affected, key::empty), 180);
	const Atom why = _safe_player_text(state, string_of(state, field_chain(state, source, { key::why_it_matters, key::matters, key::decision })), 180);
	const Atom next_step = _safe_player_text(state, string_of(state, field_chain(state, source, { key::next_step_2, key::next, key::next_actor })), 180);
	if (happened == key::empty && affected == key::empty && why == key::empty && next_step == key::empty) {
		return state.new_dict();
	}
	const DictRef recap = state.new_dict();
	put(state, recap, key::happened, gd::str(happened));
	put(state, recap, key::affected, gd::str(affected));
	put(state, recap, key::why, gd::str(why));
	put(state, recap, key::next_step_2, gd::str(next_step));
	return recap;
}

Atom _action_recap_change_summary(State &state, DictRef recap) {
	if (gd::is_empty(state, recap)) {
		return key::empty;
	}
	std::vector<Atom> parts;
	for (const Atom name : { key::happened, key::affected, key::why }) {
		const Atom text = gd::strip_edges(state, string_get(state, recap, name, key::empty));
		if (text != key::empty && std::find(parts.begin(), parts.end(), text) == parts.end()) {
			parts.push_back(text);
		}
		if (parts.size() >= 2) {
			break;
		}
	}
	return join(state, key::space_bar_space, parts);
}

Atom _action_recap_next_step(State &state, DictRef recap) {
	if (gd::is_empty(state, recap)) {
		return key::empty;
	}
	return gd::strip_edges(state, string_get(state, recap, key::next_step_2, key::empty));
}

} // namespace aurelion::rules::port::save_service
