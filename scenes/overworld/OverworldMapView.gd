extends Control

signal tile_pressed(tile: Vector2i)
signal tile_hovered(tile: Vector2i)

const HeroCommandRulesScript = preload("res://scripts/core/HeroCommandRules.gd")
const OverworldRulesScript = preload("res://scripts/core/OverworldRules.gd")

const MAP_PADDING := 22.0
const GRID_COLOR := Color(0.08, 0.10, 0.12, 0.55)
const FRAME_COLOR := Color(0.73, 0.63, 0.42, 0.9)
const FRAME_FILL := Color(0.07, 0.10, 0.11, 1.0)
const UNEXPLORED_COLOR := Color(0.04, 0.05, 0.06, 1.0)
const MEMORY_OVERLAY := Color(0.05, 0.07, 0.09, 0.62)
const SELECTION_COLOR := Color(0.98, 0.87, 0.46, 1.0)
const HOVER_COLOR := Color(0.92, 0.95, 0.98, 0.55)
const HERO_RING_COLOR := Color(0.98, 0.94, 0.72, 1.0)
const HERO_FILL_COLOR := Color(0.88, 0.32, 0.21, 1.0)
const RESERVE_HERO_COLOR := Color(0.87, 0.90, 0.94, 1.0)
const ROUTE_COLOR := Color(0.97, 0.86, 0.43, 0.92)
const ROUTE_BLOCKED_COLOR := Color(0.87, 0.43, 0.33, 0.92)
const TERRAIN_COLORS := {
	"grass": Color(0.41, 0.62, 0.31, 1.0),
	"forest": Color(0.23, 0.43, 0.25, 1.0),
	"water": Color(0.20, 0.41, 0.66, 1.0),
}
const TERRAIN_MEMORY_COLORS := {
	"grass": Color(0.18, 0.24, 0.18, 1.0),
	"forest": Color(0.13, 0.18, 0.13, 1.0),
	"water": Color(0.11, 0.17, 0.24, 1.0),
}
const PLAYER_TOWN_COLOR := Color(0.84, 0.68, 0.30, 1.0)
const ENEMY_TOWN_COLOR := Color(0.72, 0.28, 0.26, 1.0)
const NEUTRAL_TOWN_COLOR := Color(0.56, 0.59, 0.64, 1.0)
const RESOURCE_COLOR := Color(0.28, 0.83, 0.62, 1.0)
const ARTIFACT_COLOR := Color(0.95, 0.68, 0.31, 1.0)
const ENCOUNTER_COLOR := Color(0.90, 0.44, 0.35, 1.0)
const DIRECTIONS := [
	Vector2i.LEFT,
	Vector2i.RIGHT,
	Vector2i.UP,
	Vector2i.DOWN,
]

var _session = null
var _map_data: Array = []
var _map_size := Vector2i.ONE
var _selected_tile := Vector2i(-1, -1)
var _hover_tile := Vector2i(-1, -1)
var _hero_tile := Vector2i.ZERO
var _path_tiles: Array = []
var _movement_left := 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(640, 400)

func set_map_state(session, map_data: Array, map_size: Vector2i, selected_tile: Vector2i) -> void:
	_session = session
	_map_data = map_data.duplicate(true)
	_map_size = Vector2i(max(map_size.x, 1), max(map_size.y, 1))
	_hero_tile = OverworldRulesScript.hero_position(session) if session != null else Vector2i.ZERO
	_movement_left = int(session.overworld.get("movement", {}).get("current", 0)) if session != null else 0
	_selected_tile = selected_tile
	_path_tiles = _build_path(_hero_tile, _selected_tile)
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
	elif what == NOTIFICATION_MOUSE_EXIT:
		if _hover_tile.x >= 0:
			_hover_tile = Vector2i(-1, -1)
			tile_hovered.emit(_hover_tile)
			queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var tile = _tile_from_local(event.position)
		if tile != _hover_tile:
			_hover_tile = tile
			tile_hovered.emit(tile)
			queue_redraw()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var tile = _tile_from_local(event.position)
		if tile.x >= 0:
			tile_pressed.emit(tile)
			accept_event()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), FRAME_FILL, true)
	if _session == null:
		return

	var board_rect = _board_rect()
	var frame_rect = board_rect.grow(12.0)
	draw_rect(frame_rect, Color(0.02, 0.03, 0.04, 0.85), true)
	draw_rect(frame_rect, FRAME_COLOR, false, 3.0)

	for y in range(_map_size.y):
		for x in range(_map_size.x):
			var tile = Vector2i(x, y)
			var rect = _tile_rect(board_rect, tile)
			_draw_tile_background(tile, rect)

	_draw_route(board_rect)

	for y in range(_map_size.y):
		for x in range(_map_size.x):
			var tile = Vector2i(x, y)
			var rect = _tile_rect(board_rect, tile)
			_draw_tile_focus(tile, rect)
			_draw_tile_icon(tile, rect)

