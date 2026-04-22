class_name TerrainPlacementRules
extends RefCounted

const PLACEMENT_MODEL := "homm3_owner_queue_rewrite_final_normalization.v1"
const PAINT_ORDER_MODEL := "paint_tiles_in_tool_order_then_drain_set_a_set_b"
const FINAL_NORMALIZATION_MODEL := "final_normalization_4bbfcc_reclassifies_settled_owner_map"
const VISUAL_SELECTION_MODEL := "accepted_web_prototype_relation_class_row_lookup.v1"
const VISUAL_FRAME_SELECTION_SOURCE := "accepted_web_prototype_and_recovered_h3maped_final_normalization"

const TERRAIN_FAMILY_IDS := {
	"dirt": 0,
	"sand": 1,
	"grass": 2,
	"snow": 3,
	"swamp": 4,
	"rough": 5,
	"subterranean": 6,
	"lava": 7,
	"water": 8,
	"rock": 9,
}
const TERRAIN_FAMILIES_BY_ID := [
	"dirt",
	"sand",
	"grass",
	"snow",
	"swamp",
	"rough",
	"subterranean",
	"lava",
	"water",
	"rock",
]
const TRAIT_FLAG4 := [1, 0, 1, 1, 1, 1, 1, 1, 0, 0]
const TRAIT_FLAG5 := [1, 1, 1, 1, 1, 1, 1, 1, 0, 0]
const NEIGHBOR_OFFSETS := [
	Vector2i(0, -1),
	Vector2i(1, -1),
	Vector2i(1, 0),
	Vector2i(1, 1),
	Vector2i(0, 1),
	Vector2i(-1, 1),
	Vector2i(-1, 0),
	Vector2i(-1, -1),
]
const CARDINAL_OFFSETS := [
	Vector2i(0, -1),
	Vector2i(0, 1),
	Vector2i(-1, 0),
	Vector2i(1, 0),
]
const DIAGONAL_OFFSETS := [
	Vector2i(-1, -1),
	Vector2i(1, -1),
	Vector2i(-1, 1),
	Vector2i(1, 1),
]
const BOUNDARY_ADJACENCIES := [
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(1, 1),
	Vector2i(-1, 1),
]
const FLAG_WORDS := [
	Vector2i(0, 0),
	Vector2i(0, 1),
	Vector2i(1, 0),
	Vector2i(1, 1),
]
const ORIENTATION_PERMS := [
	[0, 1, 2, 3, 4, 5, 6, 7],
	[4, 3, 2, 1, 0, 7, 6, 5],
	[0, 7, 6, 5, 4, 3, 2, 1],
	[4, 5, 6, 7, 0, 1, 2, 3],
]
const DIAGONAL_PROBE_OFFSETS := {
	"0,0": [Vector2i(-1, 1), Vector2i(1, -1)],
	"1,0": [Vector2i(1, 1), Vector2i(-1, -1)],
	"0,1": [Vector2i(-1, -1), Vector2i(1, 1)],
	"1,1": [Vector2i(1, -1), Vector2i(-1, 1)],
}
const TWO_STEP_PROBE_OFFSETS := {
	"0,0": Vector2i(2, 2),
	"1,0": Vector2i(-2, 2),
	"0,1": Vector2i(2, -2),
	"1,1": Vector2i(-2, -2),
}
const NORMAL_TABLE_CLASS_COVERAGE := {
	0: [0, 8, 9, 10, 11, 12, 13, 16, 24],
	1: [0],
	2: [0, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28],
	3: [0, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28],
	4: [0, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28],
	5: [0, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28],
	6: [0, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28],
	7: [0, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28],
	8: [0, 8, 9, 10, 11, 12, 13, 16],
	9: [0, 8, 9, 10, 11, 12, 13],
}
const SPECIAL_TILE_FREQ := [50, 70, 50, 80, 80, 80, 60, 80, 0, 0]
const NORMAL_TABLE_BY_OWNER_ID := {
	0: "dirt",
	1: "sand",
	2: "normal79",
	3: "normal79",
	4: "normal79",
	5: "normal79",
	6: "normal79",
	7: "normal79",
	8: "water",
}
const NORMAL79_ROWS := {
	0: {"ordinary": [49, 50, 51, 52, 53, 54, 55, 56], "special": [57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72]},
	2: [0, 1, 2, 3],
	3: [4, 5, 6, 7],
	4: [8, 9, 10, 11],
	5: [12, 13, 14, 15],
	6: [16, 17],
	7: [18, 19],
	8: [20, 21, 22, 23],
	9: [24, 25, 26, 27],
	10: [28, 29, 30, 31],
	11: [32, 33, 34, 35],
	12: [36, 37],
	13: [38, 39],
	14: [40],
	15: [41],
	16: [42],
	17: [43],
	18: [44],
	19: [45],
	20: [46],
	21: [47],
	22: [48],
	23: [73],
	24: [74],
	25: [75],
	26: [76],
	27: [78],
	28: [77],
}
const DIRT_ROWS := {
	0: {"ordinary": [21, 22, 23, 24, 25, 26, 27, 28], "special": [29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44]},
	8: [0, 1, 2, 3],
	9: [4, 5, 6, 7],
	10: [8, 9, 10, 11],
	11: [12, 13, 14, 15],
	12: [16, 17],
	13: [18, 19],
	16: [20],
	24: [45],
}
const SAND_ROWS := {
	0: {"ordinary": [0, 1, 2, 3, 4, 5, 6, 7], "special": [8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23]},
}
const WATER_ROWS := {
	0: {"ordinary": [21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32], "special": []},
	8: [0, 1, 2, 3],
	9: [4, 5, 6, 7],
	10: [8, 9, 10, 11],
	11: [12, 13, 14, 15],
	12: [16, 17],
	13: [18, 19],
	16: [20],
}
const ROCK_ROWS := {
	0: {"0,0": [0, 1, 2, 3, 4, 5, 6, 7]},
	8: {"0,0": [8, 9], "1,0": [10, 11], "0,1": [12, 13], "1,1": [14, 15]},
	9: {"0,0": [16, 17], "1,0": [18, 19]},
	10: {"0,0": [20, 21], "0,1": [22, 23]},
	11: {"0,0": [24, 25], "1,0": [26, 27], "0,1": [28, 29], "1,1": [30, 31]},
	12: {"0,0": [32, 33], "1,0": [34, 35], "0,1": [36, 37], "1,1": [38, 39]},
	13: {"0,0": [40, 41], "1,0": [42, 43], "0,1": [44, 45], "1,1": [46, 47]},
}
const CLASS_TOPOLOGY := {
	0: "full/native",
	2: "relation-1 orthogonal elbow",
	3: "relation-1 west/east edge",
	4: "relation-1 north/south edge",
	5: "relation-1 single diagonal",
	6: "relation-1 corrected elbow",
	7: "relation-1 corrected diagonal",
	8: "relation-2 orthogonal elbow",
	9: "relation-2 west/east edge",
	10: "relation-2 north/south edge",
	11: "relation-2 single diagonal",
	12: "relation-2 corrected elbow",
	13: "relation-2 corrected diagonal",
	14: "opposite diagonal pair 1/1",
	15: "opposite diagonal pair 1/2",
	16: "opposite diagonal pair 2/2",
	17: "relation-1 cardinal with relation-2 opposite diagonal",
	18: "relation-1 cardinal with relation-2 opposite diagonal, alternate axis",
	19: "relation-1 cardinal with relation-2 same-corner diagonal",
	20: "relation-1 cardinal with relation-2 same-corner diagonal, alternate axis",
	21: "relation-2 cardinal with relation-1 opposite diagonal",
	22: "relation-2 cardinal with relation-1 opposite diagonal, alternate axis",
	23: "relation-1 compound corner",
	24: "relation-2 compound corner",
	25: "relation-1 corner with relation-2 opposite diagonal",
	26: "relation-2 corner with relation-1 opposite diagonal",
	27: "relation-1 corner with relation-2 same-corner diagonal",
	28: "relation-1 corner with two relation-2 diagonals",
}

