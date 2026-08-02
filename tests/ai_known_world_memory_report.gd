extends Node

const REPORT_ID := "AI_KNOWN_WORLD_MEMORY_REPORT"
const RIVER_PASS := "river-pass"
const MIRECLAW := "faction_mireclaw"
const EMBERCOURT := "faction_embercourt"

var _failed := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var preservation_case := _known_world_memory_survives_normalization()
	if preservation_case.is_empty():
		return
	var sighting_case := _hero_targets_require_ai_sighting()
	if sighting_case.is_empty():
		return
	var empty_fallback_case := _empty_target_fallback_does_not_hunt_hidden_hero()
	if empty_fallback_case.is_empty():
		return
	var nonhero_case := _nonhero_targets_require_visibility_or_memory()
	if nonhero_case.is_empty():
		return
	var delivery_case := _convoy_interception_requires_known_route_and_hero()
	if delivery_case.is_empty():
		return
	var ordinary_scouting_case := _ordinary_scouting_records_nonhero_memory()
	if ordinary_scouting_case.is_empty():
		return
	var neutral_town_case := _neutral_towns_require_visibility_or_memory()
	if neutral_town_case.is_empty():
		return
	var persistent_exploration_case := _persistent_exploration_tasks_launch_and_complete()
	if persistent_exploration_case.is_empty():
		return
	var exclusive_frontier_case := _exclusive_frontier_reservations_diversify_live_hosts()
	if exclusive_frontier_case.is_empty():
		return
	var rebuild_relaunch_case := _rebuild_relaunch_preserves_frontier_history()
	if rebuild_relaunch_case.is_empty():
		return
	var exploration_case := _exploration_arrival_reassigns_visible_resource()
	if exploration_case.is_empty():
		return
	var post_move_scouting_case := _moving_exploration_refreshes_memory_before_same_turn_retarget()
	if post_move_scouting_case.is_empty():
		return
	var hero_route_occupancy_case := _nonhero_route_avoids_player_hero_occupied_tile()
	if hero_route_occupancy_case.is_empty():
		return
	var faction_scoped_route_case := _hero_route_occupancy_uses_moving_faction_sight()
	if faction_scoped_route_case.is_empty():
		return
	var assignment_route_case := _target_assignment_respects_faction_scoped_route_occupancy()
	if assignment_route_case.is_empty():
		return
	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"schema_status": "strategic_ai_known_world_memory_live_behavior",
		"behavior_policy": "enemy_pressure_uses_current_or_recent_ai_sightings_known_world_memory_post_move_scouting_and_faction_scoped_player_hero_route_occupancy_for_movement_and_assignment",
		"save_policy": "known_world_memory_live_persist_no_save_migration",
		"cases": [preservation_case, sighting_case, empty_fallback_case, nonhero_case, delivery_case, ordinary_scouting_case, neutral_town_case, persistent_exploration_case, exclusive_frontier_case, rebuild_relaunch_case, exploration_case, post_move_scouting_case, hero_route_occupancy_case, faction_scoped_route_case, assignment_route_case],
		"save_version_before": int(SessionStateStore.SAVE_VERSION),
		"save_version_after": int(SessionStateStore.SAVE_VERSION),
	}
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _known_world_memory_survives_normalization() -> Dictionary:
	var session = _base_session()
	_patch_enemy_memory(
		session,
		{
			"schema_version": 1,
			"scouted_targets": [
				{
					"target_kind": "resource",
					"target_id": "river_free_company",
					"target_label": "Riverwatch Free Company Yard",
					"x": 0,
					"y": 4,
					"scouted_day": int(session.day),
					"expires_day": int(session.day) + 3,
					"source_spell_id": "spell_far_glass",
				}
			],
			"player_hero_sightings": [
				{
					"hero_id": "hero_lyra",
					"hero_label": "Lyra",
					"x": 0,
					"y": 4,
					"army_strength": 96,
					"seen_day": int(session.day),
					"expires_day": int(session.day) + 2,
					"source_kind": "town",
					"source_id": "duskfen_bastion",
				}
			],
		}
	)
	EnemyTurnRules.normalize_enemy_states(session)
	var memory := _enemy_memory(session)
	var scouted: Array = memory.get("scouted_targets", []) if memory.get("scouted_targets", []) is Array else []
	var sightings: Array = memory.get("player_hero_sightings", []) if memory.get("player_hero_sightings", []) is Array else []
	if scouted.is_empty() or sightings.is_empty():
		_fail("Enemy state normalization dropped known_world_memory: %s" % JSON.stringify(memory))
		return {}
	return {
		"case_id": "known_world_memory_survives_normalization",
		"scouted_target_count": scouted.size(),
		"hero_sighting_count": sightings.size(),
		"hero_sighting_position": {"x": int(sightings[0].get("x", -1)), "y": int(sightings[0].get("y", -1))},
	}

func _hero_targets_require_ai_sighting() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config()
	_set_primary_hero_position(session, 0, 4)
	var hidden_candidates := EnemyAdventureRules._hero_target_candidates(session, Vector2i(7, 2), config, MIRECLAW)
	if not hidden_candidates.is_empty():
		_fail("Hidden player hero should not become a hero target without AI sighting memory: %s" % JSON.stringify(hidden_candidates))
		return {}
	_set_primary_hero_position(session, 5, 2)
	var memory_result := EnemyAdventureRules.refresh_enemy_known_world_memory(session, config, _enemy_state(session))
	_update_enemy_state(session, memory_result.get("state", _enemy_state(session)))
	var visible_candidates := EnemyAdventureRules._hero_target_candidates(session, Vector2i(7, 2), config, MIRECLAW)
	if visible_candidates.is_empty():
		_fail("Currently sighted player hero did not become eligible for hero pressure.")
		return {}
	_set_primary_hero_position(session, 0, 4)
	var remembered_candidates := EnemyAdventureRules._hero_target_candidates(session, Vector2i(7, 2), config, MIRECLAW)
	if remembered_candidates.is_empty():
		_fail("Recent remembered player hero sighting did not remain eligible for hero pressure.")
		return {}
	var remembered: Dictionary = remembered_candidates[0]
	if int(remembered.get("target_x", -1)) != 5 or int(remembered.get("target_y", -1)) != 2:
		_fail("Remembered hero target used live hidden position instead of remembered sighting: %s" % JSON.stringify(remembered))
		return {}
	return {
		"case_id": "hero_targets_require_ai_sighting",
		"hidden_candidate_count": hidden_candidates.size(),
		"visible_candidate_count": visible_candidates.size(),
		"remembered_target": {
			"target_id": String(remembered.get("target_placement_id", "")),
			"x": int(remembered.get("target_x", -1)),
			"y": int(remembered.get("target_y", -1)),
		},
		"sighting_count": int(memory_result.get("sighting_count", 0)),
	}

