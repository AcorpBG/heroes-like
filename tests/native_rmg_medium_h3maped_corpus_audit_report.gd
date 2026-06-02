extends Node

const REPORT_ID := "NATIVE_RMG_MEDIUM_H3MAPED_CORPUS_AUDIT_REPORT"

const CASES := [
	{
		"case_id": "medium_2p_seed_28_controlled",
		"seed": "28",
		"players": 2,
		"source_catalog_index": 35,
		"source_template_id": "h3maped_template_035",
	},
	{
		"case_id": "medium_3p_seed_11_controlled",
		"seed": "11",
		"players": 3,
		"source_catalog_index": 37,
		"source_template_id": "h3maped_template_037",
	},
	{
		"case_id": "medium_4p_seed_10_controlled",
		"seed": "10",
		"players": 4,
		"source_catalog_index": 15,
		"source_template_id": "h3maped_template_015",
	},
]

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not ClassDB.class_exists("MapPackageService"):
		_fail("MapPackageService native class is not available.")
		return
	var service: Variant = ClassDB.instantiate("MapPackageService")
	var case_reports := []
	for case in CASES:
		var report := _validate_case(service, case)
		if not bool(report.get("ok", false)):
			_fail("%s failed: %s" % [String(case.get("case_id", "")), JSON.stringify(report)])
			return
		case_reports.append(report)
	var runtime_report := _validate_runtime_generation_contract(service)
	if not bool(runtime_report.get("ok", false)):
		_fail("runtime contract failed: %s" % JSON.stringify(runtime_report))
		return
	print("%s: %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"case_count": case_reports.size(),
		"cases": case_reports,
		"runtime_generation_contract": runtime_report,
	})])
	get_tree().quit(0)

func _validate_case(service: Variant, expected: Dictionary) -> Dictionary:
	var config := _medium_land_config(String(expected.get("seed", "")), int(expected.get("players", 0)))
	var inspection: Dictionary = service.inspect_h3maped_small_rmg_port(config)
	var selection: Dictionary = inspection.get("selection_identity", {}) if inspection.get("selection_identity", {}) is Dictionary else {}
	var package_adoption: Dictionary = inspection.get("public_package_adoption", {}) if inspection.get("public_package_adoption", {}) is Dictionary else {}
	var final_writeout: Dictionary = inspection.get("final_h3m_writeout", {}) if inspection.get("final_h3m_writeout", {}) is Dictionary else {}
	var validator: Dictionary = inspection.get("fast_structural_validator", {}) if inspection.get("fast_structural_validator", {}) is Dictionary else {}
	var metrics: Dictionary = validator.get("metrics", {}) if validator.get("metrics", {}) is Dictionary else {}
	var players := int(expected.get("players", 0))
	var ok := bool(inspection.get("ok", false)) \
			and bool(selection.get("ok", false)) \
			and String(selection.get("source_template_id", "")) == String(expected.get("source_template_id", "")) \
			and int(selection.get("source_catalog_index", -1)) == int(expected.get("source_catalog_index", -1)) \
			and String(package_adoption.get("status", "")) == "strict_package_adoption_draft_materialized_runtime_blocked" \
			and String(final_writeout.get("status", "")) == "strict_final_0x49b2b6_writeout_draft_runtime_blocked" \
			and int(final_writeout.get("tile_byte_array_count", 0)) == 7 \
			and int(final_writeout.get("tile_byte_array_size", 0)) == 5184 \
			and int(final_writeout.get("road_overlay_type_nonzero_count", 0)) > 0 \
			and String(validator.get("status", "")) == "strict_fast_structural_validator_pass_public_generation_ready" \
			and int(validator.get("failure_count", -1)) == 0 \
			and int(metrics.get("width", 0)) == 72 \
			and int(metrics.get("height", 0)) == 72 \
			and int(metrics.get("level_count", 0)) == 1 \
			and int(metrics.get("expected_tile_count", 0)) == 5184 \
			and int(metrics.get("terrain_tile_count", 0)) == 5184 \
			and int(metrics.get("player_start_count", 0)) == players \
			and int(metrics.get("owned_player_town_count", 0)) == players \
			and int(metrics.get("neutral_town_count", 0)) > 0 \
			and int(metrics.get("mine_count", 0)) > 0 \
			and int(metrics.get("reward_count", 0)) > 0 \
			and int(metrics.get("connection_blocker_count", 0)) > 0 \
			and int(metrics.get("blocking_connection_blocker_count", 0)) == int(metrics.get("connection_blocker_count", 0)) \
			and int(metrics.get("connection_guard_count", 0)) > 0 \
			and int(metrics.get("blocking_connection_guard_count", 0)) == int(metrics.get("connection_guard_count", 0)) \
			and int(metrics.get("route_link_count", 0)) > 0 \
			and int(metrics.get("route_link_without_blocker_count", -1)) == 0 \
			and int(metrics.get("route_link_without_guard_count", -1)) == 0 \
			and int(metrics.get("road_record_count", 0)) > 0 \
			and int(metrics.get("road_segment_disconnected_count", -1)) == 0 \
			and int(metrics.get("road_segment_short_loop_count", -1)) == 0 \
			and int(metrics.get("duplicate_placement_id_count", -1)) == 0 \
			and int(metrics.get("out_of_bounds_object_count", -1)) == 0 \
			and int(metrics.get("exact_h3m_body_block_mismatch_count", -1)) == 0 \
			and int(metrics.get("guard_body_not_blocking_count", -1)) == 0 \
			and int(metrics.get("guard_engagement_missing_count", -1)) == 0 \
			and int(metrics.get("package_block_trim_marker_count", -1)) == 0 \
			and int(metrics.get("runtime_start_blocked_by_exact_h3m_masks_count", -1)) == 0 \
			and int(package_adoption.get("decorative_obstacle_package_object_count", 0)) > 0 \
			and int(package_adoption.get("connection_blocker_package_object_count", 0)) > 0 \
			and int(package_adoption.get("connection_guard_package_object_count", 0)) > 0 \
			and int(package_adoption.get("road_package_segment_count", 0)) > 0
	return {
		"ok": ok,
		"case_id": expected.get("case_id", ""),
		"source_template_id": selection.get("source_template_id", ""),
		"source_catalog_index": selection.get("source_catalog_index", -1),
		"tile_byte_array_size": final_writeout.get("tile_byte_array_size", 0),
		"validator_status": validator.get("status", ""),
		"validator_failure_count": validator.get("failure_count", -1),
		"metrics": {
			"player_start_count": metrics.get("player_start_count", 0),
			"owned_player_town_count": metrics.get("owned_player_town_count", 0),
			"neutral_town_count": metrics.get("neutral_town_count", 0),
			"mine_count": metrics.get("mine_count", 0),
			"reward_count": metrics.get("reward_count", 0),
			"connection_blocker_count": metrics.get("connection_blocker_count", 0),
			"connection_guard_count": metrics.get("connection_guard_count", 0),
			"road_record_count": metrics.get("road_record_count", 0),
			"decorative_obstacle_package_object_count": package_adoption.get("decorative_obstacle_package_object_count", 0),
		},
	}

