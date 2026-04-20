extends Control

signal tile_pressed(tile: Vector2i)
signal tile_hovered(tile: Vector2i)

const HeroCommandRulesScript = preload("res://scripts/core/HeroCommandRules.gd")
const OverworldRulesScript = preload("res://scripts/core/OverworldRules.gd")

const OVERWORLD_ART_MANIFEST_PATH := "res://art/overworld/manifest.json"
const TERRAIN_GRAMMAR_PATH := "res://content/terrain_grammar.json"
const MAP_PADDING := 22.0
const TACTICAL_VISIBLE_TILE_SPAN := 12.0
const TACTICAL_VISIBLE_TILE_AREA := TACTICAL_VISIBLE_TILE_SPAN * TACTICAL_VISIBLE_TILE_SPAN
const MIN_TILE_EXTENT := 24.0
const GRID_COLOR := Color(0.08, 0.10, 0.12, 0.34)
const FRAME_COLOR := Color(0.73, 0.63, 0.42, 0.9)
const FRAME_FILL := Color(0.07, 0.10, 0.11, 1.0)
const UNEXPLORED_COLOR := Color(0.04, 0.05, 0.06, 1.0)
const MEMORY_OBJECT_COLOR := Color(0.72, 0.80, 0.82, 0.84)
const MEMORY_OBJECT_OUTLINE := Color(0.92, 0.96, 0.91, 0.76)
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
	"mire": Color(0.30, 0.38, 0.25, 1.0),
	"swamp": Color(0.27, 0.35, 0.23, 1.0),
	"hills": Color(0.48, 0.48, 0.36, 1.0),
	"ridge": Color(0.48, 0.48, 0.36, 1.0),
	"badlands": Color(0.53, 0.40, 0.29, 1.0),
	"ash": Color(0.32, 0.30, 0.31, 1.0),
	"cavern": Color(0.27, 0.25, 0.34, 1.0),
	"snow": Color(0.75, 0.81, 0.82, 1.0),
}
const PLAYER_TOWN_COLOR := Color(0.84, 0.68, 0.30, 1.0)
const ENEMY_TOWN_COLOR := Color(0.72, 0.28, 0.26, 1.0)
const NEUTRAL_TOWN_COLOR := Color(0.56, 0.59, 0.64, 1.0)
const RESOURCE_COLOR := Color(0.28, 0.83, 0.62, 1.0)
const ARTIFACT_COLOR := Color(0.95, 0.68, 0.31, 1.0)
const ENCOUNTER_COLOR := Color(0.90, 0.44, 0.35, 1.0)
const MARKER_OUTLINE_COLOR := Color(0.035, 0.045, 0.038, 0.90)
const MARKER_SHADOW_COLOR := Color(0.01, 0.012, 0.009, 0.42)
const MARKER_PLATE_VISIBLE := Color(0.22, 0.17, 0.09, 0.34)
const MARKER_PLATE_MEMORY := Color(0.08, 0.15, 0.16, 0.52)
const MARKER_RING_VISIBLE := Color(0.82, 0.69, 0.36, 0.45)
const MARKER_RING_MEMORY := Color(0.82, 0.93, 0.96, 0.80)
const MARKER_PLATE_RADIUS_FACTOR := 0.31
const HERO_PLATE_RADIUS_FACTOR := 0.33
const OBJECT_SPRITE_PLATE_RADIUS_FACTOR := 0.40
const OBJECT_SPRITE_EXTENT_FACTOR := 0.88
const OBJECT_SPRITE_VISIBLE_MODULATE := Color(1.0, 1.0, 1.0, 0.96)
const OBJECT_SPRITE_SHADOW_MODULATE := Color(0.02, 0.018, 0.014, 0.30)
const OBJECT_SPRITE_MEMORY_MODULATE := Color(0.72, 0.82, 0.84, 0.82)
const OBJECT_PRESENCE_MODEL := "footprint_scaled_world_object"
const OBJECT_OCCLUSION_MODEL := "foreground_ground_lip"
const OBJECT_SPRITE_SETTLEMENT_MODEL := "footprint_scaled_sprite_with_ground_lip"
const OBJECT_PROCEDURAL_FALLBACK_MODEL := "family_specific_procedural_world_object"
const OBJECT_DEPTH_CUE_MODEL := "footprint_cast_shadow_with_base_occlusion"
const OBJECT_CONTACT_SHADOW_MODEL := "directional_footprint_cast_shadow"
const OBJECT_BASE_OCCLUSION_MODEL := "foreground_base_occlusion_pads"
const OBJECT_PLACEMENT_BED_MODEL := "footprint_terrain_quieting_bed"
const OBJECT_UPPER_BACKDROP_MODEL := "family_scaled_rear_backdrop_wash"
const OBJECT_VERTICAL_MASS_SHADOW_MODEL := "subtle_vertical_mass_shadow"
const MARKER_GROUND_ANCHOR_STYLE := "terrain_ellipse_footprint"
const MARKER_GROUND_ANCHOR_Y_OFFSET_FACTOR := 0.18
const MARKER_GROUND_ANCHOR_HEIGHT_FACTOR := 0.34
const MARKER_GROUND_ANCHOR_WIDTH_FACTOR := 1.16
const MARKER_FOOTPRINT_WIDTH_STEP := 0.28
const MARKER_FOOTPRINT_HEIGHT_STEP := 0.18
const OBJECT_CONTACT_SHADOW_VISIBLE := Color(0.018, 0.014, 0.010, 0.30)
const OBJECT_CONTACT_SHADOW_MEMORY := Color(0.18, 0.34, 0.36, 0.34)
const OBJECT_BASE_OCCLUSION_VISIBLE := Color(0.11, 0.075, 0.030, 0.34)
const OBJECT_BASE_OCCLUSION_MEMORY := Color(0.62, 0.82, 0.86, 0.32)
const OBJECT_PLACEMENT_BED_VISIBLE_ALPHA := 0.34
const OBJECT_PLACEMENT_BED_MEMORY_ALPHA := 0.30
const OBJECT_UPPER_BACKDROP_VISIBLE := Color(0.018, 0.022, 0.015, 0.26)
const OBJECT_UPPER_BACKDROP_MEMORY := Color(0.20, 0.36, 0.38, 0.26)
const OBJECT_VERTICAL_MASS_SHADOW_VISIBLE := Color(0.010, 0.012, 0.008, 0.18)
const OBJECT_VERTICAL_MASS_SHADOW_MEMORY := Color(0.22, 0.40, 0.42, 0.18)
const TERRAIN_GRAMMAR_RENDERING_MODE := "authored_autotile_layers"
const TERRAIN_ORIGINAL_TILE_BANK_RENDERING_MODE := "original_quiet_tile_bank"
const TERRAIN_TILE_ART_RENDERING_MODE := TERRAIN_ORIGINAL_TILE_BANK_RENDERING_MODE
const TERRAIN_DEPRECATED_GENERATED_SOURCE_BASIS := "generated_overworld_terrain_sources_20260419"
const TERRAIN_TRANSITION_ALPHA := 0.42
const TERRAIN_TRANSITION_WIDTH_FACTOR := 0.16
const ROAD_DEFAULT_COLOR := Color(0.72, 0.58, 0.34, 0.92)
const ROAD_DEFAULT_EDGE_COLOR := Color(0.35, 0.24, 0.15, 0.78)
const ROAD_DEFAULT_SHADOW_COLOR := Color(0.07, 0.05, 0.035, 0.58)
const ROAD_DEFAULT_CENTER_COLOR := Color(0.86, 0.74, 0.48, 0.55)
const ROAD_DEFAULT_WIDTH_FACTOR := 0.14
const TOWN_MARKER_BODY_WIDTH := 0.64
const TOWN_MARKER_BODY_HEIGHT := 0.34
const RESOURCE_MARKER_RADIUS := 0.17
const ARTIFACT_MARKER_OUTER_RADIUS := 0.18
const ARTIFACT_MARKER_INNER_RADIUS := 0.07
const ENCOUNTER_MARKER_EXTENT := 0.21
const HERO_MARKER_RADIUS := 0.17
const FOCUS_RING_WIDTH_FACTOR := 0.045
const PAN_DRAG_THRESHOLD := 6.0
const WHEEL_PAN_TILES := 3
const DIRECTIONS := [
	Vector2i.LEFT,
	Vector2i.RIGHT,
	Vector2i.UP,
	Vector2i.DOWN,
	Vector2i(-1, -1),
	Vector2i(1, -1),
	Vector2i(-1, 1),
	Vector2i(1, 1),
]

var _session = null
var _map_data: Array = []
var _map_size := Vector2i.ONE
var _selected_tile := Vector2i(-1, -1)
var _hover_tile := Vector2i(-1, -1)
var _hero_tile := Vector2i.ZERO
var _path_tiles: Array = []
var _terrain_layers: Dictionary = {}
var _road_tiles: Dictionary = {}
var _movement_left := 0
var _camera_center_tile := Vector2.ZERO
var _camera_center_ready := false
var _manual_camera := false
var _drag_start_position := Vector2.ZERO
var _drag_last_position := Vector2.ZERO
var _dragging_camera := false
var _pending_click_position := Vector2.ZERO
var _terrain_grammar: Dictionary = {}
var _terrain_styles: Dictionary = {}
var _terrain_overlay_styles: Dictionary = {}
var _terrain_base_art: Dictionary = {}
var _terrain_edge_art: Dictionary = {}
var _terrain_art_textures: Dictionary = {}
var _terrain_art_missing: Dictionary = {}
var _road_overlay_art: Dictionary = {}
var _overworld_art_manifest: Dictionary = {}
var _object_asset_paths: Dictionary = {}
var _object_textures: Dictionary = {}
var _object_texture_missing: Dictionary = {}
var _resource_site_asset_ids: Dictionary = {}
var _resource_site_object_profiles: Dictionary = {}
var _artifact_default_asset_id := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	clip_contents = true
	custom_minimum_size = Vector2(640, 400)
	_load_terrain_grammar()
	_load_overworld_art_manifest()

func set_map_state(session, map_data: Array, map_size: Vector2i, selected_tile: Vector2i) -> void:
	_session = session
	_map_data = map_data.duplicate(true)
	_map_size = Vector2i(max(map_size.x, 1), max(map_size.y, 1))
	_hero_tile = OverworldRulesScript.hero_position(session) if session != null else Vector2i.ZERO
	_movement_left = int(session.overworld.get("movement", {}).get("current", 0)) if session != null else 0
	_terrain_layers = session.overworld.get("terrain_layers", {}).duplicate(true) if session != null and session.overworld.get("terrain_layers", {}) is Dictionary else {}
	_rebuild_road_tiles()
	_selected_tile = selected_tile
	_path_tiles = _build_path(_hero_tile, _selected_tile)
	_ensure_camera_state()
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
	elif what == NOTIFICATION_MOUSE_EXIT:
		_dragging_camera = false
		if _hover_tile.x >= 0:
			_hover_tile = Vector2i(-1, -1)
			tile_hovered.emit(_hover_tile)
			queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0 and _can_pan_camera():
			var drag_delta: Vector2 = event.position - _drag_last_position
			if _dragging_camera or event.position.distance_to(_drag_start_position) >= PAN_DRAG_THRESHOLD:
				_dragging_camera = true
				_pan_camera_pixels(drag_delta)
				_drag_last_position = event.position
				accept_event()
				return
		var tile = _tile_from_local(event.position)
		if tile != _hover_tile:
			_hover_tile = tile
			tile_hovered.emit(tile)
			queue_redraw()
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_drag_start_position = event.position
				_drag_last_position = event.position
				_pending_click_position = event.position
				_dragging_camera = false
				accept_event()
				return
			if _dragging_camera:
				_dragging_camera = false
				accept_event()
				return
			var tile = _tile_from_local(_pending_click_position)
			if tile.x >= 0:
				tile_pressed.emit(tile)
				accept_event()
			return
		if event.pressed and _can_pan_camera():
			match event.button_index:
				MOUSE_BUTTON_WHEEL_UP:
					pan_tiles(Vector2i(0, -WHEEL_PAN_TILES))
					accept_event()
				MOUSE_BUTTON_WHEEL_DOWN:
					pan_tiles(Vector2i(0, WHEEL_PAN_TILES))
					accept_event()
				MOUSE_BUTTON_WHEEL_LEFT:
					pan_tiles(Vector2i(-WHEEL_PAN_TILES, 0))
					accept_event()
				MOUSE_BUTTON_WHEEL_RIGHT:
					pan_tiles(Vector2i(WHEEL_PAN_TILES, 0))
					accept_event()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), FRAME_FILL, true)
	if _session == null:
		return

	var viewport_rect := _map_viewport_rect()
	var board_rect = _board_rect()
	var frame_rect = viewport_rect.grow(12.0)
	draw_rect(frame_rect, Color(0.02, 0.03, 0.04, 0.85), true)
	draw_rect(viewport_rect, FRAME_FILL, true)

	var visible_bounds := _visible_tile_bounds(board_rect, viewport_rect)
	for y in range(visible_bounds.position.y, visible_bounds.position.y + visible_bounds.size.y):
		for x in range(visible_bounds.position.x, visible_bounds.position.x + visible_bounds.size.x):
			var tile = Vector2i(x, y)
			var rect = _tile_rect(board_rect, tile)
			_draw_tile_background(tile, rect)

	_draw_route(board_rect)

	for y in range(visible_bounds.position.y, visible_bounds.position.y + visible_bounds.size.y):
		for x in range(visible_bounds.position.x, visible_bounds.position.x + visible_bounds.size.x):
			var tile = Vector2i(x, y)
			var rect = _tile_rect(board_rect, tile)
			_draw_tile_focus(tile, rect)
			_draw_tile_icon(tile, rect)
	_draw_viewport_mask(viewport_rect)
	draw_rect(frame_rect, FRAME_COLOR, false, 3.0)

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

	var terrain = _terrain_at(tile)
	if not _draw_terrain_tile_art(tile, rect, terrain):
		var base_color: Color = _terrain_color(terrain, "base_color", TERRAIN_COLORS.get(terrain, TERRAIN_COLORS["grass"]))
		draw_rect(rect, base_color, true)
		_draw_authored_terrain_pattern(tile, rect, terrain, true)
	_draw_terrain_transitions(tile, rect, terrain)
	_draw_road_overlay(tile, rect)

	draw_rect(rect, GRID_COLOR, false, 1.0)

func _draw_terrain_tile_art(tile: Vector2i, rect: Rect2, terrain: String) -> bool:
	if not _terrain_art_can_be_primary(terrain):
		return false
	var entry := _terrain_base_art_entry(terrain, tile)
	var texture_path := String(entry.get("path", ""))
	var texture = _terrain_art_texture(texture_path)
	if not (texture is Texture2D):
		return false
	draw_texture_rect(texture, rect, false)
	return true

