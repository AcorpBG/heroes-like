extends Node

const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const OverworldShellScene = preload("res://scenes/overworld/OverworldShell.tscn")

const REPORT_ID := "GENERATED_OPENING_AUTOSAVE_FAILURE_RETRY_REGRESSION"
const FAILURE_ENV := "HEROES_LIKE_SAVE_FAIL_PHASE"
const FORCE_ENV := "HEROES_LIKE_GENERATED_OPENING_AUTOSAVE_FORCE_FAILURE"
const FAILURE_ROWS := ["forced", "precommit", "after_backup"]
const FAILURE_MESSAGE := "Generated map is ready, but autosave failed. Press Save to protect this checkpoint."
const AUTOSAVE_PATH := "user://saves/autosave.json"
const MANUAL_PATH := "user://saves/slot1.json"
const ISSUE_LOG_PATH := "user://debug/heroes_runtime_issues.jsonl"
const LATEST_ISSUE_PATH := "user://debug/heroes_last_runtime_issue.json"

var _original_session = null
var _original_selected_slot := 1
var _original_failure_env := ""
var _original_force_env := ""
var _original_files := {}


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_original_session = SessionState.active_session
	_original_selected_slot = SaveService.get_selected_manual_slot()
	_original_failure_env = OS.get_environment(FAILURE_ENV)
	_original_force_env = OS.get_environment(FORCE_ENV)
	_original_files = _capture_files(_tracked_paths())
	_clear_injections()
	if not _require_contract():
		return
	var matrix := {}
	for row_value in FAILURE_ROWS:
		var row := String(row_value)
		var result: Dictionary = await _prove_failure_retry(row)
		if result.is_empty():
			return
		matrix[row] = result
	var controls: Dictionary = _prove_runtime_save_controls()
	if controls.is_empty():
		return
	_cleanup()
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": true, "matrix": matrix, "controls": controls, "save_version": SessionState.SAVE_VERSION})])
	get_tree().quit(0)


func _require_contract() -> bool:
	var shell := OverworldShellScene.instantiate()
	for method_name in [
		"validation_retry_generated_opening_autosave",
		"validation_reset_generated_opening_autosave_recovery_state",
		"validation_generated_opening_autosave_recovery_snapshot",
	]:
		if not shell.has_method(method_name):
			shell.free()
			return _fail_bool("OverworldShell is missing %s." % method_name)
	shell.free()
	for method_name in ["validation_summary_cache_snapshot", "validation_clear_summary_cache", "validation_transaction_artifact_paths"]:
		if not SaveService.has_method(method_name):
			return _fail_bool("SaveService is missing %s." % method_name)
	return true


