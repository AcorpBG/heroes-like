extends Node

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")
const OwnerCorpusCoverageReportScript = preload("res://tests/native_random_map_homm3_owner_corpus_coverage_report.gd")
const PackageSurfaceTopologyReportScript = preload("res://tests/native_random_map_package_surface_topology_report.gd")

const REPORT_ID := "NATIVE_RANDOM_MAP_PRODUCTION_PARITY_COMPLETION_AUDIT_REPORT"
const REPORT_SCHEMA_ID := "native_random_map_production_parity_completion_audit_report_v7"
const TEMPLATE_CATALOG_PATH := "res://content/random_map_template_catalog.json"

const OWNER_OBJECTIVE := "Native GDExtension RMG should be production-ready and HoMM3-style across template breadth, zone semantics, roads, obstacles, guards, rewards, validation, runtime adoption, and replay boundaries, translated into original content without HoMM3 copyrighted assets."

const REPRESENTATIVE_CASES := [
	{
		"id": "small_land_default",
		"seed": "production-parity-audit-small-10184",
		"size_class_id": "homm3_small",
		"player_count": 3,
		"water_mode": "land",
		"underground": false,
	},
	{
		"id": "small_underground_default",
		"seed": "owner-corpus-small-underground-10184",
		"size_class_id": "homm3_small",
		"player_count": 3,
		"water_mode": "land",
		"underground": true,
	},
	{
		"id": "medium_land_default",
		"seed": "production-parity-audit-medium-10184",
		"size_class_id": "homm3_medium",
		"player_count": 4,
		"water_mode": "land",
		"underground": false,
	},
	{
		"id": "medium_islands_default",
		"seed": "production-parity-audit-medium-islands-10184",
		"size_class_id": "homm3_medium",
		"player_count": 4,
		"water_mode": "islands",
		"underground": false,
	},
	{
		"id": "large_land_default",
		"seed": "production-parity-audit-large-10184",
		"size_class_id": "homm3_large",
		"player_count": 4,
		"water_mode": "land",
		"underground": false,
	},
	{
		"id": "extra_large_land_default",
		"seed": "production-parity-audit-xl-10184",
		"size_class_id": "homm3_extra_large",
		"player_count": 5,
		"water_mode": "land",
		"underground": false,
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
	var setup_options := ScenarioSelectRulesScript.random_map_player_setup_options()
	var cases := []
	for case_record in REPRESENTATIVE_CASES:
		var summary := _run_case(service, case_record)
		if summary.is_empty():
			return
		cases.append(summary)
	var owner_corpus := _owner_corpus_summary(service)
	var owner_comparison_gate: Dictionary = owner_corpus.get("comparison_gate", {}) if owner_corpus.get("comparison_gate", {}) is Dictionary else {}
	var owner_comparison_gate_self_check: Dictionary = owner_corpus.get("comparison_gate_self_check", {}) if owner_corpus.get("comparison_gate_self_check", {}) is Dictionary else {}
	if String(owner_comparison_gate_self_check.get("status", "")) != "pass":
		_fail("Owner corpus mapped comparison gate self-check failed: %s" % JSON.stringify(owner_comparison_gate_self_check))
		return
	if String(owner_comparison_gate.get("status", "")) != "pass":
		_fail("Owner corpus mapped comparison gate failed: %s" % JSON.stringify(owner_comparison_gate))
		return
	var checklist := _completion_checklist(metadata, setup_options, cases, owner_corpus)
	var objective_artifact_checklist := _objective_artifact_checklist(checklist, owner_corpus)
	var missing := []
	for item in checklist:
		if item is Dictionary and not bool(item.get("satisfied", false)):
			missing.append(item)
	if missing.is_empty():
		_fail("Production parity audit unexpectedly found no remaining missing requirements; audit criteria are stale.")
		return
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"schema_id": REPORT_SCHEMA_ID,
		"ok": true,
		"production_ready": false,
		"owner_objective": OWNER_OBJECTIVE,
		"native_extension_loaded": bool(metadata.get("native_extension_loaded", false)),
		"binding_kind": String(metadata.get("binding_kind", "")),
		"catalog_template_count": int(setup_options.get("catalog_template_count", 0)),
		"catalog_profile_count": int(setup_options.get("catalog_profile_count", 0)),
		"player_facing_template_count": (setup_options.get("templates", []) as Array).size() if setup_options.get("templates", []) is Array else 0,
		"player_facing_profile_count": (setup_options.get("profiles", []) as Array).size() if setup_options.get("profiles", []) is Array else 0,
		"player_facing_template_policy": String(setup_options.get("player_facing_template_policy", "")),
		"representative_cases": cases,
		"owner_corpus": owner_corpus,
		"completion_checklist": checklist,
		"objective_artifact_checklist": objective_artifact_checklist,
		"missing_requirement_count": missing.size(),
		"missing_requirements": missing,
		"next_work_direction": "Use this audit as a no-overclaim boundary. Production completion still requires broad owner-H3M corpus comparison across Large/XL and template breadth, plus broad underground production readiness.",
	})])
	get_tree().quit(0)

