extends Node

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")

const REPORT_ID := "NATIVE_RANDOM_MAP_SUPPORTED_UNDERGROUND_TERRAIN_COUNT_REPORT"
const EXPECTED_TILE_COUNT := 36 * 36 * 2

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not ClassDB.class_exists("MapPackageService"):
		_fail("MapPackageService native class is not available.")
		return
	var service: Variant = ClassDB.instantiate("MapPackageService")
	var config := ScenarioSelectRulesScript.build_random_map_player_config(
		"native-rmg-supported-underground-terrain-count-10184",
		"translated_rmg_template_001_v1",
		"translated_rmg_profile_001_v1",
		4,
		"land",
		true,
		"homm3_small"
	)
	var generated: Dictionary = service.generate_random_map(config, {"startup_path": "supported_underground_terrain_count"})
	if not bool(generated.get("ok", false)) or String(generated.get("validation_status", "")) != "pass":
		_fail("Supported underground generation did not validate: %s" % JSON.stringify(generated.get("validation_report", generated)))
		return
	if String(generated.get("status", "")) != "full_parity_supported" or String(generated.get("full_generation_status", "")) == "not_implemented":
		_fail("Supported underground generation lost full-parity status: %s" % JSON.stringify(generated.get("report", {})))
		return
	var terrain: Dictionary = generated.get("terrain_grid", {}) if generated.get("terrain_grid", {}) is Dictionary else {}
	if int(terrain.get("tile_count", 0)) != EXPECTED_TILE_COUNT:
		_fail("Supported underground tile count did not include both native levels: %s" % JSON.stringify(terrain))
		return
	if int(terrain.get("materialized_level_count", 0)) != 2 or String(terrain.get("level_count_semantics", "")) != "all_native_levels_materialized":
		_fail("Supported underground terrain did not explicitly materialize both levels: %s" % JSON.stringify(terrain))
		return
	var terrain_sum := 0
	var terrain_counts: Dictionary = terrain.get("terrain_counts", {}) if terrain.get("terrain_counts", {}) is Dictionary else {}
	for terrain_id in terrain_counts.keys():
		terrain_sum += int(terrain_counts.get(terrain_id, 0))
	if terrain_sum != EXPECTED_TILE_COUNT:
		_fail("Supported underground terrain_counts sum mismatch: %d/%d %s" % [terrain_sum, EXPECTED_TILE_COUNT, JSON.stringify(terrain_counts)])
		return
	for failure in generated.get("validation_report", {}).get("failures", []):
		if failure is Dictionary and String(failure.get("code", "")) == "terrain_count_sum_mismatch":
			_fail("Supported underground validation still reported terrain_count_sum_mismatch: %s" % JSON.stringify(generated.get("validation_report", {})))
			return
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"status": generated.get("status", ""),
		"full_generation_status": generated.get("full_generation_status", ""),
		"tile_count": int(terrain.get("tile_count", 0)),
		"terrain_sum": terrain_sum,
		"materialized_level_count": int(terrain.get("materialized_level_count", 0)),
		"level_count_semantics": String(terrain.get("level_count_semantics", "")),
	})])
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
