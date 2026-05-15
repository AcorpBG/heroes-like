extends Node

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const OverworldRulesScript = preload("res://scripts/core/OverworldRules.gd")
const OverworldMapViewScript = preload("res://scenes/overworld/OverworldMapView.gd")

const REPORT_ID := "NATIVE_RMG_SMALL_H3MAPED_RUNTIME_ACCEPTANCE_REPORT"
const REPORT_SCHEMA_ID := "native_rmg_small_h3maped_runtime_acceptance_report_v1"
const DIRECTIONS := [
	Vector2i.LEFT,
	Vector2i.RIGHT,
	Vector2i.UP,
	Vector2i.DOWN,
	Vector2i(-1, -1),
	Vector2i(1, -1),
	Vector2i(-1, 1),
	Vector2i(1, 1),
]

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not ClassDB.class_exists("MapPackageService"):
		_fail("MapPackageService native class is not available.")
		return
	var service: Variant = ClassDB.instantiate("MapPackageService")
	var metadata: Dictionary = service.get_api_metadata()
	if String(metadata.get("binding_kind", "")) != "native_gdextension" or not bool(metadata.get("native_extension_loaded", false)):
		_fail("Native service metadata did not prove GDExtension load: %s" % JSON.stringify(metadata))
		return

	ContentService.clear_generated_scenario_drafts()
	var config := ScenarioSelectRulesScript.build_random_map_player_config(
		"1",
		"",
		"",
		3,
		"land",
		false,
		"homm3_small"
	)
	var setup := ScenarioSelectRulesScript.build_random_map_skirmish_setup_with_retry(
		config,
		"normal",
		ScenarioSelectRulesScript.RANDOM_MAP_PLAYER_RETRY_POLICY
	)
	if not bool(setup.get("ok", false)):
		_fail("Generated package setup failed: %s" % JSON.stringify(setup))
		return
	if not setup.get("generated_map", {}).is_empty():
		_fail("Setup still exposed legacy in-memory generated map payload.")
		return
	var package_startup: Dictionary = setup.get("package_startup", {}) if setup.get("package_startup", {}) is Dictionary else {}
	if package_startup.is_empty():
		_fail("Setup did not include generated package startup data.")
		return
	var map_path := String(package_startup.get("map_path", ""))
	var scenario_path := String(package_startup.get("scenario_path", ""))
	if map_path == "" or scenario_path == "" or not FileAccess.file_exists(map_path) or not FileAccess.file_exists(scenario_path):
		_fail("Generated package files were not present for runtime acceptance: %s" % JSON.stringify(package_startup))
		return

	var session = ScenarioSelectRulesScript.start_random_map_skirmish_session_from_setup(setup)
	if session == null or session.scenario_id == "":
		_cleanup_generated_packages(map_path, scenario_path)
		_fail("Generated package setup did not start a runtime session.")
		return
	var boundary: Dictionary = session.flags.get("generated_random_map_boundary", {}) if session.flags.get("generated_random_map_boundary", {}) is Dictionary else {}
	if String(boundary.get("adoption_path", "")) != "native_rmg_generated_package_saved_loaded_from_disk":
		_cleanup_generated_packages(map_path, scenario_path)
		_fail("Runtime session did not use disk package adoption: %s" % JSON.stringify(boundary))
		return

	var loaded_map: Dictionary = service.load_map_package(map_path)
	var loaded_scenario: Dictionary = service.load_scenario_package(scenario_path)
	if not bool(loaded_map.get("ok", false)) or not bool(loaded_scenario.get("ok", false)):
		_cleanup_generated_packages(map_path, scenario_path)
		_fail("Independent package load failed: map=%s scenario=%s" % [JSON.stringify(loaded_map), JSON.stringify(loaded_scenario)])
		return
	var map_document: Variant = loaded_map.get("map_document", null)
	var scenario_document: Variant = loaded_scenario.get("scenario_document", null)
	if map_document == null or scenario_document == null:
		_cleanup_generated_packages(map_path, scenario_path)
		_fail("Loaded packages did not expose map/scenario documents.")
		return

	var package_summary := _package_summary(map_document, scenario_document)
	var runtime_summary := _runtime_summary(session)
	var pathing_summary := _runtime_pathing_mask_summary(session, map_document)
	var road_tiles := _road_tiles_from_document(map_document)
	var reachable_road := _reachable_road_summary(session, road_tiles)
	if not _assert_package_runtime_acceptance(package_summary, runtime_summary, pathing_summary, reachable_road):
		_cleanup_generated_packages(map_path, scenario_path)
		return

	_reveal_full_map(session, Vector2i(int(map_document.get_width()), int(map_document.get_height())))
	var render_summary := await _renderer_summary(session, road_tiles, reachable_road)
	if not _assert_renderer_acceptance(render_summary, package_summary, reachable_road):
		_cleanup_generated_packages(map_path, scenario_path)
		return

	var saved_session_map_ref: Dictionary = session.overworld.get("map_package_ref", {}) if session.overworld.get("map_package_ref", {}) is Dictionary else {}
	var saved_session_scenario_ref: Dictionary = session.overworld.get("scenario_package_ref", {}) if session.overworld.get("scenario_package_ref", {}) is Dictionary else {}
	_cleanup_generated_packages(map_path, scenario_path)
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"schema_id": REPORT_SCHEMA_ID,
		"ok": true,
		"native_extension_loaded": true,
		"map_path": map_path,
		"scenario_path": scenario_path,
		"session_id": session.session_id,
		"scenario_id": session.scenario_id,
		"map_package_ref": saved_session_map_ref,
		"scenario_package_ref": saved_session_scenario_ref,
		"package_summary": package_summary,
		"runtime_summary": runtime_summary,
		"pathing_summary": pathing_summary,
		"reachable_road": reachable_road,
		"renderer_summary": render_summary,
		"acceptance_scope": "strict_small_land_runtime_editor_renderer_acceptance_without_mode_expansion",
	})])
	get_tree().quit(0)

