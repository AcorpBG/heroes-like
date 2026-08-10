extends Node

const REPORT_ID := "APPLICATION_SCENARIO_OUTCOME_AUTOSAVE_FAILURE_RECOVERY_REGRESSION"
const FAILURE_ENV := "HEROES_LIKE_SAVE_FAIL_PHASE"
const FAILURE_PHASES := ["precommit", "after_backup"]
const CAMPAIGN_ID := "campaign_reedfall"
const SCENARIO_ID := "river-pass"
const AUTOSAVE_PATH := "user://saves/autosave.json"
const PROGRESSION_PATH := "user://saves/campaign_progression.json"
const MANUAL_PATH := "user://saves/manual_1.json"
const OUTCOME_SCENE := "res://scenes/results/ScenarioOutcomeShell.tscn"
const EXPECTED_ROUTER_MESSAGE := "Outcome is ready, but autosave failed. Use Save now to protect it."
const EXPECTED_SHELL_MESSAGE := "Outcome reached, but autosave failed. Use Save Outcome now."
const ISSUE_EVENT := "scenario_outcome_autosave_failed"
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

var _original_session = null
var _original_profile: Dictionary = {}
var _original_failure_env := ""
var _original_files: Dictionary = {}


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_original_session = SessionState.active_session
	_original_profile = CampaignProgression.profile.duplicate(true)
	_original_failure_env = OS.get_environment(FAILURE_ENV)
	_original_files = _capture_file_states(_tracked_paths())
	_detach_runner_for_scene_changes()
	if not _require_api():
		return
	var failure_rows := []
	var cases := [
		{"phase": "precommit", "launch_mode": "campaign", "status": "victory", "source": "overworld"},
		{"phase": "precommit", "launch_mode": "skirmish", "status": "defeat", "source": "town"},
		{"phase": "after_backup", "launch_mode": "campaign", "status": "defeat", "source": "battle"},
		{"phase": "after_backup", "launch_mode": "skirmish", "status": "victory", "source": "resume"},
	]
	for index in range(cases.size()):
		var row := await _validate_failure_and_retry(cases[index], index)
		if row.is_empty():
			return
		failure_rows.append(row)
	var stale := await _validate_stale_session_identity()
	if stale.is_empty():
		return
	var clearing := await _validate_return_and_safe_close_clear_recovery()
	if clearing.is_empty():
		return
	var controls := await _validate_ordinary_route_controls()
	if controls.is_empty():
		return
	_cleanup()
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"failure_rows": failure_rows,
		"stale_identity": stale,
		"recovery_clearing": clearing,
		"controls": controls,
		"save_version": SessionState.SAVE_VERSION,
	})])
	get_tree().quit(0)


