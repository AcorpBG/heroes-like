extends Node

const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const OverworldShellScene = preload("res://scenes/overworld/OverworldShell.tscn")

const REPORT_ID := "OVERWORLD_END_TURN_AUTOSAVE_FAILURE_REGRESSION"
const FAILURE_ENV := "HEROES_LIKE_SAVE_FAIL_PHASE"
const AUTOSAVE_PATH := "user://saves/autosave.json"
const MANUAL_PATH := "user://saves/slot1.json"
const ISSUE_LOG_PATH := "user://debug/heroes_runtime_issues.jsonl"
const LATEST_ISSUE_PATH := "user://debug/heroes_last_runtime_issue.json"

var _original_active_session = null
var _original_failure_env := ""
var _original_file_states := {}


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_original_active_session = SessionState.active_session
	_original_failure_env = OS.get_environment(FAILURE_ENV)
	_original_file_states = _capture_file_states(_tracked_paths())
	OS.unset_environment(FAILURE_ENV)
	if not _require_hooks():
		return
	if SessionState.SAVE_VERSION != 9:
		_fail_bool("End Turn autosave recovery must preserve save version 9.")
		return

	var precommit := await _prove_failure_and_manual_recovery("precommit", false)
	if precommit.is_empty():
		return
	var after_backup := await _prove_failure_and_manual_recovery("after_backup", true)
	if after_backup.is_empty():
		return
	var pending_battle := {}
	for phase_value in ["precommit", "after_backup"]:
		var phase := String(phase_value)
		for occupied_value in [false, true]:
			var occupied := bool(occupied_value)
			var case_id := "%s_%s" % [phase, "occupied" if occupied else "empty"]
			var pending_case: Dictionary = await _prove_pending_battle_manual_save_failure(phase, occupied)
			if pending_case.is_empty():
				return
			pending_battle[case_id] = pending_case
	var controls := await _prove_controls()
	if controls.is_empty():
		return

	_cleanup()
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"failure_phases": {
			"precommit": precommit,
			"after_backup": after_backup,
		},
		"pending_battle": pending_battle,
		"controls": controls,
		"save_version": SessionState.SAVE_VERSION,
	})])
	get_tree().quit(0)


func _require_hooks() -> bool:
	var probe = OverworldShellScene.instantiate()
	for method_name in [
		"validation_request_end_turn",
		"validation_confirm_end_turn",
		"validation_end_turn_confirmation_snapshot",
		"validation_reset_end_turn_confirmation_state",
		"validation_select_save_slot",
		"validation_save_to_selected_slot",
		"validation_set_end_turn_resolution_routing_enabled",
	]:
		if not probe.has_method(method_name):
			probe.free()
			return _fail_bool("OverworldShell is missing validation hook %s." % method_name)
	probe.free()
	for method_name in [
		"validation_summary_cache_snapshot",
		"validation_clear_summary_cache",
		"validation_transaction_artifact_paths",
	]:
		if not SaveService.has_method(method_name):
			return _fail_bool("SaveService is missing transaction hook %s." % method_name)
	return true


