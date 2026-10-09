extends Node
## The 11x9 battle board, edge deployment and obstacles (battle rework, owner
## request 2026-10-09: "We may also need to improve the ground tiles, and
## implement blocking objects"). Checks that each army deploys on its own edge;
## that every battle gets 2-4 seeded obstacles off the deployment columns, never
## touching each other and always leaving a way across, and the same ones for
## the same seed; that no stack stands on, walks through or is pulled onto an
## obstacle; that Advance walks around them and stops where its attack works;
## that a shooter next to any enemy shoots at x0.6; that obstacles survive a
## save and load and old saves load with an open field; and that the board
## draws each obstacle with the terrain's art. The battles come from a
## generated small map.

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const BattleBoardViewScript = preload("res://scenes/battle/BattleBoardView.gd")
const Footprint = preload("res://scripts/core/BattleFootprint.gd")
const REPORT_ID := "BATTLE_BOARD_OBSTACLES_REPORT"
const SEED := "battle-board-obstacles-20261009"
const TERRAINS := ["plains", "grass", "forest", "swamp", "rough", "road", "mire", "snow", "coast", "sand", "lava", "underground"]

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
		var battles := _generated_battles(session)
		_check(battles.size() >= 3, "the generated map offers several battles: %d" % battles.size())
		var layouts := {}
		for battle in battles:
			_check_board(battle)
			_check_deployment(battle)
			_check_obstacles(battle)
			_check_destinations_avoid_obstacles(battle)
			layouts[JSON.stringify(battle.get(BattleRules.OBSTACLES_KEY, []))] = true
		_check(layouts.size() >= 2, "different battles get different fields: %d layouts in %d battles" % [layouts.size(), battles.size()])
		var battle: Dictionary = battles[0]
		_check_town_field(battle)
		_check_routing(battle)
		_check_advance(battle)
		_check_hookline(battle)
		_check_shot_penalty(battle)
		session.battle = battle.duplicate(true)
		session.game_state = "battle"
		_check_save_load(session)
		session.battle = battle.duplicate(true)
		_check_old_save(session)
		session.battle = battle.duplicate(true)
		await _check_board_view(session)
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
	return session

## Up to eight battles against the map's guards, entered as the battle screen does.
func _generated_battles(session) -> Array:
	var battles := []
	for encounter in session.overworld.get("encounters", []):
		var battle := BattleRules.create_battle_payload(session, encounter)
		if battle.is_empty() or _living(battle, "enemy").is_empty() or _living(battle, "player").is_empty():
			continue
		session.battle = battle
		session.game_state = "battle"
		_check(BattleRules.normalize_battle_state(session), "battle %s normalizes on entry" % String(battle.get("encounter_id", "")))
		battles.append(session.battle.duplicate(true))
		if battles.size() >= 8:
			break
	session.battle = {}
	session.game_state = "overworld"
	return battles

func _living(battle: Dictionary, side: String) -> Array:
	return battle.get("stacks", []).filter(func(stack): return String(stack.get("side", "")) == side and BattleRules._alive_count(stack) > 0)

func _key(cell: Dictionary) -> String:
	return "%d,%d" % [int(cell.get("q", -1)), int(cell.get("r", -1))]

func _cell(q: int, r: int) -> Dictionary:
	return {"q": q, "r": r}

func _check_board(battle: Dictionary) -> void:
	_check(BattleRules.BATTLE_HEX_COLUMNS == 11 and BattleRules.BATTLE_HEX_ROWS == 9, "the board is 11x9")
	var board: Dictionary = battle.get(BattleRules.HEX_BOARD_KEY, {})
	_check(int(board.get("columns", 0)) == 11 and int(board.get("rows", 0)) == 9, "the battle carries the 11x9 board: %s" % [board])
	_check(int(battle.get("distance", -1)) == 2, "edge deployment opens at long range: %s" % battle.get("distance", -1))

