extends Node

const REPORT_ID := "AI_RAID_ASSAULT_GROUPING_REPORT"
const RIVER_PASS := "river-pass"
const MIRECLAW := "faction_mireclaw"
const TOWN_ID := "duskfen_bastion"

var _failed := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var commanderless_case_report := _river_pass_nearby_raids_group_for_town_assault()
	if commanderless_case_report.is_empty():
		return
	var commander_case_report := _river_pass_commander_raids_group_for_town_assault()
	if commander_case_report.is_empty():
		return
	var planned_commander_case_report := _planned_commander_keeps_grouping_leadership()
	if planned_commander_case_report.is_empty():
		return
	var post_move_case_report := _river_pass_raids_group_after_leader_movement_for_town_assault()
	if post_move_case_report.is_empty():
		return
	var long_range_pressure_case_report := _long_range_player_town_restores_battle_pressure()
	if long_range_pressure_case_report.is_empty():
		return
	var blocked_route_pressure_case_report := _blocked_player_town_uses_persistent_frontier_pressure()
	if blocked_route_pressure_case_report.is_empty():
		return
	var continued_route_pressure_case_report := _blocked_player_town_waypoint_continues_town_pressure()
	if continued_route_pressure_case_report.is_empty():
		return
	var exhausted_route_pressure_case_report := _exhausted_player_town_frontier_does_not_recycle()
	if exhausted_route_pressure_case_report.is_empty():
		return
	var neutral_town_fallback_case_report := _blocked_player_town_prefers_reachable_defended_neutral_town()
	if neutral_town_fallback_case_report.is_empty():
		return
	var resource_traversal_case_report := _resource_visit_tile_allows_contest_route()
	if resource_traversal_case_report.is_empty():
		return
	var eight_way_pathing_case_report := _eight_way_pathing_matches_overworld_corner_rules()
	if eight_way_pathing_case_report.is_empty():
		return
	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"schema_status": "live_raid_assault_grouping_post_move_no_save_migration",
		"behavior_policy": "nearby_same_town_raids_group_before_assault_or_after_movement_and_reachable_or_blocked_player_towns_restore_persistent_battle_pressure",
		"save_policy": "hero_task_state_live_persist_no_save_migration",
		"case": commanderless_case_report,
		"commander_case": commander_case_report,
		"planned_commander_case": planned_commander_case_report,
		"post_move_case": post_move_case_report,
		"long_range_pressure_case": long_range_pressure_case_report,
		"blocked_route_pressure_case": blocked_route_pressure_case_report,
		"continued_route_pressure_case": continued_route_pressure_case_report,
		"exhausted_route_pressure_case": exhausted_route_pressure_case_report,
		"neutral_town_fallback_case": neutral_town_fallback_case_report,
		"resource_traversal_case": resource_traversal_case_report,
		"eight_way_pathing_case": eight_way_pathing_case_report,
		"save_version_before": int(SessionStateStore.SAVE_VERSION),
		"save_version_after": int(SessionStateStore.SAVE_VERSION),
	}
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _planned_commander_keeps_grouping_leadership() -> Dictionary:
	var session = _base_session()
	_set_player_captured_retake_front(session, TOWN_ID)
	var config := _enemy_config()
	var generic_leader := _raid_seed("generic_pressure_leader", 7, 2, 12, true, session, config, "hero_sable")
	var planned_commander := _raid_seed("planned_task_commander", 7, 3, 8, true, session, config, "hero_vaska")
	var planned_reason_codes: Array = planned_commander.get("target_reason_codes", []).duplicate()
	planned_reason_codes.append("strategic_task_planner")
	planned_commander["target_reason_codes"] = planned_reason_codes
	var encounters := [generic_leader, planned_commander]
	var resolved: Array = []
	var generic_result := EnemyAdventureRules.group_nearby_raids_for_town_assault(
		session,
		config,
		encounters,
		0,
		generic_leader,
		MIRECLAW,
		resolved
	)
	if bool(generic_result.get("grouped", false)):
		_fail("Generic pressure host consumed an intact planner-assigned commander.")
		return {}
	var planned_result := EnemyAdventureRules.group_nearby_raids_for_town_assault(
		session,
		config,
		encounters,
		1,
		planned_commander,
		MIRECLAW,
		resolved
	)
	if not bool(planned_result.get("grouped", false)):
		_fail("Planner-assigned commander did not consolidate the stronger generic support host.")
		return {}
	if String(planned_result.get("donor_placement_id", "")) != "generic_pressure_leader":
		_fail("Planner-assigned commander consolidated the wrong support host: %s" % JSON.stringify(planned_result))
		return {}
	var grouped: Dictionary = planned_result.get("encounter", {})
	return {
		"case_id": "planned_commander_keeps_grouping_leadership",
		"planned_commander_id": "planned_task_commander",
		"task_marker": "strategic_task_planner",
		"support_id": "generic_pressure_leader",
		"generic_leader_grouped": false,
		"planned_commander_grouped": true,
		"grouped_strength": EnemyAdventureRules.raid_strength(grouped),
	}

