extends Node

const REPORT_ID := "OVERWORLD_INTERACTABLE_CONFIRMATION_OPTIMIZATION_REGRESSION"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not _assert_scenario_event_gating():
		return
	if not _assert_resource_blocked_index_full_fallback():
		return
	if not _assert_artifact_descriptor_scan_fallback():
		return
	if not _assert_encounter_and_town_descriptor_coverage():
		return
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": true})])
	get_tree().quit(0)

func _assert_scenario_event_gating() -> bool:
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	var resource_result: Dictionary = ScenarioRules.evaluate_session_for_event(session, {
		"event_type": "interactable_resolved",
		"family": "resource_site",
		"placement_id": "unrelated_cache",
		"resources": ["wood"],
	})
	var resource_profile: Dictionary = resource_result.get("profile", {}) if resource_result.get("profile", {}) is Dictionary else {}
	if String(resource_profile.get("dependency_mode", "")) != "event_gated_skip":
		return _fail("Unrelated resource event did not use event-gated scenario skip.", resource_profile)
	if int(resource_profile.get("objectives_skipped", 0)) <= 0 or int(resource_profile.get("hooks_skipped", 0)) <= 0:
		return _fail("Unrelated resource event did not report skipped objective/hook counts.", resource_profile)

	var town_result: Dictionary = ScenarioRules.evaluate_session_for_event(session, {
		"event_type": "town_control_changed",
		"family": "town",
		"town_placement_ids": ["duskfen_bastion"],
	})
	var town_profile: Dictionary = town_result.get("profile", {}) if town_result.get("profile", {}) is Dictionary else {}
	if String(town_profile.get("dependency_mode", "")) != "scoped" or int(town_profile.get("affected_objective_count", 0)) <= 0:
		return _fail("Objective-affecting town event did not use scoped/full semantic evaluation.", town_profile)

	var encounter_result: Dictionary = ScenarioRules.evaluate_session_for_event(session, {
		"event_type": "encounter_resolved",
		"family": "encounter",
		"encounter_placement_ids": ["river_pass_reed_totemists"],
	})
	var encounter_profile: Dictionary = encounter_result.get("profile", {}) if encounter_result.get("profile", {}) is Dictionary else {}
	if String(encounter_profile.get("dependency_mode", "")) != "scoped" or int(encounter_profile.get("affected_objective_count", 0)) <= 0:
		return _fail("Objective-affecting encounter event did not use scoped/full semantic evaluation.", encounter_profile)

	session.scenario_status = "victory"
	var inactive_result: Dictionary = ScenarioRules.evaluate_session_for_event(session, {
		"event_type": "interactable_resolved",
		"family": "resource_site",
	})
	var inactive_profile: Dictionary = inactive_result.get("profile", {}) if inactive_result.get("profile", {}) is Dictionary else {}
	if String(inactive_profile.get("dependency_mode", "")) != "full_fallback_not_in_progress":
		return _fail("Completed scenario did not expose full fallback status mode.", inactive_profile)
	return true

