extends Node

const RandomMapGeneratorRulesScript = preload("res://scripts/core/RandomMapGeneratorRules.gd")
const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")

const REPORT_ID := "NATIVE_RANDOM_MAP_AUTO_TEMPLATE_BATCH_REPORT"
const REPORT_SCHEMA_ID := "native_random_map_auto_template_batch_report_v1"

const CASES := [
	{"id": "small_land_seed_a", "seed": "auto-template-batch-small-land-a-10184", "size_class_id": "homm3_small", "player_count": 3, "water_mode": "land", "underground": false},
	{"id": "small_land_seed_b", "seed": "auto-template-batch-small-land-b-10184", "size_class_id": "homm3_small", "player_count": 3, "water_mode": "land", "underground": false},
	{"id": "small_land_seed_c", "seed": "auto-template-batch-small-land-c-10184", "size_class_id": "homm3_small", "player_count": 3, "water_mode": "land", "underground": false},
	{"id": "small_underground_seed_a", "seed": "auto-template-batch-small-underground-a-10184", "size_class_id": "homm3_small", "player_count": 3, "water_mode": "land", "underground": true},
	{"id": "medium_land_seed_a", "seed": "auto-template-batch-medium-land-a-10184", "size_class_id": "homm3_medium", "player_count": 4, "water_mode": "land", "underground": false},
	{"id": "medium_land_seed_b", "seed": "auto-template-batch-medium-land-b-10184", "size_class_id": "homm3_medium", "player_count": 4, "water_mode": "land", "underground": false},
	{"id": "medium_islands_seed_a", "seed": "auto-template-batch-medium-islands-a-10184", "size_class_id": "homm3_medium", "player_count": 4, "water_mode": "islands", "underground": false},
	{"id": "medium_islands_seed_b", "seed": "auto-template-batch-medium-islands-b-10184", "size_class_id": "homm3_medium", "player_count": 4, "water_mode": "islands", "underground": false},
	{"id": "large_land_seed_a", "seed": "auto-template-batch-large-land-a-10184", "size_class_id": "homm3_large", "player_count": 4, "water_mode": "land", "underground": false},
	{"id": "xl_land_seed_a", "seed": "auto-template-batch-xl-land-a-10184", "size_class_id": "homm3_extra_large", "player_count": 5, "water_mode": "land", "underground": false},
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
	var catalog: Dictionary = ContentService.load_json(RandomMapGeneratorRulesScript.TEMPLATE_CATALOG_PATH)
	var summaries := []
	var selected_templates := {}
	for case_record in CASES:
		var summary := _run_case(service, catalog, case_record)
		if summary.is_empty():
			return
		summaries.append(summary)
		selected_templates[String(summary.get("template_id", ""))] = true
	if selected_templates.size() < 6:
		_fail("Auto-template selection did not cover every current owner-compared production default lane: %s" % JSON.stringify(summaries))
		return
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"schema_id": REPORT_SCHEMA_ID,
		"ok": true,
		"binding_kind": metadata.get("binding_kind", ""),
		"native_extension_loaded": metadata.get("native_extension_loaded", false),
		"case_count": summaries.size(),
		"unique_selected_template_count": selected_templates.size(),
		"cases": summaries,
		"remaining_gap": "This proves representative seeded native catalog auto-selection cases prefer current owner-compared production defaults when available and package successfully; it is not an exhaustive 53-template or exact HoMM3 output parity sweep.",
	})])
	get_tree().quit(0)