func _eight_way_pathing_matches_overworld_corner_rules() -> Dictionary:
	var session = _base_session()
	session.overworld["map"] = [
		["water", "water", "water", "water", "water"],
		["water", "grass", "water", "grass", "water"],
		["water", "grass", "grass", "grass", "water"],
		["water", "water", "water", "water", "water"],
	]
	session.overworld["map_size"] = {"width": 5, "height": 4}
	for key in ["towns", "encounters", "map_objects", "resource_nodes", "artifact_nodes", "player_heroes"]:
		session.overworld[key] = []
	session.overworld["hero"] = {}
	EnemyAdventureRules._path_distance_surface_cache.clear()
	var start := Vector2i(1, 1)
	var goal := Vector2i(3, 1)
	var bridge := Vector2i(2, 2)
	var diagonal_distance := EnemyAdventureRules._path_distance(session, start, [goal], "", MIRECLAW)
	var next_step := EnemyAdventureRules._next_step_toward(session, start, [goal], "", MIRECLAW)
	if diagonal_distance != 2 or next_step != bridge:
		_fail("Eight-way AI pathing did not use the legal two-diagonal route: distance=%d next=%s" % [diagonal_distance, next_step])
		return {}
	if OverworldRules.tile_step_cuts_blocked_corner(session, start, bridge):
		_fail("AI accepted a diagonal that the live overworld corner rule rejects.")
		return {}

	session.overworld["map"] = [
		["grass", "water", "water"],
		["water", "grass", "water"],
		["water", "water", "grass"],
	]
	session.overworld["map_size"] = {"width": 3, "height": 3}
	EnemyAdventureRules._path_distance_surface_cache.clear()
	var blocked_start := Vector2i(0, 0)
	var blocked_goal := Vector2i(1, 1)
	var blocked_distance := EnemyAdventureRules._path_distance(session, blocked_start, [blocked_goal], "", MIRECLAW)
	var blocked_next_step := EnemyAdventureRules._next_step_toward(session, blocked_start, [blocked_goal], "", MIRECLAW)
	if blocked_distance < 9999 or blocked_next_step != blocked_start:
		_fail("Eight-way AI pathing cut through a doubly blocked corner: distance=%d next=%s" % [blocked_distance, blocked_next_step])
		return {}
	if not OverworldRules.tile_step_cuts_blocked_corner(session, blocked_start, blocked_goal):
		_fail("Blocked-corner fixture does not exercise the live overworld corner rule.")
		return {}
	return {
		"case_id": "strategic_ai_eight_way_pathing_matches_overworld_corner_rules",
		"legal_diagonal_distance": diagonal_distance,
		"legal_diagonal_next_step": {"x": next_step.x, "y": next_step.y},
		"blocked_corner_distance": blocked_distance,
		"blocked_corner_next_step": {"x": blocked_next_step.x, "y": blocked_next_step.y},
	}

func _resource_visit_tile_allows_contest_route() -> Dictionary:
	var session = _base_session()
	session.overworld["map"] = [["grass", "grass", "grass", "grass", "grass"]]
	session.overworld["map_size"] = {"width": 5, "height": 1}
	session.overworld["towns"] = []
	session.overworld["encounters"] = []
	session.overworld["map_objects"] = []
	session.overworld["artifact_nodes"] = []
	session.overworld["player_heroes"] = []
	session.overworld["hero"] = {}
	session.overworld["resource_nodes"] = [{
		"placement_id": "owned_corridor_site",
		"site_id": "site_generated_town_required_source_cache",
		"x": 3,
		"y": 0,
		"blocking_body": true,
		"collected": true,
		"collected_by_faction_id": "player",
		"visit_tile": {"x": 2, "y": 0, "level": 0},
		"package_block_tiles": [{"x": 2, "y": 0, "level": 0}],
	}]
	var owned_distance := EnemyAdventureRules._path_distance(
		session,
		Vector2i(0, 0),
		[Vector2i(4, 0)],
		"",
		MIRECLAW
	)
	var opposing_distance := EnemyAdventureRules._path_distance(
		session,
		Vector2i(0, 0),
		[Vector2i(4, 0)],
		"",
		"faction_sunvault"
	)
	if owned_distance != 4:
		_fail("Faction-owned resource visit tile did not reopen its corridor: %d" % owned_distance)
		return {}
	if opposing_distance != 4:
		_fail("Contesting faction could not route through a resource visit tile: %d" % opposing_distance)
		return {}
	var claim_id := EnemyAdventureRules._current_tile_contestable_resource_id(
		session,
		{"x": 2, "y": 0},
		MIRECLAW
	)
	if claim_id != "owned_corridor_site":
		_fail("AI did not recognize the offset visit tile as the resource interaction tile: %s" % claim_id)
		return {}
	var candidates := []
	EnemyAdventureRules._append_resource_candidate(
		session,
		candidates,
		{},
		session.overworld.get("resource_nodes", [])[0],
		Vector2i(0, 0),
		{"faction_id": MIRECLAW},
		MIRECLAW,
		true,
		EnemyAdventureRules._path_distance_surface_context(session, "", MIRECLAW)
	)
	if candidates.size() != 1 \
			or int(candidates[0].get("target_x", -1)) != 2 \
			or int(candidates[0].get("goal_distance", -1)) != 2:
		_fail("AI resource candidate did not target the offset visit tile: %s" % JSON.stringify(candidates))
		return {}
	var saved_task_plan := EnemyAdventureRules._ai_hero_task_plan_from_saved_task(
		session,
		{"faction_id": MIRECLAW},
		{
			"placement_id": "offset_visit_saved_task_probe",
			"spawned_by_faction_id": MIRECLAW,
			"x": 0,
			"y": 0,
		},
		{
			"task_id": "offset_visit_saved_resource_task",
			"task_class": "contest_site",
			"task_status": "planned",
			"actor_id": "hero_vaska",
			"target_kind": "resource",
			"target_id": "owned_corridor_site",
			"priority_reason_codes": ["site_contested"],
		},
		Vector2i(0, 0),
		"offset_visit_saved_task_probe"
	)
	if int(saved_task_plan.get("target_x", -1)) != 2 \
			or int(saved_task_plan.get("goal_x", -1)) != 2 \
			or int(saved_task_plan.get("goal_distance", -1)) != 2:
		_fail("Saved AI resource task did not use the offset visit tile: %s" % JSON.stringify(saved_task_plan))
		return {}
	var pickup := EnemyAdventureRules._resolve_opportunistic_route_objective(
		session,
		{"faction_id": MIRECLAW},
		{
			"placement_id": "offset_visit_pickup_raid",
			"spawned_by_faction_id": MIRECLAW,
			"x": 2,
			"y": 0,
			"target_kind": "explore",
			"target_placement_id": "explore:4:0",
			"enemy_army": {"stacks": [{"unit_id": "unit_bog_brute", "count": 3}]},
		},
		{},
		MIRECLAW
	)
	if not bool(pickup.get("resolved", false)) \
			or String(session.overworld.get("resource_nodes", [])[0].get("collected_by_faction_id", "")) != MIRECLAW:
		_fail("AI did not capture the resource from its offset visit tile: %s" % JSON.stringify(pickup))
		return {}
	return {
		"case_id": "resource_visit_tile_allows_contest_route",
		"owned_distance": owned_distance,
		"opposing_distance": opposing_distance,
		"claim_id": claim_id,
		"candidate_goal_x": int(candidates[0].get("target_x", -1)),
		"candidate_goal_distance": int(candidates[0].get("goal_distance", -1)),
		"saved_task_goal_x": int(saved_task_plan.get("goal_x", -1)),
		"saved_task_goal_distance": int(saved_task_plan.get("goal_distance", -1)),
		"visit_tile_pickup_resolved": bool(pickup.get("resolved", false)),
	}

