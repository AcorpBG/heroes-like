extends Node

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")

const REPORT_ID := "NATIVE_RANDOM_MAP_HOMM3_LAND_NORMALIZED_OBJECT_DENSITY_REPORT"
const REPORT_SCHEMA_ID := "native_random_map_homm3_land_normalized_object_density_report_v1"

const ATTACHED_H3M_GZ := "/root/.openclaw/media/inbound/Untitled---cad43d4f-6faa-4059-a9db-9b37770806af.gz"
const HOMM3_RE_OBJECT_METADATA := "/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/object-metadata-by-type.json"

const HOMM3_VERSION_ROE := 14
const HOMM3_VERSION_AB := 21
const HOMM3_VERSION_SOD := 28
const H3M_TILE_BYTES_PER_CELL := 7
const OBJECT_TEMPLATE_RECORD_BYTES_AFTER_NAME := 42

const DECORATION_TYPE_IDS := {
	118: true, 119: true, 120: true, 134: true, 135: true, 136: true,
	137: true, 147: true, 150: true, 155: true, 199: true, 207: true,
	210: true,
}
const GUARD_TYPE_IDS := {54: true, 71: true}
const TOWN_TYPE_IDS := {98: true}
const REWARD_RESOURCE_TYPE_IDS := {5: true, 53: true, 79: true, 83: true, 88: true, 93: true, 101: true}