func _check_deployment(battle: Dictionary) -> void:
	for side in ["player", "enemy"]:
		var living := _living(battle, side)
		var rows := []
		for stack in living:
			var hex: Dictionary = stack.get("hex", {})
			var width := Footprint.width(stack)
			var expected_q := width - 1 if side == "player" else BattleRules.BATTLE_HEX_COLUMNS - width
			_check(int(hex.get("q", -1)) == expected_q, "%s %s stands on its edge: head %s, width %d" % [side, String(stack.get("battle_id", "")), hex, width])
			rows.append(int(hex.get("r", -1)))
		if living.size() <= 9:
			rows.sort()
			var expected_rows: Array = BattleRules._formation_rows(living.size()).duplicate()
			expected_rows.sort()
			_check(rows == expected_rows, "%s rows spread over the board height: %s, expected %s" % [side, rows, expected_rows])

func _check_obstacles(battle: Dictionary) -> void:
	var obstacles: Array = battle.get(BattleRules.OBSTACLES_KEY, [])
	var label := String(battle.get("encounter_id", ""))
	_check(obstacles.size() >= BattleRules.OBSTACLE_MIN_COUNT and obstacles.size() <= BattleRules.OBSTACLE_MAX_COUNT, "%s gets %d-%d obstacles: %d" % [label, BattleRules.OBSTACLE_MIN_COUNT, BattleRules.OBSTACLE_MAX_COUNT, obstacles.size()])
	var owner_of := {}
	for obstacle in obstacles:
		var cells: Array = obstacle.get("cells", [])
		var id := String(obstacle.get("id", ""))
		_check(String(obstacle.get("kind", "")) in BattleRules.OBSTACLE_KINDS, "%s obstacle %s has a known kind" % [label, id])
		_check(int(obstacle.get("variant", -1)) >= 0 and int(obstacle.get("variant", -1)) < BattleRules.OBSTACLE_VARIANT_COUNT, "%s obstacle %s has an art variant" % [label, id])
		_check(int(obstacle.get("size", 0)) == cells.size() and cells.size() in [1, 2], "%s obstacle %s covers one or two hexes" % [label, id])
		if cells.size() == 2:
			_check(int(cells[0].r) == int(cells[1].r) and int(cells[1].q) == int(cells[0].q) + 1, "%s obstacle %s is two hexes side by side: %s" % [label, id, cells])
		for cell in cells:
			var q := int(cell.get("q", -1))
			_check(q >= BattleRules.OBSTACLE_EDGE_CLEAR_COLUMNS and q <= BattleRules.BATTLE_HEX_COLUMNS - 1 - BattleRules.OBSTACLE_EDGE_CLEAR_COLUMNS, "%s obstacle %s keeps off the deployment columns: %s" % [label, id, cell])
			owner_of[_key(cell)] = id
	for obstacle in obstacles:
		for cell in obstacle.get("cells", []):
			for neighbor in BattleRules._hex_neighbors(cell):
				var other := String(owner_of.get(_key(neighbor), ""))
				_check(other == "" or other == String(obstacle.get("id", "")), "%s obstacles never touch: %s next to %s" % [label, String(obstacle.get("id", "")), other])
	for stack in battle.get("stacks", []):
		if BattleRules._alive_count(stack) <= 0:
			continue
		for cell in Footprint.cells(stack):
			_check(not owner_of.has(_key(cell)), "%s no stack stands on an obstacle: %s" % [label, String(stack.get("battle_id", ""))])
	_check(_crossable(owner_of, "player") and _crossable(owner_of, "enemy"), "%s a two-hex body of either side can cross the field" % label)
	var again := battle.duplicate(true)
	BattleRules._generate_battle_obstacles(again)
	_check(again.get(BattleRules.OBSTACLES_KEY, []) == obstacles, "%s the same seed gives the same field" % label)
	var cell_map := BattleRules.battle_obstacle_cells(battle)
	_check(cell_map.size() == owner_of.size(), "%s the cell map lists every obstacle cell" % label)