func _assert_resource_blocked_index_full_fallback() -> bool:
	var session = _session_with_map(4, 3)
	session.overworld["resource_nodes"] = [{
		"placement_id": "resource_full_rebuild_cache",
		"site_id": "site_wood_wagon",
		"x": 1,
		"y": 1,
		"collected": false,
		"collected_by_faction_id": "",
	}]
	_prepare_session(session, Vector2i(0, 1), 3)
	var result := _execute_with_profile(session, [Vector2i(0, 1), Vector2i(1, 1)], {
		"kind": "resource",
		"placement_id": "resource_full_rebuild_cache",
		"site_id": "site_wood_wagon",
		"x": 1,
		"y": 1,
	})
	if not bool(result.get("ok", false)):
		return _fail("Resource descriptor execution failed.", result)
	var route_execution: Dictionary = result.get("route_execution", {}) if result.get("route_execution", {}) is Dictionary else {}
	var blocked_index: Dictionary = route_execution.get("blocked_index", {}) if route_execution.get("blocked_index", {}) is Dictionary else {}
	if String(blocked_index.get("mode", "")) != "skipped" or bool(blocked_index.get("rebuilt", true)):
		return _fail("Resource interaction with unchanged topology did not skip the blocked-index rebuild.", route_execution)
	OverworldRules.validation_set_pathing_profile_capture_enabled(true)
	OverworldRules._refresh_blocked_tile_index_for_interaction(session, {
		"contract_known": false,
		"blocks_changed": true,
		"body_tiles_changed": true,
		"fallback_reason": "test_unknown_contract",
	})
	var rebuilds_after := int(OverworldRules.validation_pathing_profile_snapshot().get("blocked_index_rebuild_count", 0))
	OverworldRules.validation_set_pathing_profile_capture_enabled(false)
	if rebuilds_after <= 0:
		return _fail("Unknown topology contract did not force blocked-index full fallback.", OverworldRules.validation_pathing_profile_snapshot())
	var scenario_eval: Dictionary = route_execution.get("scenario_eval", {}) if route_execution.get("scenario_eval", {}) is Dictionary else {}
	if String(scenario_eval.get("dependency_mode", "")) != "event_gated_skip":
		return _fail("Unrelated resource confirmation did not event-gate scenario evaluation.", route_execution)
	var interactable: Dictionary = route_execution.get("interactable", {}) if route_execution.get("interactable", {}) is Dictionary else {}
	if String(interactable.get("family", "")) != "resource_site":
		return _fail("Resource confirmation did not expose shared interactable facts.", route_execution)
	return true

func _assert_artifact_descriptor_scan_fallback() -> bool:
	var session = _session_with_map(4, 3)
	session.overworld["artifact_nodes"] = [{
		"placement_id": "artifact_scan_cache",
		"artifact_id": "artifact_trailsinger_boots",
		"x": 1,
		"y": 1,
		"collected": false,
	}]
	_prepare_session(session, Vector2i(0, 1), 3)
	var result := _execute_with_profile(session, [Vector2i(0, 1), Vector2i(1, 1)], {
		"kind": "artifact",
		"artifact_id": "artifact_trailsinger_boots",
		"x": 1,
		"y": 1,
	})
	if not bool(result.get("ok", false)):
		return _fail("Artifact descriptor execution failed.", result)
	var route_execution: Dictionary = result.get("route_execution", {}) if result.get("route_execution", {}) is Dictionary else {}
	var descriptor: Dictionary = route_execution.get("descriptor", {}) if route_execution.get("descriptor", {}) is Dictionary else {}
	if String(descriptor.get("lookup_mode", "")) != "full_scan_fallback":
		return _fail("Artifact descriptor without placement id did not use scan fallback.", route_execution)
	var blocked_index: Dictionary = route_execution.get("blocked_index", {}) if route_execution.get("blocked_index", {}) is Dictionary else {}
	if String(blocked_index.get("mode", "")) != "not_applicable" or bool(blocked_index.get("rebuilt", true)):
		return _fail("Artifact confirmation should not rebuild the resource blocked index.", route_execution)
	var interactable: Dictionary = route_execution.get("interactable", {}) if route_execution.get("interactable", {}) is Dictionary else {}
	if String(interactable.get("family", "")) != "artifact":
		return _fail("Artifact confirmation did not expose shared interactable facts.", route_execution)
	return true

