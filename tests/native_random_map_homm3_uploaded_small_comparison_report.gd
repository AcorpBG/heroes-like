extends Node

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")

const REPORT_ID := "NATIVE_RANDOM_MAP_HOMM3_UPLOADED_SMALL_COMPARISON_REPORT"
const REPORT_SCHEMA_ID := "native_random_map_homm3_uploaded_small_comparison_report_v1"

const OWNER_SMALL_BASELINE := {
	"source": "owner_uploaded_maps_small3playermap_1level_h3m_parsed_2026_05_05",
	"width": 36,
	"height": 36,
	"level_count": 1,
	"town_count": 7,
	"nearest_town_manhattan": 10,
	"object_count": 303,
	"decoration_count": 150,
	"guard_count": 40,
	"reward_count": 80,
	"road_cell_count": 110,
}

const CASES := [
	{
		"id": "legacy_compact_explicit",
		"seed": "uploaded-small-comparison-10184",
		"template_id": "border_gate_compact_v1",
		"profile_id": "border_gate_compact_profile_v1",
		"player_count": 3,
		"water_mode": "land",
		"underground": false,
		"size_class_id": "homm3_small",
	},
	{
		"id": "player_facing_small_default",
		"seed": "uploaded-small-comparison-10184",
		"template_id": "",
		"profile_id": "",
		"player_count": 3,
		"water_mode": "land",
		"underground": false,
		"size_class_id": "homm3_small",
	},
	{
		"id": "translated_small_template_049",
		"seed": "uploaded-small-comparison-10184",
		"template_id": "translated_rmg_template_049_v1",
		"profile_id": "translated_rmg_profile_049_v1",
		"player_count": 3,
		"water_mode": "land",
		"underground": false,
		"size_class_id": "homm3_small",
	},
]

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not ClassDB.class_exists("MapPackageService"):
		_fail("MapPackageService native class is not available.")
		return
	var service: Variant = ClassDB.instantiate("MapPackageService")
	var summaries := []
	for case_record in CASES:
		var summary := _run_case(service, case_record)
		if summary.is_empty():
			return
		summaries.append(summary)
	if not _assert_default_small_shape(summaries):
		return
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"schema_id": REPORT_SCHEMA_ID,
		"ok": true,
		"owner_small_baseline": OWNER_SMALL_BASELINE,
		"cases": summaries,
		"minimum_production_direction": "default small generation must use recovered translated-template scale, not the synthetic compact fixture",
	})])
	get_tree().quit(0)

func _run_case(service: Variant, case_record: Dictionary) -> Dictionary:
	var config := ScenarioSelectRulesScript.build_random_map_player_config(
		String(case_record.get("seed", "")),
		String(case_record.get("template_id", "")),
		String(case_record.get("profile_id", "")),
		int(case_record.get("player_count", 3)),
		String(case_record.get("water_mode", "land")),
		bool(case_record.get("underground", false)),
		String(case_record.get("size_class_id", "homm3_small"))
	)
	var generated: Dictionary = service.generate_random_map(config, {"startup_path": "uploaded_small_compare_%s" % String(case_record.get("id", "case"))})
	if not bool(generated.get("ok", false)):
		_fail("%s native generation did not return ok: %s" % [String(case_record.get("id", "case")), JSON.stringify(generated.get("validation_report", generated))])
		return {}
	var normalized: Dictionary = generated.get("normalized_config", {}) if generated.get("normalized_config", {}) is Dictionary else {}
	var metrics := _native_metrics(generated)
	metrics["id"] = String(case_record.get("id", "case"))
	metrics["validation_status"] = String(generated.get("validation_status", ""))
	metrics["full_generation_status"] = String(generated.get("full_generation_status", ""))
	metrics["template_id"] = String(normalized.get("template_id", ""))
	metrics["profile_id"] = String(normalized.get("profile_id", ""))
	metrics["object_count_ratio_to_owner"] = snapped(float(int(metrics.get("object_count", 0))) / float(int(OWNER_SMALL_BASELINE.get("object_count", 1))), 0.001)
	metrics["decoration_count_ratio_to_owner"] = snapped(float(int(metrics.get("decoration_count", 0))) / float(int(OWNER_SMALL_BASELINE.get("decoration_count", 1))), 0.001)
	metrics["road_cell_count_ratio_to_owner"] = snapped(float(int(metrics.get("road_cell_count", 0))) / float(int(OWNER_SMALL_BASELINE.get("road_cell_count", 1))), 0.001)
	return metrics

