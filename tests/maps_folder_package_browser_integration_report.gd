extends Node

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")

const REPORT_ID := "MAPS_FOLDER_PACKAGE_BROWSER_INTEGRATION_REPORT"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not ClassDB.class_exists("MapPackageService"):
		_fail("MapPackageService native class is not available.")
		return
	var package_service: Variant = ClassDB.instantiate("MapPackageService")
	if package_service == null:
		_fail("MapPackageService native class could not be instantiated.")
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
			"1",
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
	var cache_lifecycle: Dictionary = _validate_native_browser_manifest_cache(package_service, map_path, scenario_path)
	if not bool(cache_lifecycle.get("ok", false)):
		_cleanup_many([[map_path, scenario_path]])
		_fail("Native browser manifest cache lifecycle changed package authority: %s" % JSON.stringify(cache_lifecycle))
		return
	var compact_artifacts := _generate_compact_package_artifact()
	var compact_map_path := String(compact_artifacts.get("map_path", ""))
	var compact_scenario_path := String(compact_artifacts.get("scenario_path", ""))
	var compact_package_id := String(compact_artifacts.get("package_id", ""))
	var failure_fixture := _create_package_index_failure_fixture(map_path, scenario_path)
	if not bool(failure_fixture.get("ok", false)):
		_cleanup_many([[map_path, scenario_path], [compact_map_path, compact_scenario_path]])
		_fail("Could not create exact package-index failure fixtures: %s" % JSON.stringify(failure_fixture))
		return
	var failure_index := ScenarioSelectRulesScript.maps_folder_package_index({
		"package_dir": String(failure_fixture.get("package_dir", "")),
	})
	var failure_codes := _package_warning_codes_by_stem(failure_index.get("warnings", []))
	if failure_codes != {
		"legacy-pair": "legacy_json_package_rejected",
		"malformed-pair": "package_inspect_failed",
		"wrong-schema-pair": "package_load_failed",
	} or int(failure_index.get("unpaired_map_count", -1)) != 1 or int(failure_index.get("unpaired_scenario_count", -1)) != 0:
		_cleanup_package_index_failure_fixture(failure_fixture)
		_cleanup_many([[map_path, scenario_path], [compact_map_path, compact_scenario_path]])
		_fail("Single-read package index changed exact failure classification: %s" % JSON.stringify({"codes": failure_codes, "index": failure_index}))
		return

	var index := ScenarioSelectRulesScript.maps_folder_package_index()
	var indexed_entry := _find_package_entry(index.get("entries", []), package_id)
	if indexed_entry.is_empty():
		var generated_warning := _find_rejected_warning(index.get("warnings", []), package_id)
		_cleanup_many([[map_path, scenario_path], [compact_map_path, compact_scenario_path]])
		_fail("Generated package pair %s (%s) was rejected by maps folder index: %s" % [package_id, package_stem, JSON.stringify(generated_warning)])
		return
	var map_inspect: Dictionary = package_service.inspect_package(map_path)
	var scenario_inspect: Dictionary = package_service.inspect_package(scenario_path)
	var map_manifest: Dictionary = map_inspect.get("browser_manifest", {}) if map_inspect.get("browser_manifest", {}) is Dictionary else {}
	var scenario_manifest: Dictionary = scenario_inspect.get("browser_manifest", {}) if scenario_inspect.get("browser_manifest", {}) is Dictionary else {}
	var map_control: Dictionary = package_service.load_map_package(map_path)
	var scenario_control: Dictionary = package_service.load_scenario_package(scenario_path)
	var map_document: Variant = map_control.get("map_document", null)
	var scenario_document: Variant = scenario_control.get("scenario_document", null)
	var manifest_checks := {
		"map_kind": String(map_manifest.get("document_kind", "")) == "map",
		"map_width": int(map_manifest.get("width", 0)) == int(map_document.get_width()),
		"map_height": int(map_manifest.get("height", 0)) == int(map_document.get_height()),
		"map_levels": int(map_manifest.get("level_count", 0)) == int(map_document.get_level_count()),
		"map_metadata": map_manifest.get("metadata", {}) == map_document.get_metadata(),
		"map_ref": map_manifest.get("map_ref", {}) == map_control.get("map_ref", {}),
		"scenario_kind": String(scenario_manifest.get("document_kind", "")) == "scenario",
		"scenario_selection": scenario_manifest.get("selection", {}) == scenario_document.get_selection(),
		"scenario_players": int(scenario_manifest.get("player_count", 0)) == scenario_document.get_player_slots().size(),
		"scenario_ref": scenario_manifest.get("scenario_ref", {}) == scenario_control.get("scenario_ref", {}),
	}
	var manifest_exact: bool = not manifest_checks.values().has(false)
	if not manifest_exact:
		_cleanup_many([[map_path, scenario_path], [compact_map_path, compact_scenario_path]])
		_fail("Native browser manifests changed full-load package authority: %s" % JSON.stringify({"checks": manifest_checks, "map": map_manifest, "scenario": scenario_manifest}))
		return
	var detached_manifest: Dictionary = map_manifest
	detached_manifest["metadata"]["browser_manifest_detach_probe"] = true
	var fresh_map_manifest: Dictionary = package_service.inspect_package(map_path).get("browser_manifest", {})
	if bool(fresh_map_manifest.get("metadata", {}).get("browser_manifest_detach_probe", false)) or bool(indexed_entry.get("metadata", {}).get("browser_manifest_detach_probe", false)):
		_cleanup_many([[map_path, scenario_path], [compact_map_path, compact_scenario_path]])
		_fail("Native package browser manifest retained aliased metadata authority.")
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
	var editor_index := ScenarioSelectRulesScript.maps_folder_package_index({
		"include_non_launchable_generated_packages": true,
		"consumer": "map_editor_validation",
	})
	var compact_editor_entry := _find_package_entry(editor_index.get("entries", []), compact_package_id)
	if not compact_package_id.is_empty() and compact_editor_entry.is_empty():
		_cleanup_many([[map_path, scenario_path], [compact_map_path, compact_scenario_path]])
		_fail("Map-editor package index did not expose a loadable generated package rejected by launch validation: %s" % JSON.stringify(editor_index))
		return
	if not compact_editor_entry.is_empty() and (bool(compact_editor_entry.get("launchable", true)) or not bool(compact_editor_entry.get("editor_inspection_only", false))):
		_cleanup_many([[map_path, scenario_path], [compact_map_path, compact_scenario_path]])
		_fail("Map-editor package index did not mark rejected launch packages as inspection-only: %s" % JSON.stringify(compact_editor_entry))
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
	var entry_setup := ScenarioSelectRulesScript.build_maps_folder_package_skirmish_setup_from_entry(indexed_entry, "normal")
	if entry_setup != package_setup:
		_cleanup_many([[map_path, scenario_path], [compact_map_path, compact_scenario_path]])
		_fail("Selected-entry Skirmish setup changed the exact by-id setup: %s" % JSON.stringify({"by_id": package_setup, "from_entry": entry_setup}))
		return
	var stale_entry: Dictionary = indexed_entry.duplicate(true)
	var stale_map_identity: Dictionary = stale_entry.get("map_file_identity", {}).duplicate(true)
	stale_map_identity["size"] = int(stale_map_identity.get("size", 0)) + 1
	stale_entry["map_file_identity"] = stale_map_identity
	if not ScenarioSelectRulesScript.build_maps_folder_package_skirmish_setup_from_entry(stale_entry, "normal").is_empty():
		_cleanup_many([[map_path, scenario_path], [compact_map_path, compact_scenario_path]])
		_fail("Selected-entry Skirmish setup accepted a stale package identity.")
		return
	var by_id_session = ScenarioSelectRulesScript.start_skirmish_session(package_id, "normal")
	var entry_session = ScenarioSelectRulesScript.start_maps_folder_package_skirmish_session_from_entry(indexed_entry, "normal")
	if not _session_authority_exact_ignoring_runtime_id(by_id_session, entry_session):
		_cleanup_many([[map_path, scenario_path], [compact_map_path, compact_scenario_path]])
		_fail("Selected-entry Skirmish launch changed by-id session authority.")
		return
	var session = entry_session
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
	var initial_editor_snapshot: Dictionary = shell.call("validation_snapshot")
	if not compact_package_id.is_empty() and compact_package_id not in initial_editor_snapshot.get("map_package_picker_metadata", []):
		_cleanup_many([[map_path, scenario_path], [compact_map_path, compact_scenario_path]])
		_fail("Map editor picker hid an inspection-only generated package: %s" % JSON.stringify(initial_editor_snapshot))
		return
	if not compact_package_id.is_empty() and int(initial_editor_snapshot.get("map_package_index_status", {}).get("editor_inspection_only_count", 0)) <= 0:
		_cleanup_many([[map_path, scenario_path], [compact_map_path, compact_scenario_path]])
		_fail("Map editor picker did not report inspection-only package entries: %s" % JSON.stringify(initial_editor_snapshot.get("map_package_index_status", {})))
		return
	if not compact_package_id.is_empty():
		var compact_editor_snapshot: Dictionary = shell.call("validation_load_maps_folder_package", compact_package_id)
		if not bool(compact_editor_snapshot.get("ok", false)):
			_cleanup_many([[map_path, scenario_path], [compact_map_path, compact_scenario_path]])
			_fail("Map editor could not inspect-load a generated package rejected by launch validation: %s" % JSON.stringify(compact_editor_snapshot))
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
	_cleanup_package_index_failure_fixture(failure_fixture)
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
		"selected_entry_setup_exact": true,
		"selected_entry_session_exact": true,
		"stale_entry_rejected": true,
		"single_read_failure_classification_exact": true,
		"native_browser_manifest_exact": true,
		"native_browser_manifest_detached": true,
		"native_browser_manifest_cache_exact": true,
		"native_browser_manifest_cache_save_prepopulated": bool(cache_lifecycle.get("save_prepopulated", false)),
		"native_browser_manifest_cache_changed_content_rebuilt": bool(cache_lifecycle.get("changed_content_rebuilt", false)),
		"native_browser_manifest_cache_corruption_rebuilt": bool(cache_lifecycle.get("corruption_rebuilt", false)),
		"authored_json_scenarios_used": false,
		"generated_draft_registry_used": false,
	})])
	get_tree().quit(0)

