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
	var personality_case := _planner_uses_commander_personality_fit()
	if personality_case.is_empty():
		return
	var global_fit_case := _planner_assigns_specialized_target_globally()
	if global_fit_case.is_empty():
		return
	var adaptive_case := _planner_uses_commander_outcome_memory()
	if adaptive_case.is_empty():
		return
	var role_adoption_case := _planner_adopts_live_commander_role_state()
	if role_adoption_case.is_empty():
		return
	var duplicate_recovery_case := _planner_recovers_duplicate_reservation_with_alternate_task()
	if duplicate_recovery_case.is_empty():
		return
	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"schema_status": "coordinated_task_planner_live_behavior",
		"behavior_policy": "enemy_turn_planner_seeds_distinct_commander_tasks_scores_targets_by_global_commander_identity_adaptive_outcome_memory_live_role_continuity_and_duplicate_reservation_recovery",
		"save_policy": "hero_task_state_live_persist_no_save_migration",
		"case": planner_case,
		"multi_origin_case": multi_origin_case,
		"personality_case": personality_case,
		"global_fit_case": global_fit_case,
		"adaptive_case": adaptive_case,
		"role_adoption_case": role_adoption_case,
		"duplicate_recovery_case": duplicate_recovery_case,
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
	var planned_keys := _task_keys(planned_tasks)
	var pressure_target_result := EnemyTurnRules._pressure_summary_target(
		session,
		config,
		planned_state,
		{"x": 7, "y": 2}
	)
	var pressure_target: Dictionary = pressure_target_result.get("target", {}) if pressure_target_result.get("target", {}) is Dictionary else {}
	var pressure_target_key := "%s:%s" % [String(pressure_target.get("target_kind", "")), String(pressure_target.get("target_placement_id", ""))]
	if String(pressure_target_result.get("source", "")) != "hero_task_state" or pressure_target_key not in planned_keys:
		_fail("Pressure summary did not reuse one of the durable planned commander targets: %s / %s" % [JSON.stringify(pressure_target_result), JSON.stringify(planned_keys)])
		return {}
	if String(pressure_target.get("target_label", "")) == "" or String(pressure_target.get("hero_task_id", "")) == "":
		_fail("Pressure summary task target is missing player-facing label or task identity: %s" % JSON.stringify(pressure_target))
		return {}
	var fallback_state := planned_state.duplicate(true)
	fallback_state.erase("hero_task_state")
	var fallback_target_result := EnemyTurnRules._pressure_summary_target(
		session,
		config,
		fallback_state,
		{"x": 7, "y": 2}
	)
	if String(fallback_target_result.get("source", "")) != "fresh_target_scan" \
			or not (fallback_target_result.get("target", {}) is Dictionary) \
			or fallback_target_result.get("target", {}).is_empty():
		_fail("Pressure summary did not retain a fresh target-scan fallback without a durable task board: %s" % JSON.stringify(fallback_target_result))
		return {}
	_update_enemy_state(session, planned_state)

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
		"pressure_target_key": pressure_target_key,
		"pressure_target_source": String(pressure_target_result.get("source", "")),
		"fallback_target_source": String(fallback_target_result.get("source", "")),
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

