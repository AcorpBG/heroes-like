extends Node

const REPORT_ID := "AI_HERO_TASK_SPAWN_COMMANDER_SELECTION_REPORT"
const RIVER_PASS := "river-pass"
const MIRECLAW := "faction_mireclaw"

var _failed := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var saved_task_case := _saved_task_commander_beats_rotation_case()
	if saved_task_case.is_empty():
		return
	var fallback_case := _fallback_and_unavailable_actor_case()
	if fallback_case.is_empty():
		return
	var spawn_point_case := _target_aware_spawn_point_case()
	if spawn_point_case.is_empty():
		return
	var multihero_spawn_occupancy_case := _multihero_spawn_point_avoids_secondary_player_hero_case()
	if multihero_spawn_occupancy_case.is_empty():
		return
	var spell_tempo_case := _spell_tempo_commander_spawn_point_case()
	if spell_tempo_case.is_empty():
		return
	var fresh_fit_case := _fresh_launch_commander_fit_beats_rotation_case()
	if fresh_fit_case.is_empty():
		return
	var generated_front_distribution_case := _generated_multi_town_front_distribution_case()
	if generated_front_distribution_case.is_empty():
		return
	var rebuild_launch_readiness_case := _rebuild_launch_waits_for_viable_commander_case()
	if rebuild_launch_readiness_case.is_empty():
		return
	var rebuild_target_completion_case := _commander_rebuild_target_stays_fixed_until_complete_case()
	if rebuild_target_completion_case.is_empty():
		return
	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"schema_status": "saved_tasks_influence_live_commander_deployment_spawn_avoids_all_player_heroes_prefers_deployable_saved_task_commander_spell_tempo_fresh_fit_generated_front_distribution_and_rebuild_launch_readiness",
		"behavior_policy": "saved_tasks_influence_live_commander_deployment_and_fresh_target_fit_influence_spawn_point_selection_while_spawn_occupancy_respects_all_live_player_heroes_adventure_spell_route_tempo_generated_multi_town_front_distribution_and_rebuilds_wait_for_viable_commanders",
		"save_policy": "hero_task_state_live_persist_no_save_migration",
		"cases": [saved_task_case, fallback_case, spawn_point_case, multihero_spawn_occupancy_case, spell_tempo_case, fresh_fit_case, generated_front_distribution_case, rebuild_launch_readiness_case, rebuild_target_completion_case],
		"save_version_before": int(SessionStateStore.SAVE_VERSION),
		"save_version_after": int(SessionStateStore.SAVE_VERSION),
	}
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _commander_rebuild_target_stays_fixed_until_complete_case() -> Dictionary:
	var session = _base_session()
	var state := _enemy_state(session)
	var roster: Array = state.get("commander_roster", []) if state.get("commander_roster", []) is Array else []
	for index in range(roster.size()):
		var entry: Dictionary = roster[index] if roster[index] is Dictionary else {}
		var commander_state: Dictionary = entry.get("commander_state", {}) if entry.get("commander_state", {}) is Dictionary else {}
		commander_state = EnemyAdventureRules.sync_commander_army_continuity(
			commander_state,
			{"stacks": []},
			"encounter_mire_raid"
		)
		entry["commander_state"] = commander_state
		entry["army_continuity"] = EnemyAdventureRules.commander_army_continuity(commander_state)
		if String(entry.get("roster_hero_id", "")) == "hero_tarn":
			entry["status"] = EnemyAdventureRules.COMMANDER_STATUS_AVAILABLE
			entry["recovery_day"] = 0
		else:
			entry["status"] = EnemyAdventureRules.COMMANDER_STATUS_RECOVERING
			entry["recovery_day"] = int(session.day) + 100
		roster[index] = entry
	state["commander_roster"] = roster
	_update_enemy_state(session, state)

	var target := EnemyTurnRules._best_commander_rebuild_target(session, _enemy_config(), MIRECLAW)
	if String(target.get("roster_hero_id", "")) != "hero_tarn" or int(target.get("target_strength", 0)) <= 0:
		_fail("Commander rebuild completion fixture did not select Tarn: %s" % JSON.stringify(target))
		return {}
	var baseline_strength: int = int(
		EnemyAdventureRules.commander_army_continuity(
			_commander_entry(session, "hero_tarn")
		).get("base_strength", 0)
	)
	var first_accepted := EnemyAdventureRules.reinforce_commander_roster_army(
		session,
		MIRECLAW,
		"hero_tarn",
		"unit_mire_slinger",
		1,
		String(target.get("base_encounter_id", "")),
		int(target.get("target_strength", 0))
	)
	var partial_continuity := EnemyAdventureRules.commander_army_continuity(
		_commander_entry(session, "hero_tarn")
	)
	if (
		first_accepted != 1
		or int(partial_continuity.get("current_strength", 0)) <= 0
		or int(partial_continuity.get("current_strength", 0)) >= baseline_strength
	):
		_fail("Single-unit commander rebuild restored untransferred base forces: %s" % JSON.stringify(partial_continuity))
		return {}
	var remaining_accepted := EnemyAdventureRules.reinforce_commander_roster_army(
		session,
		MIRECLAW,
		"hero_tarn",
		"unit_mire_slinger",
		999,
		String(target.get("base_encounter_id", "")),
		int(target.get("target_strength", 0))
	)
	var rebuilt_continuity := EnemyAdventureRules.commander_army_continuity(
		_commander_entry(session, "hero_tarn")
	)
	if remaining_accepted <= 0 or int(rebuilt_continuity.get("current_strength", 0)) < int(target.get("target_strength", 0)):
		_fail("Commander rebuild did not reach its fixed pressure target: target=%s continuity=%s" % [JSON.stringify(target), JSON.stringify(rebuilt_continuity)])
		return {}
	if int(rebuilt_continuity.get("base_strength", 0)) != baseline_strength:
		_fail("Commander rebuild moved its historical baseline after reinforcement: before=%d after=%s" % [baseline_strength, JSON.stringify(rebuilt_continuity)])
		return {}
	var next_target := EnemyTurnRules._best_commander_rebuild_target(session, _enemy_config(), MIRECLAW)
	if not next_target.is_empty():
		_fail("Completed commander rebuild immediately created another moving target: %s" % JSON.stringify(next_target))
		return {}
	return {
		"case_id": "commander_rebuild_pressure_target_stays_fixed_until_complete",
		"roster_hero_id": "hero_tarn",
		"base_strength": baseline_strength,
		"target_strength": int(target.get("target_strength", 0)),
		"partial_strength": int(partial_continuity.get("current_strength", 0)),
		"rebuilt_strength": int(rebuilt_continuity.get("current_strength", 0)),
		"accepted_units": first_accepted + remaining_accepted,
		"next_target_empty": true,
		"save_version": int(SessionStateStore.SAVE_VERSION),
	}

