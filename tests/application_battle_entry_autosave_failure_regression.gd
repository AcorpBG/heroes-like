extends Node

const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const OverworldShellScene = preload("res://scenes/overworld/OverworldShell.tscn")

const REPORT_ID := "APPLICATION_BATTLE_ENTRY_AUTOSAVE_FAILURE_REGRESSION"
const FAILURE_ENV := "HEROES_LIKE_SAVE_FAIL_PHASE"
const FAILURE_PHASES := ["precommit", "after_backup"]
const AUTOSAVE_PATH := "user://saves/autosave.json"
const MANUAL_PATH := "user://saves/slot1.json"
const ISSUE_LOG_PATH := "user://debug/heroes_runtime_issues.jsonl"
const LATEST_ISSUE_PATH := "user://debug/heroes_last_runtime_issue.json"
const FAILURE_MESSAGE := "Battle is ready, but autosave failed. Use Save now to protect it."

var _original_active_session = null
var _original_failure_env := ""
var _original_file_states: Dictionary = {}


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_original_active_session = SessionState.active_session
	_original_failure_env = OS.get_environment(FAILURE_ENV)
	_original_file_states = _capture_file_states(_tracked_paths())
	OS.unset_environment(FAILURE_ENV)
	if not _require_hooks():
		return

	var failure_matrix := {}
	for phase_value in FAILURE_PHASES:
		var phase := String(phase_value)
		var result: Dictionary = await _prove_failure_and_manual_recovery(phase)
		if result.is_empty():
			return
		failure_matrix[phase] = result

	var ordinary_success := await _prove_ordinary_success()
	if ordinary_success.is_empty():
		return
	var controls := await _prove_route_controls()
	if controls.is_empty():
		return

	_cleanup()
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"failure_phases": failure_matrix,
		"ordinary_success": ordinary_success,
		"controls": controls,
		"save_version": SessionState.SAVE_VERSION,
	})])
	get_tree().quit(0)


func _require_hooks() -> bool:
	var shell = OverworldShellScene.instantiate()
	for method_name in [
		"validation_request_pending_battle_entry",
		"validation_reset_battle_entry_state",
		"validation_battle_entry_snapshot",
		"validation_select_save_slot",
		"validation_save_to_selected_slot",
	]:
		if not shell.has_method(method_name):
			shell.free()
			return _fail_bool("OverworldShell is missing validation hook %s." % method_name)
	shell.free()
	for method_name in [
		"validation_set_battle_entry_routing_suppressed",
		"validation_reset_battle_entry_state",
		"validation_battle_entry_snapshot",
	]:
		if not AppRouter.has_method(method_name):
			return _fail_bool("AppRouter is missing battle-entry validation hook %s." % method_name)
	for method_name in [
		"validation_summary_cache_snapshot",
		"validation_clear_summary_cache",
		"validation_transaction_artifact_paths",
	]:
		if not SaveService.has_method(method_name):
			return _fail_bool("SaveService is missing transaction hook %s." % method_name)
	return true


