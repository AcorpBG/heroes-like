extends Node

const REPORT_ID := "AI_HERO_TASK_RETASK_CANCELLATION_REPORT"
const RIVER_PASS := "river-pass"
const MIRECLAW := "faction_mireclaw"

var _failed := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var case_report := _town_defense_retask_cancels_previous_task_case()
	if case_report.is_empty():
		return
	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"schema_status": "live_retask_preserves_cancelled_task_history",
		"behavior_policy": "retasked_commanders_cancel_previous_open_task",
		"save_policy": "hero_task_state_live_persist_no_save_migration",
		"case": case_report,
		"save_version_before": int(SessionStateStore.SAVE_VERSION),
		"save_version_after": int(SessionStateStore.SAVE_VERSION),
	}
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _town_defense_retask_cancels_previous_task_case() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config()
	var state := _enemy_state(session)
	state["pressure"] = 0
	_update_enemy_state(session, state)
	_set_stabilizing_front(session, "duskfen_bastion")
	_set_player_position(session, {"x": 6, "y": 2})
	_set_resource_controller(session, "river_free_company", "player")
	_seed_task_board(session, [_task("hero_vaska", "contest_site", "resource", "river_free_company", "active", "valid")])
	var raid := _defense_retask_raid(session)
	var encounters: Array = session.overworld.get("encounters", [])
	encounters.append(raid)
	session.overworld["encounters"] = encounters

	var result := EnemyAdventureRules.advance_raids(session, config, MIRECLAW, state)
	var after_raid := _encounter(session, "retask_cancel_vaska")
	if after_raid.is_empty():
		_fail("Retask cancellation fixture raid disappeared after advance.")
		return {}
	if String(after_raid.get("target_kind", "")) != "town" or String(after_raid.get("target_placement_id", "")) != "duskfen_bastion":
		_fail("Retask cancellation fixture did not retask to Duskfen defense: %s" % JSON.stringify(after_raid))
		return {}
	var event_types := _event_types(result.get("events", []))
	if "ai_target_assigned" not in event_types:
		_fail("Retask cancellation fixture did not emit ai_target_assigned: %s" % JSON.stringify(result))
		return {}
	var task_summary := _assert_task_board(session)
	if _failed:
		return {}
	EnemyTurnRules.normalize_enemy_states(session)
	var normalized_summary := _assert_task_board(session)
	if _failed:
		return {}
	var public_log := EnemyAdventureRules.ai_public_event_log_boundary_report(result.get("events", []), 8)
	if not bool(public_log.get("ok", false)):
		_fail("Retask cancellation public event boundary failed: %s" % JSON.stringify(public_log))
		return {}
	if _public_event_leaks(public_log.get("public_events", [])):
		return {}
	return {
		"case_id": "town_defense_retask_cancels_previous_resource_task",
		"after_target_kind": String(after_raid.get("target_kind", "")),
		"after_target_id": String(after_raid.get("target_placement_id", "")),
		"event_types": event_types,
		"task_summary": task_summary,
		"normalized_task_summary": normalized_summary,
		"public_event_count": int(public_log.get("public_event_count", 0)),
		"save_version": int(SessionStateStore.SAVE_VERSION),
	}

func _seed_task_board(session, tasks: Array) -> void:
	var state := _enemy_state(session)
	state["hero_task_state"] = {
		"schema_version": 1,
		"planner_epoch": 8,
		"tasks": tasks,
	}
	_update_enemy_state(session, state)

func _task(actor_id: String, task_class: String, target_kind: String, target_id: String, status: String, validation: String) -> Dictionary:
	return {
		"task_id": "task:retask_cancel:%s:%s:%s" % [actor_id, task_class, target_id],
		"owner_faction_id": MIRECLAW,
		"actor_kind": "commander_roster",
		"actor_id": actor_id,
		"source_kind": "saved_task_state",
		"source_id": "retask_cancellation_fixture",
		"task_class": task_class,
		"task_status": status,
		"target_kind": target_kind,
		"target_id": target_id,
		"front_id": "%s:%s" % [target_kind, target_id],
		"origin_kind": "encounter",
		"origin_id": "retask_cancel_vaska",
		"priority_reason_codes": ["retask_cancellation_fixture"],
		"assigned_day": 2,
		"expires_day": 10,
		"continuity_policy": "persist_until_invalid",
		"route_policy": "derive_route_on_turn",
		"last_validation": validation,
		"reservation": {
			"reservation_status": "primary",
			"reservation_scope": "exclusive_target",
			"reservation_key": "%s:%s" % [target_kind, target_id],
		},
	}

