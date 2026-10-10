extends Node
## The field cursor and the forecast beside it (docs/battle-rework.md, slice 6:
## owner requests 2026-10-09 "the end hex of a melee attack" and "a sword or
## an arrow cursor with the estimated damage") on a generated small map.
##
## The rules part resolves each order with one damage seed after another: the
## damage, kills and strike-back losses always lie in the forecast's ranges,
## and the ranges' ends are met, for a strike from each of the six sides of a
## target (whose walk is the one the playback shows), a shot (shots 4 → 3), a
## point-blank shot, a shooter's strike in melee, a strike on a target that
## has struck back already, and the hero's damage spell.
##
## The screen part opens the battle on hand-placed stacks and moves the
## pointer: pointing at a side of an enemy picks that side, and a side another
## stack or a rock takes gives the nearest open one; Q and E turn the side
## round the target and a click or Enter strikes from it; Ctrl turns a
## point-blank shot into a strike, and Ctrl-click strikes. Each cursor shows:
## a sword, an arrow, a broken arrow, a boot, a spark, a barred circle, the
## info badge, nothing on the scenery and the pointing hand on the hero. No
## forecast names an end hex.
##
## A rendering run given "-- --capture-dir=<dir>" saves a screenshot of each
## cursor for review.

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const REPORT_ID := "BATTLE_CURSOR_FORECAST_REPORT"
const SEED := "battle-cursor-forecast-20261010"
const PLAY_SIZE := Vector2i(1920, 1080)
## Damage seeds tried before the resolved outcomes must have met both ends of
## the forecast's ranges.
const MAX_SEEDS := 400
const PLAYBACK_WAIT_MSEC := 30000
const SPELL_ID := "spell_cinder_burst"
## Where the attacker's friend stands: out of the way, acting next so an order
## resolves without the enemy's turn after it.
const FRIEND_CELL := {"q": 0, "r": 8}
## How far from the middle of the target's hex the pointer points at a side,
## in hex radii: past the neutral middle, inside the hex.
const SIDE_POINT_SHARE := 0.55

var _checks := 0
var _failures: Array[String] = []
var _details := {}
var _capture_dir := ""
var _base_session = null
var _battle: Dictionary = {}


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
		push_error("%s check failed: %s" % [REPORT_ID, label])


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--capture-dir="):
			_capture_dir = String(arg).trim_prefix("--capture-dir=")
	if _capture_dir != "":
		DirAccess.make_dir_recursive_absolute(_capture_dir)
		SettingsService.set_battle_playback_speed_id("fast")
	AppRouter.validation_set_battle_report_routing_suppressed(true)
	_base_session = _session()
	if _base_session != null:
		_battle = _base_session.battle.duplicate(true)
		if _capture_dir == "":
			_check_strike_sides()
			_check_shots()
			_check_shooter_strike()
			_check_no_strike_back()
			_check_spell()
		await _check_melee_cursor()
		await _check_snapping_and_keys()
		await _check_far_shooter()
		await _check_point_blank()
		await _check_spell_cursor()
	AppRouter.validation_set_battle_report_routing_suppressed(false)
	var report := {"ok": _failures.is_empty(), "checks": _checks, "failures": _failures, "details": _details}
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
		if not _living(battle, "enemy").is_empty() and not _living(battle, "player").is_empty():
			session.battle = battle
			session.game_state = "battle"
			_details["encounter"] = String(battle.get("encounter_id", ""))
			return session
	_check(false, "a guard battle on the generated map")
	return null


func _living(battle: Dictionary, side: String) -> Array:
	return battle.get("stacks", []).filter(func(stack): return stack is Dictionary and String(stack.get("side", "")) == side and BattleRules._alive_count(stack) > 0)


func _cell(q: int, r: int) -> Dictionary:
	return {"q": q, "r": r}


func _key(cell: Dictionary) -> String:
	return "%d,%d" % [int(cell.get("q", -1)), int(cell.get("r", -1))]


func _vec(cell: Dictionary) -> Vector2i:
	return Vector2i(int(cell.get("q", -1)), int(cell.get("r", -1)))


func _stack(battle: Dictionary, battle_id: String) -> Dictionary:
	return BattleRules._get_stack_by_id(battle, battle_id)


func _cells_by_key(cells: Array) -> Dictionary:
	var by_key := {}
	for cell in cells:
		by_key[_key(cell)] = cell
	return by_key