## Breadth-first over two-hex anchors from one edge to the other, independent of the rules' own check.
func _crossable(owner_of: Dictionary, side: String) -> bool:
	var blocked := {}
	for key in owner_of.keys():
		blocked[key] = "obstacle"
	var body := {"side": side, "battle_footprint": 2}
	var columns := BattleRules.BATTLE_HEX_COLUMNS
	var rows := BattleRules.BATTLE_HEX_ROWS
	var start_q := 1 if side == "player" else columns - 2
	var goal_q := columns - 1 if side == "player" else 0
	var frontier := []
	var seen := {}
	for r in range(rows):
		if Footprint.fits(body, _cell(start_q, r), blocked, columns, rows):
			frontier.append(_cell(start_q, r))
			seen[_key(_cell(start_q, r))] = true
	while not frontier.is_empty():
		var cell: Dictionary = frontier.pop_front()
		if int(cell.q) == goal_q:
			return true
		for neighbor in BattleRules._hex_neighbors(cell):
			if seen.has(_key(neighbor)) or not Footprint.fits(body, neighbor, blocked, columns, rows):
				continue
			seen[_key(neighbor)] = true
			frontier.append(neighbor)
	return false

func _check_destinations_avoid_obstacles(battle: Dictionary) -> void:
	var blocked := BattleRules.battle_obstacle_cells(battle)
	for stack in battle.get("stacks", []):
		if BattleRules._alive_count(stack) <= 0:
			continue
		var id := String(stack.get("battle_id", ""))
		for destination in BattleRules.legal_destinations_for_stack(battle, id):
			for cell in Footprint.cells(stack, destination):
				_check(not blocked.has(_key(cell)), "%s never moves onto an obstacle: %s" % [id, destination])

func _check_town_field(battle: Dictionary) -> void:
	for context_type in ["town_defense", "town_assault"]:
		var town := battle.duplicate(true)
		town["context"] = {"type": context_type}
		BattleRules._generate_battle_obstacles(town)
		_check(town.get(BattleRules.OBSTACLES_KEY, ["x"]).is_empty(), "a %s battle keeps an open field" % context_type)

## A synthetic board with one stack a side, a chosen field and no field objectives.
func _duel(battle: Dictionary, obstacle_cells: Array, player_cell: Dictionary, enemy_cell: Dictionary, player_setup: Dictionary = {}) -> Dictionary:
	var board := battle.duplicate(true)
	var player: Dictionary = _living(board, "player")[0].duplicate(true)
	var enemy: Dictionary = _living(board, "enemy")[0].duplicate(true)
	for stack in [player, enemy]:
		stack["battle_footprint"] = 1
		stack["effects"] = []
		stack["abilities"] = []
	player["ranged"] = false
	player["shots_remaining"] = 0
	player["speed"] = 3
	for key in player_setup.keys():
		player[key] = player_setup[key]
	player["hex"] = player_cell
	enemy["hex"] = enemy_cell
	board["stacks"] = [player, enemy]
	var obstacles := []
	for index in range(obstacle_cells.size()):
		obstacles.append({"id": "t%d" % (index + 1), "kind": "rock", "size": 1, "variant": 0, "cells": [obstacle_cells[index]]})
	board[BattleRules.OBSTACLES_KEY] = obstacles
	board[BattleRules.FIELD_OBJECTIVES_KEY] = []
	board["turn_order"] = [String(player.get("battle_id", "")), String(enemy.get("battle_id", ""))]
	board["turn_index"] = 0
	board["active_stack_id"] = String(player.get("battle_id", ""))
	BattleRules._sync_occupied_hexes(board)
	BattleRules._sync_distance_from_hexes(board)
	return board

func _player_id(board: Dictionary) -> String:
	return String(_living(board, "player")[0].get("battle_id", ""))

func _destination(destinations: Array, cell: Dictionary) -> Dictionary:
	for destination in destinations:
		if _key(destination) == _key(cell):
			return destination
	return {}

