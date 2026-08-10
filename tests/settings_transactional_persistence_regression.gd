extends Node

const REPORT_ID := "SETTINGS_TRANSACTIONAL_PERSISTENCE_REGRESSION"
const FAILURE_ENV := "HEROES_LIKE_SETTINGS_FAIL_PHASE"
const FrontierVisualKitScript = preload("res://scripts/ui/FrontierVisualKit.gd")

var _original_files: Dictionary = {}
var _original_settings: Dictionary = {}
var _original_failure_env := ""
var _failure_signal_count := 0
var _failure_signal_result: Dictionary = {}


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_original_settings = SettingsService.ensure_settings().duplicate(true)
	_original_failure_env = OS.get_environment(FAILURE_ENV)
	for path in _transaction_paths():
		_original_files[path] = _file_state(path)
	OS.unset_environment(FAILURE_ENV)
	if not SettingsService.settings_commit_failed.is_connected(_on_settings_commit_failed):
		SettingsService.settings_commit_failed.connect(_on_settings_commit_failed)

	var fixture_a := _fixture_settings(false)
	var fixture_b := _fixture_settings(true)
	var fixture_a_capture := _persist_fixture(fixture_a)
	if not _expect(bool(fixture_a_capture.get("ok", false)), "Could not persist fixture A", fixture_a_capture):
		return
	var fixture_b_capture := _persist_fixture(fixture_b)
	if not _expect(bool(fixture_b_capture.get("ok", false)), "Could not persist fixture B", fixture_b_capture):
		return
	var fixture_a_bytes: PackedByteArray = fixture_a_capture.get("bytes", PackedByteArray())
	var fixture_b_bytes: PackedByteArray = fixture_b_capture.get("bytes", PackedByteArray())
	var normalized_a: Dictionary = fixture_a_capture.get("settings", {}).duplicate(true)
	var normalized_b: Dictionary = fixture_b_capture.get("settings", {}).duplicate(true)

	for phase in ["precommit", "after_backup"]:
		for change_id in ["audio", "render", "ui_scale", "theme", "input_map"]:
			if not _validate_injected_failure(phase, change_id, fixture_a):
				return
	if not _validate_non_regular_live_path(fixture_a):
		return

	if not _validate_recovery_matrix(fixture_a_bytes, normalized_a, fixture_b_bytes, normalized_b):
		return
	if not _validate_success_reload(fixture_a):
		return

	_cleanup()
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"failure_phases": ["precommit", "after_backup"],
		"exact_runtime_rollback": true,
		"full_input_map_rollback": true,
		"candidate_never_promoted": true,
		"valid_live_wins": true,
		"valid_backup_recovers": true,
		"parseable_invalid_rejected": true,
		"invalid_backup_fails_closed": true,
		"non_regular_live_path_rejected": true,
		"structured_setter_contract": true,
		"ui_contract_validator_wired": true,
		"settings_version": SettingsService.SETTINGS_VERSION,
	})])
	get_tree().quit(0)


func _fixture_settings(alternate: bool) -> Dictionary:
	var fixture := SettingsService.build_default_settings()
	fixture["audio"]["master_volume_percent"] = 44 if alternate else 31
	fixture["audio"]["music_volume_percent"] = 55 if alternate else 42
	fixture["audio"]["effects_volume_percent"] = 66 if alternate else 53
	fixture["presentation"]["mode"] = SettingsService.PRESENTATION_WINDOWED
	fixture["presentation"]["resolution"] = "1280x720"
	fixture["presentation"]["render_quality"] = SettingsService.RENDER_QUALITY_LOW if alternate else SettingsService.RENDER_QUALITY_BALANCED
	fixture["presentation"]["vsync_enabled"] = not alternate
	fixture["presentation"]["frame_rate_limit"] = 60 if alternate else 0
	fixture["gameplay"]["battle_playback_speed"] = SettingsService.BATTLE_PLAYBACK_SPEED_FAST if alternate else SettingsService.BATTLE_PLAYBACK_SPEED_NORMAL
	fixture["gameplay"]["keyboard_navigation_layout"] = SettingsService.KEYBOARD_NAVIGATION_LAYOUT_IJKL if alternate else SettingsService.KEYBOARD_NAVIGATION_LAYOUT_WASD
	fixture["gameplay"]["hero_movement_bindings"] = {"hero_move_up": KEY_P} if alternate else {}
	fixture["accessibility"]["ui_scale_percent"] = 115 if alternate else 100
	fixture["accessibility"]["large_ui_text"] = alternate
	fixture["accessibility"]["high_contrast_ui"] = alternate
	fixture["accessibility"]["color_cue_mode"] = SettingsService.COLOR_CUE_MODE_ASSISTED if alternate else SettingsService.COLOR_CUE_MODE_STANDARD
	fixture["accessibility"]["battle_camera_shake"] = SettingsService.BATTLE_CAMERA_SHAKE_REDUCED if alternate else SettingsService.BATTLE_CAMERA_SHAKE_FULL
	fixture["accessibility"]["reduce_flashes"] = alternate
	fixture["accessibility"]["reduce_motion"] = alternate
	fixture["accessibility"]["reduce_repetitive_sounds"] = alternate
	return fixture


