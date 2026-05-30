extends Node

const REPORT_ID := "AI_PLANNED_TASK_RECRUITMENT_PREP_REPORT"
const SCENARIO_ID := "river-pass"
const FACTION_ID := "faction_mireclaw"
const DUSKFEN := "duskfen_bastion"
const PREP_UNIT := "unit_bog_brute"
const TREASURY := {
	"gold": 16000,
	"wood": 24,
	"ore": 24,
	"aetherglass": 12,
	"embergrain": 12,
	"peatwax": 12,
	"verdant_grafts": 12,
	"brass_scrip": 12,
	"memory_salt": 12,
}

var _failed := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var live_turn_case := _live_turn_plans_before_same_turn_recruitment()
	if live_turn_case.is_empty():
		return
	var planned_case := _planned_task_recruitment_prepares_commander()
	if planned_case.is_empty():
		return
	var garrison_case := _critical_garrison_still_wins()
	if garrison_case.is_empty():
		return
	var ready_launch_case := _prepared_saved_task_launches_below_pressure()
	if ready_launch_case.is_empty():
		return
	var unplanned_gate_case := _unplanned_low_pressure_raid_stays_blocked()
	if unplanned_gate_case.is_empty():
		return
	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"schema_status": "planned_task_recruitment_prep_live_behavior",
		"behavior_policy": "town_recruitment_prepares_saved_commander_tasks_and_ready_tasks_launch_below_generic_pressure",
		"save_policy": "hero_task_state_live_persist_no_save_migration",
		"cases": [live_turn_case, planned_case, garrison_case, ready_launch_case, unplanned_gate_case],
		"save_version_before": int(SessionStateStore.SAVE_VERSION),
		"save_version_after": int(SessionStateStore.SAVE_VERSION),
	}
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _live_turn_plans_before_same_turn_recruitment() -> Dictionary:
	var session = _base_session()
	_set_enemy_treasury(session, TREASURY)
	_prepare_safe_recruiting_town(session)
	_mark_contestable_resources(session)
	var state := _enemy_state(session)
	state["pressure"] = 0
	state["raid_counter"] = 0
	state["commander_counter"] = 0
	state.erase("hero_task_state")
	_update_enemy_state(session, state)
	var active_before := _active_raid_count(session)
	if active_before != 0:
		_fail("Expected no active raids before same-turn prep case, got %d" % active_before)
		return {}
	var result := EnemyTurnRules.run_enemy_turn(session)
	var events: Array = result.get("events", []) if result.get("events", []) is Array else []
	var planned_index := _event_index(events, "ai_commander_task_planned")
	var prepared_index := _event_index(events, "ai_commander_prepared")
	if planned_index < 0:
		_fail("Live turn did not emit same-turn task planning: %s" % JSON.stringify(_event_types(events)))
		return {}
	if prepared_index < 0:
		_fail("Live turn did not prepare a commander from newly planned tasks: %s" % JSON.stringify(_event_types(events)))
		return {}
	if planned_index > prepared_index:
		_fail("Live turn prepared a commander before planning tasks: %s" % JSON.stringify(_event_types(events)))
		return {}
	var prepared_event: Dictionary = events[prepared_index]
	var actor_id := String(prepared_event.get("target_id", ""))
	if actor_id == "":
		_fail("Prepared event missing commander target id: %s" % JSON.stringify(prepared_event))
		return {}
	var continuity := _commander_continuity(session, actor_id)
	if int(continuity.get("current_strength", 0)) <= 0:
		_fail("Prepared commander did not gain same-turn continuity: actor=%s continuity=%s" % [actor_id, JSON.stringify(continuity)])
		return {}
	if not _has_task_for_actor(_enemy_state(session), actor_id):
		_fail("Prepared commander has no task-board record after live turn: actor=%s" % actor_id)
		return {}
	return {
		"case_id": "live_turn_plans_before_same_turn_recruitment",
		"active_raids_before": active_before,
		"prepared_actor_id": actor_id,
		"prepared_strength": int(continuity.get("current_strength", 0)),
		"planned_event_index": planned_index,
		"prepared_event_index": prepared_index,
		"event_types": _event_types(events),
	}