func _assert_package_runtime_acceptance(
	package_summary: Dictionary,
	runtime_summary: Dictionary,
	pathing_summary: Dictionary,
	reachable_road: Dictionary
) -> bool:
	if String(package_summary.get("source_template_authority", "")) != "h3maped_exe_rng" \
			or not String(package_summary.get("source_template_id", "")).begins_with("h3maped_template_"):
		_fail("Package did not preserve h3maped executable template authority: %s" % JSON.stringify(package_summary))
		return false
	if int(package_summary.get("width", 0)) != 36 or int(package_summary.get("height", 0)) != 36 or int(package_summary.get("level_count", 0)) != 1:
		_fail("Package dimensions are outside strict Small one-level scope: %s" % JSON.stringify(package_summary))
		return false
	if int(package_summary.get("player_slot_count", 0)) != 3 \
			or int(package_summary.get("town_count", 0)) != 3 \
			or int(package_summary.get("player_start_town_count", 0)) != 3 \
			or int(package_summary.get("neutral_town_count", -1)) != 0:
		_fail("Package lost Small owned start-town contract: %s" % JSON.stringify(package_summary))
		return false
	if int(runtime_summary.get("town_count", 0)) != int(package_summary.get("town_count", 0)) \
			or int(runtime_summary.get("start_slot_town_count", 0)) != int(package_summary.get("player_start_town_count", 0)):
		_fail("Runtime towns do not match package owned start-town contract: runtime=%s package=%s" % [JSON.stringify(runtime_summary), JSON.stringify(package_summary)])
		return false
	if int(package_summary.get("road_unique_tile_count", 0)) <= 0 \
			or int(package_summary.get("road_unique_tile_count", 0)) != int(runtime_summary.get("road_unique_tile_count", 0)):
		_fail("Runtime roads do not match package road tiles: runtime=%s package=%s" % [JSON.stringify(runtime_summary), JSON.stringify(package_summary)])
		return false
	if int(package_summary.get("guard_count", 0)) <= 0 \
			or int(runtime_summary.get("guard_count", 0)) != int(package_summary.get("guard_count", 0)):
		_fail("Runtime guards do not match package guards: runtime=%s package=%s" % [JSON.stringify(runtime_summary), JSON.stringify(package_summary)])
		return false
	if int(package_summary.get("connection_blocker_count", 0)) <= 0 \
			or int(runtime_summary.get("connection_blocker_count", 0)) != int(package_summary.get("connection_blocker_count", 0)):
		_fail("Runtime connection blockers do not match package blockers: runtime=%s package=%s" % [JSON.stringify(runtime_summary), JSON.stringify(package_summary)])
		return false
	if int(package_summary.get("mine_count", 0)) <= 0 or int(runtime_summary.get("resource_node_count", 0)) < int(package_summary.get("mine_count", 0)):
		_fail("Runtime resource nodes do not cover package mines: runtime=%s package=%s" % [JSON.stringify(runtime_summary), JSON.stringify(package_summary)])
		return false
	if int(package_summary.get("reward_count", 0)) <= 0:
		_fail("Package lost reward objects before runtime acceptance: %s" % JSON.stringify(package_summary))
		return false
	if int(pathing_summary.get("required_block_tile_count", 0)) <= 0 \
			or int(pathing_summary.get("runtime_unblocked_required_tile_count", 0)) != 0 \
			or int(pathing_summary.get("blocked_non_actionable_visit_tile_count", 0)) != 0:
		_fail("Package body/visit/block masks do not agree with runtime pathing: %s" % JSON.stringify(pathing_summary))
		return false
	if not bool(reachable_road.get("ok", false)) \
			or int(reachable_road.get("path_tile_count", 0)) <= 1 \
			or int(reachable_road.get("reachable_steps", 0)) <= 0:
		_fail("No playable runtime route from hero start to a package road tile: %s" % JSON.stringify(reachable_road))
		return false
	return true