func _river_pass_nearby_raids_group_for_town_assault() -> Dictionary:
	var session = _base_session()
	var state := _enemy_state(session)
	state["pressure"] = 0
	_update_enemy_state(session, state)
	_set_player_captured_retake_front(session, TOWN_ID)
	var config := _enemy_config()
	var leader := _raid_seed("grouping_assault_vaska", 7, 2, 7, true, session, config)
	var support := _raid_seed("grouping_support_column", 7, 3, 3, false, session, config)
	var leader_strength_before := EnemyAdventureRules.raid_strength(leader)
	var support_strength_before := EnemyAdventureRules.raid_strength(support)
	var encounters: Array = session.overworld.get("encounters", [])
	encounters.append(leader)
	encounters.append(support)
	session.overworld["encounters"] = encounters

	var active_before := _active_raid_count(session)
	var result := EnemyTurnRules.run_enemy_turn(session)
	if not bool(result.get("ok", false)):
		_fail("Enemy turn failed during grouping fixture: %s" % JSON.stringify(result))
		return {}
	var after_leader := _encounter(session, "grouping_assault_vaska")
	if after_leader.is_empty():
		_fail("Leader raid disappeared after grouping fixture.")
		return {}
	var resolved: Array = session.overworld.get("resolved_encounters", []) if session.overworld.get("resolved_encounters", []) is Array else []
	if "grouping_support_column" not in resolved:
		_fail("Support raid was not removed from active pressure after grouping: %s" % JSON.stringify(resolved))
		return {}
	var leader_strength_after := EnemyAdventureRules.raid_strength(after_leader)
	if leader_strength_after < leader_strength_before + support_strength_before:
		_fail("Leader did not absorb support strength: before %d support %d after %d" % [leader_strength_before, support_strength_before, leader_strength_after])
		return {}
	var continuity: Dictionary = EnemyAdventureRules.commander_army_continuity(after_leader.get("enemy_commander_state", {}))
	if int(continuity.get("current_strength", 0)) != leader_strength_after:
		_fail("Leader commander continuity did not refresh after grouping: %s strength %d" % [JSON.stringify(continuity), leader_strength_after])
		return {}
	var event_types := _event_types(result.get("events", []))
	if "ai_raid_grouped" not in event_types:
		_fail("Grouping fixture did not emit ai_raid_grouped: %s" % JSON.stringify(result))
		return {}
	var public_log := EnemyAdventureRules.ai_public_event_log_boundary_report(result.get("events", []), 8)
	if not bool(public_log.get("ok", false)):
		_fail("Grouping public event boundary failed: %s" % JSON.stringify(public_log))
		return {}
	if _public_event_leaks(public_log.get("public_events", [])):
		return {}
	if session.battle.is_empty():
		_fail("Grouped assault did not continue into a town-defense battle: %s" % JSON.stringify(after_leader))
		return {}
	var battle_context: Dictionary = session.battle.get("context", {}) if session.battle.get("context", {}) is Dictionary else {}
	if String(battle_context.get("type", "")) != "town_defense" or String(battle_context.get("town_placement_id", "")) != TOWN_ID:
		_fail("Grouped assault queued wrong battle context: %s" % JSON.stringify(battle_context))
		return {}
	_assert_saved_task_state(session)
	if _failed:
		return {}
	return {
		"case_id": "river_pass_nearby_raids_group_for_town_assault",
		"leader_id": "grouping_assault_vaska",
		"support_id": "grouping_support_column",
		"target_id": TOWN_ID,
		"active_before": active_before,
		"active_after": _active_raid_count(session),
		"leader_strength_before": leader_strength_before,
		"support_strength_before": support_strength_before,
		"leader_strength_after": leader_strength_after,
		"grouped_support_count": int(after_leader.get("grouped_support_count", 0)),
		"last_grouped_support_id": String(after_leader.get("last_grouped_support_placement_id", "")),
		"battle_context_type": String(battle_context.get("type", "")),
		"battle_town_id": String(battle_context.get("town_placement_id", "")),
		"event_types": event_types,
		"public_event_count": int(public_log.get("public_event_count", 0)),
		"save_version": int(SessionStateStore.SAVE_VERSION),
	}

