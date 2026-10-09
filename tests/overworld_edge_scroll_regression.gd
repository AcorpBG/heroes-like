extends Node

# Resting the pointer at a window edge pans the Overworld camera that way, and
# stops when the pointer leaves the edge or a modal owns the screen.
const REPORT_ID := "OVERWORLD_EDGE_SCROLL_REGRESSION"
const MAP_SIZE := Vector2i(40, 40)
const HERO_START := Vector2i(20, 20)
const VisualKit := preload("res://scripts/ui/FrontierVisualKit.gd")

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		return _fail("Edge scrolling follows window focus; run this scene with a window.")
	get_window().grab_focus()
	SessionState.reset_session()
	var session = SessionState.set_active_session(_fixture_session())
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await _frames(6)
	var map_view = shell.get_node_or_null("%Map")
	if map_view == null or not map_view.call("_can_pan_camera"):
		return _fail("Fixture map does not need camera panning.")
	if not get_window().has_focus():
		return _fail("Test window did not get focus; edge scrolling cannot be checked.")
	var bounds: Rect2 = get_viewport().get_visible_rect()
	var middle := bounds.get_center()
	var before: Dictionary = session.to_dict().duplicate(true)

	await _point(middle)
	var start: Vector2 = map_view.get("_camera_center_tile")
	await _point(Vector2(bounds.end.x - 2.0, middle.y))
	await get_tree().create_timer(0.3).timeout
	var after_right: Vector2 = map_view.get("_camera_center_tile")
	if not (after_right.x > start.x + 0.5) or not is_equal_approx(after_right.y, start.y):
		return _fail("Pointer at the right edge did not pan the camera right.", {"start": str(start), "after": str(after_right)})

	await _point(middle)
	await _frames(3)
	var rested: Vector2 = map_view.get("_camera_center_tile")
	await get_tree().create_timer(0.2).timeout
	if map_view.get("_camera_center_tile") != rested or bool(map_view.get("_edge_scroll_active")):
		return _fail("Camera kept panning after the pointer left the edge.")

	await _point(Vector2(bounds.position.x + 1.0, bounds.position.y + 1.0))
	await get_tree().create_timer(0.3).timeout
	var after_corner: Vector2 = map_view.get("_camera_center_tile")
	if not (after_corner.x < rested.x - 0.5 and after_corner.y < rested.y - 0.5):
		return _fail("Pointer at the top-left corner did not pan diagonally.", {"rested": str(rested), "after": str(after_corner)})
	await _point(middle)
	await _frames(3)

	# A modal owns the screen: the pointer at an edge must not move the map.
	shell.call("_open_scout_inspection")
	await _frames(3)
	var blocked_start: Vector2 = map_view.get("_camera_center_tile")
	await _point(Vector2(bounds.end.x - 2.0, middle.y))
	await get_tree().create_timer(0.2).timeout
	if map_view.get("_camera_center_tile") != blocked_start:
		return _fail("Edge scrolling moved the map behind an open scout report.")
	VisualKit.hide_exclusive_dialog(shell.get("_scout_dialog"))
	await _point(middle)
	await _frames(3)

	# The shell's order gate also stops it when no window takes the pointer.
	var status: String = session.scenario_status
	session.scenario_status = "victory"
	var gated_start: Vector2 = map_view.get("_camera_center_tile")
	await _point(Vector2(bounds.end.x - 2.0, middle.y))
	await get_tree().create_timer(0.2).timeout
	session.scenario_status = status
	if map_view.get("_camera_center_tile") != gated_start:
		return _fail("Edge scrolling ignored the shell's order-input gate.")
	await _point(middle)
	await _frames(3)
	if session.to_dict() != before:
		return _fail("Edge scrolling changed the session.")
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": true, "right": str(after_right - start), "corner": str(after_corner - rested)})])
	get_tree().quit(0)

func _point(position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = get_viewport().get_final_transform() * position
	event.global_position = event.position
	Input.parse_input_event(event)
	await _frames(2)

func _frames(count: int) -> void:
	for _i in range(count):
		await get_tree().process_frame

func _fixture_session():
	var rows := []
	for _y in range(MAP_SIZE.y):
		var row := []
		for _x in range(MAP_SIZE.x):
			row.append("grass")
		rows.append(row)
	var position := {"x": HERO_START.x, "y": HERO_START.y}
	var session = SessionStateStore.SessionData.new("edge_scroll_fixture", "edge_scroll_fixture", "hero_lyra", 1, {
		"map": rows,
		"map_size": {"width": MAP_SIZE.x, "height": MAP_SIZE.y},
		"hero_position": position.duplicate(true),
		"hero": {"id": "hero_lyra", "hero_id": "hero_lyra", "position": position.duplicate(true)},
		"active_hero_id": "hero_lyra",
		"player_heroes": [{"id": "hero_lyra", "hero_id": "hero_lyra", "position": position.duplicate(true), "is_active": true, "is_primary": true}],
		"movement": {"current": 6, "max": 6},
		"towns": [],
		"resource_nodes": [],
		"artifact_nodes": [],
		"encounters": [],
		"resolved_encounters": [],
		"terrain_layers": {},
		"fog": _all_visible_fog(MAP_SIZE.x, MAP_SIZE.y),
	})
	session.overworld["command_briefing"] = {"signature": "edge_scroll_fixture|campaign", "shown": true, "shown_day": 1}
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
