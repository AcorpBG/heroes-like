extends Node

const ScenarioSelectRules = preload("res://scripts/core/ScenarioSelectRules.gd")

const REPORT_ID := "RMG_SMALL_MANUAL_INSPECTION_EXPORT"
const MANIFEST_PATH := ".artifacts/rmg_small_manual_inspection_manifest.json"
const SUMMARY_PATH := ".artifacts/rmg_small_manual_inspection_summary.md"
const CASES := [
	{"id": "strict_small_2p_seed_1", "seed": "1", "player_count": 2},
	{"id": "strict_small_3p_seed_2", "seed": "2", "player_count": 3},
	{"id": "strict_small_4p_seed_3", "seed": "3", "player_count": 4},
]

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var records := []
	var failed := []
	for case in CASES:
		var record := _export_case(case)
		records.append(record)
		if not bool(record.get("ok", false)):
			failed.append(record)
	var index_check := _verify_maps_folder_index(records)
	if not bool(index_check.get("ok", false)):
		failed.append(index_check)
	var editor_check := await _verify_editor_load(records)
	if not bool(editor_check.get("ok", false)):
		failed.append(editor_check)
	var manifest := {
		"schema_id": "strict_small_land_manual_inspection_export_v1",
		"ok": failed.is_empty(),
		"case_count": records.size(),
		"failed_count": failed.size(),
		"scope": "strict_small_36x36_one_level_land_only",
		"unsupported_modes": ["water", "underground", "medium_large_xl", "broader_template_families"],
		"maps_folder_index": index_check,
		"editor_load": editor_check,
		"cases": records,
		"failed_cases": failed,
	}
	_write_manifest(manifest)
	_write_markdown_summary(manifest)
	print("%s %s" % [REPORT_ID, JSON.stringify(_manifest_print_summary(manifest))])
	get_tree().quit(0 if failed.is_empty() else 1)

func _export_case(case: Dictionary) -> Dictionary:
	var case_id := String(case.get("id", ""))
	var package_stem := "manual-%s" % case_id
	var config := ScenarioSelectRules.build_random_map_player_config(
		String(case.get("seed", "")),
		"",
		"",
		int(case.get("player_count", 0)),
		"land",
		false,
		"homm3_small"
	)
	if not ClassDB.class_exists("MapPackageService"):
		return {"id": case_id, "ok": false, "error_code": "missing_map_package_service"}
	var service: Variant = ClassDB.instantiate("MapPackageService")
	var generated: Dictionary = service.generate_random_map(config, {"startup_path": "manual_inspection_%s" % case_id})
	var record := {
		"id": case_id,
		"ok": false,
		"seed": String(case.get("seed", "")),
		"player_count": int(case.get("player_count", 0)),
		"package_stem": package_stem,
		"package_id": ScenarioSelectRules.maps_folder_package_id_for_stem(package_stem),
		"production_ready": bool(generated.get("production_ready", false)),
		"production_ready_scope": String(generated.get("production_ready_scope", "")),
		"full_generation_status": String(generated.get("full_generation_status", "")),
		"generation_status": String(generated.get("generation_status", "")),
		"validation_status": String(generated.get("validation_status", "")),
	}
	if not bool(generated.get("ok", false)):
		record["error_code"] = "generate_random_map_failed"
		record["generation_result"] = generated
		return record
	var adoption: Dictionary = service.convert_generated_payload(generated, {
		"feature_gate": "manual_strict_small_land_inspection",
		"session_save_version": 9,
		"scenario_id": package_stem,
	})
	if not bool(adoption.get("ok", false)):
		record["error_code"] = "convert_generated_payload_failed"
		record["adoption_result"] = adoption
		return record
	var map_document: Variant = adoption.get("map_document", null)
	var scenario_document: Variant = adoption.get("scenario_document", null)
	if map_document == null or scenario_document == null:
		record["error_code"] = "missing_converted_documents"
		return record
	var map_path := "res://maps/%s.amap" % package_stem
	var scenario_path := "res://maps/%s.ascenario" % package_stem
	var map_save: Dictionary = service.save_map_package(map_document, map_path, {"path_policy": "manual_strict_small_land_inspection", "return_package": false})
	if not bool(map_save.get("ok", false)):
		record["error_code"] = "save_map_package_failed"
		record["map_save"] = map_save
		return record
	var map_load: Dictionary = service.load_map_package(map_path)
	if not bool(map_load.get("ok", false)):
		record["error_code"] = "load_map_package_failed"
		record["map_load"] = map_load
		return record
	var map_ref: Dictionary = map_load.get("map_ref", {}) if map_load.get("map_ref", {}) is Dictionary else {}
	if scenario_document.has_method("configure") and not map_ref.is_empty():
		scenario_document.configure({
			"scenario_id": scenario_document.get_scenario_id(),
			"scenario_hash": scenario_document.get_scenario_hash(),
			"map_ref": map_ref,
			"selection": scenario_document.get_selection(),
			"player_slots": scenario_document.get_player_slots(),
			"objectives": scenario_document.get_objectives(),
			"script_hooks": scenario_document.get_script_hooks(),
			"enemy_factions": scenario_document.get_enemy_factions(),
			"start_contract": scenario_document.get_start_contract(),
		})
	var scenario_save: Dictionary = service.save_scenario_package(scenario_document, scenario_path, {"path_policy": "manual_strict_small_land_inspection", "return_package": false})
	if not bool(scenario_save.get("ok", false)):
		record["error_code"] = "save_scenario_package_failed"
		record["scenario_save"] = scenario_save
		return record
	var scenario_load: Dictionary = service.load_scenario_package(scenario_path)
	if not bool(scenario_load.get("ok", false)):
		record["error_code"] = "load_scenario_package_failed"
		record["scenario_load"] = scenario_load
		return record
	var loaded_map_document: Variant = map_load.get("map_document", map_document)
	var loaded_scenario_document: Variant = scenario_load.get("scenario_document", scenario_document)
	record["map_path"] = map_path
	record["scenario_path"] = scenario_path
	record["map_exists"] = FileAccess.file_exists(map_path)
	record["scenario_exists"] = FileAccess.file_exists(scenario_path)
	record["map_package_hash"] = String(map_save.get("package_hash", ""))
	record["scenario_package_hash"] = String(scenario_save.get("package_hash", ""))
	record["inspection_summary"] = _inspection_summary(loaded_map_document, loaded_scenario_document)
	var summary_errors := _inspection_summary_errors(record.get("inspection_summary", {}), int(case.get("player_count", 0)))
	if not summary_errors.is_empty():
		record["error_code"] = "inspection_summary_incomplete"
		record["inspection_summary_errors"] = summary_errors
		return record
	if not bool(record.get("map_exists", false)) or not bool(record.get("scenario_exists", false)):
		record["error_code"] = "saved_files_missing"
		return record
	record["ok"] = true
	return record