func _planned_task_recruitment_prepares_commander() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config()
	_set_enemy_treasury(session, TREASURY)
	_prepare_safe_recruiting_town(session)
	_mark_contestable_resources(session)
	var state := _enemy_state(session)
	state["pressure"] = 0
	state["raid_counter"] = 0
	state["commander_counter"] = 0
	state.erase("hero_task_state")
	_update_enemy_state(session, state)

	var plan_result := EnemyAdventureRules.plan_enemy_hero_task_board(session, config, state)
	if int(plan_result.get("planned_count", 0)) < 1:
		_fail("Expected planned tasks before recruitment prep, got %s" % JSON.stringify(plan_result))
		return {}
	_update_enemy_state(session, plan_result.get("state", {}))
	var town := _town_by_id(session, DUSKFEN)
	var destination := EnemyTurnRules._choose_recruit_destination_breakdown(session, config, town, FACTION_ID)
	if String(destination.get("type", "")) != "planned":
		_fail("Expected planned-task recruitment destination, got %s" % JSON.stringify(destination))
		return {}
	var actor_id := String(destination.get("roster_hero_id", ""))
	var before_strength := _commander_strength(session, actor_id)
	var treasury := TREASURY.duplicate(true)
	var recruit_result := EnemyTurnRules._recruit_town_forces(session, config, town, treasury, FACTION_ID)
	if int(recruit_result.get("planned_batches", 0)) < 1:
		_fail("Expected planned recruitment batch, got %s" % JSON.stringify(recruit_result))
		return {}
	var after_strength := _commander_strength(session, actor_id)
	if after_strength <= before_strength:
		_fail("Planned recruitment did not increase commander continuity: before=%d after=%d actor=%s" % [before_strength, after_strength, actor_id])
		return {}
	var prepared_event := _event_by_type(recruit_result.get("events", []), "ai_commander_prepared")
	if prepared_event.is_empty():
		_fail("Planned recruitment did not emit ai_commander_prepared: %s" % JSON.stringify(recruit_result.get("events", [])))
		return {}
	return {
		"case_id": "safe_town_prepares_saved_task_commander",
		"destination": destination,
		"actor_id": actor_id,
		"before_strength": before_strength,
		"after_strength": after_strength,
		"planned_batches": int(recruit_result.get("planned_batches", 0)),
		"event_type": String(prepared_event.get("event_type", "")),
	}

func _critical_garrison_still_wins() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config()
	_set_enemy_treasury(session, TREASURY)
	_prepare_critical_recruiting_town(session)
	_mark_contestable_resources(session)
	var state := _enemy_state(session)
	state.erase("hero_task_state")
	_update_enemy_state(session, state)
	var plan_result := EnemyAdventureRules.plan_enemy_hero_task_board(session, config, state)
	_update_enemy_state(session, plan_result.get("state", {}))
	var destination := EnemyTurnRules._choose_recruit_destination_breakdown(
		session,
		config,
		_town_by_id(session, DUSKFEN),
		FACTION_ID
	)
	if String(destination.get("type", "")) != "garrison" or String(destination.get("decision_rule", "")) != "critical_garrison_gap":
		_fail("Critical garrison should outrank planned prep, got %s" % JSON.stringify(destination))
		return {}
	if float(destination.get("planned_score", 0.0)) <= 0.0:
		_fail("Critical garrison case should still expose planned prep pressure, got %s" % JSON.stringify(destination))
		return {}
	return {
		"case_id": "critical_garrison_blocks_planned_task_prep",
		"destination_type": String(destination.get("type", "")),
		"decision_rule": String(destination.get("decision_rule", "")),
		"planned_score": float(destination.get("planned_score", 0.0)),
	}

