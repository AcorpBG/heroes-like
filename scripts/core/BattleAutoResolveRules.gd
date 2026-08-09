class_name BattleAutoResolveRules
extends RefCounted

const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")
const BattleRulesScript = preload("res://scripts/core/BattleRules.gd")
const BattleAiRulesScript = preload("res://scripts/core/BattleAiRules.gd")
const SpellRulesScript = preload("res://scripts/core/SpellRules.gd")

const DEFAULT_STEP_LIMIT := 72
const PLAYER_EXIT_ACTIONS := ["retreat", "surrender"]
const TERMINAL_STATES := [
	"victory",
	"defeat",
	"hero_defeat",
	"town_lost",
	"retreat",
	"surrender",
	"stalemate",
]


static func player_autoplay_decision(
	session: SessionStateStoreScript.SessionData,
	apply_selection: bool = false
) -> Dictionary:
	if session == null or session.battle.is_empty():
		return {
			"action": "defend",
			"reason": "no_active_battle",
			"scoring_policy": "battle_ai_nonspell_tactical_order_v1",
		}
	var active_stack: Dictionary = BattleRulesScript.get_active_stack(session.battle)
	if active_stack.is_empty() or String(active_stack.get("side", "")) != "player":
		return {
			"action": "defend",
			"reason": "no_active_player_stack",
			"scoring_policy": "battle_ai_nonspell_tactical_order_v1",
		}
	var commander_payload: Dictionary = (
		session.battle.get("player_hero", {})
		if session.battle.get("player_hero", {}) is Dictionary
		else {}
	)
	if commander_payload.is_empty() and session.battle.get("player_commander_state", {}) is Dictionary:
		commander_payload = session.battle.get("player_commander_state", {})
	var decision := BattleAiRulesScript.choose_stack_tactical_order(
		session.battle,
		active_stack,
		"enemy",
		commander_payload
	)
	if decision.is_empty():
		_select_focus_enemy(session)
		return _fallback_player_autoplay_decision(
			session,
			"no_scored_tactical_order",
			apply_selection
		)
	var target_id := String(decision.get("target_battle_id", ""))
	var action := String(decision.get("action", "defend"))
	if action in PLAYER_EXIT_ACTIONS:
		return _fallback_player_autoplay_decision(
			session,
			"player_exit_order_forbidden",
			apply_selection,
			decision
		)
	if target_id != "":
		if apply_selection and action in ["shoot", "strike"]:
			var selection_result := BattleRulesScript.select_target(session, target_id)
			decision["target_selection_ok"] = bool(selection_result.get("ok", false))
			decision["target_selection_message"] = String(selection_result.get("message", ""))
		elif apply_selection and action == "cast_spell":
			BattleRulesScript._set_selected_target(session.battle, target_id, true)
			var selected_spell_target: Dictionary = BattleRulesScript._get_stack_by_id(
				session.battle,
				target_id
			)
			decision["target_selection_ok"] = not selected_spell_target.is_empty()
			decision["target_selection_message"] = (
				"Spell target selected for autoplay."
				if not selected_spell_target.is_empty()
				else "Spell target missing for autoplay."
			)
		else:
			decision["target_selection_ok"] = true
	if action == "cast_spell":
		var spell_id := String(decision.get("spell_id", ""))
		var spell_target_stack: Dictionary = BattleRulesScript._get_stack_by_id(
			session.battle,
			target_id
		)
		var validation := SpellRulesScript.validate_battle_spell(
			commander_payload,
			session.battle,
			active_stack,
			spell_target_stack,
			spell_id,
			"player"
		)
		if bool(validation.get("ok", false)):
			decision["reason"] = "scored_tactical_spell_order"
			return decision
		decision["spell_validation_message"] = String(
			validation.get("message", "Spell order unavailable.")
		)
		return _fallback_player_autoplay_decision(
			session,
			"scored_spell_order_unavailable",
			apply_selection,
			decision
		)
	var availability: Dictionary = BattleRulesScript.action_availability(session.battle)
	if bool(availability.get(action, false)):
		decision["reason"] = "scored_tactical_order"
		return decision
	return _fallback_player_autoplay_decision(
		session,
		"scored_order_unavailable",
		apply_selection,
		decision
	)


