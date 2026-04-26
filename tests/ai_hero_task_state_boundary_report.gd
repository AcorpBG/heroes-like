extends Node

const REPORT_ID := "AI_HERO_TASK_STATE_BOUNDARY_REPORT"
const RIVER_PASS := "river-pass"
const GLASSROAD := "glassroad-sundering"
const MIRECLAW := "faction_mireclaw"
const EMBERCOURT := "faction_embercourt"
const RIVER_ORIGIN := {"x": 7, "y": 1}
const GLASSROAD_ORIGIN := {"x": 9, "y": 1}
const TREASURY := {"gold": 5200, "wood": 8, "ore": 8}

var _failed := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var cases := []
	cases.append(_river_pass_free_company_task_candidate())
	cases.append(_river_pass_signal_post_companion_task_candidate())
	cases.append(_glassroad_relay_retake_to_defend_transition())
	cases.append(_glassroad_starlens_stabilizer_candidate())
	cases.append(_commander_recovery_rebuild_blocks_task_claim())
	cases.append(_old_save_no_task_state_compatibility())
	cases.append(_duplicate_target_reservation_report_only())
	if _failed:
		return

	var public_events := []
	var per_case_id_checks := []
	var per_case_reservation_checks := []
	var ownership_tasks := []
	var invalidation_tasks := []
	var transitions := []
	for case_report in cases:
		if not (case_report is Dictionary):
			continue
		if not bool(case_report.get("ok", false)):
			_fail("Case %s did not pass: %s" % [String(case_report.get("case_id", "")), JSON.stringify(case_report)])
			return
		var tasks: Array = case_report.get("candidate_tasks", [])
		if not tasks.is_empty():
			per_case_id_checks.append(EnemyAdventureRules.ai_hero_task_candidate_task_id_check(tasks))
			per_case_reservation_checks.append(EnemyAdventureRules.ai_hero_task_target_reservation_check(tasks))
			for task in tasks:
				ownership_tasks.append(task)
				invalidation_tasks.append(task)
		for event in case_report.get("public_task_events", []):
			if event is Dictionary:
				public_events.append(event)
		for transition in case_report.get("transition_checks", []):
			if transition is Dictionary:
				transitions.append(transition)

	var candidate_task_id_check := _combine_checks(per_case_id_checks)
	var actor_ownership_check := _multi_faction_actor_check(ownership_tasks)
	var target_ownership_check := _multi_faction_target_check(ownership_tasks)
	var role_to_task_source_check := EnemyAdventureRules.ai_hero_task_role_to_task_source_check(ownership_tasks)
	var target_reservation_check := _combine_checks(per_case_reservation_checks)
	var invalidation_check := EnemyAdventureRules.ai_hero_task_invalidation_check(invalidation_tasks, transitions)
	var old_save_absence_check: Dictionary = cases[5].get("old_save_absence_check", {})
	var public_leak_check := EnemyAdventureRules.ai_hero_task_public_leak_check(public_events)
	var checks := [
		candidate_task_id_check,
		actor_ownership_check,
		target_ownership_check,
		role_to_task_source_check,
		target_reservation_check,
		invalidation_check,
		old_save_absence_check,
		public_leak_check,
	]
	for check in checks:
		if not (check is Dictionary) or not bool(check.get("ok", false)):
			_fail("Top-level task-state boundary check failed: %s" % JSON.stringify(check))
			return

	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"schema_status": "task_state_boundary_report_only",
		"behavior_policy": "derive_candidate_tasks_only",
		"save_policy": "no_hero_task_state_write",
		"source_policy": "commander_role_adapter_from_report_snapshots",
		"save_version_before": SessionStateStore.SAVE_VERSION,
		"save_version_after": SessionStateStore.SAVE_VERSION,
		"cases": cases,
		"candidate_task_id_check": candidate_task_id_check,
		"actor_ownership_check": actor_ownership_check,
		"target_ownership_check": target_ownership_check,
		"role_to_task_source_check": role_to_task_source_check,
		"target_reservation_check": target_reservation_check,
		"invalidation_check": invalidation_check,
		"old_save_absence_check": old_save_absence_check,
		"public_leak_check": public_leak_check,
		"failure_conditions": [],
		"validation_caveats": [
			"Candidate tasks are derived from report snapshots and are never written to enemy_states.",
			"The relay transition case observes existing EnemyTurnRules.run_enemy_turn once; candidate tasks do not drive target selection, movement, arrival, or town-governor choices.",
			"Duplicate reservation arbitration is report-only and does not retarget the losing candidate.",
		],
	}
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _river_pass_free_company_task_candidate() -> Dictionary:
	var session = _base_session(RIVER_PASS)
	_set_resource_controller(session, "river_free_company", "player")
	_set_resource_controller(session, "river_signal_post", "player")
	var task := _resource_candidate(
		session,
		MIRECLAW,
		RIVER_ORIGIN,
		"hero_vaska",
		"river_free_company",
		{"fixture_previous_controller": MIRECLAW},
		1,
		"before_turn"
	)
	_assert_equal(String(task.get("task_id", "")), "task:river-pass:faction_mireclaw:hero_vaska:retake_site:resource:river_free_company:day_1:seq_1", "Free Company task id")
	_assert_contains(task.get("priority_reason_codes", []), "persistent_income_denial", "Free Company reason codes")
	_assert_contains(task.get("priority_reason_codes", []), "recruit_denial", "Free Company reason codes")
	return _case_result(session, MIRECLAW, "river_pass_free_company_task_candidate", [task], [])

