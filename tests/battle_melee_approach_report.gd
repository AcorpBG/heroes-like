extends Node
## The player picks the hex a melee stack strikes from (battle rework, owner
## request 2026-10-09: "Cannot choose the end hex for a melee attack"). Checks
## that the rules list every hex a stack can strike a target from this turn and
## nothing else; that a strike from each listed hex walks there and strikes;
## that a strike naming any other hex is refused and changes nothing; that a
## two-hex body strikes with its head or its tail; that a rooted stack strikes
## only from where it stands; that reach strikes from two hexes off without a
## strike-back; that a strike without a hex still walks to the nearest one; and
## that the computer, on either side, picks the hex its score prefers: out of
## strike-back range with reach, next to a shooter. The stacks come from a
## battle on a generated small map.

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const AutoResolve = preload("res://scripts/core/BattleAutoResolveRules.gd")
const Footprint = preload("res://scripts/core/BattleFootprint.gd")
const REPORT_ID := "BATTLE_MELEE_APPROACH_REPORT"
const SEED := "battle-melee-approach-20261009"
const REACH := {"id": "reach", "name": "Report Reach", "distance_one_multiplier": 0.9}

var _checks := 0
var _failures := []

func _ready() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
		push_error("%s check failed: %s" % [REPORT_ID, label])

func _run() -> void:
	var session = _session()
	if session != null:
		var battle: Dictionary = session.battle.duplicate(true)
		_check_every_side(session, battle)
		_check_illegal_refused(session, battle)
		_check_two_hex(session, battle)
		_check_rooted(session, battle)
		_check_reach(session, battle)
		_check_default(session, battle)
		_check_ai_shooter(session, battle)
		_check_enemy_turn(session, battle)
	var report := {"ok": _failures.is_empty(), "checks": _checks, "failures": _failures}
	print("%s %s" % [REPORT_ID, JSON.stringify(report)])
	get_tree().quit(0 if _failures.is_empty() else 1)

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
			return session
	_check(false, "a guard battle of two or more enemy stacks")
	return null

func _living(battle: Dictionary, side: String) -> Array:
	return battle.get("stacks", []).filter(func(stack): return String(stack.get("side", "")) == side and BattleRules._alive_count(stack) > 0)

func _cell(q: int, r: int) -> Dictionary:
	return {"q": q, "r": r}

func _key(cell: Dictionary) -> String:
	return "%d,%d" % [int(cell.get("q", -1)), int(cell.get("r", -1))]

## A synthetic board from the generated battle's stacks: a player attacker, an
## enemy target and any extra stacks, on an open field without objectives. The
## player's stack is active and the target selected; the enemy hero has no
## spells, so its turns are plain orders.
func _board(session, battle: Dictionary, attacker_cell: Dictionary, target_cell: Dictionary, attacker_setup: Dictionary = {}, extras: Array = [], rocks: Array = []) -> Dictionary:
	session.battle = battle.duplicate(true)
	session.game_state = "battle"
	var board: Dictionary = session.battle
	var attacker: Dictionary = _living(board, "player")[0].duplicate(true)
	var target: Dictionary = _living(board, "enemy")[0].duplicate(true)
	var template: Dictionary = _living(board, "enemy")[1].duplicate(true)
	attacker["battle_id"] = "report_attacker"
	target["battle_id"] = "report_target"
	for stack in [attacker, target]:
		_plain(stack)
	attacker["speed"] = 6
	for key in attacker_setup.keys():
		attacker[key] = attacker_setup[key]
	attacker["hex"] = attacker_cell
	target["hex"] = target_cell
	var stacks := [attacker, target]
	for index in range(extras.size()):
		var extra: Dictionary = extras[index]
		var stack: Dictionary = (attacker if String(extra.get("side", "")) == "player" else template).duplicate(true)
		_plain(stack)
		stack["battle_id"] = "report_extra_%d" % index
		stack["side"] = String(extra.get("side", "enemy"))
		stack["hex"] = extra.get("hex", {})
		stack["battle_footprint"] = 1
		stack["abilities"] = []
		stack["ranged"] = bool(extra.get("ranged", false))
		stack["shots_remaining"] = 4 if bool(extra.get("ranged", false)) else 0
		stacks.append(stack)
	board["stacks"] = stacks
	var obstacles := []
	for index in range(rocks.size()):
		obstacles.append({"id": "t%d" % (index + 1), "kind": "rock", "size": 1, "variant": 0, "cells": [rocks[index]]})
	board[BattleRules.OBSTACLES_KEY] = obstacles
	board[BattleRules.FIELD_OBJECTIVES_KEY] = []
	board["battlefield_tags"] = []
	board["turn_order"] = stacks.map(func(stack): return String(stack.get("battle_id", "")))
	board["turn_index"] = 0
	board["active_stack_id"] = "report_attacker"
	board["selected_target_id"] = "report_target"
	board["enemy_hero"] = {}
	board["enemy_hero_payload"] = {}
	BattleRules._sync_occupied_hexes(board)
	BattleRules._sync_distance_from_hexes(board)
	return board

