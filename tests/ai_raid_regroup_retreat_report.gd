extends Node

const REPORT_ID := "AI_RAID_REGROUP_RETREAT_REPORT"
const RIVER_PASS := "river-pass"
const MIRECLAW := "faction_mireclaw"
const EMBERCOURT := "faction_embercourt"

var _failed := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var case_report := _river_pass_understrength_raid_regroups()
	if case_report.is_empty():
		return
	var guarded_claim_case := _guarded_resource_claim_retargets_to_guard()
	if guarded_claim_case.is_empty():
		return
	var resource_support_case := _resource_front_risk_requests_support()
	if resource_support_case.is_empty():
		return
	var empty_front_scan_case := _active_front_support_skips_empty_front_scan()
	if empty_front_scan_case.is_empty():
		return
	var resource_support_launch_case := _resource_front_support_launches_below_pressure()
	if resource_support_launch_case.is_empty():
		return
	var resource_consolidation_case := _resource_front_support_consolidates_into_capture_ready_host()
	if resource_consolidation_case.is_empty():
		return
	var neutral_town_grouping_case := _neutral_town_assault_support_consolidates()
	if neutral_town_grouping_case.is_empty():
		return
	var unreachable_route_case := _valid_but_unreachable_target_reroutes_to_regroup()
	if unreachable_route_case.is_empty():
		return
	var garrison_routing_case := _regroup_prefers_useful_garrison_town()
	if garrison_routing_case.is_empty():
		return
	var town_resupply_case := _active_raid_resupplies_while_passing_friendly_town()
	if town_resupply_case.is_empty():
		return
	var route_occupancy_regroup_case := _regroup_route_occupancy_avoids_visible_player_hero_choke()
	if route_occupancy_regroup_case.is_empty():
		return
	var failed_regroup_case := _empty_garrison_regroup_releases_to_rebuild()
	if failed_regroup_case.is_empty():
		return
	var commander_risk_case := _commander_risk_tolerance_changes_live_town_gate()
	if commander_risk_case.is_empty():
		return
	var personality_regroup_case := _faction_personality_changes_regroup_threshold()
	if personality_regroup_case.is_empty():
		return
	var assignment_reconciliation_case := _assignment_events_match_final_or_acted_on_targets()
	if assignment_reconciliation_case.is_empty():
		return
	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"schema_status": "live_regroup_behavior_no_save_migration",
		"behavior_policy": "understrength_raids_retreat_guarded_claims_retarget_and_unreachable_routes_recover_resource_fronts_request_and_consolidate_support_neutral_town_assaults_active_raids_resupply_at_friendly_towns_failed_regroups_rebuild_route_occupancy_commander_risk_tolerance_and_faction_personality_shape_live_gates",
		"case": case_report,
		"guarded_claim_case": guarded_claim_case,
		"resource_support_case": resource_support_case,
		"empty_front_scan_case": empty_front_scan_case,
		"resource_support_launch_case": resource_support_launch_case,
		"resource_consolidation_case": resource_consolidation_case,
		"neutral_town_grouping_case": neutral_town_grouping_case,
		"unreachable_route_case": unreachable_route_case,
		"garrison_routing_case": garrison_routing_case,
		"town_resupply_case": town_resupply_case,
		"route_occupancy_regroup_case": route_occupancy_regroup_case,
		"failed_regroup_case": failed_regroup_case,
		"commander_risk_case": commander_risk_case,
		"personality_regroup_case": personality_regroup_case,
		"assignment_reconciliation_case": assignment_reconciliation_case,
		"save_version_before": int(SessionStateStore.SAVE_VERSION),
		"save_version_after": int(SessionStateStore.SAVE_VERSION),
	}
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _assignment_events_match_final_or_acted_on_targets() -> Dictionary:
	var events := [
		_assignment_event("stale_host", "explore", "explore:36:30"),
		_action_event("ai_raid_moved", "stale_host", "explore", "explore:36:30"),
		_assignment_event("current_host", "explore", "explore:40:24"),
		_assignment_event("current_host", "explore", "explore:40:24"),
		_assignment_event("resolved_host", "resource", "ridge_quarry"),
		_action_event("ai_site_seized", "resolved_host", "resource", "ridge_quarry"),
		_assignment_event("regroup_host", "regroup", "prismhearth"),
		_action_event("ai_raid_regrouped", "regroup_host", "town", "prismhearth"),
	]
	var encounters := [
		_active_host("stale_host", "resource", "ridge_quarry"),
		_active_host("current_host", "explore", "explore:40:24"),
	]
	var reconciled := EnemyAdventureRules._reconcile_raid_assignment_events(
		events,
		encounters,
		MIRECLAW,
		["resolved_host"]
	)
	if _event_count(reconciled, "ai_target_assigned", "stale_host", "explore:36:30") != 0:
		_fail("Reconciliation retained an assignment superseded before action: %s" % JSON.stringify(reconciled))
		return {}
	if _event_count(reconciled, "ai_target_assigned", "current_host", "explore:40:24") != 1:
		_fail("Reconciliation did not retain exactly one final-current assignment: %s" % JSON.stringify(reconciled))
		return {}
	if _event_count(reconciled, "ai_target_assigned", "resolved_host", "ridge_quarry") != 1:
		_fail("Reconciliation removed an assignment followed by same-turn target resolution: %s" % JSON.stringify(reconciled))
		return {}
	if _event_count(reconciled, "ai_site_seized", "resolved_host", "ridge_quarry") != 1:
		_fail("Reconciliation removed a non-assignment action event: %s" % JSON.stringify(reconciled))
		return {}
	if _event_count(reconciled, "ai_target_assigned", "regroup_host", "prismhearth") != 1:
		_fail("Reconciliation removed a regroup assignment followed by same-turn completion: %s" % JSON.stringify(reconciled))
		return {}
	return {
		"case_id": "assignment_events_match_final_or_acted_on_targets",
		"input_event_count": events.size(),
		"reconciled_event_count": reconciled.size(),
		"stale_assignment_count": 0,
		"current_assignment_count": 1,
		"resolved_assignment_count": 1,
	}

func _assignment_event(actor_id: String, target_kind: String, target_id: String) -> Dictionary:
	return {
		"event_type": "ai_target_assigned",
		"actor_id": actor_id,
		"target_kind": target_kind,
		"target_id": target_id,
	}

func _action_event(event_type: String, actor_id: String, target_kind: String, target_id: String) -> Dictionary:
	return {
		"event_type": event_type,
		"actor_id": actor_id,
		"target_kind": target_kind,
		"target_id": target_id,
	}

func _active_host(actor_id: String, target_kind: String, target_id: String) -> Dictionary:
	return {
		"placement_id": actor_id,
		"encounter_id": "encounter_mire_raid",
		"spawned_by_faction_id": MIRECLAW,
		"target_kind": target_kind,
		"target_placement_id": target_id,
	}

func _event_count(events: Array, event_type: String, actor_id: String, target_id: String) -> int:
	var count := 0
	for event_value in events:
		if not (event_value is Dictionary):
			continue
		var event: Dictionary = event_value
		if String(event.get("event_type", "")) == event_type \
			and String(event.get("actor_id", "")) == actor_id \
			and String(event.get("target_id", "")) == target_id:
			count += 1
	return count

func _river_pass_understrength_raid_regroups() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config()
	var state := _enemy_state(session)
	_set_resource_controller(session, "river_free_company", "player")
	_seed_task_board(session, [
		_regroup_task("hero_sable", "duskfen_bastion", "active", "valid"),
		_regroup_task("hero_tarn", "missing_regroup_town", "active", "valid"),
		_regroup_task("hero_orrik", "riverwatch_hold", "active", "valid"),
	])
	var saved_plan_raid := _regroup_probe_raid(session, "hero_sable", "regroup_sable_saved_probe", {"x": 8, "y": 1})
	var saved_plan := EnemyAdventureRules.ai_hero_task_saved_target_selection_plan(session, config, saved_plan_raid)
	if String(saved_plan.get("target_kind", "")) != "regroup" or String(saved_plan.get("target_placement_id", "")) != "duskfen_bastion":
		_fail("Saved regroup task was not reused: %s" % JSON.stringify(saved_plan))
		return {}
	var saved_reason_codes := _string_array(saved_plan.get("target_reason_codes", []))
	if "saved_hero_task" not in saved_reason_codes:
		_fail("Saved regroup plan is missing saved_hero_task reason: %s" % JSON.stringify(saved_plan))
		return {}
	_assert_task_status(session, "hero_tarn", "regroup", "missing_regroup_town", "invalid", "invalid_target_missing")
	_assert_task_status(session, "hero_orrik", "regroup", "riverwatch_hold", "invalid", "invalid_controller_changed")
	if _failed:
		return {}
	var raid := _understrength_raid(session, config)
	var before_strength := EnemyAdventureRules.raid_strength(raid)
	var desired_before := EnemyAdventureRules.desired_raid_strength(raid)
	if not EnemyAdventureRules.raid_regroup_needed(raid):
		_fail("Fixture raid was not considered understrength: strength=%d desired=%d raid=%s" % [before_strength, desired_before, JSON.stringify(raid)])
		return {}
	var garrison_before := _town_garrison_count(session, "duskfen_bastion", "unit_bog_brute")
	var encounters: Array = session.overworld.get("encounters", [])
	encounters.append(raid)
	session.overworld["encounters"] = encounters

	var result := EnemyAdventureRules.advance_raids(session, config, MIRECLAW, state)
	state = result.get("state", state)
	var after_raid := _encounter(session, "regroup_vaska_understrength")
	if after_raid.is_empty():
		_fail("Regroup raid disappeared after advance.")
		return {}
	var after_strength := EnemyAdventureRules.raid_strength(after_raid)
	var garrison_after := _town_garrison_count(session, "duskfen_bastion", "unit_bog_brute")
	var resource_controller := _resource_controller(session, "river_free_company")
	var event_types := _event_types(result.get("events", []))
	if "ai_target_assigned" not in event_types:
		_fail("Regroup advance did not emit ai_target_assigned: %s" % JSON.stringify(result))
		return {}
	if "ai_raid_regrouped" not in event_types:
		_fail("Regroup advance did not emit ai_raid_regrouped: %s" % JSON.stringify(result))
		return {}
	if after_strength <= before_strength:
		_fail("Regroup did not increase raid strength: before=%d after=%d raid=%s" % [before_strength, after_strength, JSON.stringify(after_raid)])
		return {}
	if garrison_after >= garrison_before:
		_fail("Regroup did not pull from town garrison: before=%d after=%d" % [garrison_before, garrison_after])
		return {}
	if String(after_raid.get("last_regroup_town_id", "")) != "duskfen_bastion":
		_fail("Regroup did not record duskfen_bastion as regroup town: %s" % JSON.stringify(after_raid))
		return {}
	if String(after_raid.get("target_kind", "")) != "resource" or String(after_raid.get("target_placement_id", "")) != "river_free_company":
		_fail("Regrouped raid should resume its previous resource target after reaching a usable host strength: %s" % JSON.stringify(after_raid))
		return {}
	var resumed_reason_codes := _string_array(after_raid.get("target_reason_codes", []))
	if "regroup_complete" not in resumed_reason_codes or "persistent_income_denial" not in resumed_reason_codes:
		_fail("Regrouped raid resume missed preserved objective reason codes: %s" % JSON.stringify(after_raid))
		return {}
	if resource_controller == MIRECLAW:
		_fail("Understrength raid captured the original offensive resource instead of regrouping.")
		return {}
	_assert_task_status(session, "hero_vaska", "regroup", "duskfen_bastion", "completed", "valid")
	_assert_task_status(session, "hero_vaska", "resource", "river_free_company", "active", "valid")
	if _failed:
		return {}
	EnemyTurnRules.normalize_enemy_states(session)
	_assert_task_status(session, "hero_vaska", "regroup", "duskfen_bastion", "completed", "valid")
	_assert_task_status(session, "hero_vaska", "resource", "river_free_company", "active", "valid")
	if _failed:
		return {}
	var task_state := _task_state(session)
	return {
		"case_id": "river_pass_understrength_raid_regroups_at_duskfen",
		"before_strength": before_strength,
		"after_strength": after_strength,
		"desired_before": desired_before,
		"garrison_before": garrison_before,
		"garrison_after": garrison_after,
		"event_types": event_types,
		"message": String(result.get("message", "")),
		"resource_controller_after": resource_controller,
		"regroup_town_id": String(after_raid.get("last_regroup_town_id", "")),
		"resumed_target_kind": String(after_raid.get("target_kind", "")),
		"resumed_target_id": String(after_raid.get("target_placement_id", "")),
		"resumed_reason_codes": resumed_reason_codes,
		"goal_distance_after_resume": int(after_raid.get("goal_distance", 9999)),
		"saved_plan_target_kind": String(saved_plan.get("target_kind", "")),
		"saved_plan_target_id": String(saved_plan.get("target_placement_id", "")),
		"saved_plan_reason_codes": saved_reason_codes,
		"task_status_counts": _task_status_counts(task_state),
	}

