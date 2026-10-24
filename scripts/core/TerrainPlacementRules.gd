class_name TerrainPlacementRules
extends RefCounted

const HumanEngine = preload("res://scripts/core/HumanEngine.gd")

const PLACEMENT_MODEL := "homm3_owner_queue_rewrite_final_normalization.v1"
const PAINT_ORDER_MODEL := "paint_tiles_in_tool_order_then_drain_set_a_set_b"
const FINAL_NORMALIZATION_MODEL := "final_normalization_4bbfcc_reclassifies_settled_owner_map"
const VISUAL_SELECTION_MODEL := "accepted_web_prototype_relation_class_row_lookup.v1"
const VISUAL_FRAME_SELECTION_SOURCE := "accepted_web_prototype_and_recovered_h3maped_final_normalization"
const VISUAL_PROJECTION_MODEL := "accepted_web_prototype_cardinal_material_projection.v1"

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
const FULL_LAND_FAMILIES := ["grass", "snow", "swamp", "rough", "subterranean", "lava"]
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
const CARDINAL_PROJECTION_EDGES := [
	{"offset": Vector2i(0, -1), "quadrants": [0, 1]},
	{"offset": Vector2i(1, 0), "quadrants": [1, 3]},
	{"offset": Vector2i(0, 1), "quadrants": [2, 3]},
	{"offset": Vector2i(-1, 0), "quadrants": [0, 2]},
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

static func apply_paint(map_data: Array, map_size: Vector2i, brush_terrain_id: String, paint_tiles: Array, terrain_grammar: Dictionary, include_final_normalization: bool = true) -> Dictionary:
	return HumanEngine.native_writing(&"TerrainPlacementRules.apply_paint", [map_data, map_size, brush_terrain_id, paint_tiles, terrain_grammar, include_final_normalization])

static func final_normalization_payload(map_data: Array, map_size: Vector2i, terrain_grammar: Dictionary) -> Dictionary:
	return HumanEngine.native_writing(&"TerrainPlacementRules.final_normalization_payload", [map_data, map_size, terrain_grammar])

static func visual_selection_payload(map_data: Array, map_size: Vector2i, terrain_grammar: Dictionary, tile: Vector2i) -> Dictionary:
	return HumanEngine.native_writing(&"TerrainPlacementRules.visual_selection_payload", [map_data, map_size, terrain_grammar, tile])
