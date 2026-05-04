extends Node

const RandomMapGeneratorRulesScript = preload("res://scripts/core/RandomMapGeneratorRules.gd")
const REPORT_ID := "RANDOM_MAP_HOMM3_PARITY_RICHNESS_REPORT"
const ARTIFACT_DIR := "res://.artifacts/rmg_parity_richness"
const MAX_TOTAL_MSEC := 45000
const MAX_CASE_MSEC := 18000

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var started_msec := Time.get_ticks_msec()
	var results := []
	var failures := []
	_ensure_artifact_dir()
	for case in _cases():
		var result := _inspect_case(case)
		results.append(result)
		failures.append_array(result.get("failures", []))
		_write_case_artifacts(result)
		print("%s_CASE %s" % [REPORT_ID, JSON.stringify(_case_log_line(result))])
		if Time.get_ticks_msec() - started_msec > MAX_TOTAL_MSEC:
			failures.append("report exceeded total runtime budget %d ms" % MAX_TOTAL_MSEC)
			break
	var summary := _summary(results)
	var report := {
		"ok": failures.is_empty(),
		"report_id": REPORT_ID,
		"case_count": results.size(),
		"runtime_msec": Time.get_ticks_msec() - started_msec,
		"runtime_budget_msec": MAX_TOTAL_MSEC,
		"summary": summary,
		"cases": results,
		"failures": failures,
		"artifact_dir": ARTIFACT_DIR,
	}
	_write_json("%s/summary.json" % ARTIFACT_DIR, report)
	if not failures.is_empty():
		_fail("RMG richness report failed: %s" % JSON.stringify(failures))
		return
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"case_count": results.size(),
		"runtime_msec": report.get("runtime_msec", 0),
		"summary": summary,
		"artifact_dir": ARTIFACT_DIR,
	})])
	get_tree().quit(0)

func _cases() -> Array:
	return [
		{"id": "small_compact_land_a", "seed": "rmg-richness-small-a-10184", "width": 36, "height": 36, "water_mode": "land", "level_count": 1, "player_count": 3, "template_id": "border_gate_compact_v1", "profile_id": "border_gate_compact_profile_v1"},
		{"id": "small_compact_land_b", "seed": "rmg-richness-small-b-10184", "width": 36, "height": 36, "water_mode": "land", "level_count": 1, "player_count": 3, "template_id": "border_gate_compact_v1", "profile_id": "border_gate_compact_profile_v1"},
		{"id": "medium_translated_land_033", "seed": "rmg-richness-medium-033-10184", "width": 72, "height": 72, "water_mode": "land", "level_count": 1, "player_count": 4, "template_id": "translated_rmg_template_033_v1", "profile_id": "translated_rmg_profile_033_v1"},
		{"id": "small_translated_islands_001", "seed": "rmg-richness-islands-001-10184", "width": 36, "height": 36, "water_mode": "islands", "level_count": 1, "player_count": 4, "template_id": "translated_rmg_template_001_v1", "profile_id": "translated_rmg_profile_001_v1"},
	]