const OWNER_CASE := {
	"id": "owner_like_medium_small_ring_islands",
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

	var object_metadata := _load_homm3_object_metadata()
	if object_metadata.is_empty():
		return
	var owner := _parse_owner_h3m(object_metadata)
	if owner.is_empty():
		return
	var native := _generate_native_owner_like(service)
	if native.is_empty():
		return
	var comparison := _density_comparison(owner, native)
	var gate := _gate_summary(owner, native, comparison)
	if String(gate.get("status", "")) != "pass":
		_fail("Land-normalized density gate failed: %s" % JSON.stringify(gate))
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
		"remaining_gap": "This report compares parseable land-normalized density and category mix after the native land/water fix. It is not exact HoMM3-re object-table, asset, placement, terrain-shape, byte, or full parity.",
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
	var generated: Dictionary = service.generate_random_map(config, {"startup_path": "homm3_land_normalized_object_density_report"})
	if not bool(generated.get("ok", false)) or String(generated.get("validation_status", "")) != "pass":
		_fail("Native owner-like generation failed validation: %s" % JSON.stringify(generated.get("validation_report", generated)))
		return {}
	var normalized: Dictionary = generated.get("normalized_config", {}) if generated.get("normalized_config", {}) is Dictionary else {}
	var land_lookup := _native_land_lookup(generated, int(normalized.get("width", 0)), int(normalized.get("height", 0)))
	var road_points := _native_road_points(generated)
	var counts := _native_category_counts(generated)
	var package := _package_surface_summary(service, generated)
	if package.is_empty():
		return {}
	var metrics := _density_metrics(
		"native_owner_like",
		int(normalized.get("width", 0)),
		int(normalized.get("height", 0)),
		land_lookup.size(),
		road_points.size(),
		counts
	)
	metrics["seed"] = String(normalized.get("normalized_seed", ""))
	metrics["template_id"] = String(normalized.get("template_id", ""))
	metrics["profile_id"] = String(normalized.get("profile_id", ""))
	metrics["water_mode"] = String(normalized.get("water_mode", ""))
	metrics["zone_count"] = int(generated.get("zone_layout", {}).get("zone_count", 0))
	metrics["route_edge_count"] = int(generated.get("route_graph", {}).get("route_edge_count", 0))
	metrics["generated_object_placement_count"] = int(generated.get("object_placements", []).size()) if generated.get("object_placements", []) is Array else 0
	metrics["generated_town_count"] = int(generated.get("town_records", []).size()) if generated.get("town_records", []) is Array else 0
	metrics["generated_guard_count"] = int(generated.get("guard_records", []).size()) if generated.get("guard_records", []) is Array else 0
	metrics["object_category_counts_native"] = generated.get("object_category_counts", {})
	metrics["town_guard_category_counts"] = generated.get("town_guard_category_counts", {})
	metrics["fill_coverage_summary"] = generated.get("fill_coverage_summary", {})
	metrics["decoration_route_shaping_summary"] = generated.get("decoration_route_shaping_summary", {})
	metrics["package"] = package
	return metrics

func _parse_owner_h3m(object_metadata: Dictionary) -> Dictionary:
	var compressed := FileAccess.get_file_as_bytes(ATTACHED_H3M_GZ)
	if compressed.is_empty():
		_fail("Could not read owner H3M gzip at %s." % ATTACHED_H3M_GZ)
		return {}
	var bytes := compressed.decompress_dynamic(10000000, 3)
	if bytes.is_empty():
		_fail("Could not decompress owner H3M gzip.")
		return {}
	var version := _u32(bytes, 0)
	if version not in [HOMM3_VERSION_ROE, HOMM3_VERSION_AB, HOMM3_VERSION_SOD]:
		_fail("Unexpected H3M version %d." % version)
		return {}
	var width := _u32(bytes, 5)
	var height := width
	if width != 72:
		_fail("Owner H3M size changed from expected 72x72: %d." % width)
		return {}
	var def_offset := _find_object_definition_offset(bytes)
	if def_offset <= 0:
		_fail("Could not locate H3M object-definition table.")
		return {}
	var tile_offset := def_offset - int(width * height * H3M_TILE_BYTES_PER_CELL)
	if tile_offset <= 0:
		_fail("Computed invalid H3M tile-stream offset: %d." % tile_offset)
		return {}
	var templates := _parse_h3m_object_templates(bytes, def_offset, object_metadata)
	if templates.is_empty():
		return {}
	var objects := _parse_h3m_object_instances(bytes, int(templates.get("next_offset", 0)), templates.get("templates", []))
	if objects.is_empty():
		return {}
	var land_lookup := _h3m_land_lookup(bytes, tile_offset, width, height)
	var road_points := _h3m_road_points(bytes, tile_offset, width, height)
	var counts := _owner_category_counts(objects.get("records", []))
	var metrics := _density_metrics("owner_h3m", width, height, land_lookup.size(), road_points.size(), counts)
	metrics["path"] = ATTACHED_H3M_GZ
	metrics["version"] = version
	metrics["gzip_bytes"] = compressed.size()
	metrics["decompressed_h3m_bytes"] = bytes.size()
	metrics["tile_stream_offset"] = tile_offset
	metrics["object_definition_offset"] = def_offset
	metrics["object_definition_count"] = int(templates.get("template_count", 0))
	metrics["object_instance_table_offset"] = int(templates.get("next_offset", 0))
	metrics["object_instance_parse_tail_bytes"] = int(objects.get("tail_bytes", 0))
	var owner_counts: Dictionary = metrics.get("counts_by_category", {}) if metrics.get("counts_by_category", {}) is Dictionary else {}
	metrics["object_type_top_counts"] = _top_counts(owner_counts.get("object_type_counts", {}), 16)
	return metrics

func _density_metrics(id: String, width: int, height: int, land_count: int, road_count: int, counts: Dictionary) -> Dictionary:
	var total := 0
	for key in ["decoration_impassable", "reward_resource", "guard", "town", "other_object"]:
		total += int(counts.get(key, 0))
	var category_mix := {}
	for key in ["decoration_impassable", "reward_resource", "guard", "town", "other_object"]:
		category_mix[key] = snapped(float(counts.get(key, 0)) / float(max(1, total)), 0.0001)
	var per_100_land := {
		"total_objects": _per_100(total, land_count),
		"decoration_impassable": _per_100(int(counts.get("decoration_impassable", 0)), land_count),
		"reward_resource": _per_100(int(counts.get("reward_resource", 0)), land_count),
		"guard": _per_100(int(counts.get("guard", 0)), land_count),
		"town": _per_100(int(counts.get("town", 0)), land_count),
		"other_object": _per_100(int(counts.get("other_object", 0)), land_count),
		"road_tiles": _per_100(road_count, land_count),
	}
	return {
		"id": id,
		"width": width,
		"height": height,
		"map_tile_count": width * height,
		"land_tile_count": land_count,
		"water_tile_count": width * height - land_count,
		"land_coverage_ratio": snapped(float(land_count) / float(max(1, width * height)), 0.0001),
		"road_tile_count": road_count,
		"object_count": total,
		"counts_by_category": counts,
		"per_100_land": per_100_land,
		"category_mix": category_mix,
	}

func _density_comparison(owner: Dictionary, native: Dictionary) -> Dictionary:
	var owner_per: Dictionary = owner.get("per_100_land", {})
	var native_per: Dictionary = native.get("per_100_land", {})
	var owner_mix: Dictionary = owner.get("category_mix", {})
	var native_mix: Dictionary = native.get("category_mix", {})
	var per_100_delta := {}
	var per_100_ratio := {}
	var mix_delta := {}
	for key in ["total_objects", "decoration_impassable", "reward_resource", "guard", "town", "other_object", "road_tiles"]:
		per_100_delta[key] = snapped(float(native_per.get(key, 0.0)) - float(owner_per.get(key, 0.0)), 0.001)
		per_100_ratio[key] = snapped(float(native_per.get(key, 0.0)) / max(0.001, float(owner_per.get(key, 0.0))), 0.001)
	for key in ["decoration_impassable", "reward_resource", "guard", "town", "other_object"]:
		mix_delta[key] = snapped(float(native_mix.get(key, 0.0)) - float(owner_mix.get(key, 0.0)), 0.0001)
	return {
		"object_count_delta": int(native.get("object_count", 0)) - int(owner.get("object_count", 0)),
		"land_tile_count_delta": int(native.get("land_tile_count", 0)) - int(owner.get("land_tile_count", 0)),
		"road_tile_count_delta": int(native.get("road_tile_count", 0)) - int(owner.get("road_tile_count", 0)),
		"per_100_land_delta": per_100_delta,
		"per_100_land_ratio": per_100_ratio,
		"category_mix_delta": mix_delta,
		"interpretation": "Ratios below 1.0 mean native is sparser per land tile than the owner H3M. Mix deltas compare parseable categories as shares of object instances.",
	}

func _gate_summary(owner: Dictionary, native: Dictionary, comparison: Dictionary) -> Dictionary:
	var failures := []
	if int(owner.get("object_count", 0)) != 496:
		failures.append("owner_object_count_parse_changed")
	if int(owner.get("land_tile_count", 0)) != 1948:
		failures.append("owner_land_count_parse_changed")
	if int(owner.get("road_tile_count", 0)) != 184:
		failures.append("owner_road_count_parse_changed")
	if float(comparison.get("per_100_land_ratio", {}).get("total_objects", 0.0)) < 0.78:
		failures.append("native_total_object_density_below_78_percent_owner")
	if float(comparison.get("per_100_land_ratio", {}).get("reward_resource", 0.0)) < 0.70:
		failures.append("native_reward_resource_density_below_70_percent_owner")
	if float(comparison.get("per_100_land_ratio", {}).get("guard", 0.0)) < 0.70:
		failures.append("native_guard_density_below_70_percent_owner")
	if float(comparison.get("per_100_land_ratio", {}).get("decoration_impassable", 0.0)) < 0.70:
		failures.append("native_decoration_impassable_density_below_70_percent_owner")
	if int(native.get("package", {}).get("package_object_count", 0)) < int(native.get("object_count", 0)):
		failures.append("package_object_count_below_generated_count")
	return {
		"status": "pass" if failures.is_empty() else "fail",
		"failures": failures,
		"thresholds": {
			"owner_object_count": 496,
			"owner_land_tiles": 1948,
			"owner_road_tiles": 184,
			"native_min_total_object_density_ratio": 0.78,
			"native_min_reward_resource_density_ratio": 0.70,
			"native_min_guard_density_ratio": 0.70,
			"native_min_decoration_impassable_density_ratio": 0.70,
		},
		"comparison_snapshot": comparison,
	}

func _native_category_counts(generated: Dictionary) -> Dictionary:
	var counts := {
		"decoration_impassable": 0,
		"reward_resource": 0,
		"guard": 0,
		"town": 0,
		"other_object": 0,
	}
	for object in generated.get("object_placements", []):
		if not (object is Dictionary):
			continue
		var kind := String(object.get("kind", ""))
		if kind == "decorative_obstacle":
			counts["decoration_impassable"] = int(counts.get("decoration_impassable", 0)) + 1
		elif kind in ["resource_site", "mine", "neutral_dwelling", "reward_reference"]:
			counts["reward_resource"] = int(counts.get("reward_resource", 0)) + 1
		else:
			counts["other_object"] = int(counts.get("other_object", 0)) + 1
	for town in generated.get("town_records", []):
		if town is Dictionary:
			counts["town"] = int(counts.get("town", 0)) + 1
	for guard in generated.get("guard_records", []):
		if guard is Dictionary:
			counts["guard"] = int(counts.get("guard", 0)) + 1
	return counts

func _owner_category_counts(records: Array) -> Dictionary:
	var counts := {
		"decoration_impassable": 0,
		"reward_resource": 0,
		"guard": 0,
		"town": 0,
		"other_object": 0,
		"object_type_counts": {},
	}
	for record in records:
		if not (record is Dictionary):
			continue
		var type_id := int(record.get("type_id", -1))
		var type_name := String(record.get("type_name", ""))
		var category := _h3m_category_for_type(type_id, type_name)
		counts[category] = int(counts.get(category, 0)) + 1
		var type_key := "%d:%s" % [type_id, type_name]
		var type_counts: Dictionary = counts.get("object_type_counts", {})
		type_counts[type_key] = int(type_counts.get(type_key, 0)) + 1
		counts["object_type_counts"] = type_counts
	return counts

func _h3m_category_for_type(type_id: int, type_name: String) -> String:
	var lower := type_name.to_lower()
	if DECORATION_TYPE_IDS.has(type_id):
		return "decoration_impassable"
	if GUARD_TYPE_IDS.has(type_id) or lower.contains("monster"):
		return "guard"
	if TOWN_TYPE_IDS.has(type_id):
		return "town"
	if REWARD_RESOURCE_TYPE_IDS.has(type_id) or lower.contains("resource") or lower.contains("mine") or lower.contains("artifact") or lower.contains("shrine"):
		return "reward_resource"
	return "other_object"

func _package_surface_summary(service: Variant, generated: Dictionary) -> Dictionary:
	var adoption: Dictionary = service.convert_generated_payload(generated, {
		"feature_gate": "native_rmg_land_normalized_object_density_report",
		"session_save_version": 9,
		"scenario_id": "native_land_normalized_density_owner_like",
	})
	if not bool(adoption.get("ok", false)):
		_fail("convert_generated_payload failed for land-normalized density report: %s" % JSON.stringify(adoption))
		return {}
	var map_document: Variant = adoption.get("map_document", null)
	if map_document == null:
		_fail("convert_generated_payload missed map_document.")
		return {}
	var counts := {"package_body_tiles": 0, "package_block_tiles": 0, "package_visit_tiles": 0}
	for index in range(int(map_document.get_object_count())):
		var object: Dictionary = map_document.get_object_by_index(index)
		counts["package_body_tiles"] = int(counts.get("package_body_tiles", 0)) + _array_size(object.get("package_body_tiles", []))
		counts["package_block_tiles"] = int(counts.get("package_block_tiles", 0)) + _array_size(object.get("package_block_tiles", []))
		counts["package_visit_tiles"] = int(counts.get("package_visit_tiles", 0)) + _array_size(object.get("package_visit_tiles", []))
	var report: Dictionary = adoption.get("report", {}) if adoption.get("report", {}) is Dictionary else {}
	return {
		"package_object_count": int(map_document.get_object_count()),
		"surface_counts": counts,
		"guard_reward_package_adoption": report.get("guard_reward_package_adoption", {}),
	}

func _parse_h3m_object_templates(bytes: PackedByteArray, offset: int, object_metadata: Dictionary) -> Dictionary:
	var count := _u32(bytes, offset)
	if count <= 0 or count > 2000:
		_fail("Invalid H3M object definition count at %d: %d." % [offset, count])
		return {}
	var pos := offset + 4
	var templates := []
	for index in range(count):
		if pos + 4 > bytes.size():
			_fail("Object definition table ended early at index %d." % index)
			return {}
		var name_len := _u32(bytes, pos)
		pos += 4
		if name_len <= 0 or name_len > 128 or pos + name_len + OBJECT_TEMPLATE_RECORD_BYTES_AFTER_NAME > bytes.size():
			_fail("Invalid object definition name length %d at index %d." % [name_len, index])
			return {}
		var def_name := _ascii(bytes, pos, name_len)
		pos += name_len
		var rest_offset := pos
		pos += OBJECT_TEMPLATE_RECORD_BYTES_AFTER_NAME
		var type_id := _u32(bytes, rest_offset + 16)
		var subtype := _u32(bytes, rest_offset + 20)
		templates.append({
			"template_index": index,
			"def_name": def_name,
			"type_id": type_id,
			"type_name": String(object_metadata.get(str(type_id), "type_%d" % type_id)),
			"subtype": subtype,
		})
	return {
		"template_count": count,
		"templates": templates,
		"next_offset": pos,
	}

func _parse_h3m_object_instances(bytes: PackedByteArray, offset: int, templates: Array) -> Dictionary:
	var count := _u32(bytes, offset)
	if count <= 0 or count > 5000:
		_fail("Invalid H3M placed object count at %d: %d." % [offset, count])
		return {}
	var pos := offset + 4
	var records := []
	var skip_counts := {}
	for index in range(count):
		if not _is_h3m_object_instance_start(bytes, pos, templates.size()):
			_fail("Could not parse H3M placed object %d at offset %d." % [index, pos])
			return {}
		var template_index := _u32(bytes, pos + 3)
		var record: Dictionary = templates[template_index].duplicate(true)
		record["object_index"] = index
		record["x"] = int(bytes[pos])
		record["y"] = int(bytes[pos + 1])
		record["level"] = int(bytes[pos + 2])
		record["offset"] = pos
		records.append(record)
		var next_min := pos + 12
		if index == count - 1:
			pos = next_min
			break
		var found := -1
		for extra in range(0, 320):
			var candidate := next_min + extra
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
	var x := int(bytes[pos])
	var y := int(bytes[pos + 1])
	var z := int(bytes[pos + 2])
	var template_index := _u32(bytes, pos + 3)
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
		var count := _u32(bytes, offset)
		if count < 50 or count > 1000:
			continue
		var name_len := _u32(bytes, offset + 4)
		if name_len < 4 or name_len > 32:
			continue
		var name := _ascii(bytes, offset + 8, name_len)
		if name.to_lower().ends_with(".def"):
			return offset
	return -1

func _h3m_road_points(bytes: PackedByteArray, tile_offset: int, width: int, height: int) -> Array:
	var points := []
	for y in range(height):
		for x in range(width):
			var offset := tile_offset + (y * width + x) * H3M_TILE_BYTES_PER_CELL
			if int(bytes[offset + 4]) != 0:
				points.append(_point(x, y))
	return points

func _h3m_land_lookup(bytes: PackedByteArray, tile_offset: int, width: int, height: int) -> Dictionary:
	var land := {}
	for y in range(height):
		for x in range(width):
			var offset := tile_offset + (y * width + x) * H3M_TILE_BYTES_PER_CELL
			if int(bytes[offset]) != 8:
				land[_point_key(x, y)] = true
	return land

func _native_land_lookup(generated: Dictionary, width: int, height: int) -> Dictionary:
	var land := {}
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
		var code := int(codes[index])
		var terrain_id := String(ids[code]) if code >= 0 and code < ids.size() else "grass"
		if terrain_id != "water":
			land[_point_key(index % width, int(index / width))] = true
	return land

func _native_road_points(generated: Dictionary) -> Array:
	var points := []
	var seen := {}
	var segments: Array = generated.get("road_network", {}).get("road_segments", []) if generated.get("road_network", {}).get("road_segments", []) is Array else []
	for segment in segments:
		if not (segment is Dictionary):
			continue
		for cell in segment.get("cells", []):
			if cell is Dictionary:
				var key := _point_key(int(cell.get("x", 0)), int(cell.get("y", 0)))
				if not seen.has(key):
					seen[key] = true
					points.append(_point(int(cell.get("x", 0)), int(cell.get("y", 0))))
	return points

func _load_homm3_object_metadata() -> Dictionary:
	var text := FileAccess.get_file_as_string(HOMM3_RE_OBJECT_METADATA)
	if text == "":
		_fail("Could not load HoMM3-re object metadata at %s." % HOMM3_RE_OBJECT_METADATA)
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		_fail("HoMM3-re object metadata JSON did not parse as a dictionary.")
		return {}
	var result := {}
	var entries: Array = parsed.get("entries", []) if parsed.get("entries", []) is Array else []
	for entry in entries:
		if entry is Dictionary:
			result[str(int(entry.get("type_id", -1)))] = String(entry.get("type_name", ""))
	return result

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

func _array_size(value: Variant) -> int:
	return int(value.size()) if value is Array else 0

func _per_100(count: int, land_count: int) -> float:
	return snapped(float(count) * 100.0 / float(max(1, land_count)), 0.001)

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