func _saved_task_commander_beats_rotation_case() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config()
	var state := _enemy_state(session)
	state["raid_counter"] = 0
	state["commander_counter"] = 1
	_set_resource_controller(session, "river_free_company", "player")
	_seed_task_board(session, [_task("hero_tarn", "river_free_company", 10, "planned", "valid")])
	_update_enemy_state(session, state)

	var spawn_point := {"x": 7, "y": 1}
	var rotation_pick := EnemyAdventureRules.select_raid_commander_roster_hero_id(
		session,
		MIRECLAW,
		1,
		{},
		state.get("commander_roster", [])
	)
	if rotation_pick != "hero_sable":
		_fail("Fixture expected normal rotation to start with hero_sable, got %s" % rotation_pick)
		return {}
	var spawn_pick := EnemyAdventureRules.select_raid_commander_roster_hero_id_for_spawn(
		session,
		MIRECLAW,
		spawn_point,
		1,
		{},
		state.get("commander_roster", [])
	)
	if spawn_pick != "hero_tarn":
		_fail("Saved-task spawn selection expected hero_tarn, got %s" % spawn_pick)
		return {}
	var spawn_result := EnemyTurnRules._spawn_raid(session, config, state)
	if not bool(spawn_result.get("ok", false)):
		_fail("Spawn result failed: %s" % JSON.stringify(spawn_result))
		return {}
	var raid := _latest_raid(session)
	var commander_id := String(raid.get("enemy_commander_state", {}).get("roster_hero_id", ""))
	if commander_id != "hero_tarn":
		_fail("Spawned raid did not deploy saved-task commander hero_tarn: %s" % JSON.stringify(raid))
		return {}
	if String(raid.get("target_kind", "")) != "resource" or String(raid.get("target_placement_id", "")) != "river_free_company":
		_fail("Spawned saved-task commander did not reuse river_free_company: %s" % JSON.stringify(raid))
		return {}
	var reason_codes := _string_array(raid.get("target_reason_codes", []))
	if "saved_hero_task" not in reason_codes:
		_fail("Spawned saved-task raid is missing saved_hero_task reason: %s" % JSON.stringify(raid))
		return {}
	_assert_task_status(session, "hero_tarn", "active", "river_free_company")
	if _failed:
		return {}
	var public_log := EnemyAdventureRules.ai_public_event_log_boundary_report(spawn_result.get("events", []), 2)
	if not bool(public_log.get("ok", false)):
		_fail("Spawn assignment public event boundary failed: %s" % JSON.stringify(public_log))
		return {}
	return {
		"case_id": "spawn_prefers_tarn_saved_task_over_sable_rotation",
		"rotation_pick": rotation_pick,
		"spawn_pick": spawn_pick,
		"spawned_commander_id": commander_id,
		"target_id": String(raid.get("target_placement_id", "")),
		"reason_codes": reason_codes,
		"public_event_count": int(public_log.get("public_event_count", 0)),
		"save_version": int(SessionStateStore.SAVE_VERSION),
	}

