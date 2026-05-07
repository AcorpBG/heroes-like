extends Node

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")

const REPORT_ID := "NATIVE_RANDOM_MAP_EXTENSION_PROFILE_REPORT"
const REPORT_SCHEMA_ID := "native_random_map_extension_profile_report_v1"

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
	if not capabilities.has("native_random_map_extension_profile"):
		_fail("Native extension profiling capability is missing: %s" % JSON.stringify(Array(capabilities)))
		return

	var medium_default := _run_case(service, "medium_default_002", ScenarioSelectRulesScript.build_random_map_player_config(
		"native-extension-profile-medium-default-10184",
		"translated_rmg_template_002_v1",
		"translated_rmg_profile_002_v1",
		4,
		"land",
		false,
		"homm3_medium"
	))
	if medium_default.is_empty():
		return
	var medium_validation_gate := _run_case(service, "medium_validation_gate_005", ScenarioSelectRulesScript.build_random_map_player_config(
		"native-extension-profile-medium-gate-10184",
		"translated_rmg_template_005_v1",
		"translated_rmg_profile_005_v1",
		4,
		"land",
		false,
		"homm3_medium"
	))
	if medium_validation_gate.is_empty():
		return
	var xl_islands := _run_case(service, "xl_islands_012", _xl_islands_config(), false)
	if xl_islands.is_empty():
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"schema_id": REPORT_SCHEMA_ID,
		"ok": true,
		"binding_kind": metadata.get("binding_kind", ""),
		"native_extension_loaded": metadata.get("native_extension_loaded", false),
		"cases": [medium_default, medium_validation_gate, xl_islands],
	})])
	get_tree().quit(0)

func _xl_islands_config() -> Dictionary:
	return {
		"seed": "native-extension-profile-xl-islands-10184",
		"template_id": "translated_rmg_template_012_v1",
		"profile_id": "translated_rmg_profile_001_v1",
		"size": {
			"width": 144,
			"height": 144,
			"requested_width": 144,
			"requested_height": 144,
			"source_width": 144,
			"source_height": 144,
			"size_class_id": "homm3_extra_large",
			"water_mode": "islands",
			"level_count": 1,
		},
		"profile": {
			"id": "translated_rmg_profile_001_v1",
			"template_id": "translated_rmg_template_012_v1",
			"faction_ids": ["faction_embercourt", "faction_mireclaw", "faction_sunvault", "faction_thornwake"],
		},
		"player_constraints": {
			"human_count": 1,
			"player_count": 2,
			"team_mode": "free_for_all",
		},
	}

