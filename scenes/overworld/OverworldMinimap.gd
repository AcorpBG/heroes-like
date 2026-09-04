extends Control

signal recenter_requested(tile: Vector2i)

const OverworldRulesScript = preload("res://scripts/core/OverworldRules.gd")

const TERRAIN_COLORS := {
	"grass": Color("496b3e"),
	"dirt": Color("765638"),
	"sand": Color("92754a"),
	"snow": Color("a7b1ad"),
	"swamp": Color("344f43"),
	"rough": Color("695f50"),
	"lava": Color("6d3328"),
	"water": Color("284f66"),
	"subterranean": Color("3b353b"),
}
const UNEXPLORED_COLOR := Color("11181a")
const GRID_COLOR := Color(0.04, 0.06, 0.06, 0.20)
const VIEWPORT_COLOR := Color("f2d276")
const HERO_COLOR := Color("f6e29b")
const TOWN_PLAYER_COLOR := Color("70b7dc")
const TOWN_OTHER_COLOR := Color("d36c59")
const KEYBOARD_CURSOR_COLOR := Color("fff4bd")

var _session = null
var _map_data: Array = []
var _map_size := Vector2i.ONE
var _selected_tile := Vector2i.ZERO
var _keyboard_tile := Vector2i.ZERO
var _visible_bounds := Rect2i(Vector2i.ZERO, Vector2i.ONE)
var _last_recenter_tile := Vector2i(-1, -1)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	tooltip_text = "World map. Click to recenter the view; arrow keys choose a tile and Enter recenters."
	accessibility_name = "World minimap"
	accessibility_description = "Shows explored terrain, heroes, towns, and the current map viewport. Activation recenters the view without moving a hero."
	queue_redraw()


func configure(session, map_data: Array, map_size: Vector2i, selected_tile: Vector2i, visible_bounds: Rect2i) -> void:
	_session = session
	_map_data = map_data
	_map_size = Vector2i(maxi(map_size.x, 1), maxi(map_size.y, 1))
	_selected_tile = _clamped_tile(selected_tile)
	if not _tile_in_bounds(_keyboard_tile):
		_keyboard_tile = _selected_tile
	_visible_bounds = _clamped_bounds(visible_bounds)
	queue_redraw()


func set_viewport_bounds(visible_bounds: Rect2i) -> void:
	_visible_bounds = _clamped_bounds(visible_bounds)
	queue_redraw()


