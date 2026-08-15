extends Node

const REPORT_ID := "OVERWORLD_OBJECT_BLOCKED_FEEDBACK_REPORT"
const VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const OBJECT_TILE := Vector2i(4, 2)
const RESOURCE_BODY_TILE := Vector2i(6, 2)
const TERRAIN_TILE := Vector2i(3, 3)
const HIDDEN_OBJECT_TILE := Vector2i(9, 1)
const UNREACHABLE_TILE := Vector2i(9, 3)
const OBJECT_TEXTURE_PATH := "res://art/overworld/runtime/vfx/object_blocked.png"
const OBJECT_AUDIO_PATH := "res://art/audio/runtime/presentation/object_blocked.wav"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var original_window_size := get_window().size
	var original_reduced_motion := SettingsService.reduced_motion_enabled()
	var rows: Array = []
	for viewport_size in VIEWPORT_SIZES:
		SettingsService.set_reduced_motion_enabled(false)
		var row := await _run_case(viewport_size, "normal")
		rows.append(row)
		if not bool(row.get("ok", false)):
			await _finish_run(original_window_size, original_reduced_motion, "Normal object-blocked row failed.", row)
			return
	SettingsService.set_reduced_motion_enabled(true)
	var reduced := await _run_case(Vector2i(1280, 720), "reduced")
	if not bool(reduced.get("ok", false)):
		await _finish_run(original_window_size, original_reduced_motion, "Reduced-motion object-blocked row failed.", reduced)
		return
	SettingsService.set_reduced_motion_enabled(false)
	var missing := await _run_case(Vector2i(1280, 720), "missing")
	if not bool(missing.get("ok", false)):
		await _finish_run(original_window_size, original_reduced_motion, "Missing-asset object-blocked row failed.", missing)
		return
	SettingsService.set_reduced_motion_enabled(original_reduced_motion)
	get_window().size = original_window_size
	await get_tree().process_frame
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"viewports": [[1280, 720], [1920, 1080]],
		"visible_map_object_exact": true,
		"resource_body_exact": true,
		"hidden_identity_silent": true,
		"terrain_and_unreachable_controls_exact": true,
		"normal_rows": rows,
		"reduced": reduced,
		"missing": missing,
		"save_version": SessionStateStore.SAVE_VERSION,
	})])
	get_tree().quit(0)