func _guarded_resource_claim_retargets_to_guard() -> Dictionary:
	var session = _base_session()
	session.day = 2
	var config := _enemy_config()
	var state := _enemy_state(session)
	_set_resource_controller(session, "river_free_company", "player")
	_seed_task_board(session, [_resource_task("hero_vaska", "river_free_company", "active", "valid")])
	var guard := _resource_guard_encounter()
	var encounters: Array = session.overworld.get("encounters", [])
	encounters.append(guard)
	var raid := _guarded_resource_claim_raid(session)
	encounters.append(raid)
	session.overworld["encounters"] = encounters

	var result := EnemyAdventureRules.advance_raids(session, config, MIRECLAW, state)
	var after_raid := _encounter(session, "guarded_resource_claim_vaska")
	if after_raid.is_empty():
		_fail("Guarded resource claim raid disappeared after advance.")
		return {}
	if _resource_controller(session, "river_free_company") != "player":
		_fail("Guarded resource was seized before its guard was cleared: %s" % JSON.stringify(after_raid))
		return {}
	if String(after_raid.get("target_kind", "")) != "encounter" or String(after_raid.get("target_placement_id", "")) != "river_free_company_guard":
		_fail("Guarded resource claim did not retarget to the guard encounter: %s" % JSON.stringify(after_raid))
		return {}
	var reason_codes := _string_array(after_raid.get("target_reason_codes", []))
	if "guard_clearance" not in reason_codes or "guarded_resource_claim" not in reason_codes:
		_fail("Guarded resource redirect missed guard-clearance reason codes: %s" % JSON.stringify(after_raid))
		return {}
	if String(after_raid.get("guarded_claim_target_id", "")) != "river_free_company":
		_fail("Guarded resource redirect did not retain original claim target: %s" % JSON.stringify(after_raid))
		return {}
	if String(after_raid.get("target_public_reason", "")) != "clearing guard before claim":
		_fail("Guarded resource redirect has wrong public reason: %s" % JSON.stringify(after_raid))
		return {}
	var event_types := _event_types(result.get("events", []))
	if "ai_target_assigned" not in event_types:
		_fail("Guarded resource redirect did not emit ai_target_assigned: %s" % JSON.stringify(result))
		return {}
	if "ai_site_seized" in event_types:
		_fail("Guarded resource redirect incorrectly emitted ai_site_seized: %s" % JSON.stringify(result))
		return {}
	_assert_task_status(session, "hero_vaska", "resource", "river_free_company", "active", "valid")
	if _failed:
		return {}
	var public_log := EnemyAdventureRules.ai_public_event_log_boundary_report(result.get("events", []), 8)
	if not bool(public_log.get("ok", false)):
		_fail("Guarded resource redirect public event boundary failed: %s" % JSON.stringify(public_log))
		return {}

	var guard_result := EnemyAdventureRules.advance_raids(session, config, MIRECLAW, state)
	var after_guard_raid := _encounter(session, "guarded_resource_claim_vaska")
	if after_guard_raid.is_empty():
		_fail("Guarded resource claim raid disappeared after guard clear.")
		return {}
	if _resource_controller(session, "river_free_company") != "player":
		_fail("Guarded resource was seized during guard clearance instead of after retarget: %s" % JSON.stringify(after_guard_raid))
		return {}
	if String(after_guard_raid.get("target_kind", "")) != "resource" or String(after_guard_raid.get("target_placement_id", "")) != "river_free_company":
		_fail("Guarded resource claim did not resume the original resource after guard clear: %s" % JSON.stringify(after_guard_raid))
		return {}
	var resumed_reason_codes := _string_array(after_guard_raid.get("target_reason_codes", []))
	if "guard_cleared" not in resumed_reason_codes or "guarded_resource_claim" not in resumed_reason_codes:
		_fail("Guarded resource resume missed guard-cleared reason codes: %s" % JSON.stringify(after_guard_raid))
		return {}
	if String(after_guard_raid.get("guarded_claim_target_id", "")) != "":
		_fail("Guarded resource resume did not clear transient guarded_claim metadata: %s" % JSON.stringify(after_guard_raid))
		return {}
	var guard_event_types := _event_types(guard_result.get("events", []))
	if "ai_target_assigned" not in guard_event_types:
		_fail("Guarded resource resume did not emit ai_target_assigned: %s" % JSON.stringify(guard_result))
		return {}
	if "ai_site_seized" in guard_event_types:
		_fail("Guarded resource guard-clear turn incorrectly emitted ai_site_seized: %s" % JSON.stringify(guard_result))
		return {}
	_assert_task_status(session, "hero_vaska", "resource", "river_free_company", "active", "valid")
	if _failed:
		return {}

	var claim_result := EnemyAdventureRules.advance_raids(session, config, MIRECLAW, state)
	var after_claim_raid := _encounter(session, "guarded_resource_claim_vaska")
	if _resource_controller(session, "river_free_company") != MIRECLAW:
		_fail("Guarded resource was not seized after guard clearance and resume: %s" % JSON.stringify(after_claim_raid))
		return {}
	var claim_event_types := _event_types(claim_result.get("events", []))
	if "ai_site_seized" not in claim_event_types:
		_fail("Guarded resource final claim did not emit ai_site_seized: %s" % JSON.stringify(claim_result))
		return {}
	_assert_task_status(session, "hero_vaska", "resource", "river_free_company", "completed", "valid")
	if _failed:
		return {}
	return {
		"case_id": "guarded_resource_claim_resumes_and_secures_after_guard_clear",
		"resource_controller_after_redirect": "player",
		"resource_controller_after_guard_clear": "player",
		"resource_controller_after_claim": _resource_controller(session, "river_free_company"),
		"redirect_target_kind": String(after_raid.get("target_kind", "")),
		"redirect_target_id": String(after_raid.get("target_placement_id", "")),
		"resume_target_kind": String(after_guard_raid.get("target_kind", "")),
		"resume_target_id": String(after_guard_raid.get("target_placement_id", "")),
		"guarded_claim_target_id": String(after_raid.get("guarded_claim_target_id", "")),
		"reason_codes": reason_codes,
		"resumed_reason_codes": resumed_reason_codes,
		"redirect_event_types": event_types,
		"guard_clear_event_types": guard_event_types,
		"claim_event_types": claim_event_types,
		"public_event_count": int(public_log.get("public_event_count", 0)),
		"task_status_counts": _task_status_counts(_task_state(session)),
	}

func _resource_front_risk_requests_support() -> Dictionary:
	var session = _base_session()
	session.day = 2
	var config := _enemy_config()
	_set_resource_controller(session, "river_free_company", "player")
	var weak_raid := _fragile_resource_claim_raid(session)
	if EnemyAdventureRules.raid_regroup_needed(weak_raid):
		_fail("Resource-front risk fixture should be above the generic regroup floor: %s" % JSON.stringify(weak_raid))
		return {}
	var risk_report := EnemyAdventureRules.resource_arrival_ready_report(session, weak_raid, MIRECLAW)
	if bool(risk_report.get("ready", true)):
		_fail("Resource-front risk fixture was unexpectedly ready: %s" % JSON.stringify(risk_report))
		return {}
	var redirected := EnemyAdventureRules.redirect_resource_objective_for_risk(session, config, weak_raid, MIRECLAW, risk_report)
	if String(redirected.get("target_kind", "")) != "regroup":
		_fail("Fragile resource-front raid did not regroup for support: %s" % JSON.stringify(redirected))
		return {}
	if String(redirected.get("previous_target_kind", "")) != "resource" or String(redirected.get("previous_target_placement_id", "")) != "river_free_company":
		_fail("Resource-front regroup did not preserve previous resource target: %s" % JSON.stringify(redirected))
		return {}
	var redirected_reason_codes := _string_array(redirected.get("target_reason_codes", []))
	if "resource_risk_regroup" not in redirected_reason_codes or "site_contested" not in redirected_reason_codes:
		_fail("Resource-front regroup missed risk/site reason codes: %s" % JSON.stringify(redirected))
		return {}
	var encounters: Array = session.overworld.get("encounters", [])
	encounters.append(redirected)
	session.overworld["encounters"] = encounters
	var support_raid := _regroup_probe_raid(session, "hero_sable", "resource_support_sable_probe", {"x": 8, "y": 3})
	var support_plan := EnemyAdventureRules.ai_active_front_support_target_selection_plan(session, config, support_raid)
	var legacy_support_plan := EnemyAdventureRules._active_front_support_candidate(
		session,
		config,
		MIRECLAW,
		redirected,
		Vector2i(int(support_raid.get("x", 0)), int(support_raid.get("y", 0))),
		String(support_raid.get("placement_id", "")),
		{}
	)
	if JSON.stringify(support_plan) != JSON.stringify(legacy_support_plan):
		_fail("Virtual active-front path context changed the legacy support candidate: shared=%s legacy=%s" % [JSON.stringify(support_plan), JSON.stringify(legacy_support_plan)])
		return {}
	if String(support_plan.get("target_kind", "")) != "resource" or String(support_plan.get("target_placement_id", "")) != "river_free_company":
		_fail("Active front support did not resolve regrouped resource target: %s" % JSON.stringify(support_plan))
		return {}
	var support_reason_codes := _string_array(support_plan.get("target_reason_codes", []))
	if "active_front_support" not in support_reason_codes or "site_contested" not in support_reason_codes:
		_fail("Resource-front support plan missed active/support reason codes: %s" % JSON.stringify(support_plan))
		return {}
	if String(support_plan.get("supporting_front_placement_id", "")) != "resource_risk_vaska":
		_fail("Resource-front support plan linked the wrong active front: %s" % JSON.stringify(support_plan))
		return {}
	if int(support_plan.get("support_strength_gap", 0)) <= 0:
		_fail("Resource-front support plan did not expose an open support gap: %s" % JSON.stringify(support_plan))
		return {}
	return {
		"case_id": "resource_front_risk_requests_active_support",
		"host_strength": int(risk_report.get("host_strength", 0)),
		"required_strength": int(risk_report.get("required_strength", 0)),
		"redirect_target_kind": String(redirected.get("target_kind", "")),
		"redirect_target_id": String(redirected.get("target_placement_id", "")),
		"previous_target_id": String(redirected.get("previous_target_placement_id", "")),
		"redirect_reason_codes": redirected_reason_codes,
		"support_target_kind": String(support_plan.get("target_kind", "")),
		"support_target_id": String(support_plan.get("target_placement_id", "")),
		"support_reason_codes": support_reason_codes,
		"support_strength_gap": int(support_plan.get("support_strength_gap", 0)),
		"virtual_path_context_legacy_match": true,
	}