## A board from the generated battle's stacks on an open field without
## objectives: the player's attacker (20 units of 10 health, 2–4 damage, 6
## hexes a turn) is active against the enemy's target (40 units, 1–3 damage),
## with the attacker's friend acting next. The hero knows Cinder Burst and has
## full mana. Rocks stand on rocks.
func _board(session, attacker_cell: Dictionary, target_cell: Dictionary, attacker_setup: Dictionary = {}, target_setup: Dictionary = {}, rocks: Array = [], friend_cell: Dictionary = FRIEND_CELL) -> Dictionary:
	session.battle = _battle.duplicate(true)
	session.game_state = "battle"
	var board: Dictionary = session.battle
	var attacker: Dictionary = _living(board, "player")[0].duplicate(true)
	var target: Dictionary = _living(board, "enemy")[0].duplicate(true)
	var friend: Dictionary = attacker.duplicate(true)
	attacker["battle_id"] = "report_attacker"
	target["battle_id"] = "report_target"
	friend["battle_id"] = "report_friend"
	for stack in [attacker, target, friend]:
		_plain(stack)
	attacker.merge({"base_count": 20, "total_health": 200, "min_damage": 2, "max_damage": 4, "speed": 6}, true)
	target.merge({"base_count": 40, "total_health": 400, "min_damage": 1, "max_damage": 3}, true)
	attacker.merge(attacker_setup, true)
	target.merge(target_setup, true)
	attacker["hex"] = attacker_cell
	target["hex"] = target_cell
	friend["hex"] = friend_cell
	board["stacks"] = [attacker, target, friend]
	var obstacles := []
	for index in range(rocks.size()):
		obstacles.append({"id": "t%d" % (index + 1), "kind": "rock", "size": 1, "variant": 0, "cells": [rocks[index]]})
	board[BattleRules.OBSTACLES_KEY] = obstacles
	board[BattleRules.FIELD_OBJECTIVES_KEY] = []
	board["battlefield_tags"] = []
	board["turn_order"] = ["report_attacker", "report_friend", "report_target"]
	board["turn_index"] = 0
	board["active_stack_id"] = "report_attacker"
	board["selected_target_id"] = "report_target"
	board["enemy_hero"] = {}
	board["enemy_hero_payload"] = {}
	var commander: Dictionary = (board.get("player_commander_state", {}) as Dictionary).duplicate(true)
	var spellbook: Dictionary = (commander.get("spellbook", {}) as Dictionary).duplicate(true) if commander.get("spellbook", {}) is Dictionary else {}
	var known: Array = (spellbook.get("known_spell_ids", []) as Array).duplicate()
	if not known.has(SPELL_ID):
		known.append(SPELL_ID)
	var mana_max := SpellRules.mana_max_from_hero(commander)
	spellbook["known_spell_ids"] = known
	spellbook["mana"] = {"current": mana_max, "max": mana_max}
	commander["spellbook"] = spellbook
	board["player_commander_state"] = commander
	BattleRules._sync_occupied_hexes(board)
	BattleRules._sync_distance_from_hexes(board)
	return board


## A plain one-hex stack of 10-health units: no abilities or effects.
func _plain(stack: Dictionary) -> void:
	stack["battle_footprint"] = 1
	stack["effects"] = []
	stack["abilities"] = []
	stack["defending"] = false
	stack["ranged"] = false
	stack["shots_remaining"] = 0
	stack["unit_hp"] = 10
	stack["retaliations_left"] = 1
	stack["speed"] = 4


func _forecast_text(preview: Dictionary) -> String:
	return BattleRules.forecast_text(preview.get("forecast_lines", []))


## The first walk the active stack's playback shows.
func _walk_path(result: Dictionary) -> Array:
	for frame in result.get("playback_frames", []):
		var event: Dictionary = frame.get("playback_event", {})
		if String(event.get("event_id", "")) == "battle_unit_move" and String(event.get("battle_id", "")) == "report_attacker":
			return event.get("walk_path", [])
	return []


# --- The forecast against what the rules resolve ---------------------------------

## Resolves action on board with one damage seed after another: every outcome
## lies in the forecast's ranges, and both ends of each range are met (the
## damage and kills dealt, the damage and units the strike-back costs).
func _check_bounds(session, board: Dictionary, action: String, approach: Dictionary, preview: Dictionary, label: String) -> void:
	var damage: Dictionary = preview.get("damage", {})
	var incoming: Dictionary = preview.get("incoming", {})
	var want := {
		"damage": [int(damage.get("min_damage", 0)), int(damage.get("max_damage", 0))],
		"kills": [int(damage.get("min_units", 0)), int(damage.get("max_units", 0))],
		"strike-back damage": [int(incoming.get("min_damage", 0)), int(incoming.get("max_damage", 0))],
		"strike-back losses": [int(incoming.get("min_units", 0)), int(incoming.get("max_units", 0))],
	}
	var target_id := String(preview.get("target_id", "report_target"))
	var seen := {}
	var outside: Array[String] = []
	var tries := 0
	for index in range(MAX_SEEDS):
		tries += 1
		session.battle = board.duplicate(true)
		session.battle["combat_seed"] = 104729 + index * 7919
		BattleRules._initialize_damage_rng_state(session, session.battle)
		var target_before := _stack(session.battle, target_id).duplicate(true)
		var attacker_before := _stack(session.battle, "report_attacker").duplicate(true)
		var result := BattleRules.perform_presented_action(session, action, approach)
		if not bool(result.get("ok", false)):
			_check(false, "%s: the order is accepted: %s" % [label, result.get("message", "")])
			return
		var target_after := _stack(session.battle, target_id)
		var attacker_after := _stack(session.battle, "report_attacker")
		var outcome := {
			"damage": int(target_before.get("total_health", 0)) - int(target_after.get("total_health", 0)),
			"kills": BattleRules._alive_count(target_before) - BattleRules._alive_count(target_after),
			"strike-back damage": int(attacker_before.get("total_health", 0)) - int(attacker_after.get("total_health", 0)),
			"strike-back losses": BattleRules._alive_count(attacker_before) - BattleRules._alive_count(attacker_after),
		}
		for key in outcome.keys():
			var value := int(outcome[key])
			var bounds: Array = want[key]
			if value < int(bounds[0]) or value > int(bounds[1]):
				outside.append("%s %d outside %d–%d" % [key, value, int(bounds[0]), int(bounds[1])])
			var pair: Array = seen.get(key, [value, value])
			seen[key] = [mini(int(pair[0]), value), maxi(int(pair[1]), value)]
		if not outside.is_empty():
			break
		if want.keys().all(func(key): return seen.get(key, []) == want[key]):
			break
	_check(outside.is_empty(), "%s: every outcome lies in the forecast %s" % [label, outside.slice(0, 3)])
	for key in want.keys():
		_check(seen.get(key, []) == want[key], "%s: the %s resolved over %d seeds spans the forecast %s (seen %s)" % [label, key, tries, want[key], seen.get(key, [])])
	_details["bounds_%s" % label] = {"forecast": want, "seeds": tries}