func _validate_runtime_generation_contract(service: Variant) -> Dictionary:
	var generated: Dictionary = service.generate_random_map(_medium_land_config("10", 4))
	var validator: Dictionary = generated.get("fast_structural_validator", {}) if generated.get("fast_structural_validator", {}) is Dictionary else {}
	var final_summary: Dictionary = generated.get("final_writeout_summary", {}) if generated.get("final_writeout_summary", {}) is Dictionary else {}
	var adoption_summary: Dictionary = generated.get("public_package_adoption_summary", {}) if generated.get("public_package_adoption_summary", {}) is Dictionary else {}
	var payload: Dictionary = generated.get("map_document_payload", {}) if generated.get("map_document_payload", {}) is Dictionary else {}
	var ok := bool(generated.get("ok", false)) \
			and String(generated.get("generation_status", "")) == "h3maped_medium_validated_package_ready" \
			and String(generated.get("full_generation_status", "")) == "h3maped_medium_public_package_production_ready_strict_medium_land" \
			and String(generated.get("production_ready_scope", "")) == "strict_medium_72x72_one_level_land_only" \
			and bool(generated.get("runtime_generation_allowed", false)) \
			and bool(generated.get("public_runtime_authoritative", false)) \
			and not payload.is_empty() \
			and String(payload.get("source_kind", "")) == "generated_h3maped_medium_validated" \
			and int(payload.get("width", 0)) == 72 \
			and int(payload.get("height", 0)) == 72 \
			and int(payload.get("level_count", 0)) == 1 \
			and String(validator.get("status", "")) == "strict_fast_structural_validator_pass_public_generation_ready" \
			and int(validator.get("failure_count", -1)) == 0 \
			and int(final_summary.get("tile_byte_array_size", 0)) == 5184 \
			and int(adoption_summary.get("player_start_count", 0)) == 4
	return {
		"ok": ok,
		"generation_status": generated.get("generation_status", ""),
		"full_generation_status": generated.get("full_generation_status", ""),
		"production_ready_scope": generated.get("production_ready_scope", ""),
		"runtime_generation_allowed": generated.get("runtime_generation_allowed", false),
		"has_map_document_payload": generated.has("map_document_payload"),
		"validator_status": validator.get("status", ""),
		"final_tile_byte_array_size": final_summary.get("tile_byte_array_size", 0),
	}

func _medium_land_config(seed: String, player_count: int) -> Dictionary:
	return {
		"seed": seed,
		"size": {
			"width": 72,
			"height": 72,
			"level_count": 1,
			"water_mode": "land",
			"size_class_id": "homm3_medium",
		},
		"player_constraints": {
			"human_count": 1,
			"player_count": player_count,
			"team_mode": "free_for_all",
		},
	}

func _fail(message: String) -> void:
	push_error("%s: %s" % [REPORT_ID, message])
	get_tree().quit(1)