func _verify_maps_folder_index(records: Array) -> Dictionary:
	var index: Dictionary = ScenarioSelectRules.maps_folder_package_index({
		"include_non_launchable_generated_packages": true,
		"consumer": "manual_strict_small_land_inspection",
	})
	var entries: Array = index.get("entries", []) if index.get("entries", []) is Array else []
	var expected := []
	var found := []
	var missing := []
	for record in records:
		if not (record is Dictionary) or not bool(record.get("ok", false)):
			continue
		var package_id := String(record.get("package_id", ""))
		if package_id == "":
			continue
		expected.append(package_id)
		if _index_has_package(entries, package_id):
			found.append(package_id)
		else:
			missing.append(package_id)
	return {
		"id": "maps_folder_manual_inspection_index",
		"ok": bool(index.get("ok", false)) and missing.is_empty(),
		"index_ok": bool(index.get("ok", false)),
		"expected_count": expected.size(),
		"found_count": found.size(),
		"missing_count": missing.size(),
		"expected_package_ids": expected,
		"found_package_ids": found,
		"missing_package_ids": missing,
		"entry_count": entries.size(),
	}

func _index_has_package(entries: Array, package_id: String) -> bool:
	for entry in entries:
		if entry is Dictionary and String(entry.get("package_id", entry.get("scenario_id", ""))) == package_id:
			return true
	return false

func _inspection_summary(map_document: Variant, scenario_document: Variant) -> Dictionary:
	if map_document == null:
		return {"ok": false, "error_code": "missing_map_document"}
	var metadata: Dictionary = map_document.get_metadata() if map_document.has_method("get_metadata") else {}
	var component_counts: Dictionary = metadata.get("component_counts", {}) if metadata.get("component_counts", {}) is Dictionary else {}
	var terrain_layers: Dictionary = map_document.get_terrain_layers() if map_document.has_method("get_terrain_layers") else {}
	var roads: Array = terrain_layers.get("roads", []) if terrain_layers.get("roads", []) is Array else []
	var route_graph: Dictionary = map_document.get_route_graph() if map_document.has_method("get_route_graph") else {}
	var counts := _object_counts(map_document)
	var start_contract: Dictionary = scenario_document.get_start_contract() if scenario_document != null and scenario_document.has_method("get_start_contract") else {}
	var player_slots: Array = scenario_document.get_player_slots() if scenario_document != null and scenario_document.has_method("get_player_slots") else []
	var road_unique_tiles := _road_unique_tiles(roads)
	var start_town_summary := _start_town_summary(start_contract)
	var route_gate_summary := _route_gate_summary(route_graph)
	var topology_preview := _topology_preview(map_document, start_contract)
	return {
		"ok": true,
		"width": int(map_document.get_width()) if map_document.has_method("get_width") else 0,
		"height": int(map_document.get_height()) if map_document.has_method("get_height") else 0,
		"level_count": int(map_document.get_level_count()) if map_document.has_method("get_level_count") else 0,
		"map_id": String(map_document.get_map_id()) if map_document.has_method("get_map_id") else "",
		"map_hash": String(map_document.get_map_hash()) if map_document.has_method("get_map_hash") else "",
		"scenario_id": String(scenario_document.get_scenario_id()) if scenario_document != null and scenario_document.has_method("get_scenario_id") else "",
		"source_template_id": String(metadata.get("source_template_id", "")),
		"source_template_authority": String(metadata.get("source_template_authority", "")),
		"production_ready": bool(metadata.get("production_ready", false)),
		"production_ready_scope": String(metadata.get("production_ready_scope", "")),
		"zone_count": int(component_counts.get("zone_count", 0)),
		"route_link_count": int(route_graph.get("link_count", 0)),
		"guarded_route_link_count": int(route_graph.get("guarded_link_count", 0)),
		"road_record_count": roads.size(),
		"road_unique_tile_count": road_unique_tiles.size(),
		"source_road_cell_count": int(component_counts.get("road_cell_count", 0)),
		"road_segment_cell_count": int(component_counts.get("road_segment_cell_count", 0)),
		"object_count": int(map_document.get_object_count()) if map_document.has_method("get_object_count") else 0,
		"town_count": int(counts.get("town", 0)),
		"player_owned_town_count": int(counts.get("player_owned_town", 0)),
		"human_owned_town_count": int(counts.get("human_owned_town", 0)),
		"computer_owned_town_count": int(counts.get("computer_owned_town", 0)),
		"player_start_town_count": int(counts.get("player_start_town", 0)),
		"neutral_town_count": int(counts.get("neutral_town", 0)),
		"guard_count": int(counts.get("guard", 0)),
		"connection_blocker_count": int(counts.get("connection_blocker", 0)),
		"decorative_obstacle_count": int(counts.get("decorative_obstacle", 0)),
		"mine_count": int(counts.get("mine", 0)),
		"reward_count": int(counts.get("reward_reference", 0)),
		"artifact_count": int(counts.get("artifact", 0)),
		"artifact_reward_proxy_count": int(counts.get("artifact_reward_proxy", 0)),
		"non_artifact_reward_count": int(counts.get("reward_reference", 0)) - int(counts.get("artifact_reward_proxy", 0)),
		"player_slot_count": player_slots.size(),
		"start_count": int(start_contract.get("start_count", 0)),
		"start_town_contract_count": int(start_contract.get("start_town_count", 0)),
		"town_start_summary": start_town_summary,
		"route_gate_summary": route_gate_summary,
		"topology_preview": topology_preview,
		"start_contract": start_contract,
		"object_counts_by_kind": counts,
	}

