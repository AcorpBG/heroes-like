// SaveService's file layer: the transactional write (candidate, backup, previous
// generation, commit, rollback), reading and recovering saves, and the campaign
// progression's storage report.

#include "aurelion_rules/port/save_service.hpp"

#include <cstdint>
#include <initializer_list>
#include <string>

namespace aurelion::rules::port {

namespace {

using gd::Atom;
using gd::bool_value;
using gd::dict_value;
using gd::DictRef;
using gd::int_value;
using gd::str;
using state::Kind;
using state::State;
using state::Value;
namespace key = state::key;

// OK, FileAccess.READ and FileAccess.WRITE.
constexpr int64_t kOk = 0;
constexpr int64_t kFileRead = 1;
constexpr int64_t kFileWrite = 2;
// CampaignRules.PROFILE_VERSION and SaveService.PROGRESSION_MIN_SUPPORTED_VERSION.
constexpr int64_t kCampaignProfileVersion = 1;
constexpr int64_t kProgressionMinSupportedVersion = 1;
// SaveService.MANUAL_SLOT_IDS.
constexpr int64_t kManualSlotIds[] = { 1, 2, 3 };

// String(x) of any value.
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

// String(d.get(k, fallback)).
Atom string_at(State &state, DictRef dict, Atom name, Atom fallback) {
	return string_of(state, state.get(dict, str(name), str(fallback)));
}

void print_error_text(State &state, Atom text) {
	state.print_error(state.text(text));
}

// raw.get("payload", {}) if raw.get("payload", {}) is Dictionary else {}.
DictRef payload_or_empty(State &state, DictRef raw) {
	Value payload;
	if (state.lookup(raw, str(key::payload), payload) && gd::is_dict(payload)) {
		return payload.ref;
	}
	return state.new_dict();
}

// {"ok": false, "recovered": false, "live_valid": false, "reason": reason}.
DictRef failed_recovery(State &state, Atom reason) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(false));
	state.set(result, str(key::recovered), bool_value(false));
	state.set(result, str(key::live_valid), bool_value(false));
	state.set(result, str(key::reason), str(reason));
	return result;
}

// {"ok": true, "recovered": recovered, "live_valid": true, "retained_manual_name": name}.
DictRef valid_recovery(State &state, bool recovered, Atom retained_manual_name) {
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(true));
	state.set(result, str(key::recovered), bool_value(recovered));
	state.set(result, str(key::live_valid), bool_value(true));
	state.set(result, str(key::retained_manual_name), str(retained_manual_name));
	return result;
}

// _progression_payload_semantic_report's answers: status, reason, then
// campaign_id and entry_id when given, version and expected_version.
DictRef progression_report(State &state, Atom status, Atom reason, int64_t version, const Atom *campaign_id = nullptr,
		const Atom *entry_id = nullptr) {
	const DictRef report = state.new_dict();
	state.set(report, str(key::status), str(status));
	state.set(report, str(key::reason), str(reason));
	if (campaign_id != nullptr) {
		state.set(report, str(key::campaign_id), str(*campaign_id));
	}
	if (entry_id != nullptr) {
		state.set(report, str(key::entry_id), str(*entry_id));
	}
	state.set(report, str(key::version), int_value(version));
	state.set(report, str(key::expected_version), int_value(kCampaignProfileVersion));
	return report;
}

// s.find(what, from) in bytes (the texts searched for are ASCII, so byte and
// code point positions agree), -1 when missing.
int64_t text_find(const std::string &text, const char *what, size_t from = 0) {
	const size_t found = text.find(what, from);
	return found == std::string::npos ? -1 : static_cast<int64_t>(found);
}

int64_t text_find_char(const std::string &text, char what, int64_t from) {
	const size_t found = text.find(what, static_cast<size_t>(from));
	return found == std::string::npos ? -1 : static_cast<int64_t>(found);
}

// max(s.rfind_char('/'), s.rfind_char('\\')), -1 when neither is there.
int64_t last_separator(const std::string &text) {
	const size_t slash = text.rfind('/');
	const size_t backslash = text.rfind('\\');
	const int64_t a = slash == std::string::npos ? -1 : static_cast<int64_t>(slash);
	const int64_t b = backslash == std::string::npos ? -1 : static_cast<int64_t>(backslash);
	return a > b ? a : b;
}