func _prove_failure_and_manual_recovery(phase: String, warned: bool) -> Dictionary:
	_clear_tracked_save_files()
	var prior_session = _movement_fixture(1, true)
	var prior_save: Dictionary = SaveService.save_runtime_autosave_session(prior_session)
	if not bool(prior_save.get("ok", false)) or not FileAccess.file_exists(AUTOSAVE_PATH):
		return _fail_dictionary("Could not seed the prior autosave for %s." % phase)
	var old_file_state := _file_state(AUTOSAVE_PATH)
	var fixture: SessionStateStoreScript.SessionData = _movement_fixture(2, not warned)
	var shell = await _create_shell(fixture)
	if shell == null:
		return {}
	var live_session: SessionStateStoreScript.SessionData = SessionState.ensure_active_session()
	var initial_forecast := _command_risk_forecast_snapshot(live_session)
	if int(initial_forecast.get("signature_day", -1)) != 2 \
			or bool(initial_forecast.get("shown", false)) != not warned \
			or int(initial_forecast.get("shown_day", -1)) != (0 if warned else 2):
		await _discard_shell(shell)
		return _fail_dictionary("The %s fixture did not begin with the exact Day 2 %s command-risk forecast: %s" % [
			phase,
			"unconsumed" if warned else "consumed",
			JSON.stringify(initial_forecast),
		])
	SaveService.inspect_autosave()
	var cache_before: Dictionary = SaveService.validation_summary_cache_snapshot()
	if cache_before.is_empty():
		await _discard_shell(shell)
		return _fail_dictionary("Could not prime the autosave summary cache for %s." % phase)
	var control := _duplicate_session(live_session)
	var issue_count_before := RuntimeIssueLog.issue_record_count()
	OS.set_environment(FAILURE_ENV, phase)
	var result: Dictionary
	if warned:
		var request: Dictionary = shell.validation_request_end_turn()
		var requested: Dictionary = shell.validation_end_turn_confirmation_snapshot()
		if not bool(request.get("confirmation_required", false)) \
				or not bool(requested.get("pending", false)) \
				or not bool(requested.get("risk_unconsumed", false)):
			OS.unset_environment(FAILURE_ENV)
			await _discard_shell(shell)
			return _fail_dictionary("Warned %s fixture did not request confirmation." % phase)
		if bool(requested.get("risk_unconsumed", false)):
			OverworldRules.consume_command_risk_forecast(control)
		result = shell.validation_confirm_end_turn()
	else:
		result = shell.validation_request_end_turn()
	OS.unset_environment(FAILURE_ENV)

	var direct_result: Dictionary = OverworldRules.end_turn(control)
	control.flags["last_action"] = "ended_turn"
	await get_tree().process_frame
	var snapshot: Dictionary = shell.validation_end_turn_confirmation_snapshot()
	var autosave_result: Dictionary = snapshot.get("last_autosave_result", {}) if snapshot.get("last_autosave_result", {}) is Dictionary else {}
	var live_payload := _gameplay_payload(live_session)
	var control_payload := _gameplay_payload(control)
	var transition_authority := _end_turn_transition_authority(live_session)
	var control_transition_authority := _end_turn_transition_authority(control)
	var canonical_check := _normalization_idempotence_check(live_session)
	var post_turn_forecast := _command_risk_forecast_snapshot(live_session)
	var focus_owner_after_failure := _focus_owner_name()
	var issue_records: Array = RuntimeIssueLog.last_issue_records(1)
	var issue: Dictionary = issue_records[0] if not issue_records.is_empty() and issue_records[0] is Dictionary else {}
	var visible_message := String(snapshot.get("visible_message", snapshot.get("message", "")))
	if bool(result.get("ok", true)) \
			or not bool(result.get("committed", false)) \
			or String(result.get("reason", "")) != "autosave_failed" \
			or not bool(result.get("rules_applied", false)) \
			or not bool(result.get("save_failed", false)) \
			or String(result.get("retry_action", "")) != "manual_save" \
			or String(result.get("message", "")).strip_edges() == "":
		await _discard_shell(shell)
		return _fail_dictionary("Injected %s failure returned a dishonest End Turn result: %s" % [phase, JSON.stringify(result)])
	if int(snapshot.get("rules_end_turn_call_count", -1)) != 1 \
			or int(snapshot.get("autosave_call_count", -1)) != 1 \
			or bool(autosave_result.get("ok", true)):
		await _discard_shell(shell)
		return _fail_dictionary("Injected %s failure did not call rules/save exactly once: %s" % [phase, JSON.stringify(_compact_snapshot(snapshot))])
	if live_session.day != 3 \
			or live_payload != control_payload \
			or transition_authority != control_transition_authority \
			or _result_signature(snapshot.get("last_rule_result", {})) != _result_signature(direct_result) \
			or int(post_turn_forecast.get("signature_day", -1)) != 3 \
			or bool(post_turn_forecast.get("shown", true)) \
			or int(post_turn_forecast.get("shown_day", -1)) != 0 \
			or not bool(canonical_check.get("runtime_normalized", false)) \
			or not bool(canonical_check.get("once_exact", false)) \
			or not bool(canonical_check.get("twice_exact", false)):
		await _discard_shell(shell)
		return _fail_dictionary("Injected %s failure did not retain the exact canonical advanced live gameplay state: %s" % [phase, JSON.stringify({
			"payload_difference": _first_difference(control_payload, live_payload),
			"transition_authority_difference": _first_difference(control_transition_authority, transition_authority),
			"forecast": post_turn_forecast,
			"canonical": canonical_check,
		})])
	if _file_state(AUTOSAVE_PATH) != old_file_state \
			or SaveService.validation_summary_cache_snapshot() != cache_before \
			or not _transaction_artifacts_absent(AUTOSAVE_PATH) \
			or int(snapshot.get("request_count", -1)) != 1 \
			or int(snapshot.get("confirm_count", -1)) != (1 if warned else 0) \
			or int(snapshot.get("commit_count", -1)) != 1 \
			or int(snapshot.get("autosave_failure_count", -1)) != 1 \
			or int(snapshot.get("resolution_attempt_count", -1)) != 0 \
			or not (snapshot.get("last_resolution_route", {}) as Dictionary).is_empty() \
			or focus_owner_after_failure != "EndTurn":
		await _discard_shell(shell)
		return _fail_dictionary("Injected %s failure changed prior authority, route, focus, bytes/cache, or left transaction residue: %s" % [phase, JSON.stringify({
			"snapshot": _compact_snapshot(snapshot),
			"focus_owner": focus_owner_after_failure,
		})])
	if RuntimeIssueLog.issue_record_count() != issue_count_before + 1 \
			or String(issue.get("event", "")) != "end_turn_autosave_failed" \
			or String(issue.get("message", "")).strip_edges() == "" \
			or visible_message.strip_edges() == "" \
			or visible_message != String(result.get("message", "")):
		await _discard_shell(shell)
		return _fail_dictionary("Injected %s failure was not surfaced honestly in the shell and RuntimeIssueLog: %s" % [phase, JSON.stringify({"result": result, "visible_message": visible_message, "issue": issue})])

	var rules_calls_before_manual := int(snapshot.get("rules_end_turn_call_count", -1))
	if not shell.validation_select_save_slot(1):
		await _discard_shell(shell)
		return _fail_dictionary("Could not select Manual Slot 1 after %s failure." % phase)
	var manual_result: Dictionary = shell.validation_save_to_selected_slot()
	var after_manual: Dictionary = shell.validation_end_turn_confirmation_snapshot()
	var post_manual_payload := _gameplay_payload(live_session)
	var post_manual_full_payload := _canonical_session_payload(live_session)
	var raw_manual_payload := _canonical_session_payload_dictionary(SaveService.load_session(1))
	var restored = SaveService.restore_manual_session(1)
	var restored_full_payload := _canonical_session_payload(restored)
	if not bool(manual_result.get("ok", false)) \
			or restored == null \
			or _gameplay_payload(restored) != post_manual_payload \
			or raw_manual_payload != post_manual_full_payload \
			or restored_full_payload != post_manual_full_payload \
			or int(after_manual.get("rules_end_turn_call_count", -1)) != rules_calls_before_manual \
			or int(after_manual.get("autosave_call_count", -1)) != 1 \
			or int(after_manual.get("resolution_attempt_count", -1)) != 0 \
			or not (after_manual.get("last_resolution_route", {}) as Dictionary).is_empty() \
			or not _transaction_artifacts_absent(MANUAL_PATH):
		await _discard_shell(shell)
		return _fail_dictionary("Manual Save did not preserve the advanced %s state without a second End Turn: %s" % [phase, JSON.stringify({
			"manual": manual_result,
			"snapshot": _compact_snapshot(after_manual),
			"restored": restored != null,
			"raw_difference": _first_difference(post_manual_full_payload, raw_manual_payload),
			"restored_difference": _first_difference(post_manual_full_payload, restored_full_payload),
		})])

	await _discard_shell(shell)
	return {
		"warned": warned,
		"old_autosave_bytes_exact": true,
		"cache_exact": true,
		"no_transaction_residue": true,
		"rules_calls": 1,
		"autosave_calls": 1,
		"advanced_live_state_retained": true,
		"day2_forecast_consumed": true,
		"day3_forecast_canonical_unconsumed": true,
		"normalization_idempotent": true,
		"hook_occupation_recovery_income_muster_exact": true,
		"full_raw_manual_exact": true,
		"focus_owner_after_failure": focus_owner_after_failure,
		"runtime_issue_event": "end_turn_autosave_failed",
		"manual_reload_exact": true,
		"second_end_turn_calls": 0,
	}