func _check_strike_sides() -> void:
	var session = _base_session
	var board := _board(session, _cell(2, 4), _cell(6, 4))
	var cells := BattleRules.melee_approach_cells(board, _stack(board, "report_attacker"), _stack(board, "report_target"))
	_check(cells.size() == 6, "rules: an open target has six sides to strike from (%d)" % cells.size())
	for cell in cells:
		var approach := {"q": int(cell.get("q", -1)), "r": int(cell.get("r", -1))}
		var label := "strike from %s" % _key(cell)
		var preview := BattleRules.attack_consequence_preview(board, "strike", "report_target", approach)
		_check(bool(preview.get("ok", false)), "%s: the forecast is made: %s" % [label, preview.get("message", "")])
		if not bool(preview.get("ok", false)):
			continue
		var steps := int(cell.get("steps", 0))
		var path: Array = preview.get("path", [])
		_check(int(preview.get("steps", -1)) == steps and path.size() == steps + 1 and _key(path.back()) == _key(cell), "%s: the forecast walks %d steps to it: %s" % [label, steps, path])
		var text := _forecast_text(preview)
		_check(text.contains("Moves %d hex" % steps) and text.contains("Kills") and text.contains("Strikes back: lose"), "%s: the forecast says the kills, the strike-back and the walk: %s" % [label, text])
		_check(not text.contains("End hex") and not String(preview.get("message", "")).contains("End hex"), "%s: the forecast names no end hex: %s" % [label, preview.get("message", "")])
		session.battle = board.duplicate(true)
		var result := BattleRules.perform_presented_action(session, "strike", approach)
		var walk := _walk_path(result).map(func(step): return _key(step))
		_check(walk == path.map(func(step): return _key(step)), "%s: the playback walks the forecast's path %s (%s)" % [label, walk, path.map(func(step): return _key(step))])
		_check_bounds(session, board, "strike", approach, preview, label)


func _check_shots() -> void:
	var session = _base_session
	var far := _board(session, _cell(2, 4), _cell(6, 4), {"ranged": true, "shots_remaining": 4})
	var shot := BattleRules.attack_consequence_preview(far, "shoot", "report_target")
	var text := _forecast_text(shot)
	_check(bool(shot.get("ok", false)) and int(shot.get("shots_before", 0)) == 4 and int(shot.get("shots_after", 0)) == 3, "shot: the forecast counts the shots 4 → 3 (%s → %s)" % [shot.get("shots_before", ""), shot.get("shots_after", "")])
	_check(text.contains("No retaliation · shots 4 → 3") and not bool(shot.get("penalised", true)), "shot: the forecast says no retaliation and the shots left: %s" % text)
	_check(not text.contains("End hex") and not String(shot.get("message", "")).contains("End hex"), "shot: the forecast names no end hex: %s" % shot.get("message", ""))
	_check_bounds(session, far, "shoot", {}, shot, "shot")
	session.battle = far.duplicate(true)
	BattleRules.perform_presented_action(session, "shoot")
	_check(int(_stack(session.battle, "report_attacker").get("shots_remaining", 0)) == 3, "shot: the shot leaves 3 shots")
	var close := _board(session, _cell(5, 4), _cell(6, 4), {"ranged": true, "shots_remaining": 4})
	var point_blank := BattleRules.attack_consequence_preview(close, "shoot", "report_target")
	_check(bool(point_blank.get("penalised", false)) and _forecast_text(point_blank).contains("Point-blank: -40% damage"), "point-blank shot: the forecast warns of the penalty: %s" % _forecast_text(point_blank))
	_check_bounds(session, close, "shoot", {}, point_blank, "point-blank shot")


## A shooter beside its target strikes in melee from where it stands, and
## keeps its shots.
func _check_shooter_strike() -> void:
	var session = _base_session
	var board := _board(session, _cell(5, 4), _cell(6, 4), {"ranged": true, "shots_remaining": 4})
	var cells := BattleRules.melee_approach_cells(board, _stack(board, "report_attacker"), _stack(board, "report_target"))
	var stand: Dictionary = cells[0] if not cells.is_empty() else {}
	_check(_key(stand) == "5,4" and int(stand.get("steps", -1)) == 0, "shooter's strike: it can strike from where it stands: %s" % [stand])
	var approach := {"q": 5, "r": 4}
	var preview := BattleRules.attack_consequence_preview(board, "strike", "report_target", approach)
	_check(bool(preview.get("ok", false)) and _forecast_text(preview).contains("Strikes from where it stands") and not bool(preview.get("penalised", true)), "shooter's strike: the forecast strikes in place without the shot's penalty: %s" % _forecast_text(preview))
	_check_bounds(session, board, "strike", approach, preview, "shooter's strike")
	session.battle = board.duplicate(true)
	BattleRules.perform_presented_action(session, "strike", approach)
	_check(int(_stack(session.battle, "report_attacker").get("shots_remaining", 0)) == 4, "shooter's strike: the strike keeps its shots")