## A sturdy plain stack: no abilities or effects, so a strike never ends it.
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
	stack["speed"] = 4

func _stack(board: Dictionary, battle_id: String) -> Dictionary:
	return BattleRules._get_stack_by_id(board, battle_id)

func _cells_by_key(cells: Array) -> Dictionary:
	var by_key := {}
	for cell in cells:
		by_key[_key(cell)] = cell
	return by_key

func _neighbors(cell: Dictionary) -> Array:
	return BattleRules._hex_neighbors(cell)

## The player's frames from a strike: its walk, its blow and the strike-back.
func _frame_events(result: Dictionary) -> Array:
	var events := []
	for frame in result.get("playback_frames", []):
		var event: Dictionary = frame.get("playback_event", {})
		events.append(event)
	return events

func _check_every_side(session, battle: Dictionary) -> void:
	var board := _board(session, battle, _cell(2, 4), _cell(6, 4))
	var attacker := _stack(board, "report_attacker")
	var target := _stack(board, "report_target")
	var cells := BattleRules.melee_approach_cells(board, attacker, target)
	_check_offer(session, board, "open field")
	var listed := _cells_by_key(cells)
	var sides := _neighbors(target.get("hex", {}))
	_check(sides.size() == 6 and listed.size() == 6, "an open target lists its six sides: %s" % [listed.keys()])
	for side in sides:
		_check(listed.has(_key(side)), "side %s is listed" % _key(side))
	var reachable := _cells_by_key(BattleRules.legal_destinations_for_stack(board, "report_attacker"))
	for cell in cells:
		_check(reachable.has(_key(cell)) and int(cell.get("steps", 0)) == int(reachable[_key(cell)].get("steps", -1)), "side %s is a hex it can reach this turn, in as many steps" % _key(cell))
		_check(String(cell.get("strike_part", "")) == "head" and int(cell.get("hex_distance", 0)) == 1, "a one-hex stack strikes from beside the target at %s" % _key(cell))
	var steps := cells.map(func(cell): return int(cell.get("steps", 0)))
	var sorted_steps := steps.duplicate()
	sorted_steps.sort()
	_check(steps == sorted_steps, "the sides come in walking order: %s" % [steps])
	var base: Dictionary = board.duplicate(true)
	for cell in cells:
		session.battle = base.duplicate(true)
		var health_before := int(_stack(session.battle, "report_target").get("total_health", 0))
		var result := BattleRules.perform_presented_action(session, "strike", {"q": int(cell.q), "r": int(cell.r)})
		var moved := _stack(session.battle, "report_attacker")
		_check(bool(result.get("ok", false)), "the strike from %s is accepted: %s" % [_key(cell), result.get("message", "")])
		_check(_key(moved.get("hex", {})) == _key(cell), "the attacker stands on %s after its strike: %s" % [_key(cell), moved.get("hex", {})])
		_check(int(_stack(session.battle, "report_target").get("total_health", 0)) < health_before, "the strike from %s lands" % _key(cell))
		var events := _frame_events(result)
		var walk: Dictionary = events[0] if not events.is_empty() else {}
		var path: Array = walk.get("walk_path", [])
		_check(String(walk.get("event_id", "")) == "battle_unit_move" and not path.is_empty() and _key(path.back()) == _key(cell) and path.size() - 1 == int(cell.get("steps", 0)), "the playback walks to %s in %d steps first: %s" % [_key(cell), int(cell.get("steps", 0)), path])
		var struck := events.any(func(event): return String(event.get("event_id", "")) == "battle_unit_melee_attack" and String(event.get("battle_id", "")) == "report_attacker")
		_check(struck, "the playback then shows the strike from %s" % _key(cell))

