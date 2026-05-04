extends Node

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")

const REPORT_ID := "NATIVE_RANDOM_MAP_HOMM3_LAND_WATER_SHAPE_REPORT"
const REPORT_SCHEMA_ID := "native_random_map_homm3_land_water_shape_report_v1"

const ATTACHED_H3M_GZ := "/root/.openclaw/media/inbound/Untitled---cad43d4f-6faa-4059-a9db-9b37770806af.gz"
const H3M_TILE_BYTES_PER_CELL := 7
const HOMM3_VERSION_SOD := 28
const PREVIOUS_NATIVE_LAND_COUNT := 4900
const PREVIOUS_NATIVE_WATER_COUNT := 284

const OWNER_CASE := {
	"seed": "1777897383",
	"template_id": "translated_rmg_template_001_v1",
	"profile_id": "translated_rmg_profile_001_v1",
	"player_count": 4,
	"water_mode": "islands",
	"underground": false,
	"size_class_id": "homm3_medium",
}

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

	var owner := _parse_owner_h3m_land_water()
	if owner.is_empty():
		return
	var native := _generate_native_owner_like(service)
	if native.is_empty():
		return
	var surface := _surface_land_summary(service, native.get("generated", {}), native.get("land_lookup", {}))
	if surface.is_empty():
		return
	var comparison := _comparison(owner, native)
	var gate := _gate_summary(owner, native, surface, comparison)
	if String(gate.get("status", "")) != "pass":
		_fail("Land/water shape gate failed: %s" % JSON.stringify(gate))
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"schema_id": REPORT_SCHEMA_ID,
		"ok": true,
		"binding_kind": metadata.get("binding_kind", ""),
		"native_extension_loaded": metadata.get("native_extension_loaded", false),
		"owner_h3m": owner,
		"native_owner_like": native.get("metrics", {}),
		"surface_land_summary": surface,
		"comparison": comparison,
		"gate": gate,
		"remaining_gap": "Native 72x72 islands land/water shape is substantially closer to the owner HoMM3-re baseline, but this is not full terrain-shape, object-table, asset, byte, or full HoMM3-re parity.",
	})])
	get_tree().quit(0)

func _generate_native_owner_like(service: Variant) -> Dictionary:
	var config := ScenarioSelectRulesScript.build_random_map_player_config(
		String(OWNER_CASE.get("seed", "")),
		String(OWNER_CASE.get("template_id", "")),
		String(OWNER_CASE.get("profile_id", "")),
		int(OWNER_CASE.get("player_count", 4)),
		String(OWNER_CASE.get("water_mode", "islands")),
		bool(OWNER_CASE.get("underground", false)),
		String(OWNER_CASE.get("size_class_id", "homm3_medium"))
	)
	var generated: Dictionary = service.generate_random_map(config, {"startup_path": "homm3_land_water_shape_report"})
	if not bool(generated.get("ok", false)) or String(generated.get("validation_status", "")) != "pass":
		_fail("Native owner-like generation failed validation: %s" % JSON.stringify(generated.get("validation_report", generated)))
		return {}
	var normalized: Dictionary = generated.get("normalized_config", {}) if generated.get("normalized_config", {}) is Dictionary else {}
	var terrain := _native_land_water(generated)
	if terrain.is_empty():
		return {}
	var metrics: Dictionary = terrain.get("metrics", {})
	metrics["seed"] = String(normalized.get("normalized_seed", ""))
	metrics["template_id"] = String(normalized.get("template_id", ""))
	metrics["profile_id"] = String(normalized.get("profile_id", ""))
	metrics["water_mode"] = String(normalized.get("water_mode", ""))
	metrics["size_class_id"] = String(normalized.get("size_class_id", ""))
	metrics["zone_count"] = int(generated.get("zone_layout", {}).get("zone_count", 0))
	metrics["route_edge_count"] = int(generated.get("route_graph", {}).get("route_edge_count", 0))
	metrics["road_cell_count"] = int(generated.get("road_network", {}).get("road_cell_count", 0))
	metrics["object_count"] = int(generated.get("object_placements", []).size()) + int(generated.get("town_records", []).size()) + int(generated.get("guard_records", []).size())
	metrics["object_category_counts"] = generated.get("object_category_counts", {})
	metrics["town_guard_category_counts"] = generated.get("town_guard_category_counts", {})
	metrics["fill_coverage_summary"] = generated.get("fill_coverage_summary", {})
	metrics["land_water_shape"] = terrain.get("land_water_shape", {})
	return {
		"generated": generated,
		"land_lookup": terrain.get("land_lookup", {}),
		"metrics": metrics,
	}

