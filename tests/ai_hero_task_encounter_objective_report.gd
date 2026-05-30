extends Node

const REPORT_ID := "AI_HERO_TASK_ENCOUNTER_OBJECTIVE_REPORT"
const SCENARIO_ID := "causeway-stand"
const MIRECLAW := "faction_mireclaw"
const OBJECTIVE_ENCOUNTER_ID := "causeway_levee_cutters"

var _failed := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var case_report := _encounter_objective_task_board_case()
	if case_report.is_empty():
		return
	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"schema_status": "encounter_objective_tasks_are_durable",
		"behavior_policy": "objective_front_encounters_use_saved_task_continuity",
		"save_policy": "hero_task_state_live_persist_no_save_migration",
		"case": case_report,
		"save_version_before": int(SessionStateStore.SAVE_VERSION),
		"save_version_after": int(SessionStateStore.SAVE_VERSION),
	}
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _encounter_objective_task_board_case() -> Dictionary:
	var session = _base_session()
	session.day = 2
	var config := _enemy_config()
	_seed_task_board(session, [_task("hero_tarn", "missing_objective_encounter", "active", "valid")])
	var encounter := _encounter(session, OBJECTIVE_ENCOUNTER_ID)
	if encounter.is_empty():
		return {}
	var raid := _raid_seed(session, "hero_vaska", "encounter_objective_task_vaska", {"x": 8, "y": 4})
	raid["target_kind"] = "encounter"
	raid["target_placement_id"] = OBJECTIVE_ENCOUNTER_ID
	raid["target_label"] = _encounter_label(encounter)
	raid["target_x"] = int(encounter.get("x", 0))
	raid["target_y"] = int(encounter.get("y", 0))
	raid["goal_x"] = int(encounter.get("x", 0))
	raid["goal_y"] = int(encounter.get("y", 0))
	raid["target_reason_codes"] = ["site_contested", "objective_front", "encounter_objective_task_fixture"]
	raid["target_public_reason"] = "objective front"
	raid["target_public_importance"] = "high"
	raid["target_debug_reason"] = "encounter objective task-board fixture"

	var assigned_raid := EnemyAdventureRules.assign_target(session, config, raid)
	if String(assigned_raid.get("target_kind", "")) != "encounter" or String(assigned_raid.get("target_placement_id", "")) != OBJECTIVE_ENCOUNTER_ID:
		_fail("Encounter objective assignment did not keep the target: %s" % JSON.stringify(assigned_raid))
		return {}
	_assert_task_status(session, "hero_vaska", "encounter", OBJECTIVE_ENCOUNTER_ID, "active", "valid")
	if _failed:
		return {}

	EnemyTurnRules.normalize_enemy_states(session)
	_assert_task_status(session, "hero_vaska", "encounter", OBJECTIVE_ENCOUNTER_ID, "active", "valid")
	if _failed:
		return {}

	var saved_plan_raid := _raid_seed(session, "hero_vaska", "encounter_objective_reuse_vaska", {"x": 8, "y": 4})
	var saved_plan := EnemyAdventureRules.ai_hero_task_saved_target_selection_plan(session, config, saved_plan_raid)
	if String(saved_plan.get("target_kind", "")) != "encounter" or String(saved_plan.get("target_placement_id", "")) != OBJECTIVE_ENCOUNTER_ID:
		_fail("Saved encounter task was not reused: %s" % JSON.stringify(saved_plan))
		return {}
	var reason_codes := _string_array(saved_plan.get("target_reason_codes", []))
	if "saved_hero_task" not in reason_codes:
		_fail("Saved encounter plan is missing saved_hero_task reason: %s" % JSON.stringify(saved_plan))
		return {}
	_assert_task_status(session, "hero_tarn", "encounter", "missing_objective_encounter", "invalid", "invalid_target_missing")
	if _failed:
		return {}

	var state := _enemy_state(session)
	var contest_result := EnemyAdventureRules._contest_encounter_target(session, assigned_raid, state, MIRECLAW)
	if contest_result.is_empty():
		_fail("Encounter contest returned no result.")
		return {}
	_assert_task_status(session, "hero_vaska", "encounter", OBJECTIVE_ENCOUNTER_ID, "completed", "valid")
	if _failed:
		return {}
	if OBJECTIVE_ENCOUNTER_ID not in _string_array(session.overworld.get("resolved_encounters", [])):
		_fail("Resolved encounter list did not include %s after contest." % OBJECTIVE_ENCOUNTER_ID)
		return {}
	EnemyTurnRules.normalize_enemy_states(session)
	_assert_task_status(session, "hero_vaska", "encounter", OBJECTIVE_ENCOUNTER_ID, "completed", "valid")
	if _failed:
		return {}

	var final_task_state := _task_state(session)
	return {
		"case_id": "objective_front_encounter_assigns_reuses_and_closes_task",
		"target_kind": String(saved_plan.get("target_kind", "")),
		"target_id": String(saved_plan.get("target_placement_id", "")),
		"reason_codes": reason_codes,
		"resolved_encounter_id": OBJECTIVE_ENCOUNTER_ID,
		"task_status_counts": _task_status_counts(final_task_state),
		"save_version": int(SessionStateStore.SAVE_VERSION),
	}