func _run_case(viewport_size: Vector2i, mode: String) -> Dictionary:
	get_window().size = viewport_size
	await get_tree().process_frame
	await get_tree().process_frame
	if get_window().size != viewport_size:
		return {"ok": false, "failure": "window_size", "actual": get_window().size, "mode": mode}
	var opened := await _open_shell(_blocking_session())
	var shell: Node = opened.get("shell", null)
	var session = opened.get("session", null)
	if shell == null or session == null:
		return {"ok": false, "failure": "shell_open", "mode": mode}
	_prepare_shell_state(shell, session)
	var map_view: Node = shell.get_node("%Map")
	if mode == "missing":
		map_view.set("_overworld_vfx_texture_missing", {OBJECT_TEXTURE_PATH: true})
	var map_object_surface := OverworldRules.blocking_object_feedback_surface_at_tile(session, OBJECT_TILE.x, OBJECT_TILE.y)
	var resource_surface := OverworldRules.blocking_object_feedback_surface_at_tile(session, RESOURCE_BODY_TILE.x, RESOURCE_BODY_TILE.y)
	var hidden_surface := OverworldRules.blocking_object_feedback_surface_at_tile(session, HIDDEN_OBJECT_TILE.x, HIDDEN_OBJECT_TILE.y)
	var source_surfaces_exact := map_object_surface == {
		"source": "map_objects",
		"kind": "map_object",
		"placement_id": "feedback_bramble_wall",
		"object_id": "object_bramble_wall",
		"site_id": "",
		"name": "Bramble Wall",
		"tile": {"x": OBJECT_TILE.x, "y": OBJECT_TILE.y},
	} and resource_surface == {
		"source": "resource_nodes",
		"kind": "resource_body",
		"placement_id": "feedback_brightwood_sawmill",
		"object_id": "object_brightwood_sawmill",
		"site_id": "site_brightwood_sawmill",
		"name": "Brightwood Sawmill",
		"tile": {"x": RESOURCE_BODY_TILE.x, "y": RESOURCE_BODY_TILE.y},
	} and String(hidden_surface.get("name", "")) == "Bramble Wall"
	if not source_surfaces_exact or not OverworldRules.tile_is_blocked(session, OBJECT_TILE.x, OBJECT_TILE.y) or not OverworldRules.tile_is_blocked(session, RESOURCE_BODY_TILE.x, RESOURCE_BODY_TILE.y):
		return await _finish_shell(shell, {"ok": false, "failure": "source_surface", "map_object": map_object_surface, "resource": resource_surface, "hidden": hidden_surface})
	var authority_before: Dictionary = session.to_dict()
	PresentationAudio.validation_reset()
	var selected: Dictionary = shell.call("validation_select_tile", OBJECT_TILE.x, OBJECT_TILE.y)
	await get_tree().process_frame
	var object_cue := _route_blocked_presentation(shell)
	if not _object_selection_exact(selected, object_cue, mode) or session.to_dict() != authority_before:
		return await _finish_shell(shell, {"ok": false, "failure": "object_selection", "mode": mode, "selected": selected, "cue": object_cue})
	var first_serial := int(object_cue.get("serial", 0))
	var first_records := PresentationAudio.validation_records().duplicate(true)
	shell.call("_refresh")
	await get_tree().process_frame
	var refreshed := _route_blocked_presentation(shell)
	var repeated: Dictionary = shell.call("validation_select_tile", OBJECT_TILE.x, OBJECT_TILE.y)
	await get_tree().process_frame
	var repeated_cue := _route_blocked_presentation(shell)
	var dedupe_exact := int(refreshed.get("serial", -1)) == first_serial and int(repeated_cue.get("serial", -1)) == first_serial and PresentationAudio.validation_records() == first_records and String(repeated.get("selected_route_decision", {}).get("blocked_reason", "")) == "Bramble Wall blocks travel."
	if not dedupe_exact or session.to_dict() != authority_before:
		return await _finish_shell(shell, {"ok": false, "failure": "dedupe", "refreshed": refreshed, "repeated": repeated_cue})
	var controls := {"terrain": true, "unreachable": true, "hidden": true, "reselection": true}
	var control_evidence := {}
	if mode == "normal":
		var terrain_selection: Dictionary = shell.call("validation_select_tile", TERRAIN_TILE.x, TERRAIN_TILE.y)
		await get_tree().process_frame
		var terrain_cue := _route_blocked_presentation(shell)
		controls["terrain"] = _route_control_exact(terrain_selection, terrain_cue, "Rock blocks travel.", TERRAIN_TILE)
		var unreachable_selection: Dictionary = shell.call("validation_select_tile", UNREACHABLE_TILE.x, UNREACHABLE_TILE.y)
		await get_tree().process_frame
		var unreachable_cue := _route_blocked_presentation(shell)
		controls["unreachable"] = _route_control_exact(unreachable_selection, unreachable_cue, "No clear route from the active hero.", UNREACHABLE_TILE)
		var hidden_selection: Dictionary = shell.call("validation_select_tile", HIDDEN_OBJECT_TILE.x, HIDDEN_OBJECT_TILE.y)
		await get_tree().process_frame
		var hidden_cue := _route_blocked_presentation(shell)
		var hidden_decision: Dictionary = hidden_selection.get("selected_route_decision", {}) if hidden_selection.get("selected_route_decision", {}) is Dictionary else {}
		control_evidence["hidden_decision"] = hidden_decision.duplicate(true)
		control_evidence["hidden_cue"] = hidden_cue.duplicate(true)
		controls["hidden"] = _route_control_exact(hidden_selection, hidden_cue, "An unseen obstacle blocks travel.", HIDDEN_OBJECT_TILE) and not JSON.stringify(hidden_decision).contains("Bramble Wall") and not JSON.stringify(hidden_cue).contains("Bramble Wall")
		var reselected: Dictionary = shell.call("validation_select_tile", OBJECT_TILE.x, OBJECT_TILE.y)
		await get_tree().process_frame
		var reselected_cue := _route_blocked_presentation(shell)
		controls["reselection"] = _object_selection_exact(reselected, reselected_cue, mode) and int(reselected_cue.get("serial", 0)) > first_serial
	if not controls.values().all(func(value): return bool(value)) or session.to_dict() != authority_before:
		return await _finish_shell(shell, {"ok": false, "failure": "controls", "controls": controls, "control_evidence": control_evidence, "mode": mode})
	var map_rect: Rect2 = map_view.get_global_rect()
	var viewport_rect := get_viewport().get_visible_rect()
	var summary: Dictionary = map_view.call("validation_object_resolution_vfx_asset_summary")
	return await _finish_shell(shell, {
		"ok": viewport_rect.encloses(map_rect) and _manifest_summary_exact(summary, mode) and session.to_dict() == authority_before and SessionStateStore.SAVE_VERSION == 9,
		"mode": mode,
		"viewport": [viewport_size.x, viewport_size.y],
		"source_surfaces_exact": source_surfaces_exact,
		"object_event_id": String(object_cue.get("event_id", "")),
		"blocked_reason": String(object_cue.get("blocked_reason", "")),
		"visual_mode": String(object_cue.get("vfx_draw", {}).get("mode", "")),
		"dedupe_exact": dedupe_exact,
		"controls": controls,
		"authority_exact": session.to_dict() == authority_before,
		"contained": viewport_rect.encloses(map_rect),
	})

