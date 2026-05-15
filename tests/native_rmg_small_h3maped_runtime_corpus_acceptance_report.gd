extends Node

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const OverworldRulesScript = preload("res://scripts/core/OverworldRules.gd")

const REPORT_ID := "NATIVE_RMG_SMALL_H3MAPED_RUNTIME_CORPUS_ACCEPTANCE_REPORT"
const REPORT_SCHEMA_ID := "native_rmg_small_h3maped_runtime_corpus_acceptance_report_v1"
const SEEDS := ["1", "2", "3", "4", "5"]
const PLAYER_COUNTS := [2, 3, 4]
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

	var cases := []
	var failures := []
	var aggregate := {
		"case_count": 0,
		"object_count": 0,
		"town_count": 0,
		"guard_count": 0,
		"connection_blocker_count": 0,
		"decorative_obstacle_count": 0,
		"mine_count": 0,
		"reward_count": 0,
		"road_unique_tile_count": 0,
		"required_block_tile_count": 0,
	}
	for player_count in PLAYER_COUNTS:
		for seed in SEEDS:
			var summary := _run_case(service, String(seed), int(player_count))
			cases.append(summary)
			aggregate["case_count"] = int(aggregate["case_count"]) + 1
			for key in aggregate.keys():
				if key == "case_count":
					continue
				aggregate[key] = int(aggregate.get(key, 0)) + int(summary.get(key, 0))
			if not bool(summary.get("ok", false)):
				failures.append(summary)

	if not failures.is_empty():
		_fail("Runtime corpus acceptance failed: %s" % JSON.stringify({
			"failures": failures,
			"cases": cases,
			"aggregate": aggregate,
		}))
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"schema_id": REPORT_SCHEMA_ID,
		"ok": true,
		"case_count": cases.size(),
		"player_counts": PLAYER_COUNTS,
		"seeds": SEEDS,
		"aggregate": aggregate,
		"cases": cases,
		"acceptance_scope": "strict_small_land_disk_package_runtime_pathing_corpus_without_mode_expansion",
		"remaining_gap": "This validates runtime acceptance across supported Small land seeds/player counts. Production readiness is scoped only to strict Small 36x36 one-level land; water, underground, larger sizes, and broader templates remain blocked.",
	})])
	get_tree().quit(0)

