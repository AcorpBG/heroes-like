extends Node

const REPORT_ID := "AI_RAID_MOVEMENT_PATH_PLAN_REUSE_REGRESSION"
const SCENARIO_ID := "river-pass"
const FACTION_ID := "faction_mireclaw"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures := []
	var path_cases := []
	path_cases.append(_open_goal_case(failures))
	path_cases.append(_blocked_goal_approach_case(failures))
	path_cases.append(_blocked_origin_exit_case(failures))
	path_cases.append(_multiple_goal_case(failures))
	path_cases.append(_unreachable_corner_case(failures))
	var cache_case := _goal_field_reuse_case(failures)
	var live_case := _live_three_step_raid_case(failures)
	var payload := {
		"ok": failures.is_empty(),
		"report_id": REPORT_ID,
		"path_cases": path_cases,
		"goal_field_reuse_case": cache_case,
		"live_raid_case": live_case,
	}
	if not failures.is_empty():
		payload["failures"] = failures
		push_error("%s failed" % REPORT_ID)
		print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
		get_tree().quit(1)
		return
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _open_goal_case(failures: Array) -> Dictionary:
	var session = _path_session(_filled_map(7, 5, "grass"))
	return _assert_path_case(
		failures,
		"open_goal",
		session,
		Vector2i(1, 2),
		[Vector2i(5, 2)],
		4,
		Vector2i(2, 2),
		3
	)

func _blocked_goal_approach_case(failures: Array) -> Dictionary:
	var map := _filled_map(6, 3, "grass")
	map[1][4] = "water"
	var session = _path_session(map)
	return _assert_path_case(
		failures,
		"blocked_goal_approach",
		session,
		Vector2i(1, 1),
		[Vector2i(4, 1)],
		3,
		Vector2i(2, 1),
		2
	)

func _multiple_goal_case(failures: Array) -> Dictionary:
	var session = _path_session(_filled_map(7, 6, "grass"))
	return _assert_path_case(
		failures,
		"multiple_goal",
		session,
		Vector2i(1, 2),
		[Vector2i(5, 2), Vector2i(1, 4)],
		2,
		Vector2i(1, 3),
		1
	)

func _blocked_origin_exit_case(failures: Array) -> Dictionary:
	var session = _path_session(_filled_map(6, 3, "grass"))
	session.overworld["map_objects"] = [{
		"placement_id": "occupied_origin_body",
		"x": 1,
		"y": 1,
		"blocking_body": true,
		"package_block_tiles": [{"x": 1, "y": 1, "level": 0}],
	}]
	return _assert_path_case(
		failures,
		"blocked_origin_exit",
		session,
		Vector2i(1, 1),
		[Vector2i(4, 1)],
		3,
		Vector2i(2, 1),
		2
	)

func _unreachable_corner_case(failures: Array) -> Dictionary:
	var map := _filled_map(3, 3, "water")
	map[0][0] = "grass"
	map[1][1] = "grass"
	map[2][2] = "grass"
	var session = _path_session(map)
	return _assert_path_case(
		failures,
		"unreachable_blocked_corner",
		session,
		Vector2i(0, 0),
		[Vector2i(1, 1)],
		9999,
		Vector2i(0, 0),
		9999
	)

func _assert_path_case(
	failures: Array,
	case_id: String,
	session,
	start: Vector2i,
	goals: Array,
	expected_distance: int,
	expected_step: Vector2i,
	expected_next_distance: int
) -> Dictionary:
	EnemyAdventureRules._path_distance_surface_cache.clear()
	var legacy_distance := EnemyAdventureRules._path_distance(session, start, goals, "", FACTION_ID)
	EnemyAdventureRules._path_distance_surface_cache.clear()
	var plan := EnemyAdventureRules._path_plan_toward(session, start, goals, "", FACTION_ID)
	var public_step := EnemyAdventureRules._next_step_toward(session, start, goals, "", FACTION_ID)
	if legacy_distance != expected_distance:
		failures.append("%s legacy distance changed: %d" % [case_id, legacy_distance])
	if int(plan.get("goal_distance", -1)) != expected_distance:
		failures.append("%s plan distance changed: %s" % [case_id, JSON.stringify(plan)])
	if plan.get("next_step", start) != expected_step or public_step != expected_step:
		failures.append("%s deterministic next step changed: %s" % [case_id, JSON.stringify(plan)])
	if int(plan.get("next_goal_distance", -1)) != expected_next_distance:
		failures.append("%s next distance changed: %s" % [case_id, JSON.stringify(plan)])
	return {
		"case_id": case_id,
		"goal_distance": int(plan.get("goal_distance", -1)),
		"next_step": _vector_payload(plan.get("next_step", start)),
		"next_goal_distance": int(plan.get("next_goal_distance", -1)),
		"goal_field_count": int(plan.get("goal_field_count", 0)),
	}

