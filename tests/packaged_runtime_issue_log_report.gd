extends Node

const REPORT_ID := "PACKAGED_RUNTIME_ISSUE_LOG_REPORT"
const SCHEMA_ID := "packaged_runtime_issue_log_v1"
const TEST_EVENT := "packaged_runtime_issue_smoke"
const TEST_MESSAGE := "Packaged runtime issue smoke record"

var _errors: Array[String] = []
var _report := {}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var report_path := _report_path_from_args()
	_report = {
		"schema_id": SCHEMA_ID,
		"report_id": REPORT_ID,
		"ok": false,
		"issue_log_path": RuntimeIssueLog.ISSUE_LOG_PATH,
		"latest_issue_path": RuntimeIssueLog.LATEST_ISSUE_PATH,
		"support_bundle_path": RuntimeIssueLog.SUPPORT_BUNDLE_PATH,
		"issue_log_absolute": ProjectSettings.globalize_path(RuntimeIssueLog.ISSUE_LOG_PATH),
		"latest_issue_absolute": ProjectSettings.globalize_path(RuntimeIssueLog.LATEST_ISSUE_PATH),
		"ran_from_pack_scene": ResourceLoader.exists("res://tests/packaged_runtime_issue_log_report.tscn"),
		"initial_snapshot": {},
		"emitted_record": {},
		"final_snapshot": {},
		"last_records": [],
		"latest_issue": {},
		"support_bundle_result": {},
		"support_bundle": {},
		"errors": [],
	}

	_run_issue_log_check()
	_report["ok"] = _errors.is_empty()
	_report["errors"] = _errors.duplicate()
	if report_path != "":
		_write_report_file(report_path, _report)
	print("%s %s" % [REPORT_ID, JSON.stringify(_summary_payload())])
	get_tree().quit(0 if _errors.is_empty() else 1)

