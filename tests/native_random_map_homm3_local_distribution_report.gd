extends Node

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")

const REPORT_ID := "NATIVE_RANDOM_MAP_HOMM3_LOCAL_DISTRIBUTION_REPORT"
const REPORT_SCHEMA_ID := "native_random_map_homm3_local_distribution_report_v1"

const OWNER_CASE := {
	"id": "owner_like_medium_small_ring_islands",
	"seed": "1777897383",
	"template_id": "translated_rmg_template_001_v1",
	"profile_id": "translated_rmg_profile_001_v1",
	"player_count": 4,
	"water_mode": "islands",
	"underground": false,
	"size_class_id": "homm3_medium",
}

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

	var native := _generate_native_owner_like(service)
	if native.is_empty():
		return
	var gate := _gate_summary(native)
	if String(gate.get("status", "")) != "pass":
		_fail("Local distribution gate failed: %s" % JSON.stringify(gate))
		return

	print("%s %s" % [REPORT_ID, JSON.stringify({
		"schema_id": REPORT_SCHEMA_ID,
		"ok": true,
		"binding_kind": metadata.get("binding_kind", ""),
		"native_extension_loaded": metadata.get("native_extension_loaded", false),
		"native_owner_like": native,
		"gate": gate,
		"remaining_gap": "This report gates local distribution quality for the owner-like native 72x72 islands case. It is not exact HoMM3-re placement, object-table, asset, byte, or full parity.",
	})])
	get_tree().quit(0)

func _generate_native_owner_like(service: Variant) -> Dictionary:
	var config := ScenarioSelectRulesScript.build_random_map_player_config(
		String(OWNER_CASE.get("seed", "")),
		String(OWNER_CASE.get("template_id", "")),
		String(OWNER_CASE.get("profile_id", "")),
		int(OWNER_CASE.get("player_count", 4)),
		String(OWNER_CASE.get("water_mode", "islands")),
		bool(OWNER_CASE.get("underground", false)),
		String(OWNER_CASE.get("size_class_id", "homm3_medium"))
	)
	var generated: Dictionary = service.generate_random_map(config, {"startup_path": "homm3_local_distribution_report"})
	if not bool(generated.get("ok", false)) or String(generated.get("validation_status", "")) != "pass":
		_fail("Native owner-like generation failed validation: %s" % JSON.stringify(generated.get("validation_report", generated)))
		return {}
	var normalized: Dictionary = generated.get("normalized_config", {}) if generated.get("normalized_config", {}) is Dictionary else {}
	var width := int(normalized.get("width", 0))
	var height := int(normalized.get("height", 0))
	var land_lookup := _native_land_lookup(generated, width, height)
	var records := _native_local_records(generated)
	var points_by_kind := _points_by_kind(records)
	return {
		"id": "native_owner_like",
		"seed": String(normalized.get("normalized_seed", "")),
		"template_id": String(normalized.get("template_id", "")),
		"profile_id": String(normalized.get("profile_id", "")),
		"water_mode": String(normalized.get("water_mode", "")),
		"width": width,
		"height": height,
		"land_tile_count": land_lookup.size(),
		"object_count": records.size(),
		"counts_by_kind": _counts_by_kind(records),
		"window_12_step_6": _sliding_window_metrics(width, height, land_lookup, points_by_kind, 12, 6),
		"coarse_land_region_6x6": _largest_low_content_land_region(width, height, land_lookup, points_by_kind.get("interactive_guard", []), 6, 6, 1),
		"nearest_neighbor": _nearest_neighbor_summary(points_by_kind),
		"fill_coverage_summary": generated.get("fill_coverage_summary", {}),
		"decoration_route_shaping_summary": generated.get("decoration_route_shaping_summary", {}),
		"materialized_object_guard_summary": generated.get("materialized_object_guard_summary", {}),
		"spatial_policy_counts": _spatial_policy_counts(generated),
	}

