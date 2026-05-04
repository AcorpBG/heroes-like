extends Node

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const REPORT_ID := "NATIVE_RANDOM_MAP_DECORATION_GENERATION_REPORT"

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
	if not capabilities.has("native_random_map_decorative_obstacle_generation"):
		_fail("Native decoration capability is missing: %s" % JSON.stringify(Array(capabilities)))
		return

	var small_config := ScenarioSelectRulesScript.build_random_map_player_config(
		"native-decoration-small-10184",
		"border_gate_compact_v1",
		"border_gate_compact_profile_v1",
		3,
		"land",
		false,
		"homm3_small"
	)
	var large_config := ScenarioSelectRulesScript.build_random_map_player_config(
		"native-decoration-xl-10184",
		"translated_rmg_template_043_v1",
		"translated_rmg_profile_043_v1",
		8,
		"land",
		false,
		"homm3_extra_large"
	)
	var small: Dictionary = service.generate_random_map(small_config)
	var large: Dictionary = service.generate_random_map(large_config)
	var small_summary := _assert_decorations("small_supported", small, true)
	if small_summary.is_empty():
		return
	var large_summary := _assert_decorations("xl_catalog", large, false)
	if large_summary.is_empty():
		return
	if int(large_summary.get("decoration_count", 0)) <= int(small_summary.get("decoration_count", 0)):
		_fail("XL catalog decoration count did not scale above small fixture: small=%s large=%s" % [JSON.stringify(small_summary), JSON.stringify(large_summary)])
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"binding_kind": metadata.get("binding_kind", ""),
		"native_extension_loaded": metadata.get("native_extension_loaded", false),
		"small": small_summary,
		"xl_catalog": large_summary,
		"remaining_gap": "native records HoMM3-re source-row identity and maps it to original proxy decorative_obstacle family ids; exact HoMM3-re decoration art/DEF rendering parity is not complete",
	})])
	get_tree().quit(0)

func _assert_decorations(case_id: String, generated: Dictionary, expect_supported: bool) -> Dictionary:
	if not bool(generated.get("ok", false)):
		_fail("%s generation failed: %s" % [case_id, JSON.stringify(generated)])
		return {}
	if expect_supported and String(generated.get("status", "")) != "full_parity_supported":
		_fail("%s should remain native supported output: %s" % [case_id, JSON.stringify(generated.get("provenance", {}))])
		return {}
	if String(generated.get("route_reachability_proof", {}).get("status", "")) != "pass":
		_fail("%s route reachability broke after decorations: %s" % [case_id, JSON.stringify(generated.get("route_reachability_proof", {}))])
		return {}
	var decorations := []
	var missing_metadata := []
	var road_body_conflicts := _road_body_conflicts(generated)
	for placement in generated.get("object_placements", []):
		if not (placement is Dictionary) or String(placement.get("kind", "")) != "decorative_obstacle":
			continue
		decorations.append(placement)
		if String(placement.get("placement_id", "")) == "" \
				or String(placement.get("family_id", "")) == "" \
				or String(placement.get("object_family_id", "")) != "decorative_obstacle" \
				or not bool(placement.get("blocking_body", false)) \
				or not (placement.get("body_tiles", []) is Array) \
				or placement.get("body_tiles", []).is_empty() \
				or not (placement.get("occupancy_keys", []) is Array) \
				or placement.get("occupancy_keys", []).is_empty() \
				or not (placement.get("footprint", {}) is Dictionary) \
				or String(placement.get("approach_policy", "")) == "" \
				or String(placement.get("occupancy_metadata", "")) == "" \
				or String(placement.get("homm3_re_source_kind", "")) != "rand_trn_obstacle_row" \
				or int(placement.get("homm3_re_rand_trn_source_row", 0)) <= 0 \
				or String(placement.get("homm3_re_type_name", "")) == "" \
				or String(placement.get("homm3_re_primary_def_template_ref", "")) == "" \
				or String(placement.get("proxy_family_id", "")) == "" \
				or String(placement.get("homm3_re_art_asset_policy", "")) != "metadata_only_def_names_are_not_imported_runtime_art":
			missing_metadata.append(String(placement.get("placement_id", "")))
	if decorations.is_empty():
		_fail("%s did not generate decorative_obstacle placements." % case_id)
		return {}
	if not missing_metadata.is_empty():
		_fail("%s decoration records missed body/footprint/occupancy metadata: %s" % [case_id, JSON.stringify(missing_metadata)])
		return {}
	if not road_body_conflicts.is_empty():
		_fail("%s decoration body tiles overlapped roads: %s" % [case_id, JSON.stringify(road_body_conflicts)])
		return {}
	var shaping: Dictionary = generated.get("decoration_route_shaping_summary", {}) if generated.get("decoration_route_shaping_summary", {}) is Dictionary else {}
	if int(shaping.get("blocking_body_tile_total", 0)) < decorations.size():
		_fail("%s decoration shaping summary did not count body tiles: %s" % [case_id, JSON.stringify(shaping)])
		return {}
	return {
		"status": String(generated.get("status", "")),
		"full_generation_status": String(generated.get("full_generation_status", "")),
		"template_id": String(generated.get("normalized_config", {}).get("template_id", "")),
		"width": int(generated.get("normalized_config", {}).get("width", 0)),
		"height": int(generated.get("normalized_config", {}).get("height", 0)),
		"zone_count": int(generated.get("zone_layout", {}).get("zone_count", 0)),
		"decoration_count": decorations.size(),
		"blocking_body_tile_total": int(shaping.get("blocking_body_tile_total", 0)),
		"multitile_decoration_count": int(shaping.get("multitile_decoration_count", 0)),
		"category_counts": _count_by_kind(generated.get("object_placements", [])),
		"homm3_re_source_rows": _unique_field_count(decorations, "homm3_re_rand_trn_source_row"),
		"homm3_re_type_names": _unique_field_count(decorations, "homm3_re_type_name"),
		"proxy_families": _unique_field_count(decorations, "proxy_family_id"),
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
	for placement in generated.get("object_placements", []):
		if not (placement is Dictionary) or String(placement.get("kind", "")) != "decorative_obstacle":
			continue
		for body in placement.get("body_tiles", []):
			if body is Dictionary:
				var key := _point_key(int(body.get("x", 0)), int(body.get("y", 0)))
				if road_keys.has(key):
					conflicts.append("%s@%s" % [String(placement.get("placement_id", "")), key])
	return conflicts

func _count_by_kind(records: Array) -> Dictionary:
	var counts := {}
	for record in records:
		if record is Dictionary:
			var kind := String(record.get("kind", ""))
			counts[kind] = int(counts.get(kind, 0)) + 1
	return counts

func _unique_field_count(records: Array, field: String) -> int:
	var values := {}
	for record in records:
		if record is Dictionary:
			values[str(record.get(field, ""))] = true
	return values.size()

func _point_key(x: int, y: int) -> String:
	return "%d,%d" % [x, y]

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
