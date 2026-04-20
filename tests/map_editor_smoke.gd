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
	if not _assert_editor_neighbor_transition_preview(shell):
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
	if not _assert_object_move_edits(shell):
		return
	if not _assert_object_duplicate_edits(shell):
		return
	if not _assert_object_retheme_edits(shell):
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

func _assert_editor_neighbor_transition_preview(shell) -> bool:
	var edge_receiver: Dictionary = shell.call("validation_tile_presentation", 2, 1)
	var edge_terrain: Dictionary = edge_receiver.get("terrain_presentation", {})
	if (
		not bool(edge_terrain.get("neighbor_aware_transitions", false))
		or String(edge_terrain.get("transition_calculation_model", "")) != "neighbor_priority_intrusion_8_way"
		or String(edge_terrain.get("transition_edge_model", "")) != "higher_priority_neighbor_intrusion_edges"
		or String(edge_terrain.get("transition_edge_mask", "")) != "S"
		or "forest" not in edge_terrain.get("transition_source_terrain_ids", [])
		or int(edge_terrain.get("edge_transition_count", 0)) != 1
	):
		_fail("Map editor smoke: editor preview did not put the painted forest edge onto its lower-priority neighbor: %s." % edge_receiver)
		return false
	var corner_receiver: Dictionary = shell.call("validation_tile_presentation", 1, 1)
	var corner_terrain: Dictionary = corner_receiver.get("terrain_presentation", {})
	if (
		String(corner_terrain.get("transition_corner_model", "")) != "diagonal_neighbor_corner_hints"
		or String(corner_terrain.get("transition_corner_mask", "")) != "SE"
		or "forest" not in corner_terrain.get("transition_source_terrain_ids", [])
		or int(corner_terrain.get("corner_transition_count", 0)) != 1
	):
		_fail("Map editor smoke: editor preview did not expose a diagonal corner transition from the painted forest tile: %s." % corner_receiver)
		return false
	return true

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

func _assert_object_move_edits(shell) -> bool:
	if not _assert_object_move(
		shell,
		"town",
		Vector2i(23, 26),
		Vector2i(24, 26),
		"ninefold_embercourt_survey_camp",
		"owner",
		"neutral"
	):
		return false
	if not _assert_object_move(
		shell,
		"resource",
		Vector2i(2, 6),
		Vector2i(3, 6),
		"north_snow_timber",
		"collected",
		true
	):
		return false
	if not _assert_object_move(
		shell,
		"artifact",
		Vector2i(9, 45),
		Vector2i(10, 45),
		"confluence_quarry_tally_rod",
		"collected",
		true
	):
		return false
	if not _assert_object_move(
		shell,
		"encounter",
		Vector2i(30, 32),
		Vector2i(31, 32),
		"ninefold_reedmaw_host",
		"difficulty",
		"low"
	):
		return false
	return true

func _assert_object_duplicate_edits(shell) -> bool:
	if not _assert_object_duplicate(
		shell,
		"town",
		Vector2i(24, 26),
		Vector2i(25, 26),
		"ninefold_embercourt_survey_camp",
		"owner",
		"neutral"
	):
		return false
	if not _assert_object_duplicate(
		shell,
		"resource",
		Vector2i(3, 6),
		Vector2i(4, 6),
		"north_snow_timber",
		"collected",
		true
	):
		return false
	if not _assert_object_duplicate(
		shell,
		"artifact",
		Vector2i(10, 45),
		Vector2i(11, 45),
		"confluence_quarry_tally_rod",
		"collected",
		true
	):
		return false
	if not _assert_object_duplicate(
		shell,
		"encounter",
		Vector2i(31, 32),
		Vector2i(32, 32),
		"ninefold_reedmaw_host",
		"difficulty",
		"low"
	):
		return false
	return true

