extends Node
## The painted battlefields, their props and the hex grid options
## (docs/battle-rework.md, slice 8: owner request 2026-10-09 for better ground
## and blocking objects) on a battle from a generated small map.
##
## Every battle terrain is fought on one of eleven painted battlefields, and an
## unknown terrain on the meadow. The painting covers the whole window, cropped
## to the window's shape and never stretched. Each battlefield has its own
## props: three one-hex and two two-hex ones of each kind, which stand with
## their ground on the hex centre, or on the seam of a two-hex obstacle, at the
## board's hex size. The Options' hex grid outlines every hex (Full), only the
## hexes the player's stack can move to (Range only) or none (Off, which also
## hides the movement range), and its buttons save the setting.
##
## A rendering run given "-- --capture-dir=<dir>" saves screenshots for review:
## each battlefield with the obstacles the rules make on it and with all ten of
## its props, the three grid modes and the Options.

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const BattleBoardViewScript = preload("res://scenes/battle/BattleBoardView.gd")
const REPORT_ID := "BATTLE_BATTLEFIELD_ART_REPORT"
const SEED := "battle-battlefield-art-20261010"
const PLAY_SIZE := Vector2i(1920, 1080)
const WARD_SPELL := "spell_stone_veil"
## Each battlefield and its ambience.
const FAMILIES := {
	"grass": "sunlit_pollen",
	"forest": "forest_fireflies",
	"swamp": "swamp_wisps",
	"mire": "mire_wisps",
	"rough": "roughland_dust",
	"road": "roadside_dust",
	"snow": "snow_spindrift",
	"coast": "coastal_spray",
	"sand": "desert_dust",
	"lava": "ember_drift",
	"underground": "glasscap_motes",
}
## Terrains and the battlefield each is fought on.
const TERRAINS := {
	"plains": "grass",
	"grass": "grass",
	"forest": "forest",
	"swamp": "swamp",
	"marsh": "swamp",
	"mire": "mire",
	"rough": "rough",
	"hills": "rough",
	"highland": "rough",
	"badlands": "rough",
	"road": "road",
	"snow": "snow",
	"coast": "coast",
	"sand": "sand",
	"lava": "lava",
	"underground": "underground",
	"": "grass",
	" Snow ": "snow",
	"validation_unknown_terrain": "grass",
}
## The content that gives battles their terrain: file and list.
const ENCOUNTER_SOURCES := [
	["res://content/encounters.json", "items"],
	["res://content/generated_neutral_companies.json", "encounters"],
]
const CANVAS := {1: Vector2(288.0, 352.0), 2: Vector2(512.0, 352.0)}
const PIXELS_PER_HEX := 216.0
const ANCHOR_Y := 256
## All ten props of a battlefield, apart as the rules keep obstacles: kind,
## variant (one-hex props show variant % 3, two-hex ones variant % 2) and cells.
const ALL_PROPS := [
	["rock", 0, [Vector2i(3, 0)]],
	["rock", 1, [Vector2i(8, 2)]],
	["rock", 2, [Vector2i(8, 8)]],
	["rock", 0, [Vector2i(2, 3), Vector2i(3, 3)]],
	["rock", 1, [Vector2i(3, 6), Vector2i(4, 6)]],
	["deadwood", 0, [Vector2i(5, 2)]],
	["deadwood", 1, [Vector2i(6, 4)]],
	["deadwood", 2, [Vector2i(8, 6)]],
	["deadwood", 0, [Vector2i(6, 0), Vector2i(7, 0)]],
	["deadwood", 1, [Vector2i(5, 7), Vector2i(6, 7)]],
]
## Window sizes and the part of the 1920x1080 painting each shows.
const COVERS := [
	[Vector2(1920.0, 1080.0), Rect2(0.0, 0.0, 1920.0, 1080.0)],
	[Vector2(1280.0, 720.0), Rect2(0.0, 0.0, 1920.0, 1080.0)],
	[Vector2(2560.0, 1080.0), Rect2(0.0, 135.0, 1920.0, 810.0)],
	[Vector2(1280.0, 1024.0), Rect2(285.0, 0.0, 1350.0, 1080.0)],
]

