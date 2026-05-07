extends Node

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")

const REPORT_ID := "MAPS_FOLDER_PACKAGE_BROWSER_INTEGRATION_REPORT"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not ClassDB.class_exists("MapPackageService"):
		_fail("MapPackageService native class is not available.")
		return
	ContentService.clear_generated_scenario_drafts()
	var empty_index := ScenarioSelectRulesScript.maps_folder_package_index({
		"package_dir": "user://maps-folder-package-browser-empty-%d" % Time.get_ticks_usec(),
	})
	if not bool(empty_index.get("ok", false)) or not empty_index.get("entries", []).is_empty():
		_fail("Empty maps folder index was not sane: %s" % JSON.stringify(empty_index))
		return
	if bool(empty_index.get("authored_json_scenarios_used", true)):
		_fail("Empty maps folder index used authored JSON scenarios.")
		return

	var setup := ScenarioSelectRulesScript.build_random_map_skirmish_setup(
		ScenarioSelectRulesScript.build_random_map_player_config(
			"maps-folder-package-browser-integration-10184",
			"",
			"",
			3,
			"land",
			false,
			"homm3_small",
			ScenarioSelectRulesScript.RANDOM_MAP_TEMPLATE_SELECTION_MODE_CATALOG_AUTO
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
	if package_stem == "" or not FileAccess.file_exists(map_path) or not FileAccess.file_exists(scenario_path):
		_fail("Generated setup did not write paired map packages: %s" % JSON.stringify(startup))
		return
	var compact_artifacts := _generate_compact_package_artifact()
	var compact_map_path := String(compact_artifacts.get("map_path", ""))
	var compact_scenario_path := String(compact_artifacts.get("scenario_path", ""))
	var compact_package_id := String(compact_artifacts.get("package_id", ""))

	var index := ScenarioSelectRulesScript.maps_folder_package_index()
	var indexed_entry := _find_package_entry(index.get("entries", []), package_id)
	if indexed_entry.is_empty():
		_cleanup_many([[map_path, scenario_path], [compact_map_path, compact_scenario_path]])
		_fail("Generated package pair was not found in maps folder index: %s" % JSON.stringify(index))
		return
	if bool(indexed_entry.get("legacy_json_scenario_record", true)) or bool(indexed_entry.get("authored_json_scenarios_used", true)):
		_cleanup_many([[map_path, scenario_path], [compact_map_path, compact_scenario_path]])
		_fail("Package index record did not preserve generated package boundaries: %s" % JSON.stringify(indexed_entry))
		return
	if not String(indexed_entry.get("label", "")).contains(" | ") or String(indexed_entry.get("display_name", "")).strip_edges() == "":
		_cleanup_many([[map_path, scenario_path], [compact_map_path, compact_scenario_path]])
		_fail("Package index did not build readable display fields: %s" % JSON.stringify(indexed_entry))
		return
	if not compact_package_id.is_empty() and not _find_package_entry(index.get("entries", []), compact_package_id).is_empty():
		_cleanup_many([[map_path, scenario_path], [compact_map_path, compact_scenario_path]])
		_fail("Legacy compact package was exposed in maps-folder index: %s" % JSON.stringify(index))
		return
	if not compact_package_id.is_empty() and _find_rejected_warning(index.get("warnings", []), compact_package_id).is_empty():
		_cleanup_many([[map_path, scenario_path], [compact_map_path, compact_scenario_path]])
		_fail("Legacy compact package was not reported as a rejected maps-folder package: %s" % JSON.stringify(index))
		return

	var browser_entry := _find_package_entry(ScenarioSelectRulesScript.build_skirmish_browser_entries(), package_id)
	if browser_entry.is_empty():
		_cleanup_many([[map_path, scenario_path], [compact_map_path, compact_scenario_path]])
		_fail("Skirmish browser did not expose the generated maps package.")
		return
	if not compact_package_id.is_empty() and not _find_package_entry(ScenarioSelectRulesScript.build_skirmish_browser_entries(), compact_package_id).is_empty():
		_cleanup_many([[map_path, scenario_path], [compact_map_path, compact_scenario_path]])
		_fail("Skirmish browser exposed a rejected legacy compact package.")
		return
	var package_setup := ScenarioSelectRulesScript.build_skirmish_setup(package_id, "normal")
	if not bool(package_setup.get("ok", false)) or String(package_setup.get("startup_source", "")) != "maps_folder_package":
		_cleanup_many([[map_path, scenario_path], [compact_map_path, compact_scenario_path]])
		_fail("Skirmish setup did not resolve through the maps-folder package path: %s" % JSON.stringify(package_setup))
		return
	var session = ScenarioSelectRulesScript.start_skirmish_session(package_id, "normal")
	if session == null or session.scenario_id == "":
		_cleanup_many([[map_path, scenario_path], [compact_map_path, compact_scenario_path]])
		_fail("Maps-folder skirmish package did not start a session.")
		return
	var boundary: Dictionary = session.flags.get("generated_random_map_boundary", {}) if session.flags.get("generated_random_map_boundary", {}) is Dictionary else {}
	if String(boundary.get("adoption_path", "")) != "maps_folder_package_browser_loaded_from_disk":
		_cleanup_many([[map_path, scenario_path], [compact_map_path, compact_scenario_path]])
		_fail("Skirmish session did not start from the package-browser disk path: %s" % JSON.stringify(boundary))
		return
	if bool(boundary.get("content_service_generated_draft", true)) or bool(boundary.get("legacy_json_scenario_record", true)) or bool(boundary.get("authored_json_scenarios_used", true)):
		_cleanup_many([[map_path, scenario_path], [compact_map_path, compact_scenario_path]])
		_fail("Skirmish package session used a forbidden JSON/draft path: %s" % JSON.stringify(boundary))
		return
	if ContentService.has_authored_scenario(session.scenario_id) or ContentService.has_generated_scenario_draft(session.scenario_id):
		_cleanup_many([[map_path, scenario_path], [compact_map_path, compact_scenario_path]])
		_fail("Generated package scenario leaked into authored content or generated draft registry: %s" % session.scenario_id)
		return

	var shell = load("res://scenes/editor/MapEditorShell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	if not shell.has_method("validation_load_maps_folder_package"):
		_cleanup_many([[map_path, scenario_path], [compact_map_path, compact_scenario_path]])
		_fail("Map editor did not expose maps-folder package validation loader.")
		return
	var editor_snapshot: Dictionary = shell.call("validation_load_maps_folder_package", package_id)
	if not bool(editor_snapshot.get("ok", false)):
		_cleanup_many([[map_path, scenario_path], [compact_map_path, compact_scenario_path]])
		_fail("Map editor could not open generated maps-folder package: %s" % JSON.stringify(editor_snapshot))
		return
	if String(editor_snapshot.get("editor_source_kind", "")) != "maps_folder_package" or String(editor_snapshot.get("editor_source_package_id", "")) != package_id:
		_cleanup_many([[map_path, scenario_path], [compact_map_path, compact_scenario_path]])
		_fail("Map editor did not mark the generated package source: %s" % JSON.stringify(editor_snapshot))
		return
	if String(editor_snapshot.get("editor_source_map_path", "")) != map_path or String(editor_snapshot.get("editor_source_scenario_path", "")) != scenario_path:
		_cleanup_many([[map_path, scenario_path], [compact_map_path, compact_scenario_path]])
		_fail("Map editor opened the wrong package paths: %s" % JSON.stringify(editor_snapshot))
		return
	if not bool(editor_snapshot.get("working_copy", false)) or not bool(editor_snapshot.get("maps_folder_package_browser", false)):
		_cleanup_many([[map_path, scenario_path], [compact_map_path, compact_scenario_path]])
		_fail("Map editor did not create a package-backed working copy: %s" % JSON.stringify(editor_snapshot))
		return

	_cleanup_many([[map_path, scenario_path], [compact_map_path, compact_scenario_path]])
	ContentService.clear_generated_scenario_drafts()
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"package_id": package_id,
		"package_stem": package_stem,
		"map_path": map_path,
		"scenario_path": scenario_path,
		"skirmish_scenario_id": session.scenario_id,
		"editor_scenario_id": String(editor_snapshot.get("scenario_id", "")),
		"empty_index_entries": empty_index.get("entries", []).size(),
		"compact_package_rejected": compact_package_id != "",
		"authored_json_scenarios_used": false,
		"generated_draft_registry_used": false,
	})])
	get_tree().quit(0)