func _persist_fixture(fixture: Dictionary) -> Dictionary:
	OS.unset_environment(FAILURE_ENV)
	_remove_transaction_files()
	SettingsService.settings = fixture.duplicate(true)
	SettingsService.apply_settings()
	var path := SettingsService.save_settings()
	if path != SettingsService.SETTINGS_FILE:
		return {"ok": false, "result": SettingsService.last_settings_commit_result()}
	SettingsService.settings = {}
	SettingsService.load_settings()
	return {
		"ok": true,
		"bytes": FileAccess.get_file_as_bytes(SettingsService.SETTINGS_FILE),
		"settings": SettingsService.settings.duplicate(true),
	}


func _validate_injected_failure(phase: String, change_id: String, fixture: Dictionary) -> bool:
	var installed := _persist_fixture(fixture)
	if not _expect(bool(installed.get("ok", false)), "Could not reset failure fixture", {"phase": phase, "change": change_id}):
		return false
	var before_bytes := _file_state(SettingsService.SETTINGS_FILE)
	var before_settings := SettingsService.settings.duplicate(true)
	var before_runtime := _runtime_snapshot()
	var before_input := _input_map_snapshot()
	var signal_before := _failure_signal_count
	_failure_signal_result = {}
	OS.set_environment(FAILURE_ENV, phase)
	var result := _invoke_change(change_id)
	OS.unset_environment(FAILURE_ENV)
	var details := {"phase": phase, "change": change_id, "result": _compact_result(result)}
	if not _expect(not bool(result.get("ok", true)), "Injected settings transaction unexpectedly succeeded", details):
		return false
	if not _expect(String(result.get("reason", "")) == phase, "Injected transaction returned the wrong phase reason", details):
		return false
	if not _expect(not bool(result.get("changed", true)) and String(result.get("path", "")) == "", "Failure result claimed a persisted change", details):
		return false
	if not _expect(String(result.get("message", "")) == "Settings could not be saved. Your previous settings remain active.", "Failure result omitted the truthful player message", details):
		return false
	if not _expect(_file_state(SettingsService.SETTINGS_FILE) == before_bytes, "Failure changed live config bytes", details):
		return false
	if not _expect(SettingsService.settings == before_settings, "Failure changed committed settings", _settings_difference(before_settings, SettingsService.settings, details)):
		return false
	if not _expect(_runtime_snapshot() == before_runtime, "Failure changed display/audio/UI/theme runtime", _first_difference(before_runtime, _runtime_snapshot())):
		return false
	if not _expect(_input_map_snapshot() == before_input, "Failure changed managed InputMap events", _first_difference(before_input, _input_map_snapshot())):
		return false
	if not _expect(not FileAccess.file_exists(SettingsService.SETTINGS_CANDIDATE_FILE) and not FileAccess.file_exists(SettingsService.SETTINGS_BACKUP_FILE), "Failure left transaction residue", details):
		return false
	if not _expect(_failure_signal_count == signal_before + 1 and String(_failure_signal_result.get("reason", "")) == phase, "Failure signal did not expose the commit failure", details):
		return false
	if not _expect(_contract_result(SettingsService.last_settings_commit_result()) == _contract_result(result), "last_settings_commit_result did not match the setter failure contract", details):
		return false
	return true


