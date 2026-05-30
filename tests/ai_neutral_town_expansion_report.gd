extends Node

const REPORT_ID := "AI_NEUTRAL_TOWN_EXPANSION_REPORT"
const RIVER_PASS := "river-pass"
const MIRECLAW := "faction_mireclaw"
const NEUTRAL_TOWN_ID := "mireford_neutral_hold"

var _failed := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var plan_case := _neutral_town_is_planned_expansion_target()
	if plan_case.is_empty():
		return
	var capture_case := _arrived_raid_captures_empty_neutral_town()
	if capture_case.is_empty():
		return
	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"schema_status": "live_neutral_town_expansion_no_save_migration",
		"behavior_policy": "ai_commanders_plan_and_capture_empty_neutral_towns",
		"plan_case": plan_case,
		"capture_case": capture_case,
		"save_version_before": int(SessionStateStore.SAVE_VERSION),
		"save_version_after": int(SessionStateStore.SAVE_VERSION),
	}
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _neutral_town_is_planned_expansion_target() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config()
	var state := _enemy_state(session)
	_prepare_neutral_town_only_front(session)
	var result := EnemyAdventureRules.plan_enemy_hero_task_board(session, config, state)
	var task := _task_for_target(session, "town", NEUTRAL_TOWN_ID)
	if task.is_empty():
		_fail("Planner did not create a neutral-town expansion task: %s" % JSON.stringify(result))
		return {}
	var reason_codes := _string_array(task.get("priority_reason_codes", []))
	if "town_expansion" not in reason_codes or "neutral_town_claim" not in reason_codes:
		_fail("Neutral-town expansion task missed reason codes: %s" % JSON.stringify(task))
		return {}
	if String(task.get("task_status", "")) != "planned":
		_fail("Neutral-town expansion task should be planned: %s" % JSON.stringify(task))
		return {}
	return {
		"case_id": "neutral_town_is_planned_expansion_target",
		"planned_count": int(result.get("planned_count", 0)),
		"task_id": String(task.get("task_id", "")),
		"task_status": String(task.get("task_status", "")),
		"target_kind": String(task.get("target_kind", "")),
		"target_id": String(task.get("target_id", "")),
		"reason_codes": reason_codes,
	}

func _arrived_raid_captures_empty_neutral_town() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config()
	var state := _enemy_state(session)
	_prepare_neutral_town_only_front(session)
	_seed_task_board(session, [_town_expansion_task("hero_vaska", NEUTRAL_TOWN_ID, "active", "valid")])
	var raid := _neutral_town_raid(session)
	var encounters: Array = session.overworld.get("encounters", [])
	encounters.append(raid)
	session.overworld["encounters"] = encounters
	var pressure_before := int(state.get("pressure", 0))

	var result := EnemyAdventureRules.advance_raids(session, config, MIRECLAW, state)
	var town := _town(session, NEUTRAL_TOWN_ID)
	if String(town.get("owner", "neutral")) != "enemy":
		_fail("Neutral town was not captured by AI: %s" % JSON.stringify(town))
		return {}
	if String(town.get("controlling_faction_id", "")) != MIRECLAW:
		_fail("Captured neutral town did not record controlling faction: %s" % JSON.stringify(town))
		return {}
	var front: Dictionary = town.get("front", {}) if town.get("front", {}) is Dictionary else {}
	if String(front.get("state", "")) != "stabilizing" or String(front.get("faction_id", "")) != MIRECLAW:
		_fail("Captured neutral town did not enter enemy stabilization front state: %s" % JSON.stringify(front))
		return {}
	var event_types := _event_types(result.get("events", []))
	if "ai_town_captured" not in event_types:
		_fail("Neutral town capture did not emit ai_town_captured: %s" % JSON.stringify(result))
		return {}
	var after_raid := _encounter(session, "neutral_town_vaska")
	if after_raid.is_empty():
		_fail("Neutral-town raid disappeared after capture.")
		return {}
	var commander_state: Dictionary = after_raid.get("enemy_commander_state", {}) if after_raid.get("enemy_commander_state", {}) is Dictionary else {}
	if String(commander_state.get("last_outcome", "")) != "town_captured":
		_fail("Neutral-town commander did not record town_captured outcome: %s" % JSON.stringify(commander_state))
		return {}
	_assert_task_status(session, "hero_vaska", "town", NEUTRAL_TOWN_ID, "completed", "valid")
	if _failed:
		return {}
	return {
		"case_id": "arrived_raid_captures_empty_neutral_town",
		"owner_after": String(town.get("owner", "")),
		"controlling_faction_id": String(town.get("controlling_faction_id", "")),
		"front_state": String(front.get("state", "")),
		"event_types": event_types,
		"pressure_before": pressure_before,
		"pressure_after": int(result.get("state", state).get("pressure", 0)),
		"commander_last_outcome": String(commander_state.get("last_outcome", "")),
	}

