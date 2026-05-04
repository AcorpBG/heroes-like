extends Node

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")

const REPORT_ID := "NATIVE_RANDOM_MAP_GUARD_REWARD_PACKAGE_ADOPTION_REPORT"
const REPORT_SCHEMA_ID := "native_random_map_guard_reward_package_adoption_report_v1"

const CASES := [
	{
		"id": "small_frontier_guard_package_seed_a",
		"seed": "native-guard-package-small-a",
		"template_id": "frontier_spokes_v1",
		"profile_id": "frontier_spokes_profile_v1",
		"size_class_id": "homm3_small",
		"player_count": 3,
	},
	{
		"id": "medium_translated_024_guard_package_seed_a",
		"seed": "native-guard-package-medium-a",
		"template_id": "translated_rmg_template_024_v1",
		"profile_id": "translated_rmg_profile_024_v1",
		"size_class_id": "homm3_medium",
		"player_count": 4,
	},
	{
		"id": "large_translated_042_guard_package_seed_a",
		"seed": "native-guard-package-large-a",
		"template_id": "translated_rmg_template_042_v1",
		"profile_id": "translated_rmg_profile_042_v1",
		"size_class_id": "homm3_large",
		"player_count": 4,
	},
	{
		"id": "xl_translated_043_guard_package_seed_b",
		"seed": "native-guard-package-xl-b",
		"template_id": "translated_rmg_template_043_v1",
		"profile_id": "translated_rmg_profile_043_v1",
		"size_class_id": "homm3_extra_large",
		"player_count": 8,
	},
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
	var capabilities: PackedStringArray = service.get_capabilities()
	if not capabilities.has("native_random_map_guard_reward_package_adoption"):
		_fail("Native capability list missed guard/reward package adoption: %s" % JSON.stringify(Array(capabilities)))
		return

	var summaries := []
	var aggregate := {
		"reward_count": 0,
		"valuable_reward_count": 0,
		"guarded_valuable_reward_count": 0,
		"high_value_reward_count": 0,
		"medium_value_reward_count": 0,
		"medium_guarded_reward_count": 0,
		"guard_count": 0,
		"package_block_tile_count": 0,
		"package_visit_tile_count": 0,
	}
	for case_record in CASES:
		var summary := _run_case(service, case_record)
		if summary.is_empty():
			return
		summaries.append(summary)
		for key in aggregate.keys():
			aggregate[key] = int(aggregate.get(key, 0)) + int(summary.get(key, 0))

	if int(aggregate.get("guarded_valuable_reward_count", 0)) <= 0:
		_fail("Broad package sample did not expose any guarded valuable reward records: %s" % JSON.stringify(aggregate))
		return
	if int(aggregate.get("high_value_reward_count", 0)) <= 0:
		_fail("Broad package sample did not include high-value rewards: %s" % JSON.stringify(aggregate))
		return
	if int(aggregate.get("medium_value_reward_count", 0)) >= 4 and int(aggregate.get("medium_guarded_reward_count", 0)) <= 0:
		_fail("Broad package sample included medium rewards but no guarded medium reward package links: %s" % JSON.stringify(aggregate))
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"schema_id": REPORT_SCHEMA_ID,
		"ok": true,
		"binding_kind": metadata.get("binding_kind", ""),
		"native_extension_loaded": metadata.get("native_extension_loaded", false),
		"case_count": summaries.size(),
		"cases": summaries,
		"aggregate": aggregate,
		"remaining_gap": "Generated package/editor surfaces now retain explicit guard/reward links and body/visit/block masks after save/load. This is not full HoMM3-re parity, not exact placement/asset parity, and does not change the native generation call path.",
	})])
	get_tree().quit(0)