static func resolve_active_battle(
	session: SessionStateStoreScript.SessionData,
	step_limit: int = DEFAULT_STEP_LIMIT
) -> Dictionary:
	if session == null:
		return _resolve_result(null, false, "invalid_session", "invalid", 0, 0, 0, 0, 0, {}, {}, {})
	if session.battle.is_empty():
		return _resolve_result(session, false, "no_active_battle", "invalid", 0, 0, 0, 0, 0, {}, {}, {})
	if step_limit <= 0:
		return _resolve_result(session, false, "invalid_step_limit", "invalid", 0, 0, 0, 0, 0, {}, {}, {})

	var steps := 0
	var player_orders := 0
	var enemy_ready_ticks := 0
	var invalid_orders := 0
	var forbidden_exit_orders := 0
	var action_counts := {}
	var final_state := "continue"
	var stop_reason := ""
	var last_result := {}
	var terminal_result := {}
	while steps < step_limit and not session.battle.is_empty():
		steps += 1
		var ready_result: Dictionary = BattleRulesScript.resolve_if_battle_ready(session)
		last_result = ready_result.duplicate(true)
		final_state = String(ready_result.get("state", "continue"))
		if is_terminal_state(final_state):
			terminal_result = ready_result.duplicate(true)
			break
		if session.battle.is_empty():
			stop_reason = "battle_cleared_without_terminal_state"
			break
		var active_stack: Dictionary = BattleRulesScript.get_active_stack(session.battle)
		if String(active_stack.get("side", "")) != "player":
			enemy_ready_ticks += 1
			continue
		var decision := player_autoplay_decision(session, true)
		var action := String(decision.get("action", "defend"))
		if action in PLAYER_EXIT_ACTIONS:
			forbidden_exit_orders += 1
			action = "defend"
		var result: Dictionary = _perform_player_order(session, decision, action)
		if String(result.get("state", "")) == "invalid" and action != "defend":
			invalid_orders += 1
			action = "defend"
			result = BattleRulesScript.perform_player_action(session, action)
		if String(result.get("state", "")) == "invalid":
			invalid_orders += 1
			last_result = result.duplicate(true)
			final_state = "invalid"
			stop_reason = "fallback_defend_invalid"
			break
		action_counts[action] = int(action_counts.get(action, 0)) + 1
		player_orders += 1
		last_result = result.duplicate(true)
		final_state = String(result.get("state", final_state))
		if is_terminal_state(final_state):
			terminal_result = result.duplicate(true)
			break

	var completed := is_terminal_state(final_state)
	if not completed and stop_reason == "" and steps >= step_limit:
		final_state = "stalled_step_limit"
		stop_reason = "step_limit_reached"
	if not completed and stop_reason == "" and session.battle.is_empty():
		stop_reason = "battle_cleared_without_terminal_state"
	return _resolve_result(
		session,
		completed,
		stop_reason,
		final_state,
		steps,
		player_orders,
		enemy_ready_ticks,
		invalid_orders,
		forbidden_exit_orders,
		action_counts,
		terminal_result,
		last_result
	)


static func is_terminal_state(state: String) -> bool:
	return state in TERMINAL_STATES


static func _perform_player_order(
	session: SessionStateStoreScript.SessionData,
	decision: Dictionary,
	action: String
) -> Dictionary:
	if action == "cast_spell":
		return BattleRulesScript.cast_player_spell(
			session,
			String(decision.get("spell_id", ""))
		)
	return BattleRulesScript.perform_player_action(session, action)


static func _fallback_player_autoplay_decision(
	session: SessionStateStoreScript.SessionData,
	reason: String,
	apply_selection: bool,
	scored_decision: Dictionary = {}
) -> Dictionary:
	_select_focus_enemy(session)
	var availability: Dictionary = BattleRulesScript.action_availability(session.battle)
	var fallback_action := "defend"
	if bool(availability.get("shoot", false)):
		fallback_action = "shoot"
	elif bool(availability.get("strike", false)):
		fallback_action = "strike"
	elif bool(availability.get("advance", false)):
		fallback_action = "advance"
	return {
		"action": fallback_action,
		"target_battle_id": String(session.battle.get("selected_target_id", "")),
		"reason": reason,
		"scoring_policy": "battle_ai_nonspell_tactical_order_v1",
		"fallback_policy": "legacy_availability_order",
		"scored_decision": scored_decision,
		"applied_selection": apply_selection,
	}


static func _select_focus_enemy(session: SessionStateStoreScript.SessionData) -> void:
	var best_id := ""
	var best_score := 2147483647
	for stack in session.battle.get("stacks", []):
		if not (stack is Dictionary):
			continue
		if String(stack.get("side", "")) != "enemy":
			continue
		if int(stack.get("count", 0)) <= 0 or int(stack.get("total_health", 0)) <= 0:
			continue
		var score := int(stack.get("total_health", 0)) * 1000 + int(stack.get("count", 0))
		if score < best_score:
			best_score = score
			best_id = String(stack.get("battle_id", ""))
	if best_id != "":
		BattleRulesScript.select_target(session, best_id)


static func _resolve_result(
	session: SessionStateStoreScript.SessionData,
	completed: bool,
	stop_reason: String,
	state: String,
	steps: int,
	player_orders: int,
	enemy_ready_ticks: int,
	invalid_orders: int,
	forbidden_exit_orders: int,
	action_counts: Dictionary,
	terminal_result: Dictionary,
	last_result: Dictionary
) -> Dictionary:
	return {
		"ok": completed and stop_reason == "",
		"completed": completed,
		"state": state,
		"stop_reason": stop_reason,
		"steps": steps,
		"player_orders": player_orders,
		"enemy_ready_ticks": enemy_ready_ticks,
		"invalid_orders": invalid_orders,
		"forbidden_exit_orders": forbidden_exit_orders,
		"action_counts": action_counts.duplicate(true),
		"terminal_result": terminal_result.duplicate(true),
		"last_result": last_result.duplicate(true),
		"battle_active": session != null and not session.battle.is_empty(),
		"scenario_status": String(session.scenario_status) if session != null else "",
		"game_state": String(session.game_state) if session != null else "",
	}
