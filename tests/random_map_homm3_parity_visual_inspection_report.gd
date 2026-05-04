extends Node

const RichnessReportScript = preload("res://tests/random_map_homm3_parity_richness_report.gd")

const DEFAULT_REPORT_ID := "RANDOM_MAP_HOMM3_PARITY_VISUAL_INSPECTION_REPORT"
const LARGE_REPORT_ID := "RANDOM_MAP_HOMM3_PARITY_LARGE_VISUAL_INSPECTION_REPORT"
const DEFAULT_ARTIFACT_DIR := "res://.artifacts/rmg_parity_visual_inspection"
const LARGE_ARTIFACT_DIR := "res://.artifacts/rmg_parity_large_visual_inspection"
const DEFAULT_MAX_TOTAL_MSEC := 70000
const LARGE_MAX_TOTAL_MSEC := 120000
const DEFAULT_MIN_ATTEMPTED_CASES := 6
const LARGE_MIN_ATTEMPTED_CASES := 1
const DEFAULT_MIN_STRICT_PASS_CASES := 4
const LARGE_MIN_STRICT_PASS_CASES := 0
const STRICT_CASE_MSEC := 18000
const DIAGNOSTIC_CASE_MSEC := 24000
const LARGE_DIAGNOSTIC_CASE_MSEC := 90000
const VISUAL_MARKERS := ["T", "G", "A", "M", "R", "#", ".", "C", "~", "="]

@export var report_mode := "standard"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var started_msec := Time.get_ticks_msec()
	var inspector = RichnessReportScript.new()
	var results := []
	var strict_failures := []
	var diagnostic_gaps := []
	_ensure_artifact_dir()
	for case in _cases():
		var result := inspector._inspect_case(case)
		if String(result.get("id", "")) == "":
			result["id"] = String(case.get("id", ""))
			result["failures"] = ["visual inspection case returned no result payload"]
		result["strict_gate"] = bool(case.get("strict_gate", true))
		_apply_visual_runtime_policy(result, case)
		result["inspection"] = _inspection_summary(result)
		results.append(result)
		_write_case_artifacts(result)
		print("%s_CASE %s" % [_report_id(), JSON.stringify(_case_log_line(result))])
		if bool(case.get("strict_gate", true)):
			strict_failures.append_array(result.get("failures", []))
		elif not result.get("failures", []).is_empty():
			diagnostic_gaps.append({
				"id": String(result.get("id", "")),
				"template_id": String(result.get("metrics", {}).get("template_id", "")),
				"failures": result.get("failures", []),
			})
		if Time.get_ticks_msec() - started_msec > _max_total_msec():
			strict_failures.append("visual inspection report exceeded total runtime budget %d ms" % _max_total_msec())
			break
	var summary := _summary(results)
	if results.size() < _min_attempted_cases():
		strict_failures.append("visual inspection attempted too few cases: %d/%d" % [results.size(), _min_attempted_cases()])
	if int(summary.get("strict_pass_case_count", 0)) < _min_strict_pass_cases():
		strict_failures.append("visual inspection strict pass count below floor: %d/%d" % [int(summary.get("strict_pass_case_count", 0)), _min_strict_pass_cases()])
	if _max_diagnostic_gap_count() >= 0 and diagnostic_gaps.size() > _max_diagnostic_gap_count():
		strict_failures.append("visual inspection diagnostic gaps exceeded limit: %d/%d" % [diagnostic_gaps.size(), _max_diagnostic_gap_count()])
	var report := {
		"ok": strict_failures.is_empty(),
		"report_id": _report_id(),
		"report_mode": _report_mode(),
		"case_count": results.size(),
		"runtime_msec": Time.get_ticks_msec() - started_msec,
		"runtime_budget_msec": _max_total_msec(),
		"strict_failures": strict_failures,
		"diagnostic_gaps": diagnostic_gaps,
		"summary": summary,
		"cases": results,
		"artifact_dir": _artifact_dir(),
		"reference_basis": [
			"/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generator-implementation-model.md",
			"/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-template-grammar.md",
			"/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-decoration-object-placement.md",
			"/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-zone-link-consumers.md",
		],
	}
	_write_json("%s/summary.json" % _artifact_dir(), report)
	_write_matrix_markdown(report)
	_write_rendered_gallery(report)
	if not strict_failures.is_empty():
		_fail("RMG visual inspection report failed: %s" % JSON.stringify(strict_failures))
		return
	print("%s %s" % [_report_id(), JSON.stringify({
		"ok": true,
		"case_count": results.size(),
		"runtime_msec": report.get("runtime_msec", 0),
		"summary": summary,
		"diagnostic_gaps": diagnostic_gaps,
		"artifact_dir": _artifact_dir(),
	})])
	get_tree().quit(0)