func _validate_non_regular_live_path(fixture: Dictionary) -> bool:
	var installed := _persist_fixture(fixture)
	if not _expect(bool(installed.get("ok", false)), "Could not reset non-regular-path fixture", installed):
		return false
	var before_settings := SettingsService.settings.duplicate(true)
	var before_runtime := _runtime_snapshot()
	var before_input := _input_map_snapshot()
	_remove_path(SettingsService.SETTINGS_FILE)
	var absolute_live := ProjectSettings.globalize_path(SettingsService.SETTINGS_FILE)
	var mkdir_error := DirAccess.make_dir_recursive_absolute(absolute_live)
	if not _expect(mkdir_error == OK or mkdir_error == ERR_ALREADY_EXISTS, "Could not create directory-at-live fixture", {"error": mkdir_error}):
		return false
	var result: Dictionary = SettingsService.set_master_volume_percent(92)
	var details := _compact_result(result)
	if not _expect(not bool(result.get("ok", true)) and String(result.get("reason", "")) == "live_not_regular_file", "Directory-at-live setter did not fail closed", details):
		return false
	if not _expect(DirAccess.dir_exists_absolute(absolute_live), "Directory-at-live setter mutated the live path", details):
		return false
	if not _expect(SettingsService.settings == before_settings and _runtime_snapshot() == before_runtime and _input_map_snapshot() == before_input, "Directory-at-live setter changed committed/runtime/InputMap state", details):
		return false
	if not _expect(_artifacts_absent(), "Directory-at-live setter created transaction artifacts", details):
		return false
	_remove_path(SettingsService.SETTINGS_FILE)
	return true


func _invoke_change(change_id: String) -> Dictionary:
	match change_id:
		"audio":
			return SettingsService.set_master_volume_percent(92)
		"render":
			return SettingsService.set_render_quality_id(SettingsService.RENDER_QUALITY_HIGH)
		"ui_scale":
			return SettingsService.set_ui_scale_percent(115)
		"theme":
			return SettingsService.set_high_contrast_ui_enabled(true)
		"input_map":
			return SettingsService.set_hero_movement_key(&"hero_move_up", KEY_P)
	return {"ok": false, "reason": "unknown_test_change"}


