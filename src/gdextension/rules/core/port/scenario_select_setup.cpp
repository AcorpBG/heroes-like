// ScenarioSelectRules: generating the random map, writing its .amap and
// .ascenario packages and loading them back, and starting or restarting the
// generated skirmish's session from them.

#include "aurelion_rules/port/scenario_select_rules_setup.hpp"

#include "aurelion_rules/port/ai_port.hpp"
#include "aurelion_rules/port/native_random_map_package_session_bridge.hpp"
#include "aurelion_rules/port/overworld_rules.hpp"
#include "aurelion_rules/port/random_map_generator_rules.hpp"
#include "aurelion_rules/port/scenario_evaluation.hpp"
#include "aurelion_rules/port/session_state_store.hpp"
#include "aurelion_rules/port/session_view.hpp"

#include <initializer_list>
#include <string>
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

// SessionStateStore.SAVE_VERSION.
constexpr int64_t kSaveVersion = 9;

void put(State &state, DictRef dict, Atom name, const Value &value) {
	state.set(dict, gd::str(name), value);
}

// d.get(name, {}) if d.get(name, {}) is Dictionary else {}.
DictRef dict_or_new(State &state, DictRef dict, Atom name) {
	Value found;
	if (state.lookup(dict, gd::str(name), found) && found.kind == Kind::Dict) {
		return found.ref;
	}
	return state.new_dict();
}

// d.get(name, []) if d.get(name, []) is Array else [].
ArrayRef array_or_new(State &state, DictRef dict, Atom name) {
	Value found;
	if (state.lookup(dict, gd::str(name), found) && found.kind == Kind::Array) {
		return found.ref;
	}
	return state.new_array();
}

// var x: Dictionary = d.get(name, {}): the field (a ScriptError when it is no
// Dictionary) or a new {}.
DictRef typed_dict(State &state, DictRef dict, Atom name) {
	Value found;
	if (!state.lookup(dict, gd::str(name), found)) {
		return state.new_dict();
	}
	return gd::as_dict(found);
}

// d.get(name, {}) as a value: the field, or a new {}.
Value field_or_new_dict(State &state, DictRef dict, Atom name) {
	Value found;
	if (state.lookup(dict, gd::str(name), found)) {
		return found;
	}
	return gd::dict_value(state.new_dict());
}

// String(d.get(name, fallback)).
Atom string_of(State &state, DictRef dict, Atom name, Atom fallback) {
	return gd::stringify(state, state.get(dict, gd::str(name), gd::str(fallback)));
}

// d.get(outer, {}).get(name, fallback): the inner get of an untyped value.
Value nested_get(State &state, DictRef dict, Atom outer, Atom name, const Value &fallback) {
	Value base;
	if (!state.lookup(dict, gd::str(outer), base)) {
		return fallback;
	}
	return ai::vget(state, base, name, fallback);
}

// generated.get("report", generated.get("validation_report", {})) if that is
// Dictionary else {}.
DictRef generated_report(State &state, DictRef generated) {
	Value found;
	if (!state.lookup(generated, gd::str(key::report), found) && !state.lookup(generated, gd::str(key::validation_report), found)) {
		return state.new_dict();
	}
	return found.kind == Kind::Dict ? found.ref : state.new_dict();
}

// d.get("report", {}) if d.get("report", {}) is Dictionary else fallback: a
// missing report is a new {}.
DictRef report_or(State &state, DictRef dict, DictRef fallback) {
	Value found;
	if (!state.lookup(dict, gd::str(key::report), found)) {
		return state.new_dict();
	}
	return found.kind == Kind::Dict ? found.ref : fallback;
}

// x.duplicate(true) of an untyped value.
Value duplicate_deep(State &state, const Value &value) {
	switch (value.kind) {
		case Kind::Dict:
		case Kind::Array:
			return gd::duplicate_value(state, value, true);
		case Kind::Opaque:
			return gd::call_method(state, value, key::duplicate, {gd::bool_value(true)});
		case Kind::Nil:
			throw state::ScriptError("Cannot call method 'duplicate' on a null value.");
		default:
			throw state::ScriptError(std::string("Invalid call. Nonexistent function 'duplicate' in base '") + gd::type_name(value) + "'.");
	}
}

// A String field of a SessionData (its view).
Atom session_string(State &state, DictRef view, Atom field) {
	return gd::to_string(gd::index(state, view, gd::str(field)));
}

DictRef session_flags(State &state, DictRef view) {
	return gd::as_dict(gd::index(state, view, gd::str(key::flags)));
}

// SessionStateStore.new_session_data() with its defaults.
Value empty_session(State &state) {
	return session_state_store::new_session_data(state, key::empty, key::empty, key::empty, 1, state.new_dict(), key::normal, key::campaign);
}

// RANDOM_MAP_PLAYER_RETRY_POLICY (only read where it is passed): a new copy.
DictRef player_retry_policy(State &state) {
	const DictRef policy = state.new_dict();
	put(state, policy, key::max_attempts, gd::int_value(5));
	put(state, policy, key::mode, gd::str(key::seed_salt));
	return policy;
}

ArrayRef string_array(State &state, std::initializer_list<Atom> texts) {
	const ArrayRef array = state.new_array();
	for (const Atom text : texts) {
		state.append(array, gd::str(text));
	}
	return array;
}

// separator.join(parts) of Strings.
Atom join(State &state, Atom separator, const std::vector<Atom> &parts) {
	std::string joined;
	for (size_t index = 0; index < parts.size(); ++index) {
		if (index > 0) {
			joined += state.text(separator);
		}
		joined += state.text(parts[index]);
	}
	return state.intern(joined);
}

// float(Time.get_ticks_usec() - started) / 1000.0.
Value elapsed_ms(State &state, int64_t started_usec) {
	return gd::float_value(static_cast<double>(gd::sub(gd::engine_ticks_usec(state), started_usec)) / 1000.0);
}

// The "|".join([...]) of _generated_map_package_creative_name and
// _generated_map_package_short_hash: str() of each normalized field.
std::vector<Atom> identity_parts(State &state, DictRef normalized) {
	std::vector<Atom> parts;
	parts.push_back(gd::stringify(state, state.get(normalized, gd::str(key::normalized_seed),
			state.get(normalized, gd::str(key::seed), gd::str(key::empty)))));
	for (const Atom name : {key::template_id, key::profile_id, key::size_class_id, key::width, key::height, key::level_count,
				 key::player_count, key::water_mode, key::underground_enabled, key::generator_version}) {
		parts.push_back(gd::stringify(state, state.get(normalized, gd::str(name), gd::str(key::empty))));
	}
	return parts;
}

// s.unicode_at(i) for i in range(s.length()): the code points of UTF-8 text.
std::vector<uint32_t> code_points(const std::string &text) {
	std::vector<uint32_t> points;
	points.reserve(text.size());
	for (size_t at = 0; at < text.size();) {
		const unsigned char lead = static_cast<unsigned char>(text[at]);
		size_t length = 1;
		uint32_t point = lead;
		if (lead >= 0xF0) {
			length = 4;
			point = lead & 0x07u;
		} else if (lead >= 0xE0) {
			length = 3;
			point = lead & 0x0Fu;
		} else if (lead >= 0xC0) {
			length = 2;
			point = lead & 0x1Fu;
		}
		for (size_t next = 1; next < length && at + next < text.size(); ++next) {
			point = (point << 6) | (static_cast<unsigned char>(text[at + next]) & 0x3Fu);
		}
		points.push_back(point);
		at += length;
	}
	return points;
}

// s.length(): the code points of UTF-8 text.
int64_t text_length(const std::string &text) {
	int64_t count = 0;
	for (const char byte : text) {
		if ((static_cast<unsigned char>(byte) & 0xC0) != 0x80) {
			++count;
		}
	}
	return count;
}

// s.to_lower() as far as anything here sees it: the ASCII letters, and U+0130
// and U+212A, the only other characters whose lowercase (Godot's simple case
// table) is ASCII ("i" and "k"). Every other character lowers to a character
// outside ASCII, which the callers treat alike, so it stays as it is.
std::string lowered(const std::string &text) {
	std::string out;
	out.reserve(text.size());
	for (size_t at = 0; at < text.size(); ++at) {
		const unsigned char c = static_cast<unsigned char>(text[at]);
		if (c >= 'A' && c <= 'Z') {
			out += static_cast<char>(c - 'A' + 'a');
		} else if (c == 0xC4 && at + 1 < text.size() && static_cast<unsigned char>(text[at + 1]) == 0xB0) {
			out += 'i';
			at += 1;
		} else if (c == 0xE2 && at + 2 < text.size() && static_cast<unsigned char>(text[at + 1]) == 0x84 && static_cast<unsigned char>(text[at + 2]) == 0xAA) {
			out += 'k';
			at += 2;
		} else {
			out += static_cast<char>(c);
		}
	}
	return out;
}

} // namespace

