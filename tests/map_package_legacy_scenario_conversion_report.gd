extends Node

const REPORT_ID := "MAP_PACKAGE_LEGACY_SCENARIO_CONVERSION_REPORT"
const SCENARIOS_PATH := "res://content/scenarios.json"
const TERRAIN_LAYERS_PATH := "res://content/terrain_layers.json"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not ClassDB.class_exists("MapPackageService"):
		_fail("Native MapPackageService is unavailable.")
		return
	var source_scenario_bytes := FileAccess.get_file_as_bytes(SCENARIOS_PATH)
	var source_terrain_bytes := FileAccess.get_file_as_bytes(TERRAIN_LAYERS_PATH)
	var scenario := ContentService.get_authored_scenario("river-pass")
	var terrain_layers := ContentService.get_terrain_layers_for_scenario("river-pass")
	if scenario.is_empty() or terrain_layers.is_empty():
		_fail("River Pass authored source records are unavailable.")
		return

	var service: Variant = ClassDB.instantiate("MapPackageService")
	if not service.get_capabilities().has("legacy_scenario_record_conversion"):
		_fail("Native service does not advertise legacy scenario conversion.")
		return
	var options := {
		"map_id": "editor_river_pass_copy_map",
		"scenario_id": "editor_river_pass_copy",
	}
	var conversion: Dictionary = service.convert_legacy_scenario_record(scenario, terrain_layers, options)
	if not bool(conversion.get("ok", false)):
		_fail("River Pass conversion failed: %s" % JSON.stringify(conversion))
		return
	if String(conversion.get("conversion_policy", "")) != "typed_documents_no_authored_json_writeback":
		_fail("Conversion did not expose the no-writeback policy: %s" % JSON.stringify(conversion))
		return
	var map_document: Variant = conversion.get("map_document", null)
	var scenario_document: Variant = conversion.get("scenario_document", null)
	if map_document == null or scenario_document == null:
		_fail("Conversion did not return typed documents.")
		return
	if map_document.get_map_id() != options.map_id or scenario_document.get_scenario_id() != options.scenario_id:
		_fail("Converted document identities are incorrect.")
		return
	if map_document.get_source_kind() != "authored_legacy_scenario_conversion":
		_fail("Converted map source kind is incorrect.")
		return
	if map_document.get_width() != 9 or map_document.get_height() != 5 or map_document.get_level_count() != 1 or map_document.get_tile_count() != 45:
		_fail("Converted map dimensions are incorrect.")
		return
	if not _assert_terrain_exact(map_document, scenario):
		return
	if not _assert_objects_exact(map_document, scenario):
		return
	if not _assert_scenario_exact(scenario_document, scenario, map_document):
		return
	if JSON.stringify(map_document.get_terrain_layers().get("roads", [])) != JSON.stringify(terrain_layers.get("roads", [])):
		_fail("Converted roads differ from the authored terrain-layer record.")
		return

	var map_validation: Dictionary = service.validate_map_document(map_document)
	var scenario_validation: Dictionary = service.validate_scenario_document(scenario_document, map_document)
	if not bool(map_validation.get("ok", false)) or not bool(scenario_validation.get("ok", false)):
		_fail("Converted typed documents failed validation: %s / %s" % [JSON.stringify(map_validation), JSON.stringify(scenario_validation)])
		return
	var repeated: Dictionary = service.convert_legacy_scenario_record(scenario, terrain_layers, options)
	if not bool(repeated.get("ok", false)):
		_fail("Determinism conversion rerun failed: %s" % JSON.stringify(repeated))
		return
	if repeated.get("map_document").get_map_hash() != map_document.get_map_hash() or repeated.get("scenario_document").get_scenario_hash() != scenario_document.get_scenario_hash():
		_fail("Repeated conversion produced different document hashes.")
		return

	if not _assert_failure(service, _ragged_scenario(scenario), terrain_layers, options, "ragged_map_rows"):
		return
	var mismatched_layers := terrain_layers.duplicate(true)
	mismatched_layers["id"] = "not-river-pass"
	if not _assert_failure(service, scenario, mismatched_layers, options, "terrain_scenario_id_mismatch"):
		return
	var out_of_bounds := scenario.duplicate(true)
	out_of_bounds["towns"][0]["x"] = int(scenario.get("map_size", {}).get("width", 0))
	if not _assert_failure(service, out_of_bounds, terrain_layers, options, "object_out_of_bounds"):
		return
	var duplicate_placement := scenario.duplicate(true)
	duplicate_placement["resource_nodes"][0]["placement_id"] = duplicate_placement["towns"][0]["placement_id"]
	if not _assert_failure(service, duplicate_placement, terrain_layers, options, "duplicate_placement_id"):
		return

	var package_dir := "user://tests/legacy_scenario_conversion_%s" % Time.get_ticks_msec()
	var map_path := "%s/river_pass_copy.amap" % package_dir
	var scenario_path := "%s/river_pass_copy.ascenario" % package_dir
	var save_options := {"path_policy": "editor_user_maps_copy"}
	var map_save: Dictionary = service.save_map_package(map_document, map_path, save_options)
	var map_load: Dictionary = service.load_map_package(map_path)
	if not bool(map_save.get("ok", false)) or not bool(map_load.get("ok", false)):
		_fail("Converted map package round trip failed: %s / %s" % [JSON.stringify(map_save), JSON.stringify(map_load)])
		return
	var loaded_map: Variant = map_load.get("map_document", null)
	if loaded_map == null or loaded_map.get_map_hash() != map_document.get_map_hash() or loaded_map.get_object_count() != map_document.get_object_count():
		_fail("Loaded map package did not preserve the converted document.")
		return
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
	var scenario_save: Dictionary = service.save_scenario_package(scenario_document, scenario_path, save_options)
	var scenario_load: Dictionary = service.load_scenario_package(scenario_path)
	if not bool(scenario_save.get("ok", false)) or not bool(scenario_load.get("ok", false)):
		_fail("Converted scenario package round trip failed: %s / %s" % [JSON.stringify(scenario_save), JSON.stringify(scenario_load)])
		return
	var loaded_scenario: Variant = scenario_load.get("scenario_document", null)
	if loaded_scenario == null or loaded_scenario.get_scenario_hash() != scenario_document.get_scenario_hash():
		_fail("Loaded scenario package did not preserve the converted document.")
		return
	if String(loaded_scenario.get_map_ref().get("map_hash", "")) != loaded_map.get_map_hash():
		_fail("Loaded scenario package does not reference the loaded map package.")
		return
	for package in [map_save.get("package", {}), scenario_save.get("package", {})]:
		if bool(package.get("authored_content_writeback", true)) or bool(package.get("legacy_json_scenario_record", true)):
			_fail("Saved package violated the authored no-writeback boundary: %s" % JSON.stringify(package))
			return
		if String(package.get("path_policy", "")) != "editor_user_maps_copy":
			_fail("Saved package did not preserve the editor copy path policy.")
			return

	DirAccess.remove_absolute(scenario_path)
	DirAccess.remove_absolute(map_path)
	DirAccess.remove_absolute(package_dir)
	if FileAccess.get_file_as_bytes(SCENARIOS_PATH) != source_scenario_bytes or FileAccess.get_file_as_bytes(TERRAIN_LAYERS_PATH) != source_terrain_bytes:
		_fail("Conversion or package persistence mutated authored JSON.")
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"map_hash": map_document.get_map_hash(),
		"scenario_hash": scenario_document.get_scenario_hash(),
		"terrain_cell_count": map_document.get_tile_count(),
		"object_count": map_document.get_object_count(),
		"road_count": terrain_layers.get("roads", []).size(),
		"negative_cases": 4,
		"package_round_trip": true,
		"authored_source_unchanged": true,
	})])
	get_tree().quit(0)

