extends Node

const REPORT_ID := "OVERWORLD_FULL_ROUTE_MOVEMENT_REGRESSION"

var _evidence: Dictionary = {}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not await _assert_partial_full_route_execution():
		return
	if not await _assert_selected_route_cache_reuse():
		return
	if not await _assert_reachable_interaction_resolves_only_at_destination():
		return
	if not await _assert_route_does_not_pass_through_interaction():
		return
	print("%s %s" % [REPORT_ID, JSON.stringify({"evidence": _evidence, "ok": true})])
	get_tree().quit(0)

func _assert_partial_full_route_execution() -> bool:
	var session = _session_with_map(11, 3)
	session.overworld["fog"] = {}
	var opened := await _open_shell(session)
	var shell: Node = opened.get("shell", null)
	session = opened.get("session", session)
	_prepare_shell_state(shell, session, Vector2i(0, 1), 4)
	shell.call("validation_set_debug_overlay_enabled", true)
	var target := Vector2i(9, 1)
	var before_target_explored := OverworldRules.is_tile_explored(session, target.x, target.y)
	var before_final_explored := OverworldRules.is_tile_explored(session, 4, 1)
	var selection: Dictionary = shell.call("validation_select_tile", target.x, target.y)
	var route_decision: Dictionary = selection.get("selected_route_decision", {})
	var route_preview: Dictionary = selection.get("selected_route_preview", {})
	var map_preview: Dictionary = selection.get("map_viewport", {}).get("route_preview", {})
	if String(route_decision.get("status", "")) != "not_today":
		return _fail("Partial route should be clear but beyond current movement.", selection)
	if int(route_preview.get("total_steps", 0)) != 9 or int(route_preview.get("reachable_steps", 0)) != 4 or int(route_preview.get("unreachable_steps", 0)) != 5:
		return _fail("Route preview did not partition reachable and out-of-movement segments.", selection)
	if int(map_preview.get("reachable_steps", 0)) != 4 or int(map_preview.get("unreachable_steps", 0)) != 5:
		return _fail("Map route preview did not expose the same out-of-movement partition.", selection)
	var result: Dictionary = shell.call("validation_perform_primary_action")
	await get_tree().process_frame
	var overlay: Dictionary = shell.call("validation_debug_overlay_snapshot")
	var last_command: Dictionary = overlay.get("last_command", {}) if overlay.get("last_command", {}) is Dictionary else {}
	var phase_buckets: Dictionary = last_command.get("phase_buckets_ms", {}) if last_command.get("phase_buckets_ms", {}) is Dictionary else {}
	var finish := OverworldRules.hero_position(session)
	var movement_after := int(session.overworld.get("movement", {}).get("current", -1))
	var route_execution: Dictionary = result.get("route_execution", {}) if result.get("route_execution", {}) is Dictionary else {}
	var route_steps: Array = route_execution.get("route_steps", []) if route_execution.get("route_steps", []) is Array else []
	if not bool(result.get("ok", false)) or finish != Vector2i(4, 1):
		return _fail("Full-route confirmation did not move to the farthest reachable tile.", result)
	if String(last_command.get("command_type", "")) != "full_route_execute" or not phase_buckets.has("route_execution_lookup"):
		return _fail("F3 overlay did not record full-route execution buckets.", overlay)
	_evidence["partial_full_route"] = {
		"command_type": String(last_command.get("command_type", "")),
		"total_command_ms": float(last_command.get("total_command_ms", 0.0)),
		"route_execution_lookup_ms": float(phase_buckets.get("route_execution_lookup", 0.0)),
		"movement_rules_ms": float(phase_buckets.get("movement_rules", 0.0)),
		"preview_total_steps": int(route_preview.get("total_steps", 0)),
		"preview_reachable_steps": int(route_preview.get("reachable_steps", 0)),
		"preview_unreachable_steps": int(route_preview.get("unreachable_steps", 0)),
		"executed_steps": route_steps.size(),
		"final_tile": {"x": finish.x, "y": finish.y},
	}
	if route_steps.size() != 4 or movement_after != 0:
		return _fail("Full-route confirmation did not consume one point per traversed tile.", result)
	if before_final_explored or not OverworldRules.is_tile_explored(session, 4, 1):
		return _fail("Fog did not reveal along the traversed route.", result)
	if before_target_explored or OverworldRules.is_tile_explored(session, target.x, target.y):
		return _fail("Fog revealed the untraversed destination before the hero reached it.", result)
	shell.queue_free()
	return true

