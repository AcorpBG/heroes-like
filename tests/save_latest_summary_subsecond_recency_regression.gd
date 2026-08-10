extends Node

const REPORT_ID := "SAVE_LATEST_SUMMARY_SUBSECOND_RECENCY_REGRESSION"
const AUTOSAVE_PATH := "user://saves/autosave.json"
const MANUAL_PATH := "user://saves/slot1.json"

var _original_session = null
var _original_slot := 1
var _original_files := {}


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_original_session = SessionState.active_session
	_original_slot = SaveService.get_selected_manual_slot()
	_original_files = _capture_files(_tracked_paths())
	_clear_fixture_paths()
	AppRouter.validation_set_scenario_outcome_routing_suppressed(true)
	AppRouter.validation_reset_scenario_outcome_route_state()

	var manual_newer: Dictionary = await _prove_pair(
		"manual_subsecond_newer",
		1000.1,
		1000.9,
		SaveService.SLOT_TYPE_MANUAL,
		19
	)
	if manual_newer.is_empty():
		return
	var autosave_newer: Dictionary = await _prove_pair(
		"autosave_subsecond_newer",
		1000.9,
		1000.1,
		SaveService.SLOT_TYPE_AUTOSAVE,
		29
	)
	if autosave_newer.is_empty():
		return
	var legacy: Dictionary = await _prove_integer_legacy()
	if legacy.is_empty():
		return
	var modified_fallback: Dictionary = await _prove_modified_time_legacy()
	if modified_fallback.is_empty():
		return

	_cleanup()
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"manual_newer": manual_newer,
		"autosave_newer": autosave_newer,
		"legacy": legacy,
		"modified_fallback": modified_fallback,
		"display_unchanged": true,
		"inspection_writes": 0,
		"save_version": SessionState.SAVE_VERSION,
	})])
	get_tree().quit(0)


func _prove_pair(
	label: String,
	autosave_timestamp: float,
	manual_timestamp: float,
	expected_slot_type: String,
	expected_day: int
) -> Dictionary:
	_seed_pair(autosave_timestamp, manual_timestamp, 29, 19)
	SaveService.validation_clear_summary_cache()
	var disk_before: Dictionary = _fixture_disk_signature()

	var cold_latest: Dictionary = SaveService.latest_loadable_summary()
	if not _summary_matches(cold_latest, expected_slot_type, expected_day):
		return _fail_dictionary("%s cold latest mismatch: %s" % [label, JSON.stringify(cold_latest)])
	var expected_timestamp := manual_timestamp if expected_slot_type == SaveService.SLOT_TYPE_MANUAL else autosave_timestamp
	if not is_equal_approx(float(cold_latest.get("recorded_timestamp_precise", 0.0)), expected_timestamp) \
			or not is_equal_approx(SaveService.summary_recency_timestamp(cold_latest), expected_timestamp):
		return _fail_dictionary("%s lost precise recency: %s" % [label, JSON.stringify(cold_latest)])
	var cache_after_cold: Dictionary = SaveService.validation_summary_cache_snapshot()
	if cache_after_cold.is_empty() or _fixture_disk_signature() != disk_before:
		return _fail_dictionary("%s cold inspection changed disk or failed to populate cache." % label)

	var warm_latest: Dictionary = SaveService.latest_loadable_summary()
	if not _summary_matches(warm_latest, expected_slot_type, expected_day) \
			or SaveService.validation_summary_cache_snapshot() != cache_after_cold \
			or _fixture_disk_signature() != disk_before:
		return _fail_dictionary("%s warm-cache selection drifted or wrote storage." % label)

	var autosave_summary: Dictionary = SaveService.inspect_autosave()
	var manual_summary: Dictionary = SaveService.inspect_manual_slot(1)
	if not _display_contract_unchanged(autosave_summary) or not _display_contract_unchanged(manual_summary):
		return _fail_dictionary("%s changed the integer-facing timestamp display contract." % label)

	var menu_result: Dictionary = await _prove_main_menu_alignment(expected_slot_type, expected_day, disk_before)
	if menu_result.is_empty():
		return {}
	return {
		"latest": _summary_identity(cold_latest),
		"cold_disk": true,
		"warm_cache": true,
		"main_menu": menu_result,
		"exact_bytes": true,
		"no_residue": true,
	}


