extends Node

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")

const REPORT_ID = "NATIVE_RANDOM_MAP_HOMM3_SPATIAL_PLACEMENT_COMPARISON_REPORT"
const REPORT_SCHEMA_ID = "native_random_map_homm3_spatial_placement_comparison_report_v1"

const ATTACHED_H3M_GZ = "/root/.openclaw/media/inbound/Untitled---cad43d4f-6faa-4059-a9db-9b37770806af.gz"
const HOMM3_RE_OBJECT_METADATA = "/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/object-metadata-by-type.json"

const OWNER_CASE = {
	"id": "owner_like_medium_small_ring_islands",
	"seed": "1777897383",
	"template_id": "translated_rmg_template_001_v1",
	"profile_id": "translated_rmg_profile_001_v1",
	"player_count": 4,
	"water_mode": "islands",
	"underground": false,
	"size_class_id": "homm3_medium",
}

const HOMM3_VERSION_ROE = 14
const HOMM3_VERSION_AB = 21
const HOMM3_VERSION_SOD = 28

const OBJECT_TEMPLATE_RECORD_BYTES_AFTER_NAME = 42
const H3M_TILE_BYTES_PER_CELL = 7

const DECORATION_TYPE_IDS = {
	118: true, 119: true, 120: true, 134: true, 135: true, 136: true,
	137: true, 147: true, 150: true, 155: true, 199: true, 207: true,
	210: true,
}
const GUARD_TYPE_IDS = {54: true, 71: true}
const TOWN_TYPE_IDS = {98: true}
const RESOURCE_REWARD_TYPE_IDS = {5: true, 53: true, 79: true, 83: true, 88: true, 93: true, 101: true}

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

	var object_metadata = _load_homm3_object_metadata()
	if object_metadata.is_empty():
		return
	var owner = _parse_owner_h3m(object_metadata)
	if owner.is_empty():
		return
	var native = _generate_native_owner_like(service)
	if native.is_empty():
		return

	var comparison = _spatial_comparison(owner, native)
	var gate = _gate_summary(owner, native, comparison)
	if String(gate.get("status", "")) != "pass":
		_fail("Spatial placement comparison gate failed: %s" % JSON.stringify(gate))
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"schema_id": REPORT_SCHEMA_ID,
		"ok": true,
		"binding_kind": metadata.get("binding_kind", ""),
		"native_extension_loaded": metadata.get("native_extension_loaded", false),
		"owner_h3m": owner,
		"native_owner_like": native,
		"comparison": comparison,
		"gate": gate,
		"remaining_gap": "This report compares spatial distribution metrics from the owner-attached H3M against native C++ owner-like generated output. It is not byte, asset, exact object-table, or full HoMM3-re parity.",
	})])
	get_tree().quit(0)

func _generate_native_owner_like(service: Variant) -> Dictionary:
	var config = ScenarioSelectRulesScript.build_random_map_player_config(
		String(OWNER_CASE.get("seed", "")),
		String(OWNER_CASE.get("template_id", "")),
		String(OWNER_CASE.get("profile_id", "")),
		int(OWNER_CASE.get("player_count", 4)),
		String(OWNER_CASE.get("water_mode", "islands")),
		bool(OWNER_CASE.get("underground", false)),
		String(OWNER_CASE.get("size_class_id", "homm3_medium"))
	)
	var generated: Dictionary = service.generate_random_map(config, {"startup_path": "homm3_spatial_comparison_report"})
	if not bool(generated.get("ok", false)) or String(generated.get("validation_status", "")) != "pass":
		_fail("Native owner-like generation failed validation: %s" % JSON.stringify(generated.get("validation_report", generated)))
		return {}
	var normalized: Dictionary = generated.get("normalized_config", {}) if generated.get("normalized_config", {}) is Dictionary else {}
	var width = int(normalized.get("width", 0))
	var height = int(normalized.get("height", 0))
	var road_points = _native_road_points(generated)
	var land_lookup = _native_land_lookup(generated, width, height)
	var object_records = _native_spatial_records(generated)
	var metrics = _spatial_metrics("native_owner_like", width, height, land_lookup, road_points, object_records)
	metrics["template_id"] = String(normalized.get("template_id", ""))
	metrics["profile_id"] = String(normalized.get("profile_id", ""))
	metrics["seed"] = String(normalized.get("normalized_seed", ""))
	metrics["water_mode"] = String(normalized.get("water_mode", ""))
	metrics["zone_count"] = int(generated.get("zone_layout", {}).get("zone_count", 0))
	metrics["route_edge_count"] = int(generated.get("route_graph", {}).get("route_edge_count", 0))
	metrics["road_materialization_summary"] = generated.get("road_network", {}).get("road_materialization_summary", {})
	metrics["road_spread_service_stub_summary"] = generated.get("road_network", {}).get("road_spread_service_stub_summary", {})
	metrics["start_road_connection"] = _point_connection_summary(_native_start_points(generated), road_points, "start", 4)
	metrics["fill_coverage_summary"] = generated.get("fill_coverage_summary", {})
	metrics["decoration_route_shaping_summary"] = generated.get("decoration_route_shaping_summary", {})
	return metrics