func _assert_selected_route_cache_reuse() -> bool:
	var session = _session_with_map(32, 3, true)
	session.overworld["fog"] = {}
	var opened := await _open_shell(session)
	var shell: Node = opened.get("shell", null)
	session = opened.get("session", session)
	_prepare_shell_state(shell, session, Vector2i(0, 1), 31)
	shell.call("validation_set_debug_overlay_enabled", true)
	var target := Vector2i(30, 1)
	var selection: Dictionary = shell.call("validation_select_tile", target.x, target.y)
	await get_tree().process_frame
	await get_tree().process_frame
	var selection_command := _last_debug_command(shell)
	var selection_map_path: Dictionary = selection_command.get("map_view_path", {}) if selection_command.get("map_view_path", {}) is Dictionary else {}
	if String(selection.get("selected_route_decision", {}).get("status", "")) != "reachable":
		return _fail("Cache regression route should be reachable.", selection)
	if int(selection_command.get("route_bfs_calls", -1)) != 1:
		return _fail("Route selection should compute shell BFS exactly once.", selection_command)
	if not bool(selection_command.get("map_view_route_cache_reused", false)) or not bool(selection_map_path.get("cache_reused", false)):
		return _fail("Map view did not reuse the shell selected-route cache.", selection_command)
	if int(selection_command.get("route_cache_misses", 0)) != 1 or int(selection_command.get("route_cache_hits", 0)) <= 0:
		return _fail("Selection did not expose selected-route cache miss followed by reuse hits.", selection_command)

	shell.call("validation_reset_profile", true)
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var snapshot_profile: Dictionary = shell.call("validation_profile_snapshot")
	if not (String(snapshot.get("primary_action_id", "")) in ["advance_route", "march_selected"]):
		return _fail("Cached selected route did not remain available to action surfaces.", snapshot)
	if int(snapshot_profile.get("route_bfs_calls", 0)) != 0:
		return _fail("Action/validation surfaces recomputed BFS instead of reusing cached route.", snapshot_profile)
	if int(snapshot_profile.get("selected_route_cache_hits", 0)) <= 0:
		return _fail("Action/validation surfaces did not hit the durable selected-route cache.", snapshot_profile)

	var result: Dictionary = shell.call("validation_perform_primary_action")
	await get_tree().process_frame
	await get_tree().process_frame
	var move_command := _last_debug_command(shell)
	if not bool(result.get("ok", false)):
		return _fail("Cached route confirmation failed.", result)
	if int(move_command.get("route_bfs_calls", -1)) != 0:
		return _fail("Existing-selection confirmation recomputed BFS despite a valid cached route.", move_command)
	if int(move_command.get("route_cache_hits", 0)) <= 0 or not bool(move_command.get("map_view_route_cache_reused", false)):
		return _fail("Existing-selection confirmation did not reuse route cache through refresh/map view.", move_command)
	_evidence["selected_route_cache_reuse"] = {
		"selection_bfs_calls": int(selection_command.get("route_bfs_calls", -1)),
		"selection_route_cache_hits": int(selection_command.get("route_cache_hits", 0)),
		"selection_route_cache_misses": int(selection_command.get("route_cache_misses", 0)),
		"selection_map_view_reused": bool(selection_command.get("map_view_route_cache_reused", false)),
		"snapshot_bfs_calls": int(snapshot_profile.get("route_bfs_calls", 0)),
		"confirmation_bfs_calls": int(move_command.get("route_bfs_calls", -1)),
		"confirmation_route_cache_hits": int(move_command.get("route_cache_hits", 0)),
		"confirmation_map_view_reused": bool(move_command.get("map_view_route_cache_reused", false)),
	}
	shell.queue_free()
	return true

