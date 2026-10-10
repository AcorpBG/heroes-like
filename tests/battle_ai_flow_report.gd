extends Node
## The battle AI plays the reworked flow, the same on both sides (battle rework,
## AI and balance slice). Checks that the enemy's turns and the side Quick
## Resolve and Auto battle play give the same orders: a melee stack strikes the
## best stack in its reach this turn, walking first when it must, rather than
## the nearest one; one that reaches none waits while enemies are still to act
## and walks once none are; walking goes around obstacles; a shooter with no
## shots left fights as melee; the AI weighs each stack's own contact, not the
## closest pair on the field; bracing loses its worth as the battle clock runs
## out; a hero's buff is worth more on the stack about to act, and haste most
## when it lets that stack reach an enemy this turn. A fallen stack's effects
## end without an event when the next round begins. The stacks come from a
## battle on a generated small map.

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const AutoResolve = preload("res://scripts/core/BattleAutoResolveRules.gd")
const Footprint = preload("res://scripts/core/BattleFootprint.gd")
const REPORT_ID := "BATTLE_AI_FLOW_REPORT"
const SEED := "battle-ai-flow-20261010"
const HASTE_SPELL_ID := "spell_quickmarch_hymn"
const PLAY_SIZE := Vector2i(1920, 1080)
const PLAYBACK_WAIT_MSEC := 8000

var _checks := 0
var _failures := []
var _base_session = null
var _battle := {}

func _ready() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
		push_error("%s check failed: %s" % [REPORT_ID, label])

func _run() -> void:
	AppRouter.validation_set_battle_report_routing_suppressed(true)
	_base_session = _session()
	if _base_session != null:
		_battle = _base_session.battle.duplicate(true)
		for side in ["player", "enemy"]:
			_check_best_stack_in_reach(side)
			_check_wait_then_walk(side)
			_check_shooter_without_shots(side)
		_check_route_around_rocks()
		_check_own_contact()
		_check_clock_pressure()
		_check_buff_timing()
		_check_fallen_stack_effects()
		await _check_auto_battle()
		# Last: resolving the battle ends the session's battle for good.
		_check_quick_resolve_generated()
	AppRouter.validation_set_battle_report_routing_suppressed(false)
	var report := {"ok": _failures.is_empty(), "checks": _checks, "failures": _failures}
	print("%s %s" % [REPORT_ID, JSON.stringify(report)])
	get_tree().quit(0 if _failures.is_empty() else 1)


# --- Setup ---------------------------------------------------------------------

func _session():
	var config := ScenarioSelectRulesScript.build_random_map_player_config(SEED, "", "", 2, "land", false, "homm3_small", ScenarioSelectRulesScript.RANDOM_MAP_TEMPLATE_SELECTION_MODE_SIZE_DEFAULT, "faction_embercourt", "hero_caelen")
	var setup := ScenarioSelectRulesScript.build_random_map_skirmish_setup_with_retry(config, "normal", ScenarioSelectRulesScript.RANDOM_MAP_PLAYER_RETRY_POLICY)
	_check(bool(setup.get("ok", false)), "small generated setup")
	if not bool(setup.get("ok", false)):
		return null
	var session = ScenarioSelectRulesScript.start_random_map_skirmish_session_from_setup(setup)
	OverworldRules.normalize_overworld_state(session)
	for encounter in session.overworld.get("encounters", []):
		var battle := BattleRules.create_battle_payload(session, encounter)
		if _living(battle, "enemy").size() >= 2 and not _living(battle, "player").is_empty():
			session.battle = battle
			session.game_state = "battle"
			BattleRules.normalize_battle_state(session)
			return session
	_check(false, "a guard battle of two or more enemy stacks")
	return null

func _living(battle: Dictionary, side: String) -> Array:
	return battle.get("stacks", []).filter(func(stack): return String(stack.get("side", "")) == side and BattleRules._alive_count(stack) > 0)

func _cell(q: int, r: int) -> Dictionary:
	return {"q": q, "r": r}

func _key(cell: Dictionary) -> String:
	return "%d,%d" % [int(cell.get("q", -1)), int(cell.get("r", -1))]

func _other(side: String) -> String:
	return "enemy" if side == "player" else "player"