func _run_issue_log_check() -> void:
	_expect(RuntimeIssueLog.ISSUE_LOG_PATH == "user://debug/heroes_runtime_issues.jsonl", "Runtime issue log path must stay under user://debug.")
	_expect(RuntimeIssueLog.LATEST_ISSUE_PATH == "user://debug/heroes_last_runtime_issue.json", "Latest runtime issue snapshot path must stay under user://debug.")
	_expect(RuntimeIssueLog.SUPPORT_BUNDLE_PATH == "user://debug/heroes_support_bundle.json", "Support bundle path must stay under user://debug.")
	_expect(bool(_report.get("ran_from_pack_scene", false)), "Packaged runtime issue report scene must be loadable from res://.")
	_remove_support_bundle()
	_report["initial_snapshot"] = RuntimeIssueLog.clear_issue_log()
	_expect(int((_report["initial_snapshot"] as Dictionary).get("record_count", -1)) == 0, "Issue log must start cleared for the smoke.")
	_append_support_bundle_fixtures()

	var record := RuntimeIssueLog.emit_error(
		"packaging",
		TEST_EVENT,
		TEST_MESSAGE,
		{
			"fixture": "packaged_runtime_issue_log",
			"absolute_path": "/home/private-player/save.json",
			"windows_path": "C:\\Users\\PrivatePlayer\\save.json",
			"auth_token": "secret-support-token",
			"resource_path": "res://content/scenarios.json",
			"vector": Vector2i(4, 9),
			"nested": {
				"color": Color(0.25, 0.5, 0.75, 1.0),
			},
		}
	)
	_report["emitted_record"] = record
	_report["final_snapshot"] = RuntimeIssueLog.issue_log_snapshot()
	_report["last_records"] = RuntimeIssueLog.last_issue_records(3)
	_report["latest_issue"] = _read_latest_issue()
	_report["support_bundle_result"] = RuntimeIssueLog.export_support_bundle(SettingsService.ensure_settings())
	_report["support_bundle"] = RuntimeIssueLog.support_bundle_snapshot()

	_expect(String(record.get("schema", "")) == RuntimeIssueLog.ISSUE_SCHEMA, "Runtime issue record schema mismatch.")
	_expect(String(record.get("severity", "")) == "error", "Runtime issue severity mismatch.")
	_expect(String(record.get("surface", "")) == "packaging", "Runtime issue surface mismatch.")
	_expect(String(record.get("event", "")) == TEST_EVENT, "Runtime issue event mismatch.")
	_expect(String(record.get("message", "")) == TEST_MESSAGE, "Runtime issue message mismatch.")
	_expect(record.get("metadata", {}) is Dictionary, "Runtime issue metadata must be a dictionary.")
	var metadata: Dictionary = record.get("metadata", {})
	_expect(metadata.get("vector", {}) is Dictionary, "Runtime issue metadata must sanitize Vector2i values.")
	_expect(metadata.get("nested", {}) is Dictionary, "Runtime issue metadata must preserve nested dictionaries.")
	_expect(record.get("app", {}) is Dictionary and String(record.get("app", {}).get("name", "")) == "heroes-like", "Runtime issue app metadata mismatch.")
	_expect(record.get("platform", {}) is Dictionary and String(record.get("platform", {}).get("os", "")) != "", "Runtime issue platform metadata must include OS.")
	_expect(int((_report["final_snapshot"] as Dictionary).get("record_count", 0)) == 26, "Runtime issue log must contain the bounded-history fixture and smoke record.")
	_expect(FileAccess.file_exists(RuntimeIssueLog.ISSUE_LOG_PATH), "Runtime issue JSONL file must exist.")
	_expect(FileAccess.file_exists(RuntimeIssueLog.LATEST_ISSUE_PATH), "Latest runtime issue snapshot must exist.")
	_expect((_report["last_records"] as Array).size() == 3, "Runtime issue last-record reader must honor its requested limit.")
	_expect(String(((_report["last_records"] as Array)[2] as Dictionary).get("event", "")) == TEST_EVENT, "Runtime issue last record event mismatch.")
	_expect(String((_report["latest_issue"] as Dictionary).get("event", "")) == TEST_EVENT, "Latest runtime issue snapshot event mismatch.")
	var bundle_result: Dictionary = _report.get("support_bundle_result", {})
	var bundle: Dictionary = _report.get("support_bundle", {})
	var bundle_text := JSON.stringify(bundle)
	_expect(bool(bundle_result.get("ok", false)), "Support bundle export must succeed.")
	_expect(FileAccess.file_exists(RuntimeIssueLog.SUPPORT_BUNDLE_PATH), "Support bundle file must exist.")
	_expect(String(bundle.get("schema", "")) == RuntimeIssueLog.SUPPORT_BUNDLE_SCHEMA, "Support bundle schema mismatch.")
	_expect(int(bundle_result.get("size_bytes", 0)) > 0 and int(bundle_result.get("size_bytes", 0)) <= RuntimeIssueLog.MAX_SUPPORT_BUNDLE_BYTES, "Support bundle must stay inside its byte limit.")
	_expect(int(bundle.get("issue_log", {}).get("total_record_count", 0)) == 26, "Support bundle must report complete issue history size.")
	_expect(int(bundle.get("issue_log", {}).get("included_record_count", 0)) == 1, "Support bundle must trim oversized history while preserving the newest issue.")
	_expect(int(bundle.get("issue_log", {}).get("omitted_record_count", 0)) == 25, "Support bundle must report record-cap and byte-limit omissions.")
	_expect(int(bundle_result.get("issue_record_count", 0)) == 1 and int(bundle_result.get("omitted_issue_record_count", 0)) == 25, "Support bundle result must report bounded issue counts.")
	_expect(String((bundle.get("issue_log", {}).get("recent_issues", []) as Array)[0].get("event", "")) == TEST_EVENT, "Support bundle must retain the newest actionable issue after trimming.")
	_expect(bundle.get("device_settings", {}) is Dictionary and int(bundle.get("device_settings", {}).get("version", 0)) == SettingsService.SETTINGS_VERSION, "Support bundle must include normalized device settings.")
	_expect(String(bundle.get("app", {}).get("version", "")) != "", "Support bundle must include the application version.")
	_expect(bool(bundle.get("privacy", {}).get("local_only", false)) and not bool(bundle.get("privacy", {}).get("telemetry_uploaded", true)), "Support bundle privacy policy mismatch.")
	_expect(not bundle_text.contains("/home/private-player") and not bundle_text.contains("PrivatePlayer") and not bundle_text.contains("secret-support-token"), "Support bundle leaked private path or token metadata.")
	_expect(bundle_text.contains("res://content/scenarios.json"), "Support bundle must preserve safe project-relative diagnostic paths.")
	_expect(not bundle.has("absolute_path") and not bundle.has("save") and not bundle.has("campaign_progression"), "Support bundle exposed forbidden top-level state.")

