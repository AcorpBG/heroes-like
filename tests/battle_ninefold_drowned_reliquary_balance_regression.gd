extends Node

const BalanceHarness = preload("res://scripts/core/BattleAutoplayBalanceHarnessRules.gd")
const REPORT_ID := "BATTLE_NINEFOLD_DROWNED_RELIQUARY_BALANCE_REGRESSION"
const SCENARIO_ID := "ninefold-confluence"
const PLACEMENT_ID := "ninefold_drowned_reliquary_watch"
const LOCAL_ARMY_ID := "army_ninefold_drowned_reliquary_watch"
const SHARED_ARMY_ID := "army_neutral_tidepool_skiffyard_watch"
const MAX_TERMINAL_MARGIN_PCT := 90
const MIN_ROUND := 3
const MAX_ROUND := 8
const EXPECTED_STACK_COUNTS := {
	"unit_neutral_tidepool_cutters": 4,
	"unit_neutral_reefbolt_crews": 9,
}
const SHARED_STACK_COUNTS := {
	"unit_neutral_tidepool_cutters": 7,
	"unit_neutral_reefbolt_crews": 2,
}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	ContentService.clear_cache()
	var encounter := _encounter()
	if encounter.is_empty():
		_fail("Ninefold Confluence is missing the Drowned Reliquary guard.", {})
		return
	var army: Dictionary = encounter.get("enemy_army", {}) if encounter.get("enemy_army", {}) is Dictionary else {}
	var shared_army := ContentService.get_army_group(SHARED_ARMY_ID)
	var sample := BalanceHarness.run_battle_sample(SCENARIO_ID, encounter, 72, "normal")
	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"scenario_id": SCENARIO_ID,
		"placement_id": PLACEMENT_ID,
		"placement_army_id": String(army.get("id", "")),
		"shared_army_id": String(shared_army.get("id", "")),
		"outcome_state": String(sample.get("outcome_state", "")),
		"round_reached": int(sample.get("round_reached", 0)),
		"player_health_remaining_pct": int(sample.get("player_health_remaining_pct", 0)),
		"enemy_health_remaining_pct": int(sample.get("enemy_health_remaining_pct", 0)),
		"terminal_health_margin_pct": int(sample.get("terminal_health_margin_pct", 0)),
		"damage_per_round": sample.get("damage_per_round", {}),
		"action_mix": sample.get("action_mix", {}),
		"initial_stack_profile": sample.get("initial_stack_profile", {}),
	}
	if army.is_empty() or String(army.get("id", "")) != LOCAL_ARMY_ID:
		_fail_sample("Drowned Reliquary must own a placement-local army override.", payload, sample)
		return
	if _stack_counts(army) != EXPECTED_STACK_COUNTS:
		_fail_sample("Drowned Reliquary placement-local army drifted from its bounded pressure roster.", payload, sample)
		return
	if String(shared_army.get("id", "")) != SHARED_ARMY_ID or _stack_counts(shared_army) != SHARED_STACK_COUNTS:
		_fail_sample("Shared Tidepool Skiffyard army changed with the placement-local correction.", payload, sample)
		return
	if not bool(sample.get("completed", false)) or String(sample.get("outcome_state", "")) != "victory":
		_fail_sample("Drowned Reliquary no longer resolves as a bounded player victory.", payload, sample)
		return
	if String(sample.get("initial_stack_profile", {}).get("matchup_band", "")) != "player_advantaged":
		_fail_sample("Drowned Reliquary no longer preserves its player-advantaged matchup band.", payload, sample)
		return
	var round_reached := int(sample.get("round_reached", 0))
	if round_reached < MIN_ROUND or round_reached > MAX_ROUND:
		_fail_sample("Drowned Reliquary left its bounded battle-pacing window.", payload, sample)
		return
	if int(sample.get("terminal_health_margin_pct", 100)) > MAX_TERMINAL_MARGIN_PCT:
		_fail_sample("Drowned Reliquary remains above the matrix terminal-margin target.", payload, sample)
		return
	if int(sample.get("damage_per_round", {}).get("enemy", 0)) <= 2:
		_fail_sample("Drowned Reliquary still fails to apply meaningful enemy pressure.", payload, sample)
		return
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _encounter() -> Dictionary:
	for encounter in ContentService.get_scenario(SCENARIO_ID).get("encounters", []):
		if encounter is Dictionary and String(encounter.get("placement_id", "")) == PLACEMENT_ID:
			return encounter
	return {}

func _stack_counts(army: Dictionary) -> Dictionary:
	var counts := {}
	for stack in army.get("stacks", []):
		if stack is Dictionary:
			counts[String(stack.get("unit_id", ""))] = int(stack.get("count", 0))
	return counts

func _fail_sample(message: String, payload: Dictionary, sample: Dictionary) -> void:
	payload["turn_log"] = sample.get("turn_log", [])
	_fail(message, payload)

func _fail(message: String, payload: Dictionary) -> void:
	payload["ok"] = false
	payload["error"] = message
	push_error("%s failed: %s" % [REPORT_ID, message])
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(1)
