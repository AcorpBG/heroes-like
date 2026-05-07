extends Node

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")

const REPORT_ID := "NATIVE_RANDOM_MAP_HOMM3_OWNER_CORPUS_COVERAGE_REPORT"
const REPORT_SCHEMA_ID := "native_random_map_homm3_owner_corpus_coverage_report_v5"
const HOMM3_RE_OBJECT_METADATA := "/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/object-metadata-by-type.json"

const HOMM3_VERSION_ROE := 14
const HOMM3_VERSION_AB := 21
const HOMM3_VERSION_SOD := 28
const OBJECT_TEMPLATE_RECORD_BYTES_AFTER_NAME := 42
const H3M_TILE_BYTES_PER_CELL := 7
const OBJECT_INSTANCE_TAIL_PARSE_MISSING_COUNT_TOLERANCE := 32
const OBJECT_INSTANCE_TAIL_PARSE_BYTE_TOLERANCE := 64
const H3M_BLOCKING_TERRAIN_TYPE_IDS := {8: true, 9: true}
const DECORATION_TYPE_IDS := {
	118: true, 119: true, 120: true, 134: true, 135: true, 136: true,
	137: true, 147: true, 150: true, 155: true, 199: true, 207: true,
	210: true,
}
const GUARD_TYPE_IDS := {54: true, 71: true}
const TOWN_TYPE_IDS := {98: true}
const RESOURCE_REWARD_TYPE_IDS := {5: true, 53: true, 79: true, 83: true, 88: true, 89: true, 90: true, 93: true, 101: true}

const OWNER_H3M_CANDIDATES := [
	{
		"id": "owner_small_land_single_level",
		"path": "res://maps/small3playermap-1level.h3m",
		"expected_size_class_id": "homm3_small",
		"expected_water_mode": "land",
		"local_evidence_policy": "uploaded_owner_evidence_not_committed",
	},
	{
		"id": "owner_small_with_underground",
		"path": "res://maps/small3playermap.h3m",
		"expected_size_class_id": "homm3_small",
		"expected_water_mode": "land",
		"local_evidence_policy": "uploaded_owner_evidence_not_committed",
	},
	{
		"id": "owner_medium_islands",
		"path": "/root/.openclaw/media/inbound/Untitled---cad43d4f-6faa-4059-a9db-9b37770806af.gz",
		"expected_size_class_id": "homm3_medium",
		"expected_water_mode": "islands",
		"local_evidence_policy": "uploaded_owner_evidence_not_committed",
	},
]
const OWNER_H3M_DISCOVERY_DIRS := ["res://maps", "res://maps/h3m-maps", "/root/.openclaw/media/inbound"]

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not ClassDB.class_exists("MapPackageService"):
		_fail("MapPackageService native class is not available.")
		return
	var service: Variant = ClassDB.instantiate("MapPackageService")
	var samples := []
	for candidate in owner_h3m_candidates():
		if not (candidate is Dictionary):
			continue
		var sample := _sample_header(candidate)
		if bool(sample.get("readable", false)) and String(sample.get("metric_parse_status", "")) == "parsed":
			sample["native_comparison"] = _native_comparison_for_sample(service, sample)
		if not sample.is_empty():
			samples.append(sample)
	var coverage := _coverage_summary(samples)
	if samples.is_empty():
		_fail("No owner H3M evidence samples are readable.")
		return
	var comparison_gate := _comparison_gate_summary(samples)
	var gate_self_check := _comparison_gate_self_check()
	var large_land_density_diagnostic := _owner_large_land_density_diagnostic(service, samples)
	var xl_land_density_diagnostic := _owner_xl_land_density_diagnostic(service, samples)
	var ok := String(comparison_gate.get("status", "")) == "pass" and String(gate_self_check.get("status", "")) == "pass"
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"schema_id": REPORT_SCHEMA_ID,
		"ok": ok,
		"corpus_ready": bool(coverage.get("corpus_ready", false)),
		"sample_count": samples.size(),
		"samples": samples,
		"coverage": coverage,
		"comparison_gate": comparison_gate,
		"comparison_gate_self_check": gate_self_check,
		"large_land_density_diagnostic": large_land_density_diagnostic,
		"xl_land_density_diagnostic": xl_land_density_diagnostic,
		"remaining_gap": "This report inventories readable owner H3M sample coverage and compares available samples against corresponding native outputs where supported. It does not import H3M data into runtime content and does not prove broad production parity.",
	})])
	get_tree().quit(0 if ok else 1)

func owner_h3m_candidates() -> Array:
	var candidates := []
	var seen_paths := {}
	for candidate in OWNER_H3M_CANDIDATES:
		if not (candidate is Dictionary):
			continue
		var candidate_copy: Dictionary = candidate.duplicate(true)
		var path := String(candidate_copy.get("path", ""))
		if path.is_empty() or seen_paths.has(path):
			continue
		seen_paths[path] = true
		candidates.append(candidate_copy)
	for directory in OWNER_H3M_DISCOVERY_DIRS:
		for path in _discover_h3m_paths(String(directory)):
			if seen_paths.has(path):
				continue
			seen_paths[path] = true
			candidates.append(_discovered_candidate_for_path(path))
	return candidates

func sample_header(candidate: Dictionary) -> Dictionary:
	return _sample_header(candidate)

func coverage_summary(samples: Array) -> Dictionary:
	return _coverage_summary(samples)

func comparison_gate_summary(samples: Array) -> Dictionary:
	return _comparison_gate_summary(samples)

func owner_xl_land_density_diagnostic(service: Variant, samples: Array) -> Dictionary:
	return _owner_xl_land_density_diagnostic(service, samples)

func owner_large_land_density_diagnostic(service: Variant, samples: Array) -> Dictionary:
	return _owner_large_land_density_diagnostic(service, samples)

func _discover_h3m_paths(directory_path: String) -> Array:
	var result := []
	var dir := DirAccess.open(directory_path)
	if dir == null:
		return result
	dir.list_dir_begin()
	while true:
		var file_name := dir.get_next()
		if file_name.is_empty():
			break
		if dir.current_is_dir():
			continue
		var lower_name := file_name.to_lower()
		if not (lower_name.ends_with(".h3m") or lower_name.ends_with(".gz")):
			continue
		result.append(directory_path.path_join(file_name))
	dir.list_dir_end()
	result.sort()
	return result

func _discovered_candidate_for_path(path: String) -> Dictionary:
	var file_name := path.get_file()
	var stem := file_name.get_basename().to_lower().replace(" ", "_").replace("-", "_")
	return {
		"id": "owner_discovered_%s" % stem,
		"path": path,
		"expected_size_class_id": _expected_size_class_from_name(file_name),
		"expected_water_mode": _expected_water_mode_from_name(file_name),
		"local_evidence_policy": "auto_discovered_uploaded_owner_evidence_not_committed",
	}

func _expected_size_class_from_name(file_name: String) -> String:
	var lower_name := file_name.to_lower()
	var stem := lower_name.get_basename().replace(" ", "_")
	if stem.begins_with("xl_") or stem.begins_with("xl-") or stem == "xl" \
			or "extra_large" in lower_name or "extra-large" in lower_name or "_xl" in lower_name or "-xl" in lower_name:
		return "homm3_extra_large"
	if stem.begins_with("l_") or stem.begins_with("l-") or stem == "l" or "large" in lower_name:
		return "homm3_large"
	if stem.begins_with("m_") or stem.begins_with("m-") or stem == "m" or "medium" in lower_name:
		return "homm3_medium"
	if stem.begins_with("s_") or stem.begins_with("s-") or stem == "s" or "small" in lower_name:
		return "homm3_small"
	return "unknown"

func _expected_water_mode_from_name(file_name: String) -> String:
	var lower_name := file_name.to_lower()
	if "island" in lower_name:
		return "islands"
	if "nowater" in lower_name or "no_water" in lower_name or "no-water" in lower_name or "land" in lower_name:
		return "land"
	if "normalwater" in lower_name or "normalw" in lower_name or "normal_water" in lower_name or "normal-water" in lower_name or "water" in lower_name:
		return "normal_water"
	return "unknown"

func _resolved_water_mode(expected_water_mode: String, terrain_inferred_water_mode: String) -> String:
	if expected_water_mode != "unknown":
		return expected_water_mode
	if terrain_inferred_water_mode != "unknown":
		return terrain_inferred_water_mode
	return "unknown"

func _sample_header(candidate: Dictionary) -> Dictionary:
	var path := String(candidate.get("path", ""))
	if not FileAccess.file_exists(path):
		return {
			"id": String(candidate.get("id", "")),
			"path": path,
			"present": false,
			"readable": false,
			"local_evidence_policy": String(candidate.get("local_evidence_policy", "")),
		}
	var compressed := FileAccess.get_file_as_bytes(path)
	if compressed.is_empty():
		return {
			"id": String(candidate.get("id", "")),
			"path": path,
			"present": true,
			"readable": false,
			"error": "empty_or_unreadable_file",
			"local_evidence_policy": String(candidate.get("local_evidence_policy", "")),
		}
	var bytes := compressed.decompress_dynamic(20000000, 3)
	if bytes.is_empty() or bytes.size() < 10:
		return {
			"id": String(candidate.get("id", "")),
			"path": path,
			"present": true,
			"readable": false,
			"error": "gzip_decompress_failed_or_short_header",
			"gzip_bytes": compressed.size(),
			"local_evidence_policy": String(candidate.get("local_evidence_policy", "")),
		}
	var version := _u32(bytes, 0)
	var width := _u32(bytes, 5)
	var has_underground := int(bytes[9]) != 0
	var level_count := 2 if has_underground else 1
	var metrics := _sample_metrics(bytes, width, level_count)
	var expected_water_mode := String(candidate.get("expected_water_mode", "unknown"))
	var terrain_summary: Dictionary = metrics.get("terrain_summary", {}) if metrics.get("terrain_summary", {}) is Dictionary else {}
	var terrain_inferred_water_mode := String(terrain_summary.get("inferred_water_mode", "unknown"))
	var resolved_water_mode := _resolved_water_mode(expected_water_mode, terrain_inferred_water_mode)
	var readable := version in [HOMM3_VERSION_ROE, HOMM3_VERSION_AB, HOMM3_VERSION_SOD] and width > 0
	return {
		"id": String(candidate.get("id", "")),
		"path": path,
		"present": true,
		"readable": readable,
		"version": version,
		"width": width,
		"height": width,
		"level_count": level_count,
		"has_underground": has_underground,
		"size_class_id": _size_class_for_width(width),
		"expected_size_class_id": String(candidate.get("expected_size_class_id", "")),
		"expected_water_mode": expected_water_mode,
		"water_mode": resolved_water_mode,
		"water_mode_source": "terrain_inference" if expected_water_mode == "unknown" and terrain_inferred_water_mode != "unknown" else "candidate_label",
		"terrain_inferred_water_mode": terrain_inferred_water_mode,
		"terrain_water_mode_conflict": expected_water_mode != "unknown" and terrain_inferred_water_mode != "unknown" and expected_water_mode != terrain_inferred_water_mode,
		"gzip_bytes": compressed.size(),
		"decompressed_h3m_bytes": bytes.size(),
		"metric_parse_status": String(metrics.get("status", "not_attempted")),
		"metric_parse_error": String(metrics.get("error", "")),
		"object_instance_parse_quality": String(metrics.get("parse_quality", "")),
		"object_instance_parse_warning": String(metrics.get("parse_warning", "")),
		"declared_object_count": int(metrics.get("declared_object_count", metrics.get("object_count", 0))),
		"parsed_object_count": int(metrics.get("parsed_object_count", metrics.get("object_count", 0))),
		"object_instance_missing_count": int(metrics.get("missing_object_instance_count", 0)),
		"object_instance_tail_bytes": int(metrics.get("tail_bytes", 0)),
		"object_definition_count": int(metrics.get("object_definition_count", 0)),
		"object_count": int(metrics.get("object_count", 0)),
		"counts_by_category": metrics.get("counts_by_category", {}),
		"counts_by_level": metrics.get("counts_by_level", {}),
		"terrain_summary": terrain_summary,
		"road_cell_count_by_level": metrics.get("road_cell_count_by_level", {}),
			"road_cell_count_total": int(metrics.get("road_cell_count_total", 0)),
			"road_component_count_by_level": metrics.get("road_component_count_by_level", {}),
			"road_component_sizes_by_level": metrics.get("road_component_sizes_by_level", {}),
			"semantic_layout": metrics.get("semantic_layout", {}),
			"local_evidence_policy": String(candidate.get("local_evidence_policy", "")),
		}

