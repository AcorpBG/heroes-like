extends Node

const REPORT_ID := "NATIVE_RANDOM_MAP_OBJECT_PLACEMENT_REPORT"

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
	if not capabilities.has("native_random_map_object_placement_foundation"):
		_fail("Native object placement capability is missing: %s" % JSON.stringify(Array(capabilities)))
		return

	var config := {
		"seed": "native-rmg-object-placement-foundation-10184",
		"size": {
			"width": 42,
			"height": 38,
			"level_count": 1,
			"size_class_id": "homm3_small",
			"water_mode": "islands",
		},
		"player_constraints": {
			"human_count": 1,
			"computer_count": 3,
			"team_mode": "free_for_all",
		},
		"profile": {
			"id": "native_object_placement_profile",
			"template_id": "native_foundation_spoke",
			"terrain_ids": ["grass", "dirt", "rough", "snow", "underground"],
			"faction_ids": ["faction_embercourt", "faction_mireclaw", "faction_sunvault", "faction_thornwake"],
		},
	}
	var changed_seed_config := config.duplicate(true)
	changed_seed_config["seed"] = "native-rmg-object-placement-foundation-10184-changed"

	var first: Dictionary = service.generate_random_map(config)
	var second: Dictionary = service.generate_random_map(config.duplicate(true))
	var changed: Dictionary = service.generate_random_map(changed_seed_config)

	_assert_object_shape(first, 42, 38)
	_assert_object_shape(second, 42, 38)
	_assert_object_shape(changed, 42, 38)

	var first_objects: Dictionary = first.get("object_placement", {})
	var second_objects: Dictionary = second.get("object_placement", {})
	var changed_objects: Dictionary = changed.get("object_placement", {})
	var signature := String(first_objects.get("signature", ""))
	var occupancy_signature := String(first_objects.get("occupancy_index", {}).get("signature", ""))
	if signature == "" or occupancy_signature == "":
		_fail("Object placement and occupancy signatures must be non-empty.")
		return
	if signature != String(second_objects.get("signature", "")):
		_fail("Same seed/config did not preserve object placement signature.")
		return
	if occupancy_signature != String(second_objects.get("occupancy_index", {}).get("signature", "")):
		_fail("Same seed/config did not preserve object occupancy signature.")
		return
	if signature == String(changed_objects.get("signature", "")):
		_fail("Changed seed did not change object placement signature.")
		return
	if _layout_signature(first_objects.get("object_placements", [])) == _layout_signature(changed_objects.get("object_placements", [])):
		_fail("Changed seed did not change object layout coordinates.")
		return

	var report: Dictionary = first.get("report", {})
	if String(first.get("object_generation_status", "")) != "objects_generated_foundation":
		_fail("Top-level object_generation_status missing.")
		return
	if String(report.get("object_generation_status", "")) != "objects_generated_foundation":
		_fail("Report object_generation_status missing: %s" % JSON.stringify(report))
		return
	if String(report.get("object_placement_signature", "")) != signature:
		_fail("Report object signature did not match placement payload.")
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"binding_kind": metadata.get("binding_kind", ""),
		"native_extension_loaded": metadata.get("native_extension_loaded", false),
		"status": first.get("status", ""),
		"full_generation_status": first.get("full_generation_status", ""),
		"object_generation_status": first.get("object_generation_status", ""),
		"object_count": first_objects.get("object_count", 0),
		"object_signature": signature,
		"changed_object_signature": changed_objects.get("signature", ""),
		"occupancy_signature": occupancy_signature,
		"category_counts": first_objects.get("category_counts", {}),
	})])
	get_tree().quit(0)

