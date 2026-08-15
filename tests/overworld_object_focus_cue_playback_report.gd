extends Node

const REPORT_ID := "OVERWORLD_OBJECT_FOCUS_CUE_PLAYBACK_REPORT"
const VIEWPORT_SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080)]
const FOCUS_TEXTURE_PATH := "res://art/overworld/runtime/vfx/object_focus.png"
const FOCUS_AUDIO_PATH := "res://art/audio/runtime/presentation/object_focus.wav"
const OBJECT_ROWS := [
	{"kind": "town", "id": "focus_town", "tile": Vector2i(1, 1)},
	{"kind": "resource", "id": "focus_resource", "tile": Vector2i(2, 2)},
	{"kind": "artifact", "id": "focus_artifact", "tile": Vector2i(6, 2)},
	{"kind": "encounter", "id": "focus_encounter", "tile": Vector2i(7, 1)},
]

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var original_size := get_window().size
	var original_reduced_motion := SettingsService.reduced_motion_enabled()
	var rows: Array = []
	for viewport_size in VIEWPORT_SIZES:
		SettingsService.set_reduced_motion_enabled(false)
		var row := await _run_pointer_viewport(viewport_size)
		rows.append(row)
		if not bool(row.get("ok", false)):
			SettingsService.set_reduced_motion_enabled(original_reduced_motion)
			_fail("Pointer focus viewport failed.", row)
			return
	SettingsService.set_reduced_motion_enabled(false)
	var controller := await _run_controller_selection()
	if not bool(controller.get("ok", false)):
		SettingsService.set_reduced_motion_enabled(original_reduced_motion)
		_fail("Controller focus selection failed.", controller)
		return
	var guarded := await _run_guarded_precedence()
	if not bool(guarded.get("ok", false)):
		SettingsService.set_reduced_motion_enabled(original_reduced_motion)
		_fail("Guarded-site precedence failed.", guarded)
		return
	var fail_closed := await _run_fail_closed_contexts()
	if not bool(fail_closed.get("ok", false)):
		SettingsService.set_reduced_motion_enabled(original_reduced_motion)
		_fail("Hidden, stale, or malformed focus context was accepted.", fail_closed)
		return
	SettingsService.set_reduced_motion_enabled(original_reduced_motion)
	get_window().size = original_size
	await get_tree().process_frame
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"viewports": [[1280, 720], [1920, 1080]],
		"pointer_object_family_count": 4,
		"controller_selection_exact": true,
		"guarded_precedence_exact": true,
		"save_version": SessionStateStore.SAVE_VERSION,
		"rows": rows,
		"controller": controller,
		"guarded": guarded,
		"fail_closed": fail_closed,
	})])
	get_tree().quit(0)