func _parse_owner_h3m(object_metadata: Dictionary) -> Dictionary:
	var compressed = FileAccess.get_file_as_bytes(ATTACHED_H3M_GZ)
	if compressed.is_empty():
		_fail("Could not read owner H3M gzip at %s." % ATTACHED_H3M_GZ)
		return {}
	var bytes = compressed.decompress_dynamic(10000000, 3)
	if bytes.is_empty():
		_fail("Could not decompress owner H3M gzip.")
		return {}
	var version = _u32(bytes, 0)
	if version not in [HOMM3_VERSION_ROE, HOMM3_VERSION_AB, HOMM3_VERSION_SOD]:
		_fail("Unexpected H3M version %d." % version)
		return {}
	var width = _u32(bytes, 5)
	var height = width
	if width != 72:
		_fail("Owner H3M size changed from expected 72x72: %d." % width)
		return {}
	var def_offset = _find_object_definition_offset(bytes)
	if def_offset <= 0:
		_fail("Could not locate H3M object-definition table.")
		return {}
	var tile_offset = def_offset - int(width * height * H3M_TILE_BYTES_PER_CELL)
	if tile_offset <= 0:
		_fail("Computed invalid H3M tile-stream offset: %d." % tile_offset)
		return {}
	var templates = _parse_h3m_object_templates(bytes, def_offset, object_metadata)
	if templates.is_empty():
		return {}
	var instance_offset = int(templates.get("next_offset", 0))
	var objects = _parse_h3m_object_instances(bytes, instance_offset, templates.get("templates", []))
	if objects.is_empty():
		return {}
	var road_points = _h3m_road_points(bytes, tile_offset, width, height)
	var land_lookup = _h3m_land_lookup(bytes, tile_offset, width, height)
	var records = _h3m_spatial_records(objects)
	var metrics = _spatial_metrics("owner_h3m", width, height, land_lookup, road_points, records)
	metrics["path"] = ATTACHED_H3M_GZ
	metrics["gzip_bytes"] = compressed.size()
	metrics["decompressed_h3m_bytes"] = bytes.size()
	metrics["version"] = version
	metrics["object_definition_offset"] = def_offset
	metrics["tile_stream_offset"] = tile_offset
	metrics["object_definition_count"] = int(templates.get("template_count", 0))
	metrics["object_instance_table_offset"] = instance_offset
	metrics["object_instance_parse_tail_bytes"] = int(objects.get("tail_bytes", 0))
	metrics["object_template_top_defs"] = _top_counts(metrics.get("object_def_counts", {}), 12)
	return metrics

func _parse_h3m_object_templates(bytes: PackedByteArray, offset: int, object_metadata: Dictionary) -> Dictionary:
	var count = _u32(bytes, offset)
	if count <= 0 or count > 2000:
		_fail("Invalid H3M object definition count at %d: %d." % [offset, count])
		return {}
	var pos = offset + 4
	var templates = []
	for index in range(count):
		if pos + 4 > bytes.size():
			_fail("Object definition table ended early at index %d." % index)
			return {}
		var name_len = _u32(bytes, pos)
		pos += 4
		if name_len <= 0 or name_len > 128 or pos + name_len + OBJECT_TEMPLATE_RECORD_BYTES_AFTER_NAME > bytes.size():
			_fail("Invalid object definition name length %d at index %d." % [name_len, index])
			return {}
		var def_name = _ascii(bytes, pos, name_len)
		pos += name_len
		var rest_offset = pos
		pos += OBJECT_TEMPLATE_RECORD_BYTES_AFTER_NAME
		var type_id = _u32(bytes, rest_offset + 16)
		var subtype = _u32(bytes, rest_offset + 20)
		var record = {
			"template_index": index,
			"def_name": def_name,
			"type_id": type_id,
			"type_name": String(object_metadata.get(str(type_id), "type_%d" % type_id)),
			"subtype": subtype,
			"group": int(bytes[rest_offset + 24]),
			"overlay_flag": int(bytes[rest_offset + 25]),
		}
		templates.append(record)
	return {
		"template_count": count,
		"templates": templates,
		"next_offset": pos,
	}

func _parse_h3m_object_instances(bytes: PackedByteArray, offset: int, templates: Array) -> Dictionary:
	var count = _u32(bytes, offset)
	if count <= 0 or count > 5000:
		_fail("Invalid H3M placed object count at %d: %d." % [offset, count])
		return {}
	var pos = offset + 4
	var records = []
	var skip_counts = {}
	for index in range(count):
		if not _is_h3m_object_instance_start(bytes, pos, templates.size()):
			_fail("Could not parse H3M placed object %d at offset %d." % [index, pos])
			return {}
		var template_index = _u32(bytes, pos + 3)
		var template: Dictionary = templates[template_index]
		var record = template.duplicate(true)
		record["object_index"] = index
		record["x"] = int(bytes[pos])
		record["y"] = int(bytes[pos + 1])
		record["level"] = int(bytes[pos + 2])
		record["offset"] = pos
		record["category"] = _h3m_category_for_record(record)
		records.append(record)
		var next_min = pos + 12
		if index == count - 1:
			pos = next_min
			break
		var found = -1
		for extra in range(0, 320):
			var candidate = next_min + extra
			if _is_h3m_object_instance_start(bytes, candidate, templates.size()):
				found = candidate
				skip_counts[str(extra)] = int(skip_counts.get(str(extra), 0)) + 1
				break
		if found < 0:
			_fail("Could not find next H3M object instance after index %d at offset %d." % [index, pos])
			return {}
		pos = found
	return {
		"records": records,
		"object_count": records.size(),
		"next_offset": pos,
		"tail_bytes": bytes.size() - pos,
		"instance_extra_skip_counts": skip_counts,
	}

func _is_h3m_object_instance_start(bytes: PackedByteArray, pos: int, template_count: int) -> bool:
	if pos < 0 or pos + 12 > bytes.size():
		return false
	var x = int(bytes[pos])
	var y = int(bytes[pos + 1])
	var z = int(bytes[pos + 2])
	var template_index = _u32(bytes, pos + 3)
	if x < 0 or y < 0 or x >= 72 or y >= 72 or z != 0:
		return false
	if template_index < 0 or template_index >= template_count:
		return false
	for index in range(5):
		if int(bytes[pos + 7 + index]) != 0:
			return false
	return true

