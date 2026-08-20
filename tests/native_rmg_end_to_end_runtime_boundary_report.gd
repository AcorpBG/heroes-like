extends Node

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const NativeRandomMapPackageSessionBridgeScript = preload("res://scripts/persistence/NativeRandomMapPackageSessionBridge.gd")
const OverworldRulesScript = preload("res://scripts/core/OverworldRules.gd")
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
	var ordinal_95 := _generate_and_validate(
		service,
		_config("medium", 72, 1, "land", "165429308", "weak", 4),
		76831,
		1283
	)
	if not bool(ordinal_95.get("ok", false)):
		_fail("Medium ordinal 95 exact-mask start boundary failed: %s" % JSON.stringify(ordinal_95))
		return
	var ordinal_95_generated: Dictionary = ordinal_95.get("generated", {})
	var ordinal_95_scenario: Variant = ordinal_95_generated.get("scenario_document", null)
	var ordinal_95_contract: Dictionary = ordinal_95_scenario.get_start_contract() if ordinal_95_scenario != null else {}
	var ordinal_95_player_start := _player_owned_start(ordinal_95_contract)
	var ordinal_95_runtime_start: Dictionary = ordinal_95_player_start.get("runtime_start_tile", {}) if ordinal_95_player_start.get("runtime_start_tile", {}) is Dictionary else {}
	var ordinal_95_adoption: Dictionary = service.convert_generated_payload(ordinal_95_generated, {"feature_gate": REPORT_ID})
	var ordinal_95_session = NativeRandomMapPackageSessionBridgeScript.build_session_from_adoption(ordinal_95_adoption)
	var ordinal_95_hero_position: Dictionary = ordinal_95_session.overworld.get("hero_position", {}) if ordinal_95_session != null and ordinal_95_session.overworld.get("hero_position", {}) is Dictionary else {}
	var ordinal_95_player_move := _execute_legal_player_step(ordinal_95_session)
	if String(ordinal_95_generated.get("final_payload_fnv1a32", "")) != "1744e025" \
			or int(ordinal_95_player_start.get("x", -1)) != 31 \
			or int(ordinal_95_player_start.get("y", -1)) != 10 \
			or ordinal_95_runtime_start.is_empty() \
			or (int(ordinal_95_runtime_start.get("x", -1)) == 31 and int(ordinal_95_runtime_start.get("y", -1)) == 10) \
			or int(ordinal_95_runtime_start.get("selection_package_road_reachable_steps", -1)) <= 0 \
			or ordinal_95_hero_position != {"x": int(ordinal_95_runtime_start.get("x", -1)), "y": int(ordinal_95_runtime_start.get("y", -1))} \
			or not bool(ordinal_95_player_move.get("ok", false)):
		_fail("Medium ordinal 95 did not preserve its payload/town anchor while moving the runtime start: %s" % JSON.stringify(ordinal_95_player_start))
		return
	var xlarge := _generate_and_validate(
		service,
		_config("homm3_extra_large", 144, 2, "normal_water", "77"),
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
		"medium_ordinal_95": ordinal_95.get("summary", {}),
		"medium_ordinal_95_town_anchor": {"x": 31, "y": 10},
		"medium_ordinal_95_runtime_start": ordinal_95_runtime_start,
		"medium_ordinal_95_hero_position": ordinal_95_hero_position,
		"medium_ordinal_95_player_move": ordinal_95_player_move,
		"xlarge": xlarge.get("summary", {}),
		"round_trip": round_trip,
		"startup": startup,
	})])
	get_tree().quit(0)

func _validate_supported_workflow_matrix(service: Variant) -> bool:
	var supported_count := 0
	for size_record in [["small", 36], ["medium", 72], ["large", 108], ["homm3_extra_large", 144]]:
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
		_config("homm3_extra_large", 144, 2, "normal_water", "77", "impossible")
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
	var expected_player_count := int(config.get("player_constraints", {}).get("player_count", 0))
	var start_bindings_ok := starts.size() == expected_player_count
	var start_binding_details := []
	for start_value in starts:
		if not (start_value is Dictionary):
			start_bindings_ok = false
			continue
		var start: Dictionary = start_value
		var placement_id := String(start.get("town_placement_id", ""))
		var town: Dictionary = map_document.get_object_by_placement_id(placement_id) if map_document != null else {}
		var hero_start: Dictionary = start.get("hero_start_tile", {}) if start.get("hero_start_tile", {}) is Dictionary else {}
		var runtime_start: Dictionary = start.get("runtime_start_tile", {}) if start.get("runtime_start_tile", {}) is Dictionary else {}
		var runtime_start_usable := _runtime_start_tile_is_usable(map_document, runtime_start)
		start_binding_details.append({
			"player_slot": start.get("player_slot", 0),
			"town_placement_id": placement_id,
			"town_kind": town.get("kind", ""),
			"town_owner_slot": town.get("owner_slot", 0),
			"start_owner_slot": start.get("owner_slot", -1),
			"hero_start": hero_start,
			"runtime_start": runtime_start,
			"tiles_match": hero_start == runtime_start,
			"runtime_start_usable": runtime_start_usable,
		})
		if placement_id == "" \
				or String(town.get("kind", "")) != "town" \
				or int(town.get("owner_slot", 0)) != int(start.get("owner_slot", -1)) \
				or hero_start.is_empty() \
				or hero_start != runtime_start \
				or not runtime_start_usable:
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
			and int(start_contract.get("start_count", -1)) == expected_player_count \
			and int(start_contract.get("start_town_count", -1)) == expected_player_count \
			and start_bindings_ok
	return {
		"ok": ok,
		"generated": generated,
		"summary": {
			"payload_bytes": generated.get("final_payload_byte_count", -1),
			"objects": generated.get("runtime_object_count", -1),
			"starts": start_contract.get("start_count", -1),
			"start_bindings_ok": start_bindings_ok,
			"start_binding_details": start_binding_details,
		},
		"map_validation": map_validation,
		"scenario_validation": scenario_validation,
	}

