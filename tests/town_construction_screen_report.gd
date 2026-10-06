extends Node

## Focused live report for the full-screen Town construction board. Runs every
## active faction town template through the real TownShell route: main-building
## entry, fixed slot coverage, exclusive dwelling choice, daily limit, legacy
## select/confirm compatibility, scenic preview, market hand-off and Esc.

const TownShellScene = preload("res://scenes/town/TownShell.tscn")
const Board = preload("res://scripts/core/TownConstructionBoard.gd")
const TownDevelopment = preload("res://scripts/core/TownDevelopmentRules.gd")
const CAPTURE_DIR := "res://.artifacts/town_construction_screen"
const EXPECTED_ROWS := ["town", "army", "growth", "training", "signature"]
const RICH := {"gold": 60000, "wood": 300, "ore": 300, "aetherglass": 60, "embergrain": 60, "peatwax": 60, "verdant_grafts": 60, "brass_scrip": 60, "memory_salt": 60}

var _errors := []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_DIR))
	var original_size := get_window().size
	var rows := []
	var templates := []
	for town_value in ContentService.load_json("res://content/towns.json").get("items", []):
		templates.append(String(town_value.get("id", "")))
	for index in range(templates.size()):
		var viewport_size := Vector2i(1920, 1080) if index % 2 == 0 else Vector2i(1280, 720)
		var row: Dictionary = await _run_town(String(templates[index]), viewport_size)
		rows.append(row)
		if not bool(row.get("ok", false)):
			_errors.append("%s failed: %s" % [templates[index], JSON.stringify(row.get("failures", []))])
	get_window().size = original_size
	var report := {
		"ok": _errors.is_empty(),
		"schema": "town_construction_screen_report_v1",
		"town_count": rows.size(),
		"rows": rows,
		"errors": _errors,
	}
	if _errors.is_empty():
		print("TOWN_CONSTRUCTION_SCREEN_REPORT %s" % JSON.stringify(report))
	else:
		push_error("TOWN_CONSTRUCTION_SCREEN_REPORT failed: %s" % JSON.stringify(report))
	get_tree().quit(0 if _errors.is_empty() else 1)