func _run_case(service: Variant, catalog: Dictionary, case_record: Dictionary) -> Dictionary:
	var config := ScenarioSelectRulesScript.build_random_map_player_config(
		String(case_record.get("seed", "")),
		"",
		"",
		int(case_record.get("player_count", 3)),
		String(case_record.get("water_mode", "land")),
		bool(case_record.get("underground", false)),
		String(case_record.get("size_class_id", "homm3_small")),
		ScenarioSelectRulesScript.RANDOM_MAP_TEMPLATE_SELECTION_MODE_CATALOG_AUTO
	)
	var input_profile: Dictionary = config.get("profile", {}) if config.get("profile", {}) is Dictionary else {}
	if String(input_profile.get("template_id", "")) != "" or String(input_profile.get("id", "")) != "":
		_fail("%s auto config forced a template/profile before native normalization: %s" % [String(case_record.get("id", "")), JSON.stringify(config)])
		return {}
	var first_normalized: Dictionary = service.normalize_random_map_config(config)
	var repeat_normalized: Dictionary = service.normalize_random_map_config(config.duplicate(true))
	if String(first_normalized.get("template_id", "")) != String(repeat_normalized.get("template_id", "")) or String(first_normalized.get("profile_id", "")) != String(repeat_normalized.get("profile_id", "")):
		_fail("%s native auto-selection was not deterministic: first=%s repeat=%s" % [String(case_record.get("id", "")), JSON.stringify(first_normalized), JSON.stringify(repeat_normalized)])
		return {}
	var template_id := String(first_normalized.get("template_id", ""))
	var profile_id := String(first_normalized.get("profile_id", ""))
	if template_id == "" or profile_id == "" or template_id == "native_catalog_auto" or profile_id == "native_catalog_auto":
		_fail("%s native auto-selection did not resolve concrete template/profile ids: %s" % [String(case_record.get("id", "")), JSON.stringify(first_normalized)])
		return {}
	if String(first_normalized.get("template_selection_mode", "")) != "native_catalog_auto" or String(first_normalized.get("profile_selection_mode", "")) != "template_catalog_first_profile":
		_fail("%s native normalization did not record auto-selection provenance: %s" % [String(case_record.get("id", "")), JSON.stringify(first_normalized)])
		return {}
	var template := _template_by_id(catalog, template_id)
	var profile := _profile_by_id(catalog, profile_id)
	if template.is_empty() or profile.is_empty() or String(profile.get("template_id", "")) != template_id:
		_fail("%s native auto-selection resolved ids outside catalog coherence: template=%s profile=%s" % [String(case_record.get("id", "")), JSON.stringify(template), JSON.stringify(profile)])
		return {}
	if not _catalog_constraints_allow(case_record, template):
		_fail("%s native auto-selection chose template outside basic catalog constraints: %s" % [String(case_record.get("id", "")), JSON.stringify(template)])
		return {}
	if not template_id.begins_with("translated_rmg_template_") or not profile_id.begins_with("translated_rmg_profile_"):
		_fail("%s native auto-selection chose a legacy/foundation template instead of a translated launchable catalog template: template=%s profile=%s" % [String(case_record.get("id", "")), template_id, profile_id])
		return {}
	if _expected_owner_compared_auto_template(case_record) != "" and not _is_owner_compared_auto_template(case_record, template_id, profile_id):
		_fail("%s native auto-selection did not prefer the owner-compared production default: expected=%s/%s actual=%s/%s" % [
			String(case_record.get("id", "")),
			_expected_owner_compared_auto_template(case_record),
			_expected_owner_compared_auto_profile(case_record),
			template_id,
			profile_id,
		])
		return {}
	var generated: Dictionary = service.generate_random_map(config, {"startup_path": "auto_template_batch_%s" % String(case_record.get("id", ""))})
	if not bool(generated.get("ok", false)) or String(generated.get("validation_status", "")) != "pass":
		_fail("%s generated auto-template map failed validation: %s" % [String(case_record.get("id", "")), JSON.stringify(generated.get("validation_report", generated))])
		return {}
	if String(generated.get("full_generation_status", "")) == "not_implemented":
		_fail("%s native auto-selection selected a not_implemented template: %s" % [String(case_record.get("id", "")), JSON.stringify(generated.get("normalized_config", {}))])
		return {}
	var report: Dictionary = generated.get("report", generated.get("validation_report", {})) if generated.get("report", generated.get("validation_report", {})) is Dictionary else {}
	var nearest_town_manhattan := _nearest_town_manhattan(generated.get("town_records", []))
	var town_spacing_floor := _town_spacing_floor(String(case_record.get("size_class_id", "")))
	if String(generated.get("full_generation_status", "")) != "not_implemented" and nearest_town_manhattan >= 0 and nearest_town_manhattan < town_spacing_floor:
		_fail("%s generated towns were stacked too closely: nearest=%d min=%d template=%s" % [String(case_record.get("id", "")), nearest_town_manhattan, town_spacing_floor, String(generated.get("normalized_config", {}).get("template_id", ""))])
		return {}
	var runtime_spacing: Dictionary = report.get("town_spacing", {}) if report.get("town_spacing", {}) is Dictionary else {}
	if String(generated.get("full_generation_status", "")) != "not_implemented":
		if String(runtime_spacing.get("validation_status", "")) != "pass" or int(runtime_spacing.get("nearest_town_manhattan", -2)) != nearest_town_manhattan or int(runtime_spacing.get("town_spacing_floor", -1)) != town_spacing_floor:
			_fail("%s runtime town-spacing validation did not match report gate: runtime=%s nearest=%d floor=%d" % [String(case_record.get("id", "")), JSON.stringify(runtime_spacing), nearest_town_manhattan, town_spacing_floor])
			return {}
	var not_implemented_launch_blocked := false
	if String(generated.get("full_generation_status", "")) == "not_implemented":
		var setup: Dictionary = ScenarioSelectRulesScript.build_random_map_skirmish_setup_with_retry(config, "normal", {"max_attempts": 1, "mode": "none"})
		if bool(setup.get("ok", false)) or not _setup_has_not_implemented_failure(setup):
			_fail("%s not_implemented auto-selection still produced a launchable generated setup: %s" % [String(case_record.get("id", "")), JSON.stringify(setup)])
			return {}
		not_implemented_launch_blocked = true
	var normalized: Dictionary = generated.get("normalized_config", {}) if generated.get("normalized_config", {}) is Dictionary else {}
	if String(normalized.get("template_id", "")) != template_id or String(normalized.get("profile_id", "")) != profile_id:
		_fail("%s generation normalized a different template/profile than preflight normalization: preflight=%s generated=%s" % [String(case_record.get("id", "")), JSON.stringify(first_normalized), JSON.stringify(normalized)])
		return {}
	var adoption: Dictionary = service.convert_generated_payload(generated, {
		"feature_gate": "native_rmg_auto_template_batch_report",
		"session_save_version": 9,
		"scenario_id": "native_auto_template_batch_%s" % String(case_record.get("id", "")),
	})
	if not bool(adoption.get("ok", false)):
		_fail("%s auto-template package conversion failed: %s" % [String(case_record.get("id", "")), JSON.stringify(adoption)])
		return {}
	var map_document: Variant = adoption.get("map_document", null)
	if map_document == null:
		_fail("%s auto-template package conversion missed map_document." % String(case_record.get("id", "")))
		return {}
	var terrain_layers: Dictionary = map_document.get_terrain_layers()
	var roads: Array = terrain_layers.get("roads", []) if terrain_layers.get("roads", []) is Array else []
	var road_cells := 0
	for road in roads:
		if road is Dictionary:
			road_cells += int(road.get("tile_count", road.get("cell_count", 0)))
	var object_count := int(map_document.get_object_count())
	if object_count <= 0 or road_cells <= 0:
		_fail("%s auto-template package surface was empty: objects=%d road_cells=%d." % [String(case_record.get("id", "")), object_count, road_cells])
		return {}
	var generated_object_count := int(generated.get("object_placements", []).size())
	var generated_floor := _generated_object_density_floor(String(case_record.get("size_class_id", "")))
	var package_floor := _package_object_density_floor(String(case_record.get("size_class_id", "")))
	var owner_compared_auto_candidate := _is_owner_compared_auto_template(case_record, template_id, profile_id)
	if not owner_compared_auto_candidate and generated_object_count < generated_floor:
		_fail("%s auto-template generated object density stayed sparse: %d min %d." % [String(case_record.get("id", "")), generated_object_count, generated_floor])
		return {}
	if not owner_compared_auto_candidate and object_count < package_floor:
		_fail("%s auto-template package object density stayed sparse: %d min %d." % [String(case_record.get("id", "")), object_count, package_floor])
		return {}
	return {
		"id": String(case_record.get("id", "")),
		"size_class_id": String(case_record.get("size_class_id", "")),
		"water_mode": String(case_record.get("water_mode", "")),
		"player_count": int(case_record.get("player_count", 0)),
		"template_id": template_id,
		"profile_id": profile_id,
		"template_selection_mode": String(normalized.get("template_selection_mode", "")),
		"profile_selection_mode": String(normalized.get("profile_selection_mode", "")),
		"owner_compared_auto_candidate": owner_compared_auto_candidate,
		"density_floor_policy": "owner_compared_exact_or_bounded_counts_no_broad_floor" if owner_compared_auto_candidate else "broad_structural_auto_density_floor",
		"validation_status": String(generated.get("validation_status", "")),
		"full_generation_status": String(generated.get("full_generation_status", "")),
		"not_implemented_launch_blocked": not_implemented_launch_blocked,
		"zone_count": int(generated.get("zone_layout", {}).get("zone_count", 0)),
		"route_edge_count": int(generated.get("route_graph", {}).get("route_edge_count", 0)),
		"town_count": int(generated.get("town_records", []).size()),
		"nearest_town_manhattan": nearest_town_manhattan,
		"town_spacing_floor": town_spacing_floor,
		"guard_count": int(generated.get("guard_records", []).size()),
		"object_count": generated_object_count,
		"generated_object_density_floor": generated_floor,
		"package_object_count": object_count,
		"package_object_density_floor": package_floor,
		"package_road_cell_count": road_cells,
	}