func _check_illegal_refused(session, battle: Dictionary) -> void:
	var friend := {"side": "player", "hex": _cell(5, 4)}
	var board := _board(session, battle, _cell(2, 4), _cell(6, 4), {}, [friend], [_cell(6, 5)])
	var cells := _cells_by_key(BattleRules.melee_approach_cells(board, _stack(board, "report_attacker"), _stack(board, "report_target")))
	_check_offer(session, board, "a friend and a rock beside the target")
	_check(not cells.has("5,4"), "a side another stack stands on is not listed")
	_check(not cells.has("6,5"), "a side under a rock is not listed")
	_check(cells.size() == 4, "the four open sides are listed: %s" % [cells.keys()])
	var refusals := {
		"two hexes off": _cell(4, 4),
		"on a friend": _cell(5, 4),
		"on a rock": _cell(6, 5),
		"on the target": _cell(6, 4),
		"off the board": _cell(-1, 4),
	}
	for label in refusals.keys():
		_check_refused(session, board, refusals[label], label)
	var slow := _board(session, battle, _cell(2, 4), _cell(6, 4), {"speed": 2})
	_check_refused(session, slow, _cell(7, 4), "beyond its movement")
	session.battle = slow.duplicate(true)
	_check(not bool(BattleRules.action_availability(session.battle).get("strike", true)), "a target out of reach offers no strike")
	_check_offer(session, slow, "out of reach")

## The strike order is offered exactly when the stack has a hex to strike from.
func _check_offer(session, board: Dictionary, label: String) -> void:
	session.battle = board.duplicate(true)
	var cells := BattleRules.melee_approach_cells(session.battle, BattleRules.get_active_stack(session.battle), BattleRules.get_selected_target(session.battle))
	_check(bool(BattleRules.action_availability(session.battle).get("strike", false)) == not cells.is_empty(), "the strike is offered exactly when there is a hex to strike from (%s, %d hexes)" % [label, cells.size()])

func _check_refused(session, board: Dictionary, cell: Dictionary, label: String) -> void:
	session.battle = board.duplicate(true)
	var before: Dictionary = session.to_dict().duplicate(true)
	var result := BattleRules.perform_presented_action(session, "strike", cell)
	_check(not bool(result.get("ok", true)) and String(result.get("state", "")) == "invalid", "a strike from %s (%s) is refused: %s" % [_key(cell), label, result.get("message", "")])
	_check(session.to_dict() == before, "the refused strike from %s (%s) changes nothing" % [_key(cell), label])