## The column seen from the given side: the player's stacks start on the left
## edge, the enemy's on the right.
func _q(side: String, q: int) -> int:
	return q if side == "player" else BattleRules.BATTLE_HEX_COLUMNS - 1 - q

## A board from the generated battle's stacks. Each spec names a stack:
## {"id", "side", "hex", "ranged", "shots", "speed"}, cloned from the battle's
## first stack of its side and made plain (see _plain). The field is open but
## for rocks, without objectives or tags. order is the turn order of the stacks
## still to act this round, the active one first. Neither hero casts.
func _board(specs: Array, order: Array, rocks: Array = []) -> Dictionary:
	var session = _base_session
	session.battle = _battle.duplicate(true)
	session.game_state = "battle"
	var board: Dictionary = session.battle
	var templates := {"player": _living(board, "player")[0].duplicate(true), "enemy": _living(board, "enemy")[0].duplicate(true)}
	var stacks := []
	for spec in specs:
		var stack: Dictionary = (templates[String(spec.get("side", "enemy"))] as Dictionary).duplicate(true)
		_plain(stack)
		stack["battle_id"] = String(spec.get("id", ""))
		stack["side"] = String(spec.get("side", "enemy"))
		stack["hex"] = spec.get("hex", {})
		stack["ranged"] = bool(spec.get("ranged", false))
		stack["shots_remaining"] = int(spec.get("shots", 4 if bool(spec.get("ranged", false)) else 0))
		stack["speed"] = int(spec.get("speed", 4))
		stacks.append(stack)
	board["stacks"] = stacks
	var obstacles := []
	for index in range(rocks.size()):
		obstacles.append({"id": "t%d" % (index + 1), "kind": "rock", "size": 1, "variant": 0, "cells": [rocks[index]]})
	board[BattleRules.OBSTACLES_KEY] = obstacles
	board[BattleRules.FIELD_OBJECTIVES_KEY] = []
	board["battlefield_tags"] = []
	board[BattleRules.WAITED_STACK_IDS_KEY] = []
	board["turn_order"] = order.duplicate()
	board["turn_index"] = 0
	board["active_stack_id"] = String(order[0])
	board["selected_target_id"] = ""
	board["round"] = 1
	board["max_rounds"] = 12
	board["enemy_hero"] = {}
	board["enemy_hero_payload"] = {}
	board["player_hero"] = {}
	board["player_commander_state"] = {}
	BattleRules._sync_occupied_hexes(board)
	BattleRules._sync_distance_from_hexes(board)
	return board

## A sturdy plain stack: no abilities or effects, so one blow never ends it.
func _plain(stack: Dictionary) -> void:
	stack["battle_footprint"] = 1
	stack["effects"] = []
	stack["abilities"] = []
	stack["defending"] = false
	stack["ranged"] = false
	stack["shots_remaining"] = 0
	stack["unit_hp"] = 100
	stack["base_count"] = 20
	stack["total_health"] = 2000
	stack["retaliations_left"] = 1
	stack["cohesion"] = 6
	stack["momentum"] = 0

func _stack(board: Dictionary, battle_id: String) -> Dictionary:
	return BattleRules._get_stack_by_id(board, battle_id)

## The order the given side's computer gives its active stack, and plays it:
## the enemy's turn (BattleRules._run_enemy_turn), or the player's side as
## Quick Resolve plays it (BattleAutoResolveRules). Returns {"action", "result"}.
func _play_turn(side: String) -> Dictionary:
	var session = _base_session
	var active := BattleRules.get_active_stack(session.battle)
	if side == "enemy":
		var choice := BattleAiRules.choose_enemy_action(session.battle, active, {})
		var action := String(choice.get("action", ""))
		if action == "advance":
			action = String(BattleRules.ai_advance_plan(session.battle, active).get("action", "advance"))
		var result: Dictionary = BattleRules._run_enemy_turn(session, active)
		return {"action": action, "target": String(choice.get("target_battle_id", "")), "result": result}
	var decision := AutoResolve.player_autoplay_decision(session, true, false)
	var played: Dictionary = AutoResolve._perform_player_order(session, decision, String(decision.get("action", "")))
	return {"action": String(decision.get("action", "")), "target": String(decision.get("target_battle_id", "")), "result": played, "decision": decision}


