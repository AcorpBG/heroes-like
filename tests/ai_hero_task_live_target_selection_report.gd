extends Node

const REPORT_ID := "AI_HERO_TASK_LIVE_TARGET_SELECTION_REPORT"
const RIVER_PASS := "river-pass"
const MIRECLAW := "faction_mireclaw"

var _failed := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var primary_case := _river_pass_primary_target_case()
	if primary_case.is_empty():
		return
	var companion_case := _river_pass_companion_reservation_case()
	if companion_case.is_empty():
		return
	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"schema_status": "live_target_selection_persists_task_board",
		"behavior_policy": "commander_candidate_tasks_drive_new_raid_targets",
		"save_policy": "hero_task_state_live_persist_no_save_migration",
		"cases": [primary_case, companion_case],
		"save_version_before": int(SessionStateStore.SAVE_VERSION),
		"save_version_after": int(SessionStateStore.SAVE_VERSION),
	}
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _river_pass_primary_target_case() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config()
	_set_resource_controller(session, "river_free_company", "player")
	_set_resource_controller(session, "river_signal_post", "player")
	var raid := _raid_seed(session, config, "hero_vaska", "live_target_vaska_probe", {"x": 7, "y": 1})
	var existing_selector := EnemyAdventureRules.choose_target(session, config, {"x": 7, "y": 1}, raid.get("enemy_commander_state", {}))
	var live_plan := EnemyAdventureRules.ai_hero_task_live_target_selection_plan(session, config, raid)
	_assert_target(live_plan, "river_free_company", "primary live plan")
	var assigned := EnemyAdventureRules.assign_target(session, config, raid)
	_assert_target(assigned, "river_free_company", "assigned raid")
	_assert_saved_task_state(session, "hero_vaska", "river_free_company")
	_assert_commander_role_state(session, "hero_vaska", "river_free_company", "live_target_assignment")
	var event := EnemyAdventureRules.ai_target_assignment_event(session, config, assigned, {})
	var public_log := EnemyAdventureRules.ai_public_event_log_boundary_report([event], 1)
	if not bool(public_log.get("ok", false)):
		_fail("Primary assignment public event did not pass compact log boundary: %s" % JSON.stringify(public_log))
		return {}
	return {
		"case_id": "river_pass_vaska_live_task_targets_free_company",
		"chosen_without_live_plan": "%s:%s" % [
			String(existing_selector.get("target_kind", "")),
			String(existing_selector.get("target_placement_id", "")),
		],
		"live_target_kind": String(live_plan.get("target_kind", "")),
		"live_target_id": String(live_plan.get("target_placement_id", "")),
		"assigned_target_id": String(assigned.get("target_placement_id", "")),
		"public_event_count": int(public_log.get("public_event_count", 0)),
	}

func _river_pass_companion_reservation_case() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config()
	_set_resource_controller(session, "river_free_company", "player")
	_set_resource_controller(session, "river_signal_post", "player")
	var vaska := _raid_seed(session, config, "hero_vaska", "live_target_vaska_active", {"x": 1, "y": 4})
	vaska = EnemyAdventureRules.assign_target(session, config, vaska)
	var encounters: Array = session.overworld.get("encounters", [])
	encounters.append(vaska)
	session.overworld["encounters"] = encounters
	EnemyAdventureRules.normalize_all_commander_rosters(session)
	var sable := _raid_seed(session, config, "hero_sable", "live_target_sable_probe", {"x": 7, "y": 1})
	var live_plan := EnemyAdventureRules.ai_hero_task_live_target_selection_plan(session, config, sable)
	_assert_target(live_plan, "river_signal_post", "companion live plan")
	var assigned := EnemyAdventureRules.assign_target(session, config, sable)
	_assert_target(assigned, "river_signal_post", "companion assigned raid")
	_assert_saved_task_state(session, "hero_vaska", "river_free_company")
	_assert_saved_task_state(session, "hero_sable", "river_signal_post")
	_assert_commander_role_state(session, "hero_sable", "river_signal_post", "live_target_assignment")
	return {
		"case_id": "river_pass_sable_respects_free_company_reservation",
		"reserved_target_id": String(vaska.get("target_placement_id", "")),
		"live_target_kind": String(live_plan.get("target_kind", "")),
		"live_target_id": String(live_plan.get("target_placement_id", "")),
		"assigned_target_id": String(assigned.get("target_placement_id", "")),
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

func _enemy_config() -> Dictionary:
	var scenario := ContentService.get_scenario(RIVER_PASS)
	for config in scenario.get("enemy_factions", []):
		if config is Dictionary and String(config.get("faction_id", "")) == MIRECLAW:
			return config
	_fail("Could not find enemy config for %s" % MIRECLAW)
	return {}

func _assert_target(plan: Dictionary, expected_target_id: String, label: String) -> void:
	if String(plan.get("target_kind", "")) != "resource" or String(plan.get("target_placement_id", "")) != expected_target_id:
		_fail("%s expected resource %s, got %s" % [label, expected_target_id, JSON.stringify(plan)])

func _assert_saved_task_state(session, actor_id: String, target_id: String) -> void:
	for state in session.overworld.get("enemy_states", []):
		if not (state is Dictionary) or String(state.get("faction_id", "")) != MIRECLAW:
			continue
		var task_state: Dictionary = state.get("hero_task_state", {}) if state.get("hero_task_state", {}) is Dictionary else {}
		var tasks: Array = task_state.get("tasks", []) if task_state.get("tasks", []) is Array else []
		for task_value in tasks:
			if task_value is Dictionary \
					and String(task_value.get("actor_id", "")) == actor_id \
					and String(task_value.get("target_id", "")) == target_id \
					and String(task_value.get("task_status", "")) in ["planned", "reserved", "active", "completed"]:
				return
		_fail("Live target selection did not persist task %s -> %s: %s" % [actor_id, target_id, JSON.stringify(task_state)])
		return
	_fail("Live target selection could not find Mireclaw enemy task state.")

func _assert_commander_role_state(session, actor_id: String, target_id: String, source_policy: String) -> void:
	for entry in EnemyAdventureRules.commander_roster_for_faction(session, MIRECLAW):
		if not (entry is Dictionary) or String(entry.get("roster_hero_id", "")) != actor_id:
			continue
		var role_state := EnemyAdventureRules.commander_live_role_state(entry)
		if String(role_state.get("target_id", "")) != target_id or String(role_state.get("source_policy", "")) != source_policy:
			_fail("Commander role state mismatch for %s -> %s: %s" % [actor_id, target_id, JSON.stringify(role_state)])
			return
		if String(role_state.get("role", "")) == "":
			_fail("Commander role state omitted role for %s: %s" % [actor_id, JSON.stringify(role_state)])
			return
		return
	_fail("Could not find commander %s for role-state check." % actor_id)

func _fail(message: String) -> void:
	var payload := {"ok": false, "report_id": REPORT_ID, "error": message}
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	_failed = true
	get_tree().quit(1)