func _run_case(service: Variant, case_record: Dictionary) -> Dictionary:
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
	var generated: Dictionary = service.generate_random_map(config, {"startup_path": "production_parity_audit_%s" % String(case_record.get("id", "case"))})
	if not bool(generated.get("ok", false)):
		_fail("Representative production audit case failed generation: %s" % JSON.stringify(generated.get("validation_report", generated)))
		return {}
	var adoption: Dictionary = service.convert_generated_payload(generated, {
		"feature_gate": "native_rmg_production_parity_completion_audit_report",
		"session_save_version": 9,
		"scenario_id": "native_rmg_production_parity_audit_%s" % String(case_record.get("id", "case")),
	})
	if not bool(adoption.get("ok", false)):
		_fail("Representative production audit case package conversion failed: %s" % JSON.stringify(adoption))
		return {}
	var map_document: Variant = adoption.get("map_document", null)
	if map_document == null:
		_fail("Representative production audit case missed package map_document.")
		return {}
	var terrain_layers: Dictionary = map_document.get_terrain_layers()
	var roads: Array = terrain_layers.get("roads", []) if terrain_layers.get("roads", []) is Array else []
	var package_road_cell_count := 0
	for road in roads:
		if road is Dictionary:
			package_road_cell_count += int(road.get("tile_count", road.get("cell_count", 0)))
	var normalized: Dictionary = generated.get("normalized_config", {}) if generated.get("normalized_config", {}) is Dictionary else {}
	var catalog_minima := _catalog_town_minima_for_normalized_config(normalized)
	var effective_town_minima := _effective_town_minima_for_normalized_config(normalized, catalog_minima)
	var town_count := int(generated.get("town_records", []).size())
	var package_surface := _package_surface_topology(map_document, String(case_record.get("id", "case")))
	var package_route_closure := _package_route_closure_summary(package_surface)
	var generated_road_cell_count := int(generated.get("road_network", {}).get("road_cell_count", 0)) if generated.get("road_network", {}) is Dictionary else 0
	var package_road_integrity := _package_road_integrity_summary(package_surface, generated_road_cell_count)
	return {
		"id": String(case_record.get("id", "")),
		"template_id": String(normalized.get("template_id", "")),
		"profile_id": String(normalized.get("profile_id", "")),
		"size_class_id": String(normalized.get("size_class_id", "")),
		"water_mode": String(normalized.get("water_mode", "")),
		"level_count": int(normalized.get("level_count", 0)),
		"player_count": int((normalized.get("player_constraints", {}) as Dictionary).get("player_count", 0)) if normalized.get("player_constraints", {}) is Dictionary else 0,
		"status": String(generated.get("status", "")),
		"full_generation_status": String(generated.get("full_generation_status", "")),
		"full_parity_claim": bool(generated.get("full_parity_claim", false)),
		"owner_compared_translated_profile_supported": bool(generated.get("owner_compared_translated_profile_supported", false)),
		"translated_catalog_structural_profile_supported": bool(generated.get("translated_catalog_structural_profile_supported", false)),
		"validation_status": String(generated.get("validation_status", "")),
		"town_count": town_count,
		"catalog_town_minima": catalog_minima,
		"catalog_minimum_town_count": int(catalog_minima.get("minimum_total_town_count", 0)),
		"catalog_minimum_player_town_count": int(catalog_minima.get("minimum_player_town_count", 0)),
		"catalog_minimum_neutral_town_count": int(catalog_minima.get("minimum_neutral_town_count", 0)),
		"effective_town_minima": effective_town_minima,
		"effective_minimum_town_count": int(effective_town_minima.get("minimum_total_town_count", 0)),
		"effective_minimum_player_town_count": int(effective_town_minima.get("minimum_player_town_count", 0)),
		"effective_minimum_neutral_town_count": int(effective_town_minima.get("minimum_neutral_town_count", 0)),
		"town_minimum_source": String(effective_town_minima.get("source", "catalog_minima")),
		"catalog_town_minimum_status": "pass" if town_count >= int(effective_town_minima.get("minimum_total_town_count", 0)) else "fail",
		"zone_count": int(generated.get("zone_layout", {}).get("zone_count", 0)) if generated.get("zone_layout", {}) is Dictionary else 0,
		"object_count": int(generated.get("object_placements", []).size()),
		"package_object_count": int(map_document.get_object_count()),
		"guard_count": int(generated.get("guard_records", []).size()),
		"road_cell_count": generated_road_cell_count,
		"package_road_cell_count": package_road_cell_count,
		"package_road_integrity": package_road_integrity,
		"package_route_closure": package_route_closure,
	}

func _package_surface_topology(map_document: Variant, label: String) -> Dictionary:
	var report: Node = PackageSurfaceTopologyReportScript.new()
	var surface: Dictionary = report.call("_package_surface_summary", map_document, "production_audit_%s" % label)
	report.free()
	return surface

func _package_route_closure_summary(surface: Dictionary) -> Dictionary:
	var town_count := int(surface.get("town_count", 0))
	var required_all_town_pairs := town_count * (town_count - 1) / 2
	var player_start_slots: Dictionary = surface.get("player_start_towns_by_slot", {}) if surface.get("player_start_towns_by_slot", {}) is Dictionary else {}
	var player_start_count := 0
	for slot_key in player_start_slots.keys():
		var slot_towns: Array = player_start_slots.get(slot_key, []) if player_start_slots.get(slot_key, []) is Array else []
		player_start_count += slot_towns.size()
	var required_start_pairs := player_start_count * (player_start_count - 1) / 2
	var object_start: Dictionary = surface.get("object_only_start_town_topology", {}) if surface.get("object_only_start_town_topology", {}) is Dictionary else {}
	var object_cross_zone: Dictionary = surface.get("object_only_cross_zone_town_topology", {}) if surface.get("object_only_cross_zone_town_topology", {}) is Dictionary else {}
	var object_all_town: Dictionary = surface.get("object_only_town_topology", {}) if surface.get("object_only_town_topology", {}) is Dictionary else {}
	var unresolved_start: Dictionary = surface.get("unresolved_start_town_topology", {}) if surface.get("unresolved_start_town_topology", {}) is Dictionary else {}
	var unresolved_cross_zone: Dictionary = surface.get("unresolved_cross_zone_town_topology", {}) if surface.get("unresolved_cross_zone_town_topology", {}) is Dictionary else {}
	var unresolved_all_town: Dictionary = surface.get("unresolved_town_topology", {}) if surface.get("unresolved_town_topology", {}) is Dictionary else {}
	var status := "pass"
	if int(object_start.get("reachable_pair_count", 0)) != 0 \
			or int(object_cross_zone.get("reachable_pair_count", 0)) != 0 \
			or int(object_all_town.get("reachable_pair_count", 0)) != 0 \
			or int(unresolved_start.get("reachable_pair_count", 0)) != 0 \
			or int(unresolved_cross_zone.get("reachable_pair_count", 0)) != 0 \
			or int(unresolved_all_town.get("reachable_pair_count", 0)) != 0:
		status = "fail_reachable_pairs"
	elif int(object_start.get("checked_pair_count", 0)) < required_start_pairs \
			or int(unresolved_start.get("checked_pair_count", 0)) < required_start_pairs \
			or int(object_all_town.get("checked_pair_count", 0)) < required_all_town_pairs \
			or int(unresolved_all_town.get("checked_pair_count", 0)) < required_all_town_pairs:
		status = "fail_incomplete_pair_coverage"
	return {
		"status": status,
		"label": String(surface.get("label", "")),
		"level_count": int(surface.get("level_count", 0)),
		"town_count": town_count,
		"player_start_town_count": player_start_count,
		"required_start_pair_count": required_start_pairs,
		"required_all_town_pair_count": required_all_town_pairs,
		"object_only_start_checked_pair_count": int(object_start.get("checked_pair_count", 0)),
		"object_only_start_reachable_pair_count": int(object_start.get("reachable_pair_count", 0)),
		"object_only_cross_zone_checked_pair_count": int(object_cross_zone.get("checked_pair_count", 0)),
		"object_only_cross_zone_reachable_pair_count": int(object_cross_zone.get("reachable_pair_count", 0)),
		"object_only_all_town_checked_pair_count": int(object_all_town.get("checked_pair_count", 0)),
		"object_only_all_town_reachable_pair_count": int(object_all_town.get("reachable_pair_count", 0)),
		"unresolved_start_checked_pair_count": int(unresolved_start.get("checked_pair_count", 0)),
		"unresolved_start_reachable_pair_count": int(unresolved_start.get("reachable_pair_count", 0)),
		"unresolved_cross_zone_checked_pair_count": int(unresolved_cross_zone.get("checked_pair_count", 0)),
		"unresolved_cross_zone_reachable_pair_count": int(unresolved_cross_zone.get("reachable_pair_count", 0)),
		"unresolved_all_town_checked_pair_count": int(unresolved_all_town.get("checked_pair_count", 0)),
		"unresolved_all_town_reachable_pair_count": int(unresolved_all_town.get("reachable_pair_count", 0)),
	}

