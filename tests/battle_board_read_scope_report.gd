extends Node

## Regression report for the battle board read scope (2026-10-07).
## BattleRules memoizes reachable hexes, attack legality, melee approaches and
## attackable target ids inside BattleRules.begin_board_read_scope(). For every
## encounter of a fixture scenario this report plays several player turns and,
## at each turn and for each selectable enemy target, runs the board reads the
## battle screen uses twice, from identical copies of the battle: once with the
## memo disabled and once inside a scope with it enabled. The answers, and the
## battle state the reads leave behind, must be identical. Fixture scenarios are
## only a source of varied armies and fields; their content is not checked.

const REPORT_ID := "BATTLE_BOARD_READ_SCOPE_REPORT"
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const SCENARIO_IDS := ["river-pass", "causeway-stand", "ninefold-confluence"]
const MAX_ENCOUNTERS_PER_SCENARIO := 10
const MAX_PLAYER_TURNS := 6

var _failures := []
var _comparisons := 0
var _evidence := []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var encounter_count := 0
	for scenario_id in SCENARIO_IDS:
		var probe_session = ScenarioFactory.create_session(String(scenario_id), "normal", SessionState.LAUNCH_MODE_SKIRMISH)
		var placement_ids := []
		for value in probe_session.overworld.get("encounters", []):
			if value is Dictionary and String(value.get("placement_id", "")) != "" and placement_ids.size() < MAX_ENCOUNTERS_PER_SCENARIO:
				placement_ids.append(String(value.get("placement_id", "")))
		for placement_id in placement_ids:
			_check_encounter(String(scenario_id), String(placement_id))
		encounter_count += placement_ids.size()
	BattleRulesScript.validation_set_board_read_cache_enabled(true)
	var hits := BattleRulesScript.validation_board_read_cache_hits()
	var ok := _failures.is_empty() and _comparisons > 0 and hits > 0
	var report := {
		"ok": ok,
		"encounters": encounter_count,
		"comparisons": _comparisons,
		"memo_hits": hits,
		"failures": _failures.slice(0, 10),
		"failure_count": _failures.size(),
		"evidence": _evidence,
	}
	if ok:
		print("%s %s" % [REPORT_ID, JSON.stringify(report)])
	else:
		push_error("%s failed: %s" % [REPORT_ID, JSON.stringify(report)])
	get_tree().quit(0 if ok else 1)


func _check_encounter(scenario_id: String, placement_id: String) -> void:
	var session = ScenarioFactory.create_session(scenario_id, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	var encounter := {}
	for value in session.overworld.get("encounters", []):
		if value is Dictionary and String(value.get("placement_id", "")) == placement_id:
			encounter = value
	session.battle = BattleRulesScript.create_battle_payload(session, encounter)
	if session.battle.is_empty():
		return
	session.game_state = "battle"
	SessionState.set_active_session(session)
	var turns := 0
	var compared_before := _comparisons
	var guard := 0
	while turns < MAX_PLAYER_TURNS and session.scenario_status == "in_progress" and not session.battle.is_empty() and guard < 40:
		guard += 1
		var active := BattleRulesScript.get_active_stack(session.battle)
		if String(active.get("side", "")) != "player":
			BattleRulesScript.perform_presented_action(session, "ready")
			if String(BattleRulesScript.get_active_stack(session.battle).get("side", "")) != "player":
				BattleRulesScript.advance_turn(session.battle)
			continue
		turns += 1
		var targets := [String(session.battle.get("selected_target_id", ""))]
		for stack in session.battle.get("stacks", []):
			if stack is Dictionary and String(stack.get("side", "")) == "enemy" and BattleRulesScript._alive_count(stack) > 0:
				targets.append(String(stack.get("battle_id", "")))
		for target_id in targets:
			if target_id != "" and target_id != String(session.battle.get("selected_target_id", "")):
				BattleRulesScript.select_target(session, target_id)
			_compare_reads(session, "%s turn %d target %s" % [placement_id, turns, target_id])
		var forecast := BattleRulesScript.intent_forecast_payload(session)
		var action_id := String(forecast.get("action_id", ""))
		if action_id == "" or action_id.begins_with("cast_spell:"):
			action_id = "defend"
		var result := BattleRulesScript.perform_presented_action(session, action_id)
		if not bool(result.get("ok", false)):
			BattleRulesScript.perform_presented_action(session, "defend")
	_evidence.append({"encounter": placement_id, "player_turns": turns, "comparisons": _comparisons - compared_before})


func _compare_reads(session, label: String) -> void:
	var base_battle: Dictionary = session.battle.duplicate(true)
	BattleRulesScript.validation_set_board_read_cache_enabled(false)
	session.battle = base_battle.duplicate(true)
	var plain := JSON.stringify(_reads(session))
	var plain_after: Dictionary = session.battle.duplicate(true)
	BattleRulesScript.validation_set_board_read_cache_enabled(true)
	session.battle = base_battle.duplicate(true)
	BattleRulesScript.begin_board_read_scope(session.battle)
	var memoized := JSON.stringify(_reads(session))
	BattleRulesScript.end_board_read_scope()
	var memoized_after: Dictionary = session.battle.duplicate(true)
	session.battle = base_battle
	_comparisons += 1
	if plain != memoized:
		_failures.append("%s: board reads differ with the scope memo" % label)
	elif plain_after != memoized_after:
		_failures.append("%s: board reads left a different battle state with the scope memo" % label)


func _reads(session) -> Dictionary:
	var battle: Dictionary = session.battle
	var active := BattleRulesScript.get_active_stack(battle)
	var per_target := {}
	for stack in battle.get("stacks", []):
		if not (stack is Dictionary) or String(stack.get("side", "")) != "enemy":
			continue
		var target_id := String(stack.get("battle_id", ""))
		per_target[target_id] = {
			"click": BattleRulesScript.board_click_attack_intent_for_target(battle, target_id),
			"approach": BattleRulesScript.melee_approach_destination(battle, active, stack),
		}
	return {
		"hex_state": BattleRulesScript.battle_hex_state_summary(battle),
		"destinations": BattleRulesScript.legal_destinations_for_active_stack(battle),
		"movement_intents": BattleRulesScript.legal_movement_intents_for_active_stack(battle),
		"attack_ids": BattleRulesScript.legal_attack_target_ids_for_active_stack(battle),
		"selected_click": BattleRulesScript.selected_target_board_click_intent(battle),
		"movement_click": BattleRulesScript.active_movement_board_click_intent(battle),
		"per_target": per_target,
		"intent_forecast": BattleRulesScript.intent_forecast_payload(session),
		"target_handoff": BattleRulesScript.target_handoff_cue_payload(session),
		"objective_check": BattleRulesScript.objective_check_cue_payload(session),
		"action_readiness": BattleRulesScript.action_readiness_confirmation_payload(session),
		"active_context": BattleRulesScript.describe_active_context(session),
		"target_context": BattleRulesScript.describe_target_context(session),
		"risk_board": BattleRulesScript.describe_risk_readiness_board(session),
		"action_surface": BattleRulesScript.get_action_surface(session),
	}
