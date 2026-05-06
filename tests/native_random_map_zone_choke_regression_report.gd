extends Node

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")

const REPORT_ID := "NATIVE_RANDOM_MAP_ZONE_CHOKE_REGRESSION_REPORT"
const REPORT_SCHEMA_ID := "native_random_map_zone_choke_regression_report_v1"
const CASES := [
	{
		"id": "small_supported_land",
		"seed": "zone-choke-small-default-10184",
		"template_id": "border_gate_compact_v1",
		"profile_id": "border_gate_compact_profile_v1",
		"player_count": 3,
		"expected_start_towns": 3,
		"water_mode": "land",
		"size_class_id": "homm3_small",
	},
	{
		"id": "small_translated_049_3p_land",
		"seed": "uploaded-small-comparison-10184",
		"template_id": "translated_rmg_template_049_v1",
		"profile_id": "translated_rmg_profile_049_v1",
		"player_count": 3,
		"expected_start_towns": 3,
		"expected_total_towns": 7,
		"water_mode": "land",
		"size_class_id": "homm3_small",
	},
	{
		"id": "medium_translated_4p_land",
		"seed": "zone-choke-medium-translated-10184",
		"template_id": "translated_rmg_template_002_v1",
		"profile_id": "translated_rmg_profile_002_v1",
		"player_count": 4,
		"expected_start_towns": 4,
		"water_mode": "land",
		"size_class_id": "homm3_medium",
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
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"schema_id": REPORT_SCHEMA_ID,
		"ok": true,
		"cases": summaries,
	})])
	get_tree().quit(0)