func _check_no_strike_back() -> void:
	var session = _base_session
	var board := _board(session, _cell(2, 4), _cell(6, 4), {}, {"retaliations_left": 0})
	var nearest := BattleRules.melee_approach_destination(board, _stack(board, "report_attacker"), _stack(board, "report_target"))
	var approach := {"q": int(nearest.get("q", -1)), "r": int(nearest.get("r", -1))}
	var preview := BattleRules.attack_consequence_preview(board, "strike", "report_target", approach)
	var lines: Array = preview.get("forecast_lines", [])
	var reply: Dictionary = lines[1] if lines.size() > 1 else {}
	_check(String(reply.get("text", "")) == "No retaliation" and String(reply.get("detail", "")) == "(it has struck back this round)" and String(reply.get("tone", "")) == "green", "no strike-back: the forecast says why: %s" % [reply])
	_check_bounds(session, board, "strike", approach, preview, "no strike-back")


func _check_spell() -> void:
	var session = _base_session
	var board := _board(session, _cell(2, 4), _cell(6, 4))
	session.battle = board.duplicate(true)
	var preview := BattleRules.spell_consequence_preview(session, SPELL_ID, "report_target")
	_check(bool(preview.get("ok", false)), "spell: the forecast is made: %s" % preview.get("message", ""))
	if not bool(preview.get("ok", false)):
		return
	var lines: Array = preview.get("forecast_lines", [])
	var spell_name := String(ContentService.get_spell(SPELL_ID).get("name", SPELL_ID))
	var head: Dictionary = lines[0] if not lines.is_empty() else {}
	var hit: Dictionary = lines[1] if lines.size() > 1 else {}
	_check(String(head.get("text", "")) == spell_name and String(head.get("detail", "")) == "%d mana" % int(preview.get("mana_cost", 0)), "spell: the forecast names the spell and its cost: %s" % [head])
	_check(String(hit.get("text", "")) == "%d damage · kills %d" % [int(preview.get("damage", 0)), int(preview.get("casualties", 0))], "spell: the forecast says the damage and kills: %s" % [hit])
	var before := _stack(session.battle, "report_target").duplicate(true)
	var result := BattleRules.perform_presented_action(session, "cast_spell:" + SPELL_ID, {"target_id": "report_target"})
	var after := _stack(session.battle, "report_target")
	_check(bool(result.get("ok", false)), "spell: the cast is accepted: %s" % result.get("message", ""))
	var dealt := int(before.get("total_health", 0)) - int(after.get("total_health", 0))
	var killed := BattleRules._alive_count(before) - BattleRules._alive_count(after)
	_check(dealt == int(preview.get("damage", 0)) and killed == int(preview.get("casualties", 0)), "spell: the cast deals the forecast's %d damage and kills %d (%d, %d)" % [int(preview.get("damage", 0)), int(preview.get("casualties", 0)), dealt, killed])
	_check(String(session.battle.get("active_stack_id", "")) == "report_attacker", "spell: the stack keeps its turn")


# --- The battle screen ---------------------------------------------------------

## Opens the battle screen on a board (see _board).
func _open_board(attacker_cell: Dictionary, target_cell: Dictionary, attacker_setup: Dictionary = {}, rocks: Array = [], friend_cell: Dictionary = FRIEND_CELL):
	_board(_base_session, attacker_cell, target_cell, attacker_setup, {}, rocks, friend_cell)
	SessionState.set_active_session(_base_session)
	var frame := Control.new()
	frame.name = "BattleFrame"
	frame.size = Vector2(PLAY_SIZE) if _capture_dir == "" else get_viewport().get_visible_rect().size
	add_child(frame)
	var shell = load("res://scenes/battle/BattleShell.tscn").instantiate()
	frame.add_child(shell)
	for _frame in range(4):
		await get_tree().process_frame
	var opened: bool = shell._session != null and not shell._session.battle.is_empty()
	_check(opened, "screen: the battle screen opens on the hand-placed board")
	if opened:
		_check(String(shell._session.battle.get("active_stack_id", "")) == "report_attacker", "screen: the player's stack is active on the hand-placed board")
	return shell


func _close_shell(shell) -> void:
	var frame: Node = shell.get_parent()
	frame.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func _settle(shell) -> void:
	var deadline := Time.get_ticks_msec() + PLAYBACK_WAIT_MSEC
	while (shell._action_playback_in_progress or shell._battle_exit_handoff_in_progress) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	await get_tree().process_frame


func _capture(label: String) -> void:
	if _capture_dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(_capture_dir.path_join("%s.png" % label))


func _hover_at(position: Vector2, ctrl: bool = false) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	motion.relative = Vector2(6.0, 0.0)
	motion.ctrl_pressed = ctrl
	get_viewport().push_input(motion, true)
	await get_tree().process_frame
	await get_tree().process_frame


func _click_at(position: Vector2, ctrl: bool = false) -> void:
	await _hover_at(position, ctrl)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = position
		event.global_position = position
		event.pressed = pressed
		event.ctrl_pressed = ctrl
		get_viewport().push_input(event, true)
		await get_tree().process_frame


func _key_event(keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)
	await get_tree().process_frame


func _press_key(keycode: Key) -> void:
	await _key_event(keycode, true)
	await _key_event(keycode, false)


func _cell_position(board, cell: Dictionary) -> Vector2:
	return board.global_position + board._hex_center(_vec(cell), board._current_hex_layout())


## A point on the target's hex toward one of its sides, past the neutral
## middle, turned by turn radians.
func _side_point(board, target_cell: Dictionary, side_cell: Dictionary, turn: float = 0.0) -> Vector2:
	var layout: Dictionary = board._current_hex_layout()
	var radius := float(layout.get("radius", 1.0))
	var center: Vector2 = board._hex_center(_vec(target_cell), layout)
	var side: Vector2 = board._hex_center(_vec(side_cell), layout)
	var direction: Vector2 = board._unsquashed(side - center).normalized().rotated(turn)
	return board.global_position + center + Vector2(direction.x, direction.y * board.HEX_VERTICAL_SCALE) * radius * SIDE_POINT_SHARE