func _coverage_summary(samples: Array) -> Dictionary:
	var readable := []
	var size_classes := {}
	var water_modes := {}
	var level_counts := {}
	var has_large_or_xl := false
	var has_underground := false
	var parsed_metric_count := 0
	var tail_count_mismatch_sample_ids := []
	for sample_value in samples:
		if not (sample_value is Dictionary):
			continue
		var sample: Dictionary = sample_value
		if not bool(sample.get("readable", false)):
			continue
		readable.append(sample)
		var size_class_id := String(sample.get("size_class_id", "unknown"))
		size_classes[size_class_id] = int(size_classes.get(size_class_id, 0)) + 1
		var water_mode := String(sample.get("water_mode", sample.get("expected_water_mode", "unknown")))
		water_modes[water_mode] = int(water_modes.get(water_mode, 0)) + 1
		var level_key := str(int(sample.get("level_count", 0)))
		level_counts[level_key] = int(level_counts.get(level_key, 0)) + 1
		has_large_or_xl = has_large_or_xl or size_class_id in ["homm3_large", "homm3_extra_large"]
		has_underground = has_underground or bool(sample.get("has_underground", false))
		if String(sample.get("metric_parse_status", "")) == "parsed":
			parsed_metric_count += 1
			if int(sample.get("object_instance_missing_count", 0)) > 0:
				tail_count_mismatch_sample_ids.append(String(sample.get("id", "")))
	var missing := []
	if not size_classes.has("homm3_small"):
		missing.append("small_h3m_sample")
	if not size_classes.has("homm3_medium"):
		missing.append("medium_h3m_sample")
	if not has_large_or_xl:
		missing.append("large_or_xl_h3m_sample")
	if not water_modes.has("islands"):
		missing.append("islands_h3m_sample")
	if not has_underground:
		missing.append("underground_h3m_sample")
	missing.append("template_breadth_corpus")
	if parsed_metric_count < readable.size():
		missing.append("full_object_road_guard_reward_metric_parser_for_all_corpus_samples")
	if not tail_count_mismatch_sample_ids.is_empty():
		missing.append("object_instance_tail_count_mismatch_samples")
	return {
		"readable_sample_count": readable.size(),
		"parsed_metric_sample_count": parsed_metric_count,
		"size_class_counts": size_classes,
		"water_mode_counts": water_modes,
		"level_count_counts": level_counts,
		"has_underground_sample": has_underground,
		"object_instance_tail_count_mismatch_sample_ids": tail_count_mismatch_sample_ids,
		"missing_coverage": missing,
		"missing_coverage_count": missing.size(),
		"corpus_ready": missing.is_empty(),
	}

func _comparison_gate_summary(samples: Array) -> Dictionary:
	var failures := []
	var mapped_sample_count := 0
	var mapped_pass_count := 0
	var unmapped_sample_ids := []
	for sample_value in samples:
		if not (sample_value is Dictionary):
			continue
		var sample: Dictionary = sample_value
		if not bool(sample.get("readable", false)) or String(sample.get("metric_parse_status", "")) != "parsed":
			continue
		var comparison: Dictionary = sample.get("native_comparison", {}) if sample.get("native_comparison", {}) is Dictionary else {}
		if comparison.is_empty() or String(comparison.get("status", "")) == "not_compared":
			unmapped_sample_ids.append(String(sample.get("id", "")))
			continue
		mapped_sample_count += 1
		var sample_failures := _mapped_comparison_failures(sample, comparison)
		if sample_failures.is_empty():
			mapped_pass_count += 1
		else:
			failures.append({
				"sample_id": String(sample.get("id", "")),
				"path": String(sample.get("path", "")),
				"failure_count": sample_failures.size(),
				"failures": sample_failures,
			})
	if mapped_sample_count == 0:
		failures.append({
			"sample_id": "",
			"path": "",
			"failure_count": 1,
			"failures": [{
				"code": "no_mapped_owner_samples_compared",
				"message": "No readable parsed owner H3M sample had a native comparison mapping.",
			}],
		})
	return {
		"schema_id": "native_random_map_homm3_owner_corpus_mapped_comparison_gate_v1",
		"status": "pass" if failures.is_empty() else "fail",
		"mapped_sample_count": mapped_sample_count,
		"mapped_pass_count": mapped_pass_count,
		"unmapped_parsed_sample_count": unmapped_sample_ids.size(),
		"unmapped_parsed_sample_ids": unmapped_sample_ids,
		"failure_count": failures.size(),
		"failures": failures,
			"policy": "mapped owner H3M samples are hard-gated on native generation/package conversion, validation, object/town/guard/road deltas, owner category counts, per-level road component topology, town spacing, guard footprint, and unguarded/object-only town route closure",
		}

func _mapped_comparison_failures(sample: Dictionary, comparison: Dictionary) -> Array:
	var failures := []
	var comparison_status := String(comparison.get("status", ""))
	if comparison_status != "compared":
		failures.append({
			"code": "native_comparison_status_not_compared",
			"status": comparison_status,
			"message": "Mapped owner sample did not produce a successful native comparison.",
		})
		return failures
	var validation_status := String(comparison.get("validation_status", ""))
	if validation_status != "pass":
		failures.append({
			"code": "native_validation_status_not_pass",
			"validation_status": validation_status,
		})
	var full_generation_status := String(comparison.get("full_generation_status", ""))
	if full_generation_status == "not_implemented":
		failures.append({
			"code": "native_generation_not_implemented",
			"full_generation_status": full_generation_status,
		})
	var deltas: Dictionary = comparison.get("deltas_vs_owner", {}) if comparison.get("deltas_vs_owner", {}) is Dictionary else {}
	for key in ["object_count_delta", "town_count_delta", "guard_count_delta", "road_cell_count_delta"]:
		var delta := int(deltas.get(key, 0))
		if delta != 0:
			failures.append({
				"code": key,
				"delta": delta,
				"owner_sample_id": String(sample.get("id", "")),
			})
	var category_comparison: Dictionary = comparison.get("category_count_comparison", {}) if comparison.get("category_count_comparison", {}) is Dictionary else {}
	if String(category_comparison.get("status", "")) != "category_counts_match" or int(category_comparison.get("absolute_delta_total", 0)) != 0:
		failures.append({
			"code": "category_count_gap",
			"absolute_delta_total": int(category_comparison.get("absolute_delta_total", 0)),
			"by_category": category_comparison.get("by_category", {}),
		})
	var road_topology_by_level: Dictionary = comparison.get("road_topology_comparison_by_level", {}) if comparison.get("road_topology_comparison_by_level", {}) is Dictionary else {}
	if String(road_topology_by_level.get("status", "")) != "all_level_component_sizes_match" \
			or int(road_topology_by_level.get("component_size_abs_delta_total", 0)) != 0 \
			or int(road_topology_by_level.get("component_count_abs_delta_total", 0)) != 0:
		failures.append({
			"code": "road_topology_gap",
			"status": String(road_topology_by_level.get("status", "")),
			"component_size_abs_delta_total": int(road_topology_by_level.get("component_size_abs_delta_total", 0)),
			"component_count_abs_delta_total": int(road_topology_by_level.get("component_count_abs_delta_total", 0)),
			"gap_levels": road_topology_by_level.get("gap_levels", []),
		})
	var semantic_layout: Dictionary = comparison.get("semantic_layout_comparison", {}) if comparison.get("semantic_layout_comparison", {}) is Dictionary else {}
	if String(semantic_layout.get("status", "")) != "semantic_layout_match":
		failures.append({
			"code": "semantic_layout_gap",
			"status": String(semantic_layout.get("status", "")),
			"failure_codes": semantic_layout.get("failure_codes", []),
			"nearest_town_manhattan_delta": int(semantic_layout.get("nearest_town_manhattan_delta", 0)),
			"native_object_route_reachable_pair_count_total": int(semantic_layout.get("native_object_route_reachable_pair_count_total", 0)),
			"native_guarded_route_reachable_pair_count_total": int(semantic_layout.get("native_guarded_route_reachable_pair_count_total", 0)),
			"guard_control_ratio": float(semantic_layout.get("guard_control_ratio", 0.0)),
		})
	return failures

func _comparison_gate_self_check() -> Dictionary:
	var synthetic_samples := [
		{
			"id": "synthetic_owner_gap",
			"path": "synthetic://owner-gap.h3m",
			"readable": true,
			"metric_parse_status": "parsed",
			"native_comparison": {
				"status": "compared",
				"validation_status": "pass",
				"full_generation_status": "owner_compared_translated_profile_not_full_parity",
				"deltas_vs_owner": {
					"object_count_delta": 1,
					"town_count_delta": 0,
					"guard_count_delta": -1,
					"road_cell_count_delta": 2,
				},
				"category_count_comparison": {
					"status": "category_count_gap",
					"absolute_delta_total": 4,
					"by_category": {"reward": {"delta": -2}},
				},
					"road_topology_comparison_by_level": {
						"status": "level_topology_gap",
						"component_size_abs_delta_total": 3,
						"component_count_abs_delta_total": 1,
						"gap_levels": ["0"],
					},
					"semantic_layout_comparison": {
						"status": "semantic_layout_gap",
						"failure_codes": ["native_town_spacing_below_owner_floor", "native_object_route_leak", "native_guard_footprint_below_owner_floor"],
						"nearest_town_manhattan_delta": -5,
						"native_object_route_reachable_pair_count_total": 1,
						"native_guarded_route_reachable_pair_count_total": 1,
						"guard_control_ratio": 0.25,
					},
				},
			},
		]
	var gate := _comparison_gate_summary(synthetic_samples)
	var observed_codes := {}
	var failures: Array = gate.get("failures", []) if gate.get("failures", []) is Array else []
	for failure_record in failures:
		if not (failure_record is Dictionary):
			continue
		var nested: Array = failure_record.get("failures", []) if failure_record.get("failures", []) is Array else []
		for nested_failure in nested:
			if nested_failure is Dictionary:
				observed_codes[String(nested_failure.get("code", ""))] = true
	var required_codes := [
		"object_count_delta",
		"guard_count_delta",
			"road_cell_count_delta",
			"category_count_gap",
			"road_topology_gap",
			"semantic_layout_gap",
		]
	var missing_codes := []
	for code in required_codes:
		if not observed_codes.has(String(code)):
			missing_codes.append(code)
	return {
		"schema_id": "native_random_map_homm3_owner_corpus_mapped_comparison_gate_self_check_v1",
		"status": "pass" if String(gate.get("status", "")) == "fail" and missing_codes.is_empty() else "fail",
		"synthetic_gate_status": String(gate.get("status", "")),
		"required_codes": required_codes,
		"observed_codes": observed_codes.keys(),
		"missing_codes": missing_codes,
	}

