extends Node

const REPORT_ID := "AI_TOWN_RETAKE_ASSAULT_REPORT"
const RIVER_PASS := "river-pass"
const MIRECLAW := "faction_mireclaw"

var _failed := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var case_report := _river_pass_retake_front_queues_town_battle()
	if case_report.is_empty():
		return
	var risk_case_report := _weak_river_pass_retake_front_stages_before_town_battle()
	if risk_case_report.is_empty():
		return
	var proactive_risk_case_report := _weak_river_pass_retake_front_regroups_before_marching()
	if proactive_risk_case_report.is_empty():
		return
	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"schema_status": "live_town_retake_assault_proactive_risk_no_save_migration",
		"behavior_policy": "enemy_retake_front_town_targets_queue_battles_with_proactive_risk_regroup",
		"save_policy": "hero_task_state_live_persist_no_save_migration",
		"case": case_report,
		"risk_case": risk_case_report,
		"proactive_risk_case": proactive_risk_case_report,
		"save_version_before": int(SessionStateStore.SAVE_VERSION),
		"save_version_after": int(SessionStateStore.SAVE_VERSION),
	}
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _river_pass_retake_front_queues_town_battle() -> Dictionary:
	var session = _base_session()
	var state := _enemy_state(session)
	state["pressure"] = 0
	_update_enemy_state(session, state)
	_set_player_captured_retake_front(session, "duskfen_bastion")
	var config := _enemy_config()
	var retake_plan := EnemyAdventureRules.choose_target(session, config, {"x": 7, "y": 2}, {})
	if String(retake_plan.get("target_kind", "")) != "town" or String(retake_plan.get("target_placement_id", "")) != "duskfen_bastion":
		_fail("Retake-front target selector did not prefer Duskfen: %s" % JSON.stringify(retake_plan))
		return {}
	var raid := _retake_raid_seed(session, "retake_assault_vaska", 8)
	var live_plan := EnemyAdventureRules.ai_live_town_retake_target_selection_plan(session, config, raid)
	if String(live_plan.get("target_kind", "")) != "town" or String(live_plan.get("target_placement_id", "")) != "duskfen_bastion":
		_fail("Live retake-front target selector did not prefer Duskfen: %s" % JSON.stringify(live_plan))
		return {}
	var encounters: Array = session.overworld.get("encounters", [])
	encounters.append(raid)
	session.overworld["encounters"] = encounters

	var result := EnemyTurnRules.run_enemy_turn(session)
	if not bool(result.get("ok", false)):
		_fail("Enemy turn failed during retake assault fixture: %s" % JSON.stringify(result))
		return {}
	var after_raid := _encounter(session, "retake_assault_vaska")
	if after_raid.is_empty():
		_fail("Retake raid disappeared after enemy turn.")
		return {}
	if session.battle.is_empty():
		_fail("Retake assault did not queue a town-defense battle: %s" % JSON.stringify(after_raid))
		return {}
	var battle_context: Dictionary = session.battle.get("context", {}) if session.battle.get("context", {}) is Dictionary else {}
	if String(battle_context.get("type", "")) != "town_defense":
		_fail("Retake assault queued wrong battle context: %s" % JSON.stringify(battle_context))
		return {}
	if String(battle_context.get("town_placement_id", "")) != "duskfen_bastion":
		_fail("Retake assault queued battle for wrong town: %s" % JSON.stringify(battle_context))
		return {}
	if String(after_raid.get("target_kind", "")) != "town" or String(after_raid.get("target_placement_id", "")) != "duskfen_bastion":
		_fail("Retake raid did not keep Duskfen as target: %s" % JSON.stringify(after_raid))
		return {}
	if int(after_raid.get("goal_distance", 9999)) > 1 and not bool(after_raid.get("arrived", false)):
		_fail("Retake raid did not reach town battle range: %s" % JSON.stringify(after_raid))
		return {}
	var event_types := _event_types(result.get("events", []))
	if "ai_target_assigned" not in event_types:
		_fail("Retake assault did not emit ai_target_assigned: %s" % JSON.stringify(result))
		return {}
	var public_log := EnemyAdventureRules.ai_public_event_log_boundary_report(result.get("events", []), 8)
	if not bool(public_log.get("ok", false)):
		_fail("Retake assault public event boundary failed: %s" % JSON.stringify(public_log))
		return {}
	if _public_event_leaks(public_log.get("public_events", [])):
		return {}
	_assert_saved_task_state(session)
	if _failed:
		return {}
	return {
		"case_id": "river_pass_retake_front_queues_town_defense_battle",
		"target_kind": String(after_raid.get("target_kind", "")),
		"target_id": String(after_raid.get("target_placement_id", "")),
		"goal_distance": int(after_raid.get("goal_distance", 9999)),
		"arrived": bool(after_raid.get("arrived", false)),
		"battle_context_type": String(battle_context.get("type", "")),
		"battle_town_id": String(battle_context.get("town_placement_id", "")),
		"live_selector_target_kind": String(live_plan.get("target_kind", "")),
		"live_selector_target_id": String(live_plan.get("target_placement_id", "")),
		"event_types": event_types,
		"public_event_count": int(public_log.get("public_event_count", 0)),
		"save_version": int(SessionStateStore.SAVE_VERSION),
	}