func _run_case(service: Variant, case_id: String, config: Dictionary, require_validation_pass: bool = true) -> Dictionary:
	var started_msec := Time.get_ticks_msec()
	var generated: Dictionary = service.generate_random_map(config, {"startup_path": "native_extension_profile_%s" % case_id})
	var wall_msec := Time.get_ticks_msec() - started_msec
	if not bool(generated.get("ok", false)) or (require_validation_pass and String(generated.get("validation_status", "")) != "pass"):
		_fail("%s generation failed validation: %s" % [case_id, JSON.stringify(generated.get("validation_report", generated))])
		return {}
	var profile: Dictionary = generated.get("extension_profile", {}) if generated.get("extension_profile", {}) is Dictionary else {}
	if String(profile.get("schema_id", "")) != "aurelion_native_rmg_extension_profile_v1":
		_fail("%s missed native extension profile: %s" % [case_id, JSON.stringify(profile)])
		return {}
	var phases: Array = profile.get("phases", []) if profile.get("phases", []) is Array else []
	if phases.size() < 10:
		_fail("%s profile did not expose enough phases: %s" % [case_id, JSON.stringify(profile)])
		return {}
	if float(profile.get("total_elapsed_msec", 0.0)) <= 0.0 or String(profile.get("top_phase_id", "")) == "":
		_fail("%s profile missed total/top phase: %s" % [case_id, JSON.stringify(profile)])
		return {}
	var object_summary: Dictionary = generated.get("object_placement_pipeline_summary", {}) if generated.get("object_placement_pipeline_summary", {}) is Dictionary else {}
	var object_cost: Dictionary = object_summary.get("xl_cost", {}) if object_summary.get("xl_cost", {}) is Dictionary else {}
	var object_profile: Dictionary = object_summary.get("runtime_phase_profile", {}) if object_summary.get("runtime_phase_profile", {}) is Dictionary else {}
	var object_phases: Array = object_profile.get("phases", []) if object_profile.get("phases", []) is Array else []
	if object_phases.is_empty():
		_fail("%s object placement profile missed subphases: %s" % [case_id, JSON.stringify(object_summary)])
		return {}
	var town_guard_summary: Dictionary = generated.get("town_guard_placement", {}) if generated.get("town_guard_placement", {}) is Dictionary else {}
	var town_guard_profile: Dictionary = town_guard_summary.get("runtime_phase_profile", {}) if town_guard_summary.get("runtime_phase_profile", {}) is Dictionary else {}
	var town_guard_phases: Array = town_guard_profile.get("phases", []) if town_guard_profile.get("phases", []) is Array else []
	if town_guard_phases.is_empty():
		_fail("%s town/guard placement profile missed subphases: %s" % [case_id, JSON.stringify(town_guard_summary)])
		return {}
	return {
		"case_id": case_id,
		"template_id": String(generated.get("normalized_config", {}).get("template_id", "")),
		"profile_id": String(generated.get("normalized_config", {}).get("profile_id", "")),
		"width": int(generated.get("normalized_config", {}).get("width", 0)),
		"height": int(generated.get("normalized_config", {}).get("height", 0)),
		"validation_status": String(generated.get("validation_status", "")),
		"validation_required": require_validation_pass,
		"wall_msec": wall_msec,
		"extension_total_msec": float(profile.get("total_elapsed_msec", 0.0)),
		"microseconds_per_tile": float(profile.get("microseconds_per_tile", 0.0)),
		"top_phase_id": String(profile.get("top_phase_id", "")),
		"top_phase_elapsed_msec": float(profile.get("top_phase_elapsed_msec", 0.0)),
		"object_pipeline_elapsed_msec": float(object_cost.get("elapsed_msec", 0.0)),
		"object_top_phase_id": String(object_profile.get("top_phase_id", "")),
		"object_top_phase_elapsed_msec": float(object_profile.get("top_phase_elapsed_msec", 0.0)),
		"town_guard_top_phase_id": String(town_guard_profile.get("top_phase_id", "")),
		"town_guard_top_phase_elapsed_msec": float(town_guard_profile.get("top_phase_elapsed_msec", 0.0)),
		"phase_msec": _phase_summary(phases),
		"top_phases": _top_phases(phases, 5),
		"object_top_phases": _top_phases(object_phases, 5),
		"town_guard_top_phases": _top_phases(town_guard_phases, 5),
		"object_count": int(generated.get("component_counts", {}).get("object_count", 0)),
		"road_segment_count": int(generated.get("component_counts", {}).get("road_segment_count", 0)),
		"town_count": int(generated.get("component_counts", {}).get("town_count", 0)),
		"guard_count": int(generated.get("component_counts", {}).get("guard_count", 0)),
	}

func _phase_summary(phases: Array) -> Dictionary:
	var summary := {}
	for phase_value in phases:
		var phase: Dictionary = phase_value if phase_value is Dictionary else {}
		var phase_id := String(phase.get("phase_id", ""))
		if phase_id in ["zone_layout", "road_network", "object_placement", "town_guard_placement", "terrain_grid", "validation_provenance_configure", "result_assembly"]:
			summary[phase_id] = float(phase.get("elapsed_msec", 0.0))
	return summary

func _top_phases(phases: Array, count: int) -> Array:
	var remaining := phases.duplicate(true)
	var top := []
	for _index in range(count):
		var best_index := -1
		var best_elapsed := -1.0
		for phase_index in range(remaining.size()):
			var phase: Dictionary = remaining[phase_index] if remaining[phase_index] is Dictionary else {}
			var elapsed := float(phase.get("elapsed_msec", 0.0))
			if elapsed > best_elapsed:
				best_elapsed = elapsed
				best_index = phase_index
		if best_index < 0:
			break
		var best: Dictionary = remaining[best_index]
		top.append({
			"phase_id": String(best.get("phase_id", "")),
			"elapsed_msec": float(best.get("elapsed_msec", 0.0)),
			"percent_total": float(best.get("percent_total", 0.0)),
		})
		remaining.remove_at(best_index)
	return top

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