func _run_case(service: Variant, case_record: Dictionary) -> Dictionary:
	var config := ScenarioSelectRulesScript.build_random_map_player_config(
		String(case_record.get("seed", "")),
		String(case_record.get("template_id", "")),
		String(case_record.get("profile_id", "")),
		int(case_record.get("player_count", 3)),
		String(case_record.get("water_mode", "land")),
		false,
		String(case_record.get("size_class_id", "homm3_small"))
	)
	var case_id := String(case_record.get("id", "case"))
	var generated: Dictionary = service.generate_random_map(config, {"startup_path": "zone_choke_%s" % case_id})
	if not bool(generated.get("ok", false)) or String(generated.get("validation_status", "")) != "pass":
		var town_guard_placement: Dictionary = generated.get("town_guard_placement", {}) if generated.get("town_guard_placement", {}) is Dictionary else {}
		var town_placement: Dictionary = town_guard_placement.get("town_placement", {}) if town_guard_placement.get("town_placement", {}) is Dictionary else {}
		_fail("%s generation failed validation: %s" % [case_id, JSON.stringify({
			"validation_report": generated.get("validation_report", generated),
			"town_records": generated.get("town_records", []),
			"town_diagnostics": town_placement.get("diagnostics", []),
		})])
		return {}
	var terrain_grid: Dictionary = generated.get("terrain_grid", {}) if generated.get("terrain_grid", {}) is Dictionary else {}
	var boundary_shape: Dictionary = terrain_grid.get("land_boundary_shape", {}) if terrain_grid.get("land_boundary_shape", {}) is Dictionary else {}
	if not bool(boundary_shape.get("enabled", false)):
		_fail("%s land boundary barrier shape was not enabled: %s" % [case_id, JSON.stringify(boundary_shape)])
		return {}
	var unresolved_blocked := _blocked_tiles(generated, true)
	var cleared_connection_blocked := _blocked_tiles(generated, false)
	var towns: Array = generated.get("town_records", []) if generated.get("town_records", []) is Array else []
	var start_towns := []
	for town in towns:
		if town is Dictionary and String(town.get("record_type", "")) == "player_start_town":
			start_towns.append(town)
	if case_record.has("expected_start_towns"):
		var expected_start_towns := int(case_record.get("expected_start_towns", 0))
		if start_towns.size() != expected_start_towns:
			_fail("%s expected exactly %d player start towns, got %d: %s" % [case_id, expected_start_towns, start_towns.size(), JSON.stringify(towns)])
			return {}
	if start_towns.size() < 2:
		_fail("%s needs at least two player start towns for choke traversal validation: %s" % [case_id, JSON.stringify(towns)])
		return {}
	if case_record.has("expected_total_towns"):
		var expected_total_towns := int(case_record.get("expected_total_towns", 0))
		if towns.size() != expected_total_towns:
			_fail("%s expected exactly %d total towns, got %d: %s" % [case_id, expected_total_towns, towns.size(), JSON.stringify(towns)])
			return {}
	var unresolved_reachable_pairs := []
	var cleared_blocked_pairs := []
	for left_index in range(start_towns.size()):
		for right_index in range(left_index + 1, start_towns.size()):
			var left: Dictionary = start_towns[left_index]
			var right: Dictionary = start_towns[right_index]
			var left_point := Vector2i(int(left.get("x", 0)), int(left.get("y", 0)))
			var right_point := Vector2i(int(right.get("x", 0)), int(right.get("y", 0)))
			if _has_path(unresolved_blocked.duplicate(true), terrain_grid, left_point, right_point):
				unresolved_reachable_pairs.append([_brief_town(left), _brief_town(right)])
			if not _has_path(cleared_connection_blocked.duplicate(true), terrain_grid, left_point, right_point):
				cleared_blocked_pairs.append([_brief_town(left), _brief_town(right)])
	if not unresolved_reachable_pairs.is_empty():
		_fail("%s unresolved guards/obstacles still allow start-town traversal: %s; guards=%s" % [case_id, JSON.stringify(unresolved_reachable_pairs), JSON.stringify(_guard_brief(generated))])
		return {}
	if not cleared_blocked_pairs.is_empty():
		_fail("%s cleared connection guards/gates do not restore start-town traversal: %s; guards=%s" % [case_id, JSON.stringify(cleared_blocked_pairs), JSON.stringify(_guard_brief(generated))])
		return {}
	var cross_zone_town_failures := _cross_zone_town_route_failures(towns, unresolved_blocked, cleared_connection_blocked, terrain_grid)
	if not case_record.has("expected_total_towns"):
		return {
			"id": case_id,
			"town_count": start_towns.size(),
			"total_town_count": towns.size(),
			"cross_zone_town_pair_count": int(cross_zone_town_failures.get("cross_zone_pair_count", 0)),
			"guard_count": int(generated.get("guard_records", []).size()),
			"unresolved_blocked_tile_count": unresolved_blocked.size(),
			"cleared_connection_blocked_tile_count": cleared_connection_blocked.size(),
			"land_boundary_shape": boundary_shape,
		}
	if not cross_zone_town_failures.get("unresolved_reachable_pairs", []).is_empty():
		_fail("%s unresolved guards/obstacles still allow cross-zone town traversal: %s; guards=%s" % [case_id, JSON.stringify(cross_zone_town_failures.get("unresolved_reachable_pairs", [])), JSON.stringify(_guard_brief(generated))])
		return {}
	if not cross_zone_town_failures.get("cleared_blocked_pairs", []).is_empty():
		var object_placement: Dictionary = generated.get("object_placement", {}) if generated.get("object_placement", {}) is Dictionary else {}
		_fail("%s cleared connection guards/gates do not restore all cross-zone town traversal: %s; corridor_clearance=%s; corridor_blockers=%s; town_corridors=%s; guards=%s" % [
			case_id,
			JSON.stringify(cross_zone_town_failures.get("cleared_blocked_pairs", [])),
			JSON.stringify(object_placement.get("required_town_access_corridor_clearance", {})),
			JSON.stringify(_corridor_blockers(generated, towns)),
			JSON.stringify(_town_corridor_brief(towns)),
			JSON.stringify(_guard_brief(generated)),
		])
		return {}
	return {
		"id": case_id,
		"town_count": start_towns.size(),
		"total_town_count": towns.size(),
		"cross_zone_town_pair_count": int(cross_zone_town_failures.get("cross_zone_pair_count", 0)),
		"guard_count": int(generated.get("guard_records", []).size()),
		"unresolved_blocked_tile_count": unresolved_blocked.size(),
		"cleared_connection_blocked_tile_count": cleared_connection_blocked.size(),
		"land_boundary_shape": boundary_shape,
	}

