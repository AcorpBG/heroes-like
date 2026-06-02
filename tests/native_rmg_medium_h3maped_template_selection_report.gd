extends Node

const REPORT_ID := "NATIVE_RMG_MEDIUM_H3MAPED_TEMPLATE_SELECTION_REPORT"
const SEED_COVERAGE_LIMIT := 4096

const EXPECTED_CASES := [
	{
		"case_id": "medium_2p_seed_28_controlled",
		"seed": "28",
		"players": 2,
		"accepted_indices": [1, 4, 11, 12, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 37, 38, 39, 44, 45, 46, 47, 48, 49],
		"selected_template_id": "h3maped_template_035",
		"selected_source_index": 35,
		"selected_source_name": "3SM3d",
		"preselection_rng_calls": 0,
	},
	{
		"case_id": "medium_3p_seed_11_controlled",
		"seed": "11",
		"players": 3,
		"accepted_indices": [1, 4, 12, 15, 16, 18, 20, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 37, 38, 39, 44, 45, 46, 47, 48, 49],
		"selected_template_id": "h3maped_template_037",
		"selected_source_index": 37,
		"selected_source_name": "4MM2h",
		"preselection_rng_calls": 5,
	},
	{
		"case_id": "medium_4p_seed_10_controlled",
		"seed": "10",
		"players": 4,
		"accepted_indices": [1, 12, 15, 16, 18, 20, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 37, 38, 39, 46, 47, 48, 49],
		"selected_template_id": "h3maped_template_015",
		"selected_source_index": 15,
		"selected_source_name": "2SM4d(2)",
		"preselection_rng_calls": 6,
	},
]

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not ClassDB.class_exists("MapPackageService"):
		_fail("MapPackageService native class is not available.")
		return
	var service: Variant = ClassDB.instantiate("MapPackageService")
	var report := {
		"report_id": REPORT_ID,
		"strict_scope": "strict_medium_72x72_one_level_land_only",
		"seed_coverage_limit": SEED_COVERAGE_LIMIT,
		"cases": [],
	}
	for expected in EXPECTED_CASES:
		var case_report := _validate_case(service, expected)
		if not bool(case_report.get("ok", false)):
			_fail("%s failed: %s" % [String(expected.get("case_id", "")), JSON.stringify(case_report)])
			return
		report["cases"].append(case_report)

	var explicit_report := _validate_explicit_translated_request(service)
	if not bool(explicit_report.get("ok", false)):
		_fail("explicit translated-template override failed: %s" % JSON.stringify(explicit_report))
		return
	report["explicit_translated_template_request"] = explicit_report

	var unsupported_report := _validate_unsupported_modes(service)
	if not bool(unsupported_report.get("ok", false)):
		_fail("unsupported Medium modes did not block cleanly: %s" % JSON.stringify(unsupported_report))
		return
	report["unsupported_medium_modes"] = unsupported_report

	print("%s: %s" % [REPORT_ID, JSON.stringify(report)])
	get_tree().quit(0)