func _validate_native_browser_manifest_cache(package_service: Variant, map_path: String, scenario_path: String) -> Dictionary:
	var map_profiled: Dictionary = package_service.inspect_package(map_path, {"include_browser_manifest_cache_profile": true})
	var scenario_profiled: Dictionary = package_service.inspect_package(scenario_path, {"include_browser_manifest_cache_profile": true})
	var map_profile: Dictionary = map_profiled.get("browser_manifest_cache_profile", {}) if map_profiled.get("browser_manifest_cache_profile", {}) is Dictionary else {}
	var scenario_profile: Dictionary = scenario_profiled.get("browser_manifest_cache_profile", {}) if scenario_profiled.get("browser_manifest_cache_profile", {}) is Dictionary else {}
	var save_prepopulated: bool = (
		String(map_profile.get("status", "")) == "hit"
		and String(scenario_profile.get("status", "")) == "hit"
		and not String(map_profile.get("source_sha256", "")).is_empty()
		and not String(scenario_profile.get("source_sha256", "")).is_empty()
	)
	var map_cached: Dictionary = package_service.inspect_package(map_path)
	var map_bypass: Dictionary = package_service.inspect_package(map_path, {"browser_manifest_cache_mode": "bypass_read"})
	var scenario_cached: Dictionary = package_service.inspect_package(scenario_path)
	var scenario_bypass: Dictionary = package_service.inspect_package(scenario_path, {"browser_manifest_cache_mode": "bypass_read"})
	var whole_payload_exact: bool = map_cached == map_bypass and scenario_cached == scenario_bypass
	var map_cache_path := String(map_profile.get("cache_path", ""))
	var scenario_cache_path := String(scenario_profile.get("cache_path", ""))
	var cache_paths_exact: bool = (
		map_cache_path.begins_with("user://package_browser_manifest_cache_v1/")
		and scenario_cache_path.begins_with("user://package_browser_manifest_cache_v1/")
		and map_cache_path != scenario_cache_path
		and FileAccess.file_exists(map_cache_path)
		and FileAccess.file_exists(scenario_cache_path)
	)
	if not save_prepopulated or not whole_payload_exact or not cache_paths_exact:
		return {
			"ok": false,
			"save_prepopulated": save_prepopulated,
			"whole_payload_exact": whole_payload_exact,
			"cache_paths_exact": cache_paths_exact,
			"map_differences": _variant_differences(map_cached, map_bypass, "$"),
			"scenario_differences": _variant_differences(scenario_cached, scenario_bypass, "$"),
			"map_profile": map_profile,
			"scenario_profile": scenario_profile,
		}
	var cached_manifest: Dictionary = map_cached.get("browser_manifest", {}).duplicate(true)
	cached_manifest["metadata"]["cache_detach_probe"] = true
	var detached_rebuild: Dictionary = package_service.inspect_package(map_path)
	var detached_exact: bool = not bool(detached_rebuild.get("browser_manifest", {}).get("metadata", {}).get("cache_detach_probe", false))
	var cache_file := FileAccess.open(map_cache_path, FileAccess.WRITE)
	if cache_file == null:
		return {"ok": false, "error": "cache_corruption_open_failed", "cache_path": map_cache_path}
	cache_file.store_string("{corrupt-cache")
	cache_file.close()
	var corruption_rebuild: Dictionary = package_service.inspect_package(map_path, {"include_browser_manifest_cache_profile": true})
	var corruption_profile: Dictionary = corruption_rebuild.get("browser_manifest_cache_profile", {}) if corruption_rebuild.get("browser_manifest_cache_profile", {}) is Dictionary else {}
	var corruption_exact: bool = (
		String(corruption_profile.get("status", "")) == "miss_written"
		and _inspection_without_cache_profile(corruption_rebuild) == map_bypass
		and String(package_service.inspect_package(map_path, {"include_browser_manifest_cache_profile": true}).get("browser_manifest_cache_profile", {}).get("status", "")) == "hit"
	)
	var original_scenario_text := FileAccess.get_file_as_string(scenario_path)
	var changed_scenario = JSON.parse_string(original_scenario_text)
	if not (changed_scenario is Dictionary):
		return {"ok": false, "error": "scenario_source_parse_failed"}
	changed_scenario = changed_scenario.duplicate(true)
	changed_scenario["document"]["selection"]["display_name"] = "Cache Content Change Probe"
	if not _write_fixture_text(scenario_path, JSON.stringify(changed_scenario, "\t")):
		return {"ok": false, "error": "scenario_change_write_failed"}
	var changed_profiled: Dictionary = package_service.inspect_package(scenario_path, {"include_browser_manifest_cache_profile": true})
	var changed_profile: Dictionary = changed_profiled.get("browser_manifest_cache_profile", {}) if changed_profiled.get("browser_manifest_cache_profile", {}) is Dictionary else {}
	var changed_content_rebuilt: bool = (
		String(changed_profile.get("status", "")) == "miss_written"
		and String(changed_profile.get("source_sha256", "")) != String(scenario_profile.get("source_sha256", ""))
		and String(changed_profiled.get("browser_manifest", {}).get("selection", {}).get("display_name", "")) == "Cache Content Change Probe"
	)
	if not _write_fixture_text(scenario_path, original_scenario_text):
		return {"ok": false, "error": "scenario_restore_write_failed"}
	var restored_profiled: Dictionary = package_service.inspect_package(scenario_path, {"include_browser_manifest_cache_profile": true})
	var restored_profile: Dictionary = restored_profiled.get("browser_manifest_cache_profile", {}) if restored_profiled.get("browser_manifest_cache_profile", {}) is Dictionary else {}
	var restored_exact: bool = (
		String(restored_profile.get("status", "")) == "miss_written"
		and String(restored_profile.get("source_sha256", "")) == String(scenario_profile.get("source_sha256", ""))
		and _inspection_without_cache_profile(restored_profiled) == scenario_bypass
		and String(package_service.inspect_package(scenario_path, {"include_browser_manifest_cache_profile": true}).get("browser_manifest_cache_profile", {}).get("status", "")) == "hit"
	)
	return {
		"ok": detached_exact and corruption_exact and changed_content_rebuilt and restored_exact,
		"save_prepopulated": save_prepopulated,
		"whole_payload_exact": whole_payload_exact,
		"cache_paths_exact": cache_paths_exact,
		"detached_exact": detached_exact,
		"corruption_rebuilt": corruption_exact,
		"changed_content_rebuilt": changed_content_rebuilt,
		"restored_exact": restored_exact,
	}