func _native_local_records(generated: Dictionary) -> Array:
	var result := []
	var guarded_ids := {}
	var guards: Array = generated.get("guard_records", []) if generated.get("guard_records", []) is Array else []
	for guard in guards:
		if guard is Dictionary:
			var protected_id := String(guard.get("protected_object_placement_id", ""))
			if protected_id != "":
				guarded_ids[protected_id] = true
	var objects: Array = generated.get("object_placements", []) if generated.get("object_placements", []) is Array else []
	for object in objects:
		if not (object is Dictionary):
			continue
		var kind := String(object.get("kind", "object"))
		var category := "object"
		if kind == "decorative_obstacle":
			category = "decoration"
		elif kind in ["resource_site", "mine", "neutral_dwelling", "reward_reference"]:
			category = "interactive"
		var placement_id := String(object.get("placement_id", ""))
		result.append({
			"x": int(object.get("x", 0)),
			"y": int(object.get("y", 0)),
			"kind": category,
			"source_kind": kind,
			"placement_id": placement_id,
			"guarded_package": guarded_ids.has(placement_id),
		})
	var towns: Array = generated.get("town_records", []) if generated.get("town_records", []) is Array else []
	for town in towns:
		if town is Dictionary:
			result.append({"x": int(town.get("x", 0)), "y": int(town.get("y", 0)), "kind": "town", "source_kind": "town", "placement_id": String(town.get("placement_id", "")), "guarded_package": false})
	for guard in guards:
		if guard is Dictionary:
			result.append({"x": int(guard.get("x", 0)), "y": int(guard.get("y", 0)), "kind": "guard", "source_kind": String(guard.get("guard_kind", "guard")), "placement_id": String(guard.get("placement_id", "")), "guarded_package": String(guard.get("protected_object_placement_id", "")) != ""})
	return result

func _points_by_kind(records: Array) -> Dictionary:
	var result := {
		"all_content": [],
		"decoration": [],
		"interactive": [],
		"guard": [],
		"town": [],
		"interactive_guard": [],
		"guarded_package": [],
	}
	for record in records:
		if not (record is Dictionary):
			continue
		var point := _point(int(record.get("x", 0)), int(record.get("y", 0)))
		var kind := String(record.get("kind", "object"))
		result["all_content"].append(point)
		if result.has(kind):
			result[kind].append(point)
		if kind == "interactive" or kind == "guard":
			result["interactive_guard"].append(point)
		if bool(record.get("guarded_package", false)):
			result["guarded_package"].append(point)
	return result

func _sliding_window_metrics(width: int, height: int, land_lookup: Dictionary, points_by_kind: Dictionary, window_size: int, step: int) -> Dictionary:
	var windows := []
	var land_counts := []
	var interactive_counts := []
	var interactive_guard_counts := []
	var guarded_package_counts := []
	var low_content_windows := 0
	var empty_interactive_windows := 0
	var total_windows := 0
	for y in range(0, max(1, height - window_size + 1), step):
		for x in range(0, max(1, width - window_size + 1), step):
			var land_count := _land_count_in_window(land_lookup, x, y, window_size)
			if land_count < max(8, int(window_size * window_size * 0.25)):
				continue
			total_windows += 1
			var interactive_count := _point_count_in_window(points_by_kind.get("interactive", []), x, y, window_size)
			var guard_count := _point_count_in_window(points_by_kind.get("guard", []), x, y, window_size)
			var interactive_guard_count := interactive_count + guard_count
			var package_count := _point_count_in_window(points_by_kind.get("guarded_package", []), x, y, window_size)
			if interactive_count == 0:
				empty_interactive_windows += 1
			if interactive_guard_count <= 1:
				low_content_windows += 1
			land_counts.append(land_count)
			interactive_counts.append(interactive_count)
			interactive_guard_counts.append(interactive_guard_count)
			guarded_package_counts.append(package_count)
			windows.append({
				"x": x,
				"y": y,
				"land": land_count,
				"interactive": interactive_count,
				"guard": guard_count,
				"interactive_guard": interactive_guard_count,
				"guarded_package": package_count,
			})
	return {
		"window_size": window_size,
		"step": step,
		"land_window_count": total_windows,
		"empty_interactive_window_count": empty_interactive_windows,
		"empty_interactive_window_ratio": snapped(float(empty_interactive_windows) / float(max(1, total_windows)), 0.0001),
		"low_interactive_guard_window_count": low_content_windows,
		"low_interactive_guard_window_ratio": snapped(float(low_content_windows) / float(max(1, total_windows)), 0.0001),
		"land": _distribution_summary_from_counts(land_counts),
		"interactive": _distribution_summary_from_counts(interactive_counts),
		"interactive_guard": _distribution_summary_from_counts(interactive_guard_counts),
		"guarded_package": _distribution_summary_from_counts(guarded_package_counts),
		"worst_pile_windows": _top_windows(windows, "interactive_guard", 5),
		"worst_guarded_package_windows": _top_windows(windows, "guarded_package", 5),
	}