func _check_two_hex(session, battle: Dictionary) -> void:
	# The player's body runs from its head at (q, r) back to (q - 1, r).
	var board := _board(session, battle, _cell(3, 4), _cell(6, 4), {"battle_footprint": 2, "speed": 8})
	var attacker := _stack(board, "report_attacker")
	var target := _stack(board, "report_target")
	var cells := BattleRules.melee_approach_cells(board, attacker, target)
	_check_offer(session, board, "two-hex body")
	var parts := {}
	var occupied := BattleRules._build_blocking_map(board)
	occupied.erase(_key(attacker.get("hex", {})))
	occupied.erase(_key(Footprint.cells(attacker)[1]))
	for cell in cells:
		parts[String(cell.get("strike_part", ""))] = cell
		_check(Footprint.distance(attacker, target, cell) == 1, "every two-hex placement touches the target: %s" % _key(cell))
		_check(Footprint.fits(attacker, cell, occupied, BattleRules.BATTLE_HEX_COLUMNS, BattleRules.BATTLE_HEX_ROWS), "every two-hex placement fits the board: %s" % _key(cell))
		var strike_cell := _cell(int(cell.get("strike_q", -1)), int(cell.get("strike_r", -1)))
		var body_index := Footprint.cells(attacker, cell).map(func(body_cell): return _key(body_cell)).find(_key(strike_cell))
		_check(body_index == (0 if String(cell.get("strike_part", "")) == "head" else 1) and BattleRules._hex_distance(strike_cell, target.get("hex", {})) == 1, "the striking cell of %s is the %s, next to the target" % [_key(cell), String(cell.get("strike_part", ""))])
	_check(parts.has("head") and parts.has("tail"), "a two-hex body can strike with its head or its tail: %s" % [parts.keys()])
	if parts.has("tail"):
		var tail: Dictionary = parts["tail"]
		session.battle = board.duplicate(true)
		var health_before := int(target.get("total_health", 0))
		var result := BattleRules.perform_presented_action(session, "strike", tail)
		var moved := _stack(session.battle, "report_attacker")
		_check(bool(result.get("ok", false)) and _key(moved.get("hex", {})) == _key(tail), "the strike with the tail from %s is accepted: %s" % [_key(tail), result.get("message", "")])
		_check(int(_stack(session.battle, "report_target").get("total_health", 0)) < health_before, "the strike with the tail lands")

func _check_rooted(session, battle: Dictionary) -> void:
	var rooted_effect := SpellRules._counted_in_turns(SpellRules.build_battle_effect(BattleRules.STATUS_ROOTED, "Rooted", {"defense": -1}, 2, {"round": 1}, "spell", "report"), 2)
	var adjacent := _board(session, battle, _cell(5, 4), _cell(6, 4), {"effects": [rooted_effect]})
	var cells := BattleRules.melee_approach_cells(adjacent, _stack(adjacent, "report_attacker"), _stack(adjacent, "report_target"))
	_check(cells.size() == 1 and _key(cells[0]) == "5,4" and bool(cells[0].get("stands", false)), "a rooted stack beside the target strikes only from where it stands: %s" % [cells])
	_check_offer(session, adjacent, "rooted beside the target")
	_check_refused(session, adjacent, _cell(5, 3), "a rooted stack stepping aside")
	session.battle = adjacent.duplicate(true)
	var result := BattleRules.perform_presented_action(session, "strike", _cell(5, 4))
	_check(bool(result.get("ok", false)) and _key(_stack(session.battle, "report_attacker").get("hex", {})) == "5,4", "a rooted stack strikes from where it stands: %s" % result.get("message", ""))
	var apart := _board(session, battle, _cell(3, 4), _cell(6, 4), {"effects": [rooted_effect]})
	_check(BattleRules.melee_approach_cells(apart, _stack(apart, "report_attacker"), _stack(apart, "report_target")).is_empty(), "a rooted stack away from the target cannot strike it")
	_check_offer(session, apart, "rooted away from the target")
	_check_refused(session, apart, _cell(5, 4), "a rooted stack walking up")
	session.battle = apart.duplicate(true)
	var before: Dictionary = session.to_dict().duplicate(true)
	var plain := BattleRules.perform_presented_action(session, "strike")
	_check(not bool(plain.get("ok", true)) and session.to_dict() == before, "a rooted stack away from the target cannot strike it without a hex either: %s" % plain.get("message", ""))