func _cases() -> Array:
	if _report_mode() == "large":
		return [
			{"id": "large_translated_land_042_visual", "seed": "rmg-large-visual-042-10184", "width": 108, "height": 108, "water_mode": "land", "level_count": 1, "player_count": 4, "template_id": "translated_rmg_template_042_v1", "profile_id": "translated_rmg_profile_042_v1", "strict_gate": false, "diagnostic_runtime_budget_msec": LARGE_DIAGNOSTIC_CASE_MSEC},
		]
	return [
		{"id": "small_compact_land_visual_a", "seed": "rmg-visual-small-a-10184", "width": 36, "height": 36, "water_mode": "land", "level_count": 1, "player_count": 3, "template_id": "border_gate_compact_v1", "profile_id": "border_gate_compact_profile_v1", "strict_gate": true},
		{"id": "small_compact_land_visual_b", "seed": "rmg-visual-small-b-10184", "width": 36, "height": 36, "water_mode": "land", "level_count": 1, "player_count": 3, "template_id": "border_gate_compact_v1", "profile_id": "border_gate_compact_profile_v1", "strict_gate": true},
		{"id": "small_translated_land_001_visual", "seed": "rmg-visual-small-001-land-10184", "width": 36, "height": 36, "water_mode": "land", "level_count": 1, "player_count": 4, "template_id": "translated_rmg_template_001_v1", "profile_id": "translated_rmg_profile_001_v1", "strict_gate": true},
		{"id": "small_translated_islands_001_visual", "seed": "rmg-visual-islands-001-10184", "width": 36, "height": 36, "water_mode": "islands", "level_count": 1, "player_count": 4, "template_id": "translated_rmg_template_001_v1", "profile_id": "translated_rmg_profile_001_v1", "strict_gate": true},
		{"id": "medium_translated_land_033_visual", "seed": "rmg-visual-medium-033-10184", "width": 72, "height": 72, "water_mode": "land", "level_count": 1, "player_count": 4, "template_id": "translated_rmg_template_033_v1", "profile_id": "translated_rmg_profile_033_v1", "strict_gate": true},
		{"id": "medium_translated_land_002_probe_a", "seed": "rmg-visual-medium-002-a-10184", "width": 72, "height": 72, "water_mode": "land", "level_count": 1, "player_count": 4, "template_id": "translated_rmg_template_002_v1", "profile_id": "translated_rmg_profile_002_v1", "strict_gate": false, "diagnostic_runtime_budget_msec": DIAGNOSTIC_CASE_MSEC},
	]

func _report_mode() -> String:
	var mode := report_mode.strip_edges().to_lower()
	return "large" if mode == "large" else "standard"

func _report_id() -> String:
	return LARGE_REPORT_ID if _report_mode() == "large" else DEFAULT_REPORT_ID

func _artifact_dir() -> String:
	return LARGE_ARTIFACT_DIR if _report_mode() == "large" else DEFAULT_ARTIFACT_DIR

func _max_total_msec() -> int:
	return LARGE_MAX_TOTAL_MSEC if _report_mode() == "large" else DEFAULT_MAX_TOTAL_MSEC

func _min_attempted_cases() -> int:
	return LARGE_MIN_ATTEMPTED_CASES if _report_mode() == "large" else DEFAULT_MIN_ATTEMPTED_CASES

func _min_strict_pass_cases() -> int:
	return LARGE_MIN_STRICT_PASS_CASES if _report_mode() == "large" else DEFAULT_MIN_STRICT_PASS_CASES

func _max_diagnostic_gap_count() -> int:
	return 0 if _report_mode() == "large" else -1

