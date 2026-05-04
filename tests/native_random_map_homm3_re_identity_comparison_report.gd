extends Node

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")

const REPORT_ID := "NATIVE_RANDOM_MAP_HOMM3_RE_IDENTITY_COMPARISON_REPORT"
const REPORT_SCHEMA_ID := "native_random_map_homm3_re_identity_comparison_report_v1"

const HOMM3_RE_PROXY_CATALOG := "res://content/homm3_re_obstacle_proxy_catalog.json"
const ATTACHED_H3M_GZ := "/root/.openclaw/media/inbound/Untitled---cad43d4f-6faa-4059-a9db-9b37770806af.gz"

const OWNER_ATTACHED_BASELINE := {
	"source": "owner_attached_h3m_parsed_metrics_2026_05_04",
	"gzip_bytes": 12952,
	"decompressed_h3m_bytes": 61868,
	"width": 72,
	"height": 72,
	"water_mode": "islands",
	"seed": "1777897383",
	"template": "Small Ring",
	"object_instances": 496,
	"impassable_terrain_deco_instances": 272,
	"road_tiles": 184,
	"decoration_blocked_tiles": 578,
	"decoration_blocked_coverage_whole": 0.1115,
	"decoration_blocked_coverage_non_water_land": 0.297,
	"all_blocked_occupied_tiles": 1026,
	"all_blocked_occupied_coverage_whole": 0.1979,
	"all_blocked_occupied_coverage_non_water_land": 0.527,
}