func _assert_object_retheme_edits(shell) -> bool:
	if not _assert_object_retheme(
		shell,
		"town",
		Vector2i(24, 26),
		"ninefold_embercourt_survey_camp",
		"town_duskfen",
		"owner",
		"neutral"
	):
		return false
	if not _assert_object_retheme(
		shell,
		"resource",
		Vector2i(3, 6),
		"north_snow_timber",
		"site_free_company_yard",
		"collected",
		true
	):
		return false
	if not _assert_object_retheme(
		shell,
		"artifact",
		Vector2i(10, 45),
		"confluence_quarry_tally_rod",
		"artifact_bastion_gorget",
		"collected",
		true
	):
		return false
	if not _assert_object_retheme(
		shell,
		"encounter",
		Vector2i(31, 32),
		"ninefold_reedmaw_host",
		"encounter_mire_raid",
		"difficulty",
		"low"
	):
		return false
	return true

func _assert_object_move(
	shell,
	family: String,
	source: Vector2i,
	destination: Vector2i,
	placement_id: String,
	preserved_key: String,
	preserved_value: Variant
) -> bool:
	var before_snapshot: Dictionary = shell.call("validation_snapshot")
	var before_count := int(before_snapshot.get("placement_count", 0))
	var move_result: Dictionary = shell.call("validation_move_object", source.x, source.y, destination.x, destination.y, family)
	if not bool(move_result.get("ok", false)):
		_fail("Map editor smoke: moving %s %s from %s to %s failed: %s." % [family, placement_id, source, destination, move_result])
		return false
	if int(move_result.get("placement_count", 0)) != before_count:
		_fail("Map editor smoke: moving %s changed placement count: %s." % [family, move_result])
		return false
	var before_detail: Dictionary = move_result.get("source_detail_before", {})
	var source_after := _object_detail_for_family(move_result.get("source_tile_inspection", {}), family)
	if not source_after.is_empty():
		_fail("Map editor smoke: moving %s left a source object behind: %s." % [family, move_result])
		return false
	var moved_detail := _object_detail_for_family(move_result.get("destination_tile_inspection", {}), family)
	if moved_detail.is_empty() or String(moved_detail.get("placement_id", "")) != placement_id:
		_fail("Map editor smoke: moving %s did not expose the object at its destination: %s." % [family, move_result])
		return false
	if int(moved_detail.get("x", -1)) != destination.x or int(moved_detail.get("y", -1)) != destination.y:
		_fail("Map editor smoke: moved %s inspection did not report destination coordinates: %s." % [family, moved_detail])
		return false
	if moved_detail.get(preserved_key) != preserved_value:
		_fail("Map editor smoke: moving %s did not preserve %s=%s: %s." % [family, preserved_key, preserved_value, moved_detail])
		return false
	if family == "encounter" and int(moved_detail.get("combat_seed", 0)) != int(before_detail.get("combat_seed", 0)):
		_fail("Map editor smoke: moving encounter did not preserve combat_seed: before=%s after=%s." % [before_detail, moved_detail])
		return false
	if family in ["resource", "artifact"] and String(moved_detail.get("collected_by_faction_id", "")) != String(before_detail.get("collected_by_faction_id", "")):
		_fail("Map editor smoke: moving %s did not preserve collection metadata: before=%s after=%s." % [family, before_detail, moved_detail])
		return false
	var selected_property: Dictionary = move_result.get("selected_property_object", {})
	if int(selected_property.get("x", -1)) != destination.x or int(selected_property.get("y", -1)) != destination.y:
		_fail("Map editor smoke: validation snapshot did not select the moved %s at its destination: %s." % [family, move_result])
		return false
	var source_presentation: Dictionary = shell.call("validation_tile_presentation", source.x, source.y)
	var destination_presentation: Dictionary = shell.call("validation_tile_presentation", destination.x, destination.y)
	match family:
		"town":
			if bool(source_presentation.get("has_town", false)) or not bool(destination_presentation.get("has_town", false)):
				_fail("Map editor smoke: live preview did not move the town marker: source=%s destination=%s." % [source_presentation, destination_presentation])
				return false
			if String(destination_presentation.get("town_presentation", {}).get("owner", "")) != "neutral":
				_fail("Map editor smoke: moved town preview did not preserve owner: %s." % destination_presentation)
				return false
		"resource":
			if bool(source_presentation.get("has_resource", false)) or bool(destination_presentation.get("has_resource", true)):
				_fail("Map editor smoke: collected moved resource did not stay hidden in live preview: source=%s destination=%s." % [source_presentation, destination_presentation])
				return false
		"artifact":
			if bool(source_presentation.get("has_artifact", false)) or bool(destination_presentation.get("has_artifact", true)):
				_fail("Map editor smoke: collected moved artifact did not stay hidden in live preview: source=%s destination=%s." % [source_presentation, destination_presentation])
				return false
		"encounter":
			if bool(source_presentation.get("has_visible_encounter", false)) or not bool(destination_presentation.get("has_visible_encounter", false)):
				_fail("Map editor smoke: live preview did not move the encounter marker: source=%s destination=%s." % [source_presentation, destination_presentation])
				return false
	return true

