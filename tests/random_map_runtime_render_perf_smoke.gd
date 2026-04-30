extends Node

const OverworldMapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "RANDOM_MAP_RUNTIME_RENDER_PERF_SMOKE"
const MAP_WIDTH := 144
const MAP_HEIGHT := 144

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var session := _xl_session()
	var view = OverworldMapViewScript.new()
	view.size = Vector2(1280, 720)
	add_child(view)
	await get_tree().process_frame

	var map_data: Array = session.overworld.get("map", [])
	var selected := Vector2i(72, 72)
	var started := Time.get_ticks_msec()
	view.set_map_state(session, map_data, Vector2i(MAP_WIDTH, MAP_HEIGHT), selected)
	await get_tree().process_frame
	var first_elapsed := Time.get_ticks_msec() - started
	var first_metrics: Dictionary = view.validation_view_metrics()

	started = Time.get_ticks_msec()
	view.set_map_state(session, map_data, Vector2i(MAP_WIDTH, MAP_HEIGHT), selected)
	await get_tree().process_frame
	var second_elapsed := Time.get_ticks_msec() - started
	var second_metrics: Dictionary = view.validation_view_metrics()

	if not _assert_metrics(first_metrics, second_metrics, first_elapsed, second_elapsed):
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"map_size": first_metrics.get("map_size", {}),
		"visible_bounds": first_metrics.get("visible_bounds", {}),
		"visible_tile_area": first_metrics.get("visible_tile_area", 0),
		"spatial_index": first_metrics.get("spatial_index", {}),
		"first_set_map_state_ms": first_elapsed,
		"second_set_map_state_ms": second_elapsed,
		"render_cache": second_metrics.get("render_cache", {}),
	})])
	get_tree().quit(0)

func _assert_metrics(first_metrics: Dictionary, second_metrics: Dictionary, first_elapsed: int, second_elapsed: int) -> bool:
	var map_size: Dictionary = first_metrics.get("map_size", {})
	if int(map_size.get("x", 0)) != MAP_WIDTH or int(map_size.get("y", 0)) != MAP_HEIGHT:
		_fail("Smoke did not preserve the honest XL 144x144 map size: %s" % JSON.stringify(map_size))
		return false
	if bool(first_metrics.get("full_map_visible", true)) or not bool(first_metrics.get("pan_supported", false)):
		_fail("XL map should render through a panned visible window, not as full-map visible: %s" % JSON.stringify(first_metrics))
		return false
	var visible_bounds: Dictionary = first_metrics.get("visible_bounds", {})
	var visible_area := int(visible_bounds.get("width", 0)) * int(visible_bounds.get("height", 0))
	if visible_area <= 0 or visible_area >= MAP_WIDTH * MAP_HEIGHT:
		_fail("Visible render bounds were not limited for XL: %s" % JSON.stringify(visible_bounds))
		return false
	var spatial_index: Dictionary = first_metrics.get("spatial_index", {})
	if int(spatial_index.get("resource_tiles", 0)) < 120 or int(spatial_index.get("encounter_tiles", 0)) < 120:
		_fail("Object spatial indexes did not materialize enough generated-scale objects: %s" % JSON.stringify(spatial_index))
		return false
	if first_elapsed > 3000 or second_elapsed > 1500:
		_fail("XL set_map_state/render smoke exceeded budget: first=%dms second=%dms metrics=%s" % [first_elapsed, second_elapsed, JSON.stringify(second_metrics)])
		return false
	return true