func _inspect_case(case: Dictionary) -> Dictionary:
	var started_msec := Time.get_ticks_msec()
	var generation: Dictionary = RandomMapGeneratorRulesScript.generate(_config(case))
	var elapsed_msec := Time.get_ticks_msec() - started_msec
	var payload: Dictionary = generation.get("generated_map", {}) if generation.get("generated_map", {}) is Dictionary else {}
	var validation_report: Dictionary = generation.get("report", {}) if generation.get("report", {}) is Dictionary else {}
	var staging: Dictionary = payload.get("staging", {}) if payload.get("staging", {}) is Dictionary else {}
	var scenario: Dictionary = payload.get("scenario_record", {}) if payload.get("scenario_record", {}) is Dictionary else {}
	var roads_rivers: Dictionary = staging.get("roads_rivers_writeout", {}) if staging.get("roads_rivers_writeout", {}) is Dictionary else {}
	var roads: Dictionary = roads_rivers.get("road_overlay", {}) if roads_rivers.get("road_overlay", {}) is Dictionary else {}
	var rivers: Dictionary = roads_rivers.get("river_water_coast_overlay", {}) if roads_rivers.get("river_water_coast_overlay", {}) is Dictionary else {}
	var connection_guards: Dictionary = staging.get("connection_guard_materialization", {}) if staging.get("connection_guard_materialization", {}) is Dictionary else {}
	var connection_guard_summary: Dictionary = connection_guards.get("summary", {}) if connection_guards.get("summary", {}) is Dictionary else {}
	var road_summary: Dictionary = roads.get("summary", {}) if roads.get("summary", {}) is Dictionary else {}
	var town_payload: Dictionary = staging.get("town_mine_dwelling_placement", {}) if staging.get("town_mine_dwelling_placement", {}) is Dictionary else {}
	var town_spacing: Dictionary = town_payload.get("validation", {}).get("town_spacing", {}) if town_payload.get("validation", {}) is Dictionary and town_payload.get("validation", {}).get("town_spacing", {}) is Dictionary else {}
	var start_town_spacing: Dictionary = town_spacing.get("start_towns", {}) if town_spacing.get("start_towns", {}) is Dictionary else {}
	var same_zone_town_spacing: Dictionary = town_spacing.get("same_zone_towns", {}) if town_spacing.get("same_zone_towns", {}) is Dictionary else {}
	var route_reward_summary: Dictionary = staging.get("materialized_route_reward_summary", {}) if staging.get("materialized_route_reward_summary", {}) is Dictionary else {}
	var object_guard_summary: Dictionary = staging.get("materialized_object_guard_summary", {}) if staging.get("materialized_object_guard_summary", {}) is Dictionary else {}
	var decor: Dictionary = staging.get("decoration_density_pass", {}) if staging.get("decoration_density_pass", {}) is Dictionary else {}
	var decor_summary: Dictionary = decor.get("summary", {}) if decor.get("summary", {}) is Dictionary else {}
	var decor_route_shaping: Dictionary = decor.get("route_shaping_summary", {}) if decor.get("route_shaping_summary", {}) is Dictionary else {}
	var serialization: Dictionary = roads_rivers.get("generated_map_serialization", {}) if roads_rivers.get("generated_map_serialization", {}) is Dictionary else {}
	var guarded_choke_routes := _intersection_count(decor_route_shaping.get("required_routes_with_chokes", []), roads.get("connection_controlled_route_edge_ids", []))
	var town_distances := _town_distance_summary(scenario.get("towns", []))
	var artifact_count: int = scenario.get("artifact_nodes", []).size() if scenario.get("artifact_nodes", []) is Array else 0
	var associated_guard_count: int = staging.get("materialized_object_guards", []).size() if staging.get("materialized_object_guards", []) is Array else 0
	var guarded_artifact_ratio: float = float(associated_guard_count) / float(max(1, artifact_count))
	var artifact_guard_summary := _artifact_guard_summary(scenario.get("artifact_nodes", []), staging.get("materialized_object_guards", []))
	var zone_richness := _zone_richness_summary(payload)
	var reward_bands := _reward_band_summary(staging.get("monster_reward_bands", {}))
	var template_id := String(payload.get("metadata", {}).get("template_id", ""))
	var fairness_report: Dictionary = staging.get("fairness_report", {}) if staging.get("fairness_report", {}) is Dictionary else {}
	var fairness_warning_review := _fairness_warning_review(fairness_report, template_id)
	var fairness_metrics := _fairness_layout_quality_metrics(fairness_report, fairness_warning_review)
	var metrics := {
		"ok": bool(generation.get("ok", false)),
		"elapsed_msec": elapsed_msec,
		"validation_failure_count": validation_report.get("failures", []).size() if validation_report.get("failures", []) is Array else 0,
		"stable_signature": String(payload.get("stable_signature", "")),
		"template_id": template_id,
		"profile_id": String(payload.get("metadata", {}).get("profile", {}).get("id", "")),
		"width": int(case.get("width", 0)),
		"height": int(case.get("height", 0)),
		"water_mode": String(case.get("water_mode", "land")),
		"zone_count": staging.get("zones", []).size() if staging.get("zones", []) is Array else 0,
		"link_count": staging.get("template", {}).get("links", []).size() if staging.get("template", {}).get("links", []) is Array else 0,
		"town_count": scenario.get("towns", []).size() if scenario.get("towns", []) is Array else 0,
		"mine_count": int(town_payload.get("summary", {}).get("mine_count", 0)),
		"dwelling_count": int(town_payload.get("summary", {}).get("dwelling_count", 0)),
		"artifact_count": artifact_count,
		"route_reward_artifact_node_count": int(route_reward_summary.get("artifact_node_count", 0)),
		"encounter_count": scenario.get("encounters", []).size() if scenario.get("encounters", []) is Array else 0,
		"associated_object_guard_count": associated_guard_count,
		"guarded_artifact_ratio": snapped(guarded_artifact_ratio, 0.001),
		"guarded_artifact_count": int(artifact_guard_summary.get("guarded_artifact_count", 0)),
		"guarded_artifact_missing_count": int(artifact_guard_summary.get("missing_count", 0)),
		"guarded_artifact_adjacent_count": int(artifact_guard_summary.get("adjacent_count", 0)),
		"guarded_artifact_max_distance": int(artifact_guard_summary.get("max_distance", 0)),
		"guarded_artifact_coverage_ratio": snapped(float(artifact_guard_summary.get("guarded_artifact_count", 0)) / float(max(1, artifact_count)), 0.001),
		"object_guard_artifact_node_count_seen": int(object_guard_summary.get("artifact_node_count_seen", 0)),
		"object_guard_route_reward_artifact_count_seen": int(object_guard_summary.get("route_reward_artifact_record_count_seen", 0)),
		"object_guard_artifact_guard_count": int(object_guard_summary.get("artifact_guard_count", 0)),
		"object_guard_candidate_count": int(object_guard_summary.get("candidate_count", 0)),
		"guardable_valuable_object_count": int(object_guard_summary.get("guardable_valuable_object_count", 0)),
		"guarded_valuable_object_count": int(object_guard_summary.get("guarded_valuable_object_count", 0)),
		"unguarded_valuable_object_count": int(object_guard_summary.get("unguarded_valuable_object_count", 0)),
		"guarded_mine_count": int(object_guard_summary.get("mine_guard_count", 0)),
		"guardable_mine_count": int(object_guard_summary.get("mine_candidate_count", 0)),
		"guarded_dwelling_count": int(object_guard_summary.get("dwelling_guard_count", 0)),
		"guardable_dwelling_count": int(object_guard_summary.get("dwelling_candidate_count", 0)),
		"guarded_reward_object_count": int(object_guard_summary.get("route_reward_guard_count", 0)),
		"guardable_reward_object_count": int(object_guard_summary.get("route_reward_candidate_count", 0)),
		"object_guard_skipped_no_cell": int(object_guard_summary.get("skipped_no_cell", 0)),
		"decoration_count": int(decor_summary.get("record_count", 0)),
		"decoration_blocking_body_tile_total": int(decor_summary.get("blocking_body_tile_total", 0)),
		"multitile_decoration_count": int(decor_summary.get("multitile_decoration_count", 0)),
		"decoration_body_density": snapped(float(decor_summary.get("blocking_body_tile_total", 0)) / float(max(1, int(case.get("width", 0)) * int(case.get("height", 0)))), 0.0001),
		"route_shoulder_body_count": int(decor_route_shaping.get("route_shoulder_body_count", decor_summary.get("route_shoulder_body_count", 0))),
		"route_shoulder_decoration_count": int(decor_route_shaping.get("route_shoulder_decoration_count", decor_summary.get("route_shoulder_decoration_count", 0))),
		"route_shoulder_guard_body_count": int(decor_route_shaping.get("route_shoulder_guard_body_count", 0)),
		"route_shoulder_guard_count": int(decor_route_shaping.get("route_shoulder_guard_count", 0)),
		"required_route_count": int(decor_route_shaping.get("required_route_count", decor_summary.get("required_route_count", 0))),
		"required_route_with_shoulder_count": int(decor_route_shaping.get("required_route_with_shoulder_count", decor_summary.get("required_route_with_shoulder_count", 0))),
		"required_route_shoulder_coverage_ratio": float(decor_route_shaping.get("required_route_shoulder_coverage_ratio", 0.0)),
		"choked_road_tile_count": int(decor_route_shaping.get("choked_road_tile_count", decor_summary.get("choked_road_tile_count", 0))),
		"required_route_with_choke_count": int(decor_route_shaping.get("required_route_with_choke_count", decor_summary.get("required_route_with_choke_count", 0))),
		"guarded_choke_route_count": guarded_choke_routes,
		"road_tile_count": int(road_summary.get("tile_count", 0)),
		"road_segment_count": int(road_summary.get("segment_count", 0)),
		"road_class_counts": road_summary.get("road_class_counts", {}),
		"expected_connection_guard_road_control_count": int(road_summary.get("expected_connection_guard_road_control_count", 0)),
		"connection_guard_road_control_count": int(road_summary.get("connection_guard_road_control_count", 0)),
		"missing_connection_guard_road_control_count": int(road_summary.get("missing_connection_guard_road_control_count", 0)),
		"expected_wide_suppression_road_count": int(road_summary.get("expected_wide_suppression_road_count", 0)),
		"wide_suppressed_route_count": int(road_summary.get("wide_suppressed_route_count", 0)),
		"expected_special_guard_gate_road_count": int(road_summary.get("expected_special_guard_gate_road_count", 0)),
		"special_guard_gate_road_count": int(road_summary.get("special_guard_gate_road_count", 0)),
		"expected_normal_connection_guard_count": int(connection_guard_summary.get("expected_normal_guard_count", 0)),
		"normal_connection_guard_count": int(connection_guard_summary.get("normal_guard_count", 0)),
		"expected_special_connection_guard_count": int(connection_guard_summary.get("expected_special_guard_gate_count", 0)),
		"special_connection_guard_count": int(connection_guard_summary.get("special_guard_gate_count", 0)),
		"expected_wide_suppression_count": int(connection_guard_summary.get("expected_wide_suppression_count", 0)),
		"wide_suppression_count": int(connection_guard_summary.get("wide_suppression_count", 0)),
		"river_candidate_count": int(rivers.get("summary", {}).get("river_candidate_count", 0)),
		"coherent_river_candidate_count": int(rivers.get("summary", {}).get("coherent_river_candidate_count", 0)),
		"river_continuity_failure_count": int(rivers.get("summary", {}).get("river_continuity_failure_count", 0)),
		"isolated_river_fragment_count": int(rivers.get("summary", {}).get("isolated_river_fragment_count", 0)),
		"river_body_conflict_count": int(rivers.get("summary", {}).get("river_body_conflict_count", 0)),
		"river_road_crossing_count": int(rivers.get("summary", {}).get("river_road_crossing_count", 0)),
		"land_river_candidate_count": int(rivers.get("summary", {}).get("land_river_candidate_count", 0)),
		"land_river_with_crossing_count": int(rivers.get("summary", {}).get("land_river_with_crossing_count", 0)),
		"water_tile_count": int(rivers.get("summary", {}).get("water_tile_count", 0)),
		"object_instance_count": serialization.get("object_instances", []).size() if serialization.get("object_instances", []) is Array else 0,
		"minimum_town_distance_required": int(town_payload.get("summary", {}).get("minimum_town_distance_required", 0)),
		"observed_minimum_town_distance": int(town_payload.get("summary", {}).get("observed_minimum_town_distance", town_distances.get("minimum", 0))),
		"direct_minimum_town_distance": int(town_distances.get("minimum", 0)),
		"start_town_minimum_distance_required": int(start_town_spacing.get("minimum_distance_required", town_payload.get("summary", {}).get("start_town_minimum_distance_required", 0))),
		"observed_start_town_minimum_distance": int(start_town_spacing.get("observed_minimum_distance", town_payload.get("summary", {}).get("observed_start_town_minimum_distance", 0))),
		"same_zone_town_pair_count": int(same_zone_town_spacing.get("pair_count", town_payload.get("summary", {}).get("same_zone_town_pair_count", 0))),
		"same_zone_town_minimum_distance_required": int(same_zone_town_spacing.get("minimum_distance_required", town_payload.get("summary", {}).get("same_zone_town_minimum_distance_required", 0))),
		"observed_same_zone_town_minimum_distance": int(same_zone_town_spacing.get("observed_minimum_distance", town_payload.get("summary", {}).get("observed_same_zone_town_minimum_distance", 0))),
		"eligible_zone_count": int(zone_richness.get("eligible_zone_count", 0)),
		"rich_zone_count": int(zone_richness.get("rich_zone_count", 0)),
		"poor_zone_count": int(zone_richness.get("poor_zone_count", 0)),
		"per_zone_richness_min": int(zone_richness.get("per_zone_richness_min", 0)),
		"object_category_coverage_count": int(zone_richness.get("object_category_coverage_count", 0)),
		"reward_band_record_count": int(reward_bands.get("record_count", 0)),
		"template_reward_band_record_count": int(reward_bands.get("template_record_count", 0)),
		"fallback_reward_band_record_count": int(reward_bands.get("fallback_record_count", 0)),
		"reward_band_value_min": int(reward_bands.get("value_min", 0)),
		"reward_band_value_max": int(reward_bands.get("value_max", 0)),
		"reward_band_source_counts": reward_bands.get("source_counts", {}),
		"fairness_status": String(fairness_metrics.get("fairness_status", "")),
		"fairness_warning_count": int(fairness_metrics.get("fairness_warning_count", 0)),
		"fairness_fail_threshold_warning_count": int(fairness_metrics.get("fairness_fail_threshold_warning_count", 0)),
		"fairness_accepted_asymmetry_warning_count": int(fairness_metrics.get("fairness_accepted_asymmetry_warning_count", 0)),
		"fairness_unresolved_review_warning_count": int(fairness_metrics.get("fairness_unresolved_review_warning_count", 0)),
		"fairness_layout_quality_status": String(fairness_metrics.get("fairness_layout_quality_status", "")),
		"early_resource_status": String(fairness_metrics.get("early_resource_status", "")),
		"contested_front_status": String(fairness_metrics.get("contested_front_status", "")),
		"guard_pressure_status": String(fairness_metrics.get("guard_pressure_status", "")),
		"travel_distance_status": String(fairness_metrics.get("travel_distance_status", "")),
		"core_economy_producer_status": String(fairness_metrics.get("core_economy_producer_status", "")),
		"contested_objective_pressure_status": String(fairness_metrics.get("contested_objective_pressure_status", "")),
		"contest_route_distance_spread": int(fairness_metrics.get("contest_route_distance_spread", 0)),
		"travel_contest_route_distance_spread": int(fairness_metrics.get("travel_contest_route_distance_spread", 0)),
		"contest_guard_pressure_spread": int(fairness_metrics.get("contest_guard_pressure_spread", 0)),
		"route_guard_pressure_spread": int(fairness_metrics.get("route_guard_pressure_spread", 0)),
		"town_to_resource_distance_spread": int(fairness_metrics.get("town_to_resource_distance_spread", 0)),
	}
	var failures := _metric_failures(String(case.get("id", "")), metrics)
	return {
		"id": String(case.get("id", "")),
		"config": case,
		"metrics": metrics,
		"failures": failures,
		"validation_report": validation_report,
		"fairness_warning_review": fairness_warning_review,
		"zone_richness": zone_richness,
		"reward_band_summary": reward_bands,
		"artifact_guard_summary": artifact_guard_summary,
		"artifact_node_samples": _sample_dictionaries(scenario.get("artifact_nodes", []), 8),
		"materialized_object_guard_samples": _sample_dictionaries(staging.get("materialized_object_guards", []), 8),
		"decoration_samples": _sample_dictionaries(decor.get("decoration_records", []), 4),
		"preview": _ascii_preview(payload),
	}