func _generated_object_density_floor(size_class_id: String) -> int:
	match size_class_id:
		"homm3_small":
			return 275
		"homm3_medium":
			return 380
		"homm3_large":
			return 900
		"homm3_extra_large":
			return 1100
	return 250

func _package_object_density_floor(size_class_id: String) -> int:
	match size_class_id:
		"homm3_small":
			return 300
		"homm3_medium":
			return 420
		"homm3_large":
			return 1100
		"homm3_extra_large":
			return 1180
	return 300

func _town_spacing_floor(size_class_id: String) -> int:
	match size_class_id:
		"homm3_small":
			return 8
		"homm3_medium":
			return 10
		"homm3_large":
			return 12
		"homm3_extra_large":
			return 12
	return 8

func _nearest_town_manhattan(town_records: Array) -> int:
	var towns := []
	for town in town_records:
		if town is Dictionary:
			towns.append(town)
	if towns.size() < 2:
		return -1
	var nearest := 1 << 30
	for left_index in range(towns.size()):
		var left: Dictionary = towns[left_index]
		for right_index in range(left_index + 1, towns.size()):
			var right: Dictionary = towns[right_index]
			var distance: int = abs(int(left.get("x", 0)) - int(right.get("x", 0))) + abs(int(left.get("y", 0)) - int(right.get("y", 0)))
			nearest = mini(nearest, distance)
	return nearest