func _object_selection_exact(selection: Dictionary, cue: Dictionary, mode: String) -> bool:
	var decision: Dictionary = selection.get("selected_route_decision", {}) if selection.get("selected_route_decision", {}) is Dictionary else {}
	var asset: Dictionary = cue.get("vfx_asset", {}) if cue.get("vfx_asset", {}) is Dictionary else {}
	var draw: Dictionary = cue.get("vfx_draw", {}) if cue.get("vfx_draw", {}) is Dictionary else {}
	var expected_vfx := ["blocked_object_icon"] if mode == "reduced" else ["vfx_placeholder_object_blocked_marker"]
	var expected_mode := "blocked_object_icon" if mode == "reduced" else ("procedural_object_blocked_marker" if mode == "missing" else "imported_texture")
	var expected_fallback := mode != "normal"
	return String(decision.get("status", "")) == "blocked" \
		and String(decision.get("blocked_reason", "")) == "Bramble Wall blocks travel." \
		and String(decision.get("blocked_event_id", "")) == "overworld_object_blocked" \
		and decision.get("blocking_object", {}) == cue.get("blocking_object", {}) \
		and String(decision.get("blocking_object", {}).get("placement_id", "")) == "feedback_bramble_wall" \
		and String(cue.get("event_id", "")) == "overworld_object_blocked" \
		and cue.get("tile", {}) == {"x": OBJECT_TILE.x, "y": OBJECT_TILE.y} \
		and String(cue.get("blocked_reason", "")) == "Bramble Wall blocks travel." \
		and String(cue.get("animation_state", "")) == ("blocked_object_icon" if mode == "reduced" else "object_blocks_route") \
		and cue.get("selected_vfx_cue_ids", []) == expected_vfx \
		and cue.get("selected_audio_cue_ids", []) == ["audio_placeholder_blocked_object"] \
		and bool(asset.get("uses_procedural_fallback", false)) == expected_fallback \
		and bool(asset.get("uses_imported_asset", false)) == not expected_fallback \
		and String(asset.get("texture_path", "")) == ("" if mode == "reduced" else OBJECT_TEXTURE_PATH) \
		and String(draw.get("mode", "")) == expected_mode \
		and _object_audio_exact(cue) \
		and bool(cue.get("allows_large_motion", true)) == (mode != "reduced")

func _route_control_exact(selection: Dictionary, cue: Dictionary, reason: String, tile: Vector2i) -> bool:
	var decision: Dictionary = selection.get("selected_route_decision", {}) if selection.get("selected_route_decision", {}) is Dictionary else {}
	return String(decision.get("status", "")) == "blocked" \
		and String(decision.get("blocked_reason", "")) == reason \
		and String(decision.get("blocked_event_id", "")) == ("overworld_route_blocked" if reason != "No clear route from the active hero." else "") \
		and decision.get("blocking_object", {}) == {} \
		and String(cue.get("event_id", "")) == "overworld_route_blocked" \
		and cue.get("tile", {}) == {"x": tile.x, "y": tile.y} \
		and String(cue.get("blocked_reason", "")) == reason \
		and cue.get("blocking_object", {}) == {} \
		and cue.get("selected_vfx_cue_ids", []) == ["vfx_placeholder_blocked_route_marker"] \
		and cue.get("selected_audio_cue_ids", []) == ["audio_placeholder_invalid_route"]