func _prove_pending_battle_manual_save_failure(phase: String, occupied: bool) -> Dictionary:
	_clear_tracked_save_files()
	var prior_session: SessionStateStoreScript.SessionData = _movement_fixture(1, true)
	var prior_save: Dictionary = SaveService.save_runtime_autosave_session(prior_session)
	if not bool(prior_save.get("ok", false)):
		return _fail_dictionary("Could not seed prior autosave for pending-battle %s/%s control." % [phase, "occupied" if occupied else "empty"])
	if occupied:
		var prior_manual: Dictionary = SaveService.save_runtime_manual_session(prior_session, 1)
		if not bool(prior_manual.get("ok", false)):
			return _fail_dictionary("Could not seed occupied Manual Slot 1 for pending-battle %s control." % phase)
	var old_autosave_state := _file_state(AUTOSAVE_PATH)
	var old_manual_state := _file_state(MANUAL_PATH)
	if bool(old_manual_state.get("exists", false)) != occupied:
		return _fail_dictionary("Pending-battle %s fixture did not establish the requested %s manual slot." % [phase, "occupied" if occupied else "empty"])
	var session: SessionStateStoreScript.SessionData = _movement_fixture(2, true)
	var encounters: Array = session.overworld.get("encounters", []) if session.overworld.get("encounters", []) is Array else []
	var encounter: Dictionary = {}
	for encounter_value in encounters:
		if encounter_value is Dictionary:
			encounter = encounter_value
			break
	if encounter.is_empty():
		return _fail_dictionary("Pending-battle control has no authored encounter fixture.")
	session.battle = BattleRules.create_battle_payload(session, encounter)
	if session.battle.is_empty():
		return _fail_dictionary("Pending-battle control could not create its battle payload.")
	OverworldRules.mark_runtime_normalized_transition_state(session)
	var shell = await _create_shell(session)
	if shell == null:
		return {}
	session = SessionState.ensure_active_session()
	shell.validation_set_end_turn_resolution_routing_enabled(false)
	OS.set_environment(FAILURE_ENV, phase)
	var failed: Dictionary = shell.validation_request_end_turn()
	if bool(failed.get("confirmation_required", false)):
		failed = shell.validation_confirm_end_turn()
	var failed_snapshot: Dictionary = shell.validation_end_turn_confirmation_snapshot()
	if String(failed.get("reason", "")) != "autosave_failed" \
			or not bool(failed.get("battle_pending", false)) \
			or int(failed_snapshot.get("rules_end_turn_call_count", -1)) != 1 \
			or int(failed_snapshot.get("autosave_call_count", -1)) != 1 \
			or int(failed_snapshot.get("resolution_attempt_count", -1)) != 0 \
			or session.battle.is_empty() \
			or _file_state(AUTOSAVE_PATH) != old_autosave_state \
			or not _transaction_artifacts_absent(AUTOSAVE_PATH):
		OS.unset_environment(FAILURE_ENV)
		await _discard_shell(shell)
		return _fail_dictionary("Pending-battle %s/%s autosave failure routed early, lost its warning/state, or changed prior autosave: %s" % [phase, "occupied" if occupied else "empty", JSON.stringify({"result": failed, "snapshot": _compact_snapshot(failed_snapshot)})])
	if not shell.validation_select_save_slot(1):
		OS.unset_environment(FAILURE_ENV)
		await _discard_shell(shell)
		return _fail_dictionary("Pending-battle %s/%s control could not select Manual Slot 1." % [phase, "occupied" if occupied else "empty"])
	SaveService.inspect_manual_slot(1)
	var cache_before: Dictionary = SaveService.validation_summary_cache_snapshot()
	if cache_before.is_empty():
		OS.unset_environment(FAILURE_ENV)
		await _discard_shell(shell)
		return _fail_dictionary("Pending-battle %s/%s control could not prime the manual summary cache." % [phase, "occupied" if occupied else "empty"])
	var live_before_manual: Dictionary = session.to_dict()
	var rules_calls := int(failed_snapshot.get("rules_end_turn_call_count", -1))
	var autosave_calls := int(failed_snapshot.get("autosave_call_count", -1))
	var manual_failed: Dictionary = shell.validation_save_to_selected_slot()
	var after_failed_manual: Dictionary = shell.validation_end_turn_confirmation_snapshot()
	var failed_save_result: Dictionary = manual_failed.get("save_result", {}) if manual_failed.get("save_result", {}) is Dictionary else {}
	var failure_visible_message := String(after_failed_manual.get("visible_message", "")).strip_edges()
	var failure_feedback := String(after_failed_manual.get("visible_action_feedback", "")).strip_edges()
	if bool(manual_failed.get("ok", true)) \
			or bool(manual_failed.get("saved", true)) \
			or bool(manual_failed.get("routed", true)) \
			or int(manual_failed.get("route_attempt_delta", -1)) != 0 \
			or String(manual_failed.get("reason", "")) != "manual_save_failed" \
			or String(manual_failed.get("retry_action", "")) != "manual_save" \
			or not bool(manual_failed.get("battle_pending", false)) \
			or bool(failed_save_result.get("ok", true)) \
			or String(manual_failed.get("message", "")).strip_edges() == "" \
			or failure_visible_message != String(manual_failed.get("message", "")).strip_edges() \
			or failure_feedback == "":
		OS.unset_environment(FAILURE_ENV)
		await _discard_shell(shell)
		return _fail_dictionary("Pending-battle %s/%s manual failure result or retry surface was dishonest: %s" % [phase, "occupied" if occupied else "empty", JSON.stringify(_compact_manual_result(manual_failed, after_failed_manual))])
	if _file_state(MANUAL_PATH) != old_manual_state \
			or SaveService.validation_summary_cache_snapshot() != cache_before \
			or session.to_dict() != live_before_manual \
			or not _transaction_artifacts_absent(MANUAL_PATH) \
			or int(after_failed_manual.get("resolution_attempt_count", -1)) != 0 \
			or int(after_failed_manual.get("manual_save_attempt_count", -1)) != 1 \
			or int(after_failed_manual.get("manual_save_success_count", -1)) != 0 \
			or int(after_failed_manual.get("manual_save_failure_count", -1)) != 1 \
			or int(after_failed_manual.get("manual_save_route_attempt_count", -1)) != 0 \
			or int(after_failed_manual.get("rules_end_turn_call_count", -1)) != rules_calls \
			or int(after_failed_manual.get("autosave_call_count", -1)) != autosave_calls:
		OS.unset_environment(FAILURE_ENV)
		await _discard_shell(shell)
		return _fail_dictionary("Pending-battle %s/%s manual failure changed bytes/cache/live state, routed, or left residue: %s" % [phase, "occupied" if occupied else "empty", JSON.stringify(_compact_manual_result(manual_failed, after_failed_manual))])

	OS.unset_environment(FAILURE_ENV)
	var manual_saved: Dictionary = shell.validation_save_to_selected_slot()
	var after_saved_manual: Dictionary = shell.validation_end_turn_confirmation_snapshot()
	var route: Dictionary = after_saved_manual.get("last_resolution_route", {}) if after_saved_manual.get("last_resolution_route", {}) is Dictionary else {}
	var persisted_dictionary: Dictionary = SaveService.load_session(1)
	var restored = SaveService.restore_manual_session(1)
	var session_payload := _gameplay_payload_dictionary(persisted_dictionary)
	var restored_payload := _gameplay_payload(restored) if restored != null else {}
	if not bool(manual_saved.get("ok", false)) \
			or not bool(manual_saved.get("saved", false)) \
			or not bool(manual_saved.get("routed", false)) \
			or int(manual_saved.get("route_attempt_delta", -1)) != 1 \
			or String(manual_saved.get("reason", "")) != "saved" \
			or restored == null \
			or restored_payload != session_payload \
			or String(restored.session_id) != String(session.session_id) \
			or int(restored.day) != int(session.day) \
			or String(restored.scenario_status) != String(session.scenario_status) \
			or String(restored.battle.get("id", "")) != String(session.battle.get("id", "")) \
			or SaveService.resume_target_for_session(restored) != "battle" \
			or int(after_saved_manual.get("resolution_attempt_count", -1)) != 1 \
			or String(route.get("target", "")) != "battle" \
			or int(after_saved_manual.get("manual_save_attempt_count", -1)) != 2 \
			or int(after_saved_manual.get("manual_save_success_count", -1)) != 1 \
			or int(after_saved_manual.get("manual_save_failure_count", -1)) != 1 \
			or int(after_saved_manual.get("manual_save_route_attempt_count", -1)) != 1 \
			or int(after_saved_manual.get("rules_end_turn_call_count", -1)) != rules_calls \
			or int(after_saved_manual.get("autosave_call_count", -1)) != autosave_calls \
			or not _transaction_artifacts_absent(MANUAL_PATH):
		await _discard_shell(shell)
		return _fail_dictionary("Pending-battle %s/%s retry did not persist canonical battle state and route exactly once: %s" % [phase, "occupied" if occupied else "empty", JSON.stringify({
			"manual": _compact_manual_result(manual_saved, after_saved_manual),
			"route": route,
			"restored": restored != null,
			"resume_target": SaveService.resume_target_for_session(restored) if restored != null else "",
			"payload_difference": _first_difference(session_payload, restored_payload),
		})])
	await _discard_shell(shell)
	return {
		"phase": phase,
		"occupied": occupied,
		"battle_pending_on_failure": true,
		"old_manual_bytes_exact": true,
		"cache_exact": true,
		"live_pending_battle_exact": true,
		"no_transaction_residue": true,
		"failure_result_honest": true,
		"visible_retry": true,
		"failure_route_attempts": 0,
		"manual_reload_exact": true,
		"manual_attempts": 2,
		"manual_failures": 1,
		"manual_successes": 1,
		"manual_route_attempts": 1,
		"manual_route_target": "battle",
		"second_end_turn_calls": 0,
	}


