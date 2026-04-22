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
	if not _assert_editor_terrain_option_contract(shell, snapshot):
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
	if not _assert_editor_true_terrain_placement(shell):
		return
	if not _assert_editor_placement_source_lower_edge(shell):
		return
	if not _assert_editor_sand_heavy_corner_ownership(shell):
		return
	if not _assert_flood_fill_terrain(shell):
		return
	if not _assert_terrain_line_tool(shell):
		return
	if not _assert_terrain_rectangle_tool(shell):
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
	if not _assert_road_path_tool(shell):
		return

	var hero_result: Dictionary = shell.call("validation_set_hero_start", 3, 3)
	var hero_position: Dictionary = hero_result.get("hero_position", {})
	if not bool(hero_result.get("ok", false)) or int(hero_position.get("x", -1)) != 3 or int(hero_position.get("y", -1)) != 3:
		_fail("Map editor smoke: hero-start tool did not move the working-copy hero: %s." % hero_result)
		return

	if not _assert_selected_tile_restore(shell):
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

func _assert_editor_terrain_option_contract(shell, snapshot: Dictionary) -> bool:
	var expected_options := [
		{"id": "water", "label": "Water", "family": "water", "atlas": "watrtl"},
		{"id": "snow", "label": "Snow", "family": "snow", "atlas": "snowtl"},
		{"id": "grass", "label": "Grass", "family": "grass", "atlas": "grastl"},
		{"id": "wastes", "label": "Sand", "family": "sand", "atlas": "sandtl"},
		{"id": "badlands", "label": "Dirt", "family": "dirt", "atlas": "dirttl"},
		{"id": "lava", "label": "Lava", "family": "lava", "atlas": "lavatl"},
		{"id": "swamp", "label": "Swamp", "family": "swamp", "atlas": "swmptl"},
		{"id": "highland", "label": "Rock/None", "family": "rock", "atlas": "rocktl"},
	]
	if String(snapshot.get("terrain_option_contract", "")) != "homm3_base_family_picker" or String(snapshot.get("terrain_option_source", "")) != "editor_base_terrain_options":
		_fail("Map editor smoke: terrain picker did not expose the HoMM3 base-family option contract: %s." % snapshot)
		return false
	var options: Array = snapshot.get("terrain_options", [])
	if options.size() != expected_options.size():
		_fail("Map editor smoke: terrain picker exposed the wrong number of base terrain options: %s." % options)
		return false
	for index in range(expected_options.size()):
		var expected: Dictionary = expected_options[index]
		var option: Dictionary = options[index]
		if (
			String(option.get("id", "")) != String(expected.get("id", ""))
			or String(option.get("label", "")) != String(expected.get("label", ""))
			or String(option.get("homm3_family", "")) != String(expected.get("family", ""))
			or String(option.get("homm3_atlas", "")) != String(expected.get("atlas", ""))
		):
			_fail("Map editor smoke: terrain picker option %d did not match the HoMM3-style contract: %s." % [index, options])
			return false
	var option_ids: Array = snapshot.get("terrain_option_ids", [])
	for hidden_id in ["plains", "forest", "mire", "hills", "ridge", "coast", "shore", "ash", "cavern", "underway", "frost"]:
		if hidden_id in option_ids:
			_fail("Map editor smoke: terrain picker still exposed hidden logical terrain id %s: %s." % [hidden_id, option_ids])
			return false
	var hidden_select: Dictionary = shell.call("validation_select_terrain", "forest")
	if bool(hidden_select.get("ok", true)):
		_fail("Map editor smoke: hidden logical terrain id forest was still selectable through the picker validation surface: %s." % hidden_select)
		return false
	var visible_select: Dictionary = shell.call("validation_select_terrain", "wastes")
	if not bool(visible_select.get("ok", false)) or String(visible_select.get("selected_terrain_label", "")) != "Sand":
		_fail("Map editor smoke: visible Sand terrain option did not select through the picker validation surface: %s." % visible_select)
		return false
	var restore_select: Dictionary = shell.call("validation_select_terrain", "grass")
	if not bool(restore_select.get("ok", false)):
		_fail("Map editor smoke: could not restore Grass terrain after option-contract validation: %s." % restore_select)
		return false
	return true

func _assert_editor_neighbor_transition_preview(shell) -> bool:
	var forest_tile: Dictionary = shell.call("validation_tile_presentation", 2, 2)
	var forest_terrain: Dictionary = forest_tile.get("terrain_presentation", {})
	if (
		String(forest_terrain.get("terrain", "")) != "forest"
		or String(forest_terrain.get("homm3_terrain_family", "")) != "grass"
		or String(forest_terrain.get("homm3_logical_degrade_note", "")) == ""
	):
		_fail("Map editor smoke: logical forest terrain did not expose its explicit HoMM3 local-prototype atlas limitation: %s." % forest_tile)
		return false
	var original_terrains := []
	var controlled_tiles := [
		Vector2i(0, 0),
		Vector2i(1, 0),
		Vector2i(2, 0),
		Vector2i(3, 0),
		Vector2i(0, 1),
		Vector2i(1, 1),
		Vector2i(2, 1),
		Vector2i(3, 1),
		Vector2i(0, 2),
		Vector2i(1, 2),
		Vector2i(2, 2),
		Vector2i(3, 2),
	]
	for tile in controlled_tiles:
		var presentation: Dictionary = shell.call("validation_tile_presentation", tile.x, tile.y)
		original_terrains.append({
			"tile": tile,
			"terrain": String(presentation.get("terrain_presentation", {}).get("terrain", "grass")),
		})
		if not _paint_editor_terrain_for_orientation(shell, tile, "forest"):
			_restore_editor_terrain_tiles(shell, original_terrains)
			_fail("Map editor smoke: could not seed forest baseline for HoMM3 bridge-table preview at %s." % tile)
			return false
	var mire_seed_ok := _paint_editor_terrain_for_orientation(shell, Vector2i(2, 2), "mire")
	if not mire_seed_ok:
		_restore_editor_terrain_tiles(shell, original_terrains)
		_fail("Map editor smoke: could not seed mire terrain for HoMM3 bridge-table preview.")
		return false
	var edge_receiver: Dictionary = shell.call("validation_tile_presentation", 2, 1)
	var edge_terrain: Dictionary = edge_receiver.get("terrain_presentation", {})
	if (
		not bool(edge_terrain.get("neighbor_aware_transitions", false))
		or String(edge_terrain.get("transition_calculation_model", "")) != "accepted_web_prototype_relation_class_row_lookup"
		or String(edge_terrain.get("transition_edge_model", "")) != "bridge_or_shoreline_atlas_frame_lookup"
		or String(edge_terrain.get("transition_edge_mask", "")) != "S"
		or "mire" not in edge_terrain.get("transition_source_terrain_ids", [])
		or String(edge_terrain.get("homm3_selection_kind", "")) != "bridge_transition"
		or String(edge_terrain.get("homm3_bridge_family", "")) != "dirt"
		or int(edge_terrain.get("edge_transition_count", 0)) != 1
	):
		_restore_editor_terrain_tiles(shell, original_terrains)
		_fail("Map editor smoke: editor preview did not use the HoMM3 full-receiver stamp lookup at the painted mire edge: %s." % edge_receiver)
		return false
	if not _assert_full_receiver_stamp_payload(edge_terrain, {
		"table": "full_receiver_native_to_dirt_5x4_provisional_stamp_table",
		"direction": "S",
		"frame": "00_12",
		"offset": {"x": 0, "y": 1},
		"bridge_family": "dirt",
		"target_block": "native_to_dirt_transition",
		"source_kind": "cardinal_source",
	}):
		_restore_editor_terrain_tiles(shell, original_terrains)
		_fail("Map editor smoke: painted mire edge did not expose full-receiver stamp metadata: %s." % edge_receiver)
		return false
	var corner_receiver: Dictionary = shell.call("validation_tile_presentation", 1, 1)
	var corner_terrain: Dictionary = corner_receiver.get("terrain_presentation", {})
	if (
		String(corner_terrain.get("homm3_selection_kind", "")) != "bridge_transition"
		or int(corner_terrain.get("homm3_shape_class", 0)) != 5
		or String(corner_terrain.get("homm3_row_group", "")) != "12-15"
		or String(corner_terrain.get("transition_corner_mask", "")) != ""
		or int(corner_terrain.get("corner_transition_count", -1)) != 0
		or bool(corner_terrain.get("homm3_propagated_transition", false))
		or String(corner_terrain.get("homm3_selected_frame_block", "")) != "native_to_dirt_transition"
		or "mire" in corner_terrain.get("transition_source_terrain_ids", [])
	):
		_restore_editor_terrain_tiles(shell, original_terrains)
		_fail("Map editor smoke: diagonal-only full-receiver context did not follow the accepted relation-class row lookup: %s." % corner_receiver)
		return false
	if not _assert_editor_direct_dirt_swamp_transition(shell):
		_restore_editor_terrain_tiles(shell, original_terrains)
		return false
	if not _assert_editor_horizontal_transition_orientation(shell):
		_restore_editor_terrain_tiles(shell, original_terrains)
		return false
	if not _assert_editor_solid_region_interior_stability(shell):
		_restore_editor_terrain_tiles(shell, original_terrains)
		return false
	if not _assert_editor_special_system_groundwork(shell):
		_restore_editor_terrain_tiles(shell, original_terrains)
		return false
	if not _assert_editor_bridge_material_resolver(shell):
		_restore_editor_terrain_tiles(shell, original_terrains)
		return false
	if not _assert_editor_restamp_behavior_model(shell):
		_restore_editor_terrain_tiles(shell, original_terrains)
		return false
	_restore_editor_terrain_tiles(shell, original_terrains)
	return true