func _prove_main_menu_alignment(expected_slot_type: String, expected_day: int, disk_before: Dictionary) -> Dictionary:
	var shell = load("res://scenes/menus/MainMenu.tscn").instantiate()
	add_child(shell)
	await _settle(5)
	shell.validation_open_saves_stage()
	shell.validation_refresh_save_browser()
	await _settle(3)
	var snapshot: Dictionary = shell.validation_snapshot()
	var latest: Dictionary = snapshot.get("latest_save_summary", {}) if snapshot.get("latest_save_summary", {}) is Dictionary else {}
	var selected: Dictionary = snapshot.get("selected_save_summary", {}) if snapshot.get("selected_save_summary", {}) is Dictionary else {}
	var expected_key := _summary_key(expected_slot_type)
	if not _summary_matches(latest, expected_slot_type, expected_day) \
			or not _summary_matches(selected, expected_slot_type, expected_day) \
			or String(snapshot.get("selected_save_key", "")) != expected_key \
			or not bool(snapshot.get("continue_enabled", false)) \
			or String(snapshot.get("continue_text", "")) != SaveService.continue_action_label(latest):
		shell.queue_free()
		await _settle(3)
		return _fail_dictionary("MainMenu default/Continue disagreed with SaveService latest: %s" % JSON.stringify({
			"expected_key": expected_key,
			"latest": _summary_identity(latest),
			"selected": _summary_identity(selected),
			"selected_key": snapshot.get("selected_save_key"),
			"continue_text": snapshot.get("continue_text"),
		}))

	var resume_result: Dictionary = shell.validation_resume_latest()
	await _settle(3)
	var resumed = SessionState.active_session
	if not bool(resume_result.get("ok", false)) \
			or String(resume_result.get("selected_key", "")) != expected_key \
			or resumed == null \
			or int(resumed.day) != expected_day \
			or String(resumed.scenario_status) != "victory" \
			or _fixture_disk_signature() != disk_before:
		shell.queue_free()
		await _settle(3)
		return _fail_dictionary("MainMenu Continue did not restore the same latest summary without writes: %s" % JSON.stringify(resume_result))
	shell.queue_free()
	await _settle(3)
	return {"selected_key": expected_key, "continue_day": expected_day, "routed_suppressed": true}


func _prove_integer_legacy() -> Dictionary:
	_seed_pair(1001, 1000, 41, 40)
	SaveService.validation_clear_summary_cache()
	var disk_before: Dictionary = _fixture_disk_signature()
	var latest: Dictionary = SaveService.latest_loadable_summary()
	if not _summary_matches(latest, SaveService.SLOT_TYPE_AUTOSAVE, 41) \
			or int(latest.get("recorded_timestamp", 0)) != 1001 \
			or not is_equal_approx(float(latest.get("recorded_timestamp_precise", 0.0)), 1001.0) \
			or not is_equal_approx(SaveService.summary_recency_timestamp({
				"recorded_timestamp_precise": 0.0,
				"recorded_timestamp": 1001,
				"modified_timestamp": 999,
			}), 1001.0) \
			or not is_equal_approx(SaveService.summary_recency_timestamp({
				"recorded_timestamp_precise": 0.0,
				"recorded_timestamp": 0,
				"modified_timestamp": 999,
			}), 999.0):
		return _fail_dictionary("Integer-only legacy recency fallback failed: %s" % JSON.stringify(latest))
	var restored = SaveService.restore_session_from_summary(latest)
	if restored == null or int(restored.day) != 41 or String(restored.scenario_status) != "victory":
		return _fail_dictionary("Integer-only legacy latest summary did not load.")
	if _fixture_disk_signature() != disk_before or not _display_contract_unchanged(latest):
		return _fail_dictionary("Integer-only legacy inspection/load changed disk or display formatting.")
	return {"selected": _summary_identity(latest), "loaded": true, "recorded_fallback": true, "modified_fallback": true}


func _prove_modified_time_legacy() -> Dictionary:
	var payload: Dictionary = _payload(52, 0, SaveService.SLOT_TYPE_AUTOSAVE)
	payload.erase(SaveService.SAVE_METADATA_TIMESTAMP_KEY)
	_write_payload(AUTOSAVE_PATH, payload)
	_remove_path(MANUAL_PATH)
	_remove_transaction_artifacts(AUTOSAVE_PATH)
	_remove_transaction_artifacts(MANUAL_PATH)
	SaveService.validation_clear_summary_cache()
	var disk_before: Dictionary = _fixture_disk_signature()
	var latest: Dictionary = SaveService.latest_loadable_summary()
	if not _summary_matches(latest, SaveService.SLOT_TYPE_AUTOSAVE, 52) \
			or not is_zero_approx(float(latest.get("recorded_timestamp_precise", -1.0))) \
			or int(latest.get("recorded_timestamp", 0)) <= 0 \
			or int(latest.get("recorded_timestamp", 0)) != int(latest.get("modified_timestamp", -1)) \
			or not is_equal_approx(SaveService.summary_recency_timestamp(latest), float(latest.get("modified_timestamp", 0))):
		return _fail_dictionary("Missing-timestamp disk fallback failed: %s" % JSON.stringify(latest))
	var restored = SaveService.restore_session_from_summary(latest)
	if restored == null or int(restored.day) != 52 or _fixture_disk_signature() != disk_before:
		return _fail_dictionary("Missing-timestamp legacy summary did not load without disk mutation.")
	return {"selected": _summary_identity(latest), "loaded": true, "mtime_preserved": true}


func _seed_pair(autosave_timestamp: Variant, manual_timestamp: Variant, autosave_day: int, manual_day: int) -> void:
	_write_payload(AUTOSAVE_PATH, _payload(autosave_day, autosave_timestamp, SaveService.SLOT_TYPE_AUTOSAVE))
	_write_payload(MANUAL_PATH, _payload(manual_day, manual_timestamp, SaveService.SLOT_TYPE_MANUAL))
	_remove_transaction_artifacts(AUTOSAVE_PATH)
	_remove_transaction_artifacts(MANUAL_PATH)