func _parse_owner_h3m_land_water() -> Dictionary:
	var compressed := FileAccess.get_file_as_bytes(ATTACHED_H3M_GZ)
	if compressed.is_empty():
		_fail("Could not read owner H3M gzip at %s." % ATTACHED_H3M_GZ)
		return {}
	var bytes := compressed.decompress_dynamic(10000000, 3)
	if bytes.is_empty():
		_fail("Could not decompress owner H3M gzip.")
		return {}
	var version := _u32(bytes, 0)
	var width := _u32(bytes, 5)
	var height := width
	if version != HOMM3_VERSION_SOD or width != 72:
		_fail("Owner H3M anchor changed: version=%d width=%d." % [version, width])
		return {}
	var def_offset := _find_object_definition_offset(bytes)
	if def_offset <= 0:
		_fail("Could not locate H3M object-definition table.")
		return {}
	var tile_offset := def_offset - int(width * height * H3M_TILE_BYTES_PER_CELL)
	var land_count := 0
	var water_count := 0
	var road_count := 0
	for y in range(height):
		for x in range(width):
			var offset := tile_offset + (y * width + x) * H3M_TILE_BYTES_PER_CELL
			if int(bytes[offset]) == 8:
				water_count += 1
			else:
				land_count += 1
			if int(bytes[offset + 4]) != 0:
				road_count += 1
	return {
		"path": ATTACHED_H3M_GZ,
		"version": version,
		"gzip_bytes": compressed.size(),
		"decompressed_h3m_bytes": bytes.size(),
		"width": width,
		"height": height,
		"map_tile_count": width * height,
		"tile_stream_offset": tile_offset,
		"object_definition_offset": def_offset,
		"land_tile_count": land_count,
		"water_tile_count": water_count,
		"land_coverage_ratio": snapped(float(land_count) / float(width * height), 0.0001),
		"water_coverage_ratio": snapped(float(water_count) / float(width * height), 0.0001),
		"road_tile_count": road_count,
	}

func _native_land_water(generated: Dictionary) -> Dictionary:
	var grid: Dictionary = generated.get("terrain_grid", {}) if generated.get("terrain_grid", {}) is Dictionary else {}
	var ids: PackedStringArray = grid.get("terrain_id_by_code", PackedStringArray())
	var levels: Array = grid.get("levels", []) if grid.get("levels", []) is Array else []
	if ids.is_empty() or levels.is_empty():
		_fail("Native generated terrain grid was missing terrain ids or levels.")
		return {}
	var width := int(grid.get("width", 0))
	var height := int(grid.get("height", 0))
	var level: Dictionary = levels[0]
	var codes: PackedInt32Array = level.get("terrain_code_u16", PackedInt32Array())
	var land_lookup := {}
	var terrain_counts := {}
	var land_count := 0
	var water_count := 0
	for index in range(min(codes.size(), width * height)):
		var code := int(codes[index])
		var terrain_id := String(ids[code]) if code >= 0 and code < ids.size() else "grass"
		terrain_counts[terrain_id] = int(terrain_counts.get(terrain_id, 0)) + 1
		if terrain_id == "water":
			water_count += 1
		else:
			land_count += 1
			land_lookup[_point_key(index % width, int(index / width))] = true
	return {
		"land_lookup": land_lookup,
		"land_water_shape": grid.get("land_water_shape", {}),
		"metrics": {
			"width": width,
			"height": height,
			"map_tile_count": width * height,
			"land_tile_count": land_count,
			"water_tile_count": water_count,
			"land_coverage_ratio": snapped(float(land_count) / float(max(1, width * height)), 0.0001),
			"water_coverage_ratio": snapped(float(water_count) / float(max(1, width * height)), 0.0001),
			"terrain_counts": terrain_counts,
		}
	}