func _draw_authored_terrain_pattern(tile: Vector2i, rect: Rect2, terrain: String, visible: bool) -> void:
	var pattern := _terrain_pattern(terrain)
	match pattern:
		"tree_clusters":
			_draw_forest_pattern(rect, visible)
		"water_bands":
			_draw_water_pattern(rect, visible)
		"reed_pools":
			_draw_mire_pattern(rect, visible)
		"contours":
			_draw_ridge_pattern(rect, visible)
		"snow_drifts":
			_draw_snow_pattern(rect, visible)
		"cracked_ground":
			_draw_cracked_ground_pattern(rect, visible)
		"ash_scars":
			_draw_ash_pattern(rect, visible)
		"stone_facets":
			_draw_stone_pattern(rect, visible)
		_:
			_draw_grass_pattern(rect, visible)
	_draw_tile_variant_marks(tile, rect, terrain, visible)

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

func _draw_mire_pattern(rect: Rect2, visible: bool) -> void:
	var reed_color = Color(0.62, 0.71, 0.35, 0.24 if visible else 0.12)
	for column in [0.25, 0.50, 0.72]:
		var start = rect.position + rect.size * Vector2(column, 0.68)
		draw_line(start, start - Vector2(rect.size.x * 0.06, rect.size.y * 0.32), reed_color, 2.0)
		draw_line(start, start + Vector2(rect.size.x * 0.06, -rect.size.y * 0.26), reed_color, 2.0)

func _draw_ridge_pattern(rect: Rect2, visible: bool) -> void:
	var ridge_color = Color(0.78, 0.73, 0.55, 0.22 if visible else 0.11)
	draw_line(rect.position + rect.size * Vector2(0.18, 0.70), rect.position + rect.size * Vector2(0.50, 0.30), ridge_color, 2.0)
	draw_line(rect.position + rect.size * Vector2(0.50, 0.30), rect.position + rect.size * Vector2(0.82, 0.68), ridge_color, 2.0)

func _draw_snow_pattern(rect: Rect2, visible: bool) -> void:
	var snow_color = Color(0.96, 0.98, 1.0, 0.28 if visible else 0.12)
	draw_circle(rect.position + rect.size * Vector2(0.32, 0.36), rect.size.x * 0.045, snow_color)
	draw_circle(rect.position + rect.size * Vector2(0.63, 0.60), rect.size.x * 0.055, snow_color)

func _draw_cracked_ground_pattern(rect: Rect2, visible: bool) -> void:
	var crack_color := Color(0.33, 0.22, 0.15, 0.25 if visible else 0.12)
	draw_line(rect.position + rect.size * Vector2(0.18, 0.30), rect.position + rect.size * Vector2(0.42, 0.44), crack_color, 2.0)
	draw_line(rect.position + rect.size * Vector2(0.42, 0.44), rect.position + rect.size * Vector2(0.34, 0.68), crack_color, 2.0)
	draw_line(rect.position + rect.size * Vector2(0.62, 0.25), rect.position + rect.size * Vector2(0.78, 0.48), crack_color, 1.6)

func _draw_ash_pattern(rect: Rect2, visible: bool) -> void:
	var scar_color := Color(0.83, 0.44, 0.28, 0.20 if visible else 0.10)
	var ash_color := Color(0.20, 0.18, 0.18, 0.23 if visible else 0.11)
	draw_line(rect.position + rect.size * Vector2(0.18, 0.62), rect.position + rect.size * Vector2(0.82, 0.42), ash_color, 2.0)
	draw_line(rect.position + rect.size * Vector2(0.28, 0.32), rect.position + rect.size * Vector2(0.66, 0.66), scar_color, 1.8)

func _draw_stone_pattern(rect: Rect2, visible: bool) -> void:
	var facet_color := Color(0.72, 0.68, 0.82, 0.20 if visible else 0.10)
	draw_line(rect.position + rect.size * Vector2(0.20, 0.36), rect.position + rect.size * Vector2(0.50, 0.22), facet_color, 1.8)
	draw_line(rect.position + rect.size * Vector2(0.50, 0.22), rect.position + rect.size * Vector2(0.80, 0.44), facet_color, 1.8)
	draw_line(rect.position + rect.size * Vector2(0.30, 0.72), rect.position + rect.size * Vector2(0.66, 0.58), facet_color, 1.6)

func _draw_tile_variant_marks(tile: Vector2i, rect: Rect2, terrain: String, visible: bool) -> void:
	var detail := _terrain_color(terrain, "detail_color", Color(0.85, 0.88, 0.62, 1.0))
	var alpha := 0.13 if visible else 0.06
	var color := Color(detail.r, detail.g, detail.b, alpha)
	var seed: int = abs((tile.x * 37) + (tile.y * 53))
	var center := rect.position + rect.size * Vector2(0.28 + (float(seed % 41) / 100.0), 0.26 + (float((seed / 7) % 43) / 100.0))
	var radius := maxf(1.6, minf(rect.size.x, rect.size.y) * (0.025 + (float(seed % 3) * 0.008)))
	draw_circle(center, radius, color)
	if seed % 2 == 0:
		var second := rect.position + rect.size * Vector2(0.22 + (float((seed / 3) % 50) / 100.0), 0.56 + (float((seed / 11) % 28) / 100.0))
		draw_line(second, second + Vector2(rect.size.x * 0.16, -rect.size.y * 0.04), color, 1.4)

func _draw_terrain_transitions(tile: Vector2i, rect: Rect2, terrain: String) -> void:
	var edge_mask := _terrain_transition_edge_mask(tile)
	if edge_mask == "":
		return
	var edge_color := _terrain_color(terrain, "edge_color", Color(0.24, 0.26, 0.18, 1.0))
	var color := Color(edge_color.r, edge_color.g, edge_color.b, TERRAIN_TRANSITION_ALPHA)
	var width := maxf(3.0, minf(rect.size.x, rect.size.y) * TERRAIN_TRANSITION_WIDTH_FACTOR)
	if "N" in edge_mask:
		if not _draw_terrain_edge_art(terrain, "N", rect):
			draw_rect(Rect2(rect.position, Vector2(rect.size.x, width)), color, true)
	if "S" in edge_mask:
		if not _draw_terrain_edge_art(terrain, "S", rect):
			draw_rect(Rect2(Vector2(rect.position.x, rect.end.y - width), Vector2(rect.size.x, width)), color, true)
	if "W" in edge_mask:
		if not _draw_terrain_edge_art(terrain, "W", rect):
			draw_rect(Rect2(rect.position, Vector2(width, rect.size.y)), color, true)
	if "E" in edge_mask:
		if not _draw_terrain_edge_art(terrain, "E", rect):
			draw_rect(Rect2(Vector2(rect.end.x - width, rect.position.y), Vector2(width, rect.size.y)), color, true)

func _draw_terrain_edge_art(terrain: String, direction: String, rect: Rect2) -> bool:
	if not _terrain_art_can_be_primary(terrain):
		return false
	var texture_path := _terrain_edge_art_path(terrain, direction)
	var texture = _terrain_art_texture(texture_path)
	if not (texture is Texture2D):
		return false
	draw_texture_rect(texture, rect, false)
	return true

func _draw_road_overlay(tile: Vector2i, rect: Rect2) -> void:
	var road := _road_tile_payload(tile)
	if road.is_empty():
		return
	if _draw_road_overlay_art(tile, rect, road):
		return
	var style := _road_overlay_style(String(road.get("overlay_id", "road_dirt")))
	var extent := minf(rect.size.x, rect.size.y)
	var center := rect.get_center()
	var width := maxf(4.0, extent * float(style.get("width_fraction", ROAD_DEFAULT_WIDTH_FACTOR)))
	var road_color: Color = style.get("color", ROAD_DEFAULT_COLOR)
	var edge_color: Color = style.get("edge_color", ROAD_DEFAULT_EDGE_COLOR)
	var shadow_color: Color = style.get("shadow_color", ROAD_DEFAULT_SHADOW_COLOR)
	var center_color: Color = style.get("center_color", ROAD_DEFAULT_CENTER_COLOR)
	var connector_count := 0
	for direction in DIRECTIONS:
		var neighbor: Vector2i = tile + direction
		if not _road_tiles.has(_tile_key(neighbor)):
			continue
		connector_count += 1
		var end := center + Vector2(float(direction.x) * rect.size.x * 0.52, float(direction.y) * rect.size.y * 0.52)
		draw_line(center, end, shadow_color, width * 1.45)
		draw_line(center, end, edge_color, width * 1.12)
		draw_line(center, end, road_color, width)
		draw_line(center, end, center_color, maxf(1.4, width * 0.22))
	if connector_count == 0:
		draw_circle(center, width * 0.72, shadow_color)
		draw_circle(center, width * 0.58, edge_color)
		draw_circle(center, width * 0.46, road_color)

func _draw_road_overlay_art(tile: Vector2i, rect: Rect2, road: Dictionary) -> bool:
	var overlay_id := String(road.get("overlay_id", "road_dirt"))
	if not _road_overlay_art_can_be_primary(overlay_id):
		return false
	var art := _road_overlay_art_paths(overlay_id)
	if art.is_empty():
		return false
	var drew_any := false
	var center_texture = _terrain_art_texture(String(art.get("center", "")))
	if center_texture is Texture2D:
		draw_texture_rect(center_texture, rect, false)
		drew_any = true
	var connectors = art.get("connectors", {})
	if connectors is Dictionary:
		for direction in DIRECTIONS:
			var neighbor: Vector2i = tile + direction
			if not _road_tiles.has(_tile_key(neighbor)):
				continue
			var direction_key := _direction_key(direction)
			var connector_texture = _terrain_art_texture(String(connectors.get(direction_key, "")))
			if connector_texture is Texture2D:
				draw_texture_rect(connector_texture, rect, false)
				drew_any = true
	return drew_any

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
	var extent := minf(rect.size.x, rect.size.y)
	var focus_width := maxf(3.0, extent * FOCUS_RING_WIDTH_FACTOR)
	if tile == _hero_tile:
		draw_rect(rect.grow(-1.0), Color(0.03, 0.025, 0.015, 0.50), false, focus_width + 2.0)
		draw_rect(rect.grow(-3.0), HERO_RING_COLOR, false, focus_width)

	if tile == _selected_tile:
		draw_rect(rect.grow(-5.0), Color(SELECTION_COLOR.r, SELECTION_COLOR.g, SELECTION_COLOR.b, 0.10), true)
		draw_rect(rect.grow(-5.0), SELECTION_COLOR, false, focus_width)
		_draw_selection_corners(rect, SELECTION_COLOR, focus_width)

	if tile == _hover_tile:
		draw_rect(rect.grow(-7.0), HOVER_COLOR, false, 2.0)

func _draw_tile_icon(tile: Vector2i, rect: Rect2) -> void:
	if not OverworldRulesScript.is_tile_explored(_session, tile.x, tile.y):
		return
	var visible := OverworldRulesScript.is_tile_visible(_session, tile.x, tile.y)
	var remembered := not visible

	if _has_town_at(tile):
		_draw_town_marker(rect, _town_color(tile), remembered, tile)
	var resource_node := _resource_node_at(tile)
	if not resource_node.is_empty():
		if not _draw_resource_sprite(resource_node, rect, remembered, tile):
			_draw_resource_marker(resource_node, rect, remembered, tile)
	var artifact_node := _artifact_node_at(tile)
	if not artifact_node.is_empty():
		if not _draw_artifact_sprite(artifact_node, rect, remembered, tile):
			_draw_artifact_marker(rect, remembered, tile)
	if _has_encounter_at(tile) and (visible or _has_rememberable_encounter_at(tile)):
		_draw_encounter_marker(rect, remembered, tile)
	if visible and _has_hero_at(tile):
		_draw_hero_marker(rect, tile)

func _draw_resource_sprite(node: Dictionary, rect: Rect2, remembered: bool, tile: Vector2i) -> bool:
	return _draw_object_sprite(_resource_asset_id(node), rect, remembered, _resource_object_profile(node), tile)

func _draw_artifact_sprite(node: Dictionary, rect: Rect2, remembered: bool, tile: Vector2i) -> bool:
	if node.is_empty():
		return false
	return _draw_object_sprite(_artifact_default_asset_id, rect, remembered, _artifact_object_profile(), tile)

func _draw_object_sprite(asset_id: String, rect: Rect2, remembered: bool, profile: Dictionary, tile: Vector2i) -> bool:
	var texture = _object_texture_for_asset(asset_id)
	if not (texture is Texture2D):
		return false
	var footprint := _object_profile_footprint(profile)
	var family := String(profile.get("family", "pickup"))
	var anchor := _draw_marker_plate(rect, remembered, _presence_radius_factor(family, footprint, OBJECT_SPRITE_PLATE_RADIUS_FACTOR), footprint, tile)
	var extent := minf(rect.size.x, rect.size.y)
	var sprite_fraction := _sprite_extent_fraction(profile, footprint)
	var sprite_extent := maxf(12.0, extent * sprite_fraction)
	var sprite_center := rect.get_center() + Vector2(0.0, -extent * _object_lift_fraction(family, footprint))
	var sprite_rect := Rect2(sprite_center - Vector2(sprite_extent, sprite_extent) * 0.5, Vector2(sprite_extent, sprite_extent))
	var shadow_offset := Vector2(0.0, maxf(2.0, extent * 0.055))
	_draw_upper_mass_backdrop(anchor, family, remembered, footprint)
	draw_texture_rect(texture, Rect2(sprite_rect.position + shadow_offset, sprite_rect.size), false, OBJECT_SPRITE_SHADOW_MODULATE)
	draw_texture_rect(texture, sprite_rect, false, OBJECT_SPRITE_MEMORY_MODULATE if remembered else OBJECT_SPRITE_VISIBLE_MODULATE)
	_draw_foreground_occlusion_lip(anchor, remembered)
	return true

func _draw_town_marker(rect: Rect2, color: Color, remembered: bool = false, tile: Vector2i = Vector2i(-1, -1)) -> void:
	var footprint := Vector2i(2, 2)
	var anchor := _draw_marker_plate(rect, remembered, 0.38, footprint, tile)
	var extent := minf(rect.size.x, rect.size.y)
	var outline_width := maxf(2.2, extent * 0.036)
	var marker_color := _remembered_marker_color(color) if remembered else color
	var outline_color := MEMORY_OBJECT_OUTLINE if remembered else MARKER_OUTLINE_COLOR
	_draw_upper_mass_backdrop(anchor, "town", remembered, footprint)
	var body = Rect2(
		rect.position + rect.size * Vector2(0.18, 0.43),
		rect.size * Vector2(0.64, 0.30)
	)
	var shadow_body := Rect2(body.position + Vector2(0.0, extent * 0.045), body.size)
	draw_rect(shadow_body, Color(0.02, 0.018, 0.014, 0.28), true)
	draw_rect(body, marker_color, true)
	draw_rect(body, outline_color, false, outline_width)
	for step in [0.19, 0.46, 0.70]:
		var battlement = Rect2(
			rect.position + rect.size * Vector2(step, 0.28),
			rect.size * Vector2(0.13, 0.18)
		)
		draw_rect(battlement, marker_color, true)
		draw_rect(battlement, outline_color, false, maxf(1.4, outline_width * 0.65))
	var gate := Rect2(rect.position + rect.size * Vector2(0.44, 0.56), rect.size * Vector2(0.12, 0.17))
	draw_rect(gate, Color(0.16, 0.10, 0.06, 0.48 if remembered else 0.78), true)
	var flag_start = rect.position + rect.size * Vector2(0.70, 0.13)
	var flag_end = rect.position + rect.size * Vector2(0.70, 0.43)
	draw_line(flag_end, flag_start, Color(0.97, 0.94, 0.82, 0.62 if remembered else 0.96), maxf(2.0, extent * 0.032))
	var flag = PackedVector2Array([
		flag_start,
		flag_start + rect.size * Vector2(0.13, 0.04),
		flag_start + rect.size * Vector2(0.00, 0.11),
	])
	draw_colored_polygon(flag, Color(0.98, 0.90, 0.58, 0.62 if remembered else 0.98))
	_draw_foreground_occlusion_lip(anchor, remembered)