func _owner_large_land_density_diagnostic(service: Variant, samples: Array) -> Dictionary:
	var owner_sample := _large_land_owner_sample(samples)
	if owner_sample.is_empty():
		return {
			"schema_id": "native_random_map_homm3_owner_large_land_density_diagnostic_v1",
			"status": "no_matching_owner_sample",
			"expected_sample": "parsed owner Large land surface H3M, preferring owner_discovered_l_nowater_randomplayers_nounder",
			"comparison_policy": "diagnostic_only_not_exact_parity_gate",
		}
	var config := ScenarioSelectRulesScript.build_random_map_player_config(
		"production-parity-audit-large-10184",
		"",
		"",
		4,
		"land",
		false,
		"homm3_large",
		ScenarioSelectRulesScript.RANDOM_MAP_TEMPLATE_SELECTION_MODE_CATALOG_AUTO
	)
	var generated: Dictionary = service.generate_random_map(config, {"startup_path": "owner_large_land_density_diagnostic"})
	var normalized: Dictionary = generated.get("normalized_config", {}) if generated.get("normalized_config", {}) is Dictionary else {}
	if not bool(generated.get("ok", false)):
		return {
			"schema_id": "native_random_map_homm3_owner_large_land_density_diagnostic_v1",
			"status": "native_generation_failed",
			"owner_sample_id": String(owner_sample.get("id", "")),
			"template_id": String(normalized.get("template_id", "")),
			"profile_id": String(normalized.get("profile_id", "")),
			"full_generation_status": String(generated.get("full_generation_status", "")),
			"validation_status": String(generated.get("validation_status", "")),
			"error": generated.get("validation_report", generated),
			"comparison_policy": "diagnostic_only_not_exact_parity_gate",
		}
	var adoption: Dictionary = service.convert_generated_payload(generated, {
		"feature_gate": "native_rmg_owner_large_land_density_diagnostic",
		"session_save_version": 9,
		"scenario_id": "native_rmg_owner_large_land_density_diagnostic",
	})
	if not bool(adoption.get("ok", false)):
		return {
			"schema_id": "native_random_map_homm3_owner_large_land_density_diagnostic_v1",
			"status": "native_package_conversion_failed",
			"owner_sample_id": String(owner_sample.get("id", "")),
			"template_id": String(normalized.get("template_id", "")),
			"profile_id": String(normalized.get("profile_id", "")),
			"full_generation_status": String(generated.get("full_generation_status", "")),
			"validation_status": String(generated.get("validation_status", "")),
			"generation_validation_report": generated.get("validation_report", {}),
			"error": adoption,
			"comparison_policy": "diagnostic_only_not_exact_parity_gate",
		}
	var map_document: Variant = adoption.get("map_document", null)
	if map_document == null:
		return {
			"schema_id": "native_random_map_homm3_owner_large_land_density_diagnostic_v1",
			"status": "native_package_conversion_failed",
			"reason": "missing_map_document",
			"owner_sample_id": String(owner_sample.get("id", "")),
			"template_id": String(normalized.get("template_id", "")),
			"profile_id": String(normalized.get("profile_id", "")),
			"comparison_policy": "diagnostic_only_not_exact_parity_gate",
		}
	var native := _native_package_metrics(map_document)
	var owner_counts: Dictionary = owner_sample.get("counts_by_category", {}) if owner_sample.get("counts_by_category", {}) is Dictionary else {}
	var native_counts: Dictionary = native.get("counts_by_owner_category", {}) if native.get("counts_by_owner_category", {}) is Dictionary else {}
	var owner_object_count := int(owner_sample.get("object_count", 0))
	var native_object_count := int(native.get("object_count", 0))
	var owner_guard_count := int(owner_counts.get("guard", 0))
	var native_guard_count := int(native.get("guard_count", 0))
	var owner_town_count := int(owner_counts.get("town", 0))
	var native_town_count := int(native.get("town_count", 0))
	var owner_road_count := int(owner_sample.get("road_cell_count_total", 0))
	var native_road_count := int(native.get("road_cell_count_total", 0))
	var category_density := _category_density_comparison(owner_counts, native_counts)
	var semantic_comparison := _semantic_layout_comparison(
		owner_sample.get("semantic_layout", {}) if owner_sample.get("semantic_layout", {}) is Dictionary else {},
		native.get("semantic_layout", {}) if native.get("semantic_layout", {}) is Dictionary else {}
	)
	var density_ratios := {
		"object_count_ratio": _count_ratio(native_object_count, owner_object_count),
		"guard_count_ratio": _count_ratio(native_guard_count, owner_guard_count),
		"town_count_ratio": _count_ratio(native_town_count, owner_town_count),
		"road_cell_count_ratio": _count_ratio(native_road_count, owner_road_count),
	}
	var actionable_gaps := _land_density_actionable_gaps("large", density_ratios, category_density, semantic_comparison)
	return {
		"schema_id": "native_random_map_homm3_owner_large_land_density_diagnostic_v1",
		"status": "diagnosed",
		"comparison_policy": "diagnostic_only_not_exact_parity_gate",
		"scope_boundary": "The owner Large no-water sample has a strict tail-count parser warning and may come from a different HoMM3 template/player-count setup than the native Large default; use this to target density and guard/obstacle work, not as exact parity proof.",
		"owner_sample_id": String(owner_sample.get("id", "")),
		"owner_sample_path": String(owner_sample.get("path", "")),
		"owner_parse_quality": String(owner_sample.get("object_instance_parse_quality", "")),
		"owner_parse_warning": String(owner_sample.get("object_instance_parse_warning", "")),
		"owner_declared_object_count": int(owner_sample.get("declared_object_count", owner_object_count)),
		"owner_parsed_object_count": int(owner_sample.get("parsed_object_count", owner_object_count)),
		"owner_missing_object_instance_count": int(owner_sample.get("object_instance_missing_count", 0)),
		"template_id": String(normalized.get("template_id", "")),
		"profile_id": String(normalized.get("profile_id", "")),
		"size_class_id": String(normalized.get("size_class_id", "")),
		"water_mode": String(normalized.get("water_mode", "")),
		"level_count": int(normalized.get("level_count", 0)),
		"player_count": int((normalized.get("player_constraints", {}) as Dictionary).get("player_count", 0)) if normalized.get("player_constraints", {}) is Dictionary else 0,
		"full_generation_status": String(generated.get("full_generation_status", "")),
		"validation_status": String(generated.get("validation_status", "")),
		"owner": {
			"object_count": owner_object_count,
			"town_count": owner_town_count,
			"guard_count": owner_guard_count,
			"road_cell_count_total": owner_road_count,
			"counts_by_category": owner_counts,
		},
		"native": {
			"package_object_count": native_object_count,
			"generated_object_count": (generated.get("object_placements", []) as Array).size() if generated.get("object_placements", []) is Array else 0,
			"town_count": native_town_count,
			"guard_count": native_guard_count,
			"road_cell_count_total": native_road_count,
			"counts_by_kind": native.get("counts_by_kind", {}),
			"counts_by_owner_category": native_counts,
		},
		"deltas_vs_owner": {
			"object_count_delta": native_object_count - owner_object_count,
			"town_count_delta": native_town_count - owner_town_count,
			"guard_count_delta": native_guard_count - owner_guard_count,
			"road_cell_count_delta": native_road_count - owner_road_count,
		},
		"density_ratios": density_ratios,
		"category_density_comparison": category_density,
		"semantic_layout_comparison": semantic_comparison,
		"actionable_gap_count": actionable_gaps.size(),
		"actionable_gaps": actionable_gaps,
	}

