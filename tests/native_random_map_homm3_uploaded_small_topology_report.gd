extends Node

const ScenarioSelectRulesScript = preload("res://scripts/core/ScenarioSelectRules.gd")

const REPORT_ID := "NATIVE_RANDOM_MAP_HOMM3_UPLOADED_SMALL_TOPOLOGY_REPORT"
const REPORT_SCHEMA_ID := "native_random_map_homm3_uploaded_small_topology_report_v1"
const OWNER_SMALL_H3M_PATH := "res://maps/small3playermap-1level.h3m"

const HOMM3_VERSION_ROE := 14
const HOMM3_VERSION_AB := 21
const HOMM3_VERSION_SOD := 28
const OBJECT_TEMPLATE_RECORD_BYTES_AFTER_NAME := 42
const H3M_TILE_BYTES_PER_CELL := 7
const DECORATION_TYPE_IDS := {
	118: true, 119: true, 120: true, 134: true, 135: true, 136: true,
	137: true, 147: true, 150: true, 155: true, 199: true, 207: true,
	210: true,
}
const GUARD_TYPE_IDS := {54: true, 71: true}
const TOWN_TYPE_IDS := {98: true}
const RESOURCE_REWARD_TYPE_IDS := {5: true, 53: true, 79: true, 83: true, 88: true, 93: true, 101: true}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not FileAccess.file_exists(OWNER_SMALL_H3M_PATH):
		_fail("Owner uploaded Small H3M evidence is missing at %s." % OWNER_SMALL_H3M_PATH)
		return
	if not ClassDB.class_exists("MapPackageService"):
		_fail("MapPackageService native class is not available.")
		return
	var owner := _parse_owner_small_h3m()
	if owner.is_empty():
		return
	var service: Variant = ClassDB.instantiate("MapPackageService")
	var native := _native_small_package_topology(service)
	if native.is_empty():
		return
	var comparison := _compare(owner, native)
	var gate := _gate(owner, native, comparison)
	if String(gate.get("status", "")) != "pass":
		_fail("Uploaded Small topology comparison failed: %s" % JSON.stringify({
			"gate": gate,
			"owner_h3m": owner,
			"native_small_049": native,
			"comparison": comparison,
		}))
		return
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"schema_id": REPORT_SCHEMA_ID,
		"ok": true,
		"owner_h3m": owner,
		"native_small_049": native,
		"comparison": comparison,
		"gate": gate,
		"remaining_gap": "This report parses the local uploaded Small H3M as evidence and compares it with current native Small 049 package topology. It does not claim exact H3M byte/object-art parity.",
	})])
	get_tree().quit(0)