## Reach strikes from two hexes off only from where the stack stands: a stack
## that walks ends next to the target.
func _check_reach(session, battle: Dictionary) -> void:
	var walking := _board(session, battle, _cell(2, 4), _cell(6, 4), {"abilities": [REACH]})
	var walk_cells := BattleRules.melee_approach_cells(walking, _stack(walking, "report_attacker"), _stack(walking, "report_target"))
	_check(walk_cells.size() == 6 and walk_cells.all(func(cell): return int(cell.get("hex_distance", 0)) == 1), "a reach stack walking up lists the six sides only: %s" % [walk_cells.map(func(cell): return _key(cell))])
	_check_refused(session, walking, _cell(4, 4), "two hexes off after walking, with reach")
	_check_offer(session, walking, "reach, walking up")
	var board := _board(session, battle, _cell(4, 4), _cell(6, 4), {"abilities": [REACH]})
	var attacker := _stack(board, "report_attacker")
	var target := _stack(board, "report_target")
	var cells := BattleRules.melee_approach_cells(board, attacker, target)
	var stand: Dictionary = cells[0] if not cells.is_empty() else {}
	_check(_key(stand) == "4,4" and bool(stand.get("stands", false)) and int(stand.get("hex_distance", 0)) == 2, "a reach stack two hexes off can strike from where it stands: %s" % [stand])
	_check(cells.size() == 7 and cells.slice(1).all(func(cell): return int(cell.get("hex_distance", 0)) == 1), "and from each of the six sides: %s" % [cells.map(func(cell): return _key(cell))])
	_check_offer(session, board, "reach, two hexes off")
	var strike_backs := {}
	for pick in [stand, cells[1] if cells.size() > 1 else {}]:
		if pick.is_empty():
			continue
		session.battle = board.duplicate(true)
		var result := BattleRules.perform_presented_action(session, "strike", pick)
		_check(bool(result.get("ok", false)), "the reach strike from %s is accepted: %s" % [_key(pick), result.get("message", "")])
		# Only the target's strike-back: the target's own turn follows, and the
		# attacker may strike back then.
		var struck_back := _frame_events(result).any(func(event): return String(event.get("event_id", "")) == "battle_retaliation" and String(event.get("battle_id", "")) == "report_target")
		strike_backs[int(pick.get("hex_distance", 0))] = struck_back
	_check(strike_backs.get(2, true) == false, "a reach strike from two hexes off draws no strike-back")
	_check(strike_backs.get(1, false) == true, "a strike from beside the target draws its strike-back")
	var choice := BattleRules.ai_melee_approach(board, attacker, target)
	_check(bool(choice.get("stands", false)) and int(choice.get("hex_distance", 0)) == 2, "the AI strikes with reach from where it stands, out of strike-back range: %s" % [choice])
	# Quick Resolve drives the player's side with the same choice.
	session.battle = board.duplicate(true)
	var order: Dictionary = AutoResolve._perform_player_order(session, {"action": "strike", "target_battle_id": "report_target"}, "strike")
	var after := _stack(session.battle, "report_attacker")
	_check(bool(order.get("ok", false)) and _key(after.get("hex", {})) == "4,4", "Quick Resolve's strike with reach stays two hexes off: %s" % [after.get("hex", {})])
	var reach_target := _board(session, battle, _cell(4, 4), _cell(6, 4), {"abilities": [REACH]})
	BattleRules._get_stack_by_id(reach_target, "report_target")["abilities"] = [REACH]
	var even := BattleRules.ai_melee_approach(reach_target, _stack(reach_target, "report_attacker"), _stack(reach_target, "report_target"))
	_check(int(even.get("hex_distance", 0)) == 1, "against a target with reach, which strikes back either way, the AI steps beside it for full damage: %s" % [even])

func _check_default(session, battle: Dictionary) -> void:
	var board := _board(session, battle, _cell(2, 4), _cell(6, 4))
	var attacker := _stack(board, "report_attacker")
	var nearest := BattleRules.melee_approach_destination(board, attacker, _stack(board, "report_target"))
	session.battle = board.duplicate(true)
	var result := BattleRules.perform_presented_action(session, "strike")
	_check(bool(result.get("ok", false)) and _key(_stack(session.battle, "report_attacker").get("hex", {})) == _key(nearest), "a strike without a hex walks to the nearest side %s" % _key(nearest))
	var adjacent := _board(session, battle, _cell(5, 4), _cell(6, 4))
	session.battle = adjacent.duplicate(true)
	result = BattleRules.perform_presented_action(session, "strike")
	_check(bool(result.get("ok", false)) and _key(_stack(session.battle, "report_attacker").get("hex", {})) == "5,4", "a stack beside the target strikes without moving")