func _native_comparison_for_sample(service: Variant, sample: Dictionary) -> Dictionary:
	var sample_id := String(sample.get("id", ""))
	var config := {}
	if sample_id == "owner_small_land_single_level":
		config = ScenarioSelectRulesScript.build_random_map_player_config(
			"uploaded-small-comparison-10184",
			"",
			"",
			3,
			"land",
			false,
			"homm3_small",
			ScenarioSelectRulesScript.RANDOM_MAP_TEMPLATE_SELECTION_MODE_CATALOG_AUTO
		)
	elif sample_id == "owner_small_with_underground":
		config = ScenarioSelectRulesScript.build_random_map_player_config(
			"owner-corpus-small-underground-10184",
			"",
			"",
			3,
			"land",
			true,
			"homm3_small",
			ScenarioSelectRulesScript.RANDOM_MAP_TEMPLATE_SELECTION_MODE_CATALOG_AUTO
		)
	elif sample_id == "owner_medium_islands":
		config = ScenarioSelectRulesScript.build_random_map_player_config(
			"1777897383",
			"translated_rmg_template_001_v1",
			"translated_rmg_profile_001_v1",
			4,
			"islands",
			false,
			"homm3_medium"
		)
	elif sample_id == "owner_discovered_m_normalw_4players":
		config = ScenarioSelectRulesScript.build_random_map_player_config(
			"auto-template-batch-medium-normal-water-a-10184",
			"",
			"",
			4,
			"normal_water",
			false,
			"homm3_medium",
			ScenarioSelectRulesScript.RANDOM_MAP_TEMPLATE_SELECTION_MODE_CATALOG_AUTO
		)
	elif sample_id == "owner_discovered_l_nowater_randomplayers_nounder":
		config = ScenarioSelectRulesScript.build_random_map_player_config(
			"production-parity-audit-large-10184",
			"",
			"",
			4,
			"land",
			false,
			"homm3_large",
			ScenarioSelectRulesScript.RANDOM_MAP_TEMPLATE_SELECTION_MODE_CATALOG_AUTO
		)
	else:
		return {"status": "not_compared", "reason": "no_native_case_mapping"}
	var generated: Dictionary = service.generate_random_map(config, {"startup_path": "owner_corpus_native_compare_%s" % sample_id})
	var normalized: Dictionary = generated.get("normalized_config", {}) if generated.get("normalized_config", {}) is Dictionary else {}
	if not bool(generated.get("ok", false)):
		return {
			"status": "native_generation_failed",
			"template_id": String(normalized.get("template_id", "")),
			"profile_id": String(normalized.get("profile_id", "")),
			"full_generation_status": String(generated.get("full_generation_status", "")),
			"validation_status": String(generated.get("validation_status", "")),
			"error": generated.get("validation_report", generated),
		}
	var generation_status := String(generated.get("full_generation_status", ""))
	if generation_status == "not_implemented":
		return {
			"status": "native_not_implemented",
			"template_id": String(normalized.get("template_id", "")),
			"profile_id": String(normalized.get("profile_id", "")),
			"size_class_id": String(normalized.get("size_class_id", "")),
			"water_mode": String(normalized.get("water_mode", "")),
			"level_count": int(normalized.get("level_count", 0)),
			"full_generation_status": generation_status,
			"validation_status": String(generated.get("validation_status", "")),
		}
	var adoption: Dictionary = service.convert_generated_payload(generated, {
		"feature_gate": "native_rmg_owner_corpus_native_comparison_report",
		"session_save_version": 9,
		"scenario_id": "native_rmg_owner_corpus_compare_%s" % sample_id,
	})
	if not bool(adoption.get("ok", false)):
		return {
			"status": "native_package_conversion_failed",
			"template_id": String(normalized.get("template_id", "")),
			"profile_id": String(normalized.get("profile_id", "")),
			"full_generation_status": generation_status,
			"validation_status": String(generated.get("validation_status", "")),
			"generation_validation_report": generated.get("validation_report", {}),
			"error": adoption,
		}
	var map_document: Variant = adoption.get("map_document", null)
	if map_document == null:
		return {
			"status": "native_package_conversion_failed",
			"reason": "missing_map_document",
			"template_id": String(normalized.get("template_id", "")),
			"profile_id": String(normalized.get("profile_id", "")),
			"full_generation_status": generation_status,
		}
	var native := _native_package_metrics(map_document)
	var owner_guard_count := int((sample.get("counts_by_category", {}) as Dictionary).get("guard", 0)) if sample.get("counts_by_category", {}) is Dictionary else 0
	var owner_town_count := int((sample.get("counts_by_category", {}) as Dictionary).get("town", 0)) if sample.get("counts_by_category", {}) is Dictionary else 0
	var owner_road_sizes_by_level: Dictionary = sample.get("road_component_sizes_by_level", {}) if sample.get("road_component_sizes_by_level", {}) is Dictionary else {}
	var native_road_sizes_by_level: Dictionary = native.get("road_component_sizes_by_level", {}) if native.get("road_component_sizes_by_level", {}) is Dictionary else {}
	var owner_road_sizes: Array = owner_road_sizes_by_level.get("0", []) if owner_road_sizes_by_level.get("0", []) is Array else []
	var native_road_sizes: Array = native_road_sizes_by_level.get("0", []) if native_road_sizes_by_level.get("0", []) is Array else []
	var category_comparison := _category_count_comparison(
		sample.get("counts_by_category", {}) if sample.get("counts_by_category", {}) is Dictionary else {},
		native.get("counts_by_owner_category", {}) if native.get("counts_by_owner_category", {}) is Dictionary else {}
	)
	var deltas := {
		"object_count_delta": int(native.get("object_count", 0)) - int(sample.get("object_count", 0)),
		"town_count_delta": int(native.get("town_count", 0)) - owner_town_count,
		"guard_count_delta": int(native.get("guard_count", 0)) - owner_guard_count,
		"road_cell_count_delta": int(native.get("road_cell_count_total", 0)) - int(sample.get("road_cell_count_total", 0)),
	}
	var road_topology := _road_topology_comparison(owner_road_sizes, native_road_sizes)
	var road_topology_by_level := _road_topology_comparison_by_level(owner_road_sizes_by_level, native_road_sizes_by_level)
	var semantic_layout := _semantic_layout_comparison(
		sample.get("semantic_layout", {}) if sample.get("semantic_layout", {}) is Dictionary else {},
		native.get("semantic_layout", {}) if native.get("semantic_layout", {}) is Dictionary else {}
	)
	return {
		"status": "compared",
		"template_id": String(normalized.get("template_id", "")),
		"profile_id": String(normalized.get("profile_id", "")),
		"size_class_id": String(normalized.get("size_class_id", "")),
		"water_mode": String(normalized.get("water_mode", "")),
		"level_count": int(normalized.get("level_count", 0)),
		"full_generation_status": generation_status,
		"validation_status": String(generated.get("validation_status", "")),
		"native": native,
		"deltas_vs_owner": deltas,
		"category_count_comparison": category_comparison,
		"road_topology_comparison": road_topology,
		"road_topology_comparison_by_level": road_topology_by_level,
		"semantic_layout_comparison": semantic_layout,
	}

func _owner_xl_land_density_diagnostic(service: Variant, samples: Array) -> Dictionary:
	var owner_sample := _xl_land_owner_sample(samples)
	if owner_sample.is_empty():
		return {
			"schema_id": "native_random_map_homm3_owner_xl_land_density_diagnostic_v1",
			"status": "no_matching_owner_sample",
			"expected_sample": "parsed owner Extra Large land surface H3M, preferring owner_discovered_xl_nowater",
			"comparison_policy": "diagnostic_only_not_exact_parity_gate",
		}
	var config := ScenarioSelectRulesScript.build_random_map_player_config(
		"production-parity-audit-xl-10184",
		"",
		"",
		5,
		"land",
		false,
		"homm3_extra_large",
		ScenarioSelectRulesScript.RANDOM_MAP_TEMPLATE_SELECTION_MODE_CATALOG_AUTO
	)
	var generated: Dictionary = service.generate_random_map(config, {"startup_path": "owner_xl_land_density_diagnostic"})
	var normalized: Dictionary = generated.get("normalized_config", {}) if generated.get("normalized_config", {}) is Dictionary else {}
	if not bool(generated.get("ok", false)):
		return {
			"schema_id": "native_random_map_homm3_owner_xl_land_density_diagnostic_v1",
			"status": "native_generation_failed",
			"owner_sample_id": String(owner_sample.get("id", "")),
			"template_id": String(normalized.get("template_id", "")),
			"profile_id": String(normalized.get("profile_id", "")),
			"full_generation_status": String(generated.get("full_generation_status", "")),
			"validation_status": String(generated.get("validation_status", "")),
			"error": generated.get("validation_report", generated),
			"comparison_policy": "diagnostic_only_not_exact_parity_gate",
		}
	var adoption: Dictionary = service.convert_generated_payload(generated, {
		"feature_gate": "native_rmg_owner_xl_land_density_diagnostic",
		"session_save_version": 9,
		"scenario_id": "native_rmg_owner_xl_land_density_diagnostic",
	})
	if not bool(adoption.get("ok", false)):
		return {
			"schema_id": "native_random_map_homm3_owner_xl_land_density_diagnostic_v1",
			"status": "native_package_conversion_failed",
			"owner_sample_id": String(owner_sample.get("id", "")),
			"template_id": String(normalized.get("template_id", "")),
			"profile_id": String(normalized.get("profile_id", "")),
			"full_generation_status": String(generated.get("full_generation_status", "")),
			"validation_status": String(generated.get("validation_status", "")),
			"generation_validation_report": generated.get("validation_report", {}),
			"error": adoption,
			"comparison_policy": "diagnostic_only_not_exact_parity_gate",
		}
	var map_document: Variant = adoption.get("map_document", null)
	if map_document == null:
		return {
			"schema_id": "native_random_map_homm3_owner_xl_land_density_diagnostic_v1",
			"status": "native_package_conversion_failed",
			"reason": "missing_map_document",
			"owner_sample_id": String(owner_sample.get("id", "")),
			"template_id": String(normalized.get("template_id", "")),
			"profile_id": String(normalized.get("profile_id", "")),
			"comparison_policy": "diagnostic_only_not_exact_parity_gate",
		}
	var native := _native_package_metrics(map_document)
	var owner_counts: Dictionary = owner_sample.get("counts_by_category", {}) if owner_sample.get("counts_by_category", {}) is Dictionary else {}
	var native_counts: Dictionary = native.get("counts_by_owner_category", {}) if native.get("counts_by_owner_category", {}) is Dictionary else {}
	var owner_object_count := int(owner_sample.get("object_count", 0))
	var native_object_count := int(native.get("object_count", 0))
	var owner_guard_count := int(owner_counts.get("guard", 0))
	var native_guard_count := int(native.get("guard_count", 0))
	var owner_town_count := int(owner_counts.get("town", 0))
	var native_town_count := int(native.get("town_count", 0))
	var owner_road_count := int(owner_sample.get("road_cell_count_total", 0))
	var native_road_count := int(native.get("road_cell_count_total", 0))
	var category_density := _category_density_comparison(owner_counts, native_counts)
	var semantic_comparison := _semantic_layout_comparison(
		owner_sample.get("semantic_layout", {}) if owner_sample.get("semantic_layout", {}) is Dictionary else {},
		native.get("semantic_layout", {}) if native.get("semantic_layout", {}) is Dictionary else {}
	)
	var density_ratios := {
		"object_count_ratio": _count_ratio(native_object_count, owner_object_count),
		"guard_count_ratio": _count_ratio(native_guard_count, owner_guard_count),
		"town_count_ratio": _count_ratio(native_town_count, owner_town_count),
		"road_cell_count_ratio": _count_ratio(native_road_count, owner_road_count),
	}
	var actionable_gaps := _land_density_actionable_gaps("xl", density_ratios, category_density, semantic_comparison)
	return {
		"schema_id": "native_random_map_homm3_owner_xl_land_density_diagnostic_v1",
		"status": "diagnosed",
		"comparison_policy": "diagnostic_only_not_exact_parity_gate",
		"scope_boundary": "The owner XL no-water sample may come from a different HoMM3 template/player-count setup than the native Extra Large default; use this to target density and guard/obstacle work, not as exact parity proof.",
		"owner_sample_id": String(owner_sample.get("id", "")),
		"owner_sample_path": String(owner_sample.get("path", "")),
		"template_id": String(normalized.get("template_id", "")),
		"profile_id": String(normalized.get("profile_id", "")),
		"size_class_id": String(normalized.get("size_class_id", "")),
		"water_mode": String(normalized.get("water_mode", "")),
		"level_count": int(normalized.get("level_count", 0)),
		"player_count": int((normalized.get("player_constraints", {}) as Dictionary).get("player_count", 0)) if normalized.get("player_constraints", {}) is Dictionary else 0,
		"full_generation_status": String(generated.get("full_generation_status", "")),
		"validation_status": String(generated.get("validation_status", "")),
		"owner": {
			"object_count": owner_object_count,
			"town_count": owner_town_count,
			"guard_count": owner_guard_count,
			"road_cell_count_total": owner_road_count,
			"counts_by_category": owner_counts,
		},
		"native": {
			"package_object_count": native_object_count,
			"generated_object_count": (generated.get("object_placements", []) as Array).size() if generated.get("object_placements", []) is Array else 0,
			"town_count": native_town_count,
			"guard_count": native_guard_count,
			"road_cell_count_total": native_road_count,
			"counts_by_kind": native.get("counts_by_kind", {}),
			"counts_by_owner_category": native_counts,
		},
		"deltas_vs_owner": {
			"object_count_delta": native_object_count - owner_object_count,
			"town_count_delta": native_town_count - owner_town_count,
			"guard_count_delta": native_guard_count - owner_guard_count,
			"road_cell_count_delta": native_road_count - owner_road_count,
		},
		"density_ratios": density_ratios,
		"category_density_comparison": category_density,
		"semantic_layout_comparison": semantic_comparison,
		"actionable_gap_count": actionable_gaps.size(),
		"actionable_gaps": actionable_gaps,
	}