func _draw_resource_marker(node: Dictionary, rect: Rect2, remembered: bool = false, tile: Vector2i = Vector2i(-1, -1)) -> void:
	var profile := _resource_object_profile(node)
	var footprint := _object_profile_footprint(profile)
	var family := String(profile.get("family", "pickup"))
	var anchor := _draw_marker_plate(rect, remembered, _presence_radius_factor(family, footprint), footprint, tile)
	var marker_color := _remembered_marker_color(RESOURCE_COLOR) if remembered else RESOURCE_COLOR
	var outline_color := MEMORY_OBJECT_OUTLINE if remembered else MARKER_OUTLINE_COLOR
	_draw_upper_mass_backdrop(anchor, family, remembered, footprint)
	match family:
		"neutral_dwelling", "repeatable_service", "faction_outpost":
			_draw_dwelling_silhouette(rect, marker_color, outline_color, remembered)
		"mine":
			_draw_mine_silhouette(rect, marker_color, outline_color, remembered)
		"scouting_structure":
			_draw_tower_silhouette(rect, marker_color, outline_color, remembered)
		"guarded_reward_site":
			_draw_ruin_silhouette(rect, marker_color, outline_color, remembered)
		"transit_object":
			_draw_transit_silhouette(rect, marker_color, outline_color, remembered)
		"frontier_shrine":
			_draw_shrine_silhouette(rect, marker_color, outline_color, remembered)
		_:
			_draw_pickup_silhouette(rect, marker_color, outline_color, remembered)
	_draw_foreground_occlusion_lip(anchor, remembered)

func _draw_artifact_marker(rect: Rect2, remembered: bool = false, tile: Vector2i = Vector2i(-1, -1)) -> void:
	var footprint := Vector2i(1, 1)
	var anchor := _draw_marker_plate(rect, remembered, MARKER_PLATE_RADIUS_FACTOR, footprint, tile)
	var extent := minf(rect.size.x, rect.size.y)
	var center = rect.get_center()
	var marker_color := _remembered_marker_color(ARTIFACT_COLOR) if remembered else ARTIFACT_COLOR
	var outline_color := MEMORY_OBJECT_OUTLINE if remembered else MARKER_OUTLINE_COLOR
	_draw_upper_mass_backdrop(anchor, "artifact", remembered, footprint)
	var pedestal = Rect2(rect.position + rect.size * Vector2(0.37, 0.56), rect.size * Vector2(0.26, 0.15))
	var lid = Rect2(rect.position + rect.size * Vector2(0.33, 0.48), rect.size * Vector2(0.34, 0.10))
	draw_rect(pedestal, marker_color, true)
	draw_rect(pedestal, outline_color, false, maxf(1.8, extent * 0.030))
	draw_rect(lid, _scaled_color(marker_color, 1.18), true)
	draw_rect(lid, outline_color, false, maxf(1.6, extent * 0.026))
	var gleam := PackedVector2Array([
		center + Vector2(0.0, -extent * 0.22),
		center + Vector2(extent * 0.05, -extent * 0.08),
		center + Vector2(extent * 0.18, -extent * 0.03),
		center + Vector2(extent * 0.05, extent * 0.02),
		center + Vector2(0.0, extent * 0.16),
		center + Vector2(-extent * 0.05, extent * 0.02),
		center + Vector2(-extent * 0.18, -extent * 0.03),
		center + Vector2(-extent * 0.05, -extent * 0.08),
	])
	draw_colored_polygon(gleam, Color(1.0, 0.90, 0.46, 0.62 if remembered else 0.95))
	draw_polyline(PackedVector2Array([gleam[0], gleam[1], gleam[2], gleam[3], gleam[4], gleam[5], gleam[6], gleam[7], gleam[0]]), outline_color, maxf(1.6, extent * 0.026))
	_draw_foreground_occlusion_lip(anchor, remembered)

func _draw_encounter_marker(rect: Rect2, remembered: bool = false, tile: Vector2i = Vector2i(-1, -1)) -> void:
	var footprint := Vector2i(1, 1)
	var anchor := _draw_marker_plate(rect, remembered, 0.34, footprint, tile)
	var extent := minf(rect.size.x, rect.size.y)
	var center = rect.get_center()
	var marker_color := _remembered_marker_color(ENCOUNTER_COLOR) if remembered else ENCOUNTER_COLOR
	var outline_color := MEMORY_OBJECT_OUTLINE if remembered else MARKER_OUTLINE_COLOR
	_draw_upper_mass_backdrop(anchor, "encounter", remembered, footprint)
	var tent := PackedVector2Array([
		rect.position + rect.size * Vector2(0.27, 0.66),
		rect.position + rect.size * Vector2(0.50, 0.33),
		rect.position + rect.size * Vector2(0.73, 0.66),
	])
	draw_colored_polygon(tent, marker_color)
	draw_polyline(PackedVector2Array([tent[0], tent[1], tent[2], tent[0]]), outline_color, maxf(2.0, extent * 0.034))
	draw_line(center + Vector2(-extent * 0.17, extent * 0.04), center + Vector2(-extent * 0.17, -extent * 0.26), outline_color, maxf(2.0, extent * 0.030))
	draw_line(center + Vector2(extent * 0.17, extent * 0.04), center + Vector2(extent * 0.17, -extent * 0.25), outline_color, maxf(2.0, extent * 0.030))
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-extent * 0.17, -extent * 0.26),
		center + Vector2(-extent * 0.02, -extent * 0.21),
		center + Vector2(-extent * 0.17, -extent * 0.15),
	]), Color(0.92, 0.30, 0.24, 0.68 if remembered else 0.96))
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(extent * 0.17, -extent * 0.25),
		center + Vector2(extent * 0.32, -extent * 0.20),
		center + Vector2(extent * 0.17, -extent * 0.14),
	]), Color(0.92, 0.30, 0.24, 0.68 if remembered else 0.96))
	_draw_foreground_occlusion_lip(anchor, remembered)

func _draw_hero_marker(rect: Rect2, tile: Vector2i) -> void:
	var footprint := Vector2i(1, 1)
	var anchor := _draw_marker_plate(rect, false, HERO_PLATE_RADIUS_FACTOR, footprint, tile)
	var extent := minf(rect.size.x, rect.size.y)
	var center: Vector2 = rect.get_center()
	var base_radius := maxf(5.0, extent * HERO_MARKER_RADIUS)
	var figure_center: Vector2 = center + Vector2(0.0, -extent * 0.02)
	_draw_upper_mass_backdrop(anchor, "hero", false, footprint)
	draw_line(figure_center + Vector2(-base_radius * 0.42, extent * 0.18), figure_center + Vector2(-base_radius * 0.12, extent * 0.38), HERO_RING_COLOR, maxf(2.0, extent * 0.030))
	draw_line(figure_center + Vector2(base_radius * 0.36, extent * 0.18), figure_center + Vector2(base_radius * 0.12, extent * 0.38), HERO_RING_COLOR, maxf(2.0, extent * 0.030))
	draw_rect(Rect2(figure_center + Vector2(-base_radius * 0.42, -base_radius * 0.12), Vector2(base_radius * 0.84, base_radius * 1.00)), HERO_FILL_COLOR, true)
	draw_rect(Rect2(figure_center + Vector2(-base_radius * 0.42, -base_radius * 0.12), Vector2(base_radius * 0.84, base_radius * 1.00)), HERO_RING_COLOR, false, maxf(2.2, extent * 0.032))
	draw_circle(figure_center + Vector2(0.0, -base_radius * 0.72), base_radius * 0.48, HERO_FILL_COLOR)
	draw_circle(figure_center + Vector2(0.0, -base_radius * 0.72), base_radius * 0.48, HERO_RING_COLOR, false, maxf(2.0, extent * 0.030))
	draw_line(figure_center + Vector2(base_radius * 0.82, extent * 0.20), figure_center + Vector2(base_radius * 0.82, -rect.size.y * 0.27), HERO_RING_COLOR, maxf(2.5, extent * 0.035))
	var banner = PackedVector2Array([
		figure_center + Vector2(base_radius * 0.82, -rect.size.y * 0.27),
		figure_center + Vector2(base_radius * 0.82 + rect.size.x * 0.17, -rect.size.y * 0.20),
		figure_center + Vector2(base_radius * 0.82, -rect.size.y * 0.11),
	])
	draw_colored_polygon(banner, Color(0.95, 0.73, 0.25, 0.95))
	_draw_foreground_occlusion_lip(anchor, false)

	var reserve_count = _reserve_hero_count(tile)
	if reserve_count <= 0:
		return
	var marker_center = rect.position + rect.size * Vector2(0.78, 0.25)
	draw_circle(marker_center, rect.size.x * 0.10, RESERVE_HERO_COLOR)
	draw_circle(marker_center, rect.size.x * 0.10, Color(0.07, 0.10, 0.12, 0.9), false, 2.0)
	for index in range(min(reserve_count, 3)):
		var dot_pos = marker_center + Vector2((index - 1) * 5.0, 0.0)
		draw_circle(dot_pos, 1.8, Color(0.12, 0.14, 0.17, 1.0))

func _draw_pickup_silhouette(rect: Rect2, marker_color: Color, outline_color: Color, remembered: bool) -> void:
	var extent := minf(rect.size.x, rect.size.y)
	var base := Rect2(rect.position + rect.size * Vector2(0.34, 0.50), rect.size * Vector2(0.32, 0.20))
	var crate_left := Rect2(rect.position + rect.size * Vector2(0.25, 0.57), rect.size * Vector2(0.21, 0.15))
	var crate_right := Rect2(rect.position + rect.size * Vector2(0.54, 0.55), rect.size * Vector2(0.21, 0.16))
	for box in [base, crate_left, crate_right]:
		draw_rect(box, marker_color, true)
		draw_rect(box, outline_color, false, maxf(1.6, extent * 0.026))
	draw_line(base.position + Vector2(0.0, base.size.y * 0.46), base.end - Vector2(0.0, base.size.y * 0.46), _scaled_color(outline_color, 1.0, 0.45 if remembered else 0.68), maxf(1.0, extent * 0.018))

func _draw_dwelling_silhouette(rect: Rect2, marker_color: Color, outline_color: Color, remembered: bool) -> void:
	var extent := minf(rect.size.x, rect.size.y)
	var wall := Rect2(rect.position + rect.size * Vector2(0.25, 0.48), rect.size * Vector2(0.50, 0.23))
	var roof := PackedVector2Array([
		rect.position + rect.size * Vector2(0.20, 0.50),
		rect.position + rect.size * Vector2(0.50, 0.30),
		rect.position + rect.size * Vector2(0.80, 0.50),
	])
	draw_colored_polygon(roof, _scaled_color(marker_color, 0.82))
	draw_polyline(PackedVector2Array([roof[0], roof[1], roof[2]]), outline_color, maxf(2.0, extent * 0.032))
	draw_rect(wall, marker_color, true)
	draw_rect(wall, outline_color, false, maxf(1.8, extent * 0.030))
	draw_rect(Rect2(rect.position + rect.size * Vector2(0.47, 0.58), rect.size * Vector2(0.10, 0.13)), Color(0.13, 0.09, 0.05, 0.48 if remembered else 0.80), true)
	draw_line(rect.position + rect.size * Vector2(0.28, 0.53), rect.position + rect.size * Vector2(0.28, 0.72), outline_color, maxf(1.4, extent * 0.022))
	draw_line(rect.position + rect.size * Vector2(0.72, 0.53), rect.position + rect.size * Vector2(0.72, 0.72), outline_color, maxf(1.4, extent * 0.022))

func _draw_mine_silhouette(rect: Rect2, marker_color: Color, outline_color: Color, remembered: bool) -> void:
	var extent := minf(rect.size.x, rect.size.y)
	var mound := PackedVector2Array([
		rect.position + rect.size * Vector2(0.18, 0.70),
		rect.position + rect.size * Vector2(0.36, 0.42),
		rect.position + rect.size * Vector2(0.52, 0.54),
		rect.position + rect.size * Vector2(0.66, 0.35),
		rect.position + rect.size * Vector2(0.84, 0.70),
	])
	draw_colored_polygon(mound, _scaled_color(marker_color, 0.86))
	draw_polyline(PackedVector2Array([mound[0], mound[1], mound[2], mound[3], mound[4]]), outline_color, maxf(2.0, extent * 0.032))
	var adit := Rect2(rect.position + rect.size * Vector2(0.43, 0.55), rect.size * Vector2(0.18, 0.16))
	draw_rect(adit, Color(0.07, 0.06, 0.045, 0.54 if remembered else 0.88), true)
	draw_rect(adit, outline_color, false, maxf(1.4, extent * 0.024))
	draw_line(rect.position + rect.size * Vector2(0.25, 0.65), rect.position + rect.size * Vector2(0.77, 0.65), Color(0.96, 0.88, 0.55, 0.28 if remembered else 0.44), maxf(1.2, extent * 0.018))

func _draw_tower_silhouette(rect: Rect2, marker_color: Color, outline_color: Color, remembered: bool) -> void:
	var extent := minf(rect.size.x, rect.size.y)
	var shaft := Rect2(rect.position + rect.size * Vector2(0.42, 0.30), rect.size * Vector2(0.16, 0.43))
	var cap := Rect2(rect.position + rect.size * Vector2(0.34, 0.24), rect.size * Vector2(0.32, 0.11))
	draw_rect(shaft, marker_color, true)
	draw_rect(shaft, outline_color, false, maxf(1.7, extent * 0.028))
	draw_rect(cap, _scaled_color(marker_color, 1.10), true)
	draw_rect(cap, outline_color, false, maxf(1.7, extent * 0.028))
	draw_line(rect.position + rect.size * Vector2(0.50, 0.24), rect.position + rect.size * Vector2(0.50, 0.12), outline_color, maxf(1.6, extent * 0.024))
	draw_colored_polygon(PackedVector2Array([
		rect.position + rect.size * Vector2(0.50, 0.12),
		rect.position + rect.size * Vector2(0.64, 0.17),
		rect.position + rect.size * Vector2(0.50, 0.22),
	]), Color(0.95, 0.73, 0.28, 0.56 if remembered else 0.92))