func _config(case: Dictionary) -> Dictionary:
	return {
		"generator_version": RandomMapGeneratorRulesScript.GENERATOR_VERSION,
		"seed": String(case.get("seed", "")),
		"size": {
			"preset": String(case.get("id", "")),
			"width": int(case.get("width", 36)),
			"height": int(case.get("height", 36)),
			"water_mode": String(case.get("water_mode", "land")),
			"level_count": int(case.get("level_count", 1)),
		},
		"player_constraints": {"human_count": 1, "player_count": int(case.get("player_count", 3)), "team_mode": "free_for_all"},
		"profile": {
			"id": String(case.get("profile_id", "")),
			"template_id": String(case.get("template_id", "")),
			"guard_strength_profile": "core_low",
		},
	}

func _zone_richness_summary(payload: Dictionary) -> Dictionary:
	var staging: Dictionary = payload.get("staging", {}) if payload.get("staging", {}) is Dictionary else {}
	var scenario: Dictionary = payload.get("scenario_record", {}) if payload.get("scenario_record", {}) is Dictionary else {}
	var zones: Array = staging.get("zones", []) if staging.get("zones", []) is Array else []
	var town_payload: Dictionary = staging.get("town_mine_dwelling_placement", {}) if staging.get("town_mine_dwelling_placement", {}) is Dictionary else {}
	var decor: Dictionary = staging.get("decoration_density_pass", {}) if staging.get("decoration_density_pass", {}) is Dictionary else {}
	var monster_rewards: Dictionary = staging.get("monster_reward_bands", {}) if staging.get("monster_reward_bands", {}) is Dictionary else {}
	var by_zone := {}
	for zone in zones:
		if not (zone is Dictionary):
			continue
		var zone_id := String(zone.get("id", ""))
		var role := String(zone.get("role", ""))
		if _zone_role_is_connector(role):
			continue
		by_zone[zone_id] = {
			"zone_id": zone_id,
			"role": role,
			"cell_count": int(zone.get("cell_count", 0)),
			"categories": {},
			"score": 0,
			"minimum_score": 4,
			"poor": false,
		}
	for town in town_payload.get("town_start_records", []):
		if town is Dictionary:
			_zone_richness_add(by_zone, String(town.get("zone_id", "")), "town")
	for mine in town_payload.get("mine_resource_producer_records", []):
		if mine is Dictionary:
			_zone_richness_add(by_zone, String(mine.get("zone_id", "")), "mine")
	for dwelling in town_payload.get("dwelling_recruitment_site_records", []):
		if dwelling is Dictionary:
			_zone_richness_add(by_zone, String(dwelling.get("zone_id", "")), "dwelling")
	for resource in scenario.get("resource_nodes", []):
		if resource is Dictionary:
			if String(resource.get("generated_kind", "")) == "route_reward":
				_zone_richness_add(by_zone, String(resource.get("zone_id", "")), "reward")
	for artifact in scenario.get("artifact_nodes", []):
		if artifact is Dictionary:
			_zone_richness_add(by_zone, String(artifact.get("zone_id", "")), "artifact")
	for target in decor.get("zone_density_targets", []):
		if target is Dictionary and int(target.get("placed_count", 0)) > 0:
			_zone_richness_add(by_zone, String(target.get("zone_id", "")), "decor")
	for guard in staging.get("materialized_object_guards", []):
		if guard is Dictionary:
			_zone_richness_add(by_zone, String(guard.get("zone_id", "")), "guard")
	for record in monster_rewards.get("monster_reward_records", []):
		if not (record is Dictionary):
			continue
		var context: Dictionary = record.get("zone_context", {}) if record.get("zone_context", {}) is Dictionary else {}
		var zone_id := String(context.get("primary_zone_id", ""))
		_zone_richness_add(by_zone, zone_id, "guard")
		_zone_richness_add(by_zone, zone_id, "reward_band")
	var zone_records := []
	var poor_zones := []
	var category_union := {}
	var min_score := 999999
	for zone_id in by_zone.keys():
		var record: Dictionary = by_zone[zone_id]
		var categories: Dictionary = record.get("categories", {})
		var score := categories.size()
		record["score"] = score
		record["poor"] = score < int(record.get("minimum_score", 4))
		min_score = min(min_score, score)
		for category_id in categories.keys():
			category_union[String(category_id)] = true
		zone_records.append(record)
		if bool(record.get("poor", false)):
			poor_zones.append(record)
	zone_records.sort_custom(Callable(self, "_compare_zone_richness_record"))
	poor_zones.sort_custom(Callable(self, "_compare_zone_richness_record"))
	return {
		"eligible_zone_count": by_zone.size(),
		"rich_zone_count": by_zone.size() - poor_zones.size(),
		"poor_zone_count": poor_zones.size(),
		"per_zone_richness_min": 0 if min_score == 999999 else min_score,
		"object_category_coverage_count": category_union.size(),
		"object_category_coverage": _sorted_string_keys(category_union),
		"zones": zone_records,
		"poor_zones": poor_zones,
		"policy": "eligible non-connector zones must expose a compact mix of economy/reward/guard/decor categories",
	}

func _zone_richness_add(by_zone: Dictionary, zone_id: String, category_id: String) -> void:
	if zone_id == "" or category_id == "" or not by_zone.has(zone_id):
		return
	var record: Dictionary = by_zone[zone_id]
	var categories: Dictionary = record.get("categories", {}) if record.get("categories", {}) is Dictionary else {}
	categories[category_id] = int(categories.get(category_id, 0)) + 1
	record["categories"] = categories
	by_zone[zone_id] = record

func _reward_band_summary(monster_reward_bands: Dictionary) -> Dictionary:
	var source_counts := {}
	var value_min := 999999
	var value_max := 0
	var records: Array = monster_reward_bands.get("reward_band_records", []) if monster_reward_bands.get("reward_band_records", []) is Array else []
	for reward in records:
		if not (reward is Dictionary):
			continue
		var source := String(reward.get("source", ""))
		source_counts[source] = int(source_counts.get(source, 0)) + 1
		var value_range: Dictionary = reward.get("value_range", {}) if reward.get("value_range", {}) is Dictionary else {}
		value_min = min(value_min, int(value_range.get("min", 0)))
		value_max = max(value_max, int(value_range.get("max", 0)))
	return {
		"record_count": records.size(),
		"template_record_count": int(source_counts.get("template_treasure_band", 0)),
		"fallback_record_count": records.size() - int(source_counts.get("template_treasure_band", 0)),
		"source_counts": source_counts,
		"value_min": 0 if value_min == 999999 else value_min,
		"value_max": value_max,
	}