const CASES := [
	{
		"id": "owner_like_medium_small_ring_islands",
		"seed": "1777897383",
		"template_id": "translated_rmg_template_001_v1",
		"profile_id": "translated_rmg_profile_001_v1",
		"player_count": 4,
		"water_mode": "islands",
		"underground": false,
		"size_class_id": "homm3_medium",
		"compare_to_owner_baseline": true,
		"min_decoration_coverage": 0.20,
		"min_object_instances": 180,
		"min_road_tiles": 80,
		"min_source_rows": 10,
		"min_type_names": 8,
	},
	{
		"id": "small_frontier_seed_42",
		"seed": "42",
		"template_id": "frontier_spokes_v1",
		"profile_id": "frontier_spokes_profile_v1",
		"player_count": 3,
		"water_mode": "land",
		"underground": false,
		"size_class_id": "homm3_small",
		"min_decoration_coverage": 0.18,
		"min_object_instances": 70,
		"min_road_tiles": 20,
		"min_source_rows": 6,
		"min_type_names": 5,
	},
	{
		"id": "medium_translated_024_seed_314159",
		"seed": "314159",
		"template_id": "translated_rmg_template_024_v1",
		"profile_id": "translated_rmg_profile_024_v1",
		"player_count": 4,
		"water_mode": "land",
		"underground": false,
		"size_class_id": "homm3_medium",
		"min_decoration_coverage": 0.20,
		"min_object_instances": 180,
		"min_road_tiles": 80,
		"min_source_rows": 10,
		"min_type_names": 8,
	},
	{
		"id": "large_mesh_seed_271828",
		"seed": "271828",
		"template_id": "translated_rmg_template_042_v1",
		"profile_id": "translated_rmg_profile_042_v1",
		"player_count": 4,
		"water_mode": "land",
		"underground": false,
		"size_class_id": "homm3_large",
		"min_decoration_coverage": 0.20,
		"min_object_instances": 360,
		"min_road_tiles": 120,
		"min_source_rows": 14,
		"min_type_names": 10,
	},
	{
		"id": "xl_mesh_seed_1618033",
		"seed": "1618033",
		"template_id": "translated_rmg_template_043_v1",
		"profile_id": "translated_rmg_profile_043_v1",
		"player_count": 8,
		"water_mode": "land",
		"underground": false,
		"size_class_id": "homm3_extra_large",
		"min_decoration_coverage": 0.20,
		"min_object_instances": 700,
		"min_road_tiles": 180,
		"min_source_rows": 16,
		"min_type_names": 12,
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

	var source_catalog := _load_json(HOMM3_RE_PROXY_CATALOG)
	if source_catalog.is_empty():
		_fail("Could not load HoMM3-re obstacle proxy catalog at %s." % HOMM3_RE_PROXY_CATALOG)
		return
	var catalog_summary := _validate_source_catalog(source_catalog)
	if catalog_summary.is_empty():
		return
	var attachment_summary := _attachment_summary()
	if attachment_summary.is_empty():
		return

	var cases := []
	var aggregate_source_rows := {}
	var aggregate_type_names := {}
	var aggregate_terrain_names := {}
	var aggregate_proxy_families := {}
	for case_record in CASES:
		var summary := _run_case(service, case_record)
		if summary.is_empty():
			return
		cases.append(summary)
		_merge_keys(aggregate_source_rows, summary.get("source_row_counts", {}))
		_merge_keys(aggregate_type_names, summary.get("type_name_counts", {}))
		_merge_keys(aggregate_terrain_names, summary.get("homm3_terrain_counts", {}))
		_merge_keys(aggregate_proxy_families, summary.get("proxy_family_counts", {}))

	if aggregate_source_rows.size() < 24:
		_fail("Broad sample source-row diversity stayed low: %d rows across %d cases." % [aggregate_source_rows.size(), cases.size()])
		return
	if aggregate_type_names.size() < 16:
		_fail("Broad sample type diversity stayed low: %d types across %d cases." % aggregate_type_names.size())
		return
	if aggregate_terrain_names.size() < 4:
		_fail("Broad sample terrain-biased source coverage stayed too narrow: %s" % JSON.stringify(aggregate_terrain_names))
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"schema_id": REPORT_SCHEMA_ID,
		"ok": true,
		"binding_kind": metadata.get("binding_kind", ""),
		"native_extension_loaded": metadata.get("native_extension_loaded", false),
		"source_catalog": catalog_summary,
		"owner_attached_h3m": attachment_summary,
		"cases": cases,
		"broad_sample": {
			"case_count": cases.size(),
			"unique_source_row_count": aggregate_source_rows.size(),
			"unique_type_name_count": aggregate_type_names.size(),
			"unique_homm3_terrain_count": aggregate_terrain_names.size(),
			"unique_proxy_family_count": aggregate_proxy_families.size(),
			"top_source_rows": _top_counts_from_keyed_presence(aggregate_source_rows, 12),
			"top_type_names": _top_counts_from_keyed_presence(aggregate_type_names, 12),
			"terrain_names": aggregate_terrain_names.keys(),
		},
		"remaining_gap": "This implements HoMM3-re rand_trn source identity/proxy metadata and comparison gates only; it does not import exact HoMM3 art/DEF assets and does not claim exact placement, byte, reward-table, or full RMG parity.",
	})])
	get_tree().quit(0)