func _validate_recovery_matrix(a_bytes: PackedByteArray, a_settings: Dictionary, b_bytes: PackedByteArray, b_settings: Dictionary) -> bool:
	# A valid live file is authoritative and cleans both stale artifacts.
	_write_bytes(SettingsService.SETTINGS_FILE, a_bytes)
	_write_bytes(SettingsService.SETTINGS_BACKUP_FILE, b_bytes)
	_write_bytes(SettingsService.SETTINGS_CANDIDATE_FILE, b_bytes)
	SettingsService.settings = {}
	SettingsService.load_settings()
	if not _expect(SettingsService.settings == a_settings and FileAccess.get_file_as_bytes(SettingsService.SETTINGS_FILE) == a_bytes, "Valid live settings did not remain authoritative", SettingsService.last_settings_commit_result()):
		return false
	if not _expect(_artifacts_absent(), "Valid live recovery did not clean stale artifacts"):
		return false

	# A missing or corrupt/semantically invalid live file recovers the exact valid backup.
	var invalid_live_cases := {
		"missing": null,
		"corrupt": "[broken\n".to_utf8_buffer(),
		"empty_config": _config_bytes({}),
		"meta_only": _config_bytes({"version": SettingsService.SETTINGS_VERSION}),
		"unknown_version": _config_bytes({"version": SettingsService.SETTINGS_VERSION + 100}),
	}
	for case_id in invalid_live_cases:
		_remove_transaction_files()
		var invalid_bytes: Variant = invalid_live_cases[case_id]
		if invalid_bytes is PackedByteArray:
			_write_bytes(SettingsService.SETTINGS_FILE, invalid_bytes)
		_write_bytes(SettingsService.SETTINGS_BACKUP_FILE, b_bytes)
		_write_bytes(SettingsService.SETTINGS_CANDIDATE_FILE, a_bytes)
		SettingsService.settings = {}
		SettingsService.load_settings()
		var recovery_details := {"case": case_id, "last_result": SettingsService.last_settings_commit_result()}
		if not _expect(SettingsService.settings == b_settings, "Valid backup did not recover expected settings", recovery_details):
			return false
		if not _expect(FileAccess.file_exists(SettingsService.SETTINGS_FILE) and FileAccess.get_file_as_bytes(SettingsService.SETTINGS_FILE) == b_bytes, "Valid backup was not restored byte-exactly", recovery_details):
			return false
		if not _expect(_artifacts_absent(), "Backup recovery left candidate/backup residue", recovery_details):
			return false

	# A candidate is staging only: even a valid candidate is removed, never promoted.
	_remove_transaction_files()
	_write_bytes(SettingsService.SETTINGS_CANDIDATE_FILE, b_bytes)
	SettingsService.settings = {}
	SettingsService.load_settings()
	if not _expect(SettingsService.settings == SettingsService.build_default_settings(), "Candidate-only recovery did not fail closed to defaults", SettingsService.last_settings_commit_result()):
		return false
	if not _expect(not FileAccess.file_exists(SettingsService.SETTINGS_FILE) and _artifacts_absent(), "Candidate-only recovery promoted or retained the candidate"):
		return false

	# Parseable-invalid authority plus an invalid backup remains untouched for diagnosis.
	var invalid_live := _config_bytes({"version": SettingsService.SETTINGS_VERSION})
	var invalid_backup := _config_bytes({"version": SettingsService.SETTINGS_VERSION + 100})
	_remove_transaction_files()
	_write_bytes(SettingsService.SETTINGS_FILE, invalid_live)
	_write_bytes(SettingsService.SETTINGS_BACKUP_FILE, invalid_backup)
	_write_bytes(SettingsService.SETTINGS_CANDIDATE_FILE, b_bytes)
	SettingsService.settings = {}
	SettingsService.load_settings()
	if not _expect(SettingsService.settings == SettingsService.build_default_settings(), "Invalid live/backup did not fail closed to defaults", SettingsService.last_settings_commit_result()):
		return false
	if not _expect(FileAccess.get_file_as_bytes(SettingsService.SETTINGS_FILE) == invalid_live and FileAccess.get_file_as_bytes(SettingsService.SETTINGS_BACKUP_FILE) == invalid_backup, "Invalid backup recovery replaced diagnostic bytes"):
		return false
	if not _expect(not FileAccess.file_exists(SettingsService.SETTINGS_CANDIDATE_FILE), "Invalid recovery retained/promoted its candidate"):
		return false

	# A missing live file plus an empty ConfigFile backup must not create live authority.
	_remove_transaction_files()
	var empty_backup := _config_bytes({})
	_write_bytes(SettingsService.SETTINGS_BACKUP_FILE, empty_backup)
	_write_bytes(SettingsService.SETTINGS_CANDIDATE_FILE, a_bytes)
	SettingsService.settings = {}
	SettingsService.load_settings()
	if not _expect(SettingsService.settings == SettingsService.build_default_settings(), "Empty backup did not fail closed to defaults", SettingsService.last_settings_commit_result()):
		return false
	if not _expect(not FileAccess.file_exists(SettingsService.SETTINGS_FILE) and FileAccess.get_file_as_bytes(SettingsService.SETTINGS_BACKUP_FILE) == empty_backup, "Empty backup created or replaced live settings"):
		return false
	if not _expect(not FileAccess.file_exists(SettingsService.SETTINGS_CANDIDATE_FILE), "Empty-backup recovery retained/promoted its candidate"):
		return false
	return true