func _remove_support_bundle() -> void:
	for path in [RuntimeIssueLog.SUPPORT_BUNDLE_PATH, RuntimeIssueLog.SUPPORT_BUNDLE_TEMP_PATH]:
		if not FileAccess.file_exists(path):
			continue
		var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		if error != OK:
			_error("Unable to clear support bundle fixture: %s." % error_string(error))

func _append_support_bundle_fixtures() -> void:
	var file := FileAccess.open(RuntimeIssueLog.ISSUE_LOG_PATH, FileAccess.READ_WRITE)
	if file == null:
		_error("Unable to open runtime issue log for support-bundle fixtures.")
		return
	file.seek_end()
	for index in range(24):
		file.store_string("%s\n" % JSON.stringify({
			"schema": RuntimeIssueLog.ISSUE_SCHEMA,
			"severity": "info",
			"surface": "fixture",
			"event": "support_history_%02d" % index,
			"message": "Bounded support history fixture.",
			"metadata": {"fixture_index": index},
		}))
	var oversized_metadata := {}
	for index in range(300):
		oversized_metadata["field_%03d" % index] = "x".repeat(2000)
	file.store_string("%s\n" % JSON.stringify({
		"schema": RuntimeIssueLog.ISSUE_SCHEMA,
		"severity": "warning",
		"surface": "fixture",
		"event": "oversized_support_history",
		"message": "Byte-bound support history fixture.",
		"metadata": oversized_metadata,
	}))
	file.close()

func _read_latest_issue() -> Dictionary:
	if not FileAccess.file_exists(RuntimeIssueLog.LATEST_ISSUE_PATH):
		return {}
	var file := FileAccess.open(RuntimeIssueLog.LATEST_ISSUE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}

func _report_path_from_args() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report-json="):
			return arg.trim_prefix("--report-json=")
	return ""

func _write_report_file(path: String, payload: Dictionary) -> void:
	var dir := path.get_base_dir()
	if dir != "":
		DirAccess.make_dir_recursive_absolute(dir)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_error("Unable to write packaged runtime issue report: %s." % path)
		return
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()

func _summary_payload() -> Dictionary:
	return {
		"ok": bool(_report.get("ok", false)),
		"issue_log_path": String(_report.get("issue_log_path", "")),
		"latest_issue_path": String(_report.get("latest_issue_path", "")),
		"ran_from_pack_scene": bool(_report.get("ran_from_pack_scene", false)),
		"record_count": int((_report.get("final_snapshot", {}) as Dictionary).get("record_count", 0)),
		"support_bundle_ok": bool(_report.get("support_bundle_result", {}).get("ok", false)),
		"support_bundle_size_bytes": int(_report.get("support_bundle_result", {}).get("size_bytes", 0)),
		"errors": _errors.duplicate(),
	}

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_error(message)

func _error(message: String) -> void:
	_errors.append(message)
	push_error(message)
