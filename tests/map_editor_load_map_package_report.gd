extends Node

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")

const REPORT_ID := "MAP_EDITOR_LOAD_MAP_PACKAGE_REPORT"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not ClassDB.class_exists("MapPackageService"):
		_fail("MapPackageService native class is not available.")
		return
	ContentService.clear_generated_scenario_drafts()
	var setup := ScenarioSelectRulesScript.build_random_map_skirmish_setup(
		ScenarioSelectRulesScript.build_random_map_player_config(
			"map-editor-load-map-package-10184",
			"border_gate_compact_v1",
			"border_gate_compact_profile_v1",
			3,
			"land",
			false,
			"homm3_small"
		),
		"normal"
	)
	if not bool(setup.get("ok", false)):
		_fail("Generated package setup failed: %s" % JSON.stringify(setup))
		return
	var startup: Dictionary = setup.get("package_startup", {}) if setup.get("package_startup", {}) is Dictionary else {}
	var map_path := String(startup.get("map_path", ""))
	var scenario_path := String(startup.get("scenario_path", ""))
	var package_stem := String(startup.get("package_stem", ""))
	var package_id := ScenarioSelectRulesScript.maps_folder_package_id_for_stem(package_stem)
	if package_id == "" or not FileAccess.file_exists(map_path) or not FileAccess.file_exists(scenario_path):
		_fail("Generated package setup did not write paired map packages: %s" % JSON.stringify(startup))
		return

	var shell = load("res://scenes/editor/MapEditorShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	if not shell.has_method("validation_snapshot") or not shell.has_method("validation_load_maps_folder_package"):
		_cleanup(map_path, scenario_path)
		_fail("Map editor did not expose Load Map validation hooks.")
		return
	var initial: Dictionary = shell.call("validation_snapshot")
	if bool(initial.get("working_copy", true)):
		_cleanup(map_path, scenario_path)
		_fail("Map editor should wait for Load Map instead of auto-loading an authored scenario: %s" % JSON.stringify(initial))
		return
	if not bool(initial.get("load_map_flow_active", false)) or bool(initial.get("legacy_scenario_dropdown_active", true)):
		_cleanup(map_path, scenario_path)
		_fail("Map editor did not expose the active Load Map package flow: %s" % JSON.stringify(initial))
		return
	if bool(initial.get("authored_json_scenarios_used", true)):
		_cleanup(map_path, scenario_path)
		_fail("Initial Load Map snapshot reported authored JSON scenario usage.")
		return
	var labels: Array = initial.get("map_package_picker_labels", [])
	var metadata: Array = initial.get("map_package_picker_metadata", [])
	if package_id not in metadata:
		_cleanup(map_path, scenario_path)
		_fail("Load Map picker did not include the generated maps/ package id: %s" % JSON.stringify(initial))
		return
	if not _any_label_contains(labels, "Map Package |"):
		_cleanup(map_path, scenario_path)
		_fail("Load Map picker did not use map package copy: %s" % JSON.stringify(labels))
		return
	if _active_copy_mentions_legacy_scenario_dropdown(initial):
		_cleanup(map_path, scenario_path)
		_fail("Load Map UI still exposed old scenario dropdown copy: %s" % JSON.stringify(initial))
		return

	var loaded: Dictionary = shell.call("validation_load_maps_folder_package", package_id)
	if not bool(loaded.get("ok", false)):
		_cleanup(map_path, scenario_path)
		_fail("Load Map could not open the generated package: %s" % JSON.stringify(loaded))
		return
	if String(loaded.get("editor_source_kind", "")) != "maps_folder_package":
		_cleanup(map_path, scenario_path)
		_fail("Loaded editor working copy did not record package source kind: %s" % JSON.stringify(loaded))
		return
	if String(loaded.get("editor_source_package_id", "")) != package_id:
		_cleanup(map_path, scenario_path)
		_fail("Loaded editor working copy did not record the selected package id: %s" % JSON.stringify(loaded))
		return
	if String(loaded.get("editor_source_map_path", "")) != map_path or String(loaded.get("editor_source_scenario_path", "")) != scenario_path:
		_cleanup(map_path, scenario_path)
		_fail("Loaded editor working copy used the wrong package paths: %s" % JSON.stringify(loaded))
		return
	if not bool(loaded.get("maps_folder_package_browser", false)) or not bool(loaded.get("working_copy", false)):
		_cleanup(map_path, scenario_path)
		_fail("Loaded map package did not create a package-backed editor working copy: %s" % JSON.stringify(loaded))
		return
	if bool(loaded.get("authored_json_scenarios_used", true)):
		_cleanup(map_path, scenario_path)
		_fail("Loaded editor snapshot reported authored JSON scenario usage.")
		return
	if ContentService.has_authored_scenario(String(loaded.get("scenario_id", ""))) or ContentService.has_generated_scenario_draft(String(loaded.get("scenario_id", ""))):
		_cleanup(map_path, scenario_path)
		_fail("Loaded package leaked into authored scenarios or generated draft registry: %s" % String(loaded.get("scenario_id", "")))
		return
	var map_ref: Dictionary = loaded.get("map_package_ref", {}) if loaded.get("map_package_ref", {}) is Dictionary else {}
	var scenario_ref: Dictionary = loaded.get("scenario_package_ref", {}) if loaded.get("scenario_package_ref", {}) is Dictionary else {}
	if map_ref.is_empty() or scenario_ref.is_empty():
		_cleanup(map_path, scenario_path)
		_fail("Loaded editor working copy missed package refs: %s" % JSON.stringify(loaded))
		return
	if _active_copy_mentions_legacy_scenario_dropdown(loaded):
		_cleanup(map_path, scenario_path)
		_fail("Loaded editor UI still exposed old scenario dropdown copy: %s" % JSON.stringify(loaded))
		return

	_cleanup(map_path, scenario_path)
	ContentService.clear_generated_scenario_drafts()
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"package_id": package_id,
		"package_stem": package_stem,
		"map_path": map_path,
		"scenario_path": scenario_path,
		"scenario_id": String(loaded.get("scenario_id", "")),
		"load_map_flow_active": true,
		"authored_json_scenarios_used": false,
	})])
	get_tree().quit(0)

func _any_label_contains(labels: Array, needle: String) -> bool:
	for label in labels:
		if String(label).contains(needle):
			return true
	return false

func _active_copy_mentions_legacy_scenario_dropdown(snapshot: Dictionary) -> bool:
	var combined := " ".join([
		String(snapshot.get("visible_status_text", "")),
		String(snapshot.get("map_load_handoff_text", "")),
		String(snapshot.get("map_load_handoff_tooltip", "")),
		String(snapshot.get("map_package_picker_tooltip", "")),
		String(snapshot.get("load_map_button_text", "")),
		String(snapshot.get("status_text", "")),
	])
	for forbidden in [
		"Scenario switch:",
		"Scenario Switch",
		"scenario dropdown",
		"choosing another scenario",
		"authored baseline",
		"Loaded authored scenario",
		"Ninefold Confluence",
	]:
		if combined.contains(forbidden):
			return true
	return false

func _cleanup(map_path: String, scenario_path: String) -> void:
	if map_path != "" and FileAccess.file_exists(map_path):
		DirAccess.remove_absolute(map_path)
	if scenario_path != "" and FileAccess.file_exists(scenario_path):
		DirAccess.remove_absolute(scenario_path)

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