func _validate_success_reload(fixture: Dictionary) -> bool:
	var installed := _persist_fixture(fixture)
	if not _expect(bool(installed.get("ok", false)), "Could not install success fixture", installed):
		return false
	var results := [
		SettingsService.set_master_volume_percent(88),
		SettingsService.set_render_quality_id(SettingsService.RENDER_QUALITY_HIGH),
		SettingsService.set_ui_scale_percent(115),
		SettingsService.set_high_contrast_ui_enabled(true),
		SettingsService.set_battle_playback_speed_id(SettingsService.BATTLE_PLAYBACK_SPEED_FAST),
		SettingsService.set_hero_movement_key(&"hero_move_up", KEY_P),
	]
	for result_value in results:
		var result: Dictionary = result_value
		for key in ["ok", "path", "changed", "reason", "message", "settings"]:
			if not _expect(result.has(key), "Structured setter result omitted contract key", {"key": key, "result": _compact_result(result)}):
				return false
		if not _expect(bool(result.get("ok", false)) and String(result.get("path", "")) == SettingsService.SETTINGS_FILE, "Successful setter did not report persisted settings", _compact_result(result)):
			return false
	var saved_settings := SettingsService.settings.duplicate(true)
	var saved_bytes := _file_state(SettingsService.SETTINGS_FILE)
	var saved_runtime := _runtime_snapshot()
	var saved_input := _input_map_snapshot()
	if not _expect(_artifacts_absent(), "Successful settings commits left transaction residue"):
		return false
	var config := ConfigFile.new()
	if not _expect(config.load(SettingsService.SETTINGS_FILE) == OK and int(config.get_value("meta", "version", 0)) == 14, "Successful settings commit did not persist version 14"):
		return false
	SettingsService.settings = {}
	SettingsService.load_settings()
	if not _expect(SettingsService.settings == saved_settings and _file_state(SettingsService.SETTINGS_FILE) == saved_bytes, "Successful settings did not reload exactly", _settings_difference(saved_settings, SettingsService.settings)):
		return false
	if not _expect(_runtime_snapshot() == saved_runtime, "Reload did not restore the successful runtime", _first_difference(saved_runtime, _runtime_snapshot())):
		return false
	if not _expect(_input_map_snapshot() == saved_input, "Reload did not restore the successful InputMap", _first_difference(saved_input, _input_map_snapshot())):
		return false
	return true


func _runtime_snapshot() -> Dictionary:
	var buses := {}
	for bus_index in AudioServer.get_bus_count():
		var bus_name := AudioServer.get_bus_name(bus_index)
		buses[bus_name] = {
			"volume_db": AudioServer.get_bus_volume_db(bus_index),
			"mute": AudioServer.is_bus_mute(bus_index),
			"solo": AudioServer.is_bus_solo(bus_index),
			"bypass_effects": AudioServer.is_bus_bypassing_effects(bus_index),
			"send": AudioServer.get_bus_send(bus_index),
		}
	var service_snapshot: Dictionary = SettingsService.validation_settings_transaction_snapshot()
	return {
		"display": service_snapshot.get("runtime_display", {}).duplicate(true),
		"vsync": DisplayServer.window_get_vsync_mode(),
		"max_fps": Engine.max_fps,
		"msaa_2d": get_tree().root.msaa_2d,
		"ui_scale": get_tree().root.content_scale_factor,
		"high_contrast": FrontierVisualKitScript.high_contrast_enabled(),
		"color_cue_mode": FrontierVisualKitScript.color_cue_mode(),
		"audio_buses": buses,
	}


func _input_map_snapshot() -> Dictionary:
	var action_ids: Array[String] = []
	for action_value in SettingsService.KEYBOARD_NAVIGATION_ACTIONS.keys():
		action_ids.append(String(action_value))
	for action_value in SettingsService.KEYBOARD_HERO_MOVEMENT_ACTIONS.keys():
		var action_id := String(action_value)
		if action_id not in action_ids:
			action_ids.append(action_id)
	action_ids.sort()
	var snapshot := {}
	for action_id in action_ids:
		var action := StringName(action_id)
		var events := []
		if InputMap.has_action(action):
			for input_event in InputMap.action_get_events(action):
				events.append(_serialize_input_event(input_event))
		snapshot[action_id] = {
			"exists": InputMap.has_action(action),
			"deadzone": InputMap.action_get_deadzone(action) if InputMap.has_action(action) else 0.5,
			"events": events,
		}
	return snapshot


func _serialize_input_event(input_event: InputEvent) -> Dictionary:
	var properties := {}
	for property_value in input_event.get_property_list():
		var property: Dictionary = property_value
		if (int(property.get("usage", 0)) & PROPERTY_USAGE_STORAGE) == 0:
			continue
		var name := String(property.get("name", ""))
		if name == "" or name == "script":
			continue
		properties[name] = var_to_str(input_event.get(name))
	return {
		"class": input_event.get_class(),
		"text": input_event.as_text(),
		"properties": properties,
	}


