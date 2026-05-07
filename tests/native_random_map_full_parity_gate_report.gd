extends Node

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")

const REPORT_ID := "NATIVE_RANDOM_MAP_FULL_PARITY_GATE_REPORT"
const REPORT_SCHEMA_ID := "native_random_map_full_parity_claim_boundary_report_v3"

const OWNER_COMPARED_REMAINING_PARITY_SLICES := [
	"native-rmg-full-homm3-parity-gate-10184",
	"native-rmg-islands-owner-compared-runtime-support-10184",
	"native-rmg-broad-template-owner-comparison-gate-10184",
]

const CASES := [
	{
		"id": "legacy_compact_scoped_structural",
		"seed": "native-rmg-full-parity-claim-boundary-10184-compact",
		"template_id": "border_gate_compact_v1",
		"profile_id": "border_gate_compact_profile_v1",
		"player_count": 3,
		"water_mode": "land",
		"underground": false,
		"size_class_id": "homm3_small",
		"expected_status": "scoped_structural_profile_supported",
		"expected_full_generation_status": "scoped_structural_profile_not_full_parity",
		"expected_scoped_support": true,
		"expected_owner_compared_support": false,
		"expected_runtime_authoritative": false,
		"expected_runtime_call_site_adoption": false,
		"expected_package_adoption_status": "ready_feature_gated_not_authoritative",
	},
	{
		"id": "translated_small_049_default",
		"seed": "native-rmg-full-parity-claim-boundary-10184-small",
		"template_id": "",
		"profile_id": "",
		"player_count": 3,
		"water_mode": "land",
		"underground": false,
		"size_class_id": "homm3_small",
		"expected_status": "owner_compared_translated_profile_supported",
		"expected_full_generation_status": "owner_compared_translated_profile_not_full_parity",
		"expected_scoped_support": false,
		"expected_owner_compared_support": true,
		"expected_runtime_authoritative": true,
		"expected_runtime_call_site_adoption": true,
		"expected_package_adoption_status": "runtime_authoritative_owner_compared_not_full_parity",
	},
	{
		"id": "translated_medium_002_default",
		"seed": "native-rmg-full-parity-claim-boundary-10184-medium",
		"template_id": "",
		"profile_id": "",
		"player_count": 4,
		"water_mode": "land",
		"underground": false,
		"size_class_id": "homm3_medium",
		"expected_status": "owner_compared_translated_profile_supported",
		"expected_full_generation_status": "owner_compared_translated_profile_not_full_parity",
		"expected_scoped_support": false,
		"expected_owner_compared_support": true,
		"expected_runtime_authoritative": true,
		"expected_runtime_call_site_adoption": true,
		"expected_package_adoption_status": "runtime_authoritative_owner_compared_not_full_parity",
	},
	{
		"id": "translated_medium_001_islands_owner_compared",
		"seed": "1777897383",
		"template_id": "translated_rmg_template_001_v1",
		"profile_id": "translated_rmg_profile_001_v1",
		"player_count": 4,
		"water_mode": "islands",
		"underground": false,
		"size_class_id": "homm3_medium",
		"expected_status": "owner_compared_translated_profile_supported",
		"expected_full_generation_status": "owner_compared_translated_profile_not_full_parity",
		"expected_scoped_support": false,
		"expected_owner_compared_support": true,
		"expected_runtime_authoritative": true,
		"expected_runtime_call_site_adoption": true,
		"expected_package_adoption_status": "runtime_authoritative_owner_compared_not_full_parity",
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
	var capabilities: PackedStringArray = service.get_capabilities()
	if not capabilities.has("native_random_map_scoped_structural_profile_support"):
		_fail("Native scoped structural profile capability is missing: %s" % JSON.stringify(Array(capabilities)))
		return
	if capabilities.has("native_random_map_full_parity_supported_profiles"):
		_fail("Native capabilities still expose a misleading full-parity profile claim: %s" % JSON.stringify(Array(capabilities)))
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
		"case_count": summaries.size(),
		"cases": summaries,
		"readiness": {
			"owner_compared_runtime_authoritative_without_full_parity": true,
			"full_parity_claim": false,
			"runtime_call_site_adoption_limited_to_owner_compared_defaults": true,
			"scoped_structural_profiles_preserved": true,
			"production_parity_remaining": true,
		},
	})])
	get_tree().quit(0)

