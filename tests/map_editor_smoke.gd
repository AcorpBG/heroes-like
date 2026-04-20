extends Node

const SCENARIO_ID := "ninefold-confluence"
const MAP_EDITOR_SCENE_PATH := "res://scenes/editor/MapEditorShell.tscn"
const OVERWORLD_SCENE_PATH := "res://scenes/overworld/OverworldShell.tscn"

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

	if not _assert_object_property_edits(shell):
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
	if not await _assert_play_copy_round_trip(shell):
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

func _assert_object_property_edits(shell) -> bool:
	var town_result: Dictionary = shell.call("validation_edit_object_property", 23, 26, "town", "owner", "neutral")
	var town_detail := _object_detail_for_family(town_result.get("tile_inspection", {}), "town")
	if not bool(town_result.get("ok", false)) or String(town_detail.get("owner", "")) != "neutral":
		_fail("Map editor smoke: town owner property edit did not update working-copy inspection: %s." % town_result)
		return false
	var town_property: Dictionary = town_result.get("selected_property_object", {})
	if String(town_property.get("property_key", "")) != "town:ninefold_embercourt_survey_camp" or "owner" not in town_property.get("editable_properties", []):
		_fail("Map editor smoke: town property editor did not expose structured owner detail: %s." % town_result)
		return false
	var town_presentation: Dictionary = shell.call("validation_tile_presentation", 23, 26)
	if String(town_presentation.get("town_presentation", {}).get("owner", "")) != "neutral":
		_fail("Map editor smoke: live preview did not use the edited town owner: %s." % town_presentation)
		return false

	var resource_result: Dictionary = shell.call("validation_edit_object_property", 2, 6, "resource", "collected", true)
	var resource_detail := _object_detail_for_family(resource_result.get("tile_inspection", {}), "resource")
	if (
		not bool(resource_result.get("ok", false))
		or not bool(resource_detail.get("collected", false))
		or String(resource_detail.get("collected_by_faction_id", "")) != "player"
	):
		_fail("Map editor smoke: resource collected property edit did not update working-copy inspection: %s." % resource_result)
		return false
	var resource_presentation: Dictionary = shell.call("validation_tile_presentation", 2, 6)
	if bool(resource_presentation.get("has_resource", true)):
		_fail("Map editor smoke: live preview still exposed a collected resource pickup: %s." % resource_presentation)
		return false

	var artifact_result: Dictionary = shell.call("validation_edit_object_property", 9, 45, "artifact", "collected", true)
	var artifact_detail := _object_detail_for_family(artifact_result.get("tile_inspection", {}), "artifact")
	if (
		not bool(artifact_result.get("ok", false))
		or not bool(artifact_detail.get("collected", false))
		or String(artifact_detail.get("collected_by_faction_id", "")) != "player"
	):
		_fail("Map editor smoke: artifact collected property edit did not update working-copy inspection: %s." % artifact_result)
		return false
	var artifact_presentation: Dictionary = shell.call("validation_tile_presentation", 9, 45)
	if bool(artifact_presentation.get("has_artifact", true)):
		_fail("Map editor smoke: live preview still exposed a collected artifact node: %s." % artifact_presentation)
		return false

	var encounter_result: Dictionary = shell.call("validation_edit_object_property", 30, 32, "encounter", "difficulty", "low")
	var encounter_detail := _object_detail_for_family(encounter_result.get("tile_inspection", {}), "encounter")
	if not bool(encounter_result.get("ok", false)) or String(encounter_detail.get("difficulty", "")) != "low":
		_fail("Map editor smoke: encounter difficulty property edit did not update working-copy inspection: %s." % encounter_result)
		return false
	var encounter_property: Dictionary = encounter_result.get("selected_property_object", {})
	if "difficulty" not in encounter_property.get("editable_properties", []):
		_fail("Map editor smoke: encounter property editor did not expose structured difficulty detail: %s." % encounter_result)
		return false
	return true