func _assert_editor_direct_dirt_swamp_transition(shell) -> bool:
	var original_terrains := []
	var controlled_tiles := [
		Vector2i(46, 40),
		Vector2i(47, 39),
		Vector2i(47, 40),
		Vector2i(47, 41),
		Vector2i(48, 39),
		Vector2i(48, 40),
		Vector2i(48, 41),
		Vector2i(49, 40),
	]
	for tile in controlled_tiles:
		var presentation: Dictionary = shell.call("validation_tile_presentation", tile.x, tile.y)
		original_terrains.append({
			"tile": tile,
			"terrain": String(presentation.get("terrain_presentation", {}).get("terrain", "grass")),
		})
		if not _paint_editor_terrain_for_orientation(shell, tile, "grass"):
			_restore_editor_terrain_tiles(shell, original_terrains)
			_fail("Map editor smoke: could not seed grass baseline for controlled dirt/swamp transition tile %s." % tile)
			return false
	var paint_plan := [
		{"tile": Vector2i(46, 40), "terrain": "badlands"},
		{"tile": Vector2i(47, 39), "terrain": "badlands"},
		{"tile": Vector2i(47, 40), "terrain": "badlands"},
		{"tile": Vector2i(47, 41), "terrain": "badlands"},
		{"tile": Vector2i(48, 39), "terrain": "swamp"},
		{"tile": Vector2i(48, 40), "terrain": "swamp"},
		{"tile": Vector2i(48, 41), "terrain": "swamp"},
		{"tile": Vector2i(49, 40), "terrain": "swamp"},
	]
	for entry in paint_plan:
		var tile: Vector2i = entry.get("tile", Vector2i.ZERO)
		if not _paint_editor_terrain_for_orientation(shell, tile, String(entry.get("terrain", ""))):
			_restore_editor_terrain_tiles(shell, original_terrains)
			_fail("Map editor smoke: could not seed controlled dirt/swamp transition tile %s." % entry)
			return false

	var dirt_receiver: Dictionary = shell.call("validation_tile_presentation", 47, 40)
	var dirt_terrain: Dictionary = dirt_receiver.get("terrain_presentation", {})
	if (
		String(dirt_terrain.get("terrain", "")) != "badlands"
		or String(dirt_terrain.get("homm3_terrain_family", "")) != "dirt"
		or String(dirt_terrain.get("homm3_terrain_atlas", "")) != "dirttl"
		or String(dirt_terrain.get("transition_edge_mask", "")) != "E"
		or String(dirt_terrain.get("homm3_selection_kind", "")) != "interior"
		or int(dirt_terrain.get("homm3_shape_class", -1)) != 0
		or String(dirt_terrain.get("homm3_bridge_family", "")) != ""
		or String(dirt_terrain.get("homm3_bridge_resolution_model", "")) != "accepted_web_relation_function"
		or not _transition_sources_include_bridge(dirt_terrain, "E", "swamp", "dirt", "direct_family_pair_lookup")
	):
		_restore_editor_terrain_tiles(shell, original_terrains)
		_fail("Map editor smoke: dirt as center no longer followed the recovered relation function's full/native rule while still reporting source diagnostics: %s." % dirt_receiver)
		return false

	var swamp_receiver: Dictionary = shell.call("validation_tile_presentation", 48, 40)
	var swamp_terrain: Dictionary = swamp_receiver.get("terrain_presentation", {})
	if (
		String(swamp_terrain.get("terrain", "")) != "swamp"
		or String(swamp_terrain.get("homm3_terrain_family", "")) != "swamp"
		or String(swamp_terrain.get("homm3_terrain_atlas", "")) != "swmptl"
		or String(swamp_terrain.get("transition_edge_mask", "")) != "W"
		or String(swamp_terrain.get("homm3_selection_kind", "")) != "bridge_transition"
		or String(swamp_terrain.get("homm3_bridge_family", "")) != "mixed"
		or String(swamp_terrain.get("homm3_bridge_resolution_model", "")) != "accepted_web_relation_function"
		or not _transition_sources_include_bridge(swamp_terrain, "W", "badlands", "dirt", "direct_family_pair_lookup")
	):
		_restore_editor_terrain_tiles(shell, original_terrains)
		_fail("Map editor smoke: direct swamp->dirt preview transition incorrectly routed through sand: %s." % swamp_receiver)
		return false
	if not _assert_full_receiver_stamp_payload(swamp_terrain, {
		"table": "full_receiver_native_to_dirt_5x4_provisional_stamp_table",
		"direction": "W",
		"frame": "00_43",
		"offset": {"x": -1, "y": 0},
		"bridge_family": "mixed",
		"target_block": "mixed_junction_reserved",
		"source_kind": "cardinal_source",
		"shape_class": 17,
		"row_group": "43",
		"flip": "H",
		"flip_h": true,
		"flip_v": false,
	}):
		_restore_editor_terrain_tiles(shell, original_terrains)
		_fail("Map editor smoke: direct swamp->dirt preview did not expose full-receiver stamp metadata: %s." % swamp_receiver)
		return false

	_restore_editor_terrain_tiles(shell, original_terrains)
	return true

func _assert_editor_horizontal_transition_orientation(shell) -> bool:
	var original_terrains := []
	var controlled_tiles := [
		Vector2i(39, 39),
		Vector2i(40, 39),
		Vector2i(41, 39),
		Vector2i(39, 40),
		Vector2i(40, 40),
		Vector2i(41, 40),
		Vector2i(39, 41),
		Vector2i(40, 41),
		Vector2i(41, 41),
		Vector2i(43, 39),
		Vector2i(44, 39),
		Vector2i(45, 39),
		Vector2i(43, 40),
		Vector2i(44, 40),
		Vector2i(45, 40),
		Vector2i(43, 41),
		Vector2i(44, 41),
		Vector2i(45, 41),
	]
	for tile in controlled_tiles:
		var presentation: Dictionary = shell.call("validation_tile_presentation", tile.x, tile.y)
		original_terrains.append({
			"tile": tile,
			"terrain": String(presentation.get("terrain_presentation", {}).get("terrain", "grass")),
		})
		if not _paint_editor_terrain_for_orientation(shell, tile, "grass"):
			_restore_editor_terrain_tiles(shell, original_terrains)
			_fail("Map editor smoke: could not seed grass baseline for controlled HoMM3 horizontal transition tile %s." % tile)
			return false
	var paint_plan := [
		{"tile": Vector2i(40, 40), "terrain": "grass"},
		{"tile": Vector2i(41, 40), "terrain": "plains"},
		{"tile": Vector2i(39, 40), "terrain": "grass"},
		{"tile": Vector2i(40, 39), "terrain": "grass"},
		{"tile": Vector2i(40, 41), "terrain": "grass"},
		{"tile": Vector2i(44, 40), "terrain": "grass"},
		{"tile": Vector2i(43, 40), "terrain": "plains"},
		{"tile": Vector2i(45, 40), "terrain": "grass"},
		{"tile": Vector2i(44, 39), "terrain": "grass"},
		{"tile": Vector2i(44, 41), "terrain": "grass"},
	]
	for entry in paint_plan:
		var tile: Vector2i = entry.get("tile", Vector2i.ZERO)
		if not _paint_editor_terrain_for_orientation(shell, tile, String(entry.get("terrain", ""))):
			_restore_editor_terrain_tiles(shell, original_terrains)
			_fail("Map editor smoke: could not seed controlled HoMM3 horizontal transition tile %s." % entry)
			return false

	var east_receiver: Dictionary = shell.call("validation_tile_presentation", 40, 40)
	var east_terrain: Dictionary = east_receiver.get("terrain_presentation", {})
	if (
		String(east_terrain.get("transition_edge_mask", "")) != "E"
		or String(east_terrain.get("homm3_selection_kind", "")) != "bridge_transition"
		or String(east_terrain.get("homm3_terrain_frame", "")) != "00_04"
		or int(east_terrain.get("homm3_shape_class", 0)) != 3
		or String(east_terrain.get("homm3_terrain_flip", "")) != "H"
		or not _transition_sources_include(east_terrain, "E", "plains")
	):
		_restore_editor_terrain_tiles(shell, original_terrains)
		_fail("Map editor smoke: HoMM3 east-side bridge transition did not keep dirt on the visual right in preview: %s." % east_receiver)
		return false
	if not _assert_full_receiver_stamp_payload(east_terrain, {
		"table": "full_receiver_native_to_dirt_5x4_provisional_stamp_table",
		"direction": "E",
		"frame": "00_04",
		"offset": {"x": 1, "y": 0},
		"bridge_family": "dirt",
		"target_block": "native_to_dirt_transition",
		"source_kind": "cardinal_source",
		"shape_class": 3,
		"row_group": "4-7",
		"flip": "H",
		"flip_h": true,
		"flip_v": false,
	}):
		_restore_editor_terrain_tiles(shell, original_terrains)
		_fail("Map editor smoke: east-side bridge transition did not expose full-receiver stamp metadata: %s." % east_receiver)
		return false

	var west_receiver: Dictionary = shell.call("validation_tile_presentation", 44, 40)
	var west_terrain: Dictionary = west_receiver.get("terrain_presentation", {})
	if (
		String(west_terrain.get("transition_edge_mask", "")) != "W"
		or String(west_terrain.get("homm3_selection_kind", "")) != "bridge_transition"
		or String(west_terrain.get("homm3_terrain_frame", "")) != "00_04"
		or int(west_terrain.get("homm3_shape_class", 0)) != 3
		or String(west_terrain.get("homm3_terrain_flip", "")) != ""
		or not _transition_sources_include(west_terrain, "W", "plains")
	):
		_restore_editor_terrain_tiles(shell, original_terrains)
		_fail("Map editor smoke: HoMM3 west-side bridge transition did not keep dirt on the visual left in preview: %s." % west_receiver)
		return false
	if not _assert_full_receiver_stamp_payload(west_terrain, {
		"table": "full_receiver_native_to_dirt_5x4_provisional_stamp_table",
		"direction": "W",
		"frame": "00_04",
		"offset": {"x": -1, "y": 0},
		"bridge_family": "dirt",
		"target_block": "native_to_dirt_transition",
		"source_kind": "cardinal_source",
		"shape_class": 3,
		"row_group": "4-7",
		"flip": "",
		"flip_h": false,
		"flip_v": false,
	}):
		_restore_editor_terrain_tiles(shell, original_terrains)
		_fail("Map editor smoke: west-side bridge transition did not expose full-receiver stamp metadata: %s." % west_receiver)
		return false

	_restore_editor_terrain_tiles(shell, original_terrains)
	return true

