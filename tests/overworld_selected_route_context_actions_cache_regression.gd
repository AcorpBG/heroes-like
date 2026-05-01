extends Node

const REPORT_ID := "OVERWORLD_SELECTED_ROUTE_CONTEXT_ACTIONS_CACHE_REGRESSION"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var session = _session_with_map(12, 4)
	var opened := await _open_shell(session)
	var shell: Node = opened.get("shell", null)
	session = opened.get("session", session)
	_prepare_shell_state(shell, session, Vector2i(0, 1), 10)

	var first_target := Vector2i(8, 1)
	var second_target := Vector2i(9, 1)
	var selection: Dictionary = shell.call("validation_select_tile", first_target.x, first_target.y)
	if not bool(selection.get("ok", false)):
		_fail("Initial selected-route setup failed.", selection)
		return
	if String(selection.get("primary_action_id", "")) != "advance_route":
		_fail("Initial selected route did not expose the expected movement action.", selection)
		return

	shell.call("validation_reset_profile", true)
	shell.call("_refresh")
	var reused_profile: Dictionary = shell.call("validation_profile_snapshot")
	if int(reused_profile.get("selected_route_destination_action_cache_hits", 0)) <= 0:
		_fail("Unchanged selected-route refresh did not reuse destination-only route actions.", reused_profile)
		return
	if int(reused_profile.get("selected_route_decision_surface_cache_hits", 0)) <= 0:
		_fail("Unchanged selected-route refresh did not reuse the route decision surface.", reused_profile)
		return

	shell.call("validation_reset_profile", true)
	var changed_selection: Dictionary = shell.call("validation_select_tile", second_target.x, second_target.y)
	var selected_tile_profile: Dictionary = shell.call("validation_profile_snapshot")
	if not bool(changed_selection.get("ok", false)):
		_fail("Selected tile mutation failed.", changed_selection)
		return
	if int(selected_tile_profile.get("selected_route_destination_action_cache_misses", 0)) <= 0:
		_fail("Selected tile change did not rebuild destination-only route actions.", selected_tile_profile)
		return
	if int(selected_tile_profile.get("selected_route_decision_surface_cache_misses", 0)) <= 0:
		_fail("Selected tile change did not recompute route decision surface.", selected_tile_profile)
		return

	shell.call("validation_reset_profile", true)
	_set_active_hero_position(session, Vector2i(1, 1))
	OverworldRules.refresh_fog_of_war(session)
	shell.call("_refresh")
	var hero_position_profile: Dictionary = shell.call("validation_profile_snapshot")
	if int(hero_position_profile.get("selected_route_destination_action_cache_misses", 0)) <= 0:
		_fail("Hero position change did not rebuild destination-only route actions.", hero_position_profile)
		return
	if int(hero_position_profile.get("selected_route_decision_surface_cache_misses", 0)) <= 0:
		_fail("Hero position change did not recompute selected-route decision surface.", hero_position_profile)
		return

	shell.call("validation_reset_profile", true)
	_set_active_hero_movement(session, 6)
	shell.call("_refresh")
	var movement_profile: Dictionary = shell.call("validation_profile_snapshot")
	if int(movement_profile.get("selected_route_destination_action_cache_misses", 0)) <= 0:
		_fail("Movement budget change did not rebuild destination-only route actions.", movement_profile)
		return
	if int(movement_profile.get("selected_route_decision_surface_cache_misses", 0)) <= 0:
		_fail("Movement budget change did not recompute selected-route decision surface.", movement_profile)
		return

	shell.call("validation_reset_profile", true)
	_add_route_blocking_encounter(session, Vector2i(5, 1))
	shell.call("_refresh")
	var topology_profile: Dictionary = shell.call("validation_profile_snapshot")
	if int(topology_profile.get("selected_route_destination_action_cache_misses", 0)) <= 0:
		_fail("Route interaction topology change did not rebuild destination-only route actions.", topology_profile)
		return
	if int(topology_profile.get("selected_route_decision_surface_cache_misses", 0)) <= 0:
		_fail("Route interaction topology change did not recompute selected-route decision surface.", topology_profile)
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"reuse_destination_hits": int(reused_profile.get("selected_route_destination_action_cache_hits", 0)),
		"reuse_route_decision_hits": int(reused_profile.get("selected_route_decision_surface_cache_hits", 0)),
		"selected_tile_destination_misses": int(selected_tile_profile.get("selected_route_destination_action_cache_misses", 0)),
		"hero_position_destination_misses": int(hero_position_profile.get("selected_route_destination_action_cache_misses", 0)),
		"movement_destination_misses": int(movement_profile.get("selected_route_destination_action_cache_misses", 0)),
		"topology_destination_misses": int(topology_profile.get("selected_route_destination_action_cache_misses", 0)),
	})])
	shell.queue_free()
	get_tree().quit(0)