func _prove_failure_retry(row: String) -> Dictionary:
	_clear_runtime_files()
	var prior := _ordinary_session("prior-%s" % row)
	var seeded: Dictionary = SaveService.save_runtime_autosave_session(prior)
	if not bool(seeded.get("ok", false)):
		return _fail_dictionary("Could not seed prior autosave for %s." % row)
	SaveService.inspect_autosave()
	var bytes_before := _file_state(AUTOSAVE_PATH)
	var cache_before: Dictionary = SaveService.validation_summary_cache_snapshot()
	var fixture := _generated_pending_session("generated-%s" % row)
	var live_before: Dictionary = fixture.to_dict().duplicate(true)
	_set_injection(row)
	SessionState.set_active_session(fixture)
	var shell := OverworldShellScene.instantiate()
	add_child(shell)
	await _settle(7)
	var snapshot: Dictionary = shell.call("validation_generated_opening_autosave_recovery_snapshot")
	var issue_records: Array = RuntimeIssueLog.last_issue_records(2)
	var issue: Dictionary = issue_records[issue_records.size() - 1] if not issue_records.is_empty() else {}
	if not _failure_snapshot_exact(snapshot, 1, 0) \
			or RuntimeIssueLog.issue_record_count() != 1 \
			or String(issue.get("surface", "")) != "overworld" \
			or String(issue.get("event", "")) != "generated_opening_autosave_failed" \
			or String(issue.get("message", "")) != FAILURE_MESSAGE \
			or _issue_exposes_path(issue) \
			or SessionState.ensure_active_session().to_dict() != live_before \
			or _file_state(AUTOSAVE_PATH) != bytes_before \
			or SaveService.validation_summary_cache_snapshot() != cache_before \
			or not _artifacts_absent(AUTOSAVE_PATH):
		await _discard(shell)
		return _fail_dictionary("Initial %s failure was not exact: %s" % [row, JSON.stringify(_compact(snapshot))])

	var retry_failed: Dictionary = shell.call("validation_retry_generated_opening_autosave")
	await _settle(3)
	var after_failed_retry: Dictionary = shell.call("validation_generated_opening_autosave_recovery_snapshot")
	if bool(retry_failed.get("ok", true)) \
			or String(retry_failed.get("reason", "")) != "autosave_failed" \
			or not _failure_snapshot_exact(after_failed_retry, 1, 1) \
			or RuntimeIssueLog.issue_record_count() != 1 \
			or SessionState.ensure_active_session().to_dict() != live_before \
			or _file_state(AUTOSAVE_PATH) != bytes_before \
			or SaveService.validation_summary_cache_snapshot() != cache_before \
			or not _artifacts_absent(AUTOSAVE_PATH):
		await _discard(shell)
		return _fail_dictionary("Repeated %s failure duplicated issue or mutated authority: %s" % [row, JSON.stringify(_compact(after_failed_retry))])

	_clear_injections()
	var retry_saved: Dictionary = shell.call("validation_retry_generated_opening_autosave")
	await _settle(4)
	var after_saved: Dictionary = shell.call("validation_generated_opening_autosave_recovery_snapshot")
	var live := SessionState.ensure_active_session()
	var restored = SaveService.restore_autosave_session()
	if not bool(retry_saved.get("ok", false)) \
			or String(retry_saved.get("reason", "")) != "saved" \
			or bool(after_saved.get("pending", true)) \
			or int(after_saved.get("initial_attempt_count", -1)) != 1 \
			or int(after_saved.get("retry_attempt_count", -1)) != 2 \
			or int(after_saved.get("success_count", -1)) != 1 \
			or int(after_saved.get("failure_count", -1)) != 2 \
			or int(after_saved.get("resolution_route_attempt_count", -1)) != 0 \
			or restored == null \
			or not _canonical_generated(restored) \
			or not _canonical_generated(live) \
			or _canonical_dictionary(restored.to_dict()) != _canonical_dictionary(live.to_dict()) \
			or not _artifacts_absent(AUTOSAVE_PATH):
		await _discard(shell)
		return _fail_dictionary("Cleared %s retry did not commit canonical generated state: %s" % [row, JSON.stringify(_compact(after_saved))])

	await _discard(shell)
	SessionState.set_active_session(restored)
	var fresh := OverworldShellScene.instantiate()
	add_child(fresh)
	await _settle(7)
	var fresh_snapshot: Dictionary = fresh.call("validation_generated_opening_autosave_recovery_snapshot")
	if int(fresh_snapshot.get("initial_attempt_count", -1)) != 0 \
			or int(fresh_snapshot.get("attempt_count", -1)) != 0 \
			or bool(fresh_snapshot.get("pending", true)) \
			or not _canonical_generated(SessionState.ensure_active_session()):
		await _discard(fresh)
		return _fail_dictionary("Restored %s checkpoint repeated opening autosave." % row)
	await _discard(fresh)
	return {"initial_failure": true, "retry_failure_no_duplicate": true, "canonical_retry": true, "reload_no_repeat": true}


func _failure_snapshot_exact(snapshot: Dictionary, initial: int, retry: int) -> bool:
	var result: Dictionary = snapshot.get("last_retry_result", {}) if retry > 0 else snapshot.get("last_result", {})
	return bool(snapshot.get("pending", false)) \
		and int(snapshot.get("initial_attempt_count", -1)) == initial \
		and int(snapshot.get("retry_attempt_count", -1)) == retry \
		and int(snapshot.get("attempt_count", -1)) == initial + retry \
		and int(snapshot.get("success_count", -1)) == 0 \
		and int(snapshot.get("failure_count", -1)) == initial + retry \
		and int(snapshot.get("issue_count", -1)) == 1 \
		and not bool(result.get("ok", true)) \
		and String(result.get("reason", "")) == "autosave_failed" \
		and String(result.get("retry_action", "")) == "save" \
		and String(snapshot.get("visible_message", "")) == FAILURE_MESSAGE \
		and String(snapshot.get("visible_action_feedback", "")).strip_edges() != "" \
		and String(snapshot.get("focus_owner", "")) == "Save" \
		and int(snapshot.get("resolution_route_attempt_count", -1)) == 0 \
		and bool(snapshot.get("generated_random_map", false)) \
		and bool(snapshot.get("generated_overworld_deferred_autosave_pending", false)) \
		and bool(snapshot.get("generated_overworld_command_briefing_autosave_deferred", false)) \
		and not bool(snapshot.get("generated_overworld_initial_autosave_completed", true))