namespace scenario_select_rules {

namespace bridge = native_random_map_package_session_bridge;

DictRef generated_map_package_directory_policy(State &state) {
	const DictRef policy = state.new_dict();
	put(state, policy, key::schema_id, gd::str(key::aurelion_generated_map_package_directory_policy_v1));
	put(state, policy, key::dev_source_dir, gd::str(key::res_maps));
	put(state, policy, key::export_runtime_dir, gd::str(key::user_maps));
	put(state, policy, key::active_dir, gd::str(_generated_map_package_dir(state)));
	put(state, policy, key::active_dir_kind, gd::str(_use_project_maps_dir(state) ? key::project_source_dev_maps : key::export_runtime_user_maps));
	put(state, policy, key::semantics, gd::str(key::generated_random_map_startup_writes_amap));
	return policy;
}

DictRef build_random_map_skirmish_setup_with_retry(State &state, DictRef input_config, Atom difficulty_id, DictRef retry_policy) {
	const DictRef policy = _random_map_retry_policy(state, retry_policy);
	const int64_t max_attempts = gd::int_field(state, policy, key::max_attempts, 1);
	const ArrayRef attempts = state.new_array();
	DictRef final_setup = state.new_dict();
	const DictRef launch_config = _random_map_public_h3maped_launch_config(state, input_config);
	for (int64_t attempt_index = 0; attempt_index < max_attempts; ++attempt_index) {
		const DictRef attempt_config = _random_map_retry_attempt_config(state, launch_config, attempt_index, policy);
		const DictRef attempt_setup = _build_random_map_skirmish_setup_single_attempt(state, attempt_config, difficulty_id);
		const DictRef attempt_record = _random_map_setup_attempt_record(state, attempt_setup, attempt_config, attempt_index + 1, max_attempts);
		state.append(attempts, gd::dict_value(attempt_record));
		if (gd::bool_field(state, attempt_setup, key::ok, false)) {
			final_setup = attempt_setup;
			break;
		}
	}

	if (!gd::is_empty(state, final_setup)) {
		const DictRef retry_status = _random_map_retry_status_from_attempts(state, attempts, true, policy);
		put(state, final_setup, key::retry_status, gd::dict_value(retry_status));
		put(state, final_setup, key::retry_attempts, gd::array_value(attempts));
		put(state, final_setup, key::failure_handoff, gd::str(gd::format(state, key::generation_validated_for_launch_after_d, {gd::int_value(gd::int_field(state, retry_status, key::attempt_count, 1))})));
		// The legacy generator's setup summary is gone with it (owner decision):
		// a successful setup always has its package_startup.
		const DictRef provenance = dict_or_new(state, final_setup, key::provenance);
		put(state, provenance, key::retry_status, gd::dict_value(retry_status));
		put(state, provenance, key::retry_attempts, gd::array_value(attempts));
		put(state, final_setup, key::provenance, gd::dict_value(provenance));
		const DictRef replay = dict_or_new(state, final_setup, key::replay_metadata);
		put(state, replay, key::retry_status, gd::dict_value(retry_status));
		put(state, final_setup, key::replay_metadata, gd::dict_value(replay));
		return final_setup;
	}

	const DictRef retry_status = _random_map_retry_status_from_attempts(state, attempts, false, policy);
	const DictRef last_attempt = state.array_size(attempts) > 0 ? gd::as_dict(state.at(attempts, state.array_size(attempts) - 1)) : state.new_dict();
	const DictRef last_validation = dict_or_new(state, last_attempt, key::validation);
	const DictRef result = state.new_dict();
	put(state, result, key::ok, gd::bool_value(false));
	put(state, result, key::setup_kind, gd::str(key::generated_random_map_skirmish));
	put(state, result, key::launch_mode, gd::str(key::skirmish));
	put(state, result, key::difficulty, gd::str(normalize_difficulty(state, gd::str(difficulty_id))));
	put(state, result, key::difficulty_label, gd::str(difficulty_label(state, difficulty_id)));
	put(state, result, key::validation, gd::dict_value(last_validation));
	put(state, result, key::retry_status, gd::dict_value(retry_status));
	put(state, result, key::retry_attempts, gd::array_value(attempts));
	put(state, result, key::failure_handoff, gd::str(_random_map_failure_handoff(state, last_validation, retry_status)));
	put(state, result, key::setup_summary, gd::str(_random_map_failure_setup_summary(state, last_validation, retry_status, attempts)));
	put(state, result, key::campaign_adoption, gd::bool_value(false));
	put(state, result, key::alpha_parity_claim, gd::bool_value(false));
	return result;
}

DictRef build_random_map_skirmish_setup(State &state, DictRef input_config, Atom difficulty_id) {
	return build_random_map_skirmish_setup_with_retry(state, input_config, difficulty_id, player_retry_policy(state));
}

DictRef _build_random_map_skirmish_setup_single_attempt(State &state, DictRef input_config, Atom difficulty_id) {
	const bool profile_enabled = gd::strip_edges(state, gd::os_environment(state, key::HEROES_PROFILE_LOG)) != key::empty;
	const int64_t total_started_usec = gd::engine_ticks_usec(state);
	const DictRef profile_buckets = state.new_dict();
	const Atom normalized_difficulty = normalize_difficulty(state, gd::str(difficulty_id));
	const Value service = _native_map_package_service(state);
	if (service.kind == Kind::Nil) {
		return _native_package_setup_failure(state, key::native_package_service_unavailable,
				key::native_mappackageservice_is_required_for_generated, normalized_difficulty, state.new_dict());
	}
	int64_t stage_started_usec = gd::engine_ticks_usec(state);
	const DictRef generate_options = state.new_dict();
	put(state, generate_options, key::startup_path, gd::str(key::generated_skirmish));
	put(state, generate_options, key::include_performance_profile, gd::bool_value(profile_enabled));
	const DictRef generated = gd::as_dict(gd::call_method(state, service, key::generate_random_map,
			{gd::dict_value(input_config), gd::dict_value(generate_options)}));
	put(state, profile_buckets, key::native_generate, elapsed_ms(state, stage_started_usec));
	DictRef report = generated_report(state, generated);
	if (gd::is_empty(state, report) && gd::bool_field(state, generated, key::ok, false)) {
		report = state.new_dict();
		put(state, report, key::schema_id, gd::str(key::aurelion_native_rmg_launch_validation_summary_v1));
		put(state, report, key::status, gd::str(key::pass));
		put(state, report, key::ok, gd::bool_value(true));
		put(state, report, key::failure_count, gd::int_value(0));
		put(state, report, key::warning_count, gd::int_value(0));
		put(state, report, key::source_status, gd::str(string_of(state, generated, key::status, key::empty)));
		put(state, report, key::full_generation_status, gd::str(string_of(state, generated, key::full_generation_status, key::empty)));
	} else if (gd::is_empty(state, report)) {
		const Atom failure_code = gd::stringify(state, state.get(generated, gd::str(key::error_code),
				state.get(generated, gd::str(key::status), gd::str(key::native_random_map_generation_failed))));
		const Atom failure_message = string_of(state, generated, key::message, key::native_generated_map_startup_failed_before);
		Atom failure_detail = failure_code;
		if (failure_message != key::empty) {
			failure_detail = gd::format(state, key::s_s_text, {gd::str(failure_code), gd::str(failure_message)});
		}
		report = state.new_dict();
		put(state, report, key::schema_id, gd::str(key::aurelion_native_rmg_launch_validation_summary_v1));
		put(state, report, key::status, gd::str(key::fail));
		put(state, report, key::validation_status, gd::str(key::fail));
		put(state, report, key::ok, gd::bool_value(false));
		put(state, report, key::failure_count, gd::int_value(1));
		put(state, report, key::warning_count, gd::int_value(0));
		put(state, report, key::failures, gd::array_value(string_array(state, {failure_detail})));
		put(state, report, key::source_status, gd::str(string_of(state, generated, key::status, key::empty)));
		put(state, report, key::generation_status, gd::str(string_of(state, generated, key::generation_status, key::empty)));
		put(state, report, key::full_generation_status, gd::str(string_of(state, generated, key::full_generation_status, key::empty)));
		put(state, report, key::error_code, gd::str(failure_code));
		put(state, report, key::message, gd::str(failure_message));
		put(state, report, key::normalized_config, field_or_new_dict(state, generated, key::normalized_config));
	}
	const DictRef retry_status = _random_map_retry_status(state, generated, report);
	if (!gd::bool_field(state, generated, key::ok, false)) {
		const DictRef failed = state.new_dict();
		put(state, failed, key::ok, gd::bool_value(false));
		put(state, failed, key::setup_kind, gd::str(key::generated_random_map_skirmish));
		put(state, failed, key::launch_mode, gd::str(key::skirmish));
		put(state, failed, key::difficulty, gd::str(normalized_difficulty));
		put(state, failed, key::validation, gd::dict_value(report));
		put(state, failed, key::retry_status, gd::dict_value(retry_status));
		put(state, failed, key::failure_handoff, gd::str(_random_map_failure_handoff(state, report, retry_status)));
		put(state, failed, key::campaign_adoption, gd::bool_value(false));
		put(state, failed, key::alpha_parity_claim, gd::bool_value(false));
		return failed;
	}
	if (string_of(state, generated, key::full_generation_status, key::empty) == key::not_implemented) {
		const DictRef unsupported_report = _random_map_not_implemented_launch_report(state, generated, report);
		return _native_package_setup_failure(state, key::native_rmg_full_generation_not_implemented,
				key::native_generated_map_startup_does_not, normalized_difficulty, unsupported_report);
	}
	const DictRef normalized_config = dict_or_new(state, generated, key::normalized_config);
	const DictRef player_setup = dict_or_new(state, normalized_config, key::player_setup);
	if (_is_legacy_compact_rmg_config(state, normalized_config)) {
		const DictRef legacy_report = _random_map_legacy_compact_launch_report(state, generated, report);
		return _native_package_setup_failure(state, key::native_rmg_legacy_compact_launch_blocked,
				key::the_legacy_compact_random_map_generator, normalized_difficulty, legacy_report);
	}

	stage_started_usec = gd::engine_ticks_usec(state);
	const DictRef convert_options = state.new_dict();
	put(state, convert_options, key::feature_gate, gd::str(key::native_rmg_generated_map_package_startup));
	put(state, convert_options, key::session_save_version, gd::int_value(kSaveVersion));
	const DictRef adoption = gd::as_dict(gd::call_method(state, service, key::convert_generated_payload,
			{gd::dict_value(generated), gd::dict_value(convert_options)}));
	put(state, profile_buckets, key::convert_generated_payload, elapsed_ms(state, stage_started_usec));
	if (!gd::bool_field(state, adoption, key::ok, false)) {
		const Atom code = string_of(state, adoption, key::error_code, key::native_package_conversion_failed);
		const Atom message = string_of(state, adoption, key::message, key::native_generated_payload_could_not_be);
		return _native_package_setup_failure(state, code, message, normalized_difficulty, report_or(state, adoption, report));
	}
	stage_started_usec = gd::engine_ticks_usec(state);
	const DictRef persisted = _persist_and_load_generated_packages(state, service, adoption, generated);
	put(state, profile_buckets, key::persist_and_load_packages, elapsed_ms(state, stage_started_usec));
	if (!gd::bool_field(state, persisted, key::ok, false)) {
		const Atom code = string_of(state, persisted, key::error_code, key::native_package_persist_load_failed);
		const Atom message = string_of(state, persisted, key::message, key::native_generated_packages_could_not_be);
		return _native_package_setup_failure(state, code, message, normalized_difficulty, report_or(state, persisted, report));
	}

	const DictRef identity = _native_random_map_generated_identity(state, generated, adoption, persisted);
	const DictRef provenance = _native_random_map_provenance(state, input_config, generated, adoption, persisted, retry_status);
	const Atom setup_summary = _native_random_map_setup_summary(state, generated, adoption, persisted, report, retry_status, normalized_difficulty);
	const DictRef scenario_ref = dict_or_new(state, persisted, key::scenario_ref);
	const DictRef map_ref = dict_or_new(state, persisted, key::map_ref);
	const DictRef result = state.new_dict();
	put(state, result, key::ok, gd::bool_value(true));
	put(state, result, key::setup_kind, gd::str(key::generated_random_map_skirmish));
	put(state, result, key::startup_source, gd::str(key::native_rmg_disk_package));
	put(state, result, key::launch_mode, gd::str(key::skirmish));
	put(state, result, key::difficulty, gd::str(normalized_difficulty));
	put(state, result, key::difficulty_label, gd::str(difficulty_label(state, normalized_difficulty)));
	put(state, result, key::generated_map, gd::dict_value(state.new_dict()));
	const DictRef native_generation = state.new_dict();
	put(state, native_generation, key::status, gd::str(string_of(state, generated, key::status, key::empty)));
	put(state, native_generation, key::full_generation_status, gd::str(string_of(state, generated, key::full_generation_status, key::empty)));
	put(state, native_generation, key::validation_status, gd::str(string_of(state, generated, key::validation_status, key::empty)));
	put(state, native_generation, key::supported_parity_config, gd::bool_value(gd::bool_field(state, generated, key::supported_parity_config, false)));
	put(state, native_generation, key::generator_core_reused, gd::bool_value(gd::bool_field(state, generated, key::generator_core_reused, false)));
	put(state, result, key::native_generation, gd::dict_value(native_generation));
	put(state, result, key::package_startup, gd::dict_value(persisted));
	put(state, result, key::scenario_id, gd::str(string_of(state, identity, key::scenario_id, key::empty)));
	put(state, result, key::scenario_name, gd::str(string_of(state, identity, key::scenario_id, key::empty)));
	put(state, result, key::template_id, gd::str(string_of(state, identity, key::template_id, key::empty)));
	put(state, result, key::profile_id, gd::str(string_of(state, identity, key::profile_id, key::empty)));
	put(state, result, key::normalized_seed, gd::str(string_of(state, identity, key::normalized_seed, key::empty)));
	put(state, result, key::seed_source, gd::str(string_of(state, input_config, key::seed_source, key::explicit_)));
	const Atom seed_text = string_of(state, input_config, key::seed, key::empty);
	put(state, result, key::seed_input, gd::str(string_of(state, input_config, key::seed_input, seed_text)));
	put(state, result, key::player_faction_id, gd::str(string_of(state, player_setup, key::faction_id, key::empty)));
	put(state, result, key::player_hero_id, gd::str(string_of(state, player_setup, key::hero_id, key::empty)));
	put(state, result, key::player_setup, gd::dict_value(gd::deep_duplicate_dict(state, player_setup)));
	put(state, result, key::content_manifest_fingerprint, gd::str(string_of(state, identity, key::content_manifest_fingerprint, key::empty)));
	put(state, result, key::generated_identity, gd::dict_value(identity));
	put(state, result, key::validation, gd::dict_value(report));
	put(state, result, key::retry_status, gd::dict_value(retry_status));
	put(state, result, key::provenance, gd::dict_value(provenance));
	put(state, result, key::replay_metadata, gd::dict_value(_random_map_replay_metadata(state, provenance, identity, retry_status)));
	put(state, result, key::setup_summary, gd::str(setup_summary));
	put(state, result, key::map_ref, gd::dict_value(map_ref));
	put(state, result, key::scenario_ref, gd::dict_value(scenario_ref));
	put(state, result, key::launch_handoff, gd::str(key::launch_handoff_generated_skirmish_starts_from));
	put(state, result, key::failure_handoff, gd::str(key::generation_validated_for_launch_package_refs));
	put(state, result, key::campaign_adoption, gd::bool_value(false));
	put(state, result, key::alpha_parity_claim, gd::bool_value(gd::bool_field(state, generated, key::full_parity_claim, false)));
	if (profile_enabled) {
		put(state, profile_buckets, key::total_single_attempt, elapsed_ms(state, total_started_usec));
		const DictRef performance_profile = state.new_dict();
		put(state, performance_profile, key::schema_id, gd::str(key::aurelion_generated_map_setup_performance_profile_v1));
		put(state, performance_profile, key::buckets_ms, gd::dict_value(profile_buckets));
		put(state, performance_profile, key::native_generation, field_or_new_dict(state, generated, key::performance_profile));
		put(state, result, key::performance_profile, gd::dict_value(performance_profile));
	}
	return result;
}

Value start_random_map_skirmish_session(State &state, DictRef input_config, Atom difficulty_id) {
	const DictRef setup = build_random_map_skirmish_setup_with_retry(state, input_config, difficulty_id, player_retry_policy(state));
	return _start_random_map_skirmish_session_from_setup(state, setup);
}

Value start_random_map_skirmish_session_with_retry(State &state, DictRef input_config, Atom difficulty_id, DictRef retry_policy) {
	const DictRef setup = build_random_map_skirmish_setup_with_retry(state, input_config, difficulty_id, retry_policy);
	return _start_random_map_skirmish_session_from_setup(state, setup);
}

Value start_random_map_skirmish_session_from_setup(State &state, DictRef setup) {
	return _start_random_map_skirmish_session_from_setup(state, setup);
}

DictRef restart_generated_skirmish_session(State &state, const Value &source) {
	const DictRef unavailable = state.new_dict();
	put(state, unavailable, key::ok, gd::bool_value(false));
	put(state, unavailable, key::route, gd::str(key::stay));
	put(state, unavailable, key::message, gd::str(key::the_original_generated_map_packages_are));
	if (source.kind == Kind::Nil) {
		return unavailable;
	}
	const DictRef source_view = gd::object_view(state, source);
	if (!gd::to_bool(state.get(session_flags(state, source_view), gd::str(key::generated_random_map), gd::bool_value(false)))) {
		return unavailable;
	}
	Value boundary_value;
	if (!state.lookup(session_view::overworld(state, source_view), gd::str(key::native_random_map_package_session_adoption), boundary_value)
			|| boundary_value.kind != Kind::Dict || gd::is_empty(state, boundary_value.ref)) {
		return unavailable;
	}
	const DictRef boundary = gd::deep_duplicate_dict(state, boundary_value.ref);
	const Atom map_path = string_of(state, boundary, key::map_package_path, key::empty);
	const Atom scenario_path = string_of(state, boundary, key::scenario_package_path, key::empty);
	if (!gd::file_exists(state, map_path) || !gd::file_exists(state, scenario_path)) {
		return unavailable;
	}
	const Value service = _native_map_package_service(state);
	if (service.kind == Kind::Nil) {
		return unavailable;
	}
	// Validate the exact loaded documents that will be adopted, never regenerate a
	// replacement seed or reload an unchecked package after this identity check.
	const DictRef map_load = gd::as_dict(gd::call_method(state, service, key::load_map_package, {gd::str(map_path)}));
	const DictRef scenario_load = gd::as_dict(gd::call_method(state, service, key::load_scenario_package, {gd::str(scenario_path)}));
	if (!gd::bool_field(state, map_load, key::ok, false) || !gd::bool_field(state, scenario_load, key::ok, false)) {
		return unavailable;
	}
	const DictRef map_ref = typed_dict(state, map_load, key::map_ref);
	const DictRef scenario_ref = typed_dict(state, scenario_load, key::scenario_ref);
	const ArrayRef map_keys = string_array(state, {key::package_hash, key::map_id, key::map_hash, key::source_kind});
	const ArrayRef scenario_keys = string_array(state, {key::package_hash, key::scenario_id, key::scenario_hash});
	if (!_maps_folder_package_ref_matches(state, gd::as_dict(field_or_new_dict(state, session_flags(state, source_view), key::map_package_ref)), map_ref, map_keys)
			|| !_maps_folder_package_ref_matches(state, gd::as_dict(field_or_new_dict(state, boundary, key::map_package_ref)), map_ref, map_keys)
			|| !_maps_folder_package_ref_matches(state, gd::as_dict(field_or_new_dict(state, session_flags(state, source_view), key::scenario_package_ref)), scenario_ref, scenario_keys)
			|| !_maps_folder_package_ref_matches(state, gd::as_dict(field_or_new_dict(state, boundary, key::scenario_package_ref)), scenario_ref, scenario_keys)
			|| !_maps_folder_package_ref_matches(state, gd::as_dict(field_or_new_dict(state, scenario_ref, key::map_ref)), map_ref, map_keys)
			|| string_of(state, scenario_ref, key::scenario_id, key::empty) != session_string(state, source_view, key::scenario_id)) {
		return unavailable;
	}
	const DictRef original = scenario_rules::scenario_record_for_session(state, source_view);
	const Atom hero_id = gd::stringify(state, state.get(original, gd::str(key::starting_hero_id),
			state.get(original, gd::str(key::hero_id), gd::str(key::empty))));
	const Atom faction_id = string_of(state, original, key::player_faction_id, key::empty);
	if (hero_id == key::empty || faction_id == key::empty) {
		return unavailable;
	}
	const Atom difficulty = session_string(state, source_view, key::difficulty);
	const DictRef options = state.new_dict();
	put(state, options, key::hero_id, gd::str(hero_id));
	const Value fresh = bridge::build_session_from_loaded_packages(state, map_load, scenario_load, boundary, difficulty, options);
	const DictRef fresh_view = gd::object_view(state, fresh);
	const DictRef fresh_record = scenario_rules::scenario_record_for_session(state, fresh_view);
	if (session_string(state, fresh_view, key::scenario_id) != session_string(state, source_view, key::scenario_id)
			|| session_string(state, fresh_view, key::hero_id) != hero_id
			|| string_of(state, fresh_record, key::player_faction_id, key::empty) != faction_id) {
		return unavailable;
	}
	const DictRef setup = state.new_dict();
	// for key in [...]: setup[key] = source.flags.get("generated_random_map_" + key, {}).duplicate(true)
	static constexpr Atom kCarried[][2] = {
		{key::provenance, key::generated_random_map_provenance},
		{key::replay_metadata, key::generated_random_map_replay_metadata},
		{key::validation, key::generated_random_map_validation},
		{key::retry_status, key::generated_random_map_retry_status},
	};
	for (const auto &carried : kCarried) {
		put(state, setup, carried[0], duplicate_deep(state, field_or_new_dict(state, session_flags(state, source_view), carried[1])));
	}
	_finish_random_map_skirmish_startup(state, fresh, setup, true);
	const DictRef result = state.new_dict();
	put(state, result, key::ok, gd::bool_value(true));
	put(state, result, key::route, gd::str(key::overworld));
	put(state, result, key::message, gd::str(key::empty));
	return result;
}

Value _start_random_map_skirmish_session_from_setup(State &state, DictRef setup) {
	if (!gd::bool_field(state, setup, key::ok, false)) {
		gd::push_warning(state, state.text(string_of(state, setup, key::failure_handoff, key::generated_skirmish_setup_failed_validation)));
		return empty_session(state);
	}

	// var payload: Dictionary = setup.get("generated_map", {}): only the legacy
	// path used it; its typed assignment still checks the field.
	Value payload;
	if (state.lookup(setup, gd::str(key::generated_map), payload)) {
		(void)gd::as_dict(payload);
	}
	const DictRef package_startup = dict_or_new(state, setup, key::package_startup);
	Value session;
	if (!gd::is_empty(state, package_startup)) {
		const Value service = _native_map_package_service(state);
		if (service.kind == Kind::Nil) {
			return empty_session(state);
		}
		const DictRef map_load = gd::as_dict(gd::call_method(state, service, key::load_map_package,
				{gd::str(string_of(state, package_startup, key::map_path, key::empty))}));
		const DictRef scenario_load = gd::as_dict(gd::call_method(state, service, key::load_scenario_package,
				{gd::str(string_of(state, package_startup, key::scenario_path, key::empty))}));
		const DictRef boundary = gd::as_dict(field_or_new_dict(state, package_startup, key::session_boundary_record));
		const Atom difficulty = gd::stringify(state, state.get(setup, gd::str(key::difficulty), gd::str(default_difficulty_id(state))));
		const DictRef options = state.new_dict();
		put(state, options, key::hero_id, gd::str(string_of(state, setup, key::player_hero_id, key::hero_lyra)));
		session = bridge::build_session_from_loaded_packages(state, map_load, scenario_load, boundary, difficulty, options);
	} else {
		// The legacy generator path is deleted (owner decision): an empty session,
		// which the startup returns as it is.
		session = empty_session(state);
	}
	return _finish_random_map_skirmish_startup(state, session, setup, !gd::is_empty(state, package_startup));
}

Value _finish_random_map_skirmish_startup(State &state, const Value &session, DictRef setup, bool package_backed) {
	const DictRef view = gd::object_view(state, session);
	if (session_string(state, view, key::scenario_id) == key::empty) {
		return session;
	}
	const DictRef flags = session_flags(state, view);
	put(state, flags, key::generated_random_map_provenance, field_or_new_dict(state, setup, key::provenance));
	put(state, flags, key::generated_random_map_replay_metadata, field_or_new_dict(state, setup, key::replay_metadata));
	put(state, flags, key::generated_random_map_validation, field_or_new_dict(state, setup, key::validation));
	put(state, flags, key::generated_random_map_retry_status, field_or_new_dict(state, setup, key::retry_status));
	put(state, gd::as_dict(gd::index(state, flags, gd::str(key::generated_random_map_boundary))), key::adoption_path,
			gd::str(package_backed ? key::native_rmg_generated_package_saved_loaded_from_disk : key::legacy_skirmish_session_only_no_authored_browser_or_campaign));
	const DictRef boundary = gd::as_dict(gd::index(state, flags, gd::str(key::generated_random_map_boundary)));
	const Value draft = package_backed
			? gd::bool_value(false)
			: gd::call_method(state, gd::autoload(state, key::ContentService), key::has_generated_scenario_draft,
					{gd::str(session_string(state, view, key::scenario_id))});
	put(state, boundary, key::content_service_generated_draft, draft);
	const DictRef overworld = session_view::overworld(state, view);
	put(state, overworld, key::generated_random_map_provenance, field_or_new_dict(state, setup, key::provenance));
	put(state, overworld, key::generated_random_map_replay_metadata, field_or_new_dict(state, setup, key::replay_metadata));
	put(state, overworld, key::generated_random_map_validation, field_or_new_dict(state, setup, key::validation));
	put(state, overworld, key::generated_random_map_retry_status, field_or_new_dict(state, setup, key::retry_status));
	overworld_rules::normalize_overworld_state(state, view);
	// SessionState.active_session = session: the object (a view stands for it).
	const Value object = session.kind == Kind::Dict ? gd::view_object(state, session.ref) : session;
	gd::set_property(state, gd::autoload(state, key::SessionState), key::active_session, object);
	return object;
}

DictRef _random_map_retry_status(State &state, DictRef generated, DictRef report) {
	const bool ok = gd::bool_field(state, generated, key::ok, false);
	const DictRef status = state.new_dict();
	put(state, status, key::policy, gd::str(key::single_validated_attempt_no_automatic_retry_in_this_slice));
	put(state, status, key::attempt_count, gd::int_value(1));
	put(state, status, key::retry_count, gd::int_value(0));
	put(state, status, key::status, gd::str(ok ? key::pass : key::failed_before_launch));
	put(state, status, key::validation_status, gd::str(string_of(state, report, key::status, ok ? key::pass : key::fail)));
	put(state, status, key::failure_count, gd::int_value(gd::int_field(state, report, key::failure_count, 0)));
	put(state, status, key::warning_count, gd::int_value(gd::int_field(state, report, key::warning_count, 0)));
	return status;
}

DictRef _random_map_not_implemented_launch_report(State &state, DictRef generated, DictRef report) {
	const DictRef blocked = gd::deep_duplicate_dict(state, report);
	put(state, blocked, key::schema_id, gd::str(string_of(state, blocked, key::schema_id, key::generated_random_map_launch_validation_v1)));
	put(state, blocked, key::status, gd::str(key::fail));
	put(state, blocked, key::validation_status, gd::str(key::fail));
	put(state, blocked, key::failure_count, gd::int_value(gd::add(gd::int_field(state, blocked, key::failure_count, 0), 1)));
	const ArrayRef failures = gd::deep_duplicate_array(state, array_or_new(state, blocked, key::failures));
	const DictRef failure = state.new_dict();
	put(state, failure, key::code, gd::str(key::native_rmg_full_generation_not_implemented));
	put(state, failure, key::severity, gd::str(key::error));
	put(state, failure, key::path, gd::str(key::generated_random_map_skirmish_setup_full));
	put(state, failure, key::message, gd::str(key::generated_skirmish_startup_is_blocked_until));
	put(state, failure, key::full_generation_status, gd::str(string_of(state, generated, key::full_generation_status, key::empty)));
	put(state, failure, key::normalized_config, field_or_new_dict(state, generated, key::normalized_config));
	state.append(failures, gd::dict_value(failure));
	put(state, blocked, key::failures, gd::array_value(failures));
	return blocked;
}

Value _native_map_package_service(State &state) {
	return gd::class_instantiate(state, key::MapPackageService);
}

bool _is_legacy_compact_rmg_config(State &state, DictRef normalized) {
	return string_of(state, normalized, key::template_id, key::empty) == key::border_gate_compact_v1
			|| string_of(state, normalized, key::profile_id, key::empty) == key::border_gate_compact_profile_v1;
}

DictRef _random_map_legacy_compact_launch_report(State &state, DictRef generated, DictRef report) {
	const DictRef normalized = dict_or_new(state, generated, key::normalized_config);
	const DictRef legacy_report = gd::deep_duplicate_dict(state, report);
	put(state, legacy_report, key::schema_id, gd::str(key::native_rmg_legacy_compact_launch_block_report_v1));
	put(state, legacy_report, key::status, gd::str(key::fail));
	put(state, legacy_report, key::validation_status, gd::str(key::fail));
	put(state, legacy_report, key::error_code, gd::str(key::native_rmg_legacy_compact_launch_blocked));
	put(state, legacy_report, key::template_id, gd::str(string_of(state, normalized, key::template_id, key::empty)));
	put(state, legacy_report, key::profile_id, gd::str(string_of(state, normalized, key::profile_id, key::empty)));
	put(state, legacy_report, key::generation_status, gd::str(string_of(state, generated, key::status, key::empty)));
	put(state, legacy_report, key::full_generation_status, gd::str(string_of(state, generated, key::full_generation_status, key::empty)));
	put(state, legacy_report, key::launch_boundary, gd::str(key::legacy_compact_internal_fixture_only));
	put(state, legacy_report, key::message, gd::str(key::legacy_compact_generator_output_lacks_recovered));
	const ArrayRef failures = gd::deep_duplicate_array(state, array_or_new(state, legacy_report, key::failures));
	const DictRef failure = state.new_dict();
	put(state, failure, key::code, gd::str(key::native_rmg_legacy_compact_launch_blocked));
	put(state, failure, key::severity, gd::str(key::error));
	put(state, failure, key::path, gd::str(key::generated_random_map_skirmish_setup_normalized));
	put(state, failure, key::message, gd::index(state, legacy_report, gd::str(key::message)));
	put(state, failure, key::template_id, gd::str(string_of(state, normalized, key::template_id, key::empty)));
	put(state, failure, key::profile_id, gd::str(string_of(state, normalized, key::profile_id, key::empty)));
	put(state, failure, key::normalized_config, gd::dict_value(normalized));
	state.append(failures, gd::dict_value(failure));
	put(state, legacy_report, key::failures, gd::array_value(failures));
	put(state, legacy_report, key::failure_count, gd::int_value(state.array_size(failures)));
	return legacy_report;
}

bool _use_project_maps_dir(State &state) {
	return gd::os_has_feature(state, key::editor);
}

Atom _generated_map_package_dir(State &state) {
	return _use_project_maps_dir(state) ? key::res_maps : key::user_maps;
}

DictRef _native_package_setup_failure(State &state, Atom code, Atom message, Atom difficulty_id, DictRef report) {
	const DictRef failure = state.new_dict();
	put(state, failure, key::ok, gd::bool_value(false));
	put(state, failure, key::setup_kind, gd::str(key::generated_random_map_skirmish));
	put(state, failure, key::startup_source, gd::str(key::native_rmg_disk_package));
	put(state, failure, key::launch_mode, gd::str(key::skirmish));
	put(state, failure, key::difficulty, gd::str(normalize_difficulty(state, gd::str(difficulty_id))));
	put(state, failure, key::validation, gd::dict_value(report));
	const DictRef retry_status = state.new_dict();
	put(state, retry_status, key::status, gd::str(key::failed_before_launch));
	put(state, retry_status, key::attempt_count, gd::int_value(1));
	put(state, retry_status, key::retry_count, gd::int_value(0));
	put(state, retry_status, key::validation_status, gd::str(key::fail));
	put(state, failure, key::retry_status, gd::dict_value(retry_status));
	put(state, failure, key::failure_handoff, gd::str(gd::format(state, key::generated_skirmish_blocked_s, {gd::str(message)})));
	put(state, failure, key::error_code, gd::str(code));
	put(state, failure, key::campaign_adoption, gd::bool_value(false));
	put(state, failure, key::alpha_parity_claim, gd::bool_value(false));
	return failure;
}

DictRef _persist_and_load_generated_packages(State &state, const Value &service, DictRef adoption, DictRef generated) {
	const Value map_document = state.get(adoption, gd::str(key::map_document), Value());
	const Value scenario_document = state.get(adoption, gd::str(key::scenario_document), Value());
	if (map_document.kind == Kind::Nil || scenario_document.kind == Kind::Nil) {
		const DictRef missing = state.new_dict();
		put(state, missing, key::ok, gd::bool_value(false));
		put(state, missing, key::error_code, gd::str(key::missing_native_documents));
		put(state, missing, key::message, gd::str(key::native_package_adoption_did_not_return));
		return missing;
	}
	const Value adoption_map_ref = field_or_new_dict(state, adoption, key::map_ref);
	const Value document_map_id = gd::call_method(state, map_document, key::get_map_id, {});
	const Atom map_id = gd::stringify(state, ai::vget(state, adoption_map_ref, key::map_id, document_map_id));
	const Value adoption_scenario_ref = field_or_new_dict(state, adoption, key::scenario_ref);
	const Value document_scenario_id = gd::call_method(state, scenario_document, key::get_scenario_id, {});
	const Atom scenario_id = gd::stringify(state, ai::vget(state, adoption_scenario_ref, key::scenario_id, document_scenario_id));
	const Atom package_dir = _generated_map_package_dir(state);
	const DictRef package_identity = _generated_map_package_identity(state, generated, adoption);
	Atom package_stem = string_of(state, package_identity, key::package_stem, key::empty);
	if (package_stem == key::empty) {
		package_stem = _safe_package_stem(state, gd::format(state, key::s_s_8, {gd::str(map_id), gd::str(scenario_id)}));
	}
	const Atom map_path = gd::format(state, key::s_s_amap, {gd::str(package_dir), gd::str(package_stem)});
	const Atom scenario_path = gd::format(state, key::s_s_ascenario, {gd::str(package_dir), gd::str(package_stem)});
	const DictRef policy = generated_map_package_directory_policy(state);
	const DictRef save_options = state.new_dict();
	put(state, save_options, key::path_policy, gd::str(key::dev_res_maps_export_user_maps));
	put(state, save_options, key::directory_policy, gd::dict_value(policy));
	const DictRef map_save = gd::as_dict(gd::call_method(state, service, key::save_map_package,
			{map_document, gd::str(map_path), gd::dict_value(save_options)}));
	if (!gd::bool_field(state, map_save, key::ok, false)) {
		return map_save;
	}
	const DictRef map_load = gd::as_dict(gd::call_method(state, service, key::load_map_package, {gd::str(map_path)}));
	if (!gd::bool_field(state, map_load, key::ok, false)) {
		return map_load;
	}
	const DictRef saved_map_ref = dict_or_new(state, map_load, key::map_ref);
	if (gd::has_method(state, scenario_document, key::configure) && !gd::is_empty(state, saved_map_ref)) {
		const DictRef configuration = state.new_dict();
		put(state, configuration, key::scenario_id, gd::call_method(state, scenario_document, key::get_scenario_id, {}));
		put(state, configuration, key::scenario_hash, gd::call_method(state, scenario_document, key::get_scenario_hash, {}));
		put(state, configuration, key::map_ref, gd::dict_value(saved_map_ref));
		put(state, configuration, key::selection, gd::call_method(state, scenario_document, key::get_selection, {}));
		put(state, configuration, key::player_slots, gd::call_method(state, scenario_document, key::get_player_slots, {}));
		put(state, configuration, key::objectives, gd::call_method(state, scenario_document, key::get_objectives, {}));
		put(state, configuration, key::script_hooks, gd::call_method(state, scenario_document, key::get_script_hooks, {}));
		put(state, configuration, key::enemy_factions, gd::call_method(state, scenario_document, key::get_enemy_factions, {}));
		put(state, configuration, key::start_contract, gd::call_method(state, scenario_document, key::get_start_contract, {}));
		gd::call_method(state, scenario_document, key::configure, {gd::dict_value(configuration)});
	}
	const DictRef scenario_save = gd::as_dict(gd::call_method(state, service, key::save_scenario_package,
			{scenario_document, gd::str(scenario_path), gd::dict_value(save_options)}));
	if (!gd::bool_field(state, scenario_save, key::ok, false)) {
		return scenario_save;
	}
	const DictRef scenario_load = gd::as_dict(gd::call_method(state, service, key::load_scenario_package, {gd::str(scenario_path)}));
	if (!gd::bool_field(state, scenario_load, key::ok, false)) {
		return scenario_load;
	}
	const DictRef map_ref = dict_or_new(state, map_load, key::map_ref);
	const DictRef scenario_ref = dict_or_new(state, scenario_load, key::scenario_ref);
	const DictRef boundary = dict_or_new(state, adoption, key::session_boundary_record);
	if (string_of(state, boundary, key::scenario_id, key::empty) == key::empty) {
		const Value document_id = gd::call_method(state, scenario_document, key::get_scenario_id, {});
		put(state, boundary, key::scenario_id, gd::str(gd::stringify(state, state.get(scenario_ref, gd::str(key::scenario_id), document_id))));
	}
	if (string_of(state, boundary, key::map_id, key::empty) == key::empty) {
		const Value document_id = gd::call_method(state, map_document, key::get_map_id, {});
		put(state, boundary, key::map_id, gd::str(gd::stringify(state, state.get(map_ref, gd::str(key::map_id), document_id))));
	}
	if (string_of(state, boundary, key::session_id, key::empty) == key::empty) {
		put(state, boundary, key::session_id, gd::str(gd::format(state, key::native_rmg_session_s, {gd::str(string_of(state, boundary, key::map_id, key::empty))})));
	}
	if (string_of(state, boundary, key::hero_id, key::empty) == key::empty) {
		put(state, boundary, key::hero_id, gd::str(key::hero_lyra));
	}
	put(state, boundary, key::map_package_ref, gd::dict_value(map_ref));
	put(state, boundary, key::scenario_package_ref, gd::dict_value(scenario_ref));
	put(state, boundary, key::launch_mode, gd::str(key::skirmish));
	put(state, boundary, key::runtime_call_site_adoption, gd::bool_value(true));
	put(state, boundary, key::generated_record_policy, gd::str(key::disk_package_loaded_documents_only));
	put(state, boundary, key::content_service_generated_draft, gd::bool_value(false));
	put(state, boundary, key::legacy_json_scenario_record, gd::bool_value(false));
	put(state, boundary, key::map_package_path, gd::str(map_path));
	put(state, boundary, key::scenario_package_path, gd::str(scenario_path));
	const DictRef result = state.new_dict();
	put(state, result, key::ok, gd::bool_value(true));
	put(state, result, key::schema_id, gd::str(key::aurelion_native_rmg_disk_package_startup_v1));
	put(state, result, key::directory_policy, gd::dict_value(policy));
	put(state, result, key::package_stem, gd::str(package_stem));
	put(state, result, key::package_identity, gd::dict_value(package_identity));
	put(state, result, key::map_path, gd::str(map_path));
	put(state, result, key::scenario_path, gd::str(scenario_path));
	put(state, result, key::map_save, gd::dict_value(_public_package_write_result(state, map_save)));
	put(state, result, key::scenario_save, gd::dict_value(_public_package_write_result(state, scenario_save)));
	put(state, result, key::map_load, gd::dict_value(_public_package_load_result(state, map_load)));
	put(state, result, key::scenario_load, gd::dict_value(_public_package_load_result(state, scenario_load)));
	put(state, result, key::map_ref, gd::dict_value(map_ref));
	put(state, result, key::scenario_ref, gd::dict_value(scenario_ref));
	put(state, result, key::session_boundary_record, gd::dict_value(boundary));
	put(state, result, key::storage_policy, gd::str(key::generated_package_saved_loaded_from_maps_dir));
	put(state, result, key::legacy_json_scenario_record, gd::bool_value(false));
	return result;
}

DictRef _public_package_load_result(State &state, DictRef load_result) {
	const DictRef cleaned = state.new_dict();
	for (const Atom name : {key::ok, key::status, key::operation, key::path, key::package_hash, key::storage_policy, key::report}) {
		Value found;
		if (state.lookup(load_result, gd::str(name), found)) {
			put(state, cleaned, name, found);
		}
	}
	Value found;
	if (state.lookup(load_result, gd::str(key::map_ref), found)) {
		put(state, cleaned, key::map_ref, found);
	}
	if (state.lookup(load_result, gd::str(key::scenario_ref), found)) {
		put(state, cleaned, key::scenario_ref, found);
	}
	return cleaned;
}

DictRef _public_package_write_result(State &state, DictRef write_result) {
	const DictRef cleaned = state.new_dict();
	for (const Atom name : {key::ok, key::status, key::operation, key::path, key::package_hash, key::report}) {
		Value found;
		if (state.lookup(write_result, gd::str(name), found)) {
			put(state, cleaned, name, found);
		}
	}
	return cleaned;
}

Atom _safe_package_stem(State &state, Atom value) {
	const Atom stem = _safe_package_token(state, gd::str(value), key::generated_map_2);
	return stem != key::empty ? stem : key::generated_map;
}

DictRef _generated_map_package_identity(State &state, DictRef generated, DictRef adoption) {
	const DictRef normalized = dict_or_new(state, generated, key::normalized_config);
	const DictRef report = generated_report(state, generated);
	const DictRef metrics = dict_or_new(state, report, key::metrics);
	const Value map_document = state.get(adoption, gd::str(key::map_document), Value());
	int64_t width = gd::to_int(state, state.get(normalized, gd::str(key::width), state.get(metrics, gd::str(key::width), gd::int_value(0))));
	int64_t height = gd::to_int(state, state.get(normalized, gd::str(key::height), state.get(metrics, gd::str(key::height), gd::int_value(0))));
	int64_t level_count = gd::to_int(state, state.get(normalized, gd::str(key::level_count), state.get(metrics, gd::str(key::level_count), gd::int_value(1))));
	if (map_document.kind != Kind::Nil) {
		if (width <= 0) {
			width = gd::to_int(state, gd::call_method(state, map_document, key::get_width, {}));
		}
		if (height <= 0) {
			height = gd::to_int(state, gd::call_method(state, map_document, key::get_height, {}));
		}
		if (level_count <= 0) {
			level_count = gd::to_int(state, gd::call_method(state, map_document, key::get_level_count, {}));
		}
	}
	int64_t player_count = gd::to_int(state, state.get(normalized, gd::str(key::player_count), state.get(metrics, gd::str(key::player_slot_count), gd::int_value(0))));
	if (player_count <= 0) {
		const DictRef player_assignment = dict_or_new(state, generated, key::player_assignment);
		const ArrayRef player_slots = array_or_new(state, player_assignment, key::player_slots);
		player_count = state.array_size(player_slots);
	}
	if (player_count <= 0) {
		const DictRef player_starts = dict_or_new(state, generated, key::player_starts);
		player_count = gd::int_field(state, player_starts, key::start_count, 0);
	}
	const Atom size_token = _generated_map_package_size_token(state, string_of(state, normalized, key::size_class_id, key::map));
	const Atom creative_name = _generated_map_package_creative_name(state, normalized, generated);
	const Atom hash_token = _generated_map_package_short_hash(state, normalized);
	Atom package_stem = _safe_package_stem(state, join(state, key::dash, {size_token, creative_name, hash_token}));
	if (text_length(state.text(package_stem)) > 120) {
		package_stem = _safe_package_stem(state, join(state, key::dash, {size_token, creative_name, hash_token}));
	}
	const DictRef identity = state.new_dict();
	put(state, identity, key::schema_id, gd::str(key::aurelion_native_rmg_package_filename_identity_v1));
	put(state, identity, key::package_stem, gd::str(package_stem));
	put(state, identity, key::creative_name, gd::str(creative_name));
	put(state, identity, key::template_id, gd::str(string_of(state, normalized, key::template_id, key::empty)));
	put(state, identity, key::profile_id, gd::str(_native_random_map_profile_id(state, normalized)));
	put(state, identity, key::size_class_id, gd::str(string_of(state, normalized, key::size_class_id, key::empty)));
	put(state, identity, key::width, gd::int_value(width));
	put(state, identity, key::height, gd::int_value(height));
	put(state, identity, key::level_count, gd::int_value(compat::engine_max<int64_t>(1, level_count)));
	put(state, identity, key::player_count, gd::int_value(compat::engine_max<int64_t>(1, player_count)));
	put(state, identity, key::water_mode, gd::str(string_of(state, normalized, key::water_mode, key::empty)));
	put(state, identity, key::normalized_seed, gd::str(gd::stringify(state, state.get(normalized, gd::str(key::normalized_seed),
			state.get(normalized, gd::str(key::seed), gd::str(key::empty))))));
	put(state, identity, key::short_hash, gd::str(hash_token));
	put(state, identity, key::filename_style, gd::str(key::size_creative_name_hash_lowercase_kebab));
	put(state, identity, key::detailed_identity_storage, gd::str(key::package_metadata_refs_not_filename));
	return identity;
}

Atom _generated_map_package_size_token(State &state, Atom size_class_id) {
	std::string raw = lowered(state.text(gd::strip_edges(state, size_class_id)));
	if (raw.compare(0, 6, "homm3_") == 0) {
		raw = raw.substr(6);
	}
	const Atom replaced = gd::replace(state, state.intern(raw), key::_, key::dash);
	if (replaced == key::extra_large_2) {
		return replaced;
	}
	return _safe_package_token(state, gd::str(replaced), key::map);
}

Atom _generated_map_package_creative_name(State &state, DictRef normalized, DictRef generated) {
	std::vector<Atom> parts = identity_parts(state, normalized);
	parts.push_back(gd::stringify(state, state.get(generated, gd::str(key::validation_status), gd::str(key::empty))));
	const Atom name_key = join(state, key::bar, parts);
	static constexpr Atom kFirstWords[] = {
		key::amber, key::ash, key::bracken, key::cinder, key::dawn, key::dusk, key::ember, key::fallow,
		key::frost, key::glass, key::gold, key::hollow, key::iron, key::jade, key::mist, key::moon,
		key::red, key::silver, key::sun, key::thorn, key::veil, key::wild, key::wind, key::winter,
	};
	static constexpr Atom kSecondWords[] = {
		key::barrow, key::brook, key::cairn, key::field, key::ford, key::gate, key::grove, key::hearth,
		key::keep, key::lantern, key::march, key::mire, key::moor, key::pass, key::ridge, key::road,
		key::sanctum, key::spire, key::stone, key::watch, key::wood, key::yard,
	};
	static constexpr Atom kThirdWords[] = {
		key::bend, key::crossing, key::deep, key::fall, key::fen, key::glade, key::hollow, key::marsh,
		key::meadow, key::reach, key::rise, key::shore, key::spring, key::trail, key::vale, key::way,
	};
	constexpr int64_t kFirstCount = static_cast<int64_t>(sizeof(kFirstWords) / sizeof(kFirstWords[0]));
	constexpr int64_t kSecondCount = static_cast<int64_t>(sizeof(kSecondWords) / sizeof(kSecondWords[0]));
	constexpr int64_t kThirdCount = static_cast<int64_t>(sizeof(kThirdWords) / sizeof(kThirdWords[0]));
	const Atom a = kFirstWords[_stable_name_index(state, gd::format(state, key::s_first, {gd::str(name_key)}), kFirstCount)];
	const Atom b = kSecondWords[_stable_name_index(state, gd::format(state, key::s_second, {gd::str(name_key)}), kSecondCount)];
	const Atom c = kThirdWords[_stable_name_index(state, gd::format(state, key::s_third, {gd::str(name_key)}), kThirdCount)];
	return _safe_package_stem(state, gd::format(state, key::s_s_s_8, {gd::str(a), gd::str(b), gd::str(c)}));
}

int64_t _stable_name_index(State &state, Atom value, int64_t modulo) {
	if (modulo <= 0) {
		return 0;
	}
	int64_t hash_value = 2166136261;
	for (const uint32_t point : code_points(state.text(value))) {
		hash_value = gd::mul(hash_value ^ static_cast<int64_t>(point), 16777619) & 0x7fffffff;
	}
	return hash_value % modulo;
}

Atom _generated_map_package_short_hash(State &state, DictRef normalized) {
	return _stable_hash_hex8(state, join(state, key::bar, identity_parts(state, normalized)));
}

Atom _stable_hash_hex8(State &state, Atom value) {
	int64_t hash_value = 2166136261;
	for (const uint32_t point : code_points(state.text(value))) {
		hash_value = hash_value ^ static_cast<int64_t>(point);
		hash_value = gd::mul(hash_value, 16777619) & 0xffffffff;
	}
	return _hex8(state, hash_value);
}

Atom _hex8(State &state, int64_t value) {
	static constexpr char kHexChars[] = "0123456789abcdef";
	std::string output;
	for (const int shift : {28, 24, 20, 16, 12, 8, 4, 0}) {
		output += kHexChars[(value >> shift) & 0xf];
	}
	return state.intern(output);
}

Atom _native_random_map_profile_id(State &state, DictRef normalized) {
	const Atom profile_id = gd::strip_edges(state, string_of(state, normalized, key::profile_id, key::empty));
	if (profile_id != key::empty) {
		return profile_id;
	}
	if (gd::strip_edges(state, string_of(state, normalized, key::template_selection_authority, key::empty)) == key::h3maped_exe_rng_original_catalog) {
		return key::h3maped_exe_rng_profile;
	}
	if (gd::strip_edges(state, string_of(state, normalized, key::source_template_authority, key::empty)) == key::h3maped_exe_rng) {
		return key::h3maped_exe_rng_profile;
	}
	return key::empty;
}

Atom _safe_package_token(State &state, const Value &value, Atom fallback) {
	const std::string raw = lowered(state.text(gd::strip_edges(state, gd::stringify(state, value))));
	std::string token;
	bool previous_dash = false;
	for (const uint32_t code : code_points(raw)) {
		const bool allowed = (code >= 97 && code <= 122) || (code >= 48 && code <= 57);
		if (allowed) {
			token += static_cast<char>(code);
			previous_dash = false;
		} else if (!previous_dash && !token.empty()) {
			token += '-';
			previous_dash = true;
		}
	}
	while (!token.empty() && token.front() == '-') {
		token.erase(0, 1);
	}
	while (!token.empty() && token.back() == '-') {
		token.pop_back();
	}
	return !token.empty() ? state.intern(token) : fallback;
}

DictRef _native_random_map_generated_identity(State &state, DictRef generated, DictRef adoption, DictRef persisted) {
	const DictRef normalized = dict_or_new(state, generated, key::normalized_config);
	const DictRef identity = dict_or_new(state, generated, key::deterministic_identity);
	const DictRef scenario_ref = dict_or_new(state, persisted, key::scenario_ref);
	const DictRef map_ref = dict_or_new(state, persisted, key::map_ref);
	Atom stable_signature = string_of(state, identity, key::signature, key::empty);
	const Value report_signature = nested_get(state, generated, key::validation_report, key::full_output_signature, gd::str(key::empty));
	Atom full_output_signature = gd::stringify(state, state.get(generated, gd::str(key::full_output_signature), report_signature));
	if (stable_signature == key::empty) {
		stable_signature = gd::replace(state, string_of(state, map_ref, key::package_hash, key::empty), key::fnv1a32, key::empty);
	}
	if (full_output_signature == key::empty) {
		full_output_signature = stable_signature;
	}
	const DictRef result = state.new_dict();
	const Value adoption_scenario_id = nested_get(state, adoption, key::scenario_ref, key::scenario_id, gd::str(key::empty));
	put(state, result, key::scenario_id, gd::str(gd::stringify(state, state.get(scenario_ref, gd::str(key::scenario_id), adoption_scenario_id))));
	put(state, result, key::map_id, gd::str(gd::stringify(state, state.get(map_ref, gd::str(key::map_id),
			state.get(identity, gd::str(key::map_id), gd::str(key::empty))))));
	put(state, result, key::map_package_path, gd::str(string_of(state, persisted, key::map_path, key::empty)));
	put(state, result, key::scenario_package_path, gd::str(string_of(state, persisted, key::scenario_path, key::empty)));
	put(state, result, key::stable_signature, gd::str(stable_signature));
	put(state, result, key::materialized_map_signature, gd::str(stable_signature != key::empty ? stable_signature : full_output_signature));
	put(state, result, key::full_output_signature, gd::str(full_output_signature));
	put(state, result, key::generator_version, gd::str(string_of(state, normalized, key::generator_version, key::empty)));
	put(state, result, key::template_id, gd::str(string_of(state, normalized, key::template_id, key::empty)));
	put(state, result, key::profile_id, gd::str(_native_random_map_profile_id(state, normalized)));
	put(state, result, key::size_class_id, gd::str(string_of(state, normalized, key::size_class_id, key::empty)));
	put(state, result, key::normalized_seed, gd::str(string_of(state, normalized, key::normalized_seed, key::empty)));
	put(state, result, key::content_manifest_fingerprint, gd::str(key::native_package_no_authored_scenario_json));
	return result;
}

DictRef _native_random_map_provenance(State &state, DictRef input_config, DictRef generated, DictRef adoption, DictRef persisted, DictRef retry_status) {
	const DictRef provenance = state.new_dict();
	put(state, provenance, key::schema_id, gd::str(key::aurelion_native_rmg_disk_package_provenance_v1));
	put(state, provenance, key::input_config, gd::dict_value(gd::deep_duplicate_dict(state, input_config)));
	put(state, provenance, key::normalized_config, field_or_new_dict(state, generated, key::normalized_config));
	put(state, provenance, key::generated_identity, gd::dict_value(_native_random_map_generated_identity(state, generated, adoption, persisted)));
	put(state, provenance, key::retry_status, gd::dict_value(retry_status));
	put(state, provenance, key::map_ref, field_or_new_dict(state, persisted, key::map_ref));
	put(state, provenance, key::scenario_ref, field_or_new_dict(state, persisted, key::scenario_ref));
	put(state, provenance, key::directory_policy, field_or_new_dict(state, persisted, key::directory_policy));
	const DictRef boundaries = state.new_dict();
	put(state, boundaries, key::authored_content_writeback, gd::bool_value(false));
	put(state, boundaries, key::content_scenarios_json, gd::bool_value(false));
	put(state, boundaries, key::generated_scenario_draft_registry, gd::bool_value(false));
	put(state, boundaries, key::legacy_json_scenario_record, gd::bool_value(false));
	put(state, provenance, key::boundaries, gd::dict_value(boundaries));
	return provenance;
}

Atom _native_random_map_setup_summary(State &state, DictRef generated, DictRef adoption, DictRef persisted, DictRef report, DictRef retry_status, Atom difficulty_id) {
	(void)adoption;
	const DictRef normalized = dict_or_new(state, generated, key::normalized_config);
	std::vector<Atom> lines;
	lines.push_back(key::generated_skirmish_setup);
	lines.push_back(gd::format(state, key::seed_s_template_s_profile_s, {
			gd::str(string_of(state, normalized, key::normalized_seed, key::empty)),
			gd::str(string_of(state, normalized, key::template_id, key::empty)),
			gd::str(string_of(state, normalized, key::profile_id, key::empty)),
	}));
	lines.push_back(gd::format(state, key::size_dx_d_l_d_difficulty, {
			gd::int_value(gd::int_field(state, normalized, key::width, 0)),
			gd::int_value(gd::int_field(state, normalized, key::height, 0)),
			gd::int_value(gd::int_field(state, normalized, key::level_count, 1)),
			gd::str(difficulty_label(state, difficulty_id)),
	}));
	lines.push_back(gd::format(state, key::packages_s_s, {
			gd::str(string_of(state, persisted, key::map_path, key::empty)),
			gd::str(string_of(state, persisted, key::scenario_path, key::empty)),
	}));
	const Value generated_status = state.get(generated, gd::str(key::validation_status), gd::str(key::empty));
	lines.push_back(gd::format(state, key::validation_s_attempts_d_retries_d, {
			gd::str(gd::stringify(state, state.get(report, gd::str(key::status), generated_status))),
			gd::int_value(gd::int_field(state, retry_status, key::attempt_count, 1)),
			gd::int_value(gd::int_field(state, retry_status, key::retry_count, 0)),
	}));
	lines.push_back(key::boundary_native_packages_loaded_from_disk);
	return join(state, key::newline, lines);
}

DictRef _random_map_retry_policy(State &state, DictRef retry_policy) {
	const DictRef policy = player_retry_policy(state);
	const ArrayRef names = gd::keys(state, retry_policy);
	for (const Value &name : gd::items(state, gd::array_value(names))) {
		state.set(policy, name, gd::index(state, retry_policy, name));
	}
	put(state, policy, key::max_attempts, gd::int_value(compat::engine_clamp<int64_t>(gd::int_field(state, policy, key::max_attempts, 1), 1, 5)));
	if (string_of(state, policy, key::mode, key::empty) == key::empty) {
		put(state, policy, key::mode, gd::str(key::none));
	}
	return policy;
}

DictRef _random_map_retry_attempt_config(State &state, DictRef input_config, int64_t attempt_index, DictRef retry_policy) {
	DictRef config = gd::deep_duplicate_dict(state, input_config);
	if (attempt_index > 0) {
		// retry_policy.get("fallback_config", {}) is Dictionary and not empty.
		Value fallback;
		if (state.lookup(retry_policy, gd::str(key::fallback_config), fallback) && fallback.kind == Kind::Dict
				&& !gd::is_empty(state, fallback.ref)) {
			config = gd::deep_duplicate_dict(state, fallback.ref);
		}
	}
	if (attempt_index > 0 && state.text(string_of(state, retry_policy, key::mode, key::empty)).find(state.text(key::seed_salt)) != std::string::npos) {
		const Atom salted_seed = gd::format(state, key::s_retry_d, {gd::str(string_of(state, config, key::seed, key::k_0)), gd::int_value(attempt_index)});
		const DictRef seed_record = random_map_h3maped_seed_record(state, salted_seed);
		put(state, config, key::seed, gd::str(string_of(state, seed_record, key::normalized_seed, salted_seed)));
		put(state, config, key::seed_identity, gd::dict_value(seed_record));
	}
	return config;
}

DictRef _random_map_setup_attempt_record(State &state, DictRef setup, DictRef input_config, int64_t attempt_number, int64_t max_attempts) {
	const bool ok = gd::bool_field(state, setup, key::ok, false);
	const DictRef validation = dict_or_new(state, setup, key::validation);
	const DictRef normalized = _random_map_attempt_native_normalized_config(state, setup, input_config);
	const bool retryable = !ok && attempt_number < max_attempts;
	const DictRef record = state.new_dict();
	put(state, record, key::attempt, gd::int_value(attempt_number));
	put(state, record, key::max_attempts, gd::int_value(max_attempts));
	put(state, record, key::ok, gd::bool_value(ok));
	put(state, record, key::seed, gd::str(string_of(state, normalized, key::seed, key::empty)));
	put(state, record, key::template_id, gd::str(string_of(state, normalized, key::template_id, key::empty)));
	const Value profile_id_fallback = nested_get(state, normalized, key::profile, key::id, gd::str(key::empty));
	put(state, record, key::profile_id, gd::str(gd::stringify(state, state.get(normalized, gd::str(key::profile_id), profile_id_fallback))));
	put(state, record, key::scenario_id, gd::str(string_of(state, setup, key::scenario_id, key::empty)));
	put(state, record, key::validation_status, gd::str(string_of(state, validation, key::status, ok ? key::pass : key::fail)));
	put(state, record, key::failure_count, gd::int_value(gd::int_field(state, validation, key::failure_count, 0)));
	put(state, record, key::warning_count, gd::int_value(gd::int_field(state, validation, key::warning_count, 0)));
	put(state, record, key::validation, gd::dict_value(validation));
	const DictRef retry_decision = state.new_dict();
	put(state, retry_decision, key::will_retry, gd::bool_value(retryable));
	put(state, retry_decision, key::reason, gd::str(retryable ? key::retry_policy_has_remaining_attempt : (ok ? key::accepted_valid_generation : key::attempt_limit_reached)));
	put(state, retry_decision, key::next_attempt, gd::int_value(retryable ? gd::add(attempt_number, 1) : 0));
	put(state, record, key::retry_decision, gd::dict_value(retry_decision));
	return record;
}

DictRef _random_map_attempt_native_normalized_config(State &state, DictRef setup, DictRef input_config) {
	const DictRef provenance = dict_or_new(state, setup, key::provenance);
	DictRef normalized = dict_or_new(state, provenance, key::normalized_config);
	if (gd::is_empty(state, normalized)) {
		const DictRef validation = dict_or_new(state, setup, key::validation);
		const ArrayRef failures = array_or_new(state, validation, key::failures);
		const int64_t failure_count = state.array_size(failures);
		for (int64_t index = 0; index < failure_count; ++index) {
			const Value failure = state.at(failures, index);
			if (failure.kind != Kind::Dict) {
				continue;
			}
			// failure.get("normalized_config", {}) is Dictionary: a missing one is a new {}.
			Value found;
			const bool has = state.lookup(failure.ref, gd::str(key::normalized_config), found);
			if (!has || found.kind == Kind::Dict) {
				normalized = has ? found.ref : state.new_dict();
				break;
			}
		}
		if (gd::is_empty(state, normalized)) {
			Value identity_value;
			const bool has_identity = state.lookup(validation, gd::str(key::deterministic_identity), identity_value);
			if (!has_identity || identity_value.kind == Kind::Dict) {
				const DictRef identity = has_identity ? identity_value.ref : state.new_dict();
				Value found;
				const bool has = state.lookup(identity, gd::str(key::normalized_config), found);
				if (!has || found.kind == Kind::Dict) {
					normalized = has ? found.ref : state.new_dict();
				}
			}
		}
	}
	if (gd::is_empty(state, normalized)) {
		normalized = random_map_generator_rules::normalize_config(state, input_config);
	}
	return normalized;
}

DictRef _random_map_retry_status_from_attempts(State &state, ArrayRef attempts, bool ok, DictRef retry_policy) {
	const int64_t attempt_count = state.array_size(attempts);
	Atom status = key::pass;
	if (ok && attempt_count > 1) {
		status = key::pass_after_retry;
	} else if (!ok) {
		status = key::failed_before_launch;
	}
	Atom validation_status = ok ? key::pass : key::fail;
	if (attempt_count > 0) {
		validation_status = gd::stringify(state, ai::vget(state, state.at(attempts, attempt_count - 1), key::validation_status, gd::str(validation_status)));
	}
	const DictRef result = state.new_dict();
	put(state, result, key::policy, gd::str(key::bounded_player_setup_retry_visible));
	put(state, result, key::attempt_count, gd::int_value(attempt_count));
	put(state, result, key::retry_count, gd::int_value(compat::engine_max<int64_t>(0, attempt_count - 1)));
	put(state, result, key::max_attempts, gd::int_value(gd::int_field(state, retry_policy, key::max_attempts, attempt_count)));
	put(state, result, key::mode, gd::str(string_of(state, retry_policy, key::mode, key::none)));
	put(state, result, key::status, gd::str(status));
	put(state, result, key::validation_status, gd::str(validation_status));
	put(state, result, key::failure_count, gd::int_value(attempt_count > 0
			? gd::to_int(state, ai::vget(state, state.at(attempts, attempt_count - 1), key::failure_count, gd::int_value(0)))
			: 0));
	put(state, result, key::warning_count, gd::int_value(attempt_count > 0
			? gd::to_int(state, ai::vget(state, state.at(attempts, attempt_count - 1), key::warning_count, gd::int_value(0)))
			: 0));
	return result;
}

Atom _random_map_failure_handoff(State &state, DictRef report, DictRef retry_status) {
	return gd::format(state, key::generated_skirmish_blocked_validation_s_after, {
			gd::str(string_of(state, report, key::status, key::fail)),
			gd::int_value(gd::int_field(state, retry_status, key::attempt_count, 1)),
			gd::int_value(gd::int_field(state, retry_status, key::retry_count, 0)),
	});
}

Atom _random_map_failure_setup_summary(State &state, DictRef report, DictRef retry_status, ArrayRef attempts) {
	std::vector<Atom> lines;
	lines.push_back(key::generated_skirmish_setup_blocked);
	const Value attempt_count = state.get(retry_status, gd::str(key::attempt_count), gd::int_value(0));
	lines.push_back(gd::format(state, key::validation_s_attempts_d_d_retries, {
			gd::str(string_of(state, report, key::status, key::fail)),
			gd::int_value(gd::int_field(state, retry_status, key::attempt_count, 0)),
			gd::int_value(gd::to_int(state, state.get(retry_status, gd::str(key::max_attempts), attempt_count))),
			gd::int_value(gd::int_field(state, retry_status, key::retry_count, 0)),
	}));
	// for failure in report.get("failures", []): a copy, as the body calls the engine.
	std::vector<Value> failures;
	for (const Value &failure : gd::field_items(state, report, gd::str(key::failures))) {
		failures.push_back(failure);
	}
	for (const Value &failure : failures) {
		if (lines.size() >= 5) {
			break;
		}
		lines.push_back(gd::format(state, key::failure_s, {gd::str(_stringify_report_value(state, failure))}));
	}
	const int64_t size = state.array_size(attempts);
	if (size > 0) {
		const Value last = state.at(attempts, size - 1);
		const DictRef last_attempt = last.kind == Kind::Dict ? last.ref : state.new_dict();
		const DictRef retry_decision = dict_or_new(state, last_attempt, key::retry_decision);
		lines.push_back(gd::format(state, key::retry_decision_s, {gd::str(string_of(state, retry_decision, key::reason, key::attempt_limit_reached))}));
	}
	lines.push_back(key::boundary_no_session_save_campaign_adoption);
	return join(state, key::newline, lines);
}

Atom _stringify_report_value(State &state, const Value &value) {
	if (value.kind == Kind::Dict || value.kind == Kind::Array) {
		return gd::engine_json_stringify(state, value);
	}
	return gd::stringify(state, value);
}

DictRef _random_map_replay_metadata(State &state, DictRef provenance, DictRef identity, DictRef retry_status) {
	const DictRef replay = state.new_dict();
	put(state, replay, key::schema_id, gd::str(key::generated_random_map_replay_contract_v2));
	put(state, replay, key::replay_contract_version, gd::int_value(2));
	put(state, replay, key::source, gd::str(key::skirmish_random_map_seed_config_export_stream));
	const Value input_config = field_or_new_dict(state, provenance, key::input_config);
	put(state, replay, key::generator_config, duplicate_deep(state, state.get(provenance, gd::str(key::generator_config), input_config)));
	put(state, replay, key::generated_identity, gd::dict_value(identity));
	put(state, replay, key::materialization, field_or_new_dict(state, provenance, key::materialization));
	put(state, replay, key::generated_export, field_or_new_dict(state, provenance, key::generated_export));
	put(state, replay, key::retry_status, gd::dict_value(retry_status));
	put(state, replay, key::content_manifest_fingerprint, gd::str(string_of(state, provenance, key::content_manifest_fingerprint, key::empty)));
	put(state, replay, key::replay_boundary, gd::str(key::versioned_seed_config_identity_export_stream_and_materialized_map_signature_contract));
	return replay;
}

} // namespace scenario_select_rules

} // namespace aurelion::rules::port