func _resource_front_support_launches_below_pressure() -> Dictionary:
	var session = _base_session()
	session.day = 2
	var config := _enemy_config()
	var state := _enemy_state(session)
	state["pressure"] = 0
	_update_enemy_state(session, state)
	_set_resource_controller(session, "river_free_company", "player")
	var weak_raid := _fragile_resource_claim_raid(session)
	var risk_report := EnemyAdventureRules.resource_arrival_ready_report(session, weak_raid, MIRECLAW, config)
	if bool(risk_report.get("ready", true)):
		_fail("Support-launch fixture leader should need reinforcement first: %s" % JSON.stringify(risk_report))
		return {}
	var leader := EnemyAdventureRules.redirect_resource_objective_for_risk(session, config, weak_raid, MIRECLAW, risk_report)
	var encounters: Array = session.overworld.get("encounters", [])
	encounters.append(leader)
	session.overworld["encounters"] = encounters
	state = _enemy_state(session)
	var scan_report := _active_front_support_scan_reuse_report(session, config, state)
	if scan_report.is_empty():
		return {}
	var can_launch := EnemyTurnRules._can_launch_raid(session, config, state, MIRECLAW)
	if not can_launch:
		_fail("Active-front support did not satisfy launch readiness below generic pressure.")
		return {}
	var spawn_point := EnemyTurnRules._best_open_spawn_point(session, config, state, MIRECLAW)
	if String(spawn_point.get("spawn_plan_source", "")) != "active_front_support":
		_fail("Best below-pressure spawn point did not select active-front support: %s" % JSON.stringify(spawn_point))
		return {}
	var spawn_result := EnemyTurnRules._spawn_raid(session, config, state)
	if spawn_result.is_empty():
		_fail("Active-front support launch returned an empty spawn result.")
		return {}
	if String(spawn_result.get("spawn_plan_source", "")) != "active_front_support":
		_fail("Spawn result did not preserve active-front support source: %s" % JSON.stringify(spawn_result))
		return {}
	var support_id := String(spawn_result.get("placement_id", ""))
	var support := _encounter(session, support_id)
	if support.is_empty():
		_fail("Spawned active-front support host is missing: %s" % JSON.stringify(spawn_result))
		return {}
	if String(support.get("target_kind", "")) != "resource" or String(support.get("target_placement_id", "")) != "river_free_company":
		_fail("Spawned support did not reinforce the resource front: %s" % JSON.stringify(support))
		return {}
	if String(support.get("supporting_front_placement_id", "")) != "resource_risk_vaska":
		_fail("Spawned support did not remember the supported front: %s" % JSON.stringify(support))
		return {}
	var support_reason_codes := _string_array(support.get("target_reason_codes", []))
	if "active_front_support" not in support_reason_codes or "site_contested" not in support_reason_codes:
		_fail("Spawned support missed support/resource reason codes: %s" % JSON.stringify(support))
		return {}
	var event_types := _event_types(spawn_result.get("events", []))
	if "ai_target_assigned" not in event_types:
		_fail("Active-front support launch did not emit target assignment: %s" % JSON.stringify(spawn_result))
		return {}
	return {
		"case_id": "resource_front_support_launches_below_generic_pressure",
		"can_launch_below_pressure": can_launch,
		"spawn_plan_source": String(spawn_point.get("spawn_plan_source", "")),
		"support_id": support_id,
		"support_target_kind": String(support.get("target_kind", "")),
		"support_target_id": String(support.get("target_placement_id", "")),
		"supporting_front_placement_id": String(support.get("supporting_front_placement_id", "")),
		"support_reason_codes": support_reason_codes,
		"event_types": event_types,
		"state_pressure_after_launch": int(state.get("pressure", 0)),
		"scan_reuse": scan_report,
	}

func _active_front_support_skips_empty_front_scan() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config()
	var state := _enemy_state(session)
	var resolved_encounters: Array = session.overworld.get("resolved_encounters", []) if session.overworld.get("resolved_encounters", []) is Array else []
	var retained_encounters := []
	for encounter_value in session.overworld.get("encounters", []):
		if EnemyAdventureRules.is_active_pressure_host(encounter_value, MIRECLAW, resolved_encounters):
			continue
		retained_encounters.append(encounter_value)
	session.overworld["encounters"] = retained_encounters
	if EnemyTurnRules.active_raid_count(session, MIRECLAW) != 0:
		_fail("Empty active-front scan fixture retained a live Mireclaw pressure host.")
		return {}
	var points: Array = config.get("spawn_points", []) if config.get("spawn_points", []) is Array else []
	if points.is_empty() or not (points[0] is Dictionary):
		_fail("Empty active-front scan fixture has no spawn point.")
		return {}
	var occupied := EnemyAdventureRules.occupied_raid_commander_ids(session, MIRECLAW)
	EnemyTurnRules._spawn_profile_begin(true)
	var candidate := EnemyTurnRules._active_front_support_spawn_candidate_for_point(
		session,
		config,
		state,
		MIRECLAW,
		points[0],
		occupied,
		0,
		{}
	)
	var profile := EnemyTurnRules._spawn_profile_finish()
	var counts: Dictionary = profile.get("counts", {}) if profile.get("counts", {}) is Dictionary else {}
	if not candidate.is_empty():
		_fail("Empty active-front scan produced an impossible support candidate: %s" % JSON.stringify(candidate))
		return {}
	if int(counts.get("active_front_support_no_active_front_skip", 0)) != 1:
		_fail("Empty active-front scan did not take the explicit no-front skip: %s" % JSON.stringify(profile))
		return {}
	if int(counts.get("active_front_support_commander_candidates_loaded", 0)) != 0 \
			or int(counts.get("active_front_support_probe_loaded", 0)) != 0:
		_fail("Empty active-front scan constructed commander or army probes: %s" % JSON.stringify(profile))
		return {}
	return {
		"case_id": "active_front_support_skips_empty_front_probe_construction",
		"no_active_front_skip_count": int(counts.get("active_front_support_no_active_front_skip", 0)),
		"commander_candidates_loaded": int(counts.get("active_front_support_commander_candidates_loaded", 0)),
		"commander_probes_loaded": int(counts.get("active_front_support_probe_loaded", 0)),
	}