func _cross_zone_town_route_failures(towns: Array, unresolved_blocked: Dictionary, cleared_connection_blocked: Dictionary, terrain_grid: Dictionary) -> Dictionary:
	var unresolved_reachable_pairs := []
	var cleared_blocked_pairs := []
	var cross_zone_pair_count := 0
	for left_index in range(towns.size()):
		if not (towns[left_index] is Dictionary):
			continue
		for right_index in range(left_index + 1, towns.size()):
			if not (towns[right_index] is Dictionary):
				continue
			var left: Dictionary = towns[left_index]
			var right: Dictionary = towns[right_index]
			if String(left.get("zone_id", "")) == String(right.get("zone_id", "")):
				continue
			cross_zone_pair_count += 1
			var left_point := Vector2i(int(left.get("x", 0)), int(left.get("y", 0)))
			var right_point := Vector2i(int(right.get("x", 0)), int(right.get("y", 0)))
			if _has_path(unresolved_blocked.duplicate(true), terrain_grid, left_point, right_point):
				unresolved_reachable_pairs.append([_brief_town(left), _brief_town(right)])
			if not _has_path(cleared_connection_blocked.duplicate(true), terrain_grid, left_point, right_point):
				cleared_blocked_pairs.append([_brief_town(left), _brief_town(right)])
	return {
		"cross_zone_pair_count": cross_zone_pair_count,
		"unresolved_reachable_pairs": unresolved_reachable_pairs,
		"cleared_blocked_pairs": cleared_blocked_pairs,
	}

func _blocked_tiles(generated: Dictionary, include_connection_blockers: bool) -> Dictionary:
	var blocked := {}
	var terrain_grid: Dictionary = generated.get("terrain_grid", {}) if generated.get("terrain_grid", {}) is Dictionary else {}
	var ids_by_code: Variant = terrain_grid.get("terrain_id_by_code", [])
	var levels: Array = terrain_grid.get("levels", []) if terrain_grid.get("levels", []) is Array else []
	var level: Dictionary = levels[0] if not levels.is_empty() and levels[0] is Dictionary else {}
	var width := int(terrain_grid.get("width", 0))
	var height := int(terrain_grid.get("height", 0))
	var codes: PackedInt32Array = level.get("terrain_code_u16", PackedInt32Array())
	for y in range(height):
		for x in range(width):
			var index := y * width + x
			var terrain_id := _terrain_id_for_code(ids_by_code, int(codes[index]) if index >= 0 and index < codes.size() else 0)
			if terrain_id in ["rock", "water"]:
				blocked["%d,%d" % [x, y]] = true
	for object in generated.get("object_placements", []):
		if object is Dictionary:
			var kind := String(object.get("kind", ""))
			var type_id := String(object.get("type_id", ""))
			if not include_connection_blockers and (kind == "special_guard_gate" or kind == "connection_gate" or type_id == "special_guard_gate"):
				continue
			var passability: Dictionary = object.get("passability", {}) if object.get("passability", {}) is Dictionary else {}
			if String(passability.get("class", "")) in ["blocking_non_visitable", "blocking_visitable", "edge_blocker"]:
				_mark_body(blocked, object)
	if include_connection_blockers:
		for guard in generated.get("guard_records", []):
			if guard is Dictionary:
				_mark_body(blocked, guard)
	return blocked

func _mark_body(blocked: Dictionary, record: Dictionary) -> void:
	var body_tiles: Array = record.get("body_tiles", []) if record.get("body_tiles", []) is Array else []
	if body_tiles.is_empty():
		blocked["%d,%d" % [int(record.get("x", 0)), int(record.get("y", 0))]] = true
	for body in body_tiles:
		if body is Dictionary:
			blocked["%d,%d" % [int(body.get("x", 0)), int(body.get("y", 0))]] = true

func _terrain_id_for_code(ids_by_code: Variant, code: int) -> String:
	if (ids_by_code is Array or ids_by_code is PackedStringArray) and code >= 0 and code < ids_by_code.size():
		return String(ids_by_code[code])
	return "grass"

