extends Node

const RandomMapGeneratorRulesScript = preload("res://scripts/core/RandomMapGeneratorRules.gd")
const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")

const REPORT_ID := "NATIVE_RANDOM_MAP_CATALOG_QUALITY_REPORT"
const REPORT_SCHEMA_ID := "native_random_map_catalog_quality_report_v1"

const CASES := [
	{
		"id": "small_local_frontier_spokes",
		"template_id": "frontier_spokes_v1",
		"profile_id": "frontier_spokes_profile_v1",
		"size_class_id": "homm3_small",
		"player_count": 3,
	},
	{
		"id": "medium_translated_024",
		"template_id": "translated_rmg_template_024_v1",
		"profile_id": "translated_rmg_profile_024_v1",
		"size_class_id": "homm3_medium",
		"player_count": 4,
	},
	{
		"id": "large_translated_042",
		"template_id": "translated_rmg_template_042_v1",
		"profile_id": "translated_rmg_profile_042_v1",
		"size_class_id": "homm3_large",
		"player_count": 4,
	},
	{
		"id": "xl_translated_043",
		"template_id": "translated_rmg_template_043_v1",
		"profile_id": "translated_rmg_profile_043_v1",
		"size_class_id": "homm3_extra_large",
		"player_count": 8,
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

	var catalog: Dictionary = ContentService.load_json(RandomMapGeneratorRulesScript.TEMPLATE_CATALOG_PATH)
	var summaries := []
	for case_record in CASES:
		var summary := _run_case(service, catalog, case_record)
		if summary.is_empty():
			return
		summaries.append(summary)

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"schema_id": REPORT_SCHEMA_ID,
		"ok": true,
		"binding_kind": metadata.get("binding_kind", ""),
		"native_extension_loaded": metadata.get("native_extension_loaded", false),
		"case_count": summaries.size(),
		"cases": summaries,
		"remaining_gap": "broad native catalog wiring/playability is improved; exact HoMM3-re byte/placement/art parity remains outside this report",
	})])
	get_tree().quit(0)

