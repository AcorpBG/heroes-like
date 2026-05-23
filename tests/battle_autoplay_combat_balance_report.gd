extends Node

const BattleAutoplayBalanceHarnessRulesScript = preload("res://scripts/core/BattleAutoplayBalanceHarnessRules.gd")

const REPORT_ID := "BATTLE_AUTOPLAY_COMBAT_BALANCE_REPORT"
const MAX_AVERAGE_TERMINAL_MARGIN_PCT := 65
const REQUIRED_SAMPLE_LIMIT := 12

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var report: Dictionary = BattleAutoplayBalanceHarnessRulesScript.build_sampling_report()
	var summary: Dictionary = report.get("summary", {}) if report.get("summary", {}) is Dictionary else {}
	var samples: Array = report.get("samples", []) if report.get("samples", []) is Array else []
	var compact_samples := []
	for sample in samples:
		if not (sample is Dictionary):
			continue
		compact_samples.append({
			"scenario_id": String(sample.get("scenario_id", "")),
			"encounter_placement_id": String(sample.get("encounter_placement_id", "")),
			"encounter_id": String(sample.get("encounter_id", "")),
			"outcome_state": String(sample.get("outcome_state", "")),
			"round_reached": int(sample.get("round_reached", 0)),
			"player_health_remaining_pct": int(sample.get("player_health_remaining_pct", 0)),
			"enemy_health_remaining_pct": int(sample.get("enemy_health_remaining_pct", 0)),
			"terminal_health_margin_pct": int(sample.get("terminal_health_margin_pct", 0)),
			"damage_per_round": sample.get("damage_per_round", {}),
			"action_mix": sample.get("action_mix", {}),
			"pacing_band": String(sample.get("pacing_band", "")),
			"matchup_band": String((sample.get("initial_stack_profile", {}) as Dictionary).get("matchup_band", "")) if sample.get("initial_stack_profile", {}) is Dictionary else "",
			"side_power_scores": (sample.get("initial_stack_profile", {}) as Dictionary).get("side_power_scores", {}) if sample.get("initial_stack_profile", {}) is Dictionary else {},
		})
	var gate: Dictionary = summary.get("combat_feel_gate", {}) if summary.get("combat_feel_gate", {}) is Dictionary else {}
	var warnings: Array = gate.get("warnings", []) if gate.get("warnings", []) is Array else []
	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"policy": "authored_encounter_terminal_margin_balance_gate_v1",
		"max_average_terminal_margin_pct": MAX_AVERAGE_TERMINAL_MARGIN_PCT,
		"summary": summary,
		"samples": compact_samples,
	}
	if int(summary.get("average_terminal_health_margin_pct", 0)) > MAX_AVERAGE_TERMINAL_MARGIN_PCT:
		_fail("Average terminal health margin remains above target.", payload)
		return
	if int(summary.get("requested_sample_limit", 0)) < REQUIRED_SAMPLE_LIMIT or int(summary.get("sample_count", 0)) < REQUIRED_SAMPLE_LIMIT:
		_fail("Battle autoplay combat balance report did not reach expanded sample breadth.", payload)
		return
	if "high_terminal_health_margin" in warnings:
		_fail("Combat-feel threshold gate still reports high_terminal_health_margin.", payload)
		return
	if not _assert_balance_matrix(summary, payload):
		return
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _assert_balance_matrix(summary: Dictionary, payload: Dictionary) -> bool:
	var matrix: Dictionary = summary.get("balance_matrix", {}) if summary.get("balance_matrix", {}) is Dictionary else {}
	var gate: Dictionary = summary.get("balance_matrix_gate", {}) if summary.get("balance_matrix_gate", {}) is Dictionary else {}
	if String(matrix.get("schema", "")) != "battle_autoplay_balance_matrix_v1":
		_fail("Battle autoplay balance matrix schema missing.", payload)
		return false
	if String(gate.get("policy", "")) != "report_only_balance_matrix_thresholds_v1":
		_fail("Battle autoplay balance matrix gate policy missing.", payload)
		return false
	if String(gate.get("status", "")) != "pass":
		_fail("Battle autoplay balance matrix gate must pass without terminal-margin warnings: %s" % gate, payload)
		return false
	for section_id in ["difficulty", "terrain", "scenario", "matchup", "ability_presence"]:
		var section: Dictionary = matrix.get(section_id, {}) if matrix.get(section_id, {}) is Dictionary else {}
		if section.is_empty():
			_fail("Battle autoplay balance matrix missing section: %s" % section_id, payload)
			return false
	var difficulty: Dictionary = matrix.get("difficulty", {}) if matrix.get("difficulty", {}) is Dictionary else {}
	for required_difficulty in ["low", "medium", "high"]:
		if not difficulty.has(required_difficulty):
			_fail("Battle autoplay balance matrix missing difficulty cohort: %s" % required_difficulty, payload)
			return false
	var matchup: Dictionary = matrix.get("matchup", {}) if matrix.get("matchup", {}) is Dictionary else {}
	if not matchup.has("even") and not matchup.has("player_advantaged") and not matchup.has("player_disadvantaged"):
		_fail("Battle autoplay balance matrix missing matchup cohorts: %s" % matchup, payload)
		return false
	var outliers: Array = matrix.get("terminal_margin_outliers", []) if matrix.get("terminal_margin_outliers", []) is Array else []
	if outliers.size() != int(gate.get("terminal_margin_outlier_count", -1)):
		_fail("Battle autoplay balance matrix outlier count does not match gate: %s" % gate, payload)
		return false
	if not outliers.is_empty():
		_fail("Battle autoplay balance matrix still has terminal-margin outliers: %s" % outliers, payload)
		return false
	return true

func _fail(message: String, payload: Dictionary) -> void:
	payload["ok"] = false
	payload["error"] = message
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(1)
