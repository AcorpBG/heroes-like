extends Node

const REPORT_ID := "OVERWORLD_ENEMY_ROUTE_CLOSURE_FEEDBACK_REPORT"
const SCENARIO_ID := "ninefold-confluence"
const PLACEMENT_ID := "rope_lift"
const ENEMY_FACTION_ID := "faction_sunvault"
const SITE_TILE := Vector2i(9, 52)
const CLAIM_START_TILE := Vector2i(9, 50)
const HERO_TILE := Vector2i(9, 51)
const OBSERVER_TILE := Vector2i(11, 52)
const TEXTURE_PATH := "res://art/overworld/runtime/vfx/route_closed.png"
const AUDIO_PATH := "res://art/audio/runtime/presentation/route_closed.wav"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var original_session = SessionState.active_session
	var original_window_size := get_window().size
	var original_reduced_motion := SettingsService.reduced_motion_enabled()
	var rows: Array = []
	for viewport_size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		SettingsService.set_reduced_motion_enabled(false)
		var row := await _run_case(viewport_size, "normal")
		rows.append(row)
		if not bool(row.get("ok", false)):
			await _finish(original_session, original_window_size, original_reduced_motion, "Normal route-closure row failed", row)
			return
	SettingsService.set_reduced_motion_enabled(true)
	var reduced := await _run_case(Vector2i(1280, 720), "reduced")
	if not bool(reduced.get("ok", false)):
		await _finish(original_session, original_window_size, original_reduced_motion, "Reduced route-closure row failed", reduced)
		return
	SettingsService.set_reduced_motion_enabled(false)
	var missing := await _run_case(Vector2i(1280, 720), "missing")
	if not bool(missing.get("ok", false)):
		await _finish(original_session, original_window_size, original_reduced_motion, "Missing route-closure row failed", missing)
		return
	SessionState.set_active_session(original_session)
	SettingsService.set_reduced_motion_enabled(original_reduced_motion)
	get_window().size = original_window_size
	await get_tree().process_frame
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"viewports": [[1280, 720], [1920, 1080]],
		"normal_rows": rows,
		"reduced": reduced,
		"missing": missing,
		"save_version": SessionState.SAVE_VERSION,
	})])
	get_tree().quit(0)

func _run_case(viewport_size: Vector2i, mode: String) -> Dictionary:
	get_window().size = viewport_size
	await get_tree().process_frame
	await get_tree().process_frame
	var fixture: Dictionary = _closure_ready_session()
	var session = fixture.get("session")
	var response_result: Dictionary = fixture.get("response_result", {})
	var day_before := int(session.day)
	var edges_before: Array = OverworldRules.active_linked_transit_edges(session)
	var authority_before: Dictionary = session.to_dict()
	session = SessionState.set_active_session(session)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	shell.call("validation_set_end_turn_resolution_routing_enabled", false)
	var map_view: Node = shell.get_node("%Map")
	if mode == "missing":
		map_view.set("_overworld_vfx_texture_missing", {TEXTURE_PATH: true})
	PresentationAudio.validation_reset()
	var end_result: Dictionary = shell.call("validation_end_turn")
	await get_tree().process_frame
	var end_snapshot: Dictionary = shell.call("validation_end_turn_confirmation_snapshot")
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var cue := _cue_from_snapshot(snapshot)
	var rule_result: Dictionary = end_snapshot.get("last_rule_result", {}) if end_snapshot.get("last_rule_result", {}) is Dictionary else {}
	var public_events: Array = (rule_result.get("enemy_activity_events", []) as Array).duplicate(true)
	var closure_event := _closure_event(public_events)
	var live_node := _resource_node(session, PLACEMENT_ID)
	var edges_after: Array = OverworldRules.active_linked_transit_edges(session)
	var consequence_checks := {
		"response_ok": bool(response_result.get("ok", false)),
		"edge_before_exact": edges_before.size() == 1,
		"end_ok": bool(end_result.get("ok", false)),
		"committed": int(end_snapshot.get("commit_count", 0)) == 1 and int(end_snapshot.get("rules_end_turn_call_count", 0)) == 1,
		"autosave_exact": int(end_snapshot.get("autosave_call_count", 0)) == 1 and int(end_snapshot.get("autosave_failure_count", 0)) == 0,
		"not_routed": int(end_snapshot.get("resolution_attempt_count", 0)) == 0 and (end_snapshot.get("last_resolution_route", {}) as Dictionary).is_empty(),
		"day_advanced": int(session.day) == day_before + 1,
		"event_exact": not closure_event.is_empty(),
		"controller_exact": String(live_node.get("collected_by_faction_id", "")) == ENEMY_FACTION_ID,
		"response_cleared": int(live_node.get("response_last_day", -1)) == 0 and int(live_node.get("response_until_day", -1)) == 0,
		"edge_after_exact": edges_after.is_empty(),
	}
	var consequence_exact: bool = not consequence_checks.values().has(false)
	var presentation_exact := _presentation_exact(cue, mode)
	var authority_after: Dictionary = session.to_dict()
	var records_after: Array = PresentationAudio.validation_records().duplicate(true)
	var serial := int(cue.get("serial", 0))
	shell.call("_refresh")
	await get_tree().process_frame
	var refreshed := _cue_from_snapshot(shell.call("validation_snapshot"))
	var dedupe_exact: bool = int(refreshed.get("serial", -1)) == serial \
		and PresentationAudio.validation_records() == records_after \
		and session.to_dict() == authority_after
	var restored = SessionState.new_session_data()
	restored.from_dict(authority_after)
	var save_exact: bool = restored.save_version == SessionState.SAVE_VERSION \
		and OverworldRules.active_linked_transit_edges(restored).is_empty() \
		and String(_resource_node(restored, PLACEMENT_ID).get("collected_by_faction_id", "")) == ENEMY_FACTION_ID
	var map_rect: Rect2 = map_view.get_global_rect()
	var contained := get_viewport().get_visible_rect().encloses(map_rect)
	var summary: Dictionary = map_view.call("validation_object_resolution_vfx_asset_summary")
	var manifest_exact: bool = int(summary.get("mapped_cue_count", 0)) == 16 \
		and int(summary.get("unique_texture_count", 0)) == 16 \
		and "vfx_placeholder_route_closed" in summary.get("mapped_cue_ids", [])
	var payload := {
		"ok": consequence_exact and presentation_exact and dedupe_exact and save_exact and contained and manifest_exact,
		"mode": mode,
		"viewport": [viewport_size.x, viewport_size.y],
		"consequence_exact": consequence_exact,
		"consequence_checks": consequence_checks,
		"closure_event": closure_event,
		"edges_before": edges_before,
		"edges_after": edges_after,
		"presentation_exact": presentation_exact,
		"dedupe_exact": dedupe_exact,
		"save_exact": save_exact,
		"contained": contained,
		"manifest_exact": manifest_exact,
		"cue": cue,
		"authority_changed": authority_before != authority_after,
	}
	shell.queue_free()
	await get_tree().process_frame
	return payload

