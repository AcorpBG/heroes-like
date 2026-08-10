extends Node

const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")

const REPORT_ID := "APPLICATION_SAFE_CLOSE_AUTOSAVE_REGRESSION"
const FAILURE_ENV := "HEROES_LIKE_SAVE_FAIL_PHASE"
const EXPLICIT_QUIT_PROBE_ARG := "application-safe-close-explicit-quit-probe"
const EXPLICIT_QUIT_CODE := 37
const AUTOSAVE_PATH := "user://saves/autosave.json"
const ISSUE_PATHS := [
	"user://debug/heroes_runtime_issues.jsonl",
	"user://debug/heroes_last_runtime_issue.json",
	"user://debug/heroes_runtime_session.json",
	"user://debug/heroes_runtime_session.tmp",
]
const TRANSITION_INTENT_FLAGS := [
	"runtime_autosave_dirty",
	"runtime_autosave_pending_intent",
	"runtime_autosave_pending_reason",
	"runtime_autosave_pending_route",
	"runtime_autosave_pending_game_state",
	"runtime_autosave_pending_unix",
]

var _original_states := {}
var _original_failure_env := ""
var _original_active_session = null


func _ready() -> void:
	if EXPLICIT_QUIT_PROBE_ARG in OS.get_cmdline_user_args():
		get_tree().quit(EXPLICIT_QUIT_CODE)
		return
	call_deferred("_run")


func _run() -> void:
	_original_states = _capture_file_states(_tracked_paths())
	_original_failure_env = OS.get_environment(FAILURE_ENV)
	_original_active_session = SessionState.active_session
	OS.unset_environment(FAILURE_ENV)
	if not _require_hooks():
		return
	AppRouter.validation_set_quit_suppressed(true)
	if get_tree().auto_accept_quit:
		_fail("SceneTree.auto_accept_quit must be disabled so WM close can use the safe path.")
		return
	var active_states := _validate_active_state_snapshots()
	if active_states.is_empty():
		return
	var failure_retry := _validate_failed_save_remains_open_and_retries()
	if failure_retry.is_empty():
		return
	var no_session := _validate_no_session_quit()
	if no_session.is_empty():
		return
	var reentrant := _validate_reentrant_and_completed_guards()
	if reentrant.is_empty():
		return
	var window_close := _validate_window_close_notification()
	if window_close.is_empty():
		return
	var main_menu := _validate_main_menu_delegation()
	if main_menu.is_empty():
		return
	var explicit_quit := _validate_explicit_scene_tree_quit()
	if explicit_quit.is_empty():
		return
	_cleanup()
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"active_states": active_states,
		"failure_retry": failure_retry,
		"no_session": no_session,
		"reentrant": reentrant,
		"window_close": window_close,
		"main_menu": main_menu,
		"explicit_scene_tree_quit": explicit_quit,
		"auto_accept_quit": false,
		"save_version": SessionState.SAVE_VERSION,
	})])
	get_tree().quit(0)


func _require_hooks() -> bool:
	for method_name in [
		"request_safe_quit",
		"validation_set_quit_suppressed",
		"validation_reset_safe_quit_state",
		"validation_set_safe_quit_reentrant_probe",
		"validation_safe_quit_snapshot",
	]:
		if not AppRouter.has_method(method_name):
			return _fail_bool("AppRouter is missing safe-close hook %s." % method_name)
	if not SaveService.has_method("validation_summary_cache_snapshot") \
			or not SaveService.has_method("validation_clear_summary_cache") \
			or not SaveService.has_method("validation_transaction_artifact_paths"):
		return _fail_bool("SaveService transaction validation hooks are unavailable.")
	return true