func _assert_terrain_exact(map_document: Variant, scenario: Dictionary) -> bool:
	var layers: Dictionary = map_document.get_terrain_layers()
	var terrain_ids: Array = layers.get("terrain_id_by_code", [])
	var codes: PackedInt32Array = map_document.get_tile_layer_u16("terrain", 0)
	if codes.size() != map_document.get_tile_count():
		_fail("Converted terrain layer has an incorrect cell count.")
		return false
	var map_rows: Array = scenario.get("map", [])
	for y in range(map_rows.size()):
		for x in range(map_rows[y].size()):
			var code := int(codes[y * map_document.get_width() + x])
			if code < 0 or code >= terrain_ids.size() or String(terrain_ids[code]) != String(map_rows[y][x]):
				_fail("Converted terrain differs at (%d, %d)." % [x, y])
				return false
	return true

func _assert_objects_exact(map_document: Variant, scenario: Dictionary) -> bool:
	var expected_count := 0
	for key in ["towns", "resource_nodes", "artifact_nodes", "encounters"]:
		expected_count += scenario.get(key, []).size()
	if map_document.get_object_count() != expected_count:
		_fail("Converted object count is %d, expected %d." % [map_document.get_object_count(), expected_count])
		return false
	for family in [
		{"key": "towns", "kind": "town"},
		{"key": "resource_nodes", "kind": "resource_site"},
		{"key": "artifact_nodes", "kind": "artifact"},
		{"key": "encounters", "kind": "encounter"},
	]:
		for authored in scenario.get(family.key, []):
			var converted: Dictionary = map_document.get_object_by_placement_id(String(authored.get("placement_id", "")))
			if converted.is_empty() or String(converted.get("kind", "")) != family.kind:
				_fail("Converted object family is missing %s." % String(authored.get("placement_id", "")))
				return false
			for key in authored.keys():
				if JSON.stringify(converted.get(key)) != JSON.stringify(authored.get(key)):
					_fail("Converted object %s changed authored field %s." % [authored.get("placement_id", ""), key])
					return false
	return true