func _xl_land_owner_sample(samples: Array) -> Dictionary:
	var fallback := {}
	for sample_value in samples:
		if not (sample_value is Dictionary):
			continue
		var sample: Dictionary = sample_value
		if not bool(sample.get("readable", false)) or String(sample.get("metric_parse_status", "")) != "parsed":
			continue
		if String(sample.get("size_class_id", "")) != "homm3_extra_large":
			continue
		if String(sample.get("expected_water_mode", "")) != "land":
			continue
		if int(sample.get("level_count", 0)) != 1:
			continue
		if String(sample.get("id", "")) == "owner_discovered_xl_nowater":
			return sample
		if fallback.is_empty() or int(sample.get("object_count", 0)) > int(fallback.get("object_count", 0)):
			fallback = sample
	return fallback

func _large_land_owner_sample(samples: Array) -> Dictionary:
	var fallback := {}
	for sample_value in samples:
		if not (sample_value is Dictionary):
			continue
		var sample: Dictionary = sample_value
		if not bool(sample.get("readable", false)) or String(sample.get("metric_parse_status", "")) != "parsed":
			continue
		if String(sample.get("size_class_id", "")) != "homm3_large":
			continue
		if String(sample.get("expected_water_mode", "")) != "land":
			continue
		if int(sample.get("level_count", 0)) != 1:
			continue
		if String(sample.get("id", "")) == "owner_discovered_l_nowater_randomplayers_nounder":
			return sample
		if fallback.is_empty() or int(sample.get("object_count", 0)) > int(fallback.get("object_count", 0)):
			fallback = sample
	return fallback

func _category_density_comparison(owner_counts: Dictionary, native_counts: Dictionary) -> Dictionary:
	var category_comparison := _category_count_comparison(owner_counts, native_counts)
	var by_category: Dictionary = category_comparison.get("by_category", {}) if category_comparison.get("by_category", {}) is Dictionary else {}
	for category_value in by_category.keys():
		var category := String(category_value)
		var record: Dictionary = by_category.get(category, {}) if by_category.get(category, {}) is Dictionary else {}
		record["native_to_owner_ratio"] = _count_ratio(int(record.get("native_count", 0)), int(record.get("owner_count", 0)))
		by_category[category] = record
	category_comparison["by_category"] = by_category
	return category_comparison

func _land_density_actionable_gaps(size_label: String, density_ratios: Dictionary, category_density: Dictionary, semantic_comparison: Dictionary) -> Array:
	var gaps := []
	if float(density_ratios.get("object_count_ratio", 1.0)) < 0.75:
		gaps.append("native_%s_package_object_density_below_owner_floor" % size_label)
	if float(density_ratios.get("guard_count_ratio", 1.0)) < 0.75:
		gaps.append("native_%s_guard_density_below_owner_floor" % size_label)
	if float(density_ratios.get("road_cell_count_ratio", 1.0)) < 0.75:
		gaps.append("native_%s_road_density_below_owner_floor" % size_label)
	var by_category: Dictionary = category_density.get("by_category", {}) if category_density.get("by_category", {}) is Dictionary else {}
	for category_value in ["decoration", "object", "reward"]:
		var category := String(category_value)
		var record: Dictionary = by_category.get(category, {}) if by_category.get(category, {}) is Dictionary else {}
		if int(record.get("owner_count", 0)) > 0 and float(record.get("native_to_owner_ratio", 1.0)) < 0.75:
			gaps.append("native_%s_%s_density_below_owner_floor" % [size_label, category])
	var semantic_status := String(semantic_comparison.get("status", ""))
	if semantic_status != "semantic_layout_match":
		gaps.append("native_%s_semantic_layout_gap" % size_label)
	return gaps

func _count_ratio(native_count: int, owner_count: int) -> float:
	if owner_count <= 0:
		return 1.0 if native_count <= 0 else 999.0
	return float(native_count) / float(owner_count)

func _category_count_comparison(owner_counts: Dictionary, native_counts: Dictionary) -> Dictionary:
	var category_lookup := {}
	for category in owner_counts.keys():
		category_lookup[String(category)] = true
	for category in native_counts.keys():
		category_lookup[String(category)] = true
	var categories := category_lookup.keys()
	categories.sort()
	var by_category := {}
	var absolute_delta_total := 0
	for category_value in categories:
		var category := String(category_value)
		var owner_count := int(owner_counts.get(category, 0))
		var native_count := int(native_counts.get(category, 0))
		var delta := native_count - owner_count
		absolute_delta_total += absi(delta)
		by_category[category] = {
			"owner_count": owner_count,
			"native_count": native_count,
			"delta": delta,
		}
	return {
		"categories": categories,
		"by_category": by_category,
		"absolute_delta_total": absolute_delta_total,
		"status": "category_counts_match" if absolute_delta_total == 0 else "category_count_gap",
	}

func _road_topology_comparison_by_level(owner_by_level: Dictionary, native_by_level: Dictionary) -> Dictionary:
	var level_lookup := {}
	for level_key in owner_by_level.keys():
		level_lookup[String(level_key)] = true
	for level_key in native_by_level.keys():
		level_lookup[String(level_key)] = true
	var levels := level_lookup.keys()
	levels.sort()
	var by_level := {}
	var gap_levels := []
	var component_size_abs_delta_total := 0
	var component_count_abs_delta_total := 0
	for level_key_value in levels:
		var level_key := String(level_key_value)
		var owner_sizes: Array = owner_by_level.get(level_key, []) if owner_by_level.get(level_key, []) is Array else []
		var native_sizes: Array = native_by_level.get(level_key, []) if native_by_level.get(level_key, []) is Array else []
		var comparison := _road_topology_comparison(owner_sizes, native_sizes)
		by_level[level_key] = comparison
		component_size_abs_delta_total += int(comparison.get("component_size_abs_delta", 0))
		component_count_abs_delta_total += absi(int(comparison.get("native_component_count", 0)) - int(comparison.get("owner_component_count", 0)))
		if String(comparison.get("status", "")) != "component_count_and_non_tiny_fragments_match" or int(comparison.get("component_size_abs_delta", 0)) != 0:
			gap_levels.append(level_key)
	return {
		"levels": levels,
		"by_level": by_level,
		"gap_levels": gap_levels,
		"component_size_abs_delta_total": component_size_abs_delta_total,
		"component_count_abs_delta_total": component_count_abs_delta_total,
		"status": "all_level_component_sizes_match" if gap_levels.is_empty() else "level_topology_gap",
	}

func _road_topology_comparison(owner_sizes: Array, native_sizes: Array) -> Dictionary:
	var owner_min := _min_int_array(owner_sizes)
	var native_min := _min_int_array(native_sizes)
	var size_abs_delta := 0
	var compare_count := maxi(owner_sizes.size(), native_sizes.size())
	for index in range(compare_count):
		var owner_size := int(owner_sizes[index]) if index < owner_sizes.size() else 0
		var native_size := int(native_sizes[index]) if index < native_sizes.size() else 0
		size_abs_delta += absi(native_size - owner_size)
	return {
		"owner_component_count": owner_sizes.size(),
		"native_component_count": native_sizes.size(),
		"owner_min_component_size": owner_min,
		"native_min_component_size": native_min,
		"component_size_abs_delta": size_abs_delta,
		"status": "component_count_and_non_tiny_fragments_match" if native_sizes.size() == owner_sizes.size() and native_min >= mini(owner_min, 12) else "component_topology_gap",
	}

func _min_int_array(values: Array) -> int:
	if values.is_empty():
		return 0
	var result := 2147483647
	for value in values:
		result = mini(result, int(value))
	return result

func _native_package_metrics(map_document: Variant) -> Dictionary:
	var counts := {}
	for index in range(int(map_document.get_object_count())):
		var object: Dictionary = map_document.get_object_by_index(index)
		var kind := String(object.get("kind", object.get("native_record_kind", object.get("category_id", "object"))))
		counts[kind] = int(counts.get(kind, 0)) + 1
	var counts_by_owner_category := _native_counts_by_owner_category(counts)
	var terrain_layers: Dictionary = map_document.get_terrain_layers()
	var roads: Array = terrain_layers.get("roads", []) if terrain_layers.get("roads", []) is Array else []
	var road_cell_count_by_level := {}
	var road_component_sizes_by_level := {}
	var road_total := 0
	for road in roads:
		if not (road is Dictionary):
			continue
		var road_tiles: Array = road.get("tiles", road.get("cells", [])) if road.get("tiles", road.get("cells", [])) is Array else []
		var level_lookup_by_level := {}
		for tile_value in road_tiles:
			if not (tile_value is Dictionary):
				continue
			var tile: Dictionary = tile_value
			var level_key := str(int(tile.get("level", 0)))
			var lookup: Dictionary = level_lookup_by_level.get(level_key, {}) if level_lookup_by_level.get(level_key, {}) is Dictionary else {}
			lookup[_point_key(int(tile.get("x", 0)), int(tile.get("y", 0)))] = true
			level_lookup_by_level[level_key] = lookup
		for level_key in level_lookup_by_level.keys():
			var level_lookup: Dictionary = level_lookup_by_level[level_key]
			var aggregate: Dictionary = road_component_sizes_by_level.get(level_key, {}) if road_component_sizes_by_level.get(level_key, {}) is Dictionary else {}
			for key in level_lookup.keys():
				aggregate[String(key)] = true
			road_component_sizes_by_level[level_key] = aggregate
	for level_key in road_component_sizes_by_level.keys():
		var lookup: Dictionary = road_component_sizes_by_level[level_key]
		var sizes := _lookup_component_sizes(lookup, int(map_document.get_width()))
		road_cell_count_by_level[level_key] = lookup.size()
		road_component_sizes_by_level[level_key] = sizes
		road_total += lookup.size()
	return {
		"width": int(map_document.get_width()),
		"height": int(map_document.get_height()),
		"level_count": int(map_document.get_level_count()),
		"object_count": int(map_document.get_object_count()),
		"counts_by_kind": counts,
		"counts_by_owner_category": counts_by_owner_category,
		"town_count": int(counts.get("town", 0)),
		"guard_count": int(counts.get("guard", 0)),
			"road_cell_count_by_level": road_cell_count_by_level,
			"road_cell_count_total": road_total,
			"road_component_sizes_by_level": road_component_sizes_by_level,
			"semantic_layout": _native_semantic_layout_metrics(map_document),
		}