func _inspection_without_cache_profile(value: Dictionary) -> Dictionary:
	var result: Dictionary = value.duplicate(true)
	result.erase("browser_manifest_cache_profile")
	return result

func _variant_differences(left: Variant, right: Variant, path: String) -> Array:
	var differences: Array = []
	if typeof(left) != typeof(right):
		return [{"path": path, "left_type": typeof(left), "right_type": typeof(right), "left": left, "right": right}]
	if left is Dictionary:
		for key in left.keys():
			if not right.has(key):
				differences.append({"path": "%s.%s" % [path, key], "missing_right": true})
			else:
				differences.append_array(_variant_differences(left[key], right[key], "%s.%s" % [path, key]))
		for key in right.keys():
			if not left.has(key):
				differences.append({"path": "%s.%s" % [path, key], "missing_left": true})
	elif left is Array:
		if left.size() != right.size():
			differences.append({"path": path, "left_size": left.size(), "right_size": right.size()})
		else:
			for index in left.size():
				differences.append_array(_variant_differences(left[index], right[index], "%s[%d]" % [path, index]))
	elif left != right:
		differences.append({"path": path, "left": left, "right": right, "type": typeof(left)})
	return differences

func _create_package_index_failure_fixture(source_map_path: String, source_scenario_path: String) -> Dictionary:
	var package_dir := "user://maps-folder-package-index-single-read-%d" % Time.get_ticks_usec()
	var absolute_dir := ProjectSettings.globalize_path(package_dir)
	if DirAccess.make_dir_recursive_absolute(absolute_dir) != OK:
		return {"ok": false, "error": "create_dir_failed", "package_dir": package_dir}
	var map_payload = JSON.parse_string(FileAccess.get_file_as_string(source_map_path))
	var scenario_payload = JSON.parse_string(FileAccess.get_file_as_string(source_scenario_path))
	if not (map_payload is Dictionary) or not (scenario_payload is Dictionary):
		return {"ok": false, "error": "source_parse_failed", "package_dir": package_dir}
	var paths := []
	var malformed_paths := ["%s/malformed-pair.amap" % package_dir, "%s/malformed-pair.ascenario" % package_dir]
	for path in malformed_paths:
		if not _write_fixture_text(path, "{malformed-package"):
			return {"ok": false, "error": "malformed_write_failed", "package_dir": package_dir, "paths": paths}
		paths.append(path)
	var wrong_map: Dictionary = map_payload.duplicate(true)
	var wrong_scenario: Dictionary = scenario_payload.duplicate(true)
	wrong_map["schema_id"] = "unsupported_map_package"
	wrong_scenario["schema_id"] = "unsupported_scenario_package"
	for row in [
		["%s/wrong-schema-pair.amap" % package_dir, JSON.stringify(wrong_map)],
		["%s/wrong-schema-pair.ascenario" % package_dir, JSON.stringify(wrong_scenario)],
	]:
		if not _write_fixture_text(String(row[0]), String(row[1])):
			return {"ok": false, "error": "wrong_schema_write_failed", "package_dir": package_dir, "paths": paths}
		paths.append(String(row[0]))
	var legacy_map: Dictionary = map_payload.duplicate(true)
	var legacy_scenario: Dictionary = scenario_payload.duplicate(true)
	legacy_map["legacy_json_scenario_record"] = true
	legacy_scenario["legacy_json_scenario_record"] = true
	for row in [
		["%s/legacy-pair.amap" % package_dir, JSON.stringify(legacy_map)],
		["%s/legacy-pair.ascenario" % package_dir, JSON.stringify(legacy_scenario)],
	]:
		if not _write_fixture_text(String(row[0]), String(row[1])):
			return {"ok": false, "error": "legacy_write_failed", "package_dir": package_dir, "paths": paths}
		paths.append(String(row[0]))
	var unpaired_path := "%s/unpaired-map.amap" % package_dir
	if not _write_fixture_text(unpaired_path, JSON.stringify(map_payload)):
		return {"ok": false, "error": "unpaired_write_failed", "package_dir": package_dir, "paths": paths}
	paths.append(unpaired_path)
	return {"ok": true, "package_dir": package_dir, "absolute_dir": absolute_dir, "paths": paths}