var _checks := 0
var _failures: Array[String] = []
var _details := {}
var _capture_dir := ""


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
	AppRouter.validation_set_battle_report_routing_suppressed(true)
	_check(SettingsService.battle_hex_grid_mode_id() == SettingsService.BATTLE_HEX_GRID_FULL, "settings: the hex grid starts as Full (%s)" % SettingsService.battle_hex_grid_mode_id())
	_check_terrain_map()
	_check_art()
	var session = _session()
	if session != null and _prepare(session):
		_check_all_props_layout(session.battle)
		await _check_screen(session)
	SettingsService.set_battle_hex_grid_mode_id(SettingsService.BATTLE_HEX_GRID_FULL)
	AppRouter.validation_set_battle_report_routing_suppressed(false)
	var report := {"ok": _failures.is_empty(), "checks": _checks, "failures": _failures, "details": _details}
	print("%s %s" % [REPORT_ID, JSON.stringify(report)])
	get_tree().quit(0 if _failures.is_empty() else 1)


# --- Terrains and art ----------------------------------------------------------

## Each terrain's battlefield, and every terrain the content fights on has one.
func _check_terrain_map() -> void:
	for terrain in TERRAINS:
		var family := BattleBoardViewScript.battlefield_family(terrain)
		_check(family == String(TERRAINS[terrain]), "terrain: '%s' is fought on the %s battlefield (%s)" % [terrain, TERRAINS[terrain], family])
		_check(BattleBoardViewScript.battlefield_art_path(terrain) == "%s/%s.png" % [BattleBoardViewScript.BATTLEFIELD_ART_ROOT, TERRAINS[terrain]], "terrain: '%s' draws %s" % [terrain, BattleBoardViewScript.battlefield_art_path(terrain)])
	var content_terrains := {}
	for source in ENCOUNTER_SOURCES:
		for encounter in ContentService.load_json(String(source[0])).get(String(source[1]), []):
			if encounter is Dictionary:
				content_terrains[String(encounter.get("terrain", "plains"))] = true
	for terrain in content_terrains:
		_check(BattleBoardViewScript.BATTLEFIELD_FAMILIES.has(terrain), "terrain: the content's terrain %s has its own battlefield" % terrain)
	_details["content_terrains"] = content_terrains.keys()


## Every battlefield is a 1920x1080 painting; every prop a canvas of its size
## whose anchor row runs through its ground tuft, centred.
func _check_art() -> void:
	for family in FAMILIES:
		var path := "%s/%s.png" % [BattleBoardViewScript.BATTLEFIELD_ART_ROOT, family]
		var texture := load(path) as Texture2D
		_check(texture != null and texture.get_size() == Vector2(1920.0, 1080.0), "art: the %s battlefield loads at 1920x1080: %s" % [family, path])
		for kind in BattleRules.OBSTACLE_KINDS:
			for size in [1, 2]:
				for index in range(int(BattleBoardViewScript.OBSTACLE_ART_VARIANTS[size])):
					_check_prop_art("%s/%s/%s_%d_%d.png" % [BattleBoardViewScript.OBSTACLE_ART_ROOT, family, kind, size, index], size)


func _check_prop_art(path: String, size: int) -> void:
	var canvas: Vector2 = CANVAS[size]
	var texture := load(path) as Texture2D
	_check(texture != null and texture.get_size() == canvas, "art: prop %s loads at %dx%d" % [path, int(canvas.x), int(canvas.y)])
	var image := Image.new()
	if image.load(ProjectSettings.globalize_path(path)) != OK:
		_check(false, "art: prop %s reads" % path)
		return
	var left := -1
	var right := -1
	for x in range(image.get_width()):
		if image.get_pixel(x, ANCHOR_Y).a > 24.0 / 255.0:
			if left < 0:
				left = x
			right = x
	var middle := (left + right) * 0.5
	_check(left >= 0 and absf(middle - canvas.x * 0.5) <= canvas.x * 0.06 and float(right - left + 1) >= PIXELS_PER_HEX * size * 0.75, "art: prop %s stands its ground tuft on the anchor (row %d spans %d..%d)" % [path, ANCHOR_Y, left, right])


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
		if not _living(battle, "enemy").is_empty() and not _living(battle, "player").is_empty() and not BattleRules.battle_obstacles(battle).is_empty():
			session.battle = battle
			session.game_state = "battle"
			_details["encounter"] = String(battle.get("encounter_id", ""))
			return session
	_check(false, "a guard battle with obstacles on the generated map")
	return null