## A point on the painted scenery: off the hexes, the heroes, the ribbon and
## every part of the HUD.
func _scenery_point(shell, board) -> Vector2:
	var rects: Dictionary = shell.validation_hud_snapshot().get("rects", {})
	var grid: Rect2 = board._current_hex_layout().get("rect", Rect2())
	var columns := [grid.end.x + (board.size.x - grid.end.x) * 0.5, grid.position.x * 0.5]
	for x in columns:
		for y in range(int(grid.position.y), int(grid.end.y), 24):
			var point := Vector2(float(x), float(y))
			if board._cell_in_bounds(board._hex_cell_at_position(point)) or board._hero_side_at_position(point) != "" or board._ribbon_rect().has_point(point):
				continue
			if rects.values().any(func(rect): return (rect as Rect2).has_point(point)):
				continue
			return board.global_position + point
	return Vector2(-1.0, -1.0)


func _order(board) -> Dictionary:
	return board.validation_pointer_order()


func _forecast(order: Dictionary) -> String:
	return " | ".join(order.get("forecast", PackedStringArray()))


func _note_forecast(kind: String, order: Dictionary) -> void:
	_details["forecast_%s" % kind] = _forecast(order)
	_check(not _forecast(order).contains("End hex"), "%s: the forecast names no end hex: %s" % [kind, _forecast(order)])


func _ring(order: Dictionary) -> Array:
	return (order.get("approaches", []) as Array).map(func(entry): return _key(entry))


## The sword on each side of an open target, Q and E, the other cursors, and a
## click that strikes from the turned side.
func _check_melee_cursor() -> void:
	var rock := _cell(4, 7)
	var target_cell := _cell(6, 4)
	var shell = await _open_board(_cell(2, 4), target_cell, {}, [rock])
	var board = shell._battle_board_view
	var battle: Dictionary = shell._session.battle
	var approaches := BattleRules.melee_approach_cells(battle, _stack(battle, "report_attacker"), _stack(battle, "report_target"))
	var by_key := _cells_by_key(approaches)
	var fewest := 1 << 30
	for entry in approaches:
		fewest = mini(fewest, int(entry.get("steps", 0)))
	# The middle of the target strikes from the nearest side.
	await _hover_at(_cell_position(board, target_cell))
	var order := _order(board)
	_check(String(order.get("kind", "")) == "strike" and String(order.get("cursor", "")) == "sword" and String(order.get("sector", "")) == "middle", "sword: the middle of an enemy shows the sword (%s, %s, %s)" % [order.get("kind", ""), order.get("cursor", ""), order.get("sector", "")])
	_check(by_key.has(_key(order.get("approach", {}))) and int((order.get("approach", {}) as Dictionary).get("steps", -1)) == fewest, "sword: from the middle it strikes from the nearest side (%s, %d steps)" % [_key(order.get("approach", {})), fewest])
	_check(int(order.get("cursor_shape", -1)) == Control.CURSOR_CROSS, "sword: the system cursor gives way to the board's (%s)" % order.get("cursor_shape", -1))
	var lines: PackedStringArray = order.get("forecast", PackedStringArray())
	_check(lines.size() >= 3 and (lines[0].begins_with("Kills") or lines[0].begins_with("Destroys")) and lines[1].begins_with("Strikes back") and _forecast(order).contains("Moves %d hex" % fewest), "sword: the forecast says the kills, the strike-back and the walk: %s" % _forecast(order))
	_check(_forecast(order).contains("point at another side, or turn it with Q and E"), "sword: the forecast says how to turn the side: %s" % _forecast(order))
	_note_forecast("sword", order)
	await _capture("cursor_sword")
	# Pointing at a side of the target strikes from that side.
	_check(by_key.size() == 6, "sword: an open target has six sides (%d)" % by_key.size())
	for side in BattleRules._hex_neighbors(target_cell):
		var key := _key(side)
		if not by_key.has(key):
			continue
		await _hover_at(_side_point(board, target_cell, side))
		order = _order(board)
		_check(_key(order.get("approach", {})) == key and String(order.get("sector", "")) == key, "sword: pointing at side %s strikes from it (%s, sector %s)" % [key, _key(order.get("approach", {})), order.get("sector", "")])
		var blow: float = (board._hex_center(_vec(target_cell), board._current_hex_layout()) - board._hex_center(_vec(side), board._current_hex_layout())).angle()
		_check(absf(angle_difference(float(order.get("angle", 0.0)), blow)) < 0.02, "sword: from side %s the sword points along the blow (%.2f, %.2f)" % [key, float(order.get("angle", 0.0)), blow])
		_check(_forecast(order).contains("Moves %d hex" % int(by_key[key].get("steps", 0))), "sword: from side %s the forecast walks %d hexes: %s" % [key, int(by_key[key].get("steps", 0)), _forecast(order)])
	var angles: Array = (order.get("approaches", []) as Array).map(func(entry): return float(entry.get("angle", 0.0)))
	var sorted_angles := angles.duplicate()
	sorted_angles.sort()
	_check(angles == sorted_angles and angles.size() == 6, "sword: the sides go round clockwise %s" % [angles])
	# Q and E turn the side round the target, and the turn holds in its sector.
	var west := _cell(5, 4)
	var east := _cell(7, 4)
	var west_point := _side_point(board, target_cell, west)
	await _hover_at(west_point)
	var ring := _ring(_order(board))
	var at := ring.find("5,4")
	await _press_key(KEY_E)
	_check(_key(_order(board).get("approach", {})) == ring[posmod(at + 1, ring.size())], "keys: E turns the side clockwise (%s → %s)" % [ring[at], _key(_order(board).get("approach", {}))])
	await _press_key(KEY_Q)
	_check(_key(_order(board).get("approach", {})) == "5,4", "keys: Q turns it back (%s)" % _key(_order(board).get("approach", {})))
	await _press_key(KEY_Q)
	var turned: String = ring[posmod(at - 1, ring.size())]
	_check(_key(_order(board).get("approach", {})) == turned, "keys: Q turns it the other way (%s, %s)" % [turned, _key(_order(board).get("approach", {}))])
	await _capture("cursor_sword_turned")
	await _hover_at(west_point + Vector2(2.0, 1.0))
	_check(_key(_order(board).get("approach", {})) == turned, "keys: the turn holds while the pointer stays on that side (%s)" % _key(_order(board).get("approach", {})))
	await _hover_at(_side_point(board, target_cell, east))
	_check(_key(_order(board).get("approach", {})) == "7,4", "keys: pointing at another side drops the turn (%s)" % _key(_order(board).get("approach", {})))
	await _hover_at(west_point)
	_check(_key(_order(board).get("approach", {})) == "5,4", "keys: coming back points at the side again (%s)" % _key(_order(board).get("approach", {})))
	# The other cursors.
	await _check_other_cursors(shell, board, rock)
	# A click strikes from the turned side.
	await _hover_at(west_point)
	await _press_key(KEY_Q)
	var health_before := int(_stack(shell._session.battle, "report_target").get("total_health", 0))
	await _click_at(west_point)
	await _settle(shell)
	var moved := _stack(shell._session.battle, "report_attacker")
	_check(_key(moved.get("hex", {})) == turned, "click: the stack strikes from the turned side %s (%s)" % [turned, _key(moved.get("hex", {}))])
	_check(int(_stack(shell._session.battle, "report_target").get("total_health", 0)) < health_before, "click: the strike lands")
	await _close_shell(shell)