func _river_pass_signal_post_companion_task_candidate() -> Dictionary:
	var session = _base_session(RIVER_PASS)
	_set_resource_controller(session, "river_free_company", "player")
	_set_resource_controller(session, "river_signal_post", "player")
	var task := _resource_candidate(
		session,
		MIRECLAW,
		RIVER_ORIGIN,
		"hero_sable",
		"river_signal_post",
		{"fixture_primary_target_covered": "river_free_company"},
		2,
		"before_turn"
	)
	_assert_equal(String(task.get("task_id", "")), "task:river-pass:faction_mireclaw:hero_sable:contest_site:resource:river_signal_post:day_1:seq_2", "Signal Post task id")
	_assert_equal(String(task.get("reservation", {}).get("reservation_key", "")), "resource:river_signal_post", "Signal Post reservation")
	return _case_result(session, MIRECLAW, "river_pass_signal_post_companion_task_candidate", [task], [])

func _glassroad_relay_retake_to_defend_transition() -> Dictionary:
	var session = _base_session(GLASSROAD)
	var config := _enemy_config(GLASSROAD, EMBERCOURT)
	_set_enemy_state_patch(session, EMBERCOURT, {"treasury": TREASURY.duplicate(true), "pressure": 0})
	_set_resource_controller(session, "glassroad_watch_relay", "player")
	_set_resource_controller(session, "glassroad_starlens", EMBERCOURT)
	_add_active_resource_raid(session, config, EMBERCOURT, "hero_caelen", "task_boundary_embercourt_caelen_raid", "encounter_ember_raid", "glassroad_watch_relay", {"x": 3, "y": 3})
	var before_task := _resource_candidate(
		session,
		EMBERCOURT,
		GLASSROAD_ORIGIN,
		"hero_caelen",
		"glassroad_watch_relay",
		{"fixture_previous_controller": EMBERCOURT},
		1,
		"before_turn"
	)
	var before_snapshot := _turn_snapshot(
		session,
		config,
		EMBERCOURT,
		GLASSROAD_ORIGIN,
		[
			{"roster_hero_id": "hero_caelen", "target_id": "glassroad_watch_relay", "fixture_state": {"fixture_previous_controller": EMBERCOURT}},
			{"roster_hero_id": "hero_seren", "target_id": "glassroad_starlens", "fixture_state": {"fixture_recently_secured": true}},
		],
		"glassroad_charter_front"
	)
	var turn_result := EnemyTurnRules.run_enemy_turn(session)
	if not bool(turn_result.get("ok", false)):
		_fail("Glassroad relay transition enemy turn failed")
		return {}
	var after_snapshot := _turn_snapshot(
		session,
		config,
		EMBERCOURT,
		GLASSROAD_ORIGIN,
		[
			{"roster_hero_id": "hero_caelen", "target_id": "glassroad_watch_relay", "fixture_state": {"fixture_threatened_by_player_front": true}},
			{"roster_hero_id": "hero_seren", "target_id": "glassroad_starlens", "fixture_state": {"fixture_recently_secured": true}},
		],
		"glassroad_charter_front"
	)
	var transcript := EnemyAdventureRules.commander_role_turn_transcript_report(before_snapshot, after_snapshot, config, turn_result, {"case_id": "task_boundary_glassroad_relay_transition"})
	var arrival := _arrival_for_target(transcript.get("raid_arrival_summary", []), "glassroad_watch_relay")
	if arrival.is_empty():
		_fail("Glassroad relay transition missing arrival summary")
		return {}
	var transition := EnemyAdventureRules.ai_hero_task_transition_from_arrival(before_task, arrival)
	if String(transition.get("transition_result", "")) == "completed_by_controller_flip":
		var released_reservation: Dictionary = before_task.get("reservation", {})
		released_reservation["reservation_status"] = "released"
		before_task["reservation"] = released_reservation
		before_task["task_status"] = "completed"
		before_task["last_validation"] = "invalid_controller_changed"
	var after_role := _role_record_from_snapshot(after_snapshot, "hero_caelen")
	var commander := _commander_entry(session, EMBERCOURT, "hero_caelen")
	var after_task := EnemyAdventureRules.ai_hero_task_candidate_from_role(session, config, EMBERCOURT, commander, after_role, 2, {"source_timing": "after_turn"})
	_assert_equal(String(after_task.get("task_id", "")), "task:glassroad-sundering:faction_embercourt:hero_caelen:defend_front:resource:glassroad_watch_relay:day_1:seq_2", "Glassroad defend task id")
	_assert_equal(String(transition.get("transition_result", "")), "completed_by_controller_flip", "Glassroad transition result")
	var case_report := _case_result(session, EMBERCOURT, "glassroad_relay_retake_to_defend_transition", [before_task, after_task], [transition])
	case_report["transcript_arrival_summary"] = arrival
	return case_report