func _parse_owner_small_h3m() -> Dictionary:
	var compressed := FileAccess.get_file_as_bytes(OWNER_SMALL_H3M_PATH)
	if compressed.is_empty():
		_fail("Could not read owner H3M at %s." % OWNER_SMALL_H3M_PATH)
		return {}
	var bytes := compressed.decompress_dynamic(10000000, 3)
	if bytes.is_empty():
		_fail("Could not decompress owner H3M gzip.")
		return {}
	var version := _u32(bytes, 0)
	if version not in [HOMM3_VERSION_ROE, HOMM3_VERSION_AB, HOMM3_VERSION_SOD]:
		_fail("Unexpected owner Small H3M version %d." % version)
		return {}
	var width := _u32(bytes, 5)
	var height := width
	if width != 36:
		_fail("Owner Small H3M dimensions drifted from expected 36x36: %d." % width)
		return {}
	var def_offset := _find_object_definition_offset(bytes)
	if def_offset <= 0:
		_fail("Could not locate H3M object-definition table.")
		return {}
	var tile_offset := def_offset - width * height * H3M_TILE_BYTES_PER_CELL
	if tile_offset <= 0:
		_fail("Computed invalid owner Small H3M tile-stream offset: %d." % tile_offset)
		return {}
	var templates := _parse_h3m_object_templates(bytes, def_offset)
	if templates.is_empty():
		return {}
	var objects := _parse_h3m_object_instances(bytes, int(templates.get("next_offset", 0)), templates.get("templates", []), width, height)
	if objects.is_empty():
		return {}
	var records: Array = objects.get("records", [])
	var counts := {}
	var towns := []
	var town_points := []
	var blocked := {}
	var action_blocked := {}
	var road_lookup := _h3m_road_lookup(bytes, tile_offset, width, height)
	var effective_guard_count := 0
	for record_value in records:
		if not (record_value is Dictionary):
			continue
		var record: Dictionary = record_value
		var category := _h3m_category_for_record(record)
		counts[category] = int(counts.get(category, 0)) + 1
		for point in _h3m_mask_points(record, false, width, height):
			blocked[_point_key(int(point.get("x", 0)), int(point.get("y", 0)))] = true
		for point in _h3m_mask_points(record, true, width, height):
			action_blocked[_point_key(int(point.get("x", 0)), int(point.get("y", 0)))] = true
		if int(record.get("type_id", -1)) == 54:
			effective_guard_count += 1
		if category == "town":
			var visit_points := _h3m_mask_points(record, true, width, height)
			towns.append({
				"id": "owner_town_%02d" % (towns.size() + 1),
				"x": int(record.get("x", 0)),
				"y": int(record.get("y", 0)),
				"visit_points": visit_points,
			})
			town_points.append(Vector2i(int(record.get("x", 0)), int(record.get("y", 0))))
	var topology := _town_pair_topology(blocked, width, height, towns)
	return {
		"source_path": OWNER_SMALL_H3M_PATH,
		"version": version,
		"width": width,
		"height": height,
		"level_count": 1,
		"gzip_bytes": compressed.size(),
		"decompressed_h3m_bytes": bytes.size(),
		"object_definition_count": int(templates.get("template_count", 0)),
		"object_count": records.size(),
		"counts_by_category": counts,
		"town_count": towns.size(),
		"nearest_town_manhattan": _nearest_manhattan(town_points),
		"road_cell_count": road_lookup.size(),
		"mask_blocked_tile_count": blocked.size(),
		"action_tile_count": action_blocked.size(),
		"effective_guard_count_type_54": effective_guard_count,
		"guard_count_including_type_71_records": int(counts.get("guard", 0)),
		"towns": towns,
		"rough_town_topology": topology,
		"parse_boundary": "Uses H3M object template passability/action masks with bottom-right object anchor interpretation; route semantics are useful for gap evidence but not exact HoMM3 engine pathing parity.",
	}

func _native_small_package_topology(service: Variant) -> Dictionary:
	var config := ScenarioSelectRulesScript.build_random_map_player_config(
		"uploaded-small-comparison-10184",
		"",
		"",
		3,
		"land",
		false,
		"homm3_small"
	)
	var generated: Dictionary = service.generate_random_map(config, {"startup_path": "uploaded_small_topology"})
	if not bool(generated.get("ok", false)) or String(generated.get("validation_status", "")) != "pass":
		_fail("Native Small generation failed before topology report: %s" % JSON.stringify(generated.get("validation_report", generated)))
		return {}
	var adoption: Dictionary = service.convert_generated_payload(generated, {
		"feature_gate": "native_rmg_uploaded_small_topology_report",
		"session_save_version": 9,
		"scenario_id": "native_uploaded_small_topology",
	})
	if not bool(adoption.get("ok", false)):
		_fail("Native Small package conversion failed: %s" % JSON.stringify(adoption))
		return {}
	var map_document: Variant = adoption.get("map_document", null)
	if map_document == null:
		_fail("Native Small package conversion missed map_document.")
		return {}
	var terrain_layers: Dictionary = map_document.get_terrain_layers()
	var metadata: Dictionary = map_document.get_metadata()
	var normalized: Dictionary = metadata.get("normalized_config", {}) if metadata.get("normalized_config", {}) is Dictionary else {}
	var component_counts: Dictionary = metadata.get("component_counts", {}) if metadata.get("component_counts", {}) is Dictionary else {}
	var road_summary := _native_road_summary(terrain_layers.get("roads", []) if terrain_layers.get("roads", []) is Array else [])
	var object_summary := _native_object_summary(map_document)
	var terrain_blocked := _native_terrain_blocked_tiles(map_document, terrain_layers)
	var object_blocked := _native_object_blocked_tiles(map_document)
	var unresolved_blocked := terrain_blocked.duplicate(true)
	for key in object_blocked.keys():
		unresolved_blocked[key] = true
	var topology := _town_pair_topology(unresolved_blocked, int(map_document.get_width()), int(map_document.get_height()), object_summary.get("towns", []))
	return {
		"width": int(map_document.get_width()),
		"height": int(map_document.get_height()),
		"level_count": int(map_document.get_level_count()),
		"template_id": String(normalized.get("template_id", "")),
		"profile_id": String(normalized.get("profile_id", "")),
		"validation_status": String(generated.get("validation_status", "")),
		"full_generation_status": String(generated.get("full_generation_status", "")),
		"zone_count": int(component_counts.get("zone_count", 0)),
		"road_cell_count": int(road_summary.get("road_unique_tile_count", 0)),
		"zero_tile_road_count": int(road_summary.get("zero_tile_road_count", 0)),
		"road_duplicate_tile_count": int(road_summary.get("road_duplicate_tile_count", 0)),
		"object_count": int(map_document.get_object_count()),
		"counts_by_kind": object_summary.get("counts_by_kind", {}),
		"town_count": int(object_summary.get("town_count", 0)),
		"guard_count": int(object_summary.get("guard_count", 0)),
		"nearest_town_manhattan": int(object_summary.get("nearest_town_manhattan", 0)),
		"terrain_blocked_tile_count": terrain_blocked.size(),
		"object_blocked_tile_count": object_blocked.size(),
		"unresolved_blocked_tile_count": unresolved_blocked.size(),
		"towns": object_summary.get("towns", []),
		"town_topology": topology,
	}

