extends Node

const REPORT_ID := "MAP_EDITOR_PACKAGE_SAVE_COPY_REPORT"
const SCENARIOS_PATH := "res://content/scenarios.json"
const TERRAIN_LAYERS_PATH := "res://content/terrain_layers.json"

var _test_dir := ""

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not ClassDB.class_exists("MapPackageService"):
		_fail("Native MapPackageService is unavailable.")
		return
	_test_dir = "user://tests/map_editor_save_copy_%s" % Time.get_ticks_msec()
	var source_stem := "source-editor-package"
	var source_map_path := "%s/%s.amap" % [_test_dir, source_stem]
	var source_scenario_path := "%s/%s.ascenario" % [_test_dir, source_stem]
	var authored_scenario_bytes := FileAccess.get_file_as_bytes(SCENARIOS_PATH)
	var authored_terrain_bytes := FileAccess.get_file_as_bytes(TERRAIN_LAYERS_PATH)
	var service: Variant = ClassDB.instantiate("MapPackageService")
	var source_result := _write_source_fixture(service, source_map_path, source_scenario_path)
	if not bool(source_result.get("ok", false)):
		_fail(String(source_result.get("message", "Could not write source fixture.")))
		return
	var source_map_bytes := FileAccess.get_file_as_bytes(source_map_path)
	var source_scenario_bytes := FileAccess.get_file_as_bytes(source_scenario_path)

	var shell = load("res://scenes/editor/MapEditorShell.tscn").instantiate()
	shell.set("validation_skip_initial_package_index", true)
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	var loaded: Dictionary = shell.call("validation_load_package_from_directory", _test_dir, source_stem)
	if not bool(loaded.get("ok", false)):
		_fail("Editor could not load the package-backed source fixture: %s" % JSON.stringify(loaded.get("package_index", {})))
		return
	if bool(loaded.get("save_copy_button_disabled", true)):
		_fail("Save Copy remained disabled for a validated package working copy.")
		return
	var terrain_edit: Dictionary = shell.call("validation_paint_terrain", 0, 0, "forest")
	var road_edit: Dictionary = shell.call("validation_toggle_road", 0, 0)
	var start_edit: Dictionary = shell.call("validation_set_hero_start", 1, 0)
	if not bool(terrain_edit.get("ok", false)) or not bool(road_edit.get("ok", false)) or not bool(start_edit.get("ok", false)):
		_fail("Could not apply focused editor changes before Save Copy.")
		return

	var first: Dictionary = shell.call("validation_save_copy", _test_dir, "saved-editor-copy")
	if not _assert_save_result(first, "saved-editor-copy"):
		return
	var first_map_bytes := FileAccess.get_file_as_bytes(String(first.get("map_path", "")))
	var first_scenario_bytes := FileAccess.get_file_as_bytes(String(first.get("scenario_path", "")))
	var first_pair := _assert_saved_pair(service, first)
	if not bool(first_pair.get("ok", false)):
		_fail(String(first_pair.get("message", "First saved pair validation failed.")))
		return
	var first_snapshot: Dictionary = shell.call("validation_snapshot")
	if bool(first_snapshot.get("dirty", true)) or String(first_snapshot.get("editor_source_map_path", "")) != String(first.get("map_path", "")):
		_fail("First Save Copy did not adopt a clean package-backed baseline.")
		return

	var second: Dictionary = shell.call("validation_save_copy", _test_dir, "saved-editor-copy")
	if not _assert_save_result(second, "saved-editor-copy-2"):
		return
	if FileAccess.get_file_as_bytes(String(first.get("map_path", ""))) != first_map_bytes or FileAccess.get_file_as_bytes(String(first.get("scenario_path", ""))) != first_scenario_bytes:
		_fail("Second Save Copy overwrote the first saved package pair.")
		return
	var second_pair := _assert_saved_pair(service, second)
	if not bool(second_pair.get("ok", false)):
		_fail("Second saved package pair did not reload with the edited state: %s" % String(second_pair.get("message", "")))
		return

	if FileAccess.get_file_as_bytes(source_map_path) != source_map_bytes or FileAccess.get_file_as_bytes(source_scenario_path) != source_scenario_bytes:
		_fail("Save Copy mutated the source package pair.")
		return
	if FileAccess.get_file_as_bytes(SCENARIOS_PATH) != authored_scenario_bytes or FileAccess.get_file_as_bytes(TERRAIN_LAYERS_PATH) != authored_terrain_bytes:
		_fail("Save Copy mutated authored JSON content.")
		return
	var skirmish_index: Dictionary = ScenarioSelectRules.maps_folder_package_index({"package_dir": _test_dir})
	var editor_index: Dictionary = ScenarioSelectRules.maps_folder_package_index({
		"package_dir": _test_dir,
		"include_non_launchable_generated_packages": true,
		"consumer": "map_editor",
	})
	if not skirmish_index.get("entries", []).is_empty():
		_fail("Editor-authored copies were exposed through the skirmish package index.")
		return
	if editor_index.get("entries", []).size() != 3:
		_fail("Editor package index did not retain source plus two saved copies: %s" % JSON.stringify(editor_index))
		return
	var invalid_session = shell.get("_session")
	invalid_session.overworld["map"][0][0] = "missing_editor_terrain"
	var failed: Dictionary = shell.call("validation_save_copy", _test_dir, "must-fail")
	if bool(failed.get("ok", true)) or String(failed.get("error_code", "")) != "draft_validation_failed":
		_fail("Invalid Save Copy draft did not fail closed: %s" % JSON.stringify(failed))
		return
	if FileAccess.file_exists("%s/must-fail.amap" % _test_dir) or FileAccess.file_exists("%s/must-fail.ascenario" % _test_dir):
		_fail("Failed Save Copy left a partial package output.")
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"source_package_unchanged": true,
		"authored_json_unchanged": true,
		"first_stem": first.get("package_stem", ""),
		"second_stem": second.get("package_stem", ""),
		"object_count": first.get("object_count", 0),
		"player_slot_count": first.get("player_slot_count", 0),
		"editor_index_count": editor_index.get("entries", []).size(),
		"skirmish_index_count": skirmish_index.get("entries", []).size(),
		"failed_write_closed": true,
	})])
	_cleanup()
	get_tree().quit(0)