func _empty_target_fallback_does_not_hunt_hidden_hero() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config()
	_set_primary_hero_position(session, 0, 12)
	_make_no_known_targets_session(session)
	var origin := {"x": 7, "y": 2}
	var chosen := EnemyAdventureRules.choose_target(session, config, origin, {})
	if chosen.is_empty():
		_fail("No-candidate target fallback should produce an exploration or regroup plan.")
		return {}
	if String(chosen.get("target_kind", "")) == "hero":
		_fail("No-candidate target fallback used hidden active hero coordinates: %s" % JSON.stringify(chosen))
		return {}
	if String(chosen.get("target_kind", "")) != "explore":
		_fail("No-candidate target fallback should scout reachable frontier before passive regroup, got %s" % JSON.stringify(chosen))
		return {}
	if "no_known_targets" not in _normalize_string_array(chosen.get("target_reason_codes", [])):
		_fail("No-candidate exploration fallback did not explain no_known_targets: %s" % JSON.stringify(chosen))
		return {}
	var state := _enemy_state(session)
	state["pressure"] = 999
	_update_enemy_state(session, state)
	if not EnemyTurnRules._can_launch_raid(session, config, state, MIRECLAW):
		_fail("Fresh pressure should launch an exploration commander when no legitimate target candidates exist.")
		return {}
	var turn_result := EnemyTurnRules.run_enemy_turn(session)
	var exploration_raid := _first_enemy_raid_for_kind(session, "explore")
	if exploration_raid.is_empty():
		_fail("Live enemy turn did not dispatch an exploration raid with no known targets: %s" % JSON.stringify(turn_result))
		return {}
	return {
		"case_id": "empty_target_fallback_does_not_hunt_hidden_hero",
		"fallback_target_kind": String(chosen.get("target_kind", "")),
		"fallback_target_id": String(chosen.get("target_placement_id", "")),
		"fallback_goal_distance": int(chosen.get("goal_distance", -1)),
		"pressure_launch_allowed_without_target": true,
		"live_exploration_raid_id": String(exploration_raid.get("placement_id", "")),
	}

func _nonhero_targets_require_visibility_or_memory() -> Dictionary:
	var session = _base_session()
	var config := _ordinary_target_config()
	_set_primary_hero_position(session, 0, 4)
	_make_hidden_resource_target_session(session)
	var origin := Vector2i(7, 2)
	var hidden_candidates := EnemyAdventureRules._target_candidates(session, config, origin)
	if _candidate_has_target(hidden_candidates, "resource", "river_free_company"):
		_fail("Hidden resource should not be targetable before current visibility or scouting memory: %s" % JSON.stringify(hidden_candidates))
		return {}
	var scoutable := EnemyAdventureRules._scoutable_target_candidates(session, config, MIRECLAW, origin, 20)
	if not _candidate_has_target(scoutable, "resource", "river_free_company"):
		_fail("Scouting discovery path should still see unknown nearby resources: %s" % JSON.stringify(scoutable))
		return {}
	_patch_enemy_memory(
		session,
		{
			"schema_version": 1,
			"scouted_targets": [
				{
					"target_kind": "resource",
					"target_id": "river_free_company",
					"target_label": "Riverwatch Free Company Yard",
					"x": 0,
					"y": 4,
					"scouted_day": int(session.day),
					"expires_day": int(session.day) + 3,
					"source_spell_id": "spell_far_glass",
				}
			],
		}
	)
	var known_candidates := EnemyAdventureRules._target_candidates(session, config, origin)
	if not _candidate_has_target(known_candidates, "resource", "river_free_company"):
		_fail("Scouted resource memory did not make resource targetable: %s" % JSON.stringify(known_candidates))
		return {}
	return {
		"case_id": "nonhero_targets_require_visibility_or_memory",
		"hidden_candidate_count": hidden_candidates.size(),
		"scoutable_unknown_resource": true,
		"known_resource_candidate": true,
		"known_world_target_id": "river_free_company",
	}

func _convoy_interception_requires_known_route_and_hero() -> Dictionary:
	var session = _base_session()
	var config := _ordinary_target_config()
	var hero_id := String(session.overworld.get("active_hero_id", "hero_lyra"))
	_set_primary_hero_position(session, 0, 4)
	_make_hidden_hero_delivery_session(session, hero_id)
	var origin := Vector2i(7, 2)
	var hidden_candidates := EnemyAdventureRules._target_candidates(session, config, origin)
	if not _first_delivery_candidate(hidden_candidates, "hero", hero_id).is_empty():
		_fail("Hidden convoy route should not be targetable before route source memory: %s" % JSON.stringify(hidden_candidates))
		return {}

	_patch_enemy_memory(
		session,
		{
			"schema_version": 1,
			"scouted_targets": [
				{
					"target_kind": "resource",
					"target_id": "river_free_company",
					"target_label": "Riverwatch Free Company Yard",
					"x": 0,
					"y": 4,
					"scouted_day": int(session.day),
					"expires_day": int(session.day) + 3,
					"source_spell_id": "spell_far_glass",
				}
			],
			"player_hero_sightings": [],
		}
	)
	var source_only_candidates := EnemyAdventureRules._target_candidates(session, config, origin)
	if not _first_delivery_candidate(source_only_candidates, "hero", hero_id).is_empty():
		_fail("Known convoy source should not reveal a hidden hero endpoint: %s" % JSON.stringify(source_only_candidates))
		return {}

	_patch_enemy_memory(
		session,
		{
			"schema_version": 1,
			"scouted_targets": [
				{
					"target_kind": "resource",
					"target_id": "river_free_company",
					"target_label": "Riverwatch Free Company Yard",
					"x": 0,
					"y": 4,
					"scouted_day": int(session.day),
					"expires_day": int(session.day) + 3,
					"source_spell_id": "spell_far_glass",
				}
			],
			"player_hero_sightings": [
				{
					"hero_id": hero_id,
					"hero_label": "Lyra",
					"x": 5,
					"y": 2,
					"army_strength": 96,
					"seen_day": int(session.day),
					"expires_day": int(session.day) + 2,
					"source_kind": "town",
					"source_id": "duskfen_bastion",
				}
			],
		}
	)
	var known_candidates := EnemyAdventureRules._target_candidates(session, config, origin)
	var delivery_candidate := _first_delivery_candidate(known_candidates, "hero", hero_id)
	if delivery_candidate.is_empty():
		_fail("Known convoy source plus remembered hero endpoint did not create delivery interception: %s" % JSON.stringify(known_candidates))
		return {}
	if int(delivery_candidate.get("target_x", -1)) != 5 or int(delivery_candidate.get("target_y", -1)) != 2:
		_fail("Hero-bound convoy interception used live hidden position instead of remembered hero sighting: %s" % JSON.stringify(delivery_candidate))
		return {}
	return {
		"case_id": "convoy_interception_requires_known_route_and_hero",
		"hidden_delivery_candidate": false,
		"source_only_delivery_candidate": false,
		"known_delivery_target": {
			"target_kind": String(delivery_candidate.get("target_kind", "")),
			"target_id": String(delivery_candidate.get("target_placement_id", "")),
			"x": int(delivery_candidate.get("target_x", -1)),
			"y": int(delivery_candidate.get("target_y", -1)),
		},
	}