func _run_case(service: Variant, case_record: Dictionary) -> Dictionary:
	var config := ScenarioSelectRulesScript.build_random_map_player_config(
		String(case_record.get("seed", "0")),
		String(case_record.get("template_id", "")),
		String(case_record.get("profile_id", "")),
		int(case_record.get("player_count", 4)),
		String(case_record.get("water_mode", "land")),
		bool(case_record.get("underground", false)),
		String(case_record.get("size_class_id", "homm3_medium"))
	)
	var generated: Dictionary = service.generate_random_map(config)
	if not bool(generated.get("ok", false)) or String(generated.get("validation_status", "")) != "pass":
		_fail("%s native generation failed validation: %s" % [String(case_record.get("id", "")), JSON.stringify(generated.get("validation_report", generated))])
		return {}
	var normalized: Dictionary = generated.get("normalized_config", {}) if generated.get("normalized_config", {}) is Dictionary else {}
	var objects: Array = generated.get("object_placements", []) if generated.get("object_placements", []) is Array else []
	var all_objects := objects.duplicate()
	all_objects.append_array(generated.get("town_records", []) if generated.get("town_records", []) is Array else [])
	all_objects.append_array(generated.get("guard_records", []) if generated.get("guard_records", []) is Array else [])
	var roads := _road_summary(generated)
	var metrics := _object_metrics(all_objects, int(normalized.get("width", 0)), int(normalized.get("height", 0)))
	var min_deco := float(case_record.get("min_decoration_coverage", 0.20))
	if float(metrics.get("decoration_blocked_coverage_whole", 0.0)) < min_deco:
		_fail("%s decoration coverage regressed below %.3f: %s" % [String(case_record.get("id", "")), min_deco, JSON.stringify(metrics)])
		return {}
	if int(metrics.get("object_instances", 0)) < int(case_record.get("min_object_instances", 0)):
		_fail("%s object density regressed: %s" % [String(case_record.get("id", "")), JSON.stringify(metrics)])
		return {}
	if int(roads.get("road_cell_count", 0)) < int(case_record.get("min_road_tiles", 0)):
		_fail("%s road density regressed: %s" % [String(case_record.get("id", "")), JSON.stringify(roads)])
		return {}
	if int(metrics.get("unique_homm3_source_row_count", 0)) < int(case_record.get("min_source_rows", 0)):
		_fail("%s HoMM3-re source-row diversity stayed low: %s" % [String(case_record.get("id", "")), JSON.stringify(metrics)])
		return {}
	if int(metrics.get("unique_homm3_type_name_count", 0)) < int(case_record.get("min_type_names", 0)):
		_fail("%s HoMM3-re type diversity stayed low: %s" % [String(case_record.get("id", "")), JSON.stringify(metrics)])
		return {}
	if float(metrics.get("homm3_terrain_alias_match_ratio", 0.0)) < 0.99:
		_fail("%s terrain-biased HoMM3-re source rows were absent/mismatched: %s" % [String(case_record.get("id", "")), JSON.stringify(metrics)])
		return {}
	var fill_summary: Dictionary = generated.get("fill_coverage_summary", {}) if generated.get("fill_coverage_summary", {}) is Dictionary else generated.get("object_placement", {}).get("fill_coverage_summary", {})
	var land_zone_fill := _surface_land_zone_fill_summary(generated, fill_summary)
	if int(land_zone_fill.get("checked_surface_land_zone_count", 0)) > 0 and float(land_zone_fill.get("min_surface_land_zone_decoration_body_coverage_ratio", 0.0)) < 0.07:
		_fail("%s still has a visually empty sizable surface land zone: %s" % [String(case_record.get("id", "")), JSON.stringify(land_zone_fill)])
		return {}

	var result := {
		"id": String(case_record.get("id", "")),
		"seed": String(case_record.get("seed", "")),
		"template_id": String(normalized.get("template_id", "")),
		"profile_id": String(normalized.get("profile_id", "")),
		"size_class_id": String(normalized.get("size_class_id", "")),
		"water_mode": String(normalized.get("water_mode", "")),
		"width": int(normalized.get("width", 0)),
		"height": int(normalized.get("height", 0)),
		"zone_count": int(generated.get("zone_layout", {}).get("zone_count", 0)),
		"route_edge_count": int(generated.get("route_graph", {}).get("route_edge_count", 0)),
		"roads": roads,
		"metrics": metrics,
		"source_row_counts": metrics.get("source_row_counts", {}),
		"type_name_counts": metrics.get("type_name_counts", {}),
		"homm3_terrain_counts": metrics.get("homm3_terrain_counts", {}),
		"proxy_family_counts": metrics.get("proxy_family_counts", {}),
		"top_homm3_type_names": _top_counts(metrics.get("type_name_counts", {}), 10),
		"top_proxy_families": _top_counts(metrics.get("proxy_family_counts", {}), 10),
		"fill_coverage_summary": fill_summary,
		"land_zone_fill_summary": land_zone_fill,
	}
	if bool(case_record.get("compare_to_owner_baseline", false)):
		result["owner_baseline_comparison"] = _owner_comparison(metrics, roads)
	return result