func _run_pointer_viewport(viewport_size: Vector2i) -> Dictionary:
	get_window().size = viewport_size
	await get_tree().process_frame
	await get_tree().process_frame
	if get_window().size != viewport_size:
		return {"ok": false, "failure": "window_size", "actual": get_window().size}
	var opened := await _open_shell(_focus_session())
	var shell: Node = opened.get("shell", null)
	var session = opened.get("session", null)
	if shell == null or session == null:
		return {"ok": false, "failure": "shell_open"}
	_prepare_shell_state(shell, session, Vector2i(4, 1), 12)
	var authority_before: Dictionary = session.to_dict()
	PresentationAudio.validation_reset()
	shell.call("validation_select_tile", 0, 1)
	await get_tree().process_frame
	if bool(_focus(shell).get("active", false)) or not _focus_records().is_empty():
		return await _finish(shell, {"ok": false, "failure": "programmatic_selection_not_silent", "focus": _focus(shell)})
	shell.call("validation_select_tile", 4, 1)
	await get_tree().process_frame

	var family_rows: Array = []
	for index in range(OBJECT_ROWS.size()):
		var object_row: Dictionary = OBJECT_ROWS[index]
		var tile: Vector2i = object_row.get("tile", Vector2i(-1, -1))
		SettingsService.set_reduced_motion_enabled(index == 2)
		var map_view: Node = shell.get_node("%Map")
		map_view.set("_overworld_vfx_texture_missing", {FOCUS_TEXTURE_PATH: true} if index == 1 else {})
		PresentationAudio.validation_reset()
		var selected: Dictionary = shell.call("validation_click_tile", tile.x, tile.y)
		await get_tree().process_frame
		var focus := _focus(shell)
		var expected_mode := "existing_tile_selection_outline" if index in [1, 2] else "imported_texture"
		if (
			not bool(selected.get("ok", false))
			or not _focus_identity_exact(focus, object_row, "pointer")
			or not _focus_visual_exact(focus, expected_mode, index == 2)
			or not _focus_audio_exact(focus, 1)
			or session.to_dict() != authority_before
		):
			return await _finish(shell, {
				"ok": false,
				"failure": "family_%d" % index,
				"selected": selected,
				"focus": focus,
				"shell_focus_payload": (shell.get("_object_focus_presentation") as Dictionary).duplicate(true),
				"animation_preferences": SettingsService.animation_preferences(),
			})
		var first_records := _focus_records().duplicate(true)
		shell.call("_refresh")
		await get_tree().process_frame
		var refreshed := _focus(shell)
		if refreshed.get("context_signature", "") != focus.get("context_signature", "") or _focus_records() != first_records or not _focus_audio_exact(refreshed, 1):
			return await _finish(shell, {"ok": false, "failure": "refresh_replay_%d" % index, "focus": refreshed})
		family_rows.append({
			"kind": String(object_row.get("kind", "")),
			"object_id": String(object_row.get("id", "")),
			"visual_mode": expected_mode,
			"reduced_motion": index == 2,
			"refresh_stable": true,
		})

	SettingsService.set_reduced_motion_enabled(false)
	var first_row: Dictionary = OBJECT_ROWS[0]
	var first_tile: Vector2i = first_row.get("tile", Vector2i.ZERO)
	shell.call("validation_select_tile", 4, 1)
	await get_tree().process_frame
	if bool(_focus(shell).get("active", false)):
		return await _finish(shell, {"ok": false, "failure": "deselect_clear", "focus": _focus(shell)})
	PresentationAudio.validation_reset()
	shell.call("validation_click_tile", first_tile.x, first_tile.y)
	await get_tree().process_frame
	var reselected := _focus(shell)
	if not _focus_identity_exact(reselected, first_row, "pointer") or not _focus_audio_exact(reselected, 1):
		return await _finish(shell, {"ok": false, "failure": "reselection", "focus": reselected})
	var map_rect: Rect2 = shell.get_node("%Map").get_global_rect()
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	return await _finish(shell, {
		"ok": session.to_dict() == authority_before and viewport_rect.encloses(map_rect) and SessionStateStore.SAVE_VERSION == 9,
		"viewport": [viewport_size.x, viewport_size.y],
		"families": family_rows,
		"programmatic_silent": true,
		"reselection_replayed_once": true,
		"authority_exact": session.to_dict() == authority_before,
		"contained": viewport_rect.encloses(map_rect),
		"map_rect": {"x": map_rect.position.x, "y": map_rect.position.y, "width": map_rect.size.x, "height": map_rect.size.y},
		"viewport_rect": {"x": viewport_rect.position.x, "y": viewport_rect.position.y, "width": viewport_rect.size.x, "height": viewport_rect.size.y},
	})

func _run_controller_selection() -> Dictionary:
	var session = _focus_session()
	session.overworld["towns"] = []
	session.overworld["resource_nodes"] = [_resource_node("controller_resource", Vector2i(5, 1))]
	session.overworld["artifact_nodes"] = []
	session.overworld["encounters"] = []
	var opened := await _open_shell(session)
	var shell: Node = opened.get("shell", null)
	session = opened.get("session", session)
	_prepare_shell_state(shell, session, Vector2i(4, 1), 8)
	var authority_before: Dictionary = session.to_dict()
	PresentationAudio.validation_reset()
	var axis: Dictionary = shell.call("validation_controller_route_axis", JOY_AXIS_RIGHT_X, 1.0)
	await get_tree().process_frame
	var focus := _focus(shell)
	shell.call("validation_controller_route_axis", JOY_AXIS_RIGHT_X, 0.0)
	return await _finish(shell, {
		"ok": bool(axis.get("consumed", false)) and _focus_identity_exact(focus, {"kind": "resource", "id": "controller_resource", "tile": Vector2i(5, 1)}, "controller_route_cursor") and _focus_visual_exact(focus, "imported_texture", false) and _focus_audio_exact(focus, 1) and session.to_dict() == authority_before,
		"axis_consumed": bool(axis.get("consumed", false)),
		"focus": focus,
		"authority_exact": session.to_dict() == authority_before,
	})