## The boot, the barred circle, the info badge, the scenery and the hero.
func _check_other_cursors(shell, board, rock: Dictionary) -> void:
	var walk_to := _cell(3, 2)
	await _hover_at(_cell_position(board, walk_to))
	var order := _order(board)
	var path: Array = (order.get("preview", {}) as Dictionary).get("path", [])
	_check(String(order.get("kind", "")) == "move" and String(order.get("cursor", "")) == "boot" and int(order.get("cursor_shape", -1)) == Control.CURSOR_CROSS, "boot: an open hex in reach shows the boot (%s, %s)" % [order.get("kind", ""), order.get("cursor", "")])
	_check(not path.is_empty() and _key(path.back()) == _key(walk_to) and _key(path.front()) == "2,4", "boot: the walk runs from the stack to the hex %s" % [path.map(func(step): return _key(step))])
	_check((order.get("forecast", PackedStringArray()) as PackedStringArray).is_empty(), "boot: a move shows no forecast badge: %s" % _forecast(order))
	await _capture("cursor_boot")
	await _hover_at(_cell_position(board, rock))
	order = _order(board)
	_check(String(order.get("kind", "")) == "blocked" and String(order.get("cursor", "")) == "blocked" and _forecast(order) == "Blocked by an obstacle", "blocked: a rock shows the barred circle and why: %s" % _forecast(order))
	_note_forecast("blocked_rock", order)
	await _capture("cursor_blocked")
	await _hover_at(_cell_position(board, _cell(10, 0)))
	order = _order(board)
	_check(String(order.get("kind", "")) == "blocked" and _forecast(order) == "Out of reach this turn", "blocked: a hex out of reach says so: %s" % _forecast(order))
	await _hover_at(_cell_position(board, FRIEND_CELL))
	order = _order(board)
	var friend := _stack(shell._session.battle, "report_friend")
	_check(String(order.get("kind", "")) == "info" and String(order.get("cursor", "")) == "info" and int(order.get("cursor_shape", -1)) == Control.CURSOR_ARROW, "info: a friendly stack keeps the pointer with the info badge (%s, %s)" % [order.get("kind", ""), order.get("cursor_shape", -1)])
	_check(_forecast(order).begins_with("%s ×%d" % [board._stack_full_name(friend), BattleRules._alive_count(friend)]) and _forecast(order).contains("Your stack · Melee"), "info: the forecast names the stack and how it fights: %s" % _forecast(order))
	_note_forecast("info", order)
	await _capture("cursor_info")
	var scenery := _scenery_point(shell, board)
	_check(scenery.x >= 0.0, "scenery: the window shows scenery beside the field")
	if scenery.x >= 0.0:
		await _hover_at(scenery)
		order = _order(board)
		_check(String(order.get("kind", "")) == "" and String(order.get("cursor", "")) == "" and int(order.get("cursor_shape", -1)) == Control.CURSOR_ARROW and _forecast(order) == "", "scenery: the scenery shows the plain pointer and nothing else (%s, %s, %s)" % [order.get("kind", ""), order.get("cursor_shape", -1), _forecast(order)])
	var figure: Dictionary = board.hero_figure_layout("player")
	var hit: Rect2 = figure.get("hit_rect", Rect2())
	_check(bool(figure.get("has_figure", false)) and hit.size.x > 0.0, "hero: the player's hero stands beside the field")
	if hit.size.x > 0.0:
		await _hover_at(board.global_position + hit.get_center())
		order = _order(board)
		_check(String(order.get("kind", "")) == "hero" and int(order.get("cursor_shape", -1)) == Control.CURSOR_POINTING_HAND, "hero: the hero shows the pointing hand (%s, %s)" % [order.get("kind", ""), order.get("cursor_shape", -1)])
		_check(_forecast(order).contains("spellbook"), "hero: the forecast says a click opens the spellbook: %s" % _forecast(order))
		await _capture("cursor_hero")