func _planner_uses_commander_personality_fit() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config()
	var origin := {"kind": "town", "placement_id": "duskfen_bastion", "x": 7, "y": 2}
	var hero_id := String(session.overworld.get("active_hero_id", ""))
	if hero_id == "":
		_fail("Personality fixture expected an active hero id")
		return {}
	var candidates := [
		{
			"target_kind": "artifact",
			"target_placement_id": "trailsinger_cache",
			"target_label": "Trailsinger Cache",
			"target_x": 2,
			"target_y": 0,
			"goal_x": 2,
			"goal_y": 0,
			"goal_distance": 5,
			"priority": 100,
			"target_reason_codes": ["artifact_pressure", "magic_support"],
			"target_public_reason": "magic relic",
			"target_public_importance": "medium",
		},
		{
			"target_kind": "hero",
			"target_placement_id": hero_id,
			"target_label": "Exposed Hero",
			"target_x": 1,
			"target_y": 2,
			"goal_x": 1,
			"goal_y": 2,
			"goal_distance": 5,
			"priority": 100,
			"target_reason_codes": ["hero_hunt", "exposed_hero"],
			"target_public_reason": "exposed hero",
			"target_public_importance": "high",
		},
	]
	var vaska_task := EnemyAdventureRules._ai_hero_task_planner_task_for_actor(
		session,
		config,
		MIRECLAW,
		"hero_vaska",
		origin,
		candidates,
		{},
		1
	)
	var sable_task := EnemyAdventureRules._ai_hero_task_planner_task_for_actor(
		session,
		config,
		MIRECLAW,
		"hero_sable",
		origin,
		candidates,
		{},
		2
	)
	if String(vaska_task.get("target_kind", "")) != "hero":
		_fail("Raider commander should prefer exposed hero pressure, got %s" % JSON.stringify(vaska_task))
		return {}
	if String(sable_task.get("target_kind", "")) != "artifact":
		_fail("Magic commander should prefer magic artifact pressure, got %s" % JSON.stringify(sable_task))
		return {}
	if int(vaska_task.get("commander_fit_bonus", 0)) <= 0 or int(sable_task.get("commander_fit_bonus", 0)) <= 0:
		_fail("Personality-fit tasks should persist positive fit metadata: %s / %s" % [JSON.stringify(vaska_task), JSON.stringify(sable_task)])
		return {}
	return {
		"case_id": "commander_personality_fit_changes_target_choice",
		"raider_actor_id": "hero_vaska",
		"raider_target_key": "%s:%s" % [String(vaska_task.get("target_kind", "")), String(vaska_task.get("target_id", ""))],
		"raider_fit_bonus": int(vaska_task.get("commander_fit_bonus", 0)),
		"raider_fit_profile": String(vaska_task.get("commander_fit_profile", "")),
		"magic_actor_id": "hero_sable",
		"magic_target_key": "%s:%s" % [String(sable_task.get("target_kind", "")), String(sable_task.get("target_id", ""))],
		"magic_fit_bonus": int(sable_task.get("commander_fit_bonus", 0)),
		"magic_fit_profile": String(sable_task.get("commander_fit_profile", "")),
	}

