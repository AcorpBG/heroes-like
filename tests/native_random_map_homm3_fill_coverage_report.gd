extends Node

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")

const REPORT_ID := "NATIVE_RANDOM_MAP_HOMM3_FILL_COVERAGE_REPORT"
const REPORT_SCHEMA_ID := "native_random_map_homm3_fill_coverage_report_v1"

const HOMM3_RE_OBSTACLE_CSV := "/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/object-decoration-obstacles.csv"
const ATTACHED_AMAP := "/root/.openclaw/media/inbound/medium-red-grove-shore-e75d0149---6cb5cc9e-fdbe-49e7-8f4a-5e56dbf2619d.amap"

const CASES := [
	{
		"id": "small_local_frontier_spokes",
		"template_id": "frontier_spokes_v1",
		"profile_id": "frontier_spokes_profile_v1",
		"size_class_id": "homm3_small",
		"player_count": 3,
		"min_deco_blocker_coverage": 0.18,
	},
	{
		"id": "medium_translated_024",
		"template_id": "translated_rmg_template_024_v1",
		"profile_id": "translated_rmg_profile_024_v1",
		"size_class_id": "homm3_medium",
		"player_count": 4,
		"min_deco_blocker_coverage": 0.20,
	},
	{
		"id": "large_translated_042",
		"template_id": "translated_rmg_template_042_v1",
		"profile_id": "translated_rmg_profile_042_v1",
		"size_class_id": "homm3_large",
		"player_count": 4,
		"min_deco_blocker_coverage": 0.20,
	},
	{
		"id": "xl_translated_043",
		"template_id": "translated_rmg_template_043_v1",
		"profile_id": "translated_rmg_profile_043_v1",
		"size_class_id": "homm3_extra_large",
		"player_count": 8,
		"min_deco_blocker_coverage": 0.20,
	},
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
		_fail("Native GDExtension metadata did not prove native load: %s" % JSON.stringify(metadata))
		return

	var homm3_re := _homm3_re_obstacle_catalog_summary()
	if homm3_re.is_empty():
		return
	var authored := _authored_decoration_blocker_summary()
	if authored.is_empty():
		return
	var attached_package := _load_json_file(ATTACHED_AMAP)
	if attached_package.is_empty():
		_fail("Attached native amap could not be loaded from %s." % ATTACHED_AMAP)
		return
	var attached_document: Dictionary = attached_package.get("document", {}) if attached_package.get("document", {}) is Dictionary else {}
	var attached_before := _coverage_for_objects("attached_medium_red_grove_shore_before", attached_document.get("objects", []), int(attached_document.get("width", 0)), int(attached_document.get("height", 0)))
	attached_before["raw_json_bytes"] = FileAccess.get_file_as_bytes(ATTACHED_AMAP).size()
	attached_before["known_gzip_equivalent_bytes"] = 47451
	attached_before["source_note"] = "owner-attached package generated before this fill correction"

	var summaries := []
	for case_record in CASES:
		var summary := _run_generated_case(service, case_record)
		if summary.is_empty():
			return
		summaries.append(summary)

	var attached_config: Dictionary = attached_document.get("metadata", {}).get("normalized_config", {}) if attached_document.get("metadata", {}).get("normalized_config", {}) is Dictionary else {}
	var attached_after: Dictionary = {}
	if not attached_config.is_empty():
		var after_case := {
			"id": "attached_medium_red_grove_shore_after_same_config",
			"config": attached_config,
			"min_deco_blocker_coverage": 0.20,
		}
		attached_after = _run_generated_case(service, after_case)
		if attached_after.is_empty():
			return
		summaries.append(attached_after)

	if float(attached_before.get("decoration_blocker_body_coverage_ratio", 0.0)) >= 0.20:
		_fail("Attached barren package unexpectedly passed the new medium coverage floor: %s" % JSON.stringify(attached_before))
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"schema_id": REPORT_SCHEMA_ID,
		"ok": true,
		"binding_kind": metadata.get("binding_kind", ""),
		"native_extension_loaded": metadata.get("native_extension_loaded", false),
		"homm3_source_attachment": {
			"path": "/root/.openclaw/media/inbound/Untitled---cad43d4f-6faa-4059-a9db-9b37770806af.gz",
			"gzip_bytes": 12952,
			"decompressed_h3m_bytes": 61868,
			"header_size": "72x72",
		},
		"homm3_re_obstacle_catalog": homm3_re,
		"our_authored_decoration_blocker_catalog": authored,
		"attached_package_before": attached_before,
		"generated_cases": summaries,
		"thresholds": {
			"small_min_decoration_blocker_body_coverage_ratio": 0.18,
			"medium_large_xl_min_decoration_blocker_body_coverage_ratio": 0.20,
			"min_average_decoration_body_tiles": 8.0,
			"min_large_decoration_ratio": 0.90,
			"route_policy": "decorative bodies may fill aggressively but must not overlap materialized road cells; roads remain traversable corridors",
		},
		"remaining_gap": "coverage and terrain-biased original blockers are improved; exact HoMM3-re obstacle identity, art/template parity, and compact binary H3M-format parity remain incomplete",
	})])
	get_tree().quit(0)

