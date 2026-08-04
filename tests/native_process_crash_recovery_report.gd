extends Node

const REPORT_ID := "NATIVE_PROCESS_CRASH_RECOVERY_REPORT"
const SCHEMA_ID := "native_process_crash_recovery_v1"
const CRASH_MARKER := "NATIVE_PROCESS_CRASH_FIXTURE_MARKER"
const RECOVERY_EVENT := "previous_session_unclean_exit"

var _errors: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var recovered_records := []
	for record_value in RuntimeIssueLog.last_issue_records(10):
		if record_value is Dictionary and String((record_value as Dictionary).get("event", "")) == RECOVERY_EVENT:
			recovered_records.append((record_value as Dictionary).duplicate(true))
	_expect(recovered_records.size() == 1, "Exactly one previous-session issue must be recovered.")
	var recovered: Dictionary = recovered_records[0] if recovered_records.size() == 1 else {}
	var metadata: Dictionary = recovered.get("metadata", {}) if recovered.get("metadata", {}) is Dictionary else {}
	var log_tail: Array = metadata.get("engine_log_tail", []) if metadata.get("engine_log_tail", []) is Array else []
	_expect(String(recovered.get("severity", "")) == "warning", "Recovered unclean exit must be a warning, not a second fatal engine error.")
	_expect(bool(metadata.get("engine_log_available", false)), "Recovered issue must include the previous rotated engine log.")
	_expect(int(metadata.get("engine_log_line_count", 0)) == log_tail.size(), "Recovered log line count must match its bounded payload.")
	_expect(log_tail.size() <= RuntimeIssueLog.MAX_PREVIOUS_ENGINE_LOG_LINES, "Recovered engine log tail exceeds its line cap.")
	_expect(_tail_contains(log_tail, CRASH_MARKER), "Recovered engine log tail is missing the forced-crash marker.")
	_expect(_tail_is_support_safe(log_tail), "Recovered engine log tail exposes an absolute path.")

	var session_marker := RuntimeIssueLog.session_marker_snapshot()
	_expect(String(session_marker.get("schema", "")) == RuntimeIssueLog.SESSION_MARKER_SCHEMA, "The recovery process must own a current session marker.")
	_expect(int(session_marker.get("process_id", -1)) == OS.get_process_id(), "Current session marker process ownership mismatch.")

	var support_result := RuntimeIssueLog.export_support_bundle({
		"version": 1,
		"audio": {},
		"presentation": {},
		"gameplay": {},
		"accessibility": {},
	})
	var support_bundle := RuntimeIssueLog.support_bundle_snapshot()
	var support_issues: Array = support_bundle.get("issue_log", {}).get("recent_issues", []) if support_bundle.get("issue_log", {}) is Dictionary else []
	_expect(bool(support_result.get("ok", false)), "Recovered native-process issue must export through the existing support bundle.")
	_expect(_support_contains_event(support_issues, RECOVERY_EVENT), "Support bundle is missing the recovered native-process issue.")
	var privacy: Dictionary = support_bundle.get("privacy", {}) if support_bundle.get("privacy", {}) is Dictionary else {}
	_expect(bool(privacy.get("local_only", false)), "Support bundle must remain local-only.")
	_expect(not bool(privacy.get("telemetry_uploaded", true)), "Support bundle must not claim telemetry upload.")
	_expect(not bool(privacy.get("includes_expedition_save_payload", true)), "Support bundle must not include save payloads.")
	_expect(not bool(privacy.get("includes_campaign_progression", true)), "Support bundle must not include campaign progression.")
	_expect(not bool(privacy.get("includes_absolute_user_paths", true)), "Support bundle must not include absolute user paths.")

	var report := {
		"schema_id": SCHEMA_ID,
		"report_id": REPORT_ID,
		"ok": _errors.is_empty(),
		"ran_from_pack_scene": ResourceLoader.exists("res://tests/native_process_crash_recovery_report.tscn"),
		"recovered_issue_count": recovered_records.size(),
		"recovered_issue": recovered,
		"session_marker": session_marker,
		"session_marker_path": RuntimeIssueLog.SESSION_MARKER_PATH,
		"user_data_dir_absolute": OS.get_user_data_dir(),
		"support_bundle_result": support_result,
		"support_bundle": support_bundle,
		"errors": _errors.duplicate(),
	}
	_expect(bool(report.get("ran_from_pack_scene", false)), "Recovery report scene must be present in the exported PCK.")
	report["ok"] = _errors.is_empty()
	report["errors"] = _errors.duplicate()
	var report_path := _report_path_from_args()
	if not report_path.is_empty():
		_write_report(report_path, report)
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": report.get("ok", false),
		"recovered_issue_count": recovered_records.size(),
		"log_line_count": log_tail.size(),
		"support_bundle_ok": support_result.get("ok", false),
	})])
	get_tree().quit(0 if _errors.is_empty() else 1)

func _tail_contains(lines: Array, expected: String) -> bool:
	for line_value in lines:
		if String(line_value).contains(expected):
			return true
	return false

func _tail_is_support_safe(lines: Array) -> bool:
	for line_value in lines:
		var line := String(line_value)
		if line != RuntimeIssueLog.SUPPORT_REDACTED and RuntimeIssueLog._support_text_contains_absolute_path(line):
			return false
	return true

func _support_contains_event(records: Array, expected: String) -> bool:
	for record_value in records:
		if record_value is Dictionary and String((record_value as Dictionary).get("event", "")) == expected:
			return true
	return false

func _report_path_from_args() -> String:
	for argument in OS.get_cmdline_user_args():
		if String(argument).begins_with("--report-json="):
			return String(argument).trim_prefix("--report-json=")
	return ""

func _write_report(path: String, report: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_errors.append("Unable to write recovery report: %s" % path)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
