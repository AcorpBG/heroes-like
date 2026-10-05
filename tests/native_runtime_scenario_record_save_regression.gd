extends Node

const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "NATIVE_RUNTIME_SCENARIO_RECORD_SAVE_REGRESSION"
const RECORD_KEY := "native_random_map_runtime_scenario_record"
const NATIVE_PACKAGE_FLAG := "native_random_map_package_session_adoption"
const MANUAL_PATH := "user://saves/slot1.json"
const AUTOSAVE_PATH := "user://saves/autosave.json"
const NAMED_SAVE_NAME := "Runtime Record Probe"
const NAMED_SAVE_PATH := "user://saves/Runtime Record Probe.save.json"

var _original_states := {}
var _original_active_session = null


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_original_states = _capture_file_states(_tracked_paths())
	_original_active_session = SessionState.active_session
	var manual := _validate_equal_copies_stored_once("manual")
	if manual.is_empty():
		return
	var autosave := _validate_equal_copies_stored_once("autosave")
	if autosave.is_empty():
		return
	var named_file := _validate_equal_copies_stored_once("file")
	if named_file.is_empty():
		return
	var differing := _validate_differing_copies_kept()
	if differing.is_empty():
		return
	var non_native := _validate_non_native_session_kept()
	if non_native.is_empty():
		return
	_cleanup()
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"manual": manual,
		"autosave": autosave,
		"named_file": named_file,
		"differing_copies": differing,
		"non_native_session": non_native,
	})])
	get_tree().quit(0)


func _validate_equal_copies_stored_once(slot_type: String) -> Dictionary:
	_clear_paths()
	SaveService.validation_clear_summary_cache()
	var session := _native_fixture(41, "equal_%s" % slot_type)
	var record: Dictionary = session.overworld[RECORD_KEY]
	session.flags[RECORD_KEY] = record.duplicate(true)
	var live_before := _canonical(session.to_dict())
	var result := _save(session, slot_type)
	if not bool(result.get("ok", false)):
		_fail("%s save of a native package session failed: %s" % [slot_type, JSON.stringify(result.get("message", ""))])
		return {}
	if _canonical(session.to_dict()) != live_before or not (session.flags.get(RECORD_KEY) is Dictionary):
		_fail("%s save changed the live session's runtime scenario records." % slot_type)
		return {}
	var path := _path(slot_type)
	var stored := _read_dictionary(path)
	if (stored.get("flags", {}) as Dictionary).has(RECORD_KEY) or _canonical((stored.get("overworld", {}) as Dictionary).get(RECORD_KEY, {})) != _canonical(record):
		_fail("%s save did not store equal runtime scenario records once, under overworld." % slot_type)
		return {}
	SaveService.validation_clear_summary_cache()
	var summary := _inspect(slot_type)
	if not SaveService.can_load_summary(summary):
		_fail("%s save without the flags copy is not loadable." % slot_type)
		return {}
	var restored = SaveService.restore_session_from_summary(summary)
	if restored == null or not restored.flags.has(RECORD_KEY) or not is_same(restored.flags[RECORD_KEY], restored.overworld[RECORD_KEY]):
		_fail("%s restore did not put the runtime scenario record back into flags as the overworld Dictionary." % slot_type)
		return {}
	if _canonical(ScenarioRules.scenario_record_for_session(restored)) != _canonical(record):
		_fail("%s restore changed the scenario record readers resolve." % slot_type)
		return {}
	var legacy_payload := SaveService.load_autosave() if slot_type == "autosave" else SaveService.load_session(1) if slot_type == "manual" else {}
	if slot_type != "file" and not (legacy_payload.get("flags", {}) as Dictionary).has(RECORD_KEY):
		_fail("%s dictionary load did not restore the flags runtime scenario record." % slot_type)
		return {}
	# Older builds wrote both copies. Both formats must restore the same session.
	stored["flags"][RECORD_KEY] = (stored["overworld"][RECORD_KEY] as Dictionary).duplicate(true)
	if not _write_text(path, JSON.stringify(stored)):
		_fail("Could not write the two-copy %s fixture." % slot_type)
		return {}
	SaveService.validation_clear_summary_cache()
	var restored_two_copy = SaveService.restore_session_from_summary(_inspect(slot_type))
	if restored_two_copy == null or _canonical(restored_two_copy.to_dict()) != _canonical(restored.to_dict()):
		_fail("%s restore of a one-copy save differs from the two-copy save it replaces." % slot_type)
		return {}
	return {
		"stored_once": true,
		"live_session_unchanged": true,
		"restored_shared_reference": true,
		"matches_two_copy_restore": true,
		"saved_bytes": FileAccess.get_size(path),
	}