func _validate_active_state_snapshots() -> Dictionary:
	var rows := {}
	for game_state in ["overworld", "town", "battle"]:
		_clear_autosave()
		SaveService.validation_clear_summary_cache()
		var session = _session_for_state(game_state, 10 + rows.size())
		if session == null:
			_fail("Could not construct a valid %s safe-close fixture." % game_state)
			return {}
		_add_transition_intent(session, game_state)
		SessionState.active_session = session
		var before := _canonical_dictionary(session.to_dict())
		_reset_router()
		var result: Dictionary = AppRouter.request_safe_quit("validation_%s" % game_state)
		var snapshot: Dictionary = AppRouter.validation_safe_quit_snapshot()
		var saved := _read_dictionary(AUTOSAVE_PATH)
		var restored = SaveService.restore_autosave_session()
		if not bool(result.get("ok", false)) or not bool(result.get("saved", false)):
			_fail("%s close did not save successfully: %s" % [game_state, JSON.stringify(_compact_result(result))])
			return {}
		if int(snapshot.get("save_attempt_count", -1)) != 1 \
				or int(snapshot.get("quit_attempt_count", -1)) != 1 \
				or int(snapshot.get("suppressed_quit_count", -1)) != 1:
			_fail("%s close did not produce exactly one save and one suppressed quit: %s" % [game_state, JSON.stringify(_compact_snapshot(snapshot))])
			return {}
		if not bool(snapshot.get("completed", false)) or bool(snapshot.get("in_progress", true)):
			_fail("%s close did not leave a terminal completed guard." % game_state)
			return {}
		var expected_after := before.duplicate(true)
		var expected_flags: Dictionary = expected_after.get("flags", {})
		for key in TRANSITION_INTENT_FLAGS:
			expected_flags.erase(key)
		expected_after["flags"] = expected_flags
		var live_after := _canonical_dictionary(session.to_dict())
		var saved_session := _canonical_dictionary(SessionStateStoreScript.normalize_payload(saved))
		if live_after != expected_after or saved_session != expected_after:
			_fail("%s close payload/live parity failed: %s" % [game_state, JSON.stringify({
				"signature": _payload_signature(expected_after, live_after, saved_session),
				"live_diff": _first_difference(expected_after, live_after),
				"saved_diff": _first_difference(expected_after, saved_session),
			})])
			return {}
		var restored_payload := _canonical_dictionary(restored.to_dict()) if restored != null else {}
		if restored == null \
				or _session_signature(restored_payload) != _session_signature(expected_after) \
				or SaveService.resume_target_for_session(restored) != game_state:
			_fail("%s close autosave did not restore its exact route/signature: %s" % [game_state, JSON.stringify({
				"restored": restored != null,
				"expected": _session_signature(expected_after),
				"actual": _session_signature(restored_payload),
				"resume_target": SaveService.resume_target_for_session(restored) if restored != null else "",
			})])
			return {}
		if not _artifacts_absent():
			_fail("%s close left save transaction artifacts." % game_state)
			return {}
		rows[game_state] = {
			"saved_exact": true,
			"live_commit_exact": true,
			"restored_route_exact": true,
			"save_attempts": 1,
			"quit_attempts": 1,
			"transition_intent_cleared_after_commit": true,
		}
	return rows


func _validate_failed_save_remains_open_and_retries() -> Dictionary:
	_clear_autosave()
	SaveService.validation_clear_summary_cache()
	var prior := _session_for_state("overworld", 21)
	prior.flags["safe_close_marker"] = "prior"
	if not bool(SaveService.save_runtime_autosave_session(prior).get("ok", false)):
		_fail("Could not seed prior autosave for safe-close failure.")
		return {}
	SaveService.inspect_autosave()
	var bytes_before := _file_state(AUTOSAVE_PATH)
	var cache_before: Dictionary = SaveService.validation_summary_cache_snapshot()
	var live := _session_for_state("town", 22)
	_add_transition_intent(live, "failure")
	live.flags["safe_close_marker"] = "failed_live"
	SessionState.active_session = live
	var live_before := _canonical_dictionary(live.to_dict())
	var issue_count_before := RuntimeIssueLog.issue_record_count()
	_reset_router()
	OS.set_environment(FAILURE_ENV, "precommit")
	var failed: Dictionary = AppRouter.request_safe_quit("validation_failure")
	OS.unset_environment(FAILURE_ENV)
	var failed_snapshot: Dictionary = AppRouter.validation_safe_quit_snapshot()
	if bool(failed.get("ok", true)) or String(failed.get("reason", "")) != "autosave_failed" \
			or bool(failed.get("quit_requested", true)):
		_fail("Injected safe-close failure returned the wrong contract: %s" % JSON.stringify(_compact_result(failed)))
		return {}
	if int(failed_snapshot.get("save_attempt_count", -1)) != 1 \
			or int(failed_snapshot.get("quit_attempt_count", -1)) != 0 \
			or int(failed_snapshot.get("suppressed_quit_count", -1)) != 0 \
			or bool(failed_snapshot.get("completed", true)) \
			or bool(failed_snapshot.get("in_progress", true)):
		_fail("Injected safe-close failure did not remain open/retryable: %s" % JSON.stringify(_compact_snapshot(failed_snapshot)))
		return {}
	if _file_state(AUTOSAVE_PATH) != bytes_before \
			or SaveService.validation_summary_cache_snapshot() != cache_before \
			or _canonical_dictionary(live.to_dict()) != live_before \
			or not _artifacts_absent():
		_fail("Injected safe-close failure changed prior bytes/cache/live intent or left artifacts.")
		return {}
	var latest_failure := _latest_safe_close_failure(issue_count_before)
	if latest_failure.is_empty() or String(failed_snapshot.get("visible_error", "")) == "" \
			or String(failed_snapshot.get("visible_error", "")) != String(failed.get("message", "")):
		_fail("Safe-close failure did not emit its runtime issue and visible error: %s" % JSON.stringify({
			"issue_event": latest_failure.get("event", ""),
			"visible_error": failed_snapshot.get("visible_error", ""),
			"result_message": failed.get("message", ""),
		}))
		return {}
	var retry: Dictionary = AppRouter.request_safe_quit("validation_failure_retry")
	var retry_snapshot: Dictionary = AppRouter.validation_safe_quit_snapshot()
	if not bool(retry.get("ok", false)) \
			or int(retry_snapshot.get("save_attempt_count", -1)) != 2 \
			or int(retry_snapshot.get("quit_attempt_count", -1)) != 1 \
			or not bool(retry_snapshot.get("completed", false)):
		_fail("Safe-close failure guard did not clear for a successful retry: %s" % JSON.stringify(_compact_snapshot(retry_snapshot)))
		return {}
	return {
		"prior_bytes_exact_on_failure": true,
		"summary_cache_exact_on_failure": true,
		"live_intent_exact_on_failure": true,
		"zero_quit_on_failure": true,
		"runtime_issue_recorded": true,
		"visible_error": true,
		"retry_succeeded": true,
	}