func _assert_play_copy_round_trip(shell) -> bool:
	var previous_current = get_tree().current_scene
	var parent = shell.get_parent()
	if parent != get_tree().root:
		parent.remove_child(shell)
		get_tree().root.add_child(shell)
	get_tree().current_scene = shell

	var launch_result: Dictionary = shell.call("validation_launch_working_copy")
	if (
		not bool(launch_result.get("ok", false))
		or not bool(launch_result.get("editor_working_copy", false))
		or not bool(launch_result.get("editor_snapshot_available", false))
		or String(launch_result.get("return_model", "")) != "launch_snapshot"
	):
		_fail("Map editor smoke: Play Copy did not stage the editor working-copy snapshot: %s." % launch_result)
		return false

	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	var overworld = get_tree().current_scene
	var overworld_path := String(overworld.scene_file_path) if overworld != null else ""
	if overworld_path != OVERWORLD_SCENE_PATH or not overworld.has_method("validation_snapshot"):
		_fail("Map editor smoke: Play Copy did not route to the normal overworld shell; scene=%s." % overworld_path)
		return false
	var overworld_snapshot: Dictionary = overworld.call("validation_snapshot")
	if (
		not bool(overworld_snapshot.get("editor_working_copy", false))
		or String(overworld_snapshot.get("editor_return_model", "")) != "launch_snapshot"
	):
		_fail("Map editor smoke: overworld shell did not retain editor Play Copy metadata: %s." % overworld_snapshot)
		return false
	var play_hero: Dictionary = overworld_snapshot.get("hero_position", {})
	if int(play_hero.get("x", -1)) != 3 or int(play_hero.get("y", -1)) != 3:
		_fail("Map editor smoke: Play Copy did not launch from the edited hero start: %s." % overworld_snapshot)
		return false
	var play_tile: Dictionary = overworld.call("validation_tile_presentation", 2, 2)
	var play_terrain: Dictionary = play_tile.get("terrain_presentation", {})
	if String(play_terrain.get("terrain", "")) != "forest":
		_fail("Map editor smoke: Play Copy did not use the edited terrain working copy: %s." % play_tile)
		return false
	if not _assert_active_session_property_edits(SessionState.ensure_active_session()):
		return false

	_set_active_hero_position(SessionState.ensure_active_session(), Vector2i(4, 3))
	overworld.call("validation_return_to_menu")
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	var returned_editor = get_tree().current_scene
	var returned_path := String(returned_editor.scene_file_path) if returned_editor != null else ""
	if returned_path != MAP_EDITOR_SCENE_PATH or not returned_editor.has_method("validation_snapshot"):
		_fail("Map editor smoke: editor Play Copy return did not route back to MapEditorShell; scene=%s." % returned_path)
		return false
	var returned_snapshot: Dictionary = returned_editor.call("validation_snapshot")
	if (
		String(returned_snapshot.get("scenario_id", "")) != SCENARIO_ID
		or not bool(returned_snapshot.get("restored_from_play_copy", false))
		or String(returned_snapshot.get("return_model", "")) != "launch_snapshot"
	):
		_fail("Map editor smoke: returned editor did not restore the in-memory launch snapshot: %s." % returned_snapshot)
		return false
	var returned_hero: Dictionary = returned_snapshot.get("hero_position", {})
	if int(returned_hero.get("x", -1)) != 3 or int(returned_hero.get("y", -1)) != 3:
		_fail("Map editor smoke: returned editor imported live play mutation instead of the launch snapshot: %s." % returned_snapshot)
		return false
	var returned_tile: Dictionary = returned_editor.call("validation_tile_presentation", 2, 2)
	var returned_terrain: Dictionary = returned_tile.get("terrain_presentation", {})
	if String(returned_terrain.get("terrain", "")) != "forest":
		_fail("Map editor smoke: returned editor lost the edited terrain working copy: %s." % returned_tile)
		return false
	if not _assert_returned_editor_property_edits(returned_editor):
		return false
	if SessionState.ensure_active_session().scenario_id != "":
		_fail("Map editor smoke: returning to the editor should clear the active playable session.")
		return false

	if previous_current != null and is_instance_valid(previous_current):
		get_tree().current_scene = previous_current
	return true