func _draw_ruin_silhouette(rect: Rect2, marker_color: Color, outline_color: Color, remembered: bool) -> void:
	var extent := minf(rect.size.x, rect.size.y)
	var left := Rect2(rect.position + rect.size * Vector2(0.26, 0.42), rect.size * Vector2(0.13, 0.29))
	var right := Rect2(rect.position + rect.size * Vector2(0.61, 0.38), rect.size * Vector2(0.13, 0.33))
	var lintel := Rect2(rect.position + rect.size * Vector2(0.32, 0.38), rect.size * Vector2(0.36, 0.10))
	for stone in [left, right, lintel]:
		draw_rect(stone, _scaled_color(marker_color, 0.90), true)
		draw_rect(stone, outline_color, false, maxf(1.5, extent * 0.024))
	draw_circle(rect.position + rect.size * Vector2(0.50, 0.60), maxf(2.5, extent * 0.055), Color(1.0, 0.90, 0.50, 0.42 if remembered else 0.70))

func _draw_transit_silhouette(rect: Rect2, marker_color: Color, outline_color: Color, remembered: bool) -> void:
	var extent := minf(rect.size.x, rect.size.y)
	var left_base := rect.position + rect.size * Vector2(0.30, 0.70)
	var right_base := rect.position + rect.size * Vector2(0.70, 0.70)
	var apex := rect.position + rect.size * Vector2(0.50, 0.35)
	draw_line(left_base, apex, outline_color, maxf(6.0, extent * 0.090))
	draw_line(right_base, apex, outline_color, maxf(6.0, extent * 0.090))
	draw_line(left_base, apex, marker_color, maxf(3.5, extent * 0.055))
	draw_line(right_base, apex, marker_color, maxf(3.5, extent * 0.055))
	draw_line(rect.position + rect.size * Vector2(0.34, 0.59), rect.position + rect.size * Vector2(0.66, 0.59), Color(0.96, 0.88, 0.55, 0.36 if remembered else 0.60), maxf(1.6, extent * 0.022))

func _draw_shrine_silhouette(rect: Rect2, marker_color: Color, outline_color: Color, remembered: bool) -> void:
	var extent := minf(rect.size.x, rect.size.y)
	var pillar := Rect2(rect.position + rect.size * Vector2(0.43, 0.38), rect.size * Vector2(0.14, 0.30))
	var cap := Rect2(rect.position + rect.size * Vector2(0.35, 0.32), rect.size * Vector2(0.30, 0.10))
	draw_rect(pillar, marker_color, true)
	draw_rect(pillar, outline_color, false, maxf(1.5, extent * 0.024))
	draw_rect(cap, _scaled_color(marker_color, 1.12), true)
	draw_rect(cap, outline_color, false, maxf(1.5, extent * 0.024))
	draw_circle(rect.position + rect.size * Vector2(0.50, 0.25), maxf(2.6, extent * 0.055), Color(0.98, 0.94, 0.72, 0.48 if remembered else 0.78))

func _draw_marker_plate(rect: Rect2, remembered: bool = false, radius_factor: float = MARKER_PLATE_RADIUS_FACTOR, footprint: Vector2i = Vector2i(1, 1), tile: Vector2i = Vector2i(-1, -1)) -> Dictionary:
	var extent := minf(rect.size.x, rect.size.y)
	var center := rect.get_center() + Vector2(0.0, extent * MARKER_GROUND_ANCHOR_Y_OFFSET_FACTOR)
	var radius := maxf(7.0, extent * radius_factor)
	var normalized_footprint := _normalized_footprint(footprint)
	var shadow_offset := Vector2(0.0, maxf(1.5, extent * 0.045))
	var footprint_width_scale := 1.0 + (float(normalized_footprint.x - 1) * MARKER_FOOTPRINT_WIDTH_STEP)
	var footprint_height_scale := 1.0 + (float(normalized_footprint.y - 1) * MARKER_FOOTPRINT_HEIGHT_STEP)
	var radii := Vector2(
		radius * MARKER_GROUND_ANCHOR_WIDTH_FACTOR * footprint_width_scale,
		maxf(3.0, radius * MARKER_GROUND_ANCHOR_HEIGHT_FACTOR * footprint_height_scale)
	)
	_draw_placement_bed(tile, center, radii, remembered, extent, normalized_footprint)
	_draw_directional_contact_shadow(center, radii, remembered, extent, normalized_footprint)
	draw_colored_polygon(
		_ellipse_points(center + shadow_offset, Vector2(radii.x * 1.10, radii.y * 1.24)),
		MARKER_SHADOW_COLOR
	)
	draw_colored_polygon(_ellipse_points(center, radii), MARKER_PLATE_MEMORY if remembered else MARKER_PLATE_VISIBLE)
	draw_polyline(
		_ellipse_points(center, radii, 24, true),
		MARKER_RING_MEMORY if remembered else MARKER_RING_VISIBLE,
		maxf(1.5, extent * 0.025)
	)
	_draw_ground_anchor_tie_marks(center, radii, remembered, extent)
	if remembered:
		_draw_memory_echo_marks(center, radius, extent)
	return {
		"center": center,
		"radii": radii,
		"extent": extent,
		"footprint": normalized_footprint,
	}

func _draw_placement_bed(tile: Vector2i, center: Vector2, radii: Vector2, remembered: bool, extent: float, footprint: Vector2i) -> void:
	if radii.x <= 0.0 or radii.y <= 0.0 or extent <= 0.0:
		return
	var terrain := _terrain_at(tile) if tile.x >= 0 and tile.y >= 0 else ""
	var base_color: Color = _terrain_color(terrain, "base_color", TERRAIN_COLORS.get(terrain, TERRAIN_COLORS["grass"]))
	var detail_color: Color = _terrain_color(terrain, "detail_color", Color(0.70, 0.62, 0.38, 1.0))
	var alpha := _placement_bed_alpha(remembered)
	var bed_center := center + Vector2(0.0, radii.y * 0.04)
	var bed_radii := Vector2(radii.x * 1.24, radii.y * 1.52)
	var bed_color := _placement_bed_color(base_color, detail_color, remembered, alpha)
	draw_colored_polygon(_placement_bed_points(tile, bed_center, bed_radii, footprint), bed_color)
	draw_colored_polygon(
		_placement_bed_points(tile + Vector2i(3, 5), bed_center + Vector2(0.0, radii.y * 0.03), Vector2(radii.x * 0.94, radii.y * 1.06), footprint),
		Color(bed_color.r, bed_color.g, bed_color.b, bed_color.a * 0.36)
	)
	_draw_placement_bed_scuffs(bed_center, bed_radii, detail_color, remembered, extent)

func _draw_foreground_occlusion_lip(anchor: Dictionary, remembered: bool) -> void:
	if anchor.is_empty():
		return
	var center: Vector2 = anchor.get("center", Vector2.ZERO)
	var radii: Vector2 = anchor.get("radii", Vector2.ZERO)
	var extent := float(anchor.get("extent", 0.0))
	if radii.x <= 0.0 or radii.y <= 0.0:
		return
	var lip_color := Color(0.23, 0.18, 0.10, 0.34)
	var highlight_color := Color(0.75, 0.63, 0.32, 0.18)
	if remembered:
		lip_color = Color(0.60, 0.80, 0.84, 0.34)
		highlight_color = Color(0.90, 0.98, 1.0, 0.22)
	_draw_base_occlusion_pads(center, radii, remembered, extent)
	var left := center + Vector2(-radii.x * 0.72, radii.y * 0.28)
	var mid := center + Vector2(0.0, radii.y * 0.58)
	var right := center + Vector2(radii.x * 0.72, radii.y * 0.28)
	draw_polyline(PackedVector2Array([left, mid, right]), lip_color, maxf(1.4, extent * 0.022))
	draw_line(center + Vector2(-radii.x * 0.38, radii.y * 0.05), center + Vector2(radii.x * 0.34, radii.y * 0.08), highlight_color, maxf(1.0, extent * 0.012))

func _draw_directional_contact_shadow(center: Vector2, radii: Vector2, remembered: bool, extent: float, footprint: Vector2i) -> void:
	if radii.x <= 0.0 or radii.y <= 0.0 or extent <= 0.0:
		return
	var footprint_width := 1.0 + (float(maxi(footprint.x - 1, 0)) * 0.10)
	var footprint_depth := 1.0 + (float(maxi(footprint.y - 1, 0)) * 0.14)
	var sweep := Vector2(radii.x * 0.18, radii.y * 0.54)
	var color := OBJECT_CONTACT_SHADOW_MEMORY if remembered else OBJECT_CONTACT_SHADOW_VISIBLE
	var points := PackedVector2Array([
		center + Vector2(-radii.x * 0.58, -radii.y * 0.10),
		center + sweep + Vector2(-radii.x * 0.96 * footprint_width, radii.y * 0.02),
		center + sweep + Vector2(-radii.x * 0.44 * footprint_width, radii.y * 0.78 * footprint_depth),
		center + sweep + Vector2(radii.x * 0.84 * footprint_width, radii.y * 0.70 * footprint_depth),
		center + sweep + Vector2(radii.x * 1.02 * footprint_width, -radii.y * 0.04),
		center + Vector2(radii.x * 0.54, -radii.y * 0.12),
	])
	draw_colored_polygon(points, color)
	draw_line(
		center + Vector2(-radii.x * 0.46, radii.y * 0.18),
		center + sweep + Vector2(radii.x * 0.70 * footprint_width, radii.y * 0.26 * footprint_depth),
		Color(color.r, color.g, color.b, color.a * 0.46),
		maxf(1.0, extent * 0.012)
	)

func _draw_base_occlusion_pads(center: Vector2, radii: Vector2, remembered: bool, extent: float) -> void:
	var color := OBJECT_BASE_OCCLUSION_MEMORY if remembered else OBJECT_BASE_OCCLUSION_VISIBLE
	var band := PackedVector2Array([
		center + Vector2(-radii.x * 0.64, radii.y * 0.26),
		center + Vector2(-radii.x * 0.36, radii.y * 0.66),
		center + Vector2(radii.x * 0.30, radii.y * 0.70),
		center + Vector2(radii.x * 0.66, radii.y * 0.30),
		center + Vector2(radii.x * 0.42, radii.y * 0.48),
		center + Vector2(-radii.x * 0.42, radii.y * 0.46),
	])
	draw_colored_polygon(band, color)
	var pad_width := maxf(1.0, extent * 0.016)
	draw_line(center + Vector2(-radii.x * 0.50, radii.y * 0.49), center + Vector2(-radii.x * 0.12, radii.y * 0.68), Color(color.r, color.g, color.b, color.a * 0.78), pad_width)
	draw_line(center + Vector2(radii.x * 0.08, radii.y * 0.68), center + Vector2(radii.x * 0.54, radii.y * 0.49), Color(color.r, color.g, color.b, color.a * 0.78), pad_width)

func _draw_upper_mass_backdrop(anchor: Dictionary, family: String, remembered: bool, footprint: Vector2i) -> void:
	if anchor.is_empty():
		return
	var center: Vector2 = anchor.get("center", Vector2.ZERO)
	var radii: Vector2 = anchor.get("radii", Vector2.ZERO)
	var extent := float(anchor.get("extent", 0.0))
	if radii.x <= 0.0 or radii.y <= 0.0 or extent <= 0.0:
		return
	var metrics := _upper_mass_backdrop_metrics(family, footprint, radii, extent)
	var width := float(metrics.get("width", 0.0))
	var height := float(metrics.get("height", 0.0))
	var top_width := float(metrics.get("top_width", 0.0))
	if width <= 0.0 or height <= 0.0 or top_width <= 0.0:
		return

	var wash_color := OBJECT_UPPER_BACKDROP_MEMORY if remembered else OBJECT_UPPER_BACKDROP_VISIBLE
	var mass_shadow_color := OBJECT_VERTICAL_MASS_SHADOW_MEMORY if remembered else OBJECT_VERTICAL_MASS_SHADOW_VISIBLE
	var points := PackedVector2Array([
		center + Vector2(-width * 0.50, radii.y * 0.30),
		center + Vector2(-width * 0.46, -height * 0.30),
		center + Vector2(-top_width * 0.58, -height * 0.88),
		center + Vector2(0.0, -height),
		center + Vector2(top_width * 0.62, -height * 0.84),
		center + Vector2(width * 0.44, -height * 0.28),
		center + Vector2(width * 0.52, radii.y * 0.28),
	])
	draw_colored_polygon(points, wash_color)

	var mass_points := PackedVector2Array([
		center + Vector2(-top_width * 0.20, -height * 0.78),
		center + Vector2(top_width * 0.26, -height * 0.72),
		center + Vector2(width * 0.22, -height * 0.16),
		center + Vector2(width * 0.18, radii.y * 0.25),
		center + Vector2(-width * 0.20, radii.y * 0.26),
		center + Vector2(-width * 0.24, -height * 0.18),
	])
	draw_colored_polygon(mass_points, mass_shadow_color)
	draw_line(
		center + Vector2(-width * 0.32, -height * 0.18),
		center + Vector2(-top_width * 0.38, -height * 0.72),
		Color(wash_color.r, wash_color.g, wash_color.b, wash_color.a * 0.54),
		maxf(1.0, extent * 0.012)
	)

func _upper_mass_backdrop_metrics(family: String, footprint: Vector2i, radii: Vector2, extent: float) -> Dictionary:
	var normalized_footprint := _normalized_footprint(footprint)
	var footprint_width := 1.0 + (float(maxi(normalized_footprint.x - 1, 0)) * 0.16)
	var footprint_height := 1.0 + (float(maxi(normalized_footprint.y - 1, 0)) * 0.08)
	var width_scale := 0.84
	var height_fraction := 0.38
	var top_width_scale := 0.28
	match family:
		"town":
			width_scale = 1.48
			height_fraction = 0.62
			top_width_scale = 0.42
		"neutral_dwelling", "repeatable_service", "faction_outpost":
			width_scale = 1.26
			height_fraction = 0.50
			top_width_scale = 0.34
		"mine", "guarded_reward_site":
			width_scale = 1.18
			height_fraction = 0.48
			top_width_scale = 0.28
		"scouting_structure":
			width_scale = 0.92
			height_fraction = 0.70
			top_width_scale = 0.18
		"transit_object":
			width_scale = 1.04
			height_fraction = 0.62
			top_width_scale = 0.18
		"frontier_shrine":
			width_scale = 0.92
			height_fraction = 0.56
			top_width_scale = 0.22
		"encounter":
			width_scale = 0.98
			height_fraction = 0.44
			top_width_scale = 0.24
		"artifact":
			width_scale = 0.76
			height_fraction = 0.38
			top_width_scale = 0.18
		"hero":
			width_scale = 0.72
			height_fraction = 0.52
			top_width_scale = 0.20
	var width := maxf(6.0, radii.x * width_scale * footprint_width)
	var height := maxf(6.0, extent * height_fraction * footprint_height)
	return {
		"width": width,
		"height": minf(height, extent * 0.82),
		"top_width": maxf(width * top_width_scale, extent * 0.06),
	}

