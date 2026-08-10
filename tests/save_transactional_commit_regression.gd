extends Node

const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "SAVE_TRANSACTIONAL_COMMIT_REGRESSION"
const FAILURE_ENV := "HEROES_LIKE_SAVE_FAIL_PHASE"
const SAVE_DIR := "user://saves"
const MANUAL_PATH := "user://saves/slot1.json"
const AUTOSAVE_PATH := "user://saves/autosave.json"
const PROGRESSION_PATH := "user://saves/campaign_progression.json"

var _original_states := {}
var _original_failure_env := ""
var _original_active_session = null


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_original_states = _capture_file_states(_tracked_paths())
	_original_failure_env = OS.get_environment(FAILURE_ENV)
	_original_active_session = SessionState.active_session
	OS.unset_environment(FAILURE_ENV)
	if not _require_hooks():
		return
	var manual_failures := _validate_manual_failure_phases()
	if manual_failures.is_empty():
		return
	var autosave_failure := _validate_generated_opening_failure_boundary()
	if autosave_failure.is_empty():
		return
	var progression_failure := _validate_progression_failure_boundary()
	if progression_failure.is_empty():
		return
	var success_case := _validate_successful_commit_and_reload()
	if success_case.is_empty():
		return
	var recovery_cases := _validate_recovery_boundaries()
	if recovery_cases.is_empty():
		return
	_cleanup()
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"manual_failures": manual_failures,
		"generated_opening_failure": autosave_failure,
		"progression_failure": progression_failure,
		"successful_commit": success_case,
		"recovery": recovery_cases,
		"save_version": SessionState.SAVE_VERSION,
	})])
	get_tree().quit(0)


func _require_hooks() -> bool:
	for method_name in [
		"validation_summary_cache_snapshot",
		"validation_clear_summary_cache",
		"validation_transaction_artifact_paths",
	]:
		if not SaveService.has_method(method_name):
			return _fail_bool("SaveService is missing transaction validation hook %s." % method_name)
	return true


func _validate_manual_failure_phases() -> Dictionary:
	var rows := {}
	for phase in ["precommit", "after_backup"]:
		_clear_paths([MANUAL_PATH])
		SaveService.validation_clear_summary_cache()
		var old_session := _session_fixture(3, "manual_old_%s" % phase)
		if SaveService.save_runtime_manual_session(old_session, 1).get("ok", false) != true:
			_fail("Could not seed manual transaction fixture for %s." % phase)
			return {}
		var old_file := _file_state(MANUAL_PATH)
		var old_summary: Dictionary = SaveService.inspect_manual_slot(1)
		if not SaveService.can_load_summary(old_summary):
			_fail("Seeded manual fixture was not loadable for %s." % phase)
			return {}
		var cache_before: Dictionary = SaveService.validation_summary_cache_snapshot()
		var new_session := _session_fixture(17 if phase == "precommit" else 18, "manual_new_%s" % phase)
		_add_transition_intent(new_session, phase)
		var live_flags_before := new_session.flags.duplicate(true)
		OS.set_environment(FAILURE_ENV, phase)
		var result: Dictionary = SaveService.save_runtime_manual_session(new_session, 1)
		OS.unset_environment(FAILURE_ENV)
		if bool(result.get("ok", true)):
			_fail("Injected manual %s failure unexpectedly committed." % phase)
			return {}
		if _file_state(MANUAL_PATH) != old_file:
			_fail("Injected manual %s failure changed prior live bytes." % phase)
			return {}
		if SaveService.validation_summary_cache_snapshot() != cache_before:
			_fail("Injected manual %s failure changed the primed summary cache." % phase)
			return {}
		if new_session.flags != live_flags_before:
			_fail("Injected manual %s failure cleared or changed live transition intent." % phase)
			return {}
		if not _artifacts_absent(MANUAL_PATH):
			_fail("Injected manual %s failure left transaction artifacts." % phase)
			return {}
		var restored = SaveService.restore_manual_session(1)
		if restored == null or restored.day != 3 or String(restored.flags.get("transaction_marker", "")) != "manual_old_%s" % phase:
			_fail("Injected manual %s failure did not preserve the prior loadable session." % phase)
			return {}
		rows[phase] = {
			"old_bytes_exact": true,
			"cache_exact": true,
			"live_intent_exact": true,
			"prior_reload_exact": true,
			"artifact_residue": false,
		}
	return rows