func _fallback_and_unavailable_actor_case() -> Dictionary:
	var session = _base_session()
	var state := _enemy_state(session)
	state["commander_counter"] = 1
	_set_resource_controller(session, "river_signal_post", "player")
	_seed_task_board(session, [_task("hero_sable", "river_signal_post", 10, "planned", "valid")])
	_set_commander_recovering(session, "hero_sable", 8)
	state = _enemy_state(session)
	var spawn_point := {"x": 7, "y": 1}
	var spawn_pick := EnemyAdventureRules.select_raid_commander_roster_hero_id_for_spawn(
		session,
		MIRECLAW,
		spawn_point,
		1,
		{},
		state.get("commander_roster", [])
	)
	var fallback_pick := EnemyAdventureRules.select_raid_commander_roster_hero_id(
		session,
		MIRECLAW,
		1,
		{},
		state.get("commander_roster", [])
	)
	if spawn_pick != fallback_pick:
		_fail("Unavailable saved-task actor should fall back to normal deployable rotation: spawn=%s fallback=%s" % [spawn_pick, fallback_pick])
		return {}
	if spawn_pick == "hero_sable":
		_fail("Recovering commander with saved task was incorrectly selected for spawn.")
		return {}
	return {
		"case_id": "recovering_saved_task_actor_does_not_override_rotation",
		"recovering_actor_id": "hero_sable",
		"spawn_pick": spawn_pick,
		"fallback_pick": fallback_pick,
		"save_version": int(SessionStateStore.SAVE_VERSION),
	}

func _target_aware_spawn_point_case() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config()
	var state := _enemy_state(session)
	state["raid_counter"] = 0
	state["commander_counter"] = 1
	_update_enemy_state(session, state)
	_set_resource_controller(session, "river_free_company", "player")
	_seed_task_board(session, [_task("hero_tarn", "river_free_company", 10, "planned", "valid")])
	state = _enemy_state(session)

	var first_open := EnemyTurnRules._first_open_spawn_point(session, config)
	if int(first_open.get("x", 0)) != 7 or int(first_open.get("y", 0)) != 1:
		_fail("Fixture expected first open spawn point 7,1 before target-aware selection, got %s" % JSON.stringify(first_open))
		return {}
	EnemyTurnRules._spawn_profile_begin(true)
	var best_open := EnemyTurnRules._best_open_spawn_point(session, config, state, MIRECLAW)
	var spawn_scan_profile := EnemyTurnRules._spawn_profile_finish()
	var spawn_scan_counts: Dictionary = spawn_scan_profile.get("counts", {}) if spawn_scan_profile.get("counts", {}) is Dictionary else {}
	for loaded_key in [
		"spawn_scan_commander_roster_loaded",
		"spawn_scan_commander_candidates_loaded",
		"spawn_scan_live_tasks_loaded",
		"spawn_scan_path_context_loaded",
	]:
		if int(spawn_scan_counts.get(loaded_key, 0)) != 1:
			_fail("Target-aware multi-point scan should load %s exactly once: %s" % [loaded_key, JSON.stringify(spawn_scan_profile)])
			return {}
	if int(spawn_scan_counts.get("spawn_scan_live_tasks_reused", 0)) <= 0 \
			or int(spawn_scan_counts.get("spawn_scan_path_context_reused", 0)) <= 0:
		_fail("Target-aware multi-point scan did not reuse task and path context: %s" % JSON.stringify(spawn_scan_profile))
		return {}
	if int(spawn_scan_counts.get("ready_saved_task_no_prepared_commander_skip", 0)) != 1 \
			or int(spawn_scan_counts.get("ready_saved_task_no_prepared_commander_reused", 0)) <= 0:
		_fail("Understrength saved-task scan did not reuse the explicit no-prepared-commander preflight: %s" % JSON.stringify(spawn_scan_profile))
		return {}
	if int(spawn_scan_counts.get("spawn_spell_projection_loaded", 0)) != 2 \
			or int(spawn_scan_counts.get("spawn_spell_projection_reused", 0)) != 0:
		_fail("Understrength saved-task scan retained redundant ready-path spell projections: %s" % JSON.stringify(spawn_scan_profile))
		return {}
	if int(spawn_scan_counts.get("spawn_spell_projection_roster_reused", 0)) \
			!= int(spawn_scan_counts.get("spawn_spell_projection_loaded", 0)):
		_fail("Saved-task spell projections did not all reuse the normalized spawn roster: %s" % JSON.stringify(spawn_scan_profile))
		return {}
	if int(best_open.get("x", 0)) != 7 or int(best_open.get("y", 0)) != 3:
		_fail("Target-aware spawn selection should prefer closer southern spawn point, got %s" % JSON.stringify(best_open))
		return {}
	if String(best_open.get("spawn_plan_source", "")) != "saved_task":
		_fail("Target-aware spawn selection should be driven by saved task, got %s" % JSON.stringify(best_open))
		return {}
	if String(best_open.get("roster_hero_id", "")) != "hero_tarn":
		_fail("Target-aware spawn selection should preserve saved-task commander hero_tarn, got %s" % JSON.stringify(best_open))
		return {}

	var spawn_result := EnemyTurnRules._spawn_raid(session, config, state)
	if not bool(spawn_result.get("ok", false)):
		_fail("Target-aware spawn result failed: %s" % JSON.stringify(spawn_result))
		return {}
	var raid := _latest_raid(session)
	if int(raid.get("x", 0)) != 7 or int(raid.get("y", 0)) != 3:
		_fail("Spawned raid did not use target-aware spawn point 7,3: %s" % JSON.stringify(raid))
		return {}
	if String(raid.get("enemy_commander_state", {}).get("roster_hero_id", "")) != "hero_tarn":
		_fail("Spawned raid did not keep saved-task commander hero_tarn: %s" % JSON.stringify(raid))
		return {}
	if String(raid.get("target_kind", "")) != "resource" or String(raid.get("target_placement_id", "")) != "river_free_company":
		_fail("Spawned raid did not reuse river_free_company saved task: %s" % JSON.stringify(raid))
		return {}
	_assert_task_status(session, "hero_tarn", "active", "river_free_company")
	if _failed:
		return {}
	return {
		"case_id": "spawn_point_prefers_saved_task_reachable_origin_over_first_open",
		"first_open": first_open,
		"selected_spawn_point": {"x": int(best_open.get("x", 0)), "y": int(best_open.get("y", 0))},
		"spawn_plan_source": String(best_open.get("spawn_plan_source", "")),
		"spawn_plan_goal_distance": int(best_open.get("spawn_plan_goal_distance", 0)),
		"spawned_commander_id": String(raid.get("enemy_commander_state", {}).get("roster_hero_id", "")),
		"target_id": String(raid.get("target_placement_id", "")),
		"spawn_scan_context_counts": spawn_scan_counts,
		"save_version": int(SessionStateStore.SAVE_VERSION),
	}

