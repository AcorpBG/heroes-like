extends Node

const REPORT_ID := "OVERWORLD_CACHED_ROUTE_EXECUTION_REGRESSION"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not await _assert_selected_route_uses_minimal_signatures():
		return
	if not await _assert_cached_execution_skips_full_revalidation():
		return
	if not await _assert_adjacent_open_click_uses_cached_execution():
		return
	if not await _assert_unknown_destination_descriptor_falls_back():
		return
	if not await _assert_stale_route_falls_back_to_full_revalidation():
		return
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": true})])
	get_tree().quit(0)

func _assert_selected_route_uses_minimal_signatures() -> bool:
	var session = _session_with_map(32, 3, true)
	var opened := await _open_shell(session)
	var shell: Node = opened.get("shell", null)
	session = opened.get("session", session)
	_prepare_shell_state(shell, session, Vector2i(0, 1), 31)
	shell.call("validation_set_debug_overlay_enabled", true)
	shell.call("validation_reset_profile", true)
	var selection: Dictionary = shell.call("validation_select_tile", 30, 1)
	await get_tree().process_frame
	var profile: Dictionary = shell.call("validation_profile_snapshot")
	var command := _last_debug_command(shell)
	var phase_buckets: Dictionary = command.get("phase_buckets_ms", {}) if command.get("phase_buckets_ms", {}) is Dictionary else {}
	var decision_cache: Dictionary = profile.get("last_selected_route_decision_surface_cache", {}) if profile.get("last_selected_route_decision_surface_cache", {}) is Dictionary else {}
	var signature := String(decision_cache.get("signature", ""))
	if not bool(selection.get("ok", false)):
		return _fail("Route selection failed.", selection)
	if int(profile.get("selected_route_broad_map_signature_calls", 0)) != 0:
		return _fail("Route selection called broad map signature construction.", profile)
	if int(profile.get("selected_route_broad_topology_signature_calls", 0)) != 0:
		return _fail("Route selection called broad topology signature construction.", profile)
	if String(decision_cache.get("signature_mode", "")) != "destination_minimal":
		return _fail("Route decision cache did not report the minimal destination signature path.", decision_cache)
	if signature.length() > 512 or signature.contains("objective_recap") or signature.contains("resources"):
		return _fail("Route decision signature is not compact destination-only data.", decision_cache)
	if float(phase_buckets.get("route_decision_construction", 0.0)) > 100.0:
		return _fail("Route decision construction was unexpectedly large in the controlled route test.", command)
	shell.queue_free()
	return true

func _assert_cached_execution_skips_full_revalidation() -> bool:
	var session = _session_with_map(32, 3, true)
	var opened := await _open_shell(session)
	var shell: Node = opened.get("shell", null)
	session = opened.get("session", session)
	_prepare_shell_state(shell, session, Vector2i(0, 1), 31)
	shell.call("validation_set_debug_overlay_enabled", true)
	var selection: Dictionary = shell.call("validation_select_tile", 30, 1)
	if String(selection.get("selected_route_decision", {}).get("status", "")) != "reachable":
		return _fail("Cached execution setup did not expose a reachable route.", selection)
	shell.call("validation_reset_profile", false)
	var result: Dictionary = shell.call("validation_perform_primary_action")
	await get_tree().process_frame
	var command := _last_debug_command(shell)
	var profile: Dictionary = command.get("profile", {}) if command.get("profile", {}) is Dictionary else {}
	var movement_details: Dictionary = profile.get("last_cmd_movement_rules", {}) if profile.get("last_cmd_movement_rules", {}) is Dictionary else {}
	var route_execution: Dictionary = result.get("route_execution", {}) if result.get("route_execution", {}) is Dictionary else {}
	if not bool(result.get("ok", false)):
		return _fail("Cached route execution failed.", result)
	if not bool(movement_details.get("cached_route_execution", false)):
		return _fail("Selected-route confirmation did not use cached route execution.", movement_details)
	if String(movement_details.get("route_validation_mode", "")) != "cached_prevalidated":
		return _fail("Selected-route confirmation used the wrong validation mode.", movement_details)
	if String(movement_details.get("fallback_reason", "")) != "":
		return _fail("Cached route execution unexpectedly fell back.", movement_details)
	if String(route_execution.get("route_validation_mode", "")) != "cached_prevalidated":
		return _fail("Route execution result did not expose cached validation mode.", result)
	if String(movement_details.get("cached_execution_mode", "")) != "open_fast_path":
		return _fail("Open cached route did not use the open fast path.", movement_details)
	if not bool(movement_details.get("post_action_recap_skipped", false)):
		return _fail("Open cached route did not skip post-action recap.", movement_details)
	if not bool(movement_details.get("scenario_eval_skipped", false)):
		return _fail("Open cached route did not skip scenario evaluation.", movement_details)
	if String(movement_details.get("interaction_dispatch_mode", "")) != "none":
		return _fail("Open cached route unexpectedly dispatched an interaction.", movement_details)
	if not (result.get("post_action_recap", {}) is Dictionary) or not result.get("post_action_recap", {}).is_empty():
		return _fail("Open cached route produced a post-action recap.", result)
	var pathing_profile: Dictionary = OverworldRules.validation_pathing_profile_snapshot()
	if int(pathing_profile.get("post_move_global_discovery_count", 0)) != 0:
		return _fail("Open cached route used global post-move discovery.", pathing_profile)
	if int(pathing_profile.get("post_action_tile_context_scan_count", 0)) != 0:
		return _fail("Open cached route scanned post-action tile context.", pathing_profile)
	shell.queue_free()
	return true