func _check_ai_shooter(session, battle: Dictionary) -> void:
	var lone := _board(session, battle, _cell(2, 4), _cell(6, 4))
	var plain := BattleRules.ai_melee_approach(lone, _stack(lone, "report_attacker"), _stack(lone, "report_target"))
	var first: Dictionary = BattleRules.melee_approach_cells(lone, _stack(lone, "report_attacker"), _stack(lone, "report_target"))[0]
	_check(_key(plain) == _key(first), "with nothing else near, the AI walks no further than it must: %s" % _key(plain))
	var board := _board(session, battle, _cell(2, 4), _cell(6, 4), {}, [{"side": "enemy", "hex": _cell(6, 2), "ranged": true}])
	var choice := BattleRules.ai_melee_approach(board, _stack(board, "report_attacker"), _stack(board, "report_target"))
	_check(BattleRules._hex_distance(choice, _cell(6, 2)) == 1, "the AI strikes from beside an enemy shooter: %s" % _key(choice))
	_check(not _cells_by_key(BattleRules.melee_approach_cells(board, _stack(board, "report_attacker"), _stack(board, "report_target"))).get(_key(choice), {}).is_empty(), "the AI's hex is a legal one")
	_check(_key(BattleRules.ai_melee_approach(board, _stack(board, "report_attacker"), _stack(board, "report_target"))) == _key(choice), "the AI's choice is the same each time")

## The computer's stack takes its strike and advance orders against the
## player's melee stack: it strikes from a side that also stands next to the
## player's shooter. (Which order it gives is the tactical AI's choice, not
## this slice's.)
func _check_enemy_turn(session, battle: Dictionary) -> void:
	var shooter_at := _cell(6, 2)
	var board := _enemy_board(session, battle, _cell(5, 4), _cell(6, 4), shooter_at)
	_check(_shooter_side_exists(board, shooter_at), "a side of the player's stack next to its shooter is open to the enemy")
	var player_before := int(_stack(board, "report_attacker").get("total_health", 0))
	var result := BattleRules._run_enemy_stack_order(session, _stack(board, "report_target"), {"action": "strike", "target_battle_id": "report_attacker"})
	_check_enemy_struck(session, result, player_before, shooter_at, "strike")
	shooter_at = _cell(4, 4)
	board = _enemy_board(session, battle, _cell(5, 4), _cell(8, 4), shooter_at)
	_check(_shooter_side_exists(board, shooter_at), "a side of the player's stack next to its shooter is in the enemy's reach")
	player_before = int(_stack(board, "report_attacker").get("total_health", 0))
	result = BattleRules._run_enemy_stack_order(session, _stack(board, "report_target"), {"action": "advance"})
	_check_enemy_struck(session, result, player_before, shooter_at, "advance")

## The board with the enemy's stack to act against the player's melee stack.
func _enemy_board(session, battle: Dictionary, player_cell: Dictionary, enemy_cell: Dictionary, shooter_cell: Dictionary) -> Dictionary:
	var board := _board(session, battle, player_cell, enemy_cell, {}, [{"side": "player", "hex": shooter_cell, "ranged": true}])
	board["turn_order"] = ["report_target", "report_attacker", "report_extra_0"]
	board["active_stack_id"] = "report_target"
	board["selected_target_id"] = "report_attacker"
	session.battle = board
	return board

func _shooter_side_exists(board: Dictionary, shooter_cell: Dictionary) -> bool:
	return BattleRules.melee_approach_cells(board, _stack(board, "report_target"), _stack(board, "report_attacker")).any(func(cell): return BattleRules._hex_distance(cell, shooter_cell) == 1)

func _check_enemy_struck(session, result: Dictionary, player_before: int, shooter_cell: Dictionary, order: String) -> void:
	var enemy := _stack(session.battle, "report_target")
	var player := _stack(session.battle, "report_attacker")
	_check(bool(result.get("ok", false)), "the enemy's %s order runs: %s" % [order, result.get("message", "")])
	_check(int(player.get("total_health", 0)) < player_before, "the enemy's %s strikes the player's stack: %s" % [order, result.get("message", "")])
	_check(BattleRules._hex_distance(enemy.get("hex", {}), shooter_cell) == 1 and BattleRules._hex_distance(enemy.get("hex", {}), player.get("hex", {})) == 1, "the enemy's %s strikes from beside the player's shooter too: %s" % [order, enemy.get("hex", {})])