func _validate_failure_and_retry(spec: Dictionary, index: int) -> Dictionary:
	_reset_case_state()
	var phase := String(spec.get("phase", ""))
	var launch_mode := String(spec.get("launch_mode", ""))
	var status := String(spec.get("status", ""))
	var source := String(spec.get("source", ""))
	var prepared := _prepare_terminal_case(launch_mode, status, source, index)
	var session = prepared.get("session", null)
	if session == null:
		return _fail_dictionary("Could not prepare %s/%s %s case." % [launch_mode, status, phase])
	var profile_before_route: Dictionary = CampaignProgression.profile.duplicate(true)
	var progression_before_route := _file_state(PROGRESSION_PATH)
	var autosave_before := _file_state(AUTOSAVE_PATH)
	var cache_before: Dictionary = SaveService.validation_summary_cache_snapshot()
	var expected_live: Dictionary = session.to_dict()
	expected_live["game_state"] = "outcome"
	var attempts_before := _campaign_attempts(profile_before_route) if launch_mode == "campaign" else -1
	var issue_before := _issue_count(ISSUE_EVENT)

	OS.set_environment(FAILURE_ENV, phase)
	var route_result: Dictionary = AppRouter.go_to_scenario_outcome()
	if _canonical(SessionState.ensure_active_session().to_dict()) != _canonical(expected_live):
		return _fail_dictionary("%s route changed the live terminal session beyond outcome staging." % phase, {
			"difference": _first_difference(expected_live, SessionState.ensure_active_session().to_dict()),
		})
	if _file_state(AUTOSAVE_PATH) != autosave_before or SaveService.validation_summary_cache_snapshot() != cache_before:
		return _fail_dictionary("%s failed transaction changed prior autosave bytes or summary cache." % phase, {
			"bytes_equal": _file_state(AUTOSAVE_PATH) == autosave_before,
			"cache_equal": SaveService.validation_summary_cache_snapshot() == cache_before,
		})
	var outcome_model_control := SessionStateStoreScript.SessionData.new()
	outcome_model_control.from_dict(expected_live)
	ScenarioRules.build_outcome_model(outcome_model_control)
	var expected_rendered_live: Dictionary = outcome_model_control.to_dict()
	var shell = await _wait_for_scene(OUTCOME_SCENE)
	if shell == null:
		return _fail_dictionary("%s/%s %s did not route to OutcomeShell after save failure." % [launch_mode, status, phase])
	await _settle()
	var router: Dictionary = AppRouter.validation_scenario_outcome_route_snapshot()
	var shell_snapshot: Dictionary = shell.validation_outcome_recovery_snapshot()
	if not _assert_entry_failure_contract(route_result, router, shell_snapshot, phase):
		return {}
	if _canonical(SessionState.ensure_active_session().to_dict()) != _canonical(expected_rendered_live):
		return _fail_dictionary("%s OutcomeShell changed live state beyond the method-matched outcome model." % phase, {
			"difference": _first_difference(expected_rendered_live, SessionState.ensure_active_session().to_dict()),
		})
	if CampaignProgression.profile != profile_before_route or _file_state(PROGRESSION_PATH) != progression_before_route:
		return _fail_dictionary("%s failure changed the already-committed campaign/profile authority." % phase)
	if _file_state(AUTOSAVE_PATH) != autosave_before:
		return _fail_dictionary("%s recovery shell changed prior autosave bytes before retry." % phase)
	if not _artifacts_absent(AUTOSAVE_PATH):
		return _fail_dictionary("%s failure left autosave transaction artifacts." % phase)
	if _issue_count(ISSUE_EVENT) != issue_before + 1:
		return _fail_dictionary("%s entry failure did not emit exactly one sanitized runtime issue." % phase)
	if String(shell_snapshot.get("message", "")) != EXPECTED_SHELL_MESSAGE \
			or String(shell_snapshot.get("focus_owner", "")) != "Save":
		return _fail_dictionary("Outcome recovery warning/focus was not actionable.", _compact_shell(shell_snapshot))
	var blocked_ids: Array = shell_snapshot.get("blocked_action_ids", []) if shell_snapshot.get("blocked_action_ids", []) is Array else []
	if blocked_ids.is_empty():
		return _fail_dictionary("Pending recovery exposed no blocked follow-up action.", _compact_shell(shell_snapshot))
	var blocked_action_id := String(blocked_ids[0])
	if not _live_action_button_disabled(shell, blocked_action_id):
		return _fail_dictionary("Pending recovery did not disable its live follow-up button: %s." % blocked_action_id)
	var direct_block: Dictionary = shell.validation_perform_action(blocked_action_id)
	var direct_action_result: Dictionary = direct_block.get("action_result", {}) if direct_block.get("action_result", {}) is Dictionary else direct_block
	if bool(direct_block.get("ok", false)) or String(direct_action_result.get("reason", "")) != "outcome_autosave_recovery_pending":
		return _fail_dictionary("Direct follow-up bypassed recovery guard.", _compact(direct_block))

	var failed_retry: Dictionary = shell.validation_request_save_outcome()
	var after_failed_retry: Dictionary = shell.validation_outcome_recovery_snapshot()
	if bool(failed_retry.get("ok", false)) or not bool(failed_retry.get("recovery_pending", false)) \
			or int(after_failed_retry.get("retry_failure_count", 0)) != 1 \
			or _file_state(AUTOSAVE_PATH) != autosave_before or not _artifacts_absent(AUTOSAVE_PATH):
		return _fail_dictionary("Outcome Save failure did not retain an exact retryable recovery.", {
			"result": _compact(failed_retry),
			"snapshot": _compact_shell(after_failed_retry),
			"bytes_equal": _file_state(AUTOSAVE_PATH) == autosave_before,
		})
	if _issue_count(ISSUE_EVENT) != issue_before + 1:
		return _fail_dictionary("Retry failure duplicated the entry runtime issue.")

	OS.unset_environment(FAILURE_ENV)
	var successful_retry: Dictionary = shell.validation_request_save_outcome()
	await _settle()
	var after_success: Dictionary = shell.validation_outcome_recovery_snapshot()
	var restored = SaveService.restore_autosave_session()
	if not bool(successful_retry.get("ok", false)) or bool(successful_retry.get("recovery_pending", true)) \
			or bool(after_success.get("pending", true)) or int(after_success.get("retry_success_count", 0)) != 1:
		return _fail_dictionary("Cleared hook did not complete exactly one outcome recovery.", {
			"result": _compact(successful_retry),
			"snapshot": _compact_shell(after_success),
		})
	if restored == null or _canonical(restored.to_dict()) != _canonical(expected_rendered_live) \
			or SaveService.resume_target_for_session(restored) != "outcome":
		return _fail_dictionary("Recovered autosave did not reload the canonical terminal outcome.", {
			"restored": restored != null,
			"resume_target": SaveService.resume_target_for_session(restored) if restored != null else "missing",
			"difference": _first_difference(expected_rendered_live, restored.to_dict()) if restored != null else {},
		})
	if CampaignProgression.profile != profile_before_route or _file_state(PROGRESSION_PATH) != progression_before_route:
		return _fail_dictionary("Outcome retry replayed or changed campaign completion.")
	if launch_mode == "campaign" and _campaign_attempts(CampaignProgression.profile) != attempts_before:
		return _fail_dictionary("Outcome retry incremented the campaign attempt count.")
	var final_router: Dictionary = AppRouter.validation_scenario_outcome_route_snapshot()
	if int(final_router.get("route_attempt_count", 0)) != 1 \
			or int(final_router.get("retry_attempt_count", 0)) != 2 \
			or int(final_router.get("retry_failure_count", 0)) != 1 \
			or int(final_router.get("retry_success_count", 0)) != 1 \
			or int(final_router.get("runtime_issue_count", 0)) != 1:
		return _fail_dictionary("Outcome retry counters or no-second-route contract drifted.", _compact_router(final_router))
	return {
		"phase": phase,
		"launch_mode": launch_mode,
		"status": status,
		"source": source,
		"issue_count": 1,
		"route_count": 1,
		"retry_attempts": 2,
		"resume_target": "outcome",
		"profile_unchanged": true,
	}