func _runtime_start_tile_is_usable(map_document: Variant, tile: Dictionary) -> bool:
	if map_document == null or tile.is_empty():
		return false
	var x := int(tile.get("x", -1))
	var y := int(tile.get("y", -1))
	var level := int(tile.get("level", -1))
	if x < 0 or y < 0 or level < 0 or x >= int(map_document.get_width()) or y >= int(map_document.get_height()) or level >= int(map_document.get_level_count()):
		return false
	var terrain_layers: Dictionary = map_document.get_terrain_layers()
	var terrain: Dictionary = terrain_layers.get("terrain", {}) if terrain_layers.get("terrain", {}) is Dictionary else {}
	var levels: Array = terrain.get("levels", []) if terrain.get("levels", []) is Array else []
	if level >= levels.size() or not (levels[level] is PackedInt32Array):
		return false
	var terrain_values: PackedInt32Array = levels[level]
	var terrain_code := int(terrain_values[y * int(map_document.get_width()) + x]) & 0x3f
	if terrain_code == 8 or terrain_code == 9:
		return false
	var roads: Array = terrain_layers.get("roads", []) if terrain_layers.get("roads", []) is Array else []
	for road_value in roads:
		if not (road_value is Dictionary):
			continue
		var road_tiles: Array = road_value.get("tiles", []) if road_value.get("tiles", []) is Array else []
		for road_tile_value in road_tiles:
			if road_tile_value is Dictionary and int(road_tile_value.get("x", -2)) == x and int(road_tile_value.get("y", -2)) == y and int(road_tile_value.get("level", -2)) == level:
				return false
	for object_index in range(int(map_document.get_object_count())):
		var object: Dictionary = map_document.get_object_by_index(object_index)
		for field in ["package_block_tiles", "package_visit_tiles"]:
			var cells: Array = object.get(field, []) if object.get(field, []) is Array else []
			for cell_value in cells:
				if cell_value is Dictionary and int(cell_value.get("x", -2)) == x and int(cell_value.get("y", -2)) == y and int(cell_value.get("level", -2)) == level:
					return false
	return String(tile.get("selection_source", "")) != ""

func _player_owned_start(start_contract: Dictionary) -> Dictionary:
	var starts: Array = start_contract.get("player_starts", []) if start_contract.get("player_starts", []) is Array else []
	for start_value in starts:
		if start_value is Dictionary and String(start_value.get("owner", "")) == "player":
			return start_value
	return {}

func _execute_legal_player_step(session: Variant) -> Dictionary:
	if session == null:
		return {"ok": false, "reason": "missing_session"}
	var start := OverworldRulesScript.hero_position(session)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var target := start + Vector2i(dx, dy)
			if OverworldRulesScript.tile_is_blocked(session, target.x, target.y) \
					or OverworldRulesScript.tile_has_route_interaction(session, target.x, target.y) \
					or OverworldRulesScript.tile_step_cuts_blocked_corner(session, start, target):
				continue
			var move: Dictionary = OverworldRulesScript.try_move(session, dx, dy)
			var finish := OverworldRulesScript.hero_position(session)
			if bool(move.get("ok", false)) and finish != start:
				return {"ok": true, "from": {"x": start.x, "y": start.y}, "to": {"x": finish.x, "y": finish.y}, "result": move}
	return {"ok": false, "reason": "no_executable_neighbor", "from": {"x": start.x, "y": start.y}}

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
	monster_strength: String = "weak",
	player_count: int = 2
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
			"computer_count": player_count - 1,
			"player_count": player_count,
			"human_team_count": 1,
			"computer_team_count": 0,
		},
	}

func _fail(message: String) -> void:
	push_error("%s: %s" % [REPORT_ID, message])
	get_tree().quit(1)