func _multihero_spawn_point_avoids_secondary_player_hero_case() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config()
	_set_primary_hero_position(session, 0, 4)
	_add_secondary_player_hero(session, "hero_secondary_spawn_blocker", 7, 1)

	var first_open := EnemyTurnRules._first_open_spawn_point(session, config)
	if int(first_open.get("x", 0)) == 7 and int(first_open.get("y", 0)) == 1:
		_fail("Enemy spawn point selection used a tile occupied by a secondary player hero: %s" % JSON.stringify(first_open))
		return {}
	if int(first_open.get("x", 0)) != 7 or int(first_open.get("y", 0)) != 3:
		_fail("Secondary player hero should close first spawn point 7,1 and leave 7,3 as first open, got %s" % JSON.stringify(first_open))
		return {}
	return {
		"case_id": "spawn_point_avoids_secondary_player_hero_tile",
		"primary_hero_position": {"x": 0, "y": 4},
		"secondary_hero_id": "hero_secondary_spawn_blocker",
		"secondary_hero_position": {"x": 7, "y": 1},
		"selected_spawn_point": first_open,
		"save_version": int(SessionStateStore.SAVE_VERSION),
	}

func _spell_tempo_commander_spawn_point_case() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config()
	var state := _enemy_state(session)
	state["raid_counter"] = 0
	state["commander_counter"] = 1
	_update_enemy_state(session, state)
	_set_resource_controller(session, "river_free_company", "player")
	_set_resource_controller(session, "river_signal_post", "player")
	_seed_task_board(session, [
		_task("hero_sable", "river_free_company", 10, "planned", "valid"),
		_task("hero_tarn", "river_signal_post", 10, "planned", "valid"),
	])
	state = _enemy_state(session)

	var best_open := EnemyTurnRules._best_open_spawn_point(session, config, state, MIRECLAW)
	if String(best_open.get("roster_hero_id", "")) != "hero_tarn":
		_fail("Spell-tempo spawn selection should prefer Tarn's route spell over closer non-spell pressure: %s" % JSON.stringify(best_open))
		return {}
	if not bool(best_open.get("spawn_plan_spell_tempo", false)):
		_fail("Spell-tempo spawn selection did not mark the movement-spell projection: %s" % JSON.stringify(best_open))
		return {}
	if String(best_open.get("spawn_plan_target_id", "")) != "river_signal_post":
		_fail("Spell-tempo spawn selection should keep Tarn's saved signal-post target: %s" % JSON.stringify(best_open))
		return {}
	if int(best_open.get("spawn_plan_effective_goal_distance", 9999)) >= int(best_open.get("spawn_plan_goal_distance", 0)):
		_fail("Spell-tempo projection did not improve effective route distance: %s" % JSON.stringify(best_open))
		return {}

	var spawn_result := EnemyTurnRules._spawn_raid(session, config, state)
	if not bool(spawn_result.get("ok", false)):
		_fail("Spell-tempo spawn result failed: %s" % JSON.stringify(spawn_result))
		return {}
	var raid := _latest_raid(session)
	var start_x := int(raid.get("x", 0))
	var start_y := int(raid.get("y", 0))
	if String(raid.get("enemy_commander_state", {}).get("roster_hero_id", "")) != "hero_tarn":
		_fail("Spell-tempo spawned raid did not deploy Tarn: %s" % JSON.stringify(raid))
		return {}
	if String(raid.get("target_placement_id", "")) != "river_signal_post":
		_fail("Spell-tempo spawned raid did not target the signal post: %s" % JSON.stringify(raid))
		return {}

	var advance_result := EnemyAdventureRules.advance_raids(session, config, MIRECLAW, _enemy_state(session))
	var advance_events: Array = advance_result.get("events", []) if advance_result.get("events", []) is Array else []
	var event_types := _event_types(advance_events)
	if "ai_adventure_spell_cast" not in event_types:
		_fail("Spell-tempo raid did not cast its live movement spell on advance: %s" % JSON.stringify(advance_result))
		return {}
	var after_raid := _latest_raid(session)
	var moved_steps: int = abs(int(after_raid.get("x", 0)) - start_x) + abs(int(after_raid.get("y", 0)) - start_y)
	if moved_steps <= 1:
		_fail("Spell-tempo raid did not move more than the base step after casting: before=%d,%d after=%s" % [start_x, start_y, JSON.stringify(after_raid)])
		return {}
	if String(after_raid.get("last_adventure_spell_id", "")) == "":
		_fail("Spell-tempo raid moved without preserving the cast spell metadata: %s" % JSON.stringify(after_raid))
		return {}
	var public_log := EnemyAdventureRules.ai_public_event_log_boundary_report(advance_events, 2)
	if not bool(public_log.get("ok", false)):
		_fail("Spell-tempo public event boundary failed: %s" % JSON.stringify(public_log))
		return {}
	return {
		"case_id": "spawn_selection_values_saved_task_route_spell_tempo",
		"selected_commander_id": String(best_open.get("roster_hero_id", "")),
		"spell_id": String(best_open.get("spawn_plan_spell_id", "")),
		"raw_goal_distance": int(best_open.get("spawn_plan_goal_distance", 0)),
		"effective_goal_distance": int(best_open.get("spawn_plan_effective_goal_distance", 0)),
		"moved_steps_after_cast": moved_steps,
		"advance_event_types": event_types,
		"public_event_count": int(public_log.get("public_event_count", 0)),
		"save_version": int(SessionStateStore.SAVE_VERSION),
	}

