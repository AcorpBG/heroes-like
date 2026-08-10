extends Node

const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")

const REPORT_ID := "APPLICATION_ACTIVE_PLAY_RETURN_AUTOSAVE_FAILURE_REGRESSION"
const FAILURE_ENV := "HEROES_LIKE_SAVE_FAIL_PHASE"
const AUTOSAVE_PATH := "user://saves/autosave.json"
const FAILURE_MESSAGE := "Save failed. The expedition remains open; use Save, then try Return to Main Menu again."
const ISSUE_EVENT := "active_play_return_autosave_failed"
const ACTIVE_STATES := ["overworld", "town", "battle", "outcome"]
const FAILURE_PHASES := ["precommit", "after_backup"]
const TRANSITION_FLAGS := [
	"runtime_autosave_dirty",
	"runtime_autosave_pending_intent",
	"runtime_autosave_pending_reason",
	"runtime_autosave_pending_route",
	"runtime_autosave_pending_game_state",
	"runtime_autosave_pending_unix",
]
const GENERATED_OPENING_FLAGS := [
	"generated_overworld_deferred_autosave_pending",
	"generated_overworld_command_briefing_autosave_deferred",
	"generated_overworld_initial_autosave_completed",
]
const ISSUE_PATHS := [
	"user://debug/heroes_runtime_issues.jsonl",
	"user://debug/heroes_last_runtime_issue.json",
	"user://debug/heroes_runtime_session.json",
	"user://debug/heroes_runtime_session.tmp",
]

var _original_states: Dictionary = {}
var _original_failure_env := ""
var _original_active_session = null
var _original_editor_working_copy = null
var _original_editor_return_pending := false


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_original_states = _capture_file_states(_tracked_paths())
	_original_failure_env = OS.get_environment(FAILURE_ENV)
	_original_active_session = SessionState.active_session
	_original_editor_working_copy = SessionState.editor_working_copy_session
	_original_editor_return_pending = SessionState.editor_return_pending()
	OS.unset_environment(FAILURE_ENV)
	if not _require_hooks():
		return
	AppRouter.validation_set_active_play_return_routing_suppressed(true)
	var active_rows: Dictionary = {}
	for state_value in ACTIVE_STATES:
		var state := String(state_value)
		var shell: Node = await _create_shell(state)
		if shell == null:
			_fail("Could not create the %s active-play shell fixture." % state)
			return
		var phase_rows: Dictionary = {}
		for phase_value in FAILURE_PHASES:
			var phase := String(phase_value)
			var row: Dictionary = await _exercise_active_shell_case(shell, state, phase)
			if row.is_empty():
				return
			phase_rows[phase] = row
		active_rows[state] = phase_rows
		shell.queue_free()
		await get_tree().process_frame
	var no_session: Dictionary = _exercise_no_session_route()
	if no_session.is_empty():
		return
	var editor_return: Dictionary = _exercise_editor_return_route()
	if editor_return.is_empty():
		return
	_cleanup()
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"active_states": active_rows,
		"no_session": no_session,
		"editor_return": editor_return,
		"failure_message": FAILURE_MESSAGE,
		"save_version": SessionState.SAVE_VERSION,
	})])
	get_tree().quit(0)


func _require_hooks() -> bool:
	for method_name in [
		"return_to_main_menu_from_active_play",
		"validation_set_active_play_return_routing_suppressed",
		"validation_reset_active_play_return_state",
		"validation_active_play_return_snapshot",
	]:
		if not AppRouter.has_method(method_name):
			return _fail_bool("AppRouter is missing active-play return hook %s." % method_name)
	for method_name in [
		"validation_summary_cache_snapshot",
		"validation_clear_summary_cache",
		"validation_transaction_artifact_paths",
	]:
		if not SaveService.has_method(method_name):
			return _fail_bool("SaveService is missing transaction hook %s." % method_name)
	for state_value in ACTIVE_STATES:
		var probe: Node = _scene_for_state(String(state_value)).instantiate()
		if not probe.has_method("validation_return_to_menu") \
				or not probe.has_method("validation_active_play_return_snapshot"):
			probe.free()
			return _fail_bool("%s shell is missing active-play return validation hooks." % state_value)
		probe.free()
	return true