// s.get_base_dir() (String::get_base_dir).
Atom path_base_dir(State &state, Atom path) {
	const std::string text = state.text(path);
	int64_t end = 0;
	int64_t basepos = text_find(text, "://");
	if (basepos != -1) {
		end = basepos + 3;
	}
	if (end == 0) {
		basepos = text_find(text, ":/");
		if (basepos == -1) {
			basepos = text_find(text, ":\\");
		}
		if (basepos != -1) {
			end = basepos + 2;
		}
	}
	if (end == 0) {
		if (text.rfind("//", 0) == 0 || text.rfind("\\\\", 0) == 0) {
			basepos = text_find_char(text, '/', 2);
			if (basepos == -1) {
				basepos = text_find_char(text, '\\', 2);
			}
			int64_t servpos = text_find_char(text, '/', basepos + 1);
			if (servpos == -1) {
				servpos = text_find_char(text, '\\', basepos + 1);
			}
			if (servpos != -1) {
				end = servpos + 1;
			}
		}
	}
	if (end == 0) {
		if (!text.empty() && text[0] == '/') {
			end = 1;
		}
	}
	std::string rs;
	std::string base;
	if (end != 0) {
		rs = text.substr(static_cast<size_t>(end));
		base = text.substr(0, static_cast<size_t>(end));
	} else {
		rs = text;
	}
	const int64_t sep = last_separator(rs);
	if (sep == -1) {
		return state.intern(base);
	}
	return state.intern(base + rs.substr(0, static_cast<size_t>(sep)));
}

// s.get_file().
Atom path_file(State &state, Atom path) {
	const std::string text = state.text(path);
	const int64_t sep = last_separator(text);
	if (sep == -1) {
		return path;
	}
	return state.intern(text.substr(static_cast<size_t>(sep) + 1));
}

// s.trim_suffix(suffix).
Atom text_trim_suffix(State &state, Atom text, Atom suffix) {
	if (!gd::ends_with(state, text, suffix)) {
		return text;
	}
	const std::string &whole = state.text(text);
	return state.intern(std::string_view(whole).substr(0, whole.size() - state.text(suffix).size()));
}

// FileAccess.open(path, mode): the file object, Nil when the open fails.
Value open_file(State &state, Atom path, int64_t mode) {
	return gd::class_call_static(state, key::FileAccess, key::open, { str(path), int_value(mode) });
}

// ProjectSettings.globalize_path(path).
Value globalize_path(State &state, Atom path) {
	return gd::call_method(state, gd::engine_singleton(state, key::ProjectSettings), key::globalize_path, { str(path) });
}

bool commit_base_unsafe(Atom reason) {
	return reason == key::invalid_live_remove_failed || reason == key::backup_restore_failed
			|| reason == key::backup_restore_verification_failed || reason == key::previous_restore_failed
			|| reason == key::previous_restore_verification_failed || reason == key::future_version;
}

void count_up(State &state, DictRef profile, Atom name) {
	state.set(profile, str(name), int_value(gd::add(gd::int_field(state, profile, name, 0), 1)));
}

} // namespace