func _find_object_definition_offset(bytes: PackedByteArray) -> int:
	for offset in range(0, bytes.size() - 32):
		var count = _u32(bytes, offset)
		if count < 50 or count > 1000:
			continue
		var name_len = _u32(bytes, offset + 4)
		if name_len < 4 or name_len > 32:
			continue
		var name = _ascii(bytes, offset + 8, name_len)
		if name.to_lower().ends_with(".def"):
			return offset
	return -1

func _h3m_category_for_record(record: Dictionary) -> String:
	var type_id = int(record.get("type_id", -1))
	var name = String(record.get("type_name", "")).to_lower()
	if DECORATION_TYPE_IDS.has(type_id):
		return "decoration"
	if GUARD_TYPE_IDS.has(type_id) or name.contains("monster"):
		return "guard"
	if TOWN_TYPE_IDS.has(type_id):
		return "town"
	if RESOURCE_REWARD_TYPE_IDS.has(type_id) or name.contains("resource") or name.contains("mine") or name.contains("artifact") or name.contains("shrine"):
		return "reward"
	return "object"

func _h3m_spatial_records(objects: Dictionary) -> Array:
	var result = []
	var records: Array = objects.get("records", [])
	for object in records:
		if not (object is Dictionary):
			continue
		var record: Dictionary = object
		result.append({
			"x": int(record.get("x", 0)),
			"y": int(record.get("y", 0)),
			"kind": String(record.get("category", "object")),
			"source_kind": String(record.get("type_name", "")),
			"def_name": String(record.get("def_name", "")),
		})
	return result

func _native_spatial_records(generated: Dictionary) -> Array:
	var result = []
	var objects: Array = generated.get("object_placements", []) if generated.get("object_placements", []) is Array else []
	var towns: Array = generated.get("town_records", []) if generated.get("town_records", []) is Array else []
	var guards: Array = generated.get("guard_records", []) if generated.get("guard_records", []) is Array else []
	for object in objects:
		if not (object is Dictionary):
			continue
		var kind = String(object.get("kind", "object"))
		var category = "object"
		if kind == "decorative_obstacle":
			category = "decoration"
		elif kind in ["resource_site", "mine", "neutral_dwelling", "reward_reference"]:
			category = "reward"
		result.append({
			"x": int(object.get("x", 0)),
			"y": int(object.get("y", 0)),
			"kind": category,
			"source_kind": kind,
			"def_name": String(object.get("object_id", object.get("family_id", ""))),
		})
	for town in towns:
		if town is Dictionary:
			result.append({"x": int(town.get("x", 0)), "y": int(town.get("y", 0)), "kind": "town", "source_kind": "town", "def_name": String(town.get("town_id", ""))})
	for guard in guards:
		if guard is Dictionary:
			result.append({"x": int(guard.get("x", 0)), "y": int(guard.get("y", 0)), "kind": "guard", "source_kind": "guard", "def_name": String(guard.get("guard_kind", ""))})
	return result

func _spatial_metrics(id: String, width: int, height: int, land_lookup: Dictionary, road_points: Array, records: Array) -> Dictionary:
	var road_lookup = _point_lookup(road_points)
	var by_kind = {}
	var object_def_counts = {}
	var category_points = {
		"all_content": [],
		"decoration": [],
		"reward": [],
		"guard": [],
		"town": [],
		"object": [],
	}
	for record in records:
		if not (record is Dictionary):
			continue
		var kind = String(record.get("kind", "object"))
		by_kind[kind] = int(by_kind.get(kind, 0)) + 1
		var point = _point(int(record.get("x", 0)), int(record.get("y", 0)))
		category_points["all_content"].append(point)
		if category_points.has(kind):
			category_points[kind].append(point)
		else:
			category_points["object"].append(point)
		var def_name = String(record.get("def_name", ""))
		if def_name != "":
			object_def_counts[def_name] = int(object_def_counts.get(def_name, 0)) + 1
	var land_tile_count = land_lookup.size()
	var map_tiles = max(1, width * height)
	var result = {
		"id": id,
		"width": width,
		"height": height,
		"map_tile_count": map_tiles,
		"land_tile_count": land_tile_count,
		"land_coverage_ratio": snapped(float(land_tile_count) / float(map_tiles), 0.0001),
		"object_count": records.size(),
		"counts_by_category": by_kind,
		"object_def_counts": object_def_counts,
		"road_tile_count": road_points.size(),
		"road_coverage_whole": snapped(float(road_points.size()) / float(map_tiles), 0.0001),
		"road_coverage_land": snapped(float(road_points.size()) / float(max(1, land_tile_count)), 0.0001),
		"road_quadrants": _distribution_for_points(road_points, width, height, 2, 2),
		"road_grid_6x6": _distribution_for_points(road_points, width, height, 6, 6),
		"road_topology": _road_topology_summary(road_points),
		"largest_roadless_land_region": _largest_roadless_land_region(land_lookup, road_lookup, width, height, 6, 6),
		"town_road_connection": _point_connection_summary(category_points.get("town", []), road_points, "town", 4),
		"quadrants": _quadrant_distribution(category_points, width, height),
		"coarse_grid_6x6": _coarse_grid_distribution(category_points, width, height, 6, 6),
		"nearest_neighbor": _nearest_neighbor_summary(category_points),
		"distance_to_road": _distance_to_points_summary(category_points, road_points, "road"),
		"road_adjacency": _road_adjacency_summary(category_points, road_lookup),
		"largest_low_content_region": _largest_low_content_region(category_points.get("all_content", []), width, height, 6, 6, 1),
	}
	return result

