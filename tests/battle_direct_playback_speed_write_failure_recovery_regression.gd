extends Node

const REPORT_ID := "BATTLE_DIRECT_PLAYBACK_SPEED_WRITE_FAILURE_RECOVERY_REGRESSION"
const FAILURE_ENV := "HEROES_LIKE_SETTINGS_FAIL_PHASE"
const FAILURE_PHASES := ["precommit", "after_backup"]
const FAILURE_MESSAGE := "Playback speed not saved. Previous speed restored."
const DIALOG_FAILURE_PREFIX := "Not saved; previous setting restored."
const BattleShellScene = preload("res://scenes/battle/BattleShell.tscn")

var _original_active_session = null
var _original_failure_env := ""
var _original_settings: Dictionary = {}
var _original_files: Dictionary = {}


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_original_active_session = SessionState.active_session
	_original_failure_env = OS.get_environment(FAILURE_ENV)
	_original_settings = SettingsService.ensure_settings().duplicate(true)
	for path in _transaction_paths():
		_original_files[path] = _file_state(path)
	OS.unset_environment(FAILURE_ENV)

	if not _require_contract():
		return
	if not _install_fast_fixture():
		return
	var session = _battle_fixture("failure-matrix")
	if session == null:
		return
	var shell = await _create_shell(session)
	if shell == null:
		return
	session = SessionState.ensure_active_session()

	var failure_matrix := {}
	for phase_value in FAILURE_PHASES:
		var phase := String(phase_value)
		var row := await _validate_injected_failure(shell, session, phase)
		if row.is_empty():
			return
		failure_matrix[phase] = row

	var non_regular := await _validate_non_regular_live_path(shell, session)
	if non_regular.is_empty():
		return
	var active_play_control := await _validate_active_play_settings_control(shell, session)
	if active_play_control.is_empty():
		return
	var success := await _validate_success_and_fresh_shell(shell, session)
	if success.is_empty():
		return

	_cleanup()
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"failure_matrix": failure_matrix,
		"live_not_regular_file": non_regular,
		"active_play_control": active_play_control,
		"success": success,
		"settings_version": SettingsService.SETTINGS_VERSION,
	})])
	get_tree().quit(0)


func _require_contract() -> bool:
	var shell := BattleShellScene.instantiate()
	for method_name in [
		"validation_set_battle_presentation_speed",
		"validation_reset_battle_playback_speed_state",
		"validation_battle_playback_speed_snapshot",
		"validation_open_active_play_settings",
		"validation_active_play_settings_dialog",
		"validation_snapshot",
	]:
		if not shell.has_method(method_name):
			shell.free()
			return _fail_bool("BattleShell is missing playback validation hook %s." % method_name)
	shell.free()
	if not SettingsService.has_method("validation_settings_transaction_snapshot"):
		return _fail_bool("SettingsService is missing its transaction snapshot hook.")
	return true


func _validate_injected_failure(shell: Node, session, phase: String) -> Dictionary:
	if not await _reset_fast_state(shell, session):
		return {}
	var settings_before := _settings_authority_snapshot()
	var live_before := _file_state(SettingsService.SETTINGS_FILE)
	var session_before := _canonical(session.to_dict())
	var routes_before := _route_snapshot()
	OS.set_environment(FAILURE_ENV, phase)
	var result: Dictionary = shell.validation_set_battle_presentation_speed(SettingsService.BATTLE_PLAYBACK_SPEED_INSTANT)
	OS.unset_environment(FAILURE_ENV)
	await _settle()
	var snapshot: Dictionary = shell.validation_battle_playback_speed_snapshot()
	var details := {"phase": phase, "result": _compact_result(result), "snapshot": _compact_speed_snapshot(snapshot)}
	if not _expect_failure_result(result, phase, details):
		return {}
	if not _expect_failure_surface(shell, snapshot, details):
		return {}
	if not _expect(_file_state(SettingsService.SETTINGS_FILE) == live_before, "Injected failure changed exact live settings bytes", details):
		return {}
	if not _expect(_settings_authority_snapshot() == settings_before, "Injected failure changed settings or committed cache", details):
		return {}
	if not _expect(_transaction_artifacts_absent(), "Injected failure left settings transaction residue", details):
		return {}
	if not _expect(_canonical(session.to_dict()) == session_before, "Injected failure changed battle simulation/session state", _first_difference(session_before, _canonical(session.to_dict()))):
		return {}
	if not _expect(_route_snapshot() == routes_before, "Injected failure changed routing state", _first_difference(routes_before, _route_snapshot())):
		return {}
	return {
		"settings_reason": phase,
		"prior_bytes_exact": true,
		"committed_cache_exact": true,
		"session_exact": true,
		"routes_exact": true,
		"focus_owner": String(snapshot.get("focus_owner", "")),
	}