func _river_pass_commander_raids_group_for_town_assault() -> Dictionary:
	var session = _base_session()
	var state := _enemy_state(session)
	state["pressure"] = 0
	_update_enemy_state(session, state)
	_set_player_captured_retake_front(session, TOWN_ID)
	var config := _enemy_config()
	var leader := _raid_seed("grouping_commander_leader_vaska", 7, 2, 8, true, session, config, "hero_vaska")
	var support := _raid_seed("grouping_commander_support_sable", 7, 3, 4, true, session, config, "hero_sable")
	var leader_strength_before := EnemyAdventureRules.raid_strength(leader)
	var support_strength_before := EnemyAdventureRules.raid_strength(support)
	_seed_active_town_task(session, "hero_sable", "grouping_commander_support_sable")
	var encounters: Array = session.overworld.get("encounters", [])
	encounters.append(leader)
	encounters.append(support)
	session.overworld["encounters"] = encounters

	var active_before := _active_raid_count(session)
	var result := EnemyTurnRules.run_enemy_turn(session)
	if not bool(result.get("ok", false)):
		_fail("Enemy turn failed during commander grouping fixture: %s" % JSON.stringify(result))
		return {}
	var after_leader := _encounter(session, "grouping_commander_leader_vaska")
	if after_leader.is_empty():
		_fail("Commander leader raid disappeared after grouping fixture.")
		return {}
	var resolved: Array = session.overworld.get("resolved_encounters", []) if session.overworld.get("resolved_encounters", []) is Array else []
	if "grouping_commander_support_sable" not in resolved:
		_fail("Commander support raid was not removed from active pressure after grouping: %s" % JSON.stringify(resolved))
		return {}
	var leader_strength_after := EnemyAdventureRules.raid_strength(after_leader)
	if leader_strength_after < leader_strength_before + support_strength_before:
		_fail("Commander leader did not absorb support strength: before %d support %d after %d" % [leader_strength_before, support_strength_before, leader_strength_after])
		return {}
	if int(after_leader.get("grouped_commander_support_count", 0)) < 1:
		_fail("Commander-led support was not counted on the grouped assault: %s" % JSON.stringify(after_leader))
		return {}
	var sable_entry := _commander_entry(session, "hero_sable")
	if String(sable_entry.get("status", "")) != EnemyAdventureRules.COMMANDER_STATUS_AVAILABLE:
		_fail("Grouped support commander did not return to available roster status: %s" % JSON.stringify(sable_entry))
		return {}
	if String(sable_entry.get("active_placement_id", "")) != "":
		_fail("Grouped support commander kept an active placement after donating the host: %s" % JSON.stringify(sable_entry))
		return {}
	var sable_continuity: Dictionary = EnemyAdventureRules.commander_army_continuity(sable_entry)
	if int(sable_continuity.get("base_strength", 0)) <= 0 or int(sable_continuity.get("current_strength", -1)) != 0:
		_fail("Grouped support commander did not keep rebuildable empty army continuity: %s" % JSON.stringify(sable_continuity))
		return {}
	if EnemyAdventureRules.commander_can_deploy(sable_entry):
		_fail("Grouped support commander remained deployable after transferring the host: %s" % JSON.stringify(sable_entry))
		return {}
	_assert_task_completed(session, "hero_sable", "town", TOWN_ID)
	if _failed:
		return {}
	var event_types := _event_types(result.get("events", []))
	if "ai_raid_grouped" not in event_types:
		_fail("Commander grouping fixture did not emit ai_raid_grouped: %s" % JSON.stringify(result))
		return {}
	var public_log := EnemyAdventureRules.ai_public_event_log_boundary_report(result.get("events", []), 8)
	if not bool(public_log.get("ok", false)):
		_fail("Commander grouping public event boundary failed: %s" % JSON.stringify(public_log))
		return {}
	if _public_event_leaks(public_log.get("public_events", [])):
		return {}
	return {
		"case_id": "river_pass_commander_raids_group_for_town_assault",
		"leader_id": "grouping_commander_leader_vaska",
		"support_id": "grouping_commander_support_sable",
		"target_id": TOWN_ID,
		"active_before": active_before,
		"active_after": _active_raid_count(session),
		"leader_strength_before": leader_strength_before,
		"support_strength_before": support_strength_before,
		"leader_strength_after": leader_strength_after,
		"grouped_commander_support_count": int(after_leader.get("grouped_commander_support_count", 0)),
		"support_commander_status": String(sable_entry.get("status", "")),
		"support_commander_deployable": EnemyAdventureRules.commander_can_deploy(sable_entry),
		"support_commander_current_strength": int(sable_continuity.get("current_strength", 0)),
		"support_task_status": "completed",
		"event_types": event_types,
		"public_event_count": int(public_log.get("public_event_count", 0)),
		"save_version": int(SessionStateStore.SAVE_VERSION),
	}

func _river_pass_raids_group_after_leader_movement_for_town_assault() -> Dictionary:
	var session = _base_session()
	var state := _enemy_state(session)
	state["pressure"] = 0
	_update_enemy_state(session, state)
	_set_player_captured_retake_front(session, TOWN_ID)
	var config := _enemy_config()
	var leader := _raid_seed("post_move_grouping_assault_vaska", 6, 2, 7, true, session, config)
	var support := _raid_seed("post_move_grouping_support_column", 7, 3, 3, false, session, config)
	if EnemyAdventureRules._raid_tile_distance(leader, support) <= 1:
		_fail("Post-move grouping fixture started with adjacent support; it should require movement first.")
		return {}
	var leader_strength_before := EnemyAdventureRules.raid_strength(leader)
	var support_strength_before := EnemyAdventureRules.raid_strength(support)
	var encounters: Array = session.overworld.get("encounters", [])
	encounters.append(leader)
	encounters.append(support)
	session.overworld["encounters"] = encounters

	var active_before := _active_raid_count(session)
	var result := EnemyTurnRules.run_enemy_turn(session)
	if not bool(result.get("ok", false)):
		_fail("Enemy turn failed during post-move grouping fixture: %s" % JSON.stringify(result))
		return {}
	var after_leader := _encounter(session, "post_move_grouping_assault_vaska")
	if after_leader.is_empty():
		_fail("Post-move grouping leader disappeared after enemy turn.")
		return {}
	var resolved: Array = session.overworld.get("resolved_encounters", []) if session.overworld.get("resolved_encounters", []) is Array else []
	if "post_move_grouping_support_column" not in resolved:
		_fail("Post-move support raid was not resolved into the leader: %s" % JSON.stringify(resolved))
		return {}
	var leader_strength_after := EnemyAdventureRules.raid_strength(after_leader)
	if leader_strength_after < leader_strength_before + support_strength_before:
		_fail("Post-move leader did not absorb support strength: before %d support %d after %d" % [leader_strength_before, support_strength_before, leader_strength_after])
		return {}
	if String(after_leader.get("last_grouped_support_placement_id", "")) != "post_move_grouping_support_column":
		_fail("Post-move leader did not record grouped support id: %s" % JSON.stringify(after_leader))
		return {}
	if int(after_leader.get("x", 0)) != 7 or int(after_leader.get("y", 0)) != 2:
		_fail("Post-move leader did not move onto the town staging tile before grouping: %s" % JSON.stringify(after_leader))
		return {}
	var event_types := _event_types(result.get("events", []))
	if "ai_raid_grouped" not in event_types:
		_fail("Post-move grouping fixture did not emit ai_raid_grouped: %s" % JSON.stringify(result))
		return {}
	var public_log := EnemyAdventureRules.ai_public_event_log_boundary_report(result.get("events", []), 8)
	if not bool(public_log.get("ok", false)):
		_fail("Post-move grouping public event boundary failed: %s" % JSON.stringify(public_log))
		return {}
	if _public_event_leaks(public_log.get("public_events", [])):
		return {}
	if session.battle.is_empty():
		_fail("Post-move grouped assault did not continue into a town-defense battle: %s" % JSON.stringify(after_leader))
		return {}
	var battle_context: Dictionary = session.battle.get("context", {}) if session.battle.get("context", {}) is Dictionary else {}
	if String(battle_context.get("type", "")) != "town_defense" or String(battle_context.get("town_placement_id", "")) != TOWN_ID:
		_fail("Post-move grouped assault queued wrong battle context: %s" % JSON.stringify(battle_context))
		return {}
	return {
		"case_id": "river_pass_raids_group_after_leader_movement_for_town_assault",
		"leader_id": "post_move_grouping_assault_vaska",
		"support_id": "post_move_grouping_support_column",
		"target_id": TOWN_ID,
		"active_before": active_before,
		"active_after": _active_raid_count(session),
		"leader_position_after": {"x": int(after_leader.get("x", 0)), "y": int(after_leader.get("y", 0))},
		"leader_strength_before": leader_strength_before,
		"support_strength_before": support_strength_before,
		"leader_strength_after": leader_strength_after,
		"grouped_support_count": int(after_leader.get("grouped_support_count", 0)),
		"last_grouped_support_id": String(after_leader.get("last_grouped_support_placement_id", "")),
		"battle_context_type": String(battle_context.get("type", "")),
		"battle_town_id": String(battle_context.get("town_placement_id", "")),
		"event_types": event_types,
		"public_event_count": int(public_log.get("public_event_count", 0)),
		"save_version": int(SessionStateStore.SAVE_VERSION),
	}