func _surface_land_summary(service: Variant, generated: Dictionary, land_lookup: Dictionary) -> Dictionary:
	var generated_conflicts := []
	var generated_surface_counts := {"road": 0, "body": 0, "visit": 0, "approach": 0}
	for segment in generated.get("road_network", {}).get("road_segments", []):
		if not (segment is Dictionary):
			continue
		for cell in segment.get("cells", []):
			if cell is Dictionary:
				generated_surface_counts["road"] = int(generated_surface_counts.get("road", 0)) + 1
				_append_land_conflict(generated_conflicts, "road", String(segment.get("id", "")), cell, land_lookup)
	for record in _all_generated_records(generated):
		_check_record_surfaces(record, land_lookup, generated_conflicts, generated_surface_counts)

	var adoption: Dictionary = service.convert_generated_payload(generated, {
		"feature_gate": "native_rmg_land_water_shape_report",
		"session_save_version": 9,
		"scenario_id": "native_land_water_shape_owner_like",
	})
	if not bool(adoption.get("ok", false)):
		_fail("convert_generated_payload failed for land/water shape report: %s" % JSON.stringify(adoption))
		return {}
	var adoption_report: Dictionary = adoption.get("report", {}) if adoption.get("report", {}) is Dictionary else {}
	var adoption_summary: Dictionary = adoption_report.get("guard_reward_package_adoption", {}) if adoption_report.get("guard_reward_package_adoption", {}) is Dictionary else {}
	if String(adoption_summary.get("status", "")) != "pass":
		_fail("Package adoption summary did not pass after island shaping: %s" % JSON.stringify(adoption_summary))
		return {}
	var map_document: Variant = adoption.get("map_document", null)
	if map_document == null:
		_fail("convert_generated_payload missed map_document.")
		return {}

	var package_conflicts := []
	var package_counts := {"body": 0, "block": 0, "visit": 0}
	for index in range(int(map_document.get_object_count())):
		var object: Dictionary = map_document.get_object_by_index(index)
		for cell in object.get("package_body_tiles", []):
			if cell is Dictionary:
				package_counts["body"] = int(package_counts.get("body", 0)) + 1
				_append_land_conflict(package_conflicts, "package_body", String(object.get("placement_id", "")), cell, land_lookup)
		for cell in object.get("package_block_tiles", []):
			if cell is Dictionary:
				package_counts["block"] = int(package_counts.get("block", 0)) + 1
				_append_land_conflict(package_conflicts, "package_block", String(object.get("placement_id", "")), cell, land_lookup)
		for cell in object.get("package_visit_tiles", []):
			if cell is Dictionary:
				package_counts["visit"] = int(package_counts.get("visit", 0)) + 1
				_append_land_conflict(package_conflicts, "package_visit", String(object.get("placement_id", "")), cell, land_lookup)
	return {
		"generated_surface_counts": generated_surface_counts,
		"generated_surface_water_conflict_count": generated_conflicts.size(),
		"generated_surface_water_conflicts": generated_conflicts.slice(0, 12),
		"package_surface_counts": package_counts,
		"package_surface_water_conflict_count": package_conflicts.size(),
		"package_surface_water_conflicts": package_conflicts.slice(0, 12),
		"package_adoption_summary": adoption_summary,
	}

func _all_generated_records(generated: Dictionary) -> Array:
	var result := []
	for key in ["object_placements", "town_records", "guard_records"]:
		var records: Array = generated.get(key, []) if generated.get(key, []) is Array else []
		for record in records:
			if record is Dictionary:
				result.append(record)
	return result

func _check_record_surfaces(record: Dictionary, land_lookup: Dictionary, conflicts: Array, counts: Dictionary) -> void:
	var placement_id := String(record.get("placement_id", record.get("guard_id", "")))
	for cell in record.get("body_tiles", []):
		if cell is Dictionary:
			counts["body"] = int(counts.get("body", 0)) + 1
			_append_land_conflict(conflicts, "body", placement_id, cell, land_lookup)
	if record.get("visit_tile", {}) is Dictionary:
		counts["visit"] = int(counts.get("visit", 0)) + 1
		_append_land_conflict(conflicts, "visit", placement_id, record.get("visit_tile", {}), land_lookup)
	for cell in record.get("approach_tiles", []):
		if cell is Dictionary:
			counts["approach"] = int(counts.get("approach", 0)) + 1
			_append_land_conflict(conflicts, "approach", placement_id, cell, land_lookup)