func _prepared_saved_task_launches_below_pressure() -> Dictionary:
	var session = _base_session()
	var config := _high_threshold_config()
	_set_enemy_treasury(session, TREASURY)
	_prepare_ready_launch_recruiting_town(session)
	_mark_contestable_resources(session)
	var state := _enemy_state(session)
	state["pressure"] = 0
	state["raid_counter"] = 0
	state["commander_counter"] = 0
	state.erase("hero_task_state")
	_update_enemy_state(session, state)
	var plan_result := EnemyAdventureRules.plan_enemy_hero_task_board(session, config, state)
	if int(plan_result.get("planned_count", 0)) < 1:
		_fail("Expected planned tasks before ready launch, got %s" % JSON.stringify(plan_result))
		return {}
	_update_enemy_state(session, plan_result.get("state", {}))
	var town := _town_by_id(session, DUSKFEN)
	var destination := EnemyTurnRules._choose_recruit_destination_breakdown(session, config, town, FACTION_ID)
	if String(destination.get("type", "")) != "planned":
		_fail("Ready-launch setup did not choose planned preparation: %s" % JSON.stringify(destination))
		return {}
	var actor_id := String(destination.get("roster_hero_id", ""))
	var treasury := TREASURY.duplicate(true)
	var recruit_result := EnemyTurnRules._recruit_town_forces(session, config, town, treasury, FACTION_ID)
	if int(recruit_result.get("planned_batches", 0)) < 1:
		_fail("Ready-launch setup did not prepare a commander: %s" % JSON.stringify(recruit_result))
		return {}
	var prepared_strength := _commander_strength(session, actor_id)
	state = _enemy_state(session)
	state["pressure"] = 0
	_update_enemy_state(session, state)
	var ready_report := EnemyTurnRules._planned_task_launch_ready_report(session, config, state, FACTION_ID)
	if ready_report.is_empty():
		_fail("Prepared planned task was not launch-ready below pressure: actor=%s strength=%d" % [actor_id, prepared_strength])
		return {}
	if not EnemyTurnRules._can_launch_raid(session, config, state, FACTION_ID):
		_fail("Ready planned task could not launch below generic pressure: %s" % JSON.stringify(ready_report))
		return {}
	var before_raids := _active_raid_count(session)
	var spawn_result := EnemyTurnRules._spawn_raid(session, config, state)
	var after_raids := _active_raid_count(session)
	if after_raids <= before_raids:
		_fail("Ready planned task did not spawn below generic pressure: %s" % JSON.stringify(spawn_result))
		return {}
	var raid := _raid_for_actor_target(
		session,
		actor_id,
		String(ready_report.get("target_kind", "")),
		String(ready_report.get("target_id", ""))
	)
	if raid.is_empty():
		_fail("Ready planned task did not produce its matching raid: ready=%s" % JSON.stringify(ready_report))
		return {}
	if String(raid.get("enemy_commander_state", {}).get("roster_hero_id", "")) != actor_id:
		_fail("Ready launch used the wrong commander: expected=%s raid=%s" % [actor_id, JSON.stringify(raid)])
		return {}
	if String(raid.get("target_placement_id", "")) != String(ready_report.get("target_id", "")):
		_fail("Ready launch did not preserve planned target: ready=%s raid=%s" % [JSON.stringify(ready_report), JSON.stringify(raid)])
		return {}
	if _event_by_type(spawn_result.get("events", []), "ai_target_assigned").is_empty():
		_fail("Ready launch did not emit target assignment: %s" % JSON.stringify(spawn_result.get("events", [])))
		return {}
	return {
		"case_id": "prepared_saved_task_launches_below_generic_pressure",
		"pressure": int(state.get("pressure", 0)),
		"raid_threshold": int(config.get("raid_threshold", 0)),
		"actor_id": actor_id,
		"prepared_strength": prepared_strength,
		"target_strength": int(ready_report.get("target_strength", 0)),
		"target_kind": String(ready_report.get("target_kind", "")),
		"target_id": String(ready_report.get("target_id", "")),
		"active_raids_before": before_raids,
		"active_raids_after": after_raids,
	}

func _unplanned_low_pressure_raid_stays_blocked() -> Dictionary:
	var session = _base_session()
	var config := _high_threshold_config()
	_mark_contestable_resources(session)
	var state := _enemy_state(session)
	state["pressure"] = 0
	state["raid_counter"] = 0
	state["commander_counter"] = 0
	state.erase("hero_task_state")
	_update_enemy_state(session, state)
	var ready_report := EnemyTurnRules._planned_task_launch_ready_report(session, config, state, FACTION_ID)
	if not ready_report.is_empty():
		_fail("Unplanned low-pressure case unexpectedly had a ready saved task: %s" % JSON.stringify(ready_report))
		return {}
	if EnemyTurnRules._can_launch_raid(session, config, state, FACTION_ID):
		_fail("Unplanned low-pressure raid bypassed the pressure threshold.")
		return {}
	return {
		"case_id": "unplanned_low_pressure_raid_stays_blocked",
		"pressure": int(state.get("pressure", 0)),
		"raid_threshold": int(config.get("raid_threshold", 0)),
		"ready_report_empty": ready_report.is_empty(),
	}