func _long_range_player_town_restores_battle_pressure() -> Dictionary:
	var session = _long_range_pressure_session(false)

	var raids := []
	for index in range(3):
		var x := 3 + index
		raids.append(_pressure_floor_raid_seed("long_range_pressure_%d" % index, x, 1, 8 + index))
	session.overworld["encounters"] = raids
	var config := _enemy_config()
	var candidate_before := EnemyAdventureRules._target_candidates(session, config, Vector2i(3, 1))
	var distant_town_distance := -1
	for candidate_value in candidate_before:
		if candidate_value is Dictionary and String(candidate_value.get("target_placement_id", "")) == "riverwatch_hold":
			distant_town_distance = int(candidate_value.get("goal_distance", -1))
			break
	if distant_town_distance <= EnemyAdventureRules.RAID_BATTLE_PRESSURE_FLOOR_MAX_DISTANCE:
		_fail("Long-range pressure fixture did not place the player town beyond the pressure floor distance: %d" % distant_town_distance)
		return {}

	var assigned := EnemyAdventureRules.assign_target(session, config, raids[0].duplicate(true))
	if String(assigned.get("target_kind", "")) != "town" or String(assigned.get("target_placement_id", "")) != "riverwatch_hold":
		_fail("Long-range reachable player town did not preempt exploration pressure: %s" % JSON.stringify(assigned))
		return {}
	if int(assigned.get("goal_distance", 9999)) >= 9999:
		_fail("Long-range player town pressure produced an unreachable route: %s" % JSON.stringify(assigned))
		return {}
	var reason_codes: Array = assigned.get("target_reason_codes", []) if assigned.get("target_reason_codes", []) is Array else []
	if "battle_pressure_floor" not in reason_codes:
		_fail("Long-range player town pressure omitted battle_pressure_floor reasoning: %s" % JSON.stringify(assigned))
		return {}
	return {
		"case_id": "long_range_player_town_restores_battle_pressure",
		"active_raid_count": raids.size(),
		"previous_target_kind": "explore",
		"target_kind": String(assigned.get("target_kind", "")),
		"target_id": String(assigned.get("target_placement_id", "")),
		"goal_distance": int(assigned.get("goal_distance", -1)),
		"reason_codes": reason_codes,
	}

func _pressure_floor_raid_seed(placement_id: String, x: int, y: int, brute_count: int) -> Dictionary:
	return {
		"placement_id": placement_id,
		"encounter_id": "encounter_mire_raid",
		"x": x,
		"y": y,
		"difficulty": "pressure",
		"spawned_by_faction_id": MIRECLAW,
		"commanderless_support_column": true,
		"days_active": 8,
		"arrived": false,
		"target_kind": "explore",
		"target_placement_id": "explore:%d:%d" % [x + 4, y],
		"target_label": "Frontier scout %d,%d" % [x + 4, y],
		"target_x": x + 4,
		"target_y": y,
		"goal_x": x + 4,
		"goal_y": y,
		"goal_distance": 4,
		"target_reason_codes": ["no_known_targets", "frontier_scouting"],
		"enemy_army": {
			"id": "%s_host" % placement_id,
			"name": "Long-range Pressure Host",
			"stacks": [{"unit_id": "unit_bog_brute", "count": brute_count}],
		},
	}

func _blocked_player_town_uses_persistent_frontier_pressure() -> Dictionary:
	var session = _long_range_pressure_session(true)
	var raids := []
	for index in range(3):
		raids.append(_pressure_floor_raid_seed("blocked_route_pressure_%d" % index, 3 + index, 1, 8 + index))
	session.overworld["encounters"] = raids
	var config := _enemy_config()
	var assigned := EnemyAdventureRules.assign_target(session, config, raids[0].duplicate(true))
	if String(assigned.get("target_kind", "")) != "explore":
		_fail("Blocked player town did not select a reachable frontier pressure waypoint: %s" % JSON.stringify(assigned))
		return {}
	if String(assigned.get("blocked_route_target_placement_id", "")) != "riverwatch_hold":
		_fail("Blocked player town frontier pressure lost the town objective: %s" % JSON.stringify(assigned))
		return {}
	var reason_codes: Array = assigned.get("target_reason_codes", []) if assigned.get("target_reason_codes", []) is Array else []
	if "battle_pressure_floor" not in reason_codes or "pressure_route_frontier" not in reason_codes:
		_fail("Blocked player town frontier pressure omitted route reasoning: %s" % JSON.stringify(assigned))
		return {}
	if int(assigned.get("target_x", 0)) <= int(raids[0].get("x", 0)) or int(assigned.get("target_x", 9999)) >= 40:
		_fail("Blocked player town frontier pressure did not advance toward the reachable side of the divider: %s" % JSON.stringify(assigned))
		return {}
	var encounters: Array = session.overworld.get("encounters", [])
	encounters[0] = assigned
	session.overworld["encounters"] = encounters
	var reassigned := EnemyAdventureRules.assign_target(session, config, assigned.duplicate(true))
	if String(reassigned.get("target_placement_id", "")) != String(assigned.get("target_placement_id", "")):
		_fail("Active frontier pressure route churned before reaching its waypoint: %s" % JSON.stringify(reassigned))
		return {}
	var connected_pressure_count := EnemyAdventureRules._active_player_battle_pressure_raid_count(
		session,
		MIRECLAW,
		String(raids[1].get("placement_id", "")),
		raids[1]
	)
	if connected_pressure_count != 1:
		_fail("Connected host did not recognize the existing player pressure route: %d" % connected_pressure_count)
		return {}
	var disconnected_probe: Dictionary = raids[1].duplicate(true)
	disconnected_probe["x"] = 60
	disconnected_probe["y"] = 1
	var disconnected_pressure_count := EnemyAdventureRules._active_player_battle_pressure_raid_count(
		session,
		MIRECLAW,
		String(disconnected_probe.get("placement_id", "")),
		disconnected_probe
	)
	if disconnected_pressure_count != 0:
		_fail("Disconnected host was incorrectly suppressed by another front's pressure route: %d" % disconnected_pressure_count)
		return {}
	return {
		"case_id": "blocked_player_town_uses_persistent_frontier_pressure",
		"active_raid_count": raids.size(),
		"target_kind": String(assigned.get("target_kind", "")),
		"target_id": String(assigned.get("target_placement_id", "")),
		"blocked_town_id": String(assigned.get("blocked_route_target_placement_id", "")),
		"goal_distance": int(assigned.get("goal_distance", -1)),
		"persistent_assignment": true,
		"connected_pressure_count": connected_pressure_count,
		"disconnected_pressure_count": disconnected_pressure_count,
		"reason_codes": reason_codes,
	}

