extends Node

const BattleAutoplayBalanceHarnessRulesScript = preload("res://scripts/core/BattleAutoplayBalanceHarnessRules.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "BATTLE_AUTOPLAY_TACTICAL_ORDER_REPORT"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var session := _adjacent_ranged_session()
	var initial_availability: Dictionary = BattleRulesScript.action_availability(session.battle)
	if not bool(initial_availability.get("shoot", false)) or not bool(initial_availability.get("strike", false)):
		_fail("Fixture must expose both shoot and strike before scored autoplay selection: %s" % JSON.stringify(initial_availability))
		return

	var decision := BattleAutoplayBalanceHarnessRulesScript.player_autoplay_decision_report(session, true)
	if String(decision.get("scoring_policy", "")) != "battle_ai_nonspell_tactical_order_v1":
		_fail("Autoplay decision did not use the shared tactical score policy: %s" % JSON.stringify(decision))
		return
	if String(decision.get("action", "")) != "strike":
		_fail("Adjacent ranged fixture should choose scored melee strike over legacy shoot-first order: %s" % JSON.stringify(decision))
		return
	if String(session.battle.get("selected_target_id", "")) != "enemy_front":
		_fail("Scored autoplay decision did not apply its target selection: %s" % JSON.stringify(session.battle))
		return
	var candidate_scores: Dictionary = decision.get("candidate_scores", {}) if decision.get("candidate_scores", {}) is Dictionary else {}
	if not candidate_scores.has("strike") or not candidate_scores.has("defend") or not candidate_scores.has("advance"):
		_fail("Autoplay decision is missing candidate score evidence: %s" % JSON.stringify(decision))
		return

	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"policy": "shared_battle_ai_nonspell_tactical_scoring_for_balance_autoplay",
		"initial_availability": initial_availability,
		"decision": decision,
		"selected_target_id": String(session.battle.get("selected_target_id", "")),
	}
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _adjacent_ranged_session() -> SessionStateStoreScript.SessionData:
	var session := SessionStateStoreScript.SessionData.new(
		"battle-autoplay-tactical-order-report",
		"battle-autoplay-tactical-order-report",
		"hero_report",
		1,
		{},
		"normal",
		SessionStateStoreScript.LAUNCH_MODE_SKIRMISH
	)
	session.battle = {
		"round": 2,
		"max_rounds": 99,
		"distance": 0,
		"terrain": "plains",
		"battlefield_tags": [],
		"combat_seed": 12345,
		"stacks": [
			_stack("player_archer", "player", "player_archer", true, 6, 6, 36, 2, 4, 4, 2, 7, 3, 3),
			_stack("enemy_front", "enemy", "enemy_front", false, 4, 5, 18, 1, 2, 2, 1, 5, 4, 3),
		],
		"turn_order": ["player_archer"],
		"turn_index": 0,
		"active_stack_id": "player_archer",
		"selected_target_id": "enemy_front",
		"recent_events": [],
		"retreat_allowed": true,
		"surrender_allowed": true,
		"player_commander_state": {},
		"enemy_hero": {},
		"field_objectives": [],
	}
	return session

func _stack(
	unit_id: String,
	side: String,
	battle_id: String,
	ranged: bool,
	count: int,
	unit_hp: int,
	total_health: int,
	min_damage: int,
	max_damage: int,
	attack: int,
	defense: int,
	cohesion: int,
	q: int,
	r: int
) -> Dictionary:
	return {
		"unit_id": unit_id,
		"name": battle_id,
		"side": side,
		"battle_id": battle_id,
		"count": count,
		"base_count": count,
		"unit_hp": unit_hp,
		"total_health": total_health,
		"min_damage": min_damage,
		"max_damage": max_damage,
		"attack": attack,
		"defense": defense,
		"initiative": 5,
		"cohesion": cohesion,
		"momentum": 0,
		"ranged": ranged,
		"shots_remaining": 4 if ranged else 0,
		"retaliations_left": 1,
		"abilities": [],
		"hex": {"q": q, "r": r},
	}

func _fail(message: String) -> void:
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "error": message})])
	get_tree().quit(1)