func _fairness_layout_quality_metrics(fairness_report_value, warning_review: Dictionary = {}) -> Dictionary:
	var fairness_report: Dictionary = fairness_report_value if fairness_report_value is Dictionary else {}
	var summary: Dictionary = fairness_report.get("summary", {}) if fairness_report.get("summary", {}) is Dictionary else {}
	var contested_front: Dictionary = fairness_report.get("contested_front_distribution", {}) if fairness_report.get("contested_front_distribution", {}) is Dictionary else {}
	var guard_pressure: Dictionary = fairness_report.get("guard_pressure", {}) if fairness_report.get("guard_pressure", {}) is Dictionary else {}
	var travel: Dictionary = fairness_report.get("travel_distance_comparisons", {}) if fairness_report.get("travel_distance_comparisons", {}) is Dictionary else {}
	var warnings: Array = fairness_report.get("warnings", []) if fairness_report.get("warnings", []) is Array else []
	var fail_threshold_warning_count := int(warning_review.get("fail_threshold_warning_count", 0))
	var layout_quality_status := "pass"
	if fail_threshold_warning_count > 0:
		layout_quality_status = "fail_threshold_warning"
	elif int(warning_review.get("unresolved_review_warning_count", 0)) > 0:
		layout_quality_status = "warning"
	elif not warnings.is_empty():
		layout_quality_status = "accepted_asymmetry"
	if warning_review.is_empty() and not warnings.is_empty():
		layout_quality_status = "warning"
	return {
		"fairness_status": String(fairness_report.get("status", "")),
		"fairness_warning_count": warnings.size(),
		"fairness_fail_threshold_warning_count": fail_threshold_warning_count,
		"fairness_accepted_asymmetry_warning_count": int(warning_review.get("accepted_asymmetry_warning_count", 0)),
		"fairness_unresolved_review_warning_count": int(warning_review.get("unresolved_review_warning_count", warnings.size())),
		"fairness_layout_quality_status": layout_quality_status,
		"early_resource_status": String(summary.get("early_resource_status", "")),
		"contested_front_status": String(summary.get("contested_front_status", "")),
		"guard_pressure_status": String(summary.get("guard_pressure_status", "")),
		"travel_distance_status": String(summary.get("travel_distance_status", "")),
		"core_economy_producer_status": String(summary.get("core_economy_producer_status", "")),
		"contested_objective_pressure_status": String(summary.get("contested_objective_pressure_status", "")),
		"contest_route_distance_spread": _spread_metric(contested_front.get("distance_spread", {})),
		"travel_contest_route_distance_spread": _spread_metric(travel.get("contest_route_distance_spread", {})),
		"contest_guard_pressure_spread": _spread_metric(contested_front.get("guard_pressure_spread", {})),
		"route_guard_pressure_spread": _spread_metric(guard_pressure.get("pressure_spread", {})),
		"town_to_resource_distance_spread": _spread_metric(travel.get("town_to_resource_distance_spread", {})),
	}

func _fairness_warning_review(fairness_report: Dictionary, template_id: String) -> Dictionary:
	var warnings: Array = fairness_report.get("warnings", []) if fairness_report.get("warnings", []) is Array else []
	var accepted := []
	var unresolved := []
	var fail_threshold := []
	for warning in warnings:
		var warning_text := String(warning)
		var record := {
			"warning": warning_text,
			"classification": "unresolved_review",
			"basis": "warning remains visible in raw fairness warning count",
		}
		if _is_fail_threshold_fairness_warning(warning_text):
			record["classification"] = "fail_threshold_regression"
			record["basis"] = "fail-threshold diagnostics stay strict and are never accepted as template asymmetry"
			fail_threshold.append(record)
		elif _is_accepted_fairness_asymmetry_warning(warning_text, template_id, fairness_report):
			record["classification"] = "accepted_template_asymmetry"
			record["basis"] = _accepted_fairness_asymmetry_basis(warning_text, template_id, fairness_report)
			accepted.append(record)
		else:
			unresolved.append(record)
	return {
		"raw_warning_count": warnings.size(),
		"accepted_asymmetry_warning_count": accepted.size(),
		"unresolved_review_warning_count": unresolved.size(),
		"fail_threshold_warning_count": fail_threshold.size(),
		"accepted_asymmetry_warnings": accepted,
		"unresolved_review_warnings": unresolved,
		"fail_threshold_warnings": fail_threshold,
		"classification_model": "raw_warning_count_preserved_accepted_template_asymmetry_separated_from_unresolved_and_fail_threshold",
	}

func _is_fail_threshold_fairness_warning(warning_text: String) -> bool:
	return warning_text.find("fail spread") >= 0 or warning_text.find("fail threshold") >= 0

func _is_accepted_fairness_asymmetry_warning(warning_text: String, template_id: String, fairness_report: Dictionary) -> bool:
	if warning_text == "no contested mine or dwelling pressure markers":
		return template_id == "translated_rmg_template_001_v1"
	if warning_text == "contest route distances exceed warning spread" or warning_text == "contest route distance spread exceeds warning threshold":
		return template_id.begins_with("translated_rmg_template_") or template_id == "border_gate_compact_v1"
	if warning_text.find("early support route distances are uneven") >= 0:
		var travel: Dictionary = fairness_report.get("travel_distance_comparisons", {}) if fairness_report.get("travel_distance_comparisons", {}) is Dictionary else {}
		var town_resource: Dictionary = travel.get("town_to_resource_distance_spread", {}) if travel.get("town_to_resource_distance_spread", {}) is Dictionary else {}
		return template_id == "border_gate_compact_v1" and int(town_resource.get("spread", 999999)) <= 5
	return false

func _accepted_fairness_asymmetry_basis(warning_text: String, template_id: String, fairness_report: Dictionary) -> String:
	if warning_text == "no contested mine or dwelling pressure markers":
		return "%s is a translated all-start-zone template in the current catalog; guarded source links provide the contest pressure surface without separate contested mine/dwelling markers" % template_id
	if warning_text == "contest route distances exceed warning spread" or warning_text == "contest route distance spread exceeds warning threshold":
		if template_id == "border_gate_compact_v1":
			return "%s intentionally exercises compact border-gate and wide-link pressure; warning-level route spread remains raw-reported while fail-threshold spread stays strict" % template_id
		return "%s preserves translated source-template route topology; warning-level spread remains reported while fail-threshold spread stays strict" % template_id
	if warning_text.find("early support route distances are uneven") >= 0:
		var travel: Dictionary = fairness_report.get("travel_distance_comparisons", {}) if fairness_report.get("travel_distance_comparisons", {}) is Dictionary else {}
		var town_resource: Dictionary = travel.get("town_to_resource_distance_spread", {}) if travel.get("town_to_resource_distance_spread", {}) is Dictionary else {}
		return "%s has local pickup-route variation, but cross-start town-resource spread is %d and travel-distance fairness passes" % [template_id, int(town_resource.get("spread", 0))]
	return "not accepted"

func _spread_metric(spread_value) -> int:
	var spread: Dictionary = spread_value if spread_value is Dictionary else {}
	return int(spread.get("spread", 0))

func _zone_role_is_connector(role: String) -> bool:
	return role == "junction" or role.contains("gate") or role.contains("border") or role.contains("connector") or role.contains("crossing")

func _compare_zone_richness_record(left: Dictionary, right: Dictionary) -> bool:
	if int(left.get("score", 0)) == int(right.get("score", 0)):
		return String(left.get("zone_id", "")) < String(right.get("zone_id", ""))
	return int(left.get("score", 0)) < int(right.get("score", 0))

func _sorted_string_keys(values: Dictionary) -> Array:
	var keys := []
	for key in values.keys():
		keys.append(String(key))
	keys.sort()
	return keys