func _validate_differing_copies_kept() -> Dictionary:
	_clear_paths()
	SaveService.validation_clear_summary_cache()
	var session := _native_fixture(42, "differing")
	var flags_record: Dictionary = (session.overworld[RECORD_KEY] as Dictionary).duplicate(true)
	flags_record["name"] = "Flags-only title"
	session.flags[RECORD_KEY] = flags_record
	if not bool(_save(session, "manual").get("ok", false)):
		_fail("Could not save the differing-records fixture.")
		return {}
	var stored := _read_dictionary(MANUAL_PATH)
	if _canonical((stored.get("flags", {}) as Dictionary).get(RECORD_KEY, {})) != _canonical(flags_record) \
			or _canonical((stored.get("overworld", {}) as Dictionary).get(RECORD_KEY, {})) != _canonical(session.overworld[RECORD_KEY]):
		_fail("A save dropped one of two differing runtime scenario records.")
		return {}
	var restored = SaveService.restore_manual_session(1)
	if restored == null or is_same(restored.flags.get(RECORD_KEY), restored.overworld.get(RECORD_KEY)) \
			or String(restored.flags[RECORD_KEY].get("name", "")) != "Flags-only title":
		_fail("Differing runtime scenario records did not restore independently.")
		return {}
	return {"both_stored": true, "restored_independently": true}


func _validate_non_native_session_kept() -> Dictionary:
	_clear_paths()
	SaveService.validation_clear_summary_cache()
	var session := _native_fixture(43, "non_native")
	session.flags.erase(NATIVE_PACKAGE_FLAG)
	session.flags[RECORD_KEY] = (session.overworld[RECORD_KEY] as Dictionary).duplicate(true)
	if not bool(_save(session, "manual").get("ok", false)):
		_fail("Could not save the non-native fixture.")
		return {}
	var stored := _read_dictionary(MANUAL_PATH)
	if not (stored.get("flags", {}) as Dictionary).has(RECORD_KEY):
		_fail("A session that is not a native package session lost its flags runtime scenario record.")
		return {}
	return {"flags_copy_stored": true}


func _native_fixture(day: int, marker: String) -> SessionStateStoreScript.SessionData:
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	session.day = day
	session.flags["fixture_marker"] = marker
	session.flags[NATIVE_PACKAGE_FLAG] = true
	session.overworld[RECORD_KEY] = {
		"id": session.scenario_id,
		"name": "Runtime record probe",
		"player_slots": [{"player_id": "player_1", "faction_id": "faction_embercourt", "team_id": "team_1"}],
		"objectives": {"victory": [{"type": "day_at_least", "day": 30}], "defeat": []},
		"enemy_factions": [],
	}
	return session


func _save(session: SessionStateStoreScript.SessionData, slot_type: String) -> Dictionary:
	match slot_type:
		"autosave":
			return SaveService.save_runtime_autosave_session(session)
		"file":
			return SaveService.save_runtime_file_session(session, NAMED_SAVE_NAME)
		_:
			return SaveService.save_runtime_manual_session(session, 1)


func _inspect(slot_type: String) -> Dictionary:
	match slot_type:
		"autosave":
			return SaveService.inspect_autosave()
		"file":
			return SaveService.inspect_save_file(NAMED_SAVE_NAME)
		_:
			return SaveService.inspect_manual_slot(1)


func _path(slot_type: String) -> String:
	match slot_type:
		"autosave":
			return AUTOSAVE_PATH
		"file":
			return NAMED_SAVE_PATH
		_:
			return MANUAL_PATH


# Saved numbers come back as floats; compare through the same JSON round trip.
func _canonical(value: Variant) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(value)), "", true)


func _tracked_paths() -> Array:
	var paths := []
	for live_path in [MANUAL_PATH, AUTOSAVE_PATH, NAMED_SAVE_PATH]:
		paths.append(live_path)
		var artifacts: Dictionary = SaveService.validation_transaction_artifact_paths(live_path)
		for key in artifacts.keys():
			paths.append(String(artifacts[key]))
	return paths


func _capture_file_states(paths: Array) -> Dictionary:
	var states := {}
	for path in paths:
		var file_path := String(path)
		states[file_path] = {
			"exists": FileAccess.file_exists(file_path),
			"bytes": FileAccess.get_file_as_bytes(file_path) if FileAccess.file_exists(file_path) else PackedByteArray(),
		}
	return states


func _clear_paths() -> void:
	for path in _tracked_paths():
		_remove_path(String(path))


func _read_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _write_text(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.close()
	return true


func _remove_path(path: String) -> void:
	if path != "" and FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _cleanup() -> void:
	_clear_paths()
	for path in _original_states.keys():
		var state: Dictionary = _original_states.get(path, {})
		if bool(state.get("exists", false)):
			var file := FileAccess.open(String(path), FileAccess.WRITE)
			if file != null:
				file.store_buffer(state.get("bytes", PackedByteArray()))
				file.close()
	SaveService.validation_clear_summary_cache()
	SessionState.active_session = _original_active_session


func _fail(message: String) -> void:
	_cleanup()
	push_error("%s failed: %s" % [REPORT_ID, message])
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "error": message})])
	get_tree().quit(1)