func _planner_assigns_specialized_target_globally() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config()
	var origin := {"kind": "town", "placement_id": "duskfen_bastion", "x": 7, "y": 2}
	var hero_id := String(session.overworld.get("active_hero_id", ""))
	if hero_id == "":
		_fail("Global-fit fixture expected an active hero id")
		return {}
	var candidates := [
		{
			"target_kind": "artifact",
			"target_placement_id": "trailsinger_cache",
			"target_label": "Trailsinger Cache",
			"target_x": 2,
			"target_y": 0,
			"goal_x": 2,
			"goal_y": 0,
			"goal_distance": 5,
			"priority": 120,
			"target_reason_codes": ["artifact_pressure", "magic_support"],
			"target_public_reason": "magic relic",
			"target_public_importance": "medium",
		},
		{
			"target_kind": "hero",
			"target_placement_id": hero_id,
			"target_label": "Exposed Hero",
			"target_x": 1,
			"target_y": 2,
			"goal_x": 1,
			"goal_y": 2,
			"goal_distance": 5,
			"priority": 20,
			"target_reason_codes": ["hero_hunt", "exposed_hero"],
			"target_public_reason": "exposed hero",
			"target_public_importance": "high",
		},
	]
	var vaska_greedy_task := EnemyAdventureRules._ai_hero_task_planner_task_for_actor(
		session,
		config,
		MIRECLAW,
		"hero_vaska",
		origin,
		candidates,
		{},
		1
	)
	if String(vaska_greedy_task.get("target_kind", "")) != "artifact":
		_fail("Global-fit fixture expected roster-order Vaska to greedily claim artifact before global assignment, got %s" % JSON.stringify(vaska_greedy_task))
		return {}
	var roster := [
		_commander_entry(session, MIRECLAW, "hero_vaska"),
		_commander_entry(session, MIRECLAW, "hero_sable"),
	]
	var assignments := EnemyAdventureRules._ai_hero_task_planner_global_task_assignments(
		session,
		config,
		MIRECLAW,
		roster,
		origin,
		candidates,
		{},
		[],
		1
	)
	if assignments.size() < 2:
		_fail("Global-fit assignment should allocate both commanders, got %s" % JSON.stringify(assignments))
		return {}
	var vaska_task := _task_for_actor_id(assignments, "hero_vaska")
	var sable_task := _task_for_actor_id(assignments, "hero_sable")
	if String(sable_task.get("target_kind", "")) != "artifact" or String(sable_task.get("target_id", "")) != "trailsinger_cache":
		_fail("Global-fit assignment should reserve magic artifact for Sable, got %s assignments=%s" % [JSON.stringify(sable_task), JSON.stringify(assignments)])
		return {}
	if String(vaska_task.get("target_kind", "")) != "hero" or String(vaska_task.get("target_id", "")) != hero_id:
		_fail("Global-fit assignment should move Vaska to the alternate hero pressure target, got %s assignments=%s" % [JSON.stringify(vaska_task), JSON.stringify(assignments)])
		return {}
	if int(sable_task.get("commander_fit_bonus", 0)) <= int(vaska_greedy_task.get("commander_fit_bonus", 0)):
		_fail("Global-fit fixture expected Sable's artifact fit to beat Vaska's artifact fit: sable=%s vaska=%s" % [JSON.stringify(sable_task), JSON.stringify(vaska_greedy_task)])
		return {}
	return {
		"case_id": "global_commander_task_assignment_preserves_specialist_target",
		"greedy_first_actor": "hero_vaska",
		"greedy_first_target_key": "%s:%s" % [String(vaska_greedy_task.get("target_kind", "")), String(vaska_greedy_task.get("target_id", ""))],
		"specialist_actor": "hero_sable",
		"specialist_target_key": "%s:%s" % [String(sable_task.get("target_kind", "")), String(sable_task.get("target_id", ""))],
		"specialist_fit_bonus": int(sable_task.get("commander_fit_bonus", 0)),
		"alternate_actor": "hero_vaska",
		"alternate_target_key": "%s:%s" % [String(vaska_task.get("target_kind", "")), String(vaska_task.get("target_id", ""))],
		"alternate_fit_bonus": int(vaska_task.get("commander_fit_bonus", 0)),
	}