func _weak_river_pass_retake_front_stages_before_town_battle() -> Dictionary:
	var session = _base_session()
	var state := _enemy_state(session)
	state["pressure"] = 0
	_update_enemy_state(session, state)
	_set_player_captured_retake_front(session, "duskfen_bastion")
	var config := _enemy_config()
	var raid := _retake_raid_seed(session, "weak_retake_assault_vaska", 4)
	var encounters: Array = session.overworld.get("encounters", [])
	encounters.append(raid)
	session.overworld["encounters"] = encounters

	var result := EnemyTurnRules.run_enemy_turn(session)
	if not bool(result.get("ok", false)):
		_fail("Weak retake risk fixture failed enemy turn: %s" % JSON.stringify(result))
		return {}
	var after_raid := _encounter(session, "weak_retake_assault_vaska")
	if after_raid.is_empty():
		_fail("Weak retake raid disappeared after enemy turn.")
		return {}
	if not session.battle.is_empty():
		_fail("Weak retake assault incorrectly queued a town-defense battle: %s" % JSON.stringify(session.battle.get("context", {})))
		return {}
	var reason_codes := _string_array(after_raid.get("target_reason_codes", []))
	if "assault_risk_regroup" not in reason_codes and "assault_risk_staging" not in reason_codes:
		_fail("Weak retake assault did not record assault-risk retask/staging reason: %s" % JSON.stringify(after_raid))
		return {}
	if String(after_raid.get("target_public_reason", "")) != "staging stronger assault":
		_fail("Weak retake assault public reason was not staging stronger assault: %s" % JSON.stringify(after_raid))
		return {}
	if int(after_raid.get("assault_delay_until_day", 0)) <= int(session.day):
		_fail("Weak retake assault did not set a future assault delay: %s" % JSON.stringify(after_raid))
		return {}
	var event_types := _event_types(result.get("events", []))
	if "ai_target_assigned" not in event_types:
		_fail("Weak retake assault risk gating did not emit ai_target_assigned: %s" % JSON.stringify(result))
		return {}
	var public_log := EnemyAdventureRules.ai_public_event_log_boundary_report(result.get("events", []), 8)
	if not bool(public_log.get("ok", false)):
		_fail("Weak retake assault public event boundary failed: %s" % JSON.stringify(public_log))
		return {}
	if _public_event_leaks(public_log.get("public_events", [])):
		return {}
	_assert_saved_task_state(session)
	if _failed:
		return {}
	return {
		"case_id": "weak_retake_front_stages_before_town_battle",
		"target_kind": String(after_raid.get("target_kind", "")),
		"target_id": String(after_raid.get("target_placement_id", "")),
		"goal_distance": int(after_raid.get("goal_distance", 9999)),
		"arrived": bool(after_raid.get("arrived", false)),
		"battle_started": false,
		"assault_delay_until_day": int(after_raid.get("assault_delay_until_day", 0)),
		"target_public_reason": String(after_raid.get("target_public_reason", "")),
		"reason_codes": reason_codes,
		"event_types": event_types,
		"public_event_count": int(public_log.get("public_event_count", 0)),
		"save_version": int(SessionStateStore.SAVE_VERSION),
	}