func _assert_editor_special_system_groundwork(shell) -> bool:
	var centers := [Vector2i(58, 48), Vector2i(58, 52)]
	var original_terrains := []
	for center in centers:
		for y in range(center.y - 1, center.y + 2):
			for x in range(center.x - 1, center.x + 2):
				var tile := Vector2i(x, y)
				var presentation: Dictionary = shell.call("validation_tile_presentation", tile.x, tile.y)
				original_terrains.append({
					"tile": tile,
					"terrain": String(presentation.get("terrain_presentation", {}).get("terrain", "grass")),
				})
				if not _paint_editor_terrain_for_orientation(shell, tile, "grass"):
					_restore_editor_terrain_tiles(shell, original_terrains)
					_fail("Map editor smoke: could not seed grass for special terrain system test at %s." % tile)
					return false

	var rock_center: Vector2i = centers[0]
	if not _paint_editor_terrain_for_orientation(shell, rock_center, "highland"):
		_restore_editor_terrain_tiles(shell, original_terrains)
		_fail("Map editor smoke: could not seed rock/void special-system terrain.")
		return false
	var rock_presentation: Dictionary = shell.call("validation_tile_presentation", rock_center.x, rock_center.y)
	var rock_terrain: Dictionary = rock_presentation.get("terrain_presentation", {})
	if (
		String(rock_terrain.get("homm3_terrain_family", "")) != "rock"
		or String(rock_terrain.get("homm3_terrain_atlas", "")) != "rocktl"
		or String(rock_terrain.get("homm3_atlas_role", "")) != "special_rock_void"
		or String(rock_terrain.get("homm3_special_system", "")) != "rock_void_cliff"
		or bool(rock_terrain.get("homm3_allows_generic_land_edge_masks", true))
		or String(rock_terrain.get("homm3_selection_kind", "")) != "rock_system"
		or String(rock_terrain.get("homm3_bridge_source_kind", "")) != "relation_class_sand"
		or String(rock_terrain.get("homm3_bridge_resolution_model", "")) != "accepted_web_relation_function"
		or String(rock_terrain.get("homm3_preferred_bridge_class", "")) != "sand_bridge"
		or int(rock_terrain.get("homm3_shape_class", 0)) != 24
		or String(rock_terrain.get("homm3_fallback_reason", "")).find("missing rock row bucket") < 0
		or String(rock_terrain.get("homm3_selected_frame_block", "")) != "rock_black_void"
		or String(rock_terrain.get("homm3_rock_ground_context", "")) != "preferred_light_ground"
	):
		_restore_editor_terrain_tiles(shell, original_terrains)
		_fail("Map editor smoke: rock terrain did not expose the accepted relation-class fallback for an unmaintained class-24 topology: %s." % rock_presentation)
		return false

	var water_center: Vector2i = centers[1]
	if not _paint_editor_terrain_for_orientation(shell, water_center, "water"):
		_restore_editor_terrain_tiles(shell, original_terrains)
		_fail("Map editor smoke: could not seed water special-system terrain.")
		return false
	var water_presentation: Dictionary = shell.call("validation_tile_presentation", water_center.x, water_center.y)
	var water_terrain: Dictionary = water_presentation.get("terrain_presentation", {})
	if (
		String(water_terrain.get("homm3_terrain_family", "")) != "water"
		or String(water_terrain.get("homm3_terrain_atlas", "")) != "watrtl"
		or String(water_terrain.get("homm3_atlas_role", "")) != "shoreline_system"
		or String(water_terrain.get("homm3_special_system", "")) != "water_shoreline"
		or bool(water_terrain.get("homm3_allows_generic_land_edge_masks", true))
		or String(water_terrain.get("homm3_selection_kind", "")) != "water_shoreline"
		or String(water_terrain.get("homm3_bridge_source_kind", "")) != "relation_class_sand"
		or String(water_terrain.get("homm3_bridge_resolution_model", "")) != "accepted_web_relation_function"
		or String(water_terrain.get("homm3_water_bridge_class", "")) != "sand_bridge"
		or int(water_terrain.get("homm3_shape_class", 0)) != 24
		or String(water_terrain.get("homm3_fallback_reason", "")).find("missing row bucket") < 0
		or String(water_terrain.get("homm3_selected_frame_block", "")) != "open_water_interiors"
	):
		_restore_editor_terrain_tiles(shell, original_terrains)
		_fail("Map editor smoke: water terrain did not expose the accepted relation-class fallback for an unmaintained class-24 topology: %s." % water_presentation)
		return false

	var direct_rock_tile := water_center + Vector2i(1, 0)
	if not _paint_editor_terrain_for_orientation(shell, direct_rock_tile, "highland"):
		_restore_editor_terrain_tiles(shell, original_terrains)
		_fail("Map editor smoke: could not seed direct water/rock relation-class contact at %s." % direct_rock_tile)
		return false
	var direct_water_presentation: Dictionary = shell.call("validation_tile_presentation", water_center.x, water_center.y)
	var direct_water_terrain: Dictionary = direct_water_presentation.get("terrain_presentation", {})
	var water_ring: Array = direct_water_terrain.get("homm3_relation_ring", [])
	if (
		String(direct_water_terrain.get("homm3_terrain_family", "")) != "water"
		or not bool(direct_water_terrain.get("homm3_fallback", false))
		or not bool(direct_water_terrain.get("homm3_direct_water_rock_contact", false))
		or not bool(direct_water_terrain.get("homm3_web_prototype_direct_water_rock_contact", false))
		or String(direct_water_terrain.get("homm3_fallback_reason", "")).find("direct water/rock contact") < 0
		or water_ring.size() < 3
		or int(water_ring[2]) != 2
		or String(direct_water_terrain.get("homm3_projection_model", "")) != "accepted_web_prototype_cardinal_material_projection.v1"
		or not _string_array_matches(direct_water_terrain.get("homm3_material_quadrants", []), ["land", "mixed", "land", "mixed"])
		or not _string_array_matches(direct_water_terrain.get("homm3_normalized_quadrants", []), ["land", "land", "land", "land"])
		or not _string_array_matches(direct_water_terrain.get("homm3_display_quadrants", []), ["land", "mixed", "land", "mixed"])
	):
		_restore_editor_terrain_tiles(shell, original_terrains)
		_fail("Map editor smoke: direct water/rock water cell did not expose the accepted unresolved fallback truth signal: %s." % direct_water_presentation)
		return false
	var direct_rock_presentation: Dictionary = shell.call("validation_tile_presentation", direct_rock_tile.x, direct_rock_tile.y)
	var direct_rock_terrain: Dictionary = direct_rock_presentation.get("terrain_presentation", {})
	var rock_ring: Array = direct_rock_terrain.get("homm3_relation_ring", [])
	if (
		String(direct_rock_terrain.get("homm3_terrain_family", "")) != "rock"
		or not bool(direct_rock_terrain.get("homm3_fallback", false))
		or not bool(direct_rock_terrain.get("homm3_direct_water_rock_contact", false))
		or not bool(direct_rock_terrain.get("homm3_web_prototype_direct_water_rock_contact", false))
		or String(direct_rock_terrain.get("homm3_fallback_reason", "")).find("direct water/rock contact") < 0
		or rock_ring.size() < 7
		or int(rock_ring[6]) != 2
		or String(direct_rock_terrain.get("homm3_projection_model", "")) != "accepted_web_prototype_cardinal_material_projection.v1"
		or not _string_array_matches(direct_rock_terrain.get("homm3_material_quadrants", []), ["mixed", "sand", "mixed", "sand"])
		or not _string_array_matches(direct_rock_terrain.get("homm3_normalized_quadrants", []), ["sand", "sand", "sand", "sand"])
		or not _string_array_matches(direct_rock_terrain.get("homm3_display_quadrants", []), ["mixed", "sand", "mixed", "sand"])
	):
		_restore_editor_terrain_tiles(shell, original_terrains)
		_fail("Map editor smoke: direct water/rock rock cell did not expose the accepted unresolved fallback truth signal: %s." % direct_rock_presentation)
		return false

	_restore_editor_terrain_tiles(shell, original_terrains)
	return true

func _assert_editor_bridge_material_resolver(shell) -> bool:
	var controlled_tiles := []
	for y in range(31, 34):
		for x in range(31, 58):
			controlled_tiles.append(Vector2i(x, y))
	var original_terrains := []
	for tile in controlled_tiles:
		var presentation: Dictionary = shell.call("validation_tile_presentation", tile.x, tile.y)
		original_terrains.append({
			"tile": tile,
			"terrain": String(presentation.get("terrain_presentation", {}).get("terrain", "grass")),
		})
		if not _paint_editor_terrain_for_orientation(shell, tile, "grass"):
			_restore_editor_terrain_tiles(shell, original_terrains)
			_fail("Map editor smoke: could not seed bridge resolver grass baseline at %s." % tile)
			return false
	var fixture_plan := [
		{"tile": Vector2i(32, 32), "terrain": "grass"},
		{"tile": Vector2i(33, 32), "terrain": "badlands"},
		{"tile": Vector2i(36, 32), "terrain": "badlands"},
		{"tile": Vector2i(36, 31), "terrain": "badlands"},
		{"tile": Vector2i(36, 33), "terrain": "badlands"},
		{"tile": Vector2i(35, 32), "terrain": "badlands"},
		{"tile": Vector2i(37, 32), "terrain": "wastes"},
		{"tile": Vector2i(40, 32), "terrain": "grass"},
		{"tile": Vector2i(41, 32), "terrain": "swamp"},
		{"tile": Vector2i(44, 32), "terrain": "grass"},
		{"tile": Vector2i(45, 32), "terrain": "snow"},
		{"tile": Vector2i(48, 32), "terrain": "cavern"},
		{"tile": Vector2i(48, 31), "terrain": "cavern"},
		{"tile": Vector2i(48, 33), "terrain": "cavern"},
		{"tile": Vector2i(47, 32), "terrain": "cavern"},
		{"tile": Vector2i(49, 32), "terrain": "grass"},
		{"tile": Vector2i(52, 32), "terrain": "water"},
		{"tile": Vector2i(52, 31), "terrain": "water"},
		{"tile": Vector2i(52, 33), "terrain": "water"},
		{"tile": Vector2i(51, 32), "terrain": "water"},
		{"tile": Vector2i(53, 32), "terrain": "grass"},
		{"tile": Vector2i(56, 32), "terrain": "highland"},
		{"tile": Vector2i(56, 31), "terrain": "highland"},
		{"tile": Vector2i(56, 33), "terrain": "highland"},
		{"tile": Vector2i(55, 32), "terrain": "highland"},
		{"tile": Vector2i(57, 32), "terrain": "grass"},
	]
	for entry in fixture_plan:
		var tile: Vector2i = entry.get("tile", Vector2i.ZERO)
		if not _paint_editor_terrain_for_orientation(shell, tile, String(entry.get("terrain", ""))):
			_restore_editor_terrain_tiles(shell, original_terrains)
			_fail("Map editor smoke: could not seed bridge material resolver fixture tile %s." % entry)
			return false
	var cases := [
		{
			"tile": Vector2i(32, 32),
			"source": "badlands",
			"kind": "direct_bridge_material",
			"rule": "full_receiver_direct_dirt_contact",
			"class": "dirt_earth_bridge",
			"family": "dirt",
			"block": "native_to_dirt_transition",
			"source_level": "fact",
			"model": "direct_bridge_material_contact_lookup",
			"stamp": {"table": "full_receiver_native_to_dirt_5x4_provisional_stamp_table", "direction": "E", "frame": "00_15", "offset": {"x": 1, "y": 0}, "bridge_family": "dirt", "target_block": "native_to_dirt_transition", "source_kind": "cardinal_source"},
		},
		{
			"tile": Vector2i(36, 32),
			"source": "wastes",
			"kind": "direct_bridge_material",
			"rule": "dirt_receiver_direct_sand_contact",
			"class": "sand_bridge",
			"family": "sand",
			"block": "dirt_to_sand_transition",
			"source_level": "fact",
			"model": "direct_dirt_sand_receiver_lookup",
		},
		{
			"tile": Vector2i(40, 32),
			"source": "swamp",
			"kind": "routed_bridge",
			"rule": "grass_swamp_via_dirt_bridge",
			"class": "dirt_earth_bridge",
			"family": "dirt",
			"block": "native_to_dirt_transition",
			"source_level": "inference",
			"model": "grass_swamp_via_dirt_bridge",
			"stamp": {"table": "full_receiver_native_to_dirt_5x4_provisional_stamp_table", "direction": "E", "frame": "00_15", "offset": {"x": 1, "y": 0}, "bridge_family": "dirt", "target_block": "native_to_dirt_transition", "source_kind": "cardinal_source"},
		},
		{
			"tile": Vector2i(44, 32),
			"source": "snow",
			"kind": "preferred_bridge_class",
			"rule": "full_receiver_prefers_dirt_bridge_class",
			"class": "dirt_earth_bridge",
			"family": "dirt",
			"block": "native_to_dirt_transition",
			"source_level": "editor_observation",
			"model": "receiver_preferred_bridge_class_lookup",
			"stamp": {"table": "full_receiver_native_to_dirt_5x4_provisional_stamp_table", "direction": "E", "frame": "00_15", "offset": {"x": 1, "y": 0}, "bridge_family": "dirt", "target_block": "native_to_dirt_transition", "source_kind": "cardinal_source"},
		},
		{
			"tile": Vector2i(48, 32),
			"source": "grass",
			"kind": "unresolved_fallback",
			"rule": "subterranean_preferred_bridge_class_provisional",
			"class": "subterranean_preferred_class_unresolved",
			"family": "dirt",
			"block": "native_to_dirt_transition",
			"source_level": "provisional",
			"model": "provisional_subterranean_dirt_bridge_fallback",
			"provisional": true,
			"stamp": {"table": "full_receiver_native_to_dirt_5x4_provisional_stamp_table", "direction": "E", "frame": "00_15", "offset": {"x": 1, "y": 0}, "bridge_family": "dirt", "target_block": "native_to_dirt_transition", "source_kind": "cardinal_source", "mixed_reserved": true},
		},
		{
			"tile": Vector2i(52, 32),
			"source": "grass",
			"kind": "preferred_bridge_class",
			"rule": "water_prefers_sand_bridge_class",
			"class": "sand_bridge",
			"family": "sand",
			"block": "shoreline_frames",
			"source_level": "editor_observation",
			"model": "preferred_bridge_class_before_water_shoreline_lookup",
			"selection": "water_shoreline",
		},
		{
			"tile": Vector2i(56, 32),
			"source": "grass",
			"kind": "preferred_bridge_class",
			"rule": "rock_prefers_sand_bridge_class",
			"class": "sand_bridge",
			"family": "sand",
			"block": "rock_light_ground_context",
			"source_level": "editor_observation",
			"model": "preferred_bridge_class_before_rock_system_lookup",
			"selection": "rock_system",
		},
	]
	for case in cases:
		var tile: Vector2i = case.get("tile", Vector2i.ZERO)
		var presentation: Dictionary = shell.call("validation_tile_presentation", tile.x, tile.y)
		var terrain: Dictionary = presentation.get("terrain_presentation", {})
		if not _assert_bridge_resolver_case(terrain, case):
			_restore_editor_terrain_tiles(shell, original_terrains)
			_fail("Map editor smoke: bridge material resolver metadata did not match case %s: %s." % [case, presentation])
			return false
	_restore_editor_terrain_tiles(shell, original_terrains)
	return true

