class_name HeroesRuntimeIssueLog
extends Node

const ProfileLogScript = preload("res://scripts/core/ProfileLog.gd")

const ISSUE_SCHEMA := "heroes_like.runtime_issue.v1"
const ISSUE_LOG_PATH := "user://debug/heroes_runtime_issues.jsonl"
const LATEST_ISSUE_PATH := "user://debug/heroes_last_runtime_issue.json"
const MAX_MESSAGE_LENGTH := 600
const VALID_SEVERITIES := ["info", "warning", "error", "fatal"]

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

func _bounded_text(value: String, max_length: int) -> String:
	var text := value.strip_edges()
	if text.length() <= max_length:
		return text
	return "%s..." % text.substr(0, maxi(0, max_length - 3))

func _app_metadata() -> Dictionary:
	return {
		"name": String(ProjectSettings.get_setting("application/config/name", "")),
		"main_scene": String(ProjectSettings.get_setting("application/run/main_scene", "")),
	}

func _platform_metadata() -> Dictionary:
	return {
		"os": OS.get_name(),
		"distribution": OS.get_distribution_name(),
		"locale": OS.get_locale(),
		"processor_count": OS.get_processor_count(),
	}
