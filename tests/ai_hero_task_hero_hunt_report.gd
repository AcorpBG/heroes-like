extends Node

const REPORT_ID := "AI_HERO_TASK_HERO_HUNT_REPORT"
const RIVER_PASS := "river-pass"
const MIRECLAW := "faction_mireclaw"
const MISSING_HERO_ID := "missing_player_hero"

var _failed := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var case_report := _hero_hunt_task_board_case()
	if case_report.is_empty():
		return
	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"schema_status": "hero_hunt_tasks_are_durable",
		"behavior_policy": "hero_targets_use_saved_task_continuity",
		"save_policy": "hero_task_state_live_persist_no_save_migration",
		"case": case_report,
		"save_version_before": int(SessionStateStore.SAVE_VERSION),
		"save_version_after": int(SessionStateStore.SAVE_VERSION),
	}
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _hero_hunt_task_board_case() -> Dictionary:
	var session = _base_session()
	session.day = 2
	var config := _enemy_config()
	var hero_id := String(session.overworld.get("active_hero_id", ""))
	if hero_id == "":
		_fail("River Pass has no active hero id.")
		return {}
	var first_tile := _nearest_open_non_town_tile(session, Vector2i(8, 4))
	var second_tile := _nearest_open_non_town_tile_excluding(session, Vector2i(first_tile.x + 1, first_tile.y), first_tile)
	_move_player_hero(session, hero_id, first_tile)
	_seed_task_board(session, [_task("hero_tarn", MISSING_HERO_ID, "active", "valid")])

	var raid := _raid_seed(session, "hero_vaska", "hero_hunt_task_vaska", first_tile)
	raid["target_kind"] = "hero"
	raid["target_placement_id"] = hero_id
	raid["target_label"] = _hero_name(session, hero_id)
	raid["target_x"] = first_tile.x
	raid["target_y"] = first_tile.y
	raid["goal_x"] = first_tile.x
	raid["goal_y"] = first_tile.y
	raid["target_reason_codes"] = ["hero_hunt", "exposed_hero", "hero_hunt_task_fixture"]
	raid["target_public_reason"] = "exposed hero"
	raid["target_public_importance"] = "high"
	raid["target_debug_reason"] = "hero hunt task-board fixture"

	var assigned_raid := EnemyAdventureRules.assign_target(session, config, raid)
	if String(assigned_raid.get("target_kind", "")) != "hero" or String(assigned_raid.get("target_placement_id", "")) != hero_id:
		_fail("Hero hunt assignment did not keep the target: %s" % JSON.stringify(assigned_raid))
		return {}
	_assert_task_status(session, "hero_vaska", "hero", hero_id, "active", "valid")
	if _failed:
		return {}

	EnemyTurnRules.normalize_enemy_states(session)
	_assert_task_status(session, "hero_vaska", "hero", hero_id, "active", "valid")
	if _failed:
		return {}

	_move_player_hero(session, hero_id, second_tile)
	var saved_plan_raid := _raid_seed(session, "hero_vaska", "hero_hunt_reuse_vaska", second_tile)
	var saved_plan := EnemyAdventureRules.ai_hero_task_saved_target_selection_plan(session, config, saved_plan_raid)
	if String(saved_plan.get("target_kind", "")) != "hero" or String(saved_plan.get("target_placement_id", "")) != hero_id:
		_fail("Saved hero hunt task was not reused: %s" % JSON.stringify(saved_plan))
		return {}
	if int(saved_plan.get("target_x", -1)) != second_tile.x or int(saved_plan.get("target_y", -1)) != second_tile.y:
		_fail("Saved hero hunt plan did not follow moved hero: %s expected %s" % [JSON.stringify(saved_plan), str(second_tile)])
		return {}
	var reason_codes := _string_array(saved_plan.get("target_reason_codes", []))
	if "saved_hero_task" not in reason_codes:
		_fail("Saved hero hunt plan is missing saved_hero_task reason: %s" % JSON.stringify(saved_plan))
		return {}
	_assert_task_status(session, "hero_tarn", "hero", MISSING_HERO_ID, "invalid", "invalid_target_missing")
	if _failed:
		return {}

	assigned_raid["x"] = second_tile.x
	assigned_raid["y"] = second_tile.y
	assigned_raid["target_x"] = second_tile.x
	assigned_raid["target_y"] = second_tile.y
	assigned_raid["goal_x"] = second_tile.x
	assigned_raid["goal_y"] = second_tile.y
	assigned_raid["goal_distance"] = 0
	assigned_raid["arrived"] = true
	_remove_mireclaw_hero_hunt_encounters(session)
	_append_encounter(session, assigned_raid)
	var intercept_result := EnemyTurnRules._queue_hero_intercept_battle(session, config, MIRECLAW)
	if not bool(intercept_result.get("battle_started", false)):
		_fail("Hero hunt intercept did not queue battle: %s" % JSON.stringify(intercept_result))
		return {}
	var battle_context: Dictionary = session.battle.get("context", {}) if session.battle.get("context", {}) is Dictionary else {}
	if String(battle_context.get("type", "")) != "hero_intercept" or String(battle_context.get("target_hero_id", "")) != hero_id:
		_fail("Hero hunt queued wrong battle context: %s" % JSON.stringify(battle_context))
		return {}
	_assert_task_status(session, "hero_vaska", "hero", hero_id, "completed", "valid")
	if _failed:
		return {}
	EnemyTurnRules.normalize_enemy_states(session)
	_assert_task_status(session, "hero_vaska", "hero", hero_id, "completed", "valid")
	if _failed:
		return {}

	var final_task_state := _task_state(session)
	return {
		"case_id": "hero_hunt_assigns_reuses_follows_and_closes_task",
		"target_kind": String(saved_plan.get("target_kind", "")),
		"target_id": String(saved_plan.get("target_placement_id", "")),
		"reason_codes": reason_codes,
		"first_target": {"x": first_tile.x, "y": first_tile.y},
		"moved_target": {"x": second_tile.x, "y": second_tile.y},
		"battle_context_type": String(battle_context.get("type", "")),
		"task_status_counts": _task_status_counts(final_task_state),
		"save_version": int(SessionStateStore.SAVE_VERSION),
	}