func _active_front_support_scan_reuse_report(session, config: Dictionary, state: Dictionary) -> Dictionary:
	var points: Array = config.get("spawn_points", []) if config.get("spawn_points", []) is Array else []
	if points.is_empty() or not (points[0] is Dictionary):
		_fail("Active-front scan fixture has no spawn point.")
		return {}
	var point: Dictionary = points[0]
	var occupied := EnemyAdventureRules.occupied_raid_commander_ids(session, MIRECLAW)
	var fresh_candidates := []
	for spawn_order in range(3):
		fresh_candidates.append(EnemyTurnRules._active_front_support_spawn_candidate_for_point(
			session,
			config,
			state,
			MIRECLAW,
			point,
			occupied,
			spawn_order,
			{}
		))
	var shared_context := {}
	var shared_candidates := []
	EnemyTurnRules._spawn_profile_begin(true)
	for spawn_order in range(3):
		shared_candidates.append(EnemyTurnRules._active_front_support_spawn_candidate_for_point(
			session,
			config,
			state,
			MIRECLAW,
			point,
			occupied,
			spawn_order,
			shared_context
		))
	var profile := EnemyTurnRules._spawn_profile_finish()
	var counts: Dictionary = profile.get("counts", {}) if profile.get("counts", {}) is Dictionary else {}
	for candidate in fresh_candidates:
		if not (candidate is Dictionary) or candidate.is_empty():
			_fail("Active-front scan reuse fixture produced an empty candidate.")
			return {}
	if JSON.stringify(fresh_candidates) != JSON.stringify(shared_candidates):
		_fail("Shared active-front probe payloads changed candidate behavior: fresh=%s shared=%s" % [JSON.stringify(fresh_candidates), JSON.stringify(shared_candidates)])
		return {}
	var probe_loaded := int(counts.get("active_front_support_probe_loaded", 0))
	var probe_reused := int(counts.get("active_front_support_probe_reused", 0))
	if probe_loaded <= 0 or probe_reused != probe_loaded * 2:
		_fail("Active-front probe cache loaded/reused %d/%d instead of one load and two reuses per commander." % [probe_loaded, probe_reused])
		return {}
	if int(counts.get("active_front_support_commander_candidates_loaded", 0)) != 1 \
			or int(counts.get("active_front_support_commander_candidates_reused", 0)) != 2:
		_fail("Active-front commander candidates were not shared across three origin checks: %s" % JSON.stringify(counts))
		return {}
	if int(counts.get("active_front_support_path_context_loaded", 0)) != 1 \
			or int(counts.get("active_front_support_path_context_reused", 0)) != 2:
		_fail("Active-front path context was not loaded once and reused across three origin checks: %s" % JSON.stringify(counts))
		return {}
	if int(counts.get("spawn_scan_path_context_loaded", 0)) != 1 \
			or int(counts.get("spawn_scan_path_context_reused", 0)) != 2:
		_fail("Active-front checks did not consume the one shared spawn path context: %s" % JSON.stringify(counts))
		return {}
	var uncached_launch_surface := []
	for point_index in range(points.size()):
		var launch_point: Dictionary = points[point_index] if points[point_index] is Dictionary else {}
		uncached_launch_surface.append(EnemyTurnRules._active_front_support_spawn_candidate_for_point(
			session,
			config,
			state,
			MIRECLAW,
			launch_point,
			occupied,
			point_index,
			{}
		))
	var uncached_launch_candidate := EnemyTurnRules._best_open_spawn_point(session, config, state, MIRECLAW)
	var launch_scan_cache := {
		"active_front_support_commander_candidates": [],
		"active_front_support_probe_payload_by_commander": {"stale": {"unexpected": true}},
	}
	EnemyTurnRules._spawn_profile_begin(true)
	var readiness_candidate := EnemyTurnRules._active_front_support_launch_ready_report(
		session,
		config,
		state,
		MIRECLAW,
		launch_scan_cache
	)
	var cached_launch_surface: Array = launch_scan_cache.get("active_front_support_candidate_surface", []).duplicate(true) if launch_scan_cache.get("active_front_support_candidate_surface", []) is Array else []
	var cached_launch_candidate := EnemyTurnRules._best_open_spawn_point(
		session,
		config,
		state,
		MIRECLAW,
		false,
		launch_scan_cache
	)
	var launch_surface_profile := EnemyTurnRules._spawn_profile_finish()
	var launch_surface_counts: Dictionary = launch_surface_profile.get("counts", {}) if launch_surface_profile.get("counts", {}) is Dictionary else {}
	if uncached_launch_candidate.is_empty() or String(uncached_launch_candidate.get("spawn_plan_source", "")) != "active_front_support":
		_fail("Uncached active-front launch fixture selected the wrong candidate: %s" % JSON.stringify(uncached_launch_candidate))
		return {}
	var uncached_launch_surface_keys := []
	var cached_launch_surface_keys := []
	for candidate in uncached_launch_surface:
		uncached_launch_surface_keys.append(_spawn_candidate_payload_key(candidate))
	for candidate in cached_launch_surface:
		cached_launch_surface_keys.append(_spawn_candidate_payload_key(candidate))
	if uncached_launch_surface_keys != cached_launch_surface_keys:
		_fail("Active-front launch readiness changed a per-origin candidate payload: uncached=%s cached=%s" % [JSON.stringify(uncached_launch_surface), JSON.stringify(cached_launch_surface)])
		return {}
	if _spawn_candidate_payload_key(readiness_candidate) != _spawn_candidate_payload_key(cached_launch_candidate) \
			or _spawn_candidate_payload_key(uncached_launch_candidate) != _spawn_candidate_payload_key(cached_launch_candidate):
		_fail("Active-front launch-surface reuse changed candidate behavior: readiness=%s cached=%s uncached=%s" % [JSON.stringify(readiness_candidate), JSON.stringify(cached_launch_candidate), JSON.stringify(uncached_launch_candidate)])
		return {}
	if int(launch_surface_counts.get("active_front_candidate_surface_loaded", 0)) != 1 \
			or int(launch_surface_counts.get("active_front_candidate_surface_point_reused", 0)) != points.size() \
			or int(launch_surface_counts.get("active_front_candidate_surface_consumed", 0)) != 1:
		_fail("Active-front launch surface was not loaded, reused for every point, and consumed exactly once: %s" % JSON.stringify(launch_surface_profile))
		return {}
	if int(launch_surface_counts.get("active_front_support_commander_candidates_loaded", 0)) != 1 \
			or int(launch_surface_counts.get("active_front_support_probe_loaded", 0)) <= 0:
		_fail("Final selection rebuilt active-front commanders or probes instead of consuming readiness work: %s" % JSON.stringify(launch_surface_profile))
		return {}
	if int(launch_surface_counts.get("active_front_support_path_context_loaded", 0)) != 1 \
			or int(launch_surface_counts.get("active_front_support_path_context_reused", 0)) != max(0, points.size() - 1):
		_fail("Active-front launch readiness did not share one path context across every origin: %s" % JSON.stringify(launch_surface_profile))
		return {}
	if int(launch_surface_counts.get("spawn_scan_path_context_loaded", 0)) != 1 \
			or int(launch_surface_counts.get("spawn_scan_path_context_reused", 0)) != max(0, points.size() - 1):
		_fail("Active-front launch readiness rebuilt a separate ordinary spawn path graph: %s" % JSON.stringify(launch_surface_profile))
		return {}
	if launch_scan_cache.has("active_front_support_candidate_surface") \
			or launch_scan_cache.has("active_front_support_candidate_surface_complete") \
			or launch_scan_cache.has("path_context"):
		_fail("Consumed active-front launch surface remained cached: %s" % JSON.stringify(launch_scan_cache))
		return {}
	EnemyTurnRules._spawn_profile_begin(true)
	var recomputed_launch_candidate := EnemyTurnRules._best_open_spawn_point(
		session,
		config,
		state,
		MIRECLAW,
		false,
		launch_scan_cache
	)
	var recompute_profile := EnemyTurnRules._spawn_profile_finish()
	var recompute_counts: Dictionary = recompute_profile.get("counts", {}) if recompute_profile.get("counts", {}) is Dictionary else {}
	if _spawn_candidate_payload_key(recomputed_launch_candidate) != _spawn_candidate_payload_key(uncached_launch_candidate):
		_fail("Post-consumption active-front scan did not recompute the same live candidate: %s" % JSON.stringify(recomputed_launch_candidate))
		return {}
	if int(recompute_counts.get("active_front_candidate_surface_point_reused", 0)) != 0 \
			or int(recompute_counts.get("active_front_support_commander_candidates_loaded", 0)) != 1 \
			or int(recompute_counts.get("active_front_support_probe_loaded", 0)) <= 0 \
			or int(recompute_counts.get("active_front_support_path_context_loaded", 0)) != 1:
		_fail("Post-consumption active-front scan reused stale surface state instead of recomputing: %s" % JSON.stringify(recompute_profile))
		return {}
	return {
		"candidate_count": shared_candidates.size(),
		"candidate_payloads_match": true,
		"commander_candidates_loaded": int(counts.get("active_front_support_commander_candidates_loaded", 0)),
		"commander_candidates_reused": int(counts.get("active_front_support_commander_candidates_reused", 0)),
		"commander_probes_loaded": probe_loaded,
		"commander_probes_reused": probe_reused,
		"path_context_loaded": int(counts.get("active_front_support_path_context_loaded", 0)),
		"path_context_reused": int(counts.get("active_front_support_path_context_reused", 0)),
		"shared_spawn_path_context_loaded": int(counts.get("spawn_scan_path_context_loaded", 0)),
		"shared_spawn_path_context_reused": int(counts.get("spawn_scan_path_context_reused", 0)),
		"launch_surface_candidate_match": true,
		"launch_surface_all_origin_payloads_match": true,
		"launch_surface_context_isolated": true,
		"launch_surface_points_reused": int(launch_surface_counts.get("active_front_candidate_surface_point_reused", 0)),
		"launch_surface_path_context_loaded": int(launch_surface_counts.get("active_front_support_path_context_loaded", 0)),
		"launch_surface_path_context_reused": int(launch_surface_counts.get("active_front_support_path_context_reused", 0)),
		"launch_surface_shared_spawn_path_context_loaded": int(launch_surface_counts.get("spawn_scan_path_context_loaded", 0)),
		"launch_surface_shared_spawn_path_context_reused": int(launch_surface_counts.get("spawn_scan_path_context_reused", 0)),
		"launch_surface_consumed": int(launch_surface_counts.get("active_front_candidate_surface_consumed", 0)),
		"post_consumption_recomputed": true,
	}

func _spawn_candidate_payload_key(candidate_value) -> String:
	if not (candidate_value is Dictionary):
		return JSON.stringify(candidate_value)
	var candidate: Dictionary = candidate_value.duplicate(true)
	for coordinate_key in ["x", "y"]:
		if candidate.has(coordinate_key) and (candidate[coordinate_key] is int or candidate[coordinate_key] is float):
			candidate[coordinate_key] = float(candidate[coordinate_key])
	return JSON.stringify(candidate)

func _resource_front_support_consolidates_into_capture_ready_host() -> Dictionary:
	var session = _base_session()
	session.day = 2
	var config := _enemy_config()
	var state := _enemy_state(session)
	_set_resource_controller(session, "river_free_company", "player")
	var leader := _fragile_resource_claim_raid(session)
	leader["target_reason_codes"] = ["resource_risk_staging", "awaiting_support", "site_contested", "persistent_income_denial"]
	leader["target_public_reason"] = "gathering strength for resource claim"
	var before_report := EnemyAdventureRules.resource_arrival_ready_report(session, leader, MIRECLAW, config)
	if bool(before_report.get("ready", true)):
		_fail("Resource-front consolidation fixture should start below capture readiness: %s" % JSON.stringify(before_report))
		return {}
	var encounters: Array = session.overworld.get("encounters", [])
	var leader_index := encounters.size()
	encounters.append(leader)
	session.overworld["encounters"] = encounters
	var support_probe := _regroup_probe_raid(session, "hero_sable", "resource_support_sable_merge", {"x": 9, "y": 1})
	var support := support_probe.duplicate(true)
	support.merge({
		"target_kind": "resource",
		"target_placement_id": "river_free_company",
		"target_label": "Riverwatch Free Company Yard",
		"target_x": 0,
		"target_y": 4,
		"goal_x": 0,
		"goal_y": 4,
		"target_reason_codes": ["active_front_support", "army_consolidation", "site_contested", "resource_risk_staging"],
		"target_public_reason": "reinforcing active front",
		"target_public_importance": "high",
		"supporting_front_placement_id": "resource_risk_vaska",
	}, true)
	support["enemy_army"] = {
		"id": "resource_support_merge_host",
		"name": "Resource Support Merge Host",
		"stacks": [{"unit_id": "unit_bog_brute", "count": 4}],
	}
	support = EnemyAdventureRules.ensure_raid_army(support, session)
	encounters = session.overworld.get("encounters", [])
	encounters.append(support)
	session.overworld["encounters"] = encounters
	var leader_before_strength := EnemyAdventureRules.raid_strength(leader)
	var support_strength := EnemyAdventureRules.raid_strength(support)
	var grouping_result := EnemyAdventureRules.group_nearby_raids_for_town_assault(
		session,
		config,
		session.overworld.get("encounters", []),
		leader_index,
		leader,
		MIRECLAW,
		session.overworld.get("resolved_encounters", [])
	)
	if not bool(grouping_result.get("grouped", false)):
		_fail("Resource-front support did not consolidate into the lead host: %s" % JSON.stringify(grouping_result))
		return {}
	var grouped: Dictionary = grouping_result.get("encounter", {})
	var grouped_strength := EnemyAdventureRules.raid_strength(grouped)
	if grouped_strength <= leader_before_strength:
		_fail("Resource-front grouping did not increase lead host strength: leader=%d support=%d grouped=%d" % [leader_before_strength, support_strength, grouped_strength])
		return {}
	if int(grouped.get("grouped_support_count", 0)) < 1:
		_fail("Resource-front grouping did not record support consolidation: %s" % JSON.stringify(grouped))
		return {}
	var resolved: Array = session.overworld.get("resolved_encounters", []) if session.overworld.get("resolved_encounters", []) is Array else []
	if "resource_support_sable_merge" not in resolved:
		_fail("Grouped resource-front support was not removed from active pressure: %s" % JSON.stringify(resolved))
		return {}
	var event_types := _event_types(grouping_result.get("events", []))
	if "ai_raid_grouped" not in event_types:
		_fail("Resource-front grouping did not emit ai_raid_grouped: %s" % JSON.stringify(grouping_result.get("events", [])))
		return {}
	var after_report := EnemyAdventureRules.resource_arrival_ready_report(session, grouped, MIRECLAW, config)
	if not bool(after_report.get("ready", false)):
		_fail("Merged resource-front host still failed capture readiness: %s" % JSON.stringify(after_report))
		return {}
	grouped["arrived"] = true
	var arrival_result := EnemyAdventureRules._resolve_arrived_target(session, grouped, state, MIRECLAW, config)
	if String(_resource_controller(session, "river_free_company")) != MIRECLAW:
		_fail("Merged resource-front host did not seize the resource: %s" % JSON.stringify(arrival_result))
		return {}
	return {
		"case_id": "resource_front_support_consolidates_into_capture_ready_host",
		"leader_strength_before": leader_before_strength,
		"support_strength": support_strength,
		"grouped_strength": grouped_strength,
		"ready_before": bool(before_report.get("ready", true)),
		"ready_after": bool(after_report.get("ready", false)),
		"resolved_support_id": "resource_support_sable_merge",
		"group_event_types": event_types,
		"resource_controller_after_capture": _resource_controller(session, "river_free_company"),
	}