func _apply_visual_runtime_policy(result: Dictionary, case: Dictionary) -> void:
	var metrics: Dictionary = result.get("metrics", {}) if result.get("metrics", {}) is Dictionary else {}
	var elapsed_msec := int(metrics.get("elapsed_msec", 0))
	var route_count: int = max(1, int(metrics.get("road_segment_count", 0)))
	var budget_msec := STRICT_CASE_MSEC if bool(case.get("strict_gate", true)) else int(case.get("diagnostic_runtime_budget_msec", DIAGNOSTIC_CASE_MSEC))
	var failures := []
	var diagnostic_notes := []
	for failure in result.get("failures", []):
		var failure_text := String(failure)
		if not bool(case.get("strict_gate", true)) and failure_text.find("exceeded per-case runtime budget") >= 0 and elapsed_msec <= budget_msec:
			diagnostic_notes.append("%s exceeded strict %d ms case budget but stayed within diagnostic probe budget %d ms" % [String(result.get("id", "")), STRICT_CASE_MSEC, budget_msec])
			continue
		failures.append(failure_text)
	if not bool(case.get("strict_gate", true)) and elapsed_msec > budget_msec:
		failures.append("%s exceeded diagnostic probe runtime budget: %d/%d ms" % [String(result.get("id", "")), elapsed_msec, budget_msec])
	metrics["visual_runtime_budget_msec"] = budget_msec
	metrics["visual_runtime_budget_status"] = "pass" if elapsed_msec <= budget_msec else "fail"
	metrics["elapsed_msec_per_route"] = snapped(float(elapsed_msec) / float(route_count), 0.001)
	metrics["diagnostic_note_count"] = diagnostic_notes.size()
	result["metrics"] = metrics
	result["failures"] = failures
	result["diagnostic_notes"] = diagnostic_notes

func _inspection_summary(result: Dictionary) -> Dictionary:
	var preview := String(result.get("preview", ""))
	var lines := preview.split("\n", false)
	var symbol_counts := {}
	var longest_blank_run := 0
	var blank_like_total := 0
	var total_chars := 0
	var width_max := 0
	var marker_rows := {}
	var marker_columns := {}
	var quadrant_markers := [0, 0, 0, 0]
	for y in range(lines.size()):
		var line := String(lines[y])
		width_max = max(width_max, line.length())
		var current_blank := 0
		for i in range(line.length()):
			var ch := line.substr(i, 1)
			symbol_counts[ch] = int(symbol_counts.get(ch, 0)) + 1
			total_chars += 1
			if ch == " ":
				current_blank += 1
				blank_like_total += 1
				longest_blank_run = max(longest_blank_run, current_blank)
			else:
				current_blank = 0
			if ch in VISUAL_MARKERS:
				marker_rows[y] = true
				marker_columns[i] = true
				var quadrant_x := 0 if i < int(max(1, width_max) / 2) else 1
				var quadrant_y := 0 if y < int(max(1, lines.size()) / 2) else 1
				var quadrant_index := quadrant_y * 2 + quadrant_x
				quadrant_markers[quadrant_index] = int(quadrant_markers[quadrant_index]) + 1
	var marker_count := 0
	for ch in VISUAL_MARKERS:
		marker_count += int(symbol_counts.get(ch, 0))
	var covered_quadrants := 0
	for quadrant_count in quadrant_markers:
		if int(quadrant_count) > 0:
			covered_quadrants += 1
	var metrics: Dictionary = result.get("metrics", {}) if result.get("metrics", {}) is Dictionary else {}
	var observations := []
	if total_chars > 0 and float(longest_blank_run) / float(max(1, width_max)) > 0.55:
		observations.append("large contiguous grass terrain run in ASCII inspection")
	if int(metrics.get("road_tile_count", 0)) <= 0:
		observations.append("no visible road layer")
	if int(metrics.get("decoration_blocking_body_tile_total", 0)) <= 0:
		observations.append("no decorative blocker body layer")
	if int(metrics.get("guarded_valuable_object_count", 0)) < int(metrics.get("guardable_valuable_object_count", 0)):
		observations.append("unguarded valuable objects remain in generated output")
	if int(metrics.get("fairness_fail_threshold_warning_count", 0)) > 0:
		observations.append("source-backed layout fairness spread exceeded fail threshold")
	if covered_quadrants < 4:
		observations.append("visual markers do not cover all map quadrants")
	return {
		"preview_width": width_max,
		"preview_height": lines.size(),
		"symbol_counts": symbol_counts,
		"total_chars": total_chars,
		"marker_count": marker_count,
		"blank_like_ratio": snapped(float(blank_like_total) / float(max(1, total_chars)), 0.001),
		"longest_blank_run": longest_blank_run,
		"longest_blank_run_ratio": snapped(float(longest_blank_run) / float(max(1, width_max)), 0.001),
		"row_marker_coverage_ratio": snapped(float(marker_rows.size()) / float(max(1, lines.size())), 0.001),
		"column_marker_coverage_ratio": snapped(float(marker_columns.size()) / float(max(1, width_max)), 0.001),
		"quadrant_marker_coverage": covered_quadrants,
		"quadrant_marker_counts": quadrant_markers,
		"observations": observations,
	}

