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
		"issue_log_absolute": ProjectSettings.globalize_path(RuntimeIssueLog.ISSUE_LOG_PATH),
		"latest_issue_absolute": ProjectSettings.globalize_path(RuntimeIssueLog.LATEST_ISSUE_PATH),
		"ran_from_pack_scene": ResourceLoader.exists("res://tests/packaged_runtime_issue_log_report.tscn"),
		"initial_snapshot": {},
		"emitted_record": {},
		"final_snapshot": {},
		"last_records": [],
		"latest_issue": {},
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
	_expect(bool(_report.get("ran_from_pack_scene", false)), "Packaged runtime issue report scene must be loadable from res://.")
	_report["initial_snapshot"] = RuntimeIssueLog.clear_issue_log()
	_expect(int((_report["initial_snapshot"] as Dictionary).get("record_count", -1)) == 0, "Issue log must start cleared for the smoke.")

	var record := RuntimeIssueLog.emit_error(
		"packaging",
		TEST_EVENT,
		TEST_MESSAGE,
		{
			"fixture": "packaged_runtime_issue_log",
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
	_expect(int((_report["final_snapshot"] as Dictionary).get("record_count", 0)) == 1, "Runtime issue log must contain exactly one smoke record.")
	_expect(FileAccess.file_exists(RuntimeIssueLog.ISSUE_LOG_PATH), "Runtime issue JSONL file must exist.")
	_expect(FileAccess.file_exists(RuntimeIssueLog.LATEST_ISSUE_PATH), "Latest runtime issue snapshot must exist.")
	_expect((_report["last_records"] as Array).size() == 1, "Runtime issue last-record reader must return the smoke record.")
	_expect(String(((_report["last_records"] as Array)[0] as Dictionary).get("event", "")) == TEST_EVENT, "Runtime issue last record event mismatch.")
	_expect(String((_report["latest_issue"] as Dictionary).get("event", "")) == TEST_EVENT, "Latest runtime issue snapshot event mismatch.")

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
		"errors": _errors.duplicate(),
	}

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_error(message)

func _error(message: String) -> void:
	_errors.append(message)
	push_error(message)