func _assert_renderer_acceptance(render_summary: Dictionary, package_summary: Dictionary, reachable_road: Dictionary) -> bool:
	if not bool(render_summary.get("ok", false)):
		_fail("Renderer summary failed: %s" % JSON.stringify(render_summary))
		return false
	var metrics: Dictionary = render_summary.get("metrics", {}) if render_summary.get("metrics", {}) is Dictionary else {}
	if not bool(metrics.get("generated_maps_use_normal_art_path", false)) or bool(metrics.get("primitive_generated_render_path", true)):
		_fail("Generated map used the wrong render path: %s" % JSON.stringify(metrics))
		return false
	var spatial: Dictionary = metrics.get("spatial_index", {}) if metrics.get("spatial_index", {}) is Dictionary else {}
	if int(spatial.get("town_tiles", 0)) < int(package_summary.get("town_count", 0)) \
			or int(spatial.get("resource_tiles", 0)) <= 0 \
			or int(spatial.get("encounter_tiles", 0)) < int(package_summary.get("guard_count", 0)) \
			or int(spatial.get("decorative_object_tiles", 0)) <= 0:
		_fail("Renderer spatial indexes did not expose generated map objects: %s" % JSON.stringify(spatial))
		return false
	var road_presentation: Dictionary = render_summary.get("road_presentation", {}) if render_summary.get("road_presentation", {}) is Dictionary else {}
	if not bool(road_presentation.get("road_overlay", false)) \
			or int(road_presentation.get("road_connection_count", 0)) <= 0 \
			or String(road_presentation.get("road_connection_source", "")) != "orthogonal_same_type_road_tiles" \
			or String(road_presentation.get("road_shape_model", "")) == "":
		_fail("Renderer did not present package road tile as a real road overlay: road=%s reachable=%s" % [JSON.stringify(road_presentation), JSON.stringify(reachable_road)])
		return false
	var route_preview: Dictionary = metrics.get("route_preview", {}) if metrics.get("route_preview", {}) is Dictionary else {}
	if not bool(route_preview.get("ok", false)) or int(route_preview.get("total_steps", 0)) <= 0:
		_fail("Renderer did not produce a route preview to reachable road tile: %s" % JSON.stringify(route_preview))
		return false
	var town_profiles: Array = render_summary.get("town_profiles", []) if render_summary.get("town_profiles", []) is Array else []
	if town_profiles.size() != int(package_summary.get("town_count", 0)):
		_fail("Renderer town presentation profile count does not match package towns: %s" % JSON.stringify(render_summary))
		return false
	return true