func _largest_low_content_land_region(width: int, height: int, land_lookup: Dictionary, content_points: Array, cols: int, rows: int, max_content_count: int) -> Dictionary:
	var counts := []
	var land_counts := []
	for _index in range(cols * rows):
		counts.append(0)
		land_counts.append(0)
	for key in land_lookup.keys():
		var parts := String(key).split(",")
		if parts.size() != 2:
			continue
		var x := int(parts[0])
		var y := int(parts[1])
		var cx = clampi(int(floor(float(x) * float(cols) / float(max(1, width)))), 0, cols - 1)
		var cy = clampi(int(floor(float(y) * float(rows) / float(max(1, height)))), 0, rows - 1)
		land_counts[cy * cols + cx] = int(land_counts[cy * cols + cx]) + 1
	for point in content_points:
		if not (point is Dictionary):
			continue
		var cx = clampi(int(floor(float(int(point.get("x", 0))) * float(cols) / float(max(1, width)))), 0, cols - 1)
		var cy = clampi(int(floor(float(int(point.get("y", 0))) * float(rows) / float(max(1, height)))), 0, rows - 1)
		counts[cy * cols + cx] = int(counts[cy * cols + cx]) + 1
	var visited := {}
	var largest := 0
	for y in range(rows):
		for x in range(cols):
			var key := _point_key(x, y)
			var index := y * cols + x
			if visited.has(key) or int(land_counts[index]) <= 0 or int(counts[index]) > max_content_count:
				continue
			var size := 0
			var queue := [_point(x, y)]
			visited[key] = true
			while not queue.is_empty():
				var current: Dictionary = queue.pop_front()
				size += 1
				for offset in [_point(1, 0), _point(-1, 0), _point(0, 1), _point(0, -1)]:
					var nx := int(current.get("x", 0)) + int(offset.get("x", 0))
					var ny := int(current.get("y", 0)) + int(offset.get("y", 0))
					if nx < 0 or ny < 0 or nx >= cols or ny >= rows:
						continue
					var nkey := _point_key(nx, ny)
					var nindex := ny * cols + nx
					if visited.has(nkey) or int(land_counts[nindex]) <= 0 or int(counts[nindex]) > max_content_count:
						continue
					visited[nkey] = true
					queue.append(_point(nx, ny))
			largest = max(largest, size)
	return {
		"cols": cols,
		"rows": rows,
		"max_content_count": max_content_count,
		"largest_region_cell_count": largest,
		"largest_region_ratio": snapped(float(largest) / float(max(1, cols * rows)), 0.0001),
		"content_counts": counts,
		"land_counts": land_counts,
	}

func _nearest_neighbor_summary(points_by_kind: Dictionary) -> Dictionary:
	var result := {}
	for kind in points_by_kind.keys():
		var points: Array = points_by_kind.get(kind, [])
		var distances := []
		for index in range(points.size()):
			var best := 999999
			for other_index in range(points.size()):
				if index == other_index:
					continue
				var distance := _manhattan(points[index], points[other_index])
				if distance < best:
					best = distance
			if best < 999999:
				distances.append(best)
		var summary := _distribution_summary_from_counts(distances)
		summary["average_nearest_neighbor"] = summary.get("average", 0.0)
		summary["close_pair_ratio_le_2"] = _ratio_lte(distances, 2)
		summary["close_pair_ratio_le_4"] = _ratio_lte(distances, 4)
		result[kind] = summary
	return result