func _object_counts(map_document: Variant) -> Dictionary:
	var counts := {}
	if map_document == null or not map_document.has_method("get_object_count") or not map_document.has_method("get_object_by_index"):
		return counts
	for index in range(int(map_document.get_object_count())):
		var object: Dictionary = map_document.get_object_by_index(index)
		var kind := String(object.get("kind", object.get("native_record_kind", object.get("category_id", "object"))))
		if kind == "town":
			var owner_slot := int(object.get("owner_slot", object.get("player_slot", 0)))
			var owner := String(object.get("owner", ""))
			if owner_slot > 0:
				counts["player_owned_town"] = int(counts.get("player_owned_town", 0)) + 1
			if owner == "player":
				counts["human_owned_town"] = int(counts.get("human_owned_town", 0)) + 1
			elif owner == "enemy":
				counts["computer_owned_town"] = int(counts.get("computer_owned_town", 0)) + 1
			else:
				counts["neutral_town"] = int(counts.get("neutral_town", 0)) + 1
			if String(object.get("record_type", "")) == "player_start_town":
				counts["player_start_town"] = int(counts.get("player_start_town", 0)) + 1
		elif kind == "reward_reference" and String(object.get("native_proxy_category", "")) == "artifact":
			counts["artifact_reward_proxy"] = int(counts.get("artifact_reward_proxy", 0)) + 1
		counts[kind] = int(counts.get(kind, 0)) + 1
	return counts

func _road_unique_tiles(roads: Array) -> Dictionary:
	var tiles := {}
	for road in roads:
		if not (road is Dictionary):
			continue
		var cells: Array = road.get("cells", []) if road.get("cells", []) is Array else []
		for cell in cells:
			if not (cell is Dictionary):
				continue
			var key := "%d:%d:%d" % [int(cell.get("level", 0)), int(cell.get("x", 0)), int(cell.get("y", 0))]
			tiles[key] = true
	return tiles

func _start_town_summary(start_contract: Dictionary) -> Array:
	var summaries := []
	var start_towns: Array = start_contract.get("player_start_towns", []) if start_contract.get("player_start_towns", []) is Array else []
	for town in start_towns:
		if not (town is Dictionary):
			continue
		var hero_start: Dictionary = town.get("hero_start_tile", town.get("runtime_start_tile", {})) if town.get("hero_start_tile", town.get("runtime_start_tile", {})) is Dictionary else {}
		summaries.append({
			"placement_id": String(town.get("placement_id", "")),
			"town_id": String(town.get("town_id", town.get("object_id", ""))),
			"owner": String(town.get("owner", "")),
			"owner_slot": int(town.get("owner_slot", 0)),
			"player_slot": int(town.get("player_slot", 0)),
			"player_type": String(town.get("player_type", "")),
			"zone_id": int(town.get("zone_id", 0)),
			"runtime_zone_index": int(town.get("runtime_zone_index", -1)),
			"town_tile": _compact_tile(town),
			"visit_tile": _compact_tile(town.get("visit_tile", town.get("primary_tile", {}))),
			"hero_start_tile": _compact_tile(hero_start),
			"runtime_start_reachable_road_steps": int(town.get("runtime_start_reachable_road_steps", hero_start.get("selection_package_road_reachable_steps", 0))),
			"runtime_start_selection_source": String(town.get("runtime_start_selection_source", hero_start.get("selection_source", ""))),
			"selection_adjacent_unblocked_package_road": bool(hero_start.get("selection_adjacent_unblocked_package_road", false)),
			"selection_removed_removable_start_block_mask": bool(hero_start.get("selection_removed_removable_start_block_mask", false)),
			"package_body_tile_count": int(town.get("package_body_tile_count", 0)),
			"package_visit_tile_count": int(town.get("package_visit_tile_count", 0)),
			"package_block_tile_count": int(town.get("package_block_tile_count", 0)),
		})
	return summaries