func _xl_session() -> SessionStateStoreScript.SessionData:
	var overworld := {
		"map": _map_rows(),
		"map_size": {"width": MAP_WIDTH, "height": MAP_HEIGHT},
		"terrain_layers": {"id": "runtime_render_perf_xl_layers", "roads": [_road()]},
		"hero_position": {"x": 72, "y": 72},
		"movement": {"current": 24, "max": 24},
		"resources": {"gold": 1000, "wood": 20, "ore": 20},
		"towns": _towns(),
		"resource_nodes": _resource_nodes(),
		"artifact_nodes": _artifact_nodes(),
		"encounters": _encounters(),
		"resolved_encounters": [],
		"player_heroes": [{
			"id": "runtime_render_perf_hero",
			"hero_id": "runtime_render_perf_hero",
			"name": "Runtime Scout",
			"is_active": true,
			"position": {"x": 72, "y": 72},
			"movement": {"current": 24, "max": 24},
		}],
		"fog": _fog_payload(),
	}
	var session := SessionStateStoreScript.new_session_data(
		"runtime-render-perf-smoke",
		"generated_runtime_render_perf_xl",
		"runtime_render_perf_hero",
		1,
		overworld,
		"normal",
		SessionStateStoreScript.LAUNCH_MODE_SKIRMISH
	)
	session.flags["generated_random_map_materialization"] = {
		"materialized_map_signature": "runtime-render-perf-smoke-xl-144",
		"summary": {"map_size": {"width": MAP_WIDTH, "height": MAP_HEIGHT}},
	}
	return session

func _map_rows() -> Array:
	var rows := []
	for y in range(MAP_HEIGHT):
		var row := []
		for x in range(MAP_WIDTH):
			var terrain := "grass"
			if x % 17 == 0 and y % 5 != 0:
				terrain = "forest"
			elif y % 29 == 0 and x % 7 != 0:
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
			var in_scout_net: bool = (abs(x - 72) + abs(y - 72)) <= 7
			visible_row.append(in_scout_net)
			explored_row.append(true)
		visible.append(visible_row)
		explored.append(explored_row)
	return {
		"visible_tiles": visible,
		"explored_tiles": explored,
		"visible_count": 113,
		"explored_count": MAP_WIDTH * MAP_HEIGHT,
		"total_tiles": MAP_WIDTH * MAP_HEIGHT,
	}

func _towns() -> Array:
	return [
		{"placement_id": "runtime_town_player", "town_id": "town_frontier_keep", "owner": "player", "x": 72, "y": 72},
		{"placement_id": "runtime_town_enemy", "town_id": "town_frontier_keep", "owner": "enemy", "x": 118, "y": 118},
	]

func _resource_nodes() -> Array:
	var nodes := []
	for index in range(160):
		nodes.append({
			"placement_id": "runtime_resource_%03d" % index,
			"site_id": "site_wood_wagon" if index % 2 == 0 else "site_ore_crates",
			"x": (index * 13 + 5) % MAP_WIDTH,
			"y": (index * 19 + 9) % MAP_HEIGHT,
			"collected": false,
		})
	return nodes

func _artifact_nodes() -> Array:
	var nodes := []
	for index in range(32):
		nodes.append({
			"placement_id": "runtime_artifact_%02d" % index,
			"artifact_id": "artifact_trailsinger_boots",
			"x": (index * 23 + 11) % MAP_WIDTH,
			"y": (index * 31 + 17) % MAP_HEIGHT,
			"collected": false,
		})
	return nodes

func _encounters() -> Array:
	var encounters := []
	for index in range(160):
		encounters.append({
			"placement_id": "runtime_encounter_%03d" % index,
			"encounter_id": "encounter_ghoul_grove",
			"x": (index * 29 + 3) % MAP_WIDTH,
			"y": (index * 37 + 21) % MAP_HEIGHT,
		})
	return encounters

func _road() -> Dictionary:
	var tiles := []
	for x in range(8, MAP_WIDTH - 8):
		tiles.append({"x": x, "y": 72})
	for y in range(8, MAP_HEIGHT - 8):
		tiles.append({"x": 72, "y": y})
	return {
		"id": "runtime_render_perf_crossroad",
		"overlay_id": "road_dirt",
		"role": "generated_runtime_perf_smoke",
		"tiles": tiles,
	}

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