func _prove_runtime_save_controls() -> Dictionary:
	_clear_runtime_files()
	var modes := ["fast_autosave", "ordinary_autosave", "manual", "menu_return"]
	var results := {}
	for mode_value in modes:
		var mode := String(mode_value)
		var session := _generated_pending_session("control-%s" % mode)
		SessionState.set_active_session(session)
		session = SessionState.ensure_active_session()
		var result := {}
		match mode:
			"fast_autosave":
				result = SaveService.save_runtime_autosave_session(session, false)
			"ordinary_autosave":
				result = SaveService.save_runtime_autosave_session(session, true)
			"manual":
				result = SaveService.save_runtime_manual_session(session, 1)
			"menu_return":
				AppRouter.validation_reset_active_play_return_state()
				AppRouter.validation_set_active_play_return_routing_suppressed(true)
				result = AppRouter.return_to_main_menu_from_active_play()
		if not bool(result.get("ok", false)) or not _canonical_generated(session):
			return _fail_dictionary("%s did not canonicalize live generated opening flags: %s" % [mode, JSON.stringify(result)])
		var restored = SaveService.restore_manual_session(1) if mode == "manual" else SaveService.restore_autosave_session()
		if restored == null or not _canonical_generated(restored) or _canonical_dictionary(restored.to_dict()) != _canonical_dictionary(session.to_dict()):
			return _fail_dictionary("%s did not persist the canonical generated checkpoint." % mode)
		if mode == "menu_return":
			var router: Dictionary = AppRouter.validation_active_play_return_snapshot()
			if int(router.get("route_attempt_count", -1)) != 1 or int(router.get("suppressed_route_count", -1)) != 1:
				return _fail_dictionary("Menu-like save did not route once after canonical commit.")
		results[mode] = true
	var ordinary := _ordinary_session("ordinary-control")
	var ordinary_flags: Dictionary = ordinary.flags.duplicate(true)
	var ordinary_result: Dictionary = SaveService.save_runtime_autosave_session(ordinary)
	if not bool(ordinary_result.get("ok", false)) \
			or ordinary.flags != ordinary_flags \
			or ordinary.flags.has(SaveService.GENERATED_OPENING_AUTOSAVE_COMPLETED_FLAG):
		return _fail_dictionary("Ordinary non-generated save changed lifecycle flags.")
	results["ordinary_non_generated_exact"] = true
	return results


func _generated_pending_session(suffix: String) -> SessionStateStoreScript.SessionData:
	var session := _ordinary_session(suffix)
	session.flags["generated_random_map"] = true
	session.flags[SaveService.GENERATED_OPENING_AUTOSAVE_PENDING_FLAG] = true
	session.flags[SaveService.GENERATED_OPENING_AUTOSAVE_BRIEFING_DEFERRED_FLAG] = true
	session.flags[SaveService.GENERATED_OPENING_AUTOSAVE_COMPLETED_FLAG] = false
	for key_value in SaveService.TRANSITION_AUTOSAVE_INTENT_FLAGS:
		session.flags[String(key_value)] = {"source": suffix, "pending": true}
	return session


func _ordinary_session(suffix: String) -> SessionStateStoreScript.SessionData:
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	session.session_id = "%s-%s" % [session.session_id, suffix]
	session.day = 2
	session.game_state = "overworld"
	session.battle = {}
	OverworldRules.normalize_overworld_state(session)
	return session


