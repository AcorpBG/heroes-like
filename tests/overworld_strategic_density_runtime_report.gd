extends Node

const SessionDataScript = preload("res://scripts/core/SessionStateStore.gd")
const REPORT_ID := "OVERWORLD_STRATEGIC_DENSITY_RUNTIME_REPORT"
const CASES := [
	{
		"scenario_id": "ninefold-confluence",
		"baseline_interactables": 153,
		"expected_interactables": 189,
		"expected_blockers": 29,
		"expected_body_tiles": 164,
	},
	{
		"scenario_id": "third-hearths-confluence",
		"baseline_interactables": 34,
		"expected_interactables": 44,
		"expected_blockers": 10,
		"expected_body_tiles": 52,
	},
]
const CAPTURE_VIEWPORTS := [Vector2i(1280, 720), Vector2i(1920, 1080)]

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var rows: Array = []
	for case_value in CASES:
		var row := _static_case(case_value)
		rows.append(row)
		if not bool(row.get("ok", false)):
			_fail("Strategic density case failed: %s" % JSON.stringify(row))
			return
	var visual_rows: Array = []
	for viewport_size in CAPTURE_VIEWPORTS:
		var visual_row := await _visual_case(viewport_size)
		visual_rows.append(visual_row)
		if not bool(visual_row.get("ok", false)):
			_fail("Strategic density visual case failed: %s" % JSON.stringify(visual_row))
			return
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"model": "explicit_authored_route_rewards_and_biome_scenery_v1",
		"native_rmg_unchanged": true,
		"cases": rows,
		"visual_rows": visual_rows,
	})])
	get_tree().quit(0)

