extends Node

const BattleAutoplayBalanceHarnessRulesScript = preload("res://scripts/core/BattleAutoplayBalanceHarnessRules.gd")

const REPORT_ID := "BATTLE_AUTOPLAY_DIFFICULTY_SWEEP_REPORT"
const REQUIRED_SCHEMA := "battle_autoplay_difficulty_sweep_v1"
const REQUIRED_POLICY := "report_only_launch_difficulty_balance_probe"
const REQUIRED_DIFFICULTIES := ["normal", "hard"]
const REQUIRED_SAMPLE_LIMIT := 12
const MAX_NORMAL_TUNING_QUEUE_ITEMS := 0
const MAX_HARD_TUNING_QUEUE_ITEMS := 3

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var report: Dictionary = BattleAutoplayBalanceHarnessRulesScript.build_difficulty_sweep_report({
		"battle_difficulty_sweep_ids": REQUIRED_DIFFICULTIES,
		"battle_difficulty_sweep_sample_limit": REQUIRED_SAMPLE_LIMIT,
		"battle_difficulty_sweep_minimum_sample_count": REQUIRED_SAMPLE_LIMIT,
	})
	var repeat_report: Dictionary = BattleAutoplayBalanceHarnessRulesScript.build_difficulty_sweep_report({
		"battle_difficulty_sweep_ids": REQUIRED_DIFFICULTIES,
		"battle_difficulty_sweep_sample_limit": REQUIRED_SAMPLE_LIMIT,
		"battle_difficulty_sweep_minimum_sample_count": REQUIRED_SAMPLE_LIMIT,
	})
	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"schema": String(report.get("schema", "")),
		"policy": String(report.get("policy", "")),
		"status": String(report.get("status", "")),
		"sample_limit_per_difficulty": int(report.get("sample_limit_per_difficulty", 0)),
		"minimum_sample_count_per_difficulty": int(report.get("minimum_sample_count_per_difficulty", 0)),
		"rows": _compact_rows(report.get("rows", [])),
		"deltas": report.get("deltas", {}),
		"sweep_signature": String(report.get("sweep_signature", "")),
		"repeat_sweep_signature": String(repeat_report.get("sweep_signature", "")),
		"failure_count": int(report.get("failure_count", 0)),
		"warning_count": int(report.get("warning_count", 0)),
		"failures": report.get("failures", []),
	}
	if String(report.get("schema", "")) != REQUIRED_SCHEMA:
		_fail("Difficulty sweep schema missing.", payload)
		return
	if String(report.get("policy", "")) != REQUIRED_POLICY:
		_fail("Difficulty sweep must remain report-only.", payload)
		return
	if String(report.get("sweep_signature", "")) == "" or String(report.get("sweep_signature", "")) != String(repeat_report.get("sweep_signature", "")):
		_fail("Difficulty sweep signature is missing or non-deterministic.", payload)
		return
	if String(report.get("status", "")) != "pass":
		_fail("Difficulty sweep did not pass: %s" % JSON.stringify(report.get("failures", [])), payload)
		return
	if not _assert_rows(report, payload):
		return
	if not _assert_normal_hard_delta(report, payload):
		return
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _assert_rows(report: Dictionary, payload: Dictionary) -> bool:
	var rows: Array = report.get("rows", []) if report.get("rows", []) is Array else []
	var seen := {}
	for row in rows:
		if not (row is Dictionary):
			_fail("Difficulty sweep row is not a dictionary.", payload)
			return false
		var difficulty_id := String(row.get("difficulty_id", ""))
		seen[difficulty_id] = true
		if int(row.get("sample_count", 0)) < REQUIRED_SAMPLE_LIMIT:
			_fail("%s difficulty row did not reach required sample breadth." % difficulty_id, payload)
			return false
		if int(row.get("completed_sample_count", 0)) != int(row.get("sample_count", 0)):
			_fail("%s difficulty row did not complete every sample." % difficulty_id, payload)
			return false
		if int(row.get("stalled_sample_count", 0)) != 0 or int(row.get("invalid_order_count", 0)) != 0:
			_fail("%s difficulty row has stalled samples or invalid orders." % difficulty_id, payload)
			return false
		if String(row.get("combat_feel_gate_status", "")) == "fail" or String(row.get("balance_matrix_gate_status", "")) == "fail":
			_fail("%s difficulty row has a failed balance gate." % difficulty_id, payload)
			return false
		if difficulty_id == "normal" and not _assert_report_only_queue(row, MAX_NORMAL_TUNING_QUEUE_ITEMS, payload):
			return false
		if difficulty_id == "hard" and not _assert_report_only_queue(row, MAX_HARD_TUNING_QUEUE_ITEMS, payload):
			return false
		var launch_distribution: Dictionary = row.get("launch_difficulty_distribution", {}) if row.get("launch_difficulty_distribution", {}) is Dictionary else {}
		if int(launch_distribution.get(difficulty_id, 0)) != int(row.get("sample_count", 0)):
			_fail("%s difficulty row did not preserve launch difficulty on every sample: %s" % [difficulty_id, JSON.stringify(launch_distribution)], payload)
			return false
	for required_difficulty in REQUIRED_DIFFICULTIES:
		if not seen.has(required_difficulty):
			_fail("Difficulty sweep missing row: %s" % required_difficulty, payload)
			return false
	return true