func _draw_tile_background(tile: Vector2i, rect: Rect2) -> void:
	if not OverworldRulesScript.is_tile_explored(_session, tile.x, tile.y):
		draw_rect(rect, UNEXPLORED_COLOR, true)
		draw_line(rect.position + Vector2(6.0, 6.0), rect.end - Vector2(6.0, 6.0), Color(0.19, 0.20, 0.22, 0.45), 2.0)
		draw_line(
			Vector2(rect.position.x + rect.size.x - 6.0, rect.position.y + 6.0),
			Vector2(rect.position.x + 6.0, rect.position.y + rect.size.y - 6.0),
			Color(0.19, 0.20, 0.22, 0.45),
			2.0
		)
		draw_rect(rect, GRID_COLOR, false, 1.0)
		return

	var visible = OverworldRulesScript.is_tile_visible(_session, tile.x, tile.y)
	var terrain = _terrain_at(tile)
	var base_color: Color = TERRAIN_COLORS.get(terrain, TERRAIN_COLORS["grass"])
	if not visible:
		base_color = TERRAIN_MEMORY_COLORS.get(terrain, TERRAIN_MEMORY_COLORS["grass"])
	draw_rect(rect, base_color, true)

	match terrain:
		"forest":
			_draw_forest_pattern(rect, visible)
		"water":
			_draw_water_pattern(rect, visible)
		_:
			_draw_grass_pattern(rect, visible)

	if not visible:
		draw_rect(rect, MEMORY_OVERLAY, true)
	draw_rect(rect, GRID_COLOR, false, 1.0)

func _draw_grass_pattern(rect: Rect2, visible: bool) -> void:
	var color = Color(0.69, 0.84, 0.43, 0.18 if visible else 0.10)
	var top = rect.position + rect.size * Vector2(0.24, 0.30)
	var bottom = rect.position + rect.size * Vector2(0.58, 0.66)
	draw_circle(top, rect.size.x * 0.08, color)
	draw_circle(bottom, rect.size.x * 0.06, color)

func _draw_forest_pattern(rect: Rect2, visible: bool) -> void:
	var tree_color = Color(0.12, 0.22, 0.13, 0.60 if visible else 0.35)
	var trunk_color = Color(0.33, 0.24, 0.13, 0.60 if visible else 0.30)
	for offset in [0.28, 0.52, 0.74]:
		var center = rect.position + rect.size * Vector2(offset, 0.48)
		var half_width = rect.size.x * 0.10
		var crown = PackedVector2Array([
			center + Vector2(0.0, -rect.size.y * 0.18),
			center + Vector2(half_width, rect.size.y * 0.02),
			center + Vector2(-half_width, rect.size.y * 0.02),
		])
		draw_colored_polygon(crown, tree_color)
		draw_rect(Rect2(center + Vector2(-2.0, rect.size.y * 0.02), Vector2(4.0, rect.size.y * 0.12)), trunk_color, true)

func _draw_water_pattern(rect: Rect2, visible: bool) -> void:
	var wave_color = Color(0.80, 0.90, 1.0, 0.28 if visible else 0.14)
	for row in [0.34, 0.62]:
		var start = rect.position + rect.size * Vector2(0.16, row)
		var end = rect.position + rect.size * Vector2(0.84, row)
		draw_line(start, end, wave_color, 2.0)
		draw_line(start + Vector2(rect.size.x * 0.12, -rect.size.y * 0.08), end - Vector2(rect.size.x * 0.12, -rect.size.y * 0.08), wave_color, 2.0)