func _glassroad_starlens_stabilizer_candidate() -> Dictionary:
	var session = _base_session(GLASSROAD)
	_set_resource_controller(session, "glassroad_watch_relay", EMBERCOURT)
	_set_resource_controller(session, "glassroad_starlens", EMBERCOURT)
	var task := _resource_candidate(
		session,
		EMBERCOURT,
		GLASSROAD_ORIGIN,
		"hero_seren",
		"glassroad_starlens",
		{"fixture_recently_secured": true},
		3,
		"before_turn",
		{"claim_status": "report_only_unclaimed"}
	)
	_assert_equal(String(task.get("task_id", "")), "task:glassroad-sundering:faction_embercourt:hero_seren:stabilize_front:resource:glassroad_starlens:day_1:seq_3", "Starlens task id")
	_assert_equal(bool(task.get("actor_active_linked", true)), false, "Starlens actor should be unlinked")
	_assert_equal(String(task.get("reservation", {}).get("reservation_scope", "")), "shared_front", "Starlens reservation scope")
	return _case_result(session, EMBERCOURT, "glassroad_starlens_stabilizer_candidate", [task], [])

func _commander_recovery_rebuild_blocks_task_claim() -> Dictionary:
	var session = _base_session(RIVER_PASS)
	_patch_commander_entry(session, MIRECLAW, "hero_vaska", {"status": EnemyAdventureRules.COMMANDER_STATUS_RECOVERING, "recovery_day": int(session.day) + 2})
	_patch_commander_entry(session, MIRECLAW, "hero_sable", {"army_continuity": {"base_strength": 200, "current_strength": 0}})
	var config := _enemy_config(RIVER_PASS, MIRECLAW)
	var recovery_task := EnemyAdventureRules.ai_hero_task_candidate_from_role(
		session,
		config,
		MIRECLAW,
		_commander_entry(session, MIRECLAW, "hero_vaska"),
		{
			"roster_hero_id": "hero_vaska",
			"commander_label": "Vaska Reedmaw",
			"role": EnemyAdventureRules.COMMANDER_ROLE_RECOVERING,
			"role_status": "cooldown",
			"target_kind": "commander",
			"target_id": "hero_vaska",
			"priority_reason_codes": ["commander_recovery"],
			"timing": "before_turn",
			"state_policy": "report_only",
		},
		1
	)
	var rebuild_task := EnemyAdventureRules.ai_hero_task_candidate_from_role(
		session,
		config,
		MIRECLAW,
		_commander_entry(session, MIRECLAW, "hero_sable"),
		{
			"roster_hero_id": "hero_sable",
			"commander_label": "Sable Muckscribe",
			"role": EnemyAdventureRules.COMMANDER_ROLE_RECOVERING,
			"role_status": "rebuilding",
			"target_kind": "commander",
			"target_id": "hero_sable",
			"priority_reason_codes": ["commander_rebuild"],
			"timing": "before_turn",
			"state_policy": "report_only",
		},
		2
	)
	_assert_equal(String(recovery_task.get("last_validation", "")), "invalid_actor_recovering", "Recovery task validation")
	_assert_equal(String(rebuild_task.get("last_validation", "")), "invalid_actor_rebuilding", "Rebuild task validation")
	return _case_result(session, MIRECLAW, "commander_recovery_rebuild_blocks_task_claim", [recovery_task, rebuild_task], [])