func _validate_non_regular_live_path(shell: Node, session) -> Dictionary:
	if not await _reset_fast_state(shell, session):
		return {}
	var settings_before := _settings_authority_snapshot()
	var session_before := _canonical(session.to_dict())
	var routes_before := _route_snapshot()
	_remove_path(SettingsService.SETTINGS_FILE)
	var absolute_live := ProjectSettings.globalize_path(SettingsService.SETTINGS_FILE)
	var mkdir_error := DirAccess.make_dir_recursive_absolute(absolute_live)
	if not _expect(mkdir_error == OK or mkdir_error == ERR_ALREADY_EXISTS, "Could not create directory-at-live fixture", {"error": mkdir_error}):
		return {}
	var live_before := _file_state(SettingsService.SETTINGS_FILE)
	var result: Dictionary = shell.validation_set_battle_presentation_speed(SettingsService.BATTLE_PLAYBACK_SPEED_INSTANT)
	await _settle()
	var snapshot: Dictionary = shell.validation_battle_playback_speed_snapshot()
	var details := {"result": _compact_result(result), "snapshot": _compact_speed_snapshot(snapshot)}
	if not _expect_failure_result(result, "live_not_regular_file", details):
		return {}
	if not _expect_failure_surface(shell, snapshot, details):
		return {}
	if not _expect(_file_state(SettingsService.SETTINGS_FILE) == live_before and DirAccess.dir_exists_absolute(absolute_live), "Directory-at-live failure changed the authoritative path", details):
		return {}
	if not _expect(_settings_authority_snapshot() == settings_before, "Directory-at-live failure changed settings or committed cache", details):
		return {}
	if not _expect(_transaction_artifacts_absent(), "Directory-at-live failure created transaction residue", details):
		return {}
	if not _expect(_canonical(session.to_dict()) == session_before and _route_snapshot() == routes_before, "Directory-at-live failure changed battle or route state", details):
		return {}
	_remove_path(SettingsService.SETTINGS_FILE)
	if not _install_fast_fixture():
		return {}
	BattleRules.set_battle_presentation_speed(session, SettingsService.BATTLE_PLAYBACK_SPEED_FAST)
	shell.call("_refresh")
	await _settle()
	return {"reason": "live_not_regular_file", "directory_preserved": true, "session_exact": true, "routes_exact": true}