func _run_guarded_precedence() -> Dictionary:
	var session = _focus_session()
	session.overworld["towns"] = []
	session.overworld["resource_nodes"] = [_guarded_node("guarded_resource", Vector2i(2, 1))]
	session.overworld["artifact_nodes"] = []
	session.overworld["encounters"] = [_guard_encounter("guarded_resource_watch", "guarded_resource", Vector2i(2, 0))]
	var opened := await _open_shell(session)
	var shell: Node = opened.get("shell", null)
	session = opened.get("session", session)
	_prepare_shell_state(shell, session, Vector2i(4, 1), 8)
	var authority_before: Dictionary = session.to_dict()
	PresentationAudio.validation_reset()
	shell.call("validation_click_tile", 2, 1)
	await get_tree().process_frame
	var focus := _focus(shell)
	var guarded := _guarded(shell)
	var focus_records := _focus_records()
	var guard_records: Array = []
	for record_value in PresentationAudio.validation_records():
		if record_value is Dictionary and String(record_value.get("source", "")) == "OverworldMapView.guarded_site":
			guard_records.append(record_value.duplicate(true))
	return await _finish(shell, {
		"ok": not bool(focus.get("active", true)) and focus_records.is_empty() and bool(guarded.get("active", false)) and guard_records.size() == 1 and session.to_dict() == authority_before,
		"focus_silent": focus_records.is_empty(),
		"guarded_active": bool(guarded.get("active", false)),
		"guard_audio_count": guard_records.size(),
		"authority_exact": session.to_dict() == authority_before,
	})

func _run_fail_closed_contexts() -> Dictionary:
	var session = _focus_session()
	session.overworld["towns"] = []
	session.overworld["resource_nodes"] = [
		_resource_node("hidden_resource", Vector2i(0, 1)),
		_resource_node("visible_resource", Vector2i(2, 1)),
	]
	session.overworld["artifact_nodes"] = []
	session.overworld["encounters"] = []
	var opened := await _open_shell(session)
	var shell: Node = opened.get("shell", null)
	session = opened.get("session", session)
	_prepare_shell_state(shell, session, Vector2i(4, 1), 8)
	var authority_before: Dictionary = session.to_dict()
	PresentationAudio.validation_reset()
	shell.call("validation_click_tile", 0, 1)
	await get_tree().process_frame
	var hidden_silent := not bool(_focus(shell).get("active", true)) and _focus_records().is_empty()
	shell.call("validation_select_tile", 4, 1)
	await get_tree().process_frame
	var map_view: Node = shell.get_node("%Map")
	var map_data: Array = session.overworld.get("map", []) if session.overworld.get("map", []) is Array else []
	var map_size := OverworldRules.derive_map_size(session)
	var stale := _focus_presentation(Vector2i(2, 1), "resource", "visible_resource", "pointer")
	map_view.call("set_map_state", session, map_data, map_size, Vector2i(4, 1), {}, {}, {}, {}, {}, {}, stale)
	await get_tree().process_frame
	var stale_silent := not bool(map_view.call("validation_object_focus_presentation").get("active", true)) and _focus_records().is_empty()
	var malformed := _focus_presentation(Vector2i(2, 1), "resource", "wrong_resource", "pointer")
	map_view.call("set_map_state", session, map_data, map_size, Vector2i(2, 1), {}, {}, {}, {}, {}, {}, malformed)
	await get_tree().process_frame
	var malformed_silent := not bool(map_view.call("validation_object_focus_presentation").get("active", true)) and _focus_records().is_empty()
	return await _finish(shell, {
		"ok": hidden_silent and stale_silent and malformed_silent and session.to_dict() == authority_before,
		"hidden_silent": hidden_silent,
		"stale_silent": stale_silent,
		"malformed_silent": malformed_silent,
		"authority_exact": session.to_dict() == authority_before,
	})

func _focus_presentation(tile: Vector2i, object_kind: String, object_id: String, input_source: String) -> Dictionary:
	return {
		"active": true,
		"event_id": "overworld_object_active",
		"cue_id": "cue_overworld_object_active",
		"input_source": input_source,
		"tile": {"x": tile.x, "y": tile.y},
		"object_kind": object_kind,
		"object_id": object_id,
		"selected_animation_state": "context_focus_active",
		"selected_visual_policy": "authored_animation_state",
		"selected_fallback_tag": "",
		"selected_playback_policy": "context_visible_only",
		"selected_blocking_policy": "never_blocks_input",
		"selected_vfx_cue_ids": ["vfx_placeholder_object_focus_ring"],
		"selected_audio_cue_ids": ["audio_placeholder_object_focus"],
		"allows_large_motion": true,
	}

