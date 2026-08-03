extends Node

const BattleAutoplayBalanceHarnessRulesScript = preload("res://scripts/core/BattleAutoplayBalanceHarnessRules.gd")
const REPORT_ID := "BATTLE_GHOUL_GROVE_BALANCE_REGRESSION"
const SCENARIO_ID := "river-pass"
const PLACEMENT_ID := "river_pass_ghoul_grove"
const LOCAL_ARMY_ID := "army_river_pass_ghoul_grove_watch"
const LOCAL_STACK_COUNTS := {"unit_blackbranch_cutthroat": 8, "unit_mire_slinger": 16, "unit_bog_brute": 2, "unit_mireclaw_mudglass_slingers": 1}
const SHARED_ARMY_ID := "army_blackbranch_raiders"
const SHARED_STACK_COUNTS := {"unit_blackbranch_cutthroat": 11, "unit_mire_slinger": 6, "unit_bog_brute": 2}
const SAMPLE_CONTRACTS := {
	"normal": {"outcome_state": "victory", "pacing_band": "standard", "round_reached": 5, "terminal_health_margin_pct": 66, "enemy_damage_per_round": 9},
	"hard": {"outcome_state": "defeat", "pacing_band": "standard", "round_reached": 3, "terminal_health_margin_pct": 74, "enemy_damage_per_round": 42},
}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	ContentService.clear_cache()
	var encounter := _encounter()
	if encounter.is_empty():
		_fail("River Pass is missing the Ghoul Grove encounter placement.", {})
		return
	var local_army: Dictionary = encounter.get("enemy_army", {}) if encounter.get("enemy_army", {}) is Dictionary else {}
	if String(local_army.get("id", "")) != LOCAL_ARMY_ID or _stack_counts(local_army) != LOCAL_STACK_COUNTS:
		_fail("Ghoul Grove placement-local army drifted from its bounded opening roster.", {})
		return
	var shared_army := ContentService.get_army_group(SHARED_ARMY_ID)
	if String(shared_army.get("id", "")) != SHARED_ARMY_ID or _stack_counts(shared_army) != SHARED_STACK_COUNTS:
		_fail("Shared Blackbranch Raiders changed with the placement-local Ghoul Grove correction.", {})
		return
	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"scenario_id": SCENARIO_ID,
		"placement_id": PLACEMENT_ID,
		"samples": {},
	}
	for launch_difficulty in ["normal", "hard"]:
		var sample := BattleAutoplayBalanceHarnessRulesScript.run_battle_sample(
			SCENARIO_ID,
			encounter,
			72,
			launch_difficulty
		)
		payload["samples"][launch_difficulty] = _compact_sample(sample)
		if not bool(sample.get("completed", false)) or not _sample_matches(sample, SAMPLE_CONTRACTS[launch_difficulty]):
			_fail_sample("Ghoul Grove drifted from its bounded %s outcome." % launch_difficulty, payload, launch_difficulty, sample)
			return
	if String(payload["samples"]["normal"].get("outcome_state", "")) != "victory" or String(payload["samples"]["hard"].get("outcome_state", "")) != "defeat":
		_fail("Ghoul Grove launch difficulty is no longer monotonic.", payload)
		return
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _compact_sample(sample: Dictionary) -> Dictionary:
	return {
		"outcome_state": String(sample.get("outcome_state", "")),
		"round_reached": int(sample.get("round_reached", 0)),
		"player_health_remaining_pct": int(sample.get("player_health_remaining_pct", 0)),
		"enemy_health_remaining_pct": int(sample.get("enemy_health_remaining_pct", 0)),
		"terminal_health_margin_pct": int(sample.get("terminal_health_margin_pct", 0)),
		"damage_per_round": sample.get("damage_per_round", {}),
		"action_mix": sample.get("action_mix", {}),
		"initial_stack_profile": sample.get("initial_stack_profile", {}),
	}

func _fail_sample(message: String, payload: Dictionary, launch_difficulty: String, sample: Dictionary) -> void:
	payload["samples"][launch_difficulty]["turn_log"] = sample.get("turn_log", [])
	_fail(message, payload)

func _encounter() -> Dictionary:
	var scenario := ContentService.get_scenario(SCENARIO_ID)
	for encounter in scenario.get("encounters", []):
		if encounter is Dictionary and String(encounter.get("placement_id", "")) == PLACEMENT_ID:
			return encounter
	return {}

func _stack_counts(army: Dictionary) -> Dictionary:
	var counts := {}
	for stack in army.get("stacks", []):
		if stack is Dictionary:
			counts[String(stack.get("unit_id", ""))] = int(stack.get("count", 0))
	return counts

func _sample_matches(sample: Dictionary, expected: Dictionary) -> bool:
	return (
		String(sample.get("outcome_state", "")) == String(expected.get("outcome_state", ""))
		and String(sample.get("pacing_band", "")) == String(expected.get("pacing_band", ""))
		and int(sample.get("round_reached", 0)) == int(expected.get("round_reached", -1))
		and int(sample.get("terminal_health_margin_pct", -1)) == int(expected.get("terminal_health_margin_pct", -1))
		and int(sample.get("damage_per_round", {}).get("enemy", -1)) == int(expected.get("enemy_damage_per_round", -1))
	)

func _fail(message: String, payload: Dictionary) -> void:
	payload["ok"] = false
	payload["error"] = message
	push_error("%s failed: %s" % [REPORT_ID, message])
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(1)