func _validate_stale_session_identity() -> Dictionary:
	_reset_case_state()
	AppRouter.validation_set_scenario_outcome_routing_suppressed(true)
	var prepared := _prepare_terminal_case("skirmish", "victory", "stale_source", 20)
	var source_session = prepared.get("session", null)
	if source_session == null:
		return _fail_dictionary("Could not prepare stale recovery source.")
	OS.set_environment(FAILURE_ENV, "precommit")
	var failed: Dictionary = AppRouter.go_to_scenario_outcome()
	OS.unset_environment(FAILURE_ENV)
	if String(failed.get("reason", "")) != "autosave_failed" \
			or not bool(AppRouter.scenario_outcome_recovery_snapshot().get("pending", false)):
		return _fail_dictionary("Could not establish stale recovery control.", _compact(failed))
	var counts_before: Dictionary = AppRouter.validation_scenario_outcome_route_snapshot()
	var unrelated = _new_session("skirmish", 21)
	unrelated.scenario_status = "defeat"
	unrelated.scenario_summary = "Unrelated terminal result"
	unrelated.game_state = "outcome"
	SessionState.active_session = unrelated
	var unrelated_before := _canonical(unrelated.to_dict())
	var stale_retry: Dictionary = AppRouter.retry_scenario_outcome_autosave()
	var after: Dictionary = AppRouter.validation_scenario_outcome_route_snapshot()
	AppRouter.validation_set_scenario_outcome_routing_suppressed(false)
	if String(stale_retry.get("reason", "")) != "stale_session" or bool(after.get("pending", true)) \
			or int(after.get("save_attempt_count", 0)) != int(counts_before.get("save_attempt_count", 0)) \
			or int(after.get("route_attempt_count", 0)) != int(counts_before.get("route_attempt_count", 0)) \
			or _canonical(unrelated.to_dict()) != unrelated_before:
		return _fail_dictionary("Stale recovery mutated or saved the unrelated active session.", {
			"result": _compact(stale_retry),
			"before": _compact_router(counts_before),
			"after": _compact_router(after),
			"session_equal": _canonical(unrelated.to_dict()) == unrelated_before,
		})
	return {"reason": "stale_session", "saved": false, "routed": false, "unrelated_unchanged": true}


