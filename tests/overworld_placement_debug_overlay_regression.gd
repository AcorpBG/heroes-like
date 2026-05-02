extends Node

const OverworldMapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var map_view_result := _assert_map_view_overlay_tiles()
	if not bool(map_view_result.get("ok", false)):
		push_error("Placement debug overlay map-view regression failed: %s" % JSON.stringify(map_view_result))
		get_tree().quit(1)
		return
	var shell_result = await _assert_shell_f4_toggle()
	if not bool(shell_result.get("ok", false)):
		push_error("Placement debug overlay F4 regression failed: %s" % JSON.stringify(shell_result))
		get_tree().quit(1)
		return
	get_tree().quit(0)

func _assert_map_view_overlay_tiles() -> Dictionary:
	var session = _fixture_session()
	var view = OverworldMapViewScript.new()
	view.size = Vector2(960, 640)
	add_child(view)
	view.set_map_state(session, session.overworld.get("map", []), OverworldRules.derive_map_size(session), Vector2i(1, 1))
	view.set_placement_debug_overlay_enabled(true)
	var snapshot: Dictionary = view.validation_placement_debug_overlay_snapshot()
	var failures := []
	if not bool(snapshot.get("enabled", false)):
		failures.append("Map-view overlay did not report enabled.")
	if not _tile_present(snapshot.get("blocker_tiles", []), Vector2i(12, 10), "resource_body", "overlay_runtime_yard"):
		failures.append("Generated runtime resource body tile 12,10 was not red/blocker.")
	if not _tile_present(snapshot.get("blocker_tiles", []), Vector2i(13, 10), "resource_body", "overlay_runtime_yard"):
		failures.append("Generated runtime resource body tile 13,10 was not red/blocker.")
	if not _tile_present(snapshot.get("interactable_tiles", []), Vector2i(12, 11), "resource_visit", "overlay_runtime_yard"):
		failures.append("Generated runtime visit tile 12,11 was not yellow/interactable.")
	if not _tile_present(snapshot.get("interactable_tiles", []), Vector2i(8, 8), "town_entry", "overlay_town"):
		failures.append("Town entry tile was not yellow/interactable.")
	if not _tile_present(snapshot.get("blocker_tiles", []), Vector2i(7, 7), "town_body", "overlay_town"):
		failures.append("Town non-entry footprint tile was not red/blocker.")
	if not _tile_present(snapshot.get("interactable_tiles", []), Vector2i(3, 3), "artifact_action", "overlay_artifact"):
		failures.append("Artifact action tile was not yellow/interactable.")
	if not _tile_present(snapshot.get("interactable_tiles", []), Vector2i(4, 4), "encounter_action", "overlay_encounter"):
		failures.append("Encounter action tile was not yellow/interactable.")
	view.set_placement_debug_overlay_enabled(false)
	var disabled_snapshot: Dictionary = view.validation_placement_debug_overlay_snapshot()
	if bool(disabled_snapshot.get("enabled", true)):
		failures.append("Map-view overlay did not report disabled.")
	remove_child(view)
	view.queue_free()
	return {
		"ok": failures.is_empty(),
		"failures": failures,
		"blocker_tile_count": int(snapshot.get("blocker_tile_count", 0)),
		"interactable_tile_count": int(snapshot.get("interactable_tile_count", 0)),
	}