namespace save_service {

Atom _save_raw_dictionary(State &state, DictRef payload, Atom file_path, DictRef profile, DictRef prepared_recovery) {
	if (!_ensure_save_dir(state)) {
		return key::empty;
	}
	DictRef recovery = prepared_recovery;
	if (gd::is_empty(state, recovery)) {
		const int64_t recovery_started = profile_begin_usec(state);
		recovery = _recover_save_transaction(state, file_path, false);
		_runtime_save_profile_bucket(state, profile, key::recovery, profile_elapsed_ms(state, recovery_started));
		if (!gd::is_empty(state, profile)) {
			count_up(state, profile, key::recovery_count);
		}
	} else if (!gd::is_empty(state, profile)) {
		state.set(profile, str(key::writer_recovery_reused), bool_value(true));
	}
	if (commit_base_unsafe(string_at(state, recovery, key::reason, key::empty))) {
		print_error_text(state, gd::engine_format(state, key::save_transaction_recovery_could_not_establish, { str(file_path), dict_value(recovery) }));
		return key::empty;
	}

	const int64_t stringify_started = profile_begin_usec(state);
	// The engine's String, as GDScript held it: megabytes no atom copies.
	const Value json_text = gd::class_call_static_engine(state, key::JSON, key::stringify, { dict_value(payload), str(key::empty), bool_value(false) });
	_runtime_save_profile_bucket(state, profile, key::stringify, profile_elapsed_ms(state, stringify_started));
	const Atom candidate_path = _save_transaction_candidate_path(state, file_path);
	const Atom backup_path = _save_transaction_backup_path(state, file_path);
	if (!_remove_save_transaction_artifact(state, candidate_path)) {
		print_error_text(state, gd::format(state, key::unable_to_clear_stale_save_candidate, { str(candidate_path) }));
		return key::empty;
	}

	const int64_t write_started = profile_begin_usec(state);
	const Value file = open_file(state, candidate_path, kFileWrite);
	if (file.kind == Kind::Nil) {
		print_error_text(state, gd::format(state, key::unable_to_open_save_candidate_for, { str(candidate_path) }));
		return key::empty;
	}
	gd::call_method(state, file, key::store_string, { json_text });
	gd::call_method(state, file, key::flush, {});
	const int64_t write_error = gd::to_int(state, gd::call_method(state, file, key::get_error, {}));
	const int64_t written_bytes = gd::to_int(state, gd::call_method(state, file, key::get_length, {}));
	gd::call_method(state, file, key::close, {});
	const int64_t expected_bytes = gd::to_int(state,
			gd::call_method(state, gd::call_method_engine(state, json_text, key::to_utf8_buffer, {}), key::size, {}));
	if (write_error != kOk || written_bytes != expected_bytes) {
		print_error_text(state, gd::format(state, key::save_candidate_write_failed_for_s,
				{ str(candidate_path), int_value(write_error), int_value(written_bytes), int_value(expected_bytes) }));
		_remove_save_transaction_artifact(state, candidate_path);
		return key::empty;
	}
	const DictRef candidate_read = _read_json_dictionary_unrecovered(state, candidate_path, false);
	if (!gd::is_empty(state, profile)) {
		count_up(state, profile, key::verification_parse_count);
	}
	if (!gd::bool_field(state, candidate_read, key::ok, false)
			|| !gd::engine_equal(state, state.get(candidate_read, str(key::text), str(key::empty)), json_text)) {
		print_error_text(state, gd::format(state, key::save_candidate_verification_failed_s, { str(candidate_path) }));
		_remove_save_transaction_artifact(state, candidate_path);
		return key::empty;
	}
	if (gd::os_environment(state, key::HEROES_LIKE_SAVE_FAIL_PHASE) == key::precommit) {
		_remove_save_transaction_artifact(state, candidate_path);
		return key::empty;
	}

	const bool had_live = gd::file_exists(state, file_path);
	if (gd::file_exists(state, backup_path) && !_remove_save_transaction_artifact(state, backup_path)) {
		print_error_text(state, gd::format(state, key::unable_to_clear_stale_save_backup, { str(backup_path) }));
		_remove_save_transaction_artifact(state, candidate_path);
		return key::empty;
	}
	if (had_live) {
		const int64_t backup_error = _rename_save_transaction_path(state, file_path, backup_path);
		if (backup_error != kOk) {
			print_error_text(state, gd::format(state, key::unable_to_preserve_prior_save_s, { str(file_path), int_value(backup_error) }));
			_remove_save_transaction_artifact(state, candidate_path);
			return key::empty;
		}
	}
	if (gd::os_environment(state, key::HEROES_LIKE_SAVE_FAIL_PHASE) == key::after_backup) {
		_rollback_save_transaction(state, file_path, candidate_path, backup_path, had_live);
		return key::empty;
	}

	const int64_t commit_error = _rename_save_transaction_path(state, candidate_path, file_path);
	if (commit_error != kOk) {
		print_error_text(state, gd::format(state, key::unable_to_commit_save_candidate_s, { str(candidate_path), int_value(commit_error) }));
		_rollback_save_transaction(state, file_path, candidate_path, backup_path, had_live);
		return key::empty;
	}
	// The candidate parsed already: a byte-for-byte readback of the renamed file
	// proves it is that JSON without parsing the whole map again.
	const Value committed_file = open_file(state, file_path, kFileRead);
	bool committed_exact = false;
	if (committed_file.kind != Kind::Nil) {
		committed_exact = gd::engine_equal(state, gd::call_method_engine(state, committed_file, key::get_as_text, {}), json_text);
		gd::call_method(state, committed_file, key::close, {});
	}
	if (!gd::is_empty(state, profile)) {
		state.set(profile, str(key::verification_committed_readback_count), int_value(1));
	}
	if (!committed_exact) {
		print_error_text(state, gd::format(state, key::committed_save_verification_failed_s, { str(file_path) }));
		_rollback_save_transaction(state, file_path, candidate_path, backup_path, had_live);
		return key::empty;
	}
	if (had_live) {
		_retain_previous_save_generation(state, file_path, backup_path);
	}
	_runtime_save_profile_bucket(state, profile, key::write, profile_elapsed_ms(state, write_started));
	_invalidate_summary_cache_for_path(state, file_path);
	return file_path;
}

Atom _save_transaction_candidate_path(State &state, Atom file_path) {
	return gd::format(state, key::s_s_5, { str(file_path), str(key::candidate_2) });
}

Atom _save_transaction_backup_path(State &state, Atom file_path) {
	return gd::format(state, key::s_s_5, { str(file_path), str(key::backup) });
}

Atom _save_transaction_previous_path(State &state, Atom file_path) {
	return gd::format(state, key::s_s_5, { str(file_path), str(key::previous) });
}

// The commit is verified, so the backup becomes the previous generation. A
// backup must never outlive its commit: if the rotation fails, drop it.
void _retain_previous_save_generation(State &state, Atom file_path, Atom backup_path) {
	const Atom previous_path = _save_transaction_previous_path(state, file_path);
	if (_remove_save_transaction_artifact(state, previous_path) && _rename_save_transaction_path(state, backup_path, previous_path) == kOk) {
		return;
	}
	_remove_save_transaction_artifact(state, backup_path);
}

DictRef _read_json_dictionary_unrecovered(State &state, Atom file_path, bool include_payload) {
	const bool exists = gd::file_exists(state, file_path);
	const DictRef result = state.new_dict();
	state.set(result, str(key::exists), bool_value(exists));
	state.set(result, str(key::readable), bool_value(false));
	state.set(result, str(key::ok), bool_value(false));
	state.set(result, str(key::text), str(key::empty));
	state.set(result, str(key::payload), dict_value(state.new_dict()));
	state.set(result, str(key::error_line), int_value(0));
	state.set(result, str(key::error_message), str(key::empty));
	if (!exists) {
		return result;
	}
	const Value file = open_file(state, file_path, kFileRead);
	if (file.kind == Kind::Nil) {
		state.set(result, str(key::error_message), str(key::unable_to_open_file_for_reading));
		return result;
	}
	// The engine's String (an opaque value): a save file of megabytes no atom
	// copies.
	const Value text = gd::call_method_engine(state, file, key::get_as_text, {});
	const int64_t read_error = gd::to_int(state, gd::call_method(state, file, key::get_error, {}));
	gd::call_method(state, file, key::close, {});
	state.set(result, str(key::readable), bool_value(read_error == kOk));
	state.set(result, str(key::text), text.kind == Kind::Nil ? str(key::empty) : text);
	if (read_error != kOk) {
		state.set(result, str(key::error_message), str(gd::format(state, key::file_read_failed_with_error_d, { int_value(read_error) })));
		return result;
	}
	const Value parser = gd::class_instantiate(state, key::JSON);
	const int64_t parse_error = gd::to_int(state, gd::call_method(state, parser, key::parse, { state.get(result, str(key::text), str(key::empty)) }));
	if (parse_error != kOk) {
		state.set(result, str(key::error_line), gd::call_method(state, parser, key::get_error_line, {}));
		state.set(result, str(key::error_message), gd::call_method(state, parser, key::get_error_message, {}));
		return result;
	}
	// parser.data, read once: the same Dictionary both times GDScript reads it.
	const Value data = gd::member(state, parser, key::data);
	if (!gd::is_dict(data)) {
		state.set(result, str(key::error_message), str(key::json_root_is_not_a_dictionary));
		return result;
	}
	state.set(result, str(key::ok), bool_value(true));
	if (include_payload) {
		// The parser's result is not shared with anything else: handed over, not copied.
		state.set(result, str(key::payload), data);
	}
	return result;
}

// Callers that go on to read the live file pass include_live_read to reuse the
// parse recovery already did.
DictRef _recover_save_transaction(State &state, Atom file_path, bool include_live_read) {
	const Atom candidate_path = _save_transaction_candidate_path(state, file_path);
	const Atom backup_path = _save_transaction_backup_path(state, file_path);
	const DictRef live = _read_json_dictionary_unrecovered(state, file_path, true);
	if (file_path == _progression_path(state) && gd::bool_field(state, live, key::ok, false)) {
		const DictRef live_payload = payload_or_empty(state, live);
		const DictRef live_report = _progression_payload_semantic_report(state, live_payload);
		if (string_at(state, live_report, key::status, key::empty) == key::future_version) {
			// Future live data wins over every current-version backup; a candidate
			// is staging only.
			_remove_save_transaction_artifact(state, candidate_path);
			const DictRef result = failed_recovery(state, key::future_version);
			state.set(result, str(key::version), int_value(gd::int_field(state, live_report, key::version, -1)));
			return result;
		}
	}
	if (_save_transaction_payload_valid(state, file_path, live)) {
		const DictRef live_payload = payload_or_empty(state, live);
		_remove_save_transaction_artifact(state, candidate_path);
		_remove_save_transaction_artifact(state, backup_path);
		return _with_live_read(state, valid_recovery(state, false, _manual_slot_name_from_payload(state, live_payload)), live, include_live_read);
	}

	const DictRef backup = _read_json_dictionary_unrecovered(state, backup_path, true);
	if (_save_transaction_payload_valid(state, file_path, backup)) {
		if (gd::bool_field(state, live, key::exists, false) && !_remove_save_transaction_artifact(state, file_path)) {
			return failed_recovery(state, key::invalid_live_remove_failed);
		}
		const int64_t restore_error = _rename_save_transaction_path(state, backup_path, file_path);
		if (restore_error != kOk) {
			const DictRef result = failed_recovery(state, key::backup_restore_failed);
			state.set(result, str(key::error), int_value(restore_error));
			return result;
		}
		const DictRef restored = _read_json_dictionary_unrecovered(state, file_path, true);
		if (!_save_transaction_payload_valid(state, file_path, restored)
				|| !gd::engine_equal(state, state.get(restored, str(key::text), str(key::empty)), state.get(backup, str(key::text), str(key::empty)))) {
			return failed_recovery(state, key::backup_restore_verification_failed);
		}
		_remove_save_transaction_artifact(state, candidate_path);
		_invalidate_summary_cache_for_path(state, file_path);
		return _with_live_read(state, valid_recovery(state, true, _manual_slot_name_from_payload(state, payload_or_empty(state, restored))),
				restored, include_live_read);
	}

	// Without a valid backup, a broken live file falls back to the previous
	// generation. A missing live file never does: that is how saves are deleted.
	if (gd::bool_field(state, live, key::exists, false)) {
		const DictRef previous_recovery = _recover_previous_save_generation(state, file_path, include_live_read);
		if (!gd::is_empty(state, previous_recovery)) {
			_remove_save_transaction_artifact(state, candidate_path);
			return previous_recovery;
		}
	}

	// A candidate is never recovery authority: keep malformed live and backup
	// bytes for diagnostics and discard staging only.
	_remove_save_transaction_artifact(state, candidate_path);
	const bool live_exists = gd::bool_field(state, live, key::exists, false);
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(!live_exists));
	state.set(result, str(key::recovered), bool_value(false));
	state.set(result, str(key::live_valid), bool_value(false));
	state.set(result, str(key::reason), str(live_exists ? key::no_valid_backup : key::live_missing));
	return _with_live_read(state, result, live, include_live_read);
}