func _assert_reachable_interaction_resolves_only_at_destination() -> bool:
	var session = _session_with_map(7, 3)
	session.overworld["resource_nodes"] = [
		{
			"placement_id": "full_route_wagon",
			"site_id": "site_wood_wagon",
			"x": 4,
			"y": 1,
			"collected": false,
			"collected_by_faction_id": "",
		}
	]
	session.overworld["fog"] = {}
	var opened := await _open_shell(session)
	var shell: Node = opened.get("shell", null)
	session = opened.get("session", session)
	_prepare_shell_state(shell, session, Vector2i(0, 1), 4)
	var selection: Dictionary = shell.call("validation_select_tile", 4, 1)
	if String(selection.get("selected_route_decision", {}).get("status", "")) != "reachable":
		return _fail("Reachable interaction target did not expose an executable route.", selection)
	var result: Dictionary = shell.call("validation_perform_primary_action")
	var finish := OverworldRules.hero_position(session)
	var node: Dictionary = session.overworld.get("resource_nodes", [])[0]
	if not bool(result.get("ok", false)) or finish != Vector2i(4, 1):
		return _fail("Reachable interaction route did not move to the destination.", result)
	if not bool(node.get("collected", false)):
		return _fail("Reachable interaction did not resolve at the destination.", result)
	shell.queue_free()
	return true

func _assert_route_does_not_pass_through_interaction() -> bool:
	var session = _session_with_map(6, 3, true)
	session.overworld["resource_nodes"] = [
		{
			"placement_id": "corridor_blocking_wagon",
			"site_id": "site_wood_wagon",
			"x": 2,
			"y": 1,
			"collected": false,
			"collected_by_faction_id": "",
		}
	]
	session.overworld["fog"] = {}
	var opened := await _open_shell(session)
	var shell: Node = opened.get("shell", null)
	session = opened.get("session", session)
	_prepare_shell_state(shell, session, Vector2i(0, 1), 6)
	var selection: Dictionary = shell.call("validation_select_tile", 5, 1)
	var route_decision: Dictionary = selection.get("selected_route_decision", {})
	if String(route_decision.get("status", "")) != "blocked" or bool(route_decision.get("route_clear", true)):
		return _fail("Route through an intermediate interaction should not be offered.", selection)
	if not String(route_decision.get("blocked_reason", "")).contains("No clear route"):
		return _fail("Blocked route did not explain that no clean path exists.", selection)
	shell.queue_free()
	return true

func _last_debug_command(shell: Node) -> Dictionary:
	var overlay: Dictionary = shell.call("validation_debug_overlay_snapshot")
	return overlay.get("last_command", {}) if overlay.get("last_command", {}) is Dictionary else {}

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

func _session_with_map(width: int, height: int, corridor: bool = false):
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var rows := []
	for y in range(height):
		var row := []
		for _x in range(width):
			row.append("water" if corridor and y != 1 else "grass")
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
	hero["level"] = 1
	hero["experience"] = 0
	hero["specialties"] = []
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
			entry["level"] = 1
			entry["experience"] = 0
			entry["specialties"] = []
			entry["movement"] = movement.duplicate(true)
			heroes[index] = entry
			break
	session.overworld["player_heroes"] = heroes

func _fail(message: String, payload: Dictionary = {}) -> bool:
	push_error("%s failed: %s payload=%s" % [REPORT_ID, message, JSON.stringify(payload)])
	get_tree().quit(1)
	return false