func _append_land_conflict(conflicts: Array, surface: String, placement_id: String, cell: Dictionary, land_lookup: Dictionary) -> void:
	var x := int(cell.get("x", 0))
	var y := int(cell.get("y", 0))
	if not land_lookup.has(_point_key(x, y)):
		conflicts.append({"surface": surface, "placement_id": placement_id, "x": x, "y": y})

func _comparison(owner: Dictionary, native: Dictionary) -> Dictionary:
	var metrics: Dictionary = native.get("metrics", {})
	var previous_delta: int = abs(PREVIOUS_NATIVE_LAND_COUNT - int(owner.get("land_tile_count", 0)))
	var current_delta: int = abs(int(metrics.get("land_tile_count", 0)) - int(owner.get("land_tile_count", 0)))
	return {
		"previous_native_land_count": PREVIOUS_NATIVE_LAND_COUNT,
		"previous_native_water_count": PREVIOUS_NATIVE_WATER_COUNT,
		"previous_abs_land_delta": previous_delta,
		"native_abs_land_delta": current_delta,
		"abs_land_delta_improvement": previous_delta - current_delta,
		"abs_land_delta_improvement_ratio": snapped(float(previous_delta - current_delta) / float(max(1, previous_delta)), 0.0001),
		"native_minus_owner_land": int(metrics.get("land_tile_count", 0)) - int(owner.get("land_tile_count", 0)),
		"native_minus_owner_water": int(metrics.get("water_tile_count", 0)) - int(owner.get("water_tile_count", 0)),
	}

func _gate_summary(owner: Dictionary, native: Dictionary, surface: Dictionary, comparison: Dictionary) -> Dictionary:
	var metrics: Dictionary = native.get("metrics", {})
	var failures := []
	if int(owner.get("land_tile_count", 0)) != 1948 or int(owner.get("water_tile_count", 0)) != 3236:
		failures.append("owner_land_water_baseline_changed")
	if int(metrics.get("land_tile_count", 0)) > 2600:
		failures.append("native_islands_still_too_land_dominant")
	if float(comparison.get("abs_land_delta_improvement_ratio", 0.0)) < 0.70:
		failures.append("native_land_delta_not_substantially_improved")
	if int(metrics.get("road_cell_count", 0)) <= 0:
		failures.append("native_roads_missing")
	if int(metrics.get("object_count", 0)) < 220:
		failures.append("native_objects_missing")
	if int(surface.get("generated_surface_water_conflict_count", 0)) != 0:
		failures.append("generated_surfaces_on_water")
	if int(surface.get("package_surface_water_conflict_count", 0)) != 0:
		failures.append("package_surfaces_on_water")
	if int(surface.get("package_surface_counts", {}).get("body", 0)) <= 0 or int(surface.get("package_surface_counts", {}).get("visit", 0)) <= 0:
		failures.append("package_surfaces_missing")
	return {
		"status": "pass" if failures.is_empty() else "fail",
		"failures": failures,
		"thresholds": {
			"owner_land_tiles": 1948,
			"owner_water_tiles": 3236,
			"max_native_land_tiles": 2600,
			"min_abs_land_delta_improvement_ratio": 0.70,
			"min_native_object_count": 220,
			"surface_water_conflicts": 0,
		}
	}

func _find_object_definition_offset(bytes: PackedByteArray) -> int:
	for offset in range(0, bytes.size() - 32):
		var count := _u32(bytes, offset)
		if count < 50 or count > 1000:
			continue
		var name_len := _u32(bytes, offset + 4)
		if name_len < 4 or name_len > 32:
			continue
		if _ascii(bytes, offset + 8, name_len).to_lower().ends_with(".def"):
			return offset
	return -1

func _u32(bytes: PackedByteArray, offset: int) -> int:
	if offset < 0 or offset + 4 > bytes.size():
		return 0
	return int(bytes[offset]) | (int(bytes[offset + 1]) << 8) | (int(bytes[offset + 2]) << 16) | (int(bytes[offset + 3]) << 24)

func _ascii(bytes: PackedByteArray, offset: int, length: int) -> String:
	var chars := PackedByteArray()
	for index in range(length):
		if offset + index >= bytes.size():
			break
		chars.append(bytes[offset + index])
	return chars.get_string_from_ascii()

func _point_key(x: int, y: int) -> String:
	return "%d,%d" % [x, y]

func snapped(value: float, step: float) -> float:
	if step <= 0.0:
		return value
	return round(value / step) * step

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