func _seed_task_board(session, tasks: Array) -> void:
	var state := _enemy_state(session)
	state["hero_task_state"] = {
		"schema_version": 1,
		"planner_epoch": 11,
		"tasks": tasks,
	}
	_update_enemy_state(session, state)

func _task(actor_id: String, target_id: String, status: String, validation: String) -> Dictionary:
	return {
		"task_id": "task:encounter_objective:%s:%s" % [actor_id, target_id],
		"owner_faction_id": MIRECLAW,
		"actor_kind": "commander_roster",
		"actor_id": actor_id,
		"source_kind": "saved_task_state",
		"source_id": "encounter_objective_fixture",
		"task_class": "contest_site",
		"task_status": status,
		"target_kind": "encounter",
		"target_id": target_id,
		"front_id": "encounter:%s" % target_id,
		"origin_kind": "encounter",
		"origin_id": "encounter_objective_fixture",
		"priority_reason_codes": ["site_contested", "objective_front", "encounter_objective_task_fixture"],
		"assigned_day": 2,
		"expires_day": 9,
		"continuity_policy": "persist_until_invalid",
		"route_policy": "derive_route_on_turn",
		"last_validation": validation,
		"reservation": {
			"reservation_status": "primary",
			"reservation_scope": "exclusive_target",
			"reservation_key": "encounter:%s" % target_id,
		},
	}

func _raid_seed(session, roster_hero_id: String, placement_id: String, origin: Dictionary) -> Dictionary:
	var raid := {
		"placement_id": placement_id,
		"encounter_id": "encounter_mire_raid",
		"x": int(origin.get("x", 0)),
		"y": int(origin.get("y", 0)),
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
	var session = ScenarioFactory.create_session(SCENARIO_ID, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	OverworldRules.refresh_fog_of_war(session)
	EnemyTurnRules.normalize_enemy_states(session)
	EnemyAdventureRules.normalize_all_commander_rosters(session)
	return session

func _enemy_config() -> Dictionary:
	var scenario := ContentService.get_scenario(SCENARIO_ID)
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

func _encounter(session, placement_id: String) -> Dictionary:
	for encounter in session.overworld.get("encounters", []):
		if encounter is Dictionary and String(encounter.get("placement_id", "")) == placement_id:
			return encounter
	_fail("Could not find encounter placement %s" % placement_id)
	return {}

func _encounter_label(encounter: Dictionary) -> String:
	return String(ContentService.get_encounter(String(encounter.get("encounter_id", encounter.get("id", "")))).get("name", OBJECTIVE_ENCOUNTER_ID))

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
