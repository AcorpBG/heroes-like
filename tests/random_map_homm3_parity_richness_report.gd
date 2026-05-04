extends Node

const RandomMapGeneratorRulesScript = preload("res://scripts/core/RandomMapGeneratorRules.gd")
const REPORT_ID := "RANDOM_MAP_HOMM3_PARITY_RICHNESS_REPORT"
const ARTIFACT_DIR := "res://.artifacts/rmg_parity_richness"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var cases := _cases()
	var results := []
	var failures := []
	_ensure_artifact_dir()
	for case in cases:
		var result := _inspect_case(case)
		results.append(result)
		failures.append_array(result.get("failures", []))
		_write_case_artifacts(result)
	var summary := _summary(results)
	var report := {
		"ok": failures.is_empty(),
		"report_id": REPORT_ID,
		"case_count": results.size(),
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
		"summary": summary,
		"artifact_dir": ARTIFACT_DIR,
	})])
	get_tree().quit(0)

func _cases() -> Array:
	return [
		{"id": "small_compact_land_a", "seed": "rmg-richness-small-a-10184", "width": 36, "height": 36, "water_mode": "land", "level_count": 1, "player_count": 3, "template_id": "border_gate_compact_v1", "profile_id": "border_gate_compact_profile_v1"},
		{"id": "small_compact_land_b", "seed": "rmg-richness-small-b-10184", "width": 36, "height": 36, "water_mode": "land", "level_count": 1, "player_count": 3, "template_id": "border_gate_compact_v1", "profile_id": "border_gate_compact_profile_v1"},
		{"id": "medium_translated_land", "seed": "rmg-richness-medium-10184", "width": 72, "height": 72, "water_mode": "land", "level_count": 1, "player_count": 4, "template_id": "translated_rmg_template_033_v1", "profile_id": "translated_rmg_profile_033_v1"},
		{"id": "large_translated_land", "seed": "rmg-richness-large-10184", "width": 108, "height": 108, "water_mode": "land", "level_count": 1, "player_count": 4, "template_id": "translated_rmg_template_042_v1", "profile_id": "translated_rmg_profile_042_v1"},
		{"id": "xl_translated_land", "seed": "rmg-richness-xl-10184", "width": 144, "height": 144, "water_mode": "land", "level_count": 1, "player_count": 4, "template_id": "translated_rmg_template_043_v1", "profile_id": "translated_rmg_profile_043_v1"},
		{"id": "small_islands", "seed": "rmg-richness-islands-10184", "width": 36, "height": 36, "water_mode": "islands", "level_count": 1, "player_count": 4, "template_id": "translated_rmg_template_001_v1", "profile_id": "translated_rmg_profile_001_v1"},
	]