func _blocked_player_town_waypoint_continues_town_pressure() -> Dictionary:
	var session = _long_range_pressure_session(true)
	var raids := []
	for index in range(3):
		raids.append(_pressure_floor_raid_seed("continued_route_pressure_%d" % index, 3 + index, 1, 8 + index))
	session.overworld["encounters"] = raids
	var config := _enemy_config()
	var assigned := EnemyAdventureRules.assign_target(session, config, raids[0].duplicate(true))
	assigned["x"] = int(assigned.get("target_x", 0))
	assigned["y"] = int(assigned.get("target_y", 0))
	assigned["goal_distance"] = 0
	assigned["arrived"] = true
	var state := _enemy_state(session)
	var continued_result := EnemyAdventureRules._resolve_arrived_target(session, assigned, state, MIRECLAW, config)
	var continued: Dictionary = continued_result.get("encounter", {})
	if String(continued.get("target_kind", "")) != "explore":
		_fail("Blocked player-town waypoint did not continue through another reachable frontier waypoint: %s" % JSON.stringify(continued))
		return {}
	if String(continued.get("blocked_route_target_placement_id", "")) != "riverwatch_hold":
		_fail("Continued player-town waypoint lost the blocked town identity: %s" % JSON.stringify(continued))
		return {}
	if String(continued.get("target_placement_id", "")) == String(assigned.get("target_placement_id", "")):
		_fail("Continued player-town waypoint repeated the completed waypoint: %s" % JSON.stringify(continued))
		return {}
	if int(continued.get("target_x", 0)) <= int(assigned.get("x", 0)):
		_fail("Continued player-town waypoint did not advance toward the blocked town: %s" % JSON.stringify(continued))
		return {}

	var opened_session = _long_range_pressure_session(false)
	var opened_probe := continued.duplicate(true)
	opened_probe["x"] = int(continued.get("target_x", 0))
	opened_probe["y"] = int(continued.get("target_y", 0))
	opened_probe["goal_distance"] = 0
	opened_probe["arrived"] = true
	opened_session.overworld["encounters"] = [opened_probe]
	var opened_result := EnemyAdventureRules._resolve_arrived_target(
		opened_session,
		opened_probe,
		_enemy_state(opened_session),
		MIRECLAW,
		config
	)
	var opened: Dictionary = opened_result.get("encounter", {})
	if String(opened.get("target_kind", "")) != "town" or String(opened.get("target_placement_id", "")) != "riverwatch_hold":
		_fail("Opened player-town route did not graduate from waypoint pressure to town assault: %s" % JSON.stringify(opened))
		return {}
	if int(opened.get("goal_distance", 9999)) >= 9999:
		_fail("Opened player-town route graduated to an unreachable town assault: %s" % JSON.stringify(opened))
		return {}
	return {
		"case_id": "blocked_player_town_waypoint_continues_town_pressure",
		"first_waypoint_id": String(assigned.get("target_placement_id", "")),
		"continued_waypoint_id": String(continued.get("target_placement_id", "")),
		"continued_waypoint_distance": int(continued.get("goal_distance", -1)),
		"opened_target_kind": String(opened.get("target_kind", "")),
		"opened_target_id": String(opened.get("target_placement_id", "")),
		"opened_goal_distance": int(opened.get("goal_distance", -1)),
	}