func _package_summary(map_document: Variant, scenario_document: Variant) -> Dictionary:
	var metadata: Dictionary = map_document.get_metadata()
	var component_counts: Dictionary = metadata.get("component_counts", {}) if metadata.get("component_counts", {}) is Dictionary else {}
	var roads: Array = map_document.get_terrain_layers().get("roads", []) if map_document.get_terrain_layers().get("roads", []) is Array else []
	var road_tiles := _road_tiles_from_document(map_document)
	var counts := _object_counts(map_document)
	var player_slots: Array = scenario_document.get_player_slots() if scenario_document.has_method("get_player_slots") else []
	var start_contract: Dictionary = scenario_document.get_start_contract() if scenario_document.has_method("get_start_contract") else {}
	return {
		"width": int(map_document.get_width()),
		"height": int(map_document.get_height()),
		"level_count": int(map_document.get_level_count()),
		"map_id": String(map_document.get_map_id()) if map_document.has_method("get_map_id") else "",
		"map_hash": String(map_document.get_map_hash()) if map_document.has_method("get_map_hash") else "",
		"scenario_id": String(scenario_document.get_scenario_id()) if scenario_document.has_method("get_scenario_id") else "",
		"source_template_id": String(metadata.get("source_template_id", "")),
		"source_template_authority": String(metadata.get("source_template_authority", "")),
		"production_ready": bool(metadata.get("production_ready", false)),
		"player_slot_count": player_slots.size(),
		"start_contract": start_contract,
		"road_record_count": roads.size(),
		"road_unique_tile_count": road_tiles.size(),
		"source_road_cell_count": int(component_counts.get("road_cell_count", 0)),
		"road_segment_cell_count": int(component_counts.get("road_segment_cell_count", 0)),
		"object_count": int(map_document.get_object_count()),
		"town_count": int(counts.get("town", 0)),
		"player_start_town_count": int(counts.get("player_start_town", 0)),
		"neutral_town_count": int(counts.get("neutral_town", 0)),
		"guard_count": int(counts.get("guard", 0)),
		"connection_blocker_count": int(counts.get("connection_blocker", 0)),
		"decorative_obstacle_count": int(counts.get("decorative_obstacle", 0)),
		"mine_count": int(counts.get("mine", 0)),
		"reward_count": int(counts.get("reward_reference", 0)),
		"artifact_count": int(counts.get("artifact", 0)),
		"object_counts_by_kind": counts,
	}

func _runtime_summary(session: Variant) -> Dictionary:
	var roads := _road_tiles_from_runtime(session)
	var towns: Array = session.overworld.get("towns", []) if session.overworld.get("towns", []) is Array else []
	var owned_towns := 0
	var start_slot_towns := 0
	for town in towns:
		if not (town is Dictionary):
			continue
		if String(town.get("owner", "")) == "player":
			owned_towns += 1
		if int(town.get("owner_slot", 0)) > 0 or bool(town.get("is_start_town", false)):
			start_slot_towns += 1
	var encounters: Array = session.overworld.get("encounters", []) if session.overworld.get("encounters", []) is Array else []
	var guard_count := 0
	for encounter in encounters:
		if encounter is Dictionary and String(encounter.get("kind", "")) == "guard":
			guard_count += 1
	var map_objects: Array = session.overworld.get("map_objects", []) if session.overworld.get("map_objects", []) is Array else []
	var connection_blockers := 0
	var decorative_obstacles := 0
	for object in map_objects:
		if not (object is Dictionary):
			continue
		var kind := String(object.get("kind", ""))
		if kind == "connection_blocker":
			connection_blockers += 1
		elif kind == "decorative_obstacle":
			decorative_obstacles += 1
	return {
		"hero_position": _tile_payload(OverworldRulesScript.hero_position(session)),
		"town_count": towns.size(),
		"player_owned_town_count": owned_towns,
		"start_slot_town_count": start_slot_towns,
		"guard_count": guard_count,
		"connection_blocker_count": connection_blockers,
		"decorative_obstacle_count": decorative_obstacles,
		"resource_node_count": session.overworld.get("resource_nodes", []).size() if session.overworld.get("resource_nodes", []) is Array else 0,
		"artifact_node_count": session.overworld.get("artifact_nodes", []).size() if session.overworld.get("artifact_nodes", []) is Array else 0,
		"road_unique_tile_count": roads.size(),
	}

