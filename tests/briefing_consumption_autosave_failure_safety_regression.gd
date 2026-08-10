extends Node

const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const OverworldShellScene = preload("res://scenes/overworld/OverworldShell.tscn")
const BattleShellScene = preload("res://scenes/battle/BattleShell.tscn")

const REPORT_ID := "BRIEFING_CONSUMPTION_AUTOSAVE_FAILURE_SAFETY_REGRESSION"
const FAILURE_ENV := "HEROES_LIKE_SAVE_FAIL_PHASE"
const FAILURE_PHASES := ["precommit", "after_backup"]
const SURFACES := ["overworld", "battle"]
const FAILURE_MESSAGE := "Briefing shown, but autosave failed. Press Save to protect this checkpoint."
const END_TURN_FAILURE_MESSAGE := "Turn completed, but autosave failed. Use Save now to protect the new day."
const AUTOSAVE_PATH := "user://saves/autosave.json"
const MANUAL_PATH := "user://saves/slot1.json"
const ISSUE_LOG_PATH := "user://debug/heroes_runtime_issues.jsonl"
const LATEST_ISSUE_PATH := "user://debug/heroes_last_runtime_issue.json"
const SCENARIO_ID := "river-pass"
const ENCOUNTER_ID := "river_pass_hollow_mire"

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
		for surface_value in SURFACES:
			var surface := String(surface_value)
			var row: Dictionary = await _prove_failure_and_manual_recovery(surface, phase)
			if row.is_empty():
				return
			failure_matrix["%s:%s" % [phase, surface]] = row

	var alternate_end_turn := {}
	for phase_value in FAILURE_PHASES:
		var phase := String(phase_value)
		var row: Dictionary = await _prove_alternate_end_turn_reconciliation(phase)
		if row.is_empty():
			return
		alternate_end_turn[phase] = row
	var failed_end_turn: Dictionary = await _prove_alternate_end_turn_failure("after_backup")
	if failed_end_turn.is_empty():
		return

	var ordinary := {}
	for surface_value in SURFACES:
		var surface := String(surface_value)
		var row: Dictionary = await _prove_ordinary_success(surface)
		if row.is_empty():
			return
		ordinary[surface] = row
	var generated_defer: Dictionary = await _prove_generated_overworld_defer()
	if generated_defer.is_empty():
		return

	_cleanup()
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"failure_matrix": failure_matrix,
		"alternate_end_turn": alternate_end_turn,
		"failed_end_turn": failed_end_turn,
		"ordinary_success": ordinary,
		"generated_overworld_defer": generated_defer,
		"save_version": SessionState.SAVE_VERSION,
	})])
	get_tree().quit(0)


func _require_hooks() -> bool:
	for scene in [OverworldShellScene, BattleShellScene]:
		var shell: Node = scene.instantiate()
		for method_name in [
			"validation_briefing_consumption_autosave_snapshot",
			"validation_select_save_slot",
			"validation_save_to_selected_slot",
		]:
			if not shell.has_method(method_name):
				shell.free()
				return _fail_bool("Briefing shell is missing validation hook %s." % method_name)
		shell.free()
	var overworld_shell: Node = OverworldShellScene.instantiate()
	for method_name in [
		"validation_reconcile_briefing_consumption_autosave_recovery_direct",
		"validation_request_manual_save",
		"validation_cancel_manual_save_overwrite",
		"validation_request_end_turn",
		"validation_confirm_end_turn",
		"validation_end_turn_confirmation_snapshot",
	]:
		if not overworld_shell.has_method(method_name):
			overworld_shell.free()
			return _fail_bool("Overworld briefing shell is missing validation hook %s." % method_name)
	overworld_shell.free()
	for method_name in [
		"validation_summary_cache_snapshot",
		"validation_clear_summary_cache",
		"validation_transaction_artifact_paths",
	]:
		if not SaveService.has_method(method_name):
			return _fail_bool("SaveService is missing transaction hook %s." % method_name)
	return true