func _spatial_comparison(owner: Dictionary, native: Dictionary) -> Dictionary:
	var owner_grid: Dictionary = owner.get("coarse_grid_6x6", {})
	var native_grid: Dictionary = native.get("coarse_grid_6x6", {})
	var owner_road: Dictionary = owner.get("distance_to_road", {})
	var native_road: Dictionary = native.get("distance_to_road", {})
	var owner_nn: Dictionary = owner.get("nearest_neighbor", {})
	var native_nn: Dictionary = native.get("nearest_neighbor", {})
	var owner_topology: Dictionary = owner.get("road_topology", {})
	var native_topology: Dictionary = native.get("road_topology", {})
	return {
		"object_count_delta": int(native.get("object_count", 0)) - int(owner.get("object_count", 0)),
		"road_tile_delta": int(native.get("road_tile_count", 0)) - int(owner.get("road_tile_count", 0)),
		"road_coverage_land_delta": snapped(float(native.get("road_coverage_land", 0.0)) - float(owner.get("road_coverage_land", 0.0)), 0.0001),
		"road_grid_nonempty_delta": int(native.get("road_grid_6x6", {}).get("nonempty_cell_count", 0)) - int(owner.get("road_grid_6x6", {}).get("nonempty_cell_count", 0)),
		"road_quadrant_cv_delta": snapped(float(native.get("road_quadrants", {}).get("coefficient_of_variation", 0.0)) - float(owner.get("road_quadrants", {}).get("coefficient_of_variation", 0.0)), 0.0001),
		"largest_roadless_land_region_delta": int(native.get("largest_roadless_land_region", {}).get("largest_region_cell_count", 0)) - int(owner.get("largest_roadless_land_region", {}).get("largest_region_cell_count", 0)),
		"road_endpoint_delta": int(native_topology.get("endpoint_count", 0)) - int(owner_topology.get("endpoint_count", 0)),
		"road_branch_delta": int(native_topology.get("branch_count", 0)) - int(owner_topology.get("branch_count", 0)),
		"road_intersection_delta": int(native_topology.get("intersection_count", 0)) - int(owner_topology.get("intersection_count", 0)),
		"decoration_grid_nonempty_delta": _nested_int(native_grid, "decoration", "nonempty_cell_count") - _nested_int(owner_grid, "decoration", "nonempty_cell_count"),
		"reward_grid_nonempty_delta": _nested_int(native_grid, "reward", "nonempty_cell_count") - _nested_int(owner_grid, "reward", "nonempty_cell_count"),
		"all_content_grid_cv_delta": snapped(_nested_float(native_grid, "all_content", "coefficient_of_variation") - _nested_float(owner_grid, "all_content", "coefficient_of_variation"), 0.0001),
		"reward_avg_distance_to_road_delta": snapped(_nested_float(native_road, "reward", "average_distance_to_road") - _nested_float(owner_road, "reward", "average_distance_to_road"), 0.001),
		"reward_road_adjacent_ratio_delta": snapped(_nested_float(native.get("road_adjacency", {}), "reward", "road_adjacent_ratio") - _nested_float(owner.get("road_adjacency", {}), "reward", "road_adjacent_ratio"), 0.0001),
		"reward_within_4_tiles_ratio_delta": snapped(_nested_float(native_road, "reward", "within_4_tiles_ratio") - _nested_float(owner_road, "reward", "within_4_tiles_ratio"), 0.0001),
		"town_road_connection_delta": snapped(float(native.get("town_road_connection", {}).get("connected_ratio", 0.0)) - float(owner.get("town_road_connection", {}).get("connected_ratio", 0.0)), 0.0001),
		"decoration_avg_nearest_neighbor_delta": snapped(_nested_float(native_nn, "decoration", "average_nearest_neighbor") - _nested_float(owner_nn, "decoration", "average_nearest_neighbor"), 0.001),
		"largest_low_content_region_delta": int(native.get("largest_low_content_region", {}).get("largest_region_cell_count", 0)) - int(owner.get("largest_low_content_region", {}).get("largest_region_cell_count", 0)),
		"interpretation": "Road parity is judged by layout shape and interaction metrics, not only road count. Remaining deltas are evidence for future HoMM3-re route authoring work, not a full parity claim.",
	}