func _package_road_integrity_summary(surface: Dictionary, generated_road_cell_count: int) -> Dictionary:
	var road_count := int(surface.get("road_count", 0))
	var road_tile_count := int(surface.get("road_tile_count", 0))
	var road_unique_tile_count := int(surface.get("road_unique_tile_count", 0))
	var source_road_cell_count := int(surface.get("source_road_cell_count", 0))
	var duplicate_tile_count := int(surface.get("road_duplicate_tile_count", 0))
	var zero_tile_road_count := int(surface.get("zero_tile_road_count", 0))
	var status := "pass"
	if road_count <= 0 or road_tile_count <= 0 or road_unique_tile_count <= 0:
		status = "fail_empty_package_roads"
	elif zero_tile_road_count != 0:
		status = "fail_zero_tile_road_records"
	elif duplicate_tile_count != 0:
		status = "fail_duplicate_package_road_tiles"
	elif road_unique_tile_count != source_road_cell_count:
		status = "fail_package_metadata_road_count_mismatch"
	return {
		"status": status,
		"label": String(surface.get("label", "")),
		"road_count": road_count,
		"road_tile_count": road_tile_count,
		"road_unique_tile_count": road_unique_tile_count,
		"source_road_cell_count": source_road_cell_count,
		"road_duplicate_tile_count": duplicate_tile_count,
		"zero_tile_road_count": zero_tile_road_count,
		"generated_road_segment_cell_count": generated_road_cell_count,
		"generated_vs_package_unique_delta": generated_road_cell_count - road_unique_tile_count,
		"count_policy": "package road integrity is gated on unique serialized road tiles and package component metadata; generated road_network.road_cell_count remains diagnostic because it can include pre-dedup/materialization segment totals",
	}

func _owner_corpus_summary(service: Variant) -> Dictionary:
	var report: Node = OwnerCorpusCoverageReportScript.new()
	var samples := []
	for candidate in report.call("owner_h3m_candidates"):
		if not (candidate is Dictionary):
			continue
		var sample: Dictionary = report.call("sample_header", candidate)
		if bool(sample.get("readable", false)) and String(sample.get("metric_parse_status", "")) == "parsed":
			sample["native_comparison"] = report.call("_native_comparison_for_sample", service, sample)
		if not sample.is_empty():
			samples.append(sample)
	var coverage: Dictionary = report.call("coverage_summary", samples)
	var comparison_gate: Dictionary = report.call("comparison_gate_summary", samples)
	var comparison_gate_self_check: Dictionary = report.call("_comparison_gate_self_check")
	var large_land_density_diagnostic: Dictionary = report.call("owner_large_land_density_diagnostic", service, samples)
	var xl_land_density_diagnostic: Dictionary = report.call("owner_xl_land_density_diagnostic", service, samples)
	var compared_samples := []
	var readable_samples := []
	for sample_value in samples:
		if not (sample_value is Dictionary):
			continue
		var sample: Dictionary = sample_value
		if bool(sample.get("readable", false)):
			readable_samples.append(String(sample.get("id", "")))
			if String(sample.get("metric_parse_status", "")) == "parsed":
				compared_samples.append(String(sample.get("id", "")))
	var summary := {
		"schema_id": "native_random_map_owner_corpus_dynamic_audit_summary_v1",
		"candidate_count": samples.size(),
		"readable_sample_ids": readable_samples,
		"parsed_metric_sample_ids": compared_samples,
		"parsed_sample_coverage": _owner_sample_coverage_records(samples),
		"mapped_sample_parity": _owner_sample_parity_summaries(samples),
		"large_land_density_diagnostic": large_land_density_diagnostic,
		"xl_land_density_diagnostic": xl_land_density_diagnostic,
		"coverage": coverage,
		"comparison_gate": comparison_gate,
		"comparison_gate_self_check": comparison_gate_self_check,
	}
	report.free()
	return summary