func _exhausted_player_town_frontier_does_not_recycle() -> Dictionary:
	var session = _long_range_pressure_session(true)
	var raids := []
	for index in range(3):
		raids.append(_pressure_floor_raid_seed("exhausted_route_pressure_%d" % index, 3 + index, 1, 8 + index))
	session.overworld["encounters"] = raids
	var config := _enemy_config()
	var current: Dictionary = EnemyAdventureRules.assign_target(session, config, raids[0].duplicate(true))
	var completed_frontiers := []
	var exhausted := {}
	for _step in range(8):
		var reason_codes: Array = current.get("target_reason_codes", []) if current.get("target_reason_codes", []) is Array else []
		if "pressure_route_frontier" not in reason_codes:
			_fail("Blocked route left frontier pressure before exhausting its component: %s" % JSON.stringify(current))
			return {}
		completed_frontiers.append(String(current.get("target_placement_id", "")))
		current["x"] = int(current.get("target_x", 0))
		current["y"] = int(current.get("target_y", 0))
		current["goal_distance"] = 0
		current["arrived"] = true
		var encounters: Array = session.overworld.get("encounters", [])
		encounters[0] = current
		session.overworld["encounters"] = encounters
		var result := EnemyAdventureRules._resolve_arrived_target(
			session,
			current,
			_enemy_state(session),
			MIRECLAW,
			config
		)
		var continued: Dictionary = result.get("encounter", {})
		if String(continued.get("battle_pressure_exhausted_town_id", "")) == "riverwatch_hold":
			exhausted = continued
			break
		current = continued
	if exhausted.is_empty():
		_fail("Blocked route did not record terminal frontier exhaustion: %s" % JSON.stringify(current))
		return {}
	var exhausted_target_id := String(exhausted.get("target_placement_id", ""))
	if exhausted_target_id in completed_frontiers:
		_fail("Terminal frontier immediately recycled a completed waypoint: %s" % JSON.stringify(exhausted))
		return {}
	var exhausted_reason_codes: Array = exhausted.get("target_reason_codes", []) if exhausted.get("target_reason_codes", []) is Array else []
	if "pressure_route_frontier" in exhausted_reason_codes:
		_fail("Terminal frontier remained active after its reachable component was exhausted: %s" % JSON.stringify(exhausted))
		return {}
	var exhausted_encounters: Array = session.overworld.get("encounters", [])
	exhausted_encounters[0] = exhausted
	session.overworld["encounters"] = exhausted_encounters
	var stable := EnemyAdventureRules.assign_target(session, config, exhausted.duplicate(true))
	var stable_reason_codes: Array = stable.get("target_reason_codes", []) if stable.get("target_reason_codes", []) is Array else []
	if "pressure_route_frontier" in stable_reason_codes \
			and String(stable.get("blocked_route_target_placement_id", "")) == "riverwatch_hold":
		_fail("Unchanged topology recycled exhausted player-town frontier pressure: %s" % JSON.stringify(stable))
		return {}
	var stable_encounters: Array = session.overworld.get("encounters", [])
	stable_encounters[0] = stable
	session.overworld["encounters"] = stable_encounters

	var map: Array = session.overworld.get("map", [])
	for y in range(map.size()):
		if map[y] is Array and map[y].size() > 40:
			map[y][40] = "grass"
	session.overworld["map"] = map
	EnemyAdventureRules._path_distance_surface_cache.clear()
	var reopened := EnemyAdventureRules.assign_target(session, config, stable.duplicate(true))
	if String(reopened.get("target_kind", "")) != "town" \
			or String(reopened.get("target_placement_id", "")) != "riverwatch_hold" \
			or int(reopened.get("goal_distance", 9999)) >= 9999:
		_fail("Changed topology did not restore reachable player-town pressure: %s" % JSON.stringify(reopened))
		return {}
	return {
		"case_id": "exhausted_player_town_frontier_does_not_recycle",
		"completed_frontier_count": completed_frontiers.size(),
		"exhausted_target_id": exhausted_target_id,
		"exhausted_town_gap": int(exhausted.get("battle_pressure_exhausted_town_gap", -1)),
		"stable_target_id": String(stable.get("target_placement_id", "")),
		"reopened_target_kind": String(reopened.get("target_kind", "")),
		"reopened_target_id": String(reopened.get("target_placement_id", "")),
		"reopened_goal_distance": int(reopened.get("goal_distance", -1)),
	}

func _blocked_player_town_prefers_reachable_defended_neutral_town() -> Dictionary:
	var session = _long_range_pressure_session(true)
	var towns: Array = session.overworld.get("towns", [])
	for index in range(towns.size()):
		if not (towns[index] is Dictionary):
			continue
		var town: Dictionary = towns[index]
		if String(town.get("placement_id", "")) != TOWN_ID:
			continue
		town["owner"] = "neutral"
		town["controlling_faction_id"] = ""
		town["x"] = 12
		town["y"] = 2
		town["garrison"] = [{"unit_id": "unit_bog_brute", "count": 6}]
		towns[index] = town
		break
	session.overworld["towns"] = towns
	var state := _enemy_state(session)
	state["known_world_memory"] = {
		"schema_version": 1,
		"scouted_targets": [
			{
				"target_kind": "town",
				"target_id": TOWN_ID,
				"target_label": "Duskfen Bastion",
				"x": 12,
				"y": 2,
				"scouted_day": int(session.day),
				"expires_day": int(session.day) + 3,
				"source_kind": "commander",
				"source_id": "blocked_route_neutral_fallback_scout",
			}
		],
	}
	_update_enemy_state(session, state)
	var raids := []
	for index in range(3):
		raids.append(_pressure_floor_raid_seed("neutral_fallback_pressure_%d" % index, 3 + index, 1, 8 + index))
	session.overworld["encounters"] = raids
	var assigned := EnemyAdventureRules.assign_target(session, _enemy_config(), raids[0].duplicate(true))
	if String(assigned.get("target_kind", "")) != "town" or String(assigned.get("target_placement_id", "")) != TOWN_ID:
		_fail("Blocked player-town pressure did not prefer the reachable defended neutral town: %s" % JSON.stringify(assigned))
		return {}
	var reason_codes: Array = assigned.get("target_reason_codes", []) if assigned.get("target_reason_codes", []) is Array else []
	for required_code in ["battle_pressure_floor", "town_expansion", "neutral_town_siege"]:
		if required_code not in reason_codes:
			_fail("Defended neutral-town pressure fallback omitted %s: %s" % [required_code, JSON.stringify(assigned)])
			return {}
	return {
		"case_id": "blocked_player_town_prefers_reachable_defended_neutral_town",
		"target_kind": String(assigned.get("target_kind", "")),
		"target_id": String(assigned.get("target_placement_id", "")),
		"goal_distance": int(assigned.get("goal_distance", -1)),
		"reason_codes": reason_codes,
	}

func _long_range_pressure_session(blocked: bool):
	var session = _base_session()
	session.day = 8
	var map := []
	for y in range(5):
		var row := []
		for x in range(68):
			row.append("water" if blocked and x == 40 else "grass")
		map.append(row)
	session.overworld["map"] = map
	session.overworld["map_size"] = {"width": 68, "height": 5}
	session.overworld["resource_nodes"] = []
	session.overworld["artifact_nodes"] = []
	session.overworld["resolved_encounters"] = []
	session.overworld["player_heroes"] = []
	session.overworld["hero"] = {}

	var towns: Array = session.overworld.get("towns", [])
	for index in range(towns.size()):
		if not (towns[index] is Dictionary):
			continue
		var town: Dictionary = towns[index]
		if String(town.get("placement_id", "")) == "riverwatch_hold":
			town["x"] = 65
			town["y"] = 2
			town["owner"] = "player"
		elif String(town.get("placement_id", "")) == TOWN_ID:
			town["x"] = 2
			town["y"] = 2
			town["owner"] = "enemy"
			town["controlling_faction_id"] = MIRECLAW
		towns[index] = town
	session.overworld["towns"] = towns
	return session