func _payload(day: int, timestamp: Variant, slot_type: String) -> Dictionary:
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	var payload: Dictionary = session.to_dict()
	payload["day"] = day
	payload["scenario_status"] = "victory"
	payload["game_state"] = "outcome"
	payload["scenario_summary"] = "Subsecond recency fixture Day %d." % day
	payload[SaveService.SAVE_METADATA_TIMESTAMP_KEY] = timestamp
	payload[SaveService.SAVE_METADATA_SLOT_TYPE_KEY] = slot_type
	payload[SaveService.SAVE_METADATA_GAME_STATE_KEY] = "outcome"
	payload[SaveService.SAVE_METADATA_SCENARIO_STATUS_KEY] = "victory"
	payload[SaveService.SAVE_METADATA_LAUNCH_MODE_KEY] = SessionState.LAUNCH_MODE_SKIRMISH
	return payload


func _summary_matches(summary: Dictionary, slot_type: String, day: int) -> bool:
	return SaveService.can_load_summary(summary) \
		and String(summary.get("slot_type", "")) == slot_type \
		and int(summary.get("day", 0)) == day \
		and String(summary.get("scenario_status", "")) == "victory" \
		and String(summary.get("resume_target", "")) == "outcome"


func _display_contract_unchanged(summary: Dictionary) -> bool:
	var precise := float(summary.get("recorded_timestamp_precise", 0.0))
	var integer := int(summary.get("recorded_timestamp", 0))
	return integer == int(precise) \
		and SaveService.format_modified_timestamp(int(precise)) == SaveService.format_modified_timestamp(integer)


func _summary_identity(summary: Dictionary) -> Dictionary:
	return {
		"slot_type": summary.get("slot_type"),
		"slot_id": summary.get("slot_id"),
		"day": summary.get("day"),
		"recorded_timestamp": summary.get("recorded_timestamp"),
		"recorded_timestamp_precise": summary.get("recorded_timestamp_precise"),
	}


func _summary_key(slot_type: String) -> String:
	return "%s:%s" % [slot_type, "autosave" if slot_type == SaveService.SLOT_TYPE_AUTOSAVE else "1"]


func _fixture_disk_signature() -> Dictionary:
	var result := {
		AUTOSAVE_PATH: _file_state(AUTOSAVE_PATH),
		MANUAL_PATH: _file_state(MANUAL_PATH),
		"artifacts": {},
	}
	for path in [AUTOSAVE_PATH, MANUAL_PATH]:
		var artifacts: Dictionary = SaveService.validation_transaction_artifact_paths(path)
		for artifact_path in artifacts.values():
			result["artifacts"][String(artifact_path)] = _file_state(String(artifact_path))
	return result


func _tracked_paths() -> Array:
	var paths := [AUTOSAVE_PATH, MANUAL_PATH]
	for save_path in [AUTOSAVE_PATH, MANUAL_PATH]:
		for artifact_path in SaveService.validation_transaction_artifact_paths(save_path).values():
			paths.append(String(artifact_path))
	return paths


func _capture_files(paths: Array) -> Dictionary:
	var result := {}
	for path_value in paths:
		result[String(path_value)] = _file_state(String(path_value))
	return result


func _file_state(path: String) -> Dictionary:
	var exists := FileAccess.file_exists(path)
	return {
		"exists": exists,
		"bytes": FileAccess.get_file_as_bytes(path) if exists else PackedByteArray(),
		"modified_timestamp": FileAccess.get_modified_time(path) if exists else 0,
	}


func _write_payload(path: String, payload: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail("Could not write %s." % path)
		return
	file.store_string(JSON.stringify(payload))
	file.close()


func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_buffer(bytes)
		file.close()


func _remove_transaction_artifacts(path: String) -> void:
	for artifact_path in SaveService.validation_transaction_artifact_paths(path).values():
		_remove_path(String(artifact_path))


func _clear_fixture_paths() -> void:
	for path_value in _tracked_paths():
		_remove_path(String(path_value))
	SaveService.validation_clear_summary_cache()


func _remove_path(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _cleanup() -> void:
	AppRouter.validation_set_scenario_outcome_routing_suppressed(false)
	AppRouter.validation_reset_scenario_outcome_route_state()
	for path_value in _tracked_paths():
		_remove_path(String(path_value))
	for path_value in _original_files.keys():
		var state: Dictionary = _original_files[path_value]
		if bool(state.get("exists", false)):
			_write_bytes(String(path_value), state.get("bytes", PackedByteArray()))
	SaveService.set_selected_manual_slot(_original_slot)
	SaveService.validation_clear_summary_cache()
	SessionState.active_session = _original_session


func _settle(frames: int) -> void:
	for _frame in range(frames):
		await get_tree().process_frame


func _fail_dictionary(message: String) -> Dictionary:
	_fail(message)
	return {}


func _fail(message: String) -> void:
	_cleanup()
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