func _gate_summary(native: Dictionary) -> Dictionary:
	var window: Dictionary = native.get("window_12_step_6", {})
	var interactive: Dictionary = window.get("interactive", {}) if window.get("interactive", {}) is Dictionary else {}
	var interactive_guard: Dictionary = window.get("interactive_guard", {}) if window.get("interactive_guard", {}) is Dictionary else {}
	var package_window: Dictionary = window.get("guarded_package", {}) if window.get("guarded_package", {}) is Dictionary else {}
	var nearest: Dictionary = native.get("nearest_neighbor", {}) if native.get("nearest_neighbor", {}) is Dictionary else {}
	var failures := []
	if int(native.get("object_count", 0)) < 450:
		failures.append("native_object_count_regressed")
	if float(window.get("empty_interactive_window_ratio", 1.0)) > 0.34:
		failures.append("too_many_empty_interactive_land_windows")
	if float(window.get("low_interactive_guard_window_ratio", 1.0)) > 0.24:
		failures.append("too_many_low_content_land_windows")
	if int(interactive_guard.get("max", 99)) > 28:
		failures.append("interactive_guard_window_pile_too_large")
	if int(interactive.get("max", 99)) > 20:
		failures.append("interactive_window_pile_too_large")
	if int(package_window.get("max", 99)) > 14:
		failures.append("guarded_package_window_pile_too_large")
	if float(interactive.get("coefficient_of_variation", 99.0)) > 1.05:
		failures.append("interactive_window_density_spread_too_high")
	if int(native.get("coarse_land_region_6x6", {}).get("largest_region_cell_count", 99)) > 4:
		failures.append("largest_low_content_land_region_too_large")
	if _nested_float(nearest, "interactive", "average_nearest_neighbor") < 2.35:
		failures.append("interactive_objects_too_tightly_spaced")
	if _nested_float(nearest, "interactive_guard", "close_pair_ratio_le_2") > 0.85:
		failures.append("interactive_guard_close_pair_ratio_too_high")
	return {
		"status": "pass" if failures.is_empty() else "fail",
		"failures": failures,
		"thresholds": {
			"native_min_object_count": 450,
			"max_empty_interactive_window_ratio": 0.34,
			"max_low_interactive_guard_window_ratio": 0.24,
			"max_interactive_guard_window_count": 28,
			"max_interactive_window_count": 20,
			"max_guarded_package_window_count": 14,
			"max_interactive_density_cv": 1.05,
			"max_largest_low_content_land_region_6x6": 4,
			"min_interactive_average_nearest_neighbor": 2.35,
			"max_interactive_guard_close_pair_ratio_le_2": 0.85,
		},
		"snapshot": {
			"object_count": native.get("object_count", 0),
			"empty_interactive_window_ratio": window.get("empty_interactive_window_ratio", 0.0),
			"low_interactive_guard_window_ratio": window.get("low_interactive_guard_window_ratio", 0.0),
			"interactive_window_max": interactive.get("max", 0),
			"interactive_guard_window_max": interactive_guard.get("max", 0),
			"guarded_package_window_max": package_window.get("max", 0),
			"interactive_density_cv": interactive.get("coefficient_of_variation", 0.0),
			"largest_low_content_land_region": native.get("coarse_land_region_6x6", {}).get("largest_region_cell_count", 0),
			"interactive_average_nearest_neighbor": _nested_float(nearest, "interactive", "average_nearest_neighbor"),
			"interactive_guard_close_pair_ratio_le_2": _nested_float(nearest, "interactive_guard", "close_pair_ratio_le_2"),
		},
	}

func _native_land_lookup(generated: Dictionary, width: int, height: int) -> Dictionary:
	var land := {}
	var grid: Dictionary = generated.get("terrain_grid", {}) if generated.get("terrain_grid", {}) is Dictionary else {}
	var ids: PackedStringArray = grid.get("terrain_id_by_code", PackedStringArray())
	var levels: Array = grid.get("levels", []) if grid.get("levels", []) is Array else []
	if levels.is_empty() or ids.is_empty():
		for y in range(height):
			for x in range(width):
				land[_point_key(x, y)] = true
		return land
	var level: Dictionary = levels[0]
	var codes: PackedInt32Array = level.get("terrain_code_u16", PackedInt32Array())
	for index in range(min(codes.size(), width * height)):
		var code := int(codes[index])
		var terrain_id := String(ids[code]) if code >= 0 and code < ids.size() else "grass"
		if terrain_id != "water":
			land[_point_key(index % width, index / width)] = true
	return land