func _prove_controls() -> Dictionary:
	var direct := await _prove_ordinary_end_turn_autosave(false)
	if direct.is_empty():
		return {}
	var warned := await _prove_ordinary_end_turn_autosave(true)
	if warned.is_empty():
		return {}

	var terminal: SessionStateStoreScript.SessionData = _movement_fixture(2, true)
	_stage_river_pass_victory(terminal)
	var terminal_shell = await _create_shell(terminal)
	if terminal_shell == null:
		return {}
	terminal = SessionState.ensure_active_session()
	terminal_shell.validation_set_end_turn_resolution_routing_enabled(false)
	var terminal_result: Dictionary = terminal_shell.validation_request_end_turn()
	if bool(terminal_result.get("confirmation_required", false)):
		terminal_result = terminal_shell.validation_confirm_end_turn()
	var terminal_snapshot: Dictionary = terminal_shell.validation_end_turn_confirmation_snapshot()
	var terminal_route: Dictionary = terminal_snapshot.get("last_resolution_route", {}) if terminal_snapshot.get("last_resolution_route", {}) is Dictionary else {}
	if not bool(terminal_result.get("ok", false)) or not bool(terminal_result.get("resolved", false)) \
			or terminal.scenario_status != "victory" \
			or int(terminal_snapshot.get("rules_end_turn_call_count", -1)) != 1 \
			or int(terminal_snapshot.get("autosave_call_count", -1)) != 0 \
			or int(terminal_snapshot.get("resolution_attempt_count", -1)) != 1 \
			or String(terminal_route.get("target", "")) != "outcome":
		await _discard_shell(terminal_shell)
		return _fail_dictionary("Scenario-terminal End Turn control did not resolve once without autosave: %s" % JSON.stringify({
			"result": {
				"ok": terminal_result.get("ok", false),
				"committed": terminal_result.get("committed", false),
				"resolved": terminal_result.get("resolved", false),
				"reason": terminal_result.get("reason", ""),
			},
			"status": terminal.scenario_status,
			"snapshot": _compact_snapshot(terminal_snapshot),
			"route": terminal_route,
		}))
	await _discard_shell(terminal_shell)
	return {"direct": direct, "warned": warned, "terminal_no_save": true}


