extends Node

const BattleAutoplayBalanceHarnessRulesScript = preload("res://scripts/core/BattleAutoplayBalanceHarnessRules.gd")

const REPORT_ID := "BATTLE_AUTOPLAY_COMBAT_BALANCE_REPORT"
const MAX_AVERAGE_TERMINAL_MARGIN_PCT := 65

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
	if "high_terminal_health_margin" in warnings:
		_fail("Combat-feel threshold gate still reports high_terminal_health_margin.", payload)
		return
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _fail(message: String, payload: Dictionary) -> void:
	payload["ok"] = false
	payload["error"] = message
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(1)
