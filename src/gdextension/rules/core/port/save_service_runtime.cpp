// SaveService: saving the running game (the receipts and cached recoveries,
// the runtime save, trusted live autosaves, the generated opening's autosave)
// and the runtime save profile, with ProfileLog's two clock helpers.

#include "aurelion_rules/port/save_service.hpp"
#include "aurelion_rules/port/overworld_rules_panels.hpp"

#include "aurelion_rules/port/session_state_store.hpp"
#include "aurelion_rules/port/town_rules_actions.hpp"

#include <cstdint>
#include <string>

namespace aurelion::rules::port::save_service {

namespace {

using state::Kind;
namespace key = state::key;

// SaveService's constants.
constexpr Atom kSlotTypeManual = key::manual;
constexpr Atom kSlotTypeFile = key::file;
constexpr Atom kSlotTypeAutosave = key::autosave;
constexpr int64_t kManualSlotIds[] = { 1, 2, 3 };
constexpr Atom kTransitionAutosaveIntentFlags[] = {
	key::runtime_autosave_dirty,
	key::runtime_autosave_pending_intent,
	key::runtime_autosave_pending_reason,
	key::runtime_autosave_pending_route,
	key::runtime_autosave_pending_game_state,
	key::runtime_autosave_pending_unix,
};
constexpr Atom kGeneratedOpeningAutosaveForceFailureEnv = key::HEROES_LIKE_GENERATED_OPENING_AUTOSAVE_FORCE_FAILURE;
constexpr Atom kGeneratedOpeningAutosavePendingFlag = key::generated_overworld_deferred_autosave_pending;
constexpr Atom kGeneratedOpeningAutosaveBriefingDeferredFlag = key::generated_overworld_command_briefing_autosave_deferred;
constexpr Atom kGeneratedOpeningAutosaveCompletedFlag = key::generated_overworld_initial_autosave_completed;

// The fields _owned_payload_from_normalized_detached_session copies, in its
// literal's order; _runtime_payload_for_save copies the first ten the same way.
constexpr Atom kSessionPayloadFields[] = {
	key::save_version,
	key::session_id,
	key::scenario_id,
	key::hero_id,
	key::day,
	key::difficulty,
	key::launch_mode,
	key::game_state,
	key::scenario_status,
	key::scenario_summary,
	key::overworld,
	key::battle,
	key::flags,
};
constexpr size_t kSessionScalarFieldCount = 10;

void put(State &state, DictRef dict, Atom name, const Value &value) {
	state.set(dict, gd::str(name), value);
}

// String(d.get(name, fallback)).
Atom string_of(State &state, DictRef dict, Atom name, Atom fallback) {
	return gd::stringify(state, state.get(dict, gd::str(name), gd::str(fallback)));
}

// d.get(name, {}) if d.get(name, {}) is Dictionary else {}: the field, or a new {}.
DictRef dict_field_or_new(State &state, DictRef dict, Atom name) {
	Value found;
	if (state.lookup(dict, gd::str(name), found) && found.kind == Kind::Dict) {
		return found.ref;
	}
	return state.new_dict();
}

// d.get(name, {}) and d.get(name, []) as values: the field, or a new container.
Value field_or_new_dict(State &state, DictRef dict, Atom name) {
	Value found;
	if (state.lookup(dict, gd::str(name), found)) {
		return found;
	}
	return gd::dict_value(state.new_dict());
}

Value field_or_new_array(State &state, DictRef dict, Atom name) {
	Value found;
	if (state.lookup(dict, gd::str(name), found)) {
		return found;
	}
	return gd::array_value(state.new_array());
}

// session.<name> of a session's view.
Value session_field(State &state, DictRef view, Atom name) {
	return gd::index(state, view, gd::str(name));
}

// session.flags (SessionData types it Dictionary).
DictRef session_flags(State &state, const Value &session) {
	return gd::as_dict(session_field(state, gd::object_view(state, session), key::flags));
}

// The session a host call takes: the object (a view stands for it), or null.
Value session_object(State &state, const Value &session) {
	return session.kind == Kind::Dict ? gd::view_object(state, session.ref) : session;
}

// The SaveService autoload's var `name`.
Value service_member(State &state, Atom name) {
	return gd::member(state, gd::autoload(state, key::SaveService), name);
}

// {"ok": true, "recovered": false, "live_valid": true, "reason": ..., "retained_manual_name": ...}.
DictRef verified_recovery(State &state, Atom reason, Atom retained_manual_name) {
	const DictRef recovery = state.new_dict();
	put(state, recovery, key::ok, gd::bool_value(true));
	put(state, recovery, key::recovered, gd::bool_value(false));
	put(state, recovery, key::live_valid, gd::bool_value(true));
	put(state, recovery, key::reason, gd::str(reason));
	put(state, recovery, key::retained_manual_name, gd::str(retained_manual_name));
	return recovery;
}

// {"ok": ok, "path": path, "summary": summary, "message": message}.
DictRef save_result(State &state, bool ok, Atom path, DictRef summary, Atom message) {
	const DictRef result = state.new_dict();
	put(state, result, key::ok, gd::bool_value(ok));
	put(state, result, key::path, gd::str(path));
	put(state, result, key::summary, gd::dict_value(summary));
	put(state, result, key::message, gd::str(message));
	return result;
}

// SAVE_DIR.path_join(save_file_name + NAMED_SAVE_SUFFIX) (String::path_join;
// SAVE_DIR is not empty and does not end in "/").
Atom named_save_path(State &state, Atom save_file_name) {
	const std::string file = state.text(save_file_name) + state.text(key::save_json);
	std::string joined = state.text(key::user_saves);
	if (file[0] != '/') {
		joined += '/';
	}
	joined += file;
	return state.intern(joined);
}

// The generated opening's flags on a payload's or a session's flags: pending
// and briefing-deferred erased, completed set.
void mark_generated_opening_autosave_completed(State &state, DictRef flags) {
	state.erase(flags, gd::str(kGeneratedOpeningAutosavePendingFlag));
	state.erase(flags, gd::str(kGeneratedOpeningAutosaveBriefingDeferredFlag));
	put(state, flags, kGeneratedOpeningAutosaveCompletedFlag, gd::bool_value(true));
}

} // namespace

int64_t profile_begin_usec(State &state) {
	return gd::engine_ticks_usec(state);
}

double profile_elapsed_ms(State &state, int64_t started_usec) {
	const int64_t elapsed = compat::engine_max<int64_t>(0, gd::sub(gd::engine_ticks_usec(state), started_usec));
	return compat::snappedf(static_cast<double>(elapsed) / 1000.0, 0.001);
}

DictRef _verified_cached_manual_save_recovery(State &state, Atom file_path, Atom slot_type) {
	if (slot_type != kSlotTypeManual || file_path == key::empty) {
		return state.new_dict();
	}
	if (gd::file_exists(state, _save_transaction_candidate_path(state, file_path))
			|| gd::file_exists(state, _save_transaction_backup_path(state, file_path))) {
		return state.new_dict();
	}
	Atom slot_id = key::empty;
	for (const int64_t manual_slot : kManualSlotIds) {
		if (file_path == _slot_path(state, manual_slot)) {
			slot_id = gd::stringify(state, gd::int_value(manual_slot));
			break;
		}
	}
	if (slot_id == key::empty) {
		return state.new_dict();
	}
	const DictRef summary = _cached_slot_summary(state, kSlotTypeManual, slot_id, file_path);
	if (gd::is_empty(state, summary)) {
		return state.new_dict();
	}
	if (!gd::bool_field(state, summary, key::valid, false)
			|| !gd::bool_field(state, summary, key::loadable, false)
			|| string_of(state, summary, key::slot_type, key::empty) != kSlotTypeManual
			|| string_of(state, summary, key::slot_id, key::empty) != slot_id
			|| string_of(state, summary, key::path, key::empty) != file_path) {
		return state.new_dict();
	}
	if (gd::int_field(state, summary, key::source_save_version, 0) > session_state_store::kSaveVersion
			|| gd::int_field(state, summary, key::save_version, 0) > session_state_store::kSaveVersion) {
		return state.new_dict();
	}
	return verified_recovery(state, key::verified_summary_cache, string_of(state, summary, key::manual_slot_name, key::empty));
}

DictRef _verified_receipt_recovery(State &state, Atom file_path) {
	const DictRef receipts = gd::as_dict(service_member(state, key::_verified_save_receipts));
	if (!state.has(receipts, gd::str(file_path))
			|| gd::file_exists(state, _save_transaction_candidate_path(state, file_path))
			|| gd::file_exists(state, _save_transaction_backup_path(state, file_path))) {
		return state.new_dict();
	}
	const DictRef receipt = gd::as_dict(gd::index(state, receipts, gd::str(file_path)));
	// Hash actual bytes, not timestamps: same-size external edits must invalidate
	// this shortcut. A matching file is exactly the last successfully committed save.
	if (!gd::file_exists(state, file_path)
			|| gd::to_string(gd::class_call_static(state, key::FileAccess, key::get_sha256, { gd::str(file_path) }))
					!= string_of(state, receipt, key::sha256, key::empty)) {
		state.erase(receipts, gd::str(file_path));
		return state.new_dict();
	}
	return verified_recovery(state, key::verified_byte_receipt, string_of(state, receipt, key::manual_name, key::empty));
}

DictRef _save_runtime_session(State &state, const Value &session, Atom slot_type, int64_t slot, bool include_summary, Atom save_file_name, bool cache_summary) {
	const bool has_session = session.kind != Kind::Nil;
	const Value scenario_id = has_session ? session_field(state, gd::object_view(state, session), key::scenario_id) : gd::str(key::empty);
	const bool generated_random_map = has_session ? gd::bool_field(state, session_flags(state, session), key::generated_random_map, false) : false;
	const Value session_metadata = gd::call_static(state, key::profile_log_script, key::session_metadata, { session_object(state, session) });
	const int64_t started_msec = gd::engine_ticks_msec(state);
	const int64_t started_usec = gd::engine_ticks_usec(state);
	const DictRef profile = state.new_dict();
	put(state, profile, key::slot_type, gd::str(slot_type));
	put(state, profile, key::include_summary, gd::bool_value(include_summary));
	put(state, profile, key::cache_summary, gd::bool_value(cache_summary));
	put(state, profile, key::scenario_id, scenario_id);
	put(state, profile, key::generated_random_map, gd::bool_value(generated_random_map));
	put(state, profile, key::session_metadata, session_metadata);
	put(state, profile, key::started_msec, gd::int_value(started_msec));
	put(state, profile, key::started_usec, gd::int_value(started_usec));
	put(state, profile, key::steps, gd::array_value(state.new_array()));
	put(state, profile, key::buckets_ms, gd::dict_value(state.new_dict()));
	put(state, profile, key::restore_normalize_pass_count, gd::int_value(0));
	put(state, profile, key::recovery_count, gd::int_value(0));
	put(state, profile, key::recovery_parse_count, gd::int_value(0));
	put(state, profile, key::recovery_cache_hit, gd::bool_value(false));
	put(state, profile, key::recovery_reason, gd::str(key::empty));
	put(state, profile, key::summary_session_reconstruction_count, gd::int_value(0));
	put(state, profile, key::summary_owned_session_materialization_count, gd::int_value(0));
	put(state, profile, key::summary_detail_context_build_count, gd::int_value(0));
	put(state, profile, key::summary_detail_context_reuse_count, gd::int_value(0));
	put(state, profile, key::summary_detail_direct_fallback_count, gd::int_value(0));
	put(state, profile, key::verification_parse_count, gd::int_value(0));
	put(state, profile, key::verification_payload_copy_count, gd::int_value(0));
	put(state, profile, key::restore_owned_payload_transfer, gd::bool_value(false));
	put(state, profile, key::prepared_payload, gd::bool_value(false));
	put(state, profile, key::prepared_payload_reason, gd::str(key::empty));
	_runtime_save_profile_step(state, profile, key::enter);
	if (!has_session || gd::to_string(session_field(state, gd::object_view(state, session), key::scenario_id)) == key::empty) {
		_runtime_save_profile_finish(state, profile);
		return save_result(state, false, key::empty, state.new_dict(), key::no_active_expedition_is_available_to);
	}
	if (_can_fast_save_generated_opening_autosave(state, session, slot_type, include_summary)) {
		return _save_generated_opening_autosave_fast(state, session, profile);
	}

	_runtime_save_profile_step(state, profile, key::to_dict_start);
	const int64_t to_dict_started = profile_begin_usec(state);
	const DictRef runtime_payload = _runtime_payload_for_save(state, session);
	_runtime_save_profile_bucket(state, profile, key::to_dict, profile_elapsed_ms(state, to_dict_started));
	_runtime_save_profile_step(state, profile, key::to_dict_done);
	Value sanitized_session;
	DictRef payload_for_write = runtime_payload;
	if (_can_use_trusted_live_autosave_payload(state, session, runtime_payload, slot_type)) {
		_runtime_save_profile_step(state, profile, key::restore_normalize_skipped);
		_runtime_save_profile_bucket(state, profile, key::restore_normalize, 0.0);
		put(state, profile, key::restore_normalize_skipped, gd::bool_value(true));
		put(state, profile, key::restore_normalize_skip_reason, gd::str(key::trusted_live_normalized_autosave));
		put(state, profile, key::trusted_live_payload, gd::bool_value(true));
		sanitized_session = session;
	} else {
		_runtime_save_profile_step(state, profile, key::restore_normalize_start);
		put(state, profile, key::restore_normalize_pass_count, gd::int_value(1));
		const int64_t restore_started = profile_begin_usec(state);
		const DictRef restore_result = _normalize_restore_result(state, runtime_payload, slot_type);
		_runtime_save_profile_bucket(state, profile, key::restore_normalize, profile_elapsed_ms(state, restore_started));
		_runtime_save_profile_step(state, profile, key::restore_normalize_done);
		put(state, profile, key::restore_normalize_skipped, gd::bool_value(false));
		put(state, profile, key::restore_normalize_skip_reason, gd::str(key::empty));
		put(state, profile, key::restore_owned_payload_transfer, gd::bool_value(gd::bool_field(state, restore_result, key::owned_payload_transfer, false)));
		if (!gd::bool_field(state, restore_result, key::ok, false)) {
			_runtime_save_profile_finish(state, profile);
			return save_result(state, false, key::empty, state.new_dict(),
					string_of(state, restore_result, key::message, key::this_session_cannot_be_saved_safely));
		}

		sanitized_session = state.get(restore_result, gd::str(key::session), Value());
		if (sanitized_session.kind == Kind::Nil) {
			_runtime_save_profile_finish(state, profile);
			return save_result(state, false, key::empty, state.new_dict(), key::this_session_could_not_be_prepared);
		}
		if (slot_type == kSlotTypeManual) {
			payload_for_write = _owned_payload_from_normalized_detached_session(state, sanitized_session);
			put(state, profile, key::prepared_payload, gd::bool_value(true));
			put(state, profile, key::prepared_payload_reason, gd::str(key::normalized_detached_manual_session));
		} else {
			// Restore returned a detached, normalized session. Transfer its owned
			// branches just as manual saves do, instead of copying a Large map again.
			payload_for_write = _owned_payload_from_normalized_detached_session(state, sanitized_session);
			put(state, profile, key::prepared_payload, gd::bool_value(true));
			put(state, profile, key::prepared_payload_reason, gd::str(key::normalized_detached_autosave_session));
		}
	}

	Atom path = key::empty;
	DictRef summary = state.new_dict();
	Atom cache_slot_id = key::empty;
	const DictRef saved_payload = state.new_dict();
	const bool payload_is_prepared = gd::bool_field(state, profile, key::prepared_payload, false)
			|| gd::bool_field(state, profile, key::trusted_live_payload, false);
	DictRef write_payload = payload_for_write;
	if (payload_is_prepared) {
		_clear_transition_autosave_intent_from_owned_payload(state, write_payload);
	} else {
		write_payload = _payload_without_transition_autosave_intent(state, payload_for_write);
	}
	const bool generated_opening_pending = _is_generated_opening_autosave_pending(state, session);
	if (generated_opening_pending) {
		if (payload_is_prepared) {
			_apply_generated_opening_autosave_success_to_owned_payload(state, write_payload);
		} else {
			write_payload = _generated_opening_autosave_success_payload_from_payload(state, write_payload);
		}
	}
	const Atom authoritative_resume_target = _resume_target_for_session(state, sanitized_session);
	if (slot_type == kSlotTypeAutosave) {
		_runtime_save_profile_step(state, profile, key::write_payload_start);
		const int64_t write_to_dict_started = profile_begin_usec(state);
		const DictRef autosave_payload = write_payload;
		_runtime_save_profile_bucket(state, profile, key::write_to_dict, profile_elapsed_ms(state, write_to_dict_started));
		path = _save_payload(state, autosave_payload, _autosave_path(state), kSlotTypeAutosave, saved_payload, profile, payload_is_prepared);
		_runtime_save_profile_step(state, profile, key::write_payload_done);
		cache_slot_id = kSlotTypeAutosave;
		if (path != key::empty && (include_summary || cache_summary)) {
			_runtime_save_profile_step(state, profile, key::summary_cache_store_start);
			const int64_t summary_cache_started = profile_begin_usec(state);
			_store_runtime_summary_cache(state, saved_payload, kSlotTypeAutosave, cache_slot_id, path, authoritative_resume_target, profile);
			_runtime_save_profile_bucket(state, profile, key::summary_cache, profile_elapsed_ms(state, summary_cache_started));
			_runtime_save_profile_step(state, profile, key::summary_cache_store_done);
		} else if (path != key::empty) {
			_runtime_save_profile_step(state, profile, key::summary_cache_deferred);
		}
		if (include_summary) {
			_runtime_save_profile_step(state, profile, key::inspect_summary_start);
			const int64_t inspect_started = profile_begin_usec(state);
			summary = inspect_autosave(state);
			_runtime_save_profile_bucket(state, profile, key::inspect_summary, profile_elapsed_ms(state, inspect_started));
			_runtime_save_profile_step(state, profile, key::inspect_summary_done);
		}
	} else {
		const int64_t normalized_slot = _normalize_manual_slot(state, slot);
		_runtime_save_profile_step(state, profile, key::write_payload_start);
		const int64_t write_to_dict_started = profile_begin_usec(state);
		const DictRef manual_payload = write_payload;
		_runtime_save_profile_bucket(state, profile, key::write_to_dict, profile_elapsed_ms(state, write_to_dict_started));
		const Atom target_path = slot_type == kSlotTypeFile ? named_save_path(state, save_file_name) : _slot_path(state, normalized_slot);
		path = _save_payload(state, manual_payload, target_path, slot_type, saved_payload, profile, payload_is_prepared);
		_runtime_save_profile_step(state, profile, key::write_payload_done);
		cache_slot_id = slot_type == kSlotTypeFile ? save_file_name : gd::stringify(state, gd::int_value(normalized_slot));
		if (path != key::empty && include_summary) {
			// Named files have no manual slot; keep the player's slot selection.
			if (slot_type == kSlotTypeManual) {
				gd::set_member(state, gd::autoload(state, key::SaveService), key::_selected_manual_slot, gd::int_value(normalized_slot));
			}
			_runtime_save_profile_step(state, profile, key::summary_cache_store_start);
			const int64_t summary_cache_started = profile_begin_usec(state);
			_store_runtime_summary_cache(state, saved_payload, slot_type, cache_slot_id, path, authoritative_resume_target, profile);
			_runtime_save_profile_bucket(state, profile, key::summary_cache, profile_elapsed_ms(state, summary_cache_started));
			_runtime_save_profile_step(state, profile, key::summary_cache_store_done);
		} else if (path != key::empty) {
			_runtime_save_profile_step(state, profile, key::summary_cache_deferred);
		}
		if (include_summary) {
			_runtime_save_profile_step(state, profile, key::inspect_summary_start);
			const int64_t inspect_started = profile_begin_usec(state);
			summary = slot_type == kSlotTypeFile ? inspect_save_file(state, save_file_name) : inspect_manual_slot(state, normalized_slot);
			_runtime_save_profile_bucket(state, profile, key::inspect_summary, profile_elapsed_ms(state, inspect_started));
			_runtime_save_profile_step(state, profile, key::inspect_summary_done);
		}
	}

	if (path == key::empty) {
		_runtime_save_profile_finish(state, profile);
		return save_result(state, false, key::empty, summary, key::save_write_failed);
	}
	if (generated_opening_pending) {
		_apply_generated_opening_autosave_success_to_session(state, session);
	} else {
		_clear_transition_autosave_intent_flags(state, session);
	}
	if (gd::file_exists(state, path)) {
		put(state, profile, key::written_bytes, gd::class_call_static(state, key::FileAccess, key::get_size, { gd::str(path) }));
		put(state, profile, key::path, gd::str(path));
		const DictRef receipt = state.new_dict();
		put(state, receipt, key::sha256, gd::class_call_static(state, key::FileAccess, key::get_sha256, { gd::str(path) }));
		put(state, receipt, key::manual_name, gd::str(string_of(state, saved_payload, key::manual_slot_name, key::empty)));
		state.set(gd::as_dict(service_member(state, key::_verified_save_receipts)), gd::str(path), gd::dict_value(receipt));
	}

	const Atom message = include_summary ? _runtime_save_message(state, slot_type, summary) : key::autosave_updated;
	const DictRef result = save_result(state, true, path, summary, message);
	_runtime_save_profile_finish(state, profile);
	return result;
}

bool _can_use_trusted_live_autosave_payload(State &state, const Value &session, DictRef payload, Atom slot_type) {
	if (session.kind == Kind::Nil || gd::is_empty(state, payload)) {
		return false;
	}
	if (slot_type != kSlotTypeAutosave) {
		return false;
	}
	if (string_of(state, payload, key::scenario_id, key::empty) == key::empty) {
		return false;
	}
	if (gd::int_field(state, payload, key::save_version, session_state_store::kSaveVersion) > session_state_store::kSaveVersion) {
		return false;
	}
	const Atom game_state = string_of(state, payload, key::game_state, key::empty);
	if (!(game_state == key::overworld || game_state == key::town || game_state == key::battle || game_state == key::outcome)) {
		return false;
	}
	const Atom scenario_status = string_of(state, payload, key::scenario_status, key::empty);
	if (!(scenario_status == key::in_progress || scenario_status == key::victory || scenario_status == key::defeat)) {
		return false;
	}
	if (gd::is_empty(state, gd::content_row(state, state::ContentTable::Scenario, string_of(state, payload, key::scenario_id, key::empty)))) {
		return false;
	}
	if (session.kind == Kind::Nil || !overworld_rules::is_runtime_session_normalized(state, gd::object_view(state, session))) {
		return false;
	}
	const Atom resume_target = _resume_target_for_session(state, session);
	if (resume_target == key::battle) {
		return !gd::is_empty(state, gd::as_dict(session_field(state, gd::object_view(state, session), key::battle)));
	}
	if (resume_target == key::town) {
		// TownRules.can_visit_active_town_bridge(session) is can_visit_active_town(session).
		return town_rules::can_visit_active_town(state, gd::object_view(state, session));
	}
	if (resume_target == key::outcome) {
		return gd::to_string(session_field(state, gd::object_view(state, session), key::scenario_status)) != key::in_progress;
	}
	return gd::is_empty(state, gd::as_dict(session_field(state, gd::object_view(state, session), key::battle)));
}

DictRef _runtime_payload_for_save(State &state, const Value &session) {
	if (session.kind == Kind::Nil) {
		return state.new_dict();
	}
	// GDScript's session.overworld.duplicate(false).duplicate(true) (and the same
	// of flags) is a deep copy of the session's own Dictionary: the engine copies
	// that one, as a deep copy of a native shallow copy would be made natively.
	const DictRef view = gd::object_view(state, session);
	const DictRef payload = state.new_dict();
	for (size_t index = 0; index < kSessionScalarFieldCount; ++index) {
		put(state, payload, kSessionPayloadFields[index], session_field(state, view, kSessionPayloadFields[index]));
	}
	put(state, payload, key::overworld, gd::engine_duplicate(state, gd::dict_value(gd::as_dict(session_field(state, view, key::overworld))), true));
	put(state, payload, key::battle, gd::engine_duplicate(state, gd::dict_value(gd::as_dict(session_field(state, view, key::battle))), true));
	put(state, payload, key::flags, gd::engine_duplicate(state, gd::dict_value(gd::as_dict(session_field(state, view, key::flags))), true));
	return payload;
}

DictRef _payload_without_transition_autosave_intent(State &state, DictRef payload) {
	// Callers pass an owned save snapshot, so only the branch being modified needs
	// duplication. Deep-copying the entire Large-map payload here doubled save time.
	const DictRef cleaned = gd::duplicate_dict(state, payload);
	Value found;
	if (!state.lookup(cleaned, gd::str(key::flags), found) || found.kind != Kind::Dict) {
		// A missing or non-Dictionary flags field gives an empty {}.
		return cleaned;
	}
	const DictRef flags = gd::as_dict(gd::engine_duplicate(state, found, true));
	if (gd::is_empty(state, flags)) {
		return cleaned;
	}
	for (const Atom flag : kTransitionAutosaveIntentFlags) {
		state.erase(flags, gd::str(flag));
	}
	put(state, cleaned, key::flags, gd::dict_value(flags));
	return cleaned;
}

DictRef _owned_payload_from_normalized_detached_session(State &state, const Value &session) {
	if (session.kind == Kind::Nil) {
		return state.new_dict();
	}
	const DictRef view = gd::object_view(state, session);
	const DictRef payload = state.new_dict();
	for (const Atom field : kSessionPayloadFields) {
		put(state, payload, field, session_field(state, view, field));
	}
	return payload;
}

void _clear_transition_autosave_intent_from_owned_payload(State &state, DictRef payload) {
	const DictRef flags = dict_field_or_new(state, payload, key::flags);
	for (const Atom flag : kTransitionAutosaveIntentFlags) {
		state.erase(flags, gd::str(flag));
	}
	put(state, payload, key::flags, gd::dict_value(flags));
}

void _clear_transition_autosave_intent_flags(State &state, const Value &session) {
	if (session.kind == Kind::Nil) {
		return;
	}
	const DictRef flags = session_flags(state, session);
	for (const Atom flag : kTransitionAutosaveIntentFlags) {
		state.erase(flags, gd::str(flag));
	}
}

bool _can_fast_save_generated_opening_autosave(State &state, const Value &session, Atom slot_type, bool include_summary) {
	return _is_generated_opening_autosave_pending(state, session)
			&& slot_type == kSlotTypeAutosave
			&& !include_summary;
}

bool _is_generated_opening_autosave_pending(State &state, const Value &session) {
	if (session.kind == Kind::Nil) {
		return false;
	}
	const DictRef flags = session_flags(state, session);
	return gd::bool_field(state, flags, key::generated_random_map, false)
			&& gd::bool_field(state, flags, kGeneratedOpeningAutosavePendingFlag, false);
}

DictRef _save_generated_opening_autosave_fast(State &state, const Value &session, DictRef profile) {
	_runtime_save_profile_step(state, profile, key::generated_opening_payload_start);
	const int64_t payload_started = profile_begin_usec(state);
	const DictRef payload = _generated_opening_autosave_success_payload(state, session);
	_runtime_save_profile_bucket(state, profile, key::to_dict, profile_elapsed_ms(state, payload_started));
	_runtime_save_profile_step(state, profile, key::generated_opening_payload_done);
	_runtime_save_profile_step(state, profile, key::write_payload_start);
	const DictRef saved_payload = state.new_dict();
	const bool forced_failure = gd::os_environment(state, kGeneratedOpeningAutosaveForceFailureEnv) == key::n1;
	const Atom path = forced_failure ? Atom(key::empty) : _save_payload(state, payload, _autosave_path(state), kSlotTypeAutosave, saved_payload, profile, false);
	_runtime_save_profile_step(state, profile, key::write_payload_done);
	if (path == key::empty) {
		_runtime_save_profile_finish(state, profile);
		return save_result(state, false, key::empty, state.new_dict(), key::save_write_failed);
	}
	_apply_generated_opening_autosave_success_to_session(state, session);
	if (gd::file_exists(state, path)) {
		put(state, profile, key::written_bytes, gd::class_call_static(state, key::FileAccess, key::get_size, { gd::str(path) }));
		put(state, profile, key::path, gd::str(path));
	}
	_runtime_save_profile_step(state, profile, key::summary_cache_deferred);
	_runtime_save_profile_finish(state, profile);
	return save_result(state, true, path, state.new_dict(), key::autosave_updated);
}

DictRef _generated_opening_autosave_success_payload(State &state, const Value &session) {
	return _generated_opening_autosave_success_payload_from_payload(state, gd::as_dict(gd::call_method(state, session, key::to_dict, {})));
}

DictRef _generated_opening_autosave_success_payload_from_payload(State &state, DictRef payload) {
	const DictRef canonical_payload = _payload_without_transition_autosave_intent(state, payload);
	const DictRef flags = dict_field_or_new(state, canonical_payload, key::flags);
	mark_generated_opening_autosave_completed(state, flags);
	put(state, canonical_payload, key::flags, gd::dict_value(flags));
	return canonical_payload;
}

void _apply_generated_opening_autosave_success_to_owned_payload(State &state, DictRef payload) {
	_clear_transition_autosave_intent_from_owned_payload(state, payload);
	const DictRef flags = dict_field_or_new(state, payload, key::flags);
	mark_generated_opening_autosave_completed(state, flags);
	put(state, payload, key::flags, gd::dict_value(flags));
}

void _apply_generated_opening_autosave_success_to_session(State &state, const Value &session) {
	if (session.kind == Kind::Nil) {
		return;
	}
	_clear_transition_autosave_intent_flags(state, session);
	mark_generated_opening_autosave_completed(state, session_flags(state, session));
}

void _runtime_save_profile_step(State &state, DictRef profile, Atom step_name) {
	if (gd::is_empty(state, profile)) {
		return;
	}
	const int64_t started = gd::int_field(state, profile, key::started_msec, gd::engine_ticks_msec(state));
	const int64_t elapsed = compat::engine_max<int64_t>(0, gd::sub(gd::engine_ticks_msec(state), started));
	Value found;
	const ArrayRef steps = state.lookup(profile, gd::str(key::steps), found) ? gd::as_array(found) : state.new_array();
	int64_t previous_elapsed = 0;
	const int64_t size = state.array_size(steps);
	if (size != 0) {
		const Value previous = state.at(steps, size - 1);
		if (previous.kind == Kind::Dict) {
			previous_elapsed = gd::int_field(state, previous.ref, key::elapsed_ms, 0);
		}
	}
	const DictRef step = state.new_dict();
	put(state, step, key::name, gd::str(step_name));
	put(state, step, key::elapsed_ms, gd::int_value(elapsed));
	put(state, step, key::delta_ms, gd::int_value(compat::engine_max<int64_t>(0, gd::sub(elapsed, previous_elapsed))));
	state.append(steps, gd::dict_value(step));
	put(state, profile, key::steps, gd::array_value(steps));
}

void _runtime_save_profile_bucket(State &state, DictRef profile, Atom bucket_name, double elapsed_ms) {
	if (gd::is_empty(state, profile) || bucket_name == key::empty) {
		return;
	}
	const DictRef buckets = dict_field_or_new(state, profile, key::buckets_ms);
	const double previous = gd::float_field(state, buckets, bucket_name, 0.0);
	put(state, buckets, bucket_name, gd::float_value(compat::snappedf(previous + compat::engine_max(0.0, elapsed_ms), 0.001)));
	put(state, profile, key::buckets_ms, gd::dict_value(buckets));
}

void _runtime_save_profile_finish(State &state, DictRef profile) {
	_runtime_save_profile_step(state, profile, key::finished);
	const int64_t now = gd::engine_ticks_msec(state);
	const int64_t started = gd::int_field(state, profile, key::started_msec, gd::engine_ticks_msec(state));
	put(state, profile, key::total_ms, gd::int_value(compat::engine_max<int64_t>(0, gd::sub(now, started))));
	gd::set_member(state, gd::autoload(state, key::SaveService), key::_last_runtime_save_profile,
			gd::engine_duplicate(state, gd::dict_value(profile), true));
	const Atom phase = string_of(state, profile, key::slot_type, key::runtime);
	const double total_ms = gd::float_field(state, profile, key::total_ms, 0.0);
	const DictRef buckets = dict_field_or_new(state, profile, key::buckets_ms);
	const DictRef metadata = state.new_dict();
	put(state, metadata, key::slot_type, gd::str(string_of(state, profile, key::slot_type, key::empty)));
	put(state, metadata, key::include_summary, gd::bool_value(gd::bool_field(state, profile, key::include_summary, false)));
	put(state, metadata, key::path, gd::str(string_of(state, profile, key::path, key::empty)));
	put(state, metadata, key::written_bytes, gd::int_value(gd::int_field(state, profile, key::written_bytes, 0)));
	put(state, metadata, key::generated_random_map, gd::bool_value(gd::bool_field(state, profile, key::generated_random_map, false)));
	put(state, metadata, key::restore_normalize_skipped, gd::bool_value(gd::bool_field(state, profile, key::restore_normalize_skipped, false)));
	put(state, metadata, key::restore_normalize_skip_reason, gd::str(string_of(state, profile, key::restore_normalize_skip_reason, key::empty)));
	put(state, metadata, key::session, field_or_new_dict(state, profile, key::session_metadata));
	put(state, metadata, key::steps, field_or_new_array(state, profile, key::steps));
	gd::call_static(state, key::profile_log_script, key::emit_general,
			{ gd::str(key::save), gd::str(phase), gd::str(key::runtime_save), gd::float_value(total_ms), gd::dict_value(buckets),
					gd::dict_value(metadata), Value() });
}

} // namespace aurelion::rules::port::save_service