func _validate_active_play_settings_control(shell: Node, session) -> Dictionary:
	if not await _reset_fast_state(shell, session):
		return {}
	var opened: Dictionary = shell.validation_open_active_play_settings()
	await _settle()
	var dialog = shell.validation_active_play_settings_dialog()
	if not _expect(bool(opened.get("visible", false)) and dialog != null, "ActivePlay settings control did not open", opened):
		return {}
	OS.set_environment(FAILURE_ENV, "precommit")
	var selected_failure := bool(dialog.validation_select_option("BattlePlaybackSpeedPicker", SettingsService.BATTLE_PLAYBACK_SPEED_INSTANT))
	OS.unset_environment(FAILURE_ENV)
	await _settle()
	var dialog_failure: Dictionary = dialog.validation_snapshot()
	var direct_after_failure: Dictionary = shell.validation_battle_playback_speed_snapshot()
	if not _expect(selected_failure, "ActivePlay settings picker could not request Instant", dialog_failure):
		return {}
	if not _expect(String(dialog_failure.get("status", "")).begins_with(DIALOG_FAILURE_PREFIX), "ActivePlay failure did not surface truthful rollback copy", dialog_failure):
		return {}
	if not _expect(String(dialog_failure.get("battle_playback_speed", "")) == SettingsService.BATTLE_PLAYBACK_SPEED_FAST and BattleRules.battle_presentation_speed(session) == BattleRules.PRESENTATION_SPEED_FAST, "ActivePlay failure did not keep committed/session Fast", dialog_failure):
		return {}
	if not _expect(_direct_counts_zero(direct_after_failure), "ActivePlay failure incremented direct-control counters", _compact_speed_snapshot(direct_after_failure)):
		return {}
	var selected_success := bool(dialog.validation_select_option("BattlePlaybackSpeedPicker", SettingsService.BATTLE_PLAYBACK_SPEED_INSTANT))
	await _settle()
	var dialog_success: Dictionary = dialog.validation_snapshot()
	var direct_after_success: Dictionary = shell.validation_battle_playback_speed_snapshot()
	if not _expect(selected_success and String(dialog_success.get("status", "")) == "Saved on this device", "ActivePlay success did not report saved state", dialog_success):
		return {}
	if not _expect(SettingsService.battle_playback_speed_id() == SettingsService.BATTLE_PLAYBACK_SPEED_INSTANT and BattleRules.battle_presentation_speed(session) == BattleRules.PRESENTATION_SPEED_INSTANT, "ActivePlay success did not synchronize the shell session", dialog_success):
		return {}
	if not _expect(_direct_counts_zero(direct_after_success), "ActivePlay success incremented direct-control counters", _compact_speed_snapshot(direct_after_success)):
		return {}
	dialog.close_dialog()
	await _settle()
	return {"failure_truthful": true, "success_synced": true, "direct_control_requests": 0}


func _validate_success_and_fresh_shell(shell: Node, session) -> Dictionary:
	if not await _reset_fast_state(shell, session):
		return {}
	var result: Dictionary = shell.validation_set_battle_presentation_speed(SettingsService.BATTLE_PLAYBACK_SPEED_INSTANT)
	await _settle()
	var snapshot: Dictionary = shell.validation_battle_playback_speed_snapshot()
	var details := {"result": _compact_result(result), "snapshot": _compact_speed_snapshot(snapshot)}
	if not _expect(bool(result.get("ok", false)) and bool(result.get("saved", false)) and bool(result.get("applied", false)) and String(result.get("reason", "")) == "saved", "Direct control success result was not saved/applied", details):
		return {}
	if not _expect(int(snapshot.get("request_count", -1)) == 1 and int(snapshot.get("success_count", -1)) == 1 and int(snapshot.get("failure_count", -1)) == 0, "Direct success did not apply exactly once", details):
		return {}
	if not _expect(_speed_snapshot_is(snapshot, SettingsService.BATTLE_PLAYBACK_SPEED_INSTANT), "Direct success did not align committed/session/UI state", details):
		return {}
	if not _expect(_transaction_artifacts_absent(), "Direct success left settings transaction residue", details):
		return {}
	var successful_bytes := _file_state(SettingsService.SETTINGS_FILE)
	if not _expect(bool(successful_bytes.get("exists", false)) and not PackedByteArray(successful_bytes.get("bytes", PackedByteArray())).is_empty(), "Direct success did not persist settings bytes", successful_bytes):
		return {}

	await _discard_shell(shell)
	SettingsService.settings = {}
	SettingsService.load_settings()
	if not _expect(SettingsService.battle_playback_speed_id() == SettingsService.BATTLE_PLAYBACK_SPEED_INSTANT and _file_state(SettingsService.SETTINGS_FILE) == successful_bytes, "Reload did not retain direct-control Instant bytes/settings", SettingsService.last_settings_commit_result()):
		return {}
	var fresh_session = _battle_fixture("fresh-reload")
	if fresh_session == null:
		return {}
	var fresh_shell = await _create_shell(fresh_session)
	if fresh_shell == null:
		return {}
	var fresh_snapshot: Dictionary = fresh_shell.validation_battle_playback_speed_snapshot()
	if not _expect(_speed_snapshot_is(fresh_snapshot, SettingsService.BATTLE_PLAYBACK_SPEED_INSTANT), "Fresh BattleShell did not consume persisted Instant speed", _compact_speed_snapshot(fresh_snapshot)):
		return {}
	if not _expect(_direct_counts_zero(fresh_snapshot), "Fresh BattleShell fabricated a direct-control request", _compact_speed_snapshot(fresh_snapshot)):
		return {}
	await _discard_shell(fresh_shell)
	return {"request_count": 1, "success_count": 1, "persisted_speed": "instant", "fresh_shell_speed": "instant"}