func _assert_report_only_queue(row: Dictionary, max_item_count: int, payload: Dictionary) -> bool:
	var difficulty_id := String(row.get("difficulty_id", ""))
	if String(row.get("tuning_queue_signature", "")) == "":
		_fail("%s difficulty row missing tuning queue signature." % difficulty_id, payload)
		return false
	var item_count := int(row.get("tuning_queue_item_count", 0))
	if item_count > max_item_count:
		_fail("%s difficulty tuning queue exceeded the report-only watch allowance." % difficulty_id, payload)
		return false
	var queue_status := String(row.get("tuning_queue_status", ""))
	if queue_status not in ["clear", "watch"]:
		_fail("%s difficulty tuning queue must stay report-only clear/watch, not %s." % [difficulty_id, queue_status], payload)
		return false
	var top_contributors: Array = row.get("tuning_queue_top_contributors", []) if row.get("tuning_queue_top_contributors", []) is Array else []
	if item_count > 0 and top_contributors.is_empty():
		_fail("%s difficulty row should expose top tuning contributors while watches remain." % difficulty_id, payload)
		return false
	for item in top_contributors:
		if not (item is Dictionary):
			_fail("%s difficulty tuning contributor is not a dictionary." % difficulty_id, payload)
			return false
		if String(item.get("priority_band", "")) == "high" or int(item.get("priority", 0)) >= 80:
			_fail("%s difficulty tuning queue reopened high-priority work: %s" % [difficulty_id, JSON.stringify(item)], payload)
			return false
	return true

func _assert_normal_hard_delta(report: Dictionary, payload: Dictionary) -> bool:
	var deltas: Dictionary = report.get("deltas", {}) if report.get("deltas", {}) is Dictionary else {}
	var normal_vs_hard: Dictionary = deltas.get("normal_vs_hard", {}) if deltas.get("normal_vs_hard", {}) is Dictionary else {}
	if normal_vs_hard.is_empty():
		_fail("Difficulty sweep missing normal_vs_hard delta.", payload)
		return false
	if bool(normal_vs_hard.get("no_observed_effect", true)):
		_fail("Difficulty sweep did not observe any normal-vs-hard balance effect.", payload)
		return false
	var player_remaining_delta := int(normal_vs_hard.get("player_remaining_pct_delta", 0))
	var enemy_remaining_delta := int(normal_vs_hard.get("enemy_remaining_pct_delta", 0))
	var damage_delta := int(normal_vs_hard.get("total_damage_per_round_delta", 0))
	if player_remaining_delta == 0 and enemy_remaining_delta == 0 and damage_delta == 0:
		_fail("Difficulty sweep lacks health or damage pacing deltas.", payload)
		return false
	return true

func _compact_rows(rows_value: Variant) -> Array:
	var compact := []
	var rows: Array = rows_value if rows_value is Array else []
	for row in rows:
		if not (row is Dictionary):
			continue
		compact.append({
			"difficulty_id": String(row.get("difficulty_id", "")),
			"sample_count": int(row.get("sample_count", 0)),
			"completed_sample_count": int(row.get("completed_sample_count", 0)),
			"average_terminal_health_margin_pct": int(row.get("average_terminal_health_margin_pct", 0)),
			"average_total_damage_per_round": int(row.get("average_total_damage_per_round", 0)),
			"average_player_health_remaining_pct": int(row.get("average_player_health_remaining_pct", 0)),
			"average_enemy_health_remaining_pct": int(row.get("average_enemy_health_remaining_pct", 0)),
			"primary_outcome_state": String(row.get("primary_outcome_state", "")),
			"primary_outcome_pct": int(row.get("primary_outcome_pct", 0)),
			"combat_feel_gate_status": String(row.get("combat_feel_gate_status", "")),
			"balance_matrix_gate_status": String(row.get("balance_matrix_gate_status", "")),
			"tuning_queue_status": String(row.get("tuning_queue_status", "")),
			"tuning_queue_item_count": int(row.get("tuning_queue_item_count", 0)),
			"tuning_queue_signature": String(row.get("tuning_queue_signature", "")),
			"tuning_queue_categories": row.get("tuning_queue_categories", []),
			"tuning_queue_top_contributors": row.get("tuning_queue_top_contributors", []),
		})
	return compact

func _fail(message: String, payload: Dictionary) -> void:
	payload["ok"] = false
	payload["error"] = message
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(1)