func _raid_seed(placement_id: String, x: int, y: int, brute_count: int, with_commander: bool, session, config: Dictionary, roster_hero_id: String = "hero_vaska") -> Dictionary:
	var raid := {
		"placement_id": placement_id,
		"encounter_id": "encounter_mire_raid",
		"x": x,
		"y": y,
		"difficulty": "pressure",
		"combat_seed": hash("%s:%s" % [String(session.scenario_id), placement_id]),
		"spawned_by_faction_id": MIRECLAW,
		"commanderless_support_column": not with_commander,
		"days_active": 0,
		"arrived": false,
		"goal_distance": 9999,
		"enemy_army": {
			"id": "%s_host" % placement_id,
			"name": "Assault Host",
			"stacks": [{"unit_id": "unit_bog_brute", "count": brute_count}],
		},
	}
	if with_commander:
		raid["enemy_commander_state"] = EnemyAdventureRules.build_raid_commander_state(
			raid,
			roster_hero_id,
			MIRECLAW,
			session,
			{},
			EnemyAdventureRules.commander_roster_for_faction(session, MIRECLAW)
		)
	var plan := EnemyAdventureRules.ai_live_town_retake_target_selection_plan(session, config, raid)
	if String(plan.get("target_kind", "")) != "town" or String(plan.get("target_placement_id", "")) != TOWN_ID:
		_fail("Retake target plan did not prefer %s for %s: %s" % [TOWN_ID, placement_id, JSON.stringify(plan)])
		return raid
	raid.merge(plan, true)
	return EnemyAdventureRules.ensure_raid_army(raid, session) if with_commander else raid

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

func _seed_active_town_task(session, actor_id: String, origin_id: String) -> void:
	var state := _enemy_state(session)
	state["hero_task_state"] = {
		"schema_version": 1,
		"planner_epoch": 4,
		"tasks": [
			{
				"task_id": "task:commander_grouping:%s:%s" % [actor_id, TOWN_ID],
				"owner_faction_id": MIRECLAW,
				"actor_kind": "commander_roster",
				"actor_id": actor_id,
				"source_kind": "saved_task_state",
				"source_id": origin_id,
				"task_class": "raid_town",
				"task_status": "active",
				"target_kind": "town",
				"target_id": TOWN_ID,
				"front_id": "town:%s" % TOWN_ID,
				"origin_kind": "encounter",
				"origin_id": origin_id,
				"priority_reason_codes": ["retake_front", "town_siege"],
				"assigned_day": int(session.day),
				"expires_day": int(session.day) + 7,
				"continuity_policy": "persist_until_invalid",
				"route_policy": "derive_route_on_turn",
				"last_validation": "valid",
				"reservation": {
					"reservation_status": "none",
					"reservation_scope": "none",
					"reservation_key": "",
				},
			}
		],
	}
	_update_enemy_state(session, state)

func _commander_entry(session, roster_hero_id: String) -> Dictionary:
	var state := _enemy_state(session)
	for entry in state.get("commander_roster", []):
		if entry is Dictionary and String(entry.get("roster_hero_id", "")) == roster_hero_id:
			return entry
	_fail("Could not find commander entry %s" % roster_hero_id)
	return {}

func _assert_task_completed(session, actor_id: String, target_kind: String, target_id: String) -> void:
	var state := _enemy_state(session)
	var task_state: Dictionary = state.get("hero_task_state", {}) if state.get("hero_task_state", {}) is Dictionary else {}
	for task in task_state.get("tasks", []):
		if not (task is Dictionary):
			continue
		if String(task.get("actor_id", "")) == actor_id and String(task.get("target_kind", "")) == target_kind and String(task.get("target_id", "")) == target_id:
			if String(task.get("task_status", "")) != "completed" or String(task.get("last_validation", "")) != "valid":
				_fail("Grouped commander task expected completed/valid, got %s" % JSON.stringify(task))
			return
	_fail("Could not find grouped commander task for %s/%s/%s in %s" % [actor_id, target_kind, target_id, JSON.stringify(task_state)])

func _set_player_captured_retake_front(session, placement_id: String) -> void:
	var towns: Array = session.overworld.get("towns", [])
	for index in range(towns.size()):
		var town = towns[index]
		if not (town is Dictionary) or String(town.get("placement_id", "")) != placement_id:
			continue
		town["owner"] = "player"
		town["front"] = {
			"state": "retake",
			"faction_id": MIRECLAW,
			"last_change_day": int(session.day),
			"stabilize_until_day": 0,
			"last_owner": "enemy",
			"capture_count": 1,
			"source": "test_fixture",
		}
		towns[index] = town
		session.overworld["towns"] = towns
		return
	_fail("Could not find town %s for retake-front fixture." % placement_id)

func _encounter(session, placement_id: String) -> Dictionary:
	for encounter in session.overworld.get("encounters", []):
		if encounter is Dictionary and String(encounter.get("placement_id", "")) == placement_id:
			return encounter
	return {}

func _active_raid_count(session) -> int:
	var resolved: Array = session.overworld.get("resolved_encounters", []) if session.overworld.get("resolved_encounters", []) is Array else []
	var count := 0
	for encounter in session.overworld.get("encounters", []):
		if not (encounter is Dictionary):
			continue
		if String(encounter.get("spawned_by_faction_id", "")) != MIRECLAW:
			continue
		if String(encounter.get("placement_id", "")) in resolved:
			continue
		count += 1
	return count

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

func _assert_saved_task_state(session) -> void:
	for state in session.overworld.get("enemy_states", []):
		if state is Dictionary and String(state.get("faction_id", "")) == MIRECLAW and state.has("hero_task_state"):
			return
	_fail("Grouping did not persist hero_task_state.")

func _public_event_leaks(public_events: Variant) -> bool:
	var forbidden_tokens := ["target_debug_reason", "hero_task_state", "task_id", "reservation_key", "garrison_score", "raid_score", "grouped_into"]
	var encoded := JSON.stringify(public_events)
	for token in forbidden_tokens:
		if encoded.find(token) >= 0:
			_fail("Grouping public events leaked internal token %s" % token)
			return true
	return false

func _fail(message: String) -> void:
	var payload := {"ok": false, "report_id": REPORT_ID, "error": message}
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	_failed = true
	get_tree().quit(1)