func _validate_generated_opening_failure_boundary() -> Dictionary:
	_clear_paths([AUTOSAVE_PATH])
	SaveService.validation_clear_summary_cache()
	var old_session := _session_fixture(4, "autosave_old")
	if SaveService.save_runtime_autosave_session(old_session).get("ok", false) != true:
		_fail("Could not seed autosave transaction fixture.")
		return {}
	var old_file := _file_state(AUTOSAVE_PATH)
	var old_summary: Dictionary = SaveService.inspect_autosave()
	if not SaveService.can_load_summary(old_summary):
		_fail("Seeded autosave transaction fixture was not loadable.")
		return {}
	var cache_before: Dictionary = SaveService.validation_summary_cache_snapshot()
	var generated := _session_fixture(23, "generated_opening_new")
	generated.flags["generated_random_map"] = true
	generated.flags["generated_overworld_deferred_autosave_pending"] = true
	generated.flags["generated_overworld_command_briefing_autosave_deferred"] = true
	generated.flags["generated_overworld_initial_autosave_completed"] = false
	_add_transition_intent(generated, "after_backup")
	var flags_before := generated.flags.duplicate(true)
	OS.set_environment(FAILURE_ENV, "after_backup")
	var result: Dictionary = SaveService.save_runtime_autosave_session(generated, false)
	OS.unset_environment(FAILURE_ENV)
	if bool(result.get("ok", true)):
		_fail("Generated-opening after_backup injection unexpectedly committed.")
		return {}
	if _file_state(AUTOSAVE_PATH) != old_file \
			or SaveService.validation_summary_cache_snapshot() != cache_before \
			or generated.flags != flags_before \
			or not _artifacts_absent(AUTOSAVE_PATH):
		_fail("Generated-opening failure changed old bytes/cache/live intent or left artifacts.")
		return {}
	var restored = SaveService.restore_autosave_session()
	if restored == null or restored.day != 4 or String(restored.flags.get("transaction_marker", "")) != "autosave_old":
		_fail("Generated-opening failure did not preserve the old autosave reload.")
		return {}
	return {
		"old_bytes_exact": true,
		"cache_exact": true,
		"pending_intent_exact": true,
		"completion_not_mutated": true,
		"prior_reload_exact": true,
	}


func _validate_progression_failure_boundary() -> Dictionary:
	_clear_paths([PROGRESSION_PATH])
	var old_profile := {
		"version": 1,
		"last_campaign_id": "campaign_reedfall",
		"last_scenario_id": "river-pass",
		"campaign_states": {"campaign_reedfall": {"transaction_marker": "old"}},
	}
	if SaveService.save_progression(old_profile) == "":
		_fail("Could not seed progression transaction fixture.")
		return {}
	var old_file := _file_state(PROGRESSION_PATH)
	var new_profile := old_profile.duplicate(true)
	new_profile["last_scenario_id"] = "causeway-stand"
	new_profile["campaign_states"]["campaign_reedfall"]["transaction_marker"] = "new"
	OS.set_environment(FAILURE_ENV, "after_backup")
	var path := SaveService.save_progression(new_profile)
	OS.unset_environment(FAILURE_ENV)
	if path != "" or _file_state(PROGRESSION_PATH) != old_file or not _artifacts_absent(PROGRESSION_PATH):
		_fail("Progression after_backup failure changed old bytes or left artifacts.")
		return {}
	if SaveService.load_progression() != _canonical_dictionary(old_profile):
		_fail("Progression after_backup failure did not preserve exact dictionary state.")
		return {}
	return {
		"old_bytes_exact": true,
		"old_dictionary_exact": true,
		"artifact_residue": false,
	}


