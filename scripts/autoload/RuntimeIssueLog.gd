class_name HeroesRuntimeIssueLog
extends Node

const ProfileLogScript = preload("res://scripts/core/ProfileLog.gd")

const ISSUE_SCHEMA := "heroes_like.runtime_issue.v1"
const ISSUE_LOG_PATH := "user://debug/heroes_runtime_issues.jsonl"
const LATEST_ISSUE_PATH := "user://debug/heroes_last_runtime_issue.json"
const SUPPORT_BUNDLE_SCHEMA := "heroes_like.support_bundle.v1"
const SUPPORT_BUNDLE_PATH := "user://debug/heroes_support_bundle.json"
const SUPPORT_BUNDLE_TEMP_PATH := "user://debug/heroes_support_bundle.tmp"
const SESSION_MARKER_SCHEMA := "heroes_like.runtime_session.v1"
const SESSION_MARKER_PATH := "user://debug/heroes_runtime_session.json"
const SESSION_MARKER_TEMP_PATH := "user://debug/heroes_runtime_session.tmp"
const ENGINE_LOG_DIRECTORY := "user://logs"
const ENGINE_ACTIVE_LOG_NAME := "godot.log"
const MAX_MESSAGE_LENGTH := 600
const MAX_SUPPORT_ISSUE_RECORDS := 25
const MAX_SUPPORT_BUNDLE_BYTES := 512 * 1024
const MAX_PREVIOUS_ENGINE_LOG_BYTES := 64 * 1024
const MAX_PREVIOUS_ENGINE_LOG_LINES := 40
const MAX_PREVIOUS_ENGINE_LOG_LINE_LENGTH := 240
const VALID_SEVERITIES := ["info", "warning", "error", "fatal"]
const SUPPORT_REDACTED := "<redacted>"
const SUPPORT_SENSITIVE_KEY_FRAGMENTS := [
	"absolute_path",
	"auth",
	"email",
	"home_directory",
	"password",
	"secret",
	"token",
	"user_name",
	"username",
]

var _owned_process_id := -1

func _ready() -> void:
	_ensure_debug_directory()
	_recover_previous_unclean_session()
	_owned_process_id = OS.get_process_id()
	_write_session_marker()

func _exit_tree() -> void:
	_remove_owned_session_marker()

func emit_issue(
	severity: String,
	surface: String,
	event: String,
	message: String,
	metadata: Dictionary = {},
	session: Variant = null
) -> Dictionary:
	var normalized_severity := _normalize_severity(severity)
	var record := {
		"schema": ISSUE_SCHEMA,
		"timestamp_utc": Time.get_datetime_string_from_system(true),
		"monotonic_msec": Time.get_ticks_msec(),
		"severity": normalized_severity,
		"surface": _bounded_text(surface, 80),
		"event": _bounded_text(event, 120),
		"message": _bounded_text(message, MAX_MESSAGE_LENGTH),
		"metadata": ProfileLogScript.json_safe(metadata.duplicate(true)),
		"session": ProfileLogScript.session_metadata(session),
		"app": _app_metadata(),
		"platform": _platform_metadata(),
	}
	_append_jsonl(ISSUE_LOG_PATH, record)
	_write_latest_issue(record)
	if normalized_severity in ["error", "fatal"]:
		push_error("%s: %s" % [String(record.get("event", "runtime_issue")), String(record.get("message", ""))])
	else:
		push_warning("%s: %s" % [String(record.get("event", "runtime_issue")), String(record.get("message", ""))])
	return record

func emit_error(surface: String, event: String, message: String, metadata: Dictionary = {}, session: Variant = null) -> Dictionary:
	return emit_issue("error", surface, event, message, metadata, session)

func emit_fatal(surface: String, event: String, message: String, metadata: Dictionary = {}, session: Variant = null) -> Dictionary:
	return emit_issue("fatal", surface, event, message, metadata, session)

