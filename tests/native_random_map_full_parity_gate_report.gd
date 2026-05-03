extends Node

const ComparisonReportScript = preload("res://tests/native_random_map_gdscript_comparison_report.gd")
const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")

const REPORT_ID := "NATIVE_RANDOM_MAP_FULL_PARITY_GATE_REPORT"
const REPORT_SCHEMA_ID := "native_random_map_full_parity_gate_report_v1"

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
	if not capabilities.has("native_random_map_full_parity_supported_profiles"):
		_fail("Native full-parity capability is missing: %s" % JSON.stringify(Array(capabilities)))
		return

	var comparison := ComparisonReportScript.new()
	var fixture: Dictionary = comparison._load_fixture()
	var cases: Array = fixture.get("cases", []) if fixture.get("cases", []) is Array else []
	if cases.is_empty():
		_fail("Comparison fixture has no cases.")
		return

	var case_reports := []
	var gap_records := []
	for case_record in cases:
		var case_report: Dictionary = comparison._run_case(service, case_record)
		if case_report.is_empty():
			comparison.free()
			_fail("Comparison case returned an empty report for %s." % String(case_record.get("id", "")))
			return
		case_reports.append(case_report)
		for gap in case_report.get("known_gaps", []):
			gap_records.append(gap)
		_assert_case_full_parity(case_report)
	comparison.free()
	var unsupported_report := _assert_adjacent_config_unsupported(service)

	var report := {
		"schema_id": REPORT_SCHEMA_ID,
		"ok": gap_records.is_empty(),
		"binding_kind": metadata.get("binding_kind", ""),
		"native_extension_loaded": metadata.get("native_extension_loaded", false),
		"case_count": case_reports.size(),
		"blocking_gap_count": gap_records.size(),
		"blocking_gaps": gap_records,
		"cases": case_reports,
		"unsupported_scope_check": unsupported_report,
		"readiness": {
			"native_runtime_authoritative": true,
			"package_session_adoption_ready": true,
			"full_parity_claim": true,
			"runtime_call_site_adoption": false,
			"gdscript_fallback_untouched": true,
			"supported_scope": "tracked_homm3_small_border_gate_and_translated_profile_cases",
		},
	}
	if not gap_records.is_empty():
		_fail("Full parity gate still has blocking comparison gaps: %s" % JSON.stringify(gap_records))
		return
	print("%s %s" % [REPORT_ID, JSON.stringify(report)])
	get_tree().quit(0)

func _assert_adjacent_config_unsupported(service: Variant) -> Dictionary:
	var unsupported_config := ScenarioSelectRulesScript.build_random_map_player_config(
		"native-rmg-full-parity-gate-10184-unsupported-adjacent",
		"translated_rmg_template_001_v1",
		"translated_rmg_profile_001_v1",
		4,
		"land",
		false,
		"homm3_small"
	)
	var generated: Dictionary = service.generate_random_map(unsupported_config)
	var provenance: Dictionary = generated.get("provenance", {}) if generated.get("provenance", {}) is Dictionary else {}
	if String(generated.get("status", "")) == "full_parity_supported" or String(generated.get("full_generation_status", "")) != "not_implemented":
		_fail("Adjacent unsupported config falsely claimed full parity: %s" % JSON.stringify(generated))
		return {}
	if bool(provenance.get("full_parity_claim", false)) or String(provenance.get("adoption_status", "")) == "feature_gated_authoritative_package_ready":
		_fail("Adjacent unsupported config falsely claimed adoption/full-parity readiness: %s" % JSON.stringify(provenance))
		return {}
	return {
		"case_id": "translated_land_level_1_adjacent_unsupported",
		"status": generated.get("status", ""),
		"full_generation_status": generated.get("full_generation_status", ""),
		"full_parity_claim": provenance.get("full_parity_claim", false),
		"adoption_status": provenance.get("adoption_status", ""),
	}

func _assert_case_full_parity(case_report: Dictionary) -> void:
	if not case_report.get("known_gaps", []).is_empty():
		_fail("Case %s still has gaps: %s" % [String(case_report.get("case_id", "")), JSON.stringify(case_report.get("known_gaps", []))])
		return
	var native: Dictionary = case_report.get("native", {}) if case_report.get("native", {}) is Dictionary else {}
	var adoption: Dictionary = case_report.get("package_session_adoption", {}) if case_report.get("package_session_adoption", {}) is Dictionary else {}
	if String(native.get("status", "")) != "full_parity_supported" or String(native.get("full_generation_status", "")) == "not_implemented":
		_fail("Case %s native status did not prove full parity: %s" % [String(case_report.get("case_id", "")), JSON.stringify(native)])
		return
	if not bool(native.get("provenance", {}).get("full_parity_claim", false)):
		_fail("Case %s native provenance did not claim supported full parity." % String(case_report.get("case_id", "")))
		return
	if not bool(adoption.get("ready", false)) or not bool(adoption.get("native_runtime_authoritative", false)) or not bool(adoption.get("full_parity_claim", false)):
		_fail("Case %s package/session adoption was not full-parity ready: %s" % [String(case_report.get("case_id", "")), JSON.stringify(adoption)])
		return
	if bool(adoption.get("runtime_call_site_adoption", true)) or bool(adoption.get("authored_content_writeback", true)) or bool(adoption.get("save_version_bump", true)):
		_fail("Case %s crossed runtime/writeback/save-version boundaries: %s" % [String(case_report.get("case_id", "")), JSON.stringify(adoption)])
		return

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
