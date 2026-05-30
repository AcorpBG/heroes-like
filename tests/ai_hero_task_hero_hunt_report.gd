extends Node

const REPORT_ID := "AI_HERO_TASK_HERO_HUNT_REPORT"
const RIVER_PASS := "river-pass"
const MIRECLAW := "faction_mireclaw"
const MISSING_HERO_ID := "missing_player_hero"

var _failed := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var case_report := _hero_hunt_task_board_case()
	if case_report.is_empty():
		return
	var opportunity_case_report := _active_raid_opportunistically_intercepts_nearby_exposed_hero_case()
	if opportunity_case_report.is_empty():
		return
	var threat_avoidance_case_report := _active_raid_avoids_superior_nearby_player_hero_case()
	if threat_avoidance_case_report.is_empty():
		return
	var risk_case_report := _weak_hero_hunt_regroups_before_intercept_case()
	if risk_case_report.is_empty():
		return
	var arbitration_case_report := _hero_intercept_arbitration_prefers_ready_high_value_hunt()
	if arbitration_case_report.is_empty():
		return
	var support_case_report := _hero_hunt_support_groups_before_intercept_case()
	if support_case_report.is_empty():
		return
	var stall_case_report := _stale_unsupported_hero_hunt_retires_to_rebuild_case()
	if stall_case_report.is_empty():
		return
	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"schema_status": "hero_hunt_tasks_are_durable_with_support_grouping_stall_withdrawal_and_battle_outcomes",
		"behavior_policy": "hero_targets_use_saved_task_continuity_with_intercept_risk_gating_support_grouping_stall_withdrawal_and_battle_outcome_lifecycle",
		"behavior_policy_nearby_threat": "active_nondefensive_raids_avoid_superior_nearby_player_heroes_by_regrouping",
		"behavior_policy_previous": "hero_targets_use_saved_task_continuity_with_intercept_risk_gating_and_support_grouping",
		"behavior_policy_previous_stall": "hero_targets_use_saved_task_continuity_with_intercept_risk_gating_support_grouping_and_stall_withdrawal",
		"save_policy": "hero_task_state_live_persist_no_save_migration",
		"case": case_report,
		"opportunity_case": opportunity_case_report,
		"threat_avoidance_case": threat_avoidance_case_report,
		"risk_case": risk_case_report,
		"arbitration_case": arbitration_case_report,
		"support_case": support_case_report,
		"stall_case": stall_case_report,
		"save_version_before": int(SessionStateStore.SAVE_VERSION),
		"save_version_after": int(SessionStateStore.SAVE_VERSION),
	}
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _active_raid_opportunistically_intercepts_nearby_exposed_hero_case() -> Dictionary:
	var session = _base_session()
	session.day = 3
	var config := _enemy_config()
	var hero_id := String(session.overworld.get("active_hero_id", ""))
	if hero_id == "":
		_fail("River Pass has no active hero id for opportunity intercept fixture.")
		return {}
	var hero_tile := _nearest_open_non_town_tile(session, Vector2i(8, 4))
	var raid_tile := _nearby_open_non_town_tile_at_distance(session, hero_tile, 2, 4)
	_move_player_hero(session, hero_id, hero_tile)
	_clear_mireclaw_resource_claims(session)
	var player_town := _first_player_town(session)
	if player_town.is_empty():
		_fail("Opportunity intercept fixture needs a valid player town target.")
		return {}
	_remove_mireclaw_active_raids(session)
	var raid := _raid_seed(session, "hero_vaska", "opportunity_intercept_vaska", raid_tile)
	raid["target_kind"] = "town"
	raid["target_placement_id"] = String(player_town.get("placement_id", ""))
	raid["target_label"] = String(player_town.get("name", player_town.get("placement_id", "")))
	raid["target_x"] = int(player_town.get("x", 0))
	raid["target_y"] = int(player_town.get("y", 0))
	raid["goal_x"] = int(player_town.get("x", 0))
	raid["goal_y"] = int(player_town.get("y", 0))
	raid["goal_distance"] = 9999
	raid["target_reason_codes"] = ["town_siege", "pressure_probe"]
	raid["target_public_reason"] = "town pressure"
	raid["target_public_importance"] = "high"
	raid["target_debug_reason"] = "valid non-hero target for opportunity intercept fixture"
	raid = _set_raid_bog_brutes(raid, 40)
	_append_encounter(session, raid)

	var state := {}
	var advance_result := EnemyAdventureRules.advance_raids(session, config, MIRECLAW, state)
	var after_raid := _encounter(session, "opportunity_intercept_vaska")
	if after_raid.is_empty():
		_fail("Opportunity intercept raid disappeared after advance.")
		return {}
	if String(after_raid.get("target_kind", "")) != "hero" or String(after_raid.get("target_placement_id", "")) != hero_id:
		_fail("Active raid did not opportunistically retarget the nearby exposed hero: %s" % JSON.stringify(after_raid))
		return {}
	var reason_codes := _string_array(after_raid.get("target_reason_codes", []))
	for required_code in ["hero_hunt", "exposed_hero", "opportunity_intercept"]:
		if required_code not in reason_codes:
			_fail("Opportunity intercept missing %s: %s" % [required_code, JSON.stringify(after_raid)])
			return {}
	if String(after_raid.get("previous_target_kind", "")) != "town":
		_fail("Opportunity intercept did not preserve previous target metadata: %s" % JSON.stringify(after_raid))
		return {}
	var events: Array = advance_result.get("events", []) if advance_result.get("events", []) is Array else []
	var event_types := _event_types(events)
	if "ai_target_assigned" not in event_types:
		_fail("Opportunity intercept did not emit ai_target_assigned: %s" % JSON.stringify(advance_result))
		return {}
	_assert_task_status(session, "hero_vaska", "hero", hero_id, "active", "valid")
	if _failed:
		return {}
	return {
		"case_id": "active_raid_opportunistically_intercepts_nearby_exposed_hero",
		"target_kind": String(after_raid.get("target_kind", "")),
		"target_id": String(after_raid.get("target_placement_id", "")),
		"previous_target_kind": String(after_raid.get("previous_target_kind", "")),
		"distance_after_advance": int(after_raid.get("goal_distance", 9999)),
		"reason_codes": reason_codes,
		"event_types": event_types,
		"save_version": int(SessionStateStore.SAVE_VERSION),
	}