func _land_count_in_window(land_lookup: Dictionary, x: int, y: int, size: int) -> int:
	var count := 0
	for yy in range(y, y + size):
		for xx in range(x, x + size):
			if land_lookup.has(_point_key(xx, yy)):
				count += 1
	return count

func _point_count_in_window(points: Array, x: int, y: int, size: int) -> int:
	var count := 0
	for point in points:
		if point is Dictionary:
			var px := int(point.get("x", 0))
			var py := int(point.get("y", 0))
			if px >= x and px < x + size and py >= y and py < y + size:
				count += 1
	return count

func _top_windows(windows: Array, key: String, limit: int) -> Array:
	windows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get(key, 0)) == int(b.get(key, 0)):
			if int(a.get("y", 0)) == int(b.get("y", 0)):
				return int(a.get("x", 0)) < int(b.get("x", 0))
			return int(a.get("y", 0)) < int(b.get("y", 0))
		return int(a.get(key, 0)) > int(b.get(key, 0))
	)
	return windows.slice(0, limit)

func _counts_by_kind(records: Array) -> Dictionary:
	var counts := {}
	for record in records:
		if record is Dictionary:
			var kind := String(record.get("kind", "object"))
			counts[kind] = int(counts.get(kind, 0)) + 1
	return counts

func _spatial_policy_counts(generated: Dictionary) -> Dictionary:
	var counts := {}
	var objects: Array = generated.get("object_placements", []) if generated.get("object_placements", []) is Array else []
	for object in objects:
		if object is Dictionary:
			var policy := String(object.get("spatial_placement_policy", "none"))
			counts[policy] = int(counts.get(policy, 0)) + 1
	return counts

func _distribution_summary_from_counts(values: Array) -> Dictionary:
	var total := 0.0
	var nonempty := 0
	var min_value := 999999
	var max_value := 0
	for value in values:
		var v := int(value)
		total += float(v)
		if v > 0:
			nonempty += 1
		min_value = min(min_value, v)
		max_value = max(max_value, v)
	var average := total / float(max(1, values.size()))
	var variance := 0.0
	for value in values:
		var delta := float(int(value)) - average
		variance += delta * delta
	var stddev := sqrt(variance / float(max(1, values.size())))
	return {
		"cell_count": values.size(),
		"total": int(total),
		"nonempty_cell_count": nonempty,
		"empty_cell_count": values.size() - nonempty,
		"min": 0 if min_value == 999999 else min_value,
		"max": max_value,
		"average": snapped(average, 0.001),
		"stddev": snapped(stddev, 0.001),
		"coefficient_of_variation": snapped(stddev / max(0.001, average), 0.0001),
	}

func _ratio_lte(values: Array, limit: int) -> float:
	if values.is_empty():
		return 0.0
	var count := 0
	for value in values:
		if int(value) <= limit:
			count += 1
	return snapped(float(count) / float(values.size()), 0.0001)

func _nested_float(root: Dictionary, outer: String, inner: String) -> float:
	var nested: Dictionary = root.get(outer, {}) if root.get(outer, {}) is Dictionary else {}
	return float(nested.get(inner, 0.0))

func _manhattan(left: Dictionary, right: Dictionary) -> int:
	return abs(int(left.get("x", 0)) - int(right.get("x", 0))) + abs(int(left.get("y", 0)) - int(right.get("y", 0)))

func _point(x: int, y: int) -> Dictionary:
	return {"x": x, "y": y}

func _point_key(x: int, y: int) -> String:
	return "%d,%d" % [x, y]

func snapped(value: float, step: float) -> float:
	if step <= 0.0:
		return value
	return round(value / step) * step

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	get_tree().quit(1)