func _placement_bed_alpha(remembered: bool) -> float:
	return OBJECT_PLACEMENT_BED_MEMORY_ALPHA if remembered else OBJECT_PLACEMENT_BED_VISIBLE_ALPHA

func _placement_bed_color(base_color: Color, detail_color: Color, remembered: bool, alpha: float) -> Color:
	var ground_tone := Color(0.38, 0.32, 0.20, 1.0)
	var r := (base_color.r * 0.56) + (ground_tone.r * 0.32) + (detail_color.r * 0.12)
	var g := (base_color.g * 0.56) + (ground_tone.g * 0.32) + (detail_color.g * 0.12)
	var b := (base_color.b * 0.56) + (ground_tone.b * 0.32) + (detail_color.b * 0.12)
	if remembered:
		var memory_tone := Color(0.42, 0.58, 0.60, 1.0)
		r = (r * 0.62) + (memory_tone.r * 0.38)
		g = (g * 0.62) + (memory_tone.g * 0.38)
		b = (b * 0.62) + (memory_tone.b * 0.38)
	return Color(clampf(r, 0.0, 1.0), clampf(g, 0.0, 1.0), clampf(b, 0.0, 1.0), alpha)

func _placement_bed_points(tile: Vector2i, center: Vector2, radii: Vector2, footprint: Vector2i, segment_count: int = 22, closed: bool = false) -> PackedVector2Array:
	var points := PackedVector2Array()
	var safe_segment_count := maxi(10, segment_count)
	for index in range(safe_segment_count):
		var angle := (TAU * float(index)) / float(safe_segment_count)
		var seed: int = abs((tile.x * 73) + (tile.y * 97) + (index * 31) + (footprint.x * 13) + (footprint.y * 17))
		var jitter_x := 0.94 + (float(seed % 17) / 100.0)
		var jitter_y := 0.94 + (float(int(seed / 5) % 15) / 100.0)
		points.append(center + Vector2(cos(angle) * radii.x * jitter_x, sin(angle) * radii.y * jitter_y))
	if closed and not points.is_empty():
		points.append(points[0])
	return points

func _draw_placement_bed_scuffs(center: Vector2, radii: Vector2, detail_color: Color, remembered: bool, extent: float) -> void:
	var alpha := 0.22 if remembered else 0.18
	var scuff_color := Color(detail_color.r, detail_color.g, detail_color.b, alpha)
	var width := maxf(1.0, extent * 0.010)
	draw_line(center + Vector2(-radii.x * 0.72, -radii.y * 0.08), center + Vector2(-radii.x * 0.38, -radii.y * 0.18), scuff_color, width)
	draw_line(center + Vector2(-radii.x * 0.68, radii.y * 0.34), center + Vector2(-radii.x * 0.42, radii.y * 0.52), scuff_color, width)
	draw_line(center + Vector2(-radii.x * 0.10, radii.y * 0.66), center + Vector2(radii.x * 0.26, radii.y * 0.62), scuff_color, width)
	draw_line(center + Vector2(radii.x * 0.42, -radii.y * 0.12), center + Vector2(radii.x * 0.70, radii.y * 0.03), scuff_color, width)

func _ellipse_points(center: Vector2, radii: Vector2, segment_count: int = 24, closed: bool = false) -> PackedVector2Array:
	var points := PackedVector2Array()
	var safe_segment_count := maxi(8, segment_count)
	for index in range(safe_segment_count):
		var angle := (TAU * float(index)) / float(safe_segment_count)
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	if closed and not points.is_empty():
		points.append(points[0])
	return points

func _draw_ground_anchor_tie_marks(center: Vector2, radii: Vector2, remembered: bool, extent: float) -> void:
	var color := Color(0.42, 0.34, 0.17, 0.34)
	if remembered:
		color = Color(0.74, 0.90, 0.94, 0.48)
	var width := maxf(1.0, extent * 0.014)
	draw_line(center + Vector2(-radii.x * 0.82, radii.y * 0.30), center + Vector2(-radii.x * 0.56, radii.y * 0.58), color, width)
	draw_line(center + Vector2(-radii.x * 0.24, radii.y * 0.52), center + Vector2(-radii.x * 0.04, radii.y * 0.72), color, width)
	draw_line(center + Vector2(radii.x * 0.22, radii.y * 0.52), center + Vector2(radii.x * 0.45, radii.y * 0.70), color, width)
	draw_line(center + Vector2(radii.x * 0.62, radii.y * 0.26), center + Vector2(radii.x * 0.86, radii.y * 0.48), color, width)

func _draw_memory_echo_marks(center: Vector2, radius: float, extent: float) -> void:
	var color := Color(0.86, 0.94, 0.96, 0.76)
	var width := maxf(1.25, extent * 0.018)
	var inner := radius * 0.62
	var outer := radius * 0.92
	var tick := radius * 0.22
	draw_line(center + Vector2(-inner, -outer), center + Vector2(-inner + tick, -outer), color, width)
	draw_line(center + Vector2(inner, -outer), center + Vector2(inner - tick, -outer), color, width)
	draw_line(center + Vector2(-inner, outer), center + Vector2(-inner + tick, outer), color, width)
	draw_line(center + Vector2(inner, outer), center + Vector2(inner - tick, outer), color, width)

func _draw_selection_corners(rect: Rect2, color: Color, width: float) -> void:
	var extent := minf(rect.size.x, rect.size.y)
	var inset := maxf(4.0, extent * 0.075)
	var length := maxf(8.0, extent * 0.22)
	var top_left := rect.position + Vector2(inset, inset)
	var top_right := Vector2(rect.end.x - inset, rect.position.y + inset)
	var bottom_left := Vector2(rect.position.x + inset, rect.end.y - inset)
	var bottom_right := rect.end - Vector2(inset, inset)
	draw_line(top_left, top_left + Vector2(length, 0.0), color, width)
	draw_line(top_left, top_left + Vector2(0.0, length), color, width)
	draw_line(top_right, top_right + Vector2(-length, 0.0), color, width)
	draw_line(top_right, top_right + Vector2(0.0, length), color, width)
	draw_line(bottom_left, bottom_left + Vector2(length, 0.0), color, width)
	draw_line(bottom_left, bottom_left + Vector2(0.0, -length), color, width)
	draw_line(bottom_right, bottom_right + Vector2(-length, 0.0), color, width)
	draw_line(bottom_right, bottom_right + Vector2(0.0, -length), color, width)

func _remembered_marker_color(color: Color) -> Color:
	return Color(
		(color.r * 0.55) + (MEMORY_OBJECT_COLOR.r * 0.45),
		(color.g * 0.55) + (MEMORY_OBJECT_COLOR.g * 0.45),
		(color.b * 0.55) + (MEMORY_OBJECT_COLOR.b * 0.45),
		MEMORY_OBJECT_COLOR.a
	)

func _scaled_color(color: Color, factor: float, alpha: float = -1.0) -> Color:
	return Color(
		clampf(color.r * factor, 0.0, 1.0),
		clampf(color.g * factor, 0.0, 1.0),
		clampf(color.b * factor, 0.0, 1.0),
		color.a if alpha < 0.0 else alpha
	)

func _normalized_footprint(footprint: Vector2i) -> Vector2i:
	return Vector2i(clampi(footprint.x, 1, 3), clampi(footprint.y, 1, 3))

func _object_profile_footprint(profile: Dictionary) -> Vector2i:
	var footprint = profile.get("footprint", Vector2i(1, 1))
	if footprint is Vector2i:
		return _normalized_footprint(footprint)
	if footprint is Dictionary:
		return _normalized_footprint(Vector2i(int(footprint.get("width", 1)), int(footprint.get("height", 1))))
	return Vector2i(1, 1)

func _presence_radius_factor(family: String, footprint: Vector2i, fallback: float = MARKER_PLATE_RADIUS_FACTOR) -> float:
	match family:
		"town":
			return 0.38
		"neutral_dwelling", "mine", "repeatable_service", "faction_outpost", "guarded_reward_site":
			return maxf(fallback, 0.35)
		"scouting_structure", "transit_object", "frontier_shrine":
			return maxf(fallback, 0.32)
		"hero":
			return HERO_PLATE_RADIUS_FACTOR
		"encounter":
			return 0.34
		"artifact":
			return maxf(fallback, 0.31)
		_:
			if footprint.x > 1 or footprint.y > 1:
				return maxf(fallback, 0.34)
	return fallback

func _sprite_extent_fraction(profile: Dictionary, footprint: Vector2i) -> float:
	var family := String(profile.get("family", "pickup"))
	var base := OBJECT_SPRITE_EXTENT_FACTOR
	match family:
		"neutral_dwelling", "mine", "repeatable_service", "guarded_reward_site":
			base = 0.96
		"scouting_structure", "transit_object":
			base = 0.92
		_:
			base = OBJECT_SPRITE_EXTENT_FACTOR
	base += float(maxi(footprint.x - 1, 0)) * 0.08
	base += float(maxi(footprint.y - 1, 0)) * 0.04
	return clampf(base, 0.82, 1.10)

func _object_lift_fraction(family: String, footprint: Vector2i) -> float:
	var lift := 0.05
	match family:
		"neutral_dwelling", "mine", "repeatable_service", "guarded_reward_site":
			lift = 0.08
		"scouting_structure", "transit_object":
			lift = 0.10
		_:
			lift = 0.05
	if footprint.y > 1:
		lift += 0.02
	return lift

func _board_rect() -> Rect2:
	var viewport_rect := _map_viewport_rect()
	var tile_extent := _tile_extent_for_viewport(viewport_rect.size)
	var board_size = Vector2(tile_extent * _map_size.x, tile_extent * _map_size.y)
	var board_position = _board_position_for_focus(viewport_rect, board_size, tile_extent)
	return Rect2(board_position, board_size)

func _map_viewport_rect() -> Rect2:
	var viewport_position := Vector2(MAP_PADDING, MAP_PADDING)
	var viewport_size := Vector2(
		max(size.x - (MAP_PADDING * 2.0), 1.0),
		max(size.y - (MAP_PADDING * 2.0), 1.0)
	)
	return Rect2(viewport_position, viewport_size)

func _tile_extent_for_viewport(viewport_size: Vector2) -> float:
	if _should_fit_entire_map():
		var fit_extent: float = floor(
			min(
				viewport_size.x / float(max(_map_size.x, 1)),
				viewport_size.y / float(max(_map_size.y, 1))
			)
		)
		return max(fit_extent, MIN_TILE_EXTENT)
	var tactical_extent: float = floor(sqrt(max(viewport_size.x * viewport_size.y, 1.0) / TACTICAL_VISIBLE_TILE_AREA))
	return max(tactical_extent, MIN_TILE_EXTENT)

func _should_fit_entire_map() -> bool:
	return _map_size.x <= int(TACTICAL_VISIBLE_TILE_SPAN) and _map_size.y <= int(TACTICAL_VISIBLE_TILE_SPAN)

func _board_position_for_focus(viewport_rect: Rect2, board_size: Vector2, tile_extent: float) -> Vector2:
	var focus_tile := _camera_focus_tile()
	var focus_center := Vector2(
		(focus_tile.x + 0.5) * tile_extent,
		(focus_tile.y + 0.5) * tile_extent
	)
	var board_position := viewport_rect.position + (viewport_rect.size * 0.5) - focus_center
	if board_size.x <= viewport_rect.size.x:
		board_position.x = viewport_rect.position.x + ((viewport_rect.size.x - board_size.x) * 0.5)
	else:
		board_position.x = clamp(board_position.x, viewport_rect.end.x - board_size.x, viewport_rect.position.x)
	if board_size.y <= viewport_rect.size.y:
		board_position.y = viewport_rect.position.y + ((viewport_rect.size.y - board_size.y) * 0.5)
	else:
		board_position.y = clamp(board_position.y, viewport_rect.end.y - board_size.y, viewport_rect.position.y)
	return board_position.floor()

func _camera_focus_tile() -> Vector2:
	_ensure_camera_state()
	return _camera_center_tile

func _default_camera_focus_tile() -> Vector2:
	if _hero_tile.x >= 0 and _hero_tile.y >= 0 and _hero_tile.x < _map_size.x and _hero_tile.y < _map_size.y:
		return Vector2(float(_hero_tile.x), float(_hero_tile.y))
	return Vector2(
		float(clampi(int(_map_size.x / 2), 0, max(_map_size.x - 1, 0))),
		float(clampi(int(_map_size.y / 2), 0, max(_map_size.y - 1, 0)))
	)

func _ensure_camera_state() -> void:
	if _should_fit_entire_map():
		_manual_camera = false
		_camera_center_tile = _default_camera_focus_tile()
		_camera_center_ready = true
		return
	if not _camera_center_ready or not _manual_camera:
		_camera_center_tile = _default_camera_focus_tile()
	_camera_center_tile = _clamped_camera_center(_camera_center_tile)
	_camera_center_ready = true

func _clamped_camera_center(center: Vector2) -> Vector2:
	var viewport_rect := _map_viewport_rect()
	var tile_extent: float = _tile_extent_for_viewport(viewport_rect.size)
	var visible_columns: float = viewport_rect.size.x / maxf(tile_extent, 1.0)
	var visible_rows: float = viewport_rect.size.y / maxf(tile_extent, 1.0)
	var min_x: float = maxf(0.0, (visible_columns * 0.5) - 0.5)
	var min_y: float = maxf(0.0, (visible_rows * 0.5) - 0.5)
	var max_x: float = maxf(min_x, float(_map_size.x) - (visible_columns * 0.5) - 0.5)
	var max_y: float = maxf(min_y, float(_map_size.y) - (visible_rows * 0.5) - 0.5)
	return Vector2(
		clampf(center.x, min_x, max_x),
		clampf(center.y, min_y, max_y)
	)

func _can_pan_camera() -> bool:
	if _should_fit_entire_map():
		return false
	var viewport_rect := _map_viewport_rect()
	var tile_extent := _tile_extent_for_viewport(viewport_rect.size)
	return tile_extent * float(_map_size.x) > viewport_rect.size.x + 0.01 or tile_extent * float(_map_size.y) > viewport_rect.size.y + 0.01

func _pan_camera_pixels(pixel_delta: Vector2) -> bool:
	if not _can_pan_camera():
		return false
	var viewport_rect := _map_viewport_rect()
	var tile_extent := _tile_extent_for_viewport(viewport_rect.size)
	return _set_camera_center(_camera_center_tile - (pixel_delta / max(tile_extent, 1.0)), true)

func _set_camera_center(center: Vector2, manual: bool) -> bool:
	var previous_center := _camera_center_tile
	_camera_center_tile = _clamped_camera_center(center)
	_camera_center_ready = true
	_manual_camera = manual
	var changed := previous_center.distance_to(_camera_center_tile) > 0.01
	if changed:
		queue_redraw()
	return changed

func pan_tiles(delta: Vector2i) -> bool:
	if not _can_pan_camera():
		return false
	_ensure_camera_state()
	return _set_camera_center(_camera_center_tile + Vector2(float(delta.x), float(delta.y)), true)