func _planner_uses_commander_outcome_memory() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config()
	var origin := {"kind": "town", "placement_id": "duskfen_bastion", "x": 7, "y": 2}
	var hero_id := String(session.overworld.get("active_hero_id", ""))
	if hero_id == "":
		_fail("Adaptive-memory fixture expected an active hero id")
		return {}
	var candidates := [
		{
			"target_kind": "artifact",
			"target_placement_id": "trailsinger_cache",
			"target_label": "Trailsinger Cache",
			"target_x": 2,
			"target_y": 0,
			"goal_x": 2,
			"goal_y": 0,
			"goal_distance": 5,
			"priority": 100,
			"target_reason_codes": ["artifact_pressure", "magic_support"],
			"target_public_reason": "magic relic",
			"target_public_importance": "medium",
		},
		{
			"target_kind": "hero",
			"target_placement_id": hero_id,
			"target_label": "Exposed Hero",
			"target_x": 1,
			"target_y": 2,
			"goal_x": 1,
			"goal_y": 2,
			"goal_distance": 5,
			"priority": 180,
			"target_reason_codes": ["hero_hunt", "exposed_hero"],
			"target_public_reason": "exposed hero",
			"target_public_importance": "high",
		},
	]
	var initial_task := EnemyAdventureRules._ai_hero_task_planner_task_for_actor(
		session,
		config,
		MIRECLAW,
		"hero_sable",
		origin,
		candidates,
		{},
		1
	)
	if String(initial_task.get("target_kind", "")) != "artifact":
		_fail("Magic commander fixture should start by preferring artifact pressure before outcome memory, got %s" % JSON.stringify(initial_task))
		return {}
	var entry := _commander_entry(session, MIRECLAW, "hero_sable")
	var commander_state: Dictionary = entry.get("commander_state", {}) if entry.get("commander_state", {}) is Dictionary else {}
	commander_state = EnemyAdventureRules.record_target_assignment(
		commander_state,
		"hero",
		hero_id,
		"Exposed Hero",
		1,
		2
	)
	commander_state = EnemyAdventureRules.advance_commander_record(
		commander_state,
		EnemyAdventureRules.COMMANDER_OUTCOME_FIELD_VICTORY
	)
	commander_state = EnemyAdventureRules.record_target_assignment(
		commander_state,
		"hero",
		hero_id,
		"Exposed Hero",
		1,
		2
	)
	commander_state = EnemyAdventureRules.advance_commander_record(
		commander_state,
		EnemyAdventureRules.COMMANDER_OUTCOME_PURSUIT_VICTORY
	)
	var direct_memory := EnemyAdventureRules.commander_target_memory(commander_state)
	var direct_success_counts: Dictionary = direct_memory.get("target_success_counts", {}) if direct_memory.get("target_success_counts", {}) is Dictionary else {}
	if int(direct_success_counts.get("hero", 0)) < 2:
		_fail("Outcome memory did not update on commander state before roster sync: %s" % JSON.stringify(direct_memory))
		return {}
	EnemyAdventureRules.sync_commander_state_to_roster(
		session,
		MIRECLAW,
		commander_state,
		EnemyAdventureRules.COMMANDER_STATUS_AVAILABLE,
		"",
		0,
		EnemyAdventureRules.COMMANDER_OUTCOME_PURSUIT_VICTORY
	)
	var adapted_task := EnemyAdventureRules._ai_hero_task_planner_task_for_actor(
		session,
		config,
		MIRECLAW,
		"hero_sable",
		origin,
		candidates,
		{},
		2
	)
	var memory := EnemyAdventureRules.commander_target_memory(_commander_entry(session, MIRECLAW, "hero_sable"))
	var artifact_fit := EnemyAdventureRules._ai_commander_task_fit_bonus(session, MIRECLAW, "hero_sable", candidates[0])
	var hero_fit := EnemyAdventureRules._ai_commander_task_fit_bonus(session, MIRECLAW, "hero_sable", candidates[1])
	if String(adapted_task.get("target_kind", "")) != "hero":
		_fail("Outcome memory should shift experienced commander toward successful hero pressure, got %s memory=%s artifact_fit=%d hero_fit=%d" % [JSON.stringify(adapted_task), JSON.stringify(memory), artifact_fit, hero_fit])
		return {}
	var success_counts: Dictionary = memory.get("target_success_counts", {}) if memory.get("target_success_counts", {}) is Dictionary else {}
	if int(success_counts.get("hero", 0)) < 2:
		_fail("Outcome memory did not preserve hero success counts: %s" % JSON.stringify(memory))
		return {}
	return {
		"case_id": "commander_outcome_memory_changes_future_task_choice",
		"actor_id": "hero_sable",
		"initial_target_key": "%s:%s" % [String(initial_task.get("target_kind", "")), String(initial_task.get("target_id", ""))],
		"adapted_target_key": "%s:%s" % [String(adapted_task.get("target_kind", "")), String(adapted_task.get("target_id", ""))],
		"hero_success_count": int(success_counts.get("hero", 0)),
		"adapted_fit_bonus": int(adapted_task.get("commander_fit_bonus", 0)),
		"adapted_fit_profile": String(adapted_task.get("commander_fit_profile", "")),
	}