func _runtime_pathing_mask_summary(session: Variant, map_document: Variant) -> Dictionary:
	var required_block_tiles := {}
	var unblocked_required_tiles := []
	var visit_tile_count := 0
	var blocked_visit_tiles := []
	var blocked_non_actionable_visit_tiles := []
	var kinds_with_required_blocks := {}
	var kinds_with_visit_tiles := {}
	for index in range(int(map_document.get_object_count())):
		var object: Dictionary = map_document.get_object_by_index(index)
		var kind := String(object.get("kind", object.get("native_record_kind", "")))
		var placement_id := String(object.get("placement_id", ""))
		var block_tiles: Array = object.get("package_block_tiles", []) if object.get("package_block_tiles", []) is Array else []
		var must_block := bool(object.get("blocking_body", false)) or kind in ["town", "guard", "connection_blocker", "decorative_obstacle"]
		if must_block:
			kinds_with_required_blocks[kind] = true
			for tile_value in block_tiles:
				var tile := _tile_from_payload(tile_value)
				if tile.x < 0 or tile.y < 0:
					continue
				var key := _tile_key(tile)
				required_block_tiles[key] = true
				if not OverworldRulesScript.tile_is_blocked(session, tile.x, tile.y):
					unblocked_required_tiles.append({"kind": kind, "placement_id": placement_id, "tile": _tile_payload(tile)})
		if kind in ["town", "mine", "reward_reference", "artifact"]:
			var visit_tiles: Array = object.get("package_visit_tiles", []) if object.get("package_visit_tiles", []) is Array else []
			if visit_tiles.is_empty() and object.get("visit_tile", {}) is Dictionary:
				visit_tiles = [object.get("visit_tile", {})]
			for tile_value in visit_tiles:
				var visit_tile := _tile_from_payload(tile_value)
				if visit_tile.x < 0 or visit_tile.y < 0:
					continue
				visit_tile_count += 1
				kinds_with_visit_tiles[kind] = true
				if OverworldRulesScript.tile_is_blocked(session, visit_tile.x, visit_tile.y):
					var blocked_payload := {"kind": kind, "placement_id": placement_id, "tile": _tile_payload(visit_tile)}
					blocked_visit_tiles.append(blocked_payload)
					if not OverworldRulesScript.tile_has_route_interaction(session, visit_tile.x, visit_tile.y):
						blocked_non_actionable_visit_tiles.append(blocked_payload)
	return {
		"required_block_tile_count": required_block_tiles.size(),
		"runtime_unblocked_required_tile_count": unblocked_required_tiles.size(),
		"runtime_unblocked_required_tiles": unblocked_required_tiles,
		"visit_tile_count": visit_tile_count,
		"blocked_visit_tile_count": blocked_visit_tiles.size(),
		"blocked_visit_tiles": blocked_visit_tiles,
		"blocked_non_actionable_visit_tile_count": blocked_non_actionable_visit_tiles.size(),
		"blocked_non_actionable_visit_tiles": blocked_non_actionable_visit_tiles,
		"kinds_with_required_blocks": kinds_with_required_blocks.keys(),
		"kinds_with_visit_tiles": kinds_with_visit_tiles.keys(),
		"runtime_pathing_source": "OverworldRules.tile_is_blocked_live_session_index",
	}

func _renderer_summary(session: Variant, road_tiles: Dictionary, reachable_road: Dictionary) -> Dictionary:
	var selected := _tile_from_payload(reachable_road.get("target_tile", {}))
	if selected.x < 0:
		for key in road_tiles.keys():
			selected = road_tiles[key]
			break
	if selected.x < 0:
		return {"ok": false, "message": "No road tile available for renderer acceptance."}
	var view := OverworldMapViewScript.new()
	view.size = Vector2(1024, 768)
	view.large_map_visible_tile_span_override = 36.0
	add_child(view)
	await get_tree().process_frame
	view.validation_set_path_detail_profile_enabled(true)
	var map_size := OverworldRulesScript.derive_map_size(session)
	view.set_map_state(session, session.overworld.get("map", []), map_size, selected)
	await get_tree().process_frame
	var metrics: Dictionary = view.validation_view_metrics()
	var road_presentation: Dictionary = view.validation_tile_presentation(selected).get("terrain_presentation", {})
	var town_profiles: Array = view.validation_town_presentation_profiles()
	remove_child(view)
	view.queue_free()
	return {
		"ok": true,
		"selected_tile": _tile_payload(selected),
		"metrics": metrics,
		"road_presentation": road_presentation,
		"town_profiles": town_profiles,
	}