func _presentation_exact(cue: Dictionary, mode: String) -> bool:
	var asset: Dictionary = cue.get("vfx_asset", {}) if cue.get("vfx_asset", {}) is Dictionary else {}
	var draw: Dictionary = cue.get("vfx_draw", {}) if cue.get("vfx_draw", {}) is Dictionary else {}
	var records: Array = cue.get("audio_playback_records", []) if cue.get("audio_playback_records", []) is Array else []
	var audio: Dictionary = records[0] if records.size() == 1 and records[0] is Dictionary else {}
	var expected_draw := "route_closed_icon" if mode == "reduced" else ("procedural_route_closed_marker" if mode == "missing" else "imported_texture")
	var expected_vfx := ["route_closed_icon"] if mode == "reduced" else ["vfx_placeholder_route_closed"]
	return int(cue.get("serial", 0)) > 0 \
		and String(cue.get("event_id", "")) == "overworld_route_closed" \
		and String(cue.get("family", "")) == "route_closure" \
		and String(cue.get("placement_id", "")) == PLACEMENT_ID \
		and cue.get("tile", {}) == {"x": SITE_TILE.x, "y": SITE_TILE.y} \
		and cue.get("selected_vfx_cue_ids", []) == expected_vfx \
		and cue.get("selected_audio_cue_ids", []) == ["audio_placeholder_route_closed"] \
		and String(draw.get("mode", "")) == expected_draw \
		and bool(asset.get("uses_imported_asset", false)) == (mode == "normal") \
		and bool(asset.get("uses_procedural_fallback", false)) == (mode != "normal") \
		and records.size() == 1 \
		and String(audio.get("cue_id", "")) == "audio_placeholder_route_closed" \
		and String(audio.get("source", "")) == "OverworldMapView.route_closed" \
		and String(audio.get("asset_path", "")) == AUDIO_PATH \
		and String(audio.get("playback_source", "")) == "imported_wav" \
		and int(audio.get("stream_mix_rate", 0)) == 44100 \
		and bool(audio.get("stream_stereo", false))

func _closure_event(events: Array) -> Dictionary:
	for event_value in events:
		if not (event_value is Dictionary):
			continue
		var event: Dictionary = event_value
		var reason_codes: Array = event.get("reason_codes", []) if event.get("reason_codes", []) is Array else []
		if String(event.get("event_type", "")) == "ai_site_seized" \
				and String(event.get("target_id", "")) == PLACEMENT_ID \
				and "route_closed" in reason_codes:
			return event.duplicate(true)
	return {}

func _cue_from_snapshot(snapshot: Dictionary) -> Dictionary:
	var viewport: Dictionary = snapshot.get("map_viewport", {}) if snapshot.get("map_viewport", {}) is Dictionary else {}
	return viewport.get("object_resolution_presentation", {}).duplicate(true) if viewport.get("object_resolution_presentation", {}) is Dictionary else {}