# --- Strikes, waits and walks --------------------------------------------------

## A melee stack with a melee stack three hexes off and a shooter it can also
## reach strikes the shooter, walking first, on either side.
func _check_best_stack_in_reach(side: String) -> void:
	var foe := _other(side)
	var board := _board([
		{"id": "actor", "side": side, "hex": _cell(_q(side, 2), 4), "speed": 5},
		{"id": "near", "side": foe, "hex": _cell(_q(side, 5), 4)},
		{"id": "shooter", "side": foe, "hex": _cell(_q(side, 6), 2), "ranged": true},
	], ["actor", "near", "shooter"])
	var actor := _stack(board, "actor")
	var label := "%s side" % side
	_check(Footprint.distance(actor, _stack(board, "near")) < Footprint.distance(actor, _stack(board, "shooter")), "%s: the melee stack is nearer than the shooter" % label)
	_check(not BattleRules.melee_approach_cells(board, actor, _stack(board, "near")).is_empty() and not BattleRules.melee_approach_cells(board, actor, _stack(board, "shooter")).is_empty(), "%s: both are in reach this turn" % label)
	var plan := BattleRules.ai_advance_plan(board, actor)
	_check(String(plan.get("action", "")) == "strike" and String(plan.get("target_battle_id", "")) == "shooter", "%s: an advance in reach is a strike on the shooter: %s" % [label, plan])
	var shooter_before := int(_stack(board, "shooter").get("total_health", 0))
	var turn := _play_turn(side)
	var after := _stack(_base_session.battle, "actor")
	_check(String(turn.get("action", "")) == "strike" and String(turn.get("target", "")) == "shooter", "%s: the computer orders the strike on the shooter: %s" % [label, [turn.get("action", ""), turn.get("target", "")]])
	_check(int(_stack(_base_session.battle, "shooter").get("total_health", 0)) < shooter_before, "%s: the shooter is struck: %s" % [label, (turn.get("result", {}) as Dictionary).get("message", "")])
	_check(_key(after.get("hex", {})) == _key(plan.get("approach", {})) and Footprint.distance(after, _stack(_base_session.battle, "shooter")) == 1, "%s: it walked to the AI's hex beside the shooter: %s" % [label, after.get("hex", {})])

## A melee stack no enemy is in reach of waits while enemy stacks are still to
## act this round, and walks toward the nearest once none are.
func _check_wait_then_walk(side: String) -> void:
	var foe := _other(side)
	var specs := [
		{"id": "actor", "side": side, "hex": _cell(_q(side, 0), 4), "speed": 3},
		{"id": "far_a", "side": foe, "hex": _cell(_q(side, 10), 4)},
		{"id": "far_b", "side": foe, "hex": _cell(_q(side, 10), 6)},
	]
	var label := "%s side" % side
	var board := _board(specs, ["actor", "far_a", "far_b"])
	var actor := _stack(board, "actor")
	_check(BattleAiRules.best_reachable_strike(board, actor).is_empty(), "%s: no enemy is in reach" % label)
	var turn := _play_turn(side)
	_check(String(turn.get("action", "")) == "wait" and BattleRules.stack_has_waited(_base_session.battle, "actor"), "%s: it waits while the enemies are still to act: %s" % [label, turn.get("action", "")])
	_check(_key(_stack(_base_session.battle, "actor").get("hex", {})) == _key(actor.get("hex", {})), "%s: waiting does not move it" % label)
	board = _board(specs, ["far_a", "far_b", "actor"])
	board["turn_index"] = 2
	board["active_stack_id"] = "actor"
	actor = _stack(board, "actor")
	var start := Footprint.distance(actor, _stack(board, "far_a"))
	turn = _play_turn(side)
	var moved := _stack(_base_session.battle, "actor")
	_check(String(turn.get("action", "")) == "advance" and Footprint.distance(moved, _stack(_base_session.battle, "far_a")) == start - 3, "%s: with nobody left to act it walks its three hexes toward the enemy: %s" % [label, moved.get("hex", {})])