func _active_raid_avoids_superior_nearby_player_hero_case() -> Dictionary:
	var session = _base_session()
	session.day = 3
	var config := _enemy_config()
	var hero_id := String(session.overworld.get("active_hero_id", ""))
	if hero_id == "":
		_fail("River Pass has no active hero id for nearby threat avoidance fixture.")
		return {}
	var hero_tile := _nearest_open_non_town_tile(session, Vector2i(8, 4))
	var raid_tile := _nearby_open_non_town_tile_at_distance(session, hero_tile, 2, 4)
	_move_player_hero(session, hero_id, hero_tile)
	_set_player_hero_army(session, hero_id, [{"unit_id": "unit_ember_squire", "count": 90}])
	_clear_mireclaw_resource_claims(session)
	var player_town := _first_player_town(session)
	if player_town.is_empty():
		_fail("Nearby threat avoidance fixture needs a valid player town target.")
		return {}
	_remove_mireclaw_active_raids(session)
	var raid := _raid_seed(session, "hero_vaska", "nearby_threat_avoidance_vaska", raid_tile)
	raid["target_kind"] = "town"
	raid["target_placement_id"] = String(player_town.get("placement_id", ""))
	raid["target_label"] = String(player_town.get("name", player_town.get("placement_id", "")))
	raid["target_x"] = int(player_town.get("x", 0))
	raid["target_y"] = int(player_town.get("y", 0))
	raid["goal_x"] = int(player_town.get("x", 0))
	raid["goal_y"] = int(player_town.get("y", 0))
	raid["goal_distance"] = 9999
	raid["target_reason_codes"] = ["town_siege", "pressure_probe"]
	raid["target_public_reason"] = "town pressure"
	raid["target_public_importance"] = "high"
	raid["target_debug_reason"] = "valid non-hero target for nearby threat avoidance fixture"
	raid = _set_raid_bog_brutes(raid, 10)
	if EnemyAdventureRules.raid_regroup_needed(raid):
		_fail("Nearby threat avoidance fixture should not use the generic understrength regroup path: %s" % JSON.stringify(raid))
		return {}
	_append_encounter(session, raid)

	var state := {}
	var advance_result := EnemyAdventureRules.advance_raids(session, config, MIRECLAW, state)
	var after_raid := _encounter(session, "nearby_threat_avoidance_vaska")
	if after_raid.is_empty():
		_fail("Nearby threat avoidance raid disappeared after advance.")
		return {}
	if String(after_raid.get("target_kind", "")) != "regroup":
		_fail("Active raid did not avoid superior nearby player hero: %s" % JSON.stringify(after_raid))
		return {}
	if String(after_raid.get("previous_target_kind", "")) != "town" or String(after_raid.get("previous_target_placement_id", "")) != String(player_town.get("placement_id", "")):
		_fail("Nearby threat avoidance did not preserve previous town target metadata: %s" % JSON.stringify(after_raid))
		return {}
	var reason_codes := _string_array(after_raid.get("target_reason_codes", []))
	for required_code in ["player_threat_avoidance", "hero_threat", "army_consolidation"]:
		if required_code not in reason_codes:
			_fail("Nearby threat avoidance missing %s: %s" % [required_code, JSON.stringify(after_raid)])
			return {}
	if String(after_raid.get("player_threat_hero_id", "")) != hero_id:
		_fail("Nearby threat avoidance did not record threatening hero id: %s" % JSON.stringify(after_raid))
		return {}
	var events: Array = advance_result.get("events", []) if advance_result.get("events", []) is Array else []
	var event_types := _event_types(events)
	if "ai_target_assigned" not in event_types:
		_fail("Nearby threat avoidance did not emit ai_target_assigned: %s" % JSON.stringify(advance_result))
		return {}
	_assert_task_status(session, "hero_vaska", "regroup", String(after_raid.get("target_placement_id", "")), "active", "valid")
	if _failed:
		return {}
	return {
		"case_id": "active_raid_avoids_superior_nearby_player_hero",
		"target_kind": String(after_raid.get("target_kind", "")),
		"target_id": String(after_raid.get("target_placement_id", "")),
		"previous_target_kind": String(after_raid.get("previous_target_kind", "")),
		"previous_target_id": String(after_raid.get("previous_target_placement_id", "")),
		"threat_hero_id": String(after_raid.get("player_threat_hero_id", "")),
		"threat_distance": int(after_raid.get("player_threat_distance", 9999)),
		"threat_strength": int(after_raid.get("player_threat_hero_strength", 0)),
		"raid_strength": EnemyAdventureRules.raid_strength(after_raid),
		"reason_codes": reason_codes,
		"event_types": event_types,
		"save_version": int(SessionStateStore.SAVE_VERSION),
	}