func _valid_but_unreachable_target_reroutes_to_regroup() -> Dictionary:
	var session = _base_session()
	session.day = 2
	var config := _enemy_config()
	var state := _enemy_state(session)
	_set_resource_controller(session, "river_free_company", "player")
	_set_resource_position(session, "river_free_company", Vector2i(5, 5))
	_block_cardinal_neighbors(session, Vector2i(5, 5))
	_seed_task_board(session, [_resource_task("hero_vaska", "river_free_company", "active", "valid")])
	var raid := _unreachable_route_raid(session)
	if EnemyAdventureRules.raid_regroup_needed(raid):
		_fail("Unreachable-route fixture raid should be strong enough to avoid understrength regroup: %s" % JSON.stringify(raid))
		return {}
	var encounters: Array = session.overworld.get("encounters", [])
	encounters.append(raid)
	session.overworld["encounters"] = encounters

	var result := EnemyAdventureRules.advance_raids(session, config, MIRECLAW, state)
	var after_raid := _encounter(session, "unreachable_route_vaska")
	if after_raid.is_empty():
		_fail("Unreachable-route raid disappeared after advance.")
		return {}
	var post_recovery_target_kind := String(after_raid.get("target_kind", ""))
	var post_recovery_target_reachable := post_recovery_target_kind in ["town", "resource", "artifact", "encounter", "hero", "explore"] \
		and int(after_raid.get("goal_distance", 9999)) < 9999
	var recovered_to_regroup := String(after_raid.get("last_regroup_town_id", "")) == "duskfen_bastion" \
		and int(after_raid.get("route_recovery_started_day", 0)) == int(session.day) \
		and (
			(post_recovery_target_kind == "regroup" and String(after_raid.get("target_placement_id", "")) == "duskfen_bastion")
			or post_recovery_target_kind == ""
			or post_recovery_target_reachable
		)
	if not recovered_to_regroup:
		_fail("Unreachable-route raid did not recover through reachable regroup town: %s" % JSON.stringify(after_raid))
		return {}
	if String(after_raid.get("previous_target_kind", "")) != "resource" or String(after_raid.get("previous_target_placement_id", "")) != "river_free_company":
		_fail("Unreachable-route retask did not preserve previous target metadata: %s" % JSON.stringify(after_raid))
		return {}
	var reason_codes := _event_reason_codes(result.get("events", []), "ai_target_assigned")
	if "route_unreachable" not in reason_codes or "regroup_route_recovery" not in reason_codes:
		_fail("Unreachable-route retask missed route recovery reason codes: %s" % JSON.stringify(after_raid))
		return {}
	if _resource_controller(session, "river_free_company") == MIRECLAW:
		_fail("Unreachable-route raid seized the isolated resource instead of recovering.")
		return {}
	var event_types := _event_types(result.get("events", []))
	if "ai_target_assigned" not in event_types:
		_fail("Unreachable-route recovery did not emit ai_target_assigned: %s" % JSON.stringify(result))
		return {}
	_assert_task_status(session, "hero_vaska", "resource", "river_free_company", "invalid", "invalid_route_unreachable")
	_assert_task_status(session, "hero_vaska", "regroup", "duskfen_bastion", "completed", "valid")
	if _failed:
		return {}
	return {
		"case_id": "valid_resource_target_unreachable_reroutes_to_regroup",
		"after_target_kind": String(after_raid.get("target_kind", "")),
		"after_target_id": String(after_raid.get("target_placement_id", "")),
		"previous_target_id": String(after_raid.get("previous_target_placement_id", "")),
		"reason_codes": reason_codes,
		"event_types": event_types,
		"resource_controller_after": _resource_controller(session, "river_free_company"),
		"goal_distance_after": int(after_raid.get("goal_distance", 9999)),
		"task_status_counts": _task_status_counts(_task_state(session)),
	}

func _regroup_prefers_useful_garrison_town() -> Dictionary:
	var session = _base_session()
	session.day = 2
	var config := _enemy_config()
	var state := _enemy_state(session)
	_set_resource_controller(session, "river_free_company", "player")
	_set_town_garrison(session, "duskfen_bastion", [])
	_append_enemy_town(
		session,
		{
			"placement_id": "reed_reserve_redoubt",
			"town_id": "town_duskfen",
			"x": 7,
			"y": 1,
			"owner": "enemy",
			"garrison": [{"unit_id": "unit_bog_brute", "count": 8}],
		}
	)
	var raid := _understrength_raid(session, config)
	var before_strength := EnemyAdventureRules.raid_strength(raid)
	if not EnemyAdventureRules.raid_regroup_needed(raid):
		_fail("Garrison-aware fixture raid should require regroup: %s" % JSON.stringify(raid))
		return {}
	var reserve_before := _town_garrison_count(session, "reed_reserve_redoubt", "unit_bog_brute")
	var encounters: Array = session.overworld.get("encounters", [])
	encounters.append(raid)
	session.overworld["encounters"] = encounters

	var result := EnemyAdventureRules.advance_raids(session, config, MIRECLAW, state)
	var after_raid := _encounter(session, "regroup_vaska_understrength")
	if after_raid.is_empty():
		_fail("Garrison-aware regroup raid disappeared after advance.")
		return {}
	if String(after_raid.get("last_regroup_town_id", "")) != "reed_reserve_redoubt":
		_fail("Regroup routing did not choose the useful reserve garrison town over empty Duskfen: %s" % JSON.stringify(after_raid))
		return {}
	if bool(after_raid.get("raid_retired_to_rebuild", false)):
		_fail("Garrison-aware regroup retired even though a useful reserve existed: %s" % JSON.stringify(after_raid))
		return {}
	var after_strength := EnemyAdventureRules.raid_strength(after_raid)
	if after_strength <= before_strength:
		_fail("Garrison-aware regroup did not strengthen host: before=%d after=%d raid=%s" % [before_strength, after_strength, JSON.stringify(after_raid)])
		return {}
	var reserve_after := _town_garrison_count(session, "reed_reserve_redoubt", "unit_bog_brute")
	if reserve_after >= reserve_before:
		_fail("Garrison-aware regroup did not pull from reserve redoubt: before=%d after=%d" % [reserve_before, reserve_after])
		return {}
	if _town_garrison_count(session, "duskfen_bastion", "unit_bog_brute") != 0:
		_fail("Empty nearest regroup town unexpectedly gained or spent garrison.")
		return {}
	_assert_task_status(session, "hero_vaska", "regroup", "reed_reserve_redoubt", "completed", "valid")
	if _failed:
		return {}
	var event_types := _event_types(result.get("events", []))
	return {
		"case_id": "regroup_prefers_useful_garrison_town_over_empty_nearest",
		"before_strength": before_strength,
		"after_strength": after_strength,
		"selected_town_id": String(after_raid.get("last_regroup_town_id", "")),
		"empty_nearest_town_id": "duskfen_bastion",
		"reserve_before": reserve_before,
		"reserve_after": reserve_after,
		"event_types": event_types,
		"task_status_counts": _task_status_counts(_task_state(session)),
	}

func _neutral_town_assault_support_consolidates() -> Dictionary:
	var session = _base_session()
	session.day = 2
	var config := _enemy_config()
	var neutral_town := {
		"placement_id": "neutral_reed_crossing",
		"town_id": "town_duskfen",
		"name": "Neutral Reed Crossing",
		"x": 6,
		"y": 3,
		"owner": "neutral",
		"garrison": [{"unit_id": "unit_bog_brute", "count": 9}],
		"available_recruits": {},
		"buildings": [],
	}
	_append_enemy_town(session, neutral_town)
	var leader := _neutral_town_expansion_raid(
		session,
		"neutral_town_leader_host",
		"hero_vaska",
		18,
		Vector2i(5, 3)
	)
	var donor := _neutral_town_expansion_raid(
		session,
		"neutral_town_support_host",
		"hero_sable",
		8,
		Vector2i(5, 4)
	)
	var encounters := [leader, donor]
	session.overworld["encounters"] = encounters.duplicate(true)
	session.overworld["resolved_encounters"] = []
	var before_strength := EnemyAdventureRules.raid_strength(leader)
	var donor_strength := EnemyAdventureRules.raid_strength(donor)
	if EnemyAdventureRules.raid_regroup_needed(leader, config, MIRECLAW):
		_fail("Neutral-town grouping leader should be assault-ready before grouping: %s" % JSON.stringify(leader))
		return {}
	var result := EnemyAdventureRules.group_nearby_raids_for_town_assault(
		session,
		config,
		encounters,
		0,
		leader,
		MIRECLAW,
		[]
	)
	if not bool(result.get("grouped", false)):
		_fail("Neutral-town assault support did not consolidate: %s" % JSON.stringify(result))
		return {}
	var grouped_leader: Dictionary = result.get("encounter", {}) if result.get("encounter", {}) is Dictionary else {}
	var after_strength := EnemyAdventureRules.raid_strength(grouped_leader)
	if after_strength <= before_strength:
		_fail("Neutral-town grouping did not strengthen leader: before=%d after=%d result=%s" % [before_strength, after_strength, JSON.stringify(result)])
		return {}
	if not _resolved_contains(session, "neutral_town_support_host"):
		_fail("Neutral-town grouping did not retire the support host into resolved encounters.")
		return {}
	var reason_codes := _string_array(grouped_leader.get("target_reason_codes", []))
	if "army_consolidation" not in reason_codes or "neutral_town_siege" not in reason_codes or "town_expansion" not in reason_codes:
		_fail("Neutral-town grouping lost expansion reason codes: %s" % JSON.stringify(grouped_leader))
		return {}
	var event_types := _event_types(result.get("events", []))
	if "ai_raid_grouped" not in event_types:
		_fail("Neutral-town grouping did not emit ai_raid_grouped: %s" % JSON.stringify(result))
		return {}
	return {
		"case_id": "neutral_town_assault_support_consolidates",
		"target_town_id": "neutral_reed_crossing",
		"leader_strength_before": before_strength,
		"leader_strength_after": after_strength,
		"donor_strength": donor_strength,
		"donor_resolved": _resolved_contains(session, "neutral_town_support_host"),
		"reason_codes": reason_codes,
		"event_types": event_types,
	}

func _active_raid_resupplies_while_passing_friendly_town() -> Dictionary:
	var session = _base_session()
	session.day = 2
	var config := _enemy_config()
	var state := _enemy_state(session)
	_set_resource_controller(session, "river_free_company", "player")
	_set_town_garrison(session, "duskfen_bastion", [{"unit_id": "unit_bog_brute", "count": 10}])
	var raid := _understrength_raid(session, config)
	raid["placement_id"] = "town_resupply_vaska_probe"
	raid["x"] = 8
	raid["y"] = 3
	raid["enemy_army"] = {
		"id": "town_resupply_fixture_host",
		"name": "Travel-Worn Raid Host",
		"stacks": [{"unit_id": "unit_bog_brute", "count": 6}],
	}
	raid = EnemyAdventureRules.ensure_raid_army(raid, session)
	if EnemyAdventureRules.raid_regroup_needed(raid, config, MIRECLAW):
		_fail("Town-resupply fixture should be under desired strength but above regroup floor: %s" % JSON.stringify(EnemyAdventureRules.raid_regroup_threshold_report(raid, config, MIRECLAW)))
		return {}
	var before_strength := EnemyAdventureRules.raid_strength(raid)
	var desired_before := EnemyAdventureRules.desired_raid_strength(raid)
	if before_strength >= desired_before:
		_fail("Town-resupply fixture should need reinforcement: before=%d desired=%d raid=%s" % [before_strength, desired_before, JSON.stringify(raid)])
		return {}
	var garrison_before := _town_garrison_count(session, "duskfen_bastion", "unit_bog_brute")
	var encounters: Array = session.overworld.get("encounters", [])
	encounters.append(raid)
	session.overworld["encounters"] = encounters

	var result := EnemyAdventureRules.advance_raids(session, config, MIRECLAW, state, {"only_placement_ids": ["town_resupply_vaska_probe"]})
	var after_raid := _encounter(session, "town_resupply_vaska_probe")
	if after_raid.is_empty():
		_fail("Town-resupply raid disappeared after advance.")
		return {}
	var after_strength := EnemyAdventureRules.raid_strength(after_raid)
	var garrison_after := _town_garrison_count(session, "duskfen_bastion", "unit_bog_brute")
	var event_types := _event_types(result.get("events", []))
	if "ai_raid_reinforced" not in event_types:
		_fail("Town-resupply advance did not emit ai_raid_reinforced: %s" % JSON.stringify(result))
		return {}
	if after_strength <= before_strength:
		_fail("Town-resupply did not increase raid strength: before=%d after=%d raid=%s" % [before_strength, after_strength, JSON.stringify(after_raid)])
		return {}
	if garrison_after >= garrison_before:
		_fail("Town-resupply did not pull from town garrison: before=%d after=%d" % [garrison_before, garrison_after])
		return {}
	if garrison_before - garrison_after > 3:
		_fail("Town-resupply drained more than the bounded need from one pass: before=%d after=%d" % [garrison_before, garrison_after])
		return {}
	if String(after_raid.get("last_town_resupply_town_id", "")) != "duskfen_bastion":
		_fail("Town-resupply did not record duskfen_bastion as the source town: %s" % JSON.stringify(after_raid))
		return {}
	if String(after_raid.get("target_kind", "")) != "resource" or String(after_raid.get("target_placement_id", "")) != "river_free_company":
		_fail("Town-resupply changed the raid objective instead of preserving route pressure: %s" % JSON.stringify(after_raid))
		return {}
	if String(after_raid.get("target_kind", "")) == "regroup":
		_fail("Town-resupply converted a marching raid into a regroup task: %s" % JSON.stringify(after_raid))
		return {}
	return {
		"case_id": "active_raid_resupplies_while_passing_friendly_town",
		"before_strength": before_strength,
		"after_strength": after_strength,
		"desired_before": desired_before,
		"garrison_before": garrison_before,
		"garrison_after": garrison_after,
		"resupply_town_id": String(after_raid.get("last_town_resupply_town_id", "")),
		"resupply_day": int(after_raid.get("last_town_resupply_day", -1)),
		"target_kind_after": String(after_raid.get("target_kind", "")),
		"target_id_after": String(after_raid.get("target_placement_id", "")),
		"event_types": event_types,
		"message": String(result.get("message", "")),
	}

