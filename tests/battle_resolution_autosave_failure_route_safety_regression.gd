extends Node

const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const BattleAutoResolveRulesScript = preload("res://scripts/core/BattleAutoResolveRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const BattleShellScene = preload("res://scenes/battle/BattleShell.tscn")

const REPORT_ID := "BATTLE_RESOLUTION_AUTOSAVE_FAILURE_ROUTE_SAFETY_REGRESSION"
const FAILURE_ENV := "HEROES_LIKE_SAVE_FAIL_PHASE"
const FAILURE_PHASES := ["precommit", "after_backup"]
const RESOLUTION_MODES := ["quick_resolve_victory", "confirmed_retreat"]
const SCENARIO_ID := "river-pass"
const ENCOUNTER_PLACEMENT_ID := "river_pass_hollow_mire"
const AUTOSAVE_PATH := "user://saves/autosave.json"
const ISSUE_LOG_PATH := "user://debug/heroes_runtime_issues.jsonl"
const LATEST_ISSUE_PATH := "user://debug/heroes_last_runtime_issue.json"
const ROUTER_FAILURE_MESSAGE := "Battle resolved, but autosave failed. Use Save Battle now to protect the result."
const SHELL_FAILURE_MESSAGE := "Battle resolved, but autosave failed. Press Save to retry the checkpoint."

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
		for mode_value in RESOLUTION_MODES:
			var mode := String(mode_value)
			var row: Dictionary = await _prove_failure_and_retry(phase, mode)
			if row.is_empty():
				return
			failure_matrix["%s:%s" % [phase, mode]] = row

	var ordinary_animation: Dictionary = await _prove_ordinary_success_and_exit_animation()
	if ordinary_animation.is_empty():
		return
	var terminal_outcome: Dictionary = await _prove_terminal_outcome_bypass()
	if terminal_outcome.is_empty():
		return
	var nonterminal: Dictionary = await _prove_nonterminal_control()
	if nonterminal.is_empty():
		return
	var preconditions: Dictionary = _prove_router_preconditions()
	if preconditions.is_empty():
		return

	_cleanup()
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"failure_matrix": failure_matrix,
		"ordinary_exit_animation": ordinary_animation,
		"terminal_outcome": terminal_outcome,
		"nonterminal_control": nonterminal,
		"router_preconditions": preconditions,
		"save_version": SessionState.SAVE_VERSION,
	})])
	get_tree().quit(0)


func _require_hooks() -> bool:
	var shell := BattleShellScene.instantiate()
	for method_name in [
		"validation_perform_action",
		"validation_request_withdrawal",
		"validation_confirm_withdrawal",
		"validation_request_quick_resolve_confirmation",
		"validation_confirm_quick_resolve_confirmation",
		"validation_quick_resolve_confirmation_snapshot",
		"validation_reset_battle_resolution_checkpoint_state",
		"validation_retry_battle_resolution_save",
		"validation_battle_resolution_checkpoint_snapshot",
		"validation_snapshot",
	]:
		if not shell.has_method(method_name):
			shell.free()
			return _fail_bool("BattleShell is missing checkpoint validation hook %s." % method_name)
	shell.free()
	for method_name in [
		"checkpoint_battle_resolution_for_overworld",
		"route_checkpointed_battle_resolution",
		"validation_set_battle_resolution_checkpoint_routing_suppressed",
		"validation_reset_battle_resolution_checkpoint_state",
		"validation_battle_resolution_checkpoint_snapshot",
	]:
		if not AppRouter.has_method(method_name):
			return _fail_bool("AppRouter is missing battle-resolution checkpoint hook %s." % method_name)
	for method_name in [
		"validation_summary_cache_snapshot",
		"validation_clear_summary_cache",
		"validation_transaction_artifact_paths",
	]:
		if not SaveService.has_method(method_name):
			return _fail_bool("SaveService is missing transaction hook %s." % method_name)
	return true