func _create_shell(state: String) -> Node:
	var session: SessionStateStoreScript.SessionData = _session_for_state(state, 30 + ACTIVE_STATES.find(state))
	if session == null:
		return null
	SessionState.active_session = session
	var shell: Node = _scene_for_state(state).instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	return shell


func _exercise_active_shell_case(shell: Node, state: String, phase: String) -> Dictionary:
	_clear_autosave()
	SaveService.validation_clear_summary_cache()
	var live: SessionStateStoreScript.SessionData = SessionState.ensure_active_session()
	_stage_live_flags(live, state, phase)
	var prior: SessionStateStoreScript.SessionData = _session_for_state("overworld", 70 + FAILURE_PHASES.find(phase))
	prior.flags["active_play_return_prior_marker"] = "%s_%s" % [state, phase]
	var seed_result: Dictionary = SaveService.save_runtime_autosave_session(prior)
	if not bool(seed_result.get("ok", false)):
		_fail("Could not seed the prior autosave for %s/%s." % [state, phase])
		return {}
	SaveService.inspect_autosave()
	# Prime the same complete save surface that shell failure refreshes so the
	# assertion measures cache mutation, not first-time manual-slot discovery.
	AppRouter.active_save_surface()
	var prior_file: Dictionary = _file_state(AUTOSAVE_PATH)
	var prior_cache: Dictionary = SaveService.validation_summary_cache_snapshot()
	var live_before: Dictionary = _canonical_dictionary(live.to_dict())
	var flag_snapshot: Dictionary = _flag_snapshot(live)
	var live_instance_id := live.get_instance_id()
	var shell_instance_id := shell.get_instance_id()
	var shell_parent := shell.get_parent()
	var shell_request_baseline := int((shell.call("validation_active_play_return_snapshot") as Dictionary).get("request_count", 0))
	var issue_count_before := RuntimeIssueLog.issue_record_count()
	_reset_router()
	OS.set_environment(FAILURE_ENV, phase)
	var failed: Dictionary = shell.call("validation_return_to_menu")
	OS.unset_environment(FAILURE_ENV)
	await get_tree().process_frame
	await get_tree().process_frame
	var router_failed: Dictionary = AppRouter.validation_active_play_return_snapshot()
	var shell_failed: Dictionary = shell.call("validation_active_play_return_snapshot")
	var issue_count_after_failure := RuntimeIssueLog.issue_record_count()
	var menu_button: Control = shell.get_node("%Menu")
	var focus_owner := menu_button.get_viewport().gui_get_focus_owner()
	if bool(failed.get("ok", true)) \
			or bool(failed.get("saved", true)) \
			or bool(failed.get("routed", true)) \
			or String(failed.get("reason", "")) != "autosave_failed" \
			or String(failed.get("retry_action", "")) != "return_to_menu" \
			or String(failed.get("message", "")) != FAILURE_MESSAGE \
			or bool((failed.get("save_result", {}) as Dictionary).get("ok", true)):
		_fail("%s/%s returned the wrong failure contract: %s" % [state, phase, JSON.stringify(_compact_result(failed))])
		return {}
	if not _router_failure_exact(router_failed) or issue_count_after_failure != issue_count_before + 1:
		_fail("%s/%s did not record exactly one save failure and zero routes/issues: %s" % [state, phase, JSON.stringify(_compact_router(router_failed))])
		return {}
	var runtime_issue: Dictionary = router_failed.get("last_runtime_issue", {}) if router_failed.get("last_runtime_issue", {}) is Dictionary else {}
	if String(runtime_issue.get("event", "")) != ISSUE_EVENT \
			or String(shell_failed.get("visible_message", "")) != FAILURE_MESSAGE \
			or String(shell_failed.get("focus_owner", "")) != "Menu" \
			or int(shell_failed.get("request_count", -1)) != shell_request_baseline + 1 \
			or shell_failed.get("last_result", {}) != failed \
			or focus_owner != menu_button:
		_fail("%s/%s did not surface retry guidance and restore Menu focus: %s" % [state, phase, JSON.stringify(_compact_shell(shell_failed))])
		return {}
	if not shell.is_inside_tree() or shell.get_instance_id() != shell_instance_id or shell.get_parent() != shell_parent \
			or SessionState.ensure_active_session().get_instance_id() != live_instance_id \
			or _canonical_dictionary(live.to_dict()) != live_before \
			or _flag_snapshot(live) != flag_snapshot:
		_fail("%s/%s changed the active shell/session or pending intent after save failure." % [state, phase])
		return {}
	var bytes_exact := _file_state(AUTOSAVE_PATH) == prior_file
	var cache_exact := SaveService.validation_summary_cache_snapshot() == prior_cache
	var artifacts_absent := _artifacts_absent()
	if not bytes_exact or not cache_exact or not artifacts_absent:
		_fail("%s/%s changed prior autosave transaction state: %s" % [state, phase, JSON.stringify({
			"bytes_exact": bytes_exact,
			"cache_exact": cache_exact,
			"artifacts_absent": artifacts_absent,
		})])
		return {}

	var retry: Dictionary = shell.call("validation_return_to_menu")
	await get_tree().process_frame
	await get_tree().process_frame
	var router_retry: Dictionary = AppRouter.validation_active_play_return_snapshot()
	var shell_retry: Dictionary = shell.call("validation_active_play_return_snapshot")
	if not bool(retry.get("ok", false)) or not bool(retry.get("saved", false)) \
			or not bool(retry.get("routed", false)) or String(retry.get("reason", "")) != "saved" \
			or not bool((retry.get("save_result", {}) as Dictionary).get("ok", false)):
		_fail("%s/%s retry did not save and route: %s" % [state, phase, JSON.stringify(_compact_result(retry))])
		return {}
	var last_route: Dictionary = router_retry.get("last_route", {}) if router_retry.get("last_route", {}) is Dictionary else {}
	if int(router_retry.get("request_count", -1)) != 2 \
			or int(router_retry.get("save_attempt_count", -1)) != 2 \
			or int(router_retry.get("save_failure_count", -1)) != 1 \
			or int(router_retry.get("route_attempt_count", -1)) != 1 \
			or int(router_retry.get("suppressed_route_count", -1)) != 1 \
			or String(last_route.get("target_scene", "")) != AppRouter.MAIN_MENU_SCENE \
			or String(last_route.get("reason", "")) != "saved" \
			or not bool(last_route.get("suppressed", false)) \
			or RuntimeIssueLog.issue_record_count() != issue_count_after_failure \
			or int(shell_retry.get("request_count", -1)) != shell_request_baseline + 2:
		_fail("%s/%s retry did not produce exactly one successful save/route: %s" % [state, phase, JSON.stringify(_compact_router(router_retry))])
		return {}
	if not _artifacts_absent():
		_fail("%s/%s successful retry left transaction artifacts." % [state, phase])
		return {}
	var restored: SessionStateStoreScript.SessionData = SaveService.restore_autosave_session()
	if restored == null:
		_fail("%s/%s successful retry could not restore its autosave." % [state, phase])
		return {}
	var saved_payload: Dictionary = SessionStateStoreScript.normalize_payload(_read_dictionary(AUTOSAVE_PATH))
	var expected_restore: Dictionary = _canonical_restore_payload(saved_payload, state)
	var restored_payload: Dictionary = _canonical_dictionary(restored.to_dict())
	if expected_restore != restored_payload:
		_fail("%s/%s canonical reload mismatch: %s" % [state, phase, JSON.stringify(_first_difference(expected_restore, restored_payload))])
		return {}
	if SaveService.resume_target_for_session(restored) != state \
			or String(restored.scenario_id) != String(live.scenario_id) \
			or int(restored.day) != int(live.day) \
			or String(restored.scenario_status) != String(live.scenario_status):
		_fail("%s/%s retry restored the wrong active-play identity/route." % [state, phase])
		return {}
	for flag_value in TRANSITION_FLAGS:
		if live.flags.has(String(flag_value)) or restored.flags.has(String(flag_value)):
			_fail("%s/%s successful retry retained transition intent %s." % [state, phase, flag_value])
			return {}
	for flag_value in GENERATED_OPENING_FLAGS:
		if live.flags.get(String(flag_value)) != flag_snapshot.get(String(flag_value)) \
				or restored.flags.get(String(flag_value)) != flag_snapshot.get(String(flag_value)):
			_fail("%s/%s did not preserve generated-opening flag %s through retry." % [state, phase, flag_value])
			return {}
	return {
		"failure_exact": true,
		"prior_bytes_cache_exact": true,
		"active_shell_session_exact": true,
		"visible_retry_menu_focus": true,
		"save_attempts": 2,
		"save_failures": 1,
		"successful_saves": 1,
		"routes": 1,
		"runtime_issues": 1,
		"canonical_reload": true,
	}