func _ordinary_scouting_records_nonhero_memory() -> Dictionary:
	var session = _base_session()
	var config := _ordinary_target_config()
	_set_primary_hero_position(session, 0, 4)
	_make_hidden_resource_target_session(session)
	var origin := Vector2i(7, 2)
	var hidden_candidates := EnemyAdventureRules._target_candidates(session, config, origin)
	if _candidate_has_target(hidden_candidates, "resource", "river_free_company"):
		_fail("Hidden resource should not be targetable before ordinary scout sight: %s" % JSON.stringify(hidden_candidates))
		return {}
	_add_exploration_raid(session, 0, 4)
	var memory_result := EnemyAdventureRules.refresh_enemy_known_world_memory(session, config, _enemy_state(session))
	_update_enemy_state(session, memory_result.get("state", _enemy_state(session)))
	var record := _memory_target_record(session, "resource", "river_free_company")
	if record.is_empty():
		_fail("Ordinary commander sight did not record visible resource target memory: %s" % JSON.stringify(_enemy_memory(session)))
		return {}
	if String(record.get("source_kind", "")) != "commander":
		_fail("Ordinary scout record should preserve commander source kind: %s" % JSON.stringify(record))
		return {}
	if String(record.get("source_spell_id", "")) != "":
		_fail("Ordinary scout record should not masquerade as spell scouting: %s" % JSON.stringify(record))
		return {}
	session.overworld["encounters"] = []
	session.overworld["resolved_encounters"] = []
	var remembered_candidates := EnemyAdventureRules._target_candidates(session, config, origin)
	if not _candidate_has_target(remembered_candidates, "resource", "river_free_company"):
		_fail("Ordinary scout memory did not keep the resource targetable after the scout moved away: %s" % JSON.stringify(remembered_candidates))
		return {}
	return {
		"case_id": "ordinary_scouting_records_nonhero_memory",
		"hidden_candidate_count": hidden_candidates.size(),
		"scouted_target_count": int(memory_result.get("scouted_target_count", 0)),
		"source_kind": String(record.get("source_kind", "")),
		"source_id": String(record.get("source_id", "")),
		"remembered_resource_candidate": true,
	}

func _neutral_towns_require_visibility_or_memory() -> Dictionary:
	var session = _base_session()
	var config := _ordinary_target_config()
	_set_primary_hero_position(session, 0, 12)
	_make_hidden_neutral_town_session(session)
	var origin := Vector2i(7, 2)
	var hidden_candidates := EnemyAdventureRules._target_candidates(session, config, origin)
	if _candidate_has_target(hidden_candidates, "town", "hidden_neutral_hold"):
		_fail("Hidden neutral town should not be targetable before current visibility or scouting memory: %s" % JSON.stringify(hidden_candidates))
		return {}
	var scoutable := EnemyAdventureRules._scoutable_target_candidates(session, config, MIRECLAW, origin, 20)
	if not _candidate_has_target(scoutable, "town", "hidden_neutral_hold"):
		_fail("Scouting discovery path should still see unknown neutral towns: %s" % JSON.stringify(scoutable))
		return {}
	_patch_enemy_memory(
		session,
		{
			"schema_version": 1,
			"scouted_targets": [
				{
					"target_kind": "town",
					"target_id": "hidden_neutral_hold",
					"target_label": "Hidden Neutral Hold",
					"x": 0,
					"y": 4,
					"scouted_day": int(session.day),
					"expires_day": int(session.day) + 3,
					"source_spell_id": "spell_far_glass",
				}
			],
		}
	)
	var known_candidates := EnemyAdventureRules._target_candidates(session, config, origin)
	if not _candidate_has_target(known_candidates, "town", "hidden_neutral_hold"):
		_fail("Scouted neutral-town memory did not make the town targetable: %s" % JSON.stringify(known_candidates))
		return {}
	return {
		"case_id": "neutral_towns_require_visibility_or_memory",
		"hidden_candidate_count": hidden_candidates.size(),
		"scoutable_unknown_neutral_town": true,
		"known_neutral_town_candidate": true,
		"known_world_target_id": "hidden_neutral_hold",
	}