func _inspect_case(case: Dictionary) -> Dictionary:
	var generation: Dictionary = RandomMapGeneratorRulesScript.generate(_config(case))
	var payload: Dictionary = generation.get("generated_map", {}) if generation.get("generated_map", {}) is Dictionary else {}
	var validation_report: Dictionary = generation.get("report", {}) if generation.get("report", {}) is Dictionary else {}
	var staging: Dictionary = payload.get("staging", {}) if payload.get("staging", {}) is Dictionary else {}
	var scenario: Dictionary = payload.get("scenario_record", {}) if payload.get("scenario_record", {}) is Dictionary else {}
	var roads: Dictionary = staging.get("roads_rivers_writeout", {}).get("road_overlay", {}) if staging.get("roads_rivers_writeout", {}).get("road_overlay", {}) is Dictionary else {}
	var rivers: Dictionary = staging.get("roads_rivers_writeout", {}).get("river_water_coast_overlay", {}) if staging.get("roads_rivers_writeout", {}).get("river_water_coast_overlay", {}) is Dictionary else {}
	var town_payload: Dictionary = staging.get("town_mine_dwelling_placement", {}) if staging.get("town_mine_dwelling_placement", {}) is Dictionary else {}
	var route_reward_summary: Dictionary = staging.get("materialized_route_reward_summary", {}) if staging.get("materialized_route_reward_summary", {}) is Dictionary else {}
	var object_guard_summary: Dictionary = staging.get("materialized_object_guard_summary", {}) if staging.get("materialized_object_guard_summary", {}) is Dictionary else {}
	var decor: Dictionary = staging.get("decoration_density_pass", {}) if staging.get("decoration_density_pass", {}) is Dictionary else {}
	var serialization: Dictionary = staging.get("roads_rivers_writeout", {}).get("generated_map_serialization", {}) if staging.get("roads_rivers_writeout", {}).get("generated_map_serialization", {}) is Dictionary else {}
	var metrics := {
		"ok": bool(generation.get("ok", false)),
		"validation_failure_count": validation_report.get("failures", []).size() if validation_report.get("failures", []) is Array else 0,
		"stable_signature": String(payload.get("stable_signature", "")),
		"template_id": String(payload.get("metadata", {}).get("template_id", "")),
		"profile_id": String(payload.get("metadata", {}).get("profile", {}).get("id", "")),
		"width": int(case.get("width", 0)),
		"height": int(case.get("height", 0)),
		"water_mode": String(case.get("water_mode", "land")),
		"zone_count": staging.get("zones", []).size(),
		"link_count": staging.get("template", {}).get("links", []).size(),
		"town_count": scenario.get("towns", []).size(),
		"mine_count": int(town_payload.get("summary", {}).get("mine_count", 0)),
		"dwelling_count": int(town_payload.get("summary", {}).get("dwelling_count", 0)),
		"artifact_count": scenario.get("artifact_nodes", []).size(),
		"route_reward_artifact_node_count": int(route_reward_summary.get("artifact_node_count", 0)),
		"encounter_count": scenario.get("encounters", []).size(),
		"associated_object_guard_count": staging.get("materialized_object_guards", []).size(),
		"object_guard_artifact_node_count_seen": int(object_guard_summary.get("artifact_node_count_seen", 0)),
		"object_guard_route_reward_artifact_count_seen": int(object_guard_summary.get("route_reward_artifact_record_count_seen", 0)),
		"object_guard_candidate_count": int(object_guard_summary.get("candidate_count", 0)),
		"object_guard_skipped_no_cell": int(object_guard_summary.get("skipped_no_cell", 0)),
		"decoration_count": int(decor.get("summary", {}).get("record_count", 0)),
		"road_tile_count": int(roads.get("summary", {}).get("tile_count", 0)),
		"road_segment_count": int(roads.get("summary", {}).get("segment_count", 0)),
		"river_candidate_count": int(rivers.get("summary", {}).get("river_candidate_count", 0)),
		"water_tile_count": int(rivers.get("summary", {}).get("water_tile_count", 0)),
		"object_instance_count": serialization.get("object_instances", []).size(),
		"minimum_town_distance_required": int(town_payload.get("summary", {}).get("minimum_town_distance_required", 0)),
		"observed_minimum_town_distance": int(town_payload.get("summary", {}).get("observed_minimum_town_distance", 0)),
	}
	var failures := _metric_failures(String(case.get("id", "")), metrics)
	return {
		"id": String(case.get("id", "")),
		"config": case,
		"metrics": metrics,
		"failures": failures,
		"validation_report": validation_report,
		"artifact_node_samples": _sample_dictionaries(scenario.get("artifact_nodes", []), 4),
		"materialized_route_reward_samples": _sample_dictionaries(staging.get("materialized_route_rewards", []), 4),
		"materialized_object_guard_samples": _sample_dictionaries(staging.get("materialized_object_guards", []), 4),
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

func _metric_failures(case_id: String, metrics: Dictionary) -> Array:
	var failures := []
	if not bool(metrics.get("ok", false)):
		failures.append("%s generation failed validation" % case_id)
	if int(metrics.get("road_tile_count", 0)) <= 0 or int(metrics.get("road_segment_count", 0)) <= 0:
		failures.append("%s has no generated road network" % case_id)
	if String(metrics.get("water_mode", "")) == "land" and int(metrics.get("river_candidate_count", 0)) <= 0:
		failures.append("%s land map has no river candidates" % case_id)
	if String(metrics.get("water_mode", "")) == "islands" and (int(metrics.get("water_tile_count", 0)) <= 0 or int(metrics.get("river_candidate_count", 0)) <= 0):
		failures.append("%s islands map has no water/river transit candidates" % case_id)
	if int(metrics.get("observed_minimum_town_distance", 0)) < int(metrics.get("minimum_town_distance_required", 0)):
		failures.append("%s town spacing %d below required %d" % [case_id, int(metrics.get("observed_minimum_town_distance", 0)), int(metrics.get("minimum_town_distance_required", 0))])
	if int(metrics.get("decoration_count", 0)) < max(8, int(metrics.get("width", 0) * metrics.get("height", 0) / 45)):
		failures.append("%s decoration/blocker density is too low: %d" % [case_id, int(metrics.get("decoration_count", 0))])
	if int(metrics.get("artifact_count", 0)) <= 0:
		failures.append("%s has no materialized artifact nodes" % case_id)
	if int(metrics.get("associated_object_guard_count", 0)) < int(metrics.get("artifact_count", 0)):
		failures.append("%s has fewer associated object guards than artifacts" % case_id)
	if int(metrics.get("encounter_count", 0)) < max(4, int(metrics.get("artifact_count", 0)) + int(metrics.get("town_count", 0))):
		failures.append("%s guard/encounter density is too low: %d" % [case_id, int(metrics.get("encounter_count", 0))])
	if int(metrics.get("object_instance_count", 0)) < int(metrics.get("town_count", 0)) + int(metrics.get("mine_count", 0)) + int(metrics.get("decoration_count", 0)):
		failures.append("%s object writeout count does not reflect placed objects" % case_id)
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
			marks[_point_key(int(tile.get("x", 0)), int(tile.get("y", 0)))] = "."
	for decor in staging.get("decoration_density_pass", {}).get("decoration_records", []):
		if decor is Dictionary:
			marks[_point_key(int(decor.get("x", 0)), int(decor.get("y", 0)))] = "#"
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
	var max_width: int = 72
	var step: int = 1
	if not rows.is_empty() and rows[0] is Array:
		step = max(1, int(ceil(float((rows[0] as Array).size()) / float(max_width))))
	var lines: Array[String] = []
	for y in range(0, rows.size(), step):
		var row: Array = rows[y]
		var chars: Array[String] = []
		for x in range(0, row.size(), step):
			var key := _point_key(x, y)
			if marks.has(key):
				chars.append(String(marks[key]))
			else:
				chars.append(_terrain_char(String(row[x])))
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
		"river_candidates": 0,
		"decorations": 0,
		"artifacts": 0,
		"encounters": 0,
		"associated_object_guards": 0,
		"object_instances": 0,
	}
	for result in results:
		if not (result is Dictionary):
			continue
		var metrics: Dictionary = result.get("metrics", {}) if result.get("metrics", {}) is Dictionary else {}
		totals["road_tiles"] = int(totals.get("road_tiles", 0)) + int(metrics.get("road_tile_count", 0))
		totals["river_candidates"] = int(totals.get("river_candidates", 0)) + int(metrics.get("river_candidate_count", 0))
		totals["decorations"] = int(totals.get("decorations", 0)) + int(metrics.get("decoration_count", 0))
		totals["artifacts"] = int(totals.get("artifacts", 0)) + int(metrics.get("artifact_count", 0))
		totals["encounters"] = int(totals.get("encounters", 0)) + int(metrics.get("encounter_count", 0))
		totals["associated_object_guards"] = int(totals.get("associated_object_guards", 0)) + int(metrics.get("associated_object_guard_count", 0))
		totals["object_instances"] = int(totals.get("object_instances", 0)) + int(metrics.get("object_instance_count", 0))
	return totals

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

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	print("%s %s" % [REPORT_ID, JSON.stringify({"ok": false, "error": message})])
	get_tree().quit(1)