func _validate_successful_commit_and_reload() -> Dictionary:
	_clear_paths([MANUAL_PATH])
	SaveService.validation_clear_summary_cache()
	var session := _session_fixture(27, "successful_commit")
	_add_transition_intent(session, "success")
	var result: Dictionary = SaveService.save_runtime_manual_session(session, 1)
	if not bool(result.get("ok", false)) or not _artifacts_absent(MANUAL_PATH):
		_fail("Successful manual transaction failed or left artifacts: %s" % JSON.stringify(_compact_result(result)))
		return {}
	for key in SaveService.TRANSITION_AUTOSAVE_INTENT_FLAGS:
		if session.flags.has(String(key)):
			_fail("Successful transaction retained live transition intent %s." % key)
			return {}
	var raw := _read_dictionary(MANUAL_PATH)
	var restored = SaveService.restore_manual_session(1)
	if raw.is_empty() or restored == null:
		_fail("Successful transaction could not reload its committed payload.")
		return {}
	var expected := SessionStateStoreScript.normalize_payload(raw)
	if _canonical_dictionary(restored.to_dict()) != _canonical_dictionary(expected):
		_fail("Successful transaction reload diverged from committed payload: %s" % JSON.stringify({
			"restored_day": restored.day,
			"expected_day": expected.get("day", -1),
			"restored_marker": restored.flags.get("transaction_marker", ""),
			"expected_marker": expected.get("flags", {}).get("transaction_marker", ""),
		}))
		return {}
	return {
		"reload_exact": true,
		"transition_intent_cleared_after_commit": true,
		"artifact_residue": false,
		"day": restored.day,
	}


func _validate_recovery_boundaries() -> Dictionary:
	var missing_live := _validate_backup_recovery(false)
	if missing_live.is_empty():
		return {}
	var corrupt_live := _validate_backup_recovery(true)
	if corrupt_live.is_empty():
		return {}
	var semantic_invalid_live := _validate_semantic_invalid_live_backup_recovery()
	if semantic_invalid_live.is_empty():
		return {}
	var valid_live := _validate_valid_live_wins()
	if valid_live.is_empty():
		return {}
	var malformed := _validate_malformed_artifacts_fail_closed()
	if malformed.is_empty():
		return {}
	var semantic_invalid_backup := _validate_semantic_invalid_backup_fail_closed()
	if semantic_invalid_backup.is_empty():
		return {}
	var progression := _validate_progression_backup_recovery()
	if progression.is_empty():
		return {}
	return {
		"missing_live": missing_live,
		"corrupt_live": corrupt_live,
		"semantic_invalid_live": semantic_invalid_live,
		"valid_live": valid_live,
		"malformed": malformed,
		"semantic_invalid_backup": semantic_invalid_backup,
		"progression": progression,
	}


func _validate_backup_recovery(corrupt_live: bool) -> Dictionary:
	_clear_paths([MANUAL_PATH])
	SaveService.validation_clear_summary_cache()
	var marker := "corrupt_backup_recovery" if corrupt_live else "missing_backup_recovery"
	var session := _session_fixture(31 if corrupt_live else 30, marker)
	if SaveService.save_runtime_manual_session(session, 1).get("ok", false) != true:
		_fail("Could not seed %s fixture." % marker)
		return {}
	var live_state := _file_state(MANUAL_PATH)
	var artifacts: Dictionary = SaveService.validation_transaction_artifact_paths(MANUAL_PATH)
	if not _write_bytes(String(artifacts.get("backup", "")), live_state.get("bytes", PackedByteArray())):
		_fail("Could not stage valid backup for %s." % marker)
		return {}
	_write_text(String(artifacts.get("candidate", "")), JSON.stringify({"candidate_only": true}, "\t"))
	if corrupt_live:
		_write_text(MANUAL_PATH, "{corrupt live")
	else:
		_remove_path(MANUAL_PATH)
	SaveService.validation_clear_summary_cache()
	var summary: Dictionary = SaveService.inspect_manual_slot(1)
	if not SaveService.can_load_summary(summary) or _file_state(MANUAL_PATH) != live_state or not _artifacts_absent(MANUAL_PATH):
		_fail("%s did not restore exact valid backup through inspect: %s" % [marker, JSON.stringify(_compact_summary(summary))])
		return {}
	return {
		"recovered": true,
		"bytes_exact": true,
		"candidate_not_promoted": true,
		"artifacts_cleaned": true,
	}


func _validate_valid_live_wins() -> Dictionary:
	_clear_paths([MANUAL_PATH])
	SaveService.validation_clear_summary_cache()
	var session := _session_fixture(35, "valid_live_wins")
	if SaveService.save_runtime_manual_session(session, 1).get("ok", false) != true:
		_fail("Could not seed valid-live recovery fixture.")
		return {}
	var live_state := _file_state(MANUAL_PATH)
	var artifacts: Dictionary = SaveService.validation_transaction_artifact_paths(MANUAL_PATH)
	_write_text(String(artifacts.get("candidate", "")), JSON.stringify({"candidate_only": true}, "\t"))
	_write_text(String(artifacts.get("backup", "")), JSON.stringify({"backup_only": true}, "\t"))
	SaveService.validation_clear_summary_cache()
	var summary: Dictionary = SaveService.inspect_manual_slot(1)
	if not SaveService.can_load_summary(summary) or _file_state(MANUAL_PATH) != live_state or not _artifacts_absent(MANUAL_PATH):
		_fail("Valid live save did not win over stale artifacts: %s" % JSON.stringify(_compact_summary(summary)))
		return {}
	return {"live_preserved": true, "stale_artifacts_cleaned": true}