func _prove_ordinary_end_turn_autosave(warned: bool) -> Dictionary:
	_clear_tracked_save_files()
	var shell = await _create_shell(_movement_fixture(2, not warned))
	if shell == null:
		return {}
	var session: SessionStateStoreScript.SessionData = SessionState.ensure_active_session()
	var initial_forecast := _command_risk_forecast_snapshot(session)
	var request: Dictionary = shell.validation_request_end_turn()
	var result := request
	if warned:
		var requested: Dictionary = shell.validation_end_turn_confirmation_snapshot()
		if not bool(request.get("confirmation_required", false)) \
				or not bool(requested.get("pending", false)) \
				or not bool(requested.get("risk_unconsumed", false)):
			await _discard_shell(shell)
			return _fail_dictionary("Ordinary warned End Turn did not preserve the exact Day 2 confirmation contract: %s" % JSON.stringify({
				"request": request,
				"snapshot": _compact_snapshot(requested),
				"forecast": initial_forecast,
			}))
		result = shell.validation_confirm_end_turn()
	await get_tree().process_frame
	var snapshot: Dictionary = shell.validation_end_turn_confirmation_snapshot()
	var live_payload := _canonical_session_payload(session)
	var raw_payload := _canonical_session_payload_dictionary(SaveService.load_autosave())
	var restored = SaveService.restore_autosave_session()
	var restored_payload := _canonical_session_payload(restored)
	var forecast := _command_risk_forecast_snapshot(session)
	var canonical_check := _normalization_idempotence_check(session)
	if int(initial_forecast.get("signature_day", -1)) != 2 \
			or bool(initial_forecast.get("shown", false)) != not warned \
			or int(initial_forecast.get("shown_day", -1)) != (0 if warned else 2) \
			or not bool(result.get("ok", false)) \
			or bool(result.get("confirmation_required", not warned)) != warned \
			or int(snapshot.get("request_count", -1)) != 1 \
			or int(snapshot.get("confirm_count", -1)) != (1 if warned else 0) \
			or int(snapshot.get("commit_count", -1)) != 1 \
			or int(snapshot.get("rules_end_turn_call_count", -1)) != 1 \
			or int(snapshot.get("autosave_call_count", -1)) != 1 \
			or int(snapshot.get("autosave_failure_count", -1)) != 0 \
			or int(snapshot.get("resolution_attempt_count", -1)) != 0 \
			or not (snapshot.get("last_resolution_route", {}) as Dictionary).is_empty() \
			or session.day != 3 \
			or int(forecast.get("signature_day", -1)) != 3 \
			or bool(forecast.get("shown", true)) \
			or int(forecast.get("shown_day", -1)) != 0 \
			or raw_payload != live_payload \
			or restored == null \
			or restored_payload != live_payload \
			or not bool(canonical_check.get("runtime_normalized", false)) \
			or not bool(canonical_check.get("once_exact", false)) \
			or not bool(canonical_check.get("twice_exact", false)) \
			or not _transaction_artifacts_absent(AUTOSAVE_PATH):
		await _discard_shell(shell)
		return _fail_dictionary("Ordinary %s End Turn autosave was not canonical and reload-exact: %s" % [
			"warned" if warned else "direct",
			JSON.stringify({
				"result": result,
				"snapshot": _compact_snapshot(snapshot),
				"initial_forecast": initial_forecast,
				"forecast": forecast,
				"canonical": canonical_check,
				"raw_difference": _first_difference(live_payload, raw_payload),
				"restored_difference": _first_difference(live_payload, restored_payload),
			}),
		])
	await _discard_shell(shell)
	return {
		"day2_forecast_consumed": true,
		"day3_forecast_canonical_unconsumed": true,
		"raw_autosave_exact": true,
		"restored_autosave_exact": true,
		"normalization_idempotent": true,
		"rules_calls": 1,
		"autosave_calls": 1,
		"route_attempts": 0,
	}