func _validate_no_session_quit() -> Dictionary:
	SessionState.reset_session()
	_reset_router()
	var result: Dictionary = AppRouter.request_safe_quit("validation_no_session")
	var snapshot: Dictionary = AppRouter.validation_safe_quit_snapshot()
	if not bool(result.get("ok", false)) or bool(result.get("saved", true)) \
			or int(snapshot.get("save_attempt_count", -1)) != 0 \
			or int(snapshot.get("quit_attempt_count", -1)) != 1 \
			or int(snapshot.get("suppressed_quit_count", -1)) != 1:
		_fail("No-session close did not directly attempt exactly one suppressed quit: %s" % JSON.stringify(_compact_snapshot(snapshot)))
		return {}
	return {"saved": false, "quit_attempts": 1, "direct": true}


func _validate_reentrant_and_completed_guards() -> Dictionary:
	_clear_autosave()
	SessionState.active_session = _session_for_state("overworld", 30)
	_reset_router()
	AppRouter.validation_set_safe_quit_reentrant_probe(true)
	var result: Dictionary = AppRouter.request_safe_quit("validation_reentrant_outer")
	var first: Dictionary = AppRouter.validation_safe_quit_snapshot()
	AppRouter.validation_set_safe_quit_reentrant_probe(false)
	var nested: Dictionary = first.get("reentrant_result", {}) if first.get("reentrant_result", {}) is Dictionary else {}
	if not bool(result.get("ok", false)) or bool(nested.get("ok", true)) \
			or String(nested.get("reason", "")) != "in_progress" \
			or int(first.get("save_attempt_count", -1)) != 1 \
			or int(first.get("quit_attempt_count", -1)) != 1:
		_fail("Reentrant close was not idempotently rejected: %s" % JSON.stringify({
			"outer": _compact_result(result),
			"nested": _compact_result(nested),
			"snapshot": _compact_snapshot(first),
		}))
		return {}
	var second_result: Dictionary = AppRouter.request_safe_quit("validation_completed_repeat")
	var second: Dictionary = AppRouter.validation_safe_quit_snapshot()
	if bool(second_result.get("ok", true)) or String(second_result.get("reason", "")) != "completed" \
			or int(second.get("save_attempt_count", -1)) != 1 \
			or int(second.get("quit_attempt_count", -1)) != 1:
		_fail("Completed close guard allowed a second save/quit: %s" % JSON.stringify(_compact_snapshot(second)))
		return {}
	return {"nested_reason": "in_progress", "completed_reason": "completed", "save_attempts": 1, "quit_attempts": 1}