func _closure_ready_session() -> Dictionary:
	var session = ScenarioFactory.create_session(SCENARIO_ID, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	_set_position(session, CLAIM_START_TILE)
	_set_movement(session, 20)
	OverworldRules.normalize_overworld_state_for_runtime(session)
	OverworldRules.refresh_fog_of_war(session)
	var claim_result: Dictionary = OverworldRules.try_move_along_route(session, [CLAIM_START_TILE, HERO_TILE], 20)
	if not bool(claim_result.get("ok", false)):
		return {"session": session, "response_result": claim_result}
	var resources: Dictionary = (session.overworld.get("resources", {}) as Dictionary).duplicate(true)
	resources["gold"] = maxi(500, int(resources.get("gold", 0)))
	resources["ore"] = maxi(5, int(resources.get("ore", 0)))
	session.overworld["resources"] = resources
	_set_movement(session, 10)
	var response_result: Dictionary = OverworldRules.perform_context_action(session, "site_response")
	_set_position(session, OBSERVER_TILE)
	_set_movement(session, 10)
	OverworldRules.refresh_fog_of_war(session)
	_configure_enemy_route_seizure(session)
	return {"session": session, "response_result": response_result}

func _configure_enemy_route_seizure(session) -> void:
	EnemyTurnRules.normalize_enemy_states(session)
	EnemyAdventureRules.normalize_all_commander_rosters(session)
	var config := _enemy_config()
	var roster: Array = EnemyAdventureRules.commander_roster_for_faction(session, ENEMY_FACTION_ID)
	var roster_hero_id := String((roster[0] as Dictionary).get("roster_hero_id", "")) if not roster.is_empty() and roster[0] is Dictionary else ""
	var encounter_ids: Array = config.get("raid_encounter_ids", []) if config.get("raid_encounter_ids", []) is Array else []
	var encounter_id := String(encounter_ids[0]) if not encounter_ids.is_empty() else ""
	var raid := {
		"placement_id": "route_closure_sunvault_host",
		"encounter_id": encounter_id,
		"x": SITE_TILE.x,
		"y": SITE_TILE.y,
		"difficulty": "pressure",
		"combat_seed": hash("%s:route-closure" % SCENARIO_ID),
		"spawned_by_faction_id": ENEMY_FACTION_ID,
		"days_active": 1,
		"arrived": true,
		"target_kind": "resource",
		"target_placement_id": PLACEMENT_ID,
		"target_label": "Rope Lift",
		"target_x": SITE_TILE.x,
		"target_y": SITE_TILE.y,
		"goal_x": SITE_TILE.x,
		"goal_y": SITE_TILE.y,
		"goal_distance": 0,
		"target_reason_codes": ["site_contested", "route_pressure"],
		"target_public_reason": "route pressure",
		"target_public_importance": "high",
		"target_debug_reason": "focused route-closure fixture",
	}
	raid["enemy_commander_state"] = EnemyAdventureRules.build_raid_commander_state(
		raid,
		roster_hero_id,
		ENEMY_FACTION_ID,
		session,
		{},
		roster
	)
	raid = EnemyAdventureRules.ensure_raid_army(raid, session)
	var encounters: Array = session.overworld.get("encounters", []) if session.overworld.get("encounters", []) is Array else []
	encounters.append(raid)
	session.overworld["encounters"] = encounters

func _enemy_config() -> Dictionary:
	var scenario := ContentService.get_scenario(SCENARIO_ID)
	for config_value in scenario.get("enemy_factions", []):
		if config_value is Dictionary and String(config_value.get("faction_id", "")) == ENEMY_FACTION_ID:
			return config_value
	return {}

func _resource_node(session, placement_id: String) -> Dictionary:
	for node_value in session.overworld.get("resource_nodes", []):
		if node_value is Dictionary and String(node_value.get("placement_id", "")) == placement_id:
			return node_value
	return {}

func _set_position(session, tile: Vector2i) -> void:
	OverworldRules._set_active_hero_position(session, tile)

func _set_movement(session, points: int) -> void:
	var movement: Dictionary = session.overworld.get("movement", {}).duplicate(true)
	movement["current"] = points
	movement["max"] = maxi(points, int(movement.get("max", 0)))
	session.overworld["movement"] = movement.duplicate(true)
	var hero: Dictionary = session.overworld.get("hero", {}).duplicate(true)
	hero["movement"] = movement.duplicate(true)
	session.overworld["hero"] = hero

func _finish(original_session, original_window_size: Vector2i, original_reduced_motion: bool, message: String, payload: Dictionary) -> void:
	SessionState.set_active_session(original_session)
	SettingsService.set_reduced_motion_enabled(original_reduced_motion)
	get_window().size = original_window_size
	await get_tree().process_frame
	push_error("%s failed: %s payload=%s" % [REPORT_ID, message, JSON.stringify(payload)])
	get_tree().quit(1)