func _fresh_launch_commander_fit_beats_rotation_case() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config()
	var state := _enemy_state(session)
	state["raid_counter"] = 0
	state["commander_counter"] = 1
	state.erase("hero_task_state")
	_update_enemy_state(session, state)
	_set_town_owner(session, "riverwatch_hold", "enemy", MIRECLAW)
	_set_resource_controller(session, "duskfen_bastion_peatwax_front", "")
	_set_resource_controller(session, "river_pass_duskfen_bastion_rare_exchange", "")
	_set_primary_hero_position(session, 6, 2)
	var memory_result := EnemyAdventureRules.refresh_enemy_known_world_memory(session, config, _enemy_state(session))
	_update_enemy_state(session, memory_result.get("state", _enemy_state(session)))
	state = _enemy_state(session)

	var rotation_pick := EnemyAdventureRules.select_raid_commander_roster_hero_id(
		session,
		MIRECLAW,
		1,
		{},
		state.get("commander_roster", [])
	)
	if rotation_pick != "hero_sable":
		_fail("Fixture expected fresh-launch rotation to start with hero_sable, got %s" % rotation_pick)
		return {}
	var best_open := EnemyTurnRules._best_open_spawn_point(session, config, state, MIRECLAW)
	if String(best_open.get("spawn_plan_source", "")) != "fresh_target":
		_fail("Fresh launch fit case expected fresh_target plan, got %s" % JSON.stringify(best_open))
		return {}
	if String(best_open.get("roster_hero_id", "")) == rotation_pick:
		_fail("Fresh launch fit should beat plain rotation, got %s" % JSON.stringify(best_open))
		return {}
	if String(best_open.get("roster_hero_id", "")) != "hero_vaska":
		_fail("Fresh launch fit should select Vaska for the highest-fit fresh pressure target, got %s" % JSON.stringify(best_open))
		return {}
	if int(best_open.get("spawn_plan_commander_fit_bonus", 0)) <= 0:
		_fail("Fresh launch fit did not record a positive commander fit bonus: %s" % JSON.stringify(best_open))
		return {}

	var spawn_result := EnemyTurnRules._spawn_raid(session, config, state)
	if not bool(spawn_result.get("ok", false)):
		_fail("Fresh launch fit spawn failed: %s" % JSON.stringify(spawn_result))
		return {}
	var raid := _latest_raid(session)
	if String(raid.get("enemy_commander_state", {}).get("roster_hero_id", "")) != "hero_vaska":
		_fail("Fresh launch spawned raid did not deploy Vaska: %s" % JSON.stringify(raid))
		return {}
	if String(raid.get("target_kind", "")) != String(best_open.get("spawn_plan_target_kind", "")) \
			or String(raid.get("target_placement_id", "")) != String(best_open.get("spawn_plan_target_id", "")):
		_fail("Fresh launch spawned raid did not keep the fitted target: plan=%s raid=%s" % [JSON.stringify(best_open), JSON.stringify(raid)])
		return {}
	return {
		"case_id": "fresh_launch_commander_fit_beats_rotation",
		"rotation_pick": rotation_pick,
		"selected_commander_id": String(best_open.get("roster_hero_id", "")),
		"target_kind": String(best_open.get("spawn_plan_target_kind", "")),
		"target_id": String(best_open.get("spawn_plan_target_id", "")),
		"commander_fit_bonus": int(best_open.get("spawn_plan_commander_fit_bonus", 0)),
		"commander_fit_profile": String(best_open.get("spawn_plan_commander_fit_profile", "")),
		"spawned_commander_id": String(raid.get("enemy_commander_state", {}).get("roster_hero_id", "")),
		"save_version": int(SessionStateStore.SAVE_VERSION),
	}