func _run_generated_case(service: Variant, case_record: Dictionary) -> Dictionary:
	var config: Dictionary = case_record.get("config", {}) if case_record.get("config", {}) is Dictionary else {}
	if config.is_empty():
		config = ScenarioSelectRulesScript.build_random_map_player_config(
			"native-fill-coverage-%s" % String(case_record.get("id", "")),
			String(case_record.get("template_id", "")),
			String(case_record.get("profile_id", "")),
			int(case_record.get("player_count", 4)),
			"land",
			false,
			String(case_record.get("size_class_id", "homm3_medium"))
		)
	var generated: Dictionary = service.generate_random_map(config)
	if not bool(generated.get("ok", false)) or String(generated.get("validation_status", "")) != "pass":
		_fail("%s native generation failed validation: %s" % [String(case_record.get("id", "")), JSON.stringify(generated.get("validation_report", generated))])
		return {}
	var normalized: Dictionary = generated.get("normalized_config", {}) if generated.get("normalized_config", {}) is Dictionary else {}
	var width := int(normalized.get("width", 0))
	var height := int(normalized.get("height", 0))
	var coverage := _coverage_for_objects(String(case_record.get("id", "")), generated.get("object_placements", []) + generated.get("town_records", []) + generated.get("guard_records", []), width, height)
	var road := _road_summary_from_generated(generated)
	var conflicts := _road_body_conflicts(generated)
	if not conflicts.is_empty():
		_fail("%s large decoration bodies overlapped roads: %s" % [String(case_record.get("id", "")), JSON.stringify(conflicts.slice(0, 20))])
		return {}
	var min_deco := float(case_record.get("min_deco_blocker_coverage", 0.20))
	if float(coverage.get("decoration_blocker_body_coverage_ratio", 0.0)) < min_deco:
		_fail("%s decoration/blocker body coverage stayed barren: %.3f min %.3f metrics=%s" % [String(case_record.get("id", "")), float(coverage.get("decoration_blocker_body_coverage_ratio", 0.0)), min_deco, JSON.stringify(coverage)])
		return {}
	if float(coverage.get("average_decoration_body_tiles", 0.0)) < 8.0:
		_fail("%s average decoration footprint is still token-sized: %s" % [String(case_record.get("id", "")), JSON.stringify(coverage)])
		return {}
	if float(coverage.get("large_decoration_ratio", 0.0)) < 0.90:
		_fail("%s did not prefer large authored decoration footprints: %s" % [String(case_record.get("id", "")), JSON.stringify(coverage)])
		return {}
	var adoption: Dictionary = service.convert_generated_payload(generated, {
		"feature_gate": "native_rmg_homm3_fill_coverage_report",
		"session_save_version": 9,
		"scenario_id": "native_fill_coverage_%s" % String(case_record.get("id", "case")),
	})
	if not bool(adoption.get("ok", false)):
		_fail("%s convert_generated_payload failed: %s" % [String(case_record.get("id", "")), JSON.stringify(adoption)])
		return {}
	var map_document: Variant = adoption.get("map_document", null)
	var package_surface := _map_document_surface_summary(map_document)
	var map_path := "user://native_fill_coverage_%s.amap" % String(case_record.get("id", "case"))
	var save_result: Dictionary = service.save_map_package(map_document, map_path)
	if not bool(save_result.get("ok", false)):
		_fail("%s save_map_package failed: %s" % [String(case_record.get("id", "")), JSON.stringify(save_result)])
		return {}
	var load_result: Dictionary = service.load_map_package(map_path)
	DirAccess.remove_absolute(map_path)
	if not bool(load_result.get("ok", false)):
		_fail("%s load_map_package failed: %s" % [String(case_record.get("id", "")), JSON.stringify(load_result)])
		return {}
	var loaded_document: Variant = load_result.get("map_document", null)
	var loaded_surface := _map_document_surface_summary(loaded_document)
	var result := coverage.duplicate(true)
	result["template_id"] = String(normalized.get("template_id", ""))
	result["profile_id"] = String(normalized.get("profile_id", ""))
	result["size_class_id"] = String(normalized.get("size_class_id", ""))
	result["status"] = String(generated.get("status", ""))
	result["full_generation_status"] = String(generated.get("full_generation_status", ""))
	result["zone_count"] = int(generated.get("zone_layout", {}).get("zone_count", 0))
	result["route_edge_count"] = int(generated.get("route_graph", {}).get("route_edge_count", 0))
	result["road_count"] = int(road.get("road_segment_count", 0))
	result["road_cell_count"] = int(road.get("road_cell_count", 0))
	result["package_surface"] = package_surface
	result["loaded_surface"] = loaded_surface
	result["coverage_floor"] = min_deco
	result["remaining_gap_to_80_percent_deco_fill"] = max(0.0, 0.80 - float(result.get("decoration_blocker_body_coverage_ratio", 0.0)))
	return result