func _hero_hunt_task_board_case() -> Dictionary:
	var session = _base_session()
	session.day = 2
	var config := _enemy_config()
	var hero_id := String(session.overworld.get("active_hero_id", ""))
	if hero_id == "":
		_fail("River Pass has no active hero id.")
		return {}
	var first_tile := _nearest_open_non_town_tile(session, Vector2i(8, 4))
	var second_tile := _nearest_open_non_town_tile_excluding(session, Vector2i(first_tile.x + 1, first_tile.y), first_tile)
	_move_player_hero(session, hero_id, first_tile)
	_seed_task_board(session, [_task("hero_tarn", MISSING_HERO_ID, "active", "valid")])

	var raid := _raid_seed(session, "hero_vaska", "hero_hunt_task_vaska", first_tile)
	raid["target_kind"] = "hero"
	raid["target_placement_id"] = hero_id
	raid["target_label"] = _hero_name(session, hero_id)
	raid["target_x"] = first_tile.x
	raid["target_y"] = first_tile.y
	raid["goal_x"] = first_tile.x
	raid["goal_y"] = first_tile.y
	raid["target_reason_codes"] = ["hero_hunt", "exposed_hero", "hero_hunt_task_fixture"]
	raid["target_public_reason"] = "exposed hero"
	raid["target_public_importance"] = "high"
	raid["target_debug_reason"] = "hero hunt task-board fixture"

	var assigned_raid := EnemyAdventureRules.assign_target(session, config, raid)
	if String(assigned_raid.get("target_kind", "")) != "hero" or String(assigned_raid.get("target_placement_id", "")) != hero_id:
		_fail("Hero hunt assignment did not keep the target: %s" % JSON.stringify(assigned_raid))
		return {}
	_assert_task_status(session, "hero_vaska", "hero", hero_id, "active", "valid")
	if _failed:
		return {}

	EnemyTurnRules.normalize_enemy_states(session)
	_assert_task_status(session, "hero_vaska", "hero", hero_id, "active", "valid")
	if _failed:
		return {}

	_move_player_hero(session, hero_id, second_tile)
	var saved_plan_raid := _raid_seed(session, "hero_vaska", "hero_hunt_reuse_vaska", second_tile)
	var saved_plan := EnemyAdventureRules.ai_hero_task_saved_target_selection_plan(session, config, saved_plan_raid)
	if String(saved_plan.get("target_kind", "")) != "hero" or String(saved_plan.get("target_placement_id", "")) != hero_id:
		_fail("Saved hero hunt task was not reused: %s" % JSON.stringify(saved_plan))
		return {}
	if int(saved_plan.get("target_x", -1)) != second_tile.x or int(saved_plan.get("target_y", -1)) != second_tile.y:
		_fail("Saved hero hunt plan did not follow moved hero: %s expected %s" % [JSON.stringify(saved_plan), str(second_tile)])
		return {}
	var reason_codes := _string_array(saved_plan.get("target_reason_codes", []))
	if "saved_hero_task" not in reason_codes:
		_fail("Saved hero hunt plan is missing saved_hero_task reason: %s" % JSON.stringify(saved_plan))
		return {}
	_assert_task_status(session, "hero_tarn", "hero", MISSING_HERO_ID, "invalid", "invalid_target_missing")
	if _failed:
		return {}

	assigned_raid["x"] = second_tile.x
	assigned_raid["y"] = second_tile.y
	assigned_raid["target_x"] = second_tile.x
	assigned_raid["target_y"] = second_tile.y
	assigned_raid["goal_x"] = second_tile.x
	assigned_raid["goal_y"] = second_tile.y
	assigned_raid["goal_distance"] = 0
	assigned_raid["arrived"] = true
	assigned_raid = _set_raid_bog_brutes(assigned_raid, 12)
	_remove_mireclaw_hero_hunt_encounters(session)
	_append_encounter(session, assigned_raid)
	var intercept_result := EnemyTurnRules._queue_hero_intercept_battle(session, config, MIRECLAW)
	if not bool(intercept_result.get("battle_started", false)):
		_fail("Hero hunt intercept did not queue battle: %s" % JSON.stringify(intercept_result))
		return {}
	var battle_context: Dictionary = session.battle.get("context", {}) if session.battle.get("context", {}) is Dictionary else {}
	if String(battle_context.get("type", "")) != "hero_intercept" or String(battle_context.get("target_hero_id", "")) != hero_id:
		_fail("Hero hunt queued wrong battle context: %s" % JSON.stringify(battle_context))
		return {}
	_assert_task_status(session, "hero_vaska", "hero", hero_id, "active", "valid")
	if _failed:
		return {}
	_defeat_battle_side(session, "enemy")
	var outcome := BattleRules.resolve_if_battle_ready(session)
	if String(outcome.get("state", "")) != "victory":
		_fail("Hero hunt battle defeat fixture did not resolve as player victory: %s" % JSON.stringify(outcome))
		return {}
	_assert_task_status(session, "hero_vaska", "hero", hero_id, "failed", "invalid_battle_defeat")
	if _failed:
		return {}

	var final_task_state := _task_state(session)
	return {
		"case_id": "hero_hunt_assigns_reuses_follows_and_resolves_task_from_battle_outcome",
		"target_kind": String(saved_plan.get("target_kind", "")),
		"target_id": String(saved_plan.get("target_placement_id", "")),
		"reason_codes": reason_codes,
		"first_target": {"x": first_tile.x, "y": first_tile.y},
		"moved_target": {"x": second_tile.x, "y": second_tile.y},
		"battle_context_type": String(battle_context.get("type", "")),
		"battle_outcome": String(outcome.get("state", "")),
		"task_status_counts": _task_status_counts(final_task_state),
		"save_version": int(SessionStateStore.SAVE_VERSION),
	}

