extends Node

const REPORT_ID := "TERRAIN_BLOCKING_TOWN_CAPTURE_INTERACTION_REGRESSION"
const TOWN_PLACEMENT_ID := "route_capture_town"
const TOWN_TILE := Vector2i(4, 1)

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not _assert_rock_blocks_without_blocking_rough():
		return
	if not _assert_full_route_town_capture():
		return
	if not await _assert_cached_selected_route_town_capture():
		return
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": true})])
	get_tree().quit(0)

func _assert_rock_blocks_without_blocking_rough() -> bool:
	var session = _terrain_fixture_session()
	OverworldRules.normalize_overworld_state(session)
	if not OverworldRules.tile_is_blocked(session, 2, 1):
		return _fail("Rock terrain did not block movement.", _terrain_snapshot(session))
	for tile in [Vector2i(3, 1), Vector2i(4, 1)]:
		if OverworldRules.tile_is_blocked(session, tile.x, tile.y):
			return _fail("Passable canonical terrain was blocked.", {
				"tile": _tile_payload(tile),
				"terrain": String(session.overworld.get("map", [])[tile.y][tile.x]),
				"snapshot": _terrain_snapshot(session),
			})
	_set_active_hero_position(session, Vector2i(1, 1))
	session.overworld["movement"] = {"current": 4, "max": 4}
	var blocked_move: Dictionary = OverworldRules.try_move(session, 1, 0)
	if bool(blocked_move.get("ok", false)):
		return _fail("Movement into rock terrain succeeded.", blocked_move)
	var blocked_route: Dictionary = OverworldRules.try_move_along_route(session, [Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)], 4)
	if bool(blocked_route.get("ok", false)):
		return _fail("Route through rock terrain succeeded.", blocked_route)
	return true

func _assert_full_route_town_capture() -> bool:
	var session = _town_fixture_session("neutral")
	OverworldRules.normalize_overworld_state(session)
	var route := [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), TOWN_TILE]
	var result: Dictionary = OverworldRules.try_move_along_route(session, route, 6)
	var town := _town_by_placement(session, TOWN_PLACEMENT_ID)
	if not bool(result.get("ok", false)):
		return _fail("Full route to neutral town failed.", result)
	if String(town.get("owner", "")) != "player":
		return _fail("Full route did not capture the neutral town.", {"result": result, "town": town})
	if String(result.get("message", "")).find("Captured") < 0:
		return _fail("Full route capture result did not report capture.", result)
	return true

func _assert_cached_selected_route_town_capture() -> bool:
	var session = _town_fixture_session("neutral")
	var active_session = SessionState.set_active_session(session)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	var shell_session = shell.get("_session")
	if shell_session != null:
		active_session = shell_session
	_prepare_shell_state(shell, active_session, Vector2i(0, 1), 6)
	shell.call("validation_set_debug_overlay_enabled", true)
	var selection: Dictionary = shell.call("validation_select_tile", TOWN_TILE.x, TOWN_TILE.y)
	if not bool(selection.get("ok", false)):
		shell.queue_free()
		return _fail("Town route selection failed.", selection)
	var route_decision: Dictionary = selection.get("selected_route_decision", {}) if selection.get("selected_route_decision", {}) is Dictionary else {}
	if String(route_decision.get("action_kind", "")) != "move/capture":
		shell.queue_free()
		return _fail("Neutral town selected-route descriptor did not expose capture semantics.", route_decision)
	var primary_action: Dictionary = selection.get("primary_action", {}) if selection.get("primary_action", {}) is Dictionary else {}
	if String(primary_action.get("label", "")).find("Claim") < 0:
		shell.queue_free()
		return _fail("Neutral town primary route action did not expose claim wording.", primary_action)
	var clicked: Dictionary = shell.call("validation_click_tile", TOWN_TILE.x, TOWN_TILE.y)
	var captured := _town_by_placement(active_session, TOWN_PLACEMENT_ID)
	var command := _last_command(shell)
	shell.queue_free()
	if String(captured.get("owner", "")) != "player":
		return _fail("Cached selected-route confirmation did not capture the neutral town.", {"clicked": clicked, "town": captured, "command": command})
	var profile: Dictionary = command.get("profile", {}) if command.get("profile", {}) is Dictionary else {}
	var movement_details: Dictionary = profile.get("last_cmd_movement_rules", {}) if profile.get("last_cmd_movement_rules", {}) is Dictionary else {}
	if String(movement_details.get("cached_execution_mode", "")) != "destination_interaction_fast_path":
		return _fail("Town confirmation did not use the descriptor destination fast path.", movement_details)
	if String(movement_details.get("interaction_dispatch_mode", "")) != "destination_descriptor":
		return _fail("Town confirmation did not dispatch through the selected-route descriptor.", movement_details)
	var descriptor: Dictionary = movement_details.get("descriptor", {}) if movement_details.get("descriptor", {}) is Dictionary else {}
	if String(descriptor.get("kind", "")) != "town":
		return _fail("Town confirmation did not profile a town descriptor.", movement_details)
	return true

