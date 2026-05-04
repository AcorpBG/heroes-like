extends Node

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")

const REPORT_ID := "NATIVE_RANDOM_MAP_GDSCRIPT_PORT_AUDIT_REPORT"

var _failed := false

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

	var supported_config: Dictionary = ScenarioSelectRulesScript.build_random_map_player_config(
		"native-rmg-gdscript-port-audit-10184-supported",
		"border_gate_compact_v1",
		"border_gate_compact_profile_v1",
		3,
		"land",
		false,
		"homm3_small"
	)
	var supported: Dictionary = service.generate_random_map(supported_config)
	_assert_supported_native_surfaces(supported)
	if _failed:
		return

	var foundation_config := {
		"seed": "native-rmg-gdscript-port-audit-10184-foundation",
		"size": {
			"width": 40,
			"height": 36,
			"level_count": 1,
			"size_class_id": "homm3_small",
			"water_mode": "land",
		},
		"player_constraints": {
			"human_count": 1,
			"computer_count": 3,
			"team_mode": "free_for_all",
		},
		"profile": {
			"id": "native_port_audit_foundation_profile",
			"template_id": "native_foundation_spoke",
			"terrain_ids": ["grass", "dirt", "rough", "snow"],
			"faction_ids": ["faction_embercourt", "faction_mireclaw", "faction_sunvault", "faction_thornwake"],
		},
	}
	var foundation: Dictionary = service.generate_random_map(foundation_config)
	_assert_foundation_native_surfaces(foundation)
	if _failed:
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"binding_kind": metadata.get("binding_kind", ""),
		"native_extension_loaded": metadata.get("native_extension_loaded", false),
		"supported_status": supported.get("status", ""),
		"supported_parity_config": supported.get("supported_parity_config", false),
		"connection_road_controls": supported.get("connection_road_controls", {}),
		"support_resource_count": _count_resource_sites_with_policy(supported.get("object_placements", [])),
		"artifact_guard_count": supported.get("materialized_object_guard_summary", {}).get("artifact_guard_count", 0),
		"foundation_status": foundation.get("status", ""),
		"river_quality_summary": foundation.get("river_quality_summary", {}),
		"decoration_route_shaping_summary": foundation.get("decoration_route_shaping_summary", {}),
		"town_spacing": foundation.get("town_guard_placement", {}).get("town_placement", {}).get("town_spacing", {}),
	})])
	get_tree().quit(0)

func _assert_supported_native_surfaces(generated: Dictionary) -> void:
	if not bool(generated.get("ok", false)):
		_fail("Supported native generation returned ok=false: %s" % JSON.stringify(generated))
		return
	if String(generated.get("status", "")) != "full_parity_supported" or not bool(generated.get("supported_parity_config", false)):
		_fail("Supported audit config did not stay in native full-parity scope: %s" % JSON.stringify(generated))
		return

	var road_controls: Dictionary = generated.get("connection_road_controls", {}) if generated.get("connection_road_controls", {}) is Dictionary else {}
	if String(road_controls.get("schema_id", "")) != "native_random_map_connection_road_controls_v1":
		_fail("Native connection road controls are missing: %s" % JSON.stringify(road_controls))
		return
	if int(road_controls.get("special_guard_gate_road_count", 0)) <= 0:
		_fail("Native road controls did not record any special guard gate road.")
		return

	var route_graph: Dictionary = generated.get("route_graph", {}) if generated.get("route_graph", {}) is Dictionary else {}
	var saw_front_policy := false
	for edge in route_graph.get("edges", []):
		if not (edge is Dictionary):
			continue
		if (edge as Dictionary).has("fairness_start_front_zones") and (edge as Dictionary).has("layout_contract_roles"):
			saw_front_policy = true
			break
	if not saw_front_policy:
		_fail("Native route graph did not expose start-front fairness metadata.")
		return

	var support_resource_count := _count_resource_sites_with_policy(generated.get("object_placements", []))
	if support_resource_count <= 0:
		_fail("Native object placement did not expose path-scored support resource placement policy.")
		return

	var saw_artifact_reward := false
	for object in generated.get("object_placements", []):
		if object is Dictionary and String((object as Dictionary).get("artifact_id", "")) != "":
			saw_artifact_reward = true
			break
	if not saw_artifact_reward:
		_fail("Native object placement did not include guarded artifact reward candidates.")
		return

	var guard_summary: Dictionary = generated.get("materialized_object_guard_summary", {}) if generated.get("materialized_object_guard_summary", {}) is Dictionary else {}
	if String(guard_summary.get("schema_id", "")) != "native_random_map_materialized_object_guard_summary_v1":
		_fail("Native object guard materialization summary is missing: %s" % JSON.stringify(guard_summary))
		return
	if int(guard_summary.get("artifact_candidate_count", 0)) > 0 and int(guard_summary.get("artifact_guard_count", 0)) <= 0:
		_fail("Native artifact candidates were not prioritized into materialized object guards: %s" % JSON.stringify(guard_summary))
		return

	var zone_layout: Dictionary = generated.get("zone_layout", {}) if generated.get("zone_layout", {}) is Dictionary else {}
	var saw_richness_floor := false
	for zone in zone_layout.get("zones", []):
		if not (zone is Dictionary):
			continue
		var metadata: Dictionary = (zone as Dictionary).get("catalog_metadata", {}) if (zone as Dictionary).get("catalog_metadata", {}) is Dictionary else {}
		if metadata.has("richness_floor") and metadata.has("mine_requirements") and metadata.has("treasure_bands"):
			saw_richness_floor = true
			break
	if not saw_richness_floor:
		_fail("Native zones did not expose richness-floor metadata.")
		return