func _compare(owner: Dictionary, native: Dictionary) -> Dictionary:
	return {
		"object_count_delta": int(native.get("object_count", 0)) - int(owner.get("object_count", 0)),
		"town_count_delta": int(native.get("town_count", 0)) - int(owner.get("town_count", 0)),
		"guard_count_delta_including_type_71": int(native.get("guard_count", 0)) - int(owner.get("guard_count_including_type_71_records", 0)),
		"road_cell_delta": int(native.get("road_cell_count", 0)) - int(owner.get("road_cell_count", 0)),
		"nearest_town_manhattan_delta": int(native.get("nearest_town_manhattan", 0)) - int(owner.get("nearest_town_manhattan", 0)),
		"native_terrain_blocked_vs_owner_mask_blocked_delta": int(native.get("terrain_blocked_tile_count", 0)) - int(owner.get("mask_blocked_tile_count", 0)),
		"native_unresolved_reachable_town_pairs": int(native.get("town_topology", {}).get("reachable_pair_count", 0)),
		"owner_rough_unresolved_reachable_town_pairs": int(owner.get("rough_town_topology", {}).get("reachable_pair_count", 0)),
		"interpretation": "Counts compare exact parsed/package surfaces; owner rough topology is not used as a hard gate because exact H3M passability/pathing semantics are not fully implemented in this local parser.",
	}

func _gate(owner: Dictionary, native: Dictionary, comparison: Dictionary) -> Dictionary:
	var failures := []
	var warnings := []
	if String(native.get("template_id", "")) != "translated_rmg_template_049_v1":
		failures.append("native_small_default_not_using_translated_template_049")
	if int(native.get("object_count", 0)) != int(owner.get("object_count", 0)):
		failures.append("native_small_object_count_drifted_from_owner_upload")
	if int(native.get("town_count", 0)) != int(owner.get("town_count", 0)):
		failures.append("native_small_town_count_drifted_from_owner_upload")
	if int(native.get("guard_count", 0)) < int(owner.get("guard_count_including_type_71_records", 0)):
		failures.append("native_small_guard_count_below_owner_upload")
	if abs(int(comparison.get("road_cell_delta", 999))) > 8:
		failures.append("native_small_road_cell_count_too_far_from_owner_upload")
	if int(native.get("zero_tile_road_count", 0)) != 0 or int(native.get("road_duplicate_tile_count", 0)) != 0:
		failures.append("native_small_package_serialized_empty_or_duplicate_roads")
	if int(comparison.get("native_unresolved_reachable_town_pairs", 0)) != 0:
		failures.append("native_small_has_unresolved_reachable_town_pairs")
	if int(native.get("terrain_blocked_tile_count", 0)) > 0:
		warnings.append("native_small_still_uses_terrain_rock_boundaries_instead_of_object_only_h3m_style_obstacle_chokes")
	if String(native.get("full_generation_status", "")) != "implemented_for_supported_profile":
		warnings.append("native_small_translated_profile_full_generation_status_not_implemented")
	return {
		"status": "pass" if failures.is_empty() else "fail",
		"failures": failures,
		"warnings": warnings,
		"thresholds": {
			"max_abs_road_cell_delta": 8,
			"required_native_unresolved_reachable_town_pairs": 0,
			"required_zero_tile_road_count": 0,
		},
	}