func _persistent_exploration_tasks_launch_and_complete() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config()
	_set_primary_hero_position(session, 0, 12)
	_make_no_known_targets_session(session)
	var state := _enemy_state(session)
	var plan_result := EnemyAdventureRules.plan_enemy_hero_task_board(session, config, state)
	_update_enemy_state(session, plan_result.get("state", _enemy_state(session)))
	var scout_task := _first_task_for_kind(session, "explore")
	if scout_task.is_empty():
		_fail("No-known-target strategic planner should create a persistent exploration task: %s" % JSON.stringify(plan_result))
		return {}
	if String(scout_task.get("task_class", "")) != "scout_frontier":
		_fail("Exploration task should use scout_frontier class: %s" % JSON.stringify(scout_task))
		return {}
	var task_target_id := String(scout_task.get("target_id", ""))
	state = _enemy_state(session)
	state["pressure"] = 999
	_update_enemy_state(session, state)
	var turn_result := EnemyTurnRules.run_enemy_turn(session)
	var exploration_raid := _first_enemy_raid_for_kind(session, "explore")
	if exploration_raid.is_empty():
		_fail("Saved exploration task did not launch an exploration raid: %s" % JSON.stringify(turn_result))
		return {}
	var launched_task := _first_task_for_target(session, "explore", String(exploration_raid.get("target_placement_id", "")))
	if launched_task.is_empty() or String(launched_task.get("task_class", "")) != "scout_frontier":
		_fail("Exploration raid did not launch from a saved scout task: planned=%s raid=%s" % [JSON.stringify(_task_state(session)), JSON.stringify(exploration_raid)])
		return {}
	task_target_id = String(exploration_raid.get("target_placement_id", ""))
	var target_tile := _explore_target_tile(task_target_id)
	if target_tile.is_empty():
		_fail("Exploration task target id did not encode a tile: %s" % task_target_id)
		return {}
	if int(exploration_raid.get("target_x", -1)) != int(target_tile.get("x", -2)) or int(exploration_raid.get("target_y", -1)) != int(target_tile.get("y", -2)):
		_fail("Exploration raid lost saved target coordinates during spawn: %s" % JSON.stringify(exploration_raid))
		return {}
	_move_raid_to_target(session, String(exploration_raid.get("placement_id", "")), int(target_tile.get("x", 0)), int(target_tile.get("y", 0)))
	var arrival_result := EnemyAdventureRules.advance_raids(session, config, MIRECLAW, _enemy_state(session))
	_update_enemy_state(session, arrival_result.get("state", _enemy_state(session)))
	var completed_task := _task_by_id(session, String(launched_task.get("task_id", "")))
	if String(completed_task.get("task_status", "")) != "completed":
		_fail("Exploration arrival did not complete the saved scout task: %s" % JSON.stringify(completed_task))
		return {}
	var reservation: Dictionary = completed_task.get("reservation", {}) if completed_task.get("reservation", {}) is Dictionary else {}
	if String(reservation.get("reservation_status", "")) != "released":
		_fail("Completed exploration task did not release its reservation: %s" % JSON.stringify(completed_task))
		return {}
	var continued_raid := _encounter_by_id(session, String(exploration_raid.get("placement_id", "")))
	if continued_raid.is_empty():
		_fail("Exploration commander disappeared after completing an empty scout tile: %s" % JSON.stringify(session.overworld.get("encounters", [])))
		return {}
	if String(continued_raid.get("target_kind", "")) == "explore" and String(continued_raid.get("target_placement_id", "")) == task_target_id:
		_fail("Exploration commander stayed on the completed scout tile instead of continuing: %s" % JSON.stringify(continued_raid))
		return {}
	var recent_exploration_target_ids: Array = continued_raid.get("recent_exploration_target_ids", []) if continued_raid.get("recent_exploration_target_ids", []) is Array else []
	if task_target_id not in recent_exploration_target_ids:
		_fail("Exploration host did not retain its completed frontier target: %s" % JSON.stringify(continued_raid))
		return {}

	var planner_session = _base_session()
	_set_primary_hero_position(planner_session, 0, 12)
	_make_no_known_targets_session(planner_session)
	var planner_origin := Vector2i(7, 2)
	var first_plan := EnemyAdventureRules._no_known_target_frontier_sweep_plan(planner_session, config, planner_origin)
	var first_plan_id := String(first_plan.get("target_placement_id", ""))
	var second_plan := EnemyAdventureRules._no_known_target_frontier_sweep_plan(
		planner_session,
		config,
		planner_origin,
		{"recent_exploration_target_ids": [first_plan_id]}
	)
	var second_plan_id := String(second_plan.get("target_placement_id", ""))
	if first_plan.is_empty() or second_plan.is_empty() or second_plan_id == first_plan_id:
		_fail("Frontier planner did not advance beyond its most recent completed target: first=%s second=%s" % [JSON.stringify(first_plan), JSON.stringify(second_plan)])
		return {}
	var third_plan := EnemyAdventureRules._no_known_target_frontier_sweep_plan(
		planner_session,
		config,
		planner_origin,
		{"recent_exploration_target_ids": [first_plan_id, second_plan_id]}
	)
	var third_plan_id := String(third_plan.get("target_placement_id", ""))
	if not third_plan.is_empty() and third_plan_id in [first_plan_id, second_plan_id]:
		_fail("Frontier planner alternated back to a completed target: first=%s second=%s third=%s" % [first_plan_id, second_plan_id, third_plan_id])
		return {}
	return {
		"case_id": "persistent_exploration_tasks_launch_and_complete",
		"planned_count": int(plan_result.get("planned_count", 0)),
		"task_class": String(launched_task.get("task_class", "")),
		"task_target_id": task_target_id,
		"spawned_raid_id": String(exploration_raid.get("placement_id", "")),
		"spawned_target_x": int(exploration_raid.get("target_x", -1)),
		"spawned_target_y": int(exploration_raid.get("target_y", -1)),
		"completed_task_status": String(completed_task.get("task_status", "")),
		"continued_target_id": String(continued_raid.get("target_placement_id", "")),
		"recent_exploration_target_ids": recent_exploration_target_ids,
		"planner_target_sequence": [first_plan_id, second_plan_id, third_plan_id],
		"event_types": _event_types(arrival_result.get("events", [])),
	}

func _exclusive_frontier_reservations_diversify_live_hosts() -> Dictionary:
	var session = _base_session()
	var config := _ordinary_target_config()
	_set_primary_hero_position(session, 0, 12)
	_make_no_known_targets_session(session)
	var first_plan := EnemyAdventureRules._no_known_target_frontier_sweep_plan(session, config, Vector2i(7, 2))
	if first_plan.is_empty():
		_fail("Exclusive frontier fixture could not produce its first reachable target.")
		return {}
	var first_raid := _frontier_reservation_raid(session, "frontier_reservation_host_1", "hero_vaska", 7, 2, first_plan)
	var second_raid := _frontier_reservation_raid(session, "frontier_reservation_host_2", "hero_zhorra", 8, 2, {})
	session.overworld["encounters"] = [first_raid, second_raid]
	var same_origin_frontier_plan := EnemyAdventureRules._no_known_target_frontier_sweep_plan(
		session,
		config,
		Vector2i(7, 2),
		second_raid
	)
	if same_origin_frontier_plan.is_empty() or String(same_origin_frontier_plan.get("target_placement_id", "")) == String(first_plan.get("target_placement_id", "")):
		_fail("Frontier fallback reused another live host's exclusive target: first=%s second=%s" % [JSON.stringify(first_plan), JSON.stringify(same_origin_frontier_plan)])
		return {}
	second_raid = EnemyAdventureRules.assign_target(session, config, second_raid)
	if String(second_raid.get("target_kind", "")) != "explore":
		_fail("Second no-objective host did not receive a frontier assignment: %s" % JSON.stringify(second_raid))
		return {}
	if String(second_raid.get("target_placement_id", "")) == String(first_raid.get("target_placement_id", "")):
		_fail("Live frontier hosts received the same exclusive target: %s" % JSON.stringify([first_raid, second_raid]))
		return {}
	var encounters: Array = session.overworld.get("encounters", [])
	encounters[1] = second_raid
	session.overworld["encounters"] = encounters
	var starts := {
		String(first_raid.get("placement_id", "")): Vector2i(int(first_raid.get("x", 0)), int(first_raid.get("y", 0))),
		String(second_raid.get("placement_id", "")): Vector2i(int(second_raid.get("x", 0)), int(second_raid.get("y", 0))),
	}
	var result := EnemyAdventureRules.advance_raids(session, config, MIRECLAW, _enemy_state(session))
	_update_enemy_state(session, result.get("state", _enemy_state(session)))
	var first_after := _encounter_by_id(session, String(first_raid.get("placement_id", "")))
	var second_after := _encounter_by_id(session, String(second_raid.get("placement_id", "")))
	for moved_raid in [first_after, second_after]:
		var placement_id := String(moved_raid.get("placement_id", ""))
		var start: Vector2i = starts.get(placement_id, Vector2i(-1, -1))
		var finish := Vector2i(int(moved_raid.get("x", -1)), int(moved_raid.get("y", -1)))
		if moved_raid.is_empty() or finish == start:
			_fail("Exclusive frontier host did not advance toward its distinct target: %s" % JSON.stringify(moved_raid))
			return {}
	return {
		"case_id": "exclusive_frontier_reservations_diversify_live_hosts",
		"first_target_id": String(first_raid.get("target_placement_id", "")),
		"second_target_id": String(second_raid.get("target_placement_id", "")),
		"first_after": {"x": int(first_after.get("x", -1)), "y": int(first_after.get("y", -1))},
		"second_after": {"x": int(second_after.get("x", -1)), "y": int(second_after.get("y", -1))},
		"event_types": _event_types(result.get("events", [])),
	}