func _summary(results: Array) -> Dictionary:
	var totals := {
		"strict_case_count": 0,
		"strict_pass_case_count": 0,
		"diagnostic_case_count": 0,
		"diagnostic_gap_case_count": 0,
		"template_count": 0,
		"signature_count": 0,
		"preview_artifact_count": 0,
		"rendered_preview_artifact_count": 0,
		"min_marker_count": 999999,
		"max_grass_run_ratio": 0.0,
		"min_row_marker_coverage_ratio": 1.0,
		"min_column_marker_coverage_ratio": 1.0,
		"min_quadrant_marker_coverage": 4,
		"diagnostic_note_count": 0,
		"max_elapsed_msec_per_route": 0.0,
		"total_road_tiles": 0,
		"total_river_candidates": 0,
		"total_decor_body_tiles": 0,
		"total_guarded_valuable_objects": 0,
		"total_guardable_valuable_objects": 0,
		"total_poor_zones": 0,
		"total_fairness_warnings": 0,
		"total_fairness_fail_threshold_warnings": 0,
		"total_fairness_accepted_asymmetry_warnings": 0,
		"total_fairness_unresolved_review_warnings": 0,
		"max_contest_route_distance_spread": 0,
		"max_travel_contest_route_distance_spread": 0,
		"max_contest_guard_pressure_spread": 0,
		"max_route_guard_pressure_spread": 0,
		"max_town_to_resource_distance_spread": 0,
	}
	var templates := {}
	var signatures := {}
	for result in results:
		if not (result is Dictionary):
			continue
		var metrics: Dictionary = result.get("metrics", {}) if result.get("metrics", {}) is Dictionary else {}
		var inspection: Dictionary = result.get("inspection", {}) if result.get("inspection", {}) is Dictionary else {}
		templates[String(metrics.get("template_id", ""))] = true
		signatures[String(metrics.get("stable_signature", ""))] = true
		totals["preview_artifact_count"] = int(totals.get("preview_artifact_count", 0)) + 1
		if result.get("rendered_preview", {}) is Dictionary and String(result.get("rendered_preview", {}).get("path", "")) != "":
			totals["rendered_preview_artifact_count"] = int(totals.get("rendered_preview_artifact_count", 0)) + 1
		totals["min_marker_count"] = min(int(totals.get("min_marker_count", 999999)), int(inspection.get("marker_count", 0)))
		totals["max_grass_run_ratio"] = max(float(totals.get("max_grass_run_ratio", 0.0)), float(inspection.get("longest_blank_run_ratio", 0.0)))
		totals["min_row_marker_coverage_ratio"] = min(float(totals.get("min_row_marker_coverage_ratio", 1.0)), float(inspection.get("row_marker_coverage_ratio", 0.0)))
		totals["min_column_marker_coverage_ratio"] = min(float(totals.get("min_column_marker_coverage_ratio", 1.0)), float(inspection.get("column_marker_coverage_ratio", 0.0)))
		totals["min_quadrant_marker_coverage"] = min(int(totals.get("min_quadrant_marker_coverage", 4)), int(inspection.get("quadrant_marker_coverage", 0)))
		totals["diagnostic_note_count"] = int(totals.get("diagnostic_note_count", 0)) + int(metrics.get("diagnostic_note_count", 0))
		totals["max_elapsed_msec_per_route"] = max(float(totals.get("max_elapsed_msec_per_route", 0.0)), float(metrics.get("elapsed_msec_per_route", 0.0)))
		totals["total_road_tiles"] = int(totals.get("total_road_tiles", 0)) + int(metrics.get("road_tile_count", 0))
		totals["total_river_candidates"] = int(totals.get("total_river_candidates", 0)) + int(metrics.get("river_candidate_count", 0))
		totals["total_decor_body_tiles"] = int(totals.get("total_decor_body_tiles", 0)) + int(metrics.get("decoration_blocking_body_tile_total", 0))
		totals["total_guarded_valuable_objects"] = int(totals.get("total_guarded_valuable_objects", 0)) + int(metrics.get("guarded_valuable_object_count", 0))
		totals["total_guardable_valuable_objects"] = int(totals.get("total_guardable_valuable_objects", 0)) + int(metrics.get("guardable_valuable_object_count", 0))
		totals["total_poor_zones"] = int(totals.get("total_poor_zones", 0)) + int(metrics.get("poor_zone_count", 0))
		totals["total_fairness_warnings"] = int(totals.get("total_fairness_warnings", 0)) + int(metrics.get("fairness_warning_count", 0))
		totals["total_fairness_fail_threshold_warnings"] = int(totals.get("total_fairness_fail_threshold_warnings", 0)) + int(metrics.get("fairness_fail_threshold_warning_count", 0))
		totals["total_fairness_accepted_asymmetry_warnings"] = int(totals.get("total_fairness_accepted_asymmetry_warnings", 0)) + int(metrics.get("fairness_accepted_asymmetry_warning_count", 0))
		totals["total_fairness_unresolved_review_warnings"] = int(totals.get("total_fairness_unresolved_review_warnings", 0)) + int(metrics.get("fairness_unresolved_review_warning_count", 0))
		totals["max_contest_route_distance_spread"] = max(int(totals.get("max_contest_route_distance_spread", 0)), int(metrics.get("contest_route_distance_spread", 0)))
		totals["max_travel_contest_route_distance_spread"] = max(int(totals.get("max_travel_contest_route_distance_spread", 0)), int(metrics.get("travel_contest_route_distance_spread", 0)))
		totals["max_contest_guard_pressure_spread"] = max(int(totals.get("max_contest_guard_pressure_spread", 0)), int(metrics.get("contest_guard_pressure_spread", 0)))
		totals["max_route_guard_pressure_spread"] = max(int(totals.get("max_route_guard_pressure_spread", 0)), int(metrics.get("route_guard_pressure_spread", 0)))
		totals["max_town_to_resource_distance_spread"] = max(int(totals.get("max_town_to_resource_distance_spread", 0)), int(metrics.get("town_to_resource_distance_spread", 0)))
		if bool(result.get("strict_gate", true)):
			totals["strict_case_count"] = int(totals.get("strict_case_count", 0)) + 1
			if result.get("failures", []).is_empty():
				totals["strict_pass_case_count"] = int(totals.get("strict_pass_case_count", 0)) + 1
		else:
			totals["diagnostic_case_count"] = int(totals.get("diagnostic_case_count", 0)) + 1
			if not result.get("failures", []).is_empty():
				totals["diagnostic_gap_case_count"] = int(totals.get("diagnostic_gap_case_count", 0)) + 1
	if int(totals.get("min_marker_count", 999999)) == 999999:
		totals["min_marker_count"] = 0
	totals["template_count"] = templates.size()
	totals["signature_count"] = signatures.size()
	return totals