func _validate_case(service: Variant, expected: Dictionary) -> Dictionary:
	var config := _medium_land_config(String(expected.get("seed", "")), int(expected.get("players", 0)))
	var identity: Dictionary = service.random_map_config_identity(config)
	var normalized: Dictionary = identity.get("normalized_config", {}) if identity.get("normalized_config", {}) is Dictionary else {}
	var selection: Dictionary = normalized.get("h3maped_template_selection", {}) if normalized.get("h3maped_template_selection", {}) is Dictionary else {}
	var accepted_indices := _int_array(selection.get("accepted_source_catalog_indices", []))
	var expected_indices := _int_array(expected.get("accepted_indices", []))
	var preselection_rng_calls := int(expected.get("preselection_rng_calls", 0))
	var coverage := _seed_coverage_for_vector_size(expected_indices.size(), preselection_rng_calls)
	var ok := bool(identity.get("ok", false)) \
			and bool(selection.get("ok", false)) \
			and String(normalized.get("template_selection_mode", "")) == "h3maped_exe_rng" \
			and String(normalized.get("template_selection_authority", "")) == "h3maped_exe_rng_original_catalog" \
			and String(normalized.get("template_id", "")) == String(expected.get("selected_template_id", "")) \
			and String(selection.get("source_template_id", "")) == String(expected.get("selected_template_id", "")) \
			and int(selection.get("source_catalog_index", -1)) == int(expected.get("selected_source_index", -1)) \
			and int(selection.get("template_preselection_rng_call_count", -1)) == preselection_rng_calls \
			and String(selection.get("selected_template", {}).get("source_name", "")) == String(expected.get("selected_source_name", "")) \
			and accepted_indices == expected_indices \
			and int(selection.get("accepted_template_count", -1)) == expected_indices.size() \
			and bool(coverage.get("all_vector_slots_reachable", false)) \
			and not bool(normalized.get("translated_template_authority_used", true)) \
			and not bool(normalized.get("archived_catalog_auto_used", true)) \
			and not bool(normalized.get("template_selection_fallback_used", false))
	return {
		"ok": ok,
		"case_id": expected.get("case_id", ""),
		"selected_template_id": selection.get("source_template_id", ""),
		"selected_source_catalog_index": selection.get("source_catalog_index", -1),
		"selected_source_name": selection.get("selected_template", {}).get("source_name", ""),
		"accepted_source_catalog_indices": accepted_indices,
		"accepted_template_count": accepted_indices.size(),
		"template_preselection_rng_call_count": selection.get("template_preselection_rng_call_count", -1),
		"template_selection_rng_value": selection.get("template_selection_rng_value", -1),
		"seed_coverage": coverage,
		"full_generation_status": identity.get("full_generation_status", ""),
		"template_selection_authority": normalized.get("template_selection_authority", ""),
		"translated_template_authority_used": normalized.get("translated_template_authority_used", true),
	}

func _validate_explicit_translated_request(service: Variant) -> Dictionary:
	var config := _medium_land_config("10", 4)
	config["template_id"] = "translated_rmg_template_002_v1"
	config["profile_id"] = "translated_rmg_profile_002_v1"
	var identity: Dictionary = service.random_map_config_identity(config)
	var normalized: Dictionary = identity.get("normalized_config", {}) if identity.get("normalized_config", {}) is Dictionary else {}
	var selection: Dictionary = normalized.get("h3maped_template_selection", {}) if normalized.get("h3maped_template_selection", {}) is Dictionary else {}
	var generated: Dictionary = service.generate_random_map(config)
	var ok := String(normalized.get("template_selection_mode", "")) == "h3maped_exe_rng" \
			and String(normalized.get("template_selection_authority", "")) == "h3maped_exe_rng_original_catalog" \
			and String(normalized.get("template_id", "")) == "h3maped_template_015" \
			and int(selection.get("source_catalog_index", -1)) == 15 \
			and String(normalized.get("requested_template_id_before_h3maped_selection", "")) == "translated_rmg_template_002_v1" \
			and bool(normalized.get("explicit_template_request_overridden_by_h3maped_reset", false)) \
			and not bool(normalized.get("translated_template_authority_used", true)) \
			and not bool(normalized.get("archived_catalog_auto_used", true)) \
			and not bool(generated.get("ok", true)) \
			and not bool(generated.get("runtime_generation_allowed", true)) \
			and not generated.has("map_document_payload") \
			and String(generated.get("generation_status", "")) == "h3maped_medium_phase_port_runtime_blocked" \
			and String(generated.get("full_generation_status", "")) == "h3maped_medium_waiting_for_executable_phase_port" \
			and String(generated.get("source_template_id", "")) == "h3maped_template_015" \
			and not bool(generated.get("translated_template_authority_used", true)) \
			and not bool(generated.get("archived_catalog_auto_used", true)) \
			and not bool(generated.get("template_selection_fallback_used", true))
	return {
		"ok": ok,
		"normalized_template_id": normalized.get("template_id", ""),
		"requested_template_id_before_h3maped_selection": normalized.get("requested_template_id_before_h3maped_selection", ""),
		"explicit_template_request_overridden_by_h3maped_reset": normalized.get("explicit_template_request_overridden_by_h3maped_reset", false),
		"generation_status": generated.get("generation_status", ""),
		"full_generation_status": generated.get("full_generation_status", ""),
		"source_template_id": generated.get("source_template_id", ""),
		"has_map_document_payload": generated.has("map_document_payload"),
	}

