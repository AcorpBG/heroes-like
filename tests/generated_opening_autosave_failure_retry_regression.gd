extends Node

const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const OverworldShellScene = preload("res://scenes/overworld/OverworldShell.tscn")

const REPORT_ID := "GENERATED_OPENING_AUTOSAVE_FAILURE_RETRY_REGRESSION"
const FAILURE_ENV := "HEROES_LIKE_SAVE_FAIL_PHASE"
const FORCE_ENV := "HEROES_LIKE_GENERATED_OPENING_AUTOSAVE_FORCE_FAILURE"
const FAILURE_ROWS := ["forced", "precommit", "after_backup"]
const FAILURE_MESSAGE := "Generated map is ready, but autosave failed. Press Save to protect this checkpoint."
const END_TURN_FAILURE_MESSAGE := "Turn completed, but autosave failed. Use Save now to protect the new day."
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
	var alternate_end_turn := {}
	for row_value in FAILURE_ROWS:
		var row := String(row_value)
		var result: Dictionary = await _prove_alternate_end_turn_success(row)
		if result.is_empty():
			return
		alternate_end_turn[row] = result
	var failed_end_turn: Dictionary = await _prove_alternate_end_turn_failure("after_backup")
	if failed_end_turn.is_empty():
		return
	var controls: Dictionary = _prove_runtime_save_controls()
	if controls.is_empty():
		return
	_cleanup()
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": true, "matrix": matrix, "alternate_end_turn": alternate_end_turn, "failed_end_turn": failed_end_turn, "controls": controls, "save_version": SessionState.SAVE_VERSION})])
	get_tree().quit(0)