func _regroup_route_occupancy_avoids_visible_player_hero_choke() -> Dictionary:
	var session = _base_session()
	session.day = 2
	var config := _enemy_config()
	_make_regroup_route_occupancy_corridor(session)
	var raid := _understrength_raid(session, config)
	raid["x"] = 8
	raid["y"] = 4
	raid["placement_id"] = "regroup_route_occupancy_probe"
	if not EnemyAdventureRules.raid_regroup_needed(raid):
		_fail("Route-occupancy regroup fixture should require regroup: %s" % JSON.stringify(raid))
		return {}
	var selected := EnemyAdventureRules._nearest_regroup_town(session, raid, MIRECLAW)
	if String(selected.get("placement_id", "")) != "reachable_reed_redoubt":
		_fail("Regroup selected a blocked or missing town instead of the reachable reserve: %s" % JSON.stringify(selected))
		return {}
	var generic_blocked_distance := EnemyAdventureRules._path_distance(
		session,
		Vector2i(8, 4),
		[Vector2i(6, 4)],
		String(raid.get("placement_id", ""))
	)
	var faction_blocked_distance := EnemyAdventureRules._path_distance(
		session,
		Vector2i(8, 4),
		[Vector2i(6, 4)],
		String(raid.get("placement_id", "")),
		MIRECLAW
	)
	var reachable_distance := EnemyAdventureRules._path_distance(
		session,
		Vector2i(8, 4),
		[Vector2i(12, 2)],
		String(raid.get("placement_id", "")),
		MIRECLAW
	)
	if generic_blocked_distance >= reachable_distance:
		_fail("Route-occupancy fixture should make the blocked town generically closer than the reachable reserve.")
		return {}
	if faction_blocked_distance < 9999:
		_fail("Faction-scoped routing should treat the visible player hero choke as blocking: distance=%d" % faction_blocked_distance)
		return {}
	if reachable_distance >= 9999:
		_fail("Reachable reserve should remain routeable under faction-scoped occupancy.")
		return {}
	return {
		"case_id": "regroup_route_occupancy_avoids_visible_player_hero_choke",
		"selected_town_id": String(selected.get("placement_id", "")),
		"blocked_town_id": "blocked_fen_hold",
		"hero_tile": {"x": 7, "y": 4},
		"generic_blocked_distance": generic_blocked_distance,
		"faction_blocked_distance": faction_blocked_distance,
		"reachable_distance": reachable_distance,
	}

func _empty_garrison_regroup_releases_to_rebuild() -> Dictionary:
	var session = _base_session()
	session.day = 2
	var config := _enemy_config()
	var state := _enemy_state(session)
	_set_resource_controller(session, "river_free_company", "player")
	_set_town_garrison(session, "duskfen_bastion", [])
	var raid := _understrength_raid(session, config)
	raid["recent_exploration_target_ids"] = ["explore:7:2", "explore:7:3"]
	var before_strength := EnemyAdventureRules.raid_strength(raid)
	if not EnemyAdventureRules.raid_regroup_needed(raid):
		_fail("Empty-garrison fixture raid should require regroup before release: %s" % JSON.stringify(raid))
		return {}
	var encounters: Array = session.overworld.get("encounters", [])
	encounters.append(raid)
	session.overworld["encounters"] = encounters

	var result := EnemyAdventureRules.advance_raids(session, config, MIRECLAW, state)
	var after_raid := _encounter(session, "regroup_vaska_understrength")
	if after_raid.is_empty():
		_fail("Failed-regroup raid disappeared from encounter history.")
		return {}
	if bool(after_raid.get("raid_retired_to_rebuild", false)) or int(after_raid.get("no_spare_regroup_count", -1)) != 0:
		_fail("Failed-regroup raid should receive one bounded no-spare retry before retirement: %s" % JSON.stringify(after_raid))
		return {}
	for expected_retry_count in [1, 2]:
		result = EnemyAdventureRules.advance_raids(session, config, MIRECLAW, state)
		state = result.get("state", state)
		after_raid = _encounter(session, "regroup_vaska_understrength")
		if after_raid.is_empty():
			_fail("Failed-regroup raid disappeared during bounded retry %d." % expected_retry_count)
			return {}
		if expected_retry_count == 1 and bool(after_raid.get("raid_retired_to_rebuild", false)):
			_fail("Failed-regroup raid retired before exhausting its bounded no-spare retry: %s" % JSON.stringify(after_raid))
			return {}
	if not bool(after_raid.get("raid_retired_to_rebuild", false)):
		_fail("Failed-regroup raid did not retire into rebuild: %s" % JSON.stringify(after_raid))
		return {}
	var rebuild_request: Dictionary = state.get("rebuild_pressure_request", {}) if state.get("rebuild_pressure_request", {}) is Dictionary else {}
	if String(rebuild_request.get("origin_town_id", "")) != "duskfen_bastion" \
			or String(rebuild_request.get("commander_id", "")) != "hero_vaska" \
			or int(rebuild_request.get("requested_day", 0)) != int(session.day):
		_fail("Failed-regroup rebuild request was not returned through live empire state: %s" % JSON.stringify(rebuild_request))
		return {}
	var rebuild_recent_targets := _string_array(rebuild_request.get("recent_exploration_target_ids", []))
	var expected_rebuild_recent_targets := ["explore:7:2", "explore:7:3"]
	if rebuild_recent_targets != expected_rebuild_recent_targets:
		_fail("Failed-regroup rebuild request lost completed frontier history: %s" % JSON.stringify(rebuild_request))
		return {}
	var rebuilt_state := _enemy_state(session)
	if _string_array(rebuilt_state.get("recent_rebuild_exploration_target_ids", [])) != expected_rebuild_recent_targets:
		_fail("Failed-regroup enemy state lost faction frontier history: %s" % JSON.stringify(rebuilt_state))
		return {}
	if String(after_raid.get("target_kind", "")) != "" or bool(after_raid.get("arrived", false)):
		_fail("Retired failed-regroup raid should clear target and stop applying pressure: %s" % JSON.stringify(after_raid))
		return {}
	if not _resolved_contains(session, "regroup_vaska_understrength"):
		_fail("Retired failed-regroup raid was not removed from active encounters.")
		return {}
	if _resource_controller(session, "river_free_company") == MIRECLAW:
		_fail("Failed-regroup raid captured the offensive resource instead of retiring.")
		return {}
	var message := String(result.get("message", ""))
	if "pillages" in message or "press" in message:
		_fail("Retired failed-regroup raid still produced pressure or pillage text: %s" % message)
		return {}
	var event_types := _event_types(result.get("events", []))
	if "ai_raid_regrouped" not in event_types:
		_fail("Failed-regroup retirement did not emit ai_raid_regrouped: %s" % JSON.stringify(result))
		return {}
	_assert_task_status(session, "hero_vaska", "regroup", "duskfen_bastion", "suspended", "invalid_actor_rebuilding")
	if _failed:
		return {}
	var occupied := EnemyAdventureRules.occupied_raid_commander_ids(session, MIRECLAW)
	if occupied.has("hero_vaska"):
		_fail("Retired failed-regroup commander is still treated as an active raid commander: %s" % JSON.stringify(occupied))
		return {}
	var roster_entry := _commander_entry(session, "hero_vaska")
	if roster_entry.is_empty():
		_fail("Missing hero_vaska roster entry after failed regroup.")
		return {}
	if EnemyAdventureRules.commander_can_deploy(roster_entry):
		_fail("Failed-regroup commander is deployable before rebuild: %s" % JSON.stringify(roster_entry))
		return {}
	var continuity := EnemyAdventureRules.commander_army_continuity(roster_entry)
	if int(continuity.get("current_strength", 0)) != before_strength or int(continuity.get("rebuild_need", 0)) <= 0:
		_fail("Failed-regroup commander continuity did not preserve rebuild need: before=%d continuity=%s" % [before_strength, JSON.stringify(continuity)])
		return {}
	EnemyTurnRules.normalize_enemy_states(session)
	_assert_task_status(session, "hero_vaska", "regroup", "duskfen_bastion", "suspended", "invalid_actor_rebuilding")
	if _failed:
		return {}
	return {
		"case_id": "empty_garrison_regroup_releases_to_commander_rebuild",
		"before_strength": before_strength,
		"retired_to_rebuild": bool(after_raid.get("raid_retired_to_rebuild", false)),
		"resolved": _resolved_contains(session, "regroup_vaska_understrength"),
		"event_types": event_types,
		"resource_controller_after": _resource_controller(session, "river_free_company"),
		"commander_deployable_after": EnemyAdventureRules.commander_can_deploy(roster_entry),
		"commander_rebuild_need": int(continuity.get("rebuild_need", 0)),
		"rebuild_request": rebuild_request,
		"rebuild_recent_exploration_target_ids": rebuild_recent_targets,
		"task_status_counts": _task_status_counts(_task_state(session)),
	}

