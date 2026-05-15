extends Node

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")

const REPORT_ID := "NATIVE_RMG_SMALL_H3MAPED_NEGATIVE_VALIDATOR_REPORT"
const REPORT_SCHEMA_ID := "native_rmg_small_h3maped_negative_validator_report_v1"

const EXPECTED_CASE_RULES := {
	"missing_player_starts": ["owned_start_towns"],
	"duplicate_placement_id": ["duplicate_placement_ids"],
	"out_of_bounds_object": ["out_of_bounds_objects"],
	"missing_mines": ["mines_present"],
	"missing_rewards": ["rewards_present"],
	"missing_connection_blockers": ["blocking_connection_obstacles", "unguarded_route_barriers"],
	"missing_connection_guards": ["blocking_connection_guards", "unguarded_route_barriers"],
	"missing_road_route_graph": ["road_route_graph_missing", "road_segment_without_route_edge"],
	"one_cell_fake_road": ["road_segment_short_or_loop_like"],
	"bad_final_tile_byte_size": ["final_tile_byte_arrays"],
}

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
	if not capabilities.has("native_rmg_small_h3maped_negative_validator_cases"):
		_fail("Native capability list missed h3maped negative validator cases: %s" % JSON.stringify(Array(capabilities)))
		return

	var config := ScenarioSelectRulesScript.build_random_map_player_config("1", "", "", 3, "land", false, "homm3_small")
	var report: Dictionary = service.inspect_h3maped_small_rmg_negative_validator_cases(config)
	if not bool(report.get("ok", false)) \
			or String(report.get("status", "")) != "pass" \
			or String(report.get("schema_id", "")) != "aurelion_h3maped_small_fast_structural_negative_validator_cases_v1" \
			or String(report.get("negative_validator_authority", "")) != "h3maped_fast_structural_validator_phase":
		_fail("Native h3maped negative validator report did not pass: %s" % JSON.stringify(report))
		return
	if int(report.get("case_count", 0)) < EXPECTED_CASE_RULES.size() or int(report.get("failed_case_count", -1)) != 0:
		_fail("Native h3maped negative validator case totals drifted: %s" % JSON.stringify(report))
		return
	var base_validator: Dictionary = report.get("base_validator", {}) if report.get("base_validator", {}) is Dictionary else {}
	if String(base_validator.get("status", "")) != "strict_fast_structural_validator_pass_public_generation_ready" \
			or int(base_validator.get("failure_count", -1)) != 0:
		_fail("Native h3maped negative validator base case is not green: %s" % JSON.stringify(base_validator))
		return

	var cases_by_id := {}
	for case_report in report.get("cases", []):
		if not case_report is Dictionary:
			continue
		cases_by_id[String(case_report.get("case_id", ""))] = case_report
	for case_id in EXPECTED_CASE_RULES.keys():
		if not cases_by_id.has(case_id):
			_fail("Native h3maped negative validator missed case %s: %s" % [case_id, JSON.stringify(report)])
			return
		var case_report: Dictionary = cases_by_id[case_id]
		if not bool(case_report.get("ok", false)) \
				or String(case_report.get("status", "")) != "negative_case_rejected_by_expected_rules" \
				or int(case_report.get("failure_count", 0)) <= 0:
			_fail("Native h3maped negative validator case did not reject %s: %s" % [case_id, JSON.stringify(case_report)])
			return
		var actual_rules: Array = case_report.get("actual_rules", [])
		for expected_rule in EXPECTED_CASE_RULES[case_id]:
			if not actual_rules.has(expected_rule):
				_fail("Native h3maped negative validator case %s missed rule %s: %s" % [case_id, expected_rule, JSON.stringify(case_report)])
				return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"schema_id": REPORT_SCHEMA_ID,
		"ok": true,
		"case_count": int(report.get("case_count", 0)),
		"failed_case_count": int(report.get("failed_case_count", 0)),
		"case_ids": cases_by_id.keys(),
		"base_validator_status": String(base_validator.get("status", "")),
		"negative_validator_authority": String(report.get("negative_validator_authority", "")),
		"remaining_gap": "Slice F now proves native fast structural validator rejection for injected bad Small h3maped packages. This is negative validator coverage only; Small-land corpus and broad editor/runtime acceptance remain pending.",
	})])
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"schema_id": REPORT_SCHEMA_ID,
		"ok": false,
		"error": message,
	})])
	get_tree().quit(1)