func _reset_fast_state(shell: Node, session) -> bool:
	OS.unset_environment(FAILURE_ENV)
	if not _install_fast_fixture():
		return false
	var rule_result: Dictionary = BattleRules.set_battle_presentation_speed(session, BattleRules.PRESENTATION_SPEED_FAST)
	if not bool(rule_result.get("ok", false)):
		return _fail_bool("Could not reset active battle to Fast: %s" % JSON.stringify(rule_result))
	shell.call("_refresh")
	shell.validation_reset_battle_playback_speed_state()
	await _settle()
	return true


func _install_fast_fixture() -> bool:
	OS.unset_environment(FAILURE_ENV)
	_remove_transaction_paths()
	var fixture := SettingsService.build_default_settings()
	fixture["gameplay"]["battle_playback_speed"] = SettingsService.BATTLE_PLAYBACK_SPEED_FAST
	SettingsService.settings = fixture.duplicate(true)
	SettingsService.apply_settings()
	var path := SettingsService.save_settings()
	if path != SettingsService.SETTINGS_FILE:
		return _fail_bool("Could not persist Fast settings fixture: %s" % JSON.stringify(SettingsService.last_settings_commit_result()))
	SettingsService.settings = {}
	SettingsService.load_settings()
	return _expect(SettingsService.battle_playback_speed_id() == SettingsService.BATTLE_PLAYBACK_SPEED_FAST and _transaction_artifacts_absent(), "Fast settings fixture did not reload cleanly", SettingsService.last_settings_commit_result())


func _battle_fixture(suffix: String):
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	session.session_id = "%s-direct-speed-%s" % [session.session_id, suffix]
	var encounter := {}
	for value in session.overworld.get("encounters", []):
		if value is Dictionary:
			encounter = value
			break
	if encounter.is_empty():
		_fail("Battle fixture has no authored encounter.")
		return null
	session.battle = BattleRules.create_battle_payload(session, encounter)
	session.game_state = "battle"
	BattleRules.set_battle_presentation_speed(session, BattleRules.PRESENTATION_SPEED_FAST)
	return session


func _create_shell(session) -> Node:
	SessionState.set_active_session(session)
	var shell := BattleShellScene.instantiate()
	add_child(shell)
	await _settle()
	if not is_instance_valid(shell):
		_fail("BattleShell could not be instantiated.")
		return null
	shell.validation_reset_battle_playback_speed_state()
	return shell


func _expect_failure_result(result: Dictionary, settings_reason: String, details: Dictionary) -> bool:
	var nested: Dictionary = result.get("settings_result", {}) if result.get("settings_result", {}) is Dictionary else {}
	return _expect(
		not bool(result.get("ok", true))
			and not bool(result.get("saved", true))
			and not bool(result.get("applied", true))
			and not bool(result.get("changed", true))
			and String(result.get("reason", "")) == "settings_save_failed"
			and String(result.get("settings_reason", "")) == settings_reason
			and String(nested.get("reason", "")) == settings_reason
			and String(result.get("requested_speed", "")) == SettingsService.BATTLE_PLAYBACK_SPEED_INSTANT
			and String(result.get("committed_speed", "")) == SettingsService.BATTLE_PLAYBACK_SPEED_FAST
			and String(result.get("active_speed", "")) == BattleRules.PRESENTATION_SPEED_FAST
			and String(result.get("session_speed", "")) == BattleRules.PRESENTATION_SPEED_FAST
			and String(result.get("message", "")) == FAILURE_MESSAGE,
		"Direct speed failure returned a dishonest result",
		details
	)