func _case_log_line(result: Dictionary) -> Dictionary:
	var metrics: Dictionary = result.get("metrics", {}) if result.get("metrics", {}) is Dictionary else {}
	var inspection: Dictionary = result.get("inspection", {}) if result.get("inspection", {}) is Dictionary else {}
	return {
		"id": String(result.get("id", "")),
		"strict_gate": bool(result.get("strict_gate", true)),
		"ok": result.get("failures", []).is_empty(),
		"elapsed_msec": int(metrics.get("elapsed_msec", 0)),
		"template": String(metrics.get("template_id", "")),
		"roads": int(metrics.get("road_tile_count", 0)),
		"rivers": int(metrics.get("river_candidate_count", 0)),
		"decor_body_tiles": int(metrics.get("decoration_blocking_body_tile_total", 0)),
		"guarded_valuable": int(metrics.get("guarded_valuable_object_count", 0)),
		"guardable_valuable": int(metrics.get("guardable_valuable_object_count", 0)),
		"poor_zones": int(metrics.get("poor_zone_count", 0)),
		"markers": int(inspection.get("marker_count", 0)),
		"grass_run_ratio": float(inspection.get("longest_blank_run_ratio", 0.0)),
		"row_marker_coverage": float(inspection.get("row_marker_coverage_ratio", 0.0)),
		"quadrant_marker_coverage": int(inspection.get("quadrant_marker_coverage", 0)),
		"elapsed_msec_per_route": float(metrics.get("elapsed_msec_per_route", 0.0)),
		"layout_quality_status": String(metrics.get("fairness_layout_quality_status", "")),
		"fairness_warnings": int(metrics.get("fairness_warning_count", 0)),
		"fairness_fail_threshold_warnings": int(metrics.get("fairness_fail_threshold_warning_count", 0)),
		"fairness_accepted_asymmetry_warnings": int(metrics.get("fairness_accepted_asymmetry_warning_count", 0)),
		"fairness_unresolved_review_warnings": int(metrics.get("fairness_unresolved_review_warning_count", 0)),
		"contest_route_distance_spread": int(metrics.get("contest_route_distance_spread", 0)),
		"travel_contest_route_distance_spread": int(metrics.get("travel_contest_route_distance_spread", 0)),
		"contest_guard_pressure_spread": int(metrics.get("contest_guard_pressure_spread", 0)),
		"town_to_resource_distance_spread": int(metrics.get("town_to_resource_distance_spread", 0)),
		"diagnostic_notes": result.get("diagnostic_notes", []),
		"failures": result.get("failures", []),
	}

