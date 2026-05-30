extends Node

const REPORT_ID := "AI_TOWN_DEFENSE_RETASK_REPORT"
const RIVER_PASS := "river-pass"
const MIRECLAW := "faction_mireclaw"

var _failed := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var case_report := _river_pass_raid_retasks_to_stabilizing_town()
	if case_report.is_empty():
		return
	var payload := {
		"ok": true,
		"report_id": REPORT_ID,
		"schema_status": "live_town_defense_retask_no_save_migration",
		"behavior_policy": "active_raids_defend_threatened_owned_town_fronts",
		"save_policy": "hero_task_state_live_persist_no_save_migration",
		"case": case_report,
		"save_version_before": int(SessionStateStore.SAVE_VERSION),
		"save_version_after": int(SessionStateStore.SAVE_VERSION),
	}
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	get_tree().quit(0)

func _river_pass_raid_retasks_to_stabilizing_town() -> Dictionary:
	var session = _base_session()
	var config := _enemy_config()
	var state := _enemy_state(session)
	state["pressure"] = 0
	_update_enemy_state(session, state)
	_set_stabilizing_front(session, "duskfen_bastion")
	_set_player_position(session, {"x": 6, "y": 2})
	_set_resource_controller(session, "river_free_company", "player")
	var raid := _defense_retask_raid(session)
	if EnemyAdventureRules.raid_regroup_needed(raid):
		_fail("Fixture raid should be strong enough to avoid regroup before defense retask: %s" % JSON.stringify(raid))
		return {}
	var encounters: Array = session.overworld.get("encounters", [])
	encounters.append(raid)
	session.overworld["encounters"] = encounters

	var result := EnemyAdventureRules.advance_raids(session, config, MIRECLAW, state)
	var after_raid := _encounter(session, "defense_retask_vaska")
	if after_raid.is_empty():
		_fail("Defense retask raid disappeared after advance.")
		return {}
	var event_types := _event_types(result.get("events", []))
	if "ai_target_assigned" not in event_types:
		_fail("Defense retask did not emit ai_target_assigned: %s" % JSON.stringify(result))
		return {}
	if String(after_raid.get("target_kind", "")) != "town":
		_fail("Defense retask did not target a town: %s" % JSON.stringify(after_raid))
		return {}
	if String(after_raid.get("target_placement_id", "")) != "duskfen_bastion":
		_fail("Defense retask targeted wrong town: %s" % JSON.stringify(after_raid))
		return {}
	var reason_codes := _string_array(after_raid.get("target_reason_codes", []))
	if "town_defense" not in reason_codes or "front_stabilization" not in reason_codes:
		_fail("Defense retask missing public reason codes: %s" % JSON.stringify(reason_codes))
		return {}
	if String(after_raid.get("previous_target_placement_id", "")) != "river_free_company":
		_fail("Defense retask did not preserve previous offensive target metadata: %s" % JSON.stringify(after_raid))
		return {}
	if _resource_controller(session, "river_free_company") == MIRECLAW:
		_fail("Defense retask still captured the previous resource target.")
		return {}
	var public_log := EnemyAdventureRules.ai_public_event_log_boundary_report(result.get("events", []), 8)
	if not bool(public_log.get("ok", false)):
		_fail("Defense retask public event boundary failed: %s" % JSON.stringify(public_log))
		return {}
	if _public_event_leaks(public_log.get("public_events", [])):
		return {}
	_assert_saved_task_state(session)
	if _failed:
		return {}
	return {
		"case_id": "river_pass_active_raid_defends_stabilizing_duskfen",
		"before_target_id": "river_free_company",
		"after_target_kind": String(after_raid.get("target_kind", "")),
		"after_target_id": String(after_raid.get("target_placement_id", "")),
		"target_public_reason": String(after_raid.get("target_public_reason", "")),
		"target_reason_codes": reason_codes,
		"event_types": event_types,
		"resource_controller_after": _resource_controller(session, "river_free_company"),
		"public_event_count": int(public_log.get("public_event_count", 0)),
		"save_version": int(SessionStateStore.SAVE_VERSION),
	}

func _defense_retask_raid(session) -> Dictionary:
	var raid := {
		"placement_id": "defense_retask_vaska",
		"encounter_id": "encounter_mire_raid",
		"x": 6,
		"y": 2,
		"difficulty": "pressure",
		"combat_seed": hash("%s:defense_retask_vaska" % String(session.scenario_id)),
		"spawned_by_faction_id": MIRECLAW,
		"days_active": 0,
		"arrived": false,
		"goal_distance": 9999,
		"target_kind": "resource",
		"target_placement_id": "river_free_company",
		"target_label": "Free Company Camp",
		"target_x": 0,
		"target_y": 4,
		"goal_x": 0,
		"goal_y": 4,
		"enemy_army": {
			"id": "defense_retask_fixture_host",
			"name": "Defense Retask Host",
			"stacks": [{"unit_id": "unit_bog_brute", "count": 8}],
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

func _set_stabilizing_front(session, placement_id: String) -> void:
	var towns: Array = session.overworld.get("towns", [])
	for index in range(towns.size()):
		var town = towns[index]
		if not (town is Dictionary) or String(town.get("placement_id", "")) != placement_id:
			continue
		town["front"] = {
			"state": "stabilizing",
			"faction_id": MIRECLAW,
			"last_change_day": max(0, int(session.day) - 1),
			"stabilize_until_day": int(session.day) + 4,
			"last_owner": "player",
			"capture_count": 1,
			"source": "test_fixture",
		}
		towns[index] = town
		session.overworld["towns"] = towns
		return
	_fail("Could not find town %s for stabilizing front fixture." % placement_id)

func _set_player_position(session, position: Dictionary) -> void:
	session.overworld["hero_position"] = {"x": int(position.get("x", 0)), "y": int(position.get("y", 0))}
	var heroes: Array = session.overworld.get("heroes", [])
	for index in range(heroes.size()):
		var hero = heroes[index]
		if hero is Dictionary and String(hero.get("owner", "player")) == "player":
			hero["position"] = session.overworld["hero_position"].duplicate(true)
			heroes[index] = hero
			session.overworld["heroes"] = heroes
			return

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

func _assert_saved_task_state(session) -> void:
	for state in session.overworld.get("enemy_states", []):
		if state is Dictionary and String(state.get("faction_id", "")) == MIRECLAW and state.has("hero_task_state"):
			return
	_fail("Defense retask did not persist hero_task_state.")

func _public_event_leaks(public_events: Variant) -> bool:
	var forbidden_tokens := ["target_debug_reason", "hero_task_state", "task_id", "reservation_key", "garrison_score", "raid_score"]
	var encoded := JSON.stringify(public_events)
	for token in forbidden_tokens:
		if encoded.find(token) >= 0:
			_fail("Defense retask public events leaked internal token %s" % token)
			return true
	return false

func _fail(message: String) -> void:
	var payload := {"ok": false, "report_id": REPORT_ID, "error": message}
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify(payload)])
	_failed = true
	get_tree().quit(1)
