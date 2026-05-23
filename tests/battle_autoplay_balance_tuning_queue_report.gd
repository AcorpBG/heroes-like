extends Node

const BattleAutoplayBalanceHarnessRulesScript = preload("res://scripts/core/BattleAutoplayBalanceHarnessRules.gd")

const REPORT_ID := "BATTLE_AUTOPLAY_BALANCE_TUNING_QUEUE_REPORT"
const REQUIRED_SCHEMA := "battle_autoplay_balance_tuning_queue_v1"
const REQUIRED_POLICY := "report_only_no_runtime_tuning"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var report: Dictionary = BattleAutoplayBalanceHarnessRulesScript.build_sampling_report()
	var repeat_report: Dictionary = BattleAutoplayBalanceHarnessRulesScript.build_sampling_report()
	var summary: Dictionary = report.get("summary", {}) if report.get("summary", {}) is Dictionary else {}
	var repeat_summary: Dictionary = repeat_report.get("summary", {}) if repeat_report.get("summary", {}) is Dictionary else {}
	var queue: Dictionary = summary.get("balance_tuning_queue", {}) if summary.get("balance_tuning_queue", {}) is Dictionary else {}
	var repeat_queue: Dictionary = repeat_summary.get("balance_tuning_queue", {}) if repeat_summary.get("balance_tuning_queue", {}) is Dictionary else {}
	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"schema": String(queue.get("schema", "")),
		"policy": String(queue.get("policy", "")),
		"status": String(queue.get("status", "")),
		"queue_signature": String(queue.get("queue_signature", "")),
		"repeat_queue_signature": String(repeat_queue.get("queue_signature", "")),
		"item_count": int(queue.get("item_count", 0)),
		"high_priority_count": int(queue.get("high_priority_count", 0)),
		"medium_priority_count": int(queue.get("medium_priority_count", 0)),
		"coverage": queue.get("coverage", {}),
		"top_contributors": queue.get("top_contributors", []),
	}
	if String(queue.get("schema", "")) != REQUIRED_SCHEMA:
		_fail("Battle autoplay tuning queue schema missing.", payload)
		return
	if String(queue.get("policy", "")) != REQUIRED_POLICY:
		_fail("Battle autoplay tuning queue must remain report-only/no-runtime-tuning.", payload)
		return
	if String(queue.get("queue_signature", "")) == "" or String(queue.get("queue_signature", "")) != String(repeat_queue.get("queue_signature", "")):
		_fail("Battle autoplay tuning queue signature is missing or non-deterministic.", payload)
		return
	if int(queue.get("item_count", 0)) <= 0:
		_fail("Battle autoplay tuning queue should expose actionable current watch items.", payload)
		return
	if not _assert_queue_items(queue, payload):
		return
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _assert_queue_items(queue: Dictionary, payload: Dictionary) -> bool:
	var items: Array = queue.get("items", []) if queue.get("items", []) is Array else []
	var top_contributors: Array = queue.get("top_contributors", []) if queue.get("top_contributors", []) is Array else []
	var coverage: Dictionary = queue.get("coverage", {}) if queue.get("coverage", {}) is Dictionary else {}
	if items.size() != int(queue.get("item_count", -1)):
		_fail("Battle autoplay tuning queue item count mismatch.", payload)
		return false
	if top_contributors.is_empty() or top_contributors.size() > 5:
		_fail("Battle autoplay tuning queue top contributors should expose one to five items.", payload)
		return false
	var categories: Array = coverage.get("categories", []) if coverage.get("categories", []) is Array else []
	if not ("sample_terminal_margin_watch" in categories):
		_fail("Battle autoplay tuning queue should include current terminal-margin sample watch coverage.", payload)
		return false
	var previous_priority := 999
	var saw_remediation_hint := false
	for item in items:
		if not (item is Dictionary):
			_fail("Battle autoplay tuning queue item is not a dictionary.", payload)
			return false
		var entry: Dictionary = item
		for required_field in ["id", "category", "priority", "priority_band", "metric", "observed", "target", "source", "context", "suggested_owner", "remediation_hint"]:
			if not entry.has(required_field):
				_fail("Battle autoplay tuning queue item missing field: %s" % required_field, payload)
				return false
		var priority := int(entry.get("priority", 0))
		if priority > previous_priority:
			_fail("Battle autoplay tuning queue items must be sorted by descending priority.", payload)
			return false
		previous_priority = priority
		if String(entry.get("remediation_hint", "")) != "":
			saw_remediation_hint = true
	if not saw_remediation_hint:
		_fail("Battle autoplay tuning queue needs remediation hints.", payload)
		return false
	return true

func _fail(message: String, payload: Dictionary) -> void:
	payload["ok"] = false
	payload["error"] = message
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(1)