func _metric_failures(case_id: String, metrics: Dictionary) -> Array:
	var failures := []
	var area: int = max(1, int(metrics.get("width", 0)) * int(metrics.get("height", 0)))
	if not bool(metrics.get("ok", false)):
		failures.append("%s generation failed validation" % case_id)
	if int(metrics.get("elapsed_msec", 0)) > MAX_CASE_MSEC:
		failures.append("%s exceeded per-case runtime budget: %d ms" % [case_id, int(metrics.get("elapsed_msec", 0))])
	if int(metrics.get("road_tile_count", 0)) <= 0 or int(metrics.get("road_segment_count", 0)) <= 0:
		failures.append("%s has no generated road network" % case_id)
	if int(metrics.get("connection_guard_road_control_count", 0)) < int(metrics.get("expected_connection_guard_road_control_count", 0)):
		failures.append("%s connection guard road controls are incomplete: %d/%d" % [case_id, int(metrics.get("connection_guard_road_control_count", 0)), int(metrics.get("expected_connection_guard_road_control_count", 0))])
	if int(metrics.get("wide_suppressed_route_count", 0)) < int(metrics.get("expected_wide_suppression_road_count", 0)):
		failures.append("%s wide guard-suppressed road semantics are incomplete: %d/%d" % [case_id, int(metrics.get("wide_suppressed_route_count", 0)), int(metrics.get("expected_wide_suppression_road_count", 0))])
	if int(metrics.get("special_guard_gate_road_count", 0)) < int(metrics.get("expected_special_guard_gate_road_count", 0)):
		failures.append("%s special border-guard gate roads are incomplete: %d/%d" % [case_id, int(metrics.get("special_guard_gate_road_count", 0)), int(metrics.get("expected_special_guard_gate_road_count", 0))])
	if String(metrics.get("water_mode", "")) == "land" and int(metrics.get("river_candidate_count", 0)) <= 0:
		failures.append("%s land map has no river candidates" % case_id)
	if String(metrics.get("water_mode", "")) == "islands" and (int(metrics.get("water_tile_count", 0)) <= 0 or int(metrics.get("river_candidate_count", 0)) <= 0):
		failures.append("%s islands map has no water/river transit candidates" % case_id)
	if int(metrics.get("river_candidate_count", 0)) > 0:
		if int(metrics.get("coherent_river_candidate_count", 0)) < int(metrics.get("river_candidate_count", 0)):
			failures.append("%s river continuity is incomplete: %d/%d coherent" % [case_id, int(metrics.get("coherent_river_candidate_count", 0)), int(metrics.get("river_candidate_count", 0))])
		if int(metrics.get("river_continuity_failure_count", 0)) > 0 or int(metrics.get("isolated_river_fragment_count", 0)) > 0:
			failures.append("%s has fragmented river overlays: failures=%d isolated=%d" % [case_id, int(metrics.get("river_continuity_failure_count", 0)), int(metrics.get("isolated_river_fragment_count", 0))])
		if int(metrics.get("river_body_conflict_count", 0)) > 0:
			failures.append("%s river overlay crosses object bodies: %d" % [case_id, int(metrics.get("river_body_conflict_count", 0))])
		if String(metrics.get("water_mode", "")) == "land" and int(metrics.get("land_river_with_crossing_count", 0)) < int(metrics.get("land_river_candidate_count", 0)):
			failures.append("%s land rivers missed road bridge/ford crossings: %d/%d" % [case_id, int(metrics.get("land_river_with_crossing_count", 0)), int(metrics.get("land_river_candidate_count", 0))])
	if int(metrics.get("direct_minimum_town_distance", 0)) < int(metrics.get("minimum_town_distance_required", 0)):
		failures.append("%s town spacing %d below required %d" % [case_id, int(metrics.get("direct_minimum_town_distance", 0)), int(metrics.get("minimum_town_distance_required", 0))])
	if int(metrics.get("observed_start_town_minimum_distance", 0)) > 0 and int(metrics.get("observed_start_town_minimum_distance", 0)) < int(metrics.get("start_town_minimum_distance_required", 0)):
		failures.append("%s start town spacing %d below required %d" % [case_id, int(metrics.get("observed_start_town_minimum_distance", 0)), int(metrics.get("start_town_minimum_distance_required", 0))])
	if int(metrics.get("same_zone_town_pair_count", 0)) > 0 and int(metrics.get("observed_same_zone_town_minimum_distance", 0)) < int(metrics.get("same_zone_town_minimum_distance_required", 0)):
		failures.append("%s same-zone town spacing %d below required %d" % [case_id, int(metrics.get("observed_same_zone_town_minimum_distance", 0)), int(metrics.get("same_zone_town_minimum_distance_required", 0))])
	if int(metrics.get("decoration_count", 0)) < max(8, int(area / 55)):
		failures.append("%s decoration/blocker record density is too low: %d" % [case_id, int(metrics.get("decoration_count", 0))])
	if int(metrics.get("decoration_blocking_body_tile_total", 0)) < max(10, int(area / 40)):
		failures.append("%s decorative blocker body density is too low: %d" % [case_id, int(metrics.get("decoration_blocking_body_tile_total", 0))])
	if int(metrics.get("multitile_decoration_count", 0)) <= 0:
		failures.append("%s produced no multi-tile decorative blocker footprints" % case_id)
	var required_routes := int(metrics.get("required_route_count", 0))
	if required_routes > 0:
		var min_shoulder_routes: int = max(1, int(ceil(float(required_routes) * 0.55)))
		if int(metrics.get("required_route_with_shoulder_count", 0)) < min_shoulder_routes:
			failures.append("%s decorative blockers do not shape enough required route shoulders: %d/%d required min %d" % [case_id, int(metrics.get("required_route_with_shoulder_count", 0)), required_routes, min_shoulder_routes])
		if int(metrics.get("route_shoulder_body_count", 0)) < max(8, required_routes):
			failures.append("%s route-adjacent decorative blocker body coverage is too low: %d" % [case_id, int(metrics.get("route_shoulder_body_count", 0))])
		var min_choked_road_tiles: int = max(4, int(ceil(float(required_routes) * 0.20)))
		if int(metrics.get("choked_road_tile_count", 0)) < min_choked_road_tiles:
			failures.append("%s decorative blockers do not create enough road choke pressure: %d" % [case_id, int(metrics.get("choked_road_tile_count", 0))])
		if int(metrics.get("required_route_with_choke_count", 0)) > 0 and int(metrics.get("guarded_choke_route_count", 0)) <= 0:
			failures.append("%s has choked required routes but none are connection-guard controlled" % case_id)
	if int(metrics.get("artifact_count", 0)) <= 0:
		failures.append("%s has no materialized artifact nodes" % case_id)
	if int(metrics.get("guarded_artifact_count", 0)) < int(metrics.get("artifact_count", 0)):
		failures.append("%s guarded artifact coverage is incomplete: %d/%d" % [case_id, int(metrics.get("guarded_artifact_count", 0)), int(metrics.get("artifact_count", 0))])
	if int(metrics.get("guarded_artifact_max_distance", 0)) > 2:
		failures.append("%s guarded artifact max distance is too loose: %d" % [case_id, int(metrics.get("guarded_artifact_max_distance", 0))])
	if int(metrics.get("guardable_valuable_object_count", 0)) > 0 and int(metrics.get("guarded_valuable_object_count", 0)) + int(metrics.get("object_guard_skipped_no_cell", 0)) < int(metrics.get("guardable_valuable_object_count", 0)):
		failures.append("%s has unguarded valuable objects despite available guard budget: %d guarded / %d guardable, skipped_no_cell=%d" % [case_id, int(metrics.get("guarded_valuable_object_count", 0)), int(metrics.get("guardable_valuable_object_count", 0)), int(metrics.get("object_guard_skipped_no_cell", 0))])
	if int(metrics.get("guardable_mine_count", 0)) > 0 and int(metrics.get("guarded_mine_count", 0)) <= 0:
		failures.append("%s has guardable mines but no mine guards" % case_id)
	if int(metrics.get("guardable_dwelling_count", 0)) > 0 and int(metrics.get("guarded_dwelling_count", 0)) <= 0:
		failures.append("%s has guardable dwellings but no dwelling guards" % case_id)
	if int(metrics.get("guardable_reward_object_count", 0)) > 0 and int(metrics.get("guarded_reward_object_count", 0)) <= 0:
		failures.append("%s has guardable route reward objects but no reward-object guards" % case_id)
	if int(metrics.get("encounter_count", 0)) < max(4, int(metrics.get("artifact_count", 0)) + int(metrics.get("town_count", 0))):
		failures.append("%s guard/encounter density is too low: %d" % [case_id, int(metrics.get("encounter_count", 0))])
	if int(metrics.get("object_instance_count", 0)) < int(metrics.get("town_count", 0)) + int(metrics.get("mine_count", 0)) + int(metrics.get("decoration_count", 0)):
		failures.append("%s object writeout count does not reflect placed objects" % case_id)
	if int(metrics.get("eligible_zone_count", 0)) <= 0:
		failures.append("%s has no eligible zones for richness validation" % case_id)
	if int(metrics.get("poor_zone_count", 0)) > 0:
		failures.append("%s has poor per-zone richness coverage: %d zones below floor" % [case_id, int(metrics.get("poor_zone_count", 0))])
	if int(metrics.get("per_zone_richness_min", 0)) < 4:
		failures.append("%s minimum zone richness score is too low: %d" % [case_id, int(metrics.get("per_zone_richness_min", 0))])
	if int(metrics.get("object_category_coverage_count", 0)) < 6:
		failures.append("%s object category coverage is too narrow: %d" % [case_id, int(metrics.get("object_category_coverage_count", 0))])
	if int(metrics.get("reward_band_record_count", 0)) <= 0:
		failures.append("%s produced no reward band records" % case_id)
	if int(metrics.get("template_reward_band_record_count", 0)) <= 0:
		failures.append("%s did not consume template treasure bands" % case_id)
	if int(metrics.get("fallback_reward_band_record_count", 0)) > 0:
		failures.append("%s fell back from template treasure bands: %d records" % [case_id, int(metrics.get("fallback_reward_band_record_count", 0))])
	if int(metrics.get("reward_band_value_max", 0)) < int(metrics.get("reward_band_value_min", 0)):
		failures.append("%s reward band value range is inverted" % case_id)
	return failures

