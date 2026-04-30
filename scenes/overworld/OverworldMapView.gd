extends Control

signal tile_pressed(tile: Vector2i)
signal tile_hovered(tile: Vector2i)

const HeroCommandRulesScript = preload("res://scripts/core/HeroCommandRules.gd")
const OverworldRulesScript = preload("res://scripts/core/OverworldRules.gd")
const TerrainPlacementRulesScript = preload("res://scripts/core/TerrainPlacementRules.gd")

const OVERWORLD_ART_MANIFEST_PATH := "res://art/overworld/manifest.json"
const TERRAIN_GRAMMAR_PATH := "res://content/terrain_grammar.json"
const MAP_PADDING := 22.0
const TACTICAL_VISIBLE_TILE_SPAN := 16.0
const TACTICAL_VISIBLE_TILE_AREA := TACTICAL_VISIBLE_TILE_SPAN * TACTICAL_VISIBLE_TILE_SPAN
const MIN_TILE_EXTENT := 24.0
const UNEXPLORED_GRID_COLOR := Color(0.08, 0.10, 0.12, 0.34)
const EXPLORED_TERRAIN_GRID_ALPHA := 0.0
const EXPLORED_TERRAIN_GRID_MODE := "fog_boundary_only"
const EXPLORED_TERRAIN_FOG_BOUNDARY_COLOR := Color(0.08, 0.10, 0.12, 0.24)
const EXPLORED_TERRAIN_FOG_BOUNDARY_WIDTH := 1.0
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
const OBJECT_SPRITE_SETTLEMENT_MODEL := "mapped_sprite_contact_grounding_no_support_stack"
const OBJECT_MAPPED_SPRITE_GROUNDING_MODEL := "localized_sprite_contact_scuffs"
const OBJECT_MAPPED_SPRITE_ANCHOR_STYLE := "mapped_sprite_local_contact_scuffs"
const OBJECT_MAPPED_SPRITE_OCCLUSION_MODEL := "sprite_contact_without_foreground_lip"
const OBJECT_MAPPED_SPRITE_DEPTH_CUE_MODEL := "localized_sprite_contact_shadow_without_backdrop"
const OBJECT_MAPPED_SPRITE_CONTACT_MODEL := "localized_sprite_contact_shadow"
const OBJECT_MAPPED_SPRITE_DISTURBANCE_MODEL := "thin_sprite_contact_disturbance"
const OBJECT_PROCEDURAL_FALLBACK_MODEL := "family_specific_procedural_world_object"
const OBJECT_PROCEDURAL_GROUNDING_MODEL := "family_specific_contact_scuffs_no_marker_plate"
const OBJECT_PROCEDURAL_ANCHOR_STYLE := "family_terrain_contact_scuffs"
const OBJECT_PROCEDURAL_OCCLUSION_MODEL := "ground_contact_without_foreground_lip"
const OBJECT_PROCEDURAL_DEPTH_CUE_MODEL := "localized_contact_shadow_without_backdrop"
const OBJECT_PROCEDURAL_CONTACT_MODEL := "localized_object_contact_shadow"
const OBJECT_PROCEDURAL_DISTURBANCE_MODEL := "thin_terrain_contact_disturbance"
const MARKER_GROUND_ANCHOR_STYLE := "terrain_ellipse_footprint"
const HERO_PRESENCE_MODEL := "placed_world_hero_figure"
const HERO_GROUNDING_MODEL := "hero_foot_contact_without_base_ellipse"
const HERO_ANCHOR_STYLE := "hero_foot_contact_shadow"
const HERO_DEPTH_CUE_MODEL := "hero_foot_contact_shadow_with_boot_occlusion"
const TOWN_PRESENTATION_MODEL := "town_3x2_footprint_bottom_middle_entry"
const TOWN_GROUNDING_MODEL := "town_sprite_settled_without_base_ellipse"
const TOWN_ANCHOR_STYLE := "town_contact_cues_no_base_ellipse"
const TOWN_DEPTH_CUE_MODEL := "town_contact_line_without_cast_shadow"
const TOWN_FOOTPRINT_CUE_MODEL := "no_visible_helper_cues_3x2_contract"
const TOWN_ENTRY_ROLE := "bottom_middle_visit_approach"
const TOWN_NON_ENTRY_ROLE := "blocked_non_entry_footprint"
const TOWN_PRESENTATION_FOOTPRINT := Vector2i(3, 2)
const TOWN_ENTRY_OFFSET := Vector2i(1, 1)
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
const OBJECT_PROCEDURAL_CONTACT_SHADOW_VISIBLE := Color(0.016, 0.013, 0.009, 0.27)
const OBJECT_PROCEDURAL_CONTACT_SHADOW_MEMORY := Color(0.20, 0.36, 0.38, 0.30)
const OBJECT_PROCEDURAL_DISTURBANCE_VISIBLE_ALPHA := 0.18
const OBJECT_PROCEDURAL_DISTURBANCE_MEMORY_ALPHA := 0.22
const OBJECT_MAPPED_SPRITE_CONTACT_SHADOW_VISIBLE := Color(0.016, 0.013, 0.009, 0.25)
const OBJECT_MAPPED_SPRITE_CONTACT_SHADOW_MEMORY := Color(0.20, 0.36, 0.38, 0.28)
const OBJECT_MAPPED_SPRITE_DISTURBANCE_VISIBLE_ALPHA := 0.14
const OBJECT_MAPPED_SPRITE_DISTURBANCE_MEMORY_ALPHA := 0.18
const HERO_CONTACT_SHADOW_VISIBLE := Color(0.018, 0.014, 0.010, 0.34)
const HERO_BOOT_OCCLUSION_VISIBLE := Color(0.18, 0.115, 0.045, 0.38)
const HERO_GROUND_HIGHLIGHT_VISIBLE := Color(0.78, 0.66, 0.34, 0.20)
const TERRAIN_GRAMMAR_RENDERING_MODE := "authored_autotile_layers"
const TERRAIN_ORIGINAL_TILE_BANK_RENDERING_MODE := "original_quiet_tile_bank"
const TERRAIN_HOMM3_LOCAL_PROTOTYPE_RENDERING_MODE := "homm3_local_reference_prototype"
const TERRAIN_TILE_ART_RENDERING_MODE := TERRAIN_HOMM3_LOCAL_PROTOTYPE_RENDERING_MODE
const TERRAIN_DEPRECATED_GENERATED_SOURCE_BASIS := "generated_overworld_terrain_sources_20260419"
const TERRAIN_TRANSITION_SELECTION_MODEL := "accepted_web_prototype_relation_class_row_lookup"
const TERRAIN_TRANSITION_EDGE_MODEL := "bridge_or_shoreline_atlas_frame_lookup"
const TERRAIN_TRANSITION_CORNER_MODEL := "diagonal_context_in_atlas_lookup"
const TERRAIN_HOMM3_SOURCE_BASIS := "homm3_extracted_local_reference_prototype"
const TERRAIN_HOMM3_UNSUPPORTED_POLICY := "explicit_grammar_fallback"
const TERRAIN_HOMM3_INTERIOR_SELECTION_MODEL := "accepted_web_full_row_bucket_selection"
const TERRAIN_EDITOR_RESTAMP_MODEL := "source_paint_known_receiver_offsets_shared_overworld_reprojection.v1"
const TERRAIN_EDITOR_RESTAMP_SCOPE := "map_editor_terrain_paint_update_and_shared_preview"
const TERRAIN_TRANSITION_ALPHA := 0.42
const TERRAIN_TRANSITION_WIDTH_FACTOR := 0.16
const TERRAIN_TRANSITION_CORNER_ALPHA := 0.34
const TERRAIN_TRANSITION_CORNER_FACTOR := 0.24
const ROAD_DEFAULT_COLOR := Color(0.72, 0.58, 0.34, 0.92)
const ROAD_DEFAULT_EDGE_COLOR := Color(0.35, 0.24, 0.15, 0.78)
const ROAD_DEFAULT_SHADOW_COLOR := Color(0.07, 0.05, 0.035, 0.58)
const ROAD_DEFAULT_CENTER_COLOR := Color(0.86, 0.74, 0.48, 0.55)
const ROAD_DEFAULT_WIDTH_FACTOR := 0.14
const ROAD_LANE_MODEL := "homm3_orthogonal_overlay_mask"
const ROAD_PIECE_SELECTION_MODEL := "homm3_4_neighbor_mask_lookup"
const ROAD_VERTICAL_LANE := "orthogonal_mask_frame"
const ROAD_HORIZONTAL_LANE := "orthogonal_mask_frame"
const ROAD_HORIZONTAL_EDGE_Y_FACTOR := 0.50
const ROAD_CONNECTION_SOURCE := "orthogonal_same_type_road_tiles"
const ROAD_CARDINAL_DIRECTIONS := [
	Vector2i.LEFT,
	Vector2i.RIGHT,
	Vector2i.UP,
	Vector2i.DOWN,
]
const TOWN_MARKER_BODY_WIDTH := 0.64
const TOWN_MARKER_BODY_HEIGHT := 0.34
const RESOURCE_MARKER_RADIUS := 0.17
const ARTIFACT_MARKER_OUTER_RADIUS := 0.18
const ARTIFACT_MARKER_INNER_RADIUS := 0.07
const ENCOUNTER_MARKER_EXTENT := 0.21
const HERO_MARKER_RADIUS := 0.20
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
const CACHE_SIGNATURE_SEED := 2166136261
const CACHE_SIGNATURE_MASK := 0x7fffffff

@export var large_map_visible_tile_span_override := 0.0

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
var _terrain_art_transformed_textures: Dictionary = {}
var _terrain_art_missing: Dictionary = {}
var _road_overlay_art: Dictionary = {}
var _homm3_prototype: Dictionary = {}
var _homm3_terrain_id_map: Dictionary = {}
var _homm3_terrain_families: Dictionary = {}
var _homm3_bridge_classes: Dictionary = {}
var _homm3_bridge_material_resolver: Dictionary = {}
var _homm3_land_receiver_stamp_lookup: Dictionary = {}
var _homm3_direct_bridge_pairs: Dictionary = {}
var _homm3_routed_bridge_rules: Dictionary = {}
var _homm3_road_overlays: Dictionary = {}
var _overworld_art_manifest: Dictionary = {}
var _object_asset_paths: Dictionary = {}
var _object_textures: Dictionary = {}
var _object_texture_missing: Dictionary = {}
var _resource_site_asset_ids: Dictionary = {}
var _resource_site_object_profiles: Dictionary = {}
var _artifact_default_asset_id := ""
var _town_default_asset_id := ""
var _encounter_default_asset_id := ""
var _session_static_layer: Control = null
var _state_layer: Control = null
var _dynamic_layer: Control = null
var _frame_layer: Control = null
var _draw_canvas_item: CanvasItem = null
var _session_static_cache_signature := 0
var _state_cache_signature := 0
var _session_static_cache_generation := 0
var _state_cache_generation := 0
var _dynamic_layer_generation := 0
var _frame_layer_generation := 0
var _session_static_cache_reason := "uninitialized"
var _state_cache_reason := "uninitialized"
var _dynamic_layer_reason := "uninitialized"
var _frame_layer_reason := "uninitialized"
var _object_index_signature := 0
var _hero_index_signature := 0
var _road_index_signature := 0
var _validation_force_index_rebuild := false
var _path_detail_profile_enabled := false
var _validation_profile: Dictionary = {}
var _towns_by_tile: Dictionary = {}
var _town_footprints_by_tile: Dictionary = {}
var _resources_by_tile: Dictionary = {}
var _artifacts_by_tile: Dictionary = {}
var _encounters_by_tile: Dictionary = {}
var _rememberable_encounters_by_tile: Dictionary = {}
var _heroes_by_tile: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	clip_contents = true
	custom_minimum_size = Vector2(640, 400)
	_ensure_render_layers()
	_load_terrain_grammar()
	_load_overworld_art_manifest()
	_invalidate_frame_layer("ready")

func set_map_state(session, map_data: Array, map_size: Vector2i, selected_tile: Vector2i) -> void:
	var profile_start := _profile_begin("set_map_state")
	_ensure_render_layers()
	var previous_viewport_layout := _viewport_layout_signature()
	var previous_board_layout := _board_layout_signature()
	var previous_session_static_signature := _session_static_cache_signature
	var previous_state_signature := _state_cache_signature
	var previous_session_present := _session != null
	_session = session
	_map_data = map_data
	_map_size = Vector2i(max(map_size.x, 1), max(map_size.y, 1))
	_hero_tile = OverworldRulesScript.hero_position(session) if session != null else Vector2i.ZERO
	_movement_left = int(session.overworld.get("movement", {}).get("current", 0)) if session != null else 0
	_terrain_layers = session.overworld.get("terrain_layers", {}) if session != null and session.overworld.get("terrain_layers", {}) is Dictionary else {}
	_rebuild_object_indexes()
	_rebuild_road_tiles()
	_selected_tile = selected_tile
	var path_profile_start := _profile_begin("path_recompute")
	_path_tiles = _build_path(_hero_tile, _selected_tile)
	var path_profile_details: Dictionary = _validation_profile.get("last_path_recompute", {}) if _validation_profile.get("last_path_recompute", {}) is Dictionary else {}
	path_profile_details["path_tiles"] = _path_tiles.size()
	_profile_end("path_recompute", path_profile_start, path_profile_details)
	_ensure_camera_state()
	var current_viewport_layout := _viewport_layout_signature()
	var current_board_layout := _board_layout_signature()
	var session_static_signature := _session_static_signature_for(_map_data, _terrain_layers)
	var state_signature := _state_cache_signature_for(_session)
	var session_present := _session != null
	var visibility_changed := previous_session_present != session_present
	var viewport_layout_changed := previous_viewport_layout != current_viewport_layout
	var board_layout_changed := previous_board_layout != current_board_layout
	var session_static_changed := session_static_signature != previous_session_static_signature
	var state_changed := state_signature != previous_state_signature
	_session_static_cache_signature = session_static_signature
	_state_cache_signature = state_signature

	if visibility_changed or viewport_layout_changed:
		_invalidate_frame_layer("viewport_layout_changed")

	if visibility_changed or board_layout_changed or session_static_changed:
		var session_static_reason := "session_static_content_changed"
		if visibility_changed:
			session_static_reason = "session_visibility_changed"
		elif board_layout_changed:
			session_static_reason = "board_layout_changed"
		_invalidate_session_static_cache(session_static_reason)

	if visibility_changed or board_layout_changed or state_changed or session_static_changed:
		var state_reason := "state_content_changed"
		if visibility_changed:
			state_reason = "session_visibility_changed"
		elif board_layout_changed:
			state_reason = "board_layout_changed"
		elif session_static_changed:
			state_reason = "session_static_dependency_changed"
		_invalidate_state_cache(state_reason)

	_invalidate_dynamic_layer("map_state_updated")
	_profile_end("set_map_state", profile_start)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_invalidate_frame_layer("resized")
		_invalidate_session_static_cache("resized")
		_invalidate_state_cache("resized")
		_invalidate_dynamic_layer("resized")
	elif what == NOTIFICATION_MOUSE_EXIT:
		_dragging_camera = false
		if _hover_tile.x >= 0:
			_hover_tile = Vector2i(-1, -1)
			tile_hovered.emit(_hover_tile)
			_invalidate_dynamic_layer("hover_changed")

func _ensure_render_layers() -> void:
	if _session_static_layer != null and is_instance_valid(_session_static_layer):
		return
	_session_static_layer = _create_render_layer("SessionStaticLayer", Callable(self, "_draw_session_static_layer"))
	_state_layer = _create_render_layer("StateLayer", Callable(self, "_draw_state_layer"))
	_dynamic_layer = _create_render_layer("DynamicLayer", Callable(self, "_draw_dynamic_layer"))
	_frame_layer = _create_render_layer("FrameLayer", Callable(self, "_draw_frame_layer"))

func _create_render_layer(layer_name: String, draw_callback: Callable) -> Control:
	var layer := Control.new()
	layer.name = layer_name
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.focus_mode = Control.FOCUS_NONE
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.draw.connect(draw_callback)
	add_child(layer)
	return layer

func _viewport_layout_signature() -> String:
	return "%s|%s|%s|%s|%s" % [
		var_to_str(size),
		_map_size.x,
		_map_size.y,
		large_map_visible_tile_span_override,
		_active_visible_tile_span(),
	]

func _board_layout_signature() -> String:
	var board_rect := _board_rect()
	var viewport_rect := _map_viewport_rect()
	var visible_bounds := _visible_tile_bounds(board_rect, viewport_rect)
	return "%s|%s|%s" % [
		_viewport_layout_signature(),
		var_to_str(board_rect),
		var_to_str(visible_bounds),
	]

func _session_static_signature_for(map_data: Array, terrain_layers: Dictionary) -> int:
	var roads = terrain_layers.get("roads", []) if terrain_layers is Dictionary else []
	var signature := _combine_cache_signature(CACHE_SIGNATURE_SEED, _map_size.x)
	signature = _combine_cache_signature(signature, _map_size.y)
	signature = _combine_cache_signature(signature, hash(str(_session.scenario_id) if _session != null else ""))
	if _session != null:
		var materialization = _session.flags.get("generated_random_map_materialization", {})
		if materialization is Dictionary:
			signature = _combine_cache_signature(signature, hash(str(materialization.get("materialized_map_signature", ""))))
	if not map_data.is_empty():
		signature = _combine_cache_signature(signature, hash(var_to_str(map_data[0])))
		var last_row = map_data[map_data.size() - 1]
		signature = _combine_cache_signature(signature, hash(var_to_str(last_row)))
	return _combine_cache_signature(signature, _roads_cache_signature(roads))

func _state_cache_signature_for(session) -> int:
	if session == null:
		return 0
	var overworld = session.overworld
	var signature := _combine_cache_signature(CACHE_SIGNATURE_SEED, _fog_cache_signature(overworld.get("fog", {})))
	signature = _combine_cache_signature(signature, _placement_array_cache_signature(overworld.get("towns", []), ["owner", "placement_id", "town_id"]))
	signature = _combine_cache_signature(signature, _placement_array_cache_signature(overworld.get("resource_nodes", []), ["site_id", "placement_id", "collected", "collected_by_faction_id"]))
	signature = _combine_cache_signature(signature, _placement_array_cache_signature(overworld.get("artifact_nodes", []), ["artifact_id", "placement_id", "collected"]))
	signature = _combine_cache_signature(signature, _placement_array_cache_signature(overworld.get("encounters", []), ["encounter_id", "placement_id", "spawned_by_faction_id"]))
	signature = _combine_cache_signature(signature, _placement_array_cache_signature(overworld.get("resolved_encounters", []), ["placement_id", "encounter_id", "id"]))
	return _combine_cache_signature(signature, _placement_array_cache_signature(HeroCommandRulesScript.hero_positions(session), ["hero_id", "is_active"]))

func _combine_cache_signature(signature: int, value: int) -> int:
	return int(((signature * 16777619) + value + 1013904223) & CACHE_SIGNATURE_MASK)

func _roads_cache_signature(roads) -> int:
	if not (roads is Array):
		return hash(typeof(roads))
	var signature := _combine_cache_signature(CACHE_SIGNATURE_SEED, roads.size())
	for road_value in roads:
		if not (road_value is Dictionary):
			signature = _combine_cache_signature(signature, hash(var_to_str(road_value)))
			continue
		var road: Dictionary = road_value
		signature = _combine_cache_signature(signature, hash(str(road.get("id", ""))))
		signature = _combine_cache_signature(signature, hash(str(road.get("overlay_id", ""))))
		signature = _combine_cache_signature(signature, hash(str(road.get("role", ""))))
		var tiles = road.get("tiles", [])
		if not (tiles is Array):
			signature = _combine_cache_signature(signature, hash(typeof(tiles)))
			continue
		signature = _combine_cache_signature(signature, tiles.size())
		for tile_value in tiles:
			if tile_value is Dictionary:
				signature = _combine_cache_signature(signature, int(tile_value.get("x", -1)))
				signature = _combine_cache_signature(signature, int(tile_value.get("y", -1)))
			else:
				signature = _combine_cache_signature(signature, hash(var_to_str(tile_value)))
	return signature

func _fog_cache_signature(fog) -> int:
	if not (fog is Dictionary):
		return hash(typeof(fog))
	var signature := CACHE_SIGNATURE_SEED
	signature = _combine_cache_signature(signature, int(fog.get("visible_count", 0)))
	signature = _combine_cache_signature(signature, int(fog.get("explored_count", 0)))
	signature = _combine_cache_signature(signature, int(fog.get("total_tiles", 0)))
	signature = _combine_cache_signature(signature, _bool_grid_cache_signature(fog.get("visible_tiles", [])))
	return _combine_cache_signature(signature, _bool_grid_cache_signature(fog.get("explored_tiles", [])))

func _bool_grid_cache_signature(grid) -> int:
	if not (grid is Array):
		return hash(typeof(grid))
	var signature := _combine_cache_signature(CACHE_SIGNATURE_SEED, grid.size())
	for row in grid:
		if not (row is Array):
			signature = _combine_cache_signature(signature, hash(typeof(row)))
			continue
		signature = _combine_cache_signature(signature, row.size())
		var packed_bits := 0
		var bit_index := 0
		for value in row:
			if bool(value):
				packed_bits |= 1 << bit_index
			bit_index += 1
			if bit_index >= 16:
				signature = _combine_cache_signature(signature, packed_bits)
				packed_bits = 0
				bit_index = 0
		if bit_index > 0:
			signature = _combine_cache_signature(signature, packed_bits)
	return signature

func _variant_array_cache_signature(values) -> int:
	if not (values is Array):
		return hash(typeof(values))
	var signature := _combine_cache_signature(CACHE_SIGNATURE_SEED, values.size())
	for value in values:
		signature = _combine_cache_signature(signature, hash(var_to_str(value)))
	return signature

func _placement_array_cache_signature(values, fields: Array) -> int:
	if not (values is Array):
		return hash(typeof(values))
	var signature := _combine_cache_signature(CACHE_SIGNATURE_SEED, values.size())
	for value in values:
		if not (value is Dictionary):
			signature = _combine_cache_signature(signature, hash(typeof(value)))
			continue
		var entry: Dictionary = value
		var position = entry.get("position", {})
		var fallback_x = position.get("x", -1) if position is Dictionary else -1
		var fallback_y = position.get("y", -1) if position is Dictionary else -1
		signature = _combine_cache_signature(signature, int(entry.get("x", fallback_x)))
		signature = _combine_cache_signature(signature, int(entry.get("y", fallback_y)))
		for field in fields:
			signature = _combine_cache_signature(signature, hash(str(entry.get(str(field), ""))))
	return signature

func _invalidate_session_static_cache(reason: String) -> void:
	_session_static_cache_generation += 1
	_session_static_cache_reason = reason
	if _session_static_layer != null:
		_session_static_layer.queue_redraw()

func _invalidate_state_cache(reason: String) -> void:
	_state_cache_generation += 1
	_state_cache_reason = reason
	if _state_layer != null:
		_state_layer.queue_redraw()

func _invalidate_dynamic_layer(reason: String) -> void:
	_dynamic_layer_generation += 1
	_dynamic_layer_reason = reason
	if _dynamic_layer != null:
		_dynamic_layer.queue_redraw()

func _invalidate_frame_layer(reason: String) -> void:
	_frame_layer_generation += 1
	_frame_layer_reason = reason
	if _frame_layer != null:
		_frame_layer.queue_redraw()

func _current_draw_canvas_item() -> CanvasItem:
	return _draw_canvas_item if _draw_canvas_item != null else self

func _canvas_draw_rect(rect: Rect2, color: Color, filled: bool = true, width: float = -1.0) -> void:
	_current_draw_canvas_item().draw_rect(rect, color, filled, width)

func _canvas_draw_line(from: Vector2, to: Vector2, color: Color, width: float = -1.0, antialiased: bool = false) -> void:
	_current_draw_canvas_item().draw_line(from, to, color, width, antialiased)

func _canvas_draw_circle(
	position: Vector2,
	radius: float,
	color: Color,
	filled: bool = true,
	width: float = -1.0,
	antialiased: bool = false
) -> void:
	_current_draw_canvas_item().draw_circle(position, radius, color, filled, width, antialiased)

func _canvas_draw_colored_polygon(points: PackedVector2Array, color: Color) -> void:
	_current_draw_canvas_item().draw_colored_polygon(points, color)

func _canvas_draw_polyline(points: PackedVector2Array, color: Color, width: float = -1.0, antialiased: bool = false) -> void:
	_current_draw_canvas_item().draw_polyline(points, color, width, antialiased)

func _canvas_draw_texture_rect(
	texture: Texture2D,
	rect: Rect2,
	tile: bool,
	modulate: Color = Color(1.0, 1.0, 1.0, 1.0),
	transpose: bool = false
) -> void:
	_current_draw_canvas_item().draw_texture_rect(texture, rect, tile, modulate, transpose)

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
			_invalidate_dynamic_layer("hover_changed")
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
	return

func _draw_frame_layer() -> void:
	var previous_target = _draw_canvas_item
	_draw_canvas_item = _frame_layer
	if _session == null:
		_canvas_draw_rect(Rect2(Vector2.ZERO, size), FRAME_FILL, true)
	else:
		var viewport_rect := _map_viewport_rect()
		var frame_rect = viewport_rect.grow(12.0)
		_draw_viewport_mask(viewport_rect)
		_canvas_draw_rect(frame_rect, FRAME_COLOR, false, 3.0)
	_draw_canvas_item = previous_target

func _draw_session_static_layer() -> void:
	if _session == null:
		return
	var profile_start := _profile_begin("draw_session_static")
	var terrain_draws := 0
	var road_draws := 0
	var previous_target = _draw_canvas_item
	_draw_canvas_item = _session_static_layer
	var viewport_rect := _map_viewport_rect()
	var board_rect = _board_rect()
	var frame_rect = viewport_rect.grow(12.0)
	_canvas_draw_rect(Rect2(Vector2.ZERO, size), FRAME_FILL, true)
	_canvas_draw_rect(frame_rect, Color(0.02, 0.03, 0.04, 0.85), true)
	_canvas_draw_rect(viewport_rect, FRAME_FILL, true)
	var visible_bounds := _visible_tile_bounds(board_rect, viewport_rect)
	for y in range(visible_bounds.position.y, visible_bounds.position.y + visible_bounds.size.y):
		for x in range(visible_bounds.position.x, visible_bounds.position.x + visible_bounds.size.x):
			var tile = Vector2i(x, y)
			var rect = _tile_rect(board_rect, tile)
			terrain_draws += 1
			if not _road_tile_payload(tile).is_empty():
				road_draws += 1
			_draw_tile_session_static_background(tile, rect)
	_draw_canvas_item = previous_target
	_profile_add("terrain_tile_draws", terrain_draws)
	_profile_add("road_tile_draws", road_draws)
	_profile_end("draw_session_static", profile_start, {
		"terrain_tile_draws": terrain_draws,
		"road_tile_draws": road_draws,
		"visible_bounds": _rect2i_payload(visible_bounds),
	})

func _draw_state_layer() -> void:
	if _session == null:
		return
	var profile_start := _profile_begin("draw_state")
	var tile_checks := 0
	var hidden_checks := 0
	var object_presentations := 0
	var previous_target = _draw_canvas_item
	_draw_canvas_item = _state_layer
	var viewport_rect := _map_viewport_rect()
	var board_rect = _board_rect()
	var visible_bounds := _visible_tile_bounds(board_rect, viewport_rect)
	for y in range(visible_bounds.position.y, visible_bounds.position.y + visible_bounds.size.y):
		for x in range(visible_bounds.position.x, visible_bounds.position.x + visible_bounds.size.x):
			var tile = Vector2i(x, y)
			var rect = _tile_rect(board_rect, tile)
			tile_checks += 1
			if not OverworldRulesScript.is_tile_explored(_session, tile.x, tile.y):
				hidden_checks += 1
			else:
				object_presentations += _visible_object_presentation_count(tile)
			_draw_tile_state_overlay(tile, rect)
			_draw_town_footprint_underlay(tile, rect)
			_draw_tile_state_icon(tile, rect)
	_draw_canvas_item = previous_target
	_profile_add("state_tile_checks", tile_checks)
	_profile_add("hidden_tile_checks", hidden_checks)
	_profile_add("object_presentation_checks", object_presentations)
	_profile_end("draw_state", profile_start, {
		"tile_checks": tile_checks,
		"hidden_tile_checks": hidden_checks,
		"object_presentation_checks": object_presentations,
		"visible_bounds": _rect2i_payload(visible_bounds),
	})

func _draw_dynamic_layer() -> void:
	if _session == null:
		return
	var profile_start := _profile_begin("draw_dynamic")
	var tile_checks := 0
	var previous_target = _draw_canvas_item
	_draw_canvas_item = _dynamic_layer
	var viewport_rect := _map_viewport_rect()
	var board_rect = _board_rect()
	var visible_bounds := _visible_tile_bounds(board_rect, viewport_rect)
	_draw_route(board_rect)
	for y in range(visible_bounds.position.y, visible_bounds.position.y + visible_bounds.size.y):
		for x in range(visible_bounds.position.x, visible_bounds.position.x + visible_bounds.size.x):
			var tile = Vector2i(x, y)
			var rect = _tile_rect(board_rect, tile)
			tile_checks += 1
			_draw_tile_focus(tile, rect)
			_draw_tile_dynamic_icon(tile, rect)
	_draw_canvas_item = previous_target
	_profile_add("dynamic_tile_checks", tile_checks)
	_profile_end("draw_dynamic", profile_start, {
		"tile_checks": tile_checks,
		"visible_bounds": _rect2i_payload(visible_bounds),
	})

func _draw_tile_background(tile: Vector2i, rect: Rect2) -> void:
	_draw_tile_session_static_background(tile, rect)
	_draw_tile_state_overlay(tile, rect)

func _draw_tile_session_static_background(tile: Vector2i, rect: Rect2) -> void:
	var terrain = _terrain_at(tile)
	if terrain == "":
		return
	if not _draw_terrain_tile_art(tile, rect, terrain):
		var base_color: Color = _terrain_color(terrain, "base_color", TERRAIN_COLORS.get(terrain, TERRAIN_COLORS["grass"]))
		_canvas_draw_rect(rect, base_color, true)
		_draw_authored_terrain_pattern(tile, rect, terrain, true)
	_draw_terrain_transitions(tile, rect, terrain)
	_draw_road_overlay(tile, rect)