func _require_contract() -> bool:
	var shell := OverworldShellScene.instantiate()
	for method_name in [
		"validation_retry_generated_opening_autosave",
		"validation_retry_generated_opening_autosave_direct",
		"validation_reset_generated_opening_autosave_recovery_state",
		"validation_generated_opening_autosave_recovery_snapshot",
		"validation_request_end_turn",
		"validation_end_turn_confirmation_snapshot",
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


func _prove_alternate_end_turn_success(row: String) -> Dictionary:
	_clear_runtime_files()
	var prior := _ordinary_session("alternate-prior-%s" % row)
	if not bool(SaveService.save_runtime_autosave_session(prior).get("ok", false)) \
			or not bool(SaveService.save_runtime_manual_session(prior, 1).get("ok", false)):
		return _fail_dictionary("Could not seed alternate End Turn slots for %s." % row)
	SaveService.inspect_autosave()
	var fixture := _generated_pending_end_turn_session("alternate-%s" % row)
	_set_injection(row)
	SessionState.set_active_session(fixture)
	var shell := OverworldShellScene.instantiate()
	add_child(shell)
	await _settle(7)
	var failed_opening: Dictionary = shell.validation_generated_opening_autosave_recovery_snapshot()
	var opening_issue: Dictionary = failed_opening.get("last_issue", {}).duplicate(true)
	if not _failure_snapshot_exact(failed_opening, 1, 0) or RuntimeIssueLog.issue_record_count() != 1:
		await _discard(shell)
		return _fail_dictionary("Alternate %s opening failure did not establish recovery." % row)

	var control := _duplicate_session(SessionState.ensure_active_session())
	var control_result: Dictionary = OverworldRules.end_turn(control)
	control.flags["last_action"] = "ended_turn"
	var expected_payload: Dictionary = _canonical_generated_payload(control.to_dict())
	_clear_injections()
	var end_result: Dictionary = shell.validation_request_end_turn()
	if bool(end_result.get("confirmation_required", false)):
		end_result = shell.validation_confirm_end_turn()
	await _settle(4)
	var end_snapshot: Dictionary = shell.validation_end_turn_confirmation_snapshot()
	var recovery: Dictionary = shell.validation_generated_opening_autosave_recovery_snapshot()
	var reconciliation: Dictionary = recovery.get("last_reconciliation_result", {}) if recovery.get("last_reconciliation_result", {}) is Dictionary else {}
	var live = SessionState.ensure_active_session()
	var restored = SaveService.restore_autosave_session()
	var focus_owner := String(recovery.get("focus_owner", ""))
	if not bool(end_result.get("ok", false)) \
			or not bool(end_result.get("committed", false)) \
			or bool(end_result.get("resolved", false)) \
			or int(end_snapshot.get("rules_end_turn_call_count", -1)) != 1 \
			or int(end_snapshot.get("autosave_call_count", -1)) != 1 \
			or int(end_snapshot.get("autosave_failure_count", -1)) != 0 \
			or int(end_snapshot.get("resolution_attempt_count", -1)) != 0 \
			or bool(recovery.get("pending", true)) \
			or int(recovery.get("reconciliation_count", -1)) != 1 \
			or not bool(recovery.get("authoritative_opening_canonical", false)) \
			or String(reconciliation.get("reason", "")) != "alternate_autosave_saved" \
			or String(reconciliation.get("source", "")) != "end_turn_autosave" \
			or not bool(reconciliation.get("alternate_save_verified", false)) \
			or bool(reconciliation.get("reconciliation_write_attempted", true)) \
			or int(recovery.get("issue_count", -1)) != 1 \
			or recovery.get("last_issue", {}) != opening_issue \
			or String(recovery.get("visible_message", "")) == FAILURE_MESSAGE \
			or String(recovery.get("visible_action_feedback", "")).contains(FAILURE_MESSAGE) \
			or focus_owner != "EndTurn" \
			or live.scenario_status != "in_progress" or not live.battle.is_empty() \
			or _gameplay_payload(live) != _gameplay_payload_dictionary(expected_payload) \
			or restored == null or _gameplay_payload(restored) != _gameplay_payload(live) \
			or not _canonical_generated(live) or not _canonical_generated(restored) \
			or not bool(control_result.get("ok", false)) \
			or RuntimeIssueLog.issue_record_count() != 1 \
			or not _artifacts_absent(AUTOSAVE_PATH):
		await _discard(shell)
		return _fail_dictionary("Alternate %s End Turn did not reconcile exactly: %s" % [row, JSON.stringify({"end": end_result, "end_snapshot": _compact_end_turn(end_snapshot), "recovery": _compact(recovery), "reconciliation": reconciliation, "focus": focus_owner, "live_control_difference": _first_difference(_gameplay_payload_dictionary(expected_payload), _gameplay_payload(live)), "restore_difference": _first_difference(_gameplay_payload(live), _gameplay_payload(restored)) if restored != null else {"restored": false}, "issue_records": RuntimeIssueLog.issue_record_count(), "artifacts_absent": _artifacts_absent(AUTOSAVE_PATH)})])

	var autosave_after := _file_state(AUTOSAVE_PATH)
	var manual_after := _file_state(MANUAL_PATH)
	var next_save: Dictionary = shell.validation_request_manual_save()
	await _settle(2)
	var after_next_save: Dictionary = shell.validation_generated_opening_autosave_recovery_snapshot()
	if not bool(next_save.get("visible", false)) \
			or int(next_save.get("pending_slot", 0)) != 1 \
			or int(after_next_save.get("manual_fallback_count", -1)) != 1 \
			or String(after_next_save.get("last_retry_result", {}).get("reason", "")) == "not_pending" \
			or _file_state(AUTOSAVE_PATH) != autosave_after \
			or _file_state(MANUAL_PATH) != manual_after:
		await _discard(shell)
		return _fail_dictionary("Next Save after alternate %s reconciliation did not enter ordinary overwrite flow." % row)
	shell.validation_cancel_manual_save_overwrite()
	await _discard(shell)
	return {"rules": 1, "autosaves": 1, "reconciled": true, "issue_count": 1, "focus": "EndTurn", "next_save": "manual_overwrite"}


func _prove_alternate_end_turn_failure(row: String) -> Dictionary:
	_clear_runtime_files()
	var prior := _ordinary_session("failed-end-prior")
	if not bool(SaveService.save_runtime_autosave_session(prior).get("ok", false)) \
			or not bool(SaveService.save_runtime_manual_session(prior, 1).get("ok", false)):
		return _fail_dictionary("Could not seed failed alternate End Turn slots.")
	SaveService.inspect_autosave()
	var bytes_before := _file_state(AUTOSAVE_PATH)
	var cache_before: Dictionary = SaveService.validation_summary_cache_snapshot()
	var fixture := _generated_pending_end_turn_session("failed-end-%s" % row)
	_set_injection(row)
	SessionState.set_active_session(fixture)
	var shell := OverworldShellScene.instantiate()
	add_child(shell)
	await _settle(7)
	var opening: Dictionary = shell.validation_generated_opening_autosave_recovery_snapshot()
	var opening_issue: Dictionary = opening.get("last_issue", {}).duplicate(true)
	var control := _duplicate_session(SessionState.ensure_active_session())
	var control_result: Dictionary = OverworldRules.end_turn(control)
	control.flags["last_action"] = "ended_turn"
	var end_result: Dictionary = shell.validation_request_end_turn()
	if bool(end_result.get("confirmation_required", false)):
		end_result = shell.validation_confirm_end_turn()
	await _settle(4)
	var end_snapshot: Dictionary = shell.validation_end_turn_confirmation_snapshot()
	var recovery: Dictionary = shell.validation_generated_opening_autosave_recovery_snapshot()
	var issues: Array = RuntimeIssueLog.last_issue_records(3)
	var last_issue: Dictionary = issues[issues.size() - 1] if not issues.is_empty() else {}
	var focus_owner := get_viewport().gui_get_focus_owner()
	if not bool(end_result.get("committed", false)) \
			or bool(end_result.get("ok", true)) \
			or String(end_result.get("reason", "")) != "autosave_failed" \
			or String(end_result.get("retry_action", "")) != "save" \
			or not bool(end_result.get("rules_applied", false)) \
			or int(end_snapshot.get("rules_end_turn_call_count", -1)) != 1 \
			or int(end_snapshot.get("autosave_call_count", -1)) != 1 \
			or int(end_snapshot.get("autosave_failure_count", -1)) != 1 \
			or int(end_snapshot.get("resolution_attempt_count", -1)) != 0 \
			or not bool(recovery.get("pending", false)) \
			or int(recovery.get("reconciliation_count", -1)) != 0 \
			or recovery.get("last_issue", {}) != opening_issue \
			or String(recovery.get("visible_message", "")) != END_TURN_FAILURE_MESSAGE \
			or focus_owner == null or String(focus_owner.name) != "EndTurn" \
			or RuntimeIssueLog.issue_record_count() != 2 \
			or String(last_issue.get("event", "")) != "end_turn_autosave_failed" \
			or String(last_issue.get("metadata", {}).get("retry_action", "")) != "save" \
			or not bool(control_result.get("ok", false)) \
			or _gameplay_payload(SessionState.ensure_active_session()) != _gameplay_payload(control) \
			or _file_state(AUTOSAVE_PATH) != bytes_before \
			or SaveService.validation_summary_cache_snapshot() != cache_before \
			or not _artifacts_absent(AUTOSAVE_PATH):
		await _discard(shell)
		return _fail_dictionary("Failed alternate End Turn did not preserve recovery authority: %s" % JSON.stringify({"end": end_result, "snapshot": _compact_end_turn(end_snapshot), "recovery": _compact(recovery), "focus": focus_owner.name if focus_owner != null else "", "issues": issues}))

	_clear_injections()
	var alternate_save: Dictionary = SaveService.save_runtime_autosave_session(SessionState.ensure_active_session(), false)
	var bytes_after_alternate := _file_state(AUTOSAVE_PATH)
	var cache_after_alternate: Dictionary = SaveService.validation_summary_cache_snapshot()
	var stale_retry: Dictionary = shell.validation_retry_generated_opening_autosave_direct()
	await _settle(3)
	var after_stale: Dictionary = shell.validation_generated_opening_autosave_recovery_snapshot()
	if not bool(alternate_save.get("ok", false)) \
			or not bool(stale_retry.get("reconciled", false)) \
			or String(stale_retry.get("reason", "")) != "not_pending" \
			or bool(stale_retry.get("reconciliation_write_attempted", true)) \
			or int(after_stale.get("retry_attempt_count", -1)) != 0 \
			or int(after_stale.get("reconciliation_count", -1)) != 1 \
			or bool(after_stale.get("pending", true)) \
			or String(after_stale.get("visible_message", "")) == FAILURE_MESSAGE \
			or _file_state(AUTOSAVE_PATH) != bytes_after_alternate \
			or SaveService.validation_summary_cache_snapshot() != cache_after_alternate \
			or not _artifacts_absent(AUTOSAVE_PATH):
		await _discard(shell)
		return _fail_dictionary("Canonical stale direct retry performed another write or retained recovery: %s" % JSON.stringify(stale_retry))
	var next_save: Dictionary = shell.validation_request_manual_save()
	await _settle(2)
	if not bool(next_save.get("visible", false)) or int(shell.validation_generated_opening_autosave_recovery_snapshot().get("manual_fallback_count", -1)) != 1:
		await _discard(shell)
		return _fail_dictionary("Post-stale-reconciliation Save did not enter ordinary overwrite flow.")
	shell.validation_cancel_manual_save_overwrite()
	await _discard(shell)
	return {"rules": 1, "autosave_failure": 1, "retry_action": "save", "recovery_preserved": true, "stale_retry_write_attempts": 0, "next_save": "manual_overwrite"}


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


func _generated_pending_end_turn_session(suffix: String) -> SessionStateStoreScript.SessionData:
	var session := _generated_pending_session(suffix)
	var movement: Dictionary = session.overworld.get("movement", {}) if session.overworld.get("movement", {}) is Dictionary else {}
	movement["current"] = 0
	session.overworld["movement"] = movement
	OverworldRules.consume_command_risk_forecast(session)
	OverworldRules.mark_runtime_normalized_transition_state(session)
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


func _duplicate_session(session: SessionStateStoreScript.SessionData) -> SessionStateStoreScript.SessionData:
	var duplicate := SessionStateStoreScript.new_session_data()
	duplicate.from_dict(session.to_dict())
	return duplicate


func _canonical_generated_payload(value: Dictionary) -> Dictionary:
	var payload := _canonical_dictionary(value)
	var flags: Dictionary = payload.get("flags", {}) if payload.get("flags", {}) is Dictionary else {}
	flags.erase(SaveService.GENERATED_OPENING_AUTOSAVE_PENDING_FLAG)
	flags.erase(SaveService.GENERATED_OPENING_AUTOSAVE_BRIEFING_DEFERRED_FLAG)
	flags[SaveService.GENERATED_OPENING_AUTOSAVE_COMPLETED_FLAG] = true
	for key_value in SaveService.TRANSITION_AUTOSAVE_INTENT_FLAGS:
		flags.erase(String(key_value))
	payload["flags"] = flags
	return payload


func _gameplay_payload(session) -> Dictionary:
	return _gameplay_payload_dictionary(session.to_dict()) if session != null else {}


func _gameplay_payload_dictionary(value: Dictionary) -> Dictionary:
	var payload := _canonical_dictionary(value)
	for metadata_key in ["saved_at_unix", "save_slot_type", "saved_from_game_state", "saved_from_scenario_status", "saved_from_launch_mode", "manual_slot_name"]:
		payload.erase(metadata_key)
	var overworld: Dictionary = payload.get("overworld", {}) if payload.get("overworld", {}) is Dictionary else {}
	overworld.erase("command_briefing")
	overworld.erase("command_risk_forecast")
	payload["overworld"] = overworld
	return payload


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
	return {"pending": snapshot.get("pending"), "initial": snapshot.get("initial_attempt_count"), "retry": snapshot.get("retry_attempt_count"), "success": snapshot.get("success_count"), "failure": snapshot.get("failure_count"), "issue": snapshot.get("issue_count"), "reconciliation": snapshot.get("reconciliation_count"), "message": snapshot.get("visible_message"), "focus": snapshot.get("focus_owner"), "routes": snapshot.get("resolution_route_attempt_count")}


func _compact_end_turn(snapshot: Dictionary) -> Dictionary:
	return {"rules": snapshot.get("rules_end_turn_call_count"), "autosaves": snapshot.get("autosave_call_count"), "failures": snapshot.get("autosave_failure_count"), "routes": snapshot.get("resolution_attempt_count"), "message": snapshot.get("visible_message")}


func _first_difference(expected: Variant, actual: Variant, path: String = "$") -> Dictionary:
	if typeof(expected) != typeof(actual):
		return {"path": path, "expected_type": type_string(typeof(expected)), "actual_type": type_string(typeof(actual))}
	if expected is Dictionary:
		var expected_dictionary: Dictionary = expected
		var actual_dictionary: Dictionary = actual
		var expected_keys: Array = expected_dictionary.keys()
		var actual_keys: Array = actual_dictionary.keys()
		expected_keys.sort()
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
