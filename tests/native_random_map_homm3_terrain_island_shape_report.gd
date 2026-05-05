extends Node

const REPORT_ID := "NATIVE_RANDOM_MAP_HOMM3_TERRAIN_ISLAND_SHAPE_REPORT"
const REPORT_SCHEMA_ID := "native_random_map_homm3_terrain_island_shape_report_v1"

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
	var capabilities: PackedStringArray = service.get_capabilities()
	if not capabilities.has("native_random_map_homm3_zone_aware_terrain_island_shape"):
		_fail("Zone-aware terrain/island capability is missing: %s" % JSON.stringify(Array(capabilities)))
		return

	var medium := _run_case(service, _case_config("native-rmg-terrain-island-medium", "translated_rmg_template_001_v1", "translated_rmg_profile_001_v1", 72, 72, "homm3_medium", 4), 12000, true)
	if medium.is_empty():
		return
	var xl := _run_case(service, _case_config("native-rmg-terrain-island-xl", "translated_rmg_template_012_v1", "translated_rmg_profile_001_v1", 144, 144, "homm3_extra_large", 2), 20000, false)
	if xl.is_empty():
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"schema_id": REPORT_SCHEMA_ID,
		"ok": true,
		"binding_kind": metadata.get("binding_kind", ""),
		"native_extension_loaded": metadata.get("native_extension_loaded", false),
		"medium_case": medium,
		"xl_case": xl,
		"remaining_gap": "Zone-aware terrain and water are implemented with generated-cell terrain id/art/flip metadata; exact TerrainPlacement queue propagation and later roads/rivers/object rewrites remain deferred Phase 3 slices.",
	})])
	get_tree().quit(0)

func _case_config(seed: String, template_id: String, profile_id: String, width: int, height: int, size_class_id: String, player_count: int) -> Dictionary:
	return {
		"seed": seed,
		"template_id": template_id,
		"profile_id": profile_id,
		"size": {
			"width": width,
			"height": height,
			"requested_width": width,
			"requested_height": height,
			"source_width": width,
			"source_height": height,
			"size_class_id": size_class_id,
			"water_mode": "islands",
			"level_count": 1,
		},
		"profile": {
			"id": profile_id,
			"template_id": template_id,
			"faction_ids": ["faction_embercourt", "faction_mireclaw", "faction_sunvault", "faction_thornwake"],
		},
		"player_constraints": {
			"human_count": 1,
			"player_count": player_count,
			"team_mode": "free_for_all",
		},
	}

func _run_case(service: Variant, config: Dictionary, budget_msec: int, require_validation_pass: bool) -> Dictionary:
	var started := Time.get_ticks_msec()
	var generated: Dictionary = service.generate_random_map(config, {"startup_path": "homm3_terrain_island_shape_report"})
	var elapsed_msec := Time.get_ticks_msec() - started
	if not bool(generated.get("ok", false)) or (require_validation_pass and String(generated.get("validation_status", "")) != "pass"):
		_fail("Native generation failed validation for %s: %s" % [String(config.get("template_id", "")), JSON.stringify(generated.get("validation_report", generated))])
		return {}
	if elapsed_msec > budget_msec:
		_fail("Native generation exceeded budget for %s: %d ms > %d ms" % [String(config.get("template_id", "")), elapsed_msec, budget_msec])
		return {}

	var grid: Dictionary = generated.get("terrain_grid", {}) if generated.get("terrain_grid", {}) is Dictionary else {}
	var shape: Dictionary = grid.get("land_water_shape", {}) if grid.get("land_water_shape", {}) is Dictionary else {}
	var spatial := _spatial_summary(generated)
	if spatial.is_empty():
		return {}
	_validate_shape(generated, grid, shape, spatial)
	if get_tree().root.get_meta("failed", false):
		return {}

	return {
		"template_id": String(generated.get("normalized_config", {}).get("template_id", "")),
		"size": "%dx%d" % [int(grid.get("width", 0)), int(grid.get("height", 0))],
		"elapsed_msec": elapsed_msec,
		"budget_msec": budget_msec,
		"zone_count": int(generated.get("zone_layout", {}).get("zone_count", 0)),
		"validation_status": String(generated.get("validation_status", "")),
		"validation_required": require_validation_pass,
		"water_tile_count": int(grid.get("terrain_counts", {}).get("water", 0)),
		"terrain_counts": grid.get("terrain_counts", {}),
		"land_water_shape": {
			"schema_id": shape.get("schema_id", ""),
			"source_model": shape.get("source_model", ""),
			"candidate_scoring_policy": shape.get("candidate_scoring_policy", ""),
			"performance_model": shape.get("performance_model", ""),
			"generated_land_cell_count": shape.get("generated_land_cell_count", 0),
			"generated_water_cell_count": shape.get("generated_water_cell_count", 0),
			"zone_target_count": shape.get("zone_target_count", 0),
			"diagnostic_count": shape.get("diagnostic_count", 0),
		},
		"spatial": spatial,
	}