func _assert_object_duplicate(
	shell,
	family: String,
	source: Vector2i,
	destination: Vector2i,
	source_placement_id: String,
	preserved_key: String,
	preserved_value: Variant
) -> bool:
	var before_snapshot: Dictionary = shell.call("validation_snapshot")
	var before_count := int(before_snapshot.get("placement_count", 0))
	var duplicate_result: Dictionary = shell.call("validation_duplicate_object", source.x, source.y, destination.x, destination.y, family)
	if not bool(duplicate_result.get("ok", false)):
		_fail("Map editor smoke: duplicating %s %s from %s to %s failed: %s." % [family, source_placement_id, source, destination, duplicate_result])
		return false
	if int(duplicate_result.get("placement_count", 0)) != before_count + 1:
		_fail("Map editor smoke: duplicating %s did not add exactly one placement: %s." % [family, duplicate_result])
		return false
	var before_detail: Dictionary = duplicate_result.get("source_detail_before", {})
	var source_after := _object_detail_for_family(duplicate_result.get("source_tile_inspection", {}), family)
	if source_after.is_empty() or String(source_after.get("placement_id", "")) != source_placement_id:
		_fail("Map editor smoke: duplicating %s did not preserve the source placement: %s." % [family, duplicate_result])
		return false
	var duplicate_detail := _object_detail_for_family(duplicate_result.get("destination_tile_inspection", {}), family)
	if duplicate_detail.is_empty():
		_fail("Map editor smoke: duplicating %s did not expose the duplicate at its destination: %s." % [family, duplicate_result])
		return false
	var duplicate_placement_id := String(duplicate_detail.get("placement_id", ""))
	if duplicate_placement_id == source_placement_id or not duplicate_placement_id.begins_with("editor_duplicate_%s_" % family):
		_fail("Map editor smoke: duplicated %s did not receive a fresh editor duplicate placement id: %s." % [family, duplicate_detail])
		return false
	if int(duplicate_detail.get("x", -1)) != destination.x or int(duplicate_detail.get("y", -1)) != destination.y:
		_fail("Map editor smoke: duplicated %s inspection did not report destination coordinates: %s." % [family, duplicate_detail])
		return false
	if String(duplicate_detail.get("content_id", "")) != String(before_detail.get("content_id", "")):
		_fail("Map editor smoke: duplicating %s did not preserve content id: before=%s after=%s." % [family, before_detail, duplicate_detail])
		return false
	if duplicate_detail.get(preserved_key) != preserved_value:
		_fail("Map editor smoke: duplicating %s did not preserve %s=%s: %s." % [family, preserved_key, preserved_value, duplicate_detail])
		return false
	if family == "encounter" and int(duplicate_detail.get("combat_seed", 0)) != int(before_detail.get("combat_seed", 0)):
		_fail("Map editor smoke: duplicating encounter did not preserve combat_seed: before=%s after=%s." % [before_detail, duplicate_detail])
		return false
	if family in ["resource", "artifact"] and String(duplicate_detail.get("collected_by_faction_id", "")) != String(before_detail.get("collected_by_faction_id", "")):
		_fail("Map editor smoke: duplicating %s did not preserve collection metadata: before=%s after=%s." % [family, before_detail, duplicate_detail])
		return false
	var selected_property: Dictionary = duplicate_result.get("selected_property_object", {})
	if String(selected_property.get("placement_id", "")) != duplicate_placement_id or int(selected_property.get("x", -1)) != destination.x or int(selected_property.get("y", -1)) != destination.y:
		_fail("Map editor smoke: validation snapshot did not select the duplicated %s at its destination: %s." % [family, duplicate_result])
		return false
	var source_presentation: Dictionary = shell.call("validation_tile_presentation", source.x, source.y)
	var destination_presentation: Dictionary = shell.call("validation_tile_presentation", destination.x, destination.y)
	match family:
		"town":
			if not bool(source_presentation.get("has_town", false)) or not bool(destination_presentation.get("has_town", false)):
				_fail("Map editor smoke: live preview did not expose both source and duplicated town markers: source=%s destination=%s." % [source_presentation, destination_presentation])
				return false
			if String(destination_presentation.get("town_presentation", {}).get("owner", "")) != "neutral":
				_fail("Map editor smoke: duplicated town preview did not preserve owner: %s." % destination_presentation)
				return false
		"resource":
			if bool(source_presentation.get("has_resource", true)) or bool(destination_presentation.get("has_resource", true)):
				_fail("Map editor smoke: collected duplicated resource did not stay hidden in live preview: source=%s destination=%s." % [source_presentation, destination_presentation])
				return false
		"artifact":
			if bool(source_presentation.get("has_artifact", true)) or bool(destination_presentation.get("has_artifact", true)):
				_fail("Map editor smoke: collected duplicated artifact did not stay hidden in live preview: source=%s destination=%s." % [source_presentation, destination_presentation])
				return false
		"encounter":
			if not bool(source_presentation.get("has_visible_encounter", false)) or not bool(destination_presentation.get("has_visible_encounter", false)):
				_fail("Map editor smoke: live preview did not expose both source and duplicated encounter markers: source=%s destination=%s." % [source_presentation, destination_presentation])
				return false
	return true

