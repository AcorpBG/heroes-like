extends Node

const OverworldMapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "RANDOM_MAP_GENERATED_VISUAL_PATH_REGRESSION_REPORT"
const MAP_WIDTH := 36
const MAP_HEIGHT := 36
const VIEW_SIZE := Vector2(1280, 720)

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not _assert_source_has_no_generated_fast_path():
		return
	var session := _generated_session()
	var view = OverworldMapViewScript.new()
	view.size = VIEW_SIZE
	add_child(view)
	await get_tree().process_frame

	var map_data: Array = session.overworld.get("map", [])
	view.set_map_state(session, map_data, Vector2i(MAP_WIDTH, MAP_HEIGHT), Vector2i(18, 18))
	await get_tree().process_frame

	var metrics: Dictionary = view.validation_view_metrics()
	var presentation: Dictionary = view.validation_tile_presentation(Vector2i(18, 18))
	if not _assert_normal_visual_path(metrics, presentation):
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"map_size": metrics.get("map_size", {}),
		"visual_render_path": String(metrics.get("visual_render_path", "")),
		"terrain_rendering_mode": String(presentation.get("terrain_presentation", {}).get("rendering_mode", "")),
		"art_presentation": presentation.get("art_presentation", {}),
	})])
	get_tree().quit(0)

func _assert_source_has_no_generated_fast_path() -> bool:
	var file := FileAccess.open("res://scenes/overworld/OverworldMapView.gd", FileAccess.READ)
	if file == null:
		_fail("Could not read OverworldMapView.gd for source-level visual-path guard.")
		return false
	var source := file.get_as_text()
	for forbidden in [
		"_generated_render_fast_path",
		"_draw_generated_fast_terrain_tile",
		"_draw_generated_fast_state_icon",
		"_draw_generated_fast_hero_marker",
	]:
		if source.find(forbidden) >= 0:
			_fail("Generated maps must not use the primitive fast-path/debug renderer token %s." % forbidden)
			return false
	return true

func _assert_normal_visual_path(metrics: Dictionary, presentation: Dictionary) -> bool:
	var map_size: Dictionary = metrics.get("map_size", {})
	if int(map_size.get("x", 0)) != MAP_WIDTH or int(map_size.get("y", 0)) != MAP_HEIGHT:
		_fail("Generated visual guard did not preserve true map size: %s" % JSON.stringify(map_size))
		return false
	if String(metrics.get("visual_render_path", "")) != "normal_overworld_art":
		_fail("Generated map did not report the normal overworld art path: %s" % JSON.stringify(metrics))
		return false
	if not bool(metrics.get("generated_maps_use_normal_art_path", false)):
		_fail("Generated map metrics did not affirm normal art path: %s" % JSON.stringify(metrics))
		return false
	if bool(metrics.get("primitive_generated_render_path", true)):
		_fail("Generated map metrics indicate primitive/debug render path: %s" % JSON.stringify(metrics))
		return false
	var terrain: Dictionary = presentation.get("terrain_presentation", {})
	if String(terrain.get("rendering_mode", "")) == "hidden_fog":
		_fail("Visual guard sampled hidden fog instead of visible terrain: %s" % JSON.stringify(presentation))
		return false
	if String(terrain.get("rendering_mode", "")) != "homm3_local_reference_prototype":
		_fail("Generated visible terrain did not use the normal terrain art renderer: %s" % JSON.stringify(terrain))
		return false
	var art: Dictionary = presentation.get("art_presentation", {})
	if String(art.get("object_rendering_path", "")) == "primitive_generated_fast_path":
		_fail("Generated visible object art reported primitive fast-path rendering: %s" % JSON.stringify(art))
		return false
	return true

func _generated_session() -> SessionStateStoreScript.SessionData:
	var overworld := {
		"map": _map_rows(),
		"map_size": {"width": MAP_WIDTH, "height": MAP_HEIGHT},
		"terrain_layers": {"id": "generated_visual_regression_layers", "roads": [_road()]},
		"hero_position": {"x": 18, "y": 18},
		"movement": {"current": 24, "max": 24},
		"resources": {"gold": 1000, "wood": 20, "ore": 20},
		"towns": [{"placement_id": "visual_guard_town", "town_id": "town_frontier_keep", "owner": "player", "x": 18, "y": 18}],
		"resource_nodes": [{"placement_id": "visual_guard_resource", "site_id": "site_wood_wagon", "x": 19, "y": 18, "collected": false}],
		"artifact_nodes": [{"placement_id": "visual_guard_artifact", "artifact_id": "artifact_trailsinger_boots", "x": 17, "y": 18, "collected": false}],
		"encounters": [{"placement_id": "visual_guard_encounter", "encounter_id": "encounter_ghoul_grove", "x": 18, "y": 19}],
		"resolved_encounters": [],
		"player_heroes": [{
			"id": "visual_guard_hero",
			"hero_id": "visual_guard_hero",
			"name": "Visual Guard",
			"is_active": true,
			"position": {"x": 18, "y": 18},
			"movement": {"current": 24, "max": 24},
		}],
		"fog": _fog_payload(),
	}
	var session := SessionStateStoreScript.new_session_data(
		"generated-visual-path-regression",
		"generated_visual_path_regression",
		"visual_guard_hero",
		1,
		overworld,
		"normal",
		SessionStateStoreScript.LAUNCH_MODE_SKIRMISH
	)
	session.flags["generated_random_map"] = true
	session.flags["generated_random_map_materialization"] = {
		"materialized_map_signature": "generated-visual-path-regression-36",
		"summary": {"map_size": {"width": MAP_WIDTH, "height": MAP_HEIGHT}},
	}
	return session

func _map_rows() -> Array:
	var rows := []
	for y in range(MAP_HEIGHT):
		var row := []
		for x in range(MAP_WIDTH):
			var terrain := "grass"
			if x % 9 == 0:
				terrain = "forest"
			elif y % 11 == 0:
				terrain = "hills"
			row.append(terrain)
		rows.append(row)
	return rows

func _fog_payload() -> Dictionary:
	var visible := []
	var explored := []
	for y in range(MAP_HEIGHT):
		var visible_row := []
		var explored_row := []
		for x in range(MAP_WIDTH):
			var in_scout_net: bool = (abs(x - 18) + abs(y - 18)) <= 8
			visible_row.append(in_scout_net)
			explored_row.append(true)
		visible.append(visible_row)
		explored.append(explored_row)
	return {
		"visible_tiles": visible,
		"explored_tiles": explored,
		"visible_count": 145,
		"explored_count": MAP_WIDTH * MAP_HEIGHT,
		"total_tiles": MAP_WIDTH * MAP_HEIGHT,
	}

func _road() -> Dictionary:
	var tiles := []
	for x in range(6, MAP_WIDTH - 6):
		tiles.append({"x": x, "y": 18})
	return {
		"id": "visual_guard_road",
		"overlay_id": "road_dirt",
		"role": "generated_visual_regression_guard",
		"tiles": tiles,
	}

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
