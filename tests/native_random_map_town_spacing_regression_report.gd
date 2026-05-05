extends Node

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")

const REPORT_ID := "NATIVE_RANDOM_MAP_TOWN_SPACING_REGRESSION_REPORT"
const REPORT_SCHEMA_ID := "native_random_map_town_spacing_regression_report_v1"

const CASES := [
	{
		"id": "small_default_land",
		"seed": "town-spacing-small-default-10184",
		"template_id": "border_gate_compact_v1",
		"profile_id": "border_gate_compact_profile_v1",
		"player_count": 3,
		"water_mode": "land",
		"size_class_id": "homm3_small",
		"minimum_direct_route_distance": 8,
	},
	{
		"id": "small_translated_islands",
		"seed": "town-spacing-small-islands-10184",
		"template_id": "translated_rmg_template_001_v1",
		"profile_id": "translated_rmg_profile_001_v1",
		"player_count": 4,
		"water_mode": "islands",
		"size_class_id": "homm3_small",
		"minimum_direct_route_distance": 8,
	},
	{
		"id": "medium_default_land",
		"seed": "town-spacing-medium-default-10184",
		"template_id": "translated_rmg_template_002_v1",
		"profile_id": "translated_rmg_profile_002_v1",
		"player_count": 4,
		"water_mode": "land",
		"size_class_id": "homm3_medium",
		"minimum_direct_route_distance": 12,
	},
	{
		"id": "medium_validation_gate_land",
		"seed": "town-spacing-medium-gate-10184",
		"template_id": "translated_rmg_template_005_v1",
		"profile_id": "translated_rmg_profile_005_v1",
		"player_count": 4,
		"water_mode": "land",
		"size_class_id": "homm3_medium",
		"minimum_direct_route_distance": 12,
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

	var summaries := []
	for case_record in CASES:
		var summary := _run_case(service, case_record)
		if summary.is_empty():
			return
		summaries.append(summary)

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"schema_id": REPORT_SCHEMA_ID,
		"ok": true,
		"binding_kind": metadata.get("binding_kind", ""),
		"native_extension_loaded": metadata.get("native_extension_loaded", false),
		"cases": summaries,
	})])
	get_tree().quit(0)

func _run_case(service: Variant, case_record: Dictionary) -> Dictionary:
	var config := ScenarioSelectRulesScript.build_random_map_player_config(
		String(case_record.get("seed", "")),
		String(case_record.get("template_id", "")),
		String(case_record.get("profile_id", "")),
		int(case_record.get("player_count", 4)),
		String(case_record.get("water_mode", "land")),
		false,
		String(case_record.get("size_class_id", "homm3_small"))
	)
	var generated: Dictionary = service.generate_random_map(config, {"startup_path": "town_spacing_%s" % String(case_record.get("id", ""))})
	if not bool(generated.get("ok", false)) or String(generated.get("validation_status", "")) != "pass":
		_fail("%s generation failed validation: %s" % [String(case_record.get("id", "")), JSON.stringify(generated.get("validation_report", generated))])
		return {}
	var towns: Array = generated.get("town_records", []) if generated.get("town_records", []) is Array else []
	var distance_summary := _town_distance_summary(towns)
	var minimum_direct := int(case_record.get("minimum_direct_route_distance", 8))
	if int(distance_summary.get("pair_count", 0)) > 0 and int(distance_summary.get("minimum_direct_route_distance", 0)) < minimum_direct:
		_fail("%s closest towns are too close: %s" % [String(case_record.get("id", "")), JSON.stringify(distance_summary)])
		return {}
	var town_spacing: Dictionary = generated.get("town_guard_placement", {}).get("town_placement", {}).get("town_spacing", {}) if generated.get("town_guard_placement", {}) is Dictionary and generated.get("town_guard_placement", {}).get("town_placement", {}) is Dictionary and generated.get("town_guard_placement", {}).get("town_placement", {}).get("town_spacing", {}) is Dictionary else {}
	if not bool(town_spacing.get("ok", false)):
		_fail("%s native town spacing summary did not pass: %s" % [String(case_record.get("id", "")), JSON.stringify(town_spacing)])
		return {}
	return {
		"id": String(case_record.get("id", "")),
		"template_id": String(generated.get("normalized_config", {}).get("template_id", "")),
		"profile_id": String(generated.get("normalized_config", {}).get("profile_id", "")),
		"width": int(generated.get("normalized_config", {}).get("width", 0)),
		"height": int(generated.get("normalized_config", {}).get("height", 0)),
		"town_count": towns.size(),
		"minimum_direct_route_distance_required": minimum_direct,
		"distance_summary": distance_summary,
		"native_town_spacing": town_spacing,
	}

func _town_distance_summary(towns: Array) -> Dictionary:
	var pair_count := 0
	var minimum_direct := 999999
	var minimum_manhattan := 999999
	var closest_pair := []
	for left_index in range(towns.size()):
		var left: Dictionary = towns[left_index] if towns[left_index] is Dictionary else {}
		for right_index in range(left_index + 1, towns.size()):
			var right: Dictionary = towns[right_index] if towns[right_index] is Dictionary else {}
			var dx: int = abs(int(left.get("x", 0)) - int(right.get("x", 0)))
			var dy: int = abs(int(left.get("y", 0)) - int(right.get("y", 0)))
			var direct: int = max(dx, dy)
			var manhattan: int = dx + dy
			pair_count += 1
			if direct < minimum_direct:
				minimum_direct = direct
				minimum_manhattan = manhattan
				closest_pair = [
					_town_brief(left),
					_town_brief(right),
				]
	if pair_count == 0:
		minimum_direct = 0
		minimum_manhattan = 0
	return {
		"pair_count": pair_count,
		"minimum_direct_route_distance": minimum_direct,
		"minimum_manhattan_distance": minimum_manhattan,
		"closest_pair": closest_pair,
	}

func _town_brief(town: Dictionary) -> Dictionary:
	return {
		"placement_id": String(town.get("placement_id", "")),
		"record_type": String(town.get("record_type", "")),
		"zone_id": String(town.get("zone_id", "")),
		"x": int(town.get("x", 0)),
		"y": int(town.get("y", 0)),
	}

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