func _prove_alternate_end_turn_reconciliation(phase: String) -> Dictionary:
	_clear_runtime_files()
	var prior: SessionStateStoreScript.SessionData = _prior_session(110 + FAILURE_PHASES.find(phase))
	if not bool(SaveService.save_runtime_autosave_session(prior).get("ok", false)) \
			or not bool(SaveService.save_runtime_manual_session(prior, 1).get("ok", false)):
		return _fail_dictionary("Could not seed alternate End Turn saves for %s." % phase)
	SaveService.inspect_autosave()
	var fixture: SessionStateStoreScript.SessionData = _overworld_end_turn_fixture(120 + FAILURE_PHASES.find(phase))
	OS.set_environment(FAILURE_ENV, phase)
	var shell: Node = await _create_shell("overworld", fixture)
	OS.unset_environment(FAILURE_ENV)
	if shell == null:
		return {}
	var initial: Dictionary = shell.call("validation_briefing_consumption_autosave_snapshot")
	var opening_issue: Dictionary = initial.get("last_runtime_issue", {}).duplicate(true)
	if not bool(initial.get("failure_pending", false)) \
			or not bool(initial.get("authoritative_briefing_canonical", false)) \
			or bool(initial.get("verified_alternate_proof_current", true)) \
			or RuntimeIssueLog.issue_record_count() != 1:
		await _discard_shell(shell)
		return _fail_dictionary("Alternate %s entry failure did not establish proof-bound briefing recovery: %s" % [phase, JSON.stringify(_compact_snapshot(initial))])

	var autosave_before: Dictionary = _file_state(AUTOSAVE_PATH)
	var cache_before: Dictionary = SaveService.validation_summary_cache_snapshot()
	var canonical_state: Dictionary = initial.get("authoritative_briefing_state", {}).duplicate(true)
	var live: SessionStateStoreScript.SessionData = SessionState.ensure_active_session()
	var malformed_state := canonical_state.duplicate(true)
	malformed_state["shown_day"] = 0
	live.overworld[OverworldRules.COMMAND_BRIEFING_KEY] = malformed_state
	var malformed_reconcile: Dictionary = shell.call("validation_reconcile_briefing_consumption_autosave_recovery_direct")
	live.overworld[OverworldRules.COMMAND_BRIEFING_KEY] = canonical_state
	var unverified_reconcile: Dictionary = shell.call("validation_reconcile_briefing_consumption_autosave_recovery_direct")
	if String(malformed_reconcile.get("reason", "")) != "authority_not_canonical" \
			or bool(malformed_reconcile.get("reconciled", true)) \
			or String(unverified_reconcile.get("reason", "")) != "alternate_save_not_verified" \
			or bool(unverified_reconcile.get("reconciled", true)) \
			or not bool(shell.call("validation_briefing_consumption_autosave_snapshot").get("failure_pending", false)) \
			or _file_state(AUTOSAVE_PATH) != autosave_before \
			or SaveService.validation_summary_cache_snapshot() != cache_before:
		await _discard_shell(shell)
		return _fail_dictionary("Alternate %s recovery self-healed without canonical durable proof." % phase)

	if not bool(shell.call("validation_select_save_slot", 1)):
		await _discard_shell(shell)
		return _fail_dictionary("Could not select occupied manual slot for alternate %s control." % phase)
	var first_save: Dictionary = shell.call("validation_request_manual_save")
	await _settle()
	var after_first_save: Dictionary = shell.call("validation_briefing_consumption_autosave_snapshot")
	if not bool(first_save.get("visible", false)) \
			or int(first_save.get("pending_slot", 0)) != 1 \
			or not bool(after_first_save.get("failure_pending", false)) \
			or int(after_first_save.get("reconciliation_count", -1)) != 0 \
			or _file_state(AUTOSAVE_PATH) != autosave_before \
			or SaveService.validation_summary_cache_snapshot() != cache_before:
		await _discard_shell(shell)
		return _fail_dictionary("First Save after %s entry failure bypassed proof or failed ordinary overwrite gating." % phase)
	shell.call("validation_cancel_manual_save_overwrite")
	await _settle()

	var control := _duplicate_session(SessionState.ensure_active_session())
	var control_result: Dictionary = OverworldRules.end_turn(control)
	control.flags["last_action"] = "ended_turn"
	var end_result: Dictionary = shell.call("validation_request_end_turn")
	if bool(end_result.get("confirmation_required", false)):
		end_result = shell.call("validation_confirm_end_turn")
	await _settle(4)
	var end_snapshot: Dictionary = shell.call("validation_end_turn_confirmation_snapshot")
	var recovery: Dictionary = shell.call("validation_briefing_consumption_autosave_snapshot")
	var reconciliation: Dictionary = recovery.get("last_reconciliation_result", {}) if recovery.get("last_reconciliation_result", {}) is Dictionary else {}
	live = SessionState.ensure_active_session()
	var restored = SaveService.restore_autosave_session()
	if not bool(end_result.get("ok", false)) \
			or not bool(end_result.get("committed", false)) \
			or bool(end_result.get("resolved", false)) \
			or int(end_snapshot.get("rules_end_turn_call_count", -1)) != 1 \
			or int(end_snapshot.get("autosave_call_count", -1)) != 1 \
			or int(end_snapshot.get("autosave_failure_count", -1)) != 0 \
			or int(end_snapshot.get("resolution_attempt_count", -1)) != 0 \
			or not bool(control_result.get("ok", false)) \
			or bool(recovery.get("failure_pending", true)) \
			or int(recovery.get("reconciliation_count", -1)) != 1 \
			or not bool(recovery.get("authoritative_briefing_canonical", false)) \
			or not bool(recovery.get("verified_alternate_proof_current", false)) \
			or String(reconciliation.get("source", "")) != "end_turn_autosave" \
			or String(reconciliation.get("reason", "")) != "alternate_autosave_saved" \
			or not bool(reconciliation.get("saved", false)) \
			or bool(reconciliation.get("write_attempted", true)) \
			or bool(reconciliation.get("reconciliation_write_attempted", true)) \
			or not bool(reconciliation.get("alternate_save_verified", false)) \
			or recovery.get("last_runtime_issue", {}) != opening_issue \
			or RuntimeIssueLog.issue_record_count() != 1 \
			or String(recovery.get("visible_message", "")) == FAILURE_MESSAGE \
			or String(recovery.get("visible_action_feedback", "")).contains(FAILURE_MESSAGE) \
			or String(recovery.get("focus_owner", "")) != "EndTurn" \
			or restored == null \
			or not _briefing_authority_canonical(live) \
			or not _briefing_authority_canonical(restored) \
			or _gameplay_payload(live) != _gameplay_payload(control) \
			or _gameplay_payload(restored) != _gameplay_payload(live) \
			or not _transaction_artifacts_absent(AUTOSAVE_PATH):
		await _discard_shell(shell)
		return _fail_dictionary("Alternate %s End Turn did not reconcile briefing recovery exactly: %s" % [phase, JSON.stringify({"end": end_result, "end_snapshot": _compact_end_turn(end_snapshot), "recovery": _compact_snapshot(recovery), "reconciliation": reconciliation, "live_difference": _first_difference(_gameplay_payload(control), _gameplay_payload(live)), "restore_difference": _first_difference(_gameplay_payload(live), _gameplay_payload(restored)) if restored != null else {"restored": false}})])

	var autosave_after: Dictionary = _file_state(AUTOSAVE_PATH)
	var manual_after: Dictionary = _file_state(MANUAL_PATH)
	var next_save: Dictionary = shell.call("validation_request_manual_save")
	await _settle()
	var after_next_save: Dictionary = shell.call("validation_briefing_consumption_autosave_snapshot")
	if not bool(next_save.get("visible", false)) \
			or int(next_save.get("pending_slot", 0)) != 1 \
			or bool(after_next_save.get("failure_pending", true)) \
			or String(after_next_save.get("last_reconciliation_result", {}).get("reason", "")) == "not_pending" \
			or _file_state(AUTOSAVE_PATH) != autosave_after \
			or _file_state(MANUAL_PATH) != manual_after:
		await _discard_shell(shell)
		return _fail_dictionary("Save after alternate %s reconciliation did not enter ordinary overwrite flow." % phase)
	shell.call("validation_cancel_manual_save_overwrite")
	await _discard_shell(shell)
	return {"rules": 1, "autosaves": 1, "reconciled": true, "issue_count": 1, "focus": "EndTurn", "next_save": "manual_overwrite"}