func _weak_river_pass_retake_front_regroups_before_marching() -> Dictionary:
	var session = _base_session()
	var state := _enemy_state(session)
	state["pressure"] = 0
	_update_enemy_state(session, state)
	_set_player_captured_retake_front(session, "duskfen_bastion")
	_add_enemy_regroup_town(session, "risk_regroup_redoubt", {"x": 6, "y": 2})
	var config := _enemy_config()
	var raid := _retake_raid_seed(session, "proactive_risk_retake_vaska", 5, 4, 2)
	if EnemyAdventureRules.raid_regroup_needed(raid):
		_fail("Proactive risk fixture should be deployable before target assignment: %s" % JSON.stringify(raid))
		return {}
	var encounters: Array = session.overworld.get("encounters", [])
	encounters.append(raid)
	session.overworld["encounters"] = encounters

	var result := EnemyTurnRules.run_enemy_turn(session)
	if not bool(result.get("ok", false)):
		_fail("Proactive risk fixture failed enemy turn: %s" % JSON.stringify(result))
		return {}
	var after_raid := _encounter(session, "proactive_risk_retake_vaska")
	if after_raid.is_empty():
		_fail("Proactive risk raid disappeared after enemy turn.")
		return {}
	if not session.battle.is_empty():
		_fail("Proactive risk raid should not queue a town-defense battle: %s" % JSON.stringify(session.battle.get("context", {})))
		return {}
	if String(after_raid.get("target_kind", "")) != "regroup" or String(after_raid.get("target_placement_id", "")) != "risk_regroup_redoubt":
		_fail("Proactive risk raid should regroup at risk_regroup_redoubt before marching: %s" % JSON.stringify(after_raid))
		return {}
	if String(after_raid.get("previous_target_kind", "")) != "town" or String(after_raid.get("previous_target_placement_id", "")) != "duskfen_bastion":
		_fail("Proactive risk regroup did not preserve the risky town target metadata: %s" % JSON.stringify(after_raid))
		return {}
	var reason_codes := _string_array(after_raid.get("target_reason_codes", []))
	if "assault_risk_regroup" not in reason_codes or "town_siege" not in reason_codes:
		_fail("Proactive risk regroup missed assault risk reason codes: %s" % JSON.stringify(after_raid))
		return {}
	if int(after_raid.get("x", 0)) != 5 or int(after_raid.get("y", 0)) != 2:
		_fail("Proactive risk raid should move toward regroup town, not Duskfen: %s" % JSON.stringify(after_raid))
		return {}
	var event_types := _event_types(result.get("events", []))
	if "ai_target_assigned" not in event_types:
		_fail("Proactive risk regroup did not emit ai_target_assigned: %s" % JSON.stringify(result))
		return {}
	var public_log := EnemyAdventureRules.ai_public_event_log_boundary_report(result.get("events", []), 8)
	if not bool(public_log.get("ok", false)):
		_fail("Proactive risk regroup public event boundary failed: %s" % JSON.stringify(public_log))
		return {}
	if _public_event_leaks(public_log.get("public_events", [])):
		return {}
	return {
		"case_id": "weak_retake_front_regroups_before_marching",
		"target_kind": String(after_raid.get("target_kind", "")),
		"target_id": String(after_raid.get("target_placement_id", "")),
		"previous_target_kind": String(after_raid.get("previous_target_kind", "")),
		"previous_target_id": String(after_raid.get("previous_target_placement_id", "")),
		"position_after": {"x": int(after_raid.get("x", 0)), "y": int(after_raid.get("y", 0))},
		"battle_started": false,
		"reason_codes": reason_codes,
		"event_types": event_types,
		"public_event_count": int(public_log.get("public_event_count", 0)),
		"save_version": int(SessionStateStore.SAVE_VERSION),
	}

func _retake_raid_seed(session, placement_id: String, bog_brute_count: int, x: int = 7, y: int = 2) -> Dictionary:
	var raid := {
		"placement_id": placement_id,
		"encounter_id": "encounter_mire_raid",
		"x": x,
		"y": y,
		"difficulty": "pressure",
		"combat_seed": hash("%s:%s" % [String(session.scenario_id), placement_id]),
		"spawned_by_faction_id": MIRECLAW,
		"days_active": 0,
		"arrived": false,
		"goal_distance": 9999,
		"enemy_army": {
			"id": "%s_host" % placement_id,
			"name": "Retake Assault Host",
			"stacks": [{"unit_id": "unit_bog_brute", "count": bog_brute_count}],
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

func _add_enemy_regroup_town(session, placement_id: String, position: Dictionary) -> void:
	var towns: Array = session.overworld.get("towns", [])
	towns.append(
		{
			"placement_id": placement_id,
			"town_id": "town_duskfen",
			"x": int(position.get("x", 0)),
			"y": int(position.get("y", 0)),
			"owner": "enemy",
			"controlling_faction_id": MIRECLAW,
			"garrison": [{"unit_id": "unit_bog_brute", "count": 4}],
		}
	)
	session.overworld["towns"] = towns

func _encounter(session, placement_id: String) -> Dictionary:
	for encounter in session.overworld.get("encounters", []):
		if encounter is Dictionary and String(encounter.get("placement_id", "")) == placement_id:
			return encounter
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

func _string_array(value: Variant) -> Array:
	var result := []
	if not (value is Array):
		return result
	for item in value:
		var text := String(item)
		if text != "":
			result.append(text)
	result.sort()
	return result

func _assert_saved_task_state(session) -> void:
	for state in session.overworld.get("enemy_states", []):
		if state is Dictionary and String(state.get("faction_id", "")) == MIRECLAW and state.has("hero_task_state"):
			return
	_fail("Retake assault did not persist hero_task_state.")

func _public_event_leaks(public_events: Variant) -> bool:
	var forbidden_tokens := ["target_debug_reason", "hero_task_state", "task_id", "reservation_key", "garrison_score", "raid_score"]
	var encoded := JSON.stringify(public_events)
	for token in forbidden_tokens:
		if encoded.find(token) >= 0:
			_fail("Retake assault public events leaked internal token %s" % token)
			return true
	return false

func _fail(message: String) -> void:
	var payload := {"ok": false, "report_id": REPORT_ID, "error": message}
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	_failed = true
	get_tree().quit(1)