func _seed_task_board(session, tasks: Array) -> void:
	var state := _enemy_state(session)
	state["hero_task_state"] = {
		"schema_version": 1,
		"planner_epoch": 13,
		"tasks": tasks,
	}
	_update_enemy_state(session, state)

func _task(actor_id: String, target_id: String, status: String, validation: String) -> Dictionary:
	return {
		"task_id": "task:hero_hunt:%s:%s" % [actor_id, target_id],
		"owner_faction_id": MIRECLAW,
		"actor_kind": "commander_roster",
		"actor_id": actor_id,
		"source_kind": "saved_task_state",
		"source_id": "hero_hunt_fixture",
		"task_class": "contest_site",
		"task_status": status,
		"target_kind": "hero",
		"target_id": target_id,
		"front_id": "hero:%s" % target_id,
		"origin_kind": "encounter",
		"origin_id": "hero_hunt_fixture",
		"priority_reason_codes": ["hero_hunt", "exposed_hero", "hero_hunt_task_fixture"],
		"assigned_day": 2,
		"expires_day": 9,
		"continuity_policy": "persist_until_invalid",
		"route_policy": "derive_route_on_turn",
		"last_validation": validation,
		"reservation": {
			"reservation_status": "primary",
			"reservation_scope": "exclusive_target",
			"reservation_key": "hero:%s" % target_id,
		},
	}

func _raid_seed(session, roster_hero_id: String, placement_id: String, origin: Vector2i) -> Dictionary:
	var raid := {
		"placement_id": placement_id,
		"encounter_id": "encounter_mire_raid",
		"x": origin.x,
		"y": origin.y,
		"difficulty": "pressure",
		"combat_seed": hash("%s:%s" % [String(session.scenario_id), placement_id]),
		"spawned_by_faction_id": MIRECLAW,
		"days_active": 0,
		"arrived": false,
		"goal_distance": 9999,
	}
	raid["enemy_commander_state"] = EnemyAdventureRules.build_raid_commander_state(
		raid,
		roster_hero_id,
		MIRECLAW,
		session,
		{},
		EnemyAdventureRules.commander_roster_for_faction(session, MIRECLAW)
	)
	return EnemyAdventureRules.ensure_raid_army(raid, session)