## A shooter with no shots left fights as melee: it strikes an enemy in its
## reach, and waits for one out of reach while enemies are still to act.
func _check_shooter_without_shots(side: String) -> void:
	var foe := _other(side)
	var label := "%s side" % side
	var board := _board([
		{"id": "actor", "side": side, "hex": _cell(_q(side, 2), 4), "ranged": true, "shots": 0, "speed": 4},
		{"id": "foe", "side": foe, "hex": _cell(_q(side, 5), 4)},
	], ["actor", "foe"])
	var before := int(_stack(board, "foe").get("total_health", 0))
	var turn := _play_turn(side)
	_check(String(turn.get("action", "")) == "strike" and int(_stack(_base_session.battle, "foe").get("total_health", 0)) < before, "%s: a shooter without shots walks and strikes: %s" % [label, turn.get("action", "")])
	board = _board([
		{"id": "actor", "side": side, "hex": _cell(_q(side, 0), 4), "ranged": true, "shots": 0, "speed": 3},
		{"id": "foe", "side": foe, "hex": _cell(_q(side, 10), 4)},
	], ["actor", "foe"])
	turn = _play_turn(side)
	_check(String(turn.get("action", "")) == "wait", "%s: out of reach, it waits for the enemy as a melee stack does: %s" % [label, turn.get("action", "")])

## Walking goes around a wall of rocks instead of into it: the advance ends on
## the hex fewest steps from the target by walking, which is not the hex
## nearest it in a straight line.
func _check_route_around_rocks() -> void:
	var rocks := [_cell(4, 2), _cell(4, 3), _cell(4, 4), _cell(4, 5), _cell(4, 6), _cell(4, 7)]
	var board := _board([
		{"id": "far", "side": "enemy", "hex": _cell(8, 4)},
		{"id": "actor", "side": "player", "hex": _cell(2, 5), "speed": 3},
	], ["far", "actor"], rocks)
	board["turn_index"] = 1
	board["active_stack_id"] = "actor"
	var actor := _stack(board, "actor")
	var target := _stack(board, "far")
	var walk := _walk_steps(board, actor, target)
	var destinations := BattleRules.legal_destinations_for_stack(board, "actor")
	var fewest := 9999
	var straight := {}
	for cell in destinations:
		fewest = mini(fewest, int(walk.get(_key(cell), 9999)))
		if straight.is_empty() or Footprint.distance(actor, target, cell) < Footprint.distance(actor, target, straight):
			straight = cell
	_check(int(walk.get(_key(straight), 9999)) > fewest, "the rocks wall off the straight line: the hex nearest in hexes (%s) is %d steps from the target by walking, the best %d" % [_key(straight), int(walk.get(_key(straight), 9999)), fewest])
	var turn := _play_turn("player")
	var moved := _stack(_base_session.battle, "actor")
	_check(String(turn.get("action", "")) == "advance" and int(walk.get(_key(moved.get("hex", {})), 9999)) == fewest, "the advance walks around the rocks to a hex %d steps from the target: %s" % [fewest, moved.get("hex", {})])
	var enemy_board := _board([
		{"id": "far", "side": "player", "hex": _cell(2, 4)},
		{"id": "actor", "side": "enemy", "hex": _cell(8, 5), "speed": 3},
	], ["far", "actor"], [_cell(6, 2), _cell(6, 3), _cell(6, 4), _cell(6, 5), _cell(6, 6), _cell(6, 7)])
	enemy_board["turn_index"] = 1
	enemy_board["active_stack_id"] = "actor"
	var enemy_walk := _walk_steps(enemy_board, _stack(enemy_board, "actor"), _stack(enemy_board, "far"))
	var enemy_fewest := 9999
	for cell in BattleRules.legal_destinations_for_stack(enemy_board, "actor"):
		enemy_fewest = mini(enemy_fewest, int(enemy_walk.get(_key(cell), 9999)))
	_play_turn("enemy")
	var enemy_moved := _stack(_base_session.battle, "actor")
	_check(int(enemy_walk.get(_key(enemy_moved.get("hex", {})), 9999)) == enemy_fewest, "the enemy's advance walks around its rocks the same way: %s" % [enemy_moved.get("hex", {})])

