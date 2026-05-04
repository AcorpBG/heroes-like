extends Node

const RichnessReportScript = preload("res://tests/random_map_homm3_parity_richness_report.gd")

const REPORT_ID := "RANDOM_MAP_HOMM3_PARITY_VISUAL_INSPECTION_REPORT"
const ARTIFACT_DIR := "res://.artifacts/rmg_parity_visual_inspection"
const MAX_TOTAL_MSEC := 70000
const MIN_ATTEMPTED_CASES := 6
const MIN_STRICT_PASS_CASES := 4
const STRICT_CASE_MSEC := 18000
const DIAGNOSTIC_CASE_MSEC := 24000
const VISUAL_MARKERS := ["T", "G", "A", "M", "R", "#", ".", "C", "~", "="]

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
		result["strict_gate"] = bool(case.get("strict_gate", true))
		_apply_visual_runtime_policy(result, case)
		result["inspection"] = _inspection_summary(result)
		results.append(result)
		_write_case_artifacts(result)
		print("%s_CASE %s" % [REPORT_ID, JSON.stringify(_case_log_line(result))])
		if bool(case.get("strict_gate", true)):
			strict_failures.append_array(result.get("failures", []))
		elif not result.get("failures", []).is_empty():
			diagnostic_gaps.append({
				"id": String(result.get("id", "")),
				"template_id": String(result.get("metrics", {}).get("template_id", "")),
				"failures": result.get("failures", []),
			})
		if Time.get_ticks_msec() - started_msec > MAX_TOTAL_MSEC:
			strict_failures.append("visual inspection report exceeded total runtime budget %d ms" % MAX_TOTAL_MSEC)
			break
	var summary := _summary(results)
	if results.size() < MIN_ATTEMPTED_CASES:
		strict_failures.append("visual inspection attempted too few cases: %d/%d" % [results.size(), MIN_ATTEMPTED_CASES])
	if int(summary.get("strict_pass_case_count", 0)) < MIN_STRICT_PASS_CASES:
		strict_failures.append("visual inspection strict pass count below floor: %d/%d" % [int(summary.get("strict_pass_case_count", 0)), MIN_STRICT_PASS_CASES])
	var report := {
		"ok": strict_failures.is_empty(),
		"report_id": REPORT_ID,
		"case_count": results.size(),
		"runtime_msec": Time.get_ticks_msec() - started_msec,
		"runtime_budget_msec": MAX_TOTAL_MSEC,
		"strict_failures": strict_failures,
		"diagnostic_gaps": diagnostic_gaps,
		"summary": summary,
		"cases": results,
		"artifact_dir": ARTIFACT_DIR,
		"reference_basis": [
			"/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generator-implementation-model.md",
			"/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-template-grammar.md",
			"/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-decoration-object-placement.md",
		],
	}
	_write_json("%s/summary.json" % ARTIFACT_DIR, report)
	_write_matrix_markdown(report)
	if not strict_failures.is_empty():
		_fail("RMG visual inspection report failed: %s" % JSON.stringify(strict_failures))
		return
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"ok": true,
		"case_count": results.size(),
		"runtime_msec": report.get("runtime_msec", 0),
		"summary": summary,
		"diagnostic_gaps": diagnostic_gaps,
		"artifact_dir": ARTIFACT_DIR,
	})])
	get_tree().quit(0)

