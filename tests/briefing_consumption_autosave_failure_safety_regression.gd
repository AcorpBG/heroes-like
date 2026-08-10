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
	for method_name in [
		"validation_summary_cache_snapshot",
		"validation_clear_summary_cache",
		"validation_transaction_artifact_paths",
	]:
		if not SaveService.has_method(method_name):
			return _fail_bool("SaveService is missing transaction hook %s." % method_name)
	return true


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
		"message": snapshot.get("visible_message", ""),
		"focus": snapshot.get("focus_owner", ""),
		"routes": snapshot.get("resolution_route_attempt_count", -1),
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
