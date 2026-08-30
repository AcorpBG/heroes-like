extends "res://tests/eight_neutral_dwelling_musters_report.gd"

const AbilityRuntimeReportScript = preload("res://tests/unit_ability_runtime_report.gd")

const BATCH_REPORT_ID := "TWO_ELITE_NEUTRAL_DWELLINGS_REPORT"
const BATCH_OUTPUT_DIR := "res://.artifacts/two_elite_neutral_dwellings_report"
const BATCH_ATLAS_PATH := "res://art/overworld/runtime/objects/resource_sites/elite_neutral_dwelling_atlas.png"
const BATCH_CASES := [
	{
		"scenario_id":"ninefold-confluence",
		"site_id":"site_cinderwake_fold",
		"placement_id":"dwelling_cinderwake_fold",
		"guard_id":"ninefold_cinderwake_fold_watch",
		"encounter_id":"encounter_cinderwake_fold_watch",
		"unit_id":"unit_neutral_cinderwake_aurochs",
		"ability_ids":["reach", "shielding"],
		"unclaimed":"mapobj_cinderwake_fold",
		"claimed":"resource_site_neutral_cinderwake_fold_controlled",
		"region":Rect2(48,0,48,48)
	},
	{
		"scenario_id":"ninefold-confluence",
		"site_id":"site_tideglass_roost",
		"placement_id":"dwelling_tideglass_roost",
		"guard_id":"ninefold_tideglass_roost_watch",
		"encounter_id":"encounter_tideglass_roost_watch",
		"unit_id":"unit_neutral_tideglass_skyrays",
		"ability_ids":["harry", "volley"],
		"unclaimed":"mapobj_tideglass_roost",
		"claimed":"resource_site_neutral_tideglass_roost_controlled",
		"region":Rect2(144,0,48,48)
	},
]


func _validate_case(view: Control, case: Dictionary) -> void:
	await super._validate_case(view, case)
	var probe = AbilityRuntimeReportScript.new()
	var ability_results := {}
	for ability_id_value in case.get("ability_ids", []):
		var ability_id := String(ability_id_value)
		var result: Dictionary = probe.call("_runtime_consequence_for_ability", String(case.get("unit_id", "")), ability_id)
		ability_results[ability_id] = result
		_expect(bool(result.get("ok", false)), "%s %s did not execute its complete live combat consequence: %s" % [String(case.get("unit_id", "")), ability_id, JSON.stringify(result)])
	probe.free()
	if not _rows.is_empty():
		_rows[-1]["unit_id"] = String(case.get("unit_id", ""))
		_rows[-1]["ability_results"] = ability_results


func _report_id() -> String:
	return BATCH_REPORT_ID


func _output_dir() -> String:
	return BATCH_OUTPUT_DIR


func _atlas_path() -> String:
	return BATCH_ATLAS_PATH


func _capture_environment_name() -> String:
	return "ELITE_NEUTRAL_DWELLING_CAPTURE_DIR"


func _cases() -> Array:
	return BATCH_CASES
