extends "res://tests/eight_neutral_dwelling_musters_report.gd"

const AbilityRuntimeReportScript = preload("res://tests/unit_ability_runtime_report.gd")

const BATCH_REPORT_ID := "FOUR_ELDER_WILD_RECRUITMENT_SANCTUARIES_SMOKE"
const BATCH_OUTPUT_DIR := "res://.artifacts/four_elder_wild_recruitment_sanctuaries_smoke"
const BATCH_ATLAS_PATH := "res://art/overworld/runtime/objects/resource_sites/elder_wild_sanctuaries/elder_wild_sanctuaries_atlas.png"
const BATCH_CASES := [
	{
		"scenario_id":"ninefold-confluence",
		"site_id":"site_galehorn_windfold",
		"placement_id":"dwelling_galehorn_windfold",
		"guard_id":"ninefold_galehorn_breakline_watch",
		"encounter_id":"encounter_galehorn_breakline_watch",
		"unit_id":"unit_neutral_galehorn_striders",
		"ability_ids":["reach", "bloodrush"],
		"unclaimed":"mapobj_galehorn_windfold",
		"claimed":"resource_site_neutral_galehorn_windfold_controlled",
		"region":Rect2(48,0,48,48)
	},
	{
		"scenario_id":"ninefold-confluence",
		"site_id":"site_sunscale_lantern_conservatory",
		"placement_id":"dwelling_sunscale_lantern_conservatory",
		"guard_id":"ninefold_sunscale_lantern_drift_watch",
		"encounter_id":"encounter_sunscale_lantern_drift_watch",
		"unit_id":"unit_neutral_sunscale_lanternmoths",
		"ability_ids":["harry", "volley"],
		"unclaimed":"mapobj_sunscale_lantern_conservatory",
		"claimed":"resource_site_neutral_sunscale_lantern_conservatory_controlled",
		"region":Rect2(144,0,48,48)
	},
	{
		"scenario_id":"ninefold-confluence",
		"site_id":"site_rimebell_whitewake_eyrie",
		"placement_id":"dwelling_rimebell_whitewake_eyrie",
		"guard_id":"ninefold_rimebell_whitewake_watch",
		"encounter_id":"encounter_rimebell_whitewake_watch",
		"unit_id":"unit_neutral_rimebell_skyrakers",
		"ability_ids":["fog_screen", "reach"],
		"unclaimed":"mapobj_rimebell_whitewake_eyrie",
		"claimed":"resource_site_neutral_rimebell_whitewake_eyrie_controlled",
		"region":Rect2(240,0,48,48)
	},
	{
		"scenario_id":"ninefold-confluence",
		"site_id":"site_deepforge_seventh_vault",
		"placement_id":"dwelling_deepforge_seventh_vault",
		"guard_id":"ninefold_deepforge_seventh_seal_watch",
		"encounter_id":"encounter_deepforge_seventh_seal_watch",
		"unit_id":"unit_neutral_deepforge_vaultwyrms",
		"ability_ids":["brace", "shielding"],
		"unclaimed":"mapobj_deepforge_seventh_vault",
		"claimed":"resource_site_neutral_deepforge_seventh_vault_controlled",
		"region":Rect2(336,0,48,48)
	},
]


func _validate_case(view: Control, case: Dictionary) -> void:
	await super._validate_case(view, case)
	var unit_id := String(case.get("unit_id", ""))
	var unit := ContentService.get_unit(unit_id)
	_expect(int(unit.get("tier", 0)) >= 5, "%s is no longer an elder-tier neutral." % unit_id)
	var probe = AbilityRuntimeReportScript.new()
	var ability_results := {}
	for ability_id_value in case.get("ability_ids", []):
		var ability_id := String(ability_id_value)
		var result: Dictionary = probe.call("_runtime_consequence_for_ability", unit_id, ability_id)
		ability_results[ability_id] = result
		_expect(bool(result.get("ok", false)), "%s %s did not execute its complete live combat consequence: %s" % [unit_id, ability_id, JSON.stringify(result)])
	probe.free()
	if not _rows.is_empty():
		_rows[-1]["unit_id"] = unit_id
		_rows[-1]["unit_tier"] = int(unit.get("tier", 0))
		_rows[-1]["ability_results"] = ability_results


func _report_id() -> String:
	return BATCH_REPORT_ID


func _output_dir() -> String:
	return BATCH_OUTPUT_DIR


func _atlas_path() -> String:
	return BATCH_ATLAS_PATH


func _capture_environment_name() -> String:
	return "ELDER_WILD_SANCTUARY_CAPTURE_DIR"


func _cases() -> Array:
	return BATCH_CASES
