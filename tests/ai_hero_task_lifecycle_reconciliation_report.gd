extends Node

const REPORT_ID := "AI_HERO_TASK_LIFECYCLE_RECONCILIATION_REPORT"
const RIVER_PASS := "river-pass"
const MIRECLAW := "faction_mireclaw"

var _failed := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var case_report := _river_pass_saved_task_lifecycle_case()
	if case_report.is_empty():
		return
	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"schema_status": "hero_task_state_lifecycle_reconciles_current_targets",
		"behavior_policy": "saved_tasks_reused_only_while_current_and_open",
		"save_policy": "hero_task_state_live_persist_no_save_migration",
		"case": case_report,
		"save_version_before": int(SessionStateStore.SAVE_VERSION),
		"save_version_after": int(SessionStateStore.SAVE_VERSION),
	}
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _river_pass_saved_task_lifecycle_case() -> Dictionary:
	var session = _base_session()
	session.day = 2
	var config := _enemy_config()
	_set_resource_controller(session, "river_free_company", "player")
	_set_resource_controller(session, "river_signal_post", MIRECLAW)
	_seed_task_board(session)
	var raid := _raid_seed(session, "hero_vaska", "lifecycle_vaska_saved_task", {"x": 7, "y": 1})
	var plan := EnemyAdventureRules.ai_hero_task_saved_target_selection_plan(session, config, raid)
	if String(plan.get("target_kind", "")) != "resource" or String(plan.get("target_placement_id", "")) != "river_free_company":
		_fail("Saved live task was not reused for Vaska: %s" % JSON.stringify(plan))
		return {}
	var reason_codes := _string_array(plan.get("target_reason_codes", []))
	if "saved_hero_task" not in reason_codes:
		_fail("Saved task plan did not expose saved_hero_task reason: %s" % JSON.stringify(plan))
		return {}
	var task_state_before_normalize := _task_state(session)
	_assert_task_status(task_state_before_normalize, "hero_vaska", "river_free_company", "active", "valid")
	_assert_task_status(task_state_before_normalize, "hero_sable", "river_signal_post", "completed", "valid")
	_assert_task_status(task_state_before_normalize, "hero_tarn", "missing_resource_target", "invalid", "invalid_target_missing")
	_assert_task_status(task_state_before_normalize, "hero_morga", "riverwatch_embergrain_granary", "cancelled", "invalid_task_expired")
	_assert_task_status(task_state_before_normalize, "hero_nix", "duskfen_bastion", "completed", "valid")
	if _failed:
		return {}
	EnemyTurnRules.normalize_enemy_states(session)
	var task_state_after_normalize := _task_state(session)
	_assert_task_status(task_state_after_normalize, "hero_tarn", "missing_resource_target", "invalid", "invalid_target_missing")
	_assert_task_status(task_state_after_normalize, "hero_morga", "riverwatch_embergrain_granary", "cancelled", "invalid_task_expired")
	if _failed:
		return {}
	return {
		"case_id": "river_pass_saved_tasks_reconcile_before_reuse",
		"reused_target_id": String(plan.get("target_placement_id", "")),
		"reason_codes": reason_codes,
		"planner_epoch_before_normalize": int(task_state_before_normalize.get("planner_epoch", 0)),
		"task_status_counts": _task_status_counts(task_state_after_normalize),
		"save_version": int(SessionStateStore.SAVE_VERSION),
	}

func _seed_task_board(session) -> void:
	var state := _enemy_state(session)
	state["hero_task_state"] = {
		"schema_version": 1,
		"planner_epoch": 2,
		"tasks": [
			_task("hero_vaska", "resource", "river_free_company", "retake_site", "active", "valid", 8),
			_task("hero_sable", "resource", "river_signal_post", "retake_site", "active", "valid", 8),
			_task("hero_tarn", "resource", "missing_resource_target", "contest_site", "active", "valid", 8),
			_task("hero_morga", "resource", "riverwatch_embergrain_granary", "contest_site", "active", "valid", 1),
			_task("hero_nix", "town", "duskfen_bastion", "raid_town", "active", "valid", 8),
		],
	}
	_update_enemy_state(session, state)

func _task(
	actor_id: String,
	target_kind: String,
	target_id: String,
	task_class: String,
	status: String,
	validation: String,
	expires_day: int
) -> Dictionary:
	return {
		"task_id": "task:lifecycle:%s:%s" % [actor_id, target_id],
		"owner_faction_id": MIRECLAW,
		"actor_kind": "commander_roster",
		"actor_id": actor_id,
		"source_kind": "saved_task_state",
		"source_id": "lifecycle_fixture",
		"task_class": task_class,
		"task_status": status,
		"target_kind": target_kind,
		"target_id": target_id,
		"front_id": "%s:%s" % [target_kind, target_id],
		"origin_kind": "town",
		"origin_id": "duskfen_bastion",
		"priority_reason_codes": ["lifecycle_fixture"],
		"assigned_day": 1,
		"expires_day": expires_day,
		"continuity_policy": "persist_until_invalid",
		"route_policy": "derive_route_on_turn",
		"last_validation": validation,
		"reservation": {
			"reservation_status": "primary",
			"reservation_scope": "exclusive_target",
			"reservation_key": "%s:%s" % [target_kind, target_id],
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

func _task_state(session) -> Dictionary:
	var state := _enemy_state(session)
	return state.get("hero_task_state", {}) if state.get("hero_task_state", {}) is Dictionary else {}

func _assert_task_status(task_state: Dictionary, actor_id: String, target_id: String, expected_status: String, expected_validation: String) -> void:
	var tasks: Array = task_state.get("tasks", []) if task_state.get("tasks", []) is Array else []
	for task in tasks:
		if task is Dictionary and String(task.get("actor_id", "")) == actor_id and String(task.get("target_id", "")) == target_id:
			if String(task.get("task_status", "")) != expected_status or String(task.get("last_validation", "")) != expected_validation:
				_fail("Task %s/%s expected %s/%s, got %s" % [actor_id, target_id, expected_status, expected_validation, JSON.stringify(task)])
			return
	_fail("Missing task %s/%s in %s" % [actor_id, target_id, JSON.stringify(task_state)])

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