class OrderedPointSet:
	var _map_size := Vector2i.ZERO
	var _points := {}

	func _init(map_size: Vector2i) -> void:
		_map_size = map_size

	func size() -> int:
		return _points.size()

	func add(tile: Vector2i) -> void:
		if tile.x >= 0 and tile.y >= 0 and tile.x < _map_size.x and tile.y < _map_size.y:
			_points[_tile_key(tile)] = tile

	func erase(tile: Vector2i) -> void:
		_points.erase(_tile_key(tile))

	func has(tile: Vector2i) -> bool:
		return _points.has(_tile_key(tile))

	func take_first() -> Vector2i:
		var best_key := ""
		var best_tile := Vector2i.ZERO
		for key in _points.keys():
			var tile: Vector2i = _points.get(key, Vector2i.ZERO)
			if best_key == "" or tile.y < best_tile.y or (tile.y == best_tile.y and tile.x < best_tile.x):
				best_key = String(key)
				best_tile = tile
		if best_key != "":
			_points.erase(best_key)
		return best_tile

	func _tile_key(tile: Vector2i) -> String:
		return "%d,%d" % [tile.x, tile.y]

static func apply_paint(
	map_data: Array,
	map_size: Vector2i,
	brush_terrain_id: String,
	paint_tiles: Array,
	terrain_grammar: Dictionary
) -> Dictionary:
	var brush_family := terrain_family_for_id(terrain_grammar, brush_terrain_id)
	var brush_owner_id := terrain_owner_id_for_family(brush_family)
	if brush_terrain_id == "" or brush_owner_id < 0:
		return {
			"ok": false,
			"changed": false,
			"message": "Terrain id %s is not mapped to a HoMM3 terrain family." % brush_terrain_id,
			"placement_model": PLACEMENT_MODEL,
		}
	if not (map_data is Array) or map_data.is_empty() or map_size.x <= 0 or map_size.y <= 0:
		return {
			"ok": false,
			"changed": false,
			"message": "Terrain placement requires a loaded map.",
			"placement_model": PLACEMENT_MODEL,
		}

	var context := {
		"map_data": map_data,
		"map_size": map_size,
		"terrain_grammar": terrain_grammar,
		"brush_terrain_id": brush_terrain_id,
		"brush_family": brush_family,
		"brush_owner_id": brush_owner_id,
		"changed_tiles": [],
		"owner_changed_tiles": [],
		"direct_changed_tiles": [],
		"changed_keys": {},
		"owner_changed_keys": {},
		"set_a": OrderedPointSet.new(map_size),
		"set_b": OrderedPointSet.new(map_size),
		"queue_guard_exhausted": false,
	}
	var requested_tiles := _unique_in_bounds_tiles(paint_tiles, map_size)
	var previous_terrain_by_tile := {}
	var changed_owner_cells: Array[Vector2i] = []

	for tile in requested_tiles:
		var previous_terrain := _terrain_at(map_data, tile)
		previous_terrain_by_tile[tile_key(tile)] = previous_terrain
		if previous_terrain == "":
			continue
		var previous_owner_id := terrain_owner_id_for_terrain(terrain_grammar, previous_terrain)
		if previous_owner_id != brush_owner_id:
			_write_brush_terrain(tile, context, true, true)
			changed_owner_cells.append(tile)
		elif previous_terrain != brush_terrain_id:
			_write_brush_terrain(tile, context, true, false)

	_drain_terrain_placement_queues(changed_owner_cells, context)
	var final_payload := final_normalization_payload(map_data, map_size, terrain_grammar)
	var changed_tiles: Array = context.get("changed_tiles", [])
	var owner_changed_tiles: Array = context.get("owner_changed_tiles", [])
	return {
		"ok": true,
		"changed": not changed_tiles.is_empty(),
		"placement_model": PLACEMENT_MODEL,
		"paint_order_model": PAINT_ORDER_MODEL,
		"queue_model": "rewrite_to_current_brush_4bb74b_then_drain_queues_4bc5f0",
		"final_normalization_model": FINAL_NORMALIZATION_MODEL,
		"brush_terrain_id": brush_terrain_id,
		"brush_family": brush_family,
		"brush_owner_id": brush_owner_id,
		"requested_tiles": tile_array_payload(requested_tiles),
		"requested_count": requested_tiles.size(),
		"changed_tiles": tile_array_payload(changed_tiles),
		"changed_count": changed_tiles.size(),
		"owner_changed_tiles": tile_array_payload(owner_changed_tiles),
		"owner_changed_count": owner_changed_tiles.size(),
		"direct_changed_tiles": tile_array_payload(context.get("direct_changed_tiles", [])),
		"direct_changed_count": int(context.get("direct_changed_tiles", []).size()),
		"previous_terrain_by_tile": previous_terrain_by_tile,
		"queue_guard_exhausted": bool(context.get("queue_guard_exhausted", false)),
		"final_normalization": final_payload,
	}

static func final_normalization_payload(map_data: Array, map_size: Vector2i, terrain_grammar: Dictionary) -> Dictionary:
	var boundary_counts := _compute_boundary_counts(map_data, map_size, terrain_grammar)
	var class_counts := {}
	var missing_buckets := []
	var boundary_cell_count := 0
	var correction_count := 0
	var full_native_count := 0
	var transition_cell_count := 0
	for y in range(map_size.y):
		for x in range(map_size.x):
			var tile := Vector2i(x, y)
			var owner_id := terrain_owner_id_for_terrain(terrain_grammar, _terrain_at(map_data, tile))
			var boundary_count := int(boundary_counts[y][x])
			var class_info := {"class_code": 0, "flag_a": 0, "flag_b": 0, "reason": "no classed relation"}
			var correction := ""
			if boundary_count > 0:
				boundary_cell_count += 1
				class_info = _classify_relations(_relation_ring_for_cell(map_data, map_size, terrain_grammar, tile))
				var corrected := _apply_final_corrections(int(class_info.get("class_code", 0)), map_data, map_size, terrain_grammar, tile, int(class_info.get("flag_a", 0)), int(class_info.get("flag_b", 0)))
				correction = String(corrected.get("correction", ""))
				class_info["class_code"] = int(corrected.get("class_code", class_info.get("class_code", 0)))
				if correction != "":
					correction_count += 1
			var class_code := int(class_info.get("class_code", 0))
			var class_key := str(class_code)
			class_counts[class_key] = int(class_counts.get(class_key, 0)) + 1
			if class_code == 0:
				full_native_count += 1
			else:
				transition_cell_count += 1
			if not _row_bucket_exists(owner_id, class_code):
				missing_buckets.append({
					"tile": vector2i_payload(tile),
					"owner_id": owner_id,
					"owner_family": terrain_family_for_id_number(owner_id),
					"class_code": class_code,
					"boundary_count": boundary_count,
					"correction": correction,
				})
	return {
		"model": FINAL_NORMALIZATION_MODEL,
		"visited_count": map_size.x * map_size.y,
		"boundary_cell_count": boundary_cell_count,
		"full_native_count": full_native_count,
		"transition_cell_count": transition_cell_count,
		"class_counts": class_counts,
		"correction_count": correction_count,
		"missing_bucket_count": missing_buckets.size(),
		"missing_buckets": missing_buckets,
		"stale_transition_clear_model": "zero_boundary_cells_use_pick_full_branch_and_clear_flags",
		"owner_map_source": "settled_after_4bc5f0_queue_drain",
	}

