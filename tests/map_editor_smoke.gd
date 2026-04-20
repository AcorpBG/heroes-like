extends Node

const SCENARIO_ID := "ninefold-confluence"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var shell = load("res://scenes/editor/MapEditorShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame

	if not shell.has_method("validation_snapshot"):
		_fail("Map editor smoke: shell did not expose validation_snapshot.")
		return

	var snapshot: Dictionary = shell.call("validation_snapshot")
	if String(snapshot.get("scenario_id", "")) != SCENARIO_ID:
		_fail("Map editor smoke: default working copy did not load Ninefold Confluence: %s." % snapshot)
		return
	var map_size: Dictionary = snapshot.get("map_size", {})
	if int(map_size.get("x", 0)) != 64 or int(map_size.get("y", 0)) != 64:
		_fail("Map editor smoke: editor did not preserve the authored 64x64 map size: %s." % snapshot)
		return
	if SessionState.ensure_active_session().scenario_id != "":
		_fail("Map editor smoke: opening the editor should not replace the active playable session.")
		return
	if snapshot.get("map_viewport", {}).is_empty():
		_fail("Map editor smoke: reused overworld map view did not expose viewport metrics.")
		return

	var paint_result: Dictionary = shell.call("validation_paint_terrain", 2, 2, "forest")
	if not bool(paint_result.get("ok", false)):
		_fail("Map editor smoke: terrain paint hook failed: %s." % paint_result)
		return
	var paint_inspection: Dictionary = paint_result.get("tile_inspection", {})
	if String(paint_inspection.get("terrain_id", "")) != "forest" or not bool(paint_result.get("dirty", false)):
		_fail("Map editor smoke: terrain paint did not mutate the working copy: %s." % paint_result)
		return
	var paint_presentation: Dictionary = shell.call("validation_tile_presentation", 2, 2)
	var terrain_presentation: Dictionary = paint_presentation.get("terrain_presentation", {})
	if String(terrain_presentation.get("terrain", "")) != "forest":
		_fail("Map editor smoke: live map preview did not read the painted terrain: %s." % paint_presentation)
		return

	var add_road_result: Dictionary = shell.call("validation_toggle_road", 2, 2)
	var add_road_inspection: Dictionary = add_road_result.get("tile_inspection", {})
	var road_layers: Array = add_road_inspection.get("road_layers", [])
	if not bool(add_road_result.get("ok", false)) or not bool(add_road_inspection.get("road", false)) or "editor_working_road" not in road_layers:
		_fail("Map editor smoke: road toggle did not add an editor working-copy road: %s." % add_road_result)
		return
	var road_presentation: Dictionary = shell.call("validation_tile_presentation", 2, 2)
	var road_terrain: Dictionary = road_presentation.get("terrain_presentation", {})
	if not bool(road_terrain.get("road_overlay", false)) or String(road_terrain.get("road_overlay_id", "")) != "road_dirt":
		_fail("Map editor smoke: live map preview did not render the toggled road overlay: %s." % road_presentation)
		return

	var remove_road_result: Dictionary = shell.call("validation_toggle_road", 2, 2)
	var remove_road_inspection: Dictionary = remove_road_result.get("tile_inspection", {})
	if not bool(remove_road_result.get("ok", false)) or bool(remove_road_inspection.get("road", true)):
		_fail("Map editor smoke: second road toggle did not remove the road from the working copy: %s." % remove_road_result)
		return

	var hero_result: Dictionary = shell.call("validation_set_hero_start", 3, 3)
	var hero_position: Dictionary = hero_result.get("hero_position", {})
	if not bool(hero_result.get("ok", false)) or int(hero_position.get("x", -1)) != 3 or int(hero_position.get("y", -1)) != 3:
		_fail("Map editor smoke: hero-start tool did not move the working-copy hero: %s." % hero_result)
		return

	var inspect_result: Dictionary = shell.call("validation_select_tile", 23, 26)
	var inspect_payload: Dictionary = inspect_result.get("tile_inspection", {})
	if int(inspect_payload.get("object_count", 0)) <= 0:
		_fail("Map editor smoke: tile inspection did not expose objects on the authored starting town tile: %s." % inspect_result)
		return
	var objects: Array = inspect_payload.get("objects", [])
	var found_town := false
	for line in objects:
		if String(line).begins_with("Town:"):
			found_town = true
			break
	if not found_town:
		_fail("Map editor smoke: tile inspection did not identify the town object: %s." % inspect_payload)
		return

	if not _exercise_object_placement(shell, "town", "town_riverwatch", Vector2i(4, 4), "has_town"):
		return
	if not _exercise_object_placement(shell, "resource", "site_timber_wagon", Vector2i(5, 4), "has_resource"):
		return
	var artifact_move_seed: Dictionary = shell.call("validation_remove_object", 23, 5, "artifact")
	if not bool(artifact_move_seed.get("ok", false)):
		_fail("Map editor smoke: could not remove the authored artifact before exercising artifact relocation: %s." % artifact_move_seed)
		return
	if not _exercise_object_placement(shell, "artifact", "artifact_trailsinger_boots", Vector2i(6, 4), "has_artifact"):
		return
	if not _exercise_object_placement(shell, "encounter", "encounter_mire_raid", Vector2i(7, 4), "has_visible_encounter"):
		return

	get_tree().quit(0)

func _exercise_object_placement(shell, family: String, content_id: String, tile: Vector2i, presentation_key: String) -> bool:
	var before_snapshot: Dictionary = shell.call("validation_snapshot")
	var before_count := int(before_snapshot.get("placement_count", 0))
	var place_result: Dictionary = shell.call("validation_place_object", tile.x, tile.y, family, content_id)
	if not bool(place_result.get("ok", false)):
		_fail("Map editor smoke: placing %s %s failed at %s: %s." % [family, content_id, tile, place_result])
		return false
	if String(place_result.get("selected_object_family", "")) != family or String(place_result.get("selected_object_content_id", "")) != content_id:
		_fail("Map editor smoke: object palette did not track the placed %s %s: %s." % [family, content_id, place_result])
		return false
	if int(place_result.get("placement_count", 0)) != before_count + 1:
		_fail("Map editor smoke: placing %s did not add exactly one placement: %s." % [family, place_result])
		return false

	var placed_detail := _object_detail_for_family(place_result.get("tile_inspection", {}), family)
	if placed_detail.is_empty():
		_fail("Map editor smoke: tile inspection did not expose placed %s detail: %s." % [family, place_result])
		return false
	if String(placed_detail.get("content_id", "")) != content_id:
		_fail("Map editor smoke: placed %s detail used the wrong content id: %s." % [family, placed_detail])
		return false
	var placement_id := String(placed_detail.get("placement_id", ""))
	if not placement_id.begins_with("editor_%s_" % family):
		_fail("Map editor smoke: placed %s did not receive an editor placement id: %s." % [family, placed_detail])
		return false

	var presentation: Dictionary = shell.call("validation_tile_presentation", tile.x, tile.y)
	if not bool(presentation.get(presentation_key, false)) or not bool(presentation.get("draws_discoverable_object", false)):
		_fail("Map editor smoke: live preview did not expose placed %s object: %s." % [family, presentation])
		return false

	var remove_result: Dictionary = shell.call("validation_remove_object", tile.x, tile.y, family)
	if not bool(remove_result.get("ok", false)):
		_fail("Map editor smoke: removing %s %s failed at %s: %s." % [family, content_id, tile, remove_result])
		return false
	if int(remove_result.get("placement_count", 0)) != before_count:
		_fail("Map editor smoke: removing %s did not restore the placement count: %s." % [family, remove_result])
		return false
	if not _object_detail_for_family(remove_result.get("tile_inspection", {}), family).is_empty():
		_fail("Map editor smoke: tile inspection still exposed removed %s: %s." % [family, remove_result])
		return false
	var after_presentation: Dictionary = shell.call("validation_tile_presentation", tile.x, tile.y)
	if bool(after_presentation.get(presentation_key, false)):
		_fail("Map editor smoke: live preview still exposed removed %s object: %s." % [family, after_presentation])
		return false
	return true

func _object_detail_for_family(inspection: Dictionary, family: String) -> Dictionary:
	var details = inspection.get("object_details", [])
	if not (details is Array):
		return {}
	for detail in details:
		if detail is Dictionary and String(detail.get("kind", "")) == family:
			return detail
	return {}

func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