func _assert_adjacent_open_click_uses_cached_execution() -> bool:
	var session = _session_with_map(9, 3, true)
	var opened := await _open_shell(session)
	var shell: Node = opened.get("shell", null)
	session = opened.get("session", session)
	_prepare_shell_state(shell, session, Vector2i(0, 1), 6)
	shell.call("validation_set_debug_overlay_enabled", true)
	shell.call("validation_reset_profile", false)
	var clicked: Dictionary = shell.call("validation_click_tile", 1, 1)
	await get_tree().process_frame
	var command := _last_debug_command(shell)
	var profile: Dictionary = command.get("profile", {}) if command.get("profile", {}) is Dictionary else {}
	var movement_details: Dictionary = profile.get("last_cmd_movement_rules", {}) if profile.get("last_cmd_movement_rules", {}) is Dictionary else {}
	var destination_only: Dictionary = command.get("route_destination_only_action", {}) if command.get("route_destination_only_action", {}) is Dictionary else {}
	if not bool(clicked.get("ok", false)):
		return _fail("Adjacent open-tile click did not execute.", clicked)
	if String(command.get("command_type", "")) != "adjacent_move":
		return _fail("Adjacent open-tile click did not keep the adjacent_move command type.", command)
	if OverworldRules.hero_position(session) != Vector2i(1, 1):
		return _fail("Adjacent open-tile click did not move the active hero.", clicked)
	if not bool(movement_details.get("cached_route_execution", false)):
		return _fail("Adjacent open-tile click did not use cached selected-route execution.", movement_details)
	if String(movement_details.get("route_validation_mode", "")) != "cached_prevalidated":
		return _fail("Adjacent open-tile click used the wrong route validation mode.", movement_details)
	if String(movement_details.get("cached_execution_mode", "")) != "open_fast_path":
		return _fail("Adjacent open-tile click did not use the open fast path.", movement_details)
	if not bool(destination_only.get("simple_route_ui_fast_path", false)) or String(destination_only.get("destination_interaction_kind", "")) != "current":
		return _fail("Adjacent post-move refresh did not use the minimal current-tile route UI.", command)
	shell.queue_free()
	return true