func _old_save_no_task_state_compatibility() -> Dictionary:
	var session = _base_session(RIVER_PASS)
	EnemyTurnRules.normalize_enemy_states(session)
	var absence_check := EnemyAdventureRules.ai_hero_task_old_save_absence_check(session)
	if not bool(absence_check.get("ok", false)):
		_fail("Old-save absence check failed: %s" % JSON.stringify(absence_check))
		return {}
	return {
		"case_id": "old_save_no_task_state_compatibility",
		"scenario_id": RIVER_PASS,
		"faction_id": MIRECLAW,
		"candidate_tasks": [],
		"public_task_events": [],
		"old_save_absence_check": absence_check,
		"ok": true,
	}

func _duplicate_target_reservation_report_only() -> Dictionary:
	var session = _base_session(RIVER_PASS)
	var config := _enemy_config(RIVER_PASS, MIRECLAW)
	_set_resource_controller(session, "river_free_company", "player")
	_add_active_resource_raid(session, config, MIRECLAW, "hero_vaska", "task_boundary_mireclaw_vaska_raid", "encounter_mire_raid", "river_free_company", {"x": 1, "y": 4})
	var vaska_task := _resource_candidate(
		session,
		MIRECLAW,
		RIVER_ORIGIN,
		"hero_vaska",
		"river_free_company",
		{"fixture_previous_controller": MIRECLAW},
		1,
		"before_turn"
	)
	var sable_task := _resource_candidate(
		session,
		MIRECLAW,
		RIVER_ORIGIN,
		"hero_sable",
		"river_free_company",
		{"fixture_denial_only": true},
		2,
		"before_turn"
	)
	var tasks := EnemyAdventureRules.ai_hero_task_apply_reservations([vaska_task, sable_task])
	var duplicate_task: Dictionary = tasks[1]
	_assert_equal(String(duplicate_task.get("last_validation", "")), "invalid_target_reserved", "Duplicate reservation validation")
	_assert_equal(String(duplicate_task.get("invalidated_by_task_id", "")), String(tasks[0].get("task_id", "")), "Duplicate invalidating task id")
	var public_events := [EnemyAdventureRules.ai_hero_task_public_event(session, config, tasks[0], 1)]
	return {
		"case_id": "duplicate_target_reservation_report_only",
		"scenario_id": RIVER_PASS,
		"faction_id": MIRECLAW,
		"candidate_tasks": tasks,
		"public_task_events": public_events,
		"transition_checks": [],
		"ok": true,
	}