func _expect_failure_surface(shell: Node, snapshot: Dictionary, details: Dictionary) -> bool:
	var buttons: Dictionary = snapshot.get("button_states", {}) if snapshot.get("button_states", {}) is Dictionary else {}
	var fast: Dictionary = buttons.get("fast", {}) if buttons.get("fast", {}) is Dictionary else {}
	var instant: Dictionary = buttons.get("instant", {}) if buttons.get("instant", {}) is Dictionary else {}
	var broad: Dictionary = shell.validation_snapshot()
	return _expect(
		int(snapshot.get("request_count", -1)) == 1
			and int(snapshot.get("success_count", -1)) == 0
			and int(snapshot.get("failure_count", -1)) == 1
			and _speed_snapshot_is(snapshot, SettingsService.BATTLE_PLAYBACK_SPEED_FAST)
			and bool(fast.get("selected", false))
			and bool(fast.get("disabled", false))
			and not bool(instant.get("selected", true))
			and not bool(instant.get("disabled", true))
			and String(snapshot.get("focus_owner", "")) == "SpeedInstant"
			and String(broad.get("event_visible_text", "")).contains(FAILURE_MESSAGE),
		"Direct speed failure did not restore committed UI/message/focus",
		details
	)


func _speed_snapshot_is(snapshot: Dictionary, speed: String) -> bool:
	return String(snapshot.get("active_speed", "")) == speed \
		and String(snapshot.get("session_speed", "")) == speed \
		and String(snapshot.get("committed_speed", "")) == speed \
		and String(snapshot.get("settings_speed", "")) == speed \
		and String(snapshot.get("selected_speed", "")) == speed


func _direct_counts_zero(snapshot: Dictionary) -> bool:
	return int(snapshot.get("request_count", -1)) == 0 and int(snapshot.get("success_count", -1)) == 0 and int(snapshot.get("failure_count", -1)) == 0


func _settings_authority_snapshot() -> Dictionary:
	var snapshot: Dictionary = SettingsService.validation_settings_transaction_snapshot()
	return {
		"settings": snapshot.get("settings", {}).duplicate(true),
		"committed_settings": snapshot.get("committed_settings", {}).duplicate(true),
	}


func _route_snapshot() -> Dictionary:
	return _canonical({
		"active_return": AppRouter.validation_active_play_return_snapshot(),
		"battle_entry": AppRouter.validation_battle_entry_snapshot(),
		"battle_resolution": AppRouter.validation_battle_resolution_checkpoint_snapshot(),
		"scenario_outcome": AppRouter.validation_scenario_outcome_route_snapshot(),
		"safe_quit": AppRouter.validation_safe_quit_snapshot(),
	})


func _transaction_paths() -> Array[String]:
	return [SettingsService.SETTINGS_FILE, SettingsService.SETTINGS_CANDIDATE_FILE, SettingsService.SETTINGS_BACKUP_FILE]


func _transaction_artifacts_absent() -> bool:
	return not _path_exists(SettingsService.SETTINGS_CANDIDATE_FILE) and not _path_exists(SettingsService.SETTINGS_BACKUP_FILE)


func _remove_transaction_paths() -> void:
	for path in _transaction_paths():
		_remove_path(path)


func _path_exists(path: String) -> bool:
	return FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path))


func _file_state(path: String) -> Dictionary:
	return {
		"exists": FileAccess.file_exists(path),
		"directory": DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)),
		"bytes": FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray(),
	}