func _assert_editor_solid_region_interior_stability(shell) -> bool:
	return (
		_assert_editor_solid_region_for_receiver(shell, Vector2i(52, 52), "grass")
		and _assert_editor_solid_region_for_receiver(shell, Vector2i(52, 43), "snow")
	)

func _assert_editor_solid_region_for_receiver(shell, center: Vector2i, receiver_terrain: String) -> bool:
	var original_terrains := []
	var controlled_tiles := []
	for y in range(center.y - 4, center.y + 5):
		for x in range(center.x - 4, center.x + 5):
			controlled_tiles.append(Vector2i(x, y))
	for tile in controlled_tiles:
		var presentation: Dictionary = shell.call("validation_tile_presentation", tile.x, tile.y)
		original_terrains.append({
			"tile": tile,
			"terrain": String(presentation.get("terrain_presentation", {}).get("terrain", "grass")),
		})
		if not _paint_editor_terrain_for_orientation(shell, tile, "badlands"):
			_restore_editor_terrain_tiles(shell, original_terrains)
			_fail("Map editor smoke: could not seed dirt around %s region at %s." % [receiver_terrain, tile])
			return false
	for y in range(center.y - 2, center.y + 3):
		for x in range(center.x - 2, center.x + 3):
			var tile := Vector2i(x, y)
			if not _paint_editor_terrain_for_orientation(shell, tile, receiver_terrain):
				_restore_editor_terrain_tiles(shell, original_terrains)
				_fail("Map editor smoke: could not seed %s block tile at %s." % [receiver_terrain, tile])
				return false

	var north_edge := center + Vector2i(0, -2)
	var edge_presentation: Dictionary = shell.call("validation_tile_presentation", north_edge.x, north_edge.y)
	var edge_terrain: Dictionary = edge_presentation.get("terrain_presentation", {})
	if (
		String(edge_terrain.get("terrain", "")) != receiver_terrain
		or String(edge_terrain.get("homm3_selection_kind", "")) != "bridge_transition"
		or String(edge_terrain.get("transition_edge_mask", "")) != "N"
		or String(edge_terrain.get("homm3_bridge_family", "")) != "dirt"
		or String(edge_terrain.get("homm3_selected_frame_block", "")) != "native_to_dirt_transition"
		or int(edge_terrain.get("edge_transition_count", 0)) != 1
		or int(edge_terrain.get("propagated_transition_count", -1)) != 0
		or "badlands" not in edge_terrain.get("transition_source_terrain_ids", [])
	):
		_restore_editor_terrain_tiles(shell, original_terrains)
		_fail("Map editor smoke: %s block outer edge did not keep the dirt transition frame: %s." % [receiver_terrain, edge_presentation])
		return false
	if not _assert_full_receiver_stamp_payload(edge_terrain, {
		"table": "full_receiver_native_to_dirt_5x4_provisional_stamp_table",
		"direction": "N",
		"frame": "00_08",
		"offset": {"x": 0, "y": -1},
		"bridge_family": "dirt",
		"target_block": "native_to_dirt_transition",
		"source_kind": "cardinal_source",
		"mixed_reserved": true,
	}):
		_restore_editor_terrain_tiles(shell, original_terrains)
		_fail("Map editor smoke: %s block outer edge did not expose source-anchored dirt stamp metadata: %s." % [receiver_terrain, edge_presentation])
		return false

	for interior_tile in [center, center + Vector2i(-1, -1), center + Vector2i(1, 1)]:
		var interior_presentation: Dictionary = shell.call("validation_tile_presentation", interior_tile.x, interior_tile.y)
		var interior_terrain: Dictionary = interior_presentation.get("terrain_presentation", {})
		if not _assert_solid_region_interior_payload(interior_terrain, receiver_terrain):
			_restore_editor_terrain_tiles(shell, original_terrains)
			_fail("Map editor smoke: %s block interior selected a dirt/sand transition stamp at %s: %s." % [receiver_terrain, interior_tile, interior_presentation])
			return false

	_restore_editor_terrain_tiles(shell, original_terrains)
	return true

func _assert_solid_region_interior_payload(terrain: Dictionary, expected_terrain: String) -> bool:
	if String(terrain.get("terrain", "")) != expected_terrain:
		return false
	if String(terrain.get("homm3_selection_kind", "")) != "interior":
		return false
	if bool(terrain.get("homm3_propagated_transition", false)):
		return false
	if String(terrain.get("homm3_selected_frame_block", "")) != "native_interiors":
		return false
	if String(terrain.get("homm3_stamp_table_id", "")) != "":
		return false
	if String(terrain.get("transition_edge_mask", "")) != "" or String(terrain.get("transition_corner_mask", "")) != "":
		return false
	if int(terrain.get("edge_transition_count", -1)) != 0 or int(terrain.get("corner_transition_count", -1)) != 0 or int(terrain.get("propagated_transition_count", -1)) != 0:
		return false
	if "badlands" in terrain.get("transition_source_terrain_ids", []) or "wastes" in terrain.get("transition_source_terrain_ids", []):
		return false
	return true

func _assert_editor_true_terrain_placement(shell) -> bool:
	var center := Vector2i(34, 50)
	var original_terrains := []
	var controlled_tiles := []
	for y in range(center.y - 3, center.y + 4):
		for x in range(center.x - 3, center.x + 4):
			controlled_tiles.append(Vector2i(x, y))
	for tile in controlled_tiles:
		var presentation: Dictionary = shell.call("validation_tile_presentation", tile.x, tile.y)
		original_terrains.append({
			"tile": tile,
			"terrain": String(presentation.get("terrain_presentation", {}).get("terrain", "grass")),
		})
		if not _paint_editor_terrain_for_orientation(shell, tile, "grass"):
			_restore_editor_terrain_tiles(shell, original_terrains)
			_fail("Map editor smoke: could not seed grass for true terrain placement test at %s." % tile)
			return false

	var paint_result: Dictionary = shell.call("validation_paint_terrain", center.x, center.y, "wastes")
	if not bool(paint_result.get("ok", false)) or not bool(paint_result.get("paint_changed", false)):
		_restore_editor_terrain_tiles(shell, original_terrains)
		_fail("Map editor smoke: true terrain placement paint did not report a changed operation: %s." % paint_result)
		return false
	if not _assert_true_terrain_placement_result(paint_result, "wastes"):
		_restore_editor_terrain_tiles(shell, original_terrains)
		_fail("Map editor smoke: true terrain placement did not expose queue rewrite and final normalization: %s." % paint_result)
		return false
	var owner_changed_tiles: Array = paint_result.get("owner_changed_tiles", [])
	var found_rewritten_neighbor := false
	for tile_value in owner_changed_tiles:
		if not (tile_value is Dictionary):
			continue
		var tile := Vector2i(int(tile_value.get("x", -1)), int(tile_value.get("y", -1)))
		if tile == center:
			continue
		if abs(tile.x - center.x) + abs(tile.y - center.y) == 1:
			var presentation: Dictionary = shell.call("validation_tile_presentation", tile.x, tile.y)
			if String(presentation.get("terrain_presentation", {}).get("terrain", "")) == "wastes":
				found_rewritten_neighbor = true
				break
	if not found_rewritten_neighbor:
		_restore_editor_terrain_tiles(shell, original_terrains)
		_fail("Map editor smoke: HoMM3 owner queue did not rewrite a cardinal neighbor for an isolated sand paint: %s." % paint_result)
		return false

	_restore_editor_terrain_tiles(shell, original_terrains)
	return true

func _assert_true_terrain_placement_result(result: Dictionary, expected_terrain_id: String) -> bool:
	var placement: Dictionary = result.get("terrain_placement", {})
	if placement.is_empty():
		return false
	if String(placement.get("placement_model", "")) != "homm3_owner_queue_rewrite_final_normalization.v1":
		return false
	if String(placement.get("queue_model", "")) != "rewrite_to_current_brush_4bb74b_then_drain_queues_4bc5f0":
		return false
	if String(placement.get("final_normalization_model", "")) != "final_normalization_4bbfcc_reclassifies_settled_owner_map":
		return false
	if String(placement.get("brush_terrain_id", "")) != expected_terrain_id:
		return false
	if int(placement.get("owner_changed_count", 0)) <= 1:
		return false
	if int(placement.get("changed_count", 0)) < int(placement.get("owner_changed_count", 0)):
		return false
	if bool(placement.get("queue_guard_exhausted", true)):
		return false
	var final_normalization: Dictionary = placement.get("final_normalization", {})
	if String(final_normalization.get("model", "")) != "final_normalization_4bbfcc_reclassifies_settled_owner_map":
		return false
	if String(final_normalization.get("owner_map_source", "")) != "settled_after_4bc5f0_queue_drain":
		return false
	if String(final_normalization.get("stale_transition_clear_model", "")) != "zero_boundary_cells_use_pick_full_branch_and_clear_flags":
		return false
	if int(final_normalization.get("visited_count", 0)) <= 0:
		return false
	if int(final_normalization.get("missing_bucket_count", 0)) != 0:
		return false
	return true