func focus_on_hero() -> bool:
	var previous_center := _camera_center_tile
	_manual_camera = false
	_camera_center_tile = _clamped_camera_center(_default_camera_focus_tile())
	_camera_center_ready = true
	var changed := previous_center.distance_to(_camera_center_tile) > 0.01
	if changed:
		queue_redraw()
	return changed

func _tile_rect(board_rect: Rect2, tile: Vector2i) -> Rect2:
	var cell_size = board_rect.size / Vector2(float(max(_map_size.x, 1)), float(max(_map_size.y, 1)))
	return Rect2(
		board_rect.position + Vector2(tile.x * cell_size.x, tile.y * cell_size.y),
		cell_size
	)

func _tile_from_local(local_position: Vector2) -> Vector2i:
	var viewport_rect := _map_viewport_rect()
	if not viewport_rect.has_point(local_position):
		return Vector2i(-1, -1)
	var board_rect = _board_rect()
	if not board_rect.has_point(local_position):
		return Vector2i(-1, -1)
	var cell_size = board_rect.size / Vector2(float(max(_map_size.x, 1)), float(max(_map_size.y, 1)))
	var x = int(floor((local_position.x - board_rect.position.x) / cell_size.x))
	var y = int(floor((local_position.y - board_rect.position.y) / cell_size.y))
	if x < 0 or y < 0 or x >= _map_size.x or y >= _map_size.y:
		return Vector2i(-1, -1)
	return Vector2i(x, y)

func _visible_tile_bounds(board_rect: Rect2, viewport_rect: Rect2) -> Rect2i:
	var cell_size = board_rect.size / Vector2(float(max(_map_size.x, 1)), float(max(_map_size.y, 1)))
	var start_x = clampi(int(floor((viewport_rect.position.x - board_rect.position.x) / cell_size.x)) - 1, 0, max(_map_size.x - 1, 0))
	var start_y = clampi(int(floor((viewport_rect.position.y - board_rect.position.y) / cell_size.y)) - 1, 0, max(_map_size.y - 1, 0))
	var end_x = clampi(int(ceil((viewport_rect.end.x - board_rect.position.x) / cell_size.x)) + 1, 0, _map_size.x)
	var end_y = clampi(int(ceil((viewport_rect.end.y - board_rect.position.y) / cell_size.y)) + 1, 0, _map_size.y)
	return Rect2i(
		Vector2i(start_x, start_y),
		Vector2i(max(end_x - start_x, 0), max(end_y - start_y, 0))
	)

func _draw_viewport_mask(viewport_rect: Rect2) -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, viewport_rect.position.y)), FRAME_FILL, true)
	draw_rect(Rect2(Vector2(0.0, viewport_rect.end.y), Vector2(size.x, max(size.y - viewport_rect.end.y, 0.0))), FRAME_FILL, true)
	draw_rect(Rect2(Vector2(0.0, 0.0), Vector2(viewport_rect.position.x, size.y)), FRAME_FILL, true)
	draw_rect(Rect2(Vector2(viewport_rect.end.x, 0.0), Vector2(max(size.x - viewport_rect.end.x, 0.0), size.y)), FRAME_FILL, true)

func validation_view_metrics() -> Dictionary:
	var viewport_rect := _map_viewport_rect()
	var board_rect := _board_rect()
	var cell_size: Vector2 = board_rect.size / Vector2(float(max(_map_size.x, 1)), float(max(_map_size.y, 1)))
	var visible_columns: float = min(float(_map_size.x), viewport_rect.size.x / max(cell_size.x, 1.0))
	var visible_rows: float = min(float(_map_size.y), viewport_rect.size.y / max(cell_size.y, 1.0))
	var focus_tile := _camera_focus_tile()
	var visible_bounds := _visible_tile_bounds(board_rect, viewport_rect)
	return {
		"map_size": {"x": _map_size.x, "y": _map_size.y},
		"viewport_rect": _rect_payload(viewport_rect),
		"board_rect": _rect_payload(board_rect),
		"tile_extent": cell_size.x,
		"visible_tile_columns": visible_columns,
		"visible_tile_rows": visible_rows,
		"visible_tile_area": visible_columns * visible_rows,
		"full_map_visible": board_rect.size.x <= viewport_rect.size.x + 0.01 and board_rect.size.y <= viewport_rect.size.y + 0.01,
		"fit_entire_map": _should_fit_entire_map(),
		"pan_supported": _can_pan_camera(),
		"manual_camera": _manual_camera,
		"camera_focus_tile": {"x": int(round(focus_tile.x)), "y": int(round(focus_tile.y))},
		"camera_focus_tile_precise": {"x": focus_tile.x, "y": focus_tile.y},
		"visible_bounds": {
			"x": visible_bounds.position.x,
			"y": visible_bounds.position.y,
			"width": visible_bounds.size.x,
			"height": visible_bounds.size.y,
		},
	}

func validation_tile_presentation(tile: Vector2i) -> Dictionary:
	var explored := _session != null and OverworldRulesScript.is_tile_explored(_session, tile.x, tile.y)
	var visible := _session != null and OverworldRulesScript.is_tile_visible(_session, tile.x, tile.y)
	var has_town := explored and _has_town_at(tile)
	var has_resource := explored and _has_resource_at(tile)
	var has_artifact := explored and _has_artifact_at(tile)
	var has_rememberable_encounter := explored and _has_rememberable_encounter_at(tile)
	var has_visible_encounter := visible and _has_encounter_at(tile)
	var has_visible_hero := visible and _has_hero_at(tile)
	var object_kinds := []
	if has_town:
		object_kinds.append("town")
	if has_resource:
		object_kinds.append("resource")
	if has_artifact:
		object_kinds.append("artifact")
	if has_visible_encounter or has_rememberable_encounter:
		object_kinds.append("encounter")
	var remembered_object := explored and not visible and (
		has_town or has_resource or has_artifact or has_rememberable_encounter
	)
	return {
		"x": tile.x,
		"y": tile.y,
		"explored": explored,
		"visible": visible,
		"remembered": explored and not visible,
		"has_town": has_town,
		"has_resource": has_resource,
		"has_artifact": has_artifact,
		"has_rememberable_encounter": has_rememberable_encounter,
		"has_visible_encounter": has_visible_encounter,
		"has_visible_hero": has_visible_hero,
		"draws_discoverable_object": (visible and (has_town or has_resource or has_artifact or has_visible_encounter)) or remembered_object,
		"draws_remembered_object": remembered_object,
		"terrain_presentation": _terrain_visual_payload(tile, explored, visible),
		"marker_readability": _marker_readability_payload(tile, explored, visible, object_kinds, has_visible_hero),
		"art_presentation": _object_art_payload(tile, explored, visible, object_kinds),
	}

func _terrain_visual_payload(tile: Vector2i, explored: bool, visible: bool) -> Dictionary:
	if not explored:
		return {
			"terrain": "",
			"state": "unexplored_hidden",
			"unexplored_hidden": true,
			"terrain_fully_visible": false,
			"uses_memory_terrain_dimming": false,
			"memory_overlay_alpha": 0.0,
			"pattern_detail": "hidden",
			"fill_color": _color_payload(UNEXPLORED_COLOR),
			"texture_loaded": false,
			"texture_asset_id": "",
			"texture_path": "",
			"rendering_mode": "hidden_fog",
		}
	var terrain := _terrain_at(tile)
	var base_color: Color = _terrain_color(terrain, "base_color", TERRAIN_COLORS.get(terrain, TERRAIN_COLORS["grass"]))
	var road_payload := _road_tile_payload(tile)
	var transition_mask := _terrain_transition_edge_mask(tile)
	var tile_art_entry := _terrain_base_art_entry(terrain, tile)
	var tile_art_path := String(tile_art_entry.get("path", ""))
	var tile_art_primary := _terrain_art_can_be_primary(terrain)
	var tile_art_loaded := tile_art_primary and _terrain_art_texture(tile_art_path) is Texture2D
	var edge_art_count := _edge_transition_art_count(terrain, transition_mask)
	var road_art_loaded := _road_overlay_art_loaded(road_payload, tile)
	var primary_base_model := TERRAIN_ORIGINAL_TILE_BANK_RENDERING_MODE if tile_art_loaded else (TERRAIN_GRAMMAR_RENDERING_MODE if not _terrain_style(terrain).is_empty() else "procedural_color_pattern")
	return {
		"terrain": terrain,
		"state": "current_scout_net" if visible else "explored_outside_scout_net",
		"unexplored_hidden": false,
		"terrain_fully_visible": true,
		"uses_memory_terrain_dimming": false,
		"memory_overlay_alpha": 0.0,
		"pattern_detail": "full",
		"fill_color": _color_payload(base_color),
		"texture_loaded": tile_art_loaded,
		"texture_asset_id": String(tile_art_entry.get("variant_key", "")),
		"texture_path": tile_art_path,
		"uses_sampled_texture": false,
		"uses_authored_tile_art": tile_art_loaded,
		"uses_original_tile_bank": tile_art_loaded,
		"generated_source_primary": false,
		"tile_art_source_basis": _terrain_tile_art_source_basis(terrain),
		"primary_base_model": primary_base_model,
		"fallback_pattern_rendering": not tile_art_loaded,
		"terrain_model": String(_terrain_grammar.get("rendering_model", TERRAIN_GRAMMAR_RENDERING_MODE)),
		"rendering_mode": primary_base_model,
		"autotile_ready": not _terrain_style(terrain).is_empty(),
		"terrain_group": _terrain_group(terrain),
		"style_id": _terrain_style_id(terrain),
		"pattern": _terrain_pattern(terrain),
		"terrain_noise_profile": "quiet_low_contrast_macro_readable" if tile_art_loaded else "grammar_pattern_fallback",
		"transition_edge_mask": transition_mask,
		"edge_transition_count": transition_mask.length(),
		"edge_transition_art_count": edge_art_count,
		"edge_transition_art_loaded": edge_art_count > 0 and edge_art_count == transition_mask.length(),
		"transition_shape_model": "jagged_directional_overlay" if edge_art_count > 0 else "procedural_strip_fallback",
		"road_overlay": not road_payload.is_empty(),
		"road_overlay_id": String(road_payload.get("overlay_id", "")),
		"road_role": String(road_payload.get("role", "")),
		"road_overlay_art": road_art_loaded,
		"road_shape_model": "connection_piece_overlay" if road_art_loaded else ("procedural_connector_lines" if not road_payload.is_empty() else ""),
		"road_connection_key": _road_connection_key(tile) if not road_payload.is_empty() else "",
	}

func _edge_transition_art_count(terrain: String, transition_mask: String) -> int:
	if not _terrain_art_can_be_primary(terrain):
		return 0
	var count := 0
	for direction in ["N", "E", "S", "W"]:
		if not (direction in transition_mask):
			continue
		if _terrain_art_texture(_terrain_edge_art_path(terrain, direction)) is Texture2D:
			count += 1
	return count

func _road_overlay_art_loaded(road_payload: Dictionary, tile: Vector2i) -> bool:
	if road_payload.is_empty():
		return false
	var overlay_id := String(road_payload.get("overlay_id", "road_dirt"))
	if not _road_overlay_art_can_be_primary(overlay_id):
		return false
	var art := _road_overlay_art_paths(overlay_id)
	if art.is_empty():
		return false
	var center_loaded := _terrain_art_texture(String(art.get("center", ""))) is Texture2D
	var connectors = art.get("connectors", {})
	var has_neighbor := false
	var loaded_connector := false
	if connectors is Dictionary:
		for direction in DIRECTIONS:
			var neighbor: Vector2i = tile + direction
			if not _road_tiles.has(_tile_key(neighbor)):
				continue
			has_neighbor = true
			if _terrain_art_texture(String(connectors.get(_direction_key(direction), ""))) is Texture2D:
				loaded_connector = true
	if has_neighbor:
		return center_loaded and loaded_connector
	return center_loaded

func _object_art_payload(tile: Vector2i, explored: bool, visible: bool, object_kinds: Array) -> Dictionary:
	if not explored:
		return {
			"uses_asset_sprite": false,
			"fallback_procedural_marker": false,
			"fallback_silhouette_model": "",
			"sprite_asset_ids": [],
			"remembered_sprite_treatment": "",
			"sprite_settlement_model": "",
			"settled_sprite_occlusion": false,
			"sprite_depth_contact_cues": false,
			"sprite_depth_cue_model": "",
			"sprite_placement_bed": false,
			"sprite_placement_bed_model": "",
			"sprite_upper_mass_backdrop": false,
			"sprite_upper_mass_backdrop_model": "",
			"sprite_vertical_mass_shadow": false,
			"unmapped_object_fallback": String(_overworld_art_manifest.get("unmapped_object_fallback", "procedural_marker")),
		}
	var sprite_asset_ids: Array[String] = []
	var sprite_footprints: Array = []
	var resource_node := _resource_node_at(tile)
	if not resource_node.is_empty():
		var resource_asset_id := _resource_asset_id(resource_node)
		if resource_asset_id != "" and _object_texture_for_asset(resource_asset_id) is Texture2D:
			sprite_asset_ids.append(resource_asset_id)
			var resource_footprint := _object_profile_footprint(_resource_object_profile(resource_node))
			sprite_footprints.append({"width": resource_footprint.x, "height": resource_footprint.y})
	var artifact_node := _artifact_node_at(tile)
	if not artifact_node.is_empty() and _artifact_default_asset_id != "":
		if _object_texture_for_asset(_artifact_default_asset_id) is Texture2D:
			sprite_asset_ids.append(_artifact_default_asset_id)
			var artifact_footprint := _object_profile_footprint(_artifact_object_profile())
			sprite_footprints.append({"width": artifact_footprint.x, "height": artifact_footprint.y})
	var uses_asset_sprite := not sprite_asset_ids.is_empty()
	return {
		"uses_asset_sprite": uses_asset_sprite,
		"fallback_procedural_marker": not uses_asset_sprite and not object_kinds.is_empty(),
		"fallback_silhouette_model": OBJECT_PROCEDURAL_FALLBACK_MODEL if not uses_asset_sprite and not object_kinds.is_empty() else "",
		"sprite_asset_ids": sprite_asset_ids,
		"sprite_footprints": sprite_footprints,
		"remembered_sprite_treatment": "ghosted_sprite_with_ground_anchor" if uses_asset_sprite and not visible else "",
		"sprite_settlement_model": OBJECT_SPRITE_SETTLEMENT_MODEL if uses_asset_sprite else "",
		"settled_sprite_occlusion": uses_asset_sprite,
		"sprite_depth_contact_cues": uses_asset_sprite,
		"sprite_depth_cue_model": OBJECT_DEPTH_CUE_MODEL if uses_asset_sprite else "",
		"sprite_placement_bed": uses_asset_sprite,
		"sprite_placement_bed_model": OBJECT_PLACEMENT_BED_MODEL if uses_asset_sprite else "",
		"sprite_upper_mass_backdrop": uses_asset_sprite,
		"sprite_upper_mass_backdrop_model": OBJECT_UPPER_BACKDROP_MODEL if uses_asset_sprite else "",
		"sprite_vertical_mass_shadow": uses_asset_sprite,
		"unmapped_object_fallback": String(_overworld_art_manifest.get("unmapped_object_fallback", "procedural_marker")),
	}

