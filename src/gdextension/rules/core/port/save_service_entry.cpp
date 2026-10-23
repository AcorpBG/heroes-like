// SaveService.gd's entry points: named save files, the validation hooks, saving
// and loading sessions, slot names, deleting, and the campaign progression.

#include "aurelion_rules/port/save_service.hpp"

#include "aurelion_rules/port/session_state_store.hpp"

#include <algorithm>
#include <cstdint>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

namespace aurelion::rules::port {

namespace {

using gd::ArrayRef;
using gd::Atom;
using gd::DictRef;
using gd::PackedRef;
using state::Kind;
using state::State;
using state::Value;
namespace key = state::key;

// SaveService's constants: SAVE_DIR is key::user_saves, SLOT_TYPE_MANUAL,
// _FILE and _AUTOSAVE key::manual, key::file and key::autosave,
// NAMED_SAVE_SUFFIX key::save_json, the transaction suffixes key::candidate_2,
// key::backup and key::previous; MANUAL_SLOT_IDS is [1, 2, 3].
constexpr int64_t kFirstManualSlot = 1;
constexpr int64_t kOk = 0;
constexpr int64_t kFailed = 1;

Value service(State &state) {
	return gd::autoload(state, key::SaveService);
}

void put(State &state, DictRef dict, Atom name, const Value &value) {
	state.set(dict, gd::str(name), value);
}

// {"name": value, ...}: the values are evaluated first, in order, as the
// literal's are.
DictRef dict_of(State &state, std::initializer_list<std::pair<Atom, Value>> fields) {
	const DictRef dict = state.new_dict();
	for (const auto &field : fields) {
		put(state, dict, field.first, field.second);
	}
	return dict;
}

// String(value): stringify's kinds natively, a float or a container as the
// engine prints it.
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
Atom text_field(State &state, DictRef dict, Atom name, Atom fallback) {
	return string_of(state, state.get(dict, gd::str(name), gd::str(fallback)));
}

// String(d.name): a missing key is an error, as named access is.
Atom named_text(State &state, DictRef dict, Atom name) {
	return string_of(state, gd::index(state, dict, gd::str(name)));
}

// var x: Dictionary = d.get(name, {}) if d.get(name, {}) is Dictionary else {}
DictRef dict_field_or_new(State &state, DictRef dict, Atom name) {
	Value found;
	if (state.lookup(dict, gd::str(name), found) && found.kind == Kind::Dict) {
		return found.ref;
	}
	return state.new_dict();
}

// d.get(name, {}) is Dictionary.
bool dict_or_missing(State &state, DictRef dict, Atom name) {
	Value found;
	return !state.lookup(dict, gd::str(name), found) || found.kind == Kind::Dict;
}

// d.clear(): every key erased.
void clear_dict(State &state, DictRef dict) {
	const ArrayRef keys = gd::keys(state, dict);
	for (const Value &held : gd::items(state, gd::array_value(keys))) {
		state.erase(dict, held);
	}
}

// s.trim_suffix(suffix).
Atom trim_suffix(State &state, Atom text, Atom suffix) {
	if (!gd::ends_with(state, text, suffix)) {
		return text;
	}
	const std::string whole = state.text(text);
	return state.intern(whole.substr(0, whole.size() - state.text(suffix).size()));
}

// base.path_join(file) (String::path_join).
Atom path_join(State &state, Atom base, Atom file) {
	const std::string head = state.text(base);
	const std::string tail = state.text(file);
	if (head.empty()) {
		return file;
	}
	if (head.back() == '/' || (!tail.empty() && tail.front() == '/')) {
		return state.intern(head + tail);
	}
	return state.intern(head + "/" + tail);
}

Atom concat(State &state, Atom a, Atom b) {
	return state.intern(state.text(a) + state.text(b));
}

// The characters of a String (its UTF-8 code points), as length(),
// unicode_at() and s[i] count them.
std::vector<uint32_t> code_points(const std::string &text) {
	std::vector<uint32_t> out;
	out.reserve(text.size());
	size_t index = 0;
	while (index < text.size()) {
		const unsigned char lead = static_cast<unsigned char>(text[index]);
		uint32_t code = lead;
		size_t count = 1;
		if (lead >= 0xF0) {
			code = lead & 0x07u;
			count = 4;
		} else if (lead >= 0xE0) {
			code = lead & 0x0Fu;
			count = 3;
		} else if (lead >= 0xC0) {
			code = lead & 0x1Fu;
			count = 2;
		}
		for (size_t next = 1; next < count && index + next < text.size(); ++next) {
			code = (code << 6) | (static_cast<unsigned char>(text[index + next]) & 0x3Fu);
		}
		out.push_back(code);
		index += count;
	}
	return out;
}

uint32_t ascii_lower(uint32_t c) {
	return c >= 'A' && c <= 'Z' ? c - 'A' + 'a' : c;
}

// text.to_lower() by the engine (String::to_lower and its Unicode case
// tables): an Expression, parsed once per caller into expression.
Atom engine_to_lower(State &state, Atom text, Value &expression) {
	if (expression.kind == Kind::Nil) {
		expression = gd::class_instantiate(state, key::Expression);
		const PackedRef names = gd::new_strings(state);
		gd::packed_append_string(state, names, key::text);
		gd::call_method(state, expression, key::parse, { gd::str(key::text_to_lower), gd::strings_value(names) });
	}
	const ArrayRef inputs = state.new_array();
	state.append(inputs, gd::str(text));
	return gd::to_string(gd::call_method(state, expression, key::execute, { gd::array_value(inputs) }));
}

// a.to_lower() == b.to_lower(). String::to_lower maps each character to one,
// so texts of different lengths differ and ASCII letters decide here; a pair
// of different characters outside ASCII needs the engine's case tables.
bool lower_equal(State &state, Atom a, Atom b, Value &expression) {
	if (a == b) {
		return true;
	}
	const std::vector<uint32_t> left = code_points(state.text(a));
	const std::vector<uint32_t> right = code_points(state.text(b));
	if (left.size() != right.size()) {
		return false;
	}
	bool needs_engine = false;
	for (size_t index = 0; index < left.size(); ++index) {
		const uint32_t x = left[index];
		const uint32_t y = right[index];
		if (x == y) {
			continue;
		}
		if (x < 0x80 && y < 0x80) {
			if (ascii_lower(x) != ascii_lower(y)) {
				return false;
			}
			continue;
		}
		needs_engine = true;
	}
	if (!needs_engine) {
		return true;
	}
	const Atom lower_a = engine_to_lower(state, a, expression);
	return lower_a == engine_to_lower(state, b, expression);
}

// name.get_slice(".", 0).strip_edges().to_upper() with the superscripts
// U+00B9, U+00B2 and U+00B3 replaced by "1", "2" and "3", in the Windows
// device names. Outside ASCII, to_upper() gives an ASCII letter only for
// U+0131 ("I") and U+017F ("S"), which no device name has, so a text with any
// other character outside ASCII but those superscripts is none of them.
bool is_reserved_device(const std::string &name) {
	std::string device = name.substr(0, name.find('.'));
	size_t begin = 0;
	size_t end = device.size();
	while (begin < end && static_cast<unsigned char>(device[begin]) <= 32) {
		++begin;
	}
	while (end > begin && static_cast<unsigned char>(device[end - 1]) <= 32) {
		--end;
	}
	device = device.substr(begin, end - begin);
	std::string upper;
	for (size_t index = 0; index < device.size(); ++index) {
		const unsigned char c = static_cast<unsigned char>(device[index]);
		if (c < 0x80) {
			upper += static_cast<char>(c >= 'a' && c <= 'z' ? c - 'a' + 'A' : c);
			continue;
		}
		const unsigned char next = index + 1 < device.size() ? static_cast<unsigned char>(device[index + 1]) : 0;
		if (c == 0xC2 && (next == 0xB9 || next == 0xB2 || next == 0xB3)) {
			upper += next == 0xB9 ? '1' : (next == 0xB2 ? '2' : '3');
			++index;
			continue;
		}
		return false;
	}
	static const char *const kDevices[] = { "CON", "PRN", "AUX", "NUL", "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7",
		"COM8", "COM9", "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9" };
	for (const char *reserved : kDevices) {
		if (upper == reserved) {
			return true;
		}
	}
	return false;
}

DictRef failure(State &state, Atom message) {
	return dict_of(state, { { key::ok, gd::bool_value(false) }, { key::message, gd::str(message) } });
}

Value profile_log(State &state, Atom function, std::initializer_list<Value> args) {
	return gd::call_static(state, key::profile_log_script, function, args);
}

} // namespace

namespace save_service {

DictRef save_file_identity(State &state, Atom requested_name) {
	const DictRef validated = _validated_save_file_name(state, requested_name);
	if (!gd::bool_field(state, validated, key::ok, false)) {
		return validated;
	}
	const Value directory = gd::class_call_static(state, key::DirAccess, key::open, { gd::str(key::user_saves) });
	const Atom name = named_text(state, validated, key::name);
	const PackedRef entries = directory.kind != Kind::Nil ? gd::as_strings(gd::call_method(state, directory, key::get_files, {}))
															: gd::new_strings(state);
	return _save_file_identity_in_directory(state, name, directory, entries);
}

DictRef _validated_save_file_name(State &state, Atom requested_name) {
	const Atom name = gd::strip_edges(state, requested_name);
	const std::string text = state.text(name);
	const std::vector<uint32_t> characters = code_points(text);
	if (text.empty() || characters.size() > 64 || text.size() > 200 || text.front() == '.' || text.back() == '.') {
		return failure(state, key::use_a_save_name_of_1);
	}
	constexpr std::string_view kForbidden = "<>:\"/\\|?*";
	for (const uint32_t c : characters) {
		if (c < 32 || c == 127 || (c < 0x80 && kForbidden.find(static_cast<char>(c)) != std::string_view::npos)) {
			return failure(state, key::save_names_cannot_contain_control_characters_2);
		}
	}
	if (is_reserved_device(text)) {
		return failure(state, key::that_name_is_reserved_by_windows);
	}
	return dict_of(state, { { key::ok, gd::bool_value(true) }, { key::name, gd::str(name) } });
}

DictRef _save_file_identity_in_directory(State &state, Atom validated_name, const Value &directory, PackedRef entries) {
	Atom name = validated_name;
	Atom filename = concat(state, name, key::save_json);
	if (directory.kind != Kind::Nil) {
		// Windows identities are case-insensitive. Apply the same rule on Linux,
		// including interrupted transactions, so a save cannot fork by casing.
		Value expression;
		const int64_t count = gd::packed_size(state, entries);
		for (int64_t index = 0; index < count; ++index) {
			const Atom entry = gd::packed_string(state, entries, index);
			const Atom base = trim_suffix(state, trim_suffix(state, entry, key::candidate_2), key::backup);
			if (lower_equal(state, base, filename, expression)) {
				filename = base;
				name = trim_suffix(state, filename, key::save_json);
				break;
			}
		}
		for (const Atom suffix : { key::empty, key::candidate_2, key::backup, key::previous }) {
			const Value linked = gd::call_method(state, directory, key::is_link, { gd::str(concat(state, filename, suffix)) });
			if (gd::truthy(state, linked)) {
				return failure(state, key::linked_save_files_are_not_supported);
			}
		}
	}
	return dict_of(state, { { key::ok, gd::bool_value(true) }, { key::slot_type, gd::str(key::file) }, { key::slot_id, gd::str(name) },
								  { key::name, gd::str(name) }, { key::path, gd::str(path_join(state, key::user_saves, filename)) } });
}

DictRef inspect_save_file(State &state, Atom name) {
	const DictRef identity = save_file_identity(state, name);
	if (!gd::bool_field(state, identity, key::ok, false)) {
		return state.new_dict();
	}
	const Atom slot_id = named_text(state, identity, key::name);
	const Atom path = named_text(state, identity, key::path);
	return _inspect_slot(state, key::file, slot_id, path);
}

DictRef _inspect_listed_save_file(State &state, Atom name, const Value &directory, PackedRef entries) {
	DictRef identity = _validated_save_file_name(state, name);
	if (gd::bool_field(state, identity, key::ok, false)) {
		identity = _save_file_identity_in_directory(state, named_text(state, identity, key::name), directory, entries);
	}
	if (!gd::bool_field(state, identity, key::ok, false)) {
		return state.new_dict();
	}
	const Atom slot_id = named_text(state, identity, key::name);
	const Atom path = named_text(state, identity, key::path);
	return _inspect_slot(state, key::file, slot_id, path);
}

ArrayRef list_save_files(State &state) {
	// names: a Dictionary used as a set, in insertion order.
	std::vector<Atom> names;
	const Value directory = gd::class_call_static(state, key::DirAccess, key::open, { gd::str(key::user_saves) });
	if (directory.kind == Kind::Nil) {
		return state.new_array();
	}
	const PackedRef entries = gd::as_strings(gd::call_method(state, directory, key::get_files, {}));
	const int64_t count = gd::packed_size(state, entries);
	for (int64_t index = 0; index < count; ++index) {
		const Atom filename = gd::packed_string(state, entries, index);
		const Atom base = trim_suffix(state, trim_suffix(state, filename, key::candidate_2), key::backup);
		if (gd::ends_with(state, base, key::save_json)) {
			const Atom name = trim_suffix(state, base, key::save_json);
			if (std::find(names.begin(), names.end(), name) == names.end()) {
				names.push_back(name);
			}
		}
	}
	const ArrayRef summaries = state.new_array();
	for (const Atom name : names) {
		const DictRef summary = _inspect_listed_save_file(state, name, directory, entries);
		if (!gd::is_empty(state, summary) && gd::file_exists(state, text_field(state, summary, key::path, key::empty))) {
			state.append(summaries, gd::dict_value(summary));
		}
	}
	gd::sort_custom(state, summaries, [&state](const Value &a, const Value &b) {
		return summary_recency_timestamp(state, gd::as_dict(a)) > summary_recency_timestamp(state, gd::as_dict(b));
	});
	return summaries;
}

DictRef build_file_save_action(State &state, Atom name) {
	const DictRef identity = save_file_identity(state, name);
	if (!gd::bool_field(state, identity, key::ok, false)) {
		return identity;
	}
	const DictRef summary = inspect_save_file(state, named_text(state, identity, key::name));
	const bool occupied = gd::file_exists(state, named_text(state, identity, key::path));
	put(state, identity, key::requires_confirmation, gd::bool_value(occupied));
	const Value expected = occupied ? gd::class_call_static(state, key::FileAccess, key::get_sha256, { gd::str(named_text(state, identity, key::path)) })
									: gd::str(key::empty);
	put(state, identity, key::expected_sha256, expected);
	put(state, identity, key::summary, gd::dict_value(summary));
	return identity;
}

DictRef save_runtime_file_session(State &state, const Value &session, Atom name, bool overwrite, Atom expected_sha256) {
	const DictRef action = build_file_save_action(state, name);
	if (!gd::bool_field(state, action, key::ok, false)) {
		return action;
	}
	if (gd::to_bool(gd::index(state, action, gd::str(key::requires_confirmation))) &&
			(!overwrite || expected_sha256 == key::empty || expected_sha256 != named_text(state, action, key::expected_sha256))) {
		return failure(state, key::this_file_already_exists_or_changed);
	}
	return _save_runtime_session(state, session, key::file, 1, true, named_text(state, action, key::name), false);
}

void validation_begin_summary_inspection_trace(State &state) {
	const Value self = service(state);
	gd::set_member(state, self, key::_summary_inspection_trace_enabled, gd::bool_value(true));
	const DictRef counts = dict_of(state, { { key::inspect_manual_slot, gd::int_value(0) }, { key::inspect_autosave, gd::int_value(0) },
												  { key::list_session_summaries, gd::int_value(0) }, { key::latest_loadable_summary, gd::int_value(0) },
												  { key::slot_file_inspections, gd::int_value(0) } });
	gd::set_member(state, self, key::_summary_inspection_trace_counts, gd::dict_value(counts));
}

DictRef validation_summary_inspection_trace_snapshot(State &state) {
	const Value counts = gd::member(state, service(state), key::_summary_inspection_trace_counts);
	return gd::as_dict(gd::engine_duplicate(state, counts, true));
}

DictRef validation_end_summary_inspection_trace(State &state) {
	const DictRef snapshot = validation_summary_inspection_trace_snapshot(state);
	gd::set_member(state, service(state), key::_summary_inspection_trace_enabled, gd::bool_value(false));
	return snapshot;
}

DictRef validation_last_runtime_save_profile(State &state) {
	const Value profile = gd::member(state, service(state), key::_last_runtime_save_profile);
	return gd::as_dict(gd::engine_duplicate(state, profile, true));
}

DictRef validation_summary_cache_snapshot(State &state) {
	const Value cache = gd::member(state, service(state), key::_slot_summary_cache);
	return gd::as_dict(gd::engine_duplicate(state, cache, true));
}

void validation_clear_summary_cache(State &state) {
	const Value self = service(state);
	clear_dict(state, gd::as_dict(gd::member(state, self, key::_slot_summary_cache)));
	clear_dict(state, gd::as_dict(gd::member(state, self, key::_verified_save_receipts)));
	_invalidate_latest_loadable_summary(state);
}

DictRef validation_transaction_artifact_paths(State &state, Atom file_path) {
	return dict_of(state, { { key::candidate, gd::str(_save_transaction_candidate_path(state, file_path)) },
								  { key::backup_2, gd::str(_save_transaction_backup_path(state, file_path)) },
								  { key::previous_2, gd::str(_save_transaction_previous_path(state, file_path)) } });
}

DictRef validation_clear_general_profile_log(State &state) {
	return gd::as_dict(profile_log(state, key::clear_general_log, {}));
}

DictRef validation_general_profile_log_snapshot(State &state) {
	return gd::as_dict(profile_log(state, key::general_log_snapshot, {}));
}

ArrayRef validation_general_profile_log_last_records(State &state, int64_t limit) {
	return gd::as_array(profile_log(state, key::last_general_records, { gd::int_value(limit) }));
}

void _trace_summary_inspection(State &state, Atom name) {
	const Value self = service(state);
	if (!gd::to_bool(gd::member(state, self, key::_summary_inspection_trace_enabled))) {
		return;
	}
	const DictRef counts = gd::as_dict(gd::member(state, self, key::_summary_inspection_trace_counts));
	put(state, counts, name, gd::int_value(gd::add(gd::int_field(state, counts, name, 0), 1)));
}

Atom save_session(State &state, DictRef payload, int64_t slot) {
	return save_manual_session(state, payload, slot);
}

DictRef save_runtime_manual_session(State &state, const Value &session, int64_t slot) {
	return _save_runtime_session(state, session, key::manual, slot, true, key::empty, false);
}

// cache_summary stores the written save's summary for later inspections even
// when the result does not include it.
DictRef save_runtime_autosave_session(State &state, const Value &session, bool include_summary, bool cache_summary) {
	return _save_runtime_session(state, session, key::autosave, 1, include_summary, key::empty, cache_summary);
}

Atom save_manual_session(State &state, DictRef payload, int64_t slot) {
	if (gd::is_empty(state, payload)) {
		gd::push_warning(state, "Refusing to save an empty session payload.");
		return key::empty;
	}
	const DictRef normalized = session_state_store::normalize_payload(state, gd::dict_value(payload));
	if (text_field(state, normalized, key::scenario_id, key::empty) == key::empty) {
		gd::push_warning(state, "Refusing to save a session without a scenario id.");
		return key::empty;
	}
	const int64_t normalized_slot = _normalize_manual_slot(state, slot);
	const Atom slot_path = _slot_path(state, normalized_slot);
	const Atom path = _save_payload(state, normalized, slot_path, key::manual, state.new_dict(), state.new_dict(), false);
	if (path != key::empty) {
		gd::set_member(state, service(state), key::_selected_manual_slot, gd::int_value(normalized_slot));
	}
	return path;
}

Atom save_autosave_session(State &state, DictRef payload) {
	if (gd::is_empty(state, payload)) {
		gd::push_warning(state, "Refusing to save an empty autosave payload.");
		return key::empty;
	}
	const DictRef normalized = session_state_store::normalize_payload(state, gd::dict_value(payload));
	if (text_field(state, normalized, key::scenario_id, key::empty) == key::empty) {
		gd::push_warning(state, "Refusing to save an autosave without a scenario id.");
		return key::empty;
	}
	const Atom autosave_path = _autosave_path(state);
	return _save_payload(state, normalized, autosave_path, key::autosave, state.new_dict(), state.new_dict(), false);
}

DictRef load_session(State &state, int64_t slot) {
	// Callers own the returned payload; the summary's copy stays with the cache.
	const DictRef payload = _load_summary_payload_for_restore(state, inspect_manual_slot(state, slot));
	return _loaded_session_payload(state, gd::as_dict(gd::engine_duplicate(state, gd::dict_value(payload), true)));
}

DictRef load_autosave(State &state) {
	const DictRef payload = _load_summary_payload_for_restore(state, inspect_autosave(state));
	return _loaded_session_payload(state, gd::as_dict(gd::engine_duplicate(state, gd::dict_value(payload), true)));
}

// Stored payloads hold a native runtime scenario record once; return it under
// flags too, as restoring a session does.
DictRef _loaded_session_payload(State &state, DictRef payload) {
	if (dict_or_missing(state, payload, key::overworld) && dict_or_missing(state, payload, key::flags)) {
		const DictRef overworld = gd::as_dict(gd::index(state, payload, gd::str(key::overworld)));
		const DictRef flags = gd::as_dict(gd::index(state, payload, gd::str(key::flags)));
		session_state_store::share_runtime_scenario_record(state, overworld, flags);
	}
	return payload;
}

Value restore_manual_session(State &state, int64_t slot) {
	return restore_session_from_summary(state, inspect_manual_slot(state, slot));
}

Value restore_autosave_session(State &state) {
	return restore_session_from_summary(state, inspect_autosave(state));
}

Value restore_session_from_summary(State &state, DictRef summary) {
	const DictRef live_summary = refresh_summary(state, summary);
	if (!can_load_summary(state, live_summary)) {
		return Value();
	}
	const DictRef payload = _load_summary_payload_for_restore(state, live_summary);
	if (gd::is_empty(state, payload)) {
		return Value();
	}
	const DictRef restore_result = _normalize_restore_result(state, payload, text_field(state, live_summary, key::slot_type, key::empty));
	if (!gd::bool_field(state, restore_result, key::ok, false)) {
		return Value();
	}
	return state.get(restore_result, gd::str(key::session), Value());
}

DictRef refresh_summary(State &state, DictRef summary) {
	if (gd::is_empty(state, summary)) {
		return state.new_dict();
	}
	const Atom slot_type = text_field(state, summary, key::slot_type, key::empty);
	if (slot_type == key::file) {
		return inspect_save_file(state, text_field(state, summary, key::slot_id, key::empty));
	}
	if (slot_type == key::autosave) {
		return inspect_autosave(state);
	}
	if (slot_type == key::manual) {
		return inspect_manual_slot(state, gd::to_int(state, state.get(summary, gd::str(key::slot_id), gd::int_value(kFirstManualSlot))));
	}
	const Atom slot_id = text_field(state, summary, key::slot_id, key::empty);
	const Atom path = text_field(state, summary, key::path, key::empty);
	return _inspect_slot(state, slot_type, slot_id, path);
}

DictRef build_delete_action(State &state, DictRef summary) {
	const DictRef identity = _deletable_slot_identity(state, summary);
	if (gd::is_empty(state, identity)) {
		return dict_of(state, { { key::label, gd::str(key::delete_save) }, { key::disabled, gd::bool_value(true) },
									  { key::summary, gd::str(key::select_an_occupied_autosave_or_manual) } });
	}

	const DictRef live_summary = _summary_for_slot_identity(state, identity);
	const Atom path = text_field(state, identity, key::path, key::empty);
	const bool occupied = path != key::empty && gd::file_exists(state, path);
	Atom slot_label = key::Autosave;
	if (text_field(state, identity, key::slot_type, key::empty) != key::autosave) {
		slot_label = gd::format(state, key::manual_slot_s, { gd::str(text_field(state, identity, key::slot_id, key::empty)) });
	}
	if (text_field(state, identity, key::slot_type, key::empty) == key::file) {
		slot_label = concat(state, text_field(state, identity, key::slot_id, key::empty), key::save_json);
	}
	Atom context = gd::strip_edges(state, text_field(state, live_summary, key::scenario_name, key::empty));
	if (context == key::empty) {
		context = occupied ? key::this_unreadable_save : key::this_empty_slot;
	}
	const Atom summary_text = gd::format(state, key::delete_s_for_s_this_permanently, { gd::str(slot_label), gd::str(context) });
	return dict_of(state, { { key::slot_type, gd::str(text_field(state, identity, key::slot_type, key::empty)) },
								  { key::slot_id, gd::str(text_field(state, identity, key::slot_id, key::empty)) },
								  { key::slot_label, gd::str(slot_label) },
								  { key::scenario_name, gd::str(text_field(state, live_summary, key::scenario_name, key::empty)) },
								  { key::label, gd::str(key::delete_save) }, { key::disabled, gd::bool_value(!occupied) },
								  { key::summary, gd::str(summary_text) } });
}

DictRef build_manual_slot_name_action(State &state, DictRef summary) {
	const DictRef identity = _deletable_slot_identity(state, summary);
	if (text_field(state, identity, key::slot_type, key::empty) != key::manual) {
		return dict_of(state, { { key::disabled, gd::bool_value(true) }, { key::slot_id, gd::str(key::empty) },
									  { key::current_name, gd::str(key::empty) },
									  { key::message, gd::str(key::select_an_occupied_manual_save_before) } });
	}
	const DictRef live_summary = _summary_for_slot_identity(state, identity);
	if (!can_load_summary(state, live_summary)) {
		return dict_of(state, { { key::disabled, gd::bool_value(true) },
									  { key::slot_id, gd::str(text_field(state, identity, key::slot_id, key::empty)) },
									  { key::current_name, gd::str(key::empty) },
									  { key::message, gd::str(key::only_a_valid_occupied_manual_save) } });
	}
	return dict_of(state, { { key::disabled, gd::bool_value(false) },
								  { key::slot_id, gd::str(text_field(state, identity, key::slot_id, key::empty)) },
								  { key::current_name, gd::str(text_field(state, live_summary, key::manual_slot_name, key::empty)) },
								  { key::message, gd::str(gd::format(state, key::set_an_optional_name_for_manual,
														  { gd::str(text_field(state, identity, key::slot_id, key::empty)) })) } });
}

DictRef set_manual_slot_name_from_summary(State &state, DictRef summary, Atom requested_name) {
	const DictRef action = build_manual_slot_name_action(state, summary);
	if (gd::bool_field(state, action, key::disabled, true)) {
		return dict_of(state, { { key::ok, gd::bool_value(false) }, { key::changed, gd::bool_value(false) },
									  { key::slot_id, gd::str(text_field(state, action, key::slot_id, key::empty)) },
									  { key::name, gd::str(key::empty) },
									  { key::message, gd::str(text_field(state, action, key::message, key::no_manual_save_was_renamed)) } });
	}
	const DictRef name_check = _validate_manual_slot_name(state, requested_name);
	if (!gd::bool_field(state, name_check, key::ok, false)) {
		return dict_of(state, { { key::ok, gd::bool_value(false) }, { key::changed, gd::bool_value(false) },
									  { key::slot_id, gd::str(text_field(state, action, key::slot_id, key::empty)) },
									  { key::name, gd::str(text_field(state, action, key::current_name, key::empty)) },
									  { key::message, gd::str(text_field(state, name_check, key::message, key::the_save_name_is_invalid)) } });
	}

	const Atom slot_id = text_field(state, action, key::slot_id, key::empty);
	const Atom path = _slot_path(state, gd::to_int(state, gd::str(slot_id)));
	const DictRef payload = _load_raw_dictionary(state, path, false);
	const DictRef structure_report = _payload_structure_report(state, payload, key::manual);
	if (gd::is_empty(state, payload) || !gd::bool_field(state, structure_report, key::ok, false)) {
		return dict_of(state, { { key::ok, gd::bool_value(false) }, { key::changed, gd::bool_value(false) },
									  { key::slot_id, gd::str(slot_id) },
									  { key::name, gd::str(text_field(state, action, key::current_name, key::empty)) },
									  { key::message, gd::str(gd::format(state, key::manual_slot_s_changed_or_became, { gd::str(slot_id) })) } });
	}
	const Atom normalized_name = text_field(state, name_check, key::name, key::empty);
	const Atom previous_name = _manual_slot_name_from_payload(state, payload);
	if (previous_name == normalized_name) {
		return dict_of(state, { { key::ok, gd::bool_value(true) }, { key::changed, gd::bool_value(false) }, { key::slot_id, gd::str(slot_id) },
									  { key::name, gd::str(normalized_name) }, { key::path, gd::str(path) },
									  { key::message, gd::str(gd::format(state, key::manual_slot_s_already_uses_that, { gd::str(slot_id) })) } });
	}

	const DictRef previous_payload = gd::as_dict(gd::engine_duplicate(state, gd::dict_value(payload), true));
	if (normalized_name == key::empty) {
		state.erase(payload, gd::str(key::manual_slot_name));
	} else {
		put(state, payload, key::manual_slot_name, gd::str(normalized_name));
	}
	if (_save_raw_dictionary(state, payload, path, state.new_dict(), state.new_dict()) == key::empty) {
		return dict_of(state, { { key::ok, gd::bool_value(false) }, { key::changed, gd::bool_value(false) }, { key::slot_id, gd::str(slot_id) },
									  { key::name, gd::str(previous_name) },
									  { key::message, gd::str(gd::format(state, key::manual_slot_s_could_not_save, { gd::str(slot_id) })) } });
	}
	const DictRef persisted = _load_raw_dictionary(state, path, false);
	if (!gd::equal(state, gd::dict_value(persisted), gd::dict_value(payload))) {
		_save_raw_dictionary(state, previous_payload, path, state.new_dict(), state.new_dict());
		return dict_of(state, { { key::ok, gd::bool_value(false) }, { key::changed, gd::bool_value(false) }, { key::slot_id, gd::str(slot_id) },
									  { key::name, gd::str(previous_name) },
									  { key::message, gd::str(gd::format(state, key::manual_slot_s_failed_name_verification, { gd::str(slot_id) })) } });
	}
	const Atom verb = normalized_name == key::empty ? key::cleared_the_name_from : key::Named;
	return dict_of(state, { { key::ok, gd::bool_value(true) }, { key::changed, gd::bool_value(true) }, { key::slot_id, gd::str(slot_id) },
								  { key::name, gd::str(normalized_name) }, { key::path, gd::str(path) },
								  { key::message, gd::str(gd::format(state, key::s_manual_slot_s, { gd::str(verb), gd::str(slot_id) })) } });
}

DictRef build_manual_save_action(State &state, const Value &session, int64_t manual_slot) {
	if (manual_slot != 1 && manual_slot != 2 && manual_slot != 3) {
		return dict_of(state, { { key::slot, gd::int_value(manual_slot) }, { key::slot_label, gd::str(key::manual_slot) },
									  { key::disabled, gd::bool_value(true) }, { key::requires_confirmation, gd::bool_value(false) },
									  { key::summary, gd::str(key::choose_a_valid_manual_save_slot) } });
	}
	if (session.kind == Kind::Nil ||
			gd::to_string(gd::index(state, gd::object_view(state, session), gd::str(key::scenario_id))) == key::empty) {
		return dict_of(state, { { key::slot, gd::int_value(manual_slot) },
									  { key::slot_label, gd::str(gd::format(state, key::manual_slot_d, { gd::int_value(manual_slot) })) },
									  { key::disabled, gd::bool_value(true) }, { key::requires_confirmation, gd::bool_value(false) },
									  { key::summary, gd::str(key::no_active_expedition_is_available_to) } });
	}

	const DictRef existing_summary = inspect_manual_slot(state, manual_slot);
	const DictRef current_summary = _manual_summary_for_session(state, session, manual_slot);
	const bool occupied = gd::file_exists(state, _slot_path(state, manual_slot));
	Atom existing_context = key::Empty;
	if (occupied) {
		existing_context = can_load_summary(state, existing_summary) ? describe_resume_brief(state, existing_summary) : key::unreadable_expedition_save;
	}
	const Atom current_context = describe_resume_brief(state, current_summary);
	const Atom slot_label = gd::format(state, key::manual_slot_d, { gd::int_value(manual_slot) });
	Atom summary_text = gd::format(state, key::save_s_to_s, { gd::str(current_context), gd::str(slot_label) });
	if (occupied) {
		summary_text = gd::format(state, key::replace_s_currently_saved_s_new,
				{ gd::str(slot_label), gd::str(existing_context), gd::str(current_context), gd::str(slot_label) });
	}
	return dict_of(state, { { key::slot, gd::int_value(manual_slot) }, { key::slot_label, gd::str(slot_label) },
								  { key::disabled, gd::bool_value(false) }, { key::occupied, gd::bool_value(occupied) },
								  { key::requires_confirmation, gd::bool_value(occupied) }, { key::existing_context, gd::str(existing_context) },
								  { key::current_context, gd::str(current_context) }, { key::summary, gd::str(summary_text) } });
}

DictRef delete_session_from_summary(State &state, DictRef summary) {
	const DictRef identity = _deletable_slot_identity(state, summary);
	const DictRef action = build_delete_action(state, summary);
	if (gd::is_empty(state, identity) || gd::bool_field(state, action, key::disabled, true)) {
		return dict_of(state, { { key::ok, gd::bool_value(false) },
									  { key::slot_type, gd::str(text_field(state, action, key::slot_type, key::empty)) },
									  { key::slot_id, gd::str(text_field(state, action, key::slot_id, key::empty)) },
									  { key::message, gd::str(key::no_occupied_autosave_or_manual_slot) } });
	}

	const Atom path = text_field(state, identity, key::path, key::empty);
	// A deleted save must not come back from its retained previous generation.
	int64_t remove_error = _remove_save_transaction_artifact(state, _save_transaction_previous_path(state, path)) ? kOk : kFailed;
	if (remove_error == kOk) {
		const Value absolute = gd::call_method(state, gd::engine_singleton(state, key::ProjectSettings), key::globalize_path, { gd::str(path) });
		remove_error = gd::to_int(state, gd::class_call_static(state, key::DirAccess, key::remove_absolute, { absolute }));
	}
	if (remove_error != kOk) {
		return dict_of(state, { { key::ok, gd::bool_value(false) },
									  { key::slot_type, gd::str(text_field(state, identity, key::slot_type, key::empty)) },
									  { key::slot_id, gd::str(text_field(state, identity, key::slot_id, key::empty)) },
									  { key::message, gd::str(gd::format(state, key::s_could_not_be_deleted_other,
															  { gd::str(text_field(state, action, key::slot_label, key::Save)) })) } });
	}

	_invalidate_summary_cache_for_path(state, path);
	return dict_of(state, { { key::ok, gd::bool_value(true) }, { key::slot_type, gd::str(text_field(state, identity, key::slot_type, key::empty)) },
								  { key::slot_id, gd::str(text_field(state, identity, key::slot_id, key::empty)) },
								  { key::slot_label, gd::str(text_field(state, action, key::slot_label, key::Save)) },
								  { key::message, gd::str(gd::format(state, key::s_was_deleted_other_save_slots,
														  { gd::str(text_field(state, action, key::slot_label, key::Save)) })) } });
}

Atom save_progression(State &state, DictRef payload) {
	if (gd::is_empty(state, payload)) {
		gd::push_warning(state, "Refusing to save an empty campaign progression payload.");
		return key::empty;
	}
	const DictRef payload_report = _progression_payload_semantic_report(state, payload);
	if (text_field(state, payload_report, key::status, key::empty) != key::current_valid) {
		gd::push_warning(state, "Refusing to save incompatible campaign progression: " +
						state.text(text_field(state, payload_report, key::reason, key::invalid_payload)));
		return key::empty;
	}
	const DictRef storage = inspect_progression_storage(state);
	if (!gd::bool_field(state, storage, key::writable, false)) {
		gd::push_warning(state, state.text(text_field(state, storage, key::message, key::campaign_progress_storage_cannot_be_overwritten)));
		return key::empty;
	}
	if (state.has(payload_report, gd::str(key::migrated_from_version))) {
		const DictRef current = _current_progression_payload(state, payload, payload_report);
		return _save_raw_dictionary(state, current, _progression_path(state), state.new_dict(), state.new_dict());
	}
	return _save_raw_dictionary(state, payload, _progression_path(state), state.new_dict(), state.new_dict());
}

DictRef load_progression(State &state) {
	const DictRef storage = inspect_progression_storage(state);
	if (!gd::bool_field(state, storage, key::usable, false)) {
		return state.new_dict();
	}
	const DictRef raw = _read_json_dictionary_unrecovered(state, _progression_path(state), true);
	if (!gd::bool_field(state, raw, key::ok, false)) {
		return state.new_dict();
	}
	const DictRef payload = dict_field_or_new(state, raw, key::payload);
	const DictRef semantic_report = _progression_payload_semantic_report(state, payload);
	if (text_field(state, semantic_report, key::status, key::empty) != key::current_valid) {
		return state.new_dict();
	}
	return _current_progression_payload(state, payload, semantic_report);
}

bool has_progression(State &state) {
	return gd::bool_field(state, inspect_progression_storage(state), key::usable, false);
}

DictRef inspect_progression_storage(State &state) {
	const Atom path = _progression_path(state);
	const DictRef live_before = _read_json_dictionary_unrecovered(state, path, true);
	if (gd::bool_field(state, live_before, key::ok, false)) {
		const DictRef before_payload = dict_field_or_new(state, live_before, key::payload);
		const DictRef before_report = _progression_payload_semantic_report(state, before_payload);
		if (text_field(state, before_report, key::status, key::empty) == key::future_version) {
			// A parseable future profile is authoritative user data. Never replace it
			// with an older backup; only staging is safe to discard.
			_remove_save_transaction_artifact(state, _save_transaction_candidate_path(state, path));
			const DictRef recovery = dict_of(state, { { key::reason, gd::str(key::future_version) }, { key::recovered, gd::bool_value(false) } });
			return _progression_storage_result(state, key::future_version, path, live_before, before_report, recovery);
		}
	}

	const DictRef recovery = _recover_save_transaction(state, path, false);
	const DictRef live = _read_json_dictionary_unrecovered(state, path, true);
	if (!gd::bool_field(state, live, key::exists, false)) {
		Atom missing_status = key::missing;
		const Atom missing_reason = text_field(state, recovery, key::reason, key::missing);
		if (missing_reason == key::backup_restore_failed || missing_reason == key::backup_restore_verification_failed ||
				missing_reason == key::previous_restore_failed || missing_reason == key::previous_restore_verification_failed) {
			missing_status = key::invalid;
		}
		const DictRef report = dict_of(state, { { key::status, gd::str(missing_status) }, { key::reason, gd::str(missing_reason) },
													  { key::version, gd::int_value(-1) } });
		return _progression_storage_result(state, missing_status, path, live, report, recovery);
	}
	if (!gd::bool_field(state, live, key::ok, false)) {
		const Atom reason = gd::bool_field(state, live, key::readable, false) ? key::corrupt_json : key::unreadable;
		const DictRef report = dict_of(state, { { key::status, gd::str(key::invalid) }, { key::reason, gd::str(reason) },
													  { key::version, gd::int_value(-1) } });
		return _progression_storage_result(state, key::invalid, path, live, report, recovery);
	}
	const DictRef payload = dict_field_or_new(state, live, key::payload);
	const DictRef semantic_report = _progression_payload_semantic_report(state, payload);
	Atom status = text_field(state, semantic_report, key::status, key::invalid);
	if (status == key::current_valid && gd::bool_field(state, recovery, key::recovered, false)) {
		status = key::recovered;
	}
	return _progression_storage_result(state, status, path, live, semantic_report, recovery);
}

} // namespace save_service

} // namespace aurelion::rules::port