func _expected_owner_compared_auto_template(case_record: Dictionary) -> String:
	if bool(case_record.get("underground", false)):
		if String(case_record.get("size_class_id", "")) == "homm3_small" and int(case_record.get("player_count", 0)) == 3 and String(case_record.get("water_mode", "land")) == "land":
			return "translated_rmg_template_027_v1"
		return ""
	if String(case_record.get("water_mode", "land")) == "islands":
		if String(case_record.get("size_class_id", "")) == "homm3_medium" and int(case_record.get("player_count", 0)) == 4:
			return "translated_rmg_template_001_v1"
		return ""
	if String(case_record.get("water_mode", "land")) != "land":
		return ""
	match String(case_record.get("size_class_id", "")):
		"homm3_small":
			return "translated_rmg_template_049_v1" if int(case_record.get("player_count", 0)) == 3 else ""
		"homm3_medium":
			return "translated_rmg_template_002_v1" if int(case_record.get("player_count", 0)) == 4 else ""
		"homm3_large":
			return "translated_rmg_template_042_v1" if int(case_record.get("player_count", 0)) == 4 else ""
		"homm3_extra_large":
			return "translated_rmg_template_043_v1" if int(case_record.get("player_count", 0)) == 5 else ""
	return ""

func _is_owner_compared_auto_template(case_record: Dictionary, template_id: String, profile_id: String) -> bool:
	return template_id == _expected_owner_compared_auto_template(case_record) and profile_id == _expected_owner_compared_auto_profile(case_record)

func _expected_owner_compared_auto_profile(case_record: Dictionary) -> String:
	match _expected_owner_compared_auto_template(case_record):
		"translated_rmg_template_001_v1":
			return "translated_rmg_profile_001_v1"
		"translated_rmg_template_049_v1":
			return "translated_rmg_profile_049_v1"
		"translated_rmg_template_002_v1":
			return "translated_rmg_profile_002_v1"
		"translated_rmg_template_042_v1":
			return "translated_rmg_profile_042_v1"
		"translated_rmg_template_043_v1":
			return "translated_rmg_profile_043_v1"
		"translated_rmg_template_027_v1":
			return "translated_rmg_profile_027_v1"
	return ""

func _catalog_constraints_allow(case_record: Dictionary, template: Dictionary) -> bool:
	var players: Dictionary = template.get("players", {}) if template.get("players", {}) is Dictionary else {}
	var total: Dictionary = players.get("total", {}) if players.get("total", {}) is Dictionary else {}
	var player_count := int(case_record.get("player_count", 0))
	if player_count < int(total.get("min", 1)) or player_count > int(total.get("max", 8)):
		return false
	var support: Dictionary = template.get("map_support", {}) if template.get("map_support", {}) is Dictionary else {}
	var water_modes: Array = support.get("water_modes", []) if support.get("water_modes", []) is Array else []
	var water_mode := String(case_record.get("water_mode", "land"))
	if water_mode == "islands":
		return "islands" in water_modes or "islands_size_score_halved" in water_modes
	return water_modes.is_empty() or "land" in water_modes

func _setup_has_not_implemented_failure(setup: Dictionary) -> bool:
	var validation: Dictionary = setup.get("validation", {}) if setup.get("validation", {}) is Dictionary else {}
	var failures: Array = validation.get("failures", []) if validation.get("failures", []) is Array else []
	for failure in failures:
		if failure is Dictionary and String(failure.get("code", "")) == "native_rmg_full_generation_not_implemented":
			return true
	return false

func _template_by_id(catalog: Dictionary, template_id: String) -> Dictionary:
	for template in catalog.get("templates", []):
		if template is Dictionary and String(template.get("id", "")) == template_id:
			return template
	return {}

func _profile_by_id(catalog: Dictionary, profile_id: String) -> Dictionary:
	for profile in catalog.get("profiles", []):
		if profile is Dictionary and String(profile.get("id", "")) == profile_id:
			return profile
	return {}

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