## A side another stack or a rock takes gives the nearest open side; the
## keyboard strikes from the side E turns to.
func _check_snapping_and_keys() -> void:
	var target_cell := _cell(6, 4)
	var west := _cell(5, 4)
	var south_east := _cell(6, 5)
	var shell = await _open_board(_cell(2, 4), target_cell, {}, [south_east], west)
	var board = shell._battle_board_view
	var battle: Dictionary = shell._session.battle
	var by_key := _cells_by_key(BattleRules.melee_approach_cells(battle, _stack(battle, "report_attacker"), _stack(battle, "report_target")))
	_check(by_key.size() == 4 and not by_key.has("5,4") and not by_key.has("6,5"), "snap: the friend's and the rock's sides are not offered %s" % [by_key.keys()])
	var cases := [
		[west, -10.0, "5,5"], [west, 10.0, "5,3"],
		[south_east, -10.0, "7,4"], [south_east, 10.0, "5,5"],
	]
	for snap in cases:
		await _hover_at(_side_point(board, target_cell, snap[0], deg_to_rad(float(snap[1]))))
		var order := _order(board)
		_check(String(order.get("kind", "")) == "strike" and _key(order.get("approach", {})) == String(snap[2]), "snap: pointing at the taken side %s, %d° off, strikes from the nearest open side %s (%s)" % [_key(snap[0]), int(snap[1]), snap[2], _key(order.get("approach", {}))])
	await _capture("cursor_snap")
	# The keyboard: the cursor on the enemy strikes from the nearest side, E
	# turns it, Enter strikes from there.
	board.grab_focus()
	await _key_event(KEY_UP, true)
	await _key_event(KEY_UP, false)
	for _step in range(BattleRules.BATTLE_HEX_COLUMNS + BattleRules.BATTLE_HEX_ROWS + 2):
		var cursor: Vector2i = board._controller_cursor_cell
		if cursor == _vec(target_cell):
			break
		if cursor.x != int(target_cell.q):
			await _press_key(KEY_RIGHT if int(target_cell.q) > cursor.x else KEY_LEFT)
		else:
			await _press_key(KEY_DOWN if int(target_cell.r) > cursor.y else KEY_UP)
	var order := _order(board)
	_check(board._keyboard_cursor_shown() and String(order.get("kind", "")) == "strike" and String(order.get("sector", "")) == "keys", "keys: the keyboard cursor on the enemy shows the strike (%s, %s)" % [order.get("kind", ""), order.get("sector", "")])
	var ring := _ring(order)
	var at := ring.find(_key(order.get("approach", {})))
	await _press_key(KEY_E)
	var turned := _key(_order(board).get("approach", {}))
	_check(at >= 0 and turned == ring[posmod(at + 1, ring.size())], "keys: E turns the keyboard's side clockwise (%s → %s)" % [ring[at] if at >= 0 else "", turned])
	await _capture("cursor_keys")
	await _press_key(KEY_ENTER)
	await _settle(shell)
	_check(_key(_stack(shell._session.battle, "report_attacker").get("hex", {})) == turned, "keys: Enter strikes from the turned side %s (%s)" % [turned, _key(_stack(shell._session.battle, "report_attacker").get("hex", {}))])
	await _close_shell(shell)


## The arrow toward a target in range, and a click that shoots.
func _check_far_shooter() -> void:
	var target_cell := _cell(6, 4)
	var shell = await _open_board(_cell(2, 4), target_cell, {"ranged": true, "shots_remaining": 4})
	var board = shell._battle_board_view
	await _hover_at(_cell_position(board, target_cell))
	var order := _order(board)
	var layout: Dictionary = board._current_hex_layout()
	var line: Vector2 = board._stack_rest_center(board._stack_by_id("report_target"), layout) - board._stack_rest_center(board._stack_by_id("report_attacker"), layout)
	_check(String(order.get("kind", "")) == "shoot" and String(order.get("cursor", "")) == "arrow" and int(order.get("cursor_shape", -1)) == Control.CURSOR_CROSS, "arrow: a target in range shows the arrow (%s, %s)" % [order.get("kind", ""), order.get("cursor", "")])
	_check(absf(angle_difference(float(order.get("angle", 0.0)), line.angle())) < 0.02, "arrow: the arrow points from the shooter to the target")
	_check(_forecast(order).contains("No retaliation · shots 4 → 3"), "arrow: the forecast says the shots left: %s" % _forecast(order))
	_note_forecast("arrow", order)
	await _capture("cursor_arrow")
	var health_before := int(_stack(shell._session.battle, "report_target").get("total_health", 0))
	await _click_at(_cell_position(board, target_cell))
	await _settle(shell)
	var shooter := _stack(shell._session.battle, "report_attacker")
	_check(int(shooter.get("shots_remaining", 0)) == 3 and _key(shooter.get("hex", {})) == "2,4", "arrow: a click shoots from where the stack stands (%d shots left)" % int(shooter.get("shots_remaining", 0)))
	_check(int(_stack(shell._session.battle, "report_target").get("total_health", 0)) < health_before, "arrow: the shot lands")
	await _close_shell(shell)