func _case_result(session, faction_id: String, case_id: String, tasks: Array, transitions: Array) -> Dictionary:
	var config := _enemy_config(String(session.scenario_id), faction_id)
	var public_events := []
	var sequence := 1
	for task in tasks:
		if task is Dictionary and String(task.get("task_status", "")) != "invalid":
			public_events.append(EnemyAdventureRules.ai_hero_task_public_event(session, config, task, sequence))
			sequence += 1
	var checks := [
		EnemyAdventureRules.ai_hero_task_candidate_task_id_check(tasks),
		EnemyAdventureRules.ai_hero_task_actor_ownership_check(session, faction_id, tasks),
		EnemyAdventureRules.ai_hero_task_target_ownership_check(session, faction_id, tasks),
		EnemyAdventureRules.ai_hero_task_role_to_task_source_check(tasks),
		EnemyAdventureRules.ai_hero_task_target_reservation_check(tasks),
		EnemyAdventureRules.ai_hero_task_invalidation_check(tasks, transitions),
		EnemyAdventureRules.ai_hero_task_public_leak_check(public_events),
		EnemyAdventureRules.ai_hero_task_old_save_absence_check(session),
	]
	for check in checks:
		if not bool(check.get("ok", false)):
			_fail("%s failed check: %s" % [case_id, JSON.stringify(check)])
			return {}
	return {
		"case_id": case_id,
		"scenario_id": String(session.scenario_id),
		"faction_id": faction_id,
		"candidate_tasks": tasks,
		"public_task_events": public_events,
		"transition_checks": transitions,
		"write_check": "no_hero_task_state_write",
		"ok": true,
	}

func _resource_candidate(
	session,
	faction_id: String,
	origin: Dictionary,
	roster_hero_id: String,
	target_id: String,
	fixture_state: Dictionary,
	local_sequence: int,
	timing: String,
	options: Dictionary = {}
) -> Dictionary:
	var config := _enemy_config(String(session.scenario_id), faction_id)
	var snapshot := _turn_snapshot(
		session,
		config,
		faction_id,
		origin,
		[{"roster_hero_id": roster_hero_id, "target_id": target_id, "fixture_state": fixture_state}],
		EnemyAdventureRules.commander_role_front_id(String(session.scenario_id), "resource", target_id)
	)
	var role_record := _role_record_from_snapshot(snapshot, roster_hero_id)
	role_record["timing"] = timing
	var commander := _commander_entry(session, faction_id, roster_hero_id)
	return EnemyAdventureRules.ai_hero_task_candidate_from_role(session, config, faction_id, commander, role_record, local_sequence, options)

func _turn_snapshot(session, config: Dictionary, faction_id: String, origin: Dictionary, role_assignments: Array, front_id: String) -> Dictionary:
	return EnemyAdventureRules.commander_role_turn_snapshot(
		session,
		config,
		faction_id,
		{
			"origin": origin,
			"supporting_front_id": front_id,
			"role_assignments": role_assignments,
			"town_governor_reports": [EnemyTurnRules.town_governor_pressure_report(session, config, faction_id)],
		}
	)

func _role_record_from_snapshot(snapshot: Dictionary, roster_hero_id: String) -> Dictionary:
	for proposal in snapshot.get("derived_role_proposals", []):
		if proposal is Dictionary and String(proposal.get("roster_hero_id", "")) == roster_hero_id:
			return proposal.duplicate(true)
	_fail("Missing role proposal for %s in %s" % [roster_hero_id, JSON.stringify(snapshot.get("derived_role_proposals", []))])
	return {}

