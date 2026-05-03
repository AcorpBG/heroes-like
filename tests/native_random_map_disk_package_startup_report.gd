extends Node

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")

const REPORT_ID := "NATIVE_RANDOM_MAP_DISK_PACKAGE_STARTUP_REPORT"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not ClassDB.class_exists("MapPackageService"):
		_fail("MapPackageService native class is not available.")
		return
	var service: Variant = ClassDB.instantiate("MapPackageService")
	var metadata: Dictionary = service.get_api_metadata()
	if String(metadata.get("binding_kind", "")) != "native_gdextension" or not bool(metadata.get("native_extension_loaded", false)):
		_fail("Native service metadata did not prove GDExtension load: %s" % JSON.stringify(metadata))
		return
	var capabilities: PackedStringArray = service.get_capabilities()
	if not capabilities.has("native_package_save_load") or not capabilities.has("generated_map_package_disk_startup"):
		_fail("Native package save/load startup capabilities are missing: %s" % JSON.stringify(Array(capabilities)))
		return

	ContentService.clear_generated_scenario_drafts()
	var authored_before := ContentService.load_json(ContentService.SCENARIOS_PATH).duplicate(true)
	var authored_item_count := int(authored_before.get("items", []).size())
	var config := ScenarioSelectRulesScript.build_random_map_player_config(
		"native-rmg-disk-package-startup-10184",
		"border_gate_compact_v1",
		"border_gate_compact_profile_v1",
		3,
		"land",
		false,
		"homm3_small"
	)
	var setup := ScenarioSelectRulesScript.build_random_map_skirmish_setup_with_retry(
		config,
		"normal",
		ScenarioSelectRulesScript.RANDOM_MAP_PLAYER_RETRY_POLICY
	)
	if not bool(setup.get("ok", false)):
		_fail("Generated package setup failed: %s" % JSON.stringify(setup))
		return
	if not setup.get("generated_map", {}).is_empty():
		_fail("Active setup still exposes an in-memory generated scenario payload.")
		return
	var package_startup: Dictionary = setup.get("package_startup", {}) if setup.get("package_startup", {}) is Dictionary else {}
	if package_startup.is_empty():
		_fail("Setup did not include package startup evidence.")
		return
	var map_path := String(package_startup.get("map_path", ""))
	var scenario_path := String(package_startup.get("scenario_path", ""))
	if not map_path.begins_with("res://maps/") or not scenario_path.begins_with("res://maps/"):
		_fail("Generated packages were not written under res://maps: %s" % JSON.stringify(package_startup))
		return
	if not FileAccess.file_exists(map_path) or not FileAccess.file_exists(scenario_path):
		_fail("Generated package files do not exist on disk.")
		return
	if not bool(package_startup.get("map_load", {}).get("ok", false)) or not bool(package_startup.get("scenario_load", {}).get("ok", false)):
		_fail("Setup did not prove package load after save: %s" % JSON.stringify(package_startup))
		return

	var scenario_id := String(setup.get("scenario_id", ""))
	if scenario_id == "" or ContentService.has_authored_scenario(scenario_id) or ContentService.has_generated_scenario_draft(scenario_id):
		_fail("Generated package scenario leaked into authored content or generated draft registry: %s" % scenario_id)
		return
	if int(ContentService.load_json(ContentService.SCENARIOS_PATH).get("items", []).size()) != authored_item_count:
		_fail("content/scenarios.json item count changed during generated startup.")
		return
	if not ScenarioSelectRulesScript.build_skirmish_browser_entries().is_empty():
		_fail("Authored skirmish browser unexpectedly exposed scenarios as the active path.")
		return

	var session = ScenarioSelectRulesScript.start_random_map_skirmish_session_from_setup(setup)
	if session == null or session.scenario_id == "":
		_fail("Generated package setup did not start a session.")
		return
	var boundary: Dictionary = session.flags.get("generated_random_map_boundary", {}) if session.flags.get("generated_random_map_boundary", {}) is Dictionary else {}
	if String(boundary.get("adoption_path", "")) != "native_rmg_generated_package_saved_loaded_from_disk":
		_fail("Session did not start through the disk package adoption path: %s" % JSON.stringify(boundary))
		return
	if bool(boundary.get("content_service_generated_draft", true)) or bool(boundary.get("legacy_json_scenario_record", true)):
		_fail("Session boundary still used generated drafts or legacy scenario JSON: %s" % JSON.stringify(boundary))
		return
	if session.overworld.get("map", []).is_empty() or session.overworld.get("map_package_ref", {}).is_empty() or session.overworld.get("scenario_package_ref", {}).is_empty():
		_fail("Session did not carry loaded package map data and refs.")
		return

	var loaded_map: Dictionary = service.load_map_package(map_path)
	var loaded_scenario: Dictionary = service.load_scenario_package(scenario_path)
	if not bool(loaded_map.get("ok", false)) or not bool(loaded_scenario.get("ok", false)):
		_fail("Independent package load failed after startup.")
		return
	DirAccess.remove_absolute(map_path)
	DirAccess.remove_absolute(scenario_path)

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"native_extension_loaded": true,
		"map_path": map_path,
		"scenario_path": scenario_path,
		"scenario_id": scenario_id,
		"session_id": session.session_id,
		"map_ref": session.overworld.get("map_package_ref", {}),
		"scenario_ref": session.overworld.get("scenario_package_ref", {}),
		"content_scenarios_json_used_for_startup": false,
		"generated_draft_registry_used": false,
	})])
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