func _gate_summary(owner: Dictionary, native: Dictionary, comparison: Dictionary) -> Dictionary:
	var failures = []
	var warnings = []
	if int(owner.get("object_count", 0)) != 496:
		failures.append("owner_object_count_parse_changed")
	if int(owner.get("road_tile_count", 0)) != 184:
		failures.append("owner_road_tile_parse_changed")
	if int(native.get("object_count", 0)) < int(owner.get("object_count", 0)):
		failures.append("native_object_count_too_low_for_spatial_comparison")
	var owner_counts: Dictionary = owner.get("counts_by_category", {}) if owner.get("counts_by_category", {}) is Dictionary else {}
	var native_counts: Dictionary = native.get("counts_by_category", {}) if native.get("counts_by_category", {}) is Dictionary else {}
	for category in ["decoration", "guard", "object", "reward", "town"]:
		if int(native_counts.get(category, 0)) < int(owner_counts.get(category, 0)):
			failures.append("native_%s_count_below_owner_spatial_baseline" % category)
	if abs(int(comparison.get("road_tile_delta", 999))) > 24:
		failures.append("native_road_tile_count_too_far_from_owner")
	if abs(float(comparison.get("road_coverage_land_delta", 99.0))) > 0.03:
		failures.append("native_road_land_density_too_far_from_owner")
	if int(native.get("road_grid_6x6", {}).get("nonempty_cell_count", 0)) < max(12, int(owner.get("road_grid_6x6", {}).get("nonempty_cell_count", 0)) - 2):
		failures.append("native_road_grid_spread_too_low")
	if int(native.get("largest_roadless_land_region", {}).get("largest_region_cell_count", 99)) > int(owner.get("largest_roadless_land_region", {}).get("largest_region_cell_count", 0)) + 3:
		failures.append("native_largest_roadless_land_region_too_large")
	if int(native.get("road_topology", {}).get("endpoint_count", 0)) <= 0:
		failures.append("native_roads_have_no_branch_endpoints")
	if int(native.get("road_topology", {}).get("branch_count", 0)) < int(owner.get("road_topology", {}).get("branch_count", 0)):
		failures.append("native_road_branch_count_below_owner")
	if int(native.get("road_topology", {}).get("endpoint_count", 0)) < int(owner.get("road_topology", {}).get("endpoint_count", 0)):
		failures.append("native_road_endpoint_count_below_owner")
	if int(native.get("road_topology", {}).get("endpoint_count", 0)) > int(owner.get("road_topology", {}).get("endpoint_count", 0)) + 4:
		failures.append("native_road_endpoint_count_overshot_owner")
	if int(native.get("town_road_connection", {}).get("connected_count", 0)) < int(owner.get("town_road_connection", {}).get("connected_count", 0)):
		failures.append("native_town_road_connections_below_owner")
	if int(native.get("town_road_connection", {}).get("max", 999)) > int(owner.get("town_road_connection", {}).get("max", 0)) + 2:
		failures.append("native_town_road_connection_distance_too_high")
	if _nested_int(native.get("coarse_grid_6x6", {}), "reward", "nonempty_cell_count") < 12:
		failures.append("native_rewards_too_spatially_collapsed")
	if _nested_float(native.get("distance_to_road", {}), "reward", "average_distance_to_road") < 5.0:
		failures.append("native_rewards_still_overbiased_to_roads")
	if _nested_float(native.get("distance_to_road", {}), "reward", "average_distance_to_road") > 10.0:
		failures.append("native_rewards_too_far_from_roads")
	if _nested_float(native.get("distance_to_road", {}), "reward", "within_4_tiles_ratio") > 0.50:
		failures.append("native_rewards_still_too_road_adjacent")
	if _nested_float(native.get("distance_to_road", {}), "reward", "within_4_tiles_ratio") < 0.30:
		failures.append("native_rewards_not_road_reachable_enough")
	if _nested_float(native.get("distance_to_road", {}), "reward", "within_1_tile_ratio") > 0.14:
		failures.append("native_rewards_too_directly_road_adjacent")
	if _nested_float(native.get("quadrants", {}), "all_content", "coefficient_of_variation") > 0.45:
		failures.append("native_all_content_quadrant_skew_too_high")
	if _nested_float(native.get("quadrants", {}), "reward", "coefficient_of_variation") > 0.45:
		failures.append("native_reward_quadrant_skew_too_high")
	if int(native.get("largest_low_content_region", {}).get("largest_region_cell_count", 99)) > int(owner.get("largest_low_content_region", {}).get("largest_region_cell_count", 0)) + 1:
		failures.append("native_low_content_region_too_large")
	if _nested_float(native.get("nearest_neighbor", {}), "decoration", "average_nearest_neighbor") < 2.0:
		failures.append("native_decorations_clumped_too_tightly")
	if _nested_float(native.get("distance_to_road", {}), "reward", "within_4_tiles_ratio") > _nested_float(owner.get("distance_to_road", {}), "reward", "within_4_tiles_ratio") + 0.08:
		warnings.append("native_rewards_still_somewhat_more_road_adjacent_than_owner")
	return {
		"status": "pass" if failures.is_empty() else "fail",
		"failures": failures,
		"warnings": warnings,
		"thresholds": {
			"owner_object_count": 496,
			"owner_road_tiles": 184,
			"native_min_object_count": int(owner.get("object_count", 0)),
			"native_min_counts_by_category": owner_counts,
			"native_max_abs_road_tile_delta": 24,
			"native_max_abs_road_coverage_land_delta": 0.03,
			"native_min_road_nonempty_6x6_cells": max(12, int(owner.get("road_grid_6x6", {}).get("nonempty_cell_count", 0)) - 2),
			"native_min_road_branch_count": int(owner.get("road_topology", {}).get("branch_count", 0)),
			"native_min_road_endpoint_count": int(owner.get("road_topology", {}).get("endpoint_count", 0)),
			"native_max_road_endpoint_count_over_owner": 4,
			"native_min_town_road_connected_count": int(owner.get("town_road_connection", {}).get("connected_count", 0)),
			"native_max_town_road_distance_over_owner": 2,
			"native_max_largest_roadless_land_region_over_owner": 3,
			"native_min_reward_nonempty_6x6_cells": 12,
			"native_min_reward_average_distance_to_road": 5.0,
			"native_max_reward_average_distance_to_road": 10.0,
			"native_max_reward_within_1_tile_of_road_ratio": 0.14,
			"native_min_reward_within_4_tiles_of_road_ratio": 0.30,
			"native_max_reward_within_4_tiles_of_road_ratio": 0.50,
			"native_max_all_content_quadrant_cv": 0.45,
			"native_max_reward_quadrant_cv": 0.45,
			"native_max_largest_low_content_region_over_owner": 1,
			"native_min_decoration_average_nearest_neighbor": 2.0,
		},
		"comparison_snapshot": comparison,
	}

func _quadrant_distribution(category_points: Dictionary, width: int, height: int) -> Dictionary:
	var result = {}
	for kind in category_points.keys():
		var counts = {"nw": 0, "ne": 0, "sw": 0, "se": 0}
		for point in category_points[kind]:
			var x = int(point.get("x", 0))
			var y = int(point.get("y", 0))
			var key = ("n" if y < height / 2 else "s") + ("w" if x < width / 2 else "e")
			counts[key] = int(counts.get(key, 0)) + 1
		result[kind] = _distribution_summary_from_counts(counts.values())
		result[kind]["counts"] = counts
	return result