func _validate_return_and_safe_close_clear_recovery() -> Dictionary:
	var rows := {}
	for recovery_path in ["return_to_menu", "safe_close"]:
		_reset_case_state()
		AppRouter.validation_set_scenario_outcome_routing_suppressed(recovery_path != "return_to_menu")
		var prepared := _prepare_terminal_case("skirmish", "defeat", recovery_path, 30 if recovery_path == "return_to_menu" else 31)
		if prepared.get("session", null) == null:
			return _fail_dictionary("Could not prepare %s recovery clearing control." % recovery_path)
		OS.set_environment(FAILURE_ENV, "after_backup")
		var failed: Dictionary = AppRouter.go_to_scenario_outcome()
		if String(failed.get("reason", "")) != "autosave_failed":
			return _fail_dictionary("Could not establish %s pending recovery." % recovery_path, _compact(failed))
		var result := {}
		if recovery_path == "return_to_menu":
			var shell = await _wait_for_scene(OUTCOME_SCENE)
			if shell == null:
				return _fail_dictionary("Return control did not reach OutcomeShell recovery.")
			AppRouter.validation_reset_active_play_return_state()
			AppRouter.validation_set_active_play_return_routing_suppressed(true)
			var failed_return: Dictionary = shell.validation_perform_action("return_to_menu")
			await _settle()
			var failed_action: Dictionary = failed_return.get("action_result", {}) if failed_return.get("action_result", {}) is Dictionary else {}
			var failed_shell: Dictionary = shell.validation_outcome_recovery_snapshot()
			var return_snapshot: Dictionary = shell.validation_snapshot()
			if bool(failed_return.get("ok", false)) or bool(failed_action.get("routed", true)) \
					or String(failed_action.get("reason", "")) != "autosave_failed" \
					or String(failed_return.get("route", "")) != "stay" \
					or not bool(failed_shell.get("pending", false)) \
					or String(failed_shell.get("message", "")) != EXPECTED_SHELL_MESSAGE \
					or String(return_snapshot.get("return_to_menu_focus_owner", "")) != "Menu":
				return _fail_dictionary("Live Outcome Return did not fail honestly with warning and Menu focus.", {
					"result": _compact(failed_return),
					"action_result": _compact(failed_action),
					"shell": _compact_shell(failed_shell),
					"focus": return_snapshot.get("return_to_menu_focus_owner", ""),
				})
			OS.unset_environment(FAILURE_ENV)
			result = shell.validation_perform_action("return_to_menu")
			AppRouter.validation_set_active_play_return_routing_suppressed(false)
		else:
			OS.unset_environment(FAILURE_ENV)
			AppRouter.validation_set_quit_suppressed(true)
			AppRouter.validation_reset_safe_quit_state()
			result = AppRouter.request_safe_quit("outcome_recovery_control")
			AppRouter.validation_set_quit_suppressed(false)
		var after: Dictionary = AppRouter.scenario_outcome_recovery_snapshot()
		AppRouter.validation_set_scenario_outcome_routing_suppressed(false)
		if not bool(result.get("ok", false)) or bool(after.get("pending", true)):
			return _fail_dictionary("Verified %s save did not clear pending outcome recovery." % recovery_path, {
				"result": _compact(result),
				"recovery": _compact_router(after),
			})
		rows[recovery_path] = true
	return rows