func _validate_semantic_invalid_live_backup_recovery() -> Dictionary:
	_clear_paths([MANUAL_PATH])
	SaveService.validation_clear_summary_cache()
	var session := _session_fixture(36, "semantic_invalid_live_recovery")
	if SaveService.save_runtime_manual_session(session, 1).get("ok", false) != true:
		_fail("Could not seed semantic-invalid-live recovery fixture.")
		return {}
	var live_state := _file_state(MANUAL_PATH)
	var artifacts: Dictionary = SaveService.validation_transaction_artifact_paths(MANUAL_PATH)
	_write_bytes(String(artifacts.get("backup", "")), live_state.get("bytes", PackedByteArray()))
	_write_text(MANUAL_PATH, JSON.stringify({}, "\t"))
	SaveService.validation_clear_summary_cache()
	var summary: Dictionary = SaveService.inspect_manual_slot(1)
	if not SaveService.can_load_summary(summary) or _file_state(MANUAL_PATH) != live_state or not _artifacts_absent(MANUAL_PATH):
		_fail("Parseable but semantically invalid live save did not recover valid backup: %s" % JSON.stringify(_compact_summary(summary)))
		return {}
	return {"semantic_invalid_live_rejected": true, "valid_backup_restored": true}


func _validate_malformed_artifacts_fail_closed() -> Dictionary:
	_clear_paths([MANUAL_PATH])
	var artifacts: Dictionary = SaveService.validation_transaction_artifact_paths(MANUAL_PATH)
	_write_text(String(artifacts.get("candidate", "")), JSON.stringify(_session_fixture(40, "candidate_must_not_promote").to_dict(), "\t"))
	_write_text(String(artifacts.get("backup", "")), "{malformed backup")
	SaveService.validation_clear_summary_cache()
	var summary: Dictionary = SaveService.inspect_manual_slot(1)
	if SaveService.can_load_summary(summary) or FileAccess.file_exists(MANUAL_PATH):
		_fail("Malformed backup or candidate-only state was promoted: %s" % JSON.stringify(_compact_summary(summary)))
		return {}
	if FileAccess.file_exists(String(artifacts.get("candidate", ""))):
		_fail("Fail-closed recovery retained the non-authoritative candidate.")
		return {}
	return {
		"loadable": false,
		"candidate_not_promoted": true,
		"malformed_backup_not_promoted": true,
	}


func _validate_semantic_invalid_backup_fail_closed() -> Dictionary:
	_clear_paths([MANUAL_PATH])
	var artifacts: Dictionary = SaveService.validation_transaction_artifact_paths(MANUAL_PATH)
	_write_text(String(artifacts.get("candidate", "")), JSON.stringify(_session_fixture(41, "candidate_not_authority").to_dict(), "\t"))
	_write_text(String(artifacts.get("backup", "")), JSON.stringify({}, "\t"))
	SaveService.validation_clear_summary_cache()
	var summary: Dictionary = SaveService.inspect_manual_slot(1)
	if SaveService.can_load_summary(summary) or FileAccess.file_exists(MANUAL_PATH):
		_fail("Parseable but semantically invalid backup created a loadable live save: %s" % JSON.stringify(_compact_summary(summary)))
		return {}
	if FileAccess.file_exists(String(artifacts.get("candidate", ""))):
		_fail("Semantic-invalid backup recovery promoted or retained candidate staging.")
		return {}
	return {"loadable": false, "semantic_invalid_backup_rejected": true, "candidate_not_promoted": true}