## Walking steps from every hex to a hex beside target, around rocks and
## stacks: the report's own count, to hold the rules' route against.
func _walk_steps(board: Dictionary, stack: Dictionary, target: Dictionary) -> Dictionary:
	var blocked := {}
	for obstacle in board.get(BattleRules.OBSTACLES_KEY, []):
		for cell in obstacle.get("cells", []):
			blocked[_key(cell)] = true
	for other in board.get("stacks", []):
		if String(other.get("battle_id", "")) != String(stack.get("battle_id", "")) and BattleRules._alive_count(other) > 0:
			blocked[_key(other.get("hex", {}))] = true
	var steps := {}
	var queue := []
	for cell in BattleRules._hex_neighbors(target.get("hex", {})):
		if not blocked.has(_key(cell)):
			steps[_key(cell)] = 0
			queue.append(cell)
	var index := 0
	while index < queue.size():
		var current: Dictionary = queue[index]
		index += 1
		for cell in BattleRules._hex_neighbors(current):
			if blocked.has(_key(cell)) or steps.has(_key(cell)):
				continue
			steps[_key(cell)] = int(steps[_key(current)]) + 1
			queue.append(cell)
	return steps


# --- Scoring -------------------------------------------------------------------

## The AI weighs the acting stack's own contact: a far shooter's shot, a melee
## stack's defend and advance score the same whether or not another pair
## stands in contact elsewhere (the battle-wide band); a shooter next to an
## enemy scores its point-blank shot lower.
func _check_own_contact() -> void:
	var board := _board([
		{"id": "shooter", "side": "player", "hex": _cell(0, 0), "ranged": true},
		{"id": "walker", "side": "player", "hex": _cell(0, 8)},
		{"id": "target", "side": "enemy", "hex": _cell(10, 4)},
	], ["shooter", "walker", "target"])
	var shooter := _stack(board, "shooter")
	var walker := _stack(board, "walker")
	var target := _stack(board, "target")
	var targets := [target]
	var scores := {}
	for band in [2, 0]:
		board["distance"] = band
		scores[band] = [BattleAiRules._attack_score(shooter, target, board, true), BattleAiRules._defend_score(board, walker, targets), BattleAiRules._advance_score(board, walker, targets)]
	_check(is_equal_approx(float(scores[2][0]), float(scores[0][0])), "a far shooter's shot scores the same whatever the battle-wide band: %s" % [scores])
	_check(is_equal_approx(float(scores[2][1]), float(scores[0][1])) and is_equal_approx(float(scores[2][2]), float(scores[0][2])), "an unengaged melee stack's defend and advance score the same whatever the battle-wide band: %s" % [scores])
	board = _board([
		{"id": "shooter", "side": "player", "hex": _cell(5, 4), "ranged": true},
		{"id": "beside", "side": "enemy", "hex": _cell(6, 4)},
		{"id": "target", "side": "enemy", "hex": _cell(10, 0)},
	], ["shooter", "beside", "target"])
	var engaged := BattleAiRules._attack_score(_stack(board, "shooter"), _stack(board, "target"), board, true)
	var free_board := _board([
		{"id": "shooter", "side": "player", "hex": _cell(5, 4), "ranged": true},
		{"id": "beside", "side": "enemy", "hex": _cell(8, 8)},
		{"id": "target", "side": "enemy", "hex": _cell(10, 0)},
	], ["shooter", "beside", "target"])
	var free := BattleAiRules._attack_score(_stack(free_board, "shooter"), _stack(free_board, "target"), free_board, true)
	_check(engaged < free, "a shooter next to an enemy scores its point-blank shot lower (%.2f, free %.2f)" % [engaged, free])