func _commander_risk_tolerance_changes_live_town_gate() -> Dictionary:
	var session = _base_session()
	session.day = 2
	var config := _enemy_config()
	var town := {
		"placement_id": "risk_tolerance_player_hold",
		"town_id": "town_duskfen",
		"x": 4,
		"y": 4,
		"owner": "player",
		"garrison": [],
	}
	var selected := {}
	for count in range(1, 80):
		var aggressive_raid := _town_risk_probe_raid(session, "risk_aggressive_vaska", "hero_vaska", count)
		var cautious_raid := _town_risk_probe_raid(session, "risk_cautious_sable", "hero_sable", count, EnemyAdventureRules.COMMANDER_OUTCOME_DEFEATED)
		var aggressive_report := EnemyAdventureRules._town_assault_advance_risk_report(session, aggressive_raid, town, config)
		var cautious_report := EnemyAdventureRules._town_assault_advance_risk_report(session, cautious_raid, town, config)
		var strength := int(aggressive_report.get("assault_strength", 0))
		if (
			bool(aggressive_report.get("ready", false))
			and not bool(cautious_report.get("ready", true))
			and strength < int(cautious_report.get("required_strength", 0))
		):
			selected = {
				"count": count,
				"aggressive_raid": aggressive_raid,
				"cautious_raid": cautious_raid,
				"aggressive_report": aggressive_report,
				"cautious_report": cautious_report,
			}
			break
	if selected.is_empty():
		_fail("Could not find a split strength where aggressive commander commits and cautious commander regroups.")
		return {}
	var aggressive_report: Dictionary = selected.get("aggressive_report", {})
	var cautious_report: Dictionary = selected.get("cautious_report", {})
	var minimal_cautious_raid: Dictionary = selected.get("cautious_raid", {}).duplicate(true)
	minimal_cautious_raid["enemy_commander_state"] = {
		"roster_hero_id": "hero_sable",
		"last_outcome": EnemyAdventureRules.COMMANDER_OUTCOME_DEFEATED,
	}
	var minimal_cautious_report := EnemyAdventureRules._town_assault_advance_risk_report(session, minimal_cautious_raid, town, config)
	if float(aggressive_report.get("risk_tolerance_scale", 1.0)) >= float(cautious_report.get("risk_tolerance_scale", 1.0)):
		_fail("Commander risk scales did not separate aggressive/cautious reports: aggressive=%s cautious=%s" % [JSON.stringify(aggressive_report), JSON.stringify(cautious_report)])
		return {}
	if int(aggressive_report.get("base_required_strength", 0)) != int(cautious_report.get("base_required_strength", 0)):
		_fail("Risk fixture changed base requirement instead of commander tolerance: aggressive=%s cautious=%s" % [JSON.stringify(aggressive_report), JSON.stringify(cautious_report)])
		return {}
	if float(minimal_cautious_report.get("risk_tolerance_scale", 1.0)) <= 1.0:
		_fail("Minimal cautious commander did not inherit template risk tolerance: %s" % JSON.stringify(minimal_cautious_report))
		return {}
	if absf(float(minimal_cautious_report.get("risk_tolerance_scale", 1.0)) - float(cautious_report.get("risk_tolerance_scale", 1.0))) > 0.001:
		_fail("Minimal cautious commander risk tolerance diverged from full commander state: minimal=%s full=%s" % [JSON.stringify(minimal_cautious_report), JSON.stringify(cautious_report)])
		return {}
	if bool(minimal_cautious_report.get("ready", true)):
		_fail("Minimal cautious commander should remain gated by inherited risk tolerance: %s" % JSON.stringify(minimal_cautious_report))
		return {}
	if minimal_cautious_raid.get("enemy_commander_state", {}).has("battle_traits"):
		_fail("Minimal risk commander fallback mutated source raid state: %s" % JSON.stringify(minimal_cautious_raid))
		return {}
	var cautious_redirect := EnemyAdventureRules.redirect_town_assault_for_risk(
		session,
		config,
		selected.get("cautious_raid", {}),
		MIRECLAW,
		cautious_report
	)
	if String(cautious_redirect.get("target_kind", "")) != "regroup":
		_fail("Cautious defeated commander did not regroup after risk gate: %s" % JSON.stringify(cautious_redirect))
		return {}
	var redirect_reason_codes := _string_array(cautious_redirect.get("target_reason_codes", []))
	if "assault_risk_regroup" not in redirect_reason_codes:
		_fail("Cautious commander regroup missed assault risk reason: %s" % JSON.stringify(cautious_redirect))
		return {}
	return {
		"case_id": "commander_risk_tolerance_shapes_town_assault_gate",
		"stack_count": int(selected.get("count", 0)),
		"assault_strength": int(aggressive_report.get("assault_strength", 0)),
		"base_required_strength": int(aggressive_report.get("base_required_strength", 0)),
		"aggressive_scale": float(aggressive_report.get("risk_tolerance_scale", 1.0)),
		"aggressive_required_strength": int(aggressive_report.get("required_strength", 0)),
		"aggressive_ready": bool(aggressive_report.get("ready", false)),
		"cautious_scale": float(cautious_report.get("risk_tolerance_scale", 1.0)),
		"cautious_required_strength": int(cautious_report.get("required_strength", 0)),
		"cautious_ready": bool(cautious_report.get("ready", true)),
		"minimal_cautious_scale": float(minimal_cautious_report.get("risk_tolerance_scale", 1.0)),
		"minimal_cautious_required_strength": int(minimal_cautious_report.get("required_strength", 0)),
		"minimal_cautious_ready": bool(minimal_cautious_report.get("ready", true)),
		"minimal_cautious_source_mutated": minimal_cautious_raid.get("enemy_commander_state", {}).has("battle_traits"),
		"cautious_redirect_kind": String(cautious_redirect.get("target_kind", "")),
		"cautious_redirect_id": String(cautious_redirect.get("target_placement_id", "")),
		"cautious_redirect_reasons": redirect_reason_codes,
	}

func _faction_personality_changes_regroup_threshold() -> Dictionary:
	var session = _base_session()
	var ember_config := _strategy_only_config(EMBERCOURT)
	var mire_config := _strategy_only_config(MIRECLAW)
	var selected := {}
	for count in range(1, 60):
		var raid := _personality_regroup_probe_raid(session, count)
		var ember_report := EnemyAdventureRules.raid_regroup_threshold_report(raid, ember_config, EMBERCOURT)
		var mire_report := EnemyAdventureRules.raid_regroup_threshold_report(raid, mire_config, MIRECLAW)
		if (
			bool(ember_report.get("regroup_needed", false))
			and not bool(mire_report.get("regroup_needed", true))
			and int(ember_report.get("strategy_floor", 0)) > int(mire_report.get("strategy_floor", 0))
		):
			selected = {
				"count": count,
				"raid": raid,
				"ember_report": ember_report,
				"mire_report": mire_report,
			}
			break
	if selected.is_empty():
		_fail("Could not find a live strength split between defensive and raider regroup thresholds.")
		return {}
	var ember_report: Dictionary = selected.get("ember_report", {})
	var mire_report: Dictionary = selected.get("mire_report", {})
	if float(ember_report.get("strategy_multiplier", 1.0)) <= float(mire_report.get("strategy_multiplier", 1.0)):
		_fail("Faction strategy multipliers did not separate regroup behavior: ember=%s mire=%s" % [JSON.stringify(ember_report), JSON.stringify(mire_report)])
		return {}
	if int(ember_report.get("base_floor", 0)) != int(mire_report.get("base_floor", -1)):
		_fail("Personality regroup fixture changed base floor instead of strategy floor: ember=%s mire=%s" % [JSON.stringify(ember_report), JSON.stringify(mire_report)])
		return {}
	return {
		"case_id": "faction_personality_changes_regroup_threshold",
		"stack_count": int(selected.get("count", 0)),
		"current_strength": int(ember_report.get("current_strength", 0)),
		"desired_strength": int(ember_report.get("desired_strength", 0)),
		"base_floor": int(ember_report.get("base_floor", 0)),
		"ember_strategy_floor": int(ember_report.get("strategy_floor", 0)),
		"mire_strategy_floor": int(mire_report.get("strategy_floor", 0)),
		"ember_multiplier": float(ember_report.get("strategy_multiplier", 1.0)),
		"mire_multiplier": float(mire_report.get("strategy_multiplier", 1.0)),
		"ember_regroup_needed": bool(ember_report.get("regroup_needed", false)),
		"mire_regroup_needed": bool(mire_report.get("regroup_needed", false)),
		"reason_codes": _string_array(selected.get("raid", {}).get("target_reason_codes", [])),
	}