func _prove_failure_and_manual_recovery(phase: String) -> Dictionary:
	_clear_save_files()
	var prior := _base_fixture(1)
	var prior_save: Dictionary = SaveService.save_runtime_autosave_session(prior)
	if not bool(prior_save.get("ok", false)) or not FileAccess.file_exists(AUTOSAVE_PATH):
		return _fail_dictionary("Could not seed the prior autosave for %s." % phase)
	var prior_file := _file_state(AUTOSAVE_PATH)

	var shell = await _create_shell(_pending_battle_fixture(2))
	if shell == null:
		return {}
	var live: SessionStateStoreScript.SessionData = SessionState.ensure_active_session()
	var live_before := _canonical_dictionary(live.to_dict())
	SaveService.inspect_autosave()
	var cache_before: Dictionary = SaveService.validation_summary_cache_snapshot()
	if cache_before.is_empty():
		await _discard_shell(shell)
		return _fail_dictionary("Could not prime the autosave summary cache for %s." % phase)

	AppRouter.validation_reset_battle_entry_state()
	AppRouter.validation_set_battle_entry_routing_suppressed(true)
	shell.validation_reset_battle_entry_state()
	var issue_count_before := RuntimeIssueLog.issue_record_count()
	OS.set_environment(FAILURE_ENV, phase)
	var resolution: Dictionary = shell.validation_request_pending_battle_entry(false)
	OS.unset_environment(FAILURE_ENV)
	await _settle()

	var router_result: Dictionary = resolution.get("result", {}) if resolution.get("result", {}) is Dictionary else {}
	var router_snapshot: Dictionary = AppRouter.validation_battle_entry_snapshot()
	var shell_snapshot: Dictionary = shell.validation_battle_entry_snapshot()
	var issue_records: Array = RuntimeIssueLog.last_issue_records(1)
	var issue: Dictionary = issue_records[0] if not issue_records.is_empty() and issue_records[0] is Dictionary else {}
	if not bool(resolution.get("handled", false)) \
			or bool(resolution.get("routed", true)) \
			or not bool(resolution.get("failed", false)) \
			or String(resolution.get("target", "")) != "battle" \
			or bool(router_result.get("ok", true)) \
			or bool(router_result.get("saved", true)) \
			or bool(router_result.get("routed", true)) \
			or String(router_result.get("reason", "")) != "autosave_failed" \
			or String(router_result.get("retry_action", "")) != "manual_save" \
			or not bool(router_result.get("battle_pending", false)) \
			or String(router_result.get("message", "")) != FAILURE_MESSAGE:
		await _discard_shell(shell)
		return _fail_dictionary("Injected %s failure returned a dishonest resolution: %s" % [phase, JSON.stringify(_compact_failure(resolution, router_snapshot, shell_snapshot))])
	if int(router_snapshot.get("request_count", -1)) != 1 \
			or int(router_snapshot.get("save_attempt_count", -1)) != 1 \
			or int(router_snapshot.get("save_failure_count", -1)) != 1 \
			or int(router_snapshot.get("route_attempt_count", -1)) != 0 \
			or int(router_snapshot.get("runtime_issue_count", -1)) != 1 \
			or int(shell_snapshot.get("request_count", -1)) != 1 \
			or int(shell_snapshot.get("success_count", -1)) != 0 \
			or int(shell_snapshot.get("failure_count", -1)) != 1:
		await _discard_shell(shell)
		return _fail_dictionary("Injected %s failure did not perform exactly one save and zero routes: %s" % [phase, JSON.stringify(_compact_failure(resolution, router_snapshot, shell_snapshot))])
	if _canonical_dictionary(live.to_dict()) != live_before or live.battle.is_empty():
		var live_difference := _first_difference(live_before, _canonical_dictionary(live.to_dict()))
		await _discard_shell(shell)
		return _fail_dictionary("Injected %s failure changed the live pending battle/session: %s" % [phase, JSON.stringify(live_difference)])
	if _file_state(AUTOSAVE_PATH) != prior_file \
			or SaveService.validation_summary_cache_snapshot() != cache_before \
			or not _transaction_artifacts_absent(AUTOSAVE_PATH):
		await _discard_shell(shell)
		return _fail_dictionary("Injected %s failure changed prior autosave bytes/cache or left transaction residue." % phase)
	if RuntimeIssueLog.issue_record_count() != issue_count_before + 1 \
			or String(issue.get("surface", "")) != "router" \
			or String(issue.get("event", "")) != "battle_entry_autosave_failed" \
			or String(shell_snapshot.get("visible_message", "")) != FAILURE_MESSAGE \
			or String(shell_snapshot.get("visible_action_feedback", "")).strip_edges() == "" \
			or String(shell_snapshot.get("focus_owner", "")) != "Save":
		await _discard_shell(shell)
		return _fail_dictionary("Injected %s failure did not expose one sanitized issue and usable Save guidance: %s" % [phase, JSON.stringify(_compact_failure(resolution, router_snapshot, shell_snapshot).merged({"issue": _compact_issue(issue)}, true))])

	if not shell.validation_select_save_slot(1):
		await _discard_shell(shell)
		return _fail_dictionary("Could not select Manual Slot 1 after %s battle-entry failure." % phase)
	var before_manual_rules := _rule_counter_snapshot(shell)
	var manual_result: Dictionary = shell.validation_save_to_selected_slot()
	await _settle()
	var post_manual_router: Dictionary = AppRouter.validation_battle_entry_snapshot()
	var post_manual_shell: Dictionary = shell.validation_battle_entry_snapshot()
	var post_manual_validation: Dictionary = shell.validation_snapshot()
	var restored = SaveService.restore_manual_session(1)
	var live_saved_payload := _canonical_battle_payload(live)
	var restored_payload := _gameplay_payload(restored)
	if not bool(manual_result.get("ok", false)) \
			or not bool(manual_result.get("saved", false)) \
			or not bool(manual_result.get("routed", false)) \
			or String(manual_result.get("reason", "")) != "saved" \
			or int(manual_result.get("route_attempt_delta", -1)) != 1 \
			or restored == null \
			or restored_payload != live_saved_payload \
			or String(live.game_state) != "battle" \
			or not _transaction_artifacts_absent(MANUAL_PATH):
		await _discard_shell(shell)
		return _fail_dictionary("Manual recovery after %s did not persist and route the exact pending battle once: %s" % [phase, JSON.stringify({"manual": _compact_manual(manual_result, post_manual_validation), "payload_difference": _first_difference(live_saved_payload, restored_payload)})])
	if int(post_manual_router.get("request_count", -1)) != 2 \
			or int(post_manual_router.get("save_attempt_count", -1)) != 1 \
			or int(post_manual_router.get("save_failure_count", -1)) != 1 \
			or int(post_manual_router.get("route_attempt_count", -1)) != 1 \
			or int(post_manual_router.get("suppressed_route_count", -1)) != 1 \
			or int(post_manual_router.get("skipped_durable_route_count", -1)) != 1 \
			or int(post_manual_shell.get("request_count", -1)) != 2 \
			or int(post_manual_shell.get("success_count", -1)) != 1 \
			or int(post_manual_shell.get("failure_count", -1)) != 1 \
			or int(post_manual_validation.get("manual_save_route_attempt_count", -1)) != 1 \
			or _rule_counter_snapshot(shell) != before_manual_rules:
		await _discard_shell(shell)
		return _fail_dictionary("Manual recovery after %s retried rules/save or did not record one durable route: %s" % [phase, JSON.stringify({"router": _compact_router(post_manual_router), "shell": post_manual_shell, "manual": _compact_manual(manual_result, post_manual_validation)})])

	await _discard_shell(shell)
	return {
		"prior_autosave_exact": true,
		"summary_cache_exact": true,
		"live_pending_battle_exact": true,
		"save_attempts": 1,
		"failure_routes": 0,
		"runtime_issue_event": "battle_entry_autosave_failed",
		"focus_owner": "Save",
		"manual_reload_exact": true,
		"durable_route_attempts": 1,
		"gameplay_rule_replays": 0,
	}