func _validate_unsupported_modes(service: Variant) -> Dictionary:
	var cases := [
		{"case_id": "medium_normal_water", "config": _medium_config("12", 4, 72, 72, 1, "normal_water", "homm3_medium")},
		{"case_id": "medium_islands", "config": _medium_config("12", 4, 72, 72, 1, "islands", "homm3_medium")},
		{"case_id": "medium_two_level_land", "config": _medium_config("12", 4, 72, 72, 2, "land", "homm3_medium")},
	]
	var case_reports := []
	var ok := true
	for test_case in cases:
		var generated: Dictionary = service.generate_random_map(test_case.get("config", {}))
		var case_ok := not bool(generated.get("ok", true)) \
				and not bool(generated.get("runtime_generation_allowed", true)) \
				and not generated.has("map_document_payload") \
				and String(generated.get("generation_status", "")) == "archived_legacy_native_rmg_disabled" \
				and not bool(generated.get("translated_template_authority_used", true)) \
				and not bool(generated.get("archived_catalog_auto_used", true)) \
				and not bool(generated.get("template_selection_fallback_used", true))
		ok = ok and case_ok
		case_reports.append({
			"case_id": test_case.get("case_id", ""),
			"ok": case_ok,
			"generation_status": generated.get("generation_status", ""),
			"full_generation_status": generated.get("full_generation_status", ""),
			"runtime_generation_allowed": generated.get("runtime_generation_allowed", true),
			"has_map_document_payload": generated.has("map_document_payload"),
		})
	return {
		"ok": ok,
		"cases": case_reports,
	}

func _seed_coverage_for_vector_size(vector_size: int, preselection_rng_calls: int) -> Dictionary:
	var first_seed_by_vector_index := {}
	for seed in range(SEED_COVERAGE_LIMIT):
		var selection_value := _h3maped_template_selection_rng_value(seed, preselection_rng_calls)
		var vector_index := selection_value % vector_size
		if not first_seed_by_vector_index.has(vector_index):
			first_seed_by_vector_index[vector_index] = seed
	var missing := []
	for vector_index in range(vector_size):
		if not first_seed_by_vector_index.has(vector_index):
			missing.append(vector_index)
	return {
		"all_vector_slots_reachable": missing.is_empty(),
		"covered_vector_slot_count": first_seed_by_vector_index.size(),
		"vector_size": vector_size,
		"preselection_rng_calls": preselection_rng_calls,
		"seed_limit": SEED_COVERAGE_LIMIT,
		"missing_vector_indices": missing,
	}

func _h3maped_template_selection_rng_value(seed: int, preselection_rng_calls: int) -> int:
	var state := seed
	var value := 0
	for _call_index in range(preselection_rng_calls + 1):
		state = (state * 0x343fd + 0x269ec3) & 0xffffffff
		value = (state >> 16) & 0x7fff
	return value

func _medium_land_config(seed: String, player_count: int) -> Dictionary:
	return _medium_config(seed, player_count, 72, 72, 1, "land", "homm3_medium")

func _medium_config(seed: String, player_count: int, width: int, height: int, level_count: int, water_mode: String, size_class_id: String) -> Dictionary:
	return {
		"seed": seed,
		"size": {
			"width": width,
			"height": height,
			"level_count": level_count,
			"water_mode": water_mode,
			"size_class_id": size_class_id,
		},
		"player_constraints": {
			"human_count": 1,
			"player_count": player_count,
			"team_mode": "free_for_all",
		},
	}

func _int_array(values: Variant) -> Array:
	var result := []
	if values is Array:
		for value in values:
			result.append(int(value))
	return result

func _fail(message: String) -> void:
	push_error("%s: %s" % [REPORT_ID, message])
	get_tree().quit(1)
