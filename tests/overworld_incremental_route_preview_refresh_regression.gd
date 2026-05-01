extends Node

const REPORT_ID := "OVERWORLD_INCREMENTAL_ROUTE_PREVIEW_REFRESH_REGRESSION"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var session = _session_with_map(12, 4)
	var opened := await _open_shell(session)
	var shell: Node = opened.get("shell", null)
	session = opened.get("session", session)
	_prepare_shell_state(shell, session, Vector2i(0, 1), 10)

	shell.call("validation_reset_profile", true)
	var target := Vector2i(8, 1)
	var selection: Dictionary = shell.call("validation_select_tile", target.x, target.y)
	var profile: Dictionary = shell.call("validation_profile_snapshot")
	if not bool(selection.get("ok", false)):
		_fail("Route selection failed.", selection)
		return
	if String(selection.get("primary_action_id", "")) != "advance_route":
		_fail("Route selection did not expose the expected primary route action.", selection)
		return
	if not _assert_incremental_route_request(profile, "first_selection"):
		return
	if int(profile.get("selected_context_actions_cache_misses", 0)) <= 0:
		_fail("Incremental route selection did not build selected context actions.", profile)
		return
	if int(profile.get("selected_route_decision_surface_cache_misses", 0)) <= 0:
		_fail("Incremental route selection did not build the route decision surface.", profile)
		return
	if int(profile.get("hero_actions_cache_misses", 0)) != 0:
		_fail("Incremental route selection rebuilt hero actions despite no hero/roster dirty phase.", profile)
		return

	shell.call("validation_reset_profile", true)
	var second_target := Vector2i(9, 1)
	var changed_selection: Dictionary = shell.call("validation_select_tile", second_target.x, second_target.y)
	var changed_profile: Dictionary = shell.call("validation_profile_snapshot")
	if not bool(changed_selection.get("ok", false)):
		_fail("Second route selection failed.", changed_selection)
		return
	if not _assert_incremental_route_request(changed_profile, "changed_selection"):
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"first_request": profile.get("last_refresh_request", {}),
		"changed_request": changed_profile.get("last_refresh_request", {}),
		"first_context_misses": int(profile.get("selected_context_actions_cache_misses", 0)),
		"first_route_decision_misses": int(profile.get("selected_route_decision_surface_cache_misses", 0)),
	})])
	shell.queue_free()
	get_tree().quit(0)

func _assert_incremental_route_request(profile: Dictionary, label: String) -> bool:
	var request: Dictionary = profile.get("last_refresh_request", {}) if profile.get("last_refresh_request", {}) is Dictionary else {}
	if request.is_empty():
		_fail("%s did not record a refresh request." % label, profile)
		return false
	if bool(request.get("full", true)):
		_fail("%s used the full refresh path instead of the route-preview request." % label, request)
		return false
	var phases: Array = request.get("phases", []) if request.get("phases", []) is Array else []
	for required_phase in ["map_view", "context_actions", "route_preview"]:
		if required_phase not in phases:
			_fail("%s incremental request missed required phase %s." % [label, required_phase], request)
			return false
	for forbidden_phase in ["hero_actions", "spell_rails", "specialty_rails", "artifact_rails", "status_surfaces", "save_surface", "generated_surfaces"]:
		if forbidden_phase in phases:
			_fail("%s incremental request included unrelated phase %s." % [label, forbidden_phase], request)
			return false
	var phase_counts: Dictionary = {}
	for key_value in profile.keys():
		var key := String(key_value)
		if key.begins_with("refresh_phase_") and key.ends_with("_calls"):
			phase_counts[key] = int(profile.get(key, 0))
	if int(profile.get("refresh_phase_map_view_calls", 0)) <= 0:
		_fail("%s did not run the map-view phase." % label, profile)
		return false
	if int(profile.get("refresh_phase_context_actions_calls", 0)) <= 0:
		_fail("%s did not run the context-action phase." % label, profile)
		return false
	if int(profile.get("refresh_phase_route_preview_calls", 0)) <= 0:
		_fail("%s did not run the route-preview phase." % label, profile)
		return false
	for skipped_counter in [
		"refresh_phase_hero_actions_calls",
		"refresh_phase_spell_rails_calls",
		"refresh_phase_specialty_rails_calls",
		"refresh_phase_artifact_rails_calls",
		"refresh_phase_status_surfaces_calls",
		"refresh_phase_save_surface_calls",
		"refresh_phase_generated_surfaces_calls",
		"refresh_hero_actions_calls",
		"refresh_spell_actions_calls",
		"refresh_specialty_actions_calls",
		"refresh_artifact_actions_calls",
	]:
		if int(profile.get(skipped_counter, 0)) != 0:
			_fail("%s rebuilt an unrelated refresh phase: %s." % [label, skipped_counter], profile)
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

func _fail(message: String, payload: Variant = {}) -> void:
	push_error("%s failed: %s %s" % [REPORT_ID, message, JSON.stringify(payload)])
	get_tree().quit(1)