func _object_metrics(objects: Array, width: int, height: int) -> Dictionary:
	var decoration_body := {}
	var all_blocked_occupied := {}
	var source_rows := {}
	var type_names := {}
	var terrain_names := {}
	var proxy_families := {}
	var terrain_alias_matches := 0
	var sourced_decorations := 0
	var counts_by_kind := {}
	var decoration_count := 0
	var missing_source := []
	for object in objects:
		if not (object is Dictionary):
			continue
		var kind := String(object.get("kind", object.get("native_record_kind", "")))
		counts_by_kind[kind] = int(counts_by_kind.get(kind, 0)) + 1
		var body_tiles: Array = object.get("body_tiles", []) if object.get("body_tiles", []) is Array else []
		var is_deco := kind == "decorative_obstacle" or String(object.get("object_family_id", "")) == "decorative_obstacle"
		if is_deco:
			decoration_count += 1
			if String(object.get("homm3_re_source_kind", "")) != "rand_trn_obstacle_row":
				missing_source.append(String(object.get("placement_id", "")))
			else:
				sourced_decorations += 1
				var row_key := str(int(object.get("homm3_re_rand_trn_source_row", 0)))
				source_rows[row_key] = int(source_rows.get(row_key, 0)) + 1
				var type_key := String(object.get("homm3_re_type_name", ""))
				type_names[type_key] = int(type_names.get(type_key, 0)) + 1
				var terrain_key := String(object.get("homm3_re_terrain_name", ""))
				terrain_names[terrain_key] = int(terrain_names.get(terrain_key, 0)) + 1
				var proxy_key := String(object.get("proxy_family_id", object.get("family_id", "")))
				proxy_families[proxy_key] = int(proxy_families.get(proxy_key, 0)) + 1
				if terrain_key == _homm3_source_alias(String(object.get("terrain_id", ""))):
					terrain_alias_matches += 1
		var is_blocking := is_deco or bool(object.get("blocking_body", false)) or String(object.get("passability_class", "")).begins_with("blocking") or String(object.get("passability_class", "")) == "edge_blocker"
		for body in body_tiles:
			if not (body is Dictionary):
				continue
			var key := _point_key(int(body.get("x", 0)), int(body.get("y", 0)))
			if is_deco:
				decoration_body[key] = true
			if is_blocking:
				all_blocked_occupied[key] = true
		var visit: Dictionary = object.get("visit_tile", {}) if object.get("visit_tile", {}) is Dictionary else {}
		if not visit.is_empty():
			all_blocked_occupied[_point_key(int(visit.get("x", 0)), int(visit.get("y", 0)))] = true
	var map_tiles: int = max(1, width * height)
	return {
		"object_instances": objects.size(),
		"counts_by_kind": counts_by_kind,
		"decoration_count": decoration_count,
		"homm3_re_sourced_decoration_count": sourced_decorations,
		"homm3_re_sourced_decoration_ratio": snapped(float(sourced_decorations) / float(max(1, decoration_count)), 0.0001),
		"missing_homm3_re_source_count": missing_source.size(),
		"missing_homm3_re_source_examples": missing_source.slice(0, 10),
		"decoration_blocked_tiles": decoration_body.size(),
		"decoration_blocked_coverage_whole": snapped(float(decoration_body.size()) / float(map_tiles), 0.0001),
		"all_blocked_occupied_tiles": all_blocked_occupied.size(),
		"all_blocked_occupied_coverage_whole": snapped(float(all_blocked_occupied.size()) / float(map_tiles), 0.0001),
		"unique_homm3_source_row_count": source_rows.size(),
		"unique_homm3_type_name_count": type_names.size(),
		"unique_homm3_terrain_name_count": terrain_names.size(),
		"unique_proxy_family_count": proxy_families.size(),
		"homm3_terrain_alias_match_ratio": snapped(float(terrain_alias_matches) / float(max(1, sourced_decorations)), 0.0001),
		"source_row_counts": source_rows,
		"type_name_counts": type_names,
		"homm3_terrain_counts": terrain_names,
		"proxy_family_counts": proxy_families,
	}