func _prove_failure_and_retry(phase: String, mode: String) -> Dictionary:
	_clear_save_files()
	var shell = await _create_shell(_active_battle_fixture(10 + FAILURE_PHASES.find(phase) * 4 + RESOLUTION_MODES.find(mode)))
	if shell == null:
		return {}
	var live: SessionStateStoreScript.SessionData = SessionState.ensure_active_session()
	var direct: SessionStateStoreScript.SessionData = _clone_session(live)
	var prior: SessionStateStoreScript.SessionData = _base_session(90 + FAILURE_PHASES.find(phase) * 4 + RESOLUTION_MODES.find(mode))
	var prior_save: Dictionary = SaveService.save_runtime_autosave_session(prior)
	if not bool(prior_save.get("ok", false)):
		await _discard_shell(shell)
		return _fail_dictionary("Could not seed prior autosave for %s/%s." % [phase, mode])
	SaveService.inspect_autosave()
	var autosave_before := _file_state(AUTOSAVE_PATH)
	var cache_before: Dictionary = SaveService.validation_summary_cache_snapshot()
	var issue_count_before := RuntimeIssueLog.issue_record_count()
	var direct_result := {}
	var expected_action_count := 0
	if mode == "quick_resolve_victory":
		var autoplay: Dictionary = BattleAutoResolveRulesScript.resolve_active_battle(direct)
		var terminal_value: Variant = autoplay.get("terminal_result", {})
		direct_result = terminal_value if terminal_value is Dictionary else {}
		if not bool(autoplay.get("ok", false)) or not bool(autoplay.get("completed", false)) or String(direct_result.get("state", "")) != "victory":
			await _discard_shell(shell)
			return _fail_dictionary("Quick Resolve direct control did not produce deterministic victory: %s" % JSON.stringify(_compact_result(autoplay)))
	else:
		direct_result = BattleRulesScript.perform_player_action(direct, "retreat")
		expected_action_count = 1
		if not bool(direct_result.get("ok", false)) or String(direct_result.get("state", "")) != "retreat":
			await _discard_shell(shell)
			return _fail_dictionary("Retreat direct control did not resolve deterministically: %s" % JSON.stringify(_compact_result(direct_result)))

	OS.set_environment(FAILURE_ENV, phase)
	var shell_result := {}
	if mode == "quick_resolve_victory":
		var requested: Dictionary = shell.validation_request_quick_resolve_confirmation()
		var confirmation_pending: Dictionary = shell.validation_quick_resolve_confirmation_snapshot()
		if not bool(requested.get("ok", false)) \
			or not bool(requested.get("pending", false)) \
			or not bool(confirmation_pending.get("pending", false)) \
			or not bool(confirmation_pending.get("dialog_visible", false)) \
			or int(confirmation_pending.get("request_count", 0)) != 1 \
			or int(confirmation_pending.get("confirm_count", 0)) != 0 \
			or int(confirmation_pending.get("perform_count", 0)) != 0:
			OS.unset_environment(FAILURE_ENV)
			await _discard_shell(shell)
			return _fail_dictionary("Quick Resolve confirmation could not be requested for %s: %s" % [phase, JSON.stringify({"result": requested, "snapshot": confirmation_pending})])
		var confirmed: Dictionary = shell.validation_confirm_quick_resolve_confirmation()
		if not bool(confirmed.get("performed", false)) \
			or int(shell.validation_quick_resolve_confirmation_snapshot().get("confirm_count", 0)) != 1:
			OS.unset_environment(FAILURE_ENV)
			await _discard_shell(shell)
			return _fail_dictionary("Quick Resolve confirmation did not execute exactly once for %s: %s" % [phase, JSON.stringify(confirmed)])
	else:
		var requested: Dictionary = shell.validation_request_withdrawal("retreat")
		if not bool(requested.get("ok", false)) or not bool(requested.get("pending", false)):
			OS.unset_environment(FAILURE_ENV)
			await _discard_shell(shell)
			return _fail_dictionary("Retreat confirmation could not be requested for %s: %s" % [phase, JSON.stringify(requested)])
		var confirmed: Dictionary = shell.validation_confirm_withdrawal()
		var result_value: Variant = confirmed.get("result", {})
		shell_result = result_value if result_value is Dictionary else {}
	OS.unset_environment(FAILURE_ENV)
	await _settle()

	var shell_snapshot: Dictionary = shell.validation_battle_resolution_checkpoint_snapshot()
	var router_snapshot: Dictionary = AppRouter.validation_battle_resolution_checkpoint_snapshot()
	if mode == "quick_resolve_victory":
		shell_result = shell_snapshot.get("pending_result", {}) if shell_snapshot.get("pending_result", {}) is Dictionary else {}
	var checkpoint_result: Dictionary = shell_snapshot.get("last_checkpoint_result", {}) if shell_snapshot.get("last_checkpoint_result", {}) is Dictionary else {}
	var issue_records: Array = RuntimeIssueLog.last_issue_records(1)
	var issue: Dictionary = issue_records[0] if not issue_records.is_empty() and issue_records[0] is Dictionary else {}
	if shell_result != direct_result:
		await _discard_shell(shell)
		return _fail_dictionary("Shell %s result diverged from direct control under %s: %s" % [mode, phase, JSON.stringify({"shell": _compact_result(shell_result), "direct": _compact_result(direct_result)})])
	var shell_gameplay := _gameplay_payload_without_shell_presentation(live)
	var direct_gameplay := _gameplay_payload_without_shell_presentation(direct)
	if _canonical_dictionary(shell_gameplay) != _canonical_dictionary(direct_gameplay):
		var difference := _first_difference(_canonical_dictionary(direct_gameplay), _canonical_dictionary(shell_gameplay))
		await _discard_shell(shell)
		return _fail_dictionary("Finalized live %s diverged from direct BattleRules control under %s: %s" % [mode, phase, JSON.stringify(difference)])
	if not bool(shell_snapshot.get("pending", false)) \
			or not bool(shell_snapshot.get("battle_resolved", false)) \
			or String(shell_snapshot.get("pending_state", "")) != String(direct_result.get("state", "")) \
			or bool(shell_snapshot.get("routed", true)) \
			or int(shell_snapshot.get("checkpoint_request_count", -1)) != 1 \
			or int(shell_snapshot.get("checkpoint_success_count", -1)) != 0 \
			or int(shell_snapshot.get("checkpoint_failure_count", -1)) != 1 \
			or not bool(shell_snapshot.get("combat_inputs_disabled", false)):
		await _discard_shell(shell)
		return _fail_dictionary("Shell did not retain one blocked finalized checkpoint for %s/%s: %s" % [phase, mode, JSON.stringify(_compact_checkpoint(shell_snapshot))])
	if bool(checkpoint_result.get("ok", true)) \
			or bool(checkpoint_result.get("saved", true)) \
			or bool(checkpoint_result.get("routed", true)) \
			or String(checkpoint_result.get("reason", "")) != "autosave_failed" \
			or String(checkpoint_result.get("retry_action", "")) != "manual_save" \
			or String(checkpoint_result.get("message", "")) != ROUTER_FAILURE_MESSAGE:
		await _discard_shell(shell)
		return _fail_dictionary("Checkpoint failure result was dishonest for %s/%s: %s" % [phase, mode, JSON.stringify(_compact_result(checkpoint_result))])
	if int(router_snapshot.get("request_count", -1)) != 1 \
			or int(router_snapshot.get("save_attempt_count", -1)) != 1 \
			or int(router_snapshot.get("save_failure_count", -1)) != 1 \
			or int(router_snapshot.get("route_request_count", -1)) != 0 \
			or int(router_snapshot.get("route_attempt_count", -1)) != 0 \
			or int(router_snapshot.get("runtime_issue_count", -1)) != 1:
		await _discard_shell(shell)
		return _fail_dictionary("Checkpoint failure did not save once and route zero times for %s/%s: %s" % [phase, mode, JSON.stringify(_compact_router(router_snapshot))])
	if _file_state(AUTOSAVE_PATH) != autosave_before \
			or SaveService.validation_summary_cache_snapshot() != cache_before \
			or not _transaction_artifacts_absent(AUTOSAVE_PATH):
		await _discard_shell(shell)
		return _fail_dictionary("Checkpoint failure changed prior autosave bytes/cache or left residue for %s/%s." % [phase, mode])
	if RuntimeIssueLog.issue_record_count() != issue_count_before + 1 \
			or String(issue.get("surface", "")) != "battle" \
			or String(issue.get("event", "")) != "battle_resolution_autosave_failed" \
			or String(shell_snapshot.get("visible_message", "")) != SHELL_FAILURE_MESSAGE \
			or String(shell_snapshot.get("save_button_text", "")) != "Save Battle" \
			or String(shell_snapshot.get("focus_owner", "")) != "Save":
		await _discard_shell(shell)
		return _fail_dictionary("Checkpoint failure did not expose one issue and usable Save Battle recovery for %s/%s: %s" % [phase, mode, JSON.stringify({"checkpoint": _compact_checkpoint(shell_snapshot), "issue": _compact_issue(issue)})])
	var validation_before_retry: Dictionary = shell.validation_snapshot()
	var action_count_before := _perform_count(validation_before_retry, "retreat")
	if action_count_before != expected_action_count:
		await _discard_shell(shell)
		return _fail_dictionary("Unexpected gameplay action count before retry for %s/%s: %d" % [phase, mode, action_count_before])
	var outcome_before_retry := _outcome_signature(live)
	var retry: Dictionary = shell.validation_retry_battle_resolution_save()
	await _wait_for_route_handoff()
	var after_shell: Dictionary = shell.validation_battle_resolution_checkpoint_snapshot()
	var after_router: Dictionary = AppRouter.validation_battle_resolution_checkpoint_snapshot()
	var restored = SaveService.restore_autosave_session()
	if not bool(retry.get("ok", false)) \
			or not bool(retry.get("saved", false)) \
			or not bool(retry.get("routed", false)) \
			or bool(retry.get("pending", true)) \
			or String(retry.get("reason", "")) != "saved":
		await _discard_shell(shell)
		return _fail_dictionary("Save Battle retry did not save and resume exactly once for %s/%s: %s" % [phase, mode, JSON.stringify(_compact_result(retry))])
	if int(after_router.get("request_count", -1)) != 2 \
			or int(after_router.get("save_attempt_count", -1)) != 2 \
			or int(after_router.get("save_failure_count", -1)) != 1 \
			or int(after_router.get("route_request_count", -1)) != 1 \
			or int(after_router.get("route_attempt_count", -1)) != 1 \
			or int(after_router.get("suppressed_route_count", -1)) != 1 \
			or int(after_shell.get("checkpoint_request_count", -1)) != 2 \
			or int(after_shell.get("checkpoint_success_count", -1)) != 1 \
			or int(after_shell.get("checkpoint_failure_count", -1)) != 1 \
			or int(after_shell.get("checkpoint_retry_count", -1)) != 1 \
			or int(after_shell.get("durable_route_count", -1)) != 1:
		await _discard_shell(shell)
		return _fail_dictionary("Save Battle retry counters were not failure+retry+route exactly once for %s/%s: %s" % [phase, mode, JSON.stringify({"shell": _compact_checkpoint(after_shell), "router": _compact_router(after_router)})])
	if _perform_count(shell.validation_snapshot(), "retreat") != action_count_before \
			or _outcome_signature(live) != outcome_before_retry:
		await _discard_shell(shell)
		return _fail_dictionary("Save Battle retry replayed gameplay or reward finalization for %s/%s." % [phase, mode])
	if restored == null or _canonical_dictionary(restored.to_dict()) != _canonical_dictionary(live.to_dict()) or not _transaction_artifacts_absent(AUTOSAVE_PATH):
		var restored_payload := _canonical_dictionary(restored.to_dict()) if restored != null else {}
		var live_payload := _canonical_dictionary(live.to_dict())
		await _discard_shell(shell)
		return _fail_dictionary("Save Battle retry did not reload the canonical finalized state for %s/%s: %s" % [phase, mode, JSON.stringify(_first_difference(live_payload, restored_payload))])

	await _discard_shell(shell)
	return {
		"state": String(direct_result.get("state", "")),
		"direct_result_match": true,
		"direct_gameplay_state_match": true,
		"prior_autosave_bytes_exact": true,
		"summary_cache_exact": true,
		"failure_save_attempts": 1,
		"failure_routes": 0,
		"retry_total_save_attempts": 2,
		"retry_route_attempts": 1,
		"gameplay_replays": 0,
		"canonical_reload_exact": true,
		"runtime_issue_event": "battle_resolution_autosave_failed",
	}