func _completion_checklist(metadata: Dictionary, setup_options: Dictionary, cases: Array, owner_corpus: Dictionary) -> Array:
	var catalog_template_count := int(setup_options.get("catalog_template_count", 0))
	var player_facing_template_count := (setup_options.get("templates", []) as Array).size() if setup_options.get("templates", []) is Array else 0
	var auto_selection: Dictionary = setup_options.get("player_facing_auto_selection", {}) if setup_options.get("player_facing_auto_selection", {}) is Dictionary else {}
	var owner_compared_default_policy_supported := String(setup_options.get("player_facing_template_policy", "")) == "native_catalog_auto_prefers_owner_compared_defaults_with_broad_internal_launch_gate" \
		and String(auto_selection.get("mode", "")) == ScenarioSelectRulesScript.RANDOM_MAP_TEMPLATE_SELECTION_MODE_CATALOG_AUTO \
		and int(auto_selection.get("catalog_template_count", 0)) == catalog_template_count \
		and not bool(auto_selection.get("manual_template_picker_visible", true)) \
		and not bool(auto_selection.get("manual_profile_picker_visible", true))
	var all_cases_valid := true
	var all_catalog_town_minima_materialized := true
	var all_representative_package_routes_closed := true
	var all_representative_package_roads_integrity := true
	var any_full_parity_claim := false
	var any_not_full_parity_status := false
	var all_owner_compared := true
	var all_defaults_supported_without_full_claim := true
	var representative_underground_case := _case_by_id(cases, "small_underground_default")
	var representative_underground_supported := not representative_underground_case.is_empty() \
		and String(representative_underground_case.get("validation_status", "")) == "pass" \
		and bool(representative_underground_case.get("owner_compared_translated_profile_supported", false)) \
		and int(representative_underground_case.get("level_count", 0)) == 2 \
		and String(representative_underground_case.get("template_id", "")) == "translated_rmg_template_027_v1" \
		and String(representative_underground_case.get("catalog_town_minimum_status", "")) == "pass"
	var owner_corpus_coverage: Dictionary = owner_corpus.get("coverage", {}) if owner_corpus.get("coverage", {}) is Dictionary else {}
	var owner_corpus_ready := bool(owner_corpus_coverage.get("corpus_ready", false))
	var owner_corpus_gate: Dictionary = owner_corpus.get("comparison_gate", {}) if owner_corpus.get("comparison_gate", {}) is Dictionary else {}
	var mapped_owner_sample_parity: Array = owner_corpus.get("mapped_sample_parity", []) if owner_corpus.get("mapped_sample_parity", []) is Array else []
	var representative_owner_sample_coverage := _representative_owner_sample_coverage(cases, owner_corpus)
	var mapped_owner_sample_exact_parity := String(owner_corpus_gate.get("status", "")) == "pass" \
		and int(owner_corpus_gate.get("mapped_sample_count", 0)) >= 3 \
		and int(owner_corpus_gate.get("mapped_pass_count", 0)) == int(owner_corpus_gate.get("mapped_sample_count", 0)) \
		and _mapped_owner_sample_parity_summaries_pass(mapped_owner_sample_parity)
	for case_record in cases:
		if not (case_record is Dictionary):
			continue
		var case_dict: Dictionary = case_record
		all_cases_valid = all_cases_valid and String(case_dict.get("validation_status", "")) == "pass"
		all_catalog_town_minima_materialized = all_catalog_town_minima_materialized and String(case_dict.get("catalog_town_minimum_status", "")) == "pass"
		var route_closure: Dictionary = case_dict.get("package_route_closure", {}) if case_dict.get("package_route_closure", {}) is Dictionary else {}
		all_representative_package_routes_closed = all_representative_package_routes_closed and String(route_closure.get("status", "")) == "pass"
		var road_integrity: Dictionary = case_dict.get("package_road_integrity", {}) if case_dict.get("package_road_integrity", {}) is Dictionary else {}
		all_representative_package_roads_integrity = all_representative_package_roads_integrity and String(road_integrity.get("status", "")) == "pass"
		any_full_parity_claim = any_full_parity_claim or bool(case_dict.get("full_parity_claim", false))
		any_not_full_parity_status = any_not_full_parity_status or String(case_dict.get("full_generation_status", "")).ends_with("_not_full_parity")
		all_owner_compared = all_owner_compared and bool(case_dict.get("owner_compared_translated_profile_supported", false))
		all_defaults_supported_without_full_claim = all_defaults_supported_without_full_claim \
			and String(case_dict.get("validation_status", "")) == "pass" \
			and String(case_dict.get("full_generation_status", "")) != "not_implemented" \
			and not bool(case_dict.get("full_parity_claim", false))
	return [
		{
			"id": "native_gdextension_active",
			"requirement": "Native GDExtension RMG path is active.",
			"satisfied": String(metadata.get("binding_kind", "")) == "native_gdextension" and bool(metadata.get("native_extension_loaded", false)),
			"evidence": {"binding_kind": String(metadata.get("binding_kind", "")), "native_extension_loaded": bool(metadata.get("native_extension_loaded", false))},
		},
		{
			"id": "representative_defaults_generate",
			"requirement": "Representative player-facing defaults generate and validate.",
			"satisfied": all_cases_valid,
			"evidence": _case_statuses(cases),
		},
			{
				"id": "no_false_full_parity_claim",
			"requirement": "Implementation must not falsely claim full HoMM3 parity before evidence exists.",
			"satisfied": not any_full_parity_claim,
			"evidence": {"any_full_parity_claim": any_full_parity_claim},
			},
			{
				"id": "representative_catalog_town_minima_materialize",
				"requirement": "Representative player-facing translated defaults materialize active catalog player castle and neutral town/castle minima, except owner-compared profiles where parsed owner-H3M town counts supersede stale catalog minima.",
				"satisfied": all_catalog_town_minima_materialized,
				"evidence": _case_town_minima_statuses(cases),
			},
			{
				"id": "representative_package_route_closure",
				"requirement": "Representative player-facing defaults have package-level object-only and unresolved route closure for start-town, cross-zone, and all-town pairs.",
				"satisfied": all_representative_package_routes_closed,
				"evidence": _case_package_route_closure_statuses(cases),
			},
			{
				"id": "representative_package_road_integrity",
				"requirement": "Representative player-facing defaults serialize non-empty package roads with no empty road records, no duplicate road tiles, and package metadata matching unique serialized road tiles.",
				"satisfied": all_representative_package_roads_integrity,
				"evidence": _case_package_road_integrity_statuses(cases),
			},
			{
				"id": "mapped_owner_sample_exact_parity",
				"requirement": "Every currently mapped owner H3M sample has exact native parity for object, town, guard, road-cell, owner category, road-component, and semantic route/spacing gates.",
				"satisfied": mapped_owner_sample_exact_parity,
				"evidence": {
					"comparison_gate": owner_corpus_gate,
					"mapped_sample_parity": mapped_owner_sample_parity,
					"scope_boundary": "exact parity for currently mapped local samples only; this does not satisfy broad owner-H3M corpus coverage",
				},
			},
			{
				"id": "representative_owner_h3m_sample_coverage",
				"requirement": "Every representative player-facing default has at least one parsed owner-H3M sample with matching size, water mode, and underground/surface level shape.",
				"satisfied": bool(representative_owner_sample_coverage.get("all_representatives_have_owner_sample", false)),
				"evidence": representative_owner_sample_coverage,
			},
			{
				"id": "owner_xl_land_density_gap_diagnostic",
				"requirement": "Parsed owner XL land evidence is compared to the native Extra Large land default as a diagnostic object/guard/road/category density gap before exact XL parity is claimed.",
				"satisfied": String((owner_corpus.get("xl_land_density_diagnostic", {}) as Dictionary).get("status", "")) == "diagnosed" if owner_corpus.get("xl_land_density_diagnostic", {}) is Dictionary else false,
				"evidence": owner_corpus.get("xl_land_density_diagnostic", {}),
			},
			{
				"id": "owner_large_land_density_gap_diagnostic",
				"requirement": "Parsed owner Large land evidence is compared to the native Large land default as a diagnostic object/guard/road/category density gap before exact Large parity is claimed.",
				"satisfied": String((owner_corpus.get("large_land_density_diagnostic", {}) as Dictionary).get("status", "")) == "diagnosed" if owner_corpus.get("large_land_density_diagnostic", {}) is Dictionary else false,
				"evidence": owner_corpus.get("large_land_density_diagnostic", {}),
			},
			{
				"id": "full_homm3_style_parity",
			"requirement": "Generator reaches full HoMM3-style functional parity translated into original content.",
			"satisfied": false,
			"evidence": {"representative_cases_still_report_not_full_parity": any_not_full_parity_status, "case_statuses": _case_statuses(cases)},
		},
		{
			"id": "broad_template_player_facing_support",
			"requirement": "Player-facing generated-map startup uses a product policy that prefers owner-compared production defaults and does not expose broad structural templates as false production parity.",
			"satisfied": owner_compared_default_policy_supported,
			"evidence": {
				"catalog_template_count": catalog_template_count,
				"player_facing_template_count": player_facing_template_count,
				"player_facing_template_policy": String(setup_options.get("player_facing_template_policy", "")),
				"player_facing_auto_selection": auto_selection,
				"manual_template_picker_policy": "hidden_size_defaults_visible_native_auto_prefers_owner_compared_defaults_with_broad_internal_launch_gate",
			},
		},
		{
			"id": "translated_catalog_structural_route_closure_matrix",
			"requirement": "Recovered translated catalog structural generation has explicit full-sweep route-closure coverage for land/surface, Islands/surface, and land/underground lanes.",
			"satisfied": true,
			"evidence": {
				"scope_boundary": "structural route-closure evidence only; not owner-H3M corpus parity or player-facing underground production readiness",
				"land_surface": {
					"report_scene": "tests/native_random_map_broad_translated_catalog_route_closure_sweep_report.tscn",
					"eligible_translated_templates_attempted": 51,
					"translated_not_implemented_status_count": 0,
					"object_only_route_leak_count": 0,
					"zero_tile_road_count": 0,
				},
				"islands_surface": {
					"report_scene": "tests/native_random_map_broad_translated_catalog_islands_route_closure_sweep_report.tscn",
					"eligible_translated_templates_attempted": 45,
					"translated_not_implemented_status_count": 0,
					"object_only_route_leak_count": 0,
					"zero_tile_road_count": 0,
				},
				"land_underground": {
					"report_scene": "tests/native_random_map_broad_translated_catalog_underground_route_closure_sweep_report.tscn",
					"eligible_translated_templates_attempted": 47,
					"translated_not_implemented_status_count": 0,
					"object_only_route_leak_count": 0,
					"zero_tile_road_count": 0,
				},
			},
			},
			{
				"id": "representative_owner_compared_underground_support",
				"requirement": "Representative owner-compared Small underground generation validates with two levels and active catalog town minima.",
				"satisfied": representative_underground_supported,
				"evidence": {
					"case": representative_underground_case,
					"owner_corpus_has_underground_sample": bool(owner_corpus_coverage.get("has_underground_sample", false)),
					"scope_boundary": "representative owner-compared Small underground only; broad underground owner-H3M corpus breadth remains covered by broad_owner_h3m_comparison_corpus",
				},
			},
			{
				"id": "broad_owner_h3m_comparison_corpus",
				"requirement": "A broad owner-H3M comparison corpus covers size, water, underground, roads, zones, objects, guards, rewards, and reachability, not just the current three uploaded owner samples.",
			"satisfied": owner_corpus_ready,
			"evidence": {
				"candidate_count": int(owner_corpus.get("candidate_count", 0)),
				"readable_sample_ids": owner_corpus.get("readable_sample_ids", []),
				"parsed_metric_sample_ids": owner_corpus.get("parsed_metric_sample_ids", []),
				"coverage": owner_corpus_coverage,
				"mapped_comparison_gate": owner_corpus.get("comparison_gate", {}),
				"scope_boundary": "dynamic local owner evidence discovery only; readable samples still require mapped native comparisons and broader H3M corpus breadth before production parity can be claimed",
			},
		},
		{
			"id": "player_facing_defaults_supported_without_overclaim",
			"requirement": "Player-facing native-auto defaults generate with launchable structural/owner-compared support and no false full-parity claim.",
			"satisfied": all_defaults_supported_without_full_claim and all_owner_compared and owner_compared_default_policy_supported,
			"evidence": {
				"all_owner_compared": all_owner_compared,
				"owner_compared_default_policy_supported": owner_compared_default_policy_supported,
				"case_statuses": _case_statuses(cases),
			},
		},
			{
				"id": "underground_production_parity",
				"requirement": "Underground generation is production-ready when broadly exposed.",
				"satisfied": false,
				"evidence": {
					"current_policy": "player-facing underground remains bounded/disabled for broad exposure until owner-H3M corpus breadth covers more than the current Small underground sample",
					"representative_owner_compared_small_underground_supported": representative_underground_supported,
				},
			},
		]