func _terrain_fixture_session():
	var rows := [
		["grass", "grass", "grass", "grass", "grass"],
		["grass", "grass", "rock", "rough", "dirt"],
		["grass", "grass", "grass", "grass", "grass"],
	]
	return _base_session("terrain_blocking_fixture", rows, Vector2i(1, 1), [])

func _town_fixture_session(owner: String):
	var rows := []
	for _y in range(3):
		var row := []
		for _x in range(7):
			row.append("grass")
		rows.append(row)
	var towns := [
		{
			"placement_id": TOWN_PLACEMENT_ID,
			"town_id": "town_riverwatch",
			"x": TOWN_TILE.x,
			"y": TOWN_TILE.y,
			"owner": owner,
			"garrison": [],
		}
	]
	return _base_session("town_capture_fixture", rows, Vector2i(0, 1), towns)

func _base_session(session_id: String, rows: Array, hero_tile: Vector2i, towns: Array):
	var first_row: Array = rows[0] if rows[0] is Array else []
	var width: int = first_row.size()
	var height: int = rows.size()
	var session = SessionStateStore.SessionData.new(session_id, session_id, "hero_lyra", 1, {
		"map": rows,
		"map_size": {"width": width, "height": height},
		"hero_position": {"x": hero_tile.x, "y": hero_tile.y},
		"hero": {"id": "hero_lyra", "hero_id": "hero_lyra", "position": {"x": hero_tile.x, "y": hero_tile.y}},
		"active_hero_id": "hero_lyra",
		"player_heroes": [{"id": "hero_lyra", "hero_id": "hero_lyra", "position": {"x": hero_tile.x, "y": hero_tile.y}, "is_active": true, "is_primary": true}],
		"movement": {"current": 6, "max": 6},
		"towns": towns,
		"resource_nodes": [],
		"artifact_nodes": [],
		"encounters": [],
		"resolved_encounters": [],
		"terrain_layers": {},
		"fog": _all_visible_fog(width, height),
	})
	session.game_state = "overworld"
	session.scenario_status = "in_progress"
	return session

func _prepare_shell_state(shell: Node, session, position: Vector2i, movement_points: int) -> void:
	_set_active_hero_position(session, position)
	_set_active_hero_movement(session, movement_points)
	session.overworld["fog"] = _all_visible_fog(
		int(session.overworld.get("map_size", {}).get("width", 1)),
		int(session.overworld.get("map_size", {}).get("height", 1))
	)
	OverworldRules.normalize_overworld_state(session)
	shell.call("_set_selected_tile", position)
	shell.call("_refresh")

func _set_active_hero_position(session, tile: Vector2i) -> void:
	var position := {"x": tile.x, "y": tile.y}
	session.overworld["hero_position"] = position.duplicate(true)
	var hero: Dictionary = session.overworld.get("hero", {}) if session.overworld.get("hero", {}) is Dictionary else {}
	hero["position"] = position.duplicate(true)
	session.overworld["hero"] = hero
	var heroes: Array = session.overworld.get("player_heroes", []) if session.overworld.get("player_heroes", []) is Array else []
	for index in range(heroes.size()):
		if heroes[index] is Dictionary and bool(heroes[index].get("is_active", false)):
			var entry: Dictionary = heroes[index]
			entry["position"] = position.duplicate(true)
			heroes[index] = entry
	session.overworld["player_heroes"] = heroes

func _set_active_hero_movement(session, movement_points: int) -> void:
	var movement := {"current": movement_points, "max": movement_points}
	session.overworld["movement"] = movement.duplicate(true)
	var hero: Dictionary = session.overworld.get("hero", {}) if session.overworld.get("hero", {}) is Dictionary else {}
	hero["movement"] = movement.duplicate(true)
	hero["base_movement"] = movement_points
	session.overworld["hero"] = hero
	var heroes: Array = session.overworld.get("player_heroes", []) if session.overworld.get("player_heroes", []) is Array else []
	for index in range(heroes.size()):
		if heroes[index] is Dictionary and bool(heroes[index].get("is_active", false)):
			var entry: Dictionary = heroes[index]
			entry["movement"] = movement.duplicate(true)
			entry["base_movement"] = movement_points
			heroes[index] = entry
	session.overworld["player_heroes"] = heroes

func _town_by_placement(session, placement_id: String) -> Dictionary:
	for town_value in session.overworld.get("towns", []):
		if town_value is Dictionary and String(town_value.get("placement_id", "")) == placement_id:
			return town_value
	return {}

func _last_command(shell: Node) -> Dictionary:
	var overlay: Dictionary = shell.call("validation_debug_overlay_snapshot")
	return overlay.get("last_command", {}) if overlay.get("last_command", {}) is Dictionary else {}

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

func _terrain_snapshot(session) -> Dictionary:
	return {
		"rock": OverworldRules.terrain_profile_at(session, 2, 1),
		"rough": OverworldRules.terrain_profile_at(session, 3, 1),
		"dirt": OverworldRules.terrain_profile_at(session, 4, 1),
	}

func _tile_payload(tile: Vector2i) -> Dictionary:
	return {"x": tile.x, "y": tile.y}

func _fail(message: String, payload: Variant = {}) -> bool:
	push_error("%s failed: %s %s" % [REPORT_ID, message, JSON.stringify(payload)])
	get_tree().quit(1)
	return false