func _coverage_for_objects(case_id: String, objects: Array, width: int, height: int) -> Dictionary:
	var all_body := {}
	var deco_body := {}
	var blocking_body := {}
	var visits := {}
	var per_zone_decor_count := {}
	var per_zone_decor_body := {}
	var counts_by_kind := {}
	var decoration_count := 0
	var large_decoration_count := 0
	var decoration_body_sum := 0
	for object in objects:
		if not (object is Dictionary):
			continue
		var kind := String(object.get("kind", object.get("native_record_kind", "")))
		counts_by_kind[kind] = int(counts_by_kind.get(kind, 0)) + 1
		var is_deco := kind == "decorative_obstacle" or String(object.get("object_family_id", "")) == "decorative_obstacle"
		var is_blocking := is_deco or bool(object.get("blocking_body", false)) or String(object.get("passability_class", "")).begins_with("blocking") or String(object.get("passability_class", "")) == "edge_blocker"
		var zone_id := String(object.get("zone_id", ""))
		var body_tiles: Array = object.get("body_tiles", []) if object.get("body_tiles", []) is Array else []
		if is_deco:
			decoration_count += 1
			per_zone_decor_count[zone_id] = int(per_zone_decor_count.get(zone_id, 0)) + 1
			if body_tiles.size() >= 6:
				large_decoration_count += 1
		for body in body_tiles:
			if not (body is Dictionary):
				continue
			var key := _point_key(int(body.get("x", 0)), int(body.get("y", 0)))
			all_body[key] = true
			if is_deco:
				deco_body[key] = true
				blocking_body[key] = true
				decoration_body_sum += 1
				per_zone_decor_body[zone_id] = int(per_zone_decor_body.get(zone_id, 0)) + 1
			elif is_blocking:
				blocking_body[key] = true
		var visit: Dictionary = object.get("visit_tile", {}) if object.get("visit_tile", {}) is Dictionary else {}
		if not visit.is_empty():
			visits[_point_key(int(visit.get("x", 0)), int(visit.get("y", 0)))] = true
	var zone_counts := per_zone_decor_count.values()
	var zone_body_counts := per_zone_decor_body.values()
	var map_tiles: int = max(1, width * height)
	return {
		"id": case_id,
		"width": width,
		"height": height,
		"map_tile_count": map_tiles,
		"object_count": objects.size(),
		"decoration_count": decoration_count,
		"counts_by_kind": counts_by_kind,
		"unique_body_tile_count": all_body.size(),
		"unique_decoration_blocker_body_tile_count": deco_body.size(),
		"unique_blocking_body_tile_count": blocking_body.size(),
		"unique_visit_tile_count": visits.size(),
		"body_coverage_ratio": snapped(float(all_body.size()) / float(map_tiles), 0.0001),
		"decoration_blocker_body_coverage_ratio": snapped(float(deco_body.size()) / float(map_tiles), 0.0001),
		"blocking_body_coverage_ratio": snapped(float(blocking_body.size()) / float(map_tiles), 0.0001),
		"visit_tile_coverage_ratio": snapped(float(visits.size()) / float(map_tiles), 0.0001),
		"empty_body_tile_ratio": snapped(1.0 - float(all_body.size()) / float(map_tiles), 0.0001),
		"average_decoration_body_tiles": snapped(float(decoration_body_sum) / float(max(1, decoration_count)), 0.001),
		"large_decoration_count": large_decoration_count,
		"large_decoration_ratio": snapped(float(large_decoration_count) / float(max(1, decoration_count)), 0.0001),
		"per_zone_decoration_count_min": _array_min_int(zone_counts),
		"per_zone_decoration_count_max": _array_max_int(zone_counts),
		"per_zone_decoration_count_avg": snapped(_array_avg(zone_counts), 0.001),
		"per_zone_decoration_body_tiles_min": _array_min_int(zone_body_counts),
		"per_zone_decoration_body_tiles_max": _array_max_int(zone_body_counts),
		"per_zone_decoration_body_tiles_avg": snapped(_array_avg(zone_body_counts), 0.001),
	}