static func visual_selection_payload(map_data: Array, map_size: Vector2i, terrain_grammar: Dictionary, tile: Vector2i) -> Dictionary:
	if not (map_data is Array) or map_data.is_empty() or not _in_bounds(tile, map_size):
		return {}
	var terrain_id := _terrain_at(map_data, tile)
	var owner_family := terrain_family_for_id(terrain_grammar, terrain_id)
	var owner_id := terrain_owner_id_for_family(owner_family)
	if owner_id < 0:
		return {}
	var boundary_count := _boundary_count_for_cell(map_data, map_size, terrain_grammar, tile)
	var relation_ring := _relation_ring_for_cell(map_data, map_size, terrain_grammar, tile)
	var direct_water_rock_contact := _has_direct_water_rock_contact(map_data, map_size, terrain_grammar, tile)
	var class_info := {"class_code": 0, "flag_a": 0, "flag_b": 0, "reason": "no classed relation"}
	var correction := ""
	if boundary_count > 0:
		class_info = _classify_relations(relation_ring)
		var corrected := _apply_final_corrections(
			int(class_info.get("class_code", 0)),
			map_data,
			map_size,
			terrain_grammar,
			tile,
			int(class_info.get("flag_a", 0)),
			int(class_info.get("flag_b", 0))
		)
		correction = String(corrected.get("correction", ""))
		class_info["class_code"] = int(corrected.get("class_code", class_info.get("class_code", 0)))
	var class_code := int(class_info.get("class_code", 0))
	var selected := _select_visual_frame(owner_id, class_code, int(class_info.get("flag_a", 0)), int(class_info.get("flag_b", 0)), tile)
	var frame_number := int(selected.get("frame", 0))
	var fallback_reasons := []
	if bool(selected.get("fallback", false)):
		fallback_reasons.append(String(selected.get("fallback_reason", "")))
	if direct_water_rock_contact:
		fallback_reasons.append("explicit direct water/rock contact kept unresolved")
	return {
		"ok": true,
		"selection_model": VISUAL_SELECTION_MODEL,
		"frame_selection_source": VISUAL_FRAME_SELECTION_SOURCE,
		"final_normalization_model": FINAL_NORMALIZATION_MODEL,
		"owner_id": owner_id,
		"owner_family": owner_family,
		"terrain_id": terrain_id,
		"shape_class": class_code,
		"class_topology": String(CLASS_TOPOLOGY.get(class_code, "unlabeled recovered class")),
		"class_reason": String(class_info.get("reason", "")),
		"correction": correction,
		"boundary_count": boundary_count,
		"relation_ring": relation_ring,
		"relation_grid": relation_grid_string(relation_ring),
		"row_group": String(selected.get("row_group", "")),
		"row_source": String(selected.get("row_source", "")),
		"row_table": String(selected.get("row_table", "")),
		"frame_number": frame_number,
		"frame_id": "00_%02d" % frame_number,
		"requested_flag_a": int(class_info.get("flag_a", 0)),
		"requested_flag_b": int(class_info.get("flag_b", 0)),
		"flag_a": int(selected.get("output_flag_a", 0)),
		"flag_b": int(selected.get("output_flag_b", 0)),
		"flip_h": int(selected.get("output_flag_a", 0)) == 1,
		"flip_v": int(selected.get("output_flag_b", 0)) == 1,
		"fallback": bool(selected.get("fallback", false)) or direct_water_rock_contact,
		"fallback_reason": "; ".join(fallback_reasons),
		"direct_water_rock_contact": direct_water_rock_contact,
		"bridge_family": _bridge_family_from_relations(relation_ring),
		"selected_frame_block": _visual_frame_block_for(owner_family, frame_number, class_code),
	}

static func terrain_family_for_id(terrain_grammar: Dictionary, terrain_id: String) -> String:
	var normalized := terrain_id.strip_edges().to_lower()
	var homm3 = terrain_grammar.get("homm3_local_prototype", {})
	var terrain_id_map = homm3.get("terrain_id_map", {}) if homm3 is Dictionary else {}
	if terrain_id_map is Dictionary:
		var mapping = terrain_id_map.get(normalized, {})
		if mapping is Dictionary:
			var family := String(mapping.get("family", "")).strip_edges()
			if family != "":
				return family
	if TERRAIN_FAMILY_IDS.has(normalized):
		return normalized
	return ""

static func terrain_owner_id_for_terrain(terrain_grammar: Dictionary, terrain_id: String) -> int:
	return terrain_owner_id_for_family(terrain_family_for_id(terrain_grammar, terrain_id))

static func terrain_owner_id_for_family(family_id: String) -> int:
	return int(TERRAIN_FAMILY_IDS.get(family_id.strip_edges().to_lower(), -1))

static func terrain_family_for_id_number(owner_id: int) -> String:
	if owner_id >= 0 and owner_id < TERRAIN_FAMILIES_BY_ID.size():
		return String(TERRAIN_FAMILIES_BY_ID[owner_id])
	return ""

static func tile_key(tile: Vector2i) -> String:
	return "%d,%d" % [tile.x, tile.y]

static func vector2i_payload(tile: Vector2i) -> Dictionary:
	return {"x": tile.x, "y": tile.y}

static func tile_array_payload(tiles: Array) -> Array:
	var payload := []
	for tile_value in tiles:
		if tile_value is Vector2i:
			payload.append(vector2i_payload(tile_value))
	return payload