## In the last three rounds before stalemate bracing loses 2.5 a round and a
## melee advance gains 1, so neither side sits out the clock.
func _check_clock_pressure() -> void:
	var board := _board([
		{"id": "walker", "side": "player", "hex": _cell(1, 4)},
		{"id": "target", "side": "enemy", "hex": _cell(9, 4)},
	], ["walker", "target"])
	var walker := _stack(board, "walker")
	var targets := [_stack(board, "target")]
	var defend := {}
	var advance := {}
	for round_number in [1, 9, 10, 12]:
		board["round"] = round_number
		defend[round_number] = BattleAiRules._defend_score(board, walker, targets)
		advance[round_number] = BattleAiRules._advance_score(board, walker, targets)
	_check(is_equal_approx(float(defend[9]), float(defend[1])) and is_equal_approx(float(advance[9]), float(advance[1])), "four rounds before stalemate the clock does not press yet: %s %s" % [defend, advance])
	_check(is_equal_approx(float(defend[1]) - float(defend[10]), 2.5) and is_equal_approx(float(defend[1]) - float(defend[12]), 7.5), "bracing loses 2.5 three rounds out and 7.5 in the last round: %s" % [defend])
	_check(is_equal_approx(float(advance[12]) - float(advance[1]), 3.0), "a melee advance gains 3 in the last round: %s" % [advance])

## A buff on the stack about to act is worth 1 more, since an effect on the
## acting stack does not spend its turn; haste is worth 2.5 more again when it
## lets that stack reach an enemy this turn.
func _check_buff_timing() -> void:
	var haste := ContentService.get_spell(HASTE_SPELL_ID)
	_check(not haste.is_empty() and int(SpellRules.battle_spell_modifiers(haste).get("speed", 0)) == 1, "the haste spell adds one speed")
	if haste.is_empty():
		return
	# Four steps reach a hex beside the target at seven hexes off only with haste.
	var board := _board([
		{"id": "runner", "side": "player", "hex": _cell(1, 4), "speed": 5},
		{"id": "other", "side": "player", "hex": _cell(0, 0), "speed": 5},
		{"id": "target", "side": "enemy", "hex": _cell(8, 4)},
	], ["runner", "other", "target"])
	var runner := _stack(board, "runner")
	var other := _stack(board, "other")
	var targets := [_stack(board, "target")]
	_check(not BattleRules.extra_speed_reaches_strike(board, runner, 0) and BattleRules.extra_speed_reaches_strike(board, runner, 1), "one more speed lets the runner reach the target this turn")
	var acting := BattleAiRules._buff_spell_score(board, runner, runner, targets, haste)
	var while_other_acts := BattleAiRules._buff_spell_score(board, other, runner, targets, haste)
	_check(is_equal_approx(acting - while_other_acts, 3.5), "haste on the acting runner is worth 3.5 more than while another stack acts (%.2f, %.2f)" % [acting, while_other_acts])
	var reached := _board([
		{"id": "runner", "side": "player", "hex": _cell(3, 4), "speed": 5},
		{"id": "other", "side": "player", "hex": _cell(0, 0), "speed": 5},
		{"id": "target", "side": "enemy", "hex": _cell(8, 4)},
	], ["runner", "other", "target"])
	var near_runner := _stack(reached, "runner")
	_check(not BattleRules.extra_speed_reaches_strike(reached, near_runner, 1), "haste brings nothing new to a runner already in reach")
	var near_targets := [_stack(reached, "target")]
	var near_acting := BattleAiRules._buff_spell_score(reached, near_runner, near_runner, near_targets, haste)
	var near_other := BattleAiRules._buff_spell_score(reached, _stack(reached, "other"), near_runner, near_targets, haste)
	_check(is_equal_approx(near_acting - near_other, 1.0), "on the acting stack a buff is worth 1 more (%.2f, %.2f)" % [near_acting, near_other])


# --- Round start ---------------------------------------------------------------