func _generated_multi_town_front_distribution_case() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config().duplicate(true)
	config["generated_package_town_config"] = true
	config["spawn_points"] = [{"x": 7, "y": 1}, {"x": 7, "y": 3}]
	var state := _enemy_state(session)
	state.erase("hero_task_state")
	_update_enemy_state(session, state)
	var encounters: Array = session.overworld.get("encounters", [])
	encounters.append({
		"placement_id": "generated_front_distribution_existing_host",
		"encounter_id": "encounter_mire_raid",
		"x": 6,
		"y": 1,
		"spawn_origin_x": 7,
		"spawn_origin_y": 1,
		"difficulty": "pressure",
		"spawned_by_faction_id": MIRECLAW,
		"days_active": 2,
		"arrived": false,
		"target_kind": "explore",
		"target_placement_id": "explore:5:1",
		"target_label": "Existing frontier sweep",
		"target_x": 5,
		"target_y": 1,
		"goal_x": 5,
		"goal_y": 1,
		"goal_distance": 1,
		"enemy_army": {"id": "generated_front_distribution_host", "name": "Existing Host", "stacks": [{"unit_id": "unit_bog_brute", "count": 3}]},
	})
	session.overworld["encounters"] = encounters
	state = _enemy_state(session)
	var best_open := EnemyTurnRules._best_open_spawn_point(session, config, state, MIRECLAW)
	if int(best_open.get("x", 0)) != 7 or int(best_open.get("y", 0)) != 3:
		_fail("Generated multi-town launch repeated an occupied deployment origin instead of opening the unused front: %s" % JSON.stringify(best_open))
		return {}
	if not bool(best_open.get("spawn_plan_generated_front_distribution", false)) \
			or int(best_open.get("spawn_plan_active_origin_count", -1)) != 0:
		_fail("Generated multi-town launch omitted unused-front distribution evidence: %s" % JSON.stringify(best_open))
		return {}
	var spawn_result := EnemyTurnRules._spawn_raid(session, config, state, best_open)
	if not bool(spawn_result.get("ok", false)):
		_fail("Generated multi-town distributed spawn failed: %s" % JSON.stringify(spawn_result))
		return {}
	var raid := _latest_raid(session)
	if int(raid.get("spawn_origin_x", -1)) != 7 or int(raid.get("spawn_origin_y", -1)) != 3:
		_fail("Generated multi-town distributed host did not preserve its deployment origin: %s" % JSON.stringify(raid))
		return {}
	return {
		"case_id": "generated_multi_town_ordinary_launch_uses_unoccupied_front",
		"existing_origin": {"x": 7, "y": 1},
		"selected_origin": {"x": int(best_open.get("x", 0)), "y": int(best_open.get("y", 0))},
		"active_origin_count": int(best_open.get("spawn_plan_active_origin_count", -1)),
		"spawn_plan_source": String(best_open.get("spawn_plan_source", "")),
		"preserved_spawn_origin": {"x": int(raid.get("spawn_origin_x", -1)), "y": int(raid.get("spawn_origin_y", -1))},
		"save_version": int(SessionStateStore.SAVE_VERSION),
	}