func _validate_ordinary_route_controls() -> Dictionary:
	var rows := {}
	_reset_case_state()
	AppRouter.validation_set_scenario_outcome_routing_suppressed(true)
	SessionState.active_session = null
	var missing: Dictionary = AppRouter.go_to_scenario_outcome()
	if String(missing.get("reason", "")) != "missing_session" or bool(missing.get("saved", true)):
		return _fail_dictionary("Missing-session outcome route did not fail closed.", _compact(missing))
	rows["missing_session"] = true

	AppRouter.validation_reset_scenario_outcome_route_state()
	var in_progress = _new_session("skirmish", 40)
	SessionState.active_session = in_progress
	var in_progress_before := _canonical(in_progress.to_dict())
	var active: Dictionary = AppRouter.go_to_scenario_outcome()
	var active_snapshot: Dictionary = AppRouter.validation_scenario_outcome_route_snapshot()
	if String(active.get("reason", "")) != "scenario_in_progress" \
			or int(active_snapshot.get("save_attempt_count", -1)) != 0 \
			or _canonical(in_progress.to_dict()) != in_progress_before:
		return _fail_dictionary("In-progress outcome request saved or mutated gameplay.", {
			"result": _compact(active),
			"snapshot": _compact_router(active_snapshot),
		})
	rows["in_progress"] = true

	AppRouter.validation_reset_scenario_outcome_route_state()
	var terminal = _new_session("skirmish", 41)
	terminal.scenario_status = "victory"
	terminal.scenario_summary = "Ordinary terminal control"
	SessionState.active_session = terminal
	var ordinary: Dictionary = AppRouter.go_to_scenario_outcome()
	var restored = SaveService.restore_autosave_session()
	if not bool(ordinary.get("ok", false)) or String(ordinary.get("reason", "")) != "saved" \
			or restored == null or restored.game_state != "outcome" or restored.scenario_status != "victory":
		return _fail_dictionary("Ordinary outcome entry did not save and route normally.", _compact(ordinary))
	rows["ordinary_success"] = true

	AppRouter.validation_reset_scenario_outcome_route_state()
	SessionState.active_session = restored
	var durable: Dictionary = AppRouter.go_to_scenario_outcome(true)
	var durable_snapshot: Dictionary = AppRouter.validation_scenario_outcome_route_snapshot()
	AppRouter.validation_set_scenario_outcome_routing_suppressed(false)
	if not bool(durable.get("ok", false)) or String(durable.get("reason", "")) != "already_saved" \
			or int(durable_snapshot.get("save_attempt_count", -1)) != 0 \
			or int(durable_snapshot.get("skipped_durable_route_count", 0)) != 1:
		return _fail_dictionary("Durable outcome resume performed a redundant save.", {
			"result": _compact(durable),
			"snapshot": _compact_router(durable_snapshot),
		})
	rows["durable_resume"] = true
	return rows


func _prepare_terminal_case(launch_mode: String, status: String, source: String, index: int) -> Dictionary:
	var profile: Dictionary = CampaignRules.build_profile()
	CampaignProgression.profile = profile.duplicate(true)
	if SaveService.save_progression(profile) == "":
		return {}
	var session = _new_session(launch_mode, index)
	session.game_state = source if source in ["overworld", "town", "battle"] else "overworld"
	SessionState.active_session = session
	var seeded: Dictionary = SaveService.save_runtime_autosave_session(session)
	if not bool(seeded.get("ok", false)):
		return {}
	session.scenario_status = status
	session.scenario_summary = "%s %s outcome %d" % [launch_mode, status, index]
	session.flags["scenario_result"] = status
	var completion_result := {"ok": true, "reason": "skirmish_control"}
	if launch_mode == "campaign":
		session.flags["campaign"] = status
		completion_result = CampaignProgression.record_session_completion(session)
		if not bool(completion_result.get("ok", false)):
			return {}
	return {"session": session, "completion_result": completion_result}