func _draw_tile_state_overlay(tile: Vector2i, rect: Rect2) -> void:
	if not OverworldRulesScript.is_tile_explored(_session, tile.x, tile.y):
		_canvas_draw_rect(rect, UNEXPLORED_COLOR, true)
		_canvas_draw_line(rect.position + Vector2(6.0, 6.0), rect.end - Vector2(6.0, 6.0), Color(0.19, 0.20, 0.22, 0.45), 2.0)
		_canvas_draw_line(
			Vector2(rect.position.x + rect.size.x - 6.0, rect.position.y + 6.0),
			Vector2(rect.position.x + 6.0, rect.position.y + rect.size.y - 6.0),
			Color(0.19, 0.20, 0.22, 0.45),
			2.0
		)
		_canvas_draw_rect(rect, UNEXPLORED_GRID_COLOR, false, 1.0)
		return
	_draw_explored_terrain_boundary(tile, rect)

func _draw_terrain_tile_art(tile: Vector2i, rect: Rect2, terrain: String) -> bool:
	if not _terrain_art_can_be_primary(terrain):
		return false
	var entry := _terrain_base_art_entry(terrain, tile)
	var texture = _terrain_art_texture_for_entry(entry)
	if not (texture is Texture2D):
		return false
	_canvas_draw_texture_rect(texture, rect, false)
	return true

func _draw_explored_terrain_boundary(tile: Vector2i, rect: Rect2) -> void:
	if _session == null:
		return
	var checks := {
		"N": Vector2i(0, -1),
		"E": Vector2i(1, 0),
		"S": Vector2i(0, 1),
		"W": Vector2i(-1, 0),
	}
	for direction in checks.keys():
		var neighbor: Vector2i = tile + checks[direction]
		if neighbor.x < 0 or neighbor.y < 0 or neighbor.x >= _map_size.x or neighbor.y >= _map_size.y:
			continue
		if OverworldRulesScript.is_tile_explored(_session, neighbor.x, neighbor.y):
			continue
		match direction:
			"N":
				_canvas_draw_line(rect.position, Vector2(rect.end.x, rect.position.y), EXPLORED_TERRAIN_FOG_BOUNDARY_COLOR, EXPLORED_TERRAIN_FOG_BOUNDARY_WIDTH)
			"S":
				_canvas_draw_line(Vector2(rect.position.x, rect.end.y), rect.end, EXPLORED_TERRAIN_FOG_BOUNDARY_COLOR, EXPLORED_TERRAIN_FOG_BOUNDARY_WIDTH)
			"W":
				_canvas_draw_line(rect.position, Vector2(rect.position.x, rect.end.y), EXPLORED_TERRAIN_FOG_BOUNDARY_COLOR, EXPLORED_TERRAIN_FOG_BOUNDARY_WIDTH)
			"E":
				_canvas_draw_line(Vector2(rect.end.x, rect.position.y), rect.end, EXPLORED_TERRAIN_FOG_BOUNDARY_COLOR, EXPLORED_TERRAIN_FOG_BOUNDARY_WIDTH)

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
	_canvas_draw_circle(top, rect.size.x * 0.08, color)
	_canvas_draw_circle(bottom, rect.size.x * 0.06, color)

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
		_canvas_draw_colored_polygon(crown, tree_color)
		_canvas_draw_rect(Rect2(center + Vector2(-2.0, rect.size.y * 0.02), Vector2(4.0, rect.size.y * 0.12)), trunk_color, true)

func _draw_water_pattern(rect: Rect2, visible: bool) -> void:
	var wave_color = Color(0.80, 0.90, 1.0, 0.28 if visible else 0.14)
	for row in [0.34, 0.62]:
		var start = rect.position + rect.size * Vector2(0.16, row)
		var end = rect.position + rect.size * Vector2(0.84, row)
		_canvas_draw_line(start, end, wave_color, 2.0)
		_canvas_draw_line(start + Vector2(rect.size.x * 0.12, -rect.size.y * 0.08), end - Vector2(rect.size.x * 0.12, -rect.size.y * 0.08), wave_color, 2.0)

func _draw_mire_pattern(rect: Rect2, visible: bool) -> void:
	var reed_color = Color(0.62, 0.71, 0.35, 0.24 if visible else 0.12)
	for column in [0.25, 0.50, 0.72]:
		var start = rect.position + rect.size * Vector2(column, 0.68)
		_canvas_draw_line(start, start - Vector2(rect.size.x * 0.06, rect.size.y * 0.32), reed_color, 2.0)
		_canvas_draw_line(start, start + Vector2(rect.size.x * 0.06, -rect.size.y * 0.26), reed_color, 2.0)

func _draw_ridge_pattern(rect: Rect2, visible: bool) -> void:
	var ridge_color = Color(0.78, 0.73, 0.55, 0.22 if visible else 0.11)
	_canvas_draw_line(rect.position + rect.size * Vector2(0.18, 0.70), rect.position + rect.size * Vector2(0.50, 0.30), ridge_color, 2.0)
	_canvas_draw_line(rect.position + rect.size * Vector2(0.50, 0.30), rect.position + rect.size * Vector2(0.82, 0.68), ridge_color, 2.0)

func _draw_snow_pattern(rect: Rect2, visible: bool) -> void:
	var snow_color = Color(0.96, 0.98, 1.0, 0.28 if visible else 0.12)
	_canvas_draw_circle(rect.position + rect.size * Vector2(0.32, 0.36), rect.size.x * 0.045, snow_color)
	_canvas_draw_circle(rect.position + rect.size * Vector2(0.63, 0.60), rect.size.x * 0.055, snow_color)

func _draw_cracked_ground_pattern(rect: Rect2, visible: bool) -> void:
	var crack_color := Color(0.33, 0.22, 0.15, 0.25 if visible else 0.12)
	_canvas_draw_line(rect.position + rect.size * Vector2(0.18, 0.30), rect.position + rect.size * Vector2(0.42, 0.44), crack_color, 2.0)
	_canvas_draw_line(rect.position + rect.size * Vector2(0.42, 0.44), rect.position + rect.size * Vector2(0.34, 0.68), crack_color, 2.0)
	_canvas_draw_line(rect.position + rect.size * Vector2(0.62, 0.25), rect.position + rect.size * Vector2(0.78, 0.48), crack_color, 1.6)

func _draw_ash_pattern(rect: Rect2, visible: bool) -> void:
	var scar_color := Color(0.83, 0.44, 0.28, 0.20 if visible else 0.10)
	var ash_color := Color(0.20, 0.18, 0.18, 0.23 if visible else 0.11)
	_canvas_draw_line(rect.position + rect.size * Vector2(0.18, 0.62), rect.position + rect.size * Vector2(0.82, 0.42), ash_color, 2.0)
	_canvas_draw_line(rect.position + rect.size * Vector2(0.28, 0.32), rect.position + rect.size * Vector2(0.66, 0.66), scar_color, 1.8)

func _draw_stone_pattern(rect: Rect2, visible: bool) -> void:
	var facet_color := Color(0.72, 0.68, 0.82, 0.20 if visible else 0.10)
	_canvas_draw_line(rect.position + rect.size * Vector2(0.20, 0.36), rect.position + rect.size * Vector2(0.50, 0.22), facet_color, 1.8)
	_canvas_draw_line(rect.position + rect.size * Vector2(0.50, 0.22), rect.position + rect.size * Vector2(0.80, 0.44), facet_color, 1.8)
	_canvas_draw_line(rect.position + rect.size * Vector2(0.30, 0.72), rect.position + rect.size * Vector2(0.66, 0.58), facet_color, 1.6)

func _draw_tile_variant_marks(tile: Vector2i, rect: Rect2, terrain: String, visible: bool) -> void:
	var detail := _terrain_color(terrain, "detail_color", Color(0.85, 0.88, 0.62, 1.0))
	var alpha := 0.13 if visible else 0.06
	var color := Color(detail.r, detail.g, detail.b, alpha)
	var seed: int = abs((tile.x * 37) + (tile.y * 53))
	var center := rect.position + rect.size * Vector2(0.28 + (float(seed % 41) / 100.0), 0.26 + (float((seed / 7) % 43) / 100.0))
	var radius := maxf(1.6, minf(rect.size.x, rect.size.y) * (0.025 + (float(seed % 3) * 0.008)))
	_canvas_draw_circle(center, radius, color)
	if seed % 2 == 0:
		var second := rect.position + rect.size * Vector2(0.22 + (float((seed / 3) % 50) / 100.0), 0.56 + (float((seed / 11) % 28) / 100.0))
		_canvas_draw_line(second, second + Vector2(rect.size.x * 0.16, -rect.size.y * 0.04), color, 1.4)

func _draw_terrain_transitions(tile: Vector2i, rect: Rect2, terrain: String) -> void:
	if not _homm3_terrain_config(terrain).is_empty():
		return
	var transition_payload := _terrain_transition_payload(tile)
	var cardinal_sources = transition_payload.get("cardinal_sources", [])
	if cardinal_sources is Array:
		for source_value in cardinal_sources:
			if not (source_value is Dictionary):
				continue
			var source: Dictionary = source_value
			var direction := String(source.get("direction", ""))
			var source_terrain := String(source.get("source_terrain", terrain))
			if not _draw_terrain_edge_art(source_terrain, direction, rect):
				_draw_terrain_edge_fallback(source_terrain, direction, rect)
	var corner_sources = transition_payload.get("corner_sources", [])
	if corner_sources is Array:
		for source_value in corner_sources:
			if not (source_value is Dictionary):
				continue
			var source: Dictionary = source_value
			_draw_terrain_corner_hint(String(source.get("source_terrain", terrain)), String(source.get("direction", "")), rect)

func _draw_terrain_edge_fallback(source_terrain: String, direction: String, rect: Rect2) -> void:
	var edge_color := _terrain_color(source_terrain, "edge_color", Color(0.24, 0.26, 0.18, 1.0))
	var color := Color(edge_color.r, edge_color.g, edge_color.b, TERRAIN_TRANSITION_ALPHA)
	var width := maxf(3.0, minf(rect.size.x, rect.size.y) * TERRAIN_TRANSITION_WIDTH_FACTOR)
	match direction:
		"N":
			_canvas_draw_rect(Rect2(rect.position, Vector2(rect.size.x, width)), color, true)
		"S":
			_canvas_draw_rect(Rect2(Vector2(rect.position.x, rect.end.y - width), Vector2(rect.size.x, width)), color, true)
		"W":
			_canvas_draw_rect(Rect2(rect.position, Vector2(width, rect.size.y)), color, true)
		"E":
			_canvas_draw_rect(Rect2(Vector2(rect.end.x - width, rect.position.y), Vector2(width, rect.size.y)), color, true)

func _draw_terrain_corner_hint(source_terrain: String, direction: String, rect: Rect2) -> void:
	if direction == "":
		return
	var edge_color := _terrain_color(source_terrain, "edge_color", Color(0.24, 0.26, 0.18, 1.0))
	var color := Color(edge_color.r, edge_color.g, edge_color.b, TERRAIN_TRANSITION_CORNER_ALPHA)
	var detail := _terrain_color(source_terrain, "detail_color", edge_color)
	var detail_color := Color(detail.r, detail.g, detail.b, TERRAIN_TRANSITION_CORNER_ALPHA * 0.58)
	var extent := minf(rect.size.x, rect.size.y)
	var corner := maxf(4.0, extent * TERRAIN_TRANSITION_CORNER_FACTOR)
	var points := PackedVector2Array()
	var accent_start := Vector2.ZERO
	var accent_end := Vector2.ZERO
	var origin := Vector2.ZERO
	match direction:
		"NE":
			origin = Vector2(rect.end.x, rect.position.y)
			points = PackedVector2Array([origin, origin + Vector2(-corner, 0.0), origin + Vector2(0.0, corner)])
			accent_start = origin + Vector2(-corner * 0.76, corner * 0.18)
			accent_end = origin + Vector2(-corner * 0.20, corner * 0.72)
		"SE":
			origin = rect.end
			points = PackedVector2Array([origin, origin + Vector2(0.0, -corner), origin + Vector2(-corner, 0.0)])
			accent_start = origin + Vector2(-corner * 0.22, -corner * 0.72)
			accent_end = origin + Vector2(-corner * 0.78, -corner * 0.18)
		"SW":
			origin = Vector2(rect.position.x, rect.end.y)
			points = PackedVector2Array([origin, origin + Vector2(corner, 0.0), origin + Vector2(0.0, -corner)])
			accent_start = origin + Vector2(corner * 0.76, -corner * 0.18)
			accent_end = origin + Vector2(corner * 0.20, -corner * 0.72)
		"NW":
			origin = rect.position
			points = PackedVector2Array([origin, origin + Vector2(0.0, corner), origin + Vector2(corner, 0.0)])
			accent_start = origin + Vector2(corner * 0.22, corner * 0.72)
			accent_end = origin + Vector2(corner * 0.78, corner * 0.18)
		_:
			return
	_canvas_draw_colored_polygon(points, color)
	_canvas_draw_line(accent_start, accent_end, detail_color, maxf(1.0, extent * 0.014))

func _draw_terrain_edge_art(terrain: String, direction: String, rect: Rect2) -> bool:
	if not _terrain_art_can_be_primary(terrain):
		return false
	var texture_path := _terrain_edge_art_path(terrain, direction)
	var texture = _terrain_art_texture(texture_path)
	if not (texture is Texture2D):
		return false
	_canvas_draw_texture_rect(texture, rect, false)
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
	for direction in _road_neighbor_directions(tile):
		connector_count += 1
		var start := _road_connector_start(rect, direction)
		var end := _road_connector_end(rect, direction)
		_canvas_draw_line(start, end, shadow_color, width * 1.45)
		_canvas_draw_line(start, end, edge_color, width * 1.12)
		_canvas_draw_line(start, end, road_color, width)
		_canvas_draw_line(start, end, center_color, maxf(1.4, width * 0.22))
	if _road_needs_joint_cap(_road_neighbor_directions(tile)) and _road_has_horizontal_connections(_road_neighbor_directions(tile)):
		var edge_center := Vector2(center.x, _road_horizontal_lane_y(rect))
		_canvas_draw_line(center, edge_center, shadow_color, width * 1.45)
		_canvas_draw_line(center, edge_center, edge_color, width * 1.12)
		_canvas_draw_line(center, edge_center, road_color, width)
	if connector_count == 0:
		_canvas_draw_circle(center, width * 0.72, shadow_color)
		_canvas_draw_circle(center, width * 0.58, edge_color)
		_canvas_draw_circle(center, width * 0.46, road_color)

func _draw_road_overlay_art(tile: Vector2i, rect: Rect2, road: Dictionary) -> bool:
	var overlay_id := String(road.get("overlay_id", "road_dirt"))
	var homm3_path := _homm3_road_art_path(overlay_id, tile)
	if homm3_path != "":
		var homm3_texture = _terrain_art_texture(homm3_path)
		if homm3_texture is Texture2D:
			_canvas_draw_texture_rect(homm3_texture, rect, false)
			return true
	if not _road_overlay_art_can_be_primary(overlay_id):
		return false
	var art := _road_overlay_art_paths(overlay_id)
	if art.is_empty():
		return false
	var neighbor_directions := _road_neighbor_directions(tile)
	var drew_any := false
	var connection_pieces = art.get("connection_pieces", {})
	if connection_pieces is Dictionary:
		var connection_piece_texture = _terrain_art_texture(String(connection_pieces.get(_road_connection_key_from_directions(neighbor_directions), "")))
		if connection_piece_texture is Texture2D:
			_canvas_draw_texture_rect(connection_piece_texture, rect, false)
			drew_any = true
			if not _road_needs_joint_cap(neighbor_directions):
				return true
	var connectors = art.get("connectors", {})
	if connectors is Dictionary:
		for direction in neighbor_directions:
			var direction_key := _direction_key(direction)
			var connector_texture = _terrain_art_texture(String(connectors.get(direction_key, "")))
			if connector_texture is Texture2D:
				_canvas_draw_texture_rect(connector_texture, rect, false)
				drew_any = true
	if _road_needs_joint_cap(neighbor_directions):
		var center_texture = _terrain_art_texture(String(art.get("center", "")))
		if center_texture is Texture2D:
			_canvas_draw_texture_rect(center_texture, rect, false)
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
	_canvas_draw_polyline(points, line_color, 5.0)
	for point in points:
		_canvas_draw_circle(point, 4.0, line_color)

func _draw_tile_focus(tile: Vector2i, rect: Rect2) -> void:
	var extent := minf(rect.size.x, rect.size.y)
	var focus_width := maxf(3.0, extent * FOCUS_RING_WIDTH_FACTOR)
	if tile == _hero_tile:
		_canvas_draw_rect(rect.grow(-1.0), Color(0.03, 0.025, 0.015, 0.50), false, focus_width + 2.0)
		_canvas_draw_rect(rect.grow(-3.0), HERO_RING_COLOR, false, focus_width)

	if tile == _selected_tile:
		_canvas_draw_rect(rect.grow(-5.0), Color(SELECTION_COLOR.r, SELECTION_COLOR.g, SELECTION_COLOR.b, 0.10), true)
		_canvas_draw_rect(rect.grow(-5.0), SELECTION_COLOR, false, focus_width)
		_draw_selection_corners(rect, SELECTION_COLOR, focus_width)

	if tile == _hover_tile:
		_canvas_draw_rect(rect.grow(-7.0), HOVER_COLOR, false, 2.0)

func _draw_tile_icon(tile: Vector2i, rect: Rect2) -> void:
	_draw_tile_state_icon(tile, rect)
	_draw_tile_dynamic_icon(tile, rect)

func _draw_tile_state_icon(tile: Vector2i, rect: Rect2) -> void:
	if not OverworldRulesScript.is_tile_explored(_session, tile.x, tile.y):
		return
	var visible := OverworldRulesScript.is_tile_visible(_session, tile.x, tile.y)
	var remembered := not visible

	if _has_town_at(tile):
		var footprint_rect := _town_footprint_rect_for_entry(tile)
		if not _draw_town_sprite(footprint_rect, rect, remembered, tile):
			_draw_town_marker(footprint_rect, rect, _town_color(tile), remembered, tile)
	var resource_node := _resource_node_at(tile)
	if not resource_node.is_empty():
		var resource_rect := _resource_footprint_rect(resource_node, rect, tile)
		if not _draw_resource_sprite(resource_node, resource_rect, remembered, tile):
			_draw_resource_marker(resource_node, resource_rect, remembered, tile)
	var artifact_node := _artifact_node_at(tile)
	if not artifact_node.is_empty():
		if not _draw_artifact_sprite(artifact_node, rect, remembered, tile):
			_draw_artifact_marker(rect, remembered, tile)
	if _has_encounter_at(tile) and (visible or _has_rememberable_encounter_at(tile)):
		if not _draw_encounter_sprite(rect, remembered, tile):
			_draw_encounter_marker(rect, remembered, tile)

func _draw_tile_dynamic_icon(tile: Vector2i, rect: Rect2) -> void:
	if not OverworldRulesScript.is_tile_explored(_session, tile.x, tile.y):
		return
	var visible := OverworldRulesScript.is_tile_visible(_session, tile.x, tile.y)
	if visible and _has_hero_at(tile):
		_draw_hero_marker(rect, tile)

func _draw_resource_sprite(node: Dictionary, rect: Rect2, remembered: bool, tile: Vector2i) -> bool:
	return _draw_object_sprite(_resource_asset_id(node), rect, remembered, _resource_object_profile(node), tile)

func _draw_artifact_sprite(node: Dictionary, rect: Rect2, remembered: bool, tile: Vector2i) -> bool:
	if node.is_empty():
		return false
	return _draw_object_sprite(_artifact_default_asset_id, rect, remembered, _artifact_object_profile(), tile)

func _draw_town_sprite(rect: Rect2, entry_rect: Rect2, remembered: bool, tile: Vector2i) -> bool:
	var texture = _object_texture_for_asset(_town_default_asset_id)
	if not (texture is Texture2D):
		return false
	var profile := _town_object_profile()
	var footprint := _object_profile_footprint(profile)
	var anchor := _draw_town_grounding_anchor(rect, remembered, tile)
	var extent := minf(rect.size.x, rect.size.y)
	var sprite_fraction := _sprite_extent_fraction(profile, footprint)
	var sprite_extent := maxf(12.0, extent * sprite_fraction)
	var sprite_center := rect.get_center() + Vector2(0.0, -extent * _object_lift_fraction("town", footprint))
	var sprite_rect := Rect2(sprite_center - Vector2(sprite_extent, sprite_extent) * 0.5, Vector2(sprite_extent, sprite_extent))
	_canvas_draw_texture_rect(texture, sprite_rect, false, OBJECT_SPRITE_MEMORY_MODULATE if remembered else OBJECT_SPRITE_VISIBLE_MODULATE)
	_draw_town_owner_pennant(rect, _town_color(tile), remembered)
	_draw_town_front_contact(anchor, remembered)
	_draw_town_entry_approach(entry_rect, _town_color(tile), remembered)
	return true

func _draw_encounter_sprite(rect: Rect2, remembered: bool, tile: Vector2i) -> bool:
	return _draw_object_sprite(_encounter_default_asset_id, rect, remembered, _encounter_object_profile(), tile)

func _draw_object_sprite(asset_id: String, rect: Rect2, remembered: bool, profile: Dictionary, tile: Vector2i) -> bool:
	var texture = _object_texture_for_asset(asset_id)
	if not (texture is Texture2D):
		return false
	var footprint := _object_profile_footprint(profile)
	var family := String(profile.get("family", "pickup"))
	_draw_mapped_sprite_grounding_anchor(rect, tile, family, footprint, remembered)
	var extent := minf(rect.size.x, rect.size.y)
	var sprite_fraction := _sprite_extent_fraction(profile, footprint)
	var sprite_extent := maxf(12.0, extent * sprite_fraction)
	var sprite_center := rect.get_center() + Vector2(0.0, -extent * _object_lift_fraction(family, footprint))
	var sprite_rect := Rect2(sprite_center - Vector2(sprite_extent, sprite_extent) * 0.5, Vector2(sprite_extent, sprite_extent))
	_canvas_draw_texture_rect(texture, sprite_rect, false, OBJECT_SPRITE_MEMORY_MODULATE if remembered else OBJECT_SPRITE_VISIBLE_MODULATE)
	return true

func _draw_town_owner_pennant(rect: Rect2, color: Color, remembered: bool) -> void:
	var extent := minf(rect.size.x, rect.size.y)
	var pole_top := rect.position + rect.size * Vector2(0.74, 0.18)
	var pole_bottom := rect.position + rect.size * Vector2(0.74, 0.42)
	var pole_color := MEMORY_OBJECT_OUTLINE if remembered else Color(0.97, 0.94, 0.82, 0.90)
	var flag_color := _remembered_marker_color(color) if remembered else color
	var outline_color := MEMORY_OBJECT_OUTLINE if remembered else MARKER_OUTLINE_COLOR
	_canvas_draw_line(pole_bottom, pole_top, pole_color, maxf(1.6, extent * 0.024))
	var flag := PackedVector2Array([
		pole_top,
		pole_top + Vector2(extent * 0.16, extent * 0.045),
		pole_top + Vector2(extent * 0.02, extent * 0.12),
	])
	_canvas_draw_colored_polygon(flag, flag_color)
	_canvas_draw_polyline(PackedVector2Array([flag[0], flag[1], flag[2], flag[0]]), outline_color, maxf(1.0, extent * 0.014))

func _draw_town_marker(rect: Rect2, entry_rect: Rect2, color: Color, remembered: bool = false, tile: Vector2i = Vector2i(-1, -1)) -> void:
	var anchor := _draw_town_grounding_anchor(rect, remembered, tile)
	var extent := minf(rect.size.x, rect.size.y)
	var outline_width := maxf(2.2, extent * 0.036)
	var marker_color := _remembered_marker_color(color) if remembered else color
	var outline_color := MEMORY_OBJECT_OUTLINE if remembered else MARKER_OUTLINE_COLOR
	var body = Rect2(
		rect.position + rect.size * Vector2(0.18, 0.43),
		rect.size * Vector2(0.64, 0.30)
	)
	_canvas_draw_rect(body, marker_color, true)
	_canvas_draw_rect(body, outline_color, false, outline_width)
	for step in [0.19, 0.46, 0.70]:
		var battlement = Rect2(
			rect.position + rect.size * Vector2(step, 0.28),
			rect.size * Vector2(0.13, 0.18)
		)
		_canvas_draw_rect(battlement, marker_color, true)
		_canvas_draw_rect(battlement, outline_color, false, maxf(1.4, outline_width * 0.65))
	var gate := Rect2(rect.position + rect.size * Vector2(0.44, 0.56), rect.size * Vector2(0.12, 0.17))
	_canvas_draw_rect(gate, Color(0.16, 0.10, 0.06, 0.48 if remembered else 0.78), true)
	var flag_start = rect.position + rect.size * Vector2(0.70, 0.13)
	var flag_end = rect.position + rect.size * Vector2(0.70, 0.43)
	_canvas_draw_line(flag_end, flag_start, Color(0.97, 0.94, 0.82, 0.62 if remembered else 0.96), maxf(2.0, extent * 0.032))
	var flag = PackedVector2Array([
		flag_start,
		flag_start + rect.size * Vector2(0.13, 0.04),
		flag_start + rect.size * Vector2(0.00, 0.11),
	])
	_canvas_draw_colored_polygon(flag, Color(0.98, 0.90, 0.58, 0.62 if remembered else 0.98))
	_draw_town_front_contact(anchor, remembered)
	_draw_town_entry_approach(entry_rect, color, remembered)

func _draw_town_footprint_underlay(_tile: Vector2i, _rect: Rect2) -> void:
	return

func _draw_town_grounding_anchor(rect: Rect2, remembered: bool, tile: Vector2i) -> Dictionary:
	var extent := minf(rect.size.x, rect.size.y)
	var center := rect.position + rect.size * Vector2(0.50, 0.76)
	var radii := Vector2(rect.size.x * 0.30, maxf(2.0, rect.size.y * 0.055))
	_draw_town_ground_scuffs(tile, center, radii, remembered, extent)
	return {
		"center": center,
		"radii": radii,
		"extent": extent,
		"footprint": TOWN_PRESENTATION_FOOTPRINT,
	}

func _draw_town_ground_scuffs(tile: Vector2i, center: Vector2, radii: Vector2, remembered: bool, extent: float) -> void:
	if radii.x <= 0.0 or radii.y <= 0.0 or extent <= 0.0:
		return
	var terrain := _terrain_at(tile) if tile.x >= 0 and tile.y >= 0 else ""
	var detail_color: Color = _terrain_color(terrain, "detail_color", Color(0.70, 0.62, 0.38, 1.0))
	var alpha := 0.18 if not remembered else 0.14
	var scuff_color := Color(detail_color.r, detail_color.g, detail_color.b, alpha)
	var width := maxf(1.0, extent * 0.010)
	_canvas_draw_line(center + Vector2(-radii.x * 0.88, -radii.y * 0.18), center + Vector2(-radii.x * 0.46, -radii.y * 0.48), scuff_color, width)
	_canvas_draw_line(center + Vector2(-radii.x * 0.22, radii.y * 0.18), center + Vector2(radii.x * 0.20, radii.y * 0.04), scuff_color, width)
	_canvas_draw_line(center + Vector2(radii.x * 0.44, -radii.y * 0.36), center + Vector2(radii.x * 0.84, -radii.y * 0.12), scuff_color, width)

func _draw_town_front_contact(anchor: Dictionary, remembered: bool) -> void:
	if anchor.is_empty():
		return
	var center: Vector2 = anchor.get("center", Vector2.ZERO)
	var radii: Vector2 = anchor.get("radii", Vector2.ZERO)
	var extent := float(anchor.get("extent", 0.0))
	if radii.x <= 0.0 or radii.y <= 0.0 or extent <= 0.0:
		return
	var contact_color := Color(0.20, 0.14, 0.07, 0.20 if not remembered else 0.16)
	var highlight_color := Color(0.78, 0.66, 0.34, 0.12 if not remembered else 0.10)
	var left := center + Vector2(-radii.x * 0.66, radii.y * 0.24)
	var mid := center + Vector2(0.0, radii.y * 0.56)
	var right := center + Vector2(radii.x * 0.66, radii.y * 0.24)
	_canvas_draw_polyline(PackedVector2Array([left, mid, right]), contact_color, maxf(1.0, extent * 0.014))
	_canvas_draw_line(center + Vector2(-radii.x * 0.28, radii.y * 0.02), center + Vector2(radii.x * 0.26, radii.y * 0.04), highlight_color, maxf(1.0, extent * 0.010))

func _draw_town_entry_approach(_rect: Rect2, _color: Color, _remembered: bool) -> void:
	return

func _draw_resource_marker(node: Dictionary, rect: Rect2, remembered: bool = false, tile: Vector2i = Vector2i(-1, -1)) -> void:
	var profile := _resource_object_profile(node)
	var footprint := _object_profile_footprint(profile)
	var family := String(profile.get("family", "pickup"))
	var anchor := _draw_procedural_object_grounding(rect, tile, family, footprint, remembered)
	var marker_color := _procedural_resource_marker_color(family, remembered)
	var outline_color := MEMORY_OBJECT_OUTLINE if remembered else MARKER_OUTLINE_COLOR
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
	_draw_procedural_contact_marks(anchor, family, remembered)

func _draw_artifact_marker(rect: Rect2, remembered: bool = false, tile: Vector2i = Vector2i(-1, -1)) -> void:
	var footprint := Vector2i(1, 1)
	var anchor := _draw_procedural_object_grounding(rect, tile, "artifact", footprint, remembered)
	var extent := minf(rect.size.x, rect.size.y)
	var center = rect.get_center()
	var marker_color := _remembered_marker_color(ARTIFACT_COLOR) if remembered else ARTIFACT_COLOR
	var outline_color := MEMORY_OBJECT_OUTLINE if remembered else MARKER_OUTLINE_COLOR
	var pedestal = Rect2(rect.position + rect.size * Vector2(0.37, 0.56), rect.size * Vector2(0.26, 0.15))
	var lid = Rect2(rect.position + rect.size * Vector2(0.33, 0.48), rect.size * Vector2(0.34, 0.10))
	_canvas_draw_rect(pedestal, marker_color, true)
	_canvas_draw_rect(pedestal, outline_color, false, maxf(1.8, extent * 0.030))
	_canvas_draw_rect(lid, _scaled_color(marker_color, 1.18), true)
	_canvas_draw_rect(lid, outline_color, false, maxf(1.6, extent * 0.026))
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
	_canvas_draw_colored_polygon(gleam, Color(1.0, 0.90, 0.46, 0.62 if remembered else 0.95))
	_canvas_draw_polyline(PackedVector2Array([gleam[0], gleam[1], gleam[2], gleam[3], gleam[4], gleam[5], gleam[6], gleam[7], gleam[0]]), outline_color, maxf(1.6, extent * 0.026))
	_draw_procedural_contact_marks(anchor, "artifact", remembered)

