class_name TerrainPlacementRules
extends RefCounted

const PLACEMENT_MODEL := "homm3_owner_queue_rewrite_final_normalization.v1"
const PAINT_ORDER_MODEL := "paint_tiles_in_tool_order_then_drain_set_a_set_b"
const FINAL_NORMALIZATION_MODEL := "final_normalization_4bbfcc_reclassifies_settled_owner_map"

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

static func _trait_flag4(owner_id: int) -> int:
	if owner_id >= 0 and owner_id < TRAIT_FLAG4.size():
		return int(TRAIT_FLAG4[owner_id])
	return 1

static func _trait_flag5(owner_id: int) -> int:
	if owner_id >= 0 and owner_id < TRAIT_FLAG5.size():
		return int(TRAIT_FLAG5[owner_id])
	return 1