func _prove_alternate_end_turn_failure(phase: String) -> Dictionary:
	_clear_runtime_files()
	var prior: SessionStateStoreScript.SessionData = _prior_session(140)
	if not bool(SaveService.save_runtime_autosave_session(prior).get("ok", false)):
		return _fail_dictionary("Could not seed failed alternate End Turn autosave.")
	SaveService.inspect_autosave()
	var fixture: SessionStateStoreScript.SessionData = _overworld_end_turn_fixture(141)
	OS.set_environment(FAILURE_ENV, phase)
	var shell: Node = await _create_shell("overworld", fixture)
	if shell == null:
		return {}
	var opening: Dictionary = shell.call("validation_briefing_consumption_autosave_snapshot")
	var opening_issue: Dictionary = opening.get("last_runtime_issue", {}).duplicate(true)
	var autosave_before: Dictionary = _file_state(AUTOSAVE_PATH)
	var cache_before: Dictionary = SaveService.validation_summary_cache_snapshot()
	var control := _duplicate_session(SessionState.ensure_active_session())
	var control_result: Dictionary = OverworldRules.end_turn(control)
	control.flags["last_action"] = "ended_turn"
	var end_result: Dictionary = shell.call("validation_request_end_turn")
	if bool(end_result.get("confirmation_required", false)):
		end_result = shell.call("validation_confirm_end_turn")
	await _settle(4)
	var end_snapshot: Dictionary = shell.call("validation_end_turn_confirmation_snapshot")
	var recovery: Dictionary = shell.call("validation_briefing_consumption_autosave_snapshot")
	var issues: Array = RuntimeIssueLog.last_issue_records(3)
	var last_issue: Dictionary = issues[issues.size() - 1] if not issues.is_empty() and issues[issues.size() - 1] is Dictionary else {}
	if bool(end_result.get("ok", true)) \
			or not bool(end_result.get("committed", false)) \
			or String(end_result.get("reason", "")) != "autosave_failed" \
			or String(end_result.get("retry_action", "")) != "save" \
			or not bool(end_result.get("rules_applied", false)) \
			or int(end_snapshot.get("rules_end_turn_call_count", -1)) != 1 \
			or int(end_snapshot.get("autosave_call_count", -1)) != 1 \
			or int(end_snapshot.get("autosave_failure_count", -1)) != 1 \
			or int(end_snapshot.get("resolution_attempt_count", -1)) != 0 \
			or not bool(control_result.get("ok", false)) \
			or not bool(recovery.get("failure_pending", false)) \
			or int(recovery.get("reconciliation_count", -1)) != 0 \
			or recovery.get("last_runtime_issue", {}) != opening_issue \
			or RuntimeIssueLog.issue_record_count() != 2 \
			or String(last_issue.get("event", "")) != "end_turn_autosave_failed" \
			or String(last_issue.get("metadata", {}).get("retry_action", "")) != "save" \
			or String(recovery.get("visible_message", "")) != END_TURN_FAILURE_MESSAGE \
			or String(recovery.get("focus_owner", "")) != "EndTurn" \
			or _gameplay_payload(SessionState.ensure_active_session()) != _gameplay_payload(control) \
			or _file_state(AUTOSAVE_PATH) != autosave_before \
			or SaveService.validation_summary_cache_snapshot() != cache_before \
			or not _transaction_artifacts_absent(AUTOSAVE_PATH):
		await _discard_shell(shell)
		return _fail_dictionary("Failed alternate End Turn did not preserve briefing recovery authority: %s" % JSON.stringify({"end": end_result, "end_snapshot": _compact_end_turn(end_snapshot), "recovery": _compact_snapshot(recovery), "issues": issues}))

	OS.unset_environment(FAILURE_ENV)
	var stale_direct: Dictionary = shell.call("validation_reconcile_briefing_consumption_autosave_recovery_direct")
	await _settle()
	var after_stale: Dictionary = shell.call("validation_briefing_consumption_autosave_snapshot")
	if String(stale_direct.get("reason", "")) != "alternate_save_not_verified" \
			or bool(stale_direct.get("reconciled", true)) \
			or not bool(after_stale.get("failure_pending", false)) \
			or int(after_stale.get("reconciliation_count", -1)) != 0 \
			or _file_state(AUTOSAVE_PATH) != autosave_before \
			or SaveService.validation_summary_cache_snapshot() != cache_before:
		await _discard_shell(shell)
		return _fail_dictionary("Failed alternate End Turn stale direct retry cleared unprotected briefing recovery.")
	await _discard_shell(shell)
	return {"rules": 1, "autosave_failure": 1, "retry_action": "save", "pending": true, "issues": 2, "stale_direct_write_attempts": 0}