func _prove_ordinary_success_and_exit_animation() -> Dictionary:
	_clear_save_files()
	var shell = await _create_shell(_active_battle_fixture(30))
	if shell == null:
		return {}
	var live: SessionStateStoreScript.SessionData = SessionState.ensure_active_session()
	BattleRulesScript.set_battle_presentation_speed(live, BattleRulesScript.PRESENTATION_SPEED_INSTANT)
	var direct: SessionStateStoreScript.SessionData = _clone_session(live)
	var direct_result: Dictionary = BattleRulesScript.perform_player_action(direct, "retreat")
	var request: Dictionary = shell.validation_request_withdrawal("retreat")
	var confirmed: Dictionary = shell.validation_confirm_withdrawal()
	var result_value: Variant = confirmed.get("result", {})
	var shell_result: Dictionary = result_value if result_value is Dictionary else {}
	var immediate: Dictionary = shell.validation_battle_resolution_checkpoint_snapshot()
	if not bool(request.get("ok", false)) or shell_result != direct_result \
			or not bool(immediate.get("route_scheduled", false)) \
			or int(immediate.get("checkpoint_success_count", -1)) != 1:
		await _discard_shell(shell)
		return _fail_dictionary("Ordinary retreat did not checkpoint before its exit animation: %s" % JSON.stringify({"result": _compact_result(shell_result), "checkpoint": _compact_checkpoint(immediate)}))
	await _wait_for_route_handoff()
	var after: Dictionary = shell.validation_battle_resolution_checkpoint_snapshot()
	var router: Dictionary = AppRouter.validation_battle_resolution_checkpoint_snapshot()
	var restored = SaveService.restore_autosave_session()
	var restored_gameplay := _canonical_dictionary(_gameplay_payload_without_shell_presentation(restored)) if restored != null else {}
	var live_gameplay := _canonical_dictionary(_gameplay_payload_without_shell_presentation(live))
	if int(router.get("save_attempt_count", -1)) != 1 \
			or int(router.get("save_failure_count", -1)) != 0 \
			or int(router.get("route_attempt_count", -1)) != 1 \
			or int(after.get("durable_route_count", -1)) != 1 \
			or restored == null \
			or restored_gameplay != live_gameplay:
		await _discard_shell(shell)
		return _fail_dictionary("Ordinary retreat did not save then route once after animation: %s" % JSON.stringify({"shell": _compact_checkpoint(after), "router": _compact_router(router), "payload_difference": _first_difference(live_gameplay, restored_gameplay)}))
	await _discard_shell(shell)
	return {"state": "retreat", "checkpoint_before_animation": true, "save_attempts": 1, "route_attempts": 1, "reload_exact": true}