func _write_case_artifacts(result: Dictionary) -> void:
	var case_id := String(result.get("id", "case"))
	var rendered_path := "%s/%s.svg" % [_artifact_dir(), case_id]
	result["rendered_preview"] = {
		"path": rendered_path,
		"format": "svg",
		"source": "ascii_visual_inspection_preview",
		"manual_review_role": "human-inspectable generated-map preview for roads, rivers, terrain, towns, guards, resources, artifacts, and blockers",
	}
	var rendered := FileAccess.open(rendered_path, FileAccess.WRITE)
	if rendered != null:
		rendered.store_string(_svg_preview(result))
	_write_json("%s/%s.json" % [_artifact_dir(), case_id], result)
	var preview := FileAccess.open("%s/%s.txt" % [_artifact_dir(), case_id], FileAccess.WRITE)
	if preview != null:
		preview.store_string(String(result.get("preview", "")) + "\n")

func _write_matrix_markdown(report: Dictionary) -> void:
	var lines := [
		"# RMG Parity Visual Inspection Matrix",
		"",
		"Generated by `%s`." % _report_id(),
		"",
		"| Case | Gate | Template | Size | Roads | Rivers | Decor Body | Guarded/Guardable | Poor Zones | Fair Warn | Accepted | Review | Contest Dist | Guard Spread | Town-Resource | Row Coverage | Quadrants | ms/Route | Rendered | Status |",
		"| --- | --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- |",
	]
	for result in report.get("cases", []):
		if not (result is Dictionary):
			continue
		var metrics: Dictionary = result.get("metrics", {}) if result.get("metrics", {}) is Dictionary else {}
		var inspection: Dictionary = result.get("inspection", {}) if result.get("inspection", {}) is Dictionary else {}
		var status := "pass" if result.get("failures", []).is_empty() else "diagnostic-gap"
		var rendered: Dictionary = result.get("rendered_preview", {}) if result.get("rendered_preview", {}) is Dictionary else {}
		var rendered_link := "[svg](%s)" % String(rendered.get("path", "")).get_file() if String(rendered.get("path", "")) != "" else ""
		lines.append("| %s | %s | %s | %dx%d | %d | %d | %d | %d/%d | %d | %d/%d | %d | %d | %d/%d | %d | %d | %.3f | %d/4 | %.1f | %s | %s |" % [
			String(result.get("id", "")),
			"strict" if bool(result.get("strict_gate", true)) else "diagnostic",
			String(metrics.get("template_id", "")),
			int(metrics.get("width", 0)),
			int(metrics.get("height", 0)),
			int(metrics.get("road_tile_count", 0)),
			int(metrics.get("river_candidate_count", 0)),
			int(metrics.get("decoration_blocking_body_tile_total", 0)),
			int(metrics.get("guarded_valuable_object_count", 0)),
			int(metrics.get("guardable_valuable_object_count", 0)),
			int(metrics.get("poor_zone_count", 0)),
			int(metrics.get("fairness_fail_threshold_warning_count", 0)),
			int(metrics.get("fairness_warning_count", 0)),
			int(metrics.get("fairness_accepted_asymmetry_warning_count", 0)),
			int(metrics.get("fairness_unresolved_review_warning_count", 0)),
			int(metrics.get("contest_route_distance_spread", 0)),
			int(metrics.get("travel_contest_route_distance_spread", 0)),
			int(metrics.get("contest_guard_pressure_spread", 0)),
			int(metrics.get("town_to_resource_distance_spread", 0)),
			float(inspection.get("row_marker_coverage_ratio", 0.0)),
			int(inspection.get("quadrant_marker_coverage", 0)),
			float(metrics.get("elapsed_msec_per_route", 0.0)),
			rendered_link,
			status,
		])
	lines.append("")
	lines.append("ASCII legend: `T` town, `G` guard/encounter, `A` artifact, `M` mine/resource producer, `R` reward/resource, `#` blocker body, `.` road, `C` connection-controlled road, `~` river candidate, `=` water. Fair Warn shows fail-threshold warnings over total raw fairness warnings; Accepted/Review split warning-level source-template asymmetry from warnings that still need manual review. Distance/pressure spread columns are diagnostic layout-quality evidence, not rendered art comparison.")
	lines.append("")
	for result in report.get("cases", []):
		if not (result is Dictionary):
			continue
		lines.append("## %s" % String(result.get("id", "")))
		lines.append("")
		lines.append("```")
		lines.append(String(result.get("preview", "")))
		lines.append("```")
		lines.append("")
	var file := FileAccess.open("%s/matrix.md" % _artifact_dir(), FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines) + "\n")