func _assert_active_session_property_edits(session) -> bool:
	if _town_owner(session, "ninefold_embercourt_survey_camp") != "neutral":
		_fail("Map editor smoke: Play Copy did not use the edited town owner.")
		return false
	if not _resource_collected(session, "north_snow_timber"):
		_fail("Map editor smoke: Play Copy did not use the edited resource collected state.")
		return false
	if not _artifact_collected(session, "confluence_quarry_tally_rod"):
		_fail("Map editor smoke: Play Copy did not use the edited artifact collected state.")
		return false
	if _encounter_difficulty(session, "ninefold_reedmaw_host") != "low":
		_fail("Map editor smoke: Play Copy did not use the edited encounter difficulty.")
		return false
	return true

func _assert_returned_editor_property_edits(returned_editor) -> bool:
	var town_result: Dictionary = returned_editor.call("validation_select_tile", 23, 26)
	var town_detail := _object_detail_for_family(town_result.get("tile_inspection", {}), "town")
	if String(town_detail.get("owner", "")) != "neutral":
		_fail("Map editor smoke: returned editor lost the edited town owner: %s." % town_result)
		return false
	var resource_result: Dictionary = returned_editor.call("validation_select_tile", 2, 6)
	var resource_detail := _object_detail_for_family(resource_result.get("tile_inspection", {}), "resource")
	if not bool(resource_detail.get("collected", false)):
		_fail("Map editor smoke: returned editor lost the edited resource collected state: %s." % resource_result)
		return false
	var artifact_result: Dictionary = returned_editor.call("validation_select_tile", 9, 45)
	var artifact_detail := _object_detail_for_family(artifact_result.get("tile_inspection", {}), "artifact")
	if not bool(artifact_detail.get("collected", false)):
		_fail("Map editor smoke: returned editor lost the edited artifact collected state: %s." % artifact_result)
		return false
	var encounter_result: Dictionary = returned_editor.call("validation_select_tile", 30, 32)
	var encounter_detail := _object_detail_for_family(encounter_result.get("tile_inspection", {}), "encounter")
	if String(encounter_detail.get("difficulty", "")) != "low":
		_fail("Map editor smoke: returned editor lost the edited encounter difficulty: %s." % encounter_result)
		return false
	return true

func _set_active_hero_position(session, tile: Vector2i) -> void:
	var position_payload := {"x": tile.x, "y": tile.y}
	session.overworld["hero_position"] = position_payload.duplicate(true)
	var hero = session.overworld.get("hero", {})
	if hero is Dictionary:
		hero["position"] = position_payload.duplicate(true)
		session.overworld["hero"] = hero
	var heroes = session.overworld.get("player_heroes", [])
	if heroes is Array:
		var active_hero_id := String(session.overworld.get("active_hero_id", session.hero_id))
		for index in range(heroes.size()):
			var hero_state = heroes[index]
			if not (hero_state is Dictionary):
				continue
			if String(hero_state.get("id", "")) == active_hero_id:
				hero_state["position"] = position_payload.duplicate(true)
				heroes[index] = hero_state
				break
		session.overworld["player_heroes"] = heroes

func _town_owner(session, placement_id: String) -> String:
	for town in session.overworld.get("towns", []):
		if town is Dictionary and String(town.get("placement_id", "")) == placement_id:
			return String(town.get("owner", ""))
	return ""

func _resource_collected(session, placement_id: String) -> bool:
	for node in session.overworld.get("resource_nodes", []):
		if node is Dictionary and String(node.get("placement_id", "")) == placement_id:
			return bool(node.get("collected", false))
	return false

func _artifact_collected(session, placement_id: String) -> bool:
	for node in session.overworld.get("artifact_nodes", []):
		if node is Dictionary and String(node.get("placement_id", "")) == placement_id:
			return bool(node.get("collected", false))
	return false

func _encounter_difficulty(session, placement_id: String) -> String:
	for encounter in session.overworld.get("encounters", []):
		if encounter is Dictionary and String(encounter.get("placement_id", "")) == placement_id:
			return String(encounter.get("difficulty", ""))
	return ""

func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