func _run_town(template_id: String, viewport_size: Vector2i) -> Dictionary:
	var failures := []
	get_window().size = viewport_size
	await _frames(2)
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var town := _first_player_town(session)
	if town.is_empty():
		return {"ok": false, "template_id": template_id, "failures": ["player_town_missing"]}
	town["town_id"] = template_id
	town["built_buildings"] = ["building_town_hall"]
	town["last_build_day"] = 0
	session.day = 2
	session.overworld["resources"] = RICH.duplicate(true)
	_move_active_hero_to_town(session, town)
	var visit: Dictionary = OverworldRules.set_active_town_visit(session, String(town.get("placement_id", "")))
	if not bool(visit.get("ok", false)):
		return {"ok": false, "template_id": template_id, "failures": ["town_visit"], "visit": visit}
	session = SessionState.set_active_session(session)
	var shell = TownShellScene.instantiate()
	add_child(shell)
	await _frames(3)
	var template := ContentService.get_town(template_id)
	var template_ids := Board.town_building_ids(template)

	# Entry through the painted main building is the authoritative build route.
	var route: Dictionary = shell.call("validation_activate_main_building_hotspot")
	await _frames(3)
	if not bool(route.get("same_authoritative_build_route", false)):
		failures.append("main_building_route")
	var screen = shell.get("_construction_screen")
	if screen == null:
		shell.queue_free()
		return {"ok": false, "template_id": template_id, "failures": failures + ["screen_missing"]}
	var snap: Dictionary = screen.validation_snapshot()
	_check(failures, bool(snap.get("open", false)), "screen_open")
	_check(failures, snap.get("row_order", []) == EXPECTED_ROWS, "row_order %s" % [snap.get("row_order", [])])
	_check(failures, int(snap.get("slot_count", 0)) == 23, "slot_count %d" % int(snap.get("slot_count", 0)))
	_check(failures, snap.get("unassigned_building_ids", ["x"]).is_empty(), "unassigned %s" % [snap.get("unassigned_building_ids", [])])
	var covered := []
	var tile_rects := []
	var screen_rect: Rect2 = snap.get("screen_rect", Rect2())
	var detail_rect: Rect2 = snap.get("detail_rect", Rect2())
	for row in snap.get("rows", []):
		for slot in row.get("slots", []):
			for building_id in slot.get("building_ids", []):
				if building_id in covered:
					failures.append("building %s in two slots" % building_id)
				covered.append(building_id)
			var rect: Rect2 = slot.get("tile_rect", Rect2())
			if not bool(slot.get("tile_visible", false)) or not bool(slot.get("tile_has_art", false)):
				failures.append("tile %s visible=%s art=%s" % [slot.id, slot.tile_visible, slot.tile_has_art])
			if not screen_rect.grow(1.0).encloses(rect) or rect.size.x < 60.0 or rect.size.y < 60.0:
				failures.append("tile %s rect %s outside %s" % [slot.id, rect, screen_rect])
			if rect.intersects(detail_rect):
				failures.append("tile %s overlaps detail" % slot.id)
			for other in tile_rects:
				if rect.grow(-1.0).intersects(other):
					failures.append("tile %s overlaps another tile" % slot.id)
			tile_rects.append(rect)
	_check(failures, covered.size() == template_ids.size(), "covered %d of %d" % [covered.size(), template_ids.size()])
	var board: Dictionary = screen.board()
	var tiles_by_id := {}
	for row in snap.get("rows", []):
		for tile_snap in row.get("slots", []):
			tiles_by_id[String(tile_snap.get("id", ""))] = tile_snap
	for slot in Board.ordered_slots(board):
		var tile_snap: Dictionary = tiles_by_id.get(String(slot.get("id", "")), {})
		var expected_cost := []
		for resource_id in Board.RESOURCE_ORDER:
			if slot.get("cost", {}).has(resource_id):
				expected_cost.append(resource_id)
		if String(slot.get("next_id", "")) != "":
			_check(failures, tile_snap.get("cost_ids", []) == expected_cost, "tile %s cost %s expected %s" % [slot.id, tile_snap.get("cost_ids", []), expected_cost])
		var expected_roles := []
		if String(slot.get("kind", "")) == "choice":
			for option in slot.get("options", []):
				expected_roles.append(_role_of(String(option.get("unit_id", ""))))
		elif String(slot.get("kind", "")) == "dwelling":
			var unit_building := String(slot.get("current_id", "")) if String(slot.get("current_id", "")) != "" else String(slot.get("art_building_id", ""))
			expected_roles.append(_role_of(String(ContentService.get_building(unit_building).get("unlock_unit_id", ""))))
		_check(failures, tile_snap.get("roles", []) == expected_roles, "tile %s roles %s expected %s" % [slot.id, tile_snap.get("roles", []), expected_roles])
		var expected_buttons := 0
		if String(slot.get("status", "")) == Board.STATUS_READY:
			expected_buttons = 2 if String(slot.get("kind", "")) == "choice" else 1
		_check(failures, int(tile_snap.get("quick_buttons", -1)) == expected_buttons, "tile %s one-click buttons %s" % [slot.id, tile_snap.get("quick_buttons", -1)])
	for tier in range(1, 8):
		var slot := Board.slot_by_id(board, "dwelling_%d" % tier)
		var expected_kind := "choice" if tier <= 5 else "dwelling"
		_check(failures, String(slot.get("kind", "")) == expected_kind, "dwelling_%d kind %s" % [tier, slot.get("kind", "")])
		if tier >= 6:
			_check(failures, String(slot.get("status", "")) == Board.STATUS_LOCKED, "dwelling_%d locked" % tier)
	_check(failures, String(Board.slot_by_id(board, "hall").get("status", "")) == Board.STATUS_READY, "hall ready")
	_check(failures, String(Board.slot_by_id(board, "tavern").get("status", "")) == Board.STATUS_READY, "tavern ready")
	await _capture(template_id, "initial", viewport_size)

	# Exclusive choice: picking branch 2 builds only that branch.
	var choice := Board.slot_by_id(board, "dwelling_1")
	var options: Array = choice.get("options", [])
	if options.size() != 2:
		failures.append("dwelling_1 options %d" % options.size())
	else:
		screen.select_slot("dwelling_1")
		await _frames(1)
		var unpicked: Dictionary = screen.validation_snapshot()
		_check(failures, bool(unpicked.get("primary_disabled", false)), "choice requires a picked option")
		screen.select_slot("dwelling_1", 1)
		await _frames(1)
		var picked: Dictionary = screen.validation_snapshot()
		_check(failures, String(picked.get("selected_building_id", "")) == String(options[1].building_id), "picked option id")
		_check(failures, not bool(picked.get("primary_disabled", true)), "picked option buildable")
		await _capture(template_id, "choice", viewport_size)
		screen.select_slot("hall")
		await _frames(1)
		_check(failures, screen.validation_quick_build("dwelling_1", 1), "choice tile has one-click build per branch")
		await _frames(3)
		if session.scenario_status != "in_progress":
			shell.queue_free()
			return {"ok": false, "template_id": template_id, "failures": failures + ["scenario ended: %s" % session.scenario_status]}
		town = TownRules.get_active_town(session)
		_check(failures, String(options[1].building_id) in town.get("built_buildings", []), "branch 2 built")
		_check(failures, not bool(screen.visible), "screen closes after building")
		_check(failures, int(town.get("last_build_day", 0)) == int(session.day), "last_build_day stamped")
		for action in TownRules.get_build_actions(session):
			if String(action.get("id", "")) == "build:%s" % String(options[0].building_id):
				failures.append("forgone branch still offered")

	# Daily limit: everything orderable waits until tomorrow.
	await _open_construction(shell, failures)
	board = screen.board()
	var waiting := 0
	for slot in Board.ordered_slots(board):
		if String(slot.get("status", "")) in [Board.STATUS_READY, Board.STATUS_SHORT, Board.STATUS_TRADE]:
			failures.append("slot %s orderable after today's build" % slot.id)
		if String(slot.get("status", "")) == Board.STATUS_TOMORROW:
			waiting += 1
	_check(failures, waiting > 0, "tomorrow slots shown")
	_check(failures, bool(board.get("built_today", false)), "board built_today")
	var chosen := Board.slot_by_id(board, "dwelling_1")
	_check(failures, String(chosen.get("kind", "")) == "dwelling" and not chosen.get("forgone_unit_names", []).is_empty(), "dwelling_1 shows chosen line")
	screen.select_slot("hall")
	await _frames(1)
	_check(failures, bool(screen.validation_snapshot().get("primary_disabled", false)), "build disabled after today's build")
	await _capture(template_id, "tomorrow", viewport_size)
	shell.call("validation_close_town_catalog")
	await _frames(1)

	# Legacy select/confirm routes keep working through the screen.
	session.day += 1
	var selected: Dictionary = shell.call("validation_select_build_plan", "build:building_dev_hall_2")
	_check(failures, bool(selected.get("ok", false)) and bool(selected.get("state_unchanged", false)), "legacy select")
	var confirmed: Dictionary = shell.call("validation_confirm_build_plan")
	_check(failures, bool(confirmed.get("ok", false)), "legacy confirm")
	town = TownRules.get_active_town(session)
	_check(failures, TownDevelopment.satisfies(town.get("built_buildings", []), "building_dev_hall_2"), "hall upgraded")

	# Scenic preview folds the board away and Esc returns, then Esc closes.
	session.day += 1
	await _open_construction(shell, failures)
	screen.select_slot("fort")
	await _frames(1)
	var fort := Board.slot_by_id(screen.board(), "fort")
	var view_button := screen.find_child("ConstructionViewInTown", true, false) as Button
	view_button.emit_signal("pressed")
	await _frames(2)
	var stage = shell.get("_town_stage_view")
	_check(failures, bool(screen.validation_snapshot().get("peek", false)), "peek on")
	_check(failures, String(stage.get("_construction_preview_id")) == String(fort.get("next_id", "")), "stage preview %s" % stage.get("_construction_preview_id"))
	await _capture(template_id, "peek", viewport_size)
	_cancel(shell)
	await _frames(2)
	_check(failures, bool(screen.visible) and not bool(screen.validation_snapshot().get("peek", true)), "esc leaves peek")
	_check(failures, bool(screen.validation_snapshot().get("focus_inside", false)), "focus returns inside screen")
	_cancel(shell)
	await _frames(2)
	_check(failures, not bool(screen.visible) and not bool(shell.call("_town_catalog_is_open")), "esc closes screen")

	# One click on a tile's Build strip constructs without visiting the panel.
	await _open_construction(shell, failures)
	screen.select_slot("hall")
	await _frames(1)
	_check(failures, screen.validation_quick_build("tavern"), "tavern one-click build button")
	await _frames(3)
	town = TownRules.get_active_town(session)
	_check(failures, "building_wayfarers_hall" in town.get("built_buildings", []) and not bool(screen.visible), "one-click tile build")

	# A double-click on a ready tile builds it as well.
	session.day += 1
	await _open_construction(shell, failures)
	_check(failures, screen.validation_double_click("fort"), "fort double-click")
	await _frames(4)
	town = TownRules.get_active_town(session)
	_check(failures, TownDevelopment.satisfies(town.get("built_buildings", []), "building_dev_fort_1"), "double-click tile build")

	# Market hand-off when trade can cover a shortfall.
	session.day += 1
	town = TownRules.get_active_town(session)
	var built: Array = town.get("built_buildings", []).duplicate()
	built.append("building_market_square")
	town["built_buildings"] = built
	session.overworld["resources"] = {"gold": 500, "wood": 120, "ore": 120, "aetherglass": 0, "embergrain": 0, "peatwax": 0, "verdant_grafts": 0, "brass_scrip": 0, "memory_salt": 0}
	await _open_construction(shell, failures)
	var trade_slot := ""
	for slot in Board.ordered_slots(screen.board()):
		if String(slot.get("status", "")) == Board.STATUS_TRADE:
			trade_slot = String(slot.get("id", ""))
			break
	_check(failures, trade_slot != "", "a market-coverable slot exists")
	if trade_slot != "":
		screen.select_slot(trade_slot)
		await _frames(1)
		screen.validation_press_primary()
		await _frames(2)
		_check(failures, String(shell.get("_town_catalog_mode")) == "trade" and not bool(screen.visible), "trade hand-off")
	shell.call("validation_close_town_catalog")
	shell.queue_free()
	await _frames(2)
	return {"ok": failures.is_empty(), "template_id": template_id, "viewport": viewport_size, "failures": failures}

