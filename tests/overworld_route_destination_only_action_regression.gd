extends Node

const REPORT_ID := "OVERWORLD_ROUTE_DESTINATION_ONLY_ACTION_REGRESSION"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not await _assert_plain_route_selection_and_confirmation_skip_broad_actions():
		return
	if not await _assert_resource_destination_keeps_existing_interaction_semantics():
		return
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": true})])
	get_tree().quit(0)

func _assert_plain_route_selection_and_confirmation_skip_broad_actions() -> bool:
	var session = _session_with_map(9, 3)
	var opened := await _open_shell(session)
	var shell: Node = opened.get("shell", null)
	session = opened.get("session", session)
	_prepare_shell_state(shell, session, Vector2i(0, 1), 8)
	shell.call("validation_set_debug_overlay_enabled", true)

	var target := Vector2i(5, 1)
	var selection: Dictionary = shell.call("validation_select_tile", target.x, target.y)
	if not bool(selection.get("ok", false)):
		return _fail("Plain route selection failed.", selection)
	if String(selection.get("primary_action_id", "")) != "advance_route":
		return _fail("Plain route selection did not expose route advance.", selection)
	var selection_command := _last_command(shell)
	if not _assert_destination_only_command(selection_command, "select_route", "open", true):
		return false

	var clicked: Dictionary = shell.call("validation_click_tile", target.x, target.y)
	if not bool(clicked.get("ok", false)):
		return _fail("Plain route confirmation failed.", clicked)
	if OverworldRules.hero_position(session) != target:
		return _fail("Plain route confirmation did not move along the selected route.", {
			"hero": _tile_payload(OverworldRules.hero_position(session)),
			"target": _tile_payload(target),
		})
	var confirm_command := _last_command(shell)
	if not _assert_destination_only_command(confirm_command, "click_existing_selection", "current", false):
		return false
	if int(confirm_command.get("route_cache_hits", 0)) <= 0:
		return _fail("Route confirmation did not reuse the selected route cache.", confirm_command)
	shell.queue_free()
	return true

func _assert_resource_destination_keeps_existing_interaction_semantics() -> bool:
	var session = _session_with_map(7, 3)
	session.overworld["resource_nodes"] = [
		{
			"placement_id": "destination_only_wagon",
			"site_id": "site_wood_wagon",
			"x": 4,
			"y": 1,
			"collected": false,
			"collected_by_faction_id": "",
		}
	]
	var opened := await _open_shell(session)
	var shell: Node = opened.get("shell", null)
	session = opened.get("session", session)
	_prepare_shell_state(shell, session, Vector2i(0, 1), 4)
	shell.call("validation_set_debug_overlay_enabled", true)

	var selection: Dictionary = shell.call("validation_select_tile", 4, 1)
	if not bool(selection.get("ok", false)):
		return _fail("Resource route selection failed.", selection)
	if String(selection.get("primary_action_id", "")) != "advance_route":
		return _fail("Resource route selection did not keep route execution as the commit path.", selection)
	if not _assert_destination_only_command(_last_command(shell), "select_route", "resource", true):
		return false

	var clicked: Dictionary = shell.call("validation_click_tile", 4, 1)
	if not bool(clicked.get("ok", false)):
		return _fail("Resource route confirmation failed.", clicked)
	var node: Dictionary = session.overworld.get("resource_nodes", [])[0]
	if not bool(node.get("collected", false)):
		return _fail("Resource destination did not resolve through existing post-move interaction semantics.", clicked)
	var confirm_command := _last_command(shell)
	var profile: Dictionary = confirm_command.get("profile", {}) if confirm_command.get("profile", {}) is Dictionary else {}
	var movement_details: Dictionary = profile.get("last_cmd_movement_rules", {}) if profile.get("last_cmd_movement_rules", {}) is Dictionary else {}
	if String(movement_details.get("cached_execution_mode", "")) != "destination_interaction_fast_path":
		return _fail("Resource route did not use descriptor destination interaction fast path.", movement_details)
	if String(movement_details.get("interaction_dispatch_mode", "")) != "destination_descriptor":
		return _fail("Resource route did not dispatch by destination descriptor.", movement_details)
	if bool(movement_details.get("scenario_eval_skipped", true)):
		return _fail("Resource destination interaction should preserve scenario evaluation semantics.", movement_details)
	var pathing_profile: Dictionary = OverworldRules.validation_pathing_profile_snapshot()
	if int(pathing_profile.get("post_move_global_discovery_count", 0)) != 0:
		return _fail("Resource destination interaction used global post-move discovery.", pathing_profile)
	if not _assert_destination_only_command(_last_command(shell), "click_existing_selection", "current", false):
		return false
	shell.queue_free()
	return true

func _assert_destination_only_command(command: Dictionary, expected_command: String, expected_kind: String, expect_selection_request: bool) -> bool:
	if String(command.get("command_type", "")) != expected_command:
		return _fail("Unexpected command type.", command)
	var request: Dictionary = command.get("refresh_request", {}) if command.get("refresh_request", {}) is Dictionary else {}
	if bool(request.get("full", true)):
		return _fail("Route command used full refresh.", command)
	var phases: Array = request.get("phases", []) if request.get("phases", []) is Array else []
	for required_phase in ["map_view", "route_preview"]:
		if required_phase not in phases:
			return _fail("Route command missed required phase %s." % required_phase, command)
	for forbidden_phase in ["context_actions", "hero_actions"]:
		if forbidden_phase in phases:
			return _fail("Route command requested broad phase %s." % forbidden_phase, command)
	var profile: Dictionary = command.get("profile", {}) if command.get("profile", {}) is Dictionary else {}
	for forbidden_counter in ["refresh_context_actions_calls", "refresh_hero_actions_calls", "refresh_tooltip_context_drawers_calls"]:
		if int(profile.get(forbidden_counter, 0)) != 0:
			return _fail("Route command executed skipped refresh bucket %s." % forbidden_counter, command)
	var destination_only: Dictionary = command.get("route_destination_only_action", {}) if command.get("route_destination_only_action", {}) is Dictionary else {}
	if not bool(destination_only.get("destination_only", false)):
		return _fail("Route command did not use destination-only action path.", command)
	if not bool(destination_only.get("broad_context_actions_skipped", false)) or not bool(destination_only.get("hero_actions_skipped", false)):
		return _fail("Route command did not expose broad action skips.", command)
	if String(destination_only.get("destination_interaction_kind", "")) != expected_kind:
		return _fail("Route command exposed the wrong destination interaction kind.", command)
	if expected_kind in ["open", "current"]:
		if not bool(destination_only.get("simple_route_ui_fast_path", false)):
			return _fail("Open/current route command did not expose the simple route UI fast path.", command)
		if not bool(destination_only.get("rich_route_surface_skipped", false)):
			return _fail("Open/current route command did not report skipped rich route surfaces.", command)
	if expect_selection_request and int(profile.get("selected_context_actions_cache_misses", 0)) != 0:
		return _fail("Route selection recomputed broad selected context actions.", command)
	return true

func _last_command(shell: Node) -> Dictionary:
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

func _tile_payload(tile: Vector2i) -> Dictionary:
	return {"x": tile.x, "y": tile.y}

func _fail(message: String, payload: Variant = {}) -> bool:
	push_error("%s failed: %s %s" % [REPORT_ID, message, JSON.stringify(payload)])
	get_tree().quit(1)
	return false
