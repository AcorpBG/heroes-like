extends Node

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const SessionStateStoreScript = preload("res://scripts/core/SessionStateStore.gd")

const REPORT_ID := "NATIVE_RANDOM_MAP_PACKAGE_SESSION_AUTHORITATIVE_REPLAY_REPORT"
const REPORT_SCHEMA_ID := "native_random_map_package_session_authoritative_replay_report_v1"
const FEATURE_GATE := "native_rmg_package_session_authoritative_replay_gate"
const EXPECTED_STATUS := "owner_compared_translated_profile_supported"
const EXPECTED_FULL_STATUS := "owner_compared_translated_profile_not_full_parity"

const CASES := [
	{"id": "default_small_049", "size_class_id": "homm3_small"},
	{"id": "default_medium_002", "size_class_id": "homm3_medium"},
	{
		"id": "player_facing_medium_islands_001",
		"size_class_id": "homm3_medium",
		"water_mode": "islands",
		"player_count": 4,
		"template_id": "translated_rmg_template_001_v1",
		"profile_id": "translated_rmg_profile_001_v1",
	},
	{"id": "default_large_042", "size_class_id": "homm3_large"},
	{"id": "default_extra_large_043", "size_class_id": "homm3_extra_large"},
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

	var requested_case_id := OS.get_environment("NATIVE_RMG_REPLAY_CASE_ID")
	var summaries := []
	for case_record in CASES:
		if requested_case_id != "" and String(case_record.get("id", "")) != requested_case_id:
			continue
		var summary := _run_case(service, case_record)
		if summary.is_empty():
			return
		summaries.append(summary)
	if summaries.is_empty():
		_fail("No replay case matched NATIVE_RMG_REPLAY_CASE_ID=%s" % requested_case_id)
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"schema_id": REPORT_SCHEMA_ID,
		"ok": true,
		"binding_kind": metadata.get("binding_kind", ""),
		"native_extension_loaded": metadata.get("native_extension_loaded", false),
		"requested_case_id": requested_case_id,
		"case_count": summaries.size(),
		"cases": summaries,
		"readiness": {
			"replay_identity_stable": true,
			"native_runtime_authoritative": true,
			"runtime_call_site_adoption": true,
			"remaining_authority_gap": "full_homm3_parity_still_pending",
		},
	})])
	get_tree().quit(0)