func _run_case(service: Variant, case_record: Dictionary) -> Dictionary:
	var config := ScenarioSelectRulesScript.build_random_map_player_config(
		String(case_record.get("seed", "")),
		String(case_record.get("template_id", "")),
		String(case_record.get("profile_id", "")),
		int(case_record.get("player_count", 3)),
		String(case_record.get("water_mode", "land")),
		bool(case_record.get("underground", false)),
		String(case_record.get("size_class_id", "homm3_small"))
	)
	var generated: Dictionary = service.generate_random_map(config, {"startup_path": "full_parity_claim_boundary_%s" % String(case_record.get("id", "case"))})
	if not bool(generated.get("ok", false)) or String(generated.get("validation_status", "")) != "pass":
		_fail("%s native generation failed: %s" % [String(case_record.get("id", "case")), JSON.stringify(generated.get("validation_report", generated))])
		return {}
	if String(generated.get("status", "")) != String(case_record.get("expected_status", "")):
		_fail("%s status drifted: %s" % [String(case_record.get("id", "case")), JSON.stringify(_claim_summary(generated))])
		return {}
	if String(generated.get("full_generation_status", "")) != String(case_record.get("expected_full_generation_status", "")):
		_fail("%s full generation status drifted: %s" % [String(case_record.get("id", "case")), JSON.stringify(_claim_summary(generated))])
		return {}
	if bool(generated.get("supported_parity_config", false)) != bool(case_record.get("expected_scoped_support", false)):
		_fail("%s scoped support flag drifted: %s" % [String(case_record.get("id", "case")), JSON.stringify(_claim_summary(generated))])
		return {}
	if bool(generated.get("owner_compared_translated_profile_supported", false)) != bool(case_record.get("expected_owner_compared_support", false)):
		_fail("%s owner-compared support flag drifted: %s" % [String(case_record.get("id", "case")), JSON.stringify(_claim_summary(generated))])
		return {}
	if bool(generated.get("full_parity_claim", false)):
		_fail("%s falsely claimed full parity at generation time: %s" % [String(case_record.get("id", "case")), JSON.stringify(_claim_summary(generated))])
		return {}
	var provenance: Dictionary = generated.get("provenance", {}) if generated.get("provenance", {}) is Dictionary else {}
	var boundaries: Dictionary = provenance.get("boundaries", {}) if provenance.get("boundaries", {}) is Dictionary else {}
	if bool(provenance.get("full_parity_claim", false)):
		_fail("%s provenance falsely claimed full parity: %s" % [String(case_record.get("id", "case")), JSON.stringify(provenance)])
		return {}
	if bool(boundaries.get("full_parity_claim", false)):
		_fail("%s provenance boundaries crossed the full-parity claim limit: %s" % [String(case_record.get("id", "case")), JSON.stringify(boundaries)])
		return {}
	var adoption: Dictionary = service.convert_generated_payload(generated, {
		"feature_gate": "native_rmg_full_parity_claim_boundary_report",
		"session_save_version": 9,
	})
	if not bool(adoption.get("ok", false)):
		_fail("%s package conversion failed: %s" % [String(case_record.get("id", "case")), JSON.stringify(adoption)])
		return {}
	var report: Dictionary = adoption.get("report", {}) if adoption.get("report", {}) is Dictionary else {}
	if bool(report.get("full_parity_claim", true)):
		_fail("%s package adoption falsely claimed full parity: %s" % [String(case_record.get("id", "case")), JSON.stringify(report)])
		return {}
	if bool(report.get("native_runtime_authoritative", false)) != bool(case_record.get("expected_runtime_authoritative", false)):
		_fail("%s package adoption runtime-authority boundary drifted: %s" % [String(case_record.get("id", "case")), JSON.stringify(report)])
		return {}
	if bool(report.get("runtime_call_site_adoption", false)) != bool(case_record.get("expected_runtime_call_site_adoption", false)):
		_fail("%s package adoption call-site boundary drifted: %s" % [String(case_record.get("id", "case")), JSON.stringify(report)])
		return {}
	if String(report.get("adoption_status", "")) != String(case_record.get("expected_package_adoption_status", "")):
		_fail("%s package adoption status drifted: %s" % [String(case_record.get("id", "case")), JSON.stringify(report)])
		return {}
	if bool(case_record.get("expected_owner_compared_support", false)) and not _contains_all_remaining_parity_slices(report.get("remaining_parity_slices", [])):
		_fail("%s package adoption omitted owner-compared remaining parity slices: %s" % [String(case_record.get("id", "case")), JSON.stringify(report)])
		return {}
	var summary := _claim_summary(generated)
	summary["package_session_adoption_ready"] = report.get("package_session_adoption_ready", false)
	summary["package_adoption_status"] = report.get("adoption_status", "")
	summary["package_native_runtime_authoritative"] = report.get("native_runtime_authoritative", false)
	summary["package_runtime_call_site_adoption"] = report.get("runtime_call_site_adoption", false)
	summary["package_remaining_parity_slices"] = report.get("remaining_parity_slices", [])
	return summary

func _contains_all_remaining_parity_slices(value: Variant) -> bool:
	var slices: Array = value if value is Array else []
	for expected in OWNER_COMPARED_REMAINING_PARITY_SLICES:
		if not slices.has(expected):
			return false
	return true

func _claim_summary(generated: Dictionary) -> Dictionary:
	var normalized: Dictionary = generated.get("normalized_config", {}) if generated.get("normalized_config", {}) is Dictionary else {}
	var provenance: Dictionary = generated.get("provenance", {}) if generated.get("provenance", {}) is Dictionary else {}
	return {
		"status": generated.get("status", ""),
		"full_generation_status": generated.get("full_generation_status", ""),
		"template_id": normalized.get("template_id", ""),
		"profile_id": normalized.get("profile_id", ""),
		"supported_parity_config": generated.get("supported_parity_config", false),
		"scoped_structural_profile_supported": generated.get("scoped_structural_profile_supported", false),
		"owner_compared_translated_profile_supported": generated.get("owner_compared_translated_profile_supported", false),
		"full_parity_claim": generated.get("full_parity_claim", false),
		"native_runtime_authoritative": generated.get("native_runtime_authoritative", false),
		"provenance_full_parity_claim": provenance.get("full_parity_claim", false),
		"provenance_native_runtime_authoritative": provenance.get("native_runtime_authoritative", false),
		"remaining_parity_slices": generated.get("validation_report", {}).get("remaining_parity_slices", []),
	}

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "error": message})])
	get_tree().quit(1)