func _draw_route(board_rect: Rect2) -> void:
	if _path_tiles.size() <= 1:
		return
	var selected_visible = OverworldRulesScript.is_tile_explored(_session, _selected_tile.x, _selected_tile.y)
	if not selected_visible:
		return
	var line_color = ROUTE_COLOR if (_path_tiles.size() - 1) <= _movement_left else ROUTE_BLOCKED_COLOR
	var points = PackedVector2Array()
	for tile_value in _path_tiles:
		if not (tile_value is Vector2i):
			continue
		points.append(_tile_rect(board_rect, tile_value).get_center())
	if points.size() <= 1:
		return
	draw_polyline(points, line_color, 5.0)
	for point in points:
		draw_circle(point, 4.0, line_color)

func _draw_tile_focus(tile: Vector2i, rect: Rect2) -> void:
	if tile == _hero_tile:
		draw_rect(rect.grow(-2.0), HERO_RING_COLOR, false, 3.0)

	if tile == _selected_tile:
		draw_rect(rect.grow(-4.0), SELECTION_COLOR, false, 3.0)

	if tile == _hover_tile:
		draw_rect(rect.grow(-7.0), HOVER_COLOR, false, 2.0)

func _draw_tile_icon(tile: Vector2i, rect: Rect2) -> void:
	if not OverworldRulesScript.is_tile_visible(_session, tile.x, tile.y):
		return

	if _has_town_at(tile):
		_draw_town_marker(rect, _town_color(tile))
	if _has_resource_at(tile):
		_draw_resource_marker(rect)
	if _has_artifact_at(tile):
		_draw_artifact_marker(rect)
	if _has_encounter_at(tile):
		_draw_encounter_marker(rect)
	if _has_hero_at(tile):
		_draw_hero_marker(rect, tile)

func _draw_town_marker(rect: Rect2, color: Color) -> void:
	var body = Rect2(
		rect.position + rect.size * Vector2(0.24, 0.36),
		rect.size * Vector2(0.52, 0.30)
	)
	draw_rect(body, color, true)
	draw_rect(body, Color(0.08, 0.09, 0.12, 0.8), false, 2.0)
	for step in [0.26, 0.43, 0.60]:
		var battlement = Rect2(
			rect.position + rect.size * Vector2(step, 0.26),
			rect.size * Vector2(0.10, 0.10)
		)
		draw_rect(battlement, color, true)
	var flag_start = rect.position + rect.size * Vector2(0.68, 0.18)
	var flag_end = rect.position + rect.size * Vector2(0.68, 0.40)
	draw_line(flag_end, flag_start, Color(0.93, 0.91, 0.82, 0.9), 2.0)
	var flag = PackedVector2Array([
		flag_start,
		flag_start + rect.size * Vector2(0.13, 0.04),
		flag_start + rect.size * Vector2(0.00, 0.11),
	])
	draw_colored_polygon(flag, Color(0.96, 0.90, 0.67, 0.95))

func _draw_resource_marker(rect: Rect2) -> void:
	var center = rect.get_center()
	var radius = rect.size.x * 0.12
	var diamond = PackedVector2Array([
		center + Vector2(0.0, -radius),
		center + Vector2(radius, 0.0),
		center + Vector2(0.0, radius),
		center + Vector2(-radius, 0.0),
	])
	draw_colored_polygon(diamond, RESOURCE_COLOR)
	var diamond_outline = PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]])
	draw_polyline(diamond_outline, Color(0.07, 0.10, 0.12, 0.85), 2.0)