func _weak_hero_hunt_regroups_before_intercept_case() -> Dictionary:
	var session = _base_session()
	session.day = 2
	var config := _enemy_config()
	var hero_id := String(session.overworld.get("active_hero_id", ""))
	if hero_id == "":
		_fail("River Pass has no active hero id for weak intercept fixture.")
		return {}
	var target_tile := _nearest_open_non_town_tile(session, Vector2i(8, 4))
	_move_player_hero(session, hero_id, target_tile)
	var raid := _raid_seed(session, "hero_vaska", "weak_hero_hunt_vaska", target_tile)
	raid["target_kind"] = "hero"
	raid["target_placement_id"] = hero_id
	raid["target_label"] = _hero_name(session, hero_id)
	raid["target_x"] = target_tile.x
	raid["target_y"] = target_tile.y
	raid["goal_x"] = target_tile.x
	raid["goal_y"] = target_tile.y
	raid["goal_distance"] = 0
	raid["arrived"] = true
	raid["target_reason_codes"] = ["hero_hunt", "exposed_hero", "hero_hunt_task_fixture"]
	raid["target_public_reason"] = "exposed hero"
	raid["target_public_importance"] = "high"
	raid["target_debug_reason"] = "weak hero hunt risk fixture"
	raid = _set_raid_bog_brutes(raid, 4)
	_remove_mireclaw_hero_hunt_encounters(session)
	_append_encounter(session, raid)

	var intercept_result := EnemyTurnRules._queue_hero_intercept_battle(session, config, MIRECLAW)
	if bool(intercept_result.get("battle_started", false)) or not session.battle.is_empty():
		_fail("Weak hero hunt incorrectly queued battle: %s" % JSON.stringify(intercept_result))
		return {}
	if not bool(intercept_result.get("risk_gated", false)):
		_fail("Weak hero hunt did not report risk gating: %s" % JSON.stringify(intercept_result))
		return {}
	var after_raid := _encounter(session, "weak_hero_hunt_vaska")
	if after_raid.is_empty():
		_fail("Weak hero hunt raid disappeared after risk gating.")
		return {}
	var reason_codes := _string_array(after_raid.get("target_reason_codes", []))
	if "hero_hunt_risk_regroup" not in reason_codes and "hero_hunt_risk_shadow" not in reason_codes:
		_fail("Weak hero hunt did not record a hero-risk reason: %s" % JSON.stringify(after_raid))
		return {}
	if String(after_raid.get("target_public_reason", "")) != "stalking stronger hero":
		_fail("Weak hero hunt public reason was not stalking stronger hero: %s" % JSON.stringify(after_raid))
		return {}
	if int(after_raid.get("hero_intercept_delay_until_day", 0)) <= int(session.day):
		_fail("Weak hero hunt did not set a future intercept delay: %s" % JSON.stringify(after_raid))
		return {}
	var events: Array = intercept_result.get("events", []) if intercept_result.get("events", []) is Array else []
	var event_types := _event_types(events)
	if "ai_target_assigned" not in event_types:
		_fail("Weak hero hunt risk gating did not emit ai_target_assigned: %s" % JSON.stringify(intercept_result))
		return {}
	var public_log := EnemyAdventureRules.ai_public_event_log_boundary_report(events, 8)
	if not bool(public_log.get("ok", false)):
		_fail("Weak hero hunt public event boundary failed: %s" % JSON.stringify(public_log))
		return {}
	if _public_event_leaks(public_log.get("public_events", [])):
		return {}
	if _failed:
		return {}
	return {
		"case_id": "weak_hero_hunt_regroups_before_intercept",
		"target_kind": String(after_raid.get("target_kind", "")),
		"target_id": String(after_raid.get("target_placement_id", "")),
		"battle_started": false,
		"hero_intercept_delay_until_day": int(after_raid.get("hero_intercept_delay_until_day", 0)),
		"target_public_reason": String(after_raid.get("target_public_reason", "")),
		"reason_codes": reason_codes,
		"event_types": event_types,
		"public_event_count": int(public_log.get("public_event_count", 0)),
		"save_version": int(SessionStateStore.SAVE_VERSION),
	}

func _hero_intercept_arbitration_prefers_ready_high_value_hunt() -> Dictionary:
	var session = _base_session()
	session.day = 3
	var config := _enemy_config()
	var hero_id := String(session.overworld.get("active_hero_id", ""))
	if hero_id == "":
		_fail("River Pass has no active hero id for arbitration fixture.")
		return {}
	var high_value_tile := _nearest_open_non_town_tile(session, Vector2i(8, 4))
	var decoy_tile := _nearest_open_non_town_tile_excluding(session, Vector2i(high_value_tile.x + 1, high_value_tile.y), high_value_tile)
	_move_player_hero(session, hero_id, high_value_tile)
	_add_player_hero_decoy(session, "hero_decoy_arbitration", "Decoy Captain", decoy_tile)
	_remove_mireclaw_hero_hunt_encounters(session)

	var weak_near := _raid_seed(session, "hero_vaska", "near_weak_decoy_vaska", decoy_tile)
	weak_near["target_kind"] = "hero"
	weak_near["target_placement_id"] = "hero_decoy_arbitration"
	weak_near["target_label"] = "Decoy Captain"
	weak_near["target_x"] = decoy_tile.x
	weak_near["target_y"] = decoy_tile.y
	weak_near["goal_x"] = decoy_tile.x
	weak_near["goal_y"] = decoy_tile.y
	weak_near["goal_distance"] = 0
	weak_near["arrived"] = true
	weak_near["target_reason_codes"] = ["hero_hunt", "near_decoy_probe"]
	weak_near["target_public_reason"] = "exposed hero"
	weak_near = _set_raid_bog_brutes(weak_near, 1)

	var ready_hunt := _raid_seed(session, "hero_sable", "ready_high_value_hero_sable", high_value_tile)
	ready_hunt["target_kind"] = "hero"
	ready_hunt["target_placement_id"] = hero_id
	ready_hunt["target_label"] = _hero_name(session, hero_id)
	ready_hunt["target_x"] = high_value_tile.x
	ready_hunt["target_y"] = high_value_tile.y
	ready_hunt["goal_x"] = high_value_tile.x
	ready_hunt["goal_y"] = high_value_tile.y
	ready_hunt["goal_distance"] = 1
	ready_hunt["arrived"] = true
	ready_hunt["target_reason_codes"] = ["hero_hunt", "exposed_hero", "high_value_commander"]
	ready_hunt["target_public_reason"] = "exposed hero"
	ready_hunt = _set_raid_bog_brutes(ready_hunt, 14)

	_append_encounter(session, weak_near)
	_append_encounter(session, ready_hunt)
	var intercept_result := EnemyTurnRules._queue_hero_intercept_battle(session, config, MIRECLAW)
	if not bool(intercept_result.get("battle_started", false)):
		_fail("Hero intercept arbitration should have queued the ready high-value hunt: %s" % JSON.stringify(intercept_result))
		return {}
	var battle_context: Dictionary = session.battle.get("context", {}) if session.battle.get("context", {}) is Dictionary else {}
	if String(battle_context.get("target_hero_id", "")) != hero_id:
		_fail("Hero intercept arbitration chose wrong hero: %s" % JSON.stringify(battle_context))
		return {}
	if String(session.battle.get("resolved_key", "")) != "ready_high_value_hero_sable":
		_fail("Hero intercept arbitration chose wrong raid: %s" % JSON.stringify(session.battle))
		return {}
	return {
		"case_id": "hero_intercept_arbitration_prefers_ready_high_value_hunt",
		"selected_raid_id": String(session.battle.get("resolved_key", "")),
		"selected_hero_id": String(battle_context.get("target_hero_id", "")),
		"near_decoy_id": "near_weak_decoy_vaska",
		"battle_started": true,
		"save_version": int(SessionStateStore.SAVE_VERSION),
	}