func _prove_terminal_outcome_bypass() -> Dictionary:
	_clear_save_files()
	AppRouter.validation_reset_battle_resolution_checkpoint_state()
	AppRouter.validation_set_battle_resolution_checkpoint_routing_suppressed(true)
	AppRouter.validation_reset_scenario_outcome_route_state()
	AppRouter.validation_set_scenario_outcome_routing_suppressed(true)
	var session: SessionStateStoreScript.SessionData = _active_battle_fixture(40, SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN)
	var stacks: Array = session.battle.get("stacks", [])
	for index in range(stacks.size()):
		var stack = stacks[index]
		if stack is Dictionary and String(stack.get("side", "")) == "player":
			stack["total_health"] = 0
			stacks[index] = stack
	session.battle["stacks"] = stacks
	session = SessionState.set_active_session(session)
	var shell := BattleShellScene.instantiate()
	add_child(shell)
	await _settle()
	var checkpoint: Dictionary = AppRouter.validation_battle_resolution_checkpoint_snapshot()
	var outcome: Dictionary = AppRouter.validation_scenario_outcome_route_snapshot()
	if session.scenario_status == "in_progress" \
			or not session.battle.is_empty() \
			or int(checkpoint.get("request_count", -1)) != 0 \
			or int(checkpoint.get("save_attempt_count", -1)) != 0 \
			or int(outcome.get("request_count", 0)) != 1 \
			or int(outcome.get("route_attempt_count", 0)) != 1:
		await _discard_shell(shell)
		return _fail_dictionary("Terminal primary defeat did not bypass the Overworld checkpoint for Outcome: %s" % JSON.stringify({"status": session.scenario_status, "battle_active": not session.battle.is_empty(), "checkpoint": _compact_router(checkpoint), "outcome": _compact_outcome_router(outcome)}))
	await _discard_shell(shell)
	return {"scenario_status": session.scenario_status, "checkpoint_save_attempts": 0, "outcome_route_attempts": 1}