func _validate_window_close_notification() -> Dictionary:
	_clear_autosave()
	SessionState.active_session = _session_for_state("overworld", 40)
	_reset_router()
	get_tree().root.close_requested.emit()
	var snapshot: Dictionary = AppRouter.validation_safe_quit_snapshot()
	if String(snapshot.get("last_source", "")) != "window_close" \
			or int(snapshot.get("save_attempt_count", -1)) != 1 \
			or int(snapshot.get("quit_attempt_count", -1)) != 1 \
			or not bool(snapshot.get("completed", false)):
		_fail("Root Window close_requested did not use the safe-close path: %s" % JSON.stringify(_compact_snapshot(snapshot)))
		return {}
	return {"source": "window_close", "root_signal_connected": true, "saved": true, "quit_attempts": 1}


func _validate_main_menu_delegation() -> Dictionary:
	_clear_autosave()
	SessionState.active_session = _session_for_state("overworld", 50)
	_reset_router()
	var menu = load("res://scenes/menus/MainMenu.gd").new()
	if not menu.has_method("validation_request_safe_quit"):
		menu.free()
		_fail("MainMenu is missing validation_request_safe_quit delegation hook.")
		return {}
	var result: Dictionary = menu.call("validation_request_safe_quit")
	var snapshot: Dictionary = AppRouter.validation_safe_quit_snapshot()
	menu.free()
	if not bool(result.get("ok", false)) or String(snapshot.get("last_source", "")) != "main_menu" \
			or int(snapshot.get("save_attempt_count", -1)) != 1 \
			or int(snapshot.get("quit_attempt_count", -1)) != 1:
		_fail("MainMenu Exit did not delegate to AppRouter safe close: %s" % JSON.stringify(_compact_snapshot(snapshot)))
		return {}
	return {"source": "main_menu", "saved": true, "quit_attempts": 1}


func _validate_explicit_scene_tree_quit() -> Dictionary:
	var child_data_home := OS.get_temp_dir().path_join("heroes-safe-close-child-%d-%d" % [OS.get_process_id(), Time.get_ticks_msec()])
	var prior_xdg_data := OS.get_environment("XDG_DATA_HOME")
	var prior_xdg_config := OS.get_environment("XDG_CONFIG_HOME")
	OS.set_environment("XDG_DATA_HOME", child_data_home)
	OS.set_environment("XDG_CONFIG_HOME", child_data_home.path_join("config"))
	var output: Array = []
	var arguments := PackedStringArray([
		"--headless",
		"--path",
		ProjectSettings.globalize_path("res://"),
		"tests/application_safe_close_autosave_regression.tscn",
		"--",
		EXPLICIT_QUIT_PROBE_ARG,
	])
	var exit_code := OS.execute(OS.get_executable_path(), arguments, output, true)
	_restore_environment("XDG_DATA_HOME", prior_xdg_data)
	_restore_environment("XDG_CONFIG_HOME", prior_xdg_config)
	if exit_code != EXPLICIT_QUIT_CODE:
		_fail("Explicit SceneTree.quit child exited %d instead of %d: %s" % [exit_code, EXPLICIT_QUIT_CODE, _compact_child_output(output)])
		return {}
	var child_debug_dir := child_data_home.path_join("godot/app_userdata/heroes-like/debug")
	var child_marker_path := child_debug_dir.path_join(String(RuntimeIssueLog.SESSION_MARKER_PATH).get_file())
	var child_marker_temp_path := child_debug_dir.path_join(String(RuntimeIssueLog.SESSION_MARKER_TEMP_PATH).get_file())
	if FileAccess.file_exists(child_marker_path) or FileAccess.file_exists(child_marker_temp_path):
		_fail("Explicit SceneTree.quit child left a RuntimeIssueLog session marker.")
		return {}
	return {"exit_code": exit_code, "runtime_marker_removed": true}


func _session_for_state(game_state: String, day: int) -> SessionStateStoreScript.SessionData:
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	session.day = day
	session.flags["safe_close_marker"] = "%s_%d" % [game_state, day]
	match game_state:
		"town":
			var town := _first_player_town(session)
			if town.is_empty():
				return null
			_move_active_hero_to_town(session, town)
			var visit: Dictionary = OverworldRules.set_active_town_visit(session, String(town.get("placement_id", "")))
			if not bool(visit.get("ok", false)):
				return null
			session.game_state = "town"
		"battle":
			var encounter := _first_encounter(session)
			if encounter.is_empty():
				return null
			session.battle = BattleRulesScript.create_battle_payload(session, encounter)
			if session.battle.is_empty():
				return null
			session.game_state = "battle"
		_:
			session.game_state = "overworld"
	OverworldRules.normalize_overworld_state(session)
	return session