func _prove_failure_and_manual_recovery(surface: String, phase: String) -> Dictionary:
	_clear_runtime_files()
	var prior: SessionStateStoreScript.SessionData = _prior_session(10 + FAILURE_PHASES.find(phase) * 4 + SURFACES.find(surface))
	var prior_save: Dictionary = SaveService.save_runtime_autosave_session(prior)
	if not bool(prior_save.get("ok", false)):
		return _fail_dictionary("Could not seed prior autosave for %s/%s." % [phase, surface])
	SaveService.inspect_autosave()
	for manual_slot in SaveService.get_manual_slot_ids():
		SaveService.inspect_manual_slot(int(manual_slot))
	var autosave_before: Dictionary = _file_state(AUTOSAVE_PATH)
	var cache_before: Dictionary = SaveService.validation_summary_cache_snapshot()
	var issue_count_before := RuntimeIssueLog.issue_record_count()
	var fixture: SessionStateStoreScript.SessionData = _surface_fixture(surface, 30 + FAILURE_PHASES.find(phase) * 4 + SURFACES.find(surface))
	if fixture == null:
		return {}
	OS.set_environment(FAILURE_ENV, phase)
	var shell: Node = await _create_shell(surface, fixture)
	OS.unset_environment(FAILURE_ENV)
	if shell == null:
		return {}
	var live: SessionStateStoreScript.SessionData = SessionState.ensure_active_session()
	var snapshot: Dictionary = shell.call("validation_briefing_consumption_autosave_snapshot")
	var last_autosave: Dictionary = snapshot.get("last_autosave_result", {}) if snapshot.get("last_autosave_result", {}) is Dictionary else {}
	var last_result: Dictionary = snapshot.get("last_result", {}) if snapshot.get("last_result", {}) is Dictionary else {}
	var issues: Array = RuntimeIssueLog.last_issue_records(1)
	var issue: Dictionary = issues[0] if not issues.is_empty() and issues[0] is Dictionary else {}
	var save_button: Button = shell.get_node_or_null("%Save")
	if not bool(snapshot.get("briefing_consumed", false)) \
			or not bool(snapshot.get("briefing_shown", false)) \
			or not bool(snapshot.get("briefing_active", false)) \
			or not bool(snapshot.get("briefing_visible", false)) \
			or not bool(snapshot.get("failure_pending", false)) \
			or int(snapshot.get("consumption_count", -1)) != 1 \
			or int(snapshot.get("autosave_attempt_count", -1)) != 1 \
			or int(snapshot.get("autosave_success_count", -1)) != 0 \
			or int(snapshot.get("autosave_failure_count", -1)) != 1 \
			or bool(last_autosave.get("ok", true)):
		await _discard_shell(shell)
		return _fail_dictionary("%s %s failure did not retain one visible shown briefing and one failed save: %s" % [phase, surface, JSON.stringify(_compact_snapshot(snapshot))])
	if surface == "battle" and (
		bool(last_result.get("ok", true))
		or String(last_result.get("reason", "")) != "autosave_failed"
		or String(last_result.get("retry_action", "")) != "manual_save"
	):
		await _discard_shell(shell)
		return _fail_dictionary("Battle %s failure result was dishonest: %s" % [phase, JSON.stringify(last_result)])
	if String(snapshot.get("visible_message", "")) != FAILURE_MESSAGE \
			or String(snapshot.get("visible_action_feedback", "")).strip_edges() == "" \
			or save_button == null \
			or "Save" not in save_button.text \
			or String(snapshot.get("focus_owner", "")) != "Save" \
			or int(snapshot.get("resolution_route_attempt_count", -1)) != 0:
		await _discard_shell(shell)
		return _fail_dictionary("%s %s failure did not expose exact Save guidance/focus with zero route: %s" % [phase, surface, JSON.stringify(_compact_snapshot(snapshot))])
	if RuntimeIssueLog.issue_record_count() != issue_count_before + 1 \
			or String(issue.get("surface", "")) != surface \
			or String(issue.get("event", "")) != "briefing_consumption_autosave_failed" \
			or String(issue.get("message", "")) != FAILURE_MESSAGE \
			or _issue_has_path(issue):
		await _discard_shell(shell)
		return _fail_dictionary("%s %s failure did not emit one sanitized issue: %s" % [phase, surface, JSON.stringify(_compact_issue(issue))])
	if _file_state(AUTOSAVE_PATH) != autosave_before \
			or SaveService.validation_summary_cache_snapshot() != cache_before \
			or not _transaction_artifacts_absent(AUTOSAVE_PATH):
		await _discard_shell(shell)
		return _fail_dictionary("%s %s failure changed prior autosave bytes/cache or left residue." % [phase, surface])
	if not _live_briefing_shown(live, surface):
		await _discard_shell(shell)
		return _fail_dictionary("%s %s failure lost the live shown briefing state." % [phase, surface])

	if not bool(shell.call("validation_select_save_slot", 1)):
		await _discard_shell(shell)
		return _fail_dictionary("Could not select Manual Slot 1 for %s/%s recovery." % [phase, surface])
	var manual_result: Dictionary = shell.call("validation_save_to_selected_slot")
	await _settle()
	var after: Dictionary = shell.call("validation_briefing_consumption_autosave_snapshot")
	var restored = SaveService.restore_manual_session(1)
	if not bool(manual_result.get("ok", false)) \
			or restored == null \
			or bool(after.get("failure_pending", true)) \
			or int(after.get("consumption_count", -1)) != 1 \
			or int(after.get("autosave_attempt_count", -1)) != 1 \
			or int(after.get("resolution_route_attempt_count", -1)) != 0 \
			or not _live_briefing_shown(restored, surface) \
			or restored.session_id != live.session_id \
			or not _transaction_artifacts_absent(MANUAL_PATH):
		await _discard_shell(shell)
		return _fail_dictionary("Manual Save did not protect %s/%s without re-consuming or routing: %s" % [phase, surface, JSON.stringify({"manual_ok": manual_result.get("ok", false), "after": _compact_snapshot(after), "restored": restored != null})])
	await _discard_shell(shell)
	return {
		"briefing_visible": true,
		"old_autosave_bytes_exact": true,
		"summary_cache_exact": true,
		"no_transaction_residue": true,
		"runtime_issue_event": "briefing_consumption_autosave_failed",
		"manual_reload_shown": true,
		"route_attempts": 0,
	}