func issue_log_snapshot() -> Dictionary:
	return {
		"schema": ISSUE_SCHEMA,
		"path": ISSUE_LOG_PATH,
		"absolute_path": ProjectSettings.globalize_path(ISSUE_LOG_PATH),
		"latest_issue_path": LATEST_ISSUE_PATH,
		"latest_issue_absolute_path": ProjectSettings.globalize_path(LATEST_ISSUE_PATH),
		"record_count": issue_record_count(),
		"latest_issue_exists": FileAccess.file_exists(LATEST_ISSUE_PATH),
	}

func issue_record_count() -> int:
	return ProfileLogScript.record_count(ISSUE_LOG_PATH)

func last_issue_records(limit: int = 5) -> Array:
	return ProfileLogScript.last_records(ISSUE_LOG_PATH, limit)

func clear_issue_log() -> Dictionary:
	_ensure_debug_directory()
	var file := FileAccess.open(ISSUE_LOG_PATH, FileAccess.WRITE)
	if file != null:
		file.close()
	var remove_error := DirAccess.remove_absolute(ProjectSettings.globalize_path(LATEST_ISSUE_PATH))
	if remove_error != OK and remove_error != ERR_FILE_NOT_FOUND:
		push_warning("Unable to remove latest runtime issue snapshot: %s" % error_string(remove_error))
	return issue_log_snapshot()

func export_support_bundle(device_settings: Dictionary = {}) -> Dictionary:
	_ensure_debug_directory()
	var records := []
	for record_value in last_issue_records(MAX_SUPPORT_ISSUE_RECORDS):
		if record_value is Dictionary:
			records.append(_support_safe_value(record_value))
	var total_record_count := issue_record_count()
	var payload := {
		"schema": SUPPORT_BUNDLE_SCHEMA,
		"generated_at_utc": Time.get_datetime_string_from_system(true),
		"app": _support_safe_value(_app_metadata()),
		"platform": _support_safe_value(_platform_metadata()),
		"device_settings": _support_settings_snapshot(device_settings),
		"issue_log": {
			"total_record_count": total_record_count,
			"included_record_count": records.size(),
			"omitted_record_count": maxi(0, total_record_count - records.size()),
			"recent_issues": records,
		},
		"privacy": {
			"local_only": true,
			"telemetry_uploaded": false,
			"includes_expedition_save_payload": false,
			"includes_campaign_progression": false,
			"includes_absolute_user_paths": false,
		},
	}
	var serialized := JSON.stringify(ProfileLogScript.json_safe(payload), "\t")
	while serialized.to_utf8_buffer().size() > MAX_SUPPORT_BUNDLE_BYTES and not records.is_empty():
		records.pop_front()
		payload["issue_log"]["included_record_count"] = records.size()
		payload["issue_log"]["omitted_record_count"] = maxi(0, total_record_count - records.size())
		payload["issue_log"]["recent_issues"] = records
		serialized = JSON.stringify(ProfileLogScript.json_safe(payload), "\t")
	if serialized.to_utf8_buffer().size() > MAX_SUPPORT_BUNDLE_BYTES:
		return _support_bundle_failure("Support data exceeds the local bundle size limit.")
	var temp_file := FileAccess.open(SUPPORT_BUNDLE_TEMP_PATH, FileAccess.WRITE)
	if temp_file == null:
		return _support_bundle_failure("Unable to create the local support bundle.")
	temp_file.store_string(serialized)
	temp_file.close()
	var destination_absolute := ProjectSettings.globalize_path(SUPPORT_BUNDLE_PATH)
	var temp_absolute := ProjectSettings.globalize_path(SUPPORT_BUNDLE_TEMP_PATH)
	var remove_error := OK
	if FileAccess.file_exists(SUPPORT_BUNDLE_PATH):
		remove_error = DirAccess.remove_absolute(destination_absolute)
	if remove_error != OK:
		DirAccess.remove_absolute(temp_absolute)
		return _support_bundle_failure("Unable to replace the previous local support bundle.")
	var rename_error := DirAccess.rename_absolute(temp_absolute, destination_absolute)
	if rename_error != OK:
		DirAccess.remove_absolute(temp_absolute)
		return _support_bundle_failure("Unable to finalize the local support bundle.")
	return {
		"ok": true,
		"path": SUPPORT_BUNDLE_PATH,
		"schema": SUPPORT_BUNDLE_SCHEMA,
		"size_bytes": serialized.to_utf8_buffer().size(),
		"issue_record_count": records.size(),
		"omitted_issue_record_count": maxi(0, total_record_count - records.size()),
		"message": "Support bundle ready.",
	}