func _road_summary(generated: Dictionary) -> Dictionary:
	var segments: Array = generated.get("road_network", {}).get("road_segments", []) if generated.get("road_network", {}).get("road_segments", []) is Array else []
	var cells := {}
	for segment in segments:
		if not (segment is Dictionary):
			continue
		for cell in segment.get("cells", []):
			if cell is Dictionary:
				cells[_point_key(int(cell.get("x", 0)), int(cell.get("y", 0)))] = true
	return {
		"road_segment_count": segments.size(),
		"road_cell_count": cells.size(),
	}

func _surface_land_zone_fill_summary(generated: Dictionary, fill_summary: Dictionary) -> Dictionary:
	var zones: Array = generated.get("zone_layout", {}).get("zones", []) if generated.get("zone_layout", {}).get("zones", []) is Array else []
	var body_by_zone: Dictionary = fill_summary.get("decoration_body_tiles_by_zone", {}) if fill_summary.get("decoration_body_tiles_by_zone", {}) is Dictionary else {}
	var checked := 0
	var min_ratio := 1.0
	var max_ratio := 0.0
	var empty_land_zones := []
	for zone in zones:
		if not (zone is Dictionary):
			continue
		var terrain_id := String(zone.get("terrain_id", "grass"))
		var cell_count := int(zone.get("cell_count", 0))
		if terrain_id == "water" or terrain_id == "underground" or cell_count < 64:
			continue
		checked += 1
		var zone_id := String(zone.get("id", ""))
		var ratio := float(int(body_by_zone.get(zone_id, 0))) / float(max(1, cell_count))
		min_ratio = min(min_ratio, ratio)
		max_ratio = max(max_ratio, ratio)
		if ratio < 0.07:
			empty_land_zones.append({"zone_id": zone_id, "terrain_id": terrain_id, "cell_count": cell_count, "decoration_body_coverage_ratio": snapped(ratio, 0.0001)})
	return {
		"checked_surface_land_zone_count": checked,
		"min_surface_land_zone_decoration_body_coverage_ratio": snapped(0.0 if checked == 0 else min_ratio, 0.0001),
		"max_surface_land_zone_decoration_body_coverage_ratio": snapped(max_ratio, 0.0001),
		"empty_surface_land_zone_examples": empty_land_zones.slice(0, 8),
	}

func _owner_comparison(metrics: Dictionary, roads: Dictionary) -> Dictionary:
	return {
		"baseline_metrics_source": OWNER_ATTACHED_BASELINE.get("source", ""),
		"object_instance_delta": int(metrics.get("object_instances", 0)) - int(OWNER_ATTACHED_BASELINE.get("object_instances", 0)),
		"road_tile_delta": int(roads.get("road_cell_count", 0)) - int(OWNER_ATTACHED_BASELINE.get("road_tiles", 0)),
		"decoration_blocked_tile_delta": int(metrics.get("decoration_blocked_tiles", 0)) - int(OWNER_ATTACHED_BASELINE.get("decoration_blocked_tiles", 0)),
		"all_blocked_occupied_tile_delta": int(metrics.get("all_blocked_occupied_tiles", 0)) - int(OWNER_ATTACHED_BASELINE.get("all_blocked_occupied_tiles", 0)),
		"decoration_coverage_whole_delta": snapped(float(metrics.get("decoration_blocked_coverage_whole", 0.0)) - float(OWNER_ATTACHED_BASELINE.get("decoration_blocked_coverage_whole", 0.0)), 0.0001),
		"all_blocked_occupied_coverage_whole_delta": snapped(float(metrics.get("all_blocked_occupied_coverage_whole", 0.0)) - float(OWNER_ATTACHED_BASELINE.get("all_blocked_occupied_coverage_whole", 0.0)), 0.0001),
		"interpretation": "coverage/object deltas are empirical comparison signals only; exact placement and HoMM3 art/template semantics are not claimed",
	}

