extends Node

const REPORT_ID := "NATIVE_RANDOM_MAP_ZONE_PLAYER_STARTS_REPORT"

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
	if not capabilities.has("native_random_map_zone_player_starts_foundation"):
		_fail("Native zone/player-start capability is missing: %s" % JSON.stringify(Array(capabilities)))
		return

	var config := {
		"seed": "native-rmg-zone-player-starts-10184",
		"size": {
			"width": 36,
			"height": 36,
			"level_count": 1,
			"size_class_id": "homm3_small",
			"water_mode": "land",
		},
		"player_constraints": {
			"human_count": 1,
			"computer_count": 3,
			"team_mode": "free_for_all",
		},
		"profile": {
			"id": "native_zone_player_starts_profile",
			"template_id": "native_foundation_spoke",
			"terrain_ids": ["grass", "dirt", "rough", "snow"],
			"faction_ids": ["faction_embercourt", "faction_mireclaw", "faction_sunvault", "faction_thornwake"],
		},
	}
	var changed_seed_config := config.duplicate(true)
	changed_seed_config["seed"] = "native-rmg-zone-player-starts-10184-changed"

	var first: Dictionary = service.generate_random_map(config)
	var second: Dictionary = service.generate_random_map(config.duplicate(true))
	var changed: Dictionary = service.generate_random_map(changed_seed_config)

	_assert_foundation_shape(first, 36, 36, 4)
	_assert_foundation_shape(second, 36, 36, 4)
	_assert_foundation_shape(changed, 36, 36, 4)

	var first_layout: Dictionary = first.get("zone_layout", {})
	var second_layout: Dictionary = second.get("zone_layout", {})
	var changed_layout: Dictionary = changed.get("zone_layout", {})
	var first_starts: Dictionary = first.get("player_starts", {})
	var second_starts: Dictionary = second.get("player_starts", {})
	var changed_starts: Dictionary = changed.get("player_starts", {})

	var first_zone_signature := String(first_layout.get("signature", ""))
	var second_zone_signature := String(second_layout.get("signature", ""))
	var changed_zone_signature := String(changed_layout.get("signature", ""))
	var first_start_signature := String(first_starts.get("signature", ""))
	var second_start_signature := String(second_starts.get("signature", ""))
	var changed_start_signature := String(changed_starts.get("signature", ""))
	if first_zone_signature == "" or first_start_signature == "":
		_fail("Zone/player-start signatures must be non-empty.")
		return
	if first_zone_signature != second_zone_signature or first_start_signature != second_start_signature:
		_fail("Same seed/config did not produce stable zone/player-start signatures.")
		return
	if first_zone_signature == changed_zone_signature:
		_fail("Changed seed did not change the zone layout signature.")
		return
	if first_start_signature == changed_start_signature:
		_fail("Changed seed did not change the player start signature.")
		return

	var start_positions := {}
	for start_value in first_starts.get("starts", []):
		var start: Dictionary = start_value
		var key := "%d,%d,%d" % [int(start.get("x", -1)), int(start.get("y", -1)), int(start.get("level", -1))]
		if start_positions.has(key):
			_fail("Duplicate player start position found at %s." % key)
			return
		start_positions[key] = true
		if String(start.get("bounds_status", "")) != "in_bounds":
			_fail("Player start out of bounds: %s" % JSON.stringify(start))
			return
		if int(start.get("x", -1)) < 0 or int(start.get("x", -1)) >= 36 or int(start.get("y", -1)) < 0 or int(start.get("y", -1)) >= 36:
			_fail("Player start coordinate failed explicit bounds check: %s" % JSON.stringify(start))
			return
		if String(start.get("zone_id", "")) == "" or int(start.get("player_slot", 0)) <= 0:
			_fail("Player start is missing usable slot/zone metadata: %s" % JSON.stringify(start))
			return

	var report: Dictionary = first.get("report", {})
	if String(report.get("zone_generation_status", "")) != "zones_generated_foundation":
		_fail("Report did not carry zone_generation_status: %s" % JSON.stringify(report))
		return
	if String(report.get("player_start_generation_status", "")) != "player_starts_generated_foundation":
		_fail("Report did not carry player_start_generation_status: %s" % JSON.stringify(report))
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"binding_kind": metadata.get("binding_kind", ""),
		"native_extension_loaded": metadata.get("native_extension_loaded", false),
		"status": first.get("status", ""),
		"full_generation_status": first.get("full_generation_status", ""),
		"zone_generation_status": first.get("zone_generation_status", ""),
		"player_start_generation_status": first.get("player_start_generation_status", ""),
		"zone_count": first_layout.get("zone_count", 0),
		"start_count": first_starts.get("start_count", 0),
		"minimum_spacing_tiles": first_starts.get("minimum_spacing_tiles", 0),
		"zone_signature": first_zone_signature,
		"changed_zone_signature": changed_zone_signature,
		"player_start_signature": first_start_signature,
		"changed_player_start_signature": changed_start_signature,
	})])
	get_tree().quit(0)