func _config_bytes(meta_values: Dictionary) -> PackedByteArray:
	var config := ConfigFile.new()
	for key in meta_values:
		config.set_value("meta", String(key), meta_values[key])
	return config.encode_to_text().to_utf8_buffer()


func _transaction_paths() -> Array[String]:
	return [
		SettingsService.SETTINGS_FILE,
		SettingsService.SETTINGS_CANDIDATE_FILE,
		SettingsService.SETTINGS_BACKUP_FILE,
	]


func _remove_transaction_files() -> void:
	for path in _transaction_paths():
		_remove_path(path)


func _remove_path(path: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(absolute):
		DirAccess.remove_absolute(absolute)


func _artifacts_absent() -> bool:
	return not _path_exists(SettingsService.SETTINGS_CANDIDATE_FILE) and not _path_exists(SettingsService.SETTINGS_BACKUP_FILE)


func _path_exists(path: String) -> bool:
	return FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path))


func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SettingsService.SETTINGS_DIR))
	_remove_path(path)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_buffer(bytes)
		file.close()


func _file_state(path: String) -> Dictionary:
	return {
		"exists": FileAccess.file_exists(path),
		"directory": DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)),
		"bytes": FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray(),
	}


func _on_settings_commit_failed(result: Dictionary) -> void:
	_failure_signal_count += 1
	_failure_signal_result = result.duplicate(true)


func _compact_result(result: Dictionary) -> Dictionary:
	return {
		"ok": result.get("ok"),
		"path": result.get("path"),
		"changed": result.get("changed"),
		"reason": result.get("reason"),
		"message": result.get("message"),
	}


func _contract_result(result: Dictionary) -> Dictionary:
	var contract := _compact_result(result)
	contract["settings"] = result.get("settings", {})
	return contract


func _settings_difference(expected: Dictionary, actual: Dictionary, context: Dictionary = {}) -> Dictionary:
	var result := context.duplicate(true)
	result["difference"] = _first_difference(expected, actual)
	return result


func _first_difference(expected: Variant, actual: Variant, path: String = "root") -> Dictionary:
	if typeof(expected) != typeof(actual):
		return {"path": path, "expected_type": typeof(expected), "actual_type": typeof(actual)}
	if expected is Dictionary:
		var expected_dict := expected as Dictionary
		var actual_dict := actual as Dictionary
		var keys: Array = expected_dict.keys()
		for key in actual_dict.keys():
			if key not in keys:
				keys.append(key)
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
		for key in keys:
			if not expected_dict.has(key) or not actual_dict.has(key):
				return {"path": "%s.%s" % [path, key], "expected_present": expected_dict.has(key), "actual_present": actual_dict.has(key)}
			var nested := _first_difference(expected_dict[key], actual_dict[key], "%s.%s" % [path, key])
			if not nested.is_empty():
				return nested
		return {}
	if expected is Array:
		var expected_array := expected as Array
		var actual_array := actual as Array
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


func _expect(condition: bool, message: String, details: Variant = {}) -> bool:
	if condition:
		return true
	_fail("%s: %s" % [message, JSON.stringify(details)])
	return false


func _cleanup() -> void:
	OS.unset_environment(FAILURE_ENV)
	_remove_transaction_files()
	for path in _transaction_paths():
		var state: Dictionary = _original_files.get(path, {})
		if bool(state.get("exists", false)):
			_write_bytes(path, state.get("bytes", PackedByteArray()))
		elif bool(state.get("directory", false)):
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))
	SettingsService.settings = _original_settings.duplicate(true)
	SettingsService.apply_settings()
	if _original_failure_env != "":
		OS.set_environment(FAILURE_ENV, _original_failure_env)
	if SettingsService.settings_commit_failed.is_connected(_on_settings_commit_failed):
		SettingsService.settings_commit_failed.disconnect(_on_settings_commit_failed)


func _fail(message: String) -> void:
	_cleanup()
	push_error("%s: %s" % [REPORT_ID, message])
	get_tree().quit(1)