func _ascii_preview(payload: Dictionary) -> String:
	var scenario: Dictionary = payload.get("scenario_record", {}) if payload.get("scenario_record", {}) is Dictionary else {}
	var rows: Array = scenario.get("map", []) if scenario.get("map", []) is Array else []
	var staging: Dictionary = payload.get("staging", {}) if payload.get("staging", {}) is Dictionary else {}
	var marks := {}
	for candidate in staging.get("roads_rivers_writeout", {}).get("river_water_coast_overlay", {}).get("river_candidates", []):
		if candidate is Dictionary:
			for cell in candidate.get("candidate_cells", []):
				if cell is Dictionary:
					marks[_point_key(int(cell.get("x", 0)), int(cell.get("y", 0)))] = "~"
	for tile in staging.get("roads_rivers_writeout", {}).get("road_overlay", {}).get("tiles", []):
		if tile is Dictionary:
			marks[_point_key(int(tile.get("x", 0)), int(tile.get("y", 0)))] = "C" if tile.get("connection_control", {}) is Dictionary and not tile.get("connection_control", {}).is_empty() else "."
	for decor in staging.get("decoration_density_pass", {}).get("decoration_records", []):
		if decor is Dictionary:
			for body in decor.get("body_tiles", []):
				if body is Dictionary:
					marks[_point_key(int(body.get("x", 0)), int(body.get("y", 0)))] = "#"
	for node in scenario.get("resource_nodes", []):
		if node is Dictionary:
			marks[_point_key(int(node.get("x", 0)), int(node.get("y", 0)))] = "M" if String(node.get("original_resource_category_id", "")) != "" else "R"
	for node in scenario.get("artifact_nodes", []):
		if node is Dictionary:
			marks[_point_key(int(node.get("x", 0)), int(node.get("y", 0)))] = "A"
	for encounter in scenario.get("encounters", []):
		if encounter is Dictionary:
			marks[_point_key(int(encounter.get("x", 0)), int(encounter.get("y", 0)))] = "G"
	for town in scenario.get("towns", []):
		if town is Dictionary:
			marks[_point_key(int(town.get("x", 0)), int(town.get("y", 0)))] = "T"
	var step := 1
	if not rows.is_empty() and rows[0] is Array:
		step = max(1, int(ceil(float((rows[0] as Array).size()) / 72.0)))
	var lines: Array[String] = []
	for y in range(0, rows.size(), step):
		var row: Array = rows[y]
		var chars: Array[String] = []
		for x in range(0, row.size(), step):
			var key := _point_key(x, y)
			chars.append(String(marks[key]) if marks.has(key) else _terrain_char(String(row[x])))
		lines.append("".join(chars))
	return "\n".join(lines)

func _terrain_char(terrain_id: String) -> String:
	match terrain_id:
		"water":
			return "="
		"rough":
			return "^"
		"dirt":
			return ":"
		"sand":
			return ","
		"snow":
			return "*"
		"lava":
			return "!"
		"underground":
			return "u"
		_:
			return " "