func _run_case(service: Variant, case_record: Dictionary) -> Dictionary:
	var case_id := String(case_record.get("id", "case"))
	var size_class_id := String(case_record.get("size_class_id", "homm3_small"))
	var water_mode := String(case_record.get("water_mode", "land"))
	var defaults := ScenarioSelectRulesScript.random_map_size_class_default(size_class_id)
	var expected_defaults := defaults.duplicate(true)
	if case_record.has("template_id"):
		expected_defaults["template_id"] = String(case_record.get("template_id", ""))
	if case_record.has("profile_id"):
		expected_defaults["profile_id"] = String(case_record.get("profile_id", ""))
	var player_count := int(case_record.get("player_count", defaults.get("player_count", 3)))
	var base_config := ScenarioSelectRulesScript.build_random_map_player_config(
		"package-session-authoritative-replay-%s-%s-10184" % [size_class_id, water_mode],
		"",
		"",
		player_count,
		water_mode,
		false,
		size_class_id,
		ScenarioSelectRulesScript.RANDOM_MAP_TEMPLATE_SELECTION_MODE_CATALOG_AUTO
	)
	var changed_config: Dictionary = base_config.duplicate(true)
	changed_config["seed"] = "%s-changed" % String(base_config.get("seed", ""))

	var first: Dictionary = service.generate_random_map(base_config, {"startup_path": "authoritative_replay_first_%s" % case_id})
	var repeat: Dictionary = service.generate_random_map(base_config.duplicate(true), {"startup_path": "authoritative_replay_repeat_%s" % case_id})
	var changed: Dictionary = service.generate_random_map(changed_config, {"startup_path": "authoritative_replay_changed_%s" % case_id})
	if not _assert_generation(case_id, first, expected_defaults):
		return {}
	if not _assert_generation(case_id, repeat, expected_defaults):
		return {}
	if not _assert_generation(case_id, changed, expected_defaults):
		return {}

	var first_signature := String(first.get("full_output_signature", ""))
	var repeat_signature := String(repeat.get("full_output_signature", ""))
	var changed_signature := String(changed.get("full_output_signature", ""))
	if first_signature == "" or first_signature != repeat_signature:
		_fail("%s same seed/config did not preserve full output signature: %s vs %s" % [case_id, first_signature, repeat_signature])
		return {}
	if first_signature == changed_signature:
		_fail("%s changed seed did not change full output signature: %s" % [case_id, first_signature])
		return {}
	if not _assert_replay_identity_isolated(case_id, first):
		return {}

	var options := {
		"feature_gate": FEATURE_GATE,
		"session_save_version": SessionStateStoreScript.SAVE_VERSION,
		"scenario_id": "native_rmg_replay_%s" % case_id,
	}
	var first_adoption: Dictionary = service.convert_generated_payload(first, options)
	var repeat_adoption: Dictionary = service.convert_generated_payload(repeat, options.duplicate(true))
	var changed_adoption: Dictionary = service.convert_generated_payload(changed, options.duplicate(true))
	if not _assert_adoption(case_id, first_adoption):
		return {}
	if not _assert_adoption(case_id, repeat_adoption):
		return {}
	if not _assert_adoption(case_id, changed_adoption):
		return {}

	var first_replay := _adoption_replay_summary(first_adoption)
	var repeat_replay := _adoption_replay_summary(repeat_adoption)
	var changed_replay := _adoption_replay_summary(changed_adoption)
	if first_replay != repeat_replay:
		_fail("%s same seed/config did not preserve adoption replay summary: first=%s repeat=%s" % [case_id, JSON.stringify(first_replay), JSON.stringify(repeat_replay)])
		return {}
	if String(first_replay.get("map_hash", "")) == String(changed_replay.get("map_hash", "")):
		_fail("%s changed seed did not change adopted map hash: %s" % [case_id, JSON.stringify(changed_replay)])
		return {}

	var disk_replay := _assert_disk_replay(service, case_id, first_adoption, repeat_adoption)
	if disk_replay.is_empty():
		return {}

	return {
		"id": case_id,
		"size_class_id": size_class_id,
		"template_id": String(first.get("normalized_config", {}).get("template_id", "")),
		"profile_id": String(first.get("normalized_config", {}).get("profile_id", "")),
		"full_output_signature": first_signature,
		"changed_full_output_signature": changed_signature,
		"adoption_replay": first_replay,
		"changed_map_hash": changed_replay.get("map_hash", ""),
		"disk_replay": disk_replay,
		"native_runtime_authoritative": true,
		"runtime_call_site_adoption": true,
	}

func _assert_generation(case_id: String, generated: Dictionary, defaults: Dictionary) -> bool:
	if not bool(generated.get("ok", false)) or String(generated.get("validation_status", "")) != "pass":
		_fail("%s native generation failed: %s" % [case_id, JSON.stringify(generated.get("validation_report", generated))])
		return false
	if String(generated.get("status", "")) != EXPECTED_STATUS or String(generated.get("full_generation_status", "")) != EXPECTED_FULL_STATUS:
		_fail("%s native generation status drifted: %s" % [case_id, JSON.stringify(_generation_summary(generated))])
		return false
	if bool(generated.get("full_parity_claim", false)) or bool(generated.get("native_runtime_authoritative", false)):
		_fail("%s native generation falsely claimed authority/parity: %s" % [case_id, JSON.stringify(_generation_summary(generated))])
		return false
	var normalized: Dictionary = generated.get("normalized_config", {}) if generated.get("normalized_config", {}) is Dictionary else {}
	if String(normalized.get("template_id", "")) != String(defaults.get("template_id", "")) or String(normalized.get("profile_id", "")) != String(defaults.get("profile_id", "")):
		_fail("%s did not use the default translated template/profile: %s defaults=%s" % [case_id, JSON.stringify(normalized), JSON.stringify(defaults)])
		return false
	return true

