extends Node

const REPORT_ID := "NATIVE_RANDOM_MAP_TERRAIN_GRID_REPORT"

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
	if not capabilities.has("native_random_map_terrain_grid_foundation"):
		_fail("Native RMG terrain-grid capability is missing: %s" % JSON.stringify(Array(capabilities)))
		return

	var config := {
		"seed": "native-rmg-terrain-grid-10184",
		"size": {
			"width": 36,
			"height": 36,
			"level_count": 1,
			"size_class_id": "homm3_small",
			"water_mode": "land",
		},
		"profile": {
			"id": "native_terrain_grid_profile",
			"terrain_ids": ["grass", "dirt", "rough", "snow"],
			"faction_ids": ["faction_embercourt", "faction_mireclaw"],
		},
	}
	var changed_seed_config := config.duplicate(true)
	changed_seed_config["seed"] = "native-rmg-terrain-grid-10184-changed"

	var first: Dictionary = service.generate_random_map(config)
	var second: Dictionary = service.generate_random_map(config.duplicate(true))
	var changed: Dictionary = service.generate_random_map(changed_seed_config)
	var surface_only_config := config.duplicate(true)
	surface_only_config["seed"] = "native-rmg-terrain-grid-surface-only-10184"
	surface_only_config["profile"] = {
		"id": "native_terrain_grid_surface_only_profile",
		"terrain_ids": ["grass", "dirt", "rough", "snow", "underground"],
		"faction_ids": ["faction_embercourt", "faction_mireclaw"],
	}
	var surface_only: Dictionary = service.generate_random_map(surface_only_config)
	var two_level_config := surface_only_config.duplicate(true)
	two_level_config["seed"] = "native-rmg-terrain-grid-two-level-10184"
	two_level_config["size"] = surface_only_config.get("size", {}).duplicate(true)
	two_level_config["size"]["level_count"] = 2
	var two_level: Dictionary = service.generate_random_map(two_level_config)

	_assert_generated_shape(first, 36, 36)
	_assert_generated_shape(second, 36, 36)
	_assert_generated_shape(changed, 36, 36)
	_assert_generated_shape(surface_only, 36, 36)
	_assert_generated_shape(two_level, 36, 36, 2)
	if not _assert_surface_underground_terrain_policy(surface_only, two_level):
		return

	var first_grid: Dictionary = first.get("terrain_grid", {})
	var second_grid: Dictionary = second.get("terrain_grid", {})
	var changed_grid: Dictionary = changed.get("terrain_grid", {})
	var first_signature := String(first_grid.get("signature", ""))
	var second_signature := String(second_grid.get("signature", ""))
	var changed_signature := String(changed_grid.get("signature", ""))
	if first_signature == "":
		_fail("Terrain grid signature was empty.")
		return
	if first_signature != second_signature:
		_fail("Same native RMG config did not produce stable terrain grid signature.")
		return
	if first_signature == changed_signature:
		_fail("Changed seed did not change terrain grid signature.")
		return

	var level: Dictionary = first_grid.get("levels", [])[0]
	var terrain_codes: PackedInt32Array = level.get("terrain_code_u16", PackedInt32Array())
	var terrain_ids: PackedStringArray = first_grid.get("terrain_id_by_code", PackedStringArray())
	if terrain_codes.size() != 36 * 36:
		_fail("Terrain code array size %d did not match 36x36." % terrain_codes.size())
		return
	if terrain_ids.size() < 8:
		_fail("Terrain id code table is incomplete: %s" % JSON.stringify(Array(terrain_ids)))
		return
	var distinct_codes := {}
	for code in terrain_codes:
		if int(code) < 0 or int(code) >= terrain_ids.size():
			_fail("Terrain code %d is outside code table size %d." % [int(code), terrain_ids.size()])
			return
		distinct_codes[str(int(code))] = true
	if distinct_codes.size() < 2:
		_fail("Terrain grid did not distribute at least two terrain ids.")
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"binding_kind": metadata.get("binding_kind", ""),
		"native_extension_loaded": metadata.get("native_extension_loaded", false),
		"status": first.get("status", ""),
		"full_generation_status": first.get("full_generation_status", ""),
		"terrain_generation_status": first.get("terrain_generation_status", ""),
		"width": first_grid.get("width", 0),
		"height": first_grid.get("height", 0),
		"tile_count": first_grid.get("tile_count", 0),
		"terrain_palette_ids": first_grid.get("terrain_palette_ids", []),
		"terrain_counts": first_grid.get("terrain_counts", {}),
		"surface_only_counts": surface_only.get("terrain_grid", {}).get("terrain_counts", {}),
		"two_level_counts": two_level.get("terrain_grid", {}).get("terrain_counts", {}),
		"signature": first_signature,
		"changed_seed_signature": changed_signature,
	})])
	get_tree().quit(0)