func _run_case(service: Variant, case_record: Dictionary) -> Dictionary:
	var case_id := String(case_record.get("id", "case"))
	var config := ScenarioSelectRulesScript.build_random_map_player_config(
		String(case_record.get("seed", "")),
		String(case_record.get("template_id", "")),
		String(case_record.get("profile_id", "")),
		int(case_record.get("player_count", 4)),
		"land",
		false,
		String(case_record.get("size_class_id", "homm3_small"))
	)
	var generated: Dictionary = service.generate_random_map(config, {"startup_path": "guard_reward_package_report"})
	if not bool(generated.get("ok", false)):
		_fail("%s native generation failed: %s" % [case_id, JSON.stringify(generated)])
		return {}
	if String(generated.get("validation_status", "")) != "pass":
		_fail("%s native validation failed: %s" % [case_id, JSON.stringify(generated.get("validation_report", {}))])
		return {}

	var road_cell_count := int(generated.get("road_network", {}).get("road_cell_count", 0))
	var generated_objects: Array = generated.get("object_placements", []) if generated.get("object_placements", []) is Array else []
	var generated_guards: Array = generated.get("guard_records", []) if generated.get("guard_records", []) is Array else []
	var guarded_reward_ids := _guarded_reward_ids(generated_objects, generated_guards)
	var adoption: Dictionary = service.convert_generated_payload(generated, {
		"feature_gate": "native_rmg_guard_reward_package_adoption_report",
		"session_save_version": 9,
		"scenario_id": "native_guard_reward_package_%s" % case_id,
	})
	if not bool(adoption.get("ok", false)):
		_fail("%s convert_generated_payload failed: %s" % [case_id, JSON.stringify(adoption)])
		return {}
	var adoption_report: Dictionary = adoption.get("report", {}) if adoption.get("report", {}) is Dictionary else {}
	var adoption_summary: Dictionary = adoption_report.get("guard_reward_package_adoption", {}) if adoption_report.get("guard_reward_package_adoption", {}) is Dictionary else {}
	if String(adoption_summary.get("status", "")) != "pass":
		_fail("%s guard/reward package adoption summary did not pass: %s" % [case_id, JSON.stringify(adoption_summary)])
		return {}
	var map_document: Variant = adoption.get("map_document", null)
	if map_document == null:
		_fail("%s adoption missed map_document." % case_id)
		return {}

	var map_path := "user://native_guard_reward_package_%s.amap" % case_id
	var save_result: Dictionary = service.save_map_package(map_document, map_path)
	if not bool(save_result.get("ok", false)):
		_fail("%s save_map_package failed: %s" % [case_id, JSON.stringify(save_result)])
		return {}
	var load_result: Dictionary = service.load_map_package(map_path)
	DirAccess.remove_absolute(map_path)
	if not bool(load_result.get("ok", false)):
		_fail("%s load_map_package failed: %s" % [case_id, JSON.stringify(load_result)])
		return {}
	var loaded_document: Variant = load_result.get("map_document", null)
	if loaded_document == null:
		_fail("%s load result missed map_document." % case_id)
		return {}

	var surface := _loaded_surface_summary(case_id, loaded_document, guarded_reward_ids, road_cell_count)
	if surface.is_empty():
		return {}
	return {
		"id": case_id,
		"template_id": String(case_record.get("template_id", "")),
		"size_class_id": String(case_record.get("size_class_id", "")),
		"road_cell_count": road_cell_count,
		"generated_guarded_reward_count": guarded_reward_ids.size(),
		"adoption_summary": adoption_summary,
		"loaded_surface": surface,
		"reward_count": int(surface.get("reward_count", 0)),
		"valuable_reward_count": int(surface.get("valuable_reward_count", 0)),
		"guarded_valuable_reward_count": int(surface.get("guarded_valuable_reward_count", 0)),
		"high_value_reward_count": int(surface.get("high_value_reward_count", 0)),
		"medium_value_reward_count": int(surface.get("medium_value_reward_count", 0)),
		"medium_guarded_reward_count": int(surface.get("medium_guarded_reward_count", 0)),
		"guard_count": int(surface.get("guard_count", 0)),
		"package_block_tile_count": int(surface.get("package_block_tile_count", 0)),
		"package_visit_tile_count": int(surface.get("package_visit_tile_count", 0)),
	}

func _guarded_reward_ids(objects: Array, guards: Array) -> Dictionary:
	var rewards := {}
	for object in objects:
		if object is Dictionary and String(object.get("kind", "")) == "reward_reference":
			rewards[String(object.get("placement_id", ""))] = object
	var result := {}
	for guard in guards:
		if not (guard is Dictionary) or String(guard.get("protected_target_type", "")) != "object_placement":
			continue
		var protected_id := String(guard.get("protected_object_placement_id", ""))
		if rewards.has(protected_id):
			result[protected_id] = true
	return result

