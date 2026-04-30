extends Node

const SCENARIO_ID := "river-pass"
const DIFFICULTY_ID := "normal"
const REPORT_ID := "FOG_OF_WAR_HOMM_STYLE_REGRESSION"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var session = ScenarioFactory.create_session(
		SCENARIO_ID,
		DIFFICULTY_ID,
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	OverworldRules.normalize_overworld_state(session)
	SessionState.set_active_session(session)
	var start := OverworldRules.hero_position(session)
	var unexplored := _first_unexplored_tile(session)
	if unexplored.x < 0:
		_fail("Could not find an unexplored tile in the fixture.")
		return
	var before_fog := _fog_counts(session)
	if not _assert_visible_aliases_explored(session, before_fog, "initial"):
		return
	if OverworldRules.is_tile_visible(session, unexplored.x, unexplored.y) or OverworldRules.is_tile_explored(session, unexplored.x, unexplored.y):
		_fail("Unexplored tile was not hidden initially: tile=%s fog=%s" % [unexplored, before_fog])
		return

	_set_active_hero_position(session, _remote_tile_from(session, start))
	OverworldRules.refresh_fog_of_war(session)
	var after_remote_fog := _fog_counts(session)
	if not _assert_visible_aliases_explored(session, after_remote_fog, "after_remote_refresh"):
		return
	if int(after_remote_fog.get("explored_count", 0)) < int(before_fog.get("explored_count", 0)):
		_fail("Refresh after moving away shrank explored coverage: before=%s after=%s" % [before_fog, after_remote_fog])
		return
	if not OverworldRules.is_tile_visible(session, start.x, start.y) or not OverworldRules.is_tile_explored(session, start.x, start.y):
		_fail("Previously explored start tile did not remain visible after moving away.")
		return
	if OverworldRules.is_tile_visible(session, unexplored.x, unexplored.y) or OverworldRules.is_tile_explored(session, unexplored.x, unexplored.y):
		_fail("Unexplored tile became visible without entering a reveal radius: tile=%s" % unexplored)
		return

	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	var presentation: Dictionary = shell.call("validation_tile_presentation", start.x, start.y)
	var terrain_presentation: Dictionary = presentation.get("terrain_presentation", {})
	if not bool(presentation.get("explored", false)) or not bool(presentation.get("visible", false)):
		_fail("Renderer validation did not treat explored tile as visible: presentation=%s" % presentation)
		return
	if not bool(terrain_presentation.get("terrain_fully_visible", false)) or bool(terrain_presentation.get("unexplored_hidden", true)):
		_fail("Renderer validation did not keep explored terrain fully visible: presentation=%s" % presentation)
		return
	var hidden_presentation: Dictionary = shell.call("validation_tile_presentation", unexplored.x, unexplored.y)
	var hidden_terrain: Dictionary = hidden_presentation.get("terrain_presentation", {})
	if bool(hidden_presentation.get("visible", true)) or bool(hidden_presentation.get("explored", true)) or not bool(hidden_terrain.get("unexplored_hidden", false)):
		_fail("Renderer validation did not keep unexplored tile hidden: presentation=%s" % hidden_presentation)
		return

	var movement_session = ScenarioFactory.create_session(
		SCENARIO_ID,
		DIFFICULTY_ID,
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	OverworldRules.normalize_overworld_state(movement_session)
	var movement_before := _fog_counts(movement_session)
	var move_result := _try_one_step_move(movement_session)
	if not bool(move_result.get("ok", false)):
		_fail("One-step movement failed: result=%s" % move_result)
		return
	var movement_after := _fog_counts(movement_session)
	if not _assert_visible_aliases_explored(movement_session, movement_after, "after_try_move"):
		return
	if int(movement_after.get("explored_count", 0)) < int(movement_before.get("explored_count", 0)):
		_fail("try_move shrank explored coverage: before=%s after=%s result=%s" % [movement_before, movement_after, move_result])
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"fog_model": "homm_permanent_explored_visibility",
		"initial": before_fog,
		"after_remote_refresh": after_remote_fog,
		"after_try_move": movement_after,
		"unexplored_guard": {"x": unexplored.x, "y": unexplored.y},
	})])
	get_tree().quit(0)

func _assert_visible_aliases_explored(session, fog: Dictionary, label: String) -> bool:
	if int(fog.get("visible_count", 0)) != int(fog.get("explored_count", 0)):
		_fail("%s fog counts diverged: %s" % [label, fog])
		return false
	var map_size := OverworldRules.derive_map_size(session)
	for y in range(map_size.y):
		for x in range(map_size.x):
			if OverworldRules.is_tile_visible(session, x, y) != OverworldRules.is_tile_explored(session, x, y):
				_fail("%s visible/explored API diverged at %d,%d." % [label, x, y])
				return false
	return true

func _try_one_step_move(session) -> Dictionary:
	var start := OverworldRules.hero_position(session)
	var directions: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
	for direction in directions:
		var target := start + direction
		if target.x < 0 or target.y < 0:
			continue
		if OverworldRules.tile_is_blocked(session, target.x, target.y):
			continue
		var result: Dictionary = OverworldRules.try_move(session, direction.x, direction.y)
		if bool(result.get("ok", false)):
			return result
	return {"ok": false, "message": "No adjacent passable target."}

func _remote_tile_from(session, source: Vector2i) -> Vector2i:
	var map_size := OverworldRules.derive_map_size(session)
	var best := source
	var best_distance := -1
	for y in range(map_size.y):
		for x in range(map_size.x):
			if OverworldRules.tile_is_blocked(session, x, y):
				continue
			var distance: int = abs(source.x - x) + abs(source.y - y)
			if distance > best_distance:
				best = Vector2i(x, y)
				best_distance = distance
	return best

func _first_unexplored_tile(session) -> Vector2i:
	var map_size := OverworldRules.derive_map_size(session)
	for y in range(map_size.y):
		for x in range(map_size.x):
			if not OverworldRules.is_tile_explored(session, x, y):
				return Vector2i(x, y)
	return Vector2i(-1, -1)

func _set_active_hero_position(session, tile: Vector2i) -> void:
	var position := {"x": tile.x, "y": tile.y}
	session.overworld["hero_position"] = position.duplicate(true)
	var active_hero = session.overworld.get("hero", {})
	if active_hero is Dictionary:
		active_hero["position"] = position.duplicate(true)
		session.overworld["hero"] = active_hero
	var heroes = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		var hero = heroes[index]
		if hero is Dictionary and String(hero.get("id", "")) == String(session.overworld.get("active_hero_id", "")):
			hero["position"] = position.duplicate(true)
			heroes[index] = hero
	session.overworld["player_heroes"] = heroes

func _fog_counts(session) -> Dictionary:
	var fog: Dictionary = session.overworld.get("fog", {}) if session != null and session.overworld.get("fog", {}) is Dictionary else {}
	return {
		"visible_count": int(fog.get("visible_count", 0)),
		"explored_count": int(fog.get("explored_count", 0)),
		"total_tiles": int(fog.get("total_tiles", 0)),
	}

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
