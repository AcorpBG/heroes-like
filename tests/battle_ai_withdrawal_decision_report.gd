extends Node

const BattleAiRulesScript = preload("res://scripts/core/BattleAiRules.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "BATTLE_AI_WITHDRAWAL_DECISION_REPORT"

var _report := {
	"ok": true,
	"report_id": REPORT_ID,
	"slice": "battle-ai-withdrawal-decision-20260523-10184",
	"policy": "battle_ai_enemy_withdrawal_decision_v1",
	"cases": {},
}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_validate_retreat_decision()
	_validate_surrender_decision()
	_validate_locked_withdrawal()
	_validate_runtime_enemy_retreat()
	print("%s %s" % [REPORT_ID, JSON.stringify(_report)])
	get_tree().quit(0)

func _validate_retreat_decision() -> void:
	var session := _withdrawal_session(26, 100, true, false)
	var active_stack := BattleRulesScript.get_active_stack(session.battle)
	var decision := BattleAiRulesScript.choose_enemy_action(session.battle, active_stack, {})
	_expect_equal("retreat decision action", String(decision.get("action", "")), "retreat")
	_expect_equal("retreat decision policy", String(decision.get("scoring_policy", "")), "battle_ai_enemy_withdrawal_decision_v1")
	_expect_candidate_score("retreat decision candidate score", decision, "retreat")
	_report["cases"]["retreat_decision"] = decision

func _validate_surrender_decision() -> void:
	var session := _withdrawal_session(8, 100, false, true)
	var active_stack := BattleRulesScript.get_active_stack(session.battle)
	var decision := BattleAiRulesScript.choose_enemy_action(session.battle, active_stack, {})
	_expect_equal("surrender decision action", String(decision.get("action", "")), "surrender")
	_expect_equal("surrender decision policy", String(decision.get("scoring_policy", "")), "battle_ai_enemy_withdrawal_decision_v1")
	_expect_candidate_score("surrender decision candidate score", decision, "surrender")
	_report["cases"]["surrender_decision"] = decision

func _validate_locked_withdrawal() -> void:
	var session := _withdrawal_session(8, 100, false, false)
	session.battle["context"] = {"type": "town_defense"}
	var active_stack := BattleRulesScript.get_active_stack(session.battle)
	var decision := BattleAiRulesScript.choose_enemy_action(session.battle, active_stack, {})
	if String(decision.get("action", "")) in ["retreat", "surrender"]:
		_fail("locked withdrawal fixture selected an exit action: %s" % JSON.stringify(decision))
		return
	_report["cases"]["locked withdrawal"] = decision

func _validate_runtime_enemy_retreat() -> void:
	var session := _withdrawal_session(26, 100, true, false)
	var result := BattleRulesScript.resolve_if_battle_ready(session)
	_expect_equal("enemy retreat runtime state", String(result.get("state", "")), "victory")
	_expect_equal("enemy retreat last outcome", String(session.flags.get("last_battle_outcome", "")), "enemy_retreat")
	if not session.battle.is_empty():
		_fail("enemy retreat runtime did not clear battle: %s" % JSON.stringify(session.battle))
		return
	var snapshot: Dictionary = result.get("battle_exit_animation_snapshot", {}) if result.get("battle_exit_animation_snapshot", {}) is Dictionary else {}
	if snapshot.is_empty():
		_fail("enemy retreat runtime did not preserve battle_exit_animation_snapshot: %s" % JSON.stringify(result))
		return
	_expect_equal("enemy retreat snapshot outcome", String(snapshot.get("presentation_outcome", "")), "retreat")
	_expect_event("enemy retreat snapshot", snapshot, "enemy_shattered", "battle_unit_retreat", "retreat_withdraw_column")
	_report["cases"]["runtime_enemy_retreat"] = {
		"state": String(result.get("state", "")),
		"message": String(result.get("message", "")),
		"last_battle_outcome": String(session.flags.get("last_battle_outcome", "")),
		"snapshot_policy": String(snapshot.get("presentation_policy", "")),
		"queue": BattleRulesScript.animation_event_queue(snapshot),
	}

func _withdrawal_session(
	enemy_health: int,
	enemy_base_health: int,
	retreat_allowed: bool,
	surrender_allowed: bool
) -> SessionStateStoreScript.SessionData:
	var session := SessionStateStoreScript.SessionData.new(
		"battle-ai-withdrawal-decision-report",
		"battle-ai-withdrawal-decision-report",
		"hero_report",
		1,
		{
			"army": {"stacks": []},
			"encounters": [
				{
					"placement_id": "withdrawal_fixture",
					"encounter_id": "withdrawal_fixture",
					"enemy_army": {"id": "withdrawal_fixture_army", "name": "Withdrawal Fixture", "stacks": []},
				}
			],
			"resolved_encounters": [],
			"enemy_states": [],
		},
		"normal",
		SessionStateStoreScript.LAUNCH_MODE_SKIRMISH
	)
	session.battle = {
		"round": 4,
		"max_rounds": 99,
		"distance": 0,
		"terrain": "plains",
		"battlefield_tags": [],
		"combat_seed": 12345,
		"position": {"x": 0, "y": 0},
		"encounter_id": "withdrawal_fixture",
		"encounter_name": "Withdrawal Fixture",
		"resolved_key": "withdrawal_fixture",
		"context": {"type": "encounter"},
		"stacks": [
			_stack("enemy_shattered", "enemy", false, int(enemy_base_health / 10), 10, enemy_health, 1, 2, 1, 5, 0, 0),
			_stack("player_line", "player", false, 24, 10, 240, 6, 9, 7, 5, 1, 0),
		],
		"turn_order": ["enemy_shattered"],
		"turn_index": 0,
		"active_stack_id": "enemy_shattered",
		"selected_target_id": "player_line",
		"recent_events": [],
		"retreat_allowed": retreat_allowed,
		"surrender_allowed": surrender_allowed,
		"player_commander_state": {},
		"player_commander_source": {"type": "active_hero", "hero_id": "hero_report"},
		"enemy_hero": {},
		"field_objectives": [],
	}
	return session

func _stack(
	battle_id: String,
	side: String,
	ranged: bool,
	base_count: int,
	unit_hp: int,
	total_health: int,
	min_damage: int,
	max_damage: int,
	attack: int,
	defense: int,
	q: int,
	r: int
) -> Dictionary:
	return {
		"unit_id": battle_id,
		"name": battle_id,
		"side": side,
		"battle_id": battle_id,
		"count": int(ceil(float(max(0, total_health)) / float(max(1, unit_hp)))),
		"base_count": base_count,
		"unit_hp": unit_hp,
		"total_health": total_health,
		"min_damage": min_damage,
		"max_damage": max_damage,
		"attack": attack,
		"defense": defense,
		"initiative": 5,
		"cohesion": 4,
		"momentum": 0,
		"ranged": ranged,
		"shots_remaining": 0,
		"retaliations_left": 1,
		"abilities": [],
		"source_type": "encounter_army" if side == "enemy" else "hero_army",
		"encounter_key": "withdrawal_fixture" if side == "enemy" else "",
		"hero_id": "hero_report" if side == "player" else "",
		"hex": {"q": q, "r": r},
	}

func _expect_candidate_score(label: String, decision: Dictionary, action_id: String) -> void:
	var candidate_scores: Dictionary = decision.get("candidate_scores", {}) if decision.get("candidate_scores", {}) is Dictionary else {}
	if not candidate_scores.has(action_id):
		_fail("%s missing %s in candidate_scores: %s" % [label, action_id, JSON.stringify(decision)])

func _expect_event(label: String, battle: Dictionary, battle_id: String, event_id: String, state: String) -> void:
	for event in BattleRulesScript.animation_event_queue(battle):
		if not (event is Dictionary):
			continue
		if (
			String(event.get("battle_id", "")) == battle_id
			and String(event.get("event_id", "")) == event_id
			and String(event.get("state", "")) == state
		):
			return
	_fail("%s missing event %s/%s for %s in %s." % [label, event_id, state, battle_id, BattleRulesScript.animation_event_queue(battle)])

func _expect_equal(label: String, observed: String, expected: String) -> void:
	if observed != expected:
		_fail("%s expected %s, got %s." % [label, expected, observed])

func _fail(message: String) -> void:
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "error": message})])
	get_tree().quit(1)