func _planner_adopts_live_commander_role_state() -> Dictionary:
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
	var plan_result := EnemyAdventureRules.plan_enemy_hero_task_board(session, config, state)
	var planned_state: Dictionary = plan_result.get("state", {})
	var adopted_task := _first_planned_task_for_kind(planned_state, "resource")
	if adopted_task.is_empty():
		_fail("Role adoption fixture expected a planned resource task, got %s" % JSON.stringify(plan_result))
		return {}
	var actor_id := String(adopted_task.get("actor_id", ""))
	var entry := _commander_entry_from_state(planned_state, actor_id)
	var role_state := EnemyAdventureRules.commander_live_role_state(entry)
	if role_state.is_empty():
		_fail("Planner did not persist live commander role state for %s in %s" % [actor_id, JSON.stringify(entry)])
		return {}
	if String(role_state.get("target_kind", "")) != String(adopted_task.get("target_kind", "")) or String(role_state.get("target_id", "")) != String(adopted_task.get("target_id", "")):
		_fail("Role state target does not match adopted task: role=%s task=%s" % [JSON.stringify(role_state), JSON.stringify(adopted_task)])
		return {}
	if String(role_state.get("role", "")) != String(adopted_task.get("source_role", "")):
		_fail("Role state did not preserve task source_role: role=%s task=%s" % [JSON.stringify(role_state), JSON.stringify(adopted_task)])
		return {}
	_update_enemy_state(session, planned_state)
	var same_candidate := {
		"target_kind": "resource",
		"target_placement_id": String(adopted_task.get("target_id", "")),
		"priority": 100,
		"target_reason_codes": adopted_task.get("priority_reason_codes", []),
	}
	var rival_id := "river_signal_post" if String(adopted_task.get("target_id", "")) != "river_signal_post" else "river_free_company"
	var rival_candidate := {
		"target_kind": "resource",
		"target_placement_id": rival_id,
		"priority": 100,
		"target_reason_codes": ["persistent_income_denial", "route_pressure", "strategic_task_planner"],
	}
	var same_fit := EnemyAdventureRules._ai_commander_task_fit_bonus(session, MIRECLAW, actor_id, same_candidate)
	var rival_fit := EnemyAdventureRules._ai_commander_task_fit_bonus(session, MIRECLAW, actor_id, rival_candidate)
	if same_fit <= rival_fit:
		_fail("Live role continuity should favor the adopted front: same=%d rival=%d role=%s" % [same_fit, rival_fit, JSON.stringify(role_state)])
		return {}
	return {
		"case_id": "planner_persists_live_role_state_and_scores_continuity",
		"actor_id": actor_id,
		"role": String(role_state.get("role", "")),
		"source_policy": String(role_state.get("source_policy", "")),
		"target_key": "%s:%s" % [String(role_state.get("target_kind", "")), String(role_state.get("target_id", ""))],
		"same_target_fit": same_fit,
		"rival_fit": rival_fit,
	}

