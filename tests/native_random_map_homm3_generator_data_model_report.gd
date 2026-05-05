extends Node

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")

const REPORT_ID := "NATIVE_RANDOM_MAP_HOMM3_GENERATOR_DATA_MODEL_REPORT"
const REPORT_SCHEMA_ID := "native_random_map_homm3_generator_data_model_report_v1"

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
	if not capabilities.has("native_rmg_homm3_generator_data_model_report"):
		_fail("Native service is missing the data-model report capability: %s" % JSON.stringify(Array(capabilities)))
		return
	if not service.has_method("inspect_random_map_generator_data_model"):
		_fail("Native service is missing inspect_random_map_generator_data_model.")
		return

	var model_report: Dictionary = service.inspect_random_map_generator_data_model()
	if not bool(model_report.get("ok", false)) or String(model_report.get("validation_status", "")) != "pass":
		_fail("Generator data model did not validate: %s" % JSON.stringify(model_report))
		return

	var model_metrics: Dictionary = model_report.get("metrics", {}).get("data_model", {}) if model_report.get("metrics", {}) is Dictionary else {}
	var template_metrics: Dictionary = model_report.get("metrics", {}).get("template_catalog", {}) if model_report.get("metrics", {}) is Dictionary else {}
	var kind_counts: Dictionary = model_metrics.get("object_definition_kind_counts", {}) if model_metrics.get("object_definition_kind_counts", {}) is Dictionary else {}
	var definition_keys: Dictionary = model_metrics.get("definition_keys", {}) if model_metrics.get("definition_keys", {}) is Dictionary else {}
	for required_kind in ["resource_site", "mine", "neutral_dwelling", "reward_reference", "decorative_obstacle", "town", "guard", "special_guard_gate"]:
		if not kind_counts.has(required_kind):
			_fail("Data model missed required generated kind %s: %s" % [required_kind, JSON.stringify(kind_counts)])
			return
	if int(model_metrics.get("object_definition_count", 0)) < 10:
		_fail("Object definition coverage is too small: %s" % JSON.stringify(model_metrics))
		return
	if int(template_metrics.get("template_count", 0)) < 50 or int(template_metrics.get("template_zone_count", 0)) < 600 or int(template_metrics.get("template_link_count", 0)) < 800:
		_fail("Template catalog metrics no longer match the source-backed Phase 3 baseline: %s" % JSON.stringify(template_metrics))
		return
	if int(model_report.get("diagnostics", {}).get("unsupported_parity_boundary_count", 0)) <= 0:
		_fail("Unsupported parity boundaries must be explicit: %s" % JSON.stringify(model_report.get("diagnostics", {})))
		return

	var generated_summary := _run_generation_surface_check(service, definition_keys, kind_counts)
	if generated_summary.is_empty():
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"schema_id": REPORT_SCHEMA_ID,
		"ok": true,
		"binding_kind": metadata.get("binding_kind", ""),
		"native_extension_loaded": metadata.get("native_extension_loaded", false),
		"data_model_schema_id": model_report.get("data_model_schema_id", ""),
		"object_definition_count": int(model_metrics.get("object_definition_count", 0)),
		"object_definition_kind_counts": kind_counts,
		"template_catalog": template_metrics,
		"unsupported_parity_boundary_count": int(model_report.get("diagnostics", {}).get("unsupported_parity_boundary_count", 0)),
		"compatibility_gates": model_report.get("compatibility_gates", {}),
		"generation_surface": generated_summary,
		"remaining_gap": "This slice validates reusable generator data definitions and gates. Runtime zone graph, terrain shaping, full object placement, guard/reward algorithms, and binary parity remain deferred Phase 3 slices.",
	})])
	get_tree().quit(0)

func _run_generation_surface_check(service: Variant, definition_keys: Dictionary, kind_counts: Dictionary) -> Dictionary:
	var config := ScenarioSelectRulesScript.build_random_map_player_config(
		"native-rmg-data-model-fixture-a",
		"frontier_spokes_v1",
		"frontier_spokes_profile_v1",
		3,
		"land",
		false,
		"homm3_small"
	)
	var generated: Dictionary = service.generate_random_map(config)
	if not bool(generated.get("ok", false)):
		_fail("Native generation failed while checking data-model compatibility: %s" % JSON.stringify(generated))
		return {}
	if String(generated.get("validation_status", "")) != "pass":
		_fail("Native generation validation failed while checking data-model compatibility: %s" % JSON.stringify(generated.get("validation_report", {})))
		return {}

	var exact_resolved_count := 0
	var kind_resolved_count := 0
	var unresolved := []
	for object_record in generated.get("object_placements", []):
		if not (object_record is Dictionary):
			continue
		var kind := String(object_record.get("kind", ""))
		var object_id := String(object_record.get("object_id", ""))
		if kind == "" or object_id == "":
			unresolved.append({"reason": "missing_kind_or_object_id", "record": object_record})
			continue
		var exact_key := "%s:%s" % [kind, object_id]
		if definition_keys.has(exact_key):
			exact_resolved_count += 1
			continue
		if kind == "decorative_obstacle" and kind_counts.has(kind):
			kind_resolved_count += 1
			continue
		unresolved.append({"reason": "no_definition_key", "kind": kind, "object_id": object_id})
	if not unresolved.is_empty():
		_fail("Generated object records did not resolve through the data model: %s" % JSON.stringify(unresolved.slice(0, min(8, unresolved.size()))))
		return {}

	var town_count := int(generated.get("town_records", []).size())
	var guard_count := int(generated.get("guard_records", []).size())
	if town_count <= 0 or guard_count <= 0 or not kind_counts.has("town") or not kind_counts.has("guard"):
		_fail("Town/guard generated surfaces are not covered by data-model kind definitions: towns=%d guards=%d kinds=%s" % [town_count, guard_count, JSON.stringify(kind_counts)])
		return {}
	var adoption: Dictionary = service.convert_generated_payload(generated, {
		"feature_gate": "native_rmg_homm3_generator_data_model_report",
		"session_save_version": 9,
		"scenario_id": "native_rmg_data_model_fixture_a",
	})
	if not bool(adoption.get("ok", false)):
		_fail("convert_generated_payload compatibility gate failed: %s" % JSON.stringify(adoption))
		return {}

	return {
		"template_id": "frontier_spokes_v1",
		"object_count": int(generated.get("object_placements", []).size()),
		"exact_resolved_object_count": exact_resolved_count,
		"kind_resolved_decoration_count": kind_resolved_count,
		"town_count": town_count,
		"guard_count": guard_count,
		"adoption_ok": bool(adoption.get("ok", false)),
	}

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