func support_bundle_snapshot() -> Dictionary:
	if not FileAccess.file_exists(SUPPORT_BUNDLE_PATH):
		return {}
	var file := FileAccess.open(SUPPORT_BUNDLE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}

func session_marker_snapshot() -> Dictionary:
	return _read_json_dictionary(SESSION_MARKER_PATH)

func _recover_previous_unclean_session() -> void:
	if not FileAccess.file_exists(SESSION_MARKER_PATH):
		return
	var marker := _read_json_dictionary(SESSION_MARKER_PATH)
	var marker_absolute := ProjectSettings.globalize_path(SESSION_MARKER_PATH)
	var remove_error := DirAccess.remove_absolute(marker_absolute)
	if remove_error != OK and remove_error != ERR_FILE_NOT_FOUND:
		push_warning("Unable to consume previous runtime session marker: %s" % error_string(remove_error))
		return
	if String(marker.get("schema", "")) != SESSION_MARKER_SCHEMA:
		push_warning("Discarded an invalid previous runtime session marker.")
		return
	var log_tail := _latest_previous_engine_log_tail()
	emit_issue(
		"warning",
		"runtime",
		"previous_session_unclean_exit",
		"The previous game session ended without a clean shutdown.",
		{
			"previous_process_id": maxi(0, int(marker.get("process_id", 0))),
			"previous_started_at_utc": _bounded_text(String(marker.get("started_at_utc", "")), 40),
			"previous_app_version": _bounded_text(String(marker.get("app_version", "")), 80),
			"engine_log_available": not log_tail.is_empty(),
			"engine_log_line_count": log_tail.size(),
			"engine_log_tail": log_tail,
		}
	)

func _write_session_marker() -> void:
	_ensure_debug_directory()
	var marker := {
		"schema": SESSION_MARKER_SCHEMA,
		"process_id": _owned_process_id,
		"started_at_utc": Time.get_datetime_string_from_system(true),
		"app_version": String(ProjectSettings.get_setting("application/config/version", "")),
	}
	var temp_file := FileAccess.open(SESSION_MARKER_TEMP_PATH, FileAccess.WRITE)
	if temp_file == null:
		push_warning("Unable to create runtime session marker: %s" % error_string(FileAccess.get_open_error()))
		return
	temp_file.store_string(JSON.stringify(marker, "\t"))
	temp_file.close()
	var marker_absolute := ProjectSettings.globalize_path(SESSION_MARKER_PATH)
	var temp_absolute := ProjectSettings.globalize_path(SESSION_MARKER_TEMP_PATH)
	if FileAccess.file_exists(SESSION_MARKER_PATH):
		var remove_error := DirAccess.remove_absolute(marker_absolute)
		if remove_error != OK:
			DirAccess.remove_absolute(temp_absolute)
			push_warning("Unable to replace runtime session marker: %s" % error_string(remove_error))
			return
	var rename_error := DirAccess.rename_absolute(temp_absolute, marker_absolute)
	if rename_error != OK:
		DirAccess.remove_absolute(temp_absolute)
		push_warning("Unable to finalize runtime session marker: %s" % error_string(rename_error))

func _remove_owned_session_marker() -> void:
	if _owned_process_id <= 0 or not FileAccess.file_exists(SESSION_MARKER_PATH):
		return
	var marker := _read_json_dictionary(SESSION_MARKER_PATH)
	if int(marker.get("process_id", -1)) != _owned_process_id:
		return
	var remove_error := DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION_MARKER_PATH))
	if remove_error != OK and remove_error != ERR_FILE_NOT_FOUND:
		push_warning("Unable to clear runtime session marker: %s" % error_string(remove_error))

func _read_json_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}