func _prove_ordinary_success(surface: String) -> Dictionary:
	_clear_runtime_files()
	var fixture: SessionStateStoreScript.SessionData = _surface_fixture(surface, 70 + SURFACES.find(surface))
	if fixture == null:
		return {}
	var shell: Node = await _create_shell(surface, fixture)
	if shell == null:
		return {}
	var snapshot: Dictionary = shell.call("validation_briefing_consumption_autosave_snapshot")
	var restored = SaveService.restore_autosave_session()
	if int(snapshot.get("consumption_count", -1)) != 1 \
			or int(snapshot.get("autosave_attempt_count", -1)) != 1 \
			or int(snapshot.get("autosave_success_count", -1)) != 1 \
			or int(snapshot.get("autosave_failure_count", -1)) != 0 \
			or bool(snapshot.get("failure_pending", true)) \
			or restored == null \
			or not _live_briefing_shown(restored, surface) \
			or RuntimeIssueLog.issue_record_count() != 0:
		await _discard_shell(shell)
		return _fail_dictionary("Ordinary %s briefing consumption did not save exactly once: %s" % [surface, JSON.stringify(_compact_snapshot(snapshot))])
	await _discard_shell(shell)
	return {"autosave_attempts": 1, "autosave_successes": 1, "briefing_shown_on_reload": true}