func _loaded_surface_summary(case_id: String, map_document: Variant, guarded_reward_ids: Dictionary, expected_road_cells: int) -> Dictionary:
	var terrain_layers: Dictionary = map_document.get_terrain_layers()
	var roads: Array = terrain_layers.get("roads", []) if terrain_layers.get("roads", []) is Array else []
	var road_cells := {}
	var road_cell_total := 0
	for road in roads:
		if not (road is Dictionary):
			continue
		var cells: Array = road.get("cells", road.get("tiles", [])) if road.get("cells", road.get("tiles", [])) is Array else []
		road_cell_total += cells.size()
		for cell in cells:
			if cell is Dictionary:
				road_cells[_point_key(int(cell.get("x", 0)), int(cell.get("y", 0)))] = true
	if road_cell_total < expected_road_cells:
		_fail("%s loaded package dropped road/path cells: expected %d got %d" % [case_id, expected_road_cells, road_cell_total])
		return {}

	var reward_count := 0
	var valuable_reward_count := 0
	var guarded_valuable_reward_count := 0
	var high_value_reward_count := 0
	var medium_value_reward_count := 0
	var medium_guarded_reward_count := 0
	var guard_count := 0
	var package_body_tile_count := 0
	var package_block_tile_count := 0
	var package_visit_tile_count := 0
	var loaded_guarded_reward_ids := {}
	var non_guard_road_block_conflicts := []
	for index in range(int(map_document.get_object_count())):
		var object: Dictionary = map_document.get_object_by_index(index)
		var kind := String(object.get("kind", ""))
		package_body_tile_count += int(object.get("package_body_tile_count", 0))
		package_block_tile_count += int(object.get("package_block_tile_count", 0))
		package_visit_tile_count += int(object.get("package_visit_tile_count", 0))
		if String(object.get("package_pathing_materialization_state", "")) != "body_visit_block_masks_materialized_for_generated_package_surface":
			_fail("%s object missed package body/visit/block surface metadata: %s" % [case_id, JSON.stringify(object)])
			return {}
		if kind == "guard":
			guard_count += 1
			if int(object.get("package_block_tile_count", 0)) <= 0 or String(object.get("passability", {}).get("passability_class", "")) != "neutral_stack_blocking":
				_fail("%s guard did not materialize as blocking package surface: %s" % [case_id, JSON.stringify(object)])
				return {}
		var block_tiles: Array = object.get("package_block_tiles", []) if object.get("package_block_tiles", []) is Array else []
		if kind != "guard" and kind != "town":
			for tile in block_tiles:
				if tile is Dictionary and road_cells.has(_point_key(int(tile.get("x", 0)), int(tile.get("y", 0)))):
					non_guard_road_block_conflicts.append({"placement_id": object.get("placement_id", ""), "kind": kind, "tile": tile})
		if kind != "reward_reference":
			continue
		reward_count += 1
		var value := int(object.get("reward_value", 0))
		var placement_id := String(object.get("placement_id", ""))
		if String(object.get("homm3_re_value_source_model", "")) == "" or String(object.get("native_proxy_object_id", "")) == "" or String(object.get("homm3_re_reward_object_catalog_id", "")) == "":
			_fail("%s loaded reward missed value/proxy/source metadata: %s" % [case_id, JSON.stringify(object)])
			return {}
		if int(object.get("package_body_tile_count", 0)) <= 0 or int(object.get("package_visit_tile_count", 0)) <= 0 or int(object.get("package_block_tile_count", 0)) <= 0:
			_fail("%s loaded reward missed body/visit/block masks: %s" % [case_id, JSON.stringify(object)])
			return {}
		if guarded_reward_ids.has(placement_id):
			loaded_guarded_reward_ids[placement_id] = true
			if not bool(object.get("protected_by_guard", false)) or String(object.get("guarded_by_placement_id", "")) == "" or not bool(object.get("guarded_access_requirements", {}).get("requires_guard_clear", false)):
				_fail("%s generated guarded reward did not retain package guard link: %s" % [case_id, JSON.stringify(object)])
				return {}
		if value >= 2500:
			valuable_reward_count += 1
			if value >= 6000:
				high_value_reward_count += 1
			else:
				medium_value_reward_count += 1
			if bool(object.get("protected_by_guard", false)):
				guarded_valuable_reward_count += 1
				if value < 6000:
					medium_guarded_reward_count += 1
			elif value >= 6000:
				_fail("%s loaded high-value reward is reachable without package guard relation: %s" % [case_id, JSON.stringify(object)])
				return {}
	if loaded_guarded_reward_ids.size() != guarded_reward_ids.size():
		_fail("%s package save/load dropped guarded reward ids: expected=%s loaded=%s" % [case_id, JSON.stringify(guarded_reward_ids.keys()), JSON.stringify(loaded_guarded_reward_ids.keys())])
		return {}
	if not non_guard_road_block_conflicts.is_empty():
		_fail("%s non-guard package block masks overlap road/path cells: %s" % [case_id, JSON.stringify(non_guard_road_block_conflicts.slice(0, 12))])
		return {}
	if reward_count <= 0 or guard_count <= 0:
		_fail("%s loaded package missed rewards or guards: rewards=%d guards=%d" % [case_id, reward_count, guard_count])
		return {}
	return {
		"object_count": int(map_document.get_object_count()),
		"road_cell_count": road_cell_total,
		"unique_road_cell_count": road_cells.size(),
		"reward_count": reward_count,
		"valuable_reward_count": valuable_reward_count,
		"guarded_valuable_reward_count": guarded_valuable_reward_count,
		"high_value_reward_count": high_value_reward_count,
		"medium_value_reward_count": medium_value_reward_count,
		"medium_guarded_reward_count": medium_guarded_reward_count,
		"guard_count": guard_count,
		"package_body_tile_count": package_body_tile_count,
		"package_block_tile_count": package_block_tile_count,
		"package_visit_tile_count": package_visit_tile_count,
		"guarded_reward_save_load_count": loaded_guarded_reward_ids.size(),
		"non_guard_road_block_conflict_count": non_guard_road_block_conflicts.size(),
	}

func _point_key(x: int, y: int) -> String:
	return "%d,%d" % [x, y]

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
