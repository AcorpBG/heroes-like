extends Node

# Holding the right mouse button on a map tile opens its scout report; letting
# go closes it. The report is read-only and the Inspect button keeps its modal.
const REPORT_ID := "OVERWORLD_RIGHT_CLICK_HOLD_INSPECTION_REGRESSION"
const HERO_START := Vector2i(1, 2)
const GUARD_TILE := Vector2i(5, 2)
const VisualKit := preload("res://scripts/ui/FrontierVisualKit.gd")
const GUARD_PLACEMENT_ID := "right_click_inspection_guard"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	SessionState.reset_session()
	var session = SessionState.set_active_session(_fixture_session())
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await _frames(4)
	var live_session = shell.get("_session")
	if live_session != null:
		session = live_session
	var map_view: Control = shell.get_node_or_null("%Map")
	var dialog = shell.get("_scout_dialog")
	if map_view == null or dialog == null:
		return _fail("Overworld shell is missing the map view or scout dialog.")
	var before: Dictionary = session.to_dict().duplicate(true)
	var hero_before: Vector2i = OverworldRules.hero_position(session)

	await _right_button(map_view, GUARD_TILE, true)
	if not dialog.visible:
		return _fail("Right-button press on a scouted guard did not open the scout report.")
	if dialog.held_button != MOUSE_BUTTON_RIGHT or dialog.get_ok_button().visible:
		return _fail("Held report is not bound to the right button or still shows Return to map.", {"held_button": dialog.held_button})
	var report: Dictionary = dialog.snapshot
	if not bool(report.get("disclosed", false)) or Array(report.get("stacks", [])).is_empty():
		return _fail("Held report did not inspect the tile under the cursor.", report)
	if String(shell.call("_overworld_gameplay_movement_blocked_reason")) != "scout_inspection_open":
		return _fail("Held report does not block map orders while open.")
	await _frames(3)
	if not dialog.visible:
		return _fail("Held report closed while the right button was still down.")

	await _right_button(map_view, GUARD_TILE, false)
	if dialog.visible:
		return _fail("Releasing the right button did not close the scout report.")
	if dialog.held_button != MOUSE_BUTTON_NONE:
		return _fail("Closed held report kept its button binding.")
	if session.to_dict() != before or OverworldRules.hero_position(session) != hero_before:
		return _fail("Right-click inspection changed the session or moved the hero.")

	# A press over open ground still opens a report and closes on release.
	await _right_button(map_view, Vector2i(3, 0), true)
	if not dialog.visible or String(dialog.snapshot.get("title", "")) != "Scouted ground":
		return _fail("Right-button press on open ground did not open its report.", dialog.snapshot)
	await _right_button(map_view, Vector2i(3, 0), false)
	if dialog.visible:
		return _fail("Open-ground report stayed open after release.")

	# The Inspect button keeps the normal modal that waits for Return to map.
	shell.call("validation_select_tile", GUARD_TILE.x, GUARD_TILE.y)
	shell.call("_open_scout_inspection")
	await _frames(4)
	if not dialog.visible or not dialog.get_ok_button().visible or dialog.held_button != MOUSE_BUTTON_NONE:
		return _fail("Inspect button no longer opens the persistent scout report.")
	VisualKit.hide_exclusive_dialog(dialog)
	await _frames(2)
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": true})])
	get_tree().quit(0)

func _right_button(map_view: Control, tile: Vector2i, pressed: bool) -> void:
	var local_center: Vector2 = map_view.call("_tile_rect", map_view.call("_board_rect"), tile).get_center()
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.button_mask = MOUSE_BUTTON_MASK_RIGHT if pressed else 0
	event.pressed = pressed
	event.position = get_viewport().get_final_transform() * (map_view.get_global_transform() * local_center)
	event.global_position = event.position
	Input.parse_input_event(event)
	await _frames(3)

func _frames(count: int) -> void:
	for _i in range(count):
		await get_tree().process_frame

func _fixture_session():
	var rows := []
	for _y in range(5):
		var row := []
		for _x in range(8):
			row.append("grass")
		rows.append(row)
	var position := {"x": HERO_START.x, "y": HERO_START.y}
	var session = SessionStateStore.SessionData.new("right_click_inspection_fixture", "right_click_inspection_fixture", "hero_lyra", 1, {
		"map": rows,
		"map_size": {"width": 8, "height": 5},
		"hero_position": position.duplicate(true),
		"hero": {"id": "hero_lyra", "hero_id": "hero_lyra", "position": position.duplicate(true)},
		"active_hero_id": "hero_lyra",
		"player_heroes": [{"id": "hero_lyra", "hero_id": "hero_lyra", "position": position.duplicate(true), "is_active": true, "is_primary": true}],
		"movement": {"current": 6, "max": 6},
		"towns": [],
		"resource_nodes": [],
		"artifact_nodes": [],
		"encounters": [{
			"placement_id": GUARD_PLACEMENT_ID,
			"encounter_id": "encounter_ghoul_grove",
			"x": GUARD_TILE.x,
			"y": GUARD_TILE.y,
		}],
		"resolved_encounters": [],
		"terrain_layers": {},
		"fog": _all_visible_fog(8, 5),
	})
	session.overworld["command_briefing"] = {"signature": "right_click_inspection_fixture|campaign", "shown": true, "shown_day": 1}
	return session

func _all_visible_fog(width: int, height: int) -> Dictionary:
	var visible := []
	var explored := []
	for _y in range(height):
		var visible_row := []
		var explored_row := []
		for _x in range(width):
			visible_row.append(true)
			explored_row.append(true)
		visible.append(visible_row)
		explored.append(explored_row)
	return {
		"visible_tiles": visible,
		"explored_tiles": explored,
		"visible_count": width * height,
		"explored_count": width * height,
		"total_tiles": width * height,
	}

func _fail(message: String, payload: Variant = {}) -> void:
	push_error("%s failed: %s %s" % [REPORT_ID, message, JSON.stringify(payload)])
	get_tree().quit(1)