func _assert_object_retheme(
	shell,
	family: String,
	tile: Vector2i,
	placement_id: String,
	replacement_content_id: String,
	preserved_key: String,
	preserved_value: Variant
) -> bool:
	var before_snapshot: Dictionary = shell.call("validation_snapshot")
	var before_count := int(before_snapshot.get("placement_count", 0))
	var retheme_result: Dictionary = shell.call("validation_retheme_object", tile.x, tile.y, family, replacement_content_id)
	if not bool(retheme_result.get("ok", false)):
		_fail("Map editor smoke: retheming %s %s at %s to %s failed: %s." % [family, placement_id, tile, replacement_content_id, retheme_result])
		return false
	if int(retheme_result.get("placement_count", 0)) != before_count:
		_fail("Map editor smoke: retheming %s changed placement count: %s." % [family, retheme_result])
		return false
	var before_detail: Dictionary = retheme_result.get("source_detail_before", {})
	var after_detail := _object_detail_for_family(retheme_result.get("tile_inspection", {}), family)
	if after_detail.is_empty() or String(after_detail.get("placement_id", "")) != placement_id:
		_fail("Map editor smoke: retheming %s did not preserve the placement id in inspection: %s." % [family, retheme_result])
		return false
	if String(after_detail.get("content_id", "")) != replacement_content_id:
		_fail("Map editor smoke: retheming %s did not expose the replacement content id: %s." % [family, after_detail])
		return false
	if String(before_detail.get("content_id", "")) == replacement_content_id:
		_fail("Map editor smoke: retheme test picked the same content id for %s: %s." % [family, before_detail])
		return false
	if int(after_detail.get("x", -1)) != tile.x or int(after_detail.get("y", -1)) != tile.y:
		_fail("Map editor smoke: retheming %s changed placement coordinates: %s." % [family, after_detail])
		return false
	if after_detail.get(preserved_key) != preserved_value:
		_fail("Map editor smoke: retheming %s did not preserve %s=%s: %s." % [family, preserved_key, preserved_value, after_detail])
		return false
	if family == "encounter" and int(after_detail.get("combat_seed", 0)) != int(before_detail.get("combat_seed", 0)):
		_fail("Map editor smoke: retheming encounter did not preserve combat_seed: before=%s after=%s." % [before_detail, after_detail])
		return false
	if family in ["resource", "artifact"] and String(after_detail.get("collected_by_faction_id", "")) != String(before_detail.get("collected_by_faction_id", "")):
		_fail("Map editor smoke: retheming %s did not preserve collection metadata: before=%s after=%s." % [family, before_detail, after_detail])
		return false
	var selected_property: Dictionary = retheme_result.get("selected_property_object", {})
	if String(selected_property.get("placement_id", "")) != placement_id or String(selected_property.get("content_id", "")) != replacement_content_id:
		_fail("Map editor smoke: validation snapshot did not select the rethemed %s: %s." % [family, retheme_result])
		return false
	var presentation: Dictionary = shell.call("validation_tile_presentation", tile.x, tile.y)
	match family:
		"town":
			if not bool(presentation.get("has_town", false)) or String(presentation.get("town_presentation", {}).get("town_id", "")) != replacement_content_id:
				_fail("Map editor smoke: live preview did not use the rethemed town id: %s." % presentation)
				return false
			if String(presentation.get("town_presentation", {}).get("owner", "")) != "neutral":
				_fail("Map editor smoke: rethemed town preview did not preserve owner: %s." % presentation)
				return false
		"resource":
			if not bool(presentation.get("has_resource", false)):
				_fail("Map editor smoke: live preview did not expose the rethemed persistent resource site: %s." % presentation)
				return false
		"artifact":
			if bool(presentation.get("has_artifact", true)):
				_fail("Map editor smoke: rethemed collected artifact did not preserve hidden collected presentation: %s." % presentation)
				return false
		"encounter":
			if not bool(presentation.get("has_visible_encounter", false)):
				_fail("Map editor smoke: live preview did not expose the rethemed encounter marker: %s." % presentation)
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
	if _placement_content_id(session, "towns", "ninefold_embercourt_survey_camp", "town_id") != "town_duskfen":
		_fail("Map editor smoke: Play Copy did not use the rethemed town content id.")
		return false
	if _placement_position(session, "towns", "ninefold_embercourt_survey_camp") != Vector2i(24, 26):
		_fail("Map editor smoke: Play Copy did not use the moved town position.")
		return false
	if _town_owner(session, "editor_duplicate_town_ninefold_embercourt_survey_camp_25_26") != "neutral":
		_fail("Map editor smoke: Play Copy did not preserve the duplicated town owner.")
		return false
	if _placement_position(session, "towns", "editor_duplicate_town_ninefold_embercourt_survey_camp_25_26") != Vector2i(25, 26):
		_fail("Map editor smoke: Play Copy did not use the duplicated town position.")
		return false
	if not _resource_collected(session, "north_snow_timber"):
		_fail("Map editor smoke: Play Copy did not use the edited resource collected state.")
		return false
	if _placement_content_id(session, "resource_nodes", "north_snow_timber", "site_id") != "site_free_company_yard":
		_fail("Map editor smoke: Play Copy did not use the rethemed resource content id.")
		return false
	if _placement_position(session, "resource_nodes", "north_snow_timber") != Vector2i(3, 6):
		_fail("Map editor smoke: Play Copy did not use the moved resource position.")
		return false
	if not _resource_collected(session, "editor_duplicate_resource_north_snow_timber_4_6"):
		_fail("Map editor smoke: Play Copy did not preserve the duplicated resource collected state.")
		return false
	if _placement_position(session, "resource_nodes", "editor_duplicate_resource_north_snow_timber_4_6") != Vector2i(4, 6):
		_fail("Map editor smoke: Play Copy did not use the duplicated resource position.")
		return false
	if not _artifact_collected(session, "confluence_quarry_tally_rod"):
		_fail("Map editor smoke: Play Copy did not use the edited artifact collected state.")
		return false
	if _placement_content_id(session, "artifact_nodes", "confluence_quarry_tally_rod", "artifact_id") != "artifact_bastion_gorget":
		_fail("Map editor smoke: Play Copy did not use the rethemed artifact content id.")
		return false
	if _placement_position(session, "artifact_nodes", "confluence_quarry_tally_rod") != Vector2i(10, 45):
		_fail("Map editor smoke: Play Copy did not use the moved artifact position.")
		return false
	if not _artifact_collected(session, "editor_duplicate_artifact_confluence_quarry_tally_rod_11_45"):
		_fail("Map editor smoke: Play Copy did not preserve the duplicated artifact collected state.")
		return false
	if _placement_position(session, "artifact_nodes", "editor_duplicate_artifact_confluence_quarry_tally_rod_11_45") != Vector2i(11, 45):
		_fail("Map editor smoke: Play Copy did not use the duplicated artifact position.")
		return false
	if _encounter_difficulty(session, "ninefold_reedmaw_host") != "low":
		_fail("Map editor smoke: Play Copy did not use the edited encounter difficulty.")
		return false
	if _placement_content_id(session, "encounters", "ninefold_reedmaw_host", "encounter_id") != "encounter_mire_raid":
		_fail("Map editor smoke: Play Copy did not use the rethemed encounter content id.")
		return false
	if _placement_position(session, "encounters", "ninefold_reedmaw_host") != Vector2i(31, 32):
		_fail("Map editor smoke: Play Copy did not use the moved encounter position.")
		return false
	if _encounter_difficulty(session, "editor_duplicate_encounter_ninefold_reedmaw_host_32_32") != "low":
		_fail("Map editor smoke: Play Copy did not preserve the duplicated encounter difficulty.")
		return false
	if _placement_position(session, "encounters", "editor_duplicate_encounter_ninefold_reedmaw_host_32_32") != Vector2i(32, 32):
		_fail("Map editor smoke: Play Copy did not use the duplicated encounter position.")
		return false
	if _encounter_seed(session, "editor_duplicate_encounter_ninefold_reedmaw_host_32_32") != _encounter_seed(session, "ninefold_reedmaw_host"):
		_fail("Map editor smoke: Play Copy did not preserve the duplicated encounter combat seed.")
		return false
	return true