func _validate_shape(generated: Dictionary, grid: Dictionary, shape: Dictionary, spatial: Dictionary) -> void:
	if String(shape.get("schema_id", "")) != "native_random_map_zone_aware_land_water_shape_v1":
		_fail("Terrain grid missed zone-aware island shape payload: %s" % JSON.stringify(shape))
		return
	if String(shape.get("source_model", "")) != "runtime_zone_graph_owner_grid_zone_land_quotas":
		_fail("Island shape source model is not runtime-zone based: %s" % JSON.stringify(shape))
		return
	if String(shape.get("candidate_scoring_policy", "")) != "disabled_old_global_candidate_sort_removed":
		_fail("Old candidate scoring path is not explicitly disabled: %s" % JSON.stringify(shape))
		return
	if int(shape.get("zone_target_count", 0)) != int(generated.get("zone_layout", {}).get("zone_count", 0)):
		_fail("Zone land target count did not match runtime zones: %s" % JSON.stringify(shape))
		return
	if int(shape.get("generated_water_cell_count", 0)) <= 0:
		_fail("Islands case did not generate water: %s" % JSON.stringify(shape))
		return
	if int(spatial.get("surface_water_conflict_count", 0)) != 0:
		_fail("Generated surfaces landed on water: %s" % JSON.stringify(spatial))
		return
	var levels: Array = grid.get("levels", []) if grid.get("levels", []) is Array else []
	if levels.is_empty():
		_fail("Terrain grid missed levels.")
		return
	var level: Dictionary = levels[0]
	var tile_count := int(level.get("tile_count", 0))
	if tile_count > 5184:
		var summary: Dictionary = level.get("terrain_generated_cell_summary", {}) if level.get("terrain_generated_cell_summary", {}) is Dictionary else {}
		if String(summary.get("mode", "")) != "compact_metadata_only_for_large_maps":
			_fail("Large terrain grid missed compact generated-cell summary: %s" % JSON.stringify(level))
			return
		return
	for key in ["terrain_code_u16", "terrain_art_index_u8", "terrain_flip_h", "terrain_flip_v"]:
		var array_value: Variant = level.get(key, PackedInt32Array())
		if not (array_value is PackedInt32Array) or (array_value as PackedInt32Array).size() != tile_count:
			_fail("Generated-cell terrain field %s size mismatch." % key)
			return

func _spatial_summary(generated: Dictionary) -> Dictionary:
	var grid: Dictionary = generated.get("terrain_grid", {}) if generated.get("terrain_grid", {}) is Dictionary else {}
	var ids: PackedStringArray = grid.get("terrain_id_by_code", PackedStringArray())
	var levels: Array = grid.get("levels", []) if grid.get("levels", []) is Array else []
	if ids.is_empty() or levels.is_empty():
		_fail("Terrain grid missing ids or levels.")
		return {}
	var width := int(grid.get("width", 0))
	var codes: PackedInt32Array = levels[0].get("terrain_code_u16", PackedInt32Array())
	var conflicts := []
	var checked := 0
	for segment in generated.get("road_network", {}).get("road_segments", []):
		if segment is Dictionary:
			for cell in segment.get("cells", []):
				checked += _append_water_conflict(conflicts, "road", cell, width, ids, codes)
	for key in ["object_placements", "town_records", "guard_records"]:
		for record in generated.get(key, []):
			if not (record is Dictionary):
				continue
			for cell in record.get("body_tiles", []):
				checked += _append_water_conflict(conflicts, "body", cell, width, ids, codes)
			if record.get("visit_tile", {}) is Dictionary:
				checked += _append_water_conflict(conflicts, "visit", record.get("visit_tile", {}), width, ids, codes)
			for cell in record.get("approach_tiles", []):
				checked += _append_water_conflict(conflicts, "approach", cell, width, ids, codes)
	return {
		"surface_cell_count": checked,
		"surface_water_conflict_count": conflicts.size(),
		"surface_water_conflicts": conflicts.slice(0, 8),
	}

func _append_water_conflict(conflicts: Array, surface: String, cell: Variant, width: int, ids: PackedStringArray, codes: PackedInt32Array) -> int:
	if not (cell is Dictionary):
		return 0
	var x := int(cell.get("x", 0))
	var y := int(cell.get("y", 0))
	var index := y * width + x
	if index < 0 or index >= codes.size():
		conflicts.append({"surface": surface, "x": x, "y": y, "reason": "out_of_bounds"})
		return 1
	var code := int(codes[index])
	var terrain_id := String(ids[code]) if code >= 0 and code < ids.size() else ""
	if terrain_id == "water":
		conflicts.append({"surface": surface, "x": x, "y": y})
	return 1

func _fail(message: String) -> void:
	get_tree().root.set_meta("failed", true)
	push_error("%s failed: %s" % [REPORT_ID, message])
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "error": message})])
	get_tree().quit(1)