func _attachment_summary() -> Dictionary:
	var bytes := FileAccess.get_file_as_bytes(ATTACHED_H3M_GZ)
	if bytes.is_empty():
		_fail("Could not load owner-attached H3M gzip at %s." % ATTACHED_H3M_GZ)
		return {}
	var decompressed := bytes.decompress_dynamic(10000000, 3)
	if bytes.size() != int(OWNER_ATTACHED_BASELINE.get("gzip_bytes", 0)):
		_fail("Attached gzip size changed: %d expected %d." % [bytes.size(), int(OWNER_ATTACHED_BASELINE.get("gzip_bytes", 0))])
		return {}
	if decompressed.size() != int(OWNER_ATTACHED_BASELINE.get("decompressed_h3m_bytes", 0)):
		_fail("Attached H3M decompressed size changed: %d expected %d." % [decompressed.size(), int(OWNER_ATTACHED_BASELINE.get("decompressed_h3m_bytes", 0))])
		return {}
	var result := OWNER_ATTACHED_BASELINE.duplicate(true)
	result["path"] = ATTACHED_H3M_GZ
	result["gzip_size_verified"] = true
	result["decompressed_size_verified"] = true
	result["metric_parse_boundary"] = "gzip/decompressed bytes verified locally; object/coverage counts are owner-supplied parsed metrics for this attached H3M"
	return result

func _validate_source_catalog(catalog: Dictionary) -> Dictionary:
	var totals: Dictionary = catalog.get("totals", {}) if catalog.get("totals", {}) is Dictionary else {}
	if String(catalog.get("schema_id", "")) != "homm3_re_obstacle_proxy_catalog_v1":
		_fail("Unexpected HoMM3-re proxy catalog schema: %s" % String(catalog.get("schema_id", "")))
		return {}
	if int(totals.get("rand_trn_obstacle_rows", 0)) != 109 or int(totals.get("unique_type_names", 0)) != 33:
		_fail("HoMM3-re proxy catalog totals changed: %s" % JSON.stringify(totals))
		return {}
	var policy: Dictionary = catalog.get("source_policy", {}) if catalog.get("source_policy", {}) is Dictionary else {}
	if not String(policy.get("asset_boundary", "")).contains("no HoMM3 image/DEF assets are imported"):
		_fail("HoMM3-re proxy catalog missed legal asset boundary: %s" % JSON.stringify(policy))
		return {}
	return {
		"path": HOMM3_RE_PROXY_CATALOG,
		"schema_id": catalog.get("schema_id", ""),
		"totals": totals,
		"asset_boundary": policy.get("asset_boundary", ""),
	}

func _load_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text == "":
		return {}
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}

func _homm3_source_alias(terrain_id: String) -> String:
	if terrain_id == "underground":
		return "cave"
	if terrain_id == "mire":
		return "swamp"
	if ["dirt", "sand", "grass", "snow", "swamp", "rough", "lava", "water"].has(terrain_id):
		return terrain_id
	return "grass"

func _merge_keys(target: Dictionary, counts: Dictionary) -> void:
	for key in counts.keys():
		target[String(key)] = true

func _top_counts(counts: Dictionary, limit: int) -> Array:
	var rows := []
	for key in counts.keys():
		rows.append({"id": String(key), "count": int(counts.get(key, 0))})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("count", 0)) == int(b.get("count", 0)):
			return String(a.get("id", "")) < String(b.get("id", ""))
		return int(a.get("count", 0)) > int(b.get("count", 0))
	)
	return rows.slice(0, limit)

func _top_counts_from_keyed_presence(values: Dictionary, limit: int) -> Array:
	var rows := []
	for key in values.keys():
		rows.append({"id": String(key), "present": true})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("id", "")) < String(b.get("id", ""))
	)
	return rows.slice(0, limit)

func _point_key(x: int, y: int) -> String:
	return "%d,%d" % [x, y]

func snapped(value: float, step: float) -> float:
	if step <= 0.0:
		return value
	return round(value / step) * step

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