func _hero_hunt_support_groups_before_intercept_case() -> Dictionary:
	var session = _base_session()
	session.day = 2
	var config := _enemy_config()
	var hero_id := String(session.overworld.get("active_hero_id", ""))
	if hero_id == "":
		_fail("River Pass has no active hero id for support fixture.")
		return {}
	var target_tile := _nearest_open_non_town_tile(session, Vector2i(8, 4))
	var support_tile := _nearest_open_non_town_tile_excluding(session, Vector2i(target_tile.x + 1, target_tile.y), target_tile)
	_move_player_hero(session, hero_id, target_tile)
	_remove_mireclaw_hero_hunt_encounters(session)

	var leader := _raid_seed(session, "hero_vaska", "hero_hunt_support_leader_vaska", target_tile)
	leader["target_kind"] = "hero"
	leader["target_placement_id"] = hero_id
	leader["target_label"] = _hero_name(session, hero_id)
	leader["target_x"] = target_tile.x
	leader["target_y"] = target_tile.y
	leader["goal_x"] = target_tile.x
	leader["goal_y"] = target_tile.y
	leader["goal_distance"] = 0
	leader["arrived"] = true
	leader["target_reason_codes"] = ["hero_hunt", "exposed_hero", "awaiting_support", "hero_hunt_task_fixture"]
	leader["target_public_reason"] = "exposed hero"
	leader["target_public_importance"] = "high"
	leader["target_debug_reason"] = "hero hunt support grouping fixture"
	leader = _set_raid_bog_brutes(leader, 8)
	var leader_strength_before := EnemyAdventureRules.raid_strength(leader)
	_append_encounter(session, leader)

	var support := _raid_seed(session, "hero_sable", "hero_hunt_support_sable", support_tile)
	support = _set_raid_bog_brutes(support, 5)
	var assigned_support := EnemyAdventureRules.assign_target(session, config, support)
	if String(assigned_support.get("target_kind", "")) != "hero" or String(assigned_support.get("target_placement_id", "")) != hero_id:
		_fail("Hero hunt support did not select the exposed hero front: %s" % JSON.stringify(assigned_support))
		return {}
	var support_reason_codes := _string_array(assigned_support.get("target_reason_codes", []))
	for required_code in ["active_front_support", "army_consolidation", "hero_hunt", "exposed_hero"]:
		if required_code not in support_reason_codes:
			_fail("Hero hunt support assignment missing %s: %s" % [required_code, JSON.stringify(assigned_support)])
			return {}
	if String(assigned_support.get("supporting_front_placement_id", "")) != "hero_hunt_support_leader_vaska":
		_fail("Hero hunt support did not bind to the leader front: %s" % JSON.stringify(assigned_support))
		return {}
	_append_encounter(session, assigned_support)

	var state := {}
	var advance_result := EnemyAdventureRules.advance_raids(session, config, MIRECLAW, state)
	var after_leader := _encounter(session, "hero_hunt_support_leader_vaska")
	if after_leader.is_empty():
		_fail("Hero hunt support leader disappeared after advance.")
		return {}
	var resolved: Array = session.overworld.get("resolved_encounters", []) if session.overworld.get("resolved_encounters", []) is Array else []
	if "hero_hunt_support_sable" not in resolved:
		_fail("Hero hunt support donor was not resolved after grouping: %s" % JSON.stringify(resolved))
		return {}
	var leader_reason_codes := _string_array(after_leader.get("target_reason_codes", []))
	for required_code in ["army_consolidation", "hero_hunt", "exposed_hero"]:
		if required_code not in leader_reason_codes:
			_fail("Grouped hero hunt leader missing %s: %s" % [required_code, JSON.stringify(after_leader)])
			return {}
	var leader_strength_after := EnemyAdventureRules.raid_strength(after_leader)
	if leader_strength_after <= leader_strength_before:
		_fail("Hero hunt grouping did not increase leader strength: before %d after %d" % [leader_strength_before, leader_strength_after])
		return {}
	if int(after_leader.get("grouped_commander_support_count", 0)) < 1:
		_fail("Hero hunt grouping did not count commander support: %s" % JSON.stringify(after_leader))
		return {}
	var events: Array = advance_result.get("events", []) if advance_result.get("events", []) is Array else []
	var event_types := _event_types(events)
	if "ai_raid_grouped" not in event_types:
		_fail("Hero hunt support grouping did not emit ai_raid_grouped: %s" % JSON.stringify(advance_result))
		return {}
	_assert_task_status(session, "hero_sable", "hero", hero_id, "completed", "valid")
	if _failed:
		return {}
	return {
		"case_id": "hero_hunt_support_groups_before_intercept",
		"target_kind": String(after_leader.get("target_kind", "")),
		"target_id": String(after_leader.get("target_placement_id", "")),
		"supporting_front_placement_id": String(assigned_support.get("supporting_front_placement_id", "")),
		"support_reason_codes": support_reason_codes,
		"leader_reason_codes": leader_reason_codes,
		"leader_strength_before": leader_strength_before,
		"leader_strength_after": leader_strength_after,
		"grouped_commander_support_count": int(after_leader.get("grouped_commander_support_count", 0)),
		"resolved_support": "hero_hunt_support_sable" in resolved,
		"event_types": event_types,
		"save_version": int(SessionStateStore.SAVE_VERSION),
	}