func _open_construction(shell: Node, failures: Array) -> void:
	# A committed build plays a short blocking scenic presentation first.
	var stage = shell.get("_town_stage_view")
	if stage != null and stage.has_method("dismiss_town_action_presentation"):
		stage.call("dismiss_town_action_presentation")
	await _frames(2)
	shell.call("validation_open_town_catalog", "build")
	await _frames(2)
	var screen = shell.get("_construction_screen")
	_check(failures, screen != null and bool(screen.visible), "construction opened")

func _role_of(unit_id: String) -> String:
	var unit := ContentService.get_unit(unit_id)
	return "ranged" if bool(unit.get("ranged", false)) else "melee"

func _cancel(shell: Node) -> void:
	var event := InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = true
	shell.call("_input", event)

func _check(failures: Array, condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)

func _frames(count: int) -> void:
	for _index in range(count):
		await get_tree().process_frame

func _first_player_town(session) -> Dictionary:
	for town_value in session.overworld.get("towns", []):
		if town_value is Dictionary and String(town_value.get("owner", "")) == "player":
			return town_value
	return {}

func _move_active_hero_to_town(session, town: Dictionary) -> void:
	var position := {"x": int(town.get("x", 0)), "y": int(town.get("y", 0))}
	session.overworld["hero_position"] = position.duplicate(true)
	var hero = session.overworld.get("hero", {})
	if hero is Dictionary:
		hero["x"] = position.x
		hero["y"] = position.y
		hero["position"] = position.duplicate(true)
		session.overworld["hero"] = hero

func _capture(template_id: String, step: String, viewport_size: Vector2i) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png("%s/%s_%s_%dx%d.png" % [CAPTURE_DIR, template_id, step, viewport_size.x, viewport_size.y])