static func _unique_in_bounds_tiles(tiles: Array, map_size: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var seen := {}
	for tile_value in tiles:
		if not (tile_value is Vector2i):
			continue
		var tile: Vector2i = tile_value
		if not _in_bounds(tile, map_size):
			continue
		var key := tile_key(tile)
		if seen.has(key):
			continue
		seen[key] = true
		result.append(tile)
	return result

static func _in_bounds(tile: Vector2i, map_size: Vector2i) -> bool:
	return tile.x >= 0 and tile.y >= 0 and tile.x < map_size.x and tile.y < map_size.y

static func _terrain_at(map_data: Array, tile: Vector2i) -> String:
	if tile.y < 0 or tile.y >= map_data.size():
		return ""
	var row = map_data[tile.y]
	if not (row is Array) or tile.x < 0 or tile.x >= row.size():
		return ""
	return String(row[tile.x])

static func _set_terrain_at(map_data: Array, tile: Vector2i, terrain_id: String) -> void:
	var row = map_data[tile.y]
	if row is Array and tile.x >= 0 and tile.x < row.size():
		row[tile.x] = terrain_id
		map_data[tile.y] = row

static func _owner_id_at_raw(map_data: Array, terrain_grammar: Dictionary, tile: Vector2i) -> int:
	return terrain_owner_id_for_terrain(terrain_grammar, _terrain_at(map_data, tile))

static func _owner_id_at(map_data: Array, map_size: Vector2i, terrain_grammar: Dictionary, tile: Vector2i) -> int:
	var clamped := Vector2i(clampi(tile.x, 0, map_size.x - 1), clampi(tile.y, 0, map_size.y - 1))
	return _owner_id_at_raw(map_data, terrain_grammar, clamped)

static func _write_brush_terrain(tile: Vector2i, context: Dictionary, direct_write: bool, owner_write: bool) -> bool:
	var map_data: Array = context.get("map_data", [])
	var current := _terrain_at(map_data, tile)
	var brush_terrain_id := String(context.get("brush_terrain_id", ""))
	if current == brush_terrain_id:
		return false
	_set_terrain_at(map_data, tile, brush_terrain_id)
	_mark_changed(tile, context, "changed_tiles", "changed_keys")
	if direct_write:
		_mark_changed(tile, context, "direct_changed_tiles", "direct_changed_keys")
	if owner_write:
		_mark_changed(tile, context, "owner_changed_tiles", "owner_changed_keys")
	return true

static func _mark_changed(tile: Vector2i, context: Dictionary, list_key: String, map_key: String) -> void:
	var keys: Dictionary = context.get(map_key, {})
	var key := tile_key(tile)
	if keys.has(key):
		return
	keys[key] = true
	var tiles: Array = context.get(list_key, [])
	tiles.append(tile)
	context[list_key] = tiles
	context[map_key] = keys

static func _drain_terrain_placement_queues(changed_owner_cells: Array[Vector2i], context: Dictionary) -> void:
	for tile in changed_owner_cells:
		_rewrite_to_current_brush(tile, context, true)
	var map_size: Vector2i = context.get("map_size", Vector2i.ZERO)
	var guard := map_size.x * map_size.y * 128
	var set_a: OrderedPointSet = context.get("set_a")
	var set_b: OrderedPointSet = context.get("set_b")
	while guard > 0:
		while set_a.size() > 0 and guard > 0:
			guard -= 1
			_process_frontier_point(set_a.take_first(), context)
		while set_b.size() > 0 and guard > 0:
			guard -= 1
			var tile := set_b.take_first()
			if _should_rewrite_topology_point(tile, context):
				_rewrite_to_current_brush(tile, context, false)
		if set_a.size() == 0:
			break
	if guard == 0:
		context["queue_guard_exhausted"] = true

static func _rewrite_to_current_brush(tile: Vector2i, context: Dictionary, already_written: bool = false) -> bool:
	var map_size: Vector2i = context.get("map_size", Vector2i.ZERO)
	if not _in_bounds(tile, map_size):
		return false
	var map_data: Array = context.get("map_data", [])
	var terrain_grammar: Dictionary = context.get("terrain_grammar", {})
	var brush_owner_id := int(context.get("brush_owner_id", -1))
	if _owner_id_at_raw(map_data, terrain_grammar, tile) == brush_owner_id and not already_written:
		return false
	if _owner_id_at_raw(map_data, terrain_grammar, tile) != brush_owner_id:
		_write_brush_terrain(tile, context, false, true)

	var set_b: OrderedPointSet = context.get("set_b")
	set_b.erase(tile)
	if _trait_flag5(brush_owner_id) != 0:
		_maintain_normal_neighbor_frontier(tile, context)
	else:
		_maintain_special_neighbor_frontier(tile, context)
	if _should_rewrite_topology_point(tile, context):
		var set_a: OrderedPointSet = context.get("set_a")
		set_a.add(tile)
	else:
		_enqueue_secondary_candidates(tile, context)
	return true

static func _maintain_normal_neighbor_frontier(tile: Vector2i, context: Dictionary) -> void:
	var set_a: OrderedPointSet = context.get("set_a")
	for neighbor in [tile + Vector2i(0, -1), tile + Vector2i(0, 1)]:
		if set_a.has(neighbor) and not _is_horizontally_thin(neighbor, context):
			set_a.erase(neighbor)
			_enqueue_secondary_candidates(neighbor, context)
	for neighbor in [tile + Vector2i(-1, 0), tile + Vector2i(1, 0)]:
		if set_a.has(neighbor) and not _is_vertically_thin(neighbor, context):
			set_a.erase(neighbor)
			_enqueue_secondary_candidates(neighbor, context)

static func _maintain_special_neighbor_frontier(tile: Vector2i, context: Dictionary) -> void:
	var set_a: OrderedPointSet = context.get("set_a")
	var map_data: Array = context.get("map_data", [])
	var terrain_grammar: Dictionary = context.get("terrain_grammar", {})
	var brush_owner_id := int(context.get("brush_owner_id", -1))
	var map_size: Vector2i = context.get("map_size", Vector2i.ZERO)
	for offset in NEIGHBOR_OFFSETS:
		var offset_vector: Vector2i = offset
		var neighbor: Vector2i = tile + offset_vector
		if not _in_bounds(neighbor, map_size) or _owner_id_at_raw(map_data, terrain_grammar, neighbor) != brush_owner_id:
			continue
		var in_set_a := set_a.has(neighbor)
		var should_rewrite := _should_rewrite_topology_point(neighbor, context)
		if in_set_a and not should_rewrite:
			set_a.erase(neighbor)
			_enqueue_secondary_candidates(neighbor, context)
		elif not in_set_a and should_rewrite:
			set_a.add(neighbor)

static func _enqueue_secondary_candidates(tile: Vector2i, context: Dictionary) -> void:
	var set_b: OrderedPointSet = context.get("set_b")
	var map_data: Array = context.get("map_data", [])
	var terrain_grammar: Dictionary = context.get("terrain_grammar", {})
	var brush_owner_id := int(context.get("brush_owner_id", -1))
	var map_size: Vector2i = context.get("map_size", Vector2i.ZERO)
	for offset in CARDINAL_OFFSETS:
		var offset_vector: Vector2i = offset
		var neighbor: Vector2i = tile + offset_vector
		if _in_bounds(neighbor, map_size) and _owner_id_at_raw(map_data, terrain_grammar, neighbor) != brush_owner_id:
			set_b.add(neighbor)
	for offset in DIAGONAL_OFFSETS:
		var offset_vector: Vector2i = offset
		var neighbor: Vector2i = tile + offset_vector
		if not _in_bounds(neighbor, map_size):
			continue
		var neighbor_owner_id := _owner_id_at_raw(map_data, terrain_grammar, neighbor)
		if neighbor_owner_id != brush_owner_id and _trait_flag5(neighbor_owner_id) == 0:
			set_b.add(neighbor)

static func _process_frontier_point(tile: Vector2i, context: Dictionary) -> void:
	var map_data: Array = context.get("map_data", [])
	var terrain_grammar: Dictionary = context.get("terrain_grammar", {})
	var brush_owner_id := int(context.get("brush_owner_id", -1))
	var map_size: Vector2i = context.get("map_size", Vector2i.ZERO)
	if not _in_bounds(tile, map_size) or _owner_id_at_raw(map_data, terrain_grammar, tile) != brush_owner_id:
		return
	if _is_vertically_thin(tile, context):
		_rewrite_to_current_brush(_choose_vertical_frontier_target(tile, brush_owner_id, context), context, false)
	if _is_horizontally_thin(tile, context):
		_rewrite_to_current_brush(_choose_horizontal_frontier_target(tile, brush_owner_id, context), context, false)
	if _trait_flag5(brush_owner_id) != 0 or not _fragmented_same_owner_ring(tile, brush_owner_id, context):
		return
	for slot in _minimum_fragmented_gap(tile, brush_owner_id, context):
		_rewrite_to_current_brush(tile + NEIGHBOR_OFFSETS[int(slot)], context, false)

static func _choose_vertical_frontier_target(tile: Vector2i, brush_owner_id: int, context: Dictionary) -> Vector2i:
	var north := tile + Vector2i(0, -1)
	var south := tile + Vector2i(0, 1)
	if _should_rewrite_topology_point(north, context):
		return north
	if _should_rewrite_topology_point(south, context):
		return south
	if not _is_horizontally_thin_for_owner(north, brush_owner_id, context):
		return north
	if _is_horizontally_thin_for_owner(south, brush_owner_id, context):
		return north
	return south

static func _choose_horizontal_frontier_target(tile: Vector2i, brush_owner_id: int, context: Dictionary) -> Vector2i:
	var west := tile + Vector2i(-1, 0)
	var east := tile + Vector2i(1, 0)
	if _should_rewrite_topology_point(west, context):
		return west
	if _should_rewrite_topology_point(east, context):
		return east
	if not _is_vertically_thin_for_owner(west, brush_owner_id, context):
		return west
	if _is_vertically_thin_for_owner(east, brush_owner_id, context):
		return west
	return east

static func _should_rewrite_topology_point(tile: Vector2i, context: Dictionary) -> bool:
	var map_size: Vector2i = context.get("map_size", Vector2i.ZERO)
	if not _in_bounds(tile, map_size):
		return false
	var owner_id := _owner_id_at_raw(context.get("map_data", []), context.get("terrain_grammar", {}), tile)
	if owner_id < 0:
		return false
	if _is_horizontally_thin_for_owner(tile, owner_id, context) or _is_vertically_thin_for_owner(tile, owner_id, context):
		return true
	return _trait_flag5(owner_id) == 0 and _fragmented_same_owner_ring(tile, owner_id, context)

static func _is_horizontally_thin(tile: Vector2i, context: Dictionary) -> bool:
	var owner_id := _owner_id_at_raw(context.get("map_data", []), context.get("terrain_grammar", {}), tile)
	return _is_horizontally_thin_for_owner(tile, owner_id, context)

static func _is_vertically_thin(tile: Vector2i, context: Dictionary) -> bool:
	var owner_id := _owner_id_at_raw(context.get("map_data", []), context.get("terrain_grammar", {}), tile)
	return _is_vertically_thin_for_owner(tile, owner_id, context)

static func _is_horizontally_thin_for_owner(tile: Vector2i, owner_id: int, context: Dictionary) -> bool:
	var map_size: Vector2i = context.get("map_size", Vector2i.ZERO)
	if tile.x <= 0 or tile.x >= map_size.x - 1 or tile.y < 0 or tile.y >= map_size.y:
		return false
	var map_data: Array = context.get("map_data", [])
	var terrain_grammar: Dictionary = context.get("terrain_grammar", {})
	return _owner_id_at_raw(map_data, terrain_grammar, tile + Vector2i(-1, 0)) != owner_id and _owner_id_at_raw(map_data, terrain_grammar, tile + Vector2i(1, 0)) != owner_id

static func _is_vertically_thin_for_owner(tile: Vector2i, owner_id: int, context: Dictionary) -> bool:
	var map_size: Vector2i = context.get("map_size", Vector2i.ZERO)
	if tile.y <= 0 or tile.y >= map_size.y - 1 or tile.x < 0 or tile.x >= map_size.x:
		return false
	var map_data: Array = context.get("map_data", [])
	var terrain_grammar: Dictionary = context.get("terrain_grammar", {})
	return _owner_id_at_raw(map_data, terrain_grammar, tile + Vector2i(0, -1)) != owner_id and _owner_id_at_raw(map_data, terrain_grammar, tile + Vector2i(0, 1)) != owner_id

static func _minimum_fragmented_gap(tile: Vector2i, owner_id: int, context: Dictionary) -> Array[int]:
	var same := _same_owner_ring(tile, owner_id, context)
	if _ring_component_count(same) <= 1:
		return []
	var first_true := -1
	for index in range(same.size()):
		if bool(same[index]):
			first_true = index
			break
	if first_true < 0:
		return []
	var runs := []
	var cursor := (first_true + 1) & 7
	while cursor != first_true:
		if bool(same[cursor]):
			cursor = (cursor + 1) & 7
			continue
		var slots := []
		while not bool(same[cursor]):
			slots.append(cursor)
			cursor = (cursor + 1) & 7
			if cursor == first_true:
				break
		runs.append(slots)
	if runs.is_empty():
		return []
	runs.sort_custom(func(a: Array, b: Array) -> bool:
		return _gap_weight(a) < _gap_weight(b)
	)
	var result: Array[int] = []
	for slot in runs[0]:
		result.append(int(slot))
	return result

static func _fragmented_same_owner_ring(tile: Vector2i, owner_id: int, context: Dictionary) -> bool:
	return _ring_component_count(_same_owner_ring(tile, owner_id, context)) > 1

static func _same_owner_ring(tile: Vector2i, owner_id: int, context: Dictionary) -> Array:
	var map_size: Vector2i = context.get("map_size", Vector2i.ZERO)
	var map_data: Array = context.get("map_data", [])
	var terrain_grammar: Dictionary = context.get("terrain_grammar", {})
	var left := tile.x - 1 if tile.x > 0 else tile.x
	var right := tile.x + 1 if tile.x < map_size.x - 1 else tile.x
	var top := tile.y - 1 if tile.y > 0 else tile.y
	var bottom := tile.y + 1 if tile.y < map_size.y - 1 else tile.y
	var raw := [false, false, false, false, false, false, false, false]
	raw[0] = _owner_id_at_raw(map_data, terrain_grammar, Vector2i(tile.x, top)) == owner_id
	raw[2] = _owner_id_at_raw(map_data, terrain_grammar, Vector2i(right, tile.y)) == owner_id
	raw[4] = _owner_id_at_raw(map_data, terrain_grammar, Vector2i(tile.x, bottom)) == owner_id
	raw[6] = _owner_id_at_raw(map_data, terrain_grammar, Vector2i(left, tile.y)) == owner_id
	raw[1] = (raw[0] or raw[2]) and _owner_id_at_raw(map_data, terrain_grammar, Vector2i(right, top)) == owner_id
	raw[3] = (raw[2] or raw[4]) and _owner_id_at_raw(map_data, terrain_grammar, Vector2i(right, bottom)) == owner_id
	raw[5] = (raw[4] or raw[6]) and _owner_id_at_raw(map_data, terrain_grammar, Vector2i(left, bottom)) == owner_id
	raw[7] = (raw[6] or raw[0]) and _owner_id_at_raw(map_data, terrain_grammar, Vector2i(left, top)) == owner_id
	return raw

static func _ring_component_count(values: Array) -> int:
	var components := 0
	for index in range(values.size()):
		var previous := bool(values[(index + values.size() - 1) % values.size()])
		if bool(values[index]) and not previous:
			components += 1
	return components

static func _gap_weight(slots: Array) -> int:
	var weight := 0
	for slot in slots:
		weight += 2 if int(slot) % 2 == 0 else 1
	return weight

static func _compute_boundary_counts(map_data: Array, map_size: Vector2i, terrain_grammar: Dictionary) -> Array:
	var counts := []
	for _y in range(map_size.y):
		var row := []
		for _x in range(map_size.x):
			row.append(0)
		counts.append(row)
	for y in range(map_size.y):
		for x in range(map_size.x):
			var tile := Vector2i(x, y)
			var owner_id := _owner_id_at_raw(map_data, terrain_grammar, tile)
			for offset in BOUNDARY_ADJACENCIES:
				var offset_vector: Vector2i = offset
				var neighbor: Vector2i = tile + offset_vector
				if not _in_bounds(neighbor, map_size):
					continue
				if _owner_id_at_raw(map_data, terrain_grammar, neighbor) != owner_id:
					counts[y][x] = int(counts[y][x]) + 1
					counts[neighbor.y][neighbor.x] = int(counts[neighbor.y][neighbor.x]) + 1
	return counts

static func _boundary_count_for_cell(map_data: Array, map_size: Vector2i, terrain_grammar: Dictionary, tile: Vector2i) -> int:
	if not _in_bounds(tile, map_size):
		return 0
	var owner_id := _owner_id_at_raw(map_data, terrain_grammar, tile)
	var count := 0
	for offset in NEIGHBOR_OFFSETS:
		var offset_vector: Vector2i = offset
		var neighbor := tile + offset_vector
		if _in_bounds(neighbor, map_size) and _owner_id_at_raw(map_data, terrain_grammar, neighbor) != owner_id:
			count += 1
	return count

static func _relation_between_ids(center_id: int, neighbor_id: int) -> int:
	if center_id < 0 or neighbor_id < 0:
		return 0
	if center_id == neighbor_id:
		return 0
	if center_id == int(TERRAIN_FAMILY_IDS.get("sand", 1)):
		return 0
	if _trait_flag4(center_id) == 0:
		return 2
	if _trait_flag4(neighbor_id) == 0:
		return 2
	return 1 if center_id != int(TERRAIN_FAMILY_IDS.get("dirt", 0)) else 0

static func _relation_ring_for_cell(map_data: Array, map_size: Vector2i, terrain_grammar: Dictionary, tile: Vector2i) -> Array:
	var center_id := _owner_id_at(map_data, map_size, terrain_grammar, tile)
	var relations := []
	for offset in NEIGHBOR_OFFSETS:
		relations.append(_relation_between_ids(center_id, _owner_id_at(map_data, map_size, terrain_grammar, tile + offset)))
	return relations

static func _has_direct_water_rock_contact(map_data: Array, map_size: Vector2i, terrain_grammar: Dictionary, tile: Vector2i) -> bool:
	var owner_family := terrain_family_for_id_number(_owner_id_at_raw(map_data, terrain_grammar, tile))
	if owner_family != "water" and owner_family != "rock":
		return false
	var contact_family := "rock" if owner_family == "water" else "water"
	var contact_id := terrain_owner_id_for_family(contact_family)
	for offset in NEIGHBOR_OFFSETS:
		var offset_vector: Vector2i = offset
		if _owner_id_at(map_data, map_size, terrain_grammar, tile + offset_vector) == contact_id:
			return true
	return false

static func _classify_relations(relations: Array) -> Dictionary:
	for flags in FLAG_WORDS:
		var flag_word: Vector2i = flags
		var flag_a := flag_word.x
		var flag_b := flag_word.y
		if _relation_at(relations, flag_a, flag_b, 2) == 1 and _relation_at(relations, flag_a, flag_b, 4) == 1:
			if _relation_at(relations, flag_a, flag_b, 1) == 2 and _relation_at(relations, flag_a, flag_b, 5) == 2:
				return _class_result(28, flag_a, flag_b, "E=1,S=1,NE=2,SW=2")
			if _relation_at(relations, flag_a, flag_b, 3) == 2:
				return _class_result(27, flag_a, flag_b, "E=1,S=1,SE=2")
	for flags in FLAG_WORDS:
		var flag_word: Vector2i = flags
		var flag_a := flag_word.x
		var flag_b := flag_word.y
		if _relation_at(relations, flag_a, flag_b, 0) == 1 and _relation_at(relations, flag_a, flag_b, 6) == 1 and _relation_at(relations, flag_a, flag_b, 3) != 0:
			return _class_result(23 if _relation_at(relations, flag_a, flag_b, 3) == 1 else 25, flag_a, flag_b, "N=1,W=1,SE!=0")
		if _relation_at(relations, flag_a, flag_b, 0) == 2 and _relation_at(relations, flag_a, flag_b, 6) == 2 and _relation_at(relations, flag_a, flag_b, 3) != 0:
			return _class_result(26 if _relation_at(relations, flag_a, flag_b, 3) == 1 else 24, flag_a, flag_b, "N=2,W=2,SE!=0")
	for flags in FLAG_WORDS:
		var flag_word: Vector2i = flags
		var flag_a := flag_word.x
		var flag_b := flag_word.y
		if _relation_at(relations, flag_a, flag_b, 2) == 2 and _relation_at(relations, flag_a, flag_b, 4) == 1 and _relation_at(relations, flag_a, flag_b, 5) == 2:
			return _class_result(8, 1 - flag_a, 1 - flag_b, "E=2,S=1,SW=2; output flags inverted")
		if _relation_at(relations, flag_a, flag_b, 2) == 1 and _relation_at(relations, flag_a, flag_b, 4) == 2 and _relation_at(relations, flag_a, flag_b, 1) == 2:
			return _class_result(8, 1 - flag_a, 1 - flag_b, "E=1,S=2,NE=2; output flags inverted")
	for flags in FLAG_WORDS:
		var flag_word: Vector2i = flags
		var flag_a := flag_word.x
		var flag_b := flag_word.y
		if _relation_at(relations, flag_a, flag_b, 2) == 1 and _relation_at(relations, flag_a, flag_b, 4) == 1:
			if _relation_at(relations, flag_a, flag_b, 5) == 2:
				return _class_result(17, flag_a, flag_b, "E=1,S=1,SW=2")
			if _relation_at(relations, flag_a, flag_b, 1) == 2:
				return _class_result(18, flag_a, flag_b, "E=1,S=1,NE=2")
	for flags in FLAG_WORDS:
		var flag_word: Vector2i = flags
		var flag_a := flag_word.x
		var flag_b := flag_word.y
		if _relation_at(relations, flag_a, flag_b, 0) == 1 and _relation_at(relations, flag_a, flag_b, 6) == 1:
			return _class_result(2, flag_a, flag_b, "N=1,W=1")
		if _relation_at(relations, flag_a, flag_b, 0) == 2 and _relation_at(relations, flag_a, flag_b, 6) == 2:
			return _class_result(8, flag_a, flag_b, "N=2,W=2")
		if _relation_at(relations, flag_a, flag_b, 2) == 1 and _relation_at(relations, flag_a, flag_b, 5) == 2:
			return _class_result(17, flag_a, flag_b, "E=1,SW=2")
		if _relation_at(relations, flag_a, flag_b, 4) == 1 and _relation_at(relations, flag_a, flag_b, 1) == 2:
			return _class_result(18, flag_a, flag_b, "S=1,NE=2")
		if _relation_at(relations, flag_a, flag_b, 2) == 2 and _relation_at(relations, flag_a, flag_b, 5) == 1:
			return _class_result(21, flag_a, flag_b, "E=2,SW=1")
		if _relation_at(relations, flag_a, flag_b, 4) == 2 and _relation_at(relations, flag_a, flag_b, 1) == 1:
			return _class_result(22, flag_a, flag_b, "S=2,NE=1")
		if _relation_at(relations, flag_a, flag_b, 6) == 1 and _relation_at(relations, flag_a, flag_b, 1) == 1:
			return _class_result(2, flag_a, flag_b, "W=1,NE=1")
		if _relation_at(relations, flag_a, flag_b, 0) == 1 and _relation_at(relations, flag_a, flag_b, 5) == 1:
			return _class_result(2, flag_a, flag_b, "N=1,SW=1")
		if _relation_at(relations, flag_a, flag_b, 6) == 2 and _relation_at(relations, flag_a, flag_b, 1) == 2:
			return _class_result(8, flag_a, flag_b, "W=2,NE=2")
		if _relation_at(relations, flag_a, flag_b, 0) == 2 and _relation_at(relations, flag_a, flag_b, 5) == 2:
			return _class_result(8, flag_a, flag_b, "N=2,SW=2")
	for flags in FLAG_WORDS:
		var flag_word: Vector2i = flags
		var flag_a := flag_word.x
		var flag_b := flag_word.y
		if _relation_at(relations, flag_a, flag_b, 2) == 1 and _relation_at(relations, flag_a, flag_b, 3) == 2:
			return _class_result(19, flag_a, flag_b, "E=1,SE=2")
		if _relation_at(relations, flag_a, flag_b, 4) == 1 and _relation_at(relations, flag_a, flag_b, 3) == 2:
			return _class_result(20, flag_a, flag_b, "S=1,SE=2")
	for flags in FLAG_WORDS:
		var flag_word: Vector2i = flags
		var flag_a := flag_word.x
		var flag_b := flag_word.y
		if _relation_at(relations, flag_a, flag_b, 0) == 1:
			return _class_result(4, flag_a, flag_b, "N=1")
		if _relation_at(relations, flag_a, flag_b, 0) == 2:
			return _class_result(10, flag_a, flag_b, "N=2")
		if _relation_at(relations, flag_a, flag_b, 6) == 1:
			return _class_result(3, flag_a, flag_b, "W=1")
		if _relation_at(relations, flag_a, flag_b, 6) == 2:
			return _class_result(9, flag_a, flag_b, "W=2")
	for flags in FLAG_WORDS:
		var flag_word: Vector2i = flags
		var flag_a := flag_word.x
		var flag_b := flag_word.y
		if _relation_at(relations, flag_a, flag_b, 7) == 1 and _relation_at(relations, flag_a, flag_b, 3) == 1:
			return _class_result(14, flag_a, flag_b, "NW=1,SE=1")
		if _relation_at(relations, flag_a, flag_b, 7) == 1 and _relation_at(relations, flag_a, flag_b, 3) == 2:
			return _class_result(15, flag_a, flag_b, "NW=1,SE=2")
		if _relation_at(relations, flag_a, flag_b, 7) == 2 and _relation_at(relations, flag_a, flag_b, 3) == 2:
			return _class_result(16, flag_a, flag_b, "NW=2,SE=2")
	for flags in FLAG_WORDS:
		var flag_word: Vector2i = flags
		var flag_a := flag_word.x
		var flag_b := flag_word.y
		if _relation_at(relations, flag_a, flag_b, 3) == 1:
			return _class_result(5, flag_a, flag_b, "SE=1")
		if _relation_at(relations, flag_a, flag_b, 3) == 2:
			return _class_result(11, flag_a, flag_b, "SE=2")
	return _class_result(0, 0, 0, "no classed relation")

static func _class_result(class_code: int, flag_a: int, flag_b: int, reason: String) -> Dictionary:
	return {"class_code": class_code, "flag_a": flag_a, "flag_b": flag_b, "reason": reason}

static func _relation_at(relations: Array, flag_a: int, flag_b: int, slot: int) -> int:
	var perm = ORIENTATION_PERMS[flag_b + flag_a * 2]
	return int(relations[int(perm[slot])])

static func _apply_final_corrections(
	class_code: int,
	map_data: Array,
	map_size: Vector2i,
	terrain_grammar: Dictionary,
	tile: Vector2i,
	flag_a: int,
	flag_b: int
) -> Dictionary:
	if (class_code == 2 or class_code == 8) and _diagonal_probe_same_owner(map_data, map_size, terrain_grammar, tile, flag_a, flag_b):
		return {
			"class_code": 6 if class_code == 2 else 12,
			"correction": "%d->%d via diagonal same-owner probe" % [class_code, 6 if class_code == 2 else 12],
		}
	if (class_code == 5 or class_code == 11) and _two_step_probe_same_owner(map_data, map_size, terrain_grammar, tile, flag_a, flag_b):
		return {
			"class_code": 7 if class_code == 5 else 13,
			"correction": "%d->%d via two-step same-owner probe" % [class_code, 7 if class_code == 5 else 13],
		}
	return {"class_code": class_code, "correction": ""}

static func _diagonal_probe_same_owner(map_data: Array, map_size: Vector2i, terrain_grammar: Dictionary, tile: Vector2i, flag_a: int, flag_b: int) -> bool:
	var center_id := _owner_id_at_raw(map_data, terrain_grammar, tile)
	for offset in DIAGONAL_PROBE_OFFSETS.get("%d,%d" % [flag_a, flag_b], []):
		var neighbor: Vector2i = tile + offset
		if _in_bounds(neighbor, map_size) and _owner_id_at_raw(map_data, terrain_grammar, neighbor) == center_id:
			return true
	return false

static func _two_step_probe_same_owner(map_data: Array, map_size: Vector2i, terrain_grammar: Dictionary, tile: Vector2i, flag_a: int, flag_b: int) -> bool:
	var center_id := _owner_id_at_raw(map_data, terrain_grammar, tile)
	var offset: Vector2i = TWO_STEP_PROBE_OFFSETS.get("%d,%d" % [flag_a, flag_b], Vector2i.ZERO)
	var neighbor: Vector2i = tile + offset
	return _in_bounds(neighbor, map_size) and _owner_id_at_raw(map_data, terrain_grammar, neighbor) == center_id

static func _row_bucket_exists(owner_id: int, class_code: int) -> bool:
	var coverage = NORMAL_TABLE_CLASS_COVERAGE.get(owner_id, [])
	return coverage is Array and class_code in coverage

static func _select_visual_frame(owner_id: int, shape_class: int, flag_a: int, flag_b: int, tile: Vector2i) -> Dictionary:
	if owner_id == int(TERRAIN_FAMILY_IDS.get("rock", 9)):
		return _select_rock_visual_frame(shape_class, flag_a, flag_b, tile)
	return _select_normal_visual_frame(owner_id, shape_class, flag_a, flag_b, tile)

static func _select_normal_visual_frame(owner_id: int, shape_class: int, flag_a: int, flag_b: int, tile: Vector2i) -> Dictionary:
	var table_name := String(NORMAL_TABLE_BY_OWNER_ID.get(owner_id, ""))
	var row_entry = _normal_row_entry(table_name, shape_class)
	if _row_entry_empty(row_entry):
		var fallback_rows := _full_rows_for_normal_table(table_name, owner_id, tile)
		var fallback_frame := _choose_visual_frame(fallback_rows.get("rows", []), tile.x, tile.y, "%d:missing:%d" % [owner_id, shape_class])
		return {
			"frame": fallback_frame,
			"output_flag_a": 0,
			"output_flag_b": 0,
			"row_group": compact_ranges(fallback_rows.get("rows", [])),
			"row_source": "%s missing class %d; fallback full rows %s" % [table_name, shape_class, compact_ranges(fallback_rows.get("rows", []))],
			"row_table": table_name,
			"fallback": true,
			"fallback_reason": "missing row bucket for terrain %d class %d" % [owner_id, shape_class],
		}
	if shape_class == 0:
		var full := _full_rows_for_normal_table(table_name, owner_id, tile)
		return {
			"frame": _choose_visual_frame(full.get("rows", []), tile.x, tile.y, "%d:full:%s" % [owner_id, String(full.get("bucket", ""))]),
			"output_flag_a": 0,
			"output_flag_b": 0,
			"row_group": compact_ranges(full.get("rows", [])),
			"row_source": "%s class 0 %s rows %s" % [table_name, String(full.get("bucket", "")), compact_ranges(full.get("rows", []))],
			"row_table": table_name,
			"fallback": false,
			"fallback_reason": "",
		}
	var rows: Array = row_entry if row_entry is Array else []
	return {
		"frame": _choose_visual_frame(rows, tile.x, tile.y, "%d:class:%d" % [owner_id, shape_class]),
		"output_flag_a": flag_a,
		"output_flag_b": flag_b,
		"row_group": compact_ranges(rows),
		"row_source": "%s class %d rows %s" % [table_name, shape_class, compact_ranges(rows)],
		"row_table": table_name,
		"fallback": false,
		"fallback_reason": "",
	}

static func _select_rock_visual_frame(shape_class: int, flag_a: int, flag_b: int, tile: Vector2i) -> Dictionary:
	var by_flags = ROCK_ROWS.get(shape_class, {})
	var flag_key := "%d,%d" % [flag_a, flag_b]
	var rows = by_flags.get(flag_key, []) if by_flags is Dictionary else []
	if not (rows is Array) or rows.is_empty():
		var fallback_rows: Array = ROCK_ROWS.get(0, {}).get("0,0", [0]) if ROCK_ROWS.get(0, {}) is Dictionary else [0]
		return {
			"frame": _choose_visual_frame(fallback_rows, tile.x, tile.y, "rock:missing:%d:%d:%d" % [shape_class, flag_a, flag_b]),
			"output_flag_a": 0,
			"output_flag_b": 0,
			"row_group": compact_ranges(fallback_rows),
			"row_source": "rock missing class %d flags %d,%d; fallback rows %s" % [shape_class, flag_a, flag_b, compact_ranges(fallback_rows)],
			"row_table": "rock",
			"fallback": true,
			"fallback_reason": "missing rock row bucket for class %d flags %d,%d" % [shape_class, flag_a, flag_b],
		}
	return {
		"frame": _choose_visual_frame(rows, tile.x, tile.y, "rock:%d:%d:%d" % [shape_class, flag_a, flag_b]),
		"output_flag_a": 0,
		"output_flag_b": 0,
		"row_group": compact_ranges(rows),
		"row_source": "rock class %d requested flags %d,%d rows %s; stored flags cleared" % [shape_class, flag_a, flag_b, compact_ranges(rows)],
		"row_table": "rock",
		"fallback": false,
		"fallback_reason": "",
	}

static func _normal_row_entry(table_name: String, shape_class: int):
	match table_name:
		"normal79":
			return NORMAL79_ROWS.get(shape_class)
		"dirt":
			return DIRT_ROWS.get(shape_class)
		"sand":
			return SAND_ROWS.get(shape_class)
		"water":
			return WATER_ROWS.get(shape_class)
	return null

static func _row_entry_empty(row_entry) -> bool:
	if row_entry == null:
		return true
	if row_entry is Array:
		return row_entry.is_empty()
	if row_entry is Dictionary:
		var ordinary = row_entry.get("ordinary", [])
		var special = row_entry.get("special", [])
		return (not (ordinary is Array) or ordinary.is_empty()) and (not (special is Array) or special.is_empty())
	return true

static func _full_rows_for_normal_table(table_name: String, owner_id: int, tile: Vector2i) -> Dictionary:
	var row_entry = _normal_row_entry(table_name, 0)
	if not (row_entry is Dictionary):
		return {"rows": [0], "bucket": "fallback"}
	var ordinary = row_entry.get("ordinary", [])
	var special = row_entry.get("special", [])
	var ordinary_rows: Array = ordinary if ordinary is Array else []
	var special_rows: Array = special if special is Array else []
	var frequency := _special_tile_frequency(owner_id)
	var use_special := not special_rows.is_empty() and _positive_visual_hash("special:%d:%d:%d" % [owner_id, tile.x, tile.y]) % 100 < frequency
	if use_special:
		return {"rows": special_rows, "bucket": "special"}
	return {"rows": ordinary_rows if not ordinary_rows.is_empty() else special_rows, "bucket": "ordinary"}

static func _special_tile_frequency(owner_id: int) -> int:
	if owner_id >= 0 and owner_id < SPECIAL_TILE_FREQ.size():
		return int(SPECIAL_TILE_FREQ[owner_id])
	return 0

static func _choose_visual_frame(rows: Array, x: int, y: int, salt: String) -> int:
	if rows.is_empty():
		return 0
	var index := _positive_visual_hash("%s:%d:%d" % [salt, x, y]) % rows.size()
	return int(rows[index])

static func _positive_visual_hash(text: String) -> int:
	return absi(_visual_hash(text))

static func _visual_hash(text: String) -> int:
	var hash_value := 2166136261
	for index in range(text.length()):
		hash_value = hash_value ^ text.unicode_at(index)
		hash_value = (hash_value * 16777619) & 0xffffffff
	if hash_value >= 0x80000000:
		hash_value -= 0x100000000
	return hash_value

static func _bridge_family_from_relations(relations: Array) -> String:
	var has_relation_1 := false
	var has_relation_2 := false
	for relation in relations:
		if int(relation) == 1:
			has_relation_1 = true
		elif int(relation) == 2:
			has_relation_2 = true
	if has_relation_1 and has_relation_2:
		return "mixed"
	if has_relation_2:
		return "sand"
	if has_relation_1:
		return "dirt"
	return ""

static func _visual_frame_block_for(owner_family: String, frame_number: int, shape_class: int) -> String:
	if shape_class == 0:
		match owner_family:
			"dirt":
				return "dirt_base_interiors"
			"sand":
				return "sand_base_interiors"
			"water":
				return "water_interiors"
			"rock":
				return "rock_void_interiors"
		return "native_interiors"
	match owner_family:
		"dirt":
			return "dirt_to_sand_transition"
		"water":
			return "shoreline_frames"
		"rock":
			return "rock_light_ground_context"
		"sand":
			return "sand_base_interiors"
	if frame_number >= 0 and frame_number <= 19:
		return "native_to_dirt_transition"
	if frame_number >= 20 and frame_number <= 39:
		return "native_to_sand_transition"
	return "mixed_junction_reserved"

static func relation_grid_string(relations: Array) -> String:
	if relations.size() < 8:
		return ""
	return "%d%d%d/%dC%d/%d%d%d" % [
		int(relations[7]),
		int(relations[0]),
		int(relations[1]),
		int(relations[6]),
		int(relations[2]),
		int(relations[5]),
		int(relations[4]),
		int(relations[3]),
	]

static func compact_ranges(indices: Array) -> String:
	if indices.is_empty():
		return "-"
	var sorted := indices.duplicate()
	sorted.sort()
	var ranges := []
	var range_start := int(sorted[0])
	var previous := int(sorted[0])
	for value_index in range(1, sorted.size()):
		var value := int(sorted[value_index])
		if value == previous + 1:
			previous = value
			continue
		ranges.append(str(range_start) if range_start == previous else "%d-%d" % [range_start, previous])
		range_start = value
		previous = value
	ranges.append(str(range_start) if range_start == previous else "%d-%d" % [range_start, previous])
	return ",".join(ranges)

static func _trait_flag4(owner_id: int) -> int:
	if owner_id >= 0 and owner_id < TRAIT_FLAG4.size():
		return int(TRAIT_FLAG4[owner_id])
	return 1

static func _trait_flag5(owner_id: int) -> int:
	if owner_id >= 0 and owner_id < TRAIT_FLAG5.size():
		return int(TRAIT_FLAG5[owner_id])
	return 1