func _prove_ordinary_success() -> Dictionary:
	_clear_save_files()
	var shell = await _create_shell(_pending_battle_fixture(3))
	if shell == null:
		return {}
	var live: SessionStateStoreScript.SessionData = SessionState.ensure_active_session()
	AppRouter.validation_reset_battle_entry_state()
	AppRouter.validation_set_battle_entry_routing_suppressed(true)
	shell.validation_reset_battle_entry_state()
	var resolution: Dictionary = shell.validation_request_pending_battle_entry(false)
	var result: Dictionary = resolution.get("result", {}) if resolution.get("result", {}) is Dictionary else {}
	var router_snapshot: Dictionary = AppRouter.validation_battle_entry_snapshot()
	var restored = SaveService.restore_autosave_session()
	if not bool(resolution.get("handled", false)) \
			or not bool(resolution.get("routed", false)) \
			or bool(resolution.get("failed", true)) \
			or not bool(result.get("ok", false)) \
			or not bool(result.get("saved", false)) \
			or String(result.get("reason", "")) != "saved" \
			or int(router_snapshot.get("save_attempt_count", -1)) != 1 \
			or int(router_snapshot.get("route_attempt_count", -1)) != 1 \
			or int(router_snapshot.get("suppressed_route_count", -1)) != 1 \
			or restored == null \
			or _gameplay_payload(restored) != _canonical_battle_payload(live):
		await _discard_shell(shell)
		return _fail_dictionary("Ordinary battle entry did not save and route once: %s" % JSON.stringify({"resolution": resolution, "router": _compact_router(router_snapshot), "reload_difference": _first_difference(_canonical_battle_payload(live), _gameplay_payload(restored))}))
	await _discard_shell(shell)
	return {"saved": true, "route_attempts": 1, "reload_exact": true}


