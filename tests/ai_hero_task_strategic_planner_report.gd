extends Node

const REPORT_ID := "AI_HERO_TASK_STRATEGIC_PLANNER_REPORT"
const RIVER_PASS := "river-pass"
const MIRECLAW := "faction_mireclaw"

var _failed := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var planner_case := _planner_seeds_distinct_tasks_before_spawn()
	if planner_case.is_empty():
		return
	var multi_origin_case := _planner_uses_local_origin_for_remote_front()
	if multi_origin_case.is_empty():
		return
	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"schema_status": "coordinated_task_planner_live_behavior",
		"behavior_policy": "enemy_turn_planner_seeds_distinct_commander_tasks_before_raid_spawn",
		"save_policy": "hero_task_state_live_persist_no_save_migration",
		"case": planner_case,
		"multi_origin_case": multi_origin_case,
		"save_version_before": int(SessionStateStore.SAVE_VERSION),
		"save_version_after": int(SessionStateStore.SAVE_VERSION),
	}
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _planner_seeds_distinct_tasks_before_spawn() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config()
	var state := _enemy_state(session)
	state["raid_counter"] = 0
	state["commander_counter"] = 0
	state["pressure"] = 0
	state.erase("hero_task_state")
	_update_enemy_state(session, state)
	_set_resource_controller(session, "river_free_company", "player")
	_set_resource_controller(session, "river_signal_post", "player")
	var active_raids_before := _active_raid_count(session)
	if active_raids_before != 0:
		_fail("Planner fixture expected no active raids before planning, got %d" % active_raids_before)
		return {}

	var plan_result := EnemyAdventureRules.plan_enemy_hero_task_board(session, config, state)
	if int(plan_result.get("planned_count", 0)) < 2:
		_fail("Planner should seed at least two distinct commander tasks, got %s" % JSON.stringify(plan_result))
		return {}
	var planned_state: Dictionary = plan_result.get("state", {})
	var planned_tasks := _planned_tasks(planned_state)
	_assert_distinct_planned_tasks(planned_tasks)
	if _failed:
		return {}
	_update_enemy_state(session, planned_state)

	var planned_keys := _task_keys(planned_tasks)
	var spawn_result := EnemyTurnRules._spawn_raid(session, config, planned_state)
	if not bool(spawn_result.get("ok", false)):
		_fail("Spawn from planned task board failed: %s" % JSON.stringify(spawn_result))
		return {}
	var raid := _latest_raid(session)
	var spawned_key := "%s:%s" % [String(raid.get("target_kind", "")), String(raid.get("target_placement_id", ""))]
	if spawned_key not in planned_keys:
		_fail("Spawned raid target %s was not one of the planned tasks %s: %s" % [spawned_key, JSON.stringify(planned_keys), JSON.stringify(raid)])
		return {}
	var commander_id := String(raid.get("enemy_commander_state", {}).get("roster_hero_id", ""))
	_assert_active_task(session, commander_id, String(raid.get("target_kind", "")), String(raid.get("target_placement_id", "")))
	if _failed:
		return {}
	return {
		"case_id": "river_pass_predeployment_planner_seeds_and_activates_distinct_tasks",
		"active_raids_before": active_raids_before,
		"planned_count": int(plan_result.get("planned_count", 0)),
		"planned_task_keys": planned_keys,
		"spawned_commander_id": commander_id,
		"spawned_target_key": spawned_key,
		"spawn_message": String(spawn_result.get("message", "")),
		"save_version": int(SessionStateStore.SAVE_VERSION),
	}

func _planner_uses_local_origin_for_remote_front() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config()
	var state := _enemy_state(session)
	state["raid_counter"] = 0
	state["commander_counter"] = 0
	state["pressure"] = 0
	state.erase("hero_task_state")
	_add_enemy_town(session, "north_mire_watch", "town_duskfen", 0, 0)
	_update_enemy_state(session, state)
	_set_resource_controller(session, "north_wood", "player")
	_set_resource_controller(session, "river_free_company", "player")
	_set_resource_controller(session, "river_signal_post", "player")
	var plan_result := EnemyAdventureRules.plan_enemy_hero_task_board(session, config, state)
	if int(plan_result.get("planned_count", 0)) < 2:
		_fail("Multi-origin planner should seed tasks, got %s" % JSON.stringify(plan_result))
		return {}
	var planned_state: Dictionary = plan_result.get("state", {})
	var north_task := _planned_task_for_target(planned_state, "resource", "north_wood")
	if north_task.is_empty():
		_fail("Multi-origin planner did not plan north_wood from local front: %s" % JSON.stringify(_task_keys(_planned_tasks(planned_state))))
		return {}
	if String(north_task.get("origin_id", "")) != "north_mire_watch":
		_fail("north_wood should use the local north_mire_watch origin, got %s" % JSON.stringify(north_task))
		return {}
	return {
		"case_id": "multi_origin_planner_uses_local_town_for_north_resource",
		"planned_count": int(plan_result.get("planned_count", 0)),
		"target_key": "resource:north_wood",
		"origin_id": String(north_task.get("origin_id", "")),
		"origin_x": int(north_task.get("origin_x", -1)),
		"origin_y": int(north_task.get("origin_y", -1)),
	}

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