func _assert_replay_identity_isolated(case_id: String, generated: Dictionary) -> bool:
	var output_identity: Dictionary = generated.get("generated_output_identity", {}) if generated.get("generated_output_identity", {}) is Dictionary else {}
	if output_identity.is_empty():
		_fail("%s generated output identity is missing." % case_id)
		return false
	for key in ["extension_profile", "runtime_phase_profile", "elapsed_usec", "elapsed_msec", "microseconds_per_tile"]:
		if _contains_key_recursive(output_identity, key):
			_fail("%s replay output identity contains nondeterministic diagnostic key %s: %s" % [case_id, key, JSON.stringify(output_identity)])
			return false
	return true

func _assert_adoption(case_id: String, adoption: Dictionary) -> bool:
	if not bool(adoption.get("ok", false)) or String(adoption.get("status", "")) != "pass":
		_fail("%s adoption failed: %s" % [case_id, JSON.stringify(adoption)])
		return false
	var report: Dictionary = adoption.get("report", {}) if adoption.get("report", {}) is Dictionary else {}
	if not bool(report.get("package_session_adoption_ready", false)) or String(report.get("adoption_status", "")) != "runtime_authoritative_owner_compared_not_full_parity":
		_fail("%s adoption readiness/status drifted: %s" % [case_id, JSON.stringify(report)])
		return false
	if not bool(report.get("native_runtime_authoritative", false)) or not bool(report.get("runtime_call_site_adoption", false)) or bool(report.get("full_parity_claim", true)):
		_fail("%s adoption must be runtime-authoritative without full parity: %s" % [case_id, JSON.stringify(report)])
		return false
	return true

func _assert_disk_replay(service: Variant, case_id: String, first_adoption: Dictionary, repeat_adoption: Dictionary) -> Dictionary:
	var map_path := "user://native_rmg_authoritative_replay_%s.amap" % case_id
	var scenario_path := "user://native_rmg_authoritative_replay_%s.ascenario" % case_id
	var first_map := _save_load_map(service, case_id, first_adoption, map_path)
	var first_scenario := _save_load_scenario(service, case_id, first_adoption, scenario_path)
	var repeat_map := _save_load_map(service, case_id, repeat_adoption, map_path)
	var repeat_scenario := _save_load_scenario(service, case_id, repeat_adoption, scenario_path)
	DirAccess.remove_absolute(map_path)
	DirAccess.remove_absolute(scenario_path)
	if first_map.is_empty() or first_scenario.is_empty() or repeat_map.is_empty() or repeat_scenario.is_empty():
		return {}
	if first_map != repeat_map:
		_fail("%s same seed/config did not preserve disk map package replay: first=%s repeat=%s" % [case_id, JSON.stringify(first_map), JSON.stringify(repeat_map)])
		return {}
	if first_scenario != repeat_scenario:
		_fail("%s same seed/config did not preserve disk scenario package replay: first=%s repeat=%s" % [case_id, JSON.stringify(first_scenario), JSON.stringify(repeat_scenario)])
		return {}
	return {
		"map": first_map,
		"scenario": first_scenario,
	}

func _save_load_map(service: Variant, case_id: String, adoption: Dictionary, path: String) -> Dictionary:
	var map_document: Variant = adoption.get("map_document", null)
	var save_result: Dictionary = service.save_map_package(map_document, path)
	if not bool(save_result.get("ok", false)):
		_fail("%s save_map_package failed: %s" % [case_id, JSON.stringify(save_result)])
		return {}
	var load_result: Dictionary = service.load_map_package(path)
	if not bool(load_result.get("ok", false)):
		_fail("%s load_map_package failed: %s" % [case_id, JSON.stringify(load_result)])
		return {}
	var loaded_document: Variant = load_result.get("map_document", null)
	if loaded_document == null:
		_fail("%s load_map_package missed map_document." % case_id)
		return {}
	return {
		"save_package_hash": String(save_result.get("package_hash", "")),
		"load_package_hash": String(load_result.get("package_hash", "")),
		"map_hash": String(loaded_document.get_map_hash()),
		"object_count": int(loaded_document.get_object_count()),
	}