func _parse_h3m_object_templates(bytes: PackedByteArray, offset: int) -> Dictionary:
	var count := _u32(bytes, offset)
	if count <= 0 or count > 2000:
		_fail("Invalid H3M object definition count at %d: %d." % [offset, count])
		return {}
	var pos := offset + 4
	var templates := []
	for index in range(count):
		var name_len := _u32(bytes, pos)
		pos += 4
		if name_len <= 0 or name_len > 128 or pos + name_len + OBJECT_TEMPLATE_RECORD_BYTES_AFTER_NAME > bytes.size():
			_fail("Invalid H3M object definition name length %d at index %d." % [name_len, index])
			return {}
		var def_name := _ascii(bytes, pos, name_len)
		pos += name_len
		var rest_offset := pos
		pos += OBJECT_TEMPLATE_RECORD_BYTES_AFTER_NAME
		templates.append({
			"template_index": index,
			"def_name": def_name,
			"passability_mask": bytes.slice(rest_offset, rest_offset + 6),
			"action_mask": bytes.slice(rest_offset + 6, rest_offset + 12),
			"type_id": _u32(bytes, rest_offset + 16),
			"subtype": _u32(bytes, rest_offset + 20),
		})
	return {
		"template_count": count,
		"templates": templates,
		"next_offset": pos,
	}

func _parse_h3m_object_instances(bytes: PackedByteArray, offset: int, templates: Array, width: int, height: int) -> Dictionary:
	var count := _u32(bytes, offset)
	if count <= 0 or count > 5000:
		_fail("Invalid H3M placed object count at %d: %d." % [offset, count])
		return {}
	var pos := offset + 4
	var records := []
	for index in range(count):
		if not _is_h3m_object_instance_start(bytes, pos, templates.size(), width, height):
			_fail("Could not parse H3M placed object %d at offset %d." % [index, pos])
			return {}
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
		for extra in range(0, 320):
			var candidate := next_min + extra
			if _is_h3m_object_instance_start(bytes, candidate, templates.size(), width, height):
				found = candidate
				break
		if found < 0:
			_fail("Could not find next H3M object instance after index %d at offset %d." % [index, pos])
			return {}
		pos = found
	return {
		"records": records,
		"object_count": records.size(),
		"next_offset": pos,
	}

func _is_h3m_object_instance_start(bytes: PackedByteArray, pos: int, template_count: int, width: int, height: int) -> bool:
	if pos < 0 or pos + 12 > bytes.size():
		return false
	var x := int(bytes[pos])
	var y := int(bytes[pos + 1])
	var z := int(bytes[pos + 2])
	var template_index := _u32(bytes, pos + 3)
	if x < 0 or y < 0 or x >= width or y >= height or z != 0:
		return false
	if template_index < 0 or template_index >= template_count:
		return false
	for index in range(5):
		if int(bytes[pos + 7 + index]) != 0:
			return false
	return true

func _h3m_category_for_record(record: Dictionary) -> String:
	var type_id := int(record.get("type_id", -1))
	if DECORATION_TYPE_IDS.has(type_id):
		return "decoration"
	if GUARD_TYPE_IDS.has(type_id):
		return "guard"
	if TOWN_TYPE_IDS.has(type_id):
		return "town"
	if RESOURCE_REWARD_TYPE_IDS.has(type_id):
		return "reward"
	return "object"

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

func _h3m_road_lookup(bytes: PackedByteArray, tile_offset: int, width: int, height: int) -> Dictionary:
	var lookup := {}
	for y in range(height):
		for x in range(width):
			var offset := tile_offset + (y * width + x) * H3M_TILE_BYTES_PER_CELL
			if int(bytes[offset + 4]) != 0:
				lookup[_point_key(x, y)] = true
	return lookup

func _native_road_summary(roads: Array) -> Dictionary:
	var road_tile_lookup := {}
	var duplicate_count := 0
	var zero_count := 0
	for road in roads:
		if not (road is Dictionary):
			continue
		if int(road.get("tile_count", road.get("cell_count", 0))) <= 0:
			zero_count += 1
		var tiles: Array = road.get("tiles", road.get("cells", [])) if road.get("tiles", road.get("cells", [])) is Array else []
		for tile in tiles:
			if not (tile is Dictionary):
				continue
			var key := _point_key(int(tile.get("x", 0)), int(tile.get("y", 0)))
			if road_tile_lookup.has(key):
				duplicate_count += 1
			road_tile_lookup[key] = true
	return {
		"road_unique_tile_count": road_tile_lookup.size(),
		"road_duplicate_tile_count": duplicate_count,
		"zero_tile_road_count": zero_count,
	}