func _prove_generated_overworld_defer() -> Dictionary:
	_clear_runtime_files()
	var fixture: SessionStateStoreScript.SessionData = _overworld_fixture(90)
	fixture.flags["generated_random_map"] = true
	fixture.flags[SaveService.GENERATED_OPENING_AUTOSAVE_PENDING_FLAG] = true
	var shell: Node = await _create_shell("overworld", fixture)
	if shell == null:
		return {}
	var snapshot: Dictionary = shell.call("validation_briefing_consumption_autosave_snapshot")
	if int(snapshot.get("consumption_count", -1)) != 1 \
			or int(snapshot.get("autosave_attempt_count", -1)) != 0 \
			or int(snapshot.get("autosave_failure_count", -1)) != 0 \
			or int(snapshot.get("generated_defer_count", -1)) != 1 \
			or not bool(snapshot.get("briefing_shown", false)) \
			or not bool(snapshot.get("briefing_active", false)):
		await _discard_shell(shell)
		return _fail_dictionary("Generated opening did not defer the briefing-consumption save: %s" % JSON.stringify(_compact_snapshot(snapshot)))
	await _discard_shell(shell)
	return {"consumption_count": 1, "immediate_autosave_attempts": 0, "generated_defer_count": 1}


func _create_shell(surface: String, session: SessionStateStoreScript.SessionData) -> Node:
	SessionState.set_active_session(session)
	var shell: Node = OverworldShellScene.instantiate() if surface == "overworld" else BattleShellScene.instantiate()
	add_child(shell)
	await _settle(5)
	if not is_instance_valid(shell) or not shell.has_method("validation_briefing_consumption_autosave_snapshot"):
		_fail("Could not instantiate %s briefing shell." % surface)
		return null
	return shell


func _surface_fixture(surface: String, seed_offset: int) -> SessionStateStoreScript.SessionData:
	return _overworld_fixture(seed_offset) if surface == "overworld" else _battle_fixture(seed_offset)