func _stale_unsupported_hero_hunt_retires_to_rebuild_case() -> Dictionary:
	var session = _base_session()
	session.day = 6
	var config := _enemy_config()
	var hero_id := String(session.overworld.get("active_hero_id", ""))
	if hero_id == "":
		_fail("River Pass has no active hero id for stale hero-hunt fixture.")
		return {}
	var target_tile := _nearest_open_non_town_tile(session, Vector2i(8, 4))
	_move_player_hero(session, hero_id, target_tile)
	_remove_mireclaw_hero_hunt_encounters(session)
	_remove_enemy_regroup_towns(session)
	_seed_task_board(session, [_task("hero_vaska", hero_id, "active", "valid")])

	var raid := _raid_seed(session, "hero_vaska", "stale_hero_hunt_vaska", target_tile)
	raid["target_kind"] = "hero"
	raid["target_placement_id"] = hero_id
	raid["target_label"] = _hero_name(session, hero_id)
	raid["target_x"] = target_tile.x
	raid["target_y"] = target_tile.y
	raid["goal_x"] = target_tile.x
	raid["goal_y"] = target_tile.y
	raid["goal_distance"] = 0
	raid["arrived"] = true
	raid["hero_intercept_risk_started_day"] = 2
	raid["hero_intercept_delay_until_day"] = int(session.day)
	raid["target_reason_codes"] = ["hero_hunt", "hero_hunt_risk_shadow", "awaiting_support", "hero_hunt_task_fixture"]
	raid["target_public_reason"] = "stalking stronger hero"
	raid["target_public_importance"] = "high"
	raid["target_debug_reason"] = "stale unsupported hero hunt fixture"
	raid = _set_raid_bog_brutes(raid, 2)
	var before_strength := EnemyAdventureRules.raid_strength(raid)
	_append_encounter(session, raid)

	var intercept_result := EnemyTurnRules._queue_hero_intercept_battle(session, config, MIRECLAW)
	if bool(intercept_result.get("battle_started", false)) or not session.battle.is_empty():
		_fail("Stale unsupported hero hunt incorrectly queued battle: %s" % JSON.stringify(intercept_result))
		return {}
	if not bool(intercept_result.get("risk_gated", false)):
		_fail("Stale unsupported hero hunt did not pass through risk gate: %s" % JSON.stringify(intercept_result))
		return {}
	var after_raid := _encounter(session, "stale_hero_hunt_vaska")
	if after_raid.is_empty():
		_fail("Stale unsupported hero hunt raid disappeared from history.")
		return {}
	if not bool(after_raid.get("raid_retired_to_rebuild", false)) or not bool(after_raid.get("risk_stalled_to_rebuild", false)):
		_fail("Stale unsupported hero hunt did not retire into rebuild: %s" % JSON.stringify(after_raid))
		return {}
	if not _resolved_contains(session, "stale_hero_hunt_vaska"):
		_fail("Stale unsupported hero hunt was not removed from active encounters.")
		return {}
	if String(after_raid.get("target_kind", "")) != "commander":
		_fail("Stale unsupported hero hunt should retarget to commander rebuild: %s" % JSON.stringify(after_raid))
		return {}
	var reason_codes := _string_array(after_raid.get("target_reason_codes", []))
	for required_code in ["risk_support_timeout", "hero_hunt_risk_stalled", "hero_hunt"]:
		if required_code not in reason_codes:
			_fail("Stale unsupported hero hunt missing %s: %s" % [required_code, JSON.stringify(after_raid)])
			return {}
	_assert_task_status(session, "hero_vaska", "hero", hero_id, "suspended", "invalid_actor_rebuilding")
	if _failed:
		return {}
	var roster_entry := _commander_entry(session, "hero_vaska")
	if roster_entry.is_empty():
		_fail("Missing hero_vaska roster entry after stale hero-hunt retirement.")
		return {}
	if EnemyAdventureRules.commander_can_deploy(roster_entry):
		_fail("Stale unsupported hero hunt commander is deployable before rebuild: %s" % JSON.stringify(roster_entry))
		return {}
	var continuity := EnemyAdventureRules.commander_army_continuity(roster_entry)
	if int(continuity.get("current_strength", 0)) != before_strength or int(continuity.get("rebuild_need", 0)) <= 0:
		_fail("Stale unsupported hero hunt did not preserve rebuild continuity: before=%d continuity=%s" % [before_strength, JSON.stringify(continuity)])
		return {}
	var events: Array = intercept_result.get("events", []) if intercept_result.get("events", []) is Array else []
	var event_types := _event_types(events)
	if "ai_target_assigned" not in event_types:
		_fail("Stale unsupported hero hunt retirement did not emit ai_target_assigned: %s" % JSON.stringify(intercept_result))
		return {}
	return {
		"case_id": "stale_unsupported_hero_hunt_retires_to_rebuild",
		"before_strength": before_strength,
		"battle_started": false,
		"risk_gated": true,
		"retired_to_rebuild": bool(after_raid.get("raid_retired_to_rebuild", false)),
		"resolved": _resolved_contains(session, "stale_hero_hunt_vaska"),
		"target_kind": String(after_raid.get("target_kind", "")),
		"reason_codes": reason_codes,
		"commander_deployable_after": EnemyAdventureRules.commander_can_deploy(roster_entry),
		"commander_rebuild_need": int(continuity.get("rebuild_need", 0)),
		"event_types": event_types,
		"save_version": int(SessionStateStore.SAVE_VERSION),
	}