func _new_session(launch_mode: String, index: int):
	var session
	if launch_mode == "campaign":
		session = CampaignRules.build_session(CampaignProgression.profile, SCENARIO_ID, "normal", CAMPAIGN_ID)
	else:
		session = ScenarioFactory.create_session(SCENARIO_ID, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	session.session_id = "outcome_recovery_%s_%d" % [launch_mode, index]
	session.launch_mode = SessionState.LAUNCH_MODE_CAMPAIGN if launch_mode == "campaign" else SessionState.LAUNCH_MODE_SKIRMISH
	session.day = 5 + index
	session.scenario_status = "in_progress"
	session.scenario_summary = ""
	session.battle = {}
	return session


func _assert_entry_failure_contract(result: Dictionary, router: Dictionary, shell: Dictionary, phase: String) -> bool:
	if bool(result.get("ok", true)) or bool(result.get("saved", true)) or not bool(result.get("routed", false)) \
			or String(result.get("reason", "")) != "autosave_failed" \
			or String(result.get("retry_action", "")) != "retry_outcome_autosave" \
			or String(result.get("message", "")) != EXPECTED_ROUTER_MESSAGE \
			or not bool(result.get("outcome_pending", false)) or not bool(result.get("recovery_pending", false)):
		return _fail_bool("%s entry failure result contract drifted." % phase, _compact(result))
	if not bool(router.get("pending", false)) or int(router.get("request_count", 0)) != 1 \
			or int(router.get("save_attempt_count", 0)) != 1 or int(router.get("save_failure_count", 0)) != 1 \
			or int(router.get("route_attempt_count", 0)) != 1 or int(router.get("runtime_issue_count", 0)) != 1 \
			or String((router.get("last_route", {}) as Dictionary).get("target_scene", "")) != OUTCOME_SCENE \
			or String((router.get("last_runtime_issue", {}) as Dictionary).get("event", "")) != ISSUE_EVENT:
		return _fail_bool("%s router recovery counters/identity drifted." % phase, _compact_router(router))
	if not bool(shell.get("pending", false)) or String(shell.get("entry_result", {}).get("reason", "")) != "autosave_failed":
		return _fail_bool("%s OutcomeShell did not adopt the router recovery entry." % phase, _compact_shell(shell))
	return true


func _live_action_button_disabled(shell: Node, action_id: String) -> bool:
	var snapshot: Dictionary = shell.validation_snapshot()
	var actions: Array = snapshot.get("actions", []) if snapshot.get("actions", []) is Array else []
	var action_index := -1
	for index in range(actions.size()):
		if actions[index] is Dictionary and String(actions[index].get("id", "")) == action_id:
			action_index = index
			break
	var container: Node = shell.get_node_or_null("%Actions")
	if action_index < 0 or container == null or action_index >= container.get_child_count():
		return false
	var control = container.get_child(action_index)
	return control is BaseButton and control.disabled


func _campaign_attempts(profile: Dictionary) -> int:
	return int(CampaignRules.get_scenario_record(profile, CAMPAIGN_ID, SCENARIO_ID).get("attempts", 0))


func _reset_case_state() -> void:
	OS.unset_environment(FAILURE_ENV)
	AppRouter.validation_set_scenario_outcome_routing_suppressed(false)
	AppRouter.validation_reset_scenario_outcome_route_state()
	AppRouter.validation_set_active_play_return_routing_suppressed(false)
	AppRouter.validation_reset_active_play_return_state()
	AppRouter.validation_set_quit_suppressed(true)
	AppRouter.validation_reset_safe_quit_state()
	SaveService.validation_clear_summary_cache()
	_remove_file(RuntimeIssueLog.ISSUE_LOG_PATH)
	_remove_file(RuntimeIssueLog.LATEST_ISSUE_PATH)
	for path in [AUTOSAVE_PATH, PROGRESSION_PATH, MANUAL_PATH]:
		_remove_file(path)
		var artifacts: Dictionary = SaveService.validation_transaction_artifact_paths(path)
		_remove_file(String(artifacts.get("candidate", "")))
		_remove_file(String(artifacts.get("backup", "")))


func _require_api() -> bool:
	for method_name in [
		"go_to_scenario_outcome",
		"retry_scenario_outcome_autosave",
		"scenario_outcome_recovery_snapshot",
		"validation_set_scenario_outcome_routing_suppressed",
		"validation_reset_scenario_outcome_route_state",
		"validation_scenario_outcome_route_snapshot",
	]:
		if not AppRouter.has_method(method_name):
			return _fail_bool("AppRouter is missing outcome recovery API %s." % method_name)
	return true


func _wait_for_scene(path: String):
	for _frame in range(180):
		await get_tree().process_frame
		var scene = get_tree().current_scene
		if scene != null and String(scene.scene_file_path) == path:
			return scene
	return null


func _detach_runner_for_scene_changes() -> void:
	var tree := get_tree()
	if tree.current_scene != self:
		return
	var parent := get_parent()
	if parent != null:
		parent.remove_child(self)
	tree.root.add_child(self)
	var anchor := Node.new()
	anchor.name = "OutcomeRecoveryRegressionAnchor"
	tree.root.add_child(anchor)
	tree.current_scene = anchor


func _issue_count(event_id: String) -> int:
	var count := 0
	for record in RuntimeIssueLog.last_issue_records(64):
		if record is Dictionary and String(record.get("event", "")) == event_id:
			count += 1
	return count


func _artifacts_absent(path: String) -> bool:
	var artifacts: Dictionary = SaveService.validation_transaction_artifact_paths(path)
	return not FileAccess.file_exists(String(artifacts.get("candidate", ""))) \
		and not FileAccess.file_exists(String(artifacts.get("backup", "")))


func _compact_router(snapshot: Dictionary) -> Dictionary:
	var compact := {}
	for key in ["pending", "message", "identity", "request_count", "save_attempt_count", "save_failure_count", "retry_attempt_count", "retry_success_count", "retry_failure_count", "route_attempt_count", "suppressed_route_count", "skipped_durable_route_count", "runtime_issue_count", "last_route"]:
		if snapshot.has(key):
			compact[key] = snapshot[key]
	return compact


func _compact_shell(snapshot: Dictionary) -> Dictionary:
	var compact := {}
	for key in ["pending", "message", "focus_owner", "request_count", "retry_attempt_count", "retry_failure_count", "retry_success_count", "blocked_action_count", "blocked_action_ids", "entry_result", "last_retry_result"]:
		if snapshot.has(key):
			compact[key] = snapshot[key]
	return compact


func _compact(value: Dictionary) -> Dictionary:
	var compact := {}
	for key in ["ok", "saved", "routed", "reason", "retry_action", "outcome_pending", "recovery_pending", "message", "quit_requested"]:
		if value.has(key):
			compact[key] = value[key]
	return compact


func _first_difference(expected: Variant, actual: Variant, path: String = "root") -> Dictionary:
	if typeof(expected) != typeof(actual):
		return {"path": path, "expected_type": typeof(expected), "actual_type": typeof(actual)}
	if expected is Dictionary:
		var keys: Array = expected.keys()
		for key in actual.keys():
			if key not in keys:
				keys.append(key)
		keys.sort_custom(func(a, b): return String(a) < String(b))
		for key in keys:
			if not expected.has(key) or not actual.has(key):
				return {"path": "%s.%s" % [path, key], "expected_present": expected.has(key), "actual_present": actual.has(key)}
			var nested := _first_difference(expected[key], actual[key], "%s.%s" % [path, key])
			if not nested.is_empty():
				return nested
		return {}
	if expected is Array:
		if expected.size() != actual.size():
			return {"path": path, "expected_size": expected.size(), "actual_size": actual.size()}
		for index in range(expected.size()):
			var nested := _first_difference(expected[index], actual[index], "%s[%d]" % [path, index])
			if not nested.is_empty():
				return nested
		return {}
	if expected != actual:
		return {"path": path, "expected": expected, "actual": actual}
	return {}


func _canonical(value: Variant) -> String:
	return JSON.stringify(value)


func _tracked_paths() -> Array:
	var paths := [
		AUTOSAVE_PATH,
		PROGRESSION_PATH,
		MANUAL_PATH,
		RuntimeIssueLog.ISSUE_LOG_PATH,
		RuntimeIssueLog.LATEST_ISSUE_PATH,
	]
	for base_path in [AUTOSAVE_PATH, PROGRESSION_PATH, MANUAL_PATH]:
		var artifacts: Dictionary = SaveService.validation_transaction_artifact_paths(base_path)
		paths.append(String(artifacts.get("candidate", "")))
		paths.append(String(artifacts.get("backup", "")))
	return paths


func _file_state(path: String) -> Dictionary:
	return {
		"exists": FileAccess.file_exists(path),
		"bytes": FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray(),
	}


func _capture_file_states(paths: Array) -> Dictionary:
	var states := {}
	for path_value in paths:
		var path := String(path_value)
		if path != "":
			states[path] = _file_state(path)
	return states


func _restore_file_states(states: Dictionary) -> void:
	for path_value in states.keys():
		var path := String(path_value)
		var state: Dictionary = states[path]
		if not bool(state.get("exists", false)):
			_remove_file(path)
			continue
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir())
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_buffer(state.get("bytes", PackedByteArray()))
			file.close()


func _remove_file(path: String) -> void:
	if path != "" and FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _cleanup() -> void:
	OS.set_environment(FAILURE_ENV, _original_failure_env) if _original_failure_env != "" else OS.unset_environment(FAILURE_ENV)
	AppRouter.validation_set_scenario_outcome_routing_suppressed(false)
	AppRouter.validation_set_active_play_return_routing_suppressed(false)
	AppRouter.validation_set_quit_suppressed(true)
	_restore_file_states(_original_files)
	CampaignProgression.profile = _original_profile.duplicate(true)
	SessionState.active_session = _original_session


func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame


func _fail_dictionary(message: String, payload: Variant = {}) -> Dictionary:
	_fail_bool(message, payload)
	return {}


func _fail_bool(message: String, payload: Variant = {}) -> bool:
	_cleanup()
	push_error("%s failed: %s %s" % [REPORT_ID, message, JSON.stringify(payload)])
	get_tree().quit(1)
	return false