## The broken arrow beside the target; Ctrl turns it into the sword and back,
## and Ctrl-click strikes in melee.
func _check_point_blank() -> void:
	var target_cell := _cell(6, 4)
	var shell = await _open_board(_cell(5, 4), target_cell, {"ranged": true, "shots_remaining": 4})
	var board = shell._battle_board_view
	var target_point := _cell_position(board, target_cell)
	await _hover_at(target_point)
	var order := _order(board)
	_check(String(order.get("kind", "")) == "shoot" and String(order.get("cursor", "")) == "broken_arrow" and bool((order.get("preview", {}) as Dictionary).get("penalised", false)), "broken arrow: a shot beside the target shows the broken arrow (%s, %s)" % [order.get("kind", ""), order.get("cursor", "")])
	_check(_forecast(order).contains("Point-blank: -40% damage") and _forecast(order).contains("hold Ctrl to strike in melee"), "broken arrow: the forecast warns of the penalty and offers Ctrl: %s" % _forecast(order))
	_note_forecast("broken_arrow", order)
	await _capture("cursor_broken_arrow")
	await _key_event(KEY_CTRL, true)
	order = _order(board)
	_check(String(order.get("kind", "")) == "strike" and String(order.get("cursor", "")) == "sword" and bool(order.get("strike_forced", false)), "Ctrl: holding Ctrl turns the shot into a strike (%s, %s)" % [order.get("kind", ""), order.get("cursor", "")])
	_check(_forecast(order).contains("Strikes from where it stands"), "Ctrl: the strike is made from where the shooter stands: %s" % _forecast(order))
	_note_forecast("ctrl_strike", order)
	await _capture("cursor_ctrl_strike")
	await _key_event(KEY_CTRL, false)
	order = _order(board)
	_check(String(order.get("kind", "")) == "shoot" and String(order.get("cursor", "")) == "broken_arrow", "Ctrl: letting go of Ctrl turns it back into the shot (%s)" % order.get("kind", ""))
	var health_before := int(_stack(shell._session.battle, "report_target").get("total_health", 0))
	await _click_at(target_point, true)
	await _settle(shell)
	var shooter := _stack(shell._session.battle, "report_attacker")
	_check(int(shooter.get("shots_remaining", 0)) == 4 and _key(shooter.get("hex", {})) == "5,4", "Ctrl-click: the shooter strikes in melee and keeps its shots (%d)" % int(shooter.get("shots_remaining", 0)))
	_check(int(_stack(shell._session.battle, "report_target").get("total_health", 0)) < health_before, "Ctrl-click: the strike lands")
	await _close_shell(shell)


## The spark over a stack the chosen spell can be cast on, the barred circle
## elsewhere, and a cast that deals the forecast's damage.
func _check_spell_cursor() -> void:
	var target_cell := _cell(6, 4)
	var shell = await _open_board(_cell(2, 4), target_cell)
	var board = shell._battle_board_view
	var figure: Dictionary = board.hero_figure_layout("player")
	await _click_at(board.global_position + (figure.get("hit_rect", Rect2()) as Rect2).get_center())
	var row: Button = null
	for child in shell._spell_list.get_children():
		if child is Button and String(child.get_meta("spell_id", "")) == SPELL_ID:
			row = child
	_check(row != null and not row.disabled, "spark: the spellbook offers %s" % SPELL_ID)
	if row == null or row.disabled:
		shell._close_popovers()
		await _close_shell(shell)
		return
	await _click_at(row.get_global_rect().get_center())
	_check(shell._spell_targeting_id == SPELL_ID, "spark: choosing %s lights its targets" % SPELL_ID)
	await _hover_at(_cell_position(board, target_cell))
	var order := _order(board)
	var preview: Dictionary = order.get("preview", {})
	var spell_name := String(ContentService.get_spell(SPELL_ID).get("name", SPELL_ID))
	_check(String(order.get("kind", "")) == "spell" and String(order.get("cursor", "")) == "spark" and int(order.get("cursor_shape", -1)) == Control.CURSOR_CROSS, "spark: a stack the spell can be cast on shows the spark (%s, %s)" % [order.get("kind", ""), order.get("cursor", "")])
	_check(_forecast(order).begins_with("%s, %d mana" % [spell_name, int(preview.get("mana_cost", 0))]) and _forecast(order).contains("%d damage · kills %d" % [int(preview.get("damage", 0)), int(preview.get("casualties", 0))]), "spark: the forecast names the spell, its cost and its damage: %s" % _forecast(order))
	_note_forecast("spark", order)
	await _capture("cursor_spark")
	await _hover_at(_cell_position(board, FRIEND_CELL))
	order = _order(board)
	_check(String(order.get("kind", "")) == "blocked" and _forecast(order) == "Not a target for this spell", "spark: a stack the spell cannot touch shows the barred circle: %s" % _forecast(order))
	await _hover_at(_cell_position(board, _cell(4, 1)))
	order = _order(board)
	_check(String(order.get("kind", "")) == "blocked" and _forecast(order) == "Choose a highlighted stack", "spark: an empty hex asks for a lit stack: %s" % _forecast(order))
	var before := _stack(shell._session.battle, "report_target").duplicate(true)
	await _click_at(_cell_position(board, target_cell))
	await _settle(shell)
	var after := _stack(shell._session.battle, "report_target")
	var dealt := int(before.get("total_health", 0)) - int(after.get("total_health", 0))
	_check(dealt == int(preview.get("damage", 0)), "spark: the cast deals the forecast's %d damage (%d)" % [int(preview.get("damage", 0)), dealt])
	_check(String(shell._session.battle.get("active_stack_id", "")) == "report_attacker", "spark: the stack keeps its turn after the cast")
	await _close_shell(shell)