func _planner_recovers_duplicate_reservation_with_alternate_task() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config()
	var state := _enemy_state(session)
	state["raid_counter"] = 0
	state["commander_counter"] = 0
	state["pressure"] = 0
	_set_resource_controller(session, "river_free_company", "player")
	_set_resource_controller(session, "river_signal_post", "player")
	state["hero_task_state"] = {
		"schema_version": 1,
		"planner_epoch": 4,
		"tasks": [
			_saved_resource_task("hero_sable", "river_free_company", 1),
			_saved_resource_task("hero_vaska", "river_free_company", 2),
		],
	}
	_update_enemy_state(session, state)
	var plan_result := EnemyAdventureRules.plan_enemy_hero_task_board(session, config, state)
	var planned_state: Dictionary = plan_result.get("state", {})
	var task_state: Dictionary = planned_state.get("hero_task_state", {}) if planned_state.get("hero_task_state", {}) is Dictionary else {}
	var tasks: Array = task_state.get("tasks", []) if task_state.get("tasks", []) is Array else []
	var primary := _task_for_target_status(tasks, "river_free_company", "planned")
	if primary.is_empty():
		_fail("Duplicate recovery should preserve one primary Free Company task: %s" % JSON.stringify(tasks))
		return {}
	var invalid_duplicate := _invalid_reserved_task(tasks)
	if invalid_duplicate.is_empty():
		_fail("Duplicate recovery should preserve invalidated duplicate history: %s" % JSON.stringify(tasks))
		return {}
	var displaced_actor := String(invalid_duplicate.get("actor_id", ""))
	var alternate := _planned_task_for_actor(tasks, displaced_actor, "river_free_company")
	if alternate.is_empty():
		_fail("Duplicate recovery did not assign alternate planned task for displaced actor %s: %s" % [displaced_actor, JSON.stringify(tasks)])
		return {}
	var reservation_check := EnemyAdventureRules.ai_hero_task_target_reservation_check(tasks)
	if not bool(reservation_check.get("ok", false)):
		_fail("Duplicate recovery left invalid reservation state: %s" % JSON.stringify(reservation_check))
		return {}
	return {
		"case_id": "planner_recovers_duplicate_reservation_with_alternate_task",
		"primary_actor": String(primary.get("actor_id", "")),
		"displaced_actor": displaced_actor,
		"invalidated_by_task_id": String(invalid_duplicate.get("invalidated_by_task_id", "")),
		"alternate_target_key": "%s:%s" % [String(alternate.get("target_kind", "")), String(alternate.get("target_id", ""))],
		"planned_count": int(plan_result.get("planned_count", 0)),
		"task_count": tasks.size(),
		"reservation_primary_count": int(reservation_check.get("primary_reservation_count", 0)),
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

func _commander_entry(session, faction_id: String, roster_hero_id: String) -> Dictionary:
	for entry in EnemyAdventureRules.commander_roster_for_faction(session, faction_id):
		if entry is Dictionary and String(entry.get("roster_hero_id", "")) == roster_hero_id:
			return entry
	_fail("Could not find commander %s for %s" % [roster_hero_id, faction_id])
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

func _planned_task_for_actor(tasks: Array, actor_id: String, excluded_target_id: String) -> Dictionary:
	for task_value in tasks:
		if not (task_value is Dictionary):
			continue
		var task: Dictionary = task_value
		if String(task.get("actor_id", "")) != actor_id:
			continue
		if String(task.get("task_status", "")) != "planned":
			continue
		if String(task.get("target_id", "")) == excluded_target_id:
			continue
		return task
	return {}

func _task_for_actor_id(tasks: Array, actor_id: String) -> Dictionary:
	for task_value in tasks:
		if task_value is Dictionary and String(task_value.get("actor_id", "")) == actor_id:
			return task_value
	return {}

func _task_for_target_status(tasks: Array, target_id: String, status: String) -> Dictionary:
	for task_value in tasks:
		if not (task_value is Dictionary):
			continue
		var task: Dictionary = task_value
		if String(task.get("target_id", "")) == target_id and String(task.get("task_status", "")) == status:
			return task
	return {}

func _invalid_reserved_task(tasks: Array) -> Dictionary:
	for task_value in tasks:
		if not (task_value is Dictionary):
			continue
		var task: Dictionary = task_value
		if String(task.get("task_status", "")) == "invalid" and String(task.get("last_validation", "")) == "invalid_target_reserved":
			return task
	return {}

func _saved_resource_task(actor_id: String, target_id: String, sequence: int) -> Dictionary:
	return {
		"task_id": "task:%s:%s:%s:contest_site:resource:%s:day_1:seq_%d" % [RIVER_PASS, MIRECLAW, actor_id, target_id, sequence],
		"owner_faction_id": MIRECLAW,
		"actor_kind": "commander_roster",
		"actor_id": actor_id,
		"source_kind": "saved_task_state",
		"source_id": "duplicate_reservation_fixture",
		"task_class": "contest_site",
		"task_status": "planned",
		"target_kind": "resource",
		"target_id": target_id,
		"front_id": EnemyAdventureRules.commander_role_front_id(RIVER_PASS, "resource", target_id),
		"origin_kind": "town",
		"origin_id": "duskfen_bastion",
		"origin_x": 7,
		"origin_y": 2,
		"priority_reason_codes": ["persistent_income_denial", "strategic_task_planner", "duplicate_reservation_fixture"],
		"assigned_day": 1,
		"expires_day": 11,
		"continuity_policy": "persist_until_invalid",
		"route_policy": "derive_route_on_turn",
		"last_validation": "valid",
		"reservation": {
			"reservation_status": "primary",
			"reservation_scope": "exclusive_target",
			"reservation_key": "resource:%s" % target_id,
		},
	}

func _first_planned_task_for_kind(state: Dictionary, target_kind: String) -> Dictionary:
	for task_value in _planned_tasks(state):
		if task_value is Dictionary and String(task_value.get("target_kind", "")) == target_kind:
			return task_value
	return {}

func _commander_entry_from_state(state: Dictionary, roster_hero_id: String) -> Dictionary:
	var roster: Array = state.get("commander_roster", []) if state.get("commander_roster", []) is Array else []
	for entry in roster:
		if entry is Dictionary and String(entry.get("roster_hero_id", "")) == roster_hero_id:
			return entry
	_fail("Could not find commander %s in planned state" % roster_hero_id)
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
