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
	for token in ["Suggested order:", "Strike", "enemy_front"]:
		if not visible.contains(token):
			_fail("Intent forecast visible text is missing %s: %s" % [token, visible])
			return
	for token in ["Order Preview", "Preferred order:", "Expected result:", "Why:", "Risk:", "Confidence:", "does not spend an action"]:
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

	var damage_spell_session := _damage_spell_session()
	var damage_spell_before: Dictionary = damage_spell_session.to_dict()
	var damage_spell_forecast: Dictionary = BattleRulesScript.intent_forecast_payload(damage_spell_session)
	if String(damage_spell_forecast.get("action_id", "")) != "cast_spell:spell_cinder_burst" \
			or String(damage_spell_forecast.get("target_battle_id", "")) != "enemy_spell_target" \
			or not String(damage_spell_forecast.get("visible_text", "")).contains("Cast Cinder Burst") \
			or not String(damage_spell_forecast.get("visible_text", "")).contains("enemy_spell_target") \
			or String(damage_spell_forecast.get("expected_result", "")) == "" \
			or damage_spell_session.to_dict() != damage_spell_before:
		_fail("Intent forecast did not preserve the exact ready enemy-target spell order without mutation: %s" % JSON.stringify(damage_spell_forecast))
		return

	var support_spell_session := _support_spell_session()
	var support_spell_before: Dictionary = support_spell_session.to_dict()
	var support_spell_forecast: Dictionary = BattleRulesScript.intent_forecast_payload(support_spell_session)
	var support_confirmation: Dictionary = BattleRulesScript.action_readiness_confirmation_payload(support_spell_session)
	if String(support_spell_forecast.get("action_id", "")) != "cast_spell:spell_stone_veil" \
			or String(support_spell_forecast.get("target_battle_id", "")) != "player_guard" \
			or String(support_spell_forecast.get("target", "")) != "player_guard" \
			or not String(support_spell_forecast.get("visible_text", "")).contains("Cast Stone Veil") \
			or String(support_spell_forecast.get("visible_text", "")).contains("Strike -> player_guard") \
			or not String(support_spell_forecast.get("expected_result", "")).contains("defense") \
			or String(support_confirmation.get("action_id", "")) != "strike" \
			or String(support_confirmation.get("target", "")) != "enemy_front" \
			or support_spell_session.to_dict() != support_spell_before:
		_fail("Intent forecast did not preserve the exact ready allied support-spell order while keeping legal Strike confirmation coherent: forecast=%s confirmation=%s" % [JSON.stringify(support_spell_forecast), JSON.stringify(support_confirmation)])
		return
	var rejected_spell_order := {
		"action": "cast_spell",
		"spell_id": "spell_stone_veil",
		"target_battle_id": "enemy_front",
	}
	var fallback_action_id: String = BattleRulesScript._intent_forecast_action_id(
		support_spell_session.battle,
		BattleRulesScript.get_action_surface(support_spell_session),
		BattleRulesScript.get_spell_actions(support_spell_session),
		rejected_spell_order,
		BattleRulesScript.get_active_stack(support_spell_session.battle)
	)
	if fallback_action_id != "strike" \
			or BattleRulesScript._intent_forecast_action_matches_tactical_order(fallback_action_id, rejected_spell_order) \
			or String(BattleRulesScript.get_selected_target(support_spell_session.battle).get("battle_id", "")) != "enemy_front" \
			or support_spell_session.to_dict() != support_spell_before:
		_fail("Rejected non-public spell target did not fall back to the legal selected-enemy Strike without retaining the spell target: action=%s" % fallback_action_id)
		return
	var unavailable_spell_session := _support_spell_session()
	var unavailable_spellbook: Dictionary = unavailable_spell_session.battle.get("player_commander_state", {}).get("spellbook", {})
	var unavailable_mana: Dictionary = unavailable_spellbook.get("mana", {})
	unavailable_mana["current"] = 0
	unavailable_spellbook["mana"] = unavailable_mana
	unavailable_spell_session.battle["player_commander_state"]["spellbook"] = unavailable_spellbook
	var unavailable_before: Dictionary = unavailable_spell_session.to_dict()
	var unavailable_spell_order := {
		"action": "cast_spell",
		"spell_id": "spell_stone_veil",
		"target_battle_id": "player_guard",
	}
	var unavailable_fallback_action_id: String = BattleRulesScript._intent_forecast_action_id(
		unavailable_spell_session.battle,
		BattleRulesScript.get_action_surface(unavailable_spell_session),
		BattleRulesScript.get_spell_actions(unavailable_spell_session),
		unavailable_spell_order,
		BattleRulesScript.get_active_stack(unavailable_spell_session.battle)
	)
	if unavailable_fallback_action_id != "strike" \
			or BattleRulesScript._intent_forecast_action_matches_tactical_order(unavailable_fallback_action_id, unavailable_spell_order) \
			or String(BattleRulesScript.get_selected_target(unavailable_spell_session.battle).get("battle_id", "")) != "enemy_front" \
			or unavailable_spell_session.to_dict() != unavailable_before:
		_fail("Unavailable Stone Veil did not fall back to the legal selected-enemy Strike without mutation: action=%s" % unavailable_fallback_action_id)
		return

	var enemy_session := _adjacent_ranged_session()
	enemy_session.battle["active_stack_id"] = "enemy_front"
	var enemy_forecast: Dictionary = BattleRulesScript.intent_forecast_payload(enemy_session)
	if String(enemy_forecast.get("readiness", "")) != "locked" or not String(enemy_forecast.get("visible_text", "")).contains("Incoming order:"):
		_fail("Intent forecast did not truthfully lock during enemy initiative: %s" % JSON.stringify(enemy_forecast))
		return

	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"player_forecast": forecast,
		"damage_spell_forecast": damage_spell_forecast,
		"support_spell_forecast": support_spell_forecast,
		"support_strike_confirmation": support_confirmation,
		"rejected_spell_fallback_action_id": fallback_action_id,
		"unavailable_spell_fallback_action_id": unavailable_fallback_action_id,
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