func _marker_readability_payload(tile: Vector2i, explored: bool, visible: bool, object_kinds: Array, has_visible_hero: bool) -> Dictionary:
	var marker_kinds := object_kinds.duplicate()
	if has_visible_hero:
		marker_kinds.append("hero")
	var has_object_marker := not object_kinds.is_empty()
	var remembered := explored and not visible and has_object_marker
	var board_rect := _board_rect()
	var rect := _tile_rect(board_rect, tile)
	var extent := minf(rect.size.x, rect.size.y)
	var min_symbol_fraction := _minimum_symbol_fraction(object_kinds)
	var art_payload := _object_art_payload(tile, explored, visible, object_kinds)
	var uses_asset_sprite := bool(art_payload.get("uses_asset_sprite", false))
	if uses_asset_sprite:
		min_symbol_fraction = maxf(min_symbol_fraction, OBJECT_SPRITE_EXTENT_FACTOR)
	var dominant_profile := _dominant_object_profile(tile, object_kinds, has_visible_hero)
	var dominant_footprint := _object_profile_footprint(dominant_profile) if not dominant_profile.is_empty() else Vector2i(1, 1)
	var dominant_family := String(dominant_profile.get("family", ""))
	var plate_radius_fraction := MARKER_PLATE_RADIUS_FACTOR
	if uses_asset_sprite:
		plate_radius_fraction = _presence_radius_factor(dominant_family, dominant_footprint, OBJECT_SPRITE_PLATE_RADIUS_FACTOR)
	elif has_visible_hero and not has_object_marker:
		plate_radius_fraction = HERO_PLATE_RADIUS_FACTOR
	elif not dominant_profile.is_empty():
		plate_radius_fraction = _presence_radius_factor(dominant_family, dominant_footprint)
	var anchor_half_width_fraction := plate_radius_fraction * MARKER_GROUND_ANCHOR_WIDTH_FACTOR * (1.0 + (float(dominant_footprint.x - 1) * MARKER_FOOTPRINT_WIDTH_STEP))
	var anchor_half_height_fraction := plate_radius_fraction * MARKER_GROUND_ANCHOR_HEIGHT_FACTOR * (1.0 + (float(dominant_footprint.y - 1) * MARKER_FOOTPRINT_HEIGHT_STEP))
	var has_presence := has_object_marker or has_visible_hero
	var backdrop_metrics := _upper_mass_backdrop_metrics(
		dominant_family,
		dominant_footprint,
		Vector2(anchor_half_width_fraction * extent, anchor_half_height_fraction * extent),
		extent
	) if has_presence else {}
	return {
		"object_kinds": object_kinds,
		"marker_kinds": marker_kinds,
		"contrast_plate": has_presence,
		"ground_anchor": has_presence,
		"anchor_shape": MARKER_GROUND_ANCHOR_STYLE if has_presence else "",
		"presence_model": OBJECT_PRESENCE_MODEL if has_presence else "",
		"terrain_quieting_bed": has_presence,
		"placement_bed_model": OBJECT_PLACEMENT_BED_MODEL if has_presence else "",
		"placement_bed_shape": "organic_footprint_clearing" if has_presence else "",
		"placement_bed_alpha": _placement_bed_alpha(remembered) if has_presence else 0.0,
		"placement_bed_terrain_tinted": has_presence,
		"placement_bed_ui_plate": false,
		"upper_mass_backdrop": has_presence,
		"upper_mass_backdrop_model": OBJECT_UPPER_BACKDROP_MODEL if has_presence else "",
		"upper_mass_backdrop_shape": "family_scaled_rear_wash" if has_presence else "",
		"upper_mass_backdrop_alpha": (OBJECT_UPPER_BACKDROP_MEMORY.a if remembered else OBJECT_UPPER_BACKDROP_VISIBLE.a) if has_presence else 0.0,
		"upper_mass_backdrop_position": "behind_upper_body" if has_presence else "",
		"upper_mass_backdrop_height_fraction": (float(backdrop_metrics.get("height", 0.0)) / extent) if has_presence and extent > 0.0 else 0.0,
		"upper_mass_backdrop_width_fraction": (float(backdrop_metrics.get("width", 0.0)) / extent) if has_presence and extent > 0.0 else 0.0,
		"upper_mass_backdrop_ui_halo": false,
		"upper_mass_backdrop_ui_badge": false,
		"vertical_mass_shadow": has_presence,
		"vertical_mass_shadow_model": OBJECT_VERTICAL_MASS_SHADOW_MODEL if has_presence else "",
		"vertical_mass_shadow_alpha": (OBJECT_VERTICAL_MASS_SHADOW_MEMORY.a if remembered else OBJECT_VERTICAL_MASS_SHADOW_VISIBLE.a) if has_presence else 0.0,
		"foreground_occlusion_lip": has_presence,
		"occlusion_model": OBJECT_OCCLUSION_MODEL if has_presence else "",
		"depth_cue_model": OBJECT_DEPTH_CUE_MODEL if has_presence else "",
		"directional_contact_shadow": has_presence,
		"contact_shadow_model": OBJECT_CONTACT_SHADOW_MODEL if has_presence else "",
		"contact_shadow_alpha": (OBJECT_CONTACT_SHADOW_MEMORY.a if remembered else OBJECT_CONTACT_SHADOW_VISIBLE.a) if has_presence else 0.0,
		"base_occlusion_pads": has_presence,
		"base_occlusion_model": OBJECT_BASE_OCCLUSION_MODEL if has_presence else "",
		"base_occlusion_alpha": (OBJECT_BASE_OCCLUSION_MEMORY.a if remembered else OBJECT_BASE_OCCLUSION_VISIBLE.a) if has_presence else 0.0,
		"dominant_object_family": dominant_family,
		"footprint_width_tiles": dominant_footprint.x if has_presence else 0,
		"footprint_height_tiles": dominant_footprint.y if has_presence else 0,
		"footprint_anchor_width_fraction": anchor_half_width_fraction * 2.0 if has_presence else 0.0,
		"footprint_anchor_height_fraction": anchor_half_height_fraction * 2.0 if has_presence else 0.0,
		"procedural_world_silhouette": bool(art_payload.get("fallback_procedural_marker", false)),
		"mapped_sprite_settlement": uses_asset_sprite,
		"ui_badge_plate": false,
		"plate_radius_fraction": plate_radius_fraction,
		"plate_alpha": MARKER_PLATE_MEMORY.a if remembered else MARKER_PLATE_VISIBLE.a,
		"anchor_alpha": MARKER_PLATE_MEMORY.a if remembered else MARKER_PLATE_VISIBLE.a,
		"ring_alpha": MARKER_RING_MEMORY.a if remembered else MARKER_RING_VISIBLE.a,
		"outline_alpha": MEMORY_OBJECT_OUTLINE.a if remembered else MARKER_OUTLINE_COLOR.a,
		"grid_alpha": GRID_COLOR.a,
		"memory_echo": remembered,
		"remembered_marker_alpha": MEMORY_OBJECT_COLOR.a if remembered else 0.0,
		"min_symbol_extent_fraction": min_symbol_fraction,
		"min_symbol_extent_px": min_symbol_fraction * extent,
		"hero_emphasis": has_visible_hero and tile == _hero_tile,
		"hero_symbol_extent_fraction": HERO_MARKER_RADIUS * 2.0 if has_visible_hero else 0.0,
		"selection_emphasis": tile == _selected_tile,
		"focus_ring_width_px": maxf(3.0, extent * FOCUS_RING_WIDTH_FACTOR),
		"tile_extent_px": extent,
	}

func _minimum_symbol_fraction(object_kinds: Array) -> float:
	var minimum := 0.0
	for kind_value in object_kinds:
		var fraction := _symbol_extent_fraction(String(kind_value))
		if fraction <= 0.0:
			continue
		if minimum <= 0.0 or fraction < minimum:
			minimum = fraction
	return minimum

func _symbol_extent_fraction(kind: String) -> float:
	match kind:
		"town":
			return minf(TOWN_MARKER_BODY_WIDTH, TOWN_MARKER_BODY_HEIGHT)
		"resource":
			return RESOURCE_MARKER_RADIUS * 2.0
		"artifact":
			return ARTIFACT_MARKER_OUTER_RADIUS * 2.0
		"encounter":
			return ENCOUNTER_MARKER_EXTENT * 2.0
		_:
			return 0.0

func _rect_payload(rect: Rect2) -> Dictionary:
	return {
		"x": rect.position.x,
		"y": rect.position.y,
		"width": rect.size.x,
		"height": rect.size.y,
		"end_x": rect.end.x,
		"end_y": rect.end.y,
	}

func _color_payload(color: Color) -> Dictionary:
	return {
		"r": color.r,
		"g": color.g,
		"b": color.b,
		"a": color.a,
	}

func _load_terrain_grammar() -> void:
	_terrain_grammar.clear()
	_terrain_styles.clear()
	_terrain_overlay_styles.clear()
	_terrain_base_art.clear()
	_terrain_edge_art.clear()
	_terrain_art_textures.clear()
	_terrain_art_missing.clear()
	_road_overlay_art.clear()
	var grammar := ContentService.get_terrain_grammar()
	if grammar.is_empty() and FileAccess.file_exists(TERRAIN_GRAMMAR_PATH):
		var file := FileAccess.open(TERRAIN_GRAMMAR_PATH, FileAccess.READ)
		if file != null:
			var parser := JSON.new()
			if parser.parse(file.get_as_text()) == OK and parser.data is Dictionary:
				grammar = parser.data
	if grammar.is_empty():
		push_warning("Terrain grammar is missing; overworld terrain will use procedural fallback colors.")
		return
	_terrain_grammar = grammar
	var terrain_classes = grammar.get("terrain_classes", [])
	if terrain_classes is Array:
		for terrain_class in terrain_classes:
			if not (terrain_class is Dictionary):
				continue
			var terrain_id := String(terrain_class.get("id", "")).strip_edges().to_lower()
			if terrain_id != "":
				_terrain_styles[terrain_id] = terrain_class
				_register_terrain_art(terrain_id, terrain_class)
	var overlay_classes = grammar.get("overlay_classes", [])
	if overlay_classes is Array:
		for overlay_class in overlay_classes:
			if not (overlay_class is Dictionary):
				continue
			var overlay_id := String(overlay_class.get("id", "")).strip_edges()
			if overlay_id == "":
				continue
			var normalized: Dictionary = overlay_class.duplicate(true)
			for color_key in ["color", "edge_color", "shadow_color", "center_color"]:
				normalized[color_key] = _color_from_hex(String(overlay_class.get(color_key, "")), _road_default_color(color_key))
			_terrain_overlay_styles[overlay_id] = normalized
			_register_road_overlay_art(overlay_id, overlay_class)

func _register_terrain_art(terrain_id: String, terrain_class: Dictionary) -> void:
	var tile_art = terrain_class.get("tile_art", {})
	if not (tile_art is Dictionary):
		return
	var base_tiles = tile_art.get("base_tiles", [])
	var normalized_base_tiles: Array = []
	if base_tiles is Array:
		for entry in base_tiles:
			if not (entry is Dictionary):
				continue
			var texture_path := String(entry.get("path", "")).strip_edges()
			if texture_path == "":
				continue
			normalized_base_tiles.append({
				"variant_key": String(entry.get("variant_key", "")),
				"path": texture_path,
			})
	if not normalized_base_tiles.is_empty():
		_terrain_base_art[terrain_id] = normalized_base_tiles
	var edge_overlays = tile_art.get("edge_overlays", {})
	var normalized_edges := {}
	if edge_overlays is Dictionary:
		for direction in ["N", "E", "S", "W"]:
			var edge_path := String(edge_overlays.get(direction, "")).strip_edges()
			if edge_path != "":
				normalized_edges[direction] = edge_path
	if not normalized_edges.is_empty():
		_terrain_edge_art[terrain_id] = normalized_edges

func _register_road_overlay_art(overlay_id: String, overlay_class: Dictionary) -> void:
	var tile_art = overlay_class.get("tile_art", {})
	if not (tile_art is Dictionary):
		return
	var center_path := String(tile_art.get("center", "")).strip_edges()
	var connectors = tile_art.get("connectors", {})
	var normalized_connectors := {}
	if connectors is Dictionary:
		for direction in ["N", "E", "S", "W", "NE", "SE", "SW", "NW"]:
			var connector_path := String(connectors.get(direction, "")).strip_edges()
			if connector_path != "":
				normalized_connectors[direction] = connector_path
	var normalized := {}
	if center_path != "":
		normalized["center"] = center_path
	if not normalized_connectors.is_empty():
		normalized["connectors"] = normalized_connectors
	if not normalized.is_empty():
		_road_overlay_art[overlay_id] = normalized

func _terrain_style(terrain_id: String) -> Dictionary:
	return _terrain_styles.get(terrain_id.strip_edges().to_lower(), {})

func _terrain_color(terrain_id: String, key: String, fallback: Color) -> Color:
	var style := _terrain_style(terrain_id)
	return _color_from_hex(String(style.get(key, "")), fallback)

func _terrain_pattern(terrain_id: String) -> String:
	var style := _terrain_style(terrain_id)
	return String(style.get("pattern", "field_tufts"))

func _terrain_group(terrain_id: String) -> String:
	var style := _terrain_style(terrain_id)
	return String(style.get("terrain_group", terrain_id))

func _terrain_style_id(terrain_id: String) -> String:
	var style := _terrain_style(terrain_id)
	return String(style.get("style_id", terrain_id))

func _terrain_tile_art_source_basis(terrain_id: String) -> String:
	var style := _terrain_style(terrain_id)
	var tile_art = style.get("tile_art", {})
	if tile_art is Dictionary and String(tile_art.get("source_basis", "")).strip_edges() != "":
		return String(tile_art.get("source_basis", "")).strip_edges()
	var grammar_basis := String(_terrain_grammar.get("primary_base_model", "")).strip_edges()
	if grammar_basis == TERRAIN_ORIGINAL_TILE_BANK_RENDERING_MODE:
		return "original_procedural_reference_informed"
	return grammar_basis

func _terrain_art_can_be_primary(terrain_id: String) -> bool:
	var source_basis := _terrain_tile_art_source_basis(terrain_id)
	if source_basis == "" or source_basis == TERRAIN_DEPRECATED_GENERATED_SOURCE_BASIS:
		return false
	if source_basis.find("generated") >= 0:
		return false
	return source_basis.find("original") >= 0 or String(_terrain_grammar.get("primary_base_model", "")) == TERRAIN_ORIGINAL_TILE_BANK_RENDERING_MODE

func _road_overlay_art_source_basis(overlay_id: String) -> String:
	var style := _road_overlay_style(overlay_id)
	var tile_art = style.get("tile_art", {})
	if tile_art is Dictionary and String(tile_art.get("source_basis", "")).strip_edges() != "":
		return String(tile_art.get("source_basis", "")).strip_edges()
	var manifest_rendering = _overworld_art_manifest.get("terrain_rendering", {})
	if manifest_rendering is Dictionary:
		var source_basis := String(manifest_rendering.get("tile_art_source_basis", "")).strip_edges()
		if source_basis != "":
			return source_basis
	return "original_procedural_reference_informed"