func _native_object_summary(map_document: Variant) -> Dictionary:
	var counts := {}
	var towns := []
	var town_points := []
	for index in range(int(map_document.get_object_count())):
		var object: Dictionary = map_document.get_object_by_index(index)
		var kind := String(object.get("kind", object.get("native_record_kind", object.get("category_id", "object"))))
		counts[kind] = int(counts.get(kind, 0)) + 1
		if kind == "town":
			var town := {
				"id": String(object.get("placement_id", "")),
				"x": int(object.get("x", 0)),
				"y": int(object.get("y", 0)),
				"visit_points": object.get("package_visit_tiles", []),
			}
			towns.append(town)
			town_points.append(Vector2i(int(object.get("x", 0)), int(object.get("y", 0))))
	return {
		"counts_by_kind": counts,
		"towns": towns,
		"town_count": towns.size(),
		"guard_count": int(counts.get("guard", 0)),
		"nearest_town_manhattan": _nearest_manhattan(town_points),
	}

func _native_terrain_blocked_tiles(map_document: Variant, terrain_layers: Dictionary) -> Dictionary:
	var blocked := {}
	var terrain: Dictionary = terrain_layers.get("terrain", {}) if terrain_layers.get("terrain", {}) is Dictionary else {}
	var levels: Array = terrain.get("levels", []) if terrain.get("levels", []) is Array else []
	if levels.is_empty():
		return blocked
	var codes := _native_terrain_codes_for_level(levels[0])
	var ids_by_code: Variant = terrain_layers.get("terrain_id_by_code", [])
	var width := int(map_document.get_width())
	var height := int(map_document.get_height())
	for y in range(height):
		for x in range(width):
			var index := y * width + x
			var terrain_id := _terrain_id_for_code(ids_by_code, int(codes[index]) if index < codes.size() else 0)
			if terrain_id in ["rock", "water"]:
				blocked[_point_key(x, y)] = true
	return blocked

func _native_terrain_codes_for_level(level_record: Variant) -> Array:
	if level_record is Dictionary:
		return Array(level_record.get("terrain_code_u16", []))
	if level_record is PackedInt32Array:
		return Array(level_record)
	if level_record is Array:
		return level_record
	return []

func _native_object_blocked_tiles(map_document: Variant) -> Dictionary:
	var blocked := {}
	for index in range(int(map_document.get_object_count())):
		var object: Dictionary = map_document.get_object_by_index(index)
		var block_tiles: Array = object.get("package_block_tiles", []) if object.get("package_block_tiles", []) is Array else []
		for tile in block_tiles:
			if tile is Dictionary:
				blocked[_point_key(int(tile.get("x", 0)), int(tile.get("y", 0)))] = true
	return blocked

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
			best = min(best, abs(left.x - right.x) + abs(left.y - right.y))
	return best

func _find_object_definition_offset(bytes: PackedByteArray) -> int:
	for offset in range(0, bytes.size() - 32):
		var count := _u32(bytes, offset)
		if count < 10 or count > 1000:
			continue
		var name_len := _u32(bytes, offset + 4)
		if name_len < 4 or name_len > 32:
			continue
		var name := _ascii(bytes, offset + 8, name_len)
		if name.to_lower().ends_with(".def"):
			return offset
	return -1

func _terrain_id_for_code(ids_by_code: Variant, code: int) -> String:
	if (ids_by_code is Array or ids_by_code is PackedStringArray) and code >= 0 and code < ids_by_code.size():
		return String(ids_by_code[code])
	return "grass"

func _point_key(x: int, y: int) -> String:
	return "%d,%d" % [x, y]

func _u32(bytes: PackedByteArray, offset: int) -> int:
	if offset < 0 or offset + 4 > bytes.size():
		return 0
	return int(bytes[offset]) | (int(bytes[offset + 1]) << 8) | (int(bytes[offset + 2]) << 16) | (int(bytes[offset + 3]) << 24)

func _ascii(bytes: PackedByteArray, offset: int, length: int) -> String:
	var chars := PackedByteArray()
	for index in range(length):
		chars.append(bytes[offset + index])
	return chars.get_string_from_ascii()

func _fail(message: String) -> void:
	push_error("%s failed: %s" % [REPORT_ID, message])
	print("%s %s" % [REPORT_ID, JSON.stringify({
		"schema_id": REPORT_SCHEMA_ID,
		"ok": false,
		"error": message,
	})])
	get_tree().quit(1)