func _write_fixture_text(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.close()
	return true

func _package_warning_codes_by_stem(warnings: Array) -> Dictionary:
	var result := {}
	for warning_value in warnings:
		if warning_value is Dictionary:
			result[String(warning_value.get("package_stem", ""))] = String(warning_value.get("error_code", ""))
	return result

func _cleanup_package_index_failure_fixture(fixture: Dictionary) -> void:
	for path_value in fixture.get("paths", []):
		var path := String(path_value)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var absolute_dir := String(fixture.get("absolute_dir", ""))
	if absolute_dir != "" and DirAccess.dir_exists_absolute(absolute_dir):
		DirAccess.remove_absolute(absolute_dir)

func _session_authority_exact_ignoring_runtime_id(left, right) -> bool:
	if left == null or right == null or left.scenario_id == "" or right.scenario_id == "":
		return false
	var left_payload: Dictionary = left.to_dict()
	var right_payload: Dictionary = right.to_dict()
	_normalize_runtime_session_ids(left_payload)
	_normalize_runtime_session_ids(right_payload)
	return left_payload == right_payload

func _normalize_runtime_session_ids(value: Variant) -> void:
	if value is Dictionary:
		for key_value in value.keys():
			var key := String(key_value)
			if key == "session_id":
				value[key_value] = "selected-entry-parity"
			else:
				_normalize_runtime_session_ids(value[key_value])
	elif value is Array:
		for entry in value:
			_normalize_runtime_session_ids(entry)

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
