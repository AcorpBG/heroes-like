extends Node

const REPORT_ID := "AI_HERO_TASK_SPAWN_COMMANDER_SELECTION_REPORT"
const RIVER_PASS := "river-pass"
const MIRECLAW := "faction_mireclaw"

var _failed := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var saved_task_case := _saved_task_commander_beats_rotation_case()
	if saved_task_case.is_empty():
		return
	var fallback_case := _fallback_and_unavailable_actor_case()
	if fallback_case.is_empty():
		return
	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"schema_status": "spawn_prefers_deployable_saved_task_commander",
		"behavior_policy": "saved_tasks_influence_live_commander_deployment",
		"save_policy": "hero_task_state_live_persist_no_save_migration",
		"cases": [saved_task_case, fallback_case],
		"save_version_before": int(SessionStateStore.SAVE_VERSION),
		"save_version_after": int(SessionStateStore.SAVE_VERSION),
	}
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _saved_task_commander_beats_rotation_case() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config()
	var state := _enemy_state(session)
	state["raid_counter"] = 0
	state["commander_counter"] = 1
	_set_resource_controller(session, "river_free_company", "player")
	_seed_task_board(session, [_task("hero_tarn", "river_free_company", 10, "planned", "valid")])
	_update_enemy_state(session, state)

	var spawn_point := {"x": 7, "y": 1}
	var rotation_pick := EnemyAdventureRules.select_raid_commander_roster_hero_id(
		session,
		MIRECLAW,
		1,
		{},
		state.get("commander_roster", [])
	)
	if rotation_pick != "hero_sable":
		_fail("Fixture expected normal rotation to start with hero_sable, got %s" % rotation_pick)
		return {}
	var spawn_pick := EnemyAdventureRules.select_raid_commander_roster_hero_id_for_spawn(
		session,
		MIRECLAW,
		spawn_point,
		1,
		{},
		state.get("commander_roster", [])
	)
	if spawn_pick != "hero_tarn":
		_fail("Saved-task spawn selection expected hero_tarn, got %s" % spawn_pick)
		return {}
	var spawn_result := EnemyTurnRules._spawn_raid(session, config, state)
	if not bool(spawn_result.get("ok", false)):
		_fail("Spawn result failed: %s" % JSON.stringify(spawn_result))
		return {}
	var raid := _latest_raid(session)
	var commander_id := String(raid.get("enemy_commander_state", {}).get("roster_hero_id", ""))
	if commander_id != "hero_tarn":
		_fail("Spawned raid did not deploy saved-task commander hero_tarn: %s" % JSON.stringify(raid))
		return {}
	if String(raid.get("target_kind", "")) != "resource" or String(raid.get("target_placement_id", "")) != "river_free_company":
		_fail("Spawned saved-task commander did not reuse river_free_company: %s" % JSON.stringify(raid))
		return {}
	var reason_codes := _string_array(raid.get("target_reason_codes", []))
	if "saved_hero_task" not in reason_codes:
		_fail("Spawned saved-task raid is missing saved_hero_task reason: %s" % JSON.stringify(raid))
		return {}
	_assert_task_status(session, "hero_tarn", "active", "river_free_company")
	if _failed:
		return {}
	var public_log := EnemyAdventureRules.ai_public_event_log_boundary_report(spawn_result.get("events", []), 2)
	if not bool(public_log.get("ok", false)):
		_fail("Spawn assignment public event boundary failed: %s" % JSON.stringify(public_log))
		return {}
	return {
		"case_id": "spawn_prefers_tarn_saved_task_over_sable_rotation",
		"rotation_pick": rotation_pick,
		"spawn_pick": spawn_pick,
		"spawned_commander_id": commander_id,
		"target_id": String(raid.get("target_placement_id", "")),
		"reason_codes": reason_codes,
		"public_event_count": int(public_log.get("public_event_count", 0)),
		"save_version": int(SessionStateStore.SAVE_VERSION),
	}

