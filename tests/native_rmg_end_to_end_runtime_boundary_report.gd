extends Node

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const REPORT_ID := "NATIVE_RMG_END_TO_END_RUNTIME_BOUNDARY_REPORT"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not ClassDB.class_exists("MapPackageService"):
		_fail("MapPackageService native class is not available.")
		return
	var service: Variant = ClassDB.instantiate("MapPackageService")
	if not _validate_supported_workflow_matrix(service):
		return

	var medium := _generate_and_validate(
		service,
		_config("medium", 72, 1, "land", "10"),
		79333,
		1326
	)
	if not bool(medium.get("ok", false)):
		_fail("Medium public generation boundary failed: %s" % JSON.stringify(medium))
		return
	var xlarge := _generate_and_validate(
		service,
		_config("xlarge", 144, 2, "normal_water", "77"),
		365777,
		2779
	)
	if not bool(xlarge.get("ok", false)):
		_fail("XLarge public generation boundary failed: %s" % JSON.stringify(xlarge))
		return

	var round_trip := _validate_round_trip(service, medium.get("generated", {}))
	if not bool(round_trip.get("ok", false)):
		_fail("Native package round trip failed: %s" % JSON.stringify(round_trip))
		return
	var startup := _validate_session_startup()
	if not bool(startup.get("ok", false)):
		_fail("Generated session startup failed: %s" % JSON.stringify(startup))
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"workflow_shape_count": 24,
		"medium": medium.get("summary", {}),
		"xlarge": xlarge.get("summary", {}),
		"round_trip": round_trip,
		"startup": startup,
	})])
	get_tree().quit(0)

func _validate_supported_workflow_matrix(service: Variant) -> bool:
	var supported_count := 0
	for size_record in [["small", 36], ["medium", 72], ["large", 108], ["xlarge", 144]]:
		for level_count in [1, 2]:
			for water_mode in ["land", "normal_water", "islands"]:
				var normalized: Dictionary = service.normalize_random_map_config(
					_config(String(size_record[0]), int(size_record[1]), level_count, water_mode, "1")
				)
				if not bool(normalized.get("supported_parity_config", false)):
					_fail("Supported workflow shape was rejected: %s" % JSON.stringify(normalized))
					return false
				if String(normalized.get("h3maped_strict_scope", "")).begins_with("unsupported"):
					_fail("Supported workflow shape has unsupported strict-scope metadata: %s" % JSON.stringify(normalized))
					return false
				supported_count += 1
	if supported_count != 24:
		_fail("Supported workflow matrix count mismatch: %d" % supported_count)
		return false
	var unsupported: Dictionary = service.generate_random_map(
		_config("xlarge", 144, 2, "normal_water", "77", "impossible")
	)
	if bool(unsupported.get("ok", true)) \
			or String(unsupported.get("error_code", "")) != "native_rmg_monster_strength_unsupported":
		_fail("Unsupported monster strength did not fail closed: %s" % JSON.stringify(unsupported))
		return false
	return true

func _generate_and_validate(
	service: Variant,
	config: Dictionary,
	expected_payload_bytes: int,
	expected_object_count: int
) -> Dictionary:
	var generated: Dictionary = service.generate_random_map(config, {"startup_path": "completion_boundary"})
	var map_document: Variant = generated.get("map_document", null)
	var scenario_document: Variant = generated.get("scenario_document", null)
	var map_validation: Dictionary = service.validate_map_document(map_document) if map_document != null else {"ok": false}
	var scenario_validation: Dictionary = service.validate_scenario_document(
		scenario_document,
		map_document
	) if map_document != null and scenario_document != null else {"ok": false}
	var start_contract: Dictionary = scenario_document.get_start_contract() if scenario_document != null else {}
	var starts: Array = start_contract.get("player_starts", []) if start_contract.get("player_starts", []) is Array else []
	var start_bindings_ok := starts.size() == 2
	for start_value in starts:
		if not (start_value is Dictionary):
			start_bindings_ok = false
			continue
		var start: Dictionary = start_value
		var placement_id := String(start.get("town_placement_id", ""))
		var town: Dictionary = map_document.get_object_by_placement_id(placement_id) if map_document != null else {}
		if placement_id == "" \
				or String(town.get("kind", "")) != "town" \
				or int(town.get("owner_slot", 0)) != int(start.get("owner_slot", -1)):
			start_bindings_ok = false
	var ok := bool(generated.get("ok", false)) \
			and String(generated.get("generation_status", "")) == "native_rmg_complete" \
			and bool(generated.get("native_runtime_authoritative", false)) \
			and bool(generated.get("runtime_payload_projection_complete", false)) \
			and int(generated.get("final_payload_byte_count", -1)) == expected_payload_bytes \
			and int(generated.get("runtime_object_count", -1)) == expected_object_count \
			and map_document != null \
			and scenario_document != null \
			and int(map_document.get_object_count()) == expected_object_count \
			and bool(map_validation.get("ok", false)) \
			and bool(scenario_validation.get("ok", false)) \
			and int(start_contract.get("start_count", -1)) == 2 \
			and int(start_contract.get("start_town_count", -1)) == 2 \
			and start_bindings_ok
	return {
		"ok": ok,
		"generated": generated,
		"summary": {
			"payload_bytes": generated.get("final_payload_byte_count", -1),
			"objects": generated.get("runtime_object_count", -1),
			"starts": start_contract.get("start_count", -1),
			"start_bindings_ok": start_bindings_ok,
		},
		"map_validation": map_validation,
		"scenario_validation": scenario_validation,
	}