// Empty when there is no valid previous generation to restore.
DictRef _recover_previous_save_generation(State &state, Atom file_path, bool include_live_read) {
	const Atom previous_path = _save_transaction_previous_path(state, file_path);
	const DictRef previous = _read_json_dictionary_unrecovered(state, previous_path, true);
	if (!_save_transaction_payload_valid(state, file_path, previous)) {
		return state.new_dict();
	}
	if (!_remove_save_transaction_artifact(state, file_path)) {
		return failed_recovery(state, key::invalid_live_remove_failed);
	}
	const int64_t restore_error = _rename_save_transaction_path(state, previous_path, file_path);
	if (restore_error != kOk) {
		const DictRef result = failed_recovery(state, key::previous_restore_failed);
		state.set(result, str(key::error), int_value(restore_error));
		return result;
	}
	const DictRef restored = _read_json_dictionary_unrecovered(state, file_path, true);
	if (!_save_transaction_payload_valid(state, file_path, restored)
			|| !gd::engine_equal(state, state.get(restored, str(key::text), str(key::empty)), state.get(previous, str(key::text), str(key::empty)))) {
		return failed_recovery(state, key::previous_restore_verification_failed);
	}
	_invalidate_summary_cache_for_path(state, file_path);
	return _with_live_read(state, valid_recovery(state, true, _manual_slot_name_from_payload(state, payload_or_empty(state, restored))),
			restored, include_live_read);
}