func _exercise_no_session_route() -> Dictionary:
	var file_before: Dictionary = _file_state(AUTOSAVE_PATH)
	var issue_before := RuntimeIssueLog.issue_record_count()
	SessionState.reset_session()
	_reset_router()
	var result: Dictionary = AppRouter.return_to_main_menu_from_active_play()
	var snapshot: Dictionary = AppRouter.validation_active_play_return_snapshot()
	var route: Dictionary = snapshot.get("last_route", {}) if snapshot.get("last_route", {}) is Dictionary else {}
	if not bool(result.get("ok", false)) or bool(result.get("saved", true)) or not bool(result.get("routed", false)) \
			or String(result.get("reason", "")) != "no_active_session" \
			or int(snapshot.get("save_attempt_count", -1)) != 0 \
			or int(snapshot.get("route_attempt_count", -1)) != 1 \
			or String(route.get("target_scene", "")) != AppRouter.MAIN_MENU_SCENE \
			or _file_state(AUTOSAVE_PATH) != file_before \
			or RuntimeIssueLog.issue_record_count() != issue_before:
		_fail("No-session active-play return was not a direct Main Menu route: %s" % JSON.stringify(_compact_router(snapshot)))
		return {}
	return {"reason": "no_active_session", "save_attempts": 0, "routes": 1}