func _save_load_scenario(service: Variant, case_id: String, adoption: Dictionary, path: String) -> Dictionary:
	var scenario_document: Variant = adoption.get("scenario_document", null)
	var save_result: Dictionary = service.save_scenario_package(scenario_document, path)
	if not bool(save_result.get("ok", false)):
		_fail("%s save_scenario_package failed: %s" % [case_id, JSON.stringify(save_result)])
		return {}
	var load_result: Dictionary = service.load_scenario_package(path)
	if not bool(load_result.get("ok", false)):
		_fail("%s load_scenario_package failed: %s" % [case_id, JSON.stringify(load_result)])
		return {}
	var loaded_document: Variant = load_result.get("scenario_document", null)
	if loaded_document == null:
		_fail("%s load_scenario_package missed scenario_document." % case_id)
		return {}
	return {
		"save_package_hash": String(save_result.get("package_hash", "")),
		"load_package_hash": String(load_result.get("package_hash", "")),
		"scenario_hash": String(loaded_document.get_scenario_hash()),
		"player_slot_count": int(loaded_document.get_player_slots().size()),
	}

func _adoption_replay_summary(adoption: Dictionary) -> Dictionary:
	return {
		"map_hash": String(adoption.get("map_ref", {}).get("map_hash", "")),
		"map_package_hash": String(adoption.get("map_package_record", {}).get("package_hash", "")),
		"scenario_hash": String(adoption.get("scenario_ref", {}).get("scenario_hash", "")),
		"scenario_package_hash": String(adoption.get("scenario_package_record", {}).get("package_hash", "")),
		"session_id": String(adoption.get("session_boundary_record", {}).get("session_id", "")),
	}

func _generation_summary(generated: Dictionary) -> Dictionary:
	var normalized: Dictionary = generated.get("normalized_config", {}) if generated.get("normalized_config", {}) is Dictionary else {}
	return {
		"status": String(generated.get("status", "")),
		"full_generation_status": String(generated.get("full_generation_status", "")),
		"template_id": String(normalized.get("template_id", "")),
		"profile_id": String(normalized.get("profile_id", "")),
		"full_parity_claim": bool(generated.get("full_parity_claim", false)),
		"native_runtime_authoritative": bool(generated.get("native_runtime_authoritative", false)),
	}

func _contains_key_recursive(value: Variant, key: String) -> bool:
	if value is Dictionary:
		for item_key in value.keys():
			if String(item_key) == key:
				return true
			if _contains_key_recursive(value.get(item_key), key):
				return true
	elif value is Array:
		for item in value:
			if _contains_key_recursive(item, key):
				return true
	return false

func _package_diff(first: Variant, repeat: Variant, path: String = "") -> Array:
	var result := []
	if typeof(first) != typeof(repeat):
		result.append({"path": path, "first_type": type_string(typeof(first)), "repeat_type": type_string(typeof(repeat))})
		return result
	if first is Dictionary:
		var keys := {}
		for key in first.keys():
			keys[String(key)] = key
		for key in repeat.keys():
			keys[String(key)] = key
		for key_name in keys.keys():
			var key: Variant = keys[key_name]
			var child_path: String = "%s.%s" % [path, key_name] if path != "" else String(key_name)
			var child_diff := _package_diff(first.get(key), repeat.get(key), child_path)
			for item in child_diff:
				result.append(item)
				if result.size() >= 8:
					return result
	elif first is Array:
		if first.size() != repeat.size():
			result.append({"path": path, "first_size": first.size(), "repeat_size": repeat.size()})
			return result
		for index in range(first.size()):
			var child_diff := _package_diff(first[index], repeat[index], "%s[%d]" % [path, index])
			for item in child_diff:
				result.append(item)
				if result.size() >= 8:
					return result
	elif first != repeat:
		result.append({"path": path, "first": _diff_value_summary(first), "repeat": _diff_value_summary(repeat)})
	return result

func _diff_value_summary(value: Variant) -> Variant:
	if value is Dictionary:
		return {"type": "Dictionary", "size": value.size(), "keys": value.keys().slice(0, min(8, value.size()))}
	if value is Array:
		return {"type": "Array", "size": value.size()}
	var text := str(value)
	if text.length() > 160:
		return text.substr(0, 160) + "..."
	return value

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "error": message})])
	get_tree().quit(1)