func _summary(results: Array) -> Dictionary:
	var totals := {
		"road_tiles": 0,
		"connection_guard_road_controls": 0,
		"missing_connection_guard_road_controls": 0,
		"wide_suppressed_routes": 0,
		"special_guard_gate_roads": 0,
		"river_candidates": 0,
		"coherent_river_candidates": 0,
		"river_continuity_failures": 0,
		"isolated_river_fragments": 0,
		"river_body_conflicts": 0,
		"river_road_crossings": 0,
		"land_river_candidates": 0,
		"land_rivers_with_crossings": 0,
		"decorations": 0,
		"decoration_blocking_body_tiles": 0,
		"multitile_decorations": 0,
		"route_shoulder_body_count": 0,
		"route_shoulder_decorations": 0,
		"route_shoulder_guard_body_count": 0,
		"route_shoulder_guards": 0,
		"required_routes": 0,
		"required_routes_with_shoulders": 0,
		"choked_road_tiles": 0,
		"required_routes_with_chokes": 0,
		"guarded_choke_routes": 0,
		"artifacts": 0,
		"guarded_artifacts": 0,
		"guarded_artifact_missing": 0,
		"guarded_artifact_max_distance": 0,
		"encounters": 0,
		"associated_object_guards": 0,
		"guardable_valuable_objects": 0,
		"guarded_valuable_objects": 0,
		"unguarded_valuable_objects": 0,
		"guardable_mines": 0,
		"guarded_mines": 0,
		"guardable_dwellings": 0,
		"guarded_dwellings": 0,
		"guardable_reward_objects": 0,
		"guarded_reward_objects": 0,
		"object_instances": 0,
		"max_case_msec": 0,
		"minimum_town_distance_required_max": 0,
		"observed_minimum_town_distance_min": 999999,
		"start_town_minimum_distance_required_max": 0,
		"observed_start_town_minimum_distance_min": 999999,
		"same_zone_town_pair_count": 0,
		"eligible_zones": 0,
		"rich_zones": 0,
		"poor_zones": 0,
		"per_zone_richness_min": 999999,
		"object_category_coverage_max": 0,
		"reward_band_records": 0,
		"template_reward_band_records": 0,
		"fallback_reward_band_records": 0,
		"reward_band_value_min": 999999,
		"reward_band_value_max": 0,
		"fairness_warning_count": 0,
		"fairness_fail_threshold_warning_count": 0,
		"fairness_accepted_asymmetry_warning_count": 0,
		"fairness_unresolved_review_warning_count": 0,
		"max_contest_route_distance_spread": 0,
		"max_travel_contest_route_distance_spread": 0,
		"max_contest_guard_pressure_spread": 0,
		"max_route_guard_pressure_spread": 0,
		"max_town_to_resource_distance_spread": 0,
		"template_variability_signature_count": 0,
		"template_variability_template_count": 0,
	}
	var signatures := {}
	var templates := {}
	for result in results:
		if not (result is Dictionary):
			continue
		var metrics: Dictionary = result.get("metrics", {}) if result.get("metrics", {}) is Dictionary else {}
		signatures[String(metrics.get("stable_signature", ""))] = true
		templates[String(metrics.get("template_id", ""))] = true
		totals["road_tiles"] = int(totals.get("road_tiles", 0)) + int(metrics.get("road_tile_count", 0))
		totals["connection_guard_road_controls"] = int(totals.get("connection_guard_road_controls", 0)) + int(metrics.get("connection_guard_road_control_count", 0))
		totals["missing_connection_guard_road_controls"] = int(totals.get("missing_connection_guard_road_controls", 0)) + int(metrics.get("missing_connection_guard_road_control_count", 0))
		totals["wide_suppressed_routes"] = int(totals.get("wide_suppressed_routes", 0)) + int(metrics.get("wide_suppressed_route_count", 0))
		totals["special_guard_gate_roads"] = int(totals.get("special_guard_gate_roads", 0)) + int(metrics.get("special_guard_gate_road_count", 0))
		totals["river_candidates"] = int(totals.get("river_candidates", 0)) + int(metrics.get("river_candidate_count", 0))
		totals["coherent_river_candidates"] = int(totals.get("coherent_river_candidates", 0)) + int(metrics.get("coherent_river_candidate_count", 0))
		totals["river_continuity_failures"] = int(totals.get("river_continuity_failures", 0)) + int(metrics.get("river_continuity_failure_count", 0))
		totals["isolated_river_fragments"] = int(totals.get("isolated_river_fragments", 0)) + int(metrics.get("isolated_river_fragment_count", 0))
		totals["river_body_conflicts"] = int(totals.get("river_body_conflicts", 0)) + int(metrics.get("river_body_conflict_count", 0))
		totals["river_road_crossings"] = int(totals.get("river_road_crossings", 0)) + int(metrics.get("river_road_crossing_count", 0))
		totals["land_river_candidates"] = int(totals.get("land_river_candidates", 0)) + int(metrics.get("land_river_candidate_count", 0))
		totals["land_rivers_with_crossings"] = int(totals.get("land_rivers_with_crossings", 0)) + int(metrics.get("land_river_with_crossing_count", 0))
		totals["decorations"] = int(totals.get("decorations", 0)) + int(metrics.get("decoration_count", 0))
		totals["decoration_blocking_body_tiles"] = int(totals.get("decoration_blocking_body_tiles", 0)) + int(metrics.get("decoration_blocking_body_tile_total", 0))
		totals["multitile_decorations"] = int(totals.get("multitile_decorations", 0)) + int(metrics.get("multitile_decoration_count", 0))
		totals["route_shoulder_body_count"] = int(totals.get("route_shoulder_body_count", 0)) + int(metrics.get("route_shoulder_body_count", 0))
		totals["route_shoulder_decorations"] = int(totals.get("route_shoulder_decorations", 0)) + int(metrics.get("route_shoulder_decoration_count", 0))
		totals["route_shoulder_guard_body_count"] = int(totals.get("route_shoulder_guard_body_count", 0)) + int(metrics.get("route_shoulder_guard_body_count", 0))
		totals["route_shoulder_guards"] = int(totals.get("route_shoulder_guards", 0)) + int(metrics.get("route_shoulder_guard_count", 0))
		totals["required_routes"] = int(totals.get("required_routes", 0)) + int(metrics.get("required_route_count", 0))
		totals["required_routes_with_shoulders"] = int(totals.get("required_routes_with_shoulders", 0)) + int(metrics.get("required_route_with_shoulder_count", 0))
		totals["choked_road_tiles"] = int(totals.get("choked_road_tiles", 0)) + int(metrics.get("choked_road_tile_count", 0))
		totals["required_routes_with_chokes"] = int(totals.get("required_routes_with_chokes", 0)) + int(metrics.get("required_route_with_choke_count", 0))
		totals["guarded_choke_routes"] = int(totals.get("guarded_choke_routes", 0)) + int(metrics.get("guarded_choke_route_count", 0))
		totals["artifacts"] = int(totals.get("artifacts", 0)) + int(metrics.get("artifact_count", 0))
		totals["guarded_artifacts"] = int(totals.get("guarded_artifacts", 0)) + int(metrics.get("guarded_artifact_count", 0))
		totals["guarded_artifact_missing"] = int(totals.get("guarded_artifact_missing", 0)) + int(metrics.get("guarded_artifact_missing_count", 0))
		totals["guarded_artifact_max_distance"] = max(int(totals.get("guarded_artifact_max_distance", 0)), int(metrics.get("guarded_artifact_max_distance", 0)))
		totals["encounters"] = int(totals.get("encounters", 0)) + int(metrics.get("encounter_count", 0))
		totals["associated_object_guards"] = int(totals.get("associated_object_guards", 0)) + int(metrics.get("associated_object_guard_count", 0))
		totals["guardable_valuable_objects"] = int(totals.get("guardable_valuable_objects", 0)) + int(metrics.get("guardable_valuable_object_count", 0))
		totals["guarded_valuable_objects"] = int(totals.get("guarded_valuable_objects", 0)) + int(metrics.get("guarded_valuable_object_count", 0))
		totals["unguarded_valuable_objects"] = int(totals.get("unguarded_valuable_objects", 0)) + int(metrics.get("unguarded_valuable_object_count", 0))
		totals["guardable_mines"] = int(totals.get("guardable_mines", 0)) + int(metrics.get("guardable_mine_count", 0))
		totals["guarded_mines"] = int(totals.get("guarded_mines", 0)) + int(metrics.get("guarded_mine_count", 0))
		totals["guardable_dwellings"] = int(totals.get("guardable_dwellings", 0)) + int(metrics.get("guardable_dwelling_count", 0))
		totals["guarded_dwellings"] = int(totals.get("guarded_dwellings", 0)) + int(metrics.get("guarded_dwelling_count", 0))
		totals["guardable_reward_objects"] = int(totals.get("guardable_reward_objects", 0)) + int(metrics.get("guardable_reward_object_count", 0))
		totals["guarded_reward_objects"] = int(totals.get("guarded_reward_objects", 0)) + int(metrics.get("guarded_reward_object_count", 0))
		totals["object_instances"] = int(totals.get("object_instances", 0)) + int(metrics.get("object_instance_count", 0))
		totals["max_case_msec"] = max(int(totals.get("max_case_msec", 0)), int(metrics.get("elapsed_msec", 0)))
		totals["minimum_town_distance_required_max"] = max(int(totals.get("minimum_town_distance_required_max", 0)), int(metrics.get("minimum_town_distance_required", 0)))
		if int(metrics.get("observed_minimum_town_distance", 0)) > 0:
			totals["observed_minimum_town_distance_min"] = min(int(totals.get("observed_minimum_town_distance_min", 999999)), int(metrics.get("observed_minimum_town_distance", 0)))
		totals["start_town_minimum_distance_required_max"] = max(int(totals.get("start_town_minimum_distance_required_max", 0)), int(metrics.get("start_town_minimum_distance_required", 0)))
		if int(metrics.get("observed_start_town_minimum_distance", 0)) > 0:
			totals["observed_start_town_minimum_distance_min"] = min(int(totals.get("observed_start_town_minimum_distance_min", 999999)), int(metrics.get("observed_start_town_minimum_distance", 0)))
		totals["same_zone_town_pair_count"] = int(totals.get("same_zone_town_pair_count", 0)) + int(metrics.get("same_zone_town_pair_count", 0))
		totals["eligible_zones"] = int(totals.get("eligible_zones", 0)) + int(metrics.get("eligible_zone_count", 0))
		totals["rich_zones"] = int(totals.get("rich_zones", 0)) + int(metrics.get("rich_zone_count", 0))
		totals["poor_zones"] = int(totals.get("poor_zones", 0)) + int(metrics.get("poor_zone_count", 0))
		if int(metrics.get("per_zone_richness_min", 0)) > 0:
			totals["per_zone_richness_min"] = min(int(totals.get("per_zone_richness_min", 999999)), int(metrics.get("per_zone_richness_min", 0)))
		totals["object_category_coverage_max"] = max(int(totals.get("object_category_coverage_max", 0)), int(metrics.get("object_category_coverage_count", 0)))
		totals["reward_band_records"] = int(totals.get("reward_band_records", 0)) + int(metrics.get("reward_band_record_count", 0))
		totals["template_reward_band_records"] = int(totals.get("template_reward_band_records", 0)) + int(metrics.get("template_reward_band_record_count", 0))
		totals["fallback_reward_band_records"] = int(totals.get("fallback_reward_band_records", 0)) + int(metrics.get("fallback_reward_band_record_count", 0))
		if int(metrics.get("reward_band_value_min", 0)) > 0:
			totals["reward_band_value_min"] = min(int(totals.get("reward_band_value_min", 999999)), int(metrics.get("reward_band_value_min", 0)))
		totals["reward_band_value_max"] = max(int(totals.get("reward_band_value_max", 0)), int(metrics.get("reward_band_value_max", 0)))
		totals["fairness_warning_count"] = int(totals.get("fairness_warning_count", 0)) + int(metrics.get("fairness_warning_count", 0))
		totals["fairness_fail_threshold_warning_count"] = int(totals.get("fairness_fail_threshold_warning_count", 0)) + int(metrics.get("fairness_fail_threshold_warning_count", 0))
		totals["fairness_accepted_asymmetry_warning_count"] = int(totals.get("fairness_accepted_asymmetry_warning_count", 0)) + int(metrics.get("fairness_accepted_asymmetry_warning_count", 0))
		totals["fairness_unresolved_review_warning_count"] = int(totals.get("fairness_unresolved_review_warning_count", 0)) + int(metrics.get("fairness_unresolved_review_warning_count", 0))
		totals["max_contest_route_distance_spread"] = max(int(totals.get("max_contest_route_distance_spread", 0)), int(metrics.get("contest_route_distance_spread", 0)))
		totals["max_travel_contest_route_distance_spread"] = max(int(totals.get("max_travel_contest_route_distance_spread", 0)), int(metrics.get("travel_contest_route_distance_spread", 0)))
		totals["max_contest_guard_pressure_spread"] = max(int(totals.get("max_contest_guard_pressure_spread", 0)), int(metrics.get("contest_guard_pressure_spread", 0)))
		totals["max_route_guard_pressure_spread"] = max(int(totals.get("max_route_guard_pressure_spread", 0)), int(metrics.get("route_guard_pressure_spread", 0)))
		totals["max_town_to_resource_distance_spread"] = max(int(totals.get("max_town_to_resource_distance_spread", 0)), int(metrics.get("town_to_resource_distance_spread", 0)))
	if int(totals.get("observed_minimum_town_distance_min", 999999)) == 999999:
		totals["observed_minimum_town_distance_min"] = 0
	if int(totals.get("observed_start_town_minimum_distance_min", 999999)) == 999999:
		totals["observed_start_town_minimum_distance_min"] = 0
	if int(totals.get("per_zone_richness_min", 999999)) == 999999:
		totals["per_zone_richness_min"] = 0
	if int(totals.get("reward_band_value_min", 999999)) == 999999:
		totals["reward_band_value_min"] = 0
	totals["template_variability_signature_count"] = signatures.size()
	totals["template_variability_template_count"] = templates.size()
	return totals