func _assert_object_shape(generated: Dictionary, expected_width: int, expected_height: int) -> void:
	if not bool(generated.get("ok", false)):
		_fail("Native RMG object generation returned ok=false: %s" % JSON.stringify(generated))
		return
	if String(generated.get("status", "")) != "partial_foundation":
		_fail("Object slice did not preserve partial_foundation status.")
		return
	if String(generated.get("full_generation_status", "")) != "not_implemented":
		_fail("Object slice falsely implied full generation.")
		return
	if String(generated.get("object_generation_status", "")) != "objects_generated_foundation":
		_fail("Missing top-level object_generation_status.")
		return

	var placement_payload: Dictionary = generated.get("object_placement", {})
	if String(placement_payload.get("schema_id", "")) != "aurelion_native_rmg_object_placement_v1":
		_fail("Object placement schema mismatch: %s" % JSON.stringify(placement_payload))
		return
	if String(placement_payload.get("generation_status", "")) != "objects_generated_foundation":
		_fail("Object placement generation status mismatch.")
		return
	if String(placement_payload.get("materialization_state", "")) != "staged_object_records_only_no_gameplay_adoption":
		_fail("Object placement crossed the no-adoption boundary.")
		return
	var placements: Array = placement_payload.get("object_placements", [])
	if placements.is_empty() or int(placement_payload.get("object_count", 0)) != placements.size():
		_fail("Object placement payload must expose non-empty records and matching count.")
		return

	var occupancy: Dictionary = placement_payload.get("occupancy_index", {})
	if String(occupancy.get("status", "")) != "pass" or int(occupancy.get("duplicate_primary_tile_count", -1)) != 0:
		_fail("Object occupancy index did not prove unique primary tiles: %s" % JSON.stringify(occupancy))
		return
	if int(occupancy.get("occupied_primary_tile_count", 0)) != placements.size():
		_fail("Primary occupancy count did not match placement count.")
		return

	var kinds := {}
	var families := {}
	var zones := {}
	for placement in placements:
		if not (placement is Dictionary):
			_fail("Non-dictionary object placement.")
			return
		_assert_placement_valid(placement, expected_width, expected_height)
		kinds[String(placement.get("kind", ""))] = true
		families[String(placement.get("family_id", ""))] = true
		zones[String(placement.get("zone_id", ""))] = true
	if kinds.size() < 4 or not kinds.has("resource_site") or not kinds.has("reward_reference") or not kinds.has("mine") or not kinds.has("decorative_obstacle"):
		_fail("Object placement did not expose useful kind spread: %s" % JSON.stringify(kinds.keys()))
		return
	if families.size() < 5:
		_fail("Object placement did not expose useful family spread: %s" % JSON.stringify(families.keys()))
		return
	if zones.size() < 4:
		_fail("Object placement did not preserve useful zone associations: %s" % JSON.stringify(zones.keys()))
		return

	var category_counts: Dictionary = placement_payload.get("category_counts", {})
	if int(category_counts.get("by_kind", {}).get("resource_site", 0)) <= 0 or int(category_counts.get("by_kind", {}).get("reward_reference", 0)) <= 0:
		_fail("Category counts missed object kinds: %s" % JSON.stringify(category_counts))
		return

	var map_document: Variant = generated.get("map_document")
	if map_document == null or map_document.get_object_count() != placements.size():
		_fail("MapDocument object count did not match placement payload.")
		return
	var sample: Dictionary = map_document.get_object_by_index(0)
	if sample.is_empty() or String(map_document.get_object_by_placement_id(String(sample.get("placement_id", ""))).get("placement_id", "")) != String(sample.get("placement_id", "")):
		_fail("MapDocument object lookup did not return staged object records.")
		return

func _assert_placement_valid(placement: Dictionary, width: int, height: int) -> void:
	var x := int(placement.get("x", -1))
	var y := int(placement.get("y", -1))
	var level := int(placement.get("level", -1))
	if x < 0 or x >= width or y < 0 or y >= height or level != 0:
		_fail("Object placement has invalid coordinates: %s" % JSON.stringify(placement))
		return
	if String(placement.get("placement_id", "")) == "" or String(placement.get("kind", "")) == "" or String(placement.get("family_id", "")) == "" or String(placement.get("object_id", "")) == "":
		_fail("Object placement missed identity fields: %s" % JSON.stringify(placement))
		return
	if String(placement.get("zone_id", "")) == "" or String(placement.get("terrain_id", "")) == "":
		_fail("Object placement missed zone or terrain association: %s" % JSON.stringify(placement))
		return
	var bounds: Dictionary = placement.get("bounds", {})
	if int(bounds.get("min_x", -1)) < 0 or int(bounds.get("max_x", width)) >= width or int(bounds.get("min_y", -1)) < 0 or int(bounds.get("max_y", height)) >= height:
		_fail("Object placement bounds are invalid: %s" % JSON.stringify(placement))
		return
	if String(placement.get("primary_occupancy_key", "")) == "":
		_fail("Object placement missed primary occupancy key: %s" % JSON.stringify(placement))
		return
	var body_tiles: Array = placement.get("body_tiles", [])
	var occupancy_keys: Array = placement.get("occupancy_keys", [])
	if body_tiles.is_empty() or occupancy_keys.is_empty():
		_fail("Object placement missed footprint or occupancy fields: %s" % JSON.stringify(placement))
		return
	if String(placement.get("road_proximity", {}).get("proximity_class", "")) == "" or int(placement.get("road_proximity", {}).get("nearest_distance_tiles", -1)) < 0:
		_fail("Object placement missed road proximity: %s" % JSON.stringify(placement))
		return
	if String(placement.get("signature", "")) == "":
		_fail("Object placement missed stable signature: %s" % JSON.stringify(placement))
		return

func _layout_signature(placements: Array) -> String:
	var rows := []
	for placement in placements:
		if placement is Dictionary:
			rows.append("%s@%d,%d" % [String(placement.get("placement_id", "")), int(placement.get("x", 0)), int(placement.get("y", 0))])
	rows.sort()
	return "|".join(rows)

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