func _assert_foundation_shape(generated: Dictionary, expected_width: int, expected_height: int, expected_players: int) -> void:
	if not bool(generated.get("ok", false)):
		_fail("Native RMG zone/player-start generation returned ok=false: %s" % JSON.stringify(generated))
		return
	if String(generated.get("status", "")) != "partial_foundation":
		_fail("Native RMG zone/player-start slice did not preserve partial_foundation status.")
		return
	if String(generated.get("full_generation_status", "")) != "not_implemented":
		_fail("Native RMG zone/player-start slice falsely implied full generation.")
		return
	if String(generated.get("zone_generation_status", "")) != "zones_generated_foundation":
		_fail("Missing top-level zone_generation_status.")
		return
	if String(generated.get("player_start_generation_status", "")) != "player_starts_generated_foundation":
		_fail("Missing top-level player_start_generation_status.")
		return

	var normalized: Dictionary = generated.get("normalized_config", {})
	if int(normalized.get("width", 0)) != expected_width or int(normalized.get("height", 0)) != expected_height:
		_fail("Normalized dimensions mismatch: %s" % JSON.stringify(normalized))
		return
	var assignment: Dictionary = generated.get("player_assignment", {})
	if int(assignment.get("player_count", 0)) != expected_players:
		_fail("Player assignment count mismatch: %s" % JSON.stringify(assignment))
		return

	var layout: Dictionary = generated.get("zone_layout", {})
	if String(layout.get("schema_id", "")) != "aurelion_native_rmg_zone_layout_v1":
		_fail("Zone layout schema mismatch: %s" % JSON.stringify(layout))
		return
	if String(layout.get("generation_status", "")) != "zones_generated_foundation":
		_fail("Zone layout status mismatch: %s" % JSON.stringify(layout))
		return
	if int(layout.get("zone_count", 0)) <= expected_players:
		_fail("Zone layout did not include start plus neutral zones: %s" % JSON.stringify(layout))
		return
	var dimensions: Dictionary = layout.get("dimensions", {})
	if int(dimensions.get("width", 0)) != expected_width or int(dimensions.get("height", 0)) != expected_height:
		_fail("Zone layout dimensions mismatch: %s" % JSON.stringify(dimensions))
		return
	var owner_grid: Array = layout.get("surface_owner_grid", [])
	if owner_grid.size() != expected_height:
		_fail("Owner grid height mismatch.")
		return
	for row_value in owner_grid:
		var row: Array = row_value
		if row.size() != expected_width:
			_fail("Owner grid row width mismatch.")
			return
	for zone_value in layout.get("zones", []):
		var zone: Dictionary = zone_value
		var bounds: Dictionary = zone.get("bounds", {})
		if int(zone.get("cell_count", 0)) <= 0:
			_fail("Zone has no owned cells: %s" % JSON.stringify(zone))
			return
		if int(bounds.get("min_x", -1)) < 0 or int(bounds.get("max_x", -1)) >= expected_width or int(bounds.get("min_y", -1)) < 0 or int(bounds.get("max_y", -1)) >= expected_height:
			_fail("Zone bounds are invalid: %s" % JSON.stringify(zone))
			return
		if String(zone.get("terrain_id", "")) == "":
			_fail("Zone missing terrain association: %s" % JSON.stringify(zone))
			return

	var starts: Dictionary = generated.get("player_starts", {})
	if String(starts.get("schema_id", "")) != "aurelion_native_rmg_player_starts_v1":
		_fail("Player starts schema mismatch: %s" % JSON.stringify(starts))
		return
	if String(starts.get("generation_status", "")) != "player_starts_generated_foundation":
		_fail("Player starts status mismatch: %s" % JSON.stringify(starts))
		return
	if int(starts.get("start_count", 0)) != expected_players:
		_fail("Player start count mismatch: %s" % JSON.stringify(starts))
		return
	if int(starts.get("minimum_spacing_tiles", 0)) < 3:
		_fail("Minimum spacing was not recorded usefully: %s" % JSON.stringify(starts))
		return

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