func _rebuild_launch_waits_for_viable_commander_case() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config().duplicate(true)
	config["generated_package_town_config"] = true
	config["spawn_points"] = [{"x": 7, "y": 1}, {"x": 7, "y": 3}]
	_set_all_commander_continuity(session, [{"unit_id": "unit_mire_slinger", "count": 1}])
	var state := _enemy_state(session)
	state.erase("hero_task_state")
	state["rebuild_pressure_request"] = {
		"requested_day": int(session.day),
		"origin_town_id": "duskfen_bastion",
		"commander_id": "hero_tarn",
		"reason": "no_spare_garrison_after_regroup",
	}
	_update_enemy_state(session, state)
	EnemyTurnRules._spawn_profile_begin(true)
	var blocked_candidate := EnemyTurnRules._best_open_spawn_point(session, config, state, MIRECLAW)
	var blocked_scan_profile := EnemyTurnRules._spawn_profile_finish()
	var blocked_scan_counts: Dictionary = blocked_scan_profile.get("counts", {}) if blocked_scan_profile.get("counts", {}) is Dictionary else {}
	if not blocked_candidate.is_empty():
		_fail("Understrength rebuild roster bypassed target readiness through a scout launch: %s" % JSON.stringify(blocked_candidate))
		return {}
	if int(blocked_scan_counts.get("spawn_ready_probe_loaded", 0)) <= 0 \
			or int(blocked_scan_counts.get("spawn_ready_probe_reused", 0)) <= 0:
		_fail("Multi-point rebuild readiness scan did not reuse prepared commander probes: %s" % JSON.stringify(blocked_scan_profile))
		return {}

	_set_commander_continuity(
		session,
		"hero_tarn",
		[
			{"unit_id": "unit_bog_brute", "count": 12},
			{"unit_id": "unit_mire_slinger", "count": 15},
		]
	)
	state = _enemy_state(session)
	var ready_candidate := EnemyTurnRules._best_open_spawn_point(session, config, state, MIRECLAW)
	if ready_candidate.is_empty():
		_fail("Rebuilt commander did not reopen a viable strategic launch.")
		return {}
	if String(ready_candidate.get("spawn_plan_source", "")) != "fresh_target":
		_fail("Rebuilt commander bypassed known strategic targets through a fallback launch: %s" % JSON.stringify(ready_candidate))
		return {}
	if not EnemyTurnRules._spawn_candidate_ready_without_immediate_regroup(
		session,
		config,
		state,
		MIRECLAW,
		ready_candidate,
		{}
	):
		_fail("Rebuilt commander candidate still required immediate regroup: %s" % JSON.stringify(ready_candidate))
		return {}
	var immediate_patrol_candidate: Dictionary = ready_candidate.duplicate(true)
	immediate_patrol_candidate["spawn_plan_target_kind"] = "explore"
	immediate_patrol_candidate["spawn_plan_target_id"] = "explore:8:1"
	immediate_patrol_candidate["spawn_plan_target_label"] = "Immediate patrol"
	immediate_patrol_candidate["spawn_plan_target_x"] = 8
	immediate_patrol_candidate["spawn_plan_target_y"] = 1
	immediate_patrol_candidate["spawn_plan_goal_x"] = 8
	immediate_patrol_candidate["spawn_plan_goal_y"] = 1
	immediate_patrol_candidate["spawn_plan_goal_distance"] = 1
	if EnemyTurnRules._spawn_candidate_ready_without_immediate_regroup(
		session,
		config,
		state,
		MIRECLAW,
		immediate_patrol_candidate,
		{}
	):
		_fail("One-turn rebuild patrol was accepted even though launch advance would consume it immediately.")
		return {}
	return {
		"case_id": "rebuild_pressure_waits_for_viable_commander_before_known_target_launch",
		"understrength_launch_blocked": true,
		"ready_commander_id": String(ready_candidate.get("roster_hero_id", "")),
		"ready_spawn_plan_source": String(ready_candidate.get("spawn_plan_source", "")),
		"ready_target_kind": String(ready_candidate.get("spawn_plan_target_kind", "")),
		"ready_target_id": String(ready_candidate.get("spawn_plan_target_id", "")),
		"blocked_scan_probe_load_count": int(blocked_scan_counts.get("spawn_ready_probe_loaded", 0)),
		"blocked_scan_probe_reuse_count": int(blocked_scan_counts.get("spawn_ready_probe_reused", 0)),
		"immediate_patrol_launch_blocked": true,
		"save_version": int(SessionStateStore.SAVE_VERSION),
	}

func _set_all_commander_continuity(session, stacks: Array) -> void:
	var state := _enemy_state(session)
	var roster: Array = state.get("commander_roster", []) if state.get("commander_roster", []) is Array else []
	for index in range(roster.size()):
		var entry: Dictionary = roster[index] if roster[index] is Dictionary else {}
		var commander_state: Dictionary = entry.get("commander_state", {}) if entry.get("commander_state", {}) is Dictionary else {}
		commander_state = EnemyAdventureRules.sync_commander_army_continuity(
			commander_state,
			{"stacks": stacks.duplicate(true)},
			"encounter_mire_raid"
		)
		entry["commander_state"] = commander_state
		entry["army_continuity"] = EnemyAdventureRules.commander_army_continuity(commander_state)
		entry["status"] = EnemyAdventureRules.COMMANDER_STATUS_AVAILABLE
		roster[index] = entry
	state["commander_roster"] = roster
	_update_enemy_state(session, state)

func _set_commander_continuity(session, actor_id: String, stacks: Array) -> void:
	var state := _enemy_state(session)
	var roster: Array = state.get("commander_roster", []) if state.get("commander_roster", []) is Array else []
	for index in range(roster.size()):
		var entry: Dictionary = roster[index] if roster[index] is Dictionary else {}
		if String(entry.get("roster_hero_id", "")) != actor_id:
			continue
		var commander_state: Dictionary = entry.get("commander_state", {}) if entry.get("commander_state", {}) is Dictionary else {}
		commander_state = EnemyAdventureRules.sync_commander_army_continuity(
			commander_state,
			{"stacks": stacks.duplicate(true)},
			"encounter_mire_raid"
		)
		entry["commander_state"] = commander_state
		entry["army_continuity"] = EnemyAdventureRules.commander_army_continuity(commander_state)
		entry["status"] = EnemyAdventureRules.COMMANDER_STATUS_AVAILABLE
		roster[index] = entry
		state["commander_roster"] = roster
		_update_enemy_state(session, state)
		return
	_fail("Missing commander %s for continuity fixture." % actor_id)

func _seed_task_board(session, tasks: Array) -> void:
	var state := _enemy_state(session)
	state["hero_task_state"] = {
		"schema_version": 1,
		"planner_epoch": 7,
		"tasks": tasks,
	}
	_update_enemy_state(session, state)