func _understrength_raid(session, config: Dictionary) -> Dictionary:
	var raid := {
		"placement_id": "regroup_vaska_understrength",
		"encounter_id": "encounter_mire_raid",
		"x": 8,
		"y": 1,
		"difficulty": "pressure",
		"combat_seed": hash("%s:regroup_vaska_understrength" % String(session.scenario_id)),
		"spawned_by_faction_id": MIRECLAW,
		"days_active": 0,
		"arrived": false,
		"goal_distance": 9999,
		"target_kind": "resource",
		"target_placement_id": "river_free_company",
		"target_label": "Free Company Camp",
		"target_x": 3,
		"target_y": 4,
		"goal_x": 3,
		"goal_y": 4,
		"enemy_army": {
			"id": "regroup_fixture_host",
			"name": "Damaged Raid Host",
			"stacks": [{"unit_id": "unit_bog_brute", "count": 1}],
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

func _personality_regroup_probe_raid(session, stack_count: int) -> Dictionary:
	var raid := {
		"placement_id": "personality_regroup_probe",
		"encounter_id": "encounter_mire_raid",
		"x": 8,
		"y": 1,
		"difficulty": "pressure",
		"combat_seed": hash("%s:personality_regroup_probe:%d" % [String(session.scenario_id), stack_count]),
		"spawned_by_faction_id": MIRECLAW,
		"days_active": 0,
		"arrived": false,
		"goal_distance": 9999,
		"target_kind": "resource",
		"target_placement_id": "river_free_company",
		"target_label": "Riverwatch Free Company Yard",
		"target_x": 0,
		"target_y": 4,
		"goal_x": 0,
		"goal_y": 4,
		"target_reason_codes": ["persistent_income_denial", "site_contested", "personality_regroup_fixture"],
		"target_public_reason": "site denial pressure",
		"target_public_importance": "high",
		"enemy_army": {
			"id": "personality_regroup_probe_host",
			"name": "Personality Regroup Host",
			"stacks": [{"unit_id": "unit_mire_slinger", "count": max(1, stack_count)}],
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

func _town_risk_probe_raid(session, placement_id: String, roster_hero_id: String, stack_count: int, last_outcome: String = "") -> Dictionary:
	var raid := {
		"placement_id": placement_id,
		"encounter_id": "encounter_mire_raid",
		"x": 8,
		"y": 1,
		"difficulty": "pressure",
		"combat_seed": hash("%s:%s" % [String(session.scenario_id), placement_id]),
		"spawned_by_faction_id": MIRECLAW,
		"days_active": 0,
		"arrived": false,
		"goal_distance": 1,
		"target_kind": "town",
		"target_placement_id": "risk_tolerance_player_hold",
		"target_label": "Risk Tolerance Hold",
		"target_x": 4,
		"target_y": 4,
		"goal_x": 4,
		"goal_y": 4,
		"target_reason_codes": ["town_siege", "risk_tolerance_fixture"],
		"target_public_reason": "town pressure",
		"target_public_importance": "high",
		"enemy_army": {
			"id": "%s_host" % placement_id,
			"name": "Risk Tolerance Host",
			"stacks": [{"unit_id": "unit_bog_brute", "count": max(1, stack_count)}],
		},
	}
	raid["enemy_commander_state"] = EnemyAdventureRules.build_raid_commander_state(
		raid,
		roster_hero_id,
		MIRECLAW,
		session,
		{},
		EnemyAdventureRules.commander_roster_for_faction(session, MIRECLAW)
	)
	if last_outcome != "":
		var commander_state: Dictionary = raid.get("enemy_commander_state", {})
		commander_state["last_outcome"] = last_outcome
		raid["enemy_commander_state"] = commander_state
	return EnemyAdventureRules.ensure_raid_army(raid, session)

func _neutral_town_expansion_raid(
	session,
	placement_id: String,
	roster_hero_id: String,
	stack_count: int,
	origin: Vector2i
) -> Dictionary:
	var raid := {
		"placement_id": placement_id,
		"encounter_id": "encounter_mire_raid",
		"x": origin.x,
		"y": origin.y,
		"difficulty": "pressure",
		"combat_seed": hash("%s:%s" % [String(session.scenario_id), placement_id]),
		"spawned_by_faction_id": MIRECLAW,
		"days_active": 0,
		"arrived": false,
		"goal_distance": 1,
		"target_kind": "town",
		"target_placement_id": "neutral_reed_crossing",
		"target_label": "Neutral Reed Crossing",
		"target_x": 6,
		"target_y": 3,
		"goal_x": 6,
		"goal_y": 3,
		"target_reason_codes": ["town_expansion", "neutral_town_siege"],
		"target_public_reason": "claiming neutral town",
		"target_public_importance": "high",
		"enemy_army": {
			"id": "%s_host" % placement_id,
			"name": "Neutral Town Assault Host",
			"stacks": [{"unit_id": "unit_bog_brute", "count": max(1, stack_count)}],
		},
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

func _guarded_resource_claim_raid(session) -> Dictionary:
	var raid := {
		"placement_id": "guarded_resource_claim_vaska",
		"encounter_id": "encounter_mire_raid",
		"x": 0,
		"y": 4,
		"difficulty": "pressure",
		"combat_seed": hash("%s:guarded_resource_claim_vaska" % String(session.scenario_id)),
		"spawned_by_faction_id": MIRECLAW,
		"days_active": 0,
		"arrived": false,
		"goal_distance": 0,
		"target_kind": "resource",
		"target_placement_id": "river_free_company",
		"target_label": "Riverwatch Free Company Yard",
		"target_x": 0,
		"target_y": 4,
		"goal_x": 0,
		"goal_y": 4,
		"target_reason_codes": ["persistent_income_denial", "recruit_denial"],
		"target_public_reason": "site denial pressure",
		"target_public_importance": "high",
		"enemy_army": {
			"id": "guarded_resource_claim_host",
			"name": "Guarded Claim Host",
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

func _fragile_resource_claim_raid(session) -> Dictionary:
	var raid := {
		"placement_id": "resource_risk_vaska",
		"encounter_id": "encounter_mire_raid",
		"x": 8,
		"y": 1,
		"difficulty": "pressure",
		"combat_seed": hash("%s:resource_risk_vaska" % String(session.scenario_id)),
		"spawned_by_faction_id": MIRECLAW,
		"days_active": 0,
		"arrived": false,
		"goal_distance": 9999,
		"target_kind": "resource",
		"target_placement_id": "river_free_company",
		"target_label": "Riverwatch Free Company Yard",
		"target_x": 0,
		"target_y": 4,
		"goal_x": 0,
		"goal_y": 4,
		"target_reason_codes": ["persistent_income_denial", "site_contested"],
		"target_public_reason": "site denial pressure",
		"target_public_importance": "high",
		"enemy_army": {
			"id": "resource_risk_host",
			"name": "Fragile Resource Front Host",
			"stacks": [{"unit_id": "unit_bog_brute", "count": 5}],
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

func _unreachable_route_raid(session) -> Dictionary:
	var raid := {
		"placement_id": "unreachable_route_vaska",
		"encounter_id": "encounter_mire_raid",
		"x": 8,
		"y": 1,
		"difficulty": "pressure",
		"combat_seed": hash("%s:unreachable_route_vaska" % String(session.scenario_id)),
		"spawned_by_faction_id": MIRECLAW,
		"days_active": 0,
		"arrived": false,
		"goal_distance": 9999,
		"target_kind": "resource",
		"target_placement_id": "river_free_company",
		"target_label": "Riverwatch Free Company Yard",
		"target_x": 5,
		"target_y": 5,
		"goal_x": 5,
		"goal_y": 5,
		"target_reason_codes": ["persistent_income_denial", "recruit_denial"],
		"target_public_reason": "site denial pressure",
		"target_public_importance": "high",
		"enemy_army": {
			"id": "unreachable_route_host",
			"name": "Route Recovery Host",
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

func _resource_guard_encounter() -> Dictionary:
	return {
		"placement_id": "river_free_company_guard",
		"encounter_id": "encounter_roadward_lodge_watch",
		"x": 2,
		"y": 4,
		"difficulty": "medium",
		"combat_seed": 44101,
		"guard_link": {
			"guard_role": "guards_resource_node",
			"target_kind": "resource_node",
			"target_id": "river_free_company",
			"target_placement_id": "river_free_company",
			"blocks_approach": true,
			"clear_required_for_target": true,
		},
	}

func _regroup_probe_raid(session, roster_hero_id: String, placement_id: String, origin: Dictionary) -> Dictionary:
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

func _make_regroup_route_occupancy_corridor(session) -> void:
	var map := []
	for y in range(9):
		var row := []
		for x in range(13):
			var passable := y == 4 or (x == 12 and y >= 2 and y <= 4)
			row.append("grass" if passable else "rock")
		map.append(row)
	session.overworld["map"] = map
	session.overworld["map_size"] = {"width": 13, "height": 9}
	_set_primary_hero_position(session, 7, 4)
	session.overworld["towns"] = [
		{
			"placement_id": "blocked_fen_hold",
			"town_id": "town_duskfen",
			"name": "Blocked Fen Hold",
			"x": 6,
			"y": 4,
			"owner": "enemy",
			"controlling_faction_id": MIRECLAW,
			"garrison": [{"unit_id": "unit_bog_brute", "count": 14}],
			"available_recruits": {},
			"buildings": [],
		},
		{
			"placement_id": "reachable_reed_redoubt",
			"town_id": "town_duskfen",
			"name": "Reachable Reed Redoubt",
			"x": 12,
			"y": 2,
			"owner": "enemy",
			"controlling_faction_id": MIRECLAW,
			"garrison": [{"unit_id": "unit_bog_brute", "count": 14}],
			"available_recruits": {},
			"buildings": [],
		},
	]
	session.overworld["resource_nodes"] = []
	session.overworld["artifact_nodes"] = []
	session.overworld["encounters"] = []
	session.overworld["resolved_encounters"] = []

func _set_primary_hero_position(session, x: int, y: int) -> void:
	var hero: Dictionary = session.overworld.get("hero", {}).duplicate(true)
	hero["id"] = String(session.overworld.get("active_hero_id", "hero_lyra"))
	hero["name"] = String(hero.get("name", "Lyra"))
	hero["position"] = {"x": x, "y": y}
	session.overworld["hero"] = hero
	session.overworld["hero_position"] = {"x": x, "y": y}
	session.overworld["active_hero_id"] = String(hero.get("id", "hero_lyra"))
	session.overworld["player_heroes"] = [hero]

func _enemy_config() -> Dictionary:
	var scenario := ContentService.get_scenario(RIVER_PASS)
	for config in scenario.get("enemy_factions", []):
		if config is Dictionary and String(config.get("faction_id", "")) == MIRECLAW:
			return config
	_fail("Could not find enemy config for %s" % MIRECLAW)
	return {}

func _strategy_only_config(faction_id: String) -> Dictionary:
	return {
		"faction_id": faction_id,
		"label": String(ContentService.get_faction(faction_id).get("name", faction_id)),
	}

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
		"planner_epoch": 14,
		"tasks": tasks,
	}
	_update_enemy_state(session, state)

func _regroup_task(actor_id: String, target_id: String, status: String, validation: String) -> Dictionary:
	return {
		"task_id": "task:regroup:%s:%s" % [actor_id, target_id],
		"owner_faction_id": MIRECLAW,
		"actor_kind": "commander_roster",
		"actor_id": actor_id,
		"source_kind": "saved_task_state",
		"source_id": "regroup_task_fixture",
		"task_class": "rebuild_host",
		"task_status": status,
		"target_kind": "regroup",
		"target_id": target_id,
		"front_id": "regroup:%s" % target_id,
		"origin_kind": "encounter",
		"origin_id": "regroup_task_fixture",
		"priority_reason_codes": ["regroup_understrength", "army_consolidation", "regroup_task_fixture"],
		"assigned_day": 2,
		"expires_day": 9,
		"continuity_policy": "persist_until_invalid",
		"route_policy": "derive_route_on_turn",
		"last_validation": validation,
		"reservation": {
			"reservation_status": "none",
			"reservation_scope": "none",
			"reservation_key": "",
		},
	}

func _resource_task(actor_id: String, target_id: String, status: String, validation: String) -> Dictionary:
	return {
		"task_id": "task:resource:%s:%s" % [actor_id, target_id],
		"owner_faction_id": MIRECLAW,
		"actor_kind": "commander_roster",
		"actor_id": actor_id,
		"source_kind": "saved_task_state",
		"source_id": "guarded_resource_claim_fixture",
		"task_class": "contest_site",
		"task_status": status,
		"target_kind": "resource",
		"target_id": target_id,
		"front_id": "resource:%s" % target_id,
		"origin_kind": "resource",
		"origin_id": "guarded_resource_claim_fixture",
		"priority_reason_codes": ["persistent_income_denial", "recruit_denial", "guarded_resource_claim_fixture"],
		"assigned_day": 2,
		"expires_day": 9,
		"continuity_policy": "persist_until_invalid",
		"route_policy": "derive_route_on_turn",
		"last_validation": validation,
		"reservation": {
			"reservation_status": "primary",
			"reservation_scope": "exclusive_target",
			"reservation_key": "resource:%s" % target_id,
		},
	}

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

func _set_resource_position(session, placement_id: String, tile: Vector2i) -> void:
	var nodes: Array = session.overworld.get("resource_nodes", [])
	for index in range(nodes.size()):
		var node = nodes[index]
		if not (node is Dictionary):
			continue
		if String(node.get("placement_id", "")) != placement_id:
			continue
		node["x"] = tile.x
		node["y"] = tile.y
		nodes[index] = node
		session.overworld["resource_nodes"] = nodes
		return
	_fail("Could not move resource placement %s" % placement_id)

func _block_cardinal_neighbors(session, center: Vector2i) -> void:
	var map_rows: Array = session.overworld.get("map", [])
	for delta in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var tile: Vector2i = center + delta
		if tile.y < 0 or tile.y >= map_rows.size():
			continue
		var row: Array = map_rows[tile.y] if map_rows[tile.y] is Array else []
		if tile.x < 0 or tile.x >= row.size():
			continue
		row[tile.x] = "water"
		map_rows[tile.y] = row
	session.overworld["map"] = map_rows

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

func _town_garrison_count(session, placement_id: String, unit_id: String) -> int:
	for town in session.overworld.get("towns", []):
		if not (town is Dictionary) or String(town.get("placement_id", "")) != placement_id:
			continue
		for stack in town.get("garrison", []):
			if stack is Dictionary and String(stack.get("unit_id", "")) == unit_id:
				return int(stack.get("count", 0))
	return 0

func _set_town_garrison(session, placement_id: String, garrison: Array) -> void:
	var towns: Array = session.overworld.get("towns", [])
	for index in range(towns.size()):
		var town = towns[index]
		if not (town is Dictionary) or String(town.get("placement_id", "")) != placement_id:
			continue
		town["garrison"] = garrison.duplicate(true)
		towns[index] = town
		session.overworld["towns"] = towns
		return
	_fail("Could not set garrison for town %s" % placement_id)

func _append_enemy_town(session, town: Dictionary) -> void:
	var towns: Array = session.overworld.get("towns", [])
	towns.append(town.duplicate(true))
	session.overworld["towns"] = towns

func _resolved_contains(session, placement_id: String) -> bool:
	var resolved = session.overworld.get("resolved_encounters", [])
	return resolved is Array and placement_id in resolved

func _commander_entry(session, roster_hero_id: String) -> Dictionary:
	for entry in EnemyAdventureRules.commander_roster_for_faction(session, MIRECLAW):
		if entry is Dictionary and String(entry.get("roster_hero_id", "")) == roster_hero_id:
			return entry
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

func _event_reason_codes(events: Variant, event_type_filter: String) -> Array:
	if not (events is Array):
		return []
	for event in events:
		if not (event is Dictionary):
			continue
		if String(event.get("event_type", "")) != event_type_filter:
			continue
		return _string_array(event.get("reason_codes", event.get("target_reason_codes", [])))
	return []

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