func _native_counts_by_owner_category(counts_by_kind: Dictionary) -> Dictionary:
	return {
		"decoration": int(counts_by_kind.get("decorative_obstacle", 0)),
		"guard": int(counts_by_kind.get("guard", 0)),
		"object": int(counts_by_kind.get("scenic_object", 0)),
		"reward": int(counts_by_kind.get("mine", 0))
			+ int(counts_by_kind.get("neutral_dwelling", 0))
			+ int(counts_by_kind.get("resource_site", 0))
			+ int(counts_by_kind.get("reward_reference", 0)),
		"town": int(counts_by_kind.get("town", 0)),
	}

func _semantic_layout_comparison(owner_layout: Dictionary, native_layout: Dictionary) -> Dictionary:
	var failure_codes := []
	var owner_nearest := int(owner_layout.get("nearest_town_manhattan_min", 0))
	var native_nearest := int(native_layout.get("nearest_town_manhattan_min", 0))
	var nearest_floor: int = maxi(0, owner_nearest - 3) if owner_nearest > 0 else 0
	if nearest_floor > 0 and native_nearest < nearest_floor:
		failure_codes.append("native_town_spacing_below_owner_floor")
	var owner_object_pairs := int(owner_layout.get("object_route_reachable_pair_count_total", 0))
	var native_object_pairs := int(native_layout.get("object_route_reachable_pair_count_total", 0))
	if native_object_pairs > owner_object_pairs:
		failure_codes.append("native_object_route_leak")
	var owner_guarded_pairs := int(owner_layout.get("guarded_route_reachable_pair_count_total", 0))
	var native_guarded_pairs := int(native_layout.get("guarded_route_reachable_pair_count_total", 0))
	if native_guarded_pairs > owner_guarded_pairs:
		failure_codes.append("native_guarded_route_leak")
	var owner_guard_tiles := int(owner_layout.get("guard_controlled_tile_count_total", 0))
	var native_guard_tiles := int(native_layout.get("guard_controlled_tile_count_total", 0))
	var guard_ratio := 1.0
	if owner_guard_tiles > 0:
		guard_ratio = float(native_guard_tiles) / float(owner_guard_tiles)
		if guard_ratio < 0.75:
			failure_codes.append("native_guard_footprint_below_owner_floor")
	return {
		"status": "semantic_layout_match" if failure_codes.is_empty() else "semantic_layout_gap",
		"failure_codes": failure_codes,
		"nearest_town_manhattan_floor": nearest_floor,
		"owner_nearest_town_manhattan_min": owner_nearest,
		"native_nearest_town_manhattan_min": native_nearest,
		"nearest_town_manhattan_delta": native_nearest - owner_nearest,
		"owner_object_route_reachable_pair_count_total": owner_object_pairs,
		"native_object_route_reachable_pair_count_total": native_object_pairs,
		"owner_guarded_route_reachable_pair_count_total": owner_guarded_pairs,
		"native_guarded_route_reachable_pair_count_total": native_guarded_pairs,
		"owner_guard_controlled_tile_count_total": owner_guard_tiles,
		"native_guard_controlled_tile_count_total": native_guard_tiles,
		"guard_control_ratio": guard_ratio,
		"owner_by_level": owner_layout.get("by_level", {}),
		"native_by_level": native_layout.get("by_level", {}),
	}

func _h3m_semantic_layout_metrics(records: Array, width: int, level_count: int, bytes: PackedByteArray, tile_offset: int) -> Dictionary:
	var state_by_level := {}
	for level in range(level_count):
		state_by_level[str(level)] = _empty_semantic_level_state()
	for level in range(level_count):
		var state: Dictionary = state_by_level[str(level)]
		for y in range(width):
			for x in range(width):
				var cell_offset := tile_offset + ((level * width * width) + (y * width) + x) * H3M_TILE_BYTES_PER_CELL
				if cell_offset < 0 or cell_offset >= bytes.size():
					continue
				if H3M_BLOCKING_TERRAIN_TYPE_IDS.has(int(bytes[cell_offset])):
					_add_point_to_lookup(state.get("terrain_blocked", {}), {"x": x, "y": y})
	for record_value in records:
		if not (record_value is Dictionary):
			continue
		var record: Dictionary = record_value
		var level_key := str(int(record.get("level", 0)))
		if not state_by_level.has(level_key):
			state_by_level[level_key] = _empty_semantic_level_state()
		var state: Dictionary = state_by_level[level_key]
		var category := _h3m_category_for_record(record)
		for point in _h3m_mask_points(record, false, width, width):
			_add_point_to_lookup(state.get("object_blocked", {}), point)
			_add_point_to_lookup(state.get("guarded_blocked", {}), point)
		if category == "guard":
			for point in _h3m_guard_control_points(record, width, width):
				_add_point_to_lookup(state.get("guard_controlled", {}), point)
				_add_point_to_lookup(state.get("guarded_blocked", {}), point)
		if category == "town":
			var visit_points := _h3m_mask_points(record, true, width, width)
			if visit_points.is_empty():
				visit_points = [{"x": int(record.get("x", 0)), "y": int(record.get("y", 0))}]
			var towns: Array = state.get("towns", []) if state.get("towns", []) is Array else []
			towns.append({
				"id": "owner_town_%s_%02d" % [level_key, towns.size() + 1],
				"x": int(record.get("x", 0)),
				"y": int(record.get("y", 0)),
				"visit_points": visit_points,
			})
			state["towns"] = towns
	return _semantic_layout_summary(state_by_level, width, width)

func _native_semantic_layout_metrics(map_document: Variant) -> Dictionary:
	var state_by_level := {}
	for level in range(int(map_document.get_level_count())):
		state_by_level[str(level)] = _empty_semantic_level_state()
	var terrain_layers: Dictionary = map_document.get_terrain_layers()
	var terrain: Dictionary = terrain_layers.get("terrain", {}) if terrain_layers.get("terrain", {}) is Dictionary else {}
	var levels: Array = terrain.get("levels", []) if terrain.get("levels", []) is Array else []
	var ids_by_code: Variant = terrain_layers.get("terrain_id_by_code", [])
	for level in range(levels.size()):
		var level_key := str(level)
		if not state_by_level.has(level_key):
			state_by_level[level_key] = _empty_semantic_level_state()
		var state: Dictionary = state_by_level[level_key]
		var codes := _native_terrain_codes_for_level(levels[level])
		for y in range(int(map_document.get_height())):
			for x in range(int(map_document.get_width())):
				var index := y * int(map_document.get_width()) + x
				var terrain_id := _terrain_id_for_code(ids_by_code, int(codes[index]) if index < codes.size() else 0)
				if terrain_id in ["rock", "water"]:
					_add_point_to_lookup(state.get("terrain_blocked", {}), {"x": x, "y": y})
	for index in range(int(map_document.get_object_count())):
		var object: Dictionary = map_document.get_object_by_index(index)
		var level_key := str(int(object.get("level", 0)))
		if not state_by_level.has(level_key):
			state_by_level[level_key] = _empty_semantic_level_state()
		var state: Dictionary = state_by_level[level_key]
		var kind := String(object.get("kind", object.get("native_record_kind", object.get("category_id", "object"))))
		var block_tiles: Array = object.get("package_block_tiles", []) if object.get("package_block_tiles", []) is Array else []
		for tile in block_tiles:
			if tile is Dictionary:
				_add_point_to_lookup(state.get("object_blocked", {}), tile)
				_add_point_to_lookup(state.get("guarded_blocked", {}), tile)
				if kind == "guard":
					_add_point_to_lookup(state.get("guard_controlled", {}), tile)
		if kind == "town":
			var visit_points: Array = object.get("package_visit_tiles", []) if object.get("package_visit_tiles", []) is Array else []
			if visit_points.is_empty():
				visit_points = [{"x": int(object.get("x", 0)), "y": int(object.get("y", 0))}]
			var towns: Array = state.get("towns", []) if state.get("towns", []) is Array else []
			towns.append({
				"id": String(object.get("placement_id", "native_town_%02d" % towns.size())),
				"zone_id": String(object.get("zone_id", "")),
				"x": int(object.get("x", 0)),
				"y": int(object.get("y", 0)),
				"visit_points": visit_points,
			})
			state["towns"] = towns
	return _semantic_layout_summary(state_by_level, int(map_document.get_width()), int(map_document.get_height()))

func _empty_semantic_level_state() -> Dictionary:
	return {
		"terrain_blocked": {},
		"object_blocked": {},
		"guarded_blocked": {},
		"guard_controlled": {},
		"towns": [],
	}

func _semantic_layout_summary(state_by_level: Dictionary, width: int, height: int) -> Dictionary:
	var by_level := {}
	var nearest_values := []
	var object_route_total := 0
	var guarded_route_total := 0
	var guard_controlled_total := 0
	for level_key_value in state_by_level.keys():
		var level_key := String(level_key_value)
		var state: Dictionary = state_by_level[level_key]
		var towns: Array = state.get("towns", []) if state.get("towns", []) is Array else []
		var town_points := []
		for town_value in towns:
			if town_value is Dictionary:
				town_points.append(Vector2i(int(town_value.get("x", 0)), int(town_value.get("y", 0))))
		var nearest := _nearest_manhattan(town_points)
		if nearest > 0:
			nearest_values.append(nearest)
		var object_blocked: Dictionary = state.get("object_blocked", {}) if state.get("object_blocked", {}) is Dictionary else {}
		var guarded_blocked: Dictionary = state.get("guarded_blocked", {}) if state.get("guarded_blocked", {}) is Dictionary else {}
		var terrain_blocked: Dictionary = state.get("terrain_blocked", {}) if state.get("terrain_blocked", {}) is Dictionary else {}
		var guard_controlled: Dictionary = state.get("guard_controlled", {}) if state.get("guard_controlled", {}) is Dictionary else {}
		var object_route_blocked := terrain_blocked.duplicate(true)
		for key in object_blocked.keys():
			object_route_blocked[key] = true
		var guarded_route_blocked := terrain_blocked.duplicate(true)
		for key in guarded_blocked.keys():
			guarded_route_blocked[key] = true
		var object_topology := _town_pair_topology(object_route_blocked, width, height, towns)
		var guarded_topology := _town_pair_topology(guarded_route_blocked, width, height, towns)
		object_route_total += int(object_topology.get("reachable_pair_count", 0))
		guarded_route_total += int(guarded_topology.get("reachable_pair_count", 0))
		guard_controlled_total += guard_controlled.size()
		by_level[level_key] = {
			"town_count": towns.size(),
			"nearest_town_manhattan": nearest,
			"terrain_blocked_tile_count": terrain_blocked.size(),
			"object_blocked_tile_count": object_blocked.size(),
			"guarded_blocked_tile_count": guarded_blocked.size(),
			"guard_controlled_tile_count": guard_controlled.size(),
			"object_route_topology": object_topology,
			"guarded_route_topology": guarded_topology,
		}
	return {
		"by_level": by_level,
		"nearest_town_manhattan_min": _min_positive(nearest_values),
		"object_route_reachable_pair_count_total": object_route_total,
		"guarded_route_reachable_pair_count_total": guarded_route_total,
		"guard_controlled_tile_count_total": guard_controlled_total,
	}