func _check_routing(battle: Dictionary) -> void:
	# A rock straight ahead: the hex behind it is two hexes away but three steps.
	var board := _duel(battle, [_cell(3, 4)], _cell(2, 4), _cell(9, 4))
	var id := _player_id(board)
	var destinations := BattleRules.legal_destinations_for_stack(board, id)
	_check(_destination(destinations, _cell(3, 4)).is_empty(), "the rock is not a destination")
	var behind := _destination(destinations, _cell(4, 4))
	_check(int(behind.get("steps", 0)) == 3, "the hex behind the rock takes a three-step detour: %s" % [behind])
	var path: Array = BattleRules._presentation_walk_path(board, _cell(2, 4), _cell(4, 4))
	_check(path.size() == 4 and not path.any(func(cell): return _key(cell) == "3,4"), "the walk goes around the rock: %s" % [path])
	var slow := _duel(battle, [_cell(3, 4)], _cell(2, 4), _cell(9, 4), {"speed": 2})
	_check(_destination(BattleRules.legal_destinations_for_stack(slow, _player_id(slow)), _cell(4, 4)).is_empty(), "two movement points cannot reach behind the rock")
	var open := _duel(battle, [], _cell(2, 4), _cell(9, 4), {"speed": 2})
	_check(int(_destination(BattleRules.legal_destinations_for_stack(open, _player_id(open)), _cell(4, 4)).get("steps", 0)) == 2, "without the rock it is two steps")
	BattleRules._set_stack_hex(board, id, _cell(3, 4))
	_check(_key(BattleRules._get_stack_by_id(board, id).get("hex", {})) == "2,4", "a stack cannot be placed on the rock")

func _gap(board: Dictionary) -> int:
	return Footprint.distance(_living(board, "player")[0], _living(board, "enemy")[0])

func _check_advance(battle: Dictionary) -> void:
	# Far off: the melee stack closes as far as it can, around the rocks.
	var board := _duel(battle, [_cell(3, 4), _cell(3, 2)], _cell(1, 4), _cell(9, 4), {"speed": 4})
	var id := _player_id(board)
	var stack := BattleRules._get_stack_by_id(board, id)
	var enemy: Dictionary = _living(board, "enemy")[0]
	var best_gap := 999
	for destination in BattleRules.legal_destinations_for_stack(board, id):
		best_gap = mini(best_gap, Footprint.distance(stack, enemy, destination))
	var before := _gap(board)
	_check(BattleRules._apply_auto_advance_movement(board, stack), "Advance moves the stack")
	var after_hex: Dictionary = BattleRules._get_stack_by_id(board, id).get("hex", {})
	_check(not BattleRules.battle_obstacle_cells(board).has(_key(after_hex)), "Advance never ends on a rock: %s" % [after_hex])
	_check(_gap(board) == best_gap and _gap(board) < before, "Advance closes as far as the movement allows: %d -> %d (best %d)" % [before, _gap(board), best_gap])
	# Within reach: melee ends next to the enemy.
	var close := _duel(battle, [], _cell(6, 4), _cell(9, 4), {"speed": 4})
	BattleRules._apply_auto_advance_movement(close, BattleRules._get_stack_by_id(close, _player_id(close)))
	_check(_gap(close) == 1, "melee Advance ends next to the enemy when it can: gap %d" % _gap(close))
	# A shooter with shots keeps out of contact.
	var shooter := _duel(battle, [], _cell(5, 4), _cell(9, 4), {"speed": 4, "ranged": true, "shots_remaining": 4})
	BattleRules._apply_auto_advance_movement(shooter, BattleRules._get_stack_by_id(shooter, _player_id(shooter)))
	_check(_gap(shooter) == 2, "a shooter's Advance stops two hexes off: gap %d" % _gap(shooter))
	var preview := BattleRules.advance_consequence_preview(_duel(battle, [_cell(3, 4)], _cell(1, 4), _cell(9, 4), {"speed": 4}))
	_check(bool(preview.get("ok", false)) and not BattleRules.battle_obstacle_cells(board).has(_key(preview.get("destination", {}))), "the Advance preview names a destination off the rocks: %s" % [preview])