func _object_audio_exact(cue: Dictionary) -> bool:
	var records: Array = cue.get("audio_playback_records", []) if cue.get("audio_playback_records", []) is Array else []
	var record: Dictionary = records[0] if records.size() == 1 and records[0] is Dictionary else {}
	return records.size() == 1 \
		and String(record.get("cue_id", "")) == "audio_placeholder_blocked_object" \
		and String(record.get("asset_path", "")) == OBJECT_AUDIO_PATH \
		and String(record.get("source", "")) == "OverworldMapView.object_blocked" \
		and String(record.get("role", "")) == "overworld_object_blocked" \
		and String(record.get("playback_source", "")) == "imported_wav" \
		and bool(record.get("played", false)) \
		and int(record.get("stream_mix_rate", 0)) == 44100 \
		and bool(record.get("stream_stereo", false))

func _manifest_summary_exact(summary: Dictionary, mode: String) -> bool:
	var expected_loaded_count := 14 if mode == "missing" else 15
	var expected_missing_paths := [OBJECT_TEXTURE_PATH] if mode == "missing" else []
	return bool(summary.get("manifest_loaded", false)) \
		and int(summary.get("mapped_cue_count", 0)) == 15 \
		and int(summary.get("unique_texture_count", 0)) == 15 \
		and int(summary.get("loaded_texture_count", 0)) == expected_loaded_count \
		and summary.get("missing_texture_paths", []) == expected_missing_paths \
		and "vfx_placeholder_object_blocked_marker" in summary.get("mapped_cue_ids", [])

func _route_blocked_presentation(shell: Node) -> Dictionary:
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var viewport: Dictionary = snapshot.get("map_viewport", {}) if snapshot.get("map_viewport", {}) is Dictionary else {}
	return viewport.get("route_blocked_presentation", {}).duplicate(true) if viewport.get("route_blocked_presentation", {}) is Dictionary else {}

func _blocking_session():
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var width := 11
	var height := 5
	var rows := []
	for y in range(height):
		var row := []
		for _x in range(width):
			row.append("grass")
		rows.append(row)
	rows[TERRAIN_TILE.y][TERRAIN_TILE.x] = "rock"
	for tile in [Vector2i(8, 2), Vector2i(9, 2), Vector2i(10, 2), Vector2i(8, 3), Vector2i(10, 3), Vector2i(8, 4), Vector2i(9, 4), Vector2i(10, 4)]:
		rows[tile.y][tile.x] = "water"
	session.overworld["map"] = rows
	session.overworld["map_size"] = {"width": width, "height": height, "x": width, "y": height}
	session.overworld["terrain_layers"] = {}
	session.overworld["towns"] = [{"placement_id": "feedback_home", "town_id": "town_riverwatch", "x": 0, "y": 0, "owner": "player"}]
	session.overworld["map_objects"] = [
		{"placement_id": "feedback_bramble_wall", "object_id": "object_bramble_wall", "kind": "decorative_obstacle", "object_family_id": "decorative_obstacle", "blocking_body": true, "package_block_tiles": [{"x": OBJECT_TILE.x, "y": OBJECT_TILE.y}], "x": OBJECT_TILE.x, "y": OBJECT_TILE.y},
		{"placement_id": "hidden_bramble_wall", "object_id": "object_bramble_wall", "kind": "decorative_obstacle", "object_family_id": "decorative_obstacle", "blocking_body": true, "package_block_tiles": [{"x": HIDDEN_OBJECT_TILE.x, "y": HIDDEN_OBJECT_TILE.y}], "x": HIDDEN_OBJECT_TILE.x, "y": HIDDEN_OBJECT_TILE.y},
	]
	session.overworld["resource_nodes"] = [{"placement_id": "feedback_brightwood_sawmill", "site_id": "site_brightwood_sawmill", "object_id": "object_brightwood_sawmill", "blocking_body": true, "package_block_tiles": [{"x": RESOURCE_BODY_TILE.x, "y": RESOURCE_BODY_TILE.y}], "x": RESOURCE_BODY_TILE.x, "y": RESOURCE_BODY_TILE.y, "collected": false, "collected_by_faction_id": ""}]
	session.overworld["artifact_nodes"] = []
	session.overworld["encounters"] = []
	session.overworld["resolved_encounters"] = []
	return session