DictRef _with_live_read(State &state, DictRef recovery, DictRef live_read, bool include_live_read) {
	if (include_live_read) {
		state.set(recovery, str(key::live_read), dict_value(live_read));
	}
	return recovery;
}

bool _save_transaction_payload_valid(State &state, Atom file_path, DictRef raw) {
	if (!gd::bool_field(state, raw, key::ok, false)) {
		return false;
	}
	Value payload_value;
	if (!state.lookup(raw, str(key::payload), payload_value)) {
		payload_value = dict_value(state.new_dict());
	}
	if (!gd::is_dict(payload_value)) {
		return false;
	}
	const DictRef payload = payload_value.ref;
	if (file_path == _progression_path(state)) {
		return string_at(state, _progression_payload_semantic_report(state, payload), key::status, key::empty) == key::current_valid;
	}
	Atom slot_type = key::empty;
	if (file_path == _autosave_path(state)) {
		slot_type = key::autosave;
	} else if (path_base_dir(state, file_path) == key::user_saves && gd::ends_with(state, file_path, key::save_json)) {
		const DictRef identity = save_file_identity(state, text_trim_suffix(state, path_file(state, file_path), key::save_json));
		if (gd::bool_field(state, identity, key::ok, false) && string_at(state, identity, key::path, key::empty) == file_path) {
			slot_type = key::file;
		}
	} else {
		for (const int64_t slot : kManualSlotIds) {
			if (file_path == _slot_path(state, slot)) {
				slot_type = key::manual;
				break;
			}
		}
	}
	if (slot_type == key::empty) {
		return false;
	}
	const Atom recorded_slot_type = string_at(state, payload, key::save_slot_type, key::empty);
	if (recorded_slot_type != key::empty && recorded_slot_type != slot_type) {
		return false;
	}
	return gd::bool_field(state, _payload_structure_report(state, payload, slot_type), key::ok, false);
}