func _focus_identity_exact(snapshot: Dictionary, object_row: Dictionary, input_source: String) -> bool:
	var tile: Vector2i = object_row.get("tile", Vector2i(-1, -1))
	return bool(snapshot.get("active", false)) \
		and String(snapshot.get("event_id", "")) == "overworld_object_active" \
		and String(snapshot.get("cue_id", "")) == "cue_overworld_object_active" \
		and String(snapshot.get("input_source", "")) == input_source \
		and snapshot.get("tile", {}) == {"x": tile.x, "y": tile.y} \
		and String(snapshot.get("object_kind", "")) == String(object_row.get("kind", "")) \
		and String(snapshot.get("object_id", "")) == String(object_row.get("id", "")) \
		and String(snapshot.get("playback_policy", "")) == "context_visible_only" \
		and String(snapshot.get("blocking_policy", "")) == "never_blocks_input"

func _focus_visual_exact(snapshot: Dictionary, expected_mode: String, reduced_motion: bool) -> bool:
	var asset: Dictionary = snapshot.get("vfx_asset", {}) if snapshot.get("vfx_asset", {}) is Dictionary else {}
	var draw: Dictionary = snapshot.get("vfx_draw", {}) if snapshot.get("vfx_draw", {}) is Dictionary else {}
	if String(draw.get("mode", "")) != expected_mode:
		return false
	if reduced_motion:
		return String(snapshot.get("visual_policy", "")) == "reduced_motion_fallback" and snapshot.get("selected_vfx_cue_ids", []) == ["focus_outline_static"] and not bool(snapshot.get("allows_large_motion", true)) and not bool(asset.get("uses_imported_asset", true))
	if expected_mode == "existing_tile_selection_outline":
		return snapshot.get("selected_vfx_cue_ids", []) == ["vfx_placeholder_object_focus_ring"] and bool(asset.get("uses_selection_outline_fallback", false)) and not bool(asset.get("uses_imported_asset", true))
	return String(snapshot.get("visual_policy", "")) == "authored_animation_state" \
		and snapshot.get("selected_vfx_cue_ids", []) == ["vfx_placeholder_object_focus_ring"] \
		and bool(asset.get("uses_imported_asset", false)) \
		and String(asset.get("texture_path", "")) == FOCUS_TEXTURE_PATH \
		and String(draw.get("texture_path", "")) == FOCUS_TEXTURE_PATH

func _focus_audio_exact(snapshot: Dictionary, expected_service_count: int) -> bool:
	var snapshot_records: Array = snapshot.get("audio_playback_records", []) if snapshot.get("audio_playback_records", []) is Array else []
	var records := _focus_records()
	if snapshot.get("selected_audio_cue_ids", []) != ["audio_placeholder_object_focus"] or snapshot_records.size() != 1 or records.size() != expected_service_count:
		return false
	var record: Dictionary = snapshot_records[0] if snapshot_records[0] is Dictionary else {}
	var metadata: Dictionary = record.get("metadata", {}) if record.get("metadata", {}) is Dictionary else {}
	return record == records[-1] \
		and String(record.get("cue_id", "")) == "audio_placeholder_object_focus" \
		and String(record.get("source", "")) == "OverworldMapView.object_focus" \
		and bool(record.get("played", false)) \
		and String(record.get("playback_source", "")) == "imported_wav" \
		and String(record.get("asset_path", "")) == FOCUS_AUDIO_PATH \
		and String(record.get("role", "")) == "overworld_object_selected" \
		and int(record.get("stream_mix_rate", 0)) == 44100 \
		and bool(record.get("stream_stereo", false)) \
		and int(record.get("stream_loop_mode", -1)) == AudioStreamWAV.LOOP_DISABLED \
		and int(record.get("imported_asset_count", 0)) == 1 \
		and int(record.get("generated_fallback_count", -1)) == 0 \
		and metadata.get("tile", {}) == snapshot.get("tile", {}) \
		and String(metadata.get("object_kind", "")) == String(snapshot.get("object_kind", "")) \
		and String(metadata.get("object_id", "")) == String(snapshot.get("object_id", "")) \
		and String(metadata.get("input_source", "")) == String(snapshot.get("input_source", ""))

func _focus_records() -> Array:
	var records: Array = []
	for record_value in PresentationAudio.validation_records():
		if record_value is Dictionary and String(record_value.get("source", "")) == "OverworldMapView.object_focus":
			records.append(record_value.duplicate(true))
	return records

func _focus(shell: Node) -> Dictionary:
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var viewport: Dictionary = snapshot.get("map_viewport", {}) if snapshot.get("map_viewport", {}) is Dictionary else {}
	return viewport.get("object_focus_presentation", {}).duplicate(true) if viewport.get("object_focus_presentation", {}) is Dictionary else {}

func _guarded(shell: Node) -> Dictionary:
	var snapshot: Dictionary = shell.call("validation_snapshot")
	var viewport: Dictionary = snapshot.get("map_viewport", {}) if snapshot.get("map_viewport", {}) is Dictionary else {}
	return viewport.get("guarded_site_presentation", {}).duplicate(true) if viewport.get("guarded_site_presentation", {}) is Dictionary else {}

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