func _rebuild_relaunch_preserves_frontier_history() -> Dictionary:
	var session = _base_session()
	session.day = 2
	var config := _ordinary_target_config()
	_set_primary_hero_position(session, 0, 12)
	_make_no_known_targets_session(session)
	var spawn_point := {"placement_id": "rebuild_frontier_origin", "x": 7, "y": 2}
	var first_plan := EnemyTurnRules._rebuild_pressure_exploration_plan(
		session,
		config,
		MIRECLAW,
		spawn_point
	)
	var first_target_id := String(first_plan.get("target_placement_id", ""))
	if first_plan.is_empty() or not first_target_id.begins_with("explore:"):
		_fail("Rebuild relaunch fixture did not produce an initial frontier target: %s" % JSON.stringify(first_plan))
		return {}
	var state := _enemy_state(session)
	state["recent_rebuild_exploration_target_ids"] = [first_target_id]
	state["rebuild_pressure_request"] = {
		"requested_day": int(session.day),
		"origin_town_id": "duskfen_bastion",
		"commander_id": "hero_vaska",
		"reason": "no_spare_garrison_after_regroup",
		"recent_exploration_target_ids": [],
	}
	_update_enemy_state(session, state)
	var second_plan := EnemyTurnRules._rebuild_pressure_exploration_plan(
		session,
		config,
		MIRECLAW,
		spawn_point
	)
	var second_target_id := String(second_plan.get("target_placement_id", ""))
	if second_plan.is_empty() or second_target_id == first_target_id:
		_fail("Rebuild relaunch repeated the exhausted faction frontier target: first=%s second=%s" % [JSON.stringify(first_plan), JSON.stringify(second_plan)])
		return {}
	var carried_history := _normalize_string_array(second_plan.get("recent_exploration_target_ids", []))
	if first_target_id not in carried_history:
		_fail("Rebuild relaunch plan dropped faction frontier history: %s" % JSON.stringify(second_plan))
		return {}
	var candidate := EnemyTurnRules._spawn_point_candidate_from_plan(
		spawn_point,
		second_plan,
		"hero_vaska",
		"rebuild_pressure_recon",
		0
	)
	if first_target_id not in _normalize_string_array(candidate.get("recent_exploration_target_ids", [])):
		_fail("Rebuild spawn candidate dropped faction frontier history: %s" % JSON.stringify(candidate))
		return {}
	return {
		"case_id": "rebuild_relaunch_preserves_faction_frontier_history",
		"first_target_id": first_target_id,
		"second_target_id": second_target_id,
		"carried_history": carried_history,
	}

func _exploration_arrival_reassigns_visible_resource() -> Dictionary:
	var session = _base_session()
	var config := _ordinary_target_config()
	_set_primary_hero_position(session, 0, 12)
	_make_hidden_resource_target_session(session)
	_add_exploration_raid(session, 5, 4)
	var state := _enemy_state(session)
	var result := EnemyAdventureRules.advance_raids(session, config, MIRECLAW, state)
	_update_enemy_state(session, result.get("state", _enemy_state(session)))
	var reassigned := _first_enemy_raid_for_kind(session, "resource")
	if reassigned.is_empty():
		_fail("Exploration arrival did not reassign to newly visible resource: %s" % JSON.stringify(result))
		return {}
	if String(reassigned.get("target_placement_id", "")) != "river_free_company":
		_fail("Exploration arrival reassigned to wrong resource: %s" % JSON.stringify(reassigned))
		return {}
	return {
		"case_id": "exploration_arrival_reassigns_visible_resource",
		"exploration_origin": {"x": 5, "y": 4},
		"reassigned_target_kind": String(reassigned.get("target_kind", "")),
		"reassigned_target_id": String(reassigned.get("target_placement_id", "")),
		"event_types": _event_types(result.get("events", [])),
	}

func _moving_exploration_refreshes_memory_before_same_turn_retarget() -> Dictionary:
	var session = _base_session()
	var config := _ordinary_target_config()
	_set_primary_hero_position(session, 0, 12)
	_make_hidden_resource_target_session(session)
	_add_moving_exploration_raid(session, 6, 4, 5, 4)
	if not _memory_target_record(session, "resource", "river_free_company").is_empty():
		_fail("Post-move scouting fixture should start without resource memory: %s" % JSON.stringify(_enemy_memory(session)))
		return {}
	var result := EnemyAdventureRules.advance_raids(session, config, MIRECLAW, _enemy_state(session))
	_update_enemy_state(session, result.get("state", _enemy_state(session)))
	var record := _memory_target_record(session, "resource", "river_free_company")
	if record.is_empty():
		_fail("Moving exploration commander did not refresh newly reached sight line before same-turn retarget: %s" % JSON.stringify(result))
		return {}
	if String(record.get("source_kind", "")) != "commander":
		_fail("Post-move scout memory should use commander source kind: %s" % JSON.stringify(record))
		return {}
	if String(record.get("source_id", "")) != "known_world_moving_exploration_probe":
		_fail("Post-move scout memory should use the moved commander source id: %s" % JSON.stringify(record))
		return {}
	var reassigned := _first_enemy_raid_for_kind(session, "resource")
	if reassigned.is_empty():
		_fail("Moving exploration commander did not retarget newly visible resource in the same advance: %s" % JSON.stringify(session.overworld.get("encounters", [])))
		return {}
	if String(reassigned.get("target_placement_id", "")) != "river_free_company":
		_fail("Moving exploration commander retargeted the wrong post-move sight target: %s" % JSON.stringify(reassigned))
		return {}
	return {
		"case_id": "moving_exploration_refreshes_memory_before_same_turn_retarget",
		"start": {"x": 6, "y": 4},
		"post_move": {"x": int(reassigned.get("x", -1)), "y": int(reassigned.get("y", -1))},
		"memory_source_kind": String(record.get("source_kind", "")),
		"memory_source_id": String(record.get("source_id", "")),
		"reassigned_target_kind": String(reassigned.get("target_kind", "")),
		"reassigned_target_id": String(reassigned.get("target_placement_id", "")),
		"event_types": _event_types(result.get("events", [])),
	}

func _nonhero_route_avoids_player_hero_occupied_tile() -> Dictionary:
	var session = _base_session()
	var config := _ordinary_target_config()
	_make_hidden_resource_target_session(session)
	_set_primary_hero_position(session, 5, 4)
	_add_resource_route_raid(session, 6, 4, "river_free_company")
	var result := EnemyAdventureRules.advance_raids(session, config, MIRECLAW, _enemy_state(session))
	_update_enemy_state(session, result.get("state", _enemy_state(session)))
	var raid := _encounter_by_id(session, "known_world_resource_route_probe")
	if raid.is_empty():
		_fail("Resource route occupancy fixture lost the route probe: %s" % JSON.stringify(result))
		return {}
	if int(raid.get("x", -1)) == 5 and int(raid.get("y", -1)) == 4:
		_fail("Non-hero AI route stepped onto a live player hero tile: %s" % JSON.stringify(raid))
		return {}
	if String(raid.get("target_kind", "")) != "resource" or String(raid.get("target_placement_id", "")) != "river_free_company":
		_fail("Route occupancy fixture should stay on protected resource objective, got %s" % JSON.stringify(raid))
		return {}
	return {
		"case_id": "nonhero_route_avoids_player_hero_occupied_tile",
		"start": {"x": 6, "y": 4},
		"blocked_hero_tile": {"x": 5, "y": 4},
		"after_move": {"x": int(raid.get("x", -1)), "y": int(raid.get("y", -1))},
		"target_kind": String(raid.get("target_kind", "")),
		"target_id": String(raid.get("target_placement_id", "")),
		"event_types": _event_types(result.get("events", [])),
	}