func _first_player_town(session) -> Dictionary:
	for town_value in session.overworld.get("towns", []):
		if town_value is Dictionary and String(town_value.get("owner", "")) == "player":
			return town_value
	return {}


func _move_active_hero_to_town(session, town: Dictionary) -> void:
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


func _first_encounter(session) -> Dictionary:
	for encounter_value in session.overworld.get("encounters", []):
		if encounter_value is Dictionary:
			return encounter_value
	return {}


func _add_transition_intent(session, label: String) -> void:
	session.flags["runtime_autosave_dirty"] = true
	session.flags["runtime_autosave_pending_intent"] = true
	session.flags["runtime_autosave_pending_reason"] = "safe_close_%s" % label
	session.flags["runtime_autosave_pending_route"] = String(session.game_state)
	session.flags["runtime_autosave_pending_game_state"] = String(session.game_state)
	session.flags["runtime_autosave_pending_unix"] = 10184
	OverworldRules.mark_runtime_normalized_transition_state(session)


func _reset_router() -> void:
	AppRouter.validation_set_quit_suppressed(true)
	AppRouter.validation_reset_safe_quit_state()
	AppRouter.validation_set_safe_quit_reentrant_probe(false)


func _latest_safe_close_failure(previous_count: int) -> Dictionary:
	if RuntimeIssueLog.issue_record_count() <= previous_count:
		return {}
	for record_value in RuntimeIssueLog.last_issue_records(8):
		if record_value is Dictionary and String(record_value.get("event", "")) == "safe_quit_autosave_failed":
			return record_value
	return {}


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
	var states := {}
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


func _remove_path(path: String) -> void:
	if path != "" and FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _write_bytes(path: String, bytes: PackedByteArray) -> bool:
	if path == "":
		return false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(bytes)
	file.close()
	return true


func _payload_signature(expected: Dictionary, live: Dictionary, saved: Dictionary) -> Dictionary:
	return {
		"expected": _session_signature(expected),
		"live": _session_signature(live),
		"saved": _session_signature(saved),
	}


func _session_signature(payload: Dictionary) -> Dictionary:
	var flags: Dictionary = payload.get("flags", {}) if payload.get("flags", {}) is Dictionary else {}
	return {
		"scenario_id": payload.get("scenario_id", ""),
		"day": payload.get("day", 0),
		"game_state": payload.get("game_state", ""),
		"battle_active": not (payload.get("battle", {}) as Dictionary).is_empty() if payload.get("battle", {}) is Dictionary else false,
		"active_town": flags.get("active_town_placement_id", ""),
		"marker": flags.get("safe_close_marker", ""),
		"pending_intent": flags.get("runtime_autosave_pending_intent", false),
	}


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
		"ok": result.get("ok", false),
		"saved": result.get("saved", false),
		"quit_requested": result.get("quit_requested", false),
		"source": result.get("source", ""),
		"reason": result.get("reason", ""),
		"message": result.get("message", ""),
	}


func _compact_snapshot(snapshot: Dictionary) -> Dictionary:
	return {
		"request_count": snapshot.get("request_count", -1),
		"save_attempt_count": snapshot.get("save_attempt_count", -1),
		"quit_attempt_count": snapshot.get("quit_attempt_count", -1),
		"suppressed_quit_count": snapshot.get("suppressed_quit_count", -1),
		"in_progress": snapshot.get("in_progress", null),
		"completed": snapshot.get("completed", null),
		"last_source": snapshot.get("last_source", ""),
		"visible_error": snapshot.get("visible_error", ""),
	}


func _compact_child_output(output: Array) -> String:
	var joined := "\n".join(output)
	return joined.substr(maxi(0, joined.length() - 600), 600)


func _restore_environment(name: String, value: String) -> void:
	if value == "":
		OS.unset_environment(name)
	else:
		OS.set_environment(name, value)


func _cleanup() -> void:
	OS.unset_environment(FAILURE_ENV)
	AppRouter.validation_set_safe_quit_reentrant_probe(false)
	for path_value in _tracked_paths():
		_remove_path(String(path_value))
	for path_value in _original_states.keys():
		var state: Dictionary = _original_states.get(path_value, {})
		if bool(state.get("exists", false)):
			_write_bytes(String(path_value), state.get("bytes", PackedByteArray()))
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