func _coarse_grid_distribution(category_points: Dictionary, width: int, height: int, cols: int, rows: int) -> Dictionary:
	var result = {}
	for kind in category_points.keys():
		var counts = []
		for _index in range(cols * rows):
			counts.append(0)
		for point in category_points[kind]:
			var cx = clampi(int(floor(float(int(point.get("x", 0))) * float(cols) / float(max(1, width)))), 0, cols - 1)
			var cy = clampi(int(floor(float(int(point.get("y", 0))) * float(rows) / float(max(1, height)))), 0, rows - 1)
			var index = cy * cols + cx
			counts[index] = int(counts[index]) + 1
		var summary = _distribution_summary_from_counts(counts)
		summary["cols"] = cols
		summary["rows"] = rows
		summary["counts"] = counts
		result[kind] = summary
	return result

func _nearest_neighbor_summary(category_points: Dictionary) -> Dictionary:
	var result = {}
	for kind in category_points.keys():
		var points: Array = category_points[kind]
		var distances = []
		for index in range(points.size()):
			var best = 999999
			for other_index in range(points.size()):
				if index == other_index:
					continue
				var distance = _manhattan(points[index], points[other_index])
				if distance < best:
					best = distance
			if best < 999999:
				distances.append(best)
		var summary = _distribution_summary_from_counts(distances)
		summary["average_nearest_neighbor"] = summary.get("average", 0.0)
		summary["close_pair_ratio_le_2"] = _ratio_lte(distances, 2)
		summary["close_pair_ratio_le_4"] = _ratio_lte(distances, 4)
		result[kind] = summary
	return result

func _distance_to_points_summary(category_points: Dictionary, targets: Array, label: String) -> Dictionary:
	var result = {}
	for kind in category_points.keys():
		var distances = []
		for point in category_points[kind]:
			var best = _nearest_distance(point, targets)
			if best >= 0:
				distances.append(best)
		var summary = _distribution_summary_from_counts(distances)
		summary["average_distance_to_%s" % label] = summary.get("average", 0.0)
		summary["within_1_tile_ratio"] = _ratio_lte(distances, 1)
		summary["within_4_tiles_ratio"] = _ratio_lte(distances, 4)
		result[kind] = summary
	return result

func _road_adjacency_summary(category_points: Dictionary, road_lookup: Dictionary) -> Dictionary:
	var result = {}
	for kind in category_points.keys():
		var total = 0
		var adjacent = 0
		var within4 = 0
		for point in category_points[kind]:
			total += 1
			var distance = _nearest_distance_to_lookup(point, road_lookup, 4)
			if distance >= 0 and distance <= 1:
				adjacent += 1
			if distance >= 0 and distance <= 4:
				within4 += 1
		result[kind] = {
			"count": total,
			"road_adjacent_count": adjacent,
			"within_4_tiles_count": within4,
			"road_adjacent_ratio": snapped(float(adjacent) / float(max(1, total)), 0.0001),
			"within_4_tiles_ratio": snapped(float(within4) / float(max(1, total)), 0.0001),
		}
	return result

func _distribution_for_points(points: Array, width: int, height: int, cols: int, rows: int) -> Dictionary:
	var counts = []
	for _index in range(cols * rows):
		counts.append(0)
	for point in points:
		if not (point is Dictionary):
			continue
		var cx = clampi(int(floor(float(int(point.get("x", 0))) * float(cols) / float(max(1, width)))), 0, cols - 1)
		var cy = clampi(int(floor(float(int(point.get("y", 0))) * float(rows) / float(max(1, height)))), 0, rows - 1)
		counts[cy * cols + cx] = int(counts[cy * cols + cx]) + 1
	var summary = _distribution_summary_from_counts(counts)
	summary["cols"] = cols
	summary["rows"] = rows
	summary["counts"] = counts
	return summary

func _road_topology_summary(road_points: Array) -> Dictionary:
	var lookup := _point_lookup(road_points)
	var degree_counts := {}
	var endpoint_count := 0
	var trunk_count := 0
	var branch_count := 0
	var intersection_count := 0
	for point in road_points:
		if not (point is Dictionary):
			continue
		var degree := 0
		var x := int(point.get("x", 0))
		var y := int(point.get("y", 0))
		for offset in [_point(1, 0), _point(-1, 0), _point(0, 1), _point(0, -1)]:
			if lookup.has(_point_key(x + int(offset.get("x", 0)), y + int(offset.get("y", 0)))):
				degree += 1
		degree_counts[str(degree)] = int(degree_counts.get(str(degree), 0)) + 1
		if degree <= 1:
			endpoint_count += 1
		elif degree == 2:
			trunk_count += 1
		elif degree == 3:
			branch_count += 1
		else:
			intersection_count += 1
	return {
		"road_tile_count": road_points.size(),
		"degree_counts": degree_counts,
		"endpoint_count": endpoint_count,
		"trunk_count": trunk_count,
		"branch_count": branch_count,
		"intersection_count": intersection_count,
		"endpoint_ratio": snapped(float(endpoint_count) / float(max(1, road_points.size())), 0.0001),
		"branch_intersection_ratio": snapped(float(branch_count + intersection_count) / float(max(1, road_points.size())), 0.0001),
	}