func _validate_progression_backup_recovery() -> Dictionary:
	_clear_paths([PROGRESSION_PATH])
	var profile := {
		"version": 1,
		"last_campaign_id": "campaign_reedfall",
		"last_scenario_id": "river-pass",
		"campaign_states": {},
	}
	if SaveService.save_progression(profile) == "":
		_fail("Could not seed progression recovery fixture.")
		return {}
	var live_state := _file_state(PROGRESSION_PATH)
	var artifacts: Dictionary = SaveService.validation_transaction_artifact_paths(PROGRESSION_PATH)
	_write_bytes(String(artifacts.get("backup", "")), live_state.get("bytes", PackedByteArray()))
	_remove_path(PROGRESSION_PATH)
	var restored := SaveService.load_progression()
	if restored != _canonical_dictionary(profile) or _file_state(PROGRESSION_PATH) != live_state or not _artifacts_absent(PROGRESSION_PATH):
		_fail("Progression missing-live recovery did not restore exact backup dictionary/bytes.")
		return {}
	return {"dictionary_exact": true, "bytes_exact": true, "artifacts_cleaned": true}


func _session_fixture(day: int, marker: String) -> SessionStateStoreScript.SessionData:
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	session.day = day
	session.flags["transaction_marker"] = marker
	return session


func _add_transition_intent(session, label: String) -> void:
	session.flags["runtime_autosave_dirty"] = true
	session.flags["runtime_autosave_pending_intent"] = true
	session.flags["runtime_autosave_pending_reason"] = "transaction_%s" % label
	session.flags["runtime_autosave_pending_route"] = "overworld"
	session.flags["runtime_autosave_pending_game_state"] = "overworld"
	session.flags["runtime_autosave_pending_unix"] = 10184


func _tracked_paths() -> Array:
	var paths := []
	for live_path in [MANUAL_PATH, AUTOSAVE_PATH, PROGRESSION_PATH]:
		paths.append(live_path)
		paths.append("%s.candidate" % live_path)
		paths.append("%s.backup" % live_path)
	return paths


func _capture_file_states(paths: Array) -> Dictionary:
	var states := {}
	for path in paths:
		states[String(path)] = _file_state(String(path))
	return states


func _file_state(path: String) -> Dictionary:
	return {
		"exists": FileAccess.file_exists(path),
		"bytes": FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray(),
	}


func _clear_paths(live_paths: Array) -> void:
	for live_path_value in live_paths:
		var live_path := String(live_path_value)
		_remove_path(live_path)
		var artifacts: Dictionary = SaveService.validation_transaction_artifact_paths(live_path)
		_remove_path(String(artifacts.get("candidate", "")))
		_remove_path(String(artifacts.get("backup", "")))


func _artifacts_absent(live_path: String) -> bool:
	var artifacts: Dictionary = SaveService.validation_transaction_artifact_paths(live_path)
	return not FileAccess.file_exists(String(artifacts.get("candidate", ""))) \
		and not FileAccess.file_exists(String(artifacts.get("backup", "")))


func _read_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _canonical_dictionary(value: Dictionary) -> Dictionary:
	var parsed: Variant = JSON.parse_string(JSON.stringify(value))
	return parsed if parsed is Dictionary else {}


func _write_text(path: String, text: String) -> bool:
	if path == "":
		return false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.close()
	return true


func _write_bytes(path: String, bytes: PackedByteArray) -> bool:
	if path == "":
		return false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(bytes)
	file.close()
	return true


func _remove_path(path: String) -> void:
	if path != "" and FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _compact_result(result: Dictionary) -> Dictionary:
	return {
		"ok": result.get("ok", false),
		"path": result.get("path", ""),
		"message": result.get("message", ""),
	}


func _compact_summary(summary: Dictionary) -> Dictionary:
	return {
		"validity": summary.get("validity", ""),
		"loadable": summary.get("loadable", false),
		"day": summary.get("day", 0),
		"status_text": summary.get("status_text", ""),
	}


func _cleanup() -> void:
	OS.unset_environment(FAILURE_ENV)
	for path in _tracked_paths():
		_remove_path(String(path))
	for path in _original_states.keys():
		var state: Dictionary = _original_states.get(path, {})
		if bool(state.get("exists", false)):
			_write_bytes(String(path), state.get("bytes", PackedByteArray()))
	if _original_failure_env != "":
		OS.set_environment(FAILURE_ENV, _original_failure_env)
	SaveService.validation_clear_summary_cache()
	SessionState.active_session = _original_active_session


func _fail_bool(message: String) -> bool:
	_fail(message)
	return false


func _fail(message: String) -> void:
	_cleanup()
	push_error("%s failed: %s" % [REPORT_ID, message])
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "error": message})])
	get_tree().quit(1)