DictRef _progression_payload_semantic_report(State &state, DictRef payload) {
	if (!state.has(payload, str(key::version))) {
		return progression_report(state, key::invalid, key::missing_version, -1);
	}
	const Value version_value = state.get(payload, str(key::version), Value());
	if (!(gd::is_int(version_value) || gd::is_float(version_value))) {
		return progression_report(state, key::invalid, key::version_wrong_type, -1);
	}
	const double version_number = gd::to_float(version_value);
	const int64_t version = compat::float_to_int(version_number);
	if (version_number != static_cast<double>(version)) {
		return progression_report(state, key::invalid, key::version_not_integer, -1);
	}
	if (version > kCampaignProfileVersion) {
		return progression_report(state, key::future_version, key::future_version, version);
	}
	if (version < kProgressionMinSupportedVersion) {
		return progression_report(state, key::invalid, key::unsupported_version, version);
	}
	if (version < kCampaignProfileVersion) {
		// Older profiles are upgraded, never blocked, and held to the same checks.
		const DictRef migrated_report = _progression_payload_semantic_report(state, _migrate_progression_payload(state, payload, version));
		state.set(migrated_report, str(key::version), int_value(version));
		state.set(migrated_report, str(key::migrated_from_version), int_value(version));
		return migrated_report;
	}
	for (const Atom string_key : { key::last_campaign_id, key::last_scenario_id }) {
		if (!state.has(payload, str(string_key))) {
			return progression_report(state, key::invalid, gd::format(state, key::missing_s_2, { str(string_key) }), version);
		}
		if (!gd::is_string(state.get(payload, str(string_key), Value()))) {
			return progression_report(state, key::invalid, gd::format(state, key::s_wrong_type, { str(string_key) }), version);
		}
	}
	if (!state.has(payload, str(key::campaign_states))) {
		return progression_report(state, key::invalid, key::missing_campaign_states, version);
	}
	if (!gd::is_dict(state.get(payload, str(key::campaign_states), Value()))) {
		return progression_report(state, key::invalid, key::campaign_states_wrong_type, version);
	}
	const DictRef campaign_states = gd::as_dict(state.get(payload, str(key::campaign_states), Value()));
	const gd::ArrayRef campaign_ids = gd::keys(state, campaign_states);
	for (int64_t index = 0; index < state.array_size(campaign_ids); ++index) {
		const Value campaign_id_value = state.at(campaign_ids, index);
		const Atom campaign_id = string_of(state, campaign_id_value);
		const Value state_value = state.get(campaign_states, campaign_id_value, Value());
		if (!gd::is_dict(state_value)) {
			return progression_report(state, key::invalid, key::campaign_state_wrong_type, version, &campaign_id);
		}
		const DictRef campaign_state = state_value.ref;
		for (const Atom state_id_key : { key::last_selected_scenario_id, key::last_completed_scenario_id }) {
			if (state.has(campaign_state, str(state_id_key)) && !gd::is_string(state.get(campaign_state, str(state_id_key), Value()))) {
				return progression_report(state, key::invalid, gd::format(state, key::s_wrong_type, { str(state_id_key) }), version, &campaign_id);
			}
		}
		for (const Atom collection_key : { key::scenario_records, key::carryover_bundles }) {
			if (!state.has(campaign_state, str(collection_key))) {
				continue;
			}
			if (!gd::is_dict(state.get(campaign_state, str(collection_key), Value()))) {
				return progression_report(state, key::invalid, gd::format(state, key::s_wrong_type, { str(collection_key) }), version, &campaign_id);
			}
			const DictRef collection = gd::as_dict(state.get(campaign_state, str(collection_key), Value()));
			const gd::ArrayRef entry_ids = gd::keys(state, collection);
			for (int64_t entry = 0; entry < state.array_size(entry_ids); ++entry) {
				const Value entry_id = state.at(entry_ids, entry);
				if (!gd::is_dict(state.get(collection, entry_id, Value()))) {
					const Atom reason = gd::format(state, key::s_entry_wrong_type, { str(collection_key) });
					const Atom entry_text = string_of(state, entry_id);
					return progression_report(state, key::invalid, reason, version, &campaign_id, &entry_text);
				}
			}
		}
	}
	return progression_report(state, key::current_valid, key::current_valid, version);
}