func _largest_roadless_land_region(land_lookup: Dictionary, road_lookup: Dictionary, width: int, height: int, cols: int, rows: int) -> Dictionary:
	var road_counts = []
	var land_counts = []
	for _index in range(cols * rows):
		road_counts.append(0)
		land_counts.append(0)
	for key in land_lookup.keys():
		var parts := String(key).split(",")
		if parts.size() != 2:
			continue
		var x := int(parts[0])
		var y := int(parts[1])
		var cx = clampi(int(floor(float(x) * float(cols) / float(max(1, width)))), 0, cols - 1)
		var cy = clampi(int(floor(float(y) * float(rows) / float(max(1, height)))), 0, rows - 1)
		land_counts[cy * cols + cx] = int(land_counts[cy * cols + cx]) + 1
	for key in road_lookup.keys():
		var parts := String(key).split(",")
		if parts.size() != 2:
			continue
		var x := int(parts[0])
		var y := int(parts[1])
		var cx = clampi(int(floor(float(x) * float(cols) / float(max(1, width)))), 0, cols - 1)
		var cy = clampi(int(floor(float(y) * float(rows) / float(max(1, height)))), 0, rows - 1)
		road_counts[cy * cols + cx] = int(road_counts[cy * cols + cx]) + 1
	var visited = {}
	var largest = 0
	for y in range(rows):
		for x in range(cols):
			var key := _point_key(x, y)
			var index := y * cols + x
			if visited.has(key) or int(land_counts[index]) <= 0 or int(road_counts[index]) > 0:
				continue
			var size := 0
			var queue = [_point(x, y)]
			visited[key] = true
			while not queue.is_empty():
				var current: Dictionary = queue.pop_front()
				size += 1
				for offset in [_point(1, 0), _point(-1, 0), _point(0, 1), _point(0, -1)]:
					var nx := int(current.get("x", 0)) + int(offset.get("x", 0))
					var ny := int(current.get("y", 0)) + int(offset.get("y", 0))
					if nx < 0 or ny < 0 or nx >= cols or ny >= rows:
						continue
					var nkey := _point_key(nx, ny)
					var nindex := ny * cols + nx
					if visited.has(nkey) or int(land_counts[nindex]) <= 0 or int(road_counts[nindex]) > 0:
						continue
					visited[nkey] = true
					queue.append(_point(nx, ny))
			largest = max(largest, size)
	return {
		"cols": cols,
		"rows": rows,
		"largest_region_cell_count": largest,
		"largest_region_ratio": snapped(float(largest) / float(max(1, cols * rows)), 0.0001),
		"road_counts": road_counts,
		"land_counts": land_counts,
	}

func _point_connection_summary(points: Array, roads: Array, label: String, max_distance: int) -> Dictionary:
	var distances = []
	var connected := 0
	for point in points:
		if not (point is Dictionary):
			continue
		var distance := _nearest_distance(point, roads)
		if distance >= 0:
			distances.append(distance)
			if distance <= max_distance:
				connected += 1
	var summary := _distribution_summary_from_counts(distances)
	summary["label"] = label
	summary["max_connected_distance"] = max_distance
	summary["point_count"] = points.size()
	summary["connected_count"] = connected
	summary["connected_ratio"] = snapped(float(connected) / float(max(1, points.size())), 0.0001)
	return summary

func _largest_low_content_region(points: Array, width: int, height: int, cols: int, rows: int, max_count: int) -> Dictionary:
	var counts = []
	for _index in range(cols * rows):
		counts.append(0)
	for point in points:
		var cx = clampi(int(floor(float(int(point.get("x", 0))) * float(cols) / float(max(1, width)))), 0, cols - 1)
		var cy = clampi(int(floor(float(int(point.get("y", 0))) * float(rows) / float(max(1, height)))), 0, rows - 1)
		counts[cy * cols + cx] = int(counts[cy * cols + cx]) + 1
	var visited = {}
	var largest = 0
	for y in range(rows):
		for x in range(cols):
			var key = _point_key(x, y)
			var index = y * cols + x
			if visited.has(key) or int(counts[index]) > max_count:
				continue
			var size = 0
			var queue = [_point(x, y)]
			visited[key] = true
			while not queue.is_empty():
				var current: Dictionary = queue.pop_front()
				size += 1
				for offset in [_point(1, 0), _point(-1, 0), _point(0, 1), _point(0, -1)]:
					var nx = int(current.get("x", 0)) + int(offset.get("x", 0))
					var ny = int(current.get("y", 0)) + int(offset.get("y", 0))
					if nx < 0 or ny < 0 or nx >= cols or ny >= rows:
						continue
					var nkey = _point_key(nx, ny)
					var nindex = ny * cols + nx
					if visited.has(nkey) or int(counts[nindex]) > max_count:
						continue
					visited[nkey] = true
					queue.append(_point(nx, ny))
			largest = max(largest, size)
	return {
		"cols": cols,
		"rows": rows,
		"max_count_per_low_content_cell": max_count,
		"largest_region_cell_count": largest,
		"largest_region_ratio": snapped(float(largest) / float(max(1, cols * rows)), 0.0001),
		"counts": counts,
	}

func _distribution_summary_from_counts(values: Array) -> Dictionary:
	var total = 0.0
	var nonempty = 0
	var min_value = 999999
	var max_value = 0
	for value in values:
		var v = int(value)
		total += float(v)
		if v > 0:
			nonempty += 1
		min_value = min(min_value, v)
		max_value = max(max_value, v)
	var average = total / float(max(1, values.size()))
	var variance = 0.0
	for value in values:
		var delta = float(int(value)) - average
		variance += delta * delta
	var stddev = sqrt(variance / float(max(1, values.size())))
	return {
		"cell_count": values.size(),
		"total": int(total),
		"nonempty_cell_count": nonempty,
		"empty_cell_count": values.size() - nonempty,
		"min": 0 if min_value == 999999 else min_value,
		"max": max_value,
		"average": snapped(average, 0.001),
		"stddev": snapped(stddev, 0.001),
		"coefficient_of_variation": snapped(stddev / max(0.001, average), 0.0001),
	}

func _h3m_road_points(bytes: PackedByteArray, tile_offset: int, width: int, height: int) -> Array:
	var points = []
	for y in range(height):
		for x in range(width):
			var offset = tile_offset + (y * width + x) * H3M_TILE_BYTES_PER_CELL
			if int(bytes[offset + 4]) != 0:
				points.append(_point(x, y))
	return points