func _add_point_to_lookup(lookup: Dictionary, point: Variant) -> void:
	if point is Dictionary:
		lookup[_point_key(int(point.get("x", 0)), int(point.get("y", 0)))] = true

func _h3m_mask_points(record: Dictionary, action_mask: bool, width: int, height: int) -> Array:
	var points := []
	var mask: PackedByteArray = record.get("action_mask", PackedByteArray()) if action_mask else record.get("passability_mask", PackedByteArray())
	if mask.size() < 6:
		return points
	for row in range(6):
		var byte := int(mask[row])
		for col in range(8):
			var bit_set := ((byte >> col) & 1) == 1
			var include := bit_set if action_mask else not bit_set
			if not include:
				continue
			var x := int(record.get("x", 0)) - (7 - col)
			var y := int(record.get("y", 0)) - (5 - row)
			if x >= 0 and y >= 0 and x < width and y < height:
				points.append({"x": x, "y": y})
	return points

func _h3m_guard_control_points(record: Dictionary, width: int, height: int) -> Array:
	var points := []
	var lookup := {}
	var action_points := _h3m_mask_points(record, true, width, height)
	if action_points.is_empty():
		action_points = [{"x": int(record.get("x", 0)), "y": int(record.get("y", 0))}]
	for point in action_points:
		if not (point is Dictionary):
			continue
		var center := Vector2i(int(point.get("x", 0)), int(point.get("y", 0)))
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var candidate := center + Vector2i(dx, dy)
				if candidate.x < 0 or candidate.y < 0 or candidate.x >= width or candidate.y >= height:
					continue
				var key := _point_key(candidate.x, candidate.y)
				if lookup.has(key):
					continue
				lookup[key] = true
				points.append({"x": candidate.x, "y": candidate.y})
	return points

func _native_terrain_codes_for_level(level_record: Variant) -> Array:
	if level_record is Dictionary:
		return Array(level_record.get("terrain_code_u16", []))
	if level_record is PackedInt32Array:
		return Array(level_record)
	if level_record is Array:
		return level_record
	return []

func _terrain_id_for_code(ids_by_code: Variant, code: int) -> String:
	if (ids_by_code is Array or ids_by_code is PackedStringArray) and code >= 0 and code < ids_by_code.size():
		return String(ids_by_code[code])
	return "grass"

func _size_class_for_width(width: int) -> String:
	if width == 36:
		return "homm3_small"
	if width == 72:
		return "homm3_medium"
	if width == 108:
		return "homm3_large"
	if width == 144:
		return "homm3_extra_large"
	return "unknown_%d" % width

func _sample_metrics(bytes: PackedByteArray, width: int, level_count: int) -> Dictionary:
	if width <= 0 or level_count <= 0:
		return {"status": "not_attempted", "error": "invalid_dimensions"}
	var candidate_offsets := _find_object_definition_offsets(bytes)
	if candidate_offsets.is_empty():
		return {"status": "not_attempted", "error": "object_definition_offset_not_found"}
	var first_error := {}
	for offset_value in candidate_offsets:
		var result := _sample_metrics_for_definition_offset(bytes, width, level_count, int(offset_value), candidate_offsets.size())
		if String(result.get("status", "")) == "parsed":
			return result
		if first_error.is_empty():
			first_error = result
	first_error["candidate_object_definition_offset_count"] = candidate_offsets.size()
	return first_error

func _sample_metrics_for_definition_offset(bytes: PackedByteArray, width: int, level_count: int, def_offset: int, candidate_count: int) -> Dictionary:
	var tile_offset := def_offset - width * width * level_count * H3M_TILE_BYTES_PER_CELL
	if tile_offset <= 0:
		return {"status": "not_attempted", "error": "invalid_tile_offset", "object_definition_offset": def_offset, "candidate_object_definition_offset_count": candidate_count}
	var object_metadata := _load_homm3_object_metadata()
	var templates := _parse_h3m_object_templates(bytes, def_offset, object_metadata)
	if String(templates.get("status", "")) != "parsed":
		templates["candidate_object_definition_offset_count"] = candidate_count
		return templates
	var objects := _parse_h3m_object_instances(bytes, int(templates.get("next_offset", 0)), templates.get("templates", []), width, level_count)
	if String(objects.get("status", "")) != "parsed":
		objects["object_definition_offset"] = def_offset
		objects["candidate_object_definition_offset_count"] = candidate_count
		return objects
	var records: Array = objects.get("records", []) if objects.get("records", []) is Array else []
	var counts_by_category := {}
	var counts_by_level := {}
	for record_value in records:
		if not (record_value is Dictionary):
			continue
		var record: Dictionary = record_value
		var category := _h3m_category_for_record(record)
		counts_by_category[category] = int(counts_by_category.get(category, 0)) + 1
		var level_key := str(int(record.get("level", 0)))
		var level_counts: Dictionary = counts_by_level.get(level_key, {}) if counts_by_level.get(level_key, {}) is Dictionary else {}
		level_counts[category] = int(level_counts.get(category, 0)) + 1
		counts_by_level[level_key] = level_counts
	var road_cell_count_by_level := {}
	var road_component_count_by_level := {}
	var road_component_sizes_by_level := {}
	var road_total := 0
	var terrain_summary := _h3m_terrain_summary(bytes, tile_offset, width, level_count)
	for level in range(level_count):
		var road_lookup := _h3m_road_lookup(bytes, tile_offset, width, level)
		var sizes := _lookup_component_sizes(road_lookup, width)
		road_cell_count_by_level[str(level)] = road_lookup.size()
		road_component_count_by_level[str(level)] = sizes.size()
		road_component_sizes_by_level[str(level)] = sizes
		road_total += road_lookup.size()
	return {
		"status": "parsed",
		"object_definition_count": int(templates.get("template_count", 0)),
		"object_definition_offset": def_offset,
		"candidate_object_definition_offset_count": candidate_count,
		"object_count": records.size(),
		"declared_object_count": int(objects.get("declared_object_count", records.size())),
		"parsed_object_count": int(objects.get("parsed_object_count", records.size())),
		"missing_object_instance_count": int(objects.get("missing_object_instance_count", 0)),
		"tail_bytes": int(objects.get("tail_bytes", 0)),
		"parse_quality": String(objects.get("parse_quality", "complete")),
		"parse_warning": String(objects.get("parse_warning", "")),
		"counts_by_category": counts_by_category,
		"counts_by_level": counts_by_level,
		"terrain_summary": terrain_summary,
		"road_cell_count_by_level": road_cell_count_by_level,
		"road_cell_count_total": road_total,
		"road_component_count_by_level": road_component_count_by_level,
		"road_component_sizes_by_level": road_component_sizes_by_level,
		"semantic_layout": _h3m_semantic_layout_metrics(records, width, level_count, bytes, tile_offset),
	}

func _parse_h3m_object_templates(bytes: PackedByteArray, offset: int, object_metadata: Dictionary) -> Dictionary:
	var count := _u32(bytes, offset)
	if count <= 0 or count > 2000:
		return {"status": "not_attempted", "error": "invalid_object_definition_count", "object_definition_offset": offset, "count": count}
	var pos := offset + 4
	var templates := []
	for index in range(count):
		var name_len := _u32(bytes, pos)
		pos += 4
		if name_len <= 0 or name_len > 128 or pos + name_len + OBJECT_TEMPLATE_RECORD_BYTES_AFTER_NAME > bytes.size():
			return {"status": "not_attempted", "error": "invalid_object_definition_name_length", "index": index, "name_length": name_len}
		var def_name := _ascii(bytes, pos, name_len)
		pos += name_len
		var rest_offset := pos
		pos += OBJECT_TEMPLATE_RECORD_BYTES_AFTER_NAME
		var type_id := _u32(bytes, rest_offset + 16)
		templates.append({
			"template_index": index,
			"def_name": def_name,
			"passability_mask": bytes.slice(rest_offset, rest_offset + 6),
			"action_mask": bytes.slice(rest_offset + 6, rest_offset + 12),
			"type_id": type_id,
			"type_name": String(object_metadata.get(str(type_id), "type_%d" % type_id)),
			"subtype": _u32(bytes, rest_offset + 20),
		})
	return {
		"status": "parsed",
		"template_count": count,
		"templates": templates,
		"next_offset": pos,
	}

func _parse_h3m_object_instances(bytes: PackedByteArray, offset: int, templates: Array, width: int, level_count: int) -> Dictionary:
	var count := _u32(bytes, offset)
	if count <= 0 or count > 12000:
		return {"status": "not_attempted", "error": "invalid_object_instance_count", "object_instance_offset": offset, "count": count}
	var pos := offset + 4
	var records := []
	for index in range(count):
		if not _is_h3m_object_instance_start(bytes, pos, templates.size(), width, level_count):
			return {"status": "not_attempted", "error": "object_instance_parse_failed", "index": index, "offset": pos}
		var template_index := _u32(bytes, pos + 3)
		var record: Dictionary = templates[template_index].duplicate(true)
		record["object_index"] = index
		record["x"] = int(bytes[pos])
		record["y"] = int(bytes[pos + 1])
		record["level"] = int(bytes[pos + 2])
		records.append(record)
		var next_min := pos + 12
		if index == count - 1:
			pos = next_min
			break
		var found := -1
		for extra in range(0, 4096):
			var candidate := next_min + extra
			if _is_h3m_object_instance_start(bytes, candidate, templates.size(), width, level_count):
				found = candidate
				break
		if found < 0:
			var missing_count := count - records.size()
			var tail_bytes := bytes.size() - next_min
			if missing_count > 0 \
					and missing_count <= OBJECT_INSTANCE_TAIL_PARSE_MISSING_COUNT_TOLERANCE \
					and tail_bytes >= 0 \
					and tail_bytes <= OBJECT_INSTANCE_TAIL_PARSE_BYTE_TOLERANCE:
				return {
					"status": "parsed",
					"records": records,
					"object_count": records.size(),
					"declared_object_count": count,
					"parsed_object_count": records.size(),
					"missing_object_instance_count": missing_count,
					"next_offset": next_min,
					"tail_bytes": tail_bytes,
					"parse_quality": "tail_count_mismatch",
					"parse_warning": "object_instance_declared_count_exceeds_strict_tail_parse",
				}
			return {"status": "not_attempted", "error": "next_object_instance_not_found", "index": index, "offset": pos}
		pos = found
	return {
		"status": "parsed",
		"records": records,
		"object_count": records.size(),
		"declared_object_count": count,
		"parsed_object_count": records.size(),
		"missing_object_instance_count": 0,
		"next_offset": pos,
		"tail_bytes": bytes.size() - pos,
		"parse_quality": "complete",
		"parse_warning": "",
	}