func _hero_route_occupancy_uses_moving_faction_sight() -> Dictionary:
	var session = _base_session()
	_make_faction_scoped_route_corridor(session)
	var start := Vector2i(12, 4)
	var goal := [Vector2i(0, 4)]
	var mire_distance := EnemyAdventureRules._path_distance(session, start, goal, "", MIRECLAW)
	var ember_distance := EnemyAdventureRules._path_distance(session, start, goal, "", EMBERCOURT)
	if mire_distance >= 9999:
		_fail("Mireclaw should not route around a player hero only visible to another faction. distances mire=%d ember=%d" % [mire_distance, ember_distance])
		return {}
	if ember_distance < 9999:
		_fail("Same-faction sighted player hero should block the one-lane route for Embercourt. distances mire=%d ember=%d" % [mire_distance, ember_distance])
		return {}
	return {
		"case_id": "hero_route_occupancy_uses_moving_faction_sight",
		"hero_tile": {"x": 6, "y": 4},
		"route_start": {"x": start.x, "y": start.y},
		"route_goal": {"x": 0, "y": 4},
		"mireclaw_distance": mire_distance,
		"embercourt_distance": ember_distance,
	}

func _target_assignment_respects_faction_scoped_route_occupancy() -> Dictionary:
	var session = _base_session()
	_make_faction_scoped_route_corridor(session)
	_add_corridor_resource_target(session)
	var mire_config := _priority_target_config(MIRECLAW, "river_free_company")
	var ember_config := _priority_target_config(EMBERCOURT, "river_free_company")
	var mire_plan := EnemyAdventureRules.choose_target(
		session,
		mire_config,
		{"x": 12, "y": 4},
		{}
	)
	var ember_plan := EnemyAdventureRules.choose_target(
		session,
		ember_config,
		{"x": 12, "y": 4},
		{}
	)
	if String(mire_plan.get("target_kind", "")) != "resource" or String(mire_plan.get("target_placement_id", "")) != "river_free_company":
		_fail("Mireclaw assignment should keep the resource target when its faction cannot see the route-blocking hero: %s" % JSON.stringify(mire_plan))
		return {}
	if String(ember_plan.get("target_kind", "")) == "resource" and String(ember_plan.get("target_placement_id", "")) == "river_free_company":
		_fail("Embercourt assignment should not select a non-hero objective behind its visible hero blocker: %s" % JSON.stringify(ember_plan))
		return {}
	return {
		"case_id": "target_assignment_respects_faction_scoped_route_occupancy",
		"blocked_resource_id": "river_free_company",
		"mireclaw_target": "%s:%s" % [String(mire_plan.get("target_kind", "")), String(mire_plan.get("target_placement_id", ""))],
		"embercourt_target": "%s:%s" % [String(ember_plan.get("target_kind", "")), String(ember_plan.get("target_placement_id", ""))],
		"mireclaw_goal_distance": int(mire_plan.get("goal_distance", -1)),
		"embercourt_goal_distance": int(ember_plan.get("goal_distance", -1)),
	}

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

func _set_primary_hero_position(session, x: int, y: int) -> void:
	var hero: Dictionary = session.overworld.get("hero", {}).duplicate(true)
	hero["id"] = String(session.overworld.get("active_hero_id", "hero_lyra"))
	hero["name"] = String(hero.get("name", "Lyra"))
	hero["position"] = {"x": x, "y": y}
	session.overworld["hero"] = hero
	session.overworld["hero_position"] = {"x": x, "y": y}
	session.overworld["active_hero_id"] = String(hero.get("id", "hero_lyra"))
	session.overworld["player_heroes"] = [hero]

func _make_no_known_targets_session(session) -> void:
	var towns: Array = session.overworld.get("towns", [])
	for index in range(towns.size()):
		if not (towns[index] is Dictionary):
			continue
		var town: Dictionary = towns[index]
		if String(town.get("placement_id", "")) == "duskfen_bastion":
			town["owner"] = "enemy"
			town["controlling_faction_id"] = MIRECLAW
		else:
			town["owner"] = "inactive"
			town["controlling_faction_id"] = ""
		towns[index] = town
	session.overworld["towns"] = towns

	session.overworld["resource_nodes"] = []
	session.overworld["artifact_nodes"] = []
	session.overworld["encounters"] = []
	session.overworld["resolved_encounters"] = []
	_patch_enemy_memory(session, {"schema_version": 1, "player_hero_sightings": [], "scouted_targets": []})

func _make_hidden_resource_target_session(session) -> void:
	var towns: Array = session.overworld.get("towns", [])
	for index in range(towns.size()):
		if not (towns[index] is Dictionary):
			continue
		var town: Dictionary = towns[index]
		if String(town.get("placement_id", "")) == "duskfen_bastion":
			town["owner"] = "enemy"
			town["controlling_faction_id"] = MIRECLAW
		else:
			town["owner"] = "inactive"
			town["controlling_faction_id"] = ""
		towns[index] = town
	session.overworld["towns"] = towns

	var resources := []
	for node_value in session.overworld.get("resource_nodes", []):
		if not (node_value is Dictionary):
			continue
		var node: Dictionary = node_value
		if String(node.get("placement_id", "")) != "river_free_company":
			continue
		node["x"] = 0
		node["y"] = 4
		node["collected"] = true
		node["collected_by_faction_id"] = "player"
		node["response_until_day"] = 0
		node["response_security_rating"] = 0
		node["delivery_manifest"] = {}
		resources.append(node)
	session.overworld["resource_nodes"] = resources
	session.overworld["artifact_nodes"] = []
	session.overworld["encounters"] = []
	session.overworld["resolved_encounters"] = []
	_patch_enemy_memory(session, {"schema_version": 1, "player_hero_sightings": [], "scouted_targets": []})

func _make_faction_scoped_route_corridor(session) -> void:
	var map := []
	for y in range(9):
		var row := []
		for x in range(13):
			row.append("grass" if y == 4 else "rock")
		map.append(row)
	session.overworld["map"] = map
	session.overworld["map_size"] = {"width": 13, "height": 9}
	_set_primary_hero_position(session, 6, 4)
	session.overworld["resource_nodes"] = []
	session.overworld["artifact_nodes"] = []
	session.overworld["encounters"] = []
	session.overworld["resolved_encounters"] = []
	var towns := []
	towns.append({
		"placement_id": "mire_far_watch",
		"town_id": "town_duskfen",
		"name": "Mire Far Watch",
		"x": 12,
		"y": 8,
		"owner": "enemy",
		"controlling_faction_id": MIRECLAW,
		"garrison": [],
		"available_recruits": {},
		"buildings": [],
	})
	towns.append({
		"placement_id": "ember_near_watch",
		"town_id": "town_embercourt",
		"name": "Ember Near Watch",
		"x": 6,
		"y": 2,
		"owner": "enemy",
		"controlling_faction_id": EMBERCOURT,
		"garrison": [],
		"available_recruits": {},
		"buildings": [],
	})
	session.overworld["towns"] = towns