func _objective_artifact_checklist(completion_checklist: Array, owner_corpus: Dictionary) -> Array:
	var by_id := _completion_checklist_by_id(completion_checklist)
	var owner_corpus_coverage: Dictionary = owner_corpus.get("coverage", {}) if owner_corpus.get("coverage", {}) is Dictionary else {}
	return [
		{
			"id": "native_gdextension_rmg_active",
			"objective_requirement": "Use the native GDExtension RMG path, not a prototype-only script fallback.",
			"repo_artifacts": ["MapPackageService API metadata", "tests/native_random_map_production_parity_completion_audit_report.gd"],
			"evidence": _checklist_evidence(by_id, "native_gdextension_active"),
			"satisfied": _checklist_satisfied(by_id, "native_gdextension_active"),
		},
		{
			"id": "player_facing_defaults_are_launchable",
			"objective_requirement": "Generated maps are usable through player-facing defaults, not only synthetic test fixtures.",
			"repo_artifacts": ["scripts/core/ScenarioSelectRules.gd", "representative production audit cases"],
			"evidence": {
				"representative_defaults_generate": _checklist_evidence(by_id, "representative_defaults_generate"),
				"player_facing_defaults_supported_without_overclaim": _checklist_evidence(by_id, "player_facing_defaults_supported_without_overclaim"),
			},
			"satisfied": _checklist_satisfied(by_id, "representative_defaults_generate") and _checklist_satisfied(by_id, "player_facing_defaults_supported_without_overclaim"),
		},
		{
			"id": "towns_zones_and_cross_zone_routes",
			"objective_requirement": "Towns and zones must not be stacked or reachable through free unguarded routes like the bad compact native sample.",
			"repo_artifacts": ["tests/native_random_map_package_surface_topology_report.gd", "tests/native_random_map_production_parity_completion_audit_report.gd"],
			"evidence": {
				"representative_catalog_town_minima_materialize": _checklist_evidence(by_id, "representative_catalog_town_minima_materialize"),
				"representative_package_route_closure": _checklist_evidence(by_id, "representative_package_route_closure"),
				"mapped_owner_sample_exact_parity": _checklist_evidence(by_id, "mapped_owner_sample_exact_parity"),
			},
			"satisfied": _checklist_satisfied(by_id, "representative_catalog_town_minima_materialize") \
				and _checklist_satisfied(by_id, "representative_package_route_closure") \
				and _checklist_satisfied(by_id, "mapped_owner_sample_exact_parity"),
		},
		{
			"id": "roads_match_loaded_map_surface",
			"objective_requirement": "Road placement must be present and coherent in the loaded map package, not merely counted in diagnostics.",
			"repo_artifacts": ["tests/native_random_map_production_parity_completion_audit_report.gd", "tests/native_random_map_homm3_owner_corpus_coverage_report.gd"],
			"evidence": {
				"representative_package_road_integrity": _checklist_evidence(by_id, "representative_package_road_integrity"),
				"mapped_owner_sample_exact_parity": _checklist_evidence(by_id, "mapped_owner_sample_exact_parity"),
			},
			"satisfied": _checklist_satisfied(by_id, "representative_package_road_integrity") and _checklist_satisfied(by_id, "mapped_owner_sample_exact_parity"),
		},
		{
			"id": "obstacles_guards_rewards_and_object_density",
			"objective_requirement": "Obstacles/blockers, guards, rewards, and object density must match owner-style behavior where local owner evidence exists.",
			"repo_artifacts": ["tests/native_random_map_homm3_owner_corpus_coverage_report.gd", "tests/native_random_map_production_parity_completion_audit_report.gd"],
			"evidence": _checklist_evidence(by_id, "mapped_owner_sample_exact_parity"),
			"large_land_density_diagnostic": owner_corpus.get("large_land_density_diagnostic", {}),
			"xl_land_density_diagnostic": owner_corpus.get("xl_land_density_diagnostic", {}),
			"satisfied": _checklist_satisfied(by_id, "mapped_owner_sample_exact_parity"),
			"scope_boundary": "Satisfied only for currently mapped local owner samples; broad corpus coverage remains separate.",
		},
		{
			"id": "translated_template_structural_breadth",
			"objective_requirement": "Recovered translated template breadth must generate structurally without route leaks across land, islands, and underground lanes.",
			"repo_artifacts": [
				"tests/native_random_map_broad_translated_catalog_route_closure_sweep_report.tscn",
				"tests/native_random_map_broad_translated_catalog_islands_route_closure_sweep_report.tscn",
				"tests/native_random_map_broad_translated_catalog_underground_route_closure_sweep_report.tscn",
			],
			"evidence": _checklist_evidence(by_id, "translated_catalog_structural_route_closure_matrix"),
			"satisfied": _checklist_satisfied(by_id, "translated_catalog_structural_route_closure_matrix"),
			"scope_boundary": "Structural translated-template evidence is not a substitute for broad owner-H3M parity evidence.",
		},
		{
			"id": "broad_owner_h3m_parity_corpus",
			"objective_requirement": "Real HoMM3-like parity must be proven against a broad owner-H3M corpus, including Large/XL and template breadth.",
			"repo_artifacts": ["tests/native_random_map_homm3_owner_corpus_coverage_report.gd", "local maps/ and inbound owner H3M evidence"],
			"evidence": {
				"broad_owner_h3m_comparison_corpus": _checklist_evidence(by_id, "broad_owner_h3m_comparison_corpus"),
				"representative_owner_h3m_sample_coverage": _checklist_evidence(by_id, "representative_owner_h3m_sample_coverage"),
				"owner_large_land_density_gap_diagnostic": _checklist_evidence(by_id, "owner_large_land_density_gap_diagnostic"),
				"owner_xl_land_density_gap_diagnostic": _checklist_evidence(by_id, "owner_xl_land_density_gap_diagnostic"),
				"coverage": owner_corpus_coverage,
			},
			"satisfied": _checklist_satisfied(by_id, "broad_owner_h3m_comparison_corpus") and _checklist_satisfied(by_id, "representative_owner_h3m_sample_coverage"),
			"missing": owner_corpus_coverage.get("missing_coverage", []),
		},
		{
			"id": "broad_underground_production_readiness",
			"objective_requirement": "Underground generation must be production-ready before broad player-facing exposure.",
			"repo_artifacts": ["tests/native_random_map_production_parity_completion_audit_report.gd", "tests/native_random_map_homm3_owner_corpus_coverage_report.gd"],
			"evidence": _checklist_evidence(by_id, "underground_production_parity"),
			"satisfied": _checklist_satisfied(by_id, "underground_production_parity"),
		},
		{
			"id": "full_production_ready_claim",
			"objective_requirement": "The generator may be called fully production-ready only when no full-parity, corpus, underground, runtime, or replay blockers remain.",
			"repo_artifacts": ["tests/native_random_map_production_parity_completion_audit_report.gd"],
			"evidence": {
				"full_homm3_style_parity": _checklist_evidence(by_id, "full_homm3_style_parity"),
				"no_false_full_parity_claim": _checklist_evidence(by_id, "no_false_full_parity_claim"),
			},
			"satisfied": _checklist_satisfied(by_id, "full_homm3_style_parity"),
		},
	]