func _draw() -> void:
	var field := _field_rect()
	draw_rect(Rect2(Vector2.ZERO, size), Color("091012"), true)
	draw_rect(field, Color("162021"), true)
	var cell := field.size / Vector2(float(_map_size.x), float(_map_size.y))
	for y in range(_map_size.y):
		for x in range(_map_size.x):
			var tile := Vector2i(x, y)
			var tile_rect := Rect2(field.position + Vector2(x * cell.x, y * cell.y), cell + Vector2(0.35, 0.35))
			draw_rect(tile_rect, _tile_color(tile), true)
	if cell.x >= 5.0 and cell.y >= 5.0:
		for x in range(1, _map_size.x):
			var line_x := field.position.x + x * cell.x
			draw_line(Vector2(line_x, field.position.y), Vector2(line_x, field.end.y), GRID_COLOR, 1.0)
		for y in range(1, _map_size.y):
			var line_y := field.position.y + y * cell.y
			draw_line(Vector2(field.position.x, line_y), Vector2(field.end.x, line_y), GRID_COLOR, 1.0)
	_draw_towns(field, cell)
	_draw_heroes(field, cell)
	_draw_viewport(field, cell)
	if has_focus():
		var cursor_rect := _tile_rect(field, cell, _keyboard_tile).grow(-maxf(1.0, minf(cell.x, cell.y) * 0.12))
		draw_rect(cursor_rect, KEYBOARD_CURSOR_COLOR, false, 2.0)
	draw_rect(field, Color("a7894c"), false, 2.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var hovered := _tile_from_position(event.position)
		if _tile_in_bounds(hovered):
			tooltip_text = "Recenter view at %d,%d. No hero movement is spent." % [hovered.x, hovered.y]
		accept_event()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_request_recenter(_tile_from_position(event.position))
		accept_event()
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var delta := Vector2i.ZERO
	match event.keycode:
		KEY_LEFT:
			delta = Vector2i.LEFT
		KEY_RIGHT:
			delta = Vector2i.RIGHT
		KEY_UP:
			delta = Vector2i.UP
		KEY_DOWN:
			delta = Vector2i.DOWN
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_request_recenter(_keyboard_tile)
			accept_event()
			return
		_:
			return
	_keyboard_tile = _clamped_tile(_keyboard_tile + delta)
	queue_redraw()
	accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT or what == NOTIFICATION_RESIZED:
		queue_redraw()


func _request_recenter(tile: Vector2i) -> void:
	if not _tile_in_bounds(tile):
		return
	_keyboard_tile = tile
	_last_recenter_tile = tile
	recenter_requested.emit(tile)
	queue_redraw()


func _field_rect() -> Rect2:
	return Rect2(Vector2(5.0, 5.0), Vector2(maxf(size.x - 10.0, 1.0), maxf(size.y - 10.0, 1.0)))


func _tile_color(tile: Vector2i) -> Color:
	if _session == null or not OverworldRulesScript.is_tile_explored(_session, tile.x, tile.y):
		return UNEXPLORED_COLOR
	var terrain := _terrain_at(tile)
	var color: Color = TERRAIN_COLORS.get(terrain, Color("59634e"))
	if not OverworldRulesScript.is_tile_visible(_session, tile.x, tile.y):
		color = color.darkened(0.24)
	return color


func _terrain_at(tile: Vector2i) -> String:
	if tile.y < 0 or tile.y >= _map_data.size() or not (_map_data[tile.y] is Array):
		return "grass"
	var row: Array = _map_data[tile.y]
	if tile.x < 0 or tile.x >= row.size():
		return "grass"
	var cell = row[tile.x]
	if cell is Dictionary:
		return String(cell.get("terrain", cell.get("terrain_id", "grass"))).to_lower()
	return String(cell).to_lower()


func _draw_towns(field: Rect2, cell: Vector2) -> void:
	if _session == null:
		return
	for value in _session.overworld.get("towns", []):
		if not (value is Dictionary):
			continue
		var tile := Vector2i(int(value.get("x", -1)), int(value.get("y", -1)))
		if not _tile_in_bounds(tile) or not OverworldRulesScript.is_tile_explored(_session, tile.x, tile.y):
			continue
		var rect := _marker_rect(field, cell, tile, 0.62)
		var color := TOWN_PLAYER_COLOR if String(value.get("owner", "neutral")) == "player" else TOWN_OTHER_COLOR
		draw_rect(rect, Color(0.03, 0.04, 0.04, 0.92), true)
		draw_rect(rect.grow(-1.0), color, true)


func _draw_heroes(field: Rect2, cell: Vector2) -> void:
	if _session == null:
		return
	var hero_tiles: Array[Vector2i] = []
	var primary := OverworldRulesScript.hero_position(_session)
	if _tile_in_bounds(primary):
		hero_tiles.append(primary)
	for value in _session.overworld.get("heroes", []):
		if not (value is Dictionary):
			continue
		var position = value.get("position", {})
		if not (position is Dictionary):
			continue
		var tile := Vector2i(int(position.get("x", -1)), int(position.get("y", -1)))
		if _tile_in_bounds(tile) and tile not in hero_tiles:
			hero_tiles.append(tile)
	for tile in hero_tiles:
		if not OverworldRulesScript.is_tile_explored(_session, tile.x, tile.y):
			continue
		var center := _tile_rect(field, cell, tile).get_center()
		var radius := clampf(minf(cell.x, cell.y) * 0.34, 2.5, 6.0)
		draw_circle(center, radius + 1.5, Color(0.02, 0.03, 0.03, 0.96))
		draw_circle(center, radius, HERO_COLOR)


func _draw_viewport(field: Rect2, cell: Vector2) -> void:
	var bounds := _clamped_bounds(_visible_bounds)
	var viewport_rect := Rect2(
		field.position + Vector2(bounds.position.x * cell.x, bounds.position.y * cell.y),
		Vector2(bounds.size.x * cell.x, bounds.size.y * cell.y)
	)
	viewport_rect = viewport_rect.intersection(field)
	if viewport_rect.size.x > 0.0 and viewport_rect.size.y > 0.0:
		draw_rect(viewport_rect.grow(-1.0), VIEWPORT_COLOR, false, 2.0)


func _marker_rect(field: Rect2, cell: Vector2, tile: Vector2i, factor: float) -> Rect2:
	var tile_rect := _tile_rect(field, cell, tile)
	var extent := clampf(minf(cell.x, cell.y) * factor, 3.0, 9.0)
	return Rect2(tile_rect.get_center() - Vector2(extent, extent) * 0.5, Vector2(extent, extent))


func _tile_rect(field: Rect2, cell: Vector2, tile: Vector2i) -> Rect2:
	return Rect2(field.position + Vector2(tile.x * cell.x, tile.y * cell.y), cell)


func _tile_from_position(position: Vector2) -> Vector2i:
	var field := _field_rect()
	if not field.has_point(position):
		return Vector2i(-1, -1)
	var normalized := (position - field.position) / field.size
	return _clamped_tile(Vector2i(int(floor(normalized.x * _map_size.x)), int(floor(normalized.y * _map_size.y))))


func _clamped_tile(tile: Vector2i) -> Vector2i:
	return Vector2i(clampi(tile.x, 0, _map_size.x - 1), clampi(tile.y, 0, _map_size.y - 1))


func _tile_in_bounds(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.y >= 0 and tile.x < _map_size.x and tile.y < _map_size.y


func _clamped_bounds(bounds: Rect2i) -> Rect2i:
	var start := _clamped_tile(bounds.position)
	var end := _clamped_tile(bounds.end - Vector2i.ONE) + Vector2i.ONE
	return Rect2i(start, Vector2i(maxi(end.x - start.x, 1), maxi(end.y - start.y, 1)))


func validation_snapshot() -> Dictionary:
	return {
		"map_size": {"x": _map_size.x, "y": _map_size.y},
		"selected_tile": {"x": _selected_tile.x, "y": _selected_tile.y},
		"keyboard_tile": {"x": _keyboard_tile.x, "y": _keyboard_tile.y},
		"visible_bounds": {
			"x": _visible_bounds.position.x,
			"y": _visible_bounds.position.y,
			"width": _visible_bounds.size.x,
			"height": _visible_bounds.size.y,
		},
		"last_recenter_tile": {"x": _last_recenter_tile.x, "y": _last_recenter_tile.y},
		"terrain_cell_count": _map_size.x * _map_size.y,
		"presentation_only": true,
		"focusable": focus_mode == Control.FOCUS_ALL,
		"accessible_name": accessibility_name,
	}