func _route_gate_summary(route_graph: Dictionary) -> Dictionary:
	var links: Array = route_graph.get("links", []) if route_graph.get("links", []) is Array else []
	var edges: Array = route_graph.get("edges", []) if route_graph.get("edges", []) is Array else []
	var guarded_links := []
	var unguarded_links := []
	for link in links:
		if not (link is Dictionary):
			continue
		var summary := {
			"id": String(link.get("id", "")),
			"guarded": bool(link.get("guarded", false)),
			"runtime_zone_a": int(link.get("runtime_zone_a", -1)),
			"runtime_zone_b": int(link.get("runtime_zone_b", -1)),
			"raw_guard_value": int(link.get("raw_guard_value", 0)),
			"normal_guard_scaled_value": int(link.get("normal_guard_scaled_value", 0)),
			"geometry_success_helper": String(link.get("geometry_success_helper", "")),
		}
		if bool(link.get("guarded", false)):
			guarded_links.append(summary)
		else:
			unguarded_links.append(summary)
	var road_edges := []
	for edge in edges:
		if not (edge is Dictionary):
			continue
		road_edges.append({
			"id": String(edge.get("id", "")),
			"from_node_id": String(edge.get("from_node_id", "")),
			"to_node_id": String(edge.get("to_node_id", "")),
			"cell_count": int(edge.get("cell_count", 0)),
			"path_found": bool(edge.get("path_found", false)),
			"road_type_id": String(edge.get("road_type_id", "")),
			"road_segment_id": String(edge.get("road_segment_id", "")),
		})
	return {
		"link_count": links.size(),
		"guarded_link_count": guarded_links.size(),
		"unguarded_link_count": unguarded_links.size(),
		"edge_count": edges.size(),
		"guarded_links": guarded_links,
		"unguarded_links": unguarded_links,
		"road_edges": road_edges,
	}

func _topology_preview(map_document: Variant, start_contract: Dictionary) -> Dictionary:
	if map_document == null:
		return {"ok": false, "error_code": "missing_map_document"}
	if not map_document.has_method("get_width") or not map_document.has_method("get_height"):
		return {"ok": false, "error_code": "map_document_missing_dimensions"}
	var width := int(map_document.get_width())
	var height := int(map_document.get_height())
	var levels := int(map_document.get_level_count()) if map_document.has_method("get_level_count") else 1
	if width <= 0 or height <= 0 or levels <= 0:
		return {"ok": false, "error_code": "invalid_map_dimensions", "width": width, "height": height, "level_count": levels}
	var terrain_layers: Dictionary = map_document.get_terrain_layers() if map_document.has_method("get_terrain_layers") else {}
	var terrain_codes: PackedInt32Array = map_document.get_tile_layer_u16("terrain", 0) if map_document.has_method("get_tile_layer_u16") else PackedInt32Array()
	var terrain_ids: Variant = terrain_layers.get("terrain_id_by_code", [])
	var grid := []
	var priority := []
	for y in range(height):
		var row := []
		var priority_row := []
		for x in range(width):
			var index := y * width + x
			var code := int(terrain_codes[index]) if index >= 0 and index < terrain_codes.size() else 0
			row.append(_terrain_preview_char(_terrain_id_for_code(terrain_ids, code)))
			priority_row.append(0)
		grid.append(row)
		priority.append(priority_row)
	var roads: Array = terrain_layers.get("roads", []) if terrain_layers.get("roads", []) is Array else []
	for road in roads:
		if not (road is Dictionary):
			continue
		var cells: Array = road.get("cells", []) if road.get("cells", []) is Array else []
		for cell in cells:
			_overlay_preview_tile(grid, priority, cell, "=", 30)
	var object_count := int(map_document.get_object_count()) if map_document.has_method("get_object_count") else 0
	for index in range(object_count):
		var object: Dictionary = map_document.get_object_by_index(index)
		_overlay_object_preview(grid, priority, object)
	var start_towns: Array = start_contract.get("player_start_towns", []) if start_contract.get("player_start_towns", []) is Array else []
	for town in start_towns:
		if not (town is Dictionary):
			continue
		var hero_start: Dictionary = town.get("hero_start_tile", town.get("runtime_start_tile", {})) if town.get("hero_start_tile", town.get("runtime_start_tile", {})) is Dictionary else {}
		_overlay_preview_tile(grid, priority, hero_start, "H", 80)
	var rows := []
	for y in range(height):
		rows.append("".join(grid[y]))
	return {
		"ok": true,
		"width": width,
		"height": height,
		"level": 0,
		"legend": "H hero start, T player town, E enemy town, N neutral town, G guard, B connection blocker, X decorative obstacle, M mine, $ reward, A artifact or artifact reward proxy, = road, terrain letters are base terrain",
		"rows": rows,
	}

func _terrain_id_for_code(ids_by_code: Variant, code: int) -> String:
	if (ids_by_code is Array or ids_by_code is PackedStringArray) and code >= 0 and code < ids_by_code.size():
		return String(ids_by_code[code])
	return "grass"