func _task(actor_id: String, target_id: String, expires_day: int, status: String, validation: String) -> Dictionary:
	return {
		"task_id": "task:spawn_selection:%s:%s" % [actor_id, target_id],
		"owner_faction_id": MIRECLAW,
		"actor_kind": "commander_roster",
		"actor_id": actor_id,
		"source_kind": "saved_task_state",
		"source_id": "spawn_selection_fixture",
		"task_class": "contest_site",
		"task_status": status,
		"target_kind": "resource",
		"target_id": target_id,
		"front_id": "resource:%s" % target_id,
		"origin_kind": "town",
		"origin_id": "duskfen_bastion",
		"priority_reason_codes": ["spawn_selection_fixture"],
		"assigned_day": 3,
		"expires_day": expires_day,
		"continuity_policy": "persist_until_invalid",
		"route_policy": "derive_route_on_turn",
		"last_validation": validation,
		"reservation": {
			"reservation_status": "primary",
			"reservation_scope": "exclusive_target",
			"reservation_key": "resource:%s" % target_id,
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

func _commander_entry(session, roster_hero_id: String) -> Dictionary:
	for entry_value in _enemy_state(session).get("commander_roster", []):
		if entry_value is Dictionary and String(entry_value.get("roster_hero_id", "")) == roster_hero_id:
			return entry_value
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

func _set_town_owner(session, placement_id: String, owner: String, faction_id: String = "") -> void:
	var towns: Array = session.overworld.get("towns", [])
	for index in range(towns.size()):
		var town = towns[index]
		if not (town is Dictionary) or String(town.get("placement_id", "")) != placement_id:
			continue
		town["owner"] = owner
		if owner == "enemy" and faction_id != "":
			town["controlling_faction_id"] = faction_id
		towns[index] = town
		session.overworld["towns"] = towns
		return
	_fail("Could not find town placement %s" % placement_id)

func _set_primary_hero_position(session, x: int, y: int) -> void:
	var hero: Dictionary = session.overworld.get("hero", {}).duplicate(true)
	hero["id"] = String(session.overworld.get("active_hero_id", "hero_lyra"))
	hero["name"] = String(hero.get("name", "Lyra"))
	hero["position"] = {"x": x, "y": y}
	session.overworld["hero"] = hero
	session.overworld["hero_position"] = {"x": x, "y": y}
	session.overworld["active_hero_id"] = String(hero.get("id", "hero_lyra"))
	session.overworld["player_heroes"] = [hero]

func _add_secondary_player_hero(session, hero_id: String, x: int, y: int) -> void:
	var hero := {
		"id": hero_id,
		"name": "Secondary Scout",
		"owner": "player",
		"position": {"x": x, "y": y},
		"army": {"stacks": [{"unit_id": "unit_river_guard", "count": 1}]},
	}
	var player_heroes: Array = session.overworld.get("player_heroes", []) if session.overworld.get("player_heroes", []) is Array else []
	player_heroes.append(hero.duplicate(true))
	session.overworld["player_heroes"] = player_heroes
	var heroes: Array = session.overworld.get("heroes", []) if session.overworld.get("heroes", []) is Array else []
	heroes.append(hero.duplicate(true))
	session.overworld["heroes"] = heroes

func _set_commander_recovering(session, actor_id: String, recovery_day: int) -> void:
	var state := _enemy_state(session)
	var roster: Array = state.get("commander_roster", []) if state.get("commander_roster", []) is Array else []
	for index in range(roster.size()):
		var entry = roster[index]
		if entry is Dictionary and String(entry.get("roster_hero_id", "")) == actor_id:
			entry["status"] = "recovering"
			entry["recovery_day"] = recovery_day
			roster[index] = entry
			state["commander_roster"] = roster
			_update_enemy_state(session, state)
			return
	_fail("Missing commander %s for recovery fixture." % actor_id)

func _latest_raid(session) -> Dictionary:
	var encounters: Array = session.overworld.get("encounters", [])
	for index in range(encounters.size() - 1, -1, -1):
		var encounter = encounters[index]
		if encounter is Dictionary and String(encounter.get("spawned_by_faction_id", "")) == MIRECLAW:
			return encounter
	_fail("No spawned Mireclaw raid found.")
	return {}

func _assert_task_status(session, actor_id: String, expected_status: String, expected_target_id: String) -> void:
	var state := _enemy_state(session)
	var task_state: Dictionary = state.get("hero_task_state", {}) if state.get("hero_task_state", {}) is Dictionary else {}
	var tasks: Array = task_state.get("tasks", []) if task_state.get("tasks", []) is Array else []
	for task_value in tasks:
		if not (task_value is Dictionary):
			continue
		var task: Dictionary = task_value
		if String(task.get("actor_id", "")) != actor_id:
			continue
		if String(task.get("task_status", "")) != expected_status or String(task.get("target_id", "")) != expected_target_id:
			_fail("Task %s expected %s/%s, got %s" % [actor_id, expected_status, expected_target_id, JSON.stringify(task)])
		return
	_fail("Missing task for %s in %s" % [actor_id, JSON.stringify(task_state)])

func _string_array(value: Variant) -> Array:
	var output := []
	if not (value is Array):
		return output
	for item in value:
		var text := String(item)
		if text != "" and text not in output:
			output.append(text)
	return output

func _event_types(events: Variant) -> Array:
	var output := []
	if not (events is Array):
		return output
	for event_value in events:
		if not (event_value is Dictionary):
			continue
		var event_type := String(event_value.get("event_type", ""))
		if event_type != "" and event_type not in output:
			output.append(event_type)
	return output

func _fail(message: String) -> void:
	var payload := {"ok": false, "report_id": REPORT_ID, "error": message}
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	_failed = true
	get_tree().quit(1)