func _assert_encounter_and_town_descriptor_coverage() -> bool:
	var encounter_session = _session_with_map(4, 3)
	encounter_session.overworld["encounters"] = [{
		"placement_id": "descriptor_guard",
		"encounter_id": "encounter_ghoul_grove",
		"x": 1,
		"y": 1,
		"difficulty": "low",
	}]
	_prepare_session(encounter_session, Vector2i(0, 1), 3)
	var encounter_result := _execute_with_profile(encounter_session, [Vector2i(0, 1), Vector2i(1, 1)], {
		"kind": "encounter",
		"placement_id": "descriptor_guard",
		"encounter_id": "encounter_ghoul_grove",
		"x": 1,
		"y": 1,
	})
	var encounter_execution: Dictionary = encounter_result.get("route_execution", {}) if encounter_result.get("route_execution", {}) is Dictionary else {}
	if String(encounter_result.get("route", "")) != "battle" or String(encounter_execution.get("interactable", {}).get("family", "")) != "encounter":
		return _fail("Encounter descriptor did not preserve battle route handoff and interactable facts.", encounter_result)
	if String(encounter_execution.get("descriptor", {}).get("lookup_mode", "")) != "placement_index":
		return _fail("Encounter descriptor did not use placement index lookup.", encounter_execution)

	var town_session = _session_with_map(4, 3)
	town_session.overworld["towns"] = [{
		"placement_id": "descriptor_town",
		"town_id": "town_riverwatch",
		"x": 1,
		"y": 1,
		"owner": "player",
	}]
	_prepare_session(town_session, Vector2i(0, 1), 3)
	var town_result := _execute_with_profile(town_session, [Vector2i(0, 1), Vector2i(1, 1)], {
		"kind": "town",
		"placement_id": "descriptor_town",
		"town_id": "town_riverwatch",
		"owner": "player",
		"x": 1,
		"y": 1,
	})
	var town_execution: Dictionary = town_result.get("route_execution", {}) if town_result.get("route_execution", {}) is Dictionary else {}
	if String(town_result.get("route", "")) != "town" or String(town_execution.get("interactable", {}).get("family", "")) != "town":
		return _fail("Town descriptor did not preserve town route handoff and interactable facts.", town_result)
	if String(town_execution.get("scenario_eval", {}).get("dependency_mode", "")) != "event_gated_skip":
		return _fail("Town visit without control change should event-gate scenario evaluation.", town_execution)
	return true

func _execute_with_profile(session, route: Array, descriptor: Dictionary) -> Dictionary:
	OverworldRules.validation_set_pathing_profile_capture_enabled(true)
	var result: Dictionary = OverworldRules.execute_prevalidated_route(session, route, {}, -1, descriptor)
	OverworldRules.validation_set_pathing_profile_capture_enabled(false)
	return result

func _session_with_map(width: int, height: int):
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var rows := []
	for _y in range(height):
		var row := []
		for _x in range(width):
			row.append("grass")
		rows.append(row)
	session.overworld["map"] = rows
	session.overworld["map_size"] = {"width": width, "height": height, "x": width, "y": height}
	session.overworld["terrain_layers"] = {}
	session.overworld["towns"] = []
	session.overworld["resource_nodes"] = []
	session.overworld["artifact_nodes"] = []
	session.overworld["encounters"] = []
	session.overworld["resolved_encounters"] = []
	return session

func _prepare_session(session, position: Vector2i, movement_points: int) -> void:
	var position_payload := {"x": position.x, "y": position.y}
	session.overworld["hero_position"] = position_payload.duplicate(true)
	var movement := {"current": movement_points, "max": movement_points}
	session.overworld["movement"] = movement.duplicate(true)
	var hero: Dictionary = session.overworld.get("hero", {}) if session.overworld.get("hero", {}) is Dictionary else {}
	hero["position"] = position_payload.duplicate(true)
	hero["movement"] = movement.duplicate(true)
	session.overworld["hero"] = hero
	var active_hero_id := String(session.overworld.get("active_hero_id", hero.get("id", "")))
	var heroes: Array = session.overworld.get("player_heroes", []) if session.overworld.get("player_heroes", []) is Array else []
	for index in range(heroes.size()):
		if not (heroes[index] is Dictionary):
			continue
		var entry: Dictionary = heroes[index]
		if String(entry.get("id", "")) == active_hero_id:
			entry["position"] = position_payload.duplicate(true)
			entry["movement"] = movement.duplicate(true)
			heroes[index] = entry
			break
	session.overworld["player_heroes"] = heroes
	session.overworld["fog"] = {}
	OverworldRules.refresh_fog_of_war(session)

func _fail(message: String, payload: Variant = {}) -> bool:
	push_error("%s failed: %s %s" % [REPORT_ID, message, JSON.stringify(payload)])
	get_tree().quit(1)
	return false