func _road_summary_from_generated(generated: Dictionary) -> Dictionary:
	var road_segments: Array = generated.get("road_network", {}).get("road_segments", []) if generated.get("road_network", {}).get("road_segments", []) is Array else []
	var cells := 0
	for segment in road_segments:
		if segment is Dictionary:
			cells += int(segment.get("cells", []).size())
	return {
		"road_segment_count": road_segments.size(),
		"road_cell_count": cells,
	}

func _road_body_conflicts(generated: Dictionary) -> Array:
	var road_keys := {}
	for segment in generated.get("road_network", {}).get("road_segments", []):
		if not (segment is Dictionary):
			continue
		for cell in segment.get("cells", []):
			if cell is Dictionary:
				road_keys[_point_key(int(cell.get("x", 0)), int(cell.get("y", 0)))] = true
	var conflicts := []
	for object in generated.get("object_placements", []):
		if not (object is Dictionary) or String(object.get("kind", "")) != "decorative_obstacle":
			continue
		for body in object.get("body_tiles", []):
			if body is Dictionary:
				var key := _point_key(int(body.get("x", 0)), int(body.get("y", 0)))
				if road_keys.has(key):
					conflicts.append("%s@%s" % [String(object.get("placement_id", "")), key])
	return conflicts

func _homm3_re_obstacle_catalog_summary() -> Dictionary:
	var file := FileAccess.open(HOMM3_RE_OBSTACLE_CSV, FileAccess.READ)
	if file == null:
		_fail("Could not open HoMM3-re obstacle CSV at %s." % HOMM3_RE_OBSTACLE_CSV)
		return {}
	var header := file.get_csv_line()
	var index := {}
	for i in range(header.size()):
		index[String(header[i])] = i
	var terrain_counts := {}
	var type_names := {}
	var unique_defs := {}
	var row_count := 0
	var mapped_ref_total := 0
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() <= 1:
			continue
		row_count += 1
		var terrain := String(row[int(index.get("terrain_name", 0))])
		terrain_counts[terrain] = int(terrain_counts.get(terrain, 0)) + 1
		type_names[String(row[int(index.get("type_name", 0))])] = true
		mapped_ref_total += int(String(row[int(index.get("mapped_template_count", 0))]))
		for def_name in String(row[int(index.get("mapped_template_defs", 0))]).split("|", false):
			unique_defs[String(def_name).to_lower()] = true
	return {
		"source": HOMM3_RE_OBSTACLE_CSV,
		"rand_trn_obstacle_row_count": row_count,
		"unique_decorative_type_name_count": type_names.size(),
		"mapped_def_template_ref_total": mapped_ref_total,
		"unique_mapped_def_template_count": unique_defs.size(),
		"by_terrain_counts": terrain_counts,
		"source_docs": ["/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-decoration-object-placement.md"],
	}