func _base_session():
	var session = ScenarioFactory.create_session(SCENARIO_ID, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	session.day = 12
	OverworldRules.normalize_overworld_state(session)
	OverworldRules.refresh_fog_of_war(session)
	EnemyTurnRules.normalize_enemy_states(session)
	EnemyAdventureRules.normalize_all_commander_rosters(session)
	return session

func _prepare_safe_recruiting_town(session) -> void:
	_update_duskfen_town(session, {
		"garrison": [
			{"unit_id": "unit_bog_brute", "count": 12},
			{"unit_id": "unit_mire_slinger", "count": 18},
		],
		"available_recruits": {PREP_UNIT: 4},
	})

func _prepare_ready_launch_recruiting_town(session) -> void:
	_update_duskfen_town(session, {
		"garrison": [
			{"unit_id": "unit_bog_brute", "count": 12},
			{"unit_id": "unit_mire_slinger", "count": 18},
		],
		"available_recruits": {PREP_UNIT: 99},
	})

func _prepare_critical_recruiting_town(session) -> void:
	_update_duskfen_town(session, {
		"garrison": [],
		"available_recruits": {PREP_UNIT: 4},
	})

func _update_duskfen_town(session, patch: Dictionary) -> void:
	var towns: Array = session.overworld.get("towns", [])
	for index in range(towns.size()):
		var town = towns[index]
		if not (town is Dictionary) or String(town.get("placement_id", "")) != DUSKFEN:
			continue
		for key in patch.keys():
			town[key] = patch[key]
		towns[index] = town
		session.overworld["towns"] = towns
		return
	_fail("Missing town %s" % DUSKFEN)

func _mark_contestable_resources(session) -> void:
	_set_resource_controller(session, "river_free_company", "player")
	_set_resource_controller(session, "river_signal_post", "player")

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

func _set_enemy_treasury(session, treasury: Dictionary) -> void:
	var states: Array = session.overworld.get("enemy_states", [])
	for index in range(states.size()):
		var state = states[index]
		if state is Dictionary and String(state.get("faction_id", "")) == FACTION_ID:
			state["treasury"] = treasury.duplicate(true)
			states[index] = state
			session.overworld["enemy_states"] = states
			return
	_fail("Could not set enemy treasury")

func _commander_strength(session, actor_id: String) -> int:
	return int(_commander_continuity(session, actor_id).get("current_strength", 0))

func _commander_continuity(session, actor_id: String) -> Dictionary:
	for entry in EnemyAdventureRules.commander_roster_for_faction(session, FACTION_ID):
		if entry is Dictionary and String(entry.get("roster_hero_id", "")) == actor_id:
			return EnemyAdventureRules.commander_army_continuity(entry)
	return {}

func _active_raid_count(session) -> int:
	var count := 0
	for encounter in session.overworld.get("encounters", []):
		if encounter is Dictionary and String(encounter.get("spawned_by_faction_id", "")) == FACTION_ID:
			count += 1
	return count

func _has_task_for_actor(state: Dictionary, actor_id: String) -> bool:
	var task_state: Dictionary = state.get("hero_task_state", {}) if state.get("hero_task_state", {}) is Dictionary else {}
	for task_value in task_state.get("tasks", []):
		if task_value is Dictionary and String(task_value.get("actor_id", "")) == actor_id:
			return true
	return false

func _town_by_id(session, placement_id: String) -> Dictionary:
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("placement_id", "")) == placement_id:
			return town
	_fail("Missing town %s" % placement_id)
	return {}

func _enemy_config() -> Dictionary:
	var scenario := ContentService.get_scenario(SCENARIO_ID)
	for config in scenario.get("enemy_factions", []):
		if config is Dictionary and String(config.get("faction_id", "")) == FACTION_ID:
			return config
	_fail("Could not find enemy config for %s" % FACTION_ID)
	return {}

func _high_threshold_config() -> Dictionary:
	var config := _enemy_config().duplicate(true)
	config["pressure_per_day"] = 0
	config["pressure_per_enemy_town"] = 0
	config["raid_threshold"] = 99
	return config

func _enemy_state(session) -> Dictionary:
	for state in session.overworld.get("enemy_states", []):
		if state is Dictionary and String(state.get("faction_id", "")) == FACTION_ID:
			return state
	_fail("Could not find enemy state for %s" % FACTION_ID)
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

func _event_by_type(events: Array, event_type: String) -> Dictionary:
	for event in events:
		if event is Dictionary and String(event.get("event_type", "")) == event_type:
			return event
	return {}

func _raid_for_actor_target(session, actor_id: String, target_kind: String, target_id: String) -> Dictionary:
	for encounter in session.overworld.get("encounters", []):
		if not (encounter is Dictionary):
			continue
		if String(encounter.get("spawned_by_faction_id", "")) != FACTION_ID:
			continue
		var commander: Dictionary = encounter.get("enemy_commander_state", {}) if encounter.get("enemy_commander_state", {}) is Dictionary else {}
		if String(commander.get("roster_hero_id", "")) != actor_id:
			continue
		if String(encounter.get("target_kind", "")) != target_kind:
			continue
		if String(encounter.get("target_placement_id", "")) != target_id:
			continue
		return encounter
	return {}

func _event_index(events: Array, event_type: String) -> int:
	for index in range(events.size()):
		var event = events[index]
		if event is Dictionary and String(event.get("event_type", "")) == event_type:
			return index
	return -1

func _event_types(events: Array) -> Array:
	var types := []
	for event in events:
		if not (event is Dictionary):
			continue
		var event_type := String(event.get("event_type", ""))
		if event_type != "":
			types.append(event_type)
	return types

func _fail(message: String) -> void:
	var payload := {"ok": false, "report_id": REPORT_ID, "error": message}
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	_failed = true
	get_tree().quit(1)
