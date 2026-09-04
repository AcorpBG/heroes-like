extends Control

signal tile_pressed(tile: Vector2i)
signal tile_hovered(tile: Vector2i)
signal spell_cast_presentation_blocking_changed(blocking: bool)

const HeroCommandRulesScript = preload("res://scripts/core/HeroCommandRules.gd")
const OverworldRulesScript = preload("res://scripts/core/OverworldRules.gd")
const TerrainPlacementRulesScript = preload("res://scripts/core/TerrainPlacementRules.gd")
const FrontierVisualKitScript = preload("res://scripts/ui/FrontierVisualKit.gd")

const OVERWORLD_ART_MANIFEST_PATH := "res://art/overworld/manifest.json"
const OVERWORLD_VFX_MANIFEST_PATH := "res://content/overworld_vfx_manifest.json"
const TERRAIN_GRAMMAR_PATH := "res://content/terrain_grammar.json"
const MAP_PADDING := 22.0
const TACTICAL_VISIBLE_TILE_SPAN := 16.0
const TACTICAL_VISIBLE_TILE_AREA := TACTICAL_VISIBLE_TILE_SPAN * TACTICAL_VISIBLE_TILE_SPAN
const MIN_TILE_EXTENT := 24.0
const MAX_SMALL_MAP_FIT_TILE_EXTENT := 104.0
const UNEXPLORED_SHROUD_MODEL := "continuous_identity_silent_textured_cartographic_veil"
const UNEXPLORED_SHROUD_BASE := Color(0.13, 0.16, 0.16, 0.16)
const UNEXPLORED_SHROUD_LAYER_COUNT := 2
const UNEXPLORED_SHROUD_TEXTURE_PATH := "res://art/overworld/runtime/fog/unexplored_cartographic_veil_rich.png"
const UNEXPLORED_SHROUD_TEXTURE_SIZE := Vector2i(1024, 1024)
const UNEXPLORED_SHROUD_TEXTURE_MODULATE := Color(0.80, 0.88, 0.82, 0.80)
const EXPLORED_TERRAIN_GRID_ALPHA := 0.0
const EXPLORED_TERRAIN_GRID_MODE := "fog_boundary_only"
const EXPLORED_FOG_FRONTIER_MODEL := "segmented_deep_inward_cartographic_veil_feather"
const EXPLORED_FOG_FRONTIER_SURFACE_MODEL := "boundary_cap_plus_contour_segment_quads"
const EXPLORED_FOG_FRONTIER_DEPTH_FACTOR := 0.32
const EXPLORED_FOG_FRONTIER_CAP_ALPHA := 0.54
const EXPLORED_FOG_FRONTIER_EDGE_ALPHA := 0.34
const EXPLORED_FOG_FRONTIER_INNER_ALPHA := 0.0
const EXPLORED_FOG_FRONTIER_COLOR := Color(0.025, 0.035, 0.045, 1.0)
const EXPLORED_TERRAIN_FOG_BOUNDARY_COLOR := Color(0.08, 0.10, 0.12, 0.22)
const EXPLORED_TERRAIN_FOG_BOUNDARY_WIDTH := 1.0
const EXPLORED_FOG_CONTOUR_POINT_COUNT := 9
const EXPLORED_FOG_CONTOUR_MIN_INSET_FACTOR := 0.05
const EXPLORED_FOG_CONTOUR_MAX_INSET_FACTOR := 0.14
const FRAME_COLOR := Color(0.73, 0.63, 0.42, 0.9)
const FRAME_FILL := Color(0.07, 0.10, 0.11, 1.0)
const SMALL_MAP_CARTOGRAPHIC_MATTE_MODEL := "quiet_survey_field_below_playable_board"
const SMALL_MAP_CARTOGRAPHIC_MATTE_MIN_GUTTER := 48.0
const SMALL_MAP_CARTOGRAPHIC_MATTE_GRID_SPACING := 72.0
const SMALL_MAP_CARTOGRAPHIC_MATTE_BOARD_SHADOW_EXTENT := 14.0
const SMALL_MAP_CARTOGRAPHIC_MATTE_FILL := Color(0.055, 0.085, 0.082, 1.0)
const SMALL_MAP_CARTOGRAPHIC_MATTE_GRID := Color(0.42, 0.52, 0.42, 0.075)
const SMALL_MAP_CARTOGRAPHIC_MATTE_CONTOUR := Color(0.64, 0.57, 0.38, 0.10)
const SMALL_MAP_CARTOGRAPHIC_MATTE_ORNAMENT := Color(0.77, 0.67, 0.43, 0.25)
const SMALL_MAP_CARTOGRAPHIC_MATTE_BOARD_EDGE := Color(0.79, 0.69, 0.46, 0.34)
const UNEXPLORED_COLOR := Color(0.04, 0.05, 0.06, 1.0)
const MEMORY_OBJECT_COLOR := Color(0.72, 0.80, 0.82, 0.84)
const MEMORY_OBJECT_OUTLINE := Color(0.92, 0.96, 0.91, 0.76)
const SELECTION_COLOR := Color(0.98, 0.87, 0.46, 1.0)
const TOWN_SELECTION_VISUAL_MODEL := "open_cartographic_footprint_corner_and_midpoint_ticks"
const TOWN_SELECTION_PERIMETER_INSET_FACTOR := 0.045
const TOWN_SELECTION_CORNER_ALPHA := 0.78
const TOWN_SELECTION_CORNER_LENGTH_FACTOR := 0.10
const TOWN_SELECTION_CORNER_WIDTH_FACTOR := 0.010
const TOWN_SELECTION_MIDPOINT_ALPHA := 0.34
const TOWN_SELECTION_MIDPOINT_LENGTH_FACTOR := 0.035
const TOWN_SELECTION_MIDPOINT_WIDTH_FACTOR := 0.008
const TILE_SELECTION_VISUAL_MODEL := "open_cartographic_tile_corner_and_midpoint_ticks"
const TILE_SELECTION_PERIMETER_INSET_FACTOR := 0.085
const TILE_SELECTION_CORNER_ALPHA := 0.82
const TILE_SELECTION_CORNER_LENGTH_FACTOR := 0.18
const TILE_SELECTION_CORNER_WIDTH_FACTOR := 0.022
const TILE_SELECTION_MIDPOINT_ALPHA := 0.42
const TILE_SELECTION_MIDPOINT_LENGTH_FACTOR := 0.08
const TILE_SELECTION_MIDPOINT_WIDTH_FACTOR := 0.016
const HERO_COMMAND_FOCUS_VISUAL_MODEL := "open_lateral_command_wings_and_ground_tick"
const HERO_COMMAND_FOCUS_INSET_FACTOR := 0.035
const HERO_COMMAND_FOCUS_INSET_MIN_PX := 1.25
const HERO_COMMAND_FOCUS_CENTER_Y_FACTOR := 0.48
const HERO_COMMAND_FOCUS_WING_LENGTH_FACTOR := 0.075
const HERO_COMMAND_FOCUS_WING_LENGTH_MIN_PX := 2.5
const HERO_COMMAND_FOCUS_WING_DEPTH_FACTOR := 0.085
const HERO_COMMAND_FOCUS_WING_DEPTH_MIN_PX := 3.0
const HERO_COMMAND_FOCUS_GROUND_Y_FACTOR := 0.82
const HERO_COMMAND_FOCUS_GROUND_TICK_LENGTH_FACTOR := 0.18
const HERO_COMMAND_FOCUS_GROUND_NOTCH_FACTOR := 0.035
const HERO_COMMAND_FOCUS_ALPHA := 0.82
const HERO_COMMAND_FOCUS_SHADOW_ALPHA := 0.40
const HOSTILE_ACTOR_MARKER_MODEL := "open_hostile_flank_chevrons_and_threat_notch"
const HOSTILE_ACTOR_MARKER_OUTSET_FACTOR := 0.035
const HOSTILE_ACTOR_MARKER_FLANK_LENGTH_FACTOR := 0.11
const HOSTILE_ACTOR_MARKER_FLANK_DEPTH_FACTOR := 0.10
const HOSTILE_ACTOR_MARKER_NOTCH_WIDTH_FACTOR := 0.14
const HOSTILE_ACTOR_MARKER_NOTCH_DEPTH_FACTOR := 0.07
const HOSTILE_ACTOR_MARKER_LINE_WIDTH_FACTOR := 0.020
const HOSTILE_ACTOR_MARKER_VISIBLE_ALPHA := 0.86
const HOSTILE_ACTOR_MARKER_MEMORY_ALPHA := 0.62
const HOSTILE_ACTOR_MARKER_SHADOW_ALPHA := 0.42
const HOVER_COLOR := Color(0.92, 0.95, 0.98, 0.55)
const HOVER_RETICLE_VISUAL_MODEL := "open_cartographic_hover_corners"
const HOVER_RETICLE_PERIMETER_INSET_FACTOR := 0.10
const HOVER_RETICLE_PERIMETER_INSET_MIN_PX := 6.0
const HOVER_RETICLE_PERIMETER_INSET_MAX_PX := 18.0
const HOVER_RETICLE_CORNER_LENGTH_FACTOR := 0.12
const HOVER_RETICLE_CORNER_LENGTH_MIN_PX := 6.0
const HOVER_RETICLE_CORNER_LENGTH_MAX_PX := 18.0
const HOVER_RETICLE_CORNER_WIDTH_FACTOR := 0.014
const HOVER_RETICLE_CORNER_WIDTH_MIN_PX := 1.25
const HOVER_RETICLE_CORNER_WIDTH_MAX_PX := 2.0
const HOVER_RETICLE_SHADOW_ALPHA := 0.24
const HOVER_RETICLE_SHADOW_WIDTH_ADD_PX := 1.25
const HOVER_TOOLTIP_VISUAL_MODEL := "contained_cartographic_hover_card"
const HOVER_TOOLTIP_CONTENT_WIDTH_FACTOR := 0.34
const HOVER_TOOLTIP_CONTENT_WIDTH_MIN_PX := 280.0
const HOVER_TOOLTIP_CONTENT_WIDTH_MAX_PX := 420.0
const HOVER_TOOLTIP_MAX_LINES := 4
const HOVER_TOOLTIP_MARGIN_HORIZONTAL_PX := 12
const HOVER_TOOLTIP_MARGIN_VERTICAL_PX := 9
const HOVER_TOOLTIP_PANEL_COLOR := Color(0.035, 0.050, 0.045, 0.96)
const HOVER_TOOLTIP_BORDER_COLOR := Color(0.64, 0.57, 0.38, 0.86)
const HOVER_TOOLTIP_TEXT_COLOR := Color(0.93, 0.91, 0.82, 1.0)
const HOVER_TOOLTIP_SHADOW_COLOR := Color(0.01, 0.015, 0.012, 0.72)
const HOVER_TOOLTIP_BORDER_WIDTH_PX := 1
const HOVER_TOOLTIP_CORNER_RADIUS_PX := 3
const HOVER_TOOLTIP_SHADOW_SIZE_PX := 6
const HOVER_TOOLTIP_SHADOW_OFFSET := Vector2(0.0, 3.0)
const HERO_RING_COLOR := Color(0.98, 0.94, 0.72, 1.0)
const HERO_FILL_COLOR := Color(0.88, 0.32, 0.21, 1.0)
const RESERVE_HERO_COLOR := Color(0.87, 0.90, 0.94, 1.0)
const ROUTE_COLOR := Color(0.97, 0.86, 0.43, 0.82)
const ROUTE_BLOCKED_COLOR := Color(0.87, 0.43, 0.33, 0.86)
const ROUTE_VISUAL_MODEL := "layered_cartographic_trail_open_waypoints_destination_chevron"
const ROUTE_SHADOW_COLOR := Color(0.035, 0.028, 0.018, 0.50)
const ROUTE_SHADOW_WIDTH_FACTOR := 0.040
const ROUTE_CORE_WIDTH_FACTOR := 0.018
const ROUTE_HIGHLIGHT_WIDTH_FACTOR := 0.006
const ROUTE_HIGHLIGHT_ALPHA := 0.42
const ROUTE_STITCH_LENGTH_FACTOR := 0.045
const ROUTE_STITCH_WIDTH_FACTOR := 0.010
const ROUTE_STITCH_ALPHA := 0.64
const ROUTE_WAYPOINT_RADIUS_FACTOR := 0.030
const ROUTE_DESTINATION_LENGTH_FACTOR := 0.075
const ROUTE_DESTINATION_DEPTH_FACTOR := 0.045
const PLACEMENT_DEBUG_BLOCKER_FILL := Color(1.0, 0.06, 0.04, 0.36)
const PLACEMENT_DEBUG_BLOCKER_BORDER := Color(1.0, 0.17, 0.12, 0.86)
const PLACEMENT_DEBUG_INTERACTABLE_FILL := Color(1.0, 0.86, 0.08, 0.38)
const PLACEMENT_DEBUG_INTERACTABLE_BORDER := Color(1.0, 0.96, 0.32, 0.88)
const TERRAIN_COLORS := {
	"grass": Color(0.41, 0.62, 0.31, 1.0),
	"forest": Color(0.23, 0.43, 0.25, 1.0),
	"water": Color(0.20, 0.41, 0.66, 1.0),
	"mire": Color(0.30, 0.38, 0.25, 1.0),
	"swamp": Color(0.27, 0.35, 0.23, 1.0),
	"rough": Color(0.48, 0.48, 0.36, 1.0),
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
const WORLD_OBJECT_SCALE_HIERARCHY_MODEL := "classic_readable_semantic_landmark_bands_v6"
const OBJECT_HANDHELD_ARTIFACT_VISIBLE_EXTENT_TILES := 0.58
const OBJECT_LOOSE_PICKUP_VISIBLE_EXTENT_TILES := 0.68
const OBJECT_ENCOUNTER_VISIBLE_EXTENT_TILES := 0.88
const OBJECT_FACTION_ENCOUNTER_VISIBLE_EXTENT_TILES := 1.08
const OBJECT_DURABLE_VISIBLE_EXTENT_TILES := 0.82
const OBJECT_WAYPOINT_VISIBLE_EXTENT_TILES := 0.78
const OBJECT_LANDMARK_VISIBLE_EXTENT_TILES := 0.94
const OBJECT_BLOCKER_VISIBLE_EXTENT_TILES := 0.92
const OBJECT_DECORATION_VISIBLE_EXTENT_TILES := 0.46
const OBJECT_DEFAULT_VISIBLE_EXTENT_TILES := 0.62
const MULTI_TILE_INTERACTIVE_SPRITE_EXTENT_BASE_MIN_TILES := 0.78
const MULTI_TILE_INTERACTIVE_SPRITE_EXTENT_SPAN_MIN_STEP_TILES := 0.10
const MULTI_TILE_INTERACTIVE_SPRITE_EXTENT_DEPTH_MIN_STEP_TILES := 0.12
const MULTI_TILE_INTERACTIVE_SPRITE_EXTENT_BASE_CAP_TILES := 0.92
const MULTI_TILE_INTERACTIVE_SPRITE_EXTENT_SPAN_CAP_STEP_TILES := 0.14
const MULTI_TILE_INTERACTIVE_SPRITE_EXTENT_DEPTH_CAP_STEP_TILES := 0.16
const MULTI_TILE_INTERACTIVE_SPRITE_EXTENT_ABSOLUTE_CAP_TILES := 1.35
const OBJECT_VISIBLE_FOOTPRINT_INSET_TILES := 0.02
const OBJECT_PAINTED_BOUNDS_PADDING_PIXELS := 1
const OBJECT_MIN_PAINTED_EXTENT_FRACTION := 0.34
const OBJECT_VISIBLE_SCALE_MODEL := "cached_alpha_bounds_semantic_visible_extent"
const GENERATED_DECORATIVE_BODY_SPRITE_EXTENT_TILES := 1.20
const GENERATED_DECORATIVE_BODY_SCALE_FACTOR_MIN := 0.93
const GENERATED_DECORATIVE_BODY_SCALE_FACTOR_MAX := 1.07
const GENERATED_DECORATIVE_BODY_ASSET_CLUSTER_TILES := 4
const GENERATED_DECORATIVE_BODY_OFFSET_X_TILES := 0.12
const GENERATED_DECORATIVE_BODY_OFFSET_Y_MIN_TILES := -0.04
const GENERATED_DECORATIVE_BODY_OFFSET_Y_MAX_TILES := 0.04
const GENERATED_DECORATIVE_BODY_MASS_SMALL_EXTENT_TILES := 1.52
const GENERATED_DECORATIVE_BODY_MASS_MEDIUM_EXTENT_TILES := 1.90
const GENERATED_DECORATIVE_BODY_MASS_LARGE_EXTENT_TILES := 2.28
const GENERATED_DECORATIVE_BODY_MASS_BOUNDS_MARGIN_TILES := 0.52
const GENERATED_DECORATIVE_BODY_PRESENTATION_MODEL := "exact_body_cells_overlapping_landscape_mass_anchors_v4"
const GENERATED_DECORATIVE_BIOME_BY_TERRAIN := {
	"grass": "biome_grasslands",
	"forest": "biome_deep_forest",
	"mire": "biome_mire_fen",
	"swamp": "biome_mire_fen",
	"rough": "biome_highland_ridge",
	"rock": "biome_highland_ridge",
	"badlands": "biome_rough_badlands",
	"sand": "biome_rough_badlands",
	"dirt": "biome_rough_badlands",
	"ash": "biome_ash_lava_wastes",
	"lava": "biome_ash_lava_wastes",
	"snow": "biome_snow_frost_marches",
	"water": "biome_coast_archipelago",
	"coast": "biome_coast_archipelago",
	"cavern": "biome_subterranean_underways",
	"underground": "biome_subterranean_underways",
}
const OBJECT_SPRITE_VISIBLE_MODULATE := Color(1.0, 1.0, 1.0, 1.0)
const OBJECT_SPRITE_DECORATION_MODULATE := Color(0.82, 0.84, 0.78, 0.82)
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
const HERO_FIELD_LAYOUT_MODE := "full_tile_world_hero"
const HERO_TOWN_FOOTPRINT_LAYOUT_MODE := "compact_town_footprint_visitor"
const HERO_FIELD_SPRITE_EXTENT_FACTOR := 0.86
const HERO_SPRITE_LIFT_FACTOR := 0.25
const HERO_GROUND_ANCHOR_Y_FACTOR := 0.72
const HERO_TOWN_FOOTPRINT_VISITOR_RECT_EXTENT_FACTOR := 0.76
const HERO_TOWN_FOOTPRINT_VISITOR_SPRITE_EXTENT_FACTOR := 0.68
const HERO_TOWN_FOOTPRINT_VISITOR_RECT_CENTER_Y_FACTOR := 0.61
const WORLD_SPRITE_SILHOUETTE_MODEL := "eight_direction_alpha_silhouette_outline"
const TOWN_SPRITE_SILHOUETTE_WIDTH_FACTOR := 0.010
const TOWN_SPRITE_SILHOUETTE_MIN_PX := 1.4
const TOWN_SPRITE_SILHOUETTE_VISIBLE := Color(0.012, 0.014, 0.010, 0.88)
const TOWN_SPRITE_SILHOUETTE_MEMORY := Color(0.18, 0.31, 0.34, 0.78)
const HERO_SPRITE_SILHOUETTE_WIDTH_FACTOR := 0.024
const HERO_SPRITE_SILHOUETTE_MIN_PX := 1.35
const HERO_SPRITE_SILHOUETTE_COLOR := Color(0.010, 0.012, 0.010, 0.92)
const OBJECT_INTERACTIVE_SILHOUETTE_WIDTH_FACTOR := 0.024
const OBJECT_INTERACTIVE_SILHOUETTE_MIN_PX := 1.15
const OBJECT_INTERACTIVE_SILHOUETTE_VISIBLE := Color(0.010, 0.012, 0.009, 0.90)
const OBJECT_INTERACTIVE_SILHOUETTE_MEMORY := Color(0.16, 0.28, 0.30, 0.74)
const HERO_COMMAND_PENNANT_MODEL := "compact_player_command_flag"
const HERO_COMMAND_PENNANT_WIDTH_FACTOR := 0.19
const HERO_COMMAND_PENNANT_HEIGHT_FACTOR := 0.12
const HERO_COMMAND_PENNANT_POLE_HEIGHT_FACTOR := 0.43
const HERO_COMMAND_PENNANT_ALPHA := 0.96
const HERO_COMMAND_PENNANT_ASSET_EXTENT_FACTOR := 0.60
const TOWN_PRESENTATION_MODEL := "town_3x4_visual_landmark_3x2_logical_bottom_middle_entry"
const TOWN_GROUNDING_MODEL := "tall_town_landmark_settled_without_base_ellipse"
const TOWN_ANCHOR_STYLE := "town_contact_cues_no_base_ellipse"
const TOWN_DEPTH_CUE_MODEL := "tall_town_entry_ground_contact_without_cast_shadow"
const TOWN_FOOTPRINT_CUE_MODEL := "no_visible_helper_cues_3x2_contract"
const TOWN_ENTRY_ROLE := "bottom_middle_visit_approach"
const TOWN_NON_ENTRY_ROLE := "blocked_non_entry_footprint"
const TOWN_PRESENTATION_FOOTPRINT := Vector2i(3, 2)
const TOWN_ENTRY_OFFSET := Vector2i(1, 1)
const TOWN_VISUAL_FOOTPRINT := Vector2i(3, 4)
const TOWN_VISUAL_ANCHOR_MODEL := "three_by_four_entry_center_bottom"
const TOWN_SPRITE_EXTENT_FACTOR := 1.24
const TOWN_SPRITE_WIDTH_CAP_TILES := 2.90
const TOWN_SPRITE_GROUND_CLEARANCE_TILES := 0.18
const TOWN_ADJUNCT_RESOURCE_LAYOUT_MODEL := "compact_outward_edge_town_footprint_resource"
const TOWN_ADJUNCT_RESOURCE_EXTENT_FACTOR := 0.64
const TOWN_ADJUNCT_RESOURCE_VISIBLE_EXTENT_CAP_TILES := 0.56
const TOWN_OWNER_PENNANT_MODEL := "single_pass_compact_heraldic_cloth_pennant"
const TOWN_OWNER_PENNANT_WIDTH_FACTOR := 0.052
const TOWN_OWNER_PENNANT_HEIGHT_FACTOR := 0.040
const TOWN_OWNER_PENNANT_POLE_HEIGHT_FACTOR := 0.128
const TOWN_OWNER_PENNANT_LEGACY_WIDTH_FACTOR := 0.17
const TOWN_OWNER_PENNANT_LEGACY_HEIGHT_FACTOR := 0.12
const TOWN_OWNER_PENNANT_CLOTH_ALPHA := 0.96
const TOWN_OWNER_PENNANT_MEMORY_ALPHA := 0.68
const TOWN_OWNER_PENNANT_SHADOW_ALPHA := 0.42
const TOWN_OWNER_PENNANT_FOLD_ALPHA := 0.34
const TOWN_OWNER_PENNANT_HIGHLIGHT_ALPHA := 0.42
const TOWN_OWNER_PENNANT_SHADOW_OFFSET_FACTOR := 0.010
const TOWN_OWNER_PENNANT_OUTLINE_WIDTH_FACTOR := 0.014
const TOWN_OWNER_PENNANT_ASSET_EXTENT_FACTOR := 0.54
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
const TERRAIN_TRANSITION_DRAW_POLICY := "active_homm3_self_contained_else_generic_overlay"
const TERRAIN_HOMM3_SOURCE_BASIS := "homm3_extracted_local_reference_prototype"
const TERRAIN_HOMM3_UNSUPPORTED_POLICY := "explicit_grammar_fallback"
const TERRAIN_HOMM3_INTERIOR_SELECTION_MODEL := "accepted_web_full_row_bucket_selection"
const TERRAIN_EDITOR_RESTAMP_MODEL := "source_paint_known_receiver_offsets_shared_overworld_reprojection.v1"
const TERRAIN_EDITOR_RESTAMP_SCOPE := "map_editor_terrain_paint_update_and_shared_preview"
const TERRAIN_TRANSITION_ALPHA := 0.42
const TERRAIN_TRANSITION_WIDTH_FACTOR := 0.16
const TERRAIN_TRANSITION_CORNER_ALPHA := 0.34
const TERRAIN_TRANSITION_CORNER_FACTOR := 0.24
const GENERIC_TERRAIN_EDGE_SURFACE_MODEL := "layered_feathered_organic_intrusion"
const GENERIC_TERRAIN_EDGE_FEATHER_BAND_COUNT := 2
const GENERIC_TERRAIN_EDGE_OUTER_ALPHA := 0.30
const GENERIC_TERRAIN_EDGE_INNER_ALPHA := 0.15
const GENERIC_TERRAIN_EDGE_SEAM_ALPHA := 0.30
const GENERIC_TERRAIN_EDGE_OUTER_DEPTH_FACTOR := 0.34
const GENERIC_TERRAIN_EDGE_INNER_DEPTH_FACTOR := 0.18
const WATER_SHORELINE_CONTOUR_MODEL := "shared_lattice_nine_sample_layered_natural_bank"
const WATER_TRANSITION_EDGE_ART_MODEL := "authored_texture_feathered_to_shared_lattice_profile"
const WATER_TRANSITION_EDGE_ART_ALPHA := 0.46
const WATER_TRANSITION_EDGE_CLIP_DEPTH_FACTOR := 0.125
const WATER_SHORELINE_PROFILE_SAMPLE_COUNT := 9
const WATER_SHORELINE_BANK_DEPTH_FACTOR := 0.18
const WATER_SHORELINE_SHALLOW_DEPTH_FACTOR := 0.135
const WATER_SHORELINE_WET_EDGE_DEPTH_FACTOR := 0.095
const WATER_SHORELINE_FOAM_DEPTH_FACTOR := 0.070
const WATER_SHORELINE_BANK_COLOR := Color(0.34, 0.28, 0.15, 0.18)
const WATER_SHORELINE_SHALLOW_COLOR := Color(0.27, 0.55, 0.59, 0.14)
const WATER_SHORELINE_WET_EDGE_COLOR := Color(0.38, 0.32, 0.18, 0.26)
const WATER_SHORELINE_FOAM_SHADOW_COLOR := Color(0.035, 0.10, 0.12, 0.20)
const WATER_SHORELINE_FOAM_COLOR := Color(0.76, 0.89, 0.86, 0.30)
const WATER_SHORELINE_WET_EDGE_WIDTH_FACTOR := 0.014
const WATER_SHORELINE_FOAM_SHADOW_WIDTH_FACTOR := 0.024
const WATER_SHORELINE_FOAM_WIDTH_FACTOR := 0.012
const WATER_SHORELINE_FOAM_SEGMENTS_PER_EDGE := 3
const WATER_SURFACE_RIPPLE_MODEL := "deterministic_broken_painterly_current_pairs"
const WATER_SURFACE_RIPPLE_DENSITY_MODULUS := 3
const WATER_SURFACE_RIPPLE_ACTIVE_RESIDUES := [0, 1]
const WATER_SURFACE_RIPPLE_COUNT := 2
const WATER_SURFACE_RIPPLE_POINT_COUNT := 5
const WATER_SURFACE_RIPPLE_MIN_LENGTH_FACTOR := 0.26
const WATER_SURFACE_RIPPLE_MAX_LENGTH_FACTOR := 0.48
const WATER_SURFACE_RIPPLE_MIN_CURVE_FACTOR := 0.018
const WATER_SURFACE_RIPPLE_MAX_CURVE_FACTOR := 0.042
const WATER_SURFACE_RIPPLE_SHADOW_COLOR := Color(0.025, 0.11, 0.15, 0.24)
const WATER_SURFACE_RIPPLE_HIGHLIGHT_COLOR := Color(0.65, 0.86, 0.88, 0.30)
const WATER_SURFACE_RIPPLE_SHADOW_WIDTH_FACTOR := 0.024
const WATER_SURFACE_RIPPLE_HIGHLIGHT_WIDTH_FACTOR := 0.012
const TERRAIN_MACRO_LIGHTING_MODEL := "continuous_shared_corner_bilinear_field"
const TERRAIN_MACRO_LIGHTING_CELL_TILES := 12
const TERRAIN_MACRO_LIGHTING_CELL_SUBDIVISIONS := 1
const TERRAIN_MACRO_LIGHTING_SHADOW_MAX_ALPHA := 0.075
const TERRAIN_MACRO_LIGHTING_HIGHLIGHT_MAX_ALPHA := 0.040
const TERRAIN_MACRO_LIGHTING_SHADOW_COLOR := Color(0.025, 0.045, 0.060, 1.0)
const TERRAIN_MACRO_LIGHTING_HIGHLIGHT_COLOR := Color(0.96, 0.82, 0.56, 1.0)
const TERRAIN_GRAIN_TEXTURE_PATH := "res://art/overworld/runtime/terrain_tiles/detail/terrain_grain_overlay.png"
const TERRAIN_GRAIN_MODEL := "single_normalized_map_space_seamless_painterly_microtexture"
const TERRAIN_GRAIN_SOURCE_MODEL := "original_generated_neutral_grain_mirrored_seamless_alpha"
const TERRAIN_GRAIN_MODULATE := Color(1.0, 1.0, 1.0, 0.72)
const TERRAIN_GRAIN_EXPECTED_SIZE := Vector2i(1024, 1024)
const TERRAIN_MICROTEXTURE_MODEL := "deterministic_biome_tinted_brush_strokes_v1"
const TERRAIN_MICROTEXTURE_STROKE_COUNT := 5
const TERRAIN_MICROTEXTURE_MIN_LENGTH_FACTOR := 0.045
const TERRAIN_MICROTEXTURE_MAX_LENGTH_FACTOR := 0.13
const TERRAIN_MICROTEXTURE_SHADOW_ALPHA := 0.07
const TERRAIN_MICROTEXTURE_HIGHLIGHT_ALPHA := 0.13
const TERRAIN_DETAIL_DECAL_MODEL := "biome_specific_painterly_landmark_clusters_v3"
const TERRAIN_DETAIL_DECAL_SOURCE_MODEL := "built_in_imagegen_alpha_cleaned_4x4_world_surface_atlas"
const TERRAIN_DETAIL_DECAL_TEXTURE_PATH := "res://art/overworld/runtime/terrain_tiles/detail/terrain_detail_decal_atlas_world_v3.png"
const TERRAIN_DETAIL_DECAL_ATLAS_SIZE := Vector2i(1024, 1024)
const TERRAIN_DETAIL_DECAL_GRID_SIZE := Vector2i(4, 4)
const TERRAIN_DETAIL_DECAL_CELL_SIZE := Vector2i(256, 256)
const TERRAIN_DETAIL_DECAL_DENSITY_MODULUS := 9
const TERRAIN_DETAIL_DECAL_ACTIVE_RESIDUES := [0]
const TERRAIN_DETAIL_DECAL_MIN_EXTENT_FACTOR := 0.30
const TERRAIN_DETAIL_DECAL_MAX_EXTENT_FACTOR := 0.48
const TERRAIN_DETAIL_DECAL_MAX_OFFSET_X_FACTOR := 0.16
const TERRAIN_DETAIL_DECAL_MIN_OFFSET_Y_FACTOR := -0.08
const TERRAIN_DETAIL_DECAL_MAX_OFFSET_Y_FACTOR := 0.14
const TERRAIN_DETAIL_DECAL_MODULATE := Color(0.96, 0.98, 0.92, 0.74)
const TERRAIN_AMBIENT_MODEL := "deterministic_sparse_explored_tile_ambient_life"
const TERRAIN_AMBIENT_DRAW_ORDER := ["terrain_and_roads", "ambient_life", "fog_and_objects", "routes_and_selection", "vfx", "frame_and_ui"]
const TERRAIN_AMBIENT_PHASE_SPEED := 0.38
const TERRAIN_AMBIENT_STATIC_PHASE := 0.0
const TERRAIN_AMBIENT_DENSITY_MODULUS := 4
const TERRAIN_AMBIENT_PROFILES := {
	"grasslands": {"id": "meadow_pollen", "kind": "pollen", "color": Color(0.96, 0.86, 0.48, 1.0), "alpha": 0.20, "radius_factor": 0.020, "drift": Vector2(0.050, 0.065)},
	"forest": {"id": "woodland_firefly", "kind": "firefly", "color": Color(0.91, 0.95, 0.48, 1.0), "alpha": 0.28, "radius_factor": 0.019, "drift": Vector2(0.042, 0.055)},
	"mire": {"id": "fen_wisp", "kind": "wisp", "color": Color(0.48, 0.84, 0.76, 1.0), "alpha": 0.22, "radius_factor": 0.023, "drift": Vector2(0.052, 0.040)},
	"rough": {"id": "highland_dust", "kind": "dust", "color": Color(0.88, 0.70, 0.43, 1.0), "alpha": 0.15, "radius_factor": 0.018, "drift": Vector2(0.070, 0.025)},
	"rock": {"id": "ridge_dust", "kind": "dust", "color": Color(0.82, 0.74, 0.58, 1.0), "alpha": 0.14, "radius_factor": 0.018, "drift": Vector2(0.062, 0.022)},
	"sand": {"id": "desert_dust", "kind": "dust", "color": Color(0.94, 0.78, 0.48, 1.0), "alpha": 0.15, "radius_factor": 0.018, "drift": Vector2(0.078, 0.022)},
	"dirt": {"id": "roadside_dust", "kind": "dust", "color": Color(0.86, 0.70, 0.46, 1.0), "alpha": 0.14, "radius_factor": 0.018, "drift": Vector2(0.072, 0.023)},
	"ash": {"id": "ash_ember", "kind": "ember", "color": Color(1.0, 0.48, 0.24, 1.0), "alpha": 0.20, "radius_factor": 0.018, "drift": Vector2(0.038, 0.070)},
	"snow": {"id": "frost_glint", "kind": "frost", "color": Color(0.76, 0.91, 1.0, 1.0), "alpha": 0.20, "radius_factor": 0.018, "drift": Vector2(0.050, 0.042)},
	"underground": {"id": "cavern_spore", "kind": "wisp", "color": Color(0.62, 0.70, 0.94, 1.0), "alpha": 0.18, "radius_factor": 0.021, "drift": Vector2(0.040, 0.045)},
}
const ROAD_DEFAULT_COLOR := Color(0.72, 0.58, 0.34, 0.92)
const ROAD_DEFAULT_EDGE_COLOR := Color(0.35, 0.24, 0.15, 0.78)
const ROAD_DEFAULT_SHADOW_COLOR := Color(0.07, 0.05, 0.035, 0.58)
const ROAD_DEFAULT_CENTER_COLOR := Color(0.86, 0.74, 0.48, 0.55)
const ROAD_DEFAULT_WIDTH_FACTOR := 0.14
const ROAD_SOURCE_FRAME_RENDER_MODEL := "explicit_source_frame"
const ROAD_LAND_RENDER_MODEL := "layered_wheel_rutted_dirt_path"
const ROAD_WATER_RENDER_MODEL := "weathered_cross_planked_causeway"
const ROAD_LAND_WIDTH_FACTOR := 0.16
const ROAD_LAND_SHADOW_COLOR := Color(0.10, 0.07, 0.04, 0.22)
const ROAD_LAND_SHOULDER_COLOR := Color(0.34, 0.23, 0.13, 0.38)
const ROAD_LAND_EARTH_COLOR := Color(0.57, 0.42, 0.24, 0.58)
const ROAD_LAND_DUST_COLOR := Color(0.76, 0.62, 0.39, 0.16)
const ROAD_LAND_RUT_COLOR := Color(0.24, 0.16, 0.09, 0.48)
const ROAD_CAUSEWAY_WIDTH_FACTOR := 0.22
const ROAD_CAUSEWAY_SHADOW_COLOR := Color(0.055, 0.045, 0.035, 0.52)
const ROAD_CAUSEWAY_EDGE_COLOR := Color(0.24, 0.17, 0.10, 0.88)
const ROAD_CAUSEWAY_DECK_COLOR := Color(0.48, 0.34, 0.19, 0.96)
const ROAD_CAUSEWAY_GRAIN_COLOR := Color(0.67, 0.49, 0.27, 0.64)
const ROAD_CAUSEWAY_SEAM_COLOR := Color(0.18, 0.12, 0.075, 0.78)
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
const HERO_MOVEMENT_MIN_DURATION_MSEC := 80
const HERO_MOVEMENT_MAX_DURATION_MSEC := 700
const OBJECT_RESOLUTION_MIN_DURATION_MSEC := 60
const OBJECT_RESOLUTION_MAX_DURATION_MSEC := 700
const ROUTE_BLOCKED_MIN_DURATION_MSEC := 60
const ROUTE_BLOCKED_MAX_DURATION_MSEC := 700
const SPELL_CAST_MIN_DURATION_MSEC := 80
const SPELL_CAST_MAX_DURATION_MSEC := 700

@export var large_map_visible_tile_span_override := 0.0

var _session = null
var _map_data: Array = []
var _map_size := Vector2i.ONE
var _selected_tile := Vector2i(-1, -1)
var _hover_tile := Vector2i(-1, -1)
var _hero_tile := Vector2i.ZERO
var _path_tiles: Array = []
var _route_preview: Dictionary = {}
var _route_preview_enabled := true
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
var _overworld_vfx_manifest: Dictionary = {}
var _overworld_vfx_manifest_loaded := false
var _overworld_vfx_textures: Dictionary = {}
var _overworld_vfx_texture_missing: Dictionary = {}
var _object_asset_paths: Dictionary = {}
var _object_asset_regions: Dictionary = {}
var _object_textures: Dictionary = {}
var _object_texture_missing: Dictionary = {}
var _object_texture_visible_regions: Dictionary = {}
var _ownership_pennant_asset_ids: Dictionary = {}
var _unit_art_textures: Dictionary = {}
var _unit_art_texture_missing: Dictionary = {}
var _resource_site_asset_ids: Dictionary = {}
var _resource_site_unclaimed_asset_ids: Dictionary = {}
var _resource_site_object_profiles: Dictionary = {}
var _map_object_asset_ids: Dictionary = {}
var _artifact_default_asset_id := ""
var _artifact_field_asset_ids: Dictionary = {}
var _town_default_asset_id := ""
var _town_identity_asset_ids: Dictionary = {}
var _town_faction_asset_ids: Dictionary = {}
var _hero_identity_asset_ids: Dictionary = {}
var _hero_faction_asset_ids: Dictionary = {}
var _encounter_faction_asset_ids: Dictionary = {}
var _encounter_faction_cache: Dictionary = {}
var _encounter_identity_asset_ids: Dictionary = {}
var _encounter_default_asset_id := ""
var _session_static_layer: Control = null
var _terrain_ambient_layer: Control = null
var _state_layer: Control = null
var _dynamic_layer: Control = null
var _frame_layer: Control = null
var _draw_canvas_item: CanvasItem = null
var _session_static_cache_signature := 0
var _state_cache_signature := 0
var _session_static_cache_generation := 0
var _terrain_ambient_generation := 0
var _state_cache_generation := 0
var _dynamic_layer_generation := 0
var _frame_layer_generation := 0
var _session_static_cache_reason := "uninitialized"
var _terrain_ambient_reason := "uninitialized"
var _state_cache_reason := "uninitialized"
var _dynamic_layer_reason := "uninitialized"
var _frame_layer_reason := "uninitialized"
var _object_index_signature := 0
var _hero_index_signature := 0
var _road_index_signature := 0
var _validation_force_index_rebuild := false
var _path_detail_profile_enabled := false
var _validation_profile: Dictionary = {}
var _terrain_ambient_phase := TERRAIN_AMBIENT_STATIC_PHASE
var _towns_by_tile: Dictionary = {}
var _town_footprints_by_tile: Dictionary = {}
var _resources_by_tile: Dictionary = {}
var _artifacts_by_tile: Dictionary = {}
var _encounters_by_tile: Dictionary = {}
var _rememberable_encounters_by_tile: Dictionary = {}
var _decorative_objects_by_tile: Dictionary = {}
var _generated_decorative_bodies_by_tile: Dictionary = {}
var _standalone_map_objects_by_tile: Dictionary = {}
var _heroes_by_tile: Dictionary = {}
var _decorative_object_asset_ids: Dictionary = {}
var _generated_decorative_blocker_asset_ids_by_biome: Dictionary = {}
var _generated_decorative_blocker_fallback_asset_ids: Array = []
var _map_object_content_profiles: Dictionary = {}
var _placement_debug_overlay_enabled := false
var _hero_movement_last_serial := 0
var _hero_movement_path: Array = []
var _hero_movement_elapsed_sec := 0.0
var _hero_movement_duration_sec := 0.0
var _hero_movement_active := false
var _hero_movement_event_id := ""
var _hero_movement_animation_state := ""
var _hero_movement_visual_policy := ""
var _hero_movement_fallback_tag := ""
var _hero_movement_vfx_cue_ids: Array = []
var _hero_movement_audio_cue_ids: Array = []
var _hero_movement_audio_playback_records: Array = []
var _hero_movement_reduced_motion := false
var _hero_movement_last_draw: Dictionary = {}
var _object_focus_active := false
var _object_focus_tile := Vector2i(-1, -1)
var _object_focus_event_id := ""
var _object_focus_cue_id := ""
var _object_focus_input_source := ""
var _object_focus_kind := ""
var _object_focus_id := ""
var _object_focus_animation_state := ""
var _object_focus_visual_policy := ""
var _object_focus_fallback_tag := ""
var _object_focus_playback_policy := ""
var _object_focus_blocking_policy := ""
var _object_focus_vfx_cue_ids: Array = []
var _object_focus_audio_cue_ids: Array = []
var _object_focus_audio_playback_records: Array = []
var _object_focus_context_signature := ""
var _object_focus_allows_large_motion := false
var _object_focus_last_draw: Dictionary = {}
var _object_resolution_last_serial := 0
var _object_resolution_tile := Vector2i(-1, -1)
var _object_resolution_elapsed_sec := 0.0
var _object_resolution_duration_sec := 0.0
var _object_resolution_active := false
var _object_resolution_queued := false
var _object_resolution_event_id := ""
var _object_resolution_animation_state := ""
var _object_resolution_visual_policy := ""
var _object_resolution_fallback_tag := ""
var _object_resolution_vfx_cue_ids: Array = []
var _object_resolution_audio_cue_ids: Array = []
var _object_resolution_audio_playback_records: Array = []
var _object_resolution_family := ""
var _object_resolution_placement_id := ""
var _object_resolution_allows_large_motion := false
var _object_resolution_last_draw: Dictionary = {}
var _route_blocked_last_serial := 0
var _route_blocked_tile := Vector2i(-1, -1)
var _route_blocked_elapsed_sec := 0.0
var _route_blocked_duration_sec := 0.0
var _route_blocked_active := false
var _route_blocked_event_id := ""
var _route_blocked_animation_state := ""
var _route_blocked_visual_policy := ""
var _route_blocked_fallback_tag := ""
var _route_blocked_reason := ""
var _route_blocked_blocking_object: Dictionary = {}
var _route_blocked_vfx_cue_ids: Array = []
var _route_blocked_audio_cue_ids: Array = []
var _route_blocked_audio_playback_records: Array = []
var _route_blocked_allows_large_motion := false
var _route_blocked_last_draw: Dictionary = {}
var _guarded_site_active := false
var _guarded_site_tile := Vector2i(-1, -1)
var _guarded_site_event_id := ""
var _guarded_site_animation_state := ""
var _guarded_site_visual_policy := ""
var _guarded_site_fallback_tag := ""
var _guarded_site_placement_id := ""
var _guarded_site_site_id := ""
var _guarded_site_site_name := ""
var _guarded_site_guard_placement_id := ""
var _guarded_site_guard_name := ""
var _guarded_site_control_inspection := ""
var _guarded_site_guard_link_surface := ""
var _guarded_site_vfx_cue_ids: Array = []
var _guarded_site_audio_cue_ids: Array = []
var _guarded_site_audio_playback_records: Array = []
var _guarded_site_context_signature := ""
var _guarded_site_allows_large_motion := false
var _guarded_site_last_draw: Dictionary = {}
var _spell_cast_last_serial := 0
var _spell_cast_tile := Vector2i(-1, -1)
var _spell_cast_elapsed_sec := 0.0
var _spell_cast_duration_sec := 0.0
var _spell_cast_active := false
var _spell_cast_event_id := ""
var _spell_cast_cue_id := ""
var _spell_cast_spell_id := ""
var _spell_cast_spell_name := ""
var _spell_cast_result_message := ""
var _spell_cast_animation_state := ""
var _spell_cast_visual_policy := ""
var _spell_cast_fallback_tag := ""
var _spell_cast_playback_policy := ""
var _spell_cast_blocking_policy := ""
var _spell_cast_vfx_cue_ids: Array = []
var _spell_cast_audio_cue_ids: Array = []
var _spell_cast_audio_playback_records: Array = []
var _spell_cast_allows_large_motion := false
var _spell_cast_last_draw: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	clip_contents = true
	custom_minimum_size = Vector2(640, 400)
	if not SettingsService.settings_changed.is_connected(_on_settings_changed):
		SettingsService.settings_changed.connect(_on_settings_changed)
	_ensure_render_layers()
	_load_terrain_grammar()
	_load_overworld_art_manifest()
	_load_overworld_vfx_manifest()
	_invalidate_frame_layer("ready")
	set_process(false)

func _on_settings_changed(_settings: Dictionary) -> void:
	if not _overworld_terrain_ambient_should_animate():
		_terrain_ambient_phase = TERRAIN_AMBIENT_STATIC_PHASE
	_invalidate_terrain_ambient_layer("accessibility_settings_changed")
	_sync_presentation_processing()

func set_map_state(
	session,
	map_data: Array,
	map_size: Vector2i,
	selected_tile: Vector2i,
	selected_route_state: Dictionary = {},
	movement_presentation: Dictionary = {},
	object_resolution_presentation: Dictionary = {},
	route_blocked_presentation: Dictionary = {},
	guarded_site_presentation: Dictionary = {},
	spell_cast_presentation: Dictionary = {},
	object_focus_presentation: Dictionary = {}
) -> void:
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
	_sync_hero_movement_presentation(movement_presentation)
	_sync_object_resolution_presentation(object_resolution_presentation)
	_sync_route_blocked_presentation(route_blocked_presentation)
	_movement_left = int(session.overworld.get("movement", {}).get("current", 0)) if session != null else 0
	_terrain_layers = session.overworld.get("terrain_layers", {}) if session != null and session.overworld.get("terrain_layers", {}) is Dictionary else {}
	_rebuild_object_indexes()
	_rebuild_road_tiles()
	_selected_tile = selected_tile
	_sync_guarded_site_presentation(guarded_site_presentation)
	_sync_object_focus_presentation(object_focus_presentation)
	_sync_spell_cast_presentation(spell_cast_presentation)
	var path_profile_start := _profile_begin("path_recompute")
	var route_cache_reused := false
	if _route_preview_enabled:
		route_cache_reused = _apply_selected_route_state(selected_route_state)
		if not route_cache_reused:
			_path_tiles = _build_path(_hero_tile, _selected_tile)
			_route_preview = OverworldRulesScript.route_movement_preview(_session, _path_tiles, _movement_left)
	else:
		_path_tiles = []
		_route_preview = {}
	var path_profile_details: Dictionary = _validation_profile.get("last_path_recompute", {}) if _validation_profile.get("last_path_recompute", {}) is Dictionary else {}
	if not _route_preview_enabled:
		path_profile_details["status"] = "disabled_for_editor_action_tool"
		path_profile_details["cache_reused"] = false
	elif route_cache_reused:
		path_profile_details["status"] = "cache_reused"
		path_profile_details["cache_reused"] = true
	else:
		path_profile_details["cache_reused"] = false
	path_profile_details["path_tiles"] = _path_tiles.size()
	path_profile_details["reachable_steps"] = int(_route_preview.get("reachable_steps", 0))
	path_profile_details["unreachable_steps"] = int(_route_preview.get("unreachable_steps", 0))
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
	_invalidate_terrain_ambient_layer("map_state_updated")
	_sync_presentation_processing()
	_profile_end("set_map_state", profile_start)

func set_route_preview_enabled(enabled: bool) -> void:
	_route_preview_enabled = enabled

func _process(delta: float) -> void:
	var redraw_dynamic := false
	var elapsed_delta := maxf(0.0, delta)
	if _overworld_terrain_ambient_should_animate():
		_terrain_ambient_phase = fmod(_terrain_ambient_phase + elapsed_delta * TERRAIN_AMBIENT_PHASE_SPEED, TAU)
		_invalidate_terrain_ambient_layer("terrain_ambient_frame")
	elif not is_zero_approx(_terrain_ambient_phase):
		_terrain_ambient_phase = TERRAIN_AMBIENT_STATIC_PHASE
		_invalidate_terrain_ambient_layer("terrain_ambient_static")
	if _hero_movement_active:
		_hero_movement_elapsed_sec = minf(_hero_movement_duration_sec, _hero_movement_elapsed_sec + elapsed_delta)
		if _hero_movement_elapsed_sec >= _hero_movement_duration_sec:
			_hero_movement_active = false
		redraw_dynamic = true
	if _object_resolution_queued and not _hero_movement_active:
		_object_resolution_queued = false
		_object_resolution_active = true
		_play_object_resolution_audio()
		redraw_dynamic = true
	if _object_resolution_active:
		_object_resolution_elapsed_sec = minf(_object_resolution_duration_sec, _object_resolution_elapsed_sec + elapsed_delta)
		if _object_resolution_elapsed_sec >= _object_resolution_duration_sec:
			_object_resolution_active = false
		redraw_dynamic = true
	if _route_blocked_active:
		_route_blocked_elapsed_sec = minf(_route_blocked_duration_sec, _route_blocked_elapsed_sec + elapsed_delta)
		if _route_blocked_elapsed_sec >= _route_blocked_duration_sec:
			_route_blocked_active = false
		redraw_dynamic = true
	if _spell_cast_active:
		_spell_cast_elapsed_sec = minf(_spell_cast_duration_sec, _spell_cast_elapsed_sec + elapsed_delta)
		if _spell_cast_elapsed_sec >= _spell_cast_duration_sec:
			dismiss_spell_cast_presentation()
			redraw_dynamic = true
	_sync_presentation_processing()
	if redraw_dynamic:
		_invalidate_dynamic_layer("overworld_presentation_frame")

func _sync_presentation_processing() -> void:
	set_process(_overworld_terrain_ambient_should_animate() or _hero_movement_active or _object_resolution_active or _object_resolution_queued or _route_blocked_active or _spell_cast_active)

func present_spell_cast_presentation(presentation: Dictionary) -> Dictionary:
	_sync_spell_cast_presentation(presentation)
	return validation_spell_cast_presentation()

func dismiss_spell_cast_presentation() -> void:
	var was_blocking := _spell_cast_active and _spell_cast_blocking_policy == "input_blocking_timeout"
	_spell_cast_active = false
	_spell_cast_elapsed_sec = _spell_cast_duration_sec
	_sync_presentation_processing()
	_invalidate_dynamic_layer("spell_cast_presentation_dismissed")
	if was_blocking:
		spell_cast_presentation_blocking_changed.emit(false)

func _sync_spell_cast_presentation(presentation: Dictionary) -> void:
	var serial := int(presentation.get("serial", 0))
	if serial <= 0 or serial == _spell_cast_last_serial:
		return
	var event_id := String(presentation.get("event_id", ""))
	var cue_id := String(presentation.get("cue_id", ""))
	var spell_id := String(presentation.get("spell_id", ""))
	var spell_name := String(presentation.get("spell_name", ""))
	var result_message := String(presentation.get("result_message", ""))
	var animation_state := String(presentation.get("selected_animation_state", ""))
	var visual_policy := String(presentation.get("selected_visual_policy", ""))
	var fallback_tag := String(presentation.get("selected_fallback_tag", ""))
	var playback_policy := String(presentation.get("selected_playback_policy", ""))
	var blocking_policy := String(presentation.get("selected_blocking_policy", ""))
	var vfx_cue_ids: Array = (presentation.get("selected_vfx_cue_ids", []) as Array).duplicate(true)
	var audio_cue_ids: Array = (presentation.get("selected_audio_cue_ids", []) as Array).duplicate(true)
	var allows_large_motion := bool(presentation.get("allows_large_motion", true))
	var tile_payload: Dictionary = presentation.get("hero_tile", {}) if presentation.get("hero_tile", {}) is Dictionary else {}
	var spell_tile := Vector2i(int(tile_payload.get("x", -1)), int(tile_payload.get("y", -1)))
	if (
		event_id != "spell_cast_overworld"
		or cue_id != "cue_spell_cast_overworld"
		or spell_id == ""
		or spell_name == ""
		or result_message == ""
		or playback_policy != "queue_resolved"
		or blocking_policy not in ["input_blocking_timeout", "nonblocking_reduced_motion", "nonblocking_fast_resolve"]
		or spell_tile != _hero_tile
	):
		return
	var duration_msec := clampi(
		int(presentation.get("duration_ms", SPELL_CAST_MIN_DURATION_MSEC)),
		SPELL_CAST_MIN_DURATION_MSEC,
		SPELL_CAST_MAX_DURATION_MSEC
	)
	var was_blocking := _spell_cast_active and _spell_cast_blocking_policy == "input_blocking_timeout"
	if was_blocking:
		spell_cast_presentation_blocking_changed.emit(false)
	_spell_cast_last_serial = serial
	_spell_cast_elapsed_sec = 0.0
	_spell_cast_duration_sec = float(duration_msec) / 1000.0
	_spell_cast_event_id = event_id
	_spell_cast_cue_id = cue_id
	_spell_cast_spell_id = spell_id
	_spell_cast_spell_name = spell_name
	_spell_cast_result_message = result_message
	_spell_cast_animation_state = animation_state
	_spell_cast_visual_policy = visual_policy
	_spell_cast_fallback_tag = fallback_tag
	_spell_cast_playback_policy = playback_policy
	_spell_cast_blocking_policy = blocking_policy
	_spell_cast_vfx_cue_ids = vfx_cue_ids
	_spell_cast_audio_cue_ids = audio_cue_ids
	_spell_cast_audio_playback_records = []
	for audio_cue_value in audio_cue_ids:
		_spell_cast_audio_playback_records.append(PresentationAudio.play_cue(String(audio_cue_value), "OverworldMapView.spell_cast", {
			"event_id": event_id,
			"presentation_serial": serial,
			"spell_id": spell_id,
			"tile": {"x": spell_tile.x, "y": spell_tile.y},
		}))
	_spell_cast_allows_large_motion = allows_large_motion
	_spell_cast_tile = spell_tile
	_spell_cast_last_draw = {}
	_spell_cast_active = true
	_sync_presentation_processing()
	_invalidate_dynamic_layer("spell_cast_presentation_started")
	if _spell_cast_blocking_policy == "input_blocking_timeout":
		spell_cast_presentation_blocking_changed.emit(true)

func _sync_hero_movement_presentation(presentation: Dictionary) -> void:
	var serial := int(presentation.get("serial", 0))
	if serial <= 0 or serial == _hero_movement_last_serial:
		return
	_hero_movement_last_serial = serial
	_hero_movement_active = false
	_sync_presentation_processing()
	_hero_movement_path = []
	_hero_movement_elapsed_sec = 0.0
	_hero_movement_duration_sec = 0.0
	_hero_movement_event_id = String(presentation.get("event_id", ""))
	_hero_movement_animation_state = String(presentation.get("selected_animation_state", ""))
	_hero_movement_visual_policy = String(presentation.get("selected_visual_policy", ""))
	_hero_movement_fallback_tag = String(presentation.get("selected_fallback_tag", ""))
	_hero_movement_vfx_cue_ids = (presentation.get("selected_vfx_cue_ids", []) as Array).duplicate(true)
	_hero_movement_audio_cue_ids = (presentation.get("selected_audio_cue_ids", []) as Array).duplicate(true)
	_hero_movement_audio_playback_records = []
	_hero_movement_reduced_motion = not bool(presentation.get("allows_large_motion", true))
	_hero_movement_last_draw = {}
	if _hero_movement_event_id != "overworld_hero_move":
		return
	var path := _tiles_from_payloads(presentation.get("route_tiles", []))
	if path.size() <= 1 or path[path.size() - 1] != _hero_tile:
		return
	_hero_movement_path = path
	for audio_cue_value in _hero_movement_audio_cue_ids:
		_hero_movement_audio_playback_records.append(PresentationAudio.play_cue(String(audio_cue_value), "OverworldMapView.hero_movement", {
			"event_id": _hero_movement_event_id,
			"presentation_serial": serial,
			"route_step_count": path.size() - 1,
			"final_tile": {"x": _hero_tile.x, "y": _hero_tile.y},
		}))
	if _hero_movement_reduced_motion:
		_hero_movement_last_draw = {"mode": "route_endpoint_snap", "texture_path": ""}
		_invalidate_dynamic_layer("hero_movement_reduced_motion_snap")
		return
	var duration_msec := clampi(
		int(presentation.get("duration_ms", HERO_MOVEMENT_MIN_DURATION_MSEC)),
		HERO_MOVEMENT_MIN_DURATION_MSEC,
		HERO_MOVEMENT_MAX_DURATION_MSEC
	)
	_hero_movement_duration_sec = float(duration_msec) / 1000.0
	_hero_movement_active = true
	_sync_presentation_processing()
	_invalidate_dynamic_layer("hero_movement_started")

func _sync_object_resolution_presentation(presentation: Dictionary) -> void:
	var serial := int(presentation.get("serial", 0))
	if serial <= 0 or serial == _object_resolution_last_serial:
		return
	_object_resolution_last_serial = serial
	_object_resolution_active = false
	_object_resolution_queued = false
	_object_resolution_tile = Vector2i(-1, -1)
	_object_resolution_elapsed_sec = 0.0
	_object_resolution_duration_sec = 0.0
	_object_resolution_event_id = String(presentation.get("event_id", ""))
	_object_resolution_animation_state = String(presentation.get("selected_animation_state", ""))
	_object_resolution_visual_policy = String(presentation.get("selected_visual_policy", ""))
	_object_resolution_fallback_tag = String(presentation.get("selected_fallback_tag", ""))
	_object_resolution_vfx_cue_ids = (presentation.get("selected_vfx_cue_ids", []) as Array).duplicate(true)
	_object_resolution_audio_cue_ids = (presentation.get("selected_audio_cue_ids", []) as Array).duplicate(true)
	_object_resolution_audio_playback_records = []
	_object_resolution_family = String(presentation.get("family", ""))
	_object_resolution_placement_id = String(presentation.get("placement_id", ""))
	_object_resolution_allows_large_motion = bool(presentation.get("allows_large_motion", true))
	_object_resolution_last_draw = {}
	_sync_presentation_processing()
	if _object_resolution_event_id not in ["overworld_object_visited", "overworld_object_captured", "town_captured", "overworld_object_depleted", "overworld_route_open", "overworld_route_closed"]:
		return
	if _object_resolution_family not in ["resource_site", "artifact", "town_capture", "encounter", "site_response", "route_closure"] or _object_resolution_placement_id == "":
		return
	if (_object_resolution_event_id == "overworld_route_open") != (_object_resolution_family == "site_response"):
		return
	if (_object_resolution_event_id == "overworld_route_closed") != (_object_resolution_family == "route_closure"):
		return
	if _object_resolution_event_id == "town_captured" and _object_resolution_family != "town_capture":
		return
	if _object_resolution_family == "town_capture" and _object_resolution_event_id != "town_captured":
		return
	if _object_resolution_event_id == "overworld_object_captured" and _object_resolution_family != "resource_site":
		return
	var tile_payload: Dictionary = presentation.get("tile", {}) if presentation.get("tile", {}) is Dictionary else {}
	var tile := Vector2i(int(tile_payload.get("x", -1)), int(tile_payload.get("y", -1)))
	if tile.x < 0 or tile.y < 0 or tile.x >= _map_size.x or tile.y >= _map_size.y:
		return
	var duration_msec := clampi(
		int(presentation.get("duration_ms", OBJECT_RESOLUTION_MIN_DURATION_MSEC)),
		OBJECT_RESOLUTION_MIN_DURATION_MSEC,
		OBJECT_RESOLUTION_MAX_DURATION_MSEC
	)
	_object_resolution_tile = tile
	_object_resolution_duration_sec = float(duration_msec) / 1000.0
	_object_resolution_queued = _hero_movement_active
	_object_resolution_active = not _object_resolution_queued
	if _object_resolution_active:
		_play_object_resolution_audio()
	_sync_presentation_processing()
	_invalidate_dynamic_layer("object_resolution_started")

func _play_object_resolution_audio() -> void:
	if not _object_resolution_active or not _object_resolution_audio_playback_records.is_empty():
		return
	var audio_source := "OverworldMapView.route_open" if _object_resolution_event_id == "overworld_route_open" else ("OverworldMapView.route_closed" if _object_resolution_event_id == "overworld_route_closed" else "OverworldMapView.object_resolution")
	for audio_cue_value in _object_resolution_audio_cue_ids:
		_object_resolution_audio_playback_records.append(PresentationAudio.play_cue(String(audio_cue_value), audio_source, {
			"event_id": _object_resolution_event_id,
			"presentation_serial": _object_resolution_last_serial,
			"family": _object_resolution_family,
			"placement_id": _object_resolution_placement_id,
			"tile": {"x": _object_resolution_tile.x, "y": _object_resolution_tile.y},
		}))

func _sync_route_blocked_presentation(presentation: Dictionary) -> void:
	var serial := int(presentation.get("serial", 0))
	if serial <= 0 or serial == _route_blocked_last_serial:
		return
	_route_blocked_last_serial = serial
	_route_blocked_active = false
	_route_blocked_tile = Vector2i(-1, -1)
	_route_blocked_elapsed_sec = 0.0
	_route_blocked_duration_sec = 0.0
	_route_blocked_event_id = String(presentation.get("event_id", ""))
	_route_blocked_animation_state = String(presentation.get("selected_animation_state", ""))
	_route_blocked_visual_policy = String(presentation.get("selected_visual_policy", ""))
	_route_blocked_fallback_tag = String(presentation.get("selected_fallback_tag", ""))
	_route_blocked_reason = String(presentation.get("blocked_reason", "")).strip_edges()
	_route_blocked_blocking_object = (presentation.get("blocking_object", {}) as Dictionary).duplicate(true) if presentation.get("blocking_object", {}) is Dictionary else {}
	_route_blocked_vfx_cue_ids = (presentation.get("selected_vfx_cue_ids", []) as Array).duplicate(true)
	_route_blocked_audio_cue_ids = (presentation.get("selected_audio_cue_ids", []) as Array).duplicate(true)
	_route_blocked_audio_playback_records = []
	_route_blocked_allows_large_motion = bool(presentation.get("allows_large_motion", true))
	_route_blocked_last_draw = {}
	_sync_presentation_processing()
	if _route_blocked_event_id not in ["overworld_route_blocked", "overworld_object_blocked"] or String(presentation.get("status", "")) != "blocked" or _route_blocked_reason == "":
		return
	var tile_payload: Dictionary = presentation.get("tile", {}) if presentation.get("tile", {}) is Dictionary else {}
	var tile := Vector2i(int(tile_payload.get("x", -1)), int(tile_payload.get("y", -1)))
	if tile.x < 0 or tile.y < 0 or tile.x >= _map_size.x or tile.y >= _map_size.y:
		return
	var duration_msec := clampi(
		int(presentation.get("duration_ms", ROUTE_BLOCKED_MIN_DURATION_MSEC)),
		ROUTE_BLOCKED_MIN_DURATION_MSEC,
		ROUTE_BLOCKED_MAX_DURATION_MSEC
	)
	_route_blocked_tile = tile
	var audio_source := "OverworldMapView.object_blocked" if _route_blocked_event_id == "overworld_object_blocked" else "OverworldMapView.route_blocked"
	for audio_cue_value in _route_blocked_audio_cue_ids:
		_route_blocked_audio_playback_records.append(PresentationAudio.play_cue(String(audio_cue_value), audio_source, {
			"event_id": _route_blocked_event_id,
			"presentation_serial": serial,
			"tile": {"x": tile.x, "y": tile.y},
			"blocked_reason": _route_blocked_reason,
			"blocking_object": _route_blocked_blocking_object.duplicate(true),
		}))
	_route_blocked_duration_sec = float(duration_msec) / 1000.0
	_route_blocked_active = true
	_sync_presentation_processing()
	_invalidate_dynamic_layer("route_blocked_started")

func _sync_guarded_site_presentation(presentation: Dictionary) -> void:
	var previous_signature := _guarded_site_context_signature if _guarded_site_active else ""
	var previous_audio_records := _guarded_site_audio_playback_records.duplicate(true)
	_guarded_site_active = false
	_guarded_site_tile = Vector2i(-1, -1)
	_guarded_site_event_id = String(presentation.get("event_id", ""))
	_guarded_site_animation_state = String(presentation.get("selected_animation_state", ""))
	_guarded_site_visual_policy = String(presentation.get("selected_visual_policy", ""))
	_guarded_site_fallback_tag = String(presentation.get("selected_fallback_tag", ""))
	_guarded_site_placement_id = String(presentation.get("placement_id", "")).strip_edges()
	_guarded_site_site_id = String(presentation.get("site_id", "")).strip_edges()
	_guarded_site_site_name = String(presentation.get("site_name", "")).strip_edges()
	_guarded_site_guard_placement_id = String(presentation.get("guard_placement_id", "")).strip_edges()
	_guarded_site_guard_name = String(presentation.get("guard_name", "")).strip_edges()
	_guarded_site_control_inspection = String(presentation.get("control_inspection", "")).strip_edges()
	_guarded_site_guard_link_surface = String(presentation.get("guard_link_surface", "")).strip_edges()
	_guarded_site_vfx_cue_ids = (presentation.get("selected_vfx_cue_ids", []) as Array).duplicate(true)
	_guarded_site_audio_cue_ids = (presentation.get("selected_audio_cue_ids", []) as Array).duplicate(true)
	_guarded_site_audio_playback_records = []
	_guarded_site_context_signature = ""
	_guarded_site_allows_large_motion = bool(presentation.get("allows_large_motion", true))
	_guarded_site_last_draw = {}
	if (
		not bool(presentation.get("active", false))
		or _guarded_site_event_id != "overworld_object_guarded"
		or String(presentation.get("status", "")) != "guarded"
		or String(presentation.get("playback_policy", "")) != "context_visible_only"
		or _guarded_site_placement_id == ""
		or _guarded_site_site_id == ""
		or _guarded_site_guard_placement_id == ""
		or _guarded_site_guard_name == ""
		or _guarded_site_control_inspection == ""
		or _guarded_site_guard_link_surface == ""
	):
		return
	var tile_payload: Dictionary = presentation.get("tile", {}) if presentation.get("tile", {}) is Dictionary else {}
	var tile := Vector2i(int(tile_payload.get("x", -1)), int(tile_payload.get("y", -1)))
	if tile != _selected_tile or tile.x < 0 or tile.y < 0 or tile.x >= _map_size.x or tile.y >= _map_size.y:
		return
	_guarded_site_tile = tile
	_guarded_site_active = true
	_guarded_site_context_signature = "%s|%d,%d|%s|%s|%s" % [
		_guarded_site_event_id,
		tile.x,
		tile.y,
		_guarded_site_placement_id,
		_guarded_site_site_id,
		_guarded_site_guard_placement_id,
	]
	if _guarded_site_context_signature == previous_signature:
		_guarded_site_audio_playback_records = previous_audio_records
		return
	for audio_cue_value in _guarded_site_audio_cue_ids:
		_guarded_site_audio_playback_records.append(PresentationAudio.play_cue(String(audio_cue_value), "OverworldMapView.guarded_site", {
			"event_id": _guarded_site_event_id,
			"context_signature": _guarded_site_context_signature,
			"placement_id": _guarded_site_placement_id,
			"site_id": _guarded_site_site_id,
			"guard_placement_id": _guarded_site_guard_placement_id,
			"tile": {"x": _guarded_site_tile.x, "y": _guarded_site_tile.y},
		}))

func _sync_object_focus_presentation(presentation: Dictionary) -> void:
	var previous_signature := _object_focus_context_signature if _object_focus_active else ""
	var previous_audio_records := _object_focus_audio_playback_records.duplicate(true)
	_object_focus_active = false
	_object_focus_tile = Vector2i(-1, -1)
	_object_focus_event_id = String(presentation.get("event_id", ""))
	_object_focus_cue_id = String(presentation.get("cue_id", ""))
	_object_focus_input_source = String(presentation.get("input_source", ""))
	_object_focus_kind = String(presentation.get("object_kind", ""))
	_object_focus_id = String(presentation.get("object_id", "")).strip_edges()
	_object_focus_animation_state = String(presentation.get("selected_animation_state", ""))
	_object_focus_visual_policy = String(presentation.get("selected_visual_policy", ""))
	_object_focus_fallback_tag = String(presentation.get("selected_fallback_tag", ""))
	_object_focus_playback_policy = String(presentation.get("selected_playback_policy", ""))
	_object_focus_blocking_policy = String(presentation.get("selected_blocking_policy", ""))
	_object_focus_vfx_cue_ids = (presentation.get("selected_vfx_cue_ids", []) as Array).duplicate(true)
	_object_focus_audio_cue_ids = (presentation.get("selected_audio_cue_ids", []) as Array).duplicate(true)
	_object_focus_audio_playback_records = []
	_object_focus_context_signature = ""
	_object_focus_allows_large_motion = bool(presentation.get("allows_large_motion", true))
	_object_focus_last_draw = {}
	if (
		not bool(presentation.get("active", false))
		or _guarded_site_active
		or _object_focus_event_id != "overworld_object_active"
		or _object_focus_cue_id != "cue_overworld_object_active"
		or _object_focus_input_source not in ["pointer", "controller_route_cursor"]
		or _object_focus_kind not in ["town", "resource", "artifact", "encounter"]
		or _object_focus_id == ""
		or _object_focus_playback_policy not in ["context_visible_only", "fast_resolve"]
		or _object_focus_blocking_policy != "never_blocks_input"
		or _object_focus_audio_cue_ids != ["audio_placeholder_object_focus"]
	):
		return
	var tile_payload: Dictionary = presentation.get("tile", {}) if presentation.get("tile", {}) is Dictionary else {}
	var tile := Vector2i(int(tile_payload.get("x", -1)), int(tile_payload.get("y", -1)))
	if tile != _selected_tile or tile.x < 0 or tile.y < 0 or tile.x >= _map_size.x or tile.y >= _map_size.y:
		return
	if not OverworldRulesScript.is_tile_visible(_session, tile.x, tile.y):
		return
	var live_identity := _object_focus_identity_at(tile)
	if String(live_identity.get("object_kind", "")) != _object_focus_kind or String(live_identity.get("object_id", "")) != _object_focus_id:
		return
	var expected_vfx_ids := ["vfx_placeholder_object_focus_ring"]
	if _object_focus_visual_policy == "reduced_motion_fallback":
		expected_vfx_ids = ["focus_outline_static"]
	elif _object_focus_visual_policy == "fast_mode_fallback":
		expected_vfx_ids = ["focus_outline_snap"]
	if _object_focus_vfx_cue_ids != expected_vfx_ids:
		return
	_object_focus_tile = tile
	_object_focus_active = true
	_object_focus_context_signature = "%s|%d,%d|%s|%s" % [
		_object_focus_event_id,
		tile.x,
		tile.y,
		_object_focus_kind,
		_object_focus_id,
	]
	if _object_focus_context_signature == previous_signature:
		_object_focus_audio_playback_records = previous_audio_records
		return
	for audio_cue_value in _object_focus_audio_cue_ids:
		_object_focus_audio_playback_records.append(PresentationAudio.play_cue(String(audio_cue_value), "OverworldMapView.object_focus", {
			"event_id": _object_focus_event_id,
			"context_signature": _object_focus_context_signature,
			"input_source": _object_focus_input_source,
			"object_kind": _object_focus_kind,
			"object_id": _object_focus_id,
			"tile": {"x": _object_focus_tile.x, "y": _object_focus_tile.y},
		}))

func _object_focus_identity_at(tile: Vector2i) -> Dictionary:
	var town := _town_at(tile)
	if not town.is_empty():
		return {"object_kind": "town", "object_id": String(town.get("placement_id", "")).strip_edges()}
	var resource := _resource_node_at(tile)
	if not resource.is_empty():
		return {"object_kind": "resource", "object_id": String(resource.get("placement_id", "")).strip_edges()}
	var artifact := _artifact_node_at(tile)
	if not artifact.is_empty():
		return {"object_kind": "artifact", "object_id": String(artifact.get("placement_id", "")).strip_edges()}
	var encounter := _encounter_node_at(tile)
	if not encounter.is_empty():
		return {"object_kind": "encounter", "object_id": String(encounter.get("placement_id", encounter.get("id", ""))).strip_edges()}
	return {}

func set_placement_debug_overlay_enabled(enabled: bool) -> void:
	if _placement_debug_overlay_enabled == enabled:
		return
	_placement_debug_overlay_enabled = enabled
	_invalidate_dynamic_layer("placement_debug_overlay_toggled")

func _apply_selected_route_state(selected_route_state: Dictionary) -> bool:
	if selected_route_state.is_empty() or not bool(selected_route_state.get("valid", false)):
		return false
	var selected_payload = selected_route_state.get("selected_tile", {})
	var start_payload = selected_route_state.get("start_tile", selected_route_state.get("hero_tile", {}))
	if not (selected_payload is Dictionary) or not (start_payload is Dictionary):
		return false
	var selected := Vector2i(int(selected_payload.get("x", -1)), int(selected_payload.get("y", -1)))
	var start := Vector2i(int(start_payload.get("x", -1)), int(start_payload.get("y", -1)))
	if selected != _selected_tile or start != _hero_tile:
		return false
	if int(selected_route_state.get("movement_current", _movement_left)) != _movement_left:
		return false
	var route_tiles := _tiles_from_payloads(selected_route_state.get("route_tiles", []))
	if route_tiles.is_empty() and _selected_tile == _hero_tile:
		route_tiles = [_hero_tile]
	if route_tiles.is_empty():
		return false
	if route_tiles[0] != _hero_tile:
		return false
	_path_tiles = route_tiles
	var preview = selected_route_state.get("route_preview", {})
	_route_preview = preview.duplicate(true) if preview is Dictionary else OverworldRulesScript.route_movement_preview(_session, _path_tiles, _movement_left)
	_profile_add("selected_route_cache_reuse_count", 1)
	_validation_profile["last_selected_route_cache"] = {
		"status": "reused",
		"path_tiles": _path_tiles.size(),
		"reachable_steps": int(_route_preview.get("reachable_steps", 0)),
		"unreachable_steps": int(_route_preview.get("unreachable_steps", 0)),
	}
	return true

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_invalidate_frame_layer("resized")
		_invalidate_session_static_cache("resized")
		_invalidate_terrain_ambient_layer("resized")
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
	_terrain_ambient_layer = _create_render_layer("TerrainAmbientLayer", Callable(self, "_draw_terrain_ambient_layer"))
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
	for row in map_data:
		signature = _combine_cache_signature(signature, hash(var_to_str(row)))
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
				signature = _combine_cache_signature(signature, hash(str(tile_value.get("h3maped_road_art_frame_id", ""))))
				signature = _combine_cache_signature(signature, int(tile_value.get("h3maped_road_flip_a", 0)))
				signature = _combine_cache_signature(signature, int(tile_value.get("h3maped_road_flip_b", 0)))
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

func _invalidate_terrain_ambient_layer(reason: String) -> void:
	_terrain_ambient_generation += 1
	_terrain_ambient_reason = reason
	if _terrain_ambient_layer != null:
		_terrain_ambient_layer.queue_redraw()

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

func _canvas_draw_polygon(points: PackedVector2Array, colors: PackedColorArray) -> void:
	_current_draw_canvas_item().draw_polygon(points, colors)

func _canvas_draw_textured_polygon(points: PackedVector2Array, colors: PackedColorArray, uvs: PackedVector2Array, texture: Texture2D) -> void:
	_current_draw_canvas_item().draw_polygon(points, colors, uvs, texture)

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

func _canvas_draw_texture_rect_region(
	texture: Texture2D,
	rect: Rect2,
	source_rect: Rect2,
	modulate: Color = Color(1.0, 1.0, 1.0, 1.0)
) -> void:
	_current_draw_canvas_item().draw_texture_rect_region(texture, rect, source_rect, modulate, false, true)

func _canvas_draw_texture_rect_flipped(
	texture: Texture2D,
	rect: Rect2,
	flip_x: bool,
	flip_y: bool,
	modulate: Color = Color(1.0, 1.0, 1.0, 1.0),
	transpose: bool = false
) -> void:
	var canvas := _current_draw_canvas_item()
	if not flip_x and not flip_y:
		canvas.draw_texture_rect(texture, rect, false, modulate, transpose)
		return
	canvas.draw_set_transform(rect.get_center(), 0.0, Vector2(-1.0 if flip_x else 1.0, -1.0 if flip_y else 1.0))
	canvas.draw_texture_rect(texture, Rect2(rect.size * -0.5, rect.size), false, modulate, transpose)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

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

func _hover_tooltip_visual_profile(for_text: String) -> Dictionary:
	var content_width := clampf(
		size.x * HOVER_TOOLTIP_CONTENT_WIDTH_FACTOR,
		HOVER_TOOLTIP_CONTENT_WIDTH_MIN_PX,
		HOVER_TOOLTIP_CONTENT_WIDTH_MAX_PX
	)
	return {
		"model": HOVER_TOOLTIP_VISUAL_MODEL,
		"full_text": for_text,
		"content_width_px": content_width,
		"card_width_px": content_width + float(HOVER_TOOLTIP_MARGIN_HORIZONTAL_PX * 2 + HOVER_TOOLTIP_BORDER_WIDTH_PX * 2),
		"max_lines": HOVER_TOOLTIP_MAX_LINES,
		"autowrap_mode": TextServer.AUTOWRAP_WORD_SMART,
		"overrun_behavior": TextServer.OVERRUN_TRIM_ELLIPSIS,
		"margin_horizontal_px": HOVER_TOOLTIP_MARGIN_HORIZONTAL_PX,
		"margin_vertical_px": HOVER_TOOLTIP_MARGIN_VERTICAL_PX,
		"panel_color": HOVER_TOOLTIP_PANEL_COLOR,
		"border_color": HOVER_TOOLTIP_BORDER_COLOR,
		"text_color": HOVER_TOOLTIP_TEXT_COLOR,
		"shadow_color": HOVER_TOOLTIP_SHADOW_COLOR,
		"border_width_px": HOVER_TOOLTIP_BORDER_WIDTH_PX,
		"corner_radius_px": HOVER_TOOLTIP_CORNER_RADIUS_PX,
		"shadow_size_px": HOVER_TOOLTIP_SHADOW_SIZE_PX,
		"shadow_offset": HOVER_TOOLTIP_SHADOW_OFFSET,
	}

func _build_hover_tooltip_card(for_text: String) -> PanelContainer:
	var profile := _hover_tooltip_visual_profile(for_text)
	var card := PanelContainer.new()
	card.name = "CartographicHoverCard"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.custom_minimum_size = Vector2(float(profile.get("card_width_px", HOVER_TOOLTIP_CONTENT_WIDTH_MIN_PX)), 0.0)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = profile.get("panel_color", HOVER_TOOLTIP_PANEL_COLOR)
	panel_style.border_color = profile.get("border_color", HOVER_TOOLTIP_BORDER_COLOR)
	panel_style.set_border_width_all(int(profile.get("border_width_px", HOVER_TOOLTIP_BORDER_WIDTH_PX)))
	panel_style.set_corner_radius_all(int(profile.get("corner_radius_px", HOVER_TOOLTIP_CORNER_RADIUS_PX)))
	panel_style.shadow_color = profile.get("shadow_color", HOVER_TOOLTIP_SHADOW_COLOR)
	panel_style.shadow_size = int(profile.get("shadow_size_px", HOVER_TOOLTIP_SHADOW_SIZE_PX))
	panel_style.shadow_offset = profile.get("shadow_offset", HOVER_TOOLTIP_SHADOW_OFFSET)
	card.add_theme_stylebox_override("panel", panel_style)

	var margin := MarginContainer.new()
	margin.name = "CardMargin"
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", int(profile.get("margin_horizontal_px", HOVER_TOOLTIP_MARGIN_HORIZONTAL_PX)))
	margin.add_theme_constant_override("margin_right", int(profile.get("margin_horizontal_px", HOVER_TOOLTIP_MARGIN_HORIZONTAL_PX)))
	margin.add_theme_constant_override("margin_top", int(profile.get("margin_vertical_px", HOVER_TOOLTIP_MARGIN_VERTICAL_PX)))
	margin.add_theme_constant_override("margin_bottom", int(profile.get("margin_vertical_px", HOVER_TOOLTIP_MARGIN_VERTICAL_PX)))
	card.add_child(margin)

	var label := Label.new()
	label.name = "CardText"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.custom_minimum_size = Vector2(float(profile.get("content_width_px", HOVER_TOOLTIP_CONTENT_WIDTH_MIN_PX)), 0.0)
	label.autowrap_mode = int(profile.get("autowrap_mode", TextServer.AUTOWRAP_WORD_SMART))
	label.text_overrun_behavior = int(profile.get("overrun_behavior", TextServer.OVERRUN_TRIM_ELLIPSIS))
	label.max_lines_visible = int(profile.get("max_lines", HOVER_TOOLTIP_MAX_LINES))
	label.text = for_text
	label.add_theme_color_override("font_color", profile.get("text_color", HOVER_TOOLTIP_TEXT_COLOR))
	label.add_theme_color_override("font_shadow_color", profile.get("shadow_color", HOVER_TOOLTIP_SHADOW_COLOR))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	margin.add_child(label)
	return card

func _make_custom_tooltip(for_text: String) -> Object:
	return _build_hover_tooltip_card(for_text)

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
	_draw_small_map_cartographic_matte(viewport_rect, board_rect)
	var visible_bounds := _visible_tile_bounds(board_rect, viewport_rect)
	for y in range(visible_bounds.position.y, visible_bounds.position.y + visible_bounds.size.y):
		for x in range(visible_bounds.position.x, visible_bounds.position.x + visible_bounds.size.x):
			var tile = Vector2i(x, y)
			var rect = _tile_rect(board_rect, tile)
			terrain_draws += 1
			_draw_tile_terrain_surface(tile, rect)
	var terrain_grain_drawn := _draw_terrain_grain_overlay(board_rect)
	var macro_lighting_polygon_draws := _draw_terrain_macro_lighting_field(board_rect, visible_bounds)
	var terrain_detail_decal_draws := 0
	var water_surface_ripple_draws := 0
	for y in range(visible_bounds.position.y, visible_bounds.position.y + visible_bounds.size.y):
		for x in range(visible_bounds.position.x, visible_bounds.position.x + visible_bounds.size.x):
			var tile = Vector2i(x, y)
			var rect = _tile_rect(board_rect, tile)
			if _draw_terrain_detail_decal(tile, rect):
				terrain_detail_decal_draws += 1
			if _draw_water_surface_ripples(tile, rect):
				water_surface_ripple_draws += 1
			if not _road_tile_payload(tile).is_empty():
				road_draws += 1
			_draw_road_overlay(tile, rect)
	_draw_canvas_item = previous_target
	_profile_add("terrain_tile_draws", terrain_draws)
	_profile_add("terrain_grain_overlay_draws", 1 if terrain_grain_drawn else 0)
	_profile_add("road_tile_draws", road_draws)
	_profile_add("terrain_macro_lighting_polygon_draws", macro_lighting_polygon_draws)
	_profile_add("terrain_detail_decal_draws", terrain_detail_decal_draws)
	_profile_add("water_surface_ripple_draws", water_surface_ripple_draws)
	_profile_end("draw_session_static", profile_start, {
		"terrain_tile_draws": terrain_draws,
		"terrain_grain_overlay_draws": 1 if terrain_grain_drawn else 0,
		"road_tile_draws": road_draws,
		"terrain_macro_lighting_polygon_draws": macro_lighting_polygon_draws,
		"terrain_detail_decal_draws": terrain_detail_decal_draws,
		"water_surface_ripple_draws": water_surface_ripple_draws,
		"visible_bounds": _rect2i_payload(visible_bounds),
	})

func _overworld_terrain_ambient_available() -> bool:
	return _session != null and not FrontierVisualKitScript.high_contrast_enabled()

func _overworld_terrain_ambient_should_animate() -> bool:
	return _overworld_terrain_ambient_available() and not SettingsService.reduced_motion_enabled()

func _overworld_terrain_ambient_profile(tile: Vector2i) -> Dictionary:
	var terrain_group := _terrain_group(_terrain_at(tile))
	var profile_value: Variant = TERRAIN_AMBIENT_PROFILES.get(terrain_group, {})
	return profile_value if profile_value is Dictionary else {}

func _overworld_terrain_ambient_seed(tile: Vector2i, profile_id: String) -> int:
	var profile_seed := 0
	for index in range(profile_id.length()):
		profile_seed += profile_id.unicode_at(index) * (index + 1)
	return absi((tile.x * 73) + (tile.y * 151) + profile_seed)

func _overworld_terrain_ambient_entries(board_rect: Rect2, visible_bounds: Rect2i, phase: float) -> Array:
	if not _overworld_terrain_ambient_available() or board_rect.size.x <= 0.0 or board_rect.size.y <= 0.0:
		return []
	var entries: Array = []
	for y in range(visible_bounds.position.y, visible_bounds.end.y):
		for x in range(visible_bounds.position.x, visible_bounds.end.x):
			var tile := Vector2i(x, y)
			if not OverworldRulesScript.is_tile_explored(_session, tile.x, tile.y):
				continue
			var profile := _overworld_terrain_ambient_profile(tile)
			if profile.is_empty():
				continue
			var profile_id := String(profile.get("id", ""))
			var seed := _overworld_terrain_ambient_seed(tile, profile_id)
			if seed % TERRAIN_AMBIENT_DENSITY_MODULUS != 0:
				continue
			var rect := _tile_rect(board_rect, tile)
			var radius := clampf(minf(rect.size.x, rect.size.y) * float(profile.get("radius_factor", 0.02)), 0.85, 2.35)
			var outer_radius := radius * 3.0
			var base_normalized := Vector2(
				0.24 + (float(seed % 37) / 36.0) * 0.52,
				0.24 + (float((seed / 37) % 37) / 36.0) * 0.52
			)
			var local_phase := phase + float(seed % 101) * 0.071
			var drift: Vector2 = profile.get("drift", Vector2.ZERO)
			var motion_normalized := Vector2(
				sin(local_phase) * drift.x,
				cos((local_phase * 0.79) + float(seed % 13) * 0.19) * drift.y
			)
			var center := rect.position + (base_normalized + motion_normalized) * rect.size
			var pulse := 0.76 + 0.24 * sin((local_phase * 1.17) + 0.6)
			var bounds := Rect2(center - Vector2(outer_radius, outer_radius), Vector2(outer_radius * 2.0, outer_radius * 2.0))
			entries.append({
				"tile": tile,
				"profile_id": profile_id,
				"kind": String(profile.get("kind", "")),
				"base_normalized": base_normalized,
				"center": center,
				"radius": radius,
				"outer_radius": outer_radius,
				"alpha": float(profile.get("alpha", 0.0)) * pulse,
				"color": profile.get("color", Color.TRANSPARENT),
				"bounds": bounds,
				"contained": rect.encloses(bounds),
				"explored": true,
			})
	return entries

func _draw_overworld_terrain_ambient_entry(entry: Dictionary) -> void:
	var center: Vector2 = entry.get("center", Vector2.ZERO)
	var radius := float(entry.get("radius", 0.0))
	var alpha := float(entry.get("alpha", 0.0))
	var color: Color = entry.get("color", Color.TRANSPARENT)
	var halo_color := Color(color.r, color.g, color.b, alpha * 0.16)
	var soft_color := Color(color.r, color.g, color.b, alpha * 0.42)
	var core_color := Color(color.r, color.g, color.b, alpha)
	match String(entry.get("kind", "")):
		"dust":
			var tangent := Vector2(1.0, -0.22).normalized()
			_canvas_draw_line(center - tangent * radius * 2.0, center + tangent * radius * 2.0, soft_color, maxf(0.7, radius * 0.62), true)
			_canvas_draw_circle(center, radius * 0.42, core_color)
		"ember":
			_canvas_draw_line(center + Vector2(0.0, radius * 1.7), center - Vector2(radius * 0.28, radius * 1.2), soft_color, maxf(0.75, radius * 0.58), true)
			_canvas_draw_circle(center, radius * 0.44, core_color)
		"frost":
			_canvas_draw_line(center - Vector2(radius, 0.0), center + Vector2(radius, 0.0), soft_color, maxf(0.7, radius * 0.48), true)
			_canvas_draw_line(center - Vector2(0.0, radius), center + Vector2(0.0, radius), soft_color, maxf(0.7, radius * 0.48), true)
			_canvas_draw_circle(center, radius * 0.34, core_color)
		"wisp":
			_canvas_draw_circle(center, radius * 3.0, halo_color)
			_canvas_draw_line(center - Vector2(radius * 1.2, 0.0), center + Vector2(radius * 1.2, -radius * 0.34), soft_color, maxf(0.75, radius * 0.64), true)
			_canvas_draw_circle(center, radius * 0.40, core_color)
		_:
			_canvas_draw_circle(center, radius * 3.0, halo_color)
			_canvas_draw_circle(center, radius * 1.35, soft_color)
			_canvas_draw_circle(center, radius * 0.42, core_color)

func _draw_terrain_ambient_layer() -> void:
	if _session == null or _terrain_ambient_layer == null:
		return
	var previous_target = _draw_canvas_item
	_draw_canvas_item = _terrain_ambient_layer
	var viewport_rect := _map_viewport_rect()
	var board_rect := _board_rect()
	var visible_bounds := _visible_tile_bounds(board_rect, viewport_rect)
	var phase := TERRAIN_AMBIENT_STATIC_PHASE if SettingsService.reduced_motion_enabled() else _terrain_ambient_phase
	var entries := _overworld_terrain_ambient_entries(board_rect, visible_bounds, phase)
	for entry_value in entries:
		if entry_value is Dictionary:
			_draw_overworld_terrain_ambient_entry(entry_value)
	_draw_canvas_item = previous_target
	_profile_add("terrain_ambient_draws", entries.size())

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
	_draw_placement_debug_overlay(board_rect, visible_bounds)
	for y in range(visible_bounds.position.y, visible_bounds.position.y + visible_bounds.size.y):
		for x in range(visible_bounds.position.x, visible_bounds.position.x + visible_bounds.size.x):
			var tile = Vector2i(x, y)
			var rect = _tile_rect(board_rect, tile)
			tile_checks += 1
			_draw_tile_focus(tile, rect)
			_draw_tile_dynamic_icon(tile, rect)
	_draw_hero_movement_presentation(board_rect)
	_draw_object_resolution_presentation(board_rect)
	_draw_route_blocked_presentation(board_rect)
	_draw_object_focus_presentation(board_rect)
	_draw_guarded_site_presentation(board_rect)
	_draw_spell_cast_presentation(board_rect)
	_draw_canvas_item = previous_target
	_profile_add("dynamic_tile_checks", tile_checks)
	_profile_end("draw_dynamic", profile_start, {
		"tile_checks": tile_checks,
		"visible_bounds": _rect2i_payload(visible_bounds),
	})

func _draw_placement_debug_overlay(board_rect: Rect2, visible_bounds: Rect2i) -> void:
	if not _placement_debug_overlay_enabled:
		return
	var payload := _placement_debug_overlay_payload()
	var blocker_tiles: Array = payload.get("blocker_tiles", []) if payload.get("blocker_tiles", []) is Array else []
	var interactable_tiles: Array = payload.get("interactable_tiles", []) if payload.get("interactable_tiles", []) is Array else []
	for tile_payload in blocker_tiles:
		var tile := _tile_from_payload(tile_payload)
		if not _tile_in_visible_bounds(tile, visible_bounds):
			continue
		_draw_placement_debug_tile(board_rect, tile, PLACEMENT_DEBUG_BLOCKER_FILL, PLACEMENT_DEBUG_BLOCKER_BORDER)
	for tile_payload in interactable_tiles:
		var tile := _tile_from_payload(tile_payload)
		if not _tile_in_visible_bounds(tile, visible_bounds):
			continue
		_draw_placement_debug_tile(board_rect, tile, PLACEMENT_DEBUG_INTERACTABLE_FILL, PLACEMENT_DEBUG_INTERACTABLE_BORDER)

func _draw_placement_debug_tile(board_rect: Rect2, tile: Vector2i, fill_color: Color, border_color: Color) -> void:
	var rect := _tile_rect(board_rect, tile).grow(-1.0)
	_canvas_draw_rect(rect, fill_color, true)
	_canvas_draw_rect(rect, border_color, false, maxf(1.0, rect.size.x * 0.035))

func _draw_tile_background(tile: Vector2i, rect: Rect2) -> void:
	_draw_tile_session_static_background(tile, rect)
	_draw_tile_state_overlay(tile, rect)

func _draw_tile_session_static_background(tile: Vector2i, rect: Rect2) -> void:
	_draw_tile_terrain_surface(tile, rect)
	_draw_terrain_macro_lighting(tile, rect)
	_draw_road_overlay(tile, rect)

func _draw_tile_terrain_surface(tile: Vector2i, rect: Rect2) -> void:
	var terrain = _terrain_at(tile)
	if terrain == "":
		return
	if not _draw_terrain_tile_art(tile, rect, terrain):
		var base_color: Color = _terrain_color(terrain, "base_color", TERRAIN_COLORS.get(terrain, TERRAIN_COLORS["grass"]))
		_canvas_draw_rect(rect, base_color, true)
		_draw_authored_terrain_pattern(tile, rect, terrain, true)
	_draw_painterly_terrain_microtexture(tile, rect, terrain)
	_draw_terrain_transitions(tile, rect, terrain)

func _draw_painterly_terrain_microtexture(tile: Vector2i, rect: Rect2, terrain: String) -> void:
	var terrain_group := _terrain_group(terrain)
	if terrain_group == "water" or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var detail_color: Color = _terrain_color(terrain, "detail_color", Color(0.70, 0.68, 0.48, 1.0))
	var extent := minf(rect.size.x, rect.size.y)
	var line_width := maxf(0.7, extent * 0.009)
	for stroke_index in range(TERRAIN_MICROTEXTURE_STROKE_COUNT):
		var key := "%d:%d:%s:%d" % [tile.x, tile.y, terrain, stroke_index]
		var start_factor := Vector2(
			lerpf(0.10, 0.82, _stable_unit_fraction("micro_x:%s" % key)),
			lerpf(0.14, 0.86, _stable_unit_fraction("micro_y:%s" % key))
		)
		var length_factor := lerpf(TERRAIN_MICROTEXTURE_MIN_LENGTH_FACTOR, TERRAIN_MICROTEXTURE_MAX_LENGTH_FACTOR, _stable_unit_fraction("micro_length:%s" % key))
		var angle := lerpf(-0.72, 0.38, _stable_unit_fraction("micro_angle:%s" % key))
		var direction := Vector2(cos(angle), sin(angle))
		var start := rect.position + rect.size * start_factor
		var finish := start + direction * extent * length_factor
		var shadow_color := Color(0.025, 0.035, 0.025, TERRAIN_MICROTEXTURE_SHADOW_ALPHA)
		var highlight_color := Color(detail_color.r, detail_color.g, detail_color.b, TERRAIN_MICROTEXTURE_HIGHLIGHT_ALPHA)
		_canvas_draw_line(start + Vector2(0.0, line_width), finish + Vector2(0.0, line_width), shadow_color, line_width + 0.5, true)
		_canvas_draw_line(start, finish, highlight_color, line_width, true)

func _draw_tile_state_overlay(tile: Vector2i, rect: Rect2) -> void:
	if not OverworldRulesScript.is_tile_explored(_session, tile.x, tile.y):
		_canvas_draw_rect(rect, UNEXPLORED_COLOR, true)
		_draw_unexplored_shroud(tile, rect)
		return
	_draw_explored_terrain_boundary(tile, rect)

func _draw_unexplored_shroud(tile: Vector2i, rect: Rect2) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	_canvas_draw_rect(rect, UNEXPLORED_SHROUD_BASE, true)
	var texture = _unexplored_shroud_texture()
	if texture is Texture2D:
		_canvas_draw_texture_rect_region(texture, rect, _unexplored_shroud_source_rect(tile), UNEXPLORED_SHROUD_TEXTURE_MODULATE)

func _unexplored_shroud_texture():
	var texture = _terrain_art_texture(UNEXPLORED_SHROUD_TEXTURE_PATH)
	if texture is Texture2D and Vector2i(texture.get_size()) == UNEXPLORED_SHROUD_TEXTURE_SIZE:
		return texture
	return null

func _unexplored_shroud_source_rect(tile: Vector2i) -> Rect2:
	var normalized_size := Vector2(
		float(UNEXPLORED_SHROUD_TEXTURE_SIZE.x) / float(maxi(_map_size.x, 1)),
		float(UNEXPLORED_SHROUD_TEXTURE_SIZE.y) / float(maxi(_map_size.y, 1))
	)
	return Rect2(Vector2(tile) * normalized_size, normalized_size)

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
	for direction_value in _explored_fog_frontier_directions(tile):
		var direction := String(direction_value)
		_draw_explored_fog_frontier_feather(tile, rect, direction)
		_draw_explored_fog_frontier_edge(tile, rect, direction)

func _explored_fog_frontier_directions(tile: Vector2i) -> Array:
	if _session == null:
		return []
	var checks := {
		"N": Vector2i(0, -1),
		"E": Vector2i(1, 0),
		"S": Vector2i(0, 1),
		"W": Vector2i(-1, 0),
	}
	var directions: Array = []
	for direction in ["N", "E", "S", "W"]:
		var neighbor: Vector2i = tile + checks[direction]
		if neighbor.x < 0 or neighbor.y < 0 or neighbor.x >= _map_size.x or neighbor.y >= _map_size.y:
			continue
		if OverworldRulesScript.is_tile_explored(_session, neighbor.x, neighbor.y):
			continue
		directions.append(direction)
	return directions

func _explored_fog_frontier_boundary_segment(rect: Rect2, direction: String) -> PackedVector2Array:
	match direction:
		"N":
			return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y)])
		"S":
			return PackedVector2Array([Vector2(rect.position.x, rect.end.y), rect.end])
		"W":
			return PackedVector2Array([rect.position, Vector2(rect.position.x, rect.end.y)])
		"E":
			return PackedVector2Array([Vector2(rect.end.x, rect.position.y), rect.end])
	return PackedVector2Array()

func _explored_fog_frontier_inward_offset(rect: Rect2, direction: String) -> Vector2:
	match direction:
		"N":
			return Vector2(0.0, rect.size.y * EXPLORED_FOG_FRONTIER_DEPTH_FACTOR)
		"S":
			return Vector2(0.0, -rect.size.y * EXPLORED_FOG_FRONTIER_DEPTH_FACTOR)
		"W":
			return Vector2(rect.size.x * EXPLORED_FOG_FRONTIER_DEPTH_FACTOR, 0.0)
		"E":
			return Vector2(-rect.size.x * EXPLORED_FOG_FRONTIER_DEPTH_FACTOR, 0.0)
	return Vector2.ZERO

func _explored_fog_frontier_feather_colors() -> PackedColorArray:
	var edge_color := Color(
		EXPLORED_FOG_FRONTIER_COLOR.r,
		EXPLORED_FOG_FRONTIER_COLOR.g,
		EXPLORED_FOG_FRONTIER_COLOR.b,
		EXPLORED_FOG_FRONTIER_EDGE_ALPHA
	)
	var inner_color := Color(
		EXPLORED_FOG_FRONTIER_COLOR.r,
		EXPLORED_FOG_FRONTIER_COLOR.g,
		EXPLORED_FOG_FRONTIER_COLOR.b,
		EXPLORED_FOG_FRONTIER_INNER_ALPHA
	)
	return PackedColorArray([edge_color, edge_color, inner_color, inner_color])

func _explored_fog_frontier_cap_points(tile: Vector2i, rect: Rect2, direction: String) -> PackedVector2Array:
	var boundary := _explored_fog_frontier_boundary_segment(rect, direction)
	var contour := _explored_fog_frontier_edge_points(tile, rect, direction)
	if boundary.size() != 2 or contour.size() != EXPLORED_FOG_CONTOUR_POINT_COUNT:
		return PackedVector2Array()
	var points := PackedVector2Array([boundary[0], boundary[1]])
	for point_index in range(contour.size() - 2, 0, -1):
		points.append(contour[point_index])
	return points

func _draw_explored_fog_frontier_feather(tile: Vector2i, rect: Rect2, direction: String) -> void:
	var contour := _explored_fog_frontier_edge_points(tile, rect, direction)
	if contour.size() != EXPLORED_FOG_CONTOUR_POINT_COUNT:
		return
	var cap_points := _explored_fog_frontier_cap_points(tile, rect, direction)
	if cap_points.size() >= 3:
		_canvas_draw_colored_polygon(cap_points, Color(
			EXPLORED_FOG_FRONTIER_COLOR.r,
			EXPLORED_FOG_FRONTIER_COLOR.g,
			EXPLORED_FOG_FRONTIER_COLOR.b,
			EXPLORED_FOG_FRONTIER_CAP_ALPHA
		))
	var inward_offset := _explored_fog_frontier_inward_offset(rect, direction)
	var feather_colors := _explored_fog_frontier_feather_colors()
	for point_index in range(contour.size() - 1):
		var edge_start: Vector2 = contour[point_index]
		var edge_end: Vector2 = contour[point_index + 1]
		_canvas_draw_polygon(PackedVector2Array([
			edge_start,
			edge_end,
			edge_end + inward_offset,
			edge_start + inward_offset,
		]), feather_colors)

func _explored_fog_frontier_edge_points(tile: Vector2i, rect: Rect2, direction: String) -> PackedVector2Array:
	if direction not in ["N", "E", "S", "W"] or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return PackedVector2Array()
	var points := PackedVector2Array()
	for point_index in range(EXPLORED_FOG_CONTOUR_POINT_COUNT):
		var progress := float(point_index) / float(EXPLORED_FOG_CONTOUR_POINT_COUNT - 1)
		var inset_factor := 0.0
		if point_index > 0 and point_index < EXPLORED_FOG_CONTOUR_POINT_COUNT - 1:
			var variation := _stable_unit_fraction("fog_contour:%d:%d:%s:%d" % [tile.x, tile.y, direction, point_index])
			inset_factor = lerpf(EXPLORED_FOG_CONTOUR_MIN_INSET_FACTOR, EXPLORED_FOG_CONTOUR_MAX_INSET_FACTOR, variation)
		match direction:
			"N":
				points.append(Vector2(lerpf(rect.position.x, rect.end.x, progress), rect.position.y + (rect.size.y * inset_factor)))
			"S":
				points.append(Vector2(lerpf(rect.position.x, rect.end.x, progress), rect.end.y - (rect.size.y * inset_factor)))
			"W":
				points.append(Vector2(rect.position.x + (rect.size.x * inset_factor), lerpf(rect.position.y, rect.end.y, progress)))
			"E":
				points.append(Vector2(rect.end.x - (rect.size.x * inset_factor), lerpf(rect.position.y, rect.end.y, progress)))
	return points

func _draw_explored_fog_frontier_edge(tile: Vector2i, rect: Rect2, direction: String) -> void:
	var points := _explored_fog_frontier_edge_points(tile, rect, direction)
	if points.size() != EXPLORED_FOG_CONTOUR_POINT_COUNT:
		return
	_canvas_draw_polyline(points, EXPLORED_TERRAIN_FOG_BOUNDARY_COLOR, EXPLORED_TERRAIN_FOG_BOUNDARY_WIDTH, true)

func _explored_fog_frontier_payload(tile: Vector2i) -> Dictionary:
	var directions := _explored_fog_frontier_directions(tile)
	var softened_corners: Array = []
	var contour_profiles: Dictionary = {}
	for direction_value in directions:
		var direction := String(direction_value)
		var profile: Array = []
		for point in _explored_fog_frontier_edge_points(tile, Rect2(Vector2.ZERO, Vector2.ONE), direction):
			profile.append(_vector2_payload(point))
		contour_profiles[direction] = profile
	for corner in [
		{"id": "NE", "edges": ["N", "E"]},
		{"id": "SE", "edges": ["S", "E"]},
		{"id": "SW", "edges": ["S", "W"]},
		{"id": "NW", "edges": ["N", "W"]},
	]:
		var edges: Array = corner.get("edges", [])
		if directions.has(edges[0]) and directions.has(edges[1]):
			softened_corners.append(String(corner.get("id", "")))
	return {
		"model": EXPLORED_FOG_FRONTIER_MODEL,
		"drawn": not directions.is_empty(),
		"directions": directions.duplicate(),
		"direction_order": ["N", "E", "S", "W"],
		"softened_corners": softened_corners,
		"surface_model": EXPLORED_FOG_FRONTIER_SURFACE_MODEL,
		"cap_alpha": EXPLORED_FOG_FRONTIER_CAP_ALPHA,
		"cap_polygon_point_count": EXPLORED_FOG_CONTOUR_POINT_COUNT,
		"gradient_stop_count": 2,
		"gradient_depth_factor": EXPLORED_FOG_FRONTIER_DEPTH_FACTOR,
		"gradient_edge_alpha": EXPLORED_FOG_FRONTIER_EDGE_ALPHA,
		"gradient_inner_alpha": EXPLORED_FOG_FRONTIER_INNER_ALPHA,
		"gradient_segment_count_per_direction": EXPLORED_FOG_CONTOUR_POINT_COUNT - 1,
		"edge_alpha": EXPLORED_TERRAIN_FOG_BOUNDARY_COLOR.a,
		"edge_width": EXPLORED_TERRAIN_FOG_BOUNDARY_WIDTH,
		"contour_profiles": contour_profiles.duplicate(true),
		"contour_point_count": EXPLORED_FOG_CONTOUR_POINT_COUNT,
		"contour_min_inset_factor": EXPLORED_FOG_CONTOUR_MIN_INSET_FACTOR,
		"contour_max_inset_factor": EXPLORED_FOG_CONTOUR_MAX_INSET_FACTOR,
		"contour_endpoints_on_boundary": true,
		"contour_hidden_side_intrusion": false,
		"contour_variation_basis": "explored_tile_direction_only",
		"draw_side": "explored_inward",
		"neighbor_basis": "cardinal_explored_boolean_only",
		"hidden_identity_sampled": false,
		"interior_explored_seams": false,
	}

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

func _draw_terrain_macro_lighting(tile: Vector2i, rect: Rect2) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var samples := _terrain_macro_lighting_corner_samples(tile)
	if samples.size() != 4:
		return
	var points := PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	])
	var colors := PackedColorArray()
	for sample_value in samples:
		colors.append(_terrain_macro_lighting_color(float(sample_value)))
	_canvas_draw_polygon(points, colors)

func _draw_terrain_grain_overlay(board_rect: Rect2) -> bool:
	if board_rect.size.x <= 0.0 or board_rect.size.y <= 0.0:
		return false
	var texture = _terrain_art_texture(TERRAIN_GRAIN_TEXTURE_PATH)
	if not (texture is Texture2D) or Vector2i(texture.get_size()) != TERRAIN_GRAIN_EXPECTED_SIZE:
		return false
	_canvas_draw_texture_rect(texture, board_rect, false, TERRAIN_GRAIN_MODULATE)
	return true

func _terrain_grain_overlay_payload(explored: bool) -> Dictionary:
	if not explored:
		return {
			"model": TERRAIN_GRAIN_MODEL,
			"drawn": false,
			"hidden_by_unexplored_shroud": true,
			"terrain_identity_sampled": false,
		}
	var texture = _terrain_art_texture(TERRAIN_GRAIN_TEXTURE_PATH)
	var texture_loaded := texture is Texture2D and Vector2i(texture.get_size()) == TERRAIN_GRAIN_EXPECTED_SIZE
	return {
		"model": TERRAIN_GRAIN_MODEL,
		"source_model": TERRAIN_GRAIN_SOURCE_MODEL,
		"drawn": texture_loaded,
		"texture_loaded": texture_loaded,
		"texture_path": TERRAIN_GRAIN_TEXTURE_PATH if texture_loaded else "",
		"texture_size": {"x": TERRAIN_GRAIN_EXPECTED_SIZE.x, "y": TERRAIN_GRAIN_EXPECTED_SIZE.y},
		"modulate_alpha": TERRAIN_GRAIN_MODULATE.a,
		"mapping": "whole_board_normalized_once",
		"repeated_per_tile": false,
		"seamless_outer_edges": true,
		"terrain_identity_sampled": false,
		"draw_order": "after_terrain_transitions_before_macro_lighting_and_roads",
		"hidden_by_unexplored_shroud": true,
	}

func _terrain_detail_decal_cells_for_group(terrain_group: String) -> Array:
	match terrain_group:
		"grasslands":
			return [0, 4, 8, 12]
		"forest":
			return [1, 5, 9, 13]
		"mire":
			return [3, 7, 11, 15]
		"rough", "rock", "underground":
			return [2, 6, 10, 14]
		"dirt", "sand":
			return [2, 6, 10, 14]
		"ash":
			return [2, 6, 10, 14]
	return []

func _terrain_detail_decal_payload(tile: Vector2i, rect: Rect2) -> Dictionary:
	var terrain := _terrain_at(tile)
	var terrain_group := _terrain_group(terrain)
	var texture = _terrain_art_texture(TERRAIN_DETAIL_DECAL_TEXTURE_PATH)
	var texture_loaded := texture is Texture2D and Vector2i(texture.get_size()) == TERRAIN_DETAIL_DECAL_ATLAS_SIZE
	var cell_ids := _terrain_detail_decal_cells_for_group(terrain_group)
	# Hash the complete coordinate key instead of reducing a linear x/y expression.
	# The former expression made the sparse accents land on a visible diagonal lattice.
	var seed := absi(("terrain_detail:%d:%d:%s" % [tile.x, tile.y, terrain]).hash())
	var density_residue := posmod(seed, TERRAIN_DETAIL_DECAL_DENSITY_MODULUS)
	var road_excluded := not _road_tile_payload(tile).is_empty()
	var eligible := texture_loaded and not terrain.is_empty() and not cell_ids.is_empty() and not road_excluded and density_residue in TERRAIN_DETAIL_DECAL_ACTIVE_RESIDUES
	var cell_id := int(cell_ids[posmod(floori(float(seed) / float(TERRAIN_DETAIL_DECAL_DENSITY_MODULUS)), cell_ids.size())]) if eligible else -1
	var extent_factor := lerpf(
		TERRAIN_DETAIL_DECAL_MIN_EXTENT_FACTOR,
		TERRAIN_DETAIL_DECAL_MAX_EXTENT_FACTOR,
		_stable_unit_fraction("terrain_detail_extent:%d:%d:%s" % [tile.x, tile.y, terrain])
	)
	var offset_factor := Vector2(
		lerpf(-TERRAIN_DETAIL_DECAL_MAX_OFFSET_X_FACTOR, TERRAIN_DETAIL_DECAL_MAX_OFFSET_X_FACTOR, _stable_unit_fraction("terrain_detail_x:%d:%d:%s" % [tile.x, tile.y, terrain])),
		lerpf(TERRAIN_DETAIL_DECAL_MIN_OFFSET_Y_FACTOR, TERRAIN_DETAIL_DECAL_MAX_OFFSET_Y_FACTOR, _stable_unit_fraction("terrain_detail_y:%d:%d:%s" % [tile.x, tile.y, terrain]))
	)
	var extent := minf(rect.size.x, rect.size.y) * extent_factor
	var destination_center := rect.get_center() + Vector2(rect.size.x * offset_factor.x, rect.size.y * offset_factor.y)
	var destination_rect := Rect2(destination_center - Vector2(extent, extent) * 0.5, Vector2(extent, extent))
	var source_rect := Rect2()
	if cell_id >= 0:
		source_rect = Rect2(
			Vector2(float(cell_id % TERRAIN_DETAIL_DECAL_GRID_SIZE.x), float(floori(float(cell_id) / float(TERRAIN_DETAIL_DECAL_GRID_SIZE.x)))) * Vector2(TERRAIN_DETAIL_DECAL_CELL_SIZE),
			Vector2(TERRAIN_DETAIL_DECAL_CELL_SIZE)
		)
	return {
		"model": TERRAIN_DETAIL_DECAL_MODEL,
		"source_model": TERRAIN_DETAIL_DECAL_SOURCE_MODEL,
		"drawn": eligible,
		"terrain_group": terrain_group,
		"atlas_texture_loaded": texture_loaded,
		"atlas_texture_path": TERRAIN_DETAIL_DECAL_TEXTURE_PATH if texture_loaded else "",
		"atlas_size": _vector2i_payload(TERRAIN_DETAIL_DECAL_ATLAS_SIZE),
		"atlas_grid": _vector2i_payload(TERRAIN_DETAIL_DECAL_GRID_SIZE),
		"atlas_cell_size": _vector2i_payload(TERRAIN_DETAIL_DECAL_CELL_SIZE),
		"cell_id": cell_id,
		"source_rect": _rect_payload(source_rect),
		"destination_rect": _rect_payload(destination_rect),
		"destination_contained": rect.encloses(destination_rect),
		"extent_factor": extent_factor,
		"offset_factor": _vector2_payload(offset_factor),
		"density_modulus": TERRAIN_DETAIL_DECAL_DENSITY_MODULUS,
		"active_density_residues": TERRAIN_DETAIL_DECAL_ACTIVE_RESIDUES.duplicate(),
		"density_residue": density_residue,
		"road_excluded": road_excluded,
		"water_excluded": terrain_group == "water",
		"interactive": false,
		"collision": false,
		"modulate_alpha": TERRAIN_DETAIL_DECAL_MODULATE.a,
		"draw_order": "after_macro_lighting_before_roads_objects_and_fog",
		"hidden_by_unexplored_shroud": true,
		"variation_basis": "tile_coordinate_and_terrain_id_only",
	}

func _draw_terrain_detail_decal(tile: Vector2i, rect: Rect2) -> bool:
	var payload := _terrain_detail_decal_payload(tile, rect)
	if not bool(payload.get("drawn", false)):
		return false
	var texture = _terrain_art_texture(TERRAIN_DETAIL_DECAL_TEXTURE_PATH)
	if not (texture is Texture2D):
		return false
	var destination_payload: Dictionary = payload.get("destination_rect", {})
	var source_payload: Dictionary = payload.get("source_rect", {})
	var destination_rect := Rect2(
		Vector2(float(destination_payload.get("x", 0.0)), float(destination_payload.get("y", 0.0))),
		Vector2(float(destination_payload.get("width", 0.0)), float(destination_payload.get("height", 0.0)))
	)
	var source_rect := Rect2(
		Vector2(float(source_payload.get("x", 0.0)), float(source_payload.get("y", 0.0))),
		Vector2(float(source_payload.get("width", 0.0)), float(source_payload.get("height", 0.0)))
	)
	_canvas_draw_texture_rect_region(texture, destination_rect, source_rect, TERRAIN_DETAIL_DECAL_MODULATE)
	return true

func _water_surface_ripple_profiles(tile: Vector2i, rect: Rect2) -> Array:
	var profiles: Array = []
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return profiles
	for ripple_index in range(WATER_SURFACE_RIPPLE_COUNT):
		var x_center := lerpf(0.30, 0.70, _stable_unit_fraction("water_ripple_x:%d:%d:%d" % [tile.x, tile.y, ripple_index]))
		var y_base := 0.32 if ripple_index == 0 else 0.66
		var y_center := y_base + lerpf(-0.055, 0.055, _stable_unit_fraction("water_ripple_y:%d:%d:%d" % [tile.x, tile.y, ripple_index]))
		var length_factor := lerpf(WATER_SURFACE_RIPPLE_MIN_LENGTH_FACTOR, WATER_SURFACE_RIPPLE_MAX_LENGTH_FACTOR, _stable_unit_fraction("water_ripple_length:%d:%d:%d" % [tile.x, tile.y, ripple_index]))
		var curve_factor := lerpf(WATER_SURFACE_RIPPLE_MIN_CURVE_FACTOR, WATER_SURFACE_RIPPLE_MAX_CURVE_FACTOR, _stable_unit_fraction("water_ripple_curve:%d:%d:%d" % [tile.x, tile.y, ripple_index]))
		var curve_direction := -1.0 if posmod(tile.x + tile.y + ripple_index, 2) == 0 else 1.0
		var start_factor := clampf(x_center - (length_factor * 0.5), 0.08, 0.92 - length_factor)
		var points := PackedVector2Array()
		for point_index in range(WATER_SURFACE_RIPPLE_POINT_COUNT):
			var progress := float(point_index) / float(WATER_SURFACE_RIPPLE_POINT_COUNT - 1)
			var x_factor := start_factor + (length_factor * progress)
			var y_factor := y_center + (sin(progress * PI) * curve_factor * curve_direction)
			points.append(rect.position + rect.size * Vector2(x_factor, y_factor))
		profiles.append(points)
	return profiles

func _water_surface_ripple_payload(tile: Vector2i, rect: Rect2) -> Dictionary:
	var terrain := _terrain_at(tile)
	var terrain_group := _terrain_group(terrain)
	var road_excluded := not _road_tile_payload(tile).is_empty()
	var density_residue := posmod(absi((tile.x * 137) + (tile.y * 223)), WATER_SURFACE_RIPPLE_DENSITY_MODULUS)
	var drawn := terrain_group == "water" and not road_excluded and density_residue in WATER_SURFACE_RIPPLE_ACTIVE_RESIDUES
	var profiles := _water_surface_ripple_profiles(tile, rect) if drawn else []
	var normalized_profiles: Array = []
	var geometry_contained := drawn and profiles.size() == WATER_SURFACE_RIPPLE_COUNT
	for profile_value in profiles:
		var profile: PackedVector2Array = profile_value
		var normalized_profile: Array = []
		for point in profile:
			normalized_profile.append(_vector2_payload(point))
			geometry_contained = geometry_contained and rect.has_point(point)
		normalized_profiles.append(normalized_profile)
	return {
		"model": WATER_SURFACE_RIPPLE_MODEL,
		"drawn": drawn,
		"terrain_group": terrain_group,
		"road_excluded": road_excluded,
		"density_modulus": WATER_SURFACE_RIPPLE_DENSITY_MODULUS,
		"active_residues": WATER_SURFACE_RIPPLE_ACTIVE_RESIDUES.duplicate(),
		"density_residue": density_residue,
		"ripple_count": profiles.size(),
		"point_count_per_ripple": WATER_SURFACE_RIPPLE_POINT_COUNT,
		"profiles": normalized_profiles,
		"geometry_contained": geometry_contained,
		"min_length_factor": WATER_SURFACE_RIPPLE_MIN_LENGTH_FACTOR,
		"max_length_factor": WATER_SURFACE_RIPPLE_MAX_LENGTH_FACTOR,
		"min_curve_factor": WATER_SURFACE_RIPPLE_MIN_CURVE_FACTOR,
		"max_curve_factor": WATER_SURFACE_RIPPLE_MAX_CURVE_FACTOR,
		"shadow_alpha": WATER_SURFACE_RIPPLE_SHADOW_COLOR.a,
		"highlight_alpha": WATER_SURFACE_RIPPLE_HIGHLIGHT_COLOR.a,
		"interactive": false,
		"collision": false,
		"animated": false,
		"variation_basis": "tile_coordinate_and_ripple_index_only",
		"draw_order": "after_macro_lighting_before_causeways_objects_routes_selection_and_fog",
		"hidden_by_unexplored_shroud": true,
	}

func _draw_water_surface_ripples(tile: Vector2i, rect: Rect2) -> bool:
	var payload := _water_surface_ripple_payload(tile, rect)
	if not bool(payload.get("drawn", false)):
		return false
	var profiles := _water_surface_ripple_profiles(tile, rect)
	var extent := minf(rect.size.x, rect.size.y)
	for profile_value in profiles:
		var profile: PackedVector2Array = profile_value
		var shadow_profile := PackedVector2Array()
		for point in profile:
			shadow_profile.append(point + Vector2(0.0, extent * 0.018))
		_canvas_draw_polyline(shadow_profile, WATER_SURFACE_RIPPLE_SHADOW_COLOR, maxf(1.2, extent * WATER_SURFACE_RIPPLE_SHADOW_WIDTH_FACTOR), true)
		_canvas_draw_polyline(profile, WATER_SURFACE_RIPPLE_HIGHLIGHT_COLOR, maxf(1.0, extent * WATER_SURFACE_RIPPLE_HIGHLIGHT_WIDTH_FACTOR), true)
	return true

func _draw_terrain_macro_lighting_field(board_rect: Rect2, visible_bounds: Rect2i) -> int:
	if board_rect.size.x <= 0.0 or board_rect.size.y <= 0.0 or visible_bounds.size.x <= 0 or visible_bounds.size.y <= 0:
		return 0
	var tile_extent := board_rect.size.x / float(maxi(_map_size.x, 1))
	var cell_size := float(TERRAIN_MACRO_LIGHTING_CELL_TILES)
	var first_cell := Vector2i(
		floori(float(visible_bounds.position.x) / cell_size),
		floori(float(visible_bounds.position.y) / cell_size)
	)
	var last_cell := Vector2i(
		floori((float(visible_bounds.end.x) - 0.001) / cell_size),
		floori((float(visible_bounds.end.y) - 0.001) / cell_size)
	)
	var polygon_draws := 0
	for cell_y in range(first_cell.y, last_cell.y + 1):
		for cell_x in range(first_cell.x, last_cell.x + 1):
			var cell_origin := Vector2(float(cell_x), float(cell_y)) * cell_size
			var cell_end := cell_origin + Vector2.ONE * cell_size
			var clipped_origin := Vector2(
				maxf(cell_origin.x, float(visible_bounds.position.x)),
				maxf(cell_origin.y, float(visible_bounds.position.y))
			)
			var clipped_end := Vector2(
				minf(cell_end.x, float(visible_bounds.end.x)),
				minf(cell_end.y, float(visible_bounds.end.y))
			)
			var x_steps: Array[float] = [clipped_origin.x]
			var y_steps: Array[float] = [clipped_origin.y]
			for subdivision in range(1, TERRAIN_MACRO_LIGHTING_CELL_SUBDIVISIONS):
				var fraction := float(subdivision) / float(TERRAIN_MACRO_LIGHTING_CELL_SUBDIVISIONS)
				var split_x := lerpf(cell_origin.x, cell_end.x, fraction)
				var split_y := lerpf(cell_origin.y, cell_end.y, fraction)
				if split_x > clipped_origin.x and split_x < clipped_end.x:
					x_steps.append(split_x)
				if split_y > clipped_origin.y and split_y < clipped_end.y:
					y_steps.append(split_y)
			x_steps.append(clipped_end.x)
			y_steps.append(clipped_end.y)
			for y_index in range(y_steps.size() - 1):
				for x_index in range(x_steps.size() - 1):
					var map_north_west := Vector2(x_steps[x_index], y_steps[y_index])
					var map_south_east := Vector2(x_steps[x_index + 1], y_steps[y_index + 1])
					var map_north_east := Vector2(map_south_east.x, map_north_west.y)
					var map_south_west := Vector2(map_north_west.x, map_south_east.y)
					var points := PackedVector2Array([
						board_rect.position + map_north_west * tile_extent,
						board_rect.position + map_north_east * tile_extent,
						board_rect.position + map_south_east * tile_extent,
						board_rect.position + map_south_west * tile_extent,
					])
					var colors := PackedColorArray([
						_terrain_macro_lighting_color(_terrain_macro_lighting_sample_at(map_north_west)),
						_terrain_macro_lighting_color(_terrain_macro_lighting_sample_at(map_north_east)),
						_terrain_macro_lighting_color(_terrain_macro_lighting_sample_at(map_south_east)),
						_terrain_macro_lighting_color(_terrain_macro_lighting_sample_at(map_south_west)),
					])
					_canvas_draw_polygon(points, colors)
					polygon_draws += 1
	return polygon_draws

func _terrain_macro_lighting_color(sample_value: float) -> Color:
	var sample := clampf(sample_value, 0.0, 1.0)
	if sample < 0.50:
		return Color(
			TERRAIN_MACRO_LIGHTING_SHADOW_COLOR.r,
			TERRAIN_MACRO_LIGHTING_SHADOW_COLOR.g,
			TERRAIN_MACRO_LIGHTING_SHADOW_COLOR.b,
			clampf((0.50 - sample) * 2.0, 0.0, 1.0) * TERRAIN_MACRO_LIGHTING_SHADOW_MAX_ALPHA
		)
	return Color(
		TERRAIN_MACRO_LIGHTING_HIGHLIGHT_COLOR.r,
		TERRAIN_MACRO_LIGHTING_HIGHLIGHT_COLOR.g,
		TERRAIN_MACRO_LIGHTING_HIGHLIGHT_COLOR.b,
		clampf((sample - 0.50) * 2.0, 0.0, 1.0) * TERRAIN_MACRO_LIGHTING_HIGHLIGHT_MAX_ALPHA
	)

func _terrain_macro_lighting_corner_samples(tile: Vector2i) -> Array:
	return [
		_terrain_macro_lighting_sample(tile),
		_terrain_macro_lighting_sample(tile + Vector2i.RIGHT),
		_terrain_macro_lighting_sample(tile + Vector2i(1, 1)),
		_terrain_macro_lighting_sample(tile + Vector2i.DOWN),
	]

func _terrain_macro_lighting_sample(lattice_point: Vector2i) -> float:
	return _terrain_macro_lighting_sample_at(Vector2(lattice_point))

func _terrain_macro_lighting_sample_at(map_point: Vector2) -> float:
	var cell_size := TERRAIN_MACRO_LIGHTING_CELL_TILES
	var macro_cell := Vector2i(
		floori(map_point.x / float(cell_size)),
		floori(map_point.y / float(cell_size))
	)
	var local_x := (map_point.x - float(macro_cell.x * cell_size)) / float(cell_size)
	var local_y := (map_point.y - float(macro_cell.y * cell_size)) / float(cell_size)
	var smooth_x := local_x * local_x * (3.0 - 2.0 * local_x)
	var smooth_y := local_y * local_y * (3.0 - 2.0 * local_y)
	var north_west := _terrain_macro_lighting_anchor_value(macro_cell)
	var north_east := _terrain_macro_lighting_anchor_value(macro_cell + Vector2i.RIGHT)
	var south_west := _terrain_macro_lighting_anchor_value(macro_cell + Vector2i.DOWN)
	var south_east := _terrain_macro_lighting_anchor_value(macro_cell + Vector2i(1, 1))
	return lerpf(lerpf(north_west, north_east, smooth_x), lerpf(south_west, south_east, smooth_x), smooth_y)

func _terrain_macro_lighting_anchor_value(anchor: Vector2i) -> float:
	var value := sin(float(anchor.x) * 12.9898 + float(anchor.y) * 78.233 + 31.416) * 43758.5453
	return value - floor(value)

func _terrain_macro_lighting_payload(tile: Vector2i) -> Dictionary:
	var samples := _terrain_macro_lighting_corner_samples(tile)
	return {
		"model": TERRAIN_MACRO_LIGHTING_MODEL,
		"cell_tiles": TERRAIN_MACRO_LIGHTING_CELL_TILES,
		"shadow_max_alpha": TERRAIN_MACRO_LIGHTING_SHADOW_MAX_ALPHA,
		"highlight_max_alpha": TERRAIN_MACRO_LIGHTING_HIGHLIGHT_MAX_ALPHA,
		"corner_order": ["NW", "NE", "SE", "SW"],
		"corner_keys": [
			"%d,%d" % [tile.x, tile.y],
			"%d,%d" % [tile.x + 1, tile.y],
			"%d,%d" % [tile.x + 1, tile.y + 1],
			"%d,%d" % [tile.x, tile.y + 1],
		],
		"corner_samples": samples.duplicate(),
		"continuous_shared_corners": true,
		"draw_order": "after_terrain_transitions_before_roads",
		"hidden_by_unexplored_shroud": true,
	}

func _draw_terrain_transitions(tile: Vector2i, rect: Rect2, terrain: String) -> void:
	if _terrain_uses_self_contained_homm3_transition(tile, terrain):
		return
	var transition_payload := _terrain_generic_transition_payload(tile)
	var cardinal_sources = transition_payload.get("cardinal_sources", [])
	if cardinal_sources is Array:
		for source_value in cardinal_sources:
			if not (source_value is Dictionary):
				continue
			var source: Dictionary = source_value
			var direction := String(source.get("direction", ""))
			var source_terrain := String(source.get("source_terrain", terrain))
			if not _draw_terrain_edge_art(tile, source_terrain, direction, rect):
				_draw_terrain_edge_fallback(tile, source_terrain, direction, rect)
			if _terrain_group(source_terrain) == "water" and _terrain_group(terrain) != "water":
				_draw_water_shoreline_contour(tile, direction, rect)
	var corner_sources = transition_payload.get("corner_sources", [])
	if corner_sources is Array:
		for source_value in corner_sources:
			if not (source_value is Dictionary):
				continue
			var source: Dictionary = source_value
			var source_terrain := String(source.get("source_terrain", terrain))
			if _terrain_group(source_terrain) == "water":
				continue
			_draw_terrain_corner_hint(tile, source_terrain, String(source.get("direction", "")), rect)

func _terrain_uses_self_contained_homm3_transition(tile: Vector2i, terrain: String) -> bool:
	if not _homm3_runtime_rendering_enabled():
		return false
	var entry := _homm3_terrain_art_entry(terrain, tile)
	return not entry.is_empty() and _terrain_art_texture_for_entry(entry) is Texture2D

func _draw_terrain_edge_fallback(tile: Vector2i, source_terrain: String, direction: String, rect: Rect2) -> void:
	var edge_color := _terrain_color(source_terrain, "edge_color", Color(0.24, 0.26, 0.18, 1.0))
	var detail_color := _terrain_color(source_terrain, "detail_color", edge_color)
	var outer_profile := _terrain_edge_profile_points(tile, direction, rect, GENERIC_TERRAIN_EDGE_OUTER_DEPTH_FACTOR)
	var inner_profile := _terrain_edge_profile_points(tile, direction, rect, GENERIC_TERRAIN_EDGE_INNER_DEPTH_FACTOR)
	if outer_profile.is_empty() or inner_profile.is_empty():
		return
	_canvas_draw_colored_polygon(
		_terrain_edge_band_polygon(direction, rect, outer_profile),
		Color(edge_color.r, edge_color.g, edge_color.b, GENERIC_TERRAIN_EDGE_OUTER_ALPHA)
	)
	_canvas_draw_colored_polygon(
		_terrain_edge_band_polygon(direction, rect, inner_profile),
		Color(detail_color.r, detail_color.g, detail_color.b, GENERIC_TERRAIN_EDGE_INNER_ALPHA)
	)
	_canvas_draw_polyline(
		outer_profile,
		Color(edge_color.r, edge_color.g, edge_color.b, GENERIC_TERRAIN_EDGE_SEAM_ALPHA),
		maxf(1.0, minf(rect.size.x, rect.size.y) * 0.018),
		true
	)

func _terrain_edge_profile_points(tile: Vector2i, direction: String, rect: Rect2, depth_factor: float) -> PackedVector2Array:
	if direction not in ["N", "S", "W", "E"]:
		return PackedVector2Array()
	var extent := minf(rect.size.x, rect.size.y)
	var direction_seed: int = int({"N": 11, "E": 23, "S": 37, "W": 53}.get(direction, 0))
	var seed: int = absi((tile.x * 37) + (tile.y * 71) + int(direction_seed))
	var depth_weights := [0.78, 1.08, 0.88, 1.14, 0.82]
	var points := PackedVector2Array()
	for index in range(5):
		var fraction := float(index) / 4.0
		var weight := float(depth_weights[(index + seed) % depth_weights.size()])
		var depth := minf(maxf(2.0, extent * depth_factor * weight), maxf(4.0, 18.0 * weight))
		match direction:
			"N":
				points.append(Vector2(lerpf(rect.position.x, rect.end.x, fraction), rect.position.y + depth))
			"S":
				points.append(Vector2(lerpf(rect.position.x, rect.end.x, fraction), rect.end.y - depth))
			"W":
				points.append(Vector2(rect.position.x + depth, lerpf(rect.position.y, rect.end.y, fraction)))
			"E":
				points.append(Vector2(rect.end.x - depth, lerpf(rect.position.y, rect.end.y, fraction)))
	return points

func _terrain_edge_band_polygon(direction: String, rect: Rect2, inner_profile: PackedVector2Array) -> PackedVector2Array:
	if inner_profile.size() != 5:
		return PackedVector2Array()
	var polygon := PackedVector2Array()
	match direction:
		"N":
			polygon.append(rect.position)
			polygon.append(Vector2(rect.end.x, rect.position.y))
		"S":
			polygon.append(Vector2(rect.position.x, rect.end.y))
			polygon.append(rect.end)
		"W":
			polygon.append(rect.position)
			polygon.append(Vector2(rect.position.x, rect.end.y))
		"E":
			polygon.append(Vector2(rect.end.x, rect.position.y))
			polygon.append(rect.end)
		_:
			return PackedVector2Array()
	for index in range(inner_profile.size() - 1, -1, -1):
		polygon.append(inner_profile[index])
	return polygon

func _draw_water_shoreline_contour(tile: Vector2i, direction: String, rect: Rect2) -> void:
	var profile := _water_shoreline_contour_profile(tile, direction, rect)
	if profile.is_empty():
		return
	var bank_band: PackedVector2Array = profile.get("bank_band", PackedVector2Array())
	var shallow_band: PackedVector2Array = profile.get("shallow_band", PackedVector2Array())
	var wet_edge: PackedVector2Array = profile.get("wet_edge", PackedVector2Array())
	var foam_segments: Array = profile.get("foam_segments", [])
	if bank_band.size() >= 3:
		_canvas_draw_colored_polygon(bank_band, WATER_SHORELINE_BANK_COLOR)
	if shallow_band.size() >= 3:
		_canvas_draw_colored_polygon(shallow_band, WATER_SHORELINE_SHALLOW_COLOR)
	if wet_edge.size() >= 2:
		_canvas_draw_polyline(
			wet_edge,
			WATER_SHORELINE_WET_EDGE_COLOR,
			maxf(1.0, minf(rect.size.x, rect.size.y) * WATER_SHORELINE_WET_EDGE_WIDTH_FACTOR),
			true
		)
	for segment_value in foam_segments:
		if not (segment_value is PackedVector2Array):
			continue
		var segment: PackedVector2Array = segment_value
		if segment.size() != 3:
			continue
		_canvas_draw_polyline(
			segment,
			WATER_SHORELINE_FOAM_SHADOW_COLOR,
			maxf(1.4, minf(rect.size.x, rect.size.y) * WATER_SHORELINE_FOAM_SHADOW_WIDTH_FACTOR),
			true
		)
		_canvas_draw_polyline(
			segment,
			WATER_SHORELINE_FOAM_COLOR,
			maxf(1.0, minf(rect.size.x, rect.size.y) * WATER_SHORELINE_FOAM_WIDTH_FACTOR),
			true
		)

func _water_shoreline_contour_profile(tile: Vector2i, direction: String, rect: Rect2) -> Dictionary:
	if direction not in ["N", "E", "S", "W"] or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return {}
	var bank_profile := _water_shoreline_profile_points(tile, direction, rect, WATER_SHORELINE_BANK_DEPTH_FACTOR)
	var shallow_profile := _water_shoreline_profile_points(tile, direction, rect, WATER_SHORELINE_SHALLOW_DEPTH_FACTOR)
	var wet_edge := _water_shoreline_profile_points(tile, direction, rect, WATER_SHORELINE_WET_EDGE_DEPTH_FACTOR)
	var foam_profile := _water_shoreline_profile_points(tile, direction, rect, WATER_SHORELINE_FOAM_DEPTH_FACTOR)
	if bank_profile.size() != WATER_SHORELINE_PROFILE_SAMPLE_COUNT or shallow_profile.size() != WATER_SHORELINE_PROFILE_SAMPLE_COUNT or wet_edge.size() != WATER_SHORELINE_PROFILE_SAMPLE_COUNT or foam_profile.size() != WATER_SHORELINE_PROFILE_SAMPLE_COUNT:
		return {}
	return {
		"model": WATER_SHORELINE_CONTOUR_MODEL,
		"direction": direction,
		"receiver_tile": tile,
		"bank_band": _water_shoreline_band_polygon(direction, rect, bank_profile),
		"shallow_band": _water_shoreline_band_polygon(direction, rect, shallow_profile),
		"wet_edge": wet_edge,
		"foam_segments": _water_shoreline_foam_segments(tile, direction, foam_profile),
	}

func _water_shoreline_foam_segments(tile: Vector2i, direction: String, foam_profile: PackedVector2Array) -> Array:
	if foam_profile.size() != WATER_SHORELINE_PROFILE_SAMPLE_COUNT:
		return []
	var direction_seed := int({"N": 3, "E": 7, "S": 11, "W": 17}.get(direction, 0))
	var seed := absi((tile.x * 29) + (tile.y * 47) + direction_seed)
	var first_interval := seed % 2
	var interval_indices: Array = []
	for segment_index in range(WATER_SHORELINE_FOAM_SEGMENTS_PER_EDGE):
		interval_indices.append(first_interval + (segment_index * 2))
	var segments: Array = []
	for interval_value in interval_indices:
		var interval := int(interval_value)
		var start_ratio := 0.14 + (float((seed + interval) % 3) * 0.04)
		var end_ratio := 0.58 + (float((seed + interval + 1) % 3) * 0.04)
		var segment_start := foam_profile[interval].lerp(foam_profile[interval + 1], start_ratio)
		var segment_end := foam_profile[interval].lerp(foam_profile[interval + 1], end_ratio)
		var inward_normal := Vector2.ZERO
		match direction:
			"N":
				inward_normal = Vector2.DOWN
			"E":
				inward_normal = Vector2.LEFT
			"S":
				inward_normal = Vector2.UP
			"W":
				inward_normal = Vector2.RIGHT
		var wave_sign := -1.0 if ((seed + interval) % 2) == 0 else 1.0
		var segment_mid := segment_start.lerp(segment_end, 0.5) + (inward_normal * segment_start.distance_to(segment_end) * 0.055 * wave_sign)
		segments.append(PackedVector2Array([
			segment_start,
			segment_mid,
			segment_end,
		]))
	return segments

func _water_shoreline_contour_payload(tile: Vector2i, transition_payload: Dictionary) -> Dictionary:
	var source_directions: Array = []
	var profiles: Array = []
	var validation_rect := Rect2(Vector2.ZERO, Vector2(100.0, 100.0))
	var cardinal_sources = transition_payload.get("cardinal_sources", [])
	if cardinal_sources is Array:
		for source_value in cardinal_sources:
			if not (source_value is Dictionary):
				continue
			var source: Dictionary = source_value
			var source_terrain := String(source.get("source_terrain", ""))
			if _terrain_group(source_terrain) != "water" or _terrain_group(_terrain_at(tile)) == "water":
				continue
			var direction := String(source.get("direction", ""))
			var profile := _water_shoreline_contour_profile(tile, direction, validation_rect)
			if profile.is_empty():
				continue
			var bank_band: PackedVector2Array = profile.get("bank_band", PackedVector2Array())
			var shallow_band: PackedVector2Array = profile.get("shallow_band", PackedVector2Array())
			var wet_edge: PackedVector2Array = profile.get("wet_edge", PackedVector2Array())
			var foam_segments: Array = profile.get("foam_segments", [])
			var foam_contained := true
			for segment_value in foam_segments:
				if not (segment_value is PackedVector2Array) or not _shoreline_points_contained(segment_value, validation_rect):
					foam_contained = false
					break
			source_directions.append(direction)
			profiles.append({
				"direction": direction,
				"source_terrain": source_terrain,
				"bank_band_point_count": bank_band.size(),
				"shallow_band_point_count": shallow_band.size(),
				"wet_edge_point_count": wet_edge.size(),
				"foam_segment_count": foam_segments.size(),
				"geometry_contained": _shoreline_points_contained(bank_band, validation_rect) and _shoreline_points_contained(shallow_band, validation_rect) and _shoreline_points_contained(wet_edge, validation_rect) and foam_contained,
			})
	return {
		"model": WATER_SHORELINE_CONTOUR_MODEL,
		"active": not profiles.is_empty(),
		"source_count": profiles.size(),
		"source_directions": source_directions,
		"direction_order": ["N", "E", "S", "W"],
		"profiles": profiles,
		"authored_edge_art_model": WATER_TRANSITION_EDGE_ART_MODEL,
		"authored_edge_art_alpha": WATER_TRANSITION_EDGE_ART_ALPHA,
		"authored_edge_clip_depth_factor": WATER_TRANSITION_EDGE_CLIP_DEPTH_FACTOR,
		"profile_sample_count": WATER_SHORELINE_PROFILE_SAMPLE_COUNT,
		"shared_lattice_endpoints": true,
		"bank_band_alpha": WATER_SHORELINE_BANK_COLOR.a,
		"shallow_band_alpha": WATER_SHORELINE_SHALLOW_COLOR.a,
		"wet_edge_alpha": WATER_SHORELINE_WET_EDGE_COLOR.a,
		"foam_alpha": WATER_SHORELINE_FOAM_COLOR.a,
		"foam_segments_per_edge": WATER_SHORELINE_FOAM_SEGMENTS_PER_EDGE,
		"continuous_bright_outline": false,
		"full_tile_fill": false,
		"deterministic_seed_basis": "shared_boundary_lattice_and_cardinal_direction_only",
		"diagonal_water_corner_hints_suppressed": true,
		"draw_order": "after_authored_transition_overlay_before_macro_lighting_and_roads",
	}

func _shoreline_points_contained(points: PackedVector2Array, rect: Rect2) -> bool:
	if points.is_empty():
		return false
	for point in points:
		if point.x < rect.position.x or point.y < rect.position.y or point.x > rect.end.x or point.y > rect.end.y:
			return false
	return true

func _draw_terrain_corner_hint(tile: Vector2i, source_terrain: String, direction: String, rect: Rect2) -> void:
	if direction == "":
		return
	var edge_color := _terrain_color(source_terrain, "edge_color", Color(0.24, 0.26, 0.18, 1.0))
	var color := Color(edge_color.r, edge_color.g, edge_color.b, TERRAIN_TRANSITION_CORNER_ALPHA)
	var detail := _terrain_color(source_terrain, "detail_color", edge_color)
	var detail_color := Color(detail.r, detail.g, detail.b, TERRAIN_TRANSITION_CORNER_ALPHA * 0.58)
	var extent := minf(rect.size.x, rect.size.y)
	var seed: int = absi((tile.x * 43) + (tile.y * 61) + direction.hash())
	var corner_variation := 0.92 + (float(seed % 5) * 0.04)
	var corner := maxf(4.0, extent * TERRAIN_TRANSITION_CORNER_FACTOR * corner_variation)
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

func _draw_terrain_edge_art(tile: Vector2i, terrain: String, direction: String, rect: Rect2) -> bool:
	if not _terrain_art_can_be_primary(terrain):
		return false
	var texture_path := _terrain_edge_art_path(terrain, direction)
	var texture = _terrain_art_texture(texture_path)
	if not (texture is Texture2D):
		return false
	if _terrain_group(terrain) == "water":
		return _draw_water_transition_edge_art(tile, direction, rect, texture)
	_canvas_draw_texture_rect(texture, rect, false)
	return true

func _draw_water_transition_edge_art(tile: Vector2i, direction: String, rect: Rect2, texture: Texture2D) -> bool:
	var inner_profile := _water_shoreline_profile_points(tile, direction, rect, WATER_TRANSITION_EDGE_CLIP_DEPTH_FACTOR)
	if inner_profile.size() != WATER_SHORELINE_PROFILE_SAMPLE_COUNT:
		return false
	var tint := Color(1.0, 1.0, 1.0, WATER_TRANSITION_EDGE_ART_ALPHA)
	for interval in range(WATER_SHORELINE_PROFILE_SAMPLE_COUNT - 1):
		var start_fraction := float(interval) / float(WATER_SHORELINE_PROFILE_SAMPLE_COUNT - 1)
		var end_fraction := float(interval + 1) / float(WATER_SHORELINE_PROFILE_SAMPLE_COUNT - 1)
		var outer_start := Vector2.ZERO
		var outer_end := Vector2.ZERO
		match direction:
			"N":
				outer_start = Vector2(lerpf(rect.position.x, rect.end.x, start_fraction), rect.position.y)
				outer_end = Vector2(lerpf(rect.position.x, rect.end.x, end_fraction), rect.position.y)
			"E":
				outer_start = Vector2(rect.end.x, lerpf(rect.position.y, rect.end.y, start_fraction))
				outer_end = Vector2(rect.end.x, lerpf(rect.position.y, rect.end.y, end_fraction))
			"S":
				outer_start = Vector2(lerpf(rect.position.x, rect.end.x, start_fraction), rect.end.y)
				outer_end = Vector2(lerpf(rect.position.x, rect.end.x, end_fraction), rect.end.y)
			"W":
				outer_start = Vector2(rect.position.x, lerpf(rect.position.y, rect.end.y, start_fraction))
				outer_end = Vector2(rect.position.x, lerpf(rect.position.y, rect.end.y, end_fraction))
			_:
				return false
		var points := PackedVector2Array([outer_start, outer_end, inner_profile[interval + 1], inner_profile[interval]])
		var uvs := PackedVector2Array()
		for point in points:
			uvs.append((point - rect.position) / rect.size)
		_canvas_draw_textured_polygon(points, PackedColorArray([tint, tint, tint, tint]), uvs, texture)
	return true

func _water_shoreline_profile_points(tile: Vector2i, direction: String, rect: Rect2, depth_factor: float) -> PackedVector2Array:
	if direction not in ["N", "E", "S", "W"] or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return PackedVector2Array()
	var extent := minf(rect.size.x, rect.size.y)
	var boundary_lattice := tile.y if direction == "N" else tile.y + 1 if direction == "S" else tile.x if direction == "W" else tile.x + 1
	var direction_seed := float({"N": 0.0, "E": 1.7, "S": 3.4, "W": 5.1}.get(direction, 0.0))
	var points := PackedVector2Array()
	for index in range(WATER_SHORELINE_PROFILE_SAMPLE_COUNT):
		var fraction := float(index) / float(WATER_SHORELINE_PROFILE_SAMPLE_COUNT - 1)
		var axis_lattice := (tile.x * (WATER_SHORELINE_PROFILE_SAMPLE_COUNT - 1)) + index if direction in ["N", "S"] else (tile.y * (WATER_SHORELINE_PROFILE_SAMPLE_COUNT - 1)) + index
		var wave_a := sin((float(axis_lattice) * 0.73) + (float(boundary_lattice) * 1.37) + direction_seed)
		var wave_b := sin((float(axis_lattice) * 1.61) - (float(boundary_lattice) * 0.47) + (direction_seed * 0.5))
		var weight := clampf(0.84 + (wave_a * 0.075) + (wave_b * 0.035), 0.72, 0.96)
		var depth := clampf(extent * depth_factor * weight, 2.0, extent * 0.22)
		match direction:
			"N":
				points.append(Vector2(lerpf(rect.position.x, rect.end.x, fraction), rect.position.y + depth))
			"E":
				points.append(Vector2(rect.end.x - depth, lerpf(rect.position.y, rect.end.y, fraction)))
			"S":
				points.append(Vector2(lerpf(rect.position.x, rect.end.x, fraction), rect.end.y - depth))
			"W":
				points.append(Vector2(rect.position.x + depth, lerpf(rect.position.y, rect.end.y, fraction)))
	return points

func _water_shoreline_band_polygon(direction: String, rect: Rect2, inner_profile: PackedVector2Array) -> PackedVector2Array:
	if inner_profile.size() != WATER_SHORELINE_PROFILE_SAMPLE_COUNT:
		return PackedVector2Array()
	var polygon := PackedVector2Array()
	match direction:
		"N":
			polygon.append(rect.position)
			polygon.append(Vector2(rect.end.x, rect.position.y))
		"E":
			polygon.append(Vector2(rect.end.x, rect.position.y))
			polygon.append(rect.end)
		"S":
			polygon.append(Vector2(rect.position.x, rect.end.y))
			polygon.append(rect.end)
		"W":
			polygon.append(rect.position)
			polygon.append(Vector2(rect.position.x, rect.end.y))
		_:
			return PackedVector2Array()
	for index in range(inner_profile.size() - 1, -1, -1):
		polygon.append(inner_profile[index])
	return polygon

func _draw_road_overlay(tile: Vector2i, rect: Rect2) -> void:
	var road := _road_tile_payload(tile)
	if road.is_empty():
		return
	var render_model := _road_render_model(tile, road)
	if render_model == ROAD_SOURCE_FRAME_RENDER_MODEL and _draw_road_overlay_art(tile, rect, road):
		return
	if render_model == ROAD_WATER_RENDER_MODEL:
		_draw_road_water_causeway(tile, rect)
		return
	_draw_road_land_path(tile, rect)

func _draw_road_land_path(tile: Vector2i, rect: Rect2) -> void:
	var extent := minf(rect.size.x, rect.size.y)
	var center := rect.get_center()
	var width := maxf(5.0, extent * ROAD_LAND_WIDTH_FACTOR)
	var neighbor_directions := _road_neighbor_directions(tile)
	for direction in neighbor_directions:
		var start := _road_connector_start(rect, direction)
		var end := _road_connector_end(rect, direction)
		var path_points := _road_land_path_points(tile, direction, start, end, width)
		_canvas_draw_polyline(path_points, ROAD_LAND_SHADOW_COLOR, width * 1.34, true)
		_canvas_draw_polyline(path_points, ROAD_LAND_SHOULDER_COLOR, width * 1.12, true)
		_canvas_draw_polyline(path_points, ROAD_LAND_EARTH_COLOR, width, true)
		_draw_road_land_ruts(path_points, width)
	if neighbor_directions.is_empty():
		_canvas_draw_circle(center, width * 0.68, ROAD_LAND_SHADOW_COLOR)
		_canvas_draw_circle(center, width * 0.57, ROAD_LAND_SHOULDER_COLOR)
		_canvas_draw_circle(center, width * 0.48, ROAD_LAND_EARTH_COLOR)
		_canvas_draw_line(center - Vector2(width * 0.26, 0.0), center + Vector2(width * 0.26, 0.0), ROAD_LAND_RUT_COLOR, maxf(1.0, width * 0.09), true)
	elif _road_needs_joint_cap(neighbor_directions):
		_canvas_draw_circle(center, width * 0.52, ROAD_LAND_SHOULDER_COLOR)
		_canvas_draw_circle(center, width * 0.43, ROAD_LAND_EARTH_COLOR)
		_canvas_draw_circle(center, width * 0.19, ROAD_LAND_DUST_COLOR)

func _road_land_path_points(tile: Vector2i, direction: Vector2i, start: Vector2, end: Vector2, width: float) -> PackedVector2Array:
	var delta := end - start
	if delta.length_squared() <= 0.001:
		return PackedVector2Array([start, end])
	var normal := Vector2(-delta.y, delta.x).normalized()
	var bend_seed: int = absi((tile.x * 37) + (tile.y * 71) + (direction.x * 11) + (direction.y * 19))
	var bend_sign := -1.0 if bend_seed % 2 == 0 else 1.0
	var bend_strength := (0.045 + (float(bend_seed % 4) * 0.012)) * width
	return PackedVector2Array([start, start.lerp(end, 0.52) + (normal * bend_strength * bend_sign), end])

func _draw_road_land_ruts(path_points: PackedVector2Array, width: float) -> void:
	if path_points.size() < 2:
		return
	var delta := path_points[path_points.size() - 1] - path_points[0]
	if delta.length_squared() <= 0.001:
		return
	var normal := Vector2(-delta.y, delta.x).normalized()
	var offset := normal * width * 0.23
	var rut_width := maxf(1.0, width * 0.085)
	var left_rut := PackedVector2Array()
	var right_rut := PackedVector2Array()
	for point in path_points:
		left_rut.append(point + offset)
		right_rut.append(point - offset)
	_canvas_draw_polyline(left_rut, ROAD_LAND_RUT_COLOR, rut_width, true)
	_canvas_draw_polyline(right_rut, ROAD_LAND_RUT_COLOR, rut_width, true)

func _draw_road_water_causeway(tile: Vector2i, rect: Rect2) -> void:
	var extent := minf(rect.size.x, rect.size.y)
	var center := rect.get_center()
	var width := maxf(6.0, extent * ROAD_CAUSEWAY_WIDTH_FACTOR)
	var neighbor_directions := _road_neighbor_directions(tile)
	for direction in neighbor_directions:
		var start := _road_connector_start(rect, direction)
		var end := _road_connector_end(rect, direction)
		_canvas_draw_line(start, end, ROAD_CAUSEWAY_SHADOW_COLOR, width * 1.34, true)
		_canvas_draw_line(start, end, ROAD_CAUSEWAY_EDGE_COLOR, width * 1.12, true)
		_canvas_draw_line(start, end, ROAD_CAUSEWAY_DECK_COLOR, width, true)
		_draw_road_causeway_planks(start, end, width)
	if neighbor_directions.is_empty():
		var isolated_size := Vector2(width * 1.16, width * 0.92)
		_canvas_draw_rect(Rect2(center - isolated_size * 0.5, isolated_size), ROAD_CAUSEWAY_EDGE_COLOR)
		_canvas_draw_rect(Rect2(center - isolated_size * 0.42, isolated_size * 0.84), ROAD_CAUSEWAY_DECK_COLOR)
	elif _road_needs_joint_cap(neighbor_directions):
		var joint_size := Vector2(width * 0.96, width * 0.96)
		_canvas_draw_rect(Rect2(center - joint_size * 0.5, joint_size), ROAD_CAUSEWAY_EDGE_COLOR)
		_canvas_draw_rect(Rect2(center - joint_size * 0.42, joint_size * 0.84), ROAD_CAUSEWAY_DECK_COLOR)
		_canvas_draw_line(center - Vector2(width * 0.34, 0.0), center + Vector2(width * 0.34, 0.0), ROAD_CAUSEWAY_GRAIN_COLOR, maxf(1.0, width * 0.07), true)

func _draw_road_causeway_planks(start: Vector2, end: Vector2, width: float) -> void:
	var delta := end - start
	var length := delta.length()
	if length <= 0.001:
		return
	var direction := delta / length
	var normal := Vector2(-direction.y, direction.x)
	var half_plank := normal * width * 0.43
	for fraction in [0.16, 0.38, 0.60, 0.82]:
		var plank_center := start.lerp(end, float(fraction))
		_canvas_draw_line(plank_center - half_plank, plank_center + half_plank, ROAD_CAUSEWAY_SEAM_COLOR, maxf(1.0, width * 0.075), true)
	var grain_offset := normal * width * 0.18
	_canvas_draw_line(start + grain_offset, end + grain_offset, ROAD_CAUSEWAY_GRAIN_COLOR, maxf(1.0, width * 0.055), true)

func _draw_road_overlay_art(tile: Vector2i, rect: Rect2, road: Dictionary) -> bool:
	var source_path := _h3maped_road_art_path_from_payload(road)
	if source_path != "":
		var source_texture = _terrain_art_texture(source_path)
		if source_texture is Texture2D:
			_canvas_draw_texture_rect_flipped(
				source_texture,
				rect,
				int(road.get("h3maped_road_flip_a", 0)) != 0,
				int(road.get("h3maped_road_flip_b", 0)) != 0
			)
			return true
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

func _road_render_model(tile: Vector2i, road: Dictionary) -> String:
	if _road_explicit_source_frame_loaded(tile, road):
		return ROAD_SOURCE_FRAME_RENDER_MODEL
	if _terrain_at(tile).strip_edges().to_lower() == "water":
		return ROAD_WATER_RENDER_MODEL
	return ROAD_LAND_RENDER_MODEL

func _road_explicit_source_frame_loaded(tile: Vector2i, road: Dictionary) -> bool:
	return _road_explicit_source_frame_path(tile, road) != ""

func _road_explicit_source_frame_path(tile: Vector2i, road: Dictionary) -> String:
	var source_path := _h3maped_road_art_path_from_payload(road)
	if source_path != "" and _terrain_art_texture(source_path) is Texture2D:
		return source_path
	var homm3_path := _homm3_road_art_path(String(road.get("overlay_id", "road_dirt")), tile)
	if homm3_path != "" and _terrain_art_texture(homm3_path) is Texture2D:
		return homm3_path
	return ""

func _draw_route(board_rect: Rect2) -> void:
	if _path_tiles.size() <= 1:
		return
	var reachable_tiles := _tiles_from_payloads(_route_preview.get("reachable_tiles", []))
	var unreachable_tiles := _tiles_from_payloads(_route_preview.get("unreachable_tiles", []))
	if reachable_tiles.size() > 1:
		_draw_route_segment(board_rect, reachable_tiles, ROUTE_COLOR, false)
	if unreachable_tiles.size() > 0:
		var blocked_segment := []
		if reachable_tiles.size() > 0:
			blocked_segment.append(reachable_tiles[reachable_tiles.size() - 1])
		blocked_segment.append_array(unreachable_tiles)
		if blocked_segment.size() > 1:
			_draw_route_segment(board_rect, blocked_segment, ROUTE_BLOCKED_COLOR, true)

func _draw_route_segment(board_rect: Rect2, tiles: Array, line_color: Color, blocked: bool) -> void:
	var profile := _route_segment_visual_profile(board_rect, tiles, line_color, blocked)
	var points: PackedVector2Array = profile.get("points", PackedVector2Array())
	if points.size() <= 1:
		return
	var shadow_width := float(profile.get("shadow_width_px", 2.8))
	var core_width := float(profile.get("core_width_px", 1.3))
	var highlight_width := float(profile.get("highlight_width_px", 0.65))
	var highlight_color := Color(1.0, 0.96, 0.74, ROUTE_HIGHLIGHT_ALPHA) if not blocked else Color(1.0, 0.72, 0.62, ROUTE_HIGHLIGHT_ALPHA)
	_canvas_draw_polyline(points, ROUTE_SHADOW_COLOR, shadow_width, true)
	_canvas_draw_polyline(points, line_color, core_width, true)
	_canvas_draw_polyline(points, highlight_color, highlight_width, true)
	for stitch_value in profile.get("stitches", []):
		if not (stitch_value is PackedVector2Array):
			continue
		var stitch: PackedVector2Array = stitch_value
		_canvas_draw_polyline(stitch, ROUTE_SHADOW_COLOR, float(profile.get("stitch_shadow_width_px", 1.8)), true)
		_canvas_draw_polyline(stitch, Color(line_color.r, line_color.g, line_color.b, ROUTE_STITCH_ALPHA), float(profile.get("stitch_width_px", 1.0)), true)
	for waypoint_value in profile.get("waypoints", []):
		if not (waypoint_value is PackedVector2Array):
			continue
		var waypoint: PackedVector2Array = waypoint_value
		_canvas_draw_polyline(waypoint, ROUTE_SHADOW_COLOR, shadow_width, true)
		_canvas_draw_polyline(waypoint, line_color, core_width, true)
	var destination: PackedVector2Array = profile.get("destination_chevron", PackedVector2Array())
	if destination.size() == 3:
		_canvas_draw_polyline(destination, ROUTE_SHADOW_COLOR, shadow_width, true)
		_canvas_draw_polyline(destination, line_color, core_width, true)
		_canvas_draw_polyline(destination, highlight_color, highlight_width, true)

func _route_segment_visual_profile(board_rect: Rect2, tiles: Array, line_color: Color, blocked: bool) -> Dictionary:
	var points := PackedVector2Array()
	var source_tiles: Array = []
	for tile_value in tiles:
		if not (tile_value is Vector2i):
			continue
		var tile: Vector2i = tile_value
		source_tiles.append(_vector2i_payload(tile))
		points.append(_tile_rect(board_rect, tile).get_center())
	var tile_extent := minf(
		board_rect.size.x / float(maxi(_map_size.x, 1)),
		board_rect.size.y / float(maxi(_map_size.y, 1))
	)
	var shadow_width := maxf(2.8, tile_extent * ROUTE_SHADOW_WIDTH_FACTOR)
	var core_width := maxf(1.3, tile_extent * ROUTE_CORE_WIDTH_FACTOR)
	var highlight_width := maxf(0.65, tile_extent * ROUTE_HIGHLIGHT_WIDTH_FACTOR)
	var stitch_length := maxf(3.0, tile_extent * ROUTE_STITCH_LENGTH_FACTOR)
	var stitch_width := maxf(0.85, tile_extent * ROUTE_STITCH_WIDTH_FACTOR)
	var waypoint_radius := maxf(2.25, tile_extent * ROUTE_WAYPOINT_RADIUS_FACTOR)
	var destination_length := maxf(5.0, tile_extent * ROUTE_DESTINATION_LENGTH_FACTOR)
	var destination_depth := maxf(3.0, tile_extent * ROUTE_DESTINATION_DEPTH_FACTOR)
	var stitches: Array = []
	for index in range(1, points.size()):
		var start := points[index - 1]
		var finish := points[index]
		var direction := start.direction_to(finish)
		if direction == Vector2.ZERO:
			continue
		var normal := Vector2(-direction.y, direction.x)
		var midpoint := start.lerp(finish, 0.5)
		stitches.append(PackedVector2Array([
			midpoint - normal * stitch_length * 0.5,
			midpoint + normal * stitch_length * 0.5,
		]))
	var waypoints: Array = []
	for index in range(1, maxi(points.size() - 1, 1)):
		var center := points[index]
		waypoints.append(PackedVector2Array([
			center + Vector2(0.0, -waypoint_radius),
			center + Vector2(waypoint_radius, 0.0),
			center + Vector2(0.0, waypoint_radius),
			center + Vector2(-waypoint_radius, 0.0),
			center + Vector2(0.0, -waypoint_radius),
		]))
	var destination_chevron := PackedVector2Array()
	var destination_direction := Vector2.ZERO
	if points.size() > 1:
		var tip := points[points.size() - 1]
		var direction := points[points.size() - 2].direction_to(tip)
		if direction != Vector2.ZERO:
			destination_direction = direction
			var normal := Vector2(-direction.y, direction.x)
			var wing_center := tip - direction * destination_length
			destination_chevron = PackedVector2Array([
				wing_center + normal * destination_depth,
				tip,
				wing_center - normal * destination_depth,
			])
	return {
		"model": ROUTE_VISUAL_MODEL,
		"blocked": blocked,
		"source_tiles": source_tiles,
		"points": points,
		"point_count": points.size(),
		"shadow_width_px": shadow_width,
		"core_width_px": core_width,
		"highlight_width_px": highlight_width,
		"shadow_alpha": ROUTE_SHADOW_COLOR.a,
		"core_alpha": line_color.a,
		"highlight_alpha": ROUTE_HIGHLIGHT_ALPHA,
		"stitches": stitches,
		"stitch_count": stitches.size(),
		"stitch_length_px": stitch_length,
		"stitch_width_px": stitch_width,
		"stitch_shadow_width_px": stitch_width + 1.0,
		"stitch_alpha": ROUTE_STITCH_ALPHA,
		"waypoints": waypoints,
		"waypoint_count": waypoints.size(),
		"waypoint_radius_px": waypoint_radius,
		"waypoint_fill_alpha": 0.0,
		"destination_chevron": destination_chevron,
		"destination_chevron_count": 1 if destination_chevron.size() == 3 else 0,
		"destination_tip": _vector2_payload(points[points.size() - 1]) if points.size() > 1 else {},
		"destination_direction": _vector2_payload(destination_direction),
		"destination_source_tile": source_tiles[source_tiles.size() - 1].duplicate(true) if not source_tiles.is_empty() else {},
		"destination_length_px": destination_length,
		"destination_depth_px": destination_depth,
		"continuous_debug_bar": false,
		"filled_node_count": 0,
	}

func _draw_tile_focus(tile: Vector2i, rect: Rect2) -> void:
	var layout := _tile_focus_layout(tile, rect)
	if tile == _hero_tile:
		_draw_hero_command_focus_marker(layout.get("hero_command_marker_profile", {}))

	if tile == _selected_tile:
		var selection_rect: Rect2 = layout.get("selection_rect", rect)
		if bool(layout.get("selection_uses_cartographic_town_perimeter", false)):
			_draw_town_selection_perimeter(selection_rect)
		elif bool(layout.get("selection_uses_cartographic_tile_reticle", false)):
			_draw_tile_selection_reticle(selection_rect)

	if tile == _hover_tile:
		_draw_cartographic_hover_reticle(layout.get("hover_visual_profile", {}))

func _hover_reticle_visual_profile(rect: Rect2) -> Dictionary:
	var extent := minf(rect.size.x, rect.size.y)
	var perimeter_inset := clampf(
		extent * HOVER_RETICLE_PERIMETER_INSET_FACTOR,
		HOVER_RETICLE_PERIMETER_INSET_MIN_PX,
		HOVER_RETICLE_PERIMETER_INSET_MAX_PX
	)
	var corner_length := clampf(
		extent * HOVER_RETICLE_CORNER_LENGTH_FACTOR,
		HOVER_RETICLE_CORNER_LENGTH_MIN_PX,
		HOVER_RETICLE_CORNER_LENGTH_MAX_PX
	)
	var corner_width := clampf(
		extent * HOVER_RETICLE_CORNER_WIDTH_FACTOR,
		HOVER_RETICLE_CORNER_WIDTH_MIN_PX,
		HOVER_RETICLE_CORNER_WIDTH_MAX_PX
	)
	return {
		"model": HOVER_RETICLE_VISUAL_MODEL,
		"perimeter_rect": rect.grow(-perimeter_inset),
		"perimeter_inset_px": perimeter_inset,
		"corner_length_px": corner_length,
		"corner_width_px": corner_width,
		"corner_color": HOVER_COLOR,
		"shadow_alpha": HOVER_RETICLE_SHADOW_ALPHA,
		"shadow_width_px": corner_width + HOVER_RETICLE_SHADOW_WIDTH_ADD_PX,
		"continuous_outline": false,
		"interior_fill_alpha": 0.0,
	}

func _draw_cartographic_hover_reticle(profile: Dictionary) -> void:
	var perimeter_rect: Rect2 = profile.get("perimeter_rect", Rect2())
	if perimeter_rect.size.x <= 0.0 or perimeter_rect.size.y <= 0.0:
		return
	var corner_length := float(profile.get("corner_length_px", HOVER_RETICLE_CORNER_LENGTH_MIN_PX))
	var corner_width := float(profile.get("corner_width_px", HOVER_RETICLE_CORNER_WIDTH_MIN_PX))
	var shadow_width := float(profile.get("shadow_width_px", corner_width + HOVER_RETICLE_SHADOW_WIDTH_ADD_PX))
	var shadow_color := Color(0.02, 0.025, 0.03, float(profile.get("shadow_alpha", HOVER_RETICLE_SHADOW_ALPHA)))
	var corner_color: Color = profile.get("corner_color", HOVER_COLOR)
	_draw_cartographic_selection_corners(perimeter_rect, shadow_color, shadow_width, corner_length)
	_draw_cartographic_selection_corners(perimeter_rect, corner_color, corner_width, corner_length)

func _hero_command_focus_profile(rect: Rect2) -> Dictionary:
	var extent := minf(rect.size.x, rect.size.y)
	var inset := maxf(HERO_COMMAND_FOCUS_INSET_MIN_PX, extent * HERO_COMMAND_FOCUS_INSET_FACTOR)
	var marker_rect := rect.grow(-inset)
	var line_width := maxf(1.25, extent * FOCUS_RING_WIDTH_FACTOR * 0.58)
	return {
		"model": HERO_COMMAND_FOCUS_VISUAL_MODEL,
		"focus_rect": rect,
		"marker_rect": marker_rect,
		"center_y": rect.position.y + rect.size.y * HERO_COMMAND_FOCUS_CENTER_Y_FACTOR,
		"wing_length_px": maxf(HERO_COMMAND_FOCUS_WING_LENGTH_MIN_PX, extent * HERO_COMMAND_FOCUS_WING_LENGTH_FACTOR),
		"wing_depth_px": maxf(HERO_COMMAND_FOCUS_WING_DEPTH_MIN_PX, extent * HERO_COMMAND_FOCUS_WING_DEPTH_FACTOR),
		"ground_y": rect.position.y + rect.size.y * HERO_COMMAND_FOCUS_GROUND_Y_FACTOR,
		"ground_tick_length_px": maxf(6.0, extent * HERO_COMMAND_FOCUS_GROUND_TICK_LENGTH_FACTOR),
		"ground_notch_px": maxf(1.5, extent * HERO_COMMAND_FOCUS_GROUND_NOTCH_FACTOR),
		"line_width_px": line_width,
		"shadow_width_px": line_width + 1.5,
		"marker_alpha": HERO_COMMAND_FOCUS_ALPHA,
		"shadow_alpha": HERO_COMMAND_FOCUS_SHADOW_ALPHA,
		"antialiased": true,
		"continuous_outline": false,
		"interior_fill_alpha": 0.0,
	}

func _draw_hero_command_focus_marker(profile: Dictionary) -> void:
	var marker_rect: Rect2 = profile.get("marker_rect", Rect2())
	if marker_rect.size.x <= 0.0 or marker_rect.size.y <= 0.0:
		return
	var center_y := float(profile.get("center_y", marker_rect.get_center().y))
	var wing_length := float(profile.get("wing_length_px", HERO_COMMAND_FOCUS_WING_LENGTH_MIN_PX))
	var wing_depth := float(profile.get("wing_depth_px", HERO_COMMAND_FOCUS_WING_DEPTH_MIN_PX))
	var ground_y := float(profile.get("ground_y", marker_rect.end.y))
	var tick_length := float(profile.get("ground_tick_length_px", 6.0))
	var notch := float(profile.get("ground_notch_px", 1.5))
	var line_width := float(profile.get("line_width_px", 1.25))
	var shadow_width := float(profile.get("shadow_width_px", line_width + 1.5))
	var left_wing := PackedVector2Array([
		Vector2(marker_rect.position.x, center_y - wing_depth),
		Vector2(marker_rect.position.x + wing_length, center_y),
		Vector2(marker_rect.position.x, center_y + wing_depth),
	])
	var right_wing := PackedVector2Array([
		Vector2(marker_rect.end.x, center_y - wing_depth),
		Vector2(marker_rect.end.x - wing_length, center_y),
		Vector2(marker_rect.end.x, center_y + wing_depth),
	])
	var ground_center := Vector2(marker_rect.get_center().x, ground_y)
	var ground_tick := PackedVector2Array([
		ground_center + Vector2(-tick_length * 0.5, 0.0),
		ground_center + Vector2(-notch, 0.0),
		ground_center + Vector2(0.0, -notch),
		ground_center + Vector2(notch, 0.0),
		ground_center + Vector2(tick_length * 0.5, 0.0),
	])
	var shadow_color := Color(0.03, 0.025, 0.015, float(profile.get("shadow_alpha", HERO_COMMAND_FOCUS_SHADOW_ALPHA)))
	var marker_color := Color(HERO_RING_COLOR.r, HERO_RING_COLOR.g, HERO_RING_COLOR.b, float(profile.get("marker_alpha", HERO_COMMAND_FOCUS_ALPHA)))
	for points in [left_wing, right_wing, ground_tick]:
		_canvas_draw_polyline(points, shadow_color, shadow_width, true)
		_canvas_draw_polyline(points, marker_color, line_width, true)

func _tile_focus_layout(tile: Vector2i, tile_rect: Rect2) -> Dictionary:
	var town_presentation := _town_presentation_at(tile)
	var town: Dictionary = town_presentation.get("town", {}) if town_presentation.get("town", {}) is Dictionary else {}
	var uses_town_footprint := not town.is_empty()
	var town_rect := tile_rect
	if uses_town_footprint:
		town_rect = _town_footprint_rect_for_entry(_town_entry_tile(town))
	var hero_focus_rect := _hero_draw_rect(tile_rect, tile, true) if uses_town_footprint else tile_rect
	return {
		"tile_rect": tile_rect,
		"hero_focus_rect": hero_focus_rect,
		"hero_command_marker_profile": _hero_command_focus_profile(hero_focus_rect),
		"hero_uses_compact_town_footprint_rect": uses_town_footprint,
		"selection_rect": town_rect,
		"selection_uses_town_footprint_rect": uses_town_footprint,
		"selection_uses_interior_fill": false,
		"selection_uses_cartographic_town_perimeter": uses_town_footprint,
		"selection_uses_cartographic_tile_reticle": not uses_town_footprint,
		"selection_visual_model": TOWN_SELECTION_VISUAL_MODEL if uses_town_footprint else TILE_SELECTION_VISUAL_MODEL,
		"hover_rect": town_rect,
		"hover_uses_town_footprint_rect": uses_town_footprint,
		"hover_visual_model": HOVER_RETICLE_VISUAL_MODEL,
		"hover_visual_profile": _hover_reticle_visual_profile(town_rect),
		"town_entry_tile": _vector2i_payload(_town_entry_tile(town)) if uses_town_footprint else {},
	}

func _draw_tile_icon(tile: Vector2i, rect: Rect2) -> void:
	_draw_tile_state_icon(tile, rect)
	_draw_tile_dynamic_icon(tile, rect)

func _draw_tile_state_icon(tile: Vector2i, rect: Rect2) -> void:
	if not OverworldRulesScript.is_tile_explored(_session, tile.x, tile.y):
		return
	var visible := OverworldRulesScript.is_tile_visible(_session, tile.x, tile.y)
	var remembered := not visible

	var decorative_object := _decorative_object_at(tile)
	if not decorative_object.is_empty():
		var decorative_rect := _decorative_object_footprint_rect(decorative_object, rect)
		if not _draw_decorative_object_sprite(decorative_object, decorative_rect, remembered, tile):
			_draw_decorative_object_marker(decorative_object, decorative_rect, remembered, tile)
	var standalone_map_object := _standalone_map_object_at(tile)
	if not standalone_map_object.is_empty():
		var object_rect := _decorative_object_footprint_rect(standalone_map_object, rect)
		if not _draw_standalone_map_object_sprite(standalone_map_object, object_rect, remembered, tile):
			_draw_standalone_map_object_marker(standalone_map_object, object_rect, remembered, tile)
	if _has_town_at(tile):
		var visual_rect := _town_visual_rect_for_entry(tile)
		if not _draw_town_sprite(visual_rect, rect, remembered, tile):
			_draw_town_marker(visual_rect, rect, _town_color(tile), remembered, tile)
	var resource_node := _resource_node_at(tile)
	if not resource_node.is_empty():
		var resource_rect := _resource_draw_rect(resource_node, rect, tile)
		if not _draw_resource_sprite(resource_node, resource_rect, remembered, tile):
			_draw_resource_marker(resource_node, resource_rect, remembered, tile)
	var artifact_node := _artifact_node_at(tile)
	if not artifact_node.is_empty():
		if not _draw_artifact_sprite(artifact_node, rect, remembered, tile):
			_draw_artifact_marker(rect, remembered, tile)
	var encounter_node := _encounter_node_at(tile)
	if not encounter_node.is_empty() and (visible or _has_rememberable_encounter_at(tile)):
		if not _draw_encounter_sprite(encounter_node, rect, remembered, tile):
			_draw_encounter_marker(rect, remembered, tile)

func _draw_tile_dynamic_icon(tile: Vector2i, rect: Rect2) -> void:
	if not OverworldRulesScript.is_tile_explored(_session, tile.x, tile.y):
		return
	var visible := OverworldRulesScript.is_tile_visible(_session, tile.x, tile.y)
	if visible and _has_hero_at(tile) and not (_hero_movement_active and tile == _hero_tile):
		_draw_hero_marker(rect, tile)

func _draw_hero_movement_presentation(board_rect: Rect2) -> void:
	var draw_state := _hero_movement_draw_state(board_rect)
	if draw_state.is_empty():
		return
	var draw_rect: Rect2 = draw_state.get("rect", Rect2())
	var grounding_tile: Vector2i = draw_state.get("grounding_tile", Vector2i(-1, -1))
	if not _draw_hero_route_step_imported_vfx(draw_state):
		_hero_movement_last_draw = {"mode": "existing_interpolated_hero_marker_only", "texture_path": ""}
	_draw_hero_marker(draw_rect, grounding_tile, false, _hero_presentation_entry(_hero_tile))

func _draw_hero_route_step_imported_vfx(draw_state: Dictionary) -> bool:
	var asset_state := _hero_movement_vfx_asset_state()
	if not bool(asset_state.get("uses_imported_asset", false)):
		return false
	var texture: Texture2D = _overworld_vfx_texture_for_path(String(asset_state.get("texture_path", ""))) as Texture2D
	if texture == null:
		return false
	var draw_rect: Rect2 = draw_state.get("rect", Rect2())
	var center: Vector2 = draw_state.get("center", draw_rect.get_center())
	var extent := minf(draw_rect.size.x, draw_rect.size.y) * float(asset_state.get("scale", 1.0))
	var texture_rect := Rect2(Vector2(extent, extent) * -0.5, Vector2(extent, extent))
	var from_tile: Vector2i = draw_state.get("from_tile", Vector2i.ZERO)
	var to_tile: Vector2i = draw_state.get("to_tile", from_tile)
	var direction := Vector2(to_tile - from_tile)
	var rotation := direction.angle() + PI * 0.25 if direction.length_squared() > 0.0 else 0.0
	var alpha := clampf(0.90 - float(draw_state.get("segment_progress", 0.0)) * 0.18, 0.72, 0.90)
	var canvas := _current_draw_canvas_item()
	canvas.draw_set_transform(center, rotation, Vector2.ONE)
	canvas.draw_texture_rect(texture, texture_rect, false, Color(1.0, 1.0, 1.0, alpha))
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_hero_movement_last_draw = {
		"mode": "imported_texture_behind_hero",
		"texture_path": String(asset_state.get("texture_path", "")),
		"center": {"x": center.x, "y": center.y},
		"extent": extent,
		"rotation": rotation,
		"alpha": alpha,
	}
	return true

func _hero_movement_draw_state(board_rect: Rect2) -> Dictionary:
	if not _hero_movement_active or _hero_movement_path.size() <= 1 or _hero_movement_duration_sec <= 0.0:
		return {}
	var progress := clampf(_hero_movement_elapsed_sec / _hero_movement_duration_sec, 0.0, 1.0)
	var scaled_progress := progress * float(_hero_movement_path.size() - 1)
	var segment_index := mini(int(floor(scaled_progress)), _hero_movement_path.size() - 2)
	var segment_progress := clampf(scaled_progress - float(segment_index), 0.0, 1.0)
	var from_tile: Vector2i = _hero_movement_path[segment_index]
	var to_tile: Vector2i = _hero_movement_path[segment_index + 1]
	var from_rect := _tile_rect(board_rect, from_tile)
	var to_rect := _tile_rect(board_rect, to_tile)
	var center := from_rect.get_center().lerp(to_rect.get_center(), segment_progress)
	return {
		"rect": Rect2(center - from_rect.size * 0.5, from_rect.size),
		"center": center,
		"segment_index": segment_index,
		"segment_progress": segment_progress,
		"from_tile": from_tile,
		"to_tile": to_tile,
		"grounding_tile": from_tile if segment_progress < 0.5 else to_tile,
	}

func _draw_object_resolution_presentation(board_rect: Rect2) -> void:
	if not _object_resolution_active or _object_resolution_duration_sec <= 0.0:
		return
	var rect := _tile_rect(board_rect, _object_resolution_tile)
	var progress := clampf(_object_resolution_elapsed_sec / _object_resolution_duration_sec, 0.0, 1.0)
	if not (_object_resolution_event_id in ["overworld_route_open", "overworld_route_closed"] and _object_resolution_visual_policy == "reduced_motion_fallback") and _draw_object_resolution_imported_vfx(rect, progress):
		return
	_draw_object_resolution_procedural_vfx(rect, progress)

func _draw_object_resolution_imported_vfx(rect: Rect2, progress: float) -> bool:
	var asset_state := _object_resolution_vfx_asset_state()
	if not bool(asset_state.get("uses_imported_asset", false)):
		return false
	var texture: Texture2D = _overworld_vfx_texture_for_path(String(asset_state.get("texture_path", ""))) as Texture2D
	if texture == null:
		return false
	var center := rect.get_center()
	var extent := minf(rect.size.x, rect.size.y)
	var motion_progress := progress if _object_resolution_allows_large_motion else 0.35
	var alpha := clampf(1.0 - progress * 0.72, 0.24, 1.0)
	var draw_extent := extent * float(asset_state.get("scale", 1.0)) * lerpf(0.82, 1.0, motion_progress)
	var draw_rect := Rect2(center - Vector2(draw_extent, draw_extent) * 0.5, Vector2(draw_extent, draw_extent))
	_canvas_draw_texture_rect(texture, draw_rect, false, Color(1.0, 1.0, 1.0, alpha))
	_object_resolution_last_draw = {
		"mode": "imported_texture",
		"texture_path": String(asset_state.get("texture_path", "")),
		"rect": {"x": draw_rect.position.x, "y": draw_rect.position.y, "width": draw_rect.size.x, "height": draw_rect.size.y},
		"alpha": alpha,
	}
	return true

func _draw_object_resolution_procedural_vfx(rect: Rect2, progress: float) -> void:
	var center := rect.get_center()
	var extent := minf(rect.size.x, rect.size.y)
	var motion_progress := progress if _object_resolution_allows_large_motion else 0.35
	var alpha := clampf(1.0 - progress * 0.72, 0.24, 1.0)
	_object_resolution_last_draw = {
		"mode": "existing_procedural_object_resolution_body",
		"texture_path": "",
		"rect": {"x": rect.position.x, "y": rect.position.y, "width": rect.size.x, "height": rect.size.y},
		"alpha": alpha,
	}
	if _object_resolution_event_id == "overworld_route_open":
		_object_resolution_last_draw = {
			"mode": "route_open_icon" if _object_resolution_visual_policy == "reduced_motion_fallback" else "procedural_route_open_marker",
			"texture_path": "",
			"gate_post_count": 2,
			"path_line_count": 2,
			"alpha": alpha,
		}
		var open_color := Color(0.42, 1.0, 0.80, alpha)
		var path_color := Color(1.0, 0.86, 0.34, alpha)
		var gate_half_width := extent * 0.24
		var gate_top := center.y - extent * 0.26
		var gate_bottom := center.y + extent * 0.22
		_canvas_draw_line(Vector2(center.x - gate_half_width, gate_top), Vector2(center.x - gate_half_width, gate_bottom), open_color, maxf(2.2, extent * 0.042), true)
		_canvas_draw_line(Vector2(center.x + gate_half_width, gate_top), Vector2(center.x + gate_half_width, gate_bottom), open_color, maxf(2.2, extent * 0.042), true)
		_canvas_draw_line(Vector2(center.x - extent * 0.12, center.y + extent * 0.28), Vector2(center.x, center.y - extent * 0.20), path_color, maxf(2.0, extent * 0.036), true)
		_canvas_draw_line(Vector2(center.x + extent * 0.12, center.y + extent * 0.28), Vector2(center.x, center.y - extent * 0.20), path_color, maxf(2.0, extent * 0.036), true)
	elif _object_resolution_event_id == "overworld_route_closed":
		_object_resolution_last_draw = {
			"mode": "route_closed_icon" if _object_resolution_visual_policy == "reduced_motion_fallback" else "procedural_route_closed_marker",
			"texture_path": "",
			"gate_post_count": 2,
			"bar_count": 1,
			"broken_path_count": 2,
			"alpha": alpha,
		}
		var closed_color := Color(0.92, 0.30, 0.22, alpha)
		var iron_color := Color(0.34, 0.42, 0.46, alpha)
		var gate_half_width := extent * 0.22
		var gate_top := center.y - extent * 0.26
		var gate_bottom := center.y + extent * 0.22
		_canvas_draw_line(Vector2(center.x - gate_half_width, gate_top), Vector2(center.x - gate_half_width, gate_bottom), iron_color, maxf(2.2, extent * 0.042), true)
		_canvas_draw_line(Vector2(center.x + gate_half_width, gate_top), Vector2(center.x + gate_half_width, gate_bottom), iron_color, maxf(2.2, extent * 0.042), true)
		_canvas_draw_line(Vector2(center.x - gate_half_width, center.y), Vector2(center.x + gate_half_width, center.y), closed_color, maxf(2.4, extent * 0.050), true)
		_canvas_draw_line(Vector2(center.x - extent * 0.13, center.y + extent * 0.30), Vector2(center.x - extent * 0.035, center.y + extent * 0.08), Color(1.0, 0.70, 0.28, alpha), maxf(2.0, extent * 0.035), true)
		_canvas_draw_line(Vector2(center.x + extent * 0.035, center.y - extent * 0.08), Vector2(center.x + extent * 0.13, center.y - extent * 0.30), Color(1.0, 0.70, 0.28, alpha), maxf(2.0, extent * 0.035), true)
	elif _object_resolution_event_id in ["overworld_object_captured", "town_captured"]:
		var radius := extent * lerpf(0.26, 0.48, motion_progress)
		var capture_color := Color(1.0, 0.78, 0.22, alpha)
		_canvas_draw_circle(center, radius, capture_color, false, maxf(2.0, extent * 0.035), true)
		_canvas_draw_circle(center, radius * 0.72, Color(1.0, 0.94, 0.62, alpha * 0.72), false, maxf(1.0, extent * 0.018), true)
		var pole_top := center + Vector2(-extent * 0.12, -extent * 0.34)
		var pole_bottom := center + Vector2(-extent * 0.12, extent * 0.28)
		_canvas_draw_line(pole_top, pole_bottom, Color(0.28, 0.18, 0.08, alpha), maxf(2.0, extent * 0.026), true)
		_canvas_draw_colored_polygon(PackedVector2Array([
			pole_top,
			pole_top + Vector2(extent * 0.30, extent * 0.08),
			pole_top + Vector2(0.0, extent * 0.18),
		]), Color(1.0, 0.70, 0.16, alpha))
	elif _object_resolution_event_id == "overworld_object_visited":
		var radius := extent * lerpf(0.25, 0.40, motion_progress)
		var visited_color := Color(0.38, 0.94, 0.72, alpha)
		_canvas_draw_circle(center, radius, visited_color, false, maxf(2.0, extent * 0.032), true)
		var check_points := PackedVector2Array([
			center + Vector2(-extent * 0.18, 0.0),
			center + Vector2(-extent * 0.04, extent * 0.15),
			center + Vector2(extent * 0.22, -extent * 0.17),
		])
		_canvas_draw_polyline(check_points, Color(0.80, 1.0, 0.91, alpha), maxf(2.5, extent * 0.050), true)
	else:
		var radius := extent * lerpf(0.46, 0.24, motion_progress)
		var depleted_color := Color(0.72, 0.86, 0.94, alpha)
		_canvas_draw_circle(center, radius, depleted_color, false, maxf(2.0, extent * 0.032), true)
		for direction in [Vector2(-1.0, -0.35), Vector2(-0.25, -1.0), Vector2(0.55, -0.85), Vector2(1.0, -0.15)]:
			var particle_offset: Vector2 = direction.normalized() * extent * lerpf(0.12, 0.42, motion_progress)
			_canvas_draw_circle(center + particle_offset, maxf(1.5, extent * 0.035), Color(0.88, 0.95, 1.0, alpha * 0.82))

func _draw_route_blocked_presentation(board_rect: Rect2) -> void:
	if not _route_blocked_active or _route_blocked_duration_sec <= 0.0:
		return
	var rect := _tile_rect(board_rect, _route_blocked_tile)
	var progress := clampf(_route_blocked_elapsed_sec / _route_blocked_duration_sec, 0.0, 1.0)
	if _route_blocked_visual_policy != "reduced_motion_fallback" and _draw_route_blocked_imported_vfx(rect, progress):
		return
	_draw_route_blocked_procedural_marker(rect, progress)

func _draw_route_blocked_imported_vfx(rect: Rect2, progress: float) -> bool:
	var asset_state := _route_blocked_vfx_asset_state()
	if not bool(asset_state.get("uses_imported_asset", false)):
		return false
	var texture: Texture2D = _overworld_vfx_texture_for_path(String(asset_state.get("texture_path", ""))) as Texture2D
	if texture == null:
		return false
	var center := rect.get_center()
	var extent := minf(rect.size.x, rect.size.y)
	var motion_progress := progress if _route_blocked_allows_large_motion else 0.35
	var alpha := clampf(1.0 - progress * 0.68, 0.28, 1.0)
	var draw_extent := extent * float(asset_state.get("scale", 1.0)) * lerpf(0.84, 1.0, motion_progress)
	var draw_rect := Rect2(center - Vector2(draw_extent, draw_extent) * 0.5, Vector2(draw_extent, draw_extent))
	_canvas_draw_texture_rect(texture, draw_rect, false, Color(1.0, 1.0, 1.0, alpha))
	_route_blocked_last_draw = {
		"mode": "imported_texture",
		"texture_path": String(asset_state.get("texture_path", "")),
		"rect": {"x": draw_rect.position.x, "y": draw_rect.position.y, "width": draw_rect.size.x, "height": draw_rect.size.y},
		"alpha": alpha,
		"progress": progress,
	}
	return true

func _draw_route_blocked_procedural_marker(rect: Rect2, progress: float) -> void:
	var center := rect.get_center()
	var extent := minf(rect.size.x, rect.size.y)
	var motion_progress := progress if _route_blocked_allows_large_motion else 0.35
	var alpha := clampf(1.0 - progress * 0.68, 0.28, 1.0)
	if _route_blocked_event_id == "overworld_object_blocked":
		var gate_size := Vector2(extent * 0.54, extent * 0.48)
		var gate_rect := Rect2(center - gate_size * 0.5, gate_size)
		_route_blocked_last_draw = {
			"mode": "blocked_object_icon" if _route_blocked_visual_policy == "reduced_motion_fallback" else "procedural_object_blocked_marker",
			"texture_path": "",
			"gate_bar_count": 3,
			"lock_count": 1,
			"alpha": alpha,
		}
		var object_color := Color(1.0, 0.48, 0.20, alpha)
		var detail_color := Color(1.0, 0.84, 0.58, alpha)
		_canvas_draw_rect(gate_rect, object_color, false, maxf(2.0, extent * 0.038))
		for ratio in [0.25, 0.50, 0.75]:
			var bar_x: float = gate_rect.position.x + gate_rect.size.x * float(ratio)
			_canvas_draw_line(Vector2(bar_x, gate_rect.position.y), Vector2(bar_x, gate_rect.end.y), detail_color, maxf(1.8, extent * 0.032), true)
		_canvas_draw_circle(center + Vector2(0.0, extent * 0.08), maxf(2.0, extent * 0.075), detail_color, false, maxf(1.8, extent * 0.030), true)
		return
	_route_blocked_last_draw = {
		"mode": "blocked_route_icon" if _route_blocked_visual_policy == "reduced_motion_fallback" else "existing_procedural_route_blocked_marker",
		"texture_path": "",
		"circle_count": 1,
		"cross_line_count": 2,
		"alpha": alpha,
	}
	var radius := extent * lerpf(0.25, 0.40, motion_progress)
	var blocked_color := Color(1.0, 0.42, 0.24, alpha)
	_canvas_draw_circle(center, radius, blocked_color, false, maxf(2.0, extent * 0.040), true)
	var cross_extent := extent * 0.20
	_canvas_draw_line(center + Vector2(-cross_extent, -cross_extent), center + Vector2(cross_extent, cross_extent), Color(1.0, 0.82, 0.64, alpha), maxf(2.5, extent * 0.052), true)
	_canvas_draw_line(center + Vector2(cross_extent, -cross_extent), center + Vector2(-cross_extent, cross_extent), Color(1.0, 0.82, 0.64, alpha), maxf(2.5, extent * 0.052), true)

func _draw_guarded_site_presentation(board_rect: Rect2) -> void:
	if not _guarded_site_active:
		return
	var rect := _tile_rect(board_rect, _guarded_site_tile)
	if _guarded_site_visual_policy != "reduced_motion_fallback" and _draw_guarded_site_imported_vfx(rect):
		return
	_draw_guarded_site_procedural_shield(rect)

func _draw_object_focus_presentation(board_rect: Rect2) -> void:
	if not _object_focus_active:
		return
	var rect := _tile_rect(board_rect, _object_focus_tile)
	if _object_focus_visual_policy == "authored_animation_state" and _draw_object_focus_imported_vfx(rect):
		return
	_object_focus_last_draw = {
		"mode": "existing_tile_selection_outline",
		"texture_path": "",
		"rect": {"x": rect.position.x, "y": rect.position.y, "width": rect.size.x, "height": rect.size.y},
	}

func _draw_object_focus_imported_vfx(rect: Rect2) -> bool:
	var asset_state := _object_focus_vfx_asset_state()
	if not bool(asset_state.get("uses_imported_asset", false)):
		return false
	var texture: Texture2D = _overworld_vfx_texture_for_path(String(asset_state.get("texture_path", ""))) as Texture2D
	if texture == null:
		return false
	var center := rect.get_center()
	var extent := minf(rect.size.x, rect.size.y) * float(asset_state.get("scale", 1.0))
	var draw_rect := Rect2(center - Vector2(extent, extent) * 0.5, Vector2(extent, extent))
	_canvas_draw_texture_rect(texture, draw_rect, false, Color(1.0, 1.0, 1.0, 0.92))
	_object_focus_last_draw = {
		"mode": "imported_texture",
		"texture_path": String(asset_state.get("texture_path", "")),
		"rect": {"x": draw_rect.position.x, "y": draw_rect.position.y, "width": draw_rect.size.x, "height": draw_rect.size.y},
		"alpha": 0.92,
	}
	return true

func _draw_guarded_site_imported_vfx(rect: Rect2) -> bool:
	var asset_state := _guarded_site_vfx_asset_state()
	if not bool(asset_state.get("uses_imported_asset", false)):
		return false
	var texture: Texture2D = _overworld_vfx_texture_for_path(String(asset_state.get("texture_path", ""))) as Texture2D
	if texture == null:
		return false
	var center := rect.get_center()
	var extent := minf(rect.size.x, rect.size.y)
	var draw_extent := extent * float(asset_state.get("scale", 1.0))
	var draw_rect := Rect2(center - Vector2(draw_extent, draw_extent) * 0.5, Vector2(draw_extent, draw_extent))
	_canvas_draw_texture_rect(texture, draw_rect, false)
	_guarded_site_last_draw = {
		"mode": "imported_texture",
		"texture_path": String(asset_state.get("texture_path", "")),
		"rect": {"x": draw_rect.position.x, "y": draw_rect.position.y, "width": draw_rect.size.x, "height": draw_rect.size.y},
	}
	return true

func _draw_guarded_site_procedural_shield(rect: Rect2) -> void:
	var center := rect.get_center()
	var extent := minf(rect.size.x, rect.size.y)
	var guard_color := Color(1.0, 0.68, 0.18, 0.94)
	var shield_extent := extent * 0.19
	_canvas_draw_circle(center, extent * 0.38, Color(0.20, 0.08, 0.03, 0.46), true)
	_canvas_draw_circle(center, extent * 0.38, guard_color, false, maxf(2.0, extent * 0.034), true)
	_canvas_draw_colored_polygon(PackedVector2Array([
		center + Vector2(0.0, -shield_extent),
		center + Vector2(shield_extent * 0.82, -shield_extent * 0.48),
		center + Vector2(shield_extent * 0.62, shield_extent * 0.58),
		center + Vector2(0.0, shield_extent),
		center + Vector2(-shield_extent * 0.62, shield_extent * 0.58),
		center + Vector2(-shield_extent * 0.82, -shield_extent * 0.48),
	]), Color(1.0, 0.82, 0.30, 0.92))
	_canvas_draw_line(center + Vector2(0.0, -shield_extent * 0.58), center + Vector2(0.0, shield_extent * 0.48), Color(0.31, 0.12, 0.04, 0.92), maxf(2.0, extent * 0.034), true)
	_canvas_draw_circle(center + Vector2(0.0, shield_extent * 0.72), maxf(1.5, extent * 0.026), Color(0.31, 0.12, 0.04, 0.92))
	_guarded_site_last_draw = {
		"mode": "guard_badge_static" if _guarded_site_visual_policy == "reduced_motion_fallback" else "existing_procedural_guard_shield",
		"texture_path": "",
		"shield_count": 1,
	}

func _draw_spell_cast_presentation(board_rect: Rect2) -> void:
	if not _spell_cast_active or _spell_cast_duration_sec <= 0.0:
		return
	var rect := _tile_rect(board_rect, _spell_cast_tile)
	var center := rect.get_center()
	var extent := minf(rect.size.x, rect.size.y)
	var progress := clampf(_spell_cast_elapsed_sec / _spell_cast_duration_sec, 0.0, 1.0)
	var motion_progress := progress if _spell_cast_allows_large_motion else 0.36
	var alpha := clampf(1.0 - progress * 0.64, 0.30, 1.0)
	if _spell_cast_visual_policy != "reduced_motion_fallback":
		if not _draw_spell_cast_imported_vfx(rect, progress, motion_progress, alpha):
			_draw_spell_cast_procedural_rings(rect, motion_progress, alpha)
	else:
		_spell_cast_last_draw = {"mode": "adventure_spell_icon", "texture_path": "", "alpha": alpha}
	var icon_extent := extent * 0.18
	_canvas_draw_line(center + Vector2(-icon_extent, 0.0), center + Vector2(icon_extent, 0.0), Color(0.94, 0.99, 1.0, alpha), maxf(2.0, extent * 0.036), true)
	_canvas_draw_line(center + Vector2(0.0, -icon_extent), center + Vector2(0.0, icon_extent), Color(0.94, 0.99, 1.0, alpha), maxf(2.0, extent * 0.036), true)
	_canvas_draw_line(center + Vector2(-icon_extent * 0.68, -icon_extent * 0.68), center + Vector2(icon_extent * 0.68, icon_extent * 0.68), Color(0.78, 0.94, 1.0, alpha), maxf(1.5, extent * 0.024), true)
	_canvas_draw_line(center + Vector2(icon_extent * 0.68, -icon_extent * 0.68), center + Vector2(-icon_extent * 0.68, icon_extent * 0.68), Color(0.78, 0.94, 1.0, alpha), maxf(1.5, extent * 0.024), true)

func _draw_spell_cast_imported_vfx(rect: Rect2, progress: float, motion_progress: float, alpha: float) -> bool:
	var asset_state := _spell_cast_vfx_asset_state()
	if not bool(asset_state.get("uses_imported_asset", false)):
		return false
	var texture: Texture2D = _overworld_vfx_texture_for_path(String(asset_state.get("texture_path", ""))) as Texture2D
	if texture == null:
		return false
	var center := rect.get_center()
	var extent := minf(rect.size.x, rect.size.y)
	var draw_extent := extent * float(asset_state.get("scale", 1.0)) * lerpf(0.82, 1.0, motion_progress)
	var draw_rect := Rect2(center - Vector2(draw_extent, draw_extent) * 0.5, Vector2(draw_extent, draw_extent))
	_canvas_draw_texture_rect(texture, draw_rect, false, Color(1.0, 1.0, 1.0, alpha))
	_spell_cast_last_draw = {
		"mode": "imported_texture",
		"texture_path": String(asset_state.get("texture_path", "")),
		"rect": {"x": draw_rect.position.x, "y": draw_rect.position.y, "width": draw_rect.size.x, "height": draw_rect.size.y},
		"alpha": alpha,
		"progress": progress,
	}
	return true

func _draw_spell_cast_procedural_rings(rect: Rect2, motion_progress: float, alpha: float) -> void:
	var center := rect.get_center()
	var extent := minf(rect.size.x, rect.size.y)
	var radius := extent * lerpf(0.28, 0.50, motion_progress)
	var spell_color := Color(0.44, 0.82, 1.0, alpha)
	_canvas_draw_circle(center, radius, spell_color, false, maxf(2.0, extent * 0.034), true)
	_canvas_draw_circle(center, radius * 0.66, Color(0.72, 0.94, 1.0, alpha * 0.86), false, maxf(1.5, extent * 0.022), true)
	_spell_cast_last_draw = {
		"mode": "existing_procedural_adventure_cast_rings",
		"texture_path": "",
		"alpha": alpha,
		"ring_count": 2,
	}

func _draw_resource_sprite(node: Dictionary, rect: Rect2, remembered: bool, tile: Vector2i) -> bool:
	return _draw_object_sprite(_resource_asset_id(node), rect, remembered, _resource_object_profile(node), tile)

func _draw_artifact_sprite(node: Dictionary, rect: Rect2, remembered: bool, tile: Vector2i) -> bool:
	if node.is_empty():
		return false
	return _draw_object_sprite(_artifact_sprite_asset_id(node), rect, remembered, _artifact_object_profile(node), tile)

func _draw_town_sprite(rect: Rect2, entry_rect: Rect2, remembered: bool, tile: Vector2i) -> bool:
	var asset_id := _town_sprite_asset_id(_town_at(tile))
	var texture = _object_texture_for_asset(asset_id)
	if not (texture is Texture2D):
		return false
	var anchor := _draw_town_grounding_anchor(rect, remembered, tile)
	var draw_payload := _town_sprite_draw_payload(asset_id, texture, rect)
	var draw_texture: Texture2D = draw_payload.get("draw_texture", texture)
	var sprite_rect: Rect2 = draw_payload.get("draw_rect", Rect2(rect.get_center(), Vector2.ZERO))
	_draw_sprite_silhouette_outline(
		draw_texture,
		sprite_rect,
		TOWN_SPRITE_SILHOUETTE_MEMORY if remembered else TOWN_SPRITE_SILHOUETTE_VISIBLE,
		maxf(TOWN_SPRITE_SILHOUETTE_MIN_PX, minf(rect.size.x, rect.size.y) * TOWN_SPRITE_SILHOUETTE_WIDTH_FACTOR)
	)
	_canvas_draw_texture_rect(draw_texture, sprite_rect, false, OBJECT_SPRITE_MEMORY_MODULATE if remembered else OBJECT_SPRITE_VISIBLE_MODULATE)
	_draw_town_owner_pennant(rect, _town_color(tile), remembered, _town_owner_id(_town_at(tile)))
	_draw_town_front_contact(anchor, remembered)
	_draw_town_entry_approach(entry_rect, _town_color(tile), remembered)
	return true

func _draw_sprite_silhouette_outline(texture: Texture2D, rect: Rect2, color: Color, width: float) -> void:
	if texture == null or rect.size.x <= 0.0 or rect.size.y <= 0.0 or width <= 0.0:
		return
	for direction in [
		Vector2(-1.0, -1.0), Vector2(0.0, -1.0), Vector2(1.0, -1.0),
		Vector2(-1.0, 0.0), Vector2(1.0, 0.0),
		Vector2(-1.0, 1.0), Vector2(0.0, 1.0), Vector2(1.0, 1.0),
	]:
		_canvas_draw_texture_rect(texture, Rect2(rect.position + direction * width, rect.size), false, color)

func _town_sprite_draw_payload(asset_id: String, texture: Texture2D, footprint_rect: Rect2, single_tile_extent_override: float = 0.0) -> Dictionary:
	var footprint := _object_profile_footprint(_town_object_profile())
	var footprint_extent := minf(footprint_rect.size.x, footprint_rect.size.y)
	var visible_extent_px := maxf(12.0, footprint_extent * TOWN_SPRITE_EXTENT_FACTOR)
	var single_tile_extent := single_tile_extent_override if single_tile_extent_override > 0.0 else _object_world_tile_extent(footprint_rect, footprint)
	var painted_ground_line_y := footprint_rect.end.y - single_tile_extent * TOWN_SPRITE_GROUND_CLEARANCE_TILES
	var provisional_center := Vector2(footprint_rect.get_center().x, painted_ground_line_y - visible_extent_px * 0.5)
	var payload := _object_painted_sprite_draw_payload(asset_id, texture, provisional_center, visible_extent_px)
	var draw_rect: Rect2 = payload.get("draw_rect", Rect2(provisional_center, Vector2.ZERO))
	var width_cap_px := single_tile_extent * TOWN_SPRITE_WIDTH_CAP_TILES
	draw_rect.size = Vector2(width_cap_px, visible_extent_px)
	draw_rect.position = Vector2(
		footprint_rect.get_center().x - width_cap_px * 0.5,
		painted_ground_line_y - visible_extent_px
	)
	var grounding_adjustment := painted_ground_line_y - draw_rect.end.y
	draw_rect.position.y += grounding_adjustment
	payload["draw_rect"] = draw_rect
	payload["draw_size"] = draw_rect.size
	payload["draw_aspect"] = draw_rect.size.x / maxf(draw_rect.size.y, 0.0001)
	payload["sprite_center"] = provisional_center + Vector2(0.0, grounding_adjustment)
	payload["visible_extent_px"] = visible_extent_px
	payload["single_tile_extent_px"] = single_tile_extent
	payload["town_width_cap_px"] = width_cap_px
	payload["town_width_cap_tiles"] = TOWN_SPRITE_WIDTH_CAP_TILES
	payload["town_vertical_landmark_fit"] = true
	payload["painted_ground_line_y"] = painted_ground_line_y
	payload["painted_bottom_clearance_px"] = footprint_rect.end.y - draw_rect.end.y
	payload["footprint_rect"] = footprint_rect
	return payload

func _draw_encounter_sprite(encounter: Dictionary, rect: Rect2, remembered: bool, tile: Vector2i) -> bool:
	if bool(encounter.get("prefer_identity_landmark", false)) and _draw_preferred_encounter_landmark(encounter, rect, remembered, tile):
		return true
	if _draw_encounter_commander_sprite(encounter, rect, remembered, tile):
		return true
	if _draw_encounter_identity_landmark(encounter, rect, remembered, tile):
		return true
	if _draw_encounter_faction_landmark(encounter, rect, remembered, tile):
		return true
	if _draw_encounter_unit_icon(encounter, rect, remembered, tile):
		return true
	return _draw_object_sprite(_encounter_asset_id(encounter), rect, remembered, _encounter_object_profile(), tile)

func _draw_preferred_encounter_landmark(encounter: Dictionary, rect: Rect2, remembered: bool, tile: Vector2i) -> bool:
	return _draw_encounter_identity_landmark(encounter, rect, remembered, tile)

func _draw_encounter_commander_sprite(encounter: Dictionary, rect: Rect2, remembered: bool, tile: Vector2i) -> bool:
	var hero := _enemy_commander_hero_template(encounter)
	var texture = _object_texture_for_asset(_hero_sprite_asset_id(hero))
	if not (texture is Texture2D):
		return false
	var anchor := _draw_procedural_object_grounding(rect, tile, "encounter", Vector2i(1, 1), remembered)
	var layout := _hostile_actor_layout(rect, anchor.get("center", rect.get_center()), remembered)
	var icon_rect: Rect2 = layout.get("icon_rect", Rect2())
	_canvas_draw_texture_rect(texture, icon_rect, false, OBJECT_SPRITE_MEMORY_MODULATE if remembered else OBJECT_SPRITE_VISIBLE_MODULATE)
	_draw_hostile_actor_marker(layout.get("marker_profile", {}))
	_draw_procedural_contact_marks(anchor, "encounter", remembered)
	return true

func _draw_encounter_identity_landmark(encounter: Dictionary, rect: Rect2, remembered: bool, tile: Vector2i) -> bool:
	var texture = _object_texture_for_asset(_encounter_identity_asset_id(encounter))
	if not (texture is Texture2D):
		return false
	var anchor := _draw_procedural_object_grounding(rect, tile, "encounter", Vector2i(1, 1), remembered)
	var layout := _hostile_actor_layout(rect, anchor.get("center", rect.get_center()), remembered, OBJECT_FACTION_ENCOUNTER_VISIBLE_EXTENT_TILES)
	var icon_rect: Rect2 = layout.get("icon_rect", Rect2())
	_canvas_draw_texture_rect(texture, icon_rect, false, OBJECT_SPRITE_MEMORY_MODULATE if remembered else OBJECT_SPRITE_VISIBLE_MODULATE)
	_draw_hostile_actor_marker(layout.get("marker_profile", {}))
	_draw_procedural_contact_marks(anchor, "encounter", remembered)
	return true

func _draw_encounter_faction_landmark(encounter: Dictionary, rect: Rect2, remembered: bool, tile: Vector2i) -> bool:
	var texture = _object_texture_for_asset(_encounter_faction_asset_id(encounter))
	if not (texture is Texture2D):
		return false
	var anchor := _draw_procedural_object_grounding(rect, tile, "encounter", Vector2i(1, 1), remembered)
	var layout := _hostile_actor_layout(rect, anchor.get("center", rect.get_center()), remembered, OBJECT_FACTION_ENCOUNTER_VISIBLE_EXTENT_TILES)
	var icon_rect: Rect2 = layout.get("icon_rect", Rect2())
	_canvas_draw_texture_rect(texture, icon_rect, false, OBJECT_SPRITE_MEMORY_MODULATE if remembered else OBJECT_SPRITE_VISIBLE_MODULATE)
	_draw_hostile_actor_marker(layout.get("marker_profile", {}))
	_draw_procedural_contact_marks(anchor, "encounter", remembered)
	return true

func _draw_encounter_unit_icon(encounter: Dictionary, rect: Rect2, remembered: bool, tile: Vector2i) -> bool:
	var path := _encounter_overworld_icon_path(encounter)
	if path == "":
		return false
	var texture: Variant = _unit_art_texture(path)
	if not (texture is Texture2D):
		return false
	var anchor := _draw_procedural_object_grounding(rect, tile, "encounter", Vector2i(1, 1), remembered)
	var layout := _hostile_actor_layout(rect, anchor.get("center", rect.get_center()), remembered)
	var icon_rect: Rect2 = layout.get("icon_rect", Rect2())
	_canvas_draw_texture_rect(texture, icon_rect, false, OBJECT_SPRITE_MEMORY_MODULATE if remembered else OBJECT_SPRITE_VISIBLE_MODULATE)
	_draw_hostile_actor_marker(layout.get("marker_profile", {}))
	_draw_procedural_contact_marks(anchor, "encounter", remembered)
	return true

func _hostile_actor_layout(rect: Rect2, ground_center: Vector2, remembered: bool, visible_extent_tiles: float = OBJECT_ENCOUNTER_VISIBLE_EXTENT_TILES) -> Dictionary:
	var extent := minf(rect.size.x, rect.size.y)
	var icon_extent := maxf(14.0, extent * visible_extent_tiles)
	var icon_center := ground_center + Vector2(0.0, -extent * 0.14)
	var marker_outset := maxf(2.0, extent * HOSTILE_ACTOR_MARKER_OUTSET_FACTOR)
	var contained_half_extent := icon_extent * 0.5 + marker_outset + 0.25
	icon_center.x = clampf(icon_center.x, rect.position.x + contained_half_extent, rect.end.x - contained_half_extent)
	icon_center.y = clampf(icon_center.y, rect.position.y + contained_half_extent, rect.end.y - contained_half_extent)
	var icon_rect := Rect2(icon_center - Vector2(icon_extent, icon_extent) * 0.5, Vector2(icon_extent, icon_extent))
	return {
		"tile_rect": rect,
		"icon_rect": icon_rect,
		"marker_profile": _hostile_actor_marker_profile(rect, icon_rect, extent, remembered),
	}

func _hostile_actor_marker_profile(tile_rect: Rect2, icon_rect: Rect2, tile_extent: float, remembered: bool) -> Dictionary:
	var outset := maxf(2.0, tile_extent * HOSTILE_ACTOR_MARKER_OUTSET_FACTOR)
	var marker_rect := icon_rect.grow(outset)
	var line_width := maxf(1.25, tile_extent * HOSTILE_ACTOR_MARKER_LINE_WIDTH_FACTOR)
	return {
		"model": HOSTILE_ACTOR_MARKER_MODEL,
		"tile_rect": tile_rect,
		"icon_rect": icon_rect,
		"marker_rect": marker_rect,
		"center_y": marker_rect.get_center().y,
		"flank_length_px": maxf(4.0, tile_extent * HOSTILE_ACTOR_MARKER_FLANK_LENGTH_FACTOR),
		"flank_depth_px": maxf(3.5, tile_extent * HOSTILE_ACTOR_MARKER_FLANK_DEPTH_FACTOR),
		"threat_notch_width_px": maxf(5.0, tile_extent * HOSTILE_ACTOR_MARKER_NOTCH_WIDTH_FACTOR),
		"threat_notch_depth_px": maxf(3.0, tile_extent * HOSTILE_ACTOR_MARKER_NOTCH_DEPTH_FACTOR),
		"line_width_px": line_width,
		"shadow_width_px": line_width + 1.5,
		"marker_alpha": HOSTILE_ACTOR_MARKER_MEMORY_ALPHA if remembered else HOSTILE_ACTOR_MARKER_VISIBLE_ALPHA,
		"shadow_alpha": HOSTILE_ACTOR_MARKER_SHADOW_ALPHA,
		"flank_chevron_count": 2,
		"threat_notch_count": 1,
		"continuous_ring": false,
		"interior_fill_alpha": 0.0,
		"remembered": remembered,
		"contained_in_tile": tile_rect.encloses(marker_rect),
	}

func _draw_hostile_actor_marker(profile: Dictionary) -> void:
	var marker_rect: Rect2 = profile.get("marker_rect", Rect2())
	if marker_rect.size.x <= 0.0 or marker_rect.size.y <= 0.0:
		return
	var center_y := float(profile.get("center_y", marker_rect.get_center().y))
	var flank_length := float(profile.get("flank_length_px", 4.0))
	var flank_depth := float(profile.get("flank_depth_px", 3.5))
	var notch_width := float(profile.get("threat_notch_width_px", 5.0))
	var notch_depth := float(profile.get("threat_notch_depth_px", 3.0))
	var line_width := float(profile.get("line_width_px", 1.25))
	var shadow_width := float(profile.get("shadow_width_px", line_width + 1.5))
	var left_flank := PackedVector2Array([
		Vector2(marker_rect.position.x + flank_length, center_y - flank_depth),
		Vector2(marker_rect.position.x, center_y),
		Vector2(marker_rect.position.x + flank_length, center_y + flank_depth),
	])
	var right_flank := PackedVector2Array([
		Vector2(marker_rect.end.x - flank_length, center_y - flank_depth),
		Vector2(marker_rect.end.x, center_y),
		Vector2(marker_rect.end.x - flank_length, center_y + flank_depth),
	])
	var top_center := Vector2(marker_rect.get_center().x, marker_rect.position.y)
	var threat_notch := PackedVector2Array([
		top_center + Vector2(-notch_width * 0.5, 0.0),
		top_center + Vector2(0.0, notch_depth),
		top_center + Vector2(notch_width * 0.5, 0.0),
	])
	var shadow_color := Color(0.025, 0.018, 0.014, float(profile.get("shadow_alpha", HOSTILE_ACTOR_MARKER_SHADOW_ALPHA)))
	var base_color := MEMORY_OBJECT_OUTLINE if bool(profile.get("remembered", false)) else ENCOUNTER_COLOR
	var marker_color := Color(base_color.r, base_color.g, base_color.b, float(profile.get("marker_alpha", HOSTILE_ACTOR_MARKER_VISIBLE_ALPHA)))
	for points in [left_flank, right_flank, threat_notch]:
		_canvas_draw_polyline(points, shadow_color, shadow_width, true)
		_canvas_draw_polyline(points, marker_color, line_width, true)

func _hostile_actor_marker_validation_payload(profile: Dictionary) -> Dictionary:
	var tile_rect: Rect2 = profile.get("tile_rect", Rect2())
	var icon_rect: Rect2 = profile.get("icon_rect", Rect2())
	var marker_rect: Rect2 = profile.get("marker_rect", Rect2())
	return {
		"model": String(profile.get("model", "")),
		"tile_rect": _rect_payload(tile_rect),
		"icon_rect": _rect_payload(icon_rect),
		"marker_rect": _rect_payload(marker_rect),
		"flank_chevron_count": int(profile.get("flank_chevron_count", 0)),
		"threat_notch_count": int(profile.get("threat_notch_count", 0)),
		"line_width_px": float(profile.get("line_width_px", 0.0)),
		"shadow_width_px": float(profile.get("shadow_width_px", 0.0)),
		"marker_alpha": float(profile.get("marker_alpha", 0.0)),
		"visible_alpha": HOSTILE_ACTOR_MARKER_VISIBLE_ALPHA,
		"remembered_alpha": HOSTILE_ACTOR_MARKER_MEMORY_ALPHA,
		"continuous_ring": bool(profile.get("continuous_ring", true)),
		"interior_fill_alpha": float(profile.get("interior_fill_alpha", 1.0)),
		"contained_in_tile": bool(profile.get("contained_in_tile", false)),
		"antialiased": true,
	}

func _draw_decorative_object_sprite(object: Dictionary, rect: Rect2, remembered: bool, tile: Vector2i) -> bool:
	if bool(object.get("generated_decorative_body_cell", false)):
		return _draw_generated_decorative_body_sprite(object, rect, remembered, tile)
	return _draw_object_sprite(_decorative_object_asset_id(object), rect, remembered, _decorative_object_profile(object), tile)

func _draw_generated_decorative_body_sprite(object: Dictionary, rect: Rect2, remembered: bool, tile: Vector2i) -> bool:
	if not bool(object.get("generated_body_visual_anchor", false)):
		return true
	var asset_id := _decorative_object_asset_id(object)
	var texture = _object_texture_for_asset(asset_id)
	if not (texture is Texture2D):
		return false
	var footprint_payload: Dictionary = object.get("footprint", {}) if object.get("footprint", {}) is Dictionary else {}
	var footprint := Vector2i(
		maxi(1, int(footprint_payload.get("width", 1))),
		maxi(1, int(footprint_payload.get("height", 1)))
	)
	var tile_extent := _object_world_tile_extent(rect, footprint)
	var sprite_extent := maxf(12.0, tile_extent * float(object.get("generated_body_sprite_extent_tiles", GENERATED_DECORATIVE_BODY_SPRITE_EXTENT_TILES)))
	var center_payload: Dictionary = object.get("generated_body_sprite_center_tiles", {}) if object.get("generated_body_sprite_center_tiles", {}) is Dictionary else {}
	var sprite_center := rect.position + Vector2(
		rect.size.x * float(center_payload.get("x", 0.5)),
		rect.size.y * float(center_payload.get("y", 0.5))
	)
	var grounding_center := sprite_center + Vector2(0.0, sprite_extent * 0.38)
	var grounding_rect := Rect2(
		grounding_center - Vector2(sprite_extent * 0.54, tile_extent * 0.24),
		Vector2(sprite_extent * 1.08, tile_extent * 0.48)
	)
	_draw_mapped_sprite_grounding_anchor(grounding_rect, tile, "blocker", footprint, remembered)
	var draw_payload := _object_painted_sprite_draw_payload(asset_id, texture, sprite_center, sprite_extent)
	var draw_texture: Texture2D = draw_payload.get("draw_texture", texture)
	var sprite_rect: Rect2 = draw_payload.get("draw_rect", Rect2(sprite_center - Vector2(sprite_extent, sprite_extent) * 0.5, Vector2(sprite_extent, sprite_extent)))
	var base_modulate := OBJECT_SPRITE_MEMORY_MODULATE if remembered else OBJECT_SPRITE_VISIBLE_MODULATE
	_canvas_draw_texture_rect(draw_texture, sprite_rect, false, base_modulate)
	return true

func _draw_standalone_map_object_sprite(object: Dictionary, rect: Rect2, remembered: bool, tile: Vector2i) -> bool:
	return _draw_object_sprite(_standalone_map_object_asset_id(object), rect, remembered, _standalone_map_object_profile(object), tile)

func _draw_decorative_object_marker(object: Dictionary, rect: Rect2, remembered: bool, tile: Vector2i) -> void:
	var profile := _decorative_object_profile(object)
	var footprint := _object_profile_footprint(profile)
	var family := String(profile.get("family", "blocker"))
	var anchor := _draw_procedural_object_grounding(rect, tile, family, footprint, remembered)
	var marker_color := _procedural_resource_marker_color(family, remembered)
	var outline_color := MEMORY_OBJECT_OUTLINE if remembered else MARKER_OUTLINE_COLOR
	if family == "blocker":
		_draw_ruin_silhouette(rect, marker_color, outline_color, remembered)
	else:
		_draw_pickup_silhouette(rect, marker_color, outline_color, remembered)
	_draw_procedural_contact_marks(anchor, family, remembered)

func _draw_standalone_map_object_marker(object: Dictionary, rect: Rect2, remembered: bool, tile: Vector2i) -> void:
	var profile := _standalone_map_object_profile(object)
	var footprint := _object_profile_footprint(profile)
	var family := String(profile.get("family", "pickup"))
	var anchor := _draw_procedural_object_grounding(rect, tile, family, footprint, remembered)
	var marker_color := _procedural_resource_marker_color(family, remembered)
	var outline_color := MEMORY_OBJECT_OUTLINE if remembered else MARKER_OUTLINE_COLOR
	match family:
		"neutral_dwelling":
			_draw_dwelling_silhouette(rect, marker_color, outline_color, remembered)
		"mine", "support_producer", "staged_resource_front":
			_draw_mine_silhouette(rect, marker_color, outline_color, remembered)
		"scouting_structure", "sign_waypoint":
			_draw_tower_silhouette(rect, marker_color, outline_color, remembered)
		"guarded_reward_site", "scenario_objective", "faction_landmark":
			_draw_ruin_silhouette(rect, marker_color, outline_color, remembered)
		"transit_object":
			_draw_transit_silhouette(rect, marker_color, outline_color, remembered)
		"shrine", "repeatable_service":
			_draw_shrine_silhouette(rect, marker_color, outline_color, remembered)
		_:
			_draw_pickup_silhouette(rect, marker_color, outline_color, remembered)
	_draw_procedural_contact_marks(anchor, family, remembered)

func _draw_object_sprite(asset_id: String, rect: Rect2, remembered: bool, profile: Dictionary, tile: Vector2i) -> bool:
	var texture = _object_texture_for_asset(asset_id)
	if not (texture is Texture2D):
		return false
	var footprint := _object_profile_footprint(profile)
	var family := String(profile.get("family", "pickup"))
	_draw_mapped_sprite_grounding_anchor(rect, tile, family, footprint, remembered)
	var town_adjunct_cap_tiles := TOWN_ADJUNCT_RESOURCE_VISIBLE_EXTENT_CAP_TILES if not _town_presentation_at(tile).is_empty() else 0.0
	var metrics := _object_sprite_visual_metrics(rect, profile, 0.0, Rect2(), town_adjunct_cap_tiles)
	var sprite_extent := float(metrics.get("sprite_extent_px", 12.0))
	var sprite_center: Vector2 = metrics.get("sprite_center", rect.get_center())
	var draw_payload := _object_painted_sprite_draw_payload(asset_id, texture, sprite_center, sprite_extent)
	var draw_texture: Texture2D = draw_payload.get("draw_texture", texture)
	var sprite_rect: Rect2 = draw_payload.get("draw_rect", Rect2(sprite_center, Vector2.ZERO))
	if _mapped_object_uses_interactive_silhouette(profile):
		_draw_sprite_silhouette_outline(
			draw_texture,
			sprite_rect,
			OBJECT_INTERACTIVE_SILHOUETTE_MEMORY if remembered else OBJECT_INTERACTIVE_SILHOUETTE_VISIBLE,
			maxf(OBJECT_INTERACTIVE_SILHOUETTE_MIN_PX, sprite_extent * OBJECT_INTERACTIVE_SILHOUETTE_WIDTH_FACTOR)
		)
	_canvas_draw_texture_rect(draw_texture, sprite_rect, false, _mapped_object_sprite_modulate(profile, remembered))
	return true

func _mapped_object_uses_interactive_silhouette(profile: Dictionary) -> bool:
	return _semantic_visual_scale_class(profile) not in ["ground_detail", "terrain_blocker"]

func _mapped_object_sprite_modulate(profile: Dictionary, remembered: bool) -> Color:
	if remembered:
		return OBJECT_SPRITE_MEMORY_MODULATE
	if _semantic_visual_scale_class(profile) == "ground_detail":
		return OBJECT_SPRITE_DECORATION_MODULATE
	return OBJECT_SPRITE_VISIBLE_MODULATE

func _object_canvas_draw_rect(asset_id: String, texture: Texture2D, sprite_center: Vector2, visible_extent_px: float, preloaded_region: Dictionary = {}) -> Rect2:
	var region := preloaded_region if not preloaded_region.is_empty() else _object_texture_visible_region(asset_id, texture)
	var painted_extent_fraction := clampf(
		float(region.get("painted_extent_fraction", 1.0)),
		OBJECT_MIN_PAINTED_EXTENT_FRACTION,
		1.0
	)
	var canvas_extent := visible_extent_px / painted_extent_fraction
	return Rect2(sprite_center - Vector2(canvas_extent, canvas_extent) * 0.5, Vector2(canvas_extent, canvas_extent))

func _object_painted_sprite_draw_payload(asset_id: String, texture: Texture2D, sprite_center: Vector2, visible_extent_px: float) -> Dictionary:
	var region := _object_texture_visible_region(asset_id, texture)
	var source_rect: Rect2 = region.get("source_rect", Rect2(Vector2.ZERO, texture.get_size()))
	if source_rect.size.x <= 0.0 or source_rect.size.y <= 0.0:
		source_rect = Rect2(Vector2.ZERO, texture.get_size())
	var canvas_draw_rect := _object_canvas_draw_rect(asset_id, texture, sprite_center, visible_extent_px, region)
	var normalized_source_rect: Rect2 = region.get("normalized_source_rect", Rect2(Vector2.ZERO, Vector2.ONE))
	var draw_rect := Rect2(
		canvas_draw_rect.position + normalized_source_rect.position * canvas_draw_rect.size,
		normalized_source_rect.size * canvas_draw_rect.size
	)
	var draw_size := draw_rect.size
	var source_aspect := source_rect.size.x / maxf(source_rect.size.y, 1.0)
	return {
		"draw_texture": region.get("draw_texture", texture),
		"draw_rect": draw_rect,
		"draw_size": draw_size,
		"canvas_draw_rect": canvas_draw_rect,
		"canvas_extent_px": canvas_draw_rect.size.x,
		"draw_aspect": draw_size.x / maxf(draw_size.y, 0.0001),
		"source_rect": source_rect,
		"source_aspect": source_aspect,
		"uses_painted_bounds": bool(region.get("uses_painted_bounds", false)),
		"visible_scale_model": OBJECT_VISIBLE_SCALE_MODEL,
	}

func _object_texture_visible_region(asset_id: String, texture: Texture2D) -> Dictionary:
	var cache_key := asset_id.strip_edges()
	if cache_key != "" and _object_texture_visible_regions.has(cache_key):
		return _object_texture_visible_regions.get(cache_key, {})
	var texture_size := texture.get_size()
	var full_rect := Rect2(Vector2.ZERO, texture_size)
	var source_rect := full_rect
	var uses_painted_bounds := false
	var draw_texture: Texture2D = texture
	var image := texture.get_image()
	if image != null and not image.is_empty():
		var used_rect: Rect2i = image.get_used_rect()
		if used_rect.size.x > 0 and used_rect.size.y > 0:
			var left := maxi(0, used_rect.position.x - OBJECT_PAINTED_BOUNDS_PADDING_PIXELS)
			var top := maxi(0, used_rect.position.y - OBJECT_PAINTED_BOUNDS_PADDING_PIXELS)
			var right := mini(image.get_width(), used_rect.end.x + OBJECT_PAINTED_BOUNDS_PADDING_PIXELS)
			var bottom := mini(image.get_height(), used_rect.end.y + OBJECT_PAINTED_BOUNDS_PADDING_PIXELS)
			if right > left and bottom > top:
				source_rect = Rect2(Vector2(left, top), Vector2(right - left, bottom - top))
				uses_painted_bounds = source_rect != full_rect
				if uses_painted_bounds:
					var cropped_image := image.get_region(Rect2i(source_rect))
					if cropped_image != null and not cropped_image.is_empty():
						draw_texture = ImageTexture.create_from_image(cropped_image)
	var payload := {
		"draw_texture": draw_texture,
		"source_rect": source_rect,
		"texture_size": texture_size,
		"normalized_source_rect": Rect2(
			Vector2(source_rect.position.x / maxf(texture_size.x, 1.0), source_rect.position.y / maxf(texture_size.y, 1.0)),
			Vector2(source_rect.size.x / maxf(texture_size.x, 1.0), source_rect.size.y / maxf(texture_size.y, 1.0))
		),
		"painted_extent_fraction": maxf(source_rect.size.x / maxf(texture_size.x, 1.0), source_rect.size.y / maxf(texture_size.y, 1.0)),
		"uses_painted_bounds": uses_painted_bounds,
		"visible_scale_model": OBJECT_VISIBLE_SCALE_MODEL,
	}
	if cache_key != "":
		_object_texture_visible_regions[cache_key] = payload.duplicate(true)
	return payload

func _object_texture_visible_source_rect(asset_id: String, texture: Texture2D) -> Rect2:
	var region := _object_texture_visible_region(asset_id, texture)
	var source_rect: Rect2 = region.get("source_rect", Rect2(Vector2.ZERO, texture.get_size()))
	if source_rect.size.x <= 0.0 or source_rect.size.y <= 0.0:
		return Rect2(Vector2.ZERO, texture.get_size())
	return source_rect

func _object_sprite_visual_metrics(
	rect: Rect2,
	profile: Dictionary,
	world_tile_extent_override: float = 0.0,
	visible_footprint_rect_override: Rect2 = Rect2(),
	visible_extent_cap_tiles_override: float = 0.0
) -> Dictionary:
	var footprint := _object_profile_footprint(profile)
	var family := String(profile.get("family", "pickup"))
	var extent := minf(rect.size.x, rect.size.y)
	var single_tile_extent := world_tile_extent_override if world_tile_extent_override > 0.0 else _object_world_tile_extent(rect, footprint)
	var visible_footprint_rect := visible_footprint_rect_override if visible_footprint_rect_override.size.x > 0.0 and visible_footprint_rect_override.size.y > 0.0 else _object_visible_footprint_rect(rect)
	var sprite_fraction := _sprite_extent_fraction(profile, footprint)
	var uncapped_sprite_extent := maxf(12.0, extent * sprite_fraction)
	var uses_multi_tile_cap := (footprint.x > 1 or footprint.y > 1) and family not in ["blocker", "decoration", "town"]
	var multi_tile_bounds := _multi_tile_interactive_sprite_extent_bounds(footprint) if uses_multi_tile_cap else Vector2.ZERO
	var sprite_extent := clampf(
		uncapped_sprite_extent,
		single_tile_extent * multi_tile_bounds.x,
		single_tile_extent * multi_tile_bounds.y
	) if uses_multi_tile_cap else uncapped_sprite_extent
	var visible_extent_cap := maxf(
		12.0,
		minf(visible_footprint_rect.size.x, visible_footprint_rect.size.y)
			- single_tile_extent * OBJECT_VISIBLE_FOOTPRINT_INSET_TILES * 2.0
	)
	if visible_extent_cap_tiles_override > 0.0:
		visible_extent_cap = minf(visible_extent_cap, single_tile_extent * visible_extent_cap_tiles_override)
	sprite_extent = minf(sprite_extent, visible_extent_cap)
	var sprite_center := visible_footprint_rect.get_center()
	var ground_line_y := visible_footprint_rect.end.y \
		- single_tile_extent * (1.0 - _mapped_sprite_ground_center_y_factor(family))
	sprite_center.y = clampf(
		ground_line_y - sprite_extent * 0.5,
		visible_footprint_rect.position.y + sprite_extent * 0.5,
		visible_footprint_rect.end.y - sprite_extent * 0.5
	)
	return {
		"family": family,
		"footprint": {"width": footprint.x, "height": footprint.y},
		"single_tile_extent_px": single_tile_extent,
		"uncapped_sprite_extent_px": uncapped_sprite_extent,
		"sprite_extent_px": maxf(12.0, sprite_extent),
		"sprite_extent_tiles": maxf(12.0, sprite_extent) / maxf(single_tile_extent, 1.0),
		"min_tiles": multi_tile_bounds.x if uses_multi_tile_cap else 0.0,
		"cap_tiles": multi_tile_bounds.y if uses_multi_tile_cap else 0.0,
		"uses_multi_tile_visual_cap": uses_multi_tile_cap,
		"visible_footprint_rect": visible_footprint_rect,
		"footprint_clipped": visible_footprint_rect != rect,
		"visible_extent_cap_tiles_override": visible_extent_cap_tiles_override,
		"sprite_center": sprite_center,
	}

func _object_world_tile_extent(rect: Rect2, footprint: Vector2i) -> float:
	var board_rect := _board_rect()
	if _map_size.x > 0 and _map_size.y > 0 and board_rect.size.x > 0.0 and board_rect.size.y > 0.0:
		var board_tile_size := board_rect.size / Vector2(_map_size)
		var board_tile_extent := minf(board_tile_size.x, board_tile_size.y)
		if board_tile_extent > 0.0:
			return board_tile_extent
	return minf(
		rect.size.x / float(maxi(footprint.x, 1)),
		rect.size.y / float(maxi(footprint.y, 1))
	)

func _object_visible_footprint_rect(rect: Rect2) -> Rect2:
	var board_rect := _board_rect()
	if board_rect.size.x <= 0.0 or board_rect.size.y <= 0.0 or not board_rect.intersects(rect):
		return rect
	var visible_rect := board_rect.intersection(rect)
	return visible_rect if visible_rect.size.x > 0.0 and visible_rect.size.y > 0.0 else rect

func _multi_tile_interactive_sprite_extent_bounds(footprint: Vector2i) -> Vector2:
	var normalized_footprint := _normalized_footprint(footprint)
	var span_steps := float(maxi(maxi(normalized_footprint.x, normalized_footprint.y) - 1, 0))
	var depth_steps := float(maxi(mini(normalized_footprint.x, normalized_footprint.y) - 1, 0))
	var min_tiles := minf(
		MULTI_TILE_INTERACTIVE_SPRITE_EXTENT_BASE_MIN_TILES
			+ span_steps * MULTI_TILE_INTERACTIVE_SPRITE_EXTENT_SPAN_MIN_STEP_TILES
			+ depth_steps * MULTI_TILE_INTERACTIVE_SPRITE_EXTENT_DEPTH_MIN_STEP_TILES,
		MULTI_TILE_INTERACTIVE_SPRITE_EXTENT_ABSOLUTE_CAP_TILES
	)
	var cap_tiles := minf(
		MULTI_TILE_INTERACTIVE_SPRITE_EXTENT_BASE_CAP_TILES
			+ span_steps * MULTI_TILE_INTERACTIVE_SPRITE_EXTENT_SPAN_CAP_STEP_TILES
			+ depth_steps * MULTI_TILE_INTERACTIVE_SPRITE_EXTENT_DEPTH_CAP_STEP_TILES,
		MULTI_TILE_INTERACTIVE_SPRITE_EXTENT_ABSOLUTE_CAP_TILES
	)
	return Vector2(min_tiles, maxf(min_tiles, cap_tiles))

func _draw_town_owner_pennant(rect: Rect2, color: Color, remembered: bool, owner: String) -> void:
	var profile := _town_owner_pennant_profile(
		rect,
		color,
		remembered,
		owner,
		FrontierVisualKitScript.color_cue_assist_enabled()
	)
	var asset_id := String(profile.get("asset_id", ""))
	var asset_texture = _object_texture_for_asset(asset_id)
	if asset_texture is Texture2D:
		var shows_color_cue_assist := bool(profile.get("color_cue_assist", false))
		_canvas_draw_texture_rect(
			asset_texture,
			profile.get("asset_rect", Rect2()),
			false,
			OBJECT_SPRITE_MEMORY_MODULATE if remembered else OBJECT_SPRITE_VISIBLE_MODULATE
		)
		if shows_color_cue_assist:
			_draw_town_owner_asset_mark(profile, owner)
		return
	var extent := float(profile.get("extent", 0.0))
	var pole_top: Vector2 = profile.get("pole_top", Vector2.ZERO)
	var pole_bottom: Vector2 = profile.get("pole_bottom", Vector2.ZERO)
	var shadow_offset: Vector2 = profile.get("shadow_offset", Vector2.ZERO)
	var cloth_points: PackedVector2Array = profile.get("cloth_points", PackedVector2Array())
	var shadow_points: PackedVector2Array = profile.get("shadow_points", PackedVector2Array())
	var outline_points := PackedVector2Array(cloth_points)
	if not cloth_points.is_empty():
		outline_points.append(cloth_points[0])
	_canvas_draw_line(
		pole_bottom + shadow_offset,
		pole_top + shadow_offset,
		Color(0.01, 0.012, 0.009, TOWN_OWNER_PENNANT_SHADOW_ALPHA),
		maxf(1.0, extent * 0.017)
	)
	_canvas_draw_colored_polygon(shadow_points, Color(0.01, 0.012, 0.009, TOWN_OWNER_PENNANT_SHADOW_ALPHA))
	_canvas_draw_line(pole_bottom, pole_top, profile.get("pole_color", Color.WHITE), maxf(1.2, extent * 0.015))
	_canvas_draw_colored_polygon(cloth_points, profile.get("cloth_color", Color.WHITE))
	_canvas_draw_polyline(outline_points, profile.get("outline_color", MARKER_OUTLINE_COLOR), maxf(1.0, extent * TOWN_OWNER_PENNANT_OUTLINE_WIDTH_FACTOR))
	var fold_line: PackedVector2Array = profile.get("fold_line", PackedVector2Array())
	if fold_line.size() == 2:
		_canvas_draw_line(fold_line[0], fold_line[1], profile.get("fold_color", MARKER_OUTLINE_COLOR), maxf(1.0, extent * 0.007))
	var highlight_line: PackedVector2Array = profile.get("highlight_line", PackedVector2Array())
	if highlight_line.size() == 2:
		_canvas_draw_line(highlight_line[0], highlight_line[1], profile.get("highlight_color", Color.WHITE), maxf(1.0, extent * 0.006))
	_canvas_draw_circle(pole_top, maxf(1.2, extent * 0.010), profile.get("pole_color", Color.WHITE))
	if bool(profile.get("color_cue_assist", false)):
		_draw_town_owner_flag_mark(profile.get("mark_center", pole_top), extent, owner, profile.get("mark_color", MARKER_OUTLINE_COLOR))

func _draw_town_owner_asset_mark(profile: Dictionary, owner: String) -> void:
	_draw_town_owner_flag_mark(
		profile.get("asset_mark_center", Vector2.ZERO),
		float(profile.get("extent", 0.0)),
		owner,
		profile.get("mark_color", MARKER_OUTLINE_COLOR)
	)

func _town_owner_pennant_profile(
	rect: Rect2,
	color: Color,
	remembered: bool,
	owner: String,
	color_cue_assist: bool
) -> Dictionary:
	var extent := minf(rect.size.x, rect.size.y)
	var width := extent * TOWN_OWNER_PENNANT_WIDTH_FACTOR
	var height := extent * TOWN_OWNER_PENNANT_HEIGHT_FACTOR
	var pole_top := rect.position + rect.size * Vector2(0.755, 0.205)
	var pole_bottom := pole_top + Vector2(0.0, extent * TOWN_OWNER_PENNANT_POLE_HEIGHT_FACTOR)
	var cloth_points := PackedVector2Array()
	var shape_id := "compact_forked"
	if not color_cue_assist:
		cloth_points = PackedVector2Array([
			pole_top,
			pole_top + Vector2(width, height * 0.16),
			pole_top + Vector2(width * 0.76, height * 0.50),
			pole_top + Vector2(width, height * 0.84),
			pole_top + Vector2(0.0, height),
		])
	elif owner == "player":
		shape_id = "compact_square_folded"
		cloth_points = PackedVector2Array([
			pole_top,
			pole_top + Vector2(width, height * 0.10),
			pole_top + Vector2(width * 0.88, height * 0.50),
			pole_top + Vector2(width, height * 0.90),
			pole_top + Vector2(0.0, height),
		])
	elif owner == "enemy":
		shape_id = "compact_tapered"
		cloth_points = PackedVector2Array([
			pole_top,
			pole_top + Vector2(width, height * 0.50),
			pole_top + Vector2(0.0, height),
		])
	else:
		shape_id = "compact_diamond"
		cloth_points = PackedVector2Array([
			pole_top + Vector2(0.0, height * 0.50),
			pole_top + Vector2(width * 0.50, 0.0),
			pole_top + Vector2(width, height * 0.50),
			pole_top + Vector2(width * 0.50, height),
		])
	var shadow_offset := Vector2.ONE * maxf(1.0, extent * TOWN_OWNER_PENNANT_SHADOW_OFFSET_FACTOR)
	var shadow_points := PackedVector2Array()
	for point in cloth_points:
		shadow_points.append(point + shadow_offset)
	var source_color := _remembered_marker_color(color) if remembered else color
	var cloth_alpha := TOWN_OWNER_PENNANT_MEMORY_ALPHA if remembered else TOWN_OWNER_PENNANT_CLOTH_ALPHA
	var cloth_color := Color(source_color.r, source_color.g, source_color.b, minf(source_color.a, cloth_alpha))
	var outline_color := MEMORY_OBJECT_OUTLINE if remembered else MARKER_OUTLINE_COLOR
	var pole_color := MEMORY_OBJECT_OUTLINE if remembered else Color(0.92, 0.84, 0.62, 0.88)
	var fold_color := Color(outline_color.r, outline_color.g, outline_color.b, minf(outline_color.a, TOWN_OWNER_PENNANT_FOLD_ALPHA))
	var highlight_source := cloth_color.lightened(0.42)
	var highlight_color := Color(highlight_source.r, highlight_source.g, highlight_source.b, TOWN_OWNER_PENNANT_HIGHLIGHT_ALPHA if not remembered else TOWN_OWNER_PENNANT_HIGHLIGHT_ALPHA * 0.70)
	var asset_extent := extent * TOWN_OWNER_PENNANT_ASSET_EXTENT_FACTOR
	var asset_position := rect.position + Vector2(rect.size.x * 0.63, rect.size.y * 0.04)
	asset_position.x = minf(asset_position.x, rect.end.x - asset_extent)
	asset_position.y = minf(asset_position.y, rect.end.y - asset_extent)
	var asset_rect := Rect2(
		asset_position,
		Vector2(asset_extent, asset_extent)
	)
	return {
		"model": TOWN_OWNER_PENNANT_MODEL,
		"owner": owner,
		"remembered": remembered,
		"color_cue_assist": color_cue_assist,
		"shape_id": shape_id,
		"asset_id": _ownership_pennant_asset_id(owner),
		"asset_rect": asset_rect,
		"asset_mark_center": asset_rect.position + asset_rect.size * Vector2(0.60, 0.30),
		"extent": extent,
		"pole_top": pole_top,
		"pole_bottom": pole_bottom,
		"pole_color": pole_color,
		"cloth_points": cloth_points,
		"shadow_points": shadow_points,
		"cloth_bounds": _points_bounds(cloth_points),
		"cloth_color": cloth_color,
		"outline_color": outline_color,
		"shadow_offset": shadow_offset,
		"fold_line": PackedVector2Array([
			pole_top + Vector2(width * 0.08, height * 0.68),
			pole_top + Vector2(width * 0.70, height * 0.48),
		]),
		"fold_color": fold_color,
		"highlight_line": PackedVector2Array([
			pole_top + Vector2(width * 0.08, height * 0.18),
			pole_top + Vector2(width * 0.66, height * 0.27),
		]),
		"highlight_color": highlight_color,
		"mark_center": pole_top + Vector2(width * 0.48, height * 0.50),
		"mark_color": outline_color,
		"single_pass_draw_count": 1,
		"cloth_layer_count": 1,
		"width_factor": TOWN_OWNER_PENNANT_WIDTH_FACTOR,
		"height_factor": TOWN_OWNER_PENNANT_HEIGHT_FACTOR,
		"legacy_width_factor": TOWN_OWNER_PENNANT_LEGACY_WIDTH_FACTOR,
		"legacy_height_factor": TOWN_OWNER_PENNANT_LEGACY_HEIGHT_FACTOR,
		"painted_area_ratio_to_legacy": (TOWN_OWNER_PENNANT_WIDTH_FACTOR * TOWN_OWNER_PENNANT_HEIGHT_FACTOR) / (TOWN_OWNER_PENNANT_LEGACY_WIDTH_FACTOR * TOWN_OWNER_PENNANT_LEGACY_HEIGHT_FACTOR),
	}

func _ownership_pennant_asset_id(owner: String) -> String:
	return String(_ownership_pennant_asset_ids.get(owner, ""))

func _points_bounds(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	var min_position := points[0]
	var max_position := points[0]
	for point in points:
		min_position.x = minf(min_position.x, point.x)
		min_position.y = minf(min_position.y, point.y)
		max_position.x = maxf(max_position.x, point.x)
		max_position.y = maxf(max_position.y, point.y)
	return Rect2(min_position, max_position - min_position)

func _draw_town_owner_flag_mark(center: Vector2, extent: float, owner: String, color: Color) -> void:
	var mark_radius := maxf(1.8, extent * 0.022)
	if owner == "player":
		_canvas_draw_circle(center, mark_radius, color)
	elif owner == "enemy":
		_canvas_draw_line(center + Vector2(-mark_radius, -mark_radius), center + Vector2(mark_radius, mark_radius), color, maxf(1.0, extent * 0.012))
		_canvas_draw_line(center + Vector2(mark_radius, -mark_radius), center + Vector2(-mark_radius, mark_radius), color, maxf(1.0, extent * 0.012))
	else:
		_canvas_draw_line(center + Vector2(-mark_radius, 0.0), center + Vector2(mark_radius, 0.0), color, maxf(1.0, extent * 0.012))

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
	_draw_town_owner_pennant(rect, color, remembered, _town_owner_id(_town_at(tile)))
	_draw_town_front_contact(anchor, remembered)
	_draw_town_entry_approach(entry_rect, color, remembered)

func _draw_town_footprint_underlay(_tile: Vector2i, _rect: Rect2) -> void:
	return

func _draw_town_grounding_anchor(rect: Rect2, remembered: bool, tile: Vector2i) -> Dictionary:
	var extent := minf(rect.size.x, rect.size.y)
	var center := rect.position + rect.size * Vector2(0.50, 0.958)
	var radii := Vector2(rect.size.x * 0.25, maxf(2.0, rect.size.y * 0.030))
	_draw_town_ground_scuffs(tile, center, radii, remembered, extent)
	return {
		"center": center,
		"radii": radii,
		"extent": extent,
		"footprint": TOWN_VISUAL_FOOTPRINT,
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

func _draw_hero_marker(rect: Rect2, tile: Vector2i, show_reserve_count: bool = true, hero_override: Dictionary = {}) -> void:
	var hero := hero_override if not hero_override.is_empty() else _hero_presentation_entry(tile)
	var hero_rect := _hero_draw_rect(rect, tile, hero_override.is_empty())
	if _draw_hero_sprite(hero, hero_rect, tile):
		_draw_hero_reserve_badge(rect, tile, show_reserve_count)
		return
	var anchor := _draw_hero_grounding_anchor(hero_rect, tile)
	_draw_hero_command_pennant(_hero_command_pennant_profile(hero_rect, bool(hero.get("is_active", false))))
	var extent := minf(hero_rect.size.x, hero_rect.size.y)
	var base_radius := maxf(5.0, extent * HERO_MARKER_RADIUS)
	var ground_center: Vector2 = anchor.get("center", hero_rect.get_center())
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
	_canvas_draw_line(ground_center + Vector2(base_radius * 0.78, -extent * 0.02), figure_center + Vector2(base_radius * 0.78, -hero_rect.size.y * 0.36), MARKER_OUTLINE_COLOR, maxf(3.0, extent * 0.040))
	_canvas_draw_line(ground_center + Vector2(base_radius * 0.78, -extent * 0.02), figure_center + Vector2(base_radius * 0.78, -hero_rect.size.y * 0.36), HERO_RING_COLOR, maxf(1.9, extent * 0.026))
	var banner = PackedVector2Array([
		figure_center + Vector2(base_radius * 0.78, -hero_rect.size.y * 0.36),
		figure_center + Vector2(base_radius * 0.78 + hero_rect.size.x * 0.16, -hero_rect.size.y * 0.30),
		figure_center + Vector2(base_radius * 0.78, -hero_rect.size.y * 0.20),
	])
	_canvas_draw_colored_polygon(banner, Color(0.95, 0.73, 0.25, 0.95))
	_canvas_draw_polyline(PackedVector2Array([banner[0], banner[1], banner[2], banner[0]]), MARKER_OUTLINE_COLOR, maxf(1.4, extent * 0.020))
	_draw_hero_foreground_contact(anchor)

	_draw_hero_reserve_badge(rect, tile, show_reserve_count)

func _draw_hero_sprite(hero: Dictionary, rect: Rect2, tile: Vector2i) -> bool:
	var texture = _object_texture_for_asset(_hero_sprite_asset_id(hero))
	if not (texture is Texture2D):
		return false
	var anchor := _draw_hero_grounding_anchor(rect, tile)
	var extent := minf(rect.size.x, rect.size.y)
	var ground_center: Vector2 = anchor.get("center", rect.get_center())
	var sprite_factor := HERO_TOWN_FOOTPRINT_VISITOR_SPRITE_EXTENT_FACTOR if not _town_presentation_at(tile).is_empty() else HERO_FIELD_SPRITE_EXTENT_FACTOR
	var sprite_extent := maxf(16.0, extent * sprite_factor)
	var sprite_center := ground_center + Vector2(0.0, -extent * HERO_SPRITE_LIFT_FACTOR)
	var sprite_rect := Rect2(sprite_center - Vector2(sprite_extent, sprite_extent) * 0.5, Vector2(sprite_extent, sprite_extent))
	_draw_hero_command_pennant(_hero_command_pennant_profile(rect, bool(hero.get("is_active", false))))
	_draw_sprite_silhouette_outline(
		texture,
		sprite_rect,
		HERO_SPRITE_SILHOUETTE_COLOR,
		maxf(HERO_SPRITE_SILHOUETTE_MIN_PX, extent * HERO_SPRITE_SILHOUETTE_WIDTH_FACTOR)
	)
	_canvas_draw_texture_rect(texture, sprite_rect, false, OBJECT_SPRITE_VISIBLE_MODULATE)
	_draw_hero_foreground_contact(anchor)
	return true

func _hero_command_pennant_profile(rect: Rect2, active: bool) -> Dictionary:
	var extent := minf(rect.size.x, rect.size.y)
	var width := extent * HERO_COMMAND_PENNANT_WIDTH_FACTOR
	var height := extent * HERO_COMMAND_PENNANT_HEIGHT_FACTOR
	var pole_top := rect.position + rect.size * Vector2(0.80, 0.14)
	var pole_bottom := pole_top + Vector2(0.0, extent * HERO_COMMAND_PENNANT_POLE_HEIGHT_FACTOR)
	var cloth_points := PackedVector2Array([
		pole_top,
		pole_top + Vector2(-width, height * 0.10),
		pole_top + Vector2(-width * (0.78 if active else 0.64), height * 0.52),
		pole_top + Vector2(-width, height * 0.90),
		pole_top + Vector2(0.0, height),
	])
	var shadow_offset := Vector2.ONE * maxf(1.0, extent * 0.012)
	var shadow_points := PackedVector2Array()
	for point in cloth_points:
		shadow_points.append(point + shadow_offset)
	var owner_color := FrontierVisualKitScript.semantic_color("player", PLAYER_TOWN_COLOR)
	var cloth_alpha := HERO_COMMAND_PENNANT_ALPHA if active else HERO_COMMAND_PENNANT_ALPHA * 0.82
	var asset_extent := extent * HERO_COMMAND_PENNANT_ASSET_EXTENT_FACTOR
	var asset_rect := Rect2(
		rect.position + rect.size * Vector2(0.38, 0.04),
		Vector2(asset_extent, asset_extent)
	)
	return {
		"model": HERO_COMMAND_PENNANT_MODEL,
		"active": active,
		"shape_id": "active_square_fold" if active else "reserve_swallowtail",
		"asset_id": _ownership_pennant_asset_id("player"),
		"asset_rect": asset_rect,
		"extent": extent,
		"pole_top": pole_top,
		"pole_bottom": pole_bottom,
		"cloth_points": cloth_points,
		"shadow_points": shadow_points,
		"cloth_color": Color(owner_color.r, owner_color.g, owner_color.b, cloth_alpha),
		"outline_color": MARKER_OUTLINE_COLOR,
		"pole_color": Color(0.94, 0.86, 0.64, 0.96),
		"fold_line": PackedVector2Array([
			pole_top + Vector2(-width * 0.08, height * 0.72),
			pole_top + Vector2(-width * 0.68, height * 0.48),
		]),
		"highlight_line": PackedVector2Array([
			pole_top + Vector2(-width * 0.08, height * 0.20),
			pole_top + Vector2(-width * 0.66, height * 0.28),
		]),
		"width_factor": HERO_COMMAND_PENNANT_WIDTH_FACTOR,
		"height_factor": HERO_COMMAND_PENNANT_HEIGHT_FACTOR,
		"pole_height_factor": HERO_COMMAND_PENNANT_POLE_HEIGHT_FACTOR,
	}

func _draw_hero_command_pennant(profile: Dictionary) -> void:
	if profile.is_empty():
		return
	var asset_id := String(profile.get("asset_id", ""))
	var asset_texture = _object_texture_for_asset(asset_id)
	if asset_texture is Texture2D:
		var modulate := OBJECT_SPRITE_VISIBLE_MODULATE
		if not bool(profile.get("active", false)):
			modulate.a *= 0.82
		_canvas_draw_texture_rect(asset_texture, profile.get("asset_rect", Rect2()), false, modulate)
		return
	var extent := float(profile.get("extent", 0.0))
	var pole_top: Vector2 = profile.get("pole_top", Vector2.ZERO)
	var pole_bottom: Vector2 = profile.get("pole_bottom", Vector2.ZERO)
	var cloth_points: PackedVector2Array = profile.get("cloth_points", PackedVector2Array())
	var shadow_points: PackedVector2Array = profile.get("shadow_points", PackedVector2Array())
	if extent <= 0.0 or cloth_points.size() < 3:
		return
	_canvas_draw_line(pole_top, pole_bottom, MARKER_OUTLINE_COLOR, maxf(2.0, extent * 0.030))
	_canvas_draw_line(pole_top, pole_bottom, profile.get("pole_color", Color.WHITE), maxf(1.0, extent * 0.014))
	_canvas_draw_colored_polygon(shadow_points, Color(0.01, 0.012, 0.009, 0.46))
	_canvas_draw_colored_polygon(cloth_points, profile.get("cloth_color", PLAYER_TOWN_COLOR))
	var outline_points := PackedVector2Array(cloth_points)
	outline_points.append(cloth_points[0])
	_canvas_draw_polyline(outline_points, profile.get("outline_color", MARKER_OUTLINE_COLOR), maxf(1.25, extent * 0.020))
	var fold_line: PackedVector2Array = profile.get("fold_line", PackedVector2Array())
	if fold_line.size() == 2:
		_canvas_draw_line(fold_line[0], fold_line[1], Color(0.05, 0.04, 0.02, 0.46), maxf(1.0, extent * 0.010))
	var highlight_line: PackedVector2Array = profile.get("highlight_line", PackedVector2Array())
	if highlight_line.size() == 2:
		_canvas_draw_line(highlight_line[0], highlight_line[1], Color(1.0, 0.94, 0.70, 0.58), maxf(1.0, extent * 0.008))
	_canvas_draw_circle(pole_top, maxf(1.2, extent * 0.016), profile.get("pole_color", Color.WHITE))

func _hero_command_pennant_validation_payload(profile: Dictionary, containing_rect: Rect2) -> Dictionary:
	var cloth_points: PackedVector2Array = profile.get("cloth_points", PackedVector2Array())
	var shadow_points: PackedVector2Array = profile.get("shadow_points", PackedVector2Array())
	return {
		"model": String(profile.get("model", "")),
		"active": bool(profile.get("active", false)),
		"shape_id": String(profile.get("shape_id", "")),
		"asset_id": String(profile.get("asset_id", "")),
		"asset_path": String(_object_asset_paths.get(String(profile.get("asset_id", "")), "")),
		"asset_loaded": _object_texture_for_asset(String(profile.get("asset_id", ""))) is Texture2D,
		"asset_rect": _rect_payload(profile.get("asset_rect", Rect2())),
		"asset_contained": containing_rect.encloses(profile.get("asset_rect", Rect2())),
		"procedural_fallback": not (_object_texture_for_asset(String(profile.get("asset_id", ""))) is Texture2D),
		"cloth_points": _vector2_array_payload(cloth_points),
		"shadow_points": _vector2_array_payload(shadow_points),
		"pole_top": _vector2_payload(profile.get("pole_top", Vector2.ZERO)),
		"pole_bottom": _vector2_payload(profile.get("pole_bottom", Vector2.ZERO)),
		"cloth_color": _color_payload(profile.get("cloth_color", Color.TRANSPARENT)),
		"width_factor": float(profile.get("width_factor", 0.0)),
		"height_factor": float(profile.get("height_factor", 0.0)),
		"pole_height_factor": float(profile.get("pole_height_factor", 0.0)),
		"cloth_contained": containing_rect.encloses(_points_bounds(cloth_points)),
		"shadow_contained": containing_rect.encloses(_points_bounds(shadow_points)),
		"pole_contained": containing_rect.has_point(profile.get("pole_top", Vector2.ZERO)) and containing_rect.has_point(profile.get("pole_bottom", Vector2.ZERO)),
	}

func _hero_draw_rect(rect: Rect2, tile: Vector2i, allow_town_footprint_layout: bool) -> Rect2:
	if not allow_town_footprint_layout or _town_presentation_at(tile).is_empty():
		return rect
	var extent := minf(rect.size.x, rect.size.y)
	var visitor_extent := extent * HERO_TOWN_FOOTPRINT_VISITOR_RECT_EXTENT_FACTOR
	var center := rect.position + rect.size * Vector2(0.50, HERO_TOWN_FOOTPRINT_VISITOR_RECT_CENTER_Y_FACTOR)
	return Rect2(center - Vector2(visitor_extent, visitor_extent) * 0.5, Vector2(visitor_extent, visitor_extent))

func _hero_draw_layout_payload(rect: Rect2, tile: Vector2i, allow_town_footprint_layout: bool) -> Dictionary:
	var hero_rect := _hero_draw_rect(rect, tile, allow_town_footprint_layout)
	var tile_extent := minf(rect.size.x, rect.size.y)
	var hero_extent := minf(hero_rect.size.x, hero_rect.size.y)
	var ground_center := hero_rect.position + hero_rect.size * Vector2(0.50, HERO_GROUND_ANCHOR_Y_FACTOR)
	var uses_town_footprint_layout := allow_town_footprint_layout and not _town_presentation_at(tile).is_empty()
	var sprite_factor := HERO_TOWN_FOOTPRINT_VISITOR_SPRITE_EXTENT_FACTOR if uses_town_footprint_layout else HERO_FIELD_SPRITE_EXTENT_FACTOR
	var sprite_extent := maxf(16.0, hero_extent * sprite_factor)
	var sprite_center := ground_center + Vector2(0.0, -hero_extent * HERO_SPRITE_LIFT_FACTOR)
	var sprite_rect := Rect2(sprite_center - Vector2(sprite_extent, sprite_extent) * 0.5, Vector2(sprite_extent, sprite_extent))
	var silhouette_width := maxf(HERO_SPRITE_SILHOUETTE_MIN_PX, hero_extent * HERO_SPRITE_SILHOUETTE_WIDTH_FACTOR)
	var hero := _hero_presentation_entry(tile)
	var command_pennant := _hero_command_pennant_validation_payload(_hero_command_pennant_profile(hero_rect, bool(hero.get("is_active", false))), rect)
	return {
		"mode": HERO_TOWN_FOOTPRINT_LAYOUT_MODE if uses_town_footprint_layout else HERO_FIELD_LAYOUT_MODE,
		"town_footprint_colocated": uses_town_footprint_layout,
		"hero_rect": _rect_payload(hero_rect),
		"sprite_rect": _rect_payload(sprite_rect),
		"hero_rect_extent_fraction": hero_extent / tile_extent if tile_extent > 0.0 else 0.0,
		"sprite_extent_fraction": sprite_extent / tile_extent if tile_extent > 0.0 else 0.0,
		"sprite_contained_in_tile": rect.encloses(sprite_rect),
		"sprite_silhouette_model": WORLD_SPRITE_SILHOUETTE_MODEL,
		"sprite_silhouette_width_px": silhouette_width,
		"sprite_silhouette_contained_in_tile": rect.encloses(sprite_rect.grow(silhouette_width)),
		"command_pennant": command_pennant,
		"ground_anchor_y_fraction": (ground_center.y - rect.position.y) / rect.size.y if rect.size.y > 0.0 else 0.0,
	}

func _draw_hero_reserve_badge(rect: Rect2, tile: Vector2i, show_reserve_count: bool) -> void:
	var reserve_count = _reserve_hero_count(tile) if show_reserve_count else 0
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
	var center := rect.position + rect.size * Vector2(0.50, HERO_GROUND_ANCHOR_Y_FACTOR)
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

func _town_selection_visual_profile(rect: Rect2) -> Dictionary:
	var extent := minf(rect.size.x, rect.size.y)
	var perimeter_inset := maxf(4.0, extent * TOWN_SELECTION_PERIMETER_INSET_FACTOR)
	var corner_length := maxf(10.0, extent * TOWN_SELECTION_CORNER_LENGTH_FACTOR)
	var corner_width := maxf(1.5, extent * TOWN_SELECTION_CORNER_WIDTH_FACTOR)
	var midpoint_length := maxf(6.0, extent * TOWN_SELECTION_MIDPOINT_LENGTH_FACTOR)
	var midpoint_width := maxf(1.25, extent * TOWN_SELECTION_MIDPOINT_WIDTH_FACTOR)
	return {
		"model": TOWN_SELECTION_VISUAL_MODEL,
		"perimeter_rect": rect.grow(-perimeter_inset),
		"perimeter_inset_px": perimeter_inset,
		"corner_alpha": TOWN_SELECTION_CORNER_ALPHA,
		"corner_length_px": corner_length,
		"corner_width_px": corner_width,
		"midpoint_alpha": TOWN_SELECTION_MIDPOINT_ALPHA,
		"midpoint_length_px": midpoint_length,
		"midpoint_width_px": midpoint_width,
		"continuous_outline": false,
		"interior_fill_alpha": 0.0,
	}

func _draw_town_selection_perimeter(rect: Rect2) -> void:
	var profile := _town_selection_visual_profile(rect)
	var perimeter_rect: Rect2 = profile.get("perimeter_rect", rect)
	var corner_length := float(profile.get("corner_length_px", 10.0))
	var corner_width := float(profile.get("corner_width_px", 1.5))
	var midpoint_length := float(profile.get("midpoint_length_px", 6.0))
	var midpoint_width := float(profile.get("midpoint_width_px", 1.25))
	var corner_color := Color(SELECTION_COLOR.r, SELECTION_COLOR.g, SELECTION_COLOR.b, TOWN_SELECTION_CORNER_ALPHA)
	var midpoint_color := Color(SELECTION_COLOR.r, SELECTION_COLOR.g, SELECTION_COLOR.b, TOWN_SELECTION_MIDPOINT_ALPHA)
	_draw_cartographic_selection_corners(perimeter_rect, corner_color, corner_width, corner_length)
	_draw_cartographic_selection_midpoints(perimeter_rect, midpoint_color, midpoint_width, midpoint_length)

func _tile_selection_visual_profile(rect: Rect2) -> Dictionary:
	var extent := minf(rect.size.x, rect.size.y)
	var perimeter_inset := maxf(4.0, extent * TILE_SELECTION_PERIMETER_INSET_FACTOR)
	var corner_length := maxf(8.0, extent * TILE_SELECTION_CORNER_LENGTH_FACTOR)
	var corner_width := maxf(1.5, extent * TILE_SELECTION_CORNER_WIDTH_FACTOR)
	var midpoint_length := maxf(5.0, extent * TILE_SELECTION_MIDPOINT_LENGTH_FACTOR)
	var midpoint_width := maxf(1.25, extent * TILE_SELECTION_MIDPOINT_WIDTH_FACTOR)
	return {
		"model": TILE_SELECTION_VISUAL_MODEL,
		"perimeter_rect": rect.grow(-perimeter_inset),
		"perimeter_inset_px": perimeter_inset,
		"corner_alpha": TILE_SELECTION_CORNER_ALPHA,
		"corner_length_px": corner_length,
		"corner_width_px": corner_width,
		"midpoint_alpha": TILE_SELECTION_MIDPOINT_ALPHA,
		"midpoint_length_px": midpoint_length,
		"midpoint_width_px": midpoint_width,
		"continuous_outline": false,
		"interior_fill_alpha": 0.0,
	}

func _draw_tile_selection_reticle(rect: Rect2) -> void:
	var profile := _tile_selection_visual_profile(rect)
	var perimeter_rect: Rect2 = profile.get("perimeter_rect", rect)
	var corner_color := Color(SELECTION_COLOR.r, SELECTION_COLOR.g, SELECTION_COLOR.b, TILE_SELECTION_CORNER_ALPHA)
	var midpoint_color := Color(SELECTION_COLOR.r, SELECTION_COLOR.g, SELECTION_COLOR.b, TILE_SELECTION_MIDPOINT_ALPHA)
	_draw_cartographic_selection_corners(perimeter_rect, corner_color, float(profile.get("corner_width_px", 1.5)), float(profile.get("corner_length_px", 8.0)))
	_draw_cartographic_selection_midpoints(perimeter_rect, midpoint_color, float(profile.get("midpoint_width_px", 1.25)), float(profile.get("midpoint_length_px", 5.0)))

func _draw_cartographic_selection_corners(rect: Rect2, color: Color, width: float, length: float) -> void:
	var top_left := rect.position
	var top_right := Vector2(rect.end.x, rect.position.y)
	var bottom_left := Vector2(rect.position.x, rect.end.y)
	var bottom_right := rect.end
	_canvas_draw_line(top_left, top_left + Vector2(length, 0.0), color, width)
	_canvas_draw_line(top_left, top_left + Vector2(0.0, length), color, width)
	_canvas_draw_line(top_right, top_right + Vector2(-length, 0.0), color, width)
	_canvas_draw_line(top_right, top_right + Vector2(0.0, length), color, width)
	_canvas_draw_line(bottom_left, bottom_left + Vector2(length, 0.0), color, width)
	_canvas_draw_line(bottom_left, bottom_left + Vector2(0.0, -length), color, width)
	_canvas_draw_line(bottom_right, bottom_right + Vector2(-length, 0.0), color, width)
	_canvas_draw_line(bottom_right, bottom_right + Vector2(0.0, -length), color, width)

func _draw_cartographic_selection_midpoints(rect: Rect2, color: Color, width: float, length: float) -> void:
	var half_length := length * 0.5
	var top_center := Vector2(rect.get_center().x, rect.position.y)
	var bottom_center := Vector2(rect.get_center().x, rect.end.y)
	var left_center := Vector2(rect.position.x, rect.get_center().y)
	var right_center := Vector2(rect.end.x, rect.get_center().y)
	_canvas_draw_line(top_center - Vector2(half_length, 0.0), top_center + Vector2(half_length, 0.0), color, width)
	_canvas_draw_line(bottom_center - Vector2(half_length, 0.0), bottom_center + Vector2(half_length, 0.0), color, width)
	_canvas_draw_line(left_center - Vector2(0.0, half_length), left_center + Vector2(0.0, half_length), color, width)
	_canvas_draw_line(right_center - Vector2(0.0, half_length), right_center + Vector2(0.0, half_length), color, width)

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

func _resource_draw_rect(node: Dictionary, anchor_rect: Rect2, anchor_tile: Vector2i) -> Rect2:
	var footprint_rect := _resource_footprint_rect(node, anchor_rect, anchor_tile)
	var town_presentation := _town_presentation_at(anchor_tile)
	if town_presentation.is_empty():
		return footprint_rect
	var compact_size := footprint_rect.size * TOWN_ADJUNCT_RESOURCE_EXTENT_FACTOR
	var cell_offset: Vector2i = town_presentation.get("cell_offset", Vector2i.ZERO)
	var anchor_right := float(cell_offset.x) + 0.5 >= float(TOWN_PRESENTATION_FOOTPRINT.x) * 0.5
	var anchor_bottom := float(cell_offset.y) + 0.5 >= float(TOWN_PRESENTATION_FOOTPRINT.y) * 0.5
	var compact_position := footprint_rect.position + Vector2(
		footprint_rect.size.x - compact_size.x if anchor_right else 0.0,
		footprint_rect.size.y - compact_size.y if anchor_bottom else 0.0
	)
	return Rect2(compact_position, compact_size)

func _resource_draw_layout_payload(node: Dictionary, anchor_rect: Rect2, anchor_tile: Vector2i) -> Dictionary:
	if node.is_empty():
		return {}
	var footprint_rect := _resource_footprint_rect(node, anchor_rect, anchor_tile)
	var draw_rect := _resource_draw_rect(node, anchor_rect, anchor_tile)
	var town_presentation := _town_presentation_at(anchor_tile)
	var colocated := not town_presentation.is_empty()
	var cell_offset: Vector2i = town_presentation.get("cell_offset", Vector2i.ZERO) if colocated else Vector2i.ZERO
	var anchor_right := colocated and float(cell_offset.x) + 0.5 >= float(TOWN_PRESENTATION_FOOTPRINT.x) * 0.5
	var anchor_bottom := colocated and float(cell_offset.y) + 0.5 >= float(TOWN_PRESENTATION_FOOTPRINT.y) * 0.5
	return {
		"model": TOWN_ADJUNCT_RESOURCE_LAYOUT_MODEL if colocated else "ordinary_resource_footprint",
		"town_footprint_colocated": colocated,
		"extent_factor": TOWN_ADJUNCT_RESOURCE_EXTENT_FACTOR if colocated else 1.0,
		"visible_extent_cap_tiles": TOWN_ADJUNCT_RESOURCE_VISIBLE_EXTENT_CAP_TILES if colocated else 0.0,
		"edge_anchor": ("bottom" if anchor_bottom else "top") + "_" + ("right" if anchor_right else "left") if colocated else "none",
		"cell_offset": {"x": cell_offset.x, "y": cell_offset.y},
		"footprint_rect": _rect_payload(footprint_rect),
		"draw_rect": _rect_payload(draw_rect),
		"contained_in_footprint_tile": footprint_rect.encloses(draw_rect),
	}

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
		"blocker":
			return maxf(fallback, 0.34)
		"decoration":
			return maxf(fallback, 0.28)
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
		"blocker":
			half_width = 0.43
			half_height = 0.080
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
		"blocker":
			half_width *= 1.02
			half_height *= 1.05
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
	var scale_class := _semantic_visual_scale_class(profile)
	var base := OBJECT_DEFAULT_VISIBLE_EXTENT_TILES
	match scale_class:
		"handheld_artifact":
			base = OBJECT_HANDHELD_ARTIFACT_VISIBLE_EXTENT_TILES
		"loose_pickup":
			base = OBJECT_LOOSE_PICKUP_VISIBLE_EXTENT_TILES
		"encounter":
			base = OBJECT_ENCOUNTER_VISIBLE_EXTENT_TILES
		"durable_structure":
			base = OBJECT_DURABLE_VISIBLE_EXTENT_TILES
		"waypoint":
			base = OBJECT_WAYPOINT_VISIBLE_EXTENT_TILES
		"landmark":
			base = OBJECT_LANDMARK_VISIBLE_EXTENT_TILES
		"terrain_blocker":
			base = OBJECT_BLOCKER_VISIBLE_EXTENT_TILES
		"ground_detail":
			base = OBJECT_DECORATION_VISIBLE_EXTENT_TILES
		_:
			base = OBJECT_DEFAULT_VISIBLE_EXTENT_TILES
	if scale_class in ["durable_structure", "waypoint", "landmark", "terrain_blocker"]:
		base += float(maxi(footprint.x - 1, 0)) * 0.06
		base += float(maxi(footprint.y - 1, 0)) * 0.03
	return clampf(
		base,
		minf(OBJECT_DECORATION_VISIBLE_EXTENT_TILES, OBJECT_HANDHELD_ARTIFACT_VISIBLE_EXTENT_TILES),
		maxf(OBJECT_LANDMARK_VISIBLE_EXTENT_TILES, OBJECT_BLOCKER_VISIBLE_EXTENT_TILES)
	)

func _semantic_visual_scale_class(profile: Dictionary) -> String:
	var family := String(profile.get("family", "pickup")).strip_edges()
	var primary_class := String(profile.get("primary_class", "")).strip_edges()
	match family:
		"artifact":
			return "handheld_artifact"
		"pickup":
			return "loose_pickup"
		"encounter", "neutral_encounter":
			return "encounter"
		"neutral_dwelling", "mine", "repeatable_service", "guarded_reward_site", "support_producer", "staged_resource_front", "faction_outpost":
			return "durable_structure"
		"scouting_structure", "transit_object", "frontier_shrine", "sign_waypoint", "shrine":
			return "waypoint"
		"scenario_objective", "faction_landmark":
			return "landmark"
		"blocker":
			return "terrain_blocker"
		"decoration":
			return "ground_detail"
	if primary_class in ["persistent_economy_site", "neutral_dwelling", "interactable_site"]:
		return "durable_structure"
	if primary_class in ["transit_route_object", "scouting_structure"]:
		return "waypoint"
	if primary_class in ["scenario_objective", "faction_landmark"]:
		return "landmark"
	return "map_object"

func _object_lift_fraction(family: String, footprint: Vector2i) -> float:
	var lift := 0.05
	match family:
		"neutral_dwelling", "mine", "repeatable_service", "guarded_reward_site":
			lift = 0.08
		"scouting_structure", "transit_object":
			lift = 0.10
		"blocker":
			lift = 0.07
		"decoration":
			lift = 0.03
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
		var fit_extent := _uncapped_whole_map_fit_tile_extent(viewport_size)
		return clampf(fit_extent, minimum_tile_extent, maxf(minimum_tile_extent, MAX_SMALL_MAP_FIT_TILE_EXTENT))
	var visible_tile_span := _active_visible_tile_span()
	var visible_tile_area := visible_tile_span * visible_tile_span
	var tactical_extent: float = floor(sqrt(max(viewport_size.x * viewport_size.y, 1.0) / maxf(visible_tile_area, 1.0)))
	return max(tactical_extent, minimum_tile_extent)

func _uncapped_whole_map_fit_tile_extent(viewport_size: Vector2) -> float:
	return floor(
		min(
			viewport_size.x / float(max(_map_size.x, 1)),
			viewport_size.y / float(max(_map_size.y, 1))
		)
	)

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

func focus_on_tile(tile: Vector2i) -> bool:
	if tile.x < 0 or tile.y < 0 or tile.x >= _map_size.x or tile.y >= _map_size.y:
		return false
	if not _can_pan_camera():
		return false
	_ensure_camera_state()
	return _set_camera_center(Vector2(float(tile.x), float(tile.y)), true)

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

func _small_map_cartographic_matte_gutters(viewport_rect: Rect2, board_rect: Rect2) -> Dictionary:
	return {
		"left": maxf(board_rect.position.x - viewport_rect.position.x, 0.0),
		"top": maxf(board_rect.position.y - viewport_rect.position.y, 0.0),
		"right": maxf(viewport_rect.end.x - board_rect.end.x, 0.0),
		"bottom": maxf(viewport_rect.end.y - board_rect.end.y, 0.0),
	}

func _small_map_cartographic_matte_active(viewport_rect: Rect2, board_rect: Rect2) -> bool:
	if not _should_fit_entire_map() or not viewport_rect.encloses(board_rect):
		return false
	var gutters := _small_map_cartographic_matte_gutters(viewport_rect, board_rect)
	return maxf(
		maxf(float(gutters.get("left", 0.0)), float(gutters.get("right", 0.0))),
		maxf(float(gutters.get("top", 0.0)), float(gutters.get("bottom", 0.0)))
	) >= SMALL_MAP_CARTOGRAPHIC_MATTE_MIN_GUTTER

func _draw_small_map_cartographic_matte(viewport_rect: Rect2, board_rect: Rect2) -> void:
	if not _small_map_cartographic_matte_active(viewport_rect, board_rect):
		return
	_canvas_draw_rect(viewport_rect, SMALL_MAP_CARTOGRAPHIC_MATTE_FILL, true)
	var column_count := int(ceil(viewport_rect.size.x / SMALL_MAP_CARTOGRAPHIC_MATTE_GRID_SPACING))
	var row_count := int(ceil(viewport_rect.size.y / SMALL_MAP_CARTOGRAPHIC_MATTE_GRID_SPACING))
	for column in range(1, column_count):
		var x := viewport_rect.position.x + float(column) * SMALL_MAP_CARTOGRAPHIC_MATTE_GRID_SPACING
		_canvas_draw_line(Vector2(x, viewport_rect.position.y), Vector2(x, viewport_rect.end.y), SMALL_MAP_CARTOGRAPHIC_MATTE_GRID, 1.0)
	for row in range(1, row_count):
		var y := viewport_rect.position.y + float(row) * SMALL_MAP_CARTOGRAPHIC_MATTE_GRID_SPACING
		_canvas_draw_line(Vector2(viewport_rect.position.x, y), Vector2(viewport_rect.end.x, y), SMALL_MAP_CARTOGRAPHIC_MATTE_GRID, 1.0)
	var contour_centers := [viewport_rect.position, viewport_rect.end, Vector2(viewport_rect.end.x, viewport_rect.position.y), Vector2(viewport_rect.position.x, viewport_rect.end.y)]
	for contour_center in contour_centers:
		for radius in [88.0, 146.0, 214.0]:
			_canvas_draw_circle(contour_center, radius, SMALL_MAP_CARTOGRAPHIC_MATTE_CONTOUR, false, 1.0, true)
	for shadow_extent in [SMALL_MAP_CARTOGRAPHIC_MATTE_BOARD_SHADOW_EXTENT, 9.0, 5.0]:
		var alpha := 0.07 if is_equal_approx(shadow_extent, SMALL_MAP_CARTOGRAPHIC_MATTE_BOARD_SHADOW_EXTENT) else (0.10 if is_equal_approx(shadow_extent, 9.0) else 0.16)
		_canvas_draw_rect(board_rect.grow(shadow_extent), Color(0.01, 0.015, 0.012, alpha), false, 2.0)
	_canvas_draw_rect(board_rect.grow(3.0), SMALL_MAP_CARTOGRAPHIC_MATTE_BOARD_EDGE, false, 1.5)
	_draw_small_map_board_corner_brackets(board_rect)
	_draw_small_map_compass_ornament(viewport_rect, board_rect)

func _draw_small_map_board_corner_brackets(board_rect: Rect2) -> void:
	var arm := 22.0
	var inset := 7.0
	var corners := [
		{"point": board_rect.position - Vector2(inset, inset), "x": 1.0, "y": 1.0},
		{"point": Vector2(board_rect.end.x + inset, board_rect.position.y - inset), "x": -1.0, "y": 1.0},
		{"point": Vector2(board_rect.position.x - inset, board_rect.end.y + inset), "x": 1.0, "y": -1.0},
		{"point": board_rect.end + Vector2(inset, inset), "x": -1.0, "y": -1.0},
	]
	for corner_value in corners:
		var corner: Dictionary = corner_value
		var point: Vector2 = corner.get("point", Vector2.ZERO)
		_canvas_draw_line(point, point + Vector2(float(corner.get("x", 0.0)) * arm, 0.0), SMALL_MAP_CARTOGRAPHIC_MATTE_ORNAMENT, 2.0, true)
		_canvas_draw_line(point, point + Vector2(0.0, float(corner.get("y", 0.0)) * arm), SMALL_MAP_CARTOGRAPHIC_MATTE_ORNAMENT, 2.0, true)

func _draw_small_map_compass_ornament(viewport_rect: Rect2, board_rect: Rect2) -> void:
	var gutters := _small_map_cartographic_matte_gutters(viewport_rect, board_rect)
	var left_gutter := float(gutters.get("left", 0.0))
	var right_gutter := float(gutters.get("right", 0.0))
	var use_left := left_gutter >= right_gutter
	var available_gutter := left_gutter if use_left else right_gutter
	if available_gutter < 132.0:
		return
	var center_x := viewport_rect.position.x + available_gutter * 0.42 if use_left else viewport_rect.end.x - available_gutter * 0.42
	var center := Vector2(center_x, viewport_rect.get_center().y)
	var radius := minf(34.0, available_gutter * 0.18)
	_canvas_draw_circle(center, radius, SMALL_MAP_CARTOGRAPHIC_MATTE_ORNAMENT, false, 1.5, true)
	_canvas_draw_circle(center, radius * 0.30, SMALL_MAP_CARTOGRAPHIC_MATTE_ORNAMENT, false, 1.0, true)
	_canvas_draw_line(center - Vector2(radius * 1.25, 0.0), center + Vector2(radius * 1.25, 0.0), SMALL_MAP_CARTOGRAPHIC_MATTE_ORNAMENT, 1.0, true)
	_canvas_draw_line(center - Vector2(0.0, radius * 1.25), center + Vector2(0.0, radius * 1.25), SMALL_MAP_CARTOGRAPHIC_MATTE_ORNAMENT, 1.0, true)
	var north := PackedVector2Array([
		center - Vector2(radius * 0.20, radius * 0.12),
		center + Vector2(0.0, -radius * 0.92),
		center + Vector2(radius * 0.20, -radius * 0.12),
	])
	_canvas_draw_colored_polygon(north, SMALL_MAP_CARTOGRAPHIC_MATTE_ORNAMENT)

func validation_reset_profile() -> void:
	_validation_profile.clear()

func validation_set_force_index_rebuild(enabled: bool) -> void:
	_validation_force_index_rebuild = enabled

func validation_set_path_detail_profile_enabled(enabled: bool) -> void:
	_path_detail_profile_enabled = enabled

func validation_profile_snapshot() -> Dictionary:
	return _validation_profile.duplicate(true)

func validation_placement_debug_overlay_snapshot() -> Dictionary:
	var payload := _placement_debug_overlay_payload()
	payload["enabled"] = _placement_debug_overlay_enabled
	payload["dynamic_reason"] = _dynamic_layer_reason
	return payload

func validation_generated_object_visual_summary() -> Dictionary:
	var expected_body_keys: Dictionary = {}
	var generated_record_count := 0
	var legacy_primary_marker_candidates: Array = []
	var indexed_legacy_primary_marker_count := 0
	if _session != null:
		for object_value in _session.overworld.get("map_objects", []):
			if not (object_value is Dictionary):
				continue
			var object: Dictionary = object_value
			if String(object.get("runtime_object_role", "")).strip_edges() != "decorative_blocker_sprite":
				continue
			var package_block_tiles = object.get("package_block_tiles", null)
			if not (package_block_tiles is Array) or package_block_tiles.is_empty():
				continue
			generated_record_count += 1
			var package_body_keys: Dictionary = {}
			for tile_value in _tiles_from_payloads(package_block_tiles):
				if tile_value is Vector2i:
					var tile: Vector2i = tile_value
					if tile.x >= 0 and tile.y >= 0 and tile.x < _map_size.x and tile.y < _map_size.y:
						var body_key := _tile_key(tile)
						expected_body_keys[body_key] = true
						package_body_keys[body_key] = true
			var primary_tile := Vector2i(int(object.get("x", -1)), int(object.get("y", -1)))
			var primary_key := _tile_key(primary_tile)
			if primary_tile.x >= 0 and primary_tile.y >= 0 and primary_tile.x < _map_size.x and primary_tile.y < _map_size.y \
				and not package_body_keys.has(primary_key):
				legacy_primary_marker_candidates.append({
					"placement_id": String(object.get("placement_id", "")),
					"h3m_def_name": String(object.get("h3m_def_name", "")),
					"x": primary_tile.x,
					"y": primary_tile.y,
				})
				var indexed_primary: Dictionary = _decorative_objects_by_tile.get(primary_key, {})
				if String(indexed_primary.get("placement_id", "")) == String(object.get("placement_id", "")):
					indexed_legacy_primary_marker_count += 1
	var indexed_keys: Array = _generated_decorative_bodies_by_tile.keys()
	indexed_keys.sort()
	var expected_keys: Array = expected_body_keys.keys()
	expected_keys.sort()
	var entries: Array = []
	var loaded_asset_count := 0
	var terrain_matched_asset_count := 0
	var visual_anchor_count := 0
	var visual_anchor_placement_ids: Dictionary = {}
	var collision_tile_count := 0
	var distinct_asset_ids: Dictionary = {}
	var h3m_def_asset_ids: Dictionary = {}
	var h3m_def_placement_ids: Dictionary = {}
	var motif_keys: Dictionary = {}
	var composition_key_count := 0
	var transformed_bounds_within_mass_margin_count := 0
	var scale_factor_min := GENERATED_DECORATIVE_BODY_SCALE_FACTOR_MAX
	var scale_factor_max := GENERATED_DECORATIVE_BODY_SCALE_FACTOR_MIN
	var offset_x_min := GENERATED_DECORATIVE_BODY_OFFSET_X_TILES
	var offset_x_max := -GENERATED_DECORATIVE_BODY_OFFSET_X_TILES
	var offset_y_min := GENERATED_DECORATIVE_BODY_OFFSET_Y_MAX_TILES
	var offset_y_max := GENERATED_DECORATIVE_BODY_OFFSET_Y_MIN_TILES
	for key_value in indexed_keys:
		var key := String(key_value)
		var presentation: Dictionary = _generated_decorative_bodies_by_tile.get(key, {})
		var visual_anchor := bool(presentation.get("generated_body_visual_anchor", false))
		var asset_id := String(presentation.get("overworld_sprite_asset_id", ""))
		var loaded := visual_anchor and asset_id != "" and _object_texture_for_asset(asset_id) is Texture2D
		var presentation_tile := Vector2i(int(presentation.get("x", -1)), int(presentation.get("y", -1)))
		var terrain_id := _terrain_at(presentation_tile)
		var biome_id := String(GENERATED_DECORATIVE_BIOME_BY_TERRAIN.get(terrain_id, ""))
		var terrain_asset_ids: Array = _generated_decorative_blocker_asset_ids_by_biome.get(biome_id, [])
		var terrain_matched := not terrain_asset_ids.is_empty() and asset_id in terrain_asset_ids
		if visual_anchor:
			visual_anchor_count += 1
			var anchor_placement_id := String(presentation.get("generated_body_anchor_placement_id", "")).strip_edges()
			if anchor_placement_id != "":
				visual_anchor_placement_ids[anchor_placement_id] = true
		if loaded:
			loaded_asset_count += 1
		if visual_anchor and terrain_matched:
			terrain_matched_asset_count += 1
		if int(presentation.get("generated_body_source_count", 0)) > 1:
			collision_tile_count += 1
		if visual_anchor and asset_id != "":
			distinct_asset_ids[asset_id] = true
		var h3m_def_name := String(presentation.get("h3m_def_name", "")).strip_edges()
		if visual_anchor and h3m_def_name != "":
			var def_asset_ids: Dictionary = h3m_def_asset_ids.get(h3m_def_name, {})
			def_asset_ids[asset_id] = true
			h3m_def_asset_ids[h3m_def_name] = def_asset_ids
			var def_placement_ids: Dictionary = h3m_def_placement_ids.get(h3m_def_name, {})
			for source_id_value in presentation.get("generated_body_source_placement_ids", []):
				var source_id := String(source_id_value).strip_edges()
				if source_id != "":
					def_placement_ids[source_id] = true
			h3m_def_placement_ids[h3m_def_name] = def_placement_ids
		var composition_key := String(presentation.get("generated_body_composition_key", ""))
		if visual_anchor and composition_key != "":
			composition_key_count += 1
		var motif_key := String(presentation.get("generated_body_motif_key", ""))
		if visual_anchor and motif_key != "":
			motif_keys[motif_key] = true
		var scale_factor := float(presentation.get("generated_body_scale_factor", 1.0))
		var offset_payload: Dictionary = presentation.get("generated_body_offset_tiles", {}) if presentation.get("generated_body_offset_tiles", {}) is Dictionary else {}
		var offset_x := float(offset_payload.get("x", 0.0))
		var offset_y := float(offset_payload.get("y", 0.0))
		var sprite_bounds := _generated_body_normalized_sprite_bounds(presentation) if visual_anchor else {}
		if visual_anchor:
			if bool(sprite_bounds.get("within_mass_margin", false)):
				transformed_bounds_within_mass_margin_count += 1
			scale_factor_min = minf(scale_factor_min, scale_factor)
			scale_factor_max = maxf(scale_factor_max, scale_factor)
			offset_x_min = minf(offset_x_min, offset_x)
			offset_x_max = maxf(offset_x_max, offset_x)
			offset_y_min = minf(offset_y_min, offset_y)
			offset_y_max = maxf(offset_y_max, offset_y)
		entries.append({
			"tile_key": key,
			"x": int(presentation.get("x", -1)),
			"y": int(presentation.get("y", -1)),
			"terrain_id": terrain_id,
			"biome_id": biome_id,
			"asset_id": asset_id,
			"visual_anchor": visual_anchor,
			"anchor_placement_id": String(presentation.get("generated_body_anchor_placement_id", "")),
			"anchor_index": int(presentation.get("generated_body_anchor_index", -1)),
			"anchor_count": int(presentation.get("generated_body_anchor_count", 0)),
			"placement_tile_count": int(presentation.get("generated_body_placement_tile_count", 0)),
			"asset_loaded": loaded,
			"terrain_matched_asset": terrain_matched,
			"source_placement_ids": presentation.get("generated_body_source_placement_ids", []).duplicate(true),
			"h3m_def_name": h3m_def_name,
			"motif_key": motif_key,
			"composition_key": composition_key,
			"scale_factor": scale_factor,
			"offset_tiles": offset_payload.duplicate(true),
			"sprite_extent_tiles": float(presentation.get("generated_body_sprite_extent_tiles", 0.0)),
			"sprite_center_tiles": presentation.get("generated_body_sprite_center_tiles", {}).duplicate(true),
			"sprite_bounds": sprite_bounds,
		})
	var repeated_def_multi_asset_count := 0
	for h3m_def_name_value in h3m_def_asset_ids.keys():
		var h3m_def_name := String(h3m_def_name_value)
		var def_asset_ids: Dictionary = h3m_def_asset_ids.get(h3m_def_name, {})
		var def_placement_ids: Dictionary = h3m_def_placement_ids.get(h3m_def_name, {})
		if def_placement_ids.size() > 1 and def_asset_ids.size() > 1:
			repeated_def_multi_asset_count += 1
	var resource_entries: Array = []
	var capped_resource_count := 0
	var max_capped_extent_tiles := 0.0
	if _session != null:
		var board_rect := _board_rect()
		for node_value in _session.overworld.get("resource_nodes", []):
			if not (node_value is Dictionary):
				continue
			var node: Dictionary = node_value
			var anchor_tile := Vector2i(int(node.get("x", -1)), int(node.get("y", -1)))
			if anchor_tile.x < 0 or anchor_tile.y < 0 or anchor_tile.x >= _map_size.x or anchor_tile.y >= _map_size.y:
				continue
			var anchor_rect := _tile_rect(board_rect, anchor_tile)
			var resource_rect := _resource_footprint_rect(node, anchor_rect, anchor_tile)
			var metrics := _object_sprite_visual_metrics(resource_rect, _resource_object_profile(node))
			if bool(metrics.get("uses_multi_tile_visual_cap", false)):
				capped_resource_count += 1
				max_capped_extent_tiles = maxf(max_capped_extent_tiles, float(metrics.get("sprite_extent_tiles", 0.0)))
			resource_entries.append({
				"placement_id": String(node.get("placement_id", "")),
				"site_id": String(node.get("site_id", "")),
				"x": anchor_tile.x,
				"y": anchor_tile.y,
				"visual_metrics": metrics,
			})
	return {
		"presentation_model": GENERATED_DECORATIVE_BODY_PRESENTATION_MODEL,
		"generated_record_count": generated_record_count,
		"legacy_primary_marker_candidate_count": legacy_primary_marker_candidates.size(),
		"indexed_legacy_primary_marker_count": indexed_legacy_primary_marker_count,
		"legacy_primary_markers_suppressed": indexed_legacy_primary_marker_count == 0,
		"legacy_primary_marker_candidates": legacy_primary_marker_candidates,
		"expected_body_tile_count": expected_keys.size(),
		"indexed_body_tile_count": indexed_keys.size(),
		"body_tile_keys_exact": indexed_keys == expected_keys,
		"loaded_body_asset_count": loaded_asset_count,
		"visual_anchor_count": visual_anchor_count,
		"visual_anchor_placement_count": visual_anchor_placement_ids.size(),
		"all_generated_records_anchored": visual_anchor_placement_ids.size() == generated_record_count,
		"sparse_anchor_density": float(visual_anchor_count) / float(maxi(indexed_keys.size(), 1)),
		"all_body_assets_loaded": loaded_asset_count == visual_anchor_count,
		"terrain_matched_body_asset_count": terrain_matched_asset_count,
		"all_body_assets_terrain_matched": terrain_matched_asset_count == visual_anchor_count,
		"collision_tile_count": collision_tile_count,
		"body_sprite_extent_tiles": GENERATED_DECORATIVE_BODY_SPRITE_EXTENT_TILES,
		"asset_cluster_tiles": GENERATED_DECORATIVE_BODY_ASSET_CLUSTER_TILES,
		"distinct_body_asset_count": distinct_asset_ids.size(),
		"motif_key_count": motif_keys.size(),
		"repeated_def_multi_asset_count": repeated_def_multi_asset_count,
		"composition_key_count": composition_key_count,
		"transformed_bounds_within_mass_margin_count": transformed_bounds_within_mass_margin_count,
		"all_transformed_bounds_within_mass_margin": transformed_bounds_within_mass_margin_count == visual_anchor_count,
		"mass_bounds_margin_tiles": GENERATED_DECORATIVE_BODY_MASS_BOUNDS_MARGIN_TILES,
		"scale_factor_min": scale_factor_min if visual_anchor_count > 0 else 0.0,
		"scale_factor_max": scale_factor_max if visual_anchor_count > 0 else 0.0,
		"offset_x_min": offset_x_min if visual_anchor_count > 0 else 0.0,
		"offset_x_max": offset_x_max if visual_anchor_count > 0 else 0.0,
		"offset_y_min": offset_y_min if visual_anchor_count > 0 else 0.0,
		"offset_y_max": offset_y_max if visual_anchor_count > 0 else 0.0,
		"composition_signature": JSON.stringify(entries).sha256_text(),
		"body_entries": entries,
		"multi_tile_interactive_cap_tiles": MULTI_TILE_INTERACTIVE_SPRITE_EXTENT_ABSOLUTE_CAP_TILES,
		"multi_tile_interactive_base_min_tiles": MULTI_TILE_INTERACTIVE_SPRITE_EXTENT_BASE_MIN_TILES,
		"multi_tile_interactive_span_min_step_tiles": MULTI_TILE_INTERACTIVE_SPRITE_EXTENT_SPAN_MIN_STEP_TILES,
		"multi_tile_interactive_depth_min_step_tiles": MULTI_TILE_INTERACTIVE_SPRITE_EXTENT_DEPTH_MIN_STEP_TILES,
		"multi_tile_interactive_base_cap_tiles": MULTI_TILE_INTERACTIVE_SPRITE_EXTENT_BASE_CAP_TILES,
		"multi_tile_interactive_span_cap_step_tiles": MULTI_TILE_INTERACTIVE_SPRITE_EXTENT_SPAN_CAP_STEP_TILES,
		"multi_tile_interactive_depth_cap_step_tiles": MULTI_TILE_INTERACTIVE_SPRITE_EXTENT_DEPTH_CAP_STEP_TILES,
		"capped_resource_count": capped_resource_count,
		"max_capped_resource_extent_tiles": max_capped_extent_tiles,
		"resource_entries": resource_entries,
	}

func validation_authored_scenery_summary() -> Dictionary:
	var entries: Array = []
	var authored_count := 0
	var indexed_count := 0
	var loaded_asset_count := 0
	var blocked_body_tile_count := 0
	if _session == null:
		return {
			"authored_count": 0,
			"indexed_count": 0,
			"loaded_asset_count": 0,
			"blocked_body_tile_count": 0,
			"all_indexed": true,
			"all_assets_loaded": true,
			"entries": entries,
		}
	for object_value in _session.overworld.get("map_objects", []):
		if not (object_value is Dictionary):
			continue
		var object: Dictionary = object_value
		if not _is_decorative_object_placement(object) or String(object.get("runtime_object_role", "")) == "decorative_blocker_sprite":
			continue
		authored_count += 1
		var placement_id := String(object.get("placement_id", ""))
		var tile := Vector2i(int(object.get("x", -1)), int(object.get("y", -1)))
		var indexed: Dictionary = _decorative_objects_by_tile.get(_tile_key(tile), {})
		var is_indexed := String(indexed.get("placement_id", "")) == placement_id
		if is_indexed:
			indexed_count += 1
		var asset_id := _decorative_object_asset_id(object)
		var asset_loaded := asset_id != "" and _object_texture_for_asset(asset_id) is Texture2D
		if asset_loaded:
			loaded_asset_count += 1
		var body_tiles: Array = object.get("body_tiles", []) if object.get("body_tiles", []) is Array else []
		var blocked_count := 0
		for body_value in body_tiles:
			if not (body_value is Dictionary):
				continue
			var body_tile := Vector2i(int(body_value.get("x", -1)), int(body_value.get("y", -1)))
			if OverworldRulesScript.tile_is_blocked(_session, body_tile.x, body_tile.y):
				blocked_count += 1
		blocked_body_tile_count += blocked_count
		entries.append({
			"placement_id": placement_id,
			"object_id": String(object.get("object_id", "")),
			"asset_id": asset_id,
			"asset_loaded": asset_loaded,
			"indexed": is_indexed,
			"body_tile_count": body_tiles.size(),
			"blocked_body_tile_count": blocked_count,
		})
	return {
		"authored_count": authored_count,
		"indexed_count": indexed_count,
		"loaded_asset_count": loaded_asset_count,
		"blocked_body_tile_count": blocked_body_tile_count,
		"all_indexed": indexed_count == authored_count,
		"all_assets_loaded": loaded_asset_count == authored_count,
		"entries": entries,
	}

func validation_object_sprite_scale_payload(asset_id: String, family: String, footprint: Vector2i = Vector2i.ONE, profile_overrides: Dictionary = {}, visible_footprint_span: Vector2i = Vector2i.ZERO) -> Dictionary:
	var texture = _object_texture_for_asset(asset_id)
	if not (texture is Texture2D):
		return {}
	var normalized_footprint := _normalized_footprint(footprint)
	var profile := _default_object_profile(family, normalized_footprint)
	for key in profile_overrides.keys():
		profile[key] = profile_overrides.get(key)
	var single_tile_extent := 100.0
	var normalized_visible_span := normalized_footprint if visible_footprint_span == Vector2i.ZERO else _normalized_footprint(visible_footprint_span)
	var footprint_rect := Rect2(Vector2.ZERO, Vector2(normalized_visible_span) * single_tile_extent)
	var logical_footprint_rect := Rect2(Vector2.ZERO, Vector2(normalized_footprint) * single_tile_extent)
	var visible_offset := normalized_footprint - normalized_visible_span
	var visible_footprint_rect := Rect2(Vector2(visible_offset) * single_tile_extent, Vector2(normalized_visible_span) * single_tile_extent)
	var metrics := _object_sprite_visual_metrics(logical_footprint_rect, profile, single_tile_extent, visible_footprint_rect)
	var cache_size_before := _object_texture_visible_regions.size()
	var first_region := _object_texture_visible_region(asset_id, texture)
	var cache_size_after_first := _object_texture_visible_regions.size()
	var second_region := _object_texture_visible_region(asset_id, texture)
	var cache_size_after_second := _object_texture_visible_regions.size()
	var visible_extent_px := float(metrics.get("sprite_extent_px", 0.0))
	var draw_payload := _object_painted_sprite_draw_payload(
		asset_id,
		texture,
		metrics.get("sprite_center", footprint_rect.get_center()),
		visible_extent_px
	)
	var source_rect: Rect2 = first_region.get("source_rect", Rect2())
	var normalized_source_rect: Rect2 = first_region.get("normalized_source_rect", Rect2())
	var draw_rect: Rect2 = draw_payload.get("draw_rect", Rect2())
	var draw_size: Vector2 = draw_payload.get("draw_size", Vector2.ZERO)
	var sprite_center: Vector2 = metrics.get("sprite_center", visible_footprint_rect.get_center())
	return {
		"asset_id": asset_id,
		"family": family,
		"scale_hierarchy_model": WORLD_OBJECT_SCALE_HIERARCHY_MODEL,
		"primary_class": String(profile.get("primary_class", "")),
		"footprint_tier": String(profile.get("footprint_tier", "")),
		"semantic_scale_class": _semantic_visual_scale_class(profile),
		"interactive_silhouette": _mapped_object_uses_interactive_silhouette(profile),
		"interactive_silhouette_model": WORLD_SPRITE_SILHOUETTE_MODEL if _mapped_object_uses_interactive_silhouette(profile) else "none",
		"interactive_silhouette_width_px": maxf(OBJECT_INTERACTIVE_SILHOUETTE_MIN_PX, visible_extent_px * OBJECT_INTERACTIVE_SILHOUETTE_WIDTH_FACTOR) if _mapped_object_uses_interactive_silhouette(profile) else 0.0,
		"visible_modulate_alpha": _mapped_object_sprite_modulate(profile, false).a,
		"footprint": {"width": normalized_footprint.x, "height": normalized_footprint.y},
		"visible_footprint_span": {"width": normalized_visible_span.x, "height": normalized_visible_span.y},
		"world_tile_extent_px": float(metrics.get("single_tile_extent_px", 0.0)),
		"footprint_clipped": bool(metrics.get("footprint_clipped", false)),
		"visible_footprint_rect": {"x": visible_footprint_rect.position.x, "y": visible_footprint_rect.position.y, "width": visible_footprint_rect.size.x, "height": visible_footprint_rect.size.y},
		"sprite_center": {"x": sprite_center.x, "y": sprite_center.y},
		"sprite_contained_in_visible_footprint": visible_footprint_rect.encloses(draw_rect),
		"visible_scale_model": String(draw_payload.get("visible_scale_model", "")),
		"uses_painted_bounds": bool(first_region.get("uses_painted_bounds", false)),
		"painted_extent_fraction": float(first_region.get("painted_extent_fraction", 0.0)),
		"source_rect": {"x": source_rect.position.x, "y": source_rect.position.y, "width": source_rect.size.x, "height": source_rect.size.y},
		"normalized_source_rect": {"x": normalized_source_rect.position.x, "y": normalized_source_rect.position.y, "width": normalized_source_rect.size.x, "height": normalized_source_rect.size.y},
		"source_aspect": float(draw_payload.get("source_aspect", 0.0)),
		"draw_aspect": float(draw_payload.get("draw_aspect", 0.0)),
		"draw_rect": {"x": draw_rect.position.x, "y": draw_rect.position.y, "width": draw_rect.size.x, "height": draw_rect.size.y},
		"draw_size_tiles": {"x": draw_size.x / single_tile_extent, "y": draw_size.y / single_tile_extent},
		"painted_width_tiles": draw_size.x / single_tile_extent,
		"painted_height_tiles": draw_size.y / single_tile_extent,
		"visible_extent_tiles": visible_extent_px / single_tile_extent,
		"uses_multi_tile_visual_cap": bool(metrics.get("uses_multi_tile_visual_cap", false)),
		"min_tiles": float(metrics.get("min_tiles", 0.0)),
		"cap_tiles": float(metrics.get("cap_tiles", 0.0)),
		"cache_size_before": cache_size_before,
		"cache_size_after_first": cache_size_after_first,
		"cache_size_after_second": cache_size_after_second,
		"cache_repeat_exact": first_region == second_region and cache_size_after_first == cache_size_after_second,
	}

func validation_content_object_sprite_scale_payload(object_id: String, asset_id: String) -> Dictionary:
	var profile_value = _map_object_content_profiles.get(object_id, {})
	if not (profile_value is Dictionary) or profile_value.is_empty():
		return {}
	var profile: Dictionary = profile_value.duplicate(true)
	var footprint := _object_profile_footprint(profile)
	var payload := validation_object_sprite_scale_payload(asset_id, String(profile.get("family", "pickup")), footprint, profile)
	payload["content_profile"] = {
		"id": String(profile.get("id", "")),
		"family": String(profile.get("family", "")),
		"primary_class": String(profile.get("primary_class", "")),
		"footprint_tier": String(profile.get("footprint_tier", "")),
		"footprint": {"width": footprint.x, "height": footprint.y},
		"passable": bool(profile.get("passable", true)),
		"visitable": bool(profile.get("visitable", true)),
		"map_roles": profile.get("map_roles", []).duplicate(true),
	}
	return payload

func validation_town_sprite_scale_payload(asset_id: String = "town_faction_embercourt") -> Dictionary:
	var texture = _object_texture_for_asset(asset_id)
	if not (texture is Texture2D):
		return {}
	var single_tile_extent := 100.0
	var footprint_rect := Rect2(Vector2.ZERO, Vector2(TOWN_VISUAL_FOOTPRINT) * single_tile_extent)
	var cache_size_before := _object_texture_visible_regions.size()
	var first_region := _object_texture_visible_region(asset_id, texture)
	var cache_size_after_first := _object_texture_visible_regions.size()
	var second_region := _object_texture_visible_region(asset_id, texture)
	var cache_size_after_second := _object_texture_visible_regions.size()
	var draw_payload := _town_sprite_draw_payload(asset_id, texture, footprint_rect, single_tile_extent)
	var draw_size: Vector2 = draw_payload.get("draw_size", Vector2.ZERO)
	var draw_rect: Rect2 = draw_payload.get("draw_rect", Rect2())
	var sprite_center: Vector2 = draw_payload.get("sprite_center", Vector2.ZERO)
	var visible_extent_px := float(draw_payload.get("visible_extent_px", 0.0))
	var silhouette_width_px := maxf(TOWN_SPRITE_SILHOUETTE_MIN_PX, minf(footprint_rect.size.x, footprint_rect.size.y) * TOWN_SPRITE_SILHOUETTE_WIDTH_FACTOR)
	var painted_bottom_clearance_tiles := float(draw_payload.get("painted_bottom_clearance_px", 0.0)) / single_tile_extent
	return {
		"asset_id": asset_id,
		"family": "town",
		"scale_hierarchy_model": WORLD_OBJECT_SCALE_HIERARCHY_MODEL,
		"footprint": {"width": TOWN_VISUAL_FOOTPRINT.x, "height": TOWN_VISUAL_FOOTPRINT.y},
		"visual_footprint": {"width": TOWN_VISUAL_FOOTPRINT.x, "height": TOWN_VISUAL_FOOTPRINT.y},
		"logical_footprint": {"width": TOWN_PRESENTATION_FOOTPRINT.x, "height": TOWN_PRESENTATION_FOOTPRINT.y},
		"visual_anchor_model": TOWN_VISUAL_ANCHOR_MODEL,
		"visible_scale_model": String(draw_payload.get("visible_scale_model", "")),
		"uses_painted_bounds": bool(first_region.get("uses_painted_bounds", false)),
		"source_aspect": float(draw_payload.get("source_aspect", 0.0)),
		"draw_aspect": float(draw_payload.get("draw_aspect", 0.0)),
		"draw_size_tiles": {"x": draw_size.x / single_tile_extent, "y": draw_size.y / single_tile_extent},
		"painted_width_tiles": draw_size.x / single_tile_extent,
		"painted_height_tiles": draw_size.y / single_tile_extent,
		"draw_rect_tiles": {"x": draw_rect.position.x / single_tile_extent, "y": draw_rect.position.y / single_tile_extent, "width": draw_rect.size.x / single_tile_extent, "height": draw_rect.size.y / single_tile_extent},
		"visible_extent_tiles": visible_extent_px / single_tile_extent,
		"town_width_cap_tiles": float(draw_payload.get("town_width_cap_tiles", 0.0)),
		"town_vertical_landmark_fit": bool(draw_payload.get("town_vertical_landmark_fit", false)),
		"visible_extent_fraction_of_footprint_depth": TOWN_SPRITE_EXTENT_FACTOR,
		"town_to_hero_extent_ratio": (visible_extent_px / single_tile_extent) / HERO_FIELD_SPRITE_EXTENT_FACTOR,
		"town_to_largest_other_object_extent_ratio": (visible_extent_px / single_tile_extent) / MULTI_TILE_INTERACTIVE_SPRITE_EXTENT_ABSOLUTE_CAP_TILES,
		"sprite_center_tiles": {"x": sprite_center.x / single_tile_extent, "y": sprite_center.y / single_tile_extent},
		"painted_bottom_clearance_tiles": painted_bottom_clearance_tiles,
		"painted_bottom_grounded_exact": is_equal_approx(painted_bottom_clearance_tiles, TOWN_SPRITE_GROUND_CLEARANCE_TILES),
		"sprite_contained_in_footprint": footprint_rect.encloses(draw_rect),
		"sprite_silhouette_model": WORLD_SPRITE_SILHOUETTE_MODEL,
		"sprite_silhouette_width_px": silhouette_width_px,
		"sprite_silhouette_contained_in_footprint": footprint_rect.encloses(draw_rect.grow(silhouette_width_px)),
		"cache_size_before": cache_size_before,
		"cache_size_after_first": cache_size_after_first,
		"cache_size_after_second": cache_size_after_second,
		"cache_repeat_exact": first_region == second_region and cache_size_after_first == cache_size_after_second,
	}

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
	if _has_decorative_object_at(tile):
		count += 1
	if _has_standalone_map_object_at(tile):
		count += 1
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
	var small_map_matte_gutters := _small_map_cartographic_matte_gutters(viewport_rect, board_rect)
	var small_map_matte_active := _small_map_cartographic_matte_active(viewport_rect, board_rect)
	var uncapped_whole_map_fit_tile_extent := _uncapped_whole_map_fit_tile_extent(viewport_rect.size)
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
		"maximum_small_map_fit_tile_extent": MAX_SMALL_MAP_FIT_TILE_EXTENT,
		"uncapped_whole_map_fit_tile_extent": uncapped_whole_map_fit_tile_extent,
		"small_map_fit_extent_capped": _should_fit_entire_map() and uncapped_whole_map_fit_tile_extent > cell_size.x,
		"whole_map_fit_scale_policy": "bounded_small_map_fit_extent",
		"small_map_cartographic_matte_active": small_map_matte_active,
		"small_map_cartographic_matte_model": SMALL_MAP_CARTOGRAPHIC_MATTE_MODEL,
		"small_map_cartographic_matte_minimum_gutter": SMALL_MAP_CARTOGRAPHIC_MATTE_MIN_GUTTER,
		"small_map_cartographic_matte_grid_spacing": SMALL_MAP_CARTOGRAPHIC_MATTE_GRID_SPACING,
		"small_map_cartographic_matte_board_shadow_extent": SMALL_MAP_CARTOGRAPHIC_MATTE_BOARD_SHADOW_EXTENT,
		"small_map_cartographic_matte_gutters": small_map_matte_gutters.duplicate(true),
		"small_map_cartographic_matte_below_terrain": true,
		"small_map_cartographic_matte_noninteractive": true,
		"small_map_cartographic_matte_fake_tiles": false,
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
		"route_preview": _route_preview.duplicate(true),
		"route_visual_profile": validation_route_visual_profile(),
		"visible_bounds": {
			"x": visible_bounds.position.x,
			"y": visible_bounds.position.y,
			"width": visible_bounds.size.x,
			"height": visible_bounds.size.y,
		},
		"render_cache": {
			"session_static_generation": _session_static_cache_generation,
			"terrain_ambient_generation": _terrain_ambient_generation,
			"state_generation": _state_cache_generation,
			"dynamic_generation": _dynamic_layer_generation,
			"frame_generation": _frame_layer_generation,
			"session_static_reason": _session_static_cache_reason,
			"terrain_ambient_reason": _terrain_ambient_reason,
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
			"decorative_object_tiles": _decorative_objects_by_tile.size(),
			"generated_decorative_body_tiles": _generated_decorative_bodies_by_tile.size(),
			"standalone_map_object_tiles": _standalone_map_objects_by_tile.size(),
			"hero_tiles": _heroes_by_tile.size(),
		},
		"unit_art": validation_unit_art_summary(),
		"hero_movement_presentation": validation_hero_movement_presentation(),
		"object_resolution_presentation": validation_object_resolution_presentation(),
		"route_blocked_presentation": validation_route_blocked_presentation(),
		"guarded_site_presentation": validation_guarded_site_presentation(),
		"object_focus_presentation": validation_object_focus_presentation(),
		"spell_cast_presentation": validation_spell_cast_presentation(),
	}

func validation_terrain_ambient_summary() -> Dictionary:
	var viewport_rect := _map_viewport_rect()
	var board_rect := _board_rect()
	var visible_bounds := _visible_tile_bounds(board_rect, viewport_rect)
	var high_contrast := FrontierVisualKitScript.high_contrast_enabled()
	var reduced_motion := SettingsService.reduced_motion_enabled()
	var phase := TERRAIN_AMBIENT_STATIC_PHASE if reduced_motion else _terrain_ambient_phase
	var entries := _overworld_terrain_ambient_entries(board_rect, visible_bounds, phase)
	var identity_rows: Array = []
	var presentation_rows: Array = []
	var profile_ids: Array = []
	var all_contained := true
	var all_explored := true
	for entry_value in entries:
		if not (entry_value is Dictionary):
			all_contained = false
			all_explored = false
			continue
		var entry: Dictionary = entry_value
		var tile: Vector2i = entry.get("tile", Vector2i(-1, -1))
		var profile_id := String(entry.get("profile_id", ""))
		if profile_id not in profile_ids:
			profile_ids.append(profile_id)
		all_contained = all_contained and bool(entry.get("contained", false))
		all_explored = all_explored and bool(entry.get("explored", false)) and OverworldRulesScript.is_tile_explored(_session, tile.x, tile.y)
		identity_rows.append({
			"x": tile.x,
			"y": tile.y,
			"profile_id": profile_id,
			"kind": String(entry.get("kind", "")),
			"base_normalized": _vector2_payload(entry.get("base_normalized", Vector2.ZERO)),
		})
		presentation_rows.append({
			"x": tile.x,
			"y": tile.y,
			"profile_id": profile_id,
			"center": _vector2_payload(entry.get("center", Vector2.ZERO)),
			"radius": float(entry.get("radius", 0.0)),
			"outer_radius": float(entry.get("outer_radius", 0.0)),
			"alpha": float(entry.get("alpha", 0.0)),
			"contained": bool(entry.get("contained", false)),
		})
	var layer_indices := {
		"terrain_and_roads": _session_static_layer.get_index() if is_instance_valid(_session_static_layer) else -1,
		"ambient_life": _terrain_ambient_layer.get_index() if is_instance_valid(_terrain_ambient_layer) else -1,
		"fog_and_objects": _state_layer.get_index() if is_instance_valid(_state_layer) else -1,
		"routes_and_selection": _dynamic_layer.get_index() if is_instance_valid(_dynamic_layer) else -1,
		"frame_and_ui": _frame_layer.get_index() if is_instance_valid(_frame_layer) else -1,
	}
	return {
		"model": TERRAIN_AMBIENT_MODEL,
		"draw_order": TERRAIN_AMBIENT_DRAW_ORDER.duplicate(),
		"layer_name": _terrain_ambient_layer.name if is_instance_valid(_terrain_ambient_layer) else "",
		"layer_indices": layer_indices,
		"available": _overworld_terrain_ambient_available(),
		"animating": _overworld_terrain_ambient_should_animate(),
		"reduced_motion": reduced_motion,
		"high_contrast": high_contrast,
		"phase": phase,
		"phase_speed": TERRAIN_AMBIENT_PHASE_SPEED,
		"static_phase": TERRAIN_AMBIENT_STATIC_PHASE,
		"density_modulus": TERRAIN_AMBIENT_DENSITY_MODULUS,
		"profile_ids": profile_ids,
		"profile_mapping": TERRAIN_AMBIENT_PROFILES.duplicate(true),
		"entry_count": entries.size(),
		"identities": identity_rows,
		"presentations": presentation_rows,
		"all_contained": all_contained,
		"all_explored": all_explored,
		"exploration_gate_before_profile": true,
		"hidden_identity_sampled": false,
		"visible_bounds": _rect2i_payload(visible_bounds),
		"session_mutation_source": "none_presentation_only",
		"generation": _terrain_ambient_generation,
		"reason": _terrain_ambient_reason,
	}

func validation_route_visual_profile() -> Dictionary:
	var board_rect := _board_rect()
	var reachable_tiles := _tiles_from_payloads(_route_preview.get("reachable_tiles", []))
	var unreachable_tiles := _tiles_from_payloads(_route_preview.get("unreachable_tiles", []))
	var reachable_profile := {}
	var blocked_profile := {}
	if reachable_tiles.size() > 1:
		reachable_profile = _route_segment_visual_profile(board_rect, reachable_tiles, ROUTE_COLOR, false)
	if unreachable_tiles.size() > 0:
		var blocked_segment: Array = []
		if reachable_tiles.size() > 0:
			blocked_segment.append(reachable_tiles[reachable_tiles.size() - 1])
		blocked_segment.append_array(unreachable_tiles)
		if blocked_segment.size() > 1:
			blocked_profile = _route_segment_visual_profile(board_rect, blocked_segment, ROUTE_BLOCKED_COLOR, true)
	return {
		"model": ROUTE_VISUAL_MODEL,
		"reachable": reachable_profile.duplicate(true),
		"blocked": blocked_profile.duplicate(true),
		"reachable_source_tiles": _vector2i_payloads(reachable_tiles),
		"unreachable_source_tiles": _vector2i_payloads(unreachable_tiles),
		"draw_order": "before_focus_and_dynamic_icons",
		"route_preview_enabled": _route_preview_enabled,
		"continuous_debug_bar": false,
		"filled_node_count": 0,
	}

func validation_hero_movement_presentation() -> Dictionary:
	var progress := 1.0
	if _hero_movement_active and _hero_movement_duration_sec > 0.0:
		progress = clampf(_hero_movement_elapsed_sec / _hero_movement_duration_sec, 0.0, 1.0)
	var route_tiles := []
	for tile in _hero_movement_path:
		route_tiles.append({"x": tile.x, "y": tile.y})
	var draw_state := _hero_movement_draw_state(_board_rect())
	var center: Vector2 = draw_state.get("center", Vector2.ZERO)
	var from_tile: Vector2i = draw_state.get("from_tile", _hero_tile)
	var to_tile: Vector2i = draw_state.get("to_tile", _hero_tile)
	return {
		"serial": _hero_movement_last_serial,
		"event_id": _hero_movement_event_id,
		"active": _hero_movement_active,
		"route_tiles": route_tiles,
		"route_step_count": maxi(0, route_tiles.size() - 1),
		"animation_state": _hero_movement_animation_state,
		"visual_policy": _hero_movement_visual_policy,
		"fallback_tag": _hero_movement_fallback_tag,
		"selected_vfx_cue_ids": _hero_movement_vfx_cue_ids.duplicate(true),
		"selected_audio_cue_ids": _hero_movement_audio_cue_ids.duplicate(true),
		"audio_playback_records": _hero_movement_audio_playback_records.duplicate(true),
		"vfx_asset": _hero_movement_vfx_asset_state(),
		"vfx_draw": _hero_movement_last_draw.duplicate(true),
		"reduced_motion": _hero_movement_reduced_motion,
		"duration_ms": int(round(_hero_movement_duration_sec * 1000.0)),
		"progress": progress,
		"segment_index": int(draw_state.get("segment_index", -1)),
		"segment_progress": float(draw_state.get("segment_progress", 1.0)),
		"draw_center": {"x": center.x, "y": center.y},
		"segment_from_tile": {"x": from_tile.x, "y": from_tile.y},
		"segment_to_tile": {"x": to_tile.x, "y": to_tile.y},
		"final_tile": {"x": _hero_tile.x, "y": _hero_tile.y},
	}

func _hero_movement_vfx_asset_state() -> Dictionary:
	var cue_id := String(_hero_movement_vfx_cue_ids[0]).strip_edges() if _hero_movement_vfx_cue_ids.size() == 1 else ""
	var spec := _overworld_vfx_manifest_cue(cue_id)
	var texture_path := String(spec.get("texture_path", "")).strip_edges()
	var event_id := String(spec.get("event_id", "")).strip_edges()
	var render_mode := String(spec.get("render_mode", "")).strip_edges()
	var texture_loaded := texture_path != "" and _overworld_vfx_texture_for_path(texture_path) != null
	var uses_imported_asset := cue_id == "vfx_placeholder_route_step" \
		and event_id == _hero_movement_event_id \
		and render_mode == "hero_route_step" \
		and texture_loaded
	return {
		"cue_id": cue_id,
		"event_id": event_id,
		"texture_path": texture_path,
		"render_mode": render_mode,
		"scale": float(spec.get("scale", 1.0)),
		"texture_loaded": texture_loaded,
		"uses_imported_asset": uses_imported_asset,
		"uses_interpolation_fallback": not uses_imported_asset,
		"fallback_mode": "existing_interpolated_hero_marker_only",
	}

func validation_object_resolution_presentation() -> Dictionary:
	var progress := 1.0
	if (_object_resolution_active or _object_resolution_queued) and _object_resolution_duration_sec > 0.0:
		progress = clampf(_object_resolution_elapsed_sec / _object_resolution_duration_sec, 0.0, 1.0)
	return {
		"serial": _object_resolution_last_serial,
		"event_id": _object_resolution_event_id,
		"active": _object_resolution_active,
		"queued": _object_resolution_queued,
		"family": _object_resolution_family,
		"placement_id": _object_resolution_placement_id,
		"tile": {"x": _object_resolution_tile.x, "y": _object_resolution_tile.y},
		"animation_state": _object_resolution_animation_state,
		"visual_policy": _object_resolution_visual_policy,
		"fallback_tag": _object_resolution_fallback_tag,
		"selected_vfx_cue_ids": _object_resolution_vfx_cue_ids.duplicate(true),
		"selected_audio_cue_ids": _object_resolution_audio_cue_ids.duplicate(true),
		"audio_playback_records": _object_resolution_audio_playback_records.duplicate(true),
		"vfx_asset": _object_resolution_vfx_asset_state(),
		"vfx_draw": _object_resolution_last_draw.duplicate(true),
		"allows_large_motion": _object_resolution_allows_large_motion,
		"duration_ms": int(round(_object_resolution_duration_sec * 1000.0)),
		"progress": progress,
	}

func validation_object_resolution_vfx_asset_summary() -> Dictionary:
	_load_overworld_vfx_manifest()
	var cues: Dictionary = _overworld_vfx_manifest.get("cues", {}) if _overworld_vfx_manifest.get("cues", {}) is Dictionary else {}
	var cue_ids: Array = cues.keys()
	cue_ids.sort()
	var texture_paths: Array = []
	var loaded_texture_paths: Array = []
	var missing_texture_paths: Array = []
	for cue_id_value in cue_ids:
		var cue: Dictionary = cues.get(cue_id_value, {}) if cues.get(cue_id_value, {}) is Dictionary else {}
		var texture_path := String(cue.get("texture_path", "")).strip_edges()
		if texture_path == "" or texture_paths.has(texture_path):
			continue
		texture_paths.append(texture_path)
		if _overworld_vfx_texture_for_path(texture_path) != null:
			loaded_texture_paths.append(texture_path)
		else:
			missing_texture_paths.append(texture_path)
	return {
		"manifest_path": OVERWORLD_VFX_MANIFEST_PATH,
		"manifest_loaded": _overworld_vfx_manifest_loaded,
		"schema_id": String(_overworld_vfx_manifest.get("schema_id", "")),
		"mapped_cue_count": cue_ids.size(),
		"mapped_cue_ids": cue_ids,
		"unique_texture_count": texture_paths.size(),
		"texture_paths": texture_paths,
		"loaded_texture_count": loaded_texture_paths.size(),
		"loaded_texture_paths": loaded_texture_paths,
		"missing_texture_paths": missing_texture_paths,
	}

func _object_resolution_vfx_asset_state() -> Dictionary:
	var cue_id := String(_object_resolution_vfx_cue_ids[0]).strip_edges() if _object_resolution_vfx_cue_ids.size() == 1 else ""
	var spec := _overworld_vfx_manifest_cue(cue_id)
	var texture_path := String(spec.get("texture_path", "")).strip_edges()
	var event_id := String(spec.get("event_id", "")).strip_edges()
	var render_mode := String(spec.get("render_mode", "")).strip_edges()
	var texture_loaded := texture_path != "" and _overworld_vfx_texture_for_path(texture_path) != null
	var expected_render_mode := "route_open_resolution" if _object_resolution_event_id == "overworld_route_open" else ("route_closed_resolution" if _object_resolution_event_id == "overworld_route_closed" else "object_resolution")
	var expected_fallback_mode := "procedural_route_open_marker" if _object_resolution_event_id == "overworld_route_open" else ("procedural_route_closed_marker" if _object_resolution_event_id == "overworld_route_closed" else "existing_procedural_object_resolution_body")
	var uses_imported_asset := cue_id != "" \
		and event_id == _object_resolution_event_id \
		and render_mode == expected_render_mode \
		and texture_loaded
	return {
		"cue_id": cue_id,
		"event_id": event_id,
		"texture_path": texture_path,
		"render_mode": render_mode,
		"scale": float(spec.get("scale", 1.0)),
		"texture_loaded": texture_loaded,
		"uses_imported_asset": uses_imported_asset,
		"uses_procedural_fallback": not uses_imported_asset,
		"fallback_mode": expected_fallback_mode,
	}

func validation_route_blocked_presentation() -> Dictionary:
	var progress := 1.0
	if _route_blocked_active and _route_blocked_duration_sec > 0.0:
		progress = clampf(_route_blocked_elapsed_sec / _route_blocked_duration_sec, 0.0, 1.0)
	return {
		"serial": _route_blocked_last_serial,
		"event_id": _route_blocked_event_id,
		"active": _route_blocked_active,
		"tile": {"x": _route_blocked_tile.x, "y": _route_blocked_tile.y},
		"blocked_reason": _route_blocked_reason,
		"blocking_object": _route_blocked_blocking_object.duplicate(true),
		"animation_state": _route_blocked_animation_state,
		"visual_policy": _route_blocked_visual_policy,
		"fallback_tag": _route_blocked_fallback_tag,
		"selected_vfx_cue_ids": _route_blocked_vfx_cue_ids.duplicate(true),
		"selected_audio_cue_ids": _route_blocked_audio_cue_ids.duplicate(true),
		"audio_playback_records": _route_blocked_audio_playback_records.duplicate(true),
		"vfx_asset": _route_blocked_vfx_asset_state(),
		"vfx_draw": _route_blocked_last_draw.duplicate(true),
		"allows_large_motion": _route_blocked_allows_large_motion,
		"duration_ms": int(round(_route_blocked_duration_sec * 1000.0)),
		"progress": progress,
	}

func _route_blocked_vfx_asset_state() -> Dictionary:
	var cue_id := String(_route_blocked_vfx_cue_ids[0]).strip_edges() if _route_blocked_vfx_cue_ids.size() == 1 else ""
	var spec := _overworld_vfx_manifest_cue(cue_id)
	var texture_path := String(spec.get("texture_path", "")).strip_edges()
	var event_id := String(spec.get("event_id", "")).strip_edges()
	var render_mode := String(spec.get("render_mode", "")).strip_edges()
	var texture_loaded := texture_path != "" and _overworld_vfx_texture_for_path(texture_path) != null
	var expected_cue_id := "vfx_placeholder_object_blocked_marker" if _route_blocked_event_id == "overworld_object_blocked" else "vfx_placeholder_blocked_route_marker"
	var expected_render_mode := "object_blocked_marker" if _route_blocked_event_id == "overworld_object_blocked" else "route_blocked_marker"
	var expected_fallback_mode := "procedural_object_blocked_marker" if _route_blocked_event_id == "overworld_object_blocked" else "existing_procedural_route_blocked_marker"
	var uses_imported_asset := cue_id == expected_cue_id \
		and event_id == _route_blocked_event_id \
		and render_mode == expected_render_mode \
		and texture_loaded
	return {
		"cue_id": cue_id,
		"event_id": event_id,
		"texture_path": texture_path,
		"render_mode": render_mode,
		"scale": float(spec.get("scale", 1.0)),
		"texture_loaded": texture_loaded,
		"uses_imported_asset": uses_imported_asset,
		"uses_procedural_fallback": not uses_imported_asset,
		"fallback_mode": expected_fallback_mode,
	}

func validation_guarded_site_presentation() -> Dictionary:
	return {
		"active": _guarded_site_active,
		"event_id": _guarded_site_event_id,
		"status": "guarded" if _guarded_site_active else "",
		"tile": {"x": _guarded_site_tile.x, "y": _guarded_site_tile.y},
		"placement_id": _guarded_site_placement_id,
		"site_id": _guarded_site_site_id,
		"site_name": _guarded_site_site_name,
		"guard_placement_id": _guarded_site_guard_placement_id,
		"guard_name": _guarded_site_guard_name,
		"control_inspection": _guarded_site_control_inspection,
		"guard_link_surface": _guarded_site_guard_link_surface,
		"playback_policy": "context_visible_only" if _guarded_site_active else "",
		"animation_state": _guarded_site_animation_state,
		"visual_policy": _guarded_site_visual_policy,
		"fallback_tag": _guarded_site_fallback_tag,
		"selected_vfx_cue_ids": _guarded_site_vfx_cue_ids.duplicate(true),
		"selected_audio_cue_ids": _guarded_site_audio_cue_ids.duplicate(true),
		"audio_playback_records": _guarded_site_audio_playback_records.duplicate(true),
		"context_signature": _guarded_site_context_signature,
		"vfx_asset": _guarded_site_vfx_asset_state(),
		"vfx_draw": _guarded_site_last_draw.duplicate(true),
		"allows_large_motion": _guarded_site_allows_large_motion,
	}

func validation_object_focus_presentation() -> Dictionary:
	return {
		"active": _object_focus_active,
		"event_id": _object_focus_event_id,
		"cue_id": _object_focus_cue_id,
		"input_source": _object_focus_input_source,
		"tile": {"x": _object_focus_tile.x, "y": _object_focus_tile.y},
		"object_kind": _object_focus_kind,
		"object_id": _object_focus_id,
		"animation_state": _object_focus_animation_state,
		"visual_policy": _object_focus_visual_policy,
		"fallback_tag": _object_focus_fallback_tag,
		"playback_policy": _object_focus_playback_policy,
		"blocking_policy": _object_focus_blocking_policy,
		"selected_vfx_cue_ids": _object_focus_vfx_cue_ids.duplicate(true),
		"selected_audio_cue_ids": _object_focus_audio_cue_ids.duplicate(true),
		"audio_playback_records": _object_focus_audio_playback_records.duplicate(true),
		"context_signature": _object_focus_context_signature,
		"vfx_asset": _object_focus_vfx_asset_state(),
		"vfx_draw": _object_focus_last_draw.duplicate(true),
		"allows_large_motion": _object_focus_allows_large_motion,
	}

func _object_focus_vfx_asset_state() -> Dictionary:
	var cue_id := String(_object_focus_vfx_cue_ids[0]).strip_edges() if _object_focus_vfx_cue_ids.size() == 1 else ""
	var spec := _overworld_vfx_manifest_cue(cue_id)
	var texture_path := String(spec.get("texture_path", "")).strip_edges()
	var event_id := String(spec.get("event_id", "")).strip_edges()
	var render_mode := String(spec.get("render_mode", "")).strip_edges()
	var texture_loaded := texture_path != "" and _overworld_vfx_texture_for_path(texture_path) != null
	var uses_imported_asset := cue_id == "vfx_placeholder_object_focus_ring" \
		and event_id == _object_focus_event_id \
		and render_mode == "object_focus_context" \
		and texture_loaded
	return {
		"cue_id": cue_id,
		"event_id": event_id,
		"texture_path": texture_path,
		"render_mode": render_mode,
		"scale": float(spec.get("scale", 1.0)),
		"texture_loaded": texture_loaded,
		"uses_imported_asset": uses_imported_asset,
		"uses_selection_outline_fallback": not uses_imported_asset,
		"fallback_mode": "existing_tile_selection_outline",
	}

func _guarded_site_vfx_asset_state() -> Dictionary:
	var cue_id := String(_guarded_site_vfx_cue_ids[0]).strip_edges() if _guarded_site_vfx_cue_ids.size() == 1 else ""
	var spec := _overworld_vfx_manifest_cue(cue_id)
	var texture_path := String(spec.get("texture_path", "")).strip_edges()
	var event_id := String(spec.get("event_id", "")).strip_edges()
	var render_mode := String(spec.get("render_mode", "")).strip_edges()
	var texture_loaded := texture_path != "" and _overworld_vfx_texture_for_path(texture_path) != null
	var uses_imported_asset := cue_id == "vfx_placeholder_guard_warning" \
		and event_id == _guarded_site_event_id \
		and render_mode == "guarded_site_context" \
		and texture_loaded
	return {
		"cue_id": cue_id,
		"event_id": event_id,
		"texture_path": texture_path,
		"render_mode": render_mode,
		"scale": float(spec.get("scale", 1.0)),
		"texture_loaded": texture_loaded,
		"uses_imported_asset": uses_imported_asset,
		"uses_procedural_fallback": not uses_imported_asset,
		"fallback_mode": "existing_procedural_guard_shield",
	}

func validation_spell_cast_presentation() -> Dictionary:
	var progress := 1.0
	if _spell_cast_active and _spell_cast_duration_sec > 0.0:
		progress = clampf(_spell_cast_elapsed_sec / _spell_cast_duration_sec, 0.0, 1.0)
	var reduced_motion := _spell_cast_visual_policy == "reduced_motion_fallback"
	return {
		"serial": _spell_cast_last_serial,
		"event_id": _spell_cast_event_id,
		"cue_id": _spell_cast_cue_id,
		"active": _spell_cast_active,
		"spell_id": _spell_cast_spell_id,
		"spell_name": _spell_cast_spell_name,
		"result_message": _spell_cast_result_message,
		"hero_tile": {"x": _spell_cast_tile.x, "y": _spell_cast_tile.y},
		"animation_state": _spell_cast_animation_state,
		"visual_policy": _spell_cast_visual_policy,
		"fallback_tag": _spell_cast_fallback_tag,
		"playback_policy": _spell_cast_playback_policy,
		"blocking_policy": _spell_cast_blocking_policy,
		"blocks_input": _spell_cast_active and _spell_cast_blocking_policy == "input_blocking_timeout",
		"vfx_cue_ids": _spell_cast_vfx_cue_ids.duplicate(true),
		"audio_cue_ids": _spell_cast_audio_cue_ids.duplicate(true),
		"audio_playback_records": _spell_cast_audio_playback_records.duplicate(true),
		"vfx_asset": _spell_cast_vfx_asset_state(),
		"vfx_draw": _spell_cast_last_draw.duplicate(true),
		"allows_large_motion": _spell_cast_allows_large_motion,
		"duration_ms": int(round(_spell_cast_duration_sec * 1000.0)),
		"progress": progress,
		"draw_entries": ["adventure_spell_icon"] if reduced_motion else ["adventure_cast_rings", "adventure_spell_icon"],
	}

func _spell_cast_vfx_asset_state() -> Dictionary:
	var cue_id := String(_spell_cast_vfx_cue_ids[0]).strip_edges() if _spell_cast_vfx_cue_ids.size() == 1 else ""
	var spec := _overworld_vfx_manifest_cue(cue_id)
	var texture_path := String(spec.get("texture_path", "")).strip_edges()
	var event_id := String(spec.get("event_id", "")).strip_edges()
	var render_mode := String(spec.get("render_mode", "")).strip_edges()
	var texture_loaded := texture_path != "" and _overworld_vfx_texture_for_path(texture_path) != null
	var uses_imported_asset := cue_id == "vfx_placeholder_adventure_spell" \
		and event_id == _spell_cast_event_id \
		and render_mode == "field_spell_cast" \
		and texture_loaded
	return {
		"cue_id": cue_id,
		"event_id": event_id,
		"texture_path": texture_path,
		"render_mode": render_mode,
		"scale": float(spec.get("scale", 1.0)),
		"texture_loaded": texture_loaded,
		"uses_imported_asset": uses_imported_asset,
		"uses_procedural_fallback": not uses_imported_asset,
		"fallback_mode": "existing_procedural_adventure_cast_rings",
	}

func validation_color_cue_summary() -> Dictionary:
	return {
		"mode": FrontierVisualKitScript.color_cue_mode(),
		"assisted": FrontierVisualKitScript.color_cue_assist_enabled(),
		"player_town_color": _town_owner_color({"owner": "player"}),
		"enemy_town_color": _town_owner_color({"owner": "enemy"}),
		"neutral_town_color": _town_owner_color({"owner": "neutral"}),
		"player_owner_mark": "rectangle_dot" if FrontierVisualKitScript.color_cue_assist_enabled() else "triangle_color",
		"enemy_owner_mark": "triangle_cross" if FrontierVisualKitScript.color_cue_assist_enabled() else "triangle_color",
		"neutral_owner_mark": "diamond_bar" if FrontierVisualKitScript.color_cue_assist_enabled() else "triangle_color",
		"owner_marks_drawn_with_town_pennants": FrontierVisualKitScript.color_cue_assist_enabled(),
		"terrain_palette_unchanged": true,
	}

func validation_unit_art_summary() -> Dictionary:
	var entries := []
	var loaded_count := 0
	var missing := []
	for key in _encounters_by_tile.keys():
		var encounter: Dictionary = _encounters_by_tile.get(key, {})
		var unit_id := _encounter_primary_unit_id(encounter)
		var path := _encounter_overworld_icon_path(encounter)
		var loaded := path != "" and _unit_art_texture(path) is Texture2D
		if loaded:
			loaded_count += 1
		elif unit_id != "":
			missing.append(unit_id)
		entries.append({
			"tile_key": String(key),
			"encounter_id": String(encounter.get("encounter_id", encounter.get("id", ""))),
			"unit_id": unit_id,
			"overworld_icon": path,
			"loaded": loaded,
		})
	return {
		"encounter_count": entries.size(),
		"overworld_icon_loaded_count": loaded_count,
		"missing_overworld_icon_units": missing,
		"encounters": entries,
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
	var has_decorative_object := explored and _has_decorative_object_at(tile)
	var has_standalone_map_object := explored and _has_standalone_map_object_at(tile)
	var has_rememberable_encounter := explored and _has_rememberable_encounter_at(tile)
	var has_visible_encounter := visible and _has_encounter_at(tile)
	var has_visible_hero := visible and _has_hero_at(tile)
	var town_presentation := _town_presentation_payload(tile, explored, visible)
	var has_town_footprint := bool(town_presentation.get("has_town_footprint", false))
	var object_kinds := []
	if has_decorative_object:
		object_kinds.append("decorative_object")
	if has_standalone_map_object:
		object_kinds.append("map_object")
	if has_town:
		object_kinds.append("town")
	if has_resource:
		object_kinds.append("resource")
	if has_artifact:
		object_kinds.append("artifact")
	if has_visible_encounter or has_rememberable_encounter:
		object_kinds.append("encounter")
	var remembered_object := explored and not visible and (
		has_town or has_resource or has_artifact or has_decorative_object or has_standalone_map_object or has_rememberable_encounter or has_town_footprint
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
		"has_decorative_object": has_decorative_object,
		"has_standalone_map_object": has_standalone_map_object,
		"has_rememberable_encounter": has_rememberable_encounter,
		"has_visible_encounter": has_visible_encounter,
		"has_visible_hero": has_visible_hero,
		"has_town_footprint": has_town_footprint,
		"has_town_entry": bool(town_presentation.get("is_entry_tile", false)),
		"has_town_non_entry": has_town_footprint and not bool(town_presentation.get("is_entry_tile", false)),
		"draws_discoverable_object": (visible and (has_town or has_resource or has_artifact or has_decorative_object or has_standalone_map_object or has_visible_encounter or has_town_footprint)) or remembered_object,
		"draws_remembered_object": remembered_object,
		"terrain_presentation": _terrain_visual_payload(tile, explored, visible),
		"marker_readability": _marker_readability_payload(tile, explored, visible, object_kinds, has_visible_hero),
		"art_presentation": _object_art_payload(tile, explored, visible, object_kinds),
		"resource_draw_layout": _resource_draw_layout_payload(_resource_node_at(tile), _tile_rect(_board_rect(), tile), tile) if explored and has_resource else {},
		"artifact_presentation": _artifact_presentation_payload(tile, explored),
		"hero_presentation": _hero_presentation_payload(tile, explored),
		"town_presentation": town_presentation,
	}

func _artifact_presentation_payload(tile: Vector2i, explored: bool) -> Dictionary:
	if not explored:
		return {}
	var node := _artifact_node_at(tile)
	if node.is_empty():
		return {}
	var artifact_id := String(node.get("artifact_id", "")).strip_edges()
	var artifact := ContentService.get_artifact(artifact_id)
	var ui: Dictionary = artifact.get("ui", {}) if artifact.get("ui", {}) is Dictionary else {}
	var icon_asset_id := String(ui.get("icon_id", "")).strip_edges()
	var icon_path := ArtifactRules.artifact_icon_path(artifact_id)
	var sprite_asset_id := _artifact_sprite_asset_id(node)
	var field_sprite_path := String(_object_asset_paths.get(sprite_asset_id, ""))
	var artifact_profile := _artifact_object_profile(node)
	var field_sprite_extent_fraction := _sprite_extent_fraction(artifact_profile, Vector2i(1, 1))
	var expected_field_asset_id := String(_artifact_field_asset_ids.get(artifact_id, ""))
	return {
		"artifact_id": artifact_id,
		"icon_asset_id": icon_asset_id,
		"icon_path": icon_path,
		"sprite_asset_id": sprite_asset_id,
		"sprite_path": field_sprite_path,
		"uses_artifact_icon": artifact_id != "" and icon_asset_id != "" and sprite_asset_id == icon_asset_id,
		"uses_default_sprite": sprite_asset_id != "" and sprite_asset_id == _artifact_default_asset_id,
		"uses_distinct_field_sprite": expected_field_asset_id != "" and sprite_asset_id == expected_field_asset_id,
		"field_sprite_matches_artifact": expected_field_asset_id != "" and sprite_asset_id == expected_field_asset_id,
		"inventory_icon_separate_from_field_sprite": icon_path != "" and field_sprite_path != "" and icon_path != field_sprite_path,
		"field_sprite_extent_fraction": field_sprite_extent_fraction,
		"semantic_scale_class": _semantic_visual_scale_class(artifact_profile),
		"field_sprite_contained_in_tile": field_sprite_extent_fraction <= 1.0,
		"footprint_width_tiles": 1,
		"footprint_height_tiles": 1,
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

func validation_town_owner_pennant_variants(tile: Vector2i) -> Dictionary:
	var presentation := _town_presentation_at(tile)
	if presentation.is_empty():
		return {}
	var town: Dictionary = presentation.get("town", {})
	if town.is_empty():
		return {}
	var entry := _town_entry_tile(town)
	var rect := _town_footprint_rect_for_entry(entry)
	var variants := []
	for remembered in [false, true]:
		for color_cue_assist in [false, true]:
			for owner in ["player", "enemy", "neutral"]:
				var color := PLAYER_TOWN_COLOR if owner == "player" else (ENEMY_TOWN_COLOR if owner == "enemy" else NEUTRAL_TOWN_COLOR)
				variants.append(_town_owner_pennant_validation_payload(
					_town_owner_pennant_profile(rect, color, remembered, owner, color_cue_assist),
					rect
				))
	return {
		"model": TOWN_OWNER_PENNANT_MODEL,
		"tile": _vector2i_payload(tile),
		"entry_tile": _vector2i_payload(entry),
		"town_placement_id": String(town.get("placement_id", "")),
		"town_id": String(town.get("town_id", "")),
		"live_owner": _town_owner_id(town),
		"footprint_rect": _rect_payload(rect),
		"variant_count": variants.size(),
		"variants": variants,
	}

func _town_owner_pennant_validation_payload(profile: Dictionary, rect: Rect2) -> Dictionary:
	var cloth_points: PackedVector2Array = profile.get("cloth_points", PackedVector2Array())
	var shadow_points: PackedVector2Array = profile.get("shadow_points", PackedVector2Array())
	var fold_line: PackedVector2Array = profile.get("fold_line", PackedVector2Array())
	var highlight_line: PackedVector2Array = profile.get("highlight_line", PackedVector2Array())
	return {
		"model": String(profile.get("model", "")),
		"owner": String(profile.get("owner", "")),
		"remembered": bool(profile.get("remembered", false)),
		"color_cue_assist": bool(profile.get("color_cue_assist", false)),
		"shape_id": String(profile.get("shape_id", "")),
		"asset_id": String(profile.get("asset_id", "")),
		"asset_path": String(_object_asset_paths.get(String(profile.get("asset_id", "")), "")),
		"asset_loaded": _object_texture_for_asset(String(profile.get("asset_id", ""))) is Texture2D,
		"asset_rect": _rect_payload(profile.get("asset_rect", Rect2())),
		"asset_contained": rect.encloses(profile.get("asset_rect", Rect2())),
		"asset_mark_contained": profile.get("asset_rect", Rect2()).has_point(profile.get("asset_mark_center", Vector2.ZERO)),
		"procedural_fallback": not (_object_texture_for_asset(String(profile.get("asset_id", ""))) is Texture2D),
		"single_pass_draw_count": int(profile.get("single_pass_draw_count", 0)),
		"cloth_layer_count": int(profile.get("cloth_layer_count", 0)),
		"point_count": cloth_points.size(),
		"cloth_points": _vector2_array_payload(cloth_points),
		"shadow_points": _vector2_array_payload(shadow_points),
		"fold_line": _vector2_array_payload(fold_line),
		"highlight_line": _vector2_array_payload(highlight_line),
		"pole_top": _vector2_payload(profile.get("pole_top", Vector2.ZERO)),
		"pole_bottom": _vector2_payload(profile.get("pole_bottom", Vector2.ZERO)),
		"mark_center": _vector2_payload(profile.get("mark_center", Vector2.ZERO)),
		"cloth_bounds": _rect_payload(profile.get("cloth_bounds", Rect2())),
		"cloth_contained": rect.encloses(_points_bounds(cloth_points)),
		"shadow_contained": rect.encloses(_points_bounds(shadow_points)),
		"pole_contained": rect.has_point(profile.get("pole_top", Vector2.ZERO)) and rect.has_point(profile.get("pole_bottom", Vector2.ZERO)),
		"mark_contained": _points_bounds(cloth_points).has_point(profile.get("mark_center", Vector2.ZERO)),
		"cloth_color": _color_payload(profile.get("cloth_color", Color.TRANSPARENT)),
		"outline_color": _color_payload(profile.get("outline_color", Color.TRANSPARENT)),
		"pole_color": _color_payload(profile.get("pole_color", Color.TRANSPARENT)),
		"width_factor": float(profile.get("width_factor", 0.0)),
		"height_factor": float(profile.get("height_factor", 0.0)),
		"legacy_width_factor": float(profile.get("legacy_width_factor", 0.0)),
		"legacy_height_factor": float(profile.get("legacy_height_factor", 0.0)),
		"painted_area_ratio_to_legacy": float(profile.get("painted_area_ratio_to_legacy", 1.0)),
	}

func validation_hero_presentation_profiles() -> Array:
	var profiles := []
	if _session == null:
		return profiles
	for hero_value in HeroCommandRulesScript.hero_positions(_session):
		if not (hero_value is Dictionary):
			continue
		var hero: Dictionary = hero_value
		profiles.append(_hero_presentation_payload(Vector2i(int(hero.get("x", -1)), int(hero.get("y", -1))), true))
	return profiles

func validation_hero_draw_layout(tile: Vector2i, moving: bool = false) -> Dictionary:
	return _hero_draw_layout_payload(_tile_rect(_board_rect(), tile), tile, not moving)

func validation_tile_focus_layout(tile: Vector2i) -> Dictionary:
	var tile_rect := _tile_rect(_board_rect(), tile)
	var layout := _tile_focus_layout(tile, tile_rect)
	var hero_focus_rect: Rect2 = layout.get("hero_focus_rect", tile_rect)
	var selection_rect: Rect2 = layout.get("selection_rect", tile_rect)
	var hover_rect: Rect2 = layout.get("hover_rect", tile_rect)
	var hover_visual_profile: Dictionary = layout.get("hover_visual_profile", {}).duplicate(true)
	if not hover_visual_profile.is_empty():
		hover_visual_profile["perimeter_rect"] = _rect_payload(hover_visual_profile.get("perimeter_rect", hover_rect))
		var hover_color: Color = hover_visual_profile.get("corner_color", HOVER_COLOR)
		hover_visual_profile["corner_color"] = _color_payload(hover_color)
	var hero_command_marker_profile: Dictionary = layout.get("hero_command_marker_profile", {}).duplicate(true)
	if not hero_command_marker_profile.is_empty():
		hero_command_marker_profile["focus_rect"] = _rect_payload(hero_command_marker_profile.get("focus_rect", hero_focus_rect))
		hero_command_marker_profile["marker_rect"] = _rect_payload(hero_command_marker_profile.get("marker_rect", hero_focus_rect))
	var town_selection_visual_profile := _town_selection_visual_profile(selection_rect) if bool(layout.get("selection_uses_cartographic_town_perimeter", false)) else {}
	if not town_selection_visual_profile.is_empty():
		town_selection_visual_profile["perimeter_rect"] = _rect_payload(town_selection_visual_profile.get("perimeter_rect", selection_rect))
	var tile_selection_visual_profile := _tile_selection_visual_profile(selection_rect) if bool(layout.get("selection_uses_cartographic_tile_reticle", false)) else {}
	if not tile_selection_visual_profile.is_empty():
		tile_selection_visual_profile["perimeter_rect"] = _rect_payload(tile_selection_visual_profile.get("perimeter_rect", selection_rect))
	return {
		"tile": _vector2i_payload(tile),
		"tile_rect": _rect_payload(tile_rect),
		"hero_focus_rect": _rect_payload(hero_focus_rect),
		"hero_command_marker_profile": hero_command_marker_profile,
		"hero_uses_compact_town_footprint_rect": bool(layout.get("hero_uses_compact_town_footprint_rect", false)),
		"selection_rect": _rect_payload(selection_rect),
		"selection_uses_town_footprint_rect": bool(layout.get("selection_uses_town_footprint_rect", false)),
		"selection_uses_interior_fill": bool(layout.get("selection_uses_interior_fill", true)),
		"selection_uses_cartographic_town_perimeter": bool(layout.get("selection_uses_cartographic_town_perimeter", false)),
		"selection_uses_cartographic_tile_reticle": bool(layout.get("selection_uses_cartographic_tile_reticle", false)),
		"selection_visual_model": String(layout.get("selection_visual_model", "")),
		"town_selection_visual_profile": town_selection_visual_profile.duplicate(true),
		"tile_selection_visual_profile": tile_selection_visual_profile.duplicate(true),
		"hover_rect": _rect_payload(hover_rect),
		"hover_uses_town_footprint_rect": bool(layout.get("hover_uses_town_footprint_rect", false)),
		"hover_visual_model": String(layout.get("hover_visual_model", "")),
		"hover_visual_profile": hover_visual_profile,
		"town_entry_tile": layout.get("town_entry_tile", {}).duplicate(true),
	}

func validation_hover_presentation() -> Dictionary:
	if _hover_tile.x < 0 or _hover_tile.y < 0 or _hover_tile.x >= _map_size.x or _hover_tile.y >= _map_size.y:
		return {
			"active": false,
			"hover_tile": _vector2i_payload(_hover_tile),
			"focus_layout": {},
		}
	return {
		"active": true,
		"hover_tile": _vector2i_payload(_hover_tile),
		"focus_layout": validation_tile_focus_layout(_hover_tile),
	}

func validation_hover_tooltip_card(for_text: String) -> Dictionary:
	var profile := _hover_tooltip_visual_profile(for_text).duplicate(true)
	profile["panel_color"] = _color_payload(profile.get("panel_color", HOVER_TOOLTIP_PANEL_COLOR))
	profile["border_color"] = _color_payload(profile.get("border_color", HOVER_TOOLTIP_BORDER_COLOR))
	profile["text_color"] = _color_payload(profile.get("text_color", HOVER_TOOLTIP_TEXT_COLOR))
	profile["shadow_color"] = _color_payload(profile.get("shadow_color", HOVER_TOOLTIP_SHADOW_COLOR))
	profile["shadow_offset"] = _vector2_payload(profile.get("shadow_offset", HOVER_TOOLTIP_SHADOW_OFFSET))
	var card := _build_hover_tooltip_card(for_text)
	var margin := card.get_node_or_null("CardMargin") as MarginContainer
	var label := card.get_node_or_null("CardMargin/CardText") as Label
	var panel_style := card.get_theme_stylebox("panel") as StyleBoxFlat
	var result := {
		"profile": profile,
		"card_name": String(card.name),
		"card_mouse_filter": card.mouse_filter,
		"card_minimum_size": _vector2_payload(card.custom_minimum_size),
		"margin_name": String(margin.name) if margin != null else "",
		"margin_mouse_filter": margin.mouse_filter if margin != null else -1,
		"margins": {
			"left": margin.get_theme_constant("margin_left") if margin != null else -1,
			"right": margin.get_theme_constant("margin_right") if margin != null else -1,
			"top": margin.get_theme_constant("margin_top") if margin != null else -1,
			"bottom": margin.get_theme_constant("margin_bottom") if margin != null else -1,
		},
		"label_name": String(label.name) if label != null else "",
		"label_mouse_filter": label.mouse_filter if label != null else -1,
		"label_minimum_size": _vector2_payload(label.custom_minimum_size) if label != null else {},
		"label_autowrap_mode": label.autowrap_mode if label != null else -1,
		"label_overrun_behavior": label.text_overrun_behavior if label != null else -1,
		"label_max_lines": label.max_lines_visible if label != null else -1,
		"label_text": label.text if label != null else "",
		"panel_style": {
			"panel_color": _color_payload(panel_style.bg_color) if panel_style != null else {},
			"border_color": _color_payload(panel_style.border_color) if panel_style != null else {},
			"border_width": panel_style.border_width_left if panel_style != null else -1,
			"corner_radius": panel_style.corner_radius_top_left if panel_style != null else -1,
			"shadow_color": _color_payload(panel_style.shadow_color) if panel_style != null else {},
			"shadow_size": panel_style.shadow_size if panel_style != null else -1,
			"shadow_offset": _vector2_payload(panel_style.shadow_offset) if panel_style != null else {},
		},
	}
	card.free()
	return result

func validation_enemy_commander_presentation_profiles() -> Array:
	var profiles := []
	if _session == null:
		return profiles
	for encounter_value in _session.overworld.get("encounters", []):
		if not (encounter_value is Dictionary):
			continue
		var encounter: Dictionary = encounter_value
		if String(encounter.get("spawned_by_faction_id", "")).strip_edges() == "":
			continue
		var tile := Vector2i(int(encounter.get("x", -1)), int(encounter.get("y", -1)))
		if not _encounters_by_tile.has(_tile_key(tile)):
			continue
		profiles.append(_enemy_commander_presentation_payload(encounter))
	return profiles

func validation_encounter_presentation_payload(encounter: Dictionary) -> Dictionary:
	return _enemy_commander_presentation_payload(encounter)

func _enemy_commander_presentation_payload(encounter: Dictionary) -> Dictionary:
	var commander_state: Dictionary = encounter.get("enemy_commander_state", {}) if encounter.get("enemy_commander_state", {}) is Dictionary else {}
	var hero_id := String(commander_state.get("roster_hero_id", "")).strip_edges()
	var commander_faction_id := String(commander_state.get("faction_id", "")).strip_edges()
	var spawned_faction_id := String(encounter.get("spawned_by_faction_id", "")).strip_edges()
	var authored_hero := ContentService.get_hero(hero_id)
	var authored_faction_id := String(authored_hero.get("faction_id", "")).strip_edges()
	var resolved_hero := _enemy_commander_hero_template(encounter)
	var sprite_asset_id := _hero_sprite_asset_id(resolved_hero)
	var unit_id := _encounter_primary_unit_id(encounter)
	var unit_icon_path := _encounter_overworld_icon_path(encounter)
	var unit_icon_loaded := unit_icon_path != "" and _unit_art_texture(unit_icon_path) is Texture2D
	var identity_encounter_asset_id := _encounter_identity_asset_id(encounter)
	var identity_encounter_path := String(_object_asset_paths.get(identity_encounter_asset_id, ""))
	var identity_encounter_loaded := identity_encounter_asset_id != "" and _object_texture_for_asset(identity_encounter_asset_id) is Texture2D
	var faction_encounter_asset_id := _encounter_faction_asset_id(encounter)
	var faction_encounter_path := String(_object_asset_paths.get(faction_encounter_asset_id, ""))
	var faction_encounter_loaded := faction_encounter_asset_id != "" and _object_texture_for_asset(faction_encounter_asset_id) is Texture2D
	var encounter_asset_id := _encounter_asset_id(encounter)
	var encounter_asset_loaded := encounter_asset_id != "" and _object_texture_for_asset(encounter_asset_id) is Texture2D
	var prefer_identity_landmark := bool(encounter.get("prefer_identity_landmark", false)) and identity_encounter_loaded
	var tile := Vector2i(int(encounter.get("x", -1)), int(encounter.get("y", -1)))
	var tile_rect := _tile_rect(_board_rect(), tile)
	var ground_center := tile_rect.position + tile_rect.size * Vector2(0.50, _procedural_ground_center_y_factor("encounter"))
	var presentation_extent := OBJECT_FACTION_ENCOUNTER_VISIBLE_EXTENT_TILES if prefer_identity_landmark or (sprite_asset_id == "" and (identity_encounter_loaded or faction_encounter_loaded)) else OBJECT_ENCOUNTER_VISIBLE_EXTENT_TILES
	var hostile_layout := _hostile_actor_layout(tile_rect, ground_center, false, presentation_extent)
	var hostile_marker_profile: Dictionary = hostile_layout.get("marker_profile", {})
	return {
		"placement_id": String(encounter.get("placement_id", "")),
		"hero_id": hero_id,
		"commander_faction_id": commander_faction_id,
		"spawned_by_faction_id": spawned_faction_id,
		"authored_faction_id": authored_faction_id,
		"sprite_asset_id": sprite_asset_id,
		"sprite_path": String(_object_asset_paths.get(sprite_asset_id, "")),
		"primary_unit_id": unit_id,
		"unit_icon_path": unit_icon_path,
		"identity_encounter_asset_id": identity_encounter_asset_id,
		"identity_encounter_path": identity_encounter_path,
		"faction_encounter_asset_id": faction_encounter_asset_id,
		"faction_encounter_path": faction_encounter_path,
		"encounter_asset_id": encounter_asset_id,
		"prefer_identity_landmark": prefer_identity_landmark,
		"uses_commander_sprite": sprite_asset_id != "" and not prefer_identity_landmark,
		"uses_identity_encounter_sprite": sprite_asset_id == "" and identity_encounter_loaded or prefer_identity_landmark,
		"uses_faction_encounter_sprite": sprite_asset_id == "" and not identity_encounter_loaded and faction_encounter_loaded and not prefer_identity_landmark,
		"uses_unit_icon_fallback": sprite_asset_id == "" and not identity_encounter_loaded and not faction_encounter_loaded and unit_icon_loaded and not prefer_identity_landmark,
		"uses_encounter_sprite_fallback": sprite_asset_id == "" and not identity_encounter_loaded and not faction_encounter_loaded and not unit_icon_loaded and encounter_asset_loaded and not prefer_identity_landmark,
		"hostile_treatment": HOSTILE_ACTOR_MARKER_MODEL,
		"hostile_marker_profile": _hostile_actor_marker_validation_payload(hostile_marker_profile),
		"visible_extent_tiles": OBJECT_ENCOUNTER_VISIBLE_EXTENT_TILES,
		"faction_landmark_visible_extent_tiles": OBJECT_FACTION_ENCOUNTER_VISIBLE_EXTENT_TILES,
		"grounding_model": OBJECT_PROCEDURAL_GROUNDING_MODEL,
		"contact_model": OBJECT_PROCEDURAL_CONTACT_MODEL,
	}

func _hero_presentation_payload(tile: Vector2i, explored: bool) -> Dictionary:
	if not explored:
		return {}
	var hero := _hero_presentation_entry(tile)
	if hero.is_empty():
		return {}
	var hero_id := String(hero.get("id", "")).strip_edges()
	var faction_id := _hero_template_faction_id(hero)
	var sprite_asset_id := _hero_sprite_asset_id(hero)
	var layout := _hero_draw_layout_payload(_tile_rect(_board_rect(), tile), tile, true)
	return {
		"hero_id": hero_id,
		"scale_hierarchy_model": WORLD_OBJECT_SCALE_HIERARCHY_MODEL,
		"tile": {"x": tile.x, "y": tile.y},
		"faction_id": faction_id,
		"is_active": bool(hero.get("is_active", false)),
		"sprite_asset_id": sprite_asset_id,
		"sprite_path": String(_object_asset_paths.get(sprite_asset_id, "")),
		"uses_identity_sprite": hero_id != "" and String(_hero_identity_asset_ids.get(hero_id, "")) == sprite_asset_id,
		"uses_faction_sprite": faction_id != "" and String(_hero_faction_asset_ids.get(faction_id, "")) == sprite_asset_id,
		"uses_procedural_fallback": sprite_asset_id == "",
		"reserve_count": _reserve_hero_count(tile),
		"grounding_model": HERO_GROUNDING_MODEL,
		"depth_cue_model": HERO_DEPTH_CUE_MODEL,
		"sprite_silhouette_model": WORLD_SPRITE_SILHOUETTE_MODEL,
		"command_pennant_model": HERO_COMMAND_PENNANT_MODEL,
		"layout": layout,
	}

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
	var footprint_rect := _town_footprint_rect_for_entry(_town_entry_tile(town))
	payload["owner_pennant"] = _town_owner_pennant_validation_payload(
		_town_owner_pennant_profile(
			footprint_rect,
			_town_owner_color(town),
			not visible,
			_town_owner_id(town),
			FrontierVisualKitScript.color_cue_assist_enabled()
		),
		footprint_rect
	)
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
	var faction_id := _town_template_faction_id(town)
	var sprite_asset_id := _town_sprite_asset_id(town)
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
		"scale_hierarchy_model": WORLD_OBJECT_SCALE_HIERARCHY_MODEL,
		"presentation_model": TOWN_PRESENTATION_MODEL,
		"footprint_width_tiles": TOWN_PRESENTATION_FOOTPRINT.x,
		"footprint_height_tiles": TOWN_PRESENTATION_FOOTPRINT.y,
		"visual_footprint_width_tiles": TOWN_VISUAL_FOOTPRINT.x,
		"visual_footprint_height_tiles": TOWN_VISUAL_FOOTPRINT.y,
		"visual_anchor_model": TOWN_VISUAL_ANCHOR_MODEL,
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
		"faction_id": faction_id,
		"sprite_asset_id": sprite_asset_id,
		"sprite_path": String(_object_asset_paths.get(sprite_asset_id, "")),
		"uses_identity_sprite": String(_town_identity_asset_ids.get(String(town.get("town_id", "")).strip_edges(), "")) == sprite_asset_id,
		"uses_faction_sprite": faction_id != "" and String(_town_faction_asset_ids.get(faction_id, "")) == sprite_asset_id,
		"uses_default_sprite": sprite_asset_id == _town_default_asset_id,
		"visual_sprite_extent_fraction_of_footprint": TOWN_SPRITE_EXTENT_FACTOR,
		"visual_sprite_extent_tiles": TOWN_SPRITE_EXTENT_FACTOR * float(mini(TOWN_VISUAL_FOOTPRINT.x, TOWN_VISUAL_FOOTPRINT.y)),
		"owner_pennant_model": TOWN_OWNER_PENNANT_MODEL,
		"owner_pennant_single_pass": true,
		"owner_pennant_width_factor": TOWN_OWNER_PENNANT_WIDTH_FACTOR,
		"owner_pennant_height_factor": TOWN_OWNER_PENNANT_HEIGHT_FACTOR,
		"sprite_silhouette_model": WORLD_SPRITE_SILHOUETTE_MODEL,
		"sprite_silhouette_width_factor": TOWN_SPRITE_SILHOUETTE_WIDTH_FACTOR,
		"sprite_silhouette_visible_alpha": TOWN_SPRITE_SILHOUETTE_VISIBLE.a,
		"sprite_silhouette_memory_alpha": TOWN_SPRITE_SILHOUETTE_MEMORY.a,
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
		var unexplored_texture = _unexplored_shroud_texture()
		var unexplored_texture_loaded := unexplored_texture is Texture2D
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
			"visible_terrain_grid_mode": "hidden_fog_shroud",
			"visible_terrain_grid_alpha": 0.0,
			"explored_intertile_seams": false,
			"unexplored_wireframe": false,
			"unexplored_wireframe_alpha": 0.0,
			"unexplored_shroud": true,
			"unexplored_shroud_model": UNEXPLORED_SHROUD_MODEL,
			"unexplored_shroud_layer_count": UNEXPLORED_SHROUD_LAYER_COUNT,
			"unexplored_shroud_contained": true,
			"unexplored_shroud_seed_basis": "none_contiguous",
			"unexplored_shroud_repeated_stamps": false,
			"unexplored_shroud_texture_loaded": unexplored_texture_loaded,
			"unexplored_shroud_texture_path": UNEXPLORED_SHROUD_TEXTURE_PATH if unexplored_texture_loaded else "",
			"unexplored_shroud_texture_size": {"x": UNEXPLORED_SHROUD_TEXTURE_SIZE.x, "y": UNEXPLORED_SHROUD_TEXTURE_SIZE.y},
			"unexplored_shroud_texture_modulate_alpha": UNEXPLORED_SHROUD_TEXTURE_MODULATE.a,
			"unexplored_shroud_texture_mapping": "whole_board_normalized_once_clipped_by_hidden_cells",
			"unexplored_shroud_texture_source_rect": _rect_payload(_unexplored_shroud_source_rect(tile)),
			"unexplored_shroud_texture_terrain_identity_sampled": false,
			"fog_boundary_alpha": 0.0,
			"fog_frontier": {
				"model": EXPLORED_FOG_FRONTIER_MODEL,
				"drawn": false,
				"draw_side": "explored_inward",
				"hidden_identity_sampled": false,
			},
			"terrain_macro_lighting": {
				"model": TERRAIN_MACRO_LIGHTING_MODEL,
				"drawn": false,
				"hidden_by_unexplored_shroud": true,
			},
			"water_shoreline_contour": {
				"model": WATER_SHORELINE_CONTOUR_MODEL,
				"active": false,
				"source_count": 0,
				"hidden_by_unexplored_shroud": true,
			},
			"terrain_grain_overlay": _terrain_grain_overlay_payload(false),
			"terrain_microtexture": {
				"model": TERRAIN_MICROTEXTURE_MODEL,
				"drawn": false,
				"hidden_by_unexplored_shroud": true,
				"terrain_identity_sampled": false,
			},
			"terrain_detail_decal": {
				"model": TERRAIN_DETAIL_DECAL_MODEL,
				"drawn": false,
				"hidden_by_unexplored_shroud": true,
				"terrain_identity_sampled": false,
			},
			"water_surface_ripples": {
				"model": WATER_SURFACE_RIPPLE_MODEL,
				"drawn": false,
				"hidden_by_unexplored_shroud": true,
				"terrain_identity_sampled": false,
			},
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
	var homm3_selection: Dictionary = _homm3_terrain_selection_payload(tile, terrain)
	var tile_art_primary := _terrain_art_can_be_primary(terrain)
	var tile_art_loaded := tile_art_primary and _terrain_art_texture(tile_art_path) is Texture2D
	var selected_homm3_payload: Dictionary = tile_art_entry.get("homm3_selection", {}) if tile_art_entry.get("homm3_selection", {}) is Dictionary else {}
	var homm3_rendering_active: bool = _homm3_runtime_rendering_enabled() and tile_art_loaded and not selected_homm3_payload.is_empty()
	var edge_art_count := _transition_edge_art_count(transition_payload)
	var edge_transition_count := _transition_source_count(transition_payload, "cardinal_sources")
	var corner_transition_count := _transition_source_count(transition_payload, "corner_sources")
	var propagated_transition_count := _transition_source_count(transition_payload, "propagated_sources")
	var transition_relationship_count := edge_transition_count + corner_transition_count + propagated_transition_count
	var homm3_transition_self_contained := _terrain_uses_self_contained_homm3_transition(tile, terrain)
	var generic_transition_payload := _terrain_generic_transition_payload(tile)
	var generic_transition_overlay_relationship_count := (
		_transition_source_count(generic_transition_payload, "cardinal_sources")
		+ _transition_source_count(generic_transition_payload, "corner_sources")
	)
	var generic_transition_overlay_active := generic_transition_overlay_relationship_count > 0 and not homm3_transition_self_contained
	var water_shoreline_contour := _water_shoreline_contour_payload(tile, generic_transition_payload) if generic_transition_overlay_active else {
		"model": WATER_SHORELINE_CONTOUR_MODEL,
		"active": false,
		"source_count": 0,
	}
	var road_neighbor_directions := _road_neighbor_directions(tile) if not road_payload.is_empty() else []
	var road_art_loaded := _road_overlay_art_loaded(road_payload, tile)
	var road_connection_piece_loaded := _road_connection_piece_loaded(road_payload, tile)
	var road_render_model := _road_render_model(tile, road_payload) if not road_payload.is_empty() else ""
	var road_explicit_source_frame_rendered := road_render_model == ROAD_SOURCE_FRAME_RENDER_MODEL
	var road_source_frame_path := _road_explicit_source_frame_path(tile, road_payload) if road_explicit_source_frame_rendered else ""
	var road_joint_cap := _road_needs_joint_cap(road_neighbor_directions) if not road_payload.is_empty() else false
	var road_connection_key := _road_connection_key_from_directions(road_neighbor_directions) if not road_payload.is_empty() else ""
	var road_has_horizontal := _road_has_horizontal_connections(road_neighbor_directions)
	var road_has_vertical := _road_has_vertical_connections(road_neighbor_directions)
	var road_has_diagonal := _road_has_diagonal_connections(road_neighbor_directions)
	var terrain_macro_lighting := _terrain_macro_lighting_payload(tile)
	var fog_frontier := _explored_fog_frontier_payload(tile)
	terrain_macro_lighting["drawn"] = true
	var primary_base_model := TERRAIN_HOMM3_LOCAL_PROTOTYPE_RENDERING_MODE if homm3_rendering_active else (TERRAIN_ORIGINAL_TILE_BANK_RENDERING_MODE if tile_art_loaded else (TERRAIN_GRAMMAR_RENDERING_MODE if not _terrain_style(terrain).is_empty() else "procedural_color_pattern"))
	return {
		"terrain": terrain,
		"state": "explored_visible",
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
		"unexplored_wireframe_alpha": 0.0,
		"unexplored_shroud": false,
		"unexplored_shroud_model": "",
		"unexplored_shroud_layer_count": 0,
		"unexplored_shroud_contained": false,
		"unexplored_shroud_seed_basis": "",
		"unexplored_shroud_repeated_stamps": false,
		"fog_boundary_alpha": EXPLORED_TERRAIN_FOG_BOUNDARY_COLOR.a,
		"fog_frontier": fog_frontier,
		"terrain_macro_lighting": terrain_macro_lighting,
		"water_shoreline_contour": water_shoreline_contour,
		"terrain_grain_overlay": _terrain_grain_overlay_payload(true),
		"terrain_microtexture": {
			"model": TERRAIN_MICROTEXTURE_MODEL,
			"drawn": _terrain_group(terrain) != "water",
			"stroke_count": TERRAIN_MICROTEXTURE_STROKE_COUNT if _terrain_group(terrain) != "water" else 0,
			"min_length_factor": TERRAIN_MICROTEXTURE_MIN_LENGTH_FACTOR,
			"max_length_factor": TERRAIN_MICROTEXTURE_MAX_LENGTH_FACTOR,
			"shadow_alpha": TERRAIN_MICROTEXTURE_SHADOW_ALPHA,
			"highlight_alpha": TERRAIN_MICROTEXTURE_HIGHLIGHT_ALPHA,
			"interactive": false,
			"collision": false,
			"variation_basis": "tile_coordinate_terrain_id_and_stroke_index_only",
			"draw_order": "after_base_tile_before_terrain_transitions_grain_decals_roads_objects_and_fog",
			"hidden_by_unexplored_shroud": true,
		},
		"terrain_detail_decal": _terrain_detail_decal_payload(tile, Rect2(Vector2.ZERO, Vector2.ONE)),
		"water_surface_ripples": _water_surface_ripple_payload(tile, Rect2(Vector2.ZERO, Vector2.ONE)),
		"uses_sampled_texture": false,
		"uses_authored_tile_art": tile_art_loaded,
		"uses_original_tile_bank": tile_art_loaded and not homm3_rendering_active,
		"uses_homm3_local_prototype": homm3_rendering_active,
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
		"terrain_noise_profile": "homm3_extracted_atlas_frame" if homm3_rendering_active else ("quiet_low_contrast_macro_readable" if tile_art_loaded else "grammar_pattern_fallback"),
		"terrain_variant_selection": "accepted_web_relation_class_row_lookup" if homm3_rendering_active else ("patch_cohesive_low_frequency" if tile_art_loaded else "procedural_fallback_marks"),
		"grasslands_base_cohesion": "homm3_grass_atlas_family" if _terrain_group(terrain) == "grasslands" and homm3_rendering_active else ("grass_plains_shared_palette" if _terrain_group(terrain) == "grasslands" and tile_art_loaded else ""),
		"homm3_local_reference_only": bool(homm3_selection.get("local_reference_only", false)),
		"homm3_terrain_lookup_model": String(homm3_selection.get("terrain_lookup_model", "")),
		"homm3_logical_terrain_id": String(homm3_selection.get("logical_terrain_id", terrain)),
		"homm3_terrain_family": String(homm3_selection.get("family", "")),
		"homm3_renderer_family": String(homm3_selection.get("renderer_family", "")),
		"homm3_terrain_atlas": String(homm3_selection.get("atlas_id", "")),
		"homm3_asset_root": String(homm3_selection.get("asset_root", "")),
		"homm3_asset_root_mode": String(homm3_selection.get("asset_root_mode", "")),
		"homm3_runtime_asset_source_basis": String(homm3_selection.get("runtime_asset_source_basis", "")),
		"homm3_expected_frame_count": int(homm3_selection.get("expected_frame_count", 0)),
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
		"transition_relationship_count": transition_relationship_count,
		"transition_draw_policy": TERRAIN_TRANSITION_DRAW_POLICY,
		"homm3_transition_self_contained": homm3_transition_self_contained,
		"generic_transition_overlay_relationship_count": generic_transition_overlay_relationship_count,
		"generic_transition_overlay_active": generic_transition_overlay_active,
		"generic_transition_surface_model": GENERIC_TERRAIN_EDGE_SURFACE_MODEL if generic_transition_overlay_active else "",
		"generic_transition_feather_band_count": GENERIC_TERRAIN_EDGE_FEATHER_BAND_COUNT if generic_transition_overlay_active else 0,
		"generic_transition_irregular_inner_edge": generic_transition_overlay_active,
		"generic_transition_deterministic_seed_basis": "tile_and_direction_only" if generic_transition_overlay_active else "",
		"edge_transition_count": edge_transition_count,
		"corner_transition_count": corner_transition_count,
		"propagated_transition_count": propagated_transition_count,
		"transition_uses_second_ring": bool(homm3_selection.get("uses_second_ring", false)) if not homm3_selection.is_empty() else false,
		"transition_diagonal_policy": String(homm3_selection.get("diagonal_policy", "")),
		"edge_transition_art_count": edge_art_count,
		"edge_transition_art_loaded": edge_transition_count > 0 and edge_art_count == edge_transition_count,
		"transition_shape_model": "homm3_base_atlas_frame" if homm3_rendering_active else ("jagged_directional_overlay" if edge_art_count > 0 else GENERIC_TERRAIN_EDGE_SURFACE_MODEL),
		"transition_edge_treatment": "bridge_or_shoreline_encoded_in_selected_tile" if homm3_rendering_active else ("soft_feathered_jagged_overlay" if edge_art_count > 0 else "shallow_irregular_feather_bands"),
		"transition_selection_rule": "settled_owner_relation_classes_select_recovered_row_buckets" if homm3_rendering_active else "higher_priority_neighbor_intrudes_into_lower_priority_receiver",
		"higher_priority_neighbor_intrusion": edge_transition_count > 0 or corner_transition_count > 0 or propagated_transition_count > 0,
		"same_group_transition_suppressed": true,
		"road_overlay": not road_payload.is_empty(),
		"road_overlay_id": String(road_payload.get("overlay_id", "")),
		"road_role": String(road_payload.get("role", "")),
		"road_overlay_art": road_art_loaded,
		"road_render_model": road_render_model,
		"road_explicit_source_frame_rendered": road_explicit_source_frame_rendered,
		"road_source_frame_path": road_source_frame_path,
		"road_ordinary_tile_art_bypassed": not road_payload.is_empty() and not road_explicit_source_frame_rendered,
		"road_surface_material": "weathered_cross_planked_timber" if road_render_model == ROAD_WATER_RENDER_MODEL else ("packed_earth_with_twin_wheel_ruts" if road_render_model == ROAD_LAND_RENDER_MODEL else "source_frame"),
		"road_surface_detail": "cross_plank_seams_and_longitudinal_grain" if road_render_model == ROAD_WATER_RENDER_MODEL else ("soft_shoulders_twin_ruts_and_dust_center" if road_render_model == ROAD_LAND_RENDER_MODEL else "source_owned"),
		"road_shape_model": "homm3_4_neighbor_overlay_lookup" if road_explicit_source_frame_rendered else ("terrain_integrated_4_neighbor_surface" if not road_payload.is_empty() else ""),
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
	var decorative_object := _decorative_object_at(tile)
	if not decorative_object.is_empty():
		var decorative_asset_id := _decorative_object_asset_id(decorative_object)
		if decorative_asset_id != "" and _object_texture_for_asset(decorative_asset_id) is Texture2D:
			sprite_asset_ids.append(decorative_asset_id)
			var decorative_footprint := _object_profile_footprint(_decorative_object_profile(decorative_object))
			sprite_footprints.append({"width": decorative_footprint.x, "height": decorative_footprint.y})
	var standalone_map_object := _standalone_map_object_at(tile)
	if not standalone_map_object.is_empty():
		var standalone_asset_id := _standalone_map_object_asset_id(standalone_map_object)
		if standalone_asset_id != "" and _object_texture_for_asset(standalone_asset_id) is Texture2D:
			sprite_asset_ids.append(standalone_asset_id)
			var standalone_footprint := _object_profile_footprint(_standalone_map_object_profile(standalone_map_object))
			sprite_footprints.append({"width": standalone_footprint.x, "height": standalone_footprint.y})
	if "town" in object_kinds:
		var town_asset_id := _town_sprite_asset_id(_town_at(tile))
		if town_asset_id != "" and _object_texture_for_asset(town_asset_id) is Texture2D:
			sprite_asset_ids.append(town_asset_id)
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
	if not artifact_node.is_empty():
		var artifact_asset_id := _artifact_sprite_asset_id(artifact_node)
		if artifact_asset_id != "" and _object_texture_for_asset(artifact_asset_id) is Texture2D:
			sprite_asset_ids.append(artifact_asset_id)
			var artifact_footprint := _object_profile_footprint(_artifact_object_profile())
			sprite_footprints.append({"width": artifact_footprint.x, "height": artifact_footprint.y})
	var encounter_payload := _encounter_node_at(tile)
	if not encounter_payload.is_empty():
		var encounter_asset_id := _encounter_identity_asset_id(encounter_payload) if bool(encounter_payload.get("prefer_identity_landmark", false)) else _encounter_asset_id(encounter_payload)
		if encounter_asset_id != "" and _object_texture_for_asset(encounter_asset_id) is Texture2D:
			sprite_asset_ids.append(encounter_asset_id)
			var encounter_footprint := _object_profile_footprint(_encounter_object_profile())
			sprite_footprints.append({"width": encounter_footprint.x, "height": encounter_footprint.y})
	var uses_asset_sprite := not sprite_asset_ids.is_empty()
	var uses_town_sprite := "town" in object_kinds and _town_sprite_asset_id(_town_at(tile)) in sprite_asset_ids
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
		"unexplored_wireframe_alpha": 0.0,
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
		"hero_focus_visual_model": HERO_COMMAND_FOCUS_VISUAL_MODEL if has_visible_hero else "",
		"hero_focus_continuous_outline": false if has_visible_hero else null,
		"hero_focus_interior_fill_alpha": 0.0 if has_visible_hero else null,
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
		"decorative_object":
			return OBJECT_SPRITE_EXTENT_FACTOR
		"map_object":
			return OBJECT_SPRITE_EXTENT_FACTOR
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
	if _homm3_runtime_rendering_enabled() and not _homm3_terrain_config(terrain_id).is_empty():
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
	if _homm3_runtime_rendering_enabled() and _homm3_road_overlays.has(overlay_id):
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
	if not _homm3_runtime_rendering_enabled():
		return ""
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

func _h3maped_road_art_path_from_payload(road: Dictionary) -> String:
	if not _homm3_runtime_rendering_enabled():
		return ""
	var frame_id := String(road.get("h3maped_road_art_frame_id", "")).strip_edges()
	if frame_id == "":
		return ""
	var atlas_id := String(road.get("h3maped_road_atlas", "dirtrd")).strip_edges()
	if atlas_id == "":
		atlas_id = "dirtrd"
	return "%s/roads/%s/%s.png" % [_homm3_asset_root(), atlas_id, frame_id]

func _homm3_asset_root() -> String:
	return String(_homm3_prototype.get("asset_root", "res://art/overworld/runtime/homm3_local_prototype")).strip_edges()

func _homm3_runtime_rendering_enabled() -> bool:
	return bool(_homm3_prototype.get("enabled", false))

func _homm3_family_asset_root(family: Dictionary) -> String:
	var family_root := String(family.get("asset_root", "")).strip_edges()
	return family_root if family_root != "" else _homm3_asset_root()

func _homm3_terrain_frame_path(family: Dictionary, atlas_id: String, frame_id: String) -> String:
	var asset_root := _homm3_family_asset_root(family)
	var asset_root_mode := String(family.get("asset_root_mode", "prototype_terrain_atlas_directory")).strip_edges()
	if asset_root_mode == "flat_frame_directory":
		return "%s/%s.png" % [asset_root, frame_id]
	return "%s/terrain/%s/%s.png" % [asset_root, atlas_id, frame_id]

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

func _vector2_payload(value: Vector2) -> Dictionary:
	return {"x": value.x, "y": value.y}

func _vector2_array_payload(values: PackedVector2Array) -> Array:
	var payloads: Array = []
	for value in values:
		payloads.append(_vector2_payload(value))
	return payloads

func _vector2i_payloads(values: Array) -> Array:
	var payloads: Array = []
	for value in values:
		if value is Vector2i:
			payloads.append(_vector2i_payload(value))
	return payloads

func _homm3_terrain_art_entry(terrain_id: String, tile: Vector2i) -> Dictionary:
	if not _homm3_runtime_rendering_enabled():
		return {}
	var selection := _homm3_terrain_selection_payload(tile, terrain_id)
	var frame_id := String(selection.get("frame_id", "")).strip_edges()
	var atlas_id := String(selection.get("atlas_id", "")).strip_edges()
	if atlas_id == "" or frame_id == "":
		return {}
	var family := _homm3_terrain_family_config(String(selection.get("family", "")))
	var path := _homm3_terrain_frame_path(family, atlas_id, frame_id)
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
	var family_asset_root := _homm3_family_asset_root(family)
	var family_source_basis := String(family.get("runtime_asset_source_basis", TERRAIN_HOMM3_SOURCE_BASIS)).strip_edges()
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
		"asset_root": family_asset_root,
		"asset_root_mode": String(family.get("asset_root_mode", "prototype_terrain_atlas_directory")),
		"runtime_asset_source_basis": family_source_basis,
		"expected_frame_count": int(family.get("expected_frame_count", 0)),
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
	return _terrain_generic_transition_payload(tile)

func _terrain_generic_transition_payload(tile: Vector2i) -> Dictionary:
	var terrain := _terrain_at(tile)
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
			_ensure_road_tile_payload(tile, overlay_id, road_id, role, tile_value)
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
		_decorative_objects_by_tile.clear()
		_generated_decorative_bodies_by_tile.clear()
		_standalone_map_objects_by_tile.clear()
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
		"decorative_object_tiles": _decorative_objects_by_tile.size(),
		"generated_decorative_body_tiles": _generated_decorative_bodies_by_tile.size(),
		"standalone_map_object_tiles": _standalone_map_objects_by_tile.size(),
		"hero_tiles": _heroes_by_tile.size(),
	})

func _rebuild_static_object_indexes() -> void:
	_towns_by_tile.clear()
	_town_footprints_by_tile.clear()
	_resources_by_tile.clear()
	_artifacts_by_tile.clear()
	_encounters_by_tile.clear()
	_rememberable_encounters_by_tile.clear()
	_decorative_objects_by_tile.clear()
	_generated_decorative_bodies_by_tile.clear()
	_standalone_map_objects_by_tile.clear()
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
		var repeatable := bool(site.get("repeatable", false)) or String(site.get("family", "")) == "repeatable_service"
		if bool(site.get("persistent_control", false)) or repeatable or not bool(node.get("collected", false)):
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
	for object_value in _session.overworld.get("map_objects", []):
		if not (object_value is Dictionary):
			continue
		var object: Dictionary = object_value
		if not _is_decorative_object_placement(object):
			if not _is_standalone_map_object_placement(object):
				continue
			var standalone_tile := Vector2i(int(object.get("x", -1)), int(object.get("y", -1)))
			if standalone_tile.x < 0 or standalone_tile.y < 0 or standalone_tile.x >= _map_size.x or standalone_tile.y >= _map_size.y:
				continue
			_standalone_map_objects_by_tile[_tile_key(standalone_tile)] = object
			continue
		var tile := Vector2i(int(object.get("x", -1)), int(object.get("y", -1)))
		if tile.x < 0 or tile.y < 0 or tile.x >= _map_size.x or tile.y >= _map_size.y:
			continue
		var package_block_tiles = object.get("package_block_tiles", null)
		var uses_generated_body: bool = String(object.get("runtime_object_role", "")).strip_edges() == "decorative_blocker_sprite" \
			and package_block_tiles is Array \
			and not package_block_tiles.is_empty()
		if uses_generated_body:
			# The package x/y value is the legacy DEF anchor, not another visible
			# world object. Indexing it separately drew an orphan procedural ruin
			# beside the authoritative raster body whenever it sat outside the
			# package's blocking cells.
			_index_generated_decorative_body_cells(object)
			continue
		_decorative_objects_by_tile[_tile_key(tile)] = object

func _index_generated_decorative_body_cells(object: Dictionary) -> void:
	if String(object.get("runtime_object_role", "")).strip_edges() != "decorative_blocker_sprite":
		return
	var package_block_tiles = object.get("package_block_tiles", null)
	if not (package_block_tiles is Array) or package_block_tiles.is_empty():
		return
	var source_placement_id := String(object.get("placement_id", "")).strip_edges()
	var body_tiles: Array = []
	var min_tile := Vector2i(_map_size.x, _map_size.y)
	var max_tile := Vector2i(-1, -1)
	for tile_value in _tiles_from_payloads(package_block_tiles):
		if not (tile_value is Vector2i):
			continue
		var body_tile: Vector2i = tile_value
		if body_tile.x < 0 or body_tile.y < 0 or body_tile.x >= _map_size.x or body_tile.y >= _map_size.y:
			continue
		if body_tile in body_tiles:
			continue
		body_tiles.append(body_tile)
		min_tile = Vector2i(mini(min_tile.x, body_tile.x), mini(min_tile.y, body_tile.y))
		max_tile = Vector2i(maxi(max_tile.x, body_tile.x), maxi(max_tile.y, body_tile.y))
	if body_tiles.is_empty():
		return
	for body_tile_value in body_tiles:
		var body_tile: Vector2i = body_tile_value
		var key := _tile_key(body_tile)
		if _generated_decorative_bodies_by_tile.has(key):
			var existing: Dictionary = _generated_decorative_bodies_by_tile.get(key, {})
			var placement_ids: Array = existing.get("generated_body_source_placement_ids", [])
			if source_placement_id != "" and source_placement_id not in placement_ids:
				placement_ids.append(source_placement_id)
			existing["generated_body_source_placement_ids"] = placement_ids
			existing["generated_body_source_count"] = placement_ids.size()
			_generated_decorative_bodies_by_tile[key] = existing
			continue
		var presentation: Dictionary = object.duplicate(true)
		presentation["x"] = body_tile.x
		presentation["y"] = body_tile.y
		presentation["primary_tile"] = {"x": body_tile.x, "y": body_tile.y, "level": int(object.get("level", 0))}
		presentation["footprint"] = {"width": 1, "height": 1, "anchor": "bottom_center"}
		presentation["generated_decorative_body_cell"] = true
		presentation["generated_body_visual_anchor"] = false
		presentation["generated_body_presentation_model"] = GENERATED_DECORATIVE_BODY_PRESENTATION_MODEL
		presentation["generated_body_source_placement_ids"] = [source_placement_id] if source_placement_id != "" else []
		presentation["generated_body_source_count"] = 1
		_generated_decorative_bodies_by_tile[key] = presentation
	var desired_anchor_count := 1
	if body_tiles.size() >= 9:
		desired_anchor_count = 3
	elif body_tiles.size() >= 5:
		desired_anchor_count = 2
	var selected_anchor_tiles: Array = []
	for anchor_index in range(desired_anchor_count):
		var target_x := lerpf(float(min_tile.x), float(max_tile.x), (float(anchor_index) + 0.5) / float(desired_anchor_count))
		var best_tile := Vector2i(-1, -1)
		var best_score := INF
		for body_tile_value in body_tiles:
			var candidate: Vector2i = body_tile_value
			if candidate in selected_anchor_tiles:
				continue
			var existing: Dictionary = _generated_decorative_bodies_by_tile.get(_tile_key(candidate), {})
			if bool(existing.get("generated_body_visual_anchor", false)):
				continue
			var score := absf(float(candidate.x) - target_x) * 100.0 + float(max_tile.y - candidate.y) * 12.0 + float(candidate.x) * 0.001
			if score < best_score:
				best_score = score
				best_tile = candidate
		if best_tile.x >= 0:
			selected_anchor_tiles.append(best_tile)
	var placement_bounds := {
		"min_x": min_tile.x,
		"min_y": min_tile.y,
		"max_x": max_tile.x,
		"max_y": max_tile.y,
	}
	var placement_footprint := Vector2i(max_tile.x - min_tile.x + 1, max_tile.y - min_tile.y + 1)
	for anchor_index in range(selected_anchor_tiles.size()):
		var anchor_tile: Vector2i = selected_anchor_tiles[anchor_index]
		var key := _tile_key(anchor_tile)
		var existing: Dictionary = _generated_decorative_bodies_by_tile.get(key, {})
		var source_ids: Array = existing.get("generated_body_source_placement_ids", []).duplicate(true)
		if source_placement_id != "" and source_placement_id not in source_ids:
			source_ids.append(source_placement_id)
		var presentation: Dictionary = object.duplicate(true)
		presentation["x"] = anchor_tile.x
		presentation["y"] = anchor_tile.y
		presentation["primary_tile"] = {"x": anchor_tile.x, "y": anchor_tile.y, "level": int(object.get("level", 0))}
		presentation["bounds"] = placement_bounds.duplicate(true)
		presentation["footprint"] = {"width": placement_footprint.x, "height": placement_footprint.y, "anchor": "bottom_center"}
		presentation["overworld_sprite_asset_id"] = _generated_decorative_body_asset_id(object, anchor_tile)
		presentation["generated_body_motif_key"] = _generated_decorative_body_motif_key(object, anchor_tile)
		var composition := _generated_decorative_body_composition(
			object,
			anchor_tile,
			min_tile,
			placement_footprint,
			body_tiles.size(),
			anchor_index,
			selected_anchor_tiles.size()
		)
		presentation["generated_body_scale_factor"] = float(composition.get("scale_factor", 1.0))
		presentation["generated_body_offset_tiles"] = composition.get("offset_tiles", {}).duplicate(true)
		presentation["generated_body_sprite_extent_tiles"] = float(composition.get("sprite_extent_tiles", GENERATED_DECORATIVE_BODY_SPRITE_EXTENT_TILES))
		presentation["generated_body_sprite_center_tiles"] = composition.get("sprite_center_tiles", {}).duplicate(true)
		presentation["generated_body_composition_key"] = String(composition.get("composition_key", ""))
		presentation["generated_decorative_body_cell"] = true
		presentation["generated_body_visual_anchor"] = true
		presentation["generated_body_presentation_model"] = GENERATED_DECORATIVE_BODY_PRESENTATION_MODEL
		presentation["generated_body_source_placement_ids"] = source_ids
		presentation["generated_body_source_count"] = source_ids.size()
		presentation["generated_body_anchor_placement_id"] = source_placement_id
		presentation["generated_body_anchor_index"] = anchor_index
		presentation["generated_body_anchor_count"] = selected_anchor_tiles.size()
		presentation["generated_body_placement_tile_count"] = body_tiles.size()
		_generated_decorative_bodies_by_tile[key] = presentation

func _generated_decorative_body_asset_id(object: Dictionary, tile: Vector2i) -> String:
	var terrain_id := _terrain_at(tile)
	var biome_id := String(GENERATED_DECORATIVE_BIOME_BY_TERRAIN.get(terrain_id, ""))
	var candidates: Array = _generated_decorative_blocker_asset_ids_by_biome.get(biome_id, [])
	if candidates.is_empty():
		candidates = _generated_decorative_blocker_fallback_asset_ids
	if candidates.is_empty():
		return ""
	var stable_key := _generated_decorative_body_motif_key(object, tile)
	return String(candidates[absi(stable_key.hash()) % candidates.size()])

func _generated_decorative_body_motif_key(object: Dictionary, tile: Vector2i) -> String:
	var terrain_id := _terrain_at(tile)
	var biome_id := String(GENERATED_DECORATIVE_BIOME_BY_TERRAIN.get(terrain_id, ""))
	var placement_id := String(object.get("placement_id", "")).strip_edges()
	if placement_id == "":
		placement_id = String(object.get("h3m_def_name", "")).strip_edges()
	var cluster_x := floori(float(tile.x) / float(GENERATED_DECORATIVE_BODY_ASSET_CLUSTER_TILES))
	var cluster_y := floori(float(tile.y) / float(GENERATED_DECORATIVE_BODY_ASSET_CLUSTER_TILES))
	return "%s|%s|%s|%d,%d" % [
		biome_id,
		terrain_id,
		placement_id,
		cluster_x,
		cluster_y,
	]

func _generated_decorative_body_composition(
	object: Dictionary,
	tile: Vector2i,
	min_tile: Vector2i,
	footprint: Vector2i,
	body_tile_count: int,
	anchor_index: int,
	anchor_count: int
) -> Dictionary:
	var placement_id := String(object.get("placement_id", "")).strip_edges()
	if placement_id == "":
		placement_id = String(object.get("h3m_def_name", "")).strip_edges()
	var composition_key := "%s|%s|%d,%d|%d/%d" % [
		placement_id,
		String(object.get("h3m_def_name", "")),
		tile.x,
		tile.y,
		anchor_index,
		anchor_count,
	]
	var scale_factor := lerpf(
		GENERATED_DECORATIVE_BODY_SCALE_FACTOR_MIN,
		GENERATED_DECORATIVE_BODY_SCALE_FACTOR_MAX,
		_stable_unit_fraction("%s|scale" % composition_key)
	)
	var offset_tiles := Vector2(
		lerpf(-GENERATED_DECORATIVE_BODY_OFFSET_X_TILES, GENERATED_DECORATIVE_BODY_OFFSET_X_TILES, _stable_unit_fraction("%s|offset_x" % composition_key)),
		lerpf(GENERATED_DECORATIVE_BODY_OFFSET_Y_MIN_TILES, GENERATED_DECORATIVE_BODY_OFFSET_Y_MAX_TILES, _stable_unit_fraction("%s|offset_y" % composition_key))
	)
	var base_extent_tiles := GENERATED_DECORATIVE_BODY_SPRITE_EXTENT_TILES
	if body_tile_count >= 9:
		base_extent_tiles = GENERATED_DECORATIVE_BODY_MASS_LARGE_EXTENT_TILES
	elif body_tile_count >= 5:
		base_extent_tiles = GENERATED_DECORATIVE_BODY_MASS_MEDIUM_EXTENT_TILES
	elif body_tile_count >= 3:
		base_extent_tiles = GENERATED_DECORATIVE_BODY_MASS_SMALL_EXTENT_TILES
	var sprite_extent_tiles := base_extent_tiles * scale_factor
	var sprite_center_tiles := Vector2(
		(float(tile.x - min_tile.x) + 0.5 + offset_tiles.x) / float(maxi(footprint.x, 1)),
		(float(tile.y - min_tile.y) + 0.5 + offset_tiles.y - _object_lift_fraction("blocker", footprint)) / float(maxi(footprint.y, 1))
	)
	var horizontal_inset := maxf(0.0, sprite_extent_tiles * 0.5 - GENERATED_DECORATIVE_BODY_MASS_BOUNDS_MARGIN_TILES) / float(maxi(footprint.x, 1))
	var vertical_inset := maxf(0.0, sprite_extent_tiles * 0.5 - GENERATED_DECORATIVE_BODY_MASS_BOUNDS_MARGIN_TILES) / float(maxi(footprint.y, 1))
	sprite_center_tiles = Vector2(
		clampf(sprite_center_tiles.x, horizontal_inset, 1.0 - horizontal_inset),
		clampf(sprite_center_tiles.y, vertical_inset, 1.0 - vertical_inset)
	)
	return {
		"composition_key": composition_key,
		"scale_factor": scale_factor,
		"offset_tiles": {"x": offset_tiles.x, "y": offset_tiles.y},
		"sprite_extent_tiles": sprite_extent_tiles,
		"sprite_center_tiles": {"x": sprite_center_tiles.x, "y": sprite_center_tiles.y},
	}

func _generated_body_normalized_sprite_bounds(presentation: Dictionary) -> Dictionary:
	var scale_factor := clampf(
		float(presentation.get("generated_body_scale_factor", 1.0)),
		GENERATED_DECORATIVE_BODY_SCALE_FACTOR_MIN,
		GENERATED_DECORATIVE_BODY_SCALE_FACTOR_MAX
	)
	var offset_payload: Dictionary = presentation.get("generated_body_offset_tiles", {}) if presentation.get("generated_body_offset_tiles", {}) is Dictionary else {}
	var offset_x := clampf(float(offset_payload.get("x", 0.0)), -GENERATED_DECORATIVE_BODY_OFFSET_X_TILES, GENERATED_DECORATIVE_BODY_OFFSET_X_TILES)
	var offset_y := clampf(float(offset_payload.get("y", 0.0)), GENERATED_DECORATIVE_BODY_OFFSET_Y_MIN_TILES, GENERATED_DECORATIVE_BODY_OFFSET_Y_MAX_TILES)
	var sprite_extent := float(presentation.get("generated_body_sprite_extent_tiles", GENERATED_DECORATIVE_BODY_SPRITE_EXTENT_TILES))
	var footprint_payload: Dictionary = presentation.get("footprint", {}) if presentation.get("footprint", {}) is Dictionary else {}
	var footprint := Vector2i(maxi(1, int(footprint_payload.get("width", 1))), maxi(1, int(footprint_payload.get("height", 1))))
	var center_payload: Dictionary = presentation.get("generated_body_sprite_center_tiles", {}) if presentation.get("generated_body_sprite_center_tiles", {}) is Dictionary else {}
	var center := Vector2(float(center_payload.get("x", 0.5)), float(center_payload.get("y", 0.5)))
	var half_width := sprite_extent * 0.5 / float(footprint.x)
	var half_height := sprite_extent * 0.5 / float(footprint.y)
	var left := center.x - half_width
	var top := center.y - half_height
	var right := center.x + half_width
	var bottom := center.y + half_height
	var margin_x := GENERATED_DECORATIVE_BODY_MASS_BOUNDS_MARGIN_TILES / float(footprint.x)
	var margin_y := GENERATED_DECORATIVE_BODY_MASS_BOUNDS_MARGIN_TILES / float(footprint.y)
	return {
		"left": left,
		"top": top,
		"right": right,
		"bottom": bottom,
		"extent_tiles": sprite_extent,
		"within_mass_margin": left >= -margin_x - 0.0001 and top >= -margin_y - 0.0001 and right <= 1.0 + margin_x + 0.0001 and bottom <= 1.0 + margin_y + 0.0001,
	}

func _stable_unit_fraction(stable_key: String) -> float:
	return float(posmod(stable_key.hash(), 1000003)) / 1000002.0

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
	signature = _combine_cache_signature(signature, _enemy_commander_presentation_signature(overworld.get("encounters", [])))
	signature = _combine_cache_signature(signature, _placement_array_cache_signature(overworld.get("map_objects", []), ["object_id", "placement_id", "kind", "runtime_object_role"]))
	return _combine_cache_signature(signature, _placement_array_cache_signature(overworld.get("resolved_encounters", []), ["placement_id", "encounter_id", "id"]))

func _enemy_commander_presentation_signature(encounters: Variant) -> int:
	var signature := CACHE_SIGNATURE_SEED
	if not (encounters is Array):
		return signature
	for encounter_value in encounters:
		if not (encounter_value is Dictionary):
			continue
		var encounter: Dictionary = encounter_value
		var commander_state: Dictionary = encounter.get("enemy_commander_state", {}) if encounter.get("enemy_commander_state", {}) is Dictionary else {}
		signature = _combine_cache_signature(signature, String(encounter.get("placement_id", "")).hash())
		signature = _combine_cache_signature(signature, String(encounter.get("spawned_by_faction_id", "")).hash())
		signature = _combine_cache_signature(signature, String(encounter.get("faction_id", "")).hash())
		signature = _combine_cache_signature(signature, String(encounter.get("enemy_group_id", "")).hash())
		signature = _combine_cache_signature(signature, String(encounter.get("encounter_id", encounter.get("id", ""))).hash())
		signature = _combine_cache_signature(signature, String(commander_state.get("roster_hero_id", "")).hash())
		signature = _combine_cache_signature(signature, String(commander_state.get("faction_id", "")).hash())
	return signature

func _hero_index_signature_for(session) -> int:
	if session == null:
		return 0
	return _placement_array_cache_signature(HeroCommandRulesScript.hero_positions(session), ["hero_id", "is_active"])

func _ensure_road_tile_payload(tile: Vector2i, overlay_id: String, road_id: String, role: String, source_tile: Dictionary = {}) -> void:
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
	if source_tile.has("h3maped_road_art_frame_id"):
		payload["h3maped_road_art_frame_id"] = String(source_tile.get("h3maped_road_art_frame_id", ""))
	if source_tile.has("h3maped_road_art_index"):
		payload["h3maped_road_art_index"] = int(source_tile.get("h3maped_road_art_index", 0))
	if source_tile.has("h3maped_road_flip_a"):
		payload["h3maped_road_flip_a"] = int(source_tile.get("h3maped_road_flip_a", 0))
	if source_tile.has("h3maped_road_flip_b"):
		payload["h3maped_road_flip_b"] = int(source_tile.get("h3maped_road_flip_b", 0))
	if source_tile.has("h3maped_road_atlas"):
		payload["h3maped_road_atlas"] = String(source_tile.get("h3maped_road_atlas", ""))
	if source_tile.has("h3maped_road_type"):
		payload["h3maped_road_type"] = int(source_tile.get("h3maped_road_type", 0))
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
	_object_asset_regions.clear()
	_object_textures.clear()
	_object_texture_missing.clear()
	_object_texture_visible_regions.clear()
	_ownership_pennant_asset_ids.clear()
	_resource_site_asset_ids.clear()
	_resource_site_unclaimed_asset_ids.clear()
	_resource_site_object_profiles.clear()
	_map_object_asset_ids.clear()
	_decorative_object_asset_ids.clear()
	_generated_decorative_blocker_asset_ids_by_biome.clear()
	_generated_decorative_blocker_fallback_asset_ids.clear()
	_artifact_default_asset_id = ""
	_artifact_field_asset_ids.clear()
	_town_default_asset_id = ""
	_town_identity_asset_ids.clear()
	_town_faction_asset_ids.clear()
	_hero_identity_asset_ids.clear()
	_hero_faction_asset_ids.clear()
	_encounter_faction_asset_ids.clear()
	_encounter_faction_cache.clear()
	_encounter_identity_asset_ids.clear()
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
			var atlas_region: Variant = entry.get("atlas_region", [])
			if atlas_region is Array and not atlas_region.is_empty():
				_object_asset_regions[asset_id] = atlas_region.duplicate(true)

	var ownership_pennant_sprites = _overworld_art_manifest.get("ownership_pennant_sprites", {})
	if ownership_pennant_sprites is Dictionary:
		for owner_value in ownership_pennant_sprites.keys():
			var owner := String(owner_value)
			var asset_id := String(ownership_pennant_sprites.get(owner_value, ""))
			if owner != "" and asset_id != "":
				_ownership_pennant_asset_ids[owner] = asset_id

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
			var unclaimed_asset_id := String(entry.get("unclaimed_asset_id", ""))
			if site_id != "" and unclaimed_asset_id != "":
				_resource_site_unclaimed_asset_ids[site_id] = unclaimed_asset_id

	var artifact_default = _overworld_art_manifest.get("artifact_default_sprite", {})
	if artifact_default is Dictionary:
		_artifact_default_asset_id = String(artifact_default.get("asset_id", ""))

	var artifact_field_sprites = _overworld_art_manifest.get("artifact_field_sprites", {})
	if artifact_field_sprites is Dictionary:
		for artifact_id_value in artifact_field_sprites:
			var artifact_id := String(artifact_id_value).strip_edges()
			var asset_id := String(artifact_field_sprites.get(artifact_id_value, "")).strip_edges()
			if artifact_id != "" and asset_id != "":
				_artifact_field_asset_ids[artifact_id] = asset_id

	var town_default = _overworld_art_manifest.get("town_default_sprite", {})
	if town_default is Dictionary:
		_town_default_asset_id = String(town_default.get("asset_id", ""))

	var town_faction_sprites = _overworld_art_manifest.get("town_faction_sprites", {})
	if town_faction_sprites is Dictionary:
		for faction_id_value in town_faction_sprites:
			var faction_id := String(faction_id_value).strip_edges()
			var asset_id := String(town_faction_sprites.get(faction_id_value, "")).strip_edges()
			if faction_id != "" and asset_id != "":
				_town_faction_asset_ids[faction_id] = asset_id

	var town_identity_sprites = _overworld_art_manifest.get("town_identity_sprites", {})
	if town_identity_sprites is Dictionary:
		for town_id_value in town_identity_sprites:
			var town_id := String(town_id_value).strip_edges()
			var asset_id := String(town_identity_sprites.get(town_id_value, "")).strip_edges()
			if town_id != "" and asset_id != "":
				_town_identity_asset_ids[town_id] = asset_id

	var hero_faction_sprites = _overworld_art_manifest.get("hero_faction_sprites", {})
	if hero_faction_sprites is Dictionary:
		for faction_id_value in hero_faction_sprites:
			var faction_id := String(faction_id_value).strip_edges()
			var asset_id := String(hero_faction_sprites.get(faction_id_value, "")).strip_edges()
			if faction_id != "" and asset_id != "":
				_hero_faction_asset_ids[faction_id] = asset_id

	var hero_identity_sprites = _overworld_art_manifest.get("hero_identity_sprites", {})
	if hero_identity_sprites is Dictionary:
		for hero_id_value in hero_identity_sprites:
			var hero_id := String(hero_id_value).strip_edges()
			var asset_id := String(hero_identity_sprites.get(hero_id_value, "")).strip_edges()
			if hero_id != "" and asset_id != "":
				_hero_identity_asset_ids[hero_id] = asset_id

	var encounter_faction_sprites = _overworld_art_manifest.get("encounter_faction_sprites", {})
	if encounter_faction_sprites is Dictionary:
		for faction_id_value in encounter_faction_sprites:
			var faction_id := String(faction_id_value).strip_edges()
			var asset_id := String(encounter_faction_sprites.get(faction_id_value, "")).strip_edges()
			if faction_id != "" and asset_id != "":
				_encounter_faction_asset_ids[faction_id] = asset_id

	var encounter_identity_sprites = _overworld_art_manifest.get("encounter_identity_sprites", {})
	if encounter_identity_sprites is Dictionary:
		for encounter_id_value in encounter_identity_sprites:
			var encounter_id := String(encounter_id_value).strip_edges()
			var asset_id := String(encounter_identity_sprites.get(encounter_id_value, "")).strip_edges()
			if encounter_id != "" and asset_id != "":
				_encounter_identity_asset_ids[encounter_id] = asset_id

	var encounter_default = _overworld_art_manifest.get("encounter_default_sprite", {})
	if encounter_default is Dictionary:
		_encounter_default_asset_id = String(encounter_default.get("asset_id", ""))

	_load_decorative_object_sprite_manifest(String(_overworld_art_manifest.get("decorative_object_sprite_manifest", "")))
	_load_map_object_sprite_manifest(String(_overworld_art_manifest.get("map_object_sprite_manifest", "")))

func _overworld_vfx_manifest_cue(cue_id: String) -> Dictionary:
	_load_overworld_vfx_manifest()
	var cues: Dictionary = _overworld_vfx_manifest.get("cues", {}) if _overworld_vfx_manifest.get("cues", {}) is Dictionary else {}
	var cue: Dictionary = cues.get(cue_id, {}) if cues.get(cue_id, {}) is Dictionary else {}
	return cue.duplicate(true)

func _load_overworld_vfx_manifest() -> void:
	if _overworld_vfx_manifest_loaded:
		return
	_overworld_vfx_manifest_loaded = true
	_overworld_vfx_manifest = {}
	_overworld_vfx_textures.clear()
	_overworld_vfx_texture_missing.clear()
	if not FileAccess.file_exists(OVERWORLD_VFX_MANIFEST_PATH):
		return
	var text := FileAccess.get_file_as_string(OVERWORLD_VFX_MANIFEST_PATH)
	if text.strip_edges() == "":
		return
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		_overworld_vfx_manifest = parsed

func _overworld_vfx_texture_for_path(texture_path: String):
	if texture_path == "" or _overworld_vfx_texture_missing.has(texture_path):
		return null
	if _overworld_vfx_textures.has(texture_path):
		return _overworld_vfx_textures.get(texture_path)
	if not ResourceLoader.exists(texture_path):
		_overworld_vfx_texture_missing[texture_path] = true
		return null
	var loaded = load(texture_path)
	if loaded is Texture2D:
		_overworld_vfx_textures[texture_path] = loaded
		return loaded
	_overworld_vfx_texture_missing[texture_path] = true
	return null

func _load_decorative_object_sprite_manifest(manifest_path: String) -> void:
	var normalized_path := manifest_path.strip_edges()
	if normalized_path == "":
		return
	var raw := ContentService.load_json(normalized_path)
	if raw.is_empty():
		push_warning("Decorative object sprite manifest is missing or invalid; procedural decorative markers remain available.")
		return
	var mappings = raw.get("object_sprite_mappings", {})
	if not (mappings is Dictionary):
		return
	for object_id_value in mappings.keys():
		var object_id := String(object_id_value).strip_edges()
		var entry = mappings.get(object_id_value, {})
		var asset_id := ""
		if entry is Dictionary:
			asset_id = String(entry.get("asset_id", "")).strip_edges()
		else:
			asset_id = String(entry).strip_edges()
		if object_id == "" or asset_id == "":
			continue
		_decorative_object_asset_ids[object_id] = asset_id
		if entry is Dictionary and String(entry.get("source_family", "")).strip_edges() == "blocker":
			if asset_id not in _generated_decorative_blocker_fallback_asset_ids:
				_generated_decorative_blocker_fallback_asset_ids.append(asset_id)
			var source_biome_ids = entry.get("source_biome_ids", [])
			if source_biome_ids is Array:
				for biome_id_value in source_biome_ids:
					var biome_id := String(biome_id_value).strip_edges()
					if biome_id == "":
						continue
					var biome_asset_ids: Array = _generated_decorative_blocker_asset_ids_by_biome.get(biome_id, [])
					if asset_id not in biome_asset_ids:
						biome_asset_ids.append(asset_id)
					_generated_decorative_blocker_asset_ids_by_biome[biome_id] = biome_asset_ids
	_generated_decorative_blocker_fallback_asset_ids.sort()
	for biome_id_value in _generated_decorative_blocker_asset_ids_by_biome.keys():
		var biome_asset_ids: Array = _generated_decorative_blocker_asset_ids_by_biome.get(biome_id_value, [])
		biome_asset_ids.sort()
		_generated_decorative_blocker_asset_ids_by_biome[biome_id_value] = biome_asset_ids

func _load_map_object_sprite_manifest(manifest_path: String) -> void:
	var normalized_path := manifest_path.strip_edges()
	if normalized_path == "":
		return
	var raw := ContentService.load_json(normalized_path)
	if raw.is_empty():
		push_warning("Map object sprite manifest is missing or invalid; resource/default sprite fallbacks remain available.")
		return
	var mappings = raw.get("object_sprite_mappings", {})
	if not (mappings is Dictionary):
		return
	for object_id_value in mappings.keys():
		var object_id := String(object_id_value).strip_edges()
		var entry = mappings.get(object_id_value, {})
		var asset_id := ""
		if entry is Dictionary:
			asset_id = String(entry.get("asset_id", "")).strip_edges()
		else:
			asset_id = String(entry).strip_edges()
		if object_id == "" or asset_id == "":
			continue
		_map_object_asset_ids[object_id] = asset_id

func _load_map_object_profiles() -> void:
	_resource_site_object_profiles.clear()
	_map_object_content_profiles.clear()
	var raw := ContentService.load_json("res://content/map_objects.json")
	var items = raw.get("items", [])
	if not (items is Array):
		return
	for object_value in items:
		if not (object_value is Dictionary):
			continue
		var footprint = object_value.get("footprint", {})
		var footprint_size := Vector2i(1, 1)
		if footprint is Dictionary:
			footprint_size = Vector2i(int(footprint.get("width", 1)), int(footprint.get("height", 1)))
		var profile := {
			"id": String(object_value.get("id", "")),
			"family": String(object_value.get("family", "pickup")),
			"primary_class": String(object_value.get("primary_class", "")),
			"secondary_tags": object_value.get("secondary_tags", []),
			"footprint": _normalized_footprint(footprint_size),
			"footprint_tier": String(footprint.get("tier", "")) if footprint is Dictionary else "",
			"footprint_anchor": String(footprint.get("anchor", "bottom_center")) if footprint is Dictionary else "bottom_center",
			"passable": bool(object_value.get("passable", true)),
			"visitable": bool(object_value.get("visitable", true)),
			"map_roles": object_value.get("map_roles", []),
		}
		var object_id := String(object_value.get("id", "")).strip_edges()
		if object_id != "":
			_map_object_content_profiles[object_id] = profile
		var site_id := String(object_value.get("resource_site_id", "")).strip_edges()
		if site_id == "":
			continue
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
		var atlas_region_value: Variant = _object_asset_regions.get(normalized_asset_id, [])
		if atlas_region_value is Array and not atlas_region_value.is_empty():
			if atlas_region_value.size() != 4:
				_object_texture_missing[normalized_asset_id] = texture_path
				return null
			var atlas_region := Rect2(
				float(atlas_region_value[0]),
				float(atlas_region_value[1]),
				float(atlas_region_value[2]),
				float(atlas_region_value[3])
			)
			if atlas_region.position.x < 0.0 \
				or atlas_region.position.y < 0.0 \
				or atlas_region.size.x <= 0.0 \
				or atlas_region.size.y <= 0.0 \
				or atlas_region.end.x > texture.get_width() \
				or atlas_region.end.y > texture.get_height():
				_object_texture_missing[normalized_asset_id] = texture_path
				return null
			var atlas_texture := AtlasTexture.new()
			atlas_texture.atlas = texture
			atlas_texture.region = atlas_region
			_object_textures[normalized_asset_id] = atlas_texture
			return atlas_texture
		_object_textures[normalized_asset_id] = texture
		return texture
	_object_texture_missing[normalized_asset_id] = texture_path
	return null

func _unit_art_texture(path: String):
	var normalized_path := path.strip_edges()
	if normalized_path == "":
		return null
	if _unit_art_textures.has(normalized_path):
		return _unit_art_textures.get(normalized_path)
	if _unit_art_texture_missing.has(normalized_path):
		return null
	var texture = _texture_from_path(normalized_path)
	if texture is Texture2D:
		_unit_art_textures[normalized_path] = texture
		return texture
	_unit_art_texture_missing[normalized_path] = true
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

func _encounter_overworld_icon_path(encounter: Dictionary) -> String:
	var unit_id := _encounter_primary_unit_id(encounter)
	if unit_id == "":
		return ""
	var art := ContentService.get_unit_art(unit_id)
	return String(art.get("overworld_icon", ""))

func _encounter_primary_unit_id(encounter: Dictionary) -> String:
	var direct_unit_id := String(encounter.get("unit_id", "")).strip_edges()
	if direct_unit_id != "":
		return direct_unit_id
	var group_id := String(encounter.get("enemy_group_id", "")).strip_edges()
	if group_id == "":
		var encounter_id := String(encounter.get("encounter_id", encounter.get("id", ""))).strip_edges()
		var definition := ContentService.get_encounter(encounter_id)
		group_id = String(definition.get("enemy_group_id", "")).strip_edges()
	if group_id == "":
		return ""
	var group := ContentService.get_army_group(group_id)
	var best_unit_id := ""
	var best_count := -1
	for stack in group.get("stacks", []):
		if not (stack is Dictionary):
			continue
		var unit_id := String(stack.get("unit_id", "")).strip_edges()
		if unit_id == "":
			continue
		var count := int(stack.get("count", 0))
		if best_unit_id == "" or count > best_count:
			best_unit_id = unit_id
			best_count = count
	return best_unit_id

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

func _decorative_object_profile(object: Dictionary) -> Dictionary:
	if object.is_empty():
		return _default_object_profile("blocker", Vector2i(1, 1))
	var object_id := String(object.get("object_id", object.get("id", ""))).strip_edges()
	var profile = _map_object_content_profiles.get(object_id, {})
	var resolved_profile: Dictionary = profile.duplicate(true) if profile is Dictionary and not profile.is_empty() else {}
	if resolved_profile.is_empty():
		resolved_profile = _default_object_profile(_decorative_object_family(object), Vector2i(1, 1))
	else:
		resolved_profile["family"] = _decorative_object_family(object, String(resolved_profile.get("family", "blocker")))
	var footprint = object.get("footprint", {})
	if footprint is Dictionary and not footprint.is_empty():
		resolved_profile["footprint"] = {
			"width": maxi(1, int(footprint.get("width", 1))),
			"height": maxi(1, int(footprint.get("height", 1))),
			"anchor": String(footprint.get("anchor", resolved_profile.get("footprint_anchor", "bottom_center"))),
		}
		resolved_profile["footprint_anchor"] = String(resolved_profile["footprint"].get("anchor", "bottom_center"))
		resolved_profile["render_footprint_source"] = "generated_runtime_footprint"
	var bounds = object.get("bounds", {})
	if bounds is Dictionary and not bounds.is_empty():
		var min_x := int(bounds.get("min_x", object.get("x", 0)))
		var min_y := int(bounds.get("min_y", object.get("y", 0)))
		var max_x := int(bounds.get("max_x", min_x))
		var max_y := int(bounds.get("max_y", min_y))
		resolved_profile["footprint"] = {
			"width": maxi(1, max_x - min_x + 1),
			"height": maxi(1, max_y - min_y + 1),
			"anchor": String(resolved_profile.get("footprint_anchor", "bottom_center")),
		}
		resolved_profile["render_footprint_source"] = "generated_runtime_bounds"
	return resolved_profile

func _standalone_map_object_profile(object: Dictionary) -> Dictionary:
	if object.is_empty():
		return _default_object_profile("pickup", Vector2i(1, 1))
	var object_id := String(object.get("object_id", object.get("id", ""))).strip_edges()
	var profile = _map_object_content_profiles.get(object_id, {})
	var resolved_profile: Dictionary = profile.duplicate(true) if profile is Dictionary and not profile.is_empty() else {}
	if resolved_profile.is_empty():
		resolved_profile = _default_object_profile(String(object.get("family_id", object.get("object_family_id", "pickup"))), Vector2i(1, 1))
	var footprint = object.get("footprint", {})
	if footprint is Dictionary and not footprint.is_empty():
		resolved_profile["footprint"] = {
			"width": maxi(1, int(footprint.get("width", 1))),
			"height": maxi(1, int(footprint.get("height", 1))),
			"anchor": String(footprint.get("anchor", resolved_profile.get("footprint_anchor", "bottom_center"))),
		}
		resolved_profile["footprint_anchor"] = String(resolved_profile["footprint"].get("anchor", "bottom_center"))
		resolved_profile["render_footprint_source"] = "generated_runtime_footprint"
	var bounds = object.get("bounds", {})
	if bounds is Dictionary and not bounds.is_empty():
		var min_x := int(bounds.get("min_x", object.get("x", 0)))
		var min_y := int(bounds.get("min_y", object.get("y", 0)))
		var max_x := int(bounds.get("max_x", min_x))
		var max_y := int(bounds.get("max_y", min_y))
		resolved_profile["footprint"] = {
			"width": maxi(1, max_x - min_x + 1),
			"height": maxi(1, max_y - min_y + 1),
			"anchor": String(resolved_profile.get("footprint_anchor", "bottom_center")),
		}
		resolved_profile["render_footprint_source"] = "generated_runtime_bounds"
	return resolved_profile

func _decorative_object_family(object: Dictionary, fallback: String = "blocker") -> String:
	var object_id := String(object.get("object_id", object.get("id", ""))).strip_edges()
	if object_id != "":
		var profile = _map_object_content_profiles.get(object_id, {})
		if profile is Dictionary and String(profile.get("family", "")).strip_edges() != "":
			return String(profile.get("family", "")).strip_edges()
	var family := fallback.strip_edges()
	return family if family != "" else "blocker"

func _artifact_object_profile(node: Dictionary = {}) -> Dictionary:
	var profile := _default_object_profile("artifact", Vector2i(1, 1))
	profile["id"] = String(node.get("artifact_id", "")).strip_edges()
	profile["primary_class"] = "handheld_artifact"
	profile["footprint_tier"] = "micro"
	return profile

func _town_object_profile() -> Dictionary:
	return {
		"id": "default_town_world_object",
		"family": "town",
		"footprint": TOWN_PRESENTATION_FOOTPRINT,
		"visual_footprint": TOWN_VISUAL_FOOTPRINT,
		"visual_anchor_model": TOWN_VISUAL_ANCHOR_MODEL,
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
		"decorative_object":
			return _decorative_object_profile(_decorative_object_at(tile))
		"map_object":
			return _standalone_map_object_profile(_standalone_map_object_at(tile))
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

func _town_template_faction_id(town: Dictionary) -> String:
	var template := ContentService.get_town(String(town.get("town_id", "")))
	return String(template.get("faction_id", "")).strip_edges()

func _town_sprite_asset_id(town: Dictionary) -> String:
	var town_id := String(town.get("town_id", "")).strip_edges()
	var identity_asset_id := String(_town_identity_asset_ids.get(town_id, "")).strip_edges()
	if identity_asset_id != "" and _object_texture_for_asset(identity_asset_id) is Texture2D:
		return identity_asset_id
	var faction_id := _town_template_faction_id(town)
	var faction_asset_id := String(_town_faction_asset_ids.get(faction_id, "")).strip_edges()
	if faction_asset_id != "" and _object_texture_for_asset(faction_asset_id) is Texture2D:
		return faction_asset_id
	if _town_default_asset_id != "" and _object_texture_for_asset(_town_default_asset_id) is Texture2D:
		return _town_default_asset_id
	return ""

func _hero_presentation_entry(tile: Vector2i) -> Dictionary:
	var heroes: Array = _heroes_by_tile.get(_tile_key(tile), [])
	for hero_value in heroes:
		if hero_value is Dictionary and bool(hero_value.get("is_active", false)):
			return hero_value
	for hero_value in heroes:
		if hero_value is Dictionary:
			return hero_value
	return {}

func _hero_template_faction_id(hero: Dictionary) -> String:
	var template := ContentService.get_hero(String(hero.get("id", "")))
	return String(template.get("faction_id", "")).strip_edges()

func _hero_sprite_asset_id(hero: Dictionary) -> String:
	var hero_id := String(hero.get("id", "")).strip_edges()
	var identity_asset_id := String(_hero_identity_asset_ids.get(hero_id, "")).strip_edges()
	if identity_asset_id != "" and _object_texture_for_asset(identity_asset_id) is Texture2D:
		return identity_asset_id
	var faction_id := _hero_template_faction_id(hero)
	var asset_id := String(_hero_faction_asset_ids.get(faction_id, "")).strip_edges()
	if asset_id != "" and _object_texture_for_asset(asset_id) is Texture2D:
		return asset_id
	return ""

func _enemy_commander_hero_template(encounter: Dictionary) -> Dictionary:
	var commander_state: Dictionary = encounter.get("enemy_commander_state", {}) if encounter.get("enemy_commander_state", {}) is Dictionary else {}
	var hero_id := String(commander_state.get("roster_hero_id", "")).strip_edges()
	var commander_faction_id := String(commander_state.get("faction_id", "")).strip_edges()
	var spawned_faction_id := String(encounter.get("spawned_by_faction_id", "")).strip_edges()
	if hero_id == "" or commander_faction_id == "" or spawned_faction_id == "" or commander_faction_id != spawned_faction_id:
		return {}
	var hero := ContentService.get_hero(hero_id)
	if hero.is_empty() or String(hero.get("faction_id", "")).strip_edges() != spawned_faction_id:
		return {}
	return hero

func _town_color(tile: Vector2i) -> Color:
	var town = _town_at(tile)
	return _town_owner_color(town)

func _town_owner_color(town: Dictionary) -> Color:
	var owner := _town_owner_id(town)
	match owner:
		"player":
			return FrontierVisualKitScript.semantic_color("player", PLAYER_TOWN_COLOR)
		"enemy":
			return FrontierVisualKitScript.semantic_color("enemy", ENEMY_TOWN_COLOR)
		_:
			return FrontierVisualKitScript.semantic_color("neutral", NEUTRAL_TOWN_COLOR)

func _town_owner_id(town: Dictionary) -> String:
	var owner := String(town.get("owner", "neutral"))
	return owner if owner in ["player", "enemy"] else "neutral"

func _town_presentation_at(tile: Vector2i) -> Dictionary:
	if _session == null:
		return {}
	return _town_footprints_by_tile.get(_tile_key(tile), {})

func town_footprint_selection(tile: Vector2i) -> Dictionary:
	var presentation := _town_presentation_at(tile)
	if presentation.is_empty():
		return {}
	var town: Dictionary = presentation.get("town", {}) if presentation.get("town", {}) is Dictionary else {}
	var entry: Vector2i = presentation.get("entry_tile", tile) if presentation.get("entry_tile", tile) is Vector2i else tile
	return {
		"town_placement_id": String(town.get("placement_id", "")),
		"owner": String(town.get("owner", "neutral")),
		"entry_tile": entry,
		"is_entry_tile": bool(presentation.get("is_entry_tile", false)),
		"tile_role": String(presentation.get("tile_role", "")),
	}.duplicate(true)

func _town_entry_tile(town: Dictionary) -> Vector2i:
	return Vector2i(int(town.get("x", -1)), int(town.get("y", -1)))

func _town_footprint_origin_for_entry(entry: Vector2i) -> Vector2i:
	return entry - TOWN_ENTRY_OFFSET

func _town_visual_rect_for_entry(entry: Vector2i) -> Rect2:
	var entry_rect := _tile_rect(_board_rect(), entry)
	if entry_rect.size.x <= 0.0 or entry_rect.size.y <= 0.0:
		return entry_rect
	var visual_size := entry_rect.size * Vector2(TOWN_VISUAL_FOOTPRINT)
	return Rect2(
		Vector2(entry_rect.get_center().x - visual_size.x * 0.5, entry_rect.end.y - visual_size.y),
		visual_size
	)

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
	if String(site.get("family", "")) == "faction_landmark":
		var landmark_asset_id := String(_resource_site_asset_ids.get(site_id, ""))
		if landmark_asset_id != "" and _object_texture_for_asset(landmark_asset_id) is Texture2D:
			return landmark_asset_id
	if (
		String(site.get("family", "")) == "neutral_dwelling"
		and not String(node.get("collected_by_faction_id", "")).strip_edges().is_empty()
	):
		var claimed_asset_id := String(_resource_site_asset_ids.get(site_id, ""))
		if claimed_asset_id != "" and _object_texture_for_asset(claimed_asset_id) is Texture2D:
			return claimed_asset_id
	if (
		not String(node.get("collected_by_faction_id", "")).strip_edges().is_empty()
		and _resource_site_unclaimed_asset_ids.has(site_id)
	):
		var claimed_state_asset_id := String(_resource_site_asset_ids.get(site_id, ""))
		if claimed_state_asset_id != "" and _object_texture_for_asset(claimed_state_asset_id) is Texture2D:
			return claimed_state_asset_id
	if String(node.get("kind", "")) == "reward_reference":
		var reward_asset_id := String(_resource_site_asset_ids.get(site_id, ""))
		if reward_asset_id != "":
			return reward_asset_id
	var object_id := String(node.get("object_id", "")).strip_edges()
	if object_id != "" and _map_object_asset_ids.has(object_id):
		return String(_map_object_asset_ids.get(object_id, ""))
	var map_object = ContentService.get_map_object_for_resource_site(site_id)
	if map_object is Dictionary:
		var mapped_object_id := String(map_object.get("id", "")).strip_edges()
		if mapped_object_id != "" and _map_object_asset_ids.has(mapped_object_id):
			return String(_map_object_asset_ids.get(mapped_object_id, ""))
	var direct_asset_id := String(site.get("overworld_sprite_asset_id", ""))
	if direct_asset_id != "":
		return direct_asset_id
	if String(site.get("family", "")) == "neutral_dwelling":
		var unclaimed_asset_id := String(_resource_site_unclaimed_asset_ids.get(site_id, ""))
		if unclaimed_asset_id != "" and _object_texture_for_asset(unclaimed_asset_id) is Texture2D:
			return unclaimed_asset_id
	return String(_resource_site_asset_ids.get(site_id, ""))

func _artifact_sprite_asset_id(node: Dictionary) -> String:
	if node.is_empty():
		return ""
	var artifact_id := String(node.get("artifact_id", "")).strip_edges()
	var field_asset_id := String(_artifact_field_asset_ids.get(artifact_id, ""))
	if field_asset_id != "" and _object_texture_for_asset(field_asset_id) is Texture2D:
		return field_asset_id
	if _artifact_default_asset_id != "" and _object_texture_for_asset(_artifact_default_asset_id) is Texture2D:
		return _artifact_default_asset_id
	return ""

func _encounter_asset_id(encounter: Dictionary) -> String:
	var object_id := String(encounter.get("object_id", "")).strip_edges()
	if object_id != "" and _map_object_asset_ids.has(object_id):
		return String(_map_object_asset_ids.get(object_id, ""))
	return _encounter_default_asset_id

func _encounter_identity_asset_id(encounter: Dictionary) -> String:
	var encounter_id := String(encounter.get("encounter_id", encounter.get("id", ""))).strip_edges()
	var asset_id := String(_encounter_identity_asset_ids.get(encounter_id, "")).strip_edges()
	if asset_id != "" and _object_texture_for_asset(asset_id) is Texture2D:
		return asset_id
	return ""

func _encounter_faction_asset_id(encounter: Dictionary) -> String:
	var faction_id := _encounter_faction_id(encounter)
	var asset_id := String(_encounter_faction_asset_ids.get(faction_id, "")).strip_edges()
	if asset_id != "" and _object_texture_for_asset(asset_id) is Texture2D:
		return asset_id
	return ""

func _encounter_faction_id(encounter: Dictionary) -> String:
	var spawned_faction_id := String(encounter.get("spawned_by_faction_id", "")).strip_edges()
	if spawned_faction_id != "":
		return spawned_faction_id
	var direct_faction_id := String(encounter.get("faction_id", "")).strip_edges()
	if direct_faction_id != "":
		return direct_faction_id
	var group_id := String(encounter.get("enemy_group_id", "")).strip_edges()
	if group_id == "":
		var encounter_id := String(encounter.get("encounter_id", encounter.get("id", ""))).strip_edges()
		var definition := ContentService.get_encounter(encounter_id)
		group_id = String(definition.get("enemy_group_id", "")).strip_edges()
	if group_id == "":
		return ""
	if _encounter_faction_cache.has(group_id):
		return String(_encounter_faction_cache.get(group_id, ""))
	var faction_id := String(ContentService.get_army_group(group_id).get("faction_id", "")).strip_edges()
	_encounter_faction_cache[group_id] = faction_id
	return faction_id

func _has_decorative_object_at(tile: Vector2i) -> bool:
	return not _decorative_object_at(tile).is_empty()

func _decorative_object_at(tile: Vector2i) -> Dictionary:
	var generated_body: Dictionary = _generated_decorative_bodies_by_tile.get(_tile_key(tile), {})
	if not generated_body.is_empty():
		return generated_body
	return _decorative_objects_by_tile.get(_tile_key(tile), {})

func _has_standalone_map_object_at(tile: Vector2i) -> bool:
	return not _standalone_map_object_at(tile).is_empty()

func _standalone_map_object_at(tile: Vector2i) -> Dictionary:
	return _standalone_map_objects_by_tile.get(_tile_key(tile), {})

func _is_decorative_object_placement(object: Dictionary) -> bool:
	var kind := String(object.get("kind", "")).strip_edges()
	var family := String(object.get("object_family_id", object.get("family_id", ""))).strip_edges()
	var role := String(object.get("runtime_object_role", "")).strip_edges()
	return kind == "decorative_obstacle" or family == "decorative_obstacle" or role == "decorative_blocker_sprite"

func _is_standalone_map_object_placement(object: Dictionary) -> bool:
	var kind := String(object.get("kind", "")).strip_edges()
	if kind in ["town", "guard"]:
		return false
	if String(object.get("site_id", "")).strip_edges() != "":
		return false
	if String(object.get("artifact_id", "")).strip_edges() != "":
		return false
	var object_id := String(object.get("object_id", object.get("id", ""))).strip_edges()
	return object_id != "" and (_map_object_asset_ids.has(object_id) or String(object.get("overworld_sprite_asset_id", "")).strip_edges() != "")

func _decorative_object_asset_id(object: Dictionary) -> String:
	if object.is_empty():
		return ""
	var direct_asset_id := String(object.get("overworld_sprite_asset_id", "")).strip_edges()
	if direct_asset_id != "":
		return direct_asset_id
	var object_id := String(object.get("object_id", object.get("id", ""))).strip_edges()
	if object_id != "" and _decorative_object_asset_ids.has(object_id):
		return String(_decorative_object_asset_ids.get(object_id, ""))
	var family_id := String(object.get("object_family_id", object.get("family_id", ""))).strip_edges()
	if family_id != "" and _decorative_object_asset_ids.has(family_id):
		return String(_decorative_object_asset_ids.get(family_id, ""))
	return ""

func _standalone_map_object_asset_id(object: Dictionary) -> String:
	if object.is_empty():
		return ""
	var direct_asset_id := String(object.get("overworld_sprite_asset_id", "")).strip_edges()
	if direct_asset_id != "":
		return direct_asset_id
	var object_id := String(object.get("object_id", object.get("id", ""))).strip_edges()
	if object_id != "" and _map_object_asset_ids.has(object_id):
		return String(_map_object_asset_ids.get(object_id, ""))
	return ""

func _decorative_object_footprint_rect(object: Dictionary, entry_rect: Rect2) -> Rect2:
	if object.is_empty():
		return entry_rect
	var min_tile := Vector2i(int(object.get("x", -1)), int(object.get("y", -1)))
	var max_tile := min_tile
	var bounds = object.get("bounds", {})
	if bounds is Dictionary and not bounds.is_empty():
		min_tile = Vector2i(int(bounds.get("min_x", min_tile.x)), int(bounds.get("min_y", min_tile.y)))
		max_tile = Vector2i(int(bounds.get("max_x", min_tile.x)), int(bounds.get("max_y", min_tile.y)))
	else:
		var footprint = object.get("footprint", {})
		if footprint is Dictionary:
			max_tile = min_tile + Vector2i(maxi(1, int(footprint.get("width", 1))) - 1, maxi(1, int(footprint.get("height", 1))) - 1)
	if min_tile.x < 0 or min_tile.y < 0:
		return entry_rect
	min_tile = Vector2i(clampi(min_tile.x, 0, maxi(_map_size.x - 1, 0)), clampi(min_tile.y, 0, maxi(_map_size.y - 1, 0)))
	max_tile = Vector2i(clampi(max_tile.x, 0, maxi(_map_size.x - 1, 0)), clampi(max_tile.y, 0, maxi(_map_size.y - 1, 0)))
	var board_rect := _board_rect()
	var start_rect := _tile_rect(board_rect, min_tile)
	var end_rect := _tile_rect(board_rect, max_tile)
	return Rect2(start_rect.position, end_rect.end - start_rect.position)

func _has_artifact_at(tile: Vector2i) -> bool:
	return not _artifact_node_at(tile).is_empty()

func _artifact_node_at(tile: Vector2i) -> Dictionary:
	return _artifacts_by_tile.get(_tile_key(tile), {})

func _has_encounter_at(tile: Vector2i) -> bool:
	return _encounters_by_tile.has(_tile_key(tile))

func _encounter_node_at(tile: Vector2i) -> Dictionary:
	return _encounters_by_tile.get(_tile_key(tile), {})

func _has_rememberable_encounter_at(tile: Vector2i) -> bool:
	return _rememberable_encounters_by_tile.has(_tile_key(tile))

func _has_hero_at(tile: Vector2i) -> bool:
	return _heroes_by_tile.has(_tile_key(tile))

func _placement_debug_overlay_payload() -> Dictionary:
	var blocker_index := {}
	var interactable_index := {}
	var records := []
	if _session == null:
		return _placement_debug_payload_from_indexes(blocker_index, interactable_index, records)
	var towns = _session.overworld.get("towns", [])
	if towns is Array:
		for town_value in towns:
			if town_value is Dictionary:
				_collect_town_placement_debug_tiles(town_value, blocker_index, interactable_index, records)
	var resource_nodes = _session.overworld.get("resource_nodes", [])
	if resource_nodes is Array:
		for node_value in resource_nodes:
			if node_value is Dictionary:
				_collect_resource_placement_debug_tiles(node_value, blocker_index, interactable_index, records)
	var map_objects = _session.overworld.get("map_objects", [])
	if map_objects is Array:
		for object_value in map_objects:
			if object_value is Dictionary:
				_collect_map_object_placement_debug_tiles(object_value, blocker_index, records)
	var artifact_nodes = _session.overworld.get("artifact_nodes", [])
	if artifact_nodes is Array:
		for node_value in artifact_nodes:
			if node_value is Dictionary and not bool(node_value.get("collected", false)):
				var tile := Vector2i(int(node_value.get("x", -1)), int(node_value.get("y", -1)))
				_add_placement_debug_tile(interactable_index, tile, "artifact_action", String(node_value.get("placement_id", "")))
				records.append(_placement_debug_record("artifact", String(node_value.get("placement_id", "")), 0, 1))
	var encounters = _session.overworld.get("encounters", [])
	if encounters is Array:
		for encounter_value in encounters:
			if encounter_value is Dictionary and not OverworldRulesScript.is_encounter_resolved(_session, encounter_value):
				var tile := Vector2i(int(encounter_value.get("x", -1)), int(encounter_value.get("y", -1)))
				_add_placement_debug_tile(interactable_index, tile, "encounter_action", String(encounter_value.get("placement_id", encounter_value.get("id", ""))))
				records.append(_placement_debug_record("encounter", String(encounter_value.get("placement_id", encounter_value.get("id", ""))), 0, 1))
	return _placement_debug_payload_from_indexes(blocker_index, interactable_index, records)

func _collect_town_placement_debug_tiles(town: Dictionary, blocker_index: Dictionary, interactable_index: Dictionary, records: Array) -> void:
	var entry := _town_entry_tile(town)
	var blocker_count := 0
	var interactable_count := 0
	for cell_value in _town_in_bounds_footprint_cells_for_entry(entry):
		var cell: Vector2i = cell_value
		if cell == entry:
			_add_placement_debug_tile(interactable_index, cell, "town_entry", String(town.get("placement_id", "")))
			interactable_count += 1
		else:
			_add_placement_debug_tile(blocker_index, cell, "town_body", String(town.get("placement_id", "")))
			blocker_count += 1
	records.append(_placement_debug_record("town", String(town.get("placement_id", "")), blocker_count, interactable_count))

func _collect_resource_placement_debug_tiles(node: Dictionary, blocker_index: Dictionary, interactable_index: Dictionary, records: Array) -> void:
	var site := ContentService.get_resource_site(String(node.get("site_id", "")))
	if not bool(site.get("persistent_control", false)) and bool(node.get("collected", false)):
		return
	var placement_id := String(node.get("placement_id", ""))
	var surface := OverworldRulesScript.overworld_object_placement_pathing_surface(_session, placement_id)
	var blocker_count := 0
	var interactable_count := 0
	if bool(surface.get("blocks_body_tiles", false)):
		var body_tiles: Array = surface.get("body_tiles", []) if surface.get("body_tiles", []) is Array else []
		for tile_payload in body_tiles:
			var tile := _tile_from_payload(tile_payload)
			_add_placement_debug_tile(blocker_index, tile, "resource_body", placement_id)
			blocker_count += 1
	var interaction_tiles: Array = surface.get("interaction_tiles", []) if surface.get("interaction_tiles", []) is Array else []
	for tile_payload in interaction_tiles:
		var tile := _tile_from_payload(tile_payload)
		_add_placement_debug_tile(interactable_index, tile, "resource_visit", placement_id)
		interactable_count += 1
	if interaction_tiles.is_empty():
		_add_placement_debug_tile(interactable_index, Vector2i(int(node.get("x", -1)), int(node.get("y", -1))), "resource_action", placement_id)
		interactable_count += 1
	records.append(_placement_debug_record("resource", placement_id, blocker_count, interactable_count))

func _collect_map_object_placement_debug_tiles(object: Dictionary, blocker_index: Dictionary, records: Array) -> void:
	if not _map_object_blocks_debug_body_tiles(object):
		return
	var placement_id := String(object.get("placement_id", object.get("id", "")))
	var blocker_count := 0
	for tile in _map_object_debug_body_tiles(object):
		if tile is Vector2i:
			_add_placement_debug_tile(blocker_index, tile, "map_object_body", placement_id)
			blocker_count += 1
	records.append(_placement_debug_record("map_object", placement_id, blocker_count, 0))

func _map_object_blocks_debug_body_tiles(object: Dictionary) -> bool:
	var kind := String(object.get("kind", ""))
	var family := String(object.get("object_family_id", object.get("family_id", "")))
	return bool(object.get("blocking_body", kind == "decorative_obstacle" or family == "decorative_obstacle"))

func _map_object_debug_body_tiles(object: Dictionary) -> Array:
	var block_payload: Variant = object.get("package_block_tiles", null)
	var body_tiles := _debug_tiles_from_payload_array(block_payload) if block_payload is Array else []
	if body_tiles.is_empty() and block_payload is Array:
		return []
	if body_tiles.is_empty():
		body_tiles = _debug_tiles_from_payload_array(object.get("body_tiles", []))
	if body_tiles.is_empty():
		body_tiles = [Vector2i(int(object.get("x", -1)), int(object.get("y", -1)))]
	return body_tiles

func _debug_tiles_from_payload_array(values: Variant) -> Array:
	var tiles := []
	if not (values is Array):
		return tiles
	for value in values:
		var tile := _tile_from_payload(value)
		if tile.x >= 0 and tile.y >= 0:
			tiles.append(tile)
	return tiles

func _placement_debug_record(kind: String, placement_id: String, blocker_count: int, interactable_count: int) -> Dictionary:
	return {
		"kind": kind,
		"placement_id": placement_id,
		"blocker_count": blocker_count,
		"interactable_count": interactable_count,
	}

func _placement_debug_payload_from_indexes(blocker_index: Dictionary, interactable_index: Dictionary, records: Array) -> Dictionary:
	return {
		"blocker_tiles": _placement_debug_tiles_from_index(blocker_index),
		"interactable_tiles": _placement_debug_tiles_from_index(interactable_index),
		"blocker_tile_count": blocker_index.size(),
		"interactable_tile_count": interactable_index.size(),
		"records": records,
	}

func _placement_debug_tiles_from_index(index: Dictionary) -> Array:
	var keys := index.keys()
	keys.sort()
	var tiles := []
	for key in keys:
		var tile: Dictionary = index.get(key, {})
		tiles.append(tile.duplicate(true))
	return tiles

func _add_placement_debug_tile(index: Dictionary, tile: Vector2i, kind: String, placement_id: String) -> void:
	if not _tile_in_map(tile):
		return
	var key := _tile_key(tile)
	var payload: Dictionary = index.get(key, {}) if index.get(key, {}) is Dictionary else {}
	if payload.is_empty():
		payload = {
			"x": tile.x,
			"y": tile.y,
			"kinds": [],
			"placement_ids": [],
		}
	var kinds: Array = payload.get("kinds", []) if payload.get("kinds", []) is Array else []
	if kind != "" and kind not in kinds:
		kinds.append(kind)
	payload["kinds"] = kinds
	var placement_ids: Array = payload.get("placement_ids", []) if payload.get("placement_ids", []) is Array else []
	if placement_id != "" and placement_id not in placement_ids:
		placement_ids.append(placement_id)
	payload["placement_ids"] = placement_ids
	index[key] = payload

func _tile_from_payload(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Dictionary:
		return Vector2i(int(value.get("x", -1)), int(value.get("y", -1)))
	return Vector2i(-1, -1)

func _tile_in_map(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.y >= 0 and tile.x < _map_size.x and tile.y < _map_size.y

func _tile_in_visible_bounds(tile: Vector2i, visible_bounds: Rect2i) -> bool:
	return (
		tile.x >= visible_bounds.position.x
		and tile.y >= visible_bounds.position.y
		and tile.x < visible_bounds.position.x + visible_bounds.size.x
		and tile.y < visible_bounds.position.y + visible_bounds.size.y
	)

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
			if OverworldRulesScript.tile_step_cuts_blocked_corner(_session, current, next):
				continue
			if OverworldRulesScript.tile_is_blocked(_session, next.x, next.y):
				continue
			if next != goal and OverworldRulesScript.tile_has_route_interaction(_session, next.x, next.y):
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

func _tiles_from_payloads(value: Variant) -> Array:
	var tiles := []
	if not (value is Array):
		return tiles
	for tile_value in value:
		if tile_value is Vector2i:
			tiles.append(tile_value)
		elif tile_value is Dictionary:
			tiles.append(Vector2i(int(tile_value.get("x", -1)), int(tile_value.get("y", -1))))
	return tiles