func _assert_scenario_exact(scenario_document: Variant, scenario: Dictionary, map_document: Variant) -> bool:
	for pair in [
		[scenario_document.get_selection(), scenario.get("selection", {})],
		[scenario_document.get_objectives(), scenario.get("objectives", {})],
		[scenario_document.get_script_hooks(), scenario.get("script_hooks", [])],
		[scenario_document.get_enemy_factions(), scenario.get("enemy_factions", [])],
	]:
		if JSON.stringify(pair[0]) != JSON.stringify(pair[1]):
			_fail("Converted scenario field differs from its authored record.")
			return false
	var start_contract: Dictionary = scenario_document.get_start_contract()
	for key in ["x", "y"]:
		if start_contract.get(key) != scenario.get("start", {}).get(key):
			_fail("Converted start coordinate %s differs." % key)
			return false
	for key in ["hero_id", "player_army_id", "player_faction_id", "hero_starts", "starting_resources"]:
		if JSON.stringify(start_contract.get(key)) != JSON.stringify(scenario.get(key)):
			_fail("Converted start contract field %s differs." % key)
			return false
	var map_ref: Dictionary = scenario_document.get_map_ref()
	if map_ref.get("map_id") != map_document.get_map_id() or map_ref.get("map_hash") != map_document.get_map_hash():
		_fail("Converted scenario map reference is incorrect.")
		return false
	return true

func _ragged_scenario(scenario: Dictionary) -> Dictionary:
	var result := scenario.duplicate(true)
	result["map"][0].remove_at(result["map"][0].size() - 1)
	return result

func _assert_failure(service: Variant, scenario: Dictionary, terrain_layers: Dictionary, options: Dictionary, expected_code: String) -> bool:
	var result: Dictionary = service.convert_legacy_scenario_record(scenario, terrain_layers, options)
	if bool(result.get("ok", true)) or String(result.get("error_code", "")) != expected_code:
		_fail("Expected conversion failure %s, got %s." % [expected_code, JSON.stringify(result)])
		return false
	return true

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