func _assert_default_small_shape(summaries: Array) -> bool:
	var default_summary := {}
	for summary in summaries:
		if summary is Dictionary and String(summary.get("id", "")) == "player_facing_small_default":
			default_summary = summary
			break
	if default_summary.is_empty():
		_fail("Missing player_facing_small_default summary: %s" % JSON.stringify(summaries))
		return false
	if String(default_summary.get("template_id", "")) != "translated_rmg_template_049_v1":
		_fail("Small player-facing default did not use the recovered template 049: %s" % JSON.stringify(default_summary))
		return false
	if int(default_summary.get("town_count", 0)) < int(OWNER_SMALL_BASELINE.get("town_count", 0)):
		_fail("Small default did not preserve owner-like town count: %s" % JSON.stringify(default_summary))
		return false
	if int(default_summary.get("nearest_town_manhattan", 0)) < 8:
		_fail("Small default town spacing is too tight: %s" % JSON.stringify(default_summary))
		return false
	if float(default_summary.get("object_count_ratio_to_owner", 0.0)) < 0.90:
		_fail("Small default object density is still far below owner baseline: %s" % JSON.stringify(default_summary))
		return false
	if float(default_summary.get("decoration_count_ratio_to_owner", 0.0)) < 0.80 or float(default_summary.get("decoration_count_ratio_to_owner", 0.0)) > 1.20:
		_fail("Small default decoration density drifted outside owner-like tolerance: %s" % JSON.stringify(default_summary))
		return false
	if float(default_summary.get("road_cell_count_ratio_to_owner", 0.0)) < 0.90:
		_fail("Small default road materialization is still below owner-like baseline: %s" % JSON.stringify(default_summary))
		return false
	if int(default_summary.get("guard_record_count", 0)) < int(OWNER_SMALL_BASELINE.get("guard_count", 0)):
		_fail("Small default guard count is below owner baseline: %s" % JSON.stringify(default_summary))
		return false
	return true

func _native_metrics(generated: Dictionary) -> Dictionary:
	var terrain_grid: Dictionary = generated.get("terrain_grid", {}) if generated.get("terrain_grid", {}) is Dictionary else {}
	var object_placements: Array = generated.get("object_placements", []) if generated.get("object_placements", []) is Array else []
	var town_records: Array = generated.get("town_records", []) if generated.get("town_records", []) is Array else []
	var guard_records: Array = generated.get("guard_records", []) if generated.get("guard_records", []) is Array else []
	var road_network: Dictionary = generated.get("road_network", {}) if generated.get("road_network", {}) is Dictionary else {}
	var zone_layout: Dictionary = generated.get("zone_layout", {}) if generated.get("zone_layout", {}) is Dictionary else {}
	var counts := {}
	for object in object_placements:
		if not (object is Dictionary):
			continue
		var kind := String(object.get("kind", "object"))
		counts[kind] = int(counts.get(kind, 0)) + 1
	var road_cells := {}
	for segment in road_network.get("road_segments", []):
		if not (segment is Dictionary):
			continue
		for cell in segment.get("cells", []):
			if cell is Dictionary:
				road_cells["%d,%d" % [int(cell.get("x", 0)), int(cell.get("y", 0))]] = true
	var town_points := []
	for town in town_records:
		if town is Dictionary:
			town_points.append(Vector2i(int(town.get("x", 0)), int(town.get("y", 0))))
	return {
		"width": int(terrain_grid.get("width", 0)),
		"height": int(terrain_grid.get("height", 0)),
		"level_count": int(terrain_grid.get("level_count", 1)),
		"zone_count": int(zone_layout.get("zone_count", 0)),
		"town_count": town_records.size(),
		"nearest_town_manhattan": _nearest_town_manhattan(town_points),
		"object_count": object_placements.size(),
		"decoration_count": int(counts.get("decorative_obstacle", 0)),
		"guard_object_count": int(counts.get("route_guard", 0)) + int(counts.get("special_guard_gate", 0)) + int(counts.get("connection_gate", 0)),
		"guard_record_count": guard_records.size(),
		"reward_count": int(counts.get("reward_reference", 0)) + int(counts.get("resource_site", 0)) + int(counts.get("mine", 0)) + int(counts.get("neutral_dwelling", 0)),
		"road_cell_count": road_cells.size(),
		"road_segment_count": int(road_network.get("road_segments", []).size()) if road_network.get("road_segments", []) is Array else 0,
		"object_counts_by_kind": counts,
	}

func _nearest_town_manhattan(points: Array) -> int:
	if points.size() < 2:
		return 0
	var best := 999999
	for left_index in range(points.size()):
		var left: Vector2i = points[left_index]
		for right_index in range(left_index + 1, points.size()):
			var right: Vector2i = points[right_index]
			best = min(best, abs(left.x - right.x) + abs(left.y - right.y))
	return best

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"schema_id": REPORT_SCHEMA_ID,
		"ok": false,
		"error": message,
	})])
	get_tree().quit(1)
