extends Node

const REPORT_ID := "NATIVE_RANDOM_MAP_HOMM3_MINES_RESOURCES_REPORT"
const EXPECTED_CATEGORIES := ["timber", "quicksilver", "ore", "ember_salt", "lens_crystal", "cut_gems", "gold"]
const MINIMUM_OFFSETS := ["+0x4c", "+0x50", "+0x54", "+0x58", "+0x5c", "+0x60", "+0x64"]
const DENSITY_OFFSETS := ["+0x68", "+0x6c", "+0x70", "+0x74", "+0x78", "+0x7c", "+0x80"]

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
	if not capabilities.has("native_random_map_homm3_mines_resources"):
		_fail("Native HoMM3 mines/resources capability is missing: %s" % JSON.stringify(Array(capabilities)))
		return

	var config := _config("native-rmg-homm3-mines-resources-10184")
	var first: Dictionary = service.generate_random_map(config)
	var second: Dictionary = service.generate_random_map(config.duplicate(true))
	var changed_config := _config("native-rmg-homm3-mines-resources-10184-changed")
	var changed: Dictionary = service.generate_random_map(changed_config)

	if not _assert_mine_resource_shape(first):
		return
	if not _assert_mine_resource_shape(second):
		return

	var first_summary: Dictionary = first.get("mine_resource_summary", {})
	var second_summary: Dictionary = second.get("mine_resource_summary", {})
	var changed_summary: Dictionary = changed.get("mine_resource_summary", {})
	var signature := String(first_summary.get("signature", ""))
	if signature == "":
		_fail("Mine/resource summary signature is empty.")
		return
	if signature != String(second_summary.get("signature", "")):
		_fail("Same seed/config did not preserve mine/resource summary signature.")
		return
	if signature == String(changed_summary.get("signature", "")):
		_fail("Changed seed did not change mine/resource summary signature.")
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"binding_kind": metadata.get("binding_kind", ""),
		"native_extension_loaded": metadata.get("native_extension_loaded", false),
		"status": first.get("status", ""),
		"object_generation_status": first.get("object_generation_status", ""),
		"mine_summary_signature": signature,
		"changed_mine_summary_signature": changed_summary.get("signature", ""),
		"required_attempt_count": first_summary.get("required_attempt_count", 0),
		"density_attempt_count": first_summary.get("density_attempt_count", 0),
		"adjacent_resource_support_count": first_summary.get("adjacent_resource_support_count", 0),
		"adjacent_resource_object_count": first_summary.get("adjacent_resource_object_count", 0),
		"mine_categories": _mine_category_counts(first.get("object_placements", [])),
	})])
	get_tree().quit(0)

func _config(seed: String) -> Dictionary:
	return {
		"seed": seed,
		"size": {
			"width": 72,
			"height": 72,
			"level_count": 1,
			"size_class_id": "homm3_medium",
			"water_mode": "land",
		},
		"player_constraints": {
			"human_count": 1,
			"computer_count": 2,
			"team_mode": "free_for_all",
		},
		"profile": {
			"id": "native_mine_resource_source_semantics_profile",
			"template_id": "translated_rmg_template_005_v1",
			"terrain_ids": ["grass", "dirt", "rough", "snow", "underground"],
			"faction_ids": ["faction_embercourt", "faction_mireclaw", "faction_sunvault"],
		},
	}

func _assert_mine_resource_shape(generated: Dictionary) -> bool:
	if not bool(generated.get("ok", false)):
		_fail("Native RMG returned ok=false: %s" % JSON.stringify(generated.get("report", {})))
		return false

	var summary: Dictionary = generated.get("mine_resource_summary", {})
	if String(summary.get("schema_id", "")) != "aurelion_native_rmg_phase7_mines_resources_summary_v1":
		_fail("Mine/resource summary schema mismatch: %s" % JSON.stringify(summary))
		return false
	if String(summary.get("phase_order", "")) != "phase_7_after_towns_castles_and_cleanup_connections_before_treasure_reward_bands":
		_fail("Mine/resource phase order drifted: %s" % JSON.stringify(summary))
		return false
	if Array(summary.get("category_order", [])) != EXPECTED_CATEGORIES:
		_fail("Mine/resource seven-category order mismatch: %s" % JSON.stringify(summary.get("category_order", [])))
		return false
	if Array(summary.get("source_offsets_minimums", [])) != MINIMUM_OFFSETS or Array(summary.get("source_offsets_densities", [])) != DENSITY_OFFSETS:
		_fail("Mine/resource recovered source offsets are missing.")
		return false
	if not bool(summary.get("minimum_before_density", false)):
		_fail("Mine/resource minimum-before-density flag missing.")
		return false
	if int(summary.get("required_attempt_count", 0)) <= 0 or int(summary.get("density_attempt_count", 0)) <= 0:
		_fail("Mine/resource schedule did not consume both minimum and density fields: %s" % JSON.stringify(summary))
		return false
	if int(summary.get("placed_required_count", 0)) != int(summary.get("required_attempt_count", 0)):
		_fail("Required mine/resource placements were not all materialized: %s" % JSON.stringify(summary))
		return false

	var mine_counts := _mine_category_counts(generated.get("object_placements", []))
	for category in EXPECTED_CATEGORIES:
		if int(mine_counts.get(String(category), 0)) <= 0:
			_fail("No mine placement for recovered category %s: %s" % [category, JSON.stringify(mine_counts)])
			return false
	if int(summary.get("adjacent_resource_support_count", 0)) < _total_count(mine_counts):
		_fail("Every mine should emit an adjacent/resource support record: %s" % JSON.stringify(summary))
		return false
	if int(summary.get("adjacent_resource_object_count", 0)) <= 0:
		_fail("Supported wood/ore/gold adjacent resource pickups were not materialized.")
		return false
	for record in summary.get("adjacent_resource_records", []):
		if not (record is Dictionary):
			_fail("Invalid adjacent resource support record.")
			return false
		if String(record.get("mine_placement_id", "")) == "" or String(record.get("category_id", "")) not in EXPECTED_CATEGORIES:
			_fail("Adjacent resource support record missed mine/category context: %s" % JSON.stringify(record))
			return false

	for diagnostic in summary.get("diagnostics", []):
		if not (diagnostic is Dictionary):
			_fail("Invalid mine/resource diagnostic.")
			return false
		if String(diagnostic.get("severity", "")) == "failure":
			_fail("Mine/resource summary reported a failure diagnostic: %s" % JSON.stringify(diagnostic))
			return false
	return true

func _mine_category_counts(objects: Array) -> Dictionary:
	var counts := {}
	for object in objects:
		if not (object is Dictionary):
			continue
		if String(object.get("kind", "")) != "mine":
			continue
		var category := String(object.get("mine_category_id", object.get("category_id", "")))
		counts[category] = int(counts.get(category, 0)) + 1
		if String(object.get("source_phase", "")) not in ["phase_7_mine_minimum", "phase_7_mine_density"]:
			_fail("Mine placement missed Phase 7 source phase: %s" % JSON.stringify(object))
			return counts
		if String(object.get("source_field_offset", "")) not in MINIMUM_OFFSETS and String(object.get("source_field_offset", "")) not in DENSITY_OFFSETS:
			_fail("Mine placement missed recovered source field offset: %s" % JSON.stringify(object))
			return counts
	return counts

func _total_count(counts: Dictionary) -> int:
	var total := 0
	for key in counts:
		total += int(counts[key])
	return total

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