func _terrain_preview_char(terrain_id: String) -> String:
	match terrain_id:
		"grass":
			return "."
		"dirt":
			return "d"
		"sand":
			return "s"
		"snow":
			return "n"
		"swamp":
			return "w"
		"rough":
			return "r"
		"subterranean":
			return "u"
		"lava":
			return "l"
		"water":
			return "~"
		"rock":
			return "^"
		_:
			return "?"

func _overlay_object_preview(grid: Array, priority: Array, object: Dictionary) -> void:
	if object.is_empty():
		return
	var kind := String(object.get("kind", object.get("native_record_kind", object.get("category_id", ""))))
	match kind:
		"town":
			var owner := String(object.get("owner", ""))
			var town_char := "N"
			if owner == "player":
				town_char = "T"
			elif owner == "enemy":
				town_char = "E"
			_overlay_preview_tile(grid, priority, object, town_char, 70)
		"guard":
			_overlay_preview_tile(grid, priority, object, "G", 60)
		"connection_blocker":
			_overlay_preview_tiles(grid, priority, object.get("package_block_tiles", []), "B", 50)
			_overlay_preview_tile(grid, priority, object, "B", 50)
		"decorative_obstacle":
			_overlay_preview_tiles(grid, priority, object.get("package_block_tiles", object.get("package_body_tiles", [])), "X", 20)
			_overlay_preview_tile(grid, priority, object, "X", 20)
		"mine":
			_overlay_preview_tile(grid, priority, object, "M", 40)
		"reward_reference":
			var reward_char := "A" if String(object.get("native_proxy_category", "")) == "artifact" else "$"
			_overlay_preview_tile(grid, priority, object, reward_char, 40)
		"artifact":
			_overlay_preview_tile(grid, priority, object, "A", 40)
		_:
			return

func _overlay_preview_tiles(grid: Array, priority: Array, tiles: Variant, label: String, label_priority: int) -> void:
	if not (tiles is Array):
		return
	for tile in tiles:
		_overlay_preview_tile(grid, priority, tile, label, label_priority)

func _overlay_preview_tile(grid: Array, priority: Array, tile: Variant, label: String, label_priority: int) -> void:
	if not (tile is Dictionary):
		return
	if int(tile.get("level", 0)) != 0:
		return
	var x := int(tile.get("x", -1))
	var y := int(tile.get("y", -1))
	if y < 0 or y >= grid.size():
		return
	var row: Array = grid[y]
	var priority_row: Array = priority[y]
	if x < 0 or x >= row.size():
		return
	if label_priority < int(priority_row[x]):
		return
	row[x] = label
	priority_row[x] = label_priority

func _inspection_summary_errors(summary: Variant, expected_player_count: int) -> Array:
	var errors := []
	if not (summary is Dictionary) or not bool(summary.get("ok", false)):
		return ["missing_or_failed_inspection_summary"]
	var start_towns: Array = summary.get("town_start_summary", []) if summary.get("town_start_summary", []) is Array else []
	var route_gates: Dictionary = summary.get("route_gate_summary", {}) if summary.get("route_gate_summary", {}) is Dictionary else {}
	var topology_preview: Dictionary = summary.get("topology_preview", {}) if summary.get("topology_preview", {}) is Dictionary else {}
	if int(summary.get("player_owned_town_count", 0)) != expected_player_count:
		errors.append("player_owned_town_count_mismatch")
	if int(summary.get("player_start_town_count", 0)) != expected_player_count:
		errors.append("player_start_town_count_mismatch")
	if int(summary.get("start_count", 0)) != expected_player_count:
		errors.append("start_count_mismatch")
	if int(summary.get("start_town_contract_count", 0)) != expected_player_count:
		errors.append("start_town_contract_count_mismatch")
	if start_towns.size() != expected_player_count:
		errors.append("town_start_summary_count_mismatch")
	if int(route_gates.get("link_count", -1)) != int(summary.get("route_link_count", -2)):
		errors.append("route_link_count_mismatch")
	if int(route_gates.get("guarded_link_count", -1)) != int(summary.get("guarded_route_link_count", -2)):
		errors.append("guarded_route_link_count_mismatch")
	if int(route_gates.get("unguarded_link_count", 0)) != 0:
		errors.append("unguarded_route_links_present")
	if int(summary.get("road_unique_tile_count", 0)) <= 0:
		errors.append("missing_unique_road_tiles")
	if int(summary.get("road_record_count", 0)) <= 0:
		errors.append("missing_road_records")
	if not bool(topology_preview.get("ok", false)):
		errors.append("missing_topology_preview")
	else:
		var preview_rows: Array = topology_preview.get("rows", []) if topology_preview.get("rows", []) is Array else []
		var expected_width := int(summary.get("width", 0))
		var expected_height := int(summary.get("height", 0))
		if int(topology_preview.get("width", 0)) != expected_width:
			errors.append("topology_preview_width_mismatch")
		if int(topology_preview.get("height", 0)) != expected_height:
			errors.append("topology_preview_height_mismatch")
		if preview_rows.size() != expected_height:
			errors.append("topology_preview_row_count_mismatch")
		for row in preview_rows:
			if String(row).length() != expected_width:
				errors.append("topology_preview_row_width_mismatch")
				break
	return errors