func _prove_nonterminal_control() -> Dictionary:
	_clear_save_files()
	var shell = await _create_shell(_active_battle_fixture(50))
	if shell == null:
		return {}
	var live: SessionStateStoreScript.SessionData = SessionState.ensure_active_session()
	var before := _canonical_dictionary(live.to_dict())
	var autosave_before := _file_state(AUTOSAVE_PATH)
	var result: Dictionary = shell.validation_perform_action("defend")
	var checkpoint: Dictionary = shell.validation_battle_resolution_checkpoint_snapshot()
	if not bool(result.get("ok", false)) \
			or String(result.get("state", "")) != "continue" \
			or live.battle.is_empty() \
			or int(checkpoint.get("checkpoint_request_count", -1)) != 0 \
			or int(checkpoint.get("router_snapshot", {}).get("save_attempt_count", -1)) != 0 \
			or _file_state(AUTOSAVE_PATH) != autosave_before \
			or _canonical_dictionary(live.to_dict()) == before:
		await _discard_shell(shell)
		return _fail_dictionary("Nonterminal Defend did not remain an ordinary unsaved battle action: %s" % JSON.stringify({"result": _compact_result(result), "checkpoint": _compact_checkpoint(checkpoint)}))
	await _discard_shell(shell)
	return {"state": "continue", "battle_active": true, "checkpoint_attempts": 0, "autosave_unchanged": true}