func _run_case(service: Variant, catalog: Dictionary, case_record: Dictionary) -> Dictionary:
	var template := _template_by_id(catalog, String(case_record.get("template_id", "")))
	if template.is_empty():
		_fail("Missing catalog template for %s." % String(case_record.get("template_id", "")))
		return {}
	var config := ScenarioSelectRulesScript.build_random_map_player_config(
		"native-catalog-quality-%s" % String(case_record.get("id", "")),
		String(case_record.get("template_id", "")),
		String(case_record.get("profile_id", "")),
		int(case_record.get("player_count", 4)),
		"land",
		false,
		String(case_record.get("size_class_id", "homm3_small"))
	)
	var generated: Dictionary = service.generate_random_map(config)
	if not bool(generated.get("ok", false)):
		_fail("%s native generation failed: %s" % [String(case_record.get("id", "")), JSON.stringify(generated)])
		return {}
	if String(generated.get("validation_status", "")) != "pass":
		_fail("%s native validation did not pass: %s" % [String(case_record.get("id", "")), JSON.stringify(generated.get("validation_report", {}))])
		return {}

	var normalized: Dictionary = generated.get("normalized_config", {}) if generated.get("normalized_config", {}) is Dictionary else {}
	var width := int(normalized.get("width", 0))
	var height := int(normalized.get("height", 0))
	var zone_count := int(generated.get("zone_layout", {}).get("zone_count", 0))
	var route_edge_count := int(generated.get("route_graph", {}).get("route_edge_count", 0))
	var road_cell_count := int(generated.get("road_network", {}).get("road_cell_count", 0))
	var road_segment_count := int(generated.get("road_network", {}).get("road_segment_count", 0))
	var object_count := int(generated.get("object_placements", []).size())
	var decoration_count := _count_kind(generated.get("object_placements", []), "decorative_obstacle")
	var town_count := int(generated.get("town_records", []).size())
	var guard_count := int(generated.get("guard_records", []).size())
	var resource_count := _count_kind(generated.get("object_placements", []), "resource_site")
	var mine_count := _count_kind(generated.get("object_placements", []), "mine")
	var reward_count := _count_kind(generated.get("object_placements", []), "reward_reference")
	var expected_zone_count := int((template.get("zones", []) as Array).size())
	var expected_link_count := int((template.get("links", []) as Array).size())
	var min_object_count: int = max(32, zone_count * 5 + int((width * height) / 192))
	var min_decoration_count: int = max(zone_count * 2, int((width * height) / 96))

	if width != int(config.get("size", {}).get("width", 0)) or height != int(config.get("size", {}).get("height", 0)):
		_fail("%s dimensions did not match selected size: %dx%d config=%s" % [String(case_record.get("id", "")), width, height, JSON.stringify(config.get("size", {}))])
		return {}
	if expected_zone_count > 0 and zone_count != expected_zone_count:
		_fail("%s zone count did not reflect catalog template: %d expected %d." % [String(case_record.get("id", "")), zone_count, expected_zone_count])
		return {}
	if expected_link_count > 0 and route_edge_count != expected_link_count:
		_fail("%s route edge count did not reflect catalog links: %d expected %d." % [String(case_record.get("id", "")), route_edge_count, expected_link_count])
		return {}
	if road_segment_count <= 0 or road_cell_count <= 0:
		_fail("%s did not materialize visible native roads: segments=%d cells=%d." % [String(case_record.get("id", "")), road_segment_count, road_cell_count])
		return {}
	if object_count < min_object_count:
		_fail("%s object count stayed too low: %d min %d." % [String(case_record.get("id", "")), object_count, min_object_count])
		return {}
	if decoration_count < min_decoration_count:
		_fail("%s decoration count stayed token-sized: %d min %d." % [String(case_record.get("id", "")), decoration_count, min_decoration_count])
		return {}
	if town_count <= 0 or guard_count <= 0 or resource_count <= 0 or mine_count <= 0 or reward_count <= 0:
		_fail("%s missed playable object categories: towns=%d guards=%d resources=%d mines=%d rewards=%d." % [String(case_record.get("id", "")), town_count, guard_count, resource_count, mine_count, reward_count])
		return {}

	var adoption: Dictionary = service.convert_generated_payload(generated, {
		"feature_gate": "native_rmg_catalog_quality_report",
		"session_save_version": 9,
		"scenario_id": "native_catalog_quality_%s" % String(case_record.get("id", "")),
	})
	if not bool(adoption.get("ok", false)):
		_fail("%s convert_generated_payload failed: %s" % [String(case_record.get("id", "")), JSON.stringify(adoption)])
		return {}
	var map_document: Variant = adoption.get("map_document", null)
	if map_document == null:
		_fail("%s adoption missed map_document." % String(case_record.get("id", "")))
		return {}
	var package_surface := _map_document_surface_summary(map_document)
	if not _package_surface_is_valid(String(case_record.get("id", "")), package_surface, road_cell_count, min_object_count):
		return {}

	var map_path := "user://native_catalog_quality_%s.amap" % String(case_record.get("id", "case"))
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
	if loaded_document == null:
		_fail("%s load result missed map_document." % String(case_record.get("id", "")))
		return {}
	var loaded_surface := _map_document_surface_summary(loaded_document)
	if not _package_surface_is_valid(String(case_record.get("id", "")) + "_loaded", loaded_surface, road_cell_count, min_object_count):
		return {}

	return {
		"id": String(case_record.get("id", "")),
		"template_id": String(case_record.get("template_id", "")),
		"size_class_id": String(case_record.get("size_class_id", "")),
		"width": width,
		"height": height,
		"zone_count": zone_count,
		"route_edge_count": route_edge_count,
		"road_segment_count": road_segment_count,
		"road_cell_count": road_cell_count,
		"object_count": object_count,
		"decoration_count": decoration_count,
		"town_count": town_count,
		"guard_count": guard_count,
		"resource_count": resource_count,
		"mine_count": mine_count,
		"reward_count": reward_count,
		"package_surface": package_surface,
		"loaded_surface": loaded_surface,
	}

func _package_surface_is_valid(case_id: String, surface: Dictionary, expected_min_road_cells: int, min_object_count: int) -> bool:
	if int(surface.get("road_count", 0)) <= 0 or int(surface.get("road_cell_count", 0)) <= 0:
		_fail("%s package/editor road surface is empty: %s" % [case_id, JSON.stringify(surface)])
		return false
	if int(surface.get("road_cell_count", 0)) < expected_min_road_cells:
		_fail("%s package/editor road cells dropped through convert/save/load: %s" % [case_id, JSON.stringify(surface)])
		return false
	if int(surface.get("object_count", 0)) < min_object_count:
		_fail("%s package/editor object surface is too small: %s" % [case_id, JSON.stringify(surface)])
		return false
	return true

func _map_document_surface_summary(map_document: Variant) -> Dictionary:
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

func _template_by_id(catalog: Dictionary, template_id: String) -> Dictionary:
	for template in catalog.get("templates", []):
		if template is Dictionary and String(template.get("id", "")) == template_id:
			return template
	return {}

func _count_kind(records: Array, kind: String) -> int:
	var count := 0
	for record in records:
		if record is Dictionary and String(record.get("kind", "")) == kind:
			count += 1
	return count

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
