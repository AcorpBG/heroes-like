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
	shell.call("_set_selected_tile", first_target)
	shell.call("_refresh_selected_route_preview", "validation_selected_route_changed")
	var initial_action: Dictionary = shell.call("_current_primary_action").duplicate(true)
	if String(initial_action.get("id", "")) != "advance_route":
		_fail("Initial selected route did not expose the expected movement action.", initial_action)
		return

	shell.call("validation_reset_profile", true)
	shell.call("_refresh")
	var reused_profile: Dictionary = shell.call("validation_profile_snapshot")
	var reused_action: Dictionary = shell.call("_current_primary_action").duplicate(true)
	if not _require_compact_cache_phase(reused_profile, reused_action, "unchanged", true, "open", first_target, "reachable"):
		return

	shell.call("validation_reset_profile", true)
	shell.call("_set_selected_tile", second_target)
	shell.call("_refresh_selected_route_preview", "validation_selected_route_changed")
	var selected_tile_profile: Dictionary = shell.call("validation_profile_snapshot")
	var selected_tile_action: Dictionary = shell.call("_current_primary_action").duplicate(true)
	if not _require_compact_cache_phase(selected_tile_profile, selected_tile_action, "selected_tile", false, "open", second_target, "reachable"):
		return

	shell.call("validation_reset_profile", true)
	_set_active_hero_position(session, Vector2i(1, 1))
	OverworldRules.refresh_fog_of_war(session)
	shell.call("_refresh")
	var hero_position_profile: Dictionary = shell.call("validation_profile_snapshot")
	var hero_position_action: Dictionary = shell.call("_current_primary_action").duplicate(true)
	if not _require_compact_cache_phase(hero_position_profile, hero_position_action, "hero_position", false, "open", second_target, "reachable"):
		return

	shell.call("validation_reset_profile", true)
	_set_active_hero_movement(session, 6)
	shell.call("_refresh")
	var movement_profile: Dictionary = shell.call("validation_profile_snapshot")
	var movement_action: Dictionary = shell.call("_current_primary_action").duplicate(true)
	if not _require_compact_cache_phase(movement_profile, movement_action, "movement", false, "open", second_target, "not_today"):
		return

	shell.call("validation_reset_profile", true)
	_add_route_blocking_encounter(session, second_target)
	shell.call("_refresh_selected_route_preview", "validation_selected_route_changed")
	var topology_profile: Dictionary = shell.call("validation_profile_snapshot")
	var topology_action: Dictionary = shell.call("_current_primary_action").duplicate(true)
	if not _require_compact_cache_phase(topology_profile, topology_action, "topology", false, "encounter", second_target, "not_today"):
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"reuse_destination_hits": int(reused_profile.get("selected_route_destination_action_cache_hits", 0)),
		"reuse_selected_route_hits": int(reused_profile.get("selected_route_cache_hits", 0)),
		"selected_tile_destination_misses": int(selected_tile_profile.get("selected_route_destination_action_cache_misses", 0)),
		"selected_tile_selected_route_misses": int(selected_tile_profile.get("selected_route_cache_misses", 0)),
		"hero_position_destination_misses": int(hero_position_profile.get("selected_route_destination_action_cache_misses", 0)),
		"hero_position_selected_route_misses": int(hero_position_profile.get("selected_route_cache_misses", 0)),
		"movement_destination_misses": int(movement_profile.get("selected_route_destination_action_cache_misses", 0)),
		"movement_selected_route_misses": int(movement_profile.get("selected_route_cache_misses", 0)),
		"topology_destination_misses": int(topology_profile.get("selected_route_destination_action_cache_misses", 0)),
		"topology_selected_route_misses": int(topology_profile.get("selected_route_cache_misses", 0)),
		"rich_route_decision_hits": int(topology_profile.get("selected_route_decision_surface_cache_hits", 0)),
		"rich_route_decision_misses": int(topology_profile.get("selected_route_decision_surface_cache_misses", 0)),
	})])
	shell.queue_free()
	get_tree().quit(0)