func _prepare_shell_state(shell: Node, session, position: Vector2i, movement_points: int) -> void:
	_set_active_hero_position(session, position)
	_set_active_hero_movement(session, movement_points)
	session.overworld["fog"] = {}
	OverworldRules.refresh_fog_of_war(session)
	shell.call("_set_selected_tile", position)
	shell.call("_refresh")

func _focus_session():
	var session = ScenarioFactory.create_session("river-pass", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	OverworldRules.normalize_overworld_state(session)
	var rows := []
	for y in range(3):
		var row := []
		for _x in range(10):
			row.append("grass")
		rows.append(row)
	session.overworld["map"] = rows
	session.overworld["map_size"] = {"width": 10, "height": 3, "x": 10, "y": 3}
	session.overworld["terrain_layers"] = {}
	session.overworld["towns"] = [_neutral_town("focus_town", Vector2i(1, 1))]
	session.overworld["resource_nodes"] = [_resource_node("focus_resource", Vector2i(2, 2))]
	session.overworld["artifact_nodes"] = [{"placement_id": "focus_artifact", "artifact_id": "artifact_bastion_gorget", "x": 6, "y": 2, "collected": false}]
	session.overworld["encounters"] = [{"placement_id": "focus_encounter", "encounter_id": "encounter_bramble_hedge_watch", "name": "Bramble Hedge Watch", "x": 7, "y": 1, "army": []}]
	session.overworld["resolved_encounters"] = []
	return session

func _neutral_town(placement_id: String, tile: Vector2i) -> Dictionary:
	return {"placement_id": placement_id, "town_id": "town_duskfen", "x": tile.x, "y": tile.y, "owner": "neutral", "controlling_faction_id": "", "garrison": [], "available_recruits": {}, "buildings": []}

func _resource_node(placement_id: String, tile: Vector2i) -> Dictionary:
	return {"placement_id": placement_id, "site_id": "site_wood_wagon", "x": tile.x, "y": tile.y, "collected": false, "collected_by_faction_id": ""}

func _guarded_node(placement_id: String, tile: Vector2i) -> Dictionary:
	return {"placement_id": placement_id, "site_id": "site_barrow_vault", "x": tile.x, "y": tile.y, "collected": false, "collected_by_faction_id": ""}

func _guard_encounter(placement_id: String, target_placement_id: String, tile: Vector2i) -> Dictionary:
	return {"placement_id": placement_id, "encounter_id": "encounter_bramble_hedge_watch", "name": "Bramble Hedge Watch", "x": tile.x, "y": tile.y, "guard_link": {"guard_role": "site_guard", "target_kind": "resource_site", "target_placement_id": target_placement_id, "target_id": "site_barrow_vault", "clear_required_for_target": true, "blocks_approach": true}}

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
			var entry: Dictionary = heroes[index]
			entry["position"] = position.duplicate(true)
			heroes[index] = entry
			break
	session.overworld["player_heroes"] = heroes

func _set_active_hero_movement(session, movement_points: int) -> void:
	var movement := {"current": movement_points, "max": movement_points}
	session.overworld["movement"] = movement.duplicate(true)
	var hero: Dictionary = session.overworld.get("hero", {}) if session.overworld.get("hero", {}) is Dictionary else {}
	hero["base_movement"] = movement_points
	hero["level"] = 1
	hero["experience"] = 0
	hero["specialties"] = []
	hero["movement"] = movement.duplicate(true)
	session.overworld["hero"] = hero
	var active_hero_id := String(session.overworld.get("active_hero_id", hero.get("id", "")))
	var heroes: Array = session.overworld.get("player_heroes", []) if session.overworld.get("player_heroes", []) is Array else []
	for index in range(heroes.size()):
		if heroes[index] is Dictionary and String(heroes[index].get("id", "")) == active_hero_id:
			var entry: Dictionary = heroes[index]
			entry["base_movement"] = movement_points
			entry["level"] = 1
			entry["experience"] = 0
			entry["specialties"] = []
			entry["movement"] = movement.duplicate(true)
			heroes[index] = entry
			break
	session.overworld["player_heroes"] = heroes

func _finish(shell: Node, row: Dictionary) -> Dictionary:
	shell.queue_free()
	await get_tree().process_frame
	return row

func _fail(message: String, payload: Dictionary = {}) -> void:
	push_error("%s failed: %s payload=%s" % [REPORT_ID, message, JSON.stringify(payload)])
	get_tree().quit(1)