func _goal_field_reuse_case(failures: Array) -> Dictionary:
	var session = _path_session(_filled_map(12, 3, "grass"))
	var goals := [Vector2i(10, 1)]
	var current := Vector2i(1, 1)
	EnemyAdventureRules._path_distance_surface_cache.clear()
	var route := [_vector_payload(current)]
	for _step in range(3):
		var plan := EnemyAdventureRules._path_plan_toward(session, current, goals, "", FACTION_ID)
		current = plan.get("next_step", current)
		route.append(_vector_payload(current))
	var context := EnemyAdventureRules._path_distance_surface_context(session, "", FACTION_ID)
	var field_cache: Dictionary = context.get("distance_field_cache", {})
	var goal_index := EnemyAdventureRules._tile_index(goals[0], Vector2i(12, 3))
	if field_cache.size() != 1 or not field_cache.has(goal_index):
		failures.append("Goal-plan reuse loaded current-origin fields: %s" % JSON.stringify(field_cache.keys()))
	if current != Vector2i(4, 1):
		failures.append("Goal-plan reuse route changed: %s" % JSON.stringify(route))
	return {
		"case_id": "goal_origin_field_reused_across_steps",
		"route": route,
		"distance_field_count": field_cache.size(),
		"goal_field_index": goal_index,
	}

func _live_three_step_raid_case(failures: Array) -> Dictionary:
	var session = _path_session(_filled_map(12, 5, "grass"))
	session.day = 2
	session.overworld["towns"] = [{
		"placement_id": "path_plan_player_town",
		"name": "Path Plan Hold",
		"owner": "player",
		"x": 10,
		"y": 2,
		"garrison": [],
	}]
	var raid := {
		"placement_id": "path_plan_raid",
		"encounter_id": "encounter_mire_raid",
		"x": 1,
		"y": 2,
		"difficulty": "pressure",
		"combat_seed": 515151,
		"spawned_by_faction_id": FACTION_ID,
		"commanderless_support_column": true,
		"days_active": 0,
		"arrived": false,
		"target_kind": "town",
		"target_placement_id": "path_plan_player_town",
		"target_label": "Path Plan Hold",
		"target_x": 10,
		"target_y": 2,
		"goal_x": 9,
		"goal_y": 2,
		"goal_distance": 8,
		"target_reason_codes": ["town_siege"],
		"target_public_reason": "testing deterministic town pressure",
		"target_public_importance": "high",
		"enemy_army": {
			"id": "army_path_plan_raid",
			"name": "Path Plan Raid",
			"stacks": [{"unit_id": "unit_bog_brute", "count": 50}],
		},
	}
	session.overworld["encounters"] = [raid]
	var result := EnemyAdventureRules.advance_raids(
		session,
		_enemy_config(),
		FACTION_ID,
		{},
		{"profile_enabled": true, "profile_label": "path_plan_reuse_regression"}
	)
	var updated: Dictionary = session.overworld.get("encounters", [])[0]
	var movement_events := []
	for event_value in result.get("events", []):
		if event_value is Dictionary and String(event_value.get("event_type", "")) == "ai_raid_moved":
			movement_events.append(event_value)
	if Vector2i(int(updated.get("x", -1)), int(updated.get("y", -1))) != Vector2i(4, 2):
		failures.append("Live tactical-pressure raid did not take three deterministic steps: %s" % JSON.stringify(updated))
	if int(updated.get("goal_distance", -1)) != 5 or movement_events.size() != 1:
		failures.append("Live raid movement outcome changed: raid=%s events=%s" % [JSON.stringify(updated), JSON.stringify(movement_events)])
	return {
		"case_id": "live_three_step_raid_uses_shared_path_plan",
		"position": {"x": int(updated.get("x", -1)), "y": int(updated.get("y", -1))},
		"goal_distance": int(updated.get("goal_distance", -1)),
		"movement_event_count": movement_events.size(),
		"profile": result.get("profile", {}),
	}

func _path_session(map: Array):
	var session = ScenarioFactory.create_session(
		SCENARIO_ID,
		"normal",
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	session.overworld["map"] = map
	session.overworld["map_size"] = {"width": map[0].size(), "height": map.size()}
	for key in ["towns", "encounters", "map_objects", "resource_nodes", "artifact_nodes", "player_heroes"]:
		session.overworld[key] = []
	session.overworld["resolved_encounters"] = []
	session.overworld["hero"] = {}
	EnemyAdventureRules._path_distance_surface_cache.clear()
	return session

func _enemy_config() -> Dictionary:
	for config_value in ContentService.get_scenario(SCENARIO_ID).get("enemy_factions", []):
		if config_value is Dictionary and String(config_value.get("faction_id", "")) == FACTION_ID:
			return config_value
	return {"faction_id": FACTION_ID, "label": "Mireclaw"}

func _filled_map(width: int, height: int, terrain_id: String) -> Array:
	var map := []
	for _y in range(height):
		var row := []
		for _x in range(width):
			row.append(terrain_id)
		map.append(row)
	return map

func _vector_payload(value: Variant) -> Dictionary:
	var vector: Vector2i = value if value is Vector2i else Vector2i.ZERO
	return {"x": vector.x, "y": vector.y}