func _check_hookline(battle: Dictionary) -> void:
	var blocked := _duel(battle, [_cell(3, 4)], _cell(2, 4), _cell(4, 4))
	var attacker: Dictionary = _living(blocked, "player")[0]
	var defender: Dictionary = _living(blocked, "enemy")[0]
	_check(not BattleRules._apply_hookline_pull(blocked, attacker, defender), "a hookline cannot pull a stack onto a rock")
	_check(_key(_living(blocked, "enemy")[0].get("hex", {})) == "4,4", "the pulled stack stays put")
	var open := _duel(battle, [], _cell(2, 4), _cell(4, 4))
	_check(BattleRules._apply_hookline_pull(open, _living(open, "player")[0], _living(open, "enemy")[0]) and _key(_living(open, "enemy")[0].get("hex", {})) == "3,4", "on open ground the same pull lands")

## Both boards keep a pair of stacks in contact elsewhere, so only the shooter's
## own contact differs.
func _shot_board(battle: Dictionary, blocker_cell: Dictionary) -> Dictionary:
	var board := battle.duplicate(true)
	var shooter: Dictionary = _living(board, "player")[0].duplicate(true)
	var escort := shooter.duplicate(true)
	var enemies := _living(board, "enemy")
	var blocker: Dictionary = enemies[0].duplicate(true)
	var target: Dictionary = (enemies[1] if enemies.size() > 1 else enemies[0]).duplicate(true)
	escort["battle_id"] = String(shooter.get("battle_id", "")) + "_escort"
	if enemies.size() < 2:
		target["battle_id"] = String(target.get("battle_id", "")) + "_target"
	for stack in [shooter, escort, blocker, target]:
		stack["battle_footprint"] = 1
		stack["effects"] = []
		stack["defending"] = false
	shooter["ranged"] = true
	shooter["shots_remaining"] = 4
	escort["ranged"] = false
	shooter["hex"] = _cell(2, 4)
	target["hex"] = _cell(8, 4)
	blocker["hex"] = blocker_cell
	escort["hex"] = _cell(7, 8) if _key(blocker_cell) == "8,8" else _cell(9, 1)
	board["stacks"] = [shooter, escort, blocker, target]
	if _key(blocker_cell) != "8,8":
		# Keep a contact pair elsewhere on the engaged board too.
		var lookout := target.duplicate(true)
		lookout["battle_id"] = String(target.get("battle_id", "")) + "_lookout"
		lookout["hex"] = _cell(9, 0)
		board["stacks"].append(lookout)
	board[BattleRules.OBSTACLES_KEY] = []
	board[BattleRules.FIELD_OBJECTIVES_KEY] = []
	board["battlefield_tags"] = []
	BattleRules._sync_occupied_hexes(board)
	BattleRules._sync_distance_from_hexes(board)
	return board

func _check_shot_penalty(battle: Dictionary) -> void:
	var engaged_board := _shot_board(battle, _cell(3, 4))
	var free_board := _shot_board(battle, _cell(8, 8))
	_check(int(engaged_board.get("distance", -1)) == 0 and int(free_board.get("distance", -1)) == 0, "both boards have stacks in contact")
	var results := []
	for board in [engaged_board, free_board]:
		var shooter: Dictionary = _living(board, "player")[0]
		var target: Dictionary = BattleRules._get_stack_by_id(board, String(_living(board, "enemy")[1].get("battle_id", "")))
		var distance := BattleRules._attack_distance_for_action(shooter, target, board, true)
		results.append({
			"engaged": BattleRules._stack_is_engaged(shooter, board),
			"ai_engaged": BattleAiRules._stack_is_engaged(shooter, board),
			"distance": distance,
			"modifier": BattleRules._damage_modifier(shooter, target, board, true, false, distance),
			"estimate": BattleAiRules._estimate_damage(shooter, target, board, true, false, distance),
		})
	var engaged: Dictionary = results[0]
	var free: Dictionary = results[1]
	_check(bool(engaged.engaged) and bool(engaged.ai_engaged), "a shooter next to an enemy is engaged")
	_check(not bool(free.engaged) and not bool(free.ai_engaged), "a shooter with no enemy beside it is free")
	_check(int(engaged.distance) == int(free.distance) and int(free.distance) > 0, "the shot itself is the same distance either way: %s" % [results])
	_check(float(free.modifier) > 0.0 and absf(float(engaged.modifier) / float(free.modifier) - 0.6) < 0.0001, "a shot at a distant stack from beside an enemy does x0.6: %s" % [results])
	_check(int(engaged.estimate) < int(free.estimate), "the computer's damage estimate knows the penalty: %s" % [results])

