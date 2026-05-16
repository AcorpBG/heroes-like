extends Node

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const REPORT_ID := "RANDOM_MAP_SMALL_RETRY_SWEEP_REPORT"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures := []
	var summaries := []
	var seeds := ["1", "2", "3", "4", "5", "17", "27", "48", "10184"]
	for seed in seeds:
		for player_count in [2, 3, 4]:
			var config := ScenarioSelectRulesScript.build_random_map_player_config(
				seed,
				"",
				"",
				player_count,
				"land",
				false,
				"homm3_small",
				ScenarioSelectRulesScript.RANDOM_MAP_TEMPLATE_SELECTION_MODE_CATALOG_AUTO
			)
			var setup: Dictionary = ScenarioSelectRulesScript.build_random_map_skirmish_setup_with_retry(
				config,
				"normal",
				ScenarioSelectRulesScript.RANDOM_MAP_PLAYER_RETRY_POLICY
			)
			var retry: Dictionary = setup.get("retry_status", {}) if setup.get("retry_status", {}) is Dictionary else {}
			summaries.append({
				"seed": seed,
				"player_count": player_count,
				"ok": bool(setup.get("ok", false)),
				"attempt_count": int(retry.get("attempt_count", 0)),
				"retry_count": int(retry.get("retry_count", 0)),
				"normalized_seed": String(setup.get("normalized_seed", "")),
				"template_id": String(setup.get("template_id", "")),
				"failure_handoff": String(setup.get("failure_handoff", "")),
			})
			if not bool(setup.get("ok", false)):
				failures.append(summaries[summaries.size() - 1])
	if not failures.is_empty():
		push_error("%s failed: %s" % [REPORT_ID, JSON.stringify({
			"failure_count": failures.size(),
			"failures": failures.slice(0, 12),
		})])
		get_tree().quit(1)
		return
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"case_count": summaries.size(),
		"retry_cases": _retry_cases(summaries),
	})])
	get_tree().quit(0)

func _retry_cases(summaries: Array) -> Array:
	var cases := []
	for summary in summaries:
		if summary is Dictionary and int(summary.get("retry_count", 0)) > 0:
			cases.append(summary)
	return cases