func _draw_encounter_marker(rect: Rect2, remembered: bool = false, tile: Vector2i = Vector2i(-1, -1)) -> void:
	var footprint := Vector2i(1, 1)
	var anchor := _draw_procedural_object_grounding(rect, tile, "encounter", footprint, remembered)
	var extent := minf(rect.size.x, rect.size.y)
	var center = rect.get_center()
	var marker_color := _remembered_marker_color(ENCOUNTER_COLOR) if remembered else ENCOUNTER_COLOR
	var outline_color := MEMORY_OBJECT_OUTLINE if remembered else MARKER_OUTLINE_COLOR
	var tent := PackedVector2Array([
		rect.position + rect.size * Vector2(0.27, 0.66),
		rect.position + rect.size * Vector2(0.50, 0.33),
		rect.position + rect.size * Vector2(0.73, 0.66),
	])
	_canvas_draw_colored_polygon(tent, marker_color)
	_canvas_draw_polyline(PackedVector2Array([tent[0], tent[1], tent[2], tent[0]]), outline_color, maxf(2.0, extent * 0.034))
	_canvas_draw_line(center + Vector2(-extent * 0.17, extent * 0.04), center + Vector2(-extent * 0.17, -extent * 0.26), outline_color, maxf(2.0, extent * 0.030))
	_canvas_draw_line(center + Vector2(extent * 0.17, extent * 0.04), center + Vector2(extent * 0.17, -extent * 0.25), outline_color, maxf(2.0, extent * 0.030))
	_canvas_draw_colored_polygon(PackedVector2Array([
		center + Vector2(-extent * 0.17, -extent * 0.26),
		center + Vector2(-extent * 0.02, -extent * 0.21),
		center + Vector2(-extent * 0.17, -extent * 0.15),
	]), Color(0.92, 0.30, 0.24, 0.68 if remembered else 0.96))
	_canvas_draw_colored_polygon(PackedVector2Array([
		center + Vector2(extent * 0.17, -extent * 0.25),
		center + Vector2(extent * 0.32, -extent * 0.20),
		center + Vector2(extent * 0.17, -extent * 0.14),
	]), Color(0.92, 0.30, 0.24, 0.68 if remembered else 0.96))
	_draw_procedural_contact_marks(anchor, "encounter", remembered)

func _draw_hero_marker(rect: Rect2, tile: Vector2i) -> void:
	var anchor := _draw_hero_grounding_anchor(rect, tile)
	var extent := minf(rect.size.x, rect.size.y)
	var base_radius := maxf(5.0, extent * HERO_MARKER_RADIUS)
	var ground_center: Vector2 = anchor.get("center", rect.get_center())
	var figure_center := ground_center + Vector2(0.0, -extent * 0.17)
	var outline_width := maxf(2.2, extent * 0.034)
	var leg_width := maxf(2.2, extent * 0.030)
	var foot_left := ground_center + Vector2(-base_radius * 0.42, -extent * 0.015)
	var foot_right := ground_center + Vector2(base_radius * 0.42, -extent * 0.010)
	var hip_left := figure_center + Vector2(-base_radius * 0.22, base_radius * 0.48)
	var hip_right := figure_center + Vector2(base_radius * 0.22, base_radius * 0.48)
	var cloak := PackedVector2Array([
		figure_center + Vector2(-base_radius * 0.62, -base_radius * 0.30),
		figure_center + Vector2(base_radius * 0.58, -base_radius * 0.26),
		figure_center + Vector2(base_radius * 0.42, base_radius * 0.86),
		figure_center + Vector2(base_radius * 0.08, base_radius * 1.10),
		figure_center + Vector2(-base_radius * 0.50, base_radius * 0.92),
	])
	var chest := PackedVector2Array([
		figure_center + Vector2(-base_radius * 0.40, -base_radius * 0.24),
		figure_center + Vector2(base_radius * 0.36, -base_radius * 0.18),
		figure_center + Vector2(base_radius * 0.24, base_radius * 0.58),
		figure_center + Vector2(-base_radius * 0.28, base_radius * 0.62),
	])
	_canvas_draw_line(hip_left, foot_left, MARKER_OUTLINE_COLOR, leg_width + 1.4)
	_canvas_draw_line(hip_right, foot_right, MARKER_OUTLINE_COLOR, leg_width + 1.4)
	_canvas_draw_line(hip_left, foot_left, HERO_RING_COLOR, leg_width)
	_canvas_draw_line(hip_right, foot_right, HERO_RING_COLOR, leg_width)
	_canvas_draw_colored_polygon(cloak, HERO_FILL_COLOR)
	_canvas_draw_polyline(PackedVector2Array([cloak[0], cloak[1], cloak[2], cloak[3], cloak[4], cloak[0]]), MARKER_OUTLINE_COLOR, outline_width)
	_canvas_draw_colored_polygon(chest, _scaled_color(HERO_FILL_COLOR, 1.18))
	_canvas_draw_polyline(PackedVector2Array([chest[0], chest[1], chest[2], chest[3], chest[0]]), HERO_RING_COLOR, maxf(1.6, extent * 0.024))
	var head_center := figure_center + Vector2(0.0, -base_radius * 0.74)
	_canvas_draw_circle(head_center, base_radius * 0.48, MARKER_OUTLINE_COLOR)
	_canvas_draw_circle(head_center, base_radius * 0.38, _scaled_color(HERO_FILL_COLOR, 1.12))
	_canvas_draw_line(ground_center + Vector2(base_radius * 0.78, -extent * 0.02), figure_center + Vector2(base_radius * 0.78, -rect.size.y * 0.36), MARKER_OUTLINE_COLOR, maxf(3.0, extent * 0.040))
	_canvas_draw_line(ground_center + Vector2(base_radius * 0.78, -extent * 0.02), figure_center + Vector2(base_radius * 0.78, -rect.size.y * 0.36), HERO_RING_COLOR, maxf(1.9, extent * 0.026))
	var banner = PackedVector2Array([
		figure_center + Vector2(base_radius * 0.78, -rect.size.y * 0.36),
		figure_center + Vector2(base_radius * 0.78 + rect.size.x * 0.16, -rect.size.y * 0.30),
		figure_center + Vector2(base_radius * 0.78, -rect.size.y * 0.20),
	])
	_canvas_draw_colored_polygon(banner, Color(0.95, 0.73, 0.25, 0.95))
	_canvas_draw_polyline(PackedVector2Array([banner[0], banner[1], banner[2], banner[0]]), MARKER_OUTLINE_COLOR, maxf(1.4, extent * 0.020))
	_draw_hero_foreground_contact(anchor)

	var reserve_count = _reserve_hero_count(tile)
	if reserve_count <= 0:
		return
	var marker_center = rect.position + rect.size * Vector2(0.78, 0.25)
	_canvas_draw_circle(marker_center, rect.size.x * 0.10, RESERVE_HERO_COLOR)
	_canvas_draw_circle(marker_center, rect.size.x * 0.10, Color(0.07, 0.10, 0.12, 0.9), false, 2.0)
	for index in range(min(reserve_count, 3)):
		var dot_pos = marker_center + Vector2((index - 1) * 5.0, 0.0)
		_canvas_draw_circle(dot_pos, 1.8, Color(0.12, 0.14, 0.17, 1.0))

func _draw_hero_grounding_anchor(rect: Rect2, tile: Vector2i) -> Dictionary:
	var extent := minf(rect.size.x, rect.size.y)
	var center := rect.position + rect.size * Vector2(0.50, 0.72)
	var radii := Vector2(maxf(6.0, extent * 0.28), maxf(2.5, extent * 0.075))
	_draw_hero_foot_shadow(tile, center, radii, extent)
	return {
		"center": center,
		"radii": radii,
		"extent": extent,
		"footprint": Vector2i(1, 1),
	}

func _draw_hero_foot_shadow(tile: Vector2i, center: Vector2, radii: Vector2, extent: float) -> void:
	if radii.x <= 0.0 or radii.y <= 0.0 or extent <= 0.0:
		return
	var terrain := _terrain_at(tile) if tile.x >= 0 and tile.y >= 0 else ""
	var base_color: Color = _terrain_color(terrain, "base_color", TERRAIN_COLORS.get(terrain, TERRAIN_COLORS["grass"]))
	var detail_color: Color = _terrain_color(terrain, "detail_color", Color(0.70, 0.62, 0.38, 1.0))
	var ground_color := Color(
		(base_color.r * 0.62) + (detail_color.r * 0.22) + 0.05,
		(base_color.g * 0.62) + (detail_color.g * 0.22) + 0.035,
		(base_color.b * 0.62) + (detail_color.b * 0.22) + 0.018,
		0.18
	)
	_canvas_draw_colored_polygon(_placement_bed_points(tile, center + Vector2(0.0, radii.y * 0.10), Vector2(radii.x * 0.92, radii.y * 1.18), Vector2i(1, 1), 14), ground_color)
	var shadow := PackedVector2Array([
		center + Vector2(-radii.x * 0.68, -radii.y * 0.05),
		center + Vector2(-radii.x * 0.34, radii.y * 0.72),
		center + Vector2(radii.x * 0.28, radii.y * 0.88),
		center + Vector2(radii.x * 0.74, radii.y * 0.18),
		center + Vector2(radii.x * 0.34, -radii.y * 0.38),
		center + Vector2(-radii.x * 0.32, -radii.y * 0.34),
	])
	_canvas_draw_colored_polygon(shadow, HERO_CONTACT_SHADOW_VISIBLE)
	var scuff_color := Color(detail_color.r, detail_color.g, detail_color.b, 0.24)
	var width := maxf(1.0, extent * 0.012)
	_canvas_draw_line(center + Vector2(-radii.x * 0.84, radii.y * 0.24), center + Vector2(-radii.x * 0.42, radii.y * 0.46), scuff_color, width)
	_canvas_draw_line(center + Vector2(-radii.x * 0.10, radii.y * 0.60), center + Vector2(radii.x * 0.34, radii.y * 0.54), scuff_color, width)
	_canvas_draw_line(center + Vector2(radii.x * 0.42, radii.y * 0.08), center + Vector2(radii.x * 0.82, radii.y * 0.24), scuff_color, width)

func _draw_hero_foreground_contact(anchor: Dictionary) -> void:
	if anchor.is_empty():
		return
	var center: Vector2 = anchor.get("center", Vector2.ZERO)
	var radii: Vector2 = anchor.get("radii", Vector2.ZERO)
	var extent := float(anchor.get("extent", 0.0))
	if radii.x <= 0.0 or radii.y <= 0.0 or extent <= 0.0:
		return
	var pad := PackedVector2Array([
		center + Vector2(-radii.x * 0.56, radii.y * 0.10),
		center + Vector2(-radii.x * 0.26, radii.y * 0.72),
		center + Vector2(radii.x * 0.22, radii.y * 0.74),
		center + Vector2(radii.x * 0.58, radii.y * 0.14),
		center + Vector2(radii.x * 0.30, radii.y * 0.36),
		center + Vector2(-radii.x * 0.34, radii.y * 0.34),
	])
	_canvas_draw_colored_polygon(pad, HERO_BOOT_OCCLUSION_VISIBLE)
	var left := center + Vector2(-radii.x * 0.58, radii.y * 0.24)
	var mid := center + Vector2(0.0, radii.y * 0.58)
	var right := center + Vector2(radii.x * 0.58, radii.y * 0.20)
	_canvas_draw_polyline(PackedVector2Array([left, mid, right]), HERO_BOOT_OCCLUSION_VISIBLE, maxf(1.4, extent * 0.020))
	_canvas_draw_line(center + Vector2(-radii.x * 0.22, radii.y * 0.02), center + Vector2(radii.x * 0.24, radii.y * 0.02), HERO_GROUND_HIGHLIGHT_VISIBLE, maxf(1.0, extent * 0.012))

func _draw_pickup_silhouette(rect: Rect2, marker_color: Color, outline_color: Color, remembered: bool) -> void:
	var extent := minf(rect.size.x, rect.size.y)
	var base := Rect2(rect.position + rect.size * Vector2(0.34, 0.50), rect.size * Vector2(0.32, 0.20))
	var crate_left := Rect2(rect.position + rect.size * Vector2(0.25, 0.57), rect.size * Vector2(0.21, 0.15))
	var crate_right := Rect2(rect.position + rect.size * Vector2(0.54, 0.55), rect.size * Vector2(0.21, 0.16))
	for box in [base, crate_left, crate_right]:
		_canvas_draw_rect(box, marker_color, true)
		_canvas_draw_rect(box, outline_color, false, maxf(1.6, extent * 0.026))
	_canvas_draw_line(base.position + Vector2(0.0, base.size.y * 0.46), base.end - Vector2(0.0, base.size.y * 0.46), _scaled_color(outline_color, 1.0, 0.45 if remembered else 0.68), maxf(1.0, extent * 0.018))

func _draw_dwelling_silhouette(rect: Rect2, marker_color: Color, outline_color: Color, remembered: bool) -> void:
	var extent := minf(rect.size.x, rect.size.y)
	var wall := Rect2(rect.position + rect.size * Vector2(0.25, 0.48), rect.size * Vector2(0.50, 0.23))
	var roof := PackedVector2Array([
		rect.position + rect.size * Vector2(0.20, 0.50),
		rect.position + rect.size * Vector2(0.50, 0.30),
		rect.position + rect.size * Vector2(0.80, 0.50),
	])
	_canvas_draw_colored_polygon(roof, _scaled_color(marker_color, 0.82))
	_canvas_draw_polyline(PackedVector2Array([roof[0], roof[1], roof[2]]), outline_color, maxf(2.0, extent * 0.032))
	_canvas_draw_rect(wall, marker_color, true)
	_canvas_draw_rect(wall, outline_color, false, maxf(1.8, extent * 0.030))
	_canvas_draw_rect(Rect2(rect.position + rect.size * Vector2(0.47, 0.58), rect.size * Vector2(0.10, 0.13)), Color(0.13, 0.09, 0.05, 0.48 if remembered else 0.80), true)
	_canvas_draw_line(rect.position + rect.size * Vector2(0.28, 0.53), rect.position + rect.size * Vector2(0.28, 0.72), outline_color, maxf(1.4, extent * 0.022))
	_canvas_draw_line(rect.position + rect.size * Vector2(0.72, 0.53), rect.position + rect.size * Vector2(0.72, 0.72), outline_color, maxf(1.4, extent * 0.022))

func _draw_mine_silhouette(rect: Rect2, marker_color: Color, outline_color: Color, remembered: bool) -> void:
	var extent := minf(rect.size.x, rect.size.y)
	var mound := PackedVector2Array([
		rect.position + rect.size * Vector2(0.18, 0.70),
		rect.position + rect.size * Vector2(0.36, 0.42),
		rect.position + rect.size * Vector2(0.52, 0.54),
		rect.position + rect.size * Vector2(0.66, 0.35),
		rect.position + rect.size * Vector2(0.84, 0.70),
	])
	_canvas_draw_colored_polygon(mound, _scaled_color(marker_color, 0.86))
	_canvas_draw_polyline(PackedVector2Array([mound[0], mound[1], mound[2], mound[3], mound[4]]), outline_color, maxf(2.0, extent * 0.032))
	var adit := Rect2(rect.position + rect.size * Vector2(0.43, 0.55), rect.size * Vector2(0.18, 0.16))
	_canvas_draw_rect(adit, Color(0.07, 0.06, 0.045, 0.54 if remembered else 0.88), true)
	_canvas_draw_rect(adit, outline_color, false, maxf(1.4, extent * 0.024))
	_canvas_draw_line(rect.position + rect.size * Vector2(0.25, 0.65), rect.position + rect.size * Vector2(0.77, 0.65), Color(0.96, 0.88, 0.55, 0.28 if remembered else 0.44), maxf(1.2, extent * 0.018))