func _assert_editor_placement_source_lower_edge(shell) -> bool:
	var center := Vector2i(42, 50)
	var original_terrains := []
	var controlled_tiles := []
	for y in range(center.y - 3, center.y + 4):
		for x in range(center.x - 3, center.x + 4):
			controlled_tiles.append(Vector2i(x, y))
	for tile in controlled_tiles:
		var presentation: Dictionary = shell.call("validation_tile_presentation", tile.x, tile.y)
		original_terrains.append({
			"tile": tile,
			"terrain": String(presentation.get("terrain_presentation", {}).get("terrain", "grass")),
		})
		if not _paint_editor_terrain_for_orientation(shell, tile, "grass"):
			_restore_editor_terrain_tiles(shell, original_terrains)
			_fail("Map editor smoke: could not seed grass for lower-edge placement regression at %s." % tile)
			return false

	var cases := [
		{"terrain": "wastes", "family": "sand", "block": "sand_base_interiors"},
		{"terrain": "badlands", "family": "dirt", "block": "dirt_base_interiors"},
	]
	for case in cases:
		for tile in controlled_tiles:
			if not _paint_editor_terrain_for_orientation(shell, tile, "grass"):
				_restore_editor_terrain_tiles(shell, original_terrains)
				_fail("Map editor smoke: could not reset grass before lower-edge placement case %s at %s." % [case, tile])
				return false
		var terrain_id := String(case.get("terrain", ""))
		var paint_result: Dictionary = shell.call("validation_paint_terrain", center.x, center.y, terrain_id)
		if not bool(paint_result.get("ok", false)) or not bool(paint_result.get("paint_changed", false)):
			_restore_editor_terrain_tiles(shell, original_terrains)
			_fail("Map editor smoke: lower-edge placement regression paint did not change %s at %s: %s." % [terrain_id, center, paint_result])
			return false
		if not _assert_true_terrain_placement_result(paint_result, terrain_id):
			_restore_editor_terrain_tiles(shell, original_terrains)
			_fail("Map editor smoke: lower-edge placement regression did not use the HoMM3 owner queue for %s: %s." % [terrain_id, paint_result])
			return false
		for lower_tile in [center + Vector2i(-1, 0), center]:
			var lower_presentation: Dictionary = shell.call("validation_tile_presentation", lower_tile.x, lower_tile.y)
			var lower_terrain: Dictionary = lower_presentation.get("terrain_presentation", {})
			if (
				String(lower_terrain.get("terrain", "")) != terrain_id
				or String(lower_terrain.get("homm3_terrain_family", "")) != String(case.get("family", ""))
				or String(lower_terrain.get("homm3_selection_kind", "")) != "interior"
				or String(lower_terrain.get("homm3_selected_frame_block", "")) != String(case.get("block", ""))
				or String(lower_terrain.get("transition_edge_mask", "")) != ""
				or int(lower_terrain.get("edge_transition_count", -1)) != 0
				or not lower_terrain.get("transition_source_terrain_ids", []).is_empty()
			):
				_restore_editor_terrain_tiles(shell, original_terrains)
				_fail("Map editor smoke: lower source edge for %s resolved as a transition instead of an interior/base tile at %s: %s." % [terrain_id, lower_tile, lower_presentation])
				return false
		var grass_receiver_tile := center + Vector2i(0, -2)
		var receiver_presentation: Dictionary = shell.call("validation_tile_presentation", grass_receiver_tile.x, grass_receiver_tile.y)
		var receiver_terrain: Dictionary = receiver_presentation.get("terrain_presentation", {})
		if (
			String(receiver_terrain.get("terrain", "")) != "grass"
			or String(receiver_terrain.get("homm3_selection_kind", "")) != "bridge_transition"
			or terrain_id not in receiver_terrain.get("transition_source_terrain_ids", [])
		):
			_restore_editor_terrain_tiles(shell, original_terrains)
			_fail("Map editor smoke: full-receiver neighbor did not retain the terrain transition around lower-edge source tiles for %s: %s." % [terrain_id, receiver_presentation])
			return false

	_restore_editor_terrain_tiles(shell, original_terrains)
	return true

func _assert_editor_sand_heavy_corner_ownership(shell) -> bool:
	var center := Vector2i(30, 50)
	var original_terrains := []
	var controlled_tiles := []
	for y in range(center.y - 3, center.y + 4):
		for x in range(center.x - 3, center.x + 4):
			controlled_tiles.append(Vector2i(x, y))
	for tile in controlled_tiles:
		var presentation: Dictionary = shell.call("validation_tile_presentation", tile.x, tile.y)
		original_terrains.append({
			"tile": tile,
			"terrain": String(presentation.get("terrain_presentation", {}).get("terrain", "grass")),
		})
		if not _paint_editor_terrain_for_orientation(shell, tile, "grass"):
			_restore_editor_terrain_tiles(shell, original_terrains)
			_fail("Map editor smoke: could not seed grass for sand-heavy corner ownership regression at %s." % tile)
			return false

	var cases := [
		{"label": "NW", "sand_offsets": [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(-1, -1)], "edge": "NW", "corner": "NW", "mask": "N+W", "direction": "NW", "offset": {"x": -1, "y": -1}, "flip": "", "flip_h": false, "flip_v": false},
		{"label": "NE", "sand_offsets": [Vector2i(0, -1), Vector2i(1, 0), Vector2i(1, -1)], "edge": "NE", "corner": "NE", "mask": "N+E", "direction": "NE", "offset": {"x": 1, "y": -1}, "flip": "H", "flip_h": true, "flip_v": false},
		{"label": "SE", "sand_offsets": [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)], "edge": "ES", "corner": "SE", "mask": "E+S", "direction": "SE", "offset": {"x": 1, "y": 1}, "flip": "HV", "flip_h": true, "flip_v": true},
		{"label": "SW", "sand_offsets": [Vector2i(0, 1), Vector2i(-1, 0), Vector2i(-1, 1)], "edge": "SW", "corner": "SW", "mask": "S+W", "direction": "SW", "offset": {"x": -1, "y": 1}, "flip": "V", "flip_h": false, "flip_v": true},
	]
	for case in cases:
		for tile in controlled_tiles:
			if not _paint_editor_terrain_for_orientation(shell, tile, "grass"):
				_restore_editor_terrain_tiles(shell, original_terrains)
				_fail("Map editor smoke: could not reset grass before sand-heavy corner case %s at %s." % [case, tile])
				return false
		for offset_value in case.get("sand_offsets", []):
			var offset: Vector2i = offset_value
			var sand_tile: Vector2i = center + offset
			if not _paint_editor_terrain_for_orientation(shell, sand_tile, "wastes"):
				_restore_editor_terrain_tiles(shell, original_terrains)
				_fail("Map editor smoke: could not seed sand-heavy corner source for case %s at %s." % [case, sand_tile])
				return false
		var presentation: Dictionary = shell.call("validation_tile_presentation", center.x, center.y)
		var terrain: Dictionary = presentation.get("terrain_presentation", {})
		if (
			String(terrain.get("terrain", "")) != "grass"
			or String(terrain.get("homm3_selection_kind", "")) != "bridge_transition"
			or String(terrain.get("transition_edge_mask", "")) != String(case.get("edge", ""))
			or String(terrain.get("transition_corner_mask", "")) != String(case.get("corner", ""))
			or String(terrain.get("homm3_mask_key", "")) != String(case.get("mask", ""))
			or String(terrain.get("homm3_bridge_family", "")) != "sand"
			or int(terrain.get("edge_transition_count", 0)) != 2
			or int(terrain.get("corner_transition_count", 0)) != 1
			or bool(terrain.get("homm3_stamp_mixed_junction_reserved", false))
		):
			_restore_editor_terrain_tiles(shell, original_terrains)
			_fail("Map editor smoke: sand-heavy %s corner did not keep 1 grass / 3 sand ownership metadata: %s." % [String(case.get("label", "")), presentation])
			return false
		if not _assert_full_receiver_stamp_payload(terrain, {
			"table": "full_receiver_native_to_sand_5x4_provisional_stamp_table",
			"direction": String(case.get("direction", "")),
			"frame": "00_20",
			"offset": case.get("offset", {}),
			"bridge_family": "sand",
			"target_block": "native_to_sand_transition",
			"source_kind": "cardinal_corner_sources",
			"flip": String(case.get("flip", "")),
			"flip_h": bool(case.get("flip_h", false)),
			"flip_v": bool(case.get("flip_v", false)),
		}):
			_restore_editor_terrain_tiles(shell, original_terrains)
			_fail("Map editor smoke: sand-heavy %s corner selected a grass-heavy edge frame instead of the sand-heavy corner stamp: %s." % [String(case.get("label", "")), presentation])
			return false

	_restore_editor_terrain_tiles(shell, original_terrains)
	return true

func _assert_editor_restamp_behavior_model(shell) -> bool:
	var painted := Vector2i(30, 50)
	var original_terrains := []
	var controlled_tiles := []
	for y in range(painted.y - 2, painted.y + 3):
		for x in range(painted.x - 2, painted.x + 3):
			controlled_tiles.append(Vector2i(x, y))
	for tile in controlled_tiles:
		var presentation: Dictionary = shell.call("validation_tile_presentation", tile.x, tile.y)
		original_terrains.append({
			"tile": tile,
			"terrain": String(presentation.get("terrain_presentation", {}).get("terrain", "grass")),
		})
		if not _paint_editor_terrain_for_orientation(shell, tile, "grass"):
			_restore_editor_terrain_tiles(shell, original_terrains)
			_fail("Map editor smoke: could not seed grass for editor restamp behavior test at %s." % tile)
			return false

	var before_snapshot: Dictionary = shell.call("validation_snapshot")
	var before_order := int(before_snapshot.get("terrain_paint_order", 0))
	var sand_result: Dictionary = shell.call("validation_paint_terrain", painted.x, painted.y, "wastes")
	var sand_order := int(sand_result.get("terrain_paint_order", 0))
	if (
		not bool(sand_result.get("ok", false))
		or not bool(sand_result.get("paint_changed", false))
		or sand_order <= before_order
	):
		_restore_editor_terrain_tiles(shell, original_terrains)
		_fail("Map editor smoke: ordered sand paint did not expose a changed terrain paint operation: %s." % sand_result)
		return false
	if not _assert_true_terrain_placement_result(sand_result, "wastes"):
		_restore_editor_terrain_tiles(shell, original_terrains)
		_fail("Map editor smoke: sand paint did not use the HoMM3 owner queue and final-normalization path: %s." % sand_result)
		return false
	var sand_restamp: Dictionary = sand_result.get("editor_restamp", {})
	if not _assert_editor_restamp_contract(sand_restamp):
		_restore_editor_terrain_tiles(shell, original_terrains)
		_fail("Map editor smoke: sand paint did not expose the editor restamp behavior contract: %s." % sand_result)
		return false
	var sand_source := _restamp_tile_by_direction(sand_restamp, "SELF")
	var sand_source_terrain: Dictionary = sand_source.get("terrain_presentation", {})
	if (
		String(sand_source.get("role", "")) != "painted_source_tile"
		or int(sand_source.get("restamp_order_index", -1)) != 0
		or String(sand_source_terrain.get("terrain", "")) != "wastes"
		or String(sand_source_terrain.get("homm3_terrain_family", "")) != "sand"
		or String(sand_source_terrain.get("homm3_selection_kind", "")) != "interior"
		or String(sand_source_terrain.get("homm3_selected_frame_block", "")) != "sand_base_interiors"
		or String(sand_source_terrain.get("transition_edge_mask", "")) != ""
		or String(sand_source_terrain.get("homm3_editor_restamp_model", "")) != "source_paint_known_receiver_offsets_shared_overworld_reprojection.v1"
	):
		_restore_editor_terrain_tiles(shell, original_terrains)
		_fail("Map editor smoke: painted source tile did not report sand through the shared restamp payload: %s." % sand_source)
		return false

	var dirt_result: Dictionary = shell.call("validation_paint_terrain", painted.x, painted.y, "badlands")
	var dirt_order := int(dirt_result.get("terrain_paint_order", 0))
	if (
		not bool(dirt_result.get("ok", false))
		or not bool(dirt_result.get("paint_changed", false))
		or dirt_order <= sand_order
	):
		_restore_editor_terrain_tiles(shell, original_terrains)
		_fail("Map editor smoke: ordered dirt repaint did not advance the editor paint order: %s." % dirt_result)
		return false
	if not _assert_true_terrain_placement_result(dirt_result, "badlands"):
		_restore_editor_terrain_tiles(shell, original_terrains)
		_fail("Map editor smoke: dirt repaint did not use the HoMM3 owner queue and final-normalization path: %s." % dirt_result)
		return false
	var dirt_restamp: Dictionary = dirt_result.get("editor_restamp", {})
	if not _assert_editor_restamp_contract(dirt_restamp):
		_restore_editor_terrain_tiles(shell, original_terrains)
		_fail("Map editor smoke: dirt repaint did not keep the editor restamp contract: %s." % dirt_result)
		return false

	_restore_editor_terrain_tiles(shell, original_terrains)
	return true