func _living(battle: Dictionary, side: String) -> Array:
	return battle.get("stacks", []).filter(func(stack): return stack is Dictionary and String(stack.get("side", "")) == side and BattleRules._alive_count(stack) > 0)


## The player's stacks act first, so the screen waits for the player; the
## hero knows Stone Veil with full mana, to aim a spell under Range only.
func _prepare(session) -> bool:
	var battle: Dictionary = session.battle
	var order := []
	for side in ["player", "enemy"]:
		for stack in _living(battle, side):
			order.append(String(stack.get("battle_id", "")))
	battle["turn_order"] = order
	battle["turn_index"] = 0
	battle["active_stack_id"] = order[0]
	battle[BattleRules.WAITED_STACK_IDS_KEY] = []
	var commander: Dictionary = (battle.get("player_commander_state", {}) as Dictionary).duplicate(true)
	var spellbook: Dictionary = (commander.get("spellbook", {}) as Dictionary).duplicate(true) if commander.get("spellbook", {}) is Dictionary else {}
	var known: Array = (spellbook.get("known_spell_ids", []) as Array).duplicate()
	if not known.has(WARD_SPELL):
		known.append(WARD_SPELL)
	var mana_max := SpellRules.mana_max_from_hero(commander)
	spellbook["known_spell_ids"] = known
	spellbook["mana"] = {"current": mana_max, "max": mana_max}
	commander["spellbook"] = spellbook
	battle["player_commander_state"] = commander
	BattleRules._sync_occupied_hexes(battle)
	BattleRules._sync_distance_from_hexes(battle)
	_details["terrain"] = String(battle.get("terrain", ""))
	_details["obstacles"] = BattleRules.battle_obstacles(battle)
	return String(battle.get("active_stack_id", "")) != ""


func _all_props() -> Array:
	var obstacles := []
	for index in range(ALL_PROPS.size()):
		var spec: Array = ALL_PROPS[index]
		var cells := []
		for cell in spec[2]:
			cells.append({"q": cell.x, "r": cell.y})
		obstacles.append({"id": "p%d" % (index + 1), "kind": String(spec[0]), "size": cells.size(), "variant": int(spec[1]), "cells": cells})
	return obstacles


## The ten props stand as the rules could place them: off the stacks and the
## deployment edges, apart from each other, and the armies can still meet.
func _check_all_props_layout(battle: Dictionary) -> void:
	var blocked := {}
	for obstacle in _all_props():
		var cells: Array = obstacle.get("cells", [])
		_check(BattleRules._obstacle_cells_clear(cells, blocked), "props layout: %s keeps apart from the others" % obstacle.get("id", ""))
		for cell in cells:
			_check(int(cell.get("q", 0)) >= BattleRules.OBSTACLE_EDGE_CLEAR_COLUMNS and int(cell.get("q", 0)) < BattleRules.BATTLE_HEX_COLUMNS - BattleRules.OBSTACLE_EDGE_CLEAR_COLUMNS, "props layout: %s stays off the deployment edges" % obstacle.get("id", ""))
			blocked[BattleRules._hex_key(cell)] = BattleRules.OBSTACLE_BLOCKER_PREFIX
	_check(BattleRules._obstacle_field_stays_open(blocked), "props layout: the armies can still reach each other")
	for stack in battle.get("stacks", []):
		for cell in BattleRules.Footprint.cells(stack):
			_check(not blocked.has(BattleRules._hex_key({"q": int(cell.q), "r": int(cell.r)})), "props layout: stack %s stands clear of the props" % String(stack.get("battle_id", "")))


# --- The battle screen ---------------------------------------------------------

func _open_shell(session):
	SessionState.set_active_session(session)
	var frame := Control.new()
	frame.name = "BattleFrame"
	frame.size = Vector2(PLAY_SIZE) if _capture_dir == "" else get_viewport().get_visible_rect().size
	add_child(frame)
	var shell = load("res://scenes/battle/BattleShell.tscn").instantiate()
	frame.add_child(shell)
	await _frames(4)
	var opened: bool = shell._session != null and not shell._session.battle.is_empty()
	_check(opened, "screen: the battle screen opens")
	if opened:
		_check(String(shell._session.battle.get("active_stack_id", "")) == String(session.battle.get("turn_order", [""])[0]), "screen: the player's stack acts (%s)" % shell._session.battle.get("active_stack_id", ""))
	return shell