func _exercise_editor_return_route() -> Dictionary:
	var file_before: Dictionary = _file_state(AUTOSAVE_PATH)
	var issue_before := RuntimeIssueLog.issue_record_count()
	var editor_session: SessionStateStoreScript.SessionData = _session_for_state("overworld", 91)
	editor_session.flags["editor_working_copy"] = true
	SessionState.set_editor_working_copy_session(editor_session)
	SessionState.active_session = editor_session
	_reset_router()
	var result: Dictionary = AppRouter.return_to_main_menu_from_active_play()
	var snapshot: Dictionary = AppRouter.validation_active_play_return_snapshot()
	var route: Dictionary = snapshot.get("last_route", {}) if snapshot.get("last_route", {}) is Dictionary else {}
	if not bool(result.get("ok", false)) or bool(result.get("saved", true)) or not bool(result.get("routed", false)) \
			or String(result.get("reason", "")) != "editor_return" \
			or int(snapshot.get("save_attempt_count", -1)) != 0 \
			or int(snapshot.get("route_attempt_count", -1)) != 1 \
			or String(route.get("target_scene", "")) != AppRouter.MAP_EDITOR_SCENE \
			or not SessionState.editor_return_pending() \
			or SessionState.has_playable_session() \
			or _file_state(AUTOSAVE_PATH) != file_before \
			or RuntimeIssueLog.issue_record_count() != issue_before:
		_fail("Editor active-play return was not a direct Map Editor route: %s" % JSON.stringify(_compact_router(snapshot)))
		return {}
	return {"reason": "editor_return", "save_attempts": 0, "routes": 1, "pending": true}


func _session_for_state(state: String, day: int) -> SessionStateStoreScript.SessionData:
	var session: SessionStateStoreScript.SessionData = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	session.day = day
	session.flags["active_play_return_fixture"] = state
	match state:
		"town":
			var town: Dictionary = _first_player_town(session)
			if town.is_empty():
				return null
			_move_active_hero_to_town(session, town)
			var visit: Dictionary = OverworldRules.set_active_town_visit(session, String(town.get("placement_id", "")))
			if not bool(visit.get("ok", false)):
				return null
			session.game_state = "town"
		"battle":
			var encounter: Dictionary = _first_encounter(session)
			if encounter.is_empty():
				return null
			session.battle = BattleRulesScript.create_battle_payload(session, encounter)
			if session.battle.is_empty():
				return null
			session.game_state = "battle"
		"outcome":
			session.scenario_status = "victory"
			session.scenario_summary = "Focused active-play return outcome fixture."
			session.game_state = "outcome"
		_:
			session.game_state = "overworld"
	OverworldRules.normalize_overworld_state(session)
	return session