func _check_save_load(session) -> void:
	var obstacles := BattleRules.battle_obstacles(session.battle)
	var hexes := {}
	for stack in session.battle.get("stacks", []):
		hexes[String(stack.get("battle_id", ""))] = _key(stack.get("hex", {}))
	var active := String(session.battle.get("active_stack_id", ""))
	var destinations := BattleRules.legal_destinations_for_stack(session.battle, active)
	session.battle = JSON.parse_string(JSON.stringify(session.battle))
	_check(BattleRules.normalize_battle_state(session), "the battle normalizes after a JSON reload")
	_check(BattleRules.battle_obstacles(session.battle) == obstacles, "the obstacles survive a save and load: %s" % [BattleRules.battle_obstacles(session.battle)])
	var moved := []
	for stack in session.battle.get("stacks", []):
		if hexes.get(String(stack.get("battle_id", "")), "") != _key(stack.get("hex", {})):
			moved.append(String(stack.get("battle_id", "")))
	_check(moved.is_empty(), "no stack moves on load: %s" % [moved])
	var reloaded := BattleRules.legal_destinations_for_stack(session.battle, active)
	_check(JSON.stringify(reloaded) == JSON.stringify(destinations), "the same destinations after the reload")

func _check_old_save(session) -> void:
	session.battle.erase(BattleRules.OBSTACLES_KEY)
	session.battle = JSON.parse_string(JSON.stringify(session.battle))
	_check(BattleRules.normalize_battle_state(session), "a save from before obstacles normalizes")
	_check(BattleRules.battle_obstacles(session.battle).is_empty() and session.battle.get(BattleRules.OBSTACLES_KEY, null) is Array, "it loads with an open field")

func _check_board_view(session) -> void:
	for terrain in TERRAINS:
		for kind in BattleRules.OBSTACLE_KINDS:
			for size in [1, 2]:
				var path := BattleBoardViewScript.obstacle_art_path(terrain, {"kind": kind, "size": size, "variant": BattleRules.OBSTACLE_VARIANT_COUNT - 1})
				_check(ResourceLoader.exists(path), "%s has %s art for %d hex%s: %s" % [terrain, kind, size, "" if size == 1 else "es", path])
	var prewarm := BattleBoardViewScript.art_texture_paths_for_battle(session.battle)
	for obstacle in BattleRules.battle_obstacles(session.battle):
		_check(prewarm.has(BattleBoardViewScript.obstacle_art_path(String(session.battle.get("terrain", "")), obstacle)), "the battle entry loads obstacle %s ahead" % String(obstacle.get("id", "")))
	var view := BattleBoardViewScript.new()
	view.size = Vector2(1280.0, 720.0)
	add_child(view)
	view.set_battle_state(session)
	await get_tree().process_frame
	await get_tree().process_frame
	var summary: Dictionary = view.validation_hex_layout_summary()
	_check(int(summary.get("rows", 0)) == 9 and int(summary.get("hex_count", 0)) == 99, "the board view lays out 11x9")
	var drawn: Array = summary.get("obstacles", [])
	_check(drawn.size() == BattleRules.battle_obstacles(session.battle).size(), "the board view draws every obstacle: %d" % drawn.size())
	for entry in drawn:
		var rect: Rect2 = entry.get("art_rect", Rect2())
		_check(bool(entry.get("art_loaded", false)) and rect.size.x > 0.0, "obstacle %s draws its art: %s" % [String(entry.get("id", "")), entry.get("art_path", "")])
	var blocked := BattleRules.battle_obstacle_cells(session.battle)
	for objective in summary.get("field_objective_cells", []):
		_check(not blocked.has("%d,%d" % [int(objective.get("q", -1)), int(objective.get("r", -1))]), "objective marker %s stays off the obstacles" % String(objective.get("id", "")))
	view.queue_free()