func _latest_previous_engine_log_tail() -> Array:
	var directory := DirAccess.open(ENGINE_LOG_DIRECTORY)
	if directory == null:
		return []
	var newest_path := ""
	var newest_modified := 0
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		if not directory.current_is_dir() and name.ends_with(".log") and name != ENGINE_ACTIVE_LOG_NAME:
			var path := "%s/%s" % [ENGINE_LOG_DIRECTORY, name]
			var modified := int(FileAccess.get_modified_time(path))
			if modified > newest_modified or (modified == newest_modified and path > newest_path):
				newest_modified = modified
				newest_path = path
		name = directory.get_next()
	directory.list_dir_end()
	if newest_path.is_empty():
		return []
	var file := FileAccess.open(newest_path, FileAccess.READ)
	if file == null:
		return []
	var length := file.get_length()
	var offset := maxi(0, length - MAX_PREVIOUS_ENGINE_LOG_BYTES)
	file.seek(offset)
	if offset > 0:
		file.get_line()
	var text := file.get_buffer(file.get_length() - file.get_position()).get_string_from_utf8()
	file.close()
	var result := []
	for line_value in text.split("\n", false):
		var line := _bounded_text(String(line_value), MAX_PREVIOUS_ENGINE_LOG_LINE_LENGTH)
		if line.is_empty():
			continue
		var safe_line = _support_safe_value(line)
		result.append(safe_line)
		while result.size() > MAX_PREVIOUS_ENGINE_LOG_LINES:
			result.pop_front()
	return result