func _open_shell(session) -> Dictionary:
	var active_session = SessionState.set_active_session(session)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	var shell_session = shell.get("_session")
	if shell_session != null:
		active_session = shell_session
	return {"shell": shell, "session": active_session}

func _prepare_shell_state(shell: Node, session) -> void:
	_set_active_hero_position(session, Vector2i(1, 2))
	_set_active_hero_movement(session, 12)
	_set_visibility(session, [Vector2i(1, 2), OBJECT_TILE, RESOURCE_BODY_TILE, TERRAIN_TILE, UNREACHABLE_TILE])
	shell.call("_set_selected_tile", Vector2i(1, 2))
	shell.call("_refresh")

func _set_visibility(session, visible_tiles: Array) -> void:
	var map_size := OverworldRules.derive_map_size(session)
	var visible := []
	var explored := []
	for y in range(map_size.y):
		var visible_row := []
		var explored_row := []
		for _x in range(map_size.x):
			visible_row.append(false)
			explored_row.append(false)
		visible.append(visible_row)
		explored.append(explored_row)
	for tile_value in visible_tiles:
		var tile: Vector2i = tile_value
		visible[tile.y][tile.x] = true
		explored[tile.y][tile.x] = true
	session.overworld["fog"] = {"visible_tiles": visible, "explored_tiles": explored, "visible_count": visible_tiles.size(), "explored_count": visible_tiles.size()}

func _set_active_hero_position(session, tile: Vector2i) -> void:
	var position := {"x": tile.x, "y": tile.y}
	session.overworld["hero_position"] = position.duplicate(true)
	var hero: Dictionary = session.overworld.get("hero", {}) if session.overworld.get("hero", {}) is Dictionary else {}
	hero["position"] = position.duplicate(true)
	session.overworld["hero"] = hero
	var active_hero_id := String(session.overworld.get("active_hero_id", hero.get("id", "")))
	var heroes: Array = session.overworld.get("player_heroes", []) if session.overworld.get("player_heroes", []) is Array else []
	for index in range(heroes.size()):
		if heroes[index] is Dictionary and String(heroes[index].get("id", "")) == active_hero_id:
			heroes[index]["position"] = position.duplicate(true)
			break
	session.overworld["player_heroes"] = heroes

func _set_active_hero_movement(session, movement_points: int) -> void:
	var movement := {"current": movement_points, "max": movement_points}
	session.overworld["movement"] = movement.duplicate(true)
	var hero: Dictionary = session.overworld.get("hero", {}) if session.overworld.get("hero", {}) is Dictionary else {}
	hero["movement"] = movement.duplicate(true)
	hero["base_movement"] = movement_points
	session.overworld["hero"] = hero
	var active_hero_id := String(session.overworld.get("active_hero_id", hero.get("id", "")))
	var heroes: Array = session.overworld.get("player_heroes", []) if session.overworld.get("player_heroes", []) is Array else []
	for index in range(heroes.size()):
		if heroes[index] is Dictionary and String(heroes[index].get("id", "")) == active_hero_id:
			heroes[index]["movement"] = movement.duplicate(true)
			heroes[index]["base_movement"] = movement_points
			break
	session.overworld["player_heroes"] = heroes

func _finish_shell(shell: Node, result: Dictionary) -> Dictionary:
	if shell != null and is_instance_valid(shell):
		shell.queue_free()
		await get_tree().process_frame
	return result

func _finish_run(original_window_size: Vector2i, original_reduced_motion: bool, message: String, payload: Dictionary) -> void:
	SettingsService.set_reduced_motion_enabled(original_reduced_motion)
	get_window().size = original_window_size
	await get_tree().process_frame
	push_error("%s failed: %s payload=%s" % [REPORT_ID, message, JSON.stringify(payload)])
	get_tree().quit(1)