func _completion_checklist_by_id(checklist: Array) -> Dictionary:
	var by_id := {}
	for item in checklist:
		if item is Dictionary:
			by_id[String(item.get("id", ""))] = item
	return by_id

func _checklist_satisfied(by_id: Dictionary, item_id: String) -> bool:
	var item: Dictionary = by_id.get(item_id, {}) if by_id.get(item_id, {}) is Dictionary else {}
	return bool(item.get("satisfied", false))

func _checklist_evidence(by_id: Dictionary, item_id: String) -> Variant:
	var item: Dictionary = by_id.get(item_id, {}) if by_id.get(item_id, {}) is Dictionary else {}
	return item.get("evidence", {})

func _case_statuses(cases: Array) -> Array:
	var result := []
	for case_record in cases:
		if case_record is Dictionary:
			var case_dict: Dictionary = case_record
			result.append({
				"id": String(case_dict.get("id", "")),
				"template_id": String(case_dict.get("template_id", "")),
				"profile_id": String(case_dict.get("profile_id", "")),
				"status": String(case_dict.get("status", "")),
				"full_generation_status": String(case_dict.get("full_generation_status", "")),
				"validation_status": String(case_dict.get("validation_status", "")),
			})
	return result

func _case_by_id(cases: Array, case_id: String) -> Dictionary:
	for case_record in cases:
		if case_record is Dictionary and String(case_record.get("id", "")) == case_id:
			return case_record
	return {}

func _case_town_minima_statuses(cases: Array) -> Array:
	var result := []
	for case_record in cases:
		if case_record is Dictionary:
			var case_dict: Dictionary = case_record
			result.append({
				"id": String(case_dict.get("id", "")),
				"template_id": String(case_dict.get("template_id", "")),
				"player_count": int(case_dict.get("player_count", 0)),
				"zone_count": int(case_dict.get("zone_count", 0)),
				"town_count": int(case_dict.get("town_count", 0)),
				"minimum_total_town_count": int(case_dict.get("catalog_minimum_town_count", 0)),
				"minimum_player_town_count": int(case_dict.get("catalog_minimum_player_town_count", 0)),
				"minimum_neutral_town_count": int(case_dict.get("catalog_minimum_neutral_town_count", 0)),
				"effective_minimum_total_town_count": int(case_dict.get("effective_minimum_town_count", case_dict.get("catalog_minimum_town_count", 0))),
				"effective_minimum_player_town_count": int(case_dict.get("effective_minimum_player_town_count", case_dict.get("catalog_minimum_player_town_count", 0))),
				"effective_minimum_neutral_town_count": int(case_dict.get("effective_minimum_neutral_town_count", case_dict.get("catalog_minimum_neutral_town_count", 0))),
				"town_minimum_source": String(case_dict.get("town_minimum_source", "catalog_minima")),
				"status": String(case_dict.get("catalog_town_minimum_status", "")),
			})
	return result

func _case_package_route_closure_statuses(cases: Array) -> Array:
	var result := []
	for case_record in cases:
		if case_record is Dictionary:
			var case_dict: Dictionary = case_record
			result.append({
				"id": String(case_dict.get("id", "")),
				"template_id": String(case_dict.get("template_id", "")),
				"profile_id": String(case_dict.get("profile_id", "")),
				"package_route_closure": case_dict.get("package_route_closure", {}),
			})
	return result

func _case_package_road_integrity_statuses(cases: Array) -> Array:
	var result := []
	for case_record in cases:
		if case_record is Dictionary:
			var case_dict: Dictionary = case_record
			result.append({
				"id": String(case_dict.get("id", "")),
				"template_id": String(case_dict.get("template_id", "")),
				"profile_id": String(case_dict.get("profile_id", "")),
				"road_cell_count": int(case_dict.get("road_cell_count", 0)),
				"package_road_cell_count": int(case_dict.get("package_road_cell_count", 0)),
				"package_road_integrity": case_dict.get("package_road_integrity", {}),
			})
	return result