func _prepare_neutral_town_only_front(session) -> void:
	session.overworld["resource_nodes"] = []
	session.overworld["artifact_nodes"] = []
	session.overworld["encounters"] = []
	var towns: Array = session.overworld.get("towns", [])
	for index in range(towns.size()):
		var town = towns[index]
		if not (town is Dictionary):
			continue
		if String(town.get("owner", "neutral")) == "player":
			town["owner"] = "enemy"
			town["controlling_faction_id"] = MIRECLAW
			towns[index] = town
	towns.append({
		"placement_id": NEUTRAL_TOWN_ID,
		"town_id": "town_duskfen",
		"x": 8,
		"y": 2,
		"owner": "neutral",
		"garrison": [],
		"available_recruits": {},
		"buildings": [],
	})
	session.overworld["towns"] = towns

func _neutral_town_raid(session) -> Dictionary:
	var raid := {
		"placement_id": "neutral_town_vaska",
		"encounter_id": "encounter_mire_raid",
		"x": 8,
		"y": 2,
		"difficulty": "pressure",
		"combat_seed": hash("%s:neutral_town_vaska" % String(session.scenario_id)),
		"spawned_by_faction_id": MIRECLAW,
		"days_active": 0,
		"arrived": false,
		"goal_distance": 0,
		"target_kind": "town",
		"target_placement_id": NEUTRAL_TOWN_ID,
		"target_label": "Mireford Neutral Hold",
		"target_x": 8,
		"target_y": 2,
		"goal_x": 8,
		"goal_y": 2,
		"target_reason_codes": ["town_expansion", "neutral_town_claim"],
		"target_public_reason": "neutral town expansion",
		"target_public_importance": "high",
	}
	raid["enemy_commander_state"] = EnemyAdventureRules.build_raid_commander_state(
		raid,
		"hero_vaska",
		MIRECLAW,
		session,
		{},
		EnemyAdventureRules.commander_roster_for_faction(session, MIRECLAW)
	)
	return EnemyAdventureRules.ensure_raid_army(raid, session)

func _base_session():
	var session = ScenarioFactory.create_session(
		RIVER_PASS,
		"normal",
		SessionState.LAUNCH_MODE_SKIRMISH
	)
	OverworldRules.normalize_overworld_state(session)
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

func _seed_task_board(session, tasks: Array) -> void:
	var state := _enemy_state(session)
	state["hero_task_state"] = {
		"schema_version": 1,
		"planner_epoch": 17,
		"tasks": tasks,
	}
	_update_enemy_state(session, state)

func _town_expansion_task(actor_id: String, target_id: String, status: String, validation: String) -> Dictionary:
	return {
		"task_id": "task:town_expansion:%s:%s" % [actor_id, target_id],
		"owner_faction_id": MIRECLAW,
		"actor_kind": "commander_roster",
		"actor_id": actor_id,
		"source_kind": "saved_task_state",
		"source_id": "neutral_town_expansion_fixture",
		"task_class": "raid_town",
		"task_status": status,
		"target_kind": "town",
		"target_id": target_id,
		"front_id": "town:%s" % target_id,
		"origin_kind": "town",
		"origin_id": "duskfen_bastion",
		"priority_reason_codes": ["town_expansion", "neutral_town_claim"],
		"assigned_day": 2,
		"expires_day": 9,
		"continuity_policy": "persist_until_invalid",
		"route_policy": "derive_route_on_turn",
		"last_validation": validation,
		"reservation": {
			"reservation_status": "primary",
			"reservation_scope": "exclusive_target",
			"reservation_key": "town:%s" % target_id,
		},
	}

func _task_for_target(session, target_kind: String, target_id: String) -> Dictionary:
	for task in _task_state(session).get("tasks", []):
		if not (task is Dictionary):
			continue
		if String(task.get("target_kind", "")) == target_kind and String(task.get("target_id", "")) == target_id:
			return task
	return {}

func _assert_task_status(session, actor_id: String, target_kind: String, target_id: String, status: String, validation: String) -> void:
	var task := _task_for_target(session, target_kind, target_id)
	if task.is_empty():
		_fail("Missing task %s/%s for %s" % [target_kind, target_id, actor_id])
		return
	if String(task.get("actor_id", "")) != actor_id or String(task.get("task_status", "")) != status or String(task.get("last_validation", "")) != validation:
		_fail("Task status mismatch: %s" % JSON.stringify(task))

func _task_state(session) -> Dictionary:
	var state := _enemy_state(session)
	return state.get("hero_task_state", {}) if state.get("hero_task_state", {}) is Dictionary else {}

func _town(session, placement_id: String) -> Dictionary:
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("placement_id", "")) == placement_id:
			return town
	return {}

func _encounter(session, placement_id: String) -> Dictionary:
	for encounter in session.overworld.get("encounters", []):
		if encounter is Dictionary and String(encounter.get("placement_id", "")) == placement_id:
			return encounter
	return {}

func _event_types(events: Variant) -> Array:
	var output := []
	if not (events is Array):
		return output
	for event in events:
		if event is Dictionary:
			output.append(String(event.get("event_type", "")))
	return output

func _string_array(value: Variant) -> Array:
	var output := []
	if not (value is Array):
		return output
	for item in value:
		output.append(String(item))
	return output

func _fail(message: String) -> void:
	_failed = true
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