func _assert_unknown_destination_descriptor_falls_back() -> bool:
	var session = _session_with_map(12, 3, true)
	var opened := await _open_shell(session)
	var shell: Node = opened.get("shell", null)
	session = opened.get("session", session)
	_prepare_shell_state(shell, session, Vector2i(0, 1), 10)
	shell.call("validation_set_debug_overlay_enabled", true)
	var selection: Dictionary = shell.call("validation_select_tile", 8, 1)
	if String(selection.get("selected_route_decision", {}).get("status", "")) != "reachable":
		return _fail("Descriptor fallback setup did not expose a reachable route.", selection)
	var stale_state: Dictionary = shell.get("_selected_route_state").duplicate(true)
	var descriptor: Dictionary = stale_state.get("destination_interaction_descriptor", {}) if stale_state.get("destination_interaction_descriptor", {}) is Dictionary else {}
	descriptor["kind"] = "mystery"
	stale_state["destination_interaction_descriptor"] = descriptor
	stale_state["signature"] = shell.call("_selected_route_signature")
	shell.set("_selected_route_state", stale_state)
	shell.call("validation_reset_profile", false)
	var result: Dictionary = shell.call("validation_perform_primary_action")
	await get_tree().process_frame
	var command := _last_debug_command(shell)
	var profile: Dictionary = command.get("profile", {}) if command.get("profile", {}) is Dictionary else {}
	var movement_details: Dictionary = profile.get("last_cmd_movement_rules", {}) if profile.get("last_cmd_movement_rules", {}) is Dictionary else {}
	if bool(movement_details.get("cached_route_execution", true)):
		return _fail("Unknown destination descriptor did not fall back to the full validation path.", movement_details)
	if String(movement_details.get("fallback_reason", "")) != "unknown_destination_descriptor":
		return _fail("Unknown destination descriptor fallback reason was not exposed.", movement_details)
	if String(movement_details.get("cached_execution_mode", "")) != "full_fallback":
		return _fail("Unknown destination descriptor did not expose full fallback mode.", movement_details)
	if not bool(result.get("ok", false)):
		return _fail("Unknown descriptor full fallback should still execute a valid route.", result)
	shell.queue_free()
	return true

func _assert_stale_route_falls_back_to_full_revalidation() -> bool:
	var session = _session_with_map(12, 3, true)
	var opened := await _open_shell(session)
	var shell: Node = opened.get("shell", null)
	session = opened.get("session", session)
	_prepare_shell_state(shell, session, Vector2i(0, 1), 10)
	shell.call("validation_set_debug_overlay_enabled", true)
	var selection: Dictionary = shell.call("validation_select_tile", 8, 1)
	if String(selection.get("selected_route_decision", {}).get("status", "")) != "reachable":
		return _fail("Fallback setup did not expose a reachable route.", selection)
	var stale_state: Dictionary = shell.get("_selected_route_state").duplicate(true)
	var stale_route: Array = stale_state.get("route_tiles", []) if stale_state.get("route_tiles", []) is Array else []
	if stale_route.size() <= 1:
		return _fail("Fallback setup route was empty.", stale_state)
	stale_route[0] = Vector2i(3, 1)
	stale_state["route_tiles"] = stale_route
	stale_state["signature"] = shell.call("_selected_route_signature")
	shell.set("_selected_route_state", stale_state)
	shell.call("validation_reset_profile", false)
	var result: Dictionary = shell.call("validation_perform_primary_action")
	await get_tree().process_frame
	var command := _last_debug_command(shell)
	var profile: Dictionary = command.get("profile", {}) if command.get("profile", {}) is Dictionary else {}
	var movement_details: Dictionary = profile.get("last_cmd_movement_rules", {}) if profile.get("last_cmd_movement_rules", {}) is Dictionary else {}
	if bool(movement_details.get("cached_route_execution", true)):
		return _fail("Stale selected route did not fall back to the full validation path.", movement_details)
	if String(movement_details.get("fallback_reason", "")) != "route_start_stale":
		return _fail("Stale selected route fallback reason was not exposed.", movement_details)
	if String(movement_details.get("route_validation_mode", "")) != "full_revalidation":
		return _fail("Stale selected route did not use full revalidation fallback.", movement_details)
	if bool(result.get("ok", true)):
		return _fail("Stale route fallback should preserve try_move_along_route safety and reject the bad route.", result)
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

func _fail(message: String, payload: Variant = {}) -> bool:
	push_error("%s failed: %s payload=%s" % [REPORT_ID, message, JSON.stringify(payload)])
	get_tree().quit(1)
	return false