func _write_rendered_gallery(report: Dictionary) -> void:
	var lines := [
		"<!doctype html>",
		"<html><head><meta charset=\"utf-8\"><title>%s Rendered Preview Gallery</title>" % _report_id(),
		"<style>body{font-family:sans-serif;margin:24px;background:#f5f1e7;color:#241f18}table{border-collapse:collapse;margin-bottom:24px}td,th{border:1px solid #c8bda8;padding:6px 8px;text-align:left}img{max-width:100%;image-rendering:pixelated;border:1px solid #766b5a;background:white}.case{margin:0 0 32px}.metrics{font-size:13px;color:#463d30}</style>",
		"</head><body>",
		"<h1>%s Rendered Preview Gallery</h1>" % _xml_escape(_report_id()),
		"<p>Generated SVG previews for manual RMG layout review. These artifacts visualize the same inspection symbols as the ASCII matrix without importing generated art into runtime assets.</p>",
		"<table><tr><th>Case</th><th>Gate</th><th>Template</th><th>Roads</th><th>Fair Warnings</th><th>Accepted</th><th>Review</th><th>Rendered Preview</th></tr>",
	]
	for result in report.get("cases", []):
		if not (result is Dictionary):
			continue
		var metrics: Dictionary = result.get("metrics", {}) if result.get("metrics", {}) is Dictionary else {}
		var rendered: Dictionary = result.get("rendered_preview", {}) if result.get("rendered_preview", {}) is Dictionary else {}
		var file_name := String(rendered.get("path", "")).get_file()
		lines.append("<tr><td>%s</td><td>%s</td><td>%s</td><td>%d</td><td>%d/%d</td><td>%d</td><td>%d</td><td><a href=\"%s\">svg</a></td></tr>" % [
			_xml_escape(String(result.get("id", ""))),
			"strict" if bool(result.get("strict_gate", true)) else "diagnostic",
			_xml_escape(String(metrics.get("template_id", ""))),
			int(metrics.get("road_tile_count", 0)),
			int(metrics.get("fairness_fail_threshold_warning_count", 0)),
			int(metrics.get("fairness_warning_count", 0)),
			int(metrics.get("fairness_accepted_asymmetry_warning_count", 0)),
			int(metrics.get("fairness_unresolved_review_warning_count", 0)),
			_xml_escape(file_name),
		])
	lines.append("</table>")
	for result in report.get("cases", []):
		if not (result is Dictionary):
			continue
		var metrics: Dictionary = result.get("metrics", {}) if result.get("metrics", {}) is Dictionary else {}
		var rendered: Dictionary = result.get("rendered_preview", {}) if result.get("rendered_preview", {}) is Dictionary else {}
		var file_name := String(rendered.get("path", "")).get_file()
		if file_name == "":
			continue
		lines.append("<section class=\"case\"><h2>%s</h2><div class=\"metrics\">template %s, roads %d, fair warnings %d/%d, contest spread %d/%d, town-resource spread %d</div><p><img src=\"%s\" alt=\"%s rendered map preview\"></p></section>" % [
			_xml_escape(String(result.get("id", ""))),
			_xml_escape(String(metrics.get("template_id", ""))),
			int(metrics.get("road_tile_count", 0)),
			int(metrics.get("fairness_fail_threshold_warning_count", 0)),
			int(metrics.get("fairness_warning_count", 0)),
			int(metrics.get("contest_route_distance_spread", 0)),
			int(metrics.get("travel_contest_route_distance_spread", 0)),
			int(metrics.get("town_to_resource_distance_spread", 0)),
			_xml_escape(file_name),
			_xml_escape(String(result.get("id", ""))),
		])
	lines.append("</body></html>")
	var file := FileAccess.open("%s/rendered_gallery.html" % _artifact_dir(), FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines) + "\n")

