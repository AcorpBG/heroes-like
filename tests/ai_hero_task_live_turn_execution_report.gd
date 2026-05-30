extends Node

const REPORT_ID := "AI_HERO_TASK_LIVE_TURN_EXECUTION_REPORT"
const RIVER_PASS := "river-pass"
const MIRECLAW := "faction_mireclaw"

var _failed := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var case_report := _river_pass_live_targets_execute_on_enemy_turn()
	if case_report.is_empty():
		return
	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"schema_status": "live_target_selection_turn_execution_persists_task_board",
		"behavior_policy": "run_enemy_turn_executes_and_completes_live_commander_resource_tasks",
		"save_policy": "hero_task_state_live_persist_no_save_migration",
		"case": case_report,
		"save_version_before": int(SessionStateStore.SAVE_VERSION),
		"save_version_after": int(SessionStateStore.SAVE_VERSION),
	}
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _river_pass_live_targets_execute_on_enemy_turn() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config()
	var state := _enemy_state(session)
	state["pressure"] = 0
	_update_enemy_state(session, state)
	_set_resource_controller(session, "river_free_company", "player")
	_set_resource_controller(session, "river_signal_post", "player")
	var free_company_before := _resource_controller(session, "river_free_company")
	var signal_post_before := _resource_controller(session, "river_signal_post")
	var encounters: Array = session.overworld.get("encounters", [])
	encounters.append(_raid_seed(session, config, "hero_vaska", "live_turn_vaska_free_company", {"x": 0, "y": 4}))
	encounters.append(_raid_seed(session, config, "hero_sable", "live_turn_sable_signal_post", {"x": 2, "y": 3}))
	session.overworld["encounters"] = encounters
	EnemyAdventureRules.normalize_all_commander_rosters(session)

	var result := EnemyTurnRules.run_enemy_turn(session)
	if not bool(result.get("ok", false)):
		_fail("Enemy turn failed: %s" % JSON.stringify(result))
		return {}
	var vaska := _encounter(session, "live_turn_vaska_free_company")
	var sable := _encounter(session, "live_turn_sable_signal_post")
	_assert_target(vaska, "river_free_company", "Vaska turn raid")
	_assert_target(sable, "river_signal_post", "Sable companion turn raid")
	if _failed:
		return {}
	var free_company_after := _resource_controller(session, "river_free_company")
	var signal_post_after := _resource_controller(session, "river_signal_post")
	if free_company_after != MIRECLAW:
		_fail("Free Company was not seized by live-turn raid: before=%s after=%s" % [free_company_before, free_company_after])
		return {}
	if signal_post_after != MIRECLAW:
		_fail("Signal Post was not seized by companion live-turn raid: before=%s after=%s" % [signal_post_before, signal_post_after])
		return {}
	var event_types := _event_types(result.get("events", []))
	_assert_event(result.get("events", []), "ai_target_assigned", "river_free_company")
	_assert_event(result.get("events", []), "ai_target_assigned", "river_signal_post")
	_assert_event(result.get("events", []), "ai_site_seized", "river_free_company")
	_assert_event(result.get("events", []), "ai_site_seized", "river_signal_post")
	if _failed:
		return {}
	var task_board := _assert_live_task_board(session)
	if _failed:
		return {}
	EnemyTurnRules.normalize_enemy_states(session)
	var normalized_task_board := _assert_live_task_board(session)
	if _failed:
		return {}
	var public_log := EnemyAdventureRules.ai_public_event_log_boundary_report(result.get("events", []), 8)
	if not bool(public_log.get("ok", false)):
		_fail("Live turn public event boundary failed: %s" % JSON.stringify(public_log))
		return {}
	if _public_event_leaks(public_log.get("public_events", [])):
		return {}
	return {
		"case_id": "river_pass_live_target_turn_seizes_reserved_resource_fronts",
		"free_company_before": free_company_before,
		"free_company_after": free_company_after,
		"signal_post_before": signal_post_before,
		"signal_post_after": signal_post_after,
		"vaska_target_id": String(vaska.get("target_placement_id", "")),
		"sable_target_id": String(sable.get("target_placement_id", "")),
		"vaska_arrived": bool(vaska.get("arrived", false)),
		"sable_arrived": bool(sable.get("arrived", false)),
		"event_types": event_types,
		"public_event_count": int(public_log.get("public_event_count", 0)),
		"task_board": task_board,
		"normalized_task_board": normalized_task_board,
		"save_version": int(SessionStateStore.SAVE_VERSION),
	}

