extends Node

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")

const REPORT_ID := "NATIVE_RANDOM_MAP_OWNER_NORMAL_WATER_UNDERGROUND_PACKAGE_REPORT"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not ClassDB.class_exists("MapPackageService"):
		_fail("MapPackageService native class is not available.")
		return
	var service: Variant = ClassDB.instantiate("MapPackageService")
	var config := ScenarioSelectRulesScript.build_random_map_player_config(
		"owner-corpus-small-normal-water-underground-10184",
		"",
		"",
		2,
		"normal_water",
		true,
		"homm3_small",
		ScenarioSelectRulesScript.RANDOM_MAP_TEMPLATE_SELECTION_MODE_CATALOG_AUTO
	)
	var generated: Dictionary = service.generate_random_map(config, {"startup_path": "owner_normal_water_underground_package_report"})
	if not bool(generated.get("ok", false)) or String(generated.get("validation_status", "")) != "pass":
		_fail("Native generation failed before package conversion: %s" % JSON.stringify(generated.get("validation_report", generated)))
		return
	var adoption: Dictionary = service.convert_generated_payload(generated, {
		"feature_gate": "native_rmg_owner_normal_water_underground_package_report",
		"session_save_version": 9,
		"scenario_id": "native_rmg_owner_normal_water_underground_package_report",
	})
	if not bool(adoption.get("ok", false)):
		_fail("convert_generated_payload failed: %s" % JSON.stringify(adoption))
		return
	var map_document: Variant = adoption.get("map_document", null)
	if map_document == null:
		_fail("convert_generated_payload did not return map_document: %s" % JSON.stringify(adoption))
		return
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"template_id": String(generated.get("normalized_config", {}).get("template_id", "")) if generated.get("normalized_config", {}) is Dictionary else "",
		"profile_id": String(generated.get("normalized_config", {}).get("profile_id", "")) if generated.get("normalized_config", {}) is Dictionary else "",
		"full_generation_status": String(generated.get("full_generation_status", "")),
		"validation_status": String(generated.get("validation_status", "")),
		"map_object_count": int(map_document.get_object_count()),
		"map_level_count": int(map_document.get_level_count()),
	})])
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