func _draw_artifact_marker(rect: Rect2) -> void:
	var center = rect.get_center()
	var outer = rect.size.x * 0.13
	var inner = rect.size.x * 0.05
	var points = PackedVector2Array([
		center + Vector2(0.0, -outer),
		center + Vector2(inner, -inner),
		center + Vector2(outer, 0.0),
		center + Vector2(inner, inner),
		center + Vector2(0.0, outer),
		center + Vector2(-inner, inner),
		center + Vector2(-outer, 0.0),
		center + Vector2(-inner, -inner),
	])
	draw_colored_polygon(points, ARTIFACT_COLOR)
	var star_outline = PackedVector2Array([
		points[0],
		points[1],
		points[2],
		points[3],
		points[4],
		points[5],
		points[6],
		points[7],
		points[0],
	])
	draw_polyline(star_outline, Color(0.15, 0.10, 0.05, 0.9), 2.0)

func _draw_encounter_marker(rect: Rect2) -> void:
	var center = rect.get_center()
	var extent = rect.size.x * 0.16
	draw_line(center + Vector2(-extent, -extent), center + Vector2(extent, extent), ENCOUNTER_COLOR, 4.0)
	draw_line(center + Vector2(extent, -extent), center + Vector2(-extent, extent), ENCOUNTER_COLOR, 4.0)
	draw_circle(center, rect.size.x * 0.05, Color(0.98, 0.94, 0.79, 1.0))

func _draw_hero_marker(rect: Rect2, tile: Vector2i) -> void:
	var center = rect.get_center()
	var base_radius = rect.size.x * 0.13
	draw_circle(center + Vector2(0.0, rect.size.y * 0.06), base_radius, HERO_FILL_COLOR)
	draw_circle(center + Vector2(0.0, rect.size.y * 0.06), base_radius, HERO_RING_COLOR, false, 2.5)
	draw_line(center + Vector2(base_radius, rect.size.y * 0.06), center + Vector2(base_radius, -rect.size.y * 0.20), HERO_RING_COLOR, 2.5)
	var banner = PackedVector2Array([
		center + Vector2(base_radius, -rect.size.y * 0.20),
		center + Vector2(base_radius + rect.size.x * 0.16, -rect.size.y * 0.14),
		center + Vector2(base_radius, -rect.size.y * 0.06),
	])
	draw_colored_polygon(banner, Color(0.95, 0.73, 0.25, 0.95))

	var reserve_count = _reserve_hero_count(tile)
	if reserve_count <= 0:
		return
	var marker_center = rect.position + rect.size * Vector2(0.78, 0.25)
	draw_circle(marker_center, rect.size.x * 0.10, RESERVE_HERO_COLOR)
	draw_circle(marker_center, rect.size.x * 0.10, Color(0.07, 0.10, 0.12, 0.9), false, 2.0)
	for index in range(min(reserve_count, 3)):
		var dot_pos = marker_center + Vector2((index - 1) * 5.0, 0.0)
		draw_circle(dot_pos, 1.8, Color(0.12, 0.14, 0.17, 1.0))

func _board_rect() -> Rect2:
	var available = size - Vector2(MAP_PADDING * 2.0, MAP_PADDING * 2.0)
	var tile_extent: float = floor(min(available.x / float(max(_map_size.x, 1)), available.y / float(max(_map_size.y, 1))))
	tile_extent = max(tile_extent, 24.0)
	var board_size = Vector2(tile_extent * _map_size.x, tile_extent * _map_size.y)
	var board_position = ((size - board_size) * 0.5).floor()
	return Rect2(board_position, board_size)

func _tile_rect(board_rect: Rect2, tile: Vector2i) -> Rect2:
	var cell_size = board_rect.size / Vector2(float(max(_map_size.x, 1)), float(max(_map_size.y, 1)))
	return Rect2(
		board_rect.position + Vector2(tile.x * cell_size.x, tile.y * cell_size.y),
		cell_size
	)

func _tile_from_local(local_position: Vector2) -> Vector2i:
	var board_rect = _board_rect()
	if not board_rect.has_point(local_position):
		return Vector2i(-1, -1)
	var cell_size = board_rect.size / Vector2(float(max(_map_size.x, 1)), float(max(_map_size.y, 1)))
	var x = int(floor((local_position.x - board_rect.position.x) / cell_size.x))
	var y = int(floor((local_position.y - board_rect.position.y) / cell_size.y))
	if x < 0 or y < 0 or x >= _map_size.x or y >= _map_size.y:
		return Vector2i(-1, -1)
	return Vector2i(x, y)