func _seed_task_board(session, tasks: Array) -> void:
	var state := _enemy_state(session)
	state["hero_task_state"] = {
		"schema_version": 1,
		"planner_epoch": 13,
		"tasks": tasks,
	}
	_update_enemy_state(session, state)

func _task(actor_id: String, target_id: String, status: String, validation: String) -> Dictionary:
	return {
		"task_id": "task:hero_hunt:%s:%s" % [actor_id, target_id],
		"owner_faction_id": MIRECLAW,
		"actor_kind": "commander_roster",
		"actor_id": actor_id,
		"source_kind": "saved_task_state",
		"source_id": "hero_hunt_fixture",
		"task_class": "contest_site",
		"task_status": status,
		"target_kind": "hero",
		"target_id": target_id,
		"front_id": "hero:%s" % target_id,
		"origin_kind": "encounter",
		"origin_id": "hero_hunt_fixture",
		"priority_reason_codes": ["hero_hunt", "exposed_hero", "hero_hunt_task_fixture"],
		"assigned_day": 2,
		"expires_day": 9,
		"continuity_policy": "persist_until_invalid",
		"route_policy": "derive_route_on_turn",
		"last_validation": validation,
		"reservation": {
			"reservation_status": "primary",
			"reservation_scope": "exclusive_target",
			"reservation_key": "hero:%s" % target_id,
		},
	}

func _raid_seed(session, roster_hero_id: String, placement_id: String, origin: Vector2i) -> Dictionary:
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

func _set_raid_bog_brutes(raid: Dictionary, count: int) -> Dictionary:
	var updated := raid.duplicate(true)
	var army := {
		"id": "%s_host" % String(updated.get("placement_id", "hero_hunt")),
		"name": "Hero Hunt Host",
		"stacks": [{"unit_id": "unit_bog_brute", "count": max(0, count)}],
	}
	updated["enemy_army"] = army
	var commander_state = updated.get("enemy_commander_state", {})
	if commander_state is Dictionary and not commander_state.is_empty():
		updated["enemy_commander_state"] = EnemyAdventureRules.sync_commander_army_continuity(
			commander_state,
			army,
			String(updated.get("encounter_id", updated.get("id", "")))
		)
	return updated

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

func _defeat_battle_side(session, side: String) -> void:
	var stacks: Array = session.battle.get("stacks", []) if session.battle.get("stacks", []) is Array else []
	for index in range(stacks.size()):
		var stack = stacks[index]
		if not (stack is Dictionary) or String(stack.get("side", "")) != side:
			continue
		stack["total_health"] = 0
		stacks[index] = stack
	session.battle["stacks"] = stacks

func _move_player_hero(session, hero_id: String, tile: Vector2i) -> void:
	var heroes: Array = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		var hero = heroes[index]
		if not (hero is Dictionary) or String(hero.get("id", "")) != hero_id:
			continue
		hero["position"] = {"x": tile.x, "y": tile.y}
		heroes[index] = hero
		session.overworld["player_heroes"] = heroes
		if String(session.overworld.get("active_hero_id", "")) == hero_id:
			session.overworld["hero"] = hero.duplicate(true)
			session.overworld["hero_position"] = {"x": tile.x, "y": tile.y}
			session.overworld["army"] = hero.get("army", {}).duplicate(true) if hero.get("army", {}) is Dictionary else {}
		return
	_fail("Could not move player hero %s." % hero_id)

func _set_player_hero_army(session, hero_id: String, stacks: Array) -> void:
	var army := {
		"id": "%s_army" % hero_id,
		"name": "%s Army" % hero_id,
		"stacks": stacks.duplicate(true),
	}
	var heroes: Array = session.overworld.get("player_heroes", [])
	for index in range(heroes.size()):
		var hero = heroes[index]
		if not (hero is Dictionary) or String(hero.get("id", "")) != hero_id:
			continue
		hero["army"] = army.duplicate(true)
		heroes[index] = hero
		session.overworld["player_heroes"] = heroes
		if String(session.overworld.get("active_hero_id", "")) == hero_id:
			var active_hero: Dictionary = session.overworld.get("hero", {}) if session.overworld.get("hero", {}) is Dictionary else {}
			active_hero["army"] = army.duplicate(true)
			session.overworld["hero"] = active_hero
			session.overworld["army"] = army.duplicate(true)
		return
	_fail("Could not set player hero army for %s." % hero_id)

func _add_player_hero_decoy(session, hero_id: String, hero_name: String, tile: Vector2i) -> void:
	var heroes: Array = session.overworld.get("player_heroes", [])
	var active_hero: Dictionary = session.overworld.get("hero", {}) if session.overworld.get("hero", {}) is Dictionary else {}
	var decoy := active_hero.duplicate(true)
	decoy["id"] = hero_id
	decoy["name"] = hero_name
	decoy["is_primary"] = false
	decoy["position"] = {"x": tile.x, "y": tile.y}
	decoy["army"] = {
		"id": "%s_army" % hero_id,
		"name": "%s Guard" % hero_name,
		"stacks": [{"unit_id": "unit_ember_squire", "count": 30}],
	}
	heroes.append(decoy)
	session.overworld["player_heroes"] = heroes