func _compact_tile(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return {}
	return {
		"level": int(value.get("level", 0)),
		"x": int(value.get("x", 0)),
		"y": int(value.get("y", 0)),
	}

func _verify_editor_load(records: Array) -> Dictionary:
	var shell_scene: PackedScene = load("res://scenes/editor/MapEditorShell.tscn")
	if shell_scene == null:
		return {"id": "map_editor_manual_inspection_load", "ok": false, "error_code": "missing_map_editor_shell_scene"}
	var shell = shell_scene.instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	if not shell.has_method("validation_load_maps_folder_package"):
		shell.queue_free()
		return {"id": "map_editor_manual_inspection_load", "ok": false, "error_code": "missing_validation_load_maps_folder_package"}
	var expected := []
	var loaded := []
	var failed := []
	for record in records:
		if not (record is Dictionary) or not bool(record.get("ok", false)):
			continue
		var package_id := String(record.get("package_id", ""))
		if package_id == "":
			continue
		expected.append(package_id)
		var snapshot: Dictionary = shell.call("validation_load_maps_folder_package", package_id)
		if bool(snapshot.get("ok", false)) and String(snapshot.get("editor_source_package_id", "")) == package_id:
			loaded.append({
				"package_id": package_id,
				"scenario_id": String(snapshot.get("scenario_id", "")),
				"map_path": String(snapshot.get("editor_source_map_path", "")),
				"scenario_path": String(snapshot.get("editor_source_scenario_path", "")),
			})
		else:
			failed.append({
				"package_id": package_id,
				"snapshot": snapshot,
			})
	shell.queue_free()
	return {
		"id": "map_editor_manual_inspection_load",
		"ok": failed.is_empty(),
		"expected_count": expected.size(),
		"loaded_count": loaded.size(),
		"failed_count": failed.size(),
		"expected_package_ids": expected,
		"loaded_packages": loaded,
		"failed_packages": failed,
	}

func _manifest_print_summary(manifest: Dictionary) -> Dictionary:
	var cases := []
	var records: Array = manifest.get("cases", []) if manifest.get("cases", []) is Array else []
	for record in records:
		if not (record is Dictionary):
			continue
		var inspection_summary: Dictionary = record.get("inspection_summary", {}) if record.get("inspection_summary", {}) is Dictionary else {}
		var compact_summary := inspection_summary.duplicate(true)
		compact_summary.erase("start_contract")
		var town_start_summary: Array = compact_summary.get("town_start_summary", []) if compact_summary.get("town_start_summary", []) is Array else []
		compact_summary["town_start_summary_count"] = town_start_summary.size()
		compact_summary.erase("town_start_summary")
		var route_gate_summary: Dictionary = compact_summary.get("route_gate_summary", {}) if compact_summary.get("route_gate_summary", {}) is Dictionary else {}
		compact_summary["route_gate_summary"] = {
			"link_count": int(route_gate_summary.get("link_count", 0)),
			"guarded_link_count": int(route_gate_summary.get("guarded_link_count", 0)),
			"unguarded_link_count": int(route_gate_summary.get("unguarded_link_count", 0)),
			"edge_count": int(route_gate_summary.get("edge_count", 0)),
		}
		cases.append({
			"id": String(record.get("id", "")),
			"ok": bool(record.get("ok", false)),
			"package_id": String(record.get("package_id", "")),
			"map_path": String(record.get("map_path", "")),
			"scenario_path": String(record.get("scenario_path", "")),
			"production_ready": bool(record.get("production_ready", false)),
			"production_ready_scope": String(record.get("production_ready_scope", "")),
			"inspection_summary": compact_summary,
		})
	var index: Dictionary = manifest.get("maps_folder_index", {}) if manifest.get("maps_folder_index", {}) is Dictionary else {}
	var editor_load: Dictionary = manifest.get("editor_load", {}) if manifest.get("editor_load", {}) is Dictionary else {}
	return {
		"schema_id": String(manifest.get("schema_id", "")),
		"ok": bool(manifest.get("ok", false)),
		"case_count": int(manifest.get("case_count", 0)),
		"failed_count": int(manifest.get("failed_count", 0)),
		"scope": String(manifest.get("scope", "")),
		"maps_folder_index": {
			"ok": bool(index.get("ok", false)),
			"expected_count": int(index.get("expected_count", 0)),
			"found_count": int(index.get("found_count", 0)),
			"missing_count": int(index.get("missing_count", 0)),
		},
		"editor_load": {
			"ok": bool(editor_load.get("ok", false)),
			"expected_count": int(editor_load.get("expected_count", 0)),
			"loaded_count": int(editor_load.get("loaded_count", 0)),
			"failed_count": int(editor_load.get("failed_count", 0)),
		},
		"cases": cases,
	}

func _write_manifest(manifest: Dictionary) -> void:
	var manifest_path := ProjectSettings.globalize_path(MANIFEST_PATH)
	var file := FileAccess.open(manifest_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(manifest, "\t"))
	file.close()

func _write_markdown_summary(manifest: Dictionary) -> void:
	var summary_path := ProjectSettings.globalize_path(SUMMARY_PATH)
	var dir := DirAccess.open(ProjectSettings.globalize_path("."))
	if dir != null:
		dir.make_dir_recursive(ProjectSettings.globalize_path(".artifacts"))
	var lines := []
	lines.append("# Strict Small RMG Manual Inspection Summary")
	lines.append("")
	lines.append("Scope: `%s`" % _markdown_table_escape(String(manifest.get("scope", ""))))
	lines.append("")
	lines.append("Generated package pairs: `%d`" % int(manifest.get("case_count", 0)))
	lines.append("")
	lines.append("Status: `%s`" % ("ok" if bool(manifest.get("ok", false)) else "fail"))
	lines.append("")
	lines.append("Run: `GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . tools/rmg_small_manual_inspection_export.tscn`")
	lines.append("")
	lines.append("Do not commit `maps/*.amap` or `maps/*.ascenario`.")
	lines.append("")
	lines.append("## Manual Review Gate")
	lines.append("")
	lines.append("Open these package ids in the built-in map picker/editor:")
	lines.append("")
	for record in manifest.get("cases", []) if manifest.get("cases", []) is Array else []:
		if record is Dictionary:
			lines.append("- `%s`" % String(record.get("package_id", "")))
	lines.append("")
	lines.append("Accept the strict Small-land baseline only if all reviewed packages satisfy:")
	lines.append("")
	lines.append("- each player starts at an owned player town")
	lines.append("- zones read as separate playable regions, not one blended area")
	lines.append("- roads read as meaningful route infrastructure between towns/zones")
	lines.append("- blockers, decorative obstacles, and guards physically gate zone links")
	lines.append("- mines, rewards, and artifact-category rewards are reachable through intended guarded routes")
	lines.append("- no free unguarded route bypasses a protected zone/town link")
	lines.append("")
	lines.append("Report defects with package id, seed/player count, visible symptom, and the closest tile/region if possible.")
	lines.append("")
	lines.append("## Case Summary")
	lines.append("")
	lines.append("| Case | Package | Template | Zones | Player towns | Neutral towns | Links | Guarded | Roads | Road tiles | Guards | Blockers | Obstacles | Mines | Rewards | Artifact proxies | Artifact objects | Editor |")
	lines.append("| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |")
	var records: Array = manifest.get("cases", []) if manifest.get("cases", []) is Array else []
	for record in records:
		if not (record is Dictionary):
			continue
		var summary: Dictionary = record.get("inspection_summary", {}) if record.get("inspection_summary", {}) is Dictionary else {}
		var package_id := String(record.get("package_id", ""))
		lines.append("| %s | %s | %s | %d | %d | %d | %d | %d | %d | %d | %d | %d | %d | %d | %d | %d | %d | %s |" % [
			_markdown_table_escape(String(record.get("id", ""))),
			_markdown_table_escape(package_id),
			_markdown_table_escape(String(summary.get("source_template_id", ""))),
			int(summary.get("zone_count", 0)),
			int(summary.get("player_owned_town_count", 0)),
			int(summary.get("neutral_town_count", 0)),
			int(summary.get("route_link_count", 0)),
			int(summary.get("guarded_route_link_count", 0)),
			int(summary.get("road_record_count", 0)),
			int(summary.get("road_unique_tile_count", 0)),
			int(summary.get("guard_count", 0)),
			int(summary.get("connection_blocker_count", 0)),
			int(summary.get("decorative_obstacle_count", 0)),
			int(summary.get("mine_count", 0)),
			int(summary.get("reward_count", 0)),
			int(summary.get("artifact_reward_proxy_count", 0)),
			int(summary.get("artifact_count", 0)),
			"ok" if _editor_load_ok_for_package(manifest, package_id) else "fail",
		])
	lines.append("")
	for record in records:
		if not (record is Dictionary):
			continue
		_append_case_markdown(lines, manifest, record)
	var file := FileAccess.open(summary_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string("\n".join(lines))
	file.close()

func _append_case_markdown(lines: Array, manifest: Dictionary, record: Dictionary) -> void:
	var summary: Dictionary = record.get("inspection_summary", {}) if record.get("inspection_summary", {}) is Dictionary else {}
	var route_gates: Dictionary = summary.get("route_gate_summary", {}) if summary.get("route_gate_summary", {}) is Dictionary else {}
	var package_id := String(record.get("package_id", ""))
	lines.append("## %s" % _markdown_table_escape(String(record.get("id", ""))))
	lines.append("")
	lines.append("- Package id: `%s`" % _markdown_table_escape(package_id))
	lines.append("- Map path: `%s`" % _markdown_table_escape(String(record.get("map_path", ""))))
	lines.append("- Scenario path: `%s`" % _markdown_table_escape(String(record.get("scenario_path", ""))))
	lines.append("- Map hash: `%s`" % _markdown_table_escape(String(summary.get("map_hash", ""))))
	lines.append("- Scenario id: `%s`" % _markdown_table_escape(String(summary.get("scenario_id", ""))))
	lines.append("- Production scope: `%s`" % _markdown_table_escape(String(summary.get("production_ready_scope", ""))))
	lines.append("- Editor load: `%s`" % ("ok" if _editor_load_ok_for_package(manifest, package_id) else "fail"))
	lines.append("- Rewards: `%d` total, `%d` artifact proxies, `%d` literal artifact objects" % [
		int(summary.get("reward_count", 0)),
		int(summary.get("artifact_reward_proxy_count", 0)),
		int(summary.get("artifact_count", 0)),
	])
	lines.append("")
	var topology_preview: Dictionary = summary.get("topology_preview", {}) if summary.get("topology_preview", {}) is Dictionary else {}
	if bool(topology_preview.get("ok", false)):
		lines.append("### Topology Preview")
		lines.append("")
		lines.append("`%s`" % _markdown_table_escape(String(topology_preview.get("legend", ""))))
		lines.append("")
		lines.append("```text")
		var rows: Array = topology_preview.get("rows", []) if topology_preview.get("rows", []) is Array else []
		for row in rows:
			lines.append(String(row))
		lines.append("```")
		lines.append("")
	lines.append("### Town Starts")
	lines.append("")
	lines.append("| Slot | Owner | Town | Town tile | Hero start | Zone | Road steps | Cleared start obstacle |")
	lines.append("| ---: | --- | --- | --- | --- | ---: | ---: | --- |")
	var start_towns: Array = summary.get("town_start_summary", []) if summary.get("town_start_summary", []) is Array else []
	for town in start_towns:
		if not (town is Dictionary):
			continue
		lines.append("| %d | %s | %s | %s | %s | %d | %d | %s |" % [
			int(town.get("player_slot", town.get("owner_slot", 0))),
			_markdown_table_escape(String(town.get("owner", ""))),
			_markdown_table_escape(String(town.get("town_id", town.get("placement_id", "")))),
			_tile_text(town.get("town_tile", {})),
			_tile_text(town.get("hero_start_tile", {})),
			int(town.get("runtime_zone_index", town.get("zone_id", -1))),
			int(town.get("runtime_start_reachable_road_steps", 0)),
			"yes" if bool(town.get("selection_removed_removable_start_block_mask", false)) else "no",
		])
	lines.append("")
	lines.append("### Route Gates")
	lines.append("")
	lines.append("Unguarded links: `%d`" % int(route_gates.get("unguarded_link_count", 0)))
	lines.append("")
	lines.append("| Link | Zone A | Zone B | Guard value | Helper |")
	lines.append("| --- | ---: | ---: | ---: | --- |")
	var guarded_links: Array = route_gates.get("guarded_links", []) if route_gates.get("guarded_links", []) is Array else []
	for link in guarded_links:
		if not (link is Dictionary):
			continue
		lines.append("| %s | %d | %d | %d | %s |" % [
			_markdown_table_escape(String(link.get("id", ""))),
			int(link.get("runtime_zone_a", -1)),
			int(link.get("runtime_zone_b", -1)),
			int(link.get("normal_guard_scaled_value", link.get("raw_guard_value", 0))),
			_markdown_table_escape(String(link.get("geometry_success_helper", ""))),
		])
	var unguarded_links: Array = route_gates.get("unguarded_links", []) if route_gates.get("unguarded_links", []) is Array else []
	if not unguarded_links.is_empty():
		lines.append("")
		lines.append("### Unguarded Links")
		lines.append("")
		lines.append("| Link | Zone A | Zone B | Guard value | Helper |")
		lines.append("| --- | ---: | ---: | ---: | --- |")
		for link in unguarded_links:
			if not (link is Dictionary):
				continue
			lines.append("| %s | %d | %d | %d | %s |" % [
				_markdown_table_escape(String(link.get("id", ""))),
				int(link.get("runtime_zone_a", -1)),
				int(link.get("runtime_zone_b", -1)),
				int(link.get("normal_guard_scaled_value", link.get("raw_guard_value", 0))),
				_markdown_table_escape(String(link.get("geometry_success_helper", ""))),
			])
	lines.append("")
	lines.append("### Road Edges")
	lines.append("")
	lines.append("| Road edge | From | To | Cells | Segment |")
	lines.append("| --- | --- | --- | ---: | --- |")
	var road_edges: Array = route_gates.get("road_edges", []) if route_gates.get("road_edges", []) is Array else []
	for edge in road_edges:
		if not (edge is Dictionary):
			continue
		lines.append("| %s | %s | %s | %d | %s |" % [
			_markdown_table_escape(String(edge.get("id", ""))),
			_markdown_table_escape(String(edge.get("from_node_id", ""))),
			_markdown_table_escape(String(edge.get("to_node_id", ""))),
			int(edge.get("cell_count", 0)),
			_markdown_table_escape(String(edge.get("road_segment_id", ""))),
		])
	lines.append("")

func _editor_load_ok_for_package(manifest: Dictionary, package_id: String) -> bool:
	var editor_load: Dictionary = manifest.get("editor_load", {}) if manifest.get("editor_load", {}) is Dictionary else {}
	var loaded_packages: Array = editor_load.get("loaded_packages", []) if editor_load.get("loaded_packages", []) is Array else []
	for loaded in loaded_packages:
		if loaded is Dictionary and String(loaded.get("package_id", "")) == package_id:
			return true
	return false

func _tile_text(tile: Variant) -> String:
	if not (tile is Dictionary) or tile.is_empty():
		return ""
	return "%d,%d,%d" % [int(tile.get("level", 0)), int(tile.get("x", 0)), int(tile.get("y", 0))]

func _markdown_table_escape(value: Variant) -> String:
	var text := String(value)
	text = text.replace("|", "\\|")
	text = text.replace("\n", " ")
	text = text.replace("\r", " ")
	return text