func _canonical_generated(session: SessionStateStoreScript.SessionData) -> bool:
	if session == null or not bool(session.flags.get("generated_random_map", false)):
		return false
	if session.flags.has(SaveService.GENERATED_OPENING_AUTOSAVE_PENDING_FLAG) \
			or session.flags.has(SaveService.GENERATED_OPENING_AUTOSAVE_BRIEFING_DEFERRED_FLAG) \
			or not bool(session.flags.get(SaveService.GENERATED_OPENING_AUTOSAVE_COMPLETED_FLAG, false)):
		return false
	for key_value in SaveService.TRANSITION_AUTOSAVE_INTENT_FLAGS:
		if session.flags.has(String(key_value)):
			return false
	return true


func _canonical_dictionary(value: Dictionary) -> Dictionary:
	var parsed: Variant = JSON.parse_string(JSON.stringify(value))
	return parsed if parsed is Dictionary else {}


func _set_injection(row: String) -> void:
	_clear_injections()
	if row == "forced":
		OS.set_environment(FORCE_ENV, "1")
	else:
		OS.set_environment(FAILURE_ENV, row)


func _clear_injections() -> void:
	OS.unset_environment(FAILURE_ENV)
	OS.unset_environment(FORCE_ENV)


func _settle(frames: int) -> void:
	for _index in range(frames):
		await get_tree().process_frame


func _discard(node: Node) -> void:
	if node != null and is_instance_valid(node):
		node.queue_free()
		await _settle(3)


func _tracked_paths() -> Array:
	return [AUTOSAVE_PATH, AUTOSAVE_PATH + ".candidate", AUTOSAVE_PATH + ".backup", MANUAL_PATH, MANUAL_PATH + ".candidate", MANUAL_PATH + ".backup", ISSUE_LOG_PATH, LATEST_ISSUE_PATH]


func _clear_runtime_files() -> void:
	_clear_injections()
	for path_value in _tracked_paths():
		_remove_path(String(path_value))
	_write_bytes(ISSUE_LOG_PATH, PackedByteArray())
	SaveService.validation_clear_summary_cache()


func _artifacts_absent(path: String) -> bool:
	var artifacts: Dictionary = SaveService.validation_transaction_artifact_paths(path)
	return not FileAccess.file_exists(String(artifacts.get("candidate", path + ".candidate"))) and not FileAccess.file_exists(String(artifacts.get("backup", path + ".backup")))


func _capture_files(paths: Array) -> Dictionary:
	var states := {}
	for path_value in paths:
		states[String(path_value)] = _file_state(String(path_value))
	return states


func _file_state(path: String) -> Dictionary:
	return {"exists": FileAccess.file_exists(path), "bytes": FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()}


func _remove_path(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_buffer(bytes)
		file.close()


func _issue_exposes_path(issue: Dictionary) -> bool:
	var text := JSON.stringify({"message": issue.get("message", ""), "metadata": issue.get("metadata", {})}).to_lower()
	return "user://" in text or "/root/" in text or "\\users\\" in text


func _compact(snapshot: Dictionary) -> Dictionary:
	return {"pending": snapshot.get("pending"), "initial": snapshot.get("initial_attempt_count"), "retry": snapshot.get("retry_attempt_count"), "success": snapshot.get("success_count"), "failure": snapshot.get("failure_count"), "issue": snapshot.get("issue_count"), "message": snapshot.get("visible_message"), "focus": snapshot.get("focus_owner"), "routes": snapshot.get("resolution_route_attempt_count")}


func _cleanup() -> void:
	_clear_injections()
	AppRouter.validation_set_active_play_return_routing_suppressed(false)
	AppRouter.validation_reset_active_play_return_state()
	for path_value in _tracked_paths():
		_remove_path(String(path_value))
	for path_value in _original_files.keys():
		var state: Dictionary = _original_files[path_value]
		if bool(state.get("exists", false)):
			_write_bytes(String(path_value), state.get("bytes", PackedByteArray()))
	if _original_failure_env != "":
		OS.set_environment(FAILURE_ENV, _original_failure_env)
	if _original_force_env != "":
		OS.set_environment(FORCE_ENV, _original_force_env)
	SaveService.set_selected_manual_slot(_original_selected_slot)
	SaveService.validation_clear_summary_cache()
	SessionState.active_session = _original_session


func _fail_dictionary(message: String) -> Dictionary:
	_fail(message)
	return {}


func _fail_bool(message: String) -> bool:
	_fail(message)
	return false


func _fail(message: String) -> void:
	_cleanup()
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