func _reachable_road_summary(session: Variant, road_tiles: Dictionary) -> Dictionary:
	var start := OverworldRulesScript.hero_position(session)
	var map_size := OverworldRulesScript.derive_map_size(session)
	var path := _find_path_to_any_road(session, start, map_size, road_tiles)
	if path.is_empty():
		return _unreachable_road_diagnostic(session, start, map_size, road_tiles)
	var target: Vector2i = path[path.size() - 1]
	var movement = session.overworld.get("movement", {})
	var budget := int(movement.get("current", 0)) if movement is Dictionary else 0
	var preview := OverworldRulesScript.route_movement_preview(session, path, budget)
	return {
		"ok": true,
		"start_tile": _tile_payload(start),
		"target_tile": _tile_payload(target),
		"path_tile_count": path.size(),
		"total_steps": int(preview.get("total_steps", 0)),
		"reachable_steps": int(preview.get("reachable_steps", 0)),
		"destination_reachable": bool(preview.get("destination_reachable", false)),
		"movement_budget": int(preview.get("movement_budget", 0)),
	}

func _find_path_to_any_road(session: Variant, start: Vector2i, map_size: Vector2i, road_tiles: Dictionary) -> Array:
	if road_tiles.has(_tile_key(start)) and not OverworldRulesScript.tile_is_blocked(session, start.x, start.y):
		return [start]
	var queue: Array = [start]
	var queue_index := 0
	var visited := {_tile_key(start): true}
	var came_from := {_tile_key(start): start}
	var found := Vector2i(-1, -1)
	while queue_index < queue.size():
		var current: Vector2i = queue[queue_index]
		queue_index += 1
		for direction in DIRECTIONS:
			var next: Vector2i = current + direction
			if next.x < 0 or next.y < 0 or next.x >= map_size.x or next.y >= map_size.y:
				continue
			var key := _tile_key(next)
			if visited.has(key):
				continue
			if OverworldRulesScript.tile_is_blocked(session, next.x, next.y):
				continue
			if OverworldRulesScript.tile_step_cuts_blocked_corner(session, current, next):
				continue
			if not road_tiles.has(key) and OverworldRulesScript.tile_has_route_interaction(session, next.x, next.y):
				continue
			visited[key] = true
			came_from[key] = current
			queue.append(next)
			if road_tiles.has(key):
				found = next
				queue_index = queue.size()
				break
	if found.x < 0:
		return []
	var path: Array = [found]
	var walker := found
	while walker != start:
		walker = came_from.get(_tile_key(walker), start)
		path.push_front(walker)
	return path

func _unreachable_road_diagnostic(session: Variant, start: Vector2i, map_size: Vector2i, road_tiles: Dictionary) -> Dictionary:
	var blocked_roads := 0
	var nearest_distance := 999999
	var nearest_tile := Vector2i(-1, -1)
	var road_block_attribution := _blocked_road_attribution(session, road_tiles)
	for key in road_tiles.keys():
		var road_tile: Vector2i = road_tiles[key]
		if OverworldRulesScript.tile_is_blocked(session, road_tile.x, road_tile.y):
			blocked_roads += 1
		var distance: int = abs(road_tile.x - start.x) + abs(road_tile.y - start.y)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_tile = road_tile
	var neighbor_payloads := []
	for direction_value in DIRECTIONS:
		var direction: Vector2i = direction_value
		var tile: Vector2i = start + direction
		if tile.x < 0 or tile.y < 0 or tile.x >= map_size.x or tile.y >= map_size.y:
			continue
		neighbor_payloads.append({
			"tile": _tile_payload(tile),
			"blocked": OverworldRulesScript.tile_is_blocked(session, tile.x, tile.y),
			"interaction": OverworldRulesScript.tile_has_route_interaction(session, tile.x, tile.y),
			"road": road_tiles.has(_tile_key(tile)),
			"blockers": _runtime_blockers_for_tile(session, tile),
		})
	return {
		"ok": false,
		"start_tile": _tile_payload(start),
		"target_tile": {},
		"path_tile_count": 0,
		"start_blocked": OverworldRulesScript.tile_is_blocked(session, start.x, start.y),
		"start_interaction": OverworldRulesScript.tile_has_route_interaction(session, start.x, start.y),
		"road_unique_tile_count": road_tiles.size(),
		"blocked_road_tile_count": blocked_roads,
		"blocked_road_attribution": road_block_attribution,
		"nearest_road_tile": _tile_payload(nearest_tile),
		"nearest_road_manhattan": nearest_distance,
		"nearest_road_blockers": _runtime_blockers_for_tile(session, nearest_tile),
		"start_blockers": _runtime_blockers_for_tile(session, start),
		"neighbors": neighbor_payloads,
	}

