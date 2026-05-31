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
	var enemy_engaged_case := _validate_enemy_engaged_melee_attack()
	if not bool(enemy_engaged_case.get("ok", false)):
		return
	var commander_payload_case := _validate_tactical_order_argument_commander_payload()
	if not bool(commander_payload_case.get("ok", false)):
		return

	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"policy": "shared_battle_ai_nonspell_tactical_scoring_for_balance_autoplay",
		"initial_availability": initial_availability,
		"decision": decision,
		"enemy_engaged_melee": enemy_engaged_case,
		"argument_commander_payload": commander_payload_case,
		"selected_target_id": String(session.battle.get("selected_target_id", "")),
	}
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _validate_enemy_engaged_melee_attack() -> Dictionary:
	var session := _engaged_enemy_melee_session()
	var active_stack := BattleRulesScript.get_active_stack(session.battle)
	var decision := BattleAiRules.choose_enemy_action(session.battle, active_stack, {})
	if String(decision.get("action", "")) != "strike":
		_fail("Engaged enemy melee stack should strike instead of bracing into no-progress defense: %s" % JSON.stringify(decision))
		return {}
	var candidate_scores: Dictionary = decision.get("candidate_scores", {}) if decision.get("candidate_scores", {}) is Dictionary else {}
	if not candidate_scores.has("defend") or not candidate_scores.has("strike"):
		_fail("Engaged melee decision is missing defend/strike candidate evidence: %s" % JSON.stringify(decision))
		return {}
	if float(candidate_scores.get("defend", 0.0)) <= float(candidate_scores.get("strike", 0.0)):
		_fail("Engaged melee fixture must prove strike beats a higher defend score only by no-progress guard: %s" % JSON.stringify(decision))
		return {}
	var tactical_order := BattleAiRules.choose_stack_tactical_order(session.battle, active_stack, "player")
	if String(tactical_order.get("action", "")) != "strike":
		_fail("Shared tactical order should also force engaged melee strike: %s" % JSON.stringify(tactical_order))
		return {}
	return {
		"ok": true,
		"live_action": String(decision.get("action", "")),
		"live_target_id": String(decision.get("target_battle_id", "")),
		"defend_score": float(candidate_scores.get("defend", 0.0)),
		"strike_score": float(candidate_scores.get("strike", 0.0)),
		"tactical_order_action": String(tactical_order.get("action", "")),
	}