func _prove_router_preconditions() -> Dictionary:
	AppRouter.validation_reset_battle_resolution_checkpoint_state()
	SessionState.active_session = null
	var missing: Dictionary = AppRouter.checkpoint_battle_resolution_for_overworld(false)
	var active: SessionStateStoreScript.SessionData = _active_battle_fixture(60)
	SessionState.set_active_session(active)
	var still_active: Dictionary = AppRouter.checkpoint_battle_resolution_for_overworld(false)
	if String(missing.get("reason", "")) != "missing_session" \
			or bool(missing.get("ok", true)) \
			or String(still_active.get("reason", "")) != "battle_still_active" \
			or bool(still_active.get("ok", true)):
		return _fail_dictionary("Router checkpoint preconditions did not fail closed: %s" % JSON.stringify({"missing": _compact_result(missing), "active": _compact_result(still_active)}))
	return {"missing_session": "missing_session", "active_battle": "battle_still_active"}


func _create_shell(session) -> Node:
	SessionState.set_active_session(session)
	AppRouter.validation_reset_battle_resolution_checkpoint_state()
	AppRouter.validation_set_battle_resolution_checkpoint_routing_suppressed(true)
	var shell := BattleShellScene.instantiate()
	add_child(shell)
	await _settle()
	if not is_instance_valid(shell) or not shell.has_method("validation_battle_resolution_checkpoint_snapshot"):
		_fail("BattleShell could not be instantiated for focused checkpoint validation.")
		return null
	shell.validation_reset_battle_resolution_checkpoint_state()
	AppRouter.validation_set_battle_resolution_checkpoint_routing_suppressed(true)
	BattleRulesScript.set_battle_presentation_speed(SessionState.ensure_active_session(), BattleRulesScript.PRESENTATION_SPEED_INSTANT)
	return shell


