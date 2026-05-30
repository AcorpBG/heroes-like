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
	var planned_case := _planned_task_recruitment_prepares_commander()
	if planned_case.is_empty():
		return
	var garrison_case := _critical_garrison_still_wins()
	if garrison_case.is_empty():
		return
	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"schema_status": "planned_task_recruitment_prep_live_behavior",
		"behavior_policy": "town_recruitment_prepares_saved_commander_tasks_before_raid_spawn",
		"save_policy": "hero_task_state_live_persist_no_save_migration",
		"cases": [planned_case, garrison_case],
		"save_version_before": int(SessionStateStore.SAVE_VERSION),
		"save_version_after": int(SessionStateStore.SAVE_VERSION),
	}
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

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
	for entry in EnemyAdventureRules.commander_roster_for_faction(session, FACTION_ID):
		if entry is Dictionary and String(entry.get("roster_hero_id", "")) == actor_id:
			return int(EnemyAdventureRules.commander_army_continuity(entry).get("current_strength", 0))
	return 0

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

func _fail(message: String) -> void:
	var payload := {"ok": false, "report_id": REPORT_ID, "error": message}
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	_failed = true
	get_tree().quit(1)