func _assert_shell_f4_toggle() -> Dictionary:
	var session = _fixture_session()
	SessionState.set_active_session(session)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	for _i in range(3):
		await get_tree().process_frame
	var failures := []
	var before: Dictionary = shell.call("validation_placement_debug_overlay_snapshot")
	if bool(before.get("enabled", false)):
		failures.append("Shell overlay started enabled.")
	var enable_event := _f4_event()
	shell._unhandled_input(enable_event)
	await get_tree().process_frame
	var enabled_snapshot: Dictionary = shell.call("validation_placement_debug_overlay_snapshot")
	var enabled_map: Dictionary = enabled_snapshot.get("map_view", {}) if enabled_snapshot.get("map_view", {}) is Dictionary else {}
	if not bool(enabled_snapshot.get("enabled", false)) or not bool(enabled_map.get("enabled", false)):
		failures.append("F4 did not enable shell and map-view placement overlay.")
	var disable_event := _f4_event()
	shell._unhandled_input(disable_event)
	await get_tree().process_frame
	var disabled_snapshot: Dictionary = shell.call("validation_placement_debug_overlay_snapshot")
	var disabled_map: Dictionary = disabled_snapshot.get("map_view", {}) if disabled_snapshot.get("map_view", {}) is Dictionary else {}
	if bool(disabled_snapshot.get("enabled", true)) or bool(disabled_map.get("enabled", true)):
		failures.append("Second F4 did not disable shell and map-view placement overlay.")
	remove_child(shell)
	shell.queue_free()
	return {
		"ok": failures.is_empty(),
		"failures": failures,
		"enabled_snapshot": enabled_snapshot,
		"disabled_snapshot": disabled_snapshot,
	}

func _f4_event() -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = KEY_F4
	event.physical_keycode = KEY_F4
	event.pressed = true
	return event

func _tile_present(tiles_value: Variant, tile: Vector2i, kind: String, placement_id: String) -> bool:
	if not (tiles_value is Array):
		return false
	for value in tiles_value:
		if not (value is Dictionary):
			continue
		var entry: Dictionary = value
		if int(entry.get("x", -1)) != tile.x or int(entry.get("y", -1)) != tile.y:
			continue
		var kinds: Array = entry.get("kinds", []) if entry.get("kinds", []) is Array else []
		var placement_ids: Array = entry.get("placement_ids", []) if entry.get("placement_ids", []) is Array else []
		return kind in kinds and placement_id in placement_ids
	return false

func _fixture_session():
	var width := 20
	var height := 16
	var rows := []
	for _y in range(height):
		var row := []
		for _x in range(width):
			row.append("grass")
		rows.append(row)
	var session = SessionStateStore.SessionData.new("overlay_fixture", "overlay_fixture", "hero_lyra", 1, {
		"map": rows,
		"map_size": {"width": width, "height": height},
		"hero_position": {"x": 1, "y": 1},
		"hero": {"hero_id": "hero_lyra", "position": {"x": 1, "y": 1}},
		"player_heroes": [{"hero_id": "hero_lyra", "x": 1, "y": 1, "is_active": true}],
		"movement": {"current": 99, "max": 99},
		"towns": [{"placement_id": "overlay_town", "town_id": "town_frontier_keep", "owner": "player", "x": 8, "y": 8}],
		"resource_nodes": [
			{
				"placement_id": "overlay_authored_yard",
				"site_id": "site_brightwood_sawmill",
				"object_id": "object_brightwood_sawmill",
				"x": 5,
				"y": 5,
				"collected": false,
			},
			{
				"placement_id": "overlay_runtime_yard",
				"site_id": "site_brightwood_sawmill",
				"object_id": "object_brightwood_sawmill",
				"x": 12,
				"y": 10,
				"collected": false,
				"object_footprint_catalog_ref": {"id": "runtime_overlay_fixture"},
				"body_tiles": [{"x": 12, "y": 10}, {"x": 13, "y": 10}],
				"visit_tile": {"x": 12, "y": 11},
				"blocking_body": true,
			},
		],
		"artifact_nodes": [{"placement_id": "overlay_artifact", "artifact_id": "artifact_bastion_gorget", "x": 3, "y": 3, "collected": false}],
		"encounters": [{"placement_id": "overlay_encounter", "encounter_id": "encounter_mire_raid", "x": 4, "y": 4}],
		"resolved_encounters": [],
		"fog": _all_visible_fog(width, height),
	})
	session.game_state = "overworld"
	session.scenario_status = "in_progress"
	return session

func _all_visible_fog(width: int, height: int) -> Dictionary:
	var visible := []
	var explored := []
	for _y in range(height):
		var visible_row := []
		var explored_row := []
		for _x in range(width):
			visible_row.append(true)
			explored_row.append(true)
		visible.append(visible_row)
		explored.append(explored_row)
	return {
		"visible_tiles": visible,
		"explored_tiles": explored,
		"visible_count": width * height,
		"explored_count": width * height,
		"total_tiles": width * height,
	}