DictRef _migrate_progression_payload(State &state, DictRef payload, int64_t from_version) {
	DictRef migrated = gd::as_dict(gd::engine_duplicate(state, dict_value(payload), true));
	for (int64_t version = from_version; version < kCampaignProfileVersion; ++version) {
		migrated = _migrate_progression_payload_step(state, migrated, version);
		state.set(migrated, str(key::version), int_value(version + 1));
	}
	return migrated;
}

// A CampaignRules.PROFILE_VERSION bump that changes the stored shape converts
// `_from_version` data to the next version here; bumps that only add optional
// fields need no step.
DictRef _migrate_progression_payload_step(State &state, DictRef payload, int64_t _from_version) {
	(void)state;
	(void)_from_version;
	return payload;
}

DictRef _current_progression_payload(State &state, DictRef payload, DictRef semantic_report) {
	if (state.has(semantic_report, str(key::migrated_from_version))) {
		return _migrate_progression_payload(state, payload, gd::int_field(state, semantic_report, key::migrated_from_version, 0));
	}
	return gd::as_dict(gd::engine_duplicate(state, dict_value(payload), true));
}

DictRef _progression_storage_result(State &state, Atom status, Atom path, DictRef raw, DictRef semantic_report, DictRef recovery) {
	Atom normalized_status = status;
	if (!(normalized_status == key::missing || normalized_status == key::current_valid || normalized_status == key::recovered
				|| normalized_status == key::invalid || normalized_status == key::future_version)) {
		normalized_status = key::invalid;
	}
	const bool accepted = normalized_status == key::missing || normalized_status == key::current_valid || normalized_status == key::recovered;
	const bool usable = normalized_status == key::current_valid || normalized_status == key::recovered;
	Atom message = key::campaign_progress_is_unreadable_or_incomplete;
	if (normalized_status == key::missing) {
		message = key::no_campaign_progress_file_exists_yet;
	} else if (normalized_status == key::current_valid) {
		message = key::campaign_progress_storage_is_current_and;
	} else if (normalized_status == key::recovered) {
		message = key::campaign_progress_was_recovered_from_the;
	} else if (normalized_status == key::future_version) {
		message = key::campaign_progress_was_written_by_a;
	}
	const DictRef result = state.new_dict();
	state.set(result, str(key::ok), bool_value(accepted));
	state.set(result, str(key::status), str(normalized_status));
	state.set(result, str(key::path), str(path));
	state.set(result, str(key::exists), bool_value(gd::bool_field(state, raw, key::exists, false)));
	state.set(result, str(key::usable), bool_value(usable));
	state.set(result, str(key::writable), bool_value(accepted));
	state.set(result, str(key::recovered), bool_value(normalized_status == key::recovered));
	state.set(result, str(key::version), int_value(gd::int_field(state, semantic_report, key::version, -1)));
	state.set(result, str(key::expected_version), int_value(kCampaignProfileVersion));
	state.set(result, str(key::reason), str(string_at(state, semantic_report, key::reason, normalized_status)));
	state.set(result, str(key::recovery_reason), str(string_at(state, recovery, key::reason, key::empty)));
	state.set(result, str(key::message), str(message));
	return result;
}