func _cases() -> Array:
	return [
		{"id": "small_compact_land_visual_a", "seed": "rmg-visual-small-a-10184", "width": 36, "height": 36, "water_mode": "land", "level_count": 1, "player_count": 3, "template_id": "border_gate_compact_v1", "profile_id": "border_gate_compact_profile_v1", "strict_gate": true},
		{"id": "small_compact_land_visual_b", "seed": "rmg-visual-small-b-10184", "width": 36, "height": 36, "water_mode": "land", "level_count": 1, "player_count": 3, "template_id": "border_gate_compact_v1", "profile_id": "border_gate_compact_profile_v1", "strict_gate": true},
		{"id": "small_translated_land_001_visual", "seed": "rmg-visual-small-001-land-10184", "width": 36, "height": 36, "water_mode": "land", "level_count": 1, "player_count": 4, "template_id": "translated_rmg_template_001_v1", "profile_id": "translated_rmg_profile_001_v1", "strict_gate": true},
		{"id": "small_translated_islands_001_visual", "seed": "rmg-visual-islands-001-10184", "width": 36, "height": 36, "water_mode": "islands", "level_count": 1, "player_count": 4, "template_id": "translated_rmg_template_001_v1", "profile_id": "translated_rmg_profile_001_v1", "strict_gate": true},
		{"id": "medium_translated_land_033_visual", "seed": "rmg-visual-medium-033-10184", "width": 72, "height": 72, "water_mode": "land", "level_count": 1, "player_count": 4, "template_id": "translated_rmg_template_033_v1", "profile_id": "translated_rmg_profile_033_v1", "strict_gate": true},
		{"id": "medium_translated_land_002_probe_a", "seed": "rmg-visual-medium-002-a-10184", "width": 72, "height": 72, "water_mode": "land", "level_count": 1, "player_count": 4, "template_id": "translated_rmg_template_002_v1", "profile_id": "translated_rmg_profile_002_v1", "strict_gate": false, "diagnostic_runtime_budget_msec": DIAGNOSTIC_CASE_MSEC},
	]

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
		"diagnostic_notes": result.get("diagnostic_notes", []),
		"failures": result.get("failures", []),
	}

func _write_case_artifacts(result: Dictionary) -> void:
	var case_id := String(result.get("id", "case"))
	_write_json("%s/%s.json" % [ARTIFACT_DIR, case_id], result)
	var preview := FileAccess.open("%s/%s.txt" % [ARTIFACT_DIR, case_id], FileAccess.WRITE)
	if preview != null:
		preview.store_string(String(result.get("preview", "")) + "\n")

func _write_matrix_markdown(report: Dictionary) -> void:
	var lines := [
		"# RMG Parity Visual Inspection Matrix",
		"",
		"Generated by `%s`." % REPORT_ID,
		"",
		"| Case | Gate | Template | Size | Roads | Rivers | Decor Body | Guarded/Guardable | Poor Zones | Row Coverage | Quadrants | ms/Route | Status |",
		"| --- | --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |",
	]
	for result in report.get("cases", []):
		if not (result is Dictionary):
			continue
		var metrics: Dictionary = result.get("metrics", {}) if result.get("metrics", {}) is Dictionary else {}
		var inspection: Dictionary = result.get("inspection", {}) if result.get("inspection", {}) is Dictionary else {}
		var status := "pass" if result.get("failures", []).is_empty() else "diagnostic-gap"
		lines.append("| %s | %s | %s | %dx%d | %d | %d | %d | %d/%d | %d | %.3f | %d/4 | %.1f | %s |" % [
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
			float(inspection.get("row_marker_coverage_ratio", 0.0)),
			int(inspection.get("quadrant_marker_coverage", 0)),
			float(metrics.get("elapsed_msec_per_route", 0.0)),
			status,
		])
	lines.append("")
	lines.append("ASCII legend: `T` town, `G` guard/encounter, `A` artifact, `M` mine/resource producer, `R` reward/resource, `#` blocker body, `.` road, `C` connection-controlled road, `~` river candidate, `=` water. Row coverage and quadrants are marker-distribution checks; long grass runs are retained in JSON as diagnostic terrain composition data, not as a strict quality gate.")
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
	var file := FileAccess.open("%s/matrix.md" % ARTIFACT_DIR, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines) + "\n")

func _ensure_artifact_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ARTIFACT_DIR))
	var dir := DirAccess.open(ARTIFACT_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and (file_name.ends_with(".json") or file_name.ends_with(".txt") or file_name.ends_with(".md")):
			dir.remove(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

func _write_json(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload, "\t") + "\n")

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "error": message})])
	get_tree().quit(1)
