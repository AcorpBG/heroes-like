extends Node

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")

const REPORT_ID := "NATIVE_RANDOM_MAP_HOMM3_OBJECT_PLACEMENT_PIPELINE_REPORT"
const REPORT_SCHEMA_ID := "native_random_map_homm3_object_placement_pipeline_report_v1"

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
	if not capabilities.has("native_random_map_homm3_object_placement_pipeline"):
		_fail("Native HoMM3 object placement pipeline capability is missing: %s" % JSON.stringify(Array(capabilities)))
		return

	var medium_config := ScenarioSelectRulesScript.build_random_map_player_config(
		"native-object-pipeline-medium-10184",
		"translated_rmg_template_005_v1",
		"translated_rmg_profile_005_v1",
		4,
		"land",
		false,
		"homm3_medium"
	)
	var xl_config := ScenarioSelectRulesScript.build_random_map_player_config(
		"native-object-pipeline-xl-10184",
		"translated_rmg_template_043_v1",
		"translated_rmg_profile_043_v1",
		8,
		"land",
		false,
		"homm3_extra_large"
	)
	var medium: Dictionary = service.generate_random_map(medium_config, {"startup_path": "homm3_object_pipeline_report_medium"})
	var xl: Dictionary = service.generate_random_map(xl_config, {"startup_path": "homm3_object_pipeline_report_xl"})
	var medium_summary := _assert_pipeline_case("medium", medium, false)
	if medium_summary.is_empty():
		return
	var xl_summary := _assert_pipeline_case("xl", xl, true)
	if xl_summary.is_empty():
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"schema_id": REPORT_SCHEMA_ID,
		"ok": true,
		"binding_kind": metadata.get("binding_kind", ""),
		"native_extension_loaded": metadata.get("native_extension_loaded", false),
		"medium": medium_summary,
		"xl": xl_summary,
		"remaining_gap": "This validates recovered object-placement structure translated to original content. It does not claim exact HoMM3 object table, DEF art, byte, or binary map parity.",
	})])
	get_tree().quit(0)