func _base_session():
	var session = ScenarioFactory.create_session(RIVER_PASS, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	OverworldRules.refresh_fog_of_war(session)
	EnemyTurnRules.normalize_enemy_states(session)
	EnemyAdventureRules.normalize_all_commander_rosters(session)
	return session

func _enemy_config() -> Dictionary:
	var scenario := ContentService.get_scenario(RIVER_PASS)
	for config in scenario.get("enemy_factions", []):
		if config is Dictionary and String(config.get("faction_id", "")) == MIRECLAW:
			return config
	_fail("Could not find enemy config for %s" % MIRECLAW)
	return {}

func _enemy_state(session) -> Dictionary:
	for state in session.overworld.get("enemy_states", []):
		if state is Dictionary and String(state.get("faction_id", "")) == MIRECLAW:
			return state
	_fail("Could not find enemy state for %s" % MIRECLAW)
	return {}

func _update_enemy_state(session, replacement: Dictionary) -> void:
	var states: Array = session.overworld.get("enemy_states", [])
	for index in range(states.size()):
		var state = states[index]
		if state is Dictionary and String(state.get("faction_id", "")) == String(replacement.get("faction_id", "")):
			states[index] = replacement
			session.overworld["enemy_states"] = states
			return
	_fail("Could not update enemy state for %s" % String(replacement.get("faction_id", "")))

func _task_state(session) -> Dictionary:
	var state := _enemy_state(session)
	return state.get("hero_task_state", {}) if state.get("hero_task_state", {}) is Dictionary else {}

func _assert_task_status(session, actor_id: String, target_kind: String, target_id: String, expected_status: String, expected_validation: String) -> void:
	var task_state := _task_state(session)
	var tasks: Array = task_state.get("tasks", []) if task_state.get("tasks", []) is Array else []
	for task in tasks:
		if not (task is Dictionary):
			continue
		if String(task.get("actor_id", "")) == actor_id and String(task.get("target_kind", "")) == target_kind and String(task.get("target_id", "")) == target_id:
			if String(task.get("task_status", "")) != expected_status or String(task.get("last_validation", "")) != expected_validation:
				_fail("Task %s/%s/%s expected %s/%s, got %s" % [actor_id, target_kind, target_id, expected_status, expected_validation, JSON.stringify(task)])
			return
	_fail("Missing task %s/%s/%s in %s" % [actor_id, target_kind, target_id, JSON.stringify(task_state)])

func _move_player_hero(session, hero_id: String, tile: Vector2i) -> void:
	var heroes: Array = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		var hero = heroes[index]
		if not (hero is Dictionary) or String(hero.get("id", "")) != hero_id:
			continue
		hero["position"] = {"x": tile.x, "y": tile.y}
		heroes[index] = hero
		session.overworld["player_heroes"] = heroes
		if String(session.overworld.get("active_hero_id", "")) == hero_id:
			session.overworld["hero"] = hero.duplicate(true)
			session.overworld["hero_position"] = {"x": tile.x, "y": tile.y}
			session.overworld["army"] = hero.get("army", {}).duplicate(true) if hero.get("army", {}) is Dictionary else {}
		return
	_fail("Could not move player hero %s." % hero_id)

func _hero_name(session, hero_id: String) -> String:
	for hero in session.overworld.get("player_heroes", []):
		if hero is Dictionary and String(hero.get("id", "")) == hero_id:
			return String(hero.get("name", hero_id))
	return hero_id

func _nearest_open_non_town_tile(session, preferred: Vector2i) -> Vector2i:
	return _nearest_open_non_town_tile_excluding(session, preferred, Vector2i(-1, -1))

func _nearest_open_non_town_tile_excluding(session, preferred: Vector2i, excluded: Vector2i) -> Vector2i:
	var map_size: Vector2i = OverworldRules.derive_map_size(session)
	for radius in range(0, max(map_size.x, map_size.y)):
		for y in range(max(0, preferred.y - radius), min(map_size.y, preferred.y + radius + 1)):
			for x in range(max(0, preferred.x - radius), min(map_size.x, preferred.x + radius + 1)):
				var tile := Vector2i(x, y)
				if tile == excluded:
					continue
				if abs(tile.x - preferred.x) + abs(tile.y - preferred.y) > radius:
					continue
				if OverworldRules.tile_is_blocked(session, tile.x, tile.y):
					continue
				if _player_town_at(session, tile):
					continue
				return tile
	_fail("Could not find open non-town tile near %s." % str(preferred))
	return preferred

func _player_town_at(session, tile: Vector2i) -> bool:
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("owner", "neutral")) == "player":
			if int(town.get("x", -1)) == tile.x and int(town.get("y", -1)) == tile.y:
				return true
	return false

func _append_encounter(session, encounter: Dictionary) -> void:
	var encounters: Array = session.overworld.get("encounters", [])
	encounters.append(encounter.duplicate(true))
	session.overworld["encounters"] = encounters

func _remove_mireclaw_hero_hunt_encounters(session) -> void:
	var kept := []
	for encounter in session.overworld.get("encounters", []):
		if not (encounter is Dictionary):
			continue
		if String(encounter.get("spawned_by_faction_id", "")) == MIRECLAW and String(encounter.get("target_kind", "")) == "hero":
			continue
		kept.append(encounter)
	session.overworld["encounters"] = kept

func _task_status_counts(task_state: Dictionary) -> Dictionary:
	var counts := {}
	var tasks: Array = task_state.get("tasks", []) if task_state.get("tasks", []) is Array else []
	for task in tasks:
		if task is Dictionary:
			var status := String(task.get("task_status", ""))
			counts[status] = int(counts.get(status, 0)) + 1
	return counts

func _string_array(value: Variant) -> Array:
	var output := []
	if not (value is Array):
		return output
	for item in value:
		var text := String(item)
		if text != "" and text not in output:
			output.append(text)
	return output

func _fail(message: String) -> void:
	var payload := {"ok": false, "report_id": REPORT_ID, "error": message}
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	_failed = true
	get_tree().quit(1)