func _hero_name(session, hero_id: String) -> String:
	for hero in session.overworld.get("player_heroes", []):
		if hero is Dictionary and String(hero.get("id", "")) == hero_id:
			return String(hero.get("name", hero_id))
	return hero_id

func _nearest_open_non_town_tile(session, preferred: Vector2i) -> Vector2i:
	return _nearest_open_non_town_tile_excluding(session, preferred, Vector2i(-1, -1))

func _nearest_open_non_town_tile_excluding(session, preferred: Vector2i, excluded: Vector2i) -> Vector2i:
	var map_size: Vector2i = OverworldRules.derive_map_size(session)
	for radius in range(0, max(map_size.x, map_size.y)):
		for y in range(max(0, preferred.y - radius), min(map_size.y, preferred.y + radius + 1)):
			for x in range(max(0, preferred.x - radius), min(map_size.x, preferred.x + radius + 1)):
				var tile := Vector2i(x, y)
				if tile == excluded:
					continue
				if abs(tile.x - preferred.x) + abs(tile.y - preferred.y) > radius:
					continue
				if OverworldRules.tile_is_blocked(session, tile.x, tile.y):
					continue
				if _player_town_at(session, tile):
					continue
				return tile
	_fail("Could not find open non-town tile near %s." % str(preferred))
	return preferred

func _nearby_open_non_town_tile_at_distance(session, center: Vector2i, min_distance: int, max_distance: int) -> Vector2i:
	var map_size: Vector2i = OverworldRules.derive_map_size(session)
	for radius in range(max(0, min_distance), max(min_distance, max_distance) + 1):
		for dy in range(-radius, radius + 1):
			var dx_options := [radius - abs(dy)]
			if dx_options[0] != 0:
				dx_options.append(-dx_options[0])
			for dx in dx_options:
				var tile := Vector2i(center.x + int(dx), center.y + dy)
				if tile.x < 0 or tile.y < 0 or tile.x >= map_size.x or tile.y >= map_size.y:
					continue
				if OverworldRules.tile_is_blocked(session, tile.x, tile.y):
					continue
				if _player_town_at(session, tile):
					continue
				return tile
	_fail("Could not find open non-town tile %d-%d steps from %s." % [min_distance, max_distance, str(center)])
	return center

func _player_town_at(session, tile: Vector2i) -> bool:
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("owner", "neutral")) == "player":
			if int(town.get("x", -1)) == tile.x and int(town.get("y", -1)) == tile.y:
				return true
	return false

func _first_player_town(session) -> Dictionary:
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("owner", "neutral")) == "player":
			return town
	return {}

func _append_encounter(session, encounter: Dictionary) -> void:
	var encounters: Array = session.overworld.get("encounters", [])
	encounters.append(encounter.duplicate(true))
	session.overworld["encounters"] = encounters

func _encounter(session, placement_id: String) -> Dictionary:
	for encounter in session.overworld.get("encounters", []):
		if encounter is Dictionary and String(encounter.get("placement_id", "")) == placement_id:
			return encounter
	return {}

func _remove_mireclaw_hero_hunt_encounters(session) -> void:
	var kept := []
	for encounter in session.overworld.get("encounters", []):
		if not (encounter is Dictionary):
			continue
		if String(encounter.get("spawned_by_faction_id", "")) == MIRECLAW and String(encounter.get("target_kind", "")) == "hero":
			continue
		kept.append(encounter)
	session.overworld["encounters"] = kept

func _remove_mireclaw_active_raids(session) -> void:
	var kept := []
	var resolved: Array = session.overworld.get("resolved_encounters", []) if session.overworld.get("resolved_encounters", []) is Array else []
	for encounter in session.overworld.get("encounters", []):
		if not (encounter is Dictionary):
			continue
		if String(encounter.get("spawned_by_faction_id", "")) == MIRECLAW and String(encounter.get("placement_id", "")) not in resolved:
			continue
		kept.append(encounter)
	session.overworld["encounters"] = kept

func _clear_mireclaw_resource_claims(session) -> void:
	var nodes: Array = session.overworld.get("resource_nodes", []) if session.overworld.get("resource_nodes", []) is Array else []
	for index in range(nodes.size()):
		var node = nodes[index]
		if not (node is Dictionary):
			continue
		if String(node.get("collected_by_faction_id", "")) == MIRECLAW:
			node["collected_by_faction_id"] = ""
			nodes[index] = node
	session.overworld["resource_nodes"] = nodes

func _remove_enemy_regroup_towns(session) -> void:
	var towns: Array = session.overworld.get("towns", [])
	for index in range(towns.size()):
		var town = towns[index]
		if not (town is Dictionary):
			continue
		if String(town.get("owner", "neutral")) == "enemy":
			town["owner"] = "neutral"
			town["controlling_faction_id"] = ""
			towns[index] = town
	session.overworld["towns"] = towns

func _resolved_contains(session, placement_id: String) -> bool:
	var resolved: Array = session.overworld.get("resolved_encounters", []) if session.overworld.get("resolved_encounters", []) is Array else []
	return placement_id in resolved

func _commander_entry(session, roster_hero_id: String) -> Dictionary:
	for entry in EnemyAdventureRules.commander_roster_for_faction(session, MIRECLAW):
		if entry is Dictionary and String(entry.get("roster_hero_id", "")) == roster_hero_id:
			return entry
	return {}

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

func _public_event_leaks(public_events: Variant) -> bool:
	var forbidden_tokens := ["target_debug_reason", "hero_task_state", "task_id", "reservation_key", "garrison_score", "raid_score"]
	var encoded := JSON.stringify(public_events)
	for token in forbidden_tokens:
		if encoded.find(token) >= 0:
			_fail("Hero hunt public events leaked internal token %s" % token)
			return true
	return false

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