func _multi_faction_actor_check(tasks: Array) -> Dictionary:
	var checked := 0
	for faction_id in [MIRECLAW, EMBERCOURT]:
		var scenario_id := RIVER_PASS if faction_id == MIRECLAW else GLASSROAD
		var session = _base_session(scenario_id)
		var faction_tasks := _tasks_for_faction(tasks, faction_id)
		var check := EnemyAdventureRules.ai_hero_task_actor_ownership_check(session, faction_id, faction_tasks)
		if not bool(check.get("ok", false)):
			return check
		checked += int(check.get("checked_tasks", 0))
	return {"ok": true, "checked_tasks": checked}

func _multi_faction_target_check(tasks: Array) -> Dictionary:
	var checked := 0
	for faction_id in [MIRECLAW, EMBERCOURT]:
		var scenario_id := RIVER_PASS if faction_id == MIRECLAW else GLASSROAD
		var session = _base_session(scenario_id)
		if faction_id == MIRECLAW:
			_set_resource_controller(session, "river_free_company", "player")
			_set_resource_controller(session, "river_signal_post", "player")
		else:
			_set_resource_controller(session, "glassroad_watch_relay", EMBERCOURT)
			_set_resource_controller(session, "glassroad_starlens", EMBERCOURT)
		var faction_tasks := _tasks_for_faction(tasks, faction_id)
		var check := EnemyAdventureRules.ai_hero_task_target_ownership_check(session, faction_id, faction_tasks)
		if not bool(check.get("ok", false)):
			return check
		checked += int(check.get("checked_tasks", 0))
	return {"ok": true, "checked_tasks": checked}

func _tasks_for_faction(tasks: Array, faction_id: String) -> Array:
	var output := []
	for task in tasks:
		if task is Dictionary and String(task.get("owner_faction_id", "")) == faction_id:
			output.append(task)
	return output

func _combine_checks(checks: Array) -> Dictionary:
	var checked := 0
	var task_ids := []
	for check in checks:
		if not (check is Dictionary) or not bool(check.get("ok", false)):
			return check
		checked += int(check.get("checked_tasks", 0))
		for task_id in check.get("task_ids", []):
			task_ids.append(task_id)
	return {"ok": true, "checked_tasks": checked, "task_ids": task_ids, "case_scoped_uniqueness": true}

func _arrival_for_target(arrivals: Array, target_id: String) -> Dictionary:
	for arrival in arrivals:
		if arrival is Dictionary and String(arrival.get("target_id", "")) == target_id:
			return arrival
	return {}