func _draw_tower_silhouette(rect: Rect2, marker_color: Color, outline_color: Color, remembered: bool) -> void:
	var extent := minf(rect.size.x, rect.size.y)
	var shaft := Rect2(rect.position + rect.size * Vector2(0.42, 0.30), rect.size * Vector2(0.16, 0.43))
	var cap := Rect2(rect.position + rect.size * Vector2(0.34, 0.24), rect.size * Vector2(0.32, 0.11))
	_canvas_draw_rect(shaft, marker_color, true)
	_canvas_draw_rect(shaft, outline_color, false, maxf(1.7, extent * 0.028))
	_canvas_draw_rect(cap, _scaled_color(marker_color, 1.10), true)
	_canvas_draw_rect(cap, outline_color, false, maxf(1.7, extent * 0.028))
	_canvas_draw_line(rect.position + rect.size * Vector2(0.50, 0.24), rect.position + rect.size * Vector2(0.50, 0.12), outline_color, maxf(1.6, extent * 0.024))
	_canvas_draw_colored_polygon(PackedVector2Array([
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
		_canvas_draw_rect(stone, _scaled_color(marker_color, 0.90), true)
		_canvas_draw_rect(stone, outline_color, false, maxf(1.5, extent * 0.024))
	_canvas_draw_circle(rect.position + rect.size * Vector2(0.50, 0.60), maxf(2.5, extent * 0.055), Color(1.0, 0.90, 0.50, 0.42 if remembered else 0.70))

func _draw_transit_silhouette(rect: Rect2, marker_color: Color, outline_color: Color, remembered: bool) -> void:
	var extent := minf(rect.size.x, rect.size.y)
	var left_base := rect.position + rect.size * Vector2(0.30, 0.70)
	var right_base := rect.position + rect.size * Vector2(0.70, 0.70)
	var apex := rect.position + rect.size * Vector2(0.50, 0.35)
	_canvas_draw_line(left_base, apex, outline_color, maxf(6.0, extent * 0.090))
	_canvas_draw_line(right_base, apex, outline_color, maxf(6.0, extent * 0.090))
	_canvas_draw_line(left_base, apex, marker_color, maxf(3.5, extent * 0.055))
	_canvas_draw_line(right_base, apex, marker_color, maxf(3.5, extent * 0.055))
	_canvas_draw_line(rect.position + rect.size * Vector2(0.34, 0.59), rect.position + rect.size * Vector2(0.66, 0.59), Color(0.96, 0.88, 0.55, 0.36 if remembered else 0.60), maxf(1.6, extent * 0.022))

func _draw_shrine_silhouette(rect: Rect2, marker_color: Color, outline_color: Color, remembered: bool) -> void:
	var extent := minf(rect.size.x, rect.size.y)
	var pillar := Rect2(rect.position + rect.size * Vector2(0.43, 0.38), rect.size * Vector2(0.14, 0.30))
	var cap := Rect2(rect.position + rect.size * Vector2(0.35, 0.32), rect.size * Vector2(0.30, 0.10))
	_canvas_draw_rect(pillar, marker_color, true)
	_canvas_draw_rect(pillar, outline_color, false, maxf(1.5, extent * 0.024))
	_canvas_draw_rect(cap, _scaled_color(marker_color, 1.12), true)
	_canvas_draw_rect(cap, outline_color, false, maxf(1.5, extent * 0.024))
	_canvas_draw_circle(rect.position + rect.size * Vector2(0.50, 0.25), maxf(2.6, extent * 0.055), Color(0.98, 0.94, 0.72, 0.48 if remembered else 0.78))

func _draw_procedural_object_grounding(rect: Rect2, tile: Vector2i, family: String, footprint: Vector2i, remembered: bool) -> Dictionary:
	var extent := minf(rect.size.x, rect.size.y)
	var normalized_footprint := _normalized_footprint(footprint)
	var fraction_metrics := _procedural_grounding_fraction_metrics(family, normalized_footprint)
	var center := rect.position + rect.size * Vector2(0.50, _procedural_ground_center_y_factor(family))
	var radii := Vector2(
		maxf(4.0, extent * float(fraction_metrics.get("half_width", 0.28))),
		maxf(2.0, extent * float(fraction_metrics.get("half_height", 0.06)))
	)
	_draw_procedural_ground_disturbance(tile, center, radii, family, normalized_footprint, remembered, extent)
	_draw_procedural_contact_shadow(center, radii, family, normalized_footprint, remembered, extent)
	if remembered:
		_draw_memory_echo_marks(center, minf(radii.x * 0.82, extent * 0.30), extent)
	return {
		"center": center,
		"radii": radii,
		"extent": extent,
		"footprint": normalized_footprint,
		"family": family,
	}

func _draw_mapped_sprite_grounding_anchor(rect: Rect2, tile: Vector2i, family: String, footprint: Vector2i, remembered: bool) -> Dictionary:
	var extent := minf(rect.size.x, rect.size.y)
	var normalized_footprint := _normalized_footprint(footprint)
	var fraction_metrics := _mapped_sprite_grounding_fraction_metrics(family, normalized_footprint)
	var center := rect.position + rect.size * Vector2(0.50, _mapped_sprite_ground_center_y_factor(family))
	var radii := Vector2(
		maxf(4.0, extent * float(fraction_metrics.get("half_width", 0.25))),
		maxf(2.0, extent * float(fraction_metrics.get("half_height", 0.045)))
	)
	_draw_mapped_sprite_contact_disturbance(tile, center, radii, family, normalized_footprint, remembered, extent)
	_draw_mapped_sprite_contact_shadow(center, radii, family, normalized_footprint, remembered, extent)
	if remembered:
		_draw_memory_echo_marks(center, minf(radii.x * 0.74, extent * 0.28), extent)
	return {
		"center": center,
		"radii": radii,
		"extent": extent,
		"footprint": normalized_footprint,
		"family": family,
	}

func _draw_mapped_sprite_contact_disturbance(tile: Vector2i, center: Vector2, radii: Vector2, family: String, footprint: Vector2i, remembered: bool, extent: float) -> void:
	if radii.x <= 0.0 or radii.y <= 0.0 or extent <= 0.0:
		return
	var terrain := _terrain_at(tile) if tile.x >= 0 and tile.y >= 0 else ""
	var base_color: Color = _terrain_color(terrain, "base_color", TERRAIN_COLORS.get(terrain, TERRAIN_COLORS["grass"]))
	var detail_color: Color = _terrain_color(terrain, "detail_color", Color(0.70, 0.62, 0.38, 1.0))
	var alpha := OBJECT_MAPPED_SPRITE_DISTURBANCE_MEMORY_ALPHA if remembered else OBJECT_MAPPED_SPRITE_DISTURBANCE_VISIBLE_ALPHA
	var scuff_fill := _placement_bed_color(base_color, detail_color, remembered, alpha)
	var segment_count := 12 if family in ["artifact", "pickup"] else 14
	_canvas_draw_colored_polygon(
		_placement_bed_points(tile + Vector2i(11, 17), center + Vector2(0.0, radii.y * 0.12), Vector2(radii.x * 0.78, radii.y * 0.78), footprint, segment_count),
		scuff_fill
	)
	var scuff_color := Color(detail_color.r, detail_color.g, detail_color.b, 0.22 if remembered else 0.18)
	var contact_color := Color(0.24, 0.17, 0.08, 0.20 if remembered else 0.24)
	if remembered:
		contact_color = Color(0.62, 0.82, 0.86, 0.26)
	var width := maxf(1.0, extent * 0.010)
	_canvas_draw_line(center + Vector2(-radii.x * 0.66, radii.y * 0.02), center + Vector2(-radii.x * 0.28, radii.y * 0.22), scuff_color, width)
	_canvas_draw_line(center + Vector2(-radii.x * 0.05, radii.y * 0.30), center + Vector2(radii.x * 0.32, radii.y * 0.22), scuff_color, width)
	_canvas_draw_line(center + Vector2(radii.x * 0.38, -radii.y * 0.05), center + Vector2(radii.x * 0.72, radii.y * 0.08), scuff_color, width)
	if family in ["encounter", "mine", "neutral_dwelling", "guarded_reward_site", "repeatable_service"]:
		_canvas_draw_line(center + Vector2(-radii.x * 0.48, radii.y * 0.22), center + Vector2(radii.x * 0.52, radii.y * 0.18), contact_color, maxf(1.0, extent * 0.012))

func _draw_mapped_sprite_contact_shadow(center: Vector2, radii: Vector2, family: String, footprint: Vector2i, remembered: bool, extent: float) -> void:
	if radii.x <= 0.0 or radii.y <= 0.0 or extent <= 0.0:
		return
	var footprint_width := 1.0 + (float(maxi(footprint.x - 1, 0)) * 0.06)
	var footprint_depth := 1.0 + (float(maxi(footprint.y - 1, 0)) * 0.08)
	var color := OBJECT_MAPPED_SPRITE_CONTACT_SHADOW_MEMORY if remembered else OBJECT_MAPPED_SPRITE_CONTACT_SHADOW_VISIBLE
	var points := PackedVector2Array([
		center + Vector2(-radii.x * 0.58 * footprint_width, -radii.y * 0.10),
		center + Vector2(-radii.x * 0.42 * footprint_width, radii.y * 0.54 * footprint_depth),
		center + Vector2(radii.x * 0.14 * footprint_width, radii.y * 0.72 * footprint_depth),
		center + Vector2(radii.x * 0.62 * footprint_width, radii.y * 0.18),
		center + Vector2(radii.x * 0.34 * footprint_width, -radii.y * 0.30),
		center + Vector2(-radii.x * 0.24 * footprint_width, -radii.y * 0.28),
	])
	_canvas_draw_colored_polygon(points, color)
	if family in ["scouting_structure", "transit_object", "frontier_shrine"]:
		_canvas_draw_line(center + Vector2(-radii.x * 0.30, -radii.y * 0.10), center + Vector2(radii.x * 0.30, radii.y * 0.34), Color(color.r, color.g, color.b, color.a * 0.68), maxf(1.0, extent * 0.010))

func _draw_procedural_ground_disturbance(tile: Vector2i, center: Vector2, radii: Vector2, family: String, footprint: Vector2i, remembered: bool, extent: float) -> void:
	if radii.x <= 0.0 or radii.y <= 0.0 or extent <= 0.0:
		return
	var terrain := _terrain_at(tile) if tile.x >= 0 and tile.y >= 0 else ""
	var base_color: Color = _terrain_color(terrain, "base_color", TERRAIN_COLORS.get(terrain, TERRAIN_COLORS["grass"]))
	var detail_color: Color = _terrain_color(terrain, "detail_color", Color(0.70, 0.62, 0.38, 1.0))
	var alpha := OBJECT_PROCEDURAL_DISTURBANCE_MEMORY_ALPHA if remembered else OBJECT_PROCEDURAL_DISTURBANCE_VISIBLE_ALPHA
	var bed_color := _placement_bed_color(base_color, detail_color, remembered, alpha)
	var segment_count := 14 if family in ["artifact", "pickup"] else 18
	_canvas_draw_colored_polygon(
		_placement_bed_points(tile + Vector2i(7, 11), center + Vector2(0.0, radii.y * 0.10), Vector2(radii.x * 1.04, radii.y * 1.28), footprint, segment_count),
		bed_color
	)
	var scuff_color := Color(detail_color.r, detail_color.g, detail_color.b, 0.24 if remembered else 0.20)
	var width := maxf(1.0, extent * 0.010)
	_canvas_draw_line(center + Vector2(-radii.x * 0.74, radii.y * 0.02), center + Vector2(-radii.x * 0.36, radii.y * 0.28), scuff_color, width)
	_canvas_draw_line(center + Vector2(-radii.x * 0.08, radii.y * 0.38), center + Vector2(radii.x * 0.30, radii.y * 0.32), scuff_color, width)
	_canvas_draw_line(center + Vector2(radii.x * 0.42, -radii.y * 0.10), center + Vector2(radii.x * 0.78, radii.y * 0.08), scuff_color, width)

func _draw_procedural_contact_shadow(center: Vector2, radii: Vector2, family: String, footprint: Vector2i, remembered: bool, extent: float) -> void:
	if radii.x <= 0.0 or radii.y <= 0.0 or extent <= 0.0:
		return
	var footprint_width := 1.0 + (float(maxi(footprint.x - 1, 0)) * 0.08)
	var footprint_depth := 1.0 + (float(maxi(footprint.y - 1, 0)) * 0.10)
	var color := OBJECT_PROCEDURAL_CONTACT_SHADOW_MEMORY if remembered else OBJECT_PROCEDURAL_CONTACT_SHADOW_VISIBLE
	var points := PackedVector2Array([
		center + Vector2(-radii.x * 0.64 * footprint_width, -radii.y * 0.12),
		center + Vector2(-radii.x * 0.44 * footprint_width, radii.y * 0.68 * footprint_depth),
		center + Vector2(radii.x * 0.20 * footprint_width, radii.y * 0.84 * footprint_depth),
		center + Vector2(radii.x * 0.72 * footprint_width, radii.y * 0.20),
		center + Vector2(radii.x * 0.36 * footprint_width, -radii.y * 0.36),
		center + Vector2(-radii.x * 0.28 * footprint_width, -radii.y * 0.32),
	])
	_canvas_draw_colored_polygon(points, color)
	if family in ["mine", "guarded_reward_site", "neutral_dwelling", "repeatable_service", "faction_outpost"]:
		_canvas_draw_line(center + Vector2(-radii.x * 0.58, radii.y * 0.34), center + Vector2(radii.x * 0.54, radii.y * 0.30), Color(color.r, color.g, color.b, color.a * 0.72), maxf(1.0, extent * 0.012))

func _draw_procedural_contact_marks(anchor: Dictionary, family: String, remembered: bool) -> void:
	if anchor.is_empty():
		return
	var center: Vector2 = anchor.get("center", Vector2.ZERO)
	var radii: Vector2 = anchor.get("radii", Vector2.ZERO)
	var extent := float(anchor.get("extent", 0.0))
	if radii.x <= 0.0 or radii.y <= 0.0 or extent <= 0.0:
		return
	var contact_color := Color(0.23, 0.17, 0.09, 0.28)
	var highlight_color := Color(0.76, 0.64, 0.34, 0.16)
	if remembered:
		contact_color = Color(0.64, 0.82, 0.86, 0.32)
		highlight_color = Color(0.90, 0.98, 1.0, 0.20)
	var width := maxf(1.0, extent * 0.014)
	match family:
		"artifact":
			_canvas_draw_line(center + Vector2(-radii.x * 0.52, radii.y * 0.22), center + Vector2(-radii.x * 0.10, radii.y * 0.44), contact_color, width)
			_canvas_draw_line(center + Vector2(radii.x * 0.10, radii.y * 0.44), center + Vector2(radii.x * 0.52, radii.y * 0.20), contact_color, width)
		"encounter":
			_canvas_draw_line(center + Vector2(-radii.x * 0.72, radii.y * 0.12), center + Vector2(-radii.x * 0.28, radii.y * 0.48), contact_color, width)
			_canvas_draw_line(center + Vector2(radii.x * 0.24, radii.y * 0.48), center + Vector2(radii.x * 0.74, radii.y * 0.10), contact_color, width)
			_canvas_draw_line(center + Vector2(-radii.x * 0.12, radii.y * 0.20), center + Vector2(radii.x * 0.18, radii.y * 0.20), highlight_color, maxf(1.0, extent * 0.010))
		_:
			_canvas_draw_line(center + Vector2(-radii.x * 0.64, radii.y * 0.20), center + Vector2(-radii.x * 0.20, radii.y * 0.48), contact_color, width)
			_canvas_draw_line(center + Vector2(radii.x * 0.16, radii.y * 0.50), center + Vector2(radii.x * 0.66, radii.y * 0.18), contact_color, width)
			_canvas_draw_line(center + Vector2(-radii.x * 0.22, radii.y * 0.04), center + Vector2(radii.x * 0.22, radii.y * 0.06), highlight_color, maxf(1.0, extent * 0.010))

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
	_canvas_draw_colored_polygon(
		_ellipse_points(center + shadow_offset, Vector2(radii.x * 1.10, radii.y * 1.24)),
		MARKER_SHADOW_COLOR
	)
	_canvas_draw_colored_polygon(_ellipse_points(center, radii), MARKER_PLATE_MEMORY if remembered else MARKER_PLATE_VISIBLE)
	_canvas_draw_polyline(
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
	_canvas_draw_colored_polygon(_placement_bed_points(tile, bed_center, bed_radii, footprint), bed_color)
	_canvas_draw_colored_polygon(
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
	_canvas_draw_polyline(PackedVector2Array([left, mid, right]), lip_color, maxf(1.4, extent * 0.022))
	_canvas_draw_line(center + Vector2(-radii.x * 0.38, radii.y * 0.05), center + Vector2(radii.x * 0.34, radii.y * 0.08), highlight_color, maxf(1.0, extent * 0.012))

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
	_canvas_draw_colored_polygon(points, color)
	_canvas_draw_line(
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
	_canvas_draw_colored_polygon(band, color)
	var pad_width := maxf(1.0, extent * 0.016)
	_canvas_draw_line(center + Vector2(-radii.x * 0.50, radii.y * 0.49), center + Vector2(-radii.x * 0.12, radii.y * 0.68), Color(color.r, color.g, color.b, color.a * 0.78), pad_width)
	_canvas_draw_line(center + Vector2(radii.x * 0.08, radii.y * 0.68), center + Vector2(radii.x * 0.54, radii.y * 0.49), Color(color.r, color.g, color.b, color.a * 0.78), pad_width)

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
	_canvas_draw_colored_polygon(points, wash_color)

	var mass_points := PackedVector2Array([
		center + Vector2(-top_width * 0.20, -height * 0.78),
		center + Vector2(top_width * 0.26, -height * 0.72),
		center + Vector2(width * 0.22, -height * 0.16),
		center + Vector2(width * 0.18, radii.y * 0.25),
		center + Vector2(-width * 0.20, radii.y * 0.26),
		center + Vector2(-width * 0.24, -height * 0.18),
	])
	_canvas_draw_colored_polygon(mass_points, mass_shadow_color)
	_canvas_draw_line(
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
	_canvas_draw_line(center + Vector2(-radii.x * 0.72, -radii.y * 0.08), center + Vector2(-radii.x * 0.38, -radii.y * 0.18), scuff_color, width)
	_canvas_draw_line(center + Vector2(-radii.x * 0.68, radii.y * 0.34), center + Vector2(-radii.x * 0.42, radii.y * 0.52), scuff_color, width)
	_canvas_draw_line(center + Vector2(-radii.x * 0.10, radii.y * 0.66), center + Vector2(radii.x * 0.26, radii.y * 0.62), scuff_color, width)
	_canvas_draw_line(center + Vector2(radii.x * 0.42, -radii.y * 0.12), center + Vector2(radii.x * 0.70, radii.y * 0.03), scuff_color, width)

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
	_canvas_draw_line(center + Vector2(-radii.x * 0.82, radii.y * 0.30), center + Vector2(-radii.x * 0.56, radii.y * 0.58), color, width)
	_canvas_draw_line(center + Vector2(-radii.x * 0.24, radii.y * 0.52), center + Vector2(-radii.x * 0.04, radii.y * 0.72), color, width)
	_canvas_draw_line(center + Vector2(radii.x * 0.22, radii.y * 0.52), center + Vector2(radii.x * 0.45, radii.y * 0.70), color, width)
	_canvas_draw_line(center + Vector2(radii.x * 0.62, radii.y * 0.26), center + Vector2(radii.x * 0.86, radii.y * 0.48), color, width)

func _draw_memory_echo_marks(center: Vector2, radius: float, extent: float) -> void:
	var color := Color(0.86, 0.94, 0.96, 0.76)
	var width := maxf(1.25, extent * 0.018)
	var inner := radius * 0.62
	var outer := radius * 0.92
	var tick := radius * 0.22
	_canvas_draw_line(center + Vector2(-inner, -outer), center + Vector2(-inner + tick, -outer), color, width)
	_canvas_draw_line(center + Vector2(inner, -outer), center + Vector2(inner - tick, -outer), color, width)
	_canvas_draw_line(center + Vector2(-inner, outer), center + Vector2(-inner + tick, outer), color, width)
	_canvas_draw_line(center + Vector2(inner, outer), center + Vector2(inner - tick, outer), color, width)

func _draw_selection_corners(rect: Rect2, color: Color, width: float) -> void:
	var extent := minf(rect.size.x, rect.size.y)
	var inset := maxf(4.0, extent * 0.075)
	var length := maxf(8.0, extent * 0.22)
	var top_left := rect.position + Vector2(inset, inset)
	var top_right := Vector2(rect.end.x - inset, rect.position.y + inset)
	var bottom_left := Vector2(rect.position.x + inset, rect.end.y - inset)
	var bottom_right := rect.end - Vector2(inset, inset)
	_canvas_draw_line(top_left, top_left + Vector2(length, 0.0), color, width)
	_canvas_draw_line(top_left, top_left + Vector2(0.0, length), color, width)
	_canvas_draw_line(top_right, top_right + Vector2(-length, 0.0), color, width)
	_canvas_draw_line(top_right, top_right + Vector2(0.0, length), color, width)
	_canvas_draw_line(bottom_left, bottom_left + Vector2(length, 0.0), color, width)
	_canvas_draw_line(bottom_left, bottom_left + Vector2(0.0, -length), color, width)
	_canvas_draw_line(bottom_right, bottom_right + Vector2(-length, 0.0), color, width)
	_canvas_draw_line(bottom_right, bottom_right + Vector2(0.0, -length), color, width)

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

func _object_profile_footprint_anchor(profile: Dictionary) -> String:
	var footprint = profile.get("footprint", {})
	if footprint is Dictionary:
		return String(footprint.get("anchor", profile.get("footprint_anchor", "bottom_center")))
	return String(profile.get("footprint_anchor", "bottom_center"))

func _resource_footprint_rect(node: Dictionary, anchor_rect: Rect2, anchor_tile: Vector2i) -> Rect2:
	var profile := _resource_object_profile(node)
	var footprint := _object_profile_footprint(profile)
	if footprint == Vector2i(1, 1):
		return anchor_rect
	var origin := _object_footprint_origin_for_anchor(anchor_tile, footprint, _object_profile_footprint_anchor(profile))
	var tile_size := anchor_rect.size
	return Rect2(
		anchor_rect.position + Vector2(float(origin.x - anchor_tile.x) * tile_size.x, float(origin.y - anchor_tile.y) * tile_size.y),
		Vector2(tile_size.x * float(footprint.x), tile_size.y * float(footprint.y))
	)

func _object_footprint_origin_for_anchor(anchor_tile: Vector2i, footprint: Vector2i, anchor: String) -> Vector2i:
	match anchor:
		"top_left":
			return anchor_tile
		"center":
			return anchor_tile - Vector2i(int(footprint.x / 2), int(footprint.y / 2))
		"bottom_left":
			return anchor_tile - Vector2i(0, footprint.y - 1)
		"bottom_right":
			return anchor_tile - Vector2i(footprint.x - 1, footprint.y - 1)
		_:
			return anchor_tile - Vector2i(int(footprint.x / 2), footprint.y - 1)

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

func _procedural_ground_center_y_factor(family: String) -> float:
	match family:
		"artifact":
			return 0.70
		"encounter":
			return 0.72
		"scouting_structure", "transit_object", "frontier_shrine":
			return 0.74
		"neutral_dwelling", "repeatable_service", "faction_outpost", "mine", "guarded_reward_site":
			return 0.75
		_:
			return 0.72

func _mapped_sprite_ground_center_y_factor(family: String) -> float:
	match family:
		"artifact":
			return 0.71
		"encounter":
			return 0.73
		"scouting_structure", "transit_object", "frontier_shrine":
			return 0.74
		"neutral_dwelling", "repeatable_service", "faction_outpost", "mine", "guarded_reward_site":
			return 0.75
		_:
			return 0.72

func _procedural_grounding_fraction_metrics(family: String, footprint: Vector2i) -> Dictionary:
	var normalized_footprint := _normalized_footprint(footprint)
	var half_width := 0.28
	var half_height := 0.055
	match family:
		"artifact":
			half_width = 0.22
			half_height = 0.046
		"encounter":
			half_width = 0.34
			half_height = 0.070
		"mine", "guarded_reward_site":
			half_width = 0.40
			half_height = 0.072
		"neutral_dwelling", "repeatable_service", "faction_outpost":
			half_width = 0.42
			half_height = 0.070
		"scouting_structure", "transit_object", "frontier_shrine":
			half_width = 0.32
			half_height = 0.060
		_:
			half_width = 0.28
			half_height = 0.055
	half_width *= 1.0 + (float(normalized_footprint.x - 1) * 0.14)
	half_height *= 1.0 + (float(normalized_footprint.y - 1) * 0.12)
	return {
		"half_width": half_width,
		"half_height": half_height,
	}

func _mapped_sprite_grounding_fraction_metrics(family: String, footprint: Vector2i) -> Dictionary:
	var procedural_metrics := _procedural_grounding_fraction_metrics(family, footprint)
	var half_width := float(procedural_metrics.get("half_width", 0.28))
	var half_height := float(procedural_metrics.get("half_height", 0.055))
	match family:
		"artifact", "pickup":
			half_width *= 0.86
			half_height *= 0.76
		"encounter":
			half_width *= 0.92
			half_height *= 0.82
		_:
			half_width *= 0.90
			half_height *= 0.78
	return {
		"half_width": half_width,
		"half_height": half_height,
	}

func _procedural_resource_marker_color(family: String, remembered: bool) -> Color:
	var color := RESOURCE_COLOR
	match family:
		"neutral_dwelling", "repeatable_service", "faction_outpost":
			color = Color(0.58, 0.43, 0.24, 1.0)
		"mine":
			color = Color(0.58, 0.51, 0.38, 1.0)
		"scouting_structure":
			color = Color(0.55, 0.60, 0.55, 1.0)
		"guarded_reward_site":
			color = Color(0.54, 0.50, 0.42, 1.0)
		"transit_object":
			color = Color(0.57, 0.44, 0.27, 1.0)
		"frontier_shrine":
			color = Color(0.62, 0.58, 0.42, 1.0)
		_:
			color = Color(0.36, 0.70, 0.48, 1.0)
	return _remembered_marker_color(color) if remembered else color

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
	var minimum_tile_extent := _active_minimum_tile_extent()
	if _should_fit_entire_map():
		var fit_extent: float = floor(
			min(
				viewport_size.x / float(max(_map_size.x, 1)),
				viewport_size.y / float(max(_map_size.y, 1))
			)
		)
		return max(fit_extent, minimum_tile_extent)
	var visible_tile_span := _active_visible_tile_span()
	var visible_tile_area := visible_tile_span * visible_tile_span
	var tactical_extent: float = floor(sqrt(max(viewport_size.x * viewport_size.y, 1.0) / maxf(visible_tile_area, 1.0)))
	return max(tactical_extent, minimum_tile_extent)

func _should_fit_entire_map() -> bool:
	var visible_tile_span := int(floor(_active_visible_tile_span()))
	return _map_size.x <= visible_tile_span and _map_size.y <= visible_tile_span

func _active_visible_tile_span() -> float:
	if large_map_visible_tile_span_override > 0.0:
		return maxf(1.0, large_map_visible_tile_span_override)
	return TACTICAL_VISIBLE_TILE_SPAN

func _active_minimum_tile_extent() -> float:
	if large_map_visible_tile_span_override <= 0.0:
		return MIN_TILE_EXTENT
	return maxf(1.0, MIN_TILE_EXTENT * (TACTICAL_VISIBLE_TILE_SPAN / _active_visible_tile_span()))

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
		_invalidate_session_static_cache("camera_pan")
		_invalidate_state_cache("camera_pan")
		_invalidate_dynamic_layer("camera_pan")
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
		_invalidate_session_static_cache("focus_on_hero")
		_invalidate_state_cache("focus_on_hero")
		_invalidate_dynamic_layer("focus_on_hero")
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
	_canvas_draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, viewport_rect.position.y)), FRAME_FILL, true)
	_canvas_draw_rect(Rect2(Vector2(0.0, viewport_rect.end.y), Vector2(size.x, max(size.y - viewport_rect.end.y, 0.0))), FRAME_FILL, true)
	_canvas_draw_rect(Rect2(Vector2(0.0, 0.0), Vector2(viewport_rect.position.x, size.y)), FRAME_FILL, true)
	_canvas_draw_rect(Rect2(Vector2(viewport_rect.end.x, 0.0), Vector2(max(size.x - viewport_rect.end.x, 0.0), size.y)), FRAME_FILL, true)

func validation_reset_profile() -> void:
	_validation_profile.clear()

func validation_set_force_index_rebuild(enabled: bool) -> void:
	_validation_force_index_rebuild = enabled

func validation_set_path_detail_profile_enabled(enabled: bool) -> void:
	_path_detail_profile_enabled = enabled

func validation_profile_snapshot() -> Dictionary:
	return _validation_profile.duplicate(true)

func _profile_begin(_name: String) -> int:
	return Time.get_ticks_usec()

func _profile_end(name: String, started_usec: int, details: Dictionary = {}) -> void:
	var elapsed_usec := maxi(0, Time.get_ticks_usec() - started_usec)
	_profile_add("%s_calls" % name, 1)
	_profile_add("%s_usec" % name, elapsed_usec)
	_validation_profile["last_%s_usec" % name] = elapsed_usec
	if not details.is_empty():
		_validation_profile["last_%s" % name] = details.duplicate(true)

func _profile_add(key: String, amount: int) -> void:
	_validation_profile[key] = int(_validation_profile.get(key, 0)) + amount

func _visible_object_presentation_count(tile: Vector2i) -> int:
	var count := 0
	if _has_town_at(tile):
		count += 1
	if _has_resource_at(tile):
		count += 1
	if _has_artifact_at(tile):
		count += 1
	if _has_encounter_at(tile) or _has_rememberable_encounter_at(tile):
		count += 1
	return count

func validation_view_metrics() -> Dictionary:
	var viewport_rect := _map_viewport_rect()
	var board_rect := _board_rect()
	var cell_size: Vector2 = board_rect.size / Vector2(float(max(_map_size.x, 1)), float(max(_map_size.y, 1)))
	var visible_columns: float = min(float(_map_size.x), viewport_rect.size.x / max(cell_size.x, 1.0))
	var visible_rows: float = min(float(_map_size.y), viewport_rect.size.y / max(cell_size.y, 1.0))
	var focus_tile := _camera_focus_tile()
	var visible_bounds := _visible_tile_bounds(board_rect, viewport_rect)
	var active_visible_tile_span := _active_visible_tile_span()
	return {
		"map_size": {"x": _map_size.x, "y": _map_size.y},
		"viewport_rect": _rect_payload(viewport_rect),
		"board_rect": _rect_payload(board_rect),
		"tile_extent": cell_size.x,
		"default_visible_tile_span": TACTICAL_VISIBLE_TILE_SPAN,
		"active_visible_tile_span": active_visible_tile_span,
		"visible_tile_span_override": large_map_visible_tile_span_override,
		"visible_tile_span_override_active": large_map_visible_tile_span_override > 0.0,
		"visible_tile_span_zoom_out_factor": active_visible_tile_span / TACTICAL_VISIBLE_TILE_SPAN,
		"minimum_tile_extent": _active_minimum_tile_extent(),
		"visible_tile_columns": visible_columns,
		"visible_tile_rows": visible_rows,
		"visible_tile_area": visible_columns * visible_rows,
		"full_map_visible": board_rect.size.x <= viewport_rect.size.x + 0.01 and board_rect.size.y <= viewport_rect.size.y + 0.01,
		"fit_entire_map": _should_fit_entire_map(),
		"pan_supported": _can_pan_camera(),
		"manual_camera": _manual_camera,
		"visual_render_path": "normal_overworld_art",
		"generated_maps_use_normal_art_path": true,
		"primitive_generated_render_path": false,
		"camera_focus_tile": {"x": int(round(focus_tile.x)), "y": int(round(focus_tile.y))},
		"camera_focus_tile_precise": {"x": focus_tile.x, "y": focus_tile.y},
		"visible_bounds": {
			"x": visible_bounds.position.x,
			"y": visible_bounds.position.y,
			"width": visible_bounds.size.x,
			"height": visible_bounds.size.y,
		},
		"render_cache": {
			"session_static_generation": _session_static_cache_generation,
			"state_generation": _state_cache_generation,
			"dynamic_generation": _dynamic_layer_generation,
			"frame_generation": _frame_layer_generation,
			"session_static_reason": _session_static_cache_reason,
			"state_reason": _state_cache_reason,
			"dynamic_reason": _dynamic_layer_reason,
			"frame_reason": _frame_layer_reason,
			"profile": validation_profile_snapshot(),
		},
		"spatial_index": {
			"town_tiles": _towns_by_tile.size(),
			"town_footprint_tiles": _town_footprints_by_tile.size(),
			"resource_tiles": _resources_by_tile.size(),
			"artifact_tiles": _artifacts_by_tile.size(),
			"encounter_tiles": _encounters_by_tile.size(),
			"rememberable_encounter_tiles": _rememberable_encounters_by_tile.size(),
			"hero_tiles": _heroes_by_tile.size(),
		},
	}

func _rect2i_payload(rect: Rect2i) -> Dictionary:
	return {
		"x": rect.position.x,
		"y": rect.position.y,
		"width": rect.size.x,
		"height": rect.size.y,
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
	var town_presentation := _town_presentation_payload(tile, explored, visible)
	var has_town_footprint := bool(town_presentation.get("has_town_footprint", false))
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
		has_town or has_resource or has_artifact or has_rememberable_encounter or has_town_footprint
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
		"has_town_footprint": has_town_footprint,
		"has_town_entry": bool(town_presentation.get("is_entry_tile", false)),
		"has_town_non_entry": has_town_footprint and not bool(town_presentation.get("is_entry_tile", false)),
		"draws_discoverable_object": (visible and (has_town or has_resource or has_artifact or has_visible_encounter or has_town_footprint)) or remembered_object,
		"draws_remembered_object": remembered_object,
		"terrain_presentation": _terrain_visual_payload(tile, explored, visible),
		"marker_readability": _marker_readability_payload(tile, explored, visible, object_kinds, has_visible_hero),
		"art_presentation": _object_art_payload(tile, explored, visible, object_kinds),
		"town_presentation": town_presentation,
	}

func validation_editor_restamp_payload(tile: Vector2i) -> Dictionary:
	return _homm3_editor_restamp_payload(tile)

func validation_town_presentation_profiles() -> Array:
	var profiles := []
	if _session == null:
		return profiles
	for town_value in _session.overworld.get("towns", []):
		if not (town_value is Dictionary):
			continue
		var town: Dictionary = town_value
		profiles.append(_town_presentation_payload_for_town(town, true))
	return profiles

func _town_presentation_payload(tile: Vector2i, explored: bool, visible: bool) -> Dictionary:
	if not explored:
		return {
			"has_town_footprint": false,
			"presentation_model": "",
			"tile_role": "",
			"is_entry_tile": false,
			"is_visit_tile": false,
			"presentation_blocked": false,
			"non_entry_tiles_blocked": false,
		}
	var presentation := _town_presentation_at(tile)
	if presentation.is_empty():
		return {
			"has_town_footprint": false,
			"presentation_model": "",
			"tile_role": "",
			"is_entry_tile": false,
			"is_visit_tile": false,
			"presentation_blocked": false,
			"non_entry_tiles_blocked": false,
		}
	var town: Dictionary = presentation.get("town", {})
	var payload := _town_presentation_payload_for_town(town, true)
	payload["visible"] = visible
	payload["remembered"] = not visible
	payload["tile"] = {"x": tile.x, "y": tile.y}
	var cell_offset: Vector2i = presentation.get("cell_offset", Vector2i.ZERO)
	payload["cell_offset"] = {"x": cell_offset.x, "y": cell_offset.y}
	payload["tile_role"] = String(presentation.get("tile_role", ""))
	payload["is_entry_tile"] = bool(presentation.get("is_entry_tile", false))
	payload["is_visit_tile"] = bool(presentation.get("is_entry_tile", false))
	payload["presentation_blocked"] = bool(presentation.get("presentation_blocked", false))
	payload["visible_helper_cues"] = false
	payload["footprint_helper_glyphs"] = false
	payload["entry_apron_cue"] = false
	payload["entry_wedge_cue"] = false
	payload["gate_cue"] = false
	payload["helper_circle_cue"] = false
	return payload

func _town_presentation_payload_for_town(town: Dictionary, include_cells: bool) -> Dictionary:
	var entry := _town_entry_tile(town)
	var origin := _town_footprint_origin_for_entry(entry)
	var cells := _town_footprint_cell_payloads(entry) if include_cells else []
	var blocked_cells := []
	var off_map_cells := 0
	for cell_value in cells:
		if not (cell_value is Dictionary):
			continue
		var cell: Dictionary = cell_value
		if bool(cell.get("is_entry_tile", false)):
			continue
		if not bool(cell.get("in_bounds", false)):
			off_map_cells += 1
			continue
		blocked_cells.append(cell)
	return {
		"has_town_footprint": true,
		"presentation_model": TOWN_PRESENTATION_MODEL,
		"footprint_width_tiles": TOWN_PRESENTATION_FOOTPRINT.x,
		"footprint_height_tiles": TOWN_PRESENTATION_FOOTPRINT.y,
		"footprint_cue_model": TOWN_FOOTPRINT_CUE_MODEL,
		"base_ellipse": false,
		"filled_underlay": false,
		"cast_shadow": false,
		"visible_helper_cues": false,
		"footprint_helper_glyphs": false,
		"entry_apron_cue": false,
		"entry_wedge_cue": false,
		"gate_cue": false,
		"helper_circle_cue": false,
		"grounding_model": TOWN_GROUNDING_MODEL,
		"entry_role": TOWN_ENTRY_ROLE,
		"entry_offset": {"x": TOWN_ENTRY_OFFSET.x, "y": TOWN_ENTRY_OFFSET.y},
		"entry_tile": {"x": entry.x, "y": entry.y},
		"origin_tile": {"x": origin.x, "y": origin.y},
		"entry_is_visit_tile": true,
		"non_entry_tiles_blocked": true,
		"presentation_passability": "entry_only",
		"town_placement_id": String(town.get("placement_id", "")),
		"town_id": String(town.get("town_id", "")),
		"owner": String(town.get("owner", "neutral")),
		"footprint_cells": cells,
		"blocked_footprint_cells": blocked_cells,
		"blocked_footprint_cell_count": blocked_cells.size(),
		"off_map_footprint_cell_count": off_map_cells,
	}

func _town_footprint_cell_payloads(entry: Vector2i) -> Array:
	var cells := []
	var origin := _town_footprint_origin_for_entry(entry)
	for y_offset in range(TOWN_PRESENTATION_FOOTPRINT.y):
		for x_offset in range(TOWN_PRESENTATION_FOOTPRINT.x):
			var tile := origin + Vector2i(x_offset, y_offset)
			var is_entry := tile == entry
			cells.append({
				"x": tile.x,
				"y": tile.y,
				"offset_x": x_offset,
				"offset_y": y_offset,
				"in_bounds": tile.x >= 0 and tile.y >= 0 and tile.x < _map_size.x and tile.y < _map_size.y,
				"is_entry_tile": is_entry,
				"tile_role": TOWN_ENTRY_ROLE if is_entry else TOWN_NON_ENTRY_ROLE,
				"presentation_blocked": not is_entry,
			})
	return cells

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
			"visible_terrain_grid_mode": "hidden_fog_wireframe",
			"visible_terrain_grid_alpha": 0.0,
			"explored_intertile_seams": false,
			"unexplored_wireframe": true,
			"unexplored_wireframe_alpha": UNEXPLORED_GRID_COLOR.a,
			"fog_boundary_alpha": 0.0,
			"rendering_mode": "hidden_fog",
		}
	var terrain := _terrain_at(tile)
	var base_color: Color = _terrain_color(terrain, "base_color", TERRAIN_COLORS.get(terrain, TERRAIN_COLORS["grass"]))
	var road_payload := _road_tile_payload(tile)
	var transition_payload := _terrain_transition_payload(tile)
	var transition_mask := String(transition_payload.get("edge_mask", ""))
	var transition_corner_mask := String(transition_payload.get("corner_mask", ""))
	var tile_art_entry := _terrain_base_art_entry(terrain, tile)
	var tile_art_path := String(tile_art_entry.get("path", ""))
	var homm3_selection: Dictionary = tile_art_entry.get("homm3_selection", {})
	var tile_art_primary := _terrain_art_can_be_primary(terrain)
	var tile_art_loaded := tile_art_primary and _terrain_art_texture(tile_art_path) is Texture2D
	var edge_art_count := _transition_edge_art_count(transition_payload)
	var edge_transition_count := _transition_source_count(transition_payload, "cardinal_sources")
	var corner_transition_count := _transition_source_count(transition_payload, "corner_sources")
	var propagated_transition_count := _transition_source_count(transition_payload, "propagated_sources")
	var road_neighbor_directions := _road_neighbor_directions(tile) if not road_payload.is_empty() else []
	var road_art_loaded := _road_overlay_art_loaded(road_payload, tile)
	var road_connection_piece_loaded := _road_connection_piece_loaded(road_payload, tile)
	var road_joint_cap := _road_needs_joint_cap(road_neighbor_directions) if not road_payload.is_empty() else false
	var road_connection_key := _road_connection_key_from_directions(road_neighbor_directions) if not road_payload.is_empty() else ""
	var road_has_horizontal := _road_has_horizontal_connections(road_neighbor_directions)
	var road_has_vertical := _road_has_vertical_connections(road_neighbor_directions)
	var road_has_diagonal := _road_has_diagonal_connections(road_neighbor_directions)
	var primary_base_model := TERRAIN_HOMM3_LOCAL_PROTOTYPE_RENDERING_MODE if tile_art_loaded and not homm3_selection.is_empty() else (TERRAIN_ORIGINAL_TILE_BANK_RENDERING_MODE if tile_art_loaded else (TERRAIN_GRAMMAR_RENDERING_MODE if not _terrain_style(terrain).is_empty() else "procedural_color_pattern"))
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
		"visible_terrain_grid_mode": EXPLORED_TERRAIN_GRID_MODE,
		"visible_terrain_grid_alpha": EXPLORED_TERRAIN_GRID_ALPHA,
		"explored_intertile_seams": false,
		"unexplored_wireframe": false,
		"unexplored_wireframe_alpha": UNEXPLORED_GRID_COLOR.a,
		"fog_boundary_alpha": EXPLORED_TERRAIN_FOG_BOUNDARY_COLOR.a,
		"uses_sampled_texture": false,
		"uses_authored_tile_art": tile_art_loaded,
		"uses_original_tile_bank": tile_art_loaded and homm3_selection.is_empty(),
		"uses_homm3_local_prototype": tile_art_loaded and not homm3_selection.is_empty(),
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
		"terrain_noise_profile": "homm3_extracted_atlas_frame" if tile_art_loaded and not homm3_selection.is_empty() else ("quiet_low_contrast_macro_readable" if tile_art_loaded else "grammar_pattern_fallback"),
		"terrain_variant_selection": "accepted_web_relation_class_row_lookup" if tile_art_loaded and not homm3_selection.is_empty() else ("patch_cohesive_low_frequency" if tile_art_loaded else "procedural_fallback_marks"),
		"grasslands_base_cohesion": "homm3_grass_atlas_family" if _terrain_group(terrain) == "grasslands" and tile_art_loaded and not homm3_selection.is_empty() else ("grass_plains_shared_palette" if _terrain_group(terrain) == "grasslands" and tile_art_loaded else ""),
		"homm3_local_reference_only": bool(homm3_selection.get("local_reference_only", false)),
		"homm3_terrain_lookup_model": String(homm3_selection.get("terrain_lookup_model", "")),
		"homm3_logical_terrain_id": String(homm3_selection.get("logical_terrain_id", terrain)),
		"homm3_terrain_family": String(homm3_selection.get("family", "")),
		"homm3_renderer_family": String(homm3_selection.get("renderer_family", "")),
		"homm3_terrain_atlas": String(homm3_selection.get("atlas_id", "")),
		"homm3_atlas_role": String(homm3_selection.get("atlas_role", "")),
		"homm3_atlas_role_source_level": String(homm3_selection.get("atlas_role_source_level", "")),
		"homm3_special_system": String(homm3_selection.get("special_system", "")),
		"homm3_special_system_flag": bool(homm3_selection.get("special_system_flag", false)),
		"homm3_allows_generic_land_edge_masks": bool(homm3_selection.get("allows_generic_land_edge_masks", false)),
		"homm3_uses_land_receiver_stamp_tables": bool(homm3_selection.get("uses_land_receiver_stamp_tables", false)),
		"homm3_terrain_frame": String(homm3_selection.get("frame_id", "")),
		"homm3_selected_frame_block": String(homm3_selection.get("selected_frame_block", "")),
		"homm3_selected_frame_block_range": String(homm3_selection.get("selected_frame_block_range", "")),
		"homm3_selected_frame_block_source_level": String(homm3_selection.get("selected_frame_block_source_level", "")),
		"homm3_selected_frame_block_role": String(homm3_selection.get("selected_frame_block_role", "")),
		"homm3_selection_kind": String(homm3_selection.get("selection_kind", "")),
		"homm3_mask_key": String(homm3_selection.get("mask_key", "")),
		"homm3_preferred_bridge_class": String(homm3_selection.get("preferred_bridge_class", "")),
		"homm3_preferred_bridge_family": String(homm3_selection.get("preferred_bridge_family", "")),
		"homm3_preferred_bridge_source_level": String(homm3_selection.get("preferred_bridge_source_level", "")),
		"homm3_bridge_material_class": String(homm3_selection.get("bridge_material_class", "")),
		"homm3_bridge_family": String(homm3_selection.get("bridge_family", "")),
		"homm3_bridge_class": String(homm3_selection.get("bridge_class", "")),
		"homm3_bridge_resolution_model": String(homm3_selection.get("bridge_resolution_model", "")),
		"homm3_bridge_resolver_model": String(homm3_selection.get("bridge_resolver_model", "")),
		"homm3_bridge_source_kind": String(homm3_selection.get("bridge_source_kind", "")),
		"homm3_bridge_source_level": String(homm3_selection.get("bridge_source_level", "")),
		"homm3_bridge_rule_id": String(homm3_selection.get("bridge_rule_id", "")),
		"homm3_bridge_target_frame_block": String(homm3_selection.get("bridge_target_frame_block", "")),
		"homm3_bridge_policy_provisional": bool(homm3_selection.get("bridge_policy_provisional", false)),
		"homm3_stamp_lookup_model": String(homm3_selection.get("stamp_lookup_model", "")),
		"homm3_stamp_selection_model": String(homm3_selection.get("stamp_selection_model", "")),
		"homm3_stamp_table_id": String(homm3_selection.get("stamp_table_id", "")),
		"homm3_stamp_anchor": String(homm3_selection.get("stamp_anchor", "")),
		"homm3_stamp_source_kind": String(homm3_selection.get("stamp_source_kind", "")),
		"homm3_stamp_source_direction": String(homm3_selection.get("stamp_source_direction", "")),
		"homm3_stamp_source_offset": homm3_selection.get("stamp_source_offset", {}),
		"homm3_stamp_selected_frame": String(homm3_selection.get("stamp_selected_frame", "")),
		"homm3_stamp_transform": String(homm3_selection.get("stamp_transform", "")),
		"homm3_stamp_flip_h": bool(homm3_selection.get("stamp_flip_h", false)),
		"homm3_stamp_flip_v": bool(homm3_selection.get("stamp_flip_v", false)),
		"homm3_stamp_source_level": String(homm3_selection.get("stamp_source_level", "")),
		"homm3_stamp_mapping_source_level": String(homm3_selection.get("stamp_mapping_source_level", "")),
		"homm3_stamp_frame_range_source_level": String(homm3_selection.get("stamp_frame_range_source_level", "")),
		"homm3_stamp_frame_range": String(homm3_selection.get("stamp_frame_range", "")),
		"homm3_stamp_target_frame_block": String(homm3_selection.get("stamp_target_frame_block", "")),
		"homm3_stamp_bridge_family": String(homm3_selection.get("stamp_bridge_family", "")),
		"homm3_stamp_bridge_class": String(homm3_selection.get("stamp_bridge_class", "")),
		"homm3_stamp_source_offset_model": String(homm3_selection.get("stamp_source_offset_model", "")),
		"homm3_stamp_array_reconstruction_mode": String(homm3_selection.get("stamp_array_reconstruction_mode", "")),
		"homm3_stamp_mixed_junction_reserved": bool(homm3_selection.get("stamp_mixed_junction_reserved", false)),
		"homm3_stamp_mixed_junction_policy": String(homm3_selection.get("stamp_mixed_junction_policy", "")),
		"homm3_stamp_reserved_mixed_junction_frame_ranges": homm3_selection.get("stamp_reserved_mixed_junction_frame_ranges", []),
		"homm3_visual_selection_model": String(homm3_selection.get("visual_selection_model", "")),
		"homm3_visual_frame_selection_source": String(homm3_selection.get("visual_frame_selection_source", "")),
		"homm3_final_normalization_model": String(homm3_selection.get("final_normalization_model", "")),
		"homm3_owner_id": int(homm3_selection.get("owner_id", -1)),
		"homm3_shape_class": int(homm3_selection.get("shape_class", 0)),
		"homm3_class_topology": String(homm3_selection.get("class_topology", "")),
		"homm3_class_reason": String(homm3_selection.get("class_reason", "")),
		"homm3_class_correction": String(homm3_selection.get("class_correction", "")),
		"homm3_boundary_count": int(homm3_selection.get("boundary_count", 0)),
		"homm3_relation_ring": homm3_selection.get("relation_ring", []),
		"homm3_relation_grid": String(homm3_selection.get("relation_grid", "")),
		"homm3_projection_model": String(homm3_selection.get("projection_model", "")),
		"homm3_raw_quadrants": homm3_selection.get("raw_quadrants", []),
		"homm3_owner_footprint_quadrants": homm3_selection.get("owner_footprint_quadrants", []),
		"homm3_material_quadrants": homm3_selection.get("material_quadrants", []),
		"homm3_count_quadrants": homm3_selection.get("count_quadrants", []),
		"homm3_normalized_quadrants": homm3_selection.get("normalized_quadrants", []),
		"homm3_visual_quadrants": homm3_selection.get("visual_quadrants", []),
		"homm3_display_quadrants": homm3_selection.get("display_quadrants", []),
		"homm3_row_group": String(homm3_selection.get("row_group", "")),
		"homm3_row_source": String(homm3_selection.get("row_source", "")),
		"homm3_row_table": String(homm3_selection.get("row_table", "")),
		"homm3_requested_flag_a": int(homm3_selection.get("requested_flag_a", 0)),
		"homm3_requested_flag_b": int(homm3_selection.get("requested_flag_b", 0)),
		"homm3_selected_flag_a": int(homm3_selection.get("selected_flag_a", 0)),
		"homm3_selected_flag_b": int(homm3_selection.get("selected_flag_b", 0)),
		"homm3_web_prototype_selection_model": String(homm3_selection.get("web_prototype_selection_model", "")),
		"homm3_web_prototype_shape_class": int(homm3_selection.get("web_prototype_shape_class", 0)),
		"homm3_web_prototype_class_topology": String(homm3_selection.get("web_prototype_class_topology", "")),
		"homm3_web_prototype_class_reason": String(homm3_selection.get("web_prototype_class_reason", "")),
		"homm3_web_prototype_correction": String(homm3_selection.get("web_prototype_correction", "")),
		"homm3_web_prototype_relation_grid": String(homm3_selection.get("web_prototype_relation_grid", "")),
		"homm3_web_prototype_row_group": String(homm3_selection.get("web_prototype_row_group", "")),
		"homm3_web_prototype_flag_a": int(homm3_selection.get("web_prototype_flag_a", 0)),
		"homm3_web_prototype_flag_b": int(homm3_selection.get("web_prototype_flag_b", 0)),
		"homm3_web_prototype_fallback": bool(homm3_selection.get("web_prototype_fallback", false)),
		"homm3_web_prototype_direct_water_rock_contact": bool(homm3_selection.get("web_prototype_direct_water_rock_contact", false)),
		"homm3_editor_restamp_model": _homm3_editor_restamp_model(),
		"homm3_editor_restamp_scope": _homm3_editor_restamp_scope(),
		"homm3_editor_restamp_source_level": _homm3_editor_restamp_source_level(),
		"homm3_editor_restamp_renderer_evaluation_model": _homm3_editor_restamp_renderer_evaluation_model(),
		"homm3_editor_restamp_logical_map_write_model": _homm3_editor_restamp_logical_map_write_model(),
		"homm3_direct_bridge_material_contact": bool(homm3_selection.get("direct_bridge_material_contact", false)),
		"homm3_preferred_bridge_class_used": bool(homm3_selection.get("preferred_bridge_class_used", false)),
		"homm3_shoreline_specific": bool(homm3_selection.get("shoreline_specific", false)),
		"homm3_water_bridge_class": String(homm3_selection.get("water_bridge_class", "")),
		"homm3_rock_system": String(homm3_selection.get("rock_system", "")),
		"homm3_rock_ground_context": String(homm3_selection.get("rock_ground_context", "")),
		"homm3_receiver_transition_policy": String(homm3_selection.get("receiver_transition_policy", "")),
		"homm3_corner_lookup": bool(homm3_selection.get("corner_lookup", false)),
		"homm3_corner_lookup_model": String(homm3_selection.get("corner_lookup_model", "")),
		"homm3_terrain_flip": String(homm3_selection.get("flip", "")),
		"homm3_terrain_flip_h": bool(homm3_selection.get("flip_h", false)),
		"homm3_terrain_flip_v": bool(homm3_selection.get("flip_v", false)),
		"homm3_propagated_transition": bool(homm3_selection.get("propagated_transition", false)),
		"homm3_transition_propagation_model": String(homm3_selection.get("transition_propagation_model", "")),
		"homm3_transition_source_distance": int(homm3_selection.get("transition_source_distance", 0)),
		"homm3_transition_source_offset": homm3_selection.get("transition_source_offset", {}),
		"homm3_transition_source_direction": String(homm3_selection.get("transition_source_direction", "")),
		"homm3_interior_frame_selection": String(homm3_selection.get("interior_frame_selection", "")),
		"homm3_interior_frame_count": int(homm3_selection.get("interior_frame_count", 0)),
		"homm3_uses_interior_variant_cycle": bool(homm3_selection.get("uses_interior_variant_cycle", false)),
		"homm3_unsupported_policy": String(homm3_selection.get("unsupported_policy", "")),
		"homm3_fallback": bool(homm3_selection.get("fallback", false)),
		"homm3_direct_water_rock_contact": bool(homm3_selection.get("direct_water_rock_contact", false)),
		"homm3_fallback_reason": String(homm3_selection.get("fallback_reason", "")),
		"homm3_provisional_fallback_policy": String(homm3_selection.get("provisional_fallback_policy", "")),
		"homm3_unresolved_fallback_policy": String(homm3_selection.get("unresolved_fallback_policy", "")),
		"homm3_logical_degrade_note": String(homm3_selection.get("logical_degrade_note", "")),
		"neighbor_aware_transitions": true,
		"transition_calculation_model": TERRAIN_TRANSITION_SELECTION_MODEL,
		"transition_edge_model": TERRAIN_TRANSITION_EDGE_MODEL,
		"transition_corner_model": TERRAIN_TRANSITION_CORNER_MODEL,
		"transition_receiver_terrain": terrain,
		"transition_receiver_group": _terrain_group(terrain),
		"transition_priority": _terrain_transition_priority(terrain),
		"transition_edge_mask": transition_mask,
		"transition_corner_mask": transition_corner_mask,
		"transition_source_terrain_ids": transition_payload.get("source_terrain_ids", []),
		"transition_source_groups": transition_payload.get("source_groups", []),
		"transition_cardinal_sources": transition_payload.get("cardinal_sources", []),
		"transition_corner_sources": transition_payload.get("corner_sources", []),
		"transition_propagated_sources": transition_payload.get("propagated_sources", []),
		"transition_relationship_count": edge_transition_count + corner_transition_count + propagated_transition_count,
		"edge_transition_count": edge_transition_count,
		"corner_transition_count": corner_transition_count,
		"propagated_transition_count": propagated_transition_count,
		"transition_uses_second_ring": bool(homm3_selection.get("uses_second_ring", false)) if not homm3_selection.is_empty() else false,
		"transition_diagonal_policy": String(homm3_selection.get("diagonal_policy", "")),
		"edge_transition_art_count": edge_art_count,
		"edge_transition_art_loaded": edge_transition_count > 0 and edge_art_count == edge_transition_count,
		"transition_shape_model": "homm3_base_atlas_frame" if not homm3_selection.is_empty() else ("jagged_directional_overlay" if edge_art_count > 0 else "procedural_strip_fallback"),
		"transition_edge_treatment": "bridge_or_shoreline_encoded_in_selected_tile" if not homm3_selection.is_empty() else ("soft_feathered_jagged_overlay" if edge_art_count > 0 else "procedural_strip_fallback"),
		"transition_selection_rule": "settled_owner_relation_classes_select_recovered_row_buckets" if not homm3_selection.is_empty() else "higher_priority_neighbor_intrudes_into_lower_priority_receiver",
		"higher_priority_neighbor_intrusion": edge_transition_count > 0 or corner_transition_count > 0 or propagated_transition_count > 0,
		"same_group_transition_suppressed": true,
		"road_overlay": not road_payload.is_empty(),
		"road_overlay_id": String(road_payload.get("overlay_id", "")),
		"road_role": String(road_payload.get("role", "")),
		"road_overlay_art": road_art_loaded,
		"road_shape_model": "homm3_4_neighbor_overlay_lookup" if road_art_loaded else ("homm3_4_neighbor_procedural_connectors" if not road_payload.is_empty() else ""),
		"road_lane_model": ROAD_LANE_MODEL if not road_payload.is_empty() else "",
		"road_piece_selection_model": String(road_payload.get("piece_selection_model", "")),
		"road_same_type_adjacency": bool(road_payload.get("same_type_adjacency", false)),
		"road_connection_key": road_connection_key,
		"road_connection_count": road_neighbor_directions.size(),
		"road_connection_source": String(road_payload.get("connection_source", "")),
		"road_horizontal_edge_riding": false,
		"road_horizontal_lane": ROAD_HORIZONTAL_LANE if road_has_horizontal else "",
		"road_vertical_centered": road_has_vertical,
		"road_vertical_lane": ROAD_VERTICAL_LANE if road_has_vertical else "",
		"road_diagonal_connections": road_has_diagonal,
		"road_orthogonal_mask_only": not road_payload.is_empty(),
		"road_orthogonal_lookup_table": String(_homm3_road_overlays.get(String(road_payload.get("overlay_id", "road_dirt")), {}).get("lookup_table", "")) if not road_payload.is_empty() else "",
		"road_diagonal_tile_piece": false,
		"road_diagonal_piece_model": "",
		"road_straight_tile_piece": road_connection_piece_loaded,
		"road_unordered_adjacency_suppressed": bool(road_payload.get("ordered_connections", false)),
		"road_joint_cap": road_joint_cap,
		"road_joint_cap_model": "connection_aware_joint_cap" if not road_payload.is_empty() else "",
	}

func _transition_edge_art_count(transition_payload: Dictionary) -> int:
	var count := 0
	var cardinal_sources = transition_payload.get("cardinal_sources", [])
	if not (cardinal_sources is Array):
		return count
	for source_value in cardinal_sources:
		if not (source_value is Dictionary):
			continue
		var source: Dictionary = source_value
		var source_terrain := String(source.get("source_terrain", ""))
		if not _terrain_art_can_be_primary(source_terrain):
			continue
		var direction := String(source.get("direction", ""))
		if _terrain_art_texture(_terrain_edge_art_path(source_terrain, direction)) is Texture2D:
			count += 1
	return count

func _transition_source_count(transition_payload: Dictionary, key: String) -> int:
	var sources = transition_payload.get(key, [])
	return sources.size() if sources is Array else 0

func _road_overlay_art_loaded(road_payload: Dictionary, tile: Vector2i) -> bool:
	if road_payload.is_empty():
		return false
	var overlay_id := String(road_payload.get("overlay_id", "road_dirt"))
	var homm3_path := _homm3_road_art_path(overlay_id, tile)
	if homm3_path != "":
		return _terrain_art_texture(homm3_path) is Texture2D
	if not _road_overlay_art_can_be_primary(overlay_id):
		return false
	var art := _road_overlay_art_paths(overlay_id)
	if art.is_empty():
		return false
	var center_loaded := _terrain_art_texture(String(art.get("center", ""))) is Texture2D
	var neighbor_directions := _road_neighbor_directions(tile)
	var connection_pieces = art.get("connection_pieces", {})
	if connection_pieces is Dictionary and _terrain_art_texture(String(connection_pieces.get(_road_connection_key_from_directions(neighbor_directions), ""))) is Texture2D:
		return true
	var connectors = art.get("connectors", {})
	var loaded_connector := false
	if connectors is Dictionary:
		for direction in neighbor_directions:
			if _terrain_art_texture(String(connectors.get(_direction_key(direction), ""))) is Texture2D:
				loaded_connector = true
	if not neighbor_directions.is_empty():
		return loaded_connector and (center_loaded or not _road_needs_joint_cap(neighbor_directions))
	return center_loaded

func _road_connection_piece_loaded(road_payload: Dictionary, tile: Vector2i) -> bool:
	if road_payload.is_empty():
		return false
	if _homm3_road_overlays.has(String(road_payload.get("overlay_id", "road_dirt"))):
		return _road_connection_key(tile) in ["N+S", "E+W"]
	var overlay_id := String(road_payload.get("overlay_id", "road_dirt"))
	if not _road_overlay_art_can_be_primary(overlay_id):
		return false
	var art := _road_overlay_art_paths(overlay_id)
	var connection_pieces = art.get("connection_pieces", {})
	if not (connection_pieces is Dictionary):
		return false
	var connection_key := _road_connection_key(tile)
	return _terrain_art_texture(String(connection_pieces.get(connection_key, ""))) is Texture2D

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
			"fallback_grounding_model": "",
			"fallback_shared_marker_plate": false,
			"fallback_upper_mass_backdrop": false,
			"fallback_foreground_lip": false,
			"fallback_contact_shadow_model": "",
			"unmapped_object_fallback": String(_overworld_art_manifest.get("unmapped_object_fallback", "procedural_marker")),
		}
	var sprite_asset_ids: Array[String] = []
	var sprite_footprints: Array = []
	if "town" in object_kinds and _town_default_asset_id != "":
		if _object_texture_for_asset(_town_default_asset_id) is Texture2D:
			sprite_asset_ids.append(_town_default_asset_id)
			var town_footprint := _object_profile_footprint(_town_object_profile())
			sprite_footprints.append({"width": town_footprint.x, "height": town_footprint.y})
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
	if "encounter" in object_kinds and _encounter_default_asset_id != "":
		if _object_texture_for_asset(_encounter_default_asset_id) is Texture2D:
			sprite_asset_ids.append(_encounter_default_asset_id)
			var encounter_footprint := _object_profile_footprint(_encounter_object_profile())
			sprite_footprints.append({"width": encounter_footprint.x, "height": encounter_footprint.y})
	var uses_asset_sprite := not sprite_asset_ids.is_empty()
	var uses_town_sprite := "town" in object_kinds and _town_default_asset_id in sprite_asset_ids
	var uses_mapped_sprite := uses_asset_sprite and not uses_town_sprite
	var uses_fallback := not uses_asset_sprite and not object_kinds.is_empty()
	return {
		"uses_asset_sprite": uses_asset_sprite,
		"fallback_procedural_marker": uses_fallback,
		"fallback_silhouette_model": OBJECT_PROCEDURAL_FALLBACK_MODEL if uses_fallback else "",
		"sprite_asset_ids": sprite_asset_ids,
		"sprite_footprints": sprite_footprints,
		"remembered_sprite_treatment": "ghosted_sprite_with_ground_anchor" if uses_asset_sprite and not visible else "",
		"sprite_settlement_model": TOWN_GROUNDING_MODEL if uses_town_sprite else (OBJECT_SPRITE_SETTLEMENT_MODEL if uses_asset_sprite else ""),
		"settled_sprite_occlusion": false if uses_mapped_sprite else uses_asset_sprite,
		"sprite_depth_contact_cues": uses_asset_sprite,
		"sprite_depth_cue_model": TOWN_DEPTH_CUE_MODEL if uses_town_sprite else (OBJECT_MAPPED_SPRITE_DEPTH_CUE_MODEL if uses_asset_sprite else ""),
		"sprite_placement_bed": false,
		"sprite_placement_bed_model": "",
		"sprite_upper_mass_backdrop": false,
		"sprite_upper_mass_backdrop_model": "",
		"sprite_vertical_mass_shadow": false,
		"mapped_sprite_grounding": uses_mapped_sprite,
		"mapped_sprite_grounding_model": OBJECT_MAPPED_SPRITE_GROUNDING_MODEL if uses_mapped_sprite else "",
		"mapped_sprite_contact_shadow_model": OBJECT_MAPPED_SPRITE_CONTACT_MODEL if uses_mapped_sprite else "",
		"mapped_sprite_contact_scuffs": uses_mapped_sprite,
		"mapped_sprite_foreground_lip": false if uses_mapped_sprite else null,
		"mapped_sprite_support_stack": false if uses_mapped_sprite else null,
		"fallback_grounding_model": OBJECT_PROCEDURAL_GROUNDING_MODEL if uses_fallback else "",
		"fallback_shared_marker_plate": false if uses_fallback else null,
		"fallback_upper_mass_backdrop": false if uses_fallback else null,
		"fallback_foreground_lip": false if uses_fallback else null,
		"fallback_contact_shadow_model": OBJECT_PROCEDURAL_CONTACT_MODEL if uses_fallback else "",
		"town_sprite_grounding_model": TOWN_GROUNDING_MODEL if uses_town_sprite else "",
		"town_footprint_cue_model": TOWN_FOOTPRINT_CUE_MODEL if uses_town_sprite else "",
		"town_base_ellipse": false if uses_town_sprite else null,
		"town_underlay": false if uses_town_sprite else null,
		"town_cast_shadow": false if uses_town_sprite else null,
		"town_vertical_mass_shadow": false if uses_town_sprite else null,
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
	var uses_procedural_fallback := bool(art_payload.get("fallback_procedural_marker", false))
	var uses_town_asset_sprite := String(art_payload.get("town_sprite_grounding_model", "")) != ""
	var uses_mapped_sprite_grounding := uses_asset_sprite and not uses_town_asset_sprite
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
	var uses_hero_grounding := has_visible_hero and dominant_family == "hero" and not has_object_marker
	var uses_quiet_town_grounding := has_presence and dominant_family == "town"
	uses_mapped_sprite_grounding = uses_mapped_sprite_grounding and has_presence and not uses_quiet_town_grounding and not uses_hero_grounding
	var uses_procedural_grounding := has_presence and uses_procedural_fallback and not uses_quiet_town_grounding and not uses_hero_grounding
	var uses_shared_grounding := false
	var hero_anchor_half_width_fraction := 0.28
	var hero_anchor_half_height_fraction := 0.075
	if uses_hero_grounding:
		anchor_half_width_fraction = hero_anchor_half_width_fraction
		anchor_half_height_fraction = hero_anchor_half_height_fraction
	if uses_mapped_sprite_grounding:
		var mapped_metrics := _mapped_sprite_grounding_fraction_metrics(dominant_family, dominant_footprint)
		anchor_half_width_fraction = float(mapped_metrics.get("half_width", anchor_half_width_fraction))
		anchor_half_height_fraction = float(mapped_metrics.get("half_height", anchor_half_height_fraction))
	if uses_procedural_grounding:
		var procedural_metrics := _procedural_grounding_fraction_metrics(dominant_family, dominant_footprint)
		anchor_half_width_fraction = float(procedural_metrics.get("half_width", anchor_half_width_fraction))
		anchor_half_height_fraction = float(procedural_metrics.get("half_height", anchor_half_height_fraction))
	var backdrop_metrics := _upper_mass_backdrop_metrics(
		dominant_family,
		dominant_footprint,
		Vector2(anchor_half_width_fraction * extent, anchor_half_height_fraction * extent),
		extent
	) if uses_shared_grounding else {}
	return {
		"object_kinds": object_kinds,
		"marker_kinds": marker_kinds,
		"contrast_plate": uses_shared_grounding,
		"ground_anchor": has_presence,
		"anchor_shape": TOWN_ANCHOR_STYLE if uses_quiet_town_grounding else (HERO_ANCHOR_STYLE if uses_hero_grounding else (OBJECT_PROCEDURAL_ANCHOR_STYLE if uses_procedural_grounding else (OBJECT_MAPPED_SPRITE_ANCHOR_STYLE if uses_mapped_sprite_grounding else (MARKER_GROUND_ANCHOR_STYLE if has_presence else "")))),
		"presence_model": HERO_PRESENCE_MODEL if uses_hero_grounding else (OBJECT_PRESENCE_MODEL if has_presence else ""),
		"terrain_quieting_bed": uses_shared_grounding,
		"placement_bed_model": "",
		"placement_bed_shape": "organic_footprint_clearing" if uses_shared_grounding else "",
		"placement_bed_alpha": _placement_bed_alpha(remembered) if uses_shared_grounding else 0.0,
		"placement_bed_terrain_tinted": uses_shared_grounding,
		"placement_bed_ui_plate": false,
		"procedural_fallback_grounding": uses_procedural_grounding,
		"procedural_grounding_model": OBJECT_PROCEDURAL_GROUNDING_MODEL if uses_procedural_grounding else "",
		"procedural_contact_disturbance": uses_procedural_grounding,
		"procedural_contact_disturbance_model": OBJECT_PROCEDURAL_DISTURBANCE_MODEL if uses_procedural_grounding else "",
		"procedural_contact_disturbance_alpha": (OBJECT_PROCEDURAL_DISTURBANCE_MEMORY_ALPHA if remembered else OBJECT_PROCEDURAL_DISTURBANCE_VISIBLE_ALPHA) if uses_procedural_grounding else 0.0,
		"mapped_sprite_grounding": uses_mapped_sprite_grounding,
		"mapped_sprite_grounding_model": OBJECT_MAPPED_SPRITE_GROUNDING_MODEL if uses_mapped_sprite_grounding else "",
		"mapped_sprite_contact_disturbance": uses_mapped_sprite_grounding,
		"mapped_sprite_contact_disturbance_model": OBJECT_MAPPED_SPRITE_DISTURBANCE_MODEL if uses_mapped_sprite_grounding else "",
		"mapped_sprite_contact_disturbance_alpha": (OBJECT_MAPPED_SPRITE_DISTURBANCE_MEMORY_ALPHA if remembered else OBJECT_MAPPED_SPRITE_DISTURBANCE_VISIBLE_ALPHA) if uses_mapped_sprite_grounding else 0.0,
		"shared_marker_plate": uses_shared_grounding,
		"upper_mass_backdrop": uses_shared_grounding,
		"upper_mass_backdrop_model": "",
		"upper_mass_backdrop_shape": "family_scaled_rear_wash" if uses_shared_grounding else "",
		"upper_mass_backdrop_alpha": (OBJECT_UPPER_BACKDROP_MEMORY.a if remembered else OBJECT_UPPER_BACKDROP_VISIBLE.a) if uses_shared_grounding else 0.0,
		"upper_mass_backdrop_position": "behind_upper_body" if uses_shared_grounding else "",
		"upper_mass_backdrop_height_fraction": (float(backdrop_metrics.get("height", 0.0)) / extent) if uses_shared_grounding and extent > 0.0 else 0.0,
		"upper_mass_backdrop_width_fraction": (float(backdrop_metrics.get("width", 0.0)) / extent) if uses_shared_grounding and extent > 0.0 else 0.0,
		"upper_mass_backdrop_ui_halo": false,
		"upper_mass_backdrop_ui_badge": false,
		"vertical_mass_shadow": uses_shared_grounding,
		"vertical_mass_shadow_model": "",
		"vertical_mass_shadow_alpha": (OBJECT_VERTICAL_MASS_SHADOW_MEMORY.a if remembered else OBJECT_VERTICAL_MASS_SHADOW_VISIBLE.a) if uses_shared_grounding else 0.0,
		"foreground_occlusion_lip": uses_shared_grounding,
		"procedural_contact_marks": uses_procedural_grounding,
		"occlusion_model": TOWN_GROUNDING_MODEL if uses_quiet_town_grounding else (HERO_GROUNDING_MODEL if uses_hero_grounding else (OBJECT_PROCEDURAL_OCCLUSION_MODEL if uses_procedural_grounding else (OBJECT_MAPPED_SPRITE_OCCLUSION_MODEL if uses_mapped_sprite_grounding else ""))),
		"depth_cue_model": TOWN_DEPTH_CUE_MODEL if uses_quiet_town_grounding else (HERO_DEPTH_CUE_MODEL if uses_hero_grounding else (OBJECT_PROCEDURAL_DEPTH_CUE_MODEL if uses_procedural_grounding else (OBJECT_MAPPED_SPRITE_DEPTH_CUE_MODEL if uses_mapped_sprite_grounding else ""))),
		"directional_contact_shadow": uses_shared_grounding,
		"localized_contact_shadow": uses_procedural_grounding or uses_mapped_sprite_grounding,
		"contact_shadow_model": OBJECT_PROCEDURAL_CONTACT_MODEL if uses_procedural_grounding else (OBJECT_MAPPED_SPRITE_CONTACT_MODEL if uses_mapped_sprite_grounding else ""),
		"contact_shadow_alpha": (OBJECT_PROCEDURAL_CONTACT_SHADOW_MEMORY.a if remembered else OBJECT_PROCEDURAL_CONTACT_SHADOW_VISIBLE.a) if uses_procedural_grounding else ((OBJECT_MAPPED_SPRITE_CONTACT_SHADOW_MEMORY.a if remembered else OBJECT_MAPPED_SPRITE_CONTACT_SHADOW_VISIBLE.a) if uses_mapped_sprite_grounding else 0.0),
		"base_occlusion_pads": uses_shared_grounding,
		"base_occlusion_model": "",
		"base_occlusion_alpha": (OBJECT_BASE_OCCLUSION_MEMORY.a if remembered else OBJECT_BASE_OCCLUSION_VISIBLE.a) if uses_shared_grounding else 0.0,
		"town_grounding_model": TOWN_GROUNDING_MODEL if uses_quiet_town_grounding else "",
		"town_footprint_cue_model": TOWN_FOOTPRINT_CUE_MODEL if uses_quiet_town_grounding else "",
		"town_base_ellipse": false if uses_quiet_town_grounding else null,
		"town_underlay": false if uses_quiet_town_grounding else null,
		"town_cast_shadow": false if uses_quiet_town_grounding else null,
		"town_contact_cue": uses_quiet_town_grounding,
		"town_remembered_treatment": "ghosted_sprite_without_echo_plate" if uses_quiet_town_grounding and remembered else "",
		"dominant_object_family": dominant_family,
		"footprint_width_tiles": dominant_footprint.x if has_presence else 0,
		"footprint_height_tiles": dominant_footprint.y if has_presence else 0,
		"footprint_anchor_width_fraction": anchor_half_width_fraction * 2.0 if has_presence else 0.0,
		"footprint_anchor_height_fraction": anchor_half_height_fraction * 2.0 if has_presence else 0.0,
		"procedural_world_silhouette": bool(art_payload.get("fallback_procedural_marker", false)),
		"mapped_sprite_settlement": uses_asset_sprite,
		"ui_badge_plate": false,
		"plate_radius_fraction": 0.0 if uses_procedural_grounding or uses_mapped_sprite_grounding else plate_radius_fraction,
		"plate_alpha": 0.0 if uses_quiet_town_grounding or uses_hero_grounding or uses_procedural_grounding or uses_mapped_sprite_grounding else (MARKER_PLATE_MEMORY.a if remembered else MARKER_PLATE_VISIBLE.a),
		"anchor_alpha": (OBJECT_PROCEDURAL_DISTURBANCE_MEMORY_ALPHA if remembered else OBJECT_PROCEDURAL_DISTURBANCE_VISIBLE_ALPHA) if uses_procedural_grounding else ((OBJECT_MAPPED_SPRITE_DISTURBANCE_MEMORY_ALPHA if remembered else OBJECT_MAPPED_SPRITE_DISTURBANCE_VISIBLE_ALPHA) if uses_mapped_sprite_grounding else (0.0 if uses_quiet_town_grounding or uses_hero_grounding else (MARKER_PLATE_MEMORY.a if remembered else MARKER_PLATE_VISIBLE.a))),
		"ring_alpha": 0.0 if uses_quiet_town_grounding or uses_hero_grounding or uses_procedural_grounding or uses_mapped_sprite_grounding else (MARKER_RING_MEMORY.a if remembered else MARKER_RING_VISIBLE.a),
		"outline_alpha": MEMORY_OBJECT_OUTLINE.a if remembered else MARKER_OUTLINE_COLOR.a,
		"grid_alpha": EXPLORED_TERRAIN_GRID_ALPHA,
		"visible_terrain_grid_alpha": EXPLORED_TERRAIN_GRID_ALPHA,
		"visible_terrain_grid_mode": EXPLORED_TERRAIN_GRID_MODE,
		"explored_intertile_seams": false,
		"unexplored_wireframe_alpha": UNEXPLORED_GRID_COLOR.a,
		"memory_echo": remembered and not uses_quiet_town_grounding and not uses_hero_grounding,
		"remembered_marker_alpha": MEMORY_OBJECT_COLOR.a if remembered else 0.0,
		"min_symbol_extent_fraction": min_symbol_fraction,
		"min_symbol_extent_px": min_symbol_fraction * extent,
		"hero_emphasis": has_visible_hero and tile == _hero_tile,
		"hero_symbol_extent_fraction": HERO_MARKER_RADIUS * 2.0 if has_visible_hero else 0.0,
		"hero_presence_model": HERO_PRESENCE_MODEL if has_visible_hero else "",
		"hero_anchor_shape": HERO_ANCHOR_STYLE if has_visible_hero else "",
		"hero_grounding_model": HERO_GROUNDING_MODEL if has_visible_hero else "",
		"hero_depth_cue_model": HERO_DEPTH_CUE_MODEL if has_visible_hero else "",
		"hero_world_figure": has_visible_hero,
		"hero_badge_plate": false if has_visible_hero else null,
		"hero_base_ellipse": false if has_visible_hero else null,
		"hero_terrain_quieting_bed": false if has_visible_hero else null,
		"hero_upper_mass_backdrop": false if has_visible_hero else null,
		"hero_shared_marker_plate": false if has_visible_hero else null,
		"hero_foot_contact_shadow": has_visible_hero,
		"hero_boot_occlusion": has_visible_hero,
		"hero_contact_shadow_alpha": HERO_CONTACT_SHADOW_VISIBLE.a if has_visible_hero else 0.0,
		"hero_boot_occlusion_alpha": HERO_BOOT_OCCLUSION_VISIBLE.a if has_visible_hero else 0.0,
		"hero_foot_anchor_width_fraction": hero_anchor_half_width_fraction * 2.0 if has_visible_hero else 0.0,
		"hero_foot_anchor_height_fraction": hero_anchor_half_height_fraction * 2.0 if has_visible_hero else 0.0,
		"hero_selection_ring_source": "tile_focus" if has_visible_hero else "",
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
	_terrain_art_transformed_textures.clear()
	_terrain_art_missing.clear()
	_road_overlay_art.clear()
	_homm3_prototype.clear()
	_homm3_terrain_id_map.clear()
	_homm3_terrain_families.clear()
	_homm3_bridge_classes.clear()
	_homm3_bridge_material_resolver.clear()
	_homm3_land_receiver_stamp_lookup.clear()
	_homm3_direct_bridge_pairs.clear()
	_homm3_routed_bridge_rules.clear()
	_homm3_road_overlays.clear()
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
	_load_homm3_prototype(grammar)
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

func _load_homm3_prototype(grammar: Dictionary) -> void:
	var prototype = grammar.get("homm3_local_prototype", {})
	if not (prototype is Dictionary):
		return
	_homm3_prototype = prototype
	var terrain_id_map = prototype.get("terrain_id_map", {})
	if terrain_id_map is Dictionary:
		for terrain_id in terrain_id_map.keys():
			var config = terrain_id_map.get(terrain_id, {})
			if config is Dictionary:
				_homm3_terrain_id_map[String(terrain_id).strip_edges().to_lower()] = config
	var terrain_families = prototype.get("terrain_families", {})
	if terrain_families is Dictionary:
		for family_id in terrain_families.keys():
			var family = terrain_families.get(family_id, {})
			if family is Dictionary:
				_homm3_terrain_families[String(family_id)] = family
	var bridge_classes = prototype.get("bridge_classes", {})
	if bridge_classes is Dictionary:
		for class_id in bridge_classes.keys():
			var bridge_class = bridge_classes.get(class_id, {})
			if bridge_class is Dictionary:
				_homm3_bridge_classes[String(class_id)] = bridge_class
	var bridge_material_resolver = prototype.get("bridge_material_resolver", {})
	if bridge_material_resolver is Dictionary:
		_homm3_bridge_material_resolver = bridge_material_resolver
	var land_receiver_stamp_lookup = prototype.get("land_receiver_stamp_lookup", {})
	if land_receiver_stamp_lookup is Dictionary:
		_homm3_land_receiver_stamp_lookup = land_receiver_stamp_lookup
	var direct_bridge_pairs = prototype.get("direct_bridge_pairs", [])
	if direct_bridge_pairs is Array:
		for pair_value in direct_bridge_pairs:
			if not (pair_value is Dictionary):
				continue
			var pair: Dictionary = pair_value
			var families = pair.get("families", [])
			if not (families is Array) or families.size() != 2:
				continue
			var first_family := String(families[0]).strip_edges()
			var second_family := String(families[1]).strip_edges()
			if first_family == "" or second_family == "":
				continue
			_homm3_direct_bridge_pairs["%s|%s" % [first_family, second_family]] = pair
			_homm3_direct_bridge_pairs["%s|%s" % [second_family, first_family]] = pair
	var routed_bridge_rules = prototype.get("routed_bridge_rules", [])
	if routed_bridge_rules is Array:
		for rule_value in routed_bridge_rules:
			if not (rule_value is Dictionary):
				continue
			var rule: Dictionary = rule_value
			var families = rule.get("families", [])
			if not (families is Array) or families.size() != 2:
				continue
			var first_family := String(families[0]).strip_edges()
			var second_family := String(families[1]).strip_edges()
			if first_family == "" or second_family == "":
				continue
			_homm3_routed_bridge_rules["%s|%s" % [first_family, second_family]] = rule
			_homm3_routed_bridge_rules["%s|%s" % [second_family, first_family]] = rule
	var road_overlays = prototype.get("road_overlays", {})
	if road_overlays is Dictionary:
		for overlay_id in road_overlays.keys():
			var overlay = road_overlays.get(overlay_id, {})
			if overlay is Dictionary:
				_homm3_road_overlays[String(overlay_id)] = overlay

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
	var connection_pieces = tile_art.get("connection_pieces", {})
	var normalized_connection_pieces := {}
	if connection_pieces is Dictionary:
		for connection_key in ["NE+SW", "NW+SE"]:
			var piece_path := String(connection_pieces.get(connection_key, "")).strip_edges()
			if piece_path != "":
				normalized_connection_pieces[connection_key] = piece_path
	var normalized := {}
	if center_path != "":
		normalized["center"] = center_path
	if not normalized_connectors.is_empty():
		normalized["connectors"] = normalized_connectors
	if not normalized_connection_pieces.is_empty():
		normalized["connection_pieces"] = normalized_connection_pieces
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
	if not _homm3_terrain_config(terrain_id).is_empty():
		return TERRAIN_HOMM3_SOURCE_BASIS
	var style := _terrain_style(terrain_id)
	var tile_art = style.get("tile_art", {})
	if tile_art is Dictionary and String(tile_art.get("source_basis", "")).strip_edges() != "":
		return String(tile_art.get("source_basis", "")).strip_edges()
	var grammar_basis := String(_terrain_grammar.get("primary_base_model", "")).strip_edges()
	if grammar_basis == TERRAIN_ORIGINAL_TILE_BANK_RENDERING_MODE:
		return "original_procedural_reference_informed"
	return grammar_basis

func _terrain_art_can_be_primary(terrain_id: String) -> bool:
	if not _homm3_terrain_config(terrain_id).is_empty():
		return true
	var source_basis := _terrain_tile_art_source_basis(terrain_id)
	if source_basis == "" or source_basis == TERRAIN_DEPRECATED_GENERATED_SOURCE_BASIS:
		return false
	if source_basis.find("generated") >= 0:
		return false
	return source_basis.find("original") >= 0 or String(_terrain_grammar.get("primary_base_model", "")) == TERRAIN_ORIGINAL_TILE_BANK_RENDERING_MODE

func _road_overlay_art_source_basis(overlay_id: String) -> String:
	if _homm3_road_overlays.has(overlay_id):
		return TERRAIN_HOMM3_SOURCE_BASIS
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
	if _homm3_road_overlays.has(overlay_id):
		return true
	var source_basis := _road_overlay_art_source_basis(overlay_id)
	return source_basis != "" and source_basis != TERRAIN_DEPRECATED_GENERATED_SOURCE_BASIS and source_basis.find("generated") < 0

func _terrain_base_art_entry(terrain_id: String, tile: Vector2i) -> Dictionary:
	var homm3_entry := _homm3_terrain_art_entry(terrain_id, tile)
	if not homm3_entry.is_empty():
		return homm3_entry
	var entries = _terrain_base_art.get(terrain_id.strip_edges().to_lower(), [])
	if not (entries is Array) or entries.is_empty():
		return {}
	var index := _deterministic_art_index(tile, terrain_id, entries.size())
	var entry = entries[index]
	return entry if entry is Dictionary else {}

func _deterministic_art_index(tile: Vector2i, terrain_id: String, count: int) -> int:
	if count <= 0:
		return 0
	var patch := Vector2i(floori(float(tile.x) / 3.0), floori(float(tile.y) / 3.0))
	var seed: int = abs((patch.x * 73) + (patch.y * 151) + (terrain_id.hash() * 19))
	return seed % count

func _terrain_edge_art_path(terrain_id: String, direction: String) -> String:
	var edge_paths = _terrain_edge_art.get(terrain_id.strip_edges().to_lower(), {})
	if not (edge_paths is Dictionary):
		return ""
	return String(edge_paths.get(direction, ""))

func _road_overlay_art_paths(overlay_id: String) -> Dictionary:
	var art = _road_overlay_art.get(overlay_id, {})
	return art if art is Dictionary else {}

func _homm3_road_art_path(overlay_id: String, tile: Vector2i) -> String:
	var overlay = _homm3_road_overlays.get(overlay_id, {})
	if not (overlay is Dictionary):
		return ""
	var atlas_id := String(overlay.get("atlas", "")).strip_edges()
	if atlas_id == "":
		return ""
	var lookup = overlay.get("mask_lookup", {})
	if not (lookup is Dictionary):
		return ""
	var mask_key := _road_connection_key(tile)
	var frame_id := String(lookup.get(mask_key, "")).strip_edges()
	if frame_id == "":
		return ""
	return "%s/roads/%s/%s.png" % [_homm3_asset_root(), atlas_id, frame_id]

func _homm3_asset_root() -> String:
	return String(_homm3_prototype.get("asset_root", "res://art/overworld/runtime/homm3_local_prototype")).strip_edges()

func _homm3_terrain_config(terrain_id: String) -> Dictionary:
	var config = _homm3_terrain_id_map.get(terrain_id.strip_edges().to_lower(), {})
	return config if config is Dictionary else {}

func _homm3_terrain_family_config(family_id: String) -> Dictionary:
	var family = _homm3_terrain_families.get(family_id, {})
	return family if family is Dictionary else {}

func _homm3_receiver_family_payload(terrain_id: String, config: Dictionary, family_id: String, family: Dictionary) -> Dictionary:
	var atlas_role := _homm3_family_atlas_role(family)
	var special_system := _homm3_family_special_system(family)
	var preferred_bridge_family := _homm3_receiver_bridge_family(config, family)
	return {
		"logical_terrain_id": terrain_id,
		"renderer_family": family_id,
		"atlas_role": atlas_role,
		"atlas_role_source_level": String(family.get("atlas_role_source_level", "fact")),
		"special_system": special_system,
		"special_system_flag": special_system != "",
		"preferred_bridge_class": String(family.get("preferred_bridge_class", config.get("preferred_bridge_class", ""))).strip_edges(),
		"preferred_bridge_family": preferred_bridge_family,
		"preferred_bridge_source_level": String(family.get("preferred_bridge_source_level", config.get("bridge_family_source_level", ""))).strip_edges(),
		"bridge_material_class": String(family.get("bridge_material_class", "")).strip_edges(),
		"allows_generic_land_edge_masks": _homm3_family_uses_generic_land_edge_masks(family),
		"provisional_fallback_policy": String(family.get("provisional_fallback_policy", config.get("provisional_fallback_policy", ""))).strip_edges(),
		"unresolved_fallback_policy": String(family.get("unresolved_fallback_policy", config.get("unresolved_fallback_policy", ""))).strip_edges(),
	}

func _homm3_family_atlas_role(family: Dictionary) -> String:
	var atlas_role := String(family.get("atlas_role", "")).strip_edges()
	return atlas_role if atlas_role != "" else "full_receiver_land"

func _homm3_family_special_system(family: Dictionary) -> String:
	return String(family.get("special_system", "")).strip_edges()

func _homm3_family_uses_generic_land_edge_masks(family: Dictionary) -> bool:
	if family.has("uses_generic_land_edge_masks"):
		return bool(family.get("uses_generic_land_edge_masks", false))
	var atlas_role := _homm3_family_atlas_role(family)
	return atlas_role in ["full_receiver_land", "reduced_bridge_receiver"]

func _homm3_is_water_system(family: Dictionary) -> bool:
	return _homm3_family_special_system(family) == "water_shoreline" or bool(family.get("shoreline_specific", false))

func _homm3_is_rock_system(family: Dictionary) -> bool:
	return _homm3_family_special_system(family) == "rock_void_cliff"

func _homm3_uses_land_receiver_stamp_tables(family: Dictionary) -> bool:
	if family.has("uses_land_receiver_stamp_tables"):
		return bool(family.get("uses_land_receiver_stamp_tables", false))
	return _homm3_family_atlas_role(family) == "full_receiver_land"

func _homm3_receiver_bridge_family(config: Dictionary, family: Dictionary) -> String:
	var config_family := String(config.get("bridge_family", "")).strip_edges()
	if config_family != "":
		return config_family
	var preferred_family := String(family.get("preferred_bridge_family", "")).strip_edges()
	if preferred_family != "":
		return preferred_family
	return String(family.get("bridge_family", "")).strip_edges()

func _homm3_bridge_material_resolver_model() -> String:
	var model := String(_homm3_bridge_material_resolver.get("resolver_model", "")).strip_edges()
	return model if model != "" else "legacy_inline_bridge_resolution"

func _homm3_bridge_class_for_family(bridge_family: String, receiver_family_config: Dictionary) -> String:
	var normalized_family := bridge_family.strip_edges()
	for class_id in _homm3_bridge_classes.keys():
		var bridge_class = _homm3_bridge_classes.get(class_id, {})
		if not (bridge_class is Dictionary):
			continue
		if String(bridge_class.get("renderer_bridge_family", "")).strip_edges() == normalized_family:
			return String(class_id).strip_edges()
	return String(receiver_family_config.get("preferred_bridge_class", "")).strip_edges()

func _homm3_bridge_material_rules(rule_key: String) -> Array:
	var rules = _homm3_bridge_material_resolver.get(rule_key, [])
	return rules if rules is Array else []

func _homm3_bridge_material_rule_for(
	rule_key: String,
	receiver_family: String,
	receiver_atlas_role: String,
	source_family: String,
	source_atlas_role: String
) -> Dictionary:
	for rule_value in _homm3_bridge_material_rules(rule_key):
		if not (rule_value is Dictionary):
			continue
		var rule: Dictionary = rule_value
		if _homm3_bridge_material_rule_matches(rule, receiver_family, receiver_atlas_role, source_family, source_atlas_role):
			return rule
	return {}

func _homm3_bridge_material_rule_matches(
	rule: Dictionary,
	receiver_family: String,
	receiver_atlas_role: String,
	source_family: String,
	source_atlas_role: String
) -> bool:
	var excluded_receiver_families = rule.get("exclude_receiver_families", [])
	if excluded_receiver_families is Array and receiver_family in excluded_receiver_families:
		return false
	var excluded_source_families = rule.get("exclude_source_families", [])
	if excluded_source_families is Array and source_family in excluded_source_families:
		return false
	var exact_receiver_family := String(rule.get("receiver_family", "")).strip_edges()
	if exact_receiver_family != "" and exact_receiver_family != receiver_family:
		return false
	var exact_source_family := String(rule.get("source_family", "")).strip_edges()
	if exact_source_family != "" and exact_source_family != source_family:
		return false
	var receiver_families = rule.get("receiver_families", [])
	if receiver_families is Array and not receiver_families.is_empty() and not receiver_families.has(receiver_family):
		return false
	var source_families = rule.get("source_families", [])
	if source_families is Array and not source_families.is_empty() and not source_families.has(source_family):
		return false
	var exact_receiver_role := String(rule.get("receiver_atlas_role", "")).strip_edges()
	if exact_receiver_role != "" and exact_receiver_role != receiver_atlas_role:
		return false
	var exact_source_role := String(rule.get("source_atlas_role", "")).strip_edges()
	if exact_source_role != "" and exact_source_role != source_atlas_role:
		return false
	return true

func _homm3_bridge_resolution_from_rule(
	rule: Dictionary,
	receiver_family_config: Dictionary,
	default_bridge_family: String,
	default_bridge_source_kind: String,
	default_bridge_resolution_model: String,
	default_bridge_source_level: String
) -> Dictionary:
	var bridge_family := String(rule.get("bridge_family", default_bridge_family)).strip_edges()
	if bridge_family == "":
		bridge_family = default_bridge_family
	var bridge_class := String(rule.get("bridge_class", "")).strip_edges()
	if bridge_class == "":
		bridge_class = _homm3_bridge_class_for_family(bridge_family, receiver_family_config)
	var bridge_source_level := String(rule.get("source_level", default_bridge_source_level)).strip_edges()
	return {
		"bridge_family": bridge_family,
		"bridge_class": bridge_class,
		"bridge_resolution_model": String(rule.get("selection_model", default_bridge_resolution_model)).strip_edges(),
		"bridge_resolver_model": _homm3_bridge_material_resolver_model(),
		"bridge_source_kind": String(rule.get("bridge_source_kind", default_bridge_source_kind)).strip_edges(),
		"bridge_source_level": bridge_source_level,
		"bridge_rule_id": String(rule.get("id", "")).strip_edges(),
		"bridge_target_frame_block": String(rule.get("target_frame_block", "")).strip_edges(),
		"bridge_policy_provisional": bool(rule.get("provisional", false)) or bridge_source_level == "provisional",
	}

func _homm3_bridge_material_resolution(
	receiver_config: Dictionary,
	receiver_family_config: Dictionary,
	receiver_family: String,
	neighbor_family_config: Dictionary,
	neighbor_family: String
) -> Dictionary:
	var receiver_atlas_role := _homm3_family_atlas_role(receiver_family_config)
	var neighbor_atlas_role := _homm3_family_atlas_role(neighbor_family_config)
	var receiver_is_water := _homm3_is_water_system(receiver_family_config)
	var default_bridge_family := _homm3_receiver_bridge_family(receiver_config, receiver_family_config)
	var default_bridge_class := _homm3_bridge_class_for_family(default_bridge_family, receiver_family_config)
	var default_source_level := String(receiver_family_config.get("preferred_bridge_source_level", receiver_config.get("bridge_family_source_level", ""))).strip_edges()
	var default_source_kind := "unresolved_fallback" if String(receiver_family_config.get("preferred_bridge_class", "")).strip_edges() == "unresolved" or default_source_level == "provisional" else "preferred_bridge_class"
	var default_model := "receiver_bridge_family_default"
	if not receiver_is_water:
		var direct_bridge_pair := _homm3_direct_bridge_pair(receiver_family, neighbor_family)
		if not direct_bridge_pair.is_empty():
			var direct_resolution := _homm3_bridge_resolution_from_rule(
				direct_bridge_pair,
				receiver_family_config,
				default_bridge_family,
				"direct_bridge_material",
				"direct_family_pair_lookup",
				default_source_level
			)
			direct_resolution["uses_direct_bridge_pair"] = true
			return direct_resolution
		var direct_contact := _homm3_bridge_material_rule_for("direct_bridge_material_contacts", receiver_family, receiver_atlas_role, neighbor_family, neighbor_atlas_role)
		if not direct_contact.is_empty():
			var contact_resolution := _homm3_bridge_resolution_from_rule(
				direct_contact,
				receiver_family_config,
				default_bridge_family,
				"direct_bridge_material",
				"direct_bridge_material_contact_lookup",
				default_source_level
			)
			contact_resolution["uses_direct_bridge_material_contact"] = true
			return contact_resolution
		var routed_bridge_rule := _homm3_routed_bridge_rule(receiver_family, neighbor_family)
		if not routed_bridge_rule.is_empty():
			var routed_resolution := _homm3_bridge_resolution_from_rule(
				routed_bridge_rule,
				receiver_family_config,
				default_bridge_family,
				"routed_bridge",
				"routed_bridge_lookup",
				default_source_level
			)
			routed_resolution["uses_routed_bridge_rule"] = true
			return routed_resolution
	var unresolved_fallback := _homm3_bridge_material_rule_for("unresolved_fallbacks", receiver_family, receiver_atlas_role, neighbor_family, neighbor_atlas_role)
	if not unresolved_fallback.is_empty():
		return _homm3_bridge_resolution_from_rule(unresolved_fallback, receiver_family_config, default_bridge_family, "unresolved_fallback", "unresolved_bridge_class_fallback", default_source_level)
	var preferred_route := _homm3_bridge_material_rule_for("preferred_bridge_class_routes", receiver_family, receiver_atlas_role, neighbor_family, neighbor_atlas_role)
	if not preferred_route.is_empty():
		return _homm3_bridge_resolution_from_rule(preferred_route, receiver_family_config, default_bridge_family, "preferred_bridge_class", "receiver_preferred_bridge_class_lookup", default_source_level)
	return {
		"bridge_family": default_bridge_family,
		"bridge_class": default_bridge_class,
		"bridge_resolution_model": default_model,
		"bridge_resolver_model": _homm3_bridge_material_resolver_model(),
		"bridge_source_kind": default_source_kind,
		"bridge_source_level": default_source_level,
		"bridge_rule_id": "",
		"bridge_target_frame_block": "",
		"bridge_policy_provisional": default_source_level == "provisional" or default_source_kind == "unresolved_fallback",
	}

func _homm3_frame_block_payload(family: Dictionary, block_id: String) -> Dictionary:
	var blocks = family.get("frame_blocks", {})
	if not (blocks is Dictionary) or block_id == "":
		return {}
	var block = blocks.get(block_id, {})
	if not (block is Dictionary):
		return {}
	return block

func _homm3_selected_frame_block_id(selection_kind: String, relation: Dictionary, family: Dictionary) -> String:
	var resolver_target_block := String(relation.get("bridge_target_frame_block", "")).strip_edges()
	if resolver_target_block != "":
		return resolver_target_block
	var stamp_target_block := String(relation.get("stamp_target_frame_block", "")).strip_edges()
	if stamp_target_block != "":
		return stamp_target_block
	match selection_kind:
		"water_shoreline":
			return "shoreline_frames"
		"rock_system":
			return "rock_light_ground_context"
		"bridge_material_base_context":
			return "base_context_provisional"
		"propagated_transition":
			return "native_to_sand_transition"
		"bridge_transition":
			var bridge_family := String(relation.get("bridge_family", "")).strip_edges()
			if bridge_family == "sand":
				if _homm3_family_atlas_role(family) == "reduced_bridge_receiver":
					return "dirt_to_sand_transition"
				return "native_to_sand_transition"
			if bridge_family == "dirt":
				if _homm3_family_atlas_role(family) == "reduced_bridge_receiver":
					return "dirt_receiver_transition"
				return "native_to_dirt_transition"
		"corner_transition":
			return "mixed_junction_reserved"
	return String(family.get("interior_frame_block", "native_interiors")).strip_edges()

func _homm3_selection_kind_from_visual_selection(visual_selection: Dictionary, family: Dictionary) -> String:
	var shape_class := int(visual_selection.get("shape_class", 0))
	if shape_class == 0:
		return "interior"
	if _homm3_is_water_system(family):
		return "water_shoreline"
	if _homm3_is_rock_system(family):
		return "rock_system"
	return "bridge_transition"

func _homm3_editor_restamp_behavior() -> Dictionary:
	var behavior = _homm3_land_receiver_stamp_lookup.get("editor_restamp_behavior", {})
	return behavior if behavior is Dictionary else {}

func _homm3_editor_restamp_model() -> String:
	var behavior := _homm3_editor_restamp_behavior()
	var model := String(behavior.get("model", "")).strip_edges()
	return model if model != "" else TERRAIN_EDITOR_RESTAMP_MODEL

func _homm3_editor_restamp_scope() -> String:
	var behavior := _homm3_editor_restamp_behavior()
	var scope := String(behavior.get("scope", "")).strip_edges()
	return scope if scope != "" else TERRAIN_EDITOR_RESTAMP_SCOPE

func _homm3_editor_restamp_source_level() -> String:
	var behavior := _homm3_editor_restamp_behavior()
	return String(behavior.get("source_level", "")).strip_edges()

func _homm3_editor_restamp_renderer_evaluation_model() -> String:
	var behavior := _homm3_editor_restamp_behavior()
	return String(behavior.get("renderer_evaluation_model", "")).strip_edges()

func _homm3_editor_restamp_logical_map_write_model() -> String:
	var behavior := _homm3_editor_restamp_behavior()
	return String(behavior.get("logical_map_write_model", "")).strip_edges()

func _homm3_editor_restamp_offset_entries() -> Array:
	var behavior := _homm3_editor_restamp_behavior()
	var raw_offsets = behavior.get("known_receiver_offsets_from_single_paint", [])
	if not (raw_offsets is Array) or raw_offsets.is_empty():
		raw_offsets = _homm3_land_receiver_stamp_lookup.get("known_changed_offsets_from_single_paint", [])
	var entries := []
	if not (raw_offsets is Array):
		return entries
	for offset_value in raw_offsets:
		if not (offset_value is Dictionary):
			continue
		var offset_dict = offset_value.get("offset_from_painted_tile", {})
		if not (offset_dict is Dictionary):
			continue
		var offset := Vector2i(int(offset_dict.get("x", 0)), int(offset_dict.get("y", 0)))
		var direction := String(offset_value.get("direction", "")).strip_edges()
		if direction == "":
			direction = _homm3_direction_from_offset(offset)
		if direction == "":
			continue
		entries.append({
			"direction": direction,
			"role": String(offset_value.get("role", "known_receiver_restamped_by_single_paint")),
			"offset": offset,
		})
	return entries

func _homm3_editor_restamp_payload(painted_tile: Vector2i) -> Dictionary:
	var behavior := _homm3_editor_restamp_behavior()
	var offset_entries := _homm3_editor_restamp_offset_entries()
	var restamp_tiles := []
	restamp_tiles.append(_homm3_editor_restamp_tile_payload(painted_tile, Vector2i.ZERO, "SELF", "painted_source_tile", 0))
	var known_receiver_offsets := []
	var order_index := 1
	var in_bounds_receiver_count := 0
	for entry_value in offset_entries:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		var offset: Vector2i = entry.get("offset", Vector2i.ZERO)
		var direction := String(entry.get("direction", ""))
		var receiver_payload := _homm3_editor_restamp_tile_payload(
			painted_tile,
			offset,
			direction,
			String(entry.get("role", "known_receiver_restamped_by_single_paint")),
			order_index
		)
		restamp_tiles.append(receiver_payload)
		known_receiver_offsets.append({
			"direction": direction,
			"offset_from_painted_tile": _vector2i_payload(offset),
			"receiver_tile": receiver_payload.get("tile", {}),
			"source_offset_from_receiver": receiver_payload.get("expected_stamp_source_offset", {}),
		})
		if bool(receiver_payload.get("in_bounds", false)):
			in_bounds_receiver_count += 1
		order_index += 1
	return {
		"enabled": not behavior.is_empty(),
		"model": _homm3_editor_restamp_model(),
		"source_level": _homm3_editor_restamp_source_level(),
		"paint_order_source_level": String(behavior.get("paint_order_source_level", "")),
		"scope": _homm3_editor_restamp_scope(),
		"logical_map_write_model": _homm3_editor_restamp_logical_map_write_model(),
		"renderer_evaluation_model": _homm3_editor_restamp_renderer_evaluation_model(),
		"restamp_anchor": String(behavior.get("restamp_anchor", "painted_source_tile")),
		"known_receiver_offsets_source_level": String(behavior.get("known_receiver_offsets_source_level", _homm3_land_receiver_stamp_lookup.get("known_changed_offsets_source_level", ""))),
		"unknown_offsets_policy": String(behavior.get("unknown_offsets_policy", "")),
		"restamp_payload_model": String(behavior.get("restamp_payload_model", "")),
		"paint_history_model": String(_homm3_land_receiver_stamp_lookup.get("array_reconstruction_mode", "")),
		"painted_tile": _vector2i_payload(painted_tile),
		"known_receiver_offsets": known_receiver_offsets,
		"known_receiver_count": known_receiver_offsets.size(),
		"in_bounds_receiver_count": in_bounds_receiver_count,
		"affected_tile_count": restamp_tiles.size(),
		"affected_tiles": restamp_tiles,
		"mixed_junction_policy": String(_homm3_land_receiver_stamp_lookup.get("mixed_junction_policy", "")),
		"reserved_mixed_junction_frame_ranges": _homm3_land_receiver_stamp_lookup.get("reserved_mixed_junction_frame_ranges", []),
		"uses_shared_overworld_map_view": true,
		"gameplay_pathing_unchanged": true,
		"save_schema_unchanged": true,
		"object_logic_unchanged": true,
	}

func _homm3_editor_restamp_tile_payload(
	painted_tile: Vector2i,
	offset_from_painted_tile: Vector2i,
	direction_from_painted_tile: String,
	role: String,
	order_index: int
) -> Dictionary:
	var tile := painted_tile + offset_from_painted_tile
	var in_bounds := _tile_in_bounds(tile)
	var explored := in_bounds and _session != null and OverworldRulesScript.is_tile_explored(_session, tile.x, tile.y)
	var visible := in_bounds and _session != null and OverworldRulesScript.is_tile_visible(_session, tile.x, tile.y)
	var terrain_payload := _terrain_visual_payload(tile, explored, visible) if in_bounds else {}
	var expected_source_offset := painted_tile - tile
	return {
		"role": role,
		"restamp_order_index": order_index,
		"direction_from_painted_tile": direction_from_painted_tile,
		"offset_from_painted_tile": _vector2i_payload(offset_from_painted_tile),
		"tile": _vector2i_payload(tile),
		"in_bounds": in_bounds,
		"explored": explored,
		"visible": visible,
		"expected_stamp_source_offset": _vector2i_payload(expected_source_offset),
		"expected_stamp_source_direction": _homm3_direction_from_offset(expected_source_offset),
		"stamp_source_matches_painted_tile": role != "painted_source_tile" and _homm3_stamp_source_matches_offset(terrain_payload, expected_source_offset),
		"terrain_presentation": terrain_payload,
	}

func _homm3_stamp_source_matches_offset(terrain_payload: Dictionary, expected_source_offset: Vector2i) -> bool:
	var source_offset = terrain_payload.get("homm3_stamp_source_offset", {})
	if not (source_offset is Dictionary):
		return false
	return int(source_offset.get("x", 999999)) == expected_source_offset.x and int(source_offset.get("y", 999999)) == expected_source_offset.y

func _vector2i_payload(value: Vector2i) -> Dictionary:
	return {"x": value.x, "y": value.y}

func _homm3_terrain_art_entry(terrain_id: String, tile: Vector2i) -> Dictionary:
	var selection := _homm3_terrain_selection_payload(tile, terrain_id)
	var frame_id := String(selection.get("frame_id", "")).strip_edges()
	var atlas_id := String(selection.get("atlas_id", "")).strip_edges()
	if atlas_id == "" or frame_id == "":
		return {}
	var path := "%s/terrain/%s/%s.png" % [_homm3_asset_root(), atlas_id, frame_id]
	return {
		"variant_key": "homm3_%s_%s" % [atlas_id, frame_id],
		"path": path,
		"source_basis": TERRAIN_HOMM3_SOURCE_BASIS,
		"homm3_selection": selection,
		"flip_h": bool(selection.get("flip_h", false)),
		"flip_v": bool(selection.get("flip_v", false)),
	}

func _homm3_terrain_selection_payload(tile: Vector2i, terrain_id: String) -> Dictionary:
	var config := _homm3_terrain_config(terrain_id)
	if config.is_empty():
		return {}
	var family_id := String(config.get("family", "")).strip_edges()
	var family := _homm3_terrain_family_config(family_id)
	if family.is_empty():
		return {}
	var atlas_id := String(family.get("atlas", "")).strip_edges()
	var receiver_payload := _homm3_receiver_family_payload(terrain_id, config, family_id, family)
	var visual_selection: Dictionary = TerrainPlacementRulesScript.visual_selection_payload(_map_data, _map_size, _terrain_grammar, tile)
	if visual_selection.is_empty():
		return {}
	var relation := _homm3_terrain_relation_payload(tile, terrain_id)
	var selection_kind := _homm3_selection_kind_from_visual_selection(visual_selection, family)
	var mask_key := String(relation.get("mask_key", ""))
	var corner_mask := String(relation.get("corner_mask", ""))
	var frame_id := String(visual_selection.get("frame_id", "")).strip_edges()
	var fallback_reason := String(visual_selection.get("fallback_reason", ""))
	var corner_lookup := false
	var corner_lookup_model := ""
	var flip_h := bool(visual_selection.get("flip_h", false))
	var flip_v := bool(visual_selection.get("flip_v", false))
	if frame_id == "":
		frame_id = _homm3_interior_frame(family, tile, terrain_id)
	var selected_frame_block_id := String(visual_selection.get("selected_frame_block", "")).strip_edges()
	if selected_frame_block_id == "":
		selected_frame_block_id = _homm3_selected_frame_block_id(selection_kind, relation, family)
	var selected_frame_block := _homm3_frame_block_payload(family, selected_frame_block_id)
	var bridge_family := String(visual_selection.get("bridge_family", relation.get("bridge_family", config.get("bridge_family", family.get("bridge_family", ""))))).strip_edges()
	var bridge_class := _homm3_bridge_class_for_family(bridge_family, family) if bridge_family != "" and bridge_family != "mixed" else bridge_family
	return {
		"enabled": true,
		"local_reference_only": bool(_homm3_prototype.get("local_reference_only", true)),
		"terrain_lookup_model": String(_homm3_prototype.get("terrain_lookup_model", "accepted_web_prototype_relation_class_row_lookup")),
		"unsupported_policy": String(_homm3_prototype.get("unsupported_policy", TERRAIN_HOMM3_UNSUPPORTED_POLICY)),
		"terrain": terrain_id,
		"logical_terrain_id": String(receiver_payload.get("logical_terrain_id", terrain_id)),
		"family": family_id,
		"renderer_family": String(receiver_payload.get("renderer_family", family_id)),
		"atlas_id": atlas_id,
		"atlas_role": String(receiver_payload.get("atlas_role", "")),
		"atlas_role_source_level": String(receiver_payload.get("atlas_role_source_level", "")),
		"special_system": String(receiver_payload.get("special_system", "")),
		"special_system_flag": bool(receiver_payload.get("special_system_flag", false)),
		"allows_generic_land_edge_masks": bool(receiver_payload.get("allows_generic_land_edge_masks", false)),
		"uses_land_receiver_stamp_tables": _homm3_uses_land_receiver_stamp_tables(family),
		"preferred_bridge_class": String(receiver_payload.get("preferred_bridge_class", "")),
		"preferred_bridge_family": String(receiver_payload.get("preferred_bridge_family", "")),
		"preferred_bridge_source_level": String(receiver_payload.get("preferred_bridge_source_level", "")),
		"bridge_material_class": String(receiver_payload.get("bridge_material_class", "")),
		"frame_id": frame_id,
		"selected_frame_block": selected_frame_block_id,
		"selected_frame_block_range": String(selected_frame_block.get("range", "")),
		"selected_frame_block_source_level": String(selected_frame_block.get("source_level", "")),
		"selected_frame_block_role": String(selected_frame_block.get("role", "")),
		"selection_kind": selection_kind,
		"mask_key": mask_key,
		"visual_selection_model": String(visual_selection.get("selection_model", "")),
		"visual_frame_selection_source": String(visual_selection.get("frame_selection_source", "")),
		"final_normalization_model": String(visual_selection.get("final_normalization_model", "")),
		"owner_id": int(visual_selection.get("owner_id", -1)),
		"shape_class": int(visual_selection.get("shape_class", 0)),
		"class_topology": String(visual_selection.get("class_topology", "")),
		"class_reason": String(visual_selection.get("class_reason", "")),
		"class_correction": String(visual_selection.get("correction", "")),
		"boundary_count": int(visual_selection.get("boundary_count", 0)),
		"relation_ring": visual_selection.get("relation_ring", []),
		"relation_grid": String(visual_selection.get("relation_grid", "")),
		"projection_model": String(visual_selection.get("projection_model", "")),
		"raw_quadrants": visual_selection.get("raw_quadrants", []),
		"owner_footprint_quadrants": visual_selection.get("owner_footprint_quadrants", []),
		"material_quadrants": visual_selection.get("material_quadrants", []),
		"count_quadrants": visual_selection.get("count_quadrants", []),
		"normalized_quadrants": visual_selection.get("normalized_quadrants", []),
		"visual_quadrants": visual_selection.get("visual_quadrants", []),
		"display_quadrants": visual_selection.get("display_quadrants", []),
		"row_group": String(visual_selection.get("row_group", "")),
		"row_source": String(visual_selection.get("row_source", "")),
		"row_table": String(visual_selection.get("row_table", "")),
		"requested_flag_a": int(visual_selection.get("requested_flag_a", 0)),
		"requested_flag_b": int(visual_selection.get("requested_flag_b", 0)),
		"selected_flag_a": int(visual_selection.get("flag_a", 0)),
		"selected_flag_b": int(visual_selection.get("flag_b", 0)),
		"bridge_family": bridge_family,
		"bridge_class": bridge_class,
		"bridge_resolution_model": "accepted_web_relation_function",
		"bridge_resolver_model": String(visual_selection.get("selection_model", "")),
		"bridge_source_kind": "relation_class_%s" % bridge_family if bridge_family != "" else "",
		"bridge_source_level": "fact",
		"bridge_rule_id": "",
		"bridge_target_frame_block": selected_frame_block_id,
		"bridge_policy_provisional": false,
		"stamp_lookup_model": "",
		"stamp_selection_model": "",
		"stamp_table_id": "",
		"stamp_anchor": "",
		"stamp_source_kind": "",
		"stamp_source_direction": "",
		"stamp_source_offset": {},
		"stamp_selected_frame": "",
		"stamp_transform": "",
		"stamp_flip_h": false,
		"stamp_flip_v": false,
		"stamp_source_level": "",
		"stamp_mapping_source_level": "",
		"stamp_frame_range_source_level": "",
		"stamp_frame_range": "",
		"stamp_target_frame_block": "",
		"stamp_bridge_family": "",
		"stamp_bridge_class": "",
		"stamp_source_offset_model": "",
		"stamp_array_reconstruction_mode": "",
		"stamp_mixed_junction_reserved": false,
		"stamp_mixed_junction_policy": "",
		"stamp_reserved_mixed_junction_frame_ranges": [],
		"web_prototype_selection_model": String(visual_selection.get("selection_model", "")),
		"web_prototype_shape_class": int(visual_selection.get("shape_class", 0)),
		"web_prototype_class_topology": String(visual_selection.get("class_topology", "")),
		"web_prototype_class_reason": String(visual_selection.get("class_reason", "")),
		"web_prototype_correction": String(visual_selection.get("correction", "")),
		"web_prototype_relation_grid": String(visual_selection.get("relation_grid", "")),
		"web_prototype_row_group": String(visual_selection.get("row_group", "")),
		"web_prototype_flag_a": int(visual_selection.get("flag_a", 0)),
		"web_prototype_flag_b": int(visual_selection.get("flag_b", 0)),
		"web_prototype_fallback": bool(visual_selection.get("fallback", false)),
		"web_prototype_direct_water_rock_contact": bool(visual_selection.get("direct_water_rock_contact", false)),
		"direct_bridge_material_contact": false,
		"preferred_bridge_class_used": false,
		"shoreline_specific": bool(family.get("shoreline_specific", false)),
		"water_bridge_class": String(receiver_payload.get("preferred_bridge_class", "")) if _homm3_is_water_system(family) else "",
		"rock_system": String(receiver_payload.get("special_system", "")) if _homm3_is_rock_system(family) else "",
		"rock_ground_context": String(relation.get("rock_ground_context", "")),
		"receiver_transition_policy": String(relation.get("receiver_transition_policy", family.get("receiver_transition_policy", ""))),
		"corner_lookup": corner_lookup,
		"corner_lookup_model": corner_lookup_model,
		"flip": _homm3_flip_key(flip_h, flip_v),
		"flip_h": flip_h,
		"flip_v": flip_v,
		"interior_frame_selection": _homm3_interior_frame_selection_model(),
		"interior_frame_count": _homm3_interior_frame_count(family),
		"uses_interior_variant_cycle": false,
		"propagated_transition": bool(relation.get("propagated_transition", false)),
		"transition_propagation_model": String(relation.get("transition_propagation_model", "")),
		"transition_source_distance": int(relation.get("transition_source_distance", 0)),
		"transition_source_offset": relation.get("transition_source_offset", {}),
		"transition_source_direction": String(relation.get("transition_source_direction", "")),
		"uses_second_ring": bool(relation.get("uses_second_ring", false)),
		"diagonal_policy": "family_stamp_lookup_with_axis_flips" if bool(relation.get("propagated_transition", false)) else "diagonal_context_in_atlas_lookup",
		"fallback": bool(visual_selection.get("fallback", false)),
		"direct_water_rock_contact": bool(visual_selection.get("direct_water_rock_contact", false)),
		"fallback_reason": fallback_reason,
		"provisional_fallback_policy": String(receiver_payload.get("provisional_fallback_policy", "")),
		"unresolved_fallback_policy": String(receiver_payload.get("unresolved_fallback_policy", "")),
		"logical_degrade_note": String(config.get("logical_degrade_note", "")),
		"relation": relation,
	}

func _homm3_bridge_mask_lookup(family: Dictionary, bridge_family: String) -> Dictionary:
	if not _homm3_family_uses_generic_land_edge_masks(family):
		return {}
	var fallback = family.get("bridge_mask_lookup", {})
	var result: Dictionary = fallback.duplicate(true) if fallback is Dictionary else {}
	var lookups = family.get("bridge_family_mask_lookups", {})
	if lookups is Dictionary and lookups.has(bridge_family):
		var family_lookup = lookups.get(bridge_family, {})
		if family_lookup is Dictionary:
			for key in family_lookup.keys():
				result[key] = family_lookup.get(key)
	return result

func _homm3_lookup_entry(lookup, mask_key: String) -> Dictionary:
	if not (lookup is Dictionary) or not lookup.has(mask_key):
		return {}
	var value = lookup.get(mask_key)
	if value is Dictionary:
		var entry: Dictionary = value
		return {
			"frame": String(entry.get("frame", "")).strip_edges(),
			"flip_h": bool(entry.get("flip_h", false)),
			"flip_v": bool(entry.get("flip_v", false)),
			"lookup_model": String(entry.get("lookup_model", "single_frame_with_axis_flips")),
		}
	return {"frame": String(value).strip_edges()}

func _homm3_flip_key(flip_h: bool, flip_v: bool) -> String:
	if flip_h and flip_v:
		return "HV"
	if flip_h:
		return "H"
	if flip_v:
		return "V"
	return ""

func _homm3_interior_frame_selection_model() -> String:
	return String(_homm3_prototype.get("interior_frame_selection_model", TERRAIN_HOMM3_INTERIOR_SELECTION_MODEL)).strip_edges()

func _homm3_interior_frame_count(family: Dictionary) -> int:
	var interior_frames = family.get("interior_frames", [])
	if not (interior_frames is Array) or interior_frames.is_empty():
		return 0
	return interior_frames.size()

func _homm3_interior_frame(family: Dictionary, _tile: Vector2i, _terrain_id: String) -> String:
	var primary_frame := String(family.get("primary_interior_frame", "")).strip_edges()
	if primary_frame != "":
		return primary_frame
	var interior_frames = family.get("interior_frames", [])
	if not (interior_frames is Array) or interior_frames.is_empty():
		return ""
	return String(interior_frames[0]).strip_edges()

func _homm3_terrain_relation_payload(tile: Vector2i, terrain_id: String) -> Dictionary:
	var config := _homm3_terrain_config(terrain_id)
	var family_id := String(config.get("family", "")).strip_edges()
	var family := _homm3_terrain_family_config(family_id)
	var bridge_family := _homm3_receiver_bridge_family(config, family)
	var atlas_role := _homm3_family_atlas_role(family)
	var uses_land_receiver_stamp_tables := _homm3_uses_land_receiver_stamp_tables(family)
	var cardinal_sources: Array = []
	var corner_sources: Array = []
	var cardinal_keys: Array[String] = []
	var corner_keys: Array[String] = []
	var selection_kind := "interior"
	if _session == null or not _tile_in_bounds(tile) or not OverworldRulesScript.is_tile_explored(_session, tile.x, tile.y):
		return {
			"selection_kind": selection_kind,
			"mask_key": "",
			"edge_mask": "",
			"corner_mask": "",
			"cardinal_sources": cardinal_sources,
			"corner_sources": corner_sources,
		}
	for check in _terrain_cardinal_transition_checks():
		var source := _homm3_relation_source_for_neighbor(tile, terrain_id, check)
		if source.is_empty():
			continue
		cardinal_sources.append(source)
		cardinal_keys.append(String(source.get("direction", "")))
	for check in _terrain_diagonal_transition_checks():
		var source := _homm3_relation_source_for_neighbor(tile, terrain_id, check)
		if source.is_empty():
			continue
		corner_sources.append(source)
		corner_keys.append(String(source.get("direction", "")))
	if uses_land_receiver_stamp_tables and cardinal_sources.is_empty():
		corner_sources.clear()
		corner_keys.clear()
	for source_value in cardinal_sources:
		if source_value is Dictionary:
			var source: Dictionary = source_value
			source["cardinal_source_count"] = cardinal_sources.size()
			source["corner_source_count"] = corner_sources.size()
	for source_value in corner_sources:
		if source_value is Dictionary:
			var source: Dictionary = source_value
			source["cardinal_source_count"] = cardinal_sources.size()
			source["corner_source_count"] = corner_sources.size()
	var bridge_sources_for_resolution := corner_sources.duplicate()
	if not cardinal_sources.is_empty():
		bridge_sources_for_resolution.clear()
	var primary_bridge_source := _homm3_primary_bridge_source(cardinal_sources, bridge_sources_for_resolution)
	var resolved_bridge_family := _homm3_bridge_family_from_sources(cardinal_sources, bridge_sources_for_resolution, bridge_family)
	var bridge_source_kind := _homm3_bridge_source_kind_from_sources(cardinal_sources, bridge_sources_for_resolution, family)
	var receiver_stamp_payload: Dictionary = {}
	var bridge_target_frame_block := String(primary_bridge_source.get("bridge_target_frame_block", ""))
	if bridge_target_frame_block == "" and not receiver_stamp_payload.is_empty():
		bridge_target_frame_block = String(receiver_stamp_payload.get("stamp_target_frame_block", ""))
	if _homm3_is_water_system(family):
		if not cardinal_keys.is_empty() or not corner_keys.is_empty():
			selection_kind = "water_shoreline"
	elif _homm3_is_rock_system(family):
		if not cardinal_keys.is_empty() or not corner_keys.is_empty():
			selection_kind = "rock_system"
	elif atlas_role == "base_decor_bridge_material":
		if not cardinal_keys.is_empty():
			selection_kind = "bridge_material_base_context"
	elif uses_land_receiver_stamp_tables:
		if not cardinal_keys.is_empty():
			selection_kind = "bridge_transition"
	elif cardinal_keys.is_empty() and not corner_keys.is_empty():
		selection_kind = "corner_transition"
	elif not cardinal_keys.is_empty() or not corner_keys.is_empty():
		selection_kind = "bridge_transition"
	var mask_key := _homm3_mask_key_from_keys(cardinal_keys)
	return {
		"selection_kind": selection_kind,
		"mask_key": mask_key,
		"edge_mask": _homm3_compact_mask_from_keys(cardinal_keys),
		"corner_mask": _homm3_compact_mask_from_keys(corner_keys),
		"bridge_family": resolved_bridge_family,
		"bridge_resolution_model": _homm3_bridge_resolution_model_from_sources(cardinal_sources, bridge_sources_for_resolution),
		"bridge_resolver_model": _homm3_bridge_material_resolver_model(),
		"bridge_class": String(primary_bridge_source.get("bridge_class", receiver_stamp_payload.get("stamp_bridge_class", _homm3_bridge_class_for_family(resolved_bridge_family, family)))),
		"bridge_source_level": String(primary_bridge_source.get("bridge_source_level", family.get("preferred_bridge_source_level", ""))),
		"bridge_rule_id": String(primary_bridge_source.get("bridge_rule_id", "")),
		"bridge_target_frame_block": bridge_target_frame_block,
		"bridge_policy_provisional": bool(primary_bridge_source.get("bridge_policy_provisional", false)),
		"bridge_source_kind": bridge_source_kind,
		"receiver_stamp_payload": receiver_stamp_payload,
		"stamp_target_frame_block": String(receiver_stamp_payload.get("stamp_target_frame_block", "")),
		"direct_bridge_material_contact": bridge_source_kind == "direct_bridge_material",
		"preferred_bridge_class_used": bridge_source_kind == "preferred_bridge_class",
		"rock_ground_context": "preferred_light_ground" if _homm3_is_rock_system(family) and bridge_source_kind == "preferred_bridge_class" else "",
		"cardinal_sources": cardinal_sources,
		"corner_sources": corner_sources,
		"propagated_sources": [],
		"propagated_transition": false,
		"propagated_transition_entry": {},
		"transition_propagation_model": "",
		"transition_source_distance": 0,
		"transition_source_offset": {},
		"transition_source_direction": "",
		"uses_second_ring": false,
	}

func _homm3_direction_from_offset(offset: Vector2i) -> String:
	var vertical := ""
	var horizontal := ""
	if offset.y < 0:
		vertical = "N"
	elif offset.y > 0:
		vertical = "S"
	if offset.x < 0:
		horizontal = "W"
	elif offset.x > 0:
		horizontal = "E"
	return vertical + horizontal

func _homm3_primary_bridge_source(cardinal_sources: Array, corner_sources: Array) -> Dictionary:
	for source_array in [cardinal_sources, corner_sources]:
		for source_value in source_array:
			if source_value is Dictionary and bool(source_value.get("uses_direct_bridge_pair", false)):
				return source_value
	for source_kind in ["direct_bridge_material", "routed_bridge", "preferred_bridge_class", "unresolved_fallback"]:
		for source_array in [cardinal_sources, corner_sources]:
			for source_value in source_array:
				if not (source_value is Dictionary):
					continue
				var source: Dictionary = source_value
				if String(source.get("bridge_source_kind", "")).strip_edges() == source_kind:
					return source
	return {}

func _homm3_bridge_family_from_sources(cardinal_sources: Array, corner_sources: Array, fallback_bridge_family: String) -> String:
	var primary_bridge_source := _homm3_primary_bridge_source(cardinal_sources, corner_sources)
	if not primary_bridge_source.is_empty():
		var primary_family := String(primary_bridge_source.get("resolved_bridge_family", "")).strip_edges()
		if primary_family != "":
			return primary_family
	for source_array in [cardinal_sources, corner_sources]:
		for source_value in source_array:
			if not (source_value is Dictionary):
				continue
			var source: Dictionary = source_value
			if bool(source.get("uses_direct_bridge_pair", false)):
				var direct_family := String(source.get("resolved_bridge_family", "")).strip_edges()
				if direct_family != "":
					return direct_family
	for source_array in [cardinal_sources, corner_sources]:
		for source_value in source_array:
			if not (source_value is Dictionary):
				continue
			var source: Dictionary = source_value
			var resolved_family := String(source.get("resolved_bridge_family", "")).strip_edges()
			if resolved_family != "":
				return resolved_family
	return fallback_bridge_family

func _homm3_bridge_resolution_model_from_sources(cardinal_sources: Array, corner_sources: Array) -> String:
	var primary_bridge_source := _homm3_primary_bridge_source(cardinal_sources, corner_sources)
	if not primary_bridge_source.is_empty():
		var primary_model := String(primary_bridge_source.get("bridge_resolution_model", "")).strip_edges()
		if primary_model != "":
			return primary_model
	for source_array in [cardinal_sources, corner_sources]:
		for source_value in source_array:
			if not (source_value is Dictionary):
				continue
			var source: Dictionary = source_value
			if bool(source.get("uses_direct_bridge_pair", false)):
				return String(source.get("bridge_resolution_model", "direct_family_pair_lookup"))
	for source_array in [cardinal_sources, corner_sources]:
		for source_value in source_array:
			if not (source_value is Dictionary):
				continue
			var source: Dictionary = source_value
			var model := String(source.get("bridge_resolution_model", "")).strip_edges()
			if model != "":
				return model
	return "receiver_bridge_family_default"

func _homm3_bridge_source_kind_from_sources(cardinal_sources: Array, corner_sources: Array, family: Dictionary) -> String:
	var primary_bridge_source := _homm3_primary_bridge_source(cardinal_sources, corner_sources)
	if not primary_bridge_source.is_empty():
		var primary_kind := String(primary_bridge_source.get("bridge_source_kind", "")).strip_edges()
		if primary_kind != "":
			return primary_kind
	for source_array in [cardinal_sources, corner_sources]:
		for source_value in source_array:
			if not (source_value is Dictionary):
				continue
			var source: Dictionary = source_value
			var source_kind := String(source.get("bridge_source_kind", "")).strip_edges()
			if source_kind != "":
				return source_kind
	var preferred_source_level := String(family.get("preferred_bridge_source_level", "")).strip_edges()
	if String(family.get("preferred_bridge_class", "")).strip_edges() == "unresolved" or preferred_source_level == "provisional":
		return "unresolved_fallback"
	if _homm3_is_water_system(family) or _homm3_is_rock_system(family):
		return "preferred_bridge_class"
	if String(family.get("preferred_bridge_class", "")).strip_edges() != "":
		return "preferred_bridge_class"
	return "unresolved_fallback"

func _homm3_relation_source_for_neighbor(tile: Vector2i, receiver_terrain: String, check: Dictionary) -> Dictionary:
	var direction := String(check.get("label", ""))
	var offset: Vector2i = check.get("offset", Vector2i.ZERO)
	var neighbor := tile + offset
	if direction == "" or not _tile_in_bounds(neighbor):
		return {}
	if _session == null or not OverworldRulesScript.is_tile_explored(_session, neighbor.x, neighbor.y):
		return {}
	var neighbor_terrain := _terrain_at(neighbor)
	if neighbor_terrain == "":
		return {}
	var receiver_config := _homm3_terrain_config(receiver_terrain)
	var neighbor_config := _homm3_terrain_config(neighbor_terrain)
	if receiver_config.is_empty() or neighbor_config.is_empty():
		return {}
	var receiver_family := String(receiver_config.get("family", ""))
	var neighbor_family := String(neighbor_config.get("family", ""))
	if receiver_family == neighbor_family:
		return {}
	var receiver_family_config := _homm3_terrain_family_config(receiver_family)
	var neighbor_family_config := _homm3_terrain_family_config(neighbor_family)
	var receiver_is_water := _homm3_is_water_system(receiver_family_config)
	var neighbor_is_water := _homm3_is_water_system(neighbor_family_config)
	if not receiver_is_water and neighbor_is_water:
		return {}
	var receiver_is_rock := _homm3_is_rock_system(receiver_family_config)
	var receiver_atlas_role := _homm3_family_atlas_role(receiver_family_config)
	var relation_kind := "shoreline_land_neighbor" if receiver_is_water else ("rock_system_neighbor" if receiver_is_rock else ("bridge_material_base_context" if receiver_atlas_role == "base_decor_bridge_material" else "bridge_base_resolution"))
	var default_bridge_family := _homm3_receiver_bridge_family(receiver_config, receiver_family_config)
	var bridge_resolution := _homm3_bridge_material_resolution(receiver_config, receiver_family_config, receiver_family, neighbor_family_config, neighbor_family)
	if _homm3_receiver_suppresses_full_land_neighbor(receiver_family_config, neighbor_family_config, bridge_resolution):
		return {}
	var resolved_bridge_family := String(bridge_resolution.get("bridge_family", default_bridge_family)).strip_edges()
	var bridge_resolution_model := "shoreline_specific_lookup" if receiver_is_water else ("rock_system_lookup" if receiver_is_rock else ("bridge_material_base_context_lookup" if receiver_atlas_role == "base_decor_bridge_material" else "receiver_bridge_family_default"))
	if String(bridge_resolution.get("bridge_resolution_model", "")).strip_edges() != "":
		bridge_resolution_model = String(bridge_resolution.get("bridge_resolution_model", ""))
	var bridge_source_kind := String(bridge_resolution.get("bridge_source_kind", "preferred_bridge_class")).strip_edges()
	return {
		"direction": direction,
		"source_terrain": neighbor_terrain,
		"source_group": _terrain_group(neighbor_terrain),
		"source_family": neighbor_family,
		"source_atlas_role": _homm3_family_atlas_role(neighbor_family_config),
		"receiver_terrain": receiver_terrain,
		"receiver_group": _terrain_group(receiver_terrain),
		"receiver_family": receiver_family,
		"receiver_atlas_role": receiver_atlas_role,
		"resolved_bridge_family": resolved_bridge_family,
		"bridge_class": String(bridge_resolution.get("bridge_class", "")),
		"bridge_resolution_model": bridge_resolution_model,
		"bridge_resolver_model": String(bridge_resolution.get("bridge_resolver_model", "")),
		"bridge_source_kind": bridge_source_kind,
		"bridge_source_level": String(bridge_resolution.get("bridge_source_level", "")),
		"bridge_rule_id": String(bridge_resolution.get("bridge_rule_id", "")),
		"bridge_target_frame_block": String(bridge_resolution.get("bridge_target_frame_block", "")),
		"bridge_policy_provisional": bool(bridge_resolution.get("bridge_policy_provisional", false)),
		"uses_direct_bridge_pair": bool(bridge_resolution.get("uses_direct_bridge_pair", false)),
		"uses_direct_bridge_material_contact": bool(bridge_resolution.get("uses_direct_bridge_material_contact", false)),
		"uses_routed_bridge_rule": bool(bridge_resolution.get("uses_routed_bridge_rule", false)),
		"relation_kind": relation_kind,
		"neighbor": {"x": neighbor.x, "y": neighbor.y},
		"source_offset": {"x": offset.x, "y": offset.y},
	}

func _homm3_receiver_suppresses_full_land_neighbor(receiver_family_config: Dictionary, neighbor_family_config: Dictionary, bridge_resolution: Dictionary) -> bool:
	var receiver_role := _homm3_family_atlas_role(receiver_family_config)
	var neighbor_role := _homm3_family_atlas_role(neighbor_family_config)
	if neighbor_role != "full_receiver_land":
		return false
	if receiver_role == "base_decor_bridge_material":
		return true
	if receiver_role == "reduced_bridge_receiver":
		return not bool(bridge_resolution.get("uses_direct_bridge_pair", false))
	return false

func _homm3_direct_bridge_pair(receiver_family: String, neighbor_family: String) -> Dictionary:
	var key := "%s|%s" % [receiver_family.strip_edges(), neighbor_family.strip_edges()]
	var pair = _homm3_direct_bridge_pairs.get(key, {})
	return pair if pair is Dictionary else {}

func _homm3_routed_bridge_rule(receiver_family: String, neighbor_family: String) -> Dictionary:
	var key := "%s|%s" % [receiver_family.strip_edges(), neighbor_family.strip_edges()]
	var rule = _homm3_routed_bridge_rules.get(key, {})
	return rule if rule is Dictionary else {}

func _homm3_mask_key_from_keys(keys: Array[String]) -> String:
	var ordered := []
	for key in ["N", "E", "S", "W"]:
		if key in keys:
			ordered.append(key)
	return "+".join(ordered)

func _homm3_compact_mask_from_keys(keys: Array[String]) -> String:
	var result := ""
	for key in ["N", "E", "S", "W", "NE", "SE", "SW", "NW"]:
		if key in keys:
			result += key
	return result

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

func _terrain_art_texture_for_entry(entry: Dictionary):
	var texture_path := String(entry.get("path", ""))
	var texture = _terrain_art_texture(texture_path)
	if not (texture is Texture2D):
		return null
	var flip_h := bool(entry.get("flip_h", false))
	var flip_v := bool(entry.get("flip_v", false))
	if not flip_h and not flip_v:
		return texture
	var cache_key := "%s|%s|%s" % [texture_path.strip_edges(), "h" if flip_h else "", "v" if flip_v else ""]
	if _terrain_art_transformed_textures.has(cache_key):
		return _terrain_art_transformed_textures.get(cache_key)
	var image = texture.get_image()
	if image == null:
		return texture
	if flip_h:
		image.flip_x()
	if flip_v:
		image.flip_y()
	var flipped_texture := ImageTexture.create_from_image(image)
	_terrain_art_transformed_textures[cache_key] = flipped_texture
	return flipped_texture

func _terrain_transition_priority(terrain_id: String) -> int:
	var style := _terrain_style(terrain_id)
	return int(style.get("transition_priority", 0))

func _terrain_transition_edge_mask(tile: Vector2i) -> String:
	return String(_terrain_transition_payload(tile).get("edge_mask", ""))

func _terrain_transition_payload(tile: Vector2i) -> Dictionary:
	var terrain := _terrain_at(tile)
	var homm3_selection := _homm3_terrain_selection_payload(tile, terrain)
	if not homm3_selection.is_empty():
		var relation: Dictionary = homm3_selection.get("relation", {})
		var cardinal_sources: Array = relation.get("cardinal_sources", [])
		var corner_sources: Array = relation.get("corner_sources", [])
		var propagated_sources: Array = relation.get("propagated_sources", [])
		var corner_and_propagated := corner_sources.duplicate()
		corner_and_propagated.append_array(propagated_sources)
		return {
			"model": TERRAIN_TRANSITION_SELECTION_MODEL,
			"edge_model": TERRAIN_TRANSITION_EDGE_MODEL,
			"corner_model": TERRAIN_TRANSITION_CORNER_MODEL,
			"receiver_terrain": terrain,
			"receiver_group": _terrain_group(terrain),
			"receiver_priority": _terrain_transition_priority(terrain),
			"edge_mask": String(relation.get("edge_mask", "")),
			"corner_mask": String(relation.get("corner_mask", "")),
			"cardinal_sources": cardinal_sources,
			"corner_sources": corner_sources,
			"propagated_sources": propagated_sources,
			"source_terrain_ids": _transition_unique_values(cardinal_sources, corner_and_propagated, "source_terrain"),
			"source_groups": _transition_unique_values(cardinal_sources, corner_and_propagated, "source_group"),
			"homm3_selection": homm3_selection,
			"homm3_mask_key": String(homm3_selection.get("mask_key", "")),
			"homm3_bridge_family": String(homm3_selection.get("bridge_family", "")),
			"homm3_selection_kind": String(homm3_selection.get("selection_kind", "")),
			"homm3_frame_id": String(homm3_selection.get("frame_id", "")),
		}
	var payload := {
		"model": TERRAIN_TRANSITION_SELECTION_MODEL,
		"edge_model": TERRAIN_TRANSITION_EDGE_MODEL,
		"corner_model": TERRAIN_TRANSITION_CORNER_MODEL,
		"receiver_terrain": terrain,
		"receiver_group": _terrain_group(terrain),
		"receiver_priority": _terrain_transition_priority(terrain),
		"edge_mask": "",
		"corner_mask": "",
		"cardinal_sources": [],
		"corner_sources": [],
		"propagated_sources": [],
		"source_terrain_ids": [],
		"source_groups": [],
	}
	if _session == null or not _tile_in_bounds(tile) or not OverworldRulesScript.is_tile_explored(_session, tile.x, tile.y):
		return payload
	var cardinal_sources: Array = []
	var corner_sources: Array = []
	var edge_mask := ""
	var corner_mask := ""
	for check in _terrain_cardinal_transition_checks():
		var source := _terrain_transition_source_for_neighbor(tile, terrain, check)
		if source.is_empty():
			continue
		cardinal_sources.append(source)
		edge_mask += String(source.get("direction", ""))
	for check in _terrain_diagonal_transition_checks():
		var source := _terrain_transition_source_for_neighbor(tile, terrain, check)
		if source.is_empty():
			continue
		var source_group := String(source.get("source_group", ""))
		var offset: Vector2i = check.get("offset", Vector2i.ZERO)
		if _tile_has_explored_terrain_group(tile + Vector2i(offset.x, 0), source_group):
			continue
		if _tile_has_explored_terrain_group(tile + Vector2i(0, offset.y), source_group):
			continue
		corner_sources.append(source)
		corner_mask += String(source.get("direction", ""))
	payload["edge_mask"] = edge_mask
	payload["corner_mask"] = corner_mask
	payload["cardinal_sources"] = cardinal_sources
	payload["corner_sources"] = corner_sources
	payload["source_terrain_ids"] = _transition_unique_values(cardinal_sources, corner_sources, "source_terrain")
	payload["source_groups"] = _transition_unique_values(cardinal_sources, corner_sources, "source_group")
	return payload

func _terrain_transition_source_for_neighbor(tile: Vector2i, receiver_terrain: String, check: Dictionary) -> Dictionary:
	var direction := String(check.get("label", ""))
	var offset: Vector2i = check.get("offset", Vector2i.ZERO)
	var neighbor := tile + offset
	if direction == "" or not _tile_in_bounds(neighbor):
		return {}
	if not OverworldRulesScript.is_tile_explored(_session, neighbor.x, neighbor.y):
		return {}
	var neighbor_terrain := _terrain_at(neighbor)
	if neighbor_terrain == "":
		return {}
	var receiver_group := _terrain_group(receiver_terrain)
	var source_group := _terrain_group(neighbor_terrain)
	if source_group == receiver_group:
		return {}
	var receiver_priority := _terrain_transition_priority(receiver_terrain)
	var source_priority := _terrain_transition_priority(neighbor_terrain)
	if source_priority <= receiver_priority:
		return {}
	return {
		"direction": direction,
		"source_terrain": neighbor_terrain,
		"source_group": source_group,
		"source_priority": source_priority,
		"receiver_terrain": receiver_terrain,
		"receiver_group": receiver_group,
		"receiver_priority": receiver_priority,
		"neighbor": {"x": neighbor.x, "y": neighbor.y},
	}

func _terrain_cardinal_transition_checks() -> Array:
	return [
		{"label": "N", "offset": Vector2i(0, -1)},
		{"label": "E", "offset": Vector2i(1, 0)},
		{"label": "S", "offset": Vector2i(0, 1)},
		{"label": "W", "offset": Vector2i(-1, 0)},
	]

func _terrain_diagonal_transition_checks() -> Array:
	return [
		{"label": "NE", "offset": Vector2i(1, -1)},
		{"label": "SE", "offset": Vector2i(1, 1)},
		{"label": "SW", "offset": Vector2i(-1, 1)},
		{"label": "NW", "offset": Vector2i(-1, -1)},
	]

func _tile_has_explored_terrain_group(tile: Vector2i, terrain_group: String) -> bool:
	if terrain_group == "" or _session == null or not _tile_in_bounds(tile):
		return false
	if not OverworldRulesScript.is_tile_explored(_session, tile.x, tile.y):
		return false
	return _terrain_group(_terrain_at(tile)) == terrain_group

func _transition_unique_values(cardinal_sources: Array, corner_sources: Array, key: String) -> Array:
	var values := []
	for source_array in [cardinal_sources, corner_sources]:
		for source_value in source_array:
			if not (source_value is Dictionary):
				continue
			var value := String(source_value.get(key, ""))
			if value != "" and value not in values:
				values.append(value)
	return values

func _tile_in_bounds(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.y >= 0 and tile.x < _map_size.x and tile.y < _map_size.y

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

func _road_neighbor_directions(tile: Vector2i) -> Array:
	var road := _road_tile_payload(tile)
	if road.has("connections"):
		var connections = road.get("connections", [])
		var connection_directions := []
		if connections is Array:
			for direction in ROAD_CARDINAL_DIRECTIONS:
				if _direction_key(direction) in connections:
					connection_directions.append(direction)
		return connection_directions
	var neighbor_directions := []
	for direction in ROAD_CARDINAL_DIRECTIONS:
		var neighbor: Vector2i = tile + direction
		if _road_tiles.has(_tile_key(neighbor)):
			neighbor_directions.append(direction)
	return neighbor_directions

func _road_horizontal_lane_y(rect: Rect2) -> float:
	return rect.position.y + (rect.size.y * ROAD_HORIZONTAL_EDGE_Y_FACTOR)

func _road_connector_start(rect: Rect2, direction: Vector2i) -> Vector2:
	if direction == Vector2i.LEFT or direction == Vector2i.RIGHT:
		return Vector2(rect.get_center().x, _road_horizontal_lane_y(rect))
	return rect.get_center()

func _road_connector_end(rect: Rect2, direction: Vector2i) -> Vector2:
	if direction == Vector2i.LEFT:
		return Vector2(rect.position.x - (rect.size.x * 0.05), _road_horizontal_lane_y(rect))
	if direction == Vector2i.RIGHT:
		return Vector2(rect.end.x + (rect.size.x * 0.05), _road_horizontal_lane_y(rect))
	return rect.get_center() + Vector2(float(direction.x) * rect.size.x * 0.52, float(direction.y) * rect.size.y * 0.52)

func _road_has_horizontal_connections(neighbor_directions: Array) -> bool:
	return Vector2i.LEFT in neighbor_directions or Vector2i.RIGHT in neighbor_directions

func _road_has_vertical_connections(neighbor_directions: Array) -> bool:
	return Vector2i.UP in neighbor_directions or Vector2i.DOWN in neighbor_directions

func _road_has_diagonal_connections(neighbor_directions: Array) -> bool:
	for direction in neighbor_directions:
		if direction is Vector2i and direction.x != 0 and direction.y != 0:
			return true
	return false

func _road_needs_joint_cap(neighbor_directions: Array) -> bool:
	var count := neighbor_directions.size()
	if count <= 1:
		return true
	if count >= 3:
		return true
	if count != 2:
		return false
	var first: Vector2i = neighbor_directions[0]
	var second: Vector2i = neighbor_directions[1]
	return (first + second) != Vector2i.ZERO

func _road_connection_key(tile: Vector2i) -> String:
	return _road_connection_key_from_directions(_road_neighbor_directions(tile))

func _road_connection_key_from_directions(directions: Array) -> String:
	var source_keys: Array[String] = []
	for direction in directions:
		var direction_key := _direction_key(direction)
		if direction_key != "":
			source_keys.append(direction_key)
	var keys: Array[String] = []
	for canonical_key in ["N", "E", "S", "W"]:
		if canonical_key in source_keys:
			keys.append(canonical_key)
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
	var profile_start := _profile_begin("road_index")
	var roads = _terrain_layers.get("roads", [])
	var signature := _combine_cache_signature(CACHE_SIGNATURE_SEED, _map_size.x)
	signature = _combine_cache_signature(signature, _map_size.y)
	signature = _combine_cache_signature(signature, _roads_cache_signature(roads))
	if not _validation_force_index_rebuild and signature == _road_index_signature:
		_profile_add("road_index_skips", 1)
		_profile_end("road_index", profile_start, {
			"rebuilt": false,
			"road_tiles": _road_tiles.size(),
			"signature": signature,
		})
		return
	_road_index_signature = signature
	_road_tiles.clear()
	if not (roads is Array):
		_profile_add("road_index_rebuilds", 1)
		_profile_end("road_index", profile_start, {"rebuilt": true, "road_tiles": 0, "signature": signature})
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
			_ensure_road_tile_payload(tile, overlay_id, road_id, role)
	_rebuild_road_adjacency_connections()
	_profile_add("road_index_rebuilds", 1)
	_profile_end("road_index", profile_start, {
		"rebuilt": true,
		"road_tiles": _road_tiles.size(),
		"signature": signature,
	})

func _rebuild_object_indexes() -> void:
	var profile_start := _profile_begin("object_index")
	var static_signature := _object_index_signature_for(_session)
	var hero_signature := _hero_index_signature_for(_session)
	var rebuilt_static := false
	var rebuilt_heroes := false
	if _session == null:
		_towns_by_tile.clear()
		_town_footprints_by_tile.clear()
		_resources_by_tile.clear()
		_artifacts_by_tile.clear()
		_encounters_by_tile.clear()
		_rememberable_encounters_by_tile.clear()
		_heroes_by_tile.clear()
		_object_index_signature = 0
		_hero_index_signature = 0
		_profile_end("object_index", profile_start, {"rebuilt_static": true, "rebuilt_heroes": true})
		return
	if _validation_force_index_rebuild or static_signature != _object_index_signature:
		_object_index_signature = static_signature
		_rebuild_static_object_indexes()
		rebuilt_static = true
		_profile_add("object_index_rebuilds", 1)
	else:
		_profile_add("object_index_skips", 1)
	if _validation_force_index_rebuild or hero_signature != _hero_index_signature:
		_hero_index_signature = hero_signature
		_rebuild_hero_index()
		rebuilt_heroes = true
		_profile_add("hero_index_rebuilds", 1)
	else:
		_profile_add("hero_index_skips", 1)
	_profile_end("object_index", profile_start, {
		"rebuilt_static": rebuilt_static,
		"rebuilt_heroes": rebuilt_heroes,
		"town_tiles": _towns_by_tile.size(),
		"resource_tiles": _resources_by_tile.size(),
		"artifact_tiles": _artifacts_by_tile.size(),
		"encounter_tiles": _encounters_by_tile.size(),
		"hero_tiles": _heroes_by_tile.size(),
	})

func _rebuild_static_object_indexes() -> void:
	_towns_by_tile.clear()
	_town_footprints_by_tile.clear()
	_resources_by_tile.clear()
	_artifacts_by_tile.clear()
	_encounters_by_tile.clear()
	_rememberable_encounters_by_tile.clear()
	for town_value in _session.overworld.get("towns", []):
		if not (town_value is Dictionary):
			continue
		var town: Dictionary = town_value
		var entry := _town_entry_tile(town)
		_towns_by_tile[_tile_key(entry)] = town
		var origin := _town_footprint_origin_for_entry(entry)
		for y_offset in range(TOWN_PRESENTATION_FOOTPRINT.y):
			for x_offset in range(TOWN_PRESENTATION_FOOTPRINT.x):
				var tile := origin + Vector2i(x_offset, y_offset)
				if tile.x < 0 or tile.y < 0 or tile.x >= _map_size.x or tile.y >= _map_size.y:
					continue
				_town_footprints_by_tile[_tile_key(tile)] = {
					"town": town,
					"entry_tile": entry,
					"origin_tile": origin,
					"cell_offset": tile - origin,
					"is_entry_tile": tile == entry,
					"tile_role": TOWN_ENTRY_ROLE if tile == entry else TOWN_NON_ENTRY_ROLE,
					"presentation_blocked": tile != entry,
				}
	for node_value in _session.overworld.get("resource_nodes", []):
		if not (node_value is Dictionary):
			continue
		var node: Dictionary = node_value
		var site = ContentService.get_resource_site(String(node.get("site_id", "")))
		if bool(site.get("persistent_control", false)) or not bool(node.get("collected", false)):
			_resources_by_tile[_tile_key(Vector2i(int(node.get("x", -1)), int(node.get("y", -1))))] = node
	for node_value in _session.overworld.get("artifact_nodes", []):
		if not (node_value is Dictionary):
			continue
		var node: Dictionary = node_value
		if not bool(node.get("collected", false)):
			_artifacts_by_tile[_tile_key(Vector2i(int(node.get("x", -1)), int(node.get("y", -1))))] = node
	for encounter_value in _session.overworld.get("encounters", []):
		if not (encounter_value is Dictionary):
			continue
		var encounter: Dictionary = encounter_value
		if OverworldRulesScript.is_encounter_resolved(_session, encounter):
			continue
		var key := _tile_key(Vector2i(int(encounter.get("x", -1)), int(encounter.get("y", -1))))
		_encounters_by_tile[key] = encounter
		if String(encounter.get("spawned_by_faction_id", "")) == "":
			_rememberable_encounters_by_tile[key] = encounter

func _rebuild_hero_index() -> void:
	_heroes_by_tile.clear()
	for hero_value in HeroCommandRulesScript.hero_positions(_session):
		if not (hero_value is Dictionary):
			continue
		var hero: Dictionary = hero_value
		var key := _tile_key(Vector2i(int(hero.get("x", -1)), int(hero.get("y", -1))))
		var heroes: Array = _heroes_by_tile.get(key, [])
		heroes.append(hero)
		_heroes_by_tile[key] = heroes

func _object_index_signature_for(session) -> int:
	if session == null:
		return 0
	var overworld = session.overworld
	var signature := _combine_cache_signature(CACHE_SIGNATURE_SEED, _map_size.x)
	signature = _combine_cache_signature(signature, _map_size.y)
	signature = _combine_cache_signature(signature, _placement_array_cache_signature(overworld.get("towns", []), ["owner", "placement_id", "town_id"]))
	signature = _combine_cache_signature(signature, _placement_array_cache_signature(overworld.get("resource_nodes", []), ["site_id", "placement_id", "collected", "collected_by_faction_id"]))
	signature = _combine_cache_signature(signature, _placement_array_cache_signature(overworld.get("artifact_nodes", []), ["artifact_id", "placement_id", "collected", "collected_by_faction_id"]))
	signature = _combine_cache_signature(signature, _placement_array_cache_signature(overworld.get("encounters", []), ["encounter_id", "placement_id", "spawned_by_faction_id"]))
	return _combine_cache_signature(signature, _placement_array_cache_signature(overworld.get("resolved_encounters", []), ["placement_id", "encounter_id", "id"]))

func _hero_index_signature_for(session) -> int:
	if session == null:
		return 0
	return _placement_array_cache_signature(HeroCommandRulesScript.hero_positions(session), ["hero_id", "is_active"])

func _ensure_road_tile_payload(tile: Vector2i, overlay_id: String, road_id: String, role: String) -> void:
	var key := _tile_key(tile)
	var payload: Dictionary = _road_tiles.get(key, {})
	if payload.is_empty():
		payload = {
			"overlay_id": overlay_id,
			"road_id": road_id,
			"road_ids": [road_id] if road_id != "" else [],
			"role": role,
			"tile_x": tile.x,
			"tile_y": tile.y,
			"connections": [],
			"ordered_connections": false,
			"same_type_adjacency": true,
			"connection_source": ROAD_CONNECTION_SOURCE,
			"piece_selection_model": ROAD_PIECE_SELECTION_MODEL,
		}
	else:
		if not payload.has("connections"):
			payload["connections"] = []
		payload["ordered_connections"] = false
		payload["same_type_adjacency"] = true
		payload["connection_source"] = ROAD_CONNECTION_SOURCE
		payload["piece_selection_model"] = ROAD_PIECE_SELECTION_MODEL
		payload["tile_x"] = tile.x
		payload["tile_y"] = tile.y
		if String(payload.get("overlay_id", "")) == "":
			payload["overlay_id"] = overlay_id
		if String(payload.get("road_id", "")) == "":
			payload["road_id"] = road_id
		var road_ids = payload.get("road_ids", [])
		if not (road_ids is Array):
			road_ids = []
		if road_id != "" and road_id not in road_ids:
			road_ids.append(road_id)
		payload["road_ids"] = road_ids
		if String(payload.get("role", "")) == "":
			payload["role"] = role
	_road_tiles[key] = payload

func _rebuild_road_adjacency_connections() -> void:
	var road_keys := _road_tiles.keys()
	for key in road_keys:
		var payload: Dictionary = _road_tiles.get(key, {})
		if payload.is_empty():
			continue
		payload["connections"] = []
		payload["ordered_connections"] = false
		payload["same_type_adjacency"] = true
		payload["connection_source"] = ROAD_CONNECTION_SOURCE
		payload["piece_selection_model"] = ROAD_PIECE_SELECTION_MODEL
		_road_tiles[key] = payload
	for key in road_keys:
		var payload: Dictionary = _road_tiles.get(key, {})
		if payload.is_empty():
			continue
		var tile := Vector2i(int(payload.get("tile_x", -1)), int(payload.get("tile_y", -1)))
		if tile.x < 0 or tile.y < 0:
			continue
		for direction in ROAD_CARDINAL_DIRECTIONS:
			var neighbor: Vector2i = tile + direction
			var neighbor_payload: Dictionary = _road_tiles.get(_tile_key(neighbor), {})
			if _road_payloads_can_connect(payload, neighbor_payload):
				_add_road_connection(tile, direction)

func _road_payloads_can_connect(payload: Dictionary, neighbor_payload: Dictionary) -> bool:
	if payload.is_empty() or neighbor_payload.is_empty():
		return false
	var overlay_id := String(payload.get("overlay_id", ""))
	return overlay_id != "" and overlay_id == String(neighbor_payload.get("overlay_id", ""))

func _add_road_connection(tile: Vector2i, direction: Vector2i) -> void:
	var key := _tile_key(tile)
	var payload: Dictionary = _road_tiles.get(key, {})
	if payload.is_empty():
		return
	var direction_key := _direction_key(direction)
	if direction_key == "":
		return
	var connections = payload.get("connections", [])
	if not (connections is Array):
		connections = []
	if direction_key not in connections:
		connections.append(direction_key)
	payload["connections"] = connections
	_road_tiles[key] = payload

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
	_town_default_asset_id = ""
	_encounter_default_asset_id = ""
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

	var town_default = _overworld_art_manifest.get("town_default_sprite", {})
	if town_default is Dictionary:
		_town_default_asset_id = String(town_default.get("asset_id", ""))

	var encounter_default = _overworld_art_manifest.get("encounter_default_sprite", {})
	if encounter_default is Dictionary:
		_encounter_default_asset_id = String(encounter_default.get("asset_id", ""))

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
			"footprint_anchor": String(footprint.get("anchor", "bottom_center")) if footprint is Dictionary else "bottom_center",
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
		var resolved_profile: Dictionary = profile.duplicate(true)
		if node.get("runtime_footprint", {}) is Dictionary and not node.get("runtime_footprint", {}).is_empty():
			var runtime_footprint: Dictionary = node.get("runtime_footprint", {}).duplicate(true)
			resolved_profile["footprint"] = runtime_footprint
			resolved_profile["footprint_anchor"] = String(runtime_footprint.get("anchor", resolved_profile.get("footprint_anchor", "bottom_center")))
			resolved_profile["render_footprint_source"] = "generated_runtime_footprint"
			resolved_profile["authored_footprint"] = profile.get("footprint", Vector2i(1, 1))
		return resolved_profile
	var site := ContentService.get_resource_site(site_id)
	var family := String(site.get("family", "pickup"))
	if family == "":
		family = "pickup"
	var fallback := _default_object_profile(family, Vector2i(1, 1))
	if node.get("runtime_footprint", {}) is Dictionary and not node.get("runtime_footprint", {}).is_empty():
		var runtime_footprint: Dictionary = node.get("runtime_footprint", {}).duplicate(true)
		fallback["footprint"] = runtime_footprint
		fallback["footprint_anchor"] = String(runtime_footprint.get("anchor", fallback.get("footprint_anchor", "bottom_center")))
		fallback["render_footprint_source"] = "generated_runtime_footprint"
	return fallback

func _artifact_object_profile() -> Dictionary:
	return _default_object_profile("artifact", Vector2i(1, 1))

func _town_object_profile() -> Dictionary:
	return {
		"id": "default_town_world_object",
		"family": "town",
		"footprint": TOWN_PRESENTATION_FOOTPRINT,
		"presentation_model": TOWN_PRESENTATION_MODEL,
		"entry_role": TOWN_ENTRY_ROLE,
		"entry_offset": {"x": TOWN_ENTRY_OFFSET.x, "y": TOWN_ENTRY_OFFSET.y},
		"entry_is_visit_tile": true,
		"presentation_passability": "entry_only",
		"entry_tile_passable": true,
		"non_entry_tiles_blocked": true,
		"passable": false,
		"visitable": true,
		"map_roles": ["town", "visit_approach", "large_world_object"],
	}

func _encounter_object_profile() -> Dictionary:
	return _default_object_profile("encounter", Vector2i(1, 1))

func _hero_object_profile() -> Dictionary:
	return _default_object_profile("hero", Vector2i(1, 1))

func _default_object_profile(family: String, footprint: Vector2i) -> Dictionary:
	return {
		"id": "",
		"family": family,
		"footprint": _normalized_footprint(footprint),
		"footprint_anchor": "bottom_center",
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
	return _towns_by_tile.get(_tile_key(tile), {})

func _town_color(tile: Vector2i) -> Color:
	var town = _town_at(tile)
	return _town_owner_color(town)

func _town_owner_color(town: Dictionary) -> Color:
	match String(town.get("owner", "neutral")):
		"player":
			return PLAYER_TOWN_COLOR
		"enemy":
			return ENEMY_TOWN_COLOR
		_:
			return NEUTRAL_TOWN_COLOR

func _town_presentation_at(tile: Vector2i) -> Dictionary:
	if _session == null:
		return {}
	return _town_footprints_by_tile.get(_tile_key(tile), {})

func _town_entry_tile(town: Dictionary) -> Vector2i:
	return Vector2i(int(town.get("x", -1)), int(town.get("y", -1)))

func _town_footprint_origin_for_entry(entry: Vector2i) -> Vector2i:
	return entry - TOWN_ENTRY_OFFSET

func _town_footprint_rect_for_entry(entry: Vector2i) -> Rect2:
	var cells := _town_in_bounds_footprint_cells_for_entry(entry)
	if cells.is_empty():
		return _tile_rect(_board_rect(), entry)
	var min_x := entry.x
	var min_y := entry.y
	var max_x := entry.x
	var max_y := entry.y
	for cell_value in cells:
		var cell: Vector2i = cell_value
		min_x = mini(min_x, cell.x)
		min_y = mini(min_y, cell.y)
		max_x = maxi(max_x, cell.x)
		max_y = maxi(max_y, cell.y)
	var board_rect := _board_rect()
	var start_rect := _tile_rect(board_rect, Vector2i(min_x, min_y))
	var end_rect := _tile_rect(board_rect, Vector2i(max_x, max_y))
	return Rect2(start_rect.position, end_rect.end - start_rect.position)

func _town_in_bounds_footprint_cells_for_entry(entry: Vector2i) -> Array:
	var cells := []
	for cell in _town_footprint_cells_for_entry(entry):
		if not (cell is Vector2i):
			continue
		if cell.x < 0 or cell.y < 0 or cell.x >= _map_size.x or cell.y >= _map_size.y:
			continue
		cells.append(cell)
	return cells

func _town_footprint_cells_for_entry(entry: Vector2i) -> Array:
	var cells := []
	var origin := _town_footprint_origin_for_entry(entry)
	for y_offset in range(TOWN_PRESENTATION_FOOTPRINT.y):
		for x_offset in range(TOWN_PRESENTATION_FOOTPRINT.x):
			cells.append(origin + Vector2i(x_offset, y_offset))
	return cells

func _has_resource_at(tile: Vector2i) -> bool:
	return not _resource_node_at(tile).is_empty()

func _resource_node_at(tile: Vector2i) -> Dictionary:
	return _resources_by_tile.get(_tile_key(tile), {})

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
	return _artifacts_by_tile.get(_tile_key(tile), {})

func _has_encounter_at(tile: Vector2i) -> bool:
	return _encounters_by_tile.has(_tile_key(tile))

func _has_rememberable_encounter_at(tile: Vector2i) -> bool:
	return _rememberable_encounters_by_tile.has(_tile_key(tile))

func _has_hero_at(tile: Vector2i) -> bool:
	return _heroes_by_tile.has(_tile_key(tile))

func _reserve_hero_count(tile: Vector2i) -> int:
	var reserve_count = 0
	for entry in _heroes_by_tile.get(_tile_key(tile), []):
		if not (entry is Dictionary):
			continue
		if not bool(entry.get("is_active", false)):
			reserve_count += 1
	return reserve_count

func _build_path(start: Vector2i, goal: Vector2i) -> Array:
	var detail_profile_enabled := _path_detail_profile_enabled
	if not detail_profile_enabled:
		_validation_profile.erase("last_path_recompute")
	if _session == null or goal.x < 0 or goal.y < 0:
		_profile_path_recompute_details(detail_profile_enabled, start, goal, "missing_session_or_goal", 0, 0, 0, 0)
		return []
	if start == goal:
		_profile_path_recompute_details(detail_profile_enabled, start, goal, "same_tile", 1, 1, 0, 0)
		return [start]
	if goal.x >= _map_size.x or goal.y >= _map_size.y:
		_profile_path_recompute_details(detail_profile_enabled, start, goal, "goal_out_of_bounds", 0, 0, 0, 0)
		return []
	if OverworldRulesScript.tile_is_blocked(_session, goal.x, goal.y):
		_profile_path_recompute_details(detail_profile_enabled, start, goal, "goal_blocked", 0, 0, 1 if detail_profile_enabled else 0, 0)
		return []
	if not OverworldRulesScript.is_tile_explored(_session, goal.x, goal.y):
		_profile_path_recompute_details(detail_profile_enabled, start, goal, "goal_unexplored", 0, 0, 1 if detail_profile_enabled else 0, 0)
		return []

	var queue: Array = [start]
	var queue_index := 0
	var visited = {_tile_key(start): true}
	var came_from = {_tile_key(start): start}
	var found = false
	var blocked_tile_lookup_count := 1 if detail_profile_enabled else 0
	var enqueued_count := 1 if detail_profile_enabled else 0

	while queue_index < queue.size():
		var current: Vector2i = queue[queue_index]
		queue_index += 1
		if current == goal:
			found = true
			break
		for direction in DIRECTIONS:
			var next: Vector2i = current + direction
			if next.x < 0 or next.y < 0 or next.x >= _map_size.x or next.y >= _map_size.y:
				continue
			if detail_profile_enabled:
				blocked_tile_lookup_count += 1
			if OverworldRulesScript.tile_is_blocked(_session, next.x, next.y):
				continue
			var key = _tile_key(next)
			if visited.has(key):
				continue
			visited[key] = true
			came_from[key] = current
			queue.append(next)
			if detail_profile_enabled:
				enqueued_count += 1

	if not found:
		_profile_path_recompute_details(detail_profile_enabled, start, goal, "not_found", 0, visited.size() if detail_profile_enabled else 0, blocked_tile_lookup_count, enqueued_count)
		return []

	var path: Array = [goal]
	var walker: Vector2i = goal
	while walker != start:
		walker = came_from.get(_tile_key(walker), start)
		path.push_front(walker)
	_profile_path_recompute_details(detail_profile_enabled, start, goal, "found", path.size(), visited.size() if detail_profile_enabled else 0, blocked_tile_lookup_count, enqueued_count)
	return path

func _profile_path_recompute_details(
	enabled: bool,
	start: Vector2i,
	goal: Vector2i,
	status: String,
	path_size: int,
	visited_count: int,
	blocked_tile_lookup_count: int,
	enqueued_count: int
) -> void:
	if not enabled:
		return
	_validation_profile["last_path_recompute"] = {
		"start": {"x": start.x, "y": start.y},
		"goal": {"x": goal.x, "y": goal.y},
		"status": status,
		"path_tiles": path_size,
		"visited_count": visited_count,
		"blocked_tile_lookup_count": blocked_tile_lookup_count,
		"enqueued_count": enqueued_count,
	}

func _tile_key(tile: Vector2i) -> String:
	return "%d,%d" % [tile.x, tile.y]