func _run_case(service: Variant, seed: String, player_count: int) -> Dictionary:
	var case_id := "small_land_p%d_seed_%s" % [player_count, seed]
	ContentService.clear_generated_scenario_drafts()
	var config := ScenarioSelectRulesScript.build_random_map_player_config(
		seed,
		"",
		"",
		player_count,
		"land",
		false,
		"homm3_small"
	)
	var setup: Dictionary = ScenarioSelectRulesScript.build_random_map_skirmish_setup_with_retry(
		config,
		"normal",
		ScenarioSelectRulesScript.RANDOM_MAP_PLAYER_RETRY_POLICY
	)
	var summary := {
		"id": case_id,
		"ok": false,
		"seed": seed,
		"player_count": player_count,
		"failures": [],
	}
	var failures: Array = summary["failures"]
	var map_path := ""
	var scenario_path := ""
	if not bool(setup.get("ok", false)):
		failures.append("setup_not_ok")
	else:
		var package_startup: Dictionary = setup.get("package_startup", {}) if setup.get("package_startup", {}) is Dictionary else {}
		map_path = String(package_startup.get("map_path", ""))
		scenario_path = String(package_startup.get("scenario_path", ""))
		if map_path == "" or scenario_path == "" or not FileAccess.file_exists(map_path) or not FileAccess.file_exists(scenario_path):
			failures.append("package_files_missing")
		if not setup.get("generated_map", {}).is_empty():
			failures.append("legacy_generated_map_payload_exposed")

	var session: Variant = null
	var map_document: Variant = null
	var scenario_document: Variant = null
	if failures.is_empty():
		session = ScenarioSelectRulesScript.start_random_map_skirmish_session_from_setup(setup)
		if session == null or String(session.scenario_id) == "":
			failures.append("session_start_failed")
		else:
			var boundary: Dictionary = session.flags.get("generated_random_map_boundary", {}) if session.flags.get("generated_random_map_boundary", {}) is Dictionary else {}
			if String(boundary.get("adoption_path", "")) != "native_rmg_generated_package_saved_loaded_from_disk":
				failures.append("session_not_loaded_from_disk_package")
		var loaded_map: Dictionary = service.load_map_package(map_path)
		var loaded_scenario: Dictionary = service.load_scenario_package(scenario_path)
		if not bool(loaded_map.get("ok", false)) or not bool(loaded_scenario.get("ok", false)):
			failures.append("independent_package_load_failed")
		else:
			map_document = loaded_map.get("map_document", null)
			scenario_document = loaded_scenario.get("scenario_document", null)
			if map_document == null or scenario_document == null:
				failures.append("loaded_documents_missing")

	var package_summary := {}
	var runtime_summary := {}
	var pathing_summary := {}
	var reachable_road := {}
	if failures.is_empty():
		package_summary = _package_summary(map_document, scenario_document)
		runtime_summary = _runtime_summary(session)
		pathing_summary = _runtime_pathing_mask_summary(session, map_document)
		reachable_road = _reachable_road_summary(session, _road_tiles_from_document(map_document))
		_validate_case_contract(package_summary, runtime_summary, pathing_summary, reachable_road, player_count, failures)

	_cleanup_generated_packages(map_path, scenario_path)

	summary["ok"] = failures.is_empty()
	summary["source_template_id"] = String(package_summary.get("source_template_id", ""))
	summary["source_template_authority"] = String(package_summary.get("source_template_authority", ""))
	summary["object_count"] = int(package_summary.get("object_count", 0))
	summary["town_count"] = int(package_summary.get("town_count", 0))
	summary["guard_count"] = int(package_summary.get("guard_count", 0))
	summary["connection_blocker_count"] = int(package_summary.get("connection_blocker_count", 0))
	summary["decorative_obstacle_count"] = int(package_summary.get("decorative_obstacle_count", 0))
	summary["mine_count"] = int(package_summary.get("mine_count", 0))
	summary["reward_count"] = int(package_summary.get("reward_count", 0))
	summary["road_unique_tile_count"] = int(package_summary.get("road_unique_tile_count", 0))
	summary["required_block_tile_count"] = int(pathing_summary.get("required_block_tile_count", 0))
	summary["reachable_road_steps"] = int(reachable_road.get("reachable_steps", 0))
	summary["runtime_unblocked_required_tile_count"] = int(pathing_summary.get("runtime_unblocked_required_tile_count", -1))
	if not failures.is_empty():
		summary["reachable_road"] = reachable_road
		summary["pathing_summary"] = {
			"blocked_non_actionable_visit_tile_count": int(pathing_summary.get("blocked_non_actionable_visit_tile_count", 0)),
			"blocked_non_actionable_visit_tiles": pathing_summary.get("blocked_non_actionable_visit_tiles", []),
			"runtime_unblocked_required_tile_count": int(pathing_summary.get("runtime_unblocked_required_tile_count", 0)),
		}
	return summary