func _raid_seed(session, config: Dictionary, roster_hero_id: String, placement_id: String, origin: Dictionary) -> Dictionary:
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
	var session = ScenarioFactory.create_session(
		RIVER_PASS,
		"normal",
		SessionState.LAUNCH_MODE_SKIRMISH
	)
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
		if not (node is Dictionary):
			continue
		if String(node.get("placement_id", "")) != placement_id:
			continue
		node["collected"] = true
		node["collected_by_faction_id"] = faction_id
		node["collected_day"] = max(1, int(session.day))
		nodes[index] = node
		session.overworld["resource_nodes"] = nodes
		return
	_fail("Could not find resource placement %s" % placement_id)

func _resource_controller(session, placement_id: String) -> String:
	for node in session.overworld.get("resource_nodes", []):
		if node is Dictionary and String(node.get("placement_id", "")) == placement_id:
			return String(node.get("collected_by_faction_id", ""))
	return ""

func _encounter(session, placement_id: String) -> Dictionary:
	for encounter in session.overworld.get("encounters", []):
		if encounter is Dictionary and String(encounter.get("placement_id", "")) == placement_id:
			return encounter
	return {}

func _assert_target(raid: Dictionary, expected_target_id: String, label: String) -> void:
	if String(raid.get("target_kind", "")) != "resource" or String(raid.get("target_placement_id", "")) != expected_target_id:
		_fail("%s expected resource %s, got %s" % [label, expected_target_id, JSON.stringify(raid)])
		return
	if not bool(raid.get("arrived", false)):
		_fail("%s did not arrive after starting on the live target tile: %s" % [label, JSON.stringify(raid)])

func _assert_event(events: Variant, event_type: String, target_id: String) -> void:
	if not (events is Array):
		_fail("Events payload is not an array for %s/%s" % [event_type, target_id])
		return
	for event in events:
		if event is Dictionary and String(event.get("event_type", "")) == event_type and String(event.get("target_id", "")) == target_id:
			return
	_fail("Missing event %s for %s in %s" % [event_type, target_id, JSON.stringify(events)])

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

func _assert_live_task_board(session) -> Dictionary:
	for state in session.overworld.get("enemy_states", []):
		if not (state is Dictionary) or String(state.get("faction_id", "")) != MIRECLAW:
			continue
		if not state.has("hero_task_state"):
			_fail("Live turn execution did not persist hero_task_state.")
			return {}
		var task_state: Dictionary = state.get("hero_task_state", {}) if state.get("hero_task_state", {}) is Dictionary else {}
		var tasks: Array = task_state.get("tasks", []) if task_state.get("tasks", []) is Array else []
		var completed := {}
		var active_count := 0
		for task_value in tasks:
			if not (task_value is Dictionary):
				continue
			var task: Dictionary = task_value
			if _task_record_leaks(task):
				return {}
			if String(task.get("task_status", "")) == "active":
				active_count += 1
			if String(task.get("task_status", "")) == "completed":
				completed[String(task.get("actor_id", ""))] = String(task.get("target_id", ""))
		if String(completed.get("hero_vaska", "")) != "river_free_company":
			_fail("Vaska's completed live task was not persisted: %s" % JSON.stringify(task_state))
			return {}
		if String(completed.get("hero_sable", "")) != "river_signal_post":
			_fail("Sable's completed live task was not persisted: %s" % JSON.stringify(task_state))
			return {}
		return {
			"schema_version": int(task_state.get("schema_version", 0)),
			"planner_epoch": int(task_state.get("planner_epoch", 0)),
			"task_count": tasks.size(),
			"active_task_count": active_count,
			"completed_tasks": completed,
		}
	_fail("Could not find Mireclaw enemy state for live task board inspection.")
	return {}

func _task_record_leaks(task: Dictionary) -> bool:
	var forbidden_tokens := [
		"actor_label",
		"target_label",
		"target_x",
		"target_y",
		"target_score",
		"target_debug_reason",
		"resource_score_breakdown",
		"final_priority",
		"actor_active_placement_id",
		"last_seen_day",
	]
	for token in forbidden_tokens:
		if task.has(token):
			_fail("Persisted live task kept report-only field %s: %s" % [token, JSON.stringify(task)])
			return true
	return false

func _public_event_leaks(public_events: Variant) -> bool:
	if not (public_events is Array):
		_fail("Public events are not an array.")
		return true
	var forbidden_tokens := ["resource_score_breakdown", "target_debug_reason", "final_priority", "hero_task_state", "task_id", "reservation_key"]
	var encoded := JSON.stringify(public_events)
	for token in forbidden_tokens:
		if token in encoded:
			_fail("Public event leaked internal live-turn token %s: %s" % [token, encoded])
			return true
	return false

func _fail(message: String) -> void:
	var payload := {"ok": false, "report_id": REPORT_ID, "error": message}
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	_failed = true
	get_tree().quit(1)