func _active_battle_fixture(seed_offset: int, launch_mode: String = SessionStateStoreScript.LAUNCH_MODE_SKIRMISH) -> SessionStateStoreScript.SessionData:
	var session = ScenarioFactory.create_session(SCENARIO_ID, "normal", launch_mode)
	session.session_id = "%s-battle-resolution-%d" % [session.session_id, seed_offset]
	var encounter := _encounter(session, ENCOUNTER_PLACEMENT_ID)
	if encounter.is_empty():
		_fail("Authored encounter %s is missing." % ENCOUNTER_PLACEMENT_ID)
		return null
	session.battle = BattleRulesScript.create_battle_payload(session, encounter)
	session.game_state = "battle"
	session.battle[BattleRulesScript.PRESENTATION_SPEED_KEY] = BattleRulesScript.PRESENTATION_SPEED_INSTANT
	session.battle["retreat_allowed"] = true
	session.battle["surrender_allowed"] = true
	var guard := 0
	while String(BattleRulesScript.get_active_stack(session.battle).get("side", "")) != "player" and guard < 16:
		BattleRulesScript.advance_turn(session.battle)
		guard += 1
	if String(BattleRulesScript.get_active_stack(session.battle).get("side", "")) != "player":
		_fail("Battle fixture could not reach a player turn.")
		return null
	return session