func _create_shell(session):
	SessionState.set_active_session(session)
	var shell = OverworldShellScene.instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	shell.validation_reset_end_turn_confirmation_state()
	return shell


func _discard_shell(shell) -> void:
	if shell != null and is_instance_valid(shell):
		shell.queue_free()
		await get_tree().process_frame


func _movement_fixture(day: int, exhausted: bool) -> SessionStateStoreScript.SessionData:
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	session.day = day
	session.game_state = "overworld"
	session.flags["end_turn_failure_marker"] = "%s_%s" % [day, "direct" if exhausted else "warned"]
	OverworldRules.normalize_overworld_state(session)
	var movement: Dictionary = session.overworld.get("movement", {}) if session.overworld.get("movement", {}) is Dictionary else {}
	movement["current"] = 0 if exhausted else maxi(1, int(movement.get("max", 6)))
	session.overworld["movement"] = movement
	if exhausted:
		OverworldRules.consume_command_risk_forecast(session)
	OverworldRules.mark_runtime_normalized_transition_state(session)
	return session


func _stage_river_pass_victory(session: SessionStateStoreScript.SessionData) -> void:
	var towns: Array = session.overworld.get("towns", []) if session.overworld.get("towns", []) is Array else []
	for index in range(towns.size()):
		var town = towns[index]
		if town is Dictionary and String(town.get("placement_id", "")) == "duskfen_bastion":
			town["owner"] = "player"
			towns[index] = town
			break
	session.overworld["towns"] = towns
	session.flags["pass_cleared"] = true
	session.flags["mire_cleared"] = true
	var resolved: Array = session.overworld.get("resolved_encounters", []) if session.overworld.get("resolved_encounters", []) is Array else []
	# This is an explicitly terminal persistence fixture, not a live play win.
	# The authored River Pass victory also requires its post-capture counterstroke.
	for placement in ["river_pass_ghoul_grove", "river_pass_hollow_mire", "river_pass_reed_totemists", "duskfen_counterstroke"]:
		if placement not in resolved:
			resolved.append(placement)
	session.overworld["resolved_encounters"] = resolved