func _stage_live_flags(session: SessionStateStoreScript.SessionData, state: String, phase: String) -> void:
	session.flags["runtime_autosave_dirty"] = true
	session.flags["runtime_autosave_pending_intent"] = true
	session.flags["runtime_autosave_pending_reason"] = "return_%s_%s" % [state, phase]
	session.flags["runtime_autosave_pending_route"] = state
	session.flags["runtime_autosave_pending_game_state"] = state
	session.flags["runtime_autosave_pending_unix"] = 10184
	session.flags["runtime_autosave_pending_count"] = int(session.flags.get("runtime_autosave_pending_count", 0)) + 1
	session.flags["generated_overworld_deferred_autosave_pending"] = true
	session.flags["generated_overworld_command_briefing_autosave_deferred"] = true
	session.flags["generated_overworld_initial_autosave_completed"] = false
	session.flags["active_play_return_case"] = "%s_%s" % [state, phase]
	OverworldRules.mark_runtime_normalized_transition_state(session)


func _canonical_restore_payload(saved_payload: Dictionary, state: String) -> Dictionary:
	var expected: SessionStateStoreScript.SessionData = SessionStateStoreScript.new_session_data()
	expected.from_dict(saved_payload)
	OverworldRules.normalize_overworld_state(expected)
	match state:
		"battle":
			BattleRulesScript.normalize_battle_state_bridge(expected)
		"outcome":
			expected.battle = {}
			expected.game_state = "outcome"
		"town":
			expected.game_state = "town"
		_:
			expected.battle = {}
			expected.game_state = "overworld"
	return _canonical_dictionary(expected.to_dict())


func _first_player_town(session: SessionStateStoreScript.SessionData) -> Dictionary:
	for town_value in session.overworld.get("towns", []):
		if town_value is Dictionary and String(town_value.get("owner", "")) == "player":
			return town_value
	return {}


func _move_active_hero_to_town(session: SessionStateStoreScript.SessionData, town: Dictionary) -> void:
	var position := {"x": int(town.get("x", 0)), "y": int(town.get("y", 0))}
	session.overworld["hero_position"] = position.duplicate(true)
	var hero: Dictionary = session.overworld.get("hero", {}) if session.overworld.get("hero", {}) is Dictionary else {}
	hero["position"] = position.duplicate(true)
	session.overworld["hero"] = hero
	var heroes: Array = session.overworld.get("player_heroes", []) if session.overworld.get("player_heroes", []) is Array else []
	for index in range(heroes.size()):
		var candidate = heroes[index]
		if candidate is Dictionary and String(candidate.get("id", "")) == String(session.overworld.get("active_hero_id", "")):
			candidate["position"] = position.duplicate(true)
			heroes[index] = candidate
	session.overworld["player_heroes"] = heroes


func _first_encounter(session: SessionStateStoreScript.SessionData) -> Dictionary:
	for encounter_value in session.overworld.get("encounters", []):
		if encounter_value is Dictionary:
			return encounter_value
	return {}


func _scene_for_state(state: String) -> PackedScene:
	match state:
		"town":
			return load("res://scenes/town/TownShell.tscn")
		"battle":
			return load("res://scenes/battle/BattleShell.tscn")
		"outcome":
			return load("res://scenes/results/ScenarioOutcomeShell.tscn")
		_:
			return load("res://scenes/overworld/OverworldShell.tscn")


func _reset_router() -> void:
	AppRouter.validation_set_active_play_return_routing_suppressed(true)
	AppRouter.validation_reset_active_play_return_state()


func _router_failure_exact(snapshot: Dictionary) -> bool:
	var last_issue: Dictionary = snapshot.get("last_runtime_issue", {}) if snapshot.get("last_runtime_issue", {}) is Dictionary else {}
	return int(snapshot.get("request_count", -1)) == 1 \
		and int(snapshot.get("save_attempt_count", -1)) == 1 \
		and int(snapshot.get("save_failure_count", -1)) == 1 \
		and int(snapshot.get("route_attempt_count", -1)) == 0 \
		and int(snapshot.get("suppressed_route_count", -1)) == 0 \
		and String(last_issue.get("event", "")) == ISSUE_EVENT