func _assert_foundation_native_surfaces(generated: Dictionary) -> void:
	if not bool(generated.get("ok", false)):
		_fail("Foundation native generation returned ok=false: %s" % JSON.stringify(generated))
		return
	if String(generated.get("status", "")) != "partial_foundation":
		_fail("Foundation audit config unexpectedly changed status: %s" % JSON.stringify(generated))
		return

	var river_summary: Dictionary = generated.get("river_quality_summary", {}) if generated.get("river_quality_summary", {}) is Dictionary else {}
	if int(river_summary.get("land_river_candidate_count", 0)) <= 0 or int(river_summary.get("land_river_with_crossing_count", 0)) <= 0:
		_fail("Native land river crossing quality summary did not record crossed land rivers: %s" % JSON.stringify(river_summary))
		return
	if int(river_summary.get("river_continuity_failure_count", 0)) != 0:
		_fail("Native river quality recorded continuity failures: %s" % JSON.stringify(river_summary))
		return

	var river_network: Dictionary = generated.get("river_network", {}) if generated.get("river_network", {}) is Dictionary else {}
	var saw_passed_land_river := false
	for segment in river_network.get("river_segments", []):
		if not (segment is Dictionary):
			continue
		if String((segment as Dictionary).get("route_feature_class", "")) == "land_river_with_road_crossing_constraints":
			saw_passed_land_river = String((segment as Dictionary).get("continuity_status", "")) == "pass" and int((segment as Dictionary).get("road_crossing_count", 0)) > 0
			break
	if not saw_passed_land_river:
		_fail("Native land river segment did not prove continuity plus a recorded road crossing.")
		return

	var decoration_summary: Dictionary = generated.get("decoration_route_shaping_summary", {}) if generated.get("decoration_route_shaping_summary", {}) is Dictionary else {}
	if String(decoration_summary.get("schema_id", "")) != "native_random_map_decoration_route_shaping_v1":
		_fail("Native decoration route-shaping summary is missing: %s" % JSON.stringify(decoration_summary))
		return
	if int(decoration_summary.get("multitile_decoration_count", 0)) <= 0 or int(decoration_summary.get("blocking_body_tile_total", 0)) <= int(decoration_summary.get("multitile_decoration_count", 0)):
		_fail("Native decorative obstacle body masks did not materialize as multi-tile blockers: %s" % JSON.stringify(decoration_summary))
		return

	var town_payload: Dictionary = generated.get("town_guard_placement", {}).get("town_placement", {}) if generated.get("town_guard_placement", {}) is Dictionary else {}
	var town_spacing: Dictionary = town_payload.get("town_spacing", {}) if town_payload.get("town_spacing", {}) is Dictionary else {}
	if not bool(town_spacing.get("ok", false)) or String(town_spacing.get("all_towns", {}).get("status", "")) != "pass" or String(town_spacing.get("start_towns", {}).get("status", "")) != "pass":
		_fail("Native town spacing did not pass: %s" % JSON.stringify(town_spacing))
		return

	var guard_summary: Dictionary = generated.get("materialized_object_guard_summary", {}) if generated.get("materialized_object_guard_summary", {}) is Dictionary else {}
	if int(guard_summary.get("guarded_valuable_object_count", 0)) <= 0:
		_fail("Native foundation object guard summary did not record guarded valuable objects: %s" % JSON.stringify(guard_summary))
		return

func _count_resource_sites_with_policy(objects: Array) -> int:
	var count := 0
	for object in objects:
		if not (object is Dictionary):
			continue
		if String((object as Dictionary).get("kind", "")) == "resource_site" and String((object as Dictionary).get("placement_policy", "")) == "strict_start_zone_support_resource_path_scored" and int((object as Dictionary).get("support_route_path_length", 0)) > 0:
			count += 1
	return count

func _fail(message: String) -> void:
	_failed = true
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