func _add_corridor_resource_target(session) -> void:
	session.overworld["resource_nodes"] = [{
		"placement_id": "river_free_company",
		"site_id": "site_riverwatch_free_company_yard",
		"x": 0,
		"y": 4,
		"collected": true,
		"collected_by_faction_id": "player",
		"response_until_day": 0,
		"response_security_rating": 0,
		"delivery_manifest": {},
	}]

func _make_hidden_hero_delivery_session(session, hero_id: String) -> void:
	_make_hidden_resource_target_session(session)
	var resources: Array = session.overworld.get("resource_nodes", [])
	for index in range(resources.size()):
		if not (resources[index] is Dictionary):
			continue
		var node: Dictionary = resources[index]
		if String(node.get("placement_id", "")) != "river_free_company":
			continue
		node["delivery_controller_id"] = "player"
		node["delivery_origin_town_id"] = "riverwatch_hold"
		node["delivery_arrival_day"] = int(session.day) + 2
		node["delivery_target_kind"] = "hero"
		node["delivery_target_id"] = hero_id
		node["delivery_target_label"] = "Lyra"
		node["delivery_manifest"] = {"unit_river_guard": 4}
		resources[index] = node
		session.overworld["resource_nodes"] = resources
		return
	_fail("Could not configure hidden hero delivery route.")

func _make_hidden_neutral_town_session(session) -> void:
	var towns: Array = session.overworld.get("towns", [])
	for index in range(towns.size()):
		if not (towns[index] is Dictionary):
			continue
		var town: Dictionary = towns[index]
		if String(town.get("placement_id", "")) == "duskfen_bastion":
			town["owner"] = "enemy"
			town["controlling_faction_id"] = MIRECLAW
		else:
			town["owner"] = "inactive"
			town["controlling_faction_id"] = ""
		towns[index] = town
	towns.append({
		"placement_id": "hidden_neutral_hold",
		"town_id": "town_duskfen",
		"name": "Hidden Neutral Hold",
		"x": 0,
		"y": 4,
		"owner": "neutral",
		"garrison": [],
		"available_recruits": {},
		"buildings": [],
	})
	session.overworld["towns"] = towns
	session.overworld["resource_nodes"] = []
	session.overworld["artifact_nodes"] = []
	session.overworld["encounters"] = []
	session.overworld["resolved_encounters"] = []
	_patch_enemy_memory(session, {"schema_version": 1, "player_hero_sightings": [], "scouted_targets": []})

func _add_exploration_raid(session, x: int, y: int) -> void:
	var raid := {
		"placement_id": "known_world_exploration_probe",
		"encounter_id": "encounter_mire_raid",
		"x": x,
		"y": y,
		"difficulty": "pressure",
		"spawned_by_faction_id": MIRECLAW,
		"days_active": 0,
		"arrived": true,
		"target_kind": "explore",
		"target_placement_id": "explore:%d:%d" % [x, y],
		"target_label": "Frontier scout %d,%d" % [x, y],
		"target_x": x,
		"target_y": y,
		"goal_x": x,
		"goal_y": y,
		"goal_distance": 0,
		"target_reason_codes": ["no_known_targets", "frontier_scouting", "search_contact"],
		"target_public_reason": "scouting the frontier",
		"target_public_importance": "medium",
	}
	raid["enemy_commander_state"] = EnemyAdventureRules.build_raid_commander_state(
		raid,
		"hero_vaska",
		MIRECLAW,
		session
	)
	raid = EnemyAdventureRules.ensure_raid_army(raid, session)
	session.overworld["encounters"] = [raid]
	session.overworld["resolved_encounters"] = []

func _frontier_reservation_raid(
	session,
	placement_id: String,
	hero_id: String,
	x: int,
	y: int,
	target_plan: Dictionary
) -> Dictionary:
	var raid := {
		"placement_id": placement_id,
		"encounter_id": "encounter_mire_raid",
		"x": x,
		"y": y,
		"difficulty": "pressure",
		"spawned_by_faction_id": MIRECLAW,
		"days_active": 0,
		"arrived": false,
	}
	if not target_plan.is_empty():
		raid.merge(target_plan, true)
	raid["enemy_commander_state"] = EnemyAdventureRules.build_raid_commander_state(
		raid,
		hero_id,
		MIRECLAW,
		session
	)
	return EnemyAdventureRules.ensure_raid_army(raid, session)

func _add_moving_exploration_raid(session, x: int, y: int, target_x: int, target_y: int) -> void:
	var raid := {
		"placement_id": "known_world_moving_exploration_probe",
		"encounter_id": "encounter_mire_raid",
		"x": x,
		"y": y,
		"difficulty": "pressure",
		"spawned_by_faction_id": MIRECLAW,
		"days_active": 0,
		"arrived": false,
		"target_kind": "explore",
		"target_placement_id": "explore:%d:%d" % [target_x, target_y],
		"target_label": "Frontier scout %d,%d" % [target_x, target_y],
		"target_x": target_x,
		"target_y": target_y,
		"goal_x": target_x,
		"goal_y": target_y,
		"goal_distance": abs(x - target_x) + abs(y - target_y),
		"target_reason_codes": ["no_known_targets", "frontier_scouting", "search_contact"],
		"target_public_reason": "scouting the frontier",
		"target_public_importance": "medium",
	}
	raid["enemy_commander_state"] = EnemyAdventureRules.build_raid_commander_state(
		raid,
		"hero_vaska",
		MIRECLAW,
		session
	)
	raid = EnemyAdventureRules.ensure_raid_army(raid, session)
	session.overworld["encounters"] = [raid]
	session.overworld["resolved_encounters"] = []

func _add_resource_route_raid(session, x: int, y: int, target_id: String) -> void:
	var target := _resource_node(session, target_id)
	if target.is_empty():
		_fail("Could not find resource route target %s" % target_id)
		return
	var raid := {
		"placement_id": "known_world_resource_route_probe",
		"encounter_id": "encounter_mire_raid",
		"x": x,
		"y": y,
		"difficulty": "pressure",
		"spawned_by_faction_id": MIRECLAW,
		"days_active": 0,
		"arrived": false,
		"target_kind": "resource",
		"target_placement_id": target_id,
		"target_label": "Route Occupancy Resource",
		"target_x": int(target.get("x", 0)),
		"target_y": int(target.get("y", 0)),
		"goal_x": int(target.get("x", 0)),
		"goal_y": int(target.get("y", 0)),
		"goal_distance": abs(x - int(target.get("x", 0))) + abs(y - int(target.get("y", 0))),
		"target_reason_codes": ["active_front_support", "route_occupancy_fixture"],
		"target_public_reason": "holding protected route",
		"target_public_importance": "medium",
	}
	raid["enemy_commander_state"] = EnemyAdventureRules.build_raid_commander_state(
		raid,
		"hero_vaska",
		MIRECLAW,
		session
	)
	raid = EnemyAdventureRules.ensure_raid_army(raid, session)
	session.overworld["encounters"] = [raid]
	session.overworld["resolved_encounters"] = []