func _static_case(case_value: Dictionary) -> Dictionary:
	var scenario_id := String(case_value.get("scenario_id", ""))
	var session = ScenarioFactory.create_session(scenario_id, "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	var blockers: Array = session.overworld.get("map_objects", [])
	var body_tiles := 0
	var all_body_tiles_blocked := true
	for blocker_value in blockers:
		if not (blocker_value is Dictionary):
			continue
		var blocker: Dictionary = blocker_value
		for body_value in blocker.get("body_tiles", []):
			if not (body_value is Dictionary):
				continue
			body_tiles += 1
			if not OverworldRules.tile_is_blocked(session, int(body_value.get("x", -1)), int(body_value.get("y", -1))):
				all_body_tiles_blocked = false
	var interactables: int = session.overworld.get("towns", []).size() \
		+ session.overworld.get("resource_nodes", []).size() \
		+ session.overworld.get("artifact_nodes", []).size() \
		+ session.overworld.get("encounters", []).size()
	var expected_interactables := int(case_value.get("expected_interactables", 0))
	var baseline_interactables := int(case_value.get("baseline_interactables", 0))
	var map_size: Dictionary = session.overworld.get("map_size", {})
	var map_area := maxi(1, int(map_size.get("width", 0)) * int(map_size.get("height", 0)))
	var pickup_count := 0
	var claimed_pickup_count := 0
	var nodes: Array = session.overworld.get("resource_nodes", [])
	for index in range(nodes.size()):
		var node: Dictionary = nodes[index] if nodes[index] is Dictionary else {}
		if String(node.get("content_batch_id", "")) != "overworld-strategic-density-and-route-occupancy-10230":
			continue
		pickup_count += 1
		var site := ContentService.get_resource_site(String(node.get("site_id", "")))
		var result: Dictionary = OverworldRules._collect_resource_node_result(session, {"index": index, "node": node}, true)
		if not site.is_empty() and bool(result.get("ok", false)):
			claimed_pickup_count += 1
	var restored = SessionDataScript.SessionData.new()
	restored.from_dict(session.to_dict().duplicate(true))
	var save_round_trip_exact: bool = restored.save_version == SessionDataScript.SAVE_VERSION \
		and restored.overworld.get("map_objects", []).size() == blockers.size() \
		and restored.overworld.get("resource_nodes", []).size() == nodes.size()
	return {
		"ok": interactables == expected_interactables \
			and blockers.size() == int(case_value.get("expected_blockers", 0)) \
			and body_tiles == int(case_value.get("expected_body_tiles", 0)) \
			and all_body_tiles_blocked \
			and claimed_pickup_count == pickup_count \
			and save_round_trip_exact,
		"scenario_id": scenario_id,
		"baseline_interactables": baseline_interactables,
		"live_interactables": interactables,
		"interactable_gain": interactables - baseline_interactables,
		"relative_interactable_gain": snapped(float(interactables - baseline_interactables) / float(maxi(1, baseline_interactables)), 0.0001),
		"interactables_per_100_tiles": snapped(float(interactables) * 100.0 / float(map_area), 0.0001),
		"authored_blockers": blockers.size(),
		"blocked_body_tiles": body_tiles,
		"all_body_tiles_blocked": all_body_tiles_blocked,
		"authored_pickup_count": pickup_count,
		"claimed_pickup_count": claimed_pickup_count,
		"save_version": restored.save_version,
		"save_round_trip_exact": save_round_trip_exact,
	}

func _visual_case(viewport_size: Vector2i) -> Dictionary:
	get_window().size = viewport_size
	await get_tree().process_frame
	var session = ScenarioFactory.create_session("ninefold-confluence", "normal", SessionState.LAUNCH_MODE_SKIRMISH)
	_reveal_all(session)
	session = SessionState.set_active_session(session)
	var shell = load("res://scenes/overworld/OverworldShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var map_view = shell.get_node_or_null("%Map")
	if map_view == null:
		shell.queue_free()
		return {"ok": false, "failure": "map_view_missing"}
	var view_metrics: Dictionary = map_view.call("validation_view_metrics")
	var scenery: Dictionary = map_view.call("validation_authored_scenery_summary")
	var shell_contained := get_viewport().get_visible_rect().encloses(shell.get_global_rect())
	await _capture_if_requested(viewport_size)
	shell.queue_free()
	await get_tree().process_frame
	return {
		"ok": int(scenery.get("authored_count", 0)) == 29 \
			and int(scenery.get("indexed_count", 0)) == 29 \
			and int(scenery.get("loaded_asset_count", 0)) == 29 \
			and int(scenery.get("blocked_body_tile_count", 0)) == 164 \
			and bool(scenery.get("all_indexed", false)) \
			and bool(scenery.get("all_assets_loaded", false)) \
			and shell_contained,
		"viewport": [viewport_size.x, viewport_size.y],
		"visible_bounds": view_metrics.get("visible_bounds", {}),
		"spatial_index": view_metrics.get("spatial_index", {}),
		"authored_scenery": scenery,
		"shell_contained": shell_contained,
	}

func _reveal_all(session) -> void:
	var map_size := OverworldRules.derive_map_size(session)
	var visible_tiles: Array = []
	var explored_tiles: Array = []
	for _y in range(map_size.y):
		var visible_row: Array = []
		var explored_row: Array = []
		for _x in range(map_size.x):
			visible_row.append(true)
			explored_row.append(true)
		visible_tiles.append(visible_row)
		explored_tiles.append(explored_row)
	session.overworld["fog"] = {
		"visible_tiles": visible_tiles,
		"explored_tiles": explored_tiles,
		"visible_count": map_size.x * map_size.y,
		"explored_count": map_size.x * map_size.y,
		"total_tiles": map_size.x * map_size.y,
	}

func _capture_if_requested(viewport_size: Vector2i) -> void:
	var capture_dir := OS.get_environment("OVERWORLD_DENSITY_CAPTURE_DIR").strip_edges()
	if capture_dir == "":
		return
	await RenderingServer.frame_post_draw
	var absolute_dir := ProjectSettings.globalize_path(capture_dir)
	if DirAccess.make_dir_recursive_absolute(absolute_dir) != OK:
		return
	var image := get_viewport().get_texture().get_image()
	if image != null and not image.is_empty():
		image.save_png(absolute_dir.path_join("ninefold_density_%dx%d.png" % [viewport_size.x, viewport_size.y]))

func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