func _flag_snapshot(session: SessionStateStoreScript.SessionData) -> Dictionary:
	var result: Dictionary = {}
	for flag_value in TRANSITION_FLAGS + GENERATED_OPENING_FLAGS + ["runtime_autosave_pending_count"]:
		var flag := String(flag_value)
		result[flag] = session.flags.get(flag)
	return result


func _clear_autosave() -> void:
	_remove_path(AUTOSAVE_PATH)
	var artifacts: Dictionary = SaveService.validation_transaction_artifact_paths(AUTOSAVE_PATH)
	_remove_path(String(artifacts.get("candidate", "")))
	_remove_path(String(artifacts.get("backup", "")))


func _artifacts_absent() -> bool:
	var artifacts: Dictionary = SaveService.validation_transaction_artifact_paths(AUTOSAVE_PATH)
	return not FileAccess.file_exists(String(artifacts.get("candidate", ""))) \
		and not FileAccess.file_exists(String(artifacts.get("backup", "")))


func _tracked_paths() -> Array:
	var paths: Array = [AUTOSAVE_PATH, "%s.candidate" % AUTOSAVE_PATH, "%s.backup" % AUTOSAVE_PATH]
	paths.append_array(ISSUE_PATHS)
	return paths


func _capture_file_states(paths: Array) -> Dictionary:
	var states: Dictionary = {}
	for path_value in paths:
		states[String(path_value)] = _file_state(String(path_value))
	return states


func _file_state(path: String) -> Dictionary:
	return {
		"exists": FileAccess.file_exists(path),
		"bytes": FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray(),
	}


func _read_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


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


func _compact_result(result: Dictionary) -> Dictionary:
	var save_result: Dictionary = result.get("save_result", {}) if result.get("save_result", {}) is Dictionary else {}
	return {
		"ok": result.get("ok", null),
		"saved": result.get("saved", null),
		"routed": result.get("routed", null),
		"reason": result.get("reason", ""),
		"retry_action": result.get("retry_action", ""),
		"message": result.get("message", ""),
		"save_ok": save_result.get("ok", null),
	}


func _compact_router(snapshot: Dictionary) -> Dictionary:
	var issue: Dictionary = snapshot.get("last_runtime_issue", {}) if snapshot.get("last_runtime_issue", {}) is Dictionary else {}
	return {
		"request_count": snapshot.get("request_count", -1),
		"save_attempt_count": snapshot.get("save_attempt_count", -1),
		"save_failure_count": snapshot.get("save_failure_count", -1),
		"route_attempt_count": snapshot.get("route_attempt_count", -1),
		"suppressed_route_count": snapshot.get("suppressed_route_count", -1),
		"last_route": snapshot.get("last_route", {}),
		"issue_event": issue.get("event", ""),
	}


func _compact_shell(snapshot: Dictionary) -> Dictionary:
	return {
		"request_count": snapshot.get("request_count", -1),
		"visible_message": snapshot.get("visible_message", ""),
		"focus_owner": snapshot.get("focus_owner", ""),
		"scenario_id": snapshot.get("scenario_id", ""),
		"resume_target": snapshot.get("resume_target", ""),
		"last_result": _compact_result(snapshot.get("last_result", {}) if snapshot.get("last_result", {}) is Dictionary else {}),
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


func _restore_environment(name: String, value: String) -> void:
	if value == "":
		OS.unset_environment(name)
	else:
		OS.set_environment(name, value)


func _cleanup() -> void:
	OS.unset_environment(FAILURE_ENV)
	AppRouter.validation_set_active_play_return_routing_suppressed(false)
	AppRouter.validation_reset_active_play_return_state()
	for path_value in _tracked_paths():
		_remove_path(String(path_value))
	for path_value in _original_states.keys():
		var state: Dictionary = _original_states.get(path_value, {})
		if bool(state.get("exists", false)):
			_write_bytes(String(path_value), state.get("bytes", PackedByteArray()))
	_restore_environment(FAILURE_ENV, _original_failure_env)
	SaveService.validation_clear_summary_cache()
	SessionState.active_session = _original_active_session
	SessionState.editor_working_copy_session = _original_editor_working_copy
	SessionState._editor_return_pending = _original_editor_return_pending


func _fail_bool(message: String) -> bool:
	_fail(message)
	return false


func _fail(message: String) -> void:
	_cleanup()
	push_error("%s failed: %s" % [REPORT_ID, message])
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "error": message})])
	get_tree().quit(1)