func _assert_editor_restamp_contract(restamp: Dictionary) -> bool:
	if not bool(restamp.get("enabled", false)):
		return false
	if String(restamp.get("model", "")) != "source_paint_known_receiver_offsets_shared_overworld_reprojection.v1":
		return false
	if String(restamp.get("scope", "")) != "map_editor_terrain_paint_update_and_shared_preview":
		return false
	if String(restamp.get("logical_map_write_model", "")) != "homm3_owner_queue_rewrite_final_normalization.v1":
		return false
	if String(restamp.get("renderer_evaluation_model", "")) != "shared_overworld_map_view_final_state_reprojection":
		return false
	if String(restamp.get("known_receiver_offsets_source_level", "")) != "editor_observation":
		return false
	if String(restamp.get("paint_history_model", "")) != "array_reconstruction_fallback_without_paint_history":
		return false
	if int(restamp.get("known_receiver_count", 0)) != 3 or int(restamp.get("in_bounds_receiver_count", 0)) != 3 or int(restamp.get("affected_tile_count", 0)) != 4:
		return false
	if not bool(restamp.get("uses_shared_overworld_map_view", false)) or not bool(restamp.get("gameplay_pathing_unchanged", false)) or not bool(restamp.get("save_schema_unchanged", false)) or not bool(restamp.get("object_logic_unchanged", false)):
		return false
	if String(restamp.get("mixed_junction_policy", "")) != "reserved_unresolved_do_not_select_for_full_receiver_stamp_lookup":
		return false
	var reserved_ranges: Array = restamp.get("reserved_mixed_junction_frame_ranges", [])
	if "00_40-00_48" not in reserved_ranges or "00_77-00_78" not in reserved_ranges:
		return false
	var expected_directions := ["N", "NW", "W"]
	var offsets: Array = restamp.get("known_receiver_offsets", [])
	if offsets.size() != expected_directions.size():
		return false
	for index in range(expected_directions.size()):
		var offset: Dictionary = offsets[index]
		if String(offset.get("direction", "")) != String(expected_directions[index]):
			return false
	return true

func _restamp_tile_by_direction(restamp: Dictionary, direction: String) -> Dictionary:
	var affected_tiles: Array = restamp.get("affected_tiles", [])
	for value in affected_tiles:
		if not (value is Dictionary):
			continue
		var entry: Dictionary = value
		if String(entry.get("direction_from_painted_tile", "")) == direction:
			return entry
	return {}

func _assert_restamped_receiver_payload(entry: Dictionary, expected_order_index: int, expected_stamp: Dictionary) -> bool:
	if entry.is_empty():
		return false
	if int(entry.get("restamp_order_index", -1)) != expected_order_index:
		return false
	if not bool(entry.get("in_bounds", false)) or not bool(entry.get("stamp_source_matches_painted_tile", false)):
		return false
	var expected_offset: Dictionary = expected_stamp.get("offset", {})
	var source_offset: Dictionary = entry.get("expected_stamp_source_offset", {})
	if int(source_offset.get("x", 9999)) != int(expected_offset.get("x", 9998)):
		return false
	if int(source_offset.get("y", 9999)) != int(expected_offset.get("y", 9998)):
		return false
	var terrain: Dictionary = entry.get("terrain_presentation", {})
	return _assert_full_receiver_stamp_payload(terrain, expected_stamp)

func _assert_restamped_receiver_interior_payload(entry: Dictionary, expected_order_index: int, expected_terrain: String) -> bool:
	if entry.is_empty():
		return false
	if int(entry.get("restamp_order_index", -1)) != expected_order_index:
		return false
	if not bool(entry.get("in_bounds", false)):
		return false
	if bool(entry.get("stamp_source_matches_painted_tile", false)):
		return false
	var terrain: Dictionary = entry.get("terrain_presentation", {})
	return _assert_solid_region_interior_payload(terrain, expected_terrain)

func _paint_editor_terrain_for_orientation(shell, tile: Vector2i, terrain_id: String) -> bool:
	var result: Dictionary = shell.call("validation_seed_terrain_direct", tile.x, tile.y, terrain_id)
	if bool(result.get("ok", false)):
		return true
	var presentation: Dictionary = shell.call("validation_tile_presentation", tile.x, tile.y)
	return String(presentation.get("terrain_presentation", {}).get("terrain", "")) == terrain_id

func _restore_editor_terrain_tiles(shell, original_terrains: Array) -> void:
	for entry in original_terrains:
		if not (entry is Dictionary):
			continue
		var tile: Vector2i = entry.get("tile", Vector2i.ZERO)
		var terrain_id := String(entry.get("terrain", ""))
		if terrain_id != "":
			shell.call("validation_seed_terrain_direct", tile.x, tile.y, terrain_id)

func _string_array_matches(value, expected: Array) -> bool:
	if not (value is Array):
		return false
	var array: Array = value
	if array.size() != expected.size():
		return false
	for index in range(expected.size()):
		if String(array[index]) != String(expected[index]):
			return false
	return true

func _transition_sources_include(terrain: Dictionary, direction: String, source_terrain: String) -> bool:
	var sources: Array = terrain.get("transition_cardinal_sources", [])
	for source_value in sources:
		if not (source_value is Dictionary):
			continue
		var source: Dictionary = source_value
		if String(source.get("direction", "")) == direction and String(source.get("source_terrain", "")) == source_terrain:
			return true
	return false

func _transition_sources_include_bridge(terrain: Dictionary, direction: String, source_terrain: String, bridge_family: String, bridge_model: String) -> bool:
	var sources: Array = terrain.get("transition_cardinal_sources", [])
	for source_value in sources:
		if not (source_value is Dictionary):
			continue
		var source: Dictionary = source_value
		if (
			String(source.get("direction", "")) == direction
			and String(source.get("source_terrain", "")) == source_terrain
			and String(source.get("resolved_bridge_family", "")) == bridge_family
			and String(source.get("bridge_resolution_model", "")) == bridge_model
			and bool(source.get("uses_direct_bridge_pair", false))
		):
			return true
	return false

func _assert_full_receiver_stamp_payload(terrain: Dictionary, expected: Dictionary) -> bool:
	if not bool(terrain.get("homm3_uses_land_receiver_stamp_tables", false)):
		return false
	if bool(terrain.get("homm3_allows_generic_land_edge_masks", true)):
		return false
	if String(terrain.get("homm3_visual_selection_model", "")) != "accepted_web_prototype_relation_class_row_lookup.v1":
		return false
	if String(terrain.get("homm3_final_normalization_model", "")) != "final_normalization_4bbfcc_reclassifies_settled_owner_map":
		return false
	if String(terrain.get("homm3_stamp_selection_model", "")) != "":
		return false
	if String(terrain.get("homm3_stamp_selected_frame", "")) != "":
		return false
	if int(terrain.get("homm3_shape_class", 0)) <= 0:
		return false
	if String(terrain.get("homm3_relation_grid", "")) == "":
		return false
	if String(expected.get("bridge_family", "")) != "" and String(terrain.get("homm3_bridge_family", "")) != String(expected.get("bridge_family", "")):
		return false
	if String(expected.get("target_block", "")) != "" and String(terrain.get("homm3_selected_frame_block", "")) != String(expected.get("target_block", "")):
		return false
	if expected.has("shape_class") and int(terrain.get("homm3_shape_class", 0)) != int(expected.get("shape_class", -1)):
		return false
	if expected.has("row_group") and String(terrain.get("homm3_row_group", "")) != String(expected.get("row_group", "")):
		return false
	if expected.has("frame") and expected.has("shape_class") and String(terrain.get("homm3_terrain_frame", "")) != String(expected.get("frame", "")):
		return false
	var expected_flip := String(expected.get("flip", String(terrain.get("homm3_terrain_flip", ""))))
	if String(terrain.get("homm3_terrain_flip", "")) != expected_flip:
		return false
	if expected.has("flip_h") and bool(terrain.get("homm3_terrain_flip_h", false)) != bool(expected.get("flip_h", false)):
		return false
	if expected.has("flip_v") and bool(terrain.get("homm3_terrain_flip_v", false)) != bool(expected.get("flip_v", false)):
		return false
	if String(terrain.get("homm3_web_prototype_selection_model", "")) != String(terrain.get("homm3_visual_selection_model", "")):
		return false
	return true

func _assert_bridge_resolver_case(terrain: Dictionary, expected: Dictionary) -> bool:
	var expected_selection := String(expected.get("selection", "bridge_transition"))
	if expected.has("selection") and String(terrain.get("homm3_selection_kind", "")) != expected_selection:
		return false
	if String(terrain.get("homm3_visual_selection_model", "")) != "accepted_web_prototype_relation_class_row_lookup.v1":
		return false
	if String(terrain.get("homm3_bridge_resolver_model", "")) != "accepted_web_prototype_relation_class_row_lookup.v1":
		return false
	var stamp_expected = expected.get("stamp", {})
	if stamp_expected is Dictionary and not stamp_expected.is_empty():
		if not _assert_full_receiver_stamp_payload(terrain, stamp_expected):
			return false
	var sources: Array = terrain.get("transition_cardinal_sources", [])
	var expected_source := String(expected.get("source", ""))
	var found_source := false
	for source_value in sources:
		if not (source_value is Dictionary):
			continue
		var source: Dictionary = source_value
		if (
			String(source.get("source_terrain", "")) == expected_source
			and String(source.get("bridge_source_kind", "")) == String(expected.get("kind", ""))
			and String(source.get("bridge_rule_id", "")) == String(expected.get("rule", ""))
			and String(source.get("bridge_class", "")) == String(expected.get("class", ""))
			and String(source.get("resolved_bridge_family", "")) == String(expected.get("family", ""))
			and String(source.get("bridge_source_level", "")) == String(expected.get("source_level", ""))
			and String(source.get("bridge_resolution_model", "")) == String(expected.get("model", ""))
		):
			found_source = true
			break
	return found_source

func _assert_flood_fill_terrain(shell) -> bool:
	if not shell.has_method("validation_fill_terrain"):
		_fail("Map editor smoke: shell did not expose terrain flood-fill validation.")
		return false

	var region_tiles := [Vector2i(12, 12), Vector2i(13, 12), Vector2i(12, 13)]
	for tile in region_tiles:
		if not _paint_editor_terrain_for_orientation(shell, tile, "mire"):
			_fail("Map editor smoke: could not seed flood-fill terrain at %s." % tile)
			return false
	if not _paint_editor_terrain_for_orientation(shell, Vector2i(13, 13), "grass"):
		_fail("Map editor smoke: could not seed flood-fill boundary terrain.")
		return false

	var fill_result: Dictionary = shell.call("validation_fill_terrain", 12, 12, "lava")
	if (
		not bool(fill_result.get("ok", false))
		or not bool(fill_result.get("changed", false))
		or int(fill_result.get("filled_count", 0)) != 3
		or int(fill_result.get("affected_count", 0)) < 3
		or String(fill_result.get("source_terrain_id", "")) != "mire"
		or String(fill_result.get("active_terrain_id", "")) != "lava"
		or String(fill_result.get("fill_result", {}).get("contiguity", "")) != "cardinal"
	):
		_fail("Map editor smoke: terrain flood fill did not report the expected bounded region: %s." % fill_result)
		return false
	if not _assert_true_terrain_placement_result(fill_result, "lava"):
		_fail("Map editor smoke: terrain flood fill did not route through HoMM3 placement: %s." % fill_result)
		return false
	for tile in region_tiles:
		var presentation: Dictionary = shell.call("validation_tile_presentation", tile.x, tile.y)
		if String(presentation.get("terrain_presentation", {}).get("terrain", "")) != "lava":
			_fail("Map editor smoke: terrain flood fill did not update expected tile %s: %s." % [tile, presentation])
			return false
	var noop_result: Dictionary = shell.call("validation_fill_terrain", 12, 12, "lava")
	if not bool(noop_result.get("ok", false)) or bool(noop_result.get("changed", true)) or int(noop_result.get("filled_count", -1)) != 0:
		_fail("Map editor smoke: terrain flood fill did not no-op cleanly on matching active terrain: %s." % noop_result)
		return false
	return true

