extends Node

const REPORT_ID := "AI_HERO_TASK_ARTIFACT_OBJECTIVE_REPORT"
const RIVER_PASS := "river-pass"
const MIRECLAW := "faction_mireclaw"
const RELIC_TARGET_ID := "warcrest_ruin"
const EXTERNALLY_COLLECTED_RELIC_ID := "quarry_tally_cache"

var _failed := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var case_report := _artifact_task_board_case()
	if case_report.is_empty():
		return
	var guarded_case_report := _guarded_artifact_claim_retargets_to_guard_case()
	if guarded_case_report.is_empty():
		return
	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"schema_status": "artifact_relic_tasks_are_durable",
		"behavior_policy": "artifact_targets_use_saved_task_continuity_and_guarded_claim_routing",
		"save_policy": "hero_task_state_live_persist_no_save_migration",
		"case": case_report,
		"guarded_claim_case": guarded_case_report,
		"save_version_before": int(SessionStateStore.SAVE_VERSION),
		"save_version_after": int(SessionStateStore.SAVE_VERSION),
	}
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _artifact_task_board_case() -> Dictionary:
	var session = _base_session()
	session.day = 2
	var config := _enemy_config()
	_set_artifact_collected(session, EXTERNALLY_COLLECTED_RELIC_ID, "player")
	_seed_task_board(session, [
		_task("hero_tarn", "missing_relic_target", "active", "valid"),
		_task("hero_orrik", EXTERNALLY_COLLECTED_RELIC_ID, "active", "valid"),
	])
	var relic := _artifact_node(session, RELIC_TARGET_ID)
	if relic.is_empty():
		return {}
	var raid := _raid_seed(session, "hero_vaska", "artifact_task_vaska", {"x": 7, "y": 1})
	raid["target_kind"] = "artifact"
	raid["target_placement_id"] = RELIC_TARGET_ID
	raid["target_label"] = ArtifactRules.describe_artifact(String(relic.get("artifact_id", "")))
	raid["target_x"] = int(relic.get("x", 0))
	raid["target_y"] = int(relic.get("y", 0))
	raid["goal_x"] = int(relic.get("x", 0))
	raid["goal_y"] = int(relic.get("y", 0))
	raid["target_reason_codes"] = ["command_pressure", "faction_fit", "artifact_task_fixture"]
	raid["target_public_reason"] = "command relic"
	raid["target_public_importance"] = "high"
	raid["target_debug_reason"] = "artifact task-board fixture"

	var assigned_raid := EnemyAdventureRules.assign_target(session, config, raid)
	if String(assigned_raid.get("target_kind", "")) != "artifact" or String(assigned_raid.get("target_placement_id", "")) != RELIC_TARGET_ID:
		_fail("Artifact assignment did not keep the target: %s" % JSON.stringify(assigned_raid))
		return {}
	_assert_task_status(session, "hero_vaska", "artifact", RELIC_TARGET_ID, "active", "valid")
	if _failed:
		return {}

	EnemyTurnRules.normalize_enemy_states(session)
	_assert_task_status(session, "hero_vaska", "artifact", RELIC_TARGET_ID, "active", "valid")
	if _failed:
		return {}

	var saved_plan_raid := _raid_seed(session, "hero_vaska", "artifact_reuse_vaska", {"x": 7, "y": 1})
	var saved_plan := EnemyAdventureRules.ai_hero_task_saved_target_selection_plan(session, config, saved_plan_raid)
	if String(saved_plan.get("target_kind", "")) != "artifact" or String(saved_plan.get("target_placement_id", "")) != RELIC_TARGET_ID:
		_fail("Saved artifact task was not reused: %s" % JSON.stringify(saved_plan))
		return {}
	var reason_codes := _string_array(saved_plan.get("target_reason_codes", []))
	if "saved_hero_task" not in reason_codes:
		_fail("Saved artifact plan is missing saved_hero_task reason: %s" % JSON.stringify(saved_plan))
		return {}
	_assert_task_status(session, "hero_tarn", "artifact", "missing_relic_target", "invalid", "invalid_target_missing")
	_assert_task_status(session, "hero_orrik", "artifact", EXTERNALLY_COLLECTED_RELIC_ID, "invalid", "invalid_target_resolved")
	if _failed:
		return {}

	var state := _enemy_state(session)
	var vaska_progress_before := _commander_progress_snapshot(session, "hero_vaska")
	var secure_result := EnemyAdventureRules._secure_artifact_target(session, assigned_raid, state, MIRECLAW)
	if secure_result.is_empty() or String(secure_result.get("event_message", "")) == "":
		_fail("Artifact secure returned no event result: %s" % JSON.stringify(secure_result))
		return {}
	var secured_raid: Dictionary = secure_result.get("encounter", {}) if secure_result.get("encounter", {}) is Dictionary else {}
	var secured_commander: Dictionary = secured_raid.get("enemy_commander_state", {}) if secured_raid.get("enemy_commander_state", {}) is Dictionary else {}
	if String(secured_commander.get("artifacts", {}).get("equipped", {}).get("banner", "")) != "artifact_warcrest_pennon":
		_fail("Secured commander did not equip Warcrest Pennon: %s" % JSON.stringify(secured_commander.get("artifacts", {})))
		return {}
	var vaska_progress_after := _commander_progress_snapshot(session, "hero_vaska")
	_assert_progression(vaska_progress_before, vaska_progress_after, EnemyAdventureRules.COMMANDER_OUTCOME_ARTIFACT_SECURED, "Vaska artifact secure")
	if _failed:
		return {}
	var bonus_report := ArtifactRules.artifact_equip_runtime_report(secured_commander)
	if int(bonus_report.get("aggregate_bonuses", {}).get("battle_attack", 0)) < 1 or int(bonus_report.get("aggregate_bonuses", {}).get("battle_initiative", 0)) < 1:
		_fail("Equipped Warcrest Pennon did not contribute live artifact bonuses: %s" % JSON.stringify(bonus_report))
		return {}
	var roster_commander := _roster_commander_state(session, "hero_vaska")
	if String(roster_commander.get("artifacts", {}).get("equipped", {}).get("banner", "")) != "artifact_warcrest_pennon":
		_fail("Commander roster did not persist equipped Warcrest Pennon: %s" % JSON.stringify(roster_commander.get("artifacts", {})))
		return {}
	var public_log := EnemyAdventureRules.ai_public_event_log_boundary_report([secure_result.get("ai_event", {})], 4)
	if not bool(public_log.get("ok", false)):
		_fail("Artifact secure public event boundary failed: %s" % JSON.stringify(public_log))
		return {}
	if String(secure_result.get("ai_event", {}).get("event_type", "")) != "ai_artifact_secured":
		_fail("Artifact secure did not emit ai_artifact_secured: %s" % JSON.stringify(secure_result.get("ai_event", {})))
		return {}
	var secured_node := _artifact_node(session, RELIC_TARGET_ID)
	if not bool(secured_node.get("collected", false)) or String(secured_node.get("collected_by_faction_id", "")) != MIRECLAW:
		_fail("Artifact node was not marked collected by Mireclaw: %s" % JSON.stringify(secured_node))
		return {}
	_assert_task_status(session, "hero_vaska", "artifact", RELIC_TARGET_ID, "completed", "valid")
	if _failed:
		return {}
	EnemyTurnRules.normalize_enemy_states(session)
	_assert_task_status(session, "hero_vaska", "artifact", RELIC_TARGET_ID, "completed", "valid")
	var vaska_progress_normalized := _commander_progress_snapshot(session, "hero_vaska")
	_assert_progression(vaska_progress_before, vaska_progress_normalized, EnemyAdventureRules.COMMANDER_OUTCOME_ARTIFACT_SECURED, "normalized Vaska artifact secure")
	if _failed:
		return {}

	var final_task_state := _task_state(session)
	return {
		"case_id": "artifact_relic_assigns_reuses_and_closes_task",
		"target_kind": String(saved_plan.get("target_kind", "")),
		"target_id": String(saved_plan.get("target_placement_id", "")),
		"reason_codes": reason_codes,
		"secured_relic_id": RELIC_TARGET_ID,
		"equipped_artifact_id": String(secured_commander.get("artifacts", {}).get("equipped", {}).get("banner", "")),
		"artifact_bonus_attack": int(bonus_report.get("aggregate_bonuses", {}).get("battle_attack", 0)),
		"artifact_bonus_initiative": int(bonus_report.get("aggregate_bonuses", {}).get("battle_initiative", 0)),
		"vaska_progress_before": vaska_progress_before,
		"vaska_progress_after": vaska_progress_after,
		"vaska_progress_normalized": vaska_progress_normalized,
		"artifact_event_type": String(secure_result.get("ai_event", {}).get("event_type", "")),
		"captured_artifacts": _string_array(secure_result.get("state", {}).get("captured_artifact_ids", []) if secure_result.get("state", {}) is Dictionary else []),
		"task_status_counts": _task_status_counts(final_task_state),
		"save_version": int(SessionStateStore.SAVE_VERSION),
	}