func _duplicate_session(session: SessionStateStoreScript.SessionData) -> SessionStateStoreScript.SessionData:
	var duplicate := SessionStateStoreScript.new_session_data()
	duplicate.from_dict(session.to_dict())
	return duplicate


func _gameplay_payload(session) -> Dictionary:
	if session == null:
		return {}
	return _gameplay_payload_dictionary(session.to_dict())


func _gameplay_payload_dictionary(value: Dictionary) -> Dictionary:
	var payload := _canonical_dictionary(value)
	for metadata_key in ["saved_at_unix", "save_slot_type", "saved_from_game_state", "saved_from_scenario_status", "saved_from_launch_mode", "manual_slot_name"]:
		payload.erase(metadata_key)
	var overworld: Dictionary = payload.get("overworld", {}) if payload.get("overworld", {}) is Dictionary else {}
	overworld.erase("command_briefing")
	payload["overworld"] = overworld
	return payload


func _canonical_session_payload(session) -> Dictionary:
	if session == null:
		return {}
	return _canonical_session_payload_dictionary(session.to_dict())


func _canonical_session_payload_dictionary(value: Dictionary) -> Dictionary:
	var payload := _canonical_dictionary(value)
	for metadata_key in ["saved_at_unix", "save_slot_type", "saved_from_game_state", "saved_from_scenario_status", "saved_from_launch_mode", "manual_slot_name"]:
		payload.erase(metadata_key)
	return payload


func _command_risk_forecast_snapshot(session) -> Dictionary:
	if session == null:
		return {}
	var state_value: Variant = session.overworld.get(OverworldRules.COMMAND_RISK_FORECAST_KEY, {})
	var state: Dictionary = state_value if state_value is Dictionary else {}
	var signature := String(state.get("signature", ""))
	var signature_value: Variant = JSON.parse_string(signature) if signature != "" else {}
	var signature_payload: Dictionary = signature_value if signature_value is Dictionary else {}
	return {
		"shown": bool(state.get("shown", false)),
		"shown_day": int(state.get("shown_day", 0)),
		"signature_day": int(signature_payload.get("day", 0)),
		"signature": signature,
	}


func _normalization_idempotence_check(session) -> Dictionary:
	if session == null:
		return {}
	var before := _canonical_session_payload(session)
	var detached := _duplicate_session(session)
	OverworldRules.normalize_overworld_state(detached)
	var after_once := _canonical_session_payload(detached)
	OverworldRules.normalize_overworld_state(detached)
	var after_twice := _canonical_session_payload(detached)
	return {
		"runtime_normalized": OverworldRules.is_runtime_session_normalized(session),
		"once_exact": after_once == before,
		"twice_exact": after_twice == after_once,
		"once_difference": _first_difference(before, after_once),
		"twice_difference": _first_difference(after_once, after_twice),
	}