func _fallback_and_unavailable_actor_case() -> Dictionary:
	var session = _base_session()
	var state := _enemy_state(session)
	state["commander_counter"] = 1
	_set_resource_controller(session, "river_signal_post", "player")
	_seed_task_board(session, [_task("hero_sable", "river_signal_post", 10, "planned", "valid")])
	_set_commander_recovering(session, "hero_sable", 8)
	state = _enemy_state(session)
	var spawn_point := {"x": 7, "y": 1}
	var spawn_pick := EnemyAdventureRules.select_raid_commander_roster_hero_id_for_spawn(
		session,
		MIRECLAW,
		spawn_point,
		1,
		{},
		state.get("commander_roster", [])
	)
	var fallback_pick := EnemyAdventureRules.select_raid_commander_roster_hero_id(
		session,
		MIRECLAW,
		1,
		{},
		state.get("commander_roster", [])
	)
	if spawn_pick != fallback_pick:
		_fail("Unavailable saved-task actor should fall back to normal deployable rotation: spawn=%s fallback=%s" % [spawn_pick, fallback_pick])
		return {}
	if spawn_pick == "hero_sable":
		_fail("Recovering commander with saved task was incorrectly selected for spawn.")
		return {}
	return {
		"case_id": "recovering_saved_task_actor_does_not_override_rotation",
		"recovering_actor_id": "hero_sable",
		"spawn_pick": spawn_pick,
		"fallback_pick": fallback_pick,
		"save_version": int(SessionStateStore.SAVE_VERSION),
	}

func _seed_task_board(session, tasks: Array) -> void:
	var state := _enemy_state(session)
	state["hero_task_state"] = {
		"schema_version": 1,
		"planner_epoch": 7,
		"tasks": tasks,
	}
	_update_enemy_state(session, state)

func _task(actor_id: String, target_id: String, expires_day: int, status: String, validation: String) -> Dictionary:
	return {
		"task_id": "task:spawn_selection:%s:%s" % [actor_id, target_id],
		"owner_faction_id": MIRECLAW,
		"actor_kind": "commander_roster",
		"actor_id": actor_id,
		"source_kind": "saved_task_state",
		"source_id": "spawn_selection_fixture",
		"task_class": "contest_site",
		"task_status": status,
		"target_kind": "resource",
		"target_id": target_id,
		"front_id": "resource:%s" % target_id,
		"origin_kind": "town",
		"origin_id": "duskfen_bastion",
		"priority_reason_codes": ["spawn_selection_fixture"],
		"assigned_day": 3,
		"expires_day": expires_day,
		"continuity_policy": "persist_until_invalid",
		"route_policy": "derive_route_on_turn",
		"last_validation": validation,
		"reservation": {
			"reservation_status": "primary",
			"reservation_scope": "exclusive_target",
			"reservation_key": "resource:%s" % target_id,
		},
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

func _set_commander_recovering(session, actor_id: String, recovery_day: int) -> void:
	var state := _enemy_state(session)
	var roster: Array = state.get("commander_roster", []) if state.get("commander_roster", []) is Array else []
	for index in range(roster.size()):
		var entry = roster[index]
		if entry is Dictionary and String(entry.get("roster_hero_id", "")) == actor_id:
			entry["status"] = "recovering"
			entry["recovery_day"] = recovery_day
			roster[index] = entry
			state["commander_roster"] = roster
			_update_enemy_state(session, state)
			return
	_fail("Missing commander %s for recovery fixture." % actor_id)

func _latest_raid(session) -> Dictionary:
	var encounters: Array = session.overworld.get("encounters", [])
	for index in range(encounters.size() - 1, -1, -1):
		var encounter = encounters[index]
		if encounter is Dictionary and String(encounter.get("spawned_by_faction_id", "")) == MIRECLAW:
			return encounter
	_fail("No spawned Mireclaw raid found.")
	return {}

func _assert_task_status(session, actor_id: String, expected_status: String, expected_target_id: String) -> void:
	var state := _enemy_state(session)
	var task_state: Dictionary = state.get("hero_task_state", {}) if state.get("hero_task_state", {}) is Dictionary else {}
	var tasks: Array = task_state.get("tasks", []) if task_state.get("tasks", []) is Array else []
	for task_value in tasks:
		if not (task_value is Dictionary):
			continue
		var task: Dictionary = task_value
		if String(task.get("actor_id", "")) != actor_id:
			continue
		if String(task.get("task_status", "")) != expected_status or String(task.get("target_id", "")) != expected_target_id:
			_fail("Task %s expected %s/%s, got %s" % [actor_id, expected_status, expected_target_id, JSON.stringify(task)])
		return
	_fail("Missing task for %s in %s" % [actor_id, JSON.stringify(task_state)])

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
