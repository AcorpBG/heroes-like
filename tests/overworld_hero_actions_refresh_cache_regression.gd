extends Node

const REPORT_ID := "OVERWORLD_HERO_ACTIONS_REFRESH_CACHE_REGRESSION"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var session = _session_with_map(12, 3)
	var opened := await _open_shell(session)
	var shell: Node = opened.get("shell", null)
	session = opened.get("session", session)
	_prepare_shell_state(shell, session, Vector2i(0, 1), 10)
	var reserve_id := _ensure_reserve_hero(session)
	shell.call("_refresh")

	var initial_snapshot: Dictionary = shell.call("validation_snapshot")
	if _hero_action_count(initial_snapshot) < 2:
		_fail("Hero action setup did not expose an active and reserve commander.", initial_snapshot)
		return

	shell.call("validation_reset_profile", true)
	var target := Vector2i(8, 1)
	var selection: Dictionary = shell.call("validation_select_tile", target.x, target.y)
	var selection_profile: Dictionary = shell.call("validation_profile_snapshot")
	if not bool(selection.get("ok", false)):
		_fail("Route selection failed during hero action cache regression.", selection)
		return
	if int(selection_profile.get("hero_actions_cache_misses", 0)) != 0:
		_fail("Route-selection refresh rebuilt hero actions despite an unchanged hero command signature.", selection_profile)
		return
	if int(selection_profile.get("hero_actions_cache_hits", 0)) <= 0:
		_fail("Route-selection refresh did not reuse cached hero actions.", selection_profile)
		return

	shell.call("validation_reset_profile", true)
	var switch_result := OverworldRules.switch_active_hero(session, reserve_id)
	if not bool(switch_result.get("ok", false)):
		_fail("Active hero switch setup failed.", switch_result)
		return
	shell.call("_refresh")
	var switch_profile: Dictionary = shell.call("validation_profile_snapshot")
	var switch_snapshot: Dictionary = shell.call("validation_snapshot")
	if int(switch_profile.get("hero_actions_cache_misses", 0)) <= 0:
		_fail("Active hero change did not invalidate cached hero actions.", switch_profile)
		return
	if not _hero_action_disabled_for(switch_snapshot, reserve_id):
		_fail("Active hero disabled state did not update after cache invalidation.", switch_snapshot)
		return

	shell.call("validation_reset_profile", true)
	var new_roster_id := _append_roster_hero(session)
	shell.call("_refresh")
	var roster_profile: Dictionary = shell.call("validation_profile_snapshot")
	var roster_snapshot: Dictionary = shell.call("validation_snapshot")
	if int(roster_profile.get("hero_actions_cache_misses", 0)) <= 0:
		_fail("Roster membership change did not invalidate cached hero actions.", roster_profile)
		return
	if not _hero_action_present(roster_snapshot, new_roster_id):
		_fail("Roster membership/order change did not reach hero action surfaces.", roster_snapshot)
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"selection_cache_hits": int(selection_profile.get("hero_actions_cache_hits", 0)),
		"selection_cache_misses": int(selection_profile.get("hero_actions_cache_misses", 0)),
		"active_switch_cache_misses": int(switch_profile.get("hero_actions_cache_misses", 0)),
		"roster_cache_misses": int(roster_profile.get("hero_actions_cache_misses", 0)),
		"hero_action_count_after_roster": _hero_action_count(roster_snapshot),
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

func _ensure_reserve_hero(session) -> String:
	OverworldRules.normalize_overworld_state(session)
	var active_id := String(session.overworld.get("active_hero_id", ""))
	var heroes: Array = session.overworld.get("player_heroes", []) if session.overworld.get("player_heroes", []) is Array else []
	for hero_value in heroes:
		if hero_value is Dictionary and String(hero_value.get("id", "")) != active_id:
			return String(hero_value.get("id", ""))
	var reserve_id := "hero_caelen" if active_id != "hero_caelen" else "hero_mira"
	heroes.append(_reserve_hero_state(reserve_id, Vector2i(1, 1), 7))
	session.overworld["player_heroes"] = heroes
	OverworldRules.normalize_overworld_state(session)
	return reserve_id

func _append_roster_hero(session) -> String:
	var heroes: Array = session.overworld.get("player_heroes", []) if session.overworld.get("player_heroes", []) is Array else []
	var used_ids := {}
	for hero_value in heroes:
		if hero_value is Dictionary:
			used_ids[String(hero_value.get("id", ""))] = true
	var candidate_ids := ["hero_mira", "hero_seren", "hero_torren"]
	var selected_id := ""
	for candidate_id in candidate_ids:
		if not used_ids.has(candidate_id):
			selected_id = candidate_id
			break
	if selected_id == "":
		selected_id = "hero_varis"
	heroes.append(_reserve_hero_state(selected_id, Vector2i(2, 1), 6))
	session.overworld["player_heroes"] = heroes
	OverworldRules.normalize_overworld_state(session)
	return selected_id

func _reserve_hero_state(hero_id: String, position: Vector2i, movement_points: int) -> Dictionary:
	var template := ContentService.get_hero(hero_id)
	return {
		"id": hero_id,
		"name": String(template.get("name", hero_id)),
		"faction_id": String(template.get("faction_id", "")),
		"archetype": String(template.get("archetype", "")),
		"roster_summary": String(template.get("roster_summary", "")),
		"is_primary": false,
		"position": {"x": position.x, "y": position.y},
		"movement": {"current": movement_points, "max": movement_points},
		"base_movement": movement_points,
		"level": 1,
		"experience": 0,
		"specialties": [],
		"army": {"id": "%s_army" % hero_id, "name": "Reserve Army", "stacks": []},
		"command": template.get("command", {}).duplicate(true) if template.get("command", {}) is Dictionary else {},
	}

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

func _hero_action_count(snapshot: Dictionary) -> int:
	var surfaces: Array = snapshot.get("hero_action_surfaces", []) if snapshot.get("hero_action_surfaces", []) is Array else []
	return surfaces.size()

func _hero_action_present(snapshot: Dictionary, hero_id: String) -> bool:
	var hero_name := String(ContentService.get_hero(hero_id).get("name", hero_id))
	for surface in _hero_action_surfaces(snapshot):
		if String(surface.get("text", "")).contains(hero_name):
			return true
	return false

func _hero_action_disabled_for(snapshot: Dictionary, hero_id: String) -> bool:
	var hero_name := String(ContentService.get_hero(hero_id).get("name", hero_id))
	for surface in _hero_action_surfaces(snapshot):
		if String(surface.get("text", "")).contains(hero_name):
			return bool(surface.get("disabled", false))
	return false

func _hero_action_surfaces(snapshot: Dictionary) -> Array:
	return snapshot.get("hero_action_surfaces", []) if snapshot.get("hero_action_surfaces", []) is Array else []

func _fail(message: String, context: Variant = {}) -> void:
	push_error("%s: %s %s" % [REPORT_ID, message, JSON.stringify(context)])
	get_tree().quit(1)
