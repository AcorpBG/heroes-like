extends Node

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const RandomMapGeneratorRulesScript = preload("res://scripts/core/RandomMapGeneratorRules.gd")

const REPORT_ID := "NATIVE_RANDOM_MAP_GDSCRIPT_COMPARISON_REPORT"
const REPORT_SCHEMA_ID := "native_random_map_gdscript_comparison_report_v1"
const FIXTURE_PATH := "res://tests/fixtures/native_random_map_comparison_cases.json"
const REQUIRED_NATIVE_CAPABILITIES := [
	"native_random_map_config_identity",
	"native_random_map_foundation_stub",
	"native_random_map_terrain_grid_foundation",
	"native_random_map_zone_player_starts_foundation",
	"native_random_map_road_river_network_foundation",
	"native_random_map_object_placement_foundation",
	"native_random_map_town_guard_placement_foundation",
	"native_random_map_validation_provenance_foundation",
	"native_random_map_package_session_adoption_bridge",
]
const REQUIRED_NATIVE_PHASE_COMPONENTS := [
	"terrain_grid",
	"zone_layout",
	"player_starts",
	"route_graph",
	"road_network",
	"river_network",
	"object_placement",
	"town_placement",
	"guard_placement",
	"validation_provenance",
]
const REQUIRED_REPORT_FIELDS := [
	"schema_id",
	"ok",
	"case_count",
	"cases",
	"aggregate",
	"known_gaps",
	"readiness",
]
const REQUIRED_COMPARISON_FIELDS := [
	"structural_dimensions",
	"players",
	"terrain",
	"roads_rivers",
	"objects_towns_guards",
	"validation_provenance",
	"known_gaps",
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
	for capability in REQUIRED_NATIVE_CAPABILITIES:
		if not capabilities.has(capability):
			_fail("Native capability %s is missing: %s" % [capability, JSON.stringify(Array(capabilities))])
			return

	var fixture := _load_fixture()
	var cases: Array = fixture.get("cases", [])
	if cases.is_empty():
		_fail("Comparison fixture has no cases: %s" % JSON.stringify(fixture))
		return

	var case_reports := []
	var aggregate_gaps := []
	var matched_dimensions := 0
	var matched_player_counts := 0
	var native_foundation_component_count := 0
	var package_session_adoption_ready_count := 0
	for case_record in cases:
		if not (case_record is Dictionary):
			_fail("Comparison fixture contains a non-dictionary case.")
			return
		var report := _run_case(service, case_record)
		if report.is_empty():
			return
		for field in REQUIRED_COMPARISON_FIELDS:
			if not report.has(field):
				_fail("Case report missed required field %s: %s" % [field, JSON.stringify(report)])
				return
		case_reports.append(report)
		if bool(report.get("structural_dimensions", {}).get("matches", false)):
			matched_dimensions += 1
		if bool(report.get("players", {}).get("player_count_matches", false)):
			matched_player_counts += 1
		if bool(report.get("native_foundation_components_reported", false)):
			native_foundation_component_count += 1
		if bool(report.get("package_session_adoption", {}).get("ready", false)):
			package_session_adoption_ready_count += 1
		for gap in report.get("known_gaps", []):
			aggregate_gaps.append(gap)

	var known_gaps := _unique_gap_records(aggregate_gaps)
	var scoped_structural_ready := known_gaps.is_empty() and package_session_adoption_ready_count == case_reports.size()

	var report := {
		"schema_id": REPORT_SCHEMA_ID,
		"ok": true,
		"binding_kind": metadata.get("binding_kind", ""),
		"native_extension_loaded": metadata.get("native_extension_loaded", false),
		"case_count": case_reports.size(),
		"cases": case_reports,
		"aggregate": {
			"dimension_match_count": matched_dimensions,
			"player_count_match_count": matched_player_counts,
			"known_gap_count": known_gaps.size(),
			"native_foundation_component_report_count": native_foundation_component_count,
			"all_native_foundation_components_reported": native_foundation_component_count == case_reports.size(),
			"package_session_adoption_ready_count": package_session_adoption_ready_count,
			"all_package_session_adoptions_ready": package_session_adoption_ready_count == case_reports.size(),
			"scoped_structural_ready": scoped_structural_ready,
			"fixture_schema_id": String(fixture.get("schema_id", "")),
		},
		"known_gaps": known_gaps,
		"readiness": {
			"gdscript_source_of_truth": true,
			"native_runtime_authoritative": false,
			"package_session_adoption_ready": package_session_adoption_ready_count == case_reports.size(),
			"full_parity_claim": false,
			"adoption_gate_status": "package_session_bridge_ready_scoped_structural_not_authoritative" if scoped_structural_ready else "blocked_until_package_session_adoption_and_structural_gates",
			"next_required_slices": ["native-rmg-production-owner-comparison-gate-10184"],
		},
	}
	_assert_report_contract(report, cases.size())
	print("%s %s" % [REPORT_ID, JSON.stringify(report)])
	get_tree().quit(0)

func _run_case(service: Variant, case_record: Dictionary) -> Dictionary:
	var config := ScenarioSelectRulesScript.build_random_map_player_config(
		String(case_record.get("seed", "")),
		String(case_record.get("template_id", "")),
		String(case_record.get("profile_id", "")),
		int(case_record.get("player_count", 3)),
		String(case_record.get("water_mode", "land")),
		bool(case_record.get("underground_enabled", false)),
		String(case_record.get("size_class_id", "homm3_small"))
	)
	var gdscript_setup := _run_gdscript_reference(config)
	if not bool(gdscript_setup.get("ok", false)):
		_fail("GDScript source-of-truth generation failed for %s: %s" % [String(case_record.get("id", "")), JSON.stringify(gdscript_setup)])
		return {}
	var native_result: Dictionary = service.generate_random_map(config)
	if not bool(native_result.get("ok", false)):
		_fail("Native generation failed for %s: %s" % [String(case_record.get("id", "")), JSON.stringify(native_result)])
		return {}
	var adoption: Dictionary = service.convert_generated_payload(native_result, {
		"feature_gate": "native_rmg_gdscript_comparison_adoption_check",
		"session_save_version": 9,
	})
	if not bool(adoption.get("ok", false)):
		_fail("Native package/session adoption conversion failed for %s: adoption=%s native_validation=%s" % [String(case_record.get("id", "")), JSON.stringify(adoption), JSON.stringify(native_result.get("validation_report", {}))])
		return {}

	var gdscript_summary := _gdscript_summary(gdscript_setup)
	var native_summary := _native_summary(native_result)
	var comparisons := _comparison_sections(gdscript_summary, native_summary)
	var adoption_summary := _adoption_summary(adoption)
	var known_gaps := _case_known_gaps(case_record, gdscript_summary, native_summary, comparisons, adoption_summary)
	return {
		"case_id": String(case_record.get("id", "")),
		"seed": String(config.get("seed", "")),
		"config": {
			"template_id": String(config.get("profile", {}).get("template_id", config.get("template_id", ""))),
			"profile_id": String(config.get("profile", {}).get("id", "")),
			"size_class_id": String(config.get("size", {}).get("size_class_id", "")),
			"width": int(config.get("size", {}).get("width", 0)),
			"height": int(config.get("size", {}).get("height", 0)),
			"level_count": int(config.get("size", {}).get("level_count", 1)),
			"water_mode": String(config.get("size", {}).get("water_mode", "")),
			"player_count": int(config.get("player_constraints", {}).get("player_count", 0)),
		},
		"gdscript": gdscript_summary,
		"native": native_summary,
		"structural_dimensions": comparisons.get("structural_dimensions", {}),
		"players": comparisons.get("players", {}),
		"terrain": comparisons.get("terrain", {}),
		"roads_rivers": comparisons.get("roads_rivers", {}),
		"objects_towns_guards": comparisons.get("objects_towns_guards", {}),
		"validation_provenance": comparisons.get("validation_provenance", {}),
		"package_session_adoption": adoption_summary,
		"native_foundation_components_reported": _native_foundation_components_reported(native_summary),
		"known_gaps": known_gaps,
		"readiness": {
			"byte_for_byte_parity_required": false,
			"native_adoption_allowed": known_gaps.is_empty(),
			"package_session_adoption_ready": bool(adoption_summary.get("ready", false)),
			"full_parity_claim": bool(native_summary.get("provenance", {}).get("full_parity_claim", false)) and known_gaps.is_empty(),
		},
	}

func _run_gdscript_reference(config: Dictionary) -> Dictionary:
	var reference: Dictionary = RandomMapGeneratorRulesScript.generate(config)
	if not bool(reference.get("ok", false)):
		return reference
	var generated_map: Dictionary = reference.get("generated_map", {}) if reference.get("generated_map", {}) is Dictionary else {}
	var report: Dictionary = reference.get("report", {}) if reference.get("report", {}) is Dictionary else {}
	return {
		"ok": true,
		"generated_map": generated_map,
		"validation": report,
		"campaign_adoption": false,
		"alpha_parity_claim": false,
		"generated_identity": {
			"stable_signature": String(generated_map.get("stable_signature", "")),
			"materialized_map_signature": String(generated_map.get("runtime_materialization", {}).get("materialized_map_signature", "")),
		},
	}

func _gdscript_summary(setup: Dictionary) -> Dictionary:
	var payload: Dictionary = setup.get("generated_map", {}) if setup.get("generated_map", {}) is Dictionary else {}
	var scenario: Dictionary = payload.get("scenario_record", {}) if payload.get("scenario_record", {}) is Dictionary else {}
	var staging: Dictionary = payload.get("staging", {}) if payload.get("staging", {}) is Dictionary else {}
	var metadata: Dictionary = payload.get("metadata", {}) if payload.get("metadata", {}) is Dictionary else {}
	var validation: Dictionary = setup.get("validation", {}) if setup.get("validation", {}) is Dictionary else {}
	var terrain_rows: Array = scenario.get("map", []) if scenario.get("map", []) is Array else []
	var road_network: Dictionary = staging.get("road_network", {}) if staging.get("road_network", {}) is Dictionary else {}
	var roads_rivers: Dictionary = staging.get("roads_rivers_writeout", {}) if staging.get("roads_rivers_writeout", {}) is Dictionary else {}
	var town_mine_dwelling: Dictionary = staging.get("town_mine_dwelling_placement", {}) if staging.get("town_mine_dwelling_placement", {}) is Dictionary else {}
	var runtime_materialization: Dictionary = payload.get("runtime_materialization", {}) if payload.get("runtime_materialization", {}) is Dictionary else {}
	var decoration: Dictionary = staging.get("decoration_density_pass", {}) if staging.get("decoration_density_pass", {}) is Dictionary else {}
	return {
		"generator": "gdscript_random_map_generator_rules",
		"ok": bool(setup.get("ok", false)),
		"scenario_id": String(scenario.get("id", "")),
		"dimensions": _dimensions_from_scenario(scenario, metadata),
		"player_count": int(metadata.get("player_constraints", {}).get("player_count", scenario.get("players", []).size())),
		"player_start_count": scenario.get("players", []).size(),
		"terrain": _terrain_summary_from_rows(terrain_rows),
		"roads": {
			"segment_count": road_network.get("road_segments", []).size(),
			"cell_count": int(roads_rivers.get("summary", {}).get("road_cell_count", 0)),
			"status": String(roads_rivers.get("status", "")),
		},
		"rivers": {
			"segment_count": int(roads_rivers.get("summary", {}).get("river_segment_count", 0)),
			"cell_count": int(roads_rivers.get("summary", {}).get("river_cell_count", 0)),
			"status": String(roads_rivers.get("status", "")),
		},
		"objects": {
			"placement_count": staging.get("object_placements", []).size(),
			"category_counts": _count_by_key(staging.get("object_placements", []), "kind"),
			"core_placement_count": staging.get("object_placements", []).size(),
			"core_category_counts": _count_by_key(staging.get("object_placements", []), "kind"),
			"decorative_obstacle_count": decoration.get("decoration_records", []).size(),
			"runtime_object_instance_count": runtime_materialization.get("objects", {}).get("object_instances", []).size(),
		},
		"towns": {
			"scenario_town_count": scenario.get("towns", []).size(),
			"staged_town_count": int(town_mine_dwelling.get("summary", {}).get("town_count", 0)),
			"mine_count": int(town_mine_dwelling.get("summary", {}).get("mine_count", 0)),
			"dwelling_count": int(town_mine_dwelling.get("summary", {}).get("dwelling_count", 0)),
		},
		"guards": {
			"scenario_encounter_count": scenario.get("encounters", []).size(),
			"route_guard_count": int(metadata.get("route_guard_count", 0)),
		},
		"validation": {
			"status": String(validation.get("status", "")),
			"failure_count": int(validation.get("failure_count", 0)),
			"warning_count": int(validation.get("warning_count", 0)),
			"schema_id": String(validation.get("schema_id", "")),
		},
		"provenance": {
			"write_policy": String(payload.get("write_policy", "")),
			"campaign_adoption": bool(setup.get("campaign_adoption", true)),
			"alpha_parity_claim": bool(setup.get("alpha_parity_claim", true)),
			"generated_identity_signature": String(setup.get("generated_identity", {}).get("stable_signature", payload.get("stable_signature", ""))),
			"materialized_map_signature": String(setup.get("generated_identity", {}).get("materialized_map_signature", "")),
		},
	}

func _native_summary(native_result: Dictionary) -> Dictionary:
	var report: Dictionary = native_result.get("validation_report", {}) if native_result.get("validation_report", {}) is Dictionary else {}
	var provenance: Dictionary = native_result.get("provenance", {}) if native_result.get("provenance", {}) is Dictionary else {}
	var metrics: Dictionary = report.get("metrics", {}) if report.get("metrics", {}) is Dictionary else {}
	var terrain_grid: Dictionary = native_result.get("terrain_grid", {}) if native_result.get("terrain_grid", {}) is Dictionary else {}
	var native_objects: Array = native_result.get("object_placements", []) if native_result.get("object_placements", []) is Array else []
	var native_category_counts := _count_by_key(native_objects, "kind")
	var native_core_category_counts := _count_by_key(_records_without_kind(native_objects, "decorative_obstacle"), "kind")
	var native_decor_count := int(native_category_counts.get("decorative_obstacle", 0))
	return {
		"generator": "native_gdextension_map_package_service",
		"ok": bool(native_result.get("ok", false)),
		"status": String(native_result.get("status", "")),
		"full_generation_status": String(native_result.get("full_generation_status", "")),
		"dimensions": {
			"width": int(metrics.get("width", terrain_grid.get("width", 0))),
			"height": int(metrics.get("height", terrain_grid.get("height", 0))),
			"level_count": int(metrics.get("level_count", native_result.get("normalized_config", {}).get("level_count", 1))),
			"tile_count": int(metrics.get("tile_count", terrain_grid.get("tile_count", 0))),
		},
		"player_count": int(native_result.get("normalized_config", {}).get("player_constraints", {}).get("player_count", 0)),
		"player_start_count": int(metrics.get("player_start_count", native_result.get("player_starts", {}).get("start_count", 0))),
		"terrain": {
			"tile_count": int(terrain_grid.get("tile_count", 0)),
			"terrain_counts": terrain_grid.get("terrain_counts", {}),
			"categories": _terrain_categories_from_counts(terrain_grid.get("terrain_counts", {})),
			"palette_ids": terrain_grid.get("terrain_palette_ids", []),
			"signature": String(terrain_grid.get("signature", "")),
		},
		"roads": {
			"segment_count": int(metrics.get("road_segment_count", 0)),
			"cell_count": int(metrics.get("road_cell_count", 0)),
			"status": String(native_result.get("road_generation_status", "")),
		},
		"rivers": {
			"segment_count": int(metrics.get("river_segment_count", 0)),
			"cell_count": int(metrics.get("river_cell_count", 0)),
			"status": String(native_result.get("river_generation_status", "")),
		},
		"objects": {
			"placement_count": int(metrics.get("object_placement_count", native_result.get("object_placements", []).size())),
			"category_counts": native_category_counts,
			"core_placement_count": native_objects.size() - native_decor_count,
			"core_category_counts": native_core_category_counts,
			"decorative_obstacle_count": native_decor_count,
			"runtime_object_instance_count": 0,
		},
		"towns": {
			"scenario_town_count": int(metrics.get("town_count", native_result.get("town_records", []).size())),
			"staged_town_count": int(metrics.get("town_count", native_result.get("town_records", []).size())),
			"mine_count": int(native_result.get("town_guard_category_counts", {}).get("mine", 0)),
			"dwelling_count": int(native_result.get("town_guard_category_counts", {}).get("neutral_dwelling", 0)),
		},
		"guards": {
			"scenario_encounter_count": int(metrics.get("guard_count", native_result.get("guard_records", []).size())),
			"route_guard_count": int(metrics.get("guard_count", native_result.get("guard_records", []).size())),
		},
		"validation": {
			"status": String(native_result.get("validation_status", "")),
			"failure_count": int(report.get("failure_count", 0)),
			"warning_count": int(report.get("warning_count", 0)),
			"schema_id": String(report.get("schema_id", "")),
		},
		"provenance": {
			"schema_id": String(provenance.get("schema_id", "")),
			"signature": String(provenance.get("signature", "")),
			"no_authored_writeback": bool(native_result.get("no_authored_writeback", false)),
			"adoption_status": String(native_result.get("adoption_status", "")),
			"full_parity_claim": bool(report.get("full_parity_claim", true)),
		},
		"component_counts": native_result.get("component_counts", {}),
		"component_signatures": native_result.get("component_signatures", {}),
		"phase_pipeline": native_result.get("phase_pipeline", []),
	}

func _adoption_summary(adoption: Dictionary) -> Dictionary:
	var report: Dictionary = adoption.get("report", {}) if adoption.get("report", {}) is Dictionary else {}
	var metrics: Dictionary = report.get("metrics", {}) if report.get("metrics", {}) is Dictionary else {}
	var map_package: Dictionary = adoption.get("map_package_record", {}) if adoption.get("map_package_record", {}) is Dictionary else {}
	var scenario_package: Dictionary = adoption.get("scenario_package_record", {}) if adoption.get("scenario_package_record", {}) is Dictionary else {}
	var session_boundary: Dictionary = adoption.get("session_boundary_record", {}) if adoption.get("session_boundary_record", {}) is Dictionary else {}
	return {
		"ready": bool(adoption.get("ok", false)) and String(report.get("status", "")) == "pass" and bool(report.get("package_session_adoption_ready", false)),
		"status": String(adoption.get("adoption_status", "")),
		"report_schema_id": String(report.get("schema_id", "")),
		"map_package_hash": String(map_package.get("package_hash", "")),
		"scenario_package_hash": String(scenario_package.get("package_hash", "")),
		"session_id": String(session_boundary.get("session_id", "")),
		"save_version": int(session_boundary.get("save_version", 0)),
		"save_version_bump": bool(session_boundary.get("save_version_bump", true)),
		"authored_content_writeback": bool(session_boundary.get("authored_content_writeback", true)),
		"runtime_call_site_adoption": bool(session_boundary.get("runtime_call_site_adoption", true)),
		"native_runtime_authoritative": bool(session_boundary.get("native_runtime_authoritative", true)),
		"full_parity_claim": bool(session_boundary.get("full_parity_claim", true)),
		"metrics": metrics,
	}

func _comparison_sections(gdscript: Dictionary, native: Dictionary) -> Dictionary:
	return {
		"structural_dimensions": _dimension_comparison(gdscript, native),
		"players": {
			"player_count_matches": int(gdscript.get("player_count", 0)) == int(native.get("player_count", 0)),
			"player_start_count_matches": int(gdscript.get("player_start_count", 0)) == int(native.get("player_start_count", 0)),
			"gdscript_player_count": int(gdscript.get("player_count", 0)),
			"native_player_count": int(native.get("player_count", 0)),
			"gdscript_player_start_count": int(gdscript.get("player_start_count", 0)),
			"native_player_start_count": int(native.get("player_start_count", 0)),
		},
		"terrain": _terrain_comparison(gdscript, native),
		"roads_rivers": _roads_rivers_comparison(gdscript, native),
		"objects_towns_guards": _object_comparison(gdscript, native),
		"validation_provenance": _validation_comparison(gdscript, native),
	}

func _dimension_comparison(gdscript: Dictionary, native: Dictionary) -> Dictionary:
	var left: Dictionary = gdscript.get("dimensions", {})
	var right: Dictionary = native.get("dimensions", {})
	return {
		"matches": int(left.get("width", 0)) == int(right.get("width", 0)) and int(left.get("height", 0)) == int(right.get("height", 0)) and int(left.get("level_count", 1)) == int(right.get("level_count", 1)),
		"gdscript": left,
		"native": right,
	}

func _terrain_comparison(gdscript: Dictionary, native: Dictionary) -> Dictionary:
	var left: Dictionary = gdscript.get("terrain", {})
	var right: Dictionary = native.get("terrain", {})
	var left_categories: Dictionary = left.get("categories", {})
	var right_categories: Dictionary = right.get("categories", {})
	return {
		"tile_count_matches": int(left.get("tile_count", 0)) == int(right.get("tile_count", 0)),
		"category_keys_match": _sorted_keys(left_categories) == _sorted_keys(right_categories),
		"gdscript_categories": left_categories,
		"native_categories": right_categories,
		"gdscript_terrain_counts": left.get("terrain_counts", {}),
		"native_terrain_counts": right.get("terrain_counts", {}),
	}

func _roads_rivers_comparison(gdscript: Dictionary, native: Dictionary) -> Dictionary:
	var left_roads: Dictionary = gdscript.get("roads", {})
	var right_roads: Dictionary = native.get("roads", {})
	var left_rivers: Dictionary = gdscript.get("rivers", {})
	var right_rivers: Dictionary = native.get("rivers", {})
	return {
		"road_segment_counts_match": int(left_roads.get("segment_count", 0)) == int(right_roads.get("segment_count", 0)),
		"road_cell_counts_match": int(left_roads.get("cell_count", 0)) == int(right_roads.get("cell_count", 0)),
		"river_segment_counts_match": int(left_rivers.get("segment_count", 0)) == int(right_rivers.get("segment_count", 0)),
		"river_cell_counts_match": int(left_rivers.get("cell_count", 0)) == int(right_rivers.get("cell_count", 0)),
		"gdscript_roads": left_roads,
		"native_roads": right_roads,
		"gdscript_rivers": left_rivers,
		"native_rivers": right_rivers,
	}

func _object_comparison(gdscript: Dictionary, native: Dictionary) -> Dictionary:
	var left_objects: Dictionary = gdscript.get("objects", {})
	var right_objects: Dictionary = native.get("objects", {})
	var left_towns: Dictionary = gdscript.get("towns", {})
	var right_towns: Dictionary = native.get("towns", {})
	var left_guards: Dictionary = gdscript.get("guards", {})
	var right_guards: Dictionary = native.get("guards", {})
	return {
		"object_placement_counts_match": int(left_objects.get("core_placement_count", left_objects.get("placement_count", 0))) == int(right_objects.get("core_placement_count", right_objects.get("placement_count", 0))),
		"object_category_keys_match": _sorted_keys(left_objects.get("core_category_counts", left_objects.get("category_counts", {}))) == _sorted_keys(right_objects.get("core_category_counts", right_objects.get("category_counts", {}))),
		"native_decorative_obstacle_count": int(right_objects.get("decorative_obstacle_count", 0)),
		"gdscript_decoration_record_count": int(left_objects.get("decorative_obstacle_count", 0)),
		"decorations_generated_in_native_output": int(right_objects.get("decorative_obstacle_count", 0)) > 0,
		"town_counts_match": int(left_towns.get("scenario_town_count", 0)) == int(right_towns.get("scenario_town_count", 0)),
		"guard_counts_match": int(left_guards.get("scenario_encounter_count", 0)) == int(right_guards.get("scenario_encounter_count", 0)),
		"gdscript_objects": left_objects,
		"native_objects": right_objects,
		"gdscript_towns": left_towns,
		"native_towns": right_towns,
		"gdscript_guards": left_guards,
		"native_guards": right_guards,
	}

func _validation_comparison(gdscript: Dictionary, native: Dictionary) -> Dictionary:
	var left_validation: Dictionary = gdscript.get("validation", {})
	var right_validation: Dictionary = native.get("validation", {})
	var left_provenance: Dictionary = gdscript.get("provenance", {})
	var right_provenance: Dictionary = native.get("provenance", {})
	return {
		"gdscript_validation_status": String(left_validation.get("status", "")),
		"native_validation_status": String(right_validation.get("status", "")),
		"native_provenance_present": String(right_provenance.get("schema_id", "")) == "aurelion_native_random_map_provenance_v1" and String(right_provenance.get("signature", "")) != "",
		"native_no_authored_writeback": bool(right_provenance.get("no_authored_writeback", false)),
		"gdscript_no_authored_writeback": String(left_provenance.get("write_policy", "")) == "generated_export_record_no_authored_content_write",
		"gdscript_campaign_adoption": bool(left_provenance.get("campaign_adoption", true)),
		"native_adoption_status": String(right_provenance.get("adoption_status", "")),
		"native_full_parity_claim": bool(right_provenance.get("full_parity_claim", true)),
	}

func _case_known_gaps(case_record: Dictionary, gdscript: Dictionary, native: Dictionary, comparisons: Dictionary, adoption: Dictionary) -> Array:
	var gaps := []
	_append_gap_if_false(gaps, comparisons.get("structural_dimensions", {}).get("matches", false), "dimension_mismatch", case_record, "Native and GDScript dimensions differ.")
	_append_gap_if_false(gaps, comparisons.get("players", {}).get("player_count_matches", false), "player_count_mismatch", case_record, "Native and GDScript player counts differ.")
	_append_gap_if_false(gaps, comparisons.get("players", {}).get("player_start_count_matches", false), "player_start_count_mismatch", case_record, "Native and GDScript player start counts differ.")
	_append_gap_if_false(gaps, comparisons.get("terrain", {}).get("tile_count_matches", false), "terrain_tile_count_mismatch", case_record, "Native and GDScript terrain tile counts differ.")
	_append_gap_if_false(gaps, comparisons.get("terrain", {}).get("category_keys_match", false), "terrain_category_gap", case_record, "Native and GDScript terrain category coverage differs.")
	_append_gap_if_false(gaps, comparisons.get("roads_rivers", {}).get("road_segment_counts_match", false), "road_segment_count_gap", case_record, "Native and GDScript road segment counts differ.")
	_append_gap_if_false(gaps, comparisons.get("roads_rivers", {}).get("road_cell_counts_match", false), "road_cell_count_gap", case_record, "Native and GDScript road cell counts differ.")
	_append_gap_if_false(gaps, comparisons.get("roads_rivers", {}).get("river_segment_counts_match", false), "river_segment_count_gap", case_record, "Native and GDScript river segment counts differ.")
	_append_gap_if_false(gaps, comparisons.get("roads_rivers", {}).get("river_cell_counts_match", false), "river_cell_count_gap", case_record, "Native and GDScript river cell counts differ.")
	_append_gap_if_false(gaps, comparisons.get("objects_towns_guards", {}).get("object_placement_counts_match", false), "object_count_gap", case_record, "Native and GDScript staged object counts differ.")
	_append_gap_if_false(gaps, comparisons.get("objects_towns_guards", {}).get("object_category_keys_match", false), "object_category_gap", case_record, "Native and GDScript object category coverage differs.")
	_append_gap_if_false(gaps, comparisons.get("objects_towns_guards", {}).get("decorations_generated_in_native_output", false), "native_decoration_absent", case_record, "Native supported output must include decorative_obstacle records.")
	_append_gap_if_false(gaps, comparisons.get("objects_towns_guards", {}).get("town_counts_match", false), "town_count_gap", case_record, "Native and GDScript town counts differ.")
	_append_gap_if_false(gaps, comparisons.get("objects_towns_guards", {}).get("guard_counts_match", false), "guard_count_gap", case_record, "Native and GDScript guard counts differ.")
	if String(native.get("status", "")) != "scoped_structural_profile_supported":
		gaps.append(_gap("native_status_not_scoped_structural", case_record, "Native status must report scoped structural support for tracked structural cases."))
	if String(native.get("full_generation_status", "")) == "not_implemented":
		gaps.append(_gap("native_full_generation_status_not_implemented", case_record, "Native full-generation status must no longer be not_implemented for tracked parity cases."))
	if not bool(adoption.get("ready", false)):
		gaps.append(_gap("package_session_adoption_not_ready", case_record, "Native package/session adoption conversion did not pass."))
	if bool(native.get("provenance", {}).get("full_parity_claim", false)) or bool(native.get("provenance", {}).get("native_runtime_authoritative", false)):
		gaps.append(_gap("native_false_production_claim", case_record, "Native validation/provenance must not claim production parity or native runtime authority for tracked structural cases."))
	if bool(gdscript.get("provenance", {}).get("campaign_adoption", true)):
		gaps.append(_gap("gdscript_false_campaign_adoption", case_record, "GDScript generated setup must keep campaign adoption disabled."))
	if String(native.get("validation", {}).get("status", "")) != "pass":
		gaps.append(_gap("native_validation_not_pass", case_record, "Native validation/provenance report did not pass."))
	return gaps

func _append_gap_if_false(gaps: Array, value: bool, code: String, case_record: Dictionary, message: String) -> void:
	if not value:
		gaps.append(_gap(code, case_record, message))

func _gap(code: String, case_record: Dictionary, message: String) -> Dictionary:
	return {
		"code": code,
		"case_id": String(case_record.get("id", "")),
		"severity": "gap",
		"message": message,
	}

func _dimensions_from_scenario(scenario: Dictionary, metadata: Dictionary) -> Dictionary:
	var size: Dictionary = scenario.get("map_size", {}) if scenario.get("map_size", {}) is Dictionary else {}
	var policy: Dictionary = metadata.get("size_policy", {}) if metadata.get("size_policy", {}) is Dictionary else {}
	return {
		"width": int(size.get("width", policy.get("source_size", {}).get("width", 0))),
		"height": int(size.get("height", policy.get("source_size", {}).get("height", 0))),
		"level_count": int(policy.get("level_count", metadata.get("size", {}).get("level_count", 1))),
		"tile_count": int(size.get("width", 0)) * int(size.get("height", 0)),
	}

func _terrain_summary_from_rows(rows: Array) -> Dictionary:
	var counts := {}
	var tile_count := 0
	for row_value in rows:
		if not (row_value is Array):
			continue
		for terrain_value in row_value:
			var terrain_id := String(terrain_value)
			counts[terrain_id] = int(counts.get(terrain_id, 0)) + 1
			tile_count += 1
	return {
		"tile_count": tile_count,
		"terrain_counts": counts,
		"categories": _terrain_categories_from_counts(counts),
	}

func _terrain_categories_from_counts(counts: Dictionary) -> Dictionary:
	var categories := {
		"land": 0,
		"water": 0,
		"underground": 0,
		"blocked": 0,
	}
	for terrain_id in counts.keys():
		var count := int(counts.get(terrain_id, 0))
		match String(terrain_id):
			"water":
				categories["water"] = int(categories.get("water", 0)) + count
				categories["blocked"] = int(categories.get("blocked", 0)) + count
			"rock":
				categories["blocked"] = int(categories.get("blocked", 0)) + count
			"underground":
				categories["underground"] = int(categories.get("underground", 0)) + count
				categories["land"] = int(categories.get("land", 0)) + count
			_:
				categories["land"] = int(categories.get("land", 0)) + count
	return categories

func _count_by_key(records: Array, key: String) -> Dictionary:
	var counts := {}
	for record_value in records:
		if not (record_value is Dictionary):
			continue
		var record: Dictionary = record_value
		var value := String(record.get(key, ""))
		if value == "":
			value = "unknown"
		counts[value] = int(counts.get(value, 0)) + 1
	return counts

func _records_without_kind(records: Array, excluded_kind: String) -> Array:
	var result := []
	for record_value in records:
		if record_value is Dictionary and String(record_value.get("kind", "")) != excluded_kind:
			result.append(record_value)
	return result

func _sorted_keys(value: Variant) -> Array:
	var keys := []
	if value is Dictionary:
		for key in value.keys():
			keys.append(String(key))
	keys.sort()
	return keys

func _unique_gap_records(gaps: Array) -> Array:
	var by_key := {}
	for gap_value in gaps:
		if not (gap_value is Dictionary):
			continue
		var gap: Dictionary = gap_value
		var key := "%s:%s" % [String(gap.get("code", "")), String(gap.get("case_id", ""))]
		if not by_key.has(key):
			by_key[key] = gap
	var result := []
	for key in _sorted_keys(by_key):
		result.append(by_key[key])
	return result

func _load_fixture() -> Dictionary:
	var file := FileAccess.open(FIXTURE_PATH, FileAccess.READ)
	if file == null:
		_fail("Could not open fixture %s." % FIXTURE_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		_fail("Fixture %s did not parse as a dictionary." % FIXTURE_PATH)
		return {}
	return parsed

func _assert_report_contract(report: Dictionary, expected_case_count: int) -> void:
	for field in REQUIRED_REPORT_FIELDS:
		if not report.has(field):
			_fail("Comparison report missed required field %s: %s" % [field, JSON.stringify(report)])
			return
	if String(report.get("schema_id", "")) != REPORT_SCHEMA_ID:
		_fail("Comparison report schema mismatch: %s" % JSON.stringify(report))
		return
	if int(report.get("case_count", 0)) != expected_case_count or report.get("cases", []).size() != expected_case_count:
		_fail("Comparison report case count mismatch: %s" % JSON.stringify(report.get("aggregate", {})))
		return
	if int(report.get("aggregate", {}).get("dimension_match_count", 0)) != expected_case_count:
		_fail("All comparison cases must match structural dimensions: %s" % JSON.stringify(report.get("aggregate", {})))
		return
	if int(report.get("aggregate", {}).get("player_count_match_count", 0)) != expected_case_count:
		_fail("All comparison cases must match player counts: %s" % JSON.stringify(report.get("aggregate", {})))
		return
	if not bool(report.get("aggregate", {}).get("all_native_foundation_components_reported", false)):
		_fail("Native did not report every implemented foundation component for each case: %s" % JSON.stringify(report.get("aggregate", {})))
		return
	if not bool(report.get("aggregate", {}).get("all_package_session_adoptions_ready", false)):
		_fail("Native package/session adoption conversion did not pass for each case: %s" % JSON.stringify(report.get("aggregate", {})))
		return
	var readiness: Dictionary = report.get("readiness", {}) if report.get("readiness", {}) is Dictionary else {}
	if bool(readiness.get("native_runtime_authoritative", true)) or bool(readiness.get("full_parity_claim", true)) or not bool(readiness.get("package_session_adoption_ready", false)):
		_fail("Comparison report readiness crossed the production claim boundary: %s" % JSON.stringify(readiness))
		return

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)

func _native_foundation_components_reported(native_summary: Dictionary) -> bool:
	var components := {}
	for phase_value in native_summary.get("phase_pipeline", []):
		if not (phase_value is Dictionary):
			continue
		var phase: Dictionary = phase_value
		if String(phase.get("validation_status", "")) == "pass":
			components[String(phase.get("component", ""))] = true
	for component in REQUIRED_NATIVE_PHASE_COMPONENTS:
		if not components.has(component):
			return false
	return true