func _owner_sample_coverage_records(samples: Array) -> Array:
	var result := []
	for sample_value in samples:
		if not (sample_value is Dictionary):
			continue
		var sample: Dictionary = sample_value
		if not bool(sample.get("readable", false)) or String(sample.get("metric_parse_status", "")) != "parsed":
			continue
		var terrain_summary: Dictionary = sample.get("terrain_summary", {}) if sample.get("terrain_summary", {}) is Dictionary else {}
		result.append({
			"id": String(sample.get("id", "")),
			"path": String(sample.get("path", "")),
			"size_class_id": String(sample.get("size_class_id", sample.get("expected_size_class_id", ""))),
			"water_mode": String(sample.get("water_mode", sample.get("expected_water_mode", ""))),
			"expected_water_mode": String(sample.get("expected_water_mode", "")),
			"water_mode_source": String(sample.get("water_mode_source", "")),
			"terrain_inferred_water_mode": String(sample.get("terrain_inferred_water_mode", "")),
			"terrain_water_mode_conflict": bool(sample.get("terrain_water_mode_conflict", false)),
			"level_count": int(sample.get("level_count", 0)),
			"has_underground": bool(sample.get("has_underground", false)),
			"terrain_water_tile_count": int(terrain_summary.get("water_tile_count", 0)),
			"terrain_rock_tile_count": int(terrain_summary.get("rock_tile_count", 0)),
			"terrain_water_ratio": float(terrain_summary.get("water_ratio", 0.0)),
			"terrain_surface_water_ratio": float(terrain_summary.get("surface_water_ratio", 0.0)),
			"terrain_rock_ratio": float(terrain_summary.get("rock_ratio", 0.0)),
			"object_count": int(sample.get("object_count", 0)),
			"declared_object_count": int(sample.get("declared_object_count", sample.get("object_count", 0))),
			"parsed_object_count": int(sample.get("parsed_object_count", sample.get("object_count", 0))),
			"object_instance_missing_count": int(sample.get("object_instance_missing_count", 0)),
			"object_instance_parse_quality": String(sample.get("object_instance_parse_quality", "")),
			"object_instance_parse_warning": String(sample.get("object_instance_parse_warning", "")),
			"town_count": int((sample.get("counts_by_category", {}) as Dictionary).get("town", 0)) if sample.get("counts_by_category", {}) is Dictionary else 0,
			"guard_count": int((sample.get("counts_by_category", {}) as Dictionary).get("guard", 0)) if sample.get("counts_by_category", {}) is Dictionary else 0,
			"road_cell_count_total": int(sample.get("road_cell_count_total", 0)),
		})
	return result

func _representative_owner_sample_coverage(cases: Array, owner_corpus: Dictionary) -> Dictionary:
	var records: Array = owner_corpus.get("parsed_sample_coverage", []) if owner_corpus.get("parsed_sample_coverage", []) is Array else []
	var by_case := []
	var missing := []
	for case_value in cases:
		if not (case_value is Dictionary):
			continue
		var case_record: Dictionary = case_value
		var expected_level_count := int(case_record.get("level_count", 0))
		var expects_underground := expected_level_count > 1
		var matches := []
		for record_value in records:
			if not (record_value is Dictionary):
				continue
			var record: Dictionary = record_value
			if String(record.get("size_class_id", "")) != String(case_record.get("size_class_id", "")):
				continue
			if String(record.get("water_mode", "")) != String(case_record.get("water_mode", "")):
				continue
			if bool(record.get("has_underground", false)) != expects_underground:
				continue
			matches.append(String(record.get("id", "")))
		var case_summary := {
			"id": String(case_record.get("id", "")),
			"template_id": String(case_record.get("template_id", "")),
			"size_class_id": String(case_record.get("size_class_id", "")),
			"water_mode": String(case_record.get("water_mode", "")),
			"level_count": expected_level_count,
			"requires_underground_sample": expects_underground,
			"matching_owner_sample_ids": matches,
			"has_matching_owner_sample": not matches.is_empty(),
		}
		by_case.append(case_summary)
		if matches.is_empty():
			missing.append(case_summary)
	return {
		"all_representatives_have_owner_sample": missing.is_empty(),
		"parsed_owner_sample_count": records.size(),
		"by_case": by_case,
		"missing_cases": missing,
		"scope_boundary": "matches size class, water mode, and surface/underground level shape; it does not prove template-by-template corpus breadth by itself",
	}

func _owner_sample_parity_summaries(samples: Array) -> Array:
	var result := []
	for sample_value in samples:
		if not (sample_value is Dictionary):
			continue
		var sample: Dictionary = sample_value
		var comparison: Dictionary = sample.get("native_comparison", {}) if sample.get("native_comparison", {}) is Dictionary else {}
		if String(comparison.get("status", "")) != "compared":
			continue
		var deltas: Dictionary = comparison.get("deltas_vs_owner", {}) if comparison.get("deltas_vs_owner", {}) is Dictionary else {}
		var category_comparison: Dictionary = comparison.get("category_count_comparison", {}) if comparison.get("category_count_comparison", {}) is Dictionary else {}
		var road_topology: Dictionary = comparison.get("road_topology_comparison_by_level", {}) if comparison.get("road_topology_comparison_by_level", {}) is Dictionary else {}
		var semantic: Dictionary = comparison.get("semantic_layout_comparison", {}) if comparison.get("semantic_layout_comparison", {}) is Dictionary else {}
		result.append({
			"id": String(sample.get("id", "")),
			"path": String(sample.get("path", "")),
			"template_id": String(comparison.get("template_id", "")),
			"profile_id": String(comparison.get("profile_id", "")),
			"size_class_id": String(comparison.get("size_class_id", "")),
			"water_mode": String(comparison.get("water_mode", "")),
			"level_count": int(comparison.get("level_count", 0)),
			"validation_status": String(comparison.get("validation_status", "")),
			"full_generation_status": String(comparison.get("full_generation_status", "")),
			"deltas_vs_owner": deltas,
			"category_count_status": String(category_comparison.get("status", "")),
			"category_absolute_delta_total": int(category_comparison.get("absolute_delta_total", 0)),
			"road_topology_status": String(road_topology.get("status", "")),
			"road_component_size_abs_delta_total": int(road_topology.get("component_size_abs_delta_total", 0)),
			"road_component_count_abs_delta_total": int(road_topology.get("component_count_abs_delta_total", 0)),
			"semantic_layout_status": String(semantic.get("status", "")),
			"native_object_route_reachable_pair_count_total": int(semantic.get("native_object_route_reachable_pair_count_total", 0)),
			"native_guarded_route_reachable_pair_count_total": int(semantic.get("native_guarded_route_reachable_pair_count_total", 0)),
			"native_nearest_town_manhattan_min": int(semantic.get("native_nearest_town_manhattan_min", 0)),
			"owner_nearest_town_manhattan_min": int(semantic.get("owner_nearest_town_manhattan_min", 0)),
			"guard_control_ratio": float(semantic.get("guard_control_ratio", 0.0)),
		})
	return result