func _blocked_road_attribution(session: Variant, road_tiles: Dictionary) -> Dictionary:
	var family_counts := {}
	var examples := []
	for key in road_tiles.keys():
		var road_tile: Vector2i = road_tiles[key]
		if not OverworldRulesScript.tile_is_blocked(session, road_tile.x, road_tile.y):
			continue
		var blockers := _runtime_blockers_for_tile(session, road_tile)
		if blockers.is_empty():
			family_counts["terrain_or_unknown"] = int(family_counts.get("terrain_or_unknown", 0)) + 1
			if examples.size() < 20:
				examples.append({
					"tile": _tile_payload(road_tile),
					"blockers": [{"family": "terrain_or_unknown"}],
				})
			continue
		var counted_families := {}
		for blocker in blockers:
			if not (blocker is Dictionary):
				continue
			var family := String(blocker.get("family", "unknown"))
			if counted_families.has(family):
				continue
			counted_families[family] = true
			family_counts[family] = int(family_counts.get(family, 0)) + 1
		if examples.size() < 20:
			examples.append({
				"tile": _tile_payload(road_tile),
				"blockers": blockers,
			})
	return {
		"family_counts": family_counts,
		"examples": examples,
	}

func _runtime_blockers_for_tile(session: Variant, tile: Vector2i) -> Array:
	var blockers := []
	if tile.x < 0 or tile.y < 0:
		return blockers
	var map_data = session.overworld.get("map", []) if session != null else []
	if map_data is Array and tile.y >= 0 and tile.y < map_data.size():
		var row = map_data[tile.y]
		if row is Array and tile.x >= 0 and tile.x < row.size():
			var terrain_id := String(row[tile.x])
			if not OverworldRulesScript.terrain_id_is_passable(terrain_id):
				blockers.append({
					"family": "terrain",
					"terrain_id": terrain_id,
				})
	for town_value in session.overworld.get("towns", []):
		if not (town_value is Dictionary):
			continue
		var town: Dictionary = town_value
		if _placement_blocks_tile(town, tile, true):
			blockers.append(_blocker_payload("town", town, tile))
	for encounter_value in session.overworld.get("encounters", []):
		if not (encounter_value is Dictionary):
			continue
		var encounter: Dictionary = encounter_value
		if _placement_blocks_tile(encounter, tile, bool(encounter.get("blocking_body", true))):
			blockers.append(_blocker_payload("guard", encounter, tile))
	for object_value in session.overworld.get("map_objects", []):
		if not (object_value is Dictionary):
			continue
		var object: Dictionary = object_value
		var kind := String(object.get("kind", "map_object"))
		var family := String(object.get("object_family_id", object.get("family_id", "")))
		var blocks_body := bool(object.get("blocking_body", kind == "decorative_obstacle" or family == "decorative_obstacle"))
		if _placement_blocks_tile(object, tile, blocks_body):
			blockers.append(_blocker_payload(kind if kind != "" else "map_object", object, tile))
	for node_value in session.overworld.get("resource_nodes", []):
		if not (node_value is Dictionary):
			continue
		var node: Dictionary = node_value
		if _placement_blocks_tile(node, tile, bool(node.get("blocking_body", false))):
			blockers.append(_blocker_payload(String(node.get("kind", "resource_node")), node, tile))
	return blockers

func _placement_blocks_tile(placement: Dictionary, tile: Vector2i, blocks_body: bool) -> bool:
	if not blocks_body:
		return false
	var body_tiles: Array = placement.get("body_tiles", []) if placement.get("body_tiles", []) is Array else []
	if body_tiles.is_empty():
		return int(placement.get("x", -1)) == tile.x and int(placement.get("y", -1)) == tile.y
	for tile_value in body_tiles:
		var body_tile := _tile_from_payload(tile_value)
		if body_tile == tile:
			return true
	return false