func _assert_terrain_line_tool(shell) -> bool:
	if not shell.has_method("validation_set_terrain_line_start") or not shell.has_method("validation_apply_terrain_line"):
		_fail("Map editor smoke: shell did not expose terrain line validation.")
		return false
	var expected_tiles := [
		Vector2i(16, 16),
		Vector2i(17, 16),
		Vector2i(18, 16),
		Vector2i(19, 16),
		Vector2i(19, 17),
		Vector2i(19, 18),
	]
	var off_line_tiles := [Vector2i(18, 17), Vector2i(16, 17)]
	var seeded_tiles := []
	seeded_tiles.append_array(expected_tiles)
	seeded_tiles.append_array(off_line_tiles)
	for tile in seeded_tiles:
		if not _paint_editor_terrain_for_orientation(shell, tile, "grass"):
			_fail("Map editor smoke: could not seed terrain-line tile %s." % tile)
			return false

	var start_result: Dictionary = shell.call("validation_set_terrain_line_start", 16, 16, "highland")
	var pending_start: Dictionary = start_result.get("pending_terrain_line_start", {})
	if (
		not bool(start_result.get("ok", false))
		or int(pending_start.get("x", -1)) != 16
		or int(pending_start.get("y", -1)) != 16
		or String(start_result.get("selected_terrain_id", "")) != "highland"
		or String(start_result.get("selected_terrain_label", "")) != "Rock/None"
		or String(start_result.get("path_rule", "")) != "manhattan_l_horizontal_then_vertical"
	):
		_fail("Map editor smoke: terrain line start did not expose the pending Manhattan L rule state: %s." % start_result)
		return false

	var line_result: Dictionary = shell.call("validation_apply_terrain_line", 19, 18)
	var pending_after_line: Dictionary = line_result.get("pending_terrain_line_start", {})
	if (
		not bool(line_result.get("ok", false))
		or not bool(line_result.get("changed", false))
		or String(line_result.get("active_terrain_id", "")) != "highland"
		or String(line_result.get("path_rule", "")) != "manhattan_l_horizontal_then_vertical"
		or int(line_result.get("path_count", 0)) != expected_tiles.size()
		or int(line_result.get("affected_count", 0)) < expected_tiles.size()
		or not _path_payload_matches(line_result.get("path_tiles", []), expected_tiles)
		or not pending_after_line.is_empty()
	):
		_fail("Map editor smoke: terrain line paint did not report the expected horizontal-first Manhattan L line: %s." % line_result)
		return false
	if not _assert_true_terrain_placement_result(line_result, "highland"):
		_fail("Map editor smoke: terrain line did not route through HoMM3 placement: %s." % line_result)
		return false
	for tile in expected_tiles:
		var presentation: Dictionary = shell.call("validation_tile_presentation", tile.x, tile.y)
		if String(presentation.get("terrain_presentation", {}).get("terrain", "")) != "highland":
			_fail("Map editor smoke: terrain line did not update expected tile %s: %s." % [tile, presentation])
			return false

	var repeat_start: Dictionary = shell.call("validation_set_terrain_line_start", 16, 16)
	if not bool(repeat_start.get("ok", false)):
		_fail("Map editor smoke: could not set terrain line start before no-op repeat: %s." % repeat_start)
		return false
	var repeat_result: Dictionary = shell.call("validation_apply_terrain_line", 19, 18)
	if (
		not bool(repeat_result.get("ok", false))
		or bool(repeat_result.get("changed", true))
		or int(repeat_result.get("affected_count", -1)) != 0
		or int(repeat_result.get("path_count", 0)) != expected_tiles.size()
		or not _path_payload_matches(repeat_result.get("path_tiles", []), expected_tiles)
	):
		_fail("Map editor smoke: terrain line repeat did not no-op cleanly on matching active terrain: %s." % repeat_result)
		return false
	return true

func _assert_terrain_rectangle_tool(shell) -> bool:
	if not shell.has_method("validation_set_terrain_rectangle_corner") or not shell.has_method("validation_apply_terrain_rectangle"):
		_fail("Map editor smoke: shell did not expose terrain rectangle validation.")
		return false
	var expected_tiles := [
		Vector2i(20, 16),
		Vector2i(21, 16),
		Vector2i(22, 16),
		Vector2i(20, 17),
		Vector2i(21, 17),
		Vector2i(22, 17),
		Vector2i(20, 18),
		Vector2i(21, 18),
		Vector2i(22, 18),
	]
	var outside_tiles := [Vector2i(19, 16), Vector2i(23, 17), Vector2i(21, 19)]
	var seeded_tiles := []
	seeded_tiles.append_array(expected_tiles)
	seeded_tiles.append_array(outside_tiles)
	for tile in seeded_tiles:
		if not _paint_editor_terrain_for_orientation(shell, tile, "grass"):
			_fail("Map editor smoke: could not seed terrain-rectangle tile %s." % tile)
			return false

	var start_result: Dictionary = shell.call("validation_set_terrain_rectangle_corner", 22, 18, "snow")
	var pending_corner: Dictionary = start_result.get("pending_terrain_rectangle_corner", {})
	if (
		not bool(start_result.get("ok", false))
		or int(pending_corner.get("x", -1)) != 22
		or int(pending_corner.get("y", -1)) != 18
		or String(start_result.get("selected_terrain_id", "")) != "snow"
		or String(start_result.get("selected_terrain_label", "")) != "Snow"
		or String(start_result.get("rectangle_rule", "")) != "inclusive_axis_aligned_corners"
		or String(start_result.get("tile_order", "")) != "row_major_top_left_to_bottom_right"
	):
		_fail("Map editor smoke: terrain rectangle start did not expose the pending rectangle rule state: %s." % start_result)
		return false

	var rect_result: Dictionary = shell.call("validation_apply_terrain_rectangle", 20, 16)
	var pending_after_rect: Dictionary = rect_result.get("pending_terrain_rectangle_corner", {})
	var bounds: Dictionary = rect_result.get("bounds", {})
	if (
		not bool(rect_result.get("ok", false))
		or not bool(rect_result.get("changed", false))
		or String(rect_result.get("active_terrain_id", "")) != "snow"
		or String(rect_result.get("rectangle_rule", "")) != "inclusive_axis_aligned_corners"
		or String(rect_result.get("tile_order", "")) != "row_major_top_left_to_bottom_right"
		or int(rect_result.get("rectangle_count", 0)) != expected_tiles.size()
		or int(rect_result.get("affected_count", 0)) < expected_tiles.size()
		or int(bounds.get("min_x", -1)) != 20
		or int(bounds.get("min_y", -1)) != 16
		or int(bounds.get("max_x", -1)) != 22
		or int(bounds.get("max_y", -1)) != 18
		or not _path_payload_matches(rect_result.get("rectangle_tiles", []), expected_tiles)
		or not pending_after_rect.is_empty()
	):
		_fail("Map editor smoke: terrain rectangle paint did not report the expected inclusive area: %s." % rect_result)
		return false
	if not _assert_true_terrain_placement_result(rect_result, "snow"):
		_fail("Map editor smoke: terrain rectangle did not route through HoMM3 placement: %s." % rect_result)
		return false
	for tile in expected_tiles:
		var presentation: Dictionary = shell.call("validation_tile_presentation", tile.x, tile.y)
		if String(presentation.get("terrain_presentation", {}).get("terrain", "")) != "snow":
			_fail("Map editor smoke: terrain rectangle did not update expected tile %s: %s." % [tile, presentation])
			return false

	var repeat_start: Dictionary = shell.call("validation_set_terrain_rectangle_corner", 22, 18)
	if not bool(repeat_start.get("ok", false)):
		_fail("Map editor smoke: could not set terrain rectangle corner before no-op repeat: %s." % repeat_start)
		return false
	var repeat_result: Dictionary = shell.call("validation_apply_terrain_rectangle", 20, 16)
	if (
		not bool(repeat_result.get("ok", false))
		or bool(repeat_result.get("changed", true))
		or int(repeat_result.get("affected_count", -1)) != 0
		or int(repeat_result.get("rectangle_count", 0)) != expected_tiles.size()
		or not _path_payload_matches(repeat_result.get("rectangle_tiles", []), expected_tiles)
	):
		_fail("Map editor smoke: terrain rectangle repeat did not no-op cleanly on matching active terrain: %s." % repeat_result)
		return false
	return true

func _assert_road_path_tool(shell) -> bool:
	if not shell.has_method("validation_set_road_path_start") or not shell.has_method("validation_apply_road_path"):
		_fail("Map editor smoke: shell did not expose road path validation.")
		return false
	var expected_tiles := [
		Vector2i(8, 8),
		Vector2i(9, 8),
		Vector2i(10, 8),
		Vector2i(11, 8),
		Vector2i(11, 9),
		Vector2i(11, 10),
	]
	for tile in expected_tiles:
		var preflight: Dictionary = shell.call("validation_select_tile", tile.x, tile.y)
		if bool(preflight.get("tile_inspection", {}).get("road", false)):
			_fail("Map editor smoke: road path test expected a no-road seed tile at %s: %s." % [tile, preflight])
			return false
	var before_snapshot: Dictionary = shell.call("validation_snapshot")
	var before_count := int(before_snapshot.get("road_tile_count", 0))

	var start_result: Dictionary = shell.call("validation_set_road_path_start", 8, 8)
	var pending_start: Dictionary = start_result.get("pending_road_path_start", {})
	if (
		not bool(start_result.get("ok", false))
		or int(pending_start.get("x", -1)) != 8
		or int(pending_start.get("y", -1)) != 8
		or String(start_result.get("path_rule", "")) != "manhattan_l_horizontal_then_vertical"
	):
		_fail("Map editor smoke: road path start did not expose the pending Manhattan L rule state: %s." % start_result)
		return false

	var add_result: Dictionary = shell.call("validation_apply_road_path", 11, 10)
	if (
		not bool(add_result.get("ok", false))
		or not bool(add_result.get("changed", false))
		or String(add_result.get("road_path_action", "")) != "add"
		or String(add_result.get("path_rule", "")) != "manhattan_l_horizontal_then_vertical"
		or int(add_result.get("path_count", 0)) != expected_tiles.size()
		or int(add_result.get("affected_count", 0)) != expected_tiles.size()
		or int(add_result.get("road_tile_count", 0)) != before_count + expected_tiles.size()
		or not _path_payload_matches(add_result.get("path_tiles", []), expected_tiles)
	):
		_fail("Map editor smoke: road path add did not report the expected horizontal-first Manhattan L path: %s." % add_result)
		return false
	for tile in expected_tiles:
		var inspection_result: Dictionary = shell.call("validation_select_tile", tile.x, tile.y)
		var inspection: Dictionary = inspection_result.get("tile_inspection", {})
		if not bool(inspection.get("road", false)) or "editor_working_road" not in inspection.get("road_layers", []):
			_fail("Map editor smoke: road path add did not affect expected tile %s: %s." % [tile, inspection_result])
			return false
	var elbow_presentation: Dictionary = shell.call("validation_tile_presentation", 11, 8)
	var elbow_terrain: Dictionary = elbow_presentation.get("terrain_presentation", {})
	if not bool(elbow_terrain.get("road_overlay", false)) or String(elbow_terrain.get("road_overlay_id", "")) != "road_dirt":
		_fail("Map editor smoke: road path did not update the live preview road overlay: %s." % elbow_presentation)
		return false
	for outside_tile in [Vector2i(10, 9), Vector2i(8, 9)]:
		var outside: Dictionary = shell.call("validation_select_tile", outside_tile.x, outside_tile.y)
		if bool(outside.get("tile_inspection", {}).get("road", false)):
			_fail("Map editor smoke: road path leaked onto off-path tile %s: %s." % [outside_tile, outside])
			return false

	var remove_start: Dictionary = shell.call("validation_set_road_path_start", 8, 8)
	if not bool(remove_start.get("ok", false)):
		_fail("Map editor smoke: could not set road path start before remove toggle: %s." % remove_start)
		return false
	var remove_result: Dictionary = shell.call("validation_apply_road_path", 11, 10)
	if (
		not bool(remove_result.get("ok", false))
		or not bool(remove_result.get("changed", false))
		or String(remove_result.get("road_path_action", "")) != "remove"
		or int(remove_result.get("affected_count", 0)) != expected_tiles.size()
		or int(remove_result.get("road_tile_count", 0)) != before_count
		or not _path_payload_matches(remove_result.get("path_tiles", []), expected_tiles)
	):
		_fail("Map editor smoke: road path toggle did not remove the same Manhattan L path: %s." % remove_result)
		return false
	for tile in expected_tiles:
		var removed_tile: Dictionary = shell.call("validation_select_tile", tile.x, tile.y)
		if bool(removed_tile.get("tile_inspection", {}).get("road", true)):
			_fail("Map editor smoke: road path remove left a path tile with road state %s: %s." % [tile, removed_tile])
			return false
	return true