bool _rollback_save_transaction(State &state, Atom file_path, Atom candidate_path, Atom backup_path, bool had_live) {
	bool rolled_back = true;
	if (gd::file_exists(state, file_path)) {
		rolled_back = _remove_save_transaction_artifact(state, file_path) && rolled_back;
	}
	if (had_live && gd::file_exists(state, backup_path)) {
		const int64_t restore_error = _rename_save_transaction_path(state, backup_path, file_path);
		rolled_back = restore_error == kOk && rolled_back;
	} else if (!had_live) {
		_remove_save_transaction_artifact(state, backup_path);
	}
	_remove_save_transaction_artifact(state, candidate_path);
	return rolled_back;
}

bool _remove_save_transaction_artifact(State &state, Atom file_path) {
	if (!gd::file_exists(state, file_path)) {
		return true;
	}
	return gd::to_int(state, gd::class_call_static(state, key::DirAccess, key::remove_absolute, { globalize_path(state, file_path) })) == kOk;
}

int64_t _rename_save_transaction_path(State &state, Atom from_path, Atom to_path) {
	const Value from = globalize_path(state, from_path);
	const Value to = globalize_path(state, to_path);
	return gd::to_int(state, gd::class_call_static(state, key::DirAccess, key::rename_absolute, { from, to }));
}

DictRef _load_raw_dictionary(State &state, Atom file_path, bool warn_if_missing) {
	const DictRef recovery = _recover_save_transaction(state, file_path, true);
	return _payload_from_raw_read(state, _recovered_live_read(state, recovery, file_path), file_path, warn_if_missing);
}

// Recovery already parsed the live file; reuse that read instead of parsing again.
DictRef _recovered_live_read(State &state, DictRef recovery, Atom file_path) {
	Value live_read;
	if (state.lookup(recovery, str(key::live_read), live_read) && gd::is_dict(live_read) && !gd::is_empty(state, live_read.ref)) {
		return live_read.ref;
	}
	return _read_json_dictionary_unrecovered(state, file_path, true);
}

DictRef _payload_from_raw_read(State &state, DictRef raw, Atom file_path, bool warn_if_missing) {
	if (!gd::bool_field(state, raw, key::exists, false)) {
		if (warn_if_missing) {
			gd::push_warning(state, state.text(gd::format(state, key::missing_save_file_s, { str(file_path) })));
		}
		return state.new_dict();
	}
	if (!gd::bool_field(state, raw, key::readable, false)) {
		print_error_text(state, gd::format(state, key::unable_to_read_save_file_s, { str(file_path) }));
		return state.new_dict();
	}
	if (!gd::bool_field(state, raw, key::ok, false)) {
		const int64_t error_line = gd::int_field(state, raw, key::error_line, 0);
		const Atom error_message = string_at(state, raw, key::error_message, key::invalid_json_dictionary);
		print_error_text(state, gd::format(state, key::invalid_save_json_in_s_at, { str(file_path), int_value(error_line), str(error_message) }));
		return state.new_dict();
	}
	// A fresh parse is owned by the caller; no copy is needed.
	Value payload;
	if (!state.lookup(raw, str(key::payload), payload)) {
		return state.new_dict();
	}
	return gd::as_dict(payload);
}

} // namespace save_service

} // namespace aurelion::rules::port