func _end_turn_transition_authority(session) -> Dictionary:
	if session == null:
		return {}
	var town_transitions := []
	var towns: Array = session.overworld.get("towns", []) if session.overworld.get("towns", []) is Array else []
	for town_value in towns:
		if not (town_value is Dictionary):
			continue
		var town: Dictionary = town_value
		town_transitions.append({
			"placement_id": String(town.get("placement_id", "")),
			"occupation": _canonical_dictionary(town.get("occupation", {}) if town.get("occupation", {}) is Dictionary else {}),
			"recovery": _canonical_dictionary(town.get("recovery", {}) if town.get("recovery", {}) is Dictionary else {}),
			"available_recruits": _canonical_dictionary(town.get("available_recruits", {}) if town.get("available_recruits", {}) is Dictionary else {}),
		})
	return {
		"day": session.day,
		"generated_random_map": bool(session.flags.get("generated_random_map", false)),
		"generated_map_provenance": _canonical_dictionary(session.flags.get("generated_map_provenance", {}) if session.flags.get("generated_map_provenance", {}) is Dictionary else {}),
		"scenario_script_state": _canonical_dictionary(session.overworld.get("scenario_script_state", {}) if session.overworld.get("scenario_script_state", {}) is Dictionary else {}),
		"resources": _canonical_dictionary(session.overworld.get("resources", {}) if session.overworld.get("resources", {}) is Dictionary else {}),
		"town_transitions": town_transitions,
	}


func _focus_owner_name() -> String:
	var viewport := get_viewport()
	var focus_owner := viewport.gui_get_focus_owner() if viewport != null else null
	return String(focus_owner.name) if focus_owner != null else ""


func _result_signature(value: Variant) -> Dictionary:
	var result: Dictionary = value if value is Dictionary else {}
	return {
		"ok": result.get("ok", false),
		"message": result.get("message", ""),
		"enemy_activity_summary": result.get("enemy_activity_summary", ""),
		"enemy_activity_events": result.get("enemy_activity_events", []),
		"resource_income_summary": result.get("resource_income_summary", ""),
		"weekly_muster_summary": result.get("weekly_muster_summary", ""),
		"movement_reset_summary": result.get("movement_reset_summary", ""),
		"town_economy_summary": result.get("town_economy_summary", ""),
		"turn_resolution_summary": result.get("turn_resolution_summary", ""),
	}


func _compact_snapshot(snapshot: Dictionary) -> Dictionary:
	var last_result: Dictionary = snapshot.get("last_result", {}) if snapshot.get("last_result", {}) is Dictionary else {}
	var last_autosave: Dictionary = snapshot.get("last_autosave_result", {}) if snapshot.get("last_autosave_result", {}) is Dictionary else {}
	return {
		"rules": snapshot.get("rules_end_turn_call_count", -1),
		"autosaves": snapshot.get("autosave_call_count", -1),
		"last_result": {
			"ok": last_result.get("ok", false),
			"reason": last_result.get("reason", ""),
			"message": last_result.get("message", ""),
			"battle_pending": last_result.get("battle_pending", false),
		},
		"last_autosave_result": {
			"ok": last_autosave.get("ok", false),
			"path": last_autosave.get("path", ""),
			"message": last_autosave.get("message", ""),
		},
		"visible_message": snapshot.get("visible_message", snapshot.get("message", "")),
		"resolution_attempt_count": snapshot.get("resolution_attempt_count", -1),
		"last_resolution_route": snapshot.get("last_resolution_route", {}),
	}


func _compact_manual_result(result: Dictionary, snapshot: Dictionary) -> Dictionary:
	var save_result: Dictionary = result.get("save_result", {}) if result.get("save_result", {}) is Dictionary else {}
	return {
		"result": {
			"ok": result.get("ok", false),
			"saved": result.get("saved", false),
			"routed": result.get("routed", false),
			"route_attempt_delta": result.get("route_attempt_delta", -1),
			"reason": result.get("reason", ""),
			"retry_action": result.get("retry_action", ""),
			"battle_pending": result.get("battle_pending", false),
			"message": result.get("message", ""),
			"save_ok": save_result.get("ok", false),
		},
		"snapshot": {
			"manual_attempts": snapshot.get("manual_save_attempt_count", -1),
			"manual_successes": snapshot.get("manual_save_success_count", -1),
			"manual_failures": snapshot.get("manual_save_failure_count", -1),
			"manual_route_attempts": snapshot.get("manual_save_route_attempt_count", -1),
			"resolution_attempts": snapshot.get("resolution_attempt_count", -1),
			"rules": snapshot.get("rules_end_turn_call_count", -1),
			"autosaves": snapshot.get("autosave_call_count", -1),
			"visible_message": snapshot.get("visible_message", ""),
			"visible_action_feedback": snapshot.get("visible_action_feedback", ""),
		},
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


func _clear_tracked_save_files() -> void:
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
	return {"exists": FileAccess.file_exists(path), "bytes": FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()}


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
	for path in _tracked_paths():
		_remove_path(String(path))
	for path in _original_file_states.keys():
		var state: Dictionary = _original_file_states.get(path, {})
		if bool(state.get("exists", false)):
			_write_bytes(String(path), state.get("bytes", PackedByteArray()))
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