func _h3m_land_lookup(bytes: PackedByteArray, tile_offset: int, width: int, height: int) -> Dictionary:
	var land = {}
	for y in range(height):
		for x in range(width):
			var offset = tile_offset + (y * width + x) * H3M_TILE_BYTES_PER_CELL
			var terrain_id = int(bytes[offset])
			if terrain_id != 8:
				land[_point_key(x, y)] = true
	return land

func _native_road_points(generated: Dictionary) -> Array:
	var points = []
	var seen = {}
	var segments: Array = generated.get("road_network", {}).get("road_segments", []) if generated.get("road_network", {}).get("road_segments", []) is Array else []
	for segment in segments:
		if not (segment is Dictionary):
			continue
		for cell in segment.get("cells", []):
			if cell is Dictionary:
				var key = _point_key(int(cell.get("x", 0)), int(cell.get("y", 0)))
				if not seen.has(key):
					seen[key] = true
					points.append(_point(int(cell.get("x", 0)), int(cell.get("y", 0))))
	return points

func _native_start_points(generated: Dictionary) -> Array:
	var points = []
	var starts: Array = generated.get("player_starts", {}).get("starts", []) if generated.get("player_starts", {}).get("starts", []) is Array else []
	for start in starts:
		if start is Dictionary:
			points.append(_point(int(start.get("x", 0)), int(start.get("y", 0))))
	return points

func _native_land_lookup(generated: Dictionary, width: int, height: int) -> Dictionary:
	var land = {}
	var grid: Dictionary = generated.get("terrain_grid", {}) if generated.get("terrain_grid", {}) is Dictionary else {}
	var ids: PackedStringArray = grid.get("terrain_id_by_code", PackedStringArray())
	var levels: Array = grid.get("levels", []) if grid.get("levels", []) is Array else []
	if levels.is_empty() or ids.is_empty():
		for y in range(height):
			for x in range(width):
				land[_point_key(x, y)] = true
		return land
	var level: Dictionary = levels[0]
	var codes: PackedInt32Array = level.get("terrain_code_u16", PackedInt32Array())
	for index in range(min(codes.size(), width * height)):
		var code = int(codes[index])
		var terrain_id = String(ids[code]) if code >= 0 and code < ids.size() else "grass"
		if terrain_id != "water":
			land[_point_key(index % width, index / width)] = true
	return land

func _point_lookup(points: Array) -> Dictionary:
	var result = {}
	for point in points:
		if point is Dictionary:
			result[_point_key(int(point.get("x", 0)), int(point.get("y", 0)))] = true
	return result

func _nearest_distance(point: Dictionary, targets: Array) -> int:
	if targets.is_empty():
		return -1
	var best = 999999
	for target in targets:
		if target is Dictionary:
			best = min(best, _manhattan(point, target))
	return best if best < 999999 else -1

func _nearest_distance_to_lookup(point: Dictionary, lookup: Dictionary, limit: int) -> int:
	var px = int(point.get("x", 0))
	var py = int(point.get("y", 0))
	for radius in range(limit + 1):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if abs(dx) + abs(dy) != radius:
					continue
				if lookup.has(_point_key(px + dx, py + dy)):
					return radius
	return -1

func _manhattan(left: Dictionary, right: Dictionary) -> int:
	return abs(int(left.get("x", 0)) - int(right.get("x", 0))) + abs(int(left.get("y", 0)) - int(right.get("y", 0)))

func _ratio_lte(values: Array, limit: int) -> float:
	if values.is_empty():
		return 0.0
	var count = 0
	for value in values:
		if int(value) <= limit:
			count += 1
	return snapped(float(count) / float(values.size()), 0.0001)

func _top_counts(counts: Dictionary, limit: int) -> Array:
	var rows = []
	for key in counts.keys():
		rows.append({"id": String(key), "count": int(counts.get(key, 0))})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("count", 0)) == int(b.get("count", 0)):
			return String(a.get("id", "")) < String(b.get("id", ""))
		return int(a.get("count", 0)) > int(b.get("count", 0))
	)
	return rows.slice(0, limit)

func _load_homm3_object_metadata() -> Dictionary:
	var text = FileAccess.get_file_as_string(HOMM3_RE_OBJECT_METADATA)
	if text == "":
		_fail("Could not load HoMM3-re object metadata at %s." % HOMM3_RE_OBJECT_METADATA)
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		_fail("HoMM3-re object metadata JSON did not parse as a dictionary.")
		return {}
	var result = {}
	var entries: Array = parsed.get("entries", []) if parsed.get("entries", []) is Array else []
	for entry in entries:
		if entry is Dictionary:
			result[str(int(entry.get("type_id", -1)))] = String(entry.get("type_name", ""))
	return result

func _nested_int(root: Dictionary, outer: String, inner: String) -> int:
	var nested: Dictionary = root.get(outer, {}) if root.get(outer, {}) is Dictionary else {}
	return int(nested.get(inner, 0))

func _nested_float(root: Dictionary, outer: String, inner: String) -> float:
	var nested: Dictionary = root.get(outer, {}) if root.get(outer, {}) is Dictionary else {}
	return float(nested.get(inner, 0.0))

func _u32(bytes: PackedByteArray, offset: int) -> int:
	if offset < 0 or offset + 4 > bytes.size():
		return 0
	return int(bytes[offset]) | (int(bytes[offset + 1]) << 8) | (int(bytes[offset + 2]) << 16) | (int(bytes[offset + 3]) << 24)

func _ascii(bytes: PackedByteArray, offset: int, length: int) -> String:
	var chars = PackedByteArray()
	for index in range(length):
		if offset + index >= bytes.size():
			break
		chars.append(bytes[offset + index])
	return chars.get_string_from_ascii()

func _point(x: int, y: int) -> Dictionary:
	return {"x": x, "y": y}

func _point_key(x: int, y: int) -> String:
	return "%d,%d" % [x, y]

func snapped(value: float, step: float) -> float:
	if step <= 0.0:
		return value
	return round(value / step) * step

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