func _remove_path(path: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(absolute):
		DirAccess.remove_absolute(absolute)


func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	_remove_path(path)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_buffer(bytes)
		file.close()


func _canonical(value: Variant) -> Dictionary:
	var parsed: Variant = JSON.parse_string(JSON.stringify(value))
	return parsed if parsed is Dictionary else {}


func _first_difference(expected: Variant, actual: Variant, path: String = "$") -> Dictionary:
	if typeof(expected) != typeof(actual):
		return {"path": path, "expected_type": type_string(typeof(expected)), "actual_type": type_string(typeof(actual))}
	if expected is Dictionary:
		var expected_dictionary: Dictionary = expected
		var actual_dictionary: Dictionary = actual
		var keys: Array = expected_dictionary.keys()
		for key in actual_dictionary.keys():
			if key not in keys:
				keys.append(key)
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
		for key in keys:
			if not expected_dictionary.has(key) or not actual_dictionary.has(key):
				return {"path": "%s.%s" % [path, key], "expected_present": expected_dictionary.has(key), "actual_present": actual_dictionary.has(key)}
			var nested := _first_difference(expected_dictionary[key], actual_dictionary[key], "%s.%s" % [path, key])
			if not nested.is_empty():
				return nested
		return {}
	if expected is Array:
		var expected_array: Array = expected
		var actual_array: Array = actual
		if expected_array.size() != actual_array.size():
			return {"path": path, "expected_size": expected_array.size(), "actual_size": actual_array.size()}
		for index in expected_array.size():
			var nested := _first_difference(expected_array[index], actual_array[index], "%s[%d]" % [path, index])
			if not nested.is_empty():
				return nested
		return {}
	if expected != actual:
		return {"path": path, "expected": var_to_str(expected), "actual": var_to_str(actual)}
	return {}


func _compact_result(result: Dictionary) -> Dictionary:
	return {
		"ok": result.get("ok", null),
		"saved": result.get("saved", null),
		"applied": result.get("applied", null),
		"changed": result.get("changed", null),
		"reason": result.get("reason", ""),
		"settings_reason": result.get("settings_reason", ""),
		"requested_speed": result.get("requested_speed", ""),
		"committed_speed": result.get("committed_speed", ""),
		"active_speed": result.get("active_speed", ""),
		"message": result.get("message", ""),
	}


func _compact_speed_snapshot(snapshot: Dictionary) -> Dictionary:
	return {
		"request": snapshot.get("request_count", -1),
		"success": snapshot.get("success_count", -1),
		"failure": snapshot.get("failure_count", -1),
		"requested": snapshot.get("requested_speed", ""),
		"active": snapshot.get("active_speed", ""),
		"session": snapshot.get("session_speed", ""),
		"committed": snapshot.get("committed_speed", ""),
		"selected": snapshot.get("selected_speed", ""),
		"focus": snapshot.get("focus_owner", ""),
		"buttons": snapshot.get("button_states", {}),
	}


func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame


func _discard_shell(shell: Node) -> void:
	if is_instance_valid(shell):
		shell.queue_free()
	await _settle()


func _expect(condition: bool, message: String, details: Variant = {}) -> bool:
	if condition:
		return true
	_fail("%s: %s" % [message, JSON.stringify(details)])
	return false


func _fail_bool(message: String) -> bool:
	_fail(message)
	return false


func _fail(message: String) -> void:
	_cleanup()
	push_error("%s failed: %s" % [REPORT_ID, message])
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "error": message})])
	get_tree().quit(1)


func _cleanup() -> void:
	OS.unset_environment(FAILURE_ENV)
	_remove_transaction_paths()
	for path_value in _original_files.keys():
		var path := String(path_value)
		var state: Dictionary = _original_files.get(path, {})
		if bool(state.get("exists", false)):
			_write_bytes(path, state.get("bytes", PackedByteArray()))
		elif bool(state.get("directory", false)):
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))
	SettingsService.settings = _original_settings.duplicate(true)
	SettingsService.apply_settings()
	SessionState.active_session = _original_active_session
	if _original_failure_env != "":
		OS.set_environment(FAILURE_ENV, _original_failure_env)