func _assert_pipeline_case(case_id: String, generated: Dictionary, expect_xl: bool) -> Dictionary:
	if not bool(generated.get("ok", false)) or String(generated.get("validation_status", "")) != "pass":
		_fail("%s generation failed validation: %s" % [case_id, JSON.stringify(generated.get("validation_report", generated))])
		return {}
	var payload: Dictionary = generated.get("object_placement", {}) if generated.get("object_placement", {}) is Dictionary else {}
	var summary: Dictionary = generated.get("object_placement_pipeline_summary", {}) if generated.get("object_placement_pipeline_summary", {}) is Dictionary else {}
	if String(summary.get("schema_id", "")) != "aurelion_native_rmg_homm3_object_placement_pipeline_summary_v1":
		_fail("%s missed pipeline summary: %s" % [case_id, JSON.stringify(summary)])
		return {}
	if String(summary.get("validation_status", "")) != "pass":
		_fail("%s pipeline summary did not pass: %s" % [case_id, JSON.stringify(summary)])
		return {}
	if int(summary.get("supported_definition_count", 0)) < 5:
		_fail("%s did not expose enough original object definitions." % case_id)
		return {}
	if String(summary.get("decorative_filler_semantics", "")) != "ordinary_object_template_rand_trn_proxy_not_decoration_super_type":
		_fail("%s decoration filler used the wrong semantic model." % case_id)
		return {}
	if int(summary.get("decorative_filler_count", 0)) <= 0 or float(summary.get("decorative_filler_ordinary_template_ratio", 0.0)) < 1.0:
		_fail("%s decoration filler did not prove ordinary-template placement: %s" % [case_id, JSON.stringify(summary)])
		return {}
	if int(summary.get("missing_definition_count", -1)) != 0 or int(summary.get("missing_mask_count", -1)) != 0 or int(summary.get("missing_writeout_count", -1)) != 0:
		_fail("%s placements missed definition/mask/writeout metadata: %s" % [case_id, JSON.stringify(summary)])
		return {}
	if int(summary.get("body_overlap_count", -1)) != 0:
		_fail("%s body occupancy overlapped: %s" % [case_id, JSON.stringify(summary)])
		return {}
	if int(summary.get("limit_failure_count", -1)) != 0:
		_fail("%s per-zone/global object limits failed: %s" % [case_id, JSON.stringify(summary)])
		return {}
	var xl_cost: Dictionary = summary.get("xl_cost", {}) if summary.get("xl_cost", {}) is Dictionary else {}
	if expect_xl and not bool(xl_cost.get("bounded_large_map_sampling", false)):
		_fail("%s did not report bounded large-map object-placement sampling: %s" % [case_id, JSON.stringify(xl_cost)])
		return {}
	if String(xl_cost.get("status", "")) != "pass":
		_fail("%s object placement cost exceeded budget: %s" % [case_id, JSON.stringify(xl_cost)])
		return {}
	var occupancy: Dictionary = payload.get("occupancy_index", {}) if payload.get("occupancy_index", {}) is Dictionary else {}
	if String(occupancy.get("status", "")) != "pass" or int(occupancy.get("duplicate_body_tile_count", -1)) != 0:
		_fail("%s object occupancy did not prove unique body tiles: %s" % [case_id, JSON.stringify(occupancy)])
		return {}
	if not _assert_placements_have_pipeline_fields(case_id, payload.get("object_placements", [])):
		return {}
	return {
		"status": String(generated.get("status", "")),
		"template_id": String(generated.get("normalized_config", {}).get("template_id", "")),
		"width": int(generated.get("normalized_config", {}).get("width", 0)),
		"height": int(generated.get("normalized_config", {}).get("height", 0)),
		"object_count": int(payload.get("object_count", 0)),
		"definition_count": int(summary.get("supported_definition_count", 0)),
		"global_counts": summary.get("global_counts", {}),
		"decorative_filler_count": int(summary.get("decorative_filler_count", 0)),
		"body_tile_reference_count": int(summary.get("body_tile_reference_count", 0)),
		"elapsed_msec": float(xl_cost.get("elapsed_msec", 0.0)),
		"microseconds_per_tile": float(xl_cost.get("microseconds_per_tile", 0.0)),
	}

func _assert_placements_have_pipeline_fields(case_id: String, placements: Array) -> bool:
	var seen_kinds := {}
	for placement in placements:
		if not (placement is Dictionary):
			_fail("%s found non-dictionary placement." % case_id)
			return false
		var kind := String(placement.get("kind", ""))
		seen_kinds[kind] = true
		if String(placement.get("object_definition_id", "")) == "":
			_fail("%s placement missed object definition: %s" % [case_id, JSON.stringify(placement)])
			return false
		for field in ["footprint", "passability", "action", "terrain_constraints", "object_type_metadata", "value_density", "writeout_metadata"]:
			if not (placement.get(field, {}) is Dictionary) or placement.get(field, {}).is_empty():
				_fail("%s placement missed %s: %s" % [case_id, field, JSON.stringify(placement)])
				return false
		if kind == "decorative_obstacle":
			if not bool(placement.get("ordinary_object_template_filler", false)) or bool(placement.get("decoration_super_type_shortcut", true)):
				_fail("%s decoration placement used shortcut semantics: %s" % [case_id, JSON.stringify(placement)])
				return false
		if int(placement.get("footprint", {}).get("width", 0)) <= 0 or int(placement.get("footprint", {}).get("height", 0)) <= 0:
			_fail("%s placement has invalid footprint: %s" % [case_id, JSON.stringify(placement)])
			return false
	if not seen_kinds.has("mine") or not seen_kinds.has("reward_reference") or not seen_kinds.has("decorative_obstacle"):
		_fail("%s did not include expected object categories: %s" % [case_id, JSON.stringify(seen_kinds.keys())])
		return false
	return true

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