func _open_shell(session) -> Dictionary:
	var active_session = SessionState.set_active_session(session)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	var shell_session = shell.get("_session")
	if shell_session != null:
		active_session = shell_session
	return {"shell": shell, "session": active_session}

func _prepare_shell_state(shell: Node, session, position: Vector2i, movement_points: int) -> void:
	_set_active_hero_position(session, position)
	_set_active_hero_movement(session, movement_points)
	session.overworld["fog"] = {}
	OverworldRules.refresh_fog_of_war(session)
	shell.call("_set_selected_tile", position)
	shell.call("_refresh")

func _session_with_map(width: int, height: int):
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var rows := []
	for _y in range(height):
		var row := []
		for _x in range(width):
			row.append("grass")
		rows.append(row)
	session.overworld["map"] = rows
	session.overworld["map_size"] = {"width": width, "height": height, "x": width, "y": height}
	session.overworld["terrain_layers"] = {}
	session.overworld["towns"] = [
		{
			"placement_id": "riverwatch_hold",
			"town_id": "town_riverwatch",
			"x": 0,
			"y": 0,
			"owner": "player",
		}
	]
	session.overworld["resource_nodes"] = []
	session.overworld["artifact_nodes"] = []
	session.overworld["encounters"] = []
	session.overworld["resolved_encounters"] = []
	OverworldRules.refresh_fog_of_war(session)
	return session

func _set_active_hero_position(session, tile: Vector2i) -> void:
	var position := {"x": tile.x, "y": tile.y}
	session.overworld["hero_position"] = position.duplicate(true)
	var hero: Dictionary = session.overworld.get("hero", {}) if session.overworld.get("hero", {}) is Dictionary else {}
	hero["position"] = position.duplicate(true)
	session.overworld["hero"] = hero
	var active_hero_id := String(session.overworld.get("active_hero_id", hero.get("id", "")))
	var heroes: Array = session.overworld.get("player_heroes", []) if session.overworld.get("player_heroes", []) is Array else []
	for index in range(heroes.size()):
		if not (heroes[index] is Dictionary):
			continue
		var entry: Dictionary = heroes[index]
		if String(entry.get("id", "")) == active_hero_id:
			entry["position"] = position.duplicate(true)
			heroes[index] = entry
			break
	session.overworld["player_heroes"] = heroes

func _set_active_hero_movement(session, movement_points: int) -> void:
	var movement := {"current": movement_points, "max": movement_points}
	session.overworld["movement"] = movement.duplicate(true)
	var hero: Dictionary = session.overworld.get("hero", {}) if session.overworld.get("hero", {}) is Dictionary else {}
	hero["base_movement"] = movement_points
	hero["movement"] = movement.duplicate(true)
	session.overworld["hero"] = hero
	var active_hero_id := String(session.overworld.get("active_hero_id", hero.get("id", "")))
	var heroes: Array = session.overworld.get("player_heroes", []) if session.overworld.get("player_heroes", []) is Array else []
	for index in range(heroes.size()):
		if not (heroes[index] is Dictionary):
			continue
		var entry: Dictionary = heroes[index]
		if String(entry.get("id", "")) == active_hero_id:
			entry["base_movement"] = movement_points
			entry["movement"] = movement.duplicate(true)
			heroes[index] = entry
			break
	session.overworld["player_heroes"] = heroes

func _add_route_blocking_encounter(session, tile: Vector2i) -> void:
	var encounters: Array = session.overworld.get("encounters", []) if session.overworld.get("encounters", []) is Array else []
	encounters.append({
		"placement_id": "validation_route_blocker",
		"encounter_id": "validation_route_blocker",
		"id": "validation_route_blocker",
		"x": tile.x,
		"y": tile.y,
	})
	session.overworld["encounters"] = encounters

func _fail(message: String, context: Variant = {}) -> void:
	push_error("%s: %s %s" % [REPORT_ID, message, JSON.stringify(context)])
	get_tree().quit(1)