func _path_payload_matches(payload: Array, expected_tiles: Array) -> bool:
	if payload.size() != expected_tiles.size():
		return false
	for index in range(expected_tiles.size()):
		var expected: Vector2i = expected_tiles[index]
		var value = payload[index]
		if not (value is Dictionary):
			return false
		if int(value.get("x", -999)) != expected.x or int(value.get("y", -999)) != expected.y:
			return false
	return true

func _assert_selected_tile_restore(shell) -> bool:
	if not shell.has_method("validation_restore_selected_tile"):
		_fail("Map editor smoke: shell did not expose selected-tile restore validation.")
		return false

	var edited_empty_tile: Dictionary = shell.call("validation_paint_terrain", 6, 6, "grass")
	if not bool(edited_empty_tile.get("ok", false)):
		_fail("Map editor smoke: could not edit the empty restore seed tile: %s." % edited_empty_tile)
		return false
	var added_empty_road: Dictionary = shell.call("validation_toggle_road", 6, 6)
	if not bool(added_empty_road.get("ok", false)):
		_fail("Map editor smoke: could not add a working-copy road before restore: %s." % added_empty_road)
		return false
	var placed_empty_object: Dictionary = shell.call("validation_place_object", 6, 6, "encounter", "encounter_mire_raid")
	if not bool(placed_empty_object.get("ok", false)):
		_fail("Map editor smoke: could not place a working-copy-only object before restore: %s." % placed_empty_object)
		return false
	var empty_restore: Dictionary = shell.call("validation_restore_selected_tile", 6, 6)
	var empty_inspection: Dictionary = empty_restore.get("tile_inspection", {})
	if (
		not bool(empty_restore.get("ok", false))
		or String(empty_inspection.get("terrain_id", "")) != "frost"
		or bool(empty_inspection.get("road", true))
		or not _object_detail_for_family(empty_inspection, "encounter").is_empty()
	):
		_fail("Map editor smoke: restore did not return an empty tile to authored terrain/no-road/no-object state: %s." % empty_restore)
		return false

	var removed_authored_road: Dictionary = shell.call("validation_toggle_road", 23, 24)
	if not bool(removed_authored_road.get("ok", false)) or bool(removed_authored_road.get("tile_inspection", {}).get("road", true)):
		_fail("Map editor smoke: could not remove an authored road before restore: %s." % removed_authored_road)
		return false
	var road_restore: Dictionary = shell.call("validation_restore_selected_tile", 23, 24)
	var road_inspection: Dictionary = road_restore.get("tile_inspection", {})
	var restored_road_layers: Array = road_inspection.get("road_layers", [])
	if (
		not bool(road_restore.get("ok", false))
		or not bool(road_inspection.get("road", false))
		or "ninefold_central_survey_road" not in restored_road_layers
	):
		_fail("Map editor smoke: restore did not return authored road presence on the selected tile: %s." % road_restore)
		return false

	var authored_hero_restore: Dictionary = shell.call("validation_restore_selected_tile", 23, 26)
	var authored_hero_position: Dictionary = authored_hero_restore.get("hero_position", {})
	if int(authored_hero_position.get("x", -1)) != 23 or int(authored_hero_position.get("y", -1)) != 26:
		_fail("Map editor smoke: restore on the authored hero-start tile did not return the hero start: %s." % authored_hero_restore)
		return false
	var moved_again: Dictionary = shell.call("validation_set_hero_start", 3, 3)
	if not bool(moved_again.get("ok", false)):
		_fail("Map editor smoke: could not move the hero again for moved-start restore coverage: %s." % moved_again)
		return false
	var moved_hero_restore: Dictionary = shell.call("validation_restore_selected_tile", 3, 3)
	var moved_hero_position: Dictionary = moved_hero_restore.get("hero_position", {})
	if int(moved_hero_position.get("x", -1)) != 23 or int(moved_hero_position.get("y", -1)) != 26:
		_fail("Map editor smoke: restore on the moved hero-start tile did not return to authored start: %s." % moved_hero_restore)
		return false
	var play_copy_hero_seed: Dictionary = shell.call("validation_set_hero_start", 3, 3)
	if not bool(play_copy_hero_seed.get("ok", false)):
		_fail("Map editor smoke: could not restore the edited hero start expected by Play Copy: %s." % play_copy_hero_seed)
		return false

	var town_owner_edit: Dictionary = shell.call("validation_edit_object_property", 30, 26, "town", "owner", "neutral")
	if not bool(town_owner_edit.get("ok", false)):
		_fail("Map editor smoke: could not edit secondary town before restore: %s." % town_owner_edit)
		return false
	var town_retheme: Dictionary = shell.call("validation_retheme_object", 30, 26, "town", "town_riverwatch")
	if not bool(town_retheme.get("ok", false)):
		_fail("Map editor smoke: could not retheme secondary town before restore: %s." % town_retheme)
		return false
	var town_restore: Dictionary = shell.call("validation_restore_selected_tile", 30, 26)
	var restored_town := _object_detail_for_family(town_restore.get("tile_inspection", {}), "town")
	if (
		String(restored_town.get("placement_id", "")) != "ninefold_duskfen_gate"
		or String(restored_town.get("content_id", "")) != "town_duskfen"
		or String(restored_town.get("owner", "")) != "enemy"
	):
		_fail("Map editor smoke: restore did not return the authored town placement state: %s." % town_restore)
		return false

	var resource_move: Dictionary = shell.call("validation_move_object", 23, 8, 24, 8, "resource")
	if not bool(resource_move.get("ok", false)):
		_fail("Map editor smoke: could not move authored resource before restore: %s." % resource_move)
		return false
	var source_blocker: Dictionary = shell.call("validation_place_object", 23, 8, "resource", "site_timber_wagon")
	if not bool(source_blocker.get("ok", false)):
		_fail("Map editor smoke: could not place a source-tile blocker before restore: %s." % source_blocker)
		return false
	var resource_restore: Dictionary = shell.call("validation_restore_selected_tile", 23, 8)
	var restored_resource := _object_detail_for_family(resource_restore.get("tile_inspection", {}), "resource")
	if (
		String(restored_resource.get("placement_id", "")) != "dwelling_roadward_lodge"
		or String(restored_resource.get("content_id", "")) != "site_free_company_yard"
		or bool(restored_resource.get("collected", true))
	):
		_fail("Map editor smoke: restore did not return the moved authored resource and clear source edits: %s." % resource_restore)
		return false
	var moved_resource_tile: Dictionary = shell.call("validation_select_tile", 24, 8)
	if not _object_detail_for_family(moved_resource_tile.get("tile_inspection", {}), "resource").is_empty():
		_fail("Map editor smoke: restore left the moved authored resource behind on its working-copy destination: %s." % moved_resource_tile)
		return false

	var artifact_edit: Dictionary = shell.call("validation_edit_object_property", 23, 5, "artifact", "collected", true)
	if not bool(artifact_edit.get("ok", false)):
		_fail("Map editor smoke: could not edit artifact before restore: %s." % artifact_edit)
		return false
	var artifact_retheme: Dictionary = shell.call("validation_retheme_object", 23, 5, "artifact", "artifact_bastion_gorget")
	if not bool(artifact_retheme.get("ok", false)):
		_fail("Map editor smoke: could not retheme artifact before restore: %s." % artifact_retheme)
		return false
	var artifact_restore: Dictionary = shell.call("validation_restore_selected_tile", 23, 5)
	var restored_artifact := _object_detail_for_family(artifact_restore.get("tile_inspection", {}), "artifact")
	if (
		String(restored_artifact.get("placement_id", "")) != "confluence_trailsinger_boots"
		or String(restored_artifact.get("content_id", "")) != "artifact_trailsinger_boots"
		or bool(restored_artifact.get("collected", true))
	):
		_fail("Map editor smoke: restore did not return authored artifact state: %s." % artifact_restore)
		return false

	var encounter_edit: Dictionary = shell.call("validation_edit_object_property", 23, 38, "encounter", "difficulty", "low")
	if not bool(encounter_edit.get("ok", false)):
		_fail("Map editor smoke: could not edit encounter before restore: %s." % encounter_edit)
		return false
	var encounter_retheme: Dictionary = shell.call("validation_retheme_object", 23, 38, "encounter", "encounter_mire_raid")
	if not bool(encounter_retheme.get("ok", false)):
		_fail("Map editor smoke: could not retheme encounter before restore: %s." % encounter_retheme)
		return false
	var encounter_restore: Dictionary = shell.call("validation_restore_selected_tile", 23, 38)
	var restored_encounter := _object_detail_for_family(encounter_restore.get("tile_inspection", {}), "encounter")
	if (
		String(restored_encounter.get("placement_id", "")) != "ninefold_prism_matrix"
		or String(restored_encounter.get("content_id", "")) != "encounter_daybreak_matrix"
		or String(restored_encounter.get("difficulty", "")) != "high"
		or int(restored_encounter.get("combat_seed", 0)) != 16402
	):
		_fail("Map editor smoke: restore did not return authored encounter state: %s." % encounter_restore)
		return false

	var edited_terrain_check: Dictionary = shell.call("validation_tile_presentation", 2, 2)
	if String(edited_terrain_check.get("terrain_presentation", {}).get("terrain", "")) != "forest":
		_fail("Map editor smoke: selected-tile restore leaked into an unrelated painted tile: %s." % edited_terrain_check)
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