func _is_h3m_object_instance_start(bytes: PackedByteArray, pos: int, template_count: int, width: int, level_count: int) -> bool:
	if pos < 0 or pos + 12 > bytes.size():
		return false
	var x := int(bytes[pos])
	var y := int(bytes[pos + 1])
	var z := int(bytes[pos + 2])
	var template_index := _u32(bytes, pos + 3)
	if x < 0 or y < 0 or x >= width or y >= width or z < 0 or z >= level_count:
		return false
	if template_index < 0 or template_index >= template_count:
		return false
	for index in range(5):
		if int(bytes[pos + 7 + index]) != 0:
			return false
	return true

func _h3m_category_for_record(record: Dictionary) -> String:
	var type_id := int(record.get("type_id", -1))
	var type_name := String(record.get("type_name", "")).to_lower()
	if DECORATION_TYPE_IDS.has(type_id):
		return "decoration"
	if GUARD_TYPE_IDS.has(type_id) or type_name.contains("monster"):
		return "guard"
	if TOWN_TYPE_IDS.has(type_id):
		return "town"
	if RESOURCE_REWARD_TYPE_IDS.has(type_id) \
			or type_name.contains("resource") \
			or type_name.contains("mine") \
			or type_name.contains("artifact") \
			or type_name.contains("shrine"):
		return "reward"
	return "object"

func _load_homm3_object_metadata() -> Dictionary:
	var text := FileAccess.get_file_as_string(HOMM3_RE_OBJECT_METADATA)
	if text.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return {}
	var result := {}
	var entries: Array = parsed.get("entries", []) if parsed.get("entries", []) is Array else []
	for entry in entries:
		if entry is Dictionary:
			result[str(int(entry.get("type_id", -1)))] = String(entry.get("type_name", ""))
	return result

func _h3m_terrain_summary(bytes: PackedByteArray, tile_offset: int, width: int, level_count: int) -> Dictionary:
	var total_tile_count := width * width * level_count
	var terrain_counts := {}
	var by_level := {}
	var water_tile_count := 0
	var rock_tile_count := 0
	for level in range(level_count):
		var level_counts := {}
		var level_water_count := 0
		var level_rock_count := 0
		var level_tile_count := width * width
		var level_offset := tile_offset + level * width * width * H3M_TILE_BYTES_PER_CELL
		for y in range(width):
			for x in range(width):
				var offset := level_offset + (y * width + x) * H3M_TILE_BYTES_PER_CELL
				if offset < 0 or offset >= bytes.size():
					continue
				var terrain_id := int(bytes[offset])
				var terrain_key := str(terrain_id)
				level_counts[terrain_key] = int(level_counts.get(terrain_key, 0)) + 1
				terrain_counts[terrain_key] = int(terrain_counts.get(terrain_key, 0)) + 1
				if terrain_id == 8:
					level_water_count += 1
					water_tile_count += 1
				elif terrain_id == 9:
					level_rock_count += 1
					rock_tile_count += 1
		by_level[str(level)] = {
			"tile_count": level_tile_count,
			"water_tile_count": level_water_count,
			"rock_tile_count": level_rock_count,
			"water_ratio": _safe_ratio(level_water_count, level_tile_count),
			"rock_ratio": _safe_ratio(level_rock_count, level_tile_count),
			"terrain_counts": level_counts,
		}
	var surface: Dictionary = by_level.get("0", {}) if by_level.get("0", {}) is Dictionary else {}
	var surface_water_ratio := float(surface.get("water_ratio", _safe_ratio(water_tile_count, total_tile_count)))
	return {
		"schema_id": "native_random_map_h3m_terrain_summary_v1",
		"tile_count": total_tile_count,
		"water_tile_count": water_tile_count,
		"rock_tile_count": rock_tile_count,
		"water_ratio": _safe_ratio(water_tile_count, total_tile_count),
		"rock_ratio": _safe_ratio(rock_tile_count, total_tile_count),
		"surface_water_ratio": surface_water_ratio,
		"inferred_water_mode": _inferred_water_mode_from_surface_ratio(surface_water_ratio),
		"terrain_counts": terrain_counts,
		"by_level": by_level,
	}

func _inferred_water_mode_from_surface_ratio(surface_water_ratio: float) -> String:
	if surface_water_ratio <= 0.01:
		return "land"
	if surface_water_ratio >= 0.55:
		return "islands"
	return "normal_water"

func _safe_ratio(numerator: int, denominator: int) -> float:
	if denominator <= 0:
		return 0.0
	return float(numerator) / float(denominator)

func _h3m_road_lookup(bytes: PackedByteArray, tile_offset: int, width: int, level: int) -> Dictionary:
	var lookup := {}
	var level_offset := tile_offset + level * width * width * H3M_TILE_BYTES_PER_CELL
	for y in range(width):
		for x in range(width):
			var offset := level_offset + (y * width + x) * H3M_TILE_BYTES_PER_CELL
			if offset + 5 <= bytes.size() and int(bytes[offset + 4]) != 0:
				lookup[_point_key(x, y)] = true
	return lookup

func _lookup_component_sizes(lookup: Dictionary, width: int) -> Array:
	var remaining := {}
	for key in lookup.keys():
		remaining[String(key)] = true
	var component_sizes := []
	var dirs := [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1),
	]
	while not remaining.is_empty():
		var start_key := String(remaining.keys()[0])
		remaining.erase(start_key)
		var queue := [_point_from_key(start_key)]
		var cursor := 0
		while cursor < queue.size():
			var current: Vector2i = queue[cursor]
			cursor += 1
			for dir_value in dirs:
				var next: Vector2i = current + dir_value
				if next.x < 0 or next.y < 0 or next.x >= width or next.y >= width:
					continue
				var key := _point_key(next.x, next.y)
				if not remaining.has(key):
					continue
				remaining.erase(key)
				queue.append(next)
		component_sizes.append(queue.size())
	component_sizes.sort()
	component_sizes.reverse()
	return component_sizes

func _town_pair_topology(blocked: Dictionary, width: int, height: int, towns: Array) -> Dictionary:
	var reachable_pairs := []
	var checked_pair_count := 0
	for left_index in range(towns.size()):
		for right_index in range(left_index + 1, towns.size()):
			var left: Dictionary = towns[left_index]
			var right: Dictionary = towns[right_index]
			checked_pair_count += 1
			var path := _find_any_path(blocked.duplicate(true), width, height, _visit_points(left), _visit_points(right))
			if not path.is_empty():
				reachable_pairs.append({
					"left": _brief_town(left),
					"right": _brief_town(right),
					"path_length": path.size(),
					"path_sample": _path_sample(path),
				})
	return {
		"checked_pair_count": checked_pair_count,
		"reachable_pair_count": reachable_pairs.size(),
		"reachable_pairs": reachable_pairs.slice(0, 8),
	}

func _visit_points(town: Dictionary) -> Array:
	var points := []
	var visit_points: Array = town.get("visit_points", []) if town.get("visit_points", []) is Array else []
	for value in visit_points:
		if value is Dictionary:
			points.append(Vector2i(int(value.get("x", 0)), int(value.get("y", 0))))
	return points

func _find_any_path(blocked: Dictionary, width: int, height: int, starts: Array, goals: Array) -> Array:
	var goal_lookup := {}
	for goal in goals:
		if goal is Vector2i:
			goal_lookup[_point_key(goal.x, goal.y)] = true
			blocked.erase(_point_key(goal.x, goal.y))
	var queue := []
	var seen := {}
	var previous_by_key := {}
	for start in starts:
		if not (start is Vector2i):
			continue
		blocked.erase(_point_key(start.x, start.y))
		seen[_point_key(start.x, start.y)] = true
		queue.append(start)
	var dirs := [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1),
	]
	var cursor := 0
	while cursor < queue.size():
		var current: Vector2i = queue[cursor]
		cursor += 1
		if goal_lookup.has(_point_key(current.x, current.y)):
			return _reconstruct_path(previous_by_key, current)
		for dir_value in dirs:
			var next: Vector2i = current + dir_value
			var key := _point_key(next.x, next.y)
			if next.x < 0 or next.y < 0 or next.x >= width or next.y >= height or seen.has(key) or blocked.has(key):
				continue
			seen[key] = true
			previous_by_key[key] = current
			queue.append(next)
	return []

func _reconstruct_path(previous_by_key: Dictionary, goal: Vector2i) -> Array:
	var path: Array = [goal]
	var current := goal
	var guard := 0
	while guard < 4096:
		guard += 1
		var current_key := _point_key(current.x, current.y)
		if not previous_by_key.has(current_key):
			break
		current = previous_by_key[current_key]
		path.push_front(current)
	return path

func _path_sample(path: Array) -> Array:
	if path.size() <= 12:
		return _path_points(path)
	var sample := []
	sample.append_array(_path_points(path.slice(0, 6)))
	sample.append({"omitted": path.size() - 12})
	sample.append_array(_path_points(path.slice(path.size() - 6, path.size())))
	return sample

func _path_points(path: Array) -> Array:
	var points := []
	for point in path:
		if point is Vector2i:
			points.append({"x": point.x, "y": point.y})
	return points

func _brief_town(town: Dictionary) -> Dictionary:
	return {
		"id": String(town.get("id", "")),
		"x": int(town.get("x", 0)),
		"y": int(town.get("y", 0)),
	}

func _nearest_manhattan(points: Array) -> int:
	if points.size() < 2:
		return 0
	var best := 999999
	for left_index in range(points.size()):
		var left: Vector2i = points[left_index]
		for right_index in range(left_index + 1, points.size()):
			var right: Vector2i = points[right_index]
			best = mini(best, abs(left.x - right.x) + abs(left.y - right.y))
	return best

func _min_positive(values: Array) -> int:
	var result := 0
	for value in values:
		var number := int(value)
		if number <= 0:
			continue
		if result == 0 or number < result:
			result = number
	return result

func _find_object_definition_offsets(bytes: PackedByteArray) -> Array:
	var result := []
	for offset in range(0, bytes.size() - 32):
		var count := _u32(bytes, offset)
		if count < 10 or count > 2000:
			continue
		var name_len := _u32(bytes, offset + 4)
		if name_len < 4 or name_len > 32:
			continue
		var name := _ascii(bytes, offset + 8, name_len)
		if name.to_lower().ends_with(".def"):
			result.append(offset)
	return result

func _point_key(x: int, y: int) -> String:
	return "%d,%d" % [x, y]

func _point_from_key(key: String) -> Vector2i:
	var parts := key.split(",")
	if parts.size() != 2:
		return Vector2i.ZERO
	return Vector2i(int(parts[0]), int(parts[1]))

func _u32(bytes: PackedByteArray, offset: int) -> int:
	if offset + 4 > bytes.size():
		return 0
	return int(bytes[offset]) | (int(bytes[offset + 1]) << 8) | (int(bytes[offset + 2]) << 16) | (int(bytes[offset + 3]) << 24)

func _ascii(bytes: PackedByteArray, offset: int, length: int) -> String:
	if offset < 0 or offset + length > bytes.size():
		return ""
	var chars := PackedByteArray()
	for index in range(length):
		chars.append(bytes[offset + index])
	return chars.get_string_from_ascii()

func _fail(message: String) -> void:
	push_error(message)
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"schema_id": REPORT_SCHEMA_ID,
		"ok": false,
		"error": message,
	})])
	get_tree().quit(1)