func _has_path(blocked: Dictionary, terrain_grid: Dictionary, start: Vector2i, goal: Vector2i) -> bool:
	var width := int(terrain_grid.get("width", 0))
	var height := int(terrain_grid.get("height", 0))
	blocked.erase("%d,%d" % [start.x, start.y])
	blocked.erase("%d,%d" % [goal.x, goal.y])
	var queue := [start]
	var seen := {"%d,%d" % [start.x, start.y]: true}
	var cursor := 0
	var dirs := [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1),
	]
	while cursor < queue.size():
		var current: Vector2i = queue[cursor]
		cursor += 1
		if current == goal:
			return true
		for dir_value in dirs:
			var dir: Vector2i = dir_value
			var next: Vector2i = current + dir
			if next.x < 0 or next.y < 0 or next.x >= width or next.y >= height:
				continue
			var key := "%d,%d" % [next.x, next.y]
			if seen.has(key) or blocked.has(key):
				continue
			seen[key] = true
			queue.append(next)
	return false

func _brief_town(town: Dictionary) -> Dictionary:
	return {
		"placement_id": String(town.get("placement_id", "")),
		"zone_id": String(town.get("zone_id", "")),
		"x": int(town.get("x", 0)),
		"y": int(town.get("y", 0)),
	}

func _town_corridor_brief(towns: Array) -> Array:
	var result := []
	for town in towns:
		if town is Dictionary:
			var corridor: Array = town.get("required_town_access_corridor_cells", []) if town.get("required_town_access_corridor_cells", []) is Array else []
			result.append({
				"placement_id": String(town.get("placement_id", "")),
				"zone_id": String(town.get("zone_id", "")),
				"x": int(town.get("x", 0)),
				"y": int(town.get("y", 0)),
				"access_anchor": town.get("required_town_access_anchor", {}),
				"corridor_cell_count": corridor.size(),
			})
	return result

func _corridor_blockers(generated: Dictionary, towns: Array) -> Array:
	var corridor_tiles := {}
	for town in towns:
		if not (town is Dictionary):
			continue
		for cell in town.get("required_town_access_corridor_cells", []):
			if cell is Dictionary:
				corridor_tiles["%d,%d" % [int(cell.get("x", 0)), int(cell.get("y", 0))]] = String(town.get("placement_id", ""))
	var result := []
	var terrain_grid: Dictionary = generated.get("terrain_grid", {}) if generated.get("terrain_grid", {}) is Dictionary else {}
	var ids_by_code: Variant = terrain_grid.get("terrain_id_by_code", [])
	var levels: Array = terrain_grid.get("levels", []) if terrain_grid.get("levels", []) is Array else []
	var level: Dictionary = levels[0] if not levels.is_empty() and levels[0] is Dictionary else {}
	var width := int(terrain_grid.get("width", 0))
	var codes: PackedInt32Array = level.get("terrain_code_u16", PackedInt32Array())
	for key in corridor_tiles.keys():
		var parts := String(key).split(",")
		var x := int(parts[0])
		var y := int(parts[1])
		var index := y * width + x
		var terrain_id := _terrain_id_for_code(ids_by_code, int(codes[index]) if index >= 0 and index < codes.size() else 0)
		if terrain_id in ["rock", "water"]:
			result.append({"kind": "terrain", "terrain_id": terrain_id, "x": x, "y": y, "town": corridor_tiles[key]})
	for object in generated.get("object_placements", []):
		if not (object is Dictionary):
			continue
		var passability: Dictionary = object.get("passability", {}) if object.get("passability", {}) is Dictionary else {}
		if not (String(passability.get("class", "")) in ["blocking_non_visitable", "blocking_visitable", "edge_blocker"]):
			continue
		for body in object.get("body_tiles", []):
			if body is Dictionary:
				var key := "%d,%d" % [int(body.get("x", 0)), int(body.get("y", 0))]
				if corridor_tiles.has(key):
					result.append({
						"kind": String(object.get("kind", "")),
						"placement_id": String(object.get("placement_id", "")),
						"passability": passability,
						"x": int(body.get("x", 0)),
						"y": int(body.get("y", 0)),
						"town": corridor_tiles[key],
					})
	return result

func _guard_brief(generated: Dictionary) -> Array:
	var result := []
	for guard in generated.get("guard_records", []):
		if guard is Dictionary:
			result.append({
				"guard_kind": String(guard.get("guard_kind", "")),
				"route_edge_id": String(guard.get("route_edge_id", "")),
				"x": int(guard.get("x", 0)),
				"y": int(guard.get("y", 0)),
				"body_tile_count": int(guard.get("body_tiles", []).size() if guard.get("body_tiles", []) is Array else 0),
			})
	return result

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