func _town_distance_summary(towns: Variant) -> Dictionary:
	if not (towns is Array) or (towns as Array).size() < 2:
		return {"minimum": 0}
	var minimum := 999999
	for i in range((towns as Array).size()):
		if not ((towns as Array)[i] is Dictionary):
			continue
		var left: Dictionary = (towns as Array)[i]
		for j in range(i + 1, (towns as Array).size()):
			if not ((towns as Array)[j] is Dictionary):
				continue
			var right: Dictionary = (towns as Array)[j]
			var distance: int = abs(int(left.get("x", 0)) - int(right.get("x", 0))) + abs(int(left.get("y", 0)) - int(right.get("y", 0)))
			minimum = min(minimum, distance)
	return {"minimum": minimum if minimum != 999999 else 0}

func _artifact_guard_summary(artifacts: Variant, guards: Variant) -> Dictionary:
	var artifact_by_id := {}
	var guarded := {}
	var adjacent_count := 0
	var max_distance := 0
	if artifacts is Array:
		for artifact in artifacts:
			if artifact is Dictionary:
				artifact_by_id[String(artifact.get("placement_id", ""))] = artifact
	if guards is Array:
		for guard in guards:
			if not (guard is Dictionary):
				continue
			if String(guard.get("guarded_object_kind", "")) != "artifact":
				continue
			var guarded_id := String(guard.get("guarded_object_placement_id", ""))
			if guarded_id == "" or not artifact_by_id.has(guarded_id):
				continue
			guarded[guarded_id] = true
			var artifact: Dictionary = artifact_by_id[guarded_id]
			var distance := int(guard.get("guard_distance", -1))
			if distance < 0:
				distance = abs(int(guard.get("x", 0)) - int(artifact.get("x", 0))) + abs(int(guard.get("y", 0)) - int(artifact.get("y", 0)))
			max_distance = max(max_distance, distance)
			if distance <= 1 or bool(guard.get("adjacent_to_guarded_object", false)):
				adjacent_count += 1
	var missing := []
	for artifact_id in artifact_by_id.keys():
		if not guarded.has(String(artifact_id)):
			missing.append(String(artifact_id))
	missing.sort()
	return {
		"artifact_count": artifact_by_id.size(),
		"guarded_artifact_count": guarded.size(),
		"missing_count": missing.size(),
		"missing_artifact_ids": missing,
		"adjacent_count": adjacent_count,
		"max_distance": max_distance,
		"policy": "guards must explicitly reference materialized artifact placement ids",
	}

func _sample_dictionaries(records: Variant, limit: int) -> Array:
	var samples := []
	if not (records is Array):
		return samples
	for record in records:
		if record is Dictionary:
			samples.append(record)
		if samples.size() >= limit:
			break
	return samples

func _case_log_line(result: Dictionary) -> Dictionary:
	var metrics: Dictionary = result.get("metrics", {}) if result.get("metrics", {}) is Dictionary else {}
	return {
		"id": String(result.get("id", "")),
		"ok": result.get("failures", []).is_empty(),
		"elapsed_msec": int(metrics.get("elapsed_msec", 0)),
		"roads": int(metrics.get("road_tile_count", 0)),
		"connection_controls": int(metrics.get("connection_guard_road_control_count", 0)),
		"wide_roads": int(metrics.get("wide_suppressed_route_count", 0)),
		"special_gate_roads": int(metrics.get("special_guard_gate_road_count", 0)),
		"rivers": int(metrics.get("river_candidate_count", 0)),
		"coherent_rivers": int(metrics.get("coherent_river_candidate_count", 0)),
		"river_crossings": int(metrics.get("river_road_crossing_count", 0)),
		"river_fragment_failures": int(metrics.get("river_continuity_failure_count", 0)),
		"decor": int(metrics.get("decoration_count", 0)),
		"decor_body_tiles": int(metrics.get("decoration_blocking_body_tile_total", 0)),
		"multitile_decor": int(metrics.get("multitile_decoration_count", 0)),
		"route_shoulders": int(metrics.get("route_shoulder_body_count", 0)),
		"route_shoulder_guards": int(metrics.get("route_shoulder_guard_count", 0)),
		"routes_with_shoulders": int(metrics.get("required_route_with_shoulder_count", 0)),
		"required_routes": int(metrics.get("required_route_count", 0)),
		"choked_road_tiles": int(metrics.get("choked_road_tile_count", 0)),
		"guarded_choke_routes": int(metrics.get("guarded_choke_route_count", 0)),
		"artifacts": int(metrics.get("artifact_count", 0)),
		"guarded_artifacts": int(metrics.get("guarded_artifact_count", 0)),
		"guarded_artifact_missing": int(metrics.get("guarded_artifact_missing_count", 0)),
		"guarded_artifact_max_distance": int(metrics.get("guarded_artifact_max_distance", 0)),
		"guards": int(metrics.get("associated_object_guard_count", 0)),
		"guardable_valuable": int(metrics.get("guardable_valuable_object_count", 0)),
		"guarded_valuable": int(metrics.get("guarded_valuable_object_count", 0)),
		"unguarded_valuable": int(metrics.get("unguarded_valuable_object_count", 0)),
		"guarded_mines": int(metrics.get("guarded_mine_count", 0)),
		"guardable_mines": int(metrics.get("guardable_mine_count", 0)),
		"guarded_dwellings": int(metrics.get("guarded_dwelling_count", 0)),
		"guardable_dwellings": int(metrics.get("guardable_dwelling_count", 0)),
		"guarded_rewards": int(metrics.get("guarded_reward_object_count", 0)),
		"guardable_rewards": int(metrics.get("guardable_reward_object_count", 0)),
		"eligible_zones": int(metrics.get("eligible_zone_count", 0)),
		"poor_zones": int(metrics.get("poor_zone_count", 0)),
		"zone_richness_min": int(metrics.get("per_zone_richness_min", 0)),
		"category_coverage": int(metrics.get("object_category_coverage_count", 0)),
		"reward_bands": int(metrics.get("reward_band_record_count", 0)),
		"template_reward_bands": int(metrics.get("template_reward_band_record_count", 0)),
		"fallback_reward_bands": int(metrics.get("fallback_reward_band_record_count", 0)),
		"fairness_status": String(metrics.get("fairness_status", "")),
		"layout_quality_status": String(metrics.get("fairness_layout_quality_status", "")),
		"fairness_warnings": int(metrics.get("fairness_warning_count", 0)),
		"fairness_fail_threshold_warnings": int(metrics.get("fairness_fail_threshold_warning_count", 0)),
		"fairness_accepted_asymmetry_warnings": int(metrics.get("fairness_accepted_asymmetry_warning_count", 0)),
		"fairness_unresolved_review_warnings": int(metrics.get("fairness_unresolved_review_warning_count", 0)),
		"contest_route_distance_spread": int(metrics.get("contest_route_distance_spread", 0)),
		"travel_contest_route_distance_spread": int(metrics.get("travel_contest_route_distance_spread", 0)),
		"contest_guard_pressure_spread": int(metrics.get("contest_guard_pressure_spread", 0)),
		"route_guard_pressure_spread": int(metrics.get("route_guard_pressure_spread", 0)),
		"town_to_resource_distance_spread": int(metrics.get("town_to_resource_distance_spread", 0)),
		"town_min": int(metrics.get("observed_minimum_town_distance", 0)),
		"town_required": int(metrics.get("minimum_town_distance_required", 0)),
		"start_town_min": int(metrics.get("observed_start_town_minimum_distance", 0)),
	}

func _write_case_artifacts(result: Dictionary) -> void:
	var case_id := String(result.get("id", "case"))
	_write_json("%s/%s.json" % [ARTIFACT_DIR, case_id], result)
	var preview := FileAccess.open("%s/%s.txt" % [ARTIFACT_DIR, case_id], FileAccess.WRITE)
	if preview != null:
		preview.store_string(String(result.get("preview", "")) + "\n")

func _ensure_artifact_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ARTIFACT_DIR))

func _write_json(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload, "\t") + "\n")

func _point_key(x: int, y: int) -> String:
	return "%d,%d" % [x, y]

func _intersection_count(left: Variant, right: Variant) -> int:
	if not (left is Array) or not (right is Array):
		return 0
	var right_lookup := {}
	for value in right:
		right_lookup[String(value)] = true
	var count := 0
	for value in left:
		if right_lookup.has(String(value)):
			count += 1
	return count

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "error": message})])
	get_tree().quit(1)