func _write_source_fixture(service: Variant, map_path: String, scenario_path: String) -> Dictionary:
	var scenario := ContentService.get_authored_scenario("river-pass")
	var terrain_layers := ContentService.get_terrain_layers_for_scenario("river-pass")
	if scenario.is_empty() or terrain_layers.is_empty():
		return {"ok": false, "message": "River Pass fixture records are unavailable."}
	scenario = scenario.duplicate(true)
	var towns: Array = scenario.get("towns", [])
	var first_town: Dictionary = towns[0].duplicate(true)
	first_town["opaque_town_fixture_field"] = {"preserve": "town-exactly"}
	towns[0] = first_town
	scenario["towns"] = towns
	scenario["map_objects"] = [{
		"placement_id": "editor-copy-decor-1",
		"kind": "decorative_obstacle",
		"native_record_kind": "decorative_obstacle",
		"object_id": "object_editor_copy_stone",
		"object_family_id": "decorative_obstacle",
		"x": 0,
		"y": 0,
		"level": 0,
		"opaque_fixture_field": {"preserve": "exactly"},
	}]
	scenario["player_slots"] = [
		{"slot": 1, "owner": "player", "human": true, "computer": false, "faction_id": "faction_embercourt", "team": 7},
		{"slot": 2, "owner": "enemy", "human": false, "computer": true, "faction_id": "faction_mireclaw", "team": 9},
	]
	var conversion: Dictionary = service.convert_legacy_scenario_record(scenario, terrain_layers, {
		"map_id": "source-editor-package-map",
		"scenario_id": source_stem_from_path(scenario_path),
	})
	if not bool(conversion.get("ok", false)):
		return {"ok": false, "message": "Source conversion failed: %s" % JSON.stringify(conversion)}
	var map_document: Variant = conversion.get("map_document", null)
	var scenario_document: Variant = conversion.get("scenario_document", null)
	var converted_town: Dictionary = map_document.get_object_by_placement_id("riverwatch_hold")
	if converted_town.get("opaque_town_fixture_field", {}) != {"preserve": "town-exactly"}:
		return {"ok": false, "message": "Source conversion dropped opaque town fields: %s" % JSON.stringify(converted_town)}
	var map_save: Dictionary = service.save_map_package(map_document, map_path, {"path_policy": "editor_save_copy_fixture", "return_package": false})
	var map_load: Dictionary = service.load_map_package(map_path)
	if not bool(map_save.get("ok", false)) or not bool(map_load.get("ok", false)):
		return {"ok": false, "message": "Source map package write failed."}
	var reloaded_town: Dictionary = map_load.get("map_document", null).get_object_by_placement_id("riverwatch_hold")
	if reloaded_town.get("opaque_town_fixture_field", {}) != {"preserve": "town-exactly"}:
		return {"ok": false, "message": "Source package reload dropped opaque town fields: %s" % JSON.stringify(reloaded_town)}
	scenario_document.configure({
		"scenario_id": scenario_document.get_scenario_id(),
		"scenario_hash": scenario_document.get_scenario_hash(),
		"map_ref": map_load.get("map_ref", {}),
		"selection": scenario_document.get_selection(),
		"player_slots": scenario_document.get_player_slots(),
		"objectives": scenario_document.get_objectives(),
		"script_hooks": scenario_document.get_script_hooks(),
		"enemy_factions": scenario_document.get_enemy_factions(),
		"start_contract": scenario_document.get_start_contract(),
	})
	var scenario_save: Dictionary = service.save_scenario_package(scenario_document, scenario_path, {"path_policy": "editor_save_copy_fixture", "return_package": false})
	return {"ok": bool(scenario_save.get("ok", false)), "message": JSON.stringify(scenario_save)}