func _guarded_artifact_claim_retargets_to_guard_case() -> Dictionary:
	var session = _base_session()
	session.day = 2
	var config := _enemy_config()
	var state := _enemy_state(session)
	_seed_task_board(session, [_task("hero_vaska", RELIC_TARGET_ID, "active", "valid")])
	var relic := _artifact_node(session, RELIC_TARGET_ID)
	if relic.is_empty():
		return {}
	var encounters: Array = session.overworld.get("encounters", [])
	encounters.append(_artifact_guard_encounter(relic))
	encounters.append(_guarded_artifact_claim_raid(session, relic))
	session.overworld["encounters"] = encounters

	var result := EnemyAdventureRules.advance_raids(session, config, MIRECLAW, state)
	var after_raid := _encounter(session, "guarded_artifact_claim_vaska")
	if after_raid.is_empty():
		_fail("Guarded artifact claim raid disappeared after advance.")
		return {}
	var guarded_node := _artifact_node(session, RELIC_TARGET_ID)
	if bool(guarded_node.get("collected", false)):
		_fail("Guarded artifact was collected before its guard was cleared: %s" % JSON.stringify(after_raid))
		return {}
	if String(after_raid.get("target_kind", "")) != "encounter" or String(after_raid.get("target_placement_id", "")) != "warcrest_ruin_guard":
		_fail("Guarded artifact claim did not retarget to the guard encounter: %s" % JSON.stringify(after_raid))
		return {}
	var reason_codes := _string_array(after_raid.get("target_reason_codes", []))
	if "guard_clearance" not in reason_codes or "guarded_artifact_claim" not in reason_codes:
		_fail("Guarded artifact redirect missed guard-clearance reason codes: %s" % JSON.stringify(after_raid))
		return {}
	if String(after_raid.get("guarded_claim_target_id", "")) != RELIC_TARGET_ID:
		_fail("Guarded artifact redirect did not retain original claim target: %s" % JSON.stringify(after_raid))
		return {}
	var event_types := _event_types(result.get("events", []))
	if "ai_target_assigned" not in event_types:
		_fail("Guarded artifact redirect did not emit ai_target_assigned: %s" % JSON.stringify(result))
		return {}
	if "ai_artifact_secured" in event_types:
		_fail("Guarded artifact redirect incorrectly emitted ai_artifact_secured: %s" % JSON.stringify(result))
		return {}
	_assert_task_status(session, "hero_vaska", "artifact", RELIC_TARGET_ID, "active", "valid")
	if _failed:
		return {}
	var public_log := EnemyAdventureRules.ai_public_event_log_boundary_report(result.get("events", []), 8)
	if not bool(public_log.get("ok", false)):
		_fail("Guarded artifact redirect public event boundary failed: %s" % JSON.stringify(public_log))
		return {}
	return {
		"case_id": "guarded_artifact_claim_retargets_to_guard",
		"artifact_collected": bool(guarded_node.get("collected", false)),
		"target_kind": String(after_raid.get("target_kind", "")),
		"target_id": String(after_raid.get("target_placement_id", "")),
		"guarded_claim_target_id": String(after_raid.get("guarded_claim_target_id", "")),
		"reason_codes": reason_codes,
		"event_types": event_types,
		"public_event_count": int(public_log.get("public_event_count", 0)),
		"task_status_counts": _task_status_counts(_task_state(session)),
		"save_version": int(SessionStateStore.SAVE_VERSION),
	}