func _assert_generated_shape(generated: Dictionary, expected_width: int, expected_height: int, expected_level_count: int = 1) -> void:
	if not bool(generated.get("ok", false)):
		_fail("Native RMG terrain-grid generation returned ok=false: %s" % JSON.stringify(generated))
		return
	if String(generated.get("status", "")) != "partial_foundation":
		_fail("Native RMG terrain-grid slice did not preserve partial_foundation status.")
		return
	if String(generated.get("full_generation_status", "")) != "not_implemented":
		_fail("Native RMG terrain-grid slice falsely implied full generation.")
		return
	if String(generated.get("terrain_generation_status", "")) != "terrain_grid_generated":
		_fail("Native RMG terrain-grid slice did not report terrain_grid_generated.")
		return
	var grid: Dictionary = generated.get("terrain_grid", {})
	if String(grid.get("schema_id", "")) != "aurelion_native_rmg_terrain_grid_v1":
		_fail("Terrain grid schema mismatch: %s" % JSON.stringify(grid))
		return
	if int(grid.get("width", 0)) != expected_width or int(grid.get("height", 0)) != expected_height:
		_fail("Terrain grid dimensions were %dx%d, expected %dx%d." % [int(grid.get("width", 0)), int(grid.get("height", 0)), expected_width, expected_height])
		return
	if int(grid.get("tile_count", 0)) != expected_width * expected_height * expected_level_count:
		_fail("Terrain grid tile count mismatch: %s" % JSON.stringify(grid))
		return
	var levels: Array = grid.get("levels", [])
	if levels.size() != expected_level_count:
		_fail("Terrain grid level count mismatch: %s" % JSON.stringify(grid))
		return
	var level: Dictionary = levels[0]
	if int(level.get("tile_count", 0)) != expected_width * expected_height:
		_fail("Terrain level tile count mismatch: %s" % JSON.stringify(level))
		return
	var counted := 0
	for value in grid.get("terrain_counts", {}).values():
		counted += int(value)
	if counted != expected_width * expected_height * expected_level_count:
		_fail("Terrain counts summed to %d instead of %d." % [counted, expected_width * expected_height * expected_level_count])
		return
	var report: Dictionary = generated.get("report", {})
	if String(report.get("terrain_grid_status", "")) != "terrain_grid_generated":
		_fail("Terrain grid report status missing: %s" % JSON.stringify(report))
		return

func _assert_surface_underground_terrain_policy(surface_only: Dictionary, two_level: Dictionary) -> bool:
	var surface_grid: Dictionary = surface_only.get("terrain_grid", {}) if surface_only.get("terrain_grid", {}) is Dictionary else {}
	var surface_counts: Dictionary = surface_grid.get("terrain_counts", {}) if surface_grid.get("terrain_counts", {}) is Dictionary else {}
	if int(surface_counts.get("underground", 0)) != 0:
		_fail("Surface-only map materialized underground terrain on level 0: %s" % JSON.stringify(surface_counts))
		return false
	if String(surface_grid.get("underground_terrain_policy", "")) != "not_materialized_for_surface_only_maps":
		_fail("Surface-only terrain grid missed underground terrain policy: %s" % JSON.stringify(surface_grid))
		return false
	var two_level_grid: Dictionary = two_level.get("terrain_grid", {}) if two_level.get("terrain_grid", {}) is Dictionary else {}
	var levels: Array = two_level_grid.get("levels", []) if two_level_grid.get("levels", []) is Array else []
	if levels.size() != 2:
		_fail("Two-level map did not materialize two terrain levels: %s" % JSON.stringify(two_level_grid))
		return false
	var surface_level: Dictionary = levels[0] if levels[0] is Dictionary else {}
	var underground_level: Dictionary = levels[1] if levels[1] is Dictionary else {}
	var surface_level_counts: Dictionary = surface_level.get("terrain_counts", {}) if surface_level.get("terrain_counts", {}) is Dictionary else {}
	var underground_level_counts: Dictionary = underground_level.get("terrain_counts", {}) if underground_level.get("terrain_counts", {}) is Dictionary else {}
	if int(surface_level_counts.get("underground", 0)) != 0:
		_fail("Two-level map used underground terrain on the surface layer: %s" % JSON.stringify(surface_level_counts))
		return false
	if int(underground_level_counts.get("underground", 0)) != 36 * 36:
		_fail("Two-level map did not reserve underground terrain for level 1: %s" % JSON.stringify(underground_level_counts))
		return false
	return true

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