func _add_enemy_town(session, placement_id: String, town_id: String, x: int, y: int) -> void:
	var towns: Array = session.overworld.get("towns", [])
	towns.append({
		"placement_id": placement_id,
		"town_id": town_id,
		"x": x,
		"y": y,
		"owner": "enemy",
	})
	session.overworld["towns"] = towns

func _update_enemy_state(session, replacement: Dictionary) -> void:
	var states: Array = session.overworld.get("enemy_states", [])
	for index in range(states.size()):
		var state = states[index]
		if state is Dictionary and String(state.get("faction_id", "")) == String(replacement.get("faction_id", "")):
			states[index] = replacement
			session.overworld["enemy_states"] = states
			return
	_fail("Could not update enemy state for %s" % String(replacement.get("faction_id", "")))

func _set_resource_controller(session, placement_id: String, faction_id: String) -> void:
	var nodes: Array = session.overworld.get("resource_nodes", [])
	for index in range(nodes.size()):
		var node = nodes[index]
		if not (node is Dictionary) or String(node.get("placement_id", "")) != placement_id:
			continue
		node["collected"] = true
		node["collected_by_faction_id"] = faction_id
		node["collected_day"] = max(1, int(session.day))
		nodes[index] = node
		session.overworld["resource_nodes"] = nodes
		return
	_fail("Could not find resource placement %s" % placement_id)

func _planned_tasks(state: Dictionary) -> Array:
	var task_state: Dictionary = state.get("hero_task_state", {}) if state.get("hero_task_state", {}) is Dictionary else {}
	var output := []
	for task_value in task_state.get("tasks", []):
		if task_value is Dictionary and String(task_value.get("task_status", "")) == "planned":
			output.append(task_value)
	return output

func _assert_distinct_planned_tasks(tasks: Array) -> void:
	if tasks.size() < 2:
		_fail("Expected at least two planned tasks, got %s" % JSON.stringify(tasks))
		return
	var actors := {}
	var targets := {}
	for task_value in tasks:
		var task: Dictionary = task_value
		var actor_id := String(task.get("actor_id", ""))
		var target_key := "%s:%s" % [String(task.get("target_kind", "")), String(task.get("target_id", ""))]
		if actor_id == "" or actors.has(actor_id):
			_fail("Planned tasks must use distinct non-empty actors: %s" % JSON.stringify(tasks))
			return
		if targets.has(target_key):
			_fail("Planned tasks must reserve distinct targets: %s" % JSON.stringify(tasks))
			return
		var reservation: Dictionary = task.get("reservation", {}) if task.get("reservation", {}) is Dictionary else {}
		if String(reservation.get("reservation_scope", "")) != "exclusive_target":
			_fail("Planned task must reserve its target exclusively: %s" % JSON.stringify(task))
			return
		if "strategic_task_planner" not in _string_array(task.get("priority_reason_codes", [])):
			_fail("Planned task missing strategic_task_planner reason: %s" % JSON.stringify(task))
			return
		actors[actor_id] = true
		targets[target_key] = true

func _task_keys(tasks: Array) -> Array:
	var keys := []
	for task_value in tasks:
		if task_value is Dictionary:
			keys.append("%s:%s" % [String(task_value.get("target_kind", "")), String(task_value.get("target_id", ""))])
	keys.sort()
	return keys

func _planned_task_for_target(state: Dictionary, target_kind: String, target_id: String) -> Dictionary:
	for task_value in _planned_tasks(state):
		if not (task_value is Dictionary):
			continue
		var task: Dictionary = task_value
		if String(task.get("target_kind", "")) == target_kind and String(task.get("target_id", "")) == target_id:
			return task
	return {}

func _assert_active_task(session, actor_id: String, target_kind: String, target_id: String) -> void:
	var state := _enemy_state(session)
	var task_state: Dictionary = state.get("hero_task_state", {}) if state.get("hero_task_state", {}) is Dictionary else {}
	for task_value in task_state.get("tasks", []):
		if not (task_value is Dictionary):
			continue
		var task: Dictionary = task_value
		if String(task.get("actor_id", "")) == actor_id \
				and String(task.get("target_kind", "")) == target_kind \
				and String(task.get("target_id", "")) == target_id \
				and String(task.get("task_status", "")) == "active":
			return
	_fail("Spawned commander task was not activated for %s/%s:%s in %s" % [actor_id, target_kind, target_id, JSON.stringify(task_state)])

func _latest_raid(session) -> Dictionary:
	var encounters: Array = session.overworld.get("encounters", [])
	for index in range(encounters.size() - 1, -1, -1):
		var encounter = encounters[index]
		if encounter is Dictionary and String(encounter.get("spawned_by_faction_id", "")) == MIRECLAW:
			return encounter
	_fail("No spawned Mireclaw raid found.")
	return {}

func _active_raid_count(session) -> int:
	var count := 0
	for encounter in session.overworld.get("encounters", []):
		if encounter is Dictionary and String(encounter.get("spawned_by_faction_id", "")) == MIRECLAW:
			count += 1
	return count

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