func _base_session(seed_offset: int) -> SessionStateStoreScript.SessionData:
	var session = ScenarioFactory.create_session(SCENARIO_ID, "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	session.session_id = "%s-prior-%d" % [session.session_id, seed_offset]
	session.game_state = "overworld"
	session.battle = {}
	return session


func _encounter(session, placement_id: String) -> Dictionary:
	for value in session.overworld.get("encounters", []):
		if value is Dictionary and String(value.get("placement_id", "")) == placement_id:
			return value
	return {}


func _clone_session(source) -> SessionStateStoreScript.SessionData:
	var clone := SessionStateStoreScript.new_session_data()
	clone.from_dict(source.to_dict())
	return clone


func _gameplay_payload_without_shell_presentation(session) -> Dictionary:
	var payload: Dictionary = session.to_dict()
	var flags: Dictionary = payload.get("flags", {}) if payload.get("flags", {}) is Dictionary else {}
	flags.erase("last_battle_action_recap")
	payload["flags"] = flags
	var overworld: Dictionary = payload.get("overworld", {}) if payload.get("overworld", {}) is Dictionary else {}
	overworld.erase("command_risk_forecast")
	payload["overworld"] = overworld
	return payload


func _outcome_signature(session) -> Dictionary:
	var payload := _gameplay_payload_without_shell_presentation(session)
	payload.erase("game_state")
	var flags: Dictionary = payload.get("flags", {}) if payload.get("flags", {}) is Dictionary else {}
	for key in SaveService.TRANSITION_AUTOSAVE_INTENT_FLAGS:
		flags.erase(String(key))
	payload["flags"] = flags
	return _canonical_dictionary(payload)


func _perform_count(snapshot: Dictionary, action_id: String) -> int:
	var counts: Dictionary = snapshot.get("validation_perform_action_counts", {}) if snapshot.get("validation_perform_action_counts", {}) is Dictionary else {}
	return int(counts.get(action_id, 0))


func _wait_for_route_handoff() -> void:
	await get_tree().create_timer(0.20).timeout
	await _settle()


func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame


func _discard_shell(shell: Node) -> void:
	if is_instance_valid(shell):
		shell.queue_free()
	await _settle()


func _tracked_paths() -> Array:
	return [
		AUTOSAVE_PATH,
		"%s.candidate" % AUTOSAVE_PATH,
		"%s.backup" % AUTOSAVE_PATH,
		ISSUE_LOG_PATH,
		LATEST_ISSUE_PATH,
	]


func _clear_save_files() -> void:
	for path in [AUTOSAVE_PATH, "%s.candidate" % AUTOSAVE_PATH, "%s.backup" % AUTOSAVE_PATH]:
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


func _compact_result(result: Dictionary) -> Dictionary:
	return {
		"ok": result.get("ok", null),
		"completed": result.get("completed", null),
		"saved": result.get("saved", null),
		"routed": result.get("routed", null),
		"pending": result.get("pending", null),
		"state": result.get("state", ""),
		"reason": result.get("reason", ""),
		"retry_action": result.get("retry_action", ""),
		"message": result.get("message", ""),
	}


func _compact_checkpoint(snapshot: Dictionary) -> Dictionary:
	return {
		"pending": snapshot.get("pending", null),
		"battle_resolved": snapshot.get("battle_resolved", null),
		"pending_state": snapshot.get("pending_state", ""),
		"route_scheduled": snapshot.get("route_scheduled", null),
		"routed": snapshot.get("routed", null),
		"request": snapshot.get("checkpoint_request_count", -1),
		"success": snapshot.get("checkpoint_success_count", -1),
		"failure": snapshot.get("checkpoint_failure_count", -1),
		"retry": snapshot.get("checkpoint_retry_count", -1),
		"durable_route": snapshot.get("durable_route_count", -1),
		"visible_message": snapshot.get("visible_message", ""),
		"save_button_text": snapshot.get("save_button_text", ""),
		"focus_owner": snapshot.get("focus_owner", ""),
		"combat_inputs_disabled": snapshot.get("combat_inputs_disabled", null),
	}


func _compact_router(snapshot: Dictionary) -> Dictionary:
	return {
		"request": snapshot.get("request_count", -1),
		"save": snapshot.get("save_attempt_count", -1),
		"failure": snapshot.get("save_failure_count", -1),
		"route_request": snapshot.get("route_request_count", -1),
		"route_attempt": snapshot.get("route_attempt_count", -1),
		"suppressed_route": snapshot.get("suppressed_route_count", -1),
		"issue": snapshot.get("runtime_issue_count", -1),
		"durable": snapshot.get("checkpoint_durable", null),
		"last_result": _compact_result(snapshot.get("last_result", {}) if snapshot.get("last_result", {}) is Dictionary else {}),
		"last_route": snapshot.get("last_route", {}),
	}


func _compact_issue(issue: Dictionary) -> Dictionary:
	return {"surface": issue.get("surface", ""), "event": issue.get("event", ""), "message": issue.get("message", "")}


func _compact_outcome_router(snapshot: Dictionary) -> Dictionary:
	return {
		"request": snapshot.get("request_count", -1),
		"save": snapshot.get("save_attempt_count", -1),
		"failure": snapshot.get("save_failure_count", -1),
		"route_attempt": snapshot.get("route_attempt_count", -1),
		"suppressed_route": snapshot.get("suppressed_route_count", -1),
		"last_reason": snapshot.get("last_result", {}).get("reason", "") if snapshot.get("last_result", {}) is Dictionary else "",
		"last_route": snapshot.get("last_route", {}),
	}


func _cleanup() -> void:
	OS.unset_environment(FAILURE_ENV)
	AppRouter.validation_set_battle_resolution_checkpoint_routing_suppressed(false)
	AppRouter.validation_reset_battle_resolution_checkpoint_state()
	AppRouter.validation_set_scenario_outcome_routing_suppressed(false)
	AppRouter.validation_reset_scenario_outcome_route_state()
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