func _prove_route_controls() -> Dictionary:
	AppRouter.validation_reset_battle_entry_state()
	AppRouter.validation_set_battle_entry_routing_suppressed(true)
	SessionState.active_session = null
	var missing_session: Dictionary = AppRouter.go_to_battle()
	var missing_session_snapshot: Dictionary = AppRouter.validation_battle_entry_snapshot()
	if String(missing_session.get("reason", "")) != "missing_session" \
			or int(missing_session_snapshot.get("save_attempt_count", -1)) != 0 \
			or int(missing_session_snapshot.get("route_attempt_count", -1)) != 1:
		return _fail_dictionary("Missing-session battle entry did not fail closed before save: %s" % JSON.stringify({"result": missing_session, "snapshot": _compact_router(missing_session_snapshot)}))

	AppRouter.validation_reset_battle_entry_state()
	AppRouter.validation_set_battle_entry_routing_suppressed(true)
	SessionState.set_active_session(_base_fixture(4))
	var missing_payload: Dictionary = AppRouter.go_to_battle()
	var missing_payload_snapshot: Dictionary = AppRouter.validation_battle_entry_snapshot()
	if String(missing_payload.get("reason", "")) != "missing_battle_payload" \
			or int(missing_payload_snapshot.get("save_attempt_count", -1)) != 0 \
			or int(missing_payload_snapshot.get("route_attempt_count", -1)) != 1:
		return _fail_dictionary("Missing-payload battle entry did not redirect before save: %s" % JSON.stringify({"result": missing_payload, "snapshot": _compact_router(missing_payload_snapshot)}))

	AppRouter.validation_reset_battle_entry_state()
	AppRouter.validation_set_battle_entry_routing_suppressed(true)
	var terminal := _pending_battle_fixture(5)
	terminal.scenario_status = "victory"
	SessionState.set_active_session(terminal)
	var terminal_result: Dictionary = AppRouter.go_to_battle()
	var terminal_snapshot: Dictionary = AppRouter.validation_battle_entry_snapshot()
	if String(terminal_result.get("reason", "")) != "terminal_redirect" \
			or int(terminal_snapshot.get("save_attempt_count", -1)) != 0 \
			or int(terminal_snapshot.get("route_attempt_count", -1)) != 1:
		return _fail_dictionary("Terminal battle entry did not redirect before battle save: %s" % JSON.stringify({"result": terminal_result, "snapshot": _compact_router(terminal_snapshot)}))

	_clear_save_files()
	var durable_source := _pending_battle_fixture(6)
	durable_source.game_state = "battle"
	var durable_save: Dictionary = SaveService.save_runtime_autosave_session(durable_source)
	var durable = SaveService.restore_autosave_session()
	if not bool(durable_save.get("ok", false)) or durable == null:
		return _fail_dictionary("Could not seed the durable battle-resume control.")
	SessionState.set_active_session(durable)
	AppRouter.validation_reset_battle_entry_state()
	AppRouter.validation_set_battle_entry_routing_suppressed(true)
	OS.set_environment(FAILURE_ENV, "precommit")
	AppRouter.resume_active_session()
	OS.unset_environment(FAILURE_ENV)
	var durable_snapshot: Dictionary = AppRouter.validation_battle_entry_snapshot()
	var durable_result: Dictionary = durable_snapshot.get("last_result", {}) if durable_snapshot.get("last_result", {}) is Dictionary else {}
	if String(durable_result.get("reason", "")) != "already_saved" \
			or not bool(durable_result.get("ok", false)) \
			or not bool(durable_result.get("saved", false)) \
			or int(durable_snapshot.get("save_attempt_count", -1)) != 0 \
			or int(durable_snapshot.get("route_attempt_count", -1)) != 1 \
			or int(durable_snapshot.get("skipped_durable_route_count", -1)) != 1:
		return _fail_dictionary("Durable battle resume redundantly saved or failed to route: %s" % JSON.stringify({"result": durable_result, "snapshot": _compact_router(durable_snapshot)}))
	return {
		"missing_session": true,
		"missing_payload": true,
		"terminal_redirect": true,
		"durable_resume_without_save": true,
	}


func _create_shell(session):
	SessionState.set_active_session(session)
	var shell = OverworldShellScene.instantiate()
	add_child(shell)
	await _settle()
	return shell


func _discard_shell(shell) -> void:
	if shell != null and is_instance_valid(shell):
		shell.queue_free()
		await get_tree().process_frame