func _road_overlay_art_can_be_primary(overlay_id: String) -> bool:
	var source_basis := _road_overlay_art_source_basis(overlay_id)
	return source_basis != "" and source_basis != TERRAIN_DEPRECATED_GENERATED_SOURCE_BASIS and source_basis.find("generated") < 0

func _terrain_base_art_entry(terrain_id: String, tile: Vector2i) -> Dictionary:
	var entries = _terrain_base_art.get(terrain_id.strip_edges().to_lower(), [])
	if not (entries is Array) or entries.is_empty():
		return {}
	var index := _deterministic_art_index(tile, terrain_id, entries.size())
	var entry = entries[index]
	return entry if entry is Dictionary else {}

func _deterministic_art_index(tile: Vector2i, terrain_id: String, count: int) -> int:
	if count <= 0:
		return 0
	var seed: int = abs((tile.x * 37) + (tile.y * 53) + (terrain_id.length() * 19))
	return seed % count

func _terrain_edge_art_path(terrain_id: String, direction: String) -> String:
	var edge_paths = _terrain_edge_art.get(terrain_id.strip_edges().to_lower(), {})
	if not (edge_paths is Dictionary):
		return ""
	return String(edge_paths.get(direction, ""))

func _road_overlay_art_paths(overlay_id: String) -> Dictionary:
	var art = _road_overlay_art.get(overlay_id, {})
	return art if art is Dictionary else {}

func _terrain_art_texture(texture_path: String):
	var normalized_path := texture_path.strip_edges()
	if normalized_path == "":
		return null
	if _terrain_art_textures.has(normalized_path):
		return _terrain_art_textures.get(normalized_path)
	if _terrain_art_missing.has(normalized_path):
		return null
	var texture = _texture_from_path(normalized_path)
	if texture is Texture2D:
		_terrain_art_textures[normalized_path] = texture
		return texture
	_terrain_art_missing[normalized_path] = true
	return null

func _terrain_transition_priority(terrain_id: String) -> int:
	var style := _terrain_style(terrain_id)
	return int(style.get("transition_priority", 0))

func _terrain_transition_edge_mask(tile: Vector2i) -> String:
	if _session == null or not OverworldRulesScript.is_tile_explored(_session, tile.x, tile.y):
		return ""
	var terrain := _terrain_at(tile)
	var group := _terrain_group(terrain)
	var priority := _terrain_transition_priority(terrain)
	var mask := ""
	var checks := {
		"N": Vector2i(0, -1),
		"E": Vector2i(1, 0),
		"S": Vector2i(0, 1),
		"W": Vector2i(-1, 0),
	}
	for label in checks.keys():
		var neighbor: Vector2i = tile + checks[label]
		if neighbor.x < 0 or neighbor.y < 0 or neighbor.x >= _map_size.x or neighbor.y >= _map_size.y:
			continue
		if not OverworldRulesScript.is_tile_explored(_session, neighbor.x, neighbor.y):
			continue
		var neighbor_terrain := _terrain_at(neighbor)
		if neighbor_terrain == "" or _terrain_group(neighbor_terrain) == group:
			continue
		if priority >= _terrain_transition_priority(neighbor_terrain):
			mask += label
	return mask

func _road_overlay_style(overlay_id: String) -> Dictionary:
	if _terrain_overlay_styles.has(overlay_id):
		return _terrain_overlay_styles.get(overlay_id)
	return {
		"color": ROAD_DEFAULT_COLOR,
		"edge_color": ROAD_DEFAULT_EDGE_COLOR,
		"shadow_color": ROAD_DEFAULT_SHADOW_COLOR,
		"center_color": ROAD_DEFAULT_CENTER_COLOR,
		"width_fraction": ROAD_DEFAULT_WIDTH_FACTOR,
	}

func _road_connection_key(tile: Vector2i) -> String:
	var keys: Array[String] = []
	for direction in DIRECTIONS:
		var neighbor: Vector2i = tile + direction
		if _road_tiles.has(_tile_key(neighbor)):
			keys.append(_direction_key(direction))
	keys.sort()
	var result := ""
	for key in keys:
		if result != "":
			result += "+"
		result += key
	return result

func _direction_key(direction: Vector2i) -> String:
	if direction == Vector2i(0, -1):
		return "N"
	if direction == Vector2i(1, -1):
		return "NE"
	if direction == Vector2i(1, 0):
		return "E"
	if direction == Vector2i(1, 1):
		return "SE"
	if direction == Vector2i(0, 1):
		return "S"
	if direction == Vector2i(-1, 1):
		return "SW"
	if direction == Vector2i(-1, 0):
		return "W"
	if direction == Vector2i(-1, -1):
		return "NW"
	return ""

func _road_default_color(key: String) -> Color:
	match key:
		"edge_color":
			return ROAD_DEFAULT_EDGE_COLOR
		"shadow_color":
			return ROAD_DEFAULT_SHADOW_COLOR
		"center_color":
			return ROAD_DEFAULT_CENTER_COLOR
		_:
			return ROAD_DEFAULT_COLOR

func _color_from_hex(value: String, fallback: Color) -> Color:
	if value.begins_with("#") and value.length() in [7, 9]:
		return Color.html(value)
	return fallback

func _rebuild_road_tiles() -> void:
	_road_tiles.clear()
	var roads = _terrain_layers.get("roads", [])
	if not (roads is Array):
		return
	for road in roads:
		if not (road is Dictionary):
			continue
		var overlay_id := String(road.get("overlay_id", "road_dirt"))
		var road_id := String(road.get("id", ""))
		var role := String(road.get("role", ""))
		var tiles = road.get("tiles", [])
		if not (tiles is Array):
			continue
		for tile_value in tiles:
			if not (tile_value is Dictionary):
				continue
			var tile := Vector2i(int(tile_value.get("x", -1)), int(tile_value.get("y", -1)))
			if tile.x < 0 or tile.y < 0 or tile.x >= _map_size.x or tile.y >= _map_size.y:
				continue
			_road_tiles[_tile_key(tile)] = {
				"overlay_id": overlay_id,
				"road_id": road_id,
				"role": role,
			}

func _road_tile_payload(tile: Vector2i) -> Dictionary:
	return _road_tiles.get(_tile_key(tile), {})

func _load_overworld_art_manifest() -> void:
	_overworld_art_manifest.clear()
	_object_asset_paths.clear()
	_object_textures.clear()
	_object_texture_missing.clear()
	_resource_site_asset_ids.clear()
	_resource_site_object_profiles.clear()
	_artifact_default_asset_id = ""
	_load_map_object_profiles()

	if not FileAccess.file_exists(OVERWORLD_ART_MANIFEST_PATH):
		push_warning("Overworld art manifest is missing; procedural overworld markers remain active.")
		return
	var file := FileAccess.open(OVERWORLD_ART_MANIFEST_PATH, FileAccess.READ)
	if file == null:
		push_warning("Unable to read overworld art manifest; procedural overworld markers remain active.")
		return
	var parser := JSON.new()
	var error := parser.parse(file.get_as_text())
	if error != OK or not (parser.data is Dictionary):
		push_warning("Invalid overworld art manifest; procedural overworld markers remain active.")
		return
	_overworld_art_manifest = parser.data

	var object_assets = _overworld_art_manifest.get("object_assets", {})
	if object_assets is Dictionary:
		for asset_id_value in object_assets.keys():
			var entry = object_assets.get(asset_id_value, {})
			if not (entry is Dictionary):
				continue
			var asset_id := String(asset_id_value)
			var texture_path := String(entry.get("path", ""))
			if asset_id == "" or texture_path == "":
				continue
			_object_asset_paths[asset_id] = texture_path

	var resource_site_sprites = _overworld_art_manifest.get("resource_site_sprites", {})
	if resource_site_sprites is Dictionary:
		for site_id_value in resource_site_sprites.keys():
			var entry = resource_site_sprites.get(site_id_value, {})
			if not (entry is Dictionary):
				continue
			var site_id := String(site_id_value)
			var asset_id := String(entry.get("asset_id", ""))
			if site_id != "" and asset_id != "":
				_resource_site_asset_ids[site_id] = asset_id

	var artifact_default = _overworld_art_manifest.get("artifact_default_sprite", {})
	if artifact_default is Dictionary:
		_artifact_default_asset_id = String(artifact_default.get("asset_id", ""))

func _load_map_object_profiles() -> void:
	_resource_site_object_profiles.clear()
	var raw := ContentService.load_json("res://content/map_objects.json")
	var items = raw.get("items", [])
	if not (items is Array):
		return
	for object_value in items:
		if not (object_value is Dictionary):
			continue
		var site_id := String(object_value.get("resource_site_id", "")).strip_edges()
		if site_id == "":
			continue
		var footprint = object_value.get("footprint", {})
		var footprint_size := Vector2i(1, 1)
		if footprint is Dictionary:
			footprint_size = Vector2i(int(footprint.get("width", 1)), int(footprint.get("height", 1)))
		var profile := {
			"id": String(object_value.get("id", "")),
			"family": String(object_value.get("family", "pickup")),
			"footprint": _normalized_footprint(footprint_size),
			"passable": bool(object_value.get("passable", true)),
			"visitable": bool(object_value.get("visitable", true)),
			"map_roles": object_value.get("map_roles", []),
		}
		if not _resource_site_object_profiles.has(site_id):
			_resource_site_object_profiles[site_id] = profile
			continue
		var current: Dictionary = _resource_site_object_profiles.get(site_id, {})
		if _footprint_area(_object_profile_footprint(profile)) > _footprint_area(_object_profile_footprint(current)):
			_resource_site_object_profiles[site_id] = profile

func _object_texture_for_asset(asset_id: String):
	var normalized_asset_id := asset_id.strip_edges()
	if normalized_asset_id == "":
		return null
	if _object_textures.has(normalized_asset_id):
		return _object_textures.get(normalized_asset_id)
	if _object_texture_missing.has(normalized_asset_id):
		return null
	var texture_path := String(_object_asset_paths.get(normalized_asset_id, ""))
	if texture_path == "":
		_object_texture_missing[normalized_asset_id] = texture_path
		return null
	var texture = _texture_from_path(texture_path)
	if texture is Texture2D:
		_object_textures[normalized_asset_id] = texture
		return texture
	_object_texture_missing[normalized_asset_id] = texture_path
	return null

func _texture_from_path(texture_path: String):
	if texture_path == "":
		return null
	if ResourceLoader.exists(texture_path):
		var resource = load(texture_path)
		if resource is Texture2D:
			return resource
	if FileAccess.file_exists(texture_path):
		var image := Image.new()
		if image.load(texture_path) == OK:
			return ImageTexture.create_from_image(image)
	return null

func _resource_object_profile(node: Dictionary) -> Dictionary:
	if node.is_empty():
		return _default_object_profile("pickup", Vector2i(1, 1))
	var site_id := String(node.get("site_id", "")).strip_edges()
	var profile = _resource_site_object_profiles.get(site_id, {})
	if profile is Dictionary and not profile.is_empty():
		return profile
	var site := ContentService.get_resource_site(site_id)
	var family := String(site.get("family", "pickup"))
	if family == "":
		family = "pickup"
	return _default_object_profile(family, Vector2i(1, 1))

func _artifact_object_profile() -> Dictionary:
	return _default_object_profile("artifact", Vector2i(1, 1))

func _town_object_profile() -> Dictionary:
	return _default_object_profile("town", Vector2i(2, 2))

func _encounter_object_profile() -> Dictionary:
	return _default_object_profile("encounter", Vector2i(1, 1))

func _hero_object_profile() -> Dictionary:
	return _default_object_profile("hero", Vector2i(1, 1))

func _default_object_profile(family: String, footprint: Vector2i) -> Dictionary:
	return {
		"id": "",
		"family": family,
		"footprint": _normalized_footprint(footprint),
		"passable": true,
		"visitable": true,
		"map_roles": [],
	}

func _dominant_object_profile(tile: Vector2i, object_kinds: Array, has_visible_hero: bool) -> Dictionary:
	var chosen := {}
	for kind_value in object_kinds:
		var profile := _profile_for_kind(tile, String(kind_value))
		if profile.is_empty():
			continue
		if chosen.is_empty() or _footprint_area(_object_profile_footprint(profile)) > _footprint_area(_object_profile_footprint(chosen)):
			chosen = profile
	if has_visible_hero and chosen.is_empty():
		chosen = _hero_object_profile()
	return chosen

func _profile_for_kind(tile: Vector2i, kind: String) -> Dictionary:
	match kind:
		"town":
			return _town_object_profile()
		"resource":
			return _resource_object_profile(_resource_node_at(tile))
		"artifact":
			return _artifact_object_profile()
		"encounter":
			return _encounter_object_profile()
		"hero":
			return _hero_object_profile()
		_:
			return {}

func _footprint_area(footprint: Vector2i) -> int:
	return maxi(footprint.x, 1) * maxi(footprint.y, 1)

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
	return not _resource_node_at(tile).is_empty()

func _resource_node_at(tile: Vector2i) -> Dictionary:
	for node in _session.overworld.get("resource_nodes", []):
		if not (node is Dictionary):
			continue
		if int(node.get("x", -1)) != tile.x or int(node.get("y", -1)) != tile.y:
			continue
		var site = ContentService.get_resource_site(String(node.get("site_id", "")))
		if bool(site.get("persistent_control", false)) or not bool(node.get("collected", false)):
			return node
	return {}

func _resource_asset_id(node: Dictionary) -> String:
	if node.is_empty():
		return ""
	var site_id := String(node.get("site_id", ""))
	var site := ContentService.get_resource_site(site_id)
	var direct_asset_id := String(site.get("overworld_sprite_asset_id", ""))
	if direct_asset_id != "":
		return direct_asset_id
	return String(_resource_site_asset_ids.get(site_id, ""))

func _has_artifact_at(tile: Vector2i) -> bool:
	return not _artifact_node_at(tile).is_empty()

func _artifact_node_at(tile: Vector2i) -> Dictionary:
	for node in _session.overworld.get("artifact_nodes", []):
		if node is Dictionary and not bool(node.get("collected", false)) and int(node.get("x", -1)) == tile.x and int(node.get("y", -1)) == tile.y:
			return node
	return {}

func _has_encounter_at(tile: Vector2i) -> bool:
	for encounter in _session.overworld.get("encounters", []):
		if not (encounter is Dictionary):
			continue
		if int(encounter.get("x", -1)) != tile.x or int(encounter.get("y", -1)) != tile.y:
			continue
		if not OverworldRulesScript.is_encounter_resolved(_session, encounter):
			return true
	return false

func _has_rememberable_encounter_at(tile: Vector2i) -> bool:
	for encounter in _session.overworld.get("encounters", []):
		if not (encounter is Dictionary):
			continue
		if String(encounter.get("spawned_by_faction_id", "")) != "":
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