func _overworld_fixture(seed_offset: int) -> SessionStateStoreScript.SessionData:
	var session = ScenarioFactory.create_session(SCENARIO_ID, "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	session.session_id = "%s-briefing-overworld-%d" % [session.session_id, seed_offset]
	session.day = 1
	session.game_state = "overworld"
	session.battle = {}
	session.flags.erase("last_action")
	OverworldRules.normalize_overworld_state(session)
	var state_value: Variant = session.overworld.get(OverworldRules.COMMAND_BRIEFING_KEY, {})
	var state: Dictionary = state_value if state_value is Dictionary else {}
	state["shown"] = false
	state["shown_day"] = 0
	session.overworld[OverworldRules.COMMAND_BRIEFING_KEY] = state
	return session


func _overworld_end_turn_fixture(seed_offset: int) -> SessionStateStoreScript.SessionData:
	var session: SessionStateStoreScript.SessionData = _overworld_fixture(seed_offset)
	var movement: Dictionary = session.overworld.get("movement", {}) if session.overworld.get("movement", {}) is Dictionary else {}
	movement["current"] = 0
	session.overworld["movement"] = movement
	OverworldRules.consume_command_risk_forecast(session)
	OverworldRules.mark_runtime_normalized_transition_state(session)
	return session


func _battle_fixture(seed_offset: int) -> SessionStateStoreScript.SessionData:
	var session = ScenarioFactory.create_session(SCENARIO_ID, "normal", SessionStateStoreScript.LAUNCH_MODE_SKIRMISH)
	session.session_id = "%s-briefing-battle-%d" % [session.session_id, seed_offset]
	var encounter := _encounter(session, ENCOUNTER_ID)
	if encounter.is_empty():
		_fail("Authored encounter %s is missing." % ENCOUNTER_ID)
		return null
	session.battle = BattleRulesScript.create_battle_payload(session, encounter)
	session.game_state = "battle"
	BattleRulesScript.normalize_battle_state(session)
	var guard := 0
	while String(BattleRulesScript.get_active_stack(session.battle).get("side", "")) != "player" and guard < 16:
		BattleRulesScript.advance_turn(session.battle)
		guard += 1
	session.battle["round"] = 1
	session.battle["recent_events"] = []
	var state_value: Variant = session.battle.get(BattleRulesScript.TACTICAL_BRIEFING_KEY, {})
	var state: Dictionary = state_value if state_value is Dictionary else {}
	state["shown"] = false
	state["shown_round"] = 0
	session.battle[BattleRulesScript.TACTICAL_BRIEFING_KEY] = state
	return session


func _prior_session(seed_offset: int) -> SessionStateStoreScript.SessionData:
	var session: SessionStateStoreScript.SessionData = _overworld_fixture(seed_offset)
	session.session_id = "%s-prior" % session.session_id
	session.day = 3
	var state_value: Variant = session.overworld.get(OverworldRules.COMMAND_BRIEFING_KEY, {})
	if state_value is Dictionary:
		state_value["shown"] = true
		state_value["shown_day"] = 1
	return session


func _encounter(session: SessionStateStoreScript.SessionData, placement_id: String) -> Dictionary:
	for value in session.overworld.get("encounters", []):
		if value is Dictionary and String(value.get("placement_id", "")) == placement_id:
			return value
	return {}


func _live_briefing_shown(session: SessionStateStoreScript.SessionData, surface: String) -> bool:
	if session == null:
		return false
	var state_value: Variant = session.overworld.get(OverworldRules.COMMAND_BRIEFING_KEY, {}) if surface == "overworld" else session.battle.get(BattleRulesScript.TACTICAL_BRIEFING_KEY, {})
	return state_value is Dictionary and bool(state_value.get("shown", false))


func _briefing_authority_canonical(session: SessionStateStoreScript.SessionData) -> bool:
	if session == null:
		return false
	var state_value: Variant = session.overworld.get(OverworldRules.COMMAND_BRIEFING_KEY, {})
	if not (state_value is Dictionary):
		return false
	var state: Dictionary = state_value
	var expected_signature := "%s|%s" % [session.scenario_id, SessionStateStoreScript.normalize_launch_mode(session.launch_mode)]
	var shown_day := int(state.get("shown_day", 0))
	return String(state.get("signature", "")) == expected_signature \
		and bool(state.get("shown", false)) \
		and shown_day > 0 \
		and shown_day <= session.day


func _duplicate_session(session: SessionStateStoreScript.SessionData) -> SessionStateStoreScript.SessionData:
	var duplicate: SessionStateStoreScript.SessionData = SessionStateStoreScript.new_session_data()
	duplicate.from_dict(session.to_dict())
	return duplicate


func _gameplay_payload(session) -> Dictionary:
	if session == null:
		return {}
	var parsed: Variant = JSON.parse_string(JSON.stringify(session.to_dict()))
	var payload: Dictionary = parsed if parsed is Dictionary else {}
	for metadata_key in ["saved_at_unix", "save_slot_type", "saved_from_game_state", "saved_from_scenario_status", "saved_from_launch_mode", "manual_slot_name"]:
		payload.erase(metadata_key)
	var overworld: Dictionary = payload.get("overworld", {}) if payload.get("overworld", {}) is Dictionary else {}
	overworld.erase("command_risk_forecast")
	payload["overworld"] = overworld
	return payload


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
			var nested: Dictionary = _first_difference(expected_dictionary.get(key), actual_dictionary.get(key), "%s.%s" % [path, key])
			if not nested.is_empty():
				return nested
		return {}
	if expected is Array:
		var expected_array: Array = expected
		var actual_array: Array = actual
		if expected_array.size() != actual_array.size():
			return {"path": path, "expected_size": expected_array.size(), "actual_size": actual_array.size()}
		for index in range(expected_array.size()):
			var nested: Dictionary = _first_difference(expected_array[index], actual_array[index], "%s[%d]" % [path, index])
			if not nested.is_empty():
				return nested
		return {}
	if expected != actual:
		return {"path": path, "expected": expected, "actual": actual}
	return {}


func _settle(frames: int = 3) -> void:
	for _index in range(maxi(1, frames)):
		await get_tree().process_frame


func _discard_shell(shell: Node) -> void:
	if shell != null and is_instance_valid(shell):
		shell.queue_free()
		await _settle(3)


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


func _clear_runtime_files() -> void:
	OS.unset_environment(FAILURE_ENV)
	for path_value in [
		AUTOSAVE_PATH,
		"%s.candidate" % AUTOSAVE_PATH,
		"%s.backup" % AUTOSAVE_PATH,
		MANUAL_PATH,
		"%s.candidate" % MANUAL_PATH,
		"%s.backup" % MANUAL_PATH,
	]:
		_remove_path(String(path_value))
	_write_bytes(ISSUE_LOG_PATH, PackedByteArray())
	_remove_path(LATEST_ISSUE_PATH)
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


func _issue_has_path(issue: Dictionary) -> bool:
	var player_payload := JSON.stringify({
		"message": issue.get("message", ""),
		"metadata": issue.get("metadata", {}),
	}).to_lower()
	return "user://" in player_payload or "/root/" in player_payload or "\\users\\" in player_payload


func _compact_snapshot(snapshot: Dictionary) -> Dictionary:
	return {
		"consumed": snapshot.get("briefing_consumed", null),
		"shown": snapshot.get("briefing_shown", null),
		"active": snapshot.get("briefing_active", null),
		"visible": snapshot.get("briefing_visible", null),
		"pending": snapshot.get("failure_pending", null),
		"consumption": snapshot.get("consumption_count", -1),
		"attempt": snapshot.get("autosave_attempt_count", -1),
		"success": snapshot.get("autosave_success_count", -1),
		"failure": snapshot.get("autosave_failure_count", -1),
		"deferred": snapshot.get("generated_defer_count", -1),
		"reconciliation": snapshot.get("reconciliation_count", -1),
		"canonical": snapshot.get("authoritative_briefing_canonical", null),
		"verified_proof": snapshot.get("verified_alternate_proof_current", null),
		"message": snapshot.get("visible_message", ""),
		"focus": snapshot.get("focus_owner", ""),
		"routes": snapshot.get("resolution_route_attempt_count", -1),
	}


func _compact_end_turn(snapshot: Dictionary) -> Dictionary:
	return {
		"rules": snapshot.get("rules_end_turn_call_count", -1),
		"autosaves": snapshot.get("autosave_call_count", -1),
		"failures": snapshot.get("autosave_failure_count", -1),
		"routes": snapshot.get("resolution_attempt_count", -1),
		"message": snapshot.get("visible_message", ""),
	}


func _compact_issue(issue: Dictionary) -> Dictionary:
	return {
		"surface": issue.get("surface", ""),
		"event": issue.get("event", ""),
		"message": issue.get("message", ""),
		"metadata": issue.get("metadata", {}),
	}


func _cleanup() -> void:
	OS.unset_environment(FAILURE_ENV)
	for path_value in _tracked_paths():
		_remove_path(String(path_value))
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
	get_tree().quit(1)