func _seed_task_board(session, tasks: Array) -> void:
	var state := _enemy_state(session)
	state["hero_task_state"] = {
		"schema_version": 1,
		"planner_epoch": 12,
		"tasks": tasks,
	}
	_update_enemy_state(session, state)

func _task(actor_id: String, target_id: String, status: String, validation: String) -> Dictionary:
	return {
		"task_id": "task:artifact_objective:%s:%s" % [actor_id, target_id],
		"owner_faction_id": MIRECLAW,
		"actor_kind": "commander_roster",
		"actor_id": actor_id,
		"source_kind": "saved_task_state",
		"source_id": "artifact_objective_fixture",
		"task_class": "contest_site",
		"task_status": status,
		"target_kind": "artifact",
		"target_id": target_id,
		"front_id": "artifact:%s" % target_id,
		"origin_kind": "encounter",
		"origin_id": "artifact_objective_fixture",
		"priority_reason_codes": ["command_pressure", "artifact_task_fixture"],
		"assigned_day": 2,
		"expires_day": 9,
		"continuity_policy": "persist_until_invalid",
		"route_policy": "derive_route_on_turn",
		"last_validation": validation,
		"reservation": {
			"reservation_status": "primary",
			"reservation_scope": "exclusive_target",
			"reservation_key": "artifact:%s" % target_id,
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

func _guarded_artifact_claim_raid(session, relic: Dictionary) -> Dictionary:
	var raid := {
		"placement_id": "guarded_artifact_claim_vaska",
		"encounter_id": "encounter_mire_raid",
		"x": int(relic.get("x", 0)),
		"y": int(relic.get("y", 0)),
		"difficulty": "pressure",
		"combat_seed": hash("%s:guarded_artifact_claim_vaska" % String(session.scenario_id)),
		"spawned_by_faction_id": MIRECLAW,
		"days_active": 0,
		"arrived": false,
		"goal_distance": 0,
		"target_kind": "artifact",
		"target_placement_id": RELIC_TARGET_ID,
		"target_label": ArtifactRules.describe_artifact(String(relic.get("artifact_id", ""))),
		"target_x": int(relic.get("x", 0)),
		"target_y": int(relic.get("y", 0)),
		"goal_x": int(relic.get("x", 0)),
		"goal_y": int(relic.get("y", 0)),
		"target_reason_codes": ["command_pressure", "faction_fit", "artifact_task_fixture"],
		"target_public_reason": "command relic",
		"target_public_importance": "high",
		"enemy_army": {
			"id": "guarded_artifact_claim_host",
			"name": "Guarded Artifact Claim Host",
			"stacks": [{"unit_id": "unit_bog_brute", "count": 12}],
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

func _artifact_guard_encounter(relic: Dictionary) -> Dictionary:
	return {
		"placement_id": "warcrest_ruin_guard",
		"encounter_id": "encounter_roadward_lodge_watch",
		"x": int(relic.get("x", 0)) + 2,
		"y": int(relic.get("y", 0)),
		"difficulty": "medium",
		"combat_seed": 44102,
		"guard_link": {
			"guard_role": "guards_reward",
			"target_kind": "artifact",
			"target_id": RELIC_TARGET_ID,
			"target_placement_id": RELIC_TARGET_ID,
			"blocks_approach": true,
			"clear_required_for_target": true,
		},
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

func _roster_commander_state(session, roster_hero_id: String) -> Dictionary:
	var state := _enemy_state(session)
	for entry in state.get("commander_roster", []):
		if entry is Dictionary and String(entry.get("roster_hero_id", "")) == roster_hero_id:
			return entry.get("commander_state", {}) if entry.get("commander_state", {}) is Dictionary else {}
	_fail("Could not find roster commander state for %s" % roster_hero_id)
	return {}

func _commander_progress_snapshot(session, roster_hero_id: String) -> Dictionary:
	var commander_state := _roster_commander_state(session, roster_hero_id)
	if commander_state.is_empty():
		return {}
	return {
		"roster_hero_id": roster_hero_id,
		"experience": max(0, int(commander_state.get("experience", 0))),
		"level": max(1, int(commander_state.get("level", 1))),
		"strategic_successes": max(0, int(commander_state.get("strategic_successes", 0))),
		"last_outcome": String(commander_state.get("last_outcome", "")),
	}

func _assert_progression(before: Dictionary, after: Dictionary, expected_outcome: String, label: String) -> void:
	if after.is_empty():
		_fail("%s commander progression snapshot is empty." % label)
		return
	if int(after.get("experience", 0)) <= int(before.get("experience", 0)) and int(after.get("level", 1)) <= int(before.get("level", 1)):
		_fail("%s did not gain adventure objective experience: before=%s after=%s" % [label, JSON.stringify(before), JSON.stringify(after)])
		return
	if int(after.get("strategic_successes", 0)) <= int(before.get("strategic_successes", 0)):
		_fail("%s did not record a strategic_successes increment: before=%s after=%s" % [label, JSON.stringify(before), JSON.stringify(after)])
		return
	if String(after.get("last_outcome", "")) != expected_outcome:
		_fail("%s last_outcome expected %s, got %s" % [label, expected_outcome, JSON.stringify(after)])

func _artifact_node(session, placement_id: String) -> Dictionary:
	for node in session.overworld.get("artifact_nodes", []):
		if node is Dictionary and String(node.get("placement_id", "")) == placement_id:
			return node
	_fail("Could not find artifact placement %s" % placement_id)
	return {}

func _encounter(session, placement_id: String) -> Dictionary:
	for encounter in session.overworld.get("encounters", []):
		if encounter is Dictionary and String(encounter.get("placement_id", "")) == placement_id:
			return encounter
	return {}

func _set_artifact_collected(session, placement_id: String, faction_id: String) -> void:
	var nodes: Array = session.overworld.get("artifact_nodes", [])
	for index in range(nodes.size()):
		var node = nodes[index]
		if not (node is Dictionary) or String(node.get("placement_id", "")) != placement_id:
			continue
		node["collected"] = true
		node["collected_by_faction_id"] = faction_id
		node["collected_day"] = max(1, int(session.day))
		nodes[index] = node
		session.overworld["artifact_nodes"] = nodes
		return
	_fail("Could not mark artifact placement collected: %s" % placement_id)

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
