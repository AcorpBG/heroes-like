extends Node

const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "BATTLE_INTENT_FORECAST_REPORT"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var player_session := _adjacent_ranged_session()
	var selected_before := String(player_session.battle.get("selected_target_id", ""))
	var active_before := String(player_session.battle.get("active_stack_id", ""))
	var forecast: Dictionary = BattleRulesScript.intent_forecast_payload(player_session)
	if String(forecast.get("action_id", "")) != "strike":
		_fail("Intent forecast should use shared scored tactical order and prefer adjacent strike: %s" % JSON.stringify(forecast))
		return
	if String(forecast.get("target_battle_id", "")) != "enemy_front":
		_fail("Intent forecast did not keep the selected enemy target in the payload: %s" % JSON.stringify(forecast))
		return
	var visible := String(forecast.get("visible_text", ""))
	var tooltip := String(forecast.get("tooltip_text", ""))
	for token in ["Intent forecast:", "Strike", "enemy_front"]:
		if not visible.contains(token):
			_fail("Intent forecast visible text is missing %s: %s" % [token, visible])
			return
	for token in ["Intent Forecast", "Preferred order:", "Expected result:", "Why:", "Risk:", "Confidence:", "does not spend an action"]:
		if not tooltip.contains(token):
			_fail("Intent forecast tooltip is missing %s: %s" % [token, tooltip])
			return
	if not String(forecast.get("expected_result", "")).contains("Hit enemy_front"):
		_fail("Intent forecast expected result did not expose damage consequence: %s" % JSON.stringify(forecast))
		return
	if not String(forecast.get("confidence", "")).contains("scored pick"):
		_fail("Intent forecast did not expose tactical score confidence: %s" % JSON.stringify(forecast))
		return
	if String(player_session.battle.get("selected_target_id", "")) != selected_before or String(player_session.battle.get("active_stack_id", "")) != active_before:
		_fail("Intent forecast mutated battle selection/initiative state: before=%s/%s after=%s/%s" % [
			active_before,
			selected_before,
			String(player_session.battle.get("active_stack_id", "")),
			String(player_session.battle.get("selected_target_id", "")),
		])
		return

	var enemy_session := _adjacent_ranged_session()
	enemy_session.battle["active_stack_id"] = "enemy_front"
	var enemy_forecast: Dictionary = BattleRulesScript.intent_forecast_payload(enemy_session)
	if String(enemy_forecast.get("readiness", "")) != "locked" or not String(enemy_forecast.get("visible_text", "")).contains("enemy initiative"):
		_fail("Intent forecast did not truthfully lock during enemy initiative: %s" % JSON.stringify(enemy_forecast))
		return

	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"player_forecast": forecast,
		"enemy_forecast": enemy_forecast,
		"mutation_check": {
			"active_stack_id": String(player_session.battle.get("active_stack_id", "")),
			"selected_target_id": String(player_session.battle.get("selected_target_id", "")),
		},
	}
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _adjacent_ranged_session() -> SessionStateStoreScript.SessionData:
	var session := SessionStateStoreScript.SessionData.new(
		"battle-intent-forecast-report",
		"battle-intent-forecast-report",
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
		"turn_order": ["player_archer", "enemy_front"],
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