## When a round begins, a fallen stack's effect ends without an event: the
## event would stand the stack up on the field again. A living stack's effect
## still ends with one. The strike that ends round 1 kills "struck"; "fallen"
## fell earlier.
func _check_fallen_stack_effects() -> void:
	var board := _board([
		{"id": "actor", "side": "player", "hex": _cell(4, 4)},
		{"id": "struck", "side": "enemy", "hex": _cell(5, 4)},
		{"id": "fallen", "side": "enemy", "hex": _cell(7, 2)},
		{"id": "other", "side": "enemy", "hex": _cell(10, 8)},
	], ["other", "struck", "actor"])
	board["turn_index"] = 2
	board["active_stack_id"] = "actor"
	board["selected_target_id"] = "struck"
	_stack(board, "struck")["total_health"] = 1
	_stack(board, "fallen")["total_health"] = 0
	for id in ["struck", "fallen", "other"]:
		_stack(board, id)["effects"] = [SpellRules.build_battle_effect("status_harried", "Harried", {}, 1, board, "ability", "harry")]
	BattleRules._sync_occupied_hexes(board)
	var result := BattleRules.perform_presented_action(_base_session, "strike", _cell(4, 4))
	var battle: Dictionary = _base_session.battle
	_check(int(battle.get("round", 1)) == 2 and BattleRules._alive_count(_stack(battle, "struck")) <= 0, "round start: the strike kills its target and ends the round: %s" % result.get("message", ""))
	var ended := []
	for frame in result.get("playback_frames", []):
		var event: Dictionary = frame.get("playback_event", {})
		if String(event.get("event_id", "")) == "battle_status_expired":
			ended.append(String(event.get("battle_id", "")))
	for event in BattleRules.animation_event_queue(battle):
		if String(event.get("event_id", "")) == "battle_status_expired":
			ended.append("queued " + String(event.get("battle_id", "")))
	_check(ended.has("other") and not ended.has("struck") and not ended.has("fallen") and not ended.has("queued struck") and not ended.has("queued fallen"), "round start: only the living stack's effect ends with an event: %s" % [ended])
	_check((_stack(battle, "struck").get("effects", []) as Array).is_empty() and (_stack(battle, "fallen").get("effects", []) as Array).is_empty(), "round start: the fallen stacks' effects are gone")


# --- Quick Resolve and Auto battle ---------------------------------------------

## Quick Resolve fights the generated battle to its end.
func _check_quick_resolve_generated() -> void:
	var session = _base_session
	session.battle = _battle.duplicate(true)
	session.game_state = "battle"
	var resolution: Dictionary = AutoResolve.resolve_active_battle(session)
	_check(bool(resolution.get("completed", false)) and AutoResolve.is_terminal_state(String(resolution.get("state", ""))), "Quick Resolve ends the generated battle: %s after %d steps" % [resolution.get("state", ""), int(resolution.get("steps", 0))])
	_check(int(resolution.get("invalid_orders", 0)) == 0, "every order Quick Resolve gave was legal: %s" % [resolution.get("action_counts", {})])

## Auto battle on the battle screen gives the player's stack the order Quick
## Resolve gives: the strike on the shooter in reach, from the AI's hex.
func _check_auto_battle() -> void:
	var board := _board([
		{"id": "actor", "side": "player", "hex": _cell(2, 4), "speed": 5},
		{"id": "near", "side": "enemy", "hex": _cell(5, 4)},
		{"id": "shooter", "side": "enemy", "hex": _cell(6, 2), "ranged": true},
	], ["actor", "near", "shooter"])
	var plan := BattleRules.ai_advance_plan(board, _stack(board, "actor"))
	SessionState.set_active_session(_base_session)
	var frame := Control.new()
	frame.name = "BattleFrame"
	frame.size = Vector2(PLAY_SIZE)
	add_child(frame)
	var shell = load("res://scenes/battle/BattleShell.tscn").instantiate()
	frame.add_child(shell)
	for _frame in range(4):
		await get_tree().process_frame
	var opened: bool = shell._session != null and not shell._session.battle.is_empty()
	_check(opened, "screen: the battle screen opens on the hand-placed board")
	if opened:
		var shooter_before := int(_stack(shell._session.battle, "shooter").get("total_health", 0))
		var order: Dictionary = shell.validation_auto_battle_order()
		var deadline := Time.get_ticks_msec() + PLAYBACK_WAIT_MSEC
		while shell._action_playback_in_progress and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
		var actor := _stack(shell._session.battle, "actor")
		_check(bool(order.get("ok", false)) and String(order.get("action", "")) == "strike" and String((order.get("decision", {}) as Dictionary).get("target_battle_id", "")) == "shooter", "screen: Auto battle orders the strike on the shooter: %s" % [[order.get("action", ""), (order.get("decision", {}) as Dictionary).get("target_battle_id", "")]])
		_check(int(_stack(shell._session.battle, "shooter").get("total_health", 0)) < shooter_before and _key(actor.get("hex", {})) == _key(plan.get("approach", {})), "screen: the strike lands from the hex Quick Resolve picks: %s" % [actor.get("hex", {})])
	frame.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