func _validate_tactical_order_argument_commander_payload() -> Dictionary:
	var session := _engaged_enemy_melee_session()
	var active_stack := BattleRulesScript.get_active_stack(session.battle)
	var baseline := BattleAiRules.choose_stack_tactical_order(session.battle, active_stack, "player")
	var commander := {
		"hero_id": "test_vanguard_commander",
		"archetype": "marshal",
		"command_path": "might",
		"battle_traits": ["vanguard"],
		"command": {"attack": 0, "defense": 0, "power": 0, "knowledge": 0},
	}
	var bridged := BattleAiRules.choose_stack_tactical_order(session.battle, active_stack, "player", commander)
	var baseline_scores: Dictionary = baseline.get("candidate_scores", {}) if baseline.get("candidate_scores", {}) is Dictionary else {}
	var bridged_scores: Dictionary = bridged.get("candidate_scores", {}) if bridged.get("candidate_scores", {}) is Dictionary else {}
	if String(bridged.get("commander_payload_source", "")) != "argument":
		_fail("Tactical order did not report argument commander payload source: %s" % JSON.stringify(bridged))
		return {}
	if not baseline_scores.has("strike") or not bridged_scores.has("strike"):
		_fail("Tactical order payload bridge case is missing strike score evidence: baseline=%s bridged=%s" % [JSON.stringify(baseline), JSON.stringify(bridged)])
		return {}
	if float(bridged_scores.get("strike", 0.0)) <= float(baseline_scores.get("strike", 0.0)):
		_fail("Vanguard argument commander payload did not improve non-spell strike scoring: baseline=%s bridged=%s" % [JSON.stringify(baseline), JSON.stringify(bridged)])
		return {}
	var enemy_battle_state := session.battle.duplicate(true)
	enemy_battle_state["enemy_hero"] = commander.duplicate(true)
	var enemy_state_fallback := BattleAiRules.choose_stack_tactical_order(enemy_battle_state, active_stack, "player")
	var enemy_state_scores: Dictionary = enemy_state_fallback.get("candidate_scores", {}) if enemy_state_fallback.get("candidate_scores", {}) is Dictionary else {}
	if String(enemy_state_fallback.get("commander_payload_source", "")) != "battle":
		_fail("Enemy battle-state commander fallback did not report battle payload source: %s" % JSON.stringify(enemy_state_fallback))
		return {}
	if float(enemy_state_scores.get("strike", 0.0)) <= float(baseline_scores.get("strike", 0.0)):
		_fail("Enemy battle-state vanguard commander did not improve non-spell strike scoring: baseline=%s fallback=%s" % [JSON.stringify(baseline), JSON.stringify(enemy_state_fallback)])
		return {}
	if enemy_battle_state.has("enemy_hero_payload"):
		_fail("Enemy battle-state commander fallback mutated source battle state: %s" % JSON.stringify(enemy_battle_state))
		return {}
	var player_session := _adjacent_ranged_session()
	player_session.battle["battlefield_tags"] = ["elevated_fire"]
	var player_active := BattleRulesScript.get_active_stack(player_session.battle)
	var player_baseline := BattleAiRules.choose_stack_tactical_order(player_session.battle, player_active, "enemy")
	var player_commander := {
		"hero_id": "test_player_vanguard_commander",
		"archetype": "marshal",
		"command_path": "might",
		"battle_traits": ["vanguard"],
		"command": {"attack": 0, "defense": 0, "power": 0, "knowledge": 0},
	}
	var player_battle_state := player_session.battle.duplicate(true)
	player_battle_state["player_commander_state"] = player_commander.duplicate(true)
	var player_state_fallback := BattleAiRules.choose_stack_tactical_order(player_battle_state, player_active, "enemy")
	var player_baseline_scores: Dictionary = player_baseline.get("candidate_scores", {}) if player_baseline.get("candidate_scores", {}) is Dictionary else {}
	var player_state_scores: Dictionary = player_state_fallback.get("candidate_scores", {}) if player_state_fallback.get("candidate_scores", {}) is Dictionary else {}
	var player_action_key := String(player_state_fallback.get("action", ""))
	if String(player_state_fallback.get("commander_payload_source", "")) != "battle":
		_fail("Player battle-state commander fallback did not report battle payload source: %s" % JSON.stringify(player_state_fallback))
		return {}
	if player_action_key == "" or not player_baseline_scores.has(player_action_key) or not player_state_scores.has(player_action_key):
		_fail("Player battle-state commander fallback did not expose comparable action score evidence: baseline=%s fallback=%s" % [JSON.stringify(player_baseline), JSON.stringify(player_state_fallback)])
		return {}
	if float(player_state_scores.get(player_action_key, 0.0)) <= float(player_baseline_scores.get(player_action_key, 0.0)):
		_fail("Player battle-state vanguard commander did not improve non-spell action scoring: baseline=%s fallback=%s" % [JSON.stringify(player_baseline), JSON.stringify(player_state_fallback)])
		return {}
	if player_battle_state.has("player_hero"):
		_fail("Player battle-state commander fallback mutated source battle state: %s" % JSON.stringify(player_battle_state))
		return {}
	if session.battle.has("enemy_hero_payload") or session.battle.has("player_hero"):
		_fail("Argument commander payload bridge mutated source battle state: %s" % JSON.stringify(session.battle))
		return {}
	return {
		"ok": true,
		"baseline_source": String(baseline.get("commander_payload_source", "")),
		"bridged_source": String(bridged.get("commander_payload_source", "")),
		"baseline_strike_score": float(baseline_scores.get("strike", 0.0)),
		"bridged_strike_score": float(bridged_scores.get("strike", 0.0)),
		"enemy_battle_state_source": String(enemy_state_fallback.get("commander_payload_source", "")),
		"enemy_battle_state_strike_score": float(enemy_state_scores.get("strike", 0.0)),
		"player_battle_state_source": String(player_state_fallback.get("commander_payload_source", "")),
		"player_battle_state_action": player_action_key,
		"player_battle_state_action_score": float(player_state_scores.get(player_action_key, 0.0)),
		"source_battle_mutated": session.battle.has("enemy_hero_payload") or session.battle.has("player_hero"),
		"enemy_battle_state_mutated": enemy_battle_state.has("enemy_hero_payload"),
		"player_battle_state_mutated": player_battle_state.has("player_hero"),
	}

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

func _engaged_enemy_melee_session() -> SessionStateStoreScript.SessionData:
	var session := SessionStateStoreScript.SessionData.new(
		"battle-ai-engaged-melee-attack-report",
		"battle-ai-engaged-melee-attack-report",
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
		"combat_seed": 67890,
		"stacks": [
			_stack("enemy_guard", "enemy", "enemy_guard", false, 10, 10, 20, 1, 1, 2, 5, 2, 4, 3, ["brace"]),
			_stack("player_wall", "player", "player_wall", false, 20, 20, 400, 1, 1, 1, 8, 7, 5, 3),
		],
		"turn_order": ["enemy_guard"],
		"turn_index": 0,
		"active_stack_id": "enemy_guard",
		"selected_target_id": "player_wall",
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
	r: int,
	abilities: Array = []
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
		"abilities": abilities,
		"hex": {"q": q, "r": r},
	}

func _fail(message: String) -> void:
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "error": message})])
	get_tree().quit(1)