func _candidate_has_target(candidates: Array, target_kind: String, target_id: String) -> bool:
	for candidate_value in candidates:
		if not (candidate_value is Dictionary):
			continue
		var candidate: Dictionary = candidate_value
		if String(candidate.get("target_kind", "")) == target_kind and String(candidate.get("target_placement_id", "")) == target_id:
			return true
	return false

func _first_delivery_candidate(candidates: Array, target_kind: String, target_id: String) -> Dictionary:
	for candidate_value in candidates:
		if not (candidate_value is Dictionary):
			continue
		var candidate: Dictionary = candidate_value
		if String(candidate.get("delivery_intercept_node_placement_id", "")) == "":
			continue
		if String(candidate.get("target_kind", "")) != target_kind:
			continue
		if String(candidate.get("target_placement_id", "")) != target_id:
			continue
		return candidate
	return {}

func _first_enemy_raid_for_kind(session, target_kind: String) -> Dictionary:
	var resolved: Array = session.overworld.get("resolved_encounters", []) if session.overworld.get("resolved_encounters", []) is Array else []
	for encounter_value in session.overworld.get("encounters", []):
		if not (encounter_value is Dictionary):
			continue
		var encounter: Dictionary = encounter_value
		if String(encounter.get("placement_id", "")) in resolved:
			continue
		if String(encounter.get("spawned_by_faction_id", "")) == MIRECLAW and String(encounter.get("target_kind", "")) == target_kind:
			return encounter
	return {}

func _encounter_by_id(session, placement_id: String) -> Dictionary:
	for encounter_value in session.overworld.get("encounters", []):
		if encounter_value is Dictionary and String(encounter_value.get("placement_id", "")) == placement_id:
			return encounter_value
	return {}

func _resource_node(session, placement_id: String) -> Dictionary:
	for node_value in session.overworld.get("resource_nodes", []):
		if node_value is Dictionary and String(node_value.get("placement_id", "")) == placement_id:
			return node_value
	return {}

func _first_task_for_kind(session, target_kind: String) -> Dictionary:
	for task_value in _task_state(session).get("tasks", []):
		if task_value is Dictionary and String(task_value.get("target_kind", "")) == target_kind:
			return task_value
	return {}

func _first_task_for_target(session, target_kind: String, target_id: String) -> Dictionary:
	for task_value in _task_state(session).get("tasks", []):
		if task_value is Dictionary \
				and String(task_value.get("target_kind", "")) == target_kind \
				and String(task_value.get("target_id", "")) == target_id:
			return task_value
	return {}

func _task_by_id(session, task_id: String) -> Dictionary:
	for task_value in _task_state(session).get("tasks", []):
		if task_value is Dictionary and String(task_value.get("task_id", "")) == task_id:
			return task_value
	return {}

func _task_state(session) -> Dictionary:
	var state := _enemy_state(session)
	return state.get("hero_task_state", {}) if state.get("hero_task_state", {}) is Dictionary else {}

func _memory_target_record(session, target_kind: String, target_id: String) -> Dictionary:
	var memory := _enemy_memory(session)
	for record_value in memory.get("scouted_targets", []):
		if record_value is Dictionary \
				and String(record_value.get("target_kind", "")) == target_kind \
				and String(record_value.get("target_id", "")) == target_id:
			return record_value
	return {}

func _explore_target_tile(target_id: String) -> Dictionary:
	var parts := target_id.split(":")
	if parts.size() != 3 or String(parts[0]) != "explore":
		return {}
	return {"x": int(parts[1]), "y": int(parts[2])}

func _move_raid_to_target(session, placement_id: String, x: int, y: int) -> void:
	var encounters: Array = session.overworld.get("encounters", [])
	for index in range(encounters.size()):
		if not (encounters[index] is Dictionary):
			continue
		var encounter: Dictionary = encounters[index]
		if String(encounter.get("placement_id", "")) != placement_id:
			continue
		encounter["x"] = x
		encounter["y"] = y
		encounter["goal_x"] = x
		encounter["goal_y"] = y
		encounter["goal_distance"] = 0
		encounter["arrived"] = true
		encounters[index] = encounter
		session.overworld["encounters"] = encounters
		return

func _event_types(events: Variant) -> Array:
	var output := []
	if not (events is Array):
		return output
	for event_value in events:
		if event_value is Dictionary:
			var event_type := String(event_value.get("event_type", ""))
			if event_type != "" and event_type not in output:
				output.append(event_type)
	return output

func _normalize_string_array(value: Variant) -> Array:
	var output := []
	if not (value is Array):
		return output
	for item in value:
		var text := String(item)
		if text != "":
			output.append(text)
	return output

func _enemy_config() -> Dictionary:
	var scenario := ContentService.get_scenario(RIVER_PASS)
	for config in scenario.get("enemy_factions", []):
		if config is Dictionary and String(config.get("faction_id", "")) == MIRECLAW:
			return config
	_fail("Could not find enemy config for %s" % MIRECLAW)
	return {}

func _ordinary_target_config() -> Dictionary:
	var config := _enemy_config().duplicate(true)
	config["priority_target_placement_ids"] = []
	config["priority_target_bonus"] = 0
	return config

func _priority_target_config(faction_id: String, placement_id: String) -> Dictionary:
	var config := _enemy_config().duplicate(true)
	config["faction_id"] = faction_id
	config["label"] = String(ContentService.get_faction(faction_id).get("name", faction_id))
	config["priority_target_placement_ids"] = [placement_id]
	config["priority_target_bonus"] = 400
	return config

func _enemy_state(session) -> Dictionary:
	for state in session.overworld.get("enemy_states", []):
		if state is Dictionary and String(state.get("faction_id", "")) == MIRECLAW:
			return state
	_fail("Could not find Mireclaw enemy state.")
	return {}

func _enemy_memory(session) -> Dictionary:
	var state := _enemy_state(session)
	return state.get("known_world_memory", {}) if state.get("known_world_memory", {}) is Dictionary else {}

func _patch_enemy_memory(session, memory: Dictionary) -> void:
	var state := _enemy_state(session)
	state["known_world_memory"] = memory
	_update_enemy_state(session, state)

func _update_enemy_state(session, updated_state: Dictionary) -> void:
	var states: Array = session.overworld.get("enemy_states", [])
	for index in range(states.size()):
		if states[index] is Dictionary and String(states[index].get("faction_id", "")) == MIRECLAW:
			states[index] = updated_state
			session.overworld["enemy_states"] = states
			return
	_fail("Could not update Mireclaw enemy state.")

func _fail(message: String) -> void:
	var payload := {"ok": false, "report_id": REPORT_ID, "error": message}
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	_failed = true
	get_tree().quit(1)