func _mapped_owner_sample_parity_summaries_pass(summaries: Array) -> bool:
	if summaries.is_empty():
		return false
	for summary_value in summaries:
		if not (summary_value is Dictionary):
			return false
		var summary: Dictionary = summary_value
		var deltas: Dictionary = summary.get("deltas_vs_owner", {}) if summary.get("deltas_vs_owner", {}) is Dictionary else {}
		for key in ["object_count_delta", "town_count_delta", "guard_count_delta", "road_cell_count_delta"]:
			if int(deltas.get(key, 0)) != 0:
				return false
		if String(summary.get("validation_status", "")) != "pass":
			return false
		if String(summary.get("category_count_status", "")) != "category_counts_match" or int(summary.get("category_absolute_delta_total", 0)) != 0:
			return false
		if String(summary.get("road_topology_status", "")) != "all_level_component_sizes_match" \
				or int(summary.get("road_component_size_abs_delta_total", 0)) != 0 \
				or int(summary.get("road_component_count_abs_delta_total", 0)) != 0:
			return false
		if String(summary.get("semantic_layout_status", "")) != "semantic_layout_match" \
				or int(summary.get("native_object_route_reachable_pair_count_total", 0)) != 0 \
				or int(summary.get("native_guarded_route_reachable_pair_count_total", 0)) != 0:
			return false
	return true

func _catalog_town_minima_for_normalized_config(normalized: Dictionary) -> Dictionary:
	var template := _catalog_template(String(normalized.get("template_id", "")))
	var player_constraints: Dictionary = normalized.get("player_constraints", {}) if normalized.get("player_constraints", {}) is Dictionary else {}
	var player_count := int(player_constraints.get("player_count", 0))
	var human_count := int(player_constraints.get("human_count", 1))
	var minimum_player_towns := 0
	var minimum_neutral_towns := 0
	var active_zone_count := 0
	for zone_value in template.get("zones", []):
		if not (zone_value is Dictionary):
			continue
		var zone: Dictionary = zone_value
		if not _catalog_player_filter_allows(zone, human_count, player_count):
			continue
		active_zone_count += 1
		var owner_slot := int(zone.get("owner_slot", 0)) if zone.get("owner_slot", null) != null else 0
		var source_role := String(zone.get("role", ""))
		var source_start_zone := source_role.find("start") >= 0
		var active_owned_zone := owner_slot > 0 and owner_slot <= player_count
		var active_player_zone := active_owned_zone and source_start_zone
		var player_rules: Dictionary = zone.get("player_towns", {}) if zone.get("player_towns", {}) is Dictionary else {}
		var neutral_rules: Dictionary = zone.get("neutral_towns", {}) if zone.get("neutral_towns", {}) is Dictionary else {}
		if active_player_zone:
			minimum_player_towns += max(1, int(player_rules.get("min_castles", 1)))
			minimum_player_towns += max(0, int(player_rules.get("min_towns", 0)))
		elif owner_slot > 0 and source_start_zone:
			minimum_neutral_towns += max(0, int(player_rules.get("min_castles", 0)))
			minimum_neutral_towns += max(0, int(player_rules.get("min_towns", 0)))
		minimum_neutral_towns += max(0, int(neutral_rules.get("min_castles", 0)))
		minimum_neutral_towns += max(0, int(neutral_rules.get("min_towns", 0)))
	return {
		"schema_id": "native_random_map_catalog_town_minima_v1",
		"catalog_source": TEMPLATE_CATALOG_PATH,
		"template_id": String(normalized.get("template_id", "")),
		"source": "catalog_minima",
		"active_zone_count": active_zone_count,
		"player_count": player_count,
		"human_count": human_count,
		"minimum_player_town_count": minimum_player_towns,
		"minimum_neutral_town_count": minimum_neutral_towns,
		"minimum_total_town_count": minimum_player_towns + minimum_neutral_towns,
		"scope": "active template zones after player_filter; optional density towns are not required by this minimum gate",
	}

func _effective_town_minima_for_normalized_config(normalized: Dictionary, catalog_minima: Dictionary) -> Dictionary:
	var player_constraints: Dictionary = normalized.get("player_constraints", {}) if normalized.get("player_constraints", {}) is Dictionary else {}
	var player_count := int(player_constraints.get("player_count", 0))
	if String(normalized.get("size_class_id", "")) == "homm3_large" \
			and String(normalized.get("water_mode", "")) == "land" \
			and int(normalized.get("level_count", 1)) == 1 \
			and String(normalized.get("template_id", "")) == "translated_rmg_template_042_v1" \
			and String(normalized.get("profile_id", "")) == "translated_rmg_profile_042_v1" \
			and player_count == 4:
		return {
			"schema_id": "native_random_map_effective_town_minima_v1",
			"template_id": String(normalized.get("template_id", "")),
			"profile_id": String(normalized.get("profile_id", "")),
			"source": "owner_discovered_l_nowater_randomplayers_nounder_town_count_supersedes_catalog_minima",
			"player_count": player_count,
			"minimum_player_town_count": player_count,
			"minimum_neutral_town_count": 4,
			"minimum_total_town_count": 8,
			"catalog_minimum_total_town_count": int(catalog_minima.get("minimum_total_town_count", 0)),
		}
	if String(normalized.get("size_class_id", "")) == "homm3_extra_large" \
			and String(normalized.get("water_mode", "")) == "land" \
			and int(normalized.get("level_count", 1)) == 1 \
			and String(normalized.get("template_id", "")) == "translated_rmg_template_043_v1" \
			and String(normalized.get("profile_id", "")) == "translated_rmg_profile_043_v1" \
			and player_count == 5:
		return {
			"schema_id": "native_random_map_effective_town_minima_v1",
			"template_id": String(normalized.get("template_id", "")),
			"profile_id": String(normalized.get("profile_id", "")),
			"source": "owner_discovered_xl_nowater_town_count_supersedes_catalog_minima",
			"player_count": player_count,
			"minimum_player_town_count": player_count,
			"minimum_neutral_town_count": 7,
			"minimum_total_town_count": 12,
			"catalog_minimum_total_town_count": int(catalog_minima.get("minimum_total_town_count", 0)),
		}
	return catalog_minima

func _catalog_template(template_id: String) -> Dictionary:
	if template_id.strip_edges().is_empty():
		return {}
	var file := FileAccess.open(TEMPLATE_CATALOG_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return {}
	for template_value in (parsed as Dictionary).get("templates", []):
		if template_value is Dictionary and String((template_value as Dictionary).get("id", "")) == template_id:
			return (template_value as Dictionary).duplicate(true)
	return {}

func _catalog_player_filter_allows(record: Dictionary, human_count: int, player_count: int) -> bool:
	var filter: Dictionary = record.get("player_filter", {}) if record.get("player_filter", {}) is Dictionary else {}
	if filter.is_empty():
		return true
	return human_count >= int(filter.get("min_human", 0)) \
		and human_count <= int(filter.get("max_human", 8)) \
		and player_count >= int(filter.get("min_total", 1)) \
		and player_count <= int(filter.get("max_total", 8))

func _fail(message: String) -> void:
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"schema_id": REPORT_SCHEMA_ID,
		"ok": false,
		"error": message,
	})])
	get_tree().quit(1)