func _assert_returned_editor_property_edits(returned_editor) -> bool:
	var town_result: Dictionary = returned_editor.call("validation_select_tile", 24, 26)
	var town_detail := _object_detail_for_family(town_result.get("tile_inspection", {}), "town")
	if String(town_detail.get("owner", "")) != "neutral" or String(town_detail.get("content_id", "")) != "town_duskfen":
		_fail("Map editor smoke: returned editor lost the edited/rethemed town state: %s." % town_result)
		return false
	var duplicate_town_result: Dictionary = returned_editor.call("validation_select_tile", 25, 26)
	var duplicate_town_detail := _object_detail_for_family(duplicate_town_result.get("tile_inspection", {}), "town")
	if String(duplicate_town_detail.get("placement_id", "")) != "editor_duplicate_town_ninefold_embercourt_survey_camp_25_26" or String(duplicate_town_detail.get("owner", "")) != "neutral":
		_fail("Map editor smoke: returned editor lost the duplicated town state: %s." % duplicate_town_result)
		return false
	var resource_result: Dictionary = returned_editor.call("validation_select_tile", 3, 6)
	var resource_detail := _object_detail_for_family(resource_result.get("tile_inspection", {}), "resource")
	if not bool(resource_detail.get("collected", false)) or String(resource_detail.get("content_id", "")) != "site_free_company_yard":
		_fail("Map editor smoke: returned editor lost the edited/rethemed resource state: %s." % resource_result)
		return false
	var duplicate_resource_result: Dictionary = returned_editor.call("validation_select_tile", 4, 6)
	var duplicate_resource_detail := _object_detail_for_family(duplicate_resource_result.get("tile_inspection", {}), "resource")
	if String(duplicate_resource_detail.get("placement_id", "")) != "editor_duplicate_resource_north_snow_timber_4_6" or not bool(duplicate_resource_detail.get("collected", false)):
		_fail("Map editor smoke: returned editor lost the duplicated resource state: %s." % duplicate_resource_result)
		return false
	var artifact_result: Dictionary = returned_editor.call("validation_select_tile", 10, 45)
	var artifact_detail := _object_detail_for_family(artifact_result.get("tile_inspection", {}), "artifact")
	if not bool(artifact_detail.get("collected", false)) or String(artifact_detail.get("content_id", "")) != "artifact_bastion_gorget":
		_fail("Map editor smoke: returned editor lost the edited/rethemed artifact state: %s." % artifact_result)
		return false
	var duplicate_artifact_result: Dictionary = returned_editor.call("validation_select_tile", 11, 45)
	var duplicate_artifact_detail := _object_detail_for_family(duplicate_artifact_result.get("tile_inspection", {}), "artifact")
	if String(duplicate_artifact_detail.get("placement_id", "")) != "editor_duplicate_artifact_confluence_quarry_tally_rod_11_45" or not bool(duplicate_artifact_detail.get("collected", false)):
		_fail("Map editor smoke: returned editor lost the duplicated artifact state: %s." % duplicate_artifact_result)
		return false
	var encounter_result: Dictionary = returned_editor.call("validation_select_tile", 31, 32)
	var encounter_detail := _object_detail_for_family(encounter_result.get("tile_inspection", {}), "encounter")
	if String(encounter_detail.get("difficulty", "")) != "low" or String(encounter_detail.get("content_id", "")) != "encounter_mire_raid":
		_fail("Map editor smoke: returned editor lost the edited/rethemed encounter state: %s." % encounter_result)
		return false
	var duplicate_encounter_result: Dictionary = returned_editor.call("validation_select_tile", 32, 32)
	var duplicate_encounter_detail := _object_detail_for_family(duplicate_encounter_result.get("tile_inspection", {}), "encounter")
	if String(duplicate_encounter_detail.get("placement_id", "")) != "editor_duplicate_encounter_ninefold_reedmaw_host_32_32" or String(duplicate_encounter_detail.get("difficulty", "")) != "low" or int(duplicate_encounter_detail.get("combat_seed", 0)) != int(encounter_detail.get("combat_seed", -1)):
		_fail("Map editor smoke: returned editor lost the duplicated encounter state: %s." % duplicate_encounter_result)
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

func _placement_position(session, array_key: String, placement_id: String) -> Vector2i:
	for placement in session.overworld.get(array_key, []):
		if placement is Dictionary and String(placement.get("placement_id", "")) == placement_id:
			return Vector2i(int(placement.get("x", -999)), int(placement.get("y", -999)))
	return Vector2i(-999, -999)

func _placement_content_id(session, array_key: String, placement_id: String, content_key: String) -> String:
	for placement in session.overworld.get(array_key, []):
		if placement is Dictionary and String(placement.get("placement_id", "")) == placement_id:
			return String(placement.get(content_key, ""))
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

func _encounter_seed(session, placement_id: String) -> int:
	for encounter in session.overworld.get("encounters", []):
		if encounter is Dictionary and String(encounter.get("placement_id", "")) == placement_id:
			return int(encounter.get("combat_seed", 0))
	return 0

func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