func _terrain_at(tile: Vector2i) -> String:
	if tile.y < 0 or tile.y >= _map_data.size():
		return ""
	var row = _map_data[tile.y]
	if not (row is Array) or tile.x < 0 or tile.x >= row.size():
		return ""
	return String(row[tile.x])

func _has_town_at(tile: Vector2i) -> bool:
	return not _town_at(tile).is_empty()

func _town_at(tile: Vector2i) -> Dictionary:
	for town in _session.overworld.get("towns", []):
		if town is Dictionary and int(town.get("x", -1)) == tile.x and int(town.get("y", -1)) == tile.y:
			return town
	return {}

func _town_color(tile: Vector2i) -> Color:
	var town = _town_at(tile)
	match String(town.get("owner", "neutral")):
		"player":
			return PLAYER_TOWN_COLOR
		"enemy":
			return ENEMY_TOWN_COLOR
		_:
			return NEUTRAL_TOWN_COLOR

func _has_resource_at(tile: Vector2i) -> bool:
	for node in _session.overworld.get("resource_nodes", []):
		if not (node is Dictionary):
			continue
		if int(node.get("x", -1)) != tile.x or int(node.get("y", -1)) != tile.y:
			continue
		var site = ContentService.get_resource_site(String(node.get("site_id", "")))
		if bool(site.get("persistent_control", false)) or not bool(node.get("collected", false)):
			return true
	return false

func _has_artifact_at(tile: Vector2i) -> bool:
	for node in _session.overworld.get("artifact_nodes", []):
		if node is Dictionary and not bool(node.get("collected", false)) and int(node.get("x", -1)) == tile.x and int(node.get("y", -1)) == tile.y:
			return true
	return false

func _has_encounter_at(tile: Vector2i) -> bool:
	for encounter in _session.overworld.get("encounters", []):
		if not (encounter is Dictionary):
			continue
		if int(encounter.get("x", -1)) != tile.x or int(encounter.get("y", -1)) != tile.y:
			continue
		if not OverworldRulesScript.is_encounter_resolved(_session, encounter):
			return true
	return false

func _has_hero_at(tile: Vector2i) -> bool:
	for entry in HeroCommandRulesScript.hero_positions(_session):
		if entry is Dictionary and int(entry.get("x", -1)) == tile.x and int(entry.get("y", -1)) == tile.y:
			return true
	return false

func _reserve_hero_count(tile: Vector2i) -> int:
	var reserve_count = 0
	for entry in HeroCommandRulesScript.hero_positions(_session):
		if not (entry is Dictionary):
			continue
		if int(entry.get("x", -1)) != tile.x or int(entry.get("y", -1)) != tile.y:
			continue
		if not bool(entry.get("is_active", false)):
			reserve_count += 1
	return reserve_count

func _build_path(start: Vector2i, goal: Vector2i) -> Array:
	if _session == null or goal.x < 0 or goal.y < 0:
		return []
	if start == goal:
		return [start]
	if goal.x >= _map_size.x or goal.y >= _map_size.y:
		return []
	if OverworldRulesScript.tile_is_blocked(_session, goal.x, goal.y):
		return []
	if not OverworldRulesScript.is_tile_explored(_session, goal.x, goal.y):
		return []

	var queue: Array = [start]
	var visited = {_tile_key(start): true}
	var came_from = {_tile_key(start): start}
	var found = false

	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		if current == goal:
			found = true
			break
		for direction in DIRECTIONS:
			var next: Vector2i = current + direction
			if next.x < 0 or next.y < 0 or next.x >= _map_size.x or next.y >= _map_size.y:
				continue
			if OverworldRulesScript.tile_is_blocked(_session, next.x, next.y):
				continue
			var key = _tile_key(next)
			if visited.has(key):
				continue
			visited[key] = true
			came_from[key] = current
			queue.append(next)

	if not found:
		return []

	var path: Array = [goal]
	var walker: Vector2i = goal
	while walker != start:
		walker = came_from.get(_tile_key(walker), start)
		path.push_front(walker)
	return path

func _tile_key(tile: Vector2i) -> String:
	return "%d,%d" % [tile.x, tile.y]