func _generate_compact_package_artifact() -> Dictionary:
	var service: Variant = ClassDB.instantiate("MapPackageService")
	var generated: Dictionary = service.generate_random_map(
		ScenarioSelectRulesScript.build_random_map_player_config(
			"maps-folder-legacy-compact-rejection-10184",
			"border_gate_compact_v1",
			"border_gate_compact_profile_v1",
			3,
			"land",
			false,
			"homm3_small"
		),
		{"startup_path": "maps_folder_legacy_compact_rejection_fixture"}
	)
	if not bool(generated.get("ok", false)):
		return {}
	var adoption: Dictionary = service.convert_generated_payload(generated, {
		"feature_gate": "maps_folder_legacy_compact_rejection_fixture",
		"session_save_version": 9,
	})
	if not bool(adoption.get("ok", false)):
		return {}
	var startup: Dictionary = ScenarioSelectRulesScript._persist_and_load_generated_packages(service, adoption, generated)
	if not bool(startup.get("ok", false)):
		return {}
	var package_stem := String(startup.get("package_stem", ""))
	return {
		"map_path": String(startup.get("map_path", "")),
		"scenario_path": String(startup.get("scenario_path", "")),
		"package_stem": package_stem,
		"package_id": ScenarioSelectRulesScript.maps_folder_package_id_for_stem(package_stem) if package_stem != "" else "",
	}

func _find_package_entry(entries: Array, package_id: String) -> Dictionary:
	for entry in entries:
		if entry is Dictionary and String(entry.get("package_id", entry.get("scenario_id", ""))) == package_id:
			return entry
	return {}

func _find_rejected_warning(warnings: Array, package_id: String) -> Dictionary:
	var package_stem := ScenarioSelectRulesScript.maps_folder_package_stem_from_id(package_id)
	for warning in warnings:
		if warning is Dictionary and String(warning.get("package_stem", "")) == package_stem:
			return warning
	return {}

func _cleanup(map_path: String, scenario_path: String) -> void:
	if map_path != "" and FileAccess.file_exists(map_path):
		DirAccess.remove_absolute(map_path)
	if scenario_path != "" and FileAccess.file_exists(scenario_path):
		DirAccess.remove_absolute(scenario_path)

func _cleanup_many(pairs: Array) -> void:
	for pair in pairs:
		if pair is Array and pair.size() >= 2:
			_cleanup(String(pair[0]), String(pair[1]))

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