func _validate_round_trip(service: Variant, generated: Dictionary) -> Dictionary:
	var adoption: Dictionary = service.convert_generated_payload(generated, {"feature_gate": REPORT_ID})
	var map_path := "user://native_rmg_completion_boundary.amap"
	var scenario_path := "user://native_rmg_completion_boundary.ascenario"
	var map_save: Dictionary = service.save_map_package(adoption.get("map_document", null), map_path)
	var scenario_save: Dictionary = service.save_scenario_package(adoption.get("scenario_document", null), scenario_path)
	var map_load: Dictionary = service.load_map_package(map_path)
	var scenario_load: Dictionary = service.load_scenario_package(scenario_path)
	var loaded_map: Variant = map_load.get("map_document", null)
	var loaded_scenario: Variant = scenario_load.get("scenario_document", null)
	var loaded_contract: Dictionary = loaded_scenario.get_start_contract() if loaded_scenario != null else {}
	var ok := bool(adoption.get("ok", false)) \
			and bool(map_save.get("ok", false)) \
			and bool(scenario_save.get("ok", false)) \
			and bool(map_load.get("ok", false)) \
			and bool(scenario_load.get("ok", false)) \
			and loaded_map != null \
			and loaded_scenario != null \
			and int(loaded_map.get_object_count()) == 1326 \
			and int(loaded_contract.get("start_count", -1)) == 2
	DirAccess.remove_absolute(ProjectSettings.globalize_path(map_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(scenario_path))
	return {
		"ok": ok,
		"map_saved": map_save.get("ok", false),
		"scenario_saved": scenario_save.get("ok", false),
		"map_loaded": map_load.get("ok", false),
		"scenario_loaded": scenario_load.get("ok", false),
	}

func _validate_session_startup() -> Dictionary:
	var config := ScenarioSelectRulesScript.build_random_map_player_config(
		"10",
		"",
		"",
		2,
		"land",
		false,
		"homm3_medium",
		ScenarioSelectRulesScript.RANDOM_MAP_TEMPLATE_SELECTION_MODE_CATALOG_AUTO
	)
	config["monster_strength"] = "weak"
	var setup: Dictionary = ScenarioSelectRulesScript.build_random_map_skirmish_setup_with_retry(
		config,
		"normal",
		{"max_attempts": 1, "mode": "none"}
	)
	var session = ScenarioSelectRulesScript.start_random_map_skirmish_session_from_setup(setup)
	var package_startup: Dictionary = setup.get("package_startup", {}) if setup.get("package_startup", {}) is Dictionary else {}
	var map_path := String(package_startup.get("map_path", ""))
	var scenario_path := String(package_startup.get("scenario_path", ""))
	var boundary: Dictionary = session.flags.get("generated_random_map_boundary", {}) if session != null and session.flags.get("generated_random_map_boundary", {}) is Dictionary else {}
	var ok := bool(setup.get("ok", false)) \
			and session != null \
			and String(session.scenario_id) != "" \
			and String(boundary.get("adoption_path", "")) == "native_rmg_generated_package_saved_loaded_from_disk"
	if map_path != "":
		DirAccess.remove_absolute(ProjectSettings.globalize_path(map_path))
	if scenario_path != "":
		DirAccess.remove_absolute(ProjectSettings.globalize_path(scenario_path))
	return {
		"ok": ok,
		"setup_ok": setup.get("ok", false),
		"scenario_id": session.scenario_id if session != null else "",
		"adoption_path": boundary.get("adoption_path", ""),
	}

func _config(
	size_class: String,
	dimension: int,
	level_count: int,
	water_mode: String,
	seed: String,
	monster_strength: String = "weak"
) -> Dictionary:
	return {
		"seed": seed,
		"size": {
			"width": dimension,
			"height": dimension,
			"level_count": level_count,
			"water_mode": water_mode,
			"size_class_id": size_class,
		},
		"monster_strength": monster_strength,
		"player_constraints": {
			"human_count": 1,
			"computer_count": 1,
			"player_count": 2,
			"human_team_count": 1,
			"computer_team_count": 0,
		},
	}

func _fail(message: String) -> void:
	push_error("%s: %s" % [REPORT_ID, message])
	get_tree().quit(1)