func _validate_case_contract(
	package_summary: Dictionary,
	runtime_summary: Dictionary,
	pathing_summary: Dictionary,
	reachable_road: Dictionary,
	player_count: int,
	failures: Array
) -> void:
	if String(package_summary.get("source_template_authority", "")) != "h3maped_exe_rng" \
			or not String(package_summary.get("source_template_id", "")).begins_with("h3maped_template_"):
		failures.append("source_template_authority_not_h3maped")
	if int(package_summary.get("width", 0)) != 36 or int(package_summary.get("height", 0)) != 36 or int(package_summary.get("level_count", 0)) != 1:
		failures.append("dimension_scope_drifted")
	if not bool(package_summary.get("production_ready", false)) \
			or String(package_summary.get("production_ready_scope", "")) != "strict_small_36x36_one_level_land_only":
		failures.append("production_ready_scope_missing")
	if int(package_summary.get("player_slot_count", 0)) != player_count:
		failures.append("player_slot_count_mismatch")
	if int(package_summary.get("town_count", 0)) != player_count \
			or int(package_summary.get("player_start_town_count", 0)) != player_count \
			or int(package_summary.get("neutral_town_count", -1)) != 0:
		failures.append("owned_start_town_contract_mismatch")
	if int(runtime_summary.get("town_count", 0)) != int(package_summary.get("town_count", 0)) \
			or int(runtime_summary.get("start_slot_town_count", 0)) != player_count:
		failures.append("runtime_town_contract_mismatch")
	if int(package_summary.get("road_unique_tile_count", 0)) <= 0 \
			or int(package_summary.get("road_unique_tile_count", 0)) != int(runtime_summary.get("road_unique_tile_count", 0)):
		failures.append("road_tiles_missing_or_runtime_mismatch")
	if int(package_summary.get("guard_count", 0)) <= 0 \
			or int(runtime_summary.get("guard_count", 0)) != int(package_summary.get("guard_count", 0)):
		failures.append("guard_count_missing_or_runtime_mismatch")
	if int(package_summary.get("connection_blocker_count", 0)) <= 0 \
			or int(runtime_summary.get("connection_blocker_count", 0)) != int(package_summary.get("connection_blocker_count", 0)):
		failures.append("connection_blocker_missing_or_runtime_mismatch")
	if int(package_summary.get("mine_count", 0)) <= 0 \
			or int(runtime_summary.get("resource_node_count", 0)) < int(package_summary.get("mine_count", 0)):
		failures.append("mines_missing_or_runtime_resource_mismatch")
	if int(package_summary.get("reward_count", 0)) <= 0:
		failures.append("rewards_missing")
	if int(pathing_summary.get("required_block_tile_count", 0)) <= 0 \
			or int(pathing_summary.get("runtime_unblocked_required_tile_count", 0)) != 0 \
			or int(pathing_summary.get("blocked_non_actionable_visit_tile_count", 0)) != 0:
		failures.append("package_masks_do_not_match_runtime_pathing")
	if not bool(reachable_road.get("ok", false)) \
			or int(reachable_road.get("path_tile_count", 0)) <= 1 \
			or int(reachable_road.get("reachable_steps", 0)) <= 0:
		failures.append("no_reachable_package_road_from_start")

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
		"production_ready_scope": String(metadata.get("production_ready_scope", "")),
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

func _unreachable_road_diagnostic(session: Variant, start: Vector2i, map_size: Vector2i, road_tiles: Dictionary) -> Dictionary:
	var nearest_distance := 999999
	var nearest_tile := Vector2i(-1, -1)
	var blocked_roads := 0
	var sample_roads := []
	for key in road_tiles.keys():
		var road_tile: Vector2i = road_tiles[key]
		if OverworldRulesScript.tile_is_blocked(session, road_tile.x, road_tile.y):
			blocked_roads += 1
		var distance: int = abs(road_tile.x - start.x) + abs(road_tile.y - start.y)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_tile = road_tile
		if sample_roads.size() < 12:
			sample_roads.append({
				"tile": _tile_payload(road_tile),
				"blocked": OverworldRulesScript.tile_is_blocked(session, road_tile.x, road_tile.y),
				"interaction": OverworldRulesScript.tile_has_route_interaction(session, road_tile.x, road_tile.y),
			})
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
		})
	return {
		"ok": false,
		"start_tile": _tile_payload(start),
		"start_blocked": OverworldRulesScript.tile_is_blocked(session, start.x, start.y),
		"start_interaction": OverworldRulesScript.tile_has_route_interaction(session, start.x, start.y),
		"road_unique_tile_count": road_tiles.size(),
		"blocked_road_tile_count": blocked_roads,
		"nearest_road_tile": _tile_payload(nearest_tile),
		"nearest_road_manhattan": nearest_distance,
		"neighbors": neighbor_payloads,
		"sample_road_tiles": sample_roads,
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