func _damage_spell_session() -> SessionStateStoreScript.SessionData:
	var session := SessionStateStoreScript.SessionData.new(
		"battle-intent-damage-spell-forecast-report",
		"battle-intent-damage-spell-forecast-report",
		"hero_report",
		1,
		{},
		"normal",
		SessionStateStoreScript.LAUNCH_MODE_SKIRMISH
	)
	session.battle = {
		"round": 2,
		"max_rounds": 99,
		"distance": 2,
		"terrain": "plains",
		"battlefield_tags": [],
		"combat_seed": 112233,
		"resistance_seed": "intent_damage_spell",
		"stacks": [
			_stack("player_apprentice", "player", "player_apprentice", false, 4, 8, 32, 1, 1, 1, 1, 4, 3, 3),
			_stack("enemy_spell_target", "enemy", "enemy_spell_target", true, 8, 8, 64, 4, 5, 4, 2, 5, 8, 3),
		],
		"turn_order": ["player_apprentice"],
		"turn_index": 0,
		"active_stack_id": "player_apprentice",
		"selected_target_id": "enemy_spell_target",
		"recent_events": [],
		"retreat_allowed": true,
		"surrender_allowed": true,
		"player_commander_state": {
			"hero_id": "intent_damage_spell_commander",
			"name": "Intent Damage Spell Commander",
			"archetype": "artillerist",
			"command_path": "magic",
			"command": {"attack": 0, "defense": 0, "power": 3, "knowledge": 8},
			"spellbook": {"known_spell_ids": ["spell_cinder_burst"], "mana": {"current": 20, "max": 20}},
		},
		"enemy_hero": {},
		"field_objectives": [],
	}
	return session

func _support_spell_session() -> SessionStateStoreScript.SessionData:
	var session := SessionStateStoreScript.SessionData.new(
		"battle-intent-support-spell-forecast-report",
		"battle-intent-support-spell-forecast-report",
		"hero_report",
		1,
		{},
		"normal",
		SessionStateStoreScript.LAUNCH_MODE_CAMPAIGN
	)
	session.battle = {
		"round": 1,
		"max_rounds": 12,
		"distance": 0,
		"terrain": "grass",
		"battlefield_tags": [],
		"combat_seed": 4201,
		"stacks": [
			_stack("unit_river_guard", "player", "player_guard", false, 4, 9, 36, 2, 4, 4, 3, 5, 3, 3),
			_stack("unit_blackbranch_cutthroat", "enemy", "enemy_front", false, 5, 8, 40, 3, 5, 5, 3, 5, 4, 3),
			_stack("unit_mire_slinger", "enemy", "enemy_slinger", true, 6, 7, 42, 2, 4, 4, 2, 5, 8, 2),
		],
		"turn_order": ["player_guard", "enemy_front", "enemy_slinger"],
		"turn_index": 0,
		"active_stack_id": "player_guard",
		"selected_target_id": "enemy_front",
		"recent_events": [],
		"retreat_allowed": true,
		"surrender_allowed": true,
		"player_commander_state": {
			"hero_id": "hero_caelen",
			"name": "Caelen Ashgrove",
			"archetype": "artillerist",
			"command_path": "magic",
			"command": {"attack": 1, "defense": 2, "power": 0, "knowledge": 1},
			"spellbook": {"known_spell_ids": ["spell_stone_veil"], "mana": {"current": 12, "max": 12}},
		},
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