func _base_session(scenario_id: String):
	var session = ScenarioFactory.create_session(scenario_id, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	OverworldRules.refresh_fog_of_war(session)
	EnemyTurnRules.normalize_enemy_states(session)
	EnemyAdventureRules.normalize_all_commander_rosters(session)
	return session

func _add_active_resource_raid(session, config: Dictionary, faction_id: String, roster_hero_id: String, placement_id: String, encounter_id: String, target_id: String, origin: Dictionary) -> void:
	var target := _resource_target(session, target_id)
	if target.is_empty():
		_fail("Missing resource target %s" % target_id)
		return
	var target_view := EnemyAdventureRules.commander_role_resource_target_view(session, config, faction_id, target_id, origin)
	var raid := {
		"placement_id": placement_id,
		"encounter_id": encounter_id,
		"x": int(origin.get("x", 0)),
		"y": int(origin.get("y", 0)),
		"difficulty": "pressure",
		"combat_seed": hash("%s:%s" % [String(session.scenario_id), placement_id]),
		"spawned_by_faction_id": faction_id,
		"days_active": 0,
		"arrived": false,
		"goal_distance": 9999,
		"target_kind": "resource",
		"target_placement_id": target_id,
		"target_label": String(target.get("label", target_id)),
		"target_x": int(target.get("x", 0)),
		"target_y": int(target.get("y", 0)),
		"goal_x": int(target.get("x", 0)),
		"goal_y": int(target.get("y", 0)),
		"target_public_reason": String(target_view.get("public_reason", "")),
		"target_reason_codes": target_view.get("reason_codes", []),
		"target_public_importance": String(target_view.get("public_importance", "high")),
		"target_debug_reason": String(target_view.get("debug_reason", "")),
	}
	raid["enemy_commander_state"] = EnemyAdventureRules.build_raid_commander_state(
		raid,
		roster_hero_id,
		faction_id,
		session,
		{},
		EnemyAdventureRules.commander_roster_for_faction(session, faction_id)
	)
	raid = EnemyAdventureRules.ensure_raid_army(raid, session)
	var encounters: Array = session.overworld.get("encounters", [])
	encounters.append(raid)
	session.overworld["encounters"] = encounters
	EnemyAdventureRules.normalize_all_commander_rosters(session)

func _resource_target(session, placement_id: String) -> Dictionary:
	for node in session.overworld.get("resource_nodes", []):
		if not (node is Dictionary) or String(node.get("placement_id", "")) != placement_id:
			continue
		var site := ContentService.get_resource_site(String(node.get("site_id", "")))
		return {"x": int(node.get("x", 0)), "y": int(node.get("y", 0)), "label": String(site.get("name", placement_id))}
	return {}

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

func _set_enemy_state_patch(session, faction_id: String, patch: Dictionary) -> void:
	var states: Array = session.overworld.get("enemy_states", [])
	for index in range(states.size()):
		var state = states[index]
		if not (state is Dictionary):
			continue
		if String(state.get("faction_id", "")) != faction_id:
			continue
		for key in patch.keys():
			state[key] = patch[key]
		states[index] = state
		session.overworld["enemy_states"] = states
		EnemyAdventureRules.normalize_all_commander_rosters(session)
		return
	_fail("Could not patch enemy state for %s" % faction_id)

func _patch_commander_entry(session, faction_id: String, roster_hero_id: String, patch: Dictionary) -> void:
	var states: Array = session.overworld.get("enemy_states", [])
	for state_index in range(states.size()):
		var state = states[state_index]
		if not (state is Dictionary) or String(state.get("faction_id", "")) != faction_id:
			continue
		var roster: Array = state.get("commander_roster", [])
		for index in range(roster.size()):
			var entry = roster[index]
			if not (entry is Dictionary) or String(entry.get("roster_hero_id", "")) != roster_hero_id:
				continue
			for key in patch.keys():
				entry[key] = patch[key]
			roster[index] = entry
			state["commander_roster"] = roster
			states[state_index] = state
			session.overworld["enemy_states"] = states
			return
	_fail("Could not patch commander entry %s" % roster_hero_id)

func _commander_entry(session, faction_id: String, roster_hero_id: String) -> Dictionary:
	for entry in EnemyAdventureRules.commander_roster_for_faction(session, faction_id):
		if entry is Dictionary and String(entry.get("roster_hero_id", "")) == roster_hero_id:
			return entry
	_fail("Missing commander entry %s" % roster_hero_id)
	return {}

func _enemy_config(scenario_id: String, faction_id: String) -> Dictionary:
	var scenario := ContentService.get_scenario(scenario_id)
	for config in scenario.get("enemy_factions", []):
		if config is Dictionary and String(config.get("faction_id", "")) == faction_id:
			return config
	_fail("Could not find enemy config for %s in %s" % [faction_id, scenario_id])
	return {}

func _assert_equal(actual, expected, label: String) -> void:
	if actual != expected:
		_fail("%s expected %s, got %s" % [label, expected, actual])

func _assert_contains(values: Array, expected, label: String) -> void:
	if expected not in values:
		_fail("%s expected %s in %s" % [label, expected, values])

func _fail(message: String) -> void:
	var payload := {"ok": false, "report_id": REPORT_ID, "error": message}
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	_failed = true
	get_tree().quit(1)
