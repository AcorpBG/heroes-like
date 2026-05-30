extends Node

const REPORT_ID := "AI_RAID_REGROUP_RETREAT_REPORT"
const RIVER_PASS := "river-pass"
const MIRECLAW := "faction_mireclaw"

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
	var unreachable_route_case := _valid_but_unreachable_target_reroutes_to_regroup()
	if unreachable_route_case.is_empty():
		return
	var garrison_routing_case := _regroup_prefers_useful_garrison_town()
	if garrison_routing_case.is_empty():
		return
	var failed_regroup_case := _empty_garrison_regroup_releases_to_rebuild()
	if failed_regroup_case.is_empty():
		return
	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"schema_status": "live_regroup_behavior_no_save_migration",
		"behavior_policy": "understrength_raids_retreat_guarded_claims_retarget_and_unreachable_routes_recover_and_failed_regroups_rebuild",
		"case": case_report,
		"guarded_claim_case": guarded_claim_case,
		"unreachable_route_case": unreachable_route_case,
		"garrison_routing_case": garrison_routing_case,
		"failed_regroup_case": failed_regroup_case,
		"save_version_before": int(SessionStateStore.SAVE_VERSION),
		"save_version_after": int(SessionStateStore.SAVE_VERSION),
	}
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

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
	if String(after_raid.get("target_kind", "")) != "":
		_fail("Regrouped raid should clear its target after reaching a usable host strength: %s" % JSON.stringify(after_raid))
		return {}
	if resource_controller == MIRECLAW:
		_fail("Understrength raid captured the original offensive resource instead of regrouping.")
		return {}
	_assert_task_status(session, "hero_vaska", "regroup", "duskfen_bastion", "completed", "valid")
	if _failed:
		return {}
	EnemyTurnRules.normalize_enemy_states(session)
	_assert_task_status(session, "hero_vaska", "regroup", "duskfen_bastion", "completed", "valid")
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
	var recovered_to_regroup := (
		(String(after_raid.get("target_kind", "")) == "regroup" and String(after_raid.get("target_placement_id", "")) == "duskfen_bastion")
		or (String(after_raid.get("target_kind", "")) == "" and String(after_raid.get("last_regroup_town_id", "")) == "duskfen_bastion")
	)
	if not recovered_to_regroup:
		_fail("Unreachable-route raid did not recover through reachable regroup town: %s" % JSON.stringify(after_raid))
		return {}
	if String(after_raid.get("previous_target_kind", "")) != "resource" or String(after_raid.get("previous_target_placement_id", "")) != "river_free_company":
		_fail("Unreachable-route retask did not preserve previous target metadata: %s" % JSON.stringify(after_raid))
		return {}
	var reason_codes := _string_array(after_raid.get("target_reason_codes", []))
	if reason_codes.is_empty():
		reason_codes = _event_reason_codes(result.get("events", []), "ai_target_assigned")
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

func _empty_garrison_regroup_releases_to_rebuild() -> Dictionary:
	var session = _base_session()
	session.day = 2
	var config := _enemy_config()
	var state := _enemy_state(session)
	_set_resource_controller(session, "river_free_company", "player")
	_set_town_garrison(session, "duskfen_bastion", [])
	var raid := _understrength_raid(session, config)
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
	if not bool(after_raid.get("raid_retired_to_rebuild", false)):
		_fail("Failed-regroup raid did not retire into rebuild: %s" % JSON.stringify(after_raid))
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
		"task_status_counts": _task_status_counts(_task_state(session)),
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