func _defense_retask_raid(session) -> Dictionary:
	var raid := {
		"placement_id": "retask_cancel_vaska",
		"encounter_id": "encounter_mire_raid",
		"x": 6,
		"y": 2,
		"difficulty": "pressure",
		"combat_seed": hash("%s:retask_cancel_vaska" % String(session.scenario_id)),
		"spawned_by_faction_id": MIRECLAW,
		"days_active": 0,
		"arrived": false,
		"goal_distance": 9999,
		"target_kind": "resource",
		"target_placement_id": "river_free_company",
		"target_label": "Free Company Camp",
		"target_x": 0,
		"target_y": 4,
		"goal_x": 0,
		"goal_y": 4,
		"target_reason_codes": ["retask_cancellation_fixture"],
		"enemy_army": {
			"id": "retask_cancel_fixture_host",
			"name": "Retask Cancellation Host",
			"stacks": [{"unit_id": "unit_bog_brute", "count": 8}],
		},
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

func _assert_task_board(session) -> Dictionary:
	var state := _enemy_state(session)
	var task_state: Dictionary = state.get("hero_task_state", {}) if state.get("hero_task_state", {}) is Dictionary else {}
	var tasks: Array = task_state.get("tasks", []) if task_state.get("tasks", []) is Array else []
	var cancelled_old := false
	var replacement_recorded := false
	var replacement_task_id := ""
	var replacement_status := ""
	var old_invalidated_by := ""
	for task_value in tasks:
		if not (task_value is Dictionary):
			continue
		var task: Dictionary = task_value
		if String(task.get("actor_id", "")) != "hero_vaska":
			continue
		if String(task.get("target_kind", "")) == "town" and String(task.get("target_id", "")) == "duskfen_bastion":
			var task_status := String(task.get("task_status", ""))
			if task_status in ["active", "completed"] and String(task.get("last_validation", "")) == "valid":
				if String(task.get("task_class", "")) != "defend_front":
					_fail("Retask replacement should be defend_front, got %s" % JSON.stringify(task))
					return {}
				replacement_recorded = true
				replacement_task_id = String(task.get("task_id", ""))
				replacement_status = task_status
		if String(task.get("target_kind", "")) == "resource" and String(task.get("target_id", "")) == "river_free_company":
			if String(task.get("task_status", "")) == "cancelled" and String(task.get("last_validation", "")) == "cancelled_by_retask":
				cancelled_old = true
				old_invalidated_by = String(task.get("invalidated_by_task_id", ""))
	if not replacement_recorded:
		_fail("Retask cancellation board is missing valid Duskfen defense replacement task: %s" % JSON.stringify(task_state))
		return {}
	if not cancelled_old:
		_fail("Retask cancellation board is missing cancelled previous resource task: %s" % JSON.stringify(task_state))
		return {}
	if replacement_task_id == "" or old_invalidated_by != replacement_task_id:
		_fail("Cancelled task did not point at replacement task id: old=%s replacement=%s board=%s" % [old_invalidated_by, replacement_task_id, JSON.stringify(task_state)])
		return {}
	return {
		"schema_version": int(task_state.get("schema_version", 0)),
		"planner_epoch": int(task_state.get("planner_epoch", 0)),
		"task_count": tasks.size(),
		"cancelled_old": cancelled_old,
		"replacement_recorded": replacement_recorded,
		"replacement_status": replacement_status,
		"replacement_task_id": replacement_task_id,
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

func _set_stabilizing_front(session, placement_id: String) -> void:
	var towns: Array = session.overworld.get("towns", [])
	for index in range(towns.size()):
		var town = towns[index]
		if not (town is Dictionary) or String(town.get("placement_id", "")) != placement_id:
			continue
		town["front"] = {
			"state": "stabilizing",
			"faction_id": MIRECLAW,
			"last_change_day": max(0, int(session.day) - 1),
			"stabilize_until_day": int(session.day) + 4,
			"last_owner": "player",
			"capture_count": 1,
			"source": "retask_cancellation_fixture",
		}
		towns[index] = town
		session.overworld["towns"] = towns
		return
	_fail("Could not find town %s for stabilizing-front fixture." % placement_id)

func _set_player_position(session, position: Dictionary) -> void:
	session.overworld["hero_position"] = {"x": int(position.get("x", 0)), "y": int(position.get("y", 0))}

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

func _encounter(session, placement_id: String) -> Dictionary:
	for encounter in session.overworld.get("encounters", []):
		if encounter is Dictionary and String(encounter.get("placement_id", "")) == placement_id:
			return encounter
	return {}

func _event_types(events: Variant) -> Array:
	var types := []
	if not (events is Array):
		return types
	for event in events:
		if event is Dictionary:
			var event_type := String(event.get("event_type", ""))
			if event_type != "" and event_type not in types:
				types.append(event_type)
	types.sort()
	return types

func _public_event_leaks(public_events: Variant) -> bool:
	var forbidden_tokens := ["target_debug_reason", "hero_task_state", "task_id", "reservation_key", "garrison_score", "raid_score", "invalidated_by_task_id"]
	var encoded := JSON.stringify(public_events)
	for token in forbidden_tokens:
		if encoded.find(token) >= 0:
			_fail("Retask cancellation public events leaked internal token %s" % token)
			return true
	return false

func _fail(message: String) -> void:
	var payload := {"ok": false, "report_id": REPORT_ID, "error": message}
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	_failed = true
	get_tree().quit(1)