func _svg_preview(result: Dictionary) -> String:
	var preview := String(result.get("preview", ""))
	var lines := preview.split("\n", false)
	var cell := 12
	var label_size := 8
	var width := 0
	for line in lines:
		width = max(width, String(line).length())
	var height := lines.size()
	var svg := [
		"<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
		"<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%d\" height=\"%d\" viewBox=\"0 0 %d %d\" shape-rendering=\"crispEdges\">" % [width * cell, height * cell, width * cell, height * cell],
		"<rect width=\"100%\" height=\"100%\" fill=\"#efe3bd\"/>",
	]
	for y in range(height):
		var line := String(lines[y])
		for x in range(width):
			var ch := " "
			if x < line.length():
				ch = line.substr(x, 1)
			var fill := _svg_fill_for_preview_char(ch)
			svg.append("<rect x=\"%d\" y=\"%d\" width=\"%d\" height=\"%d\" fill=\"%s\"/>" % [x * cell, y * cell, cell, cell, fill])
			if ch in ["T", "G", "A", "M", "R", "C"]:
				svg.append("<text x=\"%d\" y=\"%d\" font-family=\"monospace\" font-size=\"%d\" text-anchor=\"middle\" fill=\"%s\">%s</text>" % [x * cell + int(cell / 2), y * cell + cell - 3, label_size, _svg_text_fill_for_preview_char(ch), ch])
	svg.append("</svg>")
	return "\n".join(svg) + "\n"

func _svg_fill_for_preview_char(ch: String) -> String:
	match ch:
		"T":
			return "#f0d35f"
		"G":
			return "#b6463f"
		"A":
			return "#8e5ac7"
		"M":
			return "#6f8d4e"
		"R":
			return "#d79d43"
		"#":
			return "#5e5a50"
		".":
			return "#d4bf86"
		"C":
			return "#b98a49"
		"~":
			return "#5aa6b8"
		"=":
			return "#456da8"
		"^":
			return "#9f8c66"
		":":
			return "#a97448"
		",":
			return "#d2be82"
		"*":
			return "#e8edf0"
		"!":
			return "#8f4139"
		"u":
			return "#65584a"
		_:
			return "#87a969"

func _svg_text_fill_for_preview_char(ch: String) -> String:
	return "#241f18" if ch in ["T", "A", "M", "R", "C"] else "#ffffff"

func _xml_escape(value: String) -> String:
	return value.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;")

func _ensure_artifact_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_artifact_dir()))
	var dir := DirAccess.open(_artifact_dir())
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and (file_name.ends_with(".json") or file_name.ends_with(".txt") or file_name.ends_with(".md") or file_name.ends_with(".svg") or file_name.ends_with(".html")):
			dir.remove(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

func _write_json(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload, "\t") + "\n")

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [_report_id(), message])
	print("%s %s" % [_report_id(), JSON.stringify({"ok": false, "error": message})])
	get_tree().quit(1)
