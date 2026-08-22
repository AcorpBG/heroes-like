extends Node

const BattleAutoplayBalanceHarnessRulesScript = preload("res://scripts/core/BattleAutoplayBalanceHarnessRules.gd")
const REPORT_ID := "BATTLE_BELLWAKE_WRECK_BALANCE_REGRESSION"
const SCENARIO_ID := "bellwake-wreck-claim"
const MAX_TERMINAL_MARGIN_PCT := 90
const MAX_COHORT_TERMINAL_MARGIN_PCT := 69
const PLACEMENT_IDS := [
	"bellwake_relay_pickets",
	"bellwake_mirror_lancers",
	"bellwake_aurora_battery",
]
const LOCAL_ARMY_CONTRACTS := {
	"bellwake_relay_pickets": {
		"army_id": "army_bellwake_relay_pickets_watch",
		"stack_counts": {"unit_shard_guard": 9, "unit_prism_adept": 7, "unit_mirror_duelist": 8},
	},
	"bellwake_mirror_lancers": {
		"army_id": "army_bellwake_mirror_lancers_watch",
		"stack_counts": {"unit_shard_guard": 9, "unit_prism_adept": 8, "unit_mirror_duelist": 8, "unit_sunvault_resonant_choristers": 5},
	},
	"bellwake_aurora_battery": {
		"army_id": "army_bellwake_aurora_battery_watch",
		"stack_counts": {"unit_shard_guard": 8, "unit_prism_adept": 6, "unit_aurora_ballista": 3},
	},
}
const SHARED_ARMY_CONTRACTS := {
	"army_relay_pickets": {"unit_shard_guard": 5, "unit_prism_adept": 2},
	"army_mirror_lancers": {"unit_mirror_duelist": 6, "unit_shard_guard": 4, "unit_prism_adept": 4},
	"army_aurora_battery": {"unit_aurora_ballista": 1, "unit_prism_adept": 3, "unit_shard_guard": 3},
}
const SAMPLE_CONTRACTS := {
	"bellwake_relay_pickets": {"outcome_state": "victory", "pacing_band": "standard", "round_reached": 3, "terminal_health_margin_pct": 66, "enemy_damage_per_round": 13},
	"bellwake_mirror_lancers": {"outcome_state": "defeat", "pacing_band": "extended", "round_reached": 6, "terminal_health_margin_pct": 40, "enemy_damage_per_round": 49},
	"bellwake_aurora_battery": {"outcome_state": "victory", "pacing_band": "standard", "round_reached": 3, "terminal_health_margin_pct": 50, "enemy_damage_per_round": 25},
}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	ContentService.clear_cache()
	var payload := {"ok": true, "report_id": REPORT_ID, "scenario_id": SCENARIO_ID, "samples": [], "shared_army_ids": SHARED_ARMY_CONTRACTS.keys()}
	var failures := []
	var failed_turn_logs := {}
	var terminal_margin_total := 0
	for army_id in SHARED_ARMY_CONTRACTS:
		var shared_army := ContentService.get_army_group(String(army_id))
		if String(shared_army.get("id", "")) != army_id or _stack_counts(shared_army) != SHARED_ARMY_CONTRACTS[army_id]:
			failures.append("%s changed with the Bellwake placement-local correction" % army_id)
	for placement_id in PLACEMENT_IDS:
		var encounter := _encounter(String(placement_id))
		if encounter.is_empty():
			failures.append("%s is missing" % placement_id)
			continue
		if LOCAL_ARMY_CONTRACTS.has(placement_id):
			var local_army: Dictionary = encounter.get("enemy_army", {}) if encounter.get("enemy_army", {}) is Dictionary else {}
			var contract: Dictionary = LOCAL_ARMY_CONTRACTS[placement_id]
			if String(local_army.get("id", "")) != String(contract.get("army_id", "")) or _stack_counts(local_army) != contract.get("stack_counts", {}):
				failures.append("%s placement-local army drifted from its bounded pressure roster" % placement_id)
		var sample := BattleAutoplayBalanceHarnessRulesScript.run_battle_sample(SCENARIO_ID, encounter, 72, "normal")
		payload["samples"].append(_compact_sample(String(placement_id), sample))
		terminal_margin_total += int(sample.get("terminal_health_margin_pct", 100))
		var expected: Dictionary = SAMPLE_CONTRACTS[placement_id]
		if not bool(sample.get("completed", false)) or not _sample_matches(sample, expected):
			failures.append("%s drifted from its bounded cohort outcome" % placement_id)
			failed_turn_logs[placement_id] = sample.get("turn_log", [])
	var cohort_average := terminal_margin_total / PLACEMENT_IDS.size()
	payload["cohort_average_terminal_health_margin_pct"] = cohort_average
	if cohort_average > MAX_COHORT_TERMINAL_MARGIN_PCT:
		failures.append("Bellwake encounter cohort remains above its terminal-margin target")
	if not failures.is_empty():
		payload["failures"] = failures
		payload["turn_logs"] = failed_turn_logs
		_fail("Bellwake encounter balance regression failed.", payload)
		return
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _encounter(placement_id: String) -> Dictionary:
	var scenario := ContentService.get_scenario(SCENARIO_ID)
	for encounter in scenario.get("encounters", []):
		if encounter is Dictionary and String(encounter.get("placement_id", "")) == placement_id:
			return encounter
	return {}

func _compact_sample(placement_id: String, sample: Dictionary) -> Dictionary:
	return {
		"placement_id": placement_id,
		"outcome_state": String(sample.get("outcome_state", "")),
		"round_reached": int(sample.get("round_reached", 0)),
		"player_health_remaining_pct": int(sample.get("player_health_remaining_pct", 0)),
		"enemy_health_remaining_pct": int(sample.get("enemy_health_remaining_pct", 0)),
		"terminal_health_margin_pct": int(sample.get("terminal_health_margin_pct", 0)),
		"damage_per_round": sample.get("damage_per_round", {}),
		"action_mix": sample.get("action_mix", {}),
		"initial_stack_profile": sample.get("initial_stack_profile", {}),
	}

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