func _append_jsonl(path: String, record: Dictionary) -> void:
	_ensure_debug_directory()
	var file := FileAccess.open(path, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Unable to open runtime issue log at %s: %s" % [path, error_string(FileAccess.get_open_error())])
		return
	file.seek_end()
	file.store_string("%s\n" % JSON.stringify(ProfileLogScript.json_safe(record)))
	file.close()

func _write_latest_issue(record: Dictionary) -> void:
	_ensure_debug_directory()
	var file := FileAccess.open(LATEST_ISSUE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Unable to write latest runtime issue snapshot at %s: %s" % [LATEST_ISSUE_PATH, error_string(FileAccess.get_open_error())])
		return
	file.store_string(JSON.stringify(ProfileLogScript.json_safe(record), "\t"))
	file.close()

func _ensure_debug_directory() -> void:
	var dir := DirAccess.open("user://")
	if dir != null:
		dir.make_dir_recursive("debug")

func _normalize_severity(severity: String) -> String:
	var normalized := severity.strip_edges().to_lower()
	if normalized in VALID_SEVERITIES:
		return normalized
	return "error"

func _support_bundle_failure(message: String) -> Dictionary:
	return {
		"ok": false,
		"path": SUPPORT_BUNDLE_PATH,
		"schema": SUPPORT_BUNDLE_SCHEMA,
		"size_bytes": 0,
		"issue_record_count": 0,
		"omitted_issue_record_count": issue_record_count(),
		"message": _bounded_text(message, 160),
	}

func _support_settings_snapshot(value: Dictionary) -> Dictionary:
	var audio: Dictionary = value.get("audio", {}) if value.get("audio", {}) is Dictionary else {}
	var presentation: Dictionary = value.get("presentation", {}) if value.get("presentation", {}) is Dictionary else {}
	var gameplay: Dictionary = value.get("gameplay", {}) if value.get("gameplay", {}) is Dictionary else {}
	var accessibility: Dictionary = value.get("accessibility", {}) if value.get("accessibility", {}) is Dictionary else {}
	return _support_safe_value({
		"version": int(value.get("version", 0)),
		"audio": {
			"master_volume_percent": clampi(int(audio.get("master_volume_percent", 0)), 0, 100),
			"music_volume_percent": clampi(int(audio.get("music_volume_percent", 0)), 0, 100),
			"effects_volume_percent": clampi(int(audio.get("effects_volume_percent", 0)), 0, 100),
		},
		"presentation": {
			"mode": _bounded_text(String(presentation.get("mode", "")), 32),
			"resolution": _bounded_text(String(presentation.get("resolution", "")), 32),
			"render_quality": _bounded_text(String(presentation.get("render_quality", "")), 32),
			"vsync_enabled": bool(presentation.get("vsync_enabled", false)),
			"frame_rate_limit": maxi(0, int(presentation.get("frame_rate_limit", 0))),
		},
		"gameplay": {
			"battle_playback_speed": _bounded_text(String(gameplay.get("battle_playback_speed", "")), 32),
			"keyboard_navigation_layout": _bounded_text(String(gameplay.get("keyboard_navigation_layout", "")), 32),
			"custom_hero_movement_bindings": not (gameplay.get("hero_movement_bindings", {}) as Dictionary).is_empty() if gameplay.get("hero_movement_bindings", {}) is Dictionary else false,
		},
		"accessibility": {
			"ui_scale_percent": clampi(int(accessibility.get("ui_scale_percent", 100)), 75, 200),
			"high_contrast_ui": bool(accessibility.get("high_contrast_ui", false)),
			"color_cue_mode": _bounded_text(String(accessibility.get("color_cue_mode", "")), 32),
			"battle_camera_shake": _bounded_text(String(accessibility.get("battle_camera_shake", "")), 32),
			"reduce_flashes": bool(accessibility.get("reduce_flashes", false)),
			"reduce_motion": bool(accessibility.get("reduce_motion", false)),
		},
	})

func _support_safe_value(value: Variant, key_hint: String = "") -> Variant:
	if _support_sensitive_key(key_hint):
		return SUPPORT_REDACTED
	match typeof(value):
		TYPE_DICTIONARY:
			var result := {}
			var dictionary: Dictionary = value
			for key_value in dictionary.keys():
				var key := String(key_value)
				result[key] = _support_safe_value(dictionary.get(key_value), key)
			return result
		TYPE_ARRAY:
			var result := []
			for item in value as Array:
				result.append(_support_safe_value(item, key_hint))
			return result
		TYPE_STRING, TYPE_STRING_NAME, TYPE_NODE_PATH:
			var text := _bounded_text(String(value), 2000)
			return SUPPORT_REDACTED if _support_text_contains_absolute_path(text) else text
		_:
			return ProfileLogScript.json_safe(value)

func _support_sensitive_key(key: String) -> bool:
	var normalized := key.strip_edges().to_lower()
	for fragment in SUPPORT_SENSITIVE_KEY_FRAGMENTS:
		if normalized.contains(String(fragment)):
			return true
	return false

func _support_text_contains_absolute_path(text: String) -> bool:
	var normalized := text.replace("\\", "/")
	if normalized.begins_with("/") or normalized.begins_with("file://"):
		return true
	if normalized.length() >= 3 and normalized.substr(1, 2) == ":/":
		return true
	if normalized.contains("/home/") or normalized.contains("/root/") or normalized.contains("/Users/"):
		return true
	var token_source := normalized.replace("\t", " ")
	for token_value in token_source.split(" ", false):
		var token := String(token_value)
		while not token.is_empty() and token[0] in ["(", "[", "{", "\"", "'"]:
			token = token.substr(1)
		if token.begins_with("/"):
			return true
		if token.length() >= 3 and token.substr(1, 2) == ":/":
			return true
	return false

func _bounded_text(value: String, max_length: int) -> String:
	var text := value.strip_edges()
	if text.length() <= max_length:
		return text
	return "%s..." % text.substr(0, maxi(0, max_length - 3))

func _app_metadata() -> Dictionary:
	return {
		"name": String(ProjectSettings.get_setting("application/config/name", "")),
		"version": String(ProjectSettings.get_setting("application/config/version", "")),
		"main_scene": String(ProjectSettings.get_setting("application/run/main_scene", "")),
		"engine_version": Engine.get_version_info().get("string", ""),
	}

func _platform_metadata() -> Dictionary:
	return {
		"os": OS.get_name(),
		"distribution": OS.get_distribution_name(),
		"architecture": Engine.get_architecture_name(),
		"locale": OS.get_locale(),
		"processor_count": OS.get_processor_count(),
	}