func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func _base_fixture(day: int) -> SessionStateStoreScript.SessionData:
	var session: SessionStateStoreScript.SessionData = ScenarioFactory.create_session(
		"river-pass",
		"normal",
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	session.day = day
	session.game_state = "overworld"
	session.flags["battle_entry_failure_marker"] = "day_%d" % day
	OverworldRules.normalize_overworld_state(session)
	OverworldRules.mark_runtime_normalized_transition_state(session)
	return session


func _pending_battle_fixture(day: int) -> SessionStateStoreScript.SessionData:
	var session := _base_fixture(day)
	var encounters: Array = session.overworld.get("encounters", []) if session.overworld.get("encounters", []) is Array else []
	var encounter: Dictionary = {}
	for encounter_value in encounters:
		if encounter_value is Dictionary:
			encounter = encounter_value
			break
	if encounter.is_empty():
		return session
	session.battle = BattleRules.create_battle_payload(session, encounter)
	session.game_state = "overworld"
	OverworldRules.mark_runtime_normalized_transition_state(session)
	return session


func _rule_counter_snapshot(shell) -> Dictionary:
	var snapshot: Dictionary = shell.validation_snapshot()
	return {
		"end_turn_rules": snapshot.get("rules_end_turn_call_count", -1),
		"end_turn_autosaves": snapshot.get("autosave_call_count", -1),
	}


func _gameplay_payload(session) -> Dictionary:
	if session == null:
		return {}
	var payload := _canonical_dictionary(session.to_dict())
	for metadata_key in ["saved_at_unix", "save_slot_type", "saved_from_game_state", "saved_from_scenario_status", "saved_from_launch_mode", "manual_slot_name"]:
		payload.erase(metadata_key)
	var overworld: Dictionary = payload.get("overworld", {}) if payload.get("overworld", {}) is Dictionary else {}
	overworld.erase("command_briefing")
	payload["overworld"] = overworld
	return payload


func _canonical_battle_payload(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var normalized := SessionStateStoreScript.new_session_data()
	normalized.from_dict(session.to_dict())
	OverworldRules.normalize_overworld_state(normalized)
	if not normalized.battle.is_empty():
		BattleRules.normalize_battle_state(normalized)
		normalized.game_state = "battle"
	return _gameplay_payload(normalized)


func _compact_failure(resolution: Dictionary, router: Dictionary, shell: Dictionary) -> Dictionary:
	var result: Dictionary = resolution.get("result", {}) if resolution.get("result", {}) is Dictionary else {}
	return {
		"resolution": {
			"handled": resolution.get("handled", false),
			"routed": resolution.get("routed", false),
			"failed": resolution.get("failed", false),
			"target": resolution.get("target", ""),
		},
		"result": {
			"ok": result.get("ok", false),
			"saved": result.get("saved", false),
			"routed": result.get("routed", false),
			"reason": result.get("reason", ""),
			"retry_action": result.get("retry_action", ""),
			"battle_pending": result.get("battle_pending", false),
			"message": result.get("message", ""),
		},
		"router": _compact_router(router),
		"shell": {
			"requests": shell.get("request_count", -1),
			"successes": shell.get("success_count", -1),
			"failures": shell.get("failure_count", -1),
			"focus_owner": shell.get("focus_owner", ""),
			"visible_message": shell.get("visible_message", ""),
		},
	}


func _compact_router(snapshot: Dictionary) -> Dictionary:
	return {
		"requests": snapshot.get("request_count", -1),
		"save_attempts": snapshot.get("save_attempt_count", -1),
		"save_failures": snapshot.get("save_failure_count", -1),
		"route_attempts": snapshot.get("route_attempt_count", -1),
		"suppressed_routes": snapshot.get("suppressed_route_count", -1),
		"skipped_durable_routes": snapshot.get("skipped_durable_route_count", -1),
		"runtime_issues": snapshot.get("runtime_issue_count", -1),
		"last_route": snapshot.get("last_route", {}),
	}


func _compact_manual(result: Dictionary, snapshot: Dictionary) -> Dictionary:
	return {
		"ok": result.get("ok", false),
		"saved": result.get("saved", false),
		"routed": result.get("routed", false),
		"reason": result.get("reason", ""),
		"route_attempt_delta": result.get("route_attempt_delta", -1),
		"manual_attempts": snapshot.get("manual_save_attempt_count", -1),
		"manual_successes": snapshot.get("manual_save_success_count", -1),
		"manual_failures": snapshot.get("manual_save_failure_count", -1),
		"manual_route_attempts": snapshot.get("manual_save_route_attempt_count", -1),
	}


func _compact_issue(issue: Dictionary) -> Dictionary:
	return {
		"surface": issue.get("surface", ""),
		"event": issue.get("event", ""),
		"message": issue.get("message", ""),
	}


func _tracked_paths() -> Array:
	return [
		AUTOSAVE_PATH,
		"%s.candidate" % AUTOSAVE_PATH,
		"%s.backup" % AUTOSAVE_PATH,
		MANUAL_PATH,
		"%s.candidate" % MANUAL_PATH,
		"%s.backup" % MANUAL_PATH,
		ISSUE_LOG_PATH,
		LATEST_ISSUE_PATH,
	]


func _clear_save_files() -> void:
	for path in [AUTOSAVE_PATH, "%s.candidate" % AUTOSAVE_PATH, "%s.backup" % AUTOSAVE_PATH, MANUAL_PATH, "%s.candidate" % MANUAL_PATH, "%s.backup" % MANUAL_PATH]:
		_remove_path(String(path))
	SaveService.validation_clear_summary_cache()


func _transaction_artifacts_absent(path: String) -> bool:
	var artifacts: Dictionary = SaveService.validation_transaction_artifact_paths(path)
	return not FileAccess.file_exists(String(artifacts.get("candidate", "%s.candidate" % path))) \
		and not FileAccess.file_exists(String(artifacts.get("backup", "%s.backup" % path)))


func _capture_file_states(paths: Array) -> Dictionary:
	var states := {}
	for path_value in paths:
		states[String(path_value)] = _file_state(String(path_value))
	return states


func _file_state(path: String) -> Dictionary:
	return {
		"exists": FileAccess.file_exists(path),
		"bytes": FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray(),
	}


func _remove_path(path: String) -> void:
	if path != "" and FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _write_bytes(path: String, bytes: PackedByteArray) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(bytes)
	file.close()
	return true


func _canonical_dictionary(value: Dictionary) -> Dictionary:
	var parsed: Variant = JSON.parse_string(JSON.stringify(value))
	return parsed if parsed is Dictionary else {}


func _first_difference(expected: Variant, actual: Variant, path: String = "$") -> Dictionary:
	if typeof(expected) != typeof(actual):
		return {"path": path, "expected_type": type_string(typeof(expected)), "actual_type": type_string(typeof(actual))}
	if expected is Dictionary:
		var expected_dictionary: Dictionary = expected
		var actual_dictionary: Dictionary = actual
		var expected_keys: Array = expected_dictionary.keys()
		expected_keys.sort()
		var actual_keys: Array = actual_dictionary.keys()
		actual_keys.sort()
		if expected_keys != actual_keys:
			return {"path": path, "expected_keys": expected_keys, "actual_keys": actual_keys}
		for key in expected_keys:
			var nested := _first_difference(expected_dictionary.get(key), actual_dictionary.get(key), "%s.%s" % [path, key])
			if not nested.is_empty():
				return nested
		return {}
	if expected is Array:
		var expected_array: Array = expected
		var actual_array: Array = actual
		if expected_array.size() != actual_array.size():
			return {"path": path, "expected_size": expected_array.size(), "actual_size": actual_array.size()}
		for index in range(expected_array.size()):
			var nested := _first_difference(expected_array[index], actual_array[index], "%s[%d]" % [path, index])
			if not nested.is_empty():
				return nested
		return {}
	if expected != actual:
		return {"path": path, "expected": expected, "actual": actual}
	return {}


func _cleanup() -> void:
	OS.unset_environment(FAILURE_ENV)
	AppRouter.validation_set_battle_entry_routing_suppressed(false)
	for path in _tracked_paths():
		_remove_path(String(path))
	for path_value in _original_file_states.keys():
		var path := String(path_value)
		var state: Dictionary = _original_file_states.get(path, {})
		if bool(state.get("exists", false)):
			_write_bytes(path, state.get("bytes", PackedByteArray()))
	if _original_failure_env != "":
		OS.set_environment(FAILURE_ENV, _original_failure_env)
	SaveService.validation_clear_summary_cache()
	SessionState.active_session = _original_active_session


func _fail_dictionary(message: String) -> Dictionary:
	_fail(message)
	return {}


func _fail_bool(message: String) -> bool:
	_fail(message)
	return false


func _fail(message: String) -> void:
	_cleanup()
	push_error("%s failed: %s" % [REPORT_ID, message])
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "error": message})])
	get_tree().quit(1)