func _blocker_payload(family: String, placement: Dictionary, tile: Vector2i) -> Dictionary:
	return {
		"family": family,
		"placement_id": String(placement.get("placement_id", placement.get("id", ""))),
		"object_id": String(placement.get("object_id", "")),
		"site_id": String(placement.get("site_id", "")),
		"town_id": String(placement.get("town_id", "")),
		"native_record_kind": String(placement.get("native_record_kind", "")),
		"blocking_body": bool(placement.get("blocking_body", true)),
		"origin": _tile_payload(Vector2i(int(placement.get("x", -1)), int(placement.get("y", -1)))),
		"tile": _tile_payload(tile),
	}

func _road_tiles_from_document(map_document: Variant) -> Dictionary:
	var result := {}
	var terrain_layers: Dictionary = map_document.get_terrain_layers()
	var roads: Array = terrain_layers.get("roads", []) if terrain_layers.get("roads", []) is Array else []
	for road in roads:
		if not (road is Dictionary):
			continue
		var tiles: Array = road.get("tiles", road.get("cells", [])) if road.get("tiles", road.get("cells", [])) is Array else []
		for tile_value in tiles:
			var tile := _tile_from_payload(tile_value)
			if tile.x >= 0 and tile.y >= 0:
				result[_tile_key(tile)] = tile
	return result

func _road_tiles_from_runtime(session: Variant) -> Dictionary:
	var result := {}
	var terrain_layers: Dictionary = session.overworld.get("terrain_layers", {}) if session.overworld.get("terrain_layers", {}) is Dictionary else {}
	var roads: Array = terrain_layers.get("roads", []) if terrain_layers.get("roads", []) is Array else []
	for road in roads:
		if not (road is Dictionary):
			continue
		var tiles: Array = road.get("tiles", road.get("cells", [])) if road.get("tiles", road.get("cells", [])) is Array else []
		for tile_value in tiles:
			var tile := _tile_from_payload(tile_value)
			if tile.x >= 0 and tile.y >= 0:
				result[_tile_key(tile)] = tile
	return result

func _object_counts(map_document: Variant) -> Dictionary:
	var counts := {}
	for index in range(int(map_document.get_object_count())):
		var object: Dictionary = map_document.get_object_by_index(index)
		var kind := String(object.get("kind", object.get("native_record_kind", object.get("category_id", ""))))
		if kind == "":
			kind = "object"
		counts[kind] = int(counts.get(kind, 0)) + 1
		if kind == "town":
			var owner := String(object.get("owner", "neutral"))
			if bool(object.get("is_start_town", false)) or int(object.get("owner_slot", 0)) > 0:
				counts["player_start_town"] = int(counts.get("player_start_town", 0)) + 1
			if owner == "neutral":
				counts["neutral_town"] = int(counts.get("neutral_town", 0)) + 1
	return counts

func _reveal_full_map(session: Variant, map_size: Vector2i) -> void:
	var visible := []
	for _y in range(map_size.y):
		var row := []
		for _x in range(map_size.x):
			row.append(true)
		visible.append(row)
	session.overworld["fog"] = {
		"visible_tiles": visible.duplicate(true),
		"explored_tiles": visible.duplicate(true),
		"visible_count": map_size.x * map_size.y,
		"explored_count": map_size.x * map_size.y,
		"total_tiles": map_size.x * map_size.y,
	}

func _cleanup_generated_packages(map_path: String, scenario_path: String) -> void:
	if map_path != "":
		DirAccess.remove_absolute(map_path)
	if scenario_path != "":
		DirAccess.remove_absolute(scenario_path)
	ContentService.clear_generated_scenario_drafts()

func _tile_from_payload(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Dictionary:
		return Vector2i(int(value.get("x", -1)), int(value.get("y", -1)))
	return Vector2i(-1, -1)

func _tile_payload(tile: Vector2i) -> Dictionary:
	return {"x": tile.x, "y": tile.y}

func _tile_key(tile: Vector2i) -> String:
	return "%d,%d" % [tile.x, tile.y]

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