func _close_shell(shell) -> void:
	shell.get_parent().queue_free()
	await _frames(2)


func _frames(count: int) -> void:
	for _frame in range(count):
		await get_tree().process_frame


func _capture(label: String) -> void:
	if _capture_dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(_capture_dir.path_join("%s.png" % label))


func _hover_at(position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	motion.relative = Vector2(6.0, 0.0)
	get_viewport().push_input(motion, true)
	await _frames(2)


func _click_at(position: Vector2) -> void:
	await _hover_at(position)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = position
		event.global_position = position
		event.pressed = pressed
		get_viewport().push_input(event, true)
		await get_tree().process_frame


## A point on the painted scenery: off the hexes, the heroes, the ribbon and
## every part of the HUD.
func _scenery_point(shell, board) -> Vector2:
	var rects: Dictionary = shell.validation_hud_snapshot().get("rects", {})
	var grid: Rect2 = board._current_hex_layout().get("rect", Rect2())
	for x in [grid.end.x + (board.size.x - grid.end.x) * 0.5, grid.position.x * 0.5]:
		for y in range(int(grid.position.y), int(grid.end.y), 24):
			var point := Vector2(float(x), float(y))
			if board._cell_in_bounds(board._hex_cell_at_position(point)) or board._hero_side_at_position(point) != "" or board._ribbon_rect().has_point(point):
				continue
			if rects.values().any(func(rect): return (rect as Rect2).has_point(point)):
				continue
			return board.global_position + point
	return Vector2(-1.0, -1.0)


func _check_screen(session) -> void:
	var shell = await _open_shell(session)
	if shell._session == null or shell._session.battle.is_empty():
		await _close_shell(shell)
		return
	var board = shell._battle_board_view
	var scenery := _scenery_point(shell, board)
	_check(scenery.x >= 0.0, "screen: the window shows scenery beside the field")
	await _hover_at(scenery)
	var terrain := String(shell._session.battle.get("terrain", "plains"))
	_check_battlefield(shell, board, terrain, "own terrain")
	_check_props(board, shell._session.battle, "own terrain")
	await _check_grid(shell, board)
	await _check_options(shell, board)
	await _check_covers(shell, board)
	await _check_terrains(shell, board)
	await _close_shell(shell)


## The terrain's battlefield covers the board, with its ambience, and the
## battle entry loads it ahead.
func _check_battlefield(shell, board, terrain: String, label: String) -> void:
	var summary: Dictionary = board.validation_battlefield_summary()
	var family := BattleBoardViewScript.battlefield_family(terrain)
	var path := "%s/%s.png" % [BattleBoardViewScript.BATTLEFIELD_ART_ROOT, family]
	_check(String(summary.get("family", "")) == family and String(summary.get("path", "")) == path, "%s: %s is fought on the %s battlefield (%s)" % [label, terrain, family, summary.get("path", "")])
	_check(bool(summary.get("loaded", false)) and summary.get("texture_size", Vector2.ZERO) == Vector2(1920.0, 1080.0), "%s: the battlefield painting loads (%s)" % [label, summary.get("texture_size", Vector2.ZERO)])
	var board_rect: Rect2 = summary.get("board_rect", Rect2())
	_check(board_rect.position == Vector2.ZERO and board_rect.size.is_equal_approx(shell.size), "%s: the painting covers the window (%s in %s)" % [label, board_rect, shell.size])
	_check(String(summary.get("ambient_profile", "")) == String(FAMILIES.get(family, "")), "%s: the %s battlefield has its ambience (%s)" % [label, family, summary.get("ambient_profile", "")])
	_check(BattleBoardViewScript.art_texture_paths_for_battle(shell._session.battle).has(path), "%s: the battle entry loads the battlefield ahead" % label)


## Each obstacle draws its battlefield's prop: the canvas scaled to the hex
## size, its anchor on the hex centre or the seam of two hexes.
func _check_props(board, battle: Dictionary, label: String) -> void:
	var summary: Dictionary = board.validation_battlefield_summary()
	var layout: Dictionary = board._current_hex_layout()
	var scale := float(layout.get("hex_width", 0.0)) / PIXELS_PER_HEX
	var family := String(summary.get("family", ""))
	var obstacles := BattleRules.battle_obstacles(battle)
	var props: Array = summary.get("props", [])
	_check(not obstacles.is_empty() and props.size() == obstacles.size(), "%s: every obstacle draws a prop (%d of %d)" % [label, props.size(), obstacles.size()])
	var prewarm := BattleBoardViewScript.art_texture_paths_for_battle(battle)
	for index in range(mini(props.size(), obstacles.size())):
		var prop: Dictionary = props[index]
		var obstacle: Dictionary = obstacles[index]
		var cells: Array = obstacle.get("cells", [])
		var size := cells.size()
		var path := "%s/%s/%s_%d_%d.png" % [BattleBoardViewScript.OBSTACLE_ART_ROOT, family, String(obstacle.get("kind", "")), size, int(obstacle.get("variant", 0)) % (3 if size == 1 else 2)]
		_check(String(prop.get("path", "")) == path and bool(prop.get("loaded", false)) and prop.get("texture_size", Vector2.ZERO) == CANVAS.get(size, Vector2.ZERO), "%s: obstacle %s draws %s (%s)" % [label, obstacle.get("id", ""), path, prop.get("path", "")])
		var anchor := Vector2.ZERO
		for cell in cells:
			anchor += board._hex_center(Vector2i(int(cell.get("q", 0)), int(cell.get("r", 0))), layout)
		anchor /= float(maxi(1, size))
		var rect: Rect2 = prop.get("rect", Rect2())
		var drawn_anchor := rect.position + Vector2(rect.size.x * 0.5, ANCHOR_Y * scale)
		_check(rect.size.is_equal_approx(CANVAS.get(size, Vector2.ZERO) * scale) and drawn_anchor.distance_to(anchor) < 0.01, "%s: obstacle %s stands its prop on %s (%s, %s)" % [label, obstacle.get("id", ""), "its hex centre" if size == 1 else "the seam of its hexes", drawn_anchor, anchor])
		_check(prewarm.has(path), "%s: the battle entry loads %s ahead" % [label, path])


func _set_grid(board, mode: String) -> void:
	SettingsService.set_battle_hex_grid_mode_id(mode)
	board.queue_redraw()
	await _frames(2)


## Full outlines all 99 hexes; Range only the hexes the acting stack can move
## to, and none while a spell is aimed; Off none, and no movement range.
func _check_grid(shell, board) -> void:
	var legal: int = board._movement_range_region().get("cells", []).size()
	_check(legal > 0 and legal < 99, "grid: the acting stack can move to some hexes (%d)" % legal)
	await _set_grid(board, SettingsService.BATTLE_HEX_GRID_FULL)
	var summary: Dictionary = board.validation_battlefield_summary()
	_check(String(summary.get("hex_grid_mode", "")) == "full" and int(summary.get("hex_grid_cells", -1)) == 99 and bool(summary.get("movement_range_shown", false)), "grid: Full outlines every hex and shows the movement range (%s)" % summary.get("hex_grid_cells", -1))
	await _capture("grid_full")
	await _set_grid(board, SettingsService.BATTLE_HEX_GRID_RANGE)
	summary = board.validation_battlefield_summary()
	_check(int(summary.get("hex_grid_cells", -1)) == legal and bool(summary.get("movement_range_shown", false)), "grid: Range only outlines the %d hexes the stack can move to (%s)" % [legal, summary.get("hex_grid_cells", -1)])
	await _capture("grid_range")
	var aimed: Dictionary = shell._begin_spell_targeting(WARD_SPELL)
	await _frames(2)
	_check(bool(aimed.get("ok", false)) and int(board.validation_battlefield_summary().get("hex_grid_cells", -1)) == 0, "grid: Range only outlines nothing while a spell is aimed: %s" % aimed)
	shell._cancel_spell_targeting(false)
	await _frames(2)
	_check(int(board.validation_battlefield_summary().get("hex_grid_cells", -1)) == legal, "grid: the range comes back when the spell is put away")
	await _set_grid(board, SettingsService.BATTLE_HEX_GRID_OFF)
	summary = board.validation_battlefield_summary()
	_check(int(summary.get("hex_grid_cells", -1)) == 0 and not bool(summary.get("movement_range_shown", true)) and not bool(board.validation_hex_layout_summary().get("movement_range_all_legal_cells_drawn", true)), "grid: Off outlines nothing and hides the movement range")
	await _capture("grid_off")
	await _set_grid(board, SettingsService.BATTLE_HEX_GRID_FULL)


## The Options' hex grid buttons fit the Options, switch the grid and save it
## with the settings.
func _check_options(shell, board) -> void:
	shell._open_popover(shell._options_popover)
	await _frames(3)
	var popover_rect: Rect2 = shell._options_popover.get_global_rect()
	for button in [shell._grid_full_button, shell._grid_range_button, shell._grid_off_button]:
		_check(button.is_visible_in_tree() and popover_rect.encloses(button.get_global_rect()), "options: %s shows inside the Options (%s in %s)" % [button.text, button.get_global_rect(), popover_rect])
	_check(shell._grid_full_button.disabled and not shell._grid_range_button.disabled and not shell._grid_off_button.disabled, "options: Full reads as chosen")
	await _capture("options_grid")
	for step in [[shell._grid_range_button, SettingsService.BATTLE_HEX_GRID_RANGE], [shell._grid_off_button, SettingsService.BATTLE_HEX_GRID_OFF], [shell._grid_full_button, SettingsService.BATTLE_HEX_GRID_FULL]]:
		var button: Button = step[0]
		var mode := String(step[1])
		await _click_at(button.get_global_rect().get_center())
		await _frames(2)
		_check(SettingsService.battle_hex_grid_mode_id() == mode and String(board.validation_battlefield_summary().get("hex_grid_mode", "")) == mode, "options: %s switches the hex grid to %s (%s)" % [button.text, mode, SettingsService.battle_hex_grid_mode_id()])
		var saved := ConfigFile.new()
		_check(saved.load(SettingsService.SETTINGS_FILE) == OK and String(saved.get_value("gameplay", "battle_hex_grid", "")) == mode, "options: the settings file keeps the hex grid %s" % mode)
		_check(button.disabled and shell._options_popover.visible, "options: %s reads as chosen and the Options stay open" % button.text)
		if mode == SettingsService.BATTLE_HEX_GRID_RANGE:
			await _capture("options_grid_range")
	shell._close_popovers(false)
	await _frames(2)


## The painting covers windows of any shape, cropped and never stretched, and
## the props keep to the hexes.
func _check_covers(shell, board) -> void:
	var frame: Control = shell.get_parent()
	var original := frame.size
	for cover in COVERS:
		var window: Vector2 = cover[0]
		var expected: Rect2 = cover[1]
		frame.size = window
		await _frames(3)
		var summary: Dictionary = board.validation_battlefield_summary()
		var region: Rect2 = summary.get("cover_region", Rect2())
		var label := "cover %dx%d" % [int(window.x), int(window.y)]
		_check((summary.get("board_rect", Rect2()) as Rect2).size.is_equal_approx(window) and region.position.distance_to(expected.position) < 0.5 and region.size.distance_to(expected.size) < 0.5, "%s: the window shows %s of the painting (%s)" % [label, expected, region])
		_check_props(board, shell._session.battle, label)
	frame.size = original
	await _frames(3)


## Each battlefield with the obstacles the rules make on it, then with all ten
## of its props.
func _check_terrains(shell, board) -> void:
	var original_terrain := String(shell._session.battle.get("terrain", "plains"))
	var original_obstacles := BattleRules.battle_obstacles(shell._session.battle)
	for family in FAMILIES:
		shell._session.battle["terrain"] = family
		BattleRules._generate_battle_obstacles(shell._session.battle)
		shell._refresh()
		await _frames(2)
		_check_battlefield(shell, board, family, "terrain " + family)
		_check_props(board, shell._session.battle, "terrain " + family)
		await _capture("terrain_%s" % family)
		shell._session.battle[BattleRules.OBSTACLES_KEY] = _all_props()
		shell._refresh()
		await _frames(2)
		_check_props(board, shell._session.battle, "props " + family)
		await _capture("props_%s" % family)
	shell._session.battle["terrain"] = original_terrain
	shell._session.battle[BattleRules.OBSTACLES_KEY] = original_obstacles
	shell._refresh()
	await _frames(2)