func _authored_decoration_blocker_summary() -> Dictionary:
	var data: Dictionary = ContentService.load_json("res://content/map_objects.json")
	var items: Array = data.get("items", []) if data.get("items", []) is Array else []
	var decoration_count := 0
	var blocking_decoration_count := 0
	var passability_counts := {}
	var footprint_counts := {}
	for item in items:
		if not (item is Dictionary):
			continue
		if String(item.get("primary_class", "")) != "decoration":
			continue
		decoration_count += 1
		var passability := String(item.get("passability_class", ""))
		passability_counts[passability] = int(passability_counts.get(passability, 0)) + 1
		var footprint: Dictionary = item.get("footprint", {}) if item.get("footprint", {}) is Dictionary else {}
		var footprint_key := "%dx%d" % [int(footprint.get("width", 1)), int(footprint.get("height", 1))]
		footprint_counts[footprint_key] = int(footprint_counts.get(footprint_key, 0)) + 1
		if passability.begins_with("blocking") or passability == "edge_blocker":
			blocking_decoration_count += 1
	return {
		"source": "content/map_objects.json",
		"authored_decoration_count": decoration_count,
		"authored_decoration_blocker_count": blocking_decoration_count,
		"passability_counts": passability_counts,
		"footprint_counts": footprint_counts,
	}

func _map_document_surface_summary(map_document: Variant) -> Dictionary:
	if map_document == null:
		return {}
	var terrain_layers: Dictionary = map_document.get_terrain_layers()
	var roads: Array = terrain_layers.get("roads", []) if terrain_layers.get("roads", []) is Array else []
	var road_cells := 0
	for road in roads:
		if road is Dictionary:
			road_cells += int(road.get("tile_count", road.get("cell_count", 0)))
	return {
		"width": int(map_document.get_width()),
		"height": int(map_document.get_height()),
		"road_count": roads.size(),
		"road_cell_count": road_cells,
		"object_count": int(map_document.get_object_count()),
	}

func _load_json_file(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}

func _array_min_int(values: Array) -> int:
	if values.is_empty():
		return 0
	var result := int(values[0])
	for value in values:
		result = min(result, int(value))
	return result

func _array_max_int(values: Array) -> int:
	var result := 0
	for value in values:
		result = max(result, int(value))
	return result

func _array_avg(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += float(value)
	return total / float(values.size())

func _point_key(x: int, y: int) -> String:
	return "%d,%d" % [x, y]

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