func _assert_save_result(result: Dictionary, expected_stem: String) -> bool:
	if not bool(result.get("ok", false)) or String(result.get("package_stem", "")) != expected_stem:
		_fail("Save Copy result mismatch: %s" % JSON.stringify(result))
		return false
	if not bool(result.get("editor_inspection_only", false)) or bool(result.get("authored_json_writeback", true)):
		_fail("Save Copy lost its editor-only/no-writeback boundary: %s" % JSON.stringify(result))
		return false
	if not FileAccess.file_exists(String(result.get("map_path", ""))) or not FileAccess.file_exists(String(result.get("scenario_path", ""))):
		_fail("Save Copy did not write both package files.")
		return false
	return true

func _assert_saved_pair(service: Variant, result: Dictionary) -> Dictionary:
	var map_load: Dictionary = service.load_map_package(String(result.get("map_path", "")))
	var scenario_load: Dictionary = service.load_scenario_package(String(result.get("scenario_path", "")))
	if not bool(map_load.get("ok", false)) or not bool(scenario_load.get("ok", false)):
		return {"ok": false, "message": "Saved pair did not reload."}
	var map_document: Variant = map_load.get("map_document", null)
	var scenario_document: Variant = scenario_load.get("scenario_document", null)
	if not bool(service.validate_map_document(map_document).get("ok", false)) or not bool(service.validate_scenario_document(scenario_document, map_document).get("ok", false)):
		return {"ok": false, "message": "Saved pair failed structural validation."}
	var decor: Dictionary = map_document.get_object_by_placement_id("editor-copy-decor-1")
	if decor.get("opaque_fixture_field", {}) != {"preserve": "exactly"}:
		return {"ok": false, "message": "Standalone decorative object fields were not preserved."}
	var town: Dictionary = map_document.get_object_by_placement_id("riverwatch_hold")
	if town.get("opaque_town_fixture_field", {}) != {"preserve": "town-exactly"}:
		return {"ok": false, "message": "Editable town object fields were not preserved: %s" % JSON.stringify(town)}
	if map_document.get_object_count() != 21:
		return {"ok": false, "message": "Saved object topology changed: %d" % map_document.get_object_count()}
	var terrain_ids: Array = map_document.get_terrain_layers().get("terrain_id_by_code", [])
	var terrain_codes: PackedInt32Array = map_document.get_tile_layer_u16("terrain", 0)
	if terrain_codes.is_empty() or String(terrain_ids[int(terrain_codes[0])]) != "forest":
		return {"ok": false, "message": "Saved terrain edit was not preserved."}
	var start: Dictionary = scenario_document.get_start_contract()
	if int(start.get("x", -1)) != 1 or int(start.get("y", -1)) != 0:
		return {"ok": false, "message": "Saved hero start edit was not preserved."}
	var slots: Array = scenario_document.get_player_slots()
	if slots.size() != 2 or int(slots[0].get("team", -1)) != 7 or int(slots[1].get("team", -1)) != 9:
		return {"ok": false, "message": "Explicit player slots were not preserved."}
	return {"ok": true}

func source_stem_from_path(path: String) -> String:
	return path.get_file().get_basename()

func _cleanup() -> void:
	if _test_dir == "":
		return
	var dir := DirAccess.open(_test_dir)
	if dir != null:
		dir.list_dir_begin()
		var filename := dir.get_next()
		while filename != "":
			if not dir.current_is_dir():
				DirAccess.remove_absolute(ProjectSettings.globalize_path("%s/%s" % [_test_dir, filename]))
			filename = dir.get_next()
		dir.list_dir_end()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_test_dir))

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	_cleanup()
	get_tree().quit(1)