func _require_compact_cache_phase(profile: Dictionary, action: Dictionary, phase: String, expect_reuse: bool, expected_kind: String, expected_tile: Vector2i, expected_status: String) -> bool:
	var destination_cache: Dictionary = profile.get("last_selected_route_destination_action_cache", {}) if profile.get("last_selected_route_destination_action_cache", {}) is Dictionary else {}
	var selected_route_cache: Dictionary = profile.get("last_selected_route_cache", {}) if profile.get("last_selected_route_cache", {}) is Dictionary else {}
	var context_surface: Dictionary = profile.get("last_context_tile_text_simple_route_fast_path", {}) if profile.get("last_context_tile_text_simple_route_fast_path", {}) is Dictionary else {}
	var primary_tooltip: Dictionary = profile.get("last_primary_route_action_tooltip", {}) if profile.get("last_primary_route_action_tooltip", {}) is Dictionary else {}
	var destination_interaction: Dictionary = action.get("destination_interaction", {}) if action.get("destination_interaction", {}) is Dictionary else {}
	var route_decision: Dictionary = action.get("route_decision", {}) if action.get("route_decision", {}) is Dictionary else {}
	var expected_simple := expected_kind == "open"
	var checks := {
		"destination_cache_reuse_or_invalidation": int(profile.get("selected_route_destination_action_cache_hits" if expect_reuse else "selected_route_destination_action_cache_misses", 0)) > 0,
		"selected_route_reuse_or_invalidation": int(profile.get("selected_route_cache_hits" if expect_reuse else "selected_route_cache_misses", 0)) > 0,
		"rich_decision_hits_zero": int(profile.get("selected_route_decision_surface_cache_hits", 0)) == 0,
		"rich_decision_misses_zero": int(profile.get("selected_route_decision_surface_cache_misses", 0)) == 0,
		"destination_cache_minimal": String(destination_cache.get("signature_mode", "")) == "destination_minimal",
		"destination_cache_has_action": int(destination_cache.get("action_count", 0)) > 0,
		"selected_route_cached": int(selected_route_cache.get("path_tiles", 0)) > 1,
		"context_kind_exact": String(context_surface.get("destination_interaction_kind", "")) == expected_kind,
		"context_route_status_exact": String(context_surface.get("route_status", "")) == expected_status,
		"context_rich_skipped": bool(context_surface.get("rich_route_decision_skipped", false)),
		"action_id_exact": String(action.get("id", "")) == "advance_route",
		"action_enabled": not bool(action.get("disabled", false)),
		"action_destination_only": bool(action.get("destination_only", false)),
		"action_kind_exact": String(destination_interaction.get("kind", "")) == expected_kind,
		"action_destination_x_exact": int(destination_interaction.get("x", -1)) == expected_tile.x,
		"action_destination_y_exact": int(destination_interaction.get("y", -1)) == expected_tile.y,
		"action_rich_skipped": bool(destination_interaction.get("rich_route_surface_skipped", false)),
		"action_mode_exact": bool(action.get("simple_route_ui_fast_path", false)) == expected_simple and bool(action.get("compact_interaction_destination_fast_path", false)) == not expected_simple,
		"action_route_decision_present": not route_decision.is_empty(),
		"action_route_status_exact": String(route_decision.get("status", "")) == expected_status,
		"action_route_clear": bool(route_decision.get("route_clear", false)),
		"reachable_details_exact": expected_status != "reachable" or (bool(route_decision.get("destination_reachable", false)) and int(route_decision.get("unreachable_steps", -1)) == 0),
		"not_today_details_exact": expected_status != "not_today" or (
			not bool(route_decision.get("destination_reachable", true))
			and int(route_decision.get("movement_current", -1)) == 6
			and int(route_decision.get("movement_cost", -1)) == 8
			and int(route_decision.get("reachable_steps", -1)) == 6
			and int(route_decision.get("reachable_cost", -1)) == 6
			and int(route_decision.get("unreachable_steps", -1)) == 2
			and int(route_decision.get("movement_after_order", -1)) == 0
			and String(route_decision.get("blocked_reason", "")) == "Route is clear; 2 steps remain after today's movement."
		),
		"primary_mode_exact": String(primary_tooltip.get("mode", "")) == ("simple_route" if expected_simple else "compact_interaction_destination"),
		"primary_rich_skipped": bool(primary_tooltip.get("rich_commit_check_skipped", false)),
	}
	for value in checks.values():
		if not bool(value):
			_fail("Selected-route compact cache phase did not retain exact reuse/invalidation and rich-skip ownership.", {
				"phase": phase,
				"expect_reuse": expect_reuse,
				"expected_kind": expected_kind,
				"expected_tile": {"x": expected_tile.x, "y": expected_tile.y},
				"expected_status": expected_status,
				"checks": checks,
				"destination_cache": destination_cache,
				"selected_route_cache": selected_route_cache,
				"context_surface": context_surface,
				"action": action,
				"destination_interaction": destination_interaction,
				"route_decision": route_decision,
				"primary_tooltip": primary_tooltip,
			})
			return false
	return true

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
